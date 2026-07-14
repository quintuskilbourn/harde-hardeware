import LeanSec.Composition.UniversalReg

namespace LeanSec
namespace Composition

open Gadget
open UniversalReg

/-! # Closed registered pipelines

This module packages the component-local hypotheses needed by registered
serial composition.  `PipelineGadget` carries the downstream-role PINI
certificate; an upstream O-PINI certificate is supplied only when a new leaf
is prepended.
-/

/-- All declared input-arrival atoms of a gadget. -/
def interfaceAtoms (g : GadgetInstance) : List Src :=
  (List.range g.inputCount).flatMap fun input =>
    (List.range g.d).map fun share => g.inputArrival input share

/-- The public-fixing domain, with values forgotten. -/
def publicAtoms (g : GadgetInstance) : List Src :=
  g.publicFixing.map Prod.fst

/-- The complete declared input interface is injective, including pairs from
the same input sharing. -/
def InterfaceInjective (g : GadgetInstance) : Prop :=
  (interfaceAtoms g).Nodup

instance (g : GadgetInstance) : Decidable (InterfaceInjective g) := by
  unfold InterfaceInjective
  infer_instance

private theorem nodup_map_injective_on [BEq β] [LawfulBEq β]
    (xs : List α) (f : α → β) (hn : (xs.map f).Nodup) :
    ∀ a ∈ xs, ∀ b ∈ xs, f a = f b → a = b := by
  induction xs with
  | nil => simp
  | cons head tail ih =>
      rw [List.map_cons, List.nodup_cons] at hn
      intro a ha b hb heq
      simp only [List.mem_cons] at ha hb
      rcases ha with rfl | ha <;> rcases hb with rfl | hb
      · rfl
      · exfalso
        exact hn.1 (List.mem_map.mpr ⟨b, hb, heq.symm⟩)
      · exfalso
        exact hn.1 (List.mem_map.mpr ⟨a, ha, heq⟩)
      · exact ih hn.2 a ha b hb heq

/-- Executable `Nodup` implies the bounded four-index formulation used when
transporting interface injectivity through the registered constructor. -/
theorem interfaceInjective_bounded (g : GadgetInstance)
    (hinj : InterfaceInjective g) :
    ∀ i, i < g.inputCount → ∀ j, j < g.d →
      ∀ i', i' < g.inputCount → ∀ j', j' < g.d →
        g.inputArrival i j = g.inputArrival i' j' → i = i' ∧ j = j' := by
  intro i hi j hj i' hi' j' hj' heq
  let pairs : List (Nat × Nat) :=
    (List.range g.inputCount).flatMap fun input =>
      (List.range g.d).map fun share => (input, share)
  have hpairsMap : pairs.map (fun pair => g.inputArrival pair.1 pair.2) =
      interfaceAtoms g := by
    simp [pairs, interfaceAtoms, List.map_flatMap, Function.comp_def]
  have hmapNodup :
      (pairs.map fun pair => g.inputArrival pair.1 pair.2).Nodup := by
    rw [hpairsMap]
    exact hinj
  have hleft : (i, j) ∈ pairs := by
    simp [pairs, hi, hj]
  have hright : (i', j') ∈ pairs := by
    simp [pairs, hi', hj']
  have hp := nodup_map_injective_on pairs
    (fun pair => g.inputArrival pair.1 pair.2) hmapNodup
    (i, j) hleft (i', j') hright heq
  exact ⟨congrArg Prod.fst hp, congrArg Prod.snd hp⟩

private theorem map_nodup_of_inj_on [BEq α] [LawfulBEq α]
    (xs : List α) (f : α → β) (hn : xs.Nodup)
    (hinj : ∀ a ∈ xs, ∀ b ∈ xs, f a = f b → a = b) :
    (xs.map f).Nodup := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
      rw [List.map_cons, List.nodup_cons]
      have hn' := List.nodup_cons.mp hn
      refine ⟨?_, ih hn'.2 ?_⟩
      · intro hmem
        rw [List.mem_map] at hmem
        rcases hmem with ⟨y, hy, heq⟩
        have hxy := hinj x (by simp) y (by simp [hy]) heq.symm
        exact hn'.1 (hxy ▸ hy)
      · intro a ha b hb heq
        exact hinj a (by simp [ha]) b (by simp [hb]) heq

private theorem interfaceRows_nodup_of_bounded (g : GadgetInstance)
    (inputs : List Nat) (hinputs : inputs.Nodup)
    (hbound : ∀ input ∈ inputs, input < g.inputCount)
    (hinj : ∀ i, i < g.inputCount → ∀ j, j < g.d →
      ∀ i', i' < g.inputCount → ∀ j', j' < g.d →
        g.inputArrival i j = g.inputArrival i' j' → i = i' ∧ j = j') :
    (inputs.flatMap fun input =>
      (List.range g.d).map fun share => g.inputArrival input share).Nodup := by
  induction inputs with
  | nil => simp
  | cons input inputs ih =>
      simp only [List.flatMap_cons, List.nodup_append]
      have hn := List.nodup_cons.mp hinputs
      refine ⟨?_, ih hn.2 (by
        intro other hother
        exact hbound other (by simp [hother])), ?_⟩
      · apply map_nodup_of_inj_on (List.range g.d)
          (fun share => g.inputArrival input share) List.nodup_range
        intro left hleft right hright heq
        exact (hinj input (hbound input (by simp)) left (by simpa using hleft)
          input (hbound input (by simp)) right (by simpa using hright) heq).2
      · intro atom hrow otherAtom hrest
        intro hatoms
        rw [List.mem_map] at hrow
        rcases hrow with ⟨share, hshare, hrow⟩
        rw [List.mem_flatMap] at hrest
        rcases hrest with ⟨other, hother, hotherRow⟩
        rw [List.mem_map] at hotherRow
        rcases hotherRow with ⟨otherShare, hotherShare, hotherRow⟩
        have heq : g.inputArrival input share =
            g.inputArrival other otherShare :=
          hrow.trans (hatoms.trans hotherRow.symm)
        have hsame := hinj input (hbound input (by simp)) share
          (by simpa using hshare) other (hbound other (by simp [hother]))
          otherShare (by simpa using hotherShare) heq
        exact hn.1 (hsame.1 ▸ hother)

theorem interfaceInjective_of_bounded (g : GadgetInstance)
    (hinj : ∀ i, i < g.inputCount → ∀ j, j < g.d →
      ∀ i', i' < g.inputCount → ∀ j', j' < g.d →
        g.inputArrival i j = g.inputArrival i' j' → i = i' ∧ j = j') :
    InterfaceInjective g := by
  unfold InterfaceInjective interfaceAtoms
  exact interfaceRows_nodup_of_bounded g (List.range g.inputCount)
    List.nodup_range (by simp) hinj

/-- Two finite source domains are disjoint.  The explicit bounded form keeps
the invariant executable without introducing set-valued interfaces. -/
def SourceDomainsDisjoint (left right : List Src) : Prop :=
  left.all (fun src => !right.contains src) = true

instance (left right : List Src) : Decidable (SourceDomainsDisjoint left right) := by
  unfold SourceDomainsDisjoint
  infer_instance

/-- Source-faithfulness for the four clauses of `fixingForInput`.

Declared arrivals and randomness are live.  The arrival, randomness, and
public domains are pairwise disjoint, so fixing precedence is vacuous on
those clauses.  Every relevant register-initialization atom is genuinely
public-pinned; all remaining relevant atoms belong to the default-false
clause of `fixingForInput`. -/
def SourcePartition (g : GadgetInstance) : Prop :=
  (interfaceAtoms g).all
      (Execution.relevantSrcs g.circuit g.horizon).contains = true ∧
    g.randomness.all
      (Execution.relevantSrcs g.circuit g.horizon).contains = true ∧
    SourceDomainsDisjoint (interfaceAtoms g) g.randomness ∧
    SourceDomainsDisjoint (interfaceAtoms g) (publicAtoms g) ∧
    SourceDomainsDisjoint g.randomness (publicAtoms g) ∧
    (Execution.relevantSrcs g.circuit g.horizon).all (fun src =>
      match src with
      | .iniReg gate => decide (SourcePinned g (.iniReg gate))
      | _ => true) = true

instance (g : GadgetInstance) : Decidable (SourcePartition g) := by
  unfold SourcePartition SourceDomainsDisjoint interfaceAtoms publicAtoms
  infer_instance

/-- Source atoms generated throughout the window by the input gates selected
as a tail's registered connection port. -/
def portInputAtoms {g : GadgetInstance} (ports : RegisterPorts g) : List Src :=
  (List.range g.d).flatMap fun share =>
    match g.circuit.gates[ports.inputGate share]? with
    | some { kind := .inp sharing lane, inputs := _ } =>
        (List.range g.horizon).map (.inp sharing lane)
    | _ => []

/-- The exact arrival atoms which the registered boundary is meant to replace. -/
def connectedArrivalAtoms {g : GadgetInstance}
    (ports : RegisterPorts g) : List Src :=
  (List.range g.d).map fun share =>
    g.inputArrival ports.downstreamInput share

/-- The selected port owns its complete input streams.

No second gate may produce the same `.inp` sharing/lane, and atoms from those
streams away from the declared connected arrival may not occur in any fixing
clause.  This is the component-local guard needed because the registered
compiler replaces a whole input gate while `Src` equality also contains the
cycle. -/
def PortSourceExclusive {g : GadgetInstance}
    (ports : RegisterPorts g) : Prop :=
  (publicAtoms g).all
      (Execution.relevantSrcs g.circuit g.horizon).contains = true ∧
  (List.range g.d).all (fun share =>
    (List.range g.circuit.gates.size).all fun gate =>
      match g.circuit.gates[ports.inputGate share]?,
          g.circuit.gates[gate]? with
      | some { kind := .inp sharing lane, inputs := _ },
          some { kind := .inp otherSharing otherLane, inputs := _ } =>
        !(sharing == otherSharing && lane == otherLane) ||
          gate == ports.inputGate share
      | _, _ => true) = true ∧
  SourceDomainsDisjoint
    ((portInputAtoms ports).filter fun src =>
      !(connectedArrivalAtoms ports).contains src)
    (interfaceAtoms g ++ g.randomness ++ publicAtoms g)

instance {g : GadgetInstance} (ports : RegisterPorts g) :
    Decidable (PortSourceExclusive ports) := by
  unfold PortSourceExclusive
  infer_instance

/-- The executable glitch recursion uses the gate-array size as fuel.  A
forward combinational layout gives that fuel a component-local rank meaning,
so inserting a prefix cannot change a copied component's frontier. -/
def ForwardCombinational (g : GadgetInstance) : Prop :=
  g.circuit.combEdges.all (fun edge => edge.1 < edge.2) = true

instance (g : GadgetInstance) : Decidable (ForwardCombinational g) := by
  unfold ForwardCombinational
  infer_instance

end Composition

namespace Gadget

/-- The current `GadgetInstance` format has the original, non-holding input
semantics.  This is its definitionally empty hold schedule. -/
def GadgetInstance.inputHold
    (_g : GadgetInstance) (_input _share : Nat) : List Src := []

end Gadget

namespace Composition

open Gadget
open UniversalReg

/-- A pipeline tail.  All shape parameters are shared definitionally between
components, and the carried security certificate is downstream-role PINI. -/
structure PipelineGadget (H d t : Nat) where
  g : GadgetInstance
  horizon_eq : g.horizon = H
  d_eq : g.d = d
  order_lt : t < d
  whole_window : WholeWindow g
  hold_empty : ∀ i, i < g.inputCount → ∀ j, j < g.d →
    g.inputHold i j = []
  ports : RegisterPorts g
  arrival_inside : ports.arrivalCycle < H
  interface_injective : InterfaceInjective g
  source_partition : SourcePartition g
  port_source_exclusive : PortSourceExclusive ports
  forward_combinational : ForwardCombinational g
  pinned_init : PinnedInit g
  outCycle : Nat
  output_at : ∀ j, j < d → (g.output j).cycle = outCycle
  output_inj : ∀ i j, i < d → j < d →
    g.output i = g.output j → i = j
  output_pulse : OutputPulse g
  down_cert : piniSpec g transitionGlitch t

/-- The only cross-component facts needed when prepending one pipeline leaf. -/
structure PortGlue {H d t : Nat}
    (up tail : PipelineGadget H d t) : Prop where
  cycle_align : up.outCycle + 1 = tail.ports.arrivalCycle
  fresh : FullSourceDisjointness up.g tail.g

/-- Repackage a certified leaf for downstream use.  The O-PINI certificate is
retained only at the call site; the pipeline invariant carries PINI. -/
def PipelineGadget.ofLeaf {H d t : Nat} (P : PipelineGadget H d t)
    (hleaf : opiniSpec P.g transitionGlitch t) : PipelineGadget H d t :=
  { P with down_cert := opini_implies_pini P.g transitionGlitch t hleaf }

/-- Every closed pipeline tail is probing secure directly from its carried
PINI certificate and structural output boundary. -/
theorem PipelineGadget.probing {H d t : Nat} (P : PipelineGadget H d t) :
    probingSecureSpec P.g transitionGlitch t := by
  apply pini_implies_probing P.g transitionGlitch t
  · simpa [P.d_eq] using P.order_lt
  · intro share hshare
    have hwf := P.down_cert.1
    simp_all [GadgetInstance.WF, outputNodes, memberNodes, nodes]
  · intro i j hi hj heq
    exact P.output_inj i j (by simpa [P.d_eq] using hi)
      (by simpa [P.d_eq] using hj) heq
  · intro x _
    exact List.length_pos_iff.mpr
      (envsForInput_ne_nil_of_valid P.g x (fixingForInput_valid P.g x))
  · exact P.down_cert

/-! ## Component evaluation inside a registered splice -/

/-- Restrict a total environment to one finite source support, using the
evaluator's standard false value elsewhere. -/
def restrictEnv (sources : List Src) (env : Env) : Env :=
  fun src => if sources.contains src then env src else false

theorem restrictEnv_agrees (sources : List Src) (env : Env) :
    UniversalSStage1.EnvAgreeOn sources env (restrictEnv sources env) := by
  intro src hsrc
  simp [restrictEnv, hsrc]

/-- E1: the embedded upstream prefix evaluates exactly as the isolated
upstream under restriction to its finite support. -/
theorem eval_restrict_upstream {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env) (node : Node)
    (hnode : node.gate < up.g.circuit.gates.size) :
    Execution.eval (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env node =
      Execution.eval up.g.circuit up.g.horizon
        (restrictEnv
          (Execution.relevantSrcs up.g.circuit up.g.horizon) env) node := by
  simpa [registeredComposite, registeredCompositeCircuit, up.horizon_eq,
      tail.horizon_eq] using
    (UniversalSStage1.eval_appendCircuit_prefix_of_envAgree up.g.circuit
      (boundaryRegisterGates up.g tail.g ++
        registeredDownGates (up := up.g) tail.ports)
      up.g.horizon env
      (restrictEnv (Execution.relevantSrcs up.g.circuit up.g.horizon) env)
      node up.down_cert.1.1 hnode
      (restrictEnv_agrees
        (Execution.relevantSrcs up.g.circuit up.g.horizon) env))

theorem pipeline_portAlignment {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail) :
    PortAlignment up.g tail.g tail.ports := by
  refine ⟨up.d_eq.trans tail.d_eq.symm, ?_, ?_⟩
  · simpa [up.horizon_eq] using tail.arrival_inside
  · intro share hshare
    have hshare' : share < d := by simpa [tail.d_eq] using hshare
    rw [up.output_at share hshare']
    exact glue.cycle_align

private theorem pipeline_output_gate_lt {H d t : Nat}
    (P : PipelineGadget H d t) (share : Nat) (hshare : share < d) :
    (P.g.output share).gate < P.g.circuit.gates.size := by
  have hwf := P.down_cert.1
  have hshare' : share < P.g.d := by simpa [P.d_eq] using hshare
  have hout : P.g.output share ∈ outputNodes P.g :=
    List.mem_map.mpr ⟨share, by simpa using hshare', rfl⟩
  have hcontains := List.all_eq_true.mp hwf.2.2.2.1 _ hout
  have hmember : P.g.output share ∈ memberNodes P.g := by
    simpa using hcontains
  have hnode := (List.mem_filter.mp hmember).1
  rw [nodes, List.mem_flatMap] at hnode
  rcases hnode with ⟨cycle, _hcycle, hgate⟩
  rw [List.mem_map] at hgate
  rcases hgate with ⟨gate, hgate, heq⟩
  simpa [← heq] using hgate

/-- E2 at the live boundary cycle, parameterized by the remaining P0 circuit
acyclicity proof.  Once P0 is closed this specializes without an extra
hypothesis. -/
theorem eval_boundary_register_of_wf {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (hwf : (registeredCompositeCircuit up.g tail.ports).WF)
    (env : Env) (share : Nat) (hshare : share < d) :
    Execution.eval (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env
        { gate := boundaryRegister up.g share,
          cycle := tail.ports.arrivalCycle } =
      Execution.eval up.g.circuit up.g.horizon
        (restrictEnv
          (Execution.relevantSrcs up.g.circuit up.g.horizon) env)
        (up.g.output share) := by
  have hshareTail : share < tail.g.d := by simpa [tail.d_eq] using hshare
  have hinside : tail.ports.arrivalCycle <
      max up.g.horizon tail.g.horizon := by
    simpa [up.horizon_eq, tail.horizon_eq] using tail.arrival_inside
  change Execution.eval (registeredCompositeCircuit up.g tail.ports)
      (max up.g.horizon tail.g.horizon) env
      { gate := boundaryRegister up.g share,
        cycle := tail.ports.arrivalCycle } = _
  rw [registeredComposite_boundary_value up.g tail.ports share hshareTail
      (pipeline_portAlignment up tail glue) hwf hinside env]
  apply eval_restrict_upstream up tail env (up.g.output share)
  exact pipeline_output_gate_lt up share hshare

/-- A simulator depending on a smaller projection remains a simulator after
revealing a larger projection. -/
theorem simulatableOn_proj_mono
    {xs : List (List Bool)} {envsOf : List Bool → List Env}
    {small large : List Bool → List Bool} {obs : Env → Observation}
    (hdet : ∀ x ∈ xs, ∀ y ∈ xs, large x = large y → small x = small y)
    (hsim : SimulatableOn xs envsOf small obs) :
    SimulatableOn xs envsOf large obs := by
  classical
  rcases hsim with ⟨S, hpositive, hcounts⟩
  let representative : List Bool → List Bool := fun q =>
    if h : ∃ x ∈ xs, large x = q then Classical.choose h else []
  let T : List Bool → List Observation := fun q =>
    S (small (representative q))
  have hrep (x : List Bool) (hx : x ∈ xs) :
      representative (large x) ∈ xs ∧
        large (representative (large x)) = large x := by
    have hex : ∃ y ∈ xs, large y = large x := ⟨x, hx, rfl⟩
    exact ⟨by simp [representative, hex, Classical.choose_spec hex],
      by simp [representative, hex, Classical.choose_spec hex]⟩
  refine ⟨T, ?_, ?_⟩
  · intro x hx
    have hr := hrep x hx
    have hsmall := hdet _ hr.1 x hx hr.2
    simpa [T, hsmall] using hpositive x hx
  · intro x hx w
    have hr := hrep x hx
    have hsmall := hdet _ hr.1 x hx hr.2
    simpa [T, hsmall] using hcounts x hx w

/-! ## Structural well-formedness of the registered compiler -/

private theorem wireRegisteredEdge_snd {up down : GadgetInstance}
    (ports : RegisterPorts down) (edge : Nat × Nat) :
    (wireRegisteredEdge (up := up) ports edge).2 = edge.2 := by
  simp [wireRegisteredEdge]
  split <;> rfl

private def wireRegisteredGateInputs {up down : GadgetInstance}
    (ports : RegisterPorts down) (gate : Gate) : Gate :=
  { gate with inputs := gate.inputs.map fun edge =>
      wireRegisteredEdge (up := up) ports edge }

private theorem gateArityOk_wireRegistered {up down : GadgetInstance}
    (ports : RegisterPorts down) (gate : Gate) :
    Circuit.gateArityOk (wireRegisteredGateInputs (up := up) ports gate) =
      Circuit.gateArityOk gate := by
  cases gate with
  | mk kind inputs =>
      have hall (latency : Nat) :
          inputs.all ((fun edge => edge.2 == latency) ∘
              fun edge => wireRegisteredEdge (up := up) ports edge) =
            inputs.all (fun edge => edge.2 == latency) := by
        apply List.all_congr
        · rfl
        intro edge
        simp [wireRegisteredEdge_snd]
      cases kind <;> simp [wireRegisteredGateInputs, Circuit.gateArityOk,
        hall]

/-- The compiler preserves gate arities and keeps every rewritten edge inside
the concatenated gate array. -/
theorem registeredComposite_indicesOk {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    (registeredCompositeCircuit up.g tail.ports).indicesOk = true := by
  have hup := up.down_cert.1.1.1
  have htail := tail.down_cert.1.1.1
  unfold registeredCompositeCircuit UniversalSStage1.appendCircuit
  simp only [Circuit.indicesOk, Array.all_append, Bool.and_eq_true]
  constructor
  · apply Array.all_eq_true.mpr
    intro gate hgate
    have hold := Array.all_eq_true.mp hup gate hgate
    simp only [Bool.and_eq_true] at hold ⊢
    exact ⟨hold.1, List.all_eq_true.mpr fun edge hedge => by
      have hedgeLt : edge.1 < up.g.circuit.gates.size := by
        simpa using (List.all_eq_true.mp hold.2 edge hedge)
      simp [boundaryRegisterGates, registeredDownGates]
      omega⟩
  · constructor
    · apply Array.all_eq_true.mpr
      intro share hshare
      simp [boundaryRegisterGates] at hshare
      simp [boundaryRegisterGates, hshare, Circuit.gateArityOk]
      have hshare' : share < d := by simpa [tail.d_eq] using hshare
      have hout := pipeline_output_gate_lt up share hshare'
      simp [boundaryRegisterGates, registeredDownGates]
      omega
    · apply Array.all_eq_true.mpr
      intro gate hgate
      have hgateTail : gate < tail.g.circuit.gates.size := by
        simpa [registeredDownGates] using hgate
      simp only [registeredDownGates, Array.getElem_mapIdx, hgate,
        wireRegisteredDownGate]
      split
      · simp [Circuit.gateArityOk]
      · rename_i hconnected
        have hold := Array.all_eq_true.mp htail gate hgateTail
        simp only [Bool.and_eq_true] at hold ⊢
        constructor
        · change Circuit.gateArityOk
              (wireRegisteredGateInputs (up := up.g) tail.ports
                tail.g.circuit.gates[gate]) = true
          rw [gateArityOk_wireRegistered]
          exact hold.1
        · apply List.all_eq_true.mpr
          intro rewritten hrewritten
          rw [List.mem_map] at hrewritten
          rcases hrewritten with ⟨edge, hedge, rfl⟩
          have hedgeBound := List.all_eq_true.mp hold.2 edge hedge
          cases hconn : connectedShare? tail.ports edge.fst with
          | some share =>
            have hshareMem : share ∈ List.range tail.g.d := by
              unfold connectedShare? at hconn
              exact List.mem_of_find?_eq_some hconn
            have hshareBound : share < tail.g.d := by
              simpa using (List.mem_range.mp hshareMem)
            simp [wireRegisteredEdge, hconn, boundaryRegister,
              downstreamOffset, boundaryRegisterGates, registeredDownGates]
            omega
          | none =>
            have hedgeLt : edge.1 < tail.g.circuit.gates.size := by
              simpa using hedgeBound
            simp [wireRegisteredEdge, hconn, downstreamOffset,
              boundaryRegisterGates, registeredDownGates]
            omega


def embeddedTailGate {down : GadgetInstance} (up : GadgetInstance)
    (ports : RegisterPorts down) (gate : Nat) : Nat :=
  match connectedShare? ports gate with
  | some share => boundaryRegister up share
  | none => downstreamOffset up down + gate

theorem embeddedTailGate_eq_wire_fst {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down)
    (source latency : Nat) :
    embeddedTailGate up ports source =
      (wireRegisteredEdge (up := up) ports (source, latency)).1 := by
  unfold embeddedTailGate wireRegisteredEdge
  cases connectedShare? ports source <;> rfl

theorem embeddedTailGate_injective_on {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down)
    {left right : Nat} (hleft : left < down.circuit.gates.size)
    (hright : right < down.circuit.gates.size)
    (heq : embeddedTailGate up ports left =
      embeddedTailGate up ports right) : left = right := by
  cases hl : connectedShare? ports left with
  | none =>
      cases hr : connectedShare? ports right with
      | none =>
          simp [embeddedTailGate, hl, hr, downstreamOffset] at heq
          omega
      | some rshare =>
          have hrmem := List.mem_of_find?_eq_some hr
          have hrshare : rshare < down.d := by
            simpa [connectedShare?] using hrmem
          simp [embeddedTailGate, hl, hr, boundaryRegister,
            downstreamOffset] at heq
          omega
  | some lshare =>
      have hlmem := List.mem_of_find?_eq_some hl
      have hlshare : lshare < down.d := by
        simpa [connectedShare?] using hlmem
      have hlGate : ports.inputGate lshare = left := by
        have := List.find?_some hl
        simpa [connectedShare?] using this
      cases hr : connectedShare? ports right with
      | none =>
          simp [embeddedTailGate, hl, hr, boundaryRegister,
            downstreamOffset] at heq
          omega
      | some rshare =>
          have hrmem := List.mem_of_find?_eq_some hr
          have hrshare : rshare < down.d := by
            simpa [connectedShare?] using hrmem
          have hrGate : ports.inputGate rshare = right := by
            have := List.find?_some hr
            simpa [connectedShare?] using this
          simp [embeddedTailGate, hl, hr, boundaryRegister] at heq
          have hshares : lshare = rshare := by omega
          rw [← hlGate, ← hrGate, hshares]

private theorem embeddedTailGate_injective {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down) :
    Function.Injective (embeddedTailGate up ports) := by
  intro left right heq
  cases hl : connectedShare? ports left with
  | none =>
      cases hr : connectedShare? ports right with
      | none =>
          simp [embeddedTailGate, hl, hr, downstreamOffset] at heq
          omega
      | some rshare =>
          have hrmem := List.mem_of_find?_eq_some hr
          have hrshare : rshare < down.d := by
            simpa [connectedShare?] using hrmem
          simp [embeddedTailGate, hl, hr, boundaryRegister,
            downstreamOffset] at heq
          omega
  | some lshare =>
      have hlmem := List.mem_of_find?_eq_some hl
      have hlshare : lshare < down.d := by
        simpa [connectedShare?] using hlmem
      have hlGate : ports.inputGate lshare = left := by
        have := List.find?_some hl
        simpa [connectedShare?] using this
      cases hr : connectedShare? ports right with
      | none =>
          simp [embeddedTailGate, hl, hr, boundaryRegister,
            downstreamOffset] at heq
          omega
      | some rshare =>
          have hrmem := List.mem_of_find?_eq_some hr
          have hrshare : rshare < down.d := by
            simpa [connectedShare?] using hrmem
          have hrGate : ports.inputGate rshare = right := by
            have := List.find?_some hr
            simpa [connectedShare?] using this
          simp [embeddedTailGate, hl, hr, boundaryRegister] at heq
          have hshares : lshare = rshare := by omega
          rw [← hlGate, ← hrGate, hshares]

theorem pipeline_registeredComposite_combEdges_mem {H d t : Nat}
    (up tail : PipelineGadget H d t) (edge : Nat × Nat) :
    edge ∈ (registeredCompositeCircuit up.g tail.ports).combEdges ↔
      edge ∈ up.g.circuit.combEdges ∨
        ∃ downEdge ∈ tail.g.circuit.combEdges,
          edge = (embeddedTailGate up.g tail.ports downEdge.1,
            downstreamOffset up.g tail.g + downEdge.2) := by
  rw [UniversalSStage1.mem_combEdges_iff]
  constructor
  · rintro ⟨entry, hentry, input, hinput, hlatency, hsource⟩
    by_cases hprefix : edge.2 < up.g.circuit.gates.size
    · left
      rw [UniversalSStage1.mem_combEdges_iff]
      refine ⟨entry, ?_, input, hinput, hlatency, hsource⟩
      rw [← Array.getElem?_append_left (ys := boundaryRegisterGates up.g tail.g ++
        registeredDownGates (up := up.g) tail.ports) hprefix]
      simpa [registeredCompositeCircuit, UniversalSStage1.appendCircuit] using hentry
    · right
      have hbound := (Array.getElem?_eq_some_iff.mp hentry).choose
      have hoffset : downstreamOffset up.g tail.g ≤ edge.2 := by
        by_cases hoff : downstreamOffset up.g tail.g ≤ edge.2
        · exact hoff
        · have hregister : edge.2 - up.g.circuit.gates.size < tail.g.d := by
            simp [downstreamOffset] at hoff
            omega
          have happend := Array.getElem?_append_right
            (xs := up.g.circuit.gates)
            (ys := boundaryRegisterGates up.g tail.g ++
              registeredDownGates (up := up.g) tail.ports)
            (i := edge.2) (by omega)
          have hboundary := Array.getElem?_append_left
            (xs := boundaryRegisterGates up.g tail.g)
            (ys := registeredDownGates (up := up.g) tail.ports)
            (by simpa [boundaryRegisterGates] using hregister)
          rw [registeredCompositeCircuit, UniversalSStage1.appendCircuit,
            happend, hboundary] at hentry
          simp [boundaryRegisterGates] at hentry
          rcases hentry with ⟨share, _hshare, rfl⟩
          simp at hinput
          subst input
          simp at hlatency
      let gate := edge.2 - downstreamOffset up.g tail.g
      have hdest : edge.2 = downstreamOffset up.g tail.g + gate := by
        dsimp [gate]
        omega
      have hgate : gate < tail.g.circuit.gates.size := by
        dsimp [gate]
        have hsize :
            (registeredCompositeCircuit up.g tail.ports).gates.size =
              downstreamOffset up.g tail.g + tail.g.circuit.gates.size := by
          simp [registeredCompositeCircuit, UniversalSStage1.appendCircuit,
            boundaryRegisterGates, registeredDownGates, downstreamOffset,
            Nat.add_assoc]
        rw [hsize] at hbound
        omega
      have hfirst : edge.2 - up.g.circuit.gates.size = tail.g.d + gate := by
        rw [hdest]
        simp [downstreamOffset, Nat.add_assoc]
      have happend := Array.getElem?_append_right
        (xs := up.g.circuit.gates)
        (ys := boundaryRegisterGates up.g tail.g ++
          registeredDownGates (up := up.g) tail.ports)
        (i := edge.2) (by omega)
      have hdown := Array.getElem?_append_right
        (xs := boundaryRegisterGates up.g tail.g)
        (ys := registeredDownGates (up := up.g) tail.ports)
        (i := edge.2 - up.g.circuit.gates.size) (by
          simp [boundaryRegisterGates, hfirst])
      have hboundarySize :
          (boundaryRegisterGates up.g tail.g).size = tail.g.d := by
        simp [boundaryRegisterGates]
      rw [registeredCompositeCircuit, UniversalSStage1.appendCircuit,
        happend, hdown, hfirst, hboundarySize] at hentry
      simp only [Nat.add_sub_cancel_left, registeredDownGates,
        Array.getElem?_mapIdx] at hentry
      cases htailEntry : tail.g.circuit.gates[gate]? with
      | none => simp [htailEntry] at hentry
      | some downEntry =>
        simp only [htailEntry, Option.map_some] at hentry
        cases hconn : connectedShare? tail.ports gate with
        | some share =>
          simp [wireRegisteredDownGate, hconn] at hentry
          subst entry
          simp at hinput
        | none =>
          simp [wireRegisteredDownGate, hconn] at hentry
          subst entry
          rw [List.mem_map] at hinput
          rcases hinput with ⟨downInput, hdownInput, rfl⟩
          refine ⟨(downInput.1, gate), ?_, ?_⟩
          · rw [UniversalSStage1.mem_combEdges_iff]
            exact ⟨downEntry, htailEntry, downInput, hdownInput,
              by
                simp only [wireRegisteredEdge] at hlatency
                split at hlatency <;> exact hlatency,
              rfl⟩
          · apply Prod.ext
            · simp only [Prod.fst]
              rw [embeddedTailGate_eq_wire_fst up.g tail.ports]
              exact hsource.symm
            · exact hdest
  · rintro (hup | ⟨downEdge, hdownEdge, rfl⟩)
    ·
      rw [UniversalSStage1.mem_combEdges_iff] at hup
      rcases hup with ⟨entry, hentry, input, hinput, hlatency, hsource⟩
      refine ⟨entry, ?_, input, hinput, hlatency, hsource⟩
      rw [registeredCompositeCircuit, UniversalSStage1.appendCircuit,
        Array.getElem?_append_left]
      · exact hentry
      · exact (Array.getElem?_eq_some_iff.mp hentry).choose
    ·
      rw [UniversalSStage1.mem_combEdges_iff] at hdownEdge
      rcases hdownEdge with
        ⟨entry, hentry, input, hinput, hlatency, hsource⟩
      have hdstBound := (Array.getElem?_eq_some_iff.mp hentry).choose
      have hconnNone : connectedShare? tail.ports downEdge.2 = none := by
        cases hconn : connectedShare? tail.ports downEdge.2 with
        | none => rfl
        | some share =>
          have hshareMem := List.mem_of_find?_eq_some hconn
          have hshare : share < tail.g.d := by
            simpa [connectedShare?] using hshareMem
          have hgateEq : tail.ports.inputGate share = downEdge.2 := by
            have := List.find?_some hconn
            simpa [connectedShare?] using this
          obtain ⟨sharing, hportGate, _⟩ :=
            tail.ports.input_source_coherent share hshare
          rw [hgateEq, hentry] at hportGate
          cases hportGate
          simp at hinput
      refine ⟨{ entry with inputs := entry.inputs.map fun edge =>
          wireRegisteredEdge (up := up.g) tail.ports edge }, ?_,
        wireRegisteredEdge (up := up.g) tail.ports input, ?_, ?_, ?_⟩
      · rw [registeredCompositeCircuit, UniversalSStage1.appendCircuit,
          Array.getElem?_append_right]
        · have hsecond :
              downstreamOffset up.g tail.g + downEdge.2 -
                  up.g.circuit.gates.size = tail.g.d + downEdge.2 := by
              simp [downstreamOffset, Nat.add_assoc]
          rw [hsecond, Array.getElem?_append_right]
          · simp [boundaryRegisterGates, registeredDownGates,
              Array.getElem?_mapIdx, hentry, wireRegisteredDownGate,
              hconnNone]
          · simp [boundaryRegisterGates]
        · unfold downstreamOffset
          omega
      · exact List.mem_map.mpr ⟨input, hinput, rfl⟩
      · simp only [wireRegisteredEdge]
        split <;> exact hlatency
      · change (wireRegisteredEdge tail.ports input).1 =
          embeddedTailGate up.g tail.ports downEdge.1
        cases input with
        | mk source latency =>
            simp only [Prod.fst] at hsource ⊢
            subst source
            exact (embeddedTailGate_eq_wire_fst up.g tail.ports _ _).symm

theorem pipeline_combEdge_bounds (c : Circuit) (hwf : c.WF)
    (edge : Nat × Nat) (hedge : edge ∈ c.combEdges) :
    edge.1 < c.gates.size ∧ edge.2 < c.gates.size := by
  rw [UniversalSStage1.mem_combEdges_iff] at hedge
  rcases hedge with ⟨entry, hentry, input, hinput, _hlatency, hsource⟩
  have hdst := (Array.getElem?_eq_some_iff.mp hentry).choose
  have hinputs := UniversalSStage1.inputsBelow_of_indicesOk c hwf.1
  exact ⟨hsource ▸ hinputs edge.2 hdst entry hentry input hinput, hdst⟩

theorem pipeline_connectedShare_none_of_combEdge_dst {H d t : Nat}
    (tail : PipelineGadget H d t) (edge : Nat × Nat)
    (hedge : edge ∈ tail.g.circuit.combEdges) :
    connectedShare? tail.ports edge.2 = none := by
  rw [UniversalSStage1.mem_combEdges_iff] at hedge
  rcases hedge with ⟨entry, hentry, input, hinput, _hlatency, _hsource⟩
  cases hconn : connectedShare? tail.ports edge.2 with
  | none => rfl
  | some share =>
      have hshareMem := List.mem_of_find?_eq_some hconn
      have hshare : share < tail.g.d := by
        simpa [connectedShare?] using hshareMem
      have hgateEq : tail.ports.inputGate share = edge.2 := by
        have := List.find?_some hconn
        simpa [connectedShare?] using this
      obtain ⟨sharing, hportGate, _⟩ :=
        tail.ports.input_source_coherent share hshare
      rw [hgateEq, hentry] at hportGate
      cases hportGate
      simp at hinput

def testPullRemaining {down : GadgetInstance} (up : GadgetInstance)
    (ports : RegisterPorts down) (remaining : List Nat) : List Nat :=
  (List.range down.circuit.gates.size).filter fun gate =>
    remaining.contains (embeddedTailGate up ports gate)

theorem pipeline_embed_ge_up {down : GadgetInstance} (up : GadgetInstance)
    (ports : RegisterPorts down) (gate : Nat) :
    up.circuit.gates.size ≤ embeddedTailGate up ports gate := by
  unfold embeddedTailGate boundaryRegister downstreamOffset
  split <;> omega

theorem pipeline_hasRemainingPred_tail {H d t : Nat}
    (up tail : PipelineGadget H d t) (remaining : List Nat)
    (dst : Nat) (hdst : dst < tail.g.circuit.gates.size) :
    Circuit.hasRemainingPred
        (registeredCompositeCircuit up.g tail.ports).combEdges remaining
        (embeddedTailGate up.g tail.ports dst) =
      Circuit.hasRemainingPred tail.g.circuit.combEdges
        (testPullRemaining up.g tail.ports remaining) dst := by
  rw [Bool.eq_iff_iff]
  simp only [Circuit.hasRemainingPred, List.any_eq_true,
    Bool.and_eq_true, List.contains_iff_mem, beq_iff_eq]
  constructor
  · rintro ⟨edge, hedge, hsource, htarget⟩
    rw [pipeline_registeredComposite_combEdges_mem up tail edge] at hedge
    rcases hedge with hupEdge | ⟨downEdge, hdownEdge, hedgeEq⟩
    · have hbounds := pipeline_combEdge_bounds up.g.circuit up.down_cert.1.1
          edge hupEdge
      have hge := pipeline_embed_ge_up up.g tail.ports dst
      omega
    · subst edge
      have hdstNone := pipeline_connectedShare_none_of_combEdge_dst tail downEdge
        hdownEdge
      have hdownBounds := pipeline_combEdge_bounds tail.g.circuit
        tail.down_cert.1.1 downEdge hdownEdge
      have hdstEmbed :
          embeddedTailGate up.g tail.ports downEdge.2 =
            downstreamOffset up.g tail.g + downEdge.2 := by
        simp [embeddedTailGate, hdstNone]
      have htarget' :
          embeddedTailGate up.g tail.ports downEdge.2 =
            embeddedTailGate up.g tail.ports dst := by
        simpa [hdstEmbed] using htarget
      have hdstEq : downEdge.2 = dst :=
        embeddedTailGate_injective_on up.g tail.ports hdownBounds.2 hdst htarget'
      subst dst
      refine ⟨downEdge, hdownEdge, ?_, rfl⟩
      simp [testPullRemaining, hdownBounds.1, hsource]
  · rintro ⟨downEdge, hdownEdge, hsource, htarget⟩
    have hdownBounds := pipeline_combEdge_bounds tail.g.circuit
      tail.down_cert.1.1 downEdge hdownEdge
    have hdstEq : downEdge.2 = dst := htarget
    subst dst
    have hdstNone := pipeline_connectedShare_none_of_combEdge_dst tail downEdge
      hdownEdge
    let edge := (embeddedTailGate up.g tail.ports downEdge.1,
      downstreamOffset up.g tail.g + downEdge.2)
    refine ⟨edge, ?_, ?_, ?_⟩
    · rw [pipeline_registeredComposite_combEdges_mem up tail edge]
      exact Or.inr ⟨downEdge, hdownEdge, rfl⟩
    · simpa [testPullRemaining, hdownBounds.1] using hsource
    · simp [edge, embeddedTailGate, hdstNone]

theorem pipeline_pull_kahnStep {H d t : Nat}
    (up tail : PipelineGadget H d t) (remaining : List Nat) :
    testPullRemaining up.g tail.ports
        (Circuit.kahnStep
          (registeredCompositeCircuit up.g tail.ports).combEdges remaining) =
      Circuit.kahnStep tail.g.circuit.combEdges
        (testPullRemaining up.g tail.ports remaining) := by
  unfold testPullRemaining Circuit.kahnStep
  rw [List.filter_filter]
  apply List.filter_congr
  intro gate hgate
  have hgateBound : gate < tail.g.circuit.gates.size := by
    simpa using hgate
  rw [Bool.and_comm]
  -- membership in the canonical pullback is the corresponding mapped member
  rw [Bool.eq_iff_iff]
  simp only [List.contains_iff_mem, List.mem_filter, Bool.and_eq_true]
  rw [pipeline_hasRemainingPred_tail up tail remaining gate hgateBound]
  rfl

/-- Pulling one emitted Kahn layer back through the registered tail embedding
gives exactly the corresponding isolated-tail layer.  Unlike `kahnStep`,
`ready` retains the vertices whose predecessor test is false. -/
theorem pipeline_pull_ready {H d t : Nat}
    (up tail : PipelineGadget H d t) (remaining : List Nat) :
    testPullRemaining up.g tail.ports
        (Execution.ready
          (registeredCompositeCircuit up.g tail.ports).combEdges remaining) =
      Execution.ready tail.g.circuit.combEdges
        (testPullRemaining up.g tail.ports remaining) := by
  unfold testPullRemaining Execution.ready
  rw [List.filter_filter]
  apply List.filter_congr
  intro gate hgate
  have hgateBound : gate < tail.g.circuit.gates.size := by
    simpa using hgate
  rw [Bool.and_comm]
  rw [Bool.eq_iff_iff]
  simp only [List.contains_iff_mem, List.mem_filter, Bool.and_eq_true]
  rw [pipeline_hasRemainingPred_tail up tail remaining gate hgateBound]
  rfl

theorem pipeline_pull_kahnLoop {H d t : Nat}
    (up tail : PipelineGadget H d t) (fuel : Nat)
    (remaining : List Nat) :
    testPullRemaining up.g tail.ports
        (Circuit.kahnLoop
          (registeredCompositeCircuit up.g tail.ports).combEdges
          fuel remaining) =
      Circuit.kahnLoop tail.g.circuit.combEdges fuel
        (testPullRemaining up.g tail.ports remaining) := by
  induction fuel generalizing remaining with
  | zero => rfl
  | succ fuel ih =>
      simp only [Circuit.kahnLoop]
      rw [ih]
      rw [pipeline_pull_kahnStep up tail]

theorem pipeline_pull_range {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    testPullRemaining up.g tail.ports
        (List.range (registeredCompositeCircuit up.g tail.ports).gates.size) =
      List.range tail.g.circuit.gates.size := by
  apply List.filter_eq_self.mpr
  intro gate hgate
  have hgateBound : gate < tail.g.circuit.gates.size := by
    simpa using hgate
  simp only [List.contains_iff_mem, List.mem_range]
  simp [registeredCompositeCircuit, UniversalSStage1.appendCircuit,
    boundaryRegisterGates, registeredDownGates, embeddedTailGate]
  cases hconn : connectedShare? tail.ports gate with
  | none =>
      simp [hconn, downstreamOffset]
      omega
  | some share =>
      have hshareMem := List.mem_of_find?_eq_some hconn
      have hshare : share < tail.g.d := by
        simpa [connectedShare?] using hshareMem
      simp [hconn, boundaryRegister]
      omega

theorem pipeline_filter_kahnStep (bound : Nat)
    (subEdges compositeEdges : List (Nat × Nat))
    (remaining : List Nat)
    (hpred : UniversalSStage1.PredicatesAgreeBelow bound subEdges
      compositeEdges) :
    (Circuit.kahnStep compositeEdges remaining).filter
        (fun gate => gate < bound) =
      Circuit.kahnStep subEdges
        (remaining.filter fun gate => gate < bound) := by
  unfold Circuit.kahnStep
  simp only [List.filter_filter]
  apply List.filter_congr
  intro gate hgateMem
  by_cases hgate : gate < bound
  · rw [hpred remaining gate hgate]
    simp [hgate, Bool.and_comm]
  · simp [hgate]

theorem pipeline_filter_kahnLoop (bound : Nat)
    (subEdges compositeEdges : List (Nat × Nat))
    (fuel : Nat) (remaining : List Nat)
    (hpred : UniversalSStage1.PredicatesAgreeBelow bound subEdges
      compositeEdges) :
    (Circuit.kahnLoop compositeEdges fuel remaining).filter
        (fun gate => gate < bound) =
      Circuit.kahnLoop subEdges fuel
        (remaining.filter fun gate => gate < bound) := by
  induction fuel generalizing remaining with
  | zero => rfl
  | succ fuel ih =>
      simp only [Circuit.kahnLoop]
      rw [ih]
      rw [pipeline_filter_kahnStep bound subEdges compositeEdges remaining hpred]

theorem pipeline_prefix_kahnLoop {H d t : Nat}
    (up tail : PipelineGadget H d t) (fuel : Nat) :
    (Circuit.kahnLoop
        (registeredCompositeCircuit up.g tail.ports).combEdges fuel
        (List.range (registeredCompositeCircuit up.g tail.ports).gates.size)).filter
        (fun gate => gate < up.g.circuit.gates.size) =
      Circuit.kahnLoop up.g.circuit.combEdges fuel
        (List.range up.g.circuit.gates.size) := by
  have hedges := UniversalSStage1.appendCircuit_edgesAgreeBelow up.g.circuit
    (boundaryRegisterGates up.g tail.g ++
      registeredDownGates (up := up.g) tail.ports) up.down_cert.1.1.1
  have hpred := UniversalSStage1.predicatesAgreeBelow_of_edgesAgreeBelow
    up.g.circuit.gates.size up.g.circuit.combEdges
    (registeredCompositeCircuit up.g tail.ports).combEdges (by
      simpa [registeredCompositeCircuit] using hedges)
  rw [pipeline_filter_kahnLoop up.g.circuit.gates.size
    up.g.circuit.combEdges
    (registeredCompositeCircuit up.g tail.ports).combEdges fuel _ hpred]
  have hsize :
      (registeredCompositeCircuit up.g tail.ports).gates.size =
        up.g.circuit.gates.size +
          (boundaryRegisterGates up.g tail.g ++
            registeredDownGates (up := up.g) tail.ports).size := by
    simp [registeredCompositeCircuit, UniversalSStage1.appendCircuit]
  rw [hsize]
  rw [UniversalSStage1.range_add_filter_lt]

theorem pipeline_mem_kahnLoop_of_mem (edges : List (Nat × Nat))
    (fuel : Nat) (remaining : List Nat) (gate : Nat)
    (hmem : gate ∈ Circuit.kahnLoop edges fuel remaining) :
    gate ∈ remaining := by
  induction fuel generalizing remaining with
  | zero => exact hmem
  | succ fuel ih =>
      simp only [Circuit.kahnLoop] at hmem
      exact (List.mem_filter.mp (ih _ hmem)).1

theorem pipeline_kahnLoop_add (edges : List (Nat × Nat))
    (first second : Nat) (remaining : List Nat) :
    Circuit.kahnLoop edges (first + second) remaining =
      Circuit.kahnLoop edges second
        (Circuit.kahnLoop edges first remaining) := by
  induction first generalizing remaining with
  | zero => simp [Circuit.kahnLoop]
  | succ first ih =>
      simp only [Nat.succ_add, Circuit.kahnLoop]
      exact ih _

theorem pipeline_kahnLoop_empty (edges : List (Nat × Nat)) (fuel : Nat) :
    Circuit.kahnLoop edges fuel [] = [] := by
  induction fuel with
  | zero => rfl
  | succ fuel ih => simpa [Circuit.kahnLoop, Circuit.kahnStep] using ih

theorem pipeline_kahnLoop_extra_of_acyclic (c : Circuit) (extra : Nat)
    (hacyclic : c.combAcyclic = true) :
    Circuit.kahnLoop c.combEdges (c.gates.size + extra)
        (List.range c.gates.size) = [] := by
  rw [pipeline_kahnLoop_add]
  have hbase : Circuit.kahnLoop c.combEdges c.gates.size
      (List.range c.gates.size) = [] := by
    simpa [Circuit.combAcyclic] using hacyclic
  rw [hbase, pipeline_kahnLoop_empty]

private theorem mem_topoLoop_or_remaining (edges : List (Nat × Nat)) :
    ∀ (fuel : Nat) (remaining : List Nat) (gate : Nat),
      gate ∈ remaining →
        gate ∈ Execution.topoLoop edges fuel remaining ∨
          gate ∈ UniversalSStage1.topoRemaining edges fuel remaining := by
  intro fuel
  induction fuel with
  | zero =>
      intro remaining gate hgate
      exact Or.inr hgate
  | succ fuel ih =>
      intro remaining gate hgate
      by_cases hready : gate ∈ Execution.ready edges remaining
      · left
        simp [Execution.topoLoop, hready]
      · have hnext : gate ∈ remaining.filter fun candidate =>
            !(Execution.ready edges remaining).contains candidate := by
          simp [hgate, hready]
        rcases ih _ _ hnext with hemitted | hremaining
        · left
          simp only [Execution.topoLoop, List.mem_append]
          exact Or.inr hemitted
        · right
          simpa [UniversalSStage1.topoRemaining] using hremaining

private theorem gateOrder_eq_topoLoop_of_wf (c : Circuit) (hwf : c.WF) :
    Execution.gateOrder c =
      Execution.topoLoop c.combEdges c.gates.size
        (List.range c.gates.size) := by
  let topo := Execution.topoLoop c.combEdges c.gates.size
    (List.range c.gates.size)
  have hremaining := UniversalSStage1.topoRemaining_empty_of_acyclic c hwf.2
  have hcovered : ∀ gate, gate ∈ List.range c.gates.size → gate ∈ topo := by
    intro gate hgate
    rcases mem_topoLoop_or_remaining c.combEdges c.gates.size
      (List.range c.gates.size) gate hgate with htopo | hrem
    · exact htopo
    · rw [hremaining] at hrem
      contradiction
  unfold Execution.gateOrder
  change topo ++ (List.range c.gates.size).filter
      (fun gate => !topo.contains gate) = topo
  rw [List.filter_eq_nil_iff.mpr]
  · exact List.append_nil _
  · intro gate hgate
    simp [hcovered gate hgate]

private theorem mem_topoLoop_of_mem (edges : List (Nat × Nat)) :
    ∀ (fuel : Nat) (remaining : List Nat) (gate : Nat),
      gate ∈ Execution.topoLoop edges fuel remaining → gate ∈ remaining := by
  intro fuel
  induction fuel with
  | zero => simp [Execution.topoLoop]
  | succ fuel ih =>
      intro remaining gate hgate
      simp only [Execution.topoLoop, List.mem_append] at hgate
      rcases hgate with hready | hlater
      · exact (List.mem_filter.mp hready).1
      · exact (List.mem_filter.mp (ih _ _ hlater)).1

private theorem topoLoop_nodup (edges : List (Nat × Nat)) :
    ∀ (fuel : Nat) (remaining : List Nat), remaining.Nodup →
      (Execution.topoLoop edges fuel remaining).Nodup := by
  intro fuel
  induction fuel with
  | zero => intro remaining _; simp [Execution.topoLoop]
  | succ fuel ih =>
      intro remaining hn
      simp only [Execution.topoLoop]
      rw [List.nodup_append]
      refine ⟨hn.filter _, ih _ (hn.filter _), ?_⟩
      intro gate hready other hlater heq
      subst other
      have hnext := mem_topoLoop_of_mem edges fuel _ gate hlater
      have hnotReady := (List.mem_filter.mp hnext).2
      simp [hready] at hnotReady

private theorem gateOrder_nodup_of_wf (c : Circuit) (hwf : c.WF) :
    (Execution.gateOrder c).Nodup := by
  rw [gateOrder_eq_topoLoop_of_wf c hwf]
  exact topoLoop_nodup c.combEdges c.gates.size
    (List.range c.gates.size) List.nodup_range

theorem pipeline_remaining_classify_after_step {H d t : Nat}
    (up tail : PipelineGadget H d t) (remaining : List Nat) (gate : Nat)
    (hmem : gate ∈ Circuit.kahnStep
      (registeredCompositeCircuit up.g tail.ports).combEdges remaining) :
    gate < up.g.circuit.gates.size ∨
      ∃ downGate, downGate < tail.g.circuit.gates.size ∧
        embeddedTailGate up.g tail.ports downGate = gate := by
  have hpred : Circuit.hasRemainingPred
      (registeredCompositeCircuit up.g tail.ports).combEdges remaining gate =
      true := (List.mem_filter.mp hmem).2
  simp only [Circuit.hasRemainingPred, List.any_eq_true, Bool.and_eq_true,
    List.contains_iff_mem, beq_iff_eq] at hpred
  rcases hpred with ⟨edge, hedge, _hsource, htarget⟩
  rw [pipeline_registeredComposite_combEdges_mem up tail edge] at hedge
  rcases hedge with hupEdge | ⟨downEdge, hdownEdge, rfl⟩
  · left
    have hbounds := pipeline_combEdge_bounds up.g.circuit up.down_cert.1.1
      edge hupEdge
    omega
  · right
    have hbounds := pipeline_combEdge_bounds tail.g.circuit tail.down_cert.1.1
      downEdge hdownEdge
    have hnone := pipeline_connectedShare_none_of_combEdge_dst tail downEdge
      hdownEdge
    refine ⟨downEdge.2, hbounds.2, ?_⟩
    simpa [embeddedTailGate, hnone] using htarget

theorem registeredCompositeCircuit_wf {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    (registeredCompositeCircuit up.g tail.ports).WF := by
  refine ⟨registeredComposite_indicesOk up tail, ?_⟩
  unfold Circuit.combAcyclic
  let composite := registeredCompositeCircuit up.g tail.ports
  let fuel := composite.gates.size
  have hfuel : fuel = up.g.circuit.gates.size +
      (tail.g.d + tail.g.circuit.gates.size) := by
    simp [fuel, composite, registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, boundaryRegisterGates,
      registeredDownGates, Nat.add_assoc]
  have hfuelPos : 0 < fuel := by
    rw [hfuel]
    have hd : 0 < tail.g.d := by
      have : t < tail.g.d := by simpa [tail.d_eq] using tail.order_lt
      omega
    omega
  let final := Circuit.kahnLoop composite.combEdges fuel
    (List.range composite.gates.size)
  have hprefix : final.filter
      (fun gate => gate < up.g.circuit.gates.size) = [] := by
    have htrack := pipeline_prefix_kahnLoop up tail fuel
    have hupEmpty : Circuit.kahnLoop up.g.circuit.combEdges fuel
        (List.range up.g.circuit.gates.size) = [] := by
      rw [hfuel]
      exact pipeline_kahnLoop_extra_of_acyclic up.g.circuit
        (tail.g.d + tail.g.circuit.gates.size) up.down_cert.1.1.2
    simpa [final, composite, hupEmpty] using htrack
  have hpull : testPullRemaining up.g tail.ports final = [] := by
    have htrack := pipeline_pull_kahnLoop up tail fuel
      (List.range composite.gates.size)
    have hrange : testPullRemaining up.g tail.ports
        (List.range composite.gates.size) =
          List.range tail.g.circuit.gates.size := by
      simpa [composite] using pipeline_pull_range up tail
    rw [hrange] at htrack
    have htailEmpty : Circuit.kahnLoop tail.g.circuit.combEdges fuel
        (List.range tail.g.circuit.gates.size) = [] := by
      have hfuelTail : fuel = tail.g.circuit.gates.size +
          (up.g.circuit.gates.size + tail.g.d) := by
        rw [hfuel]
        omega
      rw [hfuelTail]
      exact pipeline_kahnLoop_extra_of_acyclic tail.g.circuit
        (up.g.circuit.gates.size + tail.g.d) tail.down_cert.1.1.2
    simpa [final, composite, htailEmpty] using htrack
  have hfinal : final = [] := by
    apply List.eq_nil_iff_forall_not_mem.mpr
    intro gate hgate
    have hfirst : gate ∈ Circuit.kahnStep composite.combEdges
        (List.range composite.gates.size) := by
      obtain ⟨remainingFuel, hfuelSucc⟩ := Nat.exists_eq_succ_of_ne_zero
        (Nat.ne_of_gt hfuelPos)
      have hgate' : gate ∈ Circuit.kahnLoop composite.combEdges fuel
          (List.range composite.gates.size) := by simpa [final] using hgate
      rw [hfuelSucc] at hgate'
      simp only [Circuit.kahnLoop] at hgate'
      exact pipeline_mem_kahnLoop_of_mem composite.combEdges remainingFuel _ gate
        hgate'
    have hclassify := pipeline_remaining_classify_after_step up tail
      (List.range composite.gates.size) gate (by simpa [composite] using hfirst)
    rcases hclassify with hgateUp | ⟨downGate, hdownGate, hembed⟩
    · have : gate ∈ final.filter
          (fun candidate => candidate < up.g.circuit.gates.size) :=
        List.mem_filter.mpr ⟨hgate, by simpa using hgateUp⟩
      rw [hprefix] at this
      simpa using this
    · have : downGate ∈ testPullRemaining up.g tail.ports final := by
        simp [testPullRemaining, hdownGate, hembed, hgate]
      rw [hpull] at this
      simpa using this
  change final.isEmpty = true
  rw [hfinal]
  rfl

theorem pipeline_memberNodes_eq_nodes (g : GadgetInstance)
    (hmember : ∀ node, g.member node = true) :
    memberNodes g = nodes g := by
  unfold memberNodes
  apply List.filter_eq_self.mpr
  intro node _
  exact hmember node

theorem pipeline_combInput_mem_nodes (g : GadgetInstance) (hcwf : g.circuit.WF)
    (node input : Node) (hnode : node ∈ nodes g)
    (hinput : input ∈ combInputNodes g node) : input ∈ nodes g := by
  rw [nodes, List.mem_flatMap] at hnode ⊢
  rcases hnode with ⟨cycle, hcycle, hgate⟩
  rw [List.mem_map] at hgate
  rcases hgate with ⟨gate, hgate, rfl⟩
  cases hentry : g.circuit.gates[gate]? with
  | none => simp [combInputNodes, hentry] at hinput
  | some entry =>
      simp only [combInputNodes, hentry] at hinput
      rw [List.mem_map] at hinput
      rcases hinput with ⟨edge, hedge, rfl⟩
      have hsource := UniversalSStage1.inputsBelow_of_indicesOk g.circuit
        hcwf.1 gate (by simpa using hgate) entry hentry edge
        (List.mem_filter.mp hedge).1
      exact ⟨cycle, hcycle, List.mem_map.mpr
        ⟨edge.1, by simpa using hsource, rfl⟩⟩

theorem pipeline_transInput_mem_nodes (g : GadgetInstance) (hcwf : g.circuit.WF)
    (node input : Node) (hnode : node ∈ nodes g)
    (hinput : input ∈ transInputNodes g node) : input ∈ nodes g := by
  rw [nodes, List.mem_flatMap] at hnode ⊢
  rcases hnode with ⟨cycle, hcycle, hgate⟩
  rw [List.mem_map] at hgate
  rcases hgate with ⟨gate, hgate, rfl⟩
  cases cycle with
  | zero => simp [transInputNodes] at hinput
  | succ previous =>
      cases hentry : g.circuit.gates[gate]? with
      | none => simp [transInputNodes, hentry] at hinput
      | some entry =>
          simp only [transInputNodes, hentry] at hinput
          rw [List.mem_map] at hinput
          rcases hinput with ⟨edge, hedge, rfl⟩
          have hsource := UniversalSStage1.inputsBelow_of_indicesOk g.circuit
            hcwf.1 gate (by simpa using hgate) entry hentry edge
            (List.mem_filter.mp hedge).1
          have hcycleLt : previous + 1 < g.horizon := by
            simpa using (List.mem_range.mp hcycle)
          exact ⟨previous, List.mem_range.mpr (by omega),
            List.mem_map.mpr ⟨edge.1, by simpa using hsource, rfl⟩⟩

theorem pipeline_whole_member_closure (g : GadgetInstance) (hcwf : g.circuit.WF)
    (hmember : ∀ node, g.member node = true) :
    ((memberNodes g).flatMap (combInputNodes g)).all
          (memberNodes g).contains = true ∧
      ((memberNodes g).flatMap (transInputNodes g)).all
          (memberNodes g).contains = true := by
  rw [pipeline_memberNodes_eq_nodes g hmember]
  constructor
  · apply List.all_eq_true.mpr
    intro input hinput
    rw [List.mem_flatMap] at hinput
    rcases hinput with ⟨node, hnode, hinput⟩
    simpa using pipeline_combInput_mem_nodes g hcwf node input hnode hinput
  · apply List.all_eq_true.mpr
    intro input hinput
    rw [List.mem_flatMap] at hinput
    rcases hinput with ⟨node, hnode, hinput⟩
    simpa using pipeline_transInput_mem_nodes g hcwf node input hnode hinput

theorem registeredComposite_wf {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    (registeredComposite up.g tail.ports).WF := by
  let composite := registeredComposite up.g tail.ports
  have hcwf := registeredCompositeCircuit_wf up tail
  have hmember : ∀ node, composite.member node = true := by
    intro node
    rfl
  have hclosure := pipeline_whole_member_closure composite hcwf hmember
  refine ⟨hcwf, ?_, ?_, ?_, hclosure.1, hclosure.2⟩
  · have : 0 < tail.g.d := tail.down_cert.1.2.1
    simpa [composite, registeredComposite] using this
  · apply outputNodes_nodup
    intro i j hi hj heq
    have hi' : i < d := by simpa [composite, registeredComposite,
      tail.d_eq] using hi
    have hj' : j < d := by simpa [composite, registeredComposite,
      tail.d_eq] using hj
    apply tail.output_inj i j hi' hj'
    cases hiout : tail.g.output i with
    | mk igate icycle =>
        cases hjout : tail.g.output j with
        | mk jgate jcycle =>
            simp [composite, registeredComposite, downstreamOffset,
              hiout, hjout] at heq
            simp [hiout, hjout, heq]
  · apply List.all_eq_true.mpr
    intro output houtput
    rw [List.contains_iff_mem]
    rw [pipeline_memberNodes_eq_nodes composite hmember]
    rw [outputNodes, List.mem_map] at houtput
    rcases houtput with ⟨share, hshare, rfl⟩
    have hshareTail : share < tail.g.d := by
      simpa [composite, registeredComposite] using hshare
    have htailOutput : tail.g.output share ∈ memberNodes tail.g := by
      have hall := List.all_eq_true.mp tail.down_cert.1.2.2.2.1
      exact List.contains_iff_mem.mp (hall _
        (List.mem_map.mpr ⟨share, by simpa using hshareTail, rfl⟩))
    have htailNode := (List.mem_filter.mp htailOutput).1
    rw [nodes, List.mem_flatMap] at htailNode ⊢
    rcases htailNode with ⟨cycle, hcycle, hgate⟩
    rw [List.mem_map] at hgate
    rcases hgate with ⟨gate, hgate, heq⟩
    have hgateEq : gate = (tail.g.output share).gate := by
      simpa using congrArg Node.gate heq
    have hcycleEq : cycle = (tail.g.output share).cycle := by
      simpa using congrArg Node.cycle heq
    refine ⟨(tail.g.output share).cycle, ?_, List.mem_map.mpr
      ⟨downstreamOffset up.g tail.g + (tail.g.output share).gate, ?_, ?_⟩⟩
    · exact List.mem_range.mpr (by
        have hcycleLt : (tail.g.output share).cycle < tail.g.horizon := by
          rw [← hcycleEq]
          exact List.mem_range.mp hcycle
        simp [composite, registeredComposite]
        omega)
    · exact List.mem_range.mpr (by
        have hgateLt :
            (tail.g.output share).gate < tail.g.circuit.gates.size := by
          rw [← hgateEq]
          exact List.mem_range.mp hgate
        have hcompSize : composite.circuit.gates.size =
            downstreamOffset up.g tail.g + tail.g.circuit.gates.size := by
          simp [composite, registeredComposite, registeredCompositeCircuit,
            UniversalSStage1.appendCircuit, boundaryRegisterGates,
            registeredDownGates, downstreamOffset, Nat.add_assoc]
        rw [hcompSize]
        omega)
    · simp [composite, registeredComposite]

theorem registeredComposite_forwardCombinational {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    ForwardCombinational (registeredComposite up.g tail.ports) := by
  unfold ForwardCombinational
  apply List.all_eq_true.mpr
  intro edge hedge
  rw [show (registeredComposite up.g tail.ports).circuit =
      registeredCompositeCircuit up.g tail.ports by rfl] at hedge
  have hcases := (pipeline_registeredComposite_combEdges_mem up tail edge).mp
    hedge
  rcases hcases with hupEdge | ⟨downEdge, hdownEdge, rfl⟩
  · have hall := List.all_eq_true.mp up.forward_combinational edge hupEdge
    simpa using hall
  · have hdown := List.all_eq_true.mp tail.forward_combinational
      downEdge hdownEdge
    have hdownLt : downEdge.1 < downEdge.2 := by simpa using hdown
    cases hconnected : connectedShare? tail.ports downEdge.1 with
    | none =>
        simp [embeddedTailGate, hconnected, downstreamOffset]
        omega
    | some share =>
        have hshareMem := List.mem_of_find?_eq_some hconnected
        have hshare : share < tail.g.d := by
          simpa [connectedShare?] using hshareMem
        simp [embeddedTailGate, hconnected, boundaryRegister,
          downstreamOffset]
        omega

/-! ## Composite source support -/

/-- The raw source scan contributed by the compiler-copied tail suffix, with
its final composite gate indices.  P3 first isolates this definitional layer;
the normalization to isolated-tail sources is the alias-sensitive part. -/
def registeredTailRawSrcs (up tail : GadgetInstance)
    (ports : RegisterPorts tail) : List Src :=
  ((registeredDownGates (up := up) ports).toList.zipIdx
      (downstreamOffset up tail)).flatMap fun (gate, index) =>
        UniversalSStage1.publicGateSrcs tail.horizon gate ++
          UniversalSStage1.publicBoundarySrcs tail.horizon index gate

/-- Tail sources removed when the designated input gates are compiled to
constants; surviving register-initialization atoms are shifted with their
gates. -/
def shiftedSurvivingTailSrcs (up tail : GadgetInstance)
    (ports : RegisterPorts tail) : List Src :=
  ((Execution.relevantSrcs tail.circuit tail.horizon).filter fun src =>
      !(portInputAtoms ports).contains src).map (shiftDownSrc up tail)

private theorem removeAll_eraseDups_right [BEq α] [LawfulBEq α]
    (left right : List α) :
    left.removeAll right.eraseDups = left.removeAll right := by
  induction left with
  | nil => rfl
  | cons x xs ih =>
      simp only [List.cons_removeAll]
      by_cases hx : x ∈ right <;> simp [hx, ih]

private theorem eraseDups_append_eraseDups_left [BEq α] [LawfulBEq α]
    (left right : List α) :
    (left.eraseDups ++ right).eraseDups =
      (left ++ right).eraseDups := by
  rw [List.eraseDups_append, List.eraseDups_append]
  rw [eraseDups_eq_self_of_nodup (eraseDups_nodup left)]
  rw [removeAll_eraseDups_right]

private theorem publicBoundarySrcs_register (horizon gate source : Nat)
    (hpos : 0 < horizon) :
    UniversalSStage1.publicBoundarySrcs horizon gate
        { kind := .reg, inputs := [(source, 1)] } =
      [Src.iniReg gate] := by
  obtain ⟨rest, rfl⟩ := Nat.exists_eq_succ_of_ne_zero (Nat.ne_of_gt hpos)
  simp [UniversalSStage1.publicBoundarySrcs, List.range_succ_eq_map]

private theorem boundaryRegisterRawSrcs (horizon offset : Nat)
    (outputs : Nat → Node) (shares : List Nat) (hpos : 0 < horizon) :
    ((shares.map fun share =>
        ({ kind := .reg, inputs := [((outputs share).gate, 1)] } : Gate)).zipIdx
        offset).flatMap (fun (gate, index) =>
          UniversalSStage1.publicGateSrcs horizon gate ++
            UniversalSStage1.publicBoundarySrcs horizon index gate) =
      (shares.zipIdx offset).map fun pair => Src.iniReg pair.2 := by
  induction shares generalizing offset with
  | nil => rfl
  | cons share shares ih =>
      simp only [List.map_cons, List.zipIdx_cons, List.flatMap_cons,
        List.map_cons]
      rw [publicBoundarySrcs_register horizon offset
        (outputs share).gate hpos]
      simp only [UniversalSStage1.publicGateSrcs, List.nil_append,
        List.singleton_append, List.cons.injEq, true_and]
      exact ih (offset + 1)

private theorem map_iniReg_zipIdx_range (count offset : Nat) :
    ((List.range count).zipIdx offset).map
        (fun pair => Src.iniReg pair.2) =
      (List.range count).map fun index => Src.iniReg (offset + index) := by
  rw [show (fun pair : Nat × Nat => Src.iniReg pair.2) =
    Src.iniReg ∘ Prod.snd by rfl]
  rw [← List.map_map, List.zipIdx_map_snd, List.range'_eq_map_range,
    List.map_map]
  simp [Function.comp_def]

private theorem publicBoundarySrcs_wireRegistered {up down : GadgetInstance}
    (ports : RegisterPorts down) (horizon gateIndex : Nat) (gate : Gate)
    (hconnected : connectedShare? ports gateIndex = none) :
    UniversalSStage1.publicBoundarySrcs horizon
        (downstreamOffset up down + gateIndex)
        (wireRegisteredDownGate (up := up) ports gateIndex gate) =
      (UniversalSStage1.publicBoundarySrcs horizon gateIndex gate).map
        (shiftDownSrc up down) := by
  have hsnd (edge : Nat × Nat) :
      (wireRegisteredEdge (up := up) ports edge).2 = edge.2 := by
    simp [wireRegisteredEdge]
    split <;> rfl
  have hfilter (cycle : Nat) :
      (gate.inputs.map (wireRegisteredEdge (up := up) ports)).filter
          (fun input => decide (cycle < input.2)) =
        (gate.inputs.filter (fun input => decide (cycle < input.2))).map
          (wireRegisteredEdge (up := up) ports) := by
    rw [List.filter_map]
    congr 1
    apply List.filter_congr
    intro edge _
    simp [hsnd]
  simp only [wireRegisteredDownGate, hconnected,
    UniversalSStage1.publicBoundarySrcs, List.map_flatMap]
  congr 1
  funext cycle
  rw [hfilter]
  simp only [List.map_map]
  apply List.map_congr_left
  intro edge _
  simp [shiftDownSrc, downstreamOffset]

private theorem publicGateSrcs_wireRegistered {up down : GadgetInstance}
    (ports : RegisterPorts down) (horizon gateIndex : Nat) (gate : Gate)
    (hconnected : connectedShare? ports gateIndex = none) :
    UniversalSStage1.publicGateSrcs horizon
        (wireRegisteredDownGate (up := up) ports gateIndex gate) =
      (UniversalSStage1.publicGateSrcs horizon gate).map
        (shiftDownSrc up down) := by
  simp only [wireRegisteredDownGate, hconnected]
  cases gate with
  | mk kind inputs =>
      cases kind <;>
        simp [UniversalSStage1.publicGateSrcs, shiftDownSrc]

private theorem publicSrcs_wireRegistered {up down : GadgetInstance}
    (ports : RegisterPorts down) (horizon gateIndex : Nat) (gate : Gate)
    (hconnected : connectedShare? ports gateIndex = none) :
    UniversalSStage1.publicGateSrcs horizon
          (wireRegisteredDownGate (up := up) ports gateIndex gate) ++
        UniversalSStage1.publicBoundarySrcs horizon
          (downstreamOffset up down + gateIndex)
          (wireRegisteredDownGate (up := up) ports gateIndex gate) =
      (UniversalSStage1.publicGateSrcs horizon gate ++
        UniversalSStage1.publicBoundarySrcs horizon gateIndex gate).map
          (shiftDownSrc up down) := by
  rw [List.map_append, publicGateSrcs_wireRegistered ports horizon gateIndex
    gate hconnected, publicBoundarySrcs_wireRegistered ports horizon gateIndex
    gate hconnected]

/-- The isolated tail scan after removing connected source gates and shifting
every surviving source into the composite namespace. -/
def shiftedCompiledTailRawSrcs (up tail : GadgetInstance)
    (ports : RegisterPorts tail) : List Src :=
  (tail.circuit.gates.toList.zipIdx).flatMap fun (gate, gateIndex) =>
    match connectedShare? ports gateIndex with
    | some _ => []
    | none =>
        (UniversalSStage1.publicGateSrcs tail.horizon gate ++
          UniversalSStage1.publicBoundarySrcs tail.horizon gateIndex gate).map
            (shiftDownSrc up tail)

private theorem registeredTailScan_loop (up tail : GadgetInstance)
    (ports : RegisterPorts tail) (gates : List Gate) (start : Nat) :
    (((gates.zipIdx start).map fun indexed =>
        wireRegisteredDownGate (up := up) ports indexed.2 indexed.1).zipIdx
        (downstreamOffset up tail + start)).flatMap (fun indexed =>
          UniversalSStage1.publicGateSrcs tail.horizon indexed.1 ++
            UniversalSStage1.publicBoundarySrcs tail.horizon indexed.2
              indexed.1) =
      (gates.zipIdx start).flatMap fun indexed =>
        match connectedShare? ports indexed.2 with
        | some _ => []
        | none =>
            (UniversalSStage1.publicGateSrcs tail.horizon indexed.1 ++
              UniversalSStage1.publicBoundarySrcs tail.horizon indexed.2
                indexed.1).map (shiftDownSrc up tail) := by
  induction gates generalizing start with
  | nil => rfl
  | cons gate gates ih =>
      simp only [List.zipIdx_cons, List.map_cons, List.flatMap_cons]
      cases hconnected : connectedShare? ports start with
      | some share =>
          have hhead :
              UniversalSStage1.publicGateSrcs tail.horizon
                    (wireRegisteredDownGate (up := up) ports start gate) ++
                  UniversalSStage1.publicBoundarySrcs tail.horizon
                    (downstreamOffset up tail + start)
                    (wireRegisteredDownGate (up := up) ports start gate) =
                [] := by
            simp [wireRegisteredDownGate, hconnected,
              UniversalSStage1.publicGateSrcs,
              UniversalSStage1.publicBoundarySrcs]
          rw [hhead]
          simp only [hconnected, List.nil_append]
          simpa [Nat.add_assoc] using ih (start + 1)
      | none =>
          rw [publicSrcs_wireRegistered ports tail.horizon start gate
            hconnected]
          simp only [hconnected]
          simpa [Nat.add_assoc] using ih (start + 1)

private theorem registeredTailRawSrcs_eq_compiled (up tail : GadgetInstance)
    (ports : RegisterPorts tail) :
    registeredTailRawSrcs up tail ports =
      shiftedCompiledTailRawSrcs up tail ports := by
  unfold registeredTailRawSrcs shiftedCompiledTailRawSrcs
  rw [registeredDownGates, Array.toList_mapIdx,
    List.mapIdx_eq_zipIdx_map]
  simpa using registeredTailScan_loop up tail ports
    tail.circuit.gates.toList 0

private theorem pipeline_port_stream_gate_eq {H d t : Nat}
    (tail : PipelineGadget H d t) (share other sharing lane : Nat)
    (otherInputs : List (Nat × Nat))
    (hshare : share < tail.g.d)
    (hport : tail.g.circuit.gates[tail.ports.inputGate share]? =
      some { kind := .inp sharing lane, inputs := [] })
    (hother : tail.g.circuit.gates[other]? =
      some { kind := .inp sharing lane, inputs := otherInputs }) :
    other = tail.ports.inputGate share := by
  have hotherBound : other < tail.g.circuit.gates.size :=
    (Array.getElem?_eq_some_iff.mp hother).choose
  have hshareMem : share ∈ List.range tail.g.d := by simpa using hshare
  have hotherMem : other ∈ List.range tail.g.circuit.gates.size := by
    simpa using hotherBound
  have hshares := List.all_eq_true.mp
    tail.port_source_exclusive.2.1 share hshareMem
  have hgates := List.all_eq_true.mp hshares other hotherMem
  simp [hport, hother] at hgates
  exact hgates

private def tailGateRawSrcs (g : GadgetInstance)
    (gateIndex : Nat) (gate : Gate) : List Src :=
  UniversalSStage1.publicGateSrcs g.horizon gate ++
    UniversalSStage1.publicBoundarySrcs g.horizon gateIndex gate

private theorem tailGateRawSrcs_connected_filter {H d t : Nat}
    (tail : PipelineGadget H d t) (gateIndex share : Nat) (gate : Gate)
    (hgate : tail.g.circuit.gates[gateIndex]? = some gate)
    (hconnected : connectedShare? tail.ports gateIndex = some share) :
    (tailGateRawSrcs tail.g gateIndex gate).filter
        (fun src => !(portInputAtoms tail.ports).contains src) = [] := by
  have hshareMem := List.mem_of_find?_eq_some hconnected
  have hshare : share < tail.g.d := by
    simpa [connectedShare?] using hshareMem
  have hgateEq : tail.ports.inputGate share = gateIndex := by
    have := List.find?_some hconnected
    simpa [connectedShare?] using this
  obtain ⟨sharing, hport, _⟩ :=
    tail.ports.input_source_coherent share hshare
  rw [hgateEq, hgate] at hport
  cases hport
  apply List.filter_eq_nil_iff.mpr
  intro src hsrc
  have hsrc' : src ∈
      (List.range tail.g.horizon).map (.inp sharing share) := by
    simpa [tailGateRawSrcs, UniversalSStage1.publicGateSrcs,
      UniversalSStage1.publicBoundarySrcs] using hsrc
  have hportMem : src ∈ portInputAtoms tail.ports := by
    unfold portInputAtoms
    rw [List.mem_flatMap]
    refine ⟨share, by simpa using hshare, ?_⟩
    simpa [hgateEq, hgate] using hsrc'
  simp [hportMem]

private theorem tailGateRawSrcs_unconnected_filter {H d t : Nat}
    (tail : PipelineGadget H d t) (gateIndex : Nat) (gate : Gate)
    (hgate : tail.g.circuit.gates[gateIndex]? = some gate)
    (hconnected : connectedShare? tail.ports gateIndex = none) :
    (tailGateRawSrcs tail.g gateIndex gate).filter
        (fun src => !(portInputAtoms tail.ports).contains src) =
      tailGateRawSrcs tail.g gateIndex gate := by
  apply List.filter_eq_self.mpr
  intro src hsrc
  by_cases hportMem : src ∈ portInputAtoms tail.ports
  · exfalso
    unfold portInputAtoms at hportMem
    rw [List.mem_flatMap] at hportMem
    rcases hportMem with ⟨share, hshareMem, hsrcPort⟩
    have hshare : share < tail.g.d := by simpa using hshareMem
    obtain ⟨sharing, hport, _⟩ :=
      tail.ports.input_source_coherent share hshare
    simp only [hport] at hsrcPort
    rw [List.mem_map] at hsrcPort
    rcases hsrcPort with ⟨cycle, hcycle, rfl⟩
    cases gate with
    | mk kind inputs =>
        cases kind <;>
          simp [tailGateRawSrcs, UniversalSStage1.publicGateSrcs,
            UniversalSStage1.publicBoundarySrcs] at hsrc
        case inp otherSharing otherLane =>
          rcases hsrc with
            ⟨sourceCycle, _hsourceCycle, hsharing, hlane, _hcycleEq⟩
          subst otherSharing
          subst otherLane
          have hgateEq := pipeline_port_stream_gate_eq tail share gateIndex
            sharing share inputs hshare hport hgate
          have hnot := (List.find?_eq_none.mp hconnected) share hshareMem
          exact hnot (by simpa [hgateEq])
  · simp [List.contains_iff_mem, hportMem]

private def tailRawSrcs (g : GadgetInstance) : List Src :=
  (g.circuit.gates.toList.zipIdx).flatMap fun indexed =>
    tailGateRawSrcs g indexed.2 indexed.1

private def survivingTailRawSrcs (g : GadgetInstance)
    (ports : RegisterPorts g) : List Src :=
  (g.circuit.gates.toList.zipIdx).flatMap fun indexed =>
    match connectedShare? ports indexed.2 with
    | some _ => []
    | none => tailGateRawSrcs g indexed.2 indexed.1

private theorem survivingTailRawSrcs_eq_filter {H d t : Nat}
    (tail : PipelineGadget H d t) :
    survivingTailRawSrcs tail.g tail.ports =
      (tailRawSrcs tail.g).filter fun src =>
        !(portInputAtoms tail.ports).contains src := by
  unfold survivingTailRawSrcs tailRawSrcs
  rw [List.filter_flatMap]
  apply congrArg List.flatten
  apply List.map_congr_left
  intro indexed hindexed
  have hgate : tail.g.circuit.gates[indexed.2]? = some indexed.1 := by
    rw [List.mem_zipIdx_iff_getElem?] at hindexed
    simpa using hindexed
  cases hconnected : connectedShare? tail.ports indexed.2 with
  | some share =>
      simp only [hconnected]
      exact (tailGateRawSrcs_connected_filter tail indexed.2 share
        indexed.1 hgate hconnected).symm
  | none =>
      simp only [hconnected]
      exact (tailGateRawSrcs_unconnected_filter tail indexed.2 indexed.1
        hgate hconnected).symm

private theorem filter_neq_redundant [BEq α] [LawfulBEq α]
    (predicate : α → Bool) (excluded : α) (xs : List α)
    (hexcluded : predicate excluded = false) :
    (xs.filter fun value => !value == excluded).filter predicate =
      xs.filter predicate := by
  rw [List.filter_filter]
  apply List.filter_congr
  intro value _
  by_cases heq : value = excluded
  · subst value
    simp [hexcluded]
  · simp [heq]

private theorem filter_comm (left right : α → Bool) (xs : List α) :
    (xs.filter left).filter right = (xs.filter right).filter left := by
  simp only [List.filter_filter]
  apply List.filter_congr
  intro value _
  exact Bool.and_comm _ _

private theorem eraseDups_filter [BEq α] [LawfulBEq α]
    (predicate : α → Bool) (xs : List α) :
    (xs.filter predicate).eraseDups = xs.eraseDups.filter predicate := by
  induction xs generalizing predicate with
  | nil => rfl
  | cons x xs ih =>
      simp only [List.filter_cons, List.eraseDups_cons]
      split <;> rename_i hx
      · rw [List.eraseDups_cons]
        rw [filter_comm]
        rw [ih (fun value => !value == x)]
        simp only [List.filter_filter]
        rw [ih]
      · have hxfalse : predicate x = false := by simpa using hx
        rw [ih predicate, ih (fun value => !value == x)]
        exact (filter_neq_redundant predicate x xs.eraseDups hxfalse).symm

private theorem eraseDups_map_injective [BEq α] [LawfulBEq α]
    [BEq β] [LawfulBEq β] (mapFn : α → β)
    (hinjective : Function.Injective mapFn) (xs : List α) :
    (xs.map mapFn).eraseDups = xs.eraseDups.map mapFn := by
  match xs with
  | [] => rfl
  | x :: xs =>
      simp only [List.map_cons, List.eraseDups_cons]
      have hfilter :
          (xs.map mapFn).filter (fun value => !value == mapFn x) =
            (xs.filter fun value => !value == x).map mapFn := by
        rw [List.filter_map]
        congr 1
        apply List.filter_congr
        intro value _
        rw [Bool.eq_iff_iff]
        simpa only [Function.comp_apply, Bool.not_eq_true',
          beq_eq_false_iff_ne] using
          (not_congr (hinjective.eq_iff (a := value) (b := x)))
      rw [hfilter, eraseDups_map_injective mapFn hinjective
        (xs.filter fun value => !value == x)]
termination_by xs.length
decreasing_by
  exact Nat.lt_of_le_of_lt (List.length_filter_le _ _) (Nat.lt_succ_self _)

private theorem shiftDownSrc_injective (up tail : GadgetInstance) :
    Function.Injective (shiftDownSrc up tail) := by
  intro left right heq
  cases left <;> cases right <;>
    simp [shiftDownSrc, downstreamOffset] at heq ⊢ <;> omega

private theorem shiftedCompiledTailRawSrcs_eq_map
    (up tail : GadgetInstance) (ports : RegisterPorts tail) :
    shiftedCompiledTailRawSrcs up tail ports =
      (survivingTailRawSrcs tail ports).map (shiftDownSrc up tail) := by
  unfold shiftedCompiledTailRawSrcs survivingTailRawSrcs
  rw [List.map_flatMap]
  congr 1
  funext indexed
  cases hconnected : connectedShare? ports indexed.2 <;>
    simp [hconnected, tailGateRawSrcs]

private theorem relevantSrcs_eq_tailRawSrcs (g : GadgetInstance) :
    Execution.relevantSrcs g.circuit g.horizon =
      (tailRawSrcs g).eraseDups := by
  rw [UniversalSStage1.relevantSrcs_eq_public]
  rfl

private theorem registeredTailRawSrcs_normalized {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    (registeredTailRawSrcs up.g tail.g tail.ports).eraseDups =
      shiftedSurvivingTailSrcs up.g tail.g tail.ports := by
  rw [registeredTailRawSrcs_eq_compiled,
    shiftedCompiledTailRawSrcs_eq_map]
  rw [eraseDups_map_injective (shiftDownSrc up.g tail.g)
    (shiftDownSrc_injective up.g tail.g)]
  unfold shiftedSurvivingTailSrcs
  rw [survivingTailRawSrcs_eq_filter tail]
  rw [eraseDups_filter]
  rw [← relevantSrcs_eq_tailRawSrcs]

private theorem eraseDups_removeAll [BEq α] [LawfulBEq α]
    (xs removed : List α) :
    xs.eraseDups.removeAll removed = (xs.removeAll removed).eraseDups := by
  induction removed generalizing xs with
  | nil => simp
  | cons value removed ih =>
      rw [List.removeAll_cons, List.removeAll_cons]
      rw [← eraseDups_filter]
      exact ih (xs.filter fun candidate => !candidate == value)

private theorem eraseDups_append_eraseDups_right [BEq α] [LawfulBEq α]
    (left right : List α) :
    (left ++ right.eraseDups).eraseDups =
      (left ++ right).eraseDups := by
  rw [List.eraseDups_append, List.eraseDups_append]
  rw [eraseDups_removeAll]
  rw [eraseDups_eq_self_of_nodup (eraseDups_nodup _)]

/-- P3a: exact compiler-native source-support decomposition. -/
theorem relevantSrcs_registeredComposite_raw {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    Execution.relevantSrcs
        (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon =
      (Execution.relevantSrcs up.g.circuit up.g.horizon ++
        (List.range d).map (fun share =>
          (.iniReg (boundaryRegister up.g share) : Src)) ++
        registeredTailRawSrcs up.g tail.g tail.ports).eraseDups := by
  have hpos : 0 < H := Nat.zero_lt_of_lt tail.arrival_inside
  rw [UniversalSStage1.relevantSrcs_eq_public]
  rw [UniversalSStage1.relevantSrcs_eq_public up.g.circuit]
  simp only [registeredComposite, registeredCompositeCircuit,
    UniversalSStage1.appendCircuit, Array.toList_append,
    List.zipIdx_append, List.flatMap_append, registeredTailRawSrcs,
    up.horizon_eq, tail.horizon_eq, Nat.max_self, tail.d_eq]
  simp only [boundaryRegisterGates, Array.toList_map, List.toList_toArray,
    List.length_range, Array.length_toList, Nat.zero_add, downstreamOffset,
    tail.d_eq]
  rw [boundaryRegisterRawSrcs H up.g.circuit.gates.size up.g.output
    (List.range d) hpos]
  rw [map_iniReg_zipIdx_range d up.g.circuit.gates.size]
  simp only [boundaryRegister, List.length_map, List.length_range]
  simp only [List.append_assoc]
  symm
  apply eraseDups_append_eraseDups_left

/-- P3: exact source-support decomposition in isolated component terms. -/
theorem relevantSrcs_registeredComposite {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    Execution.relevantSrcs
        (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon =
      (Execution.relevantSrcs up.g.circuit up.g.horizon ++
        (List.range d).map (fun share =>
          (.iniReg (boundaryRegister up.g share) : Src)) ++
        shiftedSurvivingTailSrcs up.g tail.g tail.ports).eraseDups := by
  rw [relevantSrcs_registeredComposite_raw up tail]
  simp only [List.append_assoc]
  rw [← eraseDups_append_eraseDups_right]
  rw [← eraseDups_append_eraseDups_right
    ((List.range d).map fun share =>
      (.iniReg (boundaryRegister up.g share) : Src))
    (registeredTailRawSrcs up.g tail.g tail.ports)]
  rw [registeredTailRawSrcs_normalized up tail]
  apply eraseDups_append_eraseDups_right

/-- E2 at the live boundary cycle, now discharged by P0. -/
theorem eval_boundary_register {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (env : Env) (share : Nat) (hshare : share < d) :
    Execution.eval (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env
        { gate := boundaryRegister up.g share,
          cycle := tail.ports.arrivalCycle } =
      Execution.eval up.g.circuit up.g.horizon
        (restrictEnv
          (Execution.relevantSrcs up.g.circuit up.g.horizon) env)
        (up.g.output share) :=
  eval_boundary_register_of_wf up tail glue
    (registeredCompositeCircuit_wf up tail) env share hshare

private theorem lookupAssoc_evalCycle_other_cycle
    (c : Circuit) (env : Env) (cycle : Nat) (schedule : List Nat)
    (values : List (Node × Bool)) (target : Node)
    (hne : target.cycle ≠ cycle) :
    Execution.lookupAssoc target
        (UniversalSStage1.evalCycle c env cycle schedule values) =
      Execution.lookupAssoc target values := by
  induction schedule generalizing values with
  | nil => rfl
  | cons gate schedule ih =>
      rw [UniversalSStage1.evalCycle]
      simp only [List.foldl_cons]
      rw [← UniversalSStage1.evalCycle, ih]
      have hnode : target ≠ { gate := gate, cycle := cycle } := by
        intro heq
        exact hne (congrArg Node.cycle heq)
      simp [Execution.lookupAssoc, hnode]

private theorem lookupAssoc_evalCycle_other_gates
    (c : Circuit) (env : Env) (cycle : Nat) (schedule : List Nat)
    (target : Node) : ∀ values : List (Node × Bool),
    target.gate ∉ schedule →
      Execution.lookupAssoc target
          (UniversalSStage1.evalCycle c env cycle schedule values) =
        Execution.lookupAssoc target values := by
  induction schedule with
  | nil => intro values _; rfl
  | cons gate schedule ih =>
      intro values hnotmem
      simp only [List.mem_cons, not_or] at hnotmem
      rw [UniversalSStage1.evalCycle]
      simp only [List.foldl_cons]
      rw [← UniversalSStage1.evalCycle]
      rw [ih _ hnotmem.2]
      have hnode : target ≠ { gate := gate, cycle := cycle } := by
        intro heq
        exact hnotmem.1 (congrArg Node.gate heq)
      simp [Execution.lookupAssoc, hnode]

private theorem lookupAssoc_register_zero_after_evalCycle
    (c : Circuit) (env : Env) (register : Nat) (schedule : List Nat)
    (values : List (Node × Bool)) (source : Nat)
    (hgate : c.gates[register]? =
      some { kind := .reg, inputs := [(source, 1)] })
    (hmem : register ∈ schedule) :
    Execution.lookupAssoc { gate := register, cycle := 0 }
        (UniversalSStage1.evalCycle c env 0 schedule values) =
      some (env (.iniReg register)) := by
  induction schedule generalizing values with
  | nil => simp at hmem
  | cons current schedule ih =>
      rw [UniversalSStage1.evalCycle]
      simp only [List.foldl_cons]
      rw [← UniversalSStage1.evalCycle]
      by_cases htail : register ∈ schedule
      · exact ih _ htail
      · have hcurrent : current = register := by
          symm
          simpa [htail] using hmem
        subst current
        have hnotmem : register ∉ schedule := htail
        have hpreserve :
            Execution.lookupAssoc { gate := register, cycle := 0 }
                (UniversalSStage1.evalCycle c env 0 schedule
                  (({ gate := register, cycle := 0 },
                    UniversalSStage1.gateValue c env values 0 register) ::
                    values)) =
              Execution.lookupAssoc { gate := register, cycle := 0 }
                (({ gate := register, cycle := 0 },
                  UniversalSStage1.gateValue c env values 0 register) ::
                  values) :=
          lookupAssoc_evalCycle_other_gates c env 0 schedule
            { gate := register, cycle := 0 } _ hnotmem
        rw [hpreserve]
        simp [Execution.lookupAssoc, UniversalSStage1.gateValue,
          hgate, UniversalSStage1.inputValue]

private theorem evalEntries_succ_local (c : Circuit) (horizon : Nat)
    (env : Env) :
    UniversalSStage1.evalEntries c (horizon + 1) env =
      UniversalSStage1.evalCycle c env horizon (Execution.gateOrder c)
        (UniversalSStage1.evalEntries c horizon env) := by
  simp [UniversalSStage1.evalEntries, UniversalSStage1.evalCycles,
    List.range_succ, List.foldl_append]

private theorem gate_mem_gateOrder_local (c : Circuit) (gate : Nat)
    (hgate : gate < c.gates.size) : gate ∈ Execution.gateOrder c := by
  unfold Execution.gateOrder
  by_cases htopo : gate ∈ Execution.topoLoop c.combEdges c.gates.size
      (List.range c.gates.size)
  · exact List.mem_append_left _ htopo
  · apply List.mem_append_right
    simp [hgate, htopo]

private theorem eval_succ_stable_local (c : Circuit) (horizon : Nat)
    (env : Env) (node : Node) (hcycle : node.cycle < horizon) :
    Execution.eval c (horizon + 1) env node =
      Execution.eval c horizon env node := by
  by_cases hgate : node.gate < c.gates.size
  · have hcycle' : node.cycle < horizon + 1 := by omega
    simp only [Execution.eval, hgate, hcycle, hcycle', Bool.true_and,
      decide_true, if_true]
    rw [← UniversalSStage1.evalEntries_eq_execution,
      ← UniversalSStage1.evalEntries_eq_execution, evalEntries_succ_local]
    exact congrArg (fun value => value.getD false)
      (lookupAssoc_evalCycle_other_cycle c env horizon
        (Execution.gateOrder c) _ node (by omega))
  · simp [Execution.eval, hgate]

/-- A latency-one register reads its explicit initialization atom at cycle
zero, independently of the later execution horizon. -/
theorem eval_register_zero (c : Circuit) (horizon : Nat) (env : Env)
    (source register : Nat) (hwf : c.WF)
    (hgate : c.gates[register]? =
      some { kind := .reg, inputs := [(source, 1)] })
    (horizon_pos : 0 < horizon) :
    Execution.eval c horizon env { gate := register, cycle := 0 } =
      env (.iniReg register) := by
  induction horizon with
  | zero => omega
  | succ horizon ih =>
      cases horizon with
      | zero =>
          have hregister : register < c.gates.size :=
            (Array.getElem?_eq_some_iff.mp hgate).choose
          simp only [Execution.eval]
          rw [if_pos (by simp [hregister])]
          rw [← UniversalSStage1.evalEntries_eq_execution]
          simp [UniversalSStage1.evalEntries,
            UniversalSStage1.evalCycles, List.range_one, List.foldl_cons,
            List.foldl_nil]
          rw [lookupAssoc_register_zero_after_evalCycle c env register
            (Execution.gateOrder c) [] source hgate
            (gate_mem_gateOrder_local c register hregister)]
          rfl
      | succ horizon =>
          rw [eval_succ_stable_local c (horizon + 1) env
            { gate := register, cycle := 0 } (by
              show 0 < horizon + 1
              omega)]
          exact ih (by omega)

/-- E2 away from the live boundary cycle. -/
theorem eval_boundary_register_off {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (env : Env) (share : Nat) (hshare : share < d)
    (x : List Bool) (hx : x ∈ boolVectors (inputWidth up.g))
    (henv : restrictEnv
        (Execution.relevantSrcs up.g.circuit up.g.horizon) env ∈
      envsForInput up.g x)
    (hinit : env (.iniReg (boundaryRegister up.g share)) = false)
    (cycle : Nat) (hcycle : cycle < H)
    (hoff : cycle ≠ tail.ports.arrivalCycle) :
    Execution.eval (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env
        { gate := boundaryRegister up.g share, cycle := cycle } = false := by
  have hshareTail : share < tail.g.d := by simpa [tail.d_eq] using hshare
  cases cycle with
  | zero =>
      rw [eval_register_zero
        (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env
        (up.g.output share).gate (boundaryRegister up.g share)
        (registeredCompositeCircuit_wf up tail)
        (registeredComposite_boundary_gate up.g tail.ports share hshareTail)]
      · exact hinit
      · simpa [registeredComposite, up.horizon_eq, tail.horizon_eq] using
          hcycle
  | succ previous =>
      rw [UniversalReg.eval_register_succ
        (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env
        (up.g.output share).gate (boundaryRegister up.g share) previous
        (registeredCompositeCircuit_wf up tail)
        (registeredComposite_boundary_gate up.g tail.ports share hshareTail)]
      · rw [eval_restrict_upstream up tail env
          { gate := (up.g.output share).gate, cycle := previous }]
        · apply up.output_pulse share
          · simpa [up.d_eq] using hshare
          · exact hx
          · exact henv
          · simpa [up.horizon_eq] using Nat.lt_of_succ_lt hcycle
          · intro heq
            apply hoff
            rw [heq, up.output_at share hshare]
            exact glue.cycle_align
        · exact pipeline_output_gate_lt up share hshare
      · simpa [registeredComposite, up.horizon_eq, tail.horizon_eq] using
          hcycle

/-! ## Downstream substitution -/

def embeddedDownNode (up tail : GadgetInstance) (node : Node) : Node :=
  { gate := downstreamOffset up tail + node.gate, cycle := node.cycle }

def connectedAtomShare? {g : GadgetInstance} (ports : RegisterPorts g)
    (src : Src) : Option Nat :=
  (List.range g.d).find? fun share =>
    match g.circuit.gates[ports.inputGate share]?, src with
    | some { kind := .inp sharing lane, inputs := _ }, .inp s j _ =>
        sharing == s && lane == j
    | _, _ => false

def substitutedTailEnv (up tail : GadgetInstance)
    (ports : RegisterPorts tail) (env : Env) : Env := fun src =>
  match connectedAtomShare? ports src, src with
  | some share, .inp _ _ cycle =>
      Execution.eval (registeredComposite up ports).circuit
        (registeredComposite up ports).horizon env
        { gate := boundaryRegister up share, cycle := cycle }
  | _, .iniReg gate => env (.iniReg (downstreamOffset up tail + gate))
  | _, _ => env src

private theorem connectedAtomShare?_of_port {H d t : Nat}
    (tail : PipelineGadget H d t) (share : Nat)
    (hshare : share < tail.g.d) :
    connectedAtomShare? tail.ports
        (tail.g.inputArrival tail.ports.downstreamInput share) = some share := by
  obtain ⟨sharing, hgate, harrival⟩ :=
    tail.ports.input_source_coherent share hshare
  rw [harrival]
  cases hfind : connectedAtomShare? tail.ports
      (.inp sharing share tail.ports.arrivalCycle) with
  | none =>
      have hnone := List.find?_eq_none.mp hfind share (by simpa using hshare)
      simp [connectedAtomShare?, hgate] at hnone
  | some other =>
      have hotherMem := List.mem_of_find?_eq_some hfind
      have hother : other < tail.g.d := by
        simpa [connectedAtomShare?] using hotherMem
      obtain ⟨otherSharing, hotherGate, _⟩ :=
        tail.ports.input_source_coherent other hother
      have hmatches := List.find?_some hfind
      simp [connectedAtomShare?, hotherGate] at hmatches
      have : other = share := hmatches.2
      subst other
      rfl

private theorem connectedAtomShare?_of_port_stream {H d t : Nat}
    (tail : PipelineGadget H d t) (share sharing cycle : Nat)
    (hshare : share < tail.g.d)
    (hgate : tail.g.circuit.gates[tail.ports.inputGate share]? =
      some { kind := .inp sharing share, inputs := [] }) :
    connectedAtomShare? tail.ports (.inp sharing share cycle) = some share := by
  cases hfind : connectedAtomShare? tail.ports (.inp sharing share cycle) with
  | none =>
      have hnone := List.find?_eq_none.mp hfind share (by simpa using hshare)
      simp [hgate] at hnone
  | some other =>
      have hotherMem := List.mem_of_find?_eq_some hfind
      have hother : other < tail.g.d := by
        simpa [connectedAtomShare?] using hotherMem
      obtain ⟨otherSharing, hotherGate, _⟩ :=
        tail.ports.input_source_coherent other hother
      have hmatches := List.find?_some hfind
      simp [hotherGate] at hmatches
      have : other = share := hmatches.2
      subst other
      rfl

private theorem connectedAtomShare?_of_unconnected_inp {H d t : Nat}
    (tail : PipelineGadget H d t) (gate sharing lane cycle : Nat)
    (hgate : tail.g.circuit.gates[gate]? =
      some { kind := .inp sharing lane, inputs := [] })
    (hunconnected : connectedShare? tail.ports gate = none) :
    connectedAtomShare? tail.ports (.inp sharing lane cycle) = none := by
  cases hfind : connectedAtomShare? tail.ports (.inp sharing lane cycle) with
  | none => rfl
  | some share =>
      have hshareMem := List.mem_of_find?_eq_some hfind
      have hshare : share < tail.g.d := by
        simpa [connectedAtomShare?] using hshareMem
      obtain ⟨portSharing, hport, _⟩ :=
        tail.ports.input_source_coherent share hshare
      have hmatches := List.find?_some hfind
      simp [connectedAtomShare?, hport] at hmatches
      have hport' : tail.g.circuit.gates[tail.ports.inputGate share]? =
          some { kind := .inp sharing lane, inputs := [] } := by
        simpa [hmatches.1, hmatches.2] using hport
      have hgateEq := pipeline_port_stream_gate_eq tail share gate sharing lane
        [] hshare hport' hgate
      have hnone := (List.find?_eq_none.mp hunconnected) share
        (by simpa using hshare)
      exact (hnone (by simpa [hgateEq])).elim

private theorem inputValue_cons_independent (env : Env)
    (values : List (Node × Bool)) (gate cycle : Nat)
    (input : Nat × Nat) (current : Nat) (value : Bool)
    (hindependent : input.2 ≠ 0 ∨ input.1 ≠ current) :
    UniversalSStage1.inputValue env
        (({ gate := current, cycle := cycle }, value) :: values)
        gate cycle input =
      UniversalSStage1.inputValue env values gate cycle input := by
  rcases input with ⟨source, latency⟩
  simp only [UniversalSStage1.inputValue]
  split
  · rename_i hlatency
    have hnode : ({ gate := source, cycle := cycle - latency } : Node) ≠
        { gate := current, cycle := cycle } := by
      intro heq
      have hsource : source = current := congrArg Node.gate heq
      have hcycle : cycle - latency = cycle := congrArg Node.cycle heq
      have hzero : latency = 0 := by omega
      rcases hindependent with hpositive | hdifferent
      · exact hpositive hzero
      · exact hdifferent hsource
    simp [Execution.lookupAssoc, hnode]
  · rfl

private theorem gateValue_cons_independent (c : Circuit) (env : Env)
    (values : List (Node × Bool)) (cycle gate current : Nat)
    (value : Bool)
    (hindependent : (current, gate) ∉ c.combEdges) :
    UniversalSStage1.gateValue c env
        (({ gate := current, cycle := cycle }, value) :: values)
        cycle gate =
      UniversalSStage1.gateValue c env values cycle gate := by
  cases hentry : c.gates[gate]? with
  | none => simp [UniversalSStage1.gateValue, hentry]
  | some entry =>
      have hinputs : entry.inputs.map (UniversalSStage1.inputValue env
          (({ gate := current, cycle := cycle }, value) :: values)
          gate cycle) =
          entry.inputs.map
            (UniversalSStage1.inputValue env values gate cycle) := by
        apply List.map_congr_left
        intro input hinput
        apply inputValue_cons_independent
        by_cases hlatency : input.2 = 0
        · right
          intro hsource
          apply hindependent
          rw [UniversalSStage1.mem_combEdges_iff]
          exact ⟨entry, hentry, input, hinput, hlatency, hsource⟩
        · exact Or.inl hlatency
      simp only [UniversalSStage1.gateValue, hentry]
      rw [hinputs]

private theorem gateValue_evalCycle_independent (c : Circuit) (env : Env)
    (cycle gate : Nat) (schedule : List Nat) (values : List (Node × Bool))
    (hindependent : ∀ current ∈ schedule, (current, gate) ∉ c.combEdges) :
    UniversalSStage1.gateValue c env
        (UniversalSStage1.evalCycle c env cycle schedule values) cycle gate =
      UniversalSStage1.gateValue c env values cycle gate := by
  induction schedule generalizing values with
  | nil => rfl
  | cons current schedule ih =>
      rw [UniversalSStage1.evalCycle]
      simp only [List.foldl_cons]
      rw [← UniversalSStage1.evalCycle]
      rw [ih]
      · apply gateValue_cons_independent
        exact hindependent current (by simp)
      · intro other hother
        exact hindependent other (by simp [hother])

private theorem lookupAssoc_evalCycle_independent (c : Circuit) (env : Env)
    (cycle gate : Nat) (schedule : List Nat) (values : List (Node × Bool))
    (hnodup : schedule.Nodup) (hgate : gate ∈ schedule)
    (hindependent : ∀ current ∈ schedule, (current, gate) ∉ c.combEdges) :
    Execution.lookupAssoc { gate := gate, cycle := cycle }
        (UniversalSStage1.evalCycle c env cycle schedule values) =
      some (UniversalSStage1.gateValue c env values cycle gate) := by
  induction schedule generalizing values with
  | nil => simp at hgate
  | cons current schedule ih =>
      have hn := List.nodup_cons.mp hnodup
      rw [UniversalSStage1.evalCycle]
      simp only [List.foldl_cons]
      rw [← UniversalSStage1.evalCycle]
      by_cases htail : gate ∈ schedule
      · rw [ih _ hn.2 htail]
        · congr 1
          apply gateValue_cons_independent
          exact hindependent current (by simp)
        · intro other hother
          exact hindependent other (by simp [hother])
      · have hcurrent : current = gate := by
          symm
          simpa [htail] using hgate
        subst current
        rw [lookupAssoc_evalCycle_other_gates c env cycle schedule
          { gate := gate, cycle := cycle } _ htail]
        simp [Execution.lookupAssoc]

private theorem ready_nodup (edges : List (Nat × Nat))
    (remaining : List Nat) (hnodup : remaining.Nodup) :
    (Execution.ready edges remaining).Nodup := by
  exact hnodup.filter _

private theorem ready_gates_independent (edges : List (Nat × Nat))
    (remaining : List Nat) (gate : Nat)
    (hgate : gate ∈ Execution.ready edges remaining) :
    ∀ current ∈ Execution.ready edges remaining,
      (current, gate) ∉ edges := by
  intro current hcurrent hedge
  have hcurrentRemaining : current ∈ remaining :=
    (List.mem_filter.mp hcurrent).1
  have hnoPred : Circuit.hasRemainingPred edges remaining gate = false := by
    have := (List.mem_filter.mp hgate).2
    simpa [Execution.ready] using this
  have hpred : Circuit.hasRemainingPred edges remaining gate = true := by
    simp only [Circuit.hasRemainingPred, List.any_eq_true, Bool.and_eq_true,
      List.contains_iff_mem, beq_iff_eq]
    exact ⟨(current, gate), hedge, hcurrentRemaining, rfl⟩
  rw [hnoPred] at hpred
  contradiction

private theorem lookupAssoc_inp_after_evalCycle
    (c : Circuit) (env : Env) (cycle gate sharing share : Nat)
    (schedule : List Nat) (values : List (Node × Bool))
    (hgate : c.gates[gate]? =
      some { kind := .inp sharing share, inputs := [] })
    (hmem : gate ∈ schedule) :
    Execution.lookupAssoc { gate := gate, cycle := cycle }
        (UniversalSStage1.evalCycle c env cycle schedule values) =
      some (env (.inp sharing share cycle)) := by
  induction schedule generalizing values with
  | nil => simp at hmem
  | cons current schedule ih =>
      rw [UniversalSStage1.evalCycle]
      simp only [List.foldl_cons]
      rw [← UniversalSStage1.evalCycle]
      by_cases htail : gate ∈ schedule
      · exact ih _ htail
      · have hcurrent : current = gate := by
          symm
          simpa [htail] using hmem
        subst current
        rw [lookupAssoc_evalCycle_other_gates c env cycle schedule
          { gate := gate, cycle := cycle } _ htail]
        simp [Execution.lookupAssoc, UniversalSStage1.gateValue, hgate]

private theorem eval_inp_source (c : Circuit) (horizon : Nat) (env : Env)
    (gate sharing share cycle : Nat)
    (hgate : c.gates[gate]? =
      some { kind := .inp sharing share, inputs := [] })
    (hcycle : cycle < horizon) :
    Execution.eval c horizon env { gate := gate, cycle := cycle } =
      env (.inp sharing share cycle) := by
  induction horizon with
  | zero => omega
  | succ horizon ih =>
      by_cases hearlier : cycle < horizon
      · rw [eval_succ_stable_local c horizon env
          { gate := gate, cycle := cycle } hearlier]
        exact ih hearlier
      · have hlast : cycle = horizon := by omega
        subst horizon
        have hgateBound : gate < c.gates.size :=
          (Array.getElem?_eq_some_iff.mp hgate).choose
        simp only [Execution.eval]
        rw [if_pos (by simp [hgateBound])]
        rw [← UniversalSStage1.evalEntries_eq_execution,
          evalEntries_succ_local]
        rw [lookupAssoc_inp_after_evalCycle c env cycle gate sharing share
          (Execution.gateOrder c) _ hgate
          (gate_mem_gateOrder_local c gate hgateBound)]
        rfl

private def embeddedTailNode {down : GadgetInstance} (up : GadgetInstance)
    (ports : RegisterPorts down) (node : Node) : Node :=
  { gate := embeddedTailGate up ports node.gate, cycle := node.cycle }

private def TailTablesAgree {down : GadgetInstance} (up : GadgetInstance)
    (ports : RegisterPorts down) (compositeValues tailValues :
      List (Node × Bool)) : Prop :=
  ∀ node, node.gate < down.circuit.gates.size →
    Execution.lookupAssoc (embeddedTailNode up ports node) compositeValues =
      Execution.lookupAssoc node tailValues

private theorem inputValue_wire_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env)
    (compositeValues tailValues : List (Node × Bool))
    (hagree : TailTablesAgree up.g tail.ports compositeValues tailValues)
    (gate cycle : Nat) (input : Nat × Nat)
    (hsource : input.1 < tail.g.circuit.gates.size) :
    UniversalSStage1.inputValue env compositeValues
        (downstreamOffset up.g tail.g + gate) cycle
        (wireRegisteredEdge (up := up.g) tail.ports input) =
      UniversalSStage1.inputValue
        (substitutedTailEnv up.g tail.g tail.ports env) tailValues
        gate cycle input := by
  rcases input with ⟨source, latency⟩
  cases hconnected : connectedShare? tail.ports source <;>
    simp only [UniversalSStage1.inputValue, wireRegisteredEdge, hconnected,
      Prod.fst, Prod.snd]
  all_goals split
  · simpa [embeddedTailNode, embeddedTailGate, hconnected] using
      congrArg (fun value => value.getD false)
        (hagree { gate := source, cycle := cycle - latency } hsource)
  · simp [embeddedTailNode, embeddedTailGate, hconnected,
      substitutedTailEnv, connectedAtomShare?, downstreamOffset]
  · simpa [embeddedTailNode, embeddedTailGate, hconnected] using
      congrArg (fun value => value.getD false)
        (hagree { gate := source, cycle := cycle - latency } hsource)
  · simp [embeddedTailNode, embeddedTailGate, hconnected,
      substitutedTailEnv, connectedAtomShare?, downstreamOffset]

private theorem registeredComposite_unconnected_gate {H d t : Nat}
    (up tail : PipelineGadget H d t) (gate : Nat)
    (hgate : gate < tail.g.circuit.gates.size)
    (hunconnected : connectedShare? tail.ports gate = none) :
    (registeredCompositeCircuit up.g tail.ports).gates[
        downstreamOffset up.g tail.g + gate]? =
      (tail.g.circuit.gates[gate]?).map
        (wireRegisteredDownGate (up := up.g) tail.ports gate) := by
  rw [registeredCompositeCircuit, UniversalSStage1.appendCircuit,
    Array.getElem?_append_right]
  · have hindex : downstreamOffset up.g tail.g + gate -
        up.g.circuit.gates.size = tail.g.d + gate := by
      simp [downstreamOffset, Nat.add_assoc]
    rw [hindex, Array.getElem?_append_right]
    · simp [boundaryRegisterGates, registeredDownGates,
        Array.getElem?_mapIdx]
    · simp [boundaryRegisterGates]
  · simp [downstreamOffset]
    omega

private theorem gateValue_wire_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env)
    (compositeValues tailValues : List (Node × Bool))
    (hagree : TailTablesAgree up.g tail.ports compositeValues tailValues)
    (cycle gate : Nat) (hgate : gate < tail.g.circuit.gates.size)
    (hunconnected : connectedShare? tail.ports gate = none) :
    UniversalSStage1.gateValue
        (registeredCompositeCircuit up.g tail.ports) env compositeValues cycle
        (downstreamOffset up.g tail.g + gate) =
      UniversalSStage1.gateValue tail.g.circuit
        (substitutedTailEnv up.g tail.g tail.ports env) tailValues cycle gate := by
  cases hentry : tail.g.circuit.gates[gate]? with
  | none =>
      have hcomposite := registeredComposite_unconnected_gate up tail gate
        hgate hunconnected
      rw [hentry] at hcomposite
      simp only [Option.map_none] at hcomposite
      simp [UniversalSStage1.gateValue, hentry, hcomposite]
  | some entry =>
      have hcomposite := registeredComposite_unconnected_gate up tail gate
        hgate hunconnected
      rw [hentry] at hcomposite
      simp only [Option.map_some] at hcomposite
      simp [wireRegisteredDownGate, hunconnected] at hcomposite
      have hgateArity : Circuit.gateArityOk entry = true := by
        have hall := Array.all_eq_true.mp tail.down_cert.1.1.1 gate hgate
        have hentry' : tail.g.circuit.gates[gate] = entry := by
          simpa [hgate] using hentry
        rw [hentry'] at hall
        simp only [Bool.and_eq_true] at hall
        exact hall.1
      have hinputBounds : ∀ input ∈ entry.inputs,
          input.1 < tail.g.circuit.gates.size := by
        intro input hinput
        have hall := Array.all_eq_true.mp tail.down_cert.1.1.1 gate hgate
        have hentry' : tail.g.circuit.gates[gate] = entry := by
          simpa [hgate] using hentry
        rw [hentry'] at hall
        simp only [Bool.and_eq_true] at hall
        have := List.all_eq_true.mp hall.2 input hinput
        simpa using this
      have hinputs : (entry.inputs.map (fun edge =>
          wireRegisteredEdge (up := up.g) tail.ports edge)).map
          (UniversalSStage1.inputValue env compositeValues
            (downstreamOffset up.g tail.g + gate) cycle) =
          entry.inputs.map
            (UniversalSStage1.inputValue
              (substitutedTailEnv up.g tail.g tail.ports env) tailValues
              gate cycle) := by
        rw [List.map_map]
        apply List.map_congr_left
        intro input hinput
        exact inputValue_wire_eq up tail env compositeValues tailValues hagree
          gate cycle input (hinputBounds input hinput)
      simp only [UniversalSStage1.gateValue, hentry, hcomposite]
      change (match entry.kind with
        | .xor => _ | .and => _ | .not => _ | .reg => _ | .mux => _
        | .const b => b | .rnd r => env (.rnd r cycle)
        | .inp sharing share => env (.inp sharing share cycle)
        | .ini source => env (.ini source cycle)
        | .ctl control => env (.ctl control cycle)) = _
      rw [hinputs]
      cases hkind : entry.kind with
      | inp sharing share =>
          have hinputsEmpty : entry.inputs = [] := by
            simpa [Circuit.gateArityOk, hkind] using hgateArity
          have hentryInp : tail.g.circuit.gates[gate]? =
              some { kind := .inp sharing share, inputs := [] } := by
            cases entry with
            | mk kind inputs => simp_all
          have hatom := connectedAtomShare?_of_unconnected_inp tail gate
            sharing share cycle hentryInp hunconnected
          simp [substitutedTailEnv, hatom]
      | rnd | ini | ctl => simp [substitutedTailEnv, connectedAtomShare?]
      | xor | and | not | reg | mux | const => rfl

private theorem ready_tail_membership {H d t : Nat}
    (up tail : PipelineGadget H d t) (remaining : List Nat)
    (gate : Nat) (hgate : gate < tail.g.circuit.gates.size) :
    embeddedTailGate up.g tail.ports gate ∈
        Execution.ready
          (registeredCompositeCircuit up.g tail.ports).combEdges remaining ↔
      gate ∈ Execution.ready tail.g.circuit.combEdges
        (testPullRemaining up.g tail.ports remaining) := by
  have hpull := pipeline_pull_ready up tail remaining
  have hmem := congrArg (fun values => gate ∈ values) hpull
  simpa [testPullRemaining, hgate] using hmem

private theorem evalReady_tablesAgree {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env) (cycle : Nat)
    (remaining : List Nat) (hremaining : remaining.Nodup)
    (compositeValues tailValues : List (Node × Bool))
    (hagree : TailTablesAgree up.g tail.ports compositeValues tailValues)
    (hgateValues : ∀ gate,
      gate ∈ Execution.ready tail.g.circuit.combEdges
          (testPullRemaining up.g tail.ports remaining) →
      UniversalSStage1.gateValue
          (registeredCompositeCircuit up.g tail.ports) env compositeValues cycle
          (embeddedTailGate up.g tail.ports gate) =
        UniversalSStage1.gateValue tail.g.circuit
          (substitutedTailEnv up.g tail.g tail.ports env) tailValues cycle gate) :
    TailTablesAgree up.g tail.ports
      (UniversalSStage1.evalCycle
        (registeredCompositeCircuit up.g tail.ports) env cycle
        (Execution.ready
          (registeredCompositeCircuit up.g tail.ports).combEdges remaining)
        compositeValues)
      (UniversalSStage1.evalCycle tail.g.circuit
        (substitutedTailEnv up.g tail.g tail.ports env) cycle
        (Execution.ready tail.g.circuit.combEdges
          (testPullRemaining up.g tail.ports remaining)) tailValues) := by
  intro node hnode
  let compositeReady := Execution.ready
    (registeredCompositeCircuit up.g tail.ports).combEdges remaining
  let tailRemaining := testPullRemaining up.g tail.ports remaining
  let tailReady := Execution.ready tail.g.circuit.combEdges tailRemaining
  by_cases hcycle : node.cycle = cycle
  · subst cycle
    change Execution.lookupAssoc
        { gate := embeddedTailGate up.g tail.ports node.gate,
          cycle := node.cycle }
        (UniversalSStage1.evalCycle
          (registeredCompositeCircuit up.g tail.ports) env node.cycle
          compositeReady compositeValues) =
      Execution.lookupAssoc node
        (UniversalSStage1.evalCycle tail.g.circuit
          (substitutedTailEnv up.g tail.g tail.ports env) node.cycle
          tailReady tailValues)
    have hmembership : embeddedTailGate up.g tail.ports node.gate ∈
        compositeReady ↔ node.gate ∈ tailReady := by
      exact ready_tail_membership up tail remaining node.gate hnode
    by_cases hready : node.gate ∈ tailReady
    · have hcompositeReady := hmembership.mpr hready
      rw [lookupAssoc_evalCycle_independent
        (registeredCompositeCircuit up.g tail.ports) env node.cycle
        (embeddedTailGate up.g tail.ports node.gate) compositeReady
        compositeValues (ready_nodup _ _ hremaining) hcompositeReady
        (ready_gates_independent _ _ _ hcompositeReady)]
      rw [lookupAssoc_evalCycle_independent tail.g.circuit
        (substitutedTailEnv up.g tail.g tail.ports env) node.cycle node.gate
        tailReady tailValues
        (ready_nodup _ _ (List.nodup_range.filter _)) hready
        (ready_gates_independent _ _ _ hready)]
      exact congrArg some (hgateValues node.gate hready)
    · have hcompositeReady : embeddedTailGate up.g tail.ports node.gate ∉
          compositeReady := by simpa [hmembership] using hready
      rw [lookupAssoc_evalCycle_other_gates
        (registeredCompositeCircuit up.g tail.ports) env node.cycle
        compositeReady
        { gate := embeddedTailGate up.g tail.ports node.gate,
          cycle := node.cycle }
        compositeValues (by simpa [embeddedTailNode] using hcompositeReady)]
      rw [lookupAssoc_evalCycle_other_gates tail.g.circuit
        (substitutedTailEnv up.g tail.g tail.ports env) node.cycle
        tailReady node tailValues hready]
      simpa [embeddedTailNode] using hagree node hnode
  · rw [lookupAssoc_evalCycle_other_cycle
        (registeredCompositeCircuit up.g tail.ports) env cycle
        compositeReady compositeValues (embeddedTailNode up.g tail.ports node)
        (by simpa [embeddedTailNode] using hcycle)]
    rw [lookupAssoc_evalCycle_other_cycle tail.g.circuit
      (substitutedTailEnv up.g tail.g tail.ports env) cycle tailReady tailValues
      node hcycle]
    exact hagree node hnode

private theorem pipeline_pull_topo_step {H d t : Nat}
    (up tail : PipelineGadget H d t) (remaining : List Nat) :
    testPullRemaining up.g tail.ports
        (remaining.filter fun gate =>
          !(Execution.ready
            (registeredCompositeCircuit up.g tail.ports).combEdges remaining).contains gate) =
      (testPullRemaining up.g tail.ports remaining).filter fun gate =>
        !(Execution.ready tail.g.circuit.combEdges
          (testPullRemaining up.g tail.ports remaining)).contains gate := by
  rw [UniversalSStage1.filter_not_ready_eq_kahnStep]
  rw [pipeline_pull_kahnStep up tail]
  rw [UniversalSStage1.filter_not_ready_eq_kahnStep]

private theorem connected_mem_ready {H d t : Nat}
    (tail : PipelineGadget H d t) (remaining : List Nat) (gate share : Nat)
    (hconnected : connectedShare? tail.ports gate = some share)
    (hmem : gate ∈ remaining) :
    gate ∈ Execution.ready tail.g.circuit.combEdges remaining := by
  unfold Execution.ready
  rw [List.mem_filter]
  refine ⟨hmem, ?_⟩
  have hnoPred : Circuit.hasRemainingPred tail.g.circuit.combEdges
      remaining gate = false := by
    rw [Bool.eq_false_iff]
    intro hpred
    simp only [Circuit.hasRemainingPred, List.any_eq_true, Bool.and_eq_true,
      List.contains_iff_mem, beq_iff_eq] at hpred
    rcases hpred with ⟨edge, hedge, _hsource, htarget⟩
    have hnone := pipeline_connectedShare_none_of_combEdge_dst tail edge hedge
    rw [htarget, hconnected] at hnone
    contradiction
  simp [Execution.ready, hnoPred]

private theorem evalTopoLoop_no_connected_tablesAgree {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env) (cycle fuel : Nat)
    (remaining : List Nat) (hremaining : remaining.Nodup)
    (hnoConnected : ∀ gate,
      gate ∈ testPullRemaining up.g tail.ports remaining →
        connectedShare? tail.ports gate = none)
    (compositeValues tailValues : List (Node × Bool))
    (hagree : TailTablesAgree up.g tail.ports compositeValues tailValues) :
    TailTablesAgree up.g tail.ports
      (UniversalSStage1.evalCycle
        (registeredCompositeCircuit up.g tail.ports) env cycle
        (Execution.topoLoop
          (registeredCompositeCircuit up.g tail.ports).combEdges fuel remaining)
        compositeValues)
      (UniversalSStage1.evalCycle tail.g.circuit
        (substitutedTailEnv up.g tail.g tail.ports env) cycle
        (Execution.topoLoop tail.g.circuit.combEdges fuel
          (testPullRemaining up.g tail.ports remaining)) tailValues) := by
  induction fuel generalizing remaining compositeValues tailValues with
  | zero => exact hagree
  | succ fuel ih =>
      let compositeReady := Execution.ready
        (registeredCompositeCircuit up.g tail.ports).combEdges remaining
      let nextRemaining := remaining.filter fun gate =>
        !compositeReady.contains gate
      let tailRemaining := testPullRemaining up.g tail.ports remaining
      let tailReady := Execution.ready tail.g.circuit.combEdges tailRemaining
      have hlayer : TailTablesAgree up.g tail.ports
          (UniversalSStage1.evalCycle
            (registeredCompositeCircuit up.g tail.ports) env cycle
            compositeReady compositeValues)
          (UniversalSStage1.evalCycle tail.g.circuit
            (substitutedTailEnv up.g tail.g tail.ports env) cycle
            tailReady tailValues) := by
        apply evalReady_tablesAgree up tail env cycle remaining hremaining
          compositeValues tailValues hagree
        intro gate hready
        have hmem : gate ∈ tailRemaining := (List.mem_filter.mp hready).1
        have hbound : gate < tail.g.circuit.gates.size := by
          dsimp [tailRemaining, testPullRemaining] at hmem
          have := (List.mem_filter.mp hmem).1
          simpa using this
        have hnone := hnoConnected gate hmem
        simpa [embeddedTailGate, hnone] using
          gateValue_wire_eq up tail env compositeValues tailValues hagree
            cycle gate hbound hnone
      have hpullNext : testPullRemaining up.g tail.ports nextRemaining =
          tailRemaining.filter fun gate => !tailReady.contains gate := by
        simpa [nextRemaining, compositeReady, tailRemaining, tailReady] using
          pipeline_pull_topo_step up tail remaining
      have hnextNoConnected : ∀ gate,
          gate ∈ testPullRemaining up.g tail.ports nextRemaining →
            connectedShare? tail.ports gate = none := by
        intro gate hgate
        rw [hpullNext] at hgate
        exact hnoConnected gate (List.mem_filter.mp hgate).1
      have hnextNodup : nextRemaining.Nodup := hremaining.filter _
      have hrest := ih nextRemaining hnextNodup hnextNoConnected
        (UniversalSStage1.evalCycle
          (registeredCompositeCircuit up.g tail.ports) env cycle
          compositeReady compositeValues)
        (UniversalSStage1.evalCycle tail.g.circuit
          (substitutedTailEnv up.g tail.g tail.ports env) cycle
          tailReady tailValues) hlayer
      rw [hpullNext] at hrest
      simpa [Execution.topoLoop, UniversalSStage1.evalCycle,
        List.foldl_append, compositeReady, nextRemaining, tailRemaining,
        tailReady, hpullNext] using hrest

private theorem eval_extend_stable (c : Circuit) (small extra : Nat)
    (env : Env) (node : Node) (hcycle : node.cycle < small) :
    Execution.eval c (small + extra) env node =
      Execution.eval c small env node := by
  induction extra with
  | zero => simp
  | succ extra ih =>
      rw [Nat.add_succ]
      rw [eval_succ_stable_local c (small + extra) env node (by omega)]
      exact ih

private theorem boundary_gateValue_eq_eval {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env) (cycle share : Nat)
    (hcycle : cycle < H) (hshare : share < tail.g.d) :
    UniversalSStage1.gateValue
        (registeredCompositeCircuit up.g tail.ports) env
        (UniversalSStage1.evalEntries
          (registeredCompositeCircuit up.g tail.ports) cycle env)
        cycle (boundaryRegister up.g share) =
      Execution.eval (registeredCompositeCircuit up.g tail.ports) H env
        { gate := boundaryRegister up.g share, cycle := cycle } := by
  let c := registeredCompositeCircuit up.g tail.ports
  have hwf : c.WF := registeredCompositeCircuit_wf up tail
  have hgate := registeredComposite_boundary_gate up.g tail.ports share hshare
  have hbound : boundaryRegister up.g share < c.gates.size :=
    (Array.getElem?_eq_some_iff.mp hgate).choose
  have hindependent : ∀ current ∈ Execution.gateOrder c,
      (current, boundaryRegister up.g share) ∉ c.combEdges := by
    intro current _hcurrent hedge
    rw [UniversalSStage1.mem_combEdges_iff] at hedge
    rcases hedge with ⟨entry, hentry, input, hinput, hzero, _⟩
    rw [hgate] at hentry
    cases hentry
    simp at hinput
    subst input
    simp at hzero
  have hsmall : Execution.eval c (cycle + 1) env
      { gate := boundaryRegister up.g share, cycle := cycle } =
      UniversalSStage1.gateValue c env
        (UniversalSStage1.evalEntries c cycle env) cycle
        (boundaryRegister up.g share) := by
    simp only [Execution.eval]
    rw [if_pos (by simp [hbound])]
    rw [← UniversalSStage1.evalEntries_eq_execution,
      evalEntries_succ_local]
    rw [lookupAssoc_evalCycle_independent c env cycle
      (boundaryRegister up.g share) (Execution.gateOrder c)
      (UniversalSStage1.evalEntries c cycle env)
      (gateOrder_nodup_of_wf c hwf)
      (gate_mem_gateOrder_local c _ hbound) hindependent]
    rfl
  have hextend := eval_extend_stable c (cycle + 1)
    (H - (cycle + 1)) env
    { gate := boundaryRegister up.g share, cycle := cycle } (by simp)
  have hsum : cycle + 1 + (H - (cycle + 1)) = H := by omega
  rw [hsum] at hextend
  exact hsmall.symm.trans hextend.symm

set_option maxHeartbeats 1000000 in
private theorem evalFullSchedule_tablesAgree_cycle {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env) (cycle : Nat)
    (hcycle : cycle < H)
    (compositeValues tailValues : List (Node × Bool))
    (hagree : TailTablesAgree up.g tail.ports compositeValues tailValues)
    (hcompositeValues : compositeValues =
      UniversalSStage1.evalEntries
        (registeredCompositeCircuit up.g tail.ports) cycle env) :
    TailTablesAgree up.g tail.ports
      (UniversalSStage1.evalCycle
        (registeredCompositeCircuit up.g tail.ports) env cycle
        (Execution.gateOrder
          (registeredCompositeCircuit up.g tail.ports)) compositeValues)
      (UniversalSStage1.evalCycle tail.g.circuit
        (substitutedTailEnv up.g tail.g tail.ports env) cycle
        (Execution.gateOrder tail.g.circuit) tailValues) := by
  let c := registeredCompositeCircuit up.g tail.ports
  let remaining := List.range c.gates.size
  let compositeReady := Execution.ready c.combEdges remaining
  let tailRemaining := testPullRemaining up.g tail.ports remaining
  let tailReady := Execution.ready tail.g.circuit.combEdges tailRemaining
  let nextRemaining := remaining.filter fun gate => !compositeReady.contains gate
  have hcwf : c.WF := registeredCompositeCircuit_wf up tail
  have htwf : tail.g.circuit.WF := tail.down_cert.1.1
  have hsizePos : 0 < c.gates.size := by
    have hd : 0 < tail.g.d := by
      have : t < tail.g.d := by simpa [tail.d_eq] using tail.order_lt
      omega
    simp [c, registeredCompositeCircuit, UniversalSStage1.appendCircuit,
      boundaryRegisterGates]
    omega
  have hpull : tailRemaining = List.range tail.g.circuit.gates.size := by
    simpa [tailRemaining, remaining, c] using pipeline_pull_range up tail
  have hlayer : TailTablesAgree up.g tail.ports
      (UniversalSStage1.evalCycle c env cycle compositeReady compositeValues)
      (UniversalSStage1.evalCycle tail.g.circuit
        (substitutedTailEnv up.g tail.g tail.ports env) cycle tailReady
        tailValues) := by
    apply evalReady_tablesAgree up tail env cycle remaining
      List.nodup_range compositeValues tailValues hagree
    intro gate hready
    have hmem : gate ∈ tailRemaining := (List.mem_filter.mp hready).1
    have hbound : gate < tail.g.circuit.gates.size := by
      rw [hpull] at hmem
      simpa using hmem
    cases hconnected : connectedShare? tail.ports gate with
    | none =>
        simpa [c, embeddedTailGate, hconnected] using
          gateValue_wire_eq up tail env compositeValues tailValues hagree
            cycle gate hbound hconnected
    | some share =>
        have hshareMem := List.mem_of_find?_eq_some hconnected
        have hshare : share < tail.g.d := by
          simpa [connectedShare?] using hshareMem
        have hgateEq : tail.ports.inputGate share = gate := by
          have := List.find?_some hconnected
          simpa [connectedShare?] using this
        obtain ⟨sharing, hportOriginal, _⟩ :=
          tail.ports.input_source_coherent share hshare
        have hport := hportOriginal
        rw [hgateEq] at hport
        have hatom := connectedAtomShare?_of_port_stream tail share sharing
          cycle hshare hportOriginal
        rw [embeddedTailGate]
        simp only [hconnected]
        rw [hcompositeValues]
        rw [boundary_gateValue_eq_eval up tail env cycle share hcycle hshare]
        simp [UniversalSStage1.gateValue, hport, substitutedTailEnv, hatom,
          registeredComposite, up.horizon_eq, tail.horizon_eq]
  have hpullNext : testPullRemaining up.g tail.ports nextRemaining =
      tailRemaining.filter fun gate => !tailReady.contains gate := by
    simpa [nextRemaining, compositeReady, tailRemaining, tailReady, c,
      remaining] using pipeline_pull_topo_step up tail remaining
  have hnextNoConnected : ∀ gate,
      gate ∈ testPullRemaining up.g tail.ports nextRemaining →
        connectedShare? tail.ports gate = none := by
    intro gate hgate
    rw [hpullNext] at hgate
    by_cases hconnected : connectedShare? tail.ports gate = none
    · exact hconnected
    · cases hsome : connectedShare? tail.ports gate with
      | none => contradiction
      | some share =>
          have hready := connected_mem_ready tail tailRemaining gate share hsome
            (List.mem_filter.mp hgate).1
          have hnot : gate ∉ tailReady := by
            simpa using (List.mem_filter.mp hgate).2
          exact (hnot (by simpa [tailReady] using hready)).elim
  have hrest := evalTopoLoop_no_connected_tablesAgree up tail env cycle
    (c.gates.size - 1) nextRemaining (List.nodup_range.filter _)
    hnextNoConnected
    (UniversalSStage1.evalCycle c env cycle compositeReady compositeValues)
    (UniversalSStage1.evalCycle tail.g.circuit
      (substitutedTailEnv up.g tail.g tail.ports env) cycle tailReady tailValues)
    hlayer
  rw [hpullNext] at hrest
  rw [gateOrder_eq_topoLoop_of_wf c hcwf,
    gateOrder_eq_topoLoop_of_wf tail.g.circuit htwf]
  have htailFuel : Execution.topoLoop tail.g.circuit.combEdges c.gates.size
      (List.range tail.g.circuit.gates.size) =
      Execution.topoLoop tail.g.circuit.combEdges tail.g.circuit.gates.size
        (List.range tail.g.circuit.gates.size) := by
    have hle : tail.g.circuit.gates.size ≤ c.gates.size := by
      simp [c, registeredCompositeCircuit, UniversalSStage1.appendCircuit,
        boundaryRegisterGates, registeredDownGates]
      omega
    have hsum : tail.g.circuit.gates.size +
        (c.gates.size - tail.g.circuit.gates.size) = c.gates.size :=
      Nat.add_sub_of_le hle
    rw [← hsum]
    exact UniversalSStage1.topoLoop_extra_fuel_of_acyclic tail.g.circuit
      (c.gates.size - tail.g.circuit.gates.size) htwf.2
  have hcompositeStep :
      Execution.topoLoop c.combEdges c.gates.size
          (List.range c.gates.size) =
        compositeReady ++ Execution.topoLoop c.combEdges (c.gates.size - 1)
          nextRemaining := by
    dsimp [compositeReady, nextRemaining, remaining]
    obtain ⟨fuel, hfuel⟩ := Nat.exists_eq_succ_of_ne_zero (by omega : c.gates.size ≠ 0)
    rw [hfuel]
    simp [Execution.topoLoop]
  have htailStep :
      Execution.topoLoop tail.g.circuit.combEdges c.gates.size
          (List.range tail.g.circuit.gates.size) =
        tailReady ++ Execution.topoLoop tail.g.circuit.combEdges
          (c.gates.size - 1)
          (tailRemaining.filter fun gate => !tailReady.contains gate) := by
    dsimp [tailReady]
    rw [hpull]
    obtain ⟨fuel, hfuel⟩ := Nat.exists_eq_succ_of_ne_zero (by omega : c.gates.size ≠ 0)
    rw [hfuel]
    simp [Execution.topoLoop]
  rw [hcompositeStep, ← htailFuel, htailStep]
  simpa [UniversalSStage1.evalCycle, List.foldl_append,
    c, remaining, compositeReady, tailRemaining, tailReady, nextRemaining,
    hpull, hpullNext] using hrest

private theorem evalEntries_tail_tablesAgree {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env) :
    ∀ horizon, horizon ≤ H →
      TailTablesAgree up.g tail.ports
        (UniversalSStage1.evalEntries
          (registeredCompositeCircuit up.g tail.ports) horizon env)
        (UniversalSStage1.evalEntries tail.g.circuit horizon
          (substitutedTailEnv up.g tail.g tail.ports env)) := by
  intro horizon
  induction horizon with
  | zero =>
      intro _
      intro node _
      rfl
  | succ horizon ih =>
      intro hle
      rw [evalEntries_succ_local, evalEntries_succ_local]
      apply evalFullSchedule_tablesAgree_cycle up tail env horizon (by omega)
        (UniversalSStage1.evalEntries
          (registeredCompositeCircuit up.g tail.ports) horizon env)
        (UniversalSStage1.evalEntries tail.g.circuit horizon
          (substitutedTailEnv up.g tail.g tail.ports env))
        (ih (by omega)) rfl

/-- E3: every surviving copied tail node is the isolated-tail evaluation
under the exact boundary-source substitution and shifted reset environment. -/
theorem eval_substitute_downstream {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env) (node : Node)
    (hnode : node.gate < tail.g.circuit.gates.size)
    (hsurvives : connectedShare? tail.ports node.gate = none) :
    Execution.eval (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env
        (embeddedDownNode up.g tail.g node) =
      Execution.eval tail.g.circuit tail.g.horizon
        (substitutedTailEnv up.g tail.g tail.ports env) node := by
  change Execution.eval (registeredCompositeCircuit up.g tail.ports)
      (max up.g.horizon tail.g.horizon) env
      (embeddedDownNode up.g tail.g node) =
    Execution.eval tail.g.circuit tail.g.horizon
      (substitutedTailEnv up.g tail.g tail.ports env) node
  rw [up.horizon_eq, tail.horizon_eq, Nat.max_self]
  have hcompositeGate : (embeddedDownNode up.g tail.g node).gate <
      (registeredCompositeCircuit up.g tail.ports).gates.size := by
    simpa [embeddedDownNode, registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, boundaryRegisterGates,
      registeredDownGates, downstreamOffset, Nat.add_assoc] using
      Nat.add_lt_add_left hnode (downstreamOffset up.g tail.g)
  by_cases hcycle : node.cycle < H
  · rw [Execution.eval, if_pos (by
      simp only [Bool.and_eq_true, decide_eq_true_eq]
      exact ⟨hcompositeGate, by simpa [embeddedDownNode] using hcycle⟩)]
    rw [Execution.eval, if_pos (by simp [hnode, hcycle])]
    rw [← UniversalSStage1.evalEntries_eq_execution,
      ← UniversalSStage1.evalEntries_eq_execution]
    have hagree := evalEntries_tail_tablesAgree up tail env H (Nat.le_refl H)
    have hlookup := hagree node hnode
    simpa [embeddedDownNode, embeddedTailNode, embeddedTailGate, hsurvives] using
      congrArg (fun value => value.getD false) hlookup
  · simp [Execution.eval, embeddedDownNode, hcycle]

private theorem map_env_mem_assignments (sources : List Src) (env : Env) :
    sources.map (fun src => (src, env src)) ∈ Execution.assignments sources := by
  induction sources with
  | nil => simp [Execution.assignments]
  | cons src sources ih =>
      cases hbit : env src <;>
        simp [Execution.assignments, ih, hbit]

private theorem lookupAssoc_map_env (sources : List Src) (env : Env)
    (hnodup : sources.Nodup) (src : Src) :
    Execution.lookupAssoc src (sources.map fun key => (key, env key)) =
      if src ∈ sources then some (env src) else none := by
  induction sources with
  | nil => simp [Execution.lookupAssoc]
  | cons key sources ih =>
      have hn := List.nodup_cons.mp hnodup
      by_cases heq : src = key
      · subst key
        simp [Execution.lookupAssoc]
      · simp [Execution.lookupAssoc, heq, ih hn.2]

private theorem envFrom_map_env_eq_restrict (sources : List Src) (env : Env)
    (hnodup : sources.Nodup) :
    Execution.envFrom (sources.map fun src => (src, env src)) =
      restrictEnv sources env := by
  funext src
  rw [Execution.envFrom]
  rw [lookupAssoc_map_env sources env hnodup src]
  by_cases hmem : src ∈ sources <;>
    simp [restrictEnv, List.contains_iff_mem, hmem]

private theorem restrictEnv_mem_envsOf_of_matches (c : Circuit)
    (horizon : Nat) (fixing : List (Src × Bool)) (env : Env)
    (hmatches : fixing.all fun entry =>
      restrictEnv (Execution.relevantSrcs c horizon) env entry.1 == entry.2) :
    restrictEnv (Execution.relevantSrcs c horizon) env ∈
      Execution.envsOf c horizon fixing := by
  rw [Execution.envsOf_eq_filtered]
  unfold Execution.envsOfFiltered
  rw [List.mem_filter]
  refine ⟨?_, ?_⟩
  · rw [List.mem_map]
    refine ⟨(Execution.relevantSrcs c horizon).map
      (fun src => (src, env src)), map_env_mem_assignments _ env, ?_⟩
    exact envFrom_map_env_eq_restrict _ env (Execution.eraseDups_nodup _)
  · exact hmatches

private theorem mem_envsOf_matches (c : Circuit) (horizon : Nat)
    (fixing : List (Src × Bool)) (env : Env)
    (henv : env ∈ Execution.envsOf c horizon fixing) :
    fixing.all fun entry => env entry.1 == entry.2 := by
  rw [Execution.envsOf_eq_filtered] at henv
  exact (List.mem_filter.mp henv).2

private theorem env_value_of_fixing_mem (c : Circuit) (horizon : Nat)
    (fixing : List (Src × Bool)) (env : Env) (src : Src) (value : Bool)
    (henv : env ∈ Execution.envsOf c horizon fixing)
    (hfixing : (src, value) ∈ fixing) : env src = value := by
  have hall := List.all_eq_true.mp (mem_envsOf_matches c horizon fixing env henv)
  have heq := hall (src, value) hfixing
  simpa using heq

def interfaceValuation (g : GadgetInstance) (env : Env) : List Bool :=
  (List.range g.inputCount).flatMap fun input =>
    (List.range g.d).map fun share => env (g.inputArrival input share)

private theorem blockAt_flatMap_range (d count : Nat)
    (blocks : Nat → List Bool)
    (hlen : ∀ index, index < count → (blocks index).length = d) :
    ∀ index, index < count →
      blockAt d ((List.range count).flatMap blocks) index = blocks index := by
  induction count generalizing blocks with
  | zero => intro index hindex; omega
  | succ count ih =>
      intro index hindex
      rw [List.range_succ_eq_map]
      simp only [List.flatMap_cons, List.flatMap_map]
      cases index with
      | zero =>
          exact blockAt_append_zero d (blocks 0)
            ((List.range count).flatMap fun index => blocks (index + 1))
            (hlen 0 (by omega))
      | succ index =>
          rw [blockAt_append_succ d (blocks 0)
            ((List.range count).flatMap fun index => blocks (index + 1))
            (hlen 0 (by omega)) index]
          apply ih (fun offset => blocks (offset + 1))
          · intro offset hoffset
            exact hlen (offset + 1) (by omega)
          · omega

private theorem interfaceValuation_inputBit (g : GadgetInstance) (env : Env)
    (input share : Nat) (hinput : input < g.inputCount)
    (hshare : share < g.d) :
    inputBit g (interfaceValuation g env) input share =
      env (g.inputArrival input share) := by
  have hblock := blockAt_flatMap_range g.d g.inputCount
    (fun input => (List.range g.d).map fun share =>
      env (g.inputArrival input share)) (by simp) input hinput
  rw [inputBit, inputPosition]
  rw [← blockAt_getD g.d (interfaceValuation g env) input share hshare]
  change (blockAt g.d
    ((List.range g.inputCount).flatMap fun input =>
      (List.range g.d).map fun share => env (g.inputArrival input share))
    input).getD share false = _
  rw [hblock]
  simp [hshare]

private theorem interfaceValuation_length (g : GadgetInstance) (env : Env) :
    (interfaceValuation g env).length = inputWidth g := by
  simp only [interfaceValuation, List.length_flatMap, List.length_map,
    List.length_range, inputWidth]
  generalize g.inputCount = count
  induction count with
  | zero => simp
  | succ count ih =>
      simp only [List.range_succ_eq_map, List.map_cons, List.map_map,
        List.sum_cons, Function.comp_apply]
      change g.d + (List.map (fun _ : Nat => g.d) (List.range count)).sum = _
      rw [ih]
      rw [Nat.succ_mul]
      omega

private theorem arrivalValue_interfaceValuation {H d t : Nat}
    (P : PipelineGadget H d t) (env : Env) (input share : Nat)
    (hinput : input < P.g.inputCount) (hshare : share < P.g.d) :
    arrivalValue? P.g (interfaceValuation P.g env)
        (P.g.inputArrival input share) =
      some (env (P.g.inputArrival input share)) := by
  unfold arrivalValue?
  have hpairs :
      (List.range P.g.inputCount).flatMap (fun sharing =>
        (List.range P.g.d).map fun lane =>
          (P.g.inputArrival sharing lane,
            inputBit P.g (interfaceValuation P.g env) sharing lane)) =
      (interfaceAtoms P.g).map fun src => (src, env src) := by
    unfold interfaceAtoms
    rw [List.map_flatMap]
    simp only [List.map_map, Function.comp_apply]
    apply congrArg List.flatten
    apply List.map_congr_left
    intro sharing hsharing
    apply List.map_congr_left
    intro lane hlane
    simp only [Function.comp_apply]
    rw [interfaceValuation_inputBit P.g env sharing lane
      (by simpa using hsharing) (by simpa using hlane)]
  rw [hpairs]
  rw [lookupAssoc_map_env (interfaceAtoms P.g) env P.interface_injective]
  rw [if_pos (by
    simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
    exact ⟨input, hinput, share, hshare, rfl⟩)]

private theorem arrivalValue_interfaceValuation_all {H d t : Nat}
    (P : PipelineGadget H d t) (env : Env) (src : Src) :
    arrivalValue? P.g (interfaceValuation P.g env) src =
      if src ∈ interfaceAtoms P.g then some (env src) else none := by
  unfold arrivalValue?
  have hpairs :
      (List.range P.g.inputCount).flatMap (fun sharing =>
        (List.range P.g.d).map fun lane =>
          (P.g.inputArrival sharing lane,
            inputBit P.g (interfaceValuation P.g env) sharing lane)) =
      (interfaceAtoms P.g).map fun source => (source, env source) := by
    unfold interfaceAtoms
    rw [List.map_flatMap]
    simp only [List.map_map, Function.comp_apply]
    apply congrArg List.flatten
    apply List.map_congr_left
    intro sharing hsharing
    apply List.map_congr_left
    intro lane hlane
    simp only [Function.comp_apply]
    rw [interfaceValuation_inputBit P.g env sharing lane
      (by simpa using hsharing) (by simpa using hlane)]
  rw [hpairs]
  exact lookupAssoc_map_env (interfaceAtoms P.g) env P.interface_injective src

private theorem canonical_matches_fixingForInput {H d t : Nat}
    (P : PipelineGadget H d t) (env : Env)
    (hpublic : ∀ src value,
      Execution.lookupAssoc src P.g.publicFixing = some value →
        env src = value)
    (hdefault : ∀ src,
      src ∈ Execution.relevantSrcs P.g.circuit P.g.horizon →
      src ∉ interfaceAtoms P.g →
      Execution.lookupAssoc src P.g.publicFixing = none →
      src ∉ P.g.randomness → env src = false) :
    (fixingForInput P.g (interfaceValuation P.g env)).all fun entry =>
      restrictEnv (Execution.relevantSrcs P.g.circuit P.g.horizon) env
        entry.1 == entry.2 := by
  apply List.all_eq_true.mpr
  intro entry hentry
  unfold fixingForInput at hentry
  rw [List.mem_filterMap] at hentry
  rcases hentry with ⟨src, hsrc, hentry⟩
  rw [arrivalValue_interfaceValuation_all P env src] at hentry
  by_cases hinterface : src ∈ interfaceAtoms P.g
  · simp [hinterface] at hentry
    subst entry
    simp [restrictEnv, hsrc]
  · simp only [hinterface, if_neg] at hentry
    cases hlookup : Execution.lookupAssoc src P.g.publicFixing with
    | some value =>
        simp [hlookup] at hentry
        subst entry
        simp [restrictEnv, hsrc, hpublic src value hlookup]
    | none =>
        simp only [hlookup] at hentry
        by_cases hrandom : src ∈ P.g.randomness
        · simp [List.contains_iff_mem, hrandom] at hentry
        · simp [List.contains_iff_mem, hrandom] at hentry
          subst entry
          have hfalse := hdefault src hsrc hinterface hlookup hrandom
          simp [restrictEnv, hsrc, hfalse]

private theorem sourceDomainsDisjoint_not_mem
    (left right : List Src) (hdisjoint : SourceDomainsDisjoint left right)
    (src : Src) (hleft : src ∈ left) : src ∉ right := by
  unfold SourceDomainsDisjoint at hdisjoint
  have h := List.all_eq_true.mp hdisjoint src hleft
  simpa [List.contains_iff_mem] using h

private theorem arrivalValue_none_of_not_mem_interface
    (g : GadgetInstance) (x : List Bool) (src : Src)
    (hnot : src ∉ interfaceAtoms g) : arrivalValue? g x src = none := by
  cases hvalue : arrivalValue? g x src with
  | none => rfl
  | some value =>
      have hisSome : (arrivalValue? g x src).isSome = true := by
        simp [hvalue]
      rw [arrivalValue_isSome] at hisSome
      simp [List.contains_iff_mem, interfaceAtoms] at hisSome
      rcases hisSome with ⟨input, hinput, share, hshare, heq⟩
      apply (hnot ?_).elim
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨input, hinput, share, hshare, heq⟩

private theorem pipeline_public_relevant {H d t : Nat}
    (P : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ publicAtoms P.g) :
    src ∈ Execution.relevantSrcs P.g.circuit P.g.horizon := by
  have hall := List.all_eq_true.mp P.port_source_exclusive.1 src hsrc
  simpa [List.contains_iff_mem] using hall

private theorem pipeline_public_not_interface {H d t : Nat}
    (P : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ publicAtoms P.g) : src ∉ interfaceAtoms P.g := by
  intro hinterface
  exact sourceDomainsDisjoint_not_mem _ _ P.source_partition.2.2.2.1
    src hinterface hsrc

private theorem pipeline_public_not_random {H d t : Nat}
    (P : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ publicAtoms P.g) : src ∉ P.g.randomness := by
  intro hrandom
  exact sourceDomainsDisjoint_not_mem _ _ P.source_partition.2.2.2.2.1
    src hrandom hsrc

/-- E5, component direction: an enumerated environment is unchanged on its
finite support and can be re-indexed by the interface values it actually
carries.  `SourcePartition` makes the four fixing clauses disjoint, so the
re-indexing is literal rather than merely distributional. -/
theorem restrictEnv_mem_envsForInput_interfaceValuation {H d t : Nat}
    (P : PipelineGadget H d t) (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput P.g x) :
    restrictEnv (Execution.relevantSrcs P.g.circuit P.g.horizon) env ∈
      envsForInput P.g (interfaceValuation P.g env) := by
  apply restrictEnv_mem_envsOf_of_matches
  apply canonical_matches_fixingForInput P env
  · intro src value hlookup
    have hpair := Execution.lookupAssoc_some_mem src P.g.publicFixing value hlookup
    have hpublic : src ∈ publicAtoms P.g := by
      exact List.mem_map.mpr ⟨(src, value), hpair, rfl⟩
    have hrelevant := pipeline_public_relevant P src hpublic
    have hnotInterface := pipeline_public_not_interface P src hpublic
    have hnotRandom := pipeline_public_not_random P src hpublic
    have harrival := arrivalValue_none_of_not_mem_interface P.g x src hnotInterface
    have hfixing : (src, value) ∈ fixingForInput P.g x := by
      unfold fixingForInput
      rw [List.mem_filterMap]
      exact ⟨src, hrelevant, by simp [harrival, hlookup]⟩
    exact env_value_of_fixing_mem P.g.circuit P.g.horizon
      (fixingForInput P.g x) env src value henv hfixing
  · intro src hrelevant hnotInterface hlookup hnotRandom
    have harrival := arrivalValue_none_of_not_mem_interface P.g x src hnotInterface
    have hfixing : (src, false) ∈ fixingForInput P.g x := by
      unfold fixingForInput
      rw [List.mem_filterMap]
      exact ⟨src, hrelevant, by
        simp [harrival, hlookup, List.contains_iff_mem, hnotRandom]⟩
    exact env_value_of_fixing_mem P.g.circuit P.g.horizon
      (fixingForInput P.g x) env src false henv hfixing

private theorem unhideRegisteredInput_lt (hidden external count : Nat)
    (hhidden : hidden < count) (hexternal : external < count - 1) :
    unhideRegisteredInput hidden external < count := by
  unfold unhideRegisteredInput
  split <;> omega

private theorem unhideRegisteredInput_ne (hidden external : Nat) :
    unhideRegisteredInput hidden external ≠ hidden := by
  unfold unhideRegisteredInput
  split <;> omega

private theorem iniReg_mem_relevant_gate_lt (c : Circuit) (horizon gate : Nat)
    (hmem : (.iniReg gate : Src) ∈
      Execution.relevantSrcs c horizon) : gate < c.gates.size := by
  rw [UniversalSStage1.relevantSrcs_eq_public, List.mem_eraseDups,
    List.mem_flatMap] at hmem
  rcases hmem with ⟨⟨entry, index⟩, hindexed, hsource⟩
  rw [List.mem_append] at hsource
  rcases hsource with hgateSource | hboundary
  · cases hkind : entry.kind <;>
      simp [UniversalSStage1.publicGateSrcs, hkind] at hgateSource
  · simp only [UniversalSStage1.publicBoundarySrcs, List.mem_flatMap,
      List.mem_map] at hboundary
    rcases hboundary with ⟨cycle, _hcycle, input, _hinput, heq⟩
    have hentry : c.gates.toList[index]? = some entry :=
      List.mk_mem_zipIdx_iff_getElem?.mp hindexed
    have hindex : index < c.gates.toList.length :=
      (List.getElem?_eq_some_iff.mp hentry).1
    have hgateEq : gate = index := by
      simpa using congrArg (fun src => match src with
        | .iniReg g => g
        | _ => 0) heq.symm
    rw [hgateEq]
    simpa using hindex

private theorem relevant_shiftDownSrc_fresh {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (upSrc tailSrc : Src)
    (hup : upSrc ∈ Execution.relevantSrcs up.g.circuit up.g.horizon)
    (htail : tailSrc ∈ Execution.relevantSrcs tail.g.circuit tail.g.horizon) :
    upSrc ≠ shiftDownSrc up.g tail.g tailSrc := by
  intro heq
  cases tailSrc with
  | iniReg gate =>
      cases upSrc <;> simp [shiftDownSrc, downstreamOffset] at heq
      rename_i upGate
      have hupGate := iniReg_mem_relevant_gate_lt up.g.circuit
        up.g.horizon upGate hup
      omega
  | inp sharing share cycle =>
      have hsame : upSrc = .inp sharing share cycle := by
        simpa [shiftDownSrc] using heq
      exact glue.fresh upSrc hup (hsame ▸ htail)
  | rnd id cycle =>
      have hsame : upSrc = .rnd id cycle := by
        simpa [shiftDownSrc] using heq
      exact glue.fresh upSrc hup (hsame ▸ htail)
  | ini id cycle =>
      have hsame : upSrc = .ini id cycle := by
        simpa [shiftDownSrc] using heq
      exact glue.fresh upSrc hup (hsame ▸ htail)
  | ctl id cycle =>
      have hsame : upSrc = .ctl id cycle := by
        simpa [shiftDownSrc] using heq
      exact glue.fresh upSrc hup (hsame ▸ htail)

private theorem pipeline_interface_relevant {H d t : Nat}
    (P : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ interfaceAtoms P.g) :
    src ∈ Execution.relevantSrcs P.g.circuit P.g.horizon := by
  have hall := List.all_eq_true.mp P.source_partition.1 src hsrc
  simpa [List.contains_iff_mem] using hall

private theorem registeredComposite_inputArrival_cases {H d t : Nat}
    (up tail : PipelineGadget H d t) (input share : Nat)
    (hinput : input < (registeredComposite up.g tail.ports).inputCount)
    (hshare : share < (registeredComposite up.g tail.ports).d) :
    (∃ upInput, upInput < up.g.inputCount ∧
      (registeredComposite up.g tail.ports).inputArrival input share =
        up.g.inputArrival upInput share) ∨
    (∃ tailInput, tailInput < tail.g.inputCount ∧
      tailInput ≠ tail.ports.downstreamInput ∧
      (registeredComposite up.g tail.ports).inputArrival input share =
        shiftDownSrc up.g tail.g (tail.g.inputArrival tailInput share)) := by
  by_cases hup : input < up.g.inputCount
  · exact Or.inl ⟨input, hup, by simp [registeredComposite, hup]⟩
  · let external := input - up.g.inputCount
    have hexternal : external < tail.g.inputCount - 1 := by
      dsimp [external]
      simp [registeredComposite] at hinput
      omega
    let tailInput := unhideRegisteredInput tail.ports.downstreamInput external
    have htailInput : tailInput < tail.g.inputCount :=
      unhideRegisteredInput_lt _ _ _ tail.ports.input_bound hexternal
    have htailNe : tailInput ≠ tail.ports.downstreamInput :=
      unhideRegisteredInput_ne _ _
    exact Or.inr ⟨tailInput, htailInput, htailNe, by
      simp [registeredComposite, hup, external, tailInput]⟩

private theorem upstream_relevant_not_composite_interface {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs up.g.circuit up.g.horizon)
    (hnotInterface : src ∉ interfaceAtoms up.g) :
    src ∉ interfaceAtoms (registeredComposite up.g tail.ports) := by
  intro hcomposite
  rw [interfaceAtoms, List.mem_flatMap] at hcomposite
  rcases hcomposite with ⟨input, hinput, hshareMem⟩
  rw [List.mem_map] at hshareMem
  rcases hshareMem with ⟨share, hshare, heq⟩
  have hcases := registeredComposite_inputArrival_cases up tail input share
    (by simpa using hinput) (by simpa using hshare)
  rcases hcases with ⟨upInput, hupInput, harrival⟩ |
      ⟨tailInput, htailInput, _htailNe, harrival⟩
  · apply hnotInterface
    simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
    exact ⟨upInput, hupInput, share,
      by simpa [up.d_eq, tail.d_eq, registeredComposite] using hshare,
      harrival.symm.trans heq⟩
  · have htailAtom : tail.g.inputArrival tailInput share ∈
        interfaceAtoms tail.g := by
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨tailInput, htailInput, share,
        by simpa [registeredComposite] using hshare, rfl⟩
    have htailRelevant := pipeline_interface_relevant tail _ htailAtom
    exact relevant_shiftDownSrc_fresh up tail glue src
      (tail.g.inputArrival tailInput share) hrelevant htailRelevant
      (harrival.symm.trans heq).symm

private theorem lookupAssoc_append_of_some [BEq α] [LawfulBEq α]
    (key : α) (left right : List (α × β)) (value : β)
    (hlookup : Execution.lookupAssoc key left = some value) :
    Execution.lookupAssoc key (left ++ right) = some value := by
  induction left with
  | nil => simp [Execution.lookupAssoc] at hlookup
  | cons entry left ih =>
      rcases entry with ⟨entryKey, entryValue⟩
      by_cases heq : key = entryKey
      · subst entryKey
        simpa [Execution.lookupAssoc] using hlookup
      · simp [Execution.lookupAssoc, heq] at hlookup ⊢
        exact ih hlookup

private theorem upstream_relevant_composite {H d t : Nat}
    (up tail : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ Execution.relevantSrcs up.g.circuit up.g.horizon) :
    src ∈ Execution.relevantSrcs
      (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).horizon := by
  rw [relevantSrcs_registeredComposite up tail]
  simp [hsrc]

private theorem upstream_relevant_not_composite_random {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs up.g.circuit up.g.horizon)
    (hnotRandom : src ∉ up.g.randomness) :
    src ∉ (registeredComposite up.g tail.ports).randomness := by
  intro hrandom
  simp only [registeredComposite, List.mem_append, List.mem_map] at hrandom
  rcases hrandom with hupRandom | ⟨tailSrc, htailRandom, heq⟩
  · exact hnotRandom hupRandom
  · have htailRelevant : tailSrc ∈
        Execution.relevantSrcs tail.g.circuit tail.g.horizon := by
      have hall := List.all_eq_true.mp tail.source_partition.2.1 tailSrc
        htailRandom
      simpa [List.contains_iff_mem] using hall
    exact relevant_shiftDownSrc_fresh up tail glue src tailSrc
      hrelevant htailRelevant heq.symm

private theorem upstream_relevant_not_boundaryInit {H d t : Nat}
    (up tail : PipelineGadget H d t) (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs up.g.circuit up.g.horizon) :
    src ∉ (List.range tail.g.d).map (fun share =>
      (.iniReg (boundaryRegister up.g share) : Src)) := by
  intro hboundary
  simp only [List.mem_map, List.mem_range] at hboundary
  rcases hboundary with ⟨share, hshare, heq⟩
  cases src with
  | iniReg gate =>
      have hgate := iniReg_mem_relevant_gate_lt up.g.circuit up.g.horizon
        gate hrelevant
      simp [boundaryRegister] at heq
      omega
  | inp | rnd | ini | ctl => simp at heq

private theorem upstream_relevant_not_composite_public {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs up.g.circuit up.g.horizon)
    (hnotPublic : src ∉ publicAtoms up.g) :
    src ∉ publicAtoms (registeredComposite up.g tail.ports) := by
  intro hpublic
  unfold publicAtoms at hpublic
  rw [List.mem_map] at hpublic
  rcases hpublic with ⟨entry, hentry, heq⟩
  simp only [registeredComposite, List.mem_append] at hentry
  rcases hentry with (hupEntry | htailEntry) | hboundaryEntry
  · apply hnotPublic
    exact List.mem_map.mpr ⟨entry, hupEntry, heq⟩
  · rw [List.mem_map] at htailEntry
    rcases htailEntry with ⟨tailEntry, htailEntry, hentryEq⟩
    subst entry
    have htailAtom : tailEntry.1 ∈ publicAtoms tail.g :=
      List.mem_map.mpr ⟨tailEntry, htailEntry, rfl⟩
    have htailRelevant := pipeline_public_relevant tail tailEntry.1 htailAtom
    exact relevant_shiftDownSrc_fresh up tail glue src tailEntry.1
      hrelevant htailRelevant heq.symm
  · apply upstream_relevant_not_boundaryInit up tail src hrelevant
    rw [List.mem_map] at hboundaryEntry ⊢
    rcases hboundaryEntry with ⟨share, hshare, hentryEq⟩
    subst entry
    exact ⟨share, hshare, heq⟩

set_option maxHeartbeats 1000000 in
/-- E5, upstream marginal: restricting a composite experiment to the prefix
support is a legal isolated upstream experiment, indexed by the values seen
on the upstream interface. -/
theorem restrictEnv_upstream_mem_envsForInput {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput (registeredComposite up.g tail.ports) x) :
    restrictEnv (Execution.relevantSrcs up.g.circuit up.g.horizon) env ∈
      envsForInput up.g (interfaceValuation up.g env) := by
  apply restrictEnv_mem_envsOf_of_matches
  apply canonical_matches_fixingForInput up env
  · intro src value hlookup
    have hpair := Execution.lookupAssoc_some_mem src up.g.publicFixing value
      hlookup
    have hpublic : src ∈ publicAtoms up.g :=
      List.mem_map.mpr ⟨(src, value), hpair, rfl⟩
    have hrelevant := pipeline_public_relevant up src hpublic
    have hnotInterfaceUp := pipeline_public_not_interface up src hpublic
    have hnotRandomUp := pipeline_public_not_random up src hpublic
    have hcompositeRelevant := upstream_relevant_composite up tail src hrelevant
    have hnotCompositeInterface := upstream_relevant_not_composite_interface
      up tail glue src hrelevant hnotInterfaceUp
    have hnotCompositeRandom := upstream_relevant_not_composite_random
      up tail glue src hrelevant hnotRandomUp
    have harrival := arrivalValue_none_of_not_mem_interface
      (registeredComposite up.g tail.ports) x src hnotCompositeInterface
    have hcompositeLookup : Execution.lookupAssoc src
        (registeredComposite up.g tail.ports).publicFixing = some value := by
      simpa [registeredComposite, List.append_assoc] using
        lookupAssoc_append_of_some src up.g.publicFixing
          (tail.g.publicFixing.map (fun entry =>
              (shiftDownSrc up.g tail.g entry.1, entry.2)) ++
            (List.range tail.g.d).map (fun share =>
              (.iniReg (boundaryRegister up.g share), false))) value hlookup
    have hfixing : (src, value) ∈
        fixingForInput (registeredComposite up.g tail.ports) x := by
      unfold fixingForInput
      rw [List.mem_filterMap]
      exact ⟨src, hcompositeRelevant, by
        simp [harrival, hcompositeLookup]⟩
    exact env_value_of_fixing_mem
      (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).horizon
      (fixingForInput (registeredComposite up.g tail.ports) x)
      env src value henv hfixing
  · intro src hrelevant hnotInterface hlookup hnotRandom
    have hnotPublic : src ∉ publicAtoms up.g := by
      intro hpublic
      obtain ⟨value, hsome⟩ := Execution.lookupAssoc_some_of_mem_key
        src up.g.publicFixing hpublic
      rw [hlookup] at hsome
      contradiction
    have hcompositeRelevant := upstream_relevant_composite up tail src hrelevant
    have hnotCompositeInterface := upstream_relevant_not_composite_interface
      up tail glue src hrelevant hnotInterface
    have hnotCompositeRandom := upstream_relevant_not_composite_random
      up tail glue src hrelevant hnotRandom
    have hnotCompositePublic := upstream_relevant_not_composite_public
      up tail glue src hrelevant hnotPublic
    have hcompositeLookup : Execution.lookupAssoc src
        (registeredComposite up.g tail.ports).publicFixing = none :=
      Execution.lookupAssoc_none_of_not_mem src
        (registeredComposite up.g tail.ports).publicFixing hnotCompositePublic
    have harrival := arrivalValue_none_of_not_mem_interface
      (registeredComposite up.g tail.ports) x src hnotCompositeInterface
    have hfixing : (src, false) ∈
        fixingForInput (registeredComposite up.g tail.ports) x := by
      unfold fixingForInput
      rw [List.mem_filterMap]
      exact ⟨src, hcompositeRelevant, by
        simp [harrival, hcompositeLookup, List.contains_iff_mem,
          hnotCompositeRandom]⟩
    exact env_value_of_fixing_mem
      (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).horizon
      (fixingForInput (registeredComposite up.g tail.ports) x)
      env src false henv hfixing

private theorem shifted_tail_surviving_relevant_composite {H d t : Nat}
    (up tail : PipelineGadget H d t) (src : Src)
    (hrelevant : src ∈
      Execution.relevantSrcs tail.g.circuit tail.g.horizon)
    (hsurvives : src ∉ portInputAtoms tail.ports) :
    shiftDownSrc up.g tail.g src ∈ Execution.relevantSrcs
      (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).horizon := by
  rw [relevantSrcs_registeredComposite up tail]
  simp only [List.mem_eraseDups, List.mem_append, shiftedSurvivingTailSrcs,
    List.mem_map, List.mem_filter]
  refine Or.inr ⟨src, ⟨hrelevant, ?_⟩, rfl⟩
  simpa [List.contains_iff_mem] using hsurvives

private theorem shifted_tail_relevant_not_composite_interface {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs tail.g.circuit tail.g.horizon)
    (hnotInterface : src ∉ interfaceAtoms tail.g) :
    shiftDownSrc up.g tail.g src ∉
      interfaceAtoms (registeredComposite up.g tail.ports) := by
  intro hcomposite
  rw [interfaceAtoms, List.mem_flatMap] at hcomposite
  rcases hcomposite with ⟨input, hinput, hshareMem⟩
  rw [List.mem_map] at hshareMem
  rcases hshareMem with ⟨share, hshare, heq⟩
  have hcases := registeredComposite_inputArrival_cases up tail input share
    (by simpa using hinput) (by simpa using hshare)
  rcases hcases with ⟨upInput, hupInput, harrival⟩ |
      ⟨tailInput, htailInput, _htailNe, harrival⟩
  · have hupAtom : up.g.inputArrival upInput share ∈ interfaceAtoms up.g := by
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨upInput, hupInput, share,
        by simpa [up.d_eq, tail.d_eq, registeredComposite] using hshare, rfl⟩
    have hupRelevant := pipeline_interface_relevant up _ hupAtom
    exact relevant_shiftDownSrc_fresh up tail glue
      (up.g.inputArrival upInput share) src hupRelevant hrelevant
      (harrival.symm.trans heq)
  · apply hnotInterface
    have hshiftEq : shiftDownSrc up.g tail.g src =
        shiftDownSrc up.g tail.g (tail.g.inputArrival tailInput share) :=
      heq.symm.trans harrival
    have hsrcEq := shiftDownSrc_injective up.g tail.g hshiftEq
    simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
    exact ⟨tailInput, htailInput, share,
      by simpa [registeredComposite] using hshare, hsrcEq.symm⟩

private theorem shifted_tail_relevant_not_composite_random {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs tail.g.circuit tail.g.horizon)
    (hnotRandom : src ∉ tail.g.randomness) :
    shiftDownSrc up.g tail.g src ∉
      (registeredComposite up.g tail.ports).randomness := by
  intro hrandom
  simp only [registeredComposite, List.mem_append, List.mem_map] at hrandom
  rcases hrandom with hupRandom | ⟨tailRandom, htailRandom, heq⟩
  · have hupRelevant : shiftDownSrc up.g tail.g src ∈
        Execution.relevantSrcs up.g.circuit up.g.horizon := by
      have hall := List.all_eq_true.mp up.source_partition.2.1
        (shiftDownSrc up.g tail.g src) hupRandom
      simpa [List.contains_iff_mem] using hall
    exact relevant_shiftDownSrc_fresh up tail glue
      (shiftDownSrc up.g tail.g src) src hupRelevant hrelevant rfl
  · have hsame := shiftDownSrc_injective up.g tail.g heq
    apply hnotRandom
    exact hsame ▸ htailRandom

private theorem shifted_tail_relevant_not_boundaryInit {H d t : Nat}
    (up tail : PipelineGadget H d t) (src : Src) :
    shiftDownSrc up.g tail.g src ∉
      (List.range tail.g.d).map (fun share =>
        (.iniReg (boundaryRegister up.g share) : Src)) := by
  intro hboundary
  simp only [List.mem_map, List.mem_range] at hboundary
  rcases hboundary with ⟨share, hshare, heq⟩
  cases src <;> simp [shiftDownSrc, downstreamOffset, boundaryRegister] at heq
  omega

private theorem connectedArrivalAtoms_mem_interfaceAtoms {g : GadgetInstance}
    (ports : RegisterPorts g) (src : Src)
    (hsrc : src ∈ connectedArrivalAtoms ports) : src ∈ interfaceAtoms g := by
  simp only [connectedArrivalAtoms, List.mem_map, List.mem_range] at hsrc
  rcases hsrc with ⟨share, hshare, rfl⟩
  simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
  exact ⟨ports.downstreamInput, ports.input_bound, share, hshare, rfl⟩

private theorem portInputAtom_mem_connected_of_domain {H d t : Nat}
    (P : PipelineGadget H d t) (src : Src)
    (hport : src ∈ portInputAtoms P.ports)
    (hdomain : src ∈
      interfaceAtoms P.g ++ P.g.randomness ++ publicAtoms P.g) :
    src ∈ connectedArrivalAtoms P.ports := by
  by_cases hconnected : src ∈ connectedArrivalAtoms P.ports
  · exact hconnected
  · have hoff : src ∈ (portInputAtoms P.ports).filter fun atom =>
        !(connectedArrivalAtoms P.ports).contains atom := by
      simp [hport, List.contains_iff_mem, hconnected]
    exact (sourceDomainsDisjoint_not_mem _ _
      P.port_source_exclusive.2.2 src hoff hdomain).elim

private theorem pipeline_public_not_portInputAtoms {H d t : Nat}
    (P : PipelineGadget H d t) (src : Src)
    (hpublic : src ∈ publicAtoms P.g) :
    src ∉ portInputAtoms P.ports := by
  intro hport
  have hconnected := portInputAtom_mem_connected_of_domain P src hport
    (by simp [hpublic])
  have hinterface := connectedArrivalAtoms_mem_interfaceAtoms P.ports src
    hconnected
  exact sourceDomainsDisjoint_not_mem _ _ P.source_partition.2.2.2.1
    src hinterface hpublic

private theorem pipeline_random_not_portInputAtoms {H d t : Nat}
    (P : PipelineGadget H d t) (src : Src)
    (hrandom : src ∈ P.g.randomness) :
    src ∉ portInputAtoms P.ports := by
  intro hport
  have hconnected := portInputAtom_mem_connected_of_domain P src hport
    (by simp [hrandom])
  have hinterface := connectedArrivalAtoms_mem_interfaceAtoms P.ports src
    hconnected
  exact sourceDomainsDisjoint_not_mem _ _ P.source_partition.2.2.1
    src hinterface hrandom

private theorem lookupAssoc_append_of_none [BEq α] [LawfulBEq α]
    (key : α) (left right : List (α × β))
    (hlookup : Execution.lookupAssoc key left = none) :
    Execution.lookupAssoc key (left ++ right) =
      Execution.lookupAssoc key right := by
  induction left with
  | nil => rfl
  | cons entry left ih =>
      rcases entry with ⟨entryKey, entryValue⟩
      by_cases heq : key = entryKey
      · subst entryKey
        simp [Execution.lookupAssoc] at hlookup
      · simp [Execution.lookupAssoc, heq] at hlookup ⊢
        exact ih hlookup

private theorem lookupAssoc_map_key_of_injective [BEq α] [LawfulBEq α]
    (f : α → α) (hinjective : Function.Injective f)
    (key : α) (values : List (α × β)) (value : β)
    (hlookup : Execution.lookupAssoc key values = some value) :
    Execution.lookupAssoc (f key) (values.map fun entry =>
      (f entry.1, entry.2)) = some value := by
  induction values with
  | nil => simp [Execution.lookupAssoc] at hlookup
  | cons entry values ih =>
      rcases entry with ⟨entryKey, entryValue⟩
      by_cases heq : key = entryKey
      · subst entryKey
        simpa [Execution.lookupAssoc] using hlookup
      · have hfne : f key ≠ f entryKey := fun h => heq (hinjective h)
        simp [Execution.lookupAssoc, heq, hfne] at hlookup ⊢
        exact ih hlookup

private theorem shifted_tail_relevant_not_composite_public {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs tail.g.circuit tail.g.horizon)
    (hnotPublic : src ∉ publicAtoms tail.g) :
    shiftDownSrc up.g tail.g src ∉
      publicAtoms (registeredComposite up.g tail.ports) := by
  intro hpublic
  unfold publicAtoms at hpublic
  rw [List.mem_map] at hpublic
  rcases hpublic with ⟨entry, hentry, heq⟩
  simp only [registeredComposite, List.mem_append] at hentry
  rcases hentry with (hupEntry | htailEntry) | hboundaryEntry
  · have hupAtom : entry.1 ∈ publicAtoms up.g :=
      List.mem_map.mpr ⟨entry, hupEntry, rfl⟩
    have hupRelevant := pipeline_public_relevant up entry.1 hupAtom
    exact relevant_shiftDownSrc_fresh up tail glue entry.1 src
      hupRelevant hrelevant heq
  · rw [List.mem_map] at htailEntry
    rcases htailEntry with ⟨tailEntry, htailEntry, hentryEq⟩
    subst entry
    apply hnotPublic
    have hsrcEq : src = tailEntry.1 :=
      shiftDownSrc_injective up.g tail.g heq.symm
    exact hsrcEq ▸ List.mem_map.mpr ⟨tailEntry, htailEntry, rfl⟩
  · apply shifted_tail_relevant_not_boundaryInit up tail src
    rw [List.mem_map] at hboundaryEntry ⊢
    rcases hboundaryEntry with ⟨share, hshare, hentryEq⟩
    subst entry
    exact ⟨share, hshare, heq⟩

set_option maxHeartbeats 1000000 in
private theorem composite_env_shifted_public_value {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput (registeredComposite up.g tail.ports) x)
    (src : Src) (value : Bool)
    (hlookup : Execution.lookupAssoc src tail.g.publicFixing = some value) :
    env (shiftDownSrc up.g tail.g src) = value := by
  have hpair := Execution.lookupAssoc_some_mem src tail.g.publicFixing value
    hlookup
  have hpublic : src ∈ publicAtoms tail.g :=
    List.mem_map.mpr ⟨(src, value), hpair, rfl⟩
  have hrelevant := pipeline_public_relevant tail src hpublic
  have hsurvives := pipeline_public_not_portInputAtoms tail src hpublic
  have hnotInterface := pipeline_public_not_interface tail src hpublic
  have hnotRandom := pipeline_public_not_random tail src hpublic
  have hcompositeRelevant := shifted_tail_surviving_relevant_composite
    up tail src hrelevant hsurvives
  have hnotCompositeInterface := shifted_tail_relevant_not_composite_interface
    up tail glue src hrelevant hnotInterface
  have hnotCompositeRandom := shifted_tail_relevant_not_composite_random
    up tail glue src hrelevant hnotRandom
  have hnotUpPublic : shiftDownSrc up.g tail.g src ∉ publicAtoms up.g := by
    intro hupPublic
    have hupRelevant := pipeline_public_relevant up _ hupPublic
    exact relevant_shiftDownSrc_fresh up tail glue _ src
      hupRelevant hrelevant rfl
  have hupLookup : Execution.lookupAssoc (shiftDownSrc up.g tail.g src)
      up.g.publicFixing = none :=
    Execution.lookupAssoc_none_of_not_mem _ _ hnotUpPublic
  have htailLookup : Execution.lookupAssoc (shiftDownSrc up.g tail.g src)
      (tail.g.publicFixing.map fun entry =>
        (shiftDownSrc up.g tail.g entry.1, entry.2)) = some value :=
    lookupAssoc_map_key_of_injective (shiftDownSrc up.g tail.g)
      (shiftDownSrc_injective up.g tail.g) src tail.g.publicFixing value hlookup
  have hcompositeLookup : Execution.lookupAssoc (shiftDownSrc up.g tail.g src)
      (registeredComposite up.g tail.ports).publicFixing = some value := by
    rw [show (registeredComposite up.g tail.ports).publicFixing =
        (up.g.publicFixing ++ tail.g.publicFixing.map (fun entry =>
          (shiftDownSrc up.g tail.g entry.1, entry.2))) ++
          (List.range tail.g.d).map (fun share =>
            (.iniReg (boundaryRegister up.g share), false)) by
      rfl]
    rw [lookupAssoc_append_of_some]
    rw [lookupAssoc_append_of_none _ _ _ hupLookup]
    exact htailLookup
  have harrival := arrivalValue_none_of_not_mem_interface
    (registeredComposite up.g tail.ports) x (shiftDownSrc up.g tail.g src)
    hnotCompositeInterface
  have hfixing : (shiftDownSrc up.g tail.g src, value) ∈
      fixingForInput (registeredComposite up.g tail.ports) x := by
    unfold fixingForInput
    rw [List.mem_filterMap]
    exact ⟨shiftDownSrc up.g tail.g src, hcompositeRelevant, by
      simp [harrival, hcompositeLookup]⟩
  exact env_value_of_fixing_mem
    (registeredComposite up.g tail.ports).circuit
    (registeredComposite up.g tail.ports).horizon
    (fixingForInput (registeredComposite up.g tail.ports) x) env
    (shiftDownSrc up.g tail.g src) value henv hfixing

set_option maxHeartbeats 1000000 in
private theorem composite_env_shifted_default_value {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput (registeredComposite up.g tail.ports) x)
    (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs tail.g.circuit tail.g.horizon)
    (hnotInterface : src ∉ interfaceAtoms tail.g)
    (hlookup : Execution.lookupAssoc src tail.g.publicFixing = none)
    (hnotRandom : src ∉ tail.g.randomness)
    (hsurvives : src ∉ portInputAtoms tail.ports) :
    env (shiftDownSrc up.g tail.g src) = false := by
  have hnotPublic : src ∉ publicAtoms tail.g := by
    intro hpublic
    obtain ⟨value, hsome⟩ := Execution.lookupAssoc_some_of_mem_key
      src tail.g.publicFixing hpublic
    rw [hlookup] at hsome
    contradiction
  have hcompositeRelevant := shifted_tail_surviving_relevant_composite
    up tail src hrelevant hsurvives
  have hnotCompositeInterface := shifted_tail_relevant_not_composite_interface
    up tail glue src hrelevant hnotInterface
  have hnotCompositeRandom := shifted_tail_relevant_not_composite_random
    up tail glue src hrelevant hnotRandom
  have hnotCompositePublic := shifted_tail_relevant_not_composite_public
    up tail glue src hrelevant hnotPublic
  have hcompositeLookup : Execution.lookupAssoc (shiftDownSrc up.g tail.g src)
      (registeredComposite up.g tail.ports).publicFixing = none :=
    Execution.lookupAssoc_none_of_not_mem _ _ hnotCompositePublic
  have harrival := arrivalValue_none_of_not_mem_interface
    (registeredComposite up.g tail.ports) x (shiftDownSrc up.g tail.g src)
    hnotCompositeInterface
  have hfixing : (shiftDownSrc up.g tail.g src, false) ∈
      fixingForInput (registeredComposite up.g tail.ports) x := by
    unfold fixingForInput
    rw [List.mem_filterMap]
    exact ⟨shiftDownSrc up.g tail.g src, hcompositeRelevant, by
      simp [harrival, hcompositeLookup, List.contains_iff_mem,
        hnotCompositeRandom]⟩
  exact env_value_of_fixing_mem
    (registeredComposite up.g tail.ports).circuit
    (registeredComposite up.g tail.ports).horizon
    (fixingForInput (registeredComposite up.g tail.ports) x) env
    (shiftDownSrc up.g tail.g src) false henv hfixing

private theorem boundaryInit_not_composite_interface {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (share : Nat) (hshare : share < tail.g.d) :
    (.iniReg (boundaryRegister up.g share) : Src) ∉
      interfaceAtoms (registeredComposite up.g tail.ports) := by
  intro hinterface
  rw [interfaceAtoms, List.mem_flatMap] at hinterface
  rcases hinterface with ⟨input, hinput, hshareMem⟩
  rw [List.mem_map] at hshareMem
  rcases hshareMem with ⟨lane, hlane, heq⟩
  have hcases := registeredComposite_inputArrival_cases up tail input lane
    (by simpa using hinput) (by simpa using hlane)
  rcases hcases with ⟨upInput, hupInput, harrival⟩ |
      ⟨tailInput, htailInput, _htailNe, harrival⟩
  · have hupAtom : up.g.inputArrival upInput lane ∈ interfaceAtoms up.g := by
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨upInput, hupInput, lane,
        by simpa [up.d_eq, tail.d_eq, registeredComposite] using hlane, rfl⟩
    have hupRelevant := pipeline_interface_relevant up _ hupAtom
    apply upstream_relevant_not_boundaryInit up tail
      (up.g.inputArrival upInput lane) hupRelevant
    simp only [List.mem_map, List.mem_range]
    exact ⟨share, hshare, (harrival.symm.trans heq).symm⟩
  · have htailAtom : tail.g.inputArrival tailInput lane ∈
        interfaceAtoms tail.g := by
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨tailInput, htailInput, lane,
        by simpa [registeredComposite] using hlane, rfl⟩
    have htailRelevant := pipeline_interface_relevant tail _ htailAtom
    apply shifted_tail_relevant_not_boundaryInit up tail
      (tail.g.inputArrival tailInput lane)
    simp only [List.mem_map, List.mem_range]
    exact ⟨share, hshare, (harrival.symm.trans heq).symm⟩

private theorem boundaryInit_not_composite_random {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (share : Nat) (hshare : share < tail.g.d) :
    (.iniReg (boundaryRegister up.g share) : Src) ∉
      (registeredComposite up.g tail.ports).randomness := by
  intro hrandom
  simp only [registeredComposite, List.mem_append, List.mem_map] at hrandom
  rcases hrandom with hupRandom | ⟨tailRandom, htailRandom, heq⟩
  · have hupRelevant : (.iniReg (boundaryRegister up.g share) : Src) ∈
        Execution.relevantSrcs up.g.circuit up.g.horizon := by
      have hall := List.all_eq_true.mp up.source_partition.2.1 _ hupRandom
      simpa [List.contains_iff_mem] using hall
    exact upstream_relevant_not_boundaryInit up tail _ hupRelevant
      (by
        simp only [List.mem_map, List.mem_range]
        exact ⟨share, hshare, rfl⟩)
  · apply shifted_tail_relevant_not_boundaryInit up tail tailRandom
    simp only [List.mem_map, List.mem_range]
    exact ⟨share, hshare, heq.symm⟩

private theorem boundaryInit_relevant_composite {H d t : Nat}
    (up tail : PipelineGadget H d t) (share : Nat) (hshare : share < d) :
    (.iniReg (boundaryRegister up.g share) : Src) ∈ Execution.relevantSrcs
      (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).horizon := by
  rw [relevantSrcs_registeredComposite up tail]
  simp only [List.mem_eraseDups, List.mem_append]
  exact Or.inl (Or.inr (by
    simp only [List.mem_map, List.mem_range]
    exact ⟨share, hshare, rfl⟩))

private theorem boundaryFixing_lookup {H d t : Nat}
    (up tail : PipelineGadget H d t) (share : Nat)
    (hshare : share < tail.g.d) :
    Execution.lookupAssoc (Src.iniReg (boundaryRegister up.g share))
      ((List.range tail.g.d).map (fun lane =>
        (Src.iniReg (boundaryRegister up.g lane), false))) = some false := by
  apply lookupAssoc_eq_of_mem_nodup
  · exact List.mem_map.mpr ⟨share, by simpa using hshare, rfl⟩
  · have hinjective : Function.Injective (fun lane =>
        (.iniReg (boundaryRegister up.g lane) : Src)) := by
      intro left right heq
      simp [boundaryRegister] at heq
      exact heq
    have hn := eraseDups_nodup
      ((List.range tail.g.d).map fun lane =>
        (.iniReg (boundaryRegister up.g lane) : Src))
    rw [eraseDups_map_injective _ hinjective,
      eraseDups_eq_self_of_nodup List.nodup_range] at hn
    simpa [Function.comp_def] using hn

set_option maxHeartbeats 1000000 in
private theorem composite_env_boundaryInit_false {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput (registeredComposite up.g tail.ports) x)
    (share : Nat) (hshare : share < d) :
    env (.iniReg (boundaryRegister up.g share)) = false := by
  have hshareTail : share < tail.g.d := by simpa [tail.d_eq] using hshare
  let src : Src := .iniReg (boundaryRegister up.g share)
  have hrelevant := boundaryInit_relevant_composite up tail share hshare
  have hnotInterface := boundaryInit_not_composite_interface up tail glue
    share hshareTail
  have hnotRandom := boundaryInit_not_composite_random up tail glue
    share hshareTail
  have hnotPrefixPublic : src ∉ publicAtoms up.g := by
    intro hpublic
    have hupRelevant := pipeline_public_relevant up src hpublic
    exact upstream_relevant_not_boundaryInit up tail src hupRelevant
      (by
        simp only [List.mem_map, List.mem_range]
        exact ⟨share, hshareTail, rfl⟩)
  have hupLookup : Execution.lookupAssoc src up.g.publicFixing = none :=
    Execution.lookupAssoc_none_of_not_mem _ _ hnotPrefixPublic
  have hnotTailPublic : src ∉
      (tail.g.publicFixing.map fun entry =>
        (shiftDownSrc up.g tail.g entry.1, entry.2)).map Prod.fst := by
    intro hpublic
    simp only [List.map_map, Function.comp_apply, List.mem_map] at hpublic
    rcases hpublic with ⟨entry, hentry, heq⟩
    have htailAtom : entry.1 ∈ publicAtoms tail.g :=
      List.mem_map.mpr ⟨entry, hentry, rfl⟩
    have htailRelevant := pipeline_public_relevant tail entry.1 htailAtom
    exact shifted_tail_relevant_not_boundaryInit up tail entry.1
      (by simp only [List.mem_map, List.mem_range]
          exact ⟨share, hshareTail, heq.symm⟩)
  have htailLookup : Execution.lookupAssoc src
      (tail.g.publicFixing.map fun entry =>
        (shiftDownSrc up.g tail.g entry.1, entry.2)) = none :=
    Execution.lookupAssoc_none_of_not_mem _ _ hnotTailPublic
  have hboundaryLookup := boundaryFixing_lookup up tail share hshareTail
  have hcompositeLookup : Execution.lookupAssoc src
      (registeredComposite up.g tail.ports).publicFixing = some false := by
    rw [show (registeredComposite up.g tail.ports).publicFixing =
        (up.g.publicFixing ++ tail.g.publicFixing.map (fun entry =>
          (shiftDownSrc up.g tail.g entry.1, entry.2))) ++
          (List.range tail.g.d).map (fun lane =>
            (Src.iniReg (boundaryRegister up.g lane), false)) by rfl]
    rw [lookupAssoc_append_of_none _ _ _]
    · exact hboundaryLookup
    · rw [lookupAssoc_append_of_none _ _ _ hupLookup]
      exact htailLookup
  have harrival := arrivalValue_none_of_not_mem_interface
    (registeredComposite up.g tail.ports) x src hnotInterface
  have hfixing : (src, false) ∈
      fixingForInput (registeredComposite up.g tail.ports) x := by
    unfold fixingForInput
    rw [List.mem_filterMap]
    exact ⟨src, hrelevant, by simp [harrival, hcompositeLookup]⟩
  exact env_value_of_fixing_mem
    (registeredComposite up.g tail.ports).circuit
    (registeredComposite up.g tail.ports).horizon
    (fixingForInput (registeredComposite up.g tail.ports) x)
    env src false henv hfixing

private theorem mem_portInputAtoms_cases {H d t : Nat}
    (P : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ portInputAtoms P.ports) :
    ∃ share, share < P.g.d ∧ ∃ sharing cycle,
      cycle < P.g.horizon ∧
      P.g.circuit.gates[P.ports.inputGate share]? =
        some { kind := .inp sharing share, inputs := [] } ∧
      src = .inp sharing share cycle := by
  rw [portInputAtoms, List.mem_flatMap] at hsrc
  rcases hsrc with ⟨share, hshareMem, hstream⟩
  have hshare : share < P.g.d := by simpa using hshareMem
  obtain ⟨sharing, hgate, _harrival⟩ :=
    P.ports.input_source_coherent share hshare
  rw [hgate] at hstream
  simp only [List.mem_map, List.mem_range] at hstream
  rcases hstream with ⟨cycle, hcycle, heq⟩
  exact ⟨share, hshare, sharing, cycle, hcycle, hgate, heq.symm⟩

set_option maxHeartbeats 1000000 in
private theorem substitutedTailEnv_default_port_false {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput (registeredComposite up.g tail.ports) x)
    (src : Src) (hport : src ∈ portInputAtoms tail.ports)
    (hnotInterface : src ∉ interfaceAtoms tail.g) :
    substitutedTailEnv up.g tail.g tail.ports env src = false := by
  rcases mem_portInputAtoms_cases tail src hport with
    ⟨share, hshare, sharing, cycle, hcycle, hgate, hsrc⟩
  have hconnected := connectedAtomShare?_of_port_stream tail share sharing
    cycle hshare hgate
  have hshareD : share < d := by simpa [tail.d_eq] using hshare
  have hoff : cycle ≠ tail.ports.arrivalCycle := by
    intro heq
    apply hnotInterface
    obtain ⟨portSharing, hportGate, harrival⟩ :=
      tail.ports.input_source_coherent share hshare
    have hsharing : portSharing = sharing := by
      rw [hgate] at hportGate
      cases hportGate
      rfl
    subst portSharing
    rw [hsrc, heq, ← harrival]
    simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
    exact ⟨tail.ports.downstreamInput, tail.ports.input_bound,
      share, hshare, rfl⟩
  have henvUp := restrictEnv_upstream_mem_envsForInput up tail glue x env henv
  have hxUp : interfaceValuation up.g env ∈
      boolVectors (inputWidth up.g) := by
    rw [mem_boolVectors_iff]
    exact interfaceValuation_length up.g env
  have hinit := composite_env_boundaryInit_false up tail glue x env henv
    share hshareD
  rw [hsrc]
  simp only [substitutedTailEnv, hconnected]
  exact eval_boundary_register_off up tail glue env share hshareD
    (interfaceValuation up.g env) hxUp henvUp hinit cycle
    (by simpa [tail.horizon_eq] using hcycle) hoff

private theorem inp_mem_relevant_cycle_lt (g : GadgetInstance)
    (sharing share cycle : Nat)
    (hmem : (.inp sharing share cycle : Src) ∈
      Execution.relevantSrcs g.circuit g.horizon) : cycle < g.horizon := by
  rw [UniversalSStage1.relevantSrcs_eq_public, List.mem_eraseDups,
    List.mem_flatMap] at hmem
  rcases hmem with ⟨⟨entry, gate⟩, _hgate, hsource⟩
  rw [List.mem_append] at hsource
  rcases hsource with hgateSource | hboundary
  · cases hkind : entry.kind <;>
      simp [UniversalSStage1.publicGateSrcs, hkind] at hgateSource
    rcases hgateSource with ⟨atCycle, hAtCycle, _hsharing, _hshare,
      hcycleEq⟩
    omega
  · simp only [UniversalSStage1.publicBoundarySrcs, List.mem_flatMap,
      List.mem_map] at hboundary
    rcases hboundary with ⟨atCycle, _hatCycle, input, _hinput, heq⟩
    cases heq

private theorem connectedAtomShare?_none_of_relevant_not_port {H d t : Nat}
    (P : PipelineGadget H d t) (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs P.g.circuit P.g.horizon)
    (hnotPort : src ∉ portInputAtoms P.ports) :
    connectedAtomShare? P.ports src = none := by
  cases hconnected : connectedAtomShare? P.ports src with
  | none => rfl
  | some lane =>
      have hlaneMem := List.mem_of_find?_eq_some hconnected
      have hlane : lane < P.g.d := by
        simpa [connectedAtomShare?] using hlaneMem
      obtain ⟨portSharing, hportGate, _harrival⟩ :=
        P.ports.input_source_coherent lane hlane
      have hmatches := List.find?_some hconnected
      cases src with
      | inp sharing share cycle =>
          simp [connectedAtomShare?, hportGate] at hmatches
          have hsharing : portSharing = sharing := hmatches.1
          have hshare : lane = share := hmatches.2
          subst portSharing
          subst lane
          have hcycle := inp_mem_relevant_cycle_lt P.g sharing share cycle
            hrelevant
          apply (hnotPort ?_).elim
          rw [portInputAtoms, List.mem_flatMap]
          refine ⟨share, by simpa using hlaneMem, ?_⟩
          rw [hportGate]
          simp [hcycle]
      | rnd | ini | ctl | iniReg =>
          simp [connectedAtomShare?] at hmatches

set_option maxHeartbeats 1000000 in
/-- E5, downstream marginal: the boundary-substituted tail environment,
canonically restricted to the isolated support, is a legal tail experiment.
Connected stream atoms away from the declared arrival collapse to the pinned
boundary value; every surviving clause is transported through `shiftDownSrc`.
-/
theorem restrictSubstitutedTailEnv_mem_envsForInput {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput (registeredComposite up.g tail.ports) x) :
    let downEnv := substitutedTailEnv up.g tail.g tail.ports env
    restrictEnv (Execution.relevantSrcs tail.g.circuit tail.g.horizon)
        downEnv ∈
      envsForInput tail.g (interfaceValuation tail.g downEnv) := by
  dsimp only
  apply restrictEnv_mem_envsOf_of_matches
  apply canonical_matches_fixingForInput tail
    (substitutedTailEnv up.g tail.g tail.ports env)
  · intro src value hlookup
    have hpair := Execution.lookupAssoc_some_mem src tail.g.publicFixing value
      hlookup
    have hpublic : src ∈ publicAtoms tail.g :=
      List.mem_map.mpr ⟨(src, value), hpair, rfl⟩
    have hrelevant := pipeline_public_relevant tail src hpublic
    have hnotPort := pipeline_public_not_portInputAtoms tail src hpublic
    have hconnected := connectedAtomShare?_none_of_relevant_not_port
      tail src hrelevant hnotPort
    have hvalue := composite_env_shifted_public_value up tail glue x env henv
      src value hlookup
    cases src <;>
      simpa [substitutedTailEnv, hconnected, shiftDownSrc] using hvalue
  · intro src hrelevant hnotInterface hlookup hnotRandom
    by_cases hport : src ∈ portInputAtoms tail.ports
    · exact substitutedTailEnv_default_port_false up tail glue x env henv
        src hport hnotInterface
    · have hconnected := connectedAtomShare?_none_of_relevant_not_port
        tail src hrelevant hport
      have hvalue := composite_env_shifted_default_value up tail glue x env
        henv src hrelevant hnotInterface hlookup hnotRandom hport
      cases src <;>
        simpa [substitutedTailEnv, hconnected, shiftDownSrc] using hvalue

/-- The P3 source decomposition has no latent duplicate elimination once the
component freshness invariant is available.  This spelling is the list-level
normal form consumed by the exact E5 assignment product. -/
theorem registeredComposite_relevantSrcs_concat {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail) :
    Execution.relevantSrcs
        (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon =
      Execution.relevantSrcs up.g.circuit up.g.horizon ++
        (List.range d).map (fun share =>
          (.iniReg (boundaryRegister up.g share) : Src)) ++
        shiftedSurvivingTailSrcs up.g tail.g tail.ports := by
  rw [relevantSrcs_registeredComposite up tail]
  apply eraseDups_eq_self_of_nodup
  have hupNodup :
      (Execution.relevantSrcs up.g.circuit up.g.horizon).Nodup :=
    Execution.eraseDups_nodup _
  have hboundaryNodup :
      ((List.range d).map fun share =>
        (.iniReg (boundaryRegister up.g share) : Src)).Nodup := by
    apply map_nodup_of_inj_on (List.range d)
      (fun share => (.iniReg (boundaryRegister up.g share) : Src))
      List.nodup_range
    intro left _ right _ heq
    simp [boundaryRegister] at heq
    exact heq
  have htailBaseNodup :
      ((Execution.relevantSrcs tail.g.circuit tail.g.horizon).filter fun src =>
        !(portInputAtoms tail.ports).contains src).Nodup :=
    (Execution.eraseDups_nodup _).filter _
  have htailNodup :
      (shiftedSurvivingTailSrcs up.g tail.g tail.ports).Nodup := by
    unfold shiftedSurvivingTailSrcs
    apply map_nodup_of_inj_on _ (shiftDownSrc up.g tail.g) htailBaseNodup
    intro left _ right _ heq
    exact shiftDownSrc_injective up.g tail.g heq
  have hupBoundaryNodup :
      (Execution.relevantSrcs up.g.circuit up.g.horizon ++
        (List.range d).map (fun share =>
          (.iniReg (boundaryRegister up.g share) : Src))).Nodup := by
    rw [List.nodup_append]
    refine ⟨hupNodup, hboundaryNodup, ?_⟩
    intro src hupSrc boundary hboundary heq
    subst boundary
    have hboundaryTail : src ∈ (List.range tail.g.d).map (fun share =>
        (.iniReg (boundaryRegister up.g share) : Src)) := by
      simpa [tail.d_eq] using hboundary
    exact upstream_relevant_not_boundaryInit up tail src hupSrc hboundaryTail
  rw [List.nodup_append]
  refine ⟨hupBoundaryNodup, htailNodup, ?_⟩
  intro src hleft shifted hright heq
  rw [List.mem_append] at hleft
  unfold shiftedSurvivingTailSrcs at hright
  rw [List.mem_map] at hright
  rcases hright with ⟨tailSrc, htailSrc, hshift⟩
  have htailRelevant := (List.mem_filter.mp htailSrc).1
  rcases hleft with hupSrc | hboundary
  · exact relevant_shiftDownSrc_fresh up tail glue src tailSrc hupSrc
      htailRelevant (heq.trans hshift.symm)
  · apply shifted_tail_relevant_not_boundaryInit up tail tailSrc
    rw [hshift, ← heq]
    simpa [tail.d_eq] using hboundary

private theorem assignmentsPattern_append (left right : List Src)
    (leftPattern rightPattern : List (Option Bool))
    (hleft : leftPattern.length = left.length) :
    Execution.assignmentsPattern (left ++ right) (leftPattern ++ rightPattern) =
      (Execution.assignmentsPattern right rightPattern).flatMap fun rightValues =>
        (Execution.assignmentsPattern left leftPattern).map fun leftValues =>
          leftValues ++ rightValues := by
  induction left generalizing leftPattern with
  | nil =>
      cases leftPattern with
      | nil => simp [Execution.assignmentsPattern]
      | cons _ _ => simp at hleft
  | cons src left ih =>
      cases leftPattern with
      | nil => simp at hleft
      | cons expected leftPattern =>
          have htail : leftPattern.length = left.length := Nat.succ.inj hleft
          cases expected <;>
            simp [Execution.assignmentsPattern, ih leftPattern htail,
              List.flatMap_assoc, List.flatMap_map, Function.comp_def,
              List.map_flatMap,
              List.map_map, List.append_assoc]

private theorem envsForInput_eq_assignmentsPattern (g : GadgetInstance)
    (x : List Bool) :
    envsForInput g x =
      (Execution.assignmentsPattern
        (Execution.relevantSrcs g.circuit g.horizon)
        ((Execution.relevantSrcs g.circuit g.horizon).map fun src =>
          Execution.lookupAssoc src (fixingForInput g x))).map
        Execution.envFrom := by
  unfold envsForInput Execution.envsOf
  rw [if_pos (fixingForInput_valid g x)]
  rw [supportedFixing_fixingForInput]

private theorem assignmentsPattern_all_fixed (sources : List Src)
    (values : Src → Bool) :
    Execution.assignmentsPattern sources
        (sources.map fun src => some (values src)) =
      [sources.map fun src => (src, values src)] := by
  induction sources with
  | nil => rfl
  | cons src sources ih => simp [Execution.assignmentsPattern, ih]

private theorem assignmentsPattern_map_keys (f : Src → Src)
    (sources : List Src) (pattern : List (Option Bool))
    (hpattern : pattern.length = sources.length) :
    Execution.assignmentsPattern (sources.map f) pattern =
      (Execution.assignmentsPattern sources pattern).map fun values =>
        values.map fun entry => (f entry.1, entry.2) := by
  induction sources generalizing pattern with
  | nil =>
      cases pattern with
      | nil => rfl
      | cons _ _ => simp at hpattern
  | cons src sources ih =>
      cases pattern with
      | nil => simp at hpattern
      | cons expected pattern =>
          have htail : pattern.length = sources.length := Nat.succ.inj hpattern
          cases expected <;>
            simp [Execution.assignmentsPattern, ih pattern htail,
              List.flatMap_map, List.map_flatMap, List.map_map,
              Function.comp_def]

private theorem assignmentsPattern_filter_fixed (sources : List Src)
    (expected : Src → Option Bool) (keep : Src → Bool)
    (hremoved : ∀ src ∈ sources, keep src = false →
      (expected src).isSome = true) :
    (Execution.assignmentsPattern sources (sources.map expected)).map
        (fun values => values.filter fun entry => keep entry.1) =
      Execution.assignmentsPattern (sources.filter keep)
        ((sources.filter keep).map expected) := by
  induction sources with
  | nil => rfl
  | cons src sources ih =>
      have htail : ∀ atom ∈ sources, keep atom = false →
          (expected atom).isSome = true := by
        intro atom hatom
        exact hremoved atom (by simp [hatom])
      by_cases hkeep : keep src = true
      · cases hexpected : expected src with
        | none =>
            simp [Execution.assignmentsPattern, hkeep, hexpected,
              List.map_flatMap]
            refine (List.flatMap_map
              (fun values => values.filter fun entry => keep entry.1)
              (fun values =>
                [[(src, false)] ++ values, [(src, true)] ++ values])
              (Execution.assignmentsPattern sources
                (sources.map expected))).symm.trans ?_
            exact congrArg (fun samples => samples.flatMap fun values =>
              [[(src, false)] ++ values, [(src, true)] ++ values]) (ih htail)
        | some value =>
            simp [Execution.assignmentsPattern, hkeep, hexpected,
              List.map_map]
            have hmap := congrArg
              (fun samples => samples.map fun values => (src, value) :: values)
              (ih htail)
            simpa [List.map_map, Function.comp_def, hkeep] using hmap
      · have hkeepFalse : keep src = false := by
          cases h : keep src <;> simp_all
        have hisSome := hremoved src (by simp) hkeepFalse
        cases hexpected : expected src with
        | none => simp [hexpected] at hisSome
        | some value =>
            simp [Execution.assignmentsPattern, hkeepFalse, hexpected,
              ih htail, List.map_map, Function.comp_def]

private theorem portSource_fixing_lookup_isSome {H d t : Nat}
    (P : PipelineGadget H d t) (x : List Bool) (src : Src)
    (hrelevant : src ∈
      Execution.relevantSrcs P.g.circuit P.g.horizon)
    (hport : src ∈ portInputAtoms P.ports) :
    (Execution.lookupAssoc src (fixingForInput P.g x)).isSome = true := by
  have hkey : src ∈ (fixingForInput P.g x).map Prod.fst := by
    rw [fixingForInput_keys]
    rw [List.mem_filter]
    refine ⟨hrelevant, ?_⟩
    by_cases hrandom : src ∈ P.g.randomness
    · have hconnected := portInputAtom_mem_connected_of_domain P src hport
        (by simp [hrandom])
      have hinterface := connectedArrivalAtoms_mem_interfaceAtoms P.ports src
        hconnected
      rw [arrivalValue_isSome]
      simp only [Bool.or_eq_true]
      apply Or.inl
      apply Or.inl
      simpa [List.contains_iff_mem, interfaceAtoms] using hinterface
    · simp [List.contains_iff_mem, hrandom]
  obtain ⟨value, hlookup⟩ := Execution.lookupAssoc_some_of_mem_key
    src (fixingForInput P.g x) hkey
  simp [hlookup]

def hideRegisteredInput (hidden input : Nat) : Nat :=
  if input < hidden then input else input - 1

private theorem unhide_hideRegisteredInput (hidden input count : Nat)
    (hhidden : hidden < count) (hinput : input < count)
    (hne : input ≠ hidden) :
    unhideRegisteredInput hidden (hideRegisteredInput hidden input) = input := by
  unfold hideRegisteredInput unhideRegisteredInput
  by_cases hlt : input < hidden
  · simp [hlt]
  · have hgt : hidden < input := by omega
    have hminus : ¬ input - 1 < hidden := by omega
    simp [hlt, hminus]
    omega

private theorem hideRegisteredInput_lt (hidden input count : Nat)
    (hhidden : hidden < count) (hinput : input < count)
    (hne : input ≠ hidden) :
    hideRegisteredInput hidden input < count - 1 := by
  unfold hideRegisteredInput
  split <;> omega

/-- External composite inputs as seen by the literal upstream prefix. -/
def pipelineUpInput {H d t : Nat} (up tail : PipelineGadget H d t)
    (x : List Bool) : List Bool :=
  (List.range up.g.inputCount).flatMap fun input =>
    (List.range up.g.d).map fun share =>
      inputBit (registeredComposite up.g tail.ports) x input share

/-- Full isolated-tail input induced by one upstream environment and the
remaining external composite inputs. -/
def pipelineTailInput {H d t : Nat} (up tail : PipelineGadget H d t)
    (x : List Bool) (upEnv : Env) : List Bool :=
  (List.range tail.g.inputCount).flatMap fun input =>
    (List.range tail.g.d).map fun share =>
      if input = tail.ports.downstreamInput then
        Execution.eval up.g.circuit up.g.horizon upEnv (up.g.output share)
      else
        inputBit (registeredComposite up.g tail.ports) x
          (up.g.inputCount +
            hideRegisteredInput tail.ports.downstreamInput input) share

private theorem length_flatMap_range_map (count width : Nat)
    (f : Nat → Nat → α) :
    ((List.range count).flatMap fun input =>
      (List.range width).map (f input)).length = count * width := by
  simp only [List.length_flatMap, List.length_map, List.length_range]
  induction count with
  | zero => simp
  | succ count ih =>
      rw [List.range_succ_eq_map]
      simp [Function.comp_def, ih, Nat.succ_mul, Nat.add_comm]

theorem pipelineUpInput_mem {H d t : Nat}
    (up tail : PipelineGadget H d t) (x : List Bool) :
    pipelineUpInput up tail x ∈ boolVectors (inputWidth up.g) := by
  rw [mem_boolVectors_iff]
  exact (length_flatMap_range_map up.g.inputCount up.g.d
    (fun input share =>
      inputBit (registeredComposite up.g tail.ports) x input share)).trans
      (by simp [inputWidth])

theorem pipelineTailInput_mem {H d t : Nat}
    (up tail : PipelineGadget H d t) (x : List Bool) (upEnv : Env) :
    pipelineTailInput up tail x upEnv ∈ boolVectors (inputWidth tail.g) := by
  rw [mem_boolVectors_iff]
  exact (length_flatMap_range_map tail.g.inputCount tail.g.d
    (fun input share =>
      if input = tail.ports.downstreamInput then
        Execution.eval up.g.circuit up.g.horizon upEnv (up.g.output share)
      else
        inputBit (registeredComposite up.g tail.ports) x
          (up.g.inputCount +
            hideRegisteredInput tail.ports.downstreamInput input) share)).trans
      (by simp [inputWidth])

private theorem inputBit_flatMap_blocks (g : GadgetInstance)
    (blocks : Nat → List Bool)
    (hlen : ∀ input, input < g.inputCount → (blocks input).length = g.d)
    (input share : Nat) (hinput : input < g.inputCount)
    (hshare : share < g.d) :
    inputBit g ((List.range g.inputCount).flatMap blocks) input share =
      (blocks input).getD share false := by
  have hblock := blockAt_flatMap_range g.d g.inputCount blocks hlen
    input hinput
  rw [inputBit, inputPosition]
  rw [← blockAt_getD g.d ((List.range g.inputCount).flatMap blocks)
    input share hshare]
  rw [hblock]

theorem pipelineUpInput_bit {H d t : Nat}
    (up tail : PipelineGadget H d t) (x : List Bool)
    (input share : Nat) (hinput : input < up.g.inputCount)
    (hshare : share < up.g.d) :
    inputBit up.g (pipelineUpInput up tail x) input share =
      inputBit (registeredComposite up.g tail.ports) x input share := by
  rw [pipelineUpInput]
  rw [inputBit_flatMap_blocks up.g
    (fun input => (List.range up.g.d).map fun share =>
      inputBit (registeredComposite up.g tail.ports) x input share)
    (by simp) input share hinput hshare]
  simp [hshare]

theorem pipelineTailInput_bit {H d t : Nat}
    (up tail : PipelineGadget H d t) (x : List Bool) (upEnv : Env)
    (input share : Nat) (hinput : input < tail.g.inputCount)
    (hshare : share < tail.g.d) :
    inputBit tail.g (pipelineTailInput up tail x upEnv) input share =
      if input = tail.ports.downstreamInput then
        Execution.eval up.g.circuit up.g.horizon upEnv (up.g.output share)
      else
        inputBit (registeredComposite up.g tail.ports) x
          (up.g.inputCount +
            hideRegisteredInput tail.ports.downstreamInput input) share := by
  rw [pipelineTailInput]
  rw [inputBit_flatMap_blocks tail.g
    (fun input => (List.range tail.g.d).map fun share =>
      if input = tail.ports.downstreamInput then
        Execution.eval up.g.circuit up.g.horizon upEnv (up.g.output share)
      else
        inputBit (registeredComposite up.g tail.ports) x
          (up.g.inputCount +
            hideRegisteredInput tail.ports.downstreamInput input) share)
    (by simp) input share hinput hshare]
  simp [hshare]

private theorem lookupAssoc_filterMap_key (sources : List Src)
    (hnodup : sources.Nodup) (cell : Src → Option Bool) (src : Src) :
    Execution.lookupAssoc src
        (sources.filterMap fun key => (cell key).map fun value => (key, value)) =
      if src ∈ sources then cell src else none := by
  induction sources with
  | nil => simp [Execution.lookupAssoc]
  | cons key sources ih =>
      have hn := List.nodup_cons.mp hnodup
      by_cases heq : src = key
      · subst key
        cases hcell : cell src <;>
          simp [Execution.lookupAssoc, hcell, ih hn.2, hn.1]
      · cases hcell : cell key <;>
          simp [Execution.lookupAssoc, hcell, heq, ih hn.2]

def fixingCell (g : GadgetInstance) (x : List Bool) (src : Src) :
    Option Bool :=
  match arrivalValue? g x src with
  | some bit => some bit
  | none =>
      match Execution.lookupAssoc src g.publicFixing with
      | some bit => some bit
      | none => if g.randomness.contains src then none else some false

private theorem fixingForInput_lookup_cell (g : GadgetInstance)
    (x : List Bool) (src : Src) :
    Execution.lookupAssoc src (fixingForInput g x) =
      if src ∈ Execution.relevantSrcs g.circuit g.horizon then
        fixingCell g x src
      else none := by
  unfold fixingForInput
  let cell := fixingCell g x
  have hbuilder :
      (fun src =>
        match arrivalValue? g x src with
        | some bit => some (src, bit)
        | none =>
            match Execution.lookupAssoc src g.publicFixing with
            | some bit => some (src, bit)
            | none => if g.randomness.contains src then none
                else some (src, false)) =
      (fun key => (cell key).map fun value => (key, value)) := by
    funext key
    simp [cell, fixingCell]
    split <;> rename_i harrival
    · rfl
    · split <;> rename_i hpublic
      · rfl
      · split <;> rfl
  have hfiltered := congrArg
    (fun builder =>
      (Execution.relevantSrcs g.circuit g.horizon).filterMap builder)
    hbuilder
  exact (congrArg (Execution.lookupAssoc src) hfiltered).trans
    (lookupAssoc_filterMap_key
      (Execution.relevantSrcs g.circuit g.horizon)
      (Execution.eraseDups_nodup _)
      cell src)

private theorem arrivalValue_input_of_injective (g : GadgetInstance)
    (hinjective : InterfaceInjective g) (x : List Bool)
    (input share : Nat) (hinput : input < g.inputCount)
    (hshare : share < g.d) :
    arrivalValue? g x (g.inputArrival input share) =
      some (inputBit g x input share) := by
  unfold arrivalValue?
  apply lookupAssoc_eq_of_mem_nodup
  · rw [List.mem_flatMap]
    exact ⟨input, by simpa using hinput,
      List.mem_map.mpr ⟨share, by simpa using hshare, rfl⟩⟩
  · have hkeys :
        (((List.range g.inputCount).flatMap fun sharing =>
          (List.range g.d).map fun lane =>
            (g.inputArrival sharing lane, inputBit g x sharing lane)).map
              Prod.fst) = interfaceAtoms g := by
      simp [interfaceAtoms, List.map_flatMap, Function.comp_def]
    rw [hkeys]
    exact hinjective

private theorem lookupAssoc_const_false_after_evalCycle
    (c : Circuit) (env : Env) (cycle gate : Nat)
    (schedule : List Nat) (values : List (Node × Bool))
    (hgate : c.gates[gate]? = some { kind := .const false, inputs := [] })
    (hmem : gate ∈ schedule) :
    Execution.lookupAssoc { gate := gate, cycle := cycle }
        (UniversalSStage1.evalCycle c env cycle schedule values) =
      some false := by
  induction schedule generalizing values with
  | nil => simp at hmem
  | cons current schedule ih =>
      rw [UniversalSStage1.evalCycle]
      simp only [List.foldl_cons]
      rw [← UniversalSStage1.evalCycle]
      by_cases htail : gate ∈ schedule
      · exact ih _ htail
      · have hcurrent : current = gate := by
          symm
          simpa [htail] using hmem
        subst current
        rw [lookupAssoc_evalCycle_other_gates c env cycle schedule
          { gate := gate, cycle := cycle } _ htail]
        simp [Execution.lookupAssoc, UniversalSStage1.gateValue, hgate]

private theorem eval_const_false (c : Circuit) (horizon : Nat) (env : Env)
    (gate cycle : Nat)
    (hgate : c.gates[gate]? = some { kind := .const false, inputs := [] })
    (hcycle : cycle < horizon) :
    Execution.eval c horizon env { gate := gate, cycle := cycle } = false := by
  induction horizon with
  | zero => omega
  | succ horizon ih =>
      by_cases hearlier : cycle < horizon
      · rw [eval_succ_stable_local c horizon env
          { gate := gate, cycle := cycle } hearlier]
        exact ih hearlier
      · have hlast : cycle = horizon := by omega
        subst horizon
        have hgateBound : gate < c.gates.size :=
          (Array.getElem?_eq_some_iff.mp hgate).choose
        simp only [Execution.eval]
        rw [if_pos (by simp [hgateBound])]
        rw [← UniversalSStage1.evalEntries_eq_execution,
          evalEntries_succ_local]
        rw [lookupAssoc_const_false_after_evalCycle c env cycle gate
          (Execution.gateOrder c) _ hgate
          (gate_mem_gateOrder_local c gate hgateBound)]
        rfl

private theorem registeredComposite_connected_const {H d t : Nat}
    (up tail : PipelineGadget H d t) (gate share : Nat)
    (hgate : gate < tail.g.circuit.gates.size)
    (hconnected : connectedShare? tail.ports gate = some share) :
    (registeredCompositeCircuit up.g tail.ports).gates[
        downstreamOffset up.g tail.g + gate]? =
      some { kind := .const false, inputs := [] } := by
  rw [registeredCompositeCircuit, UniversalSStage1.appendCircuit,
    Array.getElem?_append_right]
  · have hindex : downstreamOffset up.g tail.g + gate -
        up.g.circuit.gates.size = tail.g.d + gate := by
      simp [downstreamOffset, Nat.add_assoc]
    rw [hindex, Array.getElem?_append_right]
    · simp [boundaryRegisterGates, registeredDownGates,
        Array.getElem?_mapIdx, hgate, wireRegisteredDownGate, hconnected]
    · simp [boundaryRegisterGates]
  · simp [downstreamOffset]
    omega

set_option maxHeartbeats 1000000 in
/-- P5: the downstream output pulse invariant transfers through the
registered compiler.  Surviving output gates use E3 and the E5 downstream
marginal; a selected input gate compiled to a dead constant is immediate. -/
theorem registeredComposite_outputPulse {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail) :
    OutputPulse (registeredComposite up.g tail.ports) := by
  intro share hshare x hx env henv cycle hcycle hoff
  have hshareTail : share < tail.g.d := by
    simpa [registeredComposite] using hshare
  have hshareD : share < d := by simpa [tail.d_eq] using hshareTail
  have houtputGate := pipeline_output_gate_lt tail share hshareD
  have hcycleH : cycle < H := by
    simpa [registeredComposite, up.horizon_eq, tail.horizon_eq] using hcycle
  cases hconnected : connectedShare? tail.ports (tail.g.output share).gate with
  | some connectedShare =>
      apply eval_const_false
      · exact registeredComposite_connected_const up tail
          (tail.g.output share).gate connectedShare houtputGate hconnected
      · simpa [registeredComposite, up.horizon_eq, tail.horizon_eq] using hcycleH
  | none =>
      change Execution.eval (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env
        (embeddedDownNode up.g tail.g
          { gate := (tail.g.output share).gate, cycle := cycle }) = false
      rw [eval_substitute_downstream up tail env
        { gate := (tail.g.output share).gate, cycle := cycle }
        houtputGate hconnected]
      let downEnv := substitutedTailEnv up.g tail.g tail.ports env
      let canonicalDown := restrictEnv
        (Execution.relevantSrcs tail.g.circuit tail.g.horizon) downEnv
      rw [UniversalSStage1.eval_env_congr tail.g.circuit tail.g.horizon
        downEnv canonicalDown
        { gate := (tail.g.output share).gate, cycle := cycle }
        (restrictEnv_agrees
          (Execution.relevantSrcs tail.g.circuit tail.g.horizon) downEnv)]
      apply tail.output_pulse share
      · simpa using hshareTail
      · have hxDown : interfaceValuation tail.g downEnv ∈
            boolVectors (inputWidth tail.g) := by
          rw [mem_boolVectors_iff]
          exact interfaceValuation_length tail.g downEnv
        exact hxDown
      · exact restrictSubstitutedTailEnv_mem_envsForInput up tail glue
          x env henv
      · simpa [tail.horizon_eq] using hcycleH
      · simpa [registeredComposite] using hoff

/-! ## Ordered glitch frontiers

`transitionGlitch` instantiates `glitchGates` with the enclosing array size.
The following rank-normal form removes that incidental fuel choice for
forward-layout components. -/

private def orderedGlitchFrontier (c : Circuit) (gate : Nat) : List Nat :=
  match hgate : c.gates[gate]? with
  | none => [gate]
  | some entry =>
      let inputs := entry.inputs.filter (fun input => input.2 == 0)
      if inputs.isEmpty then [gate]
      else
        (inputs.flatMap fun input =>
          if hlt : input.1 < gate then orderedGlitchFrontier c input.1
          else [input.1]).eraseDups
termination_by gate

private theorem orderedGlitchFrontier_of_some (c : Circuit) (gate : Nat)
    (entry : Gate) (hentry : c.gates[gate]? = some entry) :
    orderedGlitchFrontier c gate =
      let inputs := entry.inputs.filter (fun input => input.2 == 0)
      if inputs.isEmpty then [gate]
      else
        (inputs.flatMap fun input =>
          if hlt : input.1 < gate then orderedGlitchFrontier c input.1
          else [input.1]).eraseDups := by
  rw [orderedGlitchFrontier]
  generalize hlookup : c.gates[gate]? = lookup at *
  cases lookup with
  | none => simp at hentry
  | some found =>
      have hfound : found = entry := Option.some.inj hentry
      subst found
      rfl

private theorem flatMap_congr_of_mem_local (xs : List α)
    (f g : α → List β) (h : ∀ x ∈ xs, f x = g x) :
    xs.flatMap f = xs.flatMap g := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
      simp only [List.flatMap_cons]
      rw [h x (by simp), ih]
      intro y hy
      exact h y (by simp [hy])

private theorem forwardCombinational_input_lt (g : GadgetInstance)
    (hforward : ForwardCombinational g) (gate : Nat) (entry : Gate)
    (hgate : g.circuit.gates[gate]? = some entry)
    (input : Nat × Nat) (hinput : input ∈ entry.inputs)
    (hzero : input.2 = 0) : input.1 < gate := by
  have hedge : (input.1, gate) ∈ g.circuit.combEdges := by
    rw [UniversalSStage1.mem_combEdges_iff]
    exact ⟨entry, hgate, input, hinput, hzero, rfl⟩
  have hall := List.all_eq_true.mp hforward (input.1, gate) hedge
  simpa using hall

private theorem glitchGates_eq_orderedGlitchFrontier
    (g : GadgetInstance) (hforward : ForwardCombinational g)
    (gate fuel : Nat) (hgate : gate < fuel) :
    Expansion.glitchGates g.circuit fuel gate =
      orderedGlitchFrontier g.circuit gate := by
  induction fuel generalizing gate with
  | zero => simp at hgate
  | succ fuel ih =>
      rw [Expansion.glitchGates, orderedGlitchFrontier]
      cases hg : g.circuit.gates[gate]? with
      | none => simp only [hg]
      | some entry =>
          simp only [hg]
          let inputs := entry.inputs.filter fun input => input.2 == 0
          split
          · rfl
          · apply congrArg List.eraseDups
            apply flatMap_congr_of_mem_local
            intro input hmem
            have hmem' := List.mem_filter.mp hmem
            have hzero : input.2 = 0 := by simpa using hmem'.2
            have hlt := forwardCombinational_input_lt g hforward gate entry
              hg input hmem'.1 hzero
            simp only [hlt, ↓reduceDIte]
            exact ih input.1 (by omega)

set_option maxHeartbeats 1000000 in
private theorem orderedGlitchFrontier_prefix {H d t : Nat}
    (up tail : PipelineGadget H d t) (gate : Nat)
    (hgate : gate < up.g.circuit.gates.size) :
    orderedGlitchFrontier (registeredComposite up.g tail.ports).circuit gate =
      orderedGlitchFrontier up.g.circuit gate := by
  induction gate using Nat.strongRecOn with
  | ind gate ih =>
      rw [orderedGlitchFrontier, orderedGlitchFrontier]
      have hsame :
          (registeredComposite up.g tail.ports).circuit.gates[gate]? =
            up.g.circuit.gates[gate]? := by
        change (up.g.circuit.gates ++
          (boundaryRegisterGates up.g tail.g ++
            registeredDownGates tail.ports))[gate]? = _
        exact Array.getElem?_append_left hgate
      cases hentry : up.g.circuit.gates[gate]? with
      | none =>
          have hcompEntry :
              (registeredComposite up.g tail.ports).circuit.gates[gate]? =
                none := hsame.trans hentry
          rw [hcompEntry]
      | some entry =>
          have hcompEntry :
              (registeredComposite up.g tail.ports).circuit.gates[gate]? =
                some entry := hsame.trans hentry
          rw [hcompEntry]
          let inputs := entry.inputs.filter fun input => input.2 == 0
          by_cases hempty : inputs.isEmpty = true
          · simp [inputs, hempty]
          · simp only [inputs, hempty, if_false]
            apply congrArg List.eraseDups
            apply flatMap_congr_of_mem_local
            intro input hinput
            have hinput' := List.mem_filter.mp hinput
            have hzero : input.2 = 0 := by simpa using hinput'.2
            have hlt := forwardCombinational_input_lt up.g
              up.forward_combinational gate entry hentry input hinput'.1 hzero
            simp only [hlt, ↓reduceDIte]
            exact ih input.1 hlt (by omega)

private theorem registeredComposite_suffix_gate_frontier {H d t : Nat}
    (up tail : PipelineGadget H d t) (gate : Nat)
    (hgate : gate < tail.g.circuit.gates.size) :
    (registeredComposite up.g tail.ports).circuit.gates[
        downstreamOffset up.g tail.g + gate]? =
      tail.g.circuit.gates[gate]?.map
        (wireRegisteredDownGate (up := up.g) tail.ports gate) := by
  simp [registeredComposite, registeredCompositeCircuit,
    UniversalSStage1.appendCircuit, downstreamOffset,
    boundaryRegisterGates, registeredDownGates, hgate, Nat.add_assoc]

set_option maxHeartbeats 1000000 in
private theorem orderedGlitchFrontier_tail {H d t : Nat}
    (up tail : PipelineGadget H d t) (gate : Nat)
    (hgate : gate < tail.g.circuit.gates.size) :
    orderedGlitchFrontier (registeredComposite up.g tail.ports).circuit
        (embeddedTailGate up.g tail.ports gate) =
      (orderedGlitchFrontier tail.g.circuit gate).map
        (embeddedTailGate up.g tail.ports) := by
  induction gate using Nat.strongRecOn with
  | ind gate ih =>
      cases hconnected : connectedShare? tail.ports gate with
      | some share =>
          have hshareMem := List.mem_of_find?_eq_some hconnected
          have hshare : share < tail.g.d := by
            simpa [connectedShare?] using hshareMem
          have hgateEq : tail.ports.inputGate share = gate := by
            have := List.find?_some hconnected
            simpa [connectedShare?] using this
          obtain ⟨sharing, htailEntry, _⟩ :=
            tail.ports.input_source_coherent share hshare
          rw [hgateEq] at htailEntry
          have hboundary := registeredComposite_boundary_gate up.g
            tail.ports share hshare
          have hboundary' := hboundary
          change (registeredComposite up.g tail.ports).circuit.gates[
              boundaryRegister up.g share]? =
            some ⟨.reg, [((up.g.output share).gate, 1)]⟩ at hboundary'
          have hembedded : embeddedTailGate up.g tail.ports gate =
              boundaryRegister up.g share := by
            simp [embeddedTailGate, hconnected]
          rw [orderedGlitchFrontier_of_some _ _ _ htailEntry,
            hembedded,
            orderedGlitchFrontier_of_some _ _ _ hboundary']
          simp only [List.filter_cons, Nat.reduceBEq, Bool.false_eq_true,
            if_false, List.filter_nil, List.isEmpty_nil, if_true,
            List.map_singleton, hembedded]
      | none =>
          have hsuffix := registeredComposite_suffix_gate_frontier up tail
            gate hgate
          obtain ⟨entry, htailEntry⟩ : ∃ entry,
              tail.g.circuit.gates[gate]? = some entry := by
            exact ⟨tail.g.circuit.gates[gate],
              Array.getElem?_eq_getElem hgate⟩
          have hcompEntry :
              (registeredComposite up.g tail.ports).circuit.gates[
                  embeddedTailGate up.g tail.ports gate]? =
                some (wireRegisteredDownGate (up := up.g) tail.ports
                  gate entry) := by
            simpa [embeddedTailGate, hconnected, wireRegisteredDownGate,
              htailEntry] using hsuffix
          rw [orderedGlitchFrontier_of_some _ _ _ hcompEntry,
            orderedGlitchFrontier_of_some _ _ _ htailEntry]
          simp only [wireRegisteredDownGate, hconnected]
          let inputs := entry.inputs.filter fun input => input.2 == 0
          have hfiltered :
              (entry.inputs.map
                    (wireRegisteredEdge (up := up.g) tail.ports)).filter
                  (fun input => input.2 == 0) =
                inputs.map (wireRegisteredEdge (up := up.g) tail.ports) := by
            rw [List.filter_map]
            congr 1
            apply List.filter_congr
            intro input _
            unfold Function.comp wireRegisteredEdge
            split <;> rfl
          rw [hfiltered]
          change
            (if (inputs.map
                  (wireRegisteredEdge (up := up.g) tail.ports)).isEmpty = true
              then [embeddedTailGate up.g tail.ports gate]
              else
                ((inputs.map
                    (wireRegisteredEdge (up := up.g) tail.ports)).flatMap
                    fun input =>
                      if hlt : input.1 <
                          embeddedTailGate up.g tail.ports gate then
                        orderedGlitchFrontier
                          (registeredComposite up.g tail.ports).circuit input.1
                      else [input.1]).eraseDups) =
              (if inputs.isEmpty = true then [gate]
                else
                  (inputs.flatMap fun input =>
                    if hlt : input.1 < gate then
                      orderedGlitchFrontier tail.g.circuit input.1
                    else [input.1]).eraseDups).map
                (embeddedTailGate up.g tail.ports)
          by_cases hempty : inputs.isEmpty = true
          · have hmappedEmpty :
                (inputs.map (wireRegisteredEdge (up := up.g)
                  tail.ports)).isEmpty = true := by
              simpa using hempty
            simp only [hempty, hmappedEmpty, if_true, List.map_singleton]
          · have hmappedEmpty :
                (inputs.map (wireRegisteredEdge (up := up.g) tail.ports)).isEmpty =
                  false := by
              simpa using hempty
            simp only [hempty, hmappedEmpty, Bool.false_eq_true, if_false]
            rw [List.flatMap_map,
              ← eraseDups_map_injective
                (embeddedTailGate up.g tail.ports)
                (embeddedTailGate_injective up.g tail.ports),
              List.map_flatMap]
            apply congrArg List.eraseDups
            apply flatMap_congr_of_mem_local
            intro input hinput
            have hinput' := List.mem_filter.mp hinput
            have hzero : input.2 = 0 := by simpa using hinput'.2
            have hlt := forwardCombinational_input_lt tail.g
              tail.forward_combinational gate entry htailEntry input
              hinput'.1 hzero
            have hwireMem :
                wireRegisteredEdge (up := up.g) tail.ports input ∈
                  entry.inputs.map
                    (wireRegisteredEdge (up := up.g) tail.ports) :=
              List.mem_map.mpr ⟨input, hinput'.1, rfl⟩
            have hwireZero :
                (wireRegisteredEdge (up := up.g) tail.ports input).2 = 0 := by
              unfold wireRegisteredEdge
              split <;> exact hzero
            have hcompRawLt := forwardCombinational_input_lt
              (registeredComposite up.g tail.ports)
              (registeredComposite_forwardCombinational up tail)
              (embeddedTailGate up.g tail.ports gate)
              (wireRegisteredDownGate (up := up.g) tail.ports gate entry)
              hcompEntry
              (wireRegisteredEdge (up := up.g) tail.ports input)
              (by simpa [wireRegisteredDownGate, hconnected] using hwireMem)
              hwireZero
            have hcompLt :
                embeddedTailGate up.g tail.ports input.1 <
                  embeddedTailGate up.g tail.ports gate := by
              calc
                embeddedTailGate up.g tail.ports input.1 =
                    (wireRegisteredEdge (up := up.g) tail.ports input).1 :=
                  embeddedTailGate_eq_wire_fst up.g tail.ports input.1 input.2
                _ < embeddedTailGate up.g tail.ports gate := hcompRawLt
            simp only [hcompRawLt, hlt, ↓reduceDIte]
            rw [← embeddedTailGate_eq_wire_fst up.g tail.ports
              input.1 input.2]
            exact ih input.1 hlt (by omega)

private theorem embeddedTailNode_injective {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down) :
    Function.Injective (embeddedTailNode up ports) := by
  intro left right heq
  cases left with
  | mk leftGate leftCycle =>
      cases right with
      | mk rightGate rightCycle =>
          simp only [embeddedTailNode, Node.mk.injEq] at heq ⊢
          exact ⟨embeddedTailGate_injective up ports heq.1, heq.2⟩

private theorem glitch_prefix {H d t : Nat}
    (up tail : PipelineGadget H d t) (node : Node)
    (hgate : node.gate < up.g.circuit.gates.size) :
    Expansion.glitch (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon node =
      Expansion.glitch up.g.circuit up.g.horizon node := by
  unfold Expansion.glitch
  change
    (Expansion.glitchGates (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).circuit.gates.size
      node.gate).map (fun gate =>
        ({ gate := gate, cycle := node.cycle } : Node)) =
    (Expansion.glitchGates up.g.circuit up.g.circuit.gates.size
      node.gate).map (fun gate =>
        ({ gate := gate, cycle := node.cycle } : Node))
  have hcompGate : node.gate <
      (registeredComposite up.g tail.ports).circuit.gates.size := by
    simp [registeredComposite, registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, boundaryRegisterGates,
      registeredDownGates]
    omega
  rw [glitchGates_eq_orderedGlitchFrontier
      (registeredComposite up.g tail.ports)
      (registeredComposite_forwardCombinational up tail)
      node.gate _ hcompGate,
    glitchGates_eq_orderedGlitchFrontier up.g up.forward_combinational
      node.gate _ hgate,
    orderedGlitchFrontier_prefix up tail node.gate hgate]

private theorem glitch_tail {H d t : Nat}
    (up tail : PipelineGadget H d t) (node : Node)
    (hgate : node.gate < tail.g.circuit.gates.size) :
    Expansion.glitch (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon
        (embeddedTailNode up.g tail.ports node) =
      (Expansion.glitch tail.g.circuit tail.g.horizon node).map
        (embeddedTailNode up.g tail.ports) := by
  have hcompGate : (embeddedTailNode up.g tail.ports node).gate <
      (registeredComposite up.g tail.ports).circuit.gates.size := by
    cases hconnected : connectedShare? tail.ports node.gate with
    | some share =>
        have hshareMem := List.mem_of_find?_eq_some hconnected
        have hshare : share < tail.g.d := by
          simpa [connectedShare?] using hshareMem
        simp [embeddedTailNode, embeddedTailGate, hconnected,
          registeredComposite, registeredCompositeCircuit,
          UniversalSStage1.appendCircuit, boundaryRegister,
          boundaryRegisterGates, registeredDownGates]
        omega
    | none =>
        simp [embeddedTailNode, embeddedTailGate, hconnected,
          registeredComposite, registeredCompositeCircuit,
          UniversalSStage1.appendCircuit, downstreamOffset,
          boundaryRegisterGates, registeredDownGates]
        omega
  change
    (Expansion.glitchGates (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).circuit.gates.size
      (embeddedTailGate up.g tail.ports node.gate)).map
        (fun gate => { gate := gate, cycle := node.cycle }) =
      ((Expansion.glitchGates tail.g.circuit tail.g.circuit.gates.size
        node.gate).map (fun gate => { gate := gate, cycle := node.cycle })).map
        (embeddedTailNode up.g tail.ports)
  rw [glitchGates_eq_orderedGlitchFrontier
      (registeredComposite up.g tail.ports)
      (registeredComposite_forwardCombinational up tail)
      (embeddedTailGate up.g tail.ports node.gate) _ hcompGate,
    glitchGates_eq_orderedGlitchFrontier tail.g tail.forward_combinational
      node.gate _ hgate,
    orderedGlitchFrontier_tail up tail node.gate hgate,
    List.map_map, List.map_map]
  rfl

private theorem transitionGlitch_prefix {H d t : Nat}
    (up tail : PipelineGadget H d t) (node : Node)
    (hgate : node.gate < up.g.circuit.gates.size) :
    transitionGlitch (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon node =
      transitionGlitch up.g.circuit up.g.horizon node := by
  have htransition :
      Expansion.transition (registeredComposite up.g tail.ports).circuit
          (registeredComposite up.g tail.ports).horizon node =
        Expansion.transition up.g.circuit up.g.horizon node := by
    simp [Expansion.transition, registeredComposite, up.horizon_eq,
      tail.horizon_eq]
  simp only [transitionGlitch, Expansion.compose, htransition]
  apply congrArg List.eraseDups
  apply flatMap_congr_of_mem_local
  intro expanded hexpanded
  have hexpGate : expanded.gate = node.gate := by
    simp only [Expansion.transition] at hexpanded
    split at hexpanded
    · simp only [List.mem_cons, List.mem_singleton] at hexpanded
      rcases hexpanded with hprev | hcurrent | hempty
      · subst expanded
        rfl
      · subst expanded
        rfl
      · simp at hempty
    · simp only [List.mem_singleton] at hexpanded
      subst expanded
      rfl
  apply glitch_prefix up tail expanded
  simpa [hexpGate] using hgate

private theorem transitionGlitch_tail {H d t : Nat}
    (up tail : PipelineGadget H d t) (node : Node)
    (hgate : node.gate < tail.g.circuit.gates.size) :
    transitionGlitch (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon
        (embeddedTailNode up.g tail.ports node) =
      (transitionGlitch tail.g.circuit tail.g.horizon node).map
        (embeddedTailNode up.g tail.ports) := by
  have htransition :
      Expansion.transition (registeredComposite up.g tail.ports).circuit
          (registeredComposite up.g tail.ports).horizon
          (embeddedTailNode up.g tail.ports node) =
        (Expansion.transition tail.g.circuit tail.g.horizon node).map
          (embeddedTailNode up.g tail.ports) := by
    cases node with
    | mk gate cycle =>
        by_cases hinside : 0 < cycle ∧ cycle < H <;>
          simp [Expansion.transition, embeddedTailNode, registeredComposite,
            up.horizon_eq, tail.horizon_eq, hinside]
  simp only [transitionGlitch, Expansion.compose, htransition,
    List.flatMap_map]
  rw [show
      (Expansion.transition tail.g.circuit tail.g.horizon node).flatMap
          (fun expanded => Expansion.glitch
            (registeredComposite up.g tail.ports).circuit
            (registeredComposite up.g tail.ports).horizon
            (embeddedTailNode up.g tail.ports expanded)) =
        (Expansion.transition tail.g.circuit tail.g.horizon node).flatMap
          (fun expanded =>
            (Expansion.glitch tail.g.circuit tail.g.horizon expanded).map
              (embeddedTailNode up.g tail.ports)) by
    apply flatMap_congr_of_mem_local
    intro expanded hexpanded
    have hexpGate : expanded.gate = node.gate := by
      simp only [Expansion.transition] at hexpanded
      split at hexpanded
      · simp only [List.mem_cons, List.mem_singleton] at hexpanded
        rcases hexpanded with hprev | hcurrent | hempty
        · subst expanded
          rfl
        · subst expanded
          rfl
        · simp at hempty
      · simp only [List.mem_singleton] at hexpanded
        subst expanded
        rfl
    apply glitch_tail up tail expanded
    simpa [hexpGate] using hgate]
  rw [← List.map_flatMap,
    eraseDups_map_injective (embeddedTailNode up.g tail.ports)
      (embeddedTailNode_injective up.g tail.ports)]

/-! ## E4: one-for-one probe partition

The registered compiler has three consecutive gate regions.  These small
classifiers partition *probe sites* before expansion; keeping that operation
one-for-one is what preserves the global PINI budget.  Boundary-register
sites and literal upstream-output sites become upstream output-share demands,
while neutralized connected tail inputs contribute only the constant value.
-/

/-- Recover the share of a declared output node, when the node is one. -/
def outputShare? {H d t : Nat} (P : PipelineGadget H d t)
    (node : Node) : Option Nat :=
  (List.range d).find? fun share => P.g.output share == node

/-- Upstream sites which remain ordinary upstream internal probes, in the
order in which the composite probe list presents them. -/
def partitionUpInternalRaw {H d t : Nat} (up : PipelineGadget H d t)
    (probes : List Node) : List Node :=
  probes.filterMap fun node =>
    if node.gate < up.g.circuit.gates.size then
      match outputShare? up node with
      | some _ => none
      | none => some node
    else none

/-- Raw upstream-output demands, before canonical duplicate elimination. -/
def partitionUpDemandsRaw {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) : List Nat :=
  probes.filterMap fun node =>
    if node.gate < up.g.circuit.gates.size then
      outputShare? up node
    else if node.gate < downstreamOffset up.g tail.g then
      some (node.gate - up.g.circuit.gates.size)
    else none

/-- Upstream-output shares demanded either directly or by a boundary register. -/
def partitionUpDemands {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) : List Nat :=
  shareUnion d (partitionUpDemandsRaw up tail probes) []

/-- Surviving suffix sites, translated back to isolated-tail numbering, in
the order in which the composite probe list presents them. -/
def partitionTailInternalRaw {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) : List Node :=
  probes.filterMap fun node =>
    if downstreamOffset up.g tail.g ≤ node.gate then
      let tailNode : Node :=
        { gate := node.gate - downstreamOffset up.g tail.g
          cycle := node.cycle }
      match connectedShare? tail.ports tailNode.gate with
      | some _ => none
      | none => some tailNode
    else none

/-- Canonical upstream internal subset, in `internalNodes` enumeration order. -/
def partitionUpInternal {H d t : Nat} (up : PipelineGadget H d t)
    (probes : List Node) : List Node :=
  (internalNodes up.g).filter fun node =>
    (partitionUpInternalRaw up probes).contains node

/-- Canonical tail internal subset, in `internalNodes` enumeration order. -/
def partitionTailInternal {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) : List Node :=
  (internalNodes tail.g).filter fun node =>
    (partitionTailInternalRaw up tail probes).contains node

private theorem length_filterMap_le_local (f : α → Option β) :
    ∀ xs : List α, (xs.filterMap f).length ≤ xs.length := by
  intro xs
  induction xs with
  | nil => simp
  | cons x xs ih =>
      cases h : f x <;> simp [h] <;> omega

private theorem nodup_length_le_of_subset_local [BEq α] [LawfulBEq α]
    (xs ys : List α) (hn : xs.Nodup)
    (hsubset : ∀ x ∈ xs, x ∈ ys) : xs.length ≤ ys.length := by
  induction xs generalizing ys with
  | nil => simp
  | cons x xs ih =>
      have hx : x ∈ ys := hsubset x (by simp)
      have hn' := List.nodup_cons.mp hn
      have htail : ∀ y ∈ xs, y ∈ ys.erase x := by
        intro y hy
        have hyx : y ≠ x := by
          intro heq
          subst y
          exact hn'.1 hy
        simp [hyx, hsubset y (by simp [hy])]
      have hrec := ih (ys.erase x) hn'.2 htail
      rw [List.length_erase_of_mem hx] at hrec
      simp only [List.length_cons]
      have hpos : 0 < ys.length := List.length_pos_of_mem hx
      omega

theorem partitionUpDemands_length_le {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) :
    (partitionUpDemands up tail probes).length ≤ probes.length := by
  have hmem : ∀ share ∈ partitionUpDemandsRaw up tail probes, share < d := by
    intro share hshare
    rw [partitionUpDemandsRaw, List.mem_filterMap] at hshare
    rcases hshare with ⟨node, _hnode, hclassified⟩
    by_cases hup : node.gate < up.g.circuit.gates.size
    · simp only [hup, if_pos] at hclassified
      cases houtput : outputShare? up node with
      | none => simp [houtput] at hclassified
      | some outputShare =>
          simp [houtput] at hclassified
          subst outputShare
          have hfound := List.mem_of_find?_eq_some houtput
          simpa [outputShare?] using hfound
    · simp only [hup, if_neg] at hclassified
      by_cases hboundary : node.gate < downstreamOffset up.g tail.g
      · simp [hboundary] at hclassified
        subst share
        unfold downstreamOffset at hboundary
        simpa [tail.d_eq] using Nat.sub_lt_left_of_lt_add
          (Nat.le_of_not_gt hup) hboundary
      · simp [hboundary] at hclassified
  have hunion := shareUnion_length_le d
    (partitionUpDemandsRaw up tail probes) [] hmem (by simp)
  exact Nat.le_trans
    (by simpa [partitionUpDemands, partitionUpDemandsRaw] using hunion)
    (length_filterMap_le_local _ probes)

theorem partitionUpDemands_sublist {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) :
    (partitionUpDemands up tail probes).Sublist (List.range d) := by
  exact shareUnion_sublist d (partitionUpDemandsRaw up tail probes) []

theorem partitionUpInternal_length_le {H d t : Nat}
    (up : PipelineGadget H d t) (probes : List Node) :
    (partitionUpInternal up probes).length ≤ probes.length := by
  apply Nat.le_trans
  · apply nodup_length_le_of_subset_local _
      (partitionUpInternalRaw up probes)
    · exact (memberNodes_nodup up.g).filter _ |>.filter _
    · intro node hnode
      simpa [partitionUpInternal] using (List.mem_filter.mp hnode).2
  · exact length_filterMap_le_local _ probes

theorem partitionTailInternal_length_le {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) :
    (partitionTailInternal up tail probes).length ≤ probes.length := by
  apply Nat.le_trans
  · apply nodup_length_le_of_subset_local _
      (partitionTailInternalRaw up tail probes)
    · exact (memberNodes_nodup tail.g).filter _ |>.filter _
    · intro node hnode
      simpa [partitionTailInternal] using (List.mem_filter.mp hnode).2
  · exact length_filterMap_le_local _ probes

theorem partitionUpInternal_sublist {H d t : Nat}
    (up : PipelineGadget H d t) (probes : List Node) :
    (partitionUpInternal up probes).Sublist (internalNodes up.g) := by
  exact List.filter_sublist

theorem partitionTailInternal_sublist {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) :
    (partitionTailInternal up tail probes).Sublist (internalNodes tail.g) := by
  exact List.filter_sublist

/-- E4 budget partition: every registered probe site enters at most one
component list.  Erasing duplicate share demands can only reduce the total. -/
theorem expansion_partition_length {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) :
    (partitionUpInternal up probes).length +
        (partitionUpDemands up tail probes).length +
        (partitionTailInternal up tail probes).length ≤ probes.length := by
  have hraw :
      (partitionUpInternalRaw up probes).length +
          (partitionUpDemandsRaw up tail probes).length +
          (partitionTailInternalRaw up tail probes).length ≤ probes.length := by
    induction probes with
    | nil => simp [partitionUpInternalRaw, partitionUpDemandsRaw,
        partitionTailInternalRaw]
    | cons node probes ih =>
        by_cases hup : node.gate < up.g.circuit.gates.size
        · have hnotTail : ¬ downstreamOffset up.g tail.g ≤ node.gate := by
            unfold downstreamOffset
            omega
          cases hout : outputShare? up node <;>
            simp [partitionUpInternalRaw, partitionUpDemandsRaw,
              partitionTailInternalRaw, hup, hout, hnotTail] at ih ⊢ <;>
            omega
        · by_cases hboundary : node.gate < downstreamOffset up.g tail.g
          · have hnotTail : ¬ downstreamOffset up.g tail.g ≤ node.gate := by
              omega
            simp [partitionUpInternalRaw, partitionUpDemandsRaw,
              partitionTailInternalRaw, hup, hboundary, hnotTail] at ih ⊢
            omega
          · have htail : downstreamOffset up.g tail.g ≤ node.gate := by omega
            let tailNode : Node :=
              { gate := node.gate - downstreamOffset up.g tail.g
                cycle := node.cycle }
            cases hconnected : connectedShare? tail.ports tailNode.gate <;>
              simp [partitionUpInternalRaw, partitionUpDemandsRaw,
                partitionTailInternalRaw, hup, hboundary, htail, tailNode,
                hconnected] at ih ⊢ <;>
              omega
  have hmem : ∀ share ∈ partitionUpDemandsRaw up tail probes, share < d := by
    intro share hshare
    rw [partitionUpDemandsRaw, List.mem_filterMap] at hshare
    rcases hshare with ⟨node, _hnode, hclassified⟩
    by_cases hup : node.gate < up.g.circuit.gates.size
    · simp only [hup, if_pos] at hclassified
      cases houtput : outputShare? up node with
      | none => simp [houtput] at hclassified
      | some outputShare =>
          simp [houtput] at hclassified
          subst outputShare
          have hfound := List.mem_of_find?_eq_some houtput
          simpa [outputShare?] using hfound
    · simp only [hup, if_neg] at hclassified
      by_cases hboundary : node.gate < downstreamOffset up.g tail.g
      · simp [hboundary] at hclassified
        subst share
        unfold downstreamOffset at hboundary
        simpa [tail.d_eq] using Nat.sub_lt_left_of_lt_add
          (Nat.le_of_not_gt hup) hboundary
      · simp [hboundary] at hclassified
  have hcanonical := shareUnion_length_le d
    (partitionUpDemandsRaw up tail probes) [] hmem (by simp)
  have hupShrink : (partitionUpInternal up probes).length ≤
      (partitionUpInternalRaw up probes).length := by
    apply nodup_length_le_of_subset_local
    · exact (memberNodes_nodup up.g).filter _ |>.filter _
    · intro node hnode
      simpa [partitionUpInternal] using (List.mem_filter.mp hnode).2
  have htailShrink : (partitionTailInternal up tail probes).length ≤
      (partitionTailInternalRaw up tail probes).length := by
    apply nodup_length_le_of_subset_local
    · exact (memberNodes_nodup tail.g).filter _ |>.filter _
    · intro node hnode
      simpa [partitionTailInternal] using (List.mem_filter.mp hnode).2
  have hdemandShrink : (partitionUpDemands up tail probes).length ≤
      (partitionUpDemandsRaw up tail probes).length := by
    simpa [partitionUpDemands] using hcanonical
  omega

/-- The three E4 pieces are genuine executable subset witnesses at the
original probe budget. -/
theorem expansion_partition_admissible {H d t : Nat}
    (up tail : PipelineGadget H d t) (probes : List Node) :
    partitionUpInternal up probes ∈
        subsetsUpTo probes.length (internalNodes up.g) ∧
      partitionTailInternal up tail probes ∈
        subsetsUpTo probes.length (internalNodes tail.g) ∧
      partitionUpDemands up tail probes ∈
        subsetsUpTo probes.length (List.range d) := by
  refine ⟨mem_subsetsUpTo_of_sublist
      (partitionUpInternal_sublist up probes)
      (partitionUpInternal_length_le up probes),
    mem_subsetsUpTo_of_sublist
      (partitionTailInternal_sublist up tail probes)
      (partitionTailInternal_length_le up tail probes), ?_⟩
  exact mem_subsetsUpTo_of_sublist
    (partitionUpDemands_sublist up tail probes)
    (partitionUpDemands_length_le up tail probes)

/-! ## Observation-level E4 assembly -/

/-- Read the value attached to a node in a component transcript.  Missing
nodes deliberately read as `false`, matching the evaluator's out-of-domain
convention and the neutralized connected input gates of the compiler. -/
def observationAt : List Node → Observation → Node → Bool
  | [], _, _ => false
  | _, [], _ => false
  | head :: nodes, value :: values, node =>
      if head == node then value else observationAt nodes values node

private theorem observationAt_observe_of_mem (g : GadgetInstance)
    (nodes : List Node) (env : Env) (node : Node) (hnode : node ∈ nodes) :
    observationAt nodes (observe g nodes env) node =
      Execution.eval g.circuit g.horizon env node := by
  induction nodes with
  | nil => simp at hnode
  | cons head nodes ih =>
      simp only [List.mem_cons] at hnode
      by_cases heq : head = node
      · subst head
        simp [observationAt, observe_eq_map_eval]
      · have htail : node ∈ nodes := hnode.resolve_left (Ne.symm heq)
        simpa [observationAt, observe_eq_map_eval, heq] using ih htail

private theorem eval_embeddedTailNode {H d t : Nat}
    (up tail : PipelineGadget H d t) (env : Env) (node : Node)
    (hnode : node.gate < tail.g.circuit.gates.size) :
    Execution.eval (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env
        (embeddedTailNode up.g tail.ports node) =
      Execution.eval tail.g.circuit tail.g.horizon
        (substitutedTailEnv up.g tail.g tail.ports env) node := by
  change Execution.eval (registeredCompositeCircuit up.g tail.ports)
      (max up.g.horizon tail.g.horizon) env
      (embeddedTailNode up.g tail.ports node) = _
  rw [up.horizon_eq, tail.horizon_eq, Nat.max_self]
  have hcompGate : (embeddedTailNode up.g tail.ports node).gate <
      (registeredCompositeCircuit up.g tail.ports).gates.size := by
    cases hconnected : connectedShare? tail.ports node.gate with
    | some share =>
        have hshareMem := List.mem_of_find?_eq_some hconnected
        have hshare : share < tail.g.d := by
          simpa [connectedShare?] using hshareMem
        simp [embeddedTailNode, embeddedTailGate, hconnected,
          registeredCompositeCircuit, UniversalSStage1.appendCircuit,
          boundaryRegister, boundaryRegisterGates, registeredDownGates]
        omega
    | none =>
        simp [embeddedTailNode, embeddedTailGate, hconnected,
          registeredCompositeCircuit, UniversalSStage1.appendCircuit,
          downstreamOffset, boundaryRegisterGates, registeredDownGates]
        omega
  by_cases hcycle : node.cycle < H
  · rw [Execution.eval, if_pos (by
      simp only [Bool.and_eq_true, decide_eq_true_eq]
      exact ⟨hcompGate, by simpa [embeddedTailNode] using hcycle⟩)]
    rw [Execution.eval, if_pos (by simp [hnode, hcycle])]
    rw [← UniversalSStage1.evalEntries_eq_execution,
      ← UniversalSStage1.evalEntries_eq_execution]
    have hagree := evalEntries_tail_tablesAgree up tail env H (Nat.le_refl H)
    have hlookup := hagree node hnode
    exact congrArg (fun value => value.getD false) hlookup
  · simp [Execution.eval, embeddedTailNode, hcycle]

/-- Node list observed by the upstream O-PINI certificate in the E6 stack. -/
def upstreamTranscriptNodes {H d t : Nat} (up : PipelineGadget H d t)
    (internal : List Node) (demanded witness : List Nat) : List Node :=
  ((expandedNodes up.g transitionGlitch
      (internal ++ demanded.map up.g.output)) ++
    demanded.map up.g.output ++ witness.map up.g.output).eraseDups

/-- Node list observed by the carried tail PINI certificate. -/
def tailTranscriptNodes {H d t : Nat} (tail : PipelineGadget H d t)
    (internal : List Node) (outputs : List Nat) : List Node :=
  expandedNodes tail.g transitionGlitch
    (internal ++ outputs.map tail.g.output)

/-- Recover the isolated tail node represented by a compiled node, preferring
the exact transported tail transcript when a boundary register was reached
through a downstream glitch cone. -/
def tailTranscriptPreimage? {H d t : Nat}
    (up tail : PipelineGadget H d t) (tailNodes : List Node)
    (node : Node) : Option Node :=
  tailNodes.find? fun tailNode =>
    embeddedTailNode up.g tail.ports tailNode == node

/-- Deterministic decoder from the two component transcripts to one compiled
node value.  E4 proves that every expanded compiled node takes one of these
four routes: literal prefix, transported tail, direct boundary register, or
neutralized connected-input constant. -/
def reconstructPipelineNode {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (upNodes tailNodes : List Node) (upValues tailValues : Observation)
    (node : Node) : Bool :=
  if node.gate < up.g.circuit.gates.size then
    observationAt upNodes upValues node
  else
    match tailTranscriptPreimage? up tail tailNodes node with
    | some tailNode => observationAt tailNodes tailValues tailNode
    | none =>
        if node.gate < downstreamOffset up.g tail.g then
          if node.cycle = tail.ports.arrivalCycle then
            observationAt upNodes upValues
              (up.g.output (node.gate - up.g.circuit.gates.size))
          else false
        else false

def reconstructPipelineObservation {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (upNodes tailNodes compositeNodes : List Node)
    (upValues tailValues : Observation) : Observation :=
  compositeNodes.map
    (reconstructPipelineNode up tail upNodes tailNodes upValues tailValues)

private theorem tailTranscriptPreimage?_of_mem {H d t : Nat}
    (up tail : PipelineGadget H d t) (tailNodes : List Node)
    (tailNode : Node) (hmem : tailNode ∈ tailNodes) :
    ∃ found, tailTranscriptPreimage? up tail tailNodes
        (embeddedTailNode up.g tail.ports tailNode) = some found ∧
      found = tailNode := by
  cases hfind : tailTranscriptPreimage? up tail tailNodes
      (embeddedTailNode up.g tail.ports tailNode) with
  | none =>
      exfalso
      simp only [tailTranscriptPreimage?] at hfind
      have hnone := List.find?_eq_none.mp hfind tailNode hmem
      simp at hnone
  | some found =>
      refine ⟨found, rfl, ?_⟩
      have hfind' := hfind
      simp only [tailTranscriptPreimage?] at hfind'
      have hfound := List.find?_some hfind'
      have heq : embeddedTailNode up.g tail.ports found =
          embeddedTailNode up.g tail.ports tailNode := by
        simpa using hfound
      exact embeddedTailNode_injective up.g tail.ports heq

/-- Static coverage certificate consumed by the deterministic E4 decoder. -/
def PipelineNodeCovered {H d t : Nat}
    (up tail : PipelineGadget H d t) (upNodes tailNodes : List Node)
    (node : Node) : Prop :=
  (node.gate < up.g.circuit.gates.size ∧ node ∈ upNodes) ∨
  (∃ tailNode ∈ tailNodes,
    embeddedTailNode up.g tail.ports tailNode = node) ∨
  (∃ share, share < d ∧
    node.gate = boundaryRegister up.g share ∧
    (node.cycle ≠ tail.ports.arrivalCycle ∨
      up.g.output share ∈ upNodes)) ∨
  (∃ gate, gate < tail.g.circuit.gates.size ∧
    connectedShare? tail.ports gate ≠ none ∧
    node.gate = downstreamOffset up.g tail.g + gate)

private theorem reconstructPipelineNode_eq_eval {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (upNodes tailNodes : List Node) (env : Env)
    (x : List Bool) (hx : x ∈ boolVectors (inputWidth up.g))
    (hupEnv : restrictEnv
        (Execution.relevantSrcs up.g.circuit up.g.horizon) env ∈
      envsForInput up.g x)
    (hinit : ∀ share, share < d →
      env (.iniReg (boundaryRegister up.g share)) = false)
    (htailBound : ∀ tailNode ∈ tailNodes,
      tailNode.gate < tail.g.circuit.gates.size)
    (node : Node) (hnodeCycle : node.cycle < H)
    (hcovered : PipelineNodeCovered up tail upNodes tailNodes node) :
    reconstructPipelineNode up tail upNodes tailNodes
        (observe up.g upNodes
          (restrictEnv
            (Execution.relevantSrcs up.g.circuit up.g.horizon) env))
        (observe tail.g tailNodes
          (substitutedTailEnv up.g tail.g tail.ports env)) node =
      Execution.eval (registeredComposite up.g tail.ports).circuit
        (registeredComposite up.g tail.ports).horizon env node := by
  unfold reconstructPipelineNode
  by_cases hprefix : node.gate < up.g.circuit.gates.size
  · rw [if_pos hprefix]
    have hmem : node ∈ upNodes := by
      rcases hcovered with h | h | h | h
      · exact h.2
      · rcases h with ⟨tailNode, _hmem, heq⟩
        subst node
        cases hc : connectedShare? tail.ports tailNode.gate <;>
          simp [embeddedTailNode, embeddedTailGate, hc, boundaryRegister,
            downstreamOffset] at hprefix
        all_goals omega
      · rcases h with ⟨share, _hshare, hgate, _⟩
        rw [hgate] at hprefix
        simp [boundaryRegister] at hprefix
        omega
      · rcases h with ⟨gate, _hgate, _hconnected, hgateEq⟩
        rw [hgateEq] at hprefix
        simp [downstreamOffset] at hprefix
        omega
    rw [observationAt_observe_of_mem up.g upNodes _ node hmem]
    symm
    exact eval_restrict_upstream up tail env node hprefix
  · rw [if_neg hprefix]
    cases hfind : tailTranscriptPreimage? up tail tailNodes node with
    | some tailNode =>
        simp only [hfind]
        have hmem : tailNode ∈ tailNodes := by
          have hfind' := hfind
          simp only [tailTranscriptPreimage?] at hfind'
          exact List.mem_of_find?_eq_some hfind'
        have hfind' := hfind
        simp only [tailTranscriptPreimage?] at hfind'
        have hmatches := List.find?_some hfind'
        have heq : embeddedTailNode up.g tail.ports tailNode = node := by
          simpa using hmatches
        rw [observationAt_observe_of_mem tail.g tailNodes _ tailNode hmem]
        rw [← heq]
        exact (eval_embeddedTailNode up tail env tailNode
          (htailBound tailNode hmem)).symm
    | none =>
        rcases hcovered with h | h | h | h
        · exact (hprefix h.1).elim
        · rcases h with ⟨tailNode, hmem, heq⟩
          subst node
          obtain ⟨found, hsome, _⟩ :=
            tailTranscriptPreimage?_of_mem up tail tailNodes tailNode hmem
          rw [hsome] at hfind
          contradiction
        · rcases h with ⟨share, hshare, hgate, hoffOrMem⟩
          have hboundary : node.gate < downstreamOffset up.g tail.g := by
            rw [hgate]
            simp [boundaryRegister, downstreamOffset]
            simpa [tail.d_eq] using hshare
          rw [if_pos hboundary]
          by_cases hcycle : node.cycle = tail.ports.arrivalCycle
          · rw [if_pos hcycle]
            have houtputMem : up.g.output share ∈ upNodes := by
              rcases hoffOrMem with hoff | hmem
              · exact (hoff hcycle).elim
              · exact hmem
            have hsub : node.gate - up.g.circuit.gates.size = share := by
              rw [hgate]
              simp [boundaryRegister]
            rw [hsub]
            rw [observationAt_observe_of_mem up.g upNodes _ _ houtputMem]
            have hnodeEq : node =
                { gate := boundaryRegister up.g share,
                  cycle := tail.ports.arrivalCycle } := by
              cases node
              simp_all
            rw [hnodeEq]
            exact (eval_boundary_register up tail glue env share hshare).symm
          · rw [if_neg hcycle]
            have hnodeEq : node =
                { gate := boundaryRegister up.g share,
                  cycle := node.cycle } := by
              cases node
              simp_all
            rw [hnodeEq]
            exact (eval_boundary_register_off up tail glue env share hshare
              x hx hupEnv (hinit share hshare) _ hnodeCycle hcycle).symm
        · rcases h with ⟨gate, hgate, hconnected, hgateEq⟩
          have hnotBoundary : ¬ node.gate < downstreamOffset up.g tail.g := by
            rw [hgateEq]
            omega
          rw [if_neg hnotBoundary]
          obtain ⟨share, hshareEq⟩ : ∃ share,
              connectedShare? tail.ports gate = some share := by
            cases hc : connectedShare? tail.ports gate with
            | none => exact (hconnected hc).elim
            | some share => exact ⟨share, rfl⟩
          have hnodeEq : node =
              { gate := downstreamOffset up.g tail.g + gate,
                cycle := node.cycle } := by
            cases node
            simp_all
          rw [hnodeEq]
          apply (eval_const_false
            (registeredComposite up.g tail.ports).circuit
            (registeredComposite up.g tail.ports).horizon env
            (downstreamOffset up.g tail.g + gate) node.cycle
            (registeredComposite_connected_const up tail gate share hgate
              hshareEq) ?_).symm
          simpa [registeredComposite, up.horizon_eq, tail.horizon_eq] using hnodeCycle

private theorem memberNode_bounds (g : GadgetInstance) (node : Node)
    (hnode : node ∈ memberNodes g) :
    node.gate < g.circuit.gates.size ∧ node.cycle < g.horizon := by
  have hnodes := (List.mem_filter.mp hnode).1
  rw [nodes, List.mem_flatMap] at hnodes
  rcases hnodes with ⟨cycle, hcycle, hgate⟩
  rw [List.mem_map] at hgate
  rcases hgate with ⟨gate, hgate, heq⟩
  subst node
  simpa using And.intro hgate hcycle

private theorem memberNode_of_bounds (g : GadgetInstance)
    (hwhole : WholeWindow g) (node : Node)
    (hgate : node.gate < g.circuit.gates.size)
    (hcycle : node.cycle < g.horizon) : node ∈ memberNodes g := by
  rw [memberNodes, List.mem_filter]
  have hnodes : node ∈ nodes g := by
    rw [nodes, List.mem_flatMap]
    exact ⟨node.cycle, by simpa, List.mem_map.mpr
      ⟨node.gate, by simpa, by cases node <;> rfl⟩⟩
  exact ⟨hnodes, hwhole node hnodes⟩

private theorem mem_expandedNodes_iff_of_wholeWindow
    (g : GadgetInstance)
    (probes : List Node) (node : Node) :
    node ∈ memberNodes g →
    (node ∈ expandedNodes g transitionGlitch probes ↔
      ∃ probe ∈ probes,
        node ∈ transitionGlitch g.circuit g.horizon probe) := by
  intro hmember
  simp only [expandedNodes, List.mem_eraseDups, List.mem_filter,
    List.mem_flatMap]
  constructor
  · rintro ⟨⟨probe, hprobe, hexpanded⟩, _⟩
    exact ⟨probe, hprobe, hexpanded⟩
  · rintro ⟨probe, hprobe, hexpanded⟩
    exact ⟨⟨probe, hprobe, hexpanded⟩,
      (List.mem_filter.mp hmember).2⟩

private theorem orderedGlitchFrontier_mem_le
    (g : GadgetInstance) (hforward : ForwardCombinational g) :
    ∀ gate frontierGate,
      frontierGate ∈ orderedGlitchFrontier g.circuit gate →
      frontierGate ≤ gate := by
  intro gate
  induction gate using Nat.strongRecOn with
  | ind gate ih =>
      intro frontierGate hmem
      rw [orderedGlitchFrontier] at hmem
      generalize hentry : g.circuit.gates[gate]? = lookup at hmem
      cases lookup with
      | none =>
          simp at hmem
          omega
      | some entry =>
          let inputs := entry.inputs.filter fun input => input.2 == 0
          by_cases hempty : inputs.isEmpty = true
          · simp only [inputs, hempty, if_true, List.mem_singleton] at hmem
            omega
          · simp only [inputs, hempty, Bool.false_eq_true, if_false,
              List.mem_eraseDups, List.mem_flatMap] at hmem
            rcases hmem with ⟨input, hinput, hfrontier⟩
            have hinput' := List.mem_filter.mp hinput
            have hzero : input.2 = 0 := by simpa using hinput'.2
            have hlt := forwardCombinational_input_lt g hforward gate entry
              hentry input hinput'.1 hzero
            simp only [hlt, ↓reduceDIte] at hfrontier
            exact Nat.le_trans (ih input.1 hlt frontierGate hfrontier)
              (Nat.le_of_lt hlt)

private theorem transitionGlitch_node_bounds
    (g : GadgetInstance) (H : Nat) (horizon_eq : g.horizon = H)
    (hforward : ForwardCombinational g) (probe node : Node)
    (hprobeGate : probe.gate < g.circuit.gates.size)
    (hprobeCycle : probe.cycle < H)
    (hnode : node ∈ transitionGlitch g.circuit g.horizon probe) :
    node.gate < g.circuit.gates.size ∧ node.cycle < H := by
  simp only [transitionGlitch, Expansion.compose, List.mem_eraseDups,
    List.mem_flatMap] at hnode
  rcases hnode with ⟨transitionNode, htransition, hglitch⟩
  have htransitionGate : transitionNode.gate = probe.gate := by
    simp only [Expansion.transition] at htransition
    split at htransition
    · simp only [List.mem_cons, List.mem_singleton] at htransition
      rcases htransition with h | h | h
      · subst transitionNode; rfl
      · subst transitionNode; rfl
      · simp at h
    · simp only [List.mem_singleton] at htransition
      subst transitionNode
      rfl
  have htransitionCycle : transitionNode.cycle < H := by
    simp only [Expansion.transition] at htransition
    split at htransition
    · simp only [List.mem_cons, List.mem_singleton] at htransition
      rcases htransition with h | h | h
      · subst transitionNode
        simp only [horizon_eq] at hprobeCycle ⊢
        omega
      · subst transitionNode
        exact hprobeCycle
      · simp at h
    · simp only [List.mem_singleton] at htransition
      subst transitionNode
      exact hprobeCycle
  unfold Expansion.glitch at hglitch
  simp only [List.mem_map] at hglitch
  rcases hglitch with ⟨frontierGate, hfrontier, heq⟩
  subst node
  have hfrontierLe : frontierGate ≤ transitionNode.gate := by
    rw [glitchGates_eq_orderedGlitchFrontier g hforward
      transitionNode.gate g.circuit.gates.size (by
        simpa [htransitionGate] using hprobeGate)] at hfrontier
    exact orderedGlitchFrontier_mem_le g hforward
      transitionNode.gate frontierGate hfrontier
  have hfrontierLt : frontierGate < g.circuit.gates.size :=
    Nat.lt_of_le_of_lt (by simpa [htransitionGate] using hfrontierLe) hprobeGate
  exact ⟨hfrontierLt, htransitionCycle⟩

private theorem transitionGlitch_eq_transition_of_no_comb_inputs
    (c : Circuit) (horizon gate : Nat) (entry : Gate)
    (hgate : c.gates[gate]? = some entry)
    (hempty : (entry.inputs.filter fun input => input.2 == 0).isEmpty = true) :
    transitionGlitch c horizon { gate := gate, cycle := cycle } =
      transition c horizon { gate := gate, cycle := cycle } := by
  have hfrontier : Expansion.glitchGates c c.gates.size gate = [gate] := by
    cases hsize : c.gates.size with
    | zero =>
        have hnone : c.gates[gate]? = none := by simp [hsize]
        rw [hnone] at hgate
        contradiction
    | succ fuel => simp [Expansion.glitchGates, hgate, hempty]
  have hglitch (atCycle : Nat) :
      glitch c horizon { gate := gate, cycle := atCycle } =
        [{ gate := gate, cycle := atCycle }] := by
    rw [Expansion.glitch_cycle, hfrontier]
    rfl
  by_cases inside : 0 < cycle ∧ cycle < horizon
  · simp [transitionGlitch, Expansion.compose, transition, inside, hglitch]
    apply eraseDups_eq_self_of_nodup
    apply List.nodup_cons.mpr
    constructor
    · intro hmem
      have heq : ({ gate := gate, cycle := cycle - 1 } : Node) =
          { gate := gate, cycle := cycle } := by simpa using hmem
      have hcycles : cycle - 1 = cycle := by
        simpa using congrArg Node.cycle heq
      omega
    · apply List.nodup_cons.mpr
      exact ⟨by simp, by simp⟩
  · simp [transitionGlitch, Expansion.compose, transition, inside, hglitch]
    exact eraseDups_eq_self_of_nodup (by simp)

private theorem outputShare?_some {H d t : Nat}
    (P : PipelineGadget H d t) (node : Node) (share : Nat)
    (hshare : outputShare? P node = some share) :
    share < d ∧ P.g.output share = node := by
  have hmem := List.mem_of_find?_eq_some hshare
  have hmatches := List.find?_some hshare
  exact ⟨by simpa [outputShare?] using hmem,
    by simpa [outputShare?] using hmatches⟩

private theorem outputShare?_none {H d t : Nat}
    (P : PipelineGadget H d t) (node : Node)
    (hshare : outputShare? P node = none) :
    ∀ share, share < d → P.g.output share ≠ node := by
  intro share hlt heq
  have hnone := List.find?_eq_none.mp hshare share (by simpa)
  simp [outputShare?, heq] at hnone

/-- Canonical backward propagation of tail input-share demands through the
registered boundary. -/
def propagatedShares (d : Nat)
    (outputs tailWitness boundary : List Nat) : List Nat :=
  shareUnion d (shareUnion d outputs tailWitness) boundary

set_option maxHeartbeats 2000000 in
/-- E4 at observation granularity: every node exposed by the compiled
experiment is supplied by the upstream transcript, the transported tail
transcript, a direct boundary-register read, or a neutralized connected-input
constant. -/
theorem expansion_partition_coverage {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (internal : List Node) (outputs tailWitness upWitness : List Nat)
    (hinternal : internal.Sublist
      (internalNodes (registeredComposite up.g tail.ports)))
    (houtputs : outputs.Sublist (List.range d)) :
    let upInternal := partitionUpInternal up internal
    let tailInternal := partitionTailInternal up tail internal
    let boundary := partitionUpDemands up tail internal
    let demanded := propagatedShares d outputs tailWitness boundary
    let upNodes := upstreamTranscriptNodes up upInternal demanded upWitness
    let tailNodes := tailTranscriptNodes tail tailInternal outputs
    ∀ node ∈ expandedNodes (registeredComposite up.g tail.ports)
        transitionGlitch
        (internal ++ outputs.map
          (registeredComposite up.g tail.ports).output),
      node.cycle < H ∧
        PipelineNodeCovered up tail upNodes tailNodes node := by
  dsimp only
  intro node hnode
  have hcompMember : node ∈ memberNodes
      (registeredComposite up.g tail.ports) := by
    simp only [expandedNodes, List.mem_eraseDups] at hnode
    exact (List.mem_filter.mp hnode).2 |> fun hmember => by
      have hnodes : node ∈ nodes (registeredComposite up.g tail.ports) := by
        have horigin := (List.mem_filter.mp hnode).1
        rw [List.mem_flatMap] at horigin
        rcases horigin with ⟨probe, hprobe, hexpanded⟩
        have hprobeMember : probe ∈ memberNodes
            (registeredComposite up.g tail.ports) := by
          rcases List.mem_append.mp hprobe with hinternalProbe | houtputProbe
          · exact (List.mem_filter.mp (hinternal.mem hinternalProbe)).1
          · rw [List.mem_map] at houtputProbe
            rcases houtputProbe with ⟨share, _hshare, rfl⟩
            have hshareComp : share <
                (registeredComposite up.g tail.ports).d := by
              have := houtputs.mem _hshare
              simpa [registeredComposite, tail.d_eq] using this
            have hwf := registeredComposite_wf up tail
            have hall := List.all_eq_true.mp hwf.2.2.2.1
              ((registeredComposite up.g tail.ports).output share)
              (List.mem_map.mpr ⟨share, by simpa using hshareComp, rfl⟩)
            simpa [List.contains_iff_mem] using hall
        have hprobeBounds := memberNode_bounds _ probe hprobeMember
        have hnodeBounds := transitionGlitch_node_bounds
          (registeredComposite up.g tail.ports) H
          (by simp [registeredComposite, up.horizon_eq, tail.horizon_eq])
          (registeredComposite_forwardCombinational up tail)
          probe node hprobeBounds.1 (by
            simpa [registeredComposite, up.horizon_eq, tail.horizon_eq] using
              hprobeBounds.2) hexpanded
        rw [nodes, List.mem_flatMap]
        exact ⟨node.cycle, by simpa [registeredComposite, up.horizon_eq,
          tail.horizon_eq] using hnodeBounds.2,
          List.mem_map.mpr ⟨node.gate, by simpa using hnodeBounds.1,
            by cases node <;> rfl⟩⟩
      exact List.mem_filter.mpr ⟨hnodes, hmember⟩
  have hnodeCycle : node.cycle < H := by
    have hb := memberNode_bounds _ node hcompMember
    simpa [registeredComposite, up.horizon_eq, tail.horizon_eq] using hb.2
  refine ⟨hnodeCycle, ?_⟩
  have horigin := (mem_expandedNodes_iff_of_wholeWindow
    (registeredComposite up.g tail.ports)
    (internal ++ outputs.map
      (registeredComposite up.g tail.ports).output) node hcompMember).mp hnode
  rcases horigin with ⟨probe, hprobe, hexpanded⟩
  rcases List.mem_append.mp hprobe with hprobeInternal | hprobeOutput
  · have hcompInternal := hinternal.mem hprobeInternal
    have hprobeMember := (List.mem_filter.mp hcompInternal).1
    have hprobeBounds := memberNode_bounds _ probe hprobeMember
    by_cases hprefix : probe.gate < up.g.circuit.gates.size
    · cases hout : outputShare? up probe with
      | none =>
          apply Or.inl
          constructor
          · have hnodeGate := (transitionGlitch_node_bounds up.g H
                up.horizon_eq up.forward_combinational probe node hprefix
                (by simpa [registeredComposite, up.horizon_eq,
                  tail.horizon_eq] using hprobeBounds.2)
                (by simpa [transitionGlitch_prefix up tail probe hprefix]
                  using hexpanded)).1
            exact hnodeGate
          · have hexpandedUp := (mem_expandedNodes_iff_of_wholeWindow up.g
              (partitionUpInternal up internal ++
                (propagatedShares d outputs tailWitness
                  (partitionUpDemands up tail internal)).map up.g.output)
              node (memberNode_of_bounds up.g up.whole_window node
                (by
                  exact (transitionGlitch_node_bounds up.g H up.horizon_eq
                    up.forward_combinational probe node hprefix
                    (by simpa [registeredComposite, up.horizon_eq,
                      tail.horizon_eq] using hprobeBounds.2)
                    (by simpa [transitionGlitch_prefix up tail probe hprefix]
                      using hexpanded)).1)
                (by simpa [up.horizon_eq] using hnodeCycle))).2 ?_
            · simp only [upstreamTranscriptNodes, List.mem_eraseDups,
                List.mem_append]
              exact Or.inl (Or.inl hexpandedUp)
            · refine ⟨probe, ?_, by
              simpa [transitionGlitch_prefix up tail probe hprefix] using
                hexpanded⟩
              apply List.mem_append_left
              have hprobeUpMember : probe ∈ memberNodes up.g :=
                memberNode_of_bounds up.g up.whole_window probe hprefix
                  (by simpa [up.horizon_eq, registeredComposite,
                    tail.horizon_eq] using hprobeBounds.2)
              have hnotOutput : probe ∉ outputNodes up.g := by
                intro houtput
                rw [outputNodes, List.mem_map] at houtput
                rcases houtput with ⟨share, hshare, heq⟩
                exact outputShare?_none up probe hout share
                  (by simpa [up.d_eq] using hshare) heq
              have hprobeUpInternal : probe ∈ internalNodes up.g := by
                exact List.mem_filter.mpr ⟨hprobeUpMember, by
                  simpa [List.contains_iff_mem] using hnotOutput⟩
              rw [partitionUpInternal, List.mem_filter]
              refine ⟨hprobeUpInternal, ?_⟩
              have hraw : probe ∈ partitionUpInternalRaw up internal := by
                rw [partitionUpInternalRaw, List.mem_filterMap]
                exact ⟨probe, hprobeInternal, by simp [hprefix, hout]⟩
              simpa [List.contains_iff_mem] using hraw
      | some share =>
          have hs := outputShare?_some up probe share hout
          apply Or.inl
          constructor
          · exact (transitionGlitch_node_bounds up.g H up.horizon_eq
              up.forward_combinational probe node hprefix
              (by simpa [registeredComposite, up.horizon_eq,
                tail.horizon_eq] using hprobeBounds.2)
              (by simpa [transitionGlitch_prefix up tail probe hprefix]
                using hexpanded)).1
          · have hexpandedUp := (mem_expandedNodes_iff_of_wholeWindow up.g
              (partitionUpInternal up internal ++
                (propagatedShares d outputs tailWitness
                  (partitionUpDemands up tail internal)).map up.g.output) node
              (memberNode_of_bounds up.g up.whole_window node
                (transitionGlitch_node_bounds up.g H up.horizon_eq
                  up.forward_combinational probe node hprefix
                  (by simpa [registeredComposite, up.horizon_eq,
                    tail.horizon_eq] using hprobeBounds.2)
                  (by simpa [transitionGlitch_prefix up tail probe hprefix]
                    using hexpanded)).1
                (by simpa [up.horizon_eq] using hnodeCycle))).2 ?_
            · simp only [upstreamTranscriptNodes, List.mem_eraseDups,
                List.mem_append]
              exact Or.inl (Or.inl hexpandedUp)
            · refine ⟨up.g.output share, ?_, ?_⟩
              · apply List.mem_append_right
                rw [List.mem_map]
                refine ⟨share, ?_, rfl⟩
                simp only [propagatedShares, shareUnion, List.mem_filter,
                  List.mem_range, Bool.or_eq_true, List.contains_iff_mem]
                refine ⟨by simpa [up.d_eq] using hs.1, Or.inr ?_⟩
                rw [partitionUpDemands, shareUnion, List.mem_filter]
                simp only [Bool.or_eq_true, List.contains_iff_mem,
                  List.contains_nil, or_false]
                refine ⟨by simpa [up.d_eq] using hs.1, Or.inl ?_⟩
                rw [partitionUpDemandsRaw, List.mem_filterMap]
                exact ⟨probe, hprobeInternal, by simp [hprefix, hout]⟩
              · rw [hs.2]
                simpa [transitionGlitch_prefix up tail probe hprefix] using
                  hexpanded
    · by_cases hboundary : probe.gate < downstreamOffset up.g tail.g
      · let share := probe.gate - up.g.circuit.gates.size
        have hshareTail : share < tail.g.d := by
          dsimp [share]
          apply Nat.sub_lt_left_of_lt_add (Nat.le_of_not_gt hprefix)
          simpa [downstreamOffset, Nat.add_assoc] using hboundary
        have hshareD : share < d := by simpa [tail.d_eq] using hshareTail
        have hprobeGate : probe.gate = boundaryRegister up.g share := by
          dsimp [share]
          simp [boundaryRegister]
          omega
        have hreg := registeredComposite_boundary_gate up.g tail.ports
          share hshareTail
        have htg := register_output_transitionGlitch_eq_transition
          (registeredComposite up.g tail.ports).circuit
          (registeredComposite up.g tail.ports).horizon
          (up.g.output share).gate (boundaryRegister up.g share) probe.cycle hreg
        have hexpandedTransition : node ∈ transition
            (registeredComposite up.g tail.ports).circuit
            (registeredComposite up.g tail.ports).horizon probe := by
          have hprobeEq : probe =
              { gate := boundaryRegister up.g share, cycle := probe.cycle } := by
            cases probe
            simp_all
          rw [hprobeEq]
          rw [← htg]
          rw [hprobeEq] at hexpanded
          exact hexpanded
        have hnodeGate : node.gate = boundaryRegister up.g share := by
          simp only [Expansion.transition] at hexpandedTransition
          split at hexpandedTransition
          · simp only [List.mem_cons, List.mem_singleton] at hexpandedTransition
            rcases hexpandedTransition with h | h | h
            · subst node; exact hprobeGate
            · subst node; exact hprobeGate
            · simp at h
          · simp only [List.mem_singleton] at hexpandedTransition
            subst node
            exact hprobeGate
        apply Or.inr
        apply Or.inr
        apply Or.inl
        refine ⟨share, hshareD, hnodeGate, ?_⟩
        by_cases hcycle : node.cycle = tail.ports.arrivalCycle
        · exact Or.inr (by
            simp only [upstreamTranscriptNodes, List.mem_eraseDups,
              List.mem_append]
            apply Or.inl
            apply Or.inr
            rw [List.mem_map]
            refine ⟨share, ?_, rfl⟩
            simp only [propagatedShares, shareUnion, List.mem_filter,
              List.mem_range, Bool.or_eq_true, List.contains_iff_mem]
            refine ⟨by simpa [up.d_eq] using hshareD, Or.inr ?_⟩
            rw [partitionUpDemands, shareUnion, List.mem_filter]
            simp only [Bool.or_eq_true, List.contains_iff_mem,
              List.contains_nil, or_false]
            refine ⟨by simpa [up.d_eq] using hshareD, Or.inl ?_⟩
            rw [partitionUpDemandsRaw, List.mem_filterMap]
            refine ⟨probe, hprobeInternal, ?_⟩
            simp only [hprefix, if_neg, hboundary, if_pos]
            rfl)
        · exact Or.inl hcycle
      · have hsuffix : downstreamOffset up.g tail.g ≤ probe.gate := by omega
        let tailGate := probe.gate - downstreamOffset up.g tail.g
        let tailProbe : Node := { gate := tailGate, cycle := probe.cycle }
        have htailGateEq : downstreamOffset up.g tail.g + tailGate =
            probe.gate := by
          dsimp [tailGate]
          exact Nat.add_sub_of_le hsuffix
        have htailGate : tailGate < tail.g.circuit.gates.size := by
          have hsize : probe.gate < downstreamOffset up.g tail.g +
              tail.g.circuit.gates.size := by
            simpa [registeredComposite, registeredCompositeCircuit,
              UniversalSStage1.appendCircuit, boundaryRegisterGates,
              registeredDownGates, downstreamOffset, Nat.add_assoc] using
              hprobeBounds.1
          rw [← htailGateEq] at hsize
          omega
        cases hconnected : connectedShare? tail.ports tailGate with
        | some connectedShare =>
            have hshareMem := List.mem_of_find?_eq_some hconnected
            have hshare : connectedShare < tail.g.d := by
              simpa [connectedShare?] using hshareMem
            have hgateEq := List.find?_some hconnected
            have hportGate : tail.ports.inputGate connectedShare = tailGate := by
              simpa [connectedShare?] using hgateEq
            have hconst := registeredComposite_connected_const up tail tailGate
              connectedShare htailGate hconnected
            have hzero :
                (({ kind := GateKind.const false, inputs := [] } : Gate).inputs.filter
                  fun input => input.2 == 0).isEmpty = true := by decide
            have htg := transitionGlitch_eq_transition_of_no_comb_inputs
              (registeredComposite up.g tail.ports).circuit
              (registeredComposite up.g tail.ports).horizon
              (downstreamOffset up.g tail.g + tailGate)
              { kind := .const false, inputs := [] } hconst hzero
              (cycle := probe.cycle)
            have hliteralEq : probe =
                { gate := downstreamOffset up.g tail.g + tailGate,
                  cycle := probe.cycle } := by
              cases probe
              simp [tailGate]
              exact htailGateEq.symm
            have hexpandedTransition : node ∈ transition
                (registeredComposite up.g tail.ports).circuit
                (registeredComposite up.g tail.ports).horizon probe := by
              rw [hliteralEq]
              rw [← htg]
              rw [hliteralEq] at hexpanded
              exact hexpanded
            have hnodeGate : node.gate =
                downstreamOffset up.g tail.g + tailGate := by
              simp only [Expansion.transition] at hexpandedTransition
              split at hexpandedTransition
              · simp only [List.mem_cons, List.mem_singleton] at hexpandedTransition
                rcases hexpandedTransition with h | h | h
                · subst node; exact htailGateEq.symm
                · subst node; exact htailGateEq.symm
                · simp at h
              · simp only [List.mem_singleton] at hexpandedTransition
                subst node
                exact htailGateEq.symm
            apply Or.inr
            apply Or.inr
            apply Or.inr
            exact ⟨tailGate, htailGate, by simp [hconnected], hnodeGate⟩
        | none =>
            have hprobeEq' : probe =
                embeddedTailNode up.g tail.ports tailProbe := by
              cases probe
              simp [tailProbe, tailGate, embeddedTailNode,
                embeddedTailGate, hconnected]
              exact htailGateEq.symm
            have htransport := transitionGlitch_tail up tail tailProbe htailGate
            have hexpandedMap : node ∈
                (transitionGlitch tail.g.circuit tail.g.horizon tailProbe).map
                  (embeddedTailNode up.g tail.ports) := by
              rw [hprobeEq'] at hexpanded
              rw [htransport] at hexpanded
              exact hexpanded
            rw [List.mem_map] at hexpandedMap
            rcases hexpandedMap with ⟨tailNode, htailExpanded, heq⟩
            apply Or.inr
            apply Or.inl
            refine ⟨tailNode, ?_, heq⟩
            simp only [tailTranscriptNodes]
            apply (mem_expandedNodes_iff_of_wholeWindow tail.g
              (partitionTailInternal up tail internal ++
                outputs.map tail.g.output) tailNode
              (memberNode_of_bounds tail.g tail.whole_window tailNode
                (transitionGlitch_node_bounds tail.g H tail.horizon_eq
                  tail.forward_combinational tailProbe tailNode htailGate
                  (by simpa [tailProbe, tail.horizon_eq, registeredComposite,
                    up.horizon_eq] using hprobeBounds.2) htailExpanded).1
                (by
                  have hb := (transitionGlitch_node_bounds tail.g H
                    tail.horizon_eq tail.forward_combinational tailProbe tailNode
                    htailGate (by simpa [tailProbe, tail.horizon_eq,
                      registeredComposite, up.horizon_eq] using hprobeBounds.2)
                    htailExpanded).2
                  simpa [tail.horizon_eq] using hb))).2
            refine ⟨tailProbe, List.mem_append_left _ ?_, htailExpanded⟩
            have htailProbeMember : tailProbe ∈ memberNodes tail.g :=
              memberNode_of_bounds tail.g tail.whole_window tailProbe htailGate
                (by simpa [tailProbe, tail.horizon_eq, registeredComposite,
                  up.horizon_eq] using hprobeBounds.2)
            have hnotCompOutput : probe ∉
                outputNodes (registeredComposite up.g tail.ports) := by
              have hnot := (List.mem_filter.mp hcompInternal).2
              simpa [List.contains_iff_mem] using hnot
            have hnotTailOutput : tailProbe ∉ outputNodes tail.g := by
              intro htailOutput
              rw [outputNodes, List.mem_map] at htailOutput
              rcases htailOutput with ⟨share, hshare, houtputEq⟩
              apply hnotCompOutput
              rw [outputNodes, List.mem_map]
              refine ⟨share, by
                simpa [registeredComposite, tail.d_eq] using hshare, ?_⟩
              rw [registeredComposite]
              simp only
              rw [hprobeEq', ← houtputEq]
              have hgateOut : (tail.g.output share).gate = tailGate := by
                rw [houtputEq]
              have hconnOutput : connectedShare? tail.ports
                  (tail.g.output share).gate = none := by
                simpa [hgateOut] using hconnected
              simp [embeddedTailNode, embeddedTailGate, hconnOutput,
                embeddedDownNode]
            have htailInternal : tailProbe ∈ internalNodes tail.g :=
              List.mem_filter.mpr ⟨htailProbeMember, by
                simpa [List.contains_iff_mem] using hnotTailOutput⟩
            rw [partitionTailInternal, List.mem_filter]
            refine ⟨htailInternal, ?_⟩
            have hraw : tailProbe ∈
                partitionTailInternalRaw up tail internal := by
              rw [partitionTailInternalRaw, List.mem_filterMap]
              refine ⟨probe, hprobeInternal, ?_⟩
              simp only [hsuffix, if_pos]
              simp [tailProbe, tailGate, hconnected]
            simpa [List.contains_iff_mem] using hraw
  · rw [List.mem_map] at hprobeOutput
    rcases hprobeOutput with ⟨outputShare, houtputShare, rfl⟩
    have hshareD : outputShare < d := by simpa using houtputs.mem houtputShare
    have hshareTail : outputShare < tail.g.d := by
      simpa [tail.d_eq] using hshareD
    let tailProbe := tail.g.output outputShare
    have htailGate : tailProbe.gate < tail.g.circuit.gates.size := by
      simpa [tailProbe] using pipeline_output_gate_lt tail outputShare hshareD
    have htailProbeMember : tailProbe ∈ memberNodes tail.g := by
      have hall := List.all_eq_true.mp tail.down_cert.1.2.2.2.1 tailProbe
        (by
          rw [outputNodes]
          exact List.mem_map.mpr ⟨outputShare, by simpa using hshareTail, rfl⟩)
      simpa [List.contains_iff_mem] using hall
    have htailCycle : tailProbe.cycle < H := by
      have hb := (memberNode_bounds tail.g tailProbe htailProbeMember).2
      simpa [tail.horizon_eq] using hb
    cases hconnected : connectedShare? tail.ports tailProbe.gate with
    | some connectedShare =>
        have hshareMem := List.mem_of_find?_eq_some hconnected
        have hconnectedShare : connectedShare < tail.g.d := by
          simpa [connectedShare?] using hshareMem
        have hconst := registeredComposite_connected_const up tail
          tailProbe.gate connectedShare htailGate hconnected
        have hzero :
            (({ kind := GateKind.const false, inputs := [] } : Gate).inputs.filter
              fun input => input.2 == 0).isEmpty = true := by decide
        have htg := transitionGlitch_eq_transition_of_no_comb_inputs
          (registeredComposite up.g tail.ports).circuit
          (registeredComposite up.g tail.ports).horizon
          (downstreamOffset up.g tail.g + tailProbe.gate)
          { kind := .const false, inputs := [] } hconst hzero
          (cycle := ((registeredComposite up.g tail.ports).output
            outputShare).cycle)
        have hprobeEq :
            (registeredComposite up.g tail.ports).output outputShare =
              { gate := downstreamOffset up.g tail.g + tailProbe.gate,
                cycle := ((registeredComposite up.g tail.ports).output
                  outputShare).cycle } := by
          simp [registeredComposite, tailProbe, embeddedDownNode]
        have hexpandedTransition : node ∈ transition
            (registeredComposite up.g tail.ports).circuit
            (registeredComposite up.g tail.ports).horizon
            ((registeredComposite up.g tail.ports).output outputShare) := by
          rw [hprobeEq]
          rw [← htg]
          rw [hprobeEq] at hexpanded
          exact hexpanded
        have hnodeGate : node.gate =
            downstreamOffset up.g tail.g + tailProbe.gate := by
          simp only [Expansion.transition] at hexpandedTransition
          split at hexpandedTransition
          · simp only [List.mem_cons, List.mem_singleton] at hexpandedTransition
            rcases hexpandedTransition with h | h | h
            · subst node; rfl
            · subst node; rfl
            · simp at h
          · simp only [List.mem_singleton] at hexpandedTransition
            subst node
            rfl
        apply Or.inr
        apply Or.inr
        apply Or.inr
        exact ⟨tailProbe.gate, htailGate, by simp [hconnected], hnodeGate⟩
    | none =>
        have hprobeEq :
            (registeredComposite up.g tail.ports).output outputShare =
              embeddedTailNode up.g tail.ports tailProbe := by
          simp [registeredComposite, tailProbe, embeddedTailNode,
            embeddedTailGate, hconnected, embeddedDownNode]
        have htransport := transitionGlitch_tail up tail tailProbe htailGate
        have hexpandedMap : node ∈
            (transitionGlitch tail.g.circuit tail.g.horizon tailProbe).map
              (embeddedTailNode up.g tail.ports) := by
          rw [hprobeEq] at hexpanded
          rw [htransport] at hexpanded
          exact hexpanded
        rw [List.mem_map] at hexpandedMap
        rcases hexpandedMap with ⟨tailNode, htailExpanded, heq⟩
        apply Or.inr
        apply Or.inl
        refine ⟨tailNode, ?_, heq⟩
        simp only [tailTranscriptNodes]
        apply (mem_expandedNodes_iff_of_wholeWindow tail.g
          (partitionTailInternal up tail internal ++
            outputs.map tail.g.output) tailNode
          (memberNode_of_bounds tail.g tail.whole_window tailNode
            (transitionGlitch_node_bounds tail.g H tail.horizon_eq
              tail.forward_combinational tailProbe tailNode htailGate
              htailCycle
              htailExpanded).1
            (by
              have hb := (transitionGlitch_node_bounds tail.g H
                tail.horizon_eq tail.forward_combinational tailProbe tailNode
                htailGate htailCycle
                htailExpanded).2
              simpa [tail.horizon_eq] using hb))).2
        exact ⟨tailProbe, List.mem_append_right _
          (List.mem_map.mpr ⟨outputShare, houtputShare, rfl⟩), htailExpanded⟩

private theorem tailTranscriptNode_gate_lt {H d t : Nat}
    (up tail : PipelineGadget H d t) (internal outputs : List Node)
    (hinternal : internal.Sublist (internalNodes tail.g))
    (houtputs : outputs.Sublist (outputNodes tail.g))
    (node : Node)
    (hnode : node ∈ expandedNodes tail.g transitionGlitch
      (internal ++ outputs)) :
    node.gate < tail.g.circuit.gates.size := by
  simp only [expandedNodes, List.mem_eraseDups, List.mem_filter,
    List.mem_flatMap] at hnode
  rcases hnode.1 with ⟨probe, hprobe, hexpanded⟩
  have hprobeMember : probe ∈ memberNodes tail.g := by
    rcases List.mem_append.mp hprobe with h | h
    · exact (List.mem_filter.mp (hinternal.mem h)).1
    · have houtput := houtputs.mem h
      have hall := List.all_eq_true.mp tail.down_cert.1.2.2.2.1 probe houtput
      simpa [List.contains_iff_mem] using hall
  have hb := memberNode_bounds tail.g probe hprobeMember
  exact (transitionGlitch_node_bounds tail.g H tail.horizon_eq
    tail.forward_combinational probe node hb.1
    (by simpa [tail.horizon_eq] using hb.2) hexpanded).1

set_option maxHeartbeats 2000000 in
/-- Pointwise E4 decoder equality.  The enriched upstream transcript includes
the raw demanded outputs used by direct boundary-register reads; all other
coordinates are literal component transcript entries or constants. -/
theorem reconstructPipelineObservation_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (internal : List Node) (outputs tailWitness upWitness : List Nat)
    (hinternal : internal.Sublist
      (internalNodes (registeredComposite up.g tail.ports)))
    (houtputs : outputs.Sublist (List.range d))
    (env : Env) (x : List Bool)
    (hx : x ∈ boolVectors (inputWidth up.g))
    (hupEnv : restrictEnv
        (Execution.relevantSrcs up.g.circuit up.g.horizon) env ∈
      envsForInput up.g x)
    (hinit : ∀ share, share < d →
      env (.iniReg (boundaryRegister up.g share)) = false) :
    let upInternal := partitionUpInternal up internal
    let tailInternal := partitionTailInternal up tail internal
    let boundary := partitionUpDemands up tail internal
    let demanded := propagatedShares d outputs tailWitness boundary
    let upNodes := upstreamTranscriptNodes up upInternal demanded upWitness
    let tailNodes := tailTranscriptNodes tail tailInternal outputs
    let compositeNodes := expandedNodes
      (registeredComposite up.g tail.ports) transitionGlitch
      (internal ++ outputs.map
        (registeredComposite up.g tail.ports).output)
    reconstructPipelineObservation up tail upNodes tailNodes compositeNodes
        (observe up.g upNodes
          (restrictEnv
            (Execution.relevantSrcs up.g.circuit up.g.horizon) env))
        (observe tail.g tailNodes
          (substitutedTailEnv up.g tail.g tail.ports env)) =
      observe (registeredComposite up.g tail.ports) compositeNodes env := by
  dsimp only
  rw [observe_eq_map_eval]
  apply List.map_congr_left
  intro node hnode
  have hcoverage := expansion_partition_coverage up tail internal outputs
    tailWitness upWitness hinternal houtputs node hnode
  apply reconstructPipelineNode_eq_eval up tail glue _ _ env x hx hupEnv hinit
  · intro tailNode htailNode
    exact tailTranscriptNode_gate_lt up tail
      (partitionTailInternal up tail internal)
      (outputs.map tail.g.output)
      (partitionTailInternal_sublist up tail internal)
      (by
        apply List.Sublist.map
        simpa [tail.d_eq] using houtputs)
      tailNode htailNode
  · exact hcoverage.1
  · exact hcoverage.2

/-! ## Deterministic recovery from an ordered glitch frontier -/

/-- The complete latency-zero ancestor cone, including its internal gates.
The ordered frontier above is exactly the leaf set of this tree. -/
private def orderedGlitchCone (c : Circuit) (gate : Nat) : List Nat :=
  match hgate : c.gates[gate]? with
  | none => [gate]
  | some entry =>
      let inputs := entry.inputs.filter fun input => input.2 == 0
      if inputs.isEmpty then [gate]
      else
        (gate :: inputs.flatMap fun input =>
          if hlt : input.1 < gate then orderedGlitchCone c input.1
          else [input.1]).eraseDups
termination_by gate

private theorem orderedGlitchCone_of_some (c : Circuit) (gate : Nat)
    (entry : Gate) (hentry : c.gates[gate]? = some entry) :
    orderedGlitchCone c gate =
      let inputs := entry.inputs.filter fun input => input.2 == 0
      if inputs.isEmpty then [gate]
      else
        (gate :: inputs.flatMap fun input =>
          if hlt : input.1 < gate then orderedGlitchCone c input.1
          else [input.1]).eraseDups := by
  rw [orderedGlitchCone]
  generalize hlookup : c.gates[gate]? = lookup at *
  cases lookup with
  | none => simp at hentry
  | some found =>
      have : found = entry := Option.some.inj hentry
      subst found
      rfl

private theorem orderedGlitchFrontier_of_none (c : Circuit) (gate : Nat)
    (hentry : c.gates[gate]? = none) :
    orderedGlitchFrontier c gate = [gate] := by
  rw [orderedGlitchFrontier]
  generalize hlookup : c.gates[gate]? = lookup at *
  cases lookup <;> simp_all

private theorem orderedGlitchCone_of_none (c : Circuit) (gate : Nat)
    (hentry : c.gates[gate]? = none) :
    orderedGlitchCone c gate = [gate] := by
  rw [orderedGlitchCone]
  generalize hlookup : c.gates[gate]? = lookup at *
  cases lookup <;> simp_all

private theorem orderedGlitchFrontier_subcone
    (g : GadgetInstance) (hforward : ForwardCombinational g) :
    ∀ gate frontierGate,
      frontierGate ∈ orderedGlitchFrontier g.circuit gate →
      frontierGate ∈ orderedGlitchCone g.circuit gate := by
  intro gate
  induction gate using Nat.strongRecOn with
  | ind gate ih =>
      intro frontierGate hfrontier
      cases hentry : g.circuit.gates[gate]? with
      | none =>
          rw [orderedGlitchFrontier_of_none g.circuit gate hentry] at hfrontier
          rw [orderedGlitchCone_of_none g.circuit gate hentry]
          exact hfrontier
      | some entry =>
          rw [orderedGlitchFrontier_of_some g.circuit gate entry hentry]
            at hfrontier
          rw [orderedGlitchCone_of_some g.circuit gate entry hentry]
          let inputs := entry.inputs.filter fun input => input.2 == 0
          by_cases hempty : inputs.isEmpty = true
          · simpa [inputs, hempty] using hfrontier
          · simp only [inputs, hempty, Bool.false_eq_true, if_false,
              List.mem_eraseDups, List.mem_cons, List.mem_flatMap]
              at hfrontier ⊢
            right
            rcases hfrontier with ⟨input, hinput, hmem⟩
            refine ⟨input, hinput, ?_⟩
            have hinput' := List.mem_filter.mp hinput
            have hzero : input.2 = 0 := by simpa using hinput'.2
            have hlt := forwardCombinational_input_lt g hforward gate entry
              hentry input hinput'.1 hzero
            simp only [hlt, ↓reduceDIte] at hmem ⊢
            exact ih input.1 hlt frontierGate hmem

private theorem orderedGlitchCone_self (c : Circuit) (gate : Nat) :
    gate ∈ orderedGlitchCone c gate := by
  cases hentry : c.gates[gate]? with
  | none => simp [orderedGlitchCone_of_none c gate hentry]
  | some entry =>
      rw [orderedGlitchCone_of_some c gate entry hentry]
      let inputs := entry.inputs.filter fun input => input.2 == 0
      by_cases hempty : inputs.isEmpty = true
      · simp [inputs, hempty]
      · have hfalse : inputs.isEmpty = false := by
          cases h : inputs.isEmpty
          · rfl
          · exact (hempty h).elim
        simp [inputs, hfalse]

private theorem orderedGlitchCone_child {H d t : Nat}
    (P : PipelineGadget H d t) (gate : Nat) (entry : Gate)
    (hentry : P.g.circuit.gates[gate]? = some entry)
    (hnonempty :
      (entry.inputs.filter fun input => input.2 == 0).isEmpty = false)
    (input : Nat × Nat)
    (hinput : input ∈ entry.inputs)
    (hzero : input.2 = 0) (child : Nat)
    (hchild : child ∈ orderedGlitchCone P.g.circuit input.1) :
    child ∈ orderedGlitchCone P.g.circuit gate := by
  rw [orderedGlitchCone_of_some P.g.circuit gate entry hentry]
  simp only [hnonempty, Bool.false_eq_true, if_false, List.mem_eraseDups,
    List.mem_cons]
  right
  rw [List.mem_flatMap]
  have hfiltered : input ∈
      entry.inputs.filter fun edge => edge.2 == 0 := by
    exact List.mem_filter.mpr ⟨hinput, by simpa [hzero]⟩
  refine ⟨input, hfiltered, ?_⟩
  have hlt := forwardCombinational_input_lt P.g P.forward_combinational gate
    entry hentry input hinput hzero
  simp [hlt, hchild]

private theorem orderedGlitchFrontier_child {H d t : Nat}
    (P : PipelineGadget H d t) (gate : Nat) (entry : Gate)
    (hentry : P.g.circuit.gates[gate]? = some entry)
    (hnonempty :
      (entry.inputs.filter fun input => input.2 == 0).isEmpty = false)
    (input : Nat × Nat)
    (hinput : input ∈ entry.inputs)
    (hzero : input.2 = 0) (child : Nat)
    (hchild : child ∈ orderedGlitchFrontier P.g.circuit input.1) :
    child ∈ orderedGlitchFrontier P.g.circuit gate := by
  rw [orderedGlitchFrontier_of_some P.g.circuit gate entry hentry]
  simp only [hnonempty, Bool.false_eq_true, if_false, List.mem_eraseDups,
    List.mem_flatMap]
  have hfiltered : input ∈
      entry.inputs.filter fun edge => edge.2 == 0 := by
    exact List.mem_filter.mpr ⟨hinput, by simpa [hzero]⟩
  refine ⟨input, hfiltered, ?_⟩
  have hlt := forwardCombinational_input_lt P.g P.forward_combinational gate
    entry hentry input hinput hzero
  simp [hlt, hchild]

private theorem orderedGlitchCone_cases {H d t : Nat}
    (P : PipelineGadget H d t) :
    ∀ root gate,
      gate ∈ orderedGlitchCone P.g.circuit root →
      gate ∈ orderedGlitchFrontier P.g.circuit root ∨
        ∃ entry, P.g.circuit.gates[gate]? = some entry ∧
          (entry.inputs.filter fun input => input.2 == 0).isEmpty = false ∧
          ∀ input ∈ entry.inputs, input.2 = 0 →
            input.1 ∈ orderedGlitchCone P.g.circuit root := by
  intro root
  induction root using Nat.strongRecOn with
  | ind root ih =>
      intro gate hcone
      cases hentry : P.g.circuit.gates[root]? with
      | none =>
          rw [orderedGlitchCone_of_none P.g.circuit root hentry] at hcone
          simp only [List.mem_singleton] at hcone
          subst gate
          left
          simp [orderedGlitchFrontier_of_none P.g.circuit root hentry]
      | some entry =>
          let inputs := entry.inputs.filter fun input => input.2 == 0
          by_cases hempty : inputs.isEmpty = true
          · rw [orderedGlitchCone_of_some P.g.circuit root entry hentry]
              at hcone
            simp only [inputs, hempty, if_true, List.mem_singleton] at hcone
            subst gate
            left
            rw [orderedGlitchFrontier_of_some P.g.circuit root entry hentry]
            simp [inputs, hempty]
          · have hnonempty : inputs.isEmpty = false := by
              cases h : inputs.isEmpty
              · rfl
              · exact (hempty h).elim
            rw [orderedGlitchCone_of_some P.g.circuit root entry hentry]
              at hcone
            simp only [inputs, hnonempty, Bool.false_eq_true, if_false,
              List.mem_eraseDups, List.mem_cons, List.mem_flatMap] at hcone
            rcases hcone with rfl | hdesc
            · right
              refine ⟨entry, hentry, hnonempty, ?_⟩
              intro input hinput hzero
              exact orderedGlitchCone_child P gate entry hentry hnonempty input
                hinput hzero input.1 (orderedGlitchCone_self _ _)
            · rcases hdesc with ⟨input, hinputFiltered, hgateChild⟩
              have hinput := (List.mem_filter.mp hinputFiltered).1
              have hzero : input.2 = 0 := by
                simpa using (List.mem_filter.mp hinputFiltered).2
              have hlt := forwardCombinational_input_lt P.g
                P.forward_combinational root entry hentry input hinput hzero
              simp only [hlt, ↓reduceDIte] at hgateChild
              rcases ih input.1 hlt gate hgateChild with hleaf | hinternal
              · left
                exact orderedGlitchFrontier_child P root entry hentry hnonempty
                  input hinput hzero gate hleaf
              · right
                rcases hinternal with ⟨gateEntry, hgateEntry, hgateNonempty,
                  hchildren⟩
                refine ⟨gateEntry, hgateEntry, hgateNonempty, ?_⟩
                intro childInput hchild hchildZero
                exact orderedGlitchCone_child P root entry hentry hnonempty input
                  hinput hzero childInput.1
                    (hchildren childInput hchild hchildZero)

private theorem lookupAssoc_evalEntries_of_cycle_ge
    (c : Circuit) (env : Env) (node : Node) :
    ∀ horizon, horizon ≤ node.cycle →
      Execution.lookupAssoc node
        (UniversalSStage1.evalEntries c horizon env) = none := by
  intro horizon
  induction horizon with
  | zero =>
      simp [UniversalSStage1.evalEntries, UniversalSStage1.evalCycles,
        Execution.lookupAssoc]
  | succ horizon ih =>
      intro hle
      rw [evalEntries_succ_local]
      rw [lookupAssoc_evalCycle_other_cycle]
      · exact ih (by omega)
      · omega

private theorem eval_eq_cycle_succ (c : Circuit) (horizon : Nat)
    (env : Env) (node : Node) (hcycle : node.cycle < horizon) :
    Execution.eval c horizon env node =
      Execution.eval c (node.cycle + 1) env node := by
  induction horizon with
  | zero => omega
  | succ horizon ih =>
      by_cases hearlier : node.cycle < horizon
      · rw [eval_succ_stable_local c horizon env node hearlier]
        exact ih hearlier
      · have heq : node.cycle = horizon := by omega
        subst horizon
        rfl

private theorem gateValue_at_schedule_eq_eval
    (c : Circuit) (horizon : Nat) (env : Env) (cycle gate : Nat)
    (hgate : gate < c.gates.size) (hcycle : cycle < horizon)
    (before after : List Nat)
    (horder : Execution.gateOrder c = before ++ gate :: after)
    (hnodup : (Execution.gateOrder c).Nodup) :
    UniversalSStage1.gateValue c env
        (UniversalSStage1.evalCycle c env cycle before
          (UniversalSStage1.evalEntries c cycle env)) cycle gate =
      Execution.eval c horizon env { gate := gate, cycle := cycle } := by
  have hgateNotAfter : gate ∉ after := by
    rw [horder] at hnodup
    have happend := List.nodup_append.mp hnodup
    have hcons := List.nodup_cons.mp happend.2.1
    exact hcons.1
  rw [eval_eq_cycle_succ c horizon env
    { gate := gate, cycle := cycle } hcycle]
  simp only [Execution.eval, hgate, Nat.lt_succ_self, Bool.true_and,
    decide_true, if_true]
  rw [← UniversalSStage1.evalEntries_eq_execution, evalEntries_succ_local]
  rw [horder]
  simp only [UniversalSStage1.evalCycle, List.foldl_append, List.foldl_cons]
  rw [← UniversalSStage1.evalCycle]
  change _ =
    (Execution.lookupAssoc { gate := gate, cycle := cycle }
      (UniversalSStage1.evalCycle c env cycle after
        (({ gate := gate, cycle := cycle },
            UniversalSStage1.gateValue c env
              (UniversalSStage1.evalCycle c env cycle before
                (UniversalSStage1.evalEntries c cycle env)) cycle gate) ::
          UniversalSStage1.evalCycle c env cycle before
            (UniversalSStage1.evalEntries c cycle env)))).getD false
  rw [lookupAssoc_evalCycle_other_gates c env cycle after
    { gate := gate, cycle := cycle } _ hgateNotAfter]
  simp [Execution.lookupAssoc]

/-- Replay one scheduled cycle while treating the ordered glitch frontier of
`root` as externally supplied values.  Every other gate is evaluated from the
newest replay table. -/
private def replayGlitchCycle (c : Circuit) (root cycle : Nat)
    (nodes : List Node) (values : Observation) (schedule : List Nat) :
    List (Node × Bool) :=
  schedule.foldl (fun table gate =>
    let value :=
      if gate ∈ orderedGlitchFrontier c root then
        observationAt nodes values { gate := gate, cycle := cycle }
      else
        UniversalSStage1.gateValue c (fun _ => false) table cycle gate
    ({ gate := gate, cycle := cycle }, value) :: table) []

private theorem replayGlitchCycle_append (c : Circuit) (root cycle : Nat)
    (nodes : List Node) (values : Observation) (left right : List Nat) :
    replayGlitchCycle c root cycle nodes values (left ++ right) =
      right.foldl (fun table gate =>
        let value :=
          if gate ∈ orderedGlitchFrontier c root then
            observationAt nodes values { gate := gate, cycle := cycle }
          else
            UniversalSStage1.gateValue c (fun _ => false) table cycle gate
        ({ gate := gate, cycle := cycle }, value) :: table)
        (replayGlitchCycle c root cycle nodes values left) := by
  simp [replayGlitchCycle, List.foldl_append]

private theorem gateValue_replay_eq {H d t : Nat}
    (P : PipelineGadget H d t) (root gate cycle : Nat)
    (env : Env) (actual replay : List (Node × Bool))
    (hcone : gate ∈ orderedGlitchCone P.g.circuit root)
    (hnotFrontier : gate ∉ orderedGlitchFrontier P.g.circuit root)
    (hagrees : ∀ child,
      child ∈ orderedGlitchCone P.g.circuit root →
        Execution.lookupAssoc { gate := child, cycle := cycle } replay =
          Execution.lookupAssoc { gate := child, cycle := cycle } actual) :
    UniversalSStage1.gateValue P.g.circuit (fun _ => false) replay cycle gate =
      UniversalSStage1.gateValue P.g.circuit env actual cycle gate := by
  rcases orderedGlitchCone_cases P root gate hcone with hfrontier |
      ⟨entry, hentry, hnonempty, hchildren⟩
  · exact (hnotFrontier hfrontier).elim
  have hgate : gate < P.g.circuit.gates.size :=
    (Array.getElem?_eq_some_iff.mp hentry).choose
  have hgateArity : Circuit.gateArityOk entry = true := by
    have hall := Array.all_eq_true.mp P.down_cert.1.1.1 gate hgate
    have hentry' : P.g.circuit.gates[gate] = entry := by
      simpa [hgate] using hentry
    rw [hentry'] at hall
    simp only [Bool.and_eq_true] at hall
    exact hall.1
  have harity := hgateArity
  have hkind : entry.kind = .xor ∨ entry.kind = .and ∨
      entry.kind = .not ∨ entry.kind = .mux := by
    cases hkind : entry.kind
    · exact Or.inl rfl
    · exact Or.inr (Or.inl rfl)
    · exact Or.inr (Or.inr (Or.inl rfl))
    · have harity' := harity
      simp [Circuit.gateArityOk, hkind] at harity'
      have hfiltered :
          entry.inputs.filter (fun input => input.2 == 0) = [] := by
        apply List.filter_eq_nil_iff.mpr
        intro input hinput
        rcases input with ⟨source, latency⟩
        have hone := harity'.2 source latency hinput
        simp at hone ⊢
        omega
      exact ((List.isEmpty_eq_false_iff.mp hnonempty) hfiltered).elim
    · exact Or.inr (Or.inr (Or.inr rfl))
    all_goals
      have harity' := harity
      simp [Circuit.gateArityOk, hkind] at harity'
      have hempty : entry.inputs = [] := harity'
      simp [hempty] at hnonempty
  have hallzero : ∀ input ∈ entry.inputs, input.2 = 0 := by
    intro input hinput
    rcases hkind with hkind | hkind | hkind | hkind <;>
      simp [Circuit.gateArityOk, hkind] at harity
    all_goals
      rcases input with ⟨source, latency⟩
      exact harity.2 source latency hinput
  have hinputValues : entry.inputs.map
        (UniversalSStage1.inputValue (fun _ => false) replay gate cycle) =
      entry.inputs.map
        (UniversalSStage1.inputValue env actual gate cycle) := by
    apply List.map_congr_left
    intro input hinput
    have hzero : input.2 = 0 := hallzero input hinput
    have hchild := hchildren input hinput hzero
    simpa [UniversalSStage1.inputValue, hzero] using
      congrArg (fun value => value.getD false)
        (hagrees input.1 hchild)
  simp only [UniversalSStage1.gateValue, hentry]
  rw [hinputValues]
  rcases hkind with hkind | hkind | hkind | hkind <;>
    rw [hkind] <;> rfl

private theorem orderedGlitchCone_gate_lt {H d t : Nat}
    (P : PipelineGadget H d t) :
    ∀ root, root < P.g.circuit.gates.size → ∀ gate,
      gate ∈ orderedGlitchCone P.g.circuit root →
        gate < P.g.circuit.gates.size := by
  intro root
  induction root using Nat.strongRecOn with
  | ind root ih =>
      intro hroot gate hcone
      have hentrySome : ∃ entry, P.g.circuit.gates[root]? = some entry := by
        simpa [Array.getElem?_eq_some_iff, hroot]
      rcases hentrySome with ⟨entry, hentry⟩
      rw [orderedGlitchCone_of_some P.g.circuit root entry hentry] at hcone
      let inputs := entry.inputs.filter fun input => input.2 == 0
      by_cases hempty : inputs.isEmpty = true
      · simp [inputs, hempty] at hcone
        simpa [hcone] using hroot
      · have hfalse : inputs.isEmpty = false := by
          cases h : inputs.isEmpty
          · rfl
          · exact (hempty h).elim
        simp only [inputs, hfalse, Bool.false_eq_true, if_false,
          List.mem_eraseDups, List.mem_cons, List.mem_flatMap] at hcone
        rcases hcone with rfl | ⟨input, hinputFiltered, hgate⟩
        · exact hroot
        · have hinput := (List.mem_filter.mp hinputFiltered).1
          have hzero : input.2 = 0 := by
            simpa using (List.mem_filter.mp hinputFiltered).2
          have hlt := forwardCombinational_input_lt P.g
            P.forward_combinational root entry hentry input hinput hzero
          simp only [hlt, ↓reduceDIte] at hgate
          have hall := Array.all_eq_true.mp P.down_cert.1.1.1 root hroot
          have hentryValue : P.g.circuit.gates[root] = entry := by
            simpa [hroot] using hentry
          rw [hentryValue] at hall
          simp only [Bool.and_eq_true] at hall
          have hchildBound := List.all_eq_true.mp hall.2 input hinput
          exact ih input.1 hlt (by simpa using hchildBound) gate hgate

private theorem list_reverse_induction {motive : List α → Prop}
    (nil : motive [])
    (snoc : ∀ xs x, motive xs → motive (xs ++ [x])) :
    ∀ xs, motive xs := by
  intro xs
  rw [← List.reverse_reverse xs]
  generalize xs.reverse = reversed
  induction reversed with
  | nil => exact nil
  | cons head tail ih =>
      rw [List.reverse_cons]
      exact snoc tail.reverse head ih

/-- Replaying the observed frontier agrees with the genuine evaluator on the
whole combinational cone after every prefix of the topological schedule. -/
private theorem replayGlitchCycle_agrees {H d t : Nat}
    (P : PipelineGadget H d t) (root cycle : Nat) (env : Env)
    (nodes : List Node) (hroot : root < P.g.circuit.gates.size)
    (hcycle : cycle < P.g.horizon)
    (hfrontier : ∀ gate,
      gate ∈ orderedGlitchFrontier P.g.circuit root →
        { gate := gate, cycle := cycle } ∈ nodes) :
    ∀ before after,
      Execution.gateOrder P.g.circuit = before ++ after →
      ∀ gate, gate ∈ orderedGlitchCone P.g.circuit root →
        Execution.lookupAssoc { gate := gate, cycle := cycle }
            (replayGlitchCycle P.g.circuit root cycle nodes
              (observe P.g nodes env) before) =
          Execution.lookupAssoc { gate := gate, cycle := cycle }
            (UniversalSStage1.evalCycle P.g.circuit env cycle before
              (UniversalSStage1.evalEntries P.g.circuit cycle env)) := by
  apply list_reverse_induction
  ·
      intro after horder gate hcone
      simp only [replayGlitchCycle, List.foldl_nil,
        UniversalSStage1.evalCycle]
      rw [lookupAssoc_evalEntries_of_cycle_ge]
      · rfl
      · simp
  ·
      intro before current ih
      intro after horder gate hcone
      have horderBefore : Execution.gateOrder P.g.circuit =
          before ++ current :: after := by
        simpa [List.append_assoc] using horder
      have ihAgree := ih (current :: after) horderBefore
      rw [replayGlitchCycle_append]
      simp only [List.foldl_cons, List.foldl_nil]
      rw [UniversalSStage1.evalCycle, List.foldl_append]
      simp only [List.foldl_cons, List.foldl_nil]
      let replayBefore := replayGlitchCycle P.g.circuit root cycle nodes
        (observe P.g nodes env) before
      let actualBefore := UniversalSStage1.evalCycle P.g.circuit env cycle before
        (UniversalSStage1.evalEntries P.g.circuit cycle env)
      have hcurrentValue (hcurrentCone :
          current ∈ orderedGlitchCone P.g.circuit root) :
          (if current ∈ orderedGlitchFrontier P.g.circuit root then
              observationAt nodes (observe P.g nodes env)
                { gate := current, cycle := cycle }
            else UniversalSStage1.gateValue P.g.circuit (fun _ => false)
              replayBefore cycle current) =
            UniversalSStage1.gateValue P.g.circuit env
              actualBefore cycle current := by
        by_cases hcurrentFrontier :
            current ∈ orderedGlitchFrontier P.g.circuit root
        · rw [if_pos hcurrentFrontier]
          rw [observationAt_observe_of_mem P.g nodes env
            { gate := current, cycle := cycle }
            (hfrontier current hcurrentFrontier)]
          symm
          exact gateValue_at_schedule_eq_eval P.g.circuit P.g.horizon env
            cycle current
            (orderedGlitchCone_gate_lt P root hroot current hcurrentCone)
            hcycle before after horderBefore
            (gateOrder_nodup_of_wf P.g.circuit P.down_cert.1.1)
        · rw [if_neg hcurrentFrontier]
          apply gateValue_replay_eq P root current cycle env
            actualBefore replayBefore hcurrentCone hcurrentFrontier
          intro child hchild
          exact ihAgree child hchild
      by_cases heq : gate = current
      · subst gate
        simpa [Execution.lookupAssoc, replayBefore, actualBefore,
          UniversalSStage1.evalCycle] using
          hcurrentValue hcone
      · simpa [Execution.lookupAssoc, heq,
          UniversalSStage1.evalCycle] using ihAgree gate hcone

/-- Deterministically recover a gate value from the observed ordered glitch
frontier at one cycle.  The replay uses the circuit's frozen schedule and
supplies `false` only outside the cone, where it cannot affect the root. -/
def recoverGlitchValue {H d t : Nat} (P : PipelineGadget H d t)
    (root cycle : Nat) (nodes : List Node) (values : Observation) : Bool :=
  (Execution.lookupAssoc { gate := root, cycle := cycle }
    (replayGlitchCycle P.g.circuit root cycle nodes values
      (Execution.gateOrder P.g.circuit))).getD false

set_option maxHeartbeats 1000000 in
/-- Correctness of ordered-frontier replay.  This is the value decoder used
for demanded combinational outputs which need not themselves occur in a
transition-glitch transcript. -/
theorem recoverGlitchValue_eq_eval {H d t : Nat}
    (P : PipelineGadget H d t) (root cycle : Nat) (env : Env)
    (nodes : List Node) (hroot : root < P.g.circuit.gates.size)
    (hcycle : cycle < P.g.horizon)
    (hfrontier : ∀ gate,
      gate ∈ orderedGlitchFrontier P.g.circuit root →
        { gate := gate, cycle := cycle } ∈ nodes) :
    recoverGlitchValue P root cycle nodes (observe P.g nodes env) =
      Execution.eval P.g.circuit P.g.horizon env
        { gate := root, cycle := cycle } := by
  have hagree := replayGlitchCycle_agrees P root cycle env nodes hroot hcycle
    hfrontier (Execution.gateOrder P.g.circuit) [] (by simp) root
    (orderedGlitchCone_self P.g.circuit root)
  unfold recoverGlitchValue
  rw [eval_eq_cycle_succ P.g.circuit P.g.horizon env
    { gate := root, cycle := cycle } hcycle]
  simp only [Execution.eval, hroot, Nat.lt_succ_self, Bool.true_and,
    decide_true, if_true]
  rw [← UniversalSStage1.evalEntries_eq_execution,
    evalEntries_succ_local]
  exact congrArg (fun value => value.getD false) hagree

/-- The literal node list emitted by the upstream O-PINI certificate. -/
def upstreamCertificateNodes {H d t : Nat} (up : PipelineGadget H d t)
    (internal : List Node) (demanded witness : List Nat) : List Node :=
  ((expandedNodes up.g transitionGlitch
      (internal ++ demanded.map up.g.output)) ++
    witness.map up.g.output).eraseDups

private theorem pipeline_output_member {H d t : Nat}
    (P : PipelineGadget H d t) (share : Nat) (hshare : share < d) :
    P.g.output share ∈ memberNodes P.g := by
  have hshareG : share < P.g.d := by simpa [P.d_eq] using hshare
  have hall := List.all_eq_true.mp P.down_cert.1.2.2.2.1
    (P.g.output share)
    (List.mem_map.mpr ⟨share, by simpa using hshareG, rfl⟩)
  simpa [List.contains_iff_mem] using hall

private theorem frontier_mem_upstreamCertificateNodes {H d t : Nat}
    (up : PipelineGadget H d t) (internal : List Node)
    (demanded witness : List Nat)
    (share frontier : Nat) (hshare : share < d)
    (hdemanded : share ∈ demanded)
    (hfrontier : frontier ∈
      orderedGlitchFrontier up.g.circuit (up.g.output share).gate) :
    ({ gate := frontier, cycle := (up.g.output share).cycle } : Node) ∈
      upstreamCertificateNodes up internal demanded witness := by
  have houtputMember := pipeline_output_member up share hshare
  have houtputBounds := memberNode_bounds up.g (up.g.output share) houtputMember
  have htransition : up.g.output share ∈
      Expansion.transition up.g.circuit up.g.horizon (up.g.output share) := by
    unfold Expansion.transition
    split <;> simp
  let frontierNode : Node :=
    { gate := frontier, cycle := (up.g.output share).cycle }
  have hglitch : frontierNode ∈
      Expansion.glitch up.g.circuit up.g.horizon (up.g.output share) := by
    rw [Expansion.glitch_cycle]
    rw [glitchGates_eq_orderedGlitchFrontier up.g
      up.forward_combinational (up.g.output share).gate
      up.g.circuit.gates.size houtputBounds.1]
    exact List.mem_map.mpr ⟨frontier, hfrontier, rfl⟩
  have hexpansion : frontierNode ∈
      transitionGlitch up.g.circuit up.g.horizon (up.g.output share) := by
    simp only [transitionGlitch, Expansion.compose, List.mem_eraseDups,
      List.mem_flatMap]
    exact ⟨up.g.output share, htransition, hglitch⟩
  have hexpanded : frontierNode ∈
      expandedNodes up.g transitionGlitch
        (internal ++ demanded.map up.g.output) := by
    have hfrontierLe := orderedGlitchFrontier_mem_le up.g
      up.forward_combinational (up.g.output share).gate frontier hfrontier
    have hfrontierMember : frontierNode ∈ memberNodes up.g := by
      apply memberNode_of_bounds up.g up.whole_window frontierNode
      · dsimp [frontierNode]
        omega
      · dsimp [frontierNode]
        exact houtputBounds.2
    apply (mem_expandedNodes_iff_of_wholeWindow up.g _ _
      hfrontierMember).2
    exact ⟨up.g.output share, List.mem_append_right _
      (List.mem_map.mpr ⟨share, hdemanded, rfl⟩), hexpansion⟩
  simpa [frontierNode, upstreamCertificateNodes] using
    (show frontierNode ∈ upstreamCertificateNodes up internal demanded witness
      from by simp [upstreamCertificateNodes, hexpanded])

/-- Read an enriched upstream node list from the literal O-PINI transcript.
Demanded combinational outputs which are absent literally are recovered from
their ordered glitch frontiers. -/
def decodeUpstreamValue {H d t : Nat} (up : PipelineGadget H d t)
    (internal : List Node) (demanded witness : List Nat)
    (values : Observation)
    (node : Node) : Bool :=
  let certificateNodes :=
    upstreamCertificateNodes up internal demanded witness
  if node ∈ certificateNodes then
    observationAt certificateNodes values node
  else if ∃ share ∈ demanded, up.g.output share = node then
    recoverGlitchValue up node.gate node.cycle certificateNodes values
  else false

def decodeUpstreamObservation {H d t : Nat}
    (up : PipelineGadget H d t) (internal : List Node)
    (demanded witness : List Nat)
    (values : Observation) : Observation :=
  (upstreamTranscriptNodes up internal demanded witness).map
    (decodeUpstreamValue up internal demanded witness values)

set_option maxHeartbeats 1000000 in
private theorem decodeUpstreamValue_eq_eval {H d t : Nat}
    (up : PipelineGadget H d t) (internal : List Node)
    (demanded witness : List Nat)
    (hdemanded : demanded.Sublist (List.range d)) (env : Env) (node : Node)
    (hnode : node ∈ upstreamTranscriptNodes up internal demanded witness) :
    decodeUpstreamValue up internal demanded witness
        (observe up.g (upstreamCertificateNodes up internal demanded witness)
          env) node =
      Execution.eval up.g.circuit up.g.horizon env node := by
  let certificateNodes := upstreamCertificateNodes up internal demanded witness
  by_cases hcertificate : node ∈ certificateNodes
  · simp only [decodeUpstreamValue, certificateNodes, hcertificate, if_pos]
    exact observationAt_observe_of_mem up.g certificateNodes env node
      hcertificate
  · have hdemandedNode : ∃ share ∈ demanded, up.g.output share = node := by
      simp only [upstreamTranscriptNodes, List.mem_eraseDups,
        List.mem_append] at hnode
      rcases hnode with hleft | hwitness
      · rcases hleft with hexpanded | hdemandedNode
        · exact (hcertificate (by
            simp [certificateNodes, upstreamCertificateNodes, hexpanded])).elim
        · simpa only [List.mem_map] using hdemandedNode
      · exact (hcertificate (by
          simp [certificateNodes, upstreamCertificateNodes, hwitness])).elim
    simp only [decodeUpstreamValue, certificateNodes, hcertificate, if_neg,
      hdemandedNode, if_pos]
    rcases hdemandedNode with ⟨share, hshare, houtput⟩
    have hshareD : share < d := by simpa using hdemanded.mem hshare
    have hmember := pipeline_output_member up share hshareD
    have hbounds := memberNode_bounds up.g (up.g.output share) hmember
    subst node
    apply recoverGlitchValue_eq_eval up (up.g.output share).gate
      (up.g.output share).cycle env certificateNodes hbounds.1 hbounds.2
    intro frontier hfrontier
    exact frontier_mem_upstreamCertificateNodes up internal demanded witness
      share frontier hshareD hshare hfrontier

theorem decodeUpstreamObservation_eq {H d t : Nat}
    (up : PipelineGadget H d t) (internal : List Node)
    (demanded witness : List Nat)
    (hdemanded : demanded.Sublist (List.range d)) (env : Env) :
    decodeUpstreamObservation up internal demanded witness
        (observe up.g (upstreamCertificateNodes up internal demanded witness)
          env) =
      observe up.g (upstreamTranscriptNodes up internal demanded witness) env := by
  rw [observe_eq_map_eval]
  apply List.map_congr_left
  intro node hnode
  exact decodeUpstreamValue_eq_eval up internal demanded witness hdemanded
    env node hnode


/-! ## Structural closure data

Prepending a leaf keeps that leaf's still-external registered input as the
port for the next stage.  Its gates are the literal prefix of the compiled
array, so no gate translation is needed. -/

def prependedPorts {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    RegisterPorts (registeredComposite up.g tail.ports) where
  downstreamInput := up.ports.downstreamInput
  input_bound := by
    have hup := up.ports.input_bound
    have htail : 0 < tail.g.inputCount :=
      Nat.zero_lt_of_lt tail.ports.input_bound
    simpa [registeredComposite] using
      (show up.ports.downstreamInput <
          up.g.inputCount + (tail.g.inputCount - 1) by omega)
  inputGate := up.ports.inputGate
  input_gate_bound := by
    intro share hshare
    have hprefix := up.ports.input_gate_bound share
      (by simpa [registeredComposite, tail.d_eq, up.d_eq] using hshare)
    simp only [registeredComposite, registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, Array.size_append,
      boundaryRegisterGates, registeredDownGates]
    omega
  arrivalCycle := up.ports.arrivalCycle
  input_source_coherent := by
    intro share hshare
    have hshareUp : share < up.g.d := by
      simpa [registeredComposite, tail.d_eq, up.d_eq] using hshare
    obtain ⟨sharing, hgate, harrival⟩ :=
      up.ports.input_source_coherent share hshareUp
    refine ⟨sharing, ?_, ?_⟩
    · have hgateBound := up.ports.input_gate_bound share hshareUp
      have hgate' : up.g.circuit.gates[up.ports.inputGate share] =
          { kind := .inp sharing share, inputs := [] } := by
        simpa [hgateBound] using hgate
      change (up.g.circuit.gates ++
        (boundaryRegisterGates up.g tail.g ++
          registeredDownGates tail.ports))[up.ports.inputGate share]? = _
      rw [Array.getElem?_append]
      simp [hgateBound, hgate']
    · simp [registeredComposite, up.ports.input_bound, harrival]
  input_gates_injective := by
    intro i j hi hj heq
    apply up.ports.input_gates_injective i j
    · simpa [registeredComposite, tail.d_eq, up.d_eq] using hi
    · simpa [registeredComposite, tail.d_eq, up.d_eq] using hj
    · exact heq

theorem registeredComposite_wholeWindow {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    WholeWindow (registeredComposite up.g tail.ports) := by
  intro node _hnode
  rfl

theorem registeredComposite_output_at {H d t : Nat}
    (up tail : PipelineGadget H d t) (share : Nat) (hshare : share < d) :
    ((registeredComposite up.g tail.ports).output share).cycle =
      tail.outCycle := by
  simpa [registeredComposite] using tail.output_at share hshare

theorem registeredComposite_output_injective {H d t : Nat}
    (up tail : PipelineGadget H d t) (i j : Nat)
    (hi : i < d) (hj : j < d)
    (heq : (registeredComposite up.g tail.ports).output i =
      (registeredComposite up.g tail.ports).output j) : i = j := by
  apply tail.output_inj i j hi hj
  cases hiout : tail.g.output i with
  | mk igate icycle =>
      cases hjout : tail.g.output j with
      | mk jgate jcycle =>
          simp [registeredComposite, hiout, hjout] at heq
          simp [hiout, hjout, heq]

theorem prependedPorts_arrival_inside {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    (prependedPorts up tail).arrivalCycle < H := by
  exact up.arrival_inside

private theorem unhideRegisteredInput_injective (hidden : Nat) :
    Function.Injective (unhideRegisteredInput hidden) := by
  intro left right heq
  unfold unhideRegisteredInput at heq
  split at heq <;> split at heq <;> omega

/-- The complete external interface remains injective after hiding the
connected tail input.  Cross-component aliases are excluded by source
freshness; aliases within the copied suffix reduce to tail injectivity. -/
theorem registeredComposite_interfaceInjective {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail) :
    InterfaceInjective (registeredComposite up.g tail.ports) := by
  apply interfaceInjective_of_bounded
  intro input hinput share hshare other hother otherShare hotherShare heq
  by_cases hinputUp : input < up.g.inputCount
  · by_cases hotherUp : other < up.g.inputCount
    · have heqUp : up.g.inputArrival input share =
          up.g.inputArrival other otherShare := by
        simpa [registeredComposite, hinputUp, hotherUp] using heq
      exact interfaceInjective_bounded up.g up.interface_injective
        input hinputUp share
        (by simpa [registeredComposite, up.d_eq, tail.d_eq] using hshare)
        other hotherUp otherShare
        (by simpa [registeredComposite, up.d_eq, tail.d_eq] using hotherShare)
        heqUp
    · let tailInput := unhideRegisteredInput tail.ports.downstreamInput
          (other - up.g.inputCount)
      have hexternal : other - up.g.inputCount < tail.g.inputCount - 1 := by
        simp [registeredComposite] at hother
        omega
      have htailInput : tailInput < tail.g.inputCount :=
        unhideRegisteredInput_lt _ _ _ tail.ports.input_bound hexternal
      have hupAtom : up.g.inputArrival input share ∈ interfaceAtoms up.g := by
        simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
        exact ⟨input, hinputUp, share,
          by simpa [registeredComposite, up.d_eq, tail.d_eq] using hshare, rfl⟩
      have htailAtom : tail.g.inputArrival tailInput otherShare ∈
          interfaceAtoms tail.g := by
        simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
        exact ⟨tailInput, htailInput, otherShare,
          by simpa [registeredComposite, up.d_eq, tail.d_eq] using hotherShare,
          rfl⟩
      have hcross : up.g.inputArrival input share =
          shiftDownSrc up.g tail.g
            (tail.g.inputArrival tailInput otherShare) := by
        simpa [registeredComposite, hinputUp, hotherUp, tailInput] using heq
      exact (relevant_shiftDownSrc_fresh up tail glue _ _
        (pipeline_interface_relevant up _ hupAtom)
        (pipeline_interface_relevant tail _ htailAtom) hcross).elim
  · by_cases hotherUp : other < up.g.inputCount
    · let tailInput := unhideRegisteredInput tail.ports.downstreamInput
          (input - up.g.inputCount)
      have hexternal : input - up.g.inputCount < tail.g.inputCount - 1 := by
        simp [registeredComposite] at hinput
        omega
      have htailInput : tailInput < tail.g.inputCount :=
        unhideRegisteredInput_lt _ _ _ tail.ports.input_bound hexternal
      have htailAtom : tail.g.inputArrival tailInput share ∈
          interfaceAtoms tail.g := by
        simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
        exact ⟨tailInput, htailInput, share,
          by simpa [registeredComposite] using hshare, rfl⟩
      have hupAtom : up.g.inputArrival other otherShare ∈ interfaceAtoms up.g := by
        simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
        exact ⟨other, hotherUp, otherShare,
          by simpa [registeredComposite, up.d_eq, tail.d_eq] using hotherShare,
          rfl⟩
      have hcross : up.g.inputArrival other otherShare =
          shiftDownSrc up.g tail.g
            (tail.g.inputArrival tailInput share) := by
        simpa [registeredComposite, hinputUp, hotherUp, tailInput] using heq.symm
      exact (relevant_shiftDownSrc_fresh up tail glue _ _
        (pipeline_interface_relevant up _ hupAtom)
        (pipeline_interface_relevant tail _ htailAtom) hcross).elim
    · let tailInput := unhideRegisteredInput tail.ports.downstreamInput
          (input - up.g.inputCount)
      let otherTailInput := unhideRegisteredInput tail.ports.downstreamInput
          (other - up.g.inputCount)
      have hinputExternal : input - up.g.inputCount < tail.g.inputCount - 1 := by
        simp [registeredComposite] at hinput
        omega
      have hotherExternal : other - up.g.inputCount < tail.g.inputCount - 1 := by
        simp [registeredComposite] at hother
        omega
      have htailInput : tailInput < tail.g.inputCount :=
        unhideRegisteredInput_lt _ _ _ tail.ports.input_bound hinputExternal
      have hotherTailInput : otherTailInput < tail.g.inputCount :=
        unhideRegisteredInput_lt _ _ _ tail.ports.input_bound hotherExternal
      have hshifted : shiftDownSrc up.g tail.g
            (tail.g.inputArrival tailInput share) =
          shiftDownSrc up.g tail.g
            (tail.g.inputArrival otherTailInput otherShare) := by
        simpa [registeredComposite, hinputUp, hotherUp, tailInput,
          otherTailInput] using heq
      have htailEq := (shiftDownSrc_injective up.g tail.g) hshifted
      have hindices := interfaceInjective_bounded tail.g
        tail.interface_injective tailInput htailInput share
        (by simpa [registeredComposite] using hshare)
        otherTailInput hotherTailInput otherShare
        (by simpa [registeredComposite] using hotherShare) htailEq
      have hexternalEq : input - up.g.inputCount =
          other - up.g.inputCount := by
        apply unhideRegisteredInput_injective tail.ports.downstreamInput
        exact hindices.1
      exact ⟨by omega, hindices.2⟩

private theorem externalTailArrival_not_portInputAtoms {H d t : Nat}
    (tail : PipelineGadget H d t) (input share : Nat)
    (hinput : input < tail.g.inputCount)
    (hneq : input ≠ tail.ports.downstreamInput)
    (hshare : share < tail.g.d) :
    tail.g.inputArrival input share ∉ portInputAtoms tail.ports := by
  intro hport
  have hatom : tail.g.inputArrival input share ∈ interfaceAtoms tail.g := by
    simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
    exact ⟨input, hinput, share, hshare, rfl⟩
  have hconnected := portInputAtom_mem_connected_of_domain tail
    (tail.g.inputArrival input share) hport (by simp [hatom])
  simp only [connectedArrivalAtoms, List.mem_map, List.mem_range] at hconnected
  rcases hconnected with ⟨otherShare, hotherShare, heq⟩
  have hindices := interfaceInjective_bounded tail.g tail.interface_injective
    input hinput share hshare tail.ports.downstreamInput tail.ports.input_bound
    otherShare hotherShare heq.symm
  exact hneq hindices.1

private theorem registeredComposite_interface_origin {H d t : Nat}
    (up tail : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ interfaceAtoms (registeredComposite up.g tail.ports)) :
    (∃ input share, input < up.g.inputCount ∧ share < up.g.d ∧
      src = up.g.inputArrival input share) ∨
    (∃ input share, input < tail.g.inputCount ∧
      input ≠ tail.ports.downstreamInput ∧ share < tail.g.d ∧
      src = shiftDownSrc up.g tail.g (tail.g.inputArrival input share)) := by
  rw [interfaceAtoms, List.mem_flatMap] at hsrc
  rcases hsrc with ⟨input, hinput, hshareMem⟩
  rw [List.mem_map] at hshareMem
  rcases hshareMem with ⟨share, hshare, heq⟩
  have horigin := registeredComposite_inputArrival_cases up tail input share
    (by simpa using hinput) (by simpa using hshare)
  rcases horigin with ⟨upInput, hupInput, harrival⟩ |
      ⟨tailInput, htailInput, htailNe, harrival⟩
  · exact Or.inl ⟨upInput, share, hupInput,
      by simpa [registeredComposite, up.d_eq, tail.d_eq] using hshare,
      heq.symm.trans harrival⟩
  · exact Or.inr ⟨tailInput, share, htailInput, htailNe,
      by simpa [registeredComposite] using hshare, heq.symm.trans harrival⟩

private theorem registeredComposite_interface_relevant {H d t : Nat}
    (up tail : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ interfaceAtoms (registeredComposite up.g tail.ports)) :
    src ∈ Execution.relevantSrcs
      (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).horizon := by
  rcases registeredComposite_interface_origin up tail src hsrc with
      ⟨input, share, hinput, hshare, rfl⟩ |
      ⟨input, share, hinput, hneq, hshare, rfl⟩
  · apply upstream_relevant_composite up tail
    apply pipeline_interface_relevant up
    simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
    exact ⟨input, hinput, share, hshare, rfl⟩
  · apply shifted_tail_surviving_relevant_composite up tail
    · apply pipeline_interface_relevant tail
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨input, hinput, share, hshare, rfl⟩
    · exact externalTailArrival_not_portInputAtoms tail input share
        hinput hneq hshare

private theorem registeredComposite_interface_not_random {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src)
    (hsrc : src ∈ interfaceAtoms (registeredComposite up.g tail.ports)) :
    src ∉ (registeredComposite up.g tail.ports).randomness := by
  rcases registeredComposite_interface_origin up tail src hsrc with
      ⟨input, share, hinput, hshare, rfl⟩ |
      ⟨input, share, hinput, _hneq, hshare, rfl⟩
  · apply upstream_relevant_not_composite_random up tail glue
    · apply pipeline_interface_relevant up
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨input, hinput, share, hshare, rfl⟩
    · exact sourceDomainsDisjoint_not_mem _ _
        up.source_partition.2.2.1 _ (by
          simp only [interfaceAtoms, List.mem_flatMap, List.mem_range,
            List.mem_map]
          exact ⟨input, hinput, share, hshare, rfl⟩)
  · apply shifted_tail_relevant_not_composite_random up tail glue
    · apply pipeline_interface_relevant tail
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨input, hinput, share, hshare, rfl⟩
    · exact sourceDomainsDisjoint_not_mem _ _
        tail.source_partition.2.2.1 _ (by
          simp only [interfaceAtoms, List.mem_flatMap, List.mem_range,
            List.mem_map]
          exact ⟨input, hinput, share, hshare, rfl⟩)

private theorem registeredComposite_interface_not_public {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src)
    (hsrc : src ∈ interfaceAtoms (registeredComposite up.g tail.ports)) :
    src ∉ publicAtoms (registeredComposite up.g tail.ports) := by
  rcases registeredComposite_interface_origin up tail src hsrc with
      ⟨input, share, hinput, hshare, rfl⟩ |
      ⟨input, share, hinput, _hneq, hshare, rfl⟩
  · apply upstream_relevant_not_composite_public up tail glue
    · apply pipeline_interface_relevant up
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨input, hinput, share, hshare, rfl⟩
    · exact sourceDomainsDisjoint_not_mem _ _
        up.source_partition.2.2.2.1 _ (by
          simp only [interfaceAtoms, List.mem_flatMap, List.mem_range,
            List.mem_map]
          exact ⟨input, hinput, share, hshare, rfl⟩)
  · apply shifted_tail_relevant_not_composite_public up tail glue
    · apply pipeline_interface_relevant tail
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨input, hinput, share, hshare, rfl⟩
    · exact sourceDomainsDisjoint_not_mem _ _
        tail.source_partition.2.2.2.1 _ (by
          simp only [interfaceAtoms, List.mem_flatMap, List.mem_range,
            List.mem_map]
          exact ⟨input, hinput, share, hshare, rfl⟩)

private theorem registeredComposite_random_relevant {H d t : Nat}
    (up tail : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ (registeredComposite up.g tail.ports).randomness) :
    src ∈ Execution.relevantSrcs
      (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).horizon := by
  simp only [registeredComposite, List.mem_append, List.mem_map] at hsrc
  rcases hsrc with hup | ⟨tailSrc, htail, rfl⟩
  · apply upstream_relevant_composite up tail
    have hall := List.all_eq_true.mp up.source_partition.2.1 _ hup
    simpa [List.contains_iff_mem] using hall
  · apply shifted_tail_surviving_relevant_composite up tail
    · have hall := List.all_eq_true.mp tail.source_partition.2.1 _ htail
      simpa [List.contains_iff_mem] using hall
    · exact pipeline_random_not_portInputAtoms tail _ htail

private theorem registeredComposite_random_not_public {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src)
    (hsrc : src ∈ (registeredComposite up.g tail.ports).randomness) :
    src ∉ publicAtoms (registeredComposite up.g tail.ports) := by
  simp only [registeredComposite, List.mem_append, List.mem_map] at hsrc
  rcases hsrc with hup | ⟨tailSrc, htail, rfl⟩
  · apply upstream_relevant_not_composite_public up tail glue
    · have hall := List.all_eq_true.mp up.source_partition.2.1 _ hup
      simpa [List.contains_iff_mem] using hall
    · exact sourceDomainsDisjoint_not_mem _ _
        up.source_partition.2.2.2.2.1 _ hup
  · apply shifted_tail_relevant_not_composite_public up tail glue
    · have hall := List.all_eq_true.mp tail.source_partition.2.1 _ htail
      simpa [List.contains_iff_mem] using hall
    · exact sourceDomainsDisjoint_not_mem _ _
        tail.source_partition.2.2.2.2.1 _ htail

private theorem sourcePinned_of_public_not_domains (g : GadgetInstance)
    (src : Src) (hpublic : src ∈ publicAtoms g)
    (hinterface : src ∉ interfaceAtoms g) (hrandom : src ∉ g.randomness) :
    SourcePinned g src := by
  obtain ⟨value, hlookup⟩ :=
    Execution.lookupAssoc_some_of_mem_key src g.publicFixing hpublic
  refine ⟨⟨value, hlookup⟩, ?_, hrandom⟩
  intro input hinput share hshare heq
  apply hinterface
  simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
  exact ⟨input, by simpa using hinput, share, by simpa using hshare, heq⟩

private theorem sourcePinned_public {g : GadgetInstance} (src : Src)
    (hpinned : SourcePinned g src) : src ∈ publicAtoms g := by
  rcases hpinned.1 with ⟨value, hlookup⟩
  exact List.mem_map.mpr
    ⟨(src, value), Execution.lookupAssoc_some_mem src g.publicFixing value
      hlookup, rfl⟩

private theorem sourcePinned_not_interface {g : GadgetInstance} (src : Src)
    (hpinned : SourcePinned g src) : src ∉ interfaceAtoms g := by
  intro hinterface
  rw [interfaceAtoms, List.mem_flatMap] at hinterface
  rcases hinterface with ⟨input, hinput, hshareMem⟩
  rw [List.mem_map] at hshareMem
  rcases hshareMem with ⟨share, hshare, heq⟩
  exact hpinned.2.1 input hinput share hshare heq

private theorem registeredComposite_iniReg_pinned {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (gate : Nat)
    (hrelevant : (.iniReg gate : Src) ∈ Execution.relevantSrcs
      (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).horizon) :
    SourcePinned (registeredComposite up.g tail.ports) (.iniReg gate) := by
  rw [relevantSrcs_registeredComposite up tail] at hrelevant
  simp only [List.mem_eraseDups, List.mem_append] at hrelevant
  rcases hrelevant with (hup | hboundary) | htail
  · have hpinned : SourcePinned up.g (.iniReg gate) := by
      have hall := List.all_eq_true.mp up.source_partition.2.2.2.2.2 _ hup
      simpa using hall
    apply sourcePinned_of_public_not_domains
    · have hpublic := sourcePinned_public _ hpinned
      unfold publicAtoms at hpublic ⊢
      simp only [registeredComposite, List.map_append, List.mem_append]
      exact Or.inl (Or.inl hpublic)
    · exact upstream_relevant_not_composite_interface up tail glue _ hup
        (sourcePinned_not_interface _ hpinned)
    · exact upstream_relevant_not_composite_random up tail glue _ hup
        hpinned.2.2
  · simp only [List.mem_map, List.mem_range] at hboundary
    rcases hboundary with ⟨share, hshare, heq⟩
    have hshareTail : share < tail.g.d := by simpa [tail.d_eq] using hshare
    have hgateEq : boundaryRegister up.g share = gate := by simpa using heq
    subst gate
    apply sourcePinned_of_public_not_domains
    · unfold publicAtoms
      rw [List.mem_map]
      refine ⟨(.iniReg (boundaryRegister up.g share), false), ?_, rfl⟩
      simp only [registeredComposite, List.mem_append, List.mem_map,
        List.mem_range]
      exact Or.inr ⟨share, hshareTail, rfl⟩
    · exact boundaryInit_not_composite_interface up tail glue share hshareTail
    · exact boundaryInit_not_composite_random up tail glue share hshareTail
  · simp only [shiftedSurvivingTailSrcs, List.mem_map, List.mem_filter,
      Bool.not_eq_true', List.contains_iff_mem] at htail
    rcases htail with ⟨tailSrc, ⟨htailRelevant, hsurvives⟩, hshift⟩
    cases tailSrc with
    | iniReg tailGate =>
        rw [← hshift]
        have hpinned : SourcePinned tail.g (.iniReg tailGate) := by
          have hall := List.all_eq_true.mp tail.source_partition.2.2.2.2.2 _
            htailRelevant
          simpa using hall
        apply sourcePinned_of_public_not_domains
        · have hpublic := sourcePinned_public _ hpinned
          unfold publicAtoms at hpublic ⊢
          simp only [registeredComposite, List.map_append, List.mem_append,
            List.map_map, Function.comp_apply]
          refine Or.inl (Or.inr ?_)
          rw [List.mem_map]
          rcases hpinned.1 with ⟨value, hlookup⟩
          exact ⟨(.iniReg tailGate, value),
            Execution.lookupAssoc_some_mem _ _ _ hlookup, by
              simp [shiftDownSrc]⟩
        · apply shifted_tail_relevant_not_composite_interface up tail glue
            (.iniReg tailGate) htailRelevant
          exact sourcePinned_not_interface _ hpinned
        · exact shifted_tail_relevant_not_composite_random up tail glue
            (.iniReg tailGate) htailRelevant hpinned.2.2
    | inp sharing share cycle => simp [shiftDownSrc] at hshift
    | rnd id cycle => simp [shiftDownSrc] at hshift
    | ini id cycle => simp [shiftDownSrc] at hshift
    | ctl id cycle => simp [shiftDownSrc] at hshift

/-- P4: every source-faithfulness clause is preserved by the registered
splice.  The proof consumes P3 for relevance and pinning and the origin
lemmas above for the three disjoint finite domains. -/
theorem registeredComposite_sourcePartition {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail) :
    SourcePartition (registeredComposite up.g tail.ports) := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · apply List.all_eq_true.mpr
    intro src hsrc
    simpa [List.contains_iff_mem] using
      registeredComposite_interface_relevant up tail src hsrc
  · apply List.all_eq_true.mpr
    intro src hsrc
    simpa [List.contains_iff_mem] using
      registeredComposite_random_relevant up tail src hsrc
  · apply List.all_eq_true.mpr
    intro src hsrc
    simpa [List.contains_iff_mem] using
      registeredComposite_interface_not_random up tail glue src hsrc
  · apply List.all_eq_true.mpr
    intro src hsrc
    simpa [List.contains_iff_mem] using
      registeredComposite_interface_not_public up tail glue src hsrc
  · apply List.all_eq_true.mpr
    intro src hsrc
    simpa [List.contains_iff_mem] using
      registeredComposite_random_not_public up tail glue src hsrc
  · apply List.all_eq_true.mpr
    intro src hsrc
    cases src with
    | iniReg gate =>
        simpa using registeredComposite_iniReg_pinned up tail glue gate hsrc
    | inp | rnd | ini | ctl => rfl

private theorem upstream_initPinned_transport {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail) (gate : Nat)
    (hpinned : SourcePinned up.g (.iniReg gate))
    (hfalse : Execution.lookupAssoc (.iniReg gate) up.g.publicFixing =
      some false) :
    SourcePinned (registeredComposite up.g tail.ports) (.iniReg gate) ∧
      Execution.lookupAssoc (.iniReg gate)
        (registeredComposite up.g tail.ports).publicFixing = some false := by
  have hpublic := sourcePinned_public _ hpinned
  have hrelevant := pipeline_public_relevant up _ hpublic
  constructor
  · apply sourcePinned_of_public_not_domains
    · unfold publicAtoms at hpublic ⊢
      simp only [registeredComposite, List.map_append, List.mem_append]
      exact Or.inl (Or.inl hpublic)
    · exact upstream_relevant_not_composite_interface up tail glue _ hrelevant
        (sourcePinned_not_interface _ hpinned)
    · exact upstream_relevant_not_composite_random up tail glue _ hrelevant
        hpinned.2.2
  · simpa [registeredComposite, List.append_assoc] using
      lookupAssoc_append_of_some (.iniReg gate) up.g.publicFixing
        (tail.g.publicFixing.map (fun entry =>
            (shiftDownSrc up.g tail.g entry.1, entry.2)) ++
          (List.range tail.g.d).map (fun share =>
            (.iniReg (boundaryRegister up.g share), false))) false hfalse

private theorem shifted_initPinned_transport {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail) (gate : Nat)
    (hpinned : SourcePinned tail.g (.iniReg gate))
    (hfalse : Execution.lookupAssoc (.iniReg gate) tail.g.publicFixing =
      some false) :
    SourcePinned (registeredComposite up.g tail.ports)
        (shiftDownSrc up.g tail.g (.iniReg gate)) ∧
      Execution.lookupAssoc (shiftDownSrc up.g tail.g (.iniReg gate))
        (registeredComposite up.g tail.ports).publicFixing = some false := by
  have hpublic := sourcePinned_public _ hpinned
  have hrelevant := pipeline_public_relevant tail _ hpublic
  have hsurvives := pipeline_public_not_portInputAtoms tail _ hpublic
  have hnotUpPublic : shiftDownSrc up.g tail.g (.iniReg gate) ∉
      publicAtoms up.g := by
    intro hupPublic
    have hupRelevant := pipeline_public_relevant up _ hupPublic
    exact relevant_shiftDownSrc_fresh up tail glue _ _ hupRelevant hrelevant rfl
  have hupNone : Execution.lookupAssoc
      (shiftDownSrc up.g tail.g (.iniReg gate)) up.g.publicFixing = none :=
    Execution.lookupAssoc_none_of_not_mem _ _ hnotUpPublic
  have htailLookup : Execution.lookupAssoc
      (shiftDownSrc up.g tail.g (.iniReg gate))
      (tail.g.publicFixing.map fun entry =>
        (shiftDownSrc up.g tail.g entry.1, entry.2)) = some false :=
    lookupAssoc_map_key_of_injective (shiftDownSrc up.g tail.g)
      (shiftDownSrc_injective up.g tail.g) (.iniReg gate)
      tail.g.publicFixing false hfalse
  constructor
  · apply sourcePinned_of_public_not_domains
    · unfold publicAtoms at hpublic ⊢
      simp only [registeredComposite, List.map_append, List.mem_append,
        List.map_map, Function.comp_apply]
      refine Or.inl (Or.inr ?_)
      rw [List.mem_map]
      rcases hpinned.1 with ⟨value, hlookup⟩
      exact ⟨(.iniReg gate, value),
        Execution.lookupAssoc_some_mem _ _ _ hlookup, rfl⟩
    · exact shifted_tail_relevant_not_composite_interface up tail glue _
        hrelevant (sourcePinned_not_interface _ hpinned)
    · exact shifted_tail_relevant_not_composite_random up tail glue _
        hrelevant hpinned.2.2
  · rw [show (registeredComposite up.g tail.ports).publicFixing =
        (up.g.publicFixing ++ tail.g.publicFixing.map (fun entry =>
          (shiftDownSrc up.g tail.g entry.1, entry.2))) ++
          (List.range tail.g.d).map (fun share =>
            (.iniReg (boundaryRegister up.g share), false)) by rfl]
    rw [lookupAssoc_append_of_some]
    rw [lookupAssoc_append_of_none _ _ _ hupNone]
    exact htailLookup

private theorem boundary_initPinned_transport {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (share : Nat) (hshare : share < tail.g.d) :
    SourcePinned (registeredComposite up.g tail.ports)
        (.iniReg (boundaryRegister up.g share)) ∧
      Execution.lookupAssoc (.iniReg (boundaryRegister up.g share))
        (registeredComposite up.g tail.ports).publicFixing = some false := by
  let src : Src := .iniReg (boundaryRegister up.g share)
  have hnotUpPublic : src ∉ publicAtoms up.g := by
    intro hpublic
    exact upstream_relevant_not_boundaryInit up tail src
      (pipeline_public_relevant up src hpublic)
      (by simp only [List.mem_map, List.mem_range]
          exact ⟨share, hshare, rfl⟩)
  have hnotTailPublic : src ∉
      (tail.g.publicFixing.map fun entry =>
        (shiftDownSrc up.g tail.g entry.1, entry.2)).map Prod.fst := by
    intro hpublic
    simp only [List.map_map, Function.comp_apply, List.mem_map] at hpublic
    rcases hpublic with ⟨entry, hentry, heq⟩
    have htailPublic : entry.1 ∈ publicAtoms tail.g :=
      List.mem_map.mpr ⟨entry, hentry, rfl⟩
    exact shifted_tail_relevant_not_boundaryInit up tail entry.1
      (by simp only [List.mem_map, List.mem_range]
          exact ⟨share, hshare, heq.symm⟩)
  have hupNone : Execution.lookupAssoc src up.g.publicFixing = none :=
    Execution.lookupAssoc_none_of_not_mem _ _ hnotUpPublic
  have htailNone : Execution.lookupAssoc src
      (tail.g.publicFixing.map fun entry =>
        (shiftDownSrc up.g tail.g entry.1, entry.2)) = none :=
    Execution.lookupAssoc_none_of_not_mem _ _ hnotTailPublic
  constructor
  · apply sourcePinned_of_public_not_domains
    · unfold publicAtoms
      rw [List.mem_map]
      refine ⟨(src, false), ?_, rfl⟩
      simp only [registeredComposite, List.mem_append, List.mem_map,
        List.mem_range]
      exact Or.inr ⟨share, hshare, rfl⟩
    · exact boundaryInit_not_composite_interface up tail glue share hshare
    · exact boundaryInit_not_composite_random up tail glue share hshare
  · rw [show (registeredComposite up.g tail.ports).publicFixing =
        (up.g.publicFixing ++ tail.g.publicFixing.map (fun entry =>
          (shiftDownSrc up.g tail.g entry.1, entry.2))) ++
          (List.range tail.g.d).map (fun lane =>
            (.iniReg (boundaryRegister up.g lane), false)) by rfl]
    rw [lookupAssoc_append_of_none]
    · exact boundaryFixing_lookup up tail share hshare
    · rw [lookupAssoc_append_of_none _ _ _ hupNone]
      exact htailNone

private theorem registeredComposite_prefix_gate {H d t : Nat}
    (up tail : PipelineGadget H d t) (gate : Nat)
    (hgate : gate < up.g.circuit.gates.size) :
    (registeredComposite up.g tail.ports).circuit.gates[gate]? =
      up.g.circuit.gates[gate]? := by
  change (up.g.circuit.gates ++
    (boundaryRegisterGates up.g tail.g ++
      registeredDownGates tail.ports))[gate]? = _
  exact Array.getElem?_append_left hgate

private theorem registeredComposite_suffix_gate {H d t : Nat}
    (up tail : PipelineGadget H d t) (gate : Nat)
    (hgate : gate < tail.g.circuit.gates.size) :
    (registeredComposite up.g tail.ports).circuit.gates[
        downstreamOffset up.g tail.g + gate]? =
      tail.g.circuit.gates[gate]?.map
        (wireRegisteredDownGate (up := up.g) tail.ports gate) := by
  simp [registeredComposite, registeredCompositeCircuit,
    UniversalSStage1.appendCircuit, downstreamOffset,
    boundaryRegisterGates, registeredDownGates, hgate, Nat.add_assoc]

/-- Every register in the compiled prefix, inserted boundary, and surviving
tail suffix retains a public false reset. -/
theorem registeredComposite_pinnedInit {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail) :
    PinnedInit (registeredComposite up.g tail.ports) := by
  unfold PinnedInit
  apply List.all_eq_true.mpr
  intro gate hgateMem
  have hgate : gate <
      (registeredComposite up.g tail.ports).circuit.gates.size := by
    simpa using hgateMem
  by_cases hprefix : gate < up.g.circuit.gates.size
  · have hsame := registeredComposite_prefix_gate up tail gate hprefix
    have hupPin := List.all_eq_true.mp up.pinned_init gate (by simpa using hprefix)
    cases hentry : up.g.circuit.gates[gate]? with
    | none => simp [initPinnedAt, hsame, hentry]
    | some entry =>
        rcases entry with ⟨kind, inputs⟩
        cases kind <;>
          simp [initPinnedAt, hsame, hentry] at hupPin ⊢
        exact upstream_initPinned_transport up tail glue gate hupPin.1 hupPin.2
  · by_cases hboundary : gate < downstreamOffset up.g tail.g
    · let share := gate - up.g.circuit.gates.size
      have hshare : share < tail.g.d := by
        dsimp [share]
        unfold downstreamOffset at hboundary
        omega
      have hgateEq : gate = boundaryRegister up.g share := by
        dsimp [share]
        unfold boundaryRegister
        omega
      rw [hgateEq]
      unfold initPinnedAt
      change (match (registeredCompositeCircuit up.g tail.ports).gates[
          boundaryRegister up.g share]? with
        | some { kind := .reg, inputs := _ } =>
            decide (SourcePinned (registeredComposite up.g tail.ports)
                (.iniReg (boundaryRegister up.g share)) ∧
              Execution.lookupAssoc (.iniReg (boundaryRegister up.g share))
                (registeredComposite up.g tail.ports).publicFixing = some false)
        | _ => true) = true
      rw [registeredComposite_boundary_gate up.g tail.ports share hshare]
      simpa using boundary_initPinned_transport up tail glue share hshare
    · let tailGate := gate - downstreamOffset up.g tail.g
      have htailGate : tailGate < tail.g.circuit.gates.size := by
        have hsize : (registeredComposite up.g tail.ports).circuit.gates.size =
            downstreamOffset up.g tail.g + tail.g.circuit.gates.size := by
          simp [registeredComposite, registeredCompositeCircuit,
            UniversalSStage1.appendCircuit, boundaryRegisterGates,
            registeredDownGates, downstreamOffset, Nat.add_assoc]
        rw [hsize] at hgate
        dsimp [tailGate]
        omega
      have hgateEq : gate = downstreamOffset up.g tail.g + tailGate := by
        dsimp [tailGate]
        omega
      rw [hgateEq]
      have htailPin := List.all_eq_true.mp tail.pinned_init tailGate
        (by simpa using htailGate)
      have hsuffix := registeredComposite_suffix_gate up tail tailGate htailGate
      cases hentry : tail.g.circuit.gates[tailGate]? with
      | none =>
          have : tail.g.circuit.gates[tailGate]? =
              some tail.g.circuit.gates[tailGate] :=
            Array.getElem?_eq_getElem htailGate
          rw [hentry] at this
          contradiction
      | some entry =>
          rcases entry with ⟨kind, inputs⟩
          cases hconnected : connectedShare? tail.ports tailGate with
          | some connected =>
              simp [initPinnedAt, hsuffix, hentry, wireRegisteredDownGate,
                hconnected]
          | none =>
              cases kind <;>
                simp [initPinnedAt, hsuffix, hentry, wireRegisteredDownGate,
                  hconnected] at htailPin ⊢
              exact shifted_initPinned_transport up tail glue tailGate
                htailPin.1 htailPin.2

private theorem inpGate_relevant (g : GadgetInstance)
    (gate sharing share cycle : Nat) (inputs : List (Nat × Nat))
    (hcycle : cycle < g.horizon)
    (hgate : g.circuit.gates[gate]? =
      some { kind := .inp sharing share, inputs := inputs }) :
    (.inp sharing share cycle : Src) ∈
      Execution.relevantSrcs g.circuit g.horizon := by
  rw [UniversalSStage1.relevantSrcs_eq_public, List.mem_eraseDups,
    List.mem_flatMap]
  refine ⟨({ kind := .inp sharing share, inputs := inputs }, gate), ?_, ?_⟩
  · rw [List.mk_mem_zipIdx_iff_getElem?, Array.getElem?_toList]
    exact hgate
  · simp [UniversalSStage1.publicGateSrcs, hcycle]

private theorem inpGate_zero_relevant (g : GadgetInstance)
    (gate sharing share : Nat) (inputs : List (Nat × Nat))
    (hpos : 0 < g.horizon)
    (hgate : g.circuit.gates[gate]? =
      some { kind := .inp sharing share, inputs := inputs }) :
    (.inp sharing share 0 : Src) ∈
      Execution.relevantSrcs g.circuit g.horizon :=
  inpGate_relevant g gate sharing share 0 inputs hpos hgate

theorem prependedPorts_portInputAtoms {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    portInputAtoms (prependedPorts up tail) = portInputAtoms up.ports := by
  unfold portInputAtoms
  have hd : (registeredComposite up.g tail.ports).d = up.g.d := by
    simp [registeredComposite, up.d_eq, tail.d_eq]
  rw [hd]
  apply congrArg List.flatten
  apply List.map_congr_left
  intro share hshare
  have hshareUp : share < up.g.d := by simpa using hshare
  have hgateBound := up.ports.input_gate_bound share hshareUp
  simp only [prependedPorts]
  rw [registeredComposite_prefix_gate up tail _ hgateBound]
  simp [prependedPorts, registeredComposite, up.horizon_eq, tail.horizon_eq]

theorem prependedPorts_connectedArrivalAtoms {H d t : Nat}
    (up tail : PipelineGadget H d t) :
    connectedArrivalAtoms (prependedPorts up tail) =
      connectedArrivalAtoms up.ports := by
  unfold connectedArrivalAtoms
  have hd : (registeredComposite up.g tail.ports).d = up.g.d := by
    simp [registeredComposite, up.d_eq, tail.d_eq]
  rw [hd]
  apply List.map_congr_left
  intro share hshare
  have hinput := up.ports.input_bound
  simp [prependedPorts, registeredComposite, hinput]

private theorem registeredComposite_public_relevant {H d t : Nat}
    (up tail : PipelineGadget H d t) (src : Src)
    (hsrc : src ∈ publicAtoms (registeredComposite up.g tail.ports)) :
    src ∈ Execution.relevantSrcs
      (registeredComposite up.g tail.ports).circuit
      (registeredComposite up.g tail.ports).horizon := by
  unfold publicAtoms at hsrc
  rw [List.mem_map] at hsrc
  rcases hsrc with ⟨entry, hentry, rfl⟩
  simp only [registeredComposite, List.mem_append] at hentry
  rcases hentry with (hup | htail) | hboundary
  · apply upstream_relevant_composite up tail
    apply pipeline_public_relevant up
    exact List.mem_map.mpr ⟨entry, hup, rfl⟩
  · rw [List.mem_map] at htail
    rcases htail with ⟨tailEntry, htailEntry, rfl⟩
    apply shifted_tail_surviving_relevant_composite up tail
    · apply pipeline_public_relevant tail
      exact List.mem_map.mpr ⟨tailEntry, htailEntry, rfl⟩
    · apply pipeline_public_not_portInputAtoms tail
      exact List.mem_map.mpr ⟨tailEntry, htailEntry, rfl⟩
  · rw [List.mem_map] at hboundary
    rcases hboundary with ⟨share, hshare, rfl⟩
    exact boundaryInit_relevant_composite up tail share
      (by simpa [tail.d_eq] using hshare)

private theorem prependedPort_input_gate_unique {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (share gate sharing : Nat) (inputs : List (Nat × Nat))
    (hshare : share < up.g.d)
    (hgate : gate < (registeredComposite up.g tail.ports).circuit.gates.size)
    (hport : up.g.circuit.gates[up.ports.inputGate share]? =
      some { kind := .inp sharing share, inputs := [] })
    (hother : (registeredComposite up.g tail.ports).circuit.gates[gate]? =
      some { kind := .inp sharing share, inputs := inputs }) :
    gate = up.ports.inputGate share := by
  by_cases hprefix : gate < up.g.circuit.gates.size
  · have hotherUp : up.g.circuit.gates[gate]? =
        some { kind := .inp sharing share, inputs := inputs } := by
      rw [← registeredComposite_prefix_gate up tail gate hprefix]
      exact hother
    have hshareAll := List.all_eq_true.mp up.port_source_exclusive.2.1
      share (by simpa using hshare)
    have hgateAll := List.all_eq_true.mp hshareAll gate (by simpa using hprefix)
    simpa [hport, hotherUp] using hgateAll
  · by_cases hboundary : gate < downstreamOffset up.g tail.g
    · let boundaryShare := gate - up.g.circuit.gates.size
      have hboundaryShare : boundaryShare < tail.g.d := by
        dsimp [boundaryShare]
        unfold downstreamOffset at hboundary
        omega
      have hgateEq : gate = boundaryRegister up.g boundaryShare := by
        dsimp [boundaryShare]
        unfold boundaryRegister
        omega
      rw [hgateEq] at hother
      have hreg := registeredComposite_boundary_gate up.g tail.ports
        boundaryShare hboundaryShare
      change (registeredCompositeCircuit up.g tail.ports).gates[
        boundaryRegister up.g boundaryShare]? = _ at hother
      rw [hreg] at hother
      simp at hother
    · let tailGate := gate - downstreamOffset up.g tail.g
      have htailGate : tailGate < tail.g.circuit.gates.size := by
        have hsize : (registeredComposite up.g tail.ports).circuit.gates.size =
            downstreamOffset up.g tail.g + tail.g.circuit.gates.size := by
          simp [registeredComposite, registeredCompositeCircuit,
            UniversalSStage1.appendCircuit, boundaryRegisterGates,
            registeredDownGates, downstreamOffset, Nat.add_assoc]
        rw [hsize] at hgate
        dsimp [tailGate]
        omega
      have hgateEq : gate = downstreamOffset up.g tail.g + tailGate := by
        dsimp [tailGate]
        omega
      rw [hgateEq] at hother
      have hsuffix := registeredComposite_suffix_gate up tail tailGate htailGate
      rw [hsuffix] at hother
      have htailSome : tail.g.circuit.gates[tailGate]? =
          some tail.g.circuit.gates[tailGate] :=
        Array.getElem?_eq_getElem htailGate
      rw [htailSome] at hother
      cases hconnected : connectedShare? tail.ports tailGate with
      | some connected =>
          simp [wireRegisteredDownGate, hconnected] at hother
      | none =>
          cases htailEntry : tail.g.circuit.gates[tailGate] with
          | mk kind inputs =>
              cases kind <;>
                simp [wireRegisteredDownGate, hconnected, htailEntry] at hother
              rename_i tailSharing tailShare
              have htailEntryOpt : tail.g.circuit.gates[tailGate]? =
                  some { kind := .inp tailSharing tailShare, inputs := inputs } := by
                rw [Array.getElem?_eq_getElem htailGate, htailEntry]
              have hsharingEq : tailSharing = sharing := hother.1.1
              have hshareEq : tailShare = share := hother.1.2
              subst sharing
              subst share
              have hpos : 0 < H := Nat.zero_lt_of_lt tail.arrival_inside
              have hupRelevant : (.inp tailSharing tailShare 0 : Src) ∈
                  Execution.relevantSrcs up.g.circuit up.g.horizon :=
                inpGate_zero_relevant up.g (up.ports.inputGate tailShare)
                  tailSharing tailShare []
                  (by simpa [up.horizon_eq] using hpos) hport
              have htailRelevant : (.inp tailSharing tailShare 0 : Src) ∈
                  Execution.relevantSrcs tail.g.circuit tail.g.horizon :=
                inpGate_zero_relevant tail.g tailGate tailSharing tailShare
                  inputs
                  (by simpa [tail.horizon_eq] using hpos) (by
                    simpa [hother] using htailEntryOpt)
              exact (glue.fresh _ hupRelevant htailRelevant).elim

private theorem prependedPort_off_not_composite_domain {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (src : Src) (hport : src ∈ portInputAtoms up.ports)
    (hoff : src ∉ connectedArrivalAtoms up.ports) :
    src ∉ interfaceAtoms (registeredComposite up.g tail.ports) ++
      (registeredComposite up.g tail.ports).randomness ++
      publicAtoms (registeredComposite up.g tail.ports) := by
  rcases mem_portInputAtoms_cases up src hport with
    ⟨share, hshare, sharing, cycle, hcycle, hgate, hsrcEq⟩
  have hupRelevant : src ∈
      Execution.relevantSrcs up.g.circuit up.g.horizon := by
    rw [hsrcEq]
    exact inpGate_relevant up.g (up.ports.inputGate share) sharing share cycle []
      hcycle hgate
  have hoffFiltered : src ∈ (portInputAtoms up.ports).filter fun atom =>
      !(connectedArrivalAtoms up.ports).contains atom := by
    simp [hport, List.contains_iff_mem, hoff]
  have hnotUpDomain : src ∉
      interfaceAtoms up.g ++ up.g.randomness ++ publicAtoms up.g :=
    sourceDomainsDisjoint_not_mem _ _ up.port_source_exclusive.2.2 src
      hoffFiltered
  intro hdomain
  simp only [List.mem_append] at hdomain
  rcases hdomain with (hinterface | hrandom) | hpublic
  · rcases registeredComposite_interface_origin up tail src hinterface with
        ⟨input, lane, hinput, hlane, heq⟩ |
        ⟨input, lane, hinput, _hneq, hlane, heq⟩
    · apply hnotUpDomain
      apply List.mem_append.mpr
      apply Or.inl
      apply List.mem_append.mpr
      apply Or.inl
      rw [interfaceAtoms, List.mem_flatMap]
      exact ⟨input, List.mem_range.mpr hinput,
        List.mem_map.mpr ⟨lane, List.mem_range.mpr hlane, heq.symm⟩⟩
    · have htailAtom : tail.g.inputArrival input lane ∈
          interfaceAtoms tail.g := by
        simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
        exact ⟨input, hinput, lane, hlane, rfl⟩
      exact relevant_shiftDownSrc_fresh up tail glue src _ hupRelevant
        (pipeline_interface_relevant tail _ htailAtom) heq
  · simp only [registeredComposite, List.mem_append, List.mem_map] at hrandom
    rcases hrandom with hupRandom | ⟨tailRandom, htailRandom, heq⟩
    · exact hnotUpDomain (List.mem_append.mpr (Or.inl
        (List.mem_append.mpr (Or.inr hupRandom))))
    · have htailRelevant : tailRandom ∈
          Execution.relevantSrcs tail.g.circuit tail.g.horizon := by
        have hall := List.all_eq_true.mp tail.source_partition.2.1 _ htailRandom
        simpa [List.contains_iff_mem] using hall
      exact relevant_shiftDownSrc_fresh up tail glue src tailRandom hupRelevant
        htailRelevant heq.symm
  · unfold publicAtoms at hpublic
    rw [List.mem_map] at hpublic
    rcases hpublic with ⟨entry, hentry, heq⟩
    simp only [registeredComposite, List.mem_append] at hentry
    rcases hentry with (hupPublic | htailPublic) | hboundary
    · apply hnotUpDomain
      exact List.mem_append.mpr (Or.inr
        (List.mem_map.mpr ⟨entry, hupPublic, heq⟩))
    · rw [List.mem_map] at htailPublic
      rcases htailPublic with ⟨tailEntry, htailEntry, hentryEq⟩
      subst entry
      have htailAtom : tailEntry.1 ∈ publicAtoms tail.g :=
        List.mem_map.mpr ⟨tailEntry, htailEntry, rfl⟩
      exact relevant_shiftDownSrc_fresh up tail glue src tailEntry.1 hupRelevant
        (pipeline_public_relevant tail _ htailAtom) heq.symm
    · rw [List.mem_map] at hboundary
      rcases hboundary with ⟨boundaryShare, _hboundaryShare, hentryEq⟩
      subst entry
      rw [hsrcEq] at heq
      cases heq

theorem registeredComposite_portSourceExclusive {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail) :
    PortSourceExclusive (prependedPorts up tail) := by
  refine ⟨?_, ?_, ?_⟩
  · apply List.all_eq_true.mpr
    intro src hsrc
    simpa [List.contains_iff_mem] using
      registeredComposite_public_relevant up tail src hsrc
  · apply List.all_eq_true.mpr
    intro share hshareMem
    have hshare : share < up.g.d := by
      simpa [registeredComposite, up.d_eq, tail.d_eq] using hshareMem
    obtain ⟨sharing, hport, _harrival⟩ :=
      up.ports.input_source_coherent share hshare
    have hportBound := up.ports.input_gate_bound share hshare
    have hcompositePort :
        (registeredComposite up.g tail.ports).circuit.gates[
          (prependedPorts up tail).inputGate share]? =
            some { kind := .inp sharing share, inputs := [] } := by
      rw [prependedPorts, registeredComposite_prefix_gate up tail _ hportBound]
      exact hport
    apply List.all_eq_true.mpr
    intro gate hgateMem
    have hgate : gate <
        (registeredComposite up.g tail.ports).circuit.gates.size := by
      simpa using hgateMem
    cases hother :
        (registeredComposite up.g tail.ports).circuit.gates[gate]? with
    | none => simp [hcompositePort, hother]
    | some entry =>
        rcases entry with ⟨kind, inputs⟩
        cases kind with
        | inp otherSharing otherLane =>
            by_cases hsharing : sharing = otherSharing
            · subst otherSharing
              by_cases hlane : share = otherLane
              · subst otherLane
                have hgateEq := prependedPort_input_gate_unique up tail glue
                  share gate sharing inputs hshare hgate hport hother
                have hcompositePort' :
                    (registeredComposite up.g tail.ports).circuit.gates[
                      up.ports.inputGate share]? =
                        some { kind := .inp sharing share, inputs := [] } := by
                  simpa [prependedPorts] using hcompositePort
                simp [hgateEq, hcompositePort', prependedPorts]
              · simp [hcompositePort, hother, hlane]
            · simp [hcompositePort, hother, hsharing]
        | _ => simp [hcompositePort, hother]
  · unfold SourceDomainsDisjoint
    apply List.all_eq_true.mpr
    intro src hsrc
    rw [prependedPorts_portInputAtoms up tail,
      prependedPorts_connectedArrivalAtoms up tail, List.mem_filter] at hsrc
    have hnot := prependedPort_off_not_composite_domain up tail glue src
      hsrc.1 (by simpa [List.contains_iff_mem] using hsrc.2)
    simpa [List.contains_iff_mem] using hnot

private theorem upstream_arrivalValue_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (src : Src)
    (hrelevant : src ∈
      Execution.relevantSrcs up.g.circuit up.g.horizon) :
    arrivalValue? (registeredComposite up.g tail.ports) x src =
      arrivalValue? up.g (pipelineUpInput up tail x) src := by
  by_cases hinterface : src ∈ interfaceAtoms up.g
  · rw [interfaceAtoms, List.mem_flatMap] at hinterface
    rcases hinterface with ⟨input, hinputMem, hshareMem⟩
    rw [List.mem_map] at hshareMem
    rcases hshareMem with ⟨share, hshareMem, heq⟩
    have hinput : input < up.g.inputCount := by simpa using hinputMem
    have hshare : share < up.g.d := by simpa using hshareMem
    subst src
    have htailInput : tail.ports.downstreamInput < tail.g.inputCount :=
      tail.ports.input_bound
    have hleft := arrivalValue_input_of_injective
      (registeredComposite up.g tail.ports)
      (registeredComposite_interfaceInjective up tail glue) x input share
      (by simp only [registeredComposite]
          omega)
      (by simpa [registeredComposite, up.d_eq, tail.d_eq] using hshare)
    have hright := arrivalValue_input_of_injective up.g
      up.interface_injective (pipelineUpInput up tail x) input share
      hinput hshare
    rw [pipelineUpInput_bit up tail x input share hinput hshare] at hright
    simpa [registeredComposite, hinput] using hleft.trans hright.symm
  · have hnotComposite := upstream_relevant_not_composite_interface
      up tail glue src hrelevant hinterface
    rw [arrivalValue_none_of_not_mem_interface up.g
      (pipelineUpInput up tail x) src hinterface]
    exact arrivalValue_none_of_not_mem_interface
      (registeredComposite up.g tail.ports) x src hnotComposite

private theorem survivingTail_arrivalValue_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (upEnv : Env) (src : Src)
    (hrelevant : src ∈
      Execution.relevantSrcs tail.g.circuit tail.g.horizon)
    (hsurvives : src ∉ portInputAtoms tail.ports) :
    arrivalValue? (registeredComposite up.g tail.ports) x
        (shiftDownSrc up.g tail.g src) =
      arrivalValue? tail.g (pipelineTailInput up tail x upEnv) src := by
  by_cases hinterface : src ∈ interfaceAtoms tail.g
  · rw [interfaceAtoms, List.mem_flatMap] at hinterface
    rcases hinterface with ⟨input, hinputMem, hshareMem⟩
    rw [List.mem_map] at hshareMem
    rcases hshareMem with ⟨share, hshareMem, heq⟩
    have hinput : input < tail.g.inputCount := by simpa using hinputMem
    have hshare : share < tail.g.d := by simpa using hshareMem
    subst src
    have hne : input ≠ tail.ports.downstreamInput := by
      intro heqInput
      subst input
      obtain ⟨sharing, hgate, harrival⟩ :=
        tail.ports.input_source_coherent share hshare
      apply hsurvives
      rw [portInputAtoms, List.mem_flatMap]
      refine ⟨share, by simpa using hshare, ?_⟩
      rw [hgate]
      exact List.mem_map.mpr ⟨tail.ports.arrivalCycle,
        by simpa [tail.horizon_eq] using tail.arrival_inside,
        harrival.symm⟩
    have hhidden := tail.ports.input_bound
    have hhiddenIndex := hideRegisteredInput_lt
      tail.ports.downstreamInput input tail.g.inputCount
      hhidden hinput hne
    have hcompositeInput :
        up.g.inputCount +
            hideRegisteredInput tail.ports.downstreamInput input <
          (registeredComposite up.g tail.ports).inputCount := by
      simp only [registeredComposite]
      omega
    have hcompositeShare : share <
        (registeredComposite up.g tail.ports).d := by
      simpa [registeredComposite, up.d_eq, tail.d_eq] using hshare
    have harrivalComposite :
        (registeredComposite up.g tail.ports).inputArrival
            (up.g.inputCount +
              hideRegisteredInput tail.ports.downstreamInput input) share =
          shiftDownSrc up.g tail.g (tail.g.inputArrival input share) := by
      have hnotUp : ¬ up.g.inputCount +
          hideRegisteredInput tail.ports.downstreamInput input <
            up.g.inputCount := by omega
      simp [registeredComposite, hnotUp,
        unhide_hideRegisteredInput _ _ _ hhidden hinput hne]
    have hleft := arrivalValue_input_of_injective
      (registeredComposite up.g tail.ports)
      (registeredComposite_interfaceInjective up tail glue) x
      (up.g.inputCount +
        hideRegisteredInput tail.ports.downstreamInput input) share
      hcompositeInput hcompositeShare
    have hright := arrivalValue_input_of_injective tail.g
      tail.interface_injective (pipelineTailInput up tail x upEnv)
      input share hinput hshare
    rw [pipelineTailInput_bit up tail x upEnv input share
      hinput hshare, if_neg hne] at hright
    rw [harrivalComposite] at hleft
    exact hleft.trans hright.symm
  · have hnotComposite := shifted_tail_relevant_not_composite_interface
      up tail glue src hrelevant hinterface
    rw [arrivalValue_none_of_not_mem_interface tail.g
      (pipelineTailInput up tail x upEnv) src hinterface]
    exact arrivalValue_none_of_not_mem_interface
      (registeredComposite up.g tail.ports) x
      (shiftDownSrc up.g tail.g src) hnotComposite

private theorem upstream_fixingCell_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (src : Src)
    (hrelevant : src ∈
      Execution.relevantSrcs up.g.circuit up.g.horizon) :
    fixingCell (registeredComposite up.g tail.ports) x src =
      fixingCell up.g (pipelineUpInput up tail x) src := by
  have harrival := upstream_arrivalValue_eq up tail glue x src hrelevant
  cases hupArrival : arrivalValue? up.g (pipelineUpInput up tail x) src with
  | some value => simp [fixingCell, hupArrival, harrival]
  | none =>
      have hcompArrival :
          arrivalValue? (registeredComposite up.g tail.ports) x src = none := by
        rw [harrival, hupArrival]
      cases hupPublic : Execution.lookupAssoc src up.g.publicFixing with
      | some value =>
          have hcompPublic : Execution.lookupAssoc src
              (registeredComposite up.g tail.ports).publicFixing = some value := by
            simpa [registeredComposite, List.append_assoc] using
              lookupAssoc_append_of_some src up.g.publicFixing
                (tail.g.publicFixing.map (fun entry =>
                    (shiftDownSrc up.g tail.g entry.1, entry.2)) ++
                  (List.range tail.g.d).map (fun share =>
                    (.iniReg (boundaryRegister up.g share), false)))
                value hupPublic
          simp [fixingCell, hupArrival, hcompArrival, hupPublic, hcompPublic]
      | none =>
          have hnotPublic : src ∉ publicAtoms up.g := by
            intro hpublic
            obtain ⟨value, hsome⟩ :=
              Execution.lookupAssoc_some_of_mem_key src up.g.publicFixing
                hpublic
            rw [hupPublic] at hsome
            contradiction
          have hnotCompPublic := upstream_relevant_not_composite_public
            up tail glue src hrelevant hnotPublic
          have hcompPublic : Execution.lookupAssoc src
              (registeredComposite up.g tail.ports).publicFixing = none :=
            Execution.lookupAssoc_none_of_not_mem _ _ hnotCompPublic
          by_cases hrandom : src ∈ up.g.randomness
          · have hcompRandom : src ∈
                (registeredComposite up.g tail.ports).randomness := by
              simp [registeredComposite, hrandom]
            simp [fixingCell, hupArrival, hcompArrival, hupPublic, hcompPublic,
              List.contains_iff_mem, hrandom, hcompRandom]
          · have hnotCompRandom := upstream_relevant_not_composite_random
              up tail glue src hrelevant hrandom
            simp [fixingCell, hupArrival, hcompArrival, hupPublic, hcompPublic,
              List.contains_iff_mem, hrandom, hnotCompRandom]

private theorem survivingTail_fixingCell_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (upEnv : Env) (src : Src)
    (hrelevant : src ∈
      Execution.relevantSrcs tail.g.circuit tail.g.horizon)
    (hsurvives : src ∉ portInputAtoms tail.ports) :
    fixingCell (registeredComposite up.g tail.ports) x
        (shiftDownSrc up.g tail.g src) =
      fixingCell tail.g (pipelineTailInput up tail x upEnv) src := by
  have harrival := survivingTail_arrivalValue_eq up tail glue x upEnv src
    hrelevant hsurvives
  cases htailArrival : arrivalValue? tail.g
      (pipelineTailInput up tail x upEnv) src with
  | some value => simp [fixingCell, htailArrival, harrival]
  | none =>
      have hcompArrival : arrivalValue?
          (registeredComposite up.g tail.ports) x
            (shiftDownSrc up.g tail.g src) = none := by
        rw [harrival, htailArrival]
      cases htailPublic : Execution.lookupAssoc src tail.g.publicFixing with
      | some value =>
          have hpublic : src ∈ publicAtoms tail.g :=
            List.mem_map.mpr ⟨(src, value),
              Execution.lookupAssoc_some_mem src tail.g.publicFixing value
                htailPublic, rfl⟩
          have hnotUp : Execution.lookupAssoc
              (shiftDownSrc up.g tail.g src) up.g.publicFixing = none := by
            apply Execution.lookupAssoc_none_of_not_mem
            intro hmem
            have hupPublic : shiftDownSrc up.g tail.g src ∈ publicAtoms up.g :=
              hmem
            exact relevant_shiftDownSrc_fresh up tail glue _ src
              (pipeline_public_relevant up _ hupPublic)
              (pipeline_public_relevant tail src hpublic) rfl
          have hshifted : Execution.lookupAssoc
              (shiftDownSrc up.g tail.g src)
              (tail.g.publicFixing.map fun entry =>
                (shiftDownSrc up.g tail.g entry.1, entry.2)) = some value :=
            lookupAssoc_map_key_of_injective (shiftDownSrc up.g tail.g)
              (shiftDownSrc_injective up.g tail.g) src tail.g.publicFixing
              value htailPublic
          have hcompPublic : Execution.lookupAssoc
              (shiftDownSrc up.g tail.g src)
              (registeredComposite up.g tail.ports).publicFixing =
                some value := by
            rw [show (registeredComposite up.g tail.ports).publicFixing =
                (up.g.publicFixing ++ tail.g.publicFixing.map (fun entry =>
                  (shiftDownSrc up.g tail.g entry.1, entry.2))) ++
                  (List.range tail.g.d).map (fun share =>
                    (.iniReg (boundaryRegister up.g share), false)) by rfl]
            rw [lookupAssoc_append_of_some]
            rw [lookupAssoc_append_of_none _ _ _ hnotUp]
            exact hshifted
          simp [fixingCell, htailArrival, hcompArrival, htailPublic,
            hcompPublic]
      | none =>
          have hnotPublic : src ∉ publicAtoms tail.g := by
            intro hpublic
            obtain ⟨value, hsome⟩ :=
              Execution.lookupAssoc_some_of_mem_key src tail.g.publicFixing
                hpublic
            rw [htailPublic] at hsome
            contradiction
          have hnotCompPublic := shifted_tail_relevant_not_composite_public
            up tail glue src hrelevant hnotPublic
          have hcompPublic : Execution.lookupAssoc
              (shiftDownSrc up.g tail.g src)
              (registeredComposite up.g tail.ports).publicFixing = none :=
            Execution.lookupAssoc_none_of_not_mem _ _ hnotCompPublic
          by_cases hrandom : src ∈ tail.g.randomness
          · have hcompRandom : shiftDownSrc up.g tail.g src ∈
                (registeredComposite up.g tail.ports).randomness := by
              simp only [registeredComposite, List.mem_append, List.mem_map]
              exact Or.inr ⟨src, hrandom, rfl⟩
            simp [fixingCell, htailArrival, hcompArrival, htailPublic,
              hcompPublic, List.contains_iff_mem, hrandom, hcompRandom]
          · have hnotCompRandom := shifted_tail_relevant_not_composite_random
              up tail glue src hrelevant hrandom
            simp [fixingCell, htailArrival, hcompArrival, htailPublic,
              hcompPublic, List.contains_iff_mem, hrandom, hnotCompRandom]

/-- `fixingCell` is the position-aligned pattern used by the executable
environment enumeration.  Keeping this spelling explicit avoids carrying
association-list lookups through the E5 product calculation. -/
private theorem envsForInput_eq_cellAssignments (g : GadgetInstance)
    (x : List Bool) :
    envsForInput g x =
      (Execution.assignmentsPattern
        (Execution.relevantSrcs g.circuit g.horizon)
        ((Execution.relevantSrcs g.circuit g.horizon).map
          (fixingCell g x))).map Execution.envFrom := by
  rw [envsForInput_eq_assignmentsPattern]
  congr 2
  apply List.map_congr_left
  intro src hsrc
  rw [fixingForInput_lookup_cell]
  simp [hsrc]

private theorem boundary_fixingCell_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (share : Nat) (hshare : share < d) :
    fixingCell (registeredComposite up.g tail.ports) x
        (.iniReg (boundaryRegister up.g share)) = some false := by
  have hshareTail : share < tail.g.d := by simpa [tail.d_eq] using hshare
  have hnotInterface := boundaryInit_not_composite_interface up tail glue
    share hshareTail
  have harrival := arrivalValue_none_of_not_mem_interface
    (registeredComposite up.g tail.ports) x
    (.iniReg (boundaryRegister up.g share)) hnotInterface
  have hlookup := (boundary_initPinned_transport up tail glue share hshareTail).2
  simp [fixingCell, harrival, hlookup]

private theorem upstream_fixingPattern_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) :
    (Execution.relevantSrcs up.g.circuit up.g.horizon).map
        (fixingCell (registeredComposite up.g tail.ports) x) =
      (Execution.relevantSrcs up.g.circuit up.g.horizon).map
        (fixingCell up.g (pipelineUpInput up tail x)) := by
  apply List.map_congr_left
  intro src hsrc
  exact upstream_fixingCell_eq up tail glue x src hsrc

private theorem boundary_fixingPattern_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) :
    ((List.range d).map fun share =>
        (.iniReg (boundaryRegister up.g share) : Src)).map
          (fixingCell (registeredComposite up.g tail.ports) x) =
      (List.range d).map fun _ => some false := by
  simp only [List.map_map, Function.comp_apply]
  apply List.map_congr_left
  intro share hshare
  exact boundary_fixingCell_eq up tail glue x share (by simpa using hshare)

private theorem survivingTail_fixingPattern_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (upEnv : Env) :
    (shiftedSurvivingTailSrcs up.g tail.g tail.ports).map
        (fixingCell (registeredComposite up.g tail.ports) x) =
      ((Execution.relevantSrcs tail.g.circuit tail.g.horizon).filter fun src =>
        !(portInputAtoms tail.ports).contains src).map
          (fixingCell tail.g (pipelineTailInput up tail x upEnv)) := by
  unfold shiftedSurvivingTailSrcs
  rw [List.map_map]
  apply List.map_congr_left
  intro src hsrc
  have hsrc' := List.mem_filter.mp hsrc
  exact survivingTail_fixingCell_eq up tail glue x upEnv src hsrc'.1
    (by simpa [List.contains_iff_mem] using hsrc'.2)

private theorem flatMap_cons_map_perm (ys : List β) (a : β → γ)
    (g : β → List γ) :
    (ys.flatMap fun y => a y :: g y).Perm
      (ys.map a ++ ys.flatMap g) := by
  induction ys with
  | nil => simp
  | cons y ys ih =>
      simp only [List.flatMap_cons, List.map_cons, List.cons_append]
      apply List.Perm.cons
      apply List.Perm.trans (List.Perm.append_left (g y) ih)
      have hswap := (List.perm_append_comm :
        ((g y) ++ (ys.map a)).Perm ((ys.map a) ++ (g y)))
      simpa [List.append_assoc] using hswap.append_right (ys.flatMap g)

private theorem flatMap_map_product_perm (xs : List α) (ys : List β)
    (f : α → β → γ) :
    (ys.flatMap fun y => xs.map fun x => f x y).Perm
      (xs.flatMap fun x => ys.map fun y => f x y) := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
      apply List.Perm.trans
        (flatMap_cons_map_perm ys (fun y => f x y)
          (fun y => xs.map fun z => f z y))
      simpa [List.flatMap_cons] using
        (List.Perm.append (List.Perm.refl (ys.map fun y => f x y)) ih)

private theorem tailAssignments_filter_port {H d t : Nat}
    (up tail : PipelineGadget H d t) (x : List Bool) (upEnv : Env) :
    (Execution.assignmentsPattern
      (Execution.relevantSrcs tail.g.circuit tail.g.horizon)
      ((Execution.relevantSrcs tail.g.circuit tail.g.horizon).map
        (fixingCell tail.g (pipelineTailInput up tail x upEnv)))).map
        (fun values => values.filter fun entry =>
          !(portInputAtoms tail.ports).contains entry.1) =
      Execution.assignmentsPattern
        ((Execution.relevantSrcs tail.g.circuit tail.g.horizon).filter fun src =>
          !(portInputAtoms tail.ports).contains src)
        (((Execution.relevantSrcs tail.g.circuit tail.g.horizon).filter fun src =>
          !(portInputAtoms tail.ports).contains src).map
            (fixingCell tail.g (pipelineTailInput up tail x upEnv))) := by
  let sources := Execution.relevantSrcs tail.g.circuit tail.g.horizon
  let expected := fixingCell tail.g (pipelineTailInput up tail x upEnv)
  let keep : Src → Bool := fun src =>
    !(portInputAtoms tail.ports).contains src
  have hremoved : ∀ src ∈ sources, keep src = false →
      (expected src).isSome = true := by
    intro src hsrc hkeep
    have hport : src ∈ portInputAtoms tail.ports := by
      have hcontains : (portInputAtoms tail.ports).contains src = true := by
        dsimp [keep] at hkeep
        cases h : (portInputAtoms tail.ports).contains src <;> simp_all
      simpa [List.contains_iff_mem] using hcontains
    have hsome := portSource_fixing_lookup_isSome tail
      (pipelineTailInput up tail x upEnv) src hsrc hport
    rw [fixingForInput_lookup_cell, if_pos hsrc] at hsome
    exact hsome
  exact assignmentsPattern_filter_fixed sources expected keep hremoved

private theorem shiftedTail_assignments_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (upEnv : Env) :
    Execution.assignmentsPattern
        (shiftedSurvivingTailSrcs up.g tail.g tail.ports)
        ((shiftedSurvivingTailSrcs up.g tail.g tail.ports).map
          (fixingCell (registeredComposite up.g tail.ports) x)) =
      (Execution.assignmentsPattern
        (Execution.relevantSrcs tail.g.circuit tail.g.horizon)
        ((Execution.relevantSrcs tail.g.circuit tail.g.horizon).map
          (fixingCell tail.g (pipelineTailInput up tail x upEnv)))).map
        (fun values =>
          (values.filter fun entry =>
            !(portInputAtoms tail.ports).contains entry.1).map fun entry =>
              (shiftDownSrc up.g tail.g entry.1, entry.2)) := by
  let surviving :=
    (Execution.relevantSrcs tail.g.circuit tail.g.horizon).filter fun src =>
      !(portInputAtoms tail.ports).contains src
  have hpattern := survivingTail_fixingPattern_eq up tail glue x upEnv
  change Execution.assignmentsPattern
      (surviving.map (shiftDownSrc up.g tail.g)) _ = _
  rw [hpattern]
  rw [assignmentsPattern_map_keys (shiftDownSrc up.g tail.g) surviving
    (surviving.map (fixingCell tail.g (pipelineTailInput up tail x upEnv)))
    (by simp)]
  rw [← tailAssignments_filter_port up tail x upEnv]
  simp [List.map_map, Function.comp_def]

private def boundaryAssignment (up : GadgetInstance) (d : Nat) :
    List (Src × Bool) :=
  (List.range d).map fun share =>
    (.iniReg (boundaryRegister up share), false)

private def shiftedTailAssignment (up tail : GadgetInstance)
    (ports : RegisterPorts tail) (values : List (Src × Bool)) :
    List (Src × Bool) :=
  (values.filter fun entry =>
    !(portInputAtoms ports).contains entry.1).map fun entry =>
      (shiftDownSrc up tail entry.1, entry.2)

/-- E5 exact assignment product.  The composite enumerator is a cartesian
product of the upstream assignment pattern and the isolated tail pattern;
the inserted register initialization is the unique all-false assignment and
the tail coordinates removed by wiring are fixed before being discarded. -/
theorem experiment_product_raw {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) :
    (envsForInput (registeredComposite up.g tail.ports) x).Perm
      ((Execution.assignmentsPattern
        (Execution.relevantSrcs up.g.circuit up.g.horizon)
        ((Execution.relevantSrcs up.g.circuit up.g.horizon).map
          (fixingCell up.g (pipelineUpInput up tail x)))).flatMap fun upValues =>
        (Execution.assignmentsPattern
          (Execution.relevantSrcs tail.g.circuit tail.g.horizon)
          ((Execution.relevantSrcs tail.g.circuit tail.g.horizon).map
            (fixingCell tail.g
              (pipelineTailInput up tail x
                (Execution.envFrom upValues))))).map fun tailValues =>
          Execution.envFrom
            (upValues ++ boundaryAssignment up.g d ++
              shiftedTailAssignment up.g tail.g tail.ports tailValues)) := by
  let upSources := Execution.relevantSrcs up.g.circuit up.g.horizon
  let boundarySources := (List.range d).map fun share =>
    (.iniReg (boundaryRegister up.g share) : Src)
  let tailSources := shiftedSurvivingTailSrcs up.g tail.g tail.ports
  let composite := registeredComposite up.g tail.ports
  rw [envsForInput_eq_cellAssignments]
  rw [registeredComposite_relevantSrcs_concat up tail glue]
  simp only [List.map_append]
  rw [assignmentsPattern_append (upSources ++ boundarySources) tailSources
    ((upSources.map (fixingCell composite x)) ++
      (boundarySources.map (fixingCell composite x)))
    (tailSources.map (fixingCell composite x)) (by simp)]
  rw [assignmentsPattern_append upSources boundarySources
    (upSources.map (fixingCell composite x))
    (boundarySources.map (fixingCell composite x)) (by simp)]
  rw [upstream_fixingPattern_eq up tail glue x]
  rw [boundary_fixingPattern_eq up tail glue x]
  have hboundaryPattern :
      (List.range d).map (fun _ => some false) =
        boundarySources.map (fun _ => some false) := by
    simp [boundarySources]
  rw [hboundaryPattern]
  rw [assignmentsPattern_all_fixed boundarySources (fun _ => false)]
  have hboundaryAssignment :
      (boundarySources.map fun src => (src, false)) =
        boundaryAssignment up.g d := by
    simp [boundarySources, boundaryAssignment, List.map_map,
      Function.comp_def]
  rw [hboundaryAssignment]
  simp only [List.flatMap_singleton, List.map_map, Function.comp_apply,
    List.map_flatMap]
  simp only [Function.comp_def]
  dsimp only [upSources]
  have hswap := flatMap_map_product_perm
    (Execution.assignmentsPattern
      (Execution.relevantSrcs up.g.circuit up.g.horizon)
      ((Execution.relevantSrcs up.g.circuit up.g.horizon).map
        (fixingCell up.g (pipelineUpInput up tail x))))
    (Execution.assignmentsPattern tailSources
      (tailSources.map (fixingCell composite x)))
    (fun upValues tailValues => Execution.envFrom
      (upValues ++ boundaryAssignment up.g d ++ tailValues))
  apply hswap.trans
  apply flatMap_perm_of_pointwise
  intro upValues hupValues
  rw [shiftedTail_assignments_eq up tail glue x
    (Execution.envFrom upValues)]
  simp [shiftedTailAssignment, List.map_map, Function.comp_def]

private theorem assignmentsPattern_keys (sources : List Src)
    (expected : Src → Option Bool) (values : List (Src × Bool))
    (hvalues : values ∈ Execution.assignmentsPattern sources
      (sources.map expected)) :
    values.map Prod.fst = sources := by
  induction sources generalizing values with
  | nil =>
      simp [Execution.assignmentsPattern] at hvalues
      subst values
      rfl
  | cons src sources ih =>
      simp only [List.map_cons, Execution.assignmentsPattern] at hvalues
      cases hexpected : expected src with
      | some bit =>
          rw [hexpected, List.mem_map] at hvalues
          rcases hvalues with ⟨tailValues, htailValues, rfl⟩
          simp [ih tailValues htailValues]
      | none =>
          rw [hexpected, List.mem_flatMap] at hvalues
          rcases hvalues with ⟨tailValues, htailValues, hchoice⟩
          simp at hchoice
          rcases hchoice with rfl | rfl <;>
            simp [ih tailValues htailValues]

private theorem envFrom_append_left_eq (values rest : List (Src × Bool))
    (src : Src) (hsrc : src ∈ values.map Prod.fst) :
    Execution.envFrom (values ++ rest) src = Execution.envFrom values src := by
  obtain ⟨value, hlookup⟩ :=
    Execution.lookupAssoc_some_of_mem_key src values hsrc
  simp [Execution.envFrom,
    lookupAssoc_append_of_some src values rest value hlookup, hlookup]

private theorem restrictEnv_product_up_eq {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (upValues tailValues : List (Src × Bool))
    (hkeys : upValues.map Prod.fst =
      Execution.relevantSrcs up.g.circuit up.g.horizon) :
    restrictEnv (Execution.relevantSrcs up.g.circuit up.g.horizon)
        (Execution.envFrom
          (upValues ++ boundaryAssignment up.g d ++
            shiftedTailAssignment up.g tail.g tail.ports tailValues)) =
      Execution.envFrom upValues := by
  funext src
  by_cases hsrc : src ∈
      Execution.relevantSrcs up.g.circuit up.g.horizon
  · have hsrcValues : src ∈ upValues.map Prod.fst := by simpa [hkeys] using hsrc
    simp [restrictEnv, hsrc,
      envFrom_append_left_eq upValues
        (boundaryAssignment up.g d ++
          shiftedTailAssignment up.g tail.g tail.ports tailValues)
        src hsrcValues]
  · have hsrcValues : src ∉ upValues.map Prod.fst := by simpa [hkeys] using hsrc
    have hlookup := Execution.lookupAssoc_none_of_not_mem src upValues hsrcValues
    simp [restrictEnv, hsrc, Execution.envFrom, hlookup]

private theorem assignmentEnv_mem (g : GadgetInstance) (x : List Bool)
    (values : List (Src × Bool))
    (hvalues : values ∈ Execution.assignmentsPattern
      (Execution.relevantSrcs g.circuit g.horizon)
      ((Execution.relevantSrcs g.circuit g.horizon).map
        (fixingCell g x))) :
    Execution.envFrom values ∈ envsForInput g x := by
  rw [envsForInput_eq_cellAssignments]
  exact List.mem_map.mpr ⟨values, hvalues, rfl⟩

private theorem productEnv_mem {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (upValues tailValues : List (Src × Bool))
    (hupValues : upValues ∈ Execution.assignmentsPattern
      (Execution.relevantSrcs up.g.circuit up.g.horizon)
      ((Execution.relevantSrcs up.g.circuit up.g.horizon).map
        (fixingCell up.g (pipelineUpInput up tail x))))
    (htailValues : tailValues ∈ Execution.assignmentsPattern
      (Execution.relevantSrcs tail.g.circuit tail.g.horizon)
      ((Execution.relevantSrcs tail.g.circuit tail.g.horizon).map
        (fixingCell tail.g
          (pipelineTailInput up tail x (Execution.envFrom upValues))))) :
    Execution.envFrom
        (upValues ++ boundaryAssignment up.g d ++
          shiftedTailAssignment up.g tail.g tail.ports tailValues) ∈
      envsForInput (registeredComposite up.g tail.ports) x := by
  have hright : Execution.envFrom
      (upValues ++ boundaryAssignment up.g d ++
        shiftedTailAssignment up.g tail.g tail.ports tailValues) ∈
      ((Execution.assignmentsPattern
        (Execution.relevantSrcs up.g.circuit up.g.horizon)
        ((Execution.relevantSrcs up.g.circuit up.g.horizon).map
          (fixingCell up.g (pipelineUpInput up tail x)))).flatMap fun upValues =>
        (Execution.assignmentsPattern
          (Execution.relevantSrcs tail.g.circuit tail.g.horizon)
          ((Execution.relevantSrcs tail.g.circuit tail.g.horizon).map
            (fixingCell tail.g
              (pipelineTailInput up tail x
                (Execution.envFrom upValues))))).map fun tailValues =>
          Execution.envFrom
            (upValues ++ boundaryAssignment up.g d ++
              shiftedTailAssignment up.g tail.g tail.ports tailValues)) := by
    exact List.mem_flatMap.mpr ⟨upValues, hupValues,
      List.mem_map.mpr ⟨tailValues, htailValues, rfl⟩⟩
  exact (experiment_product_raw up tail glue x).mem_iff.mpr hright

private theorem lookupAssoc_filter_key (values : List (Src × Bool))
    (keep : Src → Bool) (src : Src) (hkeep : keep src = true) :
    Execution.lookupAssoc src (values.filter fun entry => keep entry.1) =
      Execution.lookupAssoc src values := by
  induction values with
  | nil => rfl
  | cons entry values ih =>
      rcases entry with ⟨key, value⟩
      by_cases heq : src = key
      · subst key
        simp [Execution.lookupAssoc, hkeep]
      · cases hkey : keep key <;>
          simp [Execution.lookupAssoc, heq, ih, hkey]

private theorem productEnv_shifted_eq {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (upValues tailValues : List (Src × Bool))
    (hupKeys : upValues.map Prod.fst =
      Execution.relevantSrcs up.g.circuit up.g.horizon)
    (htailKeys : tailValues.map Prod.fst =
      Execution.relevantSrcs tail.g.circuit tail.g.horizon)
    (src : Src)
    (hrelevant : src ∈
      Execution.relevantSrcs tail.g.circuit tail.g.horizon)
    (hsurvives : src ∉ portInputAtoms tail.ports) :
    Execution.envFrom
        (upValues ++ boundaryAssignment up.g d ++
          shiftedTailAssignment up.g tail.g tail.ports tailValues)
        (shiftDownSrc up.g tail.g src) =
      Execution.envFrom tailValues src := by
  obtain ⟨value, htailLookup⟩ :=
    Execution.lookupAssoc_some_of_mem_key src tailValues (by
      simpa [htailKeys] using hrelevant)
  have hkeep : (!(portInputAtoms tail.ports).contains src) = true := by
    simpa [List.contains_iff_mem] using hsurvives
  have hfiltered : Execution.lookupAssoc src
      (tailValues.filter fun entry =>
        !(portInputAtoms tail.ports).contains entry.1) = some value := by
    rw [lookupAssoc_filter_key tailValues
      (fun atom => !(portInputAtoms tail.ports).contains atom) src hkeep]
    exact htailLookup
  have hshifted : Execution.lookupAssoc (shiftDownSrc up.g tail.g src)
      (shiftedTailAssignment up.g tail.g tail.ports tailValues) =
        some value := by
    unfold shiftedTailAssignment
    exact lookupAssoc_map_key_of_injective (shiftDownSrc up.g tail.g)
      (shiftDownSrc_injective up.g tail.g) src _ value hfiltered
  have hnotUp : shiftDownSrc up.g tail.g src ∉ upValues.map Prod.fst := by
    rw [hupKeys]
    intro hup
    exact relevant_shiftDownSrc_fresh up tail glue _ src hup hrelevant rfl
  have hupNone := Execution.lookupAssoc_none_of_not_mem
    (shiftDownSrc up.g tail.g src) upValues hnotUp
  have hnotBoundary : shiftDownSrc up.g tail.g src ∉
      (boundaryAssignment up.g d).map Prod.fst := by
    intro hboundary
    apply shifted_tail_relevant_not_boundaryInit up tail src
    simpa [boundaryAssignment, List.map_map, Function.comp_def, tail.d_eq]
      using hboundary
  have hboundaryNone := Execution.lookupAssoc_none_of_not_mem
    (shiftDownSrc up.g tail.g src) (boundaryAssignment up.g d) hnotBoundary
  rw [Execution.envFrom]
  rw [lookupAssoc_append_of_none _ _ _]
  · simp [hshifted, Execution.envFrom, htailLookup]
  · rw [lookupAssoc_append_of_none _ _ _ hupNone]
    exact hboundaryNone

private theorem pipeline_env_input_value {H d t : Nat}
    (P : PipelineGadget H d t) (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput P.g x)
    (input share : Nat) (hinput : input < P.g.inputCount)
    (hshare : share < P.g.d) :
    env (P.g.inputArrival input share) = inputBit P.g x input share := by
  have harrival := arrivalValue_input_of_injective P.g
    P.interface_injective x input share hinput hshare
  have hrelevant := pipeline_interface_relevant P
    (P.g.inputArrival input share) (by
      simp only [interfaceAtoms, List.mem_flatMap, List.mem_range, List.mem_map]
      exact ⟨input, hinput, share, hshare, rfl⟩)
  have hfixing : (P.g.inputArrival input share, inputBit P.g x input share) ∈
      fixingForInput P.g x := by
    unfold fixingForInput
    rw [List.mem_filterMap]
    exact ⟨P.g.inputArrival input share, hrelevant, by simp [harrival]⟩
  exact env_value_of_fixing_mem P.g.circuit P.g.horizon
    (fixingForInput P.g x) env _ _ henv hfixing

private theorem pipeline_env_port_default_false {H d t : Nat}
    (P : PipelineGadget H d t) (x : List Bool) (env : Env)
    (henv : env ∈ envsForInput P.g x) (src : Src)
    (hrelevant : src ∈ Execution.relevantSrcs P.g.circuit P.g.horizon)
    (hport : src ∈ portInputAtoms P.ports)
    (hnotInterface : src ∉ interfaceAtoms P.g) : env src = false := by
  have hnotRandom : src ∉ P.g.randomness := by
    intro hrandom
    exact pipeline_random_not_portInputAtoms P src hrandom hport
  have hnotPublic : src ∉ publicAtoms P.g := by
    intro hpublic
    exact pipeline_public_not_portInputAtoms P src hpublic hport
  have hlookup : Execution.lookupAssoc src P.g.publicFixing = none :=
    Execution.lookupAssoc_none_of_not_mem _ _ hnotPublic
  have harrival := arrivalValue_none_of_not_mem_interface P.g x src
    hnotInterface
  have hfixing : (src, false) ∈ fixingForInput P.g x := by
    unfold fixingForInput
    rw [List.mem_filterMap]
    exact ⟨src, hrelevant, by
      simp [harrival, hlookup, List.contains_iff_mem, hnotRandom]⟩
  exact env_value_of_fixing_mem P.g.circuit P.g.horizon
    (fixingForInput P.g x) env src false henv hfixing

set_option maxHeartbeats 1000000 in
private theorem substitutedTailEnv_product_agrees {H d t : Nat}
    (up tail : PipelineGadget H d t) (glue : PortGlue up tail)
    (x : List Bool) (upValues tailValues : List (Src × Bool))
    (hupValues : upValues ∈ Execution.assignmentsPattern
      (Execution.relevantSrcs up.g.circuit up.g.horizon)
      ((Execution.relevantSrcs up.g.circuit up.g.horizon).map
        (fixingCell up.g (pipelineUpInput up tail x))))
    (htailValues : tailValues ∈ Execution.assignmentsPattern
      (Execution.relevantSrcs tail.g.circuit tail.g.horizon)
      ((Execution.relevantSrcs tail.g.circuit tail.g.horizon).map
        (fixingCell tail.g
          (pipelineTailInput up tail x (Execution.envFrom upValues))))) :
    UniversalSStage1.EnvAgreeOn
      (Execution.relevantSrcs tail.g.circuit tail.g.horizon)
      (substitutedTailEnv up.g tail.g tail.ports
        (Execution.envFrom
          (upValues ++ boundaryAssignment up.g d ++
            shiftedTailAssignment up.g tail.g tail.ports tailValues)))
      (Execution.envFrom tailValues) := by
  let upEnv := Execution.envFrom upValues
  let tailInput := pipelineTailInput up tail x upEnv
  let tailEnv := Execution.envFrom tailValues
  let combined := Execution.envFrom
    (upValues ++ boundaryAssignment up.g d ++
      shiftedTailAssignment up.g tail.g tail.ports tailValues)
  have hupKeys := assignmentsPattern_keys _ _ upValues hupValues
  have htailKeys := assignmentsPattern_keys _ _ tailValues htailValues
  have hupEnv : upEnv ∈ envsForInput up.g (pipelineUpInput up tail x) :=
    assignmentEnv_mem up.g (pipelineUpInput up tail x) upValues hupValues
  have htailEnv : tailEnv ∈ envsForInput tail.g tailInput :=
    assignmentEnv_mem tail.g tailInput tailValues htailValues
  have hcombined : combined ∈
      envsForInput (registeredComposite up.g tail.ports) x :=
    productEnv_mem up tail glue x upValues tailValues hupValues htailValues
  have hrestrict : restrictEnv
      (Execution.relevantSrcs up.g.circuit up.g.horizon) combined = upEnv :=
    restrictEnv_product_up_eq up tail upValues tailValues hupKeys
  intro src hrelevant
  cases hconnected : connectedAtomShare? tail.ports src with
  | none =>
      have hsurvives : src ∉ portInputAtoms tail.ports := by
        intro hport
        rcases mem_portInputAtoms_cases tail src hport with
          ⟨share, hshare, sharing, cycle, _hcycle, hgate, hsrc⟩
        have hsome := connectedAtomShare?_of_port_stream tail share sharing
          cycle hshare hgate
        rw [hsrc] at hconnected
        rw [hsome] at hconnected
        contradiction
      have hvalue := productEnv_shifted_eq up tail glue upValues tailValues
        hupKeys htailKeys src hrelevant hsurvives
      cases src <;>
        simpa [substitutedTailEnv, hconnected, shiftDownSrc, combined, tailEnv]
          using hvalue
  | some boundaryShare =>
      cases src with
      | inp sharing lane cycle =>
          have hshareMem := List.mem_of_find?_eq_some hconnected
          have hshare : boundaryShare < tail.g.d := by
            simpa [connectedAtomShare?] using hshareMem
          obtain ⟨portSharing, hgate, harrival⟩ :=
            tail.ports.input_source_coherent boundaryShare hshare
          have hmatches := List.find?_some hconnected
          simp [connectedAtomShare?, hgate] at hmatches
          have hsharing : portSharing = sharing := hmatches.1
          have hlane : boundaryShare = lane := hmatches.2
          subst portSharing
          subst lane
          have hshareD : boundaryShare < d := by
            simpa [tail.d_eq] using hshare
          have hport : (.inp sharing boundaryShare cycle : Src) ∈
              portInputAtoms tail.ports := by
            rw [portInputAtoms, List.mem_flatMap]
            refine ⟨boundaryShare, by simpa using hshare, ?_⟩
            rw [hgate]
            exact List.mem_map.mpr ⟨cycle,
              (by simpa using (inp_mem_relevant_cycle_lt tail.g sharing
                boundaryShare cycle hrelevant)), rfl⟩
          by_cases hcycle : cycle = tail.ports.arrivalCycle
          · subst cycle
            have htailValue := pipeline_env_input_value tail tailInput tailEnv
              htailEnv tail.ports.downstreamInput boundaryShare
              tail.ports.input_bound hshare
            rw [pipelineTailInput_bit up tail x upEnv
              tail.ports.downstreamInput boundaryShare
              tail.ports.input_bound hshare, if_pos rfl] at htailValue
            rw [harrival] at htailValue
            simp only [substitutedTailEnv, hconnected]
            rw [eval_boundary_register up tail glue combined boundaryShare
              hshareD]
            rw [hrestrict]
            exact htailValue.symm
          · have hnotInterface : (.inp sharing boundaryShare cycle : Src) ∉
                interfaceAtoms tail.g := by
              intro hinterface
              have hconnectedArrival := portInputAtom_mem_connected_of_domain
                tail (.inp sharing boundaryShare cycle) hport
                  (by simp [hinterface])
              simp only [connectedArrivalAtoms, List.mem_map,
                List.mem_range] at hconnectedArrival
              rcases hconnectedArrival with ⟨otherShare, hotherShare, heq⟩
              obtain ⟨otherSharing, hotherGate, hotherArrival⟩ :=
                tail.ports.input_source_coherent otherShare hotherShare
              rw [hotherArrival] at heq
              simp at heq
              exact hcycle heq.2.2.symm
            have hleft := substitutedTailEnv_default_port_false up tail glue
              x combined hcombined (.inp sharing boundaryShare cycle)
              hport hnotInterface
            have hright := pipeline_env_port_default_false tail tailInput
              tailEnv htailEnv (.inp sharing boundaryShare cycle) hrelevant
              hport hnotInterface
            exact hleft.trans hright.symm
      | rnd id cycle => simp [connectedAtomShare?] at hconnected
      | ini id cycle => simp [connectedAtomShare?] at hconnected
      | ctl id cycle => simp [connectedAtomShare?] at hconnected
      | iniReg gate => simp [connectedAtomShare?] at hconnected

/-! ## E6: exact-sample form of the carried tail certificate -/

private theorem map_getD_idxOf_of_mem [BEq α] [LawfulBEq α]
    (xs : List α) (f : α → β) (value : α) (fallback : β)
    (hvalue : value ∈ xs) :
    (xs.map f).getD (xs.idxOf value) fallback = f value := by
  induction xs with
  | nil => simp at hvalue
  | cons head tail ih =>
      rcases List.mem_cons.mp hvalue with rfl | htail
      · simp
      · by_cases heq : head = value
        · subst head
          simp
        · rw [List.idxOf_cons]
          simp only [cond_eq_ite, beq_iff_eq, heq, if_false, List.map_cons]
          simpa [List.getD_eq_getElem?_getD] using ih htail

private def projectionBit (g : GadgetInstance) (shares : List Nat)
    (q : List Bool) (input share : Nat) : Bool :=
  q.getD (input * shares.length + shares.idxOf share) false

private theorem projectionBit_projection (g : GadgetInstance)
    (shares : List Nat) (x : List Bool) (input share : Nat)
    (hinput : input < g.inputCount) (hshare : share ∈ shares) :
    projectionBit g shares (projection g shares x) input share =
      inputBit g x input share := by
  have hidx : shares.idxOf share < shares.length :=
    List.idxOf_lt_length_of_mem hshare
  unfold projectionBit projection
  rw [← blockAt_getD shares.length
    ((List.range g.inputCount).flatMap fun sharing =>
      shares.map fun selected => inputBit g x sharing selected)
    input (shares.idxOf share) hidx]
  rw [blockAt_flatMap_range shares.length g.inputCount
    (fun sharing => shares.map fun selected =>
      inputBit g x sharing selected) (by simp) input hinput]
  simpa using map_getD_idxOf_of_mem shares
    (fun selected => inputBit g x input selected) share false hshare

private theorem inputBit_eq_of_projection_eq (g : GadgetInstance)
    (shares : List Nat) (x y : List Bool) (input share : Nat)
    (hinput : input < g.inputCount) (hshare : share ∈ shares)
    (hprojection : projection g shares x = projection g shares y) :
    inputBit g x input share = inputBit g y input share := by
  have h := congrArg
    (fun q => projectionBit g shares q input share) hprojection
  simpa [projectionBit_projection g shares x input share hinput hshare,
    projectionBit_projection g shares y input share hinput hshare] using h

private theorem projection_eq_of_bits (g : GadgetInstance)
    (shares : List Nat) (x y : List Bool)
    (hbits : ∀ input, input < g.inputCount → ∀ share ∈ shares,
      inputBit g x input share = inputBit g y input share) :
    projection g shares x = projection g shares y := by
  unfold projection
  apply congrArg List.flatten
  apply List.map_congr_left
  intro input hinput
  apply List.map_congr_left
  intro share hshare
  exact hbits input (by simpa using hinput) share hshare

/-- Equality of a larger projection determines every projection whose share
indices occur in it; no ordering or `Sublist` relation is required. -/
theorem projection_mono_eq (g : GadgetInstance)
    (small large : List Nat) (x y : List Bool)
    (hmem : ∀ share ∈ small, share ∈ large)
    (hlarge : projection g large x = projection g large y) :
    projection g small x = projection g small y := by
  apply projection_eq_of_bits
  intro input hinput share hshare
  exact inputBit_eq_of_projection_eq g large x y input share hinput
    (hmem share hshare) hlarge

/-- Exact dependent-bind assembly with a hidden first-stage state.  Concrete
second-stage experiments may depend on that hidden state.  They only need to
be permutation-equivalent whenever the public projection and emitted first
transcript agree. -/
theorem samplesSimulatableOn_hidden_bind
    {xs : List (List Bool)} {hidden : List Bool → List α}
    {firstObs : α → Observation}
    {secondSamples : List Bool → α → List Observation}
    {projection : List Bool → List Bool}
    (emit : Observation → Observation → Observation)
    [Inhabited α]
    (hsecond : ∀ x ∈ xs, ∀ state ∈ hidden x,
      ∀ y ∈ xs, ∀ other ∈ hidden y,
        projection x = projection y → firstObs state = firstObs other →
          (secondSamples x state).Perm (secondSamples y other))
    (hsecondNonempty : ∀ x ∈ xs, ∀ state ∈ hidden x,
      secondSamples x state ≠ [])
    (hfirst : SamplesSimulatableOn xs projection
      (fun x => (hidden x).map firstObs)) :
    SamplesSimulatableOn xs projection (fun x =>
      (hidden x).flatMap fun state =>
        (secondSamples x state).map (emit (firstObs state))) := by
  classical
  rcases hfirst with ⟨firstSimulator, hfirstPositive, hfirstPerm⟩
  let representative : List Bool → Observation → List Bool × α :=
    fun q first =>
      if h : ∃ x ∈ xs, ∃ state ∈ hidden x,
          projection x = q ∧ firstObs state = first then
        (Classical.choose h, Classical.choose (Classical.choose_spec h).2)
      else ([], default)
  have hrepresentative (x : List Bool) (hx : x ∈ xs)
      (state : α) (hstate : state ∈ hidden x) :
      let rep := representative (projection x) (firstObs state)
      rep.1 ∈ xs ∧ rep.2 ∈ hidden rep.1 ∧
        projection rep.1 = projection x ∧
        firstObs rep.2 = firstObs state := by
    dsimp only
    have hex : ∃ y ∈ xs, ∃ other ∈ hidden y,
        projection y = projection x ∧ firstObs other = firstObs state :=
      ⟨x, hx, state, hstate, rfl, rfl⟩
    simp only [representative, hex, dif_pos]
    have hchosen := Classical.choose_spec hex
    have hstateChosen := Classical.choose_spec hchosen.2
    exact ⟨hchosen.1, hstateChosen.1, hstateChosen.2.1,
      hstateChosen.2.2⟩
  let secondSimulator : List Bool → Observation → List Observation :=
    fun q first =>
      let rep := representative q first
      secondSamples rep.1 rep.2
  let simulator : List Bool → List Observation := fun q =>
    (firstSimulator q).flatMap fun first =>
      (secondSimulator q first).map (emit first)
  refine ⟨simulator, ?_, ?_⟩
  · intro x hx
    have hfirstNonempty : firstSimulator (projection x) ≠ [] :=
      List.ne_nil_of_length_pos (hfirstPositive x hx)
    rcases List.exists_mem_of_ne_nil _ hfirstNonempty with
      ⟨first, hfirst⟩
    have hconcreteFirst : first ∈ (hidden x).map firstObs :=
      (hfirstPerm x hx).mem_iff.mpr hfirst
    rcases List.mem_map.mp hconcreteFirst with ⟨state, hstate, rfl⟩
    have hrep := hrepresentative x hx state hstate
    have hnonempty := hsecondNonempty _ hrep.1 _ hrep.2.1
    rcases List.exists_mem_of_ne_nil _ hnonempty with ⟨second, hsecondMem⟩
    apply List.length_pos_of_mem
    exact List.mem_flatMap.mpr ⟨firstObs state, hfirst,
      List.mem_map.mpr ⟨second, hsecondMem, rfl⟩⟩
  · intro x hx
    have hpointwise :
        ((hidden x).flatMap fun state =>
          (secondSamples x state).map (emit (firstObs state))).Perm
        ((hidden x).flatMap fun state =>
          (secondSimulator (projection x) (firstObs state)).map
            (emit (firstObs state))) := by
      apply flatMap_perm_of_pointwise
      intro state hstate
      have hrep := hrepresentative x hx state hstate
      exact (hsecond x hx state hstate _ hrep.1 _ hrep.2.1
        hrep.2.2.1.symm hrep.2.2.2.symm).map (emit (firstObs state))
    apply hpointwise.trans
    have hfirstBind := (hfirstPerm x hx).flatMap_right fun first =>
      (secondSimulator (projection x) first).map (emit first)
    simpa [simulator, secondSimulator, List.flatMap_map,
      Function.comp_def] using hfirstBind

/-- Reindex an exact component experiment along an input embedding and expose
a larger public projection which determines the component projection. -/
theorem samplesSimulatableOn_reindex
    {sourceXs xs : List (List Bool)}
    {sourceProjection projection : List Bool → List Bool}
    {samples : List Bool → List Observation}
    (input : List Bool → List Bool)
    (hinput : ∀ x ∈ xs, input x ∈ sourceXs)
    (hdet : ∀ x ∈ xs, ∀ y ∈ xs,
      projection x = projection y →
        sourceProjection (input x) = sourceProjection (input y))
    (hsim : SamplesSimulatableOn sourceXs sourceProjection samples) :
    SamplesSimulatableOn xs projection (fun x => samples (input x)) := by
  classical
  rcases hsim with ⟨sourceSimulator, hpositive, hperm⟩
  let representative : List Bool → List Bool := fun q =>
    if h : ∃ x ∈ xs, projection x = q then Classical.choose h else []
  let simulator : List Bool → List Observation := fun q =>
    sourceSimulator (sourceProjection (input (representative q)))
  have hrep (x : List Bool) (hx : x ∈ xs) :
      representative (projection x) ∈ xs ∧
        projection (representative (projection x)) = projection x := by
    have hex : ∃ y ∈ xs, projection y = projection x := ⟨x, hx, rfl⟩
    exact ⟨by simp [representative, hex, Classical.choose_spec hex],
      by simp [representative, hex, Classical.choose_spec hex]⟩
  refine ⟨simulator, ?_, ?_⟩
  · intro x hx
    have hr := hrep x hx
    have hkey := hdet _ hr.1 x hx hr.2
    simpa [simulator, hkey] using hpositive (input x) (hinput x hx)
  · intro x hx
    have hr := hrep x hx
    have hkey := hdet _ hr.1 x hx hr.2
    simpa [simulator, hkey] using hperm (input x) (hinput x hx)

/-- The carried PINI certificate admits the same exact multiset interface as
`opiniSpec_to_samples`; unlike O-PINI it intentionally does not append the
witness output shares to the concrete transcript. -/
theorem pipelinePiniSpec_to_samples {H d t : Nat}
    (P : PipelineGadget H d t) :
    ∀ internal ∈ subsetsUpTo t (internalNodes P.g),
      ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range P.g.d),
        ∃ b ∈ subsetsUpTo internal.length (List.range P.g.d),
          SamplesSimulatableOn (boolVectors (inputWidth P.g))
            (projection P.g (outputs ++ b))
            (fun x => (envsForInput P.g x).map
              (observe P.g (expandedNodes P.g transitionGlitch
                (internal ++ outputs.map P.g.output)))) := by
  intro internal hinternal outputs houtputs
  obtain ⟨b, hb, hsim⟩ :=
    P.down_cert.2 internal hinternal outputs houtputs
  refine ⟨b, hb, simulatableOn_to_samples ?_ ?_ hsim⟩
  · intro x _hx
    exact List.ne_nil_iff_length_pos.mp
      (envsForInput_ne_nil_of_valid P.g x (fixingForInput_valid P.g x))
  · intro x _hx y _hy
    exact envsForInput_cardinality P.g x y

/-- E6 assembly: collapse a concrete environment experiment which factors as
a dependent upstream/tail bind.  The tail certificate is applied pointwise
by `hsecond`; exact permutation is then converted back to the audited
`SimulatableOn` normalization. -/
theorem bindEnv_collapse
    {xs : List (List Bool)} {envsOf : List Bool → List Env}
    {projI : List Bool → List Bool} {obs : Env → Observation}
    {firstSamples : List Bool → List Observation}
    (secondSamples secondSimulator :
      List Bool → Observation → List Observation)
    (emit : Observation → Observation → Observation)
    (hfactor : ∀ x ∈ xs,
      ((envsOf x).map obs).Perm
        (bindSamplesOn firstSamples secondSamples emit x))
    (hsecond : ∀ x ∈ xs, ∀ first,
      (secondSamples x first).Perm
        (secondSimulator (projI x) first))
    (hsecondNonempty : ∀ q first, secondSimulator q first ≠ [])
    (hfirst : SamplesSimulatableOn xs projI firstSamples) :
    SimulatableOn xs envsOf projI obs := by
  have hbind := samplesSimulatableOn_dependent_bind_congr
    secondSamples secondSimulator emit hsecond hsecondNonempty hfirst
  rcases hbind with ⟨simulator, hpositive, hperm⟩
  apply samplesSimulatableOn_to_simulatableOn
  refine ⟨simulator, hpositive, ?_⟩
  intro x hx
  exact (hfactor x hx).trans (hperm x hx)

/-- E6 budget stack.  First invoke the carried tail PINI certificate, then
invoke upstream O-PINI on the canonical union of every boundary share which
the tail simulation can inspect.  The nested `shareUnion_length_le` bounds
show that this backward step has no budget inflation. -/
theorem pipeline_probe_split_certificates {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : opiniSpec up.g transitionGlitch t)
    (upInternal tailInternal : List Node)
    (boundary outputs : List Nat)
    (hupInternal : upInternal.Sublist (internalNodes up.g))
    (htailInternal : tailInternal.Sublist (internalNodes tail.g))
    (hboundary : boundary.Sublist (List.range d))
    (houtputs : outputs.Sublist (List.range d))
    (hbudget : upInternal.length + tailInternal.length +
      boundary.length + outputs.length ≤ t) :
    ∃ tailB ∈ subsetsUpTo tailInternal.length (List.range tail.g.d),
      let propagated := propagatedShares up.g.d outputs tailB boundary
      ∃ upB ∈ subsetsUpTo upInternal.length (List.range up.g.d),
        SamplesSimulatableOn (boolVectors (inputWidth up.g))
          (projection up.g (propagated ++ upB))
          (fun x => (envsForInput up.g x).map
            (observe up.g
              ((expandedNodes up.g transitionGlitch
                (upInternal ++ propagated.map up.g.output)) ++
                  upB.map up.g.output).eraseDups)) ∧
        SamplesSimulatableOn (boolVectors (inputWidth tail.g))
          (projection tail.g (outputs ++ tailB))
          (fun x => (envsForInput tail.g x).map
            (observe tail.g (expandedNodes tail.g transitionGlitch
              (tailInternal ++ outputs.map tail.g.output)))) := by
  have hupInternalSet : upInternal ∈
      subsetsUpTo t (internalNodes up.g) :=
    mem_subsetsUpTo_of_sublist hupInternal (by omega)
  have htailInternalSet : tailInternal ∈
      subsetsUpTo t (internalNodes tail.g) :=
    mem_subsetsUpTo_of_sublist htailInternal (by omega)
  have houtputsTailSub : outputs.Sublist (List.range tail.g.d) := by
    simpa [tail.d_eq] using houtputs
  have houtputsTail : outputs ∈
      subsetsUpTo (t - tailInternal.length) (List.range tail.g.d) :=
    mem_subsetsUpTo_of_sublist houtputsTailSub (by omega)
  obtain ⟨tailB, htailB, htailSamples⟩ :=
    pipelinePiniSpec_to_samples tail tailInternal htailInternalSet
      outputs houtputsTail
  let propagated := propagatedShares up.g.d outputs tailB boundary
  have houtputsMem : ∀ share ∈ outputs, share < up.g.d := by
    intro share hshare
    have : share < d := by simpa using houtputs.mem hshare
    simpa [up.d_eq] using this
  have htailBMem : ∀ share ∈ tailB, share < up.g.d := by
    intro share hshare
    have htailRange := (subsetsUpTo_sublist _ _ _ htailB).mem hshare
    have : share < tail.g.d := by simpa using htailRange
    simpa [up.d_eq, tail.d_eq] using this
  have hboundaryMem : ∀ share ∈ boundary, share < up.g.d := by
    intro share hshare
    have : share < d := by simpa using hboundary.mem hshare
    simpa [up.d_eq] using this
  have hinnerLength := shareUnion_length_le up.g.d outputs tailB
    houtputsMem htailBMem
  have hinnerMem : ∀ share ∈ shareUnion up.g.d outputs tailB,
      share < up.g.d := by
    intro share hshare
    simpa using (shareUnion_sublist up.g.d outputs tailB).mem hshare
  have hpropLength := shareUnion_length_le up.g.d
    (shareUnion up.g.d outputs tailB) boundary hinnerMem hboundaryMem
  have htailBBound := subsetsUpTo_bound _ _ _ htailB
  have hpropBound : propagated.length ≤ t - upInternal.length := by
    dsimp [propagated, propagatedShares]
    omega
  have hpropSet : propagated ∈
      subsetsUpTo (t - upInternal.length) (List.range up.g.d) :=
    mem_subsetsUpTo_of_sublist
      (shareUnion_sublist up.g.d
        (shareUnion up.g.d outputs tailB) boundary) hpropBound
  obtain ⟨upB, hupB, hupSamples⟩ :=
    opiniSpec_to_samples up.g transitionGlitch t hup upInternal
      hupInternalSet propagated hpropSet
  exact ⟨tailB, htailB, upB, hupB, hupSamples, htailSamples⟩

set_option maxHeartbeats 4000000 in
/-- The closure crux: carried tail PINI and leaf O-PINI assemble into PINI
for the registered composite with no probe-budget inflation. -/
theorem compose_pini {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : opiniSpec up.g transitionGlitch t)
    (glue : PortGlue up tail) :
    piniSpec (registeredComposite up.g tail.ports) transitionGlitch t := by
  let composite := registeredComposite up.g tail.ports
  refine ⟨registeredComposite_wf up tail, ?_⟩
  intro internal hinternal outputs houtputs
  have hinternalSub : internal.Sublist (internalNodes composite) :=
    subsetsUpTo_sublist _ _ _ hinternal
  have houtputsSubComposite : outputs.Sublist (List.range composite.d) :=
    subsetsUpTo_sublist _ _ _ houtputs
  have houtputsSub : outputs.Sublist (List.range d) := by
    simpa [composite, registeredComposite, tail.d_eq] using
      houtputsSubComposite
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
  have hinternalBound := subsetsUpTo_bound _ _ _ hinternal
  have houtputsBound := subsetsUpTo_bound _ _ _ houtputs
  have hbudget : upInternal.length + tailInternal.length +
      boundary.length + outputs.length ≤ t := by
    dsimp [upInternal, tailInternal, boundary] at hpartition ⊢
    omega
  obtain ⟨tailB, htailB, upB, hupB, hupSamples, htailSamples⟩ :=
    pipeline_probe_split_certificates up tail hup upInternal tailInternal
      boundary outputs hupInternal htailInternal hboundary houtputsSub hbudget
  let demanded := propagatedShares d outputs tailB boundary
  let finalB := shareUnion d (shareUnion d tailB upB) boundary
  have htailBSub : tailB.Sublist (List.range tail.g.d) :=
    subsetsUpTo_sublist _ _ _ htailB
  have hupBSub : upB.Sublist (List.range up.g.d) :=
    subsetsUpTo_sublist _ _ _ hupB
  have htailBMem : ∀ share ∈ tailB, share < d := by
    intro share hshare
    have : share < tail.g.d := by simpa using htailBSub.mem hshare
    simpa [tail.d_eq] using this
  have hupBMem : ∀ share ∈ upB, share < d := by
    intro share hshare
    have : share < up.g.d := by simpa using hupBSub.mem hshare
    simpa [up.d_eq] using this
  have hboundaryMem : ∀ share ∈ boundary, share < d := by
    intro share hshare
    simpa using hboundary.mem hshare
  have hinnerLength := shareUnion_length_le d tailB upB htailBMem hupBMem
  have hinnerMem : ∀ share ∈ shareUnion d tailB upB, share < d := by
    intro share hshare
    simpa using (shareUnion_sublist d tailB upB).mem hshare
  have hfinalLength := shareUnion_length_le d
    (shareUnion d tailB upB) boundary hinnerMem hboundaryMem
  have htailBBound := subsetsUpTo_bound _ _ _ htailB
  have hupBBound := subsetsUpTo_bound _ _ _ hupB
  have hpartition' : upInternal.length + boundary.length +
      tailInternal.length ≤ internal.length := by
    simpa [upInternal, boundary, tailInternal, Nat.add_assoc,
      Nat.add_left_comm, Nat.add_comm] using hpartition
  have hfinalBound : finalB.length ≤ internal.length := by
    dsimp [finalB] at hfinalLength ⊢
    omega
  have hfinalSubComposite : finalB.Sublist (List.range composite.d) := by
    have hsub := shareUnion_sublist d (shareUnion d tailB upB) boundary
    simpa [composite, registeredComposite, tail.d_eq] using hsub
  have hfinal : finalB ∈
      subsetsUpTo internal.length (List.range composite.d) :=
    mem_subsetsUpTo_of_sublist hfinalSubComposite hfinalBound
  refine ⟨finalB, hfinal, ?_⟩
  let desiredShares := outputs ++ finalB
  let desiredProjection := projection composite desiredShares
  let upShares := demanded ++ upB
  let tailShares := outputs ++ tailB
  have htailFinal : ∀ share ∈ tailB, share ∈ finalB := by
    intro share hshare
    simp only [finalB, shareUnion, List.mem_filter, List.mem_range,
      Bool.or_eq_true, List.contains_iff_mem]
    exact ⟨htailBMem share hshare, Or.inl ⟨htailBMem share hshare,
      Or.inl hshare⟩⟩
  have hupFinal : ∀ share ∈ upB, share ∈ finalB := by
    intro share hshare
    simp only [finalB, shareUnion, List.mem_filter, List.mem_range,
      Bool.or_eq_true, List.contains_iff_mem]
    exact ⟨hupBMem share hshare, Or.inl ⟨hupBMem share hshare,
      Or.inr hshare⟩⟩
  have hboundaryFinal : ∀ share ∈ boundary, share ∈ finalB := by
    intro share hshare
    simp only [finalB, shareUnion, List.mem_filter, List.mem_range,
      Bool.or_eq_true, List.contains_iff_mem]
    exact ⟨hboundaryMem share hshare, Or.inr hshare⟩
  have hdemandedCases : ∀ share ∈ demanded,
      share ∈ outputs ∨ share ∈ tailB ∨ share ∈ boundary := by
    intro share hshare
    simp only [demanded, propagatedShares, shareUnion, List.mem_filter,
      List.mem_range, Bool.or_eq_true, List.contains_iff_mem] at hshare
    rcases hshare.2 with hinner | hboundaryShare
    · exact hinner.2.elim Or.inl (fun h => Or.inr (Or.inl h))
    · exact Or.inr (Or.inr hboundaryShare)
  have hupDesired : ∀ share ∈ upShares, share ∈ desiredShares := by
    intro share hshare
    rcases List.mem_append.mp hshare with hdemandedShare | hupBShare
    · rcases hdemandedCases share hdemandedShare with houtput |
          htailShare | hboundaryShare
      · exact List.mem_append_left _ houtput
      · exact List.mem_append_right _ (htailFinal share htailShare)
      · exact List.mem_append_right _
          (hboundaryFinal share hboundaryShare)
    · exact List.mem_append_right _ (hupFinal share hupBShare)
  have htailDesired : ∀ share ∈ tailShares,
      share ∈ desiredShares := by
    intro share hshare
    rcases List.mem_append.mp hshare with houtput | htailShare
    · exact List.mem_append_left _ houtput
    · exact List.mem_append_right _ (htailFinal share htailShare)
  have hdemandedSub : demanded.Sublist (List.range d) := by
    exact shareUnion_sublist d (shareUnion d outputs tailB) boundary
  let certificateNodes :=
    upstreamCertificateNodes up upInternal demanded upB
  let upNodes := upstreamTranscriptNodes up upInternal demanded upB
  let tailNodes := tailTranscriptNodes tail tailInternal outputs
  let compositeNodes := expandedNodes composite transitionGlitch
    (internal ++ outputs.map composite.output)
  have hupSamples' : SamplesSimulatableOn
      (boolVectors (inputWidth up.g)) (projection up.g upShares)
      (fun x => (envsForInput up.g x).map
        (observe up.g certificateNodes)) := by
    simpa [upShares, demanded, certificateNodes, upstreamCertificateNodes,
      up.d_eq]
      using hupSamples
  have hfirst : SamplesSimulatableOn
      (boolVectors (inputWidth composite)) desiredProjection
      (fun x => (envsForInput up.g (pipelineUpInput up tail x)).map
        (observe up.g certificateNodes)) := by
    apply samplesSimulatableOn_reindex
      (sourceXs := boolVectors (inputWidth up.g))
      (xs := boolVectors (inputWidth composite))
      (sourceProjection := projection up.g upShares)
      (projection := desiredProjection)
      (samples := fun x => (envsForInput up.g x).map
        (observe up.g certificateNodes))
      (pipelineUpInput up tail)
    · intro x hx
      exact pipelineUpInput_mem up tail x
    · intro x hx y hy hprojection
      apply projection_eq_of_bits
      intro input hinput share hshare
      have hshareD : share < d := by
        rcases List.mem_append.mp hshare with hdemandedShare | hupBShare
        · simpa using hdemandedSub.mem hdemandedShare
        · exact hupBMem share hupBShare
      have hshareUp : share < up.g.d := by simpa [up.d_eq] using hshareD
      rw [pipelineUpInput_bit up tail x input share hinput hshareUp]
      rw [pipelineUpInput_bit up tail y input share hinput hshareUp]
      have htailPositive : 0 < tail.g.inputCount :=
        Nat.zero_lt_of_lt tail.ports.input_bound
      have hinputComposite : input < composite.inputCount := by
        simp [composite, registeredComposite]
        omega
      exact inputBit_eq_of_projection_eq composite desiredShares x y
        input share hinputComposite (hupDesired share hshare) hprojection
    · exact hupSamples'
  rcases htailSamples with
    ⟨tailSimulator, htailPositive, htailPerm⟩
  have hsecond : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ upEnv ∈ envsForInput up.g (pipelineUpInput up tail x),
      ∀ y ∈ boolVectors (inputWidth composite),
      ∀ other ∈ envsForInput up.g (pipelineUpInput up tail y),
      desiredProjection x = desiredProjection y →
      observe up.g certificateNodes upEnv =
          observe up.g certificateNodes other →
      ((envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
          (observe tail.g tailNodes)).Perm
        ((envsForInput tail.g (pipelineTailInput up tail y other)).map
          (observe tail.g tailNodes)) := by
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
      apply projection_eq_of_bits
      intro input hinput share hshare
      have hshareD : share < d := by
        rcases List.mem_append.mp hshare with houtput | htailShare
        · simpa using houtputsSub.mem houtput
        · exact htailBMem share htailShare
      have hshareTail : share < tail.g.d := by
        simpa [tail.d_eq] using hshareD
      rw [pipelineTailInput_bit up tail x upEnv input share hinput hshareTail]
      rw [pipelineTailInput_bit up tail y other input share hinput hshareTail]
      by_cases hconnected : input = tail.ports.downstreamInput
      · rw [if_pos hconnected, if_pos hconnected]
        have hdemandedShare : share ∈ demanded := by
          simp only [demanded, propagatedShares, shareUnion, List.mem_filter,
            List.mem_range, Bool.or_eq_true, List.contains_iff_mem]
          rcases List.mem_append.mp hshare with houtput | htailShare
          · exact ⟨hshareD, Or.inl ⟨hshareD, Or.inl houtput⟩⟩
          · exact ⟨hshareD, Or.inl ⟨hshareD, Or.inr htailShare⟩⟩
        have houtputNode : up.g.output share ∈ upNodes := by
          simp only [upNodes, upstreamTranscriptNodes, List.mem_eraseDups,
            List.mem_append, List.mem_map]
          left
          right
          exact ⟨share, hdemandedShare, rfl⟩
        have hvalue := congrArg
          (fun values => observationAt upNodes values (up.g.output share))
          hdecoded
        rw [observationAt_observe_of_mem up.g upNodes upEnv
          (up.g.output share) houtputNode,
          observationAt_observe_of_mem up.g upNodes other
            (up.g.output share) houtputNode] at hvalue
        exact hvalue
      · rw [if_neg hconnected, if_neg hconnected]
        have hhidden := tail.ports.input_bound
        have hindex := hideRegisteredInput_lt tail.ports.downstreamInput
          input tail.g.inputCount hhidden hinput hconnected
        have hinputComposite : up.g.inputCount +
            hideRegisteredInput tail.ports.downstreamInput input <
              composite.inputCount := by
          simp [composite, registeredComposite]
          omega
        exact inputBit_eq_of_projection_eq composite desiredShares x y
          (up.g.inputCount +
            hideRegisteredInput tail.ports.downstreamInput input) share
          hinputComposite (htailDesired share hshare) hprojection
    have hleft :
        ((envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
          (observe tail.g tailNodes)).Perm
        (tailSimulator (projection tail.g tailShares
          (pipelineTailInput up tail x upEnv))) := by
      simpa [tailNodes, tailTranscriptNodes, tailShares] using
        htailPerm (pipelineTailInput up tail x upEnv)
          (pipelineTailInput_mem up tail x upEnv)
    have hright :
        ((envsForInput tail.g (pipelineTailInput up tail y other)).map
          (observe tail.g tailNodes)).Perm
        (tailSimulator (projection tail.g tailShares
          (pipelineTailInput up tail y other))) := by
      simpa [tailNodes, tailTranscriptNodes, tailShares] using
        htailPerm (pipelineTailInput up tail y other)
          (pipelineTailInput_mem up tail y other)
    rw [htailProjection] at hleft
    exact hleft.trans hright.symm
  let emit : Observation → Observation → Observation :=
    fun upValues tailValues =>
      reconstructPipelineObservation up tail upNodes tailNodes compositeNodes
        (decodeUpstreamObservation up upInternal demanded upB upValues)
        tailValues
  have hsecondNonempty : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ upEnv ∈ envsForInput up.g (pipelineUpInput up tail x),
      (envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
          (observe tail.g tailNodes) ≠ [] := by
    intro x hx upEnv hupEnv
    have hne := envsForInput_ne_nil_of_valid tail.g
      (pipelineTailInput up tail x upEnv) (fixingForInput_valid tail.g _)
    rcases List.exists_mem_of_ne_nil _ hne with ⟨tailEnv, htailEnv⟩
    exact List.ne_nil_of_mem (List.mem_map.mpr ⟨tailEnv, htailEnv, rfl⟩)
  have hassembled : SamplesSimulatableOn
      (boolVectors (inputWidth composite)) desiredProjection (fun x =>
        (envsForInput up.g (pipelineUpInput up tail x)).flatMap fun upEnv =>
          ((envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
            (observe tail.g tailNodes)).map
              (emit (observe up.g certificateNodes upEnv))) := by
    apply samplesSimulatableOn_hidden_bind emit hsecond hsecondNonempty hfirst
  have hfactor : ∀ x ∈ boolVectors (inputWidth composite),
      ((envsForInput composite x).map
        (observe composite compositeNodes)).Perm
      ((envsForInput up.g (pipelineUpInput up tail x)).flatMap fun upEnv =>
        ((envsForInput tail.g (pipelineTailInput up tail x upEnv)).map
          (observe tail.g tailNodes)).map
            (emit (observe up.g certificateNodes upEnv))) := by
    intro x hx
    have hraw := (experiment_product_raw up tail glue x).map
      (observe composite compositeNodes)
    apply hraw.trans
    rw [envsForInput_eq_cellAssignments up.g (pipelineUpInput up tail x)]
    simp only [List.map_flatMap, List.map_map, List.flatMap_map,
      Function.comp_def]
    apply flatMap_perm_of_pointwise
    intro upValues hupValues
    rw [envsForInput_eq_cellAssignments tail.g
      (pipelineTailInput up tail x (Execution.envFrom upValues))]
    simp only [List.map_map, Function.comp_def]
    apply List.Perm.of_eq
    apply List.map_congr_left
    intro tailValues htailValues
    let upEnv := Execution.envFrom upValues
    let tailEnv := Execution.envFrom tailValues
    let combined := Execution.envFrom
      (upValues ++ boundaryAssignment up.g d ++
        shiftedTailAssignment up.g tail.g tail.ports tailValues)
    have hupKeys := assignmentsPattern_keys _ _ upValues hupValues
    have htailKeys := assignmentsPattern_keys _ _ tailValues htailValues
    have hupEnvMem : upEnv ∈
        envsForInput up.g (pipelineUpInput up tail x) :=
      assignmentEnv_mem up.g (pipelineUpInput up tail x) upValues hupValues
    have htailEnvMem : tailEnv ∈ envsForInput tail.g
        (pipelineTailInput up tail x upEnv) :=
      assignmentEnv_mem tail.g (pipelineTailInput up tail x upEnv)
        tailValues htailValues
    have hcombinedMem : combined ∈ envsForInput composite x := by
      simpa [composite, combined] using
        productEnv_mem up tail glue x upValues tailValues
          hupValues htailValues
    have hrestrict : restrictEnv
        (Execution.relevantSrcs up.g.circuit up.g.horizon) combined = upEnv :=
      restrictEnv_product_up_eq up tail upValues tailValues hupKeys
    have hagree := substitutedTailEnv_product_agrees up tail glue x
      upValues tailValues hupValues htailValues
    have htailObserve : observe tail.g tailNodes
        (substitutedTailEnv up.g tail.g tail.ports combined) =
          observe tail.g tailNodes tailEnv := by
      rw [observe_eq_map_eval, observe_eq_map_eval]
      apply List.map_congr_left
      intro node hnode
      exact UniversalSStage1.eval_env_congr tail.g.circuit tail.g.horizon
        _ _ node hagree
    have hreconstruct := reconstructPipelineObservation_eq up tail glue
      internal outputs tailB upB hinternalSub houtputsSub combined
      (pipelineUpInput up tail x) (pipelineUpInput_mem up tail x)
      (by simpa [hrestrict] using hupEnvMem)
      (fun share hshare => composite_env_boundaryInit_false up tail glue x
        combined hcombinedMem share hshare)
    dsimp only at hreconstruct
    rw [hrestrict, htailObserve] at hreconstruct
    dsimp [emit]
    rw [decodeUpstreamObservation_eq up upInternal demanded upB
      hdemandedSub upEnv]
    exact hreconstruct.symm
  rcases hassembled with ⟨simulator, hpositive, hperm⟩
  apply samplesSimulatableOn_to_simulatableOn
  refine ⟨simulator, hpositive, ?_⟩
  intro x hx
  exact (hfactor x hx).trans (hperm x hx)

/-- Prepend one O-PINI-certified leaf to an arbitrary certified pipeline
tail.  Every invariant field is preserved, so the construction is a genuine
fixpoint for linear registered composition. -/
def compose {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : opiniSpec up.g transitionGlitch t)
    (glue : PortGlue up tail) : PipelineGadget H d t where
  g := registeredComposite up.g tail.ports
  horizon_eq := by
    simp [registeredComposite, up.horizon_eq, tail.horizon_eq]
  d_eq := by
    simp [registeredComposite, tail.d_eq]
  order_lt := up.order_lt
  whole_window := registeredComposite_wholeWindow up tail
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := prependedPorts up tail
  arrival_inside := prependedPorts_arrival_inside up tail
  interface_injective := registeredComposite_interfaceInjective up tail glue
  source_partition := registeredComposite_sourcePartition up tail glue
  port_source_exclusive :=
    registeredComposite_portSourceExclusive up tail glue
  forward_combinational := registeredComposite_forwardCombinational up tail
  pinned_init := registeredComposite_pinnedInit up tail glue
  outCycle := tail.outCycle
  output_at := registeredComposite_output_at up tail
  output_inj := registeredComposite_output_injective up tail
  output_pulse := registeredComposite_outputPulse up tail glue
  down_cert := compose_pini up tail hup glue

@[simp] theorem compose_g {H d t : Nat}
    (up tail : PipelineGadget H d t)
    (hup : opiniSpec up.g transitionGlitch t)
    (glue : PortGlue up tail) :
    (compose up tail hup glue).g = registeredComposite up.g tail.ports := rfl

namespace UniversalReg.Concrete

/-- Registered input port of the concrete upstream leaf. -/
def upstreamPorts : RegisterPorts upstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 5
    omega
  arrivalCycle := 1
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨0, rfl, rfl⟩
    · exact ⟨0, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

set_option maxHeartbeats 2000000 in
def upstreamPipeline : PipelineGadget 3 2 1 where
  g := upstream
  horizon_eq := rfl
  d_eq := rfl
  order_lt := by decide
  whole_window := upstream_wholeWindow
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := upstreamPorts
  arrival_inside := by decide
  interface_injective := by decide
  source_partition := by decide
  port_source_exclusive := by decide
  forward_combinational := by decide
  pinned_init := upstream_pinnedInit
  outCycle := 1
  output_at := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl <;> rfl
  output_inj := by
    intro i j hi hj heq
    change i < 2 at hi
    change j < 2 at hj
    have his : i = 0 ∨ i = 1 := by omega
    have hjs : j = 0 ∨ j = 1 := by omega
    rcases his with rfl | rfl <;> rcases hjs with rfl | rfl <;>
      simp [upstream] at heq ⊢
  output_pulse := outputPulse
  down_cert := opini_implies_pini upstream transitionGlitch 1 upstream_opini

set_option maxHeartbeats 2000000 in
def downstreamPipeline : PipelineGadget 3 2 1 where
  g := downstream
  horizon_eq := rfl
  d_eq := rfl
  order_lt := by decide
  whole_window := downstream_wholeWindow
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := ports
  arrival_inside := by decide
  interface_injective := by decide
  source_partition := by decide
  port_source_exclusive := by decide
  forward_combinational := by decide
  pinned_init := downstream_pinnedInit
  outCycle := 2
  output_at := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl <;> rfl
  output_inj := by
    intro i j hi hj heq
    change i < 2 at hi
    change j < 2 at hj
    have his : i = 0 ∨ i = 1 := by omega
    have hjs : j = 0 ∨ j = 1 := by omega
    rcases his with rfl | rfl <;> rcases hjs with rfl | rfl <;>
      simp [downstream] at heq ⊢
  output_pulse := by decide
  down_cert := opini_implies_pini downstream transitionGlitch 1 downstream_opini

/-- The concrete staggered leaves inhabit the generic composition domain. -/
theorem concreteGlue : PortGlue upstreamPipeline downstreamPipeline := by
  refine ⟨rfl, ?_⟩
  exact fullSourceDisjointness

/-- The still-external upstream input of the registered concrete pipeline. -/
def compositePorts : RegisterPorts composite where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 16
    omega
  arrivalCycle := 1
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨0, rfl, rfl⟩
    · exact ⟨0, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

set_option maxHeartbeats 2000000 in
/-- Standing non-vacuity witness: the concrete registered construction meets
the complete component-local pipeline invariant at strict order one. -/
def concretePipeline : PipelineGadget 3 2 1 where
  g := composite
  horizon_eq := rfl
  d_eq := rfl
  order_lt := by decide
  whole_window := by decide
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := compositePorts
  arrival_inside := by decide
  interface_injective := by decide
  source_partition := by decide
  port_source_exclusive := by decide
  forward_combinational := by decide
  pinned_init := composite_pinnedInit
  outCycle := 2
  output_at := by
    intro j hj
    change j < 2 at hj
    have hs : j = 0 ∨ j = 1 := by omega
    rcases hs with rfl | rfl <;> rfl
  output_inj := by
    intro i j hi hj heq
    change i < 2 at hi
    change j < 2 at hj
    have his : i = 0 ∨ i = 1 := by omega
    have hjs : j = 0 ∨ j = 1 := by omega
    rcases his with rfl | rfl <;> rcases hjs with rfl | rfl <;>
      simp [composite] at heq ⊢
  output_pulse := by decide
  down_cert := composite_pini

/-- The generic closure theorem instantiated on the concrete registered
upstream/downstream leaves. -/
def composedPipeline : PipelineGadget 3 2 1 :=
  compose upstreamPipeline downstreamPipeline upstream_opini concreteGlue

/-- End-to-end concrete probing security obtained from the closed invariant. -/
theorem composedPipeline_probing :
    probingSecureSpec composedPipeline.g transitionGlitch 1 :=
  composedPipeline.probing

end UniversalReg.Concrete

end Composition
end LeanSec
