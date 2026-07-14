import LeanSec.Gadgets.HPC2

namespace LeanSec.Checker.RawHPC2Benchmark

open Gadget Gadgets.HPC2

set_option maxRecDepth 10000
set_option maxHeartbeats 8000000

theorem glitch_raw : probingSecureFast gadget glitch 1 := by
  decide

#print axioms glitch_raw

end LeanSec.Checker.RawHPC2Benchmark
