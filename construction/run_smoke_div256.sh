#!/bin/bash
# Functional smoke sim for the masked carry-save divtiplier (behavioral RTL +
# the real O-PINI2 leaf). Recombines the product shares and checks
# == (x*y) mod 2^N.  Usage: run_smoke_div256.sh [N]   (default 256)
set -e
export PATH=.:$PATH
cd "$(dirname "$0")"
N=${1:-256}
iverilog -g2012 -o smoke_div${N}_sim div${N}.v ./MSKand_opini2_d2.v tb_smoke_div${N}.v
vvp smoke_div${N}_sim
