# Verification workstream — handoff / methodology

This repo IS the handoff mechanism. Everything an orchestrator or a fresh verification worker needs is here, **except access credentials + infra** (box host, ssh config, cred paths/values) — those are public-repo-forbidden and are supplied to the orchestrator through a private channel; any tooling that touches the compute host is parameterized (host/cred as inputs).

## What this is
A kernel-checked **Lean 4** masking-security framework (probing / PINI / O-PINI in the **glitch + transition-robust** model). It is the verification workstream for a side-channel-masked EVM (the construction workstream, which stipulates *which* property to target and consumes this as a versioned service). Verification makes a target property cheap to achieve and cheap to prove.

## THE acceptance gate — non-negotiable (it caught a real defect on nearly every candidate)
Any worker/loop output is a **CANDIDATE**, never accepted, until it passes all 5 checks — run by the driver, not the producing loop:
1. **Statement genuine** — conclusion is the UNMODIFIED `probingSecureSpec`/`opiniSpec` (built on `LeanSec/Security.lean` §5 `SimulatableOn`); no smuggled hypothesis, no weakened scheme; `Security.lean` sha byte-identical (`72001a4afc61eadeb727bb8adb0163d6cddb34b9f31eb7e64189f3b533e4872c`).
2. **Kernel re-verify** — `lake env leanchecker <module>` exit 0 (not just `lake build`) + `#print axioms` ⊆ {propext, Classical.choice, Quot.sound} + zero `sorry`/`admit`/`native_decide`/`ofReduceBool`.
3. **Non-vacuity** — the checker actually returns `true` on a real secure gadget; gadgets carry `recombinesTo` (real function) + `WF`.
4. **Differential / falsification** — verdicts agree with the trusted checker including an insecure-FALSE case; obstruction anchors are kernel-checked.
5. **Adversarial cross-family** — an independent model (a different LLM family) is prompted to REFUTE the result; must return PASS.

## Build / CI
- `lake build LeanSec.All` co-builds every accepted result module; `lake env leanchecker LeanSec.All` independently kernel-re-verifies. `scripts/ci.sh` runs both + the Security.lean hash pin + the axiom-subset check.
- Gadget verification uses the reflected checkers in `LeanSec/Checker/` (`Fast.lean` splitChecker; `Bitslice.lean` bitsliced checker — ~95× on the whole-circuit case), each proven sound against the spec.

## Harvest flow (worker → aggregate → published)
1. A track runs in isolation, driven by a mission (target + guards + "DONE = candidate, emit gate evidence"; never edit `Security.lean`/audited modules; new files only).
2. Gate it (5 checks). On PASS: add the new modules, wire imports into `LeanSec/All.lean` (before the `/-! Full-verification` doc line), `lake build LeanSec.All` + `leanchecker`, commit.
3. Publish: the aggregate must build + leanchecker-clean; Security.lean byte-identical; no infra/creds in any committed file.

## Loop / mission pattern (parameterized — host/cred injected privately)
- A health-checked worker loop (checks the model credential is live before each iteration, to avoid silent no-op spinning) reads a mission file, iterates until a `DONE`/`STOP` marker, commits each increment, and writes a `RESULT_*.md` with the gate evidence.
- Missions state the target + the mandatory guards and require honest partial/obstruction reporting (a kernel-checked obstruction — e.g. "this gadget is probing-secure but NOT O-PINI, so it can't compose" — is a first-class deliverable, not a failure).

## Current state
Accepted + published: composition serial → tree → reconvergent-DAG → order-1 producer-reuse (`compose_opini`) → **order-2** producer-reuse (`uniformOpiniSpec` discharged at t=2); order-2 DOM-AND; masked full-adder + its kernel-proved carry-not-O-PINI composition obstruction; the bitsliced checker; scan-flop soundness fix; SIFA fault module; hardening (non-degenerate O-PINI instance, generic parser structural witness, CI enforcement, differential coverage). Roadmap: `docs/leansec-augmentation.md`.

## Construction interface (the driver)
`CONSTRUCTION_REQUESTS.md` is the two-way coordination file: construction posts asks + priorities; verification delivers, updates Status, and replies under "Verification responses". Current: **R1 (composition) delivered; R2 (transition-robust A2B/B2A + Zₙ ring multiplier) is the P0** — the private-DEX critical path. Verification's R2 build-order recommendation (A2B/B2A first, ring-mul second; the model-extension situation; staged ETAs) is in `CONSTRUCTION_REQUESTS.md`. Target property: first-order (d=1) — do not speculatively pursue higher orders unless construction asks.

## Next task (P0)
R2 build: O-PINI-ize the full-adder cell → n-bit SecAdd via the composition closure → B2A certificate (first shippable) → A2B (needs the small additive arithmetic-sharing model extension) → ring-mul (design-doc first; do not gate the DEX on it).
