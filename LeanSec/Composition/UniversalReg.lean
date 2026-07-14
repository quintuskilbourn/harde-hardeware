import LeanSec.Composition.UniversalTFinal
import LeanSec.Composition.UniversalSStage1

namespace LeanSec
namespace Composition
namespace UniversalReg

open Gadget

/-! ## Register-layer transition neutrality

The evaluator represents the input wire of a latency-one register at output
cycle `cycle + 1` by the source node at `cycle`.  The lemmas below expose that
fact directly from the frozen fold evaluator.  No stability assumption is
made: both sides are allowed to change from one cycle to the next.
-/

private theorem lookupAssoc_evalCycle_of_cycle_ne
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
      rw [← UniversalSStage1.evalCycle]
      rw [ih]
      have hnode : target ≠ { gate := gate, cycle := cycle } := by
        intro heq
        exact hne (congrArg Node.cycle heq)
      simp [Execution.lookupAssoc, hnode]

private theorem lookupAssoc_evalCycle_of_gate_not_mem
    (c : Circuit) (env : Env) (cycle gate : Nat) (schedule : List Nat)
    (values : List (Node × Bool)) (hnot : gate ∉ schedule) :
    Execution.lookupAssoc { gate := gate, cycle := cycle }
        (UniversalSStage1.evalCycle c env cycle schedule values) =
      Execution.lookupAssoc { gate := gate, cycle := cycle } values := by
  induction schedule generalizing values with
  | nil => rfl
  | cons current schedule ih =>
      simp only [List.mem_cons, not_or] at hnot
      rw [UniversalSStage1.evalCycle]
      simp only [List.foldl_cons]
      rw [← UniversalSStage1.evalCycle]
      rw [ih _ hnot.2]
      have hnode :
          ({ gate := gate, cycle := cycle } : Node) ≠
            { gate := current, cycle := cycle } := by
        intro heq
        exact hnot.1 (congrArg Node.gate heq)
      simp [Execution.lookupAssoc, hnode]

private theorem lookupAssoc_register_after_evalCycle
    (c : Circuit) (env : Env) (source register previous : Nat)
    (schedule : List Nat) (values : List (Node × Bool))
    (hgate : c.gates[register]? =
      some { kind := .reg, inputs := [(source, 1)] })
    (hmem : register ∈ schedule) :
    Execution.lookupAssoc { gate := register, cycle := previous + 1 }
        (UniversalSStage1.evalCycle c env (previous + 1) schedule values) =
      some ((Execution.lookupAssoc { gate := source, cycle := previous }
        values).getD false) := by
  induction schedule generalizing values with
  | nil => simp at hmem
  | cons current schedule ih =>
      rw [UniversalSStage1.evalCycle]
      simp only [List.foldl_cons]
      rw [← UniversalSStage1.evalCycle]
      by_cases htail : register ∈ schedule
      · rw [ih _ htail]
        have hnode :
            ({ gate := source, cycle := previous } : Node) ≠
              { gate := current, cycle := previous + 1 } := by
          intro heq
          have hcycles : previous = previous + 1 := by
            simpa using congrArg Node.cycle heq
          omega
        simp [Execution.lookupAssoc, hnode]
      · have hcurrent : current = register := by
          symm
          simpa [htail] using hmem
        subst current
        rw [lookupAssoc_evalCycle_of_gate_not_mem c env (previous + 1)
          register schedule _ htail]
        simp only [Execution.lookupAssoc, beq_self_eq_true, if_true]
        simp [UniversalSStage1.gateValue, hgate,
          UniversalSStage1.inputValue]

private theorem evalEntries_succ (c : Circuit) (horizon : Nat) (env : Env) :
    UniversalSStage1.evalEntries c (horizon + 1) env =
      UniversalSStage1.evalCycle c env horizon (Execution.gateOrder c)
        (UniversalSStage1.evalEntries c horizon env) := by
  simp [UniversalSStage1.evalEntries, UniversalSStage1.evalCycles,
    List.range_succ, List.foldl_append]

private theorem gate_mem_gateOrder (c : Circuit) (gate : Nat)
    (hgate : gate < c.gates.size) : gate ∈ Execution.gateOrder c := by
  unfold Execution.gateOrder
  by_cases htopo : gate ∈ Execution.topoLoop c.combEdges c.gates.size
      (List.range c.gates.size)
  · exact List.mem_append_left _ htopo
  · apply List.mem_append_right
    simp [hgate, htopo]

private theorem eval_succ_of_cycle_lt (c : Circuit) (horizon : Nat)
    (env : Env) (node : Node) (hcycle : node.cycle < horizon) :
    Execution.eval c (horizon + 1) env node =
      Execution.eval c horizon env node := by
  by_cases hgate : node.gate < c.gates.size
  · have hcycle' : node.cycle < horizon + 1 := by omega
    simp only [Execution.eval, hgate, hcycle, hcycle',
      Bool.true_and, decide_true, if_true]
    rw [← UniversalSStage1.evalEntries_eq_execution,
      ← UniversalSStage1.evalEntries_eq_execution, evalEntries_succ]
    rw [lookupAssoc_evalCycle_of_cycle_ne]
    omega
  · simp [Execution.eval, hgate]

/-- A latency-one register presents its input-source value one cycle earlier.
This is the value-level register identity used by transition neutrality. -/
theorem eval_register_succ (c : Circuit) (horizon : Nat) (env : Env)
    (source register cycle : Nat) (hwf : c.WF)
    (hgate : c.gates[register]? =
      some { kind := .reg, inputs := [(source, 1)] })
    (hcycle : cycle + 1 < horizon) :
    Execution.eval c horizon env { gate := register, cycle := cycle + 1 } =
      Execution.eval c horizon env { gate := source, cycle := cycle } := by
  induction horizon with
  | zero => omega
  | succ horizon ih =>
      by_cases hearlier : cycle + 1 < horizon
      · rw [eval_succ_of_cycle_lt c horizon env
          { gate := register, cycle := cycle + 1 } hearlier]
        rw [eval_succ_of_cycle_lt c horizon env
          { gate := source, cycle := cycle } (by
            change cycle < horizon
            omega)]
        exact ih hearlier
      · have hlast : cycle + 1 = horizon := by omega
        subst horizon
        have hregister : register < c.gates.size := by
          by_cases hin : register < c.gates.size
          · exact hin
          · have hnone : c.gates[register]? = none := by simp [hin]
            rw [hnone] at hgate
            contradiction
        have hsource : source < c.gates.size := by
          have hall := Array.all_eq_true.mp hwf.1 register hregister
          have hentry : c.gates[register] =
              { kind := .reg, inputs := [(source, 1)] } := by
            simpa [hregister] using hgate
          rw [hentry] at hall
          simp only [Bool.and_eq_true] at hall
          have hinput := List.all_eq_true.mp hall.2 (source, 1)
            (List.mem_cons_self)
          simpa using hinput
        simp [Execution.eval, hregister, hsource]
        rw [← UniversalSStage1.evalEntries_eq_execution, evalEntries_succ]
        rw [lookupAssoc_register_after_evalCycle c env source register cycle
          (Execution.gateOrder c) _ hgate
          (gate_mem_gateOrder c register hregister)]
        rw [lookupAssoc_evalCycle_of_cycle_ne]
        · have hlt : cycle < cycle + 1 + 1 := by omega
          simp [hlt]
        · change cycle ≠ cycle + 1
          omega

/-- **N1 (CS21 register-layer neutrality).** Away from the initialization
boundary, the transition-extended observation of a register output is exactly
the transition-extended observation of its input wire, shifted by the
register's one-cycle latency.  The equality is of concrete observation tuples
for every environment; the input stream need not be stable. -/
theorem register_output_transition_eq_input
    (c : Circuit) (horizon : Nat) (env : Env)
    (source register cycle : Nat) (hwf : c.WF)
    (hgate : c.gates[register]? =
      some { kind := .reg, inputs := [(source, 1)] })
    (hinside : cycle + 2 < horizon) :
    (transition c horizon { gate := register, cycle := cycle + 2 }).map
        (Execution.eval c horizon env) =
      (transition c horizon { gate := source, cycle := cycle + 1 }).map
        (Execution.eval c horizon env) := by
  rw [Expansion.transition_at_successor c horizon register (cycle + 1)
      hinside]
  rw [Expansion.transition_at_successor c horizon source cycle (by omega)]
  simp only [List.map_cons, List.map_nil]
  rw [eval_register_succ c horizon env source register cycle hwf hgate
      (by omega)]
  rw [eval_register_succ c horizon env source register (cycle + 1) hwf hgate
      hinside]

/-- A register has no latency-zero input cone.  Consequently glitch expansion
stops at its output, and `transitionGlitch` reveals exactly the same adjacent
register-output nodes as plain transition expansion. -/
theorem register_output_transitionGlitch_eq_transition
    (c : Circuit) (horizon source register cycle : Nat)
    (hgate : c.gates[register]? =
      some { kind := .reg, inputs := [(source, 1)] }) :
    transitionGlitch c horizon { gate := register, cycle := cycle } =
      transition c horizon { gate := register, cycle := cycle } := by
  have hfrontier :
      Expansion.glitchGates c c.gates.size register = [register] := by
    cases hsize : c.gates.size with
    | zero =>
        have hnone : c.gates[register]? = none := by simp [hsize]
        rw [hnone] at hgate
        contradiction
    | succ fuel => simp [Expansion.glitchGates, hgate]
  have hglitch (atCycle : Nat) :
      glitch c horizon { gate := register, cycle := atCycle } =
        [{ gate := register, cycle := atCycle }] := by
    rw [Expansion.glitch_cycle, hfrontier]
    rfl
  by_cases inside : 0 < cycle ∧ cycle < horizon
  · simp [transitionGlitch, Expansion.compose, transition, inside, hglitch]
    apply eraseDups_eq_self_of_nodup
    apply List.nodup_cons.mpr
    constructor
    · intro hmem
      have heq :
          ({ gate := register, cycle := cycle - 1 } : Node) =
            { gate := register, cycle := cycle } := by
        simpa using hmem
      have hcycles : cycle - 1 = cycle := by
        simpa using congrArg Node.cycle heq
      omega
    · apply List.nodup_cons.mpr
      exact ⟨by simp, by simp⟩
  · simp [transitionGlitch, Expansion.compose, transition, inside, hglitch]
    exact eraseDups_eq_self_of_nodup (by simp)

/-! ## N2: whole register-layer neutrality -/

/-- One latency-aligned observation site in a boundary register layer.  The
output probe is at `cycle + 2`; its corresponding input-wire probe is at
`cycle + 1`. -/
structure RegisterLayerSite where
  source : Nat
  register : Nat
  cycle : Nat
deriving DecidableEq, Repr

def RegisterLayerSite.outputNode (site : RegisterLayerSite) : Node :=
  { gate := site.register, cycle := site.cycle + 2 }

def RegisterLayerSite.inputNode (site : RegisterLayerSite) : Node :=
  { gate := site.source, cycle := site.cycle + 1 }

def transitionValues (c : Circuit) (horizon : Nat) (env : Env)
    (node : Node) : Observation :=
  (transition c horizon node).map (Execution.eval c horizon env)

/-- **N2 (CS21 register-layer neutrality).** Replacing every
transition-extended probe on a boundary-register output by the latency-aligned
probe on that register's input preserves the complete observation tuple.
This holds for an arbitrary number of boundary registers and repeated probe
sites. -/
theorem register_layer_transition_neutral
    (c : Circuit) (horizon : Nat) (env : Env)
    (sites : List RegisterLayerSite) (hwf : c.WF)
    (hgates : ∀ site ∈ sites,
      c.gates[site.register]? =
        some { kind := .reg, inputs := [(site.source, 1)] })
    (hinside : ∀ site ∈ sites, site.cycle + 2 < horizon) :
    sites.flatMap (fun site =>
        transitionValues c horizon env site.outputNode) =
      sites.flatMap (fun site =>
        transitionValues c horizon env site.inputNode) := by
  induction sites with
  | nil => rfl
  | cons site sites ih =>
      simp only [List.flatMap_cons]
      have hhead : transitionValues c horizon env site.outputNode =
          transitionValues c horizon env site.inputNode := by
        simpa [transitionValues, RegisterLayerSite.outputNode,
          RegisterLayerSite.inputNode] using
          register_output_transition_eq_input c horizon env site.source
            site.register site.cycle hwf (hgates site (by simp))
            (hinside site (by simp))
      rw [hhead]
      rw [ih]
      · intro other hother
        exact hgates other (by simp [hother])
      · intro other hother
        exact hinside other (by simp [hother])

/-- Adding arbitrary unchanged observations around the register layer does not
alter N2: the register-output pairs can be replaced in place by input-wire
pairs. -/
theorem register_layer_adds_no_transition_pair
    (c : Circuit) (horizon : Nat) (env : Env)
    (before after : Observation) (sites : List RegisterLayerSite)
    (hwf : c.WF)
    (hgates : ∀ site ∈ sites,
      c.gates[site.register]? =
        some { kind := .reg, inputs := [(site.source, 1)] })
    (hinside : ∀ site ∈ sites, site.cycle + 2 < horizon) :
    before ++ sites.flatMap (fun site =>
        transitionValues c horizon env site.outputNode) ++ after =
      before ++ sites.flatMap (fun site =>
        transitionValues c horizon env site.inputNode) ++ after := by
  rw [register_layer_transition_neutral c horizon env sites hwf hgates hinside]

/-- Pointwise observation equality is security-neutral at the audited
simulator interface.  N2 supplies such an equality for a boundary layer, so
no probabilistic factorization premise is needed to transport
simulatability. -/
theorem simulatableOn_iff_of_observation_eq
    (xs : List (List Bool)) (envsOf : List Bool → List Env)
    (projI : List Bool → List Bool) (left right : Env → Observation)
    (heq : ∀ env, left env = right env) :
    SimulatableOn xs envsOf projI left ↔
      SimulatableOn xs envsOf projI right := by
  have hfun : left = right := funext heq
  subst right
  rfl

/-! ## A decidable temporal port contract

`Gate.inputs` is static, while `GadgetInstance.inputArrival` names a source
at one particular cycle.  The missing interface fact is therefore stated on
the downstream member boundary: a static edge from a connected input gate is
live only at the declared arrival cycle.  Requiring latency zero makes the
consumer cycle and source cycle coincide.
-/

/-- Structural data identifying the source gate of every share of one
connected downstream input.  The coherence field ties that gate to the exact
source named by `inputArrival`; the cycle is explicit so the contract remains
decidable even though `Src` has several constructors. -/
structure RegisterPorts (down : GadgetInstance) where
  downstreamInput : Nat
  input_bound : downstreamInput < down.inputCount
  inputGate : Nat → Nat
  input_gate_bound : ∀ share, share < down.d →
    inputGate share < down.circuit.gates.size
  arrivalCycle : Nat
  input_source_coherent : ∀ share, share < down.d → ∃ sharing,
    down.circuit.gates[inputGate share]? =
        some { kind := .inp sharing share, inputs := [] } ∧
      down.inputArrival downstreamInput share =
        .inp sharing share arrivalCycle
  input_gates_injective : ∀ i j, i < down.d → j < down.d →
    inputGate i = inputGate j → i = j

/-- A live downstream gate consumes `source` through a particular static
edge.  "Live" deliberately means membership in the gadget execution, not
mere presence in the circuit array. -/
def LiveRead (down : GadgetInstance) (source gate cycle latency : Nat) : Prop :=
  down.member { gate := gate, cycle := cycle } = true ∧
    ∃ entry, down.circuit.gates[gate]? = some entry ∧
      (source, latency) ∈ entry.inputs

/-- Finite enumeration of all live reads of one source gate. -/
def liveReads (down : GadgetInstance) (source : Nat) : List (Node × Nat) :=
  (memberNodes down).flatMap fun node =>
    match down.circuit.gates[node.gate]? with
    | none => []
    | some entry =>
        (entry.inputs.filter fun edge => edge.1 == source).map fun edge =>
          (node, edge.2)

/-- **Temporal interface faithfulness (`single_read`).** Every connected
share is genuinely consumed, and every live consumer of its source gate is a
zero-latency consumer at the one cycle declared by `inputArrival`.  This is a
stated, executable precondition; it does not alter `GadgetInstance.WF`. -/
def PortContract {down : GadgetInstance}
    (ports : RegisterPorts down) : Prop :=
  ∀ share ∈ List.range down.d,
    liveReads down (ports.inputGate share) ≠ [] ∧
      ∀ read ∈ liveReads down (ports.inputGate share),
        read.1.cycle = ports.arrivalCycle ∧ read.2 = 0

instance {down : GadgetInstance} (ports : RegisterPorts down) :
    Decidable (PortContract ports) := by
  unfold PortContract
  infer_instance

/-- **Cross-gadget port alignment.**  The connected interfaces have the same
share count.  For every connected share, the latency-one boundary register
presents the upstream output at `output.cycle + 1`, and every live downstream
read of that share occurs at exactly that register-output cycle.

Unlike `PortContract`, this proposition is indexed by both gadgets, so the
upstream/output half of the cycle equation is expressible. -/
def PortAlignment (up down : GadgetInstance)
    (ports : RegisterPorts down) : Prop :=
  up.d = down.d ∧ ports.arrivalCycle < up.horizon ∧
    ∀ share ∈ List.range down.d,
      (up.output share).cycle + 1 = ports.arrivalCycle

instance (up down : GadgetInstance) (ports : RegisterPorts down) :
    Decidable (PortAlignment up down ports) := by
  unfold PortAlignment
  infer_instance

/-- The hidden connected input must not reuse a source atom belonging to an
input which remains external after compilation.  Without this condition the
isolated downstream experiment can identify two inputs which the registered
compiler necessarily separates.  This condition is component-local and
decidable; `InputAlias` below proves that it is independent of the temporal
off-cycle conditions. -/
def ConnectedInputSeparated {down : GadgetInstance}
    (ports : RegisterPorts down) : Prop :=
  ∀ external ∈ List.range down.inputCount,
    external ≠ ports.downstreamInput →
      ∀ share ∈ List.range down.d,
        down.inputArrival external share ≠
          down.inputArrival ports.downstreamInput share

instance {down : GadgetInstance} (ports : RegisterPorts down) :
    Decidable (ConnectedInputSeparated ports) := by
  unfold ConnectedInputSeparated
  infer_instance

/-- The exact port record from the superseding registered-composition memo,
paired with the compiler's pre-existing hidden-input metadata.  Keeping this
as a hypothesis-side record avoids any change to `GadgetInstance`. -/
structure RegPorts (up down : GadgetInstance) where
  compilerPorts : RegisterPorts down
  connected : Nat
  input_gate_ok : ∀ j, j < down.d →
    down.circuit.gates[compilerPorts.inputGate j]? =
      some ⟨.inp connected j, []⟩
  c₀ : Nat
  out_cycle : ∀ j, j < up.d → (up.output j).cycle = c₀
  same_d : up.d = down.d
  arrival_eq : compilerPorts.arrivalCycle = c₀ + 1
  arrival_cycle : ∀ j, j < down.d →
    down.inputArrival compilerPorts.downstreamInput j =
      .inp connected j (c₀ + 1)
  arrival_inside : c₀ + 1 < up.horizon

/-- Exact memo ports imply the compiler's sharpened cycle alignment. -/
theorem RegPorts.portAlignment {up down : GadgetInstance}
    (ports : RegPorts up down) :
    PortAlignment up down ports.compilerPorts := by
  refine ⟨ports.same_d, ?_, ?_⟩
  · simpa [ports.arrival_eq] using ports.arrival_inside
  · intro share hshare
    have hshareUp : share < up.d := by
      rw [ports.same_d]
      simpa using hshare
    rw [ports.out_cycle share hshareUp]
    exact ports.arrival_eq.symm

/-- Both components are authored on one clock.  Since the registered
compiler uses `max`, this equality also identifies their common window with
the composite window. -/
def SharedWindow (up down : GadgetInstance) : Prop :=
  up.horizon = down.horizon

instance (up down : GadgetInstance) : Decidable (SharedWindow up down) := by
  unfold SharedWindow
  infer_instance

/-- Every declared upstream output gate is quiescent away from its declared
output cycle in every finite component experiment.  This is the executable,
component-local form of the single-pulse condition: the quantification is
over the complete finite input/environment enumeration used by O-PINI. -/
def OutputPulse (up : GadgetInstance) : Prop :=
  ∀ share ∈ List.range up.d,
    ∀ x ∈ boolVectors (inputWidth up),
      ∀ env ∈ envsForInput up x,
        ∀ cycle ∈ List.range up.horizon,
          cycle ≠ (up.output share).cycle →
            Execution.eval up.circuit up.horizon env
              { gate := (up.output share).gate, cycle := cycle } = false

instance (up : GadgetInstance) : Decidable (OutputPulse up) := by
  unfold OutputPulse
  infer_instance

/-- The expansion scheme sees the entire finite component execution.  This
prevents a component certificate from silently filtering a transition or
glitch companion which the registered splice makes observable. -/
def WholeWindow (g : GadgetInstance) : Prop :=
  ∀ node ∈ nodes g, g.member node = true

instance (g : GadgetInstance) : Decidable (WholeWindow g) := by
  unfold WholeWindow
  infer_instance

/-! ## Generic registered-composite constructor -/

/-- Identify whether a downstream gate is the declared source gate of a
connected share. -/
def connectedShare? {down : GadgetInstance} (ports : RegisterPorts down)
    (gate : Nat) : Option Nat :=
  (List.range down.d).find? fun share => ports.inputGate share == gate

/-- Gate-array index of a compiler-created boundary register. -/
def boundaryRegister (up : GadgetInstance) (share : Nat) : Nat :=
  up.circuit.gates.size + share

/-- Gate-array offset of the copied downstream suffix. -/
def downstreamOffset (up down : GadgetInstance) : Nat :=
  up.circuit.gates.size + down.d

/-- A downstream register-initialization atom follows its copied gate to the
suffix.  Other source atoms retain their already-disjoint names. -/
def shiftDownSrc (up down : GadgetInstance) : Src → Src
  | .iniReg gate => .iniReg (downstreamOffset up down + gate)
  | src => src

/-- Redirect an edge from a connected input gate to the corresponding
boundary register; shift every other downstream edge into the suffix. -/
def wireRegisteredEdge {up down : GadgetInstance}
    (ports : RegisterPorts down) (edge : Nat × Nat) : Nat × Nat :=
  match connectedShare? ports edge.1 with
  | some share => (boundaryRegister up share, edge.2)
  | none => (downstreamOffset up down + edge.1, edge.2)

/-- Copy one downstream gate.  Connected input source gates become dead
constants because all of their live uses are redirected to the boundary
registers. -/
def wireRegisteredDownGate {up down : GadgetInstance}
    (ports : RegisterPorts down) (gateIndex : Nat) (gate : Gate) : Gate :=
  match connectedShare? ports gateIndex with
  | some _ => { kind := .const false, inputs := [] }
  | none => { gate with inputs := gate.inputs.map fun edge =>
      wireRegisteredEdge (up := up) ports edge }

def registeredDownGates {up down : GadgetInstance}
    (ports : RegisterPorts down) : Array Gate :=
  down.circuit.gates.mapIdx (wireRegisteredDownGate (up := up) ports)

/-- One pinned latency-one register for every connected share. -/
def boundaryRegisterGates (up down : GadgetInstance) : Array Gate :=
  (List.range down.d).toArray.map fun share =>
    { kind := .reg, inputs := [((up.output share).gate, 1)] }

/-- Literal gate-array compiler: `upstream ++ registers ++ downstream`. -/
def registeredCompositeCircuit {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down) : Circuit :=
  UniversalSStage1.appendCircuit up.circuit
    (boundaryRegisterGates up down ++ registeredDownGates (up := up) ports)

/-- Remove the connected downstream input from its external-input numbering. -/
def unhideRegisteredInput (hidden external : Nat) : Nat :=
  if external < hidden then external else external + 1

/-- Generic registered composite.  Downstream source namespaces are assumed
fresh by `FullSourceDisjointness`; only `.iniReg` atoms require gate-index
translation.  Compiler-created register resets are pinned to `false`. -/
def registeredComposite {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down) : GadgetInstance :=
  { circuit := registeredCompositeCircuit up ports
    horizon := max up.horizon down.horizon
    d := down.d
    inputCount := up.inputCount + (down.inputCount - 1)
    inputArrival := fun input share =>
      if input < up.inputCount then up.inputArrival input share
      else shiftDownSrc up down <|
        down.inputArrival
          (unhideRegisteredInput ports.downstreamInput
            (input - up.inputCount)) share
    output := fun share =>
      { gate := downstreamOffset up down + (down.output share).gate
        cycle := (down.output share).cycle }
    member := fun _ => true
    randomness := up.randomness ++ down.randomness.map (shiftDownSrc up down)
    publicFixing := up.publicFixing ++
      down.publicFixing.map (fun entry =>
        (shiftDownSrc up down entry.1, entry.2)) ++
      (List.range down.d).map (fun share =>
        (.iniReg (boundaryRegister up share), false)) }

/-- The compiler-created gate at each connected share is literally the
latency-one register driven by that share's upstream output gate. -/
theorem registeredComposite_boundary_gate {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down)
    (share : Nat) (hshare : share < down.d) :
    (registeredCompositeCircuit up ports).gates[boundaryRegister up share]? =
      some { kind := .reg, inputs := [((up.output share).gate, 1)] } := by
  simp only [registeredCompositeCircuit, UniversalSStage1.appendCircuit,
    boundaryRegister, boundaryRegisterGates]
  rw [Array.getElem?_append]
  have hprefix : ¬ up.circuit.gates.size + share < up.circuit.gates.size := by
    omega
  simp only [hprefix, ↓reduceIte, Nat.add_sub_cancel_left]
  rw [Array.getElem?_append]
  simp [hshare]

def boundaryRegisters (up down : GadgetInstance) : List Nat :=
  (List.range down.d).map (boundaryRegister up)

/-- `PortAlignment` turns the generic compiler's register identity into the
intended cross-gadget boundary equation.  This is the value-level N1 fact;
the only remaining side condition is that the aligned cycle lies inside the
compiled execution horizon. -/
theorem registeredComposite_boundary_value {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down)
    (share : Nat) (hshare : share < down.d)
    (halign : PortAlignment up down ports)
    (hwf : (registeredCompositeCircuit up ports).WF)
    (hinside : ports.arrivalCycle < max up.horizon down.horizon)
    (env : Env) :
    Execution.eval (registeredCompositeCircuit up ports)
        (max up.horizon down.horizon) env
        { gate := boundaryRegister up share,
          cycle := ports.arrivalCycle } =
      Execution.eval (registeredCompositeCircuit up ports)
        (max up.horizon down.horizon) env (up.output share) := by
  have hcycle := halign.2.2 share (by simpa using hshare)
  rw [← hcycle]
  exact eval_register_succ (registeredCompositeCircuit up ports)
    (max up.horizon down.horizon) env (up.output share).gate
    (boundaryRegister up share) (up.output share).cycle hwf
    (registeredComposite_boundary_gate up ports share hshare)
    (by simpa [hcycle] using hinside)

abbrev single_read {down : GadgetInstance}
    (ports : RegisterPorts down) : Prop := PortContract ports

/-- Strong source freshness used by the registered splice.  It covers every
source consulted by either isolated evaluator, rather than only the lists
marked as randomness.  The registered compiler namespaces the two sides so
this finite condition is directly checkable. -/
def FullSourceDisjointness (up down : GadgetInstance) : Prop :=
  ∀ src ∈ Execution.relevantSrcs up.circuit up.horizon,
    src ∉ Execution.relevantSrcs down.circuit down.horizon

instance (up down : GadgetInstance) :
    Decidable (FullSourceDisjointness up down) := by
  unfold FullSourceDisjointness
  infer_instance

/-! ## Reset-initialized registers

`fixingForInput` gives declared input arrivals priority over `publicFixing`.
Consequently presence in `publicFixing` alone is not enough to make a source
environment-independent: the same atom must not also be an input or a random
source.  `SourcePinned` records exactly that executable condition.
-/

/-- A source is fixed by the public schedule, with no higher-priority input
or randomness declaration that could make its value environment-dependent. -/
def SourcePinned (g : GadgetInstance) (src : Src) : Prop :=
  (∃ value, Execution.lookupAssoc src g.publicFixing = some value) ∧
    (∀ input ∈ List.range g.inputCount,
      ∀ share ∈ List.range g.d, g.inputArrival input share ≠ src) ∧
    src ∉ g.randomness

instance (g : GadgetInstance) (src : Src) :
    Decidable (SourcePinned g src) := by
  unfold SourcePinned
  infer_instance

/-- Executable check for reset pinning at one gate-array position. -/
def initPinnedAt (g : GadgetInstance) (gate : Nat) : Bool :=
  match g.circuit.gates[gate]? with
  | some { kind := .reg, inputs := _ } =>
      decide (SourcePinned g (.iniReg gate) ∧
        Execution.lookupAssoc (.iniReg gate) g.publicFixing = some false)
  | _ => true

/-- **PINNED-INIT.** Every register in a gadget resets to `false` in the
public schedule.  The additional non-alias clauses are what make that reset
independent of the experiment environment under the frozen fixing
precedence. -/
def PinnedInit (g : GadgetInstance) : Prop :=
  (List.range g.circuit.gates.size).all (initPinnedAt g) = true

instance (g : GadgetInstance) : Decidable (PinnedInit g) := by
  unfold PinnedInit
  infer_instance

/-- The boundary-register part of `PinnedInit`, useful before proving that a
compiler-generated composite has no other unaccounted register indices. -/
def BoundaryPinnedInit (g : GadgetInstance) (registers : List Nat) : Prop :=
  ∀ gate ∈ registers, SourcePinned g (.iniReg gate)

instance (g : GadgetInstance) (registers : List Nat) :
    Decidable (BoundaryPinnedInit g registers) := by
  unfold BoundaryPinnedInit
  infer_instance

/-- Complete structural hypothesis bundle for registered serial composition.
`PortContract` is intentionally absent: under a shared window and a pulsed
upstream boundary, the compiler-created register wire agrees cycle-by-cycle
with the downstream input fixing, so the older downstream live-read contract
has no remaining proof role. -/
structure RegisteredConditions {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down) (t : Nat) : Prop where
  order_lt_shares : t < up.d
  port_alignment : PortAlignment up down ports
  shared_window : SharedWindow up down
  output_pulse : OutputPulse up
  source_disjoint : FullSourceDisjointness up down
  upstream_pinned : PinnedInit up
  downstream_pinned : PinnedInit down
  boundary_pinned : BoundaryPinnedInit (registeredComposite up ports)
    (boundaryRegisters up down)
  upstream_whole_window : WholeWindow up
  downstream_whole_window : WholeWindow down

/-- Exact residual at the audited final bridge.  N1/N2 and the temporal
contracts identify the boundary observations, but `Boundary.lean` still
needs a whole-composite PINI certificate together with its ordinary probing
boundary facts.  No such connected-experiment theorem currently follows
from the constructor equations alone. -/
structure RegisteredAssembly {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down) (t : Nat) : Prop where
  composite_pini :
    piniSpec (registeredComposite up ports) transitionGlitch t
  probing_boundary : ProbingBoundary (registeredComposite up ports) t

/-- The ordinary probing boundary of the registered compiler is structural.
The downstream WF certificate supplies distinct member outputs, while the
standard fixing construction makes every full-input experiment nonempty.
Thus the only non-structural field of `RegisteredAssembly` is composite PINI. -/
theorem registeredComposite_probingBoundary {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down) (t : Nat)
    (horder : t < up.d) (halign : PortAlignment up down ports)
    (hdown : down.WF) :
    ProbingBoundary (registeredComposite up ports) t := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · simpa [registeredComposite] using (halign.1 ▸ horder)
  · intro share hshare
    have hshareDown : share < down.d := by
      simpa [registeredComposite] using hshare
    have houtput : down.output share ∈ outputNodes down := by
      exact List.mem_map.mpr ⟨share, by simpa using hshareDown, rfl⟩
    have hcontains :
        (memberNodes down).contains (down.output share) = true :=
      List.all_eq_true.mp hdown.2.2.2.1 _ houtput
    have hmember : down.output share ∈ memberNodes down := by
      simpa using hcontains
    have hgate : (down.output share).gate < down.circuit.gates.size := by
      have hnode : down.output share ∈ nodes down :=
        (List.mem_filter.mp hmember).1
      rw [nodes, List.mem_flatMap] at hnode
      rcases hnode with ⟨cycle, _hcycle, hnode⟩
      rw [List.mem_map] at hnode
      rcases hnode with ⟨gate, hgate, heq⟩
      simpa [← heq] using hgate
    have hmemberValue : down.member (down.output share) = true :=
      (List.mem_filter.mp hmember).2
    have hprefix :
        ¬ downstreamOffset up down + (down.output share).gate <
          up.circuit.gates.size := by
      unfold downstreamOffset
      omega
    have hregisters :
        ¬ downstreamOffset up down + (down.output share).gate <
          downstreamOffset up down := by omega
    simp [registeredComposite, hprefix, hregisters, hmemberValue]
  · intro i j hi hj heq
    have hiDown : i < down.d := by
      simpa [registeredComposite] using hi
    have hjDown : j < down.d := by
      simpa [registeredComposite] using hj
    have hdownEq : down.output i = down.output j := by
      cases hiout : down.output i with
      | mk igate icycle =>
          cases hjout : down.output j with
          | mk jgate jcycle =>
              simp [registeredComposite, downstreamOffset, hiout, hjout] at heq
              simp [hiout, hjout, heq]
    apply (List.getElem?_inj (l := outputNodes down) (by
      simpa [outputNodes] using hiDown) hdown.2.2.1).mp
    simp only [outputNodes, List.getElem?_map,
      List.getElem?_range hiDown, List.getElem?_range hjDown,
      Option.map_some, hdownEq]
  · intro x _
    exact List.length_pos_iff.mpr
      (envsForInput_ne_nil_of_valid (registeredComposite up ports) x
        (fixingForInput_valid (registeredComposite up ports) x))

/-- Package the now-structural probing boundary with a composite PINI proof.
This exposes the exact remaining Theorem-A obligation without duplicating any
boundary fields at call sites. -/
theorem registeredAssembly_of_pini {down : GadgetInstance}
    (up : GadgetInstance) (ports : RegisterPorts down) (t : Nat)
    (horder : t < up.d) (halign : PortAlignment up down ports)
    (hdown : opiniSpec down transitionGlitch t)
    (hpini : piniSpec (registeredComposite up ports) transitionGlitch t) :
    RegisteredAssembly up ports t := by
  exact ⟨hpini,
    registeredComposite_probingBoundary up ports t horder halign hdown.1⟩

/-- Once the exact registered-assembly residual is supplied, the standard
audited `pini_implies_probing` bridge closes the desired conclusion.  All
Theorem-A premises are retained in the signature to make the unresolved cut
explicit; none is replaced by a probabilistic factorization premise. -/
theorem theoremA_of_registeredAssembly
    (up down : GadgetInstance) (ports : RegisterPorts down) (t : Nat)
    (_horder : t < up.d)
    (_hfresh : FullSourceDisjointness up down)
    (_halign : PortAlignment up down ports)
    (_hupInit : PinnedInit up) (_hdownInit : PinnedInit down)
    (_hboundaryInit : BoundaryPinnedInit (registeredComposite up ports)
      (boundaryRegisters up down))
    (_hup : opiniSpec up transitionGlitch t)
    (_hdown : opiniSpec down transitionGlitch t)
    (hassembly : RegisteredAssembly up ports t) :
    probingSecureSpec (registeredComposite up ports) transitionGlitch t := by
  exact pini_implies_probing (registeredComposite up ports) transitionGlitch t
    hassembly.probing_boundary.order_lt_shares
    hassembly.probing_boundary.outputs_are_members
    hassembly.probing_boundary.outputs_injective
    hassembly.probing_boundary.inputs_reached hassembly.composite_pini

/-- `SourcePinned` has its intended semantic effect on every full-input
experiment: if the source is relevant, the generated fixing contains exactly
the public constant, independently of the input vector. -/
theorem lookupAssoc_fixingForInput_of_sourcePinned
    (g : GadgetInstance) (src : Src) (value : Bool)
    (hpinned : SourcePinned g src)
    (hpublic : Execution.lookupAssoc src g.publicFixing = some value)
    (x : List Bool)
    (hrelevant : src ∈ Execution.relevantSrcs g.circuit g.horizon) :
    Execution.lookupAssoc src (fixingForInput g x) = some value := by
  have hnotArrival :
      src ∉ (List.range g.inputCount).flatMap (fun input =>
        (List.range g.d).map fun share => g.inputArrival input share) := by
    intro hmem
    rw [List.mem_flatMap] at hmem
    rcases hmem with ⟨input, hinput, hshareMem⟩
    rw [List.mem_map] at hshareMem
    rcases hshareMem with ⟨share, hshare, heq⟩
    exact hpinned.2.1 input hinput share hshare heq
  have harrival : arrivalValue? g x src = none := by
    cases hvalue : arrivalValue? g x src with
    | none => rfl
    | some bit =>
        have hisSome : (arrivalValue? g x src).isSome = true := by
          simp [hvalue]
        rw [arrivalValue_isSome] at hisSome
        simp [hnotArrival] at hisSome
  have hmem : (src, value) ∈ fixingForInput g x := by
    unfold fixingForInput
    rw [List.mem_filterMap]
    exact ⟨src, hrelevant, by simp [harrival, hpublic]⟩
  apply lookupAssoc_eq_of_mem_nodup src value (fixingForInput g x) hmem
  rw [fixingForInput_keys]
  exact (Execution.eraseDups_nodup _).filter _

/-! ## The remaining fixed-node interface obstruction

N1 and N2 are true, but `GadgetInstance.output` and `inputArrival` each name
one cycle-indexed object.  They do not assert that every other cycle of the
same gate is an output/input port.  The following tiny pair demonstrates that
a stream-delaying boundary register cannot manufacture that missing temporal
port contract.
-/

def registeredMismatchUpCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] }
    ] }

def registeredMismatchUp : GadgetInstance :=
  { circuit := registeredMismatchUpCircuit
    horizon := 3
    d := 2
    inputCount := 3
    inputArrival := fun input share => .inp 0 share input
    output := fun share =>
      if share = 0 then { gate := 0, cycle := 1 }
      else { gate := 1, cycle := 1 }
    member := fun node => node.gate < 2 && node.cycle < 3
    randomness := [] }

def registeredMismatchDownCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (1, 0)] },
      { kind := .const false, inputs := [] }
    ] }

/-- The declared input arrives at cycle one, while this legal gadget boundary
contains the consumer only at cycle two.  Current `GadgetInstance.WF` does not
relate those two declarations. -/
def registeredMismatchDown : GadgetInstance :=
  { circuit := registeredMismatchDownCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 1
    output := fun share =>
      if share = 0 then { gate := 2, cycle := 2 }
      else { gate := 3, cycle := 2 }
    member := fun node => node.cycle == 2 && node.gate < 4
    randomness := [] }

def registeredMismatchPorts : RegisterPorts registeredMismatchDown where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 4
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

/-- The old fixed-node witness is rejected by exactly the new temporal
precondition: its only live reads occur at cycle two, while the declared
input arrival is cycle one. -/
theorem registeredMismatch_violates_PortContract :
    ¬ PortContract registeredMismatchPorts := by
  decide

/-- Literal `upstream ++ boundary registers ++ downstream` construction.
The downstream source identifiers use the odd namespace and the connected XOR
edges are redirected to the two register-output gates. -/
def registeredMismatchCompositeCircuit : Circuit :=
  { gates := #[
      Universal.namespaceGate false
        { kind := .inp 0 0, inputs := [] },
      Universal.namespaceGate false
        { kind := .inp 0 1, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .reg, inputs := [(1, 1)] },
      Universal.namespaceGate true
        { kind := .inp 0 0, inputs := [] },
      Universal.namespaceGate true
        { kind := .inp 0 1, inputs := [] },
      { kind := .xor, inputs := [(2, 0), (3, 0)] },
      { kind := .const false, inputs := [] }
    ] }

def registeredMismatchComposite : GadgetInstance :=
  { circuit := registeredMismatchCompositeCircuit
    horizon := 3
    d := 2
    inputCount := 3
    inputArrival := fun input share =>
      Universal.namespaceSrc false (.inp 0 share input)
    output := fun share =>
      if share = 0 then { gate := 6, cycle := 2 }
      else { gate := 7, cycle := 2 }
    member := fun node =>
      (node.gate < 4 && node.cycle < 3) ||
        (node.cycle == 2 && node.gate < 8)
    randomness := [] }

theorem registeredMismatchUp_wf : registeredMismatchUp.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [registeredMismatchUp, registeredMismatchUpCircuit, Circuit.WF,
    Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
    Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred]

theorem registeredMismatchDown_wf : registeredMismatchDown.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [registeredMismatchDown, registeredMismatchDownCircuit, Circuit.WF,
    Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
    Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred]

theorem registeredMismatchComposite_wf : registeredMismatchComposite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [registeredMismatchComposite, registeredMismatchCompositeCircuit,
    Universal.namespaceGate, Universal.namespaceGateKind,
    Universal.namespaceGateIndex, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

private theorem registeredMismatch_inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

theorem registeredMismatchUp_opini :
    opiniSpec registeredMismatchUp transitionGlitch 1 := by
  apply (opini_iff_spec registeredMismatchUp transitionGlitch 1
    (registeredMismatch_inputs_reached registeredMismatchUp)).mp
  exact ⟨registeredMismatchUp_wf, by
    set_option maxRecDepth 10000 in
      decide⟩

theorem registeredMismatchDown_opini :
    opiniSpec registeredMismatchDown transitionGlitch 1 := by
  apply (opini_iff_spec registeredMismatchDown transitionGlitch 1
    (registeredMismatch_inputs_reached registeredMismatchDown)).mp
  exact ⟨registeredMismatchDown_wf, by decide⟩

private theorem registeredMismatchComposite_secrets_reached :
    ∀ secret ∈ boolVectors registeredMismatchComposite.inputCount,
      (envsForSecret registeredMismatchComposite secret).length > 0 := by
  intro secret hsecret
  let x := secret.flatMap fun bit => [bit, false]
  have hx : x ∈ boolVectors (inputWidth registeredMismatchComposite) := by
    simp [x, registeredMismatchComposite, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
      decide
  have hsecrets : secretsOf registeredMismatchComposite x = secret := by
    simp [x, registeredMismatchComposite, secretsOf, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
      decide
  exact List.length_pos_iff.mpr
    (envsForSecret_ne_nil_of_input registeredMismatchComposite secret x hx
      hsecrets (envsForInput_ne_nil_of_valid registeredMismatchComposite x
        (fixingForInput_valid registeredMismatchComposite x)))

/-- The boundary layer is genuinely live in the N1 regime: at cycle two its
two outputs are exactly the two upstream output shares from cycle one. -/
theorem registeredMismatch_boundary_values (env : Env) :
    Execution.eval registeredMismatchCompositeCircuit 3 env
        { gate := 2, cycle := 2 } =
      Execution.eval registeredMismatchCompositeCircuit 3 env
        { gate := 0, cycle := 1 } ∧
    Execution.eval registeredMismatchCompositeCircuit 3 env
        { gate := 3, cycle := 2 } =
      Execution.eval registeredMismatchCompositeCircuit 3 env
        { gate := 1, cycle := 1 } := by
  have hwf : registeredMismatchCompositeCircuit.WF :=
    registeredMismatchComposite_wf.1
  constructor
  · exact eval_register_succ registeredMismatchCompositeCircuit 3 env
      0 2 1 hwf rfl (by decide)
  · exact eval_register_succ registeredMismatchCompositeCircuit 3 env
      1 3 1 hwf rfl (by decide)

/-- Despite both components being order-one O-PINI and despite the live
boundary satisfying N1/N2, one glitch-extended downstream XOR probe exposes
both registered shares of the designated upstream cycle-one output. -/
theorem registeredMismatchComposite_not_probing :
    ¬ probingSecureSpec registeredMismatchComposite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure registeredMismatchComposite
      transitionGlitch 1 :=
    (probingSecure_iff_spec registeredMismatchComposite transitionGlitch 1
      registeredMismatchComposite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast registeredMismatchComposite
      transitionGlitch 1 :=
    (probingSecureFast_iff registeredMismatchComposite transitionGlitch 1
      registeredMismatchComposite_secrets_reached).mpr hexecutable
  exact (by decide : ¬ probingSecureFast registeredMismatchComposite
    transitionGlitch 1) hfast

/-- Precise obstruction to the requested unrestricted general theorem. -/
theorem boundary_registers_do_not_close_fixed_node_interface :
    registeredMismatchUp.horizon ≥ 2 ∧
    registeredMismatchDown.horizon ≥ 2 ∧
    registeredMismatchUp.d = registeredMismatchDown.d ∧
    1 < registeredMismatchUp.d ∧
    opiniSpec registeredMismatchUp transitionGlitch 1 ∧
    opiniSpec registeredMismatchDown transitionGlitch 1 ∧
    registeredMismatchComposite.WF ∧
    ¬ probingSecureSpec registeredMismatchComposite transitionGlitch 1 := by
  exact ⟨by decide, by decide, rfl, by decide,
    registeredMismatchUp_opini, registeredMismatchDown_opini,
    registeredMismatchComposite_wf,
    registeredMismatchComposite_not_probing⟩

/-! ## Boundary-initialization freshness obstruction

`FullSourceDisjointness` compares the source supports of the two *isolated*
circuits.  It does not cover a source which is merely declared by an input
port and becomes relevant only after a boundary register is inserted.  The
closed example below satisfies `PortContract`: its sole downstream reads are
at the declared arrival cycle.  Nevertheless, the upstream's second input
share is declared at the initial source of the newly inserted first register.
One transition probe on that register therefore reveals both shares.
-/

namespace InitCollision

def upstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .const false, inputs := [] }
    ] }

/-- Share zero is used by the isolated circuit.  Share one is a legal declared
input arrival which is outside that circuit's isolated source support. -/
def upstream : GadgetInstance :=
  { circuit := upstreamCircuit
    horizon := 2
    d := 2
    inputCount := 1
    inputArrival := fun _ share =>
      if share = 0 then .inp 0 0 0 else .iniReg 2
    output := fun share =>
      if share = 0 then { gate := 0, cycle := 0 }
      else { gate := 1, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 2
    randomness := [] }

def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 10 0, inputs := [] },
      { kind := .inp 10 1, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (2, 0)] }
    ] }

def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 2
    d := 2
    inputCount := 1
    inputArrival := fun input share =>
      if input = 0 then .inp 10 share 1
      else if share = 0 then .inp 0 0 2 else .inp 0 1 4
    output := fun share =>
      if share = 0 then { gate := 3, cycle := 1 }
      else { gate := 4, cycle := 1 }
    member := fun node => node.cycle == 1 && node.gate < 5
    randomness := [] }

def ports : RegisterPorts downstream where
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
    · exact ⟨10, rfl, rfl⟩
    · exact ⟨10, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

theorem portContract : PortContract ports := by
  decide

theorem fullSourceDisjointness :
    FullSourceDisjointness upstream downstream := by
  decide

/-- The collision witness cannot satisfy environment-independent reset
pinning: its second declared input aliases the first boundary register's
`.iniReg` source. -/
theorem boundaryInit_not_pinnable :
    ¬ SourcePinned upstream (.iniReg 2) := by
  decide

/-- Literal prefix, two latency-one registers, and downstream suffix.  The
connected input gates are dead constants and the two live reads are redirected
to the corresponding register outputs. -/
def compositeCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .reg, inputs := [(1, 1)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(2, 0), (6, 0)] },
      { kind := .xor, inputs := [(3, 0), (6, 0)] }
    ] }

def composite : GadgetInstance :=
  { circuit := compositeCircuit
    horizon := 2
    d := 2
    inputCount := 1
    inputArrival := fun input share =>
      if input < upstream.inputCount then upstream.inputArrival input share
      else shiftDownSrc upstream downstream <|
        downstream.inputArrival
          (unhideRegisteredInput ports.downstreamInput
            (input - upstream.inputCount)) share
    output := fun share =>
      if share = 0 then { gate := 7, cycle := 1 }
      else { gate := 8, cycle := 1 }
    member := fun node =>
      (node.cycle == 0 && node.gate < 2) ||
      ((node.gate == 2 || node.gate == 3) && node.cycle < 2) ||
      (node.cycle == 1 && 4 ≤ node.gate && node.gate < 9)
    randomness := [] }

theorem upstream_wf : upstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [upstream, upstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem downstream_wf : downstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [downstream, downstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem composite_wf : composite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [composite, compositeCircuit, upstream, Circuit.WF,
    Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
    Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred]

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

theorem upstream_opini : opiniSpec upstream transitionGlitch 1 := by
  apply (opini_iff_spec upstream transitionGlitch 1
    (inputs_reached upstream)).mp
  exact ⟨upstream_wf, by decide⟩

theorem downstream_opini : opiniSpec downstream transitionGlitch 1 := by
  apply (opini_iff_spec downstream transitionGlitch 1
    (inputs_reached downstream)).mp
  exact ⟨downstream_wf, by decide⟩

private theorem composite_secrets_reached :
    ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
  intro secret hsecret
  let x := secret.flatMap fun bit => [bit, false]
  have hx : x ∈ boolVectors (inputWidth composite) := by
    simp [x, composite, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl <;> decide
  have hsecrets : secretsOf composite x = secret := by
    simp [x, composite, secretsOf, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl <;> decide
  exact List.length_pos_iff.mpr
    (envsForSecret_ne_nil_of_input composite secret x hx hsecrets
      (envsForInput_ne_nil_of_valid composite x
        (fixingForInput_valid composite x)))

/-- The collision is outside the isolated upstream support but becomes the
initial source of boundary register gate two in the composite. -/
theorem declared_input_becomes_boundary_initial_source :
    upstream.inputArrival 0 1 = .iniReg 2 ∧
      .iniReg 2 ∉ Execution.relevantSrcs upstream.circuit upstream.horizon ∧
      .iniReg 2 ∈ Execution.relevantSrcs composite.circuit composite.horizon := by
  decide

/-- Both registers carry the advertised upstream outputs at cycle one; the
counterexample is genuine registered wiring rather than static glue. -/
theorem boundary_values (env : Env) :
    Execution.eval compositeCircuit 2 env { gate := 2, cycle := 1 } =
        Execution.eval compositeCircuit 2 env { gate := 0, cycle := 0 } ∧
      Execution.eval compositeCircuit 2 env { gate := 3, cycle := 1 } =
        Execution.eval compositeCircuit 2 env { gate := 1, cycle := 0 } := by
  constructor
  · exact eval_register_succ compositeCircuit 2 env 0 2 0 composite_wf.1
      rfl (by decide)
  · exact eval_register_succ compositeCircuit 2 env 1 3 0 composite_wf.1
      rfl (by decide)

/-- One transition probe at the first boundary register sees its initial
value (input share one) and its loaded value (input share zero). -/
theorem composite_not_probing :
    ¬ probingSecureSpec composite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure composite transitionGlitch 1 :=
    (probingSecure_iff_spec composite transitionGlitch 1
      composite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast composite transitionGlitch 1 :=
    (probingSecureFast_iff composite transitionGlitch 1
      composite_secrets_reached).mpr hexecutable
  exact (by decide : ¬ probingSecureFast composite transitionGlitch 1) hfast

/-- Closed refutation of the proposed premise set.  Temporal port fidelity
and isolated-source disjointness do not ensure freshness of the sources
created by the register layer. -/
theorem stated_preconditions_do_not_imply_registered_security :
    PortContract ports ∧
      FullSourceDisjointness upstream downstream ∧
      upstream.d = downstream.d ∧
      1 < upstream.d ∧
      opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      composite.WF ∧
      composite.circuit.gates[2]? =
        some { kind := .reg, inputs := [(0, 1)] } ∧
      composite.circuit.gates[3]? =
        some { kind := .reg, inputs := [(1, 1)] } ∧
      (∀ env,
        Execution.eval compositeCircuit 2 env { gate := 2, cycle := 1 } =
            Execution.eval compositeCircuit 2 env { gate := 0, cycle := 0 } ∧
          Execution.eval compositeCircuit 2 env { gate := 3, cycle := 1 } =
            Execution.eval compositeCircuit 2 env { gate := 1, cycle := 0 }) ∧
      ¬ probingSecureSpec composite transitionGlitch 1 := by
  exact ⟨portContract, fullSourceDisjointness, rfl, by decide,
    upstream_opini, downstream_opini, composite_wf, rfl, rfl,
    boundary_values, composite_not_probing⟩

end InitCollision

/-! ## Upstream port-cycle alignment control

`PortContract` fixes the cycle of every downstream read, but the current
`RegisterPorts` data is indexed only by `down`: it cannot state that the
register input at the preceding cycle is the node declared by `up.output`.
The closed control below isolates that missing half of the port contract.
All register initial values are publicly pinned and all source namespaces are
disjoint.  Nevertheless the register reads the upstream output *gate* at a
different cycle, outside the isolated upstream member boundary, where that
gate recombines both input shares.
-/

namespace PortAlignment

def upstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (1, 0)] },
      { kind := .const false, inputs := [] }
    ] }

/-- The declared output is at cycle zero, where the cycle-one input sharing
is not live and the two output shares are constants.  The same output gate at
cycle one recombines the secret, but is outside this component's boundary. -/
def upstream : GadgetInstance :=
  { circuit := upstreamCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 1
    output := fun share =>
      if share = 0 then { gate := 2, cycle := 0 }
      else { gate := 3, cycle := 0 }
    member := fun node => node.cycle == 0 && node.gate < 4
    randomness := [] }

def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 10 0, inputs := [] },
      { kind := .inp 10 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (4, 0)] },
      { kind := .xor, inputs := [(1, 0), (4, 0)] },
      { kind := .const false, inputs := [] }
    ] }

/-- Each downstream output depends on only one connected share, and every
live read occurs at its declared cycle two. -/
def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 10 share 2
    output := fun share =>
      if share = 0 then { gate := 2, cycle := 2 }
      else { gate := 3, cycle := 2 }
    member := fun node => node.cycle == 2 && node.gate < 5
    randomness := [] }

def ports : RegisterPorts downstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 5
    omega
  arrivalCycle := 2
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨10, rfl, rfl⟩
    · exact ⟨10, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

def compositeCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (1, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .reg, inputs := [(2, 1)] },
      { kind := .reg, inputs := [(3, 1)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .xor, inputs := [(4, 0), (10, 0)] },
      { kind := .xor, inputs := [(5, 0), (10, 0)] },
      { kind := .const false, inputs := [] }
    ] }

/-- Literal prefix, two pinned latency-one registers, and a downstream suffix
whose connected input edges are redirected to the register outputs. -/
def composite : GadgetInstance :=
  { circuit := compositeCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := upstream.inputArrival
    output := fun share =>
      if share = 0 then { gate := 8, cycle := 2 }
      else { gate := 9, cycle := 2 }
    member := fun node =>
      (node.cycle < 2 && node.gate < 4) ||
      (node.cycle == 2 && 4 ≤ node.gate && node.gate < 11)
    randomness := []
    publicFixing := [(.iniReg 4, false), (.iniReg 5, false)] }

theorem upstream_wf : upstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [upstream, upstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem downstream_wf : downstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [downstream, downstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem composite_wf : composite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [composite, compositeCircuit, upstream, Circuit.WF,
    Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
    Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred]

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

theorem upstream_opini : opiniSpec upstream transitionGlitch 1 := by
  apply (opini_iff_spec upstream transitionGlitch 1
    (inputs_reached upstream)).mp
  exact ⟨upstream_wf, by decide⟩

theorem downstream_opini : opiniSpec downstream transitionGlitch 1 := by
  apply (opini_iff_spec downstream transitionGlitch 1
    (inputs_reached downstream)).mp
  exact ⟨downstream_wf, by decide⟩

theorem portContract : PortContract ports := by
  decide

theorem fullSourceDisjointness :
    FullSourceDisjointness upstream downstream := by
  decide

theorem upstream_pinnedInit : PinnedInit upstream := by
  decide

theorem downstream_pinnedInit : PinnedInit downstream := by
  decide

theorem boundary_pinnedInit : BoundaryPinnedInit composite [4, 5] := by
  decide

/-- Every register in the counterexample composite is reset-pinned.  This is
strictly stronger than checking the compiler-created register list. -/
theorem composite_pinnedInit : PinnedInit composite := by
  decide

private theorem composite_secrets_reached :
    ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
  intro secret hsecret
  let x := secret.flatMap fun bit => [bit, false]
  have hx : x ∈ boolVectors (inputWidth composite) := by
    simp [x, composite, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl <;> decide
  have hsecrets : secretsOf composite x = secret := by
    simp [x, composite, secretsOf, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl <;> decide
  exact List.length_pos_iff.mpr
    (envsForSecret_ne_nil_of_input composite secret x hx hsecrets
      (envsForInput_ne_nil_of_valid composite x
        (fixingForInput_valid composite x)))

/-- The first boundary register is reset-pinned, but at cycle two it loads the
cycle-one value of upstream gate two, not the declared cycle-zero output. -/
theorem boundary_reads_undeclared_upstream_cycle (env : Env) :
    Execution.eval compositeCircuit 3 env { gate := 4, cycle := 2 } =
      Execution.eval compositeCircuit 3 env { gate := 2, cycle := 1 } := by
  exact eval_register_succ compositeCircuit 3 env 2 4 1 composite_wf.1
    rfl (by decide)

theorem composite_not_probing :
    ¬ probingSecureSpec composite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure composite transitionGlitch 1 :=
    (probingSecure_iff_spec composite transitionGlitch 1
      composite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast composite transitionGlitch 1 :=
    (probingSecureFast_iff composite transitionGlitch 1
      composite_secrets_reached).mpr hexecutable
  exact (by decide : ¬ probingSecureFast composite transitionGlitch 1) hfast

/-- Kernel-closed refutation of the literal requested premise set.  The
failure is not an initialization collision: both new `.iniReg` atoms are
public constants and cannot alias an input or random source. -/
theorem pinnedInit_preconditions_do_not_imply_registered_security :
    PortContract ports ∧
      FullSourceDisjointness upstream downstream ∧
      PinnedInit upstream ∧
      PinnedInit downstream ∧
      BoundaryPinnedInit composite [4, 5] ∧
      PinnedInit composite ∧
      upstream.d = downstream.d ∧
      1 < upstream.d ∧
      opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      composite.WF ∧
      (∀ env, Execution.eval compositeCircuit 3 env
        { gate := 4, cycle := 2 } =
          Execution.eval compositeCircuit 3 env { gate := 2, cycle := 1 }) ∧
      ¬ probingSecureSpec composite transitionGlitch 1 := by
  exact ⟨portContract, fullSourceDisjointness, upstream_pinnedInit,
    downstream_pinnedInit, boundary_pinnedInit, composite_pinnedInit,
    rfl, by decide,
    upstream_opini, downstream_opini, composite_wf,
    boundary_reads_undeclared_upstream_cycle, composite_not_probing⟩

/-- The current downstream-only port contract does not imply the boundary
register's required upstream cycle equation.  This is a type-level limitation:
`RegisterPorts downstream` contains no `upstream` value to which its arrival
cycle could be related. -/
theorem portContract_does_not_imply_upstream_alignment :
    PortContract ports ∧
      ¬ (∀ share, share < upstream.d →
        ports.arrivalCycle = (upstream.output share).cycle + 1) := by
  refine ⟨portContract, ?_⟩
  intro haligned
  have h := haligned 0 (by decide)
  have : (2 : Nat) = 1 := by
    simpa [ports, upstream] using h
  omega

/-- Exact counterexample to the condition bundle after adding the standard
strict masking-order bound.  Thus `t < d` removes the full-share-order witness
but cannot close Theorem A against the present `RegisterPorts`/`PortContract`
interface: all listed conditions hold here at `t = 1 < d = 2`, while the
literal pinned registered composite is not probing secure. -/
theorem strict_order_condition_bundle_still_insufficient :
    PortContract ports ∧
      FullSourceDisjointness upstream downstream ∧
      PinnedInit upstream ∧
      PinnedInit downstream ∧
      BoundaryPinnedInit composite [4, 5] ∧
      1 < upstream.d ∧
      opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      composite.WF ∧
      ¬ probingSecureSpec composite transitionGlitch 1 := by
  exact ⟨portContract, fullSourceDisjointness, upstream_pinnedInit,
    downstream_pinnedInit, boundary_pinnedInit, by decide, upstream_opini,
    downstream_opini, composite_wf, composite_not_probing⟩

end PortAlignment

/-! ## Shared-window necessity (6a)

Without a common horizon, distinct upstream output-share gates can pulse only
after the upstream certificate's window.  Different downstream delays then
realign those shares inside the longer composite execution, where one glitch
cone exposes the complete sharing. -/

namespace PostWindow

def upstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] }
    ] }

def upstream : GadgetInstance :=
  { circuit := upstreamCircuit
    horizon := 2
    d := 2
    inputCount := 1
    inputArrival := fun _ share =>
      if share = 0 then .inp 0 0 2 else .inp 0 1 4
    output := fun share =>
      if share = 0 then { gate := 0, cycle := 0 }
      else { gate := 1, cycle := 0 }
    member := fun _ => true
    randomness := [] }

def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 10 0, inputs := [] },
      { kind := .inp 10 1, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .reg, inputs := [(2, 1)] },
      { kind := .xor, inputs := [(3, 0), (1, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] }
    ] }

def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 6
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 10 share 1
    output := fun share =>
      if share = 0 then { gate := 5, cycle := 5 }
      else { gate := 6, cycle := 5 }
    member := fun _ => true
    randomness := []
    publicFixing := [(.iniReg 2, false), (.iniReg 3, false)] }

def ports : RegisterPorts downstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 8
    omega
  arrivalCycle := 1
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨10, rfl, rfl⟩
    · exact ⟨10, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

def compositeCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .reg, inputs := [(1, 1)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .reg, inputs := [(2, 1)] },
      { kind := .reg, inputs := [(6, 1)] },
      { kind := .xor, inputs := [(7, 0), (3, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] }
    ] }

def composite : GadgetInstance :=
  { circuit := compositeCircuit
    horizon := 6
    d := 2
    inputCount := 1
    inputArrival := fun input share =>
      if input < upstream.inputCount then upstream.inputArrival input share
      else
        shiftDownSrc upstream downstream <|
          downstream.inputArrival
            (unhideRegisteredInput ports.downstreamInput
              (input - upstream.inputCount)) share
    output := fun share =>
      if share = 0 then { gate := 9, cycle := 5 }
      else { gate := 10, cycle := 5 }
    member := fun _ => true
    randomness := []
    publicFixing := [(.iniReg 6, false), (.iniReg 7, false),
      (.iniReg 2, false), (.iniReg 3, false)] }

set_option maxHeartbeats 1000000 in
theorem registeredComposite_eq :
    registeredComposite upstream ports = composite := by
  unfold registeredComposite composite
  congr 1
  · simp only [registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, compositeCircuit, Circuit.mk.injEq]
    simp [upstream, upstreamCircuit, downstream, downstreamCircuit, ports,
      boundaryRegisterGates, registeredDownGates, wireRegisteredDownGate,
      wireRegisteredEdge, connectedShare?, boundaryRegister, downstreamOffset]
    decide
  · funext share
    by_cases hshare : share = 0 <;>
      simp [upstream, downstream, downstreamOffset, upstreamCircuit, hshare]

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

theorem upstream_wf : upstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [upstream, upstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem downstream_wf : downstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [downstream, downstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem composite_wf : composite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [composite, compositeCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem upstream_opini : opiniSpec upstream transitionGlitch 1 := by
  apply (opini_iff_spec upstream transitionGlitch 1
    (inputs_reached upstream)).mp
  exact ⟨upstream_wf, by decide⟩

set_option maxHeartbeats 1000000 in
theorem downstream_opini : opiniSpec downstream transitionGlitch 1 := by
  apply (opini_iff_spec downstream transitionGlitch 1
    (inputs_reached downstream)).mp
  exact ⟨downstream_wf, by decide⟩

private theorem composite_secrets_reached :
    ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
  intro secret hsecret
  have hs : secret = [false] ∨ secret = [true] := by
    simpa [composite, boolVectors] using hsecret
  rcases hs with rfl | rfl
  · exact List.length_pos_iff.mpr
      (envsForSecret_ne_nil_of_input composite [false] [false, false]
        (by decide) (by decide)
        (envsForInput_ne_nil_of_valid composite [false, false]
          (fixingForInput_valid composite [false, false])))
  · exact List.length_pos_iff.mpr
      (envsForSecret_ne_nil_of_input composite [true] [true, false]
        (by decide) (by decide)
        (envsForInput_ne_nil_of_valid composite [true, false]
          (fixingForInput_valid composite [true, false])))

set_option maxHeartbeats 1000000 in
theorem composite_not_probing :
    ¬ probingSecureSpec composite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure composite transitionGlitch 1 :=
    (probingSecure_iff_spec composite transitionGlitch 1
      composite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast composite transitionGlitch 1 :=
    (probingSecureFast_iff composite transitionGlitch 1
      composite_secrets_reached).mpr hexecutable
  exact (by decide :
    ¬ probingSecureFast composite transitionGlitch 1) hfast

/-- Kernel-closed 6a control: every strengthened premise other than the
shared horizon holds, including the component-local pulse check. -/
theorem sharedWindow_is_necessary :
    1 < upstream.d ∧
      PortAlignment upstream downstream ports ∧
      ¬ SharedWindow upstream downstream ∧
      OutputPulse upstream ∧
      WholeWindow upstream ∧ WholeWindow downstream ∧
      FullSourceDisjointness upstream downstream ∧
      PinnedInit upstream ∧ PinnedInit downstream ∧
      BoundaryPinnedInit composite (boundaryRegisters upstream downstream) ∧
      opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      composite.WF ∧
      registeredComposite upstream ports = composite ∧
      ¬ probingSecureSpec composite transitionGlitch 1 := by
  exact ⟨by decide, by decide, by decide, by decide, by decide, by decide,
    by decide, by decide, by decide, by decide, upstream_opini,
    downstream_opini, composite_wf, registeredComposite_eq,
    composite_not_probing⟩

end PostWindow

/-! ## Output-pulse necessity (6b)

Even on a shared clock, a boundary register retains an upstream output's
off-cycle history.  A downstream register can delay that history once more,
and a transition-glitch companion can expose both delayed shares through one
combinational cone.  The isolated downstream certificate sees only its
declared input pulse, so no condition local to the downstream wiring rules out
this capture. -/

namespace DeepHistory

def upstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] }
    ] }

def upstream : GadgetInstance :=
  { circuit := upstreamCircuit
    horizon := 4
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share =>
      if share = 0 then { gate := 0, cycle := 2 }
      else { gate := 1, cycle := 2 }
    member := fun _ => true
    randomness := [] }

def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 10 0, inputs := [] },
      { kind := .inp 10 1, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .reg, inputs := [(1, 1)] },
      { kind := .xor, inputs := [(2, 0), (3, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] }
    ] }

def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 4
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 10 share 3
    output := fun share =>
      if share = 0 then { gate := 5, cycle := 2 }
      else { gate := 6, cycle := 2 }
    member := fun _ => true
    randomness := []
    publicFixing := [(.iniReg 2, false), (.iniReg 3, false)] }

def ports : RegisterPorts downstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 7
    omega
  arrivalCycle := 3
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨10, rfl, rfl⟩
    · exact ⟨10, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

def compositeCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .reg, inputs := [(1, 1)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .reg, inputs := [(2, 1)] },
      { kind := .reg, inputs := [(3, 1)] },
      { kind := .xor, inputs := [(6, 0), (7, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] }
    ] }

def composite : GadgetInstance :=
  { circuit := compositeCircuit
    horizon := 4
    d := 2
    inputCount := 1
    inputArrival := fun input share =>
      if input < upstream.inputCount then upstream.inputArrival input share
      else
        shiftDownSrc upstream downstream <|
          downstream.inputArrival
            (unhideRegisteredInput ports.downstreamInput
              (input - upstream.inputCount)) share
    output := fun share =>
      if share = 0 then { gate := 9, cycle := 2 }
      else { gate := 10, cycle := 2 }
    member := fun _ => true
    randomness := []
    publicFixing := [(.iniReg 6, false), (.iniReg 7, false),
      (.iniReg 2, false), (.iniReg 3, false)] }

set_option maxHeartbeats 1000000 in
theorem registeredComposite_eq :
    registeredComposite upstream ports = composite := by
  unfold registeredComposite composite
  congr 1
  · simp only [registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, compositeCircuit, Circuit.mk.injEq]
    simp [upstream, upstreamCircuit, downstream, downstreamCircuit, ports,
      boundaryRegisterGates, registeredDownGates, wireRegisteredDownGate,
      wireRegisteredEdge, connectedShare?, boundaryRegister, downstreamOffset]
    decide
  · funext share
    by_cases hshare : share = 0 <;>
      simp [upstream, downstream, downstreamOffset, upstreamCircuit, hshare]

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

theorem upstream_wf : upstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [upstream, upstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem downstream_wf : downstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [downstream, downstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem composite_wf : composite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [composite, compositeCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem upstream_opini : opiniSpec upstream transitionGlitch 1 := by
  apply (opini_iff_spec upstream transitionGlitch 1
    (inputs_reached upstream)).mp
  exact ⟨upstream_wf, by decide⟩

set_option maxHeartbeats 1000000 in
theorem downstream_opini : opiniSpec downstream transitionGlitch 1 := by
  apply (opini_iff_spec downstream transitionGlitch 1
    (inputs_reached downstream)).mp
  exact ⟨downstream_wf, by decide⟩

private theorem composite_secrets_reached :
    ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
  intro secret hsecret
  have hs : secret = [false] ∨ secret = [true] := by
    simpa [composite, boolVectors] using hsecret
  rcases hs with rfl | rfl
  · exact List.length_pos_iff.mpr
      (envsForSecret_ne_nil_of_input composite [false] [false, false]
        (by decide) (by decide)
        (envsForInput_ne_nil_of_valid composite [false, false]
          (fixingForInput_valid composite [false, false])))
  · exact List.length_pos_iff.mpr
      (envsForSecret_ne_nil_of_input composite [true] [true, false]
        (by decide) (by decide)
        (envsForInput_ne_nil_of_valid composite [true, false]
          (fixingForInput_valid composite [true, false])))

set_option maxHeartbeats 1000000 in
theorem composite_not_probing :
    ¬ probingSecureSpec composite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure composite transitionGlitch 1 :=
    (probingSecure_iff_spec composite transitionGlitch 1
      composite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast composite transitionGlitch 1 :=
    (probingSecureFast_iff composite transitionGlitch 1
      composite_secrets_reached).mpr hexecutable
  exact (by decide :
    ¬ probingSecureFast composite transitionGlitch 1) hfast

/-- Kernel-closed 6b control: every strengthened premise other than the
component-local pulse property holds on one shared execution window. -/
theorem outputPulse_is_necessary :
    1 < upstream.d ∧
      PortAlignment upstream downstream ports ∧
      SharedWindow upstream downstream ∧
      ¬ OutputPulse upstream ∧
      WholeWindow upstream ∧ WholeWindow downstream ∧
      FullSourceDisjointness upstream downstream ∧
      PinnedInit upstream ∧ PinnedInit downstream ∧
      BoundaryPinnedInit composite (boundaryRegisters upstream downstream) ∧
      opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      composite.WF ∧
      registeredComposite upstream ports = composite ∧
      ¬ probingSecureSpec composite transitionGlitch 1 := by
  exact ⟨by decide, by decide, by decide, by decide, by decide, by decide,
    by decide, by decide, by decide, by decide, upstream_opini,
    downstream_opini, composite_wf, registeredComposite_eq,
    composite_not_probing⟩

end DeepHistory

/-! ## Connected-source alias obstruction

The strengthened temporal conditions do not require the hidden connected
input's source atoms to be disjoint from the downstream inputs which remain
external after compilation.  The isolated downstream experiment therefore
identifies the two inputs, while the registered compiler separates them into
a boundary-register wire and an external source wire.  This is independent
of off-cycle behavior: the upstream outputs below are genuine single pulses. -/

namespace InputAlias

def upstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] }
    ] }

def upstream : GadgetInstance :=
  { circuit := upstreamCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share =>
      if share = 0 then { gate := 0, cycle := 0 }
      else { gate := 1, cycle := 0 }
    member := fun _ => true
    randomness := [] }

def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 10 0, inputs := [] },
      { kind := .inp 10 1, inputs := [] },
      { kind := .inp 10 0, inputs := [] },
      { kind := .inp 10 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (3, 0)] },
      { kind := .reg, inputs := [(4, 1)] },
      { kind := .reg, inputs := [(5, 1)] },
      { kind := .xor, inputs := [(6, 0), (7, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] }
    ] }

/-- Inputs zero and one deliberately name the same source atoms.  In the
isolated execution each per-share XOR is therefore identically false. -/
def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 3
    d := 2
    inputCount := 2
    inputArrival := fun _ share => .inp 10 share 1
    output := fun share =>
      if share = 0 then { gate := 9, cycle := 2 }
      else { gate := 10, cycle := 2 }
    member := fun _ => true
    randomness := []
    publicFixing := [(.iniReg 6, false), (.iniReg 7, false)] }

def ports : RegisterPorts downstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 11
    omega
  arrivalCycle := 1
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨10, rfl, rfl⟩
    · exact ⟨10, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

def compositeCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .reg, inputs := [(1, 1)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .inp 10 0, inputs := [] },
      { kind := .inp 10 1, inputs := [] },
      { kind := .xor, inputs := [(2, 0), (6, 0)] },
      { kind := .xor, inputs := [(3, 0), (7, 0)] },
      { kind := .reg, inputs := [(8, 1)] },
      { kind := .reg, inputs := [(9, 1)] },
      { kind := .xor, inputs := [(10, 0), (11, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] }
    ] }

def composite : GadgetInstance :=
  { circuit := compositeCircuit
    horizon := 3
    d := 2
    inputCount := 2
    inputArrival := fun input share =>
      if input < upstream.inputCount then upstream.inputArrival input share
      else
        shiftDownSrc upstream downstream <|
          downstream.inputArrival
            (unhideRegisteredInput ports.downstreamInput
              (input - upstream.inputCount)) share
    output := fun share =>
      if share = 0 then { gate := 13, cycle := 2 }
      else { gate := 14, cycle := 2 }
    member := fun _ => true
    randomness := []
    publicFixing := [(.iniReg 10, false), (.iniReg 11, false),
      (.iniReg 2, false), (.iniReg 3, false)] }

set_option maxHeartbeats 2000000 in
theorem registeredComposite_eq :
    registeredComposite upstream ports = composite := by
  unfold registeredComposite composite
  congr 1
  · simp only [registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, compositeCircuit, Circuit.mk.injEq]
    simp [upstream, upstreamCircuit, downstream, downstreamCircuit, ports,
      boundaryRegisterGates, registeredDownGates, wireRegisteredDownGate,
      wireRegisteredEdge, connectedShare?, boundaryRegister, downstreamOffset]
    decide
  · funext share
    by_cases hshare : share = 0 <;>
      simp [upstream, downstream, downstreamOffset, upstreamCircuit, hshare]

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

theorem upstream_wf : upstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [upstream, upstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem downstream_wf : downstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [downstream, downstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem composite_wf : composite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [composite, compositeCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem upstream_opini : opiniSpec upstream transitionGlitch 1 := by
  apply (opini_iff_spec upstream transitionGlitch 1
    (inputs_reached upstream)).mp
  exact ⟨upstream_wf, by decide⟩

set_option maxHeartbeats 2000000 in
theorem downstream_opini : opiniSpec downstream transitionGlitch 1 := by
  apply (opini_iff_spec downstream transitionGlitch 1
    (inputs_reached downstream)).mp
  exact ⟨downstream_wf, by decide⟩

private theorem composite_secrets_reached :
    ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
  intro secret hsecret
  let x := secret.flatMap fun bit => [bit, false]
  have hx : x ∈ boolVectors (inputWidth composite) := by
    simp [x, composite, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl | rfl | rfl <;> decide
  have hsecrets : secretsOf composite x = secret := by
    simp [x, composite, secretsOf, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl | rfl | rfl <;> decide
  exact List.length_pos_iff.mpr
    (envsForSecret_ne_nil_of_input composite secret x hx hsecrets
      (envsForInput_ne_nil_of_valid composite x
        (fixingForInput_valid composite x)))

set_option maxHeartbeats 2000000 in
theorem composite_not_probing :
    ¬ probingSecureSpec composite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure composite transitionGlitch 1 :=
    (probingSecure_iff_spec composite transitionGlitch 1
      composite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast composite transitionGlitch 1 :=
    (probingSecureFast_iff composite transitionGlitch 1
      composite_secrets_reached).mpr hexecutable
  exact (by decide :
    ¬ probingSecureFast composite transitionGlitch 1) hfast

theorem connected_input_alias :
    downstream.inputArrival 0 0 = downstream.inputArrival 1 0 := rfl

/-- The alias witness satisfies the memo's exact `RegPorts` record, including
the literal `.inp connected j` gate guard.  Thus the obstruction is not an
artifact of the older existential source-coherence field. -/
def memoPorts : RegPorts upstream downstream where
  compilerPorts := ports
  connected := 10
  input_gate_ok := by
    intro j hj
    change j < 2 at hj
    have : j = 0 ∨ j = 1 := by omega
    rcases this with rfl | rfl <;> rfl
  c₀ := 0
  out_cycle := by
    intro j hj
    change j < 2 at hj
    have : j = 0 ∨ j = 1 := by omega
    rcases this with rfl | rfl <;> rfl
  same_d := rfl
  arrival_eq := rfl
  arrival_cycle := by
    intro j hj
    change j < 2 at hj
    have : j = 0 ∨ j = 1 := by omega
    rcases this with rfl | rfl <;> rfl
  arrival_inside := by decide

theorem memoPorts_portAlignment :
    PortAlignment upstream downstream memoPorts.compilerPorts :=
  memoPorts.portAlignment

/-- The missing condition fails for the remaining external input, whose
arrival atoms are exactly the hidden connected input's arrival atoms. -/
theorem connectedInputSeparated_is_necessary :
    ¬ ConnectedInputSeparated ports := by
  decide

/-- All requested registered conditions and both component O-PINI
certificates hold, including the exact memo `RegPorts` guard, but the compiled
gadget is not order-one probing secure.  Thus a connected-input source
separation condition is additionally necessary. -/
theorem registered_conditions_do_not_imply_theoremA :
    memoPorts.compilerPorts = ports ∧
      RegisteredConditions upstream ports 1 ∧
      ¬ ConnectedInputSeparated ports ∧
      opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      (registeredComposite upstream ports).WF ∧
      ¬ probingSecureSpec (registeredComposite upstream ports)
        transitionGlitch 1 := by
  refine ⟨rfl, ?_, connectedInputSeparated_is_necessary,
    upstream_opini, downstream_opini, ?_, ?_⟩
  · exact ⟨by decide, by decide, by decide, by decide, by decide,
      by decide, by decide, by decide, by decide, by decide⟩
  · simpa [registeredComposite_eq] using composite_wf
  · simpa [registeredComposite_eq] using composite_not_probing

end InputAlias

/-! ## Strict share order is independently necessary

The registered premise set still has to carry the standard masking-order
condition `t < d`.  At full share order, O-PINI is allowed to request every
share and therefore does not imply probing security.  The following closed
registered pipeline satisfies temporal port alignment, full source
disjointness, and reset pinning everywhere; its only failure is `1 < 1`.
-/

namespace ShareOrder

def upstreamCircuit : Circuit :=
  { gates := #[{ kind := .inp 0 0, inputs := [] }] }

def upstream : GadgetInstance :=
  { circuit := upstreamCircuit
    horizon := 2
    d := 1
    inputCount := 1
    inputArrival := fun _ _ => .inp 0 0 0
    output := fun _ => { gate := 0, cycle := 0 }
    member := fun node => node == ({ gate := 0, cycle := 0 } : Node)
    randomness := [] }

def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 10 0, inputs := [] },
      { kind := .not, inputs := [(0, 0)] }
    ] }

def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 2
    d := 1
    inputCount := 1
    inputArrival := fun _ _ => .inp 10 0 1
    output := fun _ => { gate := 1, cycle := 1 }
    member := fun node => node.cycle == 1 && node.gate < 2
    randomness := [] }

def ports : RegisterPorts downstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun _ => 0
  input_gate_bound := by decide
  arrivalCycle := 1
  input_source_coherent := by
    intro share hshare
    change share < 1 at hshare
    have : share = 0 := by omega
    subst share
    exact ⟨10, rfl, rfl⟩
  input_gates_injective := by
    intro i j hi hj _
    change i < 1 at hi
    change j < 1 at hj
    omega

/-- Literal upstream/register/downstream circuit.  The downstream input gate
is replaced by a dead constant and its sole live edge is redirected to the
boundary-register output. -/
def compositeCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] },
      { kind := .const false, inputs := [] },
      { kind := .not, inputs := [(1, 0)] }
    ] }

def composite : GadgetInstance :=
  { circuit := compositeCircuit
    horizon := 2
    d := 1
    inputCount := 1
    inputArrival := upstream.inputArrival
    output := fun _ => { gate := 3, cycle := 1 }
    member := fun node =>
      (node == ({ gate := 0, cycle := 0 } : Node)) ||
        ((node.gate == 1) && node.cycle < 2) ||
        (node.cycle == 1 && 2 ≤ node.gate && node.gate < 4)
    randomness := []
    publicFixing := [(.iniReg 1, false)] }

theorem upstream_wf : upstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [upstream, upstreamCircuit, Circuit.WF,
    Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
    Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred]

theorem downstream_wf : downstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [downstream, downstreamCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

theorem composite_wf : composite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [composite, compositeCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

theorem upstream_opini : opiniSpec upstream transitionGlitch 1 := by
  apply (opini_iff_spec upstream transitionGlitch 1
    (inputs_reached upstream)).mp
  exact ⟨upstream_wf, by decide⟩

theorem downstream_opini : opiniSpec downstream transitionGlitch 1 := by
  apply (opini_iff_spec downstream transitionGlitch 1
    (inputs_reached downstream)).mp
  exact ⟨downstream_wf, by decide⟩

theorem portContract : PortContract ports := by
  decide

theorem port_cycle_aligned :
    ports.arrivalCycle = (upstream.output 0).cycle + 1 := by
  rfl

theorem fullSourceDisjointness :
    FullSourceDisjointness upstream downstream := by
  decide

theorem upstream_pinnedInit : PinnedInit upstream := by
  decide

theorem downstream_pinnedInit : PinnedInit downstream := by
  decide

theorem boundary_pinnedInit : BoundaryPinnedInit composite [1] := by
  decide

theorem composite_pinnedInit : PinnedInit composite := by
  decide

theorem boundary_value (env : Env) :
    Execution.eval compositeCircuit 2 env { gate := 1, cycle := 1 } =
      Execution.eval compositeCircuit 2 env { gate := 0, cycle := 0 } := by
  exact eval_register_succ compositeCircuit 2 env 0 1 0 composite_wf.1
    rfl (by decide)

private theorem composite_secrets_reached :
    ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
  intro secret hsecret
  have hcases : secret = [false] ∨ secret = [true] := by
    simpa [composite, boolVectors] using hsecret
  rcases hcases with rfl | rfl
  · exact List.length_pos_iff.mpr
      (envsForSecret_ne_nil_of_input composite [false] [false]
        (by decide) (by decide)
        (envsForInput_ne_nil_of_valid composite [false]
          (fixingForInput_valid composite [false])))
  · exact List.length_pos_iff.mpr
      (envsForSecret_ne_nil_of_input composite [true] [true]
        (by decide) (by decide)
        (envsForInput_ne_nil_of_valid composite [true]
          (fixingForInput_valid composite [true])))

theorem composite_not_probing :
    ¬ probingSecureSpec composite transitionGlitch 1 := by
  intro hsecure
  have hexecutable : probingSecure composite transitionGlitch 1 :=
    (probingSecure_iff_spec composite transitionGlitch 1
      composite_secrets_reached).mpr hsecure
  have hfast : probingSecureFast composite transitionGlitch 1 :=
    (probingSecureFast_iff composite transitionGlitch 1
      composite_secrets_reached).mpr hexecutable
  exact (by decide : ¬ probingSecureFast composite transitionGlitch 1) hfast

/-- Kernel-closed refutation of the literal requested implication.  All
initialization, source, and port conditions hold, including the upstream to
downstream cycle equation.  The only missing standard premise is `t < d`. -/
theorem pinned_registered_preconditions_need_strict_share_order :
    PortContract ports ∧
      ports.arrivalCycle = (upstream.output 0).cycle + 1 ∧
      FullSourceDisjointness upstream downstream ∧
      PinnedInit upstream ∧
      PinnedInit downstream ∧
      BoundaryPinnedInit composite [1] ∧
      PinnedInit composite ∧
      upstream.d = downstream.d ∧
      ¬ 1 < upstream.d ∧
      opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      composite.WF ∧
      (∀ env, Execution.eval compositeCircuit 2 env
        { gate := 1, cycle := 1 } =
          Execution.eval compositeCircuit 2 env { gate := 0, cycle := 0 }) ∧
      ¬ probingSecureSpec composite transitionGlitch 1 := by
  exact ⟨portContract, port_cycle_aligned, fullSourceDisjointness,
    upstream_pinnedInit, downstream_pinnedInit, boundary_pinnedInit,
    composite_pinnedInit, rfl, by decide, upstream_opini, downstream_opini,
    composite_wf, boundary_value, composite_not_probing⟩

end ShareOrder

/-! ## A faithful three-stage registered pipeline -/

namespace Concrete

/-- The upstream refresh executes at cycle one.  Cycle zero is retained in
the member boundary because a transition probe at cycle one observes it. -/
def upstream : GadgetInstance :=
  { circuit := ConcreteSerial2.upstreamCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 1
    output := fun share =>
      if share = 0 then { gate := 3, cycle := 1 }
      else { gate := 4, cycle := 1 }
    member := fun _ => true
    randomness := [.rnd 0 1] }

/-- The downstream source namespace is disjoint from the upstream one even
before compilation: sharing identifiers 2/3 are reserved for its connected
and external inputs. -/
def downstreamCircuit : Circuit :=
  { gates := #[
      { kind := .inp 2 0, inputs := [] },
      { kind := .inp 2 1, inputs := [] },
      { kind := .inp 3 0, inputs := [] },
      { kind := .inp 3 1, inputs := [] },
      { kind := .rnd 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (3, 0)] },
      { kind := .xor, inputs := [(5, 0), (4, 0)] },
      { kind := .xor, inputs := [(6, 0), (4, 0)] }
    ] }

/-- The isolated downstream executes only at cycle two and declares both its
connected and external input sharings at that same cycle. -/
def downstream : GadgetInstance :=
  { circuit := downstreamCircuit
    horizon := 3
    d := 2
    inputCount := 2
    inputArrival := fun sharing share =>
      .inp (if sharing = 0 then 2 else 3) share 2
    output := fun share =>
      if share = 0 then { gate := 7, cycle := 2 }
      else { gate := 8, cycle := 2 }
    member := fun _ => true
    randomness := [.rnd 1 2] }

def ports : RegisterPorts downstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 9
    omega
  arrivalCycle := 2
  input_source_coherent := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨2, rfl, rfl⟩
    · exact ⟨2, rfl, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h

theorem portAlignment : PortAlignment upstream downstream ports := by
  decide

theorem sharedWindow : SharedWindow upstream downstream := by
  decide

set_option maxHeartbeats 1000000 in
theorem outputPulse : OutputPulse upstream := by
  decide

theorem upstream_wholeWindow : WholeWindow upstream := by
  decide

theorem downstream_wholeWindow : WholeWindow downstream := by
  decide

theorem fullSourceDisjointness : FullSourceDisjointness upstream downstream := by
  decide

/-- Literal `upstream ++ two registers ++ downstream`.  The first two
downstream input gates are replaced by constants and their two consumer edges
are redirected to the register outputs. -/
def compositeCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (2, 0)] },
      { kind := .reg, inputs := [(3, 1)] },
      { kind := .reg, inputs := [(4, 1)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .inp 3 0, inputs := [] },
      { kind := .inp 3 1, inputs := [] },
      { kind := .rnd 1, inputs := [] },
      { kind := .xor, inputs := [(5, 0), (9, 0)] },
      { kind := .xor, inputs := [(6, 0), (10, 0)] },
      { kind := .xor, inputs := [(12, 0), (11, 0)] },
      { kind := .xor, inputs := [(13, 0), (11, 0)] }
    ] }

def composite : GadgetInstance :=
  { circuit := compositeCircuit
    horizon := 3
    d := 2
    inputCount := 2
    inputArrival := fun sharing share =>
      if sharing = 0 then .inp 0 share 1 else .inp 3 share 2
    output := fun share =>
      if share = 0 then { gate := 14, cycle := 2 }
      else { gate := 15, cycle := 2 }
    member := fun _ => true
    randomness := [.rnd 0 1, .rnd 1 2]
    publicFixing := [(.iniReg 5, false), (.iniReg 6, false)] }

set_option maxHeartbeats 2000000 in
/-- The hand-audited positive witness is exactly the output of the generic
registered compiler. -/
theorem registeredComposite_eq :
    registeredComposite upstream ports = composite := by
  unfold registeredComposite composite
  congr 1
  · simp only [registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, compositeCircuit, Circuit.mk.injEq]
    simp [upstream, downstream, ports, ConcreteSerial2.upstreamCircuit,
      downstreamCircuit, boundaryRegisterGates, registeredDownGates,
      wireRegisteredDownGate, wireRegisteredEdge, connectedShare?,
      boundaryRegister, downstreamOffset]
    decide
  · funext input share
    simp [upstream, downstream, ports, shiftDownSrc,
      unhideRegisteredInput, Nat.lt_one_iff]
  · funext share
    by_cases hshare : share = 0 <;>
      simp [upstream, downstream, downstreamOffset,
        ConcreteSerial2.upstreamCircuit, hshare]

theorem upstream_pinnedInit : PinnedInit upstream := by
  decide

theorem downstream_pinnedInit : PinnedInit downstream := by
  decide

theorem boundary_pinnedInit : BoundaryPinnedInit composite [5, 6] := by
  decide

theorem composite_pinnedInit : PinnedInit composite := by
  decide

theorem upstream_wf : upstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [upstream, ConcreteSerial2.upstreamCircuit, Circuit.WF,
    Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
    Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred]

theorem downstream_wf : downstream.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [downstream, downstreamCircuit, Circuit.WF,
    Circuit.indicesOk, Circuit.gateArityOk, Circuit.combAcyclic,
    Circuit.combEdges, Circuit.kahnLoop, Circuit.kahnStep,
    Circuit.hasRemainingPred]

theorem composite_wf : composite.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [composite, compositeCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

theorem upstream_opini : opiniSpec upstream transitionGlitch 1 := by
  apply (opini_iff_spec upstream transitionGlitch 1
    (inputs_reached upstream)).mp
  exact ⟨upstream_wf, by decide⟩

theorem downstream_opini : opiniSpec downstream transitionGlitch 1 := by
  apply (opini_iff_spec downstream transitionGlitch 1
    (inputs_reached downstream)).mp
  exact ⟨downstream_wf, by decide⟩

private theorem composite_secrets_reached :
    ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
  intro secret hsecret
  let x := secret.flatMap fun bit => [bit, false]
  have hx : x ∈ boolVectors (inputWidth composite) := by
    simp [x, composite, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl | rfl | rfl <;> decide
  have hsecrets : secretsOf composite x = secret := by
    simp [x, composite, secretsOf, boolVectors] at hsecret ⊢
    rcases hsecret with rfl | rfl | rfl | rfl <;> decide
  exact List.length_pos_iff.mpr
    (envsForSecret_ne_nil_of_input composite secret x hx hsecrets
      (envsForInput_ne_nil_of_valid composite x
        (fixingForInput_valid composite x)))

set_option maxHeartbeats 1000000 in
theorem composite_pini : piniSpec composite transitionGlitch 1 := by
  exact (pini_iff_spec composite transitionGlitch 1
    (inputs_reached composite)).mp ⟨composite_wf, by decide⟩

/-- The concrete end-to-end result follows through the audited PINI bridge,
not by assuming probing security as a wiring premise. -/
theorem composite_probing :
    probingSecureSpec composite transitionGlitch 1 := by
  apply pini_implies_probing composite transitionGlitch 1
  · decide
  · intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl <;> decide
  · intro i j hi hj heq
    change i < 2 at hi
    change j < 2 at hj
    have his : i = 0 ∨ i = 1 := by omega
    have hjs : j = 0 ∨ j = 1 := by omega
    rcases his with rfl | rfl <;> rcases hjs with rfl | rfl <;>
      simp [composite] at heq ⊢
  · exact inputs_reached composite
  · exact composite_pini

theorem compiled_boundary_pinnedInit :
    BoundaryPinnedInit (registeredComposite upstream ports)
      (boundaryRegisters upstream downstream) := by
  decide

theorem compiled_pinnedInit : PinnedInit (registeredComposite upstream ports) := by
  simpa [registeredComposite_eq] using composite_pinnedInit

/-- The positive compiler instance closes the exact registered-assembly cut. -/
theorem registeredAssembly : RegisteredAssembly upstream ports 1 := by
  refine ⟨by simpa [registeredComposite_eq] using composite_pini, ?_⟩
  rw [registeredComposite_eq]
  refine ⟨by decide, ?_, ?_, inputs_reached composite⟩
  · intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl <;> decide
  · intro i j hi hj heq
    change i < 2 at hi
    change j < 2 at hj
    have his : i = 0 ∨ i = 1 := by omega
    have hjs : j = 0 ∨ j = 1 := by omega
    rcases his with rfl | rfl <;> rcases hjs with rfl | rfl <;>
      simp [composite] at heq ⊢

/-- Concrete instantiation of the generic residual theorem.  The conclusion
is definitionally the already-audited registered pipeline witness. -/
theorem theoremA_concrete_instantiation :
    probingSecureSpec (registeredComposite upstream ports)
      transitionGlitch 1 := by
  exact theoremA_of_registeredAssembly upstream downstream ports 1
    (by decide) fullSourceDisjointness portAlignment
    upstream_pinnedInit downstream_pinnedInit compiled_boundary_pinnedInit
    upstream_opini downstream_opini registeredAssembly

/-- N1 is live on both boundary registers at the concrete cycle-2 read. -/
theorem boundary_values (env : Env) :
    Execution.eval compositeCircuit 3 env { gate := 5, cycle := 2 } =
        Execution.eval compositeCircuit 3 env { gate := 3, cycle := 1 } ∧
      Execution.eval compositeCircuit 3 env { gate := 6, cycle := 2 } =
        Execution.eval compositeCircuit 3 env { gate := 4, cycle := 1 } := by
  constructor
  · exact eval_register_succ compositeCircuit 3 env 3 5 1 composite_wf.1
      rfl (by decide)
  · exact eval_register_succ compositeCircuit 3 env 4 6 1 composite_wf.1
      rfl (by decide)

/-- The complete two-register observation tuple is N2-neutral. -/
theorem boundary_layer_neutral (env : Env) :
    ([⟨3, 5, 0⟩, ⟨4, 6, 0⟩] : List RegisterLayerSite).flatMap
        (fun site => transitionValues compositeCircuit 3 env site.outputNode) =
      ([⟨3, 5, 0⟩, ⟨4, 6, 0⟩] : List RegisterLayerSite).flatMap
        (fun site => transitionValues compositeCircuit 3 env site.inputNode) := by
  apply register_layer_transition_neutral compositeCircuit 3 env
    [⟨3, 5, 0⟩, ⟨4, 6, 0⟩] composite_wf.1
  · intro site hsite
    simp at hsite
    rcases hsite with rfl | rfl <;> rfl
  · intro site hsite
    simp at hsite
    rcases hsite with rfl | rfl <;> decide

/-- Necessity control: deleting the register stage and wiring the same static
downstream edges directly to upstream gates makes the cycle-two consumer read
the cycle-two upstream stream, not the designated cycle-one output. -/
def staticGlueCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (2, 0)] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .const false, inputs := [] },
      { kind := .inp 3 0, inputs := [] },
      { kind := .inp 3 1, inputs := [] },
      { kind := .rnd 1, inputs := [] },
      { kind := .xor, inputs := [(3, 0), (9, 0)] },
      { kind := .xor, inputs := [(4, 0), (10, 0)] },
      { kind := .xor, inputs := [(12, 0), (11, 0)] },
      { kind := .xor, inputs := [(13, 0), (11, 0)] }
    ] }

def staticGlue : GadgetInstance :=
  { composite with circuit := staticGlueCircuit }

def composedXorFunction (secrets : List Bool) : Bool :=
  secrets.getD 0 false != secrets.getD 1 false

/-- The non-register glue is not a composition of the intended functions:
the upstream input is consumed at the wrong cycle and is pinned to zero. -/
theorem staticGlue_fails_functional_composition :
    ¬ recombinesTo staticGlue composedXorFunction := by
  decide

/-- Closed non-vacuity package for the three-stage construction. -/
theorem registered_pipeline_security_package :
    PortAlignment upstream downstream ports ∧
      FullSourceDisjointness upstream downstream ∧
      PinnedInit upstream ∧
      PinnedInit downstream ∧
      BoundaryPinnedInit composite [5, 6] ∧
      PinnedInit composite ∧
      opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      composite.WF ∧
      piniSpec composite transitionGlitch 1 ∧
      probingSecureSpec composite transitionGlitch 1 := by
  exact ⟨portAlignment, fullSourceDisjointness,
    upstream_pinnedInit, downstream_pinnedInit, boundary_pinnedInit,
    composite_pinnedInit,
    upstream_opini,
    downstream_opini, composite_wf, composite_pini, composite_probing⟩

/-- The positive witness also satisfies the standard strict masking order and
the upstream/downstream cycle equation missing from the older port record.
The final conjunct retains the non-register necessity control. -/
theorem registered_pipeline_strict_order_nonvacuity :
    (∀ share, share < upstream.d →
        ports.arrivalCycle = (upstream.output share).cycle + 1) ∧
      FullSourceDisjointness upstream downstream ∧
      PinnedInit upstream ∧
      PinnedInit downstream ∧
      BoundaryPinnedInit composite [5, 6] ∧
      PinnedInit composite ∧
      1 < upstream.d ∧
      upstream.d = downstream.d ∧
      opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      composite.WF ∧
      piniSpec composite transitionGlitch 1 ∧
      probingSecureSpec composite transitionGlitch 1 ∧
      ¬ recombinesTo staticGlue composedXorFunction := by
  refine ⟨?_, fullSourceDisjointness, upstream_pinnedInit,
    downstream_pinnedInit, boundary_pinnedInit, composite_pinnedInit,
    by decide, rfl, upstream_opini, downstream_opini, composite_wf,
    composite_pini, composite_probing,
    staticGlue_fails_functional_composition⟩
  intro share hshare
  change share < 2 at hshare
  have hs : share = 0 ∨ share = 1 := by omega
  rcases hs with rfl | rfl <;> rfl

end Concrete

/-!
For contrast, a `.reg` gate does not freeze one selected `Node` for
the rest of the execution.  Its value is its input at the latency selected by
the gate's static edge.  Consequently a latency-one register driven by gate
`u` presents `u@(cycle - 1)`: adjacent register cycles present adjacent
upstream cycles.

This fact is consistent with N1/N2: those lemmas equate the two adjacent
register values with the two latency-aligned input-stream values.  It only
rules out treating a plain register as a freeze/enable element that aliases
one fixed `Node` forever.
-/

/-- The smallest latency-one boundary register whose upstream source changes
between two cycles. -/
def changingBoundaryCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .reg, inputs := [(0, 1)] }
    ] }

/-- A concrete environment in which the upstream stream changes after the
declared cycle-zero boundary value. -/
def changingBoundaryEnv : Env :=
  Execution.envFrom
    [(.inp 0 0 0, true), (.inp 0 0 1, false), (.iniReg 1, false)]

theorem changingBoundaryCircuit_wf : changingBoundaryCircuit.WF := by
  simp [changingBoundaryCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

/-- At cycle one the register presents the declared upstream cycle-zero
value, but at cycle two it presents the different upstream cycle-one value.
Thus `.reg` is a stream delay, not a stable alias for one fixed output node. -/
theorem latency_one_register_does_not_stabilize_fixed_boundary :
    Execution.eval changingBoundaryCircuit 3 changingBoundaryEnv
        { gate := 0, cycle := 0 } = true ∧
      Execution.eval changingBoundaryCircuit 3 changingBoundaryEnv
        { gate := 1, cycle := 1 } = true ∧
      Execution.eval changingBoundaryCircuit 3 changingBoundaryEnv
        { gate := 0, cycle := 1 } = false ∧
      Execution.eval changingBoundaryCircuit 3 changingBoundaryEnv
        { gate := 1, cycle := 2 } = false := by
  decide

/-- A static downstream edge redirected to a register gate would need this
property in order for one fixed register-output `Node` to be the boundary at
two adjacent read cycles. -/
def StaticRegisterBoundarySubstitutionAtTwoCycles
    (cycle register latency : Nat) (boundary : Node) : Prop :=
  GenericSerial2.edgePredecessorAt cycle (register, latency) = some boundary ∧
    GenericSerial2.edgePredecessorAt (cycle + 1) (register, latency) =
      some boundary

/-- Adding a `.reg` gate does not alter the static-edge obstruction: adjacent
reads name adjacent cycle instances of the register gate, never one fixed
register-output node. -/
theorem no_static_register_boundary_substitution_at_two_cycles
    (cycle register latency : Nat) (boundary : Node) :
    ¬ StaticRegisterBoundarySubstitutionAtTwoCycles
      cycle register latency boundary := by
  exact UniversalTFinal.no_static_boundary_substitution_at_two_cycles
    cycle (register, latency) boundary

/-- Transition-plus-glitch expansion of the second register read includes
both adjacent register-output nodes.  The register's latency-one data input is
a glitch frontier, so it is not traversed by same-cycle glitch expansion. -/
theorem transitionGlitch_exposes_adjacent_register_outputs :
    transitionGlitch changingBoundaryCircuit 3 { gate := 1, cycle := 2 } =
      [{ gate := 1, cycle := 1 }, { gate := 1, cycle := 2 }] := by
  decide

/-- The two register-output nodes exposed by `transitionGlitch` can carry
different values in a well-formed circuit. -/
theorem transitionGlitch_register_observation_is_not_held :
    (transitionGlitch changingBoundaryCircuit 3
      { gate := 1, cycle := 2 }).map
        (Execution.eval changingBoundaryCircuit 3 changingBoundaryEnv) =
      [true, false] := by
  decide

/-- Kernel-checked distinction between a stream delay and a stable alias. -/
theorem frozen_register_semantics_blocks_stable_boundary :
    changingBoundaryCircuit.WF ∧
      (Execution.eval changingBoundaryCircuit 3 changingBoundaryEnv
          { gate := 1, cycle := 1 } ≠
        Execution.eval changingBoundaryCircuit 3 changingBoundaryEnv
          { gate := 1, cycle := 2 }) ∧
      (transitionGlitch changingBoundaryCircuit 3
        { gate := 1, cycle := 2 }).map
          (Execution.eval changingBoundaryCircuit 3 changingBoundaryEnv) =
        [true, false] := by
  exact ⟨changingBoundaryCircuit_wf, by decide,
    transitionGlitch_register_observation_is_not_held⟩

end UniversalReg
end Composition
end LeanSec

#print axioms LeanSec.Composition.UniversalReg.changingBoundaryCircuit_wf
#print axioms LeanSec.Composition.UniversalReg.eval_register_succ
#print axioms LeanSec.Composition.UniversalReg.register_output_transition_eq_input
#print axioms LeanSec.Composition.UniversalReg.register_layer_transition_neutral
#print axioms LeanSec.Composition.UniversalReg.registeredMismatch_violates_PortContract
#print axioms LeanSec.Composition.UniversalReg.Concrete.portAlignment
#print axioms LeanSec.Composition.UniversalReg.Concrete.registeredComposite_eq
#print axioms LeanSec.Composition.UniversalReg.Concrete.registeredAssembly
#print axioms LeanSec.Composition.UniversalReg.Concrete.theoremA_concrete_instantiation
#print axioms LeanSec.Composition.UniversalReg.Concrete.composite_pini
#print axioms LeanSec.Composition.UniversalReg.Concrete.composite_probing
#print axioms LeanSec.Composition.UniversalReg.Concrete.registered_pipeline_security_package
#print axioms LeanSec.Composition.UniversalReg.register_output_transitionGlitch_eq_transition
#print axioms LeanSec.Composition.UniversalReg.register_layer_transition_neutral
#print axioms LeanSec.Composition.UniversalReg.register_layer_adds_no_transition_pair
#print axioms LeanSec.Composition.UniversalReg.simulatableOn_iff_of_observation_eq
#print axioms LeanSec.Composition.UniversalReg.registeredComposite_boundary_gate
#print axioms LeanSec.Composition.UniversalReg.registeredComposite_boundary_value
#print axioms LeanSec.Composition.UniversalReg.registeredComposite_probingBoundary
#print axioms LeanSec.Composition.UniversalReg.registeredAssembly_of_pini
#print axioms LeanSec.Composition.UniversalReg.theoremA_of_registeredAssembly
#print axioms LeanSec.Composition.UniversalReg.lookupAssoc_fixingForInput_of_sourcePinned
#print axioms LeanSec.Composition.UniversalReg.registeredMismatchUp_opini
#print axioms LeanSec.Composition.UniversalReg.registeredMismatchDown_opini
#print axioms LeanSec.Composition.UniversalReg.registeredMismatch_boundary_values
#print axioms LeanSec.Composition.UniversalReg.PostWindow.sharedWindow_is_necessary
#print axioms LeanSec.Composition.UniversalReg.DeepHistory.outputPulse_is_necessary
#print axioms LeanSec.Composition.UniversalReg.InputAlias.connected_input_alias
#print axioms LeanSec.Composition.UniversalReg.RegPorts.portAlignment
#print axioms LeanSec.Composition.UniversalReg.InputAlias.memoPorts_portAlignment
#print axioms LeanSec.Composition.UniversalReg.InputAlias.connectedInputSeparated_is_necessary
#print axioms LeanSec.Composition.UniversalReg.InputAlias.registered_conditions_do_not_imply_theoremA
#print axioms LeanSec.Composition.UniversalReg.registeredMismatchComposite_not_probing
#print axioms LeanSec.Composition.UniversalReg.boundary_registers_do_not_close_fixed_node_interface
#print axioms LeanSec.Composition.UniversalReg.InitCollision.portContract
#print axioms LeanSec.Composition.UniversalReg.InitCollision.fullSourceDisjointness
#print axioms LeanSec.Composition.UniversalReg.InitCollision.boundaryInit_not_pinnable
#print axioms LeanSec.Composition.UniversalReg.InitCollision.upstream_opini
#print axioms LeanSec.Composition.UniversalReg.InitCollision.downstream_opini
#print axioms LeanSec.Composition.UniversalReg.InitCollision.declared_input_becomes_boundary_initial_source
#print axioms LeanSec.Composition.UniversalReg.InitCollision.boundary_values
#print axioms LeanSec.Composition.UniversalReg.InitCollision.composite_not_probing
#print axioms LeanSec.Composition.UniversalReg.InitCollision.stated_preconditions_do_not_imply_registered_security
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.portContract
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.fullSourceDisjointness
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.upstream_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.downstream_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.boundary_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.composite_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.upstream_opini
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.downstream_opini
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.composite_wf
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.boundary_reads_undeclared_upstream_cycle
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.composite_not_probing
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.pinnedInit_preconditions_do_not_imply_registered_security
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.portContract_does_not_imply_upstream_alignment
#print axioms LeanSec.Composition.UniversalReg.PortAlignment.strict_order_condition_bundle_still_insufficient
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.portContract
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.fullSourceDisjointness
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.upstream_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.downstream_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.boundary_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.composite_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.upstream_opini
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.downstream_opini
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.composite_not_probing
#print axioms LeanSec.Composition.UniversalReg.ShareOrder.pinned_registered_preconditions_need_strict_share_order
#print axioms LeanSec.Composition.UniversalReg.latency_one_register_does_not_stabilize_fixed_boundary
#print axioms LeanSec.Composition.UniversalReg.no_static_register_boundary_substitution_at_two_cycles
#print axioms LeanSec.Composition.UniversalReg.transitionGlitch_exposes_adjacent_register_outputs
#print axioms LeanSec.Composition.UniversalReg.transitionGlitch_register_observation_is_not_held
#print axioms LeanSec.Composition.UniversalReg.frozen_register_semantics_blocks_stable_boundary
#print axioms LeanSec.Composition.UniversalReg.Concrete.upstream_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.Concrete.downstream_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.Concrete.boundary_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.Concrete.composite_pinnedInit
#print axioms LeanSec.Composition.UniversalReg.Concrete.staticGlue_fails_functional_composition
#print axioms LeanSec.Composition.UniversalReg.Concrete.registered_pipeline_strict_order_nonvacuity
