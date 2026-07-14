import LeanSec.Gadgets.HPC2

namespace LeanSec.Gadgets.OPINI2

open Gadget

/- `GadgetInstance` represents one output sharing.  The circuits below use that
supported single-output shape only. -/

/-- Algorithm 3 at two shares: the HPC2 result is refreshed by one zero-sharing
bit.  Although `s1 = s0`, gates 31 and 32 are distinct physical registers. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] }, { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] }, { kind := .inp 1 1, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .reg, inputs := [(4, 1)] },
      { kind := .not, inputs := [(0, 0)] },
      { kind := .and, inputs := [(6, 0), (5, 0)] },
      { kind := .xor, inputs := [(3, 0), (4, 0)] },
      { kind := .not, inputs := [(1, 0)] },
      { kind := .and, inputs := [(9, 0), (5, 0)] },
      { kind := .xor, inputs := [(2, 0), (4, 0)] },
      { kind := .reg, inputs := [(2, 1)] }, { kind := .reg, inputs := [(3, 1)] },
      { kind := .reg, inputs := [(7, 1)] }, { kind := .reg, inputs := [(8, 1)] },
      { kind := .reg, inputs := [(10, 1)] }, { kind := .reg, inputs := [(11, 1)] },
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
      { kind := .rnd 1, inputs := [] },
      { kind := .reg, inputs := [(30, 1)] },
      { kind := .reg, inputs := [(30, 1)] },
      { kind := .xor, inputs := [(27, 0), (31, 0)] },
      { kind := .reg, inputs := [(33, 1)] },
      { kind := .xor, inputs := [(29, 0), (32, 0)] },
      { kind := .reg, inputs := [(35, 1)] }
    ] }

/- F1 repair 2026-07-13: gate 30 (`rnd 1`, the refresh mask wire) added at
cycle 1 — the free draw that `Reg[s0]`/`Reg[s1]` (gates 31/32, members at
cycle 2) load across the cycle-1→2 boundary was not itself a member, so it
was invisible to probes and dropped from register-load closure
(`transInputNodes`). -/
def member (n : Node) : Bool :=
  (n.cycle == 0 && [2, 3, 4, 8, 11, 30].contains n.gate) ||
  (n.cycle == 1 &&
    [0, 1, 5, 6, 7, 9, 10, 12, 13, 15, 17, 18, 20, 22, 24, 30, 31, 32].contains n.gate) ||
  (n.cycle == 2 &&
    [14, 16, 19, 21, 23, 25, 26, 27, 28, 29, 31, 32, 33, 35].contains n.gate) ||
  (n.cycle == 3 && [34, 36].contains n.gate)

def gadget : GadgetInstance :=
  { circuit := circuit, horizon := 4, d := 2, inputCount := 2
    inputArrival := fun sharing share =>
      if sharing == 0 then .inp sharing share 1 else .inp sharing share 0
    output := fun share =>
      if share == 0 then { gate := 34, cycle := 3 } else { gate := 36, cycle := 3 }
    member := member
    randomness := [.rnd 0 0, .rnd 1 0, .rnd 1 1] }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

theorem gadget_wf : gadget.WF := by
  refine ⟨circuit_wf, ?_⟩
  decide

/-- Functional-correctness guard: the registered O-PINI2 refresh is a zero
sharing, so the two outputs still recombine to `a AND b`. -/
theorem recombines :
    recombinesTo gadget (fun s => s.getD 0 false && s.getD 1 false) := by decide

theorem input_experiments_reached :
    ∀ x ∈ boolVectors (inputWidth gadget), (envsForInput gadget x).length > 0 := by
  set_option maxRecDepth 10000 in decide

set_option maxRecDepth 10000
set_option maxHeartbeats 12000000

/-- Algorithm 3 retains first-order glitch-robust PINI. -/
theorem glitch_pini_one : pini gadget glitch 1 := by
  refine ⟨gadget_wf, ?_⟩
  decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

theorem glitch_pini_one_spec : piniSpec gadget glitch 1 := by
  exact (pini_iff_spec gadget glitch 1 input_experiments_reached).mp glitch_pini_one

/-- The refreshed O-PINI2 output is uniform over the two sharings of the
correct product.  Both cycle-indexed instances of the pipelined refresh source
are free in the experiment. -/
theorem output_uniform : outputUniform gadget := by
  decide

theorem output_uniform_spec : outputUniformSpec gadget := by
  exact (outputUniform_iff_spec gadget).mp output_uniform

namespace Chains

/-- The physical HPC2 core with serial feedback selected by public control 0.
Cycles 0--2 execute `x*y`; cycles 3--5 execute `c*z` on the same gates. -/
def serialHPC2Circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] }, { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] }, { kind := .inp 1 1, inputs := [] },
      { kind := .inp 2 0, inputs := [] }, { kind := .inp 2 1, inputs := [] },
      { kind := .ctl 0, inputs := [] },
      { kind := .mux, inputs := [(6, 0), (0, 0), (38, 0)] },
      { kind := .mux, inputs := [(6, 0), (1, 0), (40, 0)] },
      { kind := .mux, inputs := [(6, 0), (2, 0), (4, 0)] },
      { kind := .mux, inputs := [(6, 0), (3, 0), (5, 0)] },
      { kind := .rnd 0, inputs := [] }, { kind := .reg, inputs := [(11, 1)] },
      { kind := .not, inputs := [(7, 0)] },
      { kind := .and, inputs := [(13, 0), (12, 0)] },
      { kind := .xor, inputs := [(10, 0), (11, 0)] },
      { kind := .not, inputs := [(8, 0)] },
      { kind := .and, inputs := [(16, 0), (12, 0)] },
      { kind := .xor, inputs := [(9, 0), (11, 0)] },
      { kind := .reg, inputs := [(9, 1)] }, { kind := .reg, inputs := [(10, 1)] },
      { kind := .reg, inputs := [(14, 1)] }, { kind := .reg, inputs := [(15, 1)] },
      { kind := .reg, inputs := [(17, 1)] }, { kind := .reg, inputs := [(18, 1)] },
      { kind := .and, inputs := [(7, 0), (19, 0)] },
      { kind := .reg, inputs := [(25, 1)] },
      { kind := .and, inputs := [(7, 0), (22, 0)] },
      { kind := .reg, inputs := [(27, 1)] },
      { kind := .and, inputs := [(8, 0), (20, 0)] },
      { kind := .reg, inputs := [(29, 1)] },
      { kind := .and, inputs := [(8, 0), (24, 0)] },
      { kind := .reg, inputs := [(31, 1)] },
      { kind := .xor, inputs := [(26, 0), (21, 0)] },
      { kind := .xor, inputs := [(33, 0), (28, 0)] },
      { kind := .xor, inputs := [(30, 0), (23, 0)] },
      { kind := .xor, inputs := [(35, 0), (32, 0)] },
      { kind := .reg, inputs := [(34, 1)] },
      { kind := .reg, inputs := [(37, 1)] },
      { kind := .reg, inputs := [(36, 1)] },
      { kind := .reg, inputs := [(39, 1)] }
    ] }

def controls : List (Src × Bool) :=
  [(.ctl 0 0, false), (.ctl 0 1, false), (.ctl 0 2, false),
   (.ctl 0 3, true), (.ctl 0 4, true), (.ctl 0 5, true)]

/- F1 repair 2026-07-13: the whitelist was not closed under same-cycle
combinational predecessors — the mux gates (7-10) are members whenever probed
stages read them, and a glitch expansion of a mux exposes ALL its latency-0
input wires regardless of the public select, so every mux input wire must be
scheduled at those cycles.  Added: the inactive-side input wires
(4,5)@0, (2,3,4,5)@2, (2,3)@3, (0,1)@4 and the feedback wires (38,40)@1,
whose register loads in turn demand (37,39)@0 (`transInputNodes` closure). -/
def serialHPC2Member (n : Node) : Bool :=
  (n.cycle == 0 && [2, 3, 4, 5, 6, 9, 10, 11, 15, 18, 37, 39].contains n.gate) ||
  (n.cycle == 1 &&
    [0, 1, 6, 7, 8, 12, 13, 14, 16, 17, 19, 20, 22, 24, 25, 27, 29, 31, 38, 40].contains n.gate) ||
  (n.cycle == 2 &&
    [2, 3, 4, 5, 6, 9, 10, 11, 15, 18, 21, 23, 26, 28, 30, 32, 33, 34, 35, 36].contains n.gate) ||
  (n.cycle == 3 && [2, 3, 4, 5, 6, 9, 10, 11, 15, 18, 37, 39].contains n.gate) ||
  (n.cycle == 4 &&
    [0, 1, 6, 7, 8, 12, 13, 14, 16, 17, 19, 20, 22, 24, 25, 27, 29, 31, 38, 40].contains n.gate) ||
  (n.cycle == 5 && [21, 23, 26, 28, 30, 32, 33, 34, 35, 36].contains n.gate)

def serialHPC2 : GadgetInstance :=
  { circuit := serialHPC2Circuit, horizon := 6, d := 2, inputCount := 3
    inputArrival := fun sharing share =>
      if sharing == 0 then .inp sharing share 1
      else if sharing == 1 then .inp sharing share 0
      else .inp sharing share 3
    output := fun share =>
      if share == 0 then { gate := 34, cycle := 5 } else { gate := 36, cycle := 5 }
    member := serialHPC2Member
    randomness := [.rnd 0 0, .rnd 0 3]
    publicFixing := controls }

/-- Algorithm 3 wrapped around the same serially reused HPC2 core.  Gates 38
and 39 are the required distinct `Reg[s_i]` instances. -/
def serialOPINI2Circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] }, { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] }, { kind := .inp 1 1, inputs := [] },
      { kind := .inp 2 0, inputs := [] }, { kind := .inp 2 1, inputs := [] },
      { kind := .ctl 0, inputs := [] },
      { kind := .mux, inputs := [(6, 0), (0, 0), (44, 0)] },
      { kind := .mux, inputs := [(6, 0), (1, 0), (45, 0)] },
      { kind := .mux, inputs := [(6, 0), (2, 0), (4, 0)] },
      { kind := .mux, inputs := [(6, 0), (3, 0), (5, 0)] },
      { kind := .rnd 0, inputs := [] }, { kind := .reg, inputs := [(11, 1)] },
      { kind := .not, inputs := [(7, 0)] }, { kind := .and, inputs := [(13, 0), (12, 0)] },
      { kind := .xor, inputs := [(10, 0), (11, 0)] },
      { kind := .not, inputs := [(8, 0)] }, { kind := .and, inputs := [(16, 0), (12, 0)] },
      { kind := .xor, inputs := [(9, 0), (11, 0)] },
      { kind := .reg, inputs := [(9, 1)] }, { kind := .reg, inputs := [(10, 1)] },
      { kind := .reg, inputs := [(14, 1)] }, { kind := .reg, inputs := [(15, 1)] },
      { kind := .reg, inputs := [(17, 1)] }, { kind := .reg, inputs := [(18, 1)] },
      { kind := .and, inputs := [(7, 0), (19, 0)] }, { kind := .reg, inputs := [(25, 1)] },
      { kind := .and, inputs := [(7, 0), (22, 0)] }, { kind := .reg, inputs := [(27, 1)] },
      { kind := .and, inputs := [(8, 0), (20, 0)] }, { kind := .reg, inputs := [(29, 1)] },
      { kind := .and, inputs := [(8, 0), (24, 0)] }, { kind := .reg, inputs := [(31, 1)] },
      { kind := .xor, inputs := [(26, 0), (21, 0)] }, { kind := .xor, inputs := [(33, 0), (28, 0)] },
      { kind := .xor, inputs := [(30, 0), (23, 0)] }, { kind := .xor, inputs := [(35, 0), (32, 0)] },
      { kind := .rnd 1, inputs := [] },
      { kind := .reg, inputs := [(37, 1)] }, { kind := .reg, inputs := [(37, 1)] },
      { kind := .xor, inputs := [(34, 0), (38, 0)] }, { kind := .reg, inputs := [(40, 1)] },
      { kind := .xor, inputs := [(36, 0), (39, 0)] }, { kind := .reg, inputs := [(42, 1)] },
      { kind := .reg, inputs := [(41, 1)] }, { kind := .reg, inputs := [(43, 1)] }
    ] }

/- F1 repair 2026-07-13.  The previous member reused `serialHPC2Member`
verbatim, although gates 37-40 mean different things in the two circuits
(serial-HPC2: output/feedback delay registers; here: `rnd 1`, the two
`Reg[s_i]`, and a refresh XOR).  That index collision (a) omitted the
codex-found hole — the refresh XORs (40,42)@2 read `Reg[s_i]` (38,39)@2,
which were not members, so their glitch frontier was silently dropped — and
(b) smuggled in two junk nodes, (39,3) and (40,4), that are not part of this
circuit's schedule (REMOVED here; (40,4)'s combinational cone alone would
otherwise drag ~30 mid-pipeline nodes into the boundary).  The inheritance is
now restricted to the genuinely shared gates 0-36 and the refresh/feedback
gates 37-45 get an explicit schedule, closed under `combInputNodes` and
`transInputNodes` (kernel-checked by `serial_opini2_wf`). -/
def serialOPINI2 : GadgetInstance :=
  { circuit := serialOPINI2Circuit, horizon := 7, d := 2, inputCount := 3
    inputArrival := serialHPC2.inputArrival
    output := fun share =>
      if share == 0 then { gate := 41, cycle := 6 } else { gate := 43, cycle := 6 }
    member := fun n => (n.gate < 37 && serialHPC2Member n) ||
      (n.cycle == 0 && [37, 41, 43].contains n.gate) ||
      (n.cycle == 1 && [37, 38, 39, 44, 45].contains n.gate) ||
      (n.cycle == 2 && [38, 39, 40, 42].contains n.gate) ||
      (n.cycle == 3 && [37, 41, 43].contains n.gate) ||
      (n.cycle == 4 && [37, 38, 39, 44, 45].contains n.gate) ||
      (n.cycle == 5 && [38, 39, 40, 42].contains n.gate) ||
      (n.cycle == 6 && [41, 43].contains n.gate)
    randomness := [.rnd 0 0, .rnd 1 1, .rnd 0 3, .rnd 1 4]
    publicFixing := controls }

/-- Parallel control: the second execution receives an independent `x2,z`
pair rather than feeding back the first result. -/
def parallelHPC2Circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] }, { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] }, { kind := .inp 1 1, inputs := [] },
      { kind := .inp 2 0, inputs := [] }, { kind := .inp 2 1, inputs := [] },
      { kind := .inp 3 0, inputs := [] }, { kind := .inp 3 1, inputs := [] },
      { kind := .ctl 0, inputs := [] },
      { kind := .mux, inputs := [(8, 0), (0, 0), (4, 0)] },
      { kind := .mux, inputs := [(8, 0), (1, 0), (5, 0)] },
      { kind := .mux, inputs := [(8, 0), (2, 0), (6, 0)] },
      { kind := .mux, inputs := [(8, 0), (3, 0), (7, 0)] },
      { kind := .rnd 0, inputs := [] }, { kind := .reg, inputs := [(13, 1)] },
      { kind := .not, inputs := [(9, 0)] }, { kind := .and, inputs := [(15, 0), (14, 0)] },
      { kind := .xor, inputs := [(12, 0), (13, 0)] },
      { kind := .not, inputs := [(10, 0)] }, { kind := .and, inputs := [(18, 0), (14, 0)] },
      { kind := .xor, inputs := [(11, 0), (13, 0)] },
      { kind := .reg, inputs := [(11, 1)] }, { kind := .reg, inputs := [(12, 1)] },
      { kind := .reg, inputs := [(16, 1)] }, { kind := .reg, inputs := [(17, 1)] },
      { kind := .reg, inputs := [(19, 1)] }, { kind := .reg, inputs := [(20, 1)] },
      { kind := .and, inputs := [(9, 0), (21, 0)] }, { kind := .reg, inputs := [(27, 1)] },
      { kind := .and, inputs := [(9, 0), (24, 0)] }, { kind := .reg, inputs := [(29, 1)] },
      { kind := .and, inputs := [(10, 0), (22, 0)] }, { kind := .reg, inputs := [(31, 1)] },
      { kind := .and, inputs := [(10, 0), (26, 0)] }, { kind := .reg, inputs := [(33, 1)] },
      { kind := .xor, inputs := [(28, 0), (23, 0)] }, { kind := .xor, inputs := [(35, 0), (30, 0)] },
      { kind := .xor, inputs := [(32, 0), (25, 0)] }, { kind := .xor, inputs := [(37, 0), (34, 0)] }
    ] }

def parallelHPC2 : GadgetInstance :=
  { circuit := parallelHPC2Circuit, horizon := 6, d := 2, inputCount := 4
    inputArrival := fun sharing share =>
      if sharing == 0 then .inp sharing share 1
      else if sharing == 1 then .inp sharing share 0
      else if sharing == 2 then .inp sharing share 4
      else .inp sharing share 3
    output := fun share =>
      if share == 0 then { gate := 36, cycle := 5 } else { gate := 38, cycle := 5 }
    /- F1 repair 2026-07-13: same mux-wire closure omission as
    `serialHPC2Member` — added the inactive-side mux input wires (6,7)@0,
    (4,5)@1, (2,3,6,7)@2, (2,3)@3, (0,1)@4. -/
    member := fun n =>
      (n.cycle == 0 && [2, 3, 6, 7, 8, 11, 12, 13, 17, 20].contains n.gate) ||
      (n.cycle == 1 &&
        [0, 1, 4, 5, 8, 9, 10, 14, 15, 16, 18, 19, 21, 22, 24, 26, 27, 29, 31, 33].contains n.gate) ||
      (n.cycle == 2 &&
        [2, 3, 6, 7, 8, 11, 12, 13, 17, 20, 23, 25, 28, 30, 32, 34, 35, 36, 37, 38].contains n.gate) ||
      (n.cycle == 3 && [2, 3, 6, 7, 8, 11, 12, 13, 17, 20].contains n.gate) ||
      (n.cycle == 4 &&
        [0, 1, 4, 5, 8, 9, 10, 14, 15, 16, 18, 19, 21, 22, 24, 26, 27, 29, 31, 33].contains n.gate) ||
      (n.cycle == 5 && [23, 25, 28, 30, 32, 34, 35, 36, 37, 38].contains n.gate)
    randomness := [.rnd 0 0, .rnd 0 3]
    publicFixing := controls }

set_option maxRecDepth 10000
set_option maxHeartbeats 4000000

theorem serial_hpc2_circuit_wf : serialHPC2Circuit.WF := by
  simp [serialHPC2Circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

theorem serial_opini2_circuit_wf : serialOPINI2Circuit.WF := by
  simp [serialOPINI2Circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

theorem parallel_hpc2_circuit_wf : parallelHPC2Circuit.WF := by
  simp [parallelHPC2Circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/- Anti-vacuity guards for the chain member whitelists (audit finding F1):
the boundary each whole-circuit probing statement quantifies over is now
kernel-checked to be closed under glitch (combinational) and register-load
(transition) predecessors, instead of being trusted.  These are exactly the
checks that would have rejected the pre-repair `serialOPINI2` whitelist. -/

theorem serial_hpc2_wf : serialHPC2.WF := by
  refine ⟨serial_hpc2_circuit_wf, ?_⟩
  decide

theorem serial_opini2_wf : serialOPINI2.WF := by
  refine ⟨serial_opini2_circuit_wf, ?_⟩
  decide

theorem parallel_hpc2_wf : parallelHPC2.WF := by
  refine ⟨parallel_hpc2_circuit_wf, ?_⟩
  decide

set_option maxRecDepth 1000
set_option maxHeartbeats 200000

set_option maxRecDepth 30000
set_option maxHeartbeats 50000000

/- The chain-scale functional-correctness (recombine) anchors
`serial_hpc2_recombines` / `serial_opini2_recombines` /
`parallel_hpc2_recombines` live in `LeanSec/Gadgets/OPINI2Recombines.lean`
(still in the default gate via `test/Anchors.lean`): their kernel `decide`s
peak >25 GB each, and stacked on this module's own elaboration they OOM a
30 GB host — split 2026-07-13 during the F1 repair so the default build
elaborates one heavy decide per process. -/

/- Reusing the first execution's HPC2 mask in the second execution.  Gates
44--46 retain the cycle-zero `r` for three cycles, and gate 47 selects it when
the public serial-execution control changes.  The O-PINI refresh mask `s`
remains fresh at cycles zero and three. -/
namespace StaleR

def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] }, { kind := .inp 0 1, inputs := [] },
      { kind := .inp 1 0, inputs := [] }, { kind := .inp 1 1, inputs := [] },
      { kind := .inp 2 0, inputs := [] }, { kind := .inp 2 1, inputs := [] },
      { kind := .ctl 0, inputs := [] },
      { kind := .mux, inputs := [(6, 0), (0, 0), (41, 0)] },
      { kind := .mux, inputs := [(6, 0), (1, 0), (43, 0)] },
      { kind := .mux, inputs := [(6, 0), (2, 0), (4, 0)] },
      { kind := .mux, inputs := [(6, 0), (3, 0), (5, 0)] },
      { kind := .rnd 0, inputs := [] }, { kind := .reg, inputs := [(47, 1)] },
      { kind := .not, inputs := [(7, 0)] }, { kind := .and, inputs := [(13, 0), (12, 0)] },
      { kind := .xor, inputs := [(10, 0), (47, 0)] },
      { kind := .not, inputs := [(8, 0)] }, { kind := .and, inputs := [(16, 0), (12, 0)] },
      { kind := .xor, inputs := [(9, 0), (47, 0)] },
      { kind := .reg, inputs := [(9, 1)] }, { kind := .reg, inputs := [(10, 1)] },
      { kind := .reg, inputs := [(14, 1)] }, { kind := .reg, inputs := [(15, 1)] },
      { kind := .reg, inputs := [(17, 1)] }, { kind := .reg, inputs := [(18, 1)] },
      { kind := .and, inputs := [(7, 0), (19, 0)] }, { kind := .reg, inputs := [(25, 1)] },
      { kind := .and, inputs := [(7, 0), (22, 0)] }, { kind := .reg, inputs := [(27, 1)] },
      { kind := .and, inputs := [(8, 0), (20, 0)] }, { kind := .reg, inputs := [(29, 1)] },
      { kind := .and, inputs := [(8, 0), (24, 0)] }, { kind := .reg, inputs := [(31, 1)] },
      { kind := .xor, inputs := [(26, 0), (21, 0)] }, { kind := .xor, inputs := [(33, 0), (28, 0)] },
      { kind := .xor, inputs := [(30, 0), (23, 0)] }, { kind := .xor, inputs := [(35, 0), (32, 0)] },
      { kind := .rnd 1, inputs := [] },
      { kind := .reg, inputs := [(37, 1)] }, { kind := .reg, inputs := [(37, 1)] },
      { kind := .xor, inputs := [(34, 0), (38, 0)] }, { kind := .reg, inputs := [(40, 1)] },
      { kind := .xor, inputs := [(36, 0), (39, 0)] }, { kind := .reg, inputs := [(42, 1)] },
      { kind := .reg, inputs := [(11, 1)] },
      { kind := .reg, inputs := [(44, 1)] },
      { kind := .reg, inputs := [(45, 1)] },
      { kind := .mux, inputs := [(6, 0), (11, 0), (46, 0)] }
    ] }

/- Note (F1 repair 2026-07-13): this inherits the REPAIRED `serialHPC2Member`
rows, so the mutant's probe boundary grew by the same mux-wire nodes (plus
the collided (39,0)/(38,1)/(40,1)/(39,3)/(38,4)/(40,4) rows, which name
different gates in this circuit).  Enlarging the boundary of a NEGATIVE
anchor is monotone-safe: a leak found among fewer probes remains a leak among
more.  This gadget has deliberately NOT been given a `WF` anchor — its
whitelist is not curated to closure and its only role is the leak
counterexample in `OPINI2Probing.lean`. -/
def member (n : Node) : Bool :=
  serialHPC2Member n ||
    (n.cycle == 0 && [37, 47].contains n.gate) ||
    (n.cycle == 1 && [38, 39, 44].contains n.gate) ||
    (n.cycle == 2 && [40, 42, 45].contains n.gate) ||
    (n.cycle == 3 && [37, 41, 43, 46, 47].contains n.gate) ||
    (n.cycle == 4 && [38, 39].contains n.gate) ||
    (n.cycle == 5 && [40, 42].contains n.gate)

def gadget : GadgetInstance :=
  { circuit := circuit, horizon := 6, d := 2, inputCount := 3
    inputArrival := serialHPC2.inputArrival
    output := fun share =>
      if share == 0 then { gate := 41, cycle := 5 } else { gate := 43, cycle := 5 }
    member := member
    randomness := [.rnd 0 0, .rnd 1 0, .rnd 1 3]
    publicFixing := controls }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

end StaleR

end Chains

end LeanSec.Gadgets.OPINI2
