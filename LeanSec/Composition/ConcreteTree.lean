import LeanSec.Composition.DAG

namespace LeanSec
namespace Composition
namespace ConcreteTree

open Gadget
open UniversalReg

/-! ## Two independent leaves feeding one combiner

The left leaf and the combiner are the already-audited concrete registered
splice from `Pipeline`.  The right leaf uses fresh input/random source names
and is wired into the combiner's other input.  Thus the gadget-level edges are
`left → combiner ← right`, not a path.
-/

abbrev left : GadgetInstance := UniversalReg.Concrete.upstream
abbrev combiner : GadgetInstance := UniversalReg.Concrete.downstream

/-- A source-disjoint copy of the concrete refresh leaf. -/
def rightCircuit : Circuit :=
  { gates := #[
      { kind := .inp 4 0, inputs := [] },
      { kind := .inp 4 1, inputs := [] },
      { kind := .rnd 2, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (2, 0)] }
    ] }

def right : GadgetInstance :=
  { circuit := rightCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 4 share 1
    output := fun share =>
      if share = 0 then { gate := 3, cycle := 1 }
      else { gate := 4, cycle := 1 }
    member := fun _ => true
    randomness := [.rnd 2 1] }

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

theorem right_opini : opiniSpec right transitionGlitch 1 := by
  apply (opini_iff_spec right transitionGlitch 1 (inputs_reached right)).mp
  refine ⟨?_, by decide⟩
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [right, rightCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

/-- The right leaf's own still-external input port. -/
def rightInputPorts : RegisterPorts right where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 5
    omega
  arrivalCycle := 1
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨4, rfl, rfl⟩
    · exact ⟨4, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

set_option maxHeartbeats 2000000 in
def rightPipeline : PipelineGadget 3 2 1 where
  g := right
  horizon_eq := rfl
  d_eq := rfl
  order_lt := by decide
  whole_window := by decide
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := rightInputPorts
  arrival_inside := by decide
  interface_injective := by decide
  source_partition := by decide
  port_source_exclusive := by decide
  forward_combinational := by decide
  pinned_init := by decide
  outCycle := 1
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
      simp [right] at heq ⊢
  output_pulse := by decide
  down_cert := opini_implies_pini right transitionGlitch 1 right_opini

/-- The second input domain of the isolated combiner. -/
def combinerRightPorts : RegisterPorts combiner where
  downstreamInput := 1
  input_bound := by decide
  inputGate := fun share => 2 + share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change 2 + share < 9
    omega
  arrivalCycle := 2
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨3, rfl, rfl⟩
    · exact ⟨3, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    omega

/-- In the explicit first composite, combiner input one survives as external
input one at copied gates 9 and 10. -/
def explicitSurvivingCombinerPort :
    RegisterPorts UniversalReg.Concrete.composite where
  downstreamInput := 1
  input_bound := by decide
  inputGate := fun share => 9 + share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change 9 + share < 16
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl <;> decide
  arrivalCycle := 2
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨3, rfl, rfl⟩
    · exact ⟨3, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    omega

theorem composedPipeline_g_eq :
    UniversalReg.Concrete.composedPipeline.g =
      UniversalReg.Concrete.composite := by
  change registeredComposite left UniversalReg.Concrete.ports = _
  exact UniversalReg.Concrete.registeredComposite_eq

/-- Transport a selected port together with its source-exclusivity contract
across equality of the underlying gadget instance. -/
private theorem transport_port_exclusive {first second : GadgetInstance}
    (h : first = second) (ports : RegisterPorts first)
    (hexclusive : PortSourceExclusive ports) :
    PortSourceExclusive (h ▸ ports) := by
  subst second
  exact hexclusive

/-- Transport does not change the selected port's arrival cycle. -/
private theorem transport_port_arrival {first second : GadgetInstance}
    (h : first = second) (ports : RegisterPorts first) :
    (h ▸ ports).arrivalCycle = ports.arrivalCycle := by
  subst second
  rfl

/-- The same surviving port on the definitionally compiled serial base. -/
def survivingCombinerPort :
    RegisterPorts UniversalReg.Concrete.composedPipeline.g :=
  composedPipeline_g_eq.symm ▸ explicitSurvivingCombinerPort

theorem survivingCombinerPort_inside :
    survivingCombinerPort.arrivalCycle < 3 := by
  change
    (composedPipeline_g_eq.symm ▸ explicitSurvivingCombinerPort).arrivalCycle < 3
  rw [transport_port_arrival composedPipeline_g_eq.symm
    explicitSurvivingCombinerPort]
  change 2 < 3
  decide

theorem survivingCombinerPort_arrival :
    survivingCombinerPort.arrivalCycle = 2 := by
  change
    (composedPipeline_g_eq.symm ▸ explicitSurvivingCombinerPort).arrivalCycle = 2
  rw [transport_port_arrival composedPipeline_g_eq.symm
    explicitSurvivingCombinerPort]
  rfl

set_option maxHeartbeats 2000000 in
theorem survivingCombinerPort_exclusive :
    PortSourceExclusive survivingCombinerPort := by
  apply transport_port_exclusive composedPipeline_g_eq.symm
    explicitSurvivingCombinerPort
  decide

set_option maxHeartbeats 2000000 in
theorem rightGlue :
    PortGlue rightPipeline
      (UniversalReg.Concrete.composedPipeline.withPorts
        survivingCombinerPort survivingCombinerPort_inside
        survivingCombinerPort_exclusive) := by
  refine ⟨?_, ?_⟩
  · change rightPipeline.outCycle + 1 = survivingCombinerPort.arrivalCycle
    rw [survivingCombinerPort_arrival]
    rfl
  change FullSourceDisjointness right
    (registeredComposite left UniversalReg.Concrete.ports)
  rw [UniversalReg.Concrete.registeredComposite_eq]
  decide

/-- The concrete non-serial composite obtained by the arbitrary-port closure.
Its two upstream refresh gadgets are siblings in the dependency graph. -/
def treePipeline : PipelineGadget 3 2 1 :=
  rightPipeline.wireLeaf UniversalReg.Concrete.composedPipeline right_opini
    survivingCombinerPort survivingCombinerPort_inside
    survivingCombinerPort_exclusive rightGlue

/-- The accepted serial base, viewed as the first edge of the tree
derivation. -/
theorem leftCombiner_build :
    TreeComposition UniversalReg.Concrete.composedPipeline := by
  unfold UniversalReg.Concrete.composedPipeline
  simpa [PipelineGadget.wireLeaf, PipelineGadget.withPorts] using
    (TreeComposition.wire
      UniversalReg.Concrete.upstreamPipeline
      UniversalReg.Concrete.downstreamPipeline
      UniversalReg.Concrete.upstream_opini
      (TreeComposition.leaf UniversalReg.Concrete.downstreamPipeline
        UniversalReg.Concrete.downstream_opini)
      UniversalReg.Concrete.downstreamPipeline.ports
      UniversalReg.Concrete.downstreamPipeline.arrival_inside
      UniversalReg.Concrete.downstreamPipeline.port_source_exclusive
      UniversalReg.Concrete.concreteGlue)

/-- The non-serial concrete instance is generated by the generic tree
closure induction. -/
theorem treePipeline_build : TreeComposition treePipeline := by
  exact TreeComposition.wire rightPipeline
    UniversalReg.Concrete.composedPipeline right_opini leftCombiner_build
    survivingCombinerPort survivingCombinerPort_inside
    survivingCombinerPort_exclusive rightGlue

/-- Mandatory non-vacuity: order-one transition-glitch probing security for
the concrete fork-join tree, obtained only from the closure invariant. -/
theorem treePipeline_probing :
    probingSecureSpec treePipeline.g transitionGlitch 1 :=
  TreeComposition.probing treePipeline_build

/-! ### Executable graph witness -/

def treeNode : Nat → GadgetInstance
  | 0 => left
  | 1 => right
  | _ => combiner

def leftEdge : ShareDomainEdge treeNode where
  source := 0
  target := 2
  ports := UniversalReg.Concrete.ports

def rightEdge : ShareDomainEdge treeNode where
  source := 1
  target := 2
  ports := combinerRightPorts

/-- The explicit graph has edges `0 → 2` and `1 → 2`; in particular, there
is no edge between the two upstream leaves. -/
def treeGraph : CompositionGraph where
  nodeCount := 3
  shareCount := 2
  node := treeNode
  edges := [leftEdge, rightEdge]
  outputNode := 2
  publicControl := fun index => (treeNode index).publicFixing

set_option maxHeartbeats 4000000 in
theorem treeGraph_wellFormed : treeGraph.WellFormed := by
  refine ⟨?_, by decide, ?_, by decide, ?_⟩
  · simp only [treeGraph, List.mem_range, List.all_eq_true,
      decide_eq_true_eq]
    intro index hindex
    have cases : index = 0 ∨ index = 1 ∨ index = 2 := by omega
    rcases cases with rfl | rfl | rfl
    · exact ⟨UniversalReg.Concrete.upstream_wf, rfl, trivial⟩
    · exact ⟨right_opini.1, rfl, trivial⟩
    · exact ⟨UniversalReg.Concrete.downstream_wf, rfl, trivial⟩
  · simp [treeGraph, leftEdge, rightEdge, treeNode,
      left, combiner,
      UniversalReg.Concrete.portAlignment]
    decide
  · simp [CompositionGraph.nodePairs, treeGraph, treeNode, left, combiner]
    decide

theorem treeGraph_nonserial :
    treeGraph.edges.map (fun edge => (edge.source, edge.target)) =
      [(0, 2), (1, 2)] := rfl

end ConcreteTree
end Composition
end LeanSec
