import LeanSec.Composition.Pipeline

namespace LeanSec
namespace Composition

open Gadget
open UniversalReg

/-! # Acyclic share-domain composition

`Pipeline.compose` closes a registered serial splice, but the port carried by
its result is always the still-external port of the newly prepended gadget.
This module adds the missing structural operation: select any other admissible
external port of the certified composite.  Repeated selection and splicing
wires independent upstream leaves into distinct inputs of a common tail, so
the dependency graph need not be a path.

The graph layer below is deliberately separate from `GadgetInstance`.
`publicControl` records the public schedule without treating it as a secret
share-domain edge.  Node numbers are a topological order, making acyclicity a
finite executable check.
-/

/-- One whole-sharing edge.  `ports` identifies the target input domain; the
same share index is used at both ends through `PortAlignment`. -/
structure ShareDomainEdge (node : Nat → GadgetInstance) where
  source : Nat
  target : Nat
  ports : RegisterPorts (node target)

/-- A finite gadget-level dependency graph with public controls kept outside
the secret share-domain edge relation. -/
structure CompositionGraph where
  nodeCount : Nat
  shareCount : Nat
  node : Nat → GadgetInstance
  edges : List (ShareDomainEdge node)
  outputNode : Nat
  publicControl : Nat → List (Src × Bool)

namespace CompositionGraph

/-- Every ordered pair of distinct node identifiers. -/
def nodePairs (graph : CompositionGraph) : List (Nat × Nat) :=
  (List.range graph.nodeCount).flatMap fun left =>
    ((List.range graph.nodeCount).filter fun right => left < right).map
      fun right => (left, right)

/-- Executable graph well-formedness.

The checks are: component WF, a common share count, an in-range exposed
output, public-schedule agreement, bounded and topologically forward edges,
cycle/share-domain alignment, a single driver per target input domain, and
pairwise full source disjointness. -/
def WellFormed (graph : CompositionGraph) : Prop :=
  (List.range graph.nodeCount).all (fun index =>
      decide ((graph.node index).WF ∧
        (graph.node index).d = graph.shareCount ∧
        graph.publicControl index = (graph.node index).publicFixing)) = true ∧
  graph.outputNode < graph.nodeCount ∧
  graph.edges.all (fun edge =>
      decide (edge.source < graph.nodeCount ∧
        edge.target < graph.nodeCount ∧
        edge.source < edge.target ∧
        PortAlignment (graph.node edge.source)
          (graph.node edge.target) edge.ports)) = true ∧
  (graph.edges.map fun edge =>
      (edge.target, edge.ports.downstreamInput)).Nodup ∧
  (nodePairs graph).all (fun pair =>
      decide (FullSourceDisjointness
        (graph.node pair.1) (graph.node pair.2))) = true

instance (graph : CompositionGraph) : Decidable graph.WellFormed := by
  unfold WellFormed
  infer_instance

/-- The acyclicity component of `WellFormed` is witnessed by node identity as
a strict topological rank. -/
theorem edge_rank_lt {graph : CompositionGraph} (hwf : graph.WellFormed)
    (edge : ShareDomainEdge graph.node) (hedge : edge ∈ graph.edges) :
    edge.source < edge.target := by
  have hall := List.all_eq_true.mp hwf.2.2.1 edge hedge
  have hconditions := of_decide_eq_true hall
  exact hconditions.2.2.1

/-- All nodes use the graph's common share count. -/
theorem node_shareCount {graph : CompositionGraph} (hwf : graph.WellFormed)
    (index : Nat) (hindex : index < graph.nodeCount) :
    (graph.node index).d = graph.shareCount := by
  have hall := List.all_eq_true.mp hwf.1 index (by simpa using hindex)
  have hconditions := of_decide_eq_true hall
  exact hconditions.2.1

end CompositionGraph

namespace PipelineGadget

/-- Select another admissible still-external share-domain input without
changing the compiled gadget or its carried PINI certificate. -/
def withPorts {H d t : Nat} (tail : PipelineGadget H d t)
    (ports : RegisterPorts tail.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports) : PipelineGadget H d t :=
  { tail with
    ports := ports
    arrival_inside := arrival_inside
    port_source_exclusive := source_exclusive }

@[simp] theorem withPorts_g {H d t : Nat} (tail : PipelineGadget H d t)
    (ports : RegisterPorts tail.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports) :
    (tail.withPorts ports arrival_inside source_exclusive).g = tail.g := rfl

/-- Share-wise wiring into an arbitrary admissible external port preserves
the complete `PipelineGadget` invariant.  Security is inherited only from the
upstream O-PINI leaf and the tail's carried PINI certificate. -/
def wireLeaf {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : opiniSpec up.g transitionGlitch t)
    (ports : RegisterPorts tail.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports)
    (glue : PortGlue up
      (tail.withPorts ports arrival_inside source_exclusive)) :
    PipelineGadget H d t :=
  compose up (tail.withPorts ports arrival_inside source_exclusive) hup glue

@[simp] theorem wireLeaf_g {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : opiniSpec up.g transitionGlitch t)
    (ports : RegisterPorts tail.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports)
    (glue : PortGlue up
      (tail.withPorts ports arrival_inside source_exclusive)) :
    (wireLeaf up tail hup ports arrival_inside source_exclusive glue).g =
      registeredComposite up.g ports := rfl

/-- The arbitrary-port closure theorem with the unmodified PINI conclusion. -/
theorem wireLeaf_pini {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : opiniSpec up.g transitionGlitch t)
    (ports : RegisterPorts tail.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports)
    (glue : PortGlue up
      (tail.withPorts ports arrival_inside source_exclusive)) :
    piniSpec (registeredComposite up.g ports) transitionGlitch t := by
  exact (wireLeaf up tail hup ports arrival_inside source_exclusive glue).down_cert

/-- The arbitrary-port closure theorem with the unmodified end-to-end probing
security conclusion. -/
theorem wireLeaf_probing {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : opiniSpec up.g transitionGlitch t)
    (ports : RegisterPorts tail.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports)
    (glue : PortGlue up
      (tail.withPorts ports arrival_inside source_exclusive)) :
    probingSecureSpec (registeredComposite up.g ports)
      transitionGlitch t := by
  exact (wireLeaf up tail hup ports arrival_inside source_exclusive glue).probing

end PipelineGadget

/-! ## Closure induction for rooted fan-in trees -/

/-- A well-formed composition derivation indexed by its compiled invariant.

The base is an O-PINI leaf.  Each step adds one source-disjoint O-PINI leaf
and connects its complete output share domain to any admissible still-external
input of the already closed tail.  Because every new node has exactly one
outgoing edge and node rank decreases toward the tail, these derivations are
rooted fan-in trees (paths are only the unary special case). -/
inductive TreeComposition {H d t : Nat} : PipelineGadget H d t → Prop where
  | leaf (gadget : PipelineGadget H d t)
      (opini : opiniSpec gadget.g transitionGlitch t) :
      TreeComposition gadget
  | wire (up tail : PipelineGadget H d t)
      (up_opini : opiniSpec up.g transitionGlitch t)
      (tail_tree : TreeComposition tail)
      (ports : RegisterPorts tail.g)
      (arrival_inside : ports.arrivalCycle < H)
      (source_exclusive : PortSourceExclusive ports)
      (glue : PortGlue up
        (tail.withPorts ports arrival_inside source_exclusive)) :
      TreeComposition
        (up.wireLeaf tail up_opini ports arrival_inside source_exclusive glue)

namespace TreeComposition

/-- Closure induction with the unmodified downstream-role PINI conclusion.
The induction consumes O-PINI only at leaves; every closed tail is reused
through its carried PINI invariant. -/
theorem pini {H d t : Nat} {composite : PipelineGadget H d t}
    (build : TreeComposition composite) :
    piniSpec composite.g transitionGlitch t := by
  induction build with
  | leaf gadget hopini =>
      exact opini_implies_pini gadget.g transitionGlitch t hopini
  | wire up tail hup _ ports harrival hexclusive glue _ =>
      exact PipelineGadget.wireLeaf_pini up tail hup ports harrival
        hexclusive glue

/-- Every rooted fan-in tree produced by the closure is probing secure under
the real transition-glitch expansion. -/
theorem probing {H d t : Nat} {composite : PipelineGadget H d t}
    (_build : TreeComposition composite) :
    probingSecureSpec composite.g transitionGlitch t :=
  composite.probing

end TreeComposition

end Composition
end LeanSec
