import LeanSec.Netlist.ParserWitness
import LeanSec.Netlist.ScanCellRefinement

/-!
# Parser witnesses with scan-mux outputs

This is the scan-aware extension of `CircuitRefinementClosed`.  A scan mux is
kept as a distinct ternary output step, so it cannot be certified through the
ordinary-DFF root case or a binary combinational-cell case.  Its three drivers
must be earlier parser outputs, and its local normal form is exactly
`scanMuxFrontier SE D SI`.
-/

namespace LeanSec.Netlist.ScanParserWitness

open LeanSec LeanSec.Expansion
open LeanSec.Netlist.CellRefinement
open LeanSec.Netlist.CircuitRefinementGeneric
open LeanSec.Netlist.CircuitRefinementClosed
open LeanSec.Netlist.ScanCellRefinement

/-- One root, ordinary combinational output, or scan-mux output emitted by the
production translator. -/
inductive SupportedScanOutputStep (expanded atomic : Circuit)
    (outputs : List Nat) (index gate : Nat) : Prop where
  | root (frontierRoot : Nat)
      (expandedShape : orderedFrontier expanded gate = [frontierRoot])
      (atomicShape : orderedFrontier atomic gate = [frontierRoot]) :
      SupportedScanOutputStep expanded atomic outputs index gate
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
      SupportedScanOutputStep expanded atomic outputs index gate
  | scanMux (cell : SupportedScanCell)
      (seIndex seGate dIndex dGate siIndex siGate : Nat)
      (seEarlier : seIndex < index) (dEarlier : dIndex < index)
      (siEarlier : siIndex < index)
      (seOutput : outputs[seIndex]? = some seGate)
      (dOutput : outputs[dIndex]? = some dGate)
      (siOutput : outputs[siIndex]? = some siGate)
      (expandedShape :
        orderedFrontier expanded gate =
          scanMuxFrontier (orderedFrontier expanded seGate)
            (orderedFrontier expanded dGate)
            (orderedFrontier expanded siGate))
      (atomicShape :
        orderedFrontier atomic gate =
          scanMuxFrontier (orderedFrontier atomic seGate)
            (orderedFrontier atomic dGate)
            (orderedFrontier atomic siGate)) :
      SupportedScanOutputStep expanded atomic outputs index gate

/-- Finite structural certificate emitted for a circuit that may contain scan
DFF expansions. -/
structure SupportedScanCellExpansion (expanded atomic : Circuit) where
  outputs : List Nat
  expandedZeroOrdered : ZeroOrdered expanded
  atomicZeroOrdered : ZeroOrdered atomic
  expandedOutputBound : ∀ (index gate : Nat), outputs[index]? = some gate →
    gate < expanded.gates.size
  atomicOutputBound : ∀ (index gate : Nat), outputs[index]? = some gate →
    gate < atomic.gates.size
  step : ∀ (index gate : Nat), outputs[index]? = some gate →
    SupportedScanOutputStep expanded atomic outputs index gate

/-- The emitted scan certificate supplies the local induction premise.  The
scan case uses all three earlier-frontier equalities, including SI. -/
theorem supportedScanCellExpansion_outputLocalRefinement
    {expanded atomic : Circuit}
    (construction : SupportedScanCellExpansion expanded atomic) :
    OutputLocalRefinement expanded atomic construction.outputs := by
  intro index gate hgate previous
  cases construction.step index gate hgate with
  | root frontierRoot expandedShape atomicShape =>
      exact expandedShape.trans atomicShape.symm
  | combinational cell aIndex aGate bIndex bGate aEarlier bEarlier
      aOutput bOutput expandedShape atomicShape =>
      have ha := previous aIndex aGate aEarlier aOutput
      have hb := previous bIndex bGate bEarlier bOutput
      change orderedFrontier expanded gate = orderedFrontier atomic gate
      rw [expandedShape, atomicShape, ha, hb]
      exact supported_combinational_frontier_substitution cell
        (orderedFrontier atomic aGate) (orderedFrontier atomic bGate)
        (orderedFrontier_nodup atomic aGate)
        (orderedFrontier_nodup atomic bGate)
  | scanMux cell seIndex seGate dIndex dGate siIndex siGate
      seEarlier dEarlier siEarlier seOutput dOutput siOutput
      expandedShape atomicShape =>
      have hse := previous seIndex seGate seEarlier seOutput
      have hd := previous dIndex dGate dEarlier dOutput
      have hsi := previous siIndex siGate siEarlier siOutput
      change orderedFrontier expanded gate = orderedFrontier atomic gate
      rw [expandedShape, atomicShape, hse, hd, hsi]

/-- Scan-aware ParserWitness capstone: executable `glitchGates` agrees at every
emitted root/cell output, including each member-visible scan mux. -/
theorem parser_scan_wholeCircuit_frontier_refinement
    {expanded atomic : Circuit}
    (construction : SupportedScanCellExpansion expanded atomic) :
    ∀ (index gate : Nat), construction.outputs[index]? = some gate →
      glitchGates expanded expanded.gates.size gate =
        glitchGates atomic atomic.gates.size gate := by
  exact wholeCircuit_outputOrder_refinement expanded atomic construction.outputs
    construction.expandedZeroOrdered construction.atomicZeroOrdered
    (supportedScanCellExpansion_outputLocalRefinement construction)
    construction.expandedOutputBound construction.atomicOutputBound

end LeanSec.Netlist.ScanParserWitness
