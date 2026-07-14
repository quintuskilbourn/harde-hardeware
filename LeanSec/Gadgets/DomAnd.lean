import LeanSec.Gadget

namespace LeanSec.Gadgets.DomAnd

open Gadget

/- `GadgetInstance` represents one output sharing.  This file uses that supported
single-output shape only; it is not an encoding for a multi-output gadget. -/

/-- First-order two-share DOM-AND, transcribed from
`../security/dom_and.v`.  Gates 11--14 are the four distinct RTL registers. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },                    -- a0
      { kind := .inp 0 1, inputs := [] },                    -- a1
      { kind := .inp 1 0, inputs := [] },                    -- b0
      { kind := .inp 1 1, inputs := [] },                    -- b1
      { kind := .rnd 0, inputs := [] },                      -- z
      { kind := .and, inputs := [(0, 0), (2, 0)] },          -- p00
      { kind := .and, inputs := [(1, 0), (3, 0)] },          -- p11
      { kind := .and, inputs := [(0, 0), (3, 0)] },          -- a0 b1
      { kind := .xor, inputs := [(7, 0), (4, 0)] },          -- p01
      { kind := .and, inputs := [(1, 0), (2, 0)] },          -- a1 b0
      { kind := .xor, inputs := [(9, 0), (4, 0)] },          -- p10
      { kind := .reg, inputs := [(5, 1)] },                  -- r00
      { kind := .reg, inputs := [(6, 1)] },                  -- r11
      { kind := .reg, inputs := [(8, 1)] },                  -- r01
      { kind := .reg, inputs := [(10, 1)] },                 -- r10
      { kind := .xor, inputs := [(11, 0), (13, 0)] },        -- c0
      { kind := .xor, inputs := [(12, 0), (14, 0)] }         -- c1
    ] }

/-- The concrete two-cycle execution: sources and products at cycle zero,
registers and output XORs at cycle one. -/
def member (n : Node) : Bool :=
  (n.cycle == 0 && decide (n.gate < 11)) ||
  (n.cycle == 1 && decide (11 ≤ n.gate && n.gate < 17))

def gadget : GadgetInstance :=
  { circuit := circuit
    horizon := 2
    d := 2
    inputCount := 2
    inputArrival := fun sharing share => .inp sharing share 0
    output := fun share =>
      if share == 0 then { gate := 15, cycle := 1 }
      else { gate := 16, cycle := 1 }
    member := member
    randomness := [.rnd 0 0, .rnd 0 1] }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- The two-cycle schedule satisfies the member-boundary guard, including the
register-load (transition) closure conjunct added in the F1 repair — every
cycle-one register is loaded from a scheduled cycle-zero member. -/
theorem gadget_wf : gadget.WF := by
  refine ⟨circuit_wf, ?_⟩
  decide

/-- Functional-correctness guard: DOM-AND recombines to `a AND b` for every input
and every randomness assignment. -/
theorem recombines :
    recombinesTo gadget (fun s => s.getD 0 false && s.getD 1 false) := by decide

theorem secret_experiments_reached :
    ∀ secret ∈ boolVectors gadget.inputCount,
      (envsForSecret gadget secret).length > 0 := by
  set_option maxRecDepth 10000 in
    decide

theorem input_experiments_reached :
    ∀ x ∈ boolVectors (inputWidth gadget),
      (envsForInput gadget x).length > 0 := by
  set_option maxRecDepth 10000 in
    decide

set_option maxRecDepth 10000
set_option maxHeartbeats 4000000

/-- The required first-order glitch-robust probing-security anchor. -/
theorem glitch_probing_one : probingSecure gadget glitch 1 := by
  decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

/-- The anchor stated against the audited simulator specification. -/
theorem glitch_probing_one_spec : probingSecureSpec gadget glitch 1 := by
  exact (probingSecure_iff_spec gadget glitch 1
    secret_experiments_reached).mp glitch_probing_one

/- The four differential anchors below reproduce the ordinary SILVER property
profile for this same DOM-AND structure: NI and standard SNI pass, robust SNI
and standard PINI fail. -/

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

theorem standard_ni_one : ni gadget identity 1 := by
  decide

theorem standard_sni_one : sni gadget identity 1 := by
  decide

theorem not_glitch_sni_one : ¬sni gadget glitch 1 := by
  decide

theorem not_standard_pini_one : ¬pini gadget identity 1 := by
  unfold pini
  intro secure
  have insecure := secure.2
  revert insecure
  decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

theorem standard_ni_one_spec : niSpec gadget identity 1 := by
  exact (ni_iff_spec gadget identity 1 input_experiments_reached).mp
    standard_ni_one

theorem standard_sni_one_spec : sniSpec gadget identity 1 := by
  exact (sni_iff_spec gadget identity 1 input_experiments_reached).mp
    standard_sni_one

theorem not_glitch_sni_one_spec : ¬sniSpec gadget glitch 1 := by
  intro secure
  exact not_glitch_sni_one
    ((sni_iff_spec gadget glitch 1 input_experiments_reached).mpr secure)

theorem not_standard_pini_one_spec : ¬piniSpec gadget identity 1 := by
  intro secure
  exact not_standard_pini_one
    ((pini_iff_spec gadget identity 1 input_experiments_reached).mpr secure)

/-- The output is uniform over the two sharings of the correct product. -/
theorem output_uniform : outputUniform gadget := by
  decide

theorem output_uniform_spec : outputUniformSpec gadget := by
  exact (outputUniform_iff_spec gadget).mp output_uniform

/- Moving each output XOR across the register barrier exposes a same-cycle
share recombination to glitch expansion.  The two XORs are therefore member
nodes at cycle zero, while only their output registers live at cycle one. -/
namespace XBR

def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },                    -- a0
      { kind := .inp 0 1, inputs := [] },                    -- a1
      { kind := .inp 1 0, inputs := [] },                    -- b0
      { kind := .inp 1 1, inputs := [] },                    -- b1
      { kind := .rnd 0, inputs := [] },                      -- z
      { kind := .and, inputs := [(0, 0), (2, 0)] },          -- p00
      { kind := .and, inputs := [(1, 0), (3, 0)] },          -- p11
      { kind := .and, inputs := [(0, 0), (3, 0)] },          -- a0 b1
      { kind := .xor, inputs := [(7, 0), (4, 0)] },          -- p01
      { kind := .and, inputs := [(1, 0), (2, 0)] },          -- a1 b0
      { kind := .xor, inputs := [(9, 0), (4, 0)] },          -- p10
      { kind := .xor, inputs := [(5, 0), (8, 0)] },          -- c0, before reg
      { kind := .xor, inputs := [(6, 0), (10, 0)] },         -- c1, before reg
      { kind := .reg, inputs := [(11, 1)] },                 -- registered c0
      { kind := .reg, inputs := [(12, 1)] }                  -- registered c1
    ] }

def member (n : Node) : Bool :=
  (n.cycle == 0 && decide (n.gate < 13)) ||
  (n.cycle == 1 && decide (13 ≤ n.gate && n.gate < 15))

def gadget : GadgetInstance :=
  { circuit := circuit
    horizon := 2
    d := 2
    inputCount := 2
    inputArrival := fun sharing share => .inp sharing share 0
    output := fun share =>
      if share == 0 then { gate := 13, cycle := 1 }
      else { gate := 14, cycle := 1 }
    member := member
    randomness := [.rnd 0 0, .rnd 0 1] }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

theorem secret_experiments_reached :
    ∀ secret ∈ boolVectors gadget.inputCount,
      (envsForSecret gadget secret).length > 0 := by
  set_option maxRecDepth 10000 in
    decide

theorem input_experiments_reached :
    ∀ x ∈ boolVectors (inputWidth gadget),
      (envsForInput gadget x).length > 0 := by
  set_option maxRecDepth 10000 in
    decide

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

/-- Moving the output XOR before its register breaks first-order
glitch-robust probing security. -/
theorem not_probing : ¬probingSecure gadget glitch 1 := by
  decide

/-- The same barrier mutant also fails first-order glitch-robust PINI. -/
theorem not_pini : ¬pini gadget glitch 1 := by
  unfold pini
  intro secure
  have insecure := secure.2
  revert insecure
  decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

theorem not_probing_spec :
    ¬probingSecureSpec gadget glitch 1 := by
  intro secure
  exact not_probing
    ((probingSecure_iff_spec gadget glitch 1
      secret_experiments_reached).mpr secure)

theorem not_pini_spec : ¬piniSpec gadget glitch 1 := by
  intro secure
  exact not_pini
    ((pini_iff_spec gadget glitch 1 input_experiments_reached).mpr secure)

end XBR

namespace NaiveAnd

def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .and, inputs := [(0, 0), (1, 0)] }
    ] }

def gadget : GadgetInstance :=
  { circuit := circuit
    horizon := 1
    d := 1
    inputCount := 2
    inputArrival := fun sharing _ => .inp sharing 0 0
    output := fun _ => { gate := 2, cycle := 0 }
    member := fun n => n.cycle == 0 && decide (n.gate < 3)
    randomness := [] }

theorem secret_experiments_reached :
    ∀ secret ∈ boolVectors gadget.inputCount,
      (envsForSecret gadget secret).length > 0 := by
  decide

/-- A single probe of the unmasked AND is secret-dependent. -/
theorem not_glitch_probing_one : ¬probingSecure gadget glitch 1 := by
  decide

theorem not_glitch_probing_one_spec :
    ¬probingSecureSpec gadget glitch 1 := by
  intro secure
  exact not_glitch_probing_one
    ((probingSecure_iff_spec gadget glitch 1
      secret_experiments_reached).mpr secure)

end NaiveAnd

end LeanSec.Gadgets.DomAnd
