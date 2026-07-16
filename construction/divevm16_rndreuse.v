// NEGATIVE CONTROL (must FAIL): identical to the target except gating
// gadget u_gq_1 consumes the SAME random bits as u_gq_0, active in the
// same cycles — the bug is in the NEW composition stage, so the control
// exercises exactly what this top adds. MATCHI must report multi-use.
// EVM DIV/MOD (B==0 -> 0): restoring-divider core (50 gadgets, bubble-
// free reuse) + OR-reduce nonzero tree over B (15 gadgets) + broadcast-
// AND output gating (32 gadgets). NG=97, each with a DEDICATED
// r[k]/s[k] random bit. Every XOR/NOT is strictly share-local.
// Dense sharing layout (share index fastest): port[2i]=share0, port[2i+1]=share1.
// Schedule: load @0; div iterations [1, 768]; nzr (=B!=0) captured @48;
// qe/rem_e recombine stably from ~773; state cleared @784;
// randoms fresh [0,838].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module divevm16_rndreuse (clk, rst, go, a, b, r, s, qe, reme);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [31:0] a;
(* matchi_type = "sharings_dense", matchi_active = "b_act" *) input [31:0] b;
(* matchi_type = "random", matchi_active = "r_act" *) input [96:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [96:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [31:0] qe;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [31:0] reme;

// ---- activity windows from an idempotent cycle counter (public control) ----
reg [10:0] cnt;
always @(posedge clk) begin
    if (rst)                       cnt <= 11'd0;
    else if (go)                   cnt <= 11'd1;
    else if (cnt != 11'd0 && cnt != 11'd841) cnt <= cnt + 11'd1;
end
(* keep *) wire a_act   = go || (cnt == 11'd1);   // operands consumed at load
(* keep *) wire b_act   = go || (cnt == 11'd1);
(* keep *) wire r_act   = go || (cnt >= 11'd1 && cnt <= 11'd838);
(* keep *) wire s_act   =       (cnt >= 11'd1 && cnt <= 11'd839);
(* keep *) wire out_act = go || (cnt >= 11'd1 && cnt <= 11'd836);
(* keep *) wire clr     = (cnt == 11'd784);  // bounded sensitivity
(* keep *) wire zcap    = (cnt == 11'd48);   // nonzero-tree capture

// ---- public FSM: iteration counter + phase (control only, data-independent) ----
reg running;
reg [4:0] it;
reg [5:0] ph;
always @(posedge clk) begin
    if (rst) begin running <= 1'b0; it <= 0; ph <= 0; end
    else if (go) begin running <= 1'b1; it <= 0; ph <= 0; end
    else if (running) begin
        if (ph == 47) begin
            ph <= 0;
            if (it == 5'd15) begin running <= 1'b0; it <= 0; end
            else it <= it + 5'd1;
        end else ph <= ph + 1'b1;
    end
end

// ---- div-core state registers (per-share; NEVER mix share 0 and share 1) ----
reg [15:0] R0, R1;            // partial remainder
reg [15:0] A0, A1;            // dividend, shifts left (public 0 in)
reg [15:0] Q0, Q1;            // quotient, shifts left (cout in)
reg [15:0] Bn0, Bn1;          // ~B, complement share-local (share 0 only)
reg [15:0] Bz0, Bz1;          // B held for the nonzero tree (per-share)
reg [15:0] Treg0, Treg1;      // registered subtract result (settled)
reg coutr0, coutr1;              // registered carry-out = quotient bit
reg nzr0, nzr1;                  // registered tree root = (B != 0) sharing
wire [16:0] Rsh0 = {R0, A0[15]};   // Rsh = R<<1 | msb(A), per share
wire [16:0] Rsh1 = {R1, A1[15]};
wire [15:0] w_m0, w_m1;       // borrow-mux gadget outputs
wire nz0, nz1;                   // nonzero-tree root wires (pre-capture)
// (* keep *): T/coutw feed only register inputs; without keep, abc absorbs
// their XOR drivers into the register cone and MATCHI hits a driverless wire.
(* keep *) wire [15:0] T0, T1;   // subtract difference bits (settled by M1)
(* keep *) wire coutw0, coutw1;     // subtract carry-out = NOT borrow

always @(posedge clk) begin
    if (rst || clr) begin
        R0 <= 0; R1 <= 0; A0 <= 0; A1 <= 0; Q0 <= 0; Q1 <= 0;
        Bn0 <= 0; Bn1 <= 0; Bz0 <= 0; Bz1 <= 0; Treg0 <= 0; Treg1 <= 0;
        coutr0 <= 0; coutr1 <= 0; nzr0 <= 0; nzr1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        A0 <= {a[30], a[28], a[26], a[24], a[22], a[20], a[18], a[16], a[14], a[12], a[10], a[8], a[6], a[4], a[2], a[0]};
        A1 <= {a[31], a[29], a[27], a[25], a[23], a[21], a[19], a[17], a[15], a[13], a[11], a[9], a[7], a[5], a[3], a[1]};
        Bn0 <= ~{b[30], b[28], b[26], b[24], b[22], b[20], b[18], b[16], b[14], b[12], b[10], b[8], b[6], b[4], b[2], b[0]};   // share-local NOT: complement share 0
        Bn1 <= {b[31], b[29], b[27], b[25], b[23], b[21], b[19], b[17], b[15], b[13], b[11], b[9], b[7], b[5], b[3], b[1]};    // share 1 untouched
        Bz0 <= {b[30], b[28], b[26], b[24], b[22], b[20], b[18], b[16], b[14], b[12], b[10], b[8], b[6], b[4], b[2], b[0]};    // uncomplemented copy for the tree
        Bz1 <= {b[31], b[29], b[27], b[25], b[23], b[21], b[19], b[17], b[15], b[13], b[11], b[9], b[7], b[5], b[3], b[1]};
        R0 <= 0; R1 <= 0; Q0 <= 0; Q1 <= 0;
        Treg0 <= 0; Treg1 <= 0; coutr0 <= 0; coutr1 <= 0;
        nzr0 <= 0; nzr1 <= 0;
    end else begin
        if (running) begin
            if (ph == 39) begin   // subtract ripple settled: capture T, cout
                Treg0 <= T0; Treg1 <= T1;
                coutr0 <= coutw0; coutr1 <= coutw1;
            end
            if (ph == 47) begin    // iteration update (all share-local)
                R0 <= Rsh0[15:0] ^ w_m0;   // R' = cout ? T : Rsh
                R1 <= Rsh1[15:0] ^ w_m1;
                Q0 <= {Q0[14:0], coutr0};   // quotient bit, MSB first
                Q1 <= {Q1[14:0], coutr1};
                A0 <= {A0[14:0], 1'b0};     // A <<= 1 (per-share)
                A1 <= {A1[14:0], 1'b0};
            end
        end
        if (zcap) begin               // consistent share pair of (B != 0)
            nzr0 <= nz0; nzr1 <= nz1;
        end
    end
end

// ---- 1-cycle per-share balance registers: every gadget ina arrives one
// cycle after its inb (gadget contract ina@1/inb@0 — the iszero256 pattern).
// Unconditional, so they drain by themselves one cycle after clr.
reg [16:0] Rsh_d0, Rsh_d1;      // ina of u_g_*  (inb = Bn)
reg [15:0] xm_d0, xm_d1;      // ina of u_m_*  (inb = coutr); xm = Rsh^Treg
reg [15:0] q_d0, q_d1;        // ina of u_gq_* (inb = nzr broadcast)
reg [15:0] rm_d0, rm_d1;      // ina of u_gr_* (inb = nzr broadcast)
always @(posedge clk) begin
    Rsh_d0 <= Rsh0;                       Rsh_d1 <= Rsh1;
    xm_d0  <= Rsh0[15:0] ^ Treg0;      xm_d1  <= Rsh1[15:0] ^ Treg1;
    q_d0   <= Q0;                         q_d1   <= Q1;
    rm_d0  <= R0;                         rm_d1  <= R1;
end


// ===== (N+1)-bit ripple subtract: T = Rsh + ~B + 1 (verified-adder dataflow, sub=1) =====
// fc[0] = carry-in = public 1 (share pair (1,0)); Bn bit 16 = ~0 = public 1.
wire [16:0] fc0, fc1;
assign fc0[0] = 1'b1;
assign fc1[0] = 1'b0;
wire p0_0 = Rsh_d0[0] ^ Bn0[0];
wire p1_0 = Rsh_d1[0] ^ Bn1[0];
wire g0_0, g1_0, t0_0, t1_0;
MSKand_opini2_d2 u_g_0 (
    .ina({Rsh_d1[0], Rsh_d0[0]}), .inb({Bn1[0], Bn0[0]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({g1_0, g0_0}));
MSKand_opini2_d2 u_t_0 (
    .ina({fc1[0], fc0[0]}), .inb({p1_0, p0_0}),
    .rnd(r[1]), .s(s[1]), .clk(clk), .out({t1_0, t0_0}));
assign fc0[1] = g0_0 ^ t0_0;
assign fc1[1] = g1_0 ^ t1_0;
wire p0_1 = Rsh_d0[1] ^ Bn0[1];
wire p1_1 = Rsh_d1[1] ^ Bn1[1];
wire g0_1, g1_1, t0_1, t1_1;
MSKand_opini2_d2 u_g_1 (
    .ina({Rsh_d1[1], Rsh_d0[1]}), .inb({Bn1[1], Bn0[1]}),
    .rnd(r[2]), .s(s[2]), .clk(clk), .out({g1_1, g0_1}));
MSKand_opini2_d2 u_t_1 (
    .ina({fc1[1], fc0[1]}), .inb({p1_1, p0_1}),
    .rnd(r[3]), .s(s[3]), .clk(clk), .out({t1_1, t0_1}));
assign fc0[2] = g0_1 ^ t0_1;
assign fc1[2] = g1_1 ^ t1_1;
wire p0_2 = Rsh_d0[2] ^ Bn0[2];
wire p1_2 = Rsh_d1[2] ^ Bn1[2];
wire g0_2, g1_2, t0_2, t1_2;
MSKand_opini2_d2 u_g_2 (
    .ina({Rsh_d1[2], Rsh_d0[2]}), .inb({Bn1[2], Bn0[2]}),
    .rnd(r[4]), .s(s[4]), .clk(clk), .out({g1_2, g0_2}));
MSKand_opini2_d2 u_t_2 (
    .ina({fc1[2], fc0[2]}), .inb({p1_2, p0_2}),
    .rnd(r[5]), .s(s[5]), .clk(clk), .out({t1_2, t0_2}));
assign fc0[3] = g0_2 ^ t0_2;
assign fc1[3] = g1_2 ^ t1_2;
wire p0_3 = Rsh_d0[3] ^ Bn0[3];
wire p1_3 = Rsh_d1[3] ^ Bn1[3];
wire g0_3, g1_3, t0_3, t1_3;
MSKand_opini2_d2 u_g_3 (
    .ina({Rsh_d1[3], Rsh_d0[3]}), .inb({Bn1[3], Bn0[3]}),
    .rnd(r[6]), .s(s[6]), .clk(clk), .out({g1_3, g0_3}));
MSKand_opini2_d2 u_t_3 (
    .ina({fc1[3], fc0[3]}), .inb({p1_3, p0_3}),
    .rnd(r[7]), .s(s[7]), .clk(clk), .out({t1_3, t0_3}));
assign fc0[4] = g0_3 ^ t0_3;
assign fc1[4] = g1_3 ^ t1_3;
wire p0_4 = Rsh_d0[4] ^ Bn0[4];
wire p1_4 = Rsh_d1[4] ^ Bn1[4];
wire g0_4, g1_4, t0_4, t1_4;
MSKand_opini2_d2 u_g_4 (
    .ina({Rsh_d1[4], Rsh_d0[4]}), .inb({Bn1[4], Bn0[4]}),
    .rnd(r[8]), .s(s[8]), .clk(clk), .out({g1_4, g0_4}));
MSKand_opini2_d2 u_t_4 (
    .ina({fc1[4], fc0[4]}), .inb({p1_4, p0_4}),
    .rnd(r[9]), .s(s[9]), .clk(clk), .out({t1_4, t0_4}));
assign fc0[5] = g0_4 ^ t0_4;
assign fc1[5] = g1_4 ^ t1_4;
wire p0_5 = Rsh_d0[5] ^ Bn0[5];
wire p1_5 = Rsh_d1[5] ^ Bn1[5];
wire g0_5, g1_5, t0_5, t1_5;
MSKand_opini2_d2 u_g_5 (
    .ina({Rsh_d1[5], Rsh_d0[5]}), .inb({Bn1[5], Bn0[5]}),
    .rnd(r[10]), .s(s[10]), .clk(clk), .out({g1_5, g0_5}));
MSKand_opini2_d2 u_t_5 (
    .ina({fc1[5], fc0[5]}), .inb({p1_5, p0_5}),
    .rnd(r[11]), .s(s[11]), .clk(clk), .out({t1_5, t0_5}));
assign fc0[6] = g0_5 ^ t0_5;
assign fc1[6] = g1_5 ^ t1_5;
wire p0_6 = Rsh_d0[6] ^ Bn0[6];
wire p1_6 = Rsh_d1[6] ^ Bn1[6];
wire g0_6, g1_6, t0_6, t1_6;
MSKand_opini2_d2 u_g_6 (
    .ina({Rsh_d1[6], Rsh_d0[6]}), .inb({Bn1[6], Bn0[6]}),
    .rnd(r[12]), .s(s[12]), .clk(clk), .out({g1_6, g0_6}));
MSKand_opini2_d2 u_t_6 (
    .ina({fc1[6], fc0[6]}), .inb({p1_6, p0_6}),
    .rnd(r[13]), .s(s[13]), .clk(clk), .out({t1_6, t0_6}));
assign fc0[7] = g0_6 ^ t0_6;
assign fc1[7] = g1_6 ^ t1_6;
wire p0_7 = Rsh_d0[7] ^ Bn0[7];
wire p1_7 = Rsh_d1[7] ^ Bn1[7];
wire g0_7, g1_7, t0_7, t1_7;
MSKand_opini2_d2 u_g_7 (
    .ina({Rsh_d1[7], Rsh_d0[7]}), .inb({Bn1[7], Bn0[7]}),
    .rnd(r[14]), .s(s[14]), .clk(clk), .out({g1_7, g0_7}));
MSKand_opini2_d2 u_t_7 (
    .ina({fc1[7], fc0[7]}), .inb({p1_7, p0_7}),
    .rnd(r[15]), .s(s[15]), .clk(clk), .out({t1_7, t0_7}));
assign fc0[8] = g0_7 ^ t0_7;
assign fc1[8] = g1_7 ^ t1_7;
wire p0_8 = Rsh_d0[8] ^ Bn0[8];
wire p1_8 = Rsh_d1[8] ^ Bn1[8];
wire g0_8, g1_8, t0_8, t1_8;
MSKand_opini2_d2 u_g_8 (
    .ina({Rsh_d1[8], Rsh_d0[8]}), .inb({Bn1[8], Bn0[8]}),
    .rnd(r[16]), .s(s[16]), .clk(clk), .out({g1_8, g0_8}));
MSKand_opini2_d2 u_t_8 (
    .ina({fc1[8], fc0[8]}), .inb({p1_8, p0_8}),
    .rnd(r[17]), .s(s[17]), .clk(clk), .out({t1_8, t0_8}));
assign fc0[9] = g0_8 ^ t0_8;
assign fc1[9] = g1_8 ^ t1_8;
wire p0_9 = Rsh_d0[9] ^ Bn0[9];
wire p1_9 = Rsh_d1[9] ^ Bn1[9];
wire g0_9, g1_9, t0_9, t1_9;
MSKand_opini2_d2 u_g_9 (
    .ina({Rsh_d1[9], Rsh_d0[9]}), .inb({Bn1[9], Bn0[9]}),
    .rnd(r[18]), .s(s[18]), .clk(clk), .out({g1_9, g0_9}));
MSKand_opini2_d2 u_t_9 (
    .ina({fc1[9], fc0[9]}), .inb({p1_9, p0_9}),
    .rnd(r[19]), .s(s[19]), .clk(clk), .out({t1_9, t0_9}));
assign fc0[10] = g0_9 ^ t0_9;
assign fc1[10] = g1_9 ^ t1_9;
wire p0_10 = Rsh_d0[10] ^ Bn0[10];
wire p1_10 = Rsh_d1[10] ^ Bn1[10];
wire g0_10, g1_10, t0_10, t1_10;
MSKand_opini2_d2 u_g_10 (
    .ina({Rsh_d1[10], Rsh_d0[10]}), .inb({Bn1[10], Bn0[10]}),
    .rnd(r[20]), .s(s[20]), .clk(clk), .out({g1_10, g0_10}));
MSKand_opini2_d2 u_t_10 (
    .ina({fc1[10], fc0[10]}), .inb({p1_10, p0_10}),
    .rnd(r[21]), .s(s[21]), .clk(clk), .out({t1_10, t0_10}));
assign fc0[11] = g0_10 ^ t0_10;
assign fc1[11] = g1_10 ^ t1_10;
wire p0_11 = Rsh_d0[11] ^ Bn0[11];
wire p1_11 = Rsh_d1[11] ^ Bn1[11];
wire g0_11, g1_11, t0_11, t1_11;
MSKand_opini2_d2 u_g_11 (
    .ina({Rsh_d1[11], Rsh_d0[11]}), .inb({Bn1[11], Bn0[11]}),
    .rnd(r[22]), .s(s[22]), .clk(clk), .out({g1_11, g0_11}));
MSKand_opini2_d2 u_t_11 (
    .ina({fc1[11], fc0[11]}), .inb({p1_11, p0_11}),
    .rnd(r[23]), .s(s[23]), .clk(clk), .out({t1_11, t0_11}));
assign fc0[12] = g0_11 ^ t0_11;
assign fc1[12] = g1_11 ^ t1_11;
wire p0_12 = Rsh_d0[12] ^ Bn0[12];
wire p1_12 = Rsh_d1[12] ^ Bn1[12];
wire g0_12, g1_12, t0_12, t1_12;
MSKand_opini2_d2 u_g_12 (
    .ina({Rsh_d1[12], Rsh_d0[12]}), .inb({Bn1[12], Bn0[12]}),
    .rnd(r[24]), .s(s[24]), .clk(clk), .out({g1_12, g0_12}));
MSKand_opini2_d2 u_t_12 (
    .ina({fc1[12], fc0[12]}), .inb({p1_12, p0_12}),
    .rnd(r[25]), .s(s[25]), .clk(clk), .out({t1_12, t0_12}));
assign fc0[13] = g0_12 ^ t0_12;
assign fc1[13] = g1_12 ^ t1_12;
wire p0_13 = Rsh_d0[13] ^ Bn0[13];
wire p1_13 = Rsh_d1[13] ^ Bn1[13];
wire g0_13, g1_13, t0_13, t1_13;
MSKand_opini2_d2 u_g_13 (
    .ina({Rsh_d1[13], Rsh_d0[13]}), .inb({Bn1[13], Bn0[13]}),
    .rnd(r[26]), .s(s[26]), .clk(clk), .out({g1_13, g0_13}));
MSKand_opini2_d2 u_t_13 (
    .ina({fc1[13], fc0[13]}), .inb({p1_13, p0_13}),
    .rnd(r[27]), .s(s[27]), .clk(clk), .out({t1_13, t0_13}));
assign fc0[14] = g0_13 ^ t0_13;
assign fc1[14] = g1_13 ^ t1_13;
wire p0_14 = Rsh_d0[14] ^ Bn0[14];
wire p1_14 = Rsh_d1[14] ^ Bn1[14];
wire g0_14, g1_14, t0_14, t1_14;
MSKand_opini2_d2 u_g_14 (
    .ina({Rsh_d1[14], Rsh_d0[14]}), .inb({Bn1[14], Bn0[14]}),
    .rnd(r[28]), .s(s[28]), .clk(clk), .out({g1_14, g0_14}));
MSKand_opini2_d2 u_t_14 (
    .ina({fc1[14], fc0[14]}), .inb({p1_14, p0_14}),
    .rnd(r[29]), .s(s[29]), .clk(clk), .out({t1_14, t0_14}));
assign fc0[15] = g0_14 ^ t0_14;
assign fc1[15] = g1_14 ^ t1_14;
wire p0_15 = Rsh_d0[15] ^ Bn0[15];
wire p1_15 = Rsh_d1[15] ^ Bn1[15];
wire g0_15, g1_15, t0_15, t1_15;
MSKand_opini2_d2 u_g_15 (
    .ina({Rsh_d1[15], Rsh_d0[15]}), .inb({Bn1[15], Bn0[15]}),
    .rnd(r[30]), .s(s[30]), .clk(clk), .out({g1_15, g0_15}));
MSKand_opini2_d2 u_t_15 (
    .ina({fc1[15], fc0[15]}), .inb({p1_15, p0_15}),
    .rnd(r[31]), .s(s[31]), .clk(clk), .out({t1_15, t0_15}));
assign fc0[16] = g0_15 ^ t0_15;
assign fc1[16] = g1_15 ^ t1_15;
wire p0_16 = Rsh_d0[16] ^ 1'b1;
wire p1_16 = Rsh_d1[16] ^ 1'b0;
wire g0_16, g1_16, t0_16, t1_16;
MSKand_opini2_d2 u_g_16 (
    .ina({Rsh_d1[16], Rsh_d0[16]}), .inb({1'b0, 1'b1}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({g1_16, g0_16}));
MSKand_opini2_d2 u_t_16 (
    .ina({fc1[16], fc0[16]}), .inb({p1_16, p0_16}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({t1_16, t0_16}));
assign coutw0 = g0_16 ^ t0_16;
assign coutw1 = g1_16 ^ t1_16;
// difference bits (only [15:0] needed: both R' branches are < B < 2^16)
assign T0[0] = p0_0 ^ fc0[0];  assign T1[0] = p1_0 ^ fc1[0];
assign T0[1] = p0_1 ^ fc0[1];  assign T1[1] = p1_1 ^ fc1[1];
assign T0[2] = p0_2 ^ fc0[2];  assign T1[2] = p1_2 ^ fc1[2];
assign T0[3] = p0_3 ^ fc0[3];  assign T1[3] = p1_3 ^ fc1[3];
assign T0[4] = p0_4 ^ fc0[4];  assign T1[4] = p1_4 ^ fc1[4];
assign T0[5] = p0_5 ^ fc0[5];  assign T1[5] = p1_5 ^ fc1[5];
assign T0[6] = p0_6 ^ fc0[6];  assign T1[6] = p1_6 ^ fc1[6];
assign T0[7] = p0_7 ^ fc0[7];  assign T1[7] = p1_7 ^ fc1[7];
assign T0[8] = p0_8 ^ fc0[8];  assign T1[8] = p1_8 ^ fc1[8];
assign T0[9] = p0_9 ^ fc0[9];  assign T1[9] = p1_9 ^ fc1[9];
assign T0[10] = p0_10 ^ fc0[10];  assign T1[10] = p1_10 ^ fc1[10];
assign T0[11] = p0_11 ^ fc0[11];  assign T1[11] = p1_11 ^ fc1[11];
assign T0[12] = p0_12 ^ fc0[12];  assign T1[12] = p1_12 ^ fc1[12];
assign T0[13] = p0_13 ^ fc0[13];  assign T1[13] = p1_13 ^ fc1[13];
assign T0[14] = p0_14 ^ fc0[14];  assign T1[14] = p1_14 ^ fc1[14];
assign T0[15] = p0_15 ^ fc0[15];  assign T1[15] = p1_15 ^ fc1[15];

// ===== borrow-mux: w_m[j] = coutr AND xm[j]  (coutr broadcast to both shares) =====
MSKand_opini2_d2 u_m_0 (
    .ina({xm_d1[0], xm_d0[0]}), .inb({coutr1, coutr0}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({w_m1[0], w_m0[0]}));
MSKand_opini2_d2 u_m_1 (
    .ina({xm_d1[1], xm_d0[1]}), .inb({coutr1, coutr0}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({w_m1[1], w_m0[1]}));
MSKand_opini2_d2 u_m_2 (
    .ina({xm_d1[2], xm_d0[2]}), .inb({coutr1, coutr0}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({w_m1[2], w_m0[2]}));
MSKand_opini2_d2 u_m_3 (
    .ina({xm_d1[3], xm_d0[3]}), .inb({coutr1, coutr0}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({w_m1[3], w_m0[3]}));
MSKand_opini2_d2 u_m_4 (
    .ina({xm_d1[4], xm_d0[4]}), .inb({coutr1, coutr0}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({w_m1[4], w_m0[4]}));
MSKand_opini2_d2 u_m_5 (
    .ina({xm_d1[5], xm_d0[5]}), .inb({coutr1, coutr0}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({w_m1[5], w_m0[5]}));
MSKand_opini2_d2 u_m_6 (
    .ina({xm_d1[6], xm_d0[6]}), .inb({coutr1, coutr0}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({w_m1[6], w_m0[6]}));
MSKand_opini2_d2 u_m_7 (
    .ina({xm_d1[7], xm_d0[7]}), .inb({coutr1, coutr0}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({w_m1[7], w_m0[7]}));
MSKand_opini2_d2 u_m_8 (
    .ina({xm_d1[8], xm_d0[8]}), .inb({coutr1, coutr0}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({w_m1[8], w_m0[8]}));
MSKand_opini2_d2 u_m_9 (
    .ina({xm_d1[9], xm_d0[9]}), .inb({coutr1, coutr0}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({w_m1[9], w_m0[9]}));
MSKand_opini2_d2 u_m_10 (
    .ina({xm_d1[10], xm_d0[10]}), .inb({coutr1, coutr0}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({w_m1[10], w_m0[10]}));
MSKand_opini2_d2 u_m_11 (
    .ina({xm_d1[11], xm_d0[11]}), .inb({coutr1, coutr0}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({w_m1[11], w_m0[11]}));
MSKand_opini2_d2 u_m_12 (
    .ina({xm_d1[12], xm_d0[12]}), .inb({coutr1, coutr0}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({w_m1[12], w_m0[12]}));
MSKand_opini2_d2 u_m_13 (
    .ina({xm_d1[13], xm_d0[13]}), .inb({coutr1, coutr0}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({w_m1[13], w_m0[13]}));
MSKand_opini2_d2 u_m_14 (
    .ina({xm_d1[14], xm_d0[14]}), .inb({coutr1, coutr0}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({w_m1[14], w_m0[14]}));
MSKand_opini2_d2 u_m_15 (
    .ina({xm_d1[15], xm_d0[15]}), .inb({coutr1, coutr0}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({w_m1[15], w_m0[15]}));

// ===== nonzero-tree OR-reduce level 0: 16 masked bits -> 8 =====
wire nx0_0 = Bz0[0] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_0 = Bz0[1] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_0, ina1_0;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_0 <= nx0_0;
    ina1_0 <= Bz1[0];
end
wire w0_0, w1_0;
MSKand_opini2_d2 u_or_0 (
    .ina({ina1_0, ina0_0}), .inb({Bz1[1], ny0_0}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({w1_0, w0_0}));
wire or0_0 = w0_0 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_0 = w1_0;
wire nx0_1 = Bz0[2] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_1 = Bz0[3] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_1, ina1_1;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_1 <= nx0_1;
    ina1_1 <= Bz1[2];
end
wire w0_1, w1_1;
MSKand_opini2_d2 u_or_1 (
    .ina({ina1_1, ina0_1}), .inb({Bz1[3], ny0_1}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({w1_1, w0_1}));
wire or0_1 = w0_1 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_1 = w1_1;
wire nx0_2 = Bz0[4] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_2 = Bz0[5] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_2, ina1_2;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_2 <= nx0_2;
    ina1_2 <= Bz1[4];
end
wire w0_2, w1_2;
MSKand_opini2_d2 u_or_2 (
    .ina({ina1_2, ina0_2}), .inb({Bz1[5], ny0_2}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({w1_2, w0_2}));
wire or0_2 = w0_2 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_2 = w1_2;
wire nx0_3 = Bz0[6] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_3 = Bz0[7] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_3, ina1_3;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_3 <= nx0_3;
    ina1_3 <= Bz1[6];
end
wire w0_3, w1_3;
MSKand_opini2_d2 u_or_3 (
    .ina({ina1_3, ina0_3}), .inb({Bz1[7], ny0_3}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({w1_3, w0_3}));
wire or0_3 = w0_3 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_3 = w1_3;
wire nx0_4 = Bz0[8] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_4 = Bz0[9] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_4, ina1_4;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_4 <= nx0_4;
    ina1_4 <= Bz1[8];
end
wire w0_4, w1_4;
MSKand_opini2_d2 u_or_4 (
    .ina({ina1_4, ina0_4}), .inb({Bz1[9], ny0_4}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({w1_4, w0_4}));
wire or0_4 = w0_4 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_4 = w1_4;
wire nx0_5 = Bz0[10] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_5 = Bz0[11] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_5, ina1_5;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_5 <= nx0_5;
    ina1_5 <= Bz1[10];
end
wire w0_5, w1_5;
MSKand_opini2_d2 u_or_5 (
    .ina({ina1_5, ina0_5}), .inb({Bz1[11], ny0_5}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({w1_5, w0_5}));
wire or0_5 = w0_5 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_5 = w1_5;
wire nx0_6 = Bz0[12] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_6 = Bz0[13] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_6, ina1_6;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_6 <= nx0_6;
    ina1_6 <= Bz1[12];
end
wire w0_6, w1_6;
MSKand_opini2_d2 u_or_6 (
    .ina({ina1_6, ina0_6}), .inb({Bz1[13], ny0_6}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({w1_6, w0_6}));
wire or0_6 = w0_6 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_6 = w1_6;
wire nx0_7 = Bz0[14] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_7 = Bz0[15] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_7, ina1_7;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_7 <= nx0_7;
    ina1_7 <= Bz1[14];
end
wire w0_7, w1_7;
MSKand_opini2_d2 u_or_7 (
    .ina({ina1_7, ina0_7}), .inb({Bz1[15], ny0_7}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({w1_7, w0_7}));
wire or0_7 = w0_7 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_7 = w1_7;

// ===== nonzero-tree OR-reduce level 1: 8 masked bits -> 4 =====
wire nx0_8 = or0_0 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_8 = or0_1 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_8, ina1_8;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_8 <= nx0_8;
    ina1_8 <= or1_0;
end
wire w0_8, w1_8;
MSKand_opini2_d2 u_or_8 (
    .ina({ina1_8, ina0_8}), .inb({or1_1, ny0_8}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({w1_8, w0_8}));
wire or0_8 = w0_8 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_8 = w1_8;
wire nx0_9 = or0_2 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_9 = or0_3 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_9, ina1_9;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_9 <= nx0_9;
    ina1_9 <= or1_2;
end
wire w0_9, w1_9;
MSKand_opini2_d2 u_or_9 (
    .ina({ina1_9, ina0_9}), .inb({or1_3, ny0_9}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({w1_9, w0_9}));
wire or0_9 = w0_9 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_9 = w1_9;
wire nx0_10 = or0_4 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_10 = or0_5 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_10, ina1_10;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_10 <= nx0_10;
    ina1_10 <= or1_4;
end
wire w0_10, w1_10;
MSKand_opini2_d2 u_or_10 (
    .ina({ina1_10, ina0_10}), .inb({or1_5, ny0_10}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({w1_10, w0_10}));
wire or0_10 = w0_10 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_10 = w1_10;
wire nx0_11 = or0_6 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_11 = or0_7 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_11, ina1_11;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_11 <= nx0_11;
    ina1_11 <= or1_6;
end
wire w0_11, w1_11;
MSKand_opini2_d2 u_or_11 (
    .ina({ina1_11, ina0_11}), .inb({or1_7, ny0_11}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({w1_11, w0_11}));
wire or0_11 = w0_11 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_11 = w1_11;

// ===== nonzero-tree OR-reduce level 2: 4 masked bits -> 2 =====
wire nx0_12 = or0_8 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_12 = or0_9 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_12, ina1_12;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_12 <= nx0_12;
    ina1_12 <= or1_8;
end
wire w0_12, w1_12;
MSKand_opini2_d2 u_or_12 (
    .ina({ina1_12, ina0_12}), .inb({or1_9, ny0_12}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({w1_12, w0_12}));
wire or0_12 = w0_12 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_12 = w1_12;
wire nx0_13 = or0_10 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_13 = or0_11 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_13, ina1_13;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_13 <= nx0_13;
    ina1_13 <= or1_10;
end
wire w0_13, w1_13;
MSKand_opini2_d2 u_or_13 (
    .ina({ina1_13, ina0_13}), .inb({or1_11, ny0_13}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({w1_13, w0_13}));
wire or0_13 = w0_13 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_13 = w1_13;

// ===== nonzero-tree OR-reduce level 3: 2 masked bits -> 1 =====
wire nx0_14 = or0_12 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_14 = or0_13 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_14, ina1_14;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_14 <= nx0_14;
    ina1_14 <= or1_12;
end
wire w0_14, w1_14;
MSKand_opini2_d2 u_or_14 (
    .ina({ina1_14, ina0_14}), .inb({or1_13, ny0_14}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({w1_14, w0_14}));
wire or0_14 = w0_14 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_14 = w1_14;

// tree root = OR-reduce(B) = (B != 0) — exactly the gate NOT(ISZERO(B))
assign nz0 = or0_14;
assign nz1 = or1_14;

// ===== EVM zero-gating: qe[j] = Q[j] AND (B!=0), reme[j] = R[j] AND (B!=0) =====
wire wq0_0, wq1_0;
MSKand_opini2_d2 u_gq_0 (
    .ina({q_d1[0], q_d0[0]}), .inb({nzr1, nzr0}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({wq1_0, wq0_0}));
assign qe[0] = wq0_0;  assign qe[1] = wq1_0;
wire wq0_1, wq1_1;
MSKand_opini2_d2 u_gq_1 (  // BUG UNDER TEST: reuses u_gq_0's randomness
    .ina({q_d1[1], q_d0[1]}), .inb({nzr1, nzr0}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({wq1_1, wq0_1}));
assign qe[2] = wq0_1;  assign qe[3] = wq1_1;
wire wq0_2, wq1_2;
MSKand_opini2_d2 u_gq_2 (
    .ina({q_d1[2], q_d0[2]}), .inb({nzr1, nzr0}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({wq1_2, wq0_2}));
assign qe[4] = wq0_2;  assign qe[5] = wq1_2;
wire wq0_3, wq1_3;
MSKand_opini2_d2 u_gq_3 (
    .ina({q_d1[3], q_d0[3]}), .inb({nzr1, nzr0}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({wq1_3, wq0_3}));
assign qe[6] = wq0_3;  assign qe[7] = wq1_3;
wire wq0_4, wq1_4;
MSKand_opini2_d2 u_gq_4 (
    .ina({q_d1[4], q_d0[4]}), .inb({nzr1, nzr0}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({wq1_4, wq0_4}));
assign qe[8] = wq0_4;  assign qe[9] = wq1_4;
wire wq0_5, wq1_5;
MSKand_opini2_d2 u_gq_5 (
    .ina({q_d1[5], q_d0[5]}), .inb({nzr1, nzr0}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({wq1_5, wq0_5}));
assign qe[10] = wq0_5;  assign qe[11] = wq1_5;
wire wq0_6, wq1_6;
MSKand_opini2_d2 u_gq_6 (
    .ina({q_d1[6], q_d0[6]}), .inb({nzr1, nzr0}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({wq1_6, wq0_6}));
assign qe[12] = wq0_6;  assign qe[13] = wq1_6;
wire wq0_7, wq1_7;
MSKand_opini2_d2 u_gq_7 (
    .ina({q_d1[7], q_d0[7]}), .inb({nzr1, nzr0}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({wq1_7, wq0_7}));
assign qe[14] = wq0_7;  assign qe[15] = wq1_7;
wire wq0_8, wq1_8;
MSKand_opini2_d2 u_gq_8 (
    .ina({q_d1[8], q_d0[8]}), .inb({nzr1, nzr0}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({wq1_8, wq0_8}));
assign qe[16] = wq0_8;  assign qe[17] = wq1_8;
wire wq0_9, wq1_9;
MSKand_opini2_d2 u_gq_9 (
    .ina({q_d1[9], q_d0[9]}), .inb({nzr1, nzr0}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({wq1_9, wq0_9}));
assign qe[18] = wq0_9;  assign qe[19] = wq1_9;
wire wq0_10, wq1_10;
MSKand_opini2_d2 u_gq_10 (
    .ina({q_d1[10], q_d0[10]}), .inb({nzr1, nzr0}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({wq1_10, wq0_10}));
assign qe[20] = wq0_10;  assign qe[21] = wq1_10;
wire wq0_11, wq1_11;
MSKand_opini2_d2 u_gq_11 (
    .ina({q_d1[11], q_d0[11]}), .inb({nzr1, nzr0}),
    .rnd(r[76]), .s(s[76]), .clk(clk), .out({wq1_11, wq0_11}));
assign qe[22] = wq0_11;  assign qe[23] = wq1_11;
wire wq0_12, wq1_12;
MSKand_opini2_d2 u_gq_12 (
    .ina({q_d1[12], q_d0[12]}), .inb({nzr1, nzr0}),
    .rnd(r[77]), .s(s[77]), .clk(clk), .out({wq1_12, wq0_12}));
assign qe[24] = wq0_12;  assign qe[25] = wq1_12;
wire wq0_13, wq1_13;
MSKand_opini2_d2 u_gq_13 (
    .ina({q_d1[13], q_d0[13]}), .inb({nzr1, nzr0}),
    .rnd(r[78]), .s(s[78]), .clk(clk), .out({wq1_13, wq0_13}));
assign qe[26] = wq0_13;  assign qe[27] = wq1_13;
wire wq0_14, wq1_14;
MSKand_opini2_d2 u_gq_14 (
    .ina({q_d1[14], q_d0[14]}), .inb({nzr1, nzr0}),
    .rnd(r[79]), .s(s[79]), .clk(clk), .out({wq1_14, wq0_14}));
assign qe[28] = wq0_14;  assign qe[29] = wq1_14;
wire wq0_15, wq1_15;
MSKand_opini2_d2 u_gq_15 (
    .ina({q_d1[15], q_d0[15]}), .inb({nzr1, nzr0}),
    .rnd(r[80]), .s(s[80]), .clk(clk), .out({wq1_15, wq0_15}));
assign qe[30] = wq0_15;  assign qe[31] = wq1_15;
wire wr0_0, wr1_0;
MSKand_opini2_d2 u_gr_0 (
    .ina({rm_d1[0], rm_d0[0]}), .inb({nzr1, nzr0}),
    .rnd(r[81]), .s(s[81]), .clk(clk), .out({wr1_0, wr0_0}));
assign reme[0] = wr0_0;  assign reme[1] = wr1_0;
wire wr0_1, wr1_1;
MSKand_opini2_d2 u_gr_1 (
    .ina({rm_d1[1], rm_d0[1]}), .inb({nzr1, nzr0}),
    .rnd(r[82]), .s(s[82]), .clk(clk), .out({wr1_1, wr0_1}));
assign reme[2] = wr0_1;  assign reme[3] = wr1_1;
wire wr0_2, wr1_2;
MSKand_opini2_d2 u_gr_2 (
    .ina({rm_d1[2], rm_d0[2]}), .inb({nzr1, nzr0}),
    .rnd(r[83]), .s(s[83]), .clk(clk), .out({wr1_2, wr0_2}));
assign reme[4] = wr0_2;  assign reme[5] = wr1_2;
wire wr0_3, wr1_3;
MSKand_opini2_d2 u_gr_3 (
    .ina({rm_d1[3], rm_d0[3]}), .inb({nzr1, nzr0}),
    .rnd(r[84]), .s(s[84]), .clk(clk), .out({wr1_3, wr0_3}));
assign reme[6] = wr0_3;  assign reme[7] = wr1_3;
wire wr0_4, wr1_4;
MSKand_opini2_d2 u_gr_4 (
    .ina({rm_d1[4], rm_d0[4]}), .inb({nzr1, nzr0}),
    .rnd(r[85]), .s(s[85]), .clk(clk), .out({wr1_4, wr0_4}));
assign reme[8] = wr0_4;  assign reme[9] = wr1_4;
wire wr0_5, wr1_5;
MSKand_opini2_d2 u_gr_5 (
    .ina({rm_d1[5], rm_d0[5]}), .inb({nzr1, nzr0}),
    .rnd(r[86]), .s(s[86]), .clk(clk), .out({wr1_5, wr0_5}));
assign reme[10] = wr0_5;  assign reme[11] = wr1_5;
wire wr0_6, wr1_6;
MSKand_opini2_d2 u_gr_6 (
    .ina({rm_d1[6], rm_d0[6]}), .inb({nzr1, nzr0}),
    .rnd(r[87]), .s(s[87]), .clk(clk), .out({wr1_6, wr0_6}));
assign reme[12] = wr0_6;  assign reme[13] = wr1_6;
wire wr0_7, wr1_7;
MSKand_opini2_d2 u_gr_7 (
    .ina({rm_d1[7], rm_d0[7]}), .inb({nzr1, nzr0}),
    .rnd(r[88]), .s(s[88]), .clk(clk), .out({wr1_7, wr0_7}));
assign reme[14] = wr0_7;  assign reme[15] = wr1_7;
wire wr0_8, wr1_8;
MSKand_opini2_d2 u_gr_8 (
    .ina({rm_d1[8], rm_d0[8]}), .inb({nzr1, nzr0}),
    .rnd(r[89]), .s(s[89]), .clk(clk), .out({wr1_8, wr0_8}));
assign reme[16] = wr0_8;  assign reme[17] = wr1_8;
wire wr0_9, wr1_9;
MSKand_opini2_d2 u_gr_9 (
    .ina({rm_d1[9], rm_d0[9]}), .inb({nzr1, nzr0}),
    .rnd(r[90]), .s(s[90]), .clk(clk), .out({wr1_9, wr0_9}));
assign reme[18] = wr0_9;  assign reme[19] = wr1_9;
wire wr0_10, wr1_10;
MSKand_opini2_d2 u_gr_10 (
    .ina({rm_d1[10], rm_d0[10]}), .inb({nzr1, nzr0}),
    .rnd(r[91]), .s(s[91]), .clk(clk), .out({wr1_10, wr0_10}));
assign reme[20] = wr0_10;  assign reme[21] = wr1_10;
wire wr0_11, wr1_11;
MSKand_opini2_d2 u_gr_11 (
    .ina({rm_d1[11], rm_d0[11]}), .inb({nzr1, nzr0}),
    .rnd(r[92]), .s(s[92]), .clk(clk), .out({wr1_11, wr0_11}));
assign reme[22] = wr0_11;  assign reme[23] = wr1_11;
wire wr0_12, wr1_12;
MSKand_opini2_d2 u_gr_12 (
    .ina({rm_d1[12], rm_d0[12]}), .inb({nzr1, nzr0}),
    .rnd(r[93]), .s(s[93]), .clk(clk), .out({wr1_12, wr0_12}));
assign reme[24] = wr0_12;  assign reme[25] = wr1_12;
wire wr0_13, wr1_13;
MSKand_opini2_d2 u_gr_13 (
    .ina({rm_d1[13], rm_d0[13]}), .inb({nzr1, nzr0}),
    .rnd(r[94]), .s(s[94]), .clk(clk), .out({wr1_13, wr0_13}));
assign reme[26] = wr0_13;  assign reme[27] = wr1_13;
wire wr0_14, wr1_14;
MSKand_opini2_d2 u_gr_14 (
    .ina({rm_d1[14], rm_d0[14]}), .inb({nzr1, nzr0}),
    .rnd(r[95]), .s(s[95]), .clk(clk), .out({wr1_14, wr0_14}));
assign reme[28] = wr0_14;  assign reme[29] = wr1_14;
wire wr0_15, wr1_15;
MSKand_opini2_d2 u_gr_15 (
    .ina({rm_d1[15], rm_d0[15]}), .inb({nzr1, nzr0}),
    .rnd(r[96]), .s(s[96]), .clk(clk), .out({wr1_15, wr0_15}));
assign reme[30] = wr0_15;  assign reme[31] = wr1_15;

endmodule
