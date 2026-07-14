import LeanSec.Gadgets.OPINI2

/-! # ⚠️ STALE — do not cite; re-decide required (F1 repair, 2026-07-13)

Every theorem in this file was decided against the PRE-repair member
whitelists.  The F1 repair changed the boundaries these statements quantify
over: `serialHPC2Member` +14 nodes, `parallelHPC2` +12, `serialOPINI2`
+18/−2 (mux input wires, `Reg[s]`@cycle-2 — the codex-found hole — the
`rnd 1` wire at its live cycles, and removal of two junk nodes inherited
through the gate-index collision with serial-HPC2).  Consequences:

1. The `decide` proofs below no longer elaborate as-is; each needs a fresh
   run on a big-memory host (the pre-repair serial-O-PINI2 decide peaked at
   124 GB / 3 h — the enlarged boundary will cost more; per-theorem split
   mandatory, see VERIFICATION.md).
2. `serial_hpc2_chain_not_probing` was ALREADY known false on the faithful
   circuit (VERIFICATION.md 2026-07-13: both serial chains secure) — flip it
   to the positive statement when re-deciding.
3. Positive results must be re-stated through `probingSecureWF` (Gadget.lean)
   with the now-proven boundary guards `serial_opini2_wf` /
   `parallel_hpc2_wf` (OPINI2.lean) as the WF component, e.g.
   `probingSecureWF serialOPINI2 transitionGlitch 1` from
   ⟨`serial_opini2_wf`, re-decided probing⟩ — so a whole-chain PASS can no
   longer rest on an unchecked member whitelist.
4. Residual (documented in `GadgetInstance.WF`): WF still does not force the
   same-gate previous-cycle transition companion of every member into the
   boundary; dropped companions are sound only if environment-independent.
   The fully closed alternative is `member := fun _ => true` over the window
   at additional decide cost. -/

namespace LeanSec.Gadgets.OPINI2.Chains

open Gadget

set_option maxRecDepth 30000
set_option maxHeartbeats 50000000

theorem serial_hpc2_reached :
    ∀ secret ∈ boolVectors serialHPC2.inputCount,
      (envsForSecret serialHPC2 secret).length > 0 := by
  intro secret hs
  let x := secret.flatMap fun bit => [bit, false]
  simp [serialHPC2, boolVectors] at hs
  rcases hs with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals
    apply List.length_pos_iff.mpr
    apply envsForSecret_ne_nil_of_input serialHPC2 _ x
    · decide
    · decide
    · apply envsForInput_ne_nil_of_valid
      decide

theorem serial_opini2_reached :
    ∀ secret ∈ boolVectors serialOPINI2.inputCount,
      (envsForSecret serialOPINI2 secret).length > 0 := by
  intro secret hs
  let x := secret.flatMap fun bit => [bit, false]
  simp [serialOPINI2, boolVectors] at hs
  rcases hs with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals
    apply List.length_pos_iff.mpr
    apply envsForSecret_ne_nil_of_input serialOPINI2 _ x
    · decide
    · decide
    · apply envsForInput_ne_nil_of_valid
      decide

theorem parallel_hpc2_reached :
    ∀ secret ∈ boolVectors parallelHPC2.inputCount,
      (envsForSecret parallelHPC2 secret).length > 0 := by
  intro secret hs
  let x := secret.flatMap fun bit => [bit, false]
  simp [parallelHPC2, boolVectors] at hs
  rcases hs with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals
    apply List.length_pos_iff.mpr
    apply envsForSecret_ne_nil_of_input parallelHPC2 _ x
    · decide
    · decide
    · apply envsForInput_ne_nil_of_valid
      decide

theorem serial_hpc2_chain_not_probing :
    ¬probingSecureFast serialHPC2 transitionGlitch 1 := by decide

theorem serial_opini2_chain_probing :
    probingSecureFast serialOPINI2 transitionGlitch 1 := by decide

theorem parallel_hpc2_chain_probing :
    probingSecureFast parallelHPC2 transitionGlitch 1 := by decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

theorem serial_hpc2_chain_not_probing_spec :
    ¬probingSecureSpec serialHPC2 transitionGlitch 1 := by
  intro h
  exact serial_hpc2_chain_not_probing
    ((probingSecureFast_iff _ _ _ serial_hpc2_reached).mpr
      ((probingSecure_iff_spec _ _ _ serial_hpc2_reached).mpr h))

theorem serial_opini2_chain_probing_spec :
    probingSecureSpec serialOPINI2 transitionGlitch 1 := by
  exact (probingSecure_iff_spec _ _ _ serial_opini2_reached).mp
    ((probingSecureFast_iff _ _ _ serial_opini2_reached).mp
      serial_opini2_chain_probing)

theorem parallel_hpc2_chain_probing_spec :
    probingSecureSpec parallelHPC2 transitionGlitch 1 := by
  exact (probingSecure_iff_spec _ _ _ parallel_hpc2_reached).mp
    ((probingSecureFast_iff _ _ _ parallel_hpc2_reached).mp
      parallel_hpc2_chain_probing)

namespace StaleR

theorem reached :
    ∀ secret ∈ boolVectors gadget.inputCount,
      (envsForSecret gadget secret).length > 0 := by
  intro secret hs
  let x := secret.flatMap fun bit => [bit, false]
  simp [gadget, boolVectors] at hs
  rcases hs with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals
    apply List.length_pos_iff.mpr
    apply envsForSecret_ne_nil_of_input gadget _ x
    · decide
    · decide
    · apply envsForInput_ne_nil_of_valid
      decide

set_option maxRecDepth 30000
set_option maxHeartbeats 50000000

theorem not_probing :
    ¬probingSecureFast gadget transitionGlitch 1 := by decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

theorem not_probing_spec :
    ¬probingSecureSpec gadget transitionGlitch 1 := by
  intro h
  exact not_probing
    ((probingSecureFast_iff _ _ _ reached).mpr
      ((probingSecure_iff_spec _ _ _ reached).mpr h))

end StaleR

end LeanSec.Gadgets.OPINI2.Chains
