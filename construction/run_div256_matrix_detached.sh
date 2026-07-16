#!/bin/bash
# Detached driver for the div256 MATCHI matrix: survives the construction-agent
# session ending (launch with: setsid nohup ./run_div256_matrix_detached.sh &).
# Runs all four tops in parallel subshells, records per-top verdicts in
# matrix_div256_*.out, and writes DIV256_MATRIX_DONE with the four exit codes
# when finished.
cd "$(dirname "$0")"
rm -f DIV256_MATRIX_DONE
( ./run_div256.sh div256              > matrix_div256_opini.out    2>&1; echo "EXIT=$?" >> matrix_div256_opini.out )    &
P1=$!
( ./run_div256.sh div256_pini         > matrix_div256_pini.out     2>&1; echo "EXIT=$?" >> matrix_div256_pini.out )     &
P2=$!
( ./run_div256.sh div256_rndreuse     > matrix_div256_rndreuse.out 2>&1; echo "EXIT=$?" >> matrix_div256_rndreuse.out ) &
P3=$!
( ./run_div256.sh div256_recomb RECOMB > matrix_div256_recomb.out  2>&1; echo "EXIT=$?" >> matrix_div256_recomb.out )   &
P4=$!
wait $P1 $P2 $P3 $P4
{
  date
  for f in opini pini rndreuse recomb; do echo "div256 $f: $(grep EXIT matrix_div256_$f.out)"; done
} > DIV256_MATRIX_DONE
