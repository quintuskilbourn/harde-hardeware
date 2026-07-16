#!/bin/bash
# Gated detached driver for the dexloop256 (SLOAD->swap->SSTORE @ N=256)
# MATCHI matrix. Mirrors run_divevm256_matrix_gated.sh v2:
#   GATE 0: functional smoke must close AND report "SMOKE: ALL PASS" before
#           any big sim is built (don't burn ~400GB of VCDs on broken RTL).
#   PHASE A: 5x synth+sim in parallel (CPU-bound, ~70-90GB VCD each).
#   PHASE B: HOLDS until BOTH
#             - DIVEVM256_MATRIX_DONE (RAM-budget queue owner until then), and
#             - OPINI_CRASH_RESOLVED  (dexloop256 embeds the same swap program
#               that crashed MATCHI at cycle 35932 on swap256 opini — running
#               its matrix before the recsim.rs:181 crash is understood would
#               just reproduce the crash; create this marker once a fixed /
#               exonerated binary of record is established),
#           then MATCHI-only strictly sequentially (controls first, opini
#           last), each RAM-gated on MemAvailable>100GB.
# Launch: setsid nohup ./run_dexloop256_matrix_gated.sh > dexloop256_matrix_gated.log 2>&1 &
# Done marker: DEXLOOP256_MATRIX_DONE. Expected: opini EXIT=0, all four
# controls EXIT=1 (pini LIVE bubble-free reuse, rndreuse, recomb, sharedbus —
# cf. dexloop16 pilot signatures in RESULT_DEXLOOP16.md).
cd "$(dirname "$0")"
rm -f DEXLOOP256_MATRIX_DONE

echo "[$(date)] gate 0: waiting for dexloop256 smoke"
while [ ! -f SMOKE_DEXLOOP256_DONE ]; do sleep 120; done
if ! grep -q "SMOKE: ALL PASS" smoke_dexloop256.out; then
  echo "[$(date)] ABORT: smoke did not pass (see smoke_dexloop256.out)"
  exit 1
fi
echo "[$(date)] smoke ALL PASS; phase A: 5x synth+sim parallel (STAGE=sim)"
STAGE=sim ./run_swap256.sh dexloop256_pini           > matrix_dexloop256_pini.out      2>&1 &
STAGE=sim ./run_swap256.sh dexloop256_rndreuse       > matrix_dexloop256_rndreuse.out  2>&1 &
STAGE=sim ./run_swap256.sh dexloop256_recomb RECOMB  > matrix_dexloop256_recomb.out    2>&1 &
STAGE=sim ./run_swap256.sh dexloop256_sharedbus      > matrix_dexloop256_sharedbus.out 2>&1 &
STAGE=sim ./run_swap256.sh dexloop256                > matrix_dexloop256_opini.out     2>&1 &
wait
echo "[$(date)] phase A done"
for f in pini rndreuse recomb sharedbus opini; do
  grep -q "SIM OK" "matrix_dexloop256_$f.out" || echo "[$(date)] WARNING: $f sim did not report SIM OK"
done

echo "[$(date)] phase B: waiting for DIVEVM256_MATRIX_DONE + OPINI_CRASH_RESOLVED"
while [ ! -f DIVEVM256_MATRIX_DONE ] || [ ! -f OPINI_CRASH_RESOLVED ]; do sleep 300; done
echo "[$(date)] gates open; starting dexloop256 MATCHI runs"

ram_gate() {
  while [ "$(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo)" -lt 100 ]; do sleep 120; done
}
mrun() { # top outfile
  ram_gate
  echo "[$(date)] dexloop256 matrix: $1 (STAGE=matchi)"
  STAGE=matchi ./run_swap256.sh "$1" >> "$2" 2>&1
  echo "EXIT=$?" >> "$2"
}
mrun dexloop256_pini      matrix_dexloop256_pini.out
mrun dexloop256_rndreuse  matrix_dexloop256_rndreuse.out
mrun dexloop256_recomb    matrix_dexloop256_recomb.out
mrun dexloop256_sharedbus matrix_dexloop256_sharedbus.out
mrun dexloop256           matrix_dexloop256_opini.out
touch DEXLOOP256_MATRIX_DONE
echo "[$(date)] dexloop256 matrix complete"
