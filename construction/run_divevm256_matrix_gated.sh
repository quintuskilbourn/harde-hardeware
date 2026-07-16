#!/bin/bash
# Gated detached driver for the divevm256 MATCHI matrix — v2 (iter 9):
# PHASE A runs the four synth+sim jobs IN PARALLEL IMMEDIATELY (CPU-bound,
# ~15GB VCD each, no MATCHI RAM pressure), so the VCDs are ready long before
# the swap256 matrix closes. PHASE B still HOLDS until SWAP256_MATRIX_DONE
# (the swap256 staged driver owns the RAM budget queue until then — launching
# another big MATCHI earlier would deadlock its MemAvailable>100GB gate), then
# runs MATCHI-only (STAGE=matchi) STRICTLY SEQUENTIALLY (controls first, opini
# last), each additionally RAM-gated on MemAvailable>100GB.
# Launch: setsid nohup ./run_divevm256_matrix_gated.sh > divevm256_matrix_gated.log 2>&1 &
# Done marker: DIVEVM256_MATRIX_DONE. Expected: opini EXIT=0, pini EXIT=1
# (LIVE transition control — div-core bubble-free reuse, cf. divevm16_pini),
# rndreuse EXIT=1, recomb EXIT=1.
cd "$(dirname "$0")"
rm -f DIVEVM256_MATRIX_DONE

echo "[$(date)] phase A: 4x synth+sim parallel (STAGE=sim)"
STAGE=sim ./run_divevm.sh divevm256_pini            > matrix_divevm256_pini.out     2>&1 &
STAGE=sim ./run_divevm.sh divevm256_rndreuse        > matrix_divevm256_rndreuse.out 2>&1 &
STAGE=sim ./run_divevm.sh divevm256_recomb RECOMB   > matrix_divevm256_recomb.out   2>&1 &
STAGE=sim ./run_divevm.sh divevm256                 > matrix_divevm256_opini.out    2>&1 &
wait
echo "[$(date)] phase A done"
for f in pini rndreuse recomb opini; do
  grep -q "SIM OK" "matrix_divevm256_$f.out" || echo "[$(date)] WARNING: $f sim did not report SIM OK"
done

echo "[$(date)] phase B: waiting for SWAP256_MATRIX_DONE"
while [ ! -f SWAP256_MATRIX_DONE ]; do sleep 300; done
echo "[$(date)] swap256 matrix closed; starting divevm256 MATCHI runs"

wait_ram () {
  while :; do
    AV=$(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo)
    [ "$AV" -gt 100 ] && break
    echo "[$(date)] waiting for RAM (available ${AV}GB <= 100GB)"; sleep 300
  done
}

run_one () {  # $1=top $2=outfile-suffix $3=extra
  wait_ram
  echo "[$(date)] divevm256 matrix: $1 (STAGE=matchi)"
  ( STAGE=matchi ./run_divevm.sh "$1" $3 >> "matrix_divevm256_$2.out" 2>&1
    echo "EXIT=$?" >> "matrix_divevm256_$2.out" )
}

run_one divevm256_pini     pini     ""
run_one divevm256_rndreuse rndreuse ""
run_one divevm256_recomb   recomb   RECOMB
run_one divevm256          opini    ""

{
  date
  for f in opini pini rndreuse recomb; do echo "divevm256 $f: $(grep EXIT matrix_divevm256_$f.out)"; done
} > DIVEVM256_MATRIX_DONE
echo "[$(date)] all done"
