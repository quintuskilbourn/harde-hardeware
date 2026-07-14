# MODEL_CONTRACT.md — normative Lean-facing model (phase 0)

Status: WORKING v1.1, 2026-07-11. Authoritative source: Cassiers &
Standaert, *"Provably Secure Hardware Masking in the Transition- and Glitch-Robust
Probing Model: Better Safe than Sorry"*, TCHES 2021(2):136–158,
DOI 10.46586/tches.v2021.i2.136-158 — cited below as [CS21] with Def/Thm numbers
from the published PDF (read in full this session; local copy in session scratchpad
`opini.pdf`). Human (masking-expert) review: **end-of-project validation, not a
gate** (Quintus 2026-07-11: "we won't get Thorben sign-off until we've finished
the whole thing — don't block on that"). Work proceeds on the differential
guards (oracle agreement + mutants + paper anchors) as the interim adequacy
check; external claims still label the model as internally-validated pending
expert review.

Every definition below is what `Security.lean` formalizes. The Lean names are
binding; a mismatch between this document and `Security.lean` is a bug in one of
them. The LLM implementers (codex) may NOT change this file or `Security.lean`;
changes go through Claude + (eventually) human review.

## 0. Notation and fixed scope

- **t = probing/security order; d = t+1 = number of shares.** First order ⇔ t=1 ⇔
  d=2 shares. ([CS21] uses d=t+1 throughout; our earlier project docs' "d=1" meant
  first order — do not import that usage here.)
- **Field: 𝔽₂ only** (`Bool` with xor/and/not). [CS21] is stated over 𝔽_q;
  O-PINI1/2 only work in 𝔽₂ anyway ([CS21] Remark, §6). Generalization is a later,
  separate contract revision.
- Deterministic gate functions; randomness and inputs enter only via source gates.
- v1 restricts [CS21]'s arbitrary evaluation functions to a **closed gate library**
  (§2) — every gadget we care about (HPC2, O-PINI1/2, DOM, share-isolating linear
  layers) is expressible in it, and a closed inductive type is what makes the
  security predicates decidable-by-construction.

## 1. Structural circuits ([CS21] Defs 1–3)

- **Structural gate** ([CS21] Def 1: (I, P, f, lat)): v1 fixes f by a `GateKind`:
  `xor | and | not | reg | mux | const b | rnd r | inp (i, j) | ini s | ctl c`
  where `rnd r` is a fresh-randomness source (identity `r`), `inp (i,j)` is share
  `j` of input sharing `i`, `ini s` is an **initial-state source** (explicit
  power-up/reset value, see §3), `const b` a public constant. Per-input **latency**
  `lat : Nat` is data on each incoming wire: `reg` has latency 1 on its single
  input; combinational kinds have latency 0 on all inputs. (Keeping `lat` as data,
  not derived, preserves [CS21]'s generality for multi-cycle units later.)
- **v1.2 additions (2026-07-11, serial-reuse escalation):** `mux` = 2-way
  multiplexer, inputs ordered [sel, in0, in1], all latency 0 — [CS21]'s own MUX2
  example with a public select parameter; `ctl c` = **public control source**:
  a [CS21] Def-1 *public parameter* whose per-cycle values are part of the
  security statement's fixed schedule — **always pinned in every experiment,
  never free, never secret** (a statement whose `ctl` schedule is unpinned is
  ill-formed). Rationale: serial gadget reuse (execution 2's operand = execution
  1's output on the SAME physical gates) is expressed as a genuine sequential
  circuit — operand = `mux(ctl-schedule, external-load, feedback-wire)` — which
  preserves physical gate identity across executions, so the audited
  `transitionGlitch` scheme pairs `(w,t−1),(w,t)` correctly at the boundary and
  the serial dependency is real wiring, not an environment hack. SILVER imposes
  the same discipline (feedback must go through multiplexers).
- **Structural wire** (Def 2): (source gate, (dest gate, input position)).
- **Structural circuit** (Def 3): finite digraph of gates+wires with **no
  combinational loop** (no cycle whose wires all have destination latency 0).
  Lean: gates as `Array Gate`, wires by index; acyclicity of the latency-0
  subgraph is a decidable well-formedness predicate `Circuit.WF`.

## 2. Execution and evaluation ([CS21] Defs 4–5)

- **Circuit execution** (Def 4): for a cycle set `T = {t₀, …, t*}` (v1: an
  interval `[0, horizon)`), the unrolled digraph with nodes `G × T`, where wire
  `(w, t)` with destination latency `l` connects `(src, t−l) → (dst, t)`. If the
  source node does not exist (t−l < 0), the wire connects to a fresh **initial
  state** source gate. Lean: `Execution := unroll (c : Circuit) (horizon : Nat)`,
  total by construction; initial-state gates materialize as `ini` sources indexed
  by (gate, cycle).
- **Evaluation** (Def 5): an **environment** assigns Bool values to every source
  instance — input shares (per sharing, per share, per arrival), randomness
  (per `rnd` identity, per execution instance), initial state (per `ini`).
  `eval : Execution → Env → (Node → Bool)` is structural recursion (well-founded
  by acyclicity + time). No ⊥ needed under WF.
- **Experiment space** for a security statement = all environments consistent
  with the statement's fixing of unshared secrets: secrets `x_i = ⊕_j x_{i,j}`
  range over 𝔽₂; sharings uniform conditioned on the secret; `rnd` uniform iid;
  `ini` treated per §3. All distributions are **uniform counting over finite
  environment sets** — no reals, no measure theory. Distribution equality ≔
  preimage-count equality (integer equality per observation value).

## 3. Initial state (explicit decision)

Initial-state (`ini`) sources are **part of the adversary-visible semantics**, not
silently-public constants. v1 default: `ini` values are **fixed public constants
(reset value 0)** for gadget-leaf checks — matching how [CS21]'s gadget analyses
and SILVER treat power-up — BUT the type carries them as sources so a later
statement can quantify over them (secret-correlated retained state). Every leaf
theorem must state which `ini` policy it used. First-cycle probes (t−1 < 0 in a
transition pair) observe the `ini` value, never an undefined.

## 4. Probes and expansion schemes ([CS21] Defs 11–12)

- **Probe**: a node of the execution (gate instance `(g,t)`; input wires are
  covered by their source nodes under the closed library).
- **Probing security** (Def 11): probes `P` in gadget execution `G` are secure iff
  the joint distribution of `eval`-values at `P` is independent of the sensitive
  values (the unshared secrets), over the experiment space. `t`-probing secure ⇔
  secure against every `|P| ≤ t`.
- **Probe-expansion scheme** (Def 12): a function from a probe to a set of probes.
  Three instances, all computable functions on the execution DAG:
  - **glitch**: extended probe of node n = union of extended probes over n's
    latency-0 (combinational) input cone, stopped at registers and sources —
    i.e., the register/source frontier tuple of n's combinational cone.
  - **transition**: probe (w,t) ↦ {(w,t−1), (w,t)} **when both nodes lie in the
    execution window; at the window start (t−1 < 0) the probe stays unexpanded,
    {(w,t)}** — this is [CS21] Def 12 verbatim ("the sets {(w,t−1),(w,t)} … such
    that both (w,t−1) and (w,t) belong to the gadget execution"). There is NO
    pre-window observation point in the model. Soundness note: under the §3
    reset policy the pre-window wire value is a public constant, and observing
    (const, w₀) is observationally equivalent to observing w₀ alone, so
    dropping the boundary pair loses nothing; scenarios with meaningful
    pre-history (retained secrets, back-to-back executions) are modeled by
    ENLARGING THE WINDOW to contain that history — which is exactly the
    iterated-execution machinery (§7). Every anchor statement must therefore
    choose its window to contain all security-relevant history.
    (v1.1 amendment, 2026-07-11: replaces an earlier "t−1 < 0 → ini source"
    line that deviated from Def 12 and was caught by implementation escalation.)
  - **transition+glitch**: transition-expand first, then glitch-expand every
    element. [CS21] footnote 5: expanding glitches first then transitions yields
    the SAME set — this order-independence is a mandatory unit test
    (`test/ExpansionOrder.lean`), not an assumption.
- Robust `t`-probing security w.r.t. a scheme: secure against the expansions of
  every ≤t-subset of adversarial probes.

## 5. Simulatability and its finite characterization ([CS21] Def 13)

- **Simulatability** (Def 13): probes `P` simulatable by input-share set
  `I = {(i₁,j₁),…}` iff ∃ randomized simulator `S` with `dist(G_P(x)) =
  dist(S(x|_I))` for every input assignment `x`.
- **Finite characterization (to be PROVEN in Lean, not assumed):**
  `Simulatable G P I ↔ ∀ x x', x|_I = x'|_I → dist(G_P | x) = dist(G_P | x')`
  (distributions over the non-input randomness; counting equality). The `→`
  direction constructs S by replaying the conditional counts; `←` is direct.
  This lemma (`simulatable_iff_count_invariant`) is the bridge from the
  ∃-simulator definition (declarative, audited) to the executable counting check.
  Zero-probability conditioning never arises: we compare **cross-multiplied
  counts** (`N₁·c₂ = N₂·c₁`), never quotients.
- **Normalization obligation (v1.1, 2026-07-11):** the simulator table must be
  **nonempty on every projection reached by `xs`** — a simulator denotes a
  probability distribution. Without it the empty table satisfies the
  cross-multiplied equation vacuously (`0·c = N·0`), making every observation
  "simulatable" and every PINI/O-PINI predicate vacuously true; this defect was
  found and kernel-proven by the implementation audit and is exactly the
  §"spec certified but vacuous" risk class. Valuations `x` with an empty
  environment set are unreachable and stay unconstrained; the count-invariance
  characterization's reverse direction correspondingly assumes `envsOf x`
  nonempty for reached `x` (the gadget constructor guarantees it — pinned
  sources consistent, free coordinates enumerate).
- **Glitch-robust simulatability** ([CS21] Def 16): same with glitch-expanded
  in-gadget probes, "assuming no glitches on the inputs" — inputs enter as stable
  values; the expansion stops at gadget inputs.
- **Transition-robust simulatability** (Def 17): transition-expanded probes
  restricted to in-gadget nodes (probes outside the gadget are discarded —
  handled at composition).
- **Glitch+transition-robust simulatability** (Def 21): same pattern with the
  combined expansion.

## 6. PINI and O-PINI ([CS21] Defs 14, 20)

For a gadget execution `G` with `d`-share input sharings and output sharings:

- **t-PINI** (Def 14): ∀ internal-probe set `I` (|I| = t₁) and output-share probe
  set `O` with share-index set `A` (|A| = t₂), t₁+t₂ ≤ t: ∃ share-index set `B`,
  |B| ≤ t₁, such that observations `I ∪ O` are simulatable from input shares with
  indexes `A ∪ B` (of every input sharing).
- **t-O-PINI** (Def 20): additionally the simulation must jointly produce the
  **output shares with index in B** (not only the probed `O`). O-PINI ⇒ PINI;
  strict (HPC2 witnesses the separation, §8).
- Robust variants: same statements under the respective expansion scheme via §5.
- ([CS21] footnote 4 / [CGZ20]: a d-share gadget that is (d−1)-PINI is t-PINI for
  all t; same for O-PINI — worth mechanizing as a lemma, it collapses "for any t"
  to one order.)

## 7. Structural gadgets, iteration, pipeline, adjacency ([CS21] Defs 6–10, 18–19, 22)

- **Gadget execution** (Def 6): subset of gates+wires of an execution; inputs =
  wires sourced outside; inputs/outputs partitioned into d-share sharings.
- **Composition** (Def 7): union of disjoint gadget executions, connections
  respect share order, composing-gadget graph is a DAG; **no input of a gadget
  depends on one of its outputs**.
- **Translation** (Def 8) / **structural gadget** (Def 9): set of pairwise
  disjoint, translation-equivalent executions with a canonical execution and
  per-execution canonicalization translations. Lean: canonical execution + a list
  of time-offsets; disjointness and translation-equivalence are decidable checks.
- **Structural composition** (Def 10): executions are unions of the component
  gadgets' executions; components share no structural gate/wire (**physical
  resource identity** — one physical unit reused serially = ONE structural gadget
  with many executions; this is exactly our ISE `msk.and`).
- **Iterated transition-robust simulatability** (Def 18) / **iterated
  glitch+transition-robust** (Def 22): probes of the structural gadget are
  translated into every execution; simulation inputs are the correspondingly
  translated input sets.
- **Pipeline** (Def 19): each structural gate/wire used at most once per
  execution. **Lemma 2**: pipeline ⇒ iterated t-r simulatability reduces to plain
  simulatability (per-execution). HPC2, O-PINI1/2 are pipeline gadgets.
- **v1.2 scope note (phase-2 anchors):** the full structural-gadget/translation
  machinery (Defs 8–10, 18, 22) is **deferred to the composition phases**. The
  phase-2 two-execution anchors are stated as **whole-chain probing security
  under `transitionGlitch`** on an honest sequential circuit (serial reuse via
  `mux`+`ctl` feedback, §1 v1.2) — the same property the transition-SILVER
  oracle measures on its netlist+transition encoding. Anchor theorem names must
  say `chain`/`probing`, NOT "iterated O-PINI" — the iterated-property claims
  wait for the Def-18/22 layer.
- **Adjacency** ([CS21] §5.3.2): executions G_i, G_j adjacent iff ∃ wire w, cycle
  t with (w,t) ∈ G_i and (w,t−1) ∈ G_j. Decidable on the schedule.

## 8. Target theorems and known-answer anchors

To mechanize (in dependency order):
1. **Lemma 1** (glitch-robust composability, [CGLS20] as restated in [CS21]):
   maps simulatability-based compositional strategies into the glitch-robust model.
2. **Theorem 1**: composition of iterated transition-robust t-O-PINI structural
   gadgets is iterated transition-robust t-O-PINI (fixpoint simulator; converges
   because share-index sets grow monotonically, ≤ d).
3. **Corollary 1**: same for **glitch+transition** (Theorem 1 ∘ Lemma 1). ← the
   headline theorem for our target property.
4. **Theorem 2 / Corollary 2** (optional, optimization path): mixed O-PINI + PINI
   with pairwise non-adjacent PINI executions ⇒ glitch+transition-robust t-PINI.
5. **Prop 1/5**: share-isolating structural gadgets are iterated (glitch+)
   transition-robust O-PINI — linear layer for free.

Known-answer anchors (all from [CS21], must reproduce in Lean AND against oracles):
- **HPC2 (Alg 1) is glitch-robust PINI but NOT O-PINI** — the d=3 counterexample
  (probes ā₁⊗r₀₁, ā₂⊗r₂₁ force knowledge of index-1,2 input shares; output c₁
  unsimulatable without b₀). Kernel-check the failure at the smallest order it
  manifests; d=3 if needed, else exhibit the analogous d=2 status per tool runs.
- **O-PINI1 (Alg 2)** = HPC2 + zero-sharing output refresh (s_i fresh for
  i<d−1, s_{d−1}=⊕s_i, c_i = d_i ⊕ s_i): glitch-robust PINI (Prop 2), iterated
  transition-robust t-O-PINI for t<d (Prop 3).
- **O-PINI2 (Alg 3)** = c_i = Reg[d_i ⊕ Reg[s_i]] (registered refresh, extra
  register layer): **iterated glitch+transition-robust t-O-PINI for t<d on 𝔽₂**
  (Prop 6). Costs at d=2 (Table 1): 4 AND, 8 XOR, 2 NOT, 16 Reg, randomness
  d(d−1)/2 + d − 1 = 2 bits, latency (a,b)=(2,3). ← the ISE gadget-of-record
  (Quintus 2026-07-11).
- Serial-reuse counterexamples: Fig 2a (transition-vulnerable serial linear
  gadget), Fig 4a (serial composition of iterated t-r PINI executions leaks).
- Differential-oracle agreement: ordinary SILVER (glitch notions), SILVER
  `transitional-leakage` branch (exact transition+glitch probing), PROLEAD
  (statistical, never confirms PASS).

## 9. Out of model (stated, not hidden)

Coupling leakage; P&R/analog reality (post-synthesis netlist is the object);
PRNG ideality (fresh-iid randomness is an assumption named in every theorem;
reseeding ≠ independence); software obligations of the HW/SW contract; fault
adversaries.

## 10. Proof-honesty policy (kernel-only)

No `sorry`/`admit`. No `native_decide`. No `bv_decide`/`ofReduceBool`-class
code-generator axioms. CI: `#print axioms` transitive closure of every theorem ⊆
{`propext`, `Classical.choice`, `Quot.sound`}; independent `lean4checker` pass.
Executable checkers are used via `decide` (kernel reduction) or via proven-sound
reflection lemmas only.
