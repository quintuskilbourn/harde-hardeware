import LeanSec.Checker.HPC2Probes0
import LeanSec.Checker.HPC2Probes1
import LeanSec.Checker.HPC2Probes2
import LeanSec.Checker.HPC2Probes3

namespace LeanSec.Checker.HPC2SplitDemo

open Gadget Gadgets.HPC2 HPC2Probes

theorem reached : reachedCheck gadget = true :=
  reachedCheck_complete Gadgets.HPC2.secret_experiments_reached

theorem member_nodes : memberNodes gadget =
    [{ gate := 2, cycle := 0 }, { gate := 3, cycle := 0 },
     { gate := 4, cycle := 0 }, { gate := 8, cycle := 0 },
     { gate := 11, cycle := 0 }, { gate := 0, cycle := 1 },
     { gate := 1, cycle := 1 }, { gate := 5, cycle := 1 },
     { gate := 6, cycle := 1 }, { gate := 7, cycle := 1 },
     { gate := 9, cycle := 1 }, { gate := 10, cycle := 1 },
     { gate := 12, cycle := 1 }, { gate := 13, cycle := 1 },
     { gate := 15, cycle := 1 }, { gate := 17, cycle := 1 },
     { gate := 18, cycle := 1 }, { gate := 20, cycle := 1 },
     { gate := 22, cycle := 1 }, { gate := 24, cycle := 1 },
     { gate := 14, cycle := 2 }, { gate := 16, cycle := 2 },
     { gate := 19, cycle := 2 }, { gate := 21, cycle := 2 },
     { gate := 23, cycle := 2 }, { gate := 25, cycle := 2 },
     { gate := 26, cycle := 2 }, { gate := 27, cycle := 2 },
     { gate := 28, cycle := 2 }, { gate := 29, cycle := 2 }] := by
  decide

theorem combinations_one (xs : List Node) :
    combinations 1 xs = xs.map ([·]) := by
  induction xs with
  | nil => rfl
  | cons x xs ih => simp [combinations, ih]

theorem subsets_one (xs : List Node) :
    subsetsUpTo 1 xs = [] :: xs.map ([·]) := by
  unfold subsetsUpTo
  rw [show List.range (1 + 1) = [0, 1] by rfl]
  simp [combinations, combinations_one]

theorem all_probes :
    (subsetsUpTo 1 (memberNodes gadget)).all
      (probeCheck gadget glitch) = true := by
  rw [subsets_one, member_nodes]
  simp [p_empty,
    p_0_2, p_0_3, p_0_4, p_0_8, p_0_11,
    p_1_0, p_1_1, p_1_5, p_1_6, p_1_7, p_1_9, p_1_10,
    p_1_12, p_1_13, p_1_15, p_1_17, p_1_18, p_1_20, p_1_22, p_1_24,
    p_2_14, p_2_16, p_2_19, p_2_21, p_2_23, p_2_25, p_2_26,
    p_2_27, p_2_28, p_2_29]

theorem glitch_checker_true : splitChecker gadget glitch 1 = true := by
  simp only [splitChecker, reached, all_probes, Bool.true_and]

theorem glitch_probing_spec : probingSecureSpec gadget glitch 1 :=
  splitChecker_sound gadget glitch 1 glitch_checker_true

#print axioms glitch_checker_true
#print axioms glitch_probing_spec

end LeanSec.Checker.HPC2SplitDemo
