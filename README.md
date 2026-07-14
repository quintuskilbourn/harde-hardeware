# leansec — machine-checked side-channel-masking security in Lean 4

**leansec turns exhaustive side-channel-masking security checks into kernel-checked certificates.** Instead of trusting a tool's verdict ("secure"), a masked hardware gadget carries a *Lean theorem* — re-checkable by anyone in seconds with an independent kernel — and the whole trust root is **204 lines of `Security.lean` + the Lean kernel**. Everything else (the circuit generator, the exhaustive verifiers) is *untrusted*: a wrong circuit simply fails to certify.

Target property: **O-PINI** — a *composable* masking notion for the realistic **glitch- + transition-robust** probing model (Cassiers–Standaert, TCHES 2021), designed to stay secure where ordinary composable masking (PINI) can break under transition leakage.

## Headline result

**A kernel-verified O-PINI serial-composition theorem for registered pipelines** (`LeanSec/Composition/Pipeline.lean`). A `PipelineGadget` carries a gadget plus its complete well-behavedness invariant; `compose` provably **reproduces that invariant** (it is a fixpoint under composition — closure), and `compose_pini` proves the composite is PINI *without assuming* the connected-experiment factorization. So `PipelineGadget.probing` gives `probingSecureSpec` for any pipeline prefix, and it instantiates to a concrete secure multi-cycle registered pipeline. As far as we know, we haven't found a prior proof-assistant mechanization of masking composition in the glitch+transition-robust model — though we'd be glad to be pointed to one. Verified: `leanchecker`-clean, axioms `{propext, Classical.choice, Quot.sound}`, 0 `sorry`.

Closure matters because it is a **stopping criterion**: proving `compose` preserves the invariant kernel-certifies the condition set is complete, and it makes chaining gadgets into a full masked datapath a right-fold — no whole-design re-verification.

## What is machine-checked

- **Semantics + trust root** — time-unrolled circuits, glitch/transition probing, simulatability (`Security.lean`, `Execution.lean`, `Expansion.lean`).
- **Gadgets** — DOM-AND and HPC2, faithful to their RTL / the paper's algorithm; recombine to the intended function; NI/SNI/PINI verdicts agree with SILVER; mutants fail.
- **Properties** — `O-PINI ⇒ PINI ⇒ probing`, non-vacuous; and **O-PINI is strictly stronger than PINI** (HPC2 is PINI yet provably *not* O-PINI — a real, machine-checked separation).
- **Transition leak + fix** — a share-reuse wire provably leaks under transitions, is secure under glitch-only, and a register bubble restores security.
- **Netlist correspondence** — DOM-AND & HPC2 parse from real SILVER netlists into the Lean circuit *plus a proof witness*; verdicts match. The Lean↔hardware link is a kernel proof, not a transcription.
- **Fault security** — a first-order fault-injection model + decidable detection (PASS anchor + a silent-fault FAIL mutant).
- **A faster verified checker** — sound against the exact spec, materially cheaper than raw `decide`.
- **Composition** — the register-neutrality lemma (CS21) and the pipeline-closure theorem above.

## Trust model

The Lean kernel checks a proof about a Lean `Circuit`. What you have to *believe* reduces to how far that object corresponds to real silicon:

| Layer | How it's closed | Status |
|---|---|---|
| the proof about the Lean circuit | Lean kernel + `leanchecker`; 204-line `Security.lean` | proved |
| circuit computes the intended function | `recombinesTo`, over all inputs & randomness | proved |
| Lean circuit ↔ reference gadget *leakage* | SILVER differential oracle (independent tool) | cross-checked |
| Lean circuit ↔ real netlist | parse the exact SILVER netlist → Lean circuit + witness | mechanized (DOM-AND & HPC2) |
| netlist ↔ physical GDS | EDA equivalence-check + masking-preserving P&R | out of scope |
| probing model ↔ real power/EM leakage | robust-probing theory + TVLA on silicon | field-standard assumption |

## Layout

```
LeanSec/Security.lean         the ~200-line trust root (hash-pinned)
LeanSec/{Circuit,Execution,Expansion}.lean   semantics
LeanSec/Gadget.lean           GadgetInstance, opini/pini/probing specs, recombinesTo
LeanSec/Gadgets/              DOM-AND, HPC2, O-PINI2, the transition leak/fix
LeanSec/Netlist/              SILVER-netlist front-end + correspondence proofs
LeanSec/Fault/                first-order fault model + detection
LeanSec/Checker/              the faster verified probing checker
LeanSec/Composition/          Serial2, register machinery, Pipeline (the closure theorem)
tools/netlist2lean/           the netlist parser + SILVER reference netlists
oracle/                       SILVER reference netlists + differential-check results
test/Anchors.lean             the standing kernel-checked anchors
```

## Build & verify

```
# Lean toolchain is pinned in lean-toolchain (elan installs it)
lake build                                             # build the whole library (all 53 modules)
lake env leanchecker LeanSec.Composition.Pipeline      # independently re-verify the composition theorem
lake env leanchecker LeanSec.Gadget                    # ...or any other module
```

`leanchecker` re-runs the Lean kernel from scratch over the named module and its
dependencies — a second, independent check that the proofs hold.

A theorem counts as proven only if it builds with **no `sorry`** and its `#print axioms` is a subset of `{propext, Classical.choice, Quot.sound}` (no `native_decide`, no code-generation axioms). `scripts/ci.sh` enforces the trust-root and proof-honesty invariants.

## Status & scope

The composition theorem is proven for **linear pipelines** (a composite is always a downstream stage). This is the right shape for a masked datapath; general tree/DAG composition is future work. Higher masking orders (d ≥ 2), broader gadget/cell-library coverage, combined side-channel + fault (CINI), and a proof-carrying masking compiler are on the roadmap.

## License

Apache-2.0. See [LICENSE](LICENSE).
