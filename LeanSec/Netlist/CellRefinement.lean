import LeanSec.Expansion

/-!
Kernel-checked refinement lemmas for every standard-cell expansion emitted by
`tools/netlist2lean/netlist2lean.py`.

The small circuits below use gates 0 and 1 as cell input pins.  Consequently
the frontier equalities are independent of what drives those pins in a larger
circuit: they state exactly which local leaves `glitchGates` reaches through
the emitted latency-zero primitive tree.  DFF is separate because its D edge
has latency one and its latency-zero frontier is the register output itself.
-/

namespace LeanSec.Netlist.CellRefinement

open LeanSec LeanSec.Execution LeanSec.Expansion

/-- Values supplied to the two abstract cell input pins at every cycle. -/
def pinEnv (a b : Bool) : Env
  | .inp 0 0 _ => a
  | .inp 0 1 _ => b
  | _ => false

/-- The eight combinational functions in the parser's `CELLS` table. -/
inductive CombFunction where
  | inv | buf | and2 | xor2 | nand2 | xnor2 | nor2 | or2
deriving DecidableEq, Repr

def CombFunction.spec : CombFunction → Bool → Bool → Bool
  | .inv, a, _ => !a
  | .buf, a, _ => a
  | .and2, a, b => a && b
  | .xor2, a, b => a != b
  | .nand2, a, b => !(a && b)
  | .xnor2, a, b => a == b
  | .nor2, a, b => !(a || b)
  | .or2, a, b => a || b

/-- Exact primitive trees emitted by `expand_cell`; inputs occupy gates 0, 1. -/
def CombFunction.circuit : CombFunction → Circuit
  | .inv =>
      { gates := #[
          { kind := .inp 0 0, inputs := [] },
          { kind := .not, inputs := [(0, 0)] }
        ] }
  | .buf =>
      { gates := #[
          { kind := .inp 0 0, inputs := [] },
          { kind := .and, inputs := [(0, 0), (0, 0)] }
        ] }
  | .and2 =>
      { gates := #[
          { kind := .inp 0 0, inputs := [] },
          { kind := .inp 0 1, inputs := [] },
          { kind := .and, inputs := [(0, 0), (1, 0)] }
        ] }
  | .xor2 =>
      { gates := #[
          { kind := .inp 0 0, inputs := [] },
          { kind := .inp 0 1, inputs := [] },
          { kind := .xor, inputs := [(0, 0), (1, 0)] }
        ] }
  | .nand2 =>
      { gates := #[
          { kind := .inp 0 0, inputs := [] },
          { kind := .inp 0 1, inputs := [] },
          { kind := .and, inputs := [(0, 0), (1, 0)] },
          { kind := .not, inputs := [(2, 0)] }
        ] }
  | .xnor2 =>
      { gates := #[
          { kind := .inp 0 0, inputs := [] },
          { kind := .inp 0 1, inputs := [] },
          { kind := .xor, inputs := [(0, 0), (1, 0)] },
          { kind := .not, inputs := [(2, 0)] }
        ] }
  | .nor2 =>
      { gates := #[
          { kind := .inp 0 0, inputs := [] },
          { kind := .inp 0 1, inputs := [] },
          { kind := .not, inputs := [(0, 0)] },
          { kind := .not, inputs := [(1, 0)] },
          { kind := .and, inputs := [(2, 0), (3, 0)] }
        ] }
  | .or2 =>
      { gates := #[
          { kind := .inp 0 0, inputs := [] },
          { kind := .inp 0 1, inputs := [] },
          { kind := .not, inputs := [(0, 0)] },
          { kind := .not, inputs := [(1, 0)] },
          { kind := .and, inputs := [(2, 0), (3, 0)] },
          { kind := .not, inputs := [(4, 0)] }
        ] }

def CombFunction.outputGate : CombFunction → Nat
  | .inv | .buf => 1
  | .and2 | .xor2 => 2
  | .nand2 | .xnor2 => 3
  | .nor2 => 4
  | .or2 => 5

def CombFunction.inputFrontier : CombFunction → List Nat
  | .inv | .buf => [0]
  | _ => [0, 1]

/-- Every small expansion circuit satisfies the library's structural rules. -/
theorem combinational_circuit_wf (f : CombFunction) : f.circuit.WF := by
  cases f <;>
    simp [CombFunction.circuit, Circuit.WF, Circuit.indicesOk,
      Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
      Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

/-- (a) Every emitted combinational primitive tree computes its cell function. -/
theorem combinational_function (f : CombFunction) (a b : Bool) :
    eval f.circuit 1 (pinEnv a b) { gate := f.outputGate, cycle := 0 } =
      f.spec a b := by
  cases f <;> cases a <;> cases b <;> decide

/-- (b) Every emitted combinational tree has exactly its input-pin frontier.
In particular, no NAND/XNOR/NOR/OR internal primitive survives the walk, and
the repeated BUF input is deduplicated. -/
theorem combinational_frontier (f : CombFunction) :
    glitchGates f.circuit f.circuit.gates.size f.outputGate =
      f.inputFrontier := by
  cases f <;> decide

/-! The exact aliases accepted by the parser's `CELLS` dictionary. -/

inductive SupportedCombCell where
  | invX1 | invX2 | not
  | bufX1 | bufX2 | buf
  | and2X1 | and2X2 | and
  | nand2X1 | nand2X2 | nand
  | or2X1 | or2X2 | or
  | nor2X1 | nor2X2 | nor
  | xor2X1 | xor2X2 | xor
  | xnor2X1 | xnor2X2 | xnor
deriving DecidableEq, Repr

def SupportedCombCell.function : SupportedCombCell → CombFunction
  | .invX1 | .invX2 | .not => .inv
  | .bufX1 | .bufX2 | .buf => .buf
  | .and2X1 | .and2X2 | .and => .and2
  | .nand2X1 | .nand2X2 | .nand => .nand2
  | .or2X1 | .or2X2 | .or => .or2
  | .nor2X1 | .nor2X2 | .nor => .nor2
  | .xor2X1 | .xor2X2 | .xor => .xor2
  | .xnor2X1 | .xnor2X2 | .xnor => .xnor2

def SupportedCombCell.verilogName : SupportedCombCell → String
  | .invX1 => "INV_X1" | .invX2 => "INV_X2" | .not => "NOT"
  | .bufX1 => "BUF_X1" | .bufX2 => "BUF_X2" | .buf => "BUF"
  | .and2X1 => "AND2_X1" | .and2X2 => "AND2_X2" | .and => "AND"
  | .nand2X1 => "NAND2_X1" | .nand2X2 => "NAND2_X2" | .nand => "NAND"
  | .or2X1 => "OR2_X1" | .or2X2 => "OR2_X2" | .or => "OR"
  | .nor2X1 => "NOR2_X1" | .nor2X2 => "NOR2_X2" | .nor => "NOR"
  | .xor2X1 => "XOR2_X1" | .xor2X2 => "XOR2_X2" | .xor => "XOR"
  | .xnor2X1 => "XNOR2_X1" | .xnor2X2 => "XNOR2_X2" | .xnor => "XNOR"

/-- Function preservation, quantified over every exact combinational table row. -/
theorem supported_combinational_function (cell : SupportedCombCell)
    (a b : Bool) :
    eval cell.function.circuit 1 (pinEnv a b)
        { gate := cell.function.outputGate, cycle := 0 } =
      cell.function.spec a b :=
  combinational_function cell.function a b

/-- Frontier preservation, quantified over every exact combinational table row. -/
theorem supported_combinational_frontier (cell : SupportedCombCell) :
    glitchGates cell.function.circuit cell.function.circuit.gates.size
        cell.function.outputGate = cell.function.inputFrontier :=
  combinational_frontier cell.function

/-! Sequential cells: DFF_X1, DFF_X2, and DFF all emit the same `.reg` for Q.
DFF_X1/X2 additionally emit `.not(reg)` for QN exactly when QN is consumed. -/

inductive SupportedDFF where
  | dffX1 | dffX2 | dff
deriving DecidableEq, Repr

def SupportedDFF.verilogName : SupportedDFF → String
  | .dffX1 => "DFF_X1" | .dffX2 => "DFF_X2" | .dff => "DFF"

def dffCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] }
    ] }

def dffQnCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .not, inputs := [(1, 0)] }
    ] }

theorem dff_circuit_wf : dffCircuit.WF := by
  simp [dffCircuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

theorem dff_qn_circuit_wf : dffQnCircuit.WF := by
  simp [dffQnCircuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

def SupportedDFF.circuit (_ : SupportedDFF) : Circuit := dffCircuit

/-- DFF Q at cycle one is the D-pin value sampled at cycle zero. -/
theorem dff_q_function (cell : SupportedDFF) (d : Bool) :
    eval cell.circuit 2 (pinEnv d false) { gate := 1, cycle := 1 } = d := by
  cases cell <;> cases d <;> decide

/-- A DFF output is a latency-zero frontier root; the latency-one D edge is not
part of its same-cycle glitch cone. -/
theorem dff_q_frontier (cell : SupportedDFF) :
    glitchGates cell.circuit cell.circuit.gates.size 1 = [1] := by
  cases cell <;> decide

inductive SupportedDFFWithQN where
  | dffX1 | dffX2
deriving DecidableEq, Repr

def SupportedDFFWithQN.verilogName : SupportedDFFWithQN → String
  | .dffX1 => "DFF_X1" | .dffX2 => "DFF_X2"

def SupportedDFFWithQN.circuit (_ : SupportedDFFWithQN) : Circuit :=
  dffQnCircuit

/-- Consumed DFF_X1/X2 QN computes the complement of the stored Q value. -/
theorem dff_qn_function (cell : SupportedDFFWithQN) (d : Bool) :
    eval cell.circuit 2 (pinEnv d false) { gate := 2, cycle := 1 } = !d := by
  cases cell <;> cases d <;> decide

/-- QN's combinational inverter is skipped, leaving exactly the stored-state
register output as its frontier. -/
theorem dff_qn_frontier (cell : SupportedDFFWithQN) :
    glitchGates cell.circuit cell.circuit.gates.size 2 = [1] := by
  cases cell <;> decide

/-! Constant net tokens are emitted lazily as source gates. -/

def constCircuit (b : Bool) : Circuit :=
  { gates := #[{ kind := .const b, inputs := [] }] }

theorem const_circuit_wf (b : Bool) : (constCircuit b).WF := by
  cases b <;>
    simp [constCircuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
      Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
      Circuit.kahnStep, Circuit.hasRemainingPred]

theorem const_function (b : Bool) :
    eval (constCircuit b) 1 (pinEnv false false) { gate := 0, cycle := 0 } = b := by
  cases b <;> decide

theorem const_frontier (b : Bool) :
    glitchGates (constCircuit b) (constCircuit b).gates.size 0 = [0] := by
  cases b <;> decide

/-- The six literal spellings in the parser's `NET_CONST` table. -/
inductive SupportedConstToken where
  | bin0 | hex0 | dec0 | bin1 | hex1 | dec1
deriving DecidableEq, Repr

def SupportedConstToken.verilogToken : SupportedConstToken → String
  | .bin0 => "1'b0" | .hex0 => "1'h0" | .dec0 => "1'd0"
  | .bin1 => "1'b1" | .hex1 => "1'h1" | .dec1 => "1'd1"

def SupportedConstToken.value : SupportedConstToken → Bool
  | .bin0 | .hex0 | .dec0 => false
  | .bin1 | .hex1 | .dec1 => true

theorem supported_const_function (token : SupportedConstToken) :
    eval (constCircuit token.value) 1 (pinEnv false false)
      { gate := 0, cycle := 0 } = token.value :=
  const_function token.value

theorem supported_const_frontier (token : SupportedConstToken) :
    glitchGates (constCircuit token.value) (constCircuit token.value).gates.size 0 =
      [0] :=
  const_frontier token.value

end LeanSec.Netlist.CellRefinement
