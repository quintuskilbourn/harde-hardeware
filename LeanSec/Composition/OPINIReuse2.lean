import LeanSec.Composition.UniformOPINI

namespace LeanSec
namespace Composition
namespace OPINIReuse2

open Gadget
open UniversalReg

/-! # Order-2 producer reuse through the generic O-PINI closure

The generic closure `compose_opini` requires `uniformOpiniSpec` of its
leaves.  At order one that obligation is implied by the audited `opiniSpec`
(`opini_implies_uniform_of_le_one`), but at `t ≥ 2` it is strictly stronger
and was previously open: no gadget had been shown demand-uniform at higher
order, so the closure was unusable there.

This file discharges the obligation at order two.  Both leaves below are
kernel-checked `uniformOpiniSpec _ transitionGlitch 2` via the executable
bridge `uopini_iff_spec`: a three-share refresh producer (two fresh masks)
and a purely combinational three-share fork--join consumer whose connected
input gates are each read by *two* distinct internal gates.  Wiring the
producer onto the consumer's port with the generic `UOPipelineGadget.wire`
compiles a circuit in which each shared boundary register — carrying one
producer output share — literally drives multiple consumers.  Security of
the compiled reconvergent order-2 gadget is obtained *only* from the
generic closure (`OPINIComposition`), not from a hand audit of the
composite. -/

/-! ## The order-2 leaves -/

/-- Three-share refresh: `out₀ = x₀⊕r₀`, `out₁ = x₁⊕r₁`,
`out₂ = x₂⊕r₀⊕r₁`.  Executes at cycle zero with two fresh masks. -/
def producerCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .inp 0 2, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .rnd 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (3, 0)] },
      { kind := .xor, inputs := [(1, 0), (4, 0)] },
      { kind := .xor, inputs := [(2, 0), (3, 0)] },
      { kind := .xor, inputs := [(7, 0), (4, 0)] }
    ] }

def producer : GadgetInstance :=
  { circuit := producerCircuit
    horizon := 2
    d := 3
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share =>
      if share = 0 then { gate := 5, cycle := 0 }
      else if share = 1 then { gate := 6, cycle := 0 }
      else { gate := 8, cycle := 0 }
    member := fun _ => true
    randomness := [.rnd 0 0, .rnd 1 0] }

/-- Fork--join consumer: share `s` is read by branch gate `3+s` (twice) and
again by reconvergence gate `6+s`, which also consumes the branch. -/
def forkJoin3Circuit : Circuit :=
  { gates := #[
      { kind := .inp 2 0, inputs := [] },
      { kind := .inp 2 1, inputs := [] },
      { kind := .inp 2 2, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (0, 0)] },
      { kind := .xor, inputs := [(1, 0), (1, 0)] },
      { kind := .xor, inputs := [(2, 0), (2, 0)] },
      { kind := .xor, inputs := [(3, 0), (0, 0)] },
      { kind := .xor, inputs := [(4, 0), (1, 0)] },
      { kind := .xor, inputs := [(5, 0), (2, 0)] }
    ] }

def forkJoin3 : GadgetInstance :=
  { circuit := forkJoin3Circuit
    horizon := 2
    d := 3
    inputCount := 1
    inputArrival := fun _ share => .inp 2 share 1
    output := fun share => { gate := 6 + share, cycle := 1 }
    member := fun _ => true
    randomness := [] }

theorem producer_wf : producer.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [producer, producerCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem forkJoin3_wf : forkJoin3.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [forkJoin3, forkJoin3Circuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Literal fanout inside the isolated consumer: each connected input gate
has two distinct reading gates. -/
theorem forkJoin3_fanout :
    (0, 0) ∈ forkJoin3Circuit.gates[3].inputs ∧
    (0, 0) ∈ forkJoin3Circuit.gates[6].inputs ∧
    (1, 0) ∈ forkJoin3Circuit.gates[4].inputs ∧
    (1, 0) ∈ forkJoin3Circuit.gates[7].inputs ∧
    (2, 0) ∈ forkJoin3Circuit.gates[5].inputs ∧
    (2, 0) ∈ forkJoin3Circuit.gates[8].inputs := by
  decide

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

/-! ## The kernel-checked order-2 demand-uniform certificates

These are the two leaf obligations that were open at `t ≥ 2`.  Each is the
full `uniformOpiniSpec` at order two under the real transition-glitch
expansion, obtained by exhaustive kernel computation over every internal
probe set of size at most two, every witness candidate, and every residual
output demand. -/

set_option maxRecDepth 100000 in
set_option maxHeartbeats 400000000 in
theorem producer_uniform_opini :
    uniformOpiniSpec producer transitionGlitch 2 := by
  apply (uopini_iff_spec producer transitionGlitch 2
    (inputs_reached producer)).mp
  exact ⟨producer_wf, by decide⟩

set_option maxRecDepth 100000 in
set_option maxHeartbeats 400000000 in
theorem forkJoin3_uniform_opini :
    uniformOpiniSpec forkJoin3 transitionGlitch 2 := by
  apply (uopini_iff_spec forkJoin3 transitionGlitch 2
    (inputs_reached forkJoin3)).mp
  exact ⟨forkJoin3_wf, by decide⟩

/-- The audited order-2 O-PINI certificates follow by weakening. -/
theorem producer_opini : opiniSpec producer transitionGlitch 2 :=
  uniformOpini_implies_opini producer transitionGlitch 2
    producer_uniform_opini

theorem forkJoin3_opini : opiniSpec forkJoin3 transitionGlitch 2 :=
  uniformOpini_implies_opini forkJoin3 transitionGlitch 2
    forkJoin3_uniform_opini

/-! ## Pipeline packaging -/

def producerPorts : RegisterPorts producer where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 3 at hshare
    change share < 9
    omega
  arrivalCycle := 0
  input_source_coherent := by
    intro share hshare
    change share < 3 at hshare
    have hs : share = 0 ∨ share = 1 ∨ share = 2 := by omega
    rcases hs with rfl | rfl | rfl
    · exact ⟨0, rfl, rfl⟩
    · exact ⟨0, rfl, rfl⟩
    · exact ⟨0, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

def forkJoin3Ports : RegisterPorts forkJoin3 where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 3 at hshare
    change share < 9
    omega
  arrivalCycle := 1
  input_source_coherent := by
    intro share hshare
    change share < 3 at hshare
    have hs : share = 0 ∨ share = 1 ∨ share = 2 := by omega
    rcases hs with rfl | rfl | rfl
    · exact ⟨2, rfl, rfl⟩
    · exact ⟨2, rfl, rfl⟩
    · exact ⟨2, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

set_option maxHeartbeats 4000000 in
def producerPipeline : PipelineGadget 2 3 2 where
  g := producer
  horizon_eq := rfl
  d_eq := rfl
  order_lt := by decide
  whole_window := by decide
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := producerPorts
  arrival_inside := by decide
  interface_injective := by decide
  source_partition := by decide
  port_source_exclusive := by decide
  forward_combinational := by decide
  pinned_init := by decide
  outCycle := 0
  output_at := by
    intro share hshare
    change share < 3 at hshare
    have hs : share = 0 ∨ share = 1 ∨ share = 2 := by omega
    rcases hs with rfl | rfl | rfl <;> rfl
  output_inj := by
    intro i j hi hj heq
    change i < 3 at hi
    change j < 3 at hj
    have his : i = 0 ∨ i = 1 ∨ i = 2 := by omega
    have hjs : j = 0 ∨ j = 1 ∨ j = 2 := by omega
    rcases his with rfl | rfl | rfl <;> rcases hjs with rfl | rfl | rfl <;>
      simp [producer] at heq ⊢
  output_pulse := by decide
  down_cert := opini_implies_pini producer transitionGlitch 2 producer_opini

set_option maxHeartbeats 4000000 in
def forkJoin3Pipeline : PipelineGadget 2 3 2 where
  g := forkJoin3
  horizon_eq := rfl
  d_eq := rfl
  order_lt := by decide
  whole_window := by decide
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := forkJoin3Ports
  arrival_inside := by decide
  interface_injective := by decide
  source_partition := by decide
  port_source_exclusive := by decide
  forward_combinational := by decide
  pinned_init := by decide
  outCycle := 1
  output_at := by
    intro share hshare
    change share < 3 at hshare
    have hs : share = 0 ∨ share = 1 ∨ share = 2 := by omega
    rcases hs with rfl | rfl | rfl <;> rfl
  output_inj := by
    intro i j hi hj heq
    change i < 3 at hi
    change j < 3 at hj
    have his : i = 0 ∨ i = 1 ∨ i = 2 := by omega
    have hjs : j = 0 ∨ j = 1 ∨ j = 2 := by omega
    rcases his with rfl | rfl | rfl <;> rcases hjs with rfl | rfl | rfl <;>
      simp [forkJoin3] at heq ⊢
  output_pulse := by decide
  down_cert := opini_implies_pini forkJoin3 transitionGlitch 2 forkJoin3_opini

/-! ## Closed leaves and the generic order-2 derivation -/

/-- The refresh producer, packaged as a closed order-2 uniform O-PINI node. -/
def producerNode : UOPipelineGadget 2 3 2 :=
  UOPipelineGadget.ofUniformLeaf producerPipeline producer_uniform_opini

/-- The fanout consumer, packaged as a closed order-2 uniform O-PINI node. -/
def forkJoin3Node : UOPipelineGadget 2 3 2 :=
  UOPipelineGadget.ofUniformLeaf forkJoin3Pipeline forkJoin3_uniform_opini

theorem forkJoin3_arrival_inside : forkJoin3Ports.arrivalCycle < 2 := by
  decide

theorem forkJoin3_port_exclusive : PortSourceExclusive forkJoin3Ports := by
  decide

theorem reuse2Glue : PortGlue producerNode.toPipelineGadget
    (forkJoin3Node.toPipelineGadget.withPorts forkJoin3Ports
      forkJoin3_arrival_inside forkJoin3_port_exclusive) := by
  refine ⟨rfl, ?_⟩
  decide

/-- The order-2 reconvergent producer-reuse composite, built exclusively by
the generic closure operation. -/
def reuse2Composite : UOPipelineGadget 2 3 2 :=
  UOPipelineGadget.wire producerNode forkJoin3Node forkJoin3Ports
    forkJoin3_arrival_inside forkJoin3_port_exclusive reuse2Glue

/-- The composite is a generic `OPINIComposition` derivation: two order-2
demand-uniform leaves joined by one wiring step. -/
theorem reuse2Composite_build : OPINIComposition reuse2Composite :=
  OPINIComposition.wire producerNode forkJoin3Node
    (OPINIComposition.leaf producerPipeline producer_uniform_opini)
    (OPINIComposition.leaf forkJoin3Pipeline forkJoin3_uniform_opini)
    forkJoin3Ports forkJoin3_arrival_inside forkJoin3_port_exclusive
    reuse2Glue

/-- The compiled gadget is the generic registered compiler's output. -/
theorem reuse2Composite_g :
    reuse2Composite.g = registeredComposite producer forkJoin3Ports := rfl

/-! ## The audited order-2 conclusions, from the generic theorem only -/

/-- Composite order-2 O-PINI: the reconvergent composite can itself be
reused as an upstream producer at order two. -/
theorem reuse2_opini :
    opiniSpec reuse2Composite.g transitionGlitch 2 :=
  reuse2Composite_build.opini

/-- Composite order-2 demand-uniform O-PINI: the closure invariant itself is
reproduced, so the composite is again a legitimate closure leaf. -/
theorem reuse2_uniform_opini :
    uniformOpiniSpec reuse2Composite.g transitionGlitch 2 :=
  reuse2Composite.uniform_cert

/-- Composite order-2 downstream-role PINI. -/
theorem reuse2_pini :
    piniSpec reuse2Composite.g transitionGlitch 2 :=
  reuse2Composite_build.pini

/-- End-to-end order-2 probing security of the compiled reconvergent circuit
under the real transition-glitch expansion, via the generic closure only. -/
theorem reuse2_probing :
    probingSecureSpec reuse2Composite.g transitionGlitch 2 :=
  reuse2Composite_build.probing

/-! ## Kernel-checked producer reuse in the compiled circuit

Gates 5, 6, 8 are the producer's output gates; the compiler's boundary
registers 9, 10, 11 latch them, and register `9+s` is read by the two
distinct suffix consumers `15+s` (twice) and `18+s`.  Gate `18+s`
additionally reads gate `15+s`, so the two paths `9+s → 15+s → 18+s` and
`9+s → 18+s` reconverge at declared output share `s`. -/

/-- The literal compiled circuit: producer prefix, three shared boundary
registers, and the transported fanout suffix. -/
def compiledCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .inp 0 2, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .rnd 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (3, 0)] },
      { kind := .xor, inputs := [(1, 0), (4, 0)] },
      { kind := .xor, inputs := [(2, 0), (3, 0)] },
      { kind := .xor, inputs := [(7, 0), (4, 0)] },
      { kind := .reg, inputs := [(5, 1)] },
      { kind := .reg, inputs := [(6, 1)] },
      { kind := .reg, inputs := [(8, 1)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(9, 0), (9, 0)] },
      { kind := .xor, inputs := [(10, 0), (10, 0)] },
      { kind := .xor, inputs := [(11, 0), (11, 0)] },
      { kind := .xor, inputs := [(15, 0), (9, 0)] },
      { kind := .xor, inputs := [(16, 0), (10, 0)] },
      { kind := .xor, inputs := [(17, 0), (11, 0)] }
    ] }

def compiled : GadgetInstance :=
  { circuit := compiledCircuit
    horizon := 2
    d := 3
    inputCount := 1
    inputArrival := fun input share =>
      if input < 1 then .inp 0 share 0 else .inp 2 share 1
    output := fun share => { gate := 18 + share, cycle := 1 }
    member := fun _ => true
    randomness := [.rnd 0 0, .rnd 1 0]
    publicFixing := [(.iniReg 9, false), (.iniReg 10, false),
      (.iniReg 11, false)] }

set_option maxHeartbeats 4000000 in
set_option linter.unusedSimpArgs false in
/-- The generic compiler's output is this literal reconvergent circuit. -/
theorem reuse2Composite_g_eq : reuse2Composite.g = compiled := by
  show registeredComposite producer forkJoin3Ports = compiled
  unfold registeredComposite compiled
  congr 1
  · simp only [registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, compiledCircuit, Circuit.mk.injEq]
    simp [producer, forkJoin3, forkJoin3Ports, producerCircuit,
      forkJoin3Circuit, boundaryRegisterGates, registeredDownGates,
      wireRegisteredDownGate, wireRegisteredEdge, connectedShare?,
      boundaryRegister, downstreamOffset]
    decide
  all_goals
    simp [producer, forkJoin3, forkJoin3Ports, shiftDownSrc,
      unhideRegisteredInput, Nat.lt_one_iff, downstreamOffset,
      boundaryRegister, producerCircuit, forkJoin3Circuit]
  all_goals funext share
  all_goals simp only [Node.mk.injEq, and_true]
  all_goals omega

theorem boundary_registers_latch_producer :
    reuse2Composite.g.circuit.gates[9]? =
      some { kind := .reg, inputs := [(5, 1)] } ∧
    reuse2Composite.g.circuit.gates[10]? =
      some { kind := .reg, inputs := [(6, 1)] } ∧
    reuse2Composite.g.circuit.gates[11]? =
      some { kind := .reg, inputs := [(8, 1)] } := by
  rw [reuse2Composite_g_eq]
  decide

theorem producer_reused_by_two_consumers :
    reuse2Composite.g.circuit.gates[15]? =
      some { kind := .xor, inputs := [(9, 0), (9, 0)] } ∧
    reuse2Composite.g.circuit.gates[18]? =
      some { kind := .xor, inputs := [(15, 0), (9, 0)] } ∧
    reuse2Composite.g.circuit.gates[16]? =
      some { kind := .xor, inputs := [(10, 0), (10, 0)] } ∧
    reuse2Composite.g.circuit.gates[19]? =
      some { kind := .xor, inputs := [(16, 0), (10, 0)] } ∧
    reuse2Composite.g.circuit.gates[17]? =
      some { kind := .xor, inputs := [(11, 0), (11, 0)] } ∧
    reuse2Composite.g.circuit.gates[20]? =
      some { kind := .xor, inputs := [(17, 0), (11, 0)] } := by
  rw [reuse2Composite_g_eq]
  decide

theorem outputs_reconverge :
    reuse2Composite.g.output 0 = { gate := 18, cycle := 1 } ∧
    reuse2Composite.g.output 1 = { gate := 19, cycle := 1 } ∧
    reuse2Composite.g.output 2 = { gate := 20, cycle := 1 } := by
  rw [reuse2Composite_g_eq]
  decide

set_option maxRecDepth 10000 in
set_option maxHeartbeats 16000000 in
/-- Functional non-vacuity: the compiled reconvergent composite recombines
to the refreshed identity of its single external secret. -/
theorem reuse2_recombines :
    recombinesTo reuse2Composite.g (fun secrets => secrets.getD 0 false) := by
  rw [reuse2Composite_g_eq]
  decide

/-- The headline statement on the literal circuit: the compiled order-2
reconvergent producer-reuse gadget is probing secure at order two under the
transition-glitch expansion. -/
theorem compiled_probing :
    probingSecureSpec compiled transitionGlitch 2 := by
  rw [← reuse2Composite_g_eq]
  exact reuse2_probing

end OPINIReuse2
end Composition
end LeanSec
