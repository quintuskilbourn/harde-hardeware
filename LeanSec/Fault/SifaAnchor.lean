import LeanSec.Fault.SIFA

/-!
The required falsification anchor: ordinary one-fault detection accepts this
duplicated AND, yet an ineffective reset fault selects on its secret input.

The primary AND computes `secret && mask`.  Its duplicate feeds a comparator,
and an independent output mask makes the no-fault data distribution uniform.
A reset of the primary AND is ineffective (and hence leaves the alarm low)
whenever `secret && mask = false`.  Thus every mask survives for secret zero,
whereas only mask zero survives for secret one.
-/

namespace LeanSec.Fault.SifaAnchor

/-- Gates 2 and 3 are redundant ANDs; gate 4 is their alarm comparator; gate 6
is the externally observed, independently masked primary result. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .and, inputs := [(0, 0), (1, 0)] },
      { kind := .and, inputs := [(0, 0), (1, 0)] },
      { kind := .xor, inputs := [(2, 0), (3, 0)] },
      { kind := .rnd 1, inputs := [] },
      { kind := .xor, inputs := [(2, 0), (5, 0)] }
    ] }

/-- The experiment faults the primary redundant computation.  The comparator,
sources, and external observation boundary are trusted. -/
def allowed : FaultPolicy := fun _ _ node =>
  node.cycle == 0 && node.gate == 2

def fixture : SifaInstance :=
  { circuit := circuit
    horizon := 1
    allowed := allowed
    data := { gate := 6, cycle := 0 }
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

/-- The data-dependent ineffective stuck-at-zero fault. -/
def resetFault : FaultSchedule :=
  [{ target := { gate := 2, cycle := 0 }, kind := .reset }]

theorem resetFault_valid : resetFault.Valid circuit 1 1 allowed := by
  decide

/-- The no-fault output is uniformly distributed in each secret fiber. -/
theorem empty_schedule_resistant :
    scheduleSifaResistant fixture [] := by
  decide

/-- Low-alarm selection is biased: four environments survive for secret zero,
but only two survive for secret one. -/
theorem resetFault_survivor_counts :
    (lowAlarmEnvs fixture resetFault false).length = 4 ∧
      (lowAlarmEnvs fixture resetFault true).length = 2 := by
  decide

/-- This anchor fails specifically through the acceptance-rate channel. -/
theorem resetFault_not_survivor_count_resistant :
    ¬ scheduleSurvivorCountResistant fixture resetFault := by
  decide

/-- The surviving data itself remains uniform in both secret fibers.  This
separates the channel above from conditional-data leakage. -/
theorem resetFault_conditional_data_resistant :
    scheduleConditionalDataResistant fixture resetFault := by
  decide

/-- The equal normalized distributions above are uniform: the larger false
fiber contains two copies of each outcome and the true fiber one copy. -/
theorem resetFault_conditioned_data_counts :
    countObs (lowAlarmEnvs fixture resetFault false)
        (faultedDataObservation fixture resetFault) [false] = 2 ∧
      countObs (lowAlarmEnvs fixture resetFault false)
        (faultedDataObservation fixture resetFault) [true] = 2 ∧
      countObs (lowAlarmEnvs fixture resetFault true)
        (faultedDataObservation fixture resetFault) [false] = 1 ∧
      countObs (lowAlarmEnvs fixture resetFault true)
        (faultedDataObservation fixture resetFault) [true] = 1 := by
  decide

theorem resetFault_is_sifa_counterexample :
    ¬ scheduleSifaResistant fixture resetFault := by
  decide

/-- Detection-only PASS: all allowed schedules of order at most one satisfy
the existing low-alarm-implies-correct-data property. -/
theorem passes_detection : FaultDetectingUpTo fixture 1 := by
  decide

/-- Combined-security FAIL: the valid reset schedule biases low-alarm survival
according to the secret, despite the detector's PASS result above. -/
theorem sifa_leaks : ¬ SifaResistant fixture 1 := by
  decide

#print axioms circuit_wf
#print axioms schedule_count_one
#print axioms resetFault_valid
#print axioms empty_schedule_resistant
#print axioms resetFault_survivor_counts
#print axioms resetFault_not_survivor_count_resistant
#print axioms resetFault_conditional_data_resistant
#print axioms resetFault_conditioned_data_counts
#print axioms resetFault_is_sifa_counterexample
#print axioms passes_detection
#print axioms sifa_leaks

end LeanSec.Fault.SifaAnchor
