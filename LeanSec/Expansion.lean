import LeanSec.Execution

namespace LeanSec

namespace Expansion

/-- Identity expansion: an ordinary stable-value probe reveals only itself. -/
def identity : ExpansionScheme :=
  fun _ _ node => [node]

/-- Compute the register/source frontier of a gate's latency-zero input cone.
The circuit size is sufficient fuel for every well-formed combinational cone;
the fuel also gives total fallback behavior on malformed cyclic circuits. -/
def glitchGates (c : Circuit) : Nat → Nat → List Nat
  | 0, gate => [gate]
  | fuel + 1, gate =>
      match c.gates[gate]? with
      | none => [gate]
      | some g =>
          let inputs := g.inputs.filter (fun input => input.2 == 0)
          if inputs.isEmpty then
            [gate]
          else
            (inputs.flatMap fun input => glitchGates c fuel input.1).eraseDups

/-- Glitch expansion: reveal the register/source frontier of the probed node's
combinational cone at the same cycle. -/
def glitch : ExpansionScheme :=
  fun c _ node =>
    (glitchGates c c.gates.size node.gate).map fun gate =>
      { gate := gate, cycle := node.cycle }

/-- Transition expansion within the execution window.  At cycle zero, or for
a node outside the window, no predecessor node is introduced. -/
def transition : ExpansionScheme :=
  fun _ horizon node =>
    if node.cycle > 0 && node.cycle < horizon then
      [{ gate := node.gate, cycle := node.cycle - 1 }, node]
    else
      [node]

/-- Compose expansion schemes, interpreting their result lists as sets. -/
def compose (outer inner : ExpansionScheme) : ExpansionScheme :=
  fun c horizon node =>
    ((outer c horizon node).flatMap (inner c horizon)).eraseDups

/-- Transition first, then glitch expansion ([CS21] Def 12). -/
def transitionGlitch : ExpansionScheme := compose transition glitch

/-- Glitch first, then transition expansion (the alternative order in [CS21]
footnote 5). -/
def glitchTransition : ExpansionScheme := compose glitch transition

/-- Equality of node lists when they are interpreted as finite sets. -/
def SameNodes (xs ys : List Node) : Prop :=
  ∀ node, node ∈ xs ↔ node ∈ ys

theorem glitch_cycle (c : Circuit) (horizon gate cycle : Nat) :
    glitch c horizon { gate := gate, cycle := cycle } =
      (glitchGates c c.gates.size gate).map fun g =>
        { gate := g, cycle := cycle } := by
  rfl

theorem transition_at_zero (c : Circuit) (horizon gate : Nat) :
    transition c horizon { gate := gate, cycle := 0 } =
      [{ gate := gate, cycle := 0 }] := by
  simp [transition]

theorem transition_at_successor (c : Circuit) (horizon gate cycle : Nat)
    (inside : cycle + 1 < horizon) :
    transition c horizon { gate := gate, cycle := cycle + 1 } =
      [{ gate := gate, cycle := cycle }, { gate := gate, cycle := cycle + 1 }] := by
  simp [transition, inside]

/-- Glitch and transition expansion commute as node sets. -/
theorem expandTG_comm (c : Circuit) (horizon : Nat) (node : Node) :
    SameNodes (transitionGlitch c horizon node)
      (glitchTransition c horizon node) := by
  intro observed
  simp only [transitionGlitch, glitchTransition, compose,
    List.mem_eraseDups, List.mem_flatMap]
  change
    (∃ expanded ∈ transition c horizon node,
      observed ∈ (glitchGates c c.gates.size expanded.gate).map
        (fun gate => { gate := gate, cycle := expanded.cycle })) ↔
    (∃ expanded ∈
      (glitchGates c c.gates.size node.gate).map
        (fun gate => { gate := gate, cycle := node.cycle }),
      observed ∈ transition c horizon expanded)
  constructor
  · rintro ⟨expanded, hexpanded, hobserved⟩
    by_cases inside : 0 < node.cycle ∧ node.cycle < horizon
    · have cases : expanded = { gate := node.gate, cycle := node.cycle - 1 } ∨
          expanded = node := by
        simpa [transition, inside] using hexpanded
      rcases cases with hprev | hcurrent
      · subst expanded
        rcases List.mem_map.mp hobserved with ⟨gate, hgate, heq⟩
        subst observed
        refine ⟨{ gate := gate, cycle := node.cycle }, ?_, ?_⟩
        · exact List.mem_map.mpr ⟨gate, hgate, rfl⟩
        · simp [transition, inside]
      · subst expanded
        rcases List.mem_map.mp hobserved with ⟨gate, hgate, heq⟩
        subst observed
        refine ⟨{ gate := gate, cycle := node.cycle }, ?_, ?_⟩
        · exact List.mem_map.mpr ⟨gate, hgate, rfl⟩
        · simp [transition, inside]
    · have heq : expanded = node := by
        simpa [transition, inside] using hexpanded
      subst expanded
      rcases List.mem_map.mp hobserved with ⟨gate, hgate, heq⟩
      subst observed
      refine ⟨{ gate := gate, cycle := node.cycle }, ?_, ?_⟩
      · exact List.mem_map.mpr ⟨gate, hgate, rfl⟩
      · simp [transition, inside]
  · rintro ⟨expanded, hobserved, hexpanded⟩
    rcases List.mem_map.mp hobserved with ⟨gate, hgate, heq⟩
    subst expanded
    by_cases inside : 0 < node.cycle ∧ node.cycle < horizon
    · have cases :
          observed = { gate := gate, cycle := node.cycle - 1 } ∨
          observed = { gate := gate, cycle := node.cycle } := by
        simpa [transition, inside] using hexpanded
      rcases cases with hprevious | hcurrent
      · subst observed
        refine ⟨{ gate := node.gate, cycle := node.cycle - 1 }, ?_, ?_⟩
        · simp [transition, inside]
        · exact List.mem_map.mpr ⟨gate, hgate, rfl⟩
      · subst observed
        refine ⟨node, ?_, ?_⟩
        · simp [transition, inside]
        · exact List.mem_map.mpr ⟨gate, hgate, rfl⟩
    · have heq : observed = { gate := gate, cycle := node.cycle } := by
        simpa [transition, inside] using hexpanded
      subst observed
      refine ⟨node, ?_, ?_⟩
      · simp [transition, inside]
      · exact List.mem_map.mpr ⟨gate, hgate, rfl⟩

end Expansion

export Expansion (identity glitch transition transitionGlitch)

end LeanSec
