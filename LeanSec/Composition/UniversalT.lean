import LeanSec.Composition.GenericSerial2

namespace LeanSec
namespace Composition
namespace UniversalT

open Gadget

/-!
This file tests the proposed definitional execution-graph route at its key
transport lemma.  The graph below is genuinely unrolled: vertices are `Node`
values and every edge is a `Node → Node` edge, with no static circuit edge or
latency reused between cycles.

The proposed same-environment restriction lemma is nevertheless false for the
downstream component.  A serial edge changes the downstream input node's
definition (and hence every downstream cone containing it).  Restriction is
valid for the upstream prefix, but downstream evaluation agrees with an
isolated downstream execution only after substituting the upstream output into
the downstream input environment.  That substitution is exactly the semantic
transport/factorization which cannot follow by definitional reduction.
-/

/-- Operations needed by the smallest counterexample.  `copy` has one
explicit unrolled predecessor. -/
inductive GraphKind where
  | source (src : Src)
  | copy
deriving DecidableEq, Repr

/-- One definition in an explicitly unrolled execution DAG. -/
structure NodeDef where
  node : Node
  kind : GraphKind
  inputs : List Node
deriving DecidableEq, Repr

/-- A topologically scheduled explicit execution graph.  Edges occur only in
`NodeDef.inputs`, so they connect complete `Node` values, including cycles. -/
structure ExecutionGraph where
  schedule : List NodeDef
deriving Repr

namespace ExecutionGraph

def definition (graph : ExecutionGraph) (node : Node) : Option NodeDef :=
  (graph.schedule.find? fun entry => entry.node == node)

private def nodeValue (env : Env) (values : List (Node × Bool))
    (entry : NodeDef) : Bool :=
  match entry.kind with
  | .source src => env src
  | .copy =>
      match entry.inputs with
      | predecessor :: _ =>
          (Execution.lookupAssoc predecessor values).getD false
      | [] => false

/-- Definitional evaluator for an explicit DAG, by its topological schedule. -/
def evalEntries (graph : ExecutionGraph) (env : Env) : List (Node × Bool) :=
  graph.schedule.foldl
    (fun values entry => (entry.node, nodeValue env values entry) :: values) []

def eval (graph : ExecutionGraph) (env : Env) (node : Node) : Bool :=
  (Execution.lookupAssoc node (evalEntries graph env)).getD false

/-- Same-environment evaluation restriction, the key lemma requested by the
proposed route. -/
def RestrictsTo (union component : ExecutionGraph) : Prop :=
  ∀ env entry, entry ∈ component.schedule →
    eval union env entry.node = eval component env entry.node

end ExecutionGraph

private def upstreamOutput : Node := { gate := 0, cycle := 1 }
private def downstreamInput : Node := { gate := 1, cycle := 1 }
private def upstreamPrevious : Node := { gate := 0, cycle := 0 }
private def downstreamPrevious : Node := { gate := 1, cycle := 0 }

private def upstreamSource : Src := .inp 0 0 1
private def downstreamSource : Src := .inp 1 0 1
private def upstreamPreviousSource : Src := .inp 0 0 0
private def downstreamPreviousSource : Src := .inp 1 0 0

private def upstreamPreviousEntry : NodeDef where
  node := upstreamPrevious
  kind := .source upstreamPreviousSource
  inputs := []

private def downstreamPreviousEntry : NodeDef where
  node := downstreamPrevious
  kind := .source downstreamPreviousSource
  inputs := []

private def upstreamEntry : NodeDef where
  node := upstreamOutput
  kind := .source upstreamSource
  inputs := []

private def isolatedDownstreamEntry : NodeDef where
  node := downstreamInput
  kind := .source downstreamSource
  inputs := []

private def connectedDownstreamEntry : NodeDef where
  node := downstreamInput
  kind := .copy
  inputs := [upstreamOutput]

/-- A component whose cycle-1 output is an external input source. -/
def upstreamGraph : ExecutionGraph where
  schedule := [upstreamPreviousEntry, upstreamEntry]

/-- The isolated downstream input node at the same cycle. -/
def downstreamGraph : ExecutionGraph where
  schedule := [downstreamPreviousEntry, isolatedDownstreamEntry]

/-- Clean serial union.  The two node ranges remain disjoint and the only
cross-boundary edge is the complete cycle-1 edge
`upstreamOutput → downstreamInput`. -/
def serialUnionGraph : ExecutionGraph where
  schedule := [upstreamPreviousEntry, downstreamPreviousEntry,
    upstreamEntry, connectedDownstreamEntry]

theorem component_node_ranges_disjoint :
    ∀ node, node ∈ upstreamGraph.schedule.map NodeDef.node →
      node ∉ downstreamGraph.schedule.map NodeDef.node := by
  intro node hup hdown
  simp [upstreamGraph, downstreamGraph, upstreamPreviousEntry,
    downstreamPreviousEntry, upstreamEntry, isolatedDownstreamEntry,
    upstreamOutput, downstreamInput, upstreamPrevious,
    downstreamPrevious] at hup hdown
  rcases hup with hup | hup <;> rcases hdown with hdown | hdown
  all_goals
    have hgate : (0 : Nat) = 1 :=
      congrArg Node.gate (hup.symm.trans hdown)
    omega

theorem serial_edge_is_clean_node_edge :
    (serialUnionGraph.definition downstreamInput).map NodeDef.inputs =
      some [upstreamOutput] := by
  decide

/-- Prefix restriction really is definitional: adding later nodes cannot
change evaluation of the upstream node. -/
theorem upstream_eval_restricts :
    serialUnionGraph.RestrictsTo upstreamGraph := by
  intro env entry hentry
  simp [upstreamGraph] at hentry
  rcases hentry with rfl | rfl <;> rfl

/-- The requested restriction lemma fails on the downstream side, even with
disjoint component ranges and a clean, cycle-exact Node edge. -/
theorem downstream_eval_does_not_restrict :
    ¬ serialUnionGraph.RestrictsTo downstreamGraph := by
  intro hrestrict
  let env : Env := fun src => src == upstreamSource
  have h := hrestrict env
    isolatedDownstreamEntry
    (by simp [downstreamGraph])
  change true = false at h
  contradiction

/-- The correct downstream statement changes the isolated component's
environment at its input source.  This is substitution, not restriction. -/
def substitutedDownstreamEnv (env : Env) : Env := fun src =>
  if src == downstreamSource then
    upstreamGraph.eval env upstreamOutput
  else
    env src

theorem downstream_eval_after_boundary_substitution (env : Env) :
    serialUnionGraph.eval env downstreamInput =
      downstreamGraph.eval (substitutedDownstreamEnv env) downstreamInput := by
  rfl

/-- Glitch frontier for the explicit graph.  Source nodes are their own
frontier; a copy exposes its explicit predecessor. -/
def graphGlitch (graph : ExecutionGraph) (node : Node) : List Node :=
  match graph.definition node with
  | some entry => if entry.inputs.isEmpty then [node] else entry.inputs
  | none => [node]

/-- Transition expansion is directly on unrolled nodes. -/
def graphTransition (node : Node) : List Node :=
  if node.cycle > 0 then
    [{ gate := node.gate, cycle := node.cycle - 1 }, node]
  else
    [node]

def graphTransitionGlitch (graph : ExecutionGraph) (node : Node) : List Node :=
  ((graphTransition node).flatMap (graphGlitch graph)).eraseDups

/-- The in-component expansion is not preserved at a connected downstream
input.  Its union frontier contains the upstream node, while its isolated
frontier contains the old downstream source node. -/
theorem downstream_transitionGlitch_is_not_component_local :
    ¬ Expansion.SameNodes
      (graphTransitionGlitch serialUnionGraph downstreamInput)
      (graphTransitionGlitch downstreamGraph downstreamInput) := by
  intro hlocal
  have hmember := (hlocal upstreamOutput).mp
    (by decide : upstreamOutput ∈
      graphTransitionGlitch serialUnionGraph downstreamInput)
  exact (by decide : upstreamOutput ∉
    graphTransitionGlitch downstreamGraph downstreamInput) hmember

/-- Independently, the advertised implication without `t < d` is already
false in the audited `GadgetInstance` semantics. -/
theorem strict_share_order_is_logically_necessary :
    ∃ g : Gadget.GadgetInstance,
      opiniSpec g transitionGlitch 1 ∧
      ¬ probingSecureSpec g transitionGlitch 1 :=
  GenericSerial2.opini_does_not_imply_probing_at_full_share_order

/-- Kernel-checked form of the exact obstruction: all structural conditions
advertised for the definitional argument hold, while its key conclusion does
not. -/
theorem disjoint_node_ranges_and_clean_wiring_do_not_imply_restriction :
    (∀ node, node ∈ upstreamGraph.schedule.map NodeDef.node →
      node ∉ downstreamGraph.schedule.map NodeDef.node) ∧
    (serialUnionGraph.definition downstreamInput).map NodeDef.inputs =
      some [upstreamOutput] ∧
    serialUnionGraph.RestrictsTo upstreamGraph ∧
    ¬ serialUnionGraph.RestrictsTo downstreamGraph :=
  ⟨component_node_ranges_disjoint, serial_edge_is_clean_node_edge,
    upstream_eval_restricts, downstream_eval_does_not_restrict⟩

end UniversalT
end Composition
end LeanSec

#print axioms LeanSec.Composition.UniversalT.upstream_eval_restricts
#print axioms LeanSec.Composition.UniversalT.downstream_eval_does_not_restrict
#print axioms LeanSec.Composition.UniversalT.downstream_eval_after_boundary_substitution
#print axioms LeanSec.Composition.UniversalT.downstream_transitionGlitch_is_not_component_local
#print axioms LeanSec.Composition.UniversalT.strict_share_order_is_logically_necessary
#print axioms LeanSec.Composition.UniversalT.disjoint_node_ranges_and_clean_wiring_do_not_imply_restriction
