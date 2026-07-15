# Workstream D result: the requested universal theorem is not justified by the current interface

Reassessed on 2026-07-13 against the current workspace.  The obstruction
remains structural; all Composition modules and their axiom audit build.

The requested universal theorem is **not proved**.  `ConcreteSerial2.lean`
still proves the hypothesis-free concrete closure, but the present types do
not specify enough structure to define and verify a total, honest

```lean
glue (upstream downstream : GadgetInstance) (compat : ...) : GadgetInstance
```

for arbitrary O-PINI `GadgetInstance`s.  Defining `glue` as a constant secure
gadget (or as one component) would satisfy an insufficiently constrained Lean
statement while not being serial composition, so that route was deliberately
not used.  The kernel-checked results in `GenericSerial2.lean` separate a
missing order premise from the structural representation gap.

## 1. The literal O-PINI implication needs `t < d`

The one-share identity gadget is O-PINI at order one but is not probing secure
at order one:

```lean
theorem identity_opini_order_one :
    opiniSpec identity transitionGlitch 1

theorem identity_not_probing_order_one :
    ¬ probingSecureSpec identity transitionGlitch 1

theorem opini_does_not_imply_probing_at_full_share_order :
    ∃ g, opiniSpec g transitionGlitch 1 ∧
      ¬ probingSecureSpec g transitionGlitch 1
```

An O-PINI simulator may request the only output share, while a probing
adversary seeing that share sees the secret.  Consequently the literal pair
of O-PINI hypotheses in the requested final formula is insufficient; an
honest CS21 theorem must additionally constrain the order.  This is why the existing
`pini_implies_probing` theorem requires `t < d` and why an honest CS21
compatibility record must include the masking-order condition (normally
`d = t + 1`) and equal share counts.

The witness uses a canonical source input, has no randomness, and satisfies
`GadgetInstance.WF`; the serial freshness laws do not repair this failure.

## 2. O-PINI supplies no node-level input port

The new predicate

```lean
def InputArrivalHasMemberNode (g : GadgetInstance)
    (input share : Nat) : Prop :=
  ∃ node ∈ memberNodes g, ∀ env,
    Execution.eval g.circuit g.horizon env node =
      env (g.inputArrival input share)
```

states the minimum semantic association a structural glue would need before
it could identify a downstream input arrival with an upstream output node.
The current interface does not guarantee even this much.  The
`orphanInput` gadget is well formed and O-PINI, but its declared input source
does not occur in its constant circuit:

```lean
theorem orphanInput_opini_zero :
    opiniSpec orphanInput transitionGlitch 0

theorem orphanInput_arrival_has_no_member_node :
    ¬ InputArrivalHasMemberNode orphanInput 0 0

theorem opini_does_not_supply_input_member_node :
    ∃ g, opiniSpec g transitionGlitch 0 ∧
      ¬ InputArrivalHasMemberNode g 0 0
```

Thus O-PINI alone cannot supply a node-level port map to `glue`.  An unused
orphan input could legitimately remain unused, so this witness by itself is
not claimed to refute every possible compiler.  It does prove that either
`compat` must carry explicit structural occurrence/consumer information, or a
compiler must analyze every possible `Src` representation rather than merely
consume the O-PINI certificates.  A value-level equality still does not
identify the consumer edges needed for a structural circuit rewrite.

This is not only an order-zero corner case. A second witness has two shares,
is O-PINI at order one, satisfies the standard strict order premise, and still
has no structural node for its declared input:

```lean
theorem opini_order_one_does_not_supply_input_member_node :
    ∃ g : GadgetInstance,
      1 < g.d ∧
      opiniSpec g transitionGlitch 1 ∧
      ¬ InputArrivalHasMemberNode g 0 0

theorem no_universal_opini_input_member_selector :
    ¬ ∃ selectInputNode : GadgetInstance → Node,
      ∀ g : GadgetInstance, 1 < g.d →
        opiniSpec g transitionGlitch 1 →
        selectInputNode g ∈ memberNodes g ∧
          ∀ env,
            Execution.eval g.circuit g.horizon env (selectInputNode g) =
              env (g.inputArrival 0 0)
```

The selector theorem is the direct generic consequence: even after imposing
the standard strict masking-order premise, no node-selection phase for a
structural glue can be justified from the two advertised gadget certificates.
Compatibility would have to add structural port/consumer data not present in
`GadgetInstance`; O-PINI cannot derive it.

## 3. Structural edges cannot splice one cycle-indexed arrival

The sharper mismatch is kernel-checked by:

```lean
def edgePredecessorAt (cycle : Nat) (input : Nat × Nat) : Option Node

theorem edgePredecessorAt_succ_of_eq ... :
  edgePredecessorAt cycle input = some source →
  edgePredecessorAt (cycle + 1) input =
    some { gate := source.gate, cycle := source.cycle + 1 }
```

One structural edge is reused at every cycle.  If edge replacement connects
an upstream node at the arrival cycle, it necessarily connects the same
upstream gate at the adjacent cycle too.  In contrast:

- `output : Nat → Node` names one unrolled node, including its cycle.
- `inputArrival : Nat → Nat → Src` names one environment source
  instance, also including its cycle.
- A circuit source gate is only `GateKind.inp sharing share`; evaluation
  reads a different cycle-indexed `Src.inp` from that same gate at every
  cycle of the horizon.
- Circuit edges contain a gate index and a fixed latency.  They cannot target
  an arbitrary unrolled `Node` or `Src` instance.

Replacing a downstream input gate therefore rewires that gate at every
cycle, not just the source instance named by `inputArrival`.  Rewriting its
consumer edges has the same issue because an edge is reused at every cycle.
This mismatch arises before the three serial side laws can be proved by
construction.

Time-unrolling into one new gate per node is not semantics-preserving for the
requested `transitionGlitch` theorem without a substantial new transport
proof: transition expansion observes the previous-cycle node with the same
gate index, while glitch expansion follows the original circuit
predecessors.  Splitting gates by cycle changes both structures and prevents
direct reuse of the component O-PINI certificates.

A public-control `mux` does not provide a local workaround.  It can select an
embedded upstream gate only at the declared arrival cycle, but `glitchGates`
follows every latency-zero input of a mux independently of the selected public
branch.  A transition-glitch probe downstream of that mux therefore observes
both the embedded upstream cone and the old external-input cone.  This is not
the isolated downstream experiment certified by its O-PINI hypothesis, so it
again requires a new expansion/experiment transport theorem rather than
making the assembler's connected-experiment premise true by definitional
reduction.

`ConcreteSerial2` succeeds because its horizon is one and all source gates,
consumer edges, output nodes, and namespaces are explicitly known.  It does
not provide an algorithm that can recover missing port data from an arbitrary
`GadgetInstance`.

## 4. Randomness relabeling does not close the port gap

A namespace transform can be designed, but in this model `randomness` is a
list of arbitrary `Src` values, not merely `Src.rnd`.  A correct downstream
transport must rename in lockstep:

- source identifiers in every source `GateKind`;
- `.rnd`, `.inp`, `.ini`, `.ctl`, and `.iniReg` occurrences in
  `randomness`, `publicFixing`, and `inputArrival`;
- gate indices and every edge when the downstream circuit is appended; and
- `.iniReg` sources whose identities are tied to those gate indices.

The repository has no O-PINI equivariance theorem for this combined
circuit/node/source renaming.  Such a theorem is feasible future work, but it
would only establish fresh namespaces; it cannot manufacture the absent
downstream input node and consumer relation.

## 5. Minimal route to the universal theorem

An honest full construction needs one of the following interface-level
developments, outside the permitted `LeanSec/Composition/*` edit scope:

1. Extend `GadgetInstance` with explicit unrolled input-port nodes and a
   structural consumer/coherence law relating those nodes to
   `inputArrival`; or
2. Define composition on an explicit unrolled execution graph whose edges
   connect `Node` values, then prove evaluator and `transitionGlitch`
   transport theorems between that graph and `GadgetInstance` circuits.

After that, compatibility can state `d = t + 1`, equal horizons/share counts,
and the chosen connected port.  A namespace transform can make component
randomness disjoint by construction, and evaluator/expansion transport plus
an experiment-factorization theorem can discharge the continuation of
`serial2_opini_connected_experiment_simulatable`.

Putting the evaluator factorization or the final connected-experiment
permutation directly into `compat` was not done: that would reintroduce the
required side law as a free hypothesis rather than prove it from `glue`.

## Verification

- `lake build LeanSec.Composition.GenericSerial2`: succeeds.
- `lake build LeanSec.Composition.ConcreteSerial2`: succeeds.
- `lake build LeanSec.Composition.Axioms`: succeeds.
- No `sorry` or declared `axiom` occurs in `LeanSec/Composition/*.lean`.
- Printed axiom sets, including `edgePredecessorAt_succ_of_eq`, are subsets of
  `{propext, Classical.choice, Quot.sound}`.
