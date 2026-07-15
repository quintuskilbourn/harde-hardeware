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
import LeanSec.Netlist.ScanCellRefinement
import LeanSec.Netlist.ParserWitnessScanDff
import LeanSec.Fault.SifaAnchor
import LeanSec.Fault.SifaDataAnchor

import LeanSec.Composition.ConcreteTree
import LeanSec.Composition.DAGAudit
import LeanSec.Composition.OPINIClosureAudit
import LeanSec.Composition.OPINIReuse
import LeanSec.Composition.OPINIFixpointAudit
import LeanSec.Composition.OPINIReuse2
import LeanSec.Composition.UniformOPINIFalsify
import LeanSec.Composition.OPINIReuse2Audit
import LeanSec.Checker.Bitslice
import LeanSec.Gadgets.FullAdder
import LeanSec.Gadgets.FullAdderCompositionWall
import LeanSec.Checker.Differential
import LeanSec.Composition.OPINIRealWork
import LeanSec.Netlist.ParserWitnessXorRefresh
import LeanSec.Netlist.XorRefreshAnchors
/-! Full-verification aggregator for the 2026-07-13 fleet result modules.
`lake build LeanSec.All` re-checks them all. Heavy box-only decides
(Checker.HPC2SplitDemo / HPC2Probes* / RawHPC2Benchmark) are excluded. -/
