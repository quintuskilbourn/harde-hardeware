// NEGATIVE CONTROL (must FAIL): identical to the target plus one share-
// recombining register (leak0 <= prod[0]^prod[1]). MATCHI must flag the
// gate sensitive in multiple shares (glitch leakage).
// Iterative carry-save masked multiplier, prod = (A*B) mod 2^16. 76 assumed-
// OPINI gadget leaves (16 PP-gating u_pp_*, 30 carry-save MAJ u_sc_*/u_px_*,
// 30 final-add u_g_*/u_t_* — the verified-adder dataflow; the top-bit
// carry gadgets are omitted, their carries are dropped by mod 2^16), each with
// a DEDICATED r[k]/s[k] random bit. Every XOR/shift is strictly share-local.
// Dense sharing layout (share index fastest): port[2i]=share0, port[2i+1]=share1.
// Schedule: load @0; iteration i occupies cycles [1+8i, 8+8i]; S,C final
// from cycle 8*16+1; ripple output stable ~cycle 168; state cleared
// (share-local, to public 0) at cycle 185; randoms fresh [0,239].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module mul16_recomb (clk, rst, go, a, b, r, s, prod, leak_o);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [31:0] a;
(* matchi_type = "sharings_dense", matchi_active = "b_act" *) input [31:0] b;
(* matchi_type = "random", matchi_active = "r_act" *) input [75:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [75:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [31:0] prod;
(* matchi_type = "sharing", matchi_active = "out_act" *) output [1:0] leak_o;

// ---- activity shift register (single go pulse; windows are its taps) ----
(* keep *) wire act0 = go;
(* keep *) reg [240:1] actr;
always @(posedge clk) begin
    if (rst) actr <= 240'b0;
    else     actr <= {actr[239:1], act0};
end
wire [240:0] act = {actr, act0};
(* keep *) wire a_act   = |act[1:0];      // operands consumed only at the load edge
(* keep *) wire b_act   = |act[1:0];
(* keep *) wire r_act   = |act[239:0];
(* keep *) wire s_act   = |act[240:1];
(* keep *) wire out_act = |act[237:0];
(* keep *) wire clr     = act[185];  // bounded sensitivity: zero the state regs

// ---- public FSM: iteration counter + phase (control only, data-independent) ----
reg running;
reg [4:0] it;
reg [2:0] ph;
always @(posedge clk) begin
    if (rst) begin running <= 1'b0; it <= 0; ph <= 3'd0; end
    else if (go) begin running <= 1'b1; it <= 0; ph <= 3'd0; end
    else if (running) begin
        if (ph == 3'd7) begin
            ph <= 3'd0;
            if (it == 5'd15) begin running <= 1'b0; it <= 0; end
            else it <= it + 5'd1;
        end else ph <= ph + 3'd1;
    end
end

// ---- state registers (per-share; NEVER mix share 0 and share 1) ----
reg [15:0] aa0, aa1;          // multiplicand A, shifts left (public 0 in)
reg [15:0] bb0, bb1;          // multiplier B, shifts right (public 0 in)
reg [15:0] S0, S1, C0, C1;    // carry-save accumulator
reg [15:0] pp0, pp1;          // registered PP-gadget outputs
wire [15:0] w_pp0, w_pp1;
wire [14:0] w_sc0, w_sc1, w_px0, w_px1;   // top bit not computed (mod 2^16)
wire [14:0] maj0 = w_sc0 ^ w_px0;   // share-local XOR of two gadget outputs
wire [14:0] maj1 = w_sc1 ^ w_px1;   // (same pattern as the adder's g^t)

always @(posedge clk) begin
    if (rst || clr) begin
        aa0 <= 0; aa1 <= 0; bb0 <= 0; bb1 <= 0;
        S0 <= 0; S1 <= 0; C0 <= 0; C1 <= 0; pp0 <= 0; pp1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        aa0 <= {a[30], a[28], a[26], a[24], a[22], a[20], a[18], a[16], a[14], a[12], a[10], a[8], a[6], a[4], a[2], a[0]};
        aa1 <= {a[31], a[29], a[27], a[25], a[23], a[21], a[19], a[17], a[15], a[13], a[11], a[9], a[7], a[5], a[3], a[1]};
        bb0 <= {b[30], b[28], b[26], b[24], b[22], b[20], b[18], b[16], b[14], b[12], b[10], b[8], b[6], b[4], b[2], b[0]};
        bb1 <= {b[31], b[29], b[27], b[25], b[23], b[21], b[19], b[17], b[15], b[13], b[11], b[9], b[7], b[5], b[3], b[1]};
        S0 <= 0; S1 <= 0; C0 <= 0; C1 <= 0; pp0 <= 0; pp1 <= 0;
    end else if (running) begin
        if (ph == 3'd3) begin pp0 <= w_pp0; pp1 <= w_pp1; end
        if (ph == 3'd7) begin
            S0 <= S0 ^ C0 ^ pp0;                    // share-local
            S1 <= S1 ^ C1 ^ pp1;
            C0 <= {maj0, 1'b0};                   // <<1 = mod 2^16 accumulate
            C1 <= {maj1, 1'b0};
            aa0 <= {aa0[14:0], 1'b0};          // A <<= 1 (per-share)
            aa1 <= {aa1[14:0], 1'b0};
            bb0 <= {1'b0, bb0[15:1]};          // B >>= 1 (per-share)
            bb1 <= {1'b0, bb1[15:1]};
        end
    end
end

// ---- 1-cycle per-share balance registers: every gadget ina arrives one
// cycle after its inb (gadget contract ina@1/inb@0 — the iszero256 pattern).
// Unconditional, so they drain by themselves one cycle after clr.
reg [15:0] aa_d0, aa_d1;      // ina of u_pp_*  (inb = bbit)
reg [15:0] c_d0, c_d1;        // ina of u_sc_*  (inb = S)
reg [15:0] x_d0, x_d1;        // ina of u_px_*  (inb = pp); x = S^C share-local
reg [15:0] S_d0, S_d1;        // final adder operand a := delayed S (b := C)
always @(posedge clk) begin
    aa_d0 <= aa0;       aa_d1 <= aa1;
    c_d0  <= C0;        c_d1  <= C1;
    x_d0  <= S0 ^ C0;   x_d1  <= S1 ^ C1;
    S_d0  <= S0;        S_d1  <= S1;
end


// ===== PP gating: PP[j] = aa[j] AND bbit  (bbit = current B bit, both shares fan out) =====
MSKand_opini2_d2 u_pp_0 (
    .ina({aa_d1[0], aa_d0[0]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({w_pp1[0], w_pp0[0]}));
MSKand_opini2_d2 u_pp_1 (
    .ina({aa_d1[1], aa_d0[1]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[1]), .s(s[1]), .clk(clk), .out({w_pp1[1], w_pp0[1]}));
MSKand_opini2_d2 u_pp_2 (
    .ina({aa_d1[2], aa_d0[2]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[2]), .s(s[2]), .clk(clk), .out({w_pp1[2], w_pp0[2]}));
MSKand_opini2_d2 u_pp_3 (
    .ina({aa_d1[3], aa_d0[3]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[3]), .s(s[3]), .clk(clk), .out({w_pp1[3], w_pp0[3]}));
MSKand_opini2_d2 u_pp_4 (
    .ina({aa_d1[4], aa_d0[4]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[4]), .s(s[4]), .clk(clk), .out({w_pp1[4], w_pp0[4]}));
MSKand_opini2_d2 u_pp_5 (
    .ina({aa_d1[5], aa_d0[5]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[5]), .s(s[5]), .clk(clk), .out({w_pp1[5], w_pp0[5]}));
MSKand_opini2_d2 u_pp_6 (
    .ina({aa_d1[6], aa_d0[6]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[6]), .s(s[6]), .clk(clk), .out({w_pp1[6], w_pp0[6]}));
MSKand_opini2_d2 u_pp_7 (
    .ina({aa_d1[7], aa_d0[7]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[7]), .s(s[7]), .clk(clk), .out({w_pp1[7], w_pp0[7]}));
MSKand_opini2_d2 u_pp_8 (
    .ina({aa_d1[8], aa_d0[8]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[8]), .s(s[8]), .clk(clk), .out({w_pp1[8], w_pp0[8]}));
MSKand_opini2_d2 u_pp_9 (
    .ina({aa_d1[9], aa_d0[9]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[9]), .s(s[9]), .clk(clk), .out({w_pp1[9], w_pp0[9]}));
MSKand_opini2_d2 u_pp_10 (
    .ina({aa_d1[10], aa_d0[10]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[10]), .s(s[10]), .clk(clk), .out({w_pp1[10], w_pp0[10]}));
MSKand_opini2_d2 u_pp_11 (
    .ina({aa_d1[11], aa_d0[11]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[11]), .s(s[11]), .clk(clk), .out({w_pp1[11], w_pp0[11]}));
MSKand_opini2_d2 u_pp_12 (
    .ina({aa_d1[12], aa_d0[12]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[12]), .s(s[12]), .clk(clk), .out({w_pp1[12], w_pp0[12]}));
MSKand_opini2_d2 u_pp_13 (
    .ina({aa_d1[13], aa_d0[13]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[13]), .s(s[13]), .clk(clk), .out({w_pp1[13], w_pp0[13]}));
MSKand_opini2_d2 u_pp_14 (
    .ina({aa_d1[14], aa_d0[14]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[14]), .s(s[14]), .clk(clk), .out({w_pp1[14], w_pp0[14]}));
MSKand_opini2_d2 u_pp_15 (
    .ina({aa_d1[15], aa_d0[15]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[15]), .s(s[15]), .clk(clk), .out({w_pp1[15], w_pp0[15]}));

// ===== carry-save MAJ: newC[j+1] = (S&C)[j] ^ (PP&(S^C))[j] =====
// (bit 15 omitted: its carry is dropped by the <<1 mod-2^16 accumulate)
MSKand_opini2_d2 u_sc_0 (
    .ina({c_d1[0], c_d0[0]}), .inb({S1[0], S0[0]}),
    .rnd(r[16]), .s(s[16]), .clk(clk), .out({w_sc1[0], w_sc0[0]}));
MSKand_opini2_d2 u_px_0 (
    .ina({x_d1[0], x_d0[0]}), .inb({pp1[0], pp0[0]}),
    .rnd(r[17]), .s(s[17]), .clk(clk), .out({w_px1[0], w_px0[0]}));
MSKand_opini2_d2 u_sc_1 (
    .ina({c_d1[1], c_d0[1]}), .inb({S1[1], S0[1]}),
    .rnd(r[18]), .s(s[18]), .clk(clk), .out({w_sc1[1], w_sc0[1]}));
MSKand_opini2_d2 u_px_1 (
    .ina({x_d1[1], x_d0[1]}), .inb({pp1[1], pp0[1]}),
    .rnd(r[19]), .s(s[19]), .clk(clk), .out({w_px1[1], w_px0[1]}));
MSKand_opini2_d2 u_sc_2 (
    .ina({c_d1[2], c_d0[2]}), .inb({S1[2], S0[2]}),
    .rnd(r[20]), .s(s[20]), .clk(clk), .out({w_sc1[2], w_sc0[2]}));
MSKand_opini2_d2 u_px_2 (
    .ina({x_d1[2], x_d0[2]}), .inb({pp1[2], pp0[2]}),
    .rnd(r[21]), .s(s[21]), .clk(clk), .out({w_px1[2], w_px0[2]}));
MSKand_opini2_d2 u_sc_3 (
    .ina({c_d1[3], c_d0[3]}), .inb({S1[3], S0[3]}),
    .rnd(r[22]), .s(s[22]), .clk(clk), .out({w_sc1[3], w_sc0[3]}));
MSKand_opini2_d2 u_px_3 (
    .ina({x_d1[3], x_d0[3]}), .inb({pp1[3], pp0[3]}),
    .rnd(r[23]), .s(s[23]), .clk(clk), .out({w_px1[3], w_px0[3]}));
MSKand_opini2_d2 u_sc_4 (
    .ina({c_d1[4], c_d0[4]}), .inb({S1[4], S0[4]}),
    .rnd(r[24]), .s(s[24]), .clk(clk), .out({w_sc1[4], w_sc0[4]}));
MSKand_opini2_d2 u_px_4 (
    .ina({x_d1[4], x_d0[4]}), .inb({pp1[4], pp0[4]}),
    .rnd(r[25]), .s(s[25]), .clk(clk), .out({w_px1[4], w_px0[4]}));
MSKand_opini2_d2 u_sc_5 (
    .ina({c_d1[5], c_d0[5]}), .inb({S1[5], S0[5]}),
    .rnd(r[26]), .s(s[26]), .clk(clk), .out({w_sc1[5], w_sc0[5]}));
MSKand_opini2_d2 u_px_5 (
    .ina({x_d1[5], x_d0[5]}), .inb({pp1[5], pp0[5]}),
    .rnd(r[27]), .s(s[27]), .clk(clk), .out({w_px1[5], w_px0[5]}));
MSKand_opini2_d2 u_sc_6 (
    .ina({c_d1[6], c_d0[6]}), .inb({S1[6], S0[6]}),
    .rnd(r[28]), .s(s[28]), .clk(clk), .out({w_sc1[6], w_sc0[6]}));
MSKand_opini2_d2 u_px_6 (
    .ina({x_d1[6], x_d0[6]}), .inb({pp1[6], pp0[6]}),
    .rnd(r[29]), .s(s[29]), .clk(clk), .out({w_px1[6], w_px0[6]}));
MSKand_opini2_d2 u_sc_7 (
    .ina({c_d1[7], c_d0[7]}), .inb({S1[7], S0[7]}),
    .rnd(r[30]), .s(s[30]), .clk(clk), .out({w_sc1[7], w_sc0[7]}));
MSKand_opini2_d2 u_px_7 (
    .ina({x_d1[7], x_d0[7]}), .inb({pp1[7], pp0[7]}),
    .rnd(r[31]), .s(s[31]), .clk(clk), .out({w_px1[7], w_px0[7]}));
MSKand_opini2_d2 u_sc_8 (
    .ina({c_d1[8], c_d0[8]}), .inb({S1[8], S0[8]}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({w_sc1[8], w_sc0[8]}));
MSKand_opini2_d2 u_px_8 (
    .ina({x_d1[8], x_d0[8]}), .inb({pp1[8], pp0[8]}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({w_px1[8], w_px0[8]}));
MSKand_opini2_d2 u_sc_9 (
    .ina({c_d1[9], c_d0[9]}), .inb({S1[9], S0[9]}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({w_sc1[9], w_sc0[9]}));
MSKand_opini2_d2 u_px_9 (
    .ina({x_d1[9], x_d0[9]}), .inb({pp1[9], pp0[9]}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({w_px1[9], w_px0[9]}));
MSKand_opini2_d2 u_sc_10 (
    .ina({c_d1[10], c_d0[10]}), .inb({S1[10], S0[10]}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({w_sc1[10], w_sc0[10]}));
MSKand_opini2_d2 u_px_10 (
    .ina({x_d1[10], x_d0[10]}), .inb({pp1[10], pp0[10]}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({w_px1[10], w_px0[10]}));
MSKand_opini2_d2 u_sc_11 (
    .ina({c_d1[11], c_d0[11]}), .inb({S1[11], S0[11]}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({w_sc1[11], w_sc0[11]}));
MSKand_opini2_d2 u_px_11 (
    .ina({x_d1[11], x_d0[11]}), .inb({pp1[11], pp0[11]}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({w_px1[11], w_px0[11]}));
MSKand_opini2_d2 u_sc_12 (
    .ina({c_d1[12], c_d0[12]}), .inb({S1[12], S0[12]}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({w_sc1[12], w_sc0[12]}));
MSKand_opini2_d2 u_px_12 (
    .ina({x_d1[12], x_d0[12]}), .inb({pp1[12], pp0[12]}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({w_px1[12], w_px0[12]}));
MSKand_opini2_d2 u_sc_13 (
    .ina({c_d1[13], c_d0[13]}), .inb({S1[13], S0[13]}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({w_sc1[13], w_sc0[13]}));
MSKand_opini2_d2 u_px_13 (
    .ina({x_d1[13], x_d0[13]}), .inb({pp1[13], pp0[13]}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({w_px1[13], w_px0[13]}));
MSKand_opini2_d2 u_sc_14 (
    .ina({c_d1[14], c_d0[14]}), .inb({S1[14], S0[14]}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({w_sc1[14], w_sc0[14]}));
MSKand_opini2_d2 u_px_14 (
    .ina({x_d1[14], x_d0[14]}), .inb({pp1[14], pp0[14]}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({w_px1[14], w_px0[14]}));

// ===== final ripple add: prod = S + C mod 2^16 (verified-adder dataflow, sub=0) =====
// (bit 15 needs no g/t gadgets: its carry-out is dropped by mod 2^16.
//  fc[1..14] feed gadget ports so they survive synthesis; the carry INTO the
//  top bit is kept as standalone scalars fct0/fct1 — abc may absorb them into
//  the prod XOR without leaving a driverless vector bit behind.)
wire [14:0] fc0, fc1;
assign fc0[0] = 1'b0;
assign fc1[0] = 1'b0;
wire p0_0 = S_d0[0] ^ C0[0];
wire p1_0 = S_d1[0] ^ C1[0];
wire g0_0, g1_0, t0_0, t1_0;
MSKand_opini2_d2 u_g_0 (
    .ina({S_d1[0], S_d0[0]}), .inb({C1[0], C0[0]}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({g1_0, g0_0}));
MSKand_opini2_d2 u_t_0 (
    .ina({fc1[0], fc0[0]}), .inb({p1_0, p0_0}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({t1_0, t0_0}));
assign fc0[1] = g0_0 ^ t0_0;
assign fc1[1] = g1_0 ^ t1_0;
assign prod[0]   = p0_0 ^ fc0[0];
assign prod[1] = p1_0 ^ fc1[0];
wire p0_1 = S_d0[1] ^ C0[1];
wire p1_1 = S_d1[1] ^ C1[1];
wire g0_1, g1_1, t0_1, t1_1;
MSKand_opini2_d2 u_g_1 (
    .ina({S_d1[1], S_d0[1]}), .inb({C1[1], C0[1]}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({g1_1, g0_1}));
MSKand_opini2_d2 u_t_1 (
    .ina({fc1[1], fc0[1]}), .inb({p1_1, p0_1}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({t1_1, t0_1}));
assign fc0[2] = g0_1 ^ t0_1;
assign fc1[2] = g1_1 ^ t1_1;
assign prod[2]   = p0_1 ^ fc0[1];
assign prod[3] = p1_1 ^ fc1[1];
wire p0_2 = S_d0[2] ^ C0[2];
wire p1_2 = S_d1[2] ^ C1[2];
wire g0_2, g1_2, t0_2, t1_2;
MSKand_opini2_d2 u_g_2 (
    .ina({S_d1[2], S_d0[2]}), .inb({C1[2], C0[2]}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({g1_2, g0_2}));
MSKand_opini2_d2 u_t_2 (
    .ina({fc1[2], fc0[2]}), .inb({p1_2, p0_2}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({t1_2, t0_2}));
assign fc0[3] = g0_2 ^ t0_2;
assign fc1[3] = g1_2 ^ t1_2;
assign prod[4]   = p0_2 ^ fc0[2];
assign prod[5] = p1_2 ^ fc1[2];
wire p0_3 = S_d0[3] ^ C0[3];
wire p1_3 = S_d1[3] ^ C1[3];
wire g0_3, g1_3, t0_3, t1_3;
MSKand_opini2_d2 u_g_3 (
    .ina({S_d1[3], S_d0[3]}), .inb({C1[3], C0[3]}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({g1_3, g0_3}));
MSKand_opini2_d2 u_t_3 (
    .ina({fc1[3], fc0[3]}), .inb({p1_3, p0_3}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({t1_3, t0_3}));
assign fc0[4] = g0_3 ^ t0_3;
assign fc1[4] = g1_3 ^ t1_3;
assign prod[6]   = p0_3 ^ fc0[3];
assign prod[7] = p1_3 ^ fc1[3];
wire p0_4 = S_d0[4] ^ C0[4];
wire p1_4 = S_d1[4] ^ C1[4];
wire g0_4, g1_4, t0_4, t1_4;
MSKand_opini2_d2 u_g_4 (
    .ina({S_d1[4], S_d0[4]}), .inb({C1[4], C0[4]}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({g1_4, g0_4}));
MSKand_opini2_d2 u_t_4 (
    .ina({fc1[4], fc0[4]}), .inb({p1_4, p0_4}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({t1_4, t0_4}));
assign fc0[5] = g0_4 ^ t0_4;
assign fc1[5] = g1_4 ^ t1_4;
assign prod[8]   = p0_4 ^ fc0[4];
assign prod[9] = p1_4 ^ fc1[4];
wire p0_5 = S_d0[5] ^ C0[5];
wire p1_5 = S_d1[5] ^ C1[5];
wire g0_5, g1_5, t0_5, t1_5;
MSKand_opini2_d2 u_g_5 (
    .ina({S_d1[5], S_d0[5]}), .inb({C1[5], C0[5]}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({g1_5, g0_5}));
MSKand_opini2_d2 u_t_5 (
    .ina({fc1[5], fc0[5]}), .inb({p1_5, p0_5}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({t1_5, t0_5}));
assign fc0[6] = g0_5 ^ t0_5;
assign fc1[6] = g1_5 ^ t1_5;
assign prod[10]   = p0_5 ^ fc0[5];
assign prod[11] = p1_5 ^ fc1[5];
wire p0_6 = S_d0[6] ^ C0[6];
wire p1_6 = S_d1[6] ^ C1[6];
wire g0_6, g1_6, t0_6, t1_6;
MSKand_opini2_d2 u_g_6 (
    .ina({S_d1[6], S_d0[6]}), .inb({C1[6], C0[6]}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({g1_6, g0_6}));
MSKand_opini2_d2 u_t_6 (
    .ina({fc1[6], fc0[6]}), .inb({p1_6, p0_6}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({t1_6, t0_6}));
assign fc0[7] = g0_6 ^ t0_6;
assign fc1[7] = g1_6 ^ t1_6;
assign prod[12]   = p0_6 ^ fc0[6];
assign prod[13] = p1_6 ^ fc1[6];
wire p0_7 = S_d0[7] ^ C0[7];
wire p1_7 = S_d1[7] ^ C1[7];
wire g0_7, g1_7, t0_7, t1_7;
MSKand_opini2_d2 u_g_7 (
    .ina({S_d1[7], S_d0[7]}), .inb({C1[7], C0[7]}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({g1_7, g0_7}));
MSKand_opini2_d2 u_t_7 (
    .ina({fc1[7], fc0[7]}), .inb({p1_7, p0_7}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({t1_7, t0_7}));
assign fc0[8] = g0_7 ^ t0_7;
assign fc1[8] = g1_7 ^ t1_7;
assign prod[14]   = p0_7 ^ fc0[7];
assign prod[15] = p1_7 ^ fc1[7];
wire p0_8 = S_d0[8] ^ C0[8];
wire p1_8 = S_d1[8] ^ C1[8];
wire g0_8, g1_8, t0_8, t1_8;
MSKand_opini2_d2 u_g_8 (
    .ina({S_d1[8], S_d0[8]}), .inb({C1[8], C0[8]}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({g1_8, g0_8}));
MSKand_opini2_d2 u_t_8 (
    .ina({fc1[8], fc0[8]}), .inb({p1_8, p0_8}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({t1_8, t0_8}));
assign fc0[9] = g0_8 ^ t0_8;
assign fc1[9] = g1_8 ^ t1_8;
assign prod[16]   = p0_8 ^ fc0[8];
assign prod[17] = p1_8 ^ fc1[8];
wire p0_9 = S_d0[9] ^ C0[9];
wire p1_9 = S_d1[9] ^ C1[9];
wire g0_9, g1_9, t0_9, t1_9;
MSKand_opini2_d2 u_g_9 (
    .ina({S_d1[9], S_d0[9]}), .inb({C1[9], C0[9]}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({g1_9, g0_9}));
MSKand_opini2_d2 u_t_9 (
    .ina({fc1[9], fc0[9]}), .inb({p1_9, p0_9}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({t1_9, t0_9}));
assign fc0[10] = g0_9 ^ t0_9;
assign fc1[10] = g1_9 ^ t1_9;
assign prod[18]   = p0_9 ^ fc0[9];
assign prod[19] = p1_9 ^ fc1[9];
wire p0_10 = S_d0[10] ^ C0[10];
wire p1_10 = S_d1[10] ^ C1[10];
wire g0_10, g1_10, t0_10, t1_10;
MSKand_opini2_d2 u_g_10 (
    .ina({S_d1[10], S_d0[10]}), .inb({C1[10], C0[10]}),
    .rnd(r[66]), .s(s[66]), .clk(clk), .out({g1_10, g0_10}));
MSKand_opini2_d2 u_t_10 (
    .ina({fc1[10], fc0[10]}), .inb({p1_10, p0_10}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({t1_10, t0_10}));
assign fc0[11] = g0_10 ^ t0_10;
assign fc1[11] = g1_10 ^ t1_10;
assign prod[20]   = p0_10 ^ fc0[10];
assign prod[21] = p1_10 ^ fc1[10];
wire p0_11 = S_d0[11] ^ C0[11];
wire p1_11 = S_d1[11] ^ C1[11];
wire g0_11, g1_11, t0_11, t1_11;
MSKand_opini2_d2 u_g_11 (
    .ina({S_d1[11], S_d0[11]}), .inb({C1[11], C0[11]}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({g1_11, g0_11}));
MSKand_opini2_d2 u_t_11 (
    .ina({fc1[11], fc0[11]}), .inb({p1_11, p0_11}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({t1_11, t0_11}));
assign fc0[12] = g0_11 ^ t0_11;
assign fc1[12] = g1_11 ^ t1_11;
assign prod[22]   = p0_11 ^ fc0[11];
assign prod[23] = p1_11 ^ fc1[11];
wire p0_12 = S_d0[12] ^ C0[12];
wire p1_12 = S_d1[12] ^ C1[12];
wire g0_12, g1_12, t0_12, t1_12;
MSKand_opini2_d2 u_g_12 (
    .ina({S_d1[12], S_d0[12]}), .inb({C1[12], C0[12]}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({g1_12, g0_12}));
MSKand_opini2_d2 u_t_12 (
    .ina({fc1[12], fc0[12]}), .inb({p1_12, p0_12}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({t1_12, t0_12}));
assign fc0[13] = g0_12 ^ t0_12;
assign fc1[13] = g1_12 ^ t1_12;
assign prod[24]   = p0_12 ^ fc0[12];
assign prod[25] = p1_12 ^ fc1[12];
wire p0_13 = S_d0[13] ^ C0[13];
wire p1_13 = S_d1[13] ^ C1[13];
wire g0_13, g1_13, t0_13, t1_13;
MSKand_opini2_d2 u_g_13 (
    .ina({S_d1[13], S_d0[13]}), .inb({C1[13], C0[13]}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({g1_13, g0_13}));
MSKand_opini2_d2 u_t_13 (
    .ina({fc1[13], fc0[13]}), .inb({p1_13, p0_13}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({t1_13, t0_13}));
assign fc0[14] = g0_13 ^ t0_13;
assign fc1[14] = g1_13 ^ t1_13;
assign prod[26]   = p0_13 ^ fc0[13];
assign prod[27] = p1_13 ^ fc1[13];
wire p0_14 = S_d0[14] ^ C0[14];
wire p1_14 = S_d1[14] ^ C1[14];
wire g0_14, g1_14, t0_14, t1_14;
MSKand_opini2_d2 u_g_14 (
    .ina({S_d1[14], S_d0[14]}), .inb({C1[14], C0[14]}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({g1_14, g0_14}));
MSKand_opini2_d2 u_t_14 (
    .ina({fc1[14], fc0[14]}), .inb({p1_14, p0_14}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({t1_14, t0_14}));
wire fct0 = g0_14 ^ t0_14;
wire fct1 = g1_14 ^ t1_14;
assign prod[28]   = p0_14 ^ fc0[14];
assign prod[29] = p1_14 ^ fc1[14];
// top bit: sum only, carry-out dropped (mod 2^16, EVM MUL)
wire p0_15 = S_d0[15] ^ C0[15];
wire p1_15 = S_d1[15] ^ C1[15];
assign prod[30]   = p0_15 ^ fct0;
assign prod[31] = p1_15 ^ fct1;

// BUG UNDER TEST: recombine the two shares of prod bit 0. leak0 holds
// prod[0]^prod[1] (both shares) -> the XOR gate is sensitive in ShareSet{0}
// AND ShareSet{1} -> MATCHI glitch leakage. Driven onto share 0 of leak_o.
(* keep = "yes" *) reg leak0, leak1;
always @(posedge clk) begin
    leak0 <= prod[0] ^ prod[1];
    leak1 <= 1'b0;
end
assign leak_o = {leak1, leak0};

endmodule
