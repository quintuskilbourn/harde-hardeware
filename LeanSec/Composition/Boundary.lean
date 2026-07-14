import LeanSec.Composition.Defs

namespace LeanSec
namespace Composition

open Gadget

/-- Every well-formed gadget is O-PINI at order zero.  This small base case is
useful for separating structural wiring obligations from security
certificates: even genuine O-PINI hypotheses do not manufacture a semantic
equation between an upstream output node and a downstream external source. -/
theorem opiniSpec_zero (g : GadgetInstance) (scheme : ExpansionScheme)
    (hwf : g.WF) : opiniSpec g scheme 0 := by
  refine ⟨hwf, ?_⟩
  intro internal hinternal outputs houtputs
  have hinternalNil : internal = [] := by
    simpa [subsetsUpTo, combinations] using hinternal
  subst internal
  have houtputsNil : outputs = [] := by
    simpa [subsetsUpTo, combinations] using houtputs
  subst outputs
  refine ⟨[], by simp [subsetsUpTo, combinations], ?_⟩
  refine ⟨fun _ => [[]], by simp, ?_⟩
  intro x hx observation
  cases observation <;> simp [expandedNodes, observe, countObs]

/-- The finite space of `d`-share XOR encodings of `secret`. -/
def xorSharings (d : Nat) (secret : Bool) : List (List Bool) :=
  (boolVectors d).filter fun sharing => xorList sharing == secret

/-- Selecting fewer than all shares from an XOR sharing gives exactly the
same multiset for either secret.  This is the boundary-independence fact used
by the randomized composition argument: it is permutation-level (hence
distribution-level), rather than merely an equality of total cardinalities. -/
theorem boundaryProjection_secret_independent (d : Nat) (shares : List Nat)
    (hshares : shares.Sublist (List.range d)) (hsmall : shares.length < d) :
    ((xorSharings d false).map (selectBits shares)).Perm
      ((xorSharings d true).map (selectBits shares)) := by
  rw [List.perm_iff_count]
  intro q
  rw [List.count_eq_countP, List.count_eq_countP, List.countP_map,
    List.countP_map]
  change ((xorSharings d false).countP fun sharing =>
      selectBits shares sharing == q) =
    ((xorSharings d true).countP fun sharing =>
      selectBits shares sharing == q)
  rw [List.countP_eq_length_filter, List.countP_eq_length_filter]
  simpa [xorSharings, sharingFiber, List.countP_filter,
    Bool.and_comm] using
    xorSharing_secret_independent d shares hshares hsmall q

/-- Run an arbitrary randomized continuation using only the selected boundary
shares.  This is the finite multiset denoted by first drawing a uniform XOR
sharing of `secret`, hiding every share outside `shares`, and then invoking
`kernel` on the visible projection. -/
def boundaryKernelSamples (d : Nat) (secret : Bool) (shares : List Nat)
    (kernel : List Bool → List Observation) : List Observation :=
  ((xorSharings d secret).map (selectBits shares)).flatMap kernel

/-- Boundary secrecy is stable under arbitrary randomized downstream
processing that sees fewer than all shares.  Thus the independence lemma is
strong enough for a probabilistic second-stage simulator, rather than only a
deterministic map of the boundary. -/
theorem boundaryKernel_secret_independent (d : Nat) (shares : List Nat)
    (hshares : shares.Sublist (List.range d)) (hsmall : shares.length < d)
    (kernel : List Bool → List Observation) :
    (boundaryKernelSamples d false shares kernel).Perm
      (boundaryKernelSamples d true shares kernel) := by
  exact (boundaryProjection_secret_independent d shares hshares hsmall).flatMap_right
    kernel

/-- Interpret a one-bit secret as a uniformly random XOR sharing, reveal only
`shares`, and run the randomized continuation `kernel` on that projection.
The definition is total on lists so that it fits the finite-simulator API;
the security theorem below restricts it to `boolVectors 1`. -/
def boundaryKernelExperimentSamples (d : Nat) (shares : List Nat)
    (kernel : List Bool → List Observation) :
    List Bool → List Observation
  | secret :: _ => boundaryKernelSamples d secret shares kernel
  | [] => boundaryKernelSamples d false shares kernel

/-- A nonempty randomized continuation produces a nonempty boundary
experiment.  This is the normalization side condition required by
`SamplesSimulatableOn`; it follows from the existence of an XOR sharing for
each secret, not from secrecy alone. -/
theorem boundaryKernelSamples_ne_nil (d : Nat) (secret : Bool)
    (shares : List Nat) (kernel : List Bool → List Observation)
    (hd : 0 < d) (hkernel : ∀ q, kernel q ≠ []) :
    boundaryKernelSamples d secret shares kernel ≠ [] := by
  have hprojections :
      ((xorSharings d secret).map (selectBits shares)) ≠ [] := by
    simpa [xorSharings, sharingProjections] using
      sharingProjections_ne_nil d hd secret shares
  rcases List.exists_mem_of_ne_nil _ hprojections with ⟨q, hq⟩
  rcases List.exists_mem_of_ne_nil _ (hkernel q) with ⟨w, hw⟩
  apply List.ne_nil_of_mem
  exact List.mem_flatMap.mpr ⟨q, hq, hw⟩

/-- Canonical set union of two share-index lists, ordered as `List.range d` so
that it remains an admissible `subsetsUpTo` choice.  The component O-PINI
witnesses are lists because the executable specification enumerates finite
subsets; serial propagation needs their mathematical union. -/
def shareUnion (d : Nat) (left right : List Nat) : List Nat :=
  (List.range d).filter fun share => left.contains share || right.contains share

theorem shareUnion_sublist (d : Nat) (left right : List Nat) :
    (shareUnion d left right).Sublist (List.range d) := by
  exact List.filter_sublist

theorem shareUnion_length_le (d : Nat) (left right : List Nat)
    (hleft : ∀ share ∈ left, share < d)
    (hright : ∀ share ∈ right, share < d) :
    (shareUnion d left right).length ≤ left.length + right.length := by
  have hcanonical : (shareUnion d left right).Nodup :=
    List.nodup_range.filter _
  have hdedup : (left ++ right).eraseDups.Nodup := eraseDups_nodup _
  have hp : (shareUnion d left right).Perm (left ++ right).eraseDups := by
    rw [List.perm_iff_count]
    intro share
    rw [hcanonical.count, hdedup.count]
    congr 1
    simp only [shareUnion, List.mem_filter, List.mem_range,
      Bool.or_eq_true, List.contains_iff_mem, List.mem_eraseDups, List.mem_append]
    apply propext
    constructor
    · rintro ⟨_, hleftMem | hrightMem⟩
      · exact Or.inl hleftMem
      · exact Or.inr hrightMem
    · intro hmem
      refine ⟨?_, hmem⟩
      exact hmem.elim (hleft share) (hright share)
  rw [hp.length_eq]
  simpa using eraseDups_length_le (left ++ right)

/-- Simulatability stated directly for the finite multiset of observations.
Unlike `SimulatableOn`, this exact form has no ambient `Env`; it is the right
interface for connecting two experiments whose samples are pairs of component
environments.  Uniform experiment cardinality lets us pass from
`SimulatableOn` to this form below. -/
def SamplesSimulatableOn (xs : List (List Bool))
    (projI : List Bool → List Bool)
    (samples : List Bool → List Observation) : Prop :=
  ∃ S : List Bool → List Observation,
    (∀ x ∈ xs, (S (projI x)).length > 0) ∧
    ∀ x ∈ xs, (samples x).Perm (S (projI x))

/-- The CS21 hidden-boundary argument as an exact simulator certificate.
For a positive share count, any strict subset of a uniformly random XOR
sharing can be fed to an arbitrary nonempty randomized downstream kernel,
and the resulting whole experiment is simulatable without seeing the secret.

This packages `boundaryKernel_secret_independent` in the same interface used
by the serial two-certificate assembler, including its nonempty-distribution
obligation. -/
theorem boundaryKernelExperiment_simulatable (d : Nat) (shares : List Nat)
    (hshares : shares.Sublist (List.range d)) (hsmall : shares.length < d)
    (kernel : List Bool → List Observation)
    (hkernel : ∀ q, kernel q ≠ []) :
    SamplesSimulatableOn (boolVectors 1) (fun _ => [])
      (boundaryKernelExperimentSamples d shares kernel) := by
  have hd : 0 < d := by omega
  let simulator : List Bool → List Observation := fun _ =>
    boundaryKernelSamples d false shares kernel
  refine ⟨simulator, ?_, ?_⟩
  · intro x hx
    apply List.ne_nil_iff_length_pos.mp
    exact boundaryKernelSamples_ne_nil d false shares kernel hd hkernel
  · intro x hx
    simp [boolVectors] at hx
    rcases hx with rfl | rfl
    · exact List.Perm.refl _
    · simpa [boundaryKernelExperimentSamples, simulator] using
        (boundaryKernel_secret_independent d shares hshares hsmall kernel).symm

/-- An exact finite-sample simulator is already a simulator in the audited
`SimulatableOn` sense when its concrete samples are obtained by mapping an
observation over the experiment environments.  Exact permutation supplies
both the count equality and the normalization (length) equality required by
the cross-multiplied definition. -/
theorem samplesSimulatableOn_to_simulatableOn
    {xs : List (List Bool)} {envsOf : List Bool → List Env}
    {projI : List Bool → List Bool} {obs : Env → Observation}
    (hsim : SamplesSimulatableOn xs projI
      (fun x => (envsOf x).map obs)) :
    SimulatableOn xs envsOf projI obs := by
  rcases hsim with ⟨S, hpositive, hperm⟩
  refine ⟨S, hpositive, ?_⟩
  intro x hx w
  have hp := hperm x hx
  have hlength : (envsOf x).length = (S (projI x)).length := by
    simpa using hp.length_eq
  have hcount : countObs (envsOf x) obs w = (S (projI x)).count w := by
    rw [← hp.count w]
    simp [countObs, List.count_eq_countP, List.countP_map,
      Function.comp_def]
  rw [hcount, hlength]

/-- A `SimulatableOn` certificate over equally-sized, reached experiments can
be represented by one exact observation multiset for each projection. -/
theorem simulatableOn_to_samples
    {xs : List (List Bool)} {envsOf : List Bool → List Env}
    {projI : List Bool → List Bool} {obs : Env → Observation}
    (hreached : ∀ x ∈ xs, (envsOf x).length > 0)
    (hcard : ∀ x ∈ xs, ∀ y ∈ xs,
      (envsOf x).length = (envsOf y).length)
    (hsim : SimulatableOn xs envsOf projI obs) :
    SamplesSimulatableOn xs projI (fun x => (envsOf x).map obs) := by
  classical
  have hinvariant :=
    (simulatable_iff_countInvariant xs envsOf projI obs hreached).mp hsim
  let representative : List Bool → List Bool := fun q =>
    if h : ∃ x ∈ xs, projI x = q then Classical.choose h else []
  let S : List Bool → List Observation := fun q =>
    (envsOf (representative q)).map obs
  have hrepresentative (x : List Bool) (hx : x ∈ xs) :
      representative (projI x) ∈ xs ∧
        projI (representative (projI x)) = projI x := by
    have hex : ∃ y ∈ xs, projI y = projI x := ⟨x, hx, rfl⟩
    exact ⟨by simp [representative, hex, Classical.choose_spec hex],
      by simp [representative, hex, Classical.choose_spec hex]⟩
  refine ⟨S, ?_, ?_⟩
  · intro x hx
    have hrep := hrepresentative x hx
    simpa [S] using hreached _ hrep.1
  · intro x hx
    have hrep := hrepresentative x hx
    apply observation_samples_perm_of_distEq
    · exact hcard x hx _ hrep.1
    · exact hreached x hx
    · exact hinvariant x hx _ hrep.1 hrep.2.symm

/-- Expose an O-PINI certificate as an exact finite-sample simulator.  The
conversion is valid because every full-input experiment is reached and all
such experiments enumerate the same number of environments. -/
theorem opiniSpec_to_samples (g : GadgetInstance)
    (scheme : ExpansionScheme) (t : Nat) (hopini : opiniSpec g scheme t) :
    ∀ internal ∈ subsetsUpTo t (internalNodes g),
      ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range g.d),
        ∃ b ∈ subsetsUpTo internal.length (List.range g.d),
          SamplesSimulatableOn (boolVectors (inputWidth g))
            (projection g (outputs ++ b))
            (fun x => (envsForInput g x).map
              (observe g ((expandedNodes g scheme
                (internal ++ outputs.map g.output)) ++
                  b.map g.output).eraseDups)) := by
  intro internal hinternal outputs houtputs
  obtain ⟨b, hb, hsim⟩ := hopini.2 internal hinternal outputs houtputs
  refine ⟨b, hb, simulatableOn_to_samples ?_ ?_ hsim⟩
  · intro x hx
    exact List.ne_nil_iff_length_pos.mp
      (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))
  · intro x hx y hy
    exact envsForInput_cardinality g x y

/-- Apply a finite randomized kernel to every sample.  The emitted value may
retain the first-stage transcript (serial composition uses `(· ++ ·)`). -/
def bindSamples (samples : List Bool → List Observation)
    (kernel : Observation → List Observation)
    (emit : Observation → Observation → Observation) :
    List Bool → List Observation := fun x =>
  (samples x).flatMap fun first => (kernel first).map (emit first)

/-- General randomized-boundary composition for exact finite simulators.
The kernel can branch probabilistically and can depend on the simulated
boundary outcome.  This is the simulator-assembly step missing from the
deterministic lemma: the composite simulator is the first simulator followed
by the very same downstream kernel. -/
theorem samplesSimulatableOn_bind
    {xs : List (List Bool)} {projI : List Bool → List Bool}
    {samples : List Bool → List Observation}
    (kernel : Observation → List Observation)
    (emit : Observation → Observation → Observation)
    (hkernel : ∀ first, kernel first ≠ [])
    (hsim : SamplesSimulatableOn xs projI samples) :
    SamplesSimulatableOn xs projI (bindSamples samples kernel emit) := by
  rcases hsim with ⟨S, hpositive, hperm⟩
  let composed : List Bool → List Observation := fun q =>
    (S q).flatMap fun first => (kernel first).map (emit first)
  refine ⟨composed, ?_, ?_⟩
  · intro x hx
    have hS : S (projI x) ≠ [] :=
      List.ne_nil_of_length_pos (hpositive x hx)
    rcases List.exists_mem_of_ne_nil _ hS with ⟨first, hfirst⟩
    rcases List.exists_mem_of_ne_nil _ (hkernel first) with ⟨second, hsecond⟩
    apply List.length_pos_of_mem
    exact List.mem_flatMap.mpr ⟨first, hfirst,
      List.mem_map.mpr ⟨second, hsecond, rfl⟩⟩
  · intro x hx
    exact (hperm x hx).flatMap_right fun first =>
      (kernel first).map (emit first)

/-- Assemble two component simulators.  The downstream component's concrete
conditional sample multiset need not be deterministic: it only has to be a
permutation of the kernel supplied by its certificate for every boundary
outcome. -/
theorem samplesSimulatableOn_bind_congr
    {xs : List (List Bool)} {projI : List Bool → List Bool}
    {firstSamples : List Bool → List Observation}
    (secondSamples secondSimulator : Observation → List Observation)
    (emit : Observation → Observation → Observation)
    (hsecond : ∀ first,
      (secondSamples first).Perm (secondSimulator first))
    (hsecond_nonempty : ∀ first, secondSimulator first ≠ [])
    (hfirst : SamplesSimulatableOn xs projI firstSamples) :
    SamplesSimulatableOn xs projI
      (bindSamples firstSamples secondSamples emit) := by
  obtain ⟨S, hpositive, hsimulated⟩ :=
    samplesSimulatableOn_bind secondSimulator emit hsecond_nonempty hfirst
  refine ⟨S, hpositive, ?_⟩
  intro x hx
  apply List.Perm.trans ?_ (hsimulated x hx)
  apply flatMap_perm_of_pointwise
  intro first hfirstMem
  exact (hsecond first).map (emit first)

/-- A dependent randomized bind for a connected experiment.  The concrete
second-stage experiment may depend on the entire composite input `x`, while
its simulator is allowed to depend only on the public simulator index
`projI x` and the first-stage transcript.  This is the interface needed by a
serial O-PINI proof: the index carries selected shares of the downstream
*external* inputs, and the first transcript carries the selected connected
boundary shares emitted by the upstream O-PINI simulator. -/
def bindSamplesOn (firstSamples : List Bool → List Observation)
    (secondSamples : List Bool → Observation → List Observation)
    (emit : Observation → Observation → Observation) :
    List Bool → List Observation := fun x =>
  (firstSamples x).flatMap fun first =>
    (secondSamples x first).map (emit first)

/-- Assemble exact simulators across a randomized connected boundary while
retaining dependence on the permitted projection of external composite
inputs.  Unlike `samplesSimulatableOn_bind_congr`, the downstream conditional
experiment can vary with `x`; the pointwise permutation premise proves that
all such variation is captured by `projI x` and the simulated boundary
transcript. -/
theorem samplesSimulatableOn_dependent_bind_congr
    {xs : List (List Bool)} {projI : List Bool → List Bool}
    {firstSamples : List Bool → List Observation}
    (secondSamples : List Bool → Observation → List Observation)
    (secondSimulator : List Bool → Observation → List Observation)
    (emit : Observation → Observation → Observation)
    (hsecond : ∀ x ∈ xs, ∀ first,
      (secondSamples x first).Perm
        (secondSimulator (projI x) first))
    (hsecond_nonempty : ∀ q first, secondSimulator q first ≠ [])
    (hfirst : SamplesSimulatableOn xs projI firstSamples) :
    SamplesSimulatableOn xs projI
      (bindSamplesOn firstSamples secondSamples emit) := by
  rcases hfirst with ⟨S, hpositive, hsimulated⟩
  let composed : List Bool → List Observation := fun q =>
    (S q).flatMap fun first =>
      (secondSimulator q first).map (emit first)
  refine ⟨composed, ?_, ?_⟩
  · intro x hx
    have hS : S (projI x) ≠ [] :=
      List.ne_nil_of_length_pos (hpositive x hx)
    rcases List.exists_mem_of_ne_nil _ hS with ⟨first, hfirstMem⟩
    rcases List.exists_mem_of_ne_nil _
        (hsecond_nonempty (projI x) first) with ⟨second, hsecondMem⟩
    apply List.length_pos_of_mem
    exact List.mem_flatMap.mpr ⟨first, hfirstMem,
      List.mem_map.mpr ⟨second, hsecondMem, rfl⟩⟩
  · intro x hx
    apply List.Perm.trans ?_ ((hsimulated x hx).flatMap_right fun first =>
      (secondSimulator (projI x) first).map (emit first))
    apply flatMap_perm_of_pointwise
    intro first hfirstMem
    exact (hsecond x hx first).map (emit first)

/-- Compose two exact component certificates across a factorized connected
experiment.  `firstInput` embeds a composite external input into the upstream
component experiment.  After an upstream transcript has been sampled,
`secondInput` supplies the downstream component's full input, including its
random connected boundary.

The two `...Key` functions express the essential wiring/factorization fact:
each component projection is reconstructible from the permitted composite
projection and (for the downstream component) the simulated upstream
transcript.  Unlike `samplesSimulatableOn_dependent_bind_congr`, this theorem
does not assume a pointwise downstream simulator: it consumes the second
component's `SamplesSimulatableOn` certificate and constructs that conditional
simulator itself. -/
theorem samplesSimulatableOn_dependent_compose
    {firstXs secondXs xs : List (List Bool)}
    {firstProjection secondProjection projection :
      List Bool → List Bool}
    {firstSamples secondSamples : List Bool → List Observation}
    (firstInput : List Bool → List Bool)
    (secondInput : List Bool → Observation → List Bool)
    (firstKey : List Bool → List Bool)
    (secondKey : List Bool → Observation → List Bool)
    (emit : Observation → Observation → Observation)
    (hfirstInput : ∀ x ∈ xs, firstInput x ∈ firstXs)
    (hfirstProjection : ∀ x ∈ xs,
      firstProjection (firstInput x) = firstKey (projection x))
    (hsecondInput : ∀ x ∈ xs, ∀ first ∈ firstSamples (firstInput x),
      secondInput x first ∈ secondXs)
    (hsecondProjection : ∀ x ∈ xs,
      ∀ first ∈ firstSamples (firstInput x),
        secondProjection (secondInput x first) =
          secondKey (projection x) first)
    (hfirst : SamplesSimulatableOn firstXs firstProjection firstSamples)
    (hsecond : SamplesSimulatableOn secondXs secondProjection secondSamples) :
    SamplesSimulatableOn xs projection
      (bindSamplesOn
        (fun x => firstSamples (firstInput x))
        (fun x first => secondSamples (secondInput x first)) emit) := by
  rcases hfirst with ⟨firstSimulator, hfirstPositive, hfirstPerm⟩
  rcases hsecond with ⟨secondSimulator, hsecondPositive, hsecondPerm⟩
  let composed : List Bool → List Observation := fun q =>
    (firstSimulator (firstKey q)).flatMap fun first =>
      (secondSimulator (secondKey q first)).map (emit first)
  refine ⟨composed, ?_, ?_⟩
  · intro x hx
    have hxFirst := hfirstInput x hx
    have hfirstNonempty : firstSimulator (firstKey (projection x)) ≠ [] := by
      apply List.ne_nil_of_length_pos
      simpa [hfirstProjection x hx] using hfirstPositive (firstInput x) hxFirst
    rcases List.exists_mem_of_ne_nil _ hfirstNonempty with
      ⟨first, hfirstSimulatorMem⟩
    have hfirstConcreteMem : first ∈ firstSamples (firstInput x) := by
      exact (hfirstPerm (firstInput x) hxFirst).mem_iff.mpr
        (by simpa [hfirstProjection x hx] using hfirstSimulatorMem)
    have hxSecond := hsecondInput x hx first hfirstConcreteMem
    have hsecondNonempty :
        secondSimulator (secondKey (projection x) first) ≠ [] := by
      apply List.ne_nil_of_length_pos
      simpa [hsecondProjection x hx first hfirstConcreteMem] using
        hsecondPositive (secondInput x first) hxSecond
    rcases List.exists_mem_of_ne_nil _ hsecondNonempty with
      ⟨second, hsecondSimulatorMem⟩
    apply List.length_pos_of_mem
    exact List.mem_flatMap.mpr ⟨first, hfirstSimulatorMem,
      List.mem_map.mpr ⟨second, hsecondSimulatorMem, rfl⟩⟩
  · intro x hx
    have hxFirst := hfirstInput x hx
    have hfirstPermKey :
        (firstSamples (firstInput x)).Perm
          (firstSimulator (firstKey (projection x))) := by
      simpa [hfirstProjection x hx] using
        hfirstPerm (firstInput x) hxFirst
    change
      ((firstSamples (firstInput x)).flatMap fun first =>
          (secondSamples (secondInput x first)).map (emit first)).Perm
        ((firstSimulator (firstKey (projection x))).flatMap fun first =>
          (secondSimulator (secondKey (projection x) first)).map (emit first))
    apply List.Perm.trans ?_
      (hfirstPermKey.flatMap_right fun first =>
        (secondSimulator (secondKey (projection x) first)).map (emit first))
    apply flatMap_perm_of_pointwise
    intro first hfirstMem
    have hxSecond := hsecondInput x hx first hfirstMem
    have hperm := (hsecondPerm (secondInput x first) hxSecond).map (emit first)
    simpa [hsecondProjection x hx first hfirstMem] using hperm

/-- Whole serial transcript specialization of
`samplesSimulatableOn_bind`. -/
theorem samplesSimulatableOn_randomized_serial
    {xs : List (List Bool)} {projI : List Bool → List Bool}
    {firstSamples : List Bool → List Observation}
    (next : Observation → List Observation)
    (hnext : ∀ first, next first ≠ [])
    (hfirst : SamplesSimulatableOn xs projI firstSamples) :
    SamplesSimulatableOn xs projI
      (bindSamples firstSamples next fun first second => first ++ second) := by
  exact samplesSimulatableOn_bind next (fun first second => first ++ second)
    hnext hfirst

/-- Transcript of two serial stages when the second transcript is computed
from the boundary transcript emitted by the first. -/
def deterministicSerialObservation
    (first : Env → Observation) (next : Observation → Observation)
    (env : Env) : Observation :=
  first env ++ next (first env)

/-- A genuine, deliberately restricted serial-composition rule for
`SimulatableOn`: deterministic processing of an already simulatable boundary
does not reveal more input information. -/
theorem simulatableOn_deterministic_serial
    {xs : List (List Bool)} {envsOf : List Bool → List Env}
    {projI : List Bool → List Bool}
    {first second : Env → Observation}
    (next : Observation → Observation)
    (hfirst : SimulatableOn xs envsOf projI first)
    (hboundary : ∀ env, second env = next (first env)) :
    SimulatableOn xs envsOf projI
      (fun env => first env ++ second env) := by
  have hmapped := simulatableOn_map (fun w => w ++ next w) hfirst
  have hobs :
      (fun env => first env ++ next (first env)) =
        (fun env => first env ++ second env) := by
    funext env
    rw [hboundary env]
  rw [hobs] at hmapped
  exact hmapped

end Composition
end LeanSec
