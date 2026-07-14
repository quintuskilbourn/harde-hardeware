/-
LeanSec.Netlist.HPC2 — validation anchors for the mechanically parsed HPC2.

`HPC2Gen.circuit` was generated from
`tools/netlist2lean/netlists/hpc2.v` (SHA-256
5d5df856b095dbdab7a2528d7962a2f2863a6060413676fd4a058e938182845d),
the exact SILVER-format NANG45 netlist recorded in
`tools/netlist2lean/netlists/hpc2.SILVER.txt`.

Generation command:

  python3 tools/netlist2lean/netlist2lean.py \
    tools/netlist2lean/netlists/hpc2.v --module hpc2_top \
    --namespace LeanSec.Netlist.HPC2Gen --input-arrival 0=1 \
    --conservative-members --out LeanSec/Netlist/HPC2Gen.lean

Sharing 0 (`AxDI`) arrives at cycle 1; sharing 1 (`BxDI`) and refresh `RxDI`
arrive at cycle 0; outputs are at cycle 2. Conservative membership makes the
four XOR nodes introduced by XNOR expansion probeable, so this gadget checks a
strict superset of SILVER's standard-cell output locations and satisfies the
PINI boundary guard.
-/
import LeanSec.Netlist.HPC2Gen
import LeanSec.Gadgets.HPC2

namespace LeanSec.Netlist.HPC2Gen

open LeanSec LeanSec.Gadget

/-- The generated primitive circuit has valid indices and arities and no
combinational loop. -/
theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Conservative membership is closed under the combinational and register
predecessors required by the PINI experiment boundary. -/
theorem gadget_wf : gadget.WF := by
  refine ⟨circuit_wf, ?_⟩
  decide

/-- Functional anti-vacuity anchor: for every modeled input and randomness
assignment, the two parsed output shares XOR to the unmasked product. -/
theorem recombines :
    recombinesTo gadget (fun s => s.getD 0 false && s.getD 1 false) := by decide

theorem input_experiments_reached :
    ∀ x ∈ boolVectors (inputWidth gadget),
      (envsForInput gadget x).length > 0 := by
  set_option maxRecDepth 10000 in
    decide

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

/-- First-order glitch-robust PINI for the parsed netlist. This matches both
SILVER `PINI.robust (d ≤ 1) -- PASS` on the exact source netlist and the
independent hand-transcribed HPC2 theorem. -/
theorem glitch_pini_one : pini gadget glitch 1 := by
  refine ⟨gadget_wf, ?_⟩
  decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

/-- The positive result stated against the audited simulator specification. -/
theorem glitch_pini_one_spec : piniSpec gadget glitch 1 :=
  (pini_iff_spec gadget glitch 1 input_experiments_reached).mp glitch_pini_one

/-- Both independently authored circuits recombine to the same function. -/
theorem function_matches_hand :
    recombinesTo gadget (fun s => s.getD 0 false && s.getD 1 false) ∧
    recombinesTo LeanSec.Gadgets.HPC2.gadget
      (fun s => s.getD 0 false && s.getD 1 false) :=
  ⟨recombines, LeanSec.Gadgets.HPC2.recombines⟩

/-- Both independently authored circuits have the same positive first-order
glitch-PINI verdict. -/
theorem pini_verdict_matches_hand :
    pini gadget glitch 1 ∧ pini LeanSec.Gadgets.HPC2.gadget glitch 1 :=
  ⟨glitch_pini_one, LeanSec.Gadgets.HPC2.glitch_pini_one⟩

end LeanSec.Netlist.HPC2Gen
