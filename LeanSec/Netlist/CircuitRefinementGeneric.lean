import LeanSec.Netlist.CellRefinement

/-!
Generic whole-circuit frontier composition for parser-expanded netlists.

This module proves the composition layer independently of DOM-AND and HPC2:
an arbitrary-length ordered list of locally certified cell-output expansions
has equal executable `glitchGates` frontiers in the expanded and atomic
circuits.  It also proves the required substitution-parametric local identity
for every combinational function and alias in the parser table.

Exact current boundary: the Python parser itself does not emit a Lean witness
that its two arrays satisfy `ZeroOrdered` and `OutputLocalRefinement`.  Those
structural certificates remain premises of the generic theorem.  Thus this is
an acyclic-composition intermediate, not a proof about parsing arbitrary text.
-/

namespace LeanSec.Netlist.CircuitRefinementGeneric

open LeanSec LeanSec.Expansion

/-- Every latency-zero edge points to a smaller gate index.  This is the
topological invariant established by the parser before it expands cells. -/
def ZeroOrdered (c : Circuit) : Prop :=
  ∀ (gate : Nat) (g : Gate), c.gates[gate]? = some g →
    ∀ (input : Nat × Nat), input ∈ g.inputs → input.2 = 0 → input.1 < gate

/-- A fuel-independent frontier for circuits whose latency-zero edges are
topologically ordered.  The fallback branch only gives total semantics outside
that intended domain. -/
def orderedFrontier (c : Circuit) (gate : Nat) : List Nat :=
  match hgate : c.gates[gate]? with
  | none => [gate]
  | some g =>
      let inputs := g.inputs.filter (fun input => input.2 == 0)
      if inputs.isEmpty then
        [gate]
      else
        (inputs.flatMap fun input =>
          if hlt : input.1 < gate then orderedFrontier c input.1 else [input.1]).eraseDups
termination_by gate

private theorem flatMap_congr_of_mem {α β : Type} (xs : List α)
    (f g : α → List β) (h : ∀ x ∈ xs, f x = g x) :
    xs.flatMap f = xs.flatMap g := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
      simp only [List.flatMap_cons]
      rw [h x (by simp), ih]
      intro y hy
      exact h y (by simp [hy])

theorem glitchGates_eq_orderedFrontier (c : Circuit) (hordered : ZeroOrdered c)
    (gate fuel : Nat) (hgate : gate < fuel) :
    glitchGates c fuel gate = orderedFrontier c gate := by
  induction fuel generalizing gate with
  | zero => simp at hgate
  | succ fuel ih =>
      rw [glitchGates, orderedFrontier]
      cases hg : c.gates[gate]? with
      | none => simp only [hg]
      | some g =>
          simp only [hg]
          let inputs := g.inputs.filter (fun input => input.2 == 0)
          split
          · rfl
          · rename_i hempty
            apply congrArg List.eraseDups
            change List.flatMap (fun input => glitchGates c fuel input.1) inputs =
              List.flatMap (fun input =>
                if hlt : input.1 < gate then orderedFrontier c input.1 else [input.1]) inputs
            apply flatMap_congr_of_mem
            intro input hmem
            have hmem' : input ∈ g.inputs.filter (fun x => x.2 == 0) := by
              exact hmem
            have hzero : input.2 = 0 := by
              simpa using (List.mem_filter.mp hmem').2
            have hlt : input.1 < gate :=
              hordered gate g hg input (List.mem_filter.mp hmem').1 hzero
            simp only [hlt, ↓reduceDIte]
            exact ih input.1
              (Nat.lt_of_lt_of_le hlt (Nat.le_of_lt_succ hgate))

/-- One latency-zero unfolding, parameterized by the already computed
frontiers of predecessor gates. -/
def frontierStep (c : Circuit) (previous : Nat → List Nat) (gate : Nat) : List Nat :=
  match c.gates[gate]? with
  | none => [gate]
  | some g =>
      let inputs := g.inputs.filter (fun input => input.2 == 0)
      if inputs.isEmpty then [gate]
      else (inputs.flatMap fun input => previous input.1).eraseDups

theorem orderedFrontier_eq_frontierStep (c : Circuit) (hordered : ZeroOrdered c)
    (gate : Nat) :
    orderedFrontier c gate = frontierStep c (orderedFrontier c) gate := by
  rw [orderedFrontier]
  cases hg : c.gates[gate]? with
  | none => simp [frontierStep, hg]
  | some g =>
      simp only [frontierStep, hg]
      let inputs := g.inputs.filter (fun input => input.2 == 0)
      split
      · rfl
      · apply congrArg List.eraseDups
        change List.flatMap (fun input =>
            if hlt : input.1 < gate then orderedFrontier c input.1 else [input.1]) inputs =
          List.flatMap (fun input => orderedFrontier c input.1) inputs
        apply flatMap_congr_of_mem
        intro input hmem
        have hmem' : input ∈ g.inputs.filter (fun x => x.2 == 0) := hmem
        have hzero : input.2 = 0 := by
          simpa using (List.mem_filter.mp hmem').2
        have hlt : input.1 < gate :=
          hordered gate g hg input (List.mem_filter.mp hmem').1 hzero
        simp only [hlt, ↓reduceDIte]

/-- Local, substitution-parametric refinement.  At gate `gate`, the two
circuits must have the same one-step result whenever all smaller gates have
equal frontiers.  This is the exact compositional obligation for an acyclic
cell expansion; it mentions no particular gadget or cell count. -/
def LocalFrontierRefinement (expanded atomic : Circuit) : Prop :=
  ∀ (gate : Nat) (expandedPrevious atomicPrevious : Nat → List Nat),
    (∀ predecessor < gate,
      expandedPrevious predecessor = atomicPrevious predecessor) →
    frontierStep expanded expandedPrevious gate =
      frontierStep atomic atomicPrevious gate

/-- Local cell-expansion refinement composes through an arbitrarily deep
latency-zero DAG. -/
theorem orderedFrontiers_eq_of_local (expanded atomic : Circuit)
    (hexpanded : ZeroOrdered expanded) (hatomic : ZeroOrdered atomic)
    (hlocal : LocalFrontierRefinement expanded atomic) :
    ∀ gate, orderedFrontier expanded gate = orderedFrontier atomic gate := by
  intro gate
  induction gate using Nat.strongRecOn with
  | ind gate ih =>
      rw [orderedFrontier_eq_frontierStep expanded hexpanded,
        orderedFrontier_eq_frontierStep atomic hatomic]
      exact hlocal gate (orderedFrontier expanded) (orderedFrontier atomic) ih

/-- Whole-circuit theorem for the special case where expanded and atomic gates
are related gate-for-gate (so there are no unmatched internal placeholders). -/
theorem wholeCircuit_frontier_refinement (expanded atomic : Circuit)
    (hexpanded : ZeroOrdered expanded) (hatomic : ZeroOrdered atomic)
    (hlocal : LocalFrontierRefinement expanded atomic)
    (gate : Nat) (hexpandedGate : gate < expanded.gates.size)
    (hatomicGate : gate < atomic.gates.size) :
    glitchGates expanded expanded.gates.size gate =
      glitchGates atomic atomic.gates.size gate := by
  rw [glitchGates_eq_orderedFrontier expanded hexpanded gate
      expanded.gates.size hexpandedGate,
    glitchGates_eq_orderedFrontier atomic hatomic gate
      atomic.gates.size hatomicGate]
  exact orderedFrontiers_eq_of_local expanded atomic hexpanded hatomic hlocal gate

/-- List form matching the parser's list of member/cell-output gates. -/
theorem wholeCircuit_cell_outputs (expanded atomic : Circuit)
    (hexpanded : ZeroOrdered expanded) (hatomic : ZeroOrdered atomic)
    (hlocal : LocalFrontierRefinement expanded atomic)
    (outputs : List Nat)
    (hexpandedOutputs : ∀ gate ∈ outputs, gate < expanded.gates.size)
    (hatomicOutputs : ∀ gate ∈ outputs, gate < atomic.gates.size) :
    ∀ gate ∈ outputs,
      glitchGates expanded expanded.gates.size gate =
        glitchGates atomic atomic.gates.size gate := by
  intro gate hgate
  exact wholeCircuit_frontier_refinement expanded atomic hexpanded hatomic hlocal gate
    (hexpandedOutputs gate hgate) (hatomicOutputs gate hgate)

/-! Parser expansions have unmatched internal primitive gates: the atomic
circuit puts disconnected placeholders at those indices.  Consequently the
correct induction is over the parser's ordered *cell outputs*, not over every
gate.  `OutputLocalRefinement` is the certificate supplied by each cell block:
assuming earlier cell-output frontiers agree, this cell output agrees. -/

def OutputFrontierEq (expanded atomic : Circuit) (gate : Nat) : Prop :=
  orderedFrontier expanded gate = orderedFrontier atomic gate

def OutputLocalRefinement (expanded atomic : Circuit) (outputs : List Nat) : Prop :=
  ∀ (index gate : Nat), outputs[(index : Nat)]? = some gate →
    (∀ (previousIndex previousGate : Nat), previousIndex < index →
      outputs[(previousIndex : Nat)]? = some previousGate →
      OutputFrontierEq expanded atomic previousGate) →
    OutputFrontierEq expanded atomic gate

/-- Induction over an arbitrary-length parser output order.  Internal primitive
indices never enter the induction hypothesis, so they may correspond to atomic
placeholders exactly as in `CircuitRefinement.lean`. -/
theorem ordered_outputFrontiers_eq_of_local (expanded atomic : Circuit)
    (outputs : List Nat) (hlocal : OutputLocalRefinement expanded atomic outputs) :
    ∀ (index gate : Nat), outputs[(index : Nat)]? = some gate →
      OutputFrontierEq expanded atomic gate := by
  intro index
  induction index using Nat.strongRecOn with
  | ind index ih =>
      intro gate hgate
      exact hlocal index gate hgate fun previousIndex previousGate hlt hprevious =>
        ih previousIndex hlt previousGate hprevious

/-- Clearly-scoped parser-generic whole-circuit result: for any number of
topologically ordered cell expansions, once each block supplies the local
substitution certificate, executable `glitchGates` agrees at every listed
cell-output index. -/
theorem wholeCircuit_outputOrder_refinement (expanded atomic : Circuit)
    (outputs : List Nat)
    (hexpanded : ZeroOrdered expanded) (hatomic : ZeroOrdered atomic)
    (hlocal : OutputLocalRefinement expanded atomic outputs)
    (hexpandedOutputs : ∀ (index gate : Nat), outputs[(index : Nat)]? = some gate →
      gate < expanded.gates.size)
    (hatomicOutputs : ∀ (index gate : Nat), outputs[(index : Nat)]? = some gate →
      gate < atomic.gates.size) :
    ∀ (index gate : Nat), outputs[(index : Nat)]? = some gate →
      glitchGates expanded expanded.gates.size gate =
        glitchGates atomic atomic.gates.size gate := by
  intro index gate hgate
  rw [glitchGates_eq_orderedFrontier expanded hexpanded gate expanded.gates.size
      (hexpandedOutputs index gate hgate),
    glitchGates_eq_orderedFrontier atomic hatomic gate atomic.gates.size
      (hatomicOutputs index gate hgate)]
  exact ordered_outputFrontiers_eq_of_local expanded atomic outputs hlocal
    index gate hgate

/-! The local proof obligation is genuinely per-cell and supports arbitrary
upstream cones: the variables below stand for already-computed frontiers, not
merely source pin numbers. -/

open LeanSec.Netlist.CellRefinement

private def unaryFrontier (xs : List Nat) : List Nat := xs.eraseDups
private def binaryFrontier (xs ys : List Nat) : List Nat := (xs ++ ys).eraseDups

private theorem eraseDups_nodup (xs : List Nat) : xs.eraseDups.Nodup := by
  generalize hn : xs.length = n
  induction n using Nat.strongRecOn generalizing xs with
  | ind n ih =>
      cases xs with
      | nil => simp
      | cons x xs =>
          simp only [List.length_cons] at hn
          rw [List.eraseDups_cons]
          apply List.nodup_cons.mpr
          constructor
          · intro hmem
            have hfiltered : x ∈ xs.filter (fun y => !y == x) :=
              List.mem_eraseDups.mp hmem
            simpa using (List.mem_filter.mp hfiltered).2
          · apply ih (xs.filter fun y => !y == x).length
              (hn ▸ Nat.lt_of_le_of_lt (List.length_filter_le _ _)
                (Nat.lt_succ_self xs.length))
            rfl

private theorem eraseDups_eq_self_of_nodup (xs : List Nat) (h : xs.Nodup) :
    xs.eraseDups = xs := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
      have hn := List.nodup_cons.mp h
      rw [List.eraseDups_cons]
      have hfilter : xs.filter (fun y => !y == x) = xs := by
        apply List.filter_eq_self.mpr
        intro y hy
        have hne : y ≠ x := by
          intro heq
          exact hn.1 (heq ▸ hy)
        simp [hne]
      rw [hfilter, ih hn.2]

private theorem eraseDups_append_self (xs : List Nat) :
    (xs ++ xs).eraseDups = xs.eraseDups := by
  rw [List.eraseDups_append]
  have hremove : xs.removeAll xs = [] := by
    unfold List.removeAll
    apply List.filter_eq_nil_iff.mpr
    intro x hx
    simp [hx]
  rw [hremove]
  simp

/-- Every well-founded frontier is duplicate-free, so the hypotheses of the
cell substitution lemma below are automatic for actual upstream cones. -/
theorem orderedFrontier_nodup (c : Circuit) (gate : Nat) :
    (orderedFrontier c gate).Nodup := by
  rw [orderedFrontier]
  cases hg : c.gates[gate]? with
  | none => simp
  | some g =>
      simp only [hg]
      split
      · simp
      · exact eraseDups_nodup _

/-- Frontier obtained by the parser's exact primitive tree after substituting
arbitrary upstream frontiers for its input pins. -/
def expandedCellFrontier : CombFunction → List Nat → List Nat → List Nat
  | .inv, a, _ => unaryFrontier a
  | .buf, a, _ => binaryFrontier a a
  | .and2, a, b | .xor2, a, b => binaryFrontier a b
  | .nand2, a, b | .xnor2, a, b => unaryFrontier (binaryFrontier a b)
  | .nor2, a, b => binaryFrontier (unaryFrontier a) (unaryFrontier b)
  | .or2, a, b =>
      unaryFrontier (binaryFrontier (unaryFrontier a) (unaryFrontier b))

/-- Frontier of the corresponding one-node atomic cell topology. -/
def atomicCellFrontier : CombFunction → List Nat → List Nat → List Nat
  | .inv, a, _ | .buf, a, _ => unaryFrontier a
  | _, a, b => binaryFrontier a b

/-- All eight expansion shapes preserve their frontier after substitution of
arbitrary upstream cones.  This is the per-cell fact used by composition, and
is stronger than checking a cell whose pins are leaves. -/
theorem combinational_frontier_substitution (f : CombFunction)
    (a b : List Nat) (ha : a.Nodup) (hb : b.Nodup) :
    expandedCellFrontier f a b = atomicCellFrontier f a b := by
  cases f <;>
    simp [expandedCellFrontier, atomicCellFrontier, unaryFrontier, binaryFrontier,
      eraseDups_append_self, eraseDups_eq_self_of_nodup, eraseDups_nodup, ha, hb]

/-- The substitution theorem covers every alias in the parser's `CELLS` table. -/
theorem supported_combinational_frontier_substitution
    (cell : SupportedCombCell) (a b : List Nat) (ha : a.Nodup) (hb : b.Nodup) :
    expandedCellFrontier cell.function a b =
      atomicCellFrontier cell.function a b :=
  combinational_frontier_substitution cell.function a b ha hb

end LeanSec.Netlist.CircuitRefinementGeneric
