import LeanSec.Gadgets.OPINI2

/-! # Chain-scale functional-correctness (recombine) anchors

Split out of `OPINI2.lean` (2026-07-13, during the F1 member/WF repair) so
these kernel `decide`s do not stack on the base module's elaboration in one
process (the combined module OOM'd a 30 GB host with Lean exit 137).
Measured peaks, fresh process, per decide: `serial_hpc2_recombines` ~14 GB;
`serial_opini2_recombines` ~39 GB — this one exceeds a 30 GB + 8 GB-swap
laptop even alone, so THIS MODULE IS BUILT ON THE 128 GB BOX (the
established chain-scale host, see VERIFICATION.md) and its artifacts are
cached into `.lake/build` for laptop builds (694 s wall for the module).

These anchors remain part of the standing default gate: `test/Anchors.lean`
imports this module and `test/Axioms.lean` prints their axiom closures. -/

namespace LeanSec.Gadgets.OPINI2.Chains

open Gadget

set_option maxRecDepth 30000
set_option maxHeartbeats 50000000

/-- The two-stage feedback holds make the second HPC2 execution consume the
first execution's output sharing. -/
theorem serial_hpc2_recombines :
    recombinesTo serialHPC2 (fun s =>
      (s.getD 0 false && s.getD 1 false) && s.getD 2 false) := by decide

/-- The registered O-PINI2 serial chain computes the same composed product. -/
theorem serial_opini2_recombines :
    recombinesTo serialOPINI2 (fun s =>
      (s.getD 0 false && s.getD 1 false) && s.getD 2 false) := by decide

/-- The parallel harness exposes only execution 2's output sharing, which
recombines to the product of its independent third and fourth inputs. -/
theorem parallel_hpc2_recombines :
    recombinesTo parallelHPC2 (fun s =>
      s.getD 2 false && s.getD 3 false) := by decide

end LeanSec.Gadgets.OPINI2.Chains
