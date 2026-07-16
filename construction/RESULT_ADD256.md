# 256-bit masked adder — MATCHI L2 composition result (transition model)

**Date:** 2026-07-15
**Verdict: PASS — 256-bit adder transition-verified via L1 (SILVER-per-gadget, unchanged
leaf) + L2 (MATCHI-netlist).**

The 256-bit two's-complement masked ripple adder (`top_add256_opini2.v`, 512 `MSKand_opini2_d2`
instances, 2/bit) composes securely in the **glitch+transition** model (MATCHI default;
`--no-check-transitions` NOT passed). Same discipline and same flow as the validated 8-bit
adder (`./`) — only the width changed.

- **L1 (per-gadget, unchanged):** the leaf `MSKand_opini2_d2` (O-PINI2 = HPC2 core + zero-sharing
  output refresh) is byte-identical to the SILVER-transition-proven 8-bit leaf — not modified,
  read-only reference. MATCHI black-boxes it (`matchi_prop="OPINI", matchi_strat="assumed"`); the
  existing L1 proof justifies the OPINI label.
- **L2 (netlist, this run):** MATCHI verifies the 256-bit ripple datapath — 512 assumed-OPINI
  leaves + strictly share-local XOR/NOT — composes securely.

## Verdict matrix

| # | Top module | leaf `matchi_prop` | mode | Expected | MATCHI | exit |
|---|---|---|---|---|---|---|
| 1 | `top_add256_opini2` | OPINI | add (sub=0) | PASS | `Verification successful.` | 0 |
| 2 | `top_add256_opini2` | OPINI | sub (sub=1) | PASS | `Verification successful.` | 0 |
| 3 | `top_add256_pini` (label control) | PINI | add | PASS (single-pass; see §Non-vacuity) | `Verification successful.` | 0 |
| 4 | `top_add256_rndreuse` (neg. control) | OPINI | add | **FAIL** (randomness reuse) | `Error: Random input r[0] … used in multiple places` | 1 |
| 5 | `top_add256_recomb` (neg. control) | OPINI | add | **FAIL** (share recombination) | `Error: … input sensitive in multiple shares (glitch leakage)` | 1 |

Cross-check (row 1 via the deliverable `synth_add256.ys` instead of the generic
`synth.tcl` used by `run_add256.sh`): identical verdict `Verification successful.`, exit 0
(`ys_cross_matchi.log`). Both synth paths keep the gadget as a black-box OPINI leaf and agree.

The two negative controls fire with the classic, netlist-specific errors:

**#4 randomness reuse** (`work_top_add256_rndreuse_sub0/matchi.log`) — names the two gadget
instances that were fed the same random bit directly:
```
Error: Random input r[0] at cycle 5 is used in multiple places:
	As fresh randomness in:
		u_generate_0 (at cycle 5)
		u_propagate_0 (at cycle 5)
```
**#5 share recombination** (`work_top_add256_recomb_sub0/matchi.log`) — flags the top-level
gate whose two inputs are sensitive in opposite shares (the `sum[0] ^ sum[1]` leak register):
```
Error: In module top_add256_recomb, checking instance $abc$…parse_blif$12045
Caused by:
    Gate has input sensitive in multiple shares (causes glitch leakage):
    	Input 0, shares: ShareSet{0}
    	Input 1, shares: ShareSet{1}
```

## MATCHI demonstrably read the gadget boundary (not flattened)

For every PASS run the synthesis kept all 512 gadgets as hierarchical black-box leaves — the
flow (`synth.tcl` / `synth_add256.ys`) never runs `flatten`, and `keep_hierarchy` is set on the
leaf. Confirmed two independent ways:

- **Synth JSON** (`top_add256_<top>_synth.json`): the leaf module survives with its attributes
  intact and the top has exactly 512 cells of that type —
  - `top_add256_opini2`: leaf `MSKand_opini2_d2`, `matchi_prop=OPINI`, **512 cells**
  - `top_add256_pini`:   leaf `MSKand_opini2_d2_pini`, `matchi_prop=PINI`, **512 cells**
  - `rndreuse`/`recomb`: leaf `MSKand_opini2_d2`, `matchi_prop=OPINI`, **512 cells** each
- **MATCHI log**: MATCHI addresses gadget instances by hierarchical path — it named **all 512
  distinct instances** `u_generate_0 … u_generate_255`, `u_propagate_0 … u_propagate_255` in
  every run (the rndreuse error above cites `u_generate_0`/`u_propagate_0` by name). A flattened
  netlist would have no such gadget-pathed nodes.

## Non-vacuity reasoning (honest scope)

The adder is **single-pass**: each of the 512 gadgets is executed once per addition (no gadget
output feeds back into the same gadget's input across the ripple — the carry chain threads
*distinct* per-bit `u_propagate` instances). Consequences:

- The two negative controls (#4 randomness reuse, #5 share recombination) are the load-bearing
  non-vacuity evidence: they prove MATCHI is genuinely tracking per-instance randomness and
  per-share sensitivity **on this 256-bit netlist**, not rubber-stamping. Both FAIL as required.
- The PINI label control (#3) is **EXPECTED to PASS and is recorded, NOT counted as
  non-vacuity.** For a single-pass circuit PINI composition already suffices, so relabelling the
  leaf OPINI→PINI cannot change the verdict — it does not exercise the OPINI-vs-PINI distinction.
  It is included only to show the label plumbing works end-to-end.
- The OPINI-vs-PINI distinction (transition leakage from bubble-free gadget *reuse*, which
  requires the stronger OPINI property) is carried by the **existing chain controls in the 8-bit
  dir**, not by the adder: `./top_chain_opini2` PASS vs `./top_chain_pini`
  FAIL (`Error: Transition leakage … no pipeline bubble`) — see
  `./ADDER_MATCHI_RESULT.md` rows 6–7. Those were not re-run here (they are
  width-independent gadget-reuse controls); the 256-bit adder does not reuse gadgets, so it does
  not itself distinguish the two labels — hence #3 passing under a PINI leaf is correct and not a
  gap.

## Reproduce (one command each, on the box)

```bash
cd .
./run_add256.sh top_add256_opini2   0          # row 1  -> exit 0 PASS
./run_add256.sh top_add256_opini2   1          # row 2  -> exit 0 PASS
./run_add256.sh top_add256_pini     0          # row 3  -> exit 0 PASS (label control)
./run_add256.sh top_add256_rndreuse 0          # row 4  -> exit 1 FAIL (multiple places)
./run_add256.sh top_add256_recomb   0 RECOMB   # row 5  -> exit 1 FAIL (multiple shares)
./ys_cross.sh                                  # row-1 cross-check via synth_add256.ys -> PASS
```

`run_add256.sh` is a direct mirror of the validated 8-bit `./run_one.sh`
(generic MATCHI `synth.tcl`, iverilog→VCD, MATCHI in the default transition model), fixed only to
select the leaf by the precise `_pini` suffix — a bare `*pini*` glob is wrong because the OPINI
tops contain the substring "o**pini**2".

## Files

| File | Role |
|---|---|
| `top_add256_opini2.v` | the 256-bit masked adder (512 OPINI leaves) — verified target |
| `top_add256_pini.v` / `top_add256_rndreuse.v` / `top_add256_recomb.v` | control tops (rows 3–5) |
| `synth_add256.ys` | deliverable synth script (black-box OPINI leaf; cross-checks row 1) |
| `tb_add256.v` | MATCHI testbench (activity windows E=514: b[0,513] a[1,514] r[0,1027] s[1,1028] out[0,1030]) |
| `run_add256.sh` | matrix runner (mirror of 8-bit `run_one.sh`) |
| `gen_add256.py` / `gen_controls256.py` | generators for the target / control Verilog |
| `work_top_add256_*/matchi.log` | per-run MATCHI logs |

Read-only reference (NOT modified): `./MSKand_opini2_d2.v`,
`./MSKand_opini2_d2_pini.v`, `./top_add8_opini2.v`.

## Latency invariance (digital side channel) — PASS, 2026-07-16

SINGLE-PASS FIXED SCHEDULE: pure feed-forward ripple datapath with constant activity windows; the only conditional in the RTL is the public counter/reset. Latency independent of operands.

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
