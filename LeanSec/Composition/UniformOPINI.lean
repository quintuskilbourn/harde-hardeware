import LeanSec.Composition.OPINIFixpoint

namespace LeanSec
namespace Composition

open Gadget

/-! # Executable demand-uniform O-PINI

`uniformOpiniSpec` (OPINIFixpoint.lean) is the leaf obligation of the
generic O-PINI producer-reuse closure `compose_opini`.  At order one it is
implied by the audited `opiniSpec` (`opini_implies_uniform_of_le_one`), but
at `t ≥ 2` it is strictly stronger and was previously an open per-leaf
obligation.  This file gives the executable counterpart `uopini` — exactly
`uniformOpiniSpec` with each `SimulatableOn` replaced by the decidable
`CountInvariant`, mirroring the audited `opini`/`opini_iff_spec` pair — so
that concrete gadgets can discharge the obligation at higher order by
kernel computation. -/

/-- Executable demand-uniform O-PINI predicate.  Identical to the audited
`opini` except that the witness `b` is selected once per internal probe set,
before the output demand is quantified. -/
def uopini (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) : Prop :=
  g.WF ∧
    ∀ internal ∈ subsetsUpTo t (internalNodes g),
      ∃ b ∈ subsetsUpTo internal.length (List.range g.d),
        ∀ outputs ∈ subsetsUpTo (t - internal.length) (List.range g.d),
          CountInvariant (boolVectors (inputWidth g)) (envsForInput g)
            (projection g (outputs ++ b))
            (observe g ((expandedNodes g scheme
              (internal ++ outputs.map g.output)) ++ b.map g.output).eraseDups)

instance uopiniDecidable
    (g : GadgetInstance) (scheme : ExpansionScheme) (t : Nat) :
    Decidable (uopini g scheme t) := by
  unfold uopini
  infer_instance

/-- The executable predicate decides the audited demand-uniform certificate
whenever every full input-share valuation is reached. -/
theorem uopini_iff_spec (g : GadgetInstance) (scheme : ExpansionScheme)
    (t : Nat)
    (reached : ∀ x ∈ boolVectors (inputWidth g),
      (envsForInput g x).length > 0) :
    uopini g scheme t ↔ uniformOpiniSpec g scheme t := by
  unfold uopini uniformOpiniSpec
  constructor
  · rintro ⟨hwf, h⟩
    refine ⟨hwf, ?_⟩
    intro internal hinternal
    obtain ⟨b, hb, hall⟩ := h internal hinternal
    refine ⟨b, hb, ?_⟩
    intro outputs houtputs
    exact (simulatable_iff_countInvariant _ _ _ _ reached).2
      (hall outputs houtputs)
  · rintro ⟨hwf, h⟩
    refine ⟨hwf, ?_⟩
    intro internal hinternal
    obtain ⟨b, hb, hall⟩ := h internal hinternal
    refine ⟨b, hb, ?_⟩
    intro outputs houtputs
    exact (simulatable_iff_countInvariant _ _ _ _ reached).1
      (hall outputs houtputs)

end Composition
end LeanSec
