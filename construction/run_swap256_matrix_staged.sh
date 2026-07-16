#!/bin/bash
# RAM-aware staged driver for the swap256 MATCHI matrix (replaces the fully
# parallel run_swap256_matrix_detached.sh, which would run 4 MATCHI jobs at
# once: div256 MATCHI peaked ~35GB RSS at 770 gadgets/135k cycles; swap256 is
# 3578 gadgets/138k cycles, so one job may need most of the 125GB box).
#   Phase A: synth+sim for all 4 tops IN PARALLEL (vvp is cheap on RAM,
#            ~50-100GB VCD each on disk).
#   Phase B: MATCHI STRICTLY SEQUENTIAL, controls first (they fail fast),
#            opini last; before each job wait until MemAvailable > 100GB so we
#            never overlap another big MATCHI (e.g. the div256 opini run).
# Launch: setsid nohup ./run_swap256_matrix_staged.sh > swap256_matrix_staged.log 2>&1 &
# Done marker: SWAP256_MATRIX_DONE. Expected: opini EXIT=0, pini EXIT=1 (live
# transition control, cf. swap16 u_dt_* divider reuse), rndreuse=1, recomb=1.
cd "$(dirname "$0")"
rm -f SWAP256_MATRIX_DONE

echo "[$(date)] phase A: 4x synth+sim parallel"
( STAGE=sim ./run_swap256.sh swap256               > matrix_swap256_opini.out    2>&1 ) &
P1=$!
( STAGE=sim ./run_swap256.sh swap256_pini          > matrix_swap256_pini.out     2>&1 ) &
P2=$!
( STAGE=sim ./run_swap256.sh swap256_rndreuse      > matrix_swap256_rndreuse.out 2>&1 ) &
P3=$!
( STAGE=sim ./run_swap256.sh swap256_recomb RECOMB > matrix_swap256_recomb.out   2>&1 ) &
P4=$!
wait $P1 $P2 $P3 $P4
echo "[$(date)] phase A done"

wait_ram () {
  while :; do
    AV=$(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo)
    [ "$AV" -gt 100 ] && break
    echo "[$(date)] waiting for RAM (available ${AV}GB <= 100GB)"; sleep 300
  done
}

run_one () {  # $1=top $2=outfile-suffix $3=extra
  wait_ram
  echo "[$(date)] phase B: MATCHI $1"
  ( STAGE=matchi ./run_swap256.sh "$1" $3 >> "matrix_swap256_$2.out" 2>&1
    echo "EXIT=$?" >> "matrix_swap256_$2.out" )
}

run_one swap256_pini     pini     ""
run_one swap256_rndreuse rndreuse ""
run_one swap256_recomb   recomb   RECOMB
run_one swap256          opini    ""

{
  date
  for f in opini pini rndreuse recomb; do echo "swap256 $f: $(grep EXIT matrix_swap256_$f.out)"; done
} > SWAP256_MATRIX_DONE
echo "[$(date)] all done"
