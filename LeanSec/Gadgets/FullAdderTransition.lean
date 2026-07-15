import LeanSec.Gadgets.FullAdder

/-! # Transition-glitch strengthening for the masked full-adder -/

namespace LeanSec.Gadgets.FullAdderTransition

open Gadget FullAdder
open LeanSec.Checker.Bitslice

set_option maxRecDepth 1000000
set_option maxHeartbeats 0

theorem sum_bit_checker_true :
    bitChecker sumGadget transitionGlitch 1 = true := by
  decide +kernel

theorem sum_transition_glitch_probing_one_spec :
    probingSecureSpec sumGadget transitionGlitch 1 :=
  bitChecker_sound sumGadget transitionGlitch 1 sum_bit_checker_true

theorem probing_views_eq :
    probingSecureSpec carryGadget transitionGlitch 1 =
      probingSecureSpec sumGadget transitionGlitch 1 := by
  rfl

theorem carry_transition_glitch_probing_one_spec :
    probingSecureSpec carryGadget transitionGlitch 1 :=
  probing_views_eq.symm ▸ sum_transition_glitch_probing_one_spec

end LeanSec.Gadgets.FullAdderTransition

#print axioms LeanSec.Gadgets.FullAdderTransition.sum_bit_checker_true
#print axioms LeanSec.Gadgets.FullAdderTransition.sum_transition_glitch_probing_one_spec
#print axioms LeanSec.Gadgets.FullAdderTransition.carry_transition_glitch_probing_one_spec
