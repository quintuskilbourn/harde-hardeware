import LeanSec.Composition.ConcreteSerial2
import LeanSec.Composition.UniversalSStage1

namespace LeanSec
namespace Composition
namespace UniversalSStage2

open Gadget

/-- Explicit node port for the connected input sharing.  At horizon one an
input source gate denotes its cycle-zero arrival node. -/
structure SingleCyclePorts (up down : GadgetInstance) where
  downstreamInput : Nat
  input_bound : downstreamInput < down.inputCount
  inputGate : Nat → Nat
  input_gate_bound : ∀ share, share < down.d →
    inputGate share < down.circuit.gates.size
  input_gate_kind : ∀ share, share < down.d → ∃ sharing,
    down.circuit.gates[inputGate share]? =
      some { kind := .inp sharing share, inputs := [] }
  input_arrival : ∀ share, share < down.d → ∃ sharing,
    down.inputArrival downstreamInput share = .inp sharing share 0
  input_gates_injective : ∀ i j, i < down.d → j < down.d →
    inputGate i = inputGate j → i = j
  up_horizon : up.horizon = 1
  down_horizon : down.horizon = 1
  same_shares : up.d = down.d
  two_shares : up.d = 2
  up_outputs_at_zero : ∀ share, share < up.d → (up.output share).cycle = 0
  down_outputs_at_zero : ∀ share, share < down.d → (down.output share).cycle = 0

def connectedShare? {up down : GadgetInstance}
    (ports : SingleCyclePorts up down) (gate : Nat) : Option Nat :=
  (List.range down.d).find? fun share => ports.inputGate share == gate

/-- Shift an ordinary downstream edge into the suffix; redirect an edge from
the selected input sharing directly to the corresponding upstream output
node.  Latency is retained and the clean-combinational side condition below
requires it to be zero. -/
def wireInput {up down : GadgetInstance}
    (ports : SingleCyclePorts up down) (edge : Nat × Nat) : Nat × Nat :=
  match connectedShare? ports edge.1 with
  | some share => ((up.output share).gate, edge.2)
  | none => (up.circuit.gates.size + edge.1, edge.2)

def wireDownGate {up down : GadgetInstance}
    (ports : SingleCyclePorts up down) (gateIndex : Nat) (gate : Gate) : Gate :=
  match connectedShare? ports gateIndex with
  | some _ => { kind := .const false, inputs := [] }
  | none => { gate with inputs := gate.inputs.map (wireInput ports) }

def wiredDownGates {up down : GadgetInstance}
    (ports : SingleCyclePorts up down) : Array Gate :=
  down.circuit.gates.mapIdx (wireDownGate ports)

/-- Literal DAG union: the upstream gate array is a prefix and the freshly
constructed downstream execution is its suffix. -/
def serialCircuit {up down : GadgetInstance}
    (ports : SingleCyclePorts up down) : Circuit :=
  UniversalSStage1.appendCircuit up.circuit (wiredDownGates ports)

def unhideInput (hidden external : Nat) : Nat :=
  if external < hidden then external else external + 1

/-- Gadget boundary of the single-cycle union.  This construction assumes
the unconnected component source names are already fresh; that check is kept
as an explicit structural side condition rather than silently renaming the
frozen component experiments. -/
def serialGadget {up down : GadgetInstance}
    (ports : SingleCyclePorts up down) : GadgetInstance :=
  { circuit := serialCircuit ports
    horizon := 1
    d := down.d
    inputCount := up.inputCount + (down.inputCount - 1)
    inputArrival := fun input share =>
      if input < up.inputCount then up.inputArrival input share
      else down.inputArrival
        (unhideInput ports.downstreamInput (input - up.inputCount)) share
    output := fun share =>
      { gate := up.circuit.gates.size + (down.output share).gate, cycle := 0 }
    member := fun node =>
      if node.gate < up.circuit.gates.size then up.member node
      else down.member
        { gate := node.gate - up.circuit.gates.size, cycle := node.cycle }
    randomness := up.randomness ++ down.randomness
    publicFixing := up.publicFixing ++ down.publicFixing }

/-- The only structural edge condition used by the horizon-one construction:
the connected input is consumed combinationally. -/
def CleanCombinational {up down : GadgetInstance}
    (ports : SingleCyclePorts up down) : Prop :=
  ∀ (gate : Nat) (entry : Gate) (input : Nat × Nat),
    down.circuit.gates[gate]? = some entry →
    input ∈ entry.inputs → connectedShare? ports input.1 ≠ none → input.2 = 0

/-! ## Frozen-interface boundary

The audited gate language has no node-valued input port.  These two lemmas
make the obstruction explicit: a well-formed input gate has no structural
predecessor, and the evaluator reads its value from `Env` rather than from
the evaluation table.  Consequently replacing such a gate by a node wire is
not a disjoint-union restriction of the isolated downstream execution. -/

theorem inputGate_inputs_eq_nil_of_wf (c : Circuit) (gate : Nat)
    (sharing share : Nat) (hwf : c.WF) (hgate : gate < c.gates.size)
    (hkind : c.gates[gate].kind = .inp sharing share) :
    c.gates[gate].inputs = [] := by
  have hall := Array.all_eq_true.mp hwf.1 gate hgate
  simp only [Bool.and_eq_true] at hall
  have harity := hall.1
  simp [Circuit.gateArityOk, hkind] at harity
  exact harity

theorem inputGate_has_no_node_predecessor (c : Circuit) (gate : Nat)
    (sharing share : Nat) (hwf : c.WF) (hgate : gate < c.gates.size)
    (hkind : c.gates[gate].kind = .inp sharing share) :
    ¬ ∃ edge, edge ∈ c.gates[gate].inputs := by
  rw [inputGate_inputs_eq_nil_of_wf c gate sharing share hwf hgate hkind]
  simp

theorem inputGate_value_is_environment_source (c : Circuit) (env : Env)
    (values : List (Node × Bool)) (cycle gate sharing share : Nat)
    (hlookup : c.gates[gate]? =
      some { kind := .inp sharing share, inputs := [] }) :
    UniversalSStage1.gateValue c env values cycle gate =
      env (.inp sharing share cycle) := by
  simp [UniversalSStage1.gateValue, hlookup]

namespace Concrete

open ConcreteSerial2

def ports : SingleCyclePorts upstream downstream where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    have : share < 9 := by omega
    simpa [downstream, downstreamCircuit] using this
  input_gate_kind := by
    intro share hshare
    change share < 2 at hshare
    have hs : share = 0 ∨ share = 1 := by omega
    rcases hs with rfl | rfl
    · exact ⟨0, rfl⟩
    · exact ⟨0, rfl⟩
  input_arrival := by
    intro share hshare
    exact ⟨0, rfl⟩
  input_gates_injective := by
    intro i j _ _ h
    exact h
  up_horizon := rfl
  down_horizon := rfl
  same_shares := rfl
  two_shares := rfl
  up_outputs_at_zero := by
    intro share hshare
    by_cases hs : share = 0 <;> simp [upstream, hs]
  down_outputs_at_zero := by
    intro share hshare
    by_cases hs : share = 0 <;> simp [downstream, hs]

theorem clean : CleanCombinational ports := by
  intro gate entry input hentry hinput hconnected
  have hgate : gate < 9 := by
    by_cases h : gate < 9
    · exact h
    · have : downstreamCircuit.gates[gate]? = none := by simp [downstreamCircuit, h]
      simp [downstream, this] at hentry
  have hcases : gate = 0 ∨ gate = 1 ∨ gate = 2 ∨ gate = 3 ∨
      gate = 4 ∨ gate = 5 ∨ gate = 6 ∨ gate = 7 ∨ gate = 8 := by omega
  rcases hcases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp [downstream, downstreamCircuit] at hentry <;>
    subst entry <;> simp_all [connectedShare?, ports] <;>
    try { rcases hinput with rfl | rfl <;> rfl }

/-- The frozen circuit language has no input-node alias: the connected
downstream execution is not literally the original downstream gate array.
This is a kernel-checked fact even for the required concrete pair. -/
theorem wiredDownGates_ne_original :
    wiredDownGates ports ≠ downstream.circuit.gates := by
  decide

def composite : GadgetInstance := serialGadget ports

theorem composite_probing :
    probingSecureSpec composite transitionGlitch 1 := by
  have reached : ∀ secret ∈ boolVectors composite.inputCount,
      (envsForSecret composite secret).length > 0 := by
    intro secret hsecret
    let x := secret.flatMap fun bit => [bit, false]
    have hx : x ∈ boolVectors (inputWidth composite) := by
      apply (mem_boolVectors_iff _ _).mpr
      have hlen := (mem_boolVectors_iff _ _).mp hsecret
      change secret.length = 2 at hlen
      change x.length = 4
      rcases secret with _ | ⟨a, tail⟩
      · simp at hlen
      rcases tail with _ | ⟨b, tail⟩
      · simp at hlen
      rcases tail with _ | ⟨c, tail⟩
      · simp [x]
      · simp at hlen
    have hsecrets : secretsOf composite x = secret := by
      have hlen := (mem_boolVectors_iff _ _).mp hsecret
      change secret.length = 2 at hlen
      rcases secret with _ | ⟨a, tail⟩
      · simp at hlen
      rcases tail with _ | ⟨b, tail⟩
      · simp at hlen
      rcases tail with _ | ⟨c, tail⟩
      · change [xorList [a, false], xorList [b, false]] = [a, b]
        cases a <;> cases b <;> rfl
      · simp at hlen
    apply List.length_pos_iff.mpr
    exact envsForSecret_ne_nil_of_input composite secret x hx hsecrets
      (envsForInput_ne_nil_of_valid composite x
        (fixingForInput_valid composite x))
  apply (probingSecure_iff_spec composite transitionGlitch 1 reached).mp
  apply (probingSecureFast_iff composite transitionGlitch 1 reached).mp
  decide

theorem component_opini_and_clean :
    opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧ CleanCombinational ports :=
  ⟨ConcreteSerial2.upstream_opini, ConcreteSerial2.downstream_opini, clean⟩

theorem concrete_security_package :
    opiniSpec upstream transitionGlitch 1 ∧
      opiniSpec downstream transitionGlitch 1 ∧
      CleanCombinational ports ∧
      probingSecureSpec composite transitionGlitch 1 :=
  ⟨ConcreteSerial2.upstream_opini, ConcreteSerial2.downstream_opini,
    clean, composite_probing⟩

end Concrete
end UniversalSStage2
end Composition
end LeanSec

#print axioms LeanSec.Composition.UniversalSStage2.Concrete.clean
#print axioms LeanSec.Composition.UniversalSStage2.inputGate_inputs_eq_nil_of_wf
#print axioms LeanSec.Composition.UniversalSStage2.inputGate_has_no_node_predecessor
#print axioms LeanSec.Composition.UniversalSStage2.inputGate_value_is_environment_source
#print axioms LeanSec.Composition.UniversalSStage2.Concrete.wiredDownGates_ne_original
#print axioms LeanSec.Composition.UniversalSStage2.Concrete.composite_probing
#print axioms LeanSec.Composition.UniversalSStage2.Concrete.concrete_security_package
