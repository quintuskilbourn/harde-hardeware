# RESULT — swap256: constant-product swap demonstrator (DRAFT — opini TOOL CRASH, rerun in flight)

**Status: NOT FINAL.** All three negative controls FAILed with the exact
expected signatures (matrix below), but the OPINI target run did **not**
produce a verdict: MATCHI itself crashed (Rust panic, then SIGSEGV) at
simulation cycle 35932/138312 with **no violation reported up to that point**.
This is a TOOL CRASH, not a security verdict — it is recorded honestly and is
being root-caused. DO NOT cite swap256 as verified.

Target property: first-order GLITCH+TRANSITION-robust d=1 probing security,
MATCHI L2, default transition model. Gadget-of-record: byte-identical O-PINI2
leaf `MSKand_opini2_d2.v` (matchi_strat="assumed"). Generator:
`gen_swap256.py 256` (N=16 pilot fully verified incl. opini PASS, see
SWAP_DATAPATH.md).

## MATCHI matrix (staged driver `run_swap256_matrix_staged.sh`, closed 2026-07-16 15:38)

| Top | Expectation | Verdict | Cause |
|---|---|---|---|
| `swap256` (O-PINI2 labels) | PASS | **NO VERDICT — TOOL CRASH** (EXIT=139 at cycle 35932/138312, 2026-07-16 15:38) | matchi panic `recsim.rs:181: Gate(GateState{...}) is not a module state`, then SIGSEGV (dmesg: write fault at 0x60 in matchi). No leakage finding before the crash. See "opini crash investigation" below. |
| `swap256_pini` (label control) | FAIL | **FAIL** (EXIT=1, done 07:55) | LIVE transition leakage at `u_dt_256`: "Input inb[0] ... depends on a previous execution of this gadget, there was no pipeline bubble since then" — the embedded bubble-free divider reuse; exact swap16-pilot signature (`u_dt_16`) |
| `swap256_rndreuse` | FAIL | **FAIL** (EXIT=1, done 08:31) | "Random input r[2300] at cycle 2582 is used in multiple places" — fresh in u_dm_0@2582, reused in u_dm_0/u_dm_1@2583 (the planted reuse) |
| `swap256_recomb` | FAIL | **FAIL** (EXIT=1, done 09:13→15:38 window) | "Gate has input sensitive in multiple shares (causes glitch leakage): Input 0 shares ShareSet{0}, Input 1 shares ShareSet{1}" — the planted leak0 <= aout[0]^aout[1] recombination |

## opini crash investigation (2026-07-16, this iteration)

- Crash artifacts: `SWAP256_MATRIX_DONE` (EXIT=139), tail of
  `work_swap256/matchi.log` (panic message incl. the offending GateState),
  dmesg segfault line. matchi.log is 14GB (dominated by per-cycle
  "output port ... not sensitive" warnings) — do not commit; keep the tail.
- The panicking `GateState` has inputs sensitive on ShareSet{0} and
  ShareSet{1} — legitimate only *inside* the assumed MSKand leaf (e.g. the
  HPC2 cross-domain gate `w0 = ina[0] & v0`), so the corrupted slot is inside
  a PipelineGadgetEvaluator's internal module state.
- Static audit of matchi @ upstream main 9bab4ed (our binary of record; clean
  checkout, no local diffs): every instance_states access is index-consistent;
  no `unsafe` in matchi src. The (ModuleEvaluator, GateState) pairing is
  impossible by construction — suspicion is either a deeper tool bug or
  **memory corruption** (box also logged an unrelated ld-linux segfault at
  03:16 and a 128GB OOM kill at 01:14 the same day; the crashed run had been
  at 11GB+ RSS for 6.3h).
- Upstream `origin/v2` has one extra commit "Fix recursive pipeline gadget
  bug" — **does not apply to us**: our netlist has exactly two annotated
  modules (top `swap256` composite_top + assumed leaf), no gadget-in-gadget
  nesting.
- **Discriminating rerun IN FLIGHT** (launched 2026-07-16 ~16:20): same
  source rebuilt with debug symbols (`target-dbg`, CARGO_PROFILE_RELEASE_DEBUG=true),
  run under gdb with `break rust_panic` + RUST_BACKTRACE=full on the
  byte-identical JSON+VCD. Sanity: instrumented binary reproduces dexloop16
  opini PASS and dexloop16_pini FAIL (same `u_dg_15` signature).
  Logs: `swap256_opini_rerun_gdb.log` (backtraces), `swap256_opini_rerun_dbg.log`
  (matchi output). ETA to crash cycle ≈ 6.5h (~23:00), full pass ≈ 24h.
  - Deterministic crash at the same cycle ⇒ matchi logic bug: fix from the
    backtrace (upstream-style), re-validate on dexloop16/swap16 matrices, rerun.
  - Pass or crash at a different cycle ⇒ memory corruption: rerun opini on
    the binary of record, consider memtester; treat box RAM as suspect.
- Rerun timeline (iter 22): the first gdb rerun (16:11) was launched under
  the iteration's own shell and died at the 16:19 iteration boundary before
  simulating a single cycle (logs frozen at "Starting simu"). Re-launched
  16:21 fully detached via the committed `rerun_swap256_opini_gdb.sh`
  (setsid; marker `SWAP256_OPINI_RERUN_DONE`). ETA crash cycle ≈ 23:00.
- Independent RAM canary (iter 22): `memtester 16G 1` pass, result in
  `memtester_16g_pass1.log`. **Closed CLEAN 17:21 iter 41** (all tests, 0
  errors) — RAM exonerated at one-pass strength.
- **Cross-run data point (iter 44, 2026-07-16 17:58): divevm256 opini (same
  binary of record, 1537-gadget design, 28GB VCD) crossed cycle 35932 and
  passed cycle 37054 with ZERO panics/violations** — watched live minute-by-
  minute. So the crash is NOT a generic cycle-indexed matchi bug; it is
  specific to the swap256 run (design size ~3578 gadgets / program content /
  66GB VCD / 11GB+ RSS). Combined with the clean memtester pass, the leading
  hypothesis is a size- or content-triggered deterministic matchi bug; the
  gdb backtrace (rerun ETA ~00:35 Jul 17) remains the discriminator.

## Non-vacuity (already verified, 2026-07-16 iter 9)

- **3578 / 3578 / 3578 / 3578** `MSKand_opini2_d2*` gadget cells preserved in
  all four post-synth JSONs (`work_swap256*/swap256*_synth.json`) — no
  flattening.
- Instance-naming check (all 3578 `u_*` names in the matchi log) still
  pending — must come from a *completed* opini run.
- Functional smoke: **6/6 PASS** (`smoke_swap256.out`), including the
  slippage-trip vector (ok=0) and full-width wrap vectors; reference is
  256-bit wrap arithmetic (EVM semantics).
- Trace: 138.3k cycles (covers the deepest r window plus margin; windows
  never close inside the trace). VCDs 66GB × 4 (regenerable, not committed).

## To finish

1. Resolve the opini crash per the investigation above; obtain a real
   PASS/FAIL verdict on `swap256`.
2. `grep -oE '"u_[a-z]+_[0-9]+"' <opini matchi log> | sort -u | wc -l` → 3578.
3. Remove the DRAFT banner, update SWAP_DATAPATH.md N=256 row, commit.
4. If the crash proves unresolvable at trace scale: record that honestly —
   evidence then rests on the swap16 pilot full matrix + per-unit 256-bit
   verification (mul256/div256/add256/eq256) + the dexloop16 composition
   pilot; write ESCALATE.md per the mission protocol.

Reproduce: `python3 gen_swap256.py 256 && ./run_swap256_matrix_staged.sh`
(or `STAGE=... ./run_swap256.sh <top>` per stage).

## Latency invariance (digital side channel) — PASS, 2026-07-16

WHOLE-SWAP LATENCY IS A COMPILE-TIME CONSTANT: one global cycle counter sequences every stage; all stage strobes are `cnt == <const>` (denom captured @524, mul window [1,2048] captured @2572, div go @2576, Q/R stable @137745, then cmp/gating on fixed offsets). The embedded div runs all 256 iterations (fixed 528-cycle iteration); the embedded mul runs all 256 PP iterations. The swap cycle count does NOT depend on amountIn/reserves — the digital side-channel requirement for the DEX.

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

## 2026-07-16 22:xx — gdb backtrace rerun KILLED externally; monolith MATCHI retired per orchestrator redirect

The gdb rerun (relaunched 16:21, breakpoint armed on `rust_panic`) was SIGKILLed
at **21:58:54 CEST (wrapper exit 137)** at ~cycle 30069/138312 — **before** the
crash cycle 35932; **no backtrace was obtained** (log shows only the armed
breakpoint). The divevm256 opini run was SIGKILLed the same minute (also 137,
also no tool fault) — consistent with external enforcement of the 2026-07-16
orchestrator redirect ("STOP re-running whole-swap MATCHI"), not with a machine
fault (108G RAM free, no kernel log entries, no OOM).

**Disposition per redirect:** whole-netlist MATCHI on swap256 is RETIRED (scale
wall). The whole-swap security claim moves to **composition via the R1 theorem**
over the individually verified primitives — see `ESCALATE_SWAP.md`. The marker
`SWAP256_OPINI_RERUN_DONE` exists but records a kill, NOT a verdict; the opini
cell of the matrix stays TOOL-CRASH/UNRESOLVED at whole-netlist granularity.
If partial whole-netlist confidence is requested, per-stage partition tops
(mul / div / cmp+gating) can be emitted — never the monolith.
