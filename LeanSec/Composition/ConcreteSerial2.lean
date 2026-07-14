import LeanSec.Composition.Serial2

namespace LeanSec
namespace Composition
namespace ConcreteSerial2

open Gadget

/-!
This file gives a small, completely concrete instance of serial composition.
It is deliberately separate from `Serial2Wiring`: the latter only records two
views of an already existing execution, whereas the circuit below performs the
gluing in the structural graph.

The upstream component refreshes `(a₀,a₁)` with the zero sharing `(r₀,r₀)`.
The downstream component XORs two input sharings and refreshes the result with
an independently named zero sharing `(r₁,r₁)`.  In the composite,
the downstream component's first input gates are not copied: its references
point directly to gates 0 and 1, which are the upstream output gates.  Thus the
connected boundary consists of literally identical nodes.
-/

def upstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (2, 0)] }
    ] }

def upstream : GadgetInstance :=
  { circuit := upstreamCircuit
    horizon := 1
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share => if share = 0 then { gate := 3, cycle := 0 }
      else { gate := 4, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 5
    randomness := [.rnd 0 0] }

def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .inp 1 1, inputs := [] },
      { kind := .rnd 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (3, 0)] },
      { kind := .xor, inputs := [(5, 0), (4, 0)] },
      { kind := .xor, inputs := [(6, 0), (4, 0)] }
    ] }

def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 1
    d := 2
    inputCount := 2
    inputArrival := fun sharing share => .inp sharing share 0
    output := fun share => if share = 0 then { gate := 7, cycle := 0 }
      else { gate := 8, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 9
    randomness := [.rnd 1 0] }

/-- The actual structural glue.  Gates 5 and 6 have both roles: they are the
upstream outputs and the two inputs read by downstream XOR gates 8 and 9.
There is no second copy of the connected input nodes. -/
def compositeCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .inp 1 1, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (4, 0)] },
      { kind := .xor, inputs := [(1, 0), (4, 0)] },
      { kind := .rnd 1, inputs := [] },
      { kind := .xor, inputs := [(5, 0), (2, 0)] },
      { kind := .xor, inputs := [(6, 0), (3, 0)] },
      { kind := .xor, inputs := [(8, 0), (7, 0)] },
      { kind := .xor, inputs := [(9, 0), (7, 0)] }
    ] }

def composite : GadgetInstance :=
  { circuit := compositeCircuit
    horizon := 1
    d := 2
    inputCount := 2
    inputArrival := fun sharing share => .inp sharing share 0
    output := fun share => if share = 0 then { gate := 10, cycle := 0 }
      else { gate := 11, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 12
    randomness := [.rnd 0 0, .rnd 1 0] }

def connectedNode (share : Nat) : Node :=
  if share = 0 then { gate := 5, cycle := 0 }
  else { gate := 6, cycle := 0 }

/-- The connection is node identity, not an equation between an evaluated
node and an unrelated environment source. -/
theorem connectedNode_eq_upstream_output (share : Nat) :
    connectedNode share =
      { gate := (upstream.output share).gate + 2, cycle := 0 } := by
  by_cases h : share = 0 <;> simp [connectedNode, upstream, h]

/-- The upstream output after embedding into `compositeCircuit`. -/
def embeddedUpstreamOutput (share : Nat) : Node := connectedNode share

theorem connectedNode_eq_embedded_upstream_output (share : Nat) :
    connectedNode share = embeddedUpstreamOutput share := rfl

/-- Each downstream output gate reads the connected node of the same share as
its first structural predecessor. -/
theorem downstream_reads_connected_node (share : Nat) (hshare : share < 2) :
    (compositeCircuit.gates[8 + share]?).map
        (fun gate => gate.inputs.head?) =
      some (some ((connectedNode share).gate, 0)) := by
  have hcases : share = 0 ∨ share = 1 := by omega
  rcases hcases with rfl | rfl <;> decide

/-- Boundary values agree by reflexivity because both names denote the same
node of `compositeCircuit`. -/
theorem boundaryValuesAgree_by_construction (env : Env) (share : Nat) :
    Execution.eval compositeCircuit composite.horizon env (connectedNode share) =
      Execution.eval compositeCircuit composite.horizon env
        (connectedNode share) := by
  rfl

/-- The two component random-source sets are disjoint by construction. -/
theorem componentRandomnessDisjoint_by_construction :
    Serial2Obstructions.ComponentRandomnessDisjoint upstream downstream := by
  simp [Serial2Obstructions.ComponentRandomnessDisjoint, upstream, downstream]

/-- Upstream external inputs cannot collide with downstream randomness: the
two source constructors/namespaces are distinct by construction. -/
theorem upstreamInputsDownstreamRandomnessDisjoint_by_construction :
    Serial2Obstructions.UpstreamInputsDownstreamRandomnessDisjoint
      upstream downstream := by
  simp [Serial2Obstructions.UpstreamInputsDownstreamRandomnessDisjoint,
    upstream, downstream]

theorem upstream_opini : opiniSpec upstream transitionGlitch 1 := by
  apply (opini_iff_spec upstream transitionGlitch 1 ?_).mp
  · refine ⟨?_, ?_⟩
    · refine ⟨?_, ?_⟩
      · simp [upstream, upstreamCircuit, Circuit.WF, Circuit.indicesOk,
          Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
          Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]
      · decide
    · decide
  · intro x hx
    apply List.length_pos_iff.mpr
    exact envsForInput_ne_nil_of_valid upstream x
      (fixingForInput_valid upstream x)

theorem downstream_opini : opiniSpec downstream transitionGlitch 1 := by
  apply (opini_iff_spec downstream transitionGlitch 1 ?_).mp
  · refine ⟨?_, ?_⟩
    · refine ⟨?_, ?_⟩
      · simp [downstream, downstreamCircuit, Circuit.WF, Circuit.indicesOk,
          Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
          Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]
      · decide
    · decide
  · intro x hx
    apply List.length_pos_iff.mpr
    exact envsForInput_ne_nil_of_valid downstream x
      (fixingForInput_valid downstream x)

theorem composite_wf : composite.WF := by
  refine ⟨?_, ?_⟩
  · simp [composite, compositeCircuit, Circuit.WF, Circuit.indicesOk,
      Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
      Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]
  · decide

/-- Hypothesis-free closure for this concrete structural serial composite.
The component O-PINI certificates above and this whole-circuit probing result
are all kernel proofs over the audited finite semantics. -/
theorem serial2_composite_probing :
    probingSecureSpec composite transitionGlitch 1 := by
  have reached : ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
    intro secret hsecret
    let x := secret.flatMap fun bit => [bit, false]
    have hx : x ∈ boolVectors (inputWidth composite) := by
      simp [x, composite, boolVectors] at hsecret ⊢
      rcases hsecret with rfl | rfl | rfl | rfl <;> decide
    have hsecrets : secretsOf composite x = secret := by
      simp [x, composite, secretsOf, boolVectors] at hsecret ⊢
      rcases hsecret with rfl | rfl | rfl | rfl <;> decide
    apply List.length_pos_iff.mpr
    exact envsForSecret_ne_nil_of_input composite secret x hx hsecrets
      (envsForInput_ne_nil_of_valid composite x
        (fixingForInput_valid composite x))
  apply (probingSecure_iff_spec composite transitionGlitch 1 reached).mp
  apply (probingSecureFast_iff composite transitionGlitch 1 reached).mp
  decide

/-- The same closure packaged with the audited member-boundary guard. -/
theorem serial2_composite_probing_wf :
    composite.WF ∧ probingSecureSpec composite transitionGlitch 1 :=
  ⟨composite_wf, serial2_composite_probing⟩

/-- One theorem recording both O-PINI premises and their concrete glued
whole-circuit consequence.  It has no hypotheses because all three circuits
and both fresh randomness namespaces are constructed above. -/
theorem serial2_composite_closure :
    opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      (composite.WF ∧ probingSecureSpec composite transitionGlitch 1) :=
  ⟨upstream_opini, downstream_opini, serial2_composite_probing_wf⟩

end ConcreteSerial2
end Composition
end LeanSec
