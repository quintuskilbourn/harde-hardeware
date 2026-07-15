import LeanSec.Checker.Fast

/-! # Bitsliced truth-table probing checker

Evaluate the circuit ONCE PER SECRET over ALL environments simultaneously:
each node's values across the `E` environments of `envsForSecret g secret`
are packed into one `E`-bit `Nat` literal (bit `i` = value under environment
`i`, little-endian, matching `Checker.packBits`).  Gate operations become
`Nat.land`/`Nat.lxor`/`Nat.lor` on literals, which the kernel reduces via
GMP.  Per probe set, the observation tables are split recursively into
sparse `(outcome, count)` lists (zero-mask pruning), and the per-secret
sparse count lists are compared against the base secret.

Soundness (`bitChecker_sound`) reduces to the existing audited
`probingSecureSpec` through `probingSecure_iff_spec` / `probingSecureFast_iff`
exactly like `checker_sound`; nothing audited is touched.  A checker bug can
therefore only be a completeness bug (the kernel proof fails to close). -/

namespace LeanSec.Checker.Bitslice

open Gadget

/-! ## Bit-cons micro-lemmas

`packBits (b :: bs) = (if b then 1 else 0) + 2 * packBits bs`; every packed
word in this file is built from this little-endian cons cell, so three
distribution lemmas over the cell drive all gate homomorphisms. -/

theorem consBit_div_two (b : Bool) (x : Nat) :
    ((if b then 1 else 0) + 2 * x) / 2 = x := by
  cases b <;> simp <;> omega

theorem consBit_testBit_zero (b : Bool) (x : Nat) :
    ((if b then 1 else 0) + 2 * x).testBit 0 = b := by
  rw [Nat.testBit_zero]
  cases b <;> simp <;> omega

theorem consBit_testBit_succ (b : Bool) (x : Nat) (i : Nat) :
    ((if b then 1 else 0) + 2 * x).testBit (i + 1) = x.testBit i := by
  rw [Nat.testBit_add_one, consBit_div_two]

theorem consBit_and (a b : Bool) (x y : Nat) :
    (((if a then 1 else 0) + 2 * x) &&& ((if b then 1 else 0) + 2 * y)) =
      (if a && b then 1 else 0) + 2 * (x &&& y) := by
  apply Nat.eq_of_testBit_eq
  intro i
  cases i with
  | zero =>
      rw [Nat.testBit_and, consBit_testBit_zero, consBit_testBit_zero,
        consBit_testBit_zero]
  | succ i =>
      rw [Nat.testBit_and, consBit_testBit_succ, consBit_testBit_succ,
        consBit_testBit_succ, Nat.testBit_and]

theorem consBit_or (a b : Bool) (x y : Nat) :
    (((if a then 1 else 0) + 2 * x) ||| ((if b then 1 else 0) + 2 * y)) =
      (if a || b then 1 else 0) + 2 * (x ||| y) := by
  apply Nat.eq_of_testBit_eq
  intro i
  cases i with
  | zero =>
      rw [Nat.testBit_or, consBit_testBit_zero, consBit_testBit_zero,
        consBit_testBit_zero]
  | succ i =>
      rw [Nat.testBit_or, consBit_testBit_succ, consBit_testBit_succ,
        consBit_testBit_succ, Nat.testBit_or]

theorem consBit_xor (a b : Bool) (x y : Nat) :
    (((if a then 1 else 0) + 2 * x) ^^^ ((if b then 1 else 0) + 2 * y)) =
      (if a != b then 1 else 0) + 2 * (x ^^^ y) := by
  apply Nat.eq_of_testBit_eq
  intro i
  cases i with
  | zero =>
      rw [Nat.testBit_xor, consBit_testBit_zero, consBit_testBit_zero,
        consBit_testBit_zero]
  | succ i =>
      rw [Nat.testBit_xor, consBit_testBit_succ, consBit_testBit_succ,
        consBit_testBit_succ, Nat.testBit_xor]

/-! ## `packBits` gate homomorphisms -/

theorem packBits_map_false (es : List α) :
    packBits (es.map fun _ => false) = 0 := by
  induction es with
  | nil => rfl
  | cons e es ih => simp [packBits, ih]

theorem packBits_map_true (es : List α) :
    packBits (es.map fun _ => true) = 2 ^ es.length - 1 := by
  induction es with
  | nil => rfl
  | cons e es ih =>
      simp only [List.map_cons, packBits, ih, List.length_cons, if_pos]
      have h : 2 ^ (es.length + 1) = 2 * 2 ^ es.length := by
        rw [Nat.pow_succ, Nat.mul_comm]
      have hpos : 0 < 2 ^ es.length := Nat.two_pow_pos es.length
      omega

theorem packBits_map_and (es : List α) (f g : α → Bool) :
    packBits (es.map fun e => f e && g e) =
      packBits (es.map f) &&& packBits (es.map g) := by
  induction es with
  | nil => show (0 : Nat) = 0 &&& 0; decide
  | cons e es ih =>
      simp only [List.map_cons, packBits, ih, consBit_and]

theorem packBits_map_or (es : List α) (f g : α → Bool) :
    packBits (es.map fun e => f e || g e) =
      packBits (es.map f) ||| packBits (es.map g) := by
  induction es with
  | nil => show (0 : Nat) = 0 ||| 0; decide
  | cons e es ih =>
      simp only [List.map_cons, packBits, ih, consBit_or]

theorem packBits_map_xor (es : List α) (f g : α → Bool) :
    packBits (es.map fun e => f e != g e) =
      packBits (es.map f) ^^^ packBits (es.map g) := by
  induction es with
  | nil => show (0 : Nat) = 0 ^^^ 0; decide
  | cons e es ih =>
      simp only [List.map_cons, packBits, ih, consBit_xor]

theorem packBits_map_not (es : List α) (f : α → Bool) :
    packBits (es.map fun e => !f e) =
      (2 ^ es.length - 1) ^^^ packBits (es.map f) := by
  have hnot : (es.map fun e => !f e) = es.map fun e => (true != f e) := by
    apply List.map_congr_left
    intro e _
    cases f e <;> rfl
  rw [hnot]
  have h := packBits_map_xor es (fun _ => true) f
  rw [h, packBits_map_true]

theorem packBits_map_mux (es : List α) (s y z : α → Bool) :
    packBits (es.map fun e => if s e then z e else y e) =
      (packBits (es.map s) &&& packBits (es.map z)) |||
        (((2 ^ es.length - 1) ^^^ packBits (es.map s)) &&&
          packBits (es.map y)) := by
  have hsel : (es.map fun e => if s e then z e else y e) =
      es.map fun e => (s e && z e) || (!s e && y e) := by
    apply List.map_congr_left
    intro e _
    cases s e <;> cases y e <;> cases z e <;> rfl
  rw [hsel, packBits_map_or, packBits_map_and, packBits_map_and,
    packBits_map_not]

/-! ## Reference evaluator

`Execution.inputValue` / `Execution.gateValue` are private; these are
byte-identical copies, pinned to the audited evaluator by the definitional
equality `refEvalEntries_eq`.  All alignment reasoning happens against the
copies. -/

def refInputValue (env : Env) (values : List (Node × Bool))
    (gate cycle : Nat) (input : Nat × Nat) : Bool :=
  let (src, latency) := input
  if latency ≤ cycle then
    (Execution.lookupAssoc { gate := src, cycle := cycle - latency } values).getD false
  else
    env (.iniReg gate)

def refGateValue (c : Circuit) (env : Env) (values : List (Node × Bool))
    (cycle gate : Nat) : Bool :=
  match c.gates[gate]? with
  | none => false
  | some g =>
      let ins := g.inputs.map (refInputValue env values gate cycle)
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

def refEvalEntries (c : Circuit) (horizon : Nat) (env : Env) :
    List (Node × Bool) :=
  (List.range horizon).foldl (fun values cycle =>
    (Execution.gateOrder c).foldl (fun values gate =>
      ({ gate := gate, cycle := cycle },
        refGateValue c env values cycle gate) :: values)
    values) []

theorem refEvalEntries_eq (c : Circuit) (horizon : Nat) (env : Env) :
    refEvalEntries c horizon env = Execution.evalEntries c horizon env := by
  rfl

/-! ## Bitsliced evaluator -/

/-- Truth table of one source across all environments. -/
def srcTable (es : List Env) (src : Src) : Nat :=
  packBits (es.map fun e => e src)

def bitInputValue (es : List Env) (values : List (Node × Nat))
    (gate cycle : Nat) (input : Nat × Nat) : Nat :=
  let (src, latency) := input
  if latency ≤ cycle then
    (Execution.lookupAssoc { gate := src, cycle := cycle - latency } values).getD 0
  else
    srcTable es (.iniReg gate)

def bitGateValue (mask : Nat) (es : List Env) (c : Circuit)
    (values : List (Node × Nat)) (cycle gate : Nat) : Nat :=
  match c.gates[gate]? with
  | none => 0
  | some g =>
      let ins := g.inputs.map (bitInputValue es values gate cycle)
      match g.kind with
      | .xor => ins.getD 0 0 ^^^ ins.getD 1 0
      | .and => ins.getD 0 0 &&& ins.getD 1 0
      | .not => mask ^^^ ins.getD 0 0
      | .reg => ins.getD 0 0
      | .mux =>
          (ins.getD 0 0 &&& ins.getD 2 0) |||
            ((mask ^^^ ins.getD 0 0) &&& ins.getD 1 0)
      | .const b => if b then mask else 0
      | .rnd r => srcTable es (.rnd r cycle)
      | .inp sharing share => srcTable es (.inp sharing share cycle)
      | .ini s => srcTable es (.ini s cycle)
      | .ctl control => srcTable es (.ctl control cycle)

/-- Bitsliced execution trace: identical `(cycle, gateOrder)` fold shape as
`Execution.evalEntries`, node values as packed truth tables. -/
def bitEntries (es : List Env) (c : Circuit) (horizon : Nat) :
    List (Node × Nat) :=
  let mask := 2 ^ es.length - 1
  (List.range horizon).foldl (fun values cycle =>
    (Execution.gateOrder c).foldl (fun values gate =>
      ({ gate := gate, cycle := cycle },
        bitGateValue mask es c values cycle gate) :: values)
    values) []

/-! ## Trace alignment -/

/-- Pointwise alignment of a bitsliced accumulator with the per-environment
accumulators: looking any node up in the packed trace yields exactly the
packed per-environment lookups.  Nodes absent from both sides agree because
`packBits` of an all-false column is `0`. -/
def Aligned (es : List Env) (bs : List (Node × Nat))
    (vs : Env → List (Node × Bool)) : Prop :=
  ∀ node : Node,
    (Execution.lookupAssoc node bs).getD 0 =
      packBits (es.map fun e => (Execution.lookupAssoc node (vs e)).getD false)

theorem aligned_nil (es : List Env) :
    Aligned es [] (fun _ => []) := by
  intro node
  simp [Execution.lookupAssoc, packBits_map_false]

theorem bitInputValue_correct {es : List Env} {bs : List (Node × Nat)}
    {vs : Env → List (Node × Bool)} (h : Aligned es bs vs)
    (gate cycle : Nat) (input : Nat × Nat) :
    bitInputValue es bs gate cycle input =
      packBits (es.map fun e => refInputValue e (vs e) gate cycle input) := by
  rcases input with ⟨src, latency⟩
  by_cases hlat : latency ≤ cycle
  · simpa [bitInputValue, refInputValue, hlat] using
      h { gate := src, cycle := cycle - latency }
  · simp [bitInputValue, refInputValue, hlat, srcTable]

theorem bitIns_getD {es : List Env} {bs : List (Node × Nat)}
    {vs : Env → List (Node × Bool)} (h : Aligned es bs vs)
    (inputs : List (Nat × Nat)) (gate cycle j : Nat) :
    (inputs.map (bitInputValue es bs gate cycle)).getD j 0 =
      packBits (es.map fun e =>
        (inputs.map (refInputValue e (vs e) gate cycle)).getD j false) := by
  by_cases hj : j < inputs.length
  · rw [List.getD_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_getElem hj]
    simp only [Option.map_some, Option.getD_some]
    rw [bitInputValue_correct h]
    congr 1
    apply List.map_congr_left
    intro e _
    rw [List.getD_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_getElem hj]
    rfl
  · rw [List.getD_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_none (by omega)]
    simp only [Option.map_none, Option.getD_none]
    rw [show (0 : Nat) = packBits (es.map fun _ => false) from
      (packBits_map_false es).symm]
    congr 1
    apply List.map_congr_left
    intro e _
    rw [List.getD_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_none (by omega)]
    rfl

theorem bitGateValue_correct {es : List Env} {bs : List (Node × Nat)}
    {vs : Env → List (Node × Bool)} (h : Aligned es bs vs)
    (c : Circuit) (cycle gate : Nat) :
    bitGateValue (2 ^ es.length - 1) es c bs cycle gate =
      packBits (es.map fun e => refGateValue c e (vs e) cycle gate) := by
  cases hg : c.gates[gate]? with
  | none => simp [bitGateValue, refGateValue, hg, packBits_map_false]
  | some g =>
      cases hk : g.kind with
      | xor =>
          simp only [bitGateValue, refGateValue, hg, hk]
          rw [bitIns_getD h, bitIns_getD h, ← packBits_map_xor]
      | and =>
          simp only [bitGateValue, refGateValue, hg, hk]
          rw [bitIns_getD h, bitIns_getD h, ← packBits_map_and]
      | not =>
          simp only [bitGateValue, refGateValue, hg, hk]
          rw [bitIns_getD h, ← packBits_map_not]
      | reg =>
          simp only [bitGateValue, refGateValue, hg, hk]
          rw [bitIns_getD h]
      | mux =>
          simp only [bitGateValue, refGateValue, hg, hk]
          rw [bitIns_getD h, bitIns_getD h, bitIns_getD h,
            ← packBits_map_mux]
      | const b =>
          simp only [bitGateValue, refGateValue, hg, hk]
          cases b
          · simp [packBits_map_false]
          · simp [packBits_map_true]
      | rnd r => simp [bitGateValue, refGateValue, hg, hk, srcTable]
      | inp sharing share =>
          simp [bitGateValue, refGateValue, hg, hk, srcTable]
      | ini s => simp [bitGateValue, refGateValue, hg, hk, srcTable]
      | ctl control => simp [bitGateValue, refGateValue, hg, hk, srcTable]

theorem aligned_push {es : List Env} {bs : List (Node × Nat)}
    {vs : Env → List (Node × Bool)} (h : Aligned es bs vs)
    (c : Circuit) (cycle gate : Nat) :
    Aligned es
      (({ gate := gate, cycle := cycle },
        bitGateValue (2 ^ es.length - 1) es c bs cycle gate) :: bs)
      (fun e => ({ gate := gate, cycle := cycle },
        refGateValue c e (vs e) cycle gate) :: vs e) := by
  intro node
  by_cases hnode : node = { gate := gate, cycle := cycle }
  · subst hnode
    simp only [Execution.lookupAssoc, BEq.rfl, if_pos, Option.getD_some]
    exact bitGateValue_correct h c cycle gate
  · have hne : (node == { gate := gate, cycle := cycle }) = false := by
      simpa using hnode
    simp only [Execution.lookupAssoc, hne, Bool.false_eq_true, if_neg,
      not_false_eq_true]
    exact h node

theorem aligned_gateFold {es : List Env} (c : Circuit) (cycle : Nat)
    (gates : List Nat) {bs : List (Node × Nat)}
    {vs : Env → List (Node × Bool)} (h : Aligned es bs vs) :
    Aligned es
      (gates.foldl (fun values gate =>
        ({ gate := gate, cycle := cycle },
          bitGateValue (2 ^ es.length - 1) es c values cycle gate) :: values) bs)
      (fun e => gates.foldl (fun values gate =>
        ({ gate := gate, cycle := cycle },
          refGateValue c e values cycle gate) :: values) (vs e)) := by
  induction gates generalizing bs vs with
  | nil => exact h
  | cons gate gates ih =>
      simp only [List.foldl_cons]
      exact ih (aligned_push h c cycle gate)

theorem aligned_cycleFold {es : List Env} (c : Circuit)
    (cycles : List Nat) {bs : List (Node × Nat)}
    {vs : Env → List (Node × Bool)} (h : Aligned es bs vs) :
    Aligned es
      (cycles.foldl (fun values cycle =>
        (Execution.gateOrder c).foldl (fun values gate =>
          ({ gate := gate, cycle := cycle },
            bitGateValue (2 ^ es.length - 1) es c values cycle gate) :: values)
          values) bs)
      (fun e => cycles.foldl (fun values cycle =>
        (Execution.gateOrder c).foldl (fun values gate =>
          ({ gate := gate, cycle := cycle },
            refGateValue c e values cycle gate) :: values)
          values) (vs e)) := by
  induction cycles generalizing bs vs with
  | nil => exact h
  | cons cycle cycles ih =>
      simp only [List.foldl_cons]
      exact ih (aligned_gateFold c cycle (Execution.gateOrder c) h)

theorem bitEntries_aligned (es : List Env) (c : Circuit) (horizon : Nat) :
    Aligned es (bitEntries es c horizon) (refEvalEntries c horizon) := by
  have h := aligned_cycleFold (es := es) c (List.range horizon)
    (aligned_nil es)
  exact h

/-- The load-bearing trace lemma: looking a node up in the bitsliced trace
gives exactly the packed column of the audited evaluator over `es`. -/
theorem lookup_bitEntries (es : List Env) (c : Circuit) (horizon : Nat)
    (node : Node) :
    (Execution.lookupAssoc node (bitEntries es c horizon)).getD 0 =
      packBits (es.map fun e =>
        (Execution.lookupAssoc node (Execution.evalEntries c horizon e)).getD
          false) := by
  exact bitEntries_aligned es c horizon node

/-! ## Popcount (naive specification form)

`pop` is the proof-side popcount.  It is also used by the checker for now;
a SWAR ladder with a `popSwar = pop` bridge can replace it in the checker
without touching any lemma below. -/

def pop (n : Nat) : Nat :=
  if h : n = 0 then 0 else n % 2 + pop (n / 2)
decreasing_by exact Nat.div_lt_self (Nat.pos_of_ne_zero h) (by decide)

theorem pop_zero : pop 0 = 0 := by
  simp [pop]

theorem pop_consBit (b : Bool) (x : Nat) :
    pop ((if b then 1 else 0) + 2 * x) = (if b then 1 else 0) + pop x := by
  by_cases hzero : (if b then 1 else 0) + 2 * x = 0
  · have hb : (if b then 1 else 0) = 0 := by omega
    have hx : x = 0 := by omega
    rw [hzero, hb, hx, pop_zero]
  · rw [pop, dif_neg hzero]
    have hmod : ((if b then 1 else 0) + 2 * x) % 2 = (if b then 1 else 0) := by
      cases b <;> simp <;> omega
    rw [hmod, consBit_div_two]

/-! ## Sparse outcome counting

`selMask m tbls w` narrows an environment-index mask to the indices whose
observation matches the outcome `w`; its popcount is exactly the number of
environments producing `w` (`pop_selMask_count`). -/

def selMask (m : Nat) : List Nat → List Bool → Nat
  | t :: ts, b :: w => selMask (if b then m &&& t else m ^^^ (m &&& t)) ts w
  | _, _ => m

theorem zero_land (t : Nat) : 0 &&& t = 0 := by
  apply Nat.eq_of_testBit_eq
  intro i
  simp

theorem selMask_zero (tbls : List Nat) (w : List Bool) :
    selMask 0 tbls w = 0 := by
  induction tbls generalizing w with
  | nil => cases w <;> rfl
  | cons t ts ih =>
      cases w with
      | nil => rfl
      | cons b w =>
          simp only [selMask, zero_land]
          cases b <;> simp [ih]

/-- Peeling one environment off every packed table peels one bit off the
running selection mask: the low bit accumulates whether the head environment
matches the outcome prefix consumed so far.  Stated over explicitly
cons-shaped tables to keep every rewrite at the top level. -/
theorem selMask_peel (bs : List Bool) (xs : List Nat) (w : List Bool)
    (a : Bool) (m : Nat) (hw : w.length = xs.length)
    (hlen : bs.length = xs.length) :
    selMask ((if a then 1 else 0) + 2 * m)
        (List.zipWith (fun b x => (if b then 1 else 0) + 2 * x) bs xs) w =
      (if a && (bs == w) then 1 else 0) + 2 * selMask m xs w := by
  induction xs generalizing a m w bs with
  | nil =>
      have hbs : bs = [] := List.eq_nil_of_length_eq_zero hlen
      have hws : w = [] := List.eq_nil_of_length_eq_zero hw
      subst hbs; subst hws
      simp [selMask]
  | cons x xs ih =>
      cases bs with
      | nil => simp at hlen
      | cons bb bs =>
          cases w with
          | nil => simp at hw
          | cons b w =>
              have hw' : w.length = xs.length := by simpa using hw
              have hlen' : bs.length = xs.length := by simpa using hlen
              simp only [List.zipWith_cons_cons, selMask, List.cons_beq_cons]
              cases b with
              | true =>
                  rw [if_pos rfl, if_pos rfl, consBit_and,
                    ih bs w (a && bb) (m &&& x) hw' hlen']
                  have hcond : ((a && bb) && (bs == w)) =
                      (a && (bb == true && bs == w)) := by
                    cases a <;> cases bb <;> simp
                  simp only [hcond]
                  rfl
              | false =>
                  rw [if_neg Bool.false_ne_true, if_neg Bool.false_ne_true,
                    consBit_and, consBit_xor]
                  have hxor : ∀ u v : Bool, (u != (u && v)) = (u && !v) := by
                    decide
                  simp only [hxor]
                  rw [ih bs w (a && !bb) (m ^^^ (m &&& x)) hw' hlen']
                  have hcond : ((a && !bb) && (bs == w)) =
                      (a && (bb == false && bs == w)) := by
                    cases a <;> cases bb <;> simp
                  simp only [hcond]
                  rfl

/-- Packed tables over `e :: es` are cons-shaped: head bit `f e`, tail the
packed tables over `es`. -/
theorem tables_cons (fs : List (Env → Bool)) (e : Env) (es : List Env) :
    fs.map (fun f => packBits ((e :: es).map f)) =
      List.zipWith (fun b x => (if b then 1 else 0) + 2 * x)
        (fs.map fun f => f e) (fs.map fun f => packBits (es.map f)) := by
  induction fs with
  | nil => rfl
  | cons f fs ih =>
      have hhead : packBits (List.map f (e :: es)) =
          (if f e then 1 else 0) + 2 * packBits (List.map f es) := by
        rw [List.map_cons]
        rfl
      show packBits (List.map f (e :: es)) ::
          List.map (fun f => packBits (List.map f (e :: es))) fs = _
      rw [hhead, ih]
      rfl

/-- The sparse-count fundamental lemma: the popcount of the fully narrowed
selection mask counts the environments whose observation equals `w`
(memo lemma 4 sidestepped: stated directly against the environment list, no
enumeration indexing needed). -/
theorem pop_selMask_count (es : List Env) (fs : List (Env → Bool))
    (w : List Bool) (hw : w.length = fs.length) :
    pop (selMask (2 ^ es.length - 1)
        (fs.map fun f => packBits (es.map f)) w) =
      es.countP fun e => fs.map (fun f => f e) == w := by
  induction es with
  | nil =>
      rw [show (2 : Nat) ^ ([] : List Env).length - 1 = 0 from rfl,
        selMask_zero, pop_zero]
      rfl
  | cons e es ih =>
      have hmask : 2 ^ (e :: es).length - 1 =
          (if true then 1 else 0) + 2 * (2 ^ es.length - 1) := by
        simp only [List.length_cons, if_pos]
        have h2 : 2 ^ (es.length + 1) = 2 * 2 ^ es.length := by
          rw [Nat.pow_succ, Nat.mul_comm]
        have hpos : 0 < 2 ^ es.length := Nat.two_pow_pos es.length
        omega
      have hwlen : w.length = (fs.map fun f => packBits (es.map f)).length := by
        rw [List.length_map]; exact hw
      have hblen : (fs.map fun f => f e).length =
          (fs.map fun f => packBits (es.map f)).length := by
        rw [List.length_map, List.length_map]
      rw [hmask, tables_cons,
        selMask_peel (fs.map fun f => f e) (fs.map fun f => packBits (es.map f))
          w true (2 ^ es.length - 1) hwlen hblen,
        pop_consBit, ih, List.countP_cons, Bool.true_and]
      exact Nat.add_comm _ _

/-! ## Sparse outcome enumeration

Recursive splitting of the full-environment mask into per-outcome masks,
pruning empty branches; the sparse `(outcome, count)` list determines the
whole count function via `sparseCounts_lookup`. -/

def outcomes (m : Nat) : List Nat → List (List Bool × Nat)
  | [] => [([], m)]
  | t :: ts =>
      let m1 := m &&& t
      let m0 := m ^^^ m1
      (if m0 == 0 then [] else
        (outcomes m0 ts).map fun p => (false :: p.1, p.2)) ++
      (if m1 == 0 then [] else
        (outcomes m1 ts).map fun p => (true :: p.1, p.2))

theorem lookupAssoc_append [BEq κ] (key : κ) (l₁ l₂ : List (κ × β)) :
    Execution.lookupAssoc key (l₁ ++ l₂) =
      (Execution.lookupAssoc key l₁).or (Execution.lookupAssoc key l₂) := by
  induction l₁ with
  | nil => simp [Execution.lookupAssoc]
  | cons entry l₁ ih =>
      rcases entry with ⟨k, v⟩
      cases h : key == k <;>
        simp [Execution.lookupAssoc, h, ih]

theorem lookupAssoc_map_consKey (b c : Bool) (w : List Bool)
    (xs : List (List Bool × Nat)) :
    Execution.lookupAssoc (b :: w) (xs.map fun p => (c :: p.1, p.2)) =
      if b == c then Execution.lookupAssoc w xs else none := by
  induction xs with
  | nil => cases b == c <;> simp [Execution.lookupAssoc]
  | cons p xs ih =>
      by_cases hbc : b = c
      · subst hbc
        simp [Execution.lookupAssoc, List.cons_beq_cons, ih]
      · have hbc' : (b == c) = false := by
          simpa using hbc
        simp [Execution.lookupAssoc, List.cons_beq_cons, ih, hbc']

theorem lookupAssoc_map_snd [BEq κ] (key : κ) (g : β → γ)
    (xs : List (κ × β)) :
    Execution.lookupAssoc key (xs.map fun p => (p.1, g p.2)) =
      (Execution.lookupAssoc key xs).map g := by
  induction xs with
  | nil => simp [Execution.lookupAssoc]
  | cons p xs ih =>
      cases h : key == p.1 <;>
        simp [Execution.lookupAssoc, h, ih]

theorem branch_lookup_ne (bkey c : Bool) (hne : bkey ≠ c) (w : List Bool)
    (mm : Nat) (ts : List Nat) :
    Execution.lookupAssoc (bkey :: w)
      (if mm == 0 then [] else
        (outcomes mm ts).map fun p => (c :: p.1, p.2)) = none := by
  by_cases h : mm == 0
  · rw [if_pos h]
    rfl
  · rw [if_neg h, lookupAssoc_map_consKey, if_neg]
    simpa using hne

theorem branch_lookup_eq (bkey : Bool) (w : List Bool) (mm : Nat)
    (ts : List Nat)
    (hrec : (Execution.lookupAssoc w (outcomes mm ts)).getD 0 =
      selMask mm ts w) :
    (Execution.lookupAssoc (bkey :: w)
      (if mm == 0 then [] else
        (outcomes mm ts).map fun p => (bkey :: p.1, p.2))).getD 0 =
      selMask mm ts w := by
  by_cases h : mm == 0
  · rw [if_pos h]
    have hz : mm = 0 := by simpa using h
    rw [hz, selMask_zero]
    rfl
  · rw [if_neg h, lookupAssoc_map_consKey,
      if_pos (by simp : (bkey == bkey) = true)]
    exact hrec

theorem outcomes_lookup (tbls : List Nat) (m : Nat) (w : List Bool)
    (hw : w.length = tbls.length) :
    (Execution.lookupAssoc w (outcomes m tbls)).getD 0 = selMask m tbls w := by
  induction tbls generalizing m w with
  | nil =>
      have hnil : w = [] := List.eq_nil_of_length_eq_zero hw
      subst hnil
      simp [outcomes, Execution.lookupAssoc, selMask]
  | cons t ts ih =>
      cases w with
      | nil => simp at hw
      | cons b w =>
          have hw' : w.length = ts.length := by simpa using hw
          simp only [outcomes, selMask]
          rw [lookupAssoc_append]
          cases b with
          | false =>
              rw [if_neg Bool.false_ne_true,
                branch_lookup_ne false true (by decide) w (m &&& t) ts,
                Option.or_none]
              exact branch_lookup_eq false w (m ^^^ (m &&& t)) ts
                (ih (m ^^^ (m &&& t)) w hw')
          | true =>
              rw [if_pos rfl,
                branch_lookup_ne true false (by decide) w
                  (m ^^^ (m &&& t)) ts,
                Option.none_or]
              exact branch_lookup_eq true w (m &&& t) ts
                (ih (m &&& t) w hw')

/-- Sparse `(outcome, count)` list for one secret's observation tables. -/
def sparseCounts (m : Nat) (tbls : List Nat) : List (List Bool × Nat) :=
  (outcomes m tbls).map fun p => (p.1, pop p.2)

theorem sparseCounts_lookup (tbls : List Nat) (m : Nat) (w : List Bool)
    (hw : w.length = tbls.length) :
    (Execution.lookupAssoc w (sparseCounts m tbls)).getD 0 =
      pop (selMask m tbls w) := by
  rw [sparseCounts, lookupAssoc_map_snd]
  have h := outcomes_lookup tbls m w hw
  cases hl : Execution.lookupAssoc w (outcomes m tbls) with
  | none =>
      rw [hl] at h
      simp only [Option.map_none, Option.getD_none] at h ⊢
      rw [← h, pop_zero]
  | some v =>
      rw [hl] at h
      simp only [Option.getD_some] at h
      simp only [Option.map_some, Option.getD_some]
      rw [h]

/-! ## Per-probe-set observation tables and the checker -/

/-- Per-node observation bit, exactly the body of `Gadget.observe`. -/
def obsFn (g : GadgetInstance) (node : Node) : Env → Bool := fun env =>
  if node.gate < g.circuit.gates.size && node.cycle < g.horizon then
    (Execution.lookupAssoc node
      (Execution.evalEntries g.circuit g.horizon env)).getD false
  else false

theorem observe_eq_obsFn_map (g : GadgetInstance) (ns : List Node)
    (env : Env) : observe g ns env = ns.map fun node => obsFn g node env := by
  rfl

/-- Packed observation tables of a probe set, one `E`-bit word per node. -/
def bitObserve (g : GadgetInstance) (trace : List (Node × Nat))
    (ns : List Node) : List Nat :=
  ns.map fun node =>
    if node.gate < g.circuit.gates.size && node.cycle < g.horizon then
      (Execution.lookupAssoc node trace).getD 0
    else 0

theorem bitObserve_eq (g : GadgetInstance) (es : List Env) (ns : List Node) :
    bitObserve g (bitEntries es g.circuit g.horizon) ns =
      ns.map fun node => packBits (es.map (obsFn g node)) := by
  unfold bitObserve
  apply List.map_congr_left
  intro node _
  by_cases hg : (node.gate < g.circuit.gates.size &&
      node.cycle < g.horizon) = true
  · rw [if_pos hg, lookup_bitEntries]
    congr 1
    apply List.map_congr_left
    intro e _
    simp only [obsFn]
    rw [if_pos hg]
  · rw [if_neg hg,
      show (0 : Nat) = packBits (es.map fun _ => false) from
        (packBits_map_false es).symm]
    congr 1
    apply List.map_congr_left
    intro e _
    simp only [obsFn]
    rw [if_neg hg]

theorem countObs_ne_length (g : GadgetInstance) (es : List Env)
    (ns : List Node) (w : Observation) (hw : w.length ≠ ns.length) :
    countObs es (observe g ns) w = 0 := by
  apply List.countP_eq_zero.mpr
  intro e _
  intro hbeq
  apply hw
  have heq : observe g ns e = w := by simpa using hbeq
  rw [← heq, observe_eq_obsFn_map, List.length_map]

/-- Per-secret count extraction: every outcome count of the audited
observation distribution is a lookup into the sparse count list computed
from the packed tables. -/
theorem countObs_eq_sparse (g : GadgetInstance) (es : List Env)
    (ns : List Node) (w : Observation) (hw : w.length = ns.length) :
    countObs es (observe g ns) w =
      (Execution.lookupAssoc w
        (sparseCounts (2 ^ es.length - 1)
          (bitObserve g (bitEntries es g.circuit g.horizon) ns))).getD 0 := by
  have hfs : (ns.map fun node => packBits (es.map (obsFn g node))) =
      (ns.map fun node => obsFn g node).map fun f => packBits (es.map f) := by
    rw [List.map_map]
    rfl
  have hlen : w.length = (ns.map fun node => obsFn g node).length := by
    rw [List.length_map]; exact hw
  rw [bitObserve_eq, hfs,
    sparseCounts_lookup _ _ w (by rw [List.length_map]; exact hlen),
    pop_selMask_count es _ w hlen]
  unfold countObs
  congr 1
  funext e
  rw [observe_eq_obsFn_map, List.map_map]
  rfl

/-- Per-secret packed experiment: environment count and packed trace. -/
def secretData (g : GadgetInstance) (secret : List Bool) :
    Nat × List (Node × Nat) :=
  let es := envsForSecret g secret
  (es.length, bitEntries es g.circuit g.horizon)

def bitExperiments (g : GadgetInstance) :
    List (List Bool × Nat × List (Node × Nat)) :=
  (boolVectors g.inputCount).map fun secret => (secret, secretData g secret)

/-- One observed node set: compare every secret's environment count and
sparse outcome counts against the base secret's. -/
def bitNodeCheck (g : GadgetInstance)
    (exps : List (List Bool × Nat × List (Node × Nat)))
    (ns : List Node) : Bool :=
  match exps with
  | [] => true
  | (_, base) :: _ =>
      exps.all fun (_, exp) =>
        exp.1 == base.1 &&
          sparseCounts (2 ^ exp.1 - 1) (bitObserve g exp.2 ns) ==
            sparseCounts (2 ^ base.1 - 1) (bitObserve g base.2 ns)

/-- One probe set: check its expanded node set. -/
def bitProbeCheck (g : GadgetInstance) (scheme : ExpansionScheme)
    (exps : List (List Bool × Nat × List (Node × Nat)))
    (probes : List Node) : Bool :=
  bitNodeCheck g exps (expandedNodes g scheme probes)

theorem bitNodeCheck_sound {g : GadgetInstance} {ns : List Node}
    (h : bitNodeCheck g (bitExperiments g) ns = true) :
    BaseInvariant (boolVectors g.inputCount) (envsForSecret g)
      (observe g ns) := by
  generalize hsecrets : boolVectors g.inputCount = secrets at h ⊢
  cases secrets with
  | nil => simp [BaseInvariant]
  | cons base rest =>
      simp only [BaseInvariant]
      intro secret hsecret
      have hmem : (secret, secretData g secret) ∈
          (base, secretData g base) ::
            rest.map (fun s => (s, secretData g s)) := by
        simp only [List.mem_cons, List.mem_map]
        rw [List.mem_cons] at hsecret
        rcases hsecret with heq | hsecret
        · subst secret
          exact Or.inl rfl
        · exact Or.inr ⟨secret, hsecret, rfl⟩
      simp only [bitNodeCheck, bitExperiments, hsecrets, List.map_cons,
        List.all_eq_true] at h
      have hcheck := h _ hmem
      rw [Bool.and_eq_true] at hcheck
      obtain ⟨hcnt, hsparse⟩ := hcheck
      have hlen : (envsForSecret g secret).length =
          (envsForSecret g base).length := by
        simpa [secretData] using hcnt
      have hsparse' :
          sparseCounts (2 ^ (envsForSecret g secret).length - 1)
            (bitObserve g
              (bitEntries (envsForSecret g secret) g.circuit g.horizon)
              ns) =
          sparseCounts (2 ^ (envsForSecret g base).length - 1)
            (bitObserve g
              (bitEntries (envsForSecret g base) g.circuit g.horizon)
              ns) := by
        simpa [secretData] using hsparse
      intro w
      rw [hlen]
      congr 1
      by_cases hw : w.length = ns.length
      · rw [countObs_eq_sparse g _ _ w hw, countObs_eq_sparse g _ _ w hw,
          hsparse']
      · rw [countObs_ne_length g _ _ w hw, countObs_ne_length g _ _ w hw]

theorem bitProbeCheck_sound {g : GadgetInstance} {scheme : ExpansionScheme}
    {probes : List Node}
    (h : bitProbeCheck g scheme (bitExperiments g) probes = true) :
    BaseInvariant (boolVectors g.inputCount) (envsForSecret g)
      (observe g (expandedNodes g scheme probes)) :=
  bitNodeCheck_sound h

/-- The bitsliced whole-circuit probing checker. -/
def bitChecker (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) : Bool :=
  let exps := bitExperiments g
  reachedCheck g &&
    (subsetsUpTo t (memberNodes g)).all (bitProbeCheck g scheme exps)

/-- Soundness against the audited specification; same route as
`checker_sound`. -/
theorem bitChecker_sound (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) (h : bitChecker g scheme t = true) :
    probingSecureSpec g scheme t := by
  have hparts : reachedCheck g = true ∧
      (subsetsUpTo t (memberNodes g)).all
        (bitProbeCheck g scheme (bitExperiments g)) = true := by
    simpa only [bitChecker, Bool.and_eq_true] using h
  have hreached := reachedCheck_sound hparts.1
  apply (probingSecure_iff_spec g scheme t hreached).mp
  apply (probingSecureFast_iff g scheme t hreached).mp
  intro probes hprobes
  exact bitProbeCheck_sound ((List.all_eq_true.mp hparts.2) probes hprobes)

/-! ## Subsumption dedupe (memo #2)

If every node of one observed set appears in another, the smaller
observation is a deterministic index-selection of the larger, so the larger
set's base invariance transfers (`distEq_map`).  `bitCheckerCert` verifies
an arbitrary caller-supplied list of covering node sets — soundness never
depends on how the cover was computed, so the maximality computation is
untrusted. -/

theorem getElem_idxOf_mem [BEq α] [LawfulBEq α] {l : List α} {a : α}
    (h : a ∈ l) :
    l[l.idxOf a]'(List.idxOf_lt_length_of_mem h) = a := by
  have hp := @List.findIdx_getElem _ (· == a) l
    (List.idxOf_lt_length_of_mem h)
  exact eq_of_beq hp

theorem observe_map_superset (g : GadgetInstance) (ns₁ ns₂ : List Node)
    (h : ∀ n ∈ ns₁, n ∈ ns₂) (env : Env) :
    ns₁.map (fun node =>
      (observe g ns₂ env).getD (ns₂.idxOf node) false) =
      observe g ns₁ env := by
  rw [observe_eq_obsFn_map g ns₁ env]
  apply List.map_congr_left
  intro node hmem
  have hin := h node hmem
  have hlt : ns₂.idxOf node < ns₂.length :=
    List.idxOf_lt_length_of_mem hin
  rw [observe_eq_obsFn_map g ns₂ env, List.getD_eq_getElem?_getD,
    List.getElem?_map, List.getElem?_eq_getElem hlt]
  simp only [Option.map_some, Option.getD_some]
  congr 1
  exact getElem_idxOf_mem hin

theorem distEq_congr {es₁ es₂ : List Env} {obs₁ obs₂ : Env → Observation}
    (hobs : obs₁ = obs₂) (h : distEq es₁ es₂ obs₁) :
    distEq es₁ es₂ obs₂ := by
  subst hobs
  exact h

theorem baseInvariant_superset (g : GadgetInstance)
    (secrets : List (List Bool)) (envsOf : List Bool → List Env)
    {ns₁ ns₂ : List Node} (h : ∀ n ∈ ns₁, n ∈ ns₂)
    (hinv : BaseInvariant secrets envsOf (observe g ns₂)) :
    BaseInvariant secrets envsOf (observe g ns₁) := by
  cases secrets with
  | nil => simp [BaseInvariant]
  | cons base rest =>
      simp only [BaseInvariant] at hinv ⊢
      intro x hx
      have hmapped := distEq_map
        (fun w => ns₁.map (fun node => w.getD (ns₂.idxOf node) false))
        (hinv x hx)
      apply distEq_congr _ hmapped
      funext env
      exact observe_map_superset g ns₁ ns₂ h env

def coveredBy (ns : List Node) (kept : List (List Node)) : Bool :=
  kept.any fun big => ns.all (big.contains ·)

/-- Certificate checker: verify each kept node set once, then verify that
every probe set's expansion is contained in some kept set. -/
def bitCheckerCert (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat)
    (kept : List (List Node)) : Bool :=
  let exps := bitExperiments g
  reachedCheck g &&
    kept.all (bitNodeCheck g exps) &&
    (subsetsUpTo t (memberNodes g)).all fun probes =>
      coveredBy (expandedNodes g scheme probes) kept

theorem bitCheckerCert_sound (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) (kept : List (List Node))
    (h : bitCheckerCert g scheme t kept = true) :
    probingSecureSpec g scheme t := by
  have h' := h
  simp only [bitCheckerCert, Bool.and_eq_true] at h'
  obtain ⟨⟨h1, h2⟩, h3⟩ := h'
  have hreached := reachedCheck_sound h1
  apply (probingSecure_iff_spec g scheme t hreached).mp
  apply (probingSecureFast_iff g scheme t hreached).mp
  intro probes hprobes
  have hcov := List.all_eq_true.mp h3 probes hprobes
  simp only [coveredBy, List.any_eq_true] at hcov
  obtain ⟨big, hbig, hsub⟩ := hcov
  apply baseInvariant_superset g _ _ ?_
    (bitNodeCheck_sound (List.all_eq_true.mp h2 big hbig))
  intro n hn
  have hc := List.all_eq_true.mp hsub n hn
  simpa using hc

/-- Untrusted cover computation: distinct expansions, then only the
⊆-maximal ones. -/
def maximalSets (sets : List (List Node)) : List (List Node) :=
  let d := sets.eraseDups
  d.filter fun ns => !(d.any fun other =>
    ns.all (other.contains ·) && !(other.all (ns.contains ·)))

def dedupExpansions (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) : List (List Node) :=
  maximalSets ((subsetsUpTo t (memberNodes g)).map (expandedNodes g scheme))

/-- Fully automatic dedup checker: sound for ANY cover, so `maximalSets`
needs no correctness proof. -/
def bitCheckerDedup (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) : Bool :=
  bitCheckerCert g scheme t (dedupExpansions g scheme t)

theorem bitCheckerDedup_sound (g : GadgetInstance)
    (scheme : ExpansionScheme) (t : Nat)
    (h : bitCheckerDedup g scheme t = true) : probingSecureSpec g scheme t :=
  bitCheckerCert_sound g scheme t _ h

#print axioms bitChecker_sound
#print axioms bitCheckerCert_sound
#print axioms bitCheckerDedup_sound

end LeanSec.Checker.Bitslice
