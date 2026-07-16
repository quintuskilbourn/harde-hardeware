#!/bin/bash
# MATCHI transition-model check (L2 composition gate) for the masked keccak-f
# round-unit tops. Direct mirror of ./run_iszero256.sh (the validated flow):
# generic synth via MATCHI's synth.tcl (keeps MSKand_opini2_d2 as a black-box
# assumed-OPINI leaf — no flatten), iverilog sim -> VCD, MATCHI in the DEFAULT
# transition model (transitions ON; --no-check-transitions NOT passed).
# Verdict = matchi exit code (0 PASS / 1 FAIL).
# Usage: run_keccakf.sh <TOPMODULE> [RECOMB]  (TOP = keccakf1600 | _pini |
#        _rndreuse | _recomb | any keccakfB_* from gen_keccakf.py w)
set -u
export PATH=.:$PATH
MATCHI=.
SYNTH=.
cd "$(dirname "$0")"
TOP=$1; EXTRA=${2:-}
# The PINI *label control* top ends in "_pini" — match the suffix precisely.
case "$TOP" in
  *_pini) LEAF=MSKand_opini2_d2_pini.v ;;
  *)      LEAF=MSKand_opini2_d2.v ;;
esac
TB="tb_${TOP%%_*}.v"          # div256_rndreuse -> tb_div256.v
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
    -D DUMPFILE=\"$W/a.vcd\" $DEFS "$W/${TOP}_synth.v" "$TB" > "$W/iverilog.log" 2>&1
if [ ! -f "$W/sim" ]; then echo "IVERILOG FAILED:"; tail -20 "$W/iverilog.log"; exit 3; fi
vvp "$W/sim" > "$W/vvp.log" 2>&1
"$MATCHI" --json "$W/${TOP}_synth.json" --vcd "$W/a.vcd" --gname "$TOP" --dut tb.dut \
    > "$W/matchi.log" 2>&1
EC=$?
grep -E "Verification successful|^Error|Transition leakage|multiple shares|multiple places|Caused by|no pipeline bubble|not a fresh random|^Warning" "$W/matchi.log" | head -25
echo "MATCHI exit code: $EC"
exit $EC
