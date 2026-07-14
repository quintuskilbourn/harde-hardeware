import LeanSec.Execution

/-!
An executable, finite model of transient gate-output faults.  This module is
deliberately outside `LeanSec.Security`: it is a first fault-correctness slice,
not a change to the audited probing-security trust root.

The positive anchor is a duplicated one-bit AND with a faultable comparator.
The negative anchor is the corresponding unprotected AND.  Both statements use
the same exhaustive, at-most-one-fault detection property.
-/

namespace LeanSec.Fault

/-- A transient Boolean transformation applied after a gate is evaluated. -/
inductive FaultKind where
  | set
  | reset
  | flip
deriving DecidableEq, Repr

def FaultKind.apply : FaultKind → Bool → Bool
  | .set, _ => true
  | .reset, _ => false
  | .flip, value => !value

/-- One fault identifies one output of the finite, unrolled execution. -/
structure FaultEvent where
  target : Node
  kind : FaultKind
deriving DecidableEq, Repr

abbrev FaultSchedule := List FaultEvent

/-- The target boundary is explicit and may inspect the circuit and horizon. -/
abbrev FaultPolicy := Circuit → Nat → Node → Bool

/-- Valid schedules contain at most `k` events, never fault one node twice, and
respect the declared target boundary. -/
def FaultSchedule.Valid (circuit : Circuit) (horizon k : Nat)
    (policy : FaultPolicy) (schedule : FaultSchedule) : Prop :=
  schedule.length ≤ k ∧
    (schedule.map FaultEvent.target).Nodup ∧
    schedule.all (fun event =>
      event.target.gate < circuit.gates.size &&
      event.target.cycle < horizon &&
      policy circuit horizon event.target) = true

instance (circuit : Circuit) (horizon k : Nat) (policy : FaultPolicy)
    (schedule : FaultSchedule) :
    Decidable (schedule.Valid circuit horizon k policy) := by
  unfold FaultSchedule.Valid
  infer_instance

private def inputValue (env : Env) (values : List (Node × Bool))
    (gate cycle : Nat) (input : Nat × Nat) : Bool :=
  let (src, latency) := input
  if latency ≤ cycle then
    (Execution.lookupAssoc { gate := src, cycle := cycle - latency } values).getD false
  else
    env (.iniReg gate)

private def gateValue (circuit : Circuit) (env : Env)
    (values : List (Node × Bool)) (cycle gate : Nat) : Bool :=
  match circuit.gates[gate]? with
  | none => false
  | some g =>
      let ins := g.inputs.map (inputValue env values gate cycle)
      match g.kind with
      | .xor => ins.getD 0 false != ins.getD 1 false
      | .and => ins.getD 0 false && ins.getD 1 false
      | .not => !(ins.getD 0 false)
      | .reg => ins.getD 0 false
      | .mux => if ins.getD 0 false then ins.getD 2 false else ins.getD 1 false
      | .const value => value
      | .rnd random => env (.rnd random cycle)
      | .inp sharing share => env (.inp sharing share cycle)
      | .ini initial => env (.ini initial cycle)
      | .ctl control => env (.ctl control cycle)

private def faultAt (schedule : FaultSchedule) (node : Node) : Option FaultKind :=
  Execution.lookupAssoc node (schedule.map fun event => (event.target, event.kind))

/-- Evaluate the circuit in dependency order, overriding each targeted gate
output before downstream gates consume it. -/
def evalEntriesFaulted (circuit : Circuit) (horizon : Nat) (schedule : FaultSchedule)
    (env : Env) : List (Node × Bool) :=
  (List.range horizon).foldl (fun values cycle =>
    (Execution.gateOrder circuit).foldl (fun values gate =>
      let node : Node := { gate := gate, cycle := cycle }
      let value := gateValue circuit env values cycle gate
      let faulted := (faultAt schedule node).map (fun kind => kind.apply value)
      (node, faulted.getD value) :: values)
    values) []

private def evalFaultedRaw (circuit : Circuit) (horizon : Nat)
    (schedule : FaultSchedule) (env : Env) (node : Node) : Bool :=
  if node.gate < circuit.gates.size && node.cycle < horizon then
    (Execution.lookupAssoc node
      (evalEntriesFaulted circuit horizon schedule env)).getD false
  else
    false

/-- Faulted execution.  The empty case is definitionally the existing golden
evaluator; nonempty schedules use the propagating override evaluator above. -/
def evalFaulted (circuit : Circuit) (horizon : Nat) (schedule : FaultSchedule)
    (env : Env) (node : Node) : Bool :=
  match schedule with
  | [] => Execution.eval circuit horizon env node
  | _ :: _ => evalFaultedRaw circuit horizon schedule env node

theorem evalFaulted_empty (circuit : Circuit) (horizon : Nat)
    (env : Env) (node : Node) :
    evalFaulted circuit horizon [] env node =
      Execution.eval circuit horizon env node := by
  rfl

private def combinations : Nat → List α → List (List α)
  | 0, _ => [[]]
  | _ + 1, [] => []
  | k + 1, value :: values =>
      (combinations k values).map (value :: ·) ++ combinations (k + 1) values

private def subsetsUpTo (k : Nat) (values : List α) : List (List α) :=
  (List.range (k + 1)).flatMap fun order => combinations order values

def nodes (circuit : Circuit) (horizon : Nat) : List Node :=
  (List.range horizon).flatMap fun cycle =>
    (List.range circuit.gates.size).map fun gate => { gate := gate, cycle := cycle }

def faultKinds : List FaultKind := [.set, .reset, .flip]

/-- Every allowed node paired with every supported transient fault mapping. -/
def eventUniverse (circuit : Circuit) (horizon : Nat)
    (policy : FaultPolicy) : List FaultEvent :=
  ((nodes circuit horizon).filter (policy circuit horizon)).flatMap fun target =>
    faultKinds.map fun kind => { target := target, kind := kind }

/-- Exhaustive finite schedules of order at most `k`. -/
def schedulesUpTo (circuit : Circuit) (horizon k : Nat)
    (policy : FaultPolicy) : List FaultSchedule :=
  (subsetsUpTo k (eventUniverse circuit horizon policy)).filter fun schedule =>
    decide (schedule.Valid circuit horizon k policy)

/-- A circuit boundary for detection correctness.  `data` and `alarm` are
observed outside the faultable boundary; the alarm value itself is nevertheless
the value produced by the faulted circuit. -/
structure DetectionInstance where
  circuit : Circuit
  horizon : Nat
  allowed : FaultPolicy
  data : Node
  alarm : Node

/-- One schedule is safe when, for every relevant source assignment, a low
faulted alarm implies that faulted data equals golden data.  False alarms and
ineffective faults are permitted. -/
def detectsSchedule (fixture : DetectionInstance) (schedule : FaultSchedule) : Bool :=
  (Execution.envsOf fixture.circuit fixture.horizon []).all fun env =>
    evalFaulted fixture.circuit fixture.horizon schedule env fixture.alarm ||
      (evalFaulted fixture.circuit fixture.horizon schedule env fixture.data ==
        Execution.eval fixture.circuit fixture.horizon env fixture.data)

/-- Decidable at-most-`k` detection correctness:

`alarm_F(e) = false -> data_F(e) = data_golden(e)`

for every allowed schedule of cardinality `0 .. k` and every finite relevant
environment of the execution. -/
def FaultDetectingUpTo (fixture : DetectionInstance) (k : Nat) : Prop :=
  (schedulesUpTo fixture.circuit fixture.horizon k fixture.allowed).all
    (detectsSchedule fixture) = true

instance (fixture : DetectionInstance) (k : Nat) :
    Decidable (FaultDetectingUpTo fixture k) := by
  unfold FaultDetectingUpTo
  infer_instance

/-! ## Positive redundancy anchor -/

namespace DuplicatedAnd

/-- Two disjoint AND gates feed a comparator.  The first copy is data. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .and, inputs := [(0, 0), (1, 0)] },
      { kind := .and, inputs := [(0, 0), (1, 0)] },
      { kind := .xor, inputs := [(2, 0), (3, 0)] }
    ] }

/-- Inputs and the external observation boundary are trusted; both redundant
AND outputs and the comparator output are faultable. -/
def allowed : FaultPolicy := fun _ _ node =>
  node.cycle == 0 && [2, 3, 4].contains node.gate

def fixture : DetectionInstance :=
  { circuit := circuit
    horizon := 1
    allowed := allowed
    data := { gate := 2, cycle := 0 }
    alarm := { gate := 4, cycle := 0 } }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Anti-vacuity guard: empty plus three mappings at each of three targets. -/
theorem schedule_count_one :
    (schedulesUpTo circuit 1 1 allowed).length = 10 := by
  decide

/-- PASS: every allowed set/reset/flip fault of order at most one is either
ineffective, changes only the duplicate/alarm, or makes the actual alarm high. -/
theorem detects_one_fault : FaultDetectingUpTo fixture 1 := by
  decide

end DuplicatedAnd

/-! ## Negative unprotected mutant -/

namespace UnprotectedAnd

/-- Mutant: the duplicate is removed and the alarm is tied low. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .and, inputs := [(0, 0), (1, 0)] },
      { kind := .const false, inputs := [] }
    ] }

def allowed : FaultPolicy := fun _ _ node =>
  node.cycle == 0 && [2, 3].contains node.gate

def fixture : DetectionInstance :=
  { circuit := circuit
    horizon := 1
    allowed := allowed
    data := { gate := 2, cycle := 0 }
    alarm := { gate := 3, cycle := 0 } }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- The concrete silent corruption used by the negative anchor. -/
def silentFlip : FaultSchedule :=
  [{ target := { gate := 2, cycle := 0 }, kind := .flip }]

theorem silentFlip_valid : silentFlip.Valid circuit 1 1 allowed := by
  decide

theorem silentFlip_is_counterexample :
    detectsSchedule fixture silentFlip = false := by
  decide

/-- FAIL anchor: a single effective fault on the sole AND output is silent. -/
theorem does_not_detect_one_fault : ¬ FaultDetectingUpTo fixture 1 := by
  decide

end UnprotectedAnd

#print axioms evalFaulted_empty
#print axioms DuplicatedAnd.circuit_wf
#print axioms DuplicatedAnd.schedule_count_one
#print axioms DuplicatedAnd.detects_one_fault
#print axioms UnprotectedAnd.circuit_wf
#print axioms UnprotectedAnd.silentFlip_valid
#print axioms UnprotectedAnd.silentFlip_is_counterexample
#print axioms UnprotectedAnd.does_not_detect_one_fault

end LeanSec.Fault
