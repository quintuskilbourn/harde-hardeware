#!/usr/bin/env bash
# Honesty CI for leansec (MODEL_CONTRACT.md §10). Exit nonzero on ANY violation.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.elan/bin:$PATH"

fail() { echo "CI-FAIL: $*" >&2; exit 1; }

# 1. Trust root untouched (codex must never edit these).
sha256sum -c work/trustroot.sha256 --quiet 2>/dev/null \
  || fail "trust root (Security.lean / MODEL_CONTRACT.md) was modified"

# 2. No proof-dishonesty tokens in any Lean file codex can touch.
#    (Security.lean is exempt from the grep because it is hash-pinned in step 1;
#     its comments may name the forbidden tokens.)
if grep -rnE '\bsorry\b|\badmit\b|native_decide|ofReduceBool|ofReduceNat' \
     LeanSec LeanSec.lean test --include='*.lean' \
     | grep -v '^LeanSec/Security.lean:'; then
  fail "forbidden token (sorry/admit/native_decide/code-gen axiom)"
fi
# New axiom declarations are forbidden outright.
if grep -rnE '^\s*axiom\b' LeanSec LeanSec.lean test --include='*.lean'; then
  fail "axiom declaration found"
fi

# 3. Full build.
lake build 2>&1 | tail -5

# 3b. Aggregate result target (2026-07-15 hardening H3): every result module —
#     Netlist witnesses (incl. the generated ParserWitness* modules), Scan*,
#     Sifa*, DAG/OPINI composition, and the checker differential battery —
#     is imported by LeanSec.All, so this build re-elaborates all of them,
#     and leanchecker independently re-verifies the whole chain from the
#     .oleans with a fresh kernel.
lake build LeanSec.All 2>&1 | tail -3 || fail "LeanSec.All did not build"
lake env leanchecker --fresh LeanSec.All \
  || fail "leanchecker --fresh rejected LeanSec.All"

# 4. Axiom closure of every registered theorem ⊆ {propext, Classical.choice, Quot.sound}.
#    test/Axioms.lean must `#print axioms` every theorem the mission proves.
if [ -f test/Axioms.lean ]; then
  out=$(lake env lean test/Axioms.lean 2>&1) || fail "Axioms.lean did not elaborate: $out"
  # #print axioms wraps long lists over continuation lines (leading space);
  # rejoin them so the per-line allowlist grep below stays sound.
  out=$(echo "$out" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n //g')
  echo "$out" | grep -vE "depends on axioms: \[(propext|Classical\.choice|Quot\.sound)(, ?(propext|Classical\.choice|Quot\.sound))*\]" \
    | grep -v "does not depend on any axioms" | grep -v '^\s*$' \
    && fail "theorem with axioms outside allowlist" || true
fi

echo "CI-PASS"
