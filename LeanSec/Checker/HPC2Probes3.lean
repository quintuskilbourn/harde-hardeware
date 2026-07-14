import LeanSec.Checker.Fast
import LeanSec.Gadgets.HPC2

namespace LeanSec.Checker.HPC2Probes

open Gadget Gadgets.HPC2
set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

theorem p_2_21 : probeCheck gadget glitch [{ gate := 21, cycle := 2 }] = true := by decide
theorem p_2_23 : probeCheck gadget glitch [{ gate := 23, cycle := 2 }] = true := by decide
theorem p_2_25 : probeCheck gadget glitch [{ gate := 25, cycle := 2 }] = true := by decide
theorem p_2_26 : probeCheck gadget glitch [{ gate := 26, cycle := 2 }] = true := by decide
theorem p_2_27 : probeCheck gadget glitch [{ gate := 27, cycle := 2 }] = true := by decide
theorem p_2_28 : probeCheck gadget glitch [{ gate := 28, cycle := 2 }] = true := by decide
theorem p_2_29 : probeCheck gadget glitch [{ gate := 29, cycle := 2 }] = true := by decide

end LeanSec.Checker.HPC2Probes
