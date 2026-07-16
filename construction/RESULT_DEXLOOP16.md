# RESULT — dexloop16: SLOAD → swap → SSTORE composition pilot (VERIFIED)

**Date:** 2026-07-16 (construction iter 9). Target property: first-order
GLITCH+TRANSITION-robust d=1 probing security, MATCHI L2, **default
transition model** (transitions ON). Gadget-of-record: byte-identical
O-PINI2 leaf `./MSKand_opini2_d2.v` (instantiated, never
inlined).

## What this unit is

The last integration gap in `SWAP_DATAPATH.md`: storage (`store256x8`/
`store16x4`) and the swap program (`swap256`/`swap16`) were each verified
alone; `dexloop16` verifies the **load-compute-writeback loop** as one
netlist:

1. two preload SSTOREs put the shared reserves in the two-lane scratchpad
   (slot0 = reserveIn, slot1 = reserveOut);
2. `tx_go`: a public prefix FSM SLOADs both reserves through the registered
   per-lane read port (both lanes of a word captured at the SAME edge —
   the store16x4 paging rule);
3. the constant-product swap program (gen_swap256.py body, VERBATIM —
   only the reserve held-operand load sources are redirected from input
   ports to the SLOAD capture registers rri/rro) runs on its own counter;
4. WRITEBACK: slot0 <= D (newReserveIn) at swap-count OK_CAP+2, slot1 <=
   nror (newReserveOut) at OK_CAP+3 — per-lane write-value muxes (lane k
   logic sees only share-k values, public selects), strictly before the
   global clr.

Everything stays in the two-share Boolean domain; x (amountIn) and mo
(minOut) remain calldata input sharings; storage addresses/enables are
public control (EVM slot numbers of the DEX contract are public).

Generator: `gen_dexloop.py [N]` (N=16 pilot; imports `gen_swap256.py`
argv-patched, so the swap body, schedule constants and gadget budget are
byte-derived from the verified generator; storage lanes are a structural
copy of the verified `store16x4`, paging dropped). 218 gadgets (= swap16's
14N−6); the composition glue adds ZERO gadgets and ZERO randomness.

## MATCHI matrix (5 tops, one run each, `run_dexloop16_matrix.sh`)

| Top | Expectation | Verdict | Cause (from matchi.log) |
|---|---|---|---|
| `dexloop16` (O-PINI2 labels) | PASS | **PASS** (EXIT=0, "Verification successful.") | — |
| `dexloop16_pini` (label control) | FAIL | **FAIL** (EXIT=1) | LIVE transition leakage at `u_dg_15`: "depends on a previous execution of this gadget, there was no pipeline bubble since then" — the embedded bubble-free divider reuse, same family as div16_pini/swap16_pini |
| `dexloop16_rndreuse` | FAIL | **FAIL** (EXIT=1) | "Random input r[140] at cycle 188 is used in multiple places" (planted u_dm_1 ← u_dm_0 reuse; glue has no randomness, reuse planted in the embedded core — the eq256 convention) |
| `dexloop16_recomb` | FAIL | **FAIL** (EXIT=1) | "Gate has input sensitive in multiple shares (causes glitch leakage)" — the planted leak0 <= aout[0]^aout[1] register |
| `dexloop16_sharedbus` (**NEW-GLUE control**) | FAIL | **FAIL** (EXIT=1) | Wire `$0\bus[15:0]` "glitch-sensitive for multiple shares: ShareSet{0, 1}" — the SLOAD→swap hand-off routed through ONE time-muxed bus register (share 0 of the loaded reserve, then share 1 of the SAME word next edge) |

The sharedbus control is planted **in the new composition glue itself**
(the only new logic), so the matrix is non-vacuous exactly where this unit
adds risk: MATCHI demonstrably rejects the composition done wrong, and
accepts it done right (same-edge two-lane capture).

## Non-vacuity checks

- **218 / 218 / 218 / 218 / 218** `MSKand_opini2_d2*` gadget cells preserved
  in all five post-synth JSONs (no flattening).
- **218 unique `u_*` gadget instance names** appear in the opini matchi.log —
  MATCHI read the gadget boundary, not a flattened netlist.
- Verdict logs: `work_dexloop16*/matchi.log`, summaries
  `matrix_dexloop16_{opini,pini,rndreuse,recomb,sharedbus}.out`,
  driver log `dexloop16_matrix.log`.

## Functional smoke — 18/18 PASS (`smoke_dexloop16_sim`)

6 vectors × 3 checks each (direct outputs; slot0 readback == newReserveIn;
slot1 readback == newReserveOut — i.e. the round trip through the pad is
checked, not just the ALU outputs): AMM pool 2000×100/1100 with mo=0 /
boundary / slippage-trip (ok=0 observed), ri=0 x=1 edge, x=0 edge, random
full-width wrap vector. Reference is 16-bit wrap arithmetic (EVM semantics;
e.g. vector 1: num = 200000 mod 2^16 = 3392, aout = 3392/1100 = 3 —
matches).

## Reproduce

```
python3 gen_dexloop.py 16 && ./run_dexloop16_matrix.sh   # full matrix
iverilog -o smoke_dexloop16_sim tb_smoke_dexloop16.v dexloop16.v \
    ./MSKand_opini2_d2.v && vvp smoke_dexloop16_sim  # smoke
```

## Scaling note

N=256 composition would be `gen_dexloop.py 256` (mechanically identical;
the swap body is the same one whose N=256 matrix is in flight as swap256).
Pilot-level verification of the glue + full-width verification of both
constituents (store256x8, swap256-pending) is the evidence pattern used for
divevm (RESULT_DIVEVM.md).

## Latency invariance (digital side channel) — PASS, 2026-07-16

FIXED SCHEDULE end-to-end: SLOAD prefix on the public counter `pcnt` (constant slots 0/1), swap core on the global counter (all strobes cnt==const), writeback at fixed OK_CAP+2/+3. Total loop latency is a compile-time constant; storage addresses never derive from masked data.

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
