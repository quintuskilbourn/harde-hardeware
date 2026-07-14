#!/usr/bin/env bash
# FULL verification gate — enforces the entire result chain (LeanSec.All), unlike
# the fast ci.sh whose default targets miss Netlist/Composition/Checker/Fault/Compiled.
# Run on the box (heavy decides). Addresses the 2026-07-13 cross-family audit finding
# that the refinement chain + ParserWitness were not CI-enforced.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.elan/bin:$PATH"
echo "== forbidden-token scan (whole tree) =="
if grep -rnE '\b(sorry|admit|native_decide)\b' LeanSec/ --include='*.lean' | grep -v '^LeanSec/Security.lean:' ; then
  echo "FAIL: forbidden token found"; exit 1; fi
echo "== build LeanSec.All (compiles every result module) =="
lake build LeanSec.All
echo "== leanchecker: independent kernel re-verification of the whole chain =="
lake env leanchecker LeanSec.All
echo "== forbidden-axiom scan =="
printf 'import LeanSec.All\n' > /tmp/allax.lean
if lake env lean /tmp/allax.lean 2>&1 | grep -iE 'ofReduceBool|Lean.trustCompiler'; then
  echo "FAIL: unexpected compiler-trust axiom"; exit 1; fi
echo "CI-FULL-PASS"
