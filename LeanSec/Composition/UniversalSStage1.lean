import LeanSec.Execution

namespace LeanSec
namespace Composition
namespace UniversalSStage1


/-! Public, definitionally equal names for the two private evaluator helpers.
They let this module reason about the frozen evaluator without changing it. -/

def inputValue (env : Env) (values : List (Node × Bool))
    (gate cycle : Nat) (input : Nat × Nat) : Bool :=
  let (src, latency) := input
  if latency ≤ cycle then
    (Execution.lookupAssoc
      { gate := src, cycle := cycle - latency } values).getD false
  else
    env (.iniReg gate)

def gateValue (c : Circuit) (env : Env) (values : List (Node × Bool))
    (cycle gate : Nat) : Bool :=
  match c.gates[gate]? with
  | none => false
  | some g =>
      let ins := g.inputs.map (inputValue env values gate cycle)
      match g.kind with
      | .xor => ins.getD 0 false != ins.getD 1 false
      | .and => ins.getD 0 false && ins.getD 1 false
      | .not => !(ins.getD 0 false)
      | .reg => ins.getD 0 false
      | .mux => if ins.getD 0 false then ins.getD 2 false else ins.getD 1 false
      | .const b => b
      | .rnd r => env (.rnd r cycle)
      | .inp sharing share => env (.inp sharing share cycle)
      | .ini s => env (.ini s cycle)
      | .ctl control => env (.ctl control cycle)

def evalCycle (c : Circuit) (env : Env) (cycle : Nat)
    (schedule : List Nat) (values : List (Node × Bool)) :
    List (Node × Bool) :=
  schedule.foldl (fun values gate =>
    ({ gate := gate, cycle := cycle },
      gateValue c env values cycle gate) :: values) values

def evalCycles (c : Circuit) (env : Env) (schedule : List Nat)
    (cycles : List Nat) (values : List (Node × Bool)) :
    List (Node × Bool) :=
  cycles.foldl (fun values cycle =>
    evalCycle c env cycle schedule values) values

def evalEntries (c : Circuit) (horizon : Nat) (env : Env) :
    List (Node × Bool) :=
  evalCycles c env (Execution.gateOrder c) (List.range horizon) []

theorem evalEntries_eq_execution (c : Circuit) (horizon : Nat) (env : Env) :
    evalEntries c horizon env = Execution.evalEntries c horizon env := by
  rfl

/-- Two evaluation tables agree on every node belonging to the prefix. -/
def TablesAgreeBelow (bound : Nat) (left right : List (Node × Bool)) : Prop :=
  ∀ node, node.gate < bound →
    Execution.lookupAssoc node left = Execution.lookupAssoc node right

/-- The prefix gate array is unchanged by the extension. -/
def GatesAgreeBelow (bound : Nat) (left right : Circuit) : Prop :=
  ∀ gate, gate < bound → left.gates[gate]? = right.gates[gate]?

/-- Every structural predecessor of a prefix gate is itself in the prefix. -/
def InputsBelow (bound : Nat) (c : Circuit) : Prop :=
  ∀ gate, gate < bound → ∀ entry,
    c.gates[gate]? = some entry →
      ∀ input ∈ entry.inputs, input.1 < bound

/-- Kahn predecessor tests for prefix destinations are insensitive to the
non-prefix part of the remaining vertex set. -/
def PredicatesAgreeBelow (bound : Nat)
    (subEdges compositeEdges : List (Nat × Nat)) : Prop :=
  ∀ remaining gate, gate < bound →
    Circuit.hasRemainingPred compositeEdges remaining gate =
      Circuit.hasRemainingPred subEdges
        (remaining.filter fun candidate => candidate < bound) gate

def EdgesAgreeBelow (bound : Nat)
    (subEdges compositeEdges : List (Nat × Nat)) : Prop :=
  (∀ edge, edge.2 < bound → (edge ∈ compositeEdges ↔ edge ∈ subEdges)) ∧
  (∀ edge ∈ subEdges, edge.1 < bound)

theorem mem_combEdges_iff (c : Circuit) (edge : Nat × Nat) :
    edge ∈ c.combEdges ↔
      ∃ entry, c.gates[edge.2]? = some entry ∧
        ∃ input ∈ entry.inputs, input.2 = 0 ∧ input.1 = edge.1 := by
  unfold Circuit.combEdges
  rw [List.mem_flatten]
  constructor
  · rintro ⟨edges, hedgeMap, hedge⟩
    rw [List.mem_map] at hedgeMap
    rcases hedgeMap with ⟨indexed, hindexed, hedges⟩
    rw [List.mem_zipIdx_iff_getElem?] at hindexed
    rcases indexed with ⟨entry, dst⟩
    simp only [Prod.snd, Prod.fst] at hindexed hedges
    rw [← hedges] at hedge
    rw [List.mem_map] at hedge
    rcases hedge with ⟨input, hinputFilter, heq⟩
    rw [List.mem_filter] at hinputFilter
    have hlatency : input.2 = 0 := by simpa using hinputFilter.2
    subst edge
    exact ⟨entry, by simpa using hindexed, input, hinputFilter.1,
      hlatency, rfl⟩
  · rintro ⟨entry, hentry, input, hinput, hlatency, hsource⟩
    let edges := (entry.inputs.filter fun input => input.2 == 0).map
      fun input => (input.1, edge.2)
    refine ⟨edges, ?_, ?_⟩
    · rw [List.mem_map]
      refine ⟨(entry, edge.2), ?_, rfl⟩
      rw [List.mem_zipIdx_iff_getElem?]
      simpa using hentry
    · dsimp only [edges]
      rw [List.mem_map]
      refine ⟨input, ?_, ?_⟩
      · rw [List.mem_filter]
        exact ⟨hinput, by simpa using hlatency⟩
      · exact Prod.ext hsource (Eq.refl edge.2)

def appendCircuit (subc : Circuit) (suffix : Array Gate) : Circuit :=
  { gates := subc.gates ++ suffix }

theorem appendCircuit_size (subc : Circuit) (suffix : Array Gate) :
    (appendCircuit subc suffix).gates.size =
      subc.gates.size + suffix.size := by
  simp [appendCircuit]

theorem appendCircuit_gatesAgreeBelow (subc : Circuit)
    (suffix : Array Gate) :
    GatesAgreeBelow subc.gates.size subc (appendCircuit subc suffix) := by
  intro gate hgate
  exact (Array.getElem?_append_left hgate).symm

theorem inputsBelow_of_indicesOk (c : Circuit)
    (hindices : c.indicesOk = true) :
    InputsBelow c.gates.size c := by
  intro gate hgate entry hentry input hinput
  have hentryEq : c.gates[gate] = entry := by
    simpa [hgate] using hentry
  subst entry
  have hall := Array.all_eq_true.mp hindices gate hgate
  simp only [Bool.and_eq_true] at hall
  have hinputBound := List.all_eq_true.mp hall.2 input hinput
  simpa using hinputBound

theorem appendCircuit_edgesAgreeBelow (subc : Circuit)
    (suffix : Array Gate) (hindices : subc.indicesOk = true) :
    EdgesAgreeBelow subc.gates.size subc.combEdges
      (appendCircuit subc suffix).combEdges := by
  have hinputs := inputsBelow_of_indicesOk subc hindices
  constructor
  · intro edge hedge
    rw [mem_combEdges_iff, mem_combEdges_iff]
    constructor
    · rintro ⟨entry, hentry, input, hinput, hlatency, hsource⟩
      have happend := Array.getElem?_append_left
        (xs := subc.gates) (ys := suffix) hedge
      have hentrySub : subc.gates[edge.2]? = some entry := by
        rw [← happend]
        exact hentry
      exact ⟨entry, hentrySub, input, hinput, hlatency, hsource⟩
    · rintro ⟨entry, hentry, input, hinput, hlatency, hsource⟩
      have happend := Array.getElem?_append_left
        (xs := subc.gates) (ys := suffix) hedge
      have hentryComposite :
          (appendCircuit subc suffix).gates[edge.2]? = some entry := by
        rw [appendCircuit, happend]
        exact hentry
      exact ⟨entry, hentryComposite, input, hinput, hlatency, hsource⟩
  · intro edge hedge
    rw [mem_combEdges_iff] at hedge
    rcases hedge with ⟨entry, hentry, input, hinput, _hlatency, hsource⟩
    rw [← hsource]
    have hedgeBound : edge.2 < subc.gates.size := by
      by_cases hbound : edge.2 < subc.gates.size
      · exact hbound
      · have hnone : subc.gates[edge.2]? = none := by simp [hbound]
        rw [hnone] at hentry
        contradiction
    exact hinputs edge.2 hedgeBound entry hentry input hinput

theorem tablesAgreeBelow_nil (bound : Nat) :
    TablesAgreeBelow bound [] [] := by
  intro node _
  rfl

theorem tablesAgreeBelow_cons_outside (bound : Nat)
    (node : Node) (value : Bool) (left right : List (Node × Bool))
    (hout : ¬ node.gate < bound)
    (hagree : TablesAgreeBelow bound left right) :
    TablesAgreeBelow bound ((node, value) :: left) right := by
  intro target htarget
  have hne : target ≠ node := by
    intro heq
    subst target
    exact hout htarget
  simpa [Execution.lookupAssoc, hne] using hagree target htarget

theorem tablesAgreeBelow_cons_inside (bound : Nat)
    (node : Node) (leftValue rightValue : Bool)
    (left right : List (Node × Bool))
    (hin : node.gate < bound) (hvalue : leftValue = rightValue)
    (hagree : TablesAgreeBelow bound left right) :
    TablesAgreeBelow bound
      ((node, leftValue) :: left) ((node, rightValue) :: right) := by
  subst rightValue
  intro target htarget
  by_cases heq : target = node
  · subst target
    simp [Execution.lookupAssoc]
  · simpa [Execution.lookupAssoc, heq] using hagree target htarget

theorem TablesAgreeBelow.symm {bound : Nat} {left right : List (Node × Bool)}
    (hagree : TablesAgreeBelow bound left right) :
    TablesAgreeBelow bound right left := by
  intro node hnode
  exact (hagree node hnode).symm

theorem inputValue_eq_of_tablesAgreeBelow (bound gate cycle : Nat)
    (env : Env) (left right : List (Node × Bool)) (input : Nat × Nat)
    (hinput : input.1 < bound)
    (hagree : TablesAgreeBelow bound left right) :
    inputValue env left gate cycle input =
      inputValue env right gate cycle input := by
  rcases input with ⟨source, latency⟩
  simp only [inputValue]
  split
  · rw [hagree { gate := source, cycle := cycle - latency } hinput]
  · rfl

theorem gateValue_eq_of_tablesAgreeBelow (bound cycle gate : Nat)
    (subc composite : Circuit) (env : Env)
    (left right : List (Node × Bool))
    (hgate : gate < bound)
    (hgates : GatesAgreeBelow bound subc composite)
    (hinputs : InputsBelow bound subc)
    (hagree : TablesAgreeBelow bound left right) :
    gateValue subc env left cycle gate =
      gateValue composite env right cycle gate := by
  have hlookup := hgates gate hgate
  cases hp : subc.gates[gate]? with
  | none =>
      rw [hp] at hlookup
      simp [gateValue, hp, ← hlookup]
  | some entry =>
      rw [hp] at hlookup
      have hins :
          entry.inputs.map (inputValue env left gate cycle) =
            entry.inputs.map (inputValue env right gate cycle) := by
        apply List.map_congr_left
        intro input hmem
        exact inputValue_eq_of_tablesAgreeBelow bound gate cycle env left right
          input (hinputs gate hgate entry hp input hmem) hagree
      simp only [gateValue, hp, ← hlookup]
      rw [hins]

theorem gatesAgreeBelow_refl (bound : Nat) (c : Circuit) :
    GatesAgreeBelow bound c c := by
  intro gate _
  rfl

theorem predicatesAgreeBelow_of_edgesAgreeBelow (bound : Nat)
    (subEdges compositeEdges : List (Nat × Nat))
    (hedges : EdgesAgreeBelow bound subEdges compositeEdges) :
    PredicatesAgreeBelow bound subEdges compositeEdges := by
  intro remaining gate hgate
  rw [Bool.eq_iff_iff]
  simp only [Circuit.hasRemainingPred, List.any_eq_true, Bool.and_eq_true,
    List.contains_iff_mem, beq_iff_eq, List.mem_filter]
  constructor
  · rintro ⟨edge, hedge, hsource, htarget⟩
    have hedgeSub : edge ∈ subEdges :=
      (hedges.1 edge (htarget ▸ hgate)).mp hedge
    exact ⟨edge, hedgeSub,
      ⟨hsource, by simpa using hedges.2 edge hedgeSub⟩, htarget⟩
  · rintro ⟨edge, hedge, ⟨hsource, _⟩, htarget⟩
    have hedgeComposite : edge ∈ compositeEdges :=
      (hedges.1 edge (htarget ▸ hgate)).mpr hedge
    exact ⟨edge, hedgeComposite, hsource, htarget⟩

theorem ready_filter_below (bound : Nat)
    (subEdges compositeEdges : List (Nat × Nat))
    (remaining : List Nat)
    (hpred : PredicatesAgreeBelow bound subEdges compositeEdges) :
    (Execution.ready compositeEdges remaining).filter
        (fun gate => gate < bound) =
      Execution.ready subEdges
        (remaining.filter fun gate => gate < bound) := by
  simp only [Execution.ready, List.filter_filter]
  apply List.filter_congr
  intro gate hmem
  by_cases hgate : gate < bound
  · rw [hpred remaining gate hgate]
    simp [hgate, Bool.and_comm]
  · simp [hgate]

theorem topoLoop_filter_below (bound : Nat)
    (subEdges compositeEdges : List (Nat × Nat))
    (fuel : Nat) (remaining : List Nat)
    (hpred : PredicatesAgreeBelow bound subEdges compositeEdges) :
    (Execution.topoLoop compositeEdges fuel remaining).filter
        (fun gate => gate < bound) =
      Execution.topoLoop subEdges fuel
        (remaining.filter fun gate => gate < bound) := by
  induction fuel generalizing remaining with
  | zero => rfl
  | succ fuel ih =>
      simp only [Execution.topoLoop, List.filter_append]
      have hready := ready_filter_below bound subEdges compositeEdges
        remaining hpred
      rw [hready]
      have hremaining :
          (remaining.filter fun gate =>
              !(Execution.ready compositeEdges remaining).contains gate).filter
              (fun gate => gate < bound) =
            (remaining.filter fun gate => gate < bound).filter fun gate =>
              !(Execution.ready subEdges
                (remaining.filter fun gate => gate < bound)).contains gate := by
        simp only [List.filter_filter]
        apply List.filter_congr
        intro gate hmem
        by_cases hgate : gate < bound
        · have hmemReady :
              gate ∈ Execution.ready compositeEdges remaining ↔
                gate ∈ Execution.ready subEdges
                  (remaining.filter fun gate => gate < bound) := by
            rw [← hready]
            simp [hgate]
          rw [Bool.and_comm]
          simp [hgate, hmemReady]
        · simp [hgate]
      rw [ih _, hremaining]

/-- Vertices left after the layers emitted by `topoLoop`. -/
def topoRemaining (edges : List (Nat × Nat)) : Nat → List Nat → List Nat
  | 0, remaining => remaining
  | fuel + 1, remaining =>
      topoRemaining edges fuel
        (remaining.filter fun gate =>
          !(Execution.ready edges remaining).contains gate)

theorem topoLoop_add_fuel (edges : List (Nat × Nat))
    (first second : Nat) (remaining : List Nat) :
    Execution.topoLoop edges (first + second) remaining =
      Execution.topoLoop edges first remaining ++
        Execution.topoLoop edges second
          (topoRemaining edges first remaining) := by
  induction first generalizing remaining with
  | zero =>
      simp only [Nat.zero_add, Execution.topoLoop, topoRemaining,
        List.nil_append]
  | succ first ih =>
      simp only [Nat.succ_add, Execution.topoLoop, topoRemaining]
      rw [ih]
      exact (List.append_assoc _ _ _).symm

theorem topoRemaining_add_fuel (edges : List (Nat × Nat))
    (first second : Nat) (remaining : List Nat) :
    topoRemaining edges (first + second) remaining =
      topoRemaining edges second (topoRemaining edges first remaining) := by
  induction first generalizing remaining with
  | zero => simp only [Nat.zero_add, topoRemaining]
  | succ first ih =>
      simp only [Nat.succ_add, topoRemaining]
      exact ih _

theorem filter_not_ready_eq_kahnStep (edges : List (Nat × Nat))
    (remaining : List Nat) :
    remaining.filter (fun gate =>
        !(Execution.ready edges remaining).contains gate) =
      Circuit.kahnStep edges remaining := by
  unfold Circuit.kahnStep
  apply List.filter_congr
  intro gate hgate
  by_cases hpred : Circuit.hasRemainingPred edges remaining gate
  · simp [Execution.ready, hgate, hpred]
  · simp [Execution.ready, hgate, hpred]

theorem topoRemaining_eq_kahnLoop (edges : List (Nat × Nat))
    (fuel : Nat) (remaining : List Nat) :
    topoRemaining edges fuel remaining =
      Circuit.kahnLoop edges fuel remaining := by
  induction fuel generalizing remaining with
  | zero => rfl
  | succ fuel ih =>
      simp only [topoRemaining, Circuit.kahnLoop]
      rw [filter_not_ready_eq_kahnStep]
      exact ih _

theorem topoRemaining_empty_of_acyclic (c : Circuit)
    (hacyclic : c.combAcyclic = true) :
    topoRemaining c.combEdges c.gates.size
        (List.range c.gates.size) = [] := by
  rw [topoRemaining_eq_kahnLoop]
  simpa [Circuit.combAcyclic] using hacyclic

theorem topoLoop_extra_fuel_of_acyclic (c : Circuit) (extra : Nat)
    (hacyclic : c.combAcyclic = true) :
    Execution.topoLoop c.combEdges (c.gates.size + extra)
        (List.range c.gates.size) =
      Execution.topoLoop c.combEdges c.gates.size
        (List.range c.gates.size) := by
  rw [topoLoop_add_fuel]
  rw [topoRemaining_empty_of_acyclic c hacyclic]
  have hempty : ∀ fuel,
      Execution.topoLoop c.combEdges fuel [] = [] := by
    intro fuel
    induction fuel with
    | zero => rfl
    | succ fuel ih =>
        simp [Execution.topoLoop, Execution.ready, ih]
  rw [hempty]
  simp

theorem range_add_filter_lt (bound extra : Nat) :
    (List.range (bound + extra)).filter (fun gate => gate < bound) =
      List.range bound := by
  rw [List.range_add, List.filter_append]
  have hleft : (List.range bound).filter (fun gate => gate < bound) =
      List.range bound := by
    apply List.filter_eq_self.mpr
    intro gate hgate
    simpa using hgate
  rw [hleft]
  have hright :
      (List.map (fun x => bound + x) (List.range extra)).filter
          (fun gate => gate < bound) = [] := by
    induction List.range extra with
    | nil => rfl
    | cons x xs ih =>
        simp only [List.map_cons, List.filter_cons]
        have hnot : ¬ bound + x < bound := by omega
        simp [hnot, ih]
  rw [hright, List.append_nil]

theorem fallback_filter_below (bound : Nat)
    (compositeRange compositeTopo subRange subTopo : List Nat)
    (hrange : compositeRange.filter (fun gate => gate < bound) = subRange)
    (htopo : compositeTopo.filter (fun gate => gate < bound) = subTopo) :
    (compositeRange.filter fun gate => !compositeTopo.contains gate).filter
        (fun gate => gate < bound) =
      subRange.filter fun gate => !subTopo.contains gate := by
  rw [← hrange]
  simp only [List.filter_filter]
  apply List.filter_congr
  intro gate hmem
  by_cases hgate : gate < bound
  · have hmemTopo : gate ∈ compositeTopo ↔ gate ∈ subTopo := by
      rw [← htopo]
      simp [hgate]
    rw [Bool.and_comm]
    simp [hgate, hmemTopo]
  · simp [hgate]

theorem gateOrder_filter_below (bound extra : Nat)
    (subc composite : Circuit)
    (hsubSize : subc.gates.size = bound)
    (hcompositeSize : composite.gates.size = bound + extra)
    (hpred : PredicatesAgreeBelow bound subc.combEdges composite.combEdges)
    (hacyclic : subc.combAcyclic = true) :
    (Execution.gateOrder composite).filter (fun gate => gate < bound) =
      Execution.gateOrder subc := by
  let compositeTopo := Execution.topoLoop composite.combEdges
    composite.gates.size (List.range composite.gates.size)
  let subTopo := Execution.topoLoop subc.combEdges
    subc.gates.size (List.range subc.gates.size)
  have hrange :
      (List.range composite.gates.size).filter (fun gate => gate < bound) =
        List.range subc.gates.size := by
    rw [hcompositeSize, hsubSize]
    exact range_add_filter_lt bound extra
  have htopo : compositeTopo.filter (fun gate => gate < bound) = subTopo := by
    dsimp only [compositeTopo, subTopo]
    rw [hcompositeSize]
    rw [topoLoop_filter_below bound subc.combEdges composite.combEdges
      (bound + extra) (List.range (bound + extra)) hpred]
    rw [range_add_filter_lt]
    rw [← hsubSize]
    exact topoLoop_extra_fuel_of_acyclic subc extra hacyclic
  unfold Execution.gateOrder
  change (compositeTopo ++
      (List.range composite.gates.size).filter
        (fun gate => !compositeTopo.contains gate)).filter
      (fun gate => gate < bound) =
    subTopo ++ (List.range subc.gates.size).filter
      (fun gate => !subTopo.contains gate)
  rw [List.filter_append, htopo]
  congr 1
  exact fallback_filter_below bound _ _ _ _ hrange htopo

/-- Interleaving non-prefix gates into one cycle cannot change any prefix
lookup.  Prefix gates are evaluated in the filtered order on both sides. -/
theorem evalCycle_tablesAgreeBelow (bound cycle : Nat)
    (subc composite : Circuit) (env : Env)
    (schedule : List Nat) (left right : List (Node × Bool))
    (hgates : GatesAgreeBelow bound subc composite)
    (hinputs : InputsBelow bound subc)
    (hagree : TablesAgreeBelow bound left right) :
    TablesAgreeBelow bound
      (evalCycle subc env cycle (schedule.filter fun gate => gate < bound) left)
      (evalCycle composite env cycle schedule right) := by
  induction schedule generalizing left right with
  | nil => exact hagree
  | cons gate schedule ih =>
      by_cases hgate : gate < bound
      · simp only [List.filter_cons, hgate, ↓reduceIte, evalCycle,
          List.foldl_cons]
        apply ih
        apply tablesAgreeBelow_cons_inside bound
        · exact hgate
        · exact gateValue_eq_of_tablesAgreeBelow bound cycle gate subc
            composite env left right hgate hgates hinputs hagree
        · exact hagree
      · simp only [List.filter_cons, hgate, ↓reduceIte, evalCycle,
          List.foldl_cons]
        apply ih
        exact (tablesAgreeBelow_cons_outside bound
          { gate := gate, cycle := cycle }
          (gateValue composite env right cycle gate) right left hgate
          hagree.symm).symm

theorem evalEntries_tablesAgreeBelow_of_gateOrder (bound horizon : Nat)
    (subc composite : Circuit) (env : Env)
    (hgates : GatesAgreeBelow bound subc composite)
    (hinputs : InputsBelow bound subc)
    (horder : (Execution.gateOrder composite).filter
        (fun gate => gate < bound) = Execution.gateOrder subc) :
    TablesAgreeBelow bound
      (evalEntries subc horizon env) (evalEntries composite horizon env) := by
  have hcycles : ∀ (cycles : List Nat) (left right : List (Node × Bool)),
      TablesAgreeBelow bound left right →
      TablesAgreeBelow bound
        (evalCycles subc env (Execution.gateOrder subc) cycles left)
        (evalCycles composite env (Execution.gateOrder composite)
          cycles right) := by
    intro cycles
    induction cycles with
    | nil =>
        intro left right hagree
        exact hagree
    | cons cycle cycles ih =>
        intro left right hagree
        simp only [evalCycles, List.foldl_cons]
        apply ih
        rw [← horder]
        exact evalCycle_tablesAgreeBelow bound cycle subc composite env
          (Execution.gateOrder composite) left right hgates hinputs hagree
  exact hcycles (List.range horizon) [] [] (tablesAgreeBelow_nil bound)

theorem eval_eq_of_gateOrder_restriction (horizon bound : Nat)
    (subc composite : Circuit) (env : Env) (node : Node)
    (hsubBound : bound ≤ subc.gates.size)
    (hbound : bound ≤ composite.gates.size)
    (hnode : node.gate < bound)
    (hgates : GatesAgreeBelow bound subc composite)
    (hinputs : InputsBelow bound subc)
    (horder : (Execution.gateOrder composite).filter
        (fun gate => gate < bound) = Execution.gateOrder subc) :
    Execution.eval composite horizon env node =
      Execution.eval subc horizon env node := by
  by_cases hcycle : node.cycle < horizon
  · have hsubSize : node.gate < subc.gates.size := by omega
    have hcompositeSize : node.gate < composite.gates.size := by omega
    simp only [Execution.eval, hsubSize, hcompositeSize, hcycle,
      decide_true, Bool.true_and, ↓reduceIte]
    rw [← evalEntries_eq_execution, ← evalEntries_eq_execution]
    have hagree := evalEntries_tablesAgreeBelow_of_gateOrder bound horizon
      subc composite env hgates hinputs horder
    exact congrArg (fun value => value.getD false)
      (hagree node hnode).symm
  · simp [Execution.eval, hcycle]

/-- Stage-1 restriction theorem.  Appending an arbitrary downstream gate
array to a well-formed upstream circuit does not change the frozen evaluator
on any upstream node.  Downstream gates may read upstream gates; no edge can
flow back into the prefix because destinations are determined by array
position and the prefix itself satisfies `indicesOk`. -/
theorem eval_appendCircuit_prefix (subc : Circuit) (suffix : Array Gate)
    (horizon : Nat) (env : Env) (node : Node)
    (hwf : subc.WF) (hnode : node.gate < subc.gates.size) :
    Execution.eval (appendCircuit subc suffix) horizon env node =
      Execution.eval subc horizon env node := by
  have hedges := appendCircuit_edgesAgreeBelow subc suffix hwf.1
  have hpred := predicatesAgreeBelow_of_edgesAgreeBelow
    subc.gates.size subc.combEdges (appendCircuit subc suffix).combEdges hedges
  have horder := gateOrder_filter_below subc.gates.size suffix.size
    subc (appendCircuit subc suffix) rfl (appendCircuit_size subc suffix)
    hpred hwf.2
  apply eval_eq_of_gateOrder_restriction horizon subc.gates.size
    subc (appendCircuit subc suffix) env node
  · omega
  · simp [appendCircuit]
  · exact hnode
  · exact appendCircuit_gatesAgreeBelow subc suffix
  · exact inputsBelow_of_indicesOk subc hwf.1
  · exact horder

/-! The product experiment used by serial composition does not reuse the
same total environment for both component views.  The following public
spelling of the frozen source scan and evaluator congruence theorem strengthen
the prefix restriction to environments which agree on the upstream support. -/

def publicGateSrcs (horizon : Nat) (g : Gate) : List Src :=
  match g.kind with
  | .rnd r => (List.range horizon).map (.rnd r)
  | .inp sharing share => (List.range horizon).map (.inp sharing share)
  | .ini s => (List.range horizon).map (.ini s)
  | .ctl control => (List.range horizon).map (.ctl control)
  | _ => []

def publicBoundarySrcs (horizon gate : Nat) (g : Gate) : List Src :=
  (List.range horizon).flatMap fun cycle =>
    (g.inputs.filter fun input => cycle < input.2).map fun _ => .iniReg gate

theorem relevantSrcs_eq_public (c : Circuit) (horizon : Nat) :
    Execution.relevantSrcs c horizon =
      ((c.gates.toList.zipIdx).flatMap fun (g, gate) =>
        publicGateSrcs horizon g ++ publicBoundarySrcs horizon gate g).eraseDups := by
  rfl

theorem sourceGate_mem_relevant (c : Circuit) (horizon gate cycle : Nat)
    (entry : Gate) (hgate : c.gates[gate]? = some entry)
    (hcycle : cycle < horizon) :
    match entry.kind with
    | .rnd r => .rnd r cycle ∈ Execution.relevantSrcs c horizon
    | .inp sharing share => .inp sharing share cycle ∈ Execution.relevantSrcs c horizon
    | .ini s => .ini s cycle ∈ Execution.relevantSrcs c horizon
    | .ctl control => .ctl control cycle ∈ Execution.relevantSrcs c horizon
    | _ => True := by
  have hgateBound : gate < c.gates.size := by
    by_cases h : gate < c.gates.size
    · exact h
    · simp [h] at hgate
  have hentry : c.gates[gate] = entry := by simpa [hgateBound] using hgate
  subst entry
  cases hkind : c.gates[gate].kind <;> simp only
  case rnd r =>
    rw [relevantSrcs_eq_public, List.mem_eraseDups, List.mem_flatMap]
    refine ⟨(c.gates[gate], gate), ?_, ?_⟩
    · rw [List.mem_zipIdx_iff_getElem?]
      simp [hgateBound]
    · rw [List.mem_append]
      apply Or.inl
      simp [publicGateSrcs, hkind, hcycle]
  case inp sharing share =>
    rw [relevantSrcs_eq_public, List.mem_eraseDups, List.mem_flatMap]
    refine ⟨(c.gates[gate], gate), ?_, ?_⟩
    · rw [List.mem_zipIdx_iff_getElem?]
      simp [hgateBound]
    · rw [List.mem_append]
      apply Or.inl
      simp [publicGateSrcs, hkind, hcycle]
  case ini s =>
    rw [relevantSrcs_eq_public, List.mem_eraseDups, List.mem_flatMap]
    refine ⟨(c.gates[gate], gate), ?_, ?_⟩
    · rw [List.mem_zipIdx_iff_getElem?]
      simp [hgateBound]
    · rw [List.mem_append]
      apply Or.inl
      simp [publicGateSrcs, hkind, hcycle]
  case ctl control =>
    rw [relevantSrcs_eq_public, List.mem_eraseDups, List.mem_flatMap]
    refine ⟨(c.gates[gate], gate), ?_, ?_⟩
    · rw [List.mem_zipIdx_iff_getElem?]
      simp [hgateBound]
    · rw [List.mem_append]
      apply Or.inl
      simp [publicGateSrcs, hkind, hcycle]

theorem boundaryGate_mem_relevant (c : Circuit) (horizon gate cycle : Nat)
    (entry : Gate) (input : Nat × Nat)
    (hgate : c.gates[gate]? = some entry) (hinput : input ∈ entry.inputs)
    (hcycle : cycle < horizon) (hboundary : cycle < input.2) :
    Src.iniReg gate ∈ Execution.relevantSrcs c horizon := by
  have hgateBound : gate < c.gates.size := by
    by_cases h : gate < c.gates.size
    · exact h
    · simp [h] at hgate
  have hentry : c.gates[gate] = entry := by simpa [hgateBound] using hgate
  subst entry
  rw [relevantSrcs_eq_public, List.mem_eraseDups, List.mem_flatMap]
  refine ⟨(c.gates[gate], gate), ?_, ?_⟩
  · rw [List.mem_zipIdx_iff_getElem?]
    simp [hgateBound]
  · rw [List.mem_append]
    apply Or.inr
    simp only [publicBoundarySrcs, List.mem_flatMap]
    refine ⟨cycle, by simpa using hcycle, ?_⟩
    simp only [List.mem_map]
    refine ⟨input, ?_, True.intro⟩
    simp [hinput, hboundary]

def EnvAgreeOn (sources : List Src) (left right : Env) : Prop :=
  ∀ src ∈ sources, left src = right src

theorem inputValue_eq_of_envAgree (c : Circuit) (horizon : Nat)
    (leftEnv rightEnv : Env) (values : List (Node × Bool))
    (cycle gate : Nat) (entry : Gate) (input : Nat × Nat)
    (hgate : c.gates[gate]? = some entry) (hinput : input ∈ entry.inputs)
    (hcycle : cycle < horizon)
    (henv : EnvAgreeOn (Execution.relevantSrcs c horizon) leftEnv rightEnv) :
    inputValue leftEnv values gate cycle input =
      inputValue rightEnv values gate cycle input := by
  rcases input with ⟨source, latency⟩
  simp only [inputValue]
  split
  · rfl
  · rename_i hlatency
    apply henv
    exact boundaryGate_mem_relevant c horizon gate cycle entry
      (source, latency) hgate hinput hcycle (by omega)

theorem gateValue_eq_of_envAgree (c : Circuit) (horizon : Nat)
    (leftEnv rightEnv : Env) (values : List (Node × Bool))
    (cycle gate : Nat) (hcycle : cycle < horizon)
    (henv : EnvAgreeOn (Execution.relevantSrcs c horizon) leftEnv rightEnv) :
    gateValue c leftEnv values cycle gate =
      gateValue c rightEnv values cycle gate := by
  cases hgate : c.gates[gate]? with
  | none => simp [gateValue, hgate]
  | some entry =>
      have hins :
          entry.inputs.map (inputValue leftEnv values gate cycle) =
            entry.inputs.map (inputValue rightEnv values gate cycle) := by
        apply List.map_congr_left
        intro input hinput
        exact inputValue_eq_of_envAgree c horizon leftEnv rightEnv values
          cycle gate entry input hgate hinput hcycle henv
      have hsource := sourceGate_mem_relevant c horizon gate cycle entry
        hgate hcycle
      cases hkind : entry.kind <;>
        simp only [gateValue, hgate] <;> rw [hins]
      all_goals simp only [hkind]
      case rnd r => exact henv _ (by simpa [hkind] using hsource)
      case inp sharing share => exact henv _ (by simpa [hkind] using hsource)
      case ini s => exact henv _ (by simpa [hkind] using hsource)
      case ctl control => exact henv _ (by simpa [hkind] using hsource)

theorem evalCycle_eq_of_envAgree (c : Circuit) (horizon : Nat)
    (leftEnv rightEnv : Env) (cycle : Nat) (schedule : List Nat)
    (values : List (Node × Bool)) (hcycle : cycle < horizon)
    (henv : EnvAgreeOn (Execution.relevantSrcs c horizon) leftEnv rightEnv) :
    evalCycle c leftEnv cycle schedule values =
      evalCycle c rightEnv cycle schedule values := by
  induction schedule generalizing values with
  | nil => rfl
  | cons gate schedule ih =>
      simp only [evalCycle, List.foldl_cons]
      rw [gateValue_eq_of_envAgree c horizon leftEnv rightEnv values cycle gate
        hcycle henv]
      exact ih _

theorem evalCycles_eq_of_envAgree (c : Circuit) (horizon : Nat)
    (leftEnv rightEnv : Env) (schedule cycles : List Nat)
    (values : List (Node × Bool))
    (hcycles : ∀ cycle ∈ cycles, cycle < horizon)
    (henv : EnvAgreeOn (Execution.relevantSrcs c horizon) leftEnv rightEnv) :
    evalCycles c leftEnv schedule cycles values =
      evalCycles c rightEnv schedule cycles values := by
  induction cycles generalizing values with
  | nil => rfl
  | cons cycle cycles ih =>
      simp only [evalCycles, List.foldl_cons]
      rw [evalCycle_eq_of_envAgree c horizon leftEnv rightEnv cycle schedule
        values (hcycles cycle (by simp)) henv]
      apply ih
      intro later hlater
      exact hcycles later (by simp [hlater])

theorem eval_env_congr (c : Circuit) (horizon : Nat)
    (leftEnv rightEnv : Env) (node : Node)
    (henv : EnvAgreeOn (Execution.relevantSrcs c horizon) leftEnv rightEnv) :
    Execution.eval c horizon leftEnv node =
      Execution.eval c horizon rightEnv node := by
  unfold Execution.eval
  split
  · congr 2
    rw [← evalEntries_eq_execution, ← evalEntries_eq_execution]
    unfold evalEntries
    apply evalCycles_eq_of_envAgree
    · intro cycle hcycle
      simpa using hcycle
    · exact henv
  · rfl

theorem eval_appendCircuit_prefix_of_envAgree
    (subc : Circuit) (suffix : Array Gate) (horizon : Nat)
    (compositeEnv subEnv : Env) (node : Node)
    (hwf : subc.WF) (hnode : node.gate < subc.gates.size)
    (henv : EnvAgreeOn (Execution.relevantSrcs subc horizon)
      compositeEnv subEnv) :
    Execution.eval (appendCircuit subc suffix) horizon compositeEnv node =
      Execution.eval subc horizon subEnv node := by
  rw [eval_appendCircuit_prefix subc suffix horizon compositeEnv node hwf hnode]
  exact eval_env_congr subc horizon compositeEnv subEnv node henv

end UniversalSStage1
end Composition
end LeanSec

#print axioms LeanSec.Composition.UniversalSStage1.evalEntries_eq_execution
#print axioms LeanSec.Composition.UniversalSStage1.tablesAgreeBelow_cons_outside
#print axioms LeanSec.Composition.UniversalSStage1.tablesAgreeBelow_cons_inside
#print axioms LeanSec.Composition.UniversalSStage1.gateValue_eq_of_tablesAgreeBelow
#print axioms LeanSec.Composition.UniversalSStage1.evalCycle_tablesAgreeBelow
#print axioms LeanSec.Composition.UniversalSStage1.evalEntries_tablesAgreeBelow_of_gateOrder
#print axioms LeanSec.Composition.UniversalSStage1.eval_eq_of_gateOrder_restriction
#print axioms LeanSec.Composition.UniversalSStage1.eval_appendCircuit_prefix
#print axioms LeanSec.Composition.UniversalSStage1.eval_env_congr
#print axioms LeanSec.Composition.UniversalSStage1.eval_appendCircuit_prefix_of_envAgree
