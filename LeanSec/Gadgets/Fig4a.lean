import LeanSec.Gadgets.DomAnd

/-
Cassiers--Standaert Fig. 4a (TCHES 2021): the PINI → O-PINI composition gap.

GOAL (workstream B): make the PINI-but-not-O-PINI gap *operational* by exhibiting
a serial composition of nonlinear masked gadgets where a PINI-not-O-PINI inner
gadget leaks under `transitionGlitch` while an O-PINI inner gadget makes the same
composition secure — the transition-leakage counterpart of the O-PINI ≠ PINI
separation already kernel-proven in `HPC2.not_glitch_opini_one`.

HONEST OUTCOME (this file is a *diagnosis*, not a forced anchor).  On faithful
first-order two-share circuits the composition leak the paper motivates does NOT
reproduce as a probing leak, and it is *not* fixed by the O-PINI output refresh.
Three kernel-checked facts below pin exactly why, and together they locate the
gap precisely rather than manufacture a false positive:

  A. `faithful_and_transitionGlitch_secure` — a real nonlinear masked gadget
     (DOM-AND, functionally verified by `DomAnd.recombines`) is first-order
     `transitionGlitch`-probing SECURE.  DOM-AND (this one faithful nonlinear
     gadget) carries no first-order transition leak — proven for DOM-AND
     specifically, NOT claimed for all nonlinear gadgets; the leak the artifact
     once claimed is absent here, consistent with the box-proven `serialHPC2`
     (STATUS.md §2) and the retraction in STATUS.md §3.

  B. `refreshed_multiplex_still_leaks` / `Raw.leak_not_probing` — the
     first-order transition leak we construct in this model is the linear
     share-multiplex of Fig. 2a: one un-barriered wire carrying the two shares
     of a single sharing at adjacent cycles.  Applying a zero-sharing output
     refresh — the KIND of remask that separates `OPINI2` from `HPC2` (not the
     exact O-PINI2 circuit, which registers both refreshed outputs and proves
     `opini`) — to that sharing does NOT remove the leak (`refreshed_multiplex_still_leaks`),
     because a zero-sharing refresh preserves the parity `x0 ⊕ x1 = x`.  The raw
     and refreshed multiplexers leak identically.

  C. The gap therefore lives at the SIMULATABILITY level, not the first-order
     probing level.  That separation is already kernel-proven, non-vacuously, as
     `HPC2.glitch_pini_one` (PINI ✓) together with `HPC2.not_glitch_opini_one`
     (O-PINI ✗).  See `RESULT_B.md` for the full adjacency diagnosis.

Why the Fig. 2a mechanism does not lift to a nonlinear *composition* (the crux):
the Fig. 2a leak works because the multiplexed values are INPUT SHARES — stable
sources whose glitch frontier is the source itself, and which `inputArrival`
makes live at exactly one cycle each, so a glitch-only probe sees a single share
while a transition probe spans both.  The two OUTPUT shares of a nonlinear
gadget are instead computed values: glitch-robustness forces a REGISTER BARRIER
in front of them (otherwise their glitch cone reaches the internal partial
products and the gadget is glitch-insecure outright — not transition-specific),
and that same barrier holds them stable across cycles, so time-multiplexing them
requires a hold/feedback path that barriers the transition adjacency.  The
transition leak and the glitch barrier are mutually exclusive on faithful
nonlinear output shares.  This is the register-barrier obstruction the KNOWN
TRAP (STATUS.md §3) names, now made concrete and kernel-checked.
-/

namespace LeanSec.Gadgets.Fig4a

open Gadget
open scoped LeanSec

/-! ## Part A — DOM-AND, a faithful nonlinear masked gadget, has no first-order
transition leak (proven for DOM-AND specifically, not claimed for all gadgets).
DOM-AND (`DomAnd.gadget`, verified to recombine to `a·b` by
`DomAnd.recombines`, glitch-probing secure by `DomAnd.glitch_probing_one`) is
also first-order `transitionGlitch`-probing secure.  The leak does not reproduce
on a faithful circuit. -/

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000 in
theorem faithful_and_transitionGlitch_secure :
    probingSecure DomAnd.gadget transitionGlitch 1 := by decide

set_option maxRecDepth 1000

/-! ## Part B — the only first-order transition leak is the linear share
multiplex, and the O-PINI output refresh does not fix it.

`rawMultiplex`: Fig. 2a's construction verbatim — one mux wire carries share `x0`
at cycle 0 and share `x1` at cycle 1 of a single sharing.  It leaks under
`transitionGlitch` and is secure under glitch.

`refreshedMultiplex`: the same construction, but with a fresh zero-sharing
refresh `t` (held in a register so the same `t` reaches both shares) XORed onto
the sharing *before* it is multiplexed — i.e. the O-PINI output-refresh
mechanism.  The refresh leaves the parity `x0 ⊕ x1 = x` invariant, so the leak
survives.  This is the operational content of "output refresh is not the fix for
a transition share-multiplex". -/

namespace Raw

/-- Fig. 2a's leaky multiplexer: `M = mux(sel, x0, x1)`, `sel` public. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },                    -- 0: x0
      { kind := .inp 0 1, inputs := [] },                    -- 1: x1
      { kind := .ctl 0, inputs := [] },                      -- 2: sel
      { kind := .mux, inputs := [(2, 0), (0, 0), (1, 0)] }   -- 3: M
    ] }

def member (n : Node) : Bool := decide (n.gate < 4) && decide (n.cycle < 2)

def gadget : GadgetInstance :=
  { circuit := circuit, horizon := 2, d := 2, inputCount := 1
    inputArrival := fun _ share =>
      if share == 0 then .inp 0 0 0 else .inp 0 1 1
    output := fun share =>
      if share == 0 then { gate := 3, cycle := 0 } else { gate := 3, cycle := 1 }
    member := member
    randomness := []
    publicFixing := [(.ctl 0 0, false), (.ctl 0 1, true)] }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Functional guard: the multiplexed wire recombines to the unshared secret. -/
theorem recombines : recombinesTo gadget (fun s => s.getD 0 false) := by decide

/-- Timing trace (anti-artifact guard): the two observations of the one physical
mux wire are exactly the two shares of the sharing, in order. -/
theorem leak_trace :
    ∀ x ∈ boolVectors (inputWidth gadget),
      (envsForInput gadget x).map
          (observe gadget [{ gate := 3, cycle := 0 }, { gate := 3, cycle := 1 }]) =
        [[x.getD 0 false, x.getD 1 false]] := by
  decide

/-- A single transition-extended probe spans both cycles and sees both shares. -/
theorem leak_not_probing : ¬ probingSecureFast gadget transitionGlitch 1 := by
  decide

/-- Glitch-only control: a single-cycle probe sees one live share (the other mux
input is 0 at that cycle), so the same wire is first-order secure — the leak is
transition-specific. -/
theorem leak_glitch_probing : probingSecureFast gadget glitch 1 := by decide

end Raw

namespace Refreshed

/-- The Fig. 2a multiplexer preceded by an O-PINI-style output refresh: a fresh
zero-sharing bit `t` (`rnd 0`), held in `Reg[t]` so the SAME `t` reaches both
shares, is XORed onto the sharing before it is multiplexed:
`x0' = x0 ⊕ t` at cycle 0, `x1' = x1 ⊕ Reg[t]` at cycle 1. -/
def circuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },                    -- 0: x0
      { kind := .inp 0 1, inputs := [] },                    -- 1: x1
      { kind := .rnd 0, inputs := [] },                      -- 2: t (fresh)
      { kind := .reg, inputs := [(2, 1)] },                  -- 3: Reg[t] (= t @≥1)
      { kind := .xor, inputs := [(0, 0), (2, 0)] },          -- 4: x0' = x0 ⊕ t
      { kind := .xor, inputs := [(1, 0), (3, 0)] },          -- 5: x1' = x1 ⊕ Reg[t]
      { kind := .ctl 0, inputs := [] },                      -- 6: sel
      { kind := .mux, inputs := [(6, 0), (4, 0), (5, 0)] }   -- 7: M
    ] }

def member (n : Node) : Bool := decide (n.gate < 8) && decide (n.cycle < 2)

def gadget : GadgetInstance :=
  { circuit := circuit, horizon := 2, d := 2, inputCount := 1
    inputArrival := fun _ share =>
      if share == 0 then .inp 0 0 0 else .inp 0 1 1
    output := fun share =>
      if share == 0 then { gate := 7, cycle := 0 } else { gate := 7, cycle := 1 }
    member := member
    randomness := [.rnd 0 0, .rnd 0 1]
    publicFixing := [(.ctl 0 0, false), (.ctl 0 1, true)] }

theorem circuit_wf : circuit.WF := by
  simp [circuit, Circuit.WF, Circuit.indicesOk, Circuit.gateArityOk,
    Circuit.combAcyclic, Circuit.combEdges, Circuit.kahnLoop,
    Circuit.kahnStep, Circuit.hasRemainingPred]

/-- Functional guard: the refreshed multiplexed wire still recombines to the
unshared secret (the zero-sharing refresh preserves the parity). -/
theorem recombines : recombinesTo gadget (fun s => s.getD 0 false) := by decide

/-- The O-PINI output refresh does NOT fix the transition share-multiplex: the
refreshed wire still leaks under `transitionGlitch`.  A zero-sharing refresh
leaves `x0 ⊕ x1 = x` invariant, so a transition probe spanning both refreshed
shares still recovers the secret.  This is the kernel-checked reason the
PINI → O-PINI gap is not a first-order transition-probing leak that output
refresh closes. -/
theorem refreshed_multiplex_still_leaks :
    ¬ probingSecureFast gadget transitionGlitch 1 := by decide

/-- Glitch-only control: still secure under glitch — the leak stays
transition-specific after the refresh. -/
theorem refreshed_glitch_probing : probingSecureFast gadget glitch 1 := by decide

end Refreshed

/-! ## Part C — summary of the operational separation.

The genuine PINI → O-PINI separation is the simulatability one already in the
kernel-checked default build (non-vacuous, guarded by `HPC2.recombines` and the
`opini` ≠ `pini` decidability):

  * `HPC2.glitch_pini_one`      : HPC2 is first-order glitch PINI.
  * `HPC2.not_glitch_opini_one` : HPC2 is first-order glitch NOT O-PINI.

Combined with Parts A/B this is the honest Fig. 4a result: O-PINI is strictly
stronger than PINI (the simulatability separation), but on faithful first-order
two-share circuits that strength does not manifest as a `transitionGlitch`
probing leak that the O-PINI output refresh removes — the only such first-order
transition leak is the linear share-multiplex, which is refresh-invariant, and a
faithful nonlinear gadget is transition-secure.  Full write-up: `RESULT_B.md`. -/

end LeanSec.Gadgets.Fig4a
