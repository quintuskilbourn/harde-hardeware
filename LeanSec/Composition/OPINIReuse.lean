import LeanSec.Composition.OPINIFixpoint

namespace LeanSec
namespace Composition
namespace OPINIReuse

open Gadget
open UniversalReg

/-! # Concrete producer reuse through the generic O-PINI closure

The tail below is a purely combinational fork--join whose connected input
gates are each consumed by *two* distinct internal gates, and whose two
paths reconverge at the declared outputs.  Composing the audited refresh
producer onto that port with the generic `UOPipelineGadget.wire` therefore
compiles a circuit in which each shared boundary register — carrying one
producer output share — literally drives multiple consumers.  Security of
the compiled reconvergent gadget is obtained *only* from the generic
closure (`OPINIComposition`), not from a hand audit of the composite. -/

/-- Fork--join consumer: share `s` is read by branch gate `2+s` (twice) and
again by reconvergence gate `4+s`, which also consumes the branch. -/
def forkJoinCircuit : Circuit :=
  { gates := #[
      { kind := .inp 2 0, inputs := [] },
      { kind := .inp 2 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (0, 0)] },
      { kind := .xor, inputs := [(1, 0), (1, 0)] },
      { kind := .xor, inputs := [(2, 0), (0, 0)] },
      { kind := .xor, inputs := [(3, 0), (1, 0)] }
    ] }

def forkJoin : GadgetInstance :=
  { circuit := forkJoinCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 2 share 2
    output := fun share => { gate := 4 + share, cycle := 2 }
    member := fun _ => true
    randomness := [] }

theorem forkJoin_wf : forkJoin.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [forkJoin, forkJoinCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Literal fanout inside the isolated consumer: each connected input gate
has two distinct reading gates. -/
theorem forkJoin_fanout :
    (0, 0) ∈ forkJoinCircuit.gates[2].inputs ∧
    (0, 0) ∈ forkJoinCircuit.gates[4].inputs ∧
    (1, 0) ∈ forkJoinCircuit.gates[3].inputs ∧
    (1, 0) ∈ forkJoinCircuit.gates[5].inputs := by
  decide

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

set_option maxRecDepth 10000 in
set_option maxHeartbeats 4000000 in
theorem forkJoin_opini : opiniSpec forkJoin transitionGlitch 1 := by
  apply (opini_iff_spec forkJoin transitionGlitch 1
    (inputs_reached forkJoin)).mp
  exact ⟨forkJoin_wf, by decide⟩

def forkJoinPorts : RegisterPorts forkJoin where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 6
    omega
  arrivalCycle := 2
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨2, rfl, rfl⟩
    · exact ⟨2, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

set_option maxHeartbeats 2000000 in
def forkJoinPipeline : PipelineGadget 3 2 1 where
  g := forkJoin
  horizon_eq := rfl
  d_eq := rfl
  order_lt := by decide
  whole_window := by decide
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := forkJoinPorts
  arrival_inside := by decide
  interface_injective := by decide
  source_partition := by decide
  port_source_exclusive := by decide
  forward_combinational := by decide
  pinned_init := by decide
  outCycle := 2
  output_at := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl <;> rfl
  output_inj := by
    intro i j hi hj heq
    change i < 2 at hi
    change j < 2 at hj
    have his : i = 0 ∨ i = 1 := by omega
    have hjs : j = 0 ∨ j = 1 := by omega
    rcases his with rfl | rfl <;> rcases hjs with rfl | rfl <;>
      simp [forkJoin] at heq ⊢
  output_pulse := by decide
  down_cert := opini_implies_pini forkJoin transitionGlitch 1 forkJoin_opini

/-! ## Closed leaves and the generic derivation -/

/-- The audited refresh producer, packaged as a closed O-PINI node. -/
def producerNode : UOPipelineGadget 3 2 1 :=
  UOPipelineGadget.ofLeaf UniversalReg.Concrete.upstreamPipeline
    UniversalReg.Concrete.upstream_opini

/-- The fanout consumer, packaged as a closed O-PINI node. -/
def forkJoinNode : UOPipelineGadget 3 2 1 :=
  UOPipelineGadget.ofLeaf forkJoinPipeline forkJoin_opini

theorem forkJoin_arrival_inside : forkJoinPorts.arrivalCycle < 3 := by
  decide

theorem forkJoin_port_exclusive : PortSourceExclusive forkJoinPorts := by
  decide

theorem reuseGlue : PortGlue producerNode.toPipelineGadget
    (forkJoinNode.toPipelineGadget.withPorts forkJoinPorts
      forkJoin_arrival_inside forkJoin_port_exclusive) := by
  refine ⟨rfl, ?_⟩
  decide

/-- The reconvergent producer-reuse composite, built exclusively by the
generic closure operation. -/
def reuseComposite : UOPipelineGadget 3 2 1 :=
  UOPipelineGadget.wire producerNode forkJoinNode forkJoinPorts
    forkJoin_arrival_inside forkJoin_port_exclusive reuseGlue

/-- The composite is a generic `OPINIComposition` derivation: two uniform
O-PINI leaves joined by one wiring step. -/
theorem reuseComposite_build : OPINIComposition reuseComposite :=
  OPINIComposition.wire producerNode forkJoinNode
    (OPINIComposition.leaf UniversalReg.Concrete.upstreamPipeline
      (opini_implies_uniform_of_le_one _ transitionGlitch 1 (Nat.le_refl 1)
        UniversalReg.Concrete.upstream_opini))
    (OPINIComposition.leaf forkJoinPipeline
      (opini_implies_uniform_of_le_one _ transitionGlitch 1 (Nat.le_refl 1)
        forkJoin_opini))
    forkJoinPorts forkJoin_arrival_inside forkJoin_port_exclusive reuseGlue

/-- The compiled gadget is the generic registered compiler's output. -/
theorem reuseComposite_g :
    reuseComposite.g =
      registeredComposite UniversalReg.Concrete.upstream forkJoinPorts := rfl

/-! ## The audited conclusions, obtained from the generic theorem -/

/-- Composite O-PINI: the reconvergent composite can itself be reused as an
upstream producer. -/
theorem reuse_opini :
    opiniSpec reuseComposite.g transitionGlitch 1 :=
  reuseComposite_build.opini

/-- Composite downstream-role PINI. -/
theorem reuse_pini :
    piniSpec reuseComposite.g transitionGlitch 1 :=
  reuseComposite_build.pini

/-- End-to-end probing security of the compiled reconvergent circuit under
the real transition-glitch expansion, via the generic closure only. -/
theorem reuse_probing :
    probingSecureSpec reuseComposite.g transitionGlitch 1 :=
  reuseComposite_build.probing

/-! ## Kernel-checked producer reuse in the compiled circuit

Gate 3 is the producer's output gate for share zero; the compiler's boundary
register 5 latches it, and register 5 is read by the two distinct suffix
consumers 9 (twice) and 11.  Share one is symmetric via register 6 and
consumers 10 and 12.  Gate 11 additionally reads gate 9, so the two paths
`5 → 9 → 11` and `5 → 11` reconverge at the declared output. -/

theorem producer_output_gates :
    (UniversalReg.Concrete.upstream.output 0).gate = 3 ∧
    (UniversalReg.Concrete.upstream.output 1).gate = 4 := by
  decide

/-- The literal compiled circuit: producer prefix, two shared boundary
registers, and the transported fanout suffix. -/
def compiledCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (2, 0)] },
      { kind := .reg, inputs := [(3, 1)] },
      { kind := .reg, inputs := [(4, 1)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(5, 0), (5, 0)] },
      { kind := .xor, inputs := [(6, 0), (6, 0)] },
      { kind := .xor, inputs := [(9, 0), (5, 0)] },
      { kind := .xor, inputs := [(10, 0), (6, 0)] }
    ] }

def compiled : GadgetInstance :=
  { circuit := compiledCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun input share =>
      if input < 1 then .inp 0 share 1 else .inp 2 share 2
    output := fun share => { gate := 11 + share, cycle := 2 }
    member := fun _ => true
    randomness := [.rnd 0 1]
    publicFixing := [(.iniReg 5, false), (.iniReg 6, false)] }

set_option maxHeartbeats 2000000 in
/-- The generic compiler's output is this literal reconvergent circuit. -/
theorem reuseComposite_g_eq : reuseComposite.g = compiled := by
  show registeredComposite UniversalReg.Concrete.upstream forkJoinPorts =
    compiled
  unfold registeredComposite compiled
  congr 1
  · simp only [registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, compiledCircuit, Circuit.mk.injEq]
    simp [UniversalReg.Concrete.upstream, forkJoin, forkJoinPorts,
      ConcreteSerial2.upstreamCircuit, forkJoinCircuit,
      boundaryRegisterGates, registeredDownGates, wireRegisteredDownGate,
      wireRegisteredEdge, connectedShare?, boundaryRegister,
      downstreamOffset]
    decide
  all_goals
    simp [UniversalReg.Concrete.upstream, forkJoin, forkJoinPorts,
      shiftDownSrc, unhideRegisteredInput, Nat.lt_one_iff,
      downstreamOffset, boundaryRegister, ConcreteSerial2.upstreamCircuit,
      forkJoinCircuit]
  all_goals funext share
  all_goals simp only [Node.mk.injEq, and_true]
  all_goals omega

theorem boundary_registers_latch_producer :
    reuseComposite.g.circuit.gates[5]? =
      some { kind := .reg, inputs := [(3, 1)] } ∧
    reuseComposite.g.circuit.gates[6]? =
      some { kind := .reg, inputs := [(4, 1)] } := by
  rw [reuseComposite_g_eq]
  decide

theorem producer_reused_by_two_consumers :
    reuseComposite.g.circuit.gates[9]? =
      some { kind := .xor, inputs := [(5, 0), (5, 0)] } ∧
    reuseComposite.g.circuit.gates[11]? =
      some { kind := .xor, inputs := [(9, 0), (5, 0)] } ∧
    reuseComposite.g.circuit.gates[10]? =
      some { kind := .xor, inputs := [(6, 0), (6, 0)] } ∧
    reuseComposite.g.circuit.gates[12]? =
      some { kind := .xor, inputs := [(10, 0), (6, 0)] } := by
  rw [reuseComposite_g_eq]
  decide

theorem outputs_reconverge :
    reuseComposite.g.output 0 = { gate := 11, cycle := 2 } ∧
    reuseComposite.g.output 1 = { gate := 12, cycle := 2 } := by
  rw [reuseComposite_g_eq]
  decide

set_option maxHeartbeats 4000000 in
/-- Functional non-vacuity: the compiled reconvergent composite recombines
to the refreshed identity of its single external secret. -/
theorem reuse_recombines :
    recombinesTo reuseComposite.g (fun secrets => secrets.getD 0 false) := by
  rw [reuseComposite_g_eq]
  decide

end OPINIReuse
end Composition
end LeanSec
