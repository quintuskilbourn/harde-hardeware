# Oracle results

> **Intermediate discrepancy (preserved, not hidden):** the first O-PINI2 transcription
> incorrectly collapsed the two physical instances `Reg[s0]` and `Reg[s1]` into one
> register (although `s1 = s0`) and pointed feedback at pre-output nodes. SILVER reported
> `probing.transitional (d ≤ 1) -- FAIL` in cycle 3. That circuit was not Algorithm 3:
> separate registers are physically separately probeable. The literal Algorithm 3 circuit
> below uses two registers driven by the same fresh bit and passes. The exact intermediate
> command and output are recorded under "Intermediate failed transcription".

There is **no discrepancy in the final oracle circuits**. All requested expectations match:

| Circuit | `probing.robust` | `probing.transitional` | Paper expectation |
|---|---:|---:|---:|
| Single HPC2 | PASS | PASS | PASS control |
| Iterated HPC2 | PASS | **FAIL, cycle 2** | FAIL, cycle 2 |
| Iterated O-PINI2 | PASS | PASS | PASS |

SILVER writes `d ≤ 1` because these circuits have two shares: the verifier's `d` is
the probing/security order (`shares - 1`), whereas the mission's "d=2 shares" names the
share count.

## Sources and encoding

- Tool: `<SILVER-transition-checkout>/bin/verify`, transitional-leakage branch at
  commit `1c664a7f481ad378f7dc14011d19528645d5fab9`.
- Published paper: N. Mueller, D. Knichel, P. Sasdrich, A. Moradi, *Transitional Leakage
  in Theory and Practice*, TCHES 2022(2), pp. 266-288,
  <https://tches.iacr.org/index.php/TCHES/article/download/9488/9036>.
- The downloaded paper is `2022-023.pdf`, SHA-256
  `79efc06990f9b09ec4f60785822cbfb77b53de042f240b3e08ac62055893b32b`.
- Table 2 gives first-order achieved orders 0 for iterated HPC2 and 1 for iterated
  O-PINI2. The text immediately below Table 2 says the HPC2 leakage is detected in the
  second clock cycle.
- The first 30 functional nodes are the authors' first-order HPC2 graph from
  `~/sec-tools/SILVER/test/hpc/hpc2_1.nl` (comments and signal names clarified).
- In the iterated companions, `x[0:1]` transitions to the actual output wires at the
  feedback cycle; `y[0:1]` stays static. `r_next` (and `s_next` for O-PINI2) models a
  distinct fresh mask after cycle 1. Cycle 1 deliberately has no prior primary-input
  transition, matching Algorithm 1's `l > 0` condition.
- O-PINI2 literally appends `s0` fresh, `s1 = s0`, two distinct physical `Reg[s_i]`,
  and `c_i = Reg[d_i xor Reg[s_i]]`. Its feedback latency is three cycles.
- The single-execution control has no feedback and no changing primary inputs, but its
  two empty cycle entries retain SILVER's ordinary register transition-extension. Its
  transitional PASS is therefore a genuine single-execution check, not a robust-only
  alias.

## Final verification commands and exact verdict output

All checks cap SILVER at eight cores as required. ANSI color was removed by the shown
pipeline; all other quoted text is exact pipeline output.

### Single-execution HPC2 control

```sh
timeout 60s env LD_LIBRARY_PATH=<SILVER-transition-checkout>/lib <SILVER-transition-checkout>/bin/verify --cores 8 --verbose 1 --insfile hpc2_single.nl 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'probing\.(robust|transitional)|In Cycle|dumped core'
```

```text
[     0.001] probing.robust   (d ≤ 1) -- PASS.	>> Probes: <in:line2,in:line1>
[     0.001] probing.transitional   (d ≤ 1) -- PASS.	>> Probes: <in:line2,in:line1>
timeout: the monitored command dumped core
```

### Iterated, serially reused HPC2

```sh
timeout 60s env LD_LIBRARY_PATH=<SILVER-transition-checkout>/lib <SILVER-transition-checkout>/bin/verify --cores 8 --verbose 1 --insfile hpc2_iterated.nl 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'probing\.(robust|transitional)|In Cycle|dumped core'
```

```text
[     0.001] probing.robust   (d ≤ 1) -- PASS.	>> Probes: <in:line2,in:line1>
[     0.001] probing.transitional   (d ≤ 1) -- FAIL.	>> Probes: <reg:line15>
(In Cycle: 2)
timeout: the monitored command dumped core
```

### Iterated O-PINI2

```sh
timeout 60s env LD_LIBRARY_PATH=<SILVER-transition-checkout>/lib <SILVER-transition-checkout>/bin/verify --cores 8 --verbose 1 --insfile opini2_iterated.nl 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'probing\.(robust|transitional)|In Cycle|dumped core'
```

```text
[     0.001] probing.robust   (d ≤ 1) -- PASS.	>> Probes: <in:line2,in:line1>
[     0.002] probing.transitional   (d ≤ 1) -- PASS.	>> Probes: <in:line2,in:line1>
timeout: the monitored command dumped core
```

The verifier emits all probing, NI, SNI, and PINI verdicts and then crashes in its final
uniformity phase. This is a post-verdict defect in this supplied binary; it occurs for all
three tiny circuits and does not change the already-emitted probing verdicts. The timeout
message is retained rather than suppressed.

## Intermediate failed transcription

Before separating the two `Reg[s_i]` instances and mapping feedback to output wires, the
following command was run:

```sh
timeout 60s env LD_LIBRARY_PATH=<SILVER-transition-checkout>/lib <SILVER-transition-checkout>/bin/verify --cores 8 --verbose 1 --insfile opini2_iterated.nl
```

Its relevant output is reproduced below with ANSI color codes elided:

```text
[     0.001] probing.robust   (d ≤ 1) -- PASS.	>> Probes: <in:line2,in:line1>
[     0.001] probing.transitional   (d ≤ 1) -- FAIL.	>> Probes: <reg:line17>
(In Cycle: 3)
```

This was diagnosed structurally, not adjusted based on the desired verdict: Algorithm 3
indexes `Reg[s_i]` by share, so equal register inputs do not authorize merging the two
physical probe locations. With the literal two-register circuit, the Table 2 result is
reproduced.

## Structural and functional sanity check

An independent exhaustive Boolean evaluator compared the HPC2 operation sequence with
the authors' `hpc2_1.nl` and checked every assignment of secret shares and random inputs.
Exact output:

```text
hpc2_single.nl: canonical HPC2 structure matches; exhaustive sharing correctness PASS
hpc2_iterated.nl: canonical HPC2 structure matches; exhaustive sharing correctness PASS
opini2_iterated.nl: canonical HPC2 structure matches; exhaustive sharing correctness PASS
```

The checked identity was `(out0 xor out1) = (x0 xor x1) AND (y0 xor y1)`.

## Artifact hashes

Command:

```sh
sha256sum 2022-023.pdf hpc2_single.nl hpc2_single_tran.nl hpc2_iterated.nl hpc2_iterated_tran.nl opini2_iterated.nl opini2_iterated_tran.nl
```

Exact output:

```text
79efc06990f9b09ec4f60785822cbfb77b53de042f240b3e08ac62055893b32b  2022-023.pdf
58ce7b5dbb94fb93c543cc111bd418346c82ad3576c3d9f845bb501127f14715  hpc2_single.nl
3eda327725a3266c34815078ecb70c5ef3e0ffa5d61c8a2e317a8e6e462af59e  hpc2_single_tran.nl
8b3d8a020face11af5ad851476ce20ab9e25731e6d22e49138c919c47b280305  hpc2_iterated.nl
ba2c1bed21957cea03a6be6230431b920050d921dd7f3277879d3dc3133ddd95  hpc2_iterated_tran.nl
ae1e3eaec82fced1a9de091eaf22dd23e6c680763c64c50321e241a83207dae6  opini2_iterated.nl
bfeb9d1d90b5c40dd12ab5f3977f6bba8f3722701bc5a7a1a183ecb307f2160e  opini2_iterated_tran.nl
```
