#!/bin/bash
# Functional smoke sim for the masked carry-save multiplier (behavioral RTL +
# the real O-PINI2 leaf). Recombines the product shares and checks
# == (x*y) mod 2^N.  Usage: run_smoke_mul256.sh [N]   (default 256)
set -e
export PATH=.:$PATH
cd "$(dirname "$0")"
N=${1:-256}
iverilog -g2012 -o smoke_mul${N}_sim mul${N}.v ./MSKand_opini2_d2.v tb_smoke_mul${N}.v
vvp smoke_mul${N}_sim
