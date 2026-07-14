import LeanSec.Checker.Fast
import LeanSec.Gadgets.HPC2

namespace LeanSec.Checker.HPC2Probes

open Gadget Gadgets.HPC2
set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

theorem p_1_17 : probeCheck gadget glitch [{ gate := 17, cycle := 1 }] = true := by decide
theorem p_1_18 : probeCheck gadget glitch [{ gate := 18, cycle := 1 }] = true := by decide
theorem p_1_20 : probeCheck gadget glitch [{ gate := 20, cycle := 1 }] = true := by decide
theorem p_1_22 : probeCheck gadget glitch [{ gate := 22, cycle := 1 }] = true := by decide
theorem p_1_24 : probeCheck gadget glitch [{ gate := 24, cycle := 1 }] = true := by decide
theorem p_2_14 : probeCheck gadget glitch [{ gate := 14, cycle := 2 }] = true := by decide
theorem p_2_16 : probeCheck gadget glitch [{ gate := 16, cycle := 2 }] = true := by decide
theorem p_2_19 : probeCheck gadget glitch [{ gate := 19, cycle := 2 }] = true := by decide

end LeanSec.Checker.HPC2Probes
