import LeanSec.Composition.UniversalT
import LeanSec.Composition.Universal

namespace LeanSec
namespace Composition
namespace UniversalTFinal

open Gadget

/-!
The boundary-substitution equation in `UniversalT` is correct for its
explicit, cycle-indexed execution graph.  This file checks whether that
equation can be transported to the audited `GadgetInstance` semantics for an
arbitrary multi-cycle serial splice.

There is an exact representation obstruction.  A `Circuit` input is one
static `(gate, latency)` edge which is reused at every cycle, while a
`GadgetInstance` exposes only one fixed output `Node` per share.  Replacing a
downstream input edge by that output gate therefore cannot substitute the
same fixed output node at two adjacent cycles.  At the next cycle it reads the
next-cycle instance of the gate instead.  No register or same-environment
restriction is involved in this argument.
-/

/-- The property which a static edge would need in order to substitute one
fixed boundary node at two adjacent cycles. -/
def StaticBoundarySubstitutionAtTwoCycles
    (cycle : Nat) (input : Nat × Nat) (boundary : Node) : Prop :=
  GenericSerial2.edgePredecessorAt cycle input = some boundary ∧
    GenericSerial2.edgePredecessorAt (cycle + 1) input = some boundary

/-- Cycle-parametric obstruction to generalizing the concrete substitution
law to a static `Circuit` edge.  A static edge which denotes `boundary` at one
cycle denotes the successor-cycle instance of its gate one cycle later, not
the same fixed `Node`. -/
theorem no_static_boundary_substitution_at_two_cycles
    (cycle : Nat) (input : Nat × Nat) (boundary : Node) :
    ¬ StaticBoundarySubstitutionAtTwoCycles cycle input boundary := by
  rintro ⟨hatCycle, hatNextCycle⟩
  have hsuccessor := GenericSerial2.edgePredecessorAt_succ_of_eq
    cycle input boundary hatCycle
  rw [hatNextCycle] at hsuccessor
  have hnode : boundary =
      { gate := boundary.gate, cycle := boundary.cycle + 1 } := by
    exact Option.some.inj hsuccessor
  have hcycle := congrArg Node.cycle hnode
  simp at hcycle

/-- The universal theorem requested in this workstream, stated against the
repository's only generic executable serial compiler.  `Compatible` already
contains matching shares, strict share order, and a consumed connected input;
`glue` constructs disjoint source namespaces and the composite circuit. -/
def GeneralMultiCycleSerialClaim : Prop :=
  ∀ (up down : Universal.SerialComposable) (t : Nat)
      (compat : Universal.SerialComposable.Compatible up down t),
    opiniSpec up.gadget transitionGlitch t →
    opiniSpec down.gadget transitionGlitch t →
    probingSecureSpec (Universal.glue up down t compat) transitionGlitch t

/-- Exact two-cycle instance of the representation obstruction.  Both
components are order-one O-PINI, have matching two-share interfaces and
strict order, and the compiled composite is well formed.  Nevertheless the
edge which reads the declared cycle-0 boundary at cycle 0 reads a different
node at cycle 1, and the resulting composite is not probing secure. -/
theorem multi_cycle_boundary_transport_obstruction :
    ∃ (up down : Universal.SerialComposable)
      (compat : Universal.SerialComposable.Compatible up down 1),
      up.gadget.horizon = 2 ∧
      down.gadget.horizon = 2 ∧
      up.gadget.d = down.gadget.d ∧
      1 < up.gadget.d ∧
      opiniSpec up.gadget transitionGlitch 1 ∧
      opiniSpec down.gadget transitionGlitch 1 ∧
      (Universal.glue up down 1 compat).WF ∧
      GenericSerial2.edgePredecessorAt 0 (0, 0) =
        some (Universal.namespaceNode false (up.gadget.output 0)) ∧
      GenericSerial2.edgePredecessorAt 1 (0, 0) ≠
        some (Universal.namespaceNode false (up.gadget.output 0)) ∧
      ¬ probingSecureSpec (Universal.glue up down 1 compat)
        transitionGlitch 1 := by
  refine ⟨Universal.cycleMismatchUp, Universal.cycleMismatchDown,
    Universal.cycleMismatchCompatible, rfl, rfl, rfl, by decide,
    Universal.cycleMismatchUp_opini, Universal.cycleMismatchDown_opini,
    Universal.cycleMismatchComposite_wf, by decide, by decide, ?_⟩
  exact Universal.cycleMismatchComposite_not_probing

/-- Consequently the requested general multi-cycle theorem is false for the
current executable clean-splice interface.  This refutation includes the
strict order premise; it is independent of the full-share-order obstruction
recorded in `UniversalT`. -/
theorem general_multi_cycle_serial_claim_is_false :
    ¬ GeneralMultiCycleSerialClaim := by
  intro hclaim
  have hsecure := hclaim Universal.cycleMismatchUp
    Universal.cycleMismatchDown 1 Universal.cycleMismatchCompatible
    Universal.cycleMismatchUp_opini Universal.cycleMismatchDown_opini
  exact Universal.cycleMismatchComposite_not_probing hsecure

end UniversalTFinal
end Composition
end LeanSec

#print axioms LeanSec.Composition.UniversalTFinal.no_static_boundary_substitution_at_two_cycles
#print axioms LeanSec.Composition.UniversalTFinal.multi_cycle_boundary_transport_obstruction
#print axioms LeanSec.Composition.UniversalTFinal.general_multi_cycle_serial_claim_is_false
