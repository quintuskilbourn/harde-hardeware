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
