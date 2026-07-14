import LeanSec.Composition.Boundary

namespace LeanSec
namespace Composition

open Gadget

/-- Sufficient data for the Definition-7 serial composition `upstream →
downstream`.  Both executions live in the same unrolling, have the same share
count, and are disjoint. -/
structure Serial2Wiring (upstream downstream : GadgetInstance) where
  downstreamInput : Nat
  input_bound : downstreamInput < downstream.inputCount
  same_circuit : upstream.circuit = downstream.circuit
  same_horizon : upstream.horizon = downstream.horizon
  same_shares : upstream.d = downstream.d
  disjoint : ∀ n, upstream.member n = true → downstream.member n = false

namespace Serial2Wiring

def serialConnection {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream) : Connection :=
  { source := 0
    target := { component := 1, sharing := w.downstreamInput } }

/-- The concrete two-node interface graph.  The downstream output is the
output of the composite and its connected input is removed from the external
input list by `ExecutionComposition.externalInputs`. -/
def description {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream) : ExecutionComposition where
  componentCount := 2
  shareCount := upstream.d
  component := fun component =>
    if component = 0 then upstream else downstream
  connections := [serialConnection w]
  outputs := [1]

/-- A serial pair is an honest Definition-7 composition: its two executions
are disjoint, its sole edge is share preserving, and rank `id` proves the
component graph acyclic. -/
theorem description_wellFormed {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream) :
    (description w).WellFormed := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro component hcomponent
    change component < 2 at hcomponent
    have hc : component = 0 ∨ component = 1 := by omega
    rcases hc with rfl | rfl
    · simp [description]
    · simpa [description] using w.same_shares.symm
  · intro i hi j hj
    change i < 2 at hi
    change j < 2 at hj
    have hi' : i = 0 ∨ i = 1 := by omega
    have hj' : j = 0 ∨ j = 1 := by omega
    rcases hi' with rfl | rfl <;> rcases hj' with rfl | rfl
    · simp [description]
    · simpa [description] using And.intro w.same_circuit w.same_horizon
    · simpa [description] using
        And.intro w.same_circuit.symm w.same_horizon.symm
    · simp [description]
  · intro edge hedge
    simp only [description, List.mem_singleton] at hedge
    subst edge
    refine ⟨by change 0 < 2; omega, by change 1 < 2; omega, ?_⟩
    change w.downstreamInput < downstream.inputCount
    exact w.input_bound
  · simp [description]
  · intro component hcomponent
    simp only [description, List.mem_singleton] at hcomponent
    subst component
    change 1 < 2
    omega
  · simp [description]
  · intro i hi j hj hij n hin
    change i < 2 at hi
    change j < 2 at hj
    have hi' : i = 0 ∨ i = 1 := by omega
    have hj' : j = 0 ∨ j = 1 := by omega
    rcases hi' with rfl | rfl <;> rcases hj' with rfl | rfl
    · exact (hij rfl).elim
    · simpa [description] using w.disjoint n (by simpa [description] using hin)
    · change downstream.member n = true at hin
      change upstream.member n = false
      cases hup : upstream.member n
      · rfl
      · have hdown := w.disjoint n hup
        rw [hdown] at hin
        contradiction
    · exact (hij rfl).elim
  · refine ⟨fun component => component, ?_⟩
    intro edge hedge
    simp only [description, List.mem_singleton] at hedge
    subst edge
    simp [serialConnection]

theorem connectedNode_eq_upstream_output
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream) (share : Nat) :
    w.description.connectedNode w.serialConnection share =
      upstream.output share := by
  simp [ExecutionComposition.connectedNode, description, serialConnection]

theorem connected_input_not_external
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream) :
    ({ component := 1, sharing := w.downstreamInput } : InputPort) ∉
      w.description.externalInputs := by
  simp [ExecutionComposition.externalInputs, description, serialConnection]

theorem compositeMember_iff
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream) (n : Node) :
    w.description.compositeMember n ↔
      upstream.member n = true ∨ downstream.member n = true := by
  constructor
  · rintro ⟨component, hcomponent, hmember⟩
    change component < 2 at hcomponent
    have hc : component = 0 ∨ component = 1 := by omega
    rcases hc with rfl | rfl
    · exact Or.inl (by simpa [description] using hmember)
    · exact Or.inr (by simpa [description] using hmember)
  · intro hmember
    rcases hmember with hupstream | hdownstream
    · exact ⟨0, by change 0 < 2; omega,
        by simpa [description] using hupstream⟩
    · exact ⟨1, by change 1 < 2; omega,
        by simpa [description] using hdownstream⟩

end Serial2Wiring

namespace Serial2Obstructions

/-! The following finite witnesses make two limitations of `Serial2Wiring`
kernel-checkable.  They are not security counterexamples to CS21: they show
that the present repository interface omits semantic hypotheses which CS21's
composition operation supplies. -/

/-- The direct same-environment substitution law one would need in order to
interpret the target component's designated input sources as values produced
by the source component.  `Serial2Wiring` records the corresponding graph
edge, but does not contain this semantic law. -/
def BoundaryValuesAgree {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream) : Prop :=
  ∀ env share, share < upstream.d →
    Execution.eval upstream.circuit upstream.horizon env
        (w.description.connectedNode w.serialConnection share) =
      env (downstream.inputArrival w.downstreamInput share)

/-- A minimal freshness condition for factoring the isolated component
experiments as a randomized bind.  Node-disjointness alone does not imply
that the two component experiments quantify over independent random sources. -/
def ComponentRandomnessDisjoint
    (upstream downstream : GadgetInstance) : Prop :=
  ∀ src, src ∈ upstream.randomness → src ∉ downstream.randomness

/-- A source-level compatibility condition which is not covered by
`ComponentRandomnessDisjoint`: an external input of the upstream experiment
must not simultaneously be sampled as fresh randomness by the isolated
downstream experiment.  Without some condition handling this overlap, the
downstream O-PINI distribution is not the conditional distribution appearing
in the connected experiment. -/
def UpstreamInputsDownstreamRandomnessDisjoint
    (upstream downstream : GadgetInstance) : Prop :=
  ∀ input, input < upstream.inputCount →
    ∀ share, share < upstream.d →
      upstream.inputArrival input share ∉ downstream.randomness

private def disconnectedCircuit : Circuit :=
  { gates := #[
      { kind := .const false, inputs := [] },
      { kind := .inp 0 0, inputs := [] }
    ] }

private def disconnectedUpstream : GadgetInstance where
  circuit := disconnectedCircuit
  horizon := 1
  d := 1
  inputCount := 1
  inputArrival := fun _ _ => .inp 1 0 0
  output := fun _ => { gate := 0, cycle := 0 }
  member := fun node => node == ({ gate := 0, cycle := 0 } : Node)
  randomness := []

private def disconnectedDownstream : GadgetInstance where
  circuit := disconnectedCircuit
  horizon := 1
  d := 1
  inputCount := 1
  inputArrival := fun _ _ => .inp 0 0 0
  output := fun _ => { gate := 1, cycle := 0 }
  member := fun node => node == ({ gate := 1, cycle := 0 } : Node)
  randomness := []

private def disconnectedWiring :
    Serial2Wiring disconnectedUpstream disconnectedDownstream where
  downstreamInput := 0
  input_bound := by decide
  same_circuit := rfl
  same_horizon := rfl
  same_shares := rfl
  disjoint := by
    intro node hnode
    have hnode' : node = ({ gate := 0, cycle := 0 } : Node) := by
      simpa [disconnectedUpstream] using hnode
    subst node
    decide

private theorem disconnectedUpstream_wf : disconnectedUpstream.WF := by
  simp [GadgetInstance.WF, disconnectedUpstream, disconnectedCircuit,
    Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred, Circuit.combEdges, outputNodes, memberNodes,
    nodes, combInputNodes, transInputNodes]
  intro gate hgate
  have : gate = 0 ∨ gate = 1 := by omega
  rcases this with rfl | rfl <;> simp

private theorem disconnectedDownstream_wf : disconnectedDownstream.WF := by
  simp [GadgetInstance.WF, disconnectedDownstream, disconnectedCircuit,
    Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred, Circuit.combEdges, outputNodes, memberNodes,
    nodes, combInputNodes, transInputNodes]
  intro gate hgate
  have : gate = 0 ∨ gate = 1 := by omega
  rcases this with rfl | rfl <;> simp

/-- `Serial2Wiring` alone does not impose the semantic boundary equation.
Here its connected source evaluates to `false`, while the target input source
in the very same environment is `true`.  Thus an execution-factorization
lemma cannot be derived from `description_wellFormed`. -/
theorem serial2Wiring_does_not_force_boundary_value :
    ∃ (upstream downstream : GadgetInstance)
      (w : Serial2Wiring upstream downstream) (env : Env),
      Execution.eval upstream.circuit upstream.horizon env
          (w.description.connectedNode w.serialConnection 0) ≠
        env (downstream.inputArrival w.downstreamInput 0) := by
  refine ⟨disconnectedUpstream, disconnectedDownstream, disconnectedWiring,
    Execution.envFrom [(.inp 0 0 0, true)], ?_⟩
  decide

/-- The missing boundary equation is not implied even after both components
are assumed O-PINI.  Order-zero O-PINI is enough to make this implication
failure explicit without relying on an uncertified gadget: both finite
components below satisfy the audited security predicate, yet the target input
source still disagrees with the connected upstream output. -/
theorem two_opini_do_not_force_boundary_value (scheme : ExpansionScheme) :
    ∃ (upstream downstream : GadgetInstance)
      (w : Serial2Wiring upstream downstream) (env : Env),
      opiniSpec upstream scheme 0 ∧
      opiniSpec downstream scheme 0 ∧
      Execution.eval upstream.circuit upstream.horizon env
          (w.description.connectedNode w.serialConnection 0) ≠
        env (downstream.inputArrival w.downstreamInput 0) := by
  refine ⟨disconnectedUpstream, disconnectedDownstream, disconnectedWiring,
    Execution.envFrom [(.inp 0 0 0, true)],
    opiniSpec_zero _ _ disconnectedUpstream_wf,
    opiniSpec_zero _ _ disconnectedDownstream_wf, ?_⟩
  decide

/-- The exact boundary-substitution proposition is not a consequence of the
two O-PINI certificates and a valid serial interface.  This packages the
single-environment counterexample above as failure of a named semantic law
needed by a connected-experiment factorization proof. -/
theorem two_opini_do_not_imply_boundaryValuesAgree
    (scheme : ExpansionScheme) :
    ∃ (upstream downstream : GadgetInstance)
      (w : Serial2Wiring upstream downstream),
      opiniSpec upstream scheme 0 ∧
      opiniSpec downstream scheme 0 ∧
      ¬ BoundaryValuesAgree w := by
  refine ⟨disconnectedUpstream, disconnectedDownstream, disconnectedWiring,
    opiniSpec_zero _ _ disconnectedUpstream_wf,
    opiniSpec_zero _ _ disconnectedDownstream_wf, ?_⟩
  intro hagree
  have heq := hagree (Execution.envFrom [(.inp 0 0 0, true)]) 0 (by decide)
  exact (by decide :
    Execution.eval disconnectedUpstream.circuit disconnectedUpstream.horizon
        (Execution.envFrom [(.inp 0 0 0, true)])
          (disconnectedWiring.description.connectedNode
            disconnectedWiring.serialConnection 0) ≠
      Execution.envFrom [(.inp 0 0 0, true)]
        (disconnectedDownstream.inputArrival
          disconnectedWiring.downstreamInput 0)) heq

private def sharedRandomnessUpstream : GadgetInstance where
  circuit := disconnectedCircuit
  horizon := 1
  d := 1
  inputCount := 1
  inputArrival := fun _ _ => .inp 1 0 0
  output := fun _ => { gate := 0, cycle := 0 }
  member := fun node => node == ({ gate := 0, cycle := 0 } : Node)
  randomness := [.rnd 0 0]

private def sharedRandomnessDownstream : GadgetInstance where
  circuit := disconnectedCircuit
  horizon := 1
  d := 1
  inputCount := 1
  inputArrival := fun _ _ => .inp 0 0 0
  output := fun _ => { gate := 1, cycle := 0 }
  member := fun node => node == ({ gate := 1, cycle := 0 } : Node)
  randomness := [.rnd 0 0]

private def sharedRandomnessWiring :
    Serial2Wiring sharedRandomnessUpstream sharedRandomnessDownstream where
  downstreamInput := 0
  input_bound := by decide
  same_circuit := rfl
  same_horizon := rfl
  same_shares := rfl
  disjoint := by
    intro node hnode
    have hnode' : node = ({ gate := 0, cycle := 0 } : Node) := by
      simpa [sharedRandomnessUpstream] using hnode
    subst node
    decide

/-- Node-disjoint component executions may still enumerate the same random
source.  Hence the product/conditional randomness law needed by the
randomized bind is not a consequence of `Serial2Wiring.disjoint`. -/
theorem serial2Wiring_allows_shared_randomness :
    ∃ (upstream downstream : GadgetInstance)
      (_w : Serial2Wiring upstream downstream) (src : Src),
      src ∈ upstream.randomness ∧ src ∈ downstream.randomness := by
  exact ⟨sharedRandomnessUpstream, sharedRandomnessDownstream,
    sharedRandomnessWiring, .rnd 0 0, by simp [sharedRandomnessUpstream],
    by simp [sharedRandomnessDownstream]⟩

/-- Component O-PINI certificates likewise do not upgrade node disjointness
to the source-disjointness needed by a product/conditional randomness law.
The two well-formed, order-zero O-PINI components share the very same random
source. -/
theorem two_opini_allow_shared_randomness (scheme : ExpansionScheme) :
    ∃ (upstream downstream : GadgetInstance)
      (_w : Serial2Wiring upstream downstream) (src : Src),
      opiniSpec upstream scheme 0 ∧
      opiniSpec downstream scheme 0 ∧
      src ∈ upstream.randomness ∧ src ∈ downstream.randomness := by
  exact ⟨sharedRandomnessUpstream, sharedRandomnessDownstream,
    sharedRandomnessWiring, .rnd 0 0,
    opiniSpec_zero _ _ (by
      change disconnectedUpstream.WF
      exact disconnectedUpstream_wf),
    opiniSpec_zero _ _ (by
      change disconnectedDownstream.WF
      exact disconnectedDownstream_wf),
    by simp [sharedRandomnessUpstream], by simp [sharedRandomnessDownstream]⟩

/-- The randomness freshness proposition needed by the product/conditional
experiment law is likewise not implied by two O-PINI certificates and valid
serial wiring. -/
theorem two_opini_do_not_imply_componentRandomnessDisjoint
    (scheme : ExpansionScheme) :
    ∃ (upstream downstream : GadgetInstance)
      (_w : Serial2Wiring upstream downstream),
      opiniSpec upstream scheme 0 ∧
      opiniSpec downstream scheme 0 ∧
      ¬ ComponentRandomnessDisjoint upstream downstream := by
  refine ⟨sharedRandomnessUpstream, sharedRandomnessDownstream,
    sharedRandomnessWiring,
    opiniSpec_zero _ _ (by
      change disconnectedUpstream.WF
      exact disconnectedUpstream_wf),
    opiniSpec_zero _ _ (by
      change disconnectedDownstream.WF
      exact disconnectedDownstream_wf), ?_⟩
  intro hdisjoint
  exact hdisjoint (.rnd 0 0) (by simp [sharedRandomnessUpstream])
    (by simp [sharedRandomnessDownstream])

/-! A second finite obstruction: disjoint component randomness lists do not
make the *whole experiment boundaries* disjoint. -/

private def inputRandomOverlapCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .inp 1 0, inputs := [] }
    ] }

private def inputRandomOverlapUpstream : GadgetInstance where
  circuit := inputRandomOverlapCircuit
  horizon := 1
  d := 1
  inputCount := 2
  inputArrival := fun input _ => if input = 0 then .inp 0 0 0 else .inp 1 0 0
  output := fun _ => { gate := 0, cycle := 0 }
  member := fun node =>
    node == ({ gate := 0, cycle := 0 } : Node) ||
      node == ({ gate := 1, cycle := 0 } : Node)
  randomness := []

private def inputRandomOverlapDownstream : GadgetInstance where
  circuit := inputRandomOverlapCircuit
  horizon := 1
  d := 1
  inputCount := 1
  inputArrival := fun _ _ => .inp 0 0 0
  output := fun _ => { gate := 2, cycle := 0 }
  member := fun node => node == ({ gate := 2, cycle := 0 } : Node)
  randomness := [.inp 1 0 0]

/-- The direct `GadgetInstance` realization of the finite serial witness:
the connected downstream input is hidden, the upstream inputs remain
external, component memberships are united, and component randomness lists
are united.  In this example the downstream randomness source is already an
upstream external input, so `fixingForInput` fixes it instead of sampling it.
-/
private def inputRandomOverlapComposite : GadgetInstance where
  circuit := inputRandomOverlapCircuit
  horizon := 1
  d := 1
  inputCount := 2
  inputArrival := inputRandomOverlapUpstream.inputArrival
  output := inputRandomOverlapDownstream.output
  member := fun node =>
    inputRandomOverlapUpstream.member node ||
      inputRandomOverlapDownstream.member node
  randomness := inputRandomOverlapUpstream.randomness ++
    inputRandomOverlapDownstream.randomness

private def inputRandomOverlapWiring :
    Serial2Wiring inputRandomOverlapUpstream inputRandomOverlapDownstream where
  downstreamInput := 0
  input_bound := by decide
  same_circuit := rfl
  same_horizon := rfl
  same_shares := rfl
  disjoint := by
    intro node hnode
    simp [inputRandomOverlapUpstream] at hnode
    rcases hnode with rfl | rfl <;> decide

private theorem inputRandomOverlapUpstream_wf :
    inputRandomOverlapUpstream.WF := by
  simp [GadgetInstance.WF, inputRandomOverlapUpstream,
    inputRandomOverlapCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred, Circuit.combEdges,
    outputNodes, memberNodes, nodes, combInputNodes, transInputNodes]
  intro gate hgate
  have : gate = 0 ∨ gate = 1 ∨ gate = 2 := by omega
  rcases this with rfl | rfl | rfl <;> simp

private theorem inputRandomOverlapDownstream_wf :
    inputRandomOverlapDownstream.WF := by
  simp [GadgetInstance.WF, inputRandomOverlapDownstream,
    inputRandomOverlapCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred, Circuit.combEdges,
    outputNodes, memberNodes, nodes, combInputNodes, transInputNodes]
  intro gate hgate
  have : gate = 0 ∨ gate = 1 ∨ gate = 2 := by omega
  rcases this with rfl | rfl | rfl <;> simp

private theorem inputRandomOverlapComposite_wf :
    inputRandomOverlapComposite.WF := by
  simp [GadgetInstance.WF, inputRandomOverlapComposite,
    inputRandomOverlapUpstream, inputRandomOverlapDownstream,
    inputRandomOverlapCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred, Circuit.combEdges,
    outputNodes, memberNodes, nodes, combInputNodes, transInputNodes]
  intro gate hgate
  have : gate = 0 ∨ gate = 1 ∨ gate = 2 := by omega
  rcases this with rfl | rfl | rfl <;> simp

private theorem inputRandomOverlap_boundaryValuesAgree :
    BoundaryValuesAgree inputRandomOverlapWiring := by
  intro env share hshare
  change share < 1 at hshare
  have : share = 0 := by omega
  subst share
  change Execution.eval inputRandomOverlapCircuit 1 env
      ({ gate := 0, cycle := 0 } : Node) = env (.inp 0 0 0)
  rfl

/-- Even the two requested laws plus two genuine O-PINI certificates do not
separate component experiment boundaries.  The source `.inp 1 0 0` is the
second upstream external input but is sampled as downstream randomness. -/
theorem two_laws_and_two_opini_do_not_imply_input_randomness_freshness
    (scheme : ExpansionScheme) :
    ∃ (upstream downstream : GadgetInstance)
      (w : Serial2Wiring upstream downstream),
      opiniSpec upstream scheme 0 ∧
      opiniSpec downstream scheme 0 ∧
      BoundaryValuesAgree w ∧
      ComponentRandomnessDisjoint upstream downstream ∧
      ¬ UpstreamInputsDownstreamRandomnessDisjoint upstream downstream := by
  refine ⟨inputRandomOverlapUpstream, inputRandomOverlapDownstream,
    inputRandomOverlapWiring,
    opiniSpec_zero _ _ inputRandomOverlapUpstream_wf,
    opiniSpec_zero _ _ inputRandomOverlapDownstream_wf,
    inputRandomOverlap_boundaryValuesAgree, ?_, ?_⟩
  · simp [ComponentRandomnessDisjoint, inputRandomOverlapUpstream]
  · intro hfresh
    exact hfresh 1 (by decide) 0 (by decide)
      (by simp [inputRandomOverlapUpstream, inputRandomOverlapDownstream])

/-- The overlap above is not merely a missing syntactic consequence.  It
breaks the cardinality equation needed to regard the isolated downstream
experiment as the second stage of a connected randomized bind: downstream
alone samples `.inp 1 0` in two ways, whereas fixing the upstream external
input leaves only one connected environment. -/
theorem two_laws_allow_component_experiment_factorization_failure
    (scheme : ExpansionScheme) :
    ∃ (upstream downstream : GadgetInstance)
      (w : Serial2Wiring upstream downstream),
      opiniSpec upstream scheme 0 ∧
      opiniSpec downstream scheme 0 ∧
      BoundaryValuesAgree w ∧
      ComponentRandomnessDisjoint upstream downstream ∧
      (envsForInput downstream [false]).length = 2 ∧
      (envsForInput upstream [false, false]).length = 1 := by
  refine ⟨inputRandomOverlapUpstream, inputRandomOverlapDownstream,
    inputRandomOverlapWiring,
    opiniSpec_zero _ _ inputRandomOverlapUpstream_wf,
    opiniSpec_zero _ _ inputRandomOverlapDownstream_wf,
    inputRandomOverlap_boundaryValuesAgree, ?_, ?_, ?_⟩
  · simp [ComponentRandomnessDisjoint, inputRandomOverlapUpstream]
  · rfl
  · rfl

/-- Direct failure of the randomized-bind equation for the natural connected
realization above.  The connected experiment fixes `.inp 1 0 0` through the
second upstream input and therefore has one environment.  The proposed bind
first has one upstream environment and then runs the isolated downstream
experiment, which samples that same source twice.  Lists related by `Perm`
must have equal length, so the required factorization is impossible even
though both requested laws and both component O-PINI hypotheses hold. -/
theorem two_laws_allow_connected_experiment_factorization_failure
    (scheme : ExpansionScheme) :
    ∃ (upstream downstream composite : GadgetInstance)
      (w : Serial2Wiring upstream downstream),
      opiniSpec upstream scheme 0 ∧
      opiniSpec downstream scheme 0 ∧
      BoundaryValuesAgree w ∧
      ComponentRandomnessDisjoint upstream downstream ∧
      composite.WF ∧
      ¬ (envsForInput composite [false, false]).Perm
          ((envsForInput upstream [false, false]).flatMap fun _ =>
            envsForInput downstream [false]) := by
  refine ⟨inputRandomOverlapUpstream, inputRandomOverlapDownstream,
    inputRandomOverlapComposite, inputRandomOverlapWiring,
    opiniSpec_zero _ _ inputRandomOverlapUpstream_wf,
    opiniSpec_zero _ _ inputRandomOverlapDownstream_wf,
    inputRandomOverlap_boundaryValuesAgree, ?_,
    inputRandomOverlapComposite_wf, ?_⟩
  · simp [ComponentRandomnessDisjoint, inputRandomOverlapUpstream]
  · intro hperm
    have hlength := hperm.length_eq
    change 1 = 2 at hlength
    omega

end Serial2Obstructions

/-- End-to-end serial composition with a genuinely randomized downstream
boundary.  `firstSamples x` is the upstream joint transcript (including the
boundary shares demanded by O-PINI); `secondSamples first` is the concrete
conditional downstream experiment.  A downstream certificate supplies the
permutation-equivalent `secondSimulator`.  The conclusion is one simulator
for the whole concatenated transcript, not two componentwise statements. -/
theorem serial2_randomized_boundary_composes
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream)
    {xs : List (List Bool)} {projI : List Bool → List Bool}
    {firstSamples : List Bool → List Observation}
    (secondSamples secondSimulator : Observation → List Observation)
    (hsecond : ∀ first,
      (secondSamples first).Perm (secondSimulator first))
    (hsecond_nonempty : ∀ first, secondSimulator first ≠ [])
    (hfirst : SamplesSimulatableOn xs projI firstSamples) :
    w.description.WellFormed ∧
      SamplesSimulatableOn xs projI
        (bindSamples firstSamples secondSamples
          fun first second => first ++ second) := by
  exact ⟨w.description_wellFormed,
    samplesSimulatableOn_bind_congr secondSamples secondSimulator
      (fun first second => first ++ second) hsecond hsecond_nonempty hfirst⟩

/-- End-to-end randomized serial composition with downstream external-input
dependence.  In a concrete O-PINI instantiation, `x` is the full composite
external input, `projI x` contains only the selected external shares, and
`first` contains the selected connected output shares supplied jointly by the
upstream O-PINI simulator.  The theorem assembles one simulator for the whole
concatenated transcript. -/
theorem serial2_input_dependent_randomized_boundary_composes
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream)
    {xs : List (List Bool)} {projI : List Bool → List Bool}
    {firstSamples : List Bool → List Observation}
    (secondSamples : List Bool → Observation → List Observation)
    (secondSimulator : List Bool → Observation → List Observation)
    (hsecond : ∀ x ∈ xs, ∀ first,
      (secondSamples x first).Perm
        (secondSimulator (projI x) first))
    (hsecond_nonempty : ∀ q first, secondSimulator q first ≠ [])
    (hfirst : SamplesSimulatableOn xs projI firstSamples) :
    w.description.WellFormed ∧
      SamplesSimulatableOn xs projI
        (bindSamplesOn firstSamples secondSamples
          fun first second => first ++ second) := by
  exact ⟨w.description_wellFormed,
    samplesSimulatableOn_dependent_bind_congr secondSamples secondSimulator
      (fun first second => first ++ second) hsecond hsecond_nonempty hfirst⟩

/-- Whole-serial randomized composition from two exact component simulator
certificates.  The factorization premises state that the concrete connected
experiment feeds a valid upstream input into the first execution and, for
each sampled upstream transcript, a valid full downstream input into the
second execution.  The projection premises are the semantic wiring
obligations: selected upstream inputs come from the composite external input,
while selected downstream inputs may additionally be recovered from the
random upstream boundary transcript.

This is the two-certificate form of the CS21 simulator assembly.  It has no
determinism restriction on the boundary or either component experiment. -/
theorem serial2_two_certificate_randomized_boundary_composes
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream)
    {firstXs secondXs xs : List (List Bool)}
    {firstProjection secondProjection projection :
      List Bool → List Bool}
    {firstSamples secondSamples : List Bool → List Observation}
    (firstInput : List Bool → List Bool)
    (secondInput : List Bool → Observation → List Bool)
    (firstKey : List Bool → List Bool)
    (secondKey : List Bool → Observation → List Bool)
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
    w.description.WellFormed ∧
      SamplesSimulatableOn xs projection
        (bindSamplesOn
          (fun x => firstSamples (firstInput x))
          (fun x first => secondSamples (secondInput x first))
          fun first second => first ++ second) := by
  exact ⟨w.description_wellFormed,
    samplesSimulatableOn_dependent_compose firstInput secondInput
      firstKey secondKey (fun first second => first ++ second)
      hfirstInput hfirstProjection hsecondInput hsecondProjection
      hfirst hsecond⟩

/-- Whole-experiment form of the randomized two-certificate theorem.  Here
`envsOf` and `obs` are the concrete semantics chosen for the connected serial
execution.  The sole semantic agreement premise says that evaluating that
execution gives the same finite observation multiset as first sampling the
upstream component and then conditionally sampling the downstream component.

The conclusion uses the audited `SimulatableOn` predicate directly.  Thus no
determinism assumption remains: once a concrete semantics for `description`
proves `hfactorization`, the component certificates assemble into one
simulator for its complete transcript. -/
theorem serial2_two_certificate_connected_experiment_composes
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream)
    {firstXs secondXs xs : List (List Bool)}
    {firstProjection secondProjection projection :
      List Bool → List Bool}
    {firstSamples secondSamples : List Bool → List Observation}
    {envsOf : List Bool → List Env} {obs : Env → Observation}
    (firstInput : List Bool → List Bool)
    (secondInput : List Bool → Observation → List Bool)
    (firstKey : List Bool → List Bool)
    (secondKey : List Bool → Observation → List Bool)
    (hfirstInput : ∀ x ∈ xs, firstInput x ∈ firstXs)
    (hfirstProjection : ∀ x ∈ xs,
      firstProjection (firstInput x) = firstKey (projection x))
    (hsecondInput : ∀ x ∈ xs, ∀ first ∈ firstSamples (firstInput x),
      secondInput x first ∈ secondXs)
    (hsecondProjection : ∀ x ∈ xs,
      ∀ first ∈ firstSamples (firstInput x),
        secondProjection (secondInput x first) =
          secondKey (projection x) first)
    (hfactorization : ∀ x ∈ xs,
      ((envsOf x).map obs).Perm
        (bindSamplesOn
          (fun x => firstSamples (firstInput x))
          (fun x first => secondSamples (secondInput x first))
          (fun first second => first ++ second) x))
    (hfirst : SamplesSimulatableOn firstXs firstProjection firstSamples)
    (hsecond : SamplesSimulatableOn secondXs secondProjection secondSamples) :
    w.description.WellFormed ∧
      SimulatableOn xs envsOf projection obs := by
  have hassembled :=
    serial2_two_certificate_randomized_boundary_composes w
      firstInput secondInput firstKey secondKey
      hfirstInput hfirstProjection hsecondInput hsecondProjection
      hfirst hsecond
  refine ⟨hassembled.1,
    samplesSimulatableOn_to_simulatableOn ?_⟩
  rcases hassembled.2 with ⟨simulator, hpositive, hperm⟩
  refine ⟨simulator, hpositive, ?_⟩
  intro x hx
  exact (hfactorization x hx).trans (hperm x hx)

/-- End-to-end two-stage composition for the deterministic-boundary case.
Unlike the componentwise results below, this conclusion is one simulator for
the concatenated transcript of the serial pair. -/
theorem serial2_deterministic_boundary_composes
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream)
    {xs : List (List Bool)} {envsOf : List Bool → List Env}
    {projI : List Bool → List Bool}
    {first second : Env → Observation}
    (next : Observation → Observation)
    (hfirst : SimulatableOn xs envsOf projI first)
    (hboundary : ∀ env, second env = next (first env)) :
    w.description.WellFormed ∧
      SimulatableOn xs envsOf projI
        (fun env => first env ++ second env) := by
  exact ⟨w.description_wellFormed,
    simulatableOn_deterministic_serial next hfirst hboundary⟩

/-- One backward O-PINI share-propagation step for a serial pair.  First use
the downstream certificate to obtain the input-share set `downstreamB`; the
connected upstream output must then expose the union of that set and the
actually demanded downstream output shares.  Its size is bounded by the sum
of downstream internal probes and output probes, so the upstream O-PINI
certificate is applicable within the original global order `t`.

The result contains exact randomized sample simulators for both components;
these are the two inputs consumed by
`serial2_two_certificate_connected_experiment_composes`. -/
theorem serial2_opini_probe_split_certificates
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream)
    (scheme : ExpansionScheme) (t : Nat)
    (hupstream : opiniSpec upstream scheme t)
    (hdownstream : opiniSpec downstream scheme t)
    (upstreamInternal downstreamInternal : List Node) (outputs : List Nat)
    (hupstreamInternal : upstreamInternal ∈
      subsetsUpTo t (internalNodes upstream))
    (hdownstreamInternal : downstreamInternal ∈
      subsetsUpTo t (internalNodes downstream))
    (hinternalsBound : upstreamInternal.length + downstreamInternal.length ≤ t)
    (houtputs : outputs ∈
      subsetsUpTo
        (t - (upstreamInternal.length + downstreamInternal.length))
        (List.range downstream.d)) :
    ∃ downstreamB ∈
        subsetsUpTo downstreamInternal.length (List.range downstream.d),
      let propagated := shareUnion upstream.d outputs downstreamB
      ∃ upstreamB ∈
          subsetsUpTo upstreamInternal.length (List.range upstream.d),
        SamplesSimulatableOn (boolVectors (inputWidth upstream))
          (projection upstream (propagated ++ upstreamB))
          (fun x => (envsForInput upstream x).map
            (observe upstream
              ((expandedNodes upstream scheme
                (upstreamInternal ++ propagated.map upstream.output)) ++
                  upstreamB.map upstream.output).eraseDups)) ∧
        SamplesSimulatableOn (boolVectors (inputWidth downstream))
          (projection downstream (outputs ++ downstreamB))
          (fun x => (envsForInput downstream x).map
            (observe downstream
              ((expandedNodes downstream scheme
                (downstreamInternal ++ outputs.map downstream.output)) ++
                  downstreamB.map downstream.output).eraseDups)) := by
  obtain ⟨downstreamB, hdownstreamB, hdownstreamSamples⟩ :=
    opiniSpec_to_samples downstream scheme t hdownstream
      downstreamInternal hdownstreamInternal outputs (by
        apply mem_subsetsUpTo_of_sublist
        · exact subsetsUpTo_sublist _ _ _ houtputs
        · have hbound := subsetsUpTo_bound _ _ _ houtputs
          omega)
  let propagated := shareUnion upstream.d outputs downstreamB
  have houtputsMem : ∀ share ∈ outputs, share < upstream.d := by
    intro share hshare
    rw [w.same_shares]
    simpa using (subsetsUpTo_sublist _ _ _ houtputs).mem hshare
  have hdownstreamBMem : ∀ share ∈ downstreamB, share < upstream.d := by
    intro share hshare
    rw [w.same_shares]
    simpa using (subsetsUpTo_sublist _ _ _ hdownstreamB).mem hshare
  have hpropagatedBound : propagated.length ≤
      t - upstreamInternal.length := by
    have hunion := shareUnion_length_le upstream.d outputs downstreamB
      houtputsMem hdownstreamBMem
    have houtputBound := subsetsUpTo_bound _ _ _ houtputs
    have hdownstreamBound := subsetsUpTo_bound _ _ _ hdownstreamB
    dsimp [propagated] at hunion ⊢
    omega
  have hpropagated : propagated ∈
      subsetsUpTo (t - upstreamInternal.length) (List.range upstream.d) := by
    apply mem_subsetsUpTo_of_sublist
    · exact shareUnion_sublist upstream.d outputs downstreamB
    · exact hpropagatedBound
  obtain ⟨upstreamB, hupstreamB, hupstreamSamples⟩ :=
    opiniSpec_to_samples upstream scheme t hupstream
      upstreamInternal hupstreamInternal propagated hpropagated
  exact ⟨downstreamB, hdownstreamB, upstreamB, hupstreamB,
    hupstreamSamples, hdownstreamSamples⟩

/-- The boundary-share set produced by the serial O-PINI backward step is a
strict subset whenever the global probing order is below the sharing order.
Consequently its distribution is independent of the Boolean value encoded
at the connected boundary.

This specializes `boundaryProjection_secret_independent` to the exact union
of demanded downstream output shares and the downstream O-PINI witness.  The
strictness proof is the global CS21 probe-budget argument: output demands use
the budget left after both components' internal probes, while the downstream
witness uses at most the number of downstream internal probes. -/
theorem serial2_propagated_boundary_secret_independent
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream) (t : Nat)
    (upstreamInternal downstreamInternal : List Node)
    (outputs downstreamB : List Nat)
    (horder : t < upstream.d)
    (hinternalsBound :
      upstreamInternal.length + downstreamInternal.length ≤ t)
    (houtputs : outputs ∈
      subsetsUpTo
        (t - (upstreamInternal.length + downstreamInternal.length))
        (List.range downstream.d))
    (hdownstreamB : downstreamB ∈
      subsetsUpTo downstreamInternal.length (List.range downstream.d)) :
    let propagated := shareUnion upstream.d outputs downstreamB
    ((xorSharings upstream.d false).map (selectBits propagated)).Perm
      ((xorSharings upstream.d true).map (selectBits propagated)) := by
  dsimp only
  apply boundaryProjection_secret_independent
  · exact shareUnion_sublist upstream.d outputs downstreamB
  · have houtputsMem : ∀ share ∈ outputs, share < upstream.d := by
      intro share hshare
      rw [w.same_shares]
      simpa using (subsetsUpTo_sublist _ _ _ houtputs).mem hshare
    have hdownstreamBMem : ∀ share ∈ downstreamB, share < upstream.d := by
      intro share hshare
      rw [w.same_shares]
      simpa using (subsetsUpTo_sublist _ _ _ hdownstreamB).mem hshare
    have hunion := shareUnion_length_le upstream.d outputs downstreamB
      houtputsMem hdownstreamBMem
    have houtputsBound := subsetsUpTo_bound _ _ _ houtputs
    have hdownstreamBound := subsetsUpTo_bound _ _ _ hdownstreamB
    omega

/-- The preceding connected-boundary independence survives an arbitrary
randomized downstream continuation.  This is the distributional form used
when the second component has fresh randomness: no determinism hypothesis is
placed on `kernel`. -/
theorem serial2_propagated_boundary_kernel_secret_independent
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream) (t : Nat)
    (upstreamInternal downstreamInternal : List Node)
    (outputs downstreamB : List Nat)
    (horder : t < upstream.d)
    (hinternalsBound :
      upstreamInternal.length + downstreamInternal.length ≤ t)
    (houtputs : outputs ∈
      subsetsUpTo
        (t - (upstreamInternal.length + downstreamInternal.length))
        (List.range downstream.d))
    (hdownstreamB : downstreamB ∈
      subsetsUpTo downstreamInternal.length (List.range downstream.d))
    (kernel : List Bool → List Observation) :
    let propagated := shareUnion upstream.d outputs downstreamB
    (boundaryKernelSamples upstream.d false propagated kernel).Perm
      (boundaryKernelSamples upstream.d true propagated kernel) := by
  dsimp only
  exact
    (serial2_propagated_boundary_secret_independent w t upstreamInternal
      downstreamInternal outputs downstreamB horder hinternalsBound houtputs
      hdownstreamB).flatMap_right kernel

/-- The exact upstream observation multiset used by one serial O-PINI probe
split.  Naming it separately keeps the connected-experiment law below tied to
the very probe expansion certified by `opiniSpec`, rather than to an
unconstrained abstract first-stage transcript. -/
def serial2UpstreamProbeSamples (upstream : GadgetInstance)
    (scheme : ExpansionScheme) (upstreamInternal propagated upstreamB : List Node)
    : List Bool → List Observation := fun x =>
  (envsForInput upstream x).map
    (observe upstream
      ((expandedNodes upstream scheme
        (upstreamInternal ++ propagated)) ++ upstreamB).eraseDups)

/-- The exact downstream observation multiset used by one serial O-PINI probe
split. -/
def serial2DownstreamProbeSamples (downstream : GadgetInstance)
    (scheme : ExpansionScheme) (downstreamInternal outputs downstreamB : List Node)
    : List Bool → List Observation := fun x =>
  (envsForInput downstream x).map
    (observe downstream
      ((expandedNodes downstream scheme
        (downstreamInternal ++ outputs)) ++ downstreamB).eraseDups)

/-- General whole-connected-experiment theorem obtained directly from two
O-PINI certificates.  The continuation premise is the semantic part of serial
wiring: for whichever share witnesses O-PINI chooses, it reconstructs both
component simulator indices from the allowed composite projection and proves
that the concrete transition+glitch experiment factors as a randomized bind.

Unlike the lower-level two-certificate theorem, callers do not supply
component simulators.  They are extracted from `hupstream` and `hdownstream`
after the CS21 backward share-demand step, then assembled into one simulator
for `obs`.  There is no determinism restriction on either boundary or
component randomness. -/
theorem serial2_opini_connected_experiment_simulatable
    {upstream downstream : GadgetInstance}
    (w : Serial2Wiring upstream downstream)
    (scheme : ExpansionScheme) (t : Nat)
    (hupstream : opiniSpec upstream scheme t)
    (hdownstream : opiniSpec downstream scheme t)
    (upstreamInternal downstreamInternal : List Node) (outputs : List Nat)
    (hupstreamInternal : upstreamInternal ∈
      subsetsUpTo t (internalNodes upstream))
    (hdownstreamInternal : downstreamInternal ∈
      subsetsUpTo t (internalNodes downstream))
    (hinternalsBound : upstreamInternal.length + downstreamInternal.length ≤ t)
    (houtputs : outputs ∈
      subsetsUpTo
        (t - (upstreamInternal.length + downstreamInternal.length))
        (List.range downstream.d))
    {xs : List (List Bool)} {projection : List Bool → List Bool}
    {envsOf : List Bool → List Env} {obs : Env → Observation}
    (firstInput : List Bool → List Bool)
    (secondInput : List Bool → Observation → List Bool)
    (hconnected :
      ∀ downstreamB ∈
          subsetsUpTo downstreamInternal.length (List.range downstream.d),
        let propagated := shareUnion upstream.d outputs downstreamB
        ∀ upstreamB ∈
            subsetsUpTo upstreamInternal.length (List.range upstream.d),
          ∃ firstKey : List Bool → List Bool,
          ∃ secondKey : List Bool → Observation → List Bool,
            (∀ x ∈ xs,
              firstInput x ∈ boolVectors (inputWidth upstream)) ∧
            (∀ x ∈ xs,
              Gadget.projection upstream (propagated ++ upstreamB)
                  (firstInput x) = firstKey (projection x)) ∧
            (∀ x ∈ xs, ∀ first ∈
                serial2UpstreamProbeSamples upstream scheme upstreamInternal
                  (propagated.map upstream.output) (upstreamB.map upstream.output)
                  (firstInput x),
              secondInput x first ∈ boolVectors (inputWidth downstream)) ∧
            (∀ x ∈ xs, ∀ first ∈
                serial2UpstreamProbeSamples upstream scheme upstreamInternal
                  (propagated.map upstream.output) (upstreamB.map upstream.output)
                  (firstInput x),
              Gadget.projection downstream (outputs ++ downstreamB)
                  (secondInput x first) = secondKey (projection x) first) ∧
            ∀ x ∈ xs,
              ((envsOf x).map obs).Perm
                (bindSamplesOn
                  (fun x => serial2UpstreamProbeSamples upstream scheme
                    upstreamInternal (propagated.map upstream.output)
                    (upstreamB.map upstream.output) (firstInput x))
                  (fun x first => serial2DownstreamProbeSamples downstream scheme
                    downstreamInternal (outputs.map downstream.output)
                    (downstreamB.map downstream.output) (secondInput x first))
                  (fun first second => first ++ second) x)) :
    w.description.WellFormed ∧
      SimulatableOn xs envsOf projection obs := by
  obtain ⟨downstreamB, hdownstreamB, upstreamB, hupstreamB,
      hupstreamSamples, hdownstreamSamples⟩ :=
    serial2_opini_probe_split_certificates w scheme t hupstream hdownstream
      upstreamInternal downstreamInternal outputs hupstreamInternal
      hdownstreamInternal hinternalsBound houtputs
  let propagated := shareUnion upstream.d outputs downstreamB
  obtain ⟨firstKey, secondKey, hfirstInput, hfirstProjection,
      hsecondInput, hsecondProjection, hfactorization⟩ :=
    hconnected downstreamB hdownstreamB upstreamB hupstreamB
  apply serial2_two_certificate_connected_experiment_composes w
    firstInput secondInput firstKey secondKey
  · exact hfirstInput
  · exact hfirstProjection
  · exact hsecondInput
  · exact hsecondProjection
  · exact hfactorization
  · exact hupstreamSamples
  · exact hdownstreamSamples

/-- Two O-PINI component certificates yield two PINI certificates, while the
wiring witness independently certifies that the pair really is a Definition-7
serial composition.  This theorem intentionally does not claim whole-composite
PINI; that requires the missing connected-experiment/fixpoint semantics. -/
theorem serial2_opini_components_pini
    {upstream downstream : GadgetInstance} (w : Serial2Wiring upstream downstream)
    (scheme : ExpansionScheme) (t : Nat)
    (hupstream : opiniSpec upstream scheme t)
    (hdownstream : opiniSpec downstream scheme t) :
    (w.description).WellFormed ∧
      piniSpec upstream scheme t ∧ piniSpec downstream scheme t := by
  exact ⟨w.description_wellFormed,
    opini_implies_pini upstream scheme t hupstream,
    opini_implies_pini downstream scheme t hdownstream⟩

/-- Boundary assumptions needed to turn one component's PINI certificate into
its direct probing-security specification. -/
structure ProbingBoundary (g : GadgetInstance) (t : Nat) : Prop where
  order_lt_shares : t < g.d
  outputs_are_members : ∀ i, i < g.d → g.member (g.output i) = true
  outputs_injective : ∀ i j, i < g.d → j < g.d →
    g.output i = g.output j → i = j
  inputs_reached : ∀ x ∈ boolVectors (inputWidth g),
    (envsForInput g x).length > 0

/-- Kernel-checked security consequence for both components of a serial
Definition-7 composition.  It uses both O-PINI hypotheses and both boundary
hypotheses.  As above, the conclusion is explicitly componentwise. -/
theorem serial2_opini_components_probing
    {upstream downstream : GadgetInstance} (w : Serial2Wiring upstream downstream)
    (scheme : ExpansionScheme) (t : Nat)
    (hupstream : opiniSpec upstream scheme t)
    (hdownstream : opiniSpec downstream scheme t)
    (bupstream : ProbingBoundary upstream t)
    (bdownstream : ProbingBoundary downstream t) :
    (w.description).WellFormed ∧
      probingSecureSpec upstream scheme t ∧
      probingSecureSpec downstream scheme t := by
  have hpini := serial2_opini_components_pini w scheme t hupstream hdownstream
  refine ⟨hpini.1, ?_, ?_⟩
  · exact pini_implies_probing upstream scheme t
      bupstream.order_lt_shares bupstream.outputs_are_members
      bupstream.outputs_injective bupstream.inputs_reached hpini.2.1
  · exact pini_implies_probing downstream scheme t
      bdownstream.order_lt_shares bdownstream.outputs_are_members
      bdownstream.outputs_injective bdownstream.inputs_reached hpini.2.2

end Composition
end LeanSec
