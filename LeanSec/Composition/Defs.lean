import LeanSec.Gadget

namespace LeanSec
namespace Composition

open Gadget

/-!
The interface graph below records exactly the data from Cassiers--Standaert
Definition 7 that is not present in `GadgetInstance`: which output sharing is
connected to which component input sharing, and which component output
sharings remain outputs of the composition.

`GadgetInstance.inputArrival` ranges over external `Src` values, whereas a
connected component input is driven by another component's output `Node`.
Consequently a connection must not be represented by equating those two
types.  It is an explicit edge here.  One edge denotes all `d` wires and the
definition of `connectedNode` below enforces preservation of the share index.
-/

/-- An input sharing of one component, before connections are hidden. -/
structure InputPort where
  component : Nat
  sharing : Nat
deriving DecidableEq, Repr

/-- A connection from a component's (sole, in the current `GadgetInstance`
API) output sharing to one input sharing of another component. -/
structure Connection where
  source : Nat
  target : InputPort
deriving DecidableEq, Repr

/-- The Definition-7 interface of a finite family of disjoint executions.
The composite execution is their union; each component's `member` describes
one summand.
Connections operate on complete sharings, and `outputs` selects the component
output sharings exposed by the composite gadget. -/
structure ExecutionComposition where
  componentCount : Nat
  shareCount : Nat
  component : Nat → GadgetInstance
  connections : List Connection
  outputs : List Nat

namespace ExecutionComposition

/-- All component input sharings, including the ones later hidden by wiring. -/
def allInputs (c : ExecutionComposition) : List InputPort :=
  (List.range c.componentCount).flatMap fun component =>
    (List.range (c.component component).inputCount).map fun sharing =>
      { component, sharing }

/-- Definition-7 inputs of the composite: precisely the unconnected inputs. -/
def externalInputs (c : ExecutionComposition) : List InputPort :=
  (allInputs c).filter fun input =>
    !(c.connections.map Connection.target).contains input

/-- The source node for share `share` of a connected input.  Using the same
`share` on the source output is the share-order condition of Definition 7. -/
def connectedNode (c : ExecutionComposition) (edge : Connection)
    (share : Nat) : Node :=
  (c.component edge.source).output share

/-- Membership in the union execution. -/
def compositeMember (c : ExecutionComposition) (n : Node) : Prop :=
  ∃ component < c.componentCount, (c.component component).member n = true

/-- Checkable mathematical side conditions of Definition 7: bounded ports,
one driver per connected input, pairwise-disjoint component executions, and
an acyclic component graph (witnessed by a strict topological rank). -/
def WellFormed (c : ExecutionComposition) : Prop :=
  (∀ component, component < c.componentCount →
      (c.component component).d = c.shareCount) ∧
  (∀ i, i < c.componentCount →
    ∀ j, j < c.componentCount →
      (c.component i).circuit = (c.component j).circuit ∧
      (c.component i).horizon = (c.component j).horizon) ∧
  (∀ edge ∈ c.connections,
      edge.source < c.componentCount ∧
      edge.target.component < c.componentCount ∧
      edge.target.sharing < (c.component edge.target.component).inputCount) ∧
  (c.connections.map Connection.target).Nodup ∧
  (∀ component ∈ c.outputs, component < c.componentCount) ∧
  c.outputs.Nodup ∧
  (∀ i, i < c.componentCount →
    ∀ j, j < c.componentCount → i ≠ j →
      ∀ n, (c.component i).member n = true →
        (c.component j).member n = false) ∧
  ∃ rank : Nat → Nat, ∀ edge ∈ c.connections,
    rank edge.source < rank edge.target.component

end ExecutionComposition

end Composition
end LeanSec
