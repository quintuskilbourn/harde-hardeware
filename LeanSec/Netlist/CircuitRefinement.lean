import LeanSec.Netlist.CellRefinement
import LeanSec.Netlist.DomAndGen
import LeanSec.Netlist.HPC2Gen

/-!
Whole-circuit frontier refinement for the two mechanically emitted netlists.

`AtomicFrontierCircuit` below means only an atomic *cone topology*: one gate is
kept at every standard-cell output, with its inputs wired to the outputs of the
cells (or sources) driving its pins.  Parser-only primitive expansion gates are
replaced by disconnected placeholders so that emitted and atomic gate numbers
stay aligned.  The primitive `GateKind` chosen at an atomic NAND/XNOR output is
irrelevant here: `glitchGates` depends only on the latency-labelled input graph.

Thus equality of `glitchGates` at every cell output is a whole-netlist claim,
not merely a repetition of the local cell lemmas: both walks recursively cross
all upstream latency-zero cells and stop at exactly the same register/source
frontier.  The final theorems lift this equality through both `glitch` and
`transitionGlitch` probing expansions.
-/

namespace LeanSec.Netlist.CircuitRefinement

open LeanSec LeanSec.Expansion

/-- Frontier preservation at every gate designated as a netlist cell output. -/
def RefinesCellOutputs (expanded atomic : Circuit) (outputs : List Nat) : Prop :=
  ∀ gate ∈ outputs,
    glitchGates expanded expanded.gates.size gate =
      glitchGates atomic atomic.gates.size gate

theorem glitch_eq_of_frontier_eq (expanded atomic : Circuit) (gate : Nat)
    (hfrontier :
      glitchGates expanded expanded.gates.size gate =
        glitchGates atomic atomic.gates.size gate)
    (horizon cycle : Nat) :
    glitch expanded horizon { gate := gate, cycle := cycle } =
      glitch atomic horizon { gate := gate, cycle := cycle } := by
  simp [glitch, hfrontier]

/-- A same-gate frontier equality also preserves transition-then-glitch cones:
transition expansion changes only the cycle, never the gate being expanded. -/
theorem transitionGlitch_eq_of_frontier_eq (expanded atomic : Circuit)
    (gate : Nat)
    (hfrontier :
      glitchGates expanded expanded.gates.size gate =
        glitchGates atomic atomic.gates.size gate)
    (horizon cycle : Nat) :
    transitionGlitch expanded horizon { gate := gate, cycle := cycle } =
      transitionGlitch atomic horizon { gate := gate, cycle := cycle } := by
  by_cases inside : 0 < cycle ∧ cycle < horizon
  · simp [transitionGlitch, Expansion.compose, transition, inside,
      glitch_eq_of_frontier_eq expanded atomic gate hfrontier]
  · simp [transitionGlitch, Expansion.compose, transition, inside,
      glitch_eq_of_frontier_eq expanded atomic gate hfrontier]

/-- Whole-list lifting of frontier refinement to ordinary glitch expansion. -/
theorem glitch_refines_cell_outputs {expanded atomic : Circuit}
    {outputs : List Nat} (hrefines : RefinesCellOutputs expanded atomic outputs) :
    ∀ gate ∈ outputs, ∀ horizon cycle,
      glitch expanded horizon { gate := gate, cycle := cycle } =
        glitch atomic horizon { gate := gate, cycle := cycle } := by
  intro gate hgate horizon cycle
  exact glitch_eq_of_frontier_eq expanded atomic gate
    (hrefines gate hgate) horizon cycle

/-- Whole-list lifting of frontier refinement to transition-glitch expansion. -/
theorem transitionGlitch_refines_cell_outputs {expanded atomic : Circuit}
    {outputs : List Nat} (hrefines : RefinesCellOutputs expanded atomic outputs) :
    ∀ gate ∈ outputs, ∀ horizon cycle,
      transitionGlitch expanded horizon { gate := gate, cycle := cycle } =
        transitionGlitch atomic horizon { gate := gate, cycle := cycle } := by
  intro gate hgate horizon cycle
  exact transitionGlitch_eq_of_frontier_eq expanded atomic gate
    (hrefines gate hgate) horizon cycle

/-! ## DOM-AND -/

/-- Cell outputs in `DomAndGen.circuit`, including the four DFF Q outputs.
Gates 10, 12, 14, and 16 are parser-introduced NAND/XNOR internal nodes. -/
def domAndCellOutputs : List Nat :=
  [5, 6, 7, 8, 9, 11, 13, 15, 17, 18, 19, 20]

/-- The DOM-AND netlist with every standard cell represented by one cone node.
Disconnected constants occupy the four parser-only gate numbers. -/
def domAndAtomicFrontierCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .inp 1 1, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .reg, inputs := [(19, 1)] },
      { kind := .reg, inputs := [(18, 1)] },
      { kind := .reg, inputs := [(17, 1)] },
      { kind := .reg, inputs := [(13, 1)] },
      { kind := .xor, inputs := [(5, 0), (7, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .and, inputs := [(1, 0), (2, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(4, 0), (11, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .and, inputs := [(0, 0), (3, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(4, 0), (15, 0)] },
      { kind := .and, inputs := [(1, 0), (3, 0)] },
      { kind := .and, inputs := [(2, 0), (0, 0)] },
      { kind := .xor, inputs := [(6, 0), (8, 0)] }
    ] }

theorem domAnd_atomic_frontier_circuit_wf : domAndAtomicFrontierCircuit.WF := by
  simp [domAndAtomicFrontierCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Every DOM-AND cell-output cone in the emitted primitive circuit has exactly
the frontier of the corresponding atomic standard-cell topology. -/
theorem domAnd_cell_output_frontiers :
    RefinesCellOutputs LeanSec.Netlist.DomAndGen.circuit
      domAndAtomicFrontierCircuit domAndCellOutputs := by
  intro gate hgate
  simp [domAndCellOutputs] at hgate
  rcases hgate with rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl <;> decide

theorem domAnd_glitch_cell_outputs :
    ∀ gate ∈ domAndCellOutputs, ∀ horizon cycle,
      glitch LeanSec.Netlist.DomAndGen.circuit horizon
          { gate := gate, cycle := cycle } =
        glitch domAndAtomicFrontierCircuit horizon
          { gate := gate, cycle := cycle } :=
  glitch_refines_cell_outputs domAnd_cell_output_frontiers

theorem domAnd_transitionGlitch_cell_outputs :
    ∀ gate ∈ domAndCellOutputs, ∀ horizon cycle,
      transitionGlitch LeanSec.Netlist.DomAndGen.circuit horizon
          { gate := gate, cycle := cycle } =
        transitionGlitch domAndAtomicFrontierCircuit horizon
          { gate := gate, cycle := cycle } :=
  transitionGlitch_refines_cell_outputs domAnd_cell_output_frontiers

/-! ## HPC2 -/

/-- Cell outputs in `HPC2Gen.circuit`, including all eleven DFF Q outputs.
Gates 18, 20, 27, and 29 are parser-introduced XNOR internal nodes. -/
def hpc2CellOutputs : List Nat :=
  [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
   16, 17, 19, 21, 22, 23, 24, 25, 26, 28, 30, 31, 32, 33]

/-- The HPC2 netlist's cell-level latency-labelled cone topology. -/
def hpc2AtomicFrontierCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .inp 1 1, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .reg, inputs := [(2, 1)] },
      { kind := .reg, inputs := [(32, 1)] },
      { kind := .reg, inputs := [(31, 1)] },
      { kind := .reg, inputs := [(26, 1)] },
      { kind := .reg, inputs := [(25, 1)] },
      { kind := .reg, inputs := [(24, 1)] },
      { kind := .reg, inputs := [(3, 1)] },
      { kind := .reg, inputs := [(23, 1)] },
      { kind := .reg, inputs := [(22, 1)] },
      { kind := .reg, inputs := [(33, 1)] },
      { kind := .reg, inputs := [(4, 1)] },
      { kind := .not, inputs := [(1, 0)] },
      { kind := .not, inputs := [(0, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(14, 0), (7, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(12, 0), (19, 0)] },
      { kind := .xor, inputs := [(2, 0), (4, 0)] },
      { kind := .and, inputs := [(1, 0), (11, 0)] },
      { kind := .and, inputs := [(0, 0), (9, 0)] },
      { kind := .xor, inputs := [(4, 0), (3, 0)] },
      { kind := .and, inputs := [(17, 0), (15, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(8, 0), (10, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(6, 0), (28, 0)] },
      { kind := .and, inputs := [(1, 0), (13, 0)] },
      { kind := .and, inputs := [(0, 0), (5, 0)] },
      { kind := .and, inputs := [(16, 0), (15, 0)] }
    ] }

theorem hpc2_atomic_frontier_circuit_wf : hpc2AtomicFrontierCircuit.WF := by
  simp [hpc2AtomicFrontierCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Every HPC2 cell-output cone in the emitted primitive circuit has exactly
the frontier of the corresponding atomic standard-cell topology. -/
theorem hpc2_cell_output_frontiers :
    RefinesCellOutputs LeanSec.Netlist.HPC2Gen.circuit
      hpc2AtomicFrontierCircuit hpc2CellOutputs := by
  intro gate hgate
  simp [hpc2CellOutputs] at hgate
  rcases hgate with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> decide

theorem hpc2_glitch_cell_outputs :
    ∀ gate ∈ hpc2CellOutputs, ∀ horizon cycle,
      glitch LeanSec.Netlist.HPC2Gen.circuit horizon
          { gate := gate, cycle := cycle } =
        glitch hpc2AtomicFrontierCircuit horizon
          { gate := gate, cycle := cycle } :=
  glitch_refines_cell_outputs hpc2_cell_output_frontiers

theorem hpc2_transitionGlitch_cell_outputs :
    ∀ gate ∈ hpc2CellOutputs, ∀ horizon cycle,
      transitionGlitch LeanSec.Netlist.HPC2Gen.circuit horizon
          { gate := gate, cycle := cycle } =
        transitionGlitch hpc2AtomicFrontierCircuit horizon
          { gate := gate, cycle := cycle } :=
  transitionGlitch_refines_cell_outputs hpc2_cell_output_frontiers

end LeanSec.Netlist.CircuitRefinement
