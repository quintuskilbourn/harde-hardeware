#!/bin/bash
# Functional smoke sim for the SLOAD->swap->SSTORE composition (behavioral RTL
# + the real O-PINI2 leaf). Checks the full storage round-trip against the
# reference constant-product swap.  Usage: run_smoke_dexloop.sh [N]  (default 16)
set -e
export PATH=.:$PATH
cd "$(dirname "$0")"
N=${1:-16}
iverilog -g2012 -o smoke_dexloop${N}_sim dexloop${N}.v ./MSKand_opini2_d2.v tb_smoke_dexloop${N}.v
vvp smoke_dexloop${N}_sim
