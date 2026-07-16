# Masked KECCAK-f[1600] round unit — MATCHI L2 composition result (transition model)

**Date:** 2026-07-15
**Verdict: PASS — masked Keccak-f[1600] (full 24-round permutation via one masked
round unit) transition-verified via L1 (SILVER-per-gadget, unchanged leaf) +
L2 (MATCHI-netlist).**

`keccakf1600` is a **dedicated masked round unit** — chi = `a XOR (NOT b AND c)` with
the NOT/XOR strictly share-local and the AND as one O-PINI2 gadget per state bit
(**1600 gadget instances `u_chi_*`**, each with a dedicated `r[k]`/`s[k]` random bit);
theta/rho/pi/iota are pure share-local XOR/rotation/wiring — **iterated in place by a
public FSM over all 24 rounds** (period K=6, ~145 cycles total). It composes securely
in the **glitch+transition** model (MATCHI default; `--no-check-transitions` NOT
passed). This is the EVM KECCAK256 permutation core.

## Architecture

- State `A[x][y][z]`: 25 lanes × 64 bits, two shares, flat index `64*(5y+x)+z` (spec
  ordering), dense sharing on ports.
- Per round: theta (`C/D` XOR network, share-local), rho+pi (wiring), chi
  (`A' = B ^ (~B_{x+1} & B_{x+2})`: complement share 0 only; gadget AND; share-local
  outer XOR), iota (public RC into share 0 of lane (0,0); constants from a chained
  ternary — NOT a `case`, which yosys turns into a `$memrd_v2` cell MATCHI rejects).
- Rho offsets and round constants are DERIVED FROM SPEC in the generator (the
  `(t+1)(t+2)/2` walk; the degree-8 LFSR) and asserted against published values
  (`RC[1]=0x8082`, `RC[23]=0x8000000080008008`, rho `r[2][2]=43`, …).
- **The 1600 gadgets are REUSED bubble-free across all 24 rounds with genuine
  feedback** (theta mixes every gadget's previous output into every gadget's next
  input) — the OPINI regime.
- Gadget latency contract: `ina` = 1-cycle per-share balance register of `~B_{x+1}`
  (iszero256 pattern); `inb` = `B_{x+2}` combinational from the stable round register.

## Verdict matrix

| # | Top module | leaf `matchi_prop` | Expected | MATCHI | exit |
|---|---|---|---|---|---|
| 1 | `keccakf1600` | OPINI | PASS | `Verification successful.` | 0 |
| 2 | `keccakf1600_pini` (label control) | PINI | **FAIL** (transition rule, LIVE) | `Transition leakage failure: … depends on a previous execution of this gadget, there was no pipeline bubble since then.` | 1 |
| 3 | `keccakf1600_rndreuse` (neg. control) | OPINI | **FAIL** (randomness reuse) | `Error: Random input r[0] … multiple places: u_chi_0 / u_chi_1` | 1 |
| 4 | `keccakf1600_recomb` (neg. control) | OPINI | **FAIL** (share recombination) | `Error: … sensitive in multiple shares (glitch leakage)` | 1 |

**Row 2 is live non-vacuity for the OPINI-vs-PINI distinction** (unlike the
adder/iszero/mul label controls, which pass): relabelling the identical netlist's leaf
OPINI→PINI makes MATCHI reject the bubble-free cross-round gadget reuse with the
transition-leakage error. The stronger O-PINI2 property is *required* for this unit,
and MATCHI demonstrably enforces the distinction on this exact netlist.

## Activity-window finding (honest record)

The first w=64 attempt used the mul/div-style **time-bounded** windows (share-local
`clr` of the state register + short drain tail). That annotation **PASSES at w=4/8 but
FAILS at w=16/64** with `Output share o[..] is not at a valid latency, but it is
(glitch-)sensitive`: MATCHI does not drain the sensitivity of this persistent-state
structure after the clear at larger widths (the w≤8 drain is an abc cone-factoring
accident, confirmed by bisection w=4/8/16/64 with identical generator schedule; the
`clr` pulse fires value-wise in every VCD). Since a hash state is legitimately
persistent-sensitive, the deliverable annotation is the conservative one: **the
activity windows never close inside the trace** — the tb re-randomizes `r`/`s` every
cycle and `$finish`es while all windows are open, so every cycle of the trace is
annotated sensitive-and-fresh. `KECCAK_BOUNDED_WINDOWS=1` regenerates the bounded
variant to reproduce the finding.

## MATCHI demonstrably read the gadget boundary (not flattened)

- **Synth JSON**: exactly **1600** leaf cells preserved (attributes intact) in each of
  the four netlists.
- **MATCHI log**: the OPINI run names **all 1600 distinct instances** `u_chi_0 …
  u_chi_1599` by hierarchical path.

## Functional smoke (separate from the security check)

`tb_smoke_keccakf1600.v`: shares the 1600-bit state with a random mask, pulses `go`,
waits out the 24 rounds, recombines, compares against the generator-embedded spec
reference. **4/4 PASS**, including the all-zero state whose output recombines to the
published XKCP vector — lane(0,0) = `f1258f7940e1dde7` — an anchor external to this
codebase. The reference itself is assert-anchored on XKCP values inside the generator.

## Pilot ladder

w=4 (f[100], 16 rounds, 100 gadgets): full matrix 4/4 under bounded windows.
w=8 (f[200]) OPINI PASS bounded; w=16 (f[400]): bounded FAILS (the finding above),
full matrix **4/4 under open windows** — then w=64 (this result).

## Reproduce (one command each, on the box)

```bash
cd .
python3 gen_keccakf.py                        # (re)emit the 4 tops (w=64, 1600 gadgets)
./run_smoke_keccakf.sh                         # functional: SMOKE: ALL PASS (XKCP anchor)
./run_keccakf.sh keccakf1600                   # row 1 -> exit 0 PASS
./run_keccakf.sh keccakf1600_pini              # row 2 -> exit 1 FAIL (transition rule)
./run_keccakf.sh keccakf1600_rndreuse          # row 3 -> exit 1 FAIL (multiple places)
./run_keccakf.sh keccakf1600_recomb RECOMB     # row 4 -> exit 1 FAIL (multiple shares)
```

## Files

| File | Role |
|---|---|
| `keccakf1600.v` | masked Keccak-f[1600] (1600 OPINI leaves) — **verified target** |
| `keccakf1600_pini.v` / `_rndreuse.v` / `_recomb.v` | control tops (rows 2–4) |
| `gen_keccakf.py` | generator (usage: `gen_keccakf.py [w]`; spec-derived tables) |
| `tb_keccakf1600.v` | MATCHI testbench (open windows; 196 cycles) |
| `tb_smoke_keccakf1600.v` / `run_smoke_keccakf.sh` | functional smoke |
| `run_keccakf.sh` | matrix runner (mirror of the validated flow) |
| `matrix_keccakf1600_*.out`, `work_keccakf1600*/matchi.log` | verdicts / logs |

Read-only reference (NOT modified): `./MSKand_opini2_d2.v`,
`./MSKand_opini2_d2_pini.v`, and all verified adder/ISZERO artifacts.

## Latency invariance (digital side channel) — PASS, 2026-07-16

FIXED SCHEDULE: 24 rounds always, sequenced by the public round counter; the round-constant lookup is a ROM ternary chain indexed by `rnd_i` (public). No data-dependent control anywhere in the permutation.

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
