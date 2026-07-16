# 256-bit masked ISZERO — MATCHI L2 composition result (transition model)

**Date:** 2026-07-15
**Verdict: PASS — 256-bit masked ISZERO transition-verified via L1 (SILVER-per-gadget,
unchanged leaf) + L2 (MATCHI-netlist).**

`iszero256` is a masked ISZERO over a 256-bit two-share input: the output share pair
recombines to `1` iff the masked input recombines to `0`, else `0`. It is built as a
**balanced binary OR-reduction tree** — 8 levels, **exactly 255** masked-OR nodes
(128+64+32+16+8+4+2+1), one **O-PINI2 gadget per node** — followed by a share-local
complement. It composes securely in the **glitch+transition** model (MATCHI default;
`--no-check-transitions` NOT passed). Same discipline and same flow as the verified
256-bit adder (`./`, `top_add256_opini2.v`); only the datapath changed.

## What it computes (and the sibling primitives)

- **Masked OR** via De Morgan: `OR(x,y) = NOT( AND( NOT x, NOT y ) )`. On a 2-share
  masking `(v0,v1)` (value `v0^v1`), `NOT` is **strictly share-local** — `~v = (v0^1, v1)`,
  i.e. XOR `1` into share 0 only. `AND` is the O-PINI2 masked-AND gadget. So
  `OR-out = NOT(gadget-out) = (w0^1, w1)`. Every XOR/NOT in the tree touches share 0 or
  share 1 in isolation — **no gate ever mixes share 0 and share 1 of the same value.**
- **ISZERO**: OR-reduce all 256 masked bits (recombines to `a != 0`), then complement
  (share-local) → `a == 0`.
- **EQ(A,B) = ISZERO(A ^ B)** — a share-local XOR of the two operands feeding this same
  tree. Noted; not built/verified here (this deliverable is ISZERO).
- **Unsigned LT/GT** are NOT rebuilt here: unsigned `A < B` is the **borrow-out of the
  subtractor**, already delivered by the verified adder (`top_add256_opini2` with
  `sub=1`, `cout`); this is the DEX slippage comparison path.

## L1 / L2 split

- **L1 (per-gadget, unchanged):** the leaf `MSKand_opini2_d2` (O-PINI2 = HPC2 core + zero-
  sharing output refresh) is **byte-identical** to the SILVER-transition-proven leaf used by
  the adder — read-only reference (`./MSKand_opini2_d2.v`), not modified.
  MATCHI black-boxes it (`matchi_prop="OPINI", matchi_strat="assumed"`).
- **L2 (netlist, this run):** MATCHI verifies the 255-gadget OR-reduction tree + share-local
  NOT/XOR + the per-gadget balance registers composes securely.

## Verdict matrix

| # | Top module | leaf `matchi_prop` | Expected | MATCHI | exit |
|---|---|---|---|---|---|
| 1 | `iszero256` | OPINI | PASS | `Verification successful.` | 0 |
| 2 | `iszero256_pini` (label control) | PINI | PASS (single-pass; see §Non-vacuity) | `Verification successful.` | 0 |
| 3 | `iszero256_rndreuse` (neg. control) | OPINI | **FAIL** (randomness reuse) | `Error: Random input r[0] … used in multiple places` | 1 |
| 4 | `iszero256_recomb` (neg. control) | OPINI | **FAIL** (share recombination) | `Error: … input sensitive in multiple shares (glitch leakage)` | 1 |

Cross-check (row 1 via the deliverable `synth_iszero256.ys` instead of the generic
`synth.tcl` used by `run_iszero256.sh`): identical verdict `Verification successful.`,
exit 0 (`ys_cross_iszero_matchi.log`). Both synth paths keep the gadget a black-box OPINI
leaf and agree.

The two negative controls fire with the classic, netlist-specific errors:

**#3 randomness reuse** (`work_iszero256_rndreuse/matchi.log`) — names the two gadget
instances fed the same random bit directly (gadget 1 reuses gadget 0's `r[0]/s[0]` — both
level-0, same cycle):
```
Error: Random input r[0] at cycle 5 is used in multiple places:
	As fresh randomness in:
		u_or_0 (at cycle 5)
		u_or_1 (at cycle 5)
```
**#4 share recombination** (`work_iszero256_recomb/matchi.log`) — flags the gate whose two
inputs are sensitive in opposite shares (the `out[0] ^ out[1]` recombining register):
```
Caused by:
    Gate has input sensitive in multiple shares (causes glitch leakage):
    	Input 0, shares: ShareSet{0}
    	Input 1, shares: ShareSet{1}
```

## MATCHI demonstrably read the gadget boundary (not flattened)

For every run the synthesis kept all 255 gadgets as hierarchical black-box leaves — the flow
(`synth.tcl` / `synth_iszero256.ys`) never runs `flatten`, and `keep_hierarchy` is set on the
leaf. Confirmed two independent ways:

- **Synth JSON** (`work_<top>/<top>_synth.json`): the leaf module survives with its attributes
  intact and each top has exactly 255 cells of that type —
  - `iszero256`: leaf `MSKand_opini2_d2`, `matchi_prop=OPINI`, **255 cells**
  - `iszero256_pini`: leaf `MSKand_opini2_d2_pini`, `matchi_prop=PINI`, **255 cells**
  - `iszero256_rndreuse` / `iszero256_recomb`: leaf `MSKand_opini2_d2`, `matchi_prop=OPINI`,
    **255 cells** each
  - `synth_iszero256.ys` output (`iszero256_synth.json`): **255 cells**
- **MATCHI log**: MATCHI addresses gadget instances by hierarchical path — for `iszero256` it
  named **all 255 distinct instances** `u_or_0 … u_or_254` (the reuse error above cites
  `u_or_0`/`u_or_1` by name). A flattened netlist would have no such gadget-pathed nodes.

## Functional smoke (separate from the security check)

`tb_smoke_iszero256.v` shares each 256-bit operand with a random mask, holds it steady, waits
out the 8-level tree, recombines the output shares, compares to `(x == 0 ? 1 : 0)`. Fresh gadget
randoms every cycle (the recombined output is mask-independent). **6/6 PASS** on the required
vectors:

```
PASS  iszero=1  x=0000…0000     (input 0)
PASS  iszero=0  x=0000…0001     (input 1)
PASS  iszero=0  x=ffff…ffff     (all ones)
PASS  iszero=0  x=8000…0000     (single high bit, bit 255)
PASS  iszero=0  x=deadbeef…cbed (random)
PASS  iszero=1  x=0000…0000     (0 again, after a nonzero — transition)
SMOKE: ALL PASS
```

## Non-vacuity reasoning (honest scope)

The tree is **single-pass**: each of the 255 gadgets fires once per ISZERO (feed-forward tree;
no gadget output re-enters the same gadget). Consequences:

- The two negative controls (#3 randomness reuse, #4 share recombination) are the load-bearing
  non-vacuity evidence: they prove MATCHI is genuinely tracking per-instance randomness and
  per-share sensitivity **on this 256-bit tree netlist**, not rubber-stamping. Both FAIL as
  required, with the recombination-specific glitch-leakage error (a single share spans only one
  share set and would pass — the failure is specific to combining two shares). Baseline
  `iszero256` (no injected bug) passes; each control differs from it by exactly the bug.
- The PINI label control (#2) is **EXPECTED to PASS and is recorded, NOT counted as
  non-vacuity.** For a single-pass circuit PINI composition already suffices, so relabelling the
  leaf OPINI→PINI cannot change the verdict — it does not exercise the OPINI-vs-PINI distinction.
  Same reasoning as the adder's `top_add256_pini`. The OPINI-vs-PINI distinction (transition
  leakage from bubble-free gadget *reuse*, needing the stronger OPINI property) is carried by the
  gadget-reuse chain controls in `./` (`top_chain_opini2` PASS vs `top_chain_pini`
  FAIL); this tree does not reuse gadgets, so #2 passing under a PINI leaf is correct, not a gap.

**One design note (differs from the adder, honestly flagged):** each gadget's `ina` input carries
a share-local 1-cycle **balance register** (`ina0_k/ina1_k`), so `ina` arrives one cycle after
`inb` — matching the gadget's `ina@1 / inb@0` latency contract. In the adder this stagger came for
free (`ina` = carry from a prior stage, `inb` = a shallow combinational term); in a balanced tree
both children of a node sit at the same latency, so the register supplies the stagger explicitly.
Without it MATCHI rejects the very first gadget (`rnd is not a fresh random`) because it cannot
align the gadget execution cycle. The register is per-share (never mixes shares) and does not
change per-level output latency (the gadget already expected `ina` one cycle late).

MATCHI emits benign `output port … is not sensitive, while marked as such` warnings on the OPINI
runs: `out_act` is high from cycle 0 but the ISZERO output only becomes sensitive after the tree
computes (~cycle 24+). This is conservative over-marking, not a gap — the output IS sensitive at
the cycles it is valid (control #4 recombining `out[0]^out[1]` fails with per-share glitch leakage,
proving both `out` shares are tracked as sensitive), and `Verification successful` is emitted.

## Reproduce (one command each, on the box)

```bash
cd .
python3 gen_iszero256.py                        # (re)emit the 4 tops (255 gadgets each)
./run_smoke_iszero256.sh                         # functional: SMOKE: ALL PASS
./run_iszero256.sh iszero256                     # row 1  -> exit 0 PASS
./run_iszero256.sh iszero256_pini                # row 2  -> exit 0 PASS (label control)
./run_iszero256.sh iszero256_rndreuse            # row 3  -> exit 1 FAIL (multiple places)
./run_iszero256.sh iszero256_recomb RECOMB       # row 4  -> exit 1 FAIL (multiple shares)
./ys_cross_iszero.sh                             # row-1 cross-check via synth_iszero256.ys -> PASS
```

## Files

| File | Role |
|---|---|
| `iszero256.v` | the 256-bit masked ISZERO tree (255 OPINI leaves) — **verified target** |
| `iszero256_pini.v` / `iszero256_rndreuse.v` / `iszero256_recomb.v` | control tops (rows 2–4) |
| `synth_iszero256.ys` | deliverable synth script (black-box OPINI leaf; cross-checks row 1) |
| `gen_iszero256.py` | generator for all four tops (shared tree; controls differ only by the injected bug) |
| `tb_iszero256.v` | MATCHI testbench (activity windows E=32: a[0,40] r[0,68] s[1,69] out[0,72]) |
| `tb_smoke_iszero256.v` | functional smoke testbench |
| `run_iszero256.sh` | matrix runner (mirror of the adder's `run_add256.sh`) |
| `run_smoke_iszero256.sh` | functional smoke runner |
| `ys_cross_iszero.sh` | row-1 cross-check via `synth_iszero256.ys` |
| `work_iszero256*/matchi.log` | per-run MATCHI logs |

Read-only reference (NOT modified): `./MSKand_opini2_d2.v`,
`./MSKand_opini2_d2_pini.v`, and all verified adder artifacts in `./`.

## Latency invariance (digital side channel) — PASS, 2026-07-16

FIXED SCHEDULE: OR-reduce tree settles on a constant schedule (~4 cycles/level); single public conditional (counter/reset). Result is a masked share pair, never control.

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
