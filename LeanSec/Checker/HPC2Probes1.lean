import LeanSec.Checker.Fast
import LeanSec.Gadgets.HPC2

namespace LeanSec.Checker.HPC2Probes

open Gadget Gadgets.HPC2
set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

theorem p_1_5 : probeCheck gadget glitch [{ gate := 5, cycle := 1 }] = true := by decide
theorem p_1_6 : probeCheck gadget glitch [{ gate := 6, cycle := 1 }] = true := by decide
theorem p_1_7 : probeCheck gadget glitch [{ gate := 7, cycle := 1 }] = true := by decide
theorem p_1_9 : probeCheck gadget glitch [{ gate := 9, cycle := 1 }] = true := by decide
theorem p_1_10 : probeCheck gadget glitch [{ gate := 10, cycle := 1 }] = true := by decide
theorem p_1_12 : probeCheck gadget glitch [{ gate := 12, cycle := 1 }] = true := by decide
theorem p_1_13 : probeCheck gadget glitch [{ gate := 13, cycle := 1 }] = true := by decide
theorem p_1_15 : probeCheck gadget glitch [{ gate := 15, cycle := 1 }] = true := by decide

end LeanSec.Checker.HPC2Probes
