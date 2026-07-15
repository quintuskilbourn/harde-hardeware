import LeanSec.Composition.DAG

namespace LeanSec
namespace Composition

open Gadget
open UniversalReg

/-! # O-PINI producer-reuse boundary

This module records the invariant which a producer-reuse closure would have
to carry, and supplies a concrete split--reconverge circuit.  The concrete
circuit is deliberately not obtained by duplicating its producer: gates zero
and one each drive both registered branches.
-/

/-- A pipeline carrying the output-preserving certificate required when the
compiled gadget is to be reused as an upstream producer. -/
structure OPINIPipelineGadget (H d t : Nat) extends PipelineGadget H d t where
  out_cert : opiniSpec g transitionGlitch t

namespace OPINIPipelineGadget

/-- Every O-PINI-carrying pipeline still has the audited end-to-end probing
security conclusion. -/
theorem probing {H d t : Nat} (P : OPINIPipelineGadget H d t) :
    probingSecureSpec P.g transitionGlitch t :=
  P.toPipelineGadget.probing

/-- An O-PINI leaf can be packaged without changing its structural data. -/
def ofLeaf {H d t : Nat} (P : PipelineGadget H d t)
    (hopini : opiniSpec P.g transitionGlitch t) :
    OPINIPipelineGadget H d t where
  toPipelineGadget := P.ofLeaf hopini
  out_cert := hopini

end OPINIPipelineGadget

/-! ## The exact witness feedback obligation

For one serial splice, the tail witness is demanded from the upstream
certificate.  To preserve O-PINI, the upstream witness must in turn be
observable at the tail output.  `WitnessFeedbackClosed` states precisely the
finite share-set condition which closes this feedback without assuming a
security property of the composite.
-/

/-- The output witness sets chosen for the two components are mutually
closed: the upstream demand contains the tail witness, while every upstream
witness and every boundary demand is already contained in the tail's output
demand. -/
def WitnessFeedbackClosed (d : Nat) (outputs boundary tailB upB : List Nat) :
    Prop :=
  (∀ share ∈ tailB, share ∈
    propagatedShares d outputs tailB boundary) ∧
  (∀ share ∈ upB, share ∈ shareUnion d outputs tailB) ∧
  (∀ share ∈ boundary, share ∈ shareUnion d outputs tailB)

instance (d : Nat) (outputs boundary tailB upB : List Nat) :
    Decidable (WitnessFeedbackClosed d outputs boundary tailB upB) := by
  unfold WitnessFeedbackClosed
  infer_instance

/-- The current one-way `compose_pini` propagation always closes the first
half of the feedback equation: every tail witness is demanded upstream. -/
theorem tailWitness_propagates (d : Nat) (outputs tailB boundary : List Nat)
    (hbound : ∀ share ∈ tailB, share < d) :
    ∀ share ∈ tailB,
      share ∈ propagatedShares d outputs tailB boundary := by
  intro share hshare
  simp only [propagatedShares, shareUnion, List.mem_filter, List.mem_range,
    Bool.or_eq_true, List.contains_iff_mem]
  exact ⟨hbound share hshare, Or.inl ⟨hbound share hshare, Or.inr hshare⟩⟩

/-- Local witness-size bounds alone do not imply the missing reverse
feedback.  This finite countermodel is the obstruction to promoting the
existing PINI-carrying record to O-PINI by merely retaining both local
certificates. -/
theorem witnessFeedback_not_from_local_bounds :
    ∃ d outputs boundary tailB upB,
      tailB.length ≤ 1 ∧ upB.length ≤ 1 ∧
      (∀ share ∈ outputs ++ boundary ++ tailB ++ upB, share < d) ∧
      ¬ WitnessFeedbackClosed d outputs boundary tailB upB := by
  refine ⟨2, [], [], [0], [1], by decide, by decide, ?_, ?_⟩
  · decide
  · decide

namespace ConcreteReconvergent

/-! ## Concrete producer reuse and reconvergence

At cycle zero, producer gates 0 and 1 each fan out to both branch-register
pairs `(2,3)` and `(4,5)`.  A second registered layer `(6,7)` and `(8,9)`
feeds both sides of the final XOR combiner.  The duplicate right value is
cancelled only at the combiner, so both fanout branches are live ancestors of
each declared output.
-/

def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .reg, inputs := [(1, 1)] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .reg, inputs := [(1, 1)] },
      { kind := .reg, inputs := [(2, 1)] },
      { kind := .reg, inputs := [(3, 1)] },
      { kind := .reg, inputs := [(4, 1)] },
      { kind := .reg, inputs := [(5, 1)] },
      { kind := .xor, inputs := [(6, 0), (8, 0)] },
      { kind := .xor, inputs := [(10, 0), (8, 0)] },
      { kind := .xor, inputs := [(7, 0), (9, 0)] },
      { kind := .xor, inputs := [(12, 0), (9, 0)] }
    ] }

def gadget : GadgetInstance :=
  { circuit := circuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share =>
      if share = 0 then { gate := 11, cycle := 2 }
      else { gate := 13, cycle := 2 }
    member := fun _ => true
    randomness := []
    publicFixing := (List.range 8).map fun index =>
      (.iniReg (index + 2), false) }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

theorem gadget_wf : gadget.WF := by
  refine ⟨circuit_wf, by decide, by decide, by decide, by decide, by decide⟩

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

set_option maxRecDepth 10000 in
set_option maxHeartbeats 8000000 in
theorem reconvergent_opini :
    opiniSpec gadget transitionGlitch 1 := by
  apply (opini_iff_spec gadget transitionGlitch 1
    (inputs_reached gadget)).mp
  exact ⟨gadget_wf, by decide⟩

/-- The fork--join does not obtain security by discarding its input: its
recombined output is the input secret. -/
theorem reconvergent_recombines :
    recombinesTo gadget (fun secrets => secrets.getD 0 false) := by
  set_option maxHeartbeats 4000000 in
    decide

def inputPorts : RegisterPorts gadget where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 14
    omega
  arrivalCycle := 0
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨0, rfl, rfl⟩
    · exact ⟨0, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

set_option maxHeartbeats 4000000 in
def pipelineBase : PipelineGadget 3 2 1 where
  g := gadget
  horizon_eq := rfl
  d_eq := rfl
  order_lt := by decide
  whole_window := by decide
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := inputPorts
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
      simp [gadget] at heq ⊢
  output_pulse := by decide
  down_cert := opini_implies_pini gadget transitionGlitch 1
    reconvergent_opini

/-- The concrete shared-producer circuit inhabits the strengthened invariant
proposed for producer-reuse closure. -/
def opiniPipeline : OPINIPipelineGadget 3 2 1 :=
  OPINIPipelineGadget.ofLeaf pipelineBase reconvergent_opini

/-- End-to-end security is obtained from the O-PINI-carrying pipeline
invariant, with the unmodified audited conclusion. -/
theorem reconvergent_probing :
    probingSecureSpec gadget transitionGlitch 1 :=
  opiniPipeline.probing

/-- Both producer gates have two distinct consumers, establishing literal
producer reuse in the compiled circuit rather than duplicated producers. -/
theorem producer_fanout_edges :
    (0, 1) ∈ circuit.gates[2].inputs ∧
    (0, 1) ∈ circuit.gates[4].inputs ∧
    (1, 1) ∈ circuit.gates[3].inputs ∧
    (1, 1) ∈ circuit.gates[5].inputs := by
  decide

/-- Both branches reconverge in each final output's combinational ancestry. -/
theorem branches_reconverge :
    (6, 0) ∈ circuit.gates[10].inputs ∧
    (8, 0) ∈ circuit.gates[10].inputs ∧
    (7, 0) ∈ circuit.gates[12].inputs ∧
    (9, 0) ∈ circuit.gates[12].inputs := by
  decide

/-! ### Executable gadget-level graph witness -/

def producerCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] }
    ] }

def producer : GadgetInstance :=
  { circuit := producerCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share => { gate := share, cycle := 0 }
    member := fun _ => true
    randomness := [] }

def leftCircuit : Circuit :=
  { gates := #[
      { kind := .inp 1 0, inputs := [] },
      { kind := .inp 1 1, inputs := [] }
    ] }

def left : GadgetInstance :=
  { circuit := leftCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 1 share 1
    output := fun share => { gate := share, cycle := 1 }
    member := fun _ => true
    randomness := [] }

def rightCircuit : Circuit :=
  { gates := #[
      { kind := .inp 2 0, inputs := [] },
      { kind := .inp 2 1, inputs := [] }
    ] }

def right : GadgetInstance :=
  { circuit := rightCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 2 share 1
    output := fun share => { gate := share, cycle := 1 }
    member := fun _ => true
    randomness := [] }

def combinerCircuit : Circuit :=
  { gates := #[
      { kind := .inp 3 0, inputs := [] },
      { kind := .inp 3 1, inputs := [] },
      { kind := .inp 4 0, inputs := [] },
      { kind := .inp 4 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (3, 0)] }
    ] }

def combiner : GadgetInstance :=
  { circuit := combinerCircuit
    horizon := 3
    d := 2
    inputCount := 2
    inputArrival := fun input share =>
      if input = 0 then .inp 3 share 2 else .inp 4 share 2
    output := fun share => { gate := 4 + share, cycle := 2 }
    member := fun _ => true
    randomness := [] }

def unaryPorts (g : GadgetInstance) (sharing cycle : Nat)
    (hinputs : g.inputCount = 1) (hd : g.d = 2)
    (hgates : g.circuit.gates.size = 2)
    (hlookup : ∀ share, share < 2 →
      g.circuit.gates[share]? =
        some { kind := .inp sharing share, inputs := [] })
    (harrival : ∀ share, share < 2 →
      g.inputArrival 0 share = .inp sharing share cycle) :
    RegisterPorts g where
  downstreamInput := 0
  input_bound := by omega
  inputGate := fun share => share
  input_gate_bound := by omega
  arrivalCycle := cycle
  input_source_coherent := by
    intro share hshare
    have hshare' : share < 2 := by simpa [hd] using hshare
    exact ⟨sharing, hlookup share hshare', harrival share hshare'⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

def leftPorts : RegisterPorts left :=
  unaryPorts left 1 1 rfl rfl rfl (by decide) (by decide)

def rightPorts : RegisterPorts right :=
  unaryPorts right 2 1 rfl rfl rfl (by decide) (by decide)

def combinerLeftPorts : RegisterPorts combiner where
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
    · exact ⟨3, rfl, rfl⟩
    · exact ⟨3, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

def combinerRightPorts : RegisterPorts combiner where
  downstreamInput := 1
  input_bound := by decide
  inputGate := fun share => 2 + share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change 2 + share < 6
    omega
  arrivalCycle := 2
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨4, rfl, rfl⟩
    · exact ⟨4, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    omega

def graphNode : Nat → GadgetInstance
  | 0 => producer
  | 1 => left
  | 2 => right
  | _ => combiner

def producerLeftEdge : ShareDomainEdge graphNode where
  source := 0
  target := 1
  ports := leftPorts

def producerRightEdge : ShareDomainEdge graphNode where
  source := 0
  target := 2
  ports := rightPorts

def leftCombinerEdge : ShareDomainEdge graphNode where
  source := 1
  target := 3
  ports := combinerLeftPorts

def rightCombinerEdge : ShareDomainEdge graphNode where
  source := 2
  target := 3
  ports := combinerRightPorts

/-- The graph has the split--reconverge shape
`0 → 1 → 3` and `0 → 2 → 3`, with node zero reused as producer. -/
def graph : CompositionGraph where
  nodeCount := 4
  shareCount := 2
  node := graphNode
  edges := [producerLeftEdge, producerRightEdge,
    leftCombinerEdge, rightCombinerEdge]
  outputNode := 3
  publicControl := fun index => (graphNode index).publicFixing

private theorem producer_wf : producer.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [producer, producerCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

private theorem left_wf : left.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [left, leftCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

private theorem right_wf : right.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [right, rightCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

private theorem combiner_wf : combiner.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [combiner, combinerCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem graph_shape :
    graph.edges.map (fun edge => (edge.source, edge.target)) =
      [(0, 1), (0, 2), (1, 3), (2, 3)] := rfl

set_option maxHeartbeats 4000000 in
theorem graph_wellFormed : graph.WellFormed := by
  refine ⟨?_, by decide, ?_, by decide, ?_⟩
  · simp only [graph, List.mem_range, List.all_eq_true, decide_eq_true_eq]
    intro index hindex
    have cases : index = 0 ∨ index = 1 ∨ index = 2 ∨ index = 3 := by omega
    rcases cases with rfl | rfl | rfl | rfl
    · exact ⟨producer_wf, rfl, trivial⟩
    · exact ⟨left_wf, rfl, trivial⟩
    · exact ⟨right_wf, rfl, trivial⟩
    · exact ⟨combiner_wf, rfl, trivial⟩
  · simp [graph, producerLeftEdge, producerRightEdge, leftCombinerEdge,
      rightCombinerEdge, graphNode, PortAlignment, producer, left, right,
      combiner, leftPorts, rightPorts, unaryPorts, combinerLeftPorts,
      combinerRightPorts]
  · simp [CompositionGraph.nodePairs, graph, graphNode]
    decide

end ConcreteReconvergent

end Composition
end LeanSec
