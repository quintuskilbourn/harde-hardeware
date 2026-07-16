# A side-channel-proof EVM

**Goal: run Ethereum (EVM) execution inside a trusted enclave so that *nothing* leaks to an attacker who can watch the hardware — not the values, not the timing, not the memory-access pattern.** This repository is the **verification** half of that effort: a Lean framework (`leansec`) that turns "this masked circuit is secure" from a tool's say-so into a machine-checked proof anyone can re-run.

---

## Why this exists

Confidential execution today runs on **TEEs** (Intel SGX/TDX, AMD SEV): the enclave keeps data encrypted in DRAM, but the CPU still computes on **plaintext inside the chip**. That in-chip computation leaks two ways:

- **Physically** — the power draw and EM emanations of a gate depend on the data it switches. Not theoretical: *PLATYPUS* pulled AES keys out of SGX through nothing but the CPU's power interface.
- **Digitally** — how *long* a computation takes and *which* addresses it touches also depend on secrets (an early-exiting divide, a secret-dependent branch or table lookup).

Where the host or a co-tenant is the adversary — **confidential MEV block building** (e.g. BuilderNet), private DeFi, sealed-bid auctions — that residual leakage is the whole game. Cryptographic alternatives (FHE, MPC, ZK) either don't apply (there's no plaintext for a physical channel to attack) or are orders of magnitude too slow for block building. The practical path is a TEE **hardened so its computation is provably leak-free** — which is what this project builds.

## The approach

A **masked RISC-V (RV64) processor running a software EVM**, with two pillars:

**Physical pillar — masking.** Every secret is split into random *shares* (`x = x₀ ⊕ x₁`, `x₀` uniform). Each share alone is pure noise, so a power/EM trace of any single wire reveals nothing. The hardware is redesigned so it *never recombines* the shares — it computes on them separately and only ever un-splits the intended output. This is deceptively hard to get right: one mis-placed register or reused random bit can silently re-join the shares and leak everything — which is exactly why the second half of the project is *proving* it.

**Digital pillar — constant-time + data-oblivious execution.** Masking hides *what* the values are, not *when* or *where* the work happens. A masked divider that runs a data-dependent number of cycles still leaks its operands through latency; a secret-dependent address leaks through the cache. So the datapath is also built to run in secret-independent time and touch secret-independent addresses. (Integer division is excluded from every vendor constant-time guarantee — Intel DOIT, Arm DIT, RISC-V Zkt — so we build a fixed-iteration divider ourselves.)

Two workstreams build it:
- **Construction** — the masked RV64 datapath (adder, multiplier, divider, Keccak, storage) + the software EVM that composes 256-bit opcodes on top.
- **Verification** — *this repo* — the proof that the masking is correct.

## Why verification needs a kernel proof

Masked-hardware verifiers exist (SILVER, PROLEAD, MATCHI) and they're good — but you have to *trust the tool*: its soundness is a paper proof over unverified C++/BDD code. `leansec` closes that gap. Each masked gadget carries a **Lean theorem** that it's secure in the realistic **glitch- and transition-robust probing model** (the model that accounts for a real gate's output glitching mid-cycle, and a register leaking the *difference* between its old and new value). Anyone re-checks that theorem in seconds with an independent kernel; the entire trust root is **~200 lines of `Security.lean` plus the Lean kernel**. Everything else — the circuit generator, the exhaustive checkers — is untrusted: a wrong circuit simply fails to certify.

**The scaling lever.** A processor has thousands of gadgets; re-verifying a whole flattened datapath doesn't scale (the exact tools literally crash on it). The headline result is a **kernel-checked composition theorem** (`LeanSec/Composition/Pipeline.lean`): a gadget carries its complete well-behavedness invariant, and `compose` provably *reproduces* that invariant (closure) — so chaining gadgets into a full datapath is a right-fold with no whole-design re-verification. To our knowledge this is the first kernel-checked masking-composition theorem in the glitch+transition-robust model; concurrent Lean work (Iskander & Kirah, 2026) is value-only (no glitches), and the tool verifiers above are unverified implementations. Pointers to prior work we've missed are welcome.

## Status

**Construction (built + individually verified):** 256-bit masked ADD/SUB, comparisons, **MUL**, **DIV/MOD**, **Keccak-f[1600]** (the full permutation), masked **storage** — and a constant-product **DEX swap** assembled as the first end-to-end anchor. Primitives pass gate-level composition checks (MATCHI) with the negative controls failing as they must; MUL and the arithmetic proofs have cleared an independent adversarial audit.

**Verification (this repo):** kernel-checked O-PINI gadgets (DOM-AND, HPC2, O-PINI2), the composition theorem above, a machine-checked **O-PINI ⊋ PINI** separation (HPC2 is PINI yet provably *not* transition-safe), netlist↔Lean correspondence, a first-order fault model, and a transition-robust **arithmetic island** (Boolean↔arithmetic conversions + a ring multiplier) for the multiplier's fast path.

**The frontier:** whole-*core* verification at scale. A flattened whole-swap netlist is beyond the exact tools, so the swap is discharged by *composition*; the roadmap is a **proof-carrying masking compiler** — a generator that emits masked hardware already carrying its Lean certificate. Higher masking orders (d ≥ 2), combined fault+leakage (CINI), and layout-level couplings (a physical leakage source no logic-level proof can cover — handled by placement constraints + on-silicon TVLA) round out the roadmap.

*(The construction RTL is developed in a separate workstream and tracked here via [`CONSTRUCTION_REQUESTS.md`](CONSTRUCTION_REQUESTS.md); this repo carries the verification framework the constructions are checked against.)*

## What is machine-checked (this repo)

- **Semantics + trust root** — time-unrolled circuits, glitch/transition probing, simulatability (`Security.lean`, `Execution.lean`, `Expansion.lean`).
- **Gadgets** — DOM-AND, HPC2, O-PINI2 faithful to their RTL; recombine to the intended function; NI/SNI/PINI verdicts agree with SILVER; mutants fail.
- **Properties** — `O-PINI ⇒ PINI ⇒ probing`, non-vacuous; and O-PINI *strictly stronger* than PINI (a real machine-checked separation).
- **Transition leak + fix** — a share-reuse wire provably leaks under transitions, is secure glitch-only, and a register bubble restores security.
- **Netlist correspondence** — DOM-AND & HPC2 parse from real SILVER netlists into the Lean circuit *with a proof witness*; the Lean↔hardware link is a kernel proof, not a transcription.
- **Composition** — the register-neutrality lemma (CS21) + the pipeline-closure theorem.

## Trust model

The Lean kernel checks a proof about a Lean `Circuit`; what you must *believe* reduces to how far that object corresponds to real silicon:

| Layer | How it's closed | Status |
|---|---|---|
| the proof about the Lean circuit | Lean kernel + `leanchecker`; ~200-line `Security.lean` | proved |
| circuit computes the intended function | `recombinesTo`, over all inputs & randomness | proved |
| Lean circuit ↔ reference gadget leakage | SILVER differential oracle (independent tool) | cross-checked |
| Lean circuit ↔ real netlist | parse the exact SILVER netlist → Lean circuit + witness | mechanized (DOM-AND & HPC2) |
| netlist ↔ physical GDS | EDA equivalence-check + masking-preserving P&R | out of scope |
| probing model ↔ real power/EM leakage | robust-probing theory + TVLA on silicon | field-standard assumption |

## Layout

```
LeanSec/Security.lean            the ~200-line trust root (hash-pinned)
LeanSec/{Circuit,Execution,Expansion}.lean   semantics
LeanSec/Gadget.lean              specs: opini/pini/probing, recombinesTo
LeanSec/Gadgets/                 DOM-AND, HPC2, O-PINI2, the transition leak/fix
LeanSec/Netlist/                 SILVER-netlist front-end + correspondence proofs
LeanSec/Fault/                   first-order fault model + detection
LeanSec/Checker/                 a faster verified probing checker
LeanSec/Composition/             register machinery + Pipeline (the closure theorem)
tools/netlist2lean/              netlist parser + SILVER reference netlists
oracle/                          SILVER reference netlists + differential-check results
CONSTRUCTION_REQUESTS.md         the construction↔verification coordination surface
```

## Build & verify

```
# Lean toolchain is pinned in lean-toolchain (elan installs it)
lake build                                        # build the whole library
lake env leanchecker LeanSec.Composition.Pipeline # independently re-verify the composition theorem
lake env leanchecker LeanSec.Gadget               # ...or any other module
```

`leanchecker` re-runs the Lean kernel from scratch over a module and its dependencies — a second, independent check. A theorem counts as proven only if it builds with **no `sorry`** and `#print axioms` is a subset of `{propext, Classical.choice, Quot.sound}` (no `native_decide`, no code-gen axioms). `scripts/ci.sh` enforces the trust-root and proof-honesty invariants.

## License

Apache-2.0. See [LICENSE](LICENSE).
