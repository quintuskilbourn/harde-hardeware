import LeanSec.Composition.ConcreteSerial2

namespace LeanSec
namespace Composition

open Gadget

/-! # Functional correctness of serial composition

Security composition and functional composition have different proof burdens.
For functional correctness it is enough that the downstream input sharing is
the upstream output sharing: the upstream recombination equation can then be
substituted into the downstream recombination equation.
-/

/-- The unmasked function computed by a serial connection.  The output of the
upstream function becomes the first secret consumed downstream; any remaining
downstream secrets are supplied externally. -/
def serialFunction (upstreamFunction downstreamFunction : List Bool → Bool)
    (upstreamSecrets downstreamSecrets : List Bool) : Bool :=
  downstreamFunction (upstreamFunction upstreamSecrets :: downstreamSecrets)

/-- Pointwise functional composition through a literally matching sharing.
This is the algebraic core of the generic gadget theorem below. -/
theorem xorList_functionalComposition_of_matching_boundary
    (upstreamOutput downstreamInput downstreamOutput : List Bool)
    (upstreamFunction downstreamFunction : List Bool → Bool)
    (upstreamSecrets downstreamSecrets : List Bool)
    (upstreamRecombines :
      xorList upstreamOutput = upstreamFunction upstreamSecrets)
    (boundaryMatches : downstreamInput = upstreamOutput)
    (downstreamRecombines :
      xorList downstreamOutput =
        downstreamFunction (xorList downstreamInput :: downstreamSecrets)) :
    xorList downstreamOutput =
      serialFunction upstreamFunction downstreamFunction
        upstreamSecrets downstreamSecrets := by
  rw [downstreamRecombines, boundaryMatches, upstreamRecombines]
  rfl

/-- Generic functional-correctness composition lemma.

The four adapter functions merely view one composite execution as executions
of its two component gadgets.  `boundaryMatches` is the only wiring premise:
the first downstream secret is the XOR of the actual upstream output shares.
Unlike security composition, no simulator, probe partition, or universal glue
condition is needed. -/
theorem recombinesTo_serial_of_matching_boundary
    (upstream downstream composite : GadgetInstance)
    (upstreamFunction downstreamFunction : List Bool → Bool)
    (upstreamSecrets downstreamSecrets : List Bool → List Bool)
    (upstreamInput downstreamInput : List Bool → Env → List Bool)
    (upstreamEnv downstreamEnv : List Bool → Env → Env)
    (upstreamCorrect : recombinesTo upstream upstreamFunction)
    (downstreamCorrect : recombinesTo downstream downstreamFunction)
    (upstreamInputValid : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ env ∈ envsForInput composite x,
        upstreamInput x env ∈ boolVectors (inputWidth upstream))
    (upstreamEnvValid : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ env ∈ envsForInput composite x,
        upstreamEnv x env ∈ envsForInput upstream (upstreamInput x env))
    (downstreamInputValid : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ env ∈ envsForInput composite x,
        downstreamInput x env ∈ boolVectors (inputWidth downstream))
    (downstreamEnvValid : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ env ∈ envsForInput composite x,
        downstreamEnv x env ∈ envsForInput downstream (downstreamInput x env))
    (upstreamSecretsAgree : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ env ∈ envsForInput composite x,
        secretsOf upstream (upstreamInput x env) =
          upstreamSecrets (secretsOf composite x))
    (boundaryMatches : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ env ∈ envsForInput composite x,
        secretsOf downstream (downstreamInput x env) =
          xorList (observe upstream (outputNodes upstream) (upstreamEnv x env)) ::
            downstreamSecrets (secretsOf composite x))
    (outputsAgree : ∀ x ∈ boolVectors (inputWidth composite),
      ∀ env ∈ envsForInput composite x,
        xorList (observe composite (outputNodes composite) env) =
          xorList (observe downstream (outputNodes downstream)
            (downstreamEnv x env))) :
    recombinesTo composite (fun secrets =>
      serialFunction upstreamFunction downstreamFunction
        (upstreamSecrets secrets) (downstreamSecrets secrets)) := by
  intro x hx env henv
  rw [outputsAgree x hx env henv]
  rw [downstreamCorrect (downstreamInput x env)
    (downstreamInputValid x hx env henv) (downstreamEnv x env)
    (downstreamEnvValid x hx env henv)]
  rw [boundaryMatches x hx env henv]
  rw [upstreamCorrect (upstreamInput x env)
    (upstreamInputValid x hx env henv) (upstreamEnv x env)
    (upstreamEnvValid x hx env henv)]
  rw [upstreamSecretsAgree x hx env henv]
  rfl

namespace ConcreteSerial2

/-- The upstream gadget is a refresh, hence its unmasked function is identity
on its sole secret input. -/
def upstreamFunction (secrets : List Bool) : Bool :=
  secrets.getD 0 false

/-- The downstream gadget XORs its two unmasked inputs and refreshes the
result. -/
def downstreamFunction (secrets : List Bool) : Bool :=
  secrets.getD 0 false != secrets.getD 1 false

/-- Exact function of the concrete serial topology: refresh the first input,
feed it to downstream input zero, XOR it with external input one, and refresh
again. -/
def composedFunction (secrets : List Bool) : Bool :=
  serialFunction upstreamFunction downstreamFunction
    [secrets.getD 0 false] [secrets.getD 1 false]

theorem composedFunction_eq_xor (secrets : List Bool) :
    composedFunction secrets =
      (secrets.getD 0 false != secrets.getD 1 false) := by
  simp [composedFunction, serialFunction, upstreamFunction, downstreamFunction]

theorem upstream_recombines :
    recombinesTo upstream upstreamFunction := by
  decide

theorem downstream_recombines :
    recombinesTo downstream downstreamFunction := by
  decide

/-- The boundary premise needed for functional composition follows from the
existing construction lemmas: both component views evaluate the same node. -/
theorem connected_boundary_value_matches (env : Env) (share : Nat) :
    Execution.eval compositeCircuit composite.horizon env
        (embeddedUpstreamOutput share) =
      Execution.eval compositeCircuit composite.horizon env
        (connectedNode share) := by
  simpa only [connectedNode_eq_embedded_upstream_output share] using
    boundaryValuesAgree_by_construction env share

/-- Functional correctness of the concrete structural serial composite.
Unmasking its output yields the downstream XOR of the refreshed first secret
and the second external secret. -/
theorem composite_recombines :
    recombinesTo composite composedFunction := by
  decide

theorem composite_recombines_xor :
    recombinesTo composite (fun secrets =>
      secrets.getD 0 false != secrets.getD 1 false) := by
  unfold recombinesTo
  intro x hx env henv
  change xorList (observe composite (outputNodes composite) env) =
    ((secretsOf composite x).getD 0 false !=
      (secretsOf composite x).getD 1 false)
  rw [← composedFunction_eq_xor (secretsOf composite x)]
  exact composite_recombines x hx env henv

end ConcreteSerial2
end Composition
end LeanSec

#print axioms LeanSec.Composition.recombinesTo_serial_of_matching_boundary
#print axioms LeanSec.Composition.ConcreteSerial2.composite_recombines
#print axioms LeanSec.Composition.ConcreteSerial2.composite_recombines_xor
