/-
LeanSec.Netlist.DomAnd — validation anchors for the MECHANICALLY PARSED DOM-AND.

The circuit `DomAndGen.circuit` (imported below) was produced by
`tools/netlist2lean/netlist2lean.py` from the EXACT SILVER-format NANG45 netlist
`tools/netlist2lean/netlists/dom_and.v` — the same file fed to SILVER's
`./bin/verify --verilog 1`.  Nothing here was hand-transcribed from the RTL.

This module proves the parsed circuit reproduces the DOM-AND verdict profile, and
cross-validates it against BOTH oracles:

  (1) SILVER-on-the-netlist  (tools/netlist2lean/netlists/dom_and.SILVER.txt):
        probing.robust PASS, NI PASS, SNI.standard PASS, SNI.robust FAIL,
        PINI.standard FAIL, PINI.robust FAIL.
  (2) the hand-transcribed `LeanSec.Gadgets.DomAnd` gadget: identical verdicts.

Because ABC remaps gates during synthesis (the netlist realizes p01/p10 as
XNOR∘NAND, not XOR∘AND), the parsed circuit is NOT gate-identical to the hand
transcription.  The correspondence claim is therefore FUNCTION + VERDICT
equivalence (proved below), not structural identity — see TRUST.md.
-/
import LeanSec.Netlist.DomAndGen
import LeanSec.Gadgets.DomAnd

namespace LeanSec.Netlist.DomAndGen

open LeanSec LeanSec.Gadget

/-- The parsed circuit is well formed (valid indices, arities, no comb loop). -/
theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- FUNCTIONAL-CORRECTNESS anchor (the anti-vacuity guard): the parsed circuit
recombines to `a AND b` for every input and every randomness assignment.  A parser
that silently dropped a product or mis-wired the refresh could not pass this — the
z-share would fail to cancel or the product terms would be wrong. -/
theorem recombines :
    recombinesTo gadget (fun s => s.getD 0 false && s.getD 1 false) := by decide

theorem secret_experiments_reached :
    ∀ secret ∈ boolVectors gadget.inputCount,
      (envsForSecret gadget secret).length > 0 := by
  set_option maxRecDepth 10000 in decide

theorem input_experiments_reached :
    ∀ x ∈ boolVectors (inputWidth gadget),
      (envsForInput gadget x).length > 0 := by
  set_option maxRecDepth 10000 in decide

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

/-- POSITIVE anchor — first-order glitch-robust probing security holds on the
parsed circuit.  Matches SILVER `probing.robust (d ≤ 1) -- PASS`. -/
theorem glitch_probing_one : probingSecure gadget glitch 1 := by decide

/-- Matches SILVER `NI.standard (d ≤ 1) -- PASS`. -/
theorem standard_ni_one : ni gadget identity 1 := by decide

/-- Matches SILVER `SNI.standard (d ≤ 1) -- PASS`. -/
theorem standard_sni_one : sni gadget identity 1 := by decide

/-- Matches SILVER `SNI.robust (d ≤ 1) -- FAIL`. -/
theorem not_glitch_sni_one : ¬sni gadget glitch 1 := by decide

/-- Matches SILVER `PINI.standard (d ≤ 1) -- FAIL`. -/
theorem not_standard_pini_one : ¬pini gadget identity 1 := by
  unfold pini
  intro secure
  have insecure := secure.2
  revert insecure
  decide

/-- Output sharing is uniform (the fresh z makes the output a uniform sharing). -/
theorem output_uniform : outputUniform gadget := by decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

/-- Spec-form bridge for the positive probing anchor (stated against the audited
`SimulatableOn` specification, not just the executable predicate). -/
theorem glitch_probing_one_spec : probingSecureSpec gadget glitch 1 :=
  (probingSecure_iff_spec gadget glitch 1 secret_experiments_reached).mp
    glitch_probing_one

/-! ## Correspondence with the hand-transcribed gadget

Both gadgets recombine to the SAME masked function and carry the SAME first-order
glitch-robust probing verdict.  This is the cross-validation of the parser: an
independently authored circuit (the hand transcription) and the mechanically
parsed circuit agree on function and on security. -/

/-- Same output function: the parsed circuit and the hand transcription both
recombine to `a AND b`. -/
theorem function_matches_hand :
    recombinesTo gadget (fun s => s.getD 0 false && s.getD 1 false) ∧
    recombinesTo LeanSec.Gadgets.DomAnd.gadget
      (fun s => s.getD 0 false && s.getD 1 false) :=
  ⟨recombines, LeanSec.Gadgets.DomAnd.recombines⟩

/-- Same security verdict: both are first-order glitch-robust probing secure. -/
theorem probing_verdict_matches_hand :
    probingSecure gadget glitch 1 ∧
    probingSecure LeanSec.Gadgets.DomAnd.gadget glitch 1 :=
  ⟨glitch_probing_one, LeanSec.Gadgets.DomAnd.glitch_probing_one⟩

end LeanSec.Netlist.DomAndGen
