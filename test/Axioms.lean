import LeanSec.Circuit
import LeanSec.Execution
import LeanSec.Expansion
import LeanSec.Gadget
import LeanSec.Gadgets.TransitionLeak
import Anchors
import LeanSec.Composition.OPINIRealWork
import LeanSec.Netlist.XorRefreshAnchors
import LeanSec.Netlist.ParserWitnessXorRefresh
import LeanSec.Checker.Differential

namespace LeanSec.Circuit.Tests

private def sourceCircuit : Circuit :=
  { gates := #[{ kind := .inp 0 0, inputs := [] }] }

private def selfLoopCircuit : Circuit :=
  { gates := #[{ kind := .not, inputs := [(0, 0)] }] }

theorem sourceCircuit_wf : sourceCircuit.WF := by
  simp [sourceCircuit, WF, indicesOk, gateArityOk, combAcyclic,
    combEdges, kahnLoop, kahnStep, hasRemainingPred]

theorem selfLoop_rejected : selfLoopCircuit.combAcyclic = false := by
  simp [selfLoopCircuit, combAcyclic, combEdges, kahnLoop, kahnStep,
    hasRemainingPred]

end LeanSec.Circuit.Tests

namespace LeanSec.Expansion.Tests

private def coneCircuit : Circuit :=
  { gates := #[
      { kind := .inp 0 0, inputs := [] },
      { kind := .rnd 0, inputs := [] },
      { kind := .and, inputs := [(0, 0), (1, 0)] },
      { kind := .reg, inputs := [(2, 1)] },
      { kind := .xor, inputs := [(2, 0), (3, 0)] }
    ] }

theorem glitch_cone_anchor :
    glitch coneCircuit 3 { gate := 4, cycle := 2 } =
      [{ gate := 0, cycle := 2 }, { gate := 1, cycle := 2 },
       { gate := 3, cycle := 2 }] := by
  rfl

theorem transition_boundary_anchor :
    transition coneCircuit 3 { gate := 4, cycle := 0 } =
      [{ gate := 4, cycle := 0 }] := by
  rfl

theorem expansion_order_anchor :
    SameNodes
      (transitionGlitch coneCircuit 3 { gate := 4, cycle := 2 })
      (glitchTransition coneCircuit 3 { gate := 4, cycle := 2 }) := by
  exact expandTG_comm _ _ _

end LeanSec.Expansion.Tests

#print axioms LeanSec.Circuit.wf_iff
#print axioms LeanSec.Circuit.indicesOk_of_wf
#print axioms LeanSec.Circuit.combAcyclic_of_wf
#print axioms LeanSec.Circuit.combAcyclic_empty
#print axioms LeanSec.Circuit.wf_empty
#print axioms LeanSec.Circuit.Tests.sourceCircuit_wf
#print axioms LeanSec.Circuit.Tests.selfLoop_rejected
#print axioms LeanSec.Execution.lookupAssoc_nil
#print axioms LeanSec.Execution.envFrom_head
#print axioms LeanSec.Execution.relevantSrcs_empty
#print axioms LeanSec.Execution.assignmentsPattern_eq_filter
#print axioms LeanSec.Execution.lookupAssoc_none_of_not_mem
#print axioms LeanSec.Execution.lookupAssoc_some_mem
#print axioms LeanSec.Execution.lookupAssoc_some_of_mem_key
#print axioms LeanSec.Execution.envFrom_outside
#print axioms LeanSec.Execution.eraseDups_nodup
#print axioms LeanSec.Execution.assignments_keys
#print axioms LeanSec.Execution.matchesPattern_lookup_iff
#print axioms LeanSec.Execution.matches_supportedFixing
#print axioms LeanSec.Execution.fixingValid_of_assignment
#print axioms LeanSec.Execution.envsOf_eq_filtered
#print axioms LeanSec.Execution.eval_outside_horizon
#print axioms LeanSec.Execution.Tests.xorRegCircuit_wf
#print axioms LeanSec.Execution.Tests.eval_xor
#print axioms LeanSec.Execution.Tests.eval_register_boundary
#print axioms LeanSec.Execution.Tests.relevant_sources_covered
#print axioms LeanSec.Execution.Tests.empty_fixing_enumerates_eight
#print axioms LeanSec.Execution.Tests.one_fixed_source_enumerates_four
#print axioms LeanSec.Execution.Tests.fixing_removes_one_free_source
#print axioms LeanSec.Execution.Tests.contradictory_fixing_is_empty
#print axioms LeanSec.Execution.Tests.muxCtlCircuit_wf
#print axioms LeanSec.Execution.Tests.eval_mux_ctl_false
#print axioms LeanSec.Execution.Tests.eval_mux_ctl_true
#print axioms LeanSec.Execution.Tests.relevant_ctl_sources_covered
#print axioms LeanSec.Expansion.glitch_cycle
#print axioms LeanSec.Expansion.identity
#print axioms LeanSec.Expansion.transition_at_zero
#print axioms LeanSec.Expansion.transition_at_successor
#print axioms LeanSec.Expansion.expandTG_comm
#print axioms LeanSec.Expansion.Tests.glitch_cone_anchor
#print axioms LeanSec.Expansion.Tests.transition_boundary_anchor
#print axioms LeanSec.Expansion.Tests.expansion_order_anchor
#print axioms LeanSec.Gadgets.TransitionLeak.leakyCircuit_wf
#print axioms LeanSec.Gadgets.TransitionLeak.leak_trace
#print axioms LeanSec.Gadgets.TransitionLeak.leak_recombines
#print axioms LeanSec.Gadgets.TransitionLeak.leak_not_probing
#print axioms LeanSec.Gadgets.TransitionLeak.leak_glitch_probing
#print axioms LeanSec.Gadgets.TransitionLeak.fixed_recombines
#print axioms LeanSec.Gadgets.TransitionLeak.fixed_probing
#print axioms LeanSec.Gadget.count_normalized
#print axioms LeanSec.Gadget.eraseDups_nodup
#print axioms LeanSec.Gadget.eraseDups_eq_self_of_nodup
#print axioms LeanSec.Gadget.expandedNodes_nodup
#print axioms LeanSec.Gadget.probeParts_perm
#print axioms LeanSec.Gadget.probeParts_length
#print axioms LeanSec.Gadget.outputNodes_nodup
#print axioms LeanSec.Gadget.outputSharePart_map_perm
#print axioms LeanSec.Gadget.nodeRow_nodup
#print axioms LeanSec.Gadget.nodeRows_nodup
#print axioms LeanSec.Gadget.nodes_nodup
#print axioms LeanSec.Gadget.memberNodes_nodup
#print axioms LeanSec.Gadget.lookupAssoc_isSome_eq_contains
#print axioms LeanSec.Gadget.arrivalValue_isSome
#print axioms LeanSec.Gadget.fixingForInput_keys
#print axioms LeanSec.Gadget.fixingForInput_keys_eq
#print axioms LeanSec.Gadget.lookupAssoc_eq_of_mem_nodup
#print axioms LeanSec.Gadget.supportedFixing_fixingForInput
#print axioms LeanSec.Gadget.fixingForInput_valid
#print axioms LeanSec.Gadget.sum_map_two
#print axioms LeanSec.Gadget.assignmentsPattern_length_eq_of_isSome
#print axioms LeanSec.Gadget.envsForInput_cardinality
#print axioms LeanSec.Gadget.mem_boolVectors_iff
#print axioms LeanSec.Gadget.toggleAt_length
#print axioms LeanSec.Gadget.getD_toggleAt_ne
#print axioms LeanSec.Gadget.toggleAt_involutive
#print axioms LeanSec.Gadget.foldl_xor
#print axioms LeanSec.Gadget.xorList_cons
#print axioms LeanSec.Gadget.xorList_toggleAt
#print axioms LeanSec.Gadget.selectBits_toggleAt
#print axioms LeanSec.Gadget.boolVectors_nodup
#print axioms LeanSec.Gadget.toggleAt_boolVectors_perm
#print axioms LeanSec.Gadget.sharingFiber_toggle_perm
#print axioms LeanSec.Gadget.xorSharing_secret_independent
#print axioms LeanSec.Gadget.xorSharing_secret_independent_mem
#print axioms LeanSec.Gadget.eraseDups_perm_of_perm
#print axioms LeanSec.Gadget.expandedNodes_perm
#print axioms LeanSec.Gadget.observation_reorder_of_perm
#print axioms LeanSec.Gadget.take_observe_eraseDups_append
#print axioms LeanSec.Gadget.simulatable_iff_countInvariant
#print axioms LeanSec.Gadget.distEq_iff_perm
#print axioms LeanSec.Gadget.normalized_map
#print axioms LeanSec.Gadget.distEq_map
#print axioms LeanSec.Gadget.observation_samples_perm_of_distEq
#print axioms LeanSec.Gadget.flatMap_perm_of_pointwise
#print axioms LeanSec.Gadget.sharingProjections_count
#print axioms LeanSec.Gadget.sharingProjections_ne_nil
#print axioms LeanSec.Gadget.sharingProjections_secret_perm
#print axioms LeanSec.Gadget.sharingProjections_secret_perm_mem
#print axioms LeanSec.Gadget.multiSharingProjections_secret_perm
#print axioms LeanSec.Gadget.multiSharingProjections_ne_nil
#print axioms LeanSec.Gadget.multiSharingProjections_secret_perm_mem
#print axioms LeanSec.Gadget.boolVectors_add_perm
#print axioms LeanSec.Gadget.boolVectors_mul_perm
#print axioms LeanSec.Gadget.getD_drop
#print axioms LeanSec.Gadget.sharingSecret_eq_block
#print axioms LeanSec.Gadget.secretsOf_eq_blockSecrets
#print axioms LeanSec.Gadget.inputBit_eq_drop_getD
#print axioms LeanSec.Gadget.blockAt_getD
#print axioms LeanSec.Gadget.projection_eq_blockProjection
#print axioms LeanSec.Gadget.projection_eq_blockProjection_mem
#print axioms LeanSec.Gadget.blockAt_append_zero
#print axioms LeanSec.Gadget.blockAt_append_succ
#print axioms LeanSec.Gadget.blockSecrets_append
#print axioms LeanSec.Gadget.blockProjection_append
#print axioms LeanSec.Gadget.blockProjections_perm
#print axioms LeanSec.Gadget.gadgetFiberProjections_perm
#print axioms LeanSec.Gadget.gadgetFiberProjections_perm_mem
#print axioms LeanSec.Gadget.simulatableOn_secret_fibers
#print axioms LeanSec.Gadget.count_scaleList
#print axioms LeanSec.Gadget.scaleList_map
#print axioms LeanSec.Gadget.simulatableOn_map
#print axioms LeanSec.Gadget.simulatableOn_observe_perm
#print axioms LeanSec.Gadget.distEq_iff_supportCheck
#print axioms LeanSec.Gadget.boolVectors_length
#print axioms LeanSec.Gadget.combinations_length
#print axioms LeanSec.Gadget.combinations_sublist
#print axioms LeanSec.Gadget.mem_combinations_of_sublist
#print axioms LeanSec.Gadget.subsetsUpTo_bound
#print axioms LeanSec.Gadget.subsetsUpTo_sublist
#print axioms LeanSec.Gadget.mem_subsetsUpTo_of_sublist
#print axioms LeanSec.Gadget.probingSecure_iff_spec
#print axioms LeanSec.Gadget.pini_iff_spec
#print axioms LeanSec.Gadget.opini_iff_spec
#print axioms LeanSec.Gadget.ni_iff_spec
#print axioms LeanSec.Gadget.sni_iff_spec
#print axioms LeanSec.Gadget.outputUniform_iff_spec
#print axioms LeanSec.Gadget.opini_implies_pini
#print axioms LeanSec.Gadget.pini_implies_probing
#print axioms LeanSec.Gadget.eraseDups_length_le
#print axioms LeanSec.Gadget.Tests.bool_vectors_three
#print axioms LeanSec.Gadget.Tests.combinations_anchor
#print axioms LeanSec.Gadget.Tests.leaking_observation_not_simulatable
#print axioms LeanSec.Gadgets.DomAnd.circuit_wf
#print axioms LeanSec.Gadgets.DomAnd.secret_experiments_reached
#print axioms LeanSec.Gadgets.DomAnd.input_experiments_reached
#print axioms LeanSec.Gadgets.DomAnd.glitch_probing_one
#print axioms LeanSec.Gadgets.DomAnd.glitch_probing_one_spec
#print axioms LeanSec.Gadgets.DomAnd.standard_ni_one
#print axioms LeanSec.Gadgets.DomAnd.standard_ni_one_spec
#print axioms LeanSec.Gadgets.DomAnd.standard_sni_one
#print axioms LeanSec.Gadgets.DomAnd.standard_sni_one_spec
#print axioms LeanSec.Gadgets.DomAnd.not_glitch_sni_one
#print axioms LeanSec.Gadgets.DomAnd.not_glitch_sni_one_spec
#print axioms LeanSec.Gadgets.DomAnd.not_standard_pini_one
#print axioms LeanSec.Gadgets.DomAnd.not_standard_pini_one_spec
#print axioms LeanSec.Gadgets.DomAnd.output_uniform
#print axioms LeanSec.Gadgets.DomAnd.output_uniform_spec
#print axioms LeanSec.Gadgets.DomAnd.XBR.circuit_wf
#print axioms LeanSec.Gadgets.DomAnd.XBR.secret_experiments_reached
#print axioms LeanSec.Gadgets.DomAnd.XBR.input_experiments_reached
#print axioms LeanSec.Gadgets.DomAnd.XBR.not_probing
#print axioms LeanSec.Gadgets.DomAnd.XBR.not_probing_spec
#print axioms LeanSec.Gadgets.DomAnd.XBR.not_pini
#print axioms LeanSec.Gadgets.DomAnd.XBR.not_pini_spec
#print axioms LeanSec.Gadgets.DomAnd.NaiveAnd.secret_experiments_reached
#print axioms LeanSec.Gadgets.DomAnd.NaiveAnd.not_glitch_probing_one
#print axioms LeanSec.Gadgets.DomAnd.NaiveAnd.not_glitch_probing_one_spec
#print axioms LeanSec.Gadgets.HPC2.circuit_wf
#print axioms LeanSec.Gadgets.HPC2.gadget_wf
#print axioms LeanSec.Gadgets.HPC2.recombines
#print axioms LeanSec.Gadgets.HPC2.input_experiments_reached
#print axioms LeanSec.Gadgets.HPC2.secret_experiments_reached
#print axioms LeanSec.Gadgets.HPC2.glitch_pini_one
#print axioms LeanSec.Gadgets.HPC2.glitch_pini_one_spec
#print axioms LeanSec.Gadgets.HPC2.not_glitch_opini_one
#print axioms LeanSec.Gadgets.HPC2.not_glitch_opini_one_spec
#print axioms LeanSec.Gadgets.HPC2.glitch_probing_one
#print axioms LeanSec.Gadgets.HPC2.glitch_probing_one_spec
#print axioms LeanSec.Gadgets.HPC2.output_uniform
#print axioms LeanSec.Gadgets.HPC2.output_uniform_spec
#print axioms LeanSec.Gadgets.HPC2.DroppedRefresh.input_experiments_reached
#print axioms LeanSec.Gadgets.HPC2.DroppedRefresh.not_pini
#print axioms LeanSec.Gadgets.HPC2.DroppedRefresh.not_pini_spec
#print axioms LeanSec.Gadgets.OPINI2.recombines
#print axioms LeanSec.Gadgets.OPINI2.gadget_wf
#print axioms LeanSec.Gadgets.OPINI2.glitch_pini_one_spec
#print axioms LeanSec.Gadgets.OPINI2.output_uniform
#print axioms LeanSec.Gadgets.OPINI2.output_uniform_spec
#print axioms LeanSec.Gadgets.OPINI2.Chains.serial_hpc2_recombines
#print axioms LeanSec.Gadgets.OPINI2.Chains.serial_opini2_recombines
#print axioms LeanSec.Gadgets.OPINI2.Chains.parallel_hpc2_recombines
#print axioms LeanSec.Gadgets.DomAnd.gadget_wf
#print axioms LeanSec.Gadgets.OPINI2.Chains.serial_hpc2_circuit_wf
#print axioms LeanSec.Gadgets.OPINI2.Chains.serial_opini2_circuit_wf
#print axioms LeanSec.Gadgets.OPINI2.Chains.parallel_hpc2_circuit_wf
#print axioms LeanSec.Gadgets.OPINI2.Chains.serial_hpc2_wf
#print axioms LeanSec.Gadgets.OPINI2.Chains.serial_opini2_wf
#print axioms LeanSec.Gadgets.OPINI2.Chains.parallel_hpc2_wf

/- 2026-07-15 hardening (H1/H2/H4): non-degenerate O-PINI reconvergent
instance, fresh-netlist parser witness, checker differential battery. -/

#print axioms LeanSec.Composition.OPINIRealWork.realWork_wf
#print axioms LeanSec.Composition.OPINIRealWork.realWork_fanout
#print axioms LeanSec.Composition.OPINIRealWork.realWork_opini
#print axioms LeanSec.Composition.OPINIRealWork.realComposite_build
#print axioms LeanSec.Composition.OPINIRealWork.realWork_composite_opini
#print axioms LeanSec.Composition.OPINIRealWork.realWork_composite_pini
#print axioms LeanSec.Composition.OPINIRealWork.realWork_composite_probing
#print axioms LeanSec.Composition.OPINIRealWork.realComposite_g_eq
#print axioms LeanSec.Composition.OPINIRealWork.boundary_registers_latch_producer
#print axioms LeanSec.Composition.OPINIRealWork.producer_reused_by_three_consumers
#print axioms LeanSec.Composition.OPINIRealWork.outputs_reconverge
#print axioms LeanSec.Composition.OPINIRealWork.realWork_recombines
#print axioms LeanSec.Composition.OPINIRealWork.forkJoin_branch_degenerate
#print axioms LeanSec.Composition.OPINIRealWork.realWork_gates_nonconstant
#print axioms LeanSec.Composition.OPINIRealWork.realWork_branches_distinct
#print axioms LeanSec.Netlist.XorRefreshGen.circuit_wf
#print axioms LeanSec.Netlist.XorRefreshGen.recombines
#print axioms LeanSec.Netlist.XorRefreshGen.glitch_probing_one
#print axioms LeanSec.Netlist.ParserWitnessXorRefresh.supportedCellExpansion
#print axioms LeanSec.Netlist.ParserWitnessXorRefresh.parsedOutputs_frontier_refinement
#print axioms LeanSec.Checker.Differential.accepts_dom_and
#print axioms LeanSec.Checker.Differential.accepts_xor_refresh
#print axioms LeanSec.Checker.Differential.accepts_serial2_composite
#print axioms LeanSec.Checker.Differential.accepts_leaky_glitch_only
#print axioms LeanSec.Checker.Differential.accepts_real_work_tail
#print axioms LeanSec.Checker.Differential.rejects_xbr
#print axioms LeanSec.Checker.Differential.rejects_naive_and
#print axioms LeanSec.Checker.Differential.rejects_transition_leak
#print axioms LeanSec.Checker.Differential.shareCollapse_recombines
#print axioms LeanSec.Checker.Differential.shareCollapse_not_probing
#print axioms LeanSec.Checker.Differential.rejects_share_collapse
#print axioms LeanSec.Checker.Differential.rejects_share_collapse_transition
#print axioms LeanSec.Checker.Differential.checker_route_real_work_tail
