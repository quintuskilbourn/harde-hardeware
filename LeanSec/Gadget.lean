import LeanSec.Expansion

namespace LeanSec

namespace Gadget

/-- A finite gadget execution and its experiment boundary.  `randomness` is the
exact list of source instances allowed to vary; every other relevant source not
named by `inputArrival` is pinned to zero. -/
structure GadgetInstance where
  circuit : Circuit
  horizon : Nat
  d : Nat
  inputCount : Nat
  inputArrival : Nat → Nat → Src
  output : Nat → Node
  member : Node → Bool
  randomness : List Src
  /-- Public source schedule, notably every cycle-indexed `ctl` instance. -/
  publicFixing : List (Src × Bool) := []

/-- Boolean vectors of an exact length. -/
def boolVectors : Nat → List (List Bool)
  | 0 => [[]]
  | n + 1 => (boolVectors n).flatMap fun xs => [false :: xs, true :: xs]

/-- All size-`k` sublists, without constructing a powerset. -/
def combinations : Nat → List α → List (List α)
  | 0, _ => [[]]
  | _ + 1, [] => []
  | k + 1, x :: xs =>
      (combinations k xs).map (x :: ·) ++ combinations (k + 1) xs

/-- All sublists of size at most `t`, generated one cardinality at a time. -/
def subsetsUpTo (t : Nat) (xs : List α) : List (List α) :=
  (List.range (t + 1)).flatMap fun k => combinations k xs

theorem combinations_length (k : Nat) (xs chosen : List α)
    (h : chosen ∈ combinations k xs) : chosen.length = k := by
  induction xs generalizing k chosen with
  | nil =>
      cases k with
      | zero => simpa [combinations] using h
      | succ k => simp [combinations] at h
  | cons x xs ih =>
      cases k with
      | zero => simpa [combinations] using h
      | succ k =>
          simp [combinations] at h
          rcases h with ⟨tail, htail, rfl⟩ | htail
          · simp [ih k tail htail]
          · exact ih (k + 1) chosen htail

theorem combinations_sublist (k : Nat) (xs chosen : List α)
    (h : chosen ∈ combinations k xs) : chosen.Sublist xs := by
  induction xs generalizing k chosen with
  | nil =>
      cases k with
      | zero =>
          have : chosen = [] := by simpa [combinations] using h
          subst chosen
          exact List.nil_sublist []
      | succ k => simp [combinations] at h
  | cons x xs ih =>
      cases k with
      | zero =>
          have : chosen = [] := by simpa [combinations] using h
          subst chosen
          exact List.nil_sublist _
      | succ k =>
          simp [combinations] at h
          rcases h with ⟨tail, htail, rfl⟩ | htail
          · exact (ih k tail htail).cons_cons x
          · exact (ih (k + 1) chosen htail).cons x

theorem mem_combinations_of_sublist {xs chosen : List α}
    (h : chosen.Sublist xs) : chosen ∈ combinations chosen.length xs := by
  induction xs generalizing chosen with
  | nil =>
      have : chosen = [] := List.sublist_nil.mp h
      subst chosen
      simp [combinations]
  | cons x xs ih =>
      cases chosen with
      | nil => simp [combinations]
      | cons y ys =>
          cases h
          · rename_i htail
            rw [List.length_cons, combinations]
            exact List.mem_append_right _ (ih htail)
          · rename_i htail
            exact List.mem_append_left _ (by
              simp only [List.mem_map]
              exact ⟨ys, ih htail, rfl⟩)

theorem subsetsUpTo_bound (t : Nat) (xs chosen : List α)
    (h : chosen ∈ subsetsUpTo t xs) : chosen.length ≤ t := by
  simp [subsetsUpTo] at h
  rcases h with ⟨k, hk, hchosen⟩
  rw [combinations_length k xs chosen hchosen]
  omega

theorem subsetsUpTo_sublist (t : Nat) (xs chosen : List α)
    (h : chosen ∈ subsetsUpTo t xs) : chosen.Sublist xs := by
  simp [subsetsUpTo] at h
  rcases h with ⟨k, _, hchosen⟩
  exact combinations_sublist k xs chosen hchosen

theorem mem_subsetsUpTo_of_sublist {t : Nat} {xs chosen : List α}
    (hsub : chosen.Sublist xs) (hlen : chosen.length ≤ t) :
    chosen ∈ subsetsUpTo t xs := by
  simp only [subsetsUpTo, List.mem_flatMap, List.mem_range]
  exact ⟨chosen.length, Nat.lt_succ_of_le hlen,
    mem_combinations_of_sublist hsub⟩

def nodes (g : GadgetInstance) : List Node :=
  (List.range g.horizon).flatMap fun cycle =>
    (List.range g.circuit.gates.size).map fun gate => { gate, cycle }

def memberNodes (g : GadgetInstance) : List Node :=
  (nodes g).filter g.member

def outputNodes (g : GadgetInstance) : List Node :=
  (List.range g.d).map g.output

def internalNodes (g : GadgetInstance) : List Node :=
  (memberNodes g).filter fun n => !(outputNodes g).contains n

/-- The same-cycle latency-zero predecessors whose values can be exposed by a
glitch expansion of `n`. -/
def combInputNodes (g : GadgetInstance) (n : Node) : List Node :=
  match g.circuit.gates[n.gate]? with
  | none => []
  | some gate =>
      (gate.inputs.filter (fun input => input.2 == 0)).map fun input =>
        { gate := input.1, cycle := n.cycle }

/-- The previous-cycle source nodes of a member register load: for a node
`(g, c+1)` whose gate has a latency-1 input `src`, the value the register
presents at cycle `c+1` is `src`'s value at cycle `c`, which is what a
transition-extended probe of the register wire exposes.  Membership must be
closed under this relation or a hand-curated member whitelist can silently
unschedule the producer of a scheduled register load (audit finding F1).  At
cycle 0 a register reads the pre-horizon `iniReg` source pinned by the
experiment, so no predecessor node is demanded. -/
def transInputNodes (g : GadgetInstance) (n : Node) : List Node :=
  match g.circuit.gates[n.gate]?, n.cycle with
  | some gate, cycle + 1 =>
      (gate.inputs.filter (fun input => input.2 == 1)).map fun input =>
        { gate := input.1, cycle := cycle }
  | _, _ => []

/-- Structural and boundary well-formedness required by the PINI predicates.
Outputs must be distinct in-window members, and membership must be closed
under (a) same-cycle combinational predecessors, so glitch expansion cannot
erase a boundary wire, and (b) previous-cycle register sources
(`transInputNodes`), so the transition half of a `transitionGlitch` probe on
a register cannot silently point outside the member boundary.

Note the residual gap (documented, not closed here): `expandedNodes` also
introduces the same-gate previous-cycle companion `(g, c−1)` of EVERY probed
member, and filters it through `g.member`; the curated schedules do not (and
by design cannot cheaply) contain every such companion, so a dropped
companion is sound only when its value is environment-independent.  The
fully sufficient structural condition is membership closure under the whole
expansion scheme (`member := fun _ => true` over the window realizes it);
positive whole-circuit probing anchors should therefore be stated as
`probingSecureWF` below so that at least this decidable boundary guard is
checked rather than trusted. -/
def GadgetInstance.WF (g : GadgetInstance) : Prop :=
  g.circuit.WF ∧
  g.d > 0 ∧
  (outputNodes g).Nodup ∧
  (outputNodes g).all (memberNodes g).contains = true ∧
  ((memberNodes g).flatMap (combInputNodes g)).all
    (memberNodes g).contains = true ∧
  ((memberNodes g).flatMap (transInputNodes g)).all
    (memberNodes g).contains = true

instance (g : GadgetInstance) : Decidable g.WF := by
  unfold GadgetInstance.WF
  infer_instance

/-- Canonical split of a probe list into non-output and output probes. -/
def internalProbePart (g : GadgetInstance) (probes : List Node) : List Node :=
  probes.filter fun n => !(outputNodes g).contains n

def outputProbePart (g : GadgetInstance) (probes : List Node) : List Node :=
  probes.filter fun n => (outputNodes g).contains n

/-- Canonical share indexes of the output nodes present in a probe set. -/
def outputSharePart (g : GadgetInstance) (probes : List Node) : List Nat :=
  (List.range g.d).filter fun share => probes.contains (g.output share)

theorem probeParts_perm (g : GadgetInstance) (probes : List Node) :
    (internalProbePart g probes ++ outputProbePart g probes).Perm probes := by
  simpa [internalProbePart, outputProbePart] using
    List.filter_append_perm (fun n => !(outputNodes g).contains n) probes

theorem probeParts_length (g : GadgetInstance) (probes : List Node) :
    (internalProbePart g probes).length +
      (outputProbePart g probes).length = probes.length := by
  simpa [List.length_append] using (probeParts_perm g probes).length_eq

theorem outputNodes_nodup (g : GadgetInstance)
    (hinj : ∀ i j, i < g.d → j < g.d →
      g.output i = g.output j → i = j) :
    (outputNodes g).Nodup := by
  unfold outputNodes
  change List.Pairwise (fun x y : Node => x ≠ y)
    (List.map g.output (List.range g.d))
  rw [List.pairwise_map]
  exact List.nodup_range.imp_of_mem
    (fun hi hj hne heq =>
      hne (hinj _ _ (by simpa using hi) (by simpa using hj) heq))

theorem outputSharePart_map_perm (g : GadgetInstance) (probes : List Node)
    (hprobes : probes.Nodup)
    (hinj : ∀ i j, i < g.d → j < g.d →
      g.output i = g.output j → i = j) :
    ((outputSharePart g probes).map g.output).Perm
      (outputProbePart g probes) := by
  have hleft : ((outputSharePart g probes).map g.output).Nodup := by
    change List.Pairwise (fun x y : Node => x ≠ y)
      (List.map g.output (outputSharePart g probes))
    rw [List.pairwise_map]
    exact (List.nodup_range.filter _).imp_of_mem
      (fun hi hj hne heq => hne (hinj _ _
        (by have := (List.mem_filter.mp hi).1; simpa using this)
        (by have := (List.mem_filter.mp hj).1; simpa using this) heq))
  have hright : (outputProbePart g probes).Nodup := hprobes.filter _
  rw [List.perm_iff_count]
  intro node
  rw [hleft.count, hright.count]
  congr 1
  simp only [outputSharePart, outputProbePart, List.mem_map,
    List.mem_filter, List.mem_range, List.contains_iff_mem]
  apply propext
  constructor
  · rintro ⟨share, hshare, heq⟩
    rcases hshare with ⟨hbound, hprobe⟩
    subst node
    refine ⟨by simpa using hprobe, ?_⟩
    simp only [outputNodes, List.mem_map, List.mem_range]
    exact ⟨share, hbound, rfl⟩
  · rintro ⟨hprobe, houtput⟩
    simp only [outputNodes, List.mem_map, List.mem_range] at houtput
    rcases houtput with ⟨share, hbound, heq⟩
    exact ⟨share, ⟨hbound, by simpa [heq] using hprobe⟩, heq⟩

theorem nodeRow_nodup (gateCount cycle : Nat) :
    ((List.range gateCount).map fun gate => ({ gate, cycle } : Node)).Nodup := by
  induction gateCount with
  | zero => simp
  | succ n ih =>
      rw [List.range_succ, List.map_append, List.nodup_append]
      simp only [List.map_singleton]
      refine ⟨ih, by simp, ?_⟩
      intro node hrow last hlast
      simp only [List.mem_singleton] at hlast
      subst last
      intro heq
      simp only [List.mem_map, List.mem_range] at hrow
      rcases hrow with ⟨gate, hgate, rfl⟩
      have : gate = n := congrArg Node.gate heq
      omega

theorem nodeRows_nodup (gateCount : Nat) (cycles : List Nat)
    (hcycles : cycles.Nodup) :
    (cycles.flatMap fun cycle =>
      (List.range gateCount).map fun gate => ({ gate, cycle } : Node)).Nodup := by
  induction cycles with
  | nil => simp
  | cons cycle cycles ih =>
      have hc := List.nodup_cons.mp hcycles
      rw [List.flatMap_cons, List.nodup_append]
      refine ⟨nodeRow_nodup gateCount cycle, ih hc.2, ?_⟩
      intro node hrow other hrows hout
      simp only [List.mem_map, List.mem_range] at hrow
      rcases hrow with ⟨gate, _, rfl⟩
      simp at hrows
      rcases hrows with ⟨otherCycle, hotherCycle, otherGate, _, hmember⟩
      have hcycle : otherCycle = cycle :=
        congrArg Node.cycle (hmember.trans hout.symm)
      exact hc.1 (hcycle ▸ hotherCycle)

theorem nodes_nodup (g : GadgetInstance) : (nodes g).Nodup := by
  exact nodeRows_nodup g.circuit.gates.size (List.range g.horizon)
    List.nodup_range

theorem memberNodes_nodup (g : GadgetInstance) : (memberNodes g).Nodup := by
  exact (nodes_nodup g).filter _

def inputWidth (g : GadgetInstance) : Nat := g.inputCount * g.d

def inputPosition (g : GadgetInstance) (sharing share : Nat) : Nat :=
  sharing * g.d + share

def inputBit (g : GadgetInstance) (x : List Bool)
    (sharing share : Nat) : Bool :=
  x.getD (inputPosition g sharing share) false

def arrivalValue? (g : GadgetInstance) (x : List Bool) (src : Src) : Option Bool :=
  ((List.range g.inputCount).flatMap fun sharing =>
    (List.range g.d).map fun share =>
      (g.inputArrival sharing share, inputBit g x sharing share))
    |> Execution.lookupAssoc src

/-- Complete statement-level fixing for a full input-share valuation. -/
def fixingForInput (g : GadgetInstance) (x : List Bool) : List (Src × Bool) :=
  (relevantSrcs g.circuit g.horizon).filterMap fun src =>
    match arrivalValue? g x src with
    | some bit => some (src, bit)
    | none =>
        match Execution.lookupAssoc src g.publicFixing with
        | some bit => some (src, bit)
        | none => if g.randomness.contains src then none else some (src, false)

def envsForInput (g : GadgetInstance) (x : List Bool) : List Env :=
  envsOf g.circuit g.horizon (fixingForInput g x)

theorem lookupAssoc_isSome_eq_contains [BEq α] [LawfulBEq α]
    (key : α) (values : List (α × β)) :
    (Execution.lookupAssoc key values).isSome =
      (values.map Prod.fst).contains key := by
  induction values with
  | nil => rfl
  | cons value values ih =>
      rcases value with ⟨entryKey, entryValue⟩
      by_cases h : key = entryKey
      · subst entryKey
        simp [Execution.lookupAssoc]
      · simp [Execution.lookupAssoc, h, ih]

theorem arrivalValue_isSome (g : GadgetInstance) (x : List Bool) (src : Src) :
    (arrivalValue? g x src).isSome =
      (((List.range g.inputCount).flatMap fun sharing =>
        (List.range g.d).map fun share => g.inputArrival sharing share).contains src) := by
  rw [arrivalValue?]
  rw [lookupAssoc_isSome_eq_contains]
  congr 1
  simp [List.map_flatMap, Function.comp_def]

theorem fixingForInput_keys (g : GadgetInstance) (x : List Bool) :
    (fixingForInput g x).map Prod.fst =
      (relevantSrcs g.circuit g.horizon).filter fun src =>
        (arrivalValue? g x src).isSome ||
          (Execution.lookupAssoc src g.publicFixing).isSome ||
          !(g.randomness.contains src) := by
  unfold fixingForInput
  generalize relevantSrcs g.circuit g.horizon = sources
  induction sources with
  | nil => rfl
  | cons src sources ih =>
      simp only [List.filterMap_cons, List.filter_cons]
      cases hinput : arrivalValue? g x src with
      | some bit =>
          simp only [Option.isSome_some, Bool.true_or, ite_true, List.map_cons]
          exact congrArg (src :: ·) ih
      | none =>
          simp only [Option.isSome_none, Bool.false_or]
          cases hpublic : Execution.lookupAssoc src g.publicFixing with
          | some bit =>
              simp only [Option.isSome_some, Bool.true_or, ite_true, List.map_cons]
              exact congrArg (src :: ·) ih
          | none =>
              simp only [Option.isSome_none, Bool.false_or]
              cases hrandom : g.randomness.contains src
              · simp only [Bool.not_false, ite_true]
                exact congrArg (src :: ·) ih
              · simp only [Bool.not_true]
                exact ih

theorem fixingForInput_keys_eq (g : GadgetInstance) (x y : List Bool) :
    (fixingForInput g x).map Prod.fst =
      (fixingForInput g y).map Prod.fst := by
  rw [fixingForInput_keys, fixingForInput_keys]
  apply List.filter_congr
  intro src _
  rw [arrivalValue_isSome, arrivalValue_isSome]

theorem lookupAssoc_eq_of_mem_nodup [BEq α] [LawfulBEq α]
    (key : α) (value : β) (values : List (α × β))
    (hmem : (key, value) ∈ values) (hnodup : (values.map Prod.fst).Nodup) :
    Execution.lookupAssoc key values = some value := by
  induction values with
  | nil => simp at hmem
  | cons entry values ih =>
      rcases entry with ⟨entryKey, entryValue⟩
      simp only [List.map_cons, List.nodup_cons] at hnodup
      simp only [List.mem_cons] at hmem
      rcases hmem with hhead | htail
      · cases hhead
        simp [Execution.lookupAssoc]
      · have hne : key ≠ entryKey := by
          intro heq
          subst entryKey
          exact hnodup.1 (List.mem_map.mpr ⟨(key, value), htail, rfl⟩)
        simpa [Execution.lookupAssoc, hne] using ih htail hnodup.2

theorem supportedFixing_fixingForInput (g : GadgetInstance) (x : List Bool) :
    Execution.supportedFixing (relevantSrcs g.circuit g.horizon)
      (fixingForInput g x) = fixingForInput g x := by
  apply List.filter_eq_self.mpr
  intro entry hentry
  have hkey : entry.1 ∈ (fixingForInput g x).map Prod.fst :=
    List.mem_map.mpr ⟨entry, hentry, rfl⟩
  rw [fixingForInput_keys] at hkey
  simpa [Execution.supportedFixing] using (List.mem_filter.mp hkey).1

theorem fixingForInput_valid (g : GadgetInstance) (x : List Bool) :
    Execution.fixingValid (relevantSrcs g.circuit g.horizon)
      (fixingForInput g x) = true := by
  let sources := relevantSrcs g.circuit g.horizon
  let fixing := fixingForInput g x
  have hkeys : fixing.map Prod.fst = sources.filter fun src =>
      (arrivalValue? g x src).isSome ||
        (Execution.lookupAssoc src g.publicFixing).isSome ||
        !(g.randomness.contains src) := fixingForInput_keys g x
  have hfixed : Execution.supportedFixing sources fixing = fixing :=
    supportedFixing_fixingForInput g x
  have hnodup : (fixing.map Prod.fst).Nodup := by
    rw [hkeys]
    exact (Execution.eraseDups_nodup _).filter _
  change Execution.fixingValid sources fixing = true
  simp only [Execution.fixingValid, hfixed, List.all_eq_true, beq_iff_eq]
  intro entry hentry
  rcases entry with ⟨src, bit⟩
  change Execution.envFrom fixing src = bit
  simp [Execution.envFrom,
    lookupAssoc_eq_of_mem_nodup src bit fixing hentry hnodup]

theorem sum_map_two (xs : List α) :
    (xs.map fun _ => 2).sum = 2 * xs.length := by
  induction xs with
  | nil => rfl
  | cons _ xs ih => simp [ih, Nat.mul_add, Nat.add_comm]

theorem assignmentsPattern_length_eq_of_isSome
    (sources : List Src) (left right : List (Option Bool))
    (hshape : left.map Option.isSome = right.map Option.isSome) :
    (Execution.assignmentsPattern sources left).length =
      (Execution.assignmentsPattern sources right).length := by
  induction sources generalizing left right with
  | nil => rfl
  | cons src sources ih =>
      cases left with
      | nil =>
          cases right with
          | nil => rfl
          | cons expected right => simp at hshape
      | cons expectedLeft left =>
          cases right with
          | nil => simp at hshape
          | cons expectedRight right =>
              simp only [List.map_cons, List.cons.injEq] at hshape
              rcases hshape with ⟨hhead, htail⟩
              cases expectedLeft <;> cases expectedRight <;>
                simp_all [Execution.assignmentsPattern,
                  ih left right htail, List.length_flatMap, sum_map_two]

theorem envsForInput_cardinality (g : GadgetInstance) (x y : List Bool) :
    (envsForInput g x).length = (envsForInput g y).length := by
  let sources := relevantSrcs g.circuit g.horizon
  let fixingX := fixingForInput g x
  let fixingY := fixingForInput g y
  have hvalidX : Execution.fixingValid sources fixingX = true :=
    fixingForInput_valid g x
  have hvalidY : Execution.fixingValid sources fixingY = true :=
    fixingForInput_valid g y
  have hvalidX' : Execution.fixingValid
      (relevantSrcs g.circuit g.horizon) fixingX = true := by
    simpa only [sources] using hvalidX
  have hvalidY' : Execution.fixingValid
      (relevantSrcs g.circuit g.horizon) fixingY = true := by
    simpa only [sources] using hvalidY
  have hkeys : fixingX.map Prod.fst = fixingY.map Prod.fst :=
    fixingForInput_keys_eq g x y
  have hfixedKeys :
      (Execution.supportedFixing sources fixingX).map Prod.fst =
        (Execution.supportedFixing sources fixingY).map Prod.fst := by
    rw [show Execution.supportedFixing sources fixingX = fixingX from
      supportedFixing_fixingForInput g x]
    rw [show Execution.supportedFixing sources fixingY = fixingY from
      supportedFixing_fixingForInput g y]
    exact hkeys
  have hshape :
      (sources.map fun src => Execution.lookupAssoc src
        (Execution.supportedFixing sources fixingX)).map Option.isSome =
      (sources.map fun src => Execution.lookupAssoc src
        (Execution.supportedFixing sources fixingY)).map Option.isSome := by
    simp only [List.map_map]
    apply List.map_congr_left
    intro src _
    simp only [Function.comp_apply, lookupAssoc_isSome_eq_contains, hfixedKeys]
  change (Execution.envsOf g.circuit g.horizon fixingX).length =
    (Execution.envsOf g.circuit g.horizon fixingY).length
  simp only [Execution.envsOf, hvalidX', hvalidY', if_pos, List.length_map]
  exact assignmentsPattern_length_eq_of_isSome sources _ _ hshape

def xorList : List Bool → Bool := List.foldl (fun a b => a != b) false

theorem mem_boolVectors_iff (n : Nat) (x : List Bool) :
    x ∈ boolVectors n ↔ x.length = n := by
  induction n generalizing x with
  | zero => simp [boolVectors]
  | succ n ih =>
      constructor
      · intro hx
        simp [boolVectors] at hx
        rcases hx with ⟨tail, htail, rfl | rfl⟩ <;>
          simp [(ih tail).mp htail]
      · intro hlen
        cases x with
        | nil => simp at hlen
        | cons bit tail =>
            have htail : tail.length = n := by simpa using hlen
            cases bit <;> simp [boolVectors, (ih tail).2 htail]

/-- Flip one coordinate.  Outside the list support this is the identity. -/
def toggleAt (i : Nat) (x : List Bool) : List Bool :=
  x.set i (!(x.getD i false))

theorem toggleAt_length (i : Nat) (x : List Bool) :
    (toggleAt i x).length = x.length := by
  simp [toggleAt]

theorem getD_toggleAt_ne (x : List Bool) (i j : Nat) (hne : i ≠ j) :
    (toggleAt i x).getD j false = x.getD j false := by
  simp [toggleAt, List.getD_eq_getElem?_getD, hne]

theorem toggleAt_involutive (x : List Bool) (i : Nat) :
    toggleAt i (toggleAt i x) = x := by
  apply List.ext_getElem?
  intro j
  by_cases hi : i < x.length
  · by_cases hji : j = i
    · subst j
      simp [toggleAt, List.getD_eq_getElem?_getD, hi]
    · have hin : i ≠ j := Ne.symm hji
      simp [toggleAt, List.getD_eq_getElem?_getD, hi]
  · have hset : x.set i true = x := by
      apply List.ext_getElem?
      intro k
      simp only [List.getElem?_set]
      split
      · rename_i hik
        subst k
        simp [hi]
      · rfl
    simpa [toggleAt, List.getD_eq_getElem?_getD, hi, hset]

theorem foldl_xor (acc : Bool) (xs : List Bool) :
    xs.foldl (fun a b => a != b) acc = (acc != xorList xs) := by
  have hassoc : Std.Associative (fun a b : Bool => a != b) := by
    constructor
    intro a b c
    cases a <;> cases b <;> cases c <;> rfl
  have h := @List.foldl_assoc Bool (fun a b => a != b) hassoc xs acc false
  simpa [xorList] using h

theorem xorList_cons (b : Bool) (xs : List Bool) :
    xorList (b :: xs) = (b != xorList xs) := by
  simp only [xorList, List.foldl_cons]
  rw [foldl_xor]
  change ((false != b) != xorList xs) = (b != xorList xs)
  cases b <;> rfl

theorem xorList_toggleAt (x : List Bool) (i : Nat) (hi : i < x.length) :
    xorList (toggleAt i x) = !(xorList x) := by
  induction x generalizing i with
  | nil => simp at hi
  | cons b xs ih =>
      cases i with
      | zero =>
          change xorList ((!b) :: xs) = !(xorList (b :: xs))
          rw [xorList_cons, xorList_cons]
          cases b <;> cases xorList xs <;> rfl
      | succ i =>
          have hi' : i < xs.length := by simpa using hi
          change xorList (b :: toggleAt i xs) = !xorList (b :: xs)
          rw [xorList_cons, xorList_cons, ih i hi']
          cases b <;> cases xorList xs <;> rfl

def selectBits (shares : List Nat) (x : List Bool) : List Bool :=
  shares.map fun share => x.getD share false

theorem selectBits_toggleAt (shares : List Nat) (x : List Bool) (i : Nat)
    (hi : i ∉ shares) : selectBits shares (toggleAt i x) = selectBits shares x := by
  apply List.map_congr_left
  intro j hj
  exact getD_toggleAt_ne x i j (by
    intro heq
    exact hi (heq ▸ hj))

theorem boolVectors_nodup (n : Nat) : (boolVectors n).Nodup := by
  induction n with
  | zero => simp [boolVectors]
  | succ n ih =>
      change List.Pairwise (fun a b : List Bool => a ≠ b)
        ((boolVectors n).flatMap fun xs => [false :: xs, true :: xs])
      rw [List.pairwise_flatMap]
      constructor
      · intro x hx
        simp
      · apply ih.imp
        intro x y hxy a ha b hb
        simp at ha hb
        rcases ha with rfl | rfl <;> rcases hb with rfl | rfl
        · intro heq; exact hxy (List.cons.inj heq).2
        · simp
        · simp
        · intro heq; exact hxy (List.cons.inj heq).2

theorem toggleAt_boolVectors_perm (n i : Nat) :
    ((boolVectors n).map (toggleAt i)).Perm (boolVectors n) := by
  have hnodup := boolVectors_nodup n
  have hmapNodup : ((boolVectors n).map (toggleAt i)).Nodup := by
    change List.Pairwise (fun x y : List Bool => x ≠ y)
      ((boolVectors n).map (toggleAt i))
    rw [List.pairwise_map]
    apply hnodup.imp
    intro x y hxy heq
    apply hxy
    calc
      x = toggleAt i (toggleAt i x) := (toggleAt_involutive x i).symm
      _ = toggleAt i (toggleAt i y) := by rw [heq]
      _ = y := toggleAt_involutive y i
  apply List.perm_iff_count.mpr
  intro x
  rw [hmapNodup.count, hnodup.count]
  congr 1
  simp only [List.mem_map]
  apply propext
  constructor
  · rintro ⟨y, hy, rfl⟩
    rw [mem_boolVectors_iff] at hy ⊢
    exact toggleAt_length i y |>.trans hy
  · intro hx
    refine ⟨toggleAt i x, ?_, toggleAt_involutive x i⟩
    rw [mem_boolVectors_iff] at hx ⊢
    exact toggleAt_length i x |>.trans hx

def sharingFiber (d : Nat) (secret : Bool) (shares : List Nat)
    (q : List Bool) : List (List Bool) :=
  (boolVectors d).filter fun x =>
    xorList x == secret && selectBits shares x == q

theorem sharingFiber_toggle_perm (d i : Nat) (hi : i < d)
    (shares : List Nat) (hmissing : i ∉ shares) (secret : Bool)
    (q : List Bool) :
    ((sharingFiber d secret shares q).map (toggleAt i)).Perm
      (sharingFiber d (!secret) shares q) := by
  have hp := (toggleAt_boolVectors_perm d i).filter fun x =>
    xorList x == !secret && selectBits shares x == q
  rw [List.filter_map] at hp
  have hfilter :
      (boolVectors d).filter
          ((fun x => xorList x == !secret && selectBits shares x == q) ∘
            toggleAt i) = sharingFiber d secret shares q := by
    apply List.filter_congr
    intro x hx
    have hxlen := (mem_boolVectors_iff d x).mp hx
    simp only [Function.comp_apply]
    rw [xorList_toggleAt x i (hxlen ▸ hi),
      selectBits_toggleAt shares x i hmissing]
    cases secret <;> cases xorList x <;> simp
  rw [hfilter] at hp
  exact hp

/-- Fewer than `d` selected shares of an XOR sharing have the same projection
multiset for either secret.  The proof explicitly toggles one absent share, so
it does not rely on a cardinality formula or an unproved uniformity premise. -/
theorem xorSharing_secret_independent (d : Nat) (shares : List Nat)
    (hshares : shares.Sublist (List.range d)) (hsmall : shares.length < d)
    (q : List Bool) :
    (sharingFiber d false shares q).length =
      (sharingFiber d true shares q).length := by
  have hmissing : ∃ i ∈ List.range d, i ∉ shares := by
    by_cases h : ∃ i ∈ List.range d, i ∉ shares
    · exact h
    · exfalso
      have hall : ∀ i ∈ List.range d, i ∈ shares := by
        intro i hi
        by_cases him : i ∈ shares
        · exact him
        · exact (h ⟨i, hi, him⟩).elim
      have hsnodup : shares.Nodup := hshares.nodup List.nodup_range
      have hp : shares.Perm (List.range d) := by
        apply List.perm_iff_count.mpr
        intro i
        rw [hsnodup.count, List.nodup_range.count]
        have hiff : i ∈ shares ↔ i ∈ List.range d := by
          exact ⟨fun hi => hshares.mem hi, hall i⟩
        simp [hiff]
      have := hp.length_eq
      simp at this
      omega
  rcases hmissing with ⟨i, hi, himissing⟩
  have hp := sharingFiber_toggle_perm d i (by simpa using hi)
    shares himissing false q
  simpa using hp.length_eq

def sharingSecret (g : GadgetInstance) (x : List Bool) (sharing : Nat) : Bool :=
  xorList ((List.range g.d).map fun share => inputBit g x sharing share)

def secretsOf (g : GadgetInstance) (x : List Bool) : List Bool :=
  (List.range g.inputCount).map (sharingSecret g x)

/-- The unshared result expected from the single-output multiplication gadgets
in this phase.  The supported gadget shape has exactly two input sharings. -/
def productSecret (g : GadgetInstance) (x : List Bool) : Bool :=
  (secretsOf g x).getD 0 false && (secretsOf g x).getD 1 false

/-- Every `d`-share encoding of the correct multiplication result. -/
def idealOutputSharings (g : GadgetInstance) (x : List Bool) :
    List Observation :=
  (boolVectors g.d).filter fun output =>
    xorList output == productSecret g x

def envsForSecret (g : GadgetInstance) (secret : List Bool) : List Env :=
  (boolVectors (inputWidth g)).filter (fun x => secretsOf g x == secret)
    |>.flatMap (envsForInput g)

theorem envsForInput_ne_nil_of_valid (g : GadgetInstance) (x : List Bool)
    (hvalid : Execution.fixingValid
      (relevantSrcs g.circuit g.horizon) (fixingForInput g x) = true) :
    envsForInput g x ≠ [] := by
  exact Execution.envsOf_ne_nil_of_valid _ _ _ hvalid

theorem envsForSecret_ne_nil_of_input (g : GadgetInstance)
    (secret x : List Bool) (hx : x ∈ boolVectors (inputWidth g))
    (hsecret : secretsOf g x = secret) (henvs : envsForInput g x ≠ []) :
    envsForSecret g secret ≠ [] := by
  have hx' : x ∈ (boolVectors (inputWidth g)).filter
      (fun y => secretsOf g y == secret) := by
    simp [hx, hsecret]
  cases h : envsForInput g x with
  | nil => exact (henvs h).elim
  | cons env envs =>
      intro hempty
      have : env ∈ envsForSecret g secret := by
        simp only [envsForSecret, List.mem_flatMap]
        exact ⟨x, hx', by simp [h]⟩
      simpa [hempty] using this

def expandedNodes (g : GadgetInstance) (scheme : ExpansionScheme)
    (probes : List Node) : List Node :=
  (probes.flatMap (scheme g.circuit g.horizon)).filter g.member |>.eraseDups

theorem eraseDups_nodup [BEq α] [LawfulBEq α] (xs : List α) :
    xs.eraseDups.Nodup := by
  cases xs with
  | nil => simp
  | cons x xs =>
      rw [List.eraseDups_cons, List.nodup_cons]
      constructor
      · simp [List.mem_eraseDups]
      · exact eraseDups_nodup _
termination_by xs.length
decreasing_by
  exact Nat.lt_succ_of_le (List.length_filter_le _ _)

theorem eraseDups_length_le [BEq α] [LawfulBEq α] (xs : List α) :
    xs.eraseDups.length ≤ xs.length := by
  cases xs with
  | nil => simp
  | cons x xs =>
      rw [List.eraseDups_cons]
      have hrec := eraseDups_length_le (xs.filter fun a => a != x)
      have hfilter := List.length_filter_le (fun a => a != x) xs
      simp only [List.length_cons]
      exact Nat.succ_le_succ (Nat.le_trans hrec hfilter)
termination_by xs.length
decreasing_by
  exact Nat.lt_succ_of_le (List.length_filter_le _ _)

/-- The secret-independence argument only needs every selected index to be in
range; repeated indexes do not reveal additional shares. -/
theorem xorSharing_secret_independent_mem (d : Nat) (shares : List Nat)
    (hshares : ∀ i ∈ shares, i < d) (hsmall : shares.length < d)
    (q : List Bool) :
    (sharingFiber d false shares q).length =
      (sharingFiber d true shares q).length := by
  have hmissing : ∃ i ∈ List.range d, i ∉ shares := by
    by_cases h : ∃ i ∈ List.range d, i ∉ shares
    · exact h
    · exfalso
      have hall : ∀ i ∈ List.range d, i ∈ shares := by
        intro i hi
        by_cases him : i ∈ shares
        · exact him
        · exact (h ⟨i, hi, him⟩).elim
      have hp : shares.eraseDups.Perm (List.range d) := by
        rw [List.perm_iff_count]
        intro i
        rw [(eraseDups_nodup shares).count, List.nodup_range.count]
        have hiff : i ∈ shares.eraseDups ↔ i ∈ List.range d := by
          simp only [List.mem_eraseDups]
          exact ⟨fun hi => by simpa using hshares i hi, hall i⟩
        simp [hiff]
      have hlength := hp.length_eq
      have hdedup := eraseDups_length_le shares
      simp only [List.length_range] at hlength
      omega
  rcases hmissing with ⟨i, hi, himissing⟩
  have hp := sharingFiber_toggle_perm d i (by simpa using hi)
    shares himissing false q
  simpa using hp.length_eq

theorem eraseDups_eq_self_of_nodup [BEq α] [LawfulBEq α]
    {xs : List α} (h : xs.Nodup) : xs.eraseDups = xs := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
      rw [List.eraseDups_cons]
      have hn := List.nodup_cons.mp h
      have hfilter : xs.filter (fun y => !y == x) = xs := by
        apply List.filter_eq_self.mpr
        intro y hy
        simp only [Bool.not_eq_true', beq_eq_false_iff_ne]
        intro heq
        exact hn.1 (heq ▸ hy)
      rw [hfilter, ih hn.2]

theorem expandedNodes_nodup (g : GadgetInstance) (scheme : ExpansionScheme)
    (probes : List Node) : (expandedNodes g scheme probes).Nodup := by
  exact eraseDups_nodup _

def observe (g : GadgetInstance) (ns : List Node) (env : Env) : Observation :=
  let values := Execution.evalEntries g.circuit g.horizon env
  ns.map fun node =>
    if node.gate < g.circuit.gates.size && node.cycle < g.horizon then
      (Execution.lookupAssoc node values).getD false
    else false

/-- Functional-correctness guard (the missing anti-vacuity gate): for EVERY input
valuation and EVERY randomness assignment, the gadget's output sharing recombines
(XOR of its shares) to `f (secretsOf x)`, the intended masked function of the
secrets.  Decidable and purely functional (`eval` only, no security enumeration),
so it is cheap even at chain scale.  A security proof on a functionally-dead
circuit (e.g. a serial execution stuck at 0) must fail this — it is mandatory
alongside every gadget's security anchors. -/
def recombinesTo (g : GadgetInstance) (f : List Bool → Bool) : Prop :=
  ∀ x ∈ boolVectors (inputWidth g), ∀ env ∈ envsForInput g x,
    xorList (observe g (outputNodes g) env) = f (secretsOf g x)

instance recombinesToDecidable (g : GadgetInstance) (f : List Bool → Bool) :
    Decidable (recombinesTo g f) := by
  unfold recombinesTo; infer_instance

theorem take_observe_eraseDups_append (g : GadgetInstance)
    (base extra : List Node) (env : Env) (hbase : base.Nodup) :
    (observe g ((base ++ extra).eraseDups) env).take base.length =
      observe g base env := by
  rw [List.eraseDups_append, eraseDups_eq_self_of_nodup hbase]
  simp [observe]

theorem observe_eq_map_eval (g : GadgetInstance) (ns : List Node) (env : Env) :
    observe g ns env = ns.map (eval g.circuit g.horizon env) := by
  simp [observe, eval]

theorem eraseDups_perm_of_perm [BEq α] [LawfulBEq α]
    {xs ys : List α} (h : xs.Perm ys) : xs.eraseDups.Perm ys.eraseDups := by
  apply List.perm_iff_count.mpr
  intro a
  rw [(eraseDups_nodup xs).count, (eraseDups_nodup ys).count]
  simp only [List.mem_eraseDups]
  by_cases ha : a ∈ xs
  · have hb : a ∈ ys := h.mem_iff.mp ha
    simp [ha, hb]
  · have hb : a ∉ ys := by
      intro hb
      exact ha (h.mem_iff.mpr hb)
    simp [ha, hb]

theorem expandedNodes_perm (g : GadgetInstance) (scheme : ExpansionScheme)
    {probes₁ probes₂ : List Node} (h : probes₁.Perm probes₂) :
    (expandedNodes g scheme probes₁).Perm
      (expandedNodes g scheme probes₂) := by
  apply eraseDups_perm_of_perm
  exact (h.flatMap_right (scheme g.circuit g.horizon)).filter g.member

/-- Reordering probe nodes induces one fixed reordering of every observation
tuple; the reordering is independent of the environment. -/
theorem observation_reorder_of_perm (g : GadgetInstance)
    {ns₁ ns₂ : List Node} (h : ns₁.Perm ns₂) :
    ∃ reorder : Observation → Observation,
      ∀ env, reorder (observe g ns₁ env) = observe g ns₂ env := by
  induction h with
  | nil =>
      exact ⟨fun _ => [], by intro env; simp [observe]⟩
  | cons node h ih =>
      rcases ih with ⟨reorder, hreorder⟩
      let keepHead : Observation → Observation
        | [] => []
        | bit :: bits => bit :: reorder bits
      refine ⟨keepHead, ?_⟩
      intro env
      change _ :: reorder (observe g _ env) = _ :: observe g _ env
      rw [hreorder env]
  | swap first second tail =>
      let swapHead : Observation → Observation
        | a :: b :: rest => b :: a :: rest
        | bits => bits
      exact ⟨swapHead, by intro env; simp [observe, swapHead]⟩
  | trans h₁ h₂ ih₁ ih₂ =>
      rcases ih₁ with ⟨reorder₁, hreorder₁⟩
      rcases ih₂ with ⟨reorder₂, hreorder₂⟩
      refine ⟨reorder₂ ∘ reorder₁, ?_⟩
      intro env
      simp only [Function.comp_apply, hreorder₁ env, hreorder₂ env]

def projection (g : GadgetInstance) (shares : List Nat)
    (x : List Bool) : List Bool :=
  (List.range g.inputCount).flatMap fun sharing =>
    shares.map fun share => inputBit g x sharing share

/-- Project a full input valuation onto independently selected shares of each
input sharing. -/
def projectionIxs (g : GadgetInstance) (shares : List ShareIx)
    (x : List Bool) : List Bool :=
  shares.map fun (sharing, share) => inputBit g x sharing share

/-- All input-share selections containing at most `bound` shares from each
input sharing.  The product is built one sharing at a time, while each factor
uses cardinality-directed combinations. -/
def inputShareSelections (g : GadgetInstance) (bound : Nat) :
    List (List ShareIx) :=
  (List.range g.inputCount).foldl (fun selections sharing =>
    selections.flatMap fun selected =>
      (subsetsUpTo bound (List.range g.d)).map fun shares =>
        selected ++ shares.map fun share => (sharing, share)) [[]]

/-- A cross-multiplied observation multiset. -/
def normalized (es₁ es₂ : List Env) (obs : Env → Observation) : List Observation :=
  (es₁.map obs).flatMap fun w => List.replicate es₂.length w

theorem count_normalized (es₁ es₂ : List Env) (obs : Env → Observation)
    (w : Observation) :
    (normalized es₁ es₂ obs).count w = es₂.length * countObs es₁ obs w := by
  induction es₁ with
  | nil => simp [normalized, countObs]
  | cons e es ih =>
      rw [show normalized (e :: es) es₂ obs =
        List.replicate es₂.length (obs e) ++ normalized es es₂ obs by rfl]
      rw [List.count_append, ih]
      by_cases h : obs e = w <;>
        simp [countObs, List.count_replicate, beq_iff_eq, h,
          Nat.mul_add, Nat.add_comm]

/-- Executable finite characterization of simulatability. -/
def CountInvariant (xs : List (List Bool)) (envsOf : List Bool → List Env)
    (projI : List Bool → List Bool) (obs : Env → Observation) : Prop :=
  ∀ x ∈ xs, ∀ y ∈ xs, projI x = projI y →
    distEq (envsOf x) (envsOf y) obs

theorem simulatable_iff_countInvariant
    (xs : List (List Bool)) (envsOf : List Bool → List Env)
    (projI : List Bool → List Bool) (obs : Env → Observation)
    (reached : ∀ x ∈ xs, (envsOf x).length > 0) :
    SimulatableOn xs envsOf projI obs ↔
      CountInvariant xs envsOf projI obs := by
  constructor
  · rintro ⟨S, hpositive, hsim⟩ x hx y hy hproj w
    have hxsim := hsim x hx w
    have hysim := hsim y hy w
    have hpos := hpositive x hx
    rw [← hproj] at hysim
    apply Nat.eq_of_mul_eq_mul_left hpos
    calc
      (S (projI x)).length *
          ((envsOf y).length * countObs (envsOf x) obs w) =
          (envsOf y).length *
            ((S (projI x)).length * countObs (envsOf x) obs w) := by
              simp [Nat.mul_assoc, Nat.mul_comm, Nat.mul_left_comm]
      _ = (envsOf y).length *
            ((envsOf x).length * (S (projI x)).count w) := by rw [hxsim]
      _ = (envsOf x).length *
            ((S (projI x)).length * countObs (envsOf y) obs w) := by
          rw [show (envsOf y).length *
              ((envsOf x).length * (S (projI x)).count w) =
              (envsOf x).length *
                ((envsOf y).length * (S (projI x)).count w) by
            simp [Nat.mul_assoc, Nat.mul_comm, Nat.mul_left_comm]]
          rw [← hysim]
      _ = (S (projI x)).length *
            ((envsOf x).length * countObs (envsOf y) obs w) := by
              simp [Nat.mul_assoc, Nat.mul_comm, Nat.mul_left_comm]
  · intro hinvariant
    classical
    let representative : List Bool → List Bool := fun q =>
      if h : ∃ x ∈ xs, projI x = q then Classical.choose h else []
    let S : List Bool → List Observation := fun q =>
      (envsOf (representative q)).map obs
    refine ⟨S, ?_, ?_⟩
    · intro x hx
      have hex : ∃ y ∈ xs, projI y = projI x := ⟨x, hx, rfl⟩
      have hmem : representative (projI x) ∈ xs := by
        simp [representative, hex, Classical.choose_spec hex]
      simpa [S] using reached _ hmem
    · intro x hx w
      have hex : ∃ y ∈ xs, projI y = projI x := ⟨x, hx, rfl⟩
      have hmem : representative (projI x) ∈ xs := by
        simp [representative, hex, Classical.choose_spec hex]
      have hproj : projI (representative (projI x)) = projI x := by
        simp [representative, hex, Classical.choose_spec hex]
      have hdist := hinvariant (representative (projI x)) hmem x hx hproj w
      simp only [S, List.length_map]
      change (envsOf (representative (projI x))).length *
          countObs (envsOf x) obs w =
        (envsOf x).length *
          (List.map obs (envsOf (representative (projI x)))).count w
      rw [List.count_eq_countP, List.countP_map]
      exact hdist.symm

theorem distEq_iff_perm (es₁ es₂ : List Env) (obs : Env → Observation) :
    distEq es₁ es₂ obs ↔
      (normalized es₁ es₂ obs).Perm (normalized es₂ es₁ obs) := by
  rw [List.perm_iff_count]
  simp only [distEq]
  constructor
  · intro h w
    simpa [count_normalized] using h w
  · intro h w
    simpa [count_normalized] using h w

theorem normalized_map (es₁ es₂ : List Env) (obs : Env → Observation)
    (f : Observation → Observation) :
    normalized es₁ es₂ (fun e => f (obs e)) =
      (normalized es₁ es₂ obs).map f := by
  induction es₁ with
  | nil => rfl
  | cons e es ih =>
      change List.replicate es₂.length (f (obs e)) ++
          normalized es es₂ (fun e => f (obs e)) =
        (List.replicate es₂.length (obs e) ++ normalized es es₂ obs).map f
      rw [ih]
      simp

/-- Deterministic post-processing preserves distribution equality. -/
theorem distEq_map {es₁ es₂ : List Env} {obs : Env → Observation}
    (f : Observation → Observation) (h : distEq es₁ es₂ obs) :
    distEq es₁ es₂ (fun e => f (obs e)) := by
  apply (distEq_iff_perm _ _ _).mpr
  rw [normalized_map, normalized_map]
  exact ((distEq_iff_perm _ _ _).mp h).map f

def scaleList (n : Nat) : List α → List α
  | [] => []
  | x :: xs => List.replicate n x ++ scaleList n xs

theorem count_scaleList [BEq α] [LawfulBEq α]
    (n : Nat) (xs : List α) (x : α) :
    (scaleList n xs).count x = n * xs.count x := by
  induction xs with
  | nil => simp [scaleList]
  | cons y ys ih =>
      simp only [scaleList, List.count_append, List.count_replicate, ih,
        List.count_cons]
      by_cases h : y = x <;> simp [h, Nat.mul_add, Nat.add_comm]

theorem scaleList_map (n : Nat) (xs : List α) (f : α → β) :
    scaleList n (xs.map f) = (scaleList n xs).map f := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
      simp [scaleList, ih]

/-- Simulatability is closed under deterministic restriction of observations. -/
theorem simulatableOn_map {xs : List (List Bool)}
    {envsOf : List Bool → List Env} {projI : List Bool → List Bool}
    {obs : Env → Observation} (f : Observation → Observation)
    (h : SimulatableOn xs envsOf projI obs) :
    SimulatableOn xs envsOf projI (fun e => f (obs e)) := by
  rcases h with ⟨S, hpositive, hsim⟩
  refine ⟨fun q => (S q).map f, ?_, ?_⟩
  · intro x hx
    simpa using hpositive x hx
  · intro x hx w
    have hp :
        (scaleList (S (projI x)).length ((envsOf x).map obs)).Perm
          (scaleList (envsOf x).length (S (projI x))) := by
      rw [List.perm_iff_count]
      intro v
      rw [count_scaleList, count_scaleList]
      simpa [List.count_eq_countP, List.countP_map, Function.comp_def,
        countObs] using hsim x hx v
    have hp' := hp.map f
    rw [← scaleList_map, ← scaleList_map] at hp'
    have hc := List.Perm.count hp' w
    rw [count_scaleList, count_scaleList] at hc
    simpa [List.length_map, List.count_eq_countP, List.countP_map,
      Function.comp_def, countObs] using hc

theorem simulatableOn_observe_perm (g : GadgetInstance)
    (xs : List (List Bool)) (envsOf : List Bool → List Env)
    (projI : List Bool → List Bool) {ns₁ ns₂ : List Node}
    (hperm : ns₁.Perm ns₂)
    (hsim : SimulatableOn xs envsOf projI (observe g ns₁)) :
    SimulatableOn xs envsOf projI (observe g ns₂) := by
  rcases observation_reorder_of_perm g hperm with ⟨reorder, hreorder⟩
  have hmapped := simulatableOn_map reorder hsim
  have hobs : (fun env => reorder (observe g ns₁ env)) = observe g ns₂ := by
    funext env
    exact hreorder env
  rw [hobs] at hmapped
  exact hmapped

/-- Finite support of the two observation distributions. -/
def observationSupport (es₁ es₂ : List Env)
    (obs : Env → Observation) : List Observation :=
  ((es₁.map obs) ++ (es₂.map obs)).eraseDups

/-- Check cross-multiplied counts only where either distribution has support. -/
def distEqSupportCheck (es₁ es₂ : List Env)
    (obs : Env → Observation) : Bool :=
  let samples₁ := es₁.map obs
  let samples₂ := es₂.map obs
  (samples₁ ++ samples₂).eraseDups.all fun w =>
    es₂.length * samples₁.count w ==
      es₁.length * samples₂.count w

theorem distEq_iff_supportCheck (es₁ es₂ : List Env)
    (obs : Env → Observation) :
    distEq es₁ es₂ obs ↔ distEqSupportCheck es₁ es₂ obs = true := by
  constructor
  · intro h
    simp only [distEqSupportCheck, List.all_eq_true, List.count_eq_countP,
      List.countP_map, Function.comp_def]
    intro w _
    simpa [countObs] using h w
  · intro h w
    simp only [distEqSupportCheck, List.all_eq_true, List.count_eq_countP,
      List.countP_map, Function.comp_def] at h
    by_cases hw : w ∈ observationSupport es₁ es₂ obs
    · simpa [countObs] using h w hw
    · have hw₁ : w ∉ es₁.map obs := by
        intro hmem
        apply hw
        simp [observationSupport, hmem]
      have hw₂ : w ∉ es₂.map obs := by
        intro hmem
        apply hw
        simp [observationSupport, hmem]
      have hc₁ : countObs es₁ obs w = 0 := by
        apply List.countP_eq_zero.mpr
        intro e he
        simp only [beq_iff_eq]
        intro heq
        apply hw₁
        exact List.mem_map.mpr ⟨e, he, heq⟩
      have hc₂ : countObs es₂ obs w = 0 := by
        apply List.countP_eq_zero.mpr
        intro e he
        simp only [beq_iff_eq]
        intro heq
        apply hw₂
        exact List.mem_map.mpr ⟨e, he, heq⟩
      simp [hc₁, hc₂]

instance distEqDecidable (es₁ es₂ : List Env) (obs : Env → Observation) :
    Decidable (distEq es₁ es₂ obs) :=
  decidable_of_iff (distEqSupportCheck es₁ es₂ obs = true)
    (distEq_iff_supportCheck es₁ es₂ obs).symm

instance countInvariantDecidable
    (xs : List (List Bool)) (envsOf : List Bool → List Env)
    (projI : List Bool → List Bool) (obs : Env → Observation) :
    Decidable (CountInvariant xs envsOf projI obs) := by
  unfold CountInvariant
  infer_instance

theorem distEq_refl (es : List Env) (obs : Env → Observation) :
    distEq es es obs := by
  intro w
  rfl

theorem distEq_symm {es₁ es₂ : List Env} {obs : Env → Observation}
    (h : distEq es₁ es₂ obs) : distEq es₂ es₁ obs := by
  intro w
  exact (h w).symm

theorem distEq_trans {es₁ es₂ es₃ : List Env} {obs : Env → Observation}
    (h₁₂ : distEq es₁ es₂ obs) (h₂₃ : distEq es₂ es₃ obs)
    (hmiddle : es₂.length > 0) : distEq es₁ es₃ obs := by
  intro w
  apply Nat.eq_of_mul_eq_mul_left hmiddle
  calc
    es₂.length * (es₃.length * countObs es₁ obs w) =
        es₃.length * (es₂.length * countObs es₁ obs w) := by
          simp [Nat.mul_assoc, Nat.mul_comm, Nat.mul_left_comm]
    _ = es₃.length * (es₁.length * countObs es₂ obs w) := by
          rw [h₁₂ w]
    _ = es₁.length * (es₃.length * countObs es₂ obs w) := by
          simp [Nat.mul_assoc, Nat.mul_comm, Nat.mul_left_comm]
    _ = es₁.length * (es₂.length * countObs es₃ obs w) := by
          rw [h₂₃ w]
    _ = es₂.length * (es₁.length * countObs es₃ obs w) := by
          simp [Nat.mul_assoc, Nat.mul_comm, Nat.mul_left_comm]

theorem observation_samples_perm_of_distEq {es₁ es₂ : List Env}
    {obs : Env → Observation} (hlen : es₁.length = es₂.length)
    (hpositive : es₁.length > 0) (h : distEq es₁ es₂ obs) :
    (es₁.map obs).Perm (es₂.map obs) := by
  rw [List.perm_iff_count]
  intro w
  rw [List.count_eq_countP, List.countP_map,
    List.count_eq_countP, List.countP_map]
  apply Nat.eq_of_mul_eq_mul_left hpositive
  simpa [countObs, hlen, Function.comp_def] using h w

theorem flatMap_perm_of_pointwise {xs : List α} {f g : α → List β}
    (h : ∀ x ∈ xs, (f x).Perm (g x)) :
    xs.flatMap f |>.Perm (xs.flatMap g) := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
      simp only [List.flatMap_cons]
      exact (h x (by simp)).append (ih fun y hy => h y (by simp [hy]))

/-- The multiset of selected shares in one XOR sharing. -/
def sharingProjections (d : Nat) (secret : Bool)
    (shares : List Nat) : List (List Bool) :=
  ((boolVectors d).filter fun x => xorList x == secret).map
    (selectBits shares)

theorem sharingProjections_ne_nil (d : Nat) (hd : 0 < d)
    (secret : Bool) (shares : List Nat) :
    sharingProjections d secret shares ≠ [] := by
  let x := secret :: List.replicate (d - 1) false
  have hxlen : x.length = d := by
    simp [x]
    omega
  have hx : x ∈ boolVectors d := (mem_boolVectors_iff d x).2 hxlen
  have hxor : xorList x = secret := by
    have hfold (n : Nat) (acc : Bool) :
        (List.replicate n false).foldl (fun a b => a != b) acc = acc := by
      induction n with
      | zero => rfl
      | succ n ih => simpa [List.replicate_succ] using ih
    simp [x, xorList, hfold]
  have hmem : selectBits shares x ∈ sharingProjections d secret shares := by
    apply List.mem_map.mpr
    refine ⟨x, List.mem_filter.mpr ⟨hx, ?_⟩, rfl⟩
    simpa [hxor]
  exact List.ne_nil_of_mem hmem

theorem sharingProjections_count (d : Nat) (secret : Bool)
    (shares : List Nat) (q : List Bool) :
    (sharingProjections d secret shares).count q =
      (sharingFiber d secret shares q).length := by
  unfold sharingProjections sharingFiber
  generalize boolVectors d = xs
  induction xs with
  | nil => simp
  | cons x xs ih =>
      have ih' : List.countP (fun x => selectBits shares x == q)
          (xs.filter fun x => xorList x == secret) =
          (xs.filter fun x => xorList x == secret &&
            selectBits shares x == q).length := by
        simpa [List.count_eq_countP, List.countP_map,
          Function.comp_def] using ih
      by_cases hsecret : xorList x = secret
      · by_cases hproj : selectBits shares x = q <;>
          simp [hsecret, hproj, ih', List.count_eq_countP,
            List.countP_map, Function.comp_def]
      · simp [hsecret, ih', List.count_eq_countP, List.countP_map,
          Function.comp_def]

theorem sharingProjections_secret_perm (d : Nat) (shares : List Nat)
    (hshares : shares.Sublist (List.range d)) (hsmall : shares.length < d)
    (left right : Bool) :
    (sharingProjections d left shares).Perm
      (sharingProjections d right shares) := by
  cases left <;> cases right
  · exact List.Perm.refl _
  · rw [List.perm_iff_count]
    intro q
    rw [sharingProjections_count, sharingProjections_count]
    exact xorSharing_secret_independent d shares hshares hsmall q
  · rw [List.perm_iff_count]
    intro q
    rw [sharingProjections_count, sharingProjections_count]
    exact (xorSharing_secret_independent d shares hshares hsmall q).symm
  · exact List.Perm.refl _

theorem sharingProjections_secret_perm_mem (d : Nat) (shares : List Nat)
    (hshares : ∀ i ∈ shares, i < d) (hsmall : shares.length < d)
    (left right : Bool) :
    (sharingProjections d left shares).Perm
      (sharingProjections d right shares) := by
  cases left <;> cases right
  · exact List.Perm.refl _
  · rw [List.perm_iff_count]
    intro q
    rw [sharingProjections_count, sharingProjections_count]
    exact xorSharing_secret_independent_mem d shares hshares hsmall q
  · rw [List.perm_iff_count]
    intro q
    rw [sharingProjections_count, sharingProjections_count]
    exact (xorSharing_secret_independent_mem d shares hshares hsmall q).symm
  · exact List.Perm.refl _

/-- Projection tuples for independently XOR-shared secrets, built one input
sharing at a time. -/
def multiSharingProjections (d : Nat) (shares : List Nat) :
    List Bool → List (List Bool)
  | [] => [[]]
  | secret :: secrets =>
      (sharingProjections d secret shares).flatMap fun head =>
        (multiSharingProjections d shares secrets).map (head ++ ·)

theorem multiSharingProjections_ne_nil (d : Nat) (hd : 0 < d)
    (shares : List Nat) (secrets : List Bool) :
    multiSharingProjections d shares secrets ≠ [] := by
  induction secrets with
  | nil => simp [multiSharingProjections]
  | cons secret secrets ih =>
      rcases List.exists_mem_of_ne_nil _
        (sharingProjections_ne_nil d hd secret shares) with ⟨head, hhead⟩
      rcases List.exists_mem_of_ne_nil _ ih with ⟨tail, htail⟩
      apply List.ne_nil_of_mem (a := head ++ tail)
      simp only [multiSharingProjections, List.mem_flatMap, List.mem_map]
      exact ⟨head, hhead, tail, htail, rfl⟩

/-- Fewer than `d` common share indexes reveal the same projection multiset
for every vector of XOR-shared secrets of the same arity. -/
theorem multiSharingProjections_secret_perm (d : Nat) (shares : List Nat)
    (hshares : shares.Sublist (List.range d)) (hsmall : shares.length < d)
    (left right : List Bool) (hlen : left.length = right.length) :
    (multiSharingProjections d shares left).Perm
      (multiSharingProjections d shares right) := by
  induction left generalizing right with
  | nil =>
      have : right = [] := List.eq_nil_of_length_eq_zero (by simpa using hlen.symm)
      subst right
      exact List.Perm.refl _
  | cons leftHead leftTail ih =>
      cases right with
      | nil => simp at hlen
      | cons rightHead rightTail =>
          simp only [List.length_cons, Nat.succ.injEq] at hlen
          have hhead := sharingProjections_secret_perm d shares hshares hsmall
            leftHead rightHead
          have htail := ih rightTail hlen
          exact (hhead.flatMap_right fun head =>
            (multiSharingProjections d shares leftTail).map (head ++ ·)).trans
              (flatMap_perm_of_pointwise fun head _ => htail.map (head ++ ·))

theorem multiSharingProjections_secret_perm_mem (d : Nat) (shares : List Nat)
    (hshares : ∀ i ∈ shares, i < d) (hsmall : shares.length < d)
    (left right : List Bool) (hlen : left.length = right.length) :
    (multiSharingProjections d shares left).Perm
      (multiSharingProjections d shares right) := by
  induction left generalizing right with
  | nil =>
      have : right = [] := List.eq_nil_of_length_eq_zero (by simpa using hlen.symm)
      subst right
      exact List.Perm.refl _
  | cons leftHead leftTail ih =>
      cases right with
      | nil => simp at hlen
      | cons rightHead rightTail =>
          simp only [List.length_cons, Nat.succ.injEq] at hlen
          have hhead := sharingProjections_secret_perm_mem d shares hshares hsmall
            leftHead rightHead
          have htail := ih rightTail hlen
          exact (hhead.flatMap_right fun head =>
            (multiSharingProjections d shares leftTail).map (head ++ ·)).trans
              (flatMap_perm_of_pointwise fun head _ => htail.map (head ++ ·))

/-- Splitting a Boolean vector at a fixed coordinate gives the same finite
product enumeration as choosing its prefix and suffix independently. -/
theorem boolVectors_add_perm (m n : Nat) :
    (boolVectors (m + n)).Perm
      ((boolVectors m).flatMap (fun pre =>
        (boolVectors n).map (fun tail => pre ++ tail))) := by
  have hleft := boolVectors_nodup (m + n)
  have hright : ((boolVectors m).flatMap (fun pre =>
      (boolVectors n).map (fun tail => pre ++ tail))).Nodup := by
    change List.Pairwise (fun x y : List Bool => x ≠ y) _
    rw [List.pairwise_flatMap]
    constructor
    · intro pre _
      rw [List.pairwise_map]
      apply (boolVectors_nodup n).imp
      intro left right hne
      intro heq
      exact hne (List.append_cancel_left heq)
    · apply (boolVectors_nodup m).imp
      intro left right hne x hx y hy heq
      simp only [List.mem_map] at hx hy
      rcases hx with ⟨leftTail, hleftTail, rfl⟩
      rcases hy with ⟨rightTail, hrightTail, rfl⟩
      apply hne
      have htails : leftTail.length = rightTail.length := by
        rw [(mem_boolVectors_iff n leftTail).mp hleftTail,
          (mem_boolVectors_iff n rightTail).mp hrightTail]
      have hprefixes : left.length = right.length := by
        have := congrArg List.length heq
        simp only [List.length_append] at this
        omega
      have := congrArg (List.take left.length) heq
      simpa [hprefixes] using this
  apply List.perm_iff_count.mpr
  intro x
  rw [hleft.count, hright.count]
  congr 1
  simp only [List.mem_flatMap, List.mem_map]
  rw [mem_boolVectors_iff]
  apply propext
  constructor
  · intro hlen
    refine ⟨x.take m, ?_, x.drop m, ?_, ?_⟩
    · rw [mem_boolVectors_iff, List.length_take, hlen]
      omega
    · rw [mem_boolVectors_iff, List.length_drop, hlen]
      omega
    · exact List.take_append_drop m x
  · rintro ⟨pre, hpre, tail, htail, rfl⟩
    rw [List.length_append, (mem_boolVectors_iff m pre).mp hpre,
      (mem_boolVectors_iff n tail).mp htail]

/-- Boolean vectors assembled as a product of `count` consecutive blocks of
width `d`.  This is the representation used to relate flat gadget input
valuations to independently chosen XOR sharings. -/
def boolVectorBlocks (d : Nat) : Nat → List (List Bool)
  | 0 => [[]]
  | count + 1 =>
      (boolVectors d).flatMap fun head =>
        (boolVectorBlocks d count).map (head ++ ·)

/-- Iterating `boolVectors_add_perm` decomposes the flat input enumeration into
one independent `d`-bit block per input sharing. -/
theorem boolVectors_mul_perm (count d : Nat) :
    (boolVectors (count * d)).Perm (boolVectorBlocks d count) := by
  induction count with
  | zero =>
      rw [Nat.zero_mul]
      change ([[]] : List (List Bool)).Perm [[]]
      exact List.Perm.refl _
  | succ count ih =>
      rw [Nat.succ_mul, Nat.add_comm (count * d) d]
      exact (boolVectors_add_perm d (count * d)).trans
        (flatMap_perm_of_pointwise fun head _ => ih.map (head ++ ·))

/-- A fixed-width block of a flat valuation, with the same false-padding
semantics as `inputBit` on malformed short valuations. -/
def blockAt (d : Nat) (x : List Bool) (block : Nat) : List Bool :=
  (List.range d).map fun index => x.getD (block * d + index) false

/-- Read the XOR-secret of each consecutive width-`d` block of a flat input
valuation. -/
def blockSecrets (d count : Nat) (x : List Bool) : List Bool :=
  (List.range count).map fun block => xorList (blockAt d x block)

/-- Read the selected coordinates of each consecutive width-`d` block of a
flat input valuation. -/
def blockProjection (d : Nat) (shares : List Nat)
    (count : Nat) (x : List Bool) : List Bool :=
  (List.range count).flatMap fun block => selectBits shares (blockAt d x block)

theorem getD_drop (x : List α) (offset index : Nat) (fallback : α) :
    (x.drop offset).getD index fallback = x.getD (offset + index) fallback := by
  simp only [List.getD_eq_getElem?_getD, List.getElem?_drop]

theorem sharingSecret_eq_block (g : GadgetInstance) (x : List Bool)
    (sharing : Nat) :
    sharingSecret g x sharing =
      xorList (blockAt g.d x sharing) := by
  rfl

theorem secretsOf_eq_blockSecrets (g : GadgetInstance) (x : List Bool) :
    secretsOf g x = blockSecrets g.d g.inputCount x := by
  apply List.map_congr_left
  intro sharing _
  exact sharingSecret_eq_block g x sharing

theorem inputBit_eq_drop_getD (g : GadgetInstance) (x : List Bool)
    (sharing share : Nat) :
    inputBit g x sharing share =
      (x.drop (sharing * g.d)).getD share false := by
  rw [inputBit, inputPosition, getD_drop]

theorem blockAt_getD (d : Nat) (x : List Bool) (block share : Nat)
    (hshare : share < d) :
    (blockAt d x block).getD share false =
      x.getD (block * d + share) false := by
  simp [blockAt, List.getD_eq_getElem?_getD, hshare]

theorem projection_eq_blockProjection (g : GadgetInstance)
    (shares : List Nat) (hshares : shares.Sublist (List.range g.d))
    (x : List Bool) :
    projection g shares x =
      blockProjection g.d shares g.inputCount x := by
  unfold projection blockProjection
  apply congrArg List.flatten
  apply List.map_congr_left
  intro sharing _
  apply List.map_congr_left
  intro share hshare
  unfold inputBit inputPosition
  rw [blockAt_getD]
  simpa using hshares.mem hshare

theorem projection_eq_blockProjection_mem (g : GadgetInstance)
    (shares : List Nat) (hshares : ∀ share ∈ shares, share < g.d)
    (x : List Bool) :
    projection g shares x =
      blockProjection g.d shares g.inputCount x := by
  unfold projection blockProjection
  apply congrArg List.flatten
  apply List.map_congr_left
  intro sharing _
  apply List.map_congr_left
  intro share hshare
  unfold inputBit inputPosition
  rw [blockAt_getD]
  exact hshares share hshare

theorem blockAt_append_zero (d : Nat) (head tail : List Bool)
    (hlen : head.length = d) :
    blockAt d (head ++ tail) 0 = head := by
  apply List.ext_getElem
  · simp [blockAt, hlen]
  · intro i hleft hright
    simp only [blockAt, List.length_map, List.length_range] at hleft
    simp only [blockAt, List.getElem_map, List.getElem_range, Nat.zero_mul,
      Nat.zero_add, List.getD_eq_getElem?_getD]
    rw [List.getElem?_append_left hright, List.getElem?_eq_getElem hright]
    rfl

theorem blockAt_append_succ (d : Nat) (head tail : List Bool)
    (hlen : head.length = d) (block : Nat) :
    blockAt d (head ++ tail) (block + 1) = blockAt d tail block := by
  unfold blockAt
  apply List.map_congr_left
  intro i _
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD]
  have hge : head.length ≤ (block + 1) * d + i := by
    rw [hlen, Nat.add_mul]
    omega
  rw [List.getElem?_append_right hge]
  congr 2
  rw [hlen, Nat.add_mul]
  omega

theorem blockSecrets_append (d count : Nat) (head tail : List Bool)
    (hlen : head.length = d) :
    blockSecrets d (count + 1) (head ++ tail) =
      xorList head :: blockSecrets d count tail := by
  unfold blockSecrets
  rw [List.range_succ_eq_map]
  simp only [List.map_cons, List.map_map, blockAt_append_zero d head tail hlen]
  congr 1
  apply List.map_congr_left
  intro block _
  exact congrArg xorList (blockAt_append_succ d head tail hlen block)

theorem blockProjection_append (d count : Nat) (shares : List Nat)
    (head tail : List Bool) (hlen : head.length = d) :
    blockProjection d shares (count + 1) (head ++ tail) =
      selectBits shares head ++ blockProjection d shares count tail := by
  unfold blockProjection
  rw [List.range_succ_eq_map]
  simp only [List.flatMap_cons, blockAt_append_zero d head tail hlen,
    List.flatMap_map]
  congr 1
  apply congrArg List.flatten
  apply List.map_congr_left
  intro block _
  exact congrArg (selectBits shares)
    (blockAt_append_succ d head tail hlen block)

/-- Filtering the independent block product by its XOR secrets and projecting
selected shares gives exactly the canonical multi-sharing projection multiset. -/
theorem blockProjections_perm (d count : Nat) (shares : List Nat)
    (secrets : List Bool) (hlen : secrets.length = count) :
    (((boolVectorBlocks d count).filter fun x =>
        blockSecrets d count x == secrets).map
      (blockProjection d shares count)).Perm
      (multiSharingProjections d shares secrets) := by
  induction count generalizing secrets with
  | zero =>
      have : secrets = [] := List.eq_nil_of_length_eq_zero hlen
      subst secrets
      simp [boolVectorBlocks, blockSecrets, blockProjection,
        multiSharingProjections]
  | succ count ih =>
      cases secrets with
      | nil => simp at hlen
      | cons secret secrets =>
        simp only [List.length_cons, Nat.succ.injEq] at hlen
        rw [boolVectorBlocks, List.filter_flatMap, List.map_flatMap]
        simp only [List.filter_map, Function.comp_def]
        have hgeneric (heads : List (List Bool))
            (hall : ∀ head ∈ heads, head.length = d) :
            List.flatMap (fun head =>
                List.map (blockProjection d shares (count + 1))
                  (List.map (fun tail => head ++ tail)
                    (List.filter (fun tail =>
                      blockSecrets d (count + 1) (head ++ tail) ==
                        secret :: secrets) (boolVectorBlocks d count)))) heads =
              (heads.filter fun x => xorList x == secret).flatMap fun head =>
                (((boolVectorBlocks d count).filter fun tail =>
                    blockSecrets d count tail == secrets).map
                  (blockProjection d shares count)).map
                    (selectBits shares head ++ ·) := by
          induction heads with
          | nil => simp
          | cons head heads ihheads =>
              have hheadlen := hall head (by simp)
              have htail : ∀ x ∈ heads, x.length = d := by
                intro x hx
                exact hall x (by simp [hx])
              let tails := (boolVectorBlocks d count).filter fun tail =>
                blockSecrets d count tail == secrets
              rw [List.flatMap_cons, ihheads htail]
              by_cases hsecret : xorList head = secret
              · have hfilter :
                    (boolVectorBlocks d count).filter (fun tail =>
                      blockSecrets d (count + 1) (head ++ tail) ==
                        secret :: secrets) = tails := by
                  unfold tails
                  apply List.filter_congr
                  intro tail _
                  rw [blockSecrets_append d count head tail hheadlen]
                  simp [hsecret]
                rw [hfilter]
                have hmap :
                    List.map (blockProjection d shares (count + 1))
                        (List.map (head ++ ·) tails) =
                      (tails.map (blockProjection d shares count)).map
                        (selectBits shares head ++ ·) := by
                  rw [List.map_map, List.map_map]
                  apply List.map_congr_left
                  intro tail _
                  exact blockProjection_append d count shares head tail hheadlen
                rw [hmap]
                simp [hsecret, tails]
              · have hfilter :
                    (boolVectorBlocks d count).filter (fun tail =>
                      blockSecrets d (count + 1) (head ++ tail) ==
                        secret :: secrets) = [] := by
                  apply List.filter_eq_nil_iff.mpr
                  intro tail _
                  rw [blockSecrets_append d count head tail hheadlen]
                  simp [hsecret]
                rw [hfilter]
                simp [hsecret]
        rw [hgeneric (boolVectors d) (fun head hhead =>
          (mem_boolVectors_iff d head).mp hhead)]
        rw [multiSharingProjections]
        unfold sharingProjections
        rw [List.flatMap_map]
        exact flatMap_perm_of_pointwise fun _ _ =>
          (ih secrets hlen).map (_ ++ ·)

/-- The concrete gadget input fiber has exactly the canonical multiset of
selected-share projections. -/
theorem gadgetFiberProjections_perm (g : GadgetInstance) (shares : List Nat)
    (hshares : shares.Sublist (List.range g.d)) (secrets : List Bool)
    (hlen : secrets.length = g.inputCount) :
    ((((boolVectors (inputWidth g)).filter fun x =>
        secretsOf g x == secrets).map (projection g shares))).Perm
      (multiSharingProjections g.d shares secrets) := by
  have hblocks := (boolVectors_mul_perm g.inputCount g.d).filter
    (fun x => secretsOf g x == secrets)
  have hprojected := hblocks.map (projection g shares)
  have hrewrite :
      (((boolVectorBlocks g.d g.inputCount).filter fun x =>
          secretsOf g x == secrets).map (projection g shares)) =
        ((boolVectorBlocks g.d g.inputCount).filter fun x =>
          blockSecrets g.d g.inputCount x == secrets).map
            (blockProjection g.d shares g.inputCount) := by
    have hsecretfn : (fun x => secretsOf g x == secrets) =
        (fun x => blockSecrets g.d g.inputCount x == secrets) := by
      funext x
      rw [secretsOf_eq_blockSecrets]
    have hprojfn : projection g shares =
        blockProjection g.d shares g.inputCount := by
      funext x
      exact projection_eq_blockProjection g shares hshares x
    rw [hsecretfn, hprojfn]
  rw [hrewrite] at hprojected
  change
    ((boolVectors (g.inputCount * g.d)).filter (fun x =>
      secretsOf g x == secrets) |>.map (projection g shares)).Perm _
  exact hprojected.trans
    (blockProjections_perm g.d g.inputCount shares secrets hlen)

theorem gadgetFiberProjections_perm_mem (g : GadgetInstance)
    (shares : List Nat) (hshares : ∀ share ∈ shares, share < g.d)
    (secrets : List Bool) (hlen : secrets.length = g.inputCount) :
    ((((boolVectors (inputWidth g)).filter fun x =>
        secretsOf g x == secrets).map (projection g shares))).Perm
      (multiSharingProjections g.d shares secrets) := by
  have hblocks := (boolVectors_mul_perm g.inputCount g.d).filter
    (fun x => secretsOf g x == secrets)
  have hprojected := hblocks.map (projection g shares)
  have hrewrite :
      (((boolVectorBlocks g.d g.inputCount).filter fun x =>
          secretsOf g x == secrets).map (projection g shares)) =
        ((boolVectorBlocks g.d g.inputCount).filter fun x =>
          blockSecrets g.d g.inputCount x == secrets).map
            (blockProjection g.d shares g.inputCount) := by
    have hsecretfn : (fun x => secretsOf g x == secrets) =
        (fun x => blockSecrets g.d g.inputCount x == secrets) := by
      funext x
      rw [secretsOf_eq_blockSecrets]
    have hprojfn : projection g shares =
        blockProjection g.d shares g.inputCount := by
      funext x
      exact projection_eq_blockProjection_mem g shares hshares x
    rw [hsecretfn, hprojfn]
  rw [hrewrite] at hprojected
  change
    ((boolVectors (g.inputCount * g.d)).filter (fun x =>
      secretsOf g x == secrets) |>.map (projection g shares)).Perm _
  exact hprojected.trans
    (blockProjections_perm g.d g.inputCount shares secrets hlen)

/-- If every input experiment has the same nonzero cardinality, a simulator
whose projection has the same multiset on every secret fiber yields a probing
simulator after the full-input experiments are aggregated by secret. -/
theorem simulatableOn_secret_fibers
    (xs secrets : List (List Bool)) (fiber : List Bool → List (List Bool))
    (envsOf : List Bool → List Env) (projI : List Bool → List Bool)
    (obs : Env → Observation)
    (hfiber : ∀ secret ∈ secrets, ∀ x ∈ fiber secret, x ∈ xs)
    (hfiber_nonempty : ∀ secret ∈ secrets, fiber secret ≠ [])
    (hreached : ∀ x ∈ xs, (envsOf x).length > 0)
    (hcard : ∀ x ∈ xs, ∀ y ∈ xs,
      (envsOf x).length = (envsOf y).length)
    (hproj : ∀ s₁ ∈ secrets, ∀ s₂ ∈ secrets,
      ((fiber s₁).map projI).Perm ((fiber s₂).map projI))
    (hsim : SimulatableOn xs envsOf projI obs) :
    SimulatableOn secrets (fun secret => (fiber secret).flatMap envsOf)
      (fun _ => []) obs := by
  classical
  have hinv := (simulatable_iff_countInvariant xs envsOf projI obs hreached).mp hsim
  let representative : List Bool → List Bool := fun q =>
    if h : ∃ x ∈ xs, projI x = q then Classical.choose h else []
  let canonical : List Bool → List Observation := fun q =>
    (envsOf (representative q)).map obs
  have hrepresentative (x : List Bool) (hx : x ∈ xs) :
      representative (projI x) ∈ xs ∧
        projI (representative (projI x)) = projI x := by
    have hex : ∃ y ∈ xs, projI y = projI x := ⟨x, hx, rfl⟩
    exact ⟨by simp [representative, hex, Classical.choose_spec hex],
      by simp [representative, hex, Classical.choose_spec hex]⟩
  have hsamples (x : List Bool) (hx : x ∈ xs) :
      (envsOf x).map obs |>.Perm (canonical (projI x)) := by
    have hrep := hrepresentative x hx
    apply observation_samples_perm_of_distEq
    · exact hcard x hx _ hrep.1
    · exact hreached x hx
    · exact hinv x hx _ hrep.1 hrep.2.symm
  have hnonempty (secret : List Bool) (hs : secret ∈ secrets) :
      ((fiber secret).flatMap envsOf).length > 0 := by
    rcases List.exists_mem_of_ne_nil (fiber secret)
      (hfiber_nonempty secret hs) with ⟨x, hx⟩
    have hxall := hfiber secret hs x hx
    have henv : envsOf x ≠ [] := List.ne_nil_of_length_pos (hreached x hxall)
    rcases List.exists_mem_of_ne_nil (envsOf x) henv with ⟨env, henvmem⟩
    have hmem : env ∈ (fiber secret).flatMap envsOf :=
      List.mem_flatMap.mpr ⟨x, hx, henvmem⟩
    exact List.length_pos_of_mem hmem
  apply (simulatable_iff_countInvariant secrets
    (fun secret => (fiber secret).flatMap envsOf) (fun _ => []) obs hnonempty).mpr
  intro s₁ hs₁ s₂ hs₂ _
  have hleft₁ :
      (((fiber s₁).flatMap envsOf).map obs).Perm
        (((fiber s₁).map projI).flatMap canonical) := by
    rw [List.map_flatMap]
    simpa [List.flatMap_map] using
      (flatMap_perm_of_pointwise fun x hx =>
        hsamples x (hfiber s₁ hs₁ x hx))
  have hleft₂ :
      (((fiber s₂).flatMap envsOf).map obs).Perm
        (((fiber s₂).map projI).flatMap canonical) := by
    rw [List.map_flatMap]
    simpa [List.flatMap_map] using
      (flatMap_perm_of_pointwise fun x hx =>
        hsamples x (hfiber s₂ hs₂ x hx))
  have hcanonical := (hproj s₁ hs₁ s₂ hs₂).flatMap_right canonical
  have hsamplesPerm := hleft₁.trans (hcanonical.trans hleft₂.symm)
  intro w
  have hlen : ((fiber s₁).flatMap envsOf).length =
      ((fiber s₂).flatMap envsOf).length := by
    simpa using hsamplesPerm.length_eq
  have hcount := hsamplesPerm.count w
  rw [hlen]
  congr 1
  simpa [countObs, List.count_eq_countP, List.countP_map,
    Function.comp_def] using hcount

/-- Linear comparison against one base distribution. -/
def BaseInvariant (xs : List (List Bool)) (envsOf : List Bool → List Env)
    (obs : Env → Observation) : Prop :=
  match xs with
  | [] => True
  | base :: _ => ∀ x ∈ xs, distEq (envsOf base) (envsOf x) obs

instance baseInvariantDecidable (xs : List (List Bool))
    (envsOf : List Bool → List Env) (obs : Env → Observation) :
    Decidable (BaseInvariant xs envsOf obs) := by
  unfold BaseInvariant
  split <;> infer_instance

theorem baseInvariant_iff_countInvariant_const
    (xs : List (List Bool)) (envsOf : List Bool → List Env)
    (obs : Env → Observation)
    (reached : ∀ x ∈ xs, (envsOf x).length > 0) :
    BaseInvariant xs envsOf obs ↔
      CountInvariant xs envsOf (fun _ => []) obs := by
  cases xs with
  | nil => simp [BaseInvariant, CountInvariant]
  | cons base rest =>
      constructor
      · intro h x hx y hy _
        exact distEq_trans (distEq_symm (h x hx)) (h y hy)
          (reached base (by simp))
      · intro h x hx
        exact h base (by simp) x hx rfl

/-- Direct audited probing-security specification. -/
def probingSecureSpec (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) : Prop :=
  ∀ probes ∈ subsetsUpTo t (memberNodes g),
    SimulatableOn (boolVectors g.inputCount) (envsForSecret g)
      (fun _ => []) (observe g (expandedNodes g scheme probes))

/-- Direct audited PINI specification. -/
def piniSpec (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  g.WF ∧
    ∀ internal ∈ subsetsUpTo t (internalNodes g),
      ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range g.d),
        ∃ b ∈ subsetsUpTo internal.length (List.range g.d),
          SimulatableOn (boolVectors (inputWidth g)) (envsForInput g)
            (projection g (outputs ++ b))
            (observe g (expandedNodes g scheme
              (internal ++ outputs.map g.output)))

/-- Direct audited O-PINI specification.  The shares indexed by the witness
`b` are jointly included in the simulated observation. -/
def opiniSpec (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  g.WF ∧
    ∀ internal ∈ subsetsUpTo t (internalNodes g),
      ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range g.d),
        ∃ b ∈ subsetsUpTo internal.length (List.range g.d),
          SimulatableOn (boolVectors (inputWidth g)) (envsForInput g)
            (projection g (outputs ++ b))
            (observe g ((expandedNodes g scheme
              (internal ++ outputs.map g.output)) ++ b.map g.output).eraseDups)

/-- Standard non-interference ([CGLS20]/[CS21] §2): every set of at most `t`
probes is simulatable from at most `t` shares of each input sharing.  Unlike
PINI, the share selections are independent between input sharings and have no
output-index coupling. -/
def niSpec (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  ∀ probes ∈ subsetsUpTo t (memberNodes g),
    ∃ shares ∈ inputShareSelections g t,
      SimulatableOn (boolVectors (inputWidth g)) (envsForInput g)
        (projectionIxs g shares)
        (observe g (expandedNodes g scheme probes))

/-- Strong non-interference ([CGLS20]/[CS21] §2): for `t₁` internal probes and
any output probes within the total order, simulation may use at most `t₁`
shares of each input sharing.  Output probes therefore do not propagate into
the input-share budget. -/
def sniSpec (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  ∀ internal ∈ subsetsUpTo t (internalNodes g),
    ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range g.d),
      ∃ shares ∈ inputShareSelections g internal.length,
        SimulatableOn (boolVectors (inputWidth g)) (envsForInput g)
          (projectionIxs g shares)
          (observe g (expandedNodes g scheme
            (internal ++ outputs.map g.output)))

/-- Output-sharing uniformity, matching SILVER's uniformity check: for every
full input sharing, the concrete output distribution equals the uniform
counting distribution over all sharings of the correct product value. -/
def outputUniformSpec (g : GadgetInstance) : Prop :=
  ∀ x ∈ boolVectors (inputWidth g), ∀ w : Observation,
    (idealOutputSharings g x).length *
        countObs (envsForInput g x) (observe g (outputNodes g)) w =
      (envsForInput g x).length * (idealOutputSharings g x).count w

/-- O-PINI implies PINI by restricting the simulator's joint observation to
the probes already present in the PINI experiment ([CS21], Defs. 14 and 20). -/
theorem opini_implies_pini (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) : opiniSpec g scheme t → piniSpec g scheme t := by
  rintro ⟨hwf, hopini⟩
  refine ⟨hwf, ?_⟩
  intro internal hinternal outputs houtputs
  obtain ⟨b, hb, hsim⟩ := hopini internal hinternal outputs houtputs
  refine ⟨b, hb, ?_⟩
  let base := expandedNodes g scheme (internal ++ outputs.map g.output)
  change SimulatableOn (boolVectors (inputWidth g)) (envsForInput g)
    (projection g (outputs ++ b))
    (observe g ((base ++ b.map g.output).eraseDups)) at hsim
  have hmapped := simulatableOn_map (List.take base.length) hsim
  have hobs :
      (fun env => (observe g ((base ++ b.map g.output).eraseDups) env).take
        base.length) = observe g base := by
    funext env
    exact take_observe_eraseDups_append g base (b.map g.output) env
      (expandedNodes_nodup _ _ _)
  rw [hobs] at hmapped
  exact hmapped

/-- Under the standard `d`-share XOR-input experiment, t-PINI implies
t-probing security for `t < d` ([CS20], as restated in [CS21]). -/
theorem pini_implies_probing (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) (ht : t < g.d)
    (houtput_mem : ∀ i, i < g.d → g.member (g.output i) = true)
    (houtput_inj : ∀ i j, i < g.d → j < g.d →
      g.output i = g.output j → i = j)
    (hreached : ∀ x ∈ boolVectors (inputWidth g),
      (envsForInput g x).length > 0) :
    piniSpec g scheme t → probingSecureSpec g scheme t := by
  rintro ⟨_, hpini⟩ probes hprobes
  let internal := internalProbePart g probes
  let outputs := outputSharePart g probes
  have hprobeSub := subsetsUpTo_sublist t (memberNodes g) probes hprobes
  have hprobeBound := subsetsUpTo_bound t (memberNodes g) probes hprobes
  have hprobeNodup : probes.Nodup := (memberNodes_nodup g).sublist hprobeSub
  have hinternalSub : internal.Sublist (internalNodes g) := by
    exact hprobeSub.filter (fun n => !(outputNodes g).contains n)
  have hinternalBound : internal.length ≤ t := by
    exact Nat.le_trans (List.length_filter_le _ _) hprobeBound
  have hinternal : internal ∈ subsetsUpTo t (internalNodes g) :=
    mem_subsetsUpTo_of_sublist hinternalSub hinternalBound
  have houtputsSub : outputs.Sublist (List.range g.d) :=
    List.filter_sublist
  have houtputPerm : (outputs.map g.output).Perm (outputProbePart g probes) :=
    outputSharePart_map_perm g probes hprobeNodup houtput_inj
  have houtputLength : outputs.length = (outputProbePart g probes).length := by
    simpa using houtputPerm.length_eq
  have houtputsBound : outputs.length ≤ t - internal.length := by
    have hparts := probeParts_length g probes
    change (internalProbePart g probes).length +
      (outputProbePart g probes).length = probes.length at hparts
    have htotal : internal.length + outputs.length ≤ t := by
      rw [houtputLength, hparts]
      exact hprobeBound
    omega
  have houtputs : outputs ∈
      subsetsUpTo (t - internal.length) (List.range g.d) :=
    mem_subsetsUpTo_of_sublist houtputsSub houtputsBound
  obtain ⟨b, hb, hsim⟩ := hpini internal hinternal outputs houtputs
  have hbSub := subsetsUpTo_sublist internal.length (List.range g.d) b hb
  have hbBound := subsetsUpTo_bound internal.length (List.range g.d) b hb
  let shares := outputs ++ b
  have hsharesMem : ∀ i ∈ shares, i < g.d := by
    intro i hi
    simp only [shares, List.mem_append] at hi
    exact hi.elim (fun h => by simpa using houtputsSub.mem h)
      (fun h => by simpa using hbSub.mem h)
  have hsharesSmall : shares.length < g.d := by
    simp only [shares, List.length_append]
    omega
  let fiber : List Bool → List (List Bool) := fun secret =>
    (boolVectors (inputWidth g)).filter fun x => secretsOf g x == secret
  have hfiber (secret : List Bool) (hsecret : secret ∈ boolVectors g.inputCount)
      (x : List Bool) (hx : x ∈ fiber secret) :
      x ∈ boolVectors (inputWidth g) := by
    simpa [fiber] using (List.mem_filter.mp hx).1
  have hfiberNonempty (secret : List Bool)
      (hsecret : secret ∈ boolVectors g.inputCount) : fiber secret ≠ [] := by
    have hlen := (mem_boolVectors_iff g.inputCount secret).mp hsecret
    have hp := gadgetFiberProjections_perm_mem g shares hsharesMem secret hlen
    have hright := multiSharingProjections_ne_nil g.d (by omega) shares secret
    intro hempty
    apply hright
    apply List.eq_nil_of_length_eq_zero
    have hlength := hp.length_eq
    change ((fiber secret).map (projection g shares)).length =
      (multiSharingProjections g.d shares secret).length at hlength
    rw [hempty] at hlength
    simpa using hlength.symm
  have hproj (left : List Bool) (hleft : left ∈ boolVectors g.inputCount)
      (right : List Bool) (hright : right ∈ boolVectors g.inputCount) :
      ((fiber left).map (projection g shares)).Perm
        ((fiber right).map (projection g shares)) := by
    have hleftLen := (mem_boolVectors_iff g.inputCount left).mp hleft
    have hrightLen := (mem_boolVectors_iff g.inputCount right).mp hright
    exact (gadgetFiberProjections_perm_mem g shares hsharesMem left hleftLen).trans
      ((multiSharingProjections_secret_perm_mem g.d shares hsharesMem hsharesSmall left right
        (hleftLen.trans hrightLen.symm)).trans
          (gadgetFiberProjections_perm_mem g shares hsharesMem right hrightLen).symm)
  have hsecretSim : SimulatableOn (boolVectors g.inputCount)
      (envsForSecret g) (fun _ => [])
      (observe g (expandedNodes g scheme
        (internal ++ outputs.map g.output))) := by
    change SimulatableOn (boolVectors g.inputCount)
      (fun secret => (fiber secret).flatMap (envsForInput g))
      (fun _ => []) _
    exact simulatableOn_secret_fibers
      (boolVectors (inputWidth g)) (boolVectors g.inputCount) fiber
      (envsForInput g) (projection g shares) _ hfiber hfiberNonempty hreached
      (fun x hx y hy => envsForInput_cardinality g x y) hproj hsim
  have hprobePerm : (internal ++ outputs.map g.output).Perm probes :=
    (List.Perm.append_left internal houtputPerm).trans (probeParts_perm g probes)
  have hexpanded := expandedNodes_perm g scheme hprobePerm
  exact simulatableOn_observe_perm g (boolVectors g.inputCount)
    (envsForSecret g) (fun _ => []) hexpanded hsecretSim

/-- Executable probing-security predicate, equivalent to the audited spec when
every secret valuation is reachable. -/
def probingSecure (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  ∀ probes ∈ subsetsUpTo t (memberNodes g),
    CountInvariant (boolVectors g.inputCount) (envsForSecret g)
      (fun _ => []) (observe g (expandedNodes g scheme probes))

/-- Linear-in-secrets probing checker, equivalent to `probingSecure` when all
secret-conditioned experiments are reached. -/
def probingSecureFast (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) : Prop :=
  ∀ probes ∈ subsetsUpTo t (memberNodes g),
    BaseInvariant (boolVectors g.inputCount) (envsForSecret g)
      (observe g (expandedNodes g scheme probes))

instance probingSecureFastDecidable
    (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) :
    Decidable (probingSecureFast g scheme t) := by
  unfold probingSecureFast
  infer_instance

/-- Probing security together with the member-boundary guard (audit finding
F1).  `probingSecure` alone quantifies probes over `memberNodes g` and filters
every expansion back through `g.member` (`expandedNodes`), so on an instance
with an ill-formed member whitelist it silently under-approximates the
adversary's observation — a security PASS then means only "the nodes we chose
to look at don't leak".  Positive whole-circuit probing anchors must be stated
in this form (or with `member := fun _ => true` over the window): prove
`g.WF` by the cheap structural `decide` and supply the probing component
separately (e.g. via `probingSecureFast_iff`). -/
def probingSecureWF (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) : Prop :=
  g.WF ∧ probingSecure g scheme t

theorem probingSecureFast_iff (g : GadgetInstance)
    (scheme : ExpansionScheme) (t : Nat)
    (reached : ∀ secret ∈ boolVectors g.inputCount,
      (envsForSecret g secret).length > 0) :
    probingSecureFast g scheme t ↔ probingSecure g scheme t := by
  unfold probingSecureFast probingSecure
  constructor <;> intro h probes hprobes
  · exact (baseInvariant_iff_countInvariant_const _ _ _ reached).mp
      (h probes hprobes)
  · exact (baseInvariant_iff_countInvariant_const _ _ _ reached).mpr
      (h probes hprobes)

/-- Executable PINI predicate. -/
def pini (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  g.WF ∧
    ∀ internal ∈ subsetsUpTo t (internalNodes g),
      ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range g.d),
        ∃ b ∈ subsetsUpTo internal.length (List.range g.d),
          CountInvariant (boolVectors (inputWidth g)) (envsForInput g)
            (projection g (outputs ++ b))
            (observe g (expandedNodes g scheme
              (internal ++ outputs.map g.output)))

/-- Executable O-PINI predicate. -/
def opini (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  g.WF ∧
    ∀ internal ∈ subsetsUpTo t (internalNodes g),
      ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range g.d),
        ∃ b ∈ subsetsUpTo internal.length (List.range g.d),
          CountInvariant (boolVectors (inputWidth g)) (envsForInput g)
            (projection g (outputs ++ b))
            (observe g ((expandedNodes g scheme
              (internal ++ outputs.map g.output)) ++ b.map g.output).eraseDups)

/-- Executable NI predicate. -/
def ni (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  ∀ probes ∈ subsetsUpTo t (memberNodes g),
    ∃ shares ∈ inputShareSelections g t,
      CountInvariant (boolVectors (inputWidth g)) (envsForInput g)
        (projectionIxs g shares)
        (observe g (expandedNodes g scheme probes))

/-- Executable SNI predicate. -/
def sni (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  ∀ internal ∈ subsetsUpTo t (internalNodes g),
    ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range g.d),
      ∃ shares ∈ inputShareSelections g internal.length,
        CountInvariant (boolVectors (inputWidth g)) (envsForInput g)
          (projectionIxs g shares)
          (observe g (expandedNodes g scheme
            (internal ++ outputs.map g.output)))

/-- Finite-support checker for output-sharing uniformity. -/
def outputUniform (g : GadgetInstance) : Prop :=
  ∀ x ∈ boolVectors (inputWidth g),
    let actual := (envsForInput g x).map (observe g (outputNodes g))
    let ideal := idealOutputSharings g x
    (actual ++ ideal).eraseDups.all fun w =>
      ideal.length * actual.count w == actual.length * ideal.count w

theorem outputUniform_iff_spec (g : GadgetInstance) :
    outputUniform g ↔ outputUniformSpec g := by
  unfold outputUniform outputUniformSpec
  constructor
  · intro h x hx w
    have hcheck := h x hx
    simp only [List.all_eq_true] at hcheck
    let actual := (envsForInput g x).map (observe g (outputNodes g))
    let ideal := idealOutputSharings g x
    have hcount : actual.count w =
        countObs (envsForInput g x) (observe g (outputNodes g)) w := by
      simp [actual, List.count_eq_countP, List.countP_map,
        Function.comp_def, countObs]
    have hlength : actual.length = (envsForInput g x).length := by
      simp [actual]
    rw [← hcount, ← hlength]
    by_cases hw : w ∈ (actual ++ ideal).eraseDups
    · have := hcheck w hw
      change ideal.length * actual.count w = actual.length * ideal.count w
      exact of_decide_eq_true this
    · have hactual : actual.count w = 0 := by
        apply List.count_eq_zero.mpr
        intro hmem
        exact hw (by simp [hmem])
      have hideal : ideal.count w = 0 := by
        apply List.count_eq_zero.mpr
        intro hmem
        exact hw (by simp [hmem])
      change ideal.length * actual.count w = actual.length * ideal.count w
      simp [hactual, hideal]
  · intro h x hx
    simp only [List.all_eq_true]
    intro w _
    simpa [List.count_eq_countP, List.countP_map, Function.comp_def,
      countObs] using h x hx w

theorem boolVectors_length (n : Nat) (x : List Bool)
    (hx : x ∈ boolVectors n) : x.length = n := by
  induction n generalizing x with
  | zero => simpa [boolVectors] using hx
  | succ n ih =>
      simp [boolVectors] at hx
      rcases hx with ⟨tail, htail, rfl | rfl⟩ <;> simp [ih tail htail]

theorem probingSecure_iff_spec (g : GadgetInstance)
    (scheme : ExpansionScheme) (t : Nat)
    (reached : ∀ secret ∈ boolVectors g.inputCount,
      (envsForSecret g secret).length > 0) :
    probingSecure g scheme t ↔ probingSecureSpec g scheme t := by
  unfold probingSecure probingSecureSpec
  constructor <;> intro h probes hprobes
  · exact (simulatable_iff_countInvariant _ _ _ _ reached).2
      (h probes hprobes)
  · exact (simulatable_iff_countInvariant _ _ _ _ reached).1
      (h probes hprobes)

theorem pini_iff_spec (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat)
    (reached : ∀ x ∈ boolVectors (inputWidth g),
      (envsForInput g x).length > 0) :
    pini g scheme t ↔ piniSpec g scheme t := by
  unfold pini piniSpec
  constructor
  · rintro ⟨hwf, h⟩
    refine ⟨hwf, ?_⟩
    intro internal hinternal outputs houtputs
    obtain ⟨b, hb, hsim⟩ := h internal hinternal outputs houtputs
    exact ⟨b, hb, (simulatable_iff_countInvariant _ _ _ _ reached).2 hsim⟩
  · rintro ⟨hwf, h⟩
    refine ⟨hwf, ?_⟩
    intro internal hinternal outputs houtputs
    obtain ⟨b, hb, hsim⟩ := h internal hinternal outputs houtputs
    exact ⟨b, hb, (simulatable_iff_countInvariant _ _ _ _ reached).1 hsim⟩

theorem opini_iff_spec (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat)
    (reached : ∀ x ∈ boolVectors (inputWidth g),
      (envsForInput g x).length > 0) :
    opini g scheme t ↔ opiniSpec g scheme t := by
  unfold opini opiniSpec
  constructor
  · rintro ⟨hwf, h⟩
    refine ⟨hwf, ?_⟩
    intro internal hinternal outputs houtputs
    obtain ⟨b, hb, hsim⟩ := h internal hinternal outputs houtputs
    exact ⟨b, hb, (simulatable_iff_countInvariant _ _ _ _ reached).2 hsim⟩
  · rintro ⟨hwf, h⟩
    refine ⟨hwf, ?_⟩
    intro internal hinternal outputs houtputs
    obtain ⟨b, hb, hsim⟩ := h internal hinternal outputs houtputs
    exact ⟨b, hb, (simulatable_iff_countInvariant _ _ _ _ reached).1 hsim⟩

theorem ni_iff_spec (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat)
    (reached : ∀ x ∈ boolVectors (inputWidth g),
      (envsForInput g x).length > 0) :
    ni g scheme t ↔ niSpec g scheme t := by
  unfold ni niSpec
  constructor <;> intro h probes hprobes
  · obtain ⟨shares, hshares, hinvariant⟩ := h probes hprobes
    exact ⟨shares, hshares,
      (simulatable_iff_countInvariant _ _ _ _ reached).2 hinvariant⟩
  · obtain ⟨shares, hshares, hsim⟩ := h probes hprobes
    exact ⟨shares, hshares,
      (simulatable_iff_countInvariant _ _ _ _ reached).1 hsim⟩

theorem sni_iff_spec (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat)
    (reached : ∀ x ∈ boolVectors (inputWidth g),
      (envsForInput g x).length > 0) :
    sni g scheme t ↔ sniSpec g scheme t := by
  unfold sni sniSpec
  constructor <;> intro h internal hinternal outputs houtputs
  · obtain ⟨shares, hshares, hinvariant⟩ :=
      h internal hinternal outputs houtputs
    exact ⟨shares, hshares,
      (simulatable_iff_countInvariant _ _ _ _ reached).2 hinvariant⟩
  · obtain ⟨shares, hshares, hsim⟩ :=
      h internal hinternal outputs houtputs
    exact ⟨shares, hshares,
      (simulatable_iff_countInvariant _ _ _ _ reached).1 hsim⟩

instance probingSecureDecidable
    (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) :
    Decidable (probingSecure g scheme t) := by
  unfold probingSecure
  infer_instance

instance piniDecidable
    (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) :
    Decidable (pini g scheme t) := by
  unfold pini
  infer_instance

instance opiniDecidable
    (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) :
    Decidable (opini g scheme t) := by
  unfold opini
  infer_instance

instance niDecidable
    (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) :
    Decidable (ni g scheme t) := by
  unfold ni
  infer_instance

instance sniDecidable
    (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) :
    Decidable (sni g scheme t) := by
  unfold sni
  infer_instance

instance outputUniformDecidable (g : GadgetInstance) :
    Decidable (outputUniform g) := by
  unfold outputUniform
  infer_instance

end Gadget

export Gadget (GadgetInstance probingSecure pini opini ni sni outputUniform)

end LeanSec
