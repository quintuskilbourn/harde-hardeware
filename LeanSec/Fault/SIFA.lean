import LeanSec.Fault.FirstOrder
import LeanSec.Gadget

/-!
An executable, finite first-order SIFA property layered on the existing fault
semantics.  The audited definitions in `LeanSec.Security` are reused unchanged:
`Execution.envsOf` supplies the finite experiments, while `distEq`/`countObs`
state equality of the conditional data distributions.

SIFA also exposes the probability that an execution survives with its alarm
low.  Consequently `scheduleSifaResistant` requires both equal survivor counts
and equal normalized data distributions.  The first conjunct is essential:
`distEq` deliberately cross-multiplies, and is therefore vacuous when one of
its environment lists is empty.
-/

namespace LeanSec.Fault

/-- A detection boundary together with the source whose two Boolean fibers
must remain indistinguishable after low-alarm selection. -/
structure SifaInstance extends DetectionInstance where
  secret : Src

instance : Coe SifaInstance DetectionInstance where
  coe fixture := fixture.toDetectionInstance

/-- Environments in one secret fiber for which the faulted alarm stays low. -/
def lowAlarmEnvs (fixture : SifaInstance) (schedule : FaultSchedule)
    (secretValue : Bool) : List Env :=
  (Execution.envsOf fixture.circuit fixture.horizon
      [(fixture.secret, secretValue)]).filter fun env =>
    !evalFaulted fixture.circuit fixture.horizon schedule env fixture.alarm

/-- The data visible on a surviving faulted execution. -/
def faultedDataObservation (fixture : SifaInstance)
    (schedule : FaultSchedule) (env : Env) : Observation :=
  [evalFaulted fixture.circuit fixture.horizon schedule env fixture.data]

/-- Low-alarm survival has the same mass in both secret fibers.  This rules out
the acceptance-rate channel caused by secret-dependent fault ineffectivity. -/
def scheduleSurvivorCountResistant (fixture : SifaInstance)
    (schedule : FaultSchedule) : Prop :=
  (lowAlarmEnvs fixture schedule false).length =
    (lowAlarmEnvs fixture schedule true).length

instance (fixture : SifaInstance) (schedule : FaultSchedule) :
    Decidable (scheduleSurvivorCountResistant fixture schedule) := by
  unfold scheduleSurvivorCountResistant
  infer_instance

/-- The observable-data distributions in the two secret fibers are equal after
conditioning on the faulted alarm staying low. -/
def scheduleConditionalDataResistant (fixture : SifaInstance)
    (schedule : FaultSchedule) : Prop :=
  distEq (lowAlarmEnvs fixture schedule false)
    (lowAlarmEnvs fixture schedule true)
    (faultedDataObservation fixture schedule)

instance (fixture : SifaInstance) (schedule : FaultSchedule) :
    Decidable (scheduleConditionalDataResistant fixture schedule) := by
  unfold scheduleConditionalDataResistant
  infer_instance

/-- One valid schedule is SIFA-resistant when it closes both low-alarm
channels: survival mass and the conditioned observable-data distribution. -/
def scheduleSifaResistant (fixture : SifaInstance)
    (schedule : FaultSchedule) : Prop :=
  scheduleSurvivorCountResistant fixture schedule ∧
    scheduleConditionalDataResistant fixture schedule

instance (fixture : SifaInstance) (schedule : FaultSchedule) :
    Decidable (scheduleSifaResistant fixture schedule) := by
  unfold scheduleSifaResistant
  infer_instance

/-- Data-independent detection against every allowed schedule of cardinality
at most `k`.  `schedulesUpTo` already filters schedules through
`FaultSchedule.Valid`. -/
def SifaResistant (fixture : SifaInstance) (k : Nat) : Prop :=
  (schedulesUpTo fixture.circuit fixture.horizon k fixture.allowed).all
    (fun schedule => decide (scheduleSifaResistant fixture schedule)) = true

instance (fixture : SifaInstance) (k : Nat) :
    Decidable (SifaResistant fixture k) := by
  unfold SifaResistant
  infer_instance

end LeanSec.Fault
