import LeanSec.Netlist.CircuitRefinementGeneric

/-!
# Closed whole-circuit refinement for supported-cell expansions

`CircuitRefinementGeneric` isolates `OutputLocalRefinement` as the remaining
whole-circuit hypothesis.  This module discharges that hypothesis for an
explicit, kernel-checkable representation of a supported-cell expansion.

The representation is deliberately a frontier-normal-form certificate.  Its
ordered output list contains roots before the combinational outputs that use
them.  A root has the same singleton frontier in both circuits.  A supported
combinational output records its two earlier drivers and states that the two
circuits unfold to the exact expanded and atomic cell frontier forms.  The
per-cell substitution theorem then proves the output equality automatically.

This does not assert that arbitrary parser output has such a certificate.  The
parser is Python code and currently emits only circuit arrays, not a Lean
witness relating its allocated roots, cell outputs, and internal primitive
indices to this representation.
-/

namespace LeanSec.Netlist.CircuitRefinementClosed

open LeanSec LeanSec.Expansion
open LeanSec.Netlist.CellRefinement
open LeanSec.Netlist.CircuitRefinementGeneric

/-- One entry in a supported-cell expansion, stated in the normal form needed
for frontier composition.

Roots cover primary inputs, constants, and latency-zero frontier roots such as
register outputs.  The root index need not equal the listed output gate (this
also permits an emitted inverter output whose frontier is a register gate).
Combinational entries are exactly aliases represented by
`SupportedCombCell`; both drivers must occur earlier in `outputs`. -/
inductive SupportedOutputStep (expanded atomic : Circuit) (outputs : List Nat)
    (index gate : Nat) : Prop where
  | root (frontierRoot : Nat)
      (expandedShape : orderedFrontier expanded gate = [frontierRoot])
      (atomicShape : orderedFrontier atomic gate = [frontierRoot]) :
      SupportedOutputStep expanded atomic outputs index gate
  | combinational (cell : SupportedCombCell)
      (aIndex aGate bIndex bGate : Nat)
      (aEarlier : aIndex < index) (bEarlier : bIndex < index)
      (aOutput : outputs[aIndex]? = some aGate)
      (bOutput : outputs[bIndex]? = some bGate)
      (expandedShape :
        orderedFrontier expanded gate =
          expandedCellFrontier cell.function
            (orderedFrontier expanded aGate)
            (orderedFrontier expanded bGate))
      (atomicShape :
        orderedFrontier atomic gate =
          atomicCellFrontier cell.function
            (orderedFrontier atomic aGate)
            (orderedFrontier atomic bGate)) :
      SupportedOutputStep expanded atomic outputs index gate

/-- A cleanly representable supported-cell expansion.

Besides the ordered cell/root description, this bundles exactly the structural
array facts needed to connect the well-founded frontier semantics to executable
`glitchGates`.  It contains no local or whole-circuit refinement equality. -/
structure SupportedCellExpansion (expanded atomic : Circuit) where
  outputs : List Nat
  expandedZeroOrdered : ZeroOrdered expanded
  atomicZeroOrdered : ZeroOrdered atomic
  expandedOutputBound : ∀ (index gate : Nat), outputs[index]? = some gate →
    gate < expanded.gates.size
  atomicOutputBound : ∀ (index gate : Nat), outputs[index]? = some gate →
    gate < atomic.gates.size
  step : ∀ (index gate : Nat), outputs[index]? = some gate →
    SupportedOutputStep expanded atomic outputs index gate

/-- The supported-cell structure itself supplies the local induction
certificate required by `wholeCircuit_outputOrder_refinement`. -/
theorem supportedCellExpansion_outputLocalRefinement
    {expanded atomic : Circuit}
    (construction : SupportedCellExpansion expanded atomic) :
    OutputLocalRefinement expanded atomic construction.outputs := by
  intro index gate hgate previous
  cases construction.step index gate hgate with
  | root frontierRoot expandedShape atomicShape =>
      exact expandedShape.trans atomicShape.symm
  | combinational cell aIndex aGate bIndex bGate aEarlier bEarlier
      aOutput bOutput expandedShape atomicShape =>
      have ha : OutputFrontierEq expanded atomic aGate :=
        previous aIndex aGate aEarlier aOutput
      have hb : OutputFrontierEq expanded atomic bGate :=
        previous bIndex bGate bEarlier bOutput
      change orderedFrontier expanded gate = orderedFrontier atomic gate
      rw [expandedShape, atomicShape]
      rw [ha, hb]
      exact supported_combinational_frontier_substitution cell
        (orderedFrontier atomic aGate) (orderedFrontier atomic bGate)
        (orderedFrontier_nodup atomic aGate)
        (orderedFrontier_nodup atomic bGate)

/-- Capstone: executable whole-circuit frontier refinement with no
`OutputLocalRefinement` hypothesis.  The sole premise is the bundled structural
fact that the pair of circuits is an ordered supported-cell expansion. -/
theorem parser_generic_wholeCircuit_frontier_refinement
    {expanded atomic : Circuit}
    (construction : SupportedCellExpansion expanded atomic) :
    ∀ (index gate : Nat), construction.outputs[index]? = some gate →
      glitchGates expanded expanded.gates.size gate =
        glitchGates atomic atomic.gates.size gate := by
  exact wholeCircuit_outputOrder_refinement expanded atomic construction.outputs
    construction.expandedZeroOrdered construction.atomicZeroOrdered
    (supportedCellExpansion_outputLocalRefinement construction)
    construction.expandedOutputBound construction.atomicOutputBound

end LeanSec.Netlist.CircuitRefinementClosed
