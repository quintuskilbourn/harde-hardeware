import LeanSec.Composition.ConcreteSerial2

namespace LeanSec
namespace Composition
namespace GenericSerial2

open Gadget

/-!
This module records a sharp obstruction to the universal statement without
the usual masking-order premise `t < d`.  The one-share identity gadget is
O-PINI at order one: an O-PINI simulator is allowed to request its sole output
share.  It is not probing secure at order one, because that same share is the
secret.

The example is intentionally canonical: its input arrival is the source read
by its only input gate, its output is an in-window member, and it uses no
randomness.  Thus the failure is not caused by the three serial freshness laws.
-/

def identityCircuit : Circuit :=
  { gates := #[{ kind := .inp 0 0, inputs := [] }] }

def identity : GadgetInstance :=
  { circuit := identityCircuit
    horizon := 1
    d := 1
    inputCount := 1
    inputArrival := fun _ _ => .inp 0 0 0
    output := fun _ => { gate := 0, cycle := 0 }
    member := fun node => node == ({ gate := 0, cycle := 0 } : Node)
    randomness := [] }

theorem identity_wf : identity.WF := by
  simp [identity, identityCircuit, GadgetInstance.WF, Circuit.WF,
    Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
    Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred, outputNodes, memberNodes, nodes,
    combInputNodes, transInputNodes]

theorem identity_inputs_reached :
    ∀ x ∈ boolVectors (inputWidth identity),
      (envsForInput identity x).length > 0 := by
  intro x hx
  apply List.length_pos_iff.mpr
  exact envsForInput_ne_nil_of_valid identity x
    (fixingForInput_valid identity x)

theorem identity_opini_order_one :
    opiniSpec identity transitionGlitch 1 := by
  apply (opini_iff_spec identity transitionGlitch 1
    identity_inputs_reached).mp
  refine ⟨identity_wf, ?_⟩
  intro internal hinternal
  have hinternalNil : internal = [] := by
    exact List.sublist_nil.mp
      (subsetsUpTo_sublist 1 (internalNodes identity) internal hinternal |>.trans
        (by simp [identity, identityCircuit, internalNodes, memberNodes, nodes,
          outputNodes]))
  subst internal
  intro outputs houtputs
  have houtputsCases : outputs = [] ∨ outputs = [0] := by
    have hsub := subsetsUpTo_sublist 1 (List.range identity.d) outputs houtputs
    have hlength := hsub.length_le
    cases outputs with
    | nil => exact Or.inl rfl
    | cons head tail =>
        have hhead : head = 0 := by
          have : head ∈ [0] := by
            apply hsub.mem
            simp
          simpa using this
        subst head
        have htail : tail = [] := by
          cases tail with
          | nil => rfl
          | cons next rest => simp [identity] at hlength
        subst tail
        exact Or.inr rfl
  rcases houtputsCases with rfl | rfl
  · refine ⟨[], by simp [subsetsUpTo, combinations], ?_⟩
    intro x hx y hy _ w
    cases w <;> simp [identity, identityCircuit, expandedNodes, observe,
      countObs, Nat.mul_comm]
  · refine ⟨[], by simp [subsetsUpTo, combinations], ?_⟩
    intro x hx y hy hprojection
    have hxCases : x = [false] ∨ x = [true] := by
      simpa [identity, boolVectors, inputWidth] using hx
    have hyCases : y = [false] ∨ y = [true] := by
      simpa [identity, boolVectors, inputWidth] using hy
    have hxy : x = y := by
      rcases hxCases with rfl | rfl <;> rcases hyCases with rfl | rfl
      <;> simp [identity, projection, inputBit, inputPosition] at hprojection ⊢
    subst y
    exact distEq_refl _ _

theorem identity_secrets_reached :
    ∀ secret ∈ boolVectors identity.inputCount,
      (envsForSecret identity secret).length > 0 := by
  intro secret hsecret
  apply List.length_pos_iff.mpr
  have hcases : secret = [false] ∨ secret = [true] := by
    simpa [identity, boolVectors] using hsecret
  rcases hcases with rfl | rfl
  · exact envsForSecret_ne_nil_of_input identity [false] [false]
      (by decide) (by decide)
      (envsForInput_ne_nil_of_valid identity [false]
        (fixingForInput_valid identity [false]))
  · exact envsForSecret_ne_nil_of_input identity [true] [true]
      (by decide) (by decide)
      (envsForInput_ne_nil_of_valid identity [true]
        (fixingForInput_valid identity [true]))

theorem identity_not_probing_order_one :
    ¬ probingSecureSpec identity transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure identity transitionGlitch 1 :=
    (probingSecure_iff_spec identity transitionGlitch 1
      identity_secrets_reached).mpr hsecure
  exact (by decide : ¬ probingSecure identity transitionGlitch 1) hexecutable

/-- O-PINI alone cannot imply probing security at an order which reaches all
shares.  Any universal serial theorem must include `t < d` (normally
`d = t + 1`) in its compatibility data. -/
theorem opini_does_not_imply_probing_at_full_share_order :
    ∃ g : GadgetInstance,
      opiniSpec g transitionGlitch 1 ∧
      ¬ probingSecureSpec g transitionGlitch 1 :=
  ⟨identity, identity_opini_order_one, identity_not_probing_order_one⟩

/-!
The second obstruction is structural rather than an order issue.  A generic
glue needs a node which it can identify with every connected input share.
`GadgetInstance.inputArrival` does not provide one: it is only a `Src` used by
the experiment fixing, and neither `GadgetInstance.WF` nor O-PINI requires the
source to occur in the circuit at all.
-/

/-- The node-level datum a structural glue would need for one declared input
arrival.  This deliberately asks for equality in every environment, so it is
independent of a particular experiment fixing. -/
def InputArrivalHasMemberNode (g : GadgetInstance)
    (input share : Nat) : Prop :=
  ∃ node ∈ memberNodes g, ∀ env,
    Execution.eval g.circuit g.horizon env node =
      env (g.inputArrival input share)

private def orphanInputCircuit : Circuit :=
  { gates := #[{ kind := .const false, inputs := [] }] }

/-- A well-formed gadget whose declared input arrival is not read by its
circuit.  This is legal under the current `GadgetInstance` interface. -/
def orphanInput : GadgetInstance :=
  { circuit := orphanInputCircuit
    horizon := 1
    d := 1
    inputCount := 1
    inputArrival := fun _ _ => .inp 7 0 0
    output := fun _ => { gate := 0, cycle := 0 }
    member := fun node => node == ({ gate := 0, cycle := 0 } : Node)
    randomness := [] }

theorem orphanInput_wf : orphanInput.WF := by
  simp [orphanInput, orphanInputCircuit, GadgetInstance.WF, Circuit.WF,
    Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
    Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred, outputNodes, memberNodes, nodes,
    combInputNodes, transInputNodes]

theorem orphanInput_opini_zero :
    opiniSpec orphanInput transitionGlitch 0 :=
  opiniSpec_zero orphanInput transitionGlitch orphanInput_wf

theorem orphanInput_arrival_has_no_member_node :
    ¬ InputArrivalHasMemberNode orphanInput 0 0 := by
  rintro ⟨node, hnode, hall⟩
  have hnode' : node = ({ gate := 0, cycle := 0 } : Node) := by
    simpa [orphanInput, orphanInputCircuit, memberNodes, nodes] using hnode
  subst node
  have heq := hall (Execution.envFrom [(.inp 7 0 0, true)])
  change false = true at heq
  contradiction

/-- O-PINI and well-formedness do not recover the node-level input-port map
which a generic structural glue would have to consume. -/
theorem opini_does_not_supply_input_member_node :
    ∃ g : GadgetInstance,
      opiniSpec g transitionGlitch 0 ∧
      ¬ InputArrivalHasMemberNode g 0 0 :=
  ⟨orphanInput, orphanInput_opini_zero,
    orphanInput_arrival_has_no_member_node⟩

/-!
The same interface failure occurs at the first nontrivial masking order with
the standard strict order premise.  This rules out treating the order-zero
witness above as a degenerate corner case.
-/

private def orphanInputOrderOneCircuit : Circuit :=
  { gates := #[
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] }
    ] }

/-- A two-share, order-one constant gadget.  Its declared two-share input is
again absent from the structural circuit. -/
def orphanInputOrderOne : GadgetInstance :=
  { circuit := orphanInputOrderOneCircuit
    horizon := 1
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 7 share 0
    output := fun share =>
      if share = 0 then { gate := 0, cycle := 0 }
      else { gate := 1, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 2
    randomness := [] }

theorem orphanInputOrderOne_wf : orphanInputOrderOne.WF := by
  refine ⟨?_, by decide, ?_, ?_, ?_, ?_⟩
  · simp [orphanInputOrderOne, orphanInputOrderOneCircuit, Circuit.WF,
      Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
      Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
      Circuit.hasRemainingPred]
  · change ([({ gate := 0, cycle := 0 } : Node),
        ({ gate := 1, cycle := 0 } : Node)]).Nodup
    decide
  · simp [outputNodes, memberNodes, nodes, orphanInputOrderOne,
      orphanInputOrderOneCircuit]
    intro share hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl <;> simp
  · simp [memberNodes, nodes, combInputNodes, orphanInputOrderOne,
      orphanInputOrderOneCircuit]
    intro gate hgate
    have : gate = 0 ∨ gate = 1 := by omega
    rcases this with rfl | rfl <;> simp
  · simp [memberNodes, nodes, transInputNodes, orphanInputOrderOne,
      orphanInputOrderOneCircuit]

theorem orphanInputOrderOne_inputs_reached :
    ∀ x ∈ boolVectors (inputWidth orphanInputOrderOne),
      (envsForInput orphanInputOrderOne x).length > 0 := by
  intro x hx
  apply List.length_pos_iff.mpr
  exact envsForInput_ne_nil_of_valid orphanInputOrderOne x
    (fixingForInput_valid orphanInputOrderOne x)

theorem orphanInputOrderOne_opini :
    opiniSpec orphanInputOrderOne transitionGlitch 1 := by
  apply (opini_iff_spec orphanInputOrderOne transitionGlitch 1
    orphanInputOrderOne_inputs_reached).mp
  exact ⟨orphanInputOrderOne_wf, by decide⟩

theorem orphanInputOrderOne_arrival_has_no_member_node :
    ¬ InputArrivalHasMemberNode orphanInputOrderOne 0 0 := by
  rintro ⟨node, hnode, hall⟩
  have hnodeCases :
      node = ({ gate := 0, cycle := 0 } : Node) ∨
      node = ({ gate := 1, cycle := 0 } : Node) := by
    simp [orphanInputOrderOne, orphanInputOrderOneCircuit, memberNodes,
      nodes] at hnode
    rcases hnode with ⟨⟨gate, hgate, rfl⟩, -, -⟩
    have : gate = 0 ∨ gate = 1 := by omega
    rcases this with rfl | rfl <;> simp
  rcases hnodeCases with rfl | rfl
  · exact (by decide :
      Execution.eval orphanInputOrderOne.circuit orphanInputOrderOne.horizon
          (Execution.envFrom [(.inp 7 0 0, true)])
          { gate := 0, cycle := 0 } ≠
        Execution.envFrom [(.inp 7 0 0, true)]
          (orphanInputOrderOne.inputArrival 0 0))
      (hall (Execution.envFrom [(.inp 7 0 0, true)]))
  · exact (by decide :
      Execution.eval orphanInputOrderOne.circuit orphanInputOrderOne.horizon
          (Execution.envFrom [(.inp 7 0 0, true)])
          { gate := 1, cycle := 0 } ≠
        Execution.envFrom [(.inp 7 0 0, true)]
          (orphanInputOrderOne.inputArrival 0 0))
      (hall (Execution.envFrom [(.inp 7 0 0, true)]))

/-- Even under `t < d`, O-PINI does not provide the structural input port
required by an honest serial splice. -/
theorem opini_order_one_does_not_supply_input_member_node :
    ∃ g : GadgetInstance,
      1 < g.d ∧
      opiniSpec g transitionGlitch 1 ∧
      ¬ InputArrivalHasMemberNode g 0 0 :=
  ⟨orphanInputOrderOne, by decide, orphanInputOrderOne_opini,
    orphanInputOrderOne_arrival_has_no_member_node⟩

/-- There is no generic structural-port selector whose correctness can be
derived from strict-order O-PINI.  In particular, a generic glue cannot begin
by choosing a member node that realizes the downstream arrival: the
`orphanInputOrderOne` certificate satisfies the usual `t < d` premise but has
no such node. -/
theorem no_universal_opini_input_member_selector :
    ¬ ∃ selectInputNode : GadgetInstance → Node,
      ∀ g : GadgetInstance, 1 < g.d →
        opiniSpec g transitionGlitch 1 →
        selectInputNode g ∈ memberNodes g ∧
          ∀ env,
            Execution.eval g.circuit g.horizon env (selectInputNode g) =
              env (g.inputArrival 0 0) := by
  rintro ⟨selectInputNode, hselect⟩
  have hport := hselect orphanInputOrderOne (by decide)
    orphanInputOrderOne_opini
  exact orphanInputOrderOne_arrival_has_no_member_node
    ⟨selectInputNode orphanInputOrderOne, hport.1, hport.2⟩

/-!
The orphan witnesses rule out obtaining a node-level port map from O-PINI,
but an unused orphan input could simply remain unused in a total compiler.
The cycle mismatch below is the sharper obstruction to a structural splice.
An input of a `Gate` is one `(gate, latency)` pair reused at every cycle,
whereas `GadgetInstance.inputArrival` selects one cycle-indexed `Src`.
-/

/-- The unrolled predecessor denoted by one structural gate input at a given
cycle.  This is the node-level part of `Execution.inputValue`. -/
def edgePredecessorAt (cycle : Nat) (input : Nat × Nat) : Option Node :=
  if input.2 ≤ cycle then
    some { gate := input.1, cycle := cycle - input.2 }
  else
    none

/-- A structural edge that reads `source` at `cycle` necessarily reads the
same gate one cycle later at `cycle + 1`.  Thus ordinary edge replacement
cannot identify only the single source instance named by `inputArrival`.
Any such replacement also changes the adjacent-cycle execution. -/
theorem edgePredecessorAt_succ_of_eq
    (cycle : Nat) (input : Nat × Nat) (source : Node)
    (hread : edgePredecessorAt cycle input = some source) :
    edgePredecessorAt (cycle + 1) input =
      some { gate := source.gate, cycle := source.cycle + 1 } := by
  rcases input with ⟨gate, latency⟩
  rcases source with ⟨sourceGate, sourceCycle⟩
  unfold edgePredecessorAt at hread ⊢
  split at hread
  next hlatency =>
    simp only [Option.some.injEq, Node.mk.injEq] at hread
    have hlatency' : latency ≤ cycle + 1 := by omega
    rw [if_pos hlatency']
    simp only [Option.some.injEq, Node.mk.injEq]
    omega
  next _ => contradiction

end GenericSerial2
end Composition
end LeanSec
