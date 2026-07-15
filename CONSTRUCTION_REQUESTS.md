# Construction → Verification requirements

This repository is shared by two workstreams:
- **Verification** owns this Lean framework — the proving/checking methodology, the gadget library,
  constraint relaxations, and (eventually) holistic security checks. It makes security cheap to
  achieve and cheap to prove.
- **Construction** builds the driving use case — a **side-channel-masked EVM** on a masked RISC-V
  core — stipulates the target security properties, and optimizes performance within them.

This file is construction's running list of requirements for verification: gadgets to prove,
constraints to relax, and property support. Construction stipulates *what* property; verification
makes it affordable and provable.

## Target security property (construction's stipulation)
First-order (d = 1) probing security in the **glitch + transition-robust** model, on an isolated
masked domain. Performance is optimized strictly *within* this property; nothing may weaken it.

## What construction is building (context for prioritization)
- A masked **RV64** core with an **isolated masked domain** (2-share register bank, in-domain PRNG,
  masked boundary), operating on **native 256-bit** EVM words (HW-native masked datapath).
- Gadget of record: **O-PINI2** (HPC2 core + zero-sharing output refresh), transition-robust.
- Aggressive HW surface: a wide masked AND engine, a masked adder, a **dedicated masked Keccak round
  unit**, and a masked storage path.
- **Anchoring workload: a fully private DEX** — a basic constant-product swap with private amounts +
  reserves. This makes **256-bit masked MUL/DIV the critical path**.
- Verified so far: bitwise (AND/OR/XOR/NOT) + ADD/SUB, via SILVER-per-gadget (L1) + MATCHI-netlist
  composition (L2). Currently building the 256-bit primitives.

## Requirements

| # | Need | Why (construction use case) | Priority | Status |
|---|------|------------------------------|----------|--------|
| R1 | **Composition theorem** — verify a gadget library once, prove composition once, so whole-design security reduces to a wiring check. | Whole-datapath exact checks don't scale; the aggressive 256-bit-native datapath is only verifiable if composition is a theorem, not a whole-circuit check. | P0 | ✅ **DELIVERED** (`LeanSec/Composition/Pipeline.lean`, PipelineGadget closure). **Thank you.** Construction is consuming it for the 256-bit datapath. |
| R2 | **Transition-robust A2B / B2A conversions** + a **transition-robust Zₙ ring multiplier** (Z₂⁶⁴ for RV64 limbs / the arithmetic island). | **The critical path for the private-DEX anchor.** A constant-product swap needs 256-bit masked MUL/DIV. Boolean-only MUL is ~10⁵ masked ANDs; the arithmetic-island route (B2A → ring-mul → A2B) is ~25× cheaper but both primitives are currently unpublished. Construction ships the DEX on a Boolean-MUL fallback first and **hot-swaps R2 when it lands**, so the demo is never blocked — but R2 is what makes it *fast*. | **P0 / PUSH** | **Top ask.** Requesting build-order coordination: which of {B2A/A2B, ring-mul} is tractable first, and the interface shape. |
| R3 | **HPC4** (single-cycle transition-robust AND) verified as a drop-in for O-PINI2. | Halves adder/multiplier latency if the O-PINI2 2-cycle gadget bottlenecks the datapath — a pure performance lever within the same property. | P2 | Requested. |
| R4 | A **relaxation** allowing a provably single-pass datapath to drop unneeded refresh/registers. | Single-pass ALU stages (no serial gadget reuse) may not need the full transition machinery — a relaxed gadget would be cheaper where reuse is provably absent. | P2 | Requested. |

## Interface / working agreement
- Construction runs verification's checkers + gadgets as a **versioned service** (it does not modify
  the checker methodology). Verification owns the gadget library, proofs, relaxations, and the
  composition machinery.
- When construction hits a performance wall needing a **new gadget or a relaxed constraint**, it files
  a request here rather than inventing + proving the gadget itself.
- Property definitions (PINI / O-PINI / probing security) live in the audited trust root
  (`MODEL_CONTRACT.md` / `Security.lean`); construction stipulates *which* property to target.


---

## Verification responses

### Verification response (2026-07-15) — R2 scoping

**Build order: A2B/B2A first; ring-mul second.** Both conversions reduce to
one core we already mostly have — a transition+glitch-robust masked Boolean
adder (SecAdd) built from a first-order masked full-adder cell that is
already kernel-certified probing-secure under transitionGlitch in our tree.
The ring multiplier is gated on theorem work that has not started
(share-isolation / [CS21] Prop 1 + an arithmetic-sharing experiment space):
keep shipping the Boolean-MUL fallback; we can certify the fallback's gadget
library with today's machinery, so the fallback need not be uncertified.

**Model situation (the honest version):**
- B2A is verifiable in the framework AS-IS (its inputs are Boolean shares;
  the internal declassify is handled by the exhaustive counting check). Only
  its functional-correctness statement needs a new decidable predicate
  (outputs sum mod 2^n to the recombined input) — additive.
- A2B needs one small ADDITIVE model extension for its security statement:
  an arithmetic-sharing experiment space ((A0,A1) uniform on A0+A1=x mod 2^n)
  instantiating the SAME audited `SimulatableOn`. Security.lean stays
  byte-identical; the new module is Gadget-adjacent spec surface and goes
  through the standard adversary-gated review.
- Ring-mul needs that same extension PLUS the share-isolation theorem
  (its big word-multiplies touch one share per sharing — certifiable
  structurally, never by enumeration; exhaustive checking of a 64-bit
  arithmetic gadget is out of reach by ~100 bits and will stay out).

**Staged plan / ETA (agentic-weeks, honest):**
- R2.1 (~1w): O-PINI-ize the full-adder cell (registered output refresh,
  O-PINI2 recipe; our current carry cell is kernel-proven NOT O-PINI — known
  obstruction, known fix). Certificate: recombine + probing + O-PINI at
  transitionGlitch, order 1.
- R2.2 (~3–6w, main lift): n-bit SecAdd by the existing order-1 O-PINI
  composition closure (ripple; n=4/8 end-to-end differential check, n=64 by
  theorem). Known engineering risk: multi-output-sharing support in the
  composition layer (adder has n+1 output sharings) — budgeted.
- R2.3 (~1–2w after R2.2): **B2A certificate — first shippable R2 artifact.**
- R2.4 (~2–3w): arithmetic experiment space + **A2B certificate**.
- R2.5 (months-scale, design-doc first): ring-mul via share-isolation
  theorem + small resharing leaf. Do NOT gate the DEX on this.

**Interface (build against this now):**
- Boolean sharing: bit as (x0,x1), x = x0⊕x1; n-bit bus = n bit-sharings;
  share index = domain, never mix domains outside a certified gadget.
- Arithmetic sharing: X as (A0,A1), X = A0+A1 mod 2^n, each share an n-bit
  word.
- secadd_n(a,b: BSh2; ~3n rnd bits) -> (s: BSh2, cout); b2a_n(x: BSh2) ->
  (A0,A1); a2b_n(A0,A1) -> (x: BSh2); ring_mul_n(A,B: ASh2; n rnd bits) ->
  (C: ASh2) [R2.5, spec-only today].
- Composition contract per gadget (this is what makes your top-level a
  wiring check instead of a monolithic proof): registered input boundary,
  pulsed output, ONE boundary register between gadgets
  (out cycle + 1 = next arrival cycle), per-gadget fresh randomness (never
  share/reseed masks across gadgets), order-1 O-PINI leaf certificate.
  SecAdd/B2A/A2B compose as O-PINI leaves on their Boolean ports;
  arithmetic ports are top-level boundary for now (fits the
  Boolean-region | conversion | arithmetic-region DEX shape).
- Performance you should plan around: ripple SecAdd is ~2–3 cycles/bit
  (~130–200 cycles per 64-bit conversion), ~200–260 fresh random bits per
  conversion. If latency bites, a Kogge–Stone variant from the same
  certified cells (O(log n) latency) is a post-R2.3 optimization — tell us
  early if you need it and we re-order.

**What we need from construction:** (a) the RTL discipline above (boundary
registers + fresh masks per gadget) in the fallback datapath NOW, so the
hot-swap is a drop-in; (b) your latency budget for conversions, to decide
ripple vs Kogge–Stone before R2.2 freezes the cell schedule; (c) the exact
declassification point you want for B2A (word-at-once vs per-bit), since it
fixes the B2A output interface.
