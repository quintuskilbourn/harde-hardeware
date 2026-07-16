# Masked storage path (SLOAD/SSTORE scratchpad) — MATCHI L2 result (transition model)

**Date:** 2026-07-15
**Verdict: PASS — 8 × 256-bit in-domain two-share scratchpad with transition-safe
two-lane paging, MATCHI-verified in the glitch+transition model; both leakage
controls (shared-bus paging, share recombination) rejected as required.**

`store256x8` holds 8 words × 256 bits as two shares in **physically-separate lanes**
(`m0_*` / `m1_*` per-word explicit registers; separate read muxes; separate paging
registers). Addresses and enables are **public control** (the DEX contract's storage
slot numbers are public; only the 256-bit contents are secret). SLOAD/SSTORE are pure
data movement: **no gadgets, no randomness** — every gate in the unit touches exactly
one share of one value, so the entire security claim is carried by the L2 MATCHI run
plus the two failing controls (L1 is vacuous by construction).

## Interface / behavior

- **SSTORE**: `we`/`waddr` + `wdata` (dense sharing) — per-lane write decode.
- **SLOAD**: `raddr` → registered per-lane read port (`rreg0/rreg1` ← per-lane
  chained-ternary mux, every cycle). Read-port **transitions** (word X → word Y)
  happen strictly within one lane — at most masked-share transitions, which is
  exactly what the MATCHI default transition model admits.
- **Paging** (in-domain move, SLOAD→SSTORE without leaving the masked domain):
  `pg_go`/`pg_from`/`pg_to`; cycle 1 loads BOTH lane registers `pg0 ← mux0(src)`,
  `pg1 ← mux1(src)` at the SAME edge; cycle 2 writes both lanes back. **Paired shares
  move together through physically-separate lanes.**
- Explicit per-word registers, NOT a Verilog memory array — yosys infers `$memrd_v2`
  cells from arrays and MATCHI rejects those (hit live on the keccak iota ROM).
- Sensitivity is NOT time-bounded (storage persists by design): `a_act = we`,
  `out_act = we || seen_w` (high from the first write to trace end); the MATCHI tb
  `$finish`es while words are still sensitive. Same open-window rationale as
  KECCAK (`RESULT_KECCAKF1600.md` §Activity-window finding).

## Verdict matrix

| # | Top module | Expected | MATCHI | exit |
|---|---|---|---|---|
| 1 | `store256x8` | PASS | `Verification successful.` | 0 |
| 2 | `store256x8_sharedbus` (neg. control) | **FAIL** (transition share-recombination on the paging bus) | `Error: Checking wire "$0\bus[255:0]" … glitch-sensitive for multiple shares: ShareSet{0, 1}` | 1 |
| 3 | `store256x8_recomb` (neg. control) | **FAIL** (share recombination) | `Error: … Gate has input sensitive in multiple shares (glitch leakage)` | 1 |

**Row 2 is the load-bearing control and the whole point of the design rule.** The
control serializes the page move through ONE time-multiplexed bus register — share 0
of the word on one cycle, share 1 on the next (write-back over two more cycles;
functionally identical result). MATCHI rejects it, naming the bus register's input
cone (`$0\bus`) as sensitive in **both** shares — the transition/glitch combination
of the two shares of the same word on one physical node. The verified target differs
from this control ONLY by the two-lane paging pipeline: this is direct netlist-level
evidence that "paired shares move together through physically-separate lanes" is
load-bearing, not stylistic.

- Row 3 is the classic recombination control (`leak0 <= rdata[0]^rdata[1]`).
- The MATCHI tb exercises: 8 writes (fresh sharings), a page 7→0, a 48-cycle
  continuous read sweep across all words (in-lane read-port transitions), and an
  interleaved write/read tail — all accepted in the transition model.

## Functional smoke (separate from the security check)

`tb_smoke_store256x8.v`: writes 8 known 256-bit words as fresh random sharings, reads
each back recombined, pages 7→0 and re-checks all words (word 0 now holds word 7's
value, others intact), overwrites word 0 and re-checks. **ALL PASS.**

## Pilot

`store16x4` (16-bit × 4 words): identical 3/3 matrix (`work_store16x4*/`), validating
the flow (including MATCHI on a gadget-free, randomness-free module) before full size.

## Reproduce (one command each, on the box)

```bash
cd .
python3 gen_store256.py                        # (re)emit the 3 tops (256x8)
iverilog -g2012 -o smoke_store256x8_sim store256x8.v tb_smoke_store256x8.v && vvp smoke_store256x8_sim
./run_store.sh store256x8                      # row 1 -> exit 0 PASS
./run_store.sh store256x8_sharedbus            # row 2 -> exit 1 FAIL (multi-share bus)
./run_store.sh store256x8_recomb RECOMB        # row 3 -> exit 1 FAIL (multi-share gate)
```

## Files

| File | Role |
|---|---|
| `store256x8.v` | two-lane scratchpad + paging — **verified target** |
| `store256x8_sharedbus.v` / `store256x8_recomb.v` | control tops (rows 2–3) |
| `gen_store256.py` | generator (usage: `gen_store256.py [W] [D]`) |
| `tb_store256x8.v` / `tb_smoke_store256x8.v` | MATCHI / smoke testbenches |
| `run_store.sh` | matrix runner (same validated flow) |
| `work_store256x8*/matchi.log`, `work_store16x4*/` | run logs / pilot evidence |

## Latency invariance (digital side channel) — PASS, 2026-07-16

ADDRESS-INDEPENDENT access: SLOAD is a registered full-fan-in ternary mux — EVERY word of both share lanes feeds the read mux every cycle regardless of raddr (a constant-time masked-select over a full linear scan; DEX state is far below the ORAM crossover), fixed 1-cycle read latency. Addresses/enables are matchi control-typed PUBLIC inputs (EVM slot numbers of the DEX are program constants, never derived from masked data — corroborated in the dexloop tops where all addresses come from the public prefix counter and constant slots 0/1). Paging moves paired shares on a fixed public schedule.

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
