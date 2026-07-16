# RESULT — divevm: EVM-compliant masked DIV/MOD (B==0 → 0), zero-gating composition

**Date:** 2026-07-16 (construction workstream, iter 6; N=256 smoke updated iter 8).
**Unit:** `divevm{N}` — q = (B==0) ? 0 : A/B, rem = (B==0) ? 0 : A%B. Closes the
SWAP_DATAPATH.md "EVM DIV/MOD by zero → 0" composition note with MATCHI evidence
(previously an argued-but-unverified composition; the DEX swap path itself never
needs it since its divisor `reserveIn+amountIn > 0`, so this is EVM-compliance
polish, not swap-critical).

## Architecture (composition of three already-verified dataflows, no new gadget types)

1. **DIV core** — verbatim structural copy of the `gen_div256.py` restoring
   divider: 3N+2 gadgets (2(N+1) ripple-subtract = the verified-adder dataflow
   with sub=1, + N borrow-mux broadcast-ANDs), bubble-free reuse across N
   iterations with genuine feedback (the OPINI regime).
2. **Nonzero tree** — the `gen_iszero256.py` De-Morgan OR-reduction tree (N−1
   gadgets, per-gadget ina balance registers) over B captured at go. The gate
   needed is NOT(ISZERO(B)) = OR-reduce(B) = (B≠0), so the tree **root is used
   directly — the two share-local NOTs cancel**; z is never materialized. Root
   captured into a per-share register `nzr` at cnt==Z_CAP (any post-settle cycle
   yields a consistent share pair; the recombined value is rnd-independent).
3. **Zero-gating** — qe[j] = Q[j] AND nz, reme[j] = R[j] AND nz: 2N gadgets in
   the broadcast-AND pattern verified in mul256 PP-gating and the div borrow-mux
   (inb = registered broadcast `nzr`, ina = 1-cycle per-share delay of Q/R).

Gadget budget **NG = 6N+1**, every gadget a dedicated r[k]/s[k] pair (div core
r[0..3N+1], tree r[3N+2..4N], gating r[4N+1..6N]). Every XOR/NOT strictly
share-local; shares never recombine. Activity windows from the div256
idempotent cycle counter; windows never close inside the trace (tb randfills to
$finish — the keccak f2e50d60f rule). Generator: `gen_divevm.py [N]`.

## N=16 pilot — VERIFIED (full matrix, 2026-07-16 ~02:20)

NG = 97 (50 div + 15 tree + 32 gate).

| Top | Leaf | Expectation | Verdict | Evidence |
|---|---|---|---|---|
| `divevm16` (OPINI target) | `MSKand_opini2_d2` | PASS | **PASS** — "Verification successful.", EXIT=0 | `matrix_divevm16_opini.out`, `work_divevm16/matchi.log` |
| `divevm16_pini` (label control, LIVE) | `MSKand_opini2_d2_pini` | FAIL (bubble-free div-core reuse) | **FAIL** EXIT=1 — "Transition leakage failure: Input inb[0] … depends on a previous execution of this gadget, there was no pipeline bubble since then" | `work_divevm16_pini/matchi.log` |
| `divevm16_rndreuse` (NEG control) | `MSKand_opini2_d2` | FAIL | **FAIL** EXIT=1 — "Random input r[65] at cycle 54 is used in multiple places: … u_gq_0 … u_gq_1" | `work_divevm16_rndreuse/matchi.log` |
| `divevm16_recomb` (NEG control) | `MSKand_opini2_d2` | FAIL | **FAIL** EXIT=1 — "Gate has input sensitive in multiple shares (causes glitch leakage)" | `work_divevm16_recomb/matchi.log` |

Notes on the controls:
- The **rndreuse bug is planted in the NEW gating stage** (u_gq_1 reuses
  u_gq_0's r/s, both active in the same cycles), so the negative control
  exercises exactly what this top adds over the already-verified div core —
  and MATCHI names precisely those two instances (r[65] = index GATE_BASE =
  4N+1 = 65 for N=16).
- The pini label control is **LIVE** (fails on the div-core transition rule,
  same class as div16/div256_pini) — the OPINI-vs-PINI distinction is
  non-vacuous on this netlist.
- The recomb control registers qe[0]^qe[1] (the new gated output).

Non-vacuity / gadget-boundary checks:
- Exactly **97 `MSKand_opini2_d2` cells** (resp. `_pini`) in **all four**
  `work_divevm16*/divevm16*_synth.json` — the leaf survives synthesis as an
  assumed-OPINI black box, not flattened.
- The OPINI `matchi.log` names **97/97 distinct gadget instances**
  (u_g_×17, u_t_×17, u_m_×16, u_or_×15, u_gq_×16, u_gr_×16) — MATCHI read the
  composition at the gadget boundary.
- Benign warning "output port qe[24] is not sensitive, while marked as such":
  the out_act window is a deliberate superset (safe over-approximation
  direction), same warning class as the other verified tops.

Functional smoke (`run_smoke_divevm.sh 16`): **8/8 PASS**, including the three
B=0 vectors (1/0, 0/0, x/0 → q=0, rem=0 — the EVM semantics under test) plus
1/1, x/1, x/x, max/3, random/random.

## N=256 status

- `gen_divevm.py 256` emitted: NG = **1537** (770 div + 255 tree + 512 gate),
  TB_CYC = 135749. All four tops + tbs generated (`divevm256*.v`).
- Functional smoke **8/8 PASS** (`smoke_divevm256.out`): `1/1`; all three
  required zero-divisor cases `1/0`, `0/0`, and random `/0`; random `/1`;
  `x/x`; `max/3`; and random/random. The three zero-divisor results recombine
  to `q=0, rem=0`, directly exercising EVM semantics at full width.
- **MATCHI matrix (2026-07-16 evening): controls CLOSED, opini rerun in flight.**
  The gated driver ran all four tops. Controls match expectations exactly:
  `divevm256_pini` EXIT=1, `divevm256_rndreuse` EXIT=1, `divevm256_recomb`
  EXIT=1 (see `matrix_divevm256_{pini,rndreuse,recomb}.out`). The opini target
  run was **SIGKILLed by an unidentified external actor at cycle
  111578/135756** (EXIT=137, 21:58 CEST) — NOT an OOM (108G available, no
  kernel OOM logged), NOT a script timeout (no kill/timeout logic in any
  runner), NOT a matchi crash (no panic/segfault in dmesg or the log; log
  preserved at `work_divevm256/matchi.log.killed137_cycle111578`; partial DONE
  file at `DIVEVM256_MATRIX_DONE.partial_opini137`). **No violation reported in
  111578 cycles.** Rerun relaunched detached 21:59 CEST
  (`STAGE=matchi ./run_divevm.sh divevm256`, log
  `matrix_divevm256_opini_rerun.out`), verdict ETA ~05:30–06:30 CEST 2026-07-17.
- Original queue note (historical): a 1537-gadget/135k-cycle
  MATCHI run is projected ≳80GB RSS (div256 = 770 gadgets peaked ~41GB), and
  the swap256 staged driver owns the RAM queue. The already-running
  `run_divevm256_matrix_gated.sh` waits for `SWAP256_MATRIX_DONE`, then runs
  controls first and OPINI last, strictly sequentially with a
  MemAvailable>100GB gate. Manual equivalent:
  `for t in divevm256_pini divevm256_rndreuse; do ./run_divevm.sh $t; done; ./run_divevm.sh divevm256_recomb RECOMB; ./run_divevm.sh divevm256`
  (controls first, OPINI last; sequential).

## One-command reproduce (pilot)

```
python3 gen_divevm.py 16 && ./run_smoke_divevm.sh 16 && \
./run_divevm.sh divevm16; ./run_divevm.sh divevm16_pini; \
./run_divevm.sh divevm16_rndreuse; ./run_divevm.sh divevm16_recomb RECOMB
```
(exit codes 0 / 1 / 1 / 1)

**Verdict: divevm16 VERIFIED (OPINI PASS + both negative controls FAIL +
gadget boundary read). divevm256: generated and functional smoke 8/8 PASS;
MATCHI matrix queued behind the swap256 matrix, so no full-width security
verdict is claimed yet.**

## Latency invariance (digital side channel) — PASS, 2026-07-16

FIXED-ITERATION by construction: the public FSM (`running`/`it`/`ph`) always runs exactly N=256 iterations x K=528 cycles (div window [1,135168], outputs stable @~135173, clear @135184 — compile-time constants), regardless of A/B. The quotient/borrow decision is MASKED DATA consumed only by the borrow-mux AND-gadgets (R' = cout?T:Rsh realised as share-local XOR of gadget outputs), NEVER control. B==0 is handled by masked zero-gating (AND with the nonzero-tree bit), not a branch. Cycle count is invariant in amountIn/reserves.

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
