import LeanSec.Gadget

namespace LeanSec.Gadgets.TransitionLeak

open Gadget

/- Cassiers--Standaert Fig. 2a's essential transition pattern: one physical
wire (the output of gate 3) carries share 0 at cycle zero and share 1 at cycle
one.  The public control schedule is fixed in every experiment. -/
def leakyCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .inp 0 1, inputs := [] },
      { kind := .ctl 0, inputs := [] },
      { kind := .mux, inputs := [(2, 0), (0, 0), (1, 0)] }
    ] }

def leakyMember (n : Node) : Bool :=
  decide (n.gate < 4) && decide (n.cycle < 2)

def leakyGadget : GadgetInstance :=
  { circuit := leakyCircuit
    horizon := 2
    d := 2
    inputCount := 1
    inputArrival := fun _ share =>
      if share == 0 then .inp 0 0 0 else .inp 0 1 1
    output := fun share =>
      if share == 0 then { gate := 3, cycle := 0 }
      else { gate := 3, cycle := 1 }
    member := leakyMember
    randomness := []
    publicFixing := [(.ctl 0 0, false), (.ctl 0 1, true)] }

theorem leakyCircuit_wf : leakyCircuit.WF := by
  simp [leakyCircuit, Circuit.WF, Circuit.indicesOk,
    Circuit.gateArityOk, Circuit.combAcyclic, Circuit.combEdges,
    Circuit.kahnLoop, Circuit.kahnStep, Circuit.hasRemainingPred]

/- Exhaustive timing trace: the two observations of the same physical mux
wire are exactly the two input-share values, in order. -/
theorem leak_trace :
    ∀ x ∈ boolVectors (inputWidth leakyGadget),
      (envsForInput leakyGadget x).map
          (observe leakyGadget
            [{ gate := 3, cycle := 0 }, { gate := 3, cycle := 1 }]) =
        [[x.getD 0 false, x.getD 1 false]] := by
  decide

/- Functional guard: XOR-recombining the two time-multiplexed output shares
is the identity function on the unshared input secret. -/
theorem leak_recombines :
    recombinesTo leakyGadget (fun secrets => secrets.getD 0 false) := by
  decide

/- A single transition-extended probe of the cycle-one mux output reveals the
adjacent pair traced above, and therefore distinguishes the shared secret. -/
theorem leak_not_probing :
    ¬ probingSecureFast leakyGadget transitionGlitch 1 := by
  decide

/- Without transition expansion, one glitch-extended probe sees only one of
the two time-multiplexed shares, so the same gadget is first-order secure. -/
theorem leak_glitch_probing :
    probingSecureFast leakyGadget glitch 1 := by
  decide

/- Fig. 2b's bubble fix: the same physical mux-output wire carries share 0 at
cycle zero, a public zero at cycle one, and share 1 at cycle two.  Thus no
transition pair contains both shares of the sharing. -/
def fixedMember (n : Node) : Bool :=
  decide (n.gate < 4) && decide (n.cycle < 3)

def fixedGadget : GadgetInstance :=
  { circuit := leakyCircuit
    horizon := 3
    d := 2
    inputCount := 1
    inputArrival := fun _ share =>
      if share == 0 then .inp 0 0 0 else .inp 0 1 2
    output := fun share =>
      if share == 0 then { gate := 3, cycle := 0 }
      else { gate := 3, cycle := 2 }
    member := fixedMember
    randomness := []
    publicFixing :=
      [(.ctl 0 0, false), (.ctl 0 1, false), (.ctl 0 2, true)] }

/- The bubble changes only the timing: the two scheduled output values still
XOR to the unshared input secret. -/
theorem fixed_recombines :
    recombinesTo fixedGadget (fun secrets => secrets.getD 0 false) := by
  decide

/- Each transition+glitch observation now contains at most one input share,
so the bubbled construction is first-order probing secure. -/
theorem fixed_probing :
    probingSecureFast fixedGadget transitionGlitch 1 := by
  decide

end LeanSec.Gadgets.TransitionLeak
