import LeanSec.Composition.UniversalSStage2

namespace LeanSec
namespace Composition
namespace UniversalS

/-! The single-cycle serial-composition development starts with the frozen
evaluator's disjoint-prefix restriction theorem. -/

export UniversalSStage1 (appendCircuit)

/-- Public Stage-1 theorem under the owner module's namespace. -/
theorem disjointUnion_eval_restricts_to_prefix
    (subc : Circuit) (suffix : Array Gate) (horizon : Nat)
    (env : Env) (node : Node) (hwf : subc.WF)
    (hnode : node.gate < subc.gates.size) :
    Execution.eval (UniversalSStage1.appendCircuit subc suffix)
        horizon env node =
      Execution.eval subc horizon env node :=
  UniversalSStage1.eval_appendCircuit_prefix subc suffix horizon env node
    hwf hnode

/-- Stage-1 restriction in the form needed by a product experiment: the
composite and isolated environments need only coincide on upstream sources. -/
theorem disjointUnion_eval_restricts_to_prefix_of_envAgreement
    (subc : Circuit) (suffix : Array Gate) (horizon : Nat)
    (compositeEnv subEnv : Env) (node : Node) (hwf : subc.WF)
    (hnode : node.gate < subc.gates.size)
    (henv : UniversalSStage1.EnvAgreeOn
      (Execution.relevantSrcs subc horizon) compositeEnv subEnv) :
    Execution.eval (UniversalSStage1.appendCircuit subc suffix)
        horizon compositeEnv node =
      Execution.eval subc horizon subEnv node :=
  UniversalSStage1.eval_appendCircuit_prefix_of_envAgree subc suffix horizon
    compositeEnv subEnv node hwf hnode henv

/-- The direct horizon-one DAG-union construction is nonempty: the concrete
two-share O-PINI pair yields a kernel-checked secure, register-free union. -/
theorem concrete_clean_union_probing :
    Gadget.probingSecureSpec UniversalSStage2.Concrete.composite
      transitionGlitch 1 :=
  UniversalSStage2.Concrete.composite_probing

end UniversalS
end Composition
end LeanSec

#print axioms LeanSec.Composition.UniversalS.disjointUnion_eval_restricts_to_prefix
#print axioms LeanSec.Composition.UniversalS.disjointUnion_eval_restricts_to_prefix_of_envAgreement
#print axioms LeanSec.Composition.UniversalS.concrete_clean_union_probing
