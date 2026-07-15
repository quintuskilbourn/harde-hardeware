/-
LeanSec.Netlist.XorRefreshAnchors — validation anchors for the MECHANICALLY
PARSED fresh witness subject `xor_refresh` (hardening H2).

`XorRefreshGen.circuit` was produced by `tools/netlist2lean/netlist2lean.py`
from `tools/netlist2lean/netlists/xor_refresh.v`, a FRESH netlist beyond the
three hand-checked witness subjects (dom_and / hpc2 / scan_dff).  The netlist
deliberately exercises the full supported combinational cell alphabet (XOR2,
INV, XNOR2, BUF, OR2, NAND2, AND2, NOR2) plus a DFF with a consumed QN pin.
The layer-4 structural certificate for this circuit is the GENERATED
`ParserWitnessXorRefresh.supportedCellExpansion`, kernel-checked, not
hand-authored.

The anchors below are the anti-vacuity guards: the parsed circuit is well
formed, functionally recombines to `a XOR b` (so the OR/NAND/AND xor
decomposition, the double-NOR buffer, and the QN inversion pair are all wired
correctly — any dropped or mis-wired cell flips the recombined function), and
is first-order glitch-robust probing secure with a uniform refreshed output.
-/
import LeanSec.Netlist.XorRefreshGen

namespace LeanSec.Netlist.XorRefreshGen

open LeanSec LeanSec.Gadget

/-- The parsed circuit is well formed (valid indices, arities, no comb loop). -/
theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- FUNCTIONAL-CORRECTNESS anchor: the parsed circuit recombines to
`a XOR b` for every input and every randomness assignment.  The refresh `r`
enters both output shares and must cancel; the share-1 XOR is computed
through OR/NAND/AND and re-buffered through two NORs and the QN/INV pair, so
any silently dropped or mis-wired cell changes this function. -/
theorem recombines :
    recombinesTo gadget (fun s => xor (s.getD 0 false) (s.getD 1 false)) := by
  decide

theorem secret_experiments_reached :
    ∀ secret ∈ boolVectors gadget.inputCount,
      (envsForSecret gadget secret).length > 0 := by
  set_option maxRecDepth 10000 in decide

theorem input_experiments_reached :
    ∀ x ∈ boolVectors (inputWidth gadget),
      (envsForInput gadget x).length > 0 := by
  set_option maxRecDepth 10000 in decide

set_option maxRecDepth 10000
set_option maxHeartbeats 32000000

/-- POSITIVE anchor — first-order glitch-robust probing security of the
parsed circuit (a share-wise linear layer with output refresh).

`outputUniform` is NOT stated here: that check hardcodes the two-input
product (`productSecret`) as the expected recombined value, so it applies
only to multiplication gadgets and is provably false for this XOR gadget —
`recombines` above is the applicable functional guard. -/
theorem glitch_probing_one : probingSecure gadget glitch 1 := by decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

end LeanSec.Netlist.XorRefreshGen
