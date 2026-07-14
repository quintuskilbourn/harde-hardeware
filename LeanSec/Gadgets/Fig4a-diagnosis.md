# Workstream B — Fig-4a O-PINI composition leak: result & adjacency diagnosis

**Date:** 2026-07-13
**File:** `LeanSec/Gadgets/Fig4a.lean` (builds with `lake build LeanSec.Gadgets.Fig4a`)
**Axioms:** every theorem below has `#print axioms ⊆ {propext, Classical.choice, Quot.sound}`, no `sorry`, no `native_decide`.

## Verdict

The naive target — "a serial composition of two nonlinear masked gadgets in
which a PINI-but-not-O-PINI inner gadget (HPC2) leaks under `transitionGlitch`,
and swapping the inner gadget for an O-PINI one (OPINI2) makes it secure" — **does
not reproduce as a first-order probing leak on faithful two-share circuits**, and
the O-PINI output refresh is **not** the mechanism that would fix it. This is the
honest, kernel-checked diagnosis the task's fallback branch asks for, not a forced
anchor. It is fully consistent with STATUS.md §2–§3 (the box-proven `serialHPC2`
**secure** verdict and the retraction of the earlier artifact leak) and it locates
the PINI→O-PINI gap precisely.

## Kernel-proven anchors (all in `Fig4a.lean`)

| Anchor | Statement | Meaning |
|---|---|---|
| `faithful_and_transitionGlitch_secure` | `probingSecure DomAnd.gadget transitionGlitch 1` | A faithful nonlinear masked AND (functionally verified by `DomAnd.recombines`) is first-order **transition+glitch probing SECURE**. No transition leak on a faithful nonlinear gadget. |
| `Raw.recombines` | `recombinesTo Raw.gadget (·.getD 0 false)` | The share-multiplexer is a real gadget: its wire recombines to the secret. |
| `Raw.leak_trace` | wire observations = `[[x0, x1]]` | Anti-artifact guard: the one physical mux wire provably carries the two shares in order. |
| `Raw.leak_not_probing` | `¬ probingSecureFast Raw.gadget transitionGlitch 1` | The Fig-2a linear share-multiplex **leaks** under transition+glitch. |
| `Raw.leak_glitch_probing` | `probingSecureFast Raw.gadget glitch 1` | Glitch-only control: **secure** — the leak is transition-specific. |
| `Refreshed.recombines` | `recombinesTo Refreshed.gadget (·.getD 0 false)` | The refreshed multiplexer is still a real gadget. |
| `Refreshed.refreshed_multiplex_still_leaks` | `¬ probingSecureFast Refreshed.gadget transitionGlitch 1` | **The O-PINI output refresh does NOT fix the leak.** A fresh held zero-sharing refresh XORed onto the sharing before the multiplex still leaks — the refresh preserves the parity `x0 ⊕ x1 = x`. |
| `Refreshed.refreshed_glitch_probing` | `probingSecureFast Refreshed.gadget glitch 1` | Refreshed variant still glitch-secure (leak stays transition-specific). |

Cross-referenced, already-kernel-proven in the default build (the genuine
separation, non-vacuous under `HPC2.recombines`):

- `HPC2.glitch_pini_one` — HPC2 is first-order glitch **PINI**.
- `HPC2.not_glitch_opini_one` — HPC2 is first-order glitch **not O-PINI**.

## Why the leak does not reproduce — the register-barrier obstruction

The Fig-2a transition leak (`Raw.*` above, and `TransitionLeak.lean`) works only
because the two multiplexed values are **input shares**:

1. An input share is a *stable source*; its glitch frontier is the source node
   itself. So a glitch-only probe of the mux wire sees just the one live share.
2. `inputArrival` makes each share live at exactly one cycle (the other mux data
   input is 0 that cycle), so a *transition* probe — which unions the glitch
   frontiers at cycle `c` and `c-1` — spans both cycles and recovers both shares.

Neither property survives for the two **output shares of a nonlinear gadget**:

- Output shares are *computed*, not sources. Their combinational cone reaches the
  internal partial products, so a probe on an un-registered output-share wire is
  **glitch-insecure outright** (verified: the interface-mux experiment leaks under
  plain `glitch`, not transition-specifically). To be glitch-robust the gadget
  **must register** its output shares (DOM-AND / HPC2 / OPINI2 all do).
- That register is a *glitch barrier* AND it holds the value stable across cycles.
  Time-multiplexing two stable registered shares onto one wire therefore needs a
  hold/feedback mux, and that hold register **barriers the transition adjacency**
  the leak requires (the KNOWN TRAP, STATUS.md §3).

So on faithful nonlinear output shares the transition leak and the glitch barrier
are **mutually exclusive**: the configuration that would leak under transition is
already insecure under glitch (hence not a *transition* leak), and the configuration
that is glitch-secure barriers the transition. This is exactly why the faithful
`serialHPC2` was proven **secure** (STATUS.md §2), not leaky.

## Why the O-PINI output refresh is not the fix (parity invariance)

The only first-order transition leak available is the share-multiplex, and its
leaking quantity is the **parity** `x0 ⊕ x1 = x` of the multiplexed sharing. The
O-PINI output refresh (`OPINI2` = `HPC2` + a fresh zero-sharing `(t, t)` XORed onto
the output, the sole structural difference between the two in this codebase) adds
`t` to each share and hence **preserves that parity**. `refreshed_multiplex_still_leaks`
proves the refreshed multiplexer leaks identically to the raw one. Any
refresh-*sensitive* leak would have to expose an *individual* output share
correlated with an input share; but in a faithful masked gadget every individual
output share is masked by the gadget's own randomness, so no such first-order
probing leak exists (Part A). Hence output refresh cannot be the operational
witness of the PINI→O-PINI gap at first order.

## Where the gap genuinely lives

O-PINI is strictly stronger than PINI — but as a **simulatability** property, not a
first-order probing property. The separation is the already-kernel-checked pair
`HPC2.glitch_pini_one` (PINI ✓) / `HPC2.not_glitch_opini_one` (O-PINI ✗): there is
a probe set whose observations are PINI-simulatable from input shares yet cannot be
*jointly* simulated together with the corresponding output shares. That joint-output
obligation is what composition needs and what PINI fails to provide; its absence is
invisible to a first-order `transitionGlitch` probing check on a single two-share
gadget, which is why the operational leak the paper motivates surfaces only through
the simulatability separation (or at higher order / in the general composition
theorem), not through a faithful first-order two-share leak/fix circuit.

## Status

DONE (diagnosis branch). The Fig-4a adjacency is now rigorously characterized and
kernel-checked: (A) faithful nonlinear gadget is transition-secure, (B) the only
first-order transition leak is the refresh-invariant linear share-multiplex, (C) the
genuine separation is the already-proven O-PINI ≠ PINI simulatability gap. No false
anchor was forced.
