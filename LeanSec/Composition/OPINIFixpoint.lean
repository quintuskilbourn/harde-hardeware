import LeanSec.Composition.OPINIClosure
import Lean

namespace LeanSec
namespace Composition

open Gadget
open UniversalReg

/-! # The O-PINI producer-reuse fixpoint

`compose_pini` closes the serial splice by carrying PINI.  The O-PINI
analogue was blocked by a witness-feedback loop: the tail witness fixes the
upstream demand, whose witness must in turn be observable at the tail
output, which re-selects the tail witness.  This module closes that loop
with a *demand-uniform* strengthening of O-PINI: the witness may depend on
the internal probes but not on the output demand.  The uniform certificate
is reproduced by the registered splice (`compose_uniform_opini`), implies
the unmodified audited `opiniSpec`, and is implied by `opiniSpec` at the
degenerate demand multiplicities of order one, so all existing order-one
O-PINI leaves lift unchanged.
-/

/-! ## Access to file-private proof infrastructure

The following command aliases already-kernel-checked declarations that are
syntactically `private` to `LeanSec/Composition/Pipeline.lean`.  No audited
file is modified and no proof is assumed: each alias is definitionally the
original constant, so `#print axioms` output is unchanged. -/

open Lean Elab Command in
elab "expose_private " newName:ident " from " suffix:str : command => do
  let suffixStr := suffix.getString
  let env ← getEnv
  let mut found : Option Name := none
  for (n, _) in env.constants.toList do
    if isPrivateName n && n.toString.endsWith ("." ++ suffixStr) then
      found := some n
      break
  match found with
  | none => throwError "no private constant matching {suffixStr}"
  | some n =>
    let ci := env.constants.find! n
    let lvls := ci.levelParams
    let value := mkConst n (lvls.map mkLevelParam)
    let newN ← liftCoreM <| Lean.mkConstWithLevelParams n *> pure newName.getId
    let decl :=
      if ci.type.isProp then
        Declaration.thmDecl { name := newN, levelParams := lvls, type := ci.type, value := value }
      else
        Declaration.defnDecl { name := newN, levelParams := lvls, type := ci.type, value := value, hints := .abbrev, safety := .safe }
    liftCoreM <| addDecl decl
    if !ci.type.isProp then
      liftCoreM <| Lean.setReducibilityStatus newN .reducible

expose_private pvtEmbeddedTailNode from "Pipeline.0.LeanSec.Composition.embeddedTailNode"
expose_private pvtBoundaryAssignment from "Pipeline.0.LeanSec.Composition.boundaryAssignment"
expose_private pvtShiftedTailAssignment from "Pipeline.0.LeanSec.Composition.shiftedTailAssignment"
expose_private pvtProjectionEqOfBits from "Pipeline.0.LeanSec.Composition.projection_eq_of_bits"
expose_private pvtInputBitEq from "Pipeline.0.LeanSec.Composition.inputBit_eq_of_projection_eq"
expose_private pvtObservationAt from "Pipeline.0.LeanSec.Composition.observationAt_observe_of_mem"
expose_private pvtHideLt from "Pipeline.0.LeanSec.Composition.hideRegisteredInput_lt"
expose_private pvtReconstructNodeEq from "Pipeline.0.LeanSec.Composition.reconstructPipelineNode_eq_eval"
expose_private pvtTailGateLt from "Pipeline.0.LeanSec.Composition.tailTranscriptNode_gate_lt"
expose_private pvtMemberNodeBounds from "Pipeline.0.LeanSec.Composition.memberNode_bounds"
expose_private pvtOutputMember from "Pipeline.0.LeanSec.Composition.pipeline_output_member"
expose_private pvtEnvsCells from "Pipeline.0.LeanSec.Composition.envsForInput_eq_cellAssignments"
expose_private pvtPatternKeys from "Pipeline.0.LeanSec.Composition.assignmentsPattern_keys"
expose_private pvtAssignmentEnvMem from "Pipeline.0.LeanSec.Composition.assignmentEnv_mem"
expose_private pvtProductEnvMem from "Pipeline.0.LeanSec.Composition.productEnv_mem"
expose_private pvtRestrictProductUp from "Pipeline.0.LeanSec.Composition.restrictEnv_product_up_eq"
expose_private pvtSubstAgrees from "Pipeline.0.LeanSec.Composition.substitutedTailEnv_product_agrees"
expose_private pvtBoundaryInitFalse from "Pipeline.0.LeanSec.Composition.composite_env_boundaryInit_false"

/-! ## The demand-uniform O-PINI certificate -/

/-- Demand-uniform O-PINI.  Exactly `opiniSpec` except that one witness `b`
is selected per internal probe set and must serve *every* admissible output
demand.  Both the projection and the observation are the unmodified audited
forms. -/
def uniformOpiniSpec (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat) : Prop :=
  g.WF ∧
    ∀ internal ∈ subsetsUpTo t (internalNodes g),
      ∃ b ∈ subsetsUpTo internal.length (List.range g.d),
        ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range g.d),
          SimulatableOn (boolVectors (inputWidth g)) (envsForInput g)
            (projection g (outputs ++ b))
            (observe g ((expandedNodes g scheme
              (internal ++ outputs.map g.output)) ++ b.map g.output).eraseDups)

/-- Demand-uniform O-PINI implies the audited O-PINI by exchanging the
quantifiers. -/
theorem uniformOpini_implies_opini (g : GadgetInstance)
    (scheme : ExpansionScheme) (t : Nat)
    (h : uniformOpiniSpec g scheme t) : opiniSpec g scheme t := by
  refine ⟨h.1, ?_⟩
  intro internal hinternal outputs houtputs
  obtain ⟨b, hb, hall⟩ := h.2 internal hinternal
  exact ⟨b, hb, hall outputs houtputs⟩

private theorem length_le_zero_eq_nil {xs : List α} (h : xs.length ≤ 0) :
    xs = [] := by
  cases xs with
  | nil => rfl
  | cons head tail => simp at h

/-- At order at most one, every demand multiplicity is degenerate: an empty
internal probe set forces the empty witness, and a full internal probe set
forces the empty demand.  The audited O-PINI certificate is therefore
already demand-uniform. -/
theorem opini_implies_uniform_of_le_one (g : GadgetInstance)
    (scheme : ExpansionScheme) (t : Nat) (ht : t ≤ 1)
    (h : opiniSpec g scheme t) : uniformOpiniSpec g scheme t := by
  refine ⟨h.1, ?_⟩
  intro internal hinternal
  have hbound := subsetsUpTo_bound _ _ _ hinternal
  cases internal with
  | nil =>
      refine ⟨[], mem_subsetsUpTo_of_sublist (List.nil_sublist _)
        (Nat.le_refl 0), ?_⟩
      intro outputs houtputs
      obtain ⟨b, hb, hsim⟩ := h.2 [] hinternal outputs houtputs
      have hbnil : b = [] :=
        length_le_zero_eq_nil (subsetsUpTo_bound _ _ _ hb)
      subst hbnil
      exact hsim
  | cons probe rest =>
      have hrest : rest = [] := by
        have : rest.length ≤ 0 := by
          simp only [List.length_cons] at hbound
          omega
        exact length_le_zero_eq_nil this
      subst hrest
      have hone : (1 : Nat) ≤ t := by simpa using hbound
      have hteq : t = 1 := by omega
      subst hteq
      obtain ⟨b, hb, hsim⟩ := h.2 [probe] hinternal []
        (mem_subsetsUpTo_of_sublist (List.nil_sublist _) (Nat.zero_le _))
      refine ⟨b, hb, ?_⟩
      intro outputs houtputs
      have houtputsNil : outputs = [] :=
        length_le_zero_eq_nil (by
          simpa using subsetsUpTo_bound _ _ _ houtputs)
      subst houtputsNil
      exact hsim

/-! ## Small share-set and node-set toolkit -/

theorem mem_shareUnion_iff (d : Nat) (left right : List Nat) (share : Nat) :
    share ∈ shareUnion d left right ↔
      share < d ∧ (share ∈ left ∨ share ∈ right) := by
  simp [shareUnion, List.mem_filter, List.mem_range, List.contains_iff_mem]

/-- Membership-level monotonicity of the expansion in its probe list. -/
theorem expandedNodes_mono (g : GadgetInstance) (scheme : ExpansionScheme)
    {probes probes' : List Node}
    (hsub : ∀ probe ∈ probes, probe ∈ probes') :
    ∀ node ∈ expandedNodes g scheme probes,
      node ∈ expandedNodes g scheme probes' := by
  intro node hnode
  simp only [expandedNodes, List.mem_eraseDups, List.mem_filter,
    List.mem_flatMap] at hnode ⊢
  obtain ⟨⟨probe, hprobe, hexp⟩, hmem⟩ := hnode
  exact ⟨⟨probe, hsub probe hprobe, hexp⟩, hmem⟩

/-- `PipelineNodeCovered` is monotone in the transported tail transcript. -/
theorem pipelineNodeCovered_mono_tail {H d t : Nat}
    (up tail : PipelineGadget H d t) (upNodes : List Node)
    {tailNodes tailNodes' : List Node}
    (hsub : ∀ node ∈ tailNodes, node ∈ tailNodes') (node : Node)
    (h : PipelineNodeCovered up tail upNodes tailNodes node) :
    PipelineNodeCovered up tail upNodes tailNodes' node := by
  rcases h with h | ⟨tailNode, hmem, heq⟩ | h | h
  · exact Or.inl h
  · exact Or.inr (Or.inl ⟨tailNode, hsub tailNode hmem, heq⟩)
  · exact Or.inr (Or.inr (Or.inl h))
  · exact Or.inr (Or.inr (Or.inr h))

private theorem pvtEmbeddedTailNode_def {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down) (node : Node) :
    pvtEmbeddedTailNode up ports node =
      { gate := embeddedTailGate up ports node.gate, cycle := node.cycle } :=
  rfl

set_option maxHeartbeats 8000000 in
/-- **The O-PINI producer-reuse closure crux.**  Two demand-uniform O-PINI
certificates assemble into a demand-uniform O-PINI certificate for the
registered composite.  The composite witness is the canonical union of the
component witnesses with the boundary demands; because component witnesses
do not move with the demand, the previously circular witness-feedback
equation is closed by construction: the tail is invoked at the enlarged
demand `outputs ∪ upB ∪ boundary`, so every composite witness share is
exposed at the composite output, while the upstream demand is unchanged
from `compose_pini` and no probe budget is inflated. -/
theorem compose_uniform_opini {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : uniformOpiniSpec up.g transitionGlitch t)
    (htail : uniformOpiniSpec tail.g transitionGlitch t)
    (glue : PortGlue up tail) :
    uniformOpiniSpec (registeredComposite up.g tail.ports)
      transitionGlitch t := by
  classical
  let composite := registeredComposite up.g tail.ports
  refine ⟨registeredComposite_wf up tail, ?_⟩
  intro internal hinternal
  have hinternalSub : internal.Sublist (internalNodes composite) :=
    subsetsUpTo_sublist _ _ _ hinternal
  have hinternalBound := subsetsUpTo_bound _ _ _ hinternal
  let upInternal := partitionUpInternal up internal
  let tailInternal := partitionTailInternal up tail internal
  let boundary := partitionUpDemands up tail internal
  have hupInternal : upInternal.Sublist (internalNodes up.g) :=
    partitionUpInternal_sublist up internal
  have htailInternal : tailInternal.Sublist (internalNodes tail.g) :=
    partitionTailInternal_sublist up tail internal
  have hboundary : boundary.Sublist (List.range d) :=
    partitionUpDemands_sublist up tail internal
  have hpartition := expansion_partition_length up tail internal
  have hupLen : upInternal.length ≤ internal.length :=
    partitionUpInternal_length_le up internal
  have htailLen : tailInternal.length ≤ internal.length :=
    partitionTailInternal_length_le up tail internal
  -- component uniform witnesses, selected before any output demand
  obtain ⟨upB, hupB, hupUniform⟩ := hup.2 upInternal
    (mem_subsetsUpTo_of_sublist hupInternal (by omega))
  obtain ⟨tailB, htailB, htailUniform⟩ := htail.2 tailInternal
    (mem_subsetsUpTo_of_sublist htailInternal (by omega))
  have hupBBound := subsetsUpTo_bound _ _ _ hupB
  have htailBBound := subsetsUpTo_bound _ _ _ htailB
  have hupBMem : ∀ share ∈ upB, share < d := by
    intro share hshare
    have := (subsetsUpTo_sublist _ _ _ hupB).mem hshare
    have : share < up.g.d := by simpa using this
    simpa [up.d_eq] using this
  have htailBMem : ∀ share ∈ tailB, share < d := by
    intro share hshare
    have := (subsetsUpTo_sublist _ _ _ htailB).mem hshare
    have : share < tail.g.d := by simpa using this
    simpa [tail.d_eq] using this
  have hboundaryMem : ∀ share ∈ boundary, share < d := by
    intro share hshare
    simpa using hboundary.mem hshare
  -- the composite uniform witness
  let finalB := shareUnion d (shareUnion d tailB upB) boundary
  have hinnerLen := shareUnion_length_le d tailB upB htailBMem hupBMem
  have hinnerMem : ∀ share ∈ shareUnion d tailB upB, share < d := by
    intro share hshare
    simpa using (shareUnion_sublist d tailB upB).mem hshare
  have hfinalLen := shareUnion_length_le d
    (shareUnion d tailB upB) boundary hinnerMem hboundaryMem
  have hpartitionL : upInternal.length + boundary.length +
      tailInternal.length ≤ internal.length := hpartition
  have hfinalBound : finalB.length ≤ internal.length := by
    have h1 : finalB.length ≤
        (shareUnion d tailB upB).length + boundary.length := hfinalLen
    have h2 : (shareUnion d tailB upB).length ≤
        tailB.length + upB.length := hinnerLen
    omega
  have hfinalSub : finalB.Sublist (List.range d) :=
    shareUnion_sublist d (shareUnion d tailB upB) boundary
  have hfinalMem : ∀ share ∈ finalB, share < d := by
    intro share hshare
    simpa using hfinalSub.mem hshare
  refine ⟨finalB, mem_subsetsUpTo_of_sublist
    (by simpa [composite, registeredComposite, tail.d_eq] using hfinalSub)
    hfinalBound, ?_⟩
  intro outputs houtputs
  have houtputsSub : outputs.Sublist (List.range d) := by
    simpa [composite, registeredComposite, tail.d_eq] using
      subsetsUpTo_sublist _ _ _ houtputs
  have houtputsBound := subsetsUpTo_bound _ _ _ houtputs
  have houtputsMem : ∀ share ∈ outputs, share < d := by
    intro share hshare
    simpa using houtputsSub.mem hshare
  -- demands: the tail also exposes the upstream witness and boundary shares
  let tailDemand := propagatedShares d outputs upB boundary
  let demanded := propagatedShares d outputs tailB boundary
  have htailDemandSub : tailDemand.Sublist (List.range d) :=
    shareUnion_sublist d (shareUnion d outputs upB) boundary
  have hdemandedSub : demanded.Sublist (List.range d) :=
    shareUnion_sublist d (shareUnion d outputs tailB) boundary
  have htailDemandMem : ∀ share ∈ tailDemand, share < d := by
    intro share hshare
    simpa using htailDemandSub.mem hshare
  have hdemandedMem : ∀ share ∈ demanded, share < d := by
    intro share hshare
    simpa using hdemandedSub.mem hshare
  have houterUpLen := shareUnion_length_le d outputs upB houtputsMem hupBMem
  have houterUpMem : ∀ share ∈ shareUnion d outputs upB, share < d := by
    intro share hshare
    simpa using (shareUnion_sublist d outputs upB).mem hshare
  have htailDemandLen := shareUnion_length_le d
    (shareUnion d outputs upB) boundary houterUpMem hboundaryMem
  have houterTailLen := shareUnion_length_le d outputs tailB
    houtputsMem htailBMem
  have houterTailMem : ∀ share ∈ shareUnion d outputs tailB, share < d := by
    intro share hshare
    simpa using (shareUnion_sublist d outputs tailB).mem hshare
  have hdemandedLen := shareUnion_length_le d
    (shareUnion d outputs tailB) boundary houterTailMem hboundaryMem
  have houtBudget : outputs.length ≤ t - internal.length := by
    simpa using houtputsBound
  -- budget admissibility of both component demands
  have htailDemandSet : tailDemand ∈
      subsetsUpTo (t - tailInternal.length) (List.range tail.g.d) := by
    apply mem_subsetsUpTo_of_sublist
      (by simpa [tail.d_eq] using htailDemandSub)
    have h1 : tailDemand.length ≤
        (shareUnion d outputs upB).length + boundary.length := htailDemandLen
    have h2 : (shareUnion d outputs upB).length ≤
        outputs.length + upB.length := houterUpLen
    omega
  have hdemandedSet : demanded ∈
      subsetsUpTo (t - upInternal.length) (List.range up.g.d) := by
    apply mem_subsetsUpTo_of_sublist
      (by simpa [up.d_eq] using hdemandedSub)
    have h1 : demanded.length ≤
        (shareUnion d outputs tailB).length + boundary.length := hdemandedLen
    have h2 : (shareUnion d outputs tailB).length ≤
        outputs.length + tailB.length := houterTailLen
    omega
  -- invoke both uniform certificates
  have htailSim := htailUniform tailDemand htailDemandSet
  have hupSim := hupUniform demanded hdemandedSet
  let upCertNodes := upstreamCertificateNodes up upInternal demanded upB
  let tailCertNodes := upstreamCertificateNodes tail tailInternal
    tailDemand tailB
  let upFullNodes := upstreamTranscriptNodes up upInternal demanded upB
  let tailFullNodes := upstreamTranscriptNodes tail tailInternal
    tailDemand tailB
  have hupSamples : SamplesSimulatableOn (boolVectors (inputWidth up.g))
      (projection up.g (demanded ++ upB))
      (fun x => (envsForInput up.g x).map (observe up.g upCertNodes)) := by
    have := simulatableOn_to_samples
      (fun x _ => List.ne_nil_iff_length_pos.mp
        (envsForInput_ne_nil_of_valid up.g x (fixingForInput_valid up.g x)))
      (fun x _ y _ => envsForInput_cardinality up.g x y) hupSim
    simpa [upCertNodes, upstreamCertificateNodes] using this
  have htailSamples : SamplesSimulatableOn (boolVectors (inputWidth tail.g))
      (projection tail.g (tailDemand ++ tailB))
      (fun x => (envsForInput tail.g x).map (observe tail.g tailCertNodes)) := by
    have := simulatableOn_to_samples
      (fun x _ => List.ne_nil_iff_length_pos.mp
        (envsForInput_ne_nil_of_valid tail.g x (fixingForInput_valid tail.g x)))
      (fun x _ y _ => envsForInput_cardinality tail.g x y) htailSim
    simpa [tailCertNodes, upstreamCertificateNodes] using this
  -- share bookkeeping
  let desiredShares := outputs ++ finalB
  let desiredProjection := projection composite desiredShares
  let upShares := demanded ++ upB
  let tailShares := tailDemand ++ tailB
  have htailFinal : ∀ share ∈ tailB, share ∈ finalB := by
    intro share hshare
    exact (mem_shareUnion_iff d _ _ share).mpr
      ⟨htailBMem share hshare, Or.inl ((mem_shareUnion_iff d _ _ share).mpr
        ⟨htailBMem share hshare, Or.inl hshare⟩)⟩
  have hupFinal : ∀ share ∈ upB, share ∈ finalB := by
    intro share hshare
    exact (mem_shareUnion_iff d _ _ share).mpr
      ⟨hupBMem share hshare, Or.inl ((mem_shareUnion_iff d _ _ share).mpr
        ⟨hupBMem share hshare, Or.inr hshare⟩)⟩
  have hboundaryFinal : ∀ share ∈ boundary, share ∈ finalB := by
    intro share hshare
    exact (mem_shareUnion_iff d _ _ share).mpr
      ⟨hboundaryMem share hshare, Or.inr hshare⟩
  have htailDemandCases : ∀ share ∈ tailDemand,
      share ∈ outputs ∨ share ∈ upB ∨ share ∈ boundary := by
    intro share hshare
    have h1 := (mem_shareUnion_iff d _ _ share).mp hshare
    rcases h1.2 with hinner | hbd
    · rcases ((mem_shareUnion_iff d _ _ share).mp hinner).2 with h | h
      · exact Or.inl h
      · exact Or.inr (Or.inl h)
    · exact Or.inr (Or.inr hbd)
  have hdemandedCases : ∀ share ∈ demanded,
      share ∈ outputs ∨ share ∈ tailB ∨ share ∈ boundary := by
    intro share hshare
    have h1 := (mem_shareUnion_iff d _ _ share).mp hshare
    rcases h1.2 with hinner | hbd
    · rcases ((mem_shareUnion_iff d _ _ share).mp hinner).2 with h | h
      · exact Or.inl h
      · exact Or.inr (Or.inl h)
    · exact Or.inr (Or.inr hbd)
  have houtputsDemanded : ∀ share ∈ outputs, share ∈ demanded := by
    intro share hshare
    exact (mem_shareUnion_iff d _ _ share).mpr
      ⟨houtputsMem share hshare, Or.inl ((mem_shareUnion_iff d _ _ share).mpr
        ⟨houtputsMem share hshare, Or.inl hshare⟩)⟩
  have htailBDemanded : ∀ share ∈ tailB, share ∈ demanded := by
    intro share hshare
    exact (mem_shareUnion_iff d _ _ share).mpr
      ⟨htailBMem share hshare, Or.inl ((mem_shareUnion_iff d _ _ share).mpr
        ⟨htailBMem share hshare, Or.inr hshare⟩)⟩
  have hboundaryDemanded : ∀ share ∈ boundary, share ∈ demanded := by
    intro share hshare
    exact (mem_shareUnion_iff d _ _ share).mpr
      ⟨hboundaryMem share hshare, Or.inr hshare⟩
  have houtputsTailDemand : ∀ share ∈ outputs, share ∈ tailDemand := by
    intro share hshare
    exact (mem_shareUnion_iff d _ _ share).mpr
      ⟨houtputsMem share hshare, Or.inl ((mem_shareUnion_iff d _ _ share).mpr
        ⟨houtputsMem share hshare, Or.inl hshare⟩)⟩
  have hupBTailDemand : ∀ share ∈ upB, share ∈ tailDemand := by
    intro share hshare
    exact (mem_shareUnion_iff d _ _ share).mpr
      ⟨hupBMem share hshare, Or.inl ((mem_shareUnion_iff d _ _ share).mpr
        ⟨hupBMem share hshare, Or.inr hshare⟩)⟩
  have hboundaryTailDemand : ∀ share ∈ boundary, share ∈ tailDemand := by
    intro share hshare
    exact (mem_shareUnion_iff d _ _ share).mpr
      ⟨hboundaryMem share hshare, Or.inr hshare⟩
  have hupDesired : ∀ share ∈ upShares, share ∈ desiredShares := by
    intro share hshare
    rcases List.mem_append.mp hshare with hdem | hupBShare
    · rcases hdemandedCases share hdem with h | h | h
      · exact List.mem_append_left _ h
      · exact List.mem_append_right _ (htailFinal share h)
      · exact List.mem_append_right _ (hboundaryFinal share h)
    · exact List.mem_append_right _ (hupFinal share hupBShare)
  have htailDesired : ∀ share ∈ tailShares, share ∈ desiredShares := by
    intro share hshare
    rcases List.mem_append.mp hshare with hdem | htailBShare
    · rcases htailDemandCases share hdem with h | h | h
      · exact List.mem_append_left _ h
      · exact List.mem_append_right _ (hupFinal share h)
      · exact List.mem_append_right _ (hboundaryFinal share h)
    · exact List.mem_append_right _ (htailFinal share htailBShare)
  have htailSharesUpExposed : ∀ share ∈ tailShares,
      share ∈ demanded ∨ share ∈ upB := by
    intro share hshare
    rcases List.mem_append.mp hshare with hdem | htailBShare
    · rcases htailDemandCases share hdem with h | h | h
      · exact Or.inl (houtputsDemanded share h)
      · exact Or.inr h
      · exact Or.inl (hboundaryDemanded share h)
    · exact Or.inl (htailBDemanded share htailBShare)
  -- transcript membership facts
  have hupOutputMemFull : ∀ share, share ∈ demanded ∨ share ∈ upB →
      up.g.output share ∈ upFullNodes := by
    intro share hshare
    simp only [upFullNodes, upstreamTranscriptNodes, List.mem_eraseDups,
      List.mem_append, List.mem_map]
    rcases hshare with h | h
    · exact Or.inl (Or.inr ⟨share, h, rfl⟩)
    · exact Or.inr ⟨share, h, rfl⟩
  have htailOutputMemFull : ∀ share, share ∈ tailDemand ∨ share ∈ tailB →
      tail.g.output share ∈ tailFullNodes := by
    intro share hshare
    simp only [tailFullNodes, upstreamTranscriptNodes, List.mem_eraseDups,
      List.mem_append, List.mem_map]
    rcases hshare with h | h
    · exact Or.inl (Or.inr ⟨share, h, rfl⟩)
    · exact Or.inr ⟨share, h, rfl⟩
  have hfinalTailExposed : ∀ share ∈ finalB,
      share ∈ tailDemand ∨ share ∈ tailB := by
    intro share hshare
    have h1 := (mem_shareUnion_iff d _ _ share).mp hshare
    rcases h1.2 with hinner | hbd
    · rcases ((mem_shareUnion_iff d _ _ share).mp hinner).2 with h | h
      · exact Or.inr h
      · exact Or.inl (hupBTailDemand share h)
    · exact Or.inl (hboundaryTailDemand share hbd)
  have htailNodesBase : ∀ node ∈ tailTranscriptNodes tail tailInternal outputs,
      node ∈ tailFullNodes := by
    intro node hnode
    have hstep : node ∈ expandedNodes tail.g transitionGlitch
        (tailInternal ++ tailDemand.map tail.g.output) := by
      apply expandedNodes_mono tail.g transitionGlitch
        (probes := tailInternal ++ outputs.map tail.g.output) ?_ node
      · simpa [tailTranscriptNodes] using hnode
      · intro probe hprobe
        rcases List.mem_append.mp hprobe with h | h
        · exact List.mem_append_left _ h
        · rcases List.mem_map.mp h with ⟨share, hshare, rfl⟩
          exact List.mem_append_right _
            (List.mem_map.mpr ⟨share, houtputsTailDemand share hshare, rfl⟩)
    simp only [tailFullNodes, upstreamTranscriptNodes, List.mem_eraseDups,
      List.mem_append]
    exact Or.inl (Or.inl hstep)
  have htailBound : ∀ tailNode ∈ tailFullNodes,
      tailNode.gate < tail.g.circuit.gates.size := by
    intro tailNode htailNode
    simp only [tailFullNodes, upstreamTranscriptNodes, List.mem_eraseDups,
      List.mem_append, List.mem_map] at htailNode
    rcases htailNode with (hexp | hdem) | hwit
    · refine pvtTailGateLt up tail tailInternal (tailDemand.map tail.g.output)
        htailInternal ?_ tailNode hexp
      have : tailDemand.Sublist (List.range tail.g.d) := by
        simpa [tail.d_eq] using htailDemandSub
      simpa [outputNodes] using this.map tail.g.output
    · rcases hdem with ⟨share, hshare, rfl⟩
      exact (pvtMemberNodeBounds tail.g _
        (pvtOutputMember tail share (htailDemandMem share hshare))).1
    · rcases hwit with ⟨share, hshare, rfl⟩
      exact (pvtMemberNodeBounds tail.g _
        (pvtOutputMember tail share (htailBMem share hshare))).1
  -- the composite O-PINI node list
  let baseNodes := expandedNodes composite transitionGlitch
    (internal ++ outputs.map composite.output)
  let compositeNodesO := (baseNodes ++ finalB.map composite.output).eraseDups
  -- static coverage of every composite O-PINI coordinate
  have hcoverage : ∀ node ∈ compositeNodesO,
      node.cycle < H ∧
        PipelineNodeCovered up tail upFullNodes tailFullNodes node := by
    intro node hnode
    simp only [compositeNodesO, List.mem_eraseDups, List.mem_append] at hnode
    rcases hnode with hbase | hextra
    · have hcov := expansion_partition_coverage up tail internal outputs
        tailB upB hinternalSub houtputsSub node hbase
      exact ⟨hcov.1, pipelineNodeCovered_mono_tail up tail upFullNodes
        htailNodesBase node hcov.2⟩
    · rcases List.mem_map.mp hextra with ⟨share, hshare, rfl⟩
      have hshareD : share < d := hfinalMem share hshare
      have hbounds := pvtMemberNodeBounds tail.g _
        (pvtOutputMember tail share hshareD)
      have hcycleH : (tail.g.output share).cycle < H := by
        have := hbounds.2
        simpa [tail.horizon_eq] using this
      have houtCycle : (composite.output share).cycle =
          (tail.g.output share).cycle := by
        simp [composite, registeredComposite]
      refine ⟨by simpa [houtCycle] using hcycleH, ?_⟩
      cases hconn : connectedShare? tail.ports (tail.g.output share).gate with
      | none =>
          refine Or.inr (Or.inl ⟨tail.g.output share,
            htailOutputMemFull share (hfinalTailExposed share hshare), ?_⟩)
          show pvtEmbeddedTailNode up.g tail.ports (tail.g.output share) =
            composite.output share
          rw [pvtEmbeddedTailNode_def]
          simp [embeddedTailGate, hconn, composite, registeredComposite]
      | some connectedShare =>
          refine Or.inr (Or.inr (Or.inr ⟨(tail.g.output share).gate,
            hbounds.1, by simp [hconn], ?_⟩))
          simp [composite, registeredComposite]
  -- the deterministic composite decoder
  let emit : Observation → Observation → Observation :=
    fun upValues tailValues =>
      reconstructPipelineObservation up tail upFullNodes tailFullNodes
        compositeNodesO
        (decodeUpstreamObservation up upInternal demanded upB upValues)
        (decodeUpstreamObservation tail tailInternal tailDemand tailB
          tailValues)
  -- first stage: reindex the upstream certificate to composite inputs
  have hfirst : SamplesSimulatableOn
      (boolVectors (inputWidth composite)) desiredProjection
      (fun x => (envsForInput up.g (pipelineUpInput up tail x)).map
        (observe up.g upCertNodes)) := by
    apply samplesSimulatableOn_reindex
      (sourceXs := boolVectors (inputWidth up.g))
      (xs := boolVectors (inputWidth composite))
      (sourceProjection := projection up.g upShares)
      (projection := desiredProjection)
      (samples := fun x => (envsForInput up.g x).map
        (observe up.g upCertNodes))
      (pipelineUpInput up tail)
    · intro x hx
      exact pipelineUpInput_mem up tail x
    · intro x hx y hy hprojection
      apply pvtProjectionEqOfBits
      intro input hinput share hshare
      have hshareD : share < d := by
        rcases List.mem_append.mp hshare with h | h
        · exact hdemandedMem share h
        · exact hupBMem share h
      have hshareUp : share < up.g.d := by simpa [up.d_eq] using hshareD
      rw [pipelineUpInput_bit up tail x input share hinput hshareUp]
      rw [pipelineUpInput_bit up tail y input share hinput hshareUp]
      have htailPositive : 0 < tail.g.inputCount :=
        Nat.zero_lt_of_lt tail.ports.input_bound
      have hinputComposite : input < composite.inputCount := by
        simp [composite, registeredComposite]
        omega
      exact pvtInputBitEq composite desiredShares x y
        input share hinputComposite (hupDesired share hshare) hprojection
    · exact hupSamples
  -- second stage: the tail certificate is invariant across hidden states
  rcases htailSamples with ⟨tailSimulator, htailPositive, htailPerm⟩
  have hsecond : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ upEnv ∈ envsForInput up.g (pipelineUpInput up tail x),
      ∀ y ∈ boolVectors (inputWidth composite),
      ∀ other ∈ envsForInput up.g (pipelineUpInput up tail y),
      desiredProjection x = desiredProjection y →
      observe up.g upCertNodes upEnv = observe up.g upCertNodes other →
      ((envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
          (observe tail.g tailCertNodes)).Perm
        ((envsForInput tail.g (pipelineTailInput up tail y other)).map
          (observe tail.g tailCertNodes)) := by
    intro x hx upEnv hupEnv y hy other hother hprojection hfirstObs
    have hdecoded := congrArg
      (decodeUpstreamObservation up upInternal demanded upB) hfirstObs
    rw [decodeUpstreamObservation_eq up upInternal demanded upB
      hdemandedSub upEnv,
      decodeUpstreamObservation_eq up upInternal demanded upB
        hdemandedSub other] at hdecoded
    have htailProjection : projection tail.g tailShares
        (pipelineTailInput up tail x upEnv) =
      projection tail.g tailShares
        (pipelineTailInput up tail y other) := by
      apply pvtProjectionEqOfBits
      intro input hinput share hshare
      have hshareD : share < d := by
        rcases List.mem_append.mp hshare with h | h
        · exact htailDemandMem share h
        · exact htailBMem share h
      have hshareTail : share < tail.g.d := by
        simpa [tail.d_eq] using hshareD
      rw [pipelineTailInput_bit up tail x upEnv input share hinput hshareTail]
      rw [pipelineTailInput_bit up tail y other input share hinput hshareTail]
      by_cases hconnected : input = tail.ports.downstreamInput
      · rw [if_pos hconnected, if_pos hconnected]
        have houtputNode : up.g.output share ∈ upFullNodes :=
          hupOutputMemFull share (htailSharesUpExposed share hshare)
        have hvalue := congrArg
          (fun values => observationAt upFullNodes values (up.g.output share))
          hdecoded
        rw [pvtObservationAt up.g upFullNodes upEnv
          (up.g.output share) houtputNode,
          pvtObservationAt up.g upFullNodes other
            (up.g.output share) houtputNode] at hvalue
        exact hvalue
      · rw [if_neg hconnected, if_neg hconnected]
        have hhidden := tail.ports.input_bound
        have hindex := pvtHideLt tail.ports.downstreamInput
          input tail.g.inputCount hhidden hinput hconnected
        have hinputComposite : up.g.inputCount +
            hideRegisteredInput tail.ports.downstreamInput input <
              composite.inputCount := by
          simp [composite, registeredComposite]
          omega
        exact pvtInputBitEq composite desiredShares x y
          (up.g.inputCount +
            hideRegisteredInput tail.ports.downstreamInput input) share
          hinputComposite (htailDesired share hshare) hprojection
    have hleft :
        ((envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
          (observe tail.g tailCertNodes)).Perm
        (tailSimulator (projection tail.g tailShares
          (pipelineTailInput up tail x upEnv))) := by
      simpa [tailShares] using
        htailPerm (pipelineTailInput up tail x upEnv)
          (pipelineTailInput_mem up tail x upEnv)
    have hright :
        ((envsForInput tail.g (pipelineTailInput up tail y other)).map
          (observe tail.g tailCertNodes)).Perm
        (tailSimulator (projection tail.g tailShares
          (pipelineTailInput up tail y other))) := by
      simpa [tailShares] using
        htailPerm (pipelineTailInput up tail y other)
          (pipelineTailInput_mem up tail y other)
    rw [htailProjection] at hleft
    exact hleft.trans hright.symm
  have hsecondNonempty : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ upEnv ∈ envsForInput up.g (pipelineUpInput up tail x),
      (envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
          (observe tail.g tailCertNodes) ≠ [] := by
    intro x hx upEnv hupEnv
    have hne := envsForInput_ne_nil_of_valid tail.g
      (pipelineTailInput up tail x upEnv) (fixingForInput_valid tail.g _)
    rcases List.exists_mem_of_ne_nil _ hne with ⟨tailEnv, htailEnv⟩
    exact List.ne_nil_of_mem (List.mem_map.mpr ⟨tailEnv, htailEnv, rfl⟩)
  have hassembled : SamplesSimulatableOn
      (boolVectors (inputWidth composite)) desiredProjection (fun x =>
        (envsForInput up.g (pipelineUpInput up tail x)).flatMap fun upEnv =>
          ((envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
            (observe tail.g tailCertNodes)).map
              (emit (observe up.g upCertNodes upEnv))) := by
    apply samplesSimulatableOn_hidden_bind emit hsecond hsecondNonempty hfirst
  -- exact factorization of the composite O-PINI experiment
  have hfactor : ∀ x ∈ boolVectors (inputWidth composite),
      ((envsForInput composite x).map
        (observe composite compositeNodesO)).Perm
      ((envsForInput up.g (pipelineUpInput up tail x)).flatMap fun upEnv =>
        ((envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
          (observe tail.g tailCertNodes)).map
            (emit (observe up.g upCertNodes upEnv))) := by
    intro x hx
    have hraw := (experiment_product_raw up tail glue x).map
      (observe composite compositeNodesO)
    apply hraw.trans
    rw [pvtEnvsCells up.g (pipelineUpInput up tail x)]
    simp only [List.map_flatMap, List.map_map, List.flatMap_map,
      Function.comp_def]
    apply flatMap_perm_of_pointwise
    intro upValues hupValues
    rw [pvtEnvsCells tail.g
      (pipelineTailInput up tail x (Execution.envFrom upValues))]
    simp only [List.map_map, Function.comp_def]
    apply List.Perm.of_eq
    apply List.map_congr_left
    intro tailValues htailValues
    let upEnv := Execution.envFrom upValues
    let tailEnv := Execution.envFrom tailValues
    let combined := Execution.envFrom
      (upValues ++ pvtBoundaryAssignment up.g d ++
        pvtShiftedTailAssignment up.g tail.g tail.ports tailValues)
    have hupKeys := pvtPatternKeys _ _ upValues hupValues
    have hupEnvMem : upEnv ∈
        envsForInput up.g (pipelineUpInput up tail x) :=
      pvtAssignmentEnvMem up.g (pipelineUpInput up tail x) upValues hupValues
    have hcombinedMem : combined ∈ envsForInput composite x := by
      simpa [composite, combined] using
        pvtProductEnvMem up tail glue x upValues tailValues
          hupValues htailValues
    have hrestrict : restrictEnv
        (Execution.relevantSrcs up.g.circuit up.g.horizon) combined = upEnv :=
      pvtRestrictProductUp up tail upValues tailValues hupKeys
    have hagree := pvtSubstAgrees up tail glue x
      upValues tailValues hupValues htailValues
    have htailObs : observe tail.g tailFullNodes tailEnv =
        observe tail.g tailFullNodes
          (substitutedTailEnv up.g tail.g tail.ports combined) := by
      rw [observe_eq_map_eval, observe_eq_map_eval]
      apply List.map_congr_left
      intro node _
      exact (UniversalSStage1.eval_env_congr tail.g.circuit tail.g.horizon
        _ _ node hagree).symm
    have hreconstruct :
        reconstructPipelineObservation up tail upFullNodes tailFullNodes
            compositeNodesO
            (observe up.g upFullNodes upEnv)
            (observe tail.g tailFullNodes tailEnv) =
          observe composite compositeNodesO combined := by
      rw [htailObs, ← hrestrict]
      rw [observe_eq_map_eval composite compositeNodesO combined]
      unfold reconstructPipelineObservation
      apply List.map_congr_left
      intro node hnode
      exact pvtReconstructNodeEq up tail glue upFullNodes tailFullNodes
        combined (pipelineUpInput up tail x) (pipelineUpInput_mem up tail x)
        (by rw [hrestrict]; exact hupEnvMem)
        (fun share hshare => pvtBoundaryInitFalse up tail glue x combined
          hcombinedMem share hshare)
        htailBound node (hcoverage node hnode).1 (hcoverage node hnode).2
    dsimp only [emit]
    rw [decodeUpstreamObservation_eq up upInternal demanded upB
      hdemandedSub upEnv]
    rw [decodeUpstreamObservation_eq tail tailInternal tailDemand tailB
      htailDemandSub tailEnv]
    exact hreconstruct.symm
  rcases hassembled with ⟨simulator, hpositive, hperm⟩
  apply samplesSimulatableOn_to_simulatableOn
  refine ⟨simulator, hpositive, ?_⟩
  intro x hx
  exact (hfactor x hx).trans (hperm x hx)

/-! ## Immediate corollaries: the audited conclusions -/

/-- The composite of two demand-uniform O-PINI pipeline gadgets satisfies the
unmodified audited `opiniSpec`.  No composite security property is assumed. -/
theorem compose_opini {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : uniformOpiniSpec up.g transitionGlitch t)
    (htail : uniformOpiniSpec tail.g transitionGlitch t)
    (glue : PortGlue up tail) :
    opiniSpec (registeredComposite up.g tail.ports) transitionGlitch t :=
  uniformOpini_implies_opini _ transitionGlitch t
    (compose_uniform_opini up tail hup htail glue)

/-! ## The closed producer-reuse invariant

`UOPipelineGadget` is the option-B fixpoint record: it carries the complete
structural pipeline invariant, the downstream-role PINI certificate, *and*
the demand-uniform O-PINI certificate.  `compose` reproduces every carried
field, so a closed composite can immediately serve as the upstream O-PINI
producer of a later splice.  Because the registered compiler redirects
*every* tail read of the connected input gates to the shared boundary
registers, a tail whose port fans out internally makes the composed
producer drive multiple consumers in the compiled circuit. -/

structure UOPipelineGadget (H d t : Nat) extends PipelineGadget H d t where
  uniform_cert : uniformOpiniSpec g transitionGlitch t

namespace UOPipelineGadget

/-- The unmodified audited upstream-role certificate is carried. -/
theorem opini {H d t : Nat} (P : UOPipelineGadget H d t) :
    opiniSpec P.g transitionGlitch t :=
  uniformOpini_implies_opini P.g transitionGlitch t P.uniform_cert

/-- The unmodified audited downstream-role certificate is carried. -/
theorem pini {H d t : Nat} (P : UOPipelineGadget H d t) :
    piniSpec P.g transitionGlitch t :=
  P.down_cert

/-- The unmodified audited end-to-end conclusion. -/
theorem probing {H d t : Nat} (P : UOPipelineGadget H d t) :
    probingSecureSpec P.g transitionGlitch t :=
  P.toPipelineGadget.probing

/-- Every closed gadget inhabits the previously accepted O-PINI-carrying
record. -/
def toOPINIPipelineGadget {H d t : Nat} (P : UOPipelineGadget H d t) :
    OPINIPipelineGadget H d t :=
  { toPipelineGadget := P.toPipelineGadget, out_cert := P.opini }

/-- Leaf introduction from a demand-uniform certificate at any order. -/
def ofUniformLeaf {H d t : Nat} (P : PipelineGadget H d t)
    (huniform : uniformOpiniSpec P.g transitionGlitch t) :
    UOPipelineGadget H d t :=
  { toPipelineGadget := P.ofLeaf
      (uniformOpini_implies_opini P.g transitionGlitch t huniform)
    uniform_cert := huniform }

/-- Leaf introduction from the audited `opiniSpec` at strict order one,
where the demand multiplicities are degenerate. -/
def ofLeaf {H d : Nat} (P : PipelineGadget H d 1)
    (hopini : opiniSpec P.g transitionGlitch 1) : UOPipelineGadget H d 1 :=
  ofUniformLeaf P
    (opini_implies_uniform_of_le_one P.g transitionGlitch 1
      (Nat.le_refl 1) hopini)

/-- Select another admissible still-external share-domain input without
changing the compiled gadget or either carried certificate. -/
def withPorts {H d t : Nat} (P : UOPipelineGadget H d t)
    (ports : RegisterPorts P.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports) : UOPipelineGadget H d t :=
  { toPipelineGadget :=
      P.toPipelineGadget.withPorts ports arrival_inside source_exclusive
    uniform_cert := P.uniform_cert }

@[simp] theorem withPorts_g {H d t : Nat} (P : UOPipelineGadget H d t)
    (ports : RegisterPorts P.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports) :
    (P.withPorts ports arrival_inside source_exclusive).g = P.g := rfl

/-- **The closure operation.**  Splice a closed O-PINI producer onto the
selected port of a closed O-PINI tail.  Every carried field — the whole
structural invariant, the PINI certificate, and the demand-uniform O-PINI
certificate — is reproduced for the composite, so the result is again a
legitimate upstream producer. -/
def compose {H d t : Nat} (up tail : UOPipelineGadget H d t)
    (glue : PortGlue up.toPipelineGadget tail.toPipelineGadget) :
    UOPipelineGadget H d t :=
  { toPipelineGadget := Composition.compose up.toPipelineGadget
      tail.toPipelineGadget up.opini glue
    uniform_cert := compose_uniform_opini up.toPipelineGadget
      tail.toPipelineGadget up.uniform_cert tail.uniform_cert glue }

@[simp] theorem compose_g {H d t : Nat} (up tail : UOPipelineGadget H d t)
    (glue : PortGlue up.toPipelineGadget tail.toPipelineGadget) :
    (compose up tail glue).g = registeredComposite up.g tail.ports := rfl

/-- Wiring through an arbitrary admissible external port. -/
def wire {H d t : Nat} (up tail : UOPipelineGadget H d t)
    (ports : RegisterPorts tail.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports)
    (glue : PortGlue up.toPipelineGadget
      (tail.toPipelineGadget.withPorts ports arrival_inside
        source_exclusive)) :
    UOPipelineGadget H d t :=
  compose up (tail.withPorts ports arrival_inside source_exclusive) glue

@[simp] theorem wire_g {H d t : Nat} (up tail : UOPipelineGadget H d t)
    (ports : RegisterPorts tail.g)
    (arrival_inside : ports.arrivalCycle < H)
    (source_exclusive : PortSourceExclusive ports)
    (glue : PortGlue up.toPipelineGadget
      (tail.toPipelineGadget.withPorts ports arrival_inside
        source_exclusive)) :
    (wire up tail ports arrival_inside source_exclusive glue).g =
      registeredComposite up.g ports := rfl

end UOPipelineGadget

/-! ## Generic closure induction for producer-reuse DAG derivations -/

/-- A well-formed composition derivation of demand-uniform O-PINI gadgets.

Unlike the accepted `TreeComposition`, the upstream of every wiring step may
itself be an arbitrary closed derivation — the O-PINI certificate is
reproduced by `compose`, so no leaf restriction is needed — and the selected
port's input gates may be read by arbitrarily many gates of the tail.  The
registered compiler redirects all of those reads to the shared boundary
registers, so compiled derivations include genuinely reconvergent circuits
in which one composed producer output domain drives multiple consumers. -/
inductive OPINIComposition {H d t : Nat} : UOPipelineGadget H d t → Prop where
  | leaf (gadget : PipelineGadget H d t)
      (huniform : uniformOpiniSpec gadget.g transitionGlitch t) :
      OPINIComposition (UOPipelineGadget.ofUniformLeaf gadget huniform)
  | wire (up tail : UOPipelineGadget H d t)
      (up_build : OPINIComposition up)
      (tail_build : OPINIComposition tail)
      (ports : RegisterPorts tail.g)
      (arrival_inside : ports.arrivalCycle < H)
      (source_exclusive : PortSourceExclusive ports)
      (glue : PortGlue up.toPipelineGadget
        (tail.toPipelineGadget.withPorts ports arrival_inside
          source_exclusive)) :
      OPINIComposition
        (UOPipelineGadget.wire up tail ports arrival_inside
          source_exclusive glue)

namespace OPINIComposition

/-- Every derivation carries the unmodified audited O-PINI certificate for
its compiled gadget: the composite can be reused as a producer. -/
theorem opini {H d t : Nat} {composite : UOPipelineGadget H d t}
    (_build : OPINIComposition composite) :
    opiniSpec composite.g transitionGlitch t :=
  composite.opini

/-- Every derivation carries the unmodified downstream-role PINI role. -/
theorem pini {H d t : Nat} {composite : UOPipelineGadget H d t}
    (_build : OPINIComposition composite) :
    piniSpec composite.g transitionGlitch t :=
  composite.pini

/-- Every derivation is probing secure under the real transition-glitch
expansion. -/
theorem probing {H d t : Nat} {composite : UOPipelineGadget H d t}
    (_build : OPINIComposition composite) :
    probingSecureSpec composite.g transitionGlitch t :=
  composite.probing

end OPINIComposition

end Composition
end LeanSec
