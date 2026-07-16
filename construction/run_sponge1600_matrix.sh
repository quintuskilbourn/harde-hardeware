#!/bin/bash
# sponge1600 full MATCHI matrix, sequential, controls first, opini last.
# Expected exits: pini 1, rndreuse 1, recomb 1, opini 0. Marker: SPONGE1600_MATRIX_DONE
cd "$(dirname "$0")"
echo "[$(date)] sponge1600 matrix start"
./run_keccakf.sh sponge1600_pini     > matrix_sponge1600_pini.out 2>&1;    P=$?
./run_keccakf.sh sponge1600_rndreuse > matrix_sponge1600_rndreuse.out 2>&1; R=$?
./run_keccakf.sh sponge1600_recomb RECOMB > matrix_sponge1600_recomb.out 2>&1; C=$?
./run_keccakf.sh sponge1600          > matrix_sponge1600_opini.out 2>&1;   O=$?
echo "opini=$O pini=$P rndreuse=$R recomb=$C" | tee SPONGE1600_MATRIX_DONE
echo "[$(date)] sponge1600 matrix done"
