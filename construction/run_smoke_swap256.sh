#!/bin/bash
# Functional smoke sim for the masked swap demonstrator (behavioral RTL +
# the real O-PINI2 leaf). Recombines all four outputs and checks against the
# reference constant-product swap.  Usage: run_smoke_swap256.sh [N]  (default 256)
set -e
export PATH=.:$PATH
cd "$(dirname "$0")"
N=${1:-256}
iverilog -g2012 -o smoke_swap${N}_sim swap${N}.v ./MSKand_opini2_d2.v tb_smoke_swap${N}.v
vvp smoke_swap${N}_sim
