import LeanSec.Fault.SIFA

/-!
A second falsification anchor that isolates conditioned-data leakage.  Two
copies of `secret XOR mask` feed an alarm comparator, while the mask itself is
the observable data.  With no fault, that data is uniform in each secret
fiber.  Resetting one XOR copy is ineffective exactly when
`secret XOR mask = false`: one environment survives in each secret fiber, but
the surviving observations are respectively `false` and `true`.
-/

namespace LeanSec.Fault.SifaDataAnchor

/-- Gates 2 and 3 redundantly compute the selection bit; gate 4 compares them.
Gate 1 is both the fresh mask and the external data observation. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (1, 0)] },
      { kind := .xor, inputs := [(0, 0), (1, 0)] },
      { kind := .xor, inputs := [(2, 0), (3, 0)] }
    ] }

/-- Only the primary redundant selection computation is faultable. -/
def allowed : FaultPolicy := fun _ _ node =>
  node.cycle == 0 && node.gate == 2

def fixture : SifaInstance :=
  { circuit := circuit
    horizon := 1
    allowed := allowed
    data := { gate := 1, cycle := 0 }
    alarm := { gate := 4, cycle := 0 }
    secret := .inp 0 0 0 }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Empty plus set/reset/flip at the sole allowed target. -/
theorem schedule_count_one :
    (schedulesUpTo circuit 1 1 allowed).length = 4 := by
  decide

def resetFault : FaultSchedule :=
  [{ target := { gate := 2, cycle := 0 }, kind := .reset }]

theorem resetFault_valid : resetFault.Valid circuit 1 1 allowed := by
  decide

/-- Before fault selection, the observed fresh mask is uniform in both secret
fibers and both SIFA conjuncts hold. -/
theorem empty_schedule_resistant :
    scheduleSifaResistant fixture [] := by
  decide

/-- Exactly one assignment survives in each fiber, so this fixture does not
use an acceptance-rate difference to refute SIFA. -/
theorem resetFault_survivor_counts :
    (lowAlarmEnvs fixture resetFault false).length = 1 ∧
      (lowAlarmEnvs fixture resetFault true).length = 1 := by
  decide

theorem resetFault_survivor_count_resistant :
    scheduleSurvivorCountResistant fixture resetFault := by
  decide

/-- The sole survivor observes `[false]` in the false-secret fiber and
`[true]` in the true-secret fiber. -/
theorem resetFault_conditioned_data_counts :
    countObs (lowAlarmEnvs fixture resetFault false)
        (faultedDataObservation fixture resetFault) [false] = 1 ∧
      countObs (lowAlarmEnvs fixture resetFault false)
        (faultedDataObservation fixture resetFault) [true] = 0 ∧
      countObs (lowAlarmEnvs fixture resetFault true)
        (faultedDataObservation fixture resetFault) [false] = 0 ∧
      countObs (lowAlarmEnvs fixture resetFault true)
        (faultedDataObservation fixture resetFault) [true] = 1 := by
  decide

/-- Genuine conditioned-data leakage, independent of survivor mass. -/
theorem conditional_data_leaks :
    ¬ scheduleConditionalDataResistant fixture resetFault := by
  decide

theorem resetFault_is_sifa_counterexample :
    ¬ scheduleSifaResistant fixture resetFault := by
  decide

/-- Detection-only still passes every allowed schedule of order at most one:
faults never alter the externally observed mask. -/
theorem passes_detection : FaultDetectingUpTo fixture 1 := by
  decide

theorem sifa_leaks : ¬ SifaResistant fixture 1 := by
  decide

#print axioms circuit_wf
#print axioms schedule_count_one
#print axioms resetFault_valid
#print axioms empty_schedule_resistant
#print axioms resetFault_survivor_counts
#print axioms resetFault_survivor_count_resistant
#print axioms resetFault_conditioned_data_counts
#print axioms conditional_data_leaks
#print axioms resetFault_is_sifa_counterexample
#print axioms passes_detection
#print axioms sifa_leaks

end LeanSec.Fault.SifaDataAnchor
