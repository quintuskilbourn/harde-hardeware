#!/bin/bash
# MATCHI transition-model check (L2 composition gate) for the 256-bit masked
# ISZERO tree. Direct mirror of ../add256/run_add256.sh (the validated 256-bit
# adder flow): generic synth via MATCHI's synth.tcl (keeps MSKand_opini2_d2 as
# a black-box assumed-OPINI leaf — no flatten), iverilog sim -> VCD, MATCHI in
# the DEFAULT transition model (transitions ON; --no-check-transitions NOT
# passed). Verdict = matchi exit code (0 PASS / 1 FAIL).
# Usage: run_iszero256.sh <TOPMODULE> [RECOMB]
set -u
export PATH=.:$PATH
MATCHI=.
SYNTH=.
cd "$(dirname "$0")"
TOP=$1; EXTRA=${2:-}
# The PINI *label control* top ends in "_pini". Match the "_pini" suffix only
# (a bare "*pini*" would be wrong — but here module names contain no "opini"
# substring; still, keep the precise suffix match for parity with the adder).
case "$TOP" in
  *_pini) LEAF=MSKand_opini2_d2_pini.v ;;
  *)      LEAF=MSKand_opini2_d2.v ;;
esac
W=work_${TOP}
rm -rf "$W"; mkdir -p "$W/hdl"
cp "$TOP.v" "$W/hdl/"
# the O-PINI2 leaf and (for the pini control) its PINI-relabelled twin live in
# the verified adder dir — read-only reference, copied in byte-identical.
cp "./$LEAF" "$W/hdl/"
DEFS="-DTOPMOD=$TOP"
[ "$EXTRA" = "RECOMB" ] && DEFS="$DEFS -DRECOMB"
echo "===== $TOP $EXTRA ====="
OUT_DIR="$W" MAIN_MODULE="$TOP" IMPLEM_DIR="$W/hdl" yosys -c "$SYNTH" > "$W/yosys.log" 2>&1
if [ ! -f "$W/${TOP}_synth.json" ]; then echo "SYNTH FAILED:"; tail -20 "$W/yosys.log"; exit 2; fi
iverilog -y "$W/hdl" -I "$W/hdl" -s tb -o "$W/sim" \
    -D DUMPFILE=\"$W/a.vcd\" $DEFS "$W/${TOP}_synth.v" tb_iszero256.v > "$W/iverilog.log" 2>&1
if [ ! -f "$W/sim" ]; then echo "IVERILOG FAILED:"; tail -20 "$W/iverilog.log"; exit 3; fi
vvp "$W/sim" > "$W/vvp.log" 2>&1
"$MATCHI" --json "$W/${TOP}_synth.json" --vcd "$W/a.vcd" --gname "$TOP" --dut tb.dut \
    > "$W/matchi.log" 2>&1
EC=$?
grep -E "Verification successful|^Error|Transition leakage|multiple shares|multiple places|Caused by|no pipeline bubble|not a fresh random|^Warning" "$W/matchi.log" | head -25
echo "MATCHI exit code: $EC"
exit $EC
