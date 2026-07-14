import LeanSec.Netlist.CircuitRefinementClosed

/-!
# Finite structural checks for parser witnesses

The parser emits concrete circuits and finite output lists.  The capstone's
`ZeroOrdered` and output-bound fields are intentionally stated with unbounded
natural-number quantifiers, which are not directly decidable.  This module
provides finite equivalents over the actual array/list data and proves once
that successful finite checks discharge those capstone fields.
-/

namespace LeanSec.Netlist.ParserWitness

open LeanSec
open LeanSec.Netlist.CellRefinement
open LeanSec.Netlist.CircuitRefinementGeneric

/-! Public computation lemmas for the private frontier helpers used by the E4
certificate shape.  They let generated proofs unfold one circuit layer without
recursively normalizing every predecessor frontier. -/

@[simp] theorem expandedCellFrontier_inv (a b : List Nat) :
    expandedCellFrontier .inv a b = a.eraseDups := rfl

@[simp] theorem expandedCellFrontier_buf (a b : List Nat) :
    expandedCellFrontier .buf a b = (a ++ a).eraseDups := rfl

@[simp] theorem expandedCellFrontier_and2 (a b : List Nat) :
    expandedCellFrontier .and2 a b = (a ++ b).eraseDups := rfl

@[simp] theorem expandedCellFrontier_xor2 (a b : List Nat) :
    expandedCellFrontier .xor2 a b = (a ++ b).eraseDups := rfl

@[simp] theorem expandedCellFrontier_nand2 (a b : List Nat) :
    expandedCellFrontier .nand2 a b = ((a ++ b).eraseDups).eraseDups := rfl

@[simp] theorem expandedCellFrontier_xnor2 (a b : List Nat) :
    expandedCellFrontier .xnor2 a b = ((a ++ b).eraseDups).eraseDups := rfl

@[simp] theorem expandedCellFrontier_nor2 (a b : List Nat) :
    expandedCellFrontier .nor2 a b =
      (a.eraseDups ++ b.eraseDups).eraseDups := rfl

@[simp] theorem expandedCellFrontier_or2 (a b : List Nat) :
    expandedCellFrontier .or2 a b =
      ((a.eraseDups ++ b.eraseDups).eraseDups).eraseDups := rfl

@[simp] theorem atomicCellFrontier_inv (a b : List Nat) :
    atomicCellFrontier .inv a b = a.eraseDups := rfl

@[simp] theorem atomicCellFrontier_buf (a b : List Nat) :
    atomicCellFrontier .buf a b = a.eraseDups := rfl

@[simp] theorem atomicCellFrontier_binary (f : CombFunction) (a b : List Nat)
    (binary : f ≠ .inv ∧ f ≠ .buf) :
    atomicCellFrontier f a b = (a ++ b).eraseDups := by
  cases f with
  | inv | buf => simp at binary
  | and2 | xor2 | nand2 | xnor2 | nor2 | or2 => rfl

/-- Every latency-zero input in one concrete input list precedes `gate`. -/
inductive InputsZeroOrdered (gate : Nat) : List (Nat × Nat) → Prop where
  | nil : InputsZeroOrdered gate []
  | cons {input : Nat × Nat} {inputs : List (Nat × Nat)}
      (head : input.2 = 0 → input.1 < gate)
      (tail : InputsZeroOrdered gate inputs) :
      InputsZeroOrdered gate (input :: inputs)

instance inputsZeroOrderedDecidable (gate : Nat) (inputs : List (Nat × Nat)) :
    Decidable (InputsZeroOrdered gate inputs) :=
  match inputs with
  | [] => isTrue .nil
  | input :: inputs =>
      match inputsZeroOrderedDecidable gate inputs with
      | isFalse tailFalse => isFalse fun
          | .cons _ tail => tailFalse tail
      | isTrue tailTrue =>
          if zero : input.2 = 0 then
            if earlier : input.1 < gate then
              isTrue (.cons (fun _ => earlier) tailTrue)
            else
              isFalse fun
                | .cons head _ => earlier (head zero)
          else
            isTrue (.cons (fun isZero => False.elim (zero isZero)) tailTrue)

private theorem inputsZeroOrdered_of_mem {gate : Nat} {inputs : List (Nat × Nat)}
    (checked : InputsZeroOrdered gate inputs) (input : Nat × Nat)
    (member : input ∈ inputs) (zero : input.2 = 0) : input.1 < gate := by
  induction inputs with
  | nil => simp at member
  | cons head tail ih =>
      cases checked with
      | cons headChecked tailChecked =>
          simp only [List.mem_cons] at member
          rcases member with rfl | member
          · exact headChecked zero
          · exact ih tailChecked member

/-- Decidable array-bounded form of `ZeroOrdered`. -/
def FiniteZeroOrdered (c : Circuit) : Prop :=
  ∀ gate : Fin c.gates.size,
    InputsZeroOrdered gate c.gates[gate].inputs

instance finiteZeroOrderedDecidable (c : Circuit) :
    Decidable (FiniteZeroOrdered c) := by
  unfold FiniteZeroOrdered
  infer_instance

/-- A successful finite array check supplies the capstone's unbounded form. -/
theorem zeroOrdered_of_finite {c : Circuit} (checked : FiniteZeroOrdered c) :
    ZeroOrdered c := by
  intro gate g hgate input hinput hzero
  rcases Array.getElem?_eq_some_iff.mp hgate with ⟨hbound, hvalue⟩
  have gateChecked := checked ⟨gate, hbound⟩
  have gateChecked' : InputsZeroOrdered gate (c.gates[gate]'hbound).inputs := by
    simpa using gateChecked
  have hvalue' : c.gates[gate]'hbound = g := by
    simpa using hvalue
  rw [hvalue'] at gateChecked'
  exact inputsZeroOrdered_of_mem gateChecked' input hinput hzero

/-- Every gate named by a concrete output list is in the circuit array. -/
inductive GatesInBounds (c : Circuit) : List Nat → Prop where
  | nil : GatesInBounds c []
  | cons {gate : Nat} {gates : List Nat}
      (head : gate < c.gates.size) (tail : GatesInBounds c gates) :
      GatesInBounds c (gate :: gates)

instance gatesInBoundsDecidable (c : Circuit) (outputs : List Nat) :
    Decidable (GatesInBounds c outputs) :=
  match outputs with
  | [] => isTrue .nil
  | gate :: gates =>
      match gatesInBoundsDecidable c gates with
      | isFalse tailFalse => isFalse fun
          | .cons _ tail => tailFalse tail
      | isTrue tailTrue =>
          if bound : gate < c.gates.size then
            isTrue (.cons bound tailTrue)
          else
            isFalse fun
              | .cons head _ => bound head

private theorem gateInBounds_of_mem {c : Circuit} {outputs : List Nat}
    (checked : GatesInBounds c outputs) (gate : Nat) (member : gate ∈ outputs) :
    gate < c.gates.size := by
  induction outputs with
  | nil => simp at member
  | cons head tail ih =>
      cases checked with
      | cons headChecked tailChecked =>
          simp only [List.mem_cons] at member
          rcases member with rfl | member
          · exact headChecked
          · exact ih tailChecked member

private theorem list_mem_of_getElem?_eq_some {outputs : List Nat}
    {index gate : Nat} (hgate : outputs[index]? = some gate) : gate ∈ outputs := by
  rcases List.getElem?_eq_some_iff.mp hgate with ⟨hbound, hvalue⟩
  have member := @List.getElem_mem Nat outputs index hbound
  rwa [hvalue] at member

/-- A successful finite list check supplies either output-bound field. -/
theorem outputBound_of_finite {c : Circuit} {outputs : List Nat}
    (checked : GatesInBounds c outputs) :
    ∀ (index gate : Nat), outputs[index]? = some gate → gate < c.gates.size := by
  intro index gate hgate
  exact gateInBounds_of_mem checked gate (list_mem_of_getElem?_eq_some hgate)

end LeanSec.Netlist.ParserWitness
