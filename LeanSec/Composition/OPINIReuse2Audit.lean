import LeanSec.Composition.OPINIReuse2
import LeanSec.Composition.UniformOPINIFalsify

/-! Trust audit for the order-2 demand-uniform O-PINI leaves and the
concrete order-2 reconvergent producer-reuse instantiation.  Every axiom
set below must be a subset of `{propext, Classical.choice, Quot.sound}`. -/

#print axioms LeanSec.Composition.uopini_iff_spec
#print axioms LeanSec.Composition.OPINIReuse2.producer_wf
#print axioms LeanSec.Composition.OPINIReuse2.forkJoin3_wf
#print axioms LeanSec.Composition.OPINIReuse2.forkJoin3_fanout
#print axioms LeanSec.Composition.OPINIReuse2.producer_uniform_opini
#print axioms LeanSec.Composition.OPINIReuse2.forkJoin3_uniform_opini
#print axioms LeanSec.Composition.OPINIReuse2.producer_opini
#print axioms LeanSec.Composition.OPINIReuse2.forkJoin3_opini
#print axioms LeanSec.Composition.OPINIReuse2.producerPipeline
#print axioms LeanSec.Composition.OPINIReuse2.forkJoin3Pipeline
#print axioms LeanSec.Composition.OPINIReuse2.reuse2Composite
#print axioms LeanSec.Composition.OPINIReuse2.reuse2Composite_build
#print axioms LeanSec.Composition.OPINIReuse2.reuse2Composite_g
#print axioms LeanSec.Composition.OPINIReuse2.reuse2Composite_g_eq
#print axioms LeanSec.Composition.OPINIReuse2.reuse2_opini
#print axioms LeanSec.Composition.OPINIReuse2.reuse2_uniform_opini
#print axioms LeanSec.Composition.OPINIReuse2.reuse2_pini
#print axioms LeanSec.Composition.OPINIReuse2.reuse2_probing
#print axioms LeanSec.Composition.OPINIReuse2.boundary_registers_latch_producer
#print axioms LeanSec.Composition.OPINIReuse2.producer_reused_by_two_consumers
#print axioms LeanSec.Composition.OPINIReuse2.outputs_reconverge
#print axioms LeanSec.Composition.OPINIReuse2.reuse2_recombines
#print axioms LeanSec.Composition.OPINIReuse2.compiled_probing
#print axioms LeanSec.Composition.UniformOPINIFalsify.leaky_not_uopini
#print axioms LeanSec.Composition.UniformOPINIFalsify.leaky_not_opini
