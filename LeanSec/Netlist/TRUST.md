# Netlist-to-Lean correspondence and trust boundary

## The correspondence claim

For each checked gadget, one flattened, SILVER-annotated standard-cell Verilog
netlist is the common input to two independent paths:

```text
                         SILVER verifier -> recorded verdicts
netlist N
                         netlist2lean.py -> Lean Circuit C -> kernel-checked anchors
```

The Lean claim is about `C`, not directly about Verilog. `netlist2lean.py` parses
the module ports and supported cell instances, expands each supported standard
cell into Lean primitives, derives a register-depth schedule, and emits a
`GadgetInstance`. The generated module is then checked for well-formedness,
functional recombination, and the relevant security verdict. The anchor module
also proves that the generated gadget and the independently hand-transcribed
gadget recombine to the same function and have the same security verdict.

This is a correspondence argument by a common source artifact plus differential
agreement. It is not a kernel proof of the Python parser.

## What is mechanical

- **Grounded:** the checked-in generated `*Gen.lean` circuit is produced from the
  checked-in SILVER-format netlist by `tools/netlist2lean/netlist2lean.py`; it is
  not copied from the hand-written Lean gadget.
- **Grounded:** within the parser's accepted flattened structural-Verilog subset,
  unsupported standard cells, missing pins, undriven nets, combinational cycles,
  inconsistent share annotations, and absent annotated inputs or outputs are
  fatal parser errors rather than silently dropped logic.
- **Grounded:** supported combinational cells are expanded into the closed Lean
  gate vocabulary. In the default mode, expansion-internal nodes are not probe
  candidates and each standard-cell output remains one member node. In
  `--conservative-members` mode, expansion-internal primitives are also members;
  this closes `GadgetInstance.WF` and checks a stronger probe set than SILVER's
  cell-output set. Registers become latency-one `.reg` gates and unused
  complementary DFF outputs are reported when dropped.
- **Grounded:** source roles come from SILVER port annotations. Gate cycles,
  member nodes, output cycles, horizon, and randomness nodes are derived by the
  parser rather than hand-entered in generated Lean.
- **Kernel-checked:** each anchor module proves the generated circuit is well
  formed and recombines to the intended unmasked function for every modeled
  input and randomness assignment.
- **Kernel-checked:** each anchor module proves the security verdict stated
  there, and separately pairs the generated gadget's recombination and verdict
  with the corresponding theorems for the hand-transcribed gadget.
- **Measured:** the recorded SILVER result is obtained by running SILVER on the
  same netlist artifact. Agreement on the checked function and verdict anchors
  cross-validates the parser/model path to that extent; SILVER is an independent
  differential oracle, not an axiom used by the Lean proof.

For composite cells such as NAND and XNOR, the emitted primitive tree computes
the same Boolean output. Under LeanSec's glitch expansion, only the latency-zero
cone frontier is observed. The default membership policy gives one probeable
node per source standard cell, with the same combinational frontier. The
conservative policy additionally admits probes on expansion-internal primitives;
a PASS there implies PASS for the smaller cell-output probe set, but a FAIL need
not correspond to a SILVER cell-level failure.

## What remains trusted

- The Python parser and emitter, including its Verilog subset, cell table, pin
  maps, annotation interpretation, primitive expansions, register scheduling,
  and membership construction, are trusted after review; they are not verified
  programs.
- The checked-in netlist must actually be the exact artifact supplied to SILVER.
  The reproduce scripts and recorded transcripts make substitution reviewable,
  but Lean does not authenticate a SILVER invocation.
- SILVER itself, its standard-cell library semantics, synthesis tools, and the
  recorded SILVER transcript are outside the Lean kernel. Differential agreement
  detects many translation errors but cannot prove that both paths do not share
  the same semantic mistake.
- The mapping from one standard-cell output to one eligible probe location, and
  the claim that primitive expansion preserves the relevant glitch frontier,
  are modeling assumptions reviewed against `LeanSec/Expansion.lean`; no
  cell-library-to-Lean refinement theorem is currently proved. Conservative
  membership avoids relying on the one-output-only restriction for positive
  proofs, at the cost of checking additional synthetic probe locations.
- SILVER port annotations do not encode all temporal assumptions. Where a
  gadget requires nonzero input-arrival cycles, those cycles must be supplied by
  an explicit parser mode or anchor contract and remain review-visible.

## Exact scope and residual gaps

1. **Function and verdict are not leakage equivalence.** Matching recombination
   and a finite set of PASS/FAIL predicates does not prove equality of all probe
   distributions, traces, simulators, or leakage at every order and model.
2. **ABC remapping prevents structural identity.** Synthesis may realize a
   Boolean operation using a different gate basis (for example XNOR after NAND).
   The established claim is function plus stated-verdict equivalence, not a
   gate-for-gate isomorphism between RTL, the netlist, and the hand Lean circuit.
3. **Netlist-to-GDS is open.** Placement, routing, buffering, clock-tree
   insertion, optimization, extracted parasitics, and signoff transformations
   after the verified netlist are not covered by these anchors.
4. **Model-to-physics is open.** LeanSec's probing, glitch, transition, and
   transition-plus-glitch semantics are abstractions. Analog coupling, delay,
   hazards outside the model, metastability, power/EM aggregation, process
   variation, and measurement capability are not derived from device physics.

Accordingly, the strongest warranted statement is: for the checked-in netlist,
the reviewed parser emits a well-formed Lean gadget that kernel-checks the stated
function and security anchors, those anchors agree with both SILVER on that
netlist and the independent hand transcription, and the remaining trust and
physical-realization gaps above are explicit.
