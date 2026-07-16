#!/bin/bash
# Functional smoke sim for the masked Keccak-f round unit (behavioral RTL +
# the real O-PINI2 leaf). Recombines the output shares and checks against the
# spec reference permutation (gen_keccakf.py; XKCP-anchored for w=64).
# Usage: run_smoke_keccakf.sh [B]   (B = 25*w; default 1600)
set -e
export PATH=.:$PATH
cd "$(dirname "$0")"
B=${1:-1600}
iverilog -g2012 -o smoke_keccakf${B}_sim keccakf${B}.v ./MSKand_opini2_d2.v tb_smoke_keccakf${B}.v
vvp smoke_keccakf${B}_sim
