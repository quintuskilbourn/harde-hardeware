# 256-bit masked MUL — MATCHI L2 composition result (transition model)

**Date:** 2026-07-15
**Verdict: PASS — 256-bit masked MUL (EVM: `prod = A*B mod 2^256`) transition-verified
via L1 (SILVER-per-gadget, unchanged leaf) + L2 (MATCHI-netlist).**

`mul256` is an **iterative carry-save multiplier** over a 256-bit two-share datapath:
**1276 O-PINI2 gadget instances** (`5N-4`: 256 PP-gating `u_pp_*`, 2×255 carry-save MAJ
`u_sc_*`/`u_px_*`, 2×255 final ripple-add `u_g_*`/`u_t_*` — the verified-adder dataflow
with `sub=0`; the top-bit carry gadgets are omitted because mod 2^256 drops their
carries), iterated by a public FSM over 256 iterations (period K=8, ~2600 cycles total).
It composes securely in the **glitch+transition** model (MATCHI default;
`--no-check-transitions` NOT passed). This is the DEX critical path (`y*amountIn`).

## Architecture (design record — why carry-save)

- Fully unrolled schoolbook needs ~196k gadgets (past yosys/MATCHI tractability);
  reusing the ripple adder per partial product needs ~132k cycles. Carry-save keeps
  both small: 1276 gadgets, ~2600 cycles.
- Per iteration i (invariant `S + C == sum_{k<i} PP_k mod 2^N`):
  `PP = (A<<i) AND broadcast(B[i])` (N gadgets); `newS = S^C^PP` (share-local);
  `newC = ((S&C) ^ (PP&(S^C))) << 1` (MAJ carry, 2 gadgets/bit); `A<<=1; B>>=1`
  (share-local shifts). After 256 iterations: `prod = S + C mod 2^256` via a verbatim
  structural copy of the verified adder dataflow.
- **The 1276 gadgets are REUSED bubble-free across all 256 iterations with genuine
  feedback** (C depends on the same gadgets' previous outputs) — the OPINI regime.
- Every XOR/NOT/shift is strictly share-local; no gate ever mixes share 0 and share 1
  of any masked value. The gadget is INSTANTIATED (never inlined), byte-identical leaf
  `./MSKand_opini2_d2.v` (read-only reference).
- Gadget latency contract (`inb@0, rnd@0, ina@1, s@1, out@3`): every `ina` goes through
  a 1-cycle per-share balance register (the iszero256 pattern) or is the naturally-late
  ripple carry (the adder pattern).
- State-register sensitivity is bounded in time: a control-derived `clr` pulse zeroes
  the state registers after the output window; randoms stay fresh through the drain.

## Verdict matrix

| # | Top module | leaf `matchi_prop` | Expected | MATCHI | exit |
|---|---|---|---|---|---|
| 1 | `mul256` | OPINI | PASS | `Verification successful.` | 0 |
| 2 | `mul256_pini` (label control) | PINI | recorded (see §Non-vacuity) | `Verification successful.` | 0 |
| 3 | `mul256_rndreuse` (neg. control) | OPINI | **FAIL** (randomness reuse) | `Error: Random input r[0] … multiple places` | 1 |
| 4 | `mul256_recomb` (neg. control) | OPINI | **FAIL** (share recombination) | `Error: … sensitive in multiple shares (glitch leakage)` | 1 |

**#3** (`work_mul256_rndreuse/matchi.log`) names the two same-cycle gadget instances fed
the same random bit:
```
Error: Random input r[0] at cycle 6 is used in multiple places:
	As fresh randomness in:
		u_pp_0 (at cycle 6)
		u_pp_1 (at cycle 6)
```
**#4** (`work_mul256_recomb/matchi.log`) flags the injected `prod[0]^prod[1]` register:
```
Caused by:
    Gate has input sensitive in multiple shares (causes glitch leakage):
    	Input 0, shares: ShareSet{0}
    	Input 1, shares: ShareSet{1}
```

## MATCHI demonstrably read the gadget boundary (not flattened)

- **Synth JSON** (`work_<top>/<top>_synth.json`): exactly **1276** leaf cells preserved
  with attributes intact in each of the four netlists (leaf `MSKand_opini2_d2`, or
  `MSKand_opini2_d2_pini` for row 2). The flow never runs `flatten`; `keep_hierarchy`
  is set on the leaf.
- **MATCHI log**: the OPINI run addresses **all 1276 distinct gadget instances** by
  hierarchical path — 256 `u_pp_*`, 255 `u_sc_*`, 255 `u_px_*`, 255 `u_g_*`, 255 `u_t_*`.
  A flattened netlist would have no such gadget-pathed nodes.

## Functional smoke (separate from the security check)

`tb_smoke_mul256.v`: shares each operand with a random mask, pulses `go`, waits out the
256 iterations + final ripple, recombines the product shares, compares against
`(x*y) mod 2^256`. Fresh gadget randoms every cycle. **6/6 PASS** (`smoke_mul256.out`):
`0*0`, `1*1`, `x*1=x`, `2^255*2=0` (wrap), `(-1)*(-1)=1 mod 2^256`, random×random.

## Non-vacuity reasoning (honest scope)

- The negative controls #3/#4 are the load-bearing evidence that MATCHI genuinely tracks
  per-instance randomness and per-share sensitivity on THIS 1276-gadget netlist. Both
  fail with the classic netlist-specific errors; the baseline differs from each control
  by exactly the injected bug.
- The PINI label control (#2) **passed and is recorded, NOT counted as non-vacuity**.
  Despite the bubble-free reuse, MATCHI's PINI transition rule did not fire on this
  structure (its trigger is a gadget input depending on a previous execution of the
  *same* gadget with no bubble; the multiplier's feedback path evidently does not meet
  the rule's syntactic trigger here). The OPINI-vs-PINI distinction is carried natively
  by the **divider** (`div16_pini` FAILS with `Transition leakage failure: … depends on
  a previous execution of this gadget, there was no pipeline bubble since then`, see
  `RESULT_DIV256.md`) and by the adder-dir chain controls (`top_chain_opini2` PASS vs
  `top_chain_pini` FAIL).
- MATCHI emits benign `output port prod[i] is not sensitive, while marked as such`
  warnings: `out_act` is conservatively high before the product becomes sensitive.
  Control #4 proves both `prod` shares ARE tracked as sensitive where it matters.

## N=16 pilot

The same generator at `N=16` (`gen_mul256.py 16`) passed the identical matrix first
(smoke 6/6; OPINI PASS / pini PASS / rndreuse FAIL / recomb FAIL — `work_mul16*/`),
de-risking the 256-bit runs.

## Reproduce (one command each, on the box)

```bash
cd .
python3 gen_mul256.py                       # (re)emit the 4 tops (1276 gadgets each)
./run_smoke_mul256.sh                        # functional: SMOKE: ALL PASS
./run_mul256.sh mul256                       # row 1 -> exit 0 PASS
./run_mul256.sh mul256_pini                  # row 2 -> exit 0 (label control)
./run_mul256.sh mul256_rndreuse              # row 3 -> exit 1 FAIL (multiple places)
./run_mul256.sh mul256_recomb RECOMB         # row 4 -> exit 1 FAIL (multiple shares)
```

**Reproduce audit (2026-07-16 21:48):** the N=16 pilot matrix was re-run
end-to-end from a clean `./audit_matrix16.sh` (fresh synth+sim+MATCHI per top,
`audit_matrix16.log`) and reproduced the exact expected exits —
`mul16 = 0`, `mul16_pini = 0`, `mul16_rndreuse = 1`, `mul16_recomb = 1`.
The N=256 re-run (`./audit_matrix.sh`, `audit_matrix.log`) **CLOSED
2026-07-16 ~22:26 CEST with the exact expected exit vector**:
`AUDIT_EXIT mul256 = 0` (opini PASS), `AUDIT_EXIT mul256_pini = 0` (label
control PASS), `AUDIT_EXIT mul256_rndreuse = 1` (randomness-reuse control
FAIL, as required), `AUDIT_EXIT mul256_recomb = 1` (share-recombination
control FAIL, as required), then `ALLDONE`. The full mul256 matrix is
therefore reproducible end-to-end (fresh synth + sim + MATCHI per row) with
the MATCHI binary of record — reproduce-audit obligation DISCHARGED.

## Files

| File | Role |
|---|---|
| `mul256.v` | the 256-bit masked multiplier (1276 OPINI leaves) — **verified target** |
| `mul256_pini.v` / `mul256_rndreuse.v` / `mul256_recomb.v` | control tops (rows 2–4) |
| `gen_mul256.py` | generator for all four tops + both tbs (usage: `gen_mul256.py [N]`) |
| `tb_mul256.v` | MATCHI testbench (windows: a/b [0,1], r [0,2601], s [1,2602], out [0,2569]) |
| `tb_smoke_mul256.v` / `run_smoke_mul256.sh` | functional smoke |
| `run_mul256.sh` | matrix runner (mirror of `run_iszero256.sh`) |
| `matrix_mul256_*.out` | per-run verdict summaries |
| `work_mul256*/matchi.log` | per-run MATCHI logs |

Read-only reference (NOT modified): `./MSKand_opini2_d2.v`,
`./MSKand_opini2_d2_pini.v`, and all verified adder/ISZERO artifacts.

## Latency invariance (digital side channel) — PASS, 2026-07-16

NO-EARLY-OUT by construction: all N=256 partial-product iterations always execute (8-phase FSM x 256, iteration i occupies cycles [1+8i, 8+8i]; S/C final from cycle 2049, ripple stable ~2568 — compile-time constants). No skip-on-zero-PP or operand-dependent shortcut exists; operand bits reach only gadget data ports.

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
