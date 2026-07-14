import LeanSec.Gadget

namespace LeanSec.Checker

open Gadget

/-- Lexicographic order used only to canonicalize finite observation multisets. -/
def observationLE : Observation → Observation → Bool
  | [], _ => true
  | _ :: _, [] => false
  | false :: xs, false :: ys => observationLE xs ys
  | false :: _, true :: _ => true
  | true :: _, false :: _ => false
  | true :: xs, true :: ys => observationLE xs ys

/-- Kernel-reducible insertion into a canonical observation list. -/
def insertObservation (x : Observation) : List Observation → List Observation
  | [] => [x]
  | y :: ys =>
      if observationLE x y then x :: y :: ys
      else y :: insertObservation x ys

theorem insertObservation_perm (x : Observation) (xs : List Observation) :
    (insertObservation x xs).Perm (x :: xs) := by
  induction xs with
  | nil => rfl
  | cons y ys ih =>
      simp only [insertObservation]
      split
      · rfl
      · exact (ih.cons y).trans (List.Perm.swap x y ys)

/-- A kernel-reducible canonicalization.  Unlike the library merge sorter,
this definition can be evaluated by `decide` without a compiler-trust axiom. -/
def sortObservations : List Observation → List Observation
  | [] => []
  | x :: xs => insertObservation x (sortObservations xs)

theorem sortObservations_perm (xs : List Observation) :
    (sortObservations xs).Perm xs := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
      exact (insertObservation_perm x (sortObservations xs)).trans (ih.cons x)

def sortedSamples (es : List Env) (obs : Env → Observation) :
    List Observation :=
  sortObservations (es.map obs)

/-- Fast equality test for two finite observation multisets. -/
def sameSamples (es₁ es₂ : List Env) (obs : Env → Observation) : Bool :=
  sortedSamples es₁ obs == sortedSamples es₂ obs

theorem sameSamples_perm {es₁ es₂ : List Env} {obs : Env → Observation}
    (h : sameSamples es₁ es₂ obs = true) :
    (es₁.map obs).Perm (es₂.map obs) := by
  have heq : sortedSamples es₁ obs = sortedSamples es₂ obs := by
    simpa only [sameSamples, beq_iff_eq] using h
  have hp₁ : (es₁.map obs).Perm (sortedSamples es₁ obs) := by
    exact (sortObservations_perm _).symm
  have hp₂ : (sortedSamples es₂ obs).Perm (es₂.map obs) := by
    exact sortObservations_perm _
  exact hp₁.trans ((List.Perm.of_eq heq).trans hp₂)

theorem sameSamples_sound {es₁ es₂ : List Env} {obs : Env → Observation}
    (h : sameSamples es₁ es₂ obs = true) : distEq es₁ es₂ obs := by
  have hp := sameSamples_perm h
  have hlen : es₁.length = es₂.length := by
    simpa using hp.length_eq
  intro w
  have hcount : countObs es₁ obs w = countObs es₂ obs w := by
    simpa [countObs, List.count_eq_countP, List.countP_map,
      Function.comp_def] using hp.count w
  simp [hlen, hcount]

/-- Check that all secret-conditioned experiment lists are nonempty. -/
def reachedCheck (g : GadgetInstance) : Bool :=
  (boolVectors g.inputCount).all fun secret =>
    !(envsForSecret g secret).isEmpty

theorem reachedCheck_sound {g : GadgetInstance}
    (h : reachedCheck g = true) :
    ∀ secret ∈ boolVectors g.inputCount,
      (envsForSecret g secret).length > 0 := by
  intro secret hsecret
  have hnonempty := (List.all_eq_true.mp h) secret hsecret
  apply List.length_pos_iff.mpr
  simpa [reachedCheck] using hnonempty

theorem reachedCheck_complete {g : GadgetInstance}
    (h : ∀ secret ∈ boolVectors g.inputCount,
      (envsForSecret g secret).length > 0) : reachedCheck g = true := by
  simp only [reachedCheck, List.all_eq_true]
  intro secret hsecret
  have hpos := h secret hsecret
  simpa [List.length_pos_iff] using hpos

/-- One-probe-set check: compare every secret distribution only with a single
base distribution, and compare canonical sorted samples rather than repeatedly
counting every support element. -/
def probeCheck (g : GadgetInstance) (scheme : ExpansionScheme)
    (probes : List Node) : Bool :=
  match boolVectors g.inputCount with
  | [] => true
  | base :: _ =>
      (boolVectors g.inputCount).all fun secret =>
        sameSamples (envsForSecret g base) (envsForSecret g secret)
          (observe g (expandedNodes g scheme probes))

theorem probeCheck_sound {g : GadgetInstance} {scheme : ExpansionScheme}
    {probes : List Node} (h : probeCheck g scheme probes = true) :
    BaseInvariant (boolVectors g.inputCount) (envsForSecret g)
      (observe g (expandedNodes g scheme probes)) := by
  generalize hsecrets : boolVectors g.inputCount = secrets at h ⊢
  cases secrets with
  | nil => simp [probeCheck, BaseInvariant, hsecrets]
  | cons base rest =>
      simp only [probeCheck, BaseInvariant, hsecrets, List.all_eq_true] at h ⊢
      intro secret hsecret
      exact sameSamples_sound (h secret hsecret)

abbrev Trace := List (Node × Bool)

/-- Evaluate a circuit once; probe observations are projected from this trace. -/
def traceFor (g : GadgetInstance) (env : Env) : Trace :=
  Execution.evalEntries g.circuit g.horizon env

def observeTrace (g : GadgetInstance) (ns : List Node)
    (trace : Trace) : Observation :=
  ns.map fun node =>
    if node.gate < g.circuit.gates.size && node.cycle < g.horizon then
      (Execution.lookupAssoc node trace).getD false
    else false

theorem observeTrace_traceFor (g : GadgetInstance) (ns : List Node)
    (env : Env) : observeTrace g ns (traceFor g env) = observe g ns env := by
  rfl

def secretTraces (g : GadgetInstance) (secret : List Bool) : List Trace :=
  (envsForSecret g secret).map (traceFor g)

def traceSamples (g : GadgetInstance) (ns : List Node)
    (traces : List Trace) : List Observation :=
  traces.map (observeTrace g ns)

def sameObservationLists (xs ys : List Observation) : Bool :=
  sortObservations xs == sortObservations ys

theorem sameObservationLists_perm {xs ys : List Observation}
    (h : sameObservationLists xs ys = true) : xs.Perm ys := by
  have heq : sortObservations xs = sortObservations ys := by
    simpa only [sameObservationLists, beq_iff_eq] using h
  exact (sortObservations_perm xs).symm.trans
    ((List.Perm.of_eq heq).trans (sortObservations_perm ys))

theorem traceSamples_eq_envSamples (g : GadgetInstance) (ns : List Node)
    (secret : List Bool) :
    traceSamples g ns (secretTraces g secret) =
      (envsForSecret g secret).map (observe g ns) := by
  simp [traceSamples, secretTraces, List.map_map, Function.comp_def,
    observeTrace_traceFor]

theorem sameTraceSamples_sound {g : GadgetInstance} {ns : List Node}
    {left right : List Bool}
    (h : sameObservationLists
      (traceSamples g ns (secretTraces g left))
      (traceSamples g ns (secretTraces g right)) = true) :
    distEq (envsForSecret g left) (envsForSecret g right) (observe g ns) := by
  have hp := sameObservationLists_perm h
  rw [traceSamples_eq_envSamples, traceSamples_eq_envSamples] at hp
  have hlen : (envsForSecret g left).length =
      (envsForSecret g right).length := by
    simpa using hp.length_eq
  intro w
  have hcount : countObs (envsForSecret g left) (observe g ns) w =
      countObs (envsForSecret g right) (observe g ns) w := by
    simpa [countObs, List.count_eq_countP, List.countP_map,
      Function.comp_def] using hp.count w
  simp [hlen, hcount]

def experiments (g : GadgetInstance) : List (List Bool × List Trace) :=
  (boolVectors g.inputCount).map fun secret => (secret, secretTraces g secret)

/-- Probe check over pre-evaluated traces. -/
def cachedProbeCheck (g : GadgetInstance) (scheme : ExpansionScheme)
    (exps : List (List Bool × List Trace)) (probes : List Node) : Bool :=
  match exps with
  | [] => true
  | (_, baseTraces) :: _ =>
      exps.all fun (_, traces) =>
        sameObservationLists
          (traceSamples g (expandedNodes g scheme probes) baseTraces)
          (traceSamples g (expandedNodes g scheme probes) traces)

theorem cachedProbeCheck_sound {g : GadgetInstance}
    {scheme : ExpansionScheme} {probes : List Node}
    (h : cachedProbeCheck g scheme (experiments g) probes = true) :
    BaseInvariant (boolVectors g.inputCount) (envsForSecret g)
      (observe g (expandedNodes g scheme probes)) := by
  generalize hsecrets : boolVectors g.inputCount = secrets at h ⊢
  cases secrets with
  | nil => simp [BaseInvariant, hsecrets]
  | cons base rest =>
      simp only [BaseInvariant]
      intro secret hsecret
      have hentry : (secret, secretTraces g secret) ∈
          (base, secretTraces g base) ::
            rest.map (fun s => (s, secretTraces g s)) := by
        simp only [List.mem_cons, List.mem_map]
        rw [List.mem_cons] at hsecret
        rcases hsecret with heq | hsecret
        · subst secret
          exact Or.inl rfl
        · exact Or.inr ⟨secret, hsecret, rfl⟩
      simp only [cachedProbeCheck, experiments, hsecrets, List.map_cons,
        List.all_eq_true] at h
      exact sameTraceSamples_sound (h _ hentry)

/-- Verified probing checker.  Reachability is checked, not assumed; a `true`
result therefore implies the existing audited `probingSecureSpec` directly. -/
def checker (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Bool :=
  let exps := experiments g
  reachedCheck g &&
    (subsetsUpTo t (memberNodes g)).all (cachedProbeCheck g scheme exps)

theorem checker_sound (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat)
    (h : checker g scheme t = true) : probingSecureSpec g scheme t := by
  have hparts : reachedCheck g = true ∧
      (subsetsUpTo t (memberNodes g)).all
        (cachedProbeCheck g scheme (experiments g)) = true := by
    simpa only [checker, Bool.and_eq_true] using h
  have hreached := reachedCheck_sound hparts.1
  apply (probingSecure_iff_spec g scheme t hreached).mp
  apply (probingSecureFast_iff g scheme t hreached).mp
  intro probes hprobes
  exact cachedProbeCheck_sound
    ((List.all_eq_true.mp hparts.2) probes hprobes)

/-- Granular variant intended for one kernel proof per probe. -/
def splitChecker (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Bool :=
  reachedCheck g &&
    (subsetsUpTo t (memberNodes g)).all (probeCheck g scheme)

theorem splitChecker_sound (g : GadgetInstance)
    (scheme : ExpansionScheme) (t : Nat)
    (h : splitChecker g scheme t = true) : probingSecureSpec g scheme t := by
  have hparts : reachedCheck g = true ∧
      (subsetsUpTo t (memberNodes g)).all (probeCheck g scheme) = true := by
    simpa only [splitChecker, Bool.and_eq_true] using h
  have hreached := reachedCheck_sound hparts.1
  apply (probingSecure_iff_spec g scheme t hreached).mp
  apply (probingSecureFast_iff g scheme t hreached).mp
  intro probes hprobes
  exact probeCheck_sound ((List.all_eq_true.mp hparts.2) probes hprobes)

/-- Little-endian packing used to keep concrete trace certificates compact. -/
def packBits : List Bool → Nat
  | [] => 0
  | bit :: bits => (if bit then 1 else 0) + 2 * packBits bits

def unpackBits : Nat → Nat → List Bool
  | 0, _ => []
  | n + 1, value => (value % 2 == 1) :: unpackBits n (value / 2)

abbrev PackedCertificate := List (List Bool × List Nat)

def traceNodes (g : GadgetInstance) : List Node :=
  (traceFor g fun _ => false).map Prod.fst

def inflateTrace (g : GadgetInstance) (packed : Nat) : Trace :=
  (traceNodes g).zip (unpackBits (traceNodes g).length packed)

def inflateCertificate (g : GadgetInstance)
    (certificate : PackedCertificate) : List (List Bool × List Trace) :=
  certificate.map fun (secret, traces) =>
    (secret, traces.map (inflateTrace g))

/-- Proof-carrying fast path.  The first equality validates every supplied
packed execution trace against the real evaluator exactly once.  Subsequent
probe checks reuse only those validated traces. -/
def certificateChecker (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) (certificate : PackedCertificate) : Bool :=
  let inflated := inflateCertificate g certificate
  reachedCheck g &&
    inflated == experiments g &&
      (subsetsUpTo t (memberNodes g)).all
        (cachedProbeCheck g scheme inflated)

theorem certificateChecker_sound (g : GadgetInstance)
    (scheme : ExpansionScheme) (t : Nat) (certificate : PackedCertificate)
    (h : certificateChecker g scheme t certificate = true) :
    probingSecureSpec g scheme t := by
  have hparts : (reachedCheck g = true ∧
      inflateCertificate g certificate = experiments g) ∧
      (subsetsUpTo t (memberNodes g)).all
        (cachedProbeCheck g scheme (inflateCertificate g certificate)) = true := by
    simpa only [certificateChecker, Bool.and_eq_true, beq_iff_eq] using h
  have hreached := reachedCheck_sound hparts.1.1
  apply (probingSecure_iff_spec g scheme t hreached).mp
  apply (probingSecureFast_iff g scheme t hreached).mp
  intro probes hprobes
  apply cachedProbeCheck_sound
  rw [← hparts.1.2]
  exact (List.all_eq_true.mp hparts.2) probes hprobes

#print axioms sameSamples_sound
#print axioms checker_sound
#print axioms splitChecker_sound
#print axioms certificateChecker_sound

end LeanSec.Checker
