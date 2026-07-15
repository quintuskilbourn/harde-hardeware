import LeanSec.Composition.OPINIReuse

namespace LeanSec
namespace Composition
namespace OPINIRealWork

open Gadget
open UniversalReg

/-! # Non-degenerate producer reuse through the generic O-PINI closure

Hardening of the accepted `OPINIReuse` result.  The accepted reconvergent
instance (`forkJoin`) has real fanout but degenerate computation: its branch
gates compute `x ⊕ x = 0`, so every branch value is identically `false` and
the composite recombines to the identity.  The tail below replaces that
artificial fork--join with one doing *real, distinct* work:

* branch `A` mixes the shared producer sharing `x` with an independent
  external input sharing `y` (share-wise `x_s ⊕ y_s`);
* branch `B` refreshes `x` with fresh tail randomness `r₁`
  (`x_s ⊕ r₁`);
* the branches reconverge at `C_s = A_s ⊕ B_s` and the output gates
  `D_s = C_s ⊕ x_s` read the shared input a *third* time, so each connected
  input gate drives three distinct consumers along reconvergent paths.

The compiled composite (audited refresh producer + boundary registers +
this tail) recombines to `x ⊕ y` — a function depending non-trivially on
*both* the producer-fed secret and the tail-local secret — and every
internal tail gate is proven non-constant over the actual experiment
environments (`realWork_gates_nonconstant`), in explicit contrast to the
accepted instance whose branch gate is proven identically false
(`forkJoin_branch_degenerate`).  Security of the composite is obtained
*only* from the generic closure (`OPINIComposition`), exactly as for
`OPINIReuse`: no hand audit of the composite occurs. -/

/-- Real-work fork--join tail.  Sharing 2 is the connected port, sharing 3
is external; `rnd 1` is the tail-local refresh.  Share `s` of the port is
read by branch gate `5+s` (mix with `y`), branch gate `7+s` (refresh), and
reconvergence gate `11+s`. -/
def realWorkCircuit : Circuit :=
  { gates := #[
      { kind := .inp 2 0, inputs := [] },
      { kind := .inp 2 1, inputs := [] },
      { kind := .inp 3 0, inputs := [] },
      { kind := .inp 3 1, inputs := [] },
      { kind := .rnd 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (2, 0)] },
      { kind := .xor, inputs := [(1, 0), (3, 0)] },
      { kind := .xor, inputs := [(0, 0), (4, 0)] },
      { kind := .xor, inputs := [(1, 0), (4, 0)] },
      { kind := .xor, inputs := [(5, 0), (7, 0)] },
      { kind := .xor, inputs := [(6, 0), (8, 0)] },
      { kind := .xor, inputs := [(9, 0), (0, 0)] },
      { kind := .xor, inputs := [(10, 0), (1, 0)] }
    ] }

def realWork : GadgetInstance :=
  { circuit := realWorkCircuit
    horizon := 3
    d := 2
    inputCount := 2
    inputArrival := fun sharing share =>
      .inp (if sharing = 0 then 2 else 3) share 2
    output := fun share => { gate := 11 + share, cycle := 2 }
    member := fun _ => true
    randomness := [.rnd 1 2] }

theorem realWork_wf : realWork.WF := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide⟩
  simp [realWork, realWorkCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Literal triple fanout inside the isolated tail: each connected input
gate has three distinct reading gates, on reconvergent paths. -/
theorem realWork_fanout :
    (0, 0) ∈ realWorkCircuit.gates[5].inputs ∧
    (0, 0) ∈ realWorkCircuit.gates[7].inputs ∧
    (0, 0) ∈ realWorkCircuit.gates[11].inputs ∧
    (1, 0) ∈ realWorkCircuit.gates[6].inputs ∧
    (1, 0) ∈ realWorkCircuit.gates[8].inputs ∧
    (1, 0) ∈ realWorkCircuit.gates[12].inputs := by
  decide

private theorem inputs_reached (g : GadgetInstance) :
    ∀ x ∈ boolVectors (inputWidth g), (envsForInput g x).length > 0 := by
  intro x _
  exact List.length_pos_iff.mpr
    (envsForInput_ne_nil_of_valid g x (fixingForInput_valid g x))

set_option maxRecDepth 10000 in
set_option maxHeartbeats 64000000 in
theorem realWork_opini : opiniSpec realWork transitionGlitch 1 := by
  apply (opini_iff_spec realWork transitionGlitch 1
    (inputs_reached realWork)).mp
  exact ⟨realWork_wf, by decide⟩

def realWorkPorts : RegisterPorts realWork where
  downstreamInput := 0
  input_bound := by decide
  inputGate := fun share => share
  input_gate_bound := by
    intro share hshare
    change share < 2 at hshare
    change share < 13
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

set_option maxHeartbeats 4000000 in
def realWorkPipeline : PipelineGadget 3 2 1 where
  g := realWork
  horizon_eq := rfl
  d_eq := rfl
  order_lt := by decide
  whole_window := by decide
  hold_empty := by simp [GadgetInstance.inputHold]
  ports := realWorkPorts
  arrival_inside := by decide
  interface_injective := by decide
  source_partition := by decide
  port_source_exclusive := by decide
  forward_combinational := by decide
  pinned_init := by decide
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
      simp [realWork] at heq ⊢
  output_pulse := by decide
  down_cert := opini_implies_pini realWork transitionGlitch 1 realWork_opini

/-! ## Closed leaves and the generic derivation -/

/-- The same audited refresh producer as the accepted instance. -/
def producerNode : UOPipelineGadget 3 2 1 := OPINIReuse.producerNode

/-- The real-work tail, packaged as a closed O-PINI node. -/
def realWorkNode : UOPipelineGadget 3 2 1 :=
  UOPipelineGadget.ofLeaf realWorkPipeline realWork_opini

theorem realWork_arrival_inside : realWorkPorts.arrivalCycle < 3 := by
  decide

theorem realWork_port_exclusive : PortSourceExclusive realWorkPorts := by
  decide

theorem realWorkGlue : PortGlue producerNode.toPipelineGadget
    (realWorkNode.toPipelineGadget.withPorts realWorkPorts
      realWork_arrival_inside realWork_port_exclusive) := by
  refine ⟨rfl, ?_⟩
  decide

/-- The non-degenerate reconvergent producer-reuse composite, built
exclusively by the generic closure operation. -/
def realComposite : UOPipelineGadget 3 2 1 :=
  UOPipelineGadget.wire producerNode realWorkNode realWorkPorts
    realWork_arrival_inside realWork_port_exclusive realWorkGlue

/-- The composite is a generic `OPINIComposition` derivation: two uniform
O-PINI leaves joined by one wiring step. -/
theorem realComposite_build : OPINIComposition realComposite :=
  OPINIComposition.wire producerNode realWorkNode
    (OPINIComposition.leaf UniversalReg.Concrete.upstreamPipeline
      (opini_implies_uniform_of_le_one _ transitionGlitch 1 (Nat.le_refl 1)
        UniversalReg.Concrete.upstream_opini))
    (OPINIComposition.leaf realWorkPipeline
      (opini_implies_uniform_of_le_one _ transitionGlitch 1 (Nat.le_refl 1)
        realWork_opini))
    realWorkPorts realWork_arrival_inside realWork_port_exclusive realWorkGlue

/-- The compiled gadget is the generic registered compiler's output. -/
theorem realComposite_g :
    realComposite.g =
      registeredComposite UniversalReg.Concrete.upstream realWorkPorts := rfl

/-! ## The audited conclusions, obtained from the generic theorem -/

/-- Composite O-PINI: the reconvergent composite can itself be reused as an
upstream producer. -/
theorem realWork_composite_opini :
    opiniSpec realComposite.g transitionGlitch 1 :=
  realComposite_build.opini

/-- Composite downstream-role PINI. -/
theorem realWork_composite_pini :
    piniSpec realComposite.g transitionGlitch 1 :=
  realComposite_build.pini

/-- End-to-end probing security of the compiled non-degenerate reconvergent
circuit under the real transition-glitch expansion, via the generic closure
only. -/
theorem realWork_composite_probing :
    probingSecureSpec realComposite.g transitionGlitch 1 :=
  realComposite_build.probing

/-! ## The literal compiled circuit -/

/-- Producer prefix (gates 0-4), two shared boundary registers (5, 6), and
the transported real-work suffix (7-19).  Every read of the connected input
gates has been redirected to the boundary registers 5 and 6, each of which
therefore drives three distinct consumers. -/
def compiledCircuit : Circuit :=
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
      { kind := .xor, inputs := [(5, 0), (11, 0)] },
      { kind := .xor, inputs := [(6, 0), (11, 0)] },
      { kind := .xor, inputs := [(12, 0), (14, 0)] },
      { kind := .xor, inputs := [(13, 0), (15, 0)] },
      { kind := .xor, inputs := [(16, 0), (5, 0)] },
      { kind := .xor, inputs := [(17, 0), (6, 0)] }
    ] }

def compiled : GadgetInstance :=
  { circuit := compiledCircuit
    horizon := 3
    d := 2
    inputCount := 2
    inputArrival := fun input share =>
      if input < 1 then .inp 0 share 1 else .inp 3 share 2
    output := fun share => { gate := 18 + share, cycle := 2 }
    member := fun _ => true
    randomness := [.rnd 0 1, .rnd 1 2]
    publicFixing := [(.iniReg 5, false), (.iniReg 6, false)] }

set_option maxHeartbeats 4000000 in
set_option linter.unusedSimpArgs false in
/-- The generic compiler's output is this literal reconvergent circuit. -/
theorem realComposite_g_eq : realComposite.g = compiled := by
  show registeredComposite UniversalReg.Concrete.upstream realWorkPorts =
    compiled
  unfold registeredComposite compiled
  congr 1
  · simp only [registeredCompositeCircuit,
      UniversalSStage1.appendCircuit, compiledCircuit, Circuit.mk.injEq]
    simp [UniversalReg.Concrete.upstream, realWork, realWorkPorts,
      ConcreteSerial2.upstreamCircuit, realWorkCircuit,
      boundaryRegisterGates, registeredDownGates, wireRegisteredDownGate,
      wireRegisteredEdge, connectedShare?, boundaryRegister,
      downstreamOffset]
    decide
  all_goals
    simp [UniversalReg.Concrete.upstream, realWork, realWorkPorts,
      shiftDownSrc, unhideRegisteredInput, Nat.lt_one_iff,
      downstreamOffset, boundaryRegister, ConcreteSerial2.upstreamCircuit,
      realWorkCircuit]
  all_goals funext share
  all_goals simp only [Node.mk.injEq, and_true]
  all_goals omega

/-! ## Kernel-checked producer reuse in the compiled circuit -/

theorem boundary_registers_latch_producer :
    realComposite.g.circuit.gates[5]? =
      some { kind := .reg, inputs := [(3, 1)] } ∧
    realComposite.g.circuit.gates[6]? =
      some { kind := .reg, inputs := [(4, 1)] } := by
  rw [realComposite_g_eq]
  decide

/-- Each shared boundary register is read by three distinct compiled
consumers: the `y`-mixing branch, the refresh branch, and the reconvergence
gate at the declared output. -/
theorem producer_reused_by_three_consumers :
    ((5, 0) ∈ compiledCircuit.gates[12].inputs ∧
     (5, 0) ∈ compiledCircuit.gates[14].inputs ∧
     (5, 0) ∈ compiledCircuit.gates[18].inputs) ∧
    ((6, 0) ∈ compiledCircuit.gates[13].inputs ∧
     (6, 0) ∈ compiledCircuit.gates[15].inputs ∧
     (6, 0) ∈ compiledCircuit.gates[19].inputs) := by
  decide

theorem outputs_reconverge :
    realComposite.g.output 0 = { gate := 18, cycle := 2 } ∧
    realComposite.g.output 1 = { gate := 19, cycle := 2 } := by
  rw [realComposite_g_eq]
  decide

set_option maxRecDepth 10000 in
set_option maxHeartbeats 256000000 in
/-- Functional non-vacuity: the compiled reconvergent composite recombines
to `x ⊕ y`, the XOR of the producer-fed secret and the tail-local secret —
not to the identity of a single input. -/
theorem realWork_recombines :
    recombinesTo realComposite.g
      (fun secrets => xor (secrets.getD 0 false) (secrets.getD 1 false)) := by
  rw [realComposite_g_eq]
  decide

/-! ## Non-degeneracy anchors

The accepted `forkJoin` branch gate computes `x ⊕ x`: it is identically
`false` on every admissible experiment environment.  Every internal gate of
the real-work tail, by contrast, attains both Boolean values across the
experiment environments.  Both facts are kernel-checked over the same
audited `envsForInput` experiment space. -/

/-- The accepted instance's branch gate is degenerate: identically `false`
in every admissible experiment environment. -/
theorem forkJoin_branch_degenerate :
    ∀ x ∈ boolVectors (inputWidth OPINIReuse.forkJoin),
      ∀ env ∈ envsForInput OPINIReuse.forkJoin x,
        Execution.eval OPINIReuse.forkJoinCircuit 3 env
          { gate := 2, cycle := 2 } = false := by
  decide

set_option maxRecDepth 10000 in
set_option maxHeartbeats 64000000 in
/-- No internal gate of the real-work tail is constant: each of the two
branches, the join, and both reconvergent outputs attain both Boolean
values over the audited experiment environments. -/
theorem realWork_gates_nonconstant :
    ∀ gate ∈ [5, 6, 7, 8, 9, 10, 11, 12],
      (∃ x ∈ boolVectors (inputWidth realWork),
        ∃ env ∈ envsForInput realWork x,
          Execution.eval realWorkCircuit 3 env
            { gate := gate, cycle := 2 } = true) ∧
      (∃ x ∈ boolVectors (inputWidth realWork),
        ∃ env ∈ envsForInput realWork x,
          Execution.eval realWorkCircuit 3 env
            { gate := gate, cycle := 2 } = false) := by
  decide

/-- The two branches do distinct work: there is an experiment environment on
which the `y`-mixing branch and the refresh branch differ. -/
theorem realWork_branches_distinct :
    ∃ x ∈ boolVectors (inputWidth realWork),
      ∃ env ∈ envsForInput realWork x,
        Execution.eval realWorkCircuit 3 env { gate := 5, cycle := 2 } ≠
          Execution.eval realWorkCircuit 3 env { gate := 7, cycle := 2 } := by
  decide

/-- The recombined function is non-trivial: it depends on the producer-fed
secret and on the tail-local secret. -/
theorem recombined_function_nontrivial :
    (fun secrets => xor (secrets.getD 0 false) (secrets.getD 1 false))
        [true, false] ≠
      (fun secrets => xor (secrets.getD 0 false) (secrets.getD 1 false))
        [false, false] ∧
    (fun secrets => xor (secrets.getD 0 false) (secrets.getD 1 false))
        [false, true] ≠
      (fun secrets => xor (secrets.getD 0 false) (secrets.getD 1 false))
        [false, false] := by
  decide

end OPINIRealWork
end Composition
end LeanSec
