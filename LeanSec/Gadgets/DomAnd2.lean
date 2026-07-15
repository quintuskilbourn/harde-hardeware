import LeanSec.Checker.Fast

namespace LeanSec.Gadgets.DomAnd2

open Gadget Checker

/- `GadgetInstance` represents one output sharing.  This module instantiates
the second-order (three-share) domain-oriented masked multiplication. -/

/-- Second-order three-share DOM-AND.  For every unordered pair `{i,j}`, the
same fresh mask `rᵢⱼ` protects `aᵢbⱼ` and `aⱼbᵢ`; consequently the masks cancel
when the three output shares are recombined.  Gates 24--32 are the nine
product registers which form the glitch-isolating barrier. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },                    --  0: a0
      { kind := .inp 0 1, inputs := [] },                    --  1: a1
      { kind := .inp 0 2, inputs := [] },                    --  2: a2
      { kind := .inp 1 0, inputs := [] },                    --  3: b0
      { kind := .inp 1 1, inputs := [] },                    --  4: b1
      { kind := .inp 1 2, inputs := [] },                    --  5: b2
      { kind := .rnd 0, inputs := [] },                      --  6: r01
      { kind := .rnd 1, inputs := [] },                      --  7: r02
      { kind := .rnd 2, inputs := [] },                      --  8: r12
      { kind := .and, inputs := [(0, 0), (3, 0)] },          --  9: p00
      { kind := .and, inputs := [(1, 0), (4, 0)] },          -- 10: p11
      { kind := .and, inputs := [(2, 0), (5, 0)] },          -- 11: p22
      { kind := .and, inputs := [(0, 0), (4, 0)] },          -- 12: a0 b1
      { kind := .xor, inputs := [(12, 0), (6, 0)] },         -- 13: p01
      { kind := .and, inputs := [(1, 0), (3, 0)] },          -- 14: a1 b0
      { kind := .xor, inputs := [(14, 0), (6, 0)] },         -- 15: p10
      { kind := .and, inputs := [(0, 0), (5, 0)] },          -- 16: a0 b2
      { kind := .xor, inputs := [(16, 0), (7, 0)] },         -- 17: p02
      { kind := .and, inputs := [(2, 0), (3, 0)] },          -- 18: a2 b0
      { kind := .xor, inputs := [(18, 0), (7, 0)] },         -- 19: p20
      { kind := .and, inputs := [(1, 0), (5, 0)] },          -- 20: a1 b2
      { kind := .xor, inputs := [(20, 0), (8, 0)] },         -- 21: p12
      { kind := .and, inputs := [(2, 0), (4, 0)] },          -- 22: a2 b1
      { kind := .xor, inputs := [(22, 0), (8, 0)] },         -- 23: p21
      { kind := .reg, inputs := [(9, 1)] },                  -- 24: Reg[p00]
      { kind := .reg, inputs := [(10, 1)] },                 -- 25: Reg[p11]
      { kind := .reg, inputs := [(11, 1)] },                 -- 26: Reg[p22]
      { kind := .reg, inputs := [(13, 1)] },                 -- 27: Reg[p01]
      { kind := .reg, inputs := [(15, 1)] },                 -- 28: Reg[p10]
      { kind := .reg, inputs := [(17, 1)] },                 -- 29: Reg[p02]
      { kind := .reg, inputs := [(19, 1)] },                 -- 30: Reg[p20]
      { kind := .reg, inputs := [(21, 1)] },                 -- 31: Reg[p12]
      { kind := .reg, inputs := [(23, 1)] },                 -- 32: Reg[p21]
      { kind := .xor, inputs := [(24, 0), (27, 0)] },        -- 33
      { kind := .xor, inputs := [(33, 0), (29, 0)] },        -- 34: c0
      { kind := .xor, inputs := [(25, 0), (28, 0)] },        -- 35
      { kind := .xor, inputs := [(35, 0), (31, 0)] },        -- 36: c1
      { kind := .xor, inputs := [(26, 0), (30, 0)] },        -- 37
      { kind := .xor, inputs := [(37, 0), (32, 0)] }         -- 38: c2
    ] }

/-- The concrete two-cycle schedule: sources and masked products at cycle zero,
then the product registers and domain-local output XORs at cycle one. -/
def member (n : Node) : Bool :=
  (n.cycle == 0 && decide (n.gate < 24)) ||
  (n.cycle == 1 && decide (24 ≤ n.gate && n.gate < 39))

def gadget : GadgetInstance :=
  { circuit := circuit
    horizon := 2
    d := 3
    inputCount := 2
    inputArrival := fun sharing share => .inp sharing share 0
    output := fun share =>
      if share == 0 then { gate := 34, cycle := 1 }
      else if share == 1 then { gate := 36, cycle := 1 }
      else { gate := 38, cycle := 1 }
    member := member
    randomness := [.rnd 0 0, .rnd 1 0, .rnd 2 0] }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- The schedule contains three distinct outputs and is closed under both
same-cycle combinational predecessors and previous-cycle register loads. -/
theorem gadget_wf : gadget.WF := by
  refine ⟨circuit_wf, ?_⟩
  decide

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

/-- Closed evaluator equation used to keep functional correctness symbolic. -/
theorem output_formula (env : Env) :
    observe gadget (outputNodes gadget) env =
      [((env (.inp 0 0 0) && env (.inp 1 0 0)) !=
          ((env (.inp 0 0 0) && env (.inp 1 1 0)) != env (.rnd 0 0))) !=
          ((env (.inp 0 0 0) && env (.inp 1 2 0)) != env (.rnd 1 0)),
       ((env (.inp 0 1 0) && env (.inp 1 1 0)) !=
          ((env (.inp 0 1 0) && env (.inp 1 0 0)) != env (.rnd 0 0))) !=
          ((env (.inp 0 1 0) && env (.inp 1 2 0)) != env (.rnd 2 0)),
       ((env (.inp 0 2 0) && env (.inp 1 2 0)) !=
          ((env (.inp 0 2 0) && env (.inp 1 0 0)) != env (.rnd 1 0))) !=
          ((env (.inp 0 2 0) && env (.inp 1 1 0)) != env (.rnd 2 0))] := by
  rfl

theorem input_fixed_of_arrival (g : GadgetInstance) (x : List Bool)
    (env : Env) (src : Src) (bit : Bool)
    (henv : env ∈ envsForInput g x)
    (hsrc : src ∈ relevantSrcs g.circuit g.horizon)
    (harrival : arrivalValue? g x src = some bit) : env src = bit := by
  rw [envsForInput, Execution.envsOf_eq_filtered] at henv
  have hall := List.all_eq_true.mp (List.mem_filter.mp henv).2
  apply (beq_iff_eq.mp (hall (src, bit) ?_))
  unfold fixingForInput
  exact List.mem_filterMap.mpr ⟨src, hsrc, by simp [harrival]⟩

theorem input_values (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput gadget x) :
    env (.inp 0 0 0) = inputBit gadget x 0 0 ∧
    env (.inp 0 1 0) = inputBit gadget x 0 1 ∧
    env (.inp 0 2 0) = inputBit gadget x 0 2 ∧
    env (.inp 1 0 0) = inputBit gadget x 1 0 ∧
    env (.inp 1 1 0) = inputBit gadget x 1 1 ∧
    env (.inp 1 2 0) = inputBit gadget x 1 2 := by
  have hsrc00 : (.inp 0 0 0) ∈ relevantSrcs circuit 2 := by decide
  have hsrc01 : (.inp 0 1 0) ∈ relevantSrcs circuit 2 := by decide
  have hsrc02 : (.inp 0 2 0) ∈ relevantSrcs circuit 2 := by decide
  have hsrc10 : (.inp 1 0 0) ∈ relevantSrcs circuit 2 := by decide
  have hsrc11 : (.inp 1 1 0) ∈ relevantSrcs circuit 2 := by decide
  have hsrc12 : (.inp 1 2 0) ∈ relevantSrcs circuit 2 := by decide
  refine ⟨input_fixed_of_arrival gadget x env _ _ henv (by simpa [gadget] using hsrc00)
      (by rfl), ?_⟩
  refine ⟨input_fixed_of_arrival gadget x env _ _ henv (by simpa [gadget] using hsrc01)
      (by rfl), ?_⟩
  refine ⟨input_fixed_of_arrival gadget x env _ _ henv (by simpa [gadget] using hsrc02)
      (by rfl), ?_⟩
  refine ⟨input_fixed_of_arrival gadget x env _ _ henv (by simpa [gadget] using hsrc10)
      (by rfl), ?_⟩
  refine ⟨input_fixed_of_arrival gadget x env _ _ henv (by simpa [gadget] using hsrc11)
      (by rfl), ?_⟩
  exact input_fixed_of_arrival gadget x env _ _ henv
    (by simpa [gadget] using hsrc12)
    (by rfl)

theorem domand_algebra (a0 a1 a2 b0 b1 b2 r01 r02 r12 : Bool) :
    xorList
      [((a0 && b0) != ((a0 && b1) != r01)) != ((a0 && b2) != r02),
       ((a1 && b1) != ((a1 && b0) != r01)) != ((a1 && b2) != r12),
       ((a2 && b2) != ((a2 && b0) != r02)) != ((a2 && b1) != r12)] =
      (xorList [a0, a1, a2] && xorList [b0, b1, b2]) := by
  decide +revert

/-- Mandatory anti-vacuity guard: every input sharing and every assignment of
the three pair masks recombines to the Boolean product of the input secrets. -/
theorem recombines :
    recombinesTo gadget (fun s => s.getD 0 false && s.getD 1 false) := by
  intro x _ env henv
  rw [output_formula]
  rcases input_values x env henv with
    ⟨h00, h01, h02, h10, h11, h12⟩
  rw [h00, h01, h02, h10, h11, h12]
  change xorList
      [((inputBit gadget x 0 0 && inputBit gadget x 1 0) !=
          ((inputBit gadget x 0 0 && inputBit gadget x 1 1) != env (.rnd 0 0))) !=
          ((inputBit gadget x 0 0 && inputBit gadget x 1 2) != env (.rnd 1 0)),
       ((inputBit gadget x 0 1 && inputBit gadget x 1 1) !=
          ((inputBit gadget x 0 1 && inputBit gadget x 1 0) != env (.rnd 0 0))) !=
          ((inputBit gadget x 0 1 && inputBit gadget x 1 2) != env (.rnd 2 0)),
       ((inputBit gadget x 0 2 && inputBit gadget x 1 2) !=
          ((inputBit gadget x 0 2 && inputBit gadget x 1 0) != env (.rnd 1 0))) !=
          ((inputBit gadget x 0 2 && inputBit gadget x 1 1) != env (.rnd 2 0))] =
      (xorList [inputBit gadget x 0 0, inputBit gadget x 0 1,
          inputBit gadget x 0 2] &&
       xorList [inputBit gadget x 1 0, inputBit gadget x 1 1,
          inputBit gadget x 1 2])
  exact domand_algebra
    (inputBit gadget x 0 0) (inputBit gadget x 0 1)
    (inputBit gadget x 0 2) (inputBit gadget x 1 0)
    (inputBit gadget x 1 1) (inputBit gadget x 1 2)
    (env (.rnd 0 0)) (env (.rnd 1 0)) (env (.rnd 2 0))

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

/-- The nine nonlinear multiplication nodes of the full DOM-AND gadget.  The
fragment theorem below restricts only the allowed probe locations; evaluation,
secret conditioning, glitch expansion, and randomness are those of `gadget`. -/
def andCoreNodes : List Node := [
  { gate := 9, cycle := 0 }, { gate := 10, cycle := 0 },
  { gate := 11, cycle := 0 }, { gate := 12, cycle := 0 },
  { gate := 14, cycle := 0 }, { gate := 16, cycle := 0 },
  { gate := 18, cycle := 0 }, { gate := 20, cycle := 0 },
  { gate := 22, cycle := 0 }]

/-- Verified cached check of all 46 probe sets of size at most two drawn from
the nine AND-core nodes.  This is deliberately not named as whole-gadget
`probingSecureSpec`: the full 781-set kernel certificate hits the resource wall
documented in `RESULT_D2.md`. -/
def andCoreChecker : Bool :=
  reachedCheck gadget &&
    (subsetsUpTo 2 andCoreNodes).all
      (cachedProbeCheck gadget glitch (experiments gadget))

set_option maxRecDepth 10000
set_option maxHeartbeats 20000000

theorem and_core_checker_true : andCoreChecker = true := by
  rfl

/-- Honest order-2 fragment: every set of at most two probes placed on the
nonlinear AND core of the complete gadget has a secret-independent glitch
observation distribution. -/
theorem and_core_glitch_probing_two_spec :
    ∀ probes ∈ subsetsUpTo 2 andCoreNodes,
      SimulatableOn (boolVectors gadget.inputCount) (envsForSecret gadget)
        (fun _ => []) (observe gadget (expandedNodes gadget glitch probes)) := by
  have hparts : reachedCheck gadget = true ∧
      (subsetsUpTo 2 andCoreNodes).all
        (cachedProbeCheck gadget glitch (experiments gadget)) = true := by
    simpa only [andCoreChecker, Bool.and_eq_true] using and_core_checker_true
  have hreached := reachedCheck_sound hparts.1
  intro probes hprobes
  apply (simulatable_iff_countInvariant _ _ _ _ hreached).2
  apply (baseInvariant_iff_countInvariant_const _ _ _ hreached).mp
  exact cachedProbeCheck_sound
    ((List.all_eq_true.mp hparts.2) probes hprobes)

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

end LeanSec.Gadgets.DomAnd2
