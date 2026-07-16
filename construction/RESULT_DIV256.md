# 256-bit masked DIV/MOD — MATCHI L2 composition result (transition model)

**Date:** 2026-07-16
**Verdict: PASS — 256-bit iterative restoring DIV/MOD (`q = A/B`, `rem = A%B`
for `B != 0`) transition-verified via L1 (SILVER-per-gadget, unchanged leaf) +
L2 (MATCHI netlist).**

`div256` is an iterative two-share restoring divider with **770 O-PINI2 gadget
instances** (`3N+2`: 257 `u_g_*` + 257 `u_t_*` subtractor gadgets and 256
`u_m_*` borrow-MUX gadgets). One physical subtract/MUX datapath is reused over
256 public-scheduled iterations. The run uses MATCHI's default glitch+transition
model; `--no-check-transitions` is not passed.

The core has the explicit precondition `B != 0`, which holds on the private-DEX
path because the divisor is `reserveIn + amountIn > 0`. The EVM-specific
`B == 0 -> q=rem=0` wrapper is the separate `divevm` composition documented in
`RESULT_DIVEVM.md`; it is not silently attributed to this core.

## Architecture

- Each MSB-first iteration forms `Rsh = (R << 1) | msb(A)` and computes
  `T = Rsh - B` using a 257-bit structural copy of the verified masked
  adder/subtractor dataflow (`Rsh + ~B + 1`). Its carry-out is `NOT borrow`, so
  the recombined carry is the next quotient bit `Rsh >= B`.
- The restoring select is
  `R' = Rsh XOR (cout AND (Rsh XOR T))`. The broadcast AND is 256 O-PINI2
  instances; the outer XOR and all shifts/register transfers are share-local.
- The 770 gadgets are instantiated once and reused bubble-free across all 256
  iterations with genuine feedback: the subtractor consumes the MUX-selected
  remainder from the previous iteration. This is the OPINI transition regime.
- Gadget timing follows the verified leaf contract (`inb@0`, `rnd@0`, `ina@1`,
  `s@1`, `out@3`). `Rsh_d` and `xm_d` are one-cycle, physically per-share
  balance registers; ripple carry inputs are naturally late as in the verified
  adder.
- The public iteration period is 528 cycles (`2N+16`). Outputs become stable at
  cycle 135169. A public counter supplies bounded activity windows and a
  share-local clear/drain tail; fresh randomness remains active through the
  drain.
- The gadget leaf is instantiated, never inlined. Its SHA-256 in
  `work_div256/hdl/MSKand_opini2_d2.v` is
  `a48c8e1d5f1bdd2d7b55b0d3c5042dc2944247ee67f8c54264044baa75e1fa80`,
  identical to `./MSKand_opini2_d2.v`.

## Verdict matrix

| # | Top module | leaf `matchi_prop` | Expected | MATCHI | exit |
|---|---|---|---|---|---|
| 1 | `div256` | OPINI | PASS | `Verification successful.` | 0 |
| 2 | `div256_pini` (label control) | PINI | **FAIL** (live transition-reuse control) | `Transition leakage failure: ... no pipeline bubble since then.` | 1 |
| 3 | `div256_rndreuse` (negative control) | OPINI | **FAIL** (randomness reuse) | `Random input r[514] ... used in multiple places` | 1 |
| 4 | `div256_recomb` (negative control) | OPINI | **FAIL** (share recombination) | `Gate has input sensitive in multiple shares (causes glitch leakage)` | 1 |

The negative controls fail for their planted, netlist-specific causes:

- `work_div256_pini/matchi.log` rejects `u_t_256` because its `inb[0]`
  depends on a previous execution of the same PINI-labelled gadget without a
  pipeline bubble. This is live evidence that the stronger O-PINI2 property is
  required by this reused datapath.
- `work_div256_rndreuse/matchi.log` reports `r[514]` at cycle 6 in multiple
  places after `u_m_1` is wired to `u_m_0`'s random pair.
- `work_div256_recomb/matchi.log` rejects the injected `q[0] XOR q[1]`
  register with input share sets `{0}` and `{1}`.

## MATCHI read the gadget boundary (not flattened)

- Each of the four synth JSON files contains exactly **770** preserved leaf
  cells: 770 `MSKand_opini2_d2` cells in the target/reuse/recomb netlists and
  770 `MSKand_opini2_d2_pini` cells in the PINI control. The leaf module and
  its MATCHI attributes remain in the JSON; the synthesis flow does not run
  `flatten`.
- The OPINI MATCHI log contains hierarchical paths for all **770 distinct**
  gadget instances: `u_g_0..256` (257), `u_t_0..256` (257), and
  `u_m_0..255` (256). A flattened datapath would not expose these paths.

## Functional smoke

`tb_smoke_div256.v` generates fresh two-share operands and fresh gadget
randomness, waits for all 256 iterations, recombines `q` and `rem`, and checks
both against Verilog's integer `/` and `%` reference operations. The six
vectors all pass (`smoke_div256.out`): `1/1`, random `/1`, `x/x`, `1/max`,
`max/3`, and random divided by a nonzero 128-bit divisor.

```
SMOKE: ALL PASS
EXIT=0
```

## Non-vacuity

All three controls are live on this exact 256-bit netlist. In particular, the
PINI relabel alone changes the target verdict from PASS to transition-leakage
FAIL, while the two planted negative controls independently prove that MATCHI
tracks per-instance randomness and both secret share sets. The baseline differs
from each negative control only by its deliberate bug.

MATCHI conservatively warns that early `q` output cycles are marked active
before those bits become sensitive. This is over-annotation, not a pass gap:
the activity window covers the eventual valid outputs, and the recombination
control proves MATCHI tracks both output shares when they are sensitive.

The N=16 pilot passed the same smoke and full matrix first (OPINI PASS; PINI,
randomness-reuse, and recombination controls FAIL), validating the iterative
schedule and counter-derived activity windows before the full-width run.

## Reproduce

```bash
cd .
python3 gen_div256.py
./run_smoke_div256.sh
./run_div256_matrix_detached.sh
cat DIV256_MATRIX_DONE
```

The expected marker is:

```
div256 opini: EXIT=0
div256 pini: EXIT=1
div256 rndreuse: EXIT=1
div256 recomb: EXIT=1
```

The full-width VCD/MATCHI run is long (roughly four hours on the construction
box). Individual rows can instead be reproduced with `run_div256.sh` in the
same pattern as the other primitives.

## Files

| File | Role |
|---|---|
| `div256.v` | 256-bit restoring DIV/MOD core — **verified target** |
| `div256_pini.v` / `div256_rndreuse.v` / `div256_recomb.v` | control tops |
| `gen_div256.py` | generator for the four tops and both testbenches |
| `tb_div256.v` | MATCHI activity testbench |
| `tb_smoke_div256.v` / `run_smoke_div256.sh` | functional smoke |
| `run_div256.sh` | per-top default-transition MATCHI flow |
| `run_div256_matrix_detached.sh` | complete matrix driver |
| `matrix_div256_*.out`, `work_div256*/matchi.log` | verdict summaries and detailed evidence |

Read-only references (not modified): `./MSKand_opini2_d2.v`,
`./MSKand_opini2_d2_pini.v`, and all verified ADD/SUB artifacts.

## Latency invariance (digital side channel) — PASS, 2026-07-16

FIXED-ITERATION restoring divider (same schedule as divevm256, which copies it verbatim): public FSM always runs N=256 iterations x K=528 cycles; no early-out, no data-dependent exit — the borrow bit steers data only through the masked borrow-mux gadgets, never the FSM.

**Evidence (one-command reproduce): `python3 audit_latency_invariance.py`
(exit 0, log `audit_latency_invariance.log`).** Static audit: every `if`/ternary
condition in the generated DUT RTL references ONLY public control (cycle
counters, counter-derived strobes, FSM phase/iteration registers, control-typed
address/enable inputs) — never a masked-data register. Non-vacuity: injecting a
data-dependent early-out (`running && !(coutr0 ^ coutr1)` in a copy of
divevm256.v) makes the audit FAIL (exit 1). Dynamic corroboration: the smoke tb
samples outputs at ONE compile-time-constant cycle for ALL vectors (including
extremes) and passes — a data-dependent latency would mismatch at a fixed
sample point.
