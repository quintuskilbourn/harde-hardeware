#!/bin/bash
# Functional smoke sim for iszero256 (behavioral RTL + the real O-PINI2 leaf).
# Recombines the ISZERO output shares and checks == (input==0 ? 1 : 0).
set -e
export PATH=.:$PATH
cd "$(dirname "$0")"
iverilog -g2012 -o smoke_sim iszero256.v ./MSKand_opini2_d2.v tb_smoke_iszero256.v
vvp smoke_sim
