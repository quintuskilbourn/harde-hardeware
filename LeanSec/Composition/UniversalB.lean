import LeanSec.Composition.Serial2

namespace LeanSec
namespace Composition
namespace UniversalB

open Gadget

/-!
This module investigates the proposed circuit-free route to universal serial
composition.  The simulator assembler in `Serial2` is already fully abstract:
its remaining semantic obligation is an exact factorization of the connected
experiment as a bind of the two isolated component experiments.

The definitions below state that obligation at the observation-multiset level,
without constructing or rewriting a circuit.  They also expose a source of
dependence which `Serial2Obstructions.ComponentRandomnessDisjoint` does not
exclude: an upstream external-input source may occur in the downstream
randomness list.  In a connected experiment the source is sampled once (and
may be fixed by the upstream input); the isolated bind samples it again.
-/

/-- Joint observations from a connected, same-environment experiment.  The
upstream and downstream computations see the same assignment of source atoms,
and their observations are concatenated. -/
def connectedObservationSamples (upstream : GadgetInstance)
    (upstreamInput : List Bool) (upstreamObservation downstreamObservation :
      Env → Observation) : List Observation :=
  (envsForInput upstream upstreamInput).map fun env =>
    upstreamObservation env ++ downstreamObservation env

/-- The observation multiset obtained by treating the two isolated component
experiments as independent and binding their samples.  This is the shape of
the factorization premise consumed by
`serial2_opini_connected_experiment_simulatable`. -/
def isolatedObservationBindSamples (upstream downstream : GadgetInstance)
    (upstreamInput downstreamInput : List Bool)
    (upstreamObservation downstreamObservation : Env → Observation) :
    List Observation :=
  ((envsForInput upstream upstreamInput).map upstreamObservation).flatMap
    fun first =>
      ((envsForInput downstream downstreamInput).map downstreamObservation).map
        fun second => first ++ second

/-- `ComponentRandomnessDisjoint` is not the freshness law required by the
connected-experiment factorization.  Even with two genuine O-PINI components
and exact same-environment boundary agreement, the connected observation
experiment can have one sample while the proposed isolated bind has two.

The observations are deliberately empty: failure is already visible in the
normalization/cardinality of the experiments, before any circuit semantics or
probe expansion is involved. -/
theorem componentRandomnessDisjoint_does_not_imply_observation_factorization
    (scheme : ExpansionScheme) :
    ∃ (upstream downstream : GadgetInstance)
      (w : Serial2Wiring upstream downstream),
      opiniSpec upstream scheme 0 ∧
      opiniSpec downstream scheme 0 ∧
      Serial2Obstructions.BoundaryValuesAgree w ∧
      Serial2Obstructions.ComponentRandomnessDisjoint upstream downstream ∧
      ∃ (upstreamObservation downstreamObservation : Env → Observation),
        ¬ (connectedObservationSamples upstream [false, false]
              upstreamObservation downstreamObservation).Perm
            (isolatedObservationBindSamples upstream downstream
              [false, false] [false]
              upstreamObservation downstreamObservation) := by
  obtain ⟨upstream, downstream, w, hupstream, hdownstream, hboundary,
      hrandomness, hdownstreamCard, hupstreamCard⟩ :=
    Serial2Obstructions.two_laws_allow_component_experiment_factorization_failure
      scheme
  refine ⟨upstream, downstream, w, hupstream, hdownstream, hboundary,
    hrandomness, (fun _ => []), (fun _ => []), ?_⟩
  intro hfactorization
  have hlength := hfactorization.length_eq
  generalize henvs : envsForInput upstream [false, false] = upstreamEnvs at hupstreamCard hlength
  cases upstreamEnvs with
  | nil => simp at hupstreamCard
  | cons first rest =>
      cases rest with
      | nil =>
          simp [connectedObservationSamples, isolatedObservationBindSamples,
            henvs, hdownstreamCard] at hlength
      | cons second tail => simp at hupstreamCard

/-- The missing assumption has a precise source-level name: upstream input
arrivals must also be fresh for downstream randomness.  It is independent of
component-randomness disjointness and is not supplied by O-PINI. -/
theorem listed_hypotheses_do_not_imply_input_randomness_freshness
    (scheme : ExpansionScheme) :
    ∃ (upstream downstream : GadgetInstance)
      (w : Serial2Wiring upstream downstream),
      opiniSpec upstream scheme 0 ∧
      opiniSpec downstream scheme 0 ∧
      Serial2Obstructions.BoundaryValuesAgree w ∧
      Serial2Obstructions.ComponentRandomnessDisjoint upstream downstream ∧
      ¬ Serial2Obstructions.UpstreamInputsDownstreamRandomnessDisjoint
          upstream downstream :=
  Serial2Obstructions.two_laws_and_two_opini_do_not_imply_input_randomness_freshness
    scheme

end UniversalB
end Composition
end LeanSec

#print axioms LeanSec.Composition.UniversalB.componentRandomnessDisjoint_does_not_imply_observation_factorization
#print axioms LeanSec.Composition.UniversalB.listed_hypotheses_do_not_imply_input_randomness_freshness
