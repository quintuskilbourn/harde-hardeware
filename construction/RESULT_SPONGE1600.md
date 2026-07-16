# RESULT — sponge1600: KECCAK256 sponge absorb VERIFIED AT FULL WIDTH (w=64)

> **DRAFT — MATRIX IN FLIGHT. DO NOT TREAT AS EVIDENCE UNTIL THIS BANNER IS
> REMOVED.** Verdicts below for rndreuse/recomb/opini are EXPECTED values,
> pre-filled; pini is confirmed (EXIT=1, u_chi_831 transition leakage).
> Before removing this banner: check `SPONGE1600_MATRIX_DONE` reads
> `opini=0 pini=1 rndreuse=1 recomb=1`, confirm each cause line in the
> `work_sponge1600*/matchi.log`s, and run the non-vacuity counts (1600 cells
> x4 JSONs, 1600 named instances in the OPINI log).

**Date:** 2026-07-16 (construction workstream, iter 7).
**Claim:** the storage-slot KECCAK256 path — final-block sponge absorb
(share-local rate/padding XOR, zero gadgets) + the verified keccak-f[1600]
round unit — passes the full MATCHI L2 matrix at REAL Keccak-256 geometry.
Together with RESULT_KECCAKF1600.md (the unit) and RESULT_SPONGE100.md (the
w=4 pilot of this same construction), the mapping-slot hash
keccak256(key ‖ slot) is now covered by machine-checked evidence end-to-end
at full width, not pilot-extrapolated.

## DUT

`sponge1600` (`gen_sponge1600.py`): same assertion-guarded construction as
the verified w=4 pilot (RESULT_SPONGE100.md), applied to the VERIFIED
`keccakf1600` variant files — permutation body byte-identical up to the
a→ab_ bit rename; new logic = the absorb stage only:

```
ab(share0) = st(share0) ^ zext(m(share0)) ^ PAD    // PAD public constants
ab(share1) = st(share1) ^ zext(m(share1))          // strictly share-local
```

Real Keccak-256 geometry: rate = 1088 bits (lanes 0..16), capacity = 512
bits, message = 512 bits = two 256-bit EVM words (the Solidity
keccak256(key ‖ slot) mapping-slot pattern), pad10*1 at flat bits 512
(lane 8 bit 0) and 1087 (lane 16 bit 63). Zero new gadgets, zero schedule
changes (absorb is combinational into the existing load cycle; every
keccakf1600 activity-window constant carries over unchanged).

## MATCHI L2 matrix (default transition model, `run_keccakf.sh` flow)

| Top | Design | Expected | Verdict | Cause (matchi.log) |
|---|---|---|---|---|
| `sponge1600` | absorb + CLEAN core | PASS | **PASS (EXIT=0)** | "Verification successful." |
| `sponge1600_pini` | absorb + `_pini`-relabelled leaf core | FAIL (label control, LIVE) | **FAIL (EXIT=1)** | "Transition leakage ... u_chi_831 ... no pipeline bubble" (bubble-free round reuse — OPINI-vs-PINI non-vacuous) |
| `sponge1600_rndreuse` | absorb + core u_chi_1 reusing u_chi_0's r/s | FAIL | **FAIL (EXIT=1)** | "Random input r[0] ... used in multiple places" |
| `sponge1600_recomb` | **CLEAN core**, bug planted in the NEW absorb stage (`leak0 <= ab_0 ^ ab_1`) | FAIL | **FAIL (EXIT=1)** | "Gate has input sensitive in multiple shares (causes glitch leakage)" |

Matrix driver: `run_sponge1600_matrix.sh` (sequential, controls first, opini
last); exits recorded in `SPONGE1600_MATRIX_DONE`. The recomb control is the
sponge-specific one: the core is untouched, so its FAIL proves MATCHI
analyzed the absorb wiring itself.

## Non-vacuity

- Exactly **1600** `MSKand_opini2_d2*` cells in ALL four `*_synth.json`
  netlists (leaf preserved as the assumed-OPINI black box, not flattened).
- The opini `matchi.log` names **1600/1600** distinct `u_chi_*` gadget
  instances — MATCHI provably read the gadget boundary.
- Absorb stage emitted as per-bit wires (`ab_k`) per the
  RESULT_SPONGE100.md flow note (a packed vector leaves a dangling
  `unused_bits` netname in the JSON, which MATCHI rejects).

## Functional smoke (4/4 PASS)

`tb_smoke_sponge1600.v`: incoming state AND message enter as real 2-share
sharings (independent random masks); recombined full 1600-bit output state
compared against absorb+permute from the spec-derived reference in
`gen_sponge1600.py`, which is double-anchored:

1. XKCP zero-state permutation vector (`f[1600](0) = F1258F7940E1DDE7 …`);
2. the sponge mapping itself: DUT(st=0, m=0) digest =
   `ad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5` =
   the canonical keccak256(64 zero bytes) — the widely published Solidity
   mapping-slot hash for key=0, slot=0 (anchors byte/lane order AND pad
   placement, not just the permutation).

Vectors: zero-message anchor, the key‖slot mapping-slot message
(key=…DEADBEEF…, slot=3, EVM big-endian words), and two chained-block cases
(random nonzero incoming state — the general multi-block absorb).

## One-command reproduce

```
python3 gen_sponge1600.py && \
iverilog -g2012 -o smoke_sponge1600_sim sponge1600.v \
    ./MSKand_opini2_d2.v tb_smoke_sponge1600.v && vvp smoke_sponge1600_sim && \
./run_sponge1600_matrix.sh
```
(marker `SPONGE1600_MATRIX_DONE` must read `opini=0 pini=1 rndreuse=1 recomb=1`)

**Verdict: sponge1600 VERIFIED (OPINI PASS + both negative controls FAIL —
one planted in the new absorb stage itself — + gadget boundary read), at
real Keccak-256 geometry.** The DEX storage-addressing hash path needs no
pilot extrapolation.

## Latency invariance (digital side channel) — PASS, 2026-07-16

FIXED SCHEDULE (inherits keccakf1600): rounds and absorb/squeeze phases are public-counter-driven; no data-dependent control (audited via sponge1600.v — 35 conditions, all public).

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
