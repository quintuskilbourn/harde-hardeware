/-
LeanSec.Security — THE AUDITED TRUST ROOT.

Normative counterpart of MODEL_CONTRACT.md (which mirrors Cassiers–Standaert,
TCHES 2021(2):136-158, "Better Safe than Sorry").  Definition numbers in
comments refer to that paper ([CS21]).

POLICY (MODEL_CONTRACT.md §10): this file is written and audited by Claude and
(pending) a human masking expert.  Implementation agents (codex) MUST NOT edit
this file.  Everything here is definitional or a theorem *statement*; proofs
and executable optimizations live in other modules.

Scope (v1): 𝔽₂ (Bool), closed gate library, finite horizons, counting
distributions (no reals, no measure theory).  t = probing order, d = t+1 shares.
-/

namespace LeanSec

/-! ## §1 Structural circuits ([CS21] Defs 1–3, contract §1) -/

/-- Gate kinds.  Sources (`const`, `rnd`, `inp`, `ini`, `ctl`) have no inputs.
`rnd r` = fresh-randomness source with identity `r`;
`inp i j` = share `j` of input sharing `i`;
`ini s` = explicit initial-state source (contract §3);
`ctl c` = PUBLIC control source (a [CS21] Def-1 public parameter): its per-cycle
values are fixed by the security statement's schedule, never free, never secret
(contract §1 v1.2 — added for serial-reuse feedback via `mux`);
`mux` = 2-way multiplexer with public select, inputs ordered [sel, in0, in1],
all latency 0 (the [CS21] MUX2 example; feedback paths must go through it). -/
inductive GateKind where
  | xor | and | not | reg | mux
  | const (b : Bool)
  | rnd (r : Nat)
  | inp (sharing share : Nat)
  | ini (s : Nat)
  | ctl (c : Nat)
deriving DecidableEq, Repr

/-- A structural gate: kind + ordered inputs, each input a (source gate index,
latency) pair ([CS21] Def 1 restricted per contract §1).  `reg` carries latency
1 on its single input; combinational gates carry latency 0. -/
structure Gate where
  kind   : GateKind
  inputs : List (Nat × Nat)
deriving DecidableEq, Repr

/-- A structural circuit ([CS21] Def 3): gates indexed by position. -/
structure Circuit where
  gates : Array Gate
deriving Repr

namespace Circuit

/-- Arity/latency discipline for the closed library. -/
def gateArityOk (g : Gate) : Bool :=
  match g.kind with
  | .xor        => g.inputs.length == 2 && g.inputs.all (·.2 == 0)
  | .and        => g.inputs.length == 2 && g.inputs.all (·.2 == 0)
  | .not        => g.inputs.length == 1 && g.inputs.all (·.2 == 0)
  | .reg        => g.inputs.length == 1 && g.inputs.all (·.2 == 1)
  | .mux        => g.inputs.length == 3 && g.inputs.all (·.2 == 0)
  | _           => g.inputs.length == 0

/-- Combinational (latency-0) out-edges for acyclicity checking. -/
def combEdges (c : Circuit) : List (Nat × Nat) :=
  (c.gates.toList.zipIdx.map fun (g, i) =>
    (g.inputs.filter (·.2 == 0)).map fun (src, _) => (src, i)).flatten

/-- Decidable well-formedness (contract §1): indices in range, arity ok, and
no combinational cycle.  `combAcyclic` is implemented (and proven equivalent to
"no latency-0 cycle") in `LeanSec.Circuit`; here it is only referenced. -/
def indicesOk (c : Circuit) : Bool :=
  c.gates.all fun g => gateArityOk g && g.inputs.all fun (src, _) => src < c.gates.size

end Circuit

/-! ## §2 Execution and evaluation ([CS21] Defs 4–5, contract §2)

The unrolled execution over `horizon` cycles is represented *implicitly*: a
node is a pair `(gateIx, cycle)`, and evaluation recurses through inputs with
`cycle − latency`, reading an `ini` source when the recursion would leave the
horizon (contract §2/§3).  Well-foundedness: lexicographic on (cycle, position
in a combinational topological order); total under `Circuit.WF`. -/

/-- A node of the unrolled execution. -/
structure Node where
  gate  : Nat
  cycle : Nat
deriving DecidableEq, Repr

/-- Source instances an environment must value (contract §2).
`iniReg g` = pre-horizon value read through a `reg` gate `g` (the implicit
initial-state source materialized by unrolling, [CS21] Def 4). -/
inductive Src where
  | inp (sharing share cycle : Nat)
  | rnd (r : Nat) (cycle : Nat)
  | ini (s : Nat) (cycle : Nat)
  | ctl (c : Nat) (cycle : Nat)   -- public control schedule (always pinned)
  | iniReg (gate : Nat)
deriving DecidableEq, Repr

/-- An environment: total valuation of source instances.  Counting statements
quantify over environments restricted to a finite relevant support (computed in
`LeanSec.Execution`), so decidability never needs the full function space. -/
abbrev Env : Type := Src → Bool

/-! The evaluator `eval : Circuit → Env → Node → Bool` is defined in
`LeanSec.Execution` (executable, structural recursion; its termination under
`WF` and agreement with the paper's recursive Def 5 is a theorem there).  The
definitions below are parameterized over any evaluator to keep this file free
of implementation detail; `Security.Statements` instantiates them with the real
one.  This keeps the audited surface small: the *property* shapes live here. -/

/-! ## §3 Observations, probes, expansion ([CS21] Defs 11–12, contract §4) -/

/-- An observation function: what a set of probes reveals under an environment.
For plain probes this is the tuple of node values; expansions replace a probe
by the tuple over its expanded set.  Represented as the list of observed Bools
(order fixed by the probe list). -/
abbrev Observation := List Bool

/-- A probe-expansion scheme ([CS21] Def 12): maps a probe (node) to the set of
nodes actually revealed.  `glitch`, `transition`, `transitionGlitch` are
implemented in `LeanSec.Expansion`; footnote-5 order-independence is a theorem
target there (`expandTG_comm`). -/
abbrev ExpansionScheme := Circuit → Nat → Node → List Node
-- (circuit, horizon, probe) ↦ revealed nodes

/-! ## §4 Distributions as counting (contract §2/§5)

A "distribution" of an observation under a finite set of environments is its
multiset of outcomes; equality of distributions is equality of counts for every
outcome.  `envs` below always ranges over the *finite* enumeration of relevant
assignments (built in `LeanSec.Execution`), never over `Env` at large. -/

/-- Count of environments in `envs` under which `obs` evaluates to `w`. -/
def countObs (envs : List Env) (obs : Env → Observation) (w : Observation) : Nat :=
  envs.countP (fun e => obs e == w)

/-- Distribution equality over two environment lists, cross-multiplied so that
no division/conditioning-on-zero ever occurs (contract §5). -/
def distEq (envs₁ envs₂ : List Env) (obs : Env → Observation) : Prop :=
  ∀ w : Observation,
    envs₂.length * countObs envs₁ obs w = envs₁.length * countObs envs₂ obs w

/-! ## §5 Simulatability ([CS21] Def 13, contract §5)

A randomized simulator over finite spaces is exactly a table assigning to each
input-share valuation a finite multiset (list) of outcomes.  `Simulatable` is
the paper's ∃-simulator form (audited); the executable count-invariance
characterization and the bridging theorem `simulatable_iff_count_invariant`
live outside this file. -/

/-- Input-share index: (sharing, share). -/
abbrev ShareIx := Nat × Nat

/-- Binding v1 simulatability ([CS21] Def 13 over finite spaces).  `xs` enumerates full-input valuations; `envsOf x` the
environments realizing `x`; the simulator table domain is the projected
valuation `projI x`.  Statement: ∃ table `S : List Bool → List Observation`
that is **nonempty on every reached projection** (a simulator denotes a
probability distribution — without this obligation the empty table satisfies
the count equation vacuously, `0·c = N·0`; defect found and kernel-proven by
implementation audit 2026-07-11, v1.1), such that ∀ x ∈ xs the observation
distribution under `envsOf x` equals the distribution of `S (projI x)`
(cross-multiplied count equality; `x` with `envsOf x = []` is unreachable and
stays unconstrained). -/
def SimulatableOn
    (xs : List (List Bool))                 -- full input-share valuations
    (envsOf : List Bool → List Env)         -- environments consistent with x
    (projI : List Bool → List Bool)         -- restriction of x to share set I
    (obs : Env → Observation) : Prop :=
  ∃ S : List Bool → List Observation,
    (∀ x ∈ xs, (S (projI x)).length > 0) ∧
    ∀ x ∈ xs, ∀ w : Observation,
      (S (projI x)).length * countObs (envsOf x) obs w
        = (envsOf x).length * ((S (projI x)).count w)

/-! ## §6 PINI and O-PINI ([CS21] Defs 14, 20, contract §6)

Stated against a `GadgetInstance` (defined in `LeanSec.Gadget`): a circuit,
horizon, input-sharing arrival map, output-sharing node map, share count d,
and the expansion scheme in force.  Here we fix the *shape*; the instantiated
predicates (with the real evaluator and enumerations) are assembled in
`LeanSec.Statements` and must be definitionally faithful to these shapes.

t-PINI ([CS21] Def 14): for all internal-probe sets I (|I| = t₁) and
output-share probe sets O with share-index set A (|A| = t₂), t₁ + t₂ ≤ t,
there exists B, |B| ≤ t₁, such that the observations of I ∪ O are simulatable
from input shares with indexes A ∪ B of every input sharing.

t-O-PINI ([CS21] Def 20): additionally, the simulation jointly produces the
output shares with index in B.  (O-PINI ⇒ PINI; HPC2 separates them.)

These two shapes are the entire security target; Theorem 1 / Corollary 1
(composition) and the gadget leaf theorems are stated about them. -/

/-! ## §7 Honesty policy (contract §10)

Every theorem in this development must satisfy:
  axioms(thm) ⊆ {propext, Classical.choice, Quot.sound}.
No `sorry`, no `native_decide`, no `ofReduceBool`/`ofNat`-code-generator
axioms.  CI enforces via `#print axioms` + lean4checker (scripts/ci.sh). -/

end LeanSec
