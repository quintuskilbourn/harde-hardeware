#!/bin/bash
# Full MATCHI matrix for the dexloop16 SLOAD->swap->SSTORE composition pilot.
# Reuses the generic run_swap256.sh flow (synth.tcl keeps the O-PINI2 leaf as
# an assumed-OPINI black box; iverilog VCD; MATCHI default transition model).
# Controls first, OPINI target last (established discipline). Small pilot:
# no RAM gating needed (218 gadgets, ~1k-cycle trace; swap16-scale jobs).
# Expected verdicts: pini/rndreuse/recomb/sharedbus EXIT=1, opini EXIT=0.
set -u
cd "$(dirname "$0")"
run() { # top extra outfile
  STAGE=all ./run_swap256.sh "$1" ${2:+$2} > "$3" 2>&1
  local ec=$?
  echo "EXIT=$ec" >> "$3"
  echo "[$(date)] $1 EXIT=$ec"
}
run dexloop16_pini      ""     matrix_dexloop16_pini.out
run dexloop16_rndreuse  ""     matrix_dexloop16_rndreuse.out
run dexloop16_recomb    RECOMB matrix_dexloop16_recomb.out
run dexloop16_sharedbus ""     matrix_dexloop16_sharedbus.out
run dexloop16           ""     matrix_dexloop16_opini.out
touch DEXLOOP16_MATRIX_DONE
echo "[$(date)] dexloop16 matrix complete"
