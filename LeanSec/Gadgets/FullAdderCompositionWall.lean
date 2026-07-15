import LeanSec.Gadgets.FullAdderTransition
import LeanSec.Composition.Pipeline

/-! # Exact composition-premise audit for the full-adder

`Composition.compose_pini` requires the upstream component to satisfy O-PINI.
This module checks that premise directly for the carry-output view used by a
ripple chain. -/

namespace LeanSec.Gadgets.FullAdderCompositionWall

open Gadget FullAdder

theorem input_experiments_reached :
    ∀ x ∈ boolVectors (inputWidth carryGadget),
      (envsForInput carryGadget x).length > 0 := by
  set_option maxRecDepth 10000 in
    decide

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

/-- Kernel-checked obstruction: the carry-producing full-adder is probing
secure, but it does not satisfy the O-PINI premise needed in the upstream
role of `compose_pini`. -/
theorem not_transition_opini_one :
    ¬ opini carryGadget transitionGlitch 1 := by
  unfold opini
  intro secure
  have insecure := secure.2
  revert insecure
  decide

theorem not_transition_opini_one_spec :
    ¬ opiniSpec carryGadget transitionGlitch 1 := by
  intro secure
  exact not_transition_opini_one
    ((opini_iff_spec carryGadget transitionGlitch 1
      input_experiments_reached).mpr secure)

end LeanSec.Gadgets.FullAdderCompositionWall

#print axioms LeanSec.Gadgets.FullAdderCompositionWall.not_transition_opini_one
#print axioms LeanSec.Gadgets.FullAdderCompositionWall.not_transition_opini_one_spec
