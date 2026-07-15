import LeanSec.Composition.UniformOPINI

namespace LeanSec
namespace Composition
namespace UniformOPINIFalsify

open Gadget

/-! # Falsification anchor for the executable demand-uniform checker

Without a kernel-checked FAIL, `uopini` could be accidentally trivially
true and every order-2 uniform certificate would be vacuous.  The gadget
below is the order-2 fork--join consumer with one branch gate corrupted to
recombine two shares (`gate 3 := x₀ ⊕ x₁`): a single internal probe on
that gate glitch-exposes both shares, but the O-PINI witness budget at one
internal probe is a single share, so both the demand-uniform and the plain
executable O-PINI predicates must — and do — reject it. -/

def leakyForkJoinCircuit : Circuit :=
  { gates := #[
      { kind := .inp 2 0, inputs := [] },
      { kind := .inp 2 1, inputs := [] },
      { kind := .inp 2 2, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (1, 0)] },
      { kind := .xor, inputs := [(1, 0), (1, 0)] },
      { kind := .xor, inputs := [(2, 0), (2, 0)] },
      { kind := .xor, inputs := [(3, 0), (0, 0)] },
      { kind := .xor, inputs := [(4, 0), (1, 0)] },
      { kind := .xor, inputs := [(5, 0), (2, 0)] }
    ] }

def leakyForkJoin : GadgetInstance :=
  { circuit := leakyForkJoinCircuit
    horizon := 2
    d := 3
    inputCount := 1
    inputArrival := fun _ share => .inp 2 share 1
    output := fun share => { gate := 6 + share, cycle := 1 }
    member := fun _ => true
    randomness := [] }

set_option maxRecDepth 100000 in
set_option maxHeartbeats 400000000 in
/-- The corrupted consumer is rejected by the executable demand-uniform
checker at order two. -/
theorem leaky_not_uopini : ¬ uopini leakyForkJoin transitionGlitch 2 := by
  unfold uopini
  intro secure
  have insecure := secure.2
  revert insecure
  decide

set_option maxRecDepth 100000 in
set_option maxHeartbeats 400000000 in
/-- The rejection is a genuine order-2 O-PINI failure, not an artifact of
demand-uniformity: the audited executable O-PINI predicate also rejects. -/
theorem leaky_not_opini : ¬ opini leakyForkJoin transitionGlitch 2 := by
  unfold opini
  intro secure
  have insecure := secure.2
  revert insecure
  decide

end UniformOPINIFalsify
end Composition
end LeanSec
