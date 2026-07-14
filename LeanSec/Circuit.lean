import LeanSec.Security

namespace LeanSec
namespace Circuit

/-- Whether `dst` has a latency-zero predecessor that Kahn's algorithm has not
yet removed. -/
def hasRemainingPred (edges : List (Nat × Nat))
    (remaining : List Nat) (dst : Nat) : Bool :=
  edges.any fun (src, dst') => remaining.contains src && dst' == dst

/-- One parallel Kahn step: discard every vertex whose current indegree is zero. -/
def kahnStep (edges : List (Nat × Nat))
    (remaining : List Nat) : List Nat :=
  remaining.filter (hasRemainingPred edges remaining)

/-- Run enough parallel Kahn steps for a graph with `fuel` vertices. -/
def kahnLoop (edges : List (Nat × Nat)) : Nat → List Nat → List Nat
  | 0, remaining => remaining
  | fuel + 1, remaining => kahnLoop edges fuel (kahnStep edges remaining)

/-- Executable Kahn check for acyclicity of the latency-zero subgraph.  Every
nonempty acyclic graph loses at least one vertex per step, so `gates.size`
parallel steps suffice. -/
def combAcyclic (c : Circuit) : Bool :=
  (kahnLoop c.combEdges c.gates.size (List.range c.gates.size)).isEmpty

/-- Structural well-formedness: valid indices and gate arities together with
absence of a combinational loop. -/
def WF (c : Circuit) : Prop :=
  c.indicesOk = true ∧ c.combAcyclic = true

instance (c : Circuit) : Decidable c.WF := by
  unfold WF
  infer_instance

theorem wf_iff (c : Circuit) :
    c.WF ↔ c.indicesOk = true ∧ c.combAcyclic = true :=
  Iff.rfl

theorem indicesOk_of_wf {c : Circuit} (h : c.WF) : c.indicesOk = true :=
  h.1

theorem combAcyclic_of_wf {c : Circuit} (h : c.WF) : c.combAcyclic = true :=
  h.2

theorem combAcyclic_empty : combAcyclic { gates := #[] } = true := by
  rfl

theorem wf_empty : WF { gates := #[] } := by
  simp [WF, indicesOk, combAcyclic, kahnLoop, combEdges]

end Circuit
end LeanSec
