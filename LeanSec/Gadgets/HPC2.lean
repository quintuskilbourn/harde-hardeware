import LeanSec.Gadget

namespace LeanSec.Gadgets.HPC2

open Gadget

/- `GadgetInstance` represents one output sharing.  This file uses that supported
single-output shape only; it is not an encoding for a multi-output gadget. -/

/-- First-order two-share HPC2, transcribed literally from [CS21] Algorithm 1.
The source arrival cycles make the pipeline explicit: `b` and `r` arrive at
cycle zero, `a` arrives at cycle one, and the output is produced at cycle two. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },                    -- a0
      { kind := .inp 0 1, inputs := [] },                    -- a1
      { kind := .inp 1 0, inputs := [] },                    -- b0
      { kind := .inp 1 1, inputs := [] },                    -- b1
      { kind := .rnd 0, inputs := [] },                      -- r01 = r10
      { kind := .reg, inputs := [(4, 1)] },                  -- Reg[r]
      { kind := .not, inputs := [(0, 0)] },                  -- not a0
      { kind := .and, inputs := [(6, 0), (5, 0)] },          -- u01
      { kind := .xor, inputs := [(3, 0), (4, 0)] },          -- v01 = b1 xor r
      { kind := .not, inputs := [(1, 0)] },                  -- not a1
      { kind := .and, inputs := [(9, 0), (5, 0)] },          -- u10
      { kind := .xor, inputs := [(2, 0), (4, 0)] },          -- v10 = b0 xor r
      { kind := .reg, inputs := [(2, 1)] },                  -- Reg[b0]
      { kind := .reg, inputs := [(3, 1)] },                  -- Reg[b1]
      { kind := .reg, inputs := [(7, 1)] },                  -- Reg[u01]
      { kind := .reg, inputs := [(8, 1)] },                  -- Reg[v01]
      { kind := .reg, inputs := [(10, 1)] },                 -- Reg[u10]
      { kind := .reg, inputs := [(11, 1)] },                 -- Reg[v10]
      { kind := .and, inputs := [(0, 0), (12, 0)] },         -- a0 Reg[b0]
      { kind := .reg, inputs := [(18, 1)] },                 -- Reg[a0 Reg[b0]]
      { kind := .and, inputs := [(0, 0), (15, 0)] },         -- a0 Reg[v01]
      { kind := .reg, inputs := [(20, 1)] },                 -- Reg[a0 Reg[v01]]
      { kind := .and, inputs := [(1, 0), (13, 0)] },         -- a1 Reg[b1]
      { kind := .reg, inputs := [(22, 1)] },                 -- Reg[a1 Reg[b1]]
      { kind := .and, inputs := [(1, 0), (17, 0)] },         -- a1 Reg[v10]
      { kind := .reg, inputs := [(24, 1)] },                 -- Reg[a1 Reg[v10]]
      { kind := .xor, inputs := [(19, 0), (14, 0)] },
      { kind := .xor, inputs := [(26, 0), (21, 0)] },        -- c0
      { kind := .xor, inputs := [(23, 0), (16, 0)] },
      { kind := .xor, inputs := [(28, 0), (25, 0)] }         -- c1
    ] }

/-- Nodes belonging to the concrete three-cycle HPC2 execution. -/
def member (n : Node) : Bool :=
  (n.cycle == 0 && [2, 3, 4, 8, 11].contains n.gate) ||
  (n.cycle == 1 &&
    [0, 1, 5, 6, 7, 9, 10, 12, 13, 15, 17, 18, 20, 22, 24].contains n.gate) ||
  (n.cycle == 2 && [14, 16, 19, 21, 23, 25, 26, 27, 28, 29].contains n.gate)

def gadget : GadgetInstance :=
  { circuit := circuit
    horizon := 3
    d := 2
    inputCount := 2
    inputArrival := fun sharing share =>
      if sharing == 0 then .inp sharing share 1 else .inp sharing share 0
    output := fun share =>
      if share == 0 then { gate := 27, cycle := 2 }
      else { gate := 29, cycle := 2 }
    member := member
    randomness := [.rnd 0 0, .rnd 0 1, .rnd 0 2] }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- The literal HPC2 execution satisfies the predicate boundary guard: its
outputs are distinct members and every member's combinational cone stays
inside the execution. -/
theorem gadget_wf : gadget.WF := by
  refine ⟨circuit_wf, ?_⟩
  decide

/-- Functional-correctness guard: HPC2 recombines to `a AND b` for every input
and every randomness assignment. -/
theorem recombines :
    recombinesTo gadget (fun s => s.getD 0 false && s.getD 1 false) := by decide

theorem input_experiments_reached :
    ∀ x ∈ boolVectors (inputWidth gadget),
      (envsForInput gadget x).length > 0 := by
  set_option maxRecDepth 10000 in
    decide

theorem secret_experiments_reached :
    ∀ secret ∈ boolVectors gadget.inputCount,
      (envsForSecret gadget secret).length > 0 := by
  set_option maxRecDepth 10000 in
    decide

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

/-- First-order glitch-robust PINI for the literal HPC2 circuit. -/
theorem glitch_pini_one : pini gadget glitch 1 := by
  refine ⟨gadget_wf, ?_⟩
  decide

/-- HPC2 is PINI but not O-PINI already at first order for this two-share
instance, providing a kernel-checked falsification guard for the stronger
predicate. -/
theorem not_glitch_opini_one : ¬opini gadget glitch 1 := by
  unfold opini
  intro secure
  have insecure := secure.2
  revert insecure
  decide

/-- First-order glitch-robust probing security for the same literal circuit. -/
theorem glitch_probing_one : probingSecure gadget glitch 1 := by
  decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

/-- The positive anchor against the audited simulator specification. -/
theorem glitch_pini_one_spec : piniSpec gadget glitch 1 := by
  exact (pini_iff_spec gadget glitch 1 input_experiments_reached).mp
    glitch_pini_one

theorem not_glitch_opini_one_spec : ¬opiniSpec gadget glitch 1 := by
  intro secure
  exact not_glitch_opini_one
    ((opini_iff_spec gadget glitch 1 input_experiments_reached).mpr secure)

theorem glitch_probing_one_spec : probingSecureSpec gadget glitch 1 := by
  exact (probingSecure_iff_spec gadget glitch 1
    secret_experiments_reached).mp glitch_probing_one

/-- The literal HPC2 output is uniform over the two sharings of the correct
product, independently checked here after the supplied SILVER binary crashed
in its final uniformity phase. -/
theorem output_uniform : outputUniform gadget := by
  decide

theorem output_uniform_spec : outputUniformSpec gadget := by
  exact (outputUniform_iff_spec gadget).mp output_uniform

namespace DroppedRefresh

/-- Mutant of Algorithm 1 with the `r` refresh removed from both `v_ij` paths.
Gate 30 is public zero; the `r` path feeding `u_ij` remains intact. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] },
      { kind := .inp 1 1, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .reg, inputs := [(4, 1)] },
      { kind := .not, inputs := [(0, 0)] },
      { kind := .and, inputs := [(6, 0), (5, 0)] },
      { kind := .xor, inputs := [(3, 0), (30, 0)] },
      { kind := .not, inputs := [(1, 0)] },
      { kind := .and, inputs := [(9, 0), (5, 0)] },
      { kind := .xor, inputs := [(2, 0), (30, 0)] },
      { kind := .reg, inputs := [(2, 1)] },
      { kind := .reg, inputs := [(3, 1)] },
      { kind := .reg, inputs := [(7, 1)] },
      { kind := .reg, inputs := [(8, 1)] },
      { kind := .reg, inputs := [(10, 1)] },
      { kind := .reg, inputs := [(11, 1)] },
      { kind := .and, inputs := [(0, 0), (12, 0)] },
      { kind := .reg, inputs := [(18, 1)] },
      { kind := .and, inputs := [(0, 0), (15, 0)] },
      { kind := .reg, inputs := [(20, 1)] },
      { kind := .and, inputs := [(1, 0), (13, 0)] },
      { kind := .reg, inputs := [(22, 1)] },
      { kind := .and, inputs := [(1, 0), (17, 0)] },
      { kind := .reg, inputs := [(24, 1)] },
      { kind := .xor, inputs := [(19, 0), (14, 0)] },
      { kind := .xor, inputs := [(26, 0), (21, 0)] },
      { kind := .xor, inputs := [(23, 0), (16, 0)] },
      { kind := .xor, inputs := [(28, 0), (25, 0)] },
      { kind := .const false, inputs := [] }
    ] }

def member (n : Node) : Bool :=
  (n.cycle == 0 && [2, 3, 4, 8, 11, 30].contains n.gate) ||
  (n.cycle == 1 &&
    [0, 1, 5, 6, 7, 9, 10, 12, 13, 15, 17, 18, 20, 22, 24].contains n.gate) ||
  (n.cycle == 2 && [14, 16, 19, 21, 23, 25, 26, 27, 28, 29].contains n.gate)

def gadget : GadgetInstance :=
  { circuit := circuit
    horizon := 3
    d := 2
    inputCount := 2
    inputArrival := fun sharing share =>
      if sharing == 0 then .inp sharing share 1 else .inp sharing share 0
    output := fun share =>
      if share == 0 then { gate := 27, cycle := 2 }
      else { gate := 29, cycle := 2 }
    member := member
    randomness := [.rnd 0 0, .rnd 0 1, .rnd 0 2] }

theorem input_experiments_reached :
    ∀ x ∈ boolVectors (inputWidth gadget),
      (envsForInput gadget x).length > 0 := by
  set_option maxRecDepth 10000 in
    decide

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

/-- Removing the refresh from `v_ij` destroys first-order glitch PINI. -/
theorem not_pini : ¬pini gadget glitch 1 := by
  unfold pini
  intro secure
  have insecure := secure.2
  revert insecure
  decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

theorem not_pini_spec : ¬piniSpec gadget glitch 1 := by
  intro secure
  exact not_pini
    ((pini_iff_spec gadget glitch 1 input_experiments_reached).mpr secure)

end DroppedRefresh

end LeanSec.Gadgets.HPC2
