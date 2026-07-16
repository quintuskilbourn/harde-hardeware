// LABEL CONTROL: identical netlist but instantiates the PINI-relabelled
// leaf MSKand_opini2_d2_pini. This datapath REUSES gadgets bubble-free
// with feedback, the structure MATCHI's transition rule guards for PINI
// leaves (cf. ./top_chain_pini). Verdict recorded either way.
// Iterative restoring divider, q = A/B, rem = A%B (B != 0). 50 assumed-OPINI
// gadget leaves (34 subtract u_g_*/u_t_* — the verified-adder dataflow
// with sub=1 — plus 16 borrow-mux u_m_*), each with a DEDICATED r[k]/s[k]
// random bit. Every XOR/NOT/shift is strictly share-local.
// Dense sharing layout (share index fastest): port[2i]=share0, port[2i+1]=share1.
// Schedule: load @0; iteration i occupies cycles [1+48i, 48+48i]; q/rem
// (registers) stable from cycle 769; state cleared (share-local, to
// public 0) at cycle 784; randoms fresh [0,838].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module div16_pini (clk, rst, go, a, b, r, s, q, rem);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [31:0] a;
(* matchi_type = "sharings_dense", matchi_active = "b_act" *) input [31:0] b;
(* matchi_type = "random", matchi_active = "r_act" *) input [49:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [49:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [31:0] q;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [31:0] rem;

// ---- activity windows from an idempotent cycle counter (public control;
// counts 1.. from the go pulse, saturates — see generator header) ----
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

// ---- state registers (per-share; NEVER mix share 0 and share 1) ----
reg [15:0] R0, R1;            // partial remainder
reg [15:0] A0, A1;            // dividend, shifts left (public 0 in)
reg [15:0] Q0, Q1;            // quotient, shifts left (cout in)
reg [15:0] Bn0, Bn1;          // ~B, complement share-local (share 0 only)
reg [15:0] Treg0, Treg1;      // registered subtract result (settled)
reg coutr0, coutr1;              // registered carry-out = quotient bit
wire [16:0] Rsh0 = {R0, A0[15]};   // Rsh = R<<1 | msb(A), per share
wire [16:0] Rsh1 = {R1, A1[15]};
wire [15:0] w_m0, w_m1;       // borrow-mux gadget outputs
// (* keep *): T/coutw feed only register inputs; without keep, abc absorbs
// their XOR drivers into the register cone and MATCHI hits a driverless wire.
(* keep *) wire [15:0] T0, T1;   // subtract difference bits (settled by M1)
(* keep *) wire coutw0, coutw1;     // subtract carry-out = NOT borrow

always @(posedge clk) begin
    if (rst || clr) begin
        R0 <= 0; R1 <= 0; A0 <= 0; A1 <= 0; Q0 <= 0; Q1 <= 0;
        Bn0 <= 0; Bn1 <= 0; Treg0 <= 0; Treg1 <= 0; coutr0 <= 0; coutr1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        A0 <= {a[30], a[28], a[26], a[24], a[22], a[20], a[18], a[16], a[14], a[12], a[10], a[8], a[6], a[4], a[2], a[0]};
        A1 <= {a[31], a[29], a[27], a[25], a[23], a[21], a[19], a[17], a[15], a[13], a[11], a[9], a[7], a[5], a[3], a[1]};
        Bn0 <= ~{b[30], b[28], b[26], b[24], b[22], b[20], b[18], b[16], b[14], b[12], b[10], b[8], b[6], b[4], b[2], b[0]};   // share-local NOT: complement share 0
        Bn1 <= {b[31], b[29], b[27], b[25], b[23], b[21], b[19], b[17], b[15], b[13], b[11], b[9], b[7], b[5], b[3], b[1]};    // share 1 untouched
        R0 <= 0; R1 <= 0; Q0 <= 0; Q1 <= 0;
        Treg0 <= 0; Treg1 <= 0; coutr0 <= 0; coutr1 <= 0;
    end else if (running) begin
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
end

// ---- 1-cycle per-share balance registers: every gadget ina arrives one
// cycle after its inb (gadget contract ina@1/inb@0 — the iszero256 pattern).
// Unconditional, so they drain by themselves one cycle after clr.
reg [16:0] Rsh_d0, Rsh_d1;      // ina of u_g_*  (inb = Bn)
reg [15:0] xm_d0, xm_d1;      // ina of u_m_*  (inb = coutr); xm = Rsh^Treg
always @(posedge clk) begin
    Rsh_d0 <= Rsh0;                       Rsh_d1 <= Rsh1;
    xm_d0  <= Rsh0[15:0] ^ Treg0;      xm_d1  <= Rsh1[15:0] ^ Treg1;
end

// ---- outputs: dense re-pack of the Q/R registers (share-local wiring) ----

assign q[0] = Q0[0];  assign q[1] = Q1[0];  assign rem[0] = R0[0];  assign rem[1] = R1[0];
assign q[2] = Q0[1];  assign q[3] = Q1[1];  assign rem[2] = R0[1];  assign rem[3] = R1[1];
assign q[4] = Q0[2];  assign q[5] = Q1[2];  assign rem[4] = R0[2];  assign rem[5] = R1[2];
assign q[6] = Q0[3];  assign q[7] = Q1[3];  assign rem[6] = R0[3];  assign rem[7] = R1[3];
assign q[8] = Q0[4];  assign q[9] = Q1[4];  assign rem[8] = R0[4];  assign rem[9] = R1[4];
assign q[10] = Q0[5];  assign q[11] = Q1[5];  assign rem[10] = R0[5];  assign rem[11] = R1[5];
assign q[12] = Q0[6];  assign q[13] = Q1[6];  assign rem[12] = R0[6];  assign rem[13] = R1[6];
assign q[14] = Q0[7];  assign q[15] = Q1[7];  assign rem[14] = R0[7];  assign rem[15] = R1[7];
assign q[16] = Q0[8];  assign q[17] = Q1[8];  assign rem[16] = R0[8];  assign rem[17] = R1[8];
assign q[18] = Q0[9];  assign q[19] = Q1[9];  assign rem[18] = R0[9];  assign rem[19] = R1[9];
assign q[20] = Q0[10];  assign q[21] = Q1[10];  assign rem[20] = R0[10];  assign rem[21] = R1[10];
assign q[22] = Q0[11];  assign q[23] = Q1[11];  assign rem[22] = R0[11];  assign rem[23] = R1[11];
assign q[24] = Q0[12];  assign q[25] = Q1[12];  assign rem[24] = R0[12];  assign rem[25] = R1[12];
assign q[26] = Q0[13];  assign q[27] = Q1[13];  assign rem[26] = R0[13];  assign rem[27] = R1[13];
assign q[28] = Q0[14];  assign q[29] = Q1[14];  assign rem[28] = R0[14];  assign rem[29] = R1[14];
assign q[30] = Q0[15];  assign q[31] = Q1[15];  assign rem[30] = R0[15];  assign rem[31] = R1[15];

// ===== (N+1)-bit ripple subtract: T = Rsh + ~B + 1 (verified-adder dataflow, sub=1) =====
// fc[0] = carry-in = public 1 (share pair (1,0)); Bn bit 16 = ~0 = public 1.
wire [16:0] fc0, fc1;
assign fc0[0] = 1'b1;
assign fc1[0] = 1'b0;
wire p0_0 = Rsh_d0[0] ^ Bn0[0];
wire p1_0 = Rsh_d1[0] ^ Bn1[0];
wire g0_0, g1_0, t0_0, t1_0;
MSKand_opini2_d2_pini u_g_0 (
    .ina({Rsh_d1[0], Rsh_d0[0]}), .inb({Bn1[0], Bn0[0]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({g1_0, g0_0}));
MSKand_opini2_d2_pini u_t_0 (
    .ina({fc1[0], fc0[0]}), .inb({p1_0, p0_0}),
    .rnd(r[1]), .s(s[1]), .clk(clk), .out({t1_0, t0_0}));
assign fc0[1] = g0_0 ^ t0_0;
assign fc1[1] = g1_0 ^ t1_0;
wire p0_1 = Rsh_d0[1] ^ Bn0[1];
wire p1_1 = Rsh_d1[1] ^ Bn1[1];
wire g0_1, g1_1, t0_1, t1_1;
MSKand_opini2_d2_pini u_g_1 (
    .ina({Rsh_d1[1], Rsh_d0[1]}), .inb({Bn1[1], Bn0[1]}),
    .rnd(r[2]), .s(s[2]), .clk(clk), .out({g1_1, g0_1}));
MSKand_opini2_d2_pini u_t_1 (
    .ina({fc1[1], fc0[1]}), .inb({p1_1, p0_1}),
    .rnd(r[3]), .s(s[3]), .clk(clk), .out({t1_1, t0_1}));
assign fc0[2] = g0_1 ^ t0_1;
assign fc1[2] = g1_1 ^ t1_1;
wire p0_2 = Rsh_d0[2] ^ Bn0[2];
wire p1_2 = Rsh_d1[2] ^ Bn1[2];
wire g0_2, g1_2, t0_2, t1_2;
MSKand_opini2_d2_pini u_g_2 (
    .ina({Rsh_d1[2], Rsh_d0[2]}), .inb({Bn1[2], Bn0[2]}),
    .rnd(r[4]), .s(s[4]), .clk(clk), .out({g1_2, g0_2}));
MSKand_opini2_d2_pini u_t_2 (
    .ina({fc1[2], fc0[2]}), .inb({p1_2, p0_2}),
    .rnd(r[5]), .s(s[5]), .clk(clk), .out({t1_2, t0_2}));
assign fc0[3] = g0_2 ^ t0_2;
assign fc1[3] = g1_2 ^ t1_2;
wire p0_3 = Rsh_d0[3] ^ Bn0[3];
wire p1_3 = Rsh_d1[3] ^ Bn1[3];
wire g0_3, g1_3, t0_3, t1_3;
MSKand_opini2_d2_pini u_g_3 (
    .ina({Rsh_d1[3], Rsh_d0[3]}), .inb({Bn1[3], Bn0[3]}),
    .rnd(r[6]), .s(s[6]), .clk(clk), .out({g1_3, g0_3}));
MSKand_opini2_d2_pini u_t_3 (
    .ina({fc1[3], fc0[3]}), .inb({p1_3, p0_3}),
    .rnd(r[7]), .s(s[7]), .clk(clk), .out({t1_3, t0_3}));
assign fc0[4] = g0_3 ^ t0_3;
assign fc1[4] = g1_3 ^ t1_3;
wire p0_4 = Rsh_d0[4] ^ Bn0[4];
wire p1_4 = Rsh_d1[4] ^ Bn1[4];
wire g0_4, g1_4, t0_4, t1_4;
MSKand_opini2_d2_pini u_g_4 (
    .ina({Rsh_d1[4], Rsh_d0[4]}), .inb({Bn1[4], Bn0[4]}),
    .rnd(r[8]), .s(s[8]), .clk(clk), .out({g1_4, g0_4}));
MSKand_opini2_d2_pini u_t_4 (
    .ina({fc1[4], fc0[4]}), .inb({p1_4, p0_4}),
    .rnd(r[9]), .s(s[9]), .clk(clk), .out({t1_4, t0_4}));
assign fc0[5] = g0_4 ^ t0_4;
assign fc1[5] = g1_4 ^ t1_4;
wire p0_5 = Rsh_d0[5] ^ Bn0[5];
wire p1_5 = Rsh_d1[5] ^ Bn1[5];
wire g0_5, g1_5, t0_5, t1_5;
MSKand_opini2_d2_pini u_g_5 (
    .ina({Rsh_d1[5], Rsh_d0[5]}), .inb({Bn1[5], Bn0[5]}),
    .rnd(r[10]), .s(s[10]), .clk(clk), .out({g1_5, g0_5}));
MSKand_opini2_d2_pini u_t_5 (
    .ina({fc1[5], fc0[5]}), .inb({p1_5, p0_5}),
    .rnd(r[11]), .s(s[11]), .clk(clk), .out({t1_5, t0_5}));
assign fc0[6] = g0_5 ^ t0_5;
assign fc1[6] = g1_5 ^ t1_5;
wire p0_6 = Rsh_d0[6] ^ Bn0[6];
wire p1_6 = Rsh_d1[6] ^ Bn1[6];
wire g0_6, g1_6, t0_6, t1_6;
MSKand_opini2_d2_pini u_g_6 (
    .ina({Rsh_d1[6], Rsh_d0[6]}), .inb({Bn1[6], Bn0[6]}),
    .rnd(r[12]), .s(s[12]), .clk(clk), .out({g1_6, g0_6}));
MSKand_opini2_d2_pini u_t_6 (
    .ina({fc1[6], fc0[6]}), .inb({p1_6, p0_6}),
    .rnd(r[13]), .s(s[13]), .clk(clk), .out({t1_6, t0_6}));
assign fc0[7] = g0_6 ^ t0_6;
assign fc1[7] = g1_6 ^ t1_6;
wire p0_7 = Rsh_d0[7] ^ Bn0[7];
wire p1_7 = Rsh_d1[7] ^ Bn1[7];
wire g0_7, g1_7, t0_7, t1_7;
MSKand_opini2_d2_pini u_g_7 (
    .ina({Rsh_d1[7], Rsh_d0[7]}), .inb({Bn1[7], Bn0[7]}),
    .rnd(r[14]), .s(s[14]), .clk(clk), .out({g1_7, g0_7}));
MSKand_opini2_d2_pini u_t_7 (
    .ina({fc1[7], fc0[7]}), .inb({p1_7, p0_7}),
    .rnd(r[15]), .s(s[15]), .clk(clk), .out({t1_7, t0_7}));
assign fc0[8] = g0_7 ^ t0_7;
assign fc1[8] = g1_7 ^ t1_7;
wire p0_8 = Rsh_d0[8] ^ Bn0[8];
wire p1_8 = Rsh_d1[8] ^ Bn1[8];
wire g0_8, g1_8, t0_8, t1_8;
MSKand_opini2_d2_pini u_g_8 (
    .ina({Rsh_d1[8], Rsh_d0[8]}), .inb({Bn1[8], Bn0[8]}),
    .rnd(r[16]), .s(s[16]), .clk(clk), .out({g1_8, g0_8}));
MSKand_opini2_d2_pini u_t_8 (
    .ina({fc1[8], fc0[8]}), .inb({p1_8, p0_8}),
    .rnd(r[17]), .s(s[17]), .clk(clk), .out({t1_8, t0_8}));
assign fc0[9] = g0_8 ^ t0_8;
assign fc1[9] = g1_8 ^ t1_8;
wire p0_9 = Rsh_d0[9] ^ Bn0[9];
wire p1_9 = Rsh_d1[9] ^ Bn1[9];
wire g0_9, g1_9, t0_9, t1_9;
MSKand_opini2_d2_pini u_g_9 (
    .ina({Rsh_d1[9], Rsh_d0[9]}), .inb({Bn1[9], Bn0[9]}),
    .rnd(r[18]), .s(s[18]), .clk(clk), .out({g1_9, g0_9}));
MSKand_opini2_d2_pini u_t_9 (
    .ina({fc1[9], fc0[9]}), .inb({p1_9, p0_9}),
    .rnd(r[19]), .s(s[19]), .clk(clk), .out({t1_9, t0_9}));
assign fc0[10] = g0_9 ^ t0_9;
assign fc1[10] = g1_9 ^ t1_9;
wire p0_10 = Rsh_d0[10] ^ Bn0[10];
wire p1_10 = Rsh_d1[10] ^ Bn1[10];
wire g0_10, g1_10, t0_10, t1_10;
MSKand_opini2_d2_pini u_g_10 (
    .ina({Rsh_d1[10], Rsh_d0[10]}), .inb({Bn1[10], Bn0[10]}),
    .rnd(r[20]), .s(s[20]), .clk(clk), .out({g1_10, g0_10}));
MSKand_opini2_d2_pini u_t_10 (
    .ina({fc1[10], fc0[10]}), .inb({p1_10, p0_10}),
    .rnd(r[21]), .s(s[21]), .clk(clk), .out({t1_10, t0_10}));
assign fc0[11] = g0_10 ^ t0_10;
assign fc1[11] = g1_10 ^ t1_10;
wire p0_11 = Rsh_d0[11] ^ Bn0[11];
wire p1_11 = Rsh_d1[11] ^ Bn1[11];
wire g0_11, g1_11, t0_11, t1_11;
MSKand_opini2_d2_pini u_g_11 (
    .ina({Rsh_d1[11], Rsh_d0[11]}), .inb({Bn1[11], Bn0[11]}),
    .rnd(r[22]), .s(s[22]), .clk(clk), .out({g1_11, g0_11}));
MSKand_opini2_d2_pini u_t_11 (
    .ina({fc1[11], fc0[11]}), .inb({p1_11, p0_11}),
    .rnd(r[23]), .s(s[23]), .clk(clk), .out({t1_11, t0_11}));
assign fc0[12] = g0_11 ^ t0_11;
assign fc1[12] = g1_11 ^ t1_11;
wire p0_12 = Rsh_d0[12] ^ Bn0[12];
wire p1_12 = Rsh_d1[12] ^ Bn1[12];
wire g0_12, g1_12, t0_12, t1_12;
MSKand_opini2_d2_pini u_g_12 (
    .ina({Rsh_d1[12], Rsh_d0[12]}), .inb({Bn1[12], Bn0[12]}),
    .rnd(r[24]), .s(s[24]), .clk(clk), .out({g1_12, g0_12}));
MSKand_opini2_d2_pini u_t_12 (
    .ina({fc1[12], fc0[12]}), .inb({p1_12, p0_12}),
    .rnd(r[25]), .s(s[25]), .clk(clk), .out({t1_12, t0_12}));
assign fc0[13] = g0_12 ^ t0_12;
assign fc1[13] = g1_12 ^ t1_12;
wire p0_13 = Rsh_d0[13] ^ Bn0[13];
wire p1_13 = Rsh_d1[13] ^ Bn1[13];
wire g0_13, g1_13, t0_13, t1_13;
MSKand_opini2_d2_pini u_g_13 (
    .ina({Rsh_d1[13], Rsh_d0[13]}), .inb({Bn1[13], Bn0[13]}),
    .rnd(r[26]), .s(s[26]), .clk(clk), .out({g1_13, g0_13}));
MSKand_opini2_d2_pini u_t_13 (
    .ina({fc1[13], fc0[13]}), .inb({p1_13, p0_13}),
    .rnd(r[27]), .s(s[27]), .clk(clk), .out({t1_13, t0_13}));
assign fc0[14] = g0_13 ^ t0_13;
assign fc1[14] = g1_13 ^ t1_13;
wire p0_14 = Rsh_d0[14] ^ Bn0[14];
wire p1_14 = Rsh_d1[14] ^ Bn1[14];
wire g0_14, g1_14, t0_14, t1_14;
MSKand_opini2_d2_pini u_g_14 (
    .ina({Rsh_d1[14], Rsh_d0[14]}), .inb({Bn1[14], Bn0[14]}),
    .rnd(r[28]), .s(s[28]), .clk(clk), .out({g1_14, g0_14}));
MSKand_opini2_d2_pini u_t_14 (
    .ina({fc1[14], fc0[14]}), .inb({p1_14, p0_14}),
    .rnd(r[29]), .s(s[29]), .clk(clk), .out({t1_14, t0_14}));
assign fc0[15] = g0_14 ^ t0_14;
assign fc1[15] = g1_14 ^ t1_14;
wire p0_15 = Rsh_d0[15] ^ Bn0[15];
wire p1_15 = Rsh_d1[15] ^ Bn1[15];
wire g0_15, g1_15, t0_15, t1_15;
MSKand_opini2_d2_pini u_g_15 (
    .ina({Rsh_d1[15], Rsh_d0[15]}), .inb({Bn1[15], Bn0[15]}),
    .rnd(r[30]), .s(s[30]), .clk(clk), .out({g1_15, g0_15}));
MSKand_opini2_d2_pini u_t_15 (
    .ina({fc1[15], fc0[15]}), .inb({p1_15, p0_15}),
    .rnd(r[31]), .s(s[31]), .clk(clk), .out({t1_15, t0_15}));
assign fc0[16] = g0_15 ^ t0_15;
assign fc1[16] = g1_15 ^ t1_15;
wire p0_16 = Rsh_d0[16] ^ 1'b1;
wire p1_16 = Rsh_d1[16] ^ 1'b0;
wire g0_16, g1_16, t0_16, t1_16;
MSKand_opini2_d2_pini u_g_16 (
    .ina({Rsh_d1[16], Rsh_d0[16]}), .inb({1'b0, 1'b1}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({g1_16, g0_16}));
MSKand_opini2_d2_pini u_t_16 (
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
MSKand_opini2_d2_pini u_m_0 (
    .ina({xm_d1[0], xm_d0[0]}), .inb({coutr1, coutr0}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({w_m1[0], w_m0[0]}));
MSKand_opini2_d2_pini u_m_1 (
    .ina({xm_d1[1], xm_d0[1]}), .inb({coutr1, coutr0}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({w_m1[1], w_m0[1]}));
MSKand_opini2_d2_pini u_m_2 (
    .ina({xm_d1[2], xm_d0[2]}), .inb({coutr1, coutr0}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({w_m1[2], w_m0[2]}));
MSKand_opini2_d2_pini u_m_3 (
    .ina({xm_d1[3], xm_d0[3]}), .inb({coutr1, coutr0}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({w_m1[3], w_m0[3]}));
MSKand_opini2_d2_pini u_m_4 (
    .ina({xm_d1[4], xm_d0[4]}), .inb({coutr1, coutr0}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({w_m1[4], w_m0[4]}));
MSKand_opini2_d2_pini u_m_5 (
    .ina({xm_d1[5], xm_d0[5]}), .inb({coutr1, coutr0}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({w_m1[5], w_m0[5]}));
MSKand_opini2_d2_pini u_m_6 (
    .ina({xm_d1[6], xm_d0[6]}), .inb({coutr1, coutr0}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({w_m1[6], w_m0[6]}));
MSKand_opini2_d2_pini u_m_7 (
    .ina({xm_d1[7], xm_d0[7]}), .inb({coutr1, coutr0}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({w_m1[7], w_m0[7]}));
MSKand_opini2_d2_pini u_m_8 (
    .ina({xm_d1[8], xm_d0[8]}), .inb({coutr1, coutr0}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({w_m1[8], w_m0[8]}));
MSKand_opini2_d2_pini u_m_9 (
    .ina({xm_d1[9], xm_d0[9]}), .inb({coutr1, coutr0}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({w_m1[9], w_m0[9]}));
MSKand_opini2_d2_pini u_m_10 (
    .ina({xm_d1[10], xm_d0[10]}), .inb({coutr1, coutr0}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({w_m1[10], w_m0[10]}));
MSKand_opini2_d2_pini u_m_11 (
    .ina({xm_d1[11], xm_d0[11]}), .inb({coutr1, coutr0}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({w_m1[11], w_m0[11]}));
MSKand_opini2_d2_pini u_m_12 (
    .ina({xm_d1[12], xm_d0[12]}), .inb({coutr1, coutr0}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({w_m1[12], w_m0[12]}));
MSKand_opini2_d2_pini u_m_13 (
    .ina({xm_d1[13], xm_d0[13]}), .inb({coutr1, coutr0}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({w_m1[13], w_m0[13]}));
MSKand_opini2_d2_pini u_m_14 (
    .ina({xm_d1[14], xm_d0[14]}), .inb({coutr1, coutr0}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({w_m1[14], w_m0[14]}));
MSKand_opini2_d2_pini u_m_15 (
    .ina({xm_d1[15], xm_d0[15]}), .inb({coutr1, coutr0}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({w_m1[15], w_m0[15]}));

endmodule
