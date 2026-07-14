import LeanSec.Composition.UniversalSFinal

namespace LeanSec
namespace Composition
namespace UniversalSFinal2

open Gadget
open UniversalSStage2

/-!
The two requested one-way freshness predicates do not suffice for arbitrary
`GadgetInstance`s.  This file gives the exact opposite-direction collision:
an unconnected downstream external input is also the upstream component's
random source.  The connected input ports are source-coherent, both requested
freshness predicates hold, and both components are order-one O-PINI.
-/

namespace ReverseCollision

def upstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (2, 0)] }
    ] }

/-- The source `.inp 1 0 0` is fresh randomness in the isolated upstream
experiment, despite being represented by an input-kind source gate. -/
def upstream : GadgetInstance :=
  { circuit := upstreamCircuit
    horizon := 1
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share =>
      if share = 0 then { gate := 3, cycle := 0 }
      else { gate := 4, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 5
    randomness := [.inp 1 0 0] }

def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 2 0, inputs := [] },
      { kind := .inp 2 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .inp 1 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (3, 0)] }
    ] }

/-- Sharing zero is the connected input.  Sharing one remains external and
its first share is the atom used as upstream randomness. -/
def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 1
    d := 2
    inputCount := 2
    inputArrival := fun input share =>
      if input = 0 then .inp 2 share 0 else .inp 1 share 0
    output := fun share =>
      if share = 0 then { gate := 4, cycle := 0 }
      else { gate := 5, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 6
    randomness := [] }

def ports : SingleCyclePorts upstream downstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    have : share < 6 := by omega
    simpa [downstream, downstreamCircuit] using this
  input_gate_kind := by
    intro share hshare
    change share < 2 at hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl
    · exact ⟨2, rfl⟩
    · exact ⟨2, rfl⟩
  input_arrival := by
    intro share _
    exact ⟨2, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h
  up_horizon := rfl
  down_horizon := rfl
  same_shares := rfl
  two_shares := rfl
  up_outputs_at_zero := by
    intro share _
    by_cases h : share = 0 <;> simp [upstream, h]
  down_outputs_at_zero := by
    intro share _
    by_cases h : share = 0 <;> simp [downstream, h]

/-- Stronger than the two separate existential fields in `SingleCyclePorts`:
the connected gate and declared arrival use the very same input source. -/
def InputSourceCoherent : Prop :=
  ∀ share, share < downstream.d → ∃ sharing,
    downstream.circuit.gates[ports.inputGate share]? =
        some { kind := .inp sharing share, inputs := [] } ∧
      downstream.inputArrival ports.downstreamInput share =
        .inp sharing share 0

theorem inputSourceCoherent : InputSourceCoherent := by
  intro share hshare
  change share < 2 at hshare
  have : share = 0 ∨ share = 1 := by omega
  rcases this with rfl | rfl
  · exact ⟨2, rfl, rfl⟩
  · exact ⟨2, rfl, rfl⟩

theorem clean : CleanCombinational ports := by
  intro gate entry input hentry hinput hconnected
  have hgate : gate < 6 := by
    by_cases h : gate < 6
    · exact h
    · have : downstreamCircuit.gates[gate]? = none := by
        simp [downstreamCircuit, h]
      simp [downstream, this] at hentry
  have hcases : gate = 0 ∨ gate = 1 ∨ gate = 2 ∨ gate = 3 ∨
      gate = 4 ∨ gate = 5 := by omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp [downstream, downstreamCircuit] at hentry <;>
    subst entry <;> simp_all [connectedShare?, ports] <;>
    try { rcases hinput with rfl | rfl <;> rfl }

theorem componentRandomnessDisjoint :
    Serial2Obstructions.ComponentRandomnessDisjoint upstream downstream := by
  simp [Serial2Obstructions.ComponentRandomnessDisjoint, downstream]

theorem upstreamInputsDownstreamRandomnessDisjoint :
    Serial2Obstructions.UpstreamInputsDownstreamRandomnessDisjoint
      upstream downstream := by
  simp [Serial2Obstructions.UpstreamInputsDownstreamRandomnessDisjoint,
    downstream]

/-- The reverse overlap omitted by the requested premises. -/
theorem downstream_external_input_is_upstream_randomness :
    downstream.inputArrival 1 0 ∈ upstream.randomness := by
  decide

theorem upstream_wf : upstream.WF := by
  refine ⟨?_, by decide, ?_, ?_, ?_, ?_⟩
  · simp [upstream, upstreamCircuit, Circuit.WF, Circuit.indicesOk,
      Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
      Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]
  · change ([({ gate := 3, cycle := 0 } : Node),
      ({ gate := 4, cycle := 0 } : Node)]).Nodup
    decide
  · simp [outputNodes, memberNodes, nodes, upstream, upstreamCircuit]
    intro share hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl <;> simp
  · simp [memberNodes, nodes, combInputNodes, upstream, upstreamCircuit]
    intro gate hgate
    have : gate = 0 ∨ gate = 1 ∨ gate = 2 ∨ gate = 3 ∨ gate = 4 := by
      omega
    rcases this with rfl | rfl | rfl | rfl | rfl <;> simp
  · simp [memberNodes, nodes, transInputNodes, upstream, upstreamCircuit]

theorem downstream_wf : downstream.WF := by
  refine ⟨?_, by decide, ?_, ?_, ?_, ?_⟩
  · simp [downstream, downstreamCircuit, Circuit.WF, Circuit.indicesOk,
      Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
      Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]
  · change ([({ gate := 4, cycle := 0 } : Node),
      ({ gate := 5, cycle := 0 } : Node)]).Nodup
    decide
  · simp [outputNodes, memberNodes, nodes, downstream, downstreamCircuit]
    intro share hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl <;> simp
  · simp [memberNodes, nodes, combInputNodes, downstream, downstreamCircuit]
    intro gate hgate
    have : gate = 0 ∨ gate = 1 ∨ gate = 2 ∨ gate = 3 ∨
        gate = 4 ∨ gate = 5 := by omega
    rcases this with rfl | rfl | rfl | rfl | rfl | rfl <;> simp
  · simp [memberNodes, nodes, transInputNodes, downstream, downstreamCircuit]

private theorem upstream_inputs_reached :
    ∀ x ∈ boolVectors (inputWidth upstream),
      (envsForInput upstream x).length > 0 := by
  intro x _
  apply List.length_pos_iff.mpr
  exact envsForInput_ne_nil_of_valid upstream x
    (fixingForInput_valid upstream x)

private theorem downstream_inputs_reached :
    ∀ x ∈ boolVectors (inputWidth downstream),
      (envsForInput downstream x).length > 0 := by
  intro x _
  apply List.length_pos_iff.mpr
  exact envsForInput_ne_nil_of_valid downstream x
    (fixingForInput_valid downstream x)

theorem upstream_opini : opiniSpec upstream transitionGlitch 1 := by
  apply (opini_iff_spec upstream transitionGlitch 1
    upstream_inputs_reached).mp
  exact ⟨upstream_wf, by decide⟩

theorem downstream_opini : opiniSpec downstream transitionGlitch 1 := by
  apply (opini_iff_spec downstream transitionGlitch 1
    downstream_inputs_reached).mp
  exact ⟨downstream_wf, by decide⟩

def composite : GadgetInstance := serialGadget ports

theorem composite_wf : composite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  change ({ gates := #[
    { kind := .inp 0 0, inputs := [] },
    { kind := .inp 0 1, inputs := [] },
    { kind := .inp 1 0, inputs := [] },
    { kind := .xor, inputs := [(0, 0), (2, 0)] },
    { kind := .xor, inputs := [(1, 0), (2, 0)] },
    { kind := .const false, inputs := [] },
    { kind := .const false, inputs := [] },
    { kind := .inp 1 0, inputs := [] },
    { kind := .inp 1 1, inputs := [] },
    { kind := .xor, inputs := [(3, 0), (7, 0)] },
    { kind := .xor, inputs := [(4, 0), (8, 0)] }
  ] } : Circuit).WF
  simp [Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

private theorem composite_secrets_reached :
    ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
  intro secret hsecret
  let x := secret.flatMap fun bit => [bit, false]
  have hx : x ∈ boolVectors (inputWidth composite) := by
    apply (mem_boolVectors_iff _ _).mpr
    have hlen := (mem_boolVectors_iff _ _).mp hsecret
    change secret.length = 2 at hlen
    change x.length = 4
    rcases secret with _ | ⟨a, tail⟩
    · simp at hlen
    rcases tail with _ | ⟨b, tail⟩
    · simp at hlen
    rcases tail with _ | ⟨c, tail⟩
    · simp [x]
    · simp at hlen
  have hsecrets : secretsOf composite x = secret := by
    have hlen := (mem_boolVectors_iff _ _).mp hsecret
    change secret.length = 2 at hlen
    rcases secret with _ | ⟨a, tail⟩
    · simp at hlen
    rcases tail with _ | ⟨b, tail⟩
    · simp at hlen
    rcases tail with _ | ⟨c, tail⟩
    · change [xorList [a, false], xorList [b, false]] = [a, b]
      cases a <;> cases b <;> rfl
    · simp at hlen
  apply List.length_pos_iff.mpr
  exact envsForSecret_ne_nil_of_input composite secret x hx hsecrets
    (envsForInput_ne_nil_of_valid composite x
      (fixingForInput_valid composite x))

/-- One probe of the second composite output glitches to upstream share one,
the collided random/external source, and downstream share one.  The latter
two observations reveal the complete second external sharing. -/
theorem composite_not_probing :
    ¬ probingSecureSpec composite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure composite transitionGlitch 1 :=
    (probingSecure_iff_spec composite transitionGlitch 1
      composite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast composite transitionGlitch 1 :=
    (probingSecureFast_iff composite transitionGlitch 1
      composite_secrets_reached).mpr hexecutable
  exact (by decide :
    ¬ probingSecureFast composite transitionGlitch 1) hfast

/-- Closed refutation of the requested implication, including source-coherent
ports and full well-formedness of the compiled single-cycle composite. -/
theorem requested_preconditions_counterexample :
    opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      CleanCombinational ports ∧
      InputSourceCoherent ∧
      Serial2Obstructions.ComponentRandomnessDisjoint upstream downstream ∧
      Serial2Obstructions.UpstreamInputsDownstreamRandomnessDisjoint
        upstream downstream ∧
      (serialGadget ports).WF ∧
      ¬ probingSecureSpec (serialGadget ports) transitionGlitch 1 :=
  ⟨upstream_opini, downstream_opini, clean, inputSourceCoherent,
    componentRandomnessDisjoint,
    upstreamInputsDownstreamRandomnessDisjoint, composite_wf,
    composite_not_probing⟩

end ReverseCollision

/-- The opposite-direction freshness condition missing from the requested
pair: every downstream input which remains external after serial wiring must
be disjoint from upstream randomness. -/
def DownstreamExternalInputsUpstreamRandomnessDisjoint
    {up down : GadgetInstance} (ports : SingleCyclePorts up down) : Prop :=
  ∀ input, input < down.inputCount → input ≠ ports.downstreamInput →
    ∀ share, share < down.d →
      down.inputArrival input share ∉ up.randomness

theorem reverseCollision_violates_missing_freshness :
    ¬ DownstreamExternalInputsUpstreamRandomnessDisjoint
      ReverseCollision.ports := by
  intro hfresh
  exact hfresh 1 (by decide) (by decide) 0 (by decide)
    ReverseCollision.downstream_external_input_is_upstream_randomness

/-- Exact negation of the universal theorem requested with only the two named
source-disjointness premises and clean single-cycle ports. -/
theorem requested_universal_statement_is_false :
    ¬ (∀ (up down : GadgetInstance) (ports : SingleCyclePorts up down),
      Serial2Obstructions.ComponentRandomnessDisjoint up down →
      Serial2Obstructions.UpstreamInputsDownstreamRandomnessDisjoint up down →
      CleanCombinational ports →
      opiniSpec up transitionGlitch 1 →
      opiniSpec down transitionGlitch 1 →
      probingSecureSpec (serialGadget ports) transitionGlitch 1) := by
  intro huniversal
  exact ReverseCollision.composite_not_probing
    (huniversal ReverseCollision.upstream ReverseCollision.downstream
      ReverseCollision.ports
      ReverseCollision.componentRandomnessDisjoint
      ReverseCollision.upstreamInputsDownstreamRandomnessDisjoint
      ReverseCollision.clean ReverseCollision.upstream_opini
      ReverseCollision.downstream_opini)

/-! ## Required concrete non-vacuity check

The repository's concrete pair is genuinely namespaced in both directions.
It satisfies the two requested predicates and the additional reverse law;
its compiled `serialGadget` remains kernel-proven probing secure.  What is
impossible is to obtain that concrete fact by instantiating the refuted
two-predicate universal implication.
-/

theorem concrete_requested_and_reverse_freshness :
    Serial2Obstructions.ComponentRandomnessDisjoint
        ConcreteSerial2.upstream ConcreteSerial2.downstream ∧
      Serial2Obstructions.UpstreamInputsDownstreamRandomnessDisjoint
        ConcreteSerial2.upstream ConcreteSerial2.downstream ∧
      DownstreamExternalInputsUpstreamRandomnessDisjoint
        UniversalSStage2.Concrete.ports ∧
      CleanCombinational UniversalSStage2.Concrete.ports := by
  refine ⟨ConcreteSerial2.componentRandomnessDisjoint_by_construction,
    ConcreteSerial2.upstreamInputsDownstreamRandomnessDisjoint_by_construction,
    ?_, UniversalSStage2.Concrete.clean⟩
  intro input hinput hnot share hshare
  simp [ConcreteSerial2.upstream, ConcreteSerial2.downstream]

theorem concrete_target_still_secure :
    probingSecureSpec UniversalSStage2.Concrete.composite
      transitionGlitch 1 :=
  UniversalSStage2.Concrete.composite_probing

end UniversalSFinal2
end Composition
end LeanSec

#print axioms LeanSec.Composition.UniversalSFinal2.ReverseCollision.inputSourceCoherent
#print axioms LeanSec.Composition.UniversalSFinal2.ReverseCollision.clean
#print axioms LeanSec.Composition.UniversalSFinal2.ReverseCollision.componentRandomnessDisjoint
#print axioms LeanSec.Composition.UniversalSFinal2.ReverseCollision.upstreamInputsDownstreamRandomnessDisjoint
#print axioms LeanSec.Composition.UniversalSFinal2.ReverseCollision.upstream_opini
#print axioms LeanSec.Composition.UniversalSFinal2.ReverseCollision.downstream_opini
#print axioms LeanSec.Composition.UniversalSFinal2.ReverseCollision.composite_wf
#print axioms LeanSec.Composition.UniversalSFinal2.ReverseCollision.composite_not_probing
#print axioms LeanSec.Composition.UniversalSFinal2.ReverseCollision.requested_preconditions_counterexample
#print axioms LeanSec.Composition.UniversalSFinal2.reverseCollision_violates_missing_freshness
#print axioms LeanSec.Composition.UniversalSFinal2.requested_universal_statement_is_false
#print axioms LeanSec.Composition.UniversalSFinal2.concrete_requested_and_reverse_freshness
#print axioms LeanSec.Composition.UniversalSFinal2.concrete_target_still_secure
