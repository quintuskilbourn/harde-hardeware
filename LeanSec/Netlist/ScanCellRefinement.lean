import LeanSec.Netlist.CircuitRefinementGeneric

/-!
# Scan-aware sequential-cell refinement

An ordinary DFF is a latency-one `reg`.  A scan DFF is not: its sampled data
is selected by a combinational mux, `reg (mux SE D SI)`.  The mux output is a
physical combinational route and therefore must remain observable alongside
the register output.  In particular, glitch expansion at that mux reaches the
scan-input cone even when `SE` is false for the functional execution.

This module is additive: it does not weaken or modify the audited ordinary-DFF
lemmas.  A translator supporting the aliases below must emit `scanDffCircuit`'s
shape and must include `scanMuxGate` as a member node.
-/

namespace LeanSec.Netlist.ScanCellRefinement

open LeanSec LeanSec.Execution LeanSec.Expansion
open LeanSec.Netlist.CellRefinement

/-! ## Exact scan-cell model -/

/-- Values supplied to the abstract D, SE, and SI pins at every cycle. -/
def scanPinEnv (d se si : Bool) : Env
  | .inp 0 0 _ => d
  | .ctl 0 _ => se
  | .inp 0 1 _ => si
  | _ => false

/-- Stable indices used by the local refinement and falsification theorems. -/
def dGate : Nat := 0
def scanEnableGate : Nat := 1
def scanInputGate : Nat := 2
def scanMuxGate : Nat := 3
def scanQGate : Nat := 4

/-- Exact scan-DFF expansion: `Q := reg (mux SE D SI)`.

The mux inputs use the library order `[select, false-input, true-input]`.
Thus `SE = false` samples D and `SE = true` samples SI. -/
def scanDffCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .ctl 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .mux, inputs := [(scanEnableGate, 0), (dGate, 0),
          (scanInputGate, 0)] },
      { kind := .reg, inputs := [(scanMuxGate, 1)] }
    ] }

/-- Supported scan aliases.  All have the pin contract D/SE/SI/clock/Q and
share the same expansion; a complementary QN can be emitted as `.not Q` using
the already-audited ordinary-DFF QN pattern. -/
inductive SupportedScanCell where
  | sdffX1 | sdffX2 | sdff
deriving DecidableEq, Repr

def SupportedScanCell.verilogName : SupportedScanCell → String
  | .sdffX1 => "SDFF_X1"
  | .sdffX2 => "SDFF_X2"
  | .sdff => "SDFF"

/-- Fail-closed lookup for exactly the scan aliases modeled in this module. -/
def supportedScanCellOfVerilogName : String → Option SupportedScanCell
  | "SDFF_X1" => some .sdffX1
  | "SDFF_X2" => some .sdffX2
  | "SDFF" => some .sdff
  | _ => none

theorem supported_scan_name_roundtrip (cell : SupportedScanCell) :
    supportedScanCellOfVerilogName cell.verilogName = some cell := by
  cases cell <;> decide

/-- Ordinary DFF aliases cannot be silently reclassified as scan aliases. -/
theorem supported_scan_lookup_rejects_dff (cell : SupportedDFF) :
    supportedScanCellOfVerilogName cell.verilogName = none := by
  cases cell <;> decide

/-- Fail-closed ordinary-DFF lookup, stated here to make the direction that
matters for translator soundness explicit.  A scan alias must not enter this
lookup, because that path emits only `reg D` and would discard SE/SI. -/
def supportedDffOfVerilogName : String → Option SupportedDFF
  | "DFF_X1" => some .dffX1
  | "DFF_X2" => some .dffX2
  | "DFF" => some .dff
  | _ => none

/-- Forward separation: every accepted scan alias is rejected by the
ordinary-DFF lookup/expansion path. -/
theorem supported_dff_lookup_rejects_scan (cell : SupportedScanCell) :
    supportedDffOfVerilogName cell.verilogName = none := by
  cases cell <;> decide

def SupportedScanCell.circuit (_ : SupportedScanCell) : Circuit :=
  scanDffCircuit

/-- Additive supported-cell universe: existing combinational aliases and DFFs
remain available, while scan DFFs have a distinct, non-idealized case. -/
inductive SupportedCell where
  | combinational (cell : SupportedCombCell)
  | dff (cell : SupportedDFF)
  | scanDff (cell : SupportedScanCell)
deriving DecidableEq, Repr

def SupportedCell.verilogName : SupportedCell → String
  | .combinational cell => cell.verilogName
  | .dff cell => cell.verilogName
  | .scanDff cell => cell.verilogName

/-- The scan expansion obeys the closed-library arity, index, and acyclicity
rules, including latency zero on the mux and latency one into the register. -/
theorem scan_dff_circuit_wf : scanDffCircuit.WF := by
  simp [scanDffCircuit, scanEnableGate, dGate, scanInputGate, scanMuxGate,
    Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- The combinational part computes `mux SE D SI`. -/
theorem scan_combinational_function (d se si : Bool) :
    eval scanDffCircuit 1 (scanPinEnv d se si)
        { gate := scanMuxGate, cycle := 0 } =
      (if se then si else d) := by
  cases d <;> cases se <;> cases si <;> decide

/-- The complete scan cell samples the mux result one cycle later. -/
theorem scan_q_function (cell : SupportedScanCell) (d se si : Bool) :
    eval cell.circuit 2 (scanPinEnv d se si)
        { gate := scanQGate, cycle := 1 } =
      (if se then si else d) := by
  cases cell <;> cases d <;> cases se <;> cases si <;> decide

/-! ## Frontier preservation, including arbitrary upstream SI cones -/

/-- Frontier normal form for a mux after substituting arbitrary upstream
frontiers for SE, D, and SI.  The order matches the mux's input order. -/
def scanMuxFrontier (se d si : List Nat) : List Nat :=
  (se ++ d ++ si).eraseDups

/-- Every node of an arbitrary upstream SI cone survives in the scan-mux
frontier (possibly deduplicated against the SE or D cones). -/
theorem scanMuxFrontier_includes_si (se d si : List Nat) :
    List.Subset si (scanMuxFrontier se d si) := by
  intro gate hgate
  simp [scanMuxFrontier, hgate]

/-- The scan expansion's mux and the atomic scan-mux topology have identical
frontiers after arbitrary upstream substitution.  In particular, `si` is not
conditioned away by the public value of SE: glitch frontiers are structural. -/
theorem scan_combinational_frontier_step (previous : Nat → List Nat) :
    LeanSec.Netlist.CircuitRefinementGeneric.frontierStep
        scanDffCircuit previous scanMuxGate =
      scanMuxFrontier (previous scanEnableGate) (previous dGate)
        (previous scanInputGate) := by
  simp [LeanSec.Netlist.CircuitRefinementGeneric.frontierStep,
    scanDffCircuit, scanMuxFrontier, scanMuxGate, scanEnableGate, dGate,
    scanInputGate]

/-- Substitution-parametric scan-mux refinement in the form used by the
whole-circuit machinery: equality of the three upstream frontiers suffices for
equality at the expanded scan mux. -/
theorem scan_combinational_frontier_substitution
    (expandedPrevious atomicPrevious : Nat → List Nat)
    (hse : expandedPrevious scanEnableGate = atomicPrevious scanEnableGate)
    (hd : expandedPrevious dGate = atomicPrevious dGate)
    (hsi : expandedPrevious scanInputGate = atomicPrevious scanInputGate) :
    LeanSec.Netlist.CircuitRefinementGeneric.frontierStep
        scanDffCircuit expandedPrevious scanMuxGate =
      scanMuxFrontier (atomicPrevious scanEnableGate) (atomicPrevious dGate)
        (atomicPrevious scanInputGate) := by
  rw [scan_combinational_frontier_step, hse, hd, hsi]

/-- The exact isolated-cell mux frontier includes all three pin cones, with SI
at the named gate `scanInputGate`. -/
theorem scan_combinational_frontier :
    glitchGates scanDffCircuit scanDffCircuit.gates.size scanMuxGate =
      [scanEnableGate, dGate, scanInputGate] := by
  decide

/-- Register Q is still a same-cycle frontier root.  This is why the mux output
must itself be retained as an observable member node. -/
theorem scan_q_frontier (cell : SupportedScanCell) :
    glitchGates cell.circuit cell.circuit.gates.size scanQGate = [scanQGate] := by
  cases cell <;> decide

/-- A sound scan-cell member policy exposes both the combinational sampled-data
route and the stored Q route. -/
def SupportedScanCell.observableGates (_ : SupportedScanCell) : List Nat :=
  [scanMuxGate, scanQGate]

/-- Every supported alias exposes the mux whose glitch frontier contains SI. -/
theorem supported_scan_frontier_includes_si (cell : SupportedScanCell) :
    scanInputGate ∈
      glitchGates cell.circuit cell.circuit.gates.size scanMuxGate := by
  cases cell <;> decide

/-- The required mux node is present in the scan-aware member policy. -/
theorem supported_scan_mux_observable (cell : SupportedScanCell) :
    scanMuxGate ∈ cell.observableGates := by
  simp [SupportedScanCell.observableGates]

/-- Union of the same-cycle glitch frontiers exposed by a cell member policy. -/
def observableFrontier (c : Circuit) (members : List Nat) : List Nat :=
  (members.flatMap fun gate => glitchGates c c.gates.size gate).eraseDups

/-- Scan-aware observable frontier. -/
def scanAwareObservableFrontier : List Nat :=
  observableFrontier scanDffCircuit
    ((SupportedScanCell.sdff : SupportedScanCell).observableGates)

/-- Expand all observable members under an arbitrary leakage expansion. -/
def observableExpansion (scheme : ExpansionScheme) (c : Circuit)
    (horizon cycle : Nat) (members : List Nat) : List Node :=
  (members.flatMap fun gate => scheme c horizon { gate := gate, cycle := cycle }).eraseDups

/-! ## Falsification anchor: the ideal-DFF abstraction is strictly smaller -/

/-- The old idealization on aligned D/SE/SI pins: Q samples only D. -/
def idealDffCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .ctl 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      -- Index-alignment placeholder: an ideal DFF has no scan mux at gate 3.
      { kind := .const false, inputs := [] },
      { kind := .reg, inputs := [(dGate, 1)] }
    ] }

/-- The ideal model exposes only Q; there is no combinational sampled-data
member corresponding to the missing scan mux. -/
def idealDffObservableGates : List Nat := [scanQGate]

def idealDffObservableFrontier : List Nat :=
  observableFrontier idealDffCircuit idealDffObservableGates

/-- Transition-plus-glitch observations at cycle one in the ideal model. -/
def idealDffTransitionGlitchObservations : List Node :=
  observableExpansion transitionGlitch idealDffCircuit 2 1
    idealDffObservableGates

/-- Transition-plus-glitch observations at cycle one in the scan-aware model. -/
def scanAwareTransitionGlitchObservations : List Node :=
  observableExpansion transitionGlitch scanDffCircuit 2 1
    ((SupportedScanCell.sdff : SupportedScanCell).observableGates)

/-- Frontier of the value route sampled by the idealized register. -/
def idealDffDataFrontier : List Nat :=
  glitchGates idealDffCircuit idealDffCircuit.gates.size dGate

/-- Frontier of the value route sampled by the scan-aware register. -/
def scanAwareDataFrontier : List Nat :=
  glitchGates scanDffCircuit scanDffCircuit.gates.size scanMuxGate

/-- Concrete falsification: the ideal-DFF sampled-data frontier is a strict
subset of the scan-aware frontier. -/
theorem idealDff_frontier_ssubset_scanAware :
    List.Subset idealDffDataFrontier scanAwareDataFrontier ∧
      ¬ List.Subset scanAwareDataFrontier idealDffDataFrontier := by
  change List.Subset [0] [1, 0, 2] ∧ ¬ List.Subset [1, 0, 2] [0]
  constructor
  · intro gate hgate
    simp at hgate
    subst gate
    simp
  · intro subset
    have missed := subset (show 2 ∈ [1, 0, 2] by simp)
    simpa using missed

/-- Security-relevant form of the falsification anchor: after applying each
model's required member policy, the complete ideal-DFF observable glitch
frontier is a strict subset of the scan-aware observable frontier. -/
theorem idealDff_observable_frontier_ssubset_scanAware :
    List.Subset idealDffObservableFrontier scanAwareObservableFrontier ∧
      ¬ List.Subset scanAwareObservableFrontier idealDffObservableFrontier := by
  change List.Subset [4] [1, 0, 2, 4] ∧ ¬ List.Subset [1, 0, 2, 4] [4]
  constructor
  · intro gate hgate
    simp at hgate
    subst gate
    simp
  · intro subset
    have missed := subset (show 2 ∈ [1, 0, 2, 4] by simp)
    simpa using missed

/-- Named missed node: SI is gate 2.  It is in the scan-aware frontier and is
absent from the ideal-DFF frontier. -/
theorem scanInput_missed_by_idealDff :
    scanInputGate ∈ scanAwareObservableFrontier ∧
      scanInputGate ∉ idealDffObservableFrontier := by
  decide

/-- The same missed SI route survives the full `transitionGlitch` expansion:
SI at cycle one is observable in the scan-aware model and absent in the ideal
model. -/
theorem scanInput_transitionGlitch_missed_by_idealDff :
    ({ gate := scanInputGate, cycle := 1 } : Node) ∈
        scanAwareTransitionGlitchObservations ∧
      ({ gate := scanInputGate, cycle := 1 } : Node) ∉
        idealDffTransitionGlitchObservations := by
  decide

/-- The idealization is functionally wrong in scan mode as well: with
`D=false`, `SE=true`, and `SI=true`, ideal Q is false but scan-aware Q is true. -/
theorem idealDff_disagrees_in_scan_mode :
    eval idealDffCircuit 2 (scanPinEnv false true true)
        { gate := scanQGate, cycle := 1 } = false ∧
      eval scanDffCircuit 2 (scanPinEnv false true true)
        { gate := scanQGate, cycle := 1 } = true := by
  decide

end LeanSec.Netlist.ScanCellRefinement
