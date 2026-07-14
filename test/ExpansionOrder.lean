import LeanSec.Expansion

namespace LeanSec.Expansion.Tests

private def coneCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .and, inputs := [(0, 0), (1, 0)] },
      { kind := .reg, inputs := [(2, 1)] },
      { kind := .xor, inputs := [(2, 0), (3, 0)] }
    ] }

theorem glitch_cone_anchor :
    glitch coneCircuit 3 { gate := 4, cycle := 2 } =
      [{ gate := 0, cycle := 2 }, { gate := 1, cycle := 2 },
       { gate := 3, cycle := 2 }] := by
  rfl

theorem transition_boundary_anchor :
    transition coneCircuit 3 { gate := 4, cycle := 0 } =
      [{ gate := 4, cycle := 0 }] := by
  rfl

theorem expansion_order_anchor :
    SameNodes
      (transitionGlitch coneCircuit 3 { gate := 4, cycle := 2 })
      (glitchTransition coneCircuit 3 { gate := 4, cycle := 2 }) := by
  exact expandTG_comm _ _ _

end LeanSec.Expansion.Tests
