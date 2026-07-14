import LeanSec.Circuit

namespace LeanSec

namespace Execution

/-- Vertices currently having no predecessor among `remaining`. -/
def ready (edges : List (Nat × Nat)) (remaining : List Nat) : List Nat :=
  remaining.filter fun dst => !(Circuit.hasRemainingPred edges remaining dst)

/-- Kahn's topological order, accumulated one parallel layer at a time. -/
def topoLoop (edges : List (Nat × Nat)) : Nat → List Nat → List Nat
  | 0, _ => []
  | fuel + 1, remaining =>
      let layer := ready edges remaining
      layer ++ topoLoop edges fuel (remaining.filter fun v => !layer.contains v)

/-- A total gate schedule.  On a well-formed circuit the second term is empty;
on malformed circuits it supplies deterministic, total fallback semantics. -/
def gateOrder (c : Circuit) : List Nat :=
  let topo := topoLoop c.combEdges c.gates.size (List.range c.gates.size)
  topo ++ (List.range c.gates.size).filter fun g => !topo.contains g

/-- Lookup in a newest-first association list. -/
def lookupAssoc [BEq α] (key : α) : List (α × β) → Option β
  | [] => none
  | (key', value) :: rest => if key == key' then some value else lookupAssoc key rest

/-- Turn a finite association list into a total, kernel-reducible environment. -/
def envFrom (values : List (Src × Bool)) : Env :=
  fun src => (lookupAssoc src values).getD false

private def inputValue (env : Env) (values : List (Node × Bool))
    (gate cycle : Nat) (input : Nat × Nat) : Bool :=
  let (src, latency) := input
  if latency ≤ cycle then
    (lookupAssoc { gate := src, cycle := cycle - latency } values).getD false
  else
    env (.iniReg gate)

private def gateValue (c : Circuit) (env : Env) (values : List (Node × Bool))
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
      -- Inputs are `[sel, in0, in1]`: false selects `in0`, true selects `in1`.
      | .mux => if ins.getD 0 false then ins.getD 2 false else ins.getD 1 false
      | .const b => b
      | .rnd r => env (.rnd r cycle)
      | .inp sharing share => env (.inp sharing share cycle)
      | .ini s => env (.ini s cycle)
      | .ctl control => env (.ctl control cycle)

/-- Evaluate every node in `[0, horizon)` in lexicographic
`(cycle, combinational-topological-index)` order. -/
def evalEntries (c : Circuit) (horizon : Nat) (env : Env) : List (Node × Bool) :=
  (List.range horizon).foldl (fun values cycle =>
    (gateOrder c).foldl (fun values gate =>
      ({ gate := gate, cycle := cycle }, gateValue c env values cycle gate) :: values)
    values) []

/-- Total executable evaluator.  Nodes outside the requested execution are
assigned `false`; nodes inside it are read from the finite evaluation table. -/
def eval (c : Circuit) (horizon : Nat) (env : Env) (node : Node) : Bool :=
  if node.gate < c.gates.size && node.cycle < horizon then
    (lookupAssoc node (evalEntries c horizon env)).getD false
  else
    false

private def gateSrcs (horizon : Nat) (g : Gate) : List Src :=
  match g.kind with
  | .rnd r => (List.range horizon).map (.rnd r)
  | .inp sharing share => (List.range horizon).map (.inp sharing share)
  | .ini s => (List.range horizon).map (.ini s)
  | .ctl control => (List.range horizon).map (.ctl control)
  | _ => []

private def boundarySrcs (horizon gate : Nat) (g : Gate) : List Src :=
  (List.range horizon).flatMap fun cycle =>
    (g.inputs.filter fun input => cycle < input.2).map fun _ => .iniReg gate

/-- All source instances that can be read in the finite execution.  Duplicate
identities (notably an initial register value) are removed. -/
def relevantSrcs (c : Circuit) (horizon : Nat) : List Src :=
  ((c.gates.toList.zipIdx).flatMap fun (g, gate) =>
    gateSrcs horizon g ++ boundarySrcs horizon gate g).eraseDups

/-- Enumerate every Boolean assignment to a finite source list. -/
def assignments : List Src → List (List (Src × Bool))
  | [] => [[]]
  | src :: rest =>
      (assignments rest).flatMap fun values =>
        [[(src, false)] ++ values, [(src, true)] ++ values]

/-- Enumerate assignments while fixing selected coordinates.  The option list
is position-aligned with the source list; `none` is a free coordinate. -/
def assignmentsPattern : List Src → List (Option Bool) →
    List (List (Src × Bool))
  | [], _ => [[]]
  | src :: rest, [] => assignments (src :: rest)
  | src :: rest, expected :: pattern =>
      let tails := assignmentsPattern rest pattern
      match expected with
      | some value => tails.map fun values => (src, value) :: values
      | none => tails.flatMap fun values =>
          [[(src, false)] ++ values, [(src, true)] ++ values]

/-- Whether a full assignment agrees with a position-aligned pattern. -/
def matchesPattern : List (Option Bool) → List (Src × Bool) → Bool
  | [], _ => true
  | _ :: _, [] => false
  | expected :: rest, (_, value) :: values =>
      expected.all (· == value) && matchesPattern rest values

theorem assignmentsPattern_eq_filter (sources : List Src)
    (pattern : List (Option Bool)) (hlen : pattern.length = sources.length) :
    assignmentsPattern sources pattern =
      (assignments sources).filter (matchesPattern pattern) := by
  induction sources generalizing pattern with
  | nil =>
      cases pattern with
      | nil => rfl
      | cons _ _ => simp at hlen
  | cons src rest ih =>
      cases pattern with
      | nil => simp at hlen
      | cons expected pattern =>
          have htail : pattern.length = rest.length := Nat.succ.inj hlen
          simp only [assignmentsPattern]
          rw [ih pattern htail]
          simp only [assignments]
          generalize assignments rest = tails
          cases expected with
          | none =>
              induction tails with
              | nil => rfl
              | cons values more ihMore =>
                  cases h : matchesPattern pattern values <;>
                    simp [matchesPattern, h] <;> simpa using ihMore
          | some value =>
              cases value <;>
                induction tails with
                | nil => rfl
                | cons values more ihMore =>
                    cases h : matchesPattern pattern values <;>
                      simp [matchesPattern, h] <;> simpa using ihMore

/-! `envsOfFiltered` is the direct finite-space specification.  The executable
`envsOf` below is extensionally the same enumeration, but branches only over
sources absent from the fixing. -/

/-- Direct specification: enumerate the full relevant space, then retain the
environments satisfying every entry of the partial fixing. -/
def envsOfFiltered (c : Circuit) (horizon : Nat)
    (fixing : List (Src × Bool)) : List Env :=
  ((assignments (relevantSrcs c horizon)).map envFrom).filter fun env =>
    fixing.all fun (src, value) => env src == value

/-- Entries of a fixing whose keys are in the finite execution support. -/
def supportedFixing (sources : List Src) (fixing : List (Src × Bool)) :
    List (Src × Bool) :=
  fixing.filter fun (src, _) => sources.contains src

/-- A partial fixing is meaningful for `sources` when duplicate entries agree
and every true entry is supported.  Unsupported false entries agree with the
association-list environment's default and are therefore harmless. -/
def fixingValid (sources : List Src) (fixing : List (Src × Bool)) : Bool :=
  let fixed := supportedFixing sources fixing
  fixing.all fun (src, value) => envFrom fixed src == value

/-- Sources not assigned by the supported part of a fixing. -/
def freeSrcs (sources : List Src) (fixing : List (Src × Bool)) : List Src :=
  let fixed := supportedFixing sources fixing
  sources.filter fun src => (lookupAssoc src fixed).isNone

/-- Free-dimension environment enumeration.  It constructs only
`2 ^ |freeSrcs|` assignments and splices the supported fixing in front. -/
def envsOf (c : Circuit) (horizon : Nat)
    (fixing : List (Src × Bool)) : List Env :=
  let sources := relevantSrcs c horizon
  let fixed := supportedFixing sources fixing
  if fixingValid sources fixing then
    assignmentsPattern sources (sources.map fun src => lookupAssoc src fixed)
      |>.map envFrom
  else
    []

theorem assignments_ne_nil (sources : List Src) : assignments sources ≠ [] := by
  induction sources with
  | nil => simp [assignments]
  | cons src rest ih =>
      cases h : assignments rest with
      | nil => exact (ih h).elim
      | cons values more => simp [assignments, h]

theorem assignmentsPattern_ne_nil (sources : List Src)
    (pattern : List (Option Bool)) : assignmentsPattern sources pattern ≠ [] := by
  induction sources generalizing pattern with
  | nil => simp [assignmentsPattern]
  | cons src rest ih =>
      cases pattern with
      | nil => simpa [assignmentsPattern] using assignments_ne_nil (src :: rest)
      | cons expected pattern =>
          cases h : assignmentsPattern rest pattern with
          | nil => exact (ih pattern h).elim
          | cons values more => cases expected <;> simp [assignmentsPattern, h]

theorem envsOf_ne_nil_of_valid (c : Circuit) (horizon : Nat)
    (fixing : List (Src × Bool))
    (hvalid : fixingValid (relevantSrcs c horizon) fixing = true) :
    envsOf c horizon fixing ≠ [] := by
  simp [envsOf, hvalid, assignmentsPattern_ne_nil]

theorem lookupAssoc_nil [BEq α] (key : α) :
    lookupAssoc (β := β) key [] = none := by
  rfl

theorem envFrom_head (src : Src) (value : Bool) (rest : List (Src × Bool)) :
    envFrom ((src, value) :: rest) src = value := by
  simp [envFrom, lookupAssoc]

theorem relevantSrcs_empty (horizon : Nat) :
    relevantSrcs { gates := #[] } horizon = [] := by
  simp [relevantSrcs]

theorem lookupAssoc_none_of_not_mem [BEq α] [LawfulBEq α]
    (key : α) (values : List (α × β))
    (h : key ∉ values.map Prod.fst) :
    lookupAssoc key values = none := by
  induction values with
  | nil => rfl
  | cons value values ih =>
      simp only [List.map_cons, List.mem_cons, not_or] at h
      simp [lookupAssoc, h.1, ih h.2]

theorem lookupAssoc_some_mem [BEq α] [LawfulBEq α]
    (key : α) (values : List (α × β)) (value : β)
    (h : lookupAssoc key values = some value) :
    (key, value) ∈ values := by
  induction values with
  | nil => simp [lookupAssoc] at h
  | cons entry values ih =>
      rcases entry with ⟨entryKey, entryValue⟩
      by_cases heq : key = entryKey
      · subst entryKey
        simp [lookupAssoc] at h
        subst entryValue
        simp
      · simp [lookupAssoc, heq] at h
        exact List.mem_cons_of_mem _ (ih h)

theorem lookupAssoc_some_of_mem_key [BEq α] [LawfulBEq α]
    (key : α) (values : List (α × β))
    (h : key ∈ values.map Prod.fst) :
    ∃ value, lookupAssoc key values = some value := by
  induction values with
  | nil => simp at h
  | cons entry values ih =>
      rcases entry with ⟨entryKey, entryValue⟩
      simp only [List.map_cons, Prod.fst, List.mem_cons] at h
      rcases h with heq | htail
      · subst entryKey
        exact ⟨entryValue, by simp [lookupAssoc]⟩
      · by_cases heq : key = entryKey
        · subst entryKey
          exact ⟨entryValue, by simp [lookupAssoc]⟩
        · obtain ⟨value, hvalue⟩ := ih htail
          exact ⟨value, by simpa [lookupAssoc, heq] using hvalue⟩

theorem envFrom_outside (key : Src) (values : List (Src × Bool))
    (h : key ∉ values.map Prod.fst) :
    envFrom values key = false := by
  simp [envFrom, lookupAssoc_none_of_not_mem key values h]

theorem eraseDups_nodup [BEq α] [LawfulBEq α] :
    ∀ values : List α, values.eraseDups.Nodup
  | [] => by simp
  | value :: values => by
      rw [List.eraseDups_cons]
      constructor
      · intro a ha heq
        subst a
        rw [List.mem_eraseDups] at ha
        simp at ha
      · exact eraseDups_nodup (values.filter fun other => !other == value)
termination_by values => values.length
decreasing_by
  exact Nat.lt_succ_of_le (List.length_filter_le _ _)

theorem assignments_keys (sources : List Src) (values : List (Src × Bool))
    (h : values ∈ assignments sources) :
    values.map Prod.fst = sources := by
  induction sources generalizing values with
  | nil =>
      simp [assignments] at h
      subst values
      rfl
  | cons src rest ih =>
      simp [assignments] at h
      rcases h with ⟨tail, htail, rfl | rfl⟩ <;>
        simp [ih tail htail]

theorem matchesPattern_lookup_iff (sources : List Src)
    (fixed values : List (Src × Bool))
    (hnodup : sources.Nodup) (hkeys : values.map Prod.fst = sources) :
    matchesPattern (sources.map fun src => lookupAssoc src fixed) values = true ↔
      ∀ src ∈ sources, ∀ bit,
        lookupAssoc src fixed = some bit → envFrom values src = bit := by
  induction sources generalizing values with
  | nil =>
      have hvalues : values = [] := by
        cases values <;> simp_all
      subst values
      simp [matchesPattern]
  | cons src rest ih =>
      cases values with
      | nil => simp at hkeys
      | cons value values =>
          simp only [List.map_cons, Prod.fst] at hkeys
          have hsrc : value.1 = src := (List.cons.inj hkeys).1
          have hrest : values.map Prod.fst = rest := (List.cons.inj hkeys).2
          rcases value with ⟨key, bit⟩
          change key = src at hsrc
          subst key
          simp only [List.nodup_cons] at hnodup
          have htail := ih values hnodup.2 hrest
          have hlookup : lookupAssoc src values = none :=
            lookupAssoc_none_of_not_mem src values (by simpa [hrest] using hnodup.1)
          have hne : ∀ a ∈ rest, a ≠ src := by
            intro a ha heq
            subst a
            exact hnodup.1 ha
          have henvtail : ∀ a ∈ rest,
              envFrom ((src, bit) :: values) a = envFrom values a := by
            intro a ha
            simp [envFrom, lookupAssoc, hne a ha]
          cases hfixed : lookupAssoc src fixed with
          | none =>
              simp [matchesPattern, envFrom, lookupAssoc, hlookup, htail,
                hne, hfixed, henvtail]
              constructor <;> intro hall a ha <;>
                simpa [hne a ha] using hall a ha
          | some fixedBit =>
              cases fixedBit <;> cases bit <;>
                simp [matchesPattern, envFrom, lookupAssoc, hlookup, htail,
                  hne, hfixed, henvtail] <;>
                constructor <;> intro hall a ha <;>
                  simpa [hne a ha] using hall a ha

theorem matches_supportedFixing (sources : List Src)
    (fixing values : List (Src × Bool))
    (hnodup : sources.Nodup) (hkeys : values.map Prod.fst = sources)
    (hvalid : fixingValid sources fixing) :
    matchesPattern (sources.map fun src =>
      lookupAssoc src (supportedFixing sources fixing)) values =
      fixing.all fun (src, value) => envFrom values src == value := by
  rw [Bool.eq_iff_iff]
  rw [matchesPattern_lookup_iff sources _ values hnodup hkeys]
  simp only [List.all_eq_true, beq_iff_eq]
  have hvalid' : ∀ entry ∈ fixing,
      envFrom (supportedFixing sources fixing) entry.1 = entry.2 := by
    simpa [fixingValid] using hvalid
  constructor
  · intro hmatch entry hentry
    rcases entry with ⟨src, bit⟩
    by_cases hs : src ∈ sources
    · have hmem : (src, bit) ∈ supportedFixing sources fixing := by
        simp [supportedFixing, hentry, hs]
      obtain ⟨fixedBit, hlookup⟩ := lookupAssoc_some_of_mem_key src
        (supportedFixing sources fixing) (by
          exact List.mem_map.mpr ⟨(src, bit), hmem, rfl⟩)
      have heq : fixedBit = bit := by
        have := hvalid' (src, bit) hentry
        simp [envFrom, hlookup] at this
        exact this
      subst fixedBit
      exact hmatch src hs bit hlookup
    · have hout : envFrom values src = false := by
        apply envFrom_outside
        simpa [hkeys] using hs
      have hfixedNone : lookupAssoc src (supportedFixing sources fixing) = none := by
        apply lookupAssoc_none_of_not_mem
        simp [supportedFixing, hs]
      have hbit : bit = false := by
        have := hvalid' (src, bit) hentry
        simpa [envFrom, hfixedNone] using this.symm
      simpa [hbit] using hout
  · intro hall src hs bit hlookup
    have hmem := lookupAssoc_some_mem src
      (supportedFixing sources fixing) bit hlookup
    have hentry : (src, bit) ∈ fixing := by
      simp [supportedFixing] at hmem
      exact hmem.1
    exact hall (src, bit) hentry

theorem fixingValid_of_assignment (sources : List Src)
    (fixing values : List (Src × Bool))
    (hkeys : values.map Prod.fst = sources)
    (hall : fixing.all fun (src, value) => envFrom values src == value) :
    fixingValid sources fixing := by
  simp only [List.all_eq_true, beq_iff_eq] at hall
  simp only [fixingValid, List.all_eq_true, beq_iff_eq]
  intro entry hentry
  rcases entry with ⟨src, bit⟩
  by_cases hs : src ∈ sources
  · have hmem : (src, bit) ∈ supportedFixing sources fixing := by
      simp [supportedFixing, hentry, hs]
    obtain ⟨fixedBit, hlookup⟩ := lookupAssoc_some_of_mem_key src
      (supportedFixing sources fixing) (by
        exact List.mem_map.mpr ⟨(src, bit), hmem, rfl⟩)
    have hfixedMem := lookupAssoc_some_mem src
      (supportedFixing sources fixing) fixedBit hlookup
    have hfixedEntry : (src, fixedBit) ∈ fixing := by
      simp [supportedFixing] at hfixedMem
      exact hfixedMem.1
    have heq : fixedBit = bit := by
      have hbit := hall (src, bit) hentry
      have hfixed := hall (src, fixedBit) hfixedEntry
      exact hfixed.symm.trans hbit
    subst fixedBit
    simp [envFrom, hlookup]
  · have hout : envFrom values src = false := by
      apply envFrom_outside
      simpa [hkeys] using hs
    have hbit : bit = false := by
      exact (hall (src, bit) hentry).symm.trans hout
    have hnone : lookupAssoc src (supportedFixing sources fixing) = none := by
      apply lookupAssoc_none_of_not_mem
      simp [supportedFixing, hs]
    simp [envFrom, hnone, hbit]

theorem envsOf_eq_filtered (c : Circuit) (horizon : Nat)
    (fixing : List (Src × Bool)) :
    envsOf c horizon fixing = envsOfFiltered c horizon fixing := by
  classical
  let sources := relevantSrcs c horizon
  have hnodup : sources.Nodup := by
    exact eraseDups_nodup _
  change (if fixingValid sources fixing then
      List.map envFrom (assignmentsPattern sources
        (sources.map fun src => lookupAssoc src (supportedFixing sources fixing)))
    else []) =
      List.filter (fun env => fixing.all fun (src, value) => env src == value)
        (List.map envFrom (assignments sources))
  split <;> rename_i hvalid
  · rw [assignmentsPattern_eq_filter sources
      (sources.map fun src => lookupAssoc src (supportedFixing sources fixing)) (by simp)]
    rw [List.filter_map]
    apply congrArg (List.map envFrom)
    apply List.filter_congr
    intro values hvalues
    exact matches_supportedFixing sources fixing values hnodup
      (assignments_keys sources values hvalues) hvalid
  · generalize hresult : List.filter _ (List.map envFrom (assignments _)) = result
    cases result with
    | nil => rfl
    | cons env rest =>
        exfalso
        have henv : env ∈ env :: rest := by simp
        rw [← hresult] at henv
        simp only [List.mem_filter, List.mem_map] at henv
        rcases henv with ⟨⟨values, hvalues, rfl⟩, hall⟩
        exact hvalid (fixingValid_of_assignment sources fixing values
          (assignments_keys sources values hvalues) hall)

theorem eval_outside_horizon (c : Circuit) (horizon : Nat) (env : Env)
    (gate cycle : Nat) (hcycle : ¬ cycle < horizon) :
    eval c horizon env { gate := gate, cycle := cycle } = false := by
  simp [eval, hcycle]

namespace Tests

def xorRegCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (1, 0)] },
      { kind := .reg, inputs := [(2, 1)] }
    ] }

theorem xorRegCircuit_wf : xorRegCircuit.WF := by
  simp [xorRegCircuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

theorem eval_xor :
    eval xorRegCircuit 2
      (envFrom [(.inp 0 0 0, true), (.inp 0 1 0, false)])
      { gate := 2, cycle := 0 } = true := by
  rfl

theorem eval_register_boundary :
    eval xorRegCircuit 1 (envFrom [(.iniReg 3, true)])
      { gate := 3, cycle := 0 } = true := by
  rfl

theorem relevant_sources_covered :
    (.inp 0 0 0 ∈ relevantSrcs xorRegCircuit 1) ∧
    (.inp 0 1 0 ∈ relevantSrcs xorRegCircuit 1) ∧
    (.iniReg 3 ∈ relevantSrcs xorRegCircuit 1) := by
  decide +revert

theorem empty_fixing_enumerates_eight :
    (envsOf xorRegCircuit 1 []).length = 8 := by
  rfl

theorem one_fixed_source_enumerates_four :
    (envsOf xorRegCircuit 1 [(.inp 0 0 0, true)]).length = 4 := by
  rfl

theorem fixing_removes_one_free_source :
    freeSrcs (relevantSrcs xorRegCircuit 1) [(.inp 0 0 0, true)] =
      [.inp 0 1 0, .iniReg 3] := by
  rfl

theorem contradictory_fixing_is_empty :
    envsOf xorRegCircuit 1
      [(.inp 0 0 0, true), (.inp 0 0 0, false)] = [] := by
  rfl

def muxCtlCircuit : Circuit :=
  { gates := #[
      { kind := .ctl 0, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .const true, inputs := [] },
      { kind := .mux, inputs := [(0, 0), (1, 0), (2, 0)] }
    ] }

theorem muxCtlCircuit_wf : muxCtlCircuit.WF := by
  simp [muxCtlCircuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

theorem eval_mux_ctl_false :
    eval muxCtlCircuit 2 (envFrom [(.ctl 0 0, false)])
      { gate := 3, cycle := 0 } = false := by
  rfl

theorem eval_mux_ctl_true :
    eval muxCtlCircuit 2 (envFrom [(.ctl 0 1, true)])
      { gate := 3, cycle := 1 } = true := by
  rfl

theorem relevant_ctl_sources_covered :
    relevantSrcs muxCtlCircuit 2 = [.ctl 0 0, .ctl 0 1] := by
  rfl

end Tests

end Execution

export Execution (eval relevantSrcs envsOf)

end LeanSec
