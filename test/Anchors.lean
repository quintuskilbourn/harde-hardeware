import LeanSec.Gadgets.DomAnd
import LeanSec.Gadgets.HPC2
import LeanSec.Gadgets.OPINI2
import LeanSec.Gadgets.OPINI2Recombines

namespace LeanSec.Gadget.Tests

theorem bool_vectors_three : (boolVectors 3).length = 8 := by
  rfl

theorem combinations_anchor :
    combinations 2 [0, 1, 2] = [[0, 1], [0, 2], [1, 2]] := by
  rfl

private def leakingEnvs (x : List Bool) : List Env :=
  [Execution.envFrom [(.iniReg 0, x.getD 0 false)]]

private def leakingObs (env : Env) : Observation :=
  [env (.iniReg 0)]

/-- Regression for the v1.1 normalization repair: the formerly admissible
empty simulator cannot simulate an observation that reveals the secret. -/
theorem leaking_observation_not_simulatable :
    ¬SimulatableOn [[false], [true]] leakingEnvs (fun _ => []) leakingObs := by
  intro h
  rcases h with ⟨S, hpositive, hsim⟩
  have hpos := hpositive [false] (by simp)
  have hfalse := hsim [false] (by simp) [false]
  have htrue := hsim [true] (by simp) [false]
  simp [leakingEnvs, leakingObs, Execution.envFrom, Execution.lookupAssoc,
    countObs] at hfalse htrue
  have hpos' : (S []).length > 0 := by simpa using hpos
  omega

-- The pre-v1.1 statement `SimulatableOn ...` via `fun _ => []` is retained
-- only as this comment: normalization makes that witness unprovable.

end LeanSec.Gadget.Tests
