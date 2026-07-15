import LeanSec.Composition.OPINIReuse

/-! Trust audit for the generic O-PINI producer-reuse closure and its
concrete reconvergent instantiation.  Every axiom set below must be a
subset of `{propext, Classical.choice, Quot.sound}`. -/

#print axioms LeanSec.Composition.uniformOpini_implies_opini
#print axioms LeanSec.Composition.opini_implies_uniform_of_le_one
#print axioms LeanSec.Composition.compose_uniform_opini
#print axioms LeanSec.Composition.compose_opini
#print axioms LeanSec.Composition.UOPipelineGadget.opini
#print axioms LeanSec.Composition.UOPipelineGadget.pini
#print axioms LeanSec.Composition.UOPipelineGadget.probing
#print axioms LeanSec.Composition.UOPipelineGadget.toOPINIPipelineGadget
#print axioms LeanSec.Composition.UOPipelineGadget.ofUniformLeaf
#print axioms LeanSec.Composition.UOPipelineGadget.ofLeaf
#print axioms LeanSec.Composition.UOPipelineGadget.withPorts
#print axioms LeanSec.Composition.UOPipelineGadget.compose
#print axioms LeanSec.Composition.UOPipelineGadget.wire
#print axioms LeanSec.Composition.OPINIComposition.opini
#print axioms LeanSec.Composition.OPINIComposition.pini
#print axioms LeanSec.Composition.OPINIComposition.probing
#print axioms LeanSec.Composition.OPINIReuse.forkJoin_opini
#print axioms LeanSec.Composition.OPINIReuse.forkJoin_fanout
#print axioms LeanSec.Composition.OPINIReuse.reuseComposite
#print axioms LeanSec.Composition.OPINIReuse.reuseComposite_build
#print axioms LeanSec.Composition.OPINIReuse.reuseComposite_g
#print axioms LeanSec.Composition.OPINIReuse.reuseComposite_g_eq
#print axioms LeanSec.Composition.OPINIReuse.reuse_opini
#print axioms LeanSec.Composition.OPINIReuse.reuse_pini
#print axioms LeanSec.Composition.OPINIReuse.reuse_probing
#print axioms LeanSec.Composition.OPINIReuse.boundary_registers_latch_producer
#print axioms LeanSec.Composition.OPINIReuse.producer_reused_by_two_consumers
#print axioms LeanSec.Composition.OPINIReuse.outputs_reconverge
#print axioms LeanSec.Composition.OPINIReuse.reuse_recombines
