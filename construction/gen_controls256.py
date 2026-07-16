#!/usr/bin/env python3
"""Emit the 256-bit non-vacuity control tops, mirroring the 8-bit matrix in
./ :
  top_add256_rndreuse.v  — NEG control (must FAIL): bit-0 u_propagate reuses
                           bit-0 u_generate's randomness r[0]/s[0].
  top_add256_recomb.v    — NEG control (must FAIL): extra top-level register
                           recombines the two shares of sum bit 0.
  top_add256_pini.v      — LABEL control (EXPECTED PASS, single-pass): identical
                           dataflow but instantiates the PINI-relabelled leaf
                           MSKand_opini2_d2_pini. Recorded, NOT counted as
                           non-vacuity (see RESULT_ADD256.md).
All three keep the exact activity-window annotations of top_add256_opini2.
"""
N = 256
E = 2 * N + 2
B_HI, A_HI, R_HI, S_HI, OUT_HI = E - 1, E, 2 * E - 1, 2 * E, 2 * E + 2


def header(modname, prop_comment, extra_ports="", leak_port=""):
    lp = ""
    if leak_port:
        lp = f"\n(* matchi_type = \"control\" *) output {leak_port};"
    return f"""{prop_comment}
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module {modname} (clk, rst, go, sub, a, b, r, s, sum, cout{extra_ports});
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "control" *) input sub;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [{2*N-1}:0] a;
(* matchi_type = "sharings_dense", matchi_active = "b_act" *) input [{2*N-1}:0] b;
(* matchi_type = "random", matchi_active = "r_act" *) input [{2*N-1}:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [{2*N-1}:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [{2*N-1}:0] sum;
(* matchi_type = "sharing", matchi_active = "out_act" *) output [1:0] cout;{lp}

(* keep *) wire act0 = go;
(* keep *) reg [{OUT_HI}:1] actr;
always @(posedge clk) begin
    if (rst) actr <= {OUT_HI}'b0;
    else     actr <= {{actr[{OUT_HI-1}:1], act0}};
end
wire [{OUT_HI}:0] act = {{actr, act0}};
(* keep *) wire b_act   = |act[{B_HI}:0];
(* keep *) wire a_act   = |act[{A_HI}:1];
(* keep *) wire r_act   = |act[{R_HI}:0];
(* keep *) wire s_act   = |act[{S_HI}:1];
(* keep *) wire out_act = |act[{OUT_HI}:0];

wire [{N}:0] carry0, carry1;
assign carry0[0] = sub;
assign carry1[0] = 1'b0;"""


def bitslice(i, leaf, rndreuse=False):
    if rndreuse and i == 0:
        prnd, psnd = "r[0]", "s[0]"     # BUG: reuse bit-0 generate's randomness
        note = "\n// BUG UNDER TEST: bit 0 reuses u_generate's randomness (r[0]/s[0])."
    else:
        prnd, psnd = f"r[{2*i+1}]", f"s[{2*i+1}]"
        note = ""
    return f"""
// ---- bit {i} ----{note}
wire b0_eff_{i} = b[{2*i}] ^ sub;
wire p0_{i} = a[{2*i}]   ^ b0_eff_{i};
wire p1_{i} = a[{2*i+1}] ^ b[{2*i+1}];
wire g0_{i}, g1_{i}, t0_{i}, t1_{i};
{leaf} u_generate_{i} (
    .ina({{a[{2*i+1}], a[{2*i}]}}), .inb({{b[{2*i+1}], b0_eff_{i}}}),
    .rnd(r[{2*i}]), .s(s[{2*i}]), .clk(clk), .out({{g1_{i}, g0_{i}}}));
{leaf} u_propagate_{i} (
    .ina({{carry1[{i}], carry0[{i}]}}), .inb({{p1_{i}, p0_{i}}}),
    .rnd({prnd}), .s({psnd}), .clk(clk), .out({{t1_{i}, t0_{i}}}));
assign carry0[{i+1}] = g0_{i} ^ t0_{i};
assign carry1[{i+1}] = g1_{i} ^ t1_{i};
assign sum[{2*i}]   = p0_{i} ^ carry0[{i}];
assign sum[{2*i+1}] = p1_{i} ^ carry1[{i}];"""


def build(modname, leaf, rndreuse=False, recomb=False):
    if rndreuse:
        cmt = ("// NEGATIVE CONTROL (must FAIL): identical to top_add256_opini2 except bit 0's\n"
               "// u_propagate consumes r[0]/s[0] — the SAME random bits as bit 0's u_generate —\n"
               "// instead of its dedicated r[1]/s[1]. Classic randomness-reuse composition break;\n"
               "// MATCHI must report the multi-use. Mirrors ./top_add8_rndreuse.v.")
    elif recomb:
        cmt = ("// NEGATIVE CONTROL (must FAIL): identical to top_add256_opini2 plus one\n"
               "// share-recombining register in top-level glue (leak <= share0 ^ share1 of sum\n"
               "// bit 0). MATCHI must flag the gate sensitive in multiple shares. Mirrors\n"
               "// ./top_add8_recomb.v.")
    else:  # pini label control
        cmt = ("// LABEL CONTROL (EXPECTED PASS, single-pass): identical dataflow to\n"
               "// top_add256_opini2 but instantiates the PINI-relabelled leaf\n"
               "// MSKand_opini2_d2_pini. Single-pass adder ⇒ PINI suffices ⇒ PASS. Recorded,\n"
               "// NOT counted as non-vacuity (OPINI-vs-PINI is carried by the chain controls).\n"
               "// Mirrors ./top_add8_pini.v.")
    ep = ", leak_o" if recomb else ""
    lk = "leak_o" if recomb else ""
    L = [header(modname, cmt, extra_ports=ep, leak_port=lk)]
    for i in range(N):
        L.append(bitslice(i, leaf, rndreuse=rndreuse))
    L.append(f"\nassign cout = {{carry1[{N}], carry0[{N}]}};")
    if recomb:
        L.append("""
// BUG UNDER TEST: recombine the two shares of sum bit 0.
(* keep *) reg leak;
always @(posedge clk) leak <= sum[0] ^ sum[1];
assign leak_o = out_act & leak;""")
    L.append("\nendmodule\n")
    return "\n".join(L)


def emit(fn, text, leaf, expect_count):
    # count actual instantiations ("<leaf> u_..."), not comment mentions
    n = text.count(leaf + " u_")
    assert n == expect_count, f"{fn}: leaf {leaf} x{n}, expected {expect_count}"
    with open(fn, "w") as f:
        f.write(text)
    print(f"wrote {fn}: {n} {leaf} instances")


emit("top_add256_rndreuse.v",
     build("top_add256_rndreuse", "MSKand_opini2_d2", rndreuse=True),
     "MSKand_opini2_d2", 512)
emit("top_add256_recomb.v",
     build("top_add256_recomb", "MSKand_opini2_d2", recomb=True),
     "MSKand_opini2_d2", 512)
emit("top_add256_pini.v",
     build("top_add256_pini", "MSKand_opini2_d2_pini"),
     "MSKand_opini2_d2_pini", 512)
