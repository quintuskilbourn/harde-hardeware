# RESULT — eq256: 256-bit masked EQ (= ISZERO(A ^ B)) — VERIFIED

**Date:** 2026-07-16 (construction workstream, iter 6).
**Unit:** `eq256` — out recombines to 1 iff A == B. Materializes the
composition noted (not built) in RESULT_ISZERO256.md: a share-local XOR stage
(d0 = a0^b0, d1 = a1^b1 — matching shares of two *different* sharings, never
two shares of one secret; **zero gadgets**) feeding the verified iszero256
OR-reduction tree verbatim (255 O-PINI2 `MSKand_opini2_d2` leaves, De Morgan
OR, per-gadget ina balance registers, E=32 streamed executions, identical
window constants — the XOR adds no gadget levels). Generator: `gen_eq256.py`.

## MATCHI L2 matrix (default transition model), 2026-07-16 ~02:45

| Top | Leaf | Expectation | Verdict | Evidence |
|---|---|---|---|---|
| `eq256` (OPINI target) | `MSKand_opini2_d2` | PASS | **PASS** — "Verification successful.", EXIT=0 | `matrix_eq256_opini.out`, `work_eq256/matchi.log` |
| `eq256_pini` (label control) | `MSKand_opini2_d2_pini` | PASS (single-pass tree ⇒ PINI suffices; recorded, NOT counted as non-vacuity — same as iszero256_pini) | **PASS** EXIT=0 | `matrix_eq256_pini.out` |
| `eq256_rndreuse` (NEG control) | `MSKand_opini2_d2` | FAIL | **FAIL** EXIT=1 — "Random input r[0] at cycle 5 is used in multiple places: … u_or_0 … u_or_1" | `work_eq256_rndreuse/matchi.log` |
| `eq256_recomb` (NEG control) | `MSKand_opini2_d2` | FAIL | **FAIL** EXIT=1 — "Gate has input sensitive in multiple shares (causes glitch leakage)" | `work_eq256_recomb/matchi.log` |

Non-vacuity / gadget-boundary checks:
- Exactly **255 gadget cells** in **all four** `work_eq256*/eq256*_synth.json`
  (assumed-OPINI black box preserved, not flattened).
- The OPINI `matchi.log` names **255/255 distinct `u_or_*` instances** —
  MATCHI read the composition at the gadget boundary.
- The pini PASS is expected for a single-pass feed-forward tree (no gadget
  reuse ⇒ the OPINI-vs-PINI transition distinction cannot bite); the LIVE
  OPINI-vs-PINI evidence for this campaign comes from the reuse-regime tops
  (div256/divevm16/swap16 pini FAILs).

Functional smoke (`smoke_eq256_sim`): **6/6 PASS** — 0==0, differ-in-LSB,
x==x, differ-in-MSB, complement, max==max.

## One-command reproduce

```
python3 gen_eq256.py && \
iverilog -g2012 -o smoke_eq256_sim eq256.v ./MSKand_opini2_d2.v tb_smoke_eq256.v && vvp smoke_eq256_sim && \
./run_eq256.sh eq256; ./run_eq256.sh eq256_pini; \
./run_eq256.sh eq256_rndreuse; ./run_eq256.sh eq256_recomb RECOMB
```
(exit codes 0 / 0 / 1 / 1)

**Verdict: eq256 VERIFIED (OPINI PASS + both negative controls FAIL + gadget
boundary read). The EVM EQ opcode's masked datapath is now explicit, not
argued-by-composition.**

## Latency invariance (digital side channel) — PASS, 2026-07-16

FIXED SCHEDULE: XOR + ISZERO-tree composition on constant windows; single public conditional. Latency independent of operands.

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
