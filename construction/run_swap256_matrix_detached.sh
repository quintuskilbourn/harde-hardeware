#!/bin/bash
# Detached driver for the swap256 MATCHI matrix: survives the construction-agent
# session ending (launch with: setsid nohup ./run_swap256_matrix_detached.sh &).
# Runs all four tops in parallel subshells, records per-top verdicts in
# matrix_swap256_*.out, and writes SWAP256_MATRIX_DONE with the four exit codes
# when finished. Expected: opini EXIT=0, pini EXIT=1 (live transition control,
# cf. swap16 u_dt_* bubble-free divider reuse), rndreuse EXIT=1, recomb EXIT=1.
# NOTE scale: 3578 gadgets x ~138k cycles -> VCDs ~50-100GB each, MATCHI ~10-20h.
cd "$(dirname "$0")"
rm -f SWAP256_MATRIX_DONE
( ./run_swap256.sh swap256               > matrix_swap256_opini.out    2>&1; echo "EXIT=$?" >> matrix_swap256_opini.out )    &
P1=$!
( ./run_swap256.sh swap256_pini          > matrix_swap256_pini.out     2>&1; echo "EXIT=$?" >> matrix_swap256_pini.out )     &
P2=$!
( ./run_swap256.sh swap256_rndreuse      > matrix_swap256_rndreuse.out 2>&1; echo "EXIT=$?" >> matrix_swap256_rndreuse.out ) &
P3=$!
( ./run_swap256.sh swap256_recomb RECOMB > matrix_swap256_recomb.out   2>&1; echo "EXIT=$?" >> matrix_swap256_recomb.out )   &
P4=$!
wait $P1 $P2 $P3 $P4
{
  date
  for f in opini pini rndreuse recomb; do echo "swap256 $f: $(grep EXIT matrix_swap256_$f.out)"; done
} > SWAP256_MATRIX_DONE
