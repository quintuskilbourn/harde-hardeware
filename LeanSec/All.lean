import LeanSec
import LeanSec.Netlist.DomAnd
import LeanSec.Netlist.HPC2
import LeanSec.Netlist.CellRefinementAxioms
import LeanSec.Netlist.CircuitRefinement
import LeanSec.Netlist.CircuitRefinementGeneric
import LeanSec.Netlist.CircuitRefinementClosed
import LeanSec.Composition.Axioms
import LeanSec.Composition.ConcreteSerial2
import LeanSec.Composition.GenericSerial2
import LeanSec.Checker.Fast
import LeanSec.Gadgets.Fig4a
/-! Full-verification aggregator for the 2026-07-13 fleet result modules.
`lake build LeanSec.All` re-checks them all. Heavy box-only decides
(Checker.HPC2SplitDemo / HPC2Probes* / RawHPC2Benchmark) are excluded. -/
