import LeanSec.Composition.GenericSerial2

namespace LeanSec
namespace Composition
namespace Universal

open Gadget

/-!
`SerialComposable` is the non-security data suggested by Workstream G.  It
makes the output nodes and the member boundary explicit, and retains the raw
source list on which a serial compiler applies its left/right namespace.

This record deliberately contains no security certificate and no finished
composite.  In particular, putting `probingSecureSpec (glue ...)` into this
record would make the desired theorem circular.
-/
structure SerialComposable where
  gadget : GadgetInstance
  outputNodesToEmbed : List Node
  outputNodesToEmbed_eq : outputNodesToEmbed = outputNodes gadget
  randomnessAtoms : List Src
  randomnessAtoms_eq : randomnessAtoms = gadget.randomness
  memberBoundary : Node → Bool
  memberBoundary_eq : memberBoundary = gadget.member

namespace SerialComposable

/-- A static gate-input position.  The cycle is deliberately absent: a
`Gate.inputs` entry is shared by every cycle of the unrolling. -/
structure EdgeSite where
  gate : Nat
  input : Nat
deriving DecidableEq, Repr

/-- The environment source produced by a source gate at one cycle. -/
def gateSourceAt? (kind : GateKind) (cycle : Nat) : Option Src :=
  match kind with
  | .rnd random => some (.rnd random cycle)
  | .inp sharing share => some (.inp sharing share cycle)
  | .ini initial => some (.ini initial cycle)
  | .ctl control => some (.ctl control cycle)
  | _ => none

/-- The source read by a static edge at one unrolled cycle, when that edge
reads an environment source rather than an already evaluated node. -/
def edgeReferencedSrcAt? (circuit : Circuit) (site : EdgeSite)
    (cycle : Nat) : Option Src :=
  match circuit.gates[site.gate]? with
  | none => none
  | some gate =>
      match gate.inputs[site.input]? with
      | none => none
      | some (source, latency) =>
          if latency ≤ cycle then
            match circuit.gates[source]? with
            | none => none
            | some sourceGate => gateSourceAt? sourceGate.kind (cycle - latency)
          else
            some (.iniReg site.gate)

/-- Every syntactically present gate-input position of a circuit. -/
def edgeSites (circuit : Circuit) : List EdgeSite :=
  (List.range circuit.gates.size).flatMap fun gate =>
    match circuit.gates[gate]? with
    | none => []
    | some entry =>
        (List.range entry.inputs.length).map fun input => ⟨gate, input⟩

/-- The finite scan requested by the serial compiler: all static edges which,
at some in-window cycle, read exactly the declared input-arrival source. -/
def consumingSites (gadget : GadgetInstance) (input share : Nat) :
    List EdgeSite :=
  (edgeSites gadget.circuit).filter fun site =>
    (List.range gadget.horizon).any fun cycle =>
      edgeReferencedSrcAt? gadget.circuit site cycle ==
        some (gadget.inputArrival input share)

/-- A declared input share is non-orphan precisely when the circuit scan finds
at least one consuming edge. -/
def InputShareConsumed (gadget : GadgetInstance)
    (input share : Nat) : Prop :=
  consumingSites gadget input share ≠ []

/-- All shares of a connected input must be structurally consumed. -/
def ConnectedInputConsumed (gadget : GadgetInstance) (input : Nat) : Prop :=
  ∀ share, share < gadget.d → InputShareConsumed gadget input share

/-- The ordinary serial compatibility data which does not follow from the
two O-PINI hypotheses.  `connected_input_consumed` is the non-orphan
well-formedness premise: every share of the selected input has a real
consumer in the downstream circuit. -/
structure Compatible (up down : SerialComposable) (t : Nat) where
  downstreamInput : Nat
  input_bound : downstreamInput < down.gadget.inputCount
  same_shares : up.gadget.d = down.gadget.d
  order_lt_shares : t < up.gadget.d
  connected_input_consumed :
    ConnectedInputConsumed down.gadget downstreamInput

end SerialComposable

/-! ## A source namespace which really is disjoint by construction -/

/-- Even and odd identifiers form the two sides of the serial namespace.
Every source constructor is relabeled, including `iniReg`, whose identifier
is a gate index in the evaluator.  A future circuit compiler must therefore
apply this map in lockstep to gates and edges as well as boundary lists. -/
def namespaceSrc (right : Bool) : Src → Src
  | .inp sharing share cycle =>
      .inp (2 * sharing + right.toNat) share cycle
  | .rnd random cycle =>
      .rnd (2 * random + right.toNat) cycle
  | .ini initial cycle =>
      .ini (2 * initial + right.toNat) cycle
  | .ctl control cycle =>
      .ctl (2 * control + right.toNat) cycle
  | .iniReg gate =>
      .iniReg (2 * gate + right.toNat)

/-- The two images of the canonical namespace cannot collide. -/
theorem namespaceSrc_left_ne_right (left right : Src) :
    namespaceSrc false left ≠ namespaceSrc true right := by
  cases left <;> cases right <;> simp [namespaceSrc] <;> omega

/-- Relabel all source atoms belonging to one side of a serial composition. -/
def namespacedSources (right : Bool) (sources : List Src) : List Src :=
  sources.map (namespaceSrc right)

/-- Component randomness disjointness holds for the relabeled lists without
any premise on the original source names. -/
theorem namespacedSources_disjoint (left right : List Src) :
    ∀ src, src ∈ namespacedSources false left →
      src ∉ namespacedSources true right := by
  intro src hleft hright
  simp only [namespacedSources, List.mem_map] at hleft hright
  rcases hleft with ⟨leftSrc, _, rfl⟩
  rcases hright with ⟨rightSrc, _, heq⟩
  exact namespaceSrc_left_ne_right leftSrc rightSrc heq.symm

/-- The second freshness law is the same constructor-level separation: left
external inputs cannot collide with right randomness after relabeling. -/
theorem namespacedInputs_randomness_disjoint
    (up : SerialComposable) (down : SerialComposable) :
    ∀ input, input < up.gadget.inputCount →
      ∀ share, share < up.gadget.d →
        namespaceSrc false (up.gadget.inputArrival input share) ∉
          namespacedSources true down.randomnessAtoms := by
  intro input _ share _ hmem
  simp only [namespacedSources, List.mem_map] at hmem
  rcases hmem with ⟨source, _, heq⟩
  exact namespaceSrc_left_ne_right
    (up.gadget.inputArrival input share) source heq.symm

/-! ## The circuit-rewrite compiler -/

/-- Gate and node indices use the same even/odd namespace as `iniReg`. -/
def namespaceGateIndex (right : Bool) (gate : Nat) : Nat :=
  2 * gate + right.toNat

def namespaceNode (right : Bool) (node : Node) : Node :=
  { gate := namespaceGateIndex right node.gate, cycle := node.cycle }

/-- Rename the identifiers carried by source gates. -/
def namespaceGateKind (right : Bool) : GateKind → GateKind
  | .xor => .xor
  | .and => .and
  | .not => .not
  | .reg => .reg
  | .mux => .mux
  | .const value => .const value
  | .rnd random => .rnd (2 * random + right.toNat)
  | .inp sharing share => .inp (2 * sharing + right.toNat) share
  | .ini initial => .ini (2 * initial + right.toNat)
  | .ctl control => .ctl (2 * control + right.toNat)

/-- Namespace a component gate without changing its latency discipline. -/
def namespaceGate (right : Bool) (gate : Gate) : Gate :=
  { kind := namespaceGateKind right gate.kind
    inputs := gate.inputs.map fun edge =>
      (namespaceGateIndex right edge.1, edge.2) }

/-- The first share whose declared arrival is read by a static downstream
edge.  On honest gadgets each site belongs to at most one share; retaining
`Option` makes the compiler total even when malformed arrivals alias. -/
def connectedShareAt? (down : GadgetInstance) (input : Nat)
    (site : SerialComposable.EdgeSite) : Option Nat :=
  (List.range down.d).find? fun share =>
    (List.range down.horizon).any fun cycle =>
      SerialComposable.edgeReferencedSrcAt? down.circuit site cycle ==
        some (down.inputArrival input share)

/-- Rewrite one downstream edge.  A consumer of the selected input share is
redirected to the even-namespaced upstream output gate; every other edge stays
inside the odd downstream namespace.  The original latency is retained.  Thus
the rewrite denotes the declared output node at a matching cycle when the
upstream output cycle agrees with the downstream source cycle, as it does in
the concrete serial pair and in the finite witness below.  `Compatible` has no
general cycle-alignment premise; the witness shows that even an aligned match
at one cycle cannot make this static edge cycle-local. -/
def rewriteDownstreamEdge (up down : GadgetInstance) (input : Nat)
    (site : SerialComposable.EdgeSite) (edge : Nat × Nat) : Nat × Nat :=
  match connectedShareAt? down input site with
  | some share => (namespaceGateIndex false (up.output share).gate, edge.2)
  | none => (namespaceGateIndex true edge.1, edge.2)

/-- Namespace one downstream gate and rewrite precisely its scanned connected
input edges. -/
def rewriteDownstreamGate (up down : GadgetInstance) (input gateIndex : Nat)
    (gate : Gate) : Gate :=
  { kind := namespaceGateKind true gate.kind
    inputs := gate.inputs.zipIdx.map fun (edge, inputIndex) =>
      rewriteDownstreamEdge up down input ⟨gateIndex, inputIndex⟩ edge }

private def fillerGate : Gate := { kind := .const false, inputs := [] }

/-- The even/odd union of the upstream circuit and rewritten downstream
circuit.  Unused parity slots are filled by constants, so original gate `g`
always embeds at `2*g + side`. -/
def glueCircuit (up down : GadgetInstance) (input : Nat) : Circuit :=
  let size := 2 * max up.circuit.gates.size down.circuit.gates.size
  { gates := ((List.range size).map fun gate =>
      if gate % 2 = 0 then
        match up.circuit.gates[gate / 2]? with
        | some entry => namespaceGate false entry
        | none => fillerGate
      else
        match down.circuit.gates[gate / 2]? with
        | some entry => rewriteDownstreamGate up down input (gate / 2) entry
        | none => fillerGate).toArray }

def namespaceFixing (right : Bool) (fixing : List (Src × Bool)) :
    List (Src × Bool) :=
  fixing.map fun entry => (namespaceSrc right entry.1, entry.2)

/-- Skip the hidden downstream input while enumerating the composite's
external input sharings. -/
def unhideDownstreamInput (hidden external : Nat) : Nat :=
  if external < hidden then external else external + 1

/-- The total generic circuit splice.  Upstream inputs precede all unconnected
downstream inputs; the downstream output sharing is the composite output. -/
def glue (up down : SerialComposable) (t : Nat)
    (compat : SerialComposable.Compatible up down t) : GadgetInstance :=
  { circuit := glueCircuit up.gadget down.gadget compat.downstreamInput
    horizon := max up.gadget.horizon down.gadget.horizon
    d := down.gadget.d
    inputCount := up.gadget.inputCount + (down.gadget.inputCount - 1)
    inputArrival := fun input share =>
      if input < up.gadget.inputCount then
        namespaceSrc false (up.gadget.inputArrival input share)
      else
        namespaceSrc true (down.gadget.inputArrival
          (unhideDownstreamInput compat.downstreamInput
            (input - up.gadget.inputCount)) share)
    output := fun share => namespaceNode true (down.gadget.output share)
    member := fun node =>
      if node.gate % 2 = 0 then
        up.gadget.member { gate := node.gate / 2, cycle := node.cycle }
      else
        down.gadget.member { gate := node.gate / 2, cycle := node.cycle }
    randomness := namespacedSources false up.randomnessAtoms ++
      namespacedSources true down.randomnessAtoms
    publicFixing := namespaceFixing false up.gadget.publicFixing ++
      namespaceFixing true down.gadget.publicFixing }

/-! ## Instances for the concrete serial pair -/

def concreteUpstream : SerialComposable where
  gadget := ConcreteSerial2.upstream
  outputNodesToEmbed := outputNodes ConcreteSerial2.upstream
  outputNodesToEmbed_eq := rfl
  randomnessAtoms := ConcreteSerial2.upstream.randomness
  randomnessAtoms_eq := rfl
  memberBoundary := ConcreteSerial2.upstream.member
  memberBoundary_eq := rfl

def concreteDownstream : SerialComposable where
  gadget := ConcreteSerial2.downstream
  outputNodesToEmbed := outputNodes ConcreteSerial2.downstream
  outputNodesToEmbed_eq := rfl
  randomnessAtoms := ConcreteSerial2.downstream.randomness
  randomnessAtoms_eq := rfl
  memberBoundary := ConcreteSerial2.downstream.member
  memberBoundary_eq := rfl

def concreteCompatible :
    SerialComposable.Compatible concreteUpstream concreteDownstream 1 where
  downstreamInput := 0
  input_bound := by decide
  same_shares := rfl
  order_lt_shares := by decide
  connected_input_consumed := by
    intro share hshare
    change share < 2 at hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl
    · change SerialComposable.consumingSites ConcreteSerial2.downstream 0 0 ≠ []
      decide
    · change SerialComposable.consumingSites ConcreteSerial2.downstream 0 1 ≠ []
      decide

theorem concrete_component_opini :
    opiniSpec concreteUpstream.gadget transitionGlitch 1 ∧
      opiniSpec concreteDownstream.gadget transitionGlitch 1 :=
  ⟨ConcreteSerial2.upstream_opini, ConcreteSerial2.downstream_opini⟩

/-! ## Finite adjacent-cycle obstruction to the universal theorem -/

/-- One pair of input gates is reused across two cycles.  The component API
declares cycle 0 to be input sharing 0 and cycle 1 to be input sharing 1. -/
def cycleMismatchUpCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] }
    ] }

def cycleMismatchUpGadget : GadgetInstance :=
  { circuit := cycleMismatchUpCircuit
    horizon := 2
    d := 2
    inputCount := 2
    inputArrival := fun input share => .inp 0 share input
    output := fun share =>
      if share = 0 then { gate := 0, cycle := 0 }
      else { gate := 1, cycle := 0 }
    member := fun node => node.gate < 2 && node.cycle < 2
    randomness := [] }

/-- The downstream declares its inputs at cycle 0.  Its XOR edge therefore
passes the non-orphan scan at cycle 0, but its member/output node is at cycle
1, where the isolated component sees the source gates pinned to zero. -/
def cycleMismatchDownCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (1, 0)] },
      { kind := .const false, inputs := [] }
    ] }

def cycleMismatchDownGadget : GadgetInstance :=
  { circuit := cycleMismatchDownCircuit
    horizon := 2
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share =>
      if share = 0 then { gate := 2, cycle := 1 }
      else { gate := 3, cycle := 1 }
    member := fun node => node.cycle == 1 && node.gate < 4
    randomness := [] }

def cycleMismatchUp : SerialComposable where
  gadget := cycleMismatchUpGadget
  outputNodesToEmbed := outputNodes cycleMismatchUpGadget
  outputNodesToEmbed_eq := rfl
  randomnessAtoms := cycleMismatchUpGadget.randomness
  randomnessAtoms_eq := rfl
  memberBoundary := cycleMismatchUpGadget.member
  memberBoundary_eq := rfl

def cycleMismatchDown : SerialComposable where
  gadget := cycleMismatchDownGadget
  outputNodesToEmbed := outputNodes cycleMismatchDownGadget
  outputNodesToEmbed_eq := rfl
  randomnessAtoms := cycleMismatchDownGadget.randomness
  randomnessAtoms_eq := rfl
  memberBoundary := cycleMismatchDownGadget.member
  memberBoundary_eq := rfl

def cycleMismatchCompatible :
    SerialComposable.Compatible cycleMismatchUp cycleMismatchDown 1 where
  downstreamInput := 0
  input_bound := by decide
  same_shares := rfl
  order_lt_shares := by decide
  connected_input_consumed := by
    intro share hshare
    change share < 2 at hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl
    · change SerialComposable.consumingSites cycleMismatchDownGadget 0 0 ≠ []
      decide
    · change SerialComposable.consumingSites cycleMismatchDownGadget 0 1 ≠ []
      decide

theorem cycleMismatchUp_wf : cycleMismatchUpGadget.WF := by
  refine ⟨?_, by decide, ?_, ?_, ?_, ?_⟩
  · simp [cycleMismatchUpGadget, cycleMismatchUpCircuit, Circuit.WF,
      Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
      Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
      Circuit.hasRemainingPred]
  · change ([({ gate := 0, cycle := 0 } : Node),
      ({ gate := 1, cycle := 0 } : Node)]).Nodup
    decide
  · simp [outputNodes, memberNodes, nodes, cycleMismatchUpGadget,
      cycleMismatchUpCircuit]
    intro share hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl
    · refine ⟨?_, by decide⟩
      exact ⟨0, by omega, 0, by omega, rfl⟩
    · refine ⟨?_, by decide⟩
      exact ⟨0, by omega, 1, by omega, rfl⟩
  · simp [memberNodes, nodes, combInputNodes, cycleMismatchUpGadget,
      cycleMismatchUpCircuit]
    intro cycle hcycle gate hgate
    have hc : cycle = 0 ∨ cycle = 1 := by omega
    have hg : gate = 0 ∨ gate = 1 := by omega
    rcases hc with rfl | rfl <;> rcases hg with rfl | rfl <;> simp
  · simp [memberNodes, nodes, transInputNodes, cycleMismatchUpGadget,
      cycleMismatchUpCircuit]
    intro cycle hcycle gate hgate
    have hc : cycle = 0 ∨ cycle = 1 := by omega
    have hg : gate = 0 ∨ gate = 1 := by omega
    rcases hc with rfl | rfl <;> rcases hg with rfl | rfl <;> simp

theorem cycleMismatchDown_wf : cycleMismatchDownGadget.WF := by
  refine ⟨?_, by decide, ?_, ?_, ?_, ?_⟩
  · simp [cycleMismatchDownGadget, cycleMismatchDownCircuit, Circuit.WF,
      Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
      Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
      Circuit.hasRemainingPred]
  · change ([({ gate := 2, cycle := 1 } : Node),
      ({ gate := 3, cycle := 1 } : Node)]).Nodup
    decide
  · simp [outputNodes, memberNodes, nodes, cycleMismatchDownGadget,
      cycleMismatchDownCircuit]
    intro share hshare
    have : share = 0 ∨ share = 1 := by omega
    rcases this with rfl | rfl
    · refine ⟨?_, by decide⟩
      exact ⟨1, by omega, 2, by omega, rfl⟩
    · refine ⟨?_, by decide⟩
      exact ⟨1, by omega, 3, by omega, rfl⟩
  · simp [memberNodes, nodes, combInputNodes, cycleMismatchDownGadget,
      cycleMismatchDownCircuit]
    intro cycle hcycle gate hgate
    have hc : cycle = 0 ∨ cycle = 1 := by omega
    have hg : gate = 0 ∨ gate = 1 ∨ gate = 2 ∨ gate = 3 := by omega
    rcases hc with rfl | rfl
    · rcases hg with rfl | rfl | rfl | rfl <;> simp
    · rcases hg with rfl | rfl | rfl | rfl
      · simp
      · simp
      · simp
        exact ⟨⟨1, by omega, 0, by omega, rfl, rfl⟩,
          ⟨1, by omega, 1, by omega, rfl, rfl⟩⟩
      · simp
  · simp [memberNodes, nodes, transInputNodes, cycleMismatchDownGadget,
      cycleMismatchDownCircuit]
    intro cycle hcycle gate hgate
    have hc : cycle = 0 ∨ cycle = 1 := by omega
    have hg : gate = 0 ∨ gate = 1 ∨ gate = 2 ∨ gate = 3 := by omega
    rcases hc with rfl | rfl <;>
      rcases hg with rfl | rfl | rfl | rfl <;> simp

private theorem cycleMismatchUp_inputs_reached :
    ∀ x ∈ boolVectors (inputWidth cycleMismatchUpGadget),
      (envsForInput cycleMismatchUpGadget x).length > 0 := by
  intro x _
  apply List.length_pos_iff.mpr
  exact envsForInput_ne_nil_of_valid cycleMismatchUpGadget x
    (fixingForInput_valid cycleMismatchUpGadget x)

private theorem cycleMismatchDown_inputs_reached :
    ∀ x ∈ boolVectors (inputWidth cycleMismatchDownGadget),
      (envsForInput cycleMismatchDownGadget x).length > 0 := by
  intro x _
  apply List.length_pos_iff.mpr
  exact envsForInput_ne_nil_of_valid cycleMismatchDownGadget x
    (fixingForInput_valid cycleMismatchDownGadget x)

theorem cycleMismatchUp_opini :
    opiniSpec cycleMismatchUpGadget transitionGlitch 1 := by
  apply (opini_iff_spec cycleMismatchUpGadget transitionGlitch 1
    cycleMismatchUp_inputs_reached).mp
  exact ⟨cycleMismatchUp_wf, by decide⟩

theorem cycleMismatchDown_opini :
    opiniSpec cycleMismatchDownGadget transitionGlitch 1 := by
  apply (opini_iff_spec cycleMismatchDownGadget transitionGlitch 1
    cycleMismatchDown_inputs_reached).mp
  exact ⟨cycleMismatchDown_wf, by decide⟩

def cycleMismatchComposite : GadgetInstance :=
  glue cycleMismatchUp cycleMismatchDown 1 cycleMismatchCompatible

/-- The counterexample is not exploiting malformed compiled structure: the
rewritten whole circuit and its composite boundary satisfy the repository's
full gadget well-formedness predicate. -/
theorem cycleMismatchComposite_wf : cycleMismatchComposite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  change ({ gates := #[
    { kind := .inp 0 0, inputs := [] },
    { kind := .inp 1 0, inputs := [] },
    { kind := .inp 0 1, inputs := [] },
    { kind := .inp 1 1, inputs := [] },
    { kind := .const false, inputs := [] },
    { kind := .xor, inputs := [(0, 0), (2, 0)] },
    { kind := .const false, inputs := [] },
    { kind := .const false, inputs := [] }
  ] } : Circuit).WF
  simp [Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

private theorem cycleMismatch_connectedShare0 :
    connectedShareAt? cycleMismatchDownGadget 0 ⟨2, 0⟩ = some 0 := by
  rfl

private theorem cycleMismatch_connectedShare1 :
    connectedShareAt? cycleMismatchDownGadget 0 ⟨2, 1⟩ = some 1 := by
  rfl

/-- The requested scan finds both shares, but the rewritten XOR at cycle 1
reads the upstream gates at cycle 1, not the designated upstream output nodes
at cycle 0.  All facts are closed computations over the two-cycle circuit. -/
theorem cycleMismatch_rewrite_changes_the_connected_cycle :
    SerialComposable.InputShareConsumed cycleMismatchDownGadget 0 0 ∧
      SerialComposable.InputShareConsumed cycleMismatchDownGadget 0 1 ∧
      (cycleMismatchComposite.circuit.gates[5]?).map
          (fun gate => gate.inputs) = some [(0, 0), (2, 0)] ∧
      GenericSerial2.edgePredecessorAt 0 (0, 0) =
        some (namespaceNode false (cycleMismatchUpGadget.output 0)) ∧
      GenericSerial2.edgePredecessorAt 0 (2, 0) =
        some (namespaceNode false (cycleMismatchUpGadget.output 1)) ∧
      GenericSerial2.edgePredecessorAt 1 (0, 0) =
        some ({ gate := 0, cycle := 1 } : Node) ∧
      namespaceNode false (cycleMismatchUpGadget.output 0) =
        ({ gate := 0, cycle := 0 } : Node) := by
  refine ⟨?_, ?_, ?_, by decide, by decide, by decide, by decide⟩
  · change SerialComposable.consumingSites cycleMismatchDownGadget 0 0 ≠ []
    decide
  · change SerialComposable.consumingSites cycleMismatchDownGadget 0 1 ≠ []
    decide
  · rfl

private theorem cycleMismatchComposite_secrets_reached :
    ∀ secret ∈ boolVectors cycleMismatchComposite.inputCount,
      (envsForSecret cycleMismatchComposite secret).length > 0 := by
  intro secret hsecret
  have hcases : secret = [false, false] ∨ secret = [true, false] ∨
      secret = [false, true] ∨ secret = [true, true] := by
    simpa [cycleMismatchComposite, glue, cycleMismatchUp,
      cycleMismatchDown, cycleMismatchUpGadget, cycleMismatchDownGadget,
      boolVectors]
      using hsecret
  rcases hcases with rfl | rfl | rfl | rfl
  · apply List.length_pos_iff.mpr
    exact envsForSecret_ne_nil_of_input cycleMismatchComposite _
      ([false, false, false, false] : List Bool) (by decide) (by decide)
      (envsForInput_ne_nil_of_valid cycleMismatchComposite _
        (fixingForInput_valid cycleMismatchComposite _))
  · apply List.length_pos_iff.mpr
    exact envsForSecret_ne_nil_of_input cycleMismatchComposite _
      ([true, false, false, false] : List Bool) (by decide) (by decide)
      (envsForInput_ne_nil_of_valid cycleMismatchComposite _
        (fixingForInput_valid cycleMismatchComposite _))
  · apply List.length_pos_iff.mpr
    exact envsForSecret_ne_nil_of_input cycleMismatchComposite _
      ([false, false, true, false] : List Bool) (by decide) (by decide)
      (envsForInput_ne_nil_of_valid cycleMismatchComposite _
        (fixingForInput_valid cycleMismatchComposite _))
  · apply List.length_pos_iff.mpr
    exact envsForSecret_ne_nil_of_input cycleMismatchComposite _
      ([true, false, true, false] : List Bool) (by decide) (by decide)
      (envsForInput_ne_nil_of_valid cycleMismatchComposite _
        (fixingForInput_valid cycleMismatchComposite _))

/-- Both components are order-one O-PINI, the selected input is consumed for
both shares, namespace freshness is by construction, and `1 < d`.  Still, the
static rewrite turns one downstream probe into the XOR of both shares of the
upstream component's cycle-1 input sharing.  The resulting glued gadget is
therefore not probing secure. -/
theorem cycleMismatchComposite_not_probing :
    ¬ probingSecureSpec cycleMismatchComposite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure cycleMismatchComposite transitionGlitch 1 :=
    (probingSecure_iff_spec cycleMismatchComposite transitionGlitch 1
      cycleMismatchComposite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast cycleMismatchComposite transitionGlitch 1 :=
    (probingSecureFast_iff cycleMismatchComposite transitionGlitch 1
      cycleMismatchComposite_secrets_reached).mpr hexecutable
  exact (by decide :
    ¬ probingSecureFast cycleMismatchComposite transitionGlitch 1) hfast

/-- Closed counterexample to the proposed universal theorem with exactly its
two O-PINI premises and refined compatibility record. -/
theorem universal_opini_glue_counterexample :
    ∃ (up down : SerialComposable)
      (compat : SerialComposable.Compatible up down 1),
      opiniSpec up.gadget transitionGlitch 1 ∧
      opiniSpec down.gadget transitionGlitch 1 ∧
      (glue up down 1 compat).WF ∧
      ¬ probingSecureSpec (glue up down 1 compat) transitionGlitch 1 := by
  exact ⟨cycleMismatchUp, cycleMismatchDown, cycleMismatchCompatible,
    cycleMismatchUp_opini, cycleMismatchDown_opini,
    cycleMismatchComposite_wf,
    cycleMismatchComposite_not_probing⟩

end Universal
end Composition
end LeanSec

#print axioms LeanSec.Composition.Universal.namespaceSrc_left_ne_right
#print axioms LeanSec.Composition.Universal.namespacedSources_disjoint
#print axioms LeanSec.Composition.Universal.namespacedInputs_randomness_disjoint
#print axioms LeanSec.Composition.Universal.concrete_component_opini
#print axioms LeanSec.Composition.Universal.cycleMismatch_rewrite_changes_the_connected_cycle
#print axioms LeanSec.Composition.Universal.cycleMismatchUp_opini
#print axioms LeanSec.Composition.Universal.cycleMismatchDown_opini
#print axioms LeanSec.Composition.Universal.cycleMismatchComposite_wf
#print axioms LeanSec.Composition.Universal.cycleMismatchComposite_not_probing
#print axioms LeanSec.Composition.Universal.universal_opini_glue_counterexample
