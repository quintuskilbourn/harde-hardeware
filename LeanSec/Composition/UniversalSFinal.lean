import LeanSec.Composition.UniversalS
import LeanSec.Composition.UniversalT

namespace LeanSec
namespace Composition
namespace UniversalSFinal

open Gadget
open UniversalSStage2

/-!
The literal universal theorem requested for `SingleCyclePorts` is false.
The port record controls structural edges but does not separate the source
namespaces of the two component experiments.  The closed witness below is
single-cycle, uses two shares, has clean coherent input gates, and has two
order-one O-PINI component certificates.  Nevertheless, a source sampled as
downstream randomness is the first upstream external input share.  The serial
experiment therefore fixes that source, and one downstream output becomes the
secret in a single probe.
-/

namespace SourceCollision

def upstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] }
    ] }

def upstream : GadgetInstance :=
  { circuit := upstreamCircuit
    horizon := 1
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share =>
      if share = 0 then { gate := 0, cycle := 0 }
      else { gate := 1, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 2
    randomness := [] }

def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 1 0, inputs := [] },
      { kind := .inp 1 1, inputs := [] },
      { kind := .inp 0 0, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (2, 0)] }
    ] }

def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 1
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 1 share 0
    output := fun share =>
      if share = 0 then { gate := 3, cycle := 0 }
      else { gate := 4, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 5
    randomness := [.inp 0 0 0] }

def ports : SingleCyclePorts upstream downstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    have : share < 5 := by omega
    simpa [downstream, downstreamCircuit] using this
  input_gate_kind := by
    intro share hshare
    change share < 2 at hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl
    · exact ⟨1, rfl⟩
    · exact ⟨1, rfl⟩
  input_arrival := by
    intro share _
    exact ⟨1, rfl⟩
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

theorem clean : CleanCombinational ports := by
  intro gate entry input hentry hinput hconnected
  have hgate : gate < 5 := by
    by_cases h : gate < 5
    · exact h
    · have : downstreamCircuit.gates[gate]? = none := by
        simp [downstreamCircuit, h]
      simp [downstream, this] at hentry
  have hcases : gate = 0 ∨ gate = 1 ∨ gate = 2 ∨ gate = 3 ∨ gate = 4 := by
    omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl <;>
    simp [downstream, downstreamCircuit] at hentry <;>
    subst entry <;>
    simp_all [connectedShare?, ports] <;>
    try { rcases hinput with rfl | rfl <;> rfl }

theorem upstream_wf : upstream.WF := by
  refine ⟨?_, by decide, ?_, ?_, ?_, ?_⟩
  · simp [upstream, upstreamCircuit, Circuit.WF, Circuit.indicesOk,
      Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
      Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]
  · change ([({ gate := 0, cycle := 0 } : Node),
      ({ gate := 1, cycle := 0 } : Node)]).Nodup
    decide
  · simp [outputNodes, memberNodes, nodes, upstream, upstreamCircuit]
    intro share hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl <;> simp
  · simp [memberNodes, nodes, combInputNodes, upstream, upstreamCircuit]
    intro gate hgate
    have : gate = 0 ∨ gate = 1 := by omega
    rcases this with rfl | rfl <;> simp
  · simp [memberNodes, nodes, transInputNodes, upstream, upstreamCircuit]

theorem downstream_wf : downstream.WF := by
  refine ⟨?_, by decide, ?_, ?_, ?_, ?_⟩
  · simp [downstream, downstreamCircuit, Circuit.WF, Circuit.indicesOk,
      Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
      Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]
  · change ([({ gate := 3, cycle := 0 } : Node),
      ({ gate := 4, cycle := 0 } : Node)]).Nodup
    decide
  · simp [outputNodes, memberNodes, nodes, downstream, downstreamCircuit]
    intro share hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl <;> simp
  · simp [memberNodes, nodes, combInputNodes, downstream, downstreamCircuit]
    intro gate hgate
    have : gate = 0 ∨ gate = 1 ∨ gate = 2 ∨ gate = 3 ∨ gate = 4 := by omega
    rcases this with rfl | rfl | rfl | rfl | rfl <;> simp
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
    { kind := .const false, inputs := [] },
    { kind := .const false, inputs := [] },
    { kind := .inp 0 0, inputs := [] },
    { kind := .xor, inputs := [(0, 0), (4, 0)] },
    { kind := .xor, inputs := [(1, 0), (4, 0)] }
  ] } : Circuit).WF
  simp [Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- The missing source-freshness law, stated at the exact colliding atom. -/
theorem upstream_input_is_downstream_randomness :
    upstream.inputArrival 0 0 ∈ downstream.randomness := by
  decide

/-- Boundary substitution for this witness.  This is the environment which
the intended transport lemma would give to the isolated downstream circuit. -/
def substitutedDownstreamEnv (env : Env) : Env := fun src =>
  if src == (.inp 1 0 0 : Src) then
    Execution.eval upstream.circuit 1 env (upstream.output 0)
  else if src == (.inp 1 1 0 : Src) then
    Execution.eval upstream.circuit 1 env (upstream.output 1)
  else env src

private def allTrueEnv : Env := fun _ => true

/-- The literal proposed transport statement for every downstream-range node
is also false: Stage2 replaces a connected input gate by a dead constant.
Such a node must be omitted from the downstream embedding (or mapped to the
upstream output); it cannot be related by suffix-index shifting. -/
theorem connected_input_suffix_not_boundary_substitution :
    Execution.eval (serialGadget ports).circuit 1 allTrueEnv
        { gate := upstream.circuit.gates.size + ports.inputGate 0, cycle := 0 } ≠
      Execution.eval downstream.circuit 1
        (substitutedDownstreamEnv allTrueEnv)
        { gate := ports.inputGate 0, cycle := 0 } := by
  decide

private theorem composite_secrets_reached :
    ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
  intro secret hsecret
  have hcases : secret = [false] ∨ secret = [true] := by
    simpa [composite, serialGadget, upstream, downstream, boolVectors]
      using hsecret
  rcases hcases with rfl | rfl
  · apply List.length_pos_iff.mpr
    exact envsForSecret_ne_nil_of_input composite [false] [false, false]
      (by decide) (by decide)
      (envsForInput_ne_nil_of_valid composite [false, false]
        (fixingForInput_valid composite [false, false]))
  · apply List.length_pos_iff.mpr
    exact envsForSecret_ne_nil_of_input composite [true] [true, false]
      (by decide) (by decide)
      (envsForInput_ne_nil_of_valid composite [true, false]
        (fixingForInput_valid composite [true, false]))

theorem composite_not_probing :
    ¬ probingSecureSpec composite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure composite transitionGlitch 1 :=
    (probingSecure_iff_spec composite transitionGlitch 1
      composite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast composite transitionGlitch 1 :=
    (probingSecureFast_iff composite transitionGlitch 1
      composite_secrets_reached).mpr hexecutable
  exact (by decide : ¬ probingSecureFast composite transitionGlitch 1) hfast

/-- Closed negation of the requested theorem shape, even with the optional
clean-combinational premise and exact horizon/share-count constraints. -/
theorem universal_serialGadget_counterexample :
    opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      CleanCombinational ports ∧
      (serialGadget ports).WF ∧
      ¬ probingSecureSpec (serialGadget ports) transitionGlitch 1 :=
  ⟨upstream_opini, downstream_opini, clean, composite_wf,
    composite_not_probing⟩

end SourceCollision

/-- The mandated concrete Stage2 target remains non-vacuously secure.  It
cannot be an instance of the requested universal implication because that
implication is refuted above. -/
theorem concrete_target_still_secure :
    probingSecureSpec UniversalSStage2.Concrete.composite transitionGlitch 1 :=
  UniversalSStage2.Concrete.composite_probing

end UniversalSFinal
end Composition
end LeanSec

#print axioms LeanSec.Composition.UniversalSFinal.SourceCollision.clean
#print axioms LeanSec.Composition.UniversalSFinal.SourceCollision.upstream_opini
#print axioms LeanSec.Composition.UniversalSFinal.SourceCollision.downstream_opini
#print axioms LeanSec.Composition.UniversalSFinal.SourceCollision.connected_input_suffix_not_boundary_substitution
#print axioms LeanSec.Composition.UniversalSFinal.SourceCollision.composite_wf
#print axioms LeanSec.Composition.UniversalSFinal.SourceCollision.composite_not_probing
#print axioms LeanSec.Composition.UniversalSFinal.SourceCollision.universal_serialGadget_counterexample
#print axioms LeanSec.Composition.UniversalSFinal.concrete_target_still_secure
