#!/bin/bash
# MATCHI transition-model check (L2 composition gate) for the 256-bit masked
# adder. Direct mirror of ./run_one.sh (the validated 8-bit
# flow): generic synth via MATCHI's synth.tcl (keeps MSKand_opini2_d2 as a
# black-box assumed-OPINI leaf — no flatten), iverilog sim -> VCD, MATCHI in
# the DEFAULT transition model (transitions ON; --no-check-transitions NOT
# passed). Verdict = matchi exit code (0 PASS / 1 FAIL).
# Usage: run_add256.sh <TOPMODULE> [SUBVAL:0|1] [RECOMB]
set -u
export PATH=.:$PATH
MATCHI=.
SYNTH=.
cd "$(dirname "$0")"
TOP=$1; SUBVAL=${2:-0}; EXTRA=${3:-}
# NB precise glob: the PINI *label control* tops end in "_pini"
# (top_add256_pini, top_chain_pini). A bare "*pini*" is WRONG here because the
# OPINI tops contain the substring "opini2" — it would hand the OPINI runs the
# relabelled PINI leaf. Match the "_pini" suffix only.
case "$TOP" in
  *_pini) LEAF=MSKand_opini2_d2_pini.v ;;
  *)      LEAF=MSKand_opini2_d2.v ;;
esac
W=work_${TOP}_sub${SUBVAL}
rm -rf "$W"; mkdir -p "$W/hdl"
cp "$TOP.v" "$W/hdl/"
# the O-PINI2 leaf and (for the pini control) its PINI-relabelled twin live in
# the verified 8-bit dir — read-only reference, copied in byte-identical.
cp "./$LEAF" "$W/hdl/"
DEFS="-DTOPMOD=$TOP -DSUBVAL=1'b$SUBVAL"
[ "$EXTRA" = "RECOMB" ] && DEFS="$DEFS -DRECOMB"
echo "===== $TOP sub=$SUBVAL $EXTRA ====="
OUT_DIR="$W" MAIN_MODULE="$TOP" IMPLEM_DIR="$W/hdl" yosys -c "$SYNTH" > "$W/yosys.log" 2>&1
if [ ! -f "$W/${TOP}_synth.json" ]; then echo "SYNTH FAILED:"; tail -20 "$W/yosys.log"; exit 2; fi
iverilog -y "$W/hdl" -I "$W/hdl" -s tb -o "$W/sim" \
    -D DUMPFILE=\"$W/a.vcd\" $DEFS "$W/${TOP}_synth.v" tb_add256.v > "$W/iverilog.log" 2>&1
if [ ! -f "$W/sim" ]; then echo "IVERILOG FAILED:"; tail -20 "$W/iverilog.log"; exit 3; fi
vvp "$W/sim" > "$W/vvp.log" 2>&1
"$MATCHI" --json "$W/${TOP}_synth.json" --vcd "$W/a.vcd" --gname "$TOP" --dut tb.dut \
    > "$W/matchi.log" 2>&1
EC=$?
grep -E "Verification successful|^Error|Transition leakage|multiple shares|multiple places|Caused by|no pipeline bubble|not a fresh random|^Warning" "$W/matchi.log" | head -25
echo "MATCHI exit code: $EC"
exit $EC
