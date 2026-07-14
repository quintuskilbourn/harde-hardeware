#!/bin/bash
# Build the netlist front-end modules standalone and report axiom closure.
# Run from the leansec dir.
set -uo pipefail
export PATH="$HOME/.elan/bin:$PATH"
cd "$(dirname "$0")/../.."   # -> leansec root
LOG=tools/netlist2lean/build_check.out
{
  echo "=== $(date -u) build_check ==="
  echo "--- lake build deps ---"
  lake build LeanSec.Gadget LeanSec.Gadgets.DomAnd 2>&1 | tail -3
  echo "--- compile DomAndGen (generated) ---"
  lake env lean LeanSec/Netlist/DomAndGen.lean 2>&1 && echo "GEN: OK" || echo "GEN: FAIL"
  echo "--- compile DomAnd (anchors) ---"
  lake env lean LeanSec/Netlist/DomAnd.lean 2>&1 && echo "ANCHORS: OK" || echo "ANCHORS: FAIL"
  echo "=== DONE $(date -u) ==="
} > "$LOG" 2>&1
echo "build_check finished -> $LOG"
