import LeanSec.Checker.Bitslice

/-! # First-order masked full-adder cell

`GadgetInstance` exposes one shared Boolean output.  A full adder has two
shared Boolean outputs, so this module gives two views of one common circuit:
`sumGadget` and `carryGadget`.  They have identical members, inputs, and fresh
randomness and differ only in which output sharing is selected.  Consequently
either probing certificate covers the complete joint sum/carry implementation,
not merely the selected output cone.

The carry identity used by the circuit is

`carry = (a AND b) XOR (cin AND (a XOR b))`.

The two products cannot both be true, so this XOR is the usual carry OR.  Each
product is a registered two-share DOM multiplication with its own fresh mask.
The sum is the sharewise linear XOR `a XOR b XOR cin`.
-/

namespace LeanSec.Gadgets.FullAdder

open Gadget
open LeanSec.Checker
open LeanSec.Checker.Bitslice

/-- The unmasked sum bit. -/
def sumSpec (s : List Bool) : Bool :=
  (s.getD 0 false != s.getD 1 false) != s.getD 2 false

/-- The unmasked carry bit (three-input majority). -/
def carrySpec (s : List Bool) : Bool :=
  (s.getD 0 false && s.getD 1 false) ||
    (s.getD 2 false && (s.getD 0 false != s.getD 1 false))

/-- A first-order, two-share full-adder implementation.

Gates 12--17 are the first masked product, gates 18--23 the second.  Their
four terms and the two linear sum shares are registered at gates 24--33.
Gates 34--39 recombine terms by *share*, never by secret. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },                    --  0 a0
      { kind := .inp 0 1, inputs := [] },                    --  1 a1
      { kind := .inp 1 0, inputs := [] },                    --  2 b0
      { kind := .inp 1 1, inputs := [] },                    --  3 b1
      { kind := .inp 2 0, inputs := [] },                    --  4 cin0
      { kind := .inp 2 1, inputs := [] },                    --  5 cin1
      { kind := .rnd 0, inputs := [] },                      --  6 fresh zAB
      { kind := .rnd 1, inputs := [] },                      --  7 fresh zCX
      { kind := .xor, inputs := [(0, 0), (2, 0)] },          --  8 x0=a0+b0
      { kind := .xor, inputs := [(1, 0), (3, 0)] },          --  9 x1=a1+b1
      { kind := .xor, inputs := [(8, 0), (4, 0)] },          -- 10 sum0
      { kind := .xor, inputs := [(9, 0), (5, 0)] },          -- 11 sum1
      { kind := .and, inputs := [(0, 0), (2, 0)] },          -- 12 ab00
      { kind := .and, inputs := [(1, 0), (3, 0)] },          -- 13 ab11
      { kind := .and, inputs := [(0, 0), (3, 0)] },          -- 14 ab01 raw
      { kind := .xor, inputs := [(14, 0), (6, 0)] },         -- 15 ab01 masked
      { kind := .and, inputs := [(1, 0), (2, 0)] },          -- 16 ab10 raw
      { kind := .xor, inputs := [(16, 0), (6, 0)] },         -- 17 ab10 masked
      { kind := .and, inputs := [(4, 0), (8, 0)] },          -- 18 cx00
      { kind := .and, inputs := [(5, 0), (9, 0)] },          -- 19 cx11
      { kind := .and, inputs := [(4, 0), (9, 0)] },          -- 20 cx01 raw
      { kind := .xor, inputs := [(20, 0), (7, 0)] },         -- 21 cx01 masked
      { kind := .and, inputs := [(5, 0), (8, 0)] },          -- 22 cx10 raw
      { kind := .xor, inputs := [(22, 0), (7, 0)] },         -- 23 cx10 masked
      { kind := .reg, inputs := [(10, 1)] },                 -- 24 R[sum0]
      { kind := .reg, inputs := [(11, 1)] },                 -- 25 R[sum1]
      { kind := .reg, inputs := [(12, 1)] },                 -- 26 R[ab00]
      { kind := .reg, inputs := [(13, 1)] },                 -- 27 R[ab11]
      { kind := .reg, inputs := [(15, 1)] },                 -- 28 R[ab01]
      { kind := .reg, inputs := [(17, 1)] },                 -- 29 R[ab10]
      { kind := .reg, inputs := [(18, 1)] },                 -- 30 R[cx00]
      { kind := .reg, inputs := [(19, 1)] },                 -- 31 R[cx11]
      { kind := .reg, inputs := [(21, 1)] },                 -- 32 R[cx01]
      { kind := .reg, inputs := [(23, 1)] },                 -- 33 R[cx10]
      { kind := .xor, inputs := [(26, 0), (28, 0)] },        -- 34 ab share 0
      { kind := .xor, inputs := [(27, 0), (29, 0)] },        -- 35 ab share 1
      { kind := .xor, inputs := [(30, 0), (32, 0)] },        -- 36 cx share 0
      { kind := .xor, inputs := [(31, 0), (33, 0)] },        -- 37 cx share 1
      { kind := .xor, inputs := [(34, 0), (36, 0)] },        -- 38 carry0
      { kind := .xor, inputs := [(35, 0), (37, 0)] }         -- 39 carry1
    ] }

/-- Exact active schedule.  Both output views retain this same complete
schedule, including the other logical output. -/
def member (n : Node) : Bool :=
  (n.cycle == 0 && decide (n.gate < 24)) ||
  (n.cycle == 1 && decide (24 <= n.gate && n.gate < 40))

private def common (out : Nat → Node) : GadgetInstance :=
  { circuit := circuit
    horizon := 2
    d := 2
    inputCount := 3
    inputArrival := fun sharing share => .inp sharing share 0
    output := out
    member := member
    randomness := [.rnd 0 0, .rnd 1 0] }

/-- Sum-output view of the common full-adder execution. -/
def sumGadget : GadgetInstance :=
  common fun share =>
    if share == 0 then { gate := 24, cycle := 1 }
    else { gate := 25, cycle := 1 }

/-- Carry-output view of the same common full-adder execution. -/
def carryGadget : GadgetInstance :=
  common fun share =>
    if share == 0 then { gate := 38, cycle := 1 }
    else { gate := 39, cycle := 1 }

/-- Conventional short name for the full cell's sum view.  Its member set
still covers the complete joint sum/carry circuit. -/
abbrev gadget : GadgetInstance := sumGadget

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

theorem sum_gadget_wf : sumGadget.WF := by
  refine ⟨circuit_wf, ?_⟩
  decide

theorem carry_gadget_wf : carryGadget.WF := by
  refine ⟨circuit_wf, ?_⟩
  decide

/-- Functional anti-vacuity guard for the sum output, universally quantified
over all input sharings and both fresh masks. -/
theorem sum_recombines : recombinesTo sumGadget sumSpec := by
  decide

/-- Functional anti-vacuity guard for the carry output, universally quantified
over all input sharings and both fresh masks. -/
theorem carry_recombines : recombinesTo carryGadget carrySpec := by
  decide

/-- Pair-level functional contract for the two views of the one circuit. -/
def recombinesToFullAdder : Prop :=
  recombinesTo sumGadget sumSpec ∧ recombinesTo carryGadget carrySpec

theorem recombines : recombinesToFullAdder :=
  ⟨sum_recombines, carry_recombines⟩

set_option maxRecDepth 1000000
set_option maxHeartbeats 0

/-- Verified fast-checker verdict for first-order glitch probing. -/
theorem sum_bit_checker_true : bitChecker sumGadget glitch 1 = true := by
  decide +kernel

/-- Required first-order glitch probing specification, discharged only via
the verified checker soundness theorem. -/
theorem glitch_probing_one_spec :
    probingSecureSpec sumGadget glitch 1 :=
  bitChecker_sound sumGadget glitch 1 sum_bit_checker_true

/-- The checker and probing specification do not inspect the selected output
view; both views cover the same circuit, schedule, inputs, and randomness. -/
theorem carry_bit_checker_eq :
    bitChecker carryGadget glitch 1 = bitChecker sumGadget glitch 1 := by
  rfl

theorem carry_bit_checker_true : bitChecker carryGadget glitch 1 = true := by
  rw [carry_bit_checker_eq]
  exact sum_bit_checker_true

theorem probing_views_eq :
    probingSecureSpec carryGadget glitch 1 =
      probingSecureSpec sumGadget glitch 1 := by
  rfl

theorem carry_glitch_probing_one_spec :
    probingSecureSpec carryGadget glitch 1 :=
  probing_views_eq.symm ▸ glitch_probing_one_spec

end LeanSec.Gadgets.FullAdder

#print axioms LeanSec.Gadgets.FullAdder.sum_recombines
#print axioms LeanSec.Gadgets.FullAdder.carry_recombines
#print axioms LeanSec.Gadgets.FullAdder.sum_gadget_wf
#print axioms LeanSec.Gadgets.FullAdder.carry_gadget_wf
#print axioms LeanSec.Gadgets.FullAdder.glitch_probing_one_spec
#print axioms LeanSec.Gadgets.FullAdder.carry_glitch_probing_one_spec
