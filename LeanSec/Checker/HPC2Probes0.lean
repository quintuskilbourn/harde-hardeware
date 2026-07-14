import LeanSec.Checker.Fast
import LeanSec.Gadgets.HPC2

namespace LeanSec.Checker.HPC2Probes

open Gadget Gadgets.HPC2
set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

theorem p_empty : probeCheck gadget glitch [] = true := by decide
theorem p_0_2 : probeCheck gadget glitch [{ gate := 2, cycle := 0 }] = true := by decide
theorem p_0_3 : probeCheck gadget glitch [{ gate := 3, cycle := 0 }] = true := by decide
theorem p_0_4 : probeCheck gadget glitch [{ gate := 4, cycle := 0 }] = true := by decide
theorem p_0_8 : probeCheck gadget glitch [{ gate := 8, cycle := 0 }] = true := by decide
theorem p_0_11 : probeCheck gadget glitch [{ gate := 11, cycle := 0 }] = true := by decide
theorem p_1_0 : probeCheck gadget glitch [{ gate := 0, cycle := 1 }] = true := by decide
theorem p_1_1 : probeCheck gadget glitch [{ gate := 1, cycle := 1 }] = true := by decide

end LeanSec.Checker.HPC2Probes
