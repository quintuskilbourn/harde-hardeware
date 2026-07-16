#!/bin/bash
# Functional smoke sim for the EVM zero-gated divider (behavioral RTL + the
# real O-PINI2 leaf). Recombines qe/reme and checks EVM DIV/MOD semantics
# incl. B=0 -> 0.  Usage: run_smoke_divevm.sh [N]   (default 256)
set -e
export PATH=.:$PATH
cd "$(dirname "$0")"
N=${1:-256}
iverilog -g2012 -o smoke_divevm${N}_sim divevm${N}.v ./MSKand_opini2_d2.v tb_smoke_divevm${N}.v
vvp smoke_divevm${N}_sim
