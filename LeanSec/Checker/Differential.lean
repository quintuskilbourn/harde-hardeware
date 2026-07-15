import LeanSec.Checker.Fast
import LeanSec.Gadgets.DomAnd
import LeanSec.Gadgets.TransitionLeak
import LeanSec.Netlist.XorRefreshGen
import LeanSec.Composition.ConcreteSerial2
import LeanSec.Composition.OPINIRealWork

namespace LeanSec.Checker.Differential

open Gadget Checker

/-! # Differential battery: verified checker vs independent kernel verdicts

Hardening H4.  `Checker.Fast.checker` carries a soundness proof
(`checker_sound`: a `true` verdict implies the audited `probingSecureSpec`),
but soundness alone would be satisfied by a checker that always answers
`false`.  This battery pins the checker's *behaviour* on both sides against
verdicts that are independently kernel-established elsewhere in the tree:

* every ACCEPT case is a gadget whose probing security has its own direct
  kernel proof (or SILVER agreement) — the checker must answer `true`;
* every REJECT case is a gadget with an independent kernel falsification
  (`¬probingSecure...`) — the checker must answer `false`.

Insecure rejects deliberately include a functionally-correct-but-unmasked
foil (`ShareCollapse`): it recombines to exactly the right function, so any
purely functional guard passes it, and only the security checker can reject
it.  A checker bug in either direction breaks at least one equation below,
and every equation is a kernel fact, not a test-harness observation. -/

/-! ## ACCEPT side: kernel-proven-secure gadgets the checker must pass -/

/-- DOM-AND under glitch, order 1 — matches SILVER `probing.robust PASS` and
`Gadgets.DomAnd.glitch_probing_one`. -/
theorem accepts_dom_and :
    checker LeanSec.Gadgets.DomAnd.gadget glitch 1 = true := by
  set_option maxRecDepth 10000 in
  set_option maxHeartbeats 32000000 in decide

/-- The mechanically parsed fresh-netlist XOR-refresh gadget under glitch —
matches `Netlist.XorRefreshGen.glitch_probing_one`. -/
theorem accepts_xor_refresh :
    checker LeanSec.Netlist.XorRefreshGen.gadget glitch 1 = true := by
  set_option maxRecDepth 10000 in
  set_option maxHeartbeats 32000000 in decide

/-- The concrete serial O-PINI composite under the full transition-glitch
expansion — matches `ConcreteSerial2.serial2_composite_probing`. -/
theorem accepts_serial2_composite :
    checker LeanSec.Composition.ConcreteSerial2.composite
      transitionGlitch 1 = true := by
  set_option maxRecDepth 10000 in
  set_option maxHeartbeats 32000000 in decide

/-- The time-multiplexed share-reuse wire is secure under glitch-only —
matches `TransitionLeak.leak_glitch_probing`; paired with
`rejects_transition_leak` below, the checker separates the two expansions on
the same physical circuit. -/
theorem accepts_leaky_glitch_only :
    checker LeanSec.Gadgets.TransitionLeak.leakyGadget glitch 1 = true := by
  set_option maxRecDepth 10000 in
  set_option maxHeartbeats 32000000 in decide

/-- The non-degenerate reconvergent real-work tail (hardening H1) under
transition-glitch — matches `OPINIRealWork.realWork_opini` (O-PINI implies
probing here via the audited bridges). -/
theorem accepts_real_work_tail :
    checker LeanSec.Composition.OPINIRealWork.realWork
      transitionGlitch 1 = true := by
  set_option maxRecDepth 10000 in
  set_option maxHeartbeats 64000000 in decide

/-! ## REJECT side: kernel-proven-insecure gadgets the checker must fail -/

/-- The XOR-before-register barrier mutant of DOM-AND — the independent
kernel falsification is `Gadgets.DomAnd.XBR.not_probing`. -/
theorem rejects_xbr :
    checker LeanSec.Gadgets.DomAnd.XBR.gadget glitch 1 = false := by
  set_option maxRecDepth 10000 in
  set_option maxHeartbeats 32000000 in decide

/-- The unmasked AND — independent falsification
`Gadgets.DomAnd.NaiveAnd.not_glitch_probing_one`. -/
theorem rejects_naive_and :
    checker LeanSec.Gadgets.DomAnd.NaiveAnd.gadget glitch 1 = false := by
  set_option maxRecDepth 10000 in
  set_option maxHeartbeats 32000000 in decide

/-- The transition leak ([CS21] Fig-2a) — independent falsification
`Gadgets.TransitionLeak.leak_not_probing`. -/
theorem rejects_transition_leak :
    checker LeanSec.Gadgets.TransitionLeak.leakyGadget
      transitionGlitch 1 = false := by
  set_option maxRecDepth 10000 in
  set_option maxHeartbeats 32000000 in decide

/-! ## The functionally-correct-but-unmasked foil -/

/-- Both shares of the single input sharing meet on one XOR wire; a dead
constant supplies the second output share.  The output pair recombines to
the correct identity function, so this circuit passes every functional
guard while carrying the whole secret on one probeable wire. -/
def shareCollapseCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .xor, inputs := [(0, 0), (1, 0)] },
      { kind := .const false, inputs := [] }
    ] }

def shareCollapse : GadgetInstance :=
  { circuit := shareCollapseCircuit
    horizon := 1
    d := 2
    inputCount := 1
    inputArrival := fun _ share => .inp 0 share 0
    output := fun share => { gate := 2 + share, cycle := 0 }
    member := fun node => node.cycle == 0 && decide (node.gate < 4)
    randomness := [] }

/-- The foil is functionally perfect: it recombines to the identity. -/
theorem shareCollapse_recombines :
    recombinesTo shareCollapse (fun secrets => secrets.getD 0 false) := by
  decide

/-- Independent kernel falsification: one probe on the collapse wire
distinguishes the secret. -/
theorem shareCollapse_not_probing :
    ¬probingSecure shareCollapse glitch 1 := by decide

/-- The checker rejects the foil. -/
theorem rejects_share_collapse :
    checker shareCollapse glitch 1 = false := by decide

/-- ...and rejects it under the transition-glitch expansion as well. -/
theorem rejects_share_collapse_transition :
    checker shareCollapse transitionGlitch 1 = false := by decide

/-! ## Agreement corollaries

On the accept side the checker's `true` plus `checker_sound` REPRODUCES the
independently proven security statements, so the two proof routes are pinned
to agree at the level of the audited spec. -/

theorem checker_route_dom_and :
    probingSecureSpec LeanSec.Gadgets.DomAnd.gadget glitch 1 :=
  checker_sound _ _ _ accepts_dom_and

theorem checker_route_xor_refresh :
    probingSecureSpec LeanSec.Netlist.XorRefreshGen.gadget glitch 1 :=
  checker_sound _ _ _ accepts_xor_refresh

theorem checker_route_serial2 :
    probingSecureSpec LeanSec.Composition.ConcreteSerial2.composite
      transitionGlitch 1 :=
  checker_sound _ _ _ accepts_serial2_composite

theorem checker_route_real_work_tail :
    probingSecureSpec LeanSec.Composition.OPINIRealWork.realWork
      transitionGlitch 1 :=
  checker_sound _ _ _ accepts_real_work_tail

end LeanSec.Checker.Differential
