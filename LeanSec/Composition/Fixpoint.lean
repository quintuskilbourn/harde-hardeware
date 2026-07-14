import LeanSec.Composition.Serial2

namespace LeanSec
namespace Composition

/-- One backward propagation step on the component graph.  A component needed
by the global simulator makes every direct predecessor needed as well. -/
def predecessorStep (c : ExecutionComposition) (needed : List Nat) : List Nat :=
  (needed ++
    (c.connections.filter fun edge => needed.contains edge.target.component).map
      Connection.source).eraseDups

def PredecessorClosed (c : ExecutionComposition) (needed : List Nat) : Prop :=
  predecessorStep c needed = needed

theorem mem_predecessorStep (c : ExecutionComposition) (needed : List Nat)
    {component : Nat} (hcomponent : component ∈ needed) :
    component ∈ predecessorStep c needed := by
  simp [predecessorStep, hcomponent]

/-- For the serial graph `0 → 1`, requesting the downstream component makes
the upstream component appear after one backward step. -/
theorem serial2_downstream_adds_upstream
    {upstream downstream : Gadget.GadgetInstance}
    (w : Serial2Wiring upstream downstream) (needed : List Nat)
    (hdownstream : 1 ∈ needed) :
    0 ∈ predecessorStep w.description needed := by
  simp [predecessorStep, Serial2Wiring.description,
    Serial2Wiring.serialConnection, hdownstream]

/-- The corresponding fixpoint fact: every predecessor-closed demand set
containing the downstream component also contains the upstream component. -/
theorem serial2_closed_downstream_contains_upstream
    {upstream downstream : Gadget.GadgetInstance}
    (w : Serial2Wiring upstream downstream) (needed : List Nat)
    (hclosed : PredecessorClosed w.description needed)
    (hdownstream : 1 ∈ needed) :
    0 ∈ needed := by
  have h := serial2_downstream_adds_upstream w needed hdownstream
  rw [hclosed] at h
  exact h

end Composition
end LeanSec
