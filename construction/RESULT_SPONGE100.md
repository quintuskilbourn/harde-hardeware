# RESULT — sponge100: KECCAK256 sponge absorb, MATCHI-verified pilot (w=4)

**Date:** 2026-07-16 (construction workstream, iter 7).
**Claim upgraded:** the SWAP_DATAPATH.md composition note "sponge padding /
rate XOR: share-local XOR of the masked message block into the masked state —
no gadgets" was previously *argued* + smoke-demonstrated at f[1600]
(`gen_keccak256_smoke.py`, 3/3 PASS). It is now **machine-checked by a full
MATCHI L2 matrix** at the w=4 pilot scale (keccak-f[100]), the same pilot
pattern as swap16 / divevm16.

## DUT

`sponge100` (`gen_sponge100.py`): final-block sponge absorb + one f[100]
permutation, ONE flat module produced by minimal, assertion-guarded textual
surgery on the VERIFIED `keccakf100` variant files (RESULT_KECCAKF1600.md
§pilots) — the permutation body is byte-identical up to renaming the former
input `a[k]` to internal wires `ab_k`. New logic = the absorb stage only:

```
ab(share0) = st(share0) ^ zext(m(share0)) ^ PAD    // PAD = public constants
ab(share1) = st(share1) ^ zext(m(share1))          // strictly share-local
```

Keccak-256 analog at w=4: rate = 17 lanes = 68 bits, capacity = 8 lanes =
32 bits, message = 8 lanes = 32 bits (the keccak256(key ‖ slot) two-word
mapping-slot pattern scaled w=64→4), pad10*1 at flat bits 32 and 67 — the
same lane positions (lane 8 bit 0, lane 16 bit w−1) as the real f[1600]
sponge. Zero new gadgets; zero schedule changes (the absorb is combinational
into the existing load cycle, so every keccakf100 activity-window constant
carries over unchanged).

## MATCHI L2 matrix (default transition model, `run_keccakf.sh` flow)

| Top | Design | Expected | Verdict | Cause (matchi.log) |
|---|---|---|---|---|
| `sponge100` | absorb + CLEAN core | PASS | **PASS (EXIT=0)** | "Verification successful." |
| `sponge100_pini` | absorb + `_pini`-relabelled leaf core | FAIL (label control, LIVE) | **FAIL (EXIT=1)** | "Transition leakage ... u_chi_23 ... no pipeline bubble" (bubble-free round reuse — OPINI-vs-PINI non-vacuous) |
| `sponge100_rndreuse` | absorb + core u_chi_1 reusing u_chi_0's r/s | FAIL | **FAIL (EXIT=1)** | "Random input r[0] at cycle 6 is used in multiple places" |
| `sponge100_recomb` | **CLEAN core**, bug planted in the NEW absorb stage (`leak0 <= ab_0 ^ ab_1`, the two shares of absorbed bit 0) | FAIL | **FAIL (EXIT=1)** | "Gate has input sensitive in multiple shares (causes glitch leakage)" |

The recomb control is the sponge-specific one: the core is untouched, so the
FAIL proves MATCHI analyzes the absorb wiring itself (not just the verified
permutation), i.e. the PASS on `sponge100` is a statement about the sponge
composition.

## Non-vacuity

- Exactly **100** `MSKand_opini2_d2*` cells in ALL four `*_synth.json`
  netlists (leaf preserved as an assumed-OPINI black box, not flattened).
- The opini `matchi.log` names **100/100** distinct `u_chi_*` gadget
  instances — MATCHI provably read the gadget boundary.
- Flow note: the absorb stage must be emitted as per-bit wires (`ab_k`), not
  a packed `wire [199:0]` — yosys leaves a partially-aliased packed netname
  dangling in the JSON (`unused_bits`), which MATCHI's netlist builder
  rejects ("Could not find driver for wire a[0]"). Single-bit wires sweep
  cleanly (same as eq256's `d0_*`).

## Functional smoke (4/4 PASS)

`tb_smoke_sponge100.v`: incoming state AND message enter as real 2-share
sharings (independent random masks); pad constants injected into share 0
only; recombined 100-bit output compared against absorb+permute computed by
the spec-derived reference in `gen_sponge100.py`, which is anchored on the
VERIFIED keccakf100 unit's own zero-state smoke vector
(`f[100](0) = 10aae77d05820f26dabedc566`) and cross-checked against the RTL
`rc_cur` iota table. Vectors: first-block empty message (absorbed = PAD
only), first-block with message, and two chained-block cases (random nonzero
incoming state — the general second-block absorb the f[1600] smoke could not
exercise).

## One-command reproduce

```
python3 gen_sponge100.py && \
iverilog -g2012 -o smoke_sponge100_sim sponge100.v \
    ./MSKand_opini2_d2.v tb_smoke_sponge100.v && vvp smoke_sponge100_sim && \
./run_keccakf.sh sponge100_pini; ./run_keccakf.sh sponge100_rndreuse; \
./run_keccakf.sh sponge100_recomb RECOMB; ./run_keccakf.sh sponge100
```
(exit codes 1 / 1 / 1 / 0)

**Verdict: sponge100 VERIFIED (OPINI PASS + both negative controls FAIL —
one planted in the new absorb stage itself — + gadget boundary read).**
Together with RESULT_KECCAKF1600.md (the f[1600] unit) and
`gen_keccak256_smoke.py` (functional f[1600] sponge, canonical-vector
anchored), the storage-slot KECCAK256 path is covered end-to-end: unit
verified at full width, composition verified at pilot width, composition
functionally correct at full width.

## Latency invariance (digital side channel) — PASS, 2026-07-16

FIXED SCHEDULE (inherits keccakf): rounds and absorb/squeeze phases are public-counter-driven; no data-dependent control.

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
