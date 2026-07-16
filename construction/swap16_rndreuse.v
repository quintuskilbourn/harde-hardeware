// NEGATIVE CONTROL (must FAIL): identical to the target except u_dm_1
// consumes the SAME random bits as u_dm_0, active in the same cycles,
// instead of its dedicated pair. MATCHI must report multi-use.
// Constant-product swap program over the verified masked units (structural
// copies): denom=ri+x (ADD), num=ro*x (MUL), aout=num/denom (DIV), ok =
// (aout>=mo) (borrow-out compare), nro=ro-aout (SUB). 218 assumed-OPINI
// gadget leaves (76 mul u_mpp_*/u_msc_*/u_mpx_*/u_mg_*/u_mt_*, 30 denom-add
// u_ag_*/u_at_*, 50 div u_dg_*/u_dt_*/u_dm_*, 32 compare u_cg_*/u_ct_*,
// 30 reserve-sub u_sg_*/u_st_*), each with a DEDICATED r[k]/s[k] random bit
// (disjoint per-stage slices). Every XOR/NOT/shift/hand-off is strictly
// share-local; control (counter, strobes, FSMs) is public and data-independent.
// Dense sharing layout (share index fastest): port[2i]=share0, port[2i+1]=share1.
// Schedule: load @0; mul [1,128], prod captured @172; denom captured @44;
// div go @176, iteration i occupies [176+1+48i, 176+48(i+1)], Q/R stable @945;
// ok/nro captured @989; outputs valid [990,995]; global clr @995;
// randoms fresh [0,1527].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module swap16_rndreuse (clk, rst, go, x, ri, ro, mo, r, s, aout, nri, nro, ok);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "in_act" *) input [31:0] x;
(* matchi_type = "sharings_dense", matchi_active = "in_act" *) input [31:0] ri;
(* matchi_type = "sharings_dense", matchi_active = "in_act" *) input [31:0] ro;
(* matchi_type = "sharings_dense", matchi_active = "in_act" *) input [31:0] mo;
(* matchi_type = "random", matchi_active = "r_act" *) input [217:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [217:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [31:0] aout;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [31:0] nri;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [31:0] nro;
(* matchi_type = "sharing", matchi_active = "out_act" *) output [1:0] ok;

// ---- global cycle counter (public control; counts 1.. from go, saturates —
// the div256 window pattern) + per-stage strobes at fixed counts ----
reg [11:0] cnt;
always @(posedge clk) begin
    if (rst)                       cnt <= 12'd0;
    else if (go)                   cnt <= 12'd1;
    else if (cnt != 12'd0 && cnt != 12'd1530) cnt <= cnt + 12'd1;
end
(* keep *) wire in_act  = go || (cnt == 12'd1);   // operands consumed at load
(* keep *) wire r_act   = go || (cnt >= 12'd1 && cnt <= 12'd1527);
(* keep *) wire s_act   =       (cnt >= 12'd1 && cnt <= 12'd1528);
(* keep *) wire out_act = go || (cnt >= 12'd1 && cnt <= 12'd1525);
wire add_cap = (cnt == 12'd44);   // denom D <= adder wires
wire mul_cap = (cnt == 12'd172);   // mprod <= mul ripple wires
wire d_go    = (cnt == 12'd176);    // div stage load strobe
wire ok_cap  = (cnt == 12'd989);    // ok/nror <= cmp/subro wires
(* keep *) wire clr = (cnt == 12'd995);  // bounded sensitivity

// ---- held operands (per-share; loaded at go, cleared at clr) ----
reg [15:0] hx0, hx1;          // amountIn
reg [15:0] hri0, hri1;        // reserveIn
reg [15:0] hro0, hro1;        // reserveOut
reg [15:0] hmo0, hmo1;        // minOut
always @(posedge clk) begin
    if (rst || clr) begin
        hx0 <= 0; hx1 <= 0; hri0 <= 0; hri1 <= 0;
        hro0 <= 0; hro1 <= 0; hmo0 <= 0; hmo1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        hx0  <= {x[30], x[28], x[26], x[24], x[22], x[20], x[18], x[16], x[14], x[12], x[10], x[8], x[6], x[4], x[2], x[0]};
        hx1  <= {x[31], x[29], x[27], x[25], x[23], x[21], x[19], x[17], x[15], x[13], x[11], x[9], x[7], x[5], x[3], x[1]};
        hri0 <= {ri[30], ri[28], ri[26], ri[24], ri[22], ri[20], ri[18], ri[16], ri[14], ri[12], ri[10], ri[8], ri[6], ri[4], ri[2], ri[0]};
        hri1 <= {ri[31], ri[29], ri[27], ri[25], ri[23], ri[21], ri[19], ri[17], ri[15], ri[13], ri[11], ri[9], ri[7], ri[5], ri[3], ri[1]};
        hro0 <= {ro[30], ro[28], ro[26], ro[24], ro[22], ro[20], ro[18], ro[16], ro[14], ro[12], ro[10], ro[8], ro[6], ro[4], ro[2], ro[0]};
        hro1 <= {ro[31], ro[29], ro[27], ro[25], ro[23], ro[21], ro[19], ro[17], ro[15], ro[13], ro[11], ro[9], ro[7], ro[5], ro[3], ro[1]};
        hmo0 <= {mo[30], mo[28], mo[26], mo[24], mo[22], mo[20], mo[18], mo[16], mo[14], mo[12], mo[10], mo[8], mo[6], mo[4], mo[2], mo[0]};
        hmo1 <= {mo[31], mo[29], mo[27], mo[25], mo[23], mo[21], mo[19], mo[17], mo[15], mo[13], mo[11], mo[9], mo[7], mo[5], mo[3], mo[1]};
    end
end

// ==================== stage A1: MUL num = ro * x (mul256 copy) ====================
// ---- mul public FSM (period 8) ----
reg m_running;
reg [4:0] m_it;
reg [2:0] m_ph;
always @(posedge clk) begin
    if (rst) begin m_running <= 1'b0; m_it <= 0; m_ph <= 3'd0; end
    else if (go) begin m_running <= 1'b1; m_it <= 0; m_ph <= 3'd0; end
    else if (m_running) begin
        if (m_ph == 3'd7) begin
            m_ph <= 3'd0;
            if (m_it == 5'd15) begin m_running <= 1'b0; m_it <= 0; end
            else m_it <= m_it + 5'd1;
        end else m_ph <= m_ph + 3'd1;
    end
end

// ---- mul state registers (per-share; NEVER mix shares) ----
reg [15:0] m_aa0, m_aa1;      // multiplicand = reserveOut, shifts left
reg [15:0] m_bb0, m_bb1;      // multiplier = amountIn, shifts right
reg [15:0] m_S0, m_S1, m_C0, m_C1;
reg [15:0] m_pp0, m_pp1;
wire [15:0] w_mpp0, w_mpp1;
wire [14:0] w_msc0, w_msc1, w_mpx0, w_mpx1;
wire [14:0] m_maj0 = w_msc0 ^ w_mpx0;   // share-local
wire [14:0] m_maj1 = w_msc1 ^ w_mpx1;

always @(posedge clk) begin
    if (rst || clr) begin
        m_aa0 <= 0; m_aa1 <= 0; m_bb0 <= 0; m_bb1 <= 0;
        m_S0 <= 0; m_S1 <= 0; m_C0 <= 0; m_C1 <= 0; m_pp0 <= 0; m_pp1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        m_aa0 <= {ro[30], ro[28], ro[26], ro[24], ro[22], ro[20], ro[18], ro[16], ro[14], ro[12], ro[10], ro[8], ro[6], ro[4], ro[2], ro[0]};
        m_aa1 <= {ro[31], ro[29], ro[27], ro[25], ro[23], ro[21], ro[19], ro[17], ro[15], ro[13], ro[11], ro[9], ro[7], ro[5], ro[3], ro[1]};
        m_bb0 <= {x[30], x[28], x[26], x[24], x[22], x[20], x[18], x[16], x[14], x[12], x[10], x[8], x[6], x[4], x[2], x[0]};
        m_bb1 <= {x[31], x[29], x[27], x[25], x[23], x[21], x[19], x[17], x[15], x[13], x[11], x[9], x[7], x[5], x[3], x[1]};
        m_S0 <= 0; m_S1 <= 0; m_C0 <= 0; m_C1 <= 0; m_pp0 <= 0; m_pp1 <= 0;
    end else if (m_running) begin
        if (m_ph == 3'd3) begin m_pp0 <= w_mpp0; m_pp1 <= w_mpp1; end
        if (m_ph == 3'd7) begin
            m_S0 <= m_S0 ^ m_C0 ^ m_pp0;            // share-local
            m_S1 <= m_S1 ^ m_C1 ^ m_pp1;
            m_C0 <= {m_maj0, 1'b0};
            m_C1 <= {m_maj1, 1'b0};
            m_aa0 <= {m_aa0[14:0], 1'b0};
            m_aa1 <= {m_aa1[14:0], 1'b0};
            m_bb0 <= {1'b0, m_bb0[15:1]};
            m_bb1 <= {1'b0, m_bb1[15:1]};
        end
    end
end

// ---- 1-cycle per-share balance registers (unconditional: self-draining) ----
reg [15:0] m_aa_d0, m_aa_d1;  // ina of u_mpp_*  (inb = m_bb bit)
reg [15:0] m_c_d0, m_c_d1;    // ina of u_msc_*  (inb = m_S)
reg [15:0] m_x_d0, m_x_d1;    // ina of u_mpx_*  (inb = m_pp)
reg [15:0] m_S_d0, m_S_d1;    // final-add operand a := delayed S (b := C)
always @(posedge clk) begin
    m_aa_d0 <= m_aa0;         m_aa_d1 <= m_aa1;
    m_c_d0  <= m_C0;          m_c_d1  <= m_C1;
    m_x_d0  <= m_S0 ^ m_C0;   m_x_d1  <= m_S1 ^ m_C1;
    m_S_d0  <= m_S0;          m_S_d1  <= m_S1;
end

// ---- mul product capture (inter-stage hand-off, per-share) ----
// (* keep *): mprodw feeds only register inputs; without keep, abc absorbs the
// XOR drivers into the register cone and MATCHI hits a driverless wire.
(* keep *) wire [15:0] mprodw0, mprodw1;   // mul final-ripple sum wires
reg [15:0] mprod0, mprod1;                 // captured num = ro*x mod 2^16
always @(posedge clk) begin
    if (rst || clr) begin mprod0 <= 0; mprod1 <= 0; end
    else if (mul_cap) begin mprod0 <= mprodw0; mprod1 <= mprodw1; end
end

// ==================== stage A2: ADD denom = ri + x (adder dataflow) ====================
// operands: b := hx (inb@0), a := hri_d (ina@1 via balance register)
reg [15:0] hri_d0, hri_d1;
always @(posedge clk) begin
    hri_d0 <= hri0;  hri_d1 <= hri1;
end
(* keep *) wire [15:0] a_sum0, a_sum1;     // denom sum wires (feed D regs only)
reg [15:0] D0, D1;                         // captured denom (= newReserveIn)
always @(posedge clk) begin
    if (rst || clr) begin D0 <= 0; D1 <= 0; end
    else if (add_cap) begin D0 <= a_sum0; D1 <= a_sum1; end
end

// ==================== stage B: DIV aout = num / denom (div256 copy) ====================
// ---- div public FSM (period 48), started by the d_go strobe ----
reg d_running;
reg [4:0] d_it;
reg [5:0] d_ph;
always @(posedge clk) begin
    if (rst) begin d_running <= 1'b0; d_it <= 0; d_ph <= 0; end
    else if (d_go) begin d_running <= 1'b1; d_it <= 0; d_ph <= 0; end
    else if (d_running) begin
        if (d_ph == 47) begin
            d_ph <= 0;
            if (d_it == 5'd15) begin d_running <= 1'b0; d_it <= 0; end
            else d_it <= d_it + 5'd1;
        end else d_ph <= d_ph + 1'b1;
    end
end

// ---- div state registers (per-share; NEVER mix shares) ----
reg [15:0] d_R0, d_R1;        // partial remainder
reg [15:0] d_A0, d_A1;        // dividend = num, shifts left
reg [15:0] d_Q0, d_Q1;        // quotient = amountOut, shifts left
reg [15:0] d_Bn0, d_Bn1;      // ~denom (complement share 0 only)
reg [15:0] d_Treg0, d_Treg1;  // registered subtract result (settled)
reg d_coutr0, d_coutr1;          // registered carry-out = quotient bit
wire [16:0] d_Rsh0 = {d_R0, d_A0[15]};
wire [16:0] d_Rsh1 = {d_R1, d_A1[15]};
wire [15:0] w_dm0, w_dm1;     // borrow-mux gadget outputs
// (* keep *): T/coutw feed only register inputs (div256 lesson)
(* keep *) wire [15:0] d_T0, d_T1;
(* keep *) wire d_coutw0, d_coutw1;

always @(posedge clk) begin
    if (rst || clr) begin
        d_R0 <= 0; d_R1 <= 0; d_A0 <= 0; d_A1 <= 0; d_Q0 <= 0; d_Q1 <= 0;
        d_Bn0 <= 0; d_Bn1 <= 0; d_Treg0 <= 0; d_Treg1 <= 0;
        d_coutr0 <= 0; d_coutr1 <= 0;
    end else if (d_go) begin      // inter-stage hand-off: per-share reg copies
        d_A0 <= mprod0;           // dividend = captured num
        d_A1 <= mprod1;
        d_Bn0 <= ~D0;             // share-local NOT: complement share 0
        d_Bn1 <= D1;              // share 1 untouched
        d_R0 <= 0; d_R1 <= 0; d_Q0 <= 0; d_Q1 <= 0;
        d_Treg0 <= 0; d_Treg1 <= 0; d_coutr0 <= 0; d_coutr1 <= 0;
    end else if (d_running) begin
        if (d_ph == 39) begin   // subtract ripple settled: capture T, cout
            d_Treg0 <= d_T0; d_Treg1 <= d_T1;
            d_coutr0 <= d_coutw0; d_coutr1 <= d_coutw1;
        end
        if (d_ph == 47) begin   // iteration update (all share-local)
            d_R0 <= d_Rsh0[15:0] ^ w_dm0;   // R' = cout ? T : Rsh
            d_R1 <= d_Rsh1[15:0] ^ w_dm1;
            d_Q0 <= {d_Q0[14:0], d_coutr0};
            d_Q1 <= {d_Q1[14:0], d_coutr1};
            d_A0 <= {d_A0[14:0], 1'b0};
            d_A1 <= {d_A1[14:0], 1'b0};
        end
    end
end

// ---- 1-cycle per-share balance registers (unconditional: self-draining) ----
reg [16:0] d_Rsh_d0, d_Rsh_d1;  // ina of u_dg_*  (inb = d_Bn)
reg [15:0] d_xm_d0, d_xm_d1;  // ina of u_dm_*  (inb = d_coutr)
always @(posedge clk) begin
    d_Rsh_d0 <= d_Rsh0;                        d_Rsh_d1 <= d_Rsh1;
    d_xm_d0  <= d_Rsh0[15:0] ^ d_Treg0;     d_xm_d1  <= d_Rsh1[15:0] ^ d_Treg1;
end

// ==================== stage C: CMP ok = (aout >= mo), SUB nro = ro - aout ====================
// cmp: aout - mo borrow-out. b := mo complemented share-locally (sub=1),
// a := Q via balance register. subro: b := ~Q (share 0), a := hro_d.
reg [15:0] d_Q_d0, d_Q_d1;    // ina of u_cg_* (inb = ~hmo0/hmo1)
reg [15:0] hro_d0, hro_d1;    // ina of u_sg_* (inb = ~d_Q0/d_Q1)
always @(posedge clk) begin
    d_Q_d0 <= d_Q0;  d_Q_d1 <= d_Q1;
    hro_d0 <= hro0;  hro_d1 <= hro1;
end
(* keep *) wire c_coutw0, c_coutw1;           // compare borrow-out wires
(* keep *) wire [15:0] s_sum0, s_sum1;     // reserve-sub sum wires
reg ok0, ok1;                                 // captured ok = (aout >= mo)
reg [15:0] nror0, nror1;                   // captured nro = ro - aout
always @(posedge clk) begin
    if (rst || clr) begin ok0 <= 0; ok1 <= 0; nror0 <= 0; nror1 <= 0; end
    else if (ok_cap) begin
        ok0 <= c_coutw0; ok1 <= c_coutw1;
        nror0 <= s_sum0; nror1 <= s_sum1;
    end
end

// ---- outputs: dense re-pack of the result registers (share-local wiring) ----
assign ok = {ok1, ok0};

assign aout[0] = d_Q0[0];  assign aout[1] = d_Q1[0];  assign nri[0] = D0[0];  assign nri[1] = D1[0];  assign nro[0] = nror0[0];  assign nro[1] = nror1[0];
assign aout[2] = d_Q0[1];  assign aout[3] = d_Q1[1];  assign nri[2] = D0[1];  assign nri[3] = D1[1];  assign nro[2] = nror0[1];  assign nro[3] = nror1[1];
assign aout[4] = d_Q0[2];  assign aout[5] = d_Q1[2];  assign nri[4] = D0[2];  assign nri[5] = D1[2];  assign nro[4] = nror0[2];  assign nro[5] = nror1[2];
assign aout[6] = d_Q0[3];  assign aout[7] = d_Q1[3];  assign nri[6] = D0[3];  assign nri[7] = D1[3];  assign nro[6] = nror0[3];  assign nro[7] = nror1[3];
assign aout[8] = d_Q0[4];  assign aout[9] = d_Q1[4];  assign nri[8] = D0[4];  assign nri[9] = D1[4];  assign nro[8] = nror0[4];  assign nro[9] = nror1[4];
assign aout[10] = d_Q0[5];  assign aout[11] = d_Q1[5];  assign nri[10] = D0[5];  assign nri[11] = D1[5];  assign nro[10] = nror0[5];  assign nro[11] = nror1[5];
assign aout[12] = d_Q0[6];  assign aout[13] = d_Q1[6];  assign nri[12] = D0[6];  assign nri[13] = D1[6];  assign nro[12] = nror0[6];  assign nro[13] = nror1[6];
assign aout[14] = d_Q0[7];  assign aout[15] = d_Q1[7];  assign nri[14] = D0[7];  assign nri[15] = D1[7];  assign nro[14] = nror0[7];  assign nro[15] = nror1[7];
assign aout[16] = d_Q0[8];  assign aout[17] = d_Q1[8];  assign nri[16] = D0[8];  assign nri[17] = D1[8];  assign nro[16] = nror0[8];  assign nro[17] = nror1[8];
assign aout[18] = d_Q0[9];  assign aout[19] = d_Q1[9];  assign nri[18] = D0[9];  assign nri[19] = D1[9];  assign nro[18] = nror0[9];  assign nro[19] = nror1[9];
assign aout[20] = d_Q0[10];  assign aout[21] = d_Q1[10];  assign nri[20] = D0[10];  assign nri[21] = D1[10];  assign nro[20] = nror0[10];  assign nro[21] = nror1[10];
assign aout[22] = d_Q0[11];  assign aout[23] = d_Q1[11];  assign nri[22] = D0[11];  assign nri[23] = D1[11];  assign nro[22] = nror0[11];  assign nro[23] = nror1[11];
assign aout[24] = d_Q0[12];  assign aout[25] = d_Q1[12];  assign nri[24] = D0[12];  assign nri[25] = D1[12];  assign nro[24] = nror0[12];  assign nro[25] = nror1[12];
assign aout[26] = d_Q0[13];  assign aout[27] = d_Q1[13];  assign nri[26] = D0[13];  assign nri[27] = D1[13];  assign nro[26] = nror0[13];  assign nro[27] = nror1[13];
assign aout[28] = d_Q0[14];  assign aout[29] = d_Q1[14];  assign nri[28] = D0[14];  assign nri[29] = D1[14];  assign nro[28] = nror0[14];  assign nro[29] = nror1[14];
assign aout[30] = d_Q0[15];  assign aout[31] = d_Q1[15];  assign nri[30] = D0[15];  assign nri[31] = D1[15];  assign nro[30] = nror0[15];  assign nro[31] = nror1[15];

// ===== mul PP gating: PP[j] = m_aa[j] AND m_bb[0] (mul256 copy) =====
MSKand_opini2_d2 u_mpp_0 (
    .ina({m_aa_d1[0], m_aa_d0[0]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({w_mpp1[0], w_mpp0[0]}));
MSKand_opini2_d2 u_mpp_1 (
    .ina({m_aa_d1[1], m_aa_d0[1]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[1]), .s(s[1]), .clk(clk), .out({w_mpp1[1], w_mpp0[1]}));
MSKand_opini2_d2 u_mpp_2 (
    .ina({m_aa_d1[2], m_aa_d0[2]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[2]), .s(s[2]), .clk(clk), .out({w_mpp1[2], w_mpp0[2]}));
MSKand_opini2_d2 u_mpp_3 (
    .ina({m_aa_d1[3], m_aa_d0[3]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[3]), .s(s[3]), .clk(clk), .out({w_mpp1[3], w_mpp0[3]}));
MSKand_opini2_d2 u_mpp_4 (
    .ina({m_aa_d1[4], m_aa_d0[4]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[4]), .s(s[4]), .clk(clk), .out({w_mpp1[4], w_mpp0[4]}));
MSKand_opini2_d2 u_mpp_5 (
    .ina({m_aa_d1[5], m_aa_d0[5]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[5]), .s(s[5]), .clk(clk), .out({w_mpp1[5], w_mpp0[5]}));
MSKand_opini2_d2 u_mpp_6 (
    .ina({m_aa_d1[6], m_aa_d0[6]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[6]), .s(s[6]), .clk(clk), .out({w_mpp1[6], w_mpp0[6]}));
MSKand_opini2_d2 u_mpp_7 (
    .ina({m_aa_d1[7], m_aa_d0[7]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[7]), .s(s[7]), .clk(clk), .out({w_mpp1[7], w_mpp0[7]}));
MSKand_opini2_d2 u_mpp_8 (
    .ina({m_aa_d1[8], m_aa_d0[8]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[8]), .s(s[8]), .clk(clk), .out({w_mpp1[8], w_mpp0[8]}));
MSKand_opini2_d2 u_mpp_9 (
    .ina({m_aa_d1[9], m_aa_d0[9]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[9]), .s(s[9]), .clk(clk), .out({w_mpp1[9], w_mpp0[9]}));
MSKand_opini2_d2 u_mpp_10 (
    .ina({m_aa_d1[10], m_aa_d0[10]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[10]), .s(s[10]), .clk(clk), .out({w_mpp1[10], w_mpp0[10]}));
MSKand_opini2_d2 u_mpp_11 (
    .ina({m_aa_d1[11], m_aa_d0[11]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[11]), .s(s[11]), .clk(clk), .out({w_mpp1[11], w_mpp0[11]}));
MSKand_opini2_d2 u_mpp_12 (
    .ina({m_aa_d1[12], m_aa_d0[12]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[12]), .s(s[12]), .clk(clk), .out({w_mpp1[12], w_mpp0[12]}));
MSKand_opini2_d2 u_mpp_13 (
    .ina({m_aa_d1[13], m_aa_d0[13]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[13]), .s(s[13]), .clk(clk), .out({w_mpp1[13], w_mpp0[13]}));
MSKand_opini2_d2 u_mpp_14 (
    .ina({m_aa_d1[14], m_aa_d0[14]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[14]), .s(s[14]), .clk(clk), .out({w_mpp1[14], w_mpp0[14]}));
MSKand_opini2_d2 u_mpp_15 (
    .ina({m_aa_d1[15], m_aa_d0[15]}), .inb({m_bb1[0], m_bb0[0]}),
    .rnd(r[15]), .s(s[15]), .clk(clk), .out({w_mpp1[15], w_mpp0[15]}));

// ===== mul carry-save MAJ: newC[j+1] = (S&C)[j] ^ (PP&(S^C))[j] =====
MSKand_opini2_d2 u_msc_0 (
    .ina({m_c_d1[0], m_c_d0[0]}), .inb({m_S1[0], m_S0[0]}),
    .rnd(r[16]), .s(s[16]), .clk(clk), .out({w_msc1[0], w_msc0[0]}));
MSKand_opini2_d2 u_mpx_0 (
    .ina({m_x_d1[0], m_x_d0[0]}), .inb({m_pp1[0], m_pp0[0]}),
    .rnd(r[17]), .s(s[17]), .clk(clk), .out({w_mpx1[0], w_mpx0[0]}));
MSKand_opini2_d2 u_msc_1 (
    .ina({m_c_d1[1], m_c_d0[1]}), .inb({m_S1[1], m_S0[1]}),
    .rnd(r[18]), .s(s[18]), .clk(clk), .out({w_msc1[1], w_msc0[1]}));
MSKand_opini2_d2 u_mpx_1 (
    .ina({m_x_d1[1], m_x_d0[1]}), .inb({m_pp1[1], m_pp0[1]}),
    .rnd(r[19]), .s(s[19]), .clk(clk), .out({w_mpx1[1], w_mpx0[1]}));
MSKand_opini2_d2 u_msc_2 (
    .ina({m_c_d1[2], m_c_d0[2]}), .inb({m_S1[2], m_S0[2]}),
    .rnd(r[20]), .s(s[20]), .clk(clk), .out({w_msc1[2], w_msc0[2]}));
MSKand_opini2_d2 u_mpx_2 (
    .ina({m_x_d1[2], m_x_d0[2]}), .inb({m_pp1[2], m_pp0[2]}),
    .rnd(r[21]), .s(s[21]), .clk(clk), .out({w_mpx1[2], w_mpx0[2]}));
MSKand_opini2_d2 u_msc_3 (
    .ina({m_c_d1[3], m_c_d0[3]}), .inb({m_S1[3], m_S0[3]}),
    .rnd(r[22]), .s(s[22]), .clk(clk), .out({w_msc1[3], w_msc0[3]}));
MSKand_opini2_d2 u_mpx_3 (
    .ina({m_x_d1[3], m_x_d0[3]}), .inb({m_pp1[3], m_pp0[3]}),
    .rnd(r[23]), .s(s[23]), .clk(clk), .out({w_mpx1[3], w_mpx0[3]}));
MSKand_opini2_d2 u_msc_4 (
    .ina({m_c_d1[4], m_c_d0[4]}), .inb({m_S1[4], m_S0[4]}),
    .rnd(r[24]), .s(s[24]), .clk(clk), .out({w_msc1[4], w_msc0[4]}));
MSKand_opini2_d2 u_mpx_4 (
    .ina({m_x_d1[4], m_x_d0[4]}), .inb({m_pp1[4], m_pp0[4]}),
    .rnd(r[25]), .s(s[25]), .clk(clk), .out({w_mpx1[4], w_mpx0[4]}));
MSKand_opini2_d2 u_msc_5 (
    .ina({m_c_d1[5], m_c_d0[5]}), .inb({m_S1[5], m_S0[5]}),
    .rnd(r[26]), .s(s[26]), .clk(clk), .out({w_msc1[5], w_msc0[5]}));
MSKand_opini2_d2 u_mpx_5 (
    .ina({m_x_d1[5], m_x_d0[5]}), .inb({m_pp1[5], m_pp0[5]}),
    .rnd(r[27]), .s(s[27]), .clk(clk), .out({w_mpx1[5], w_mpx0[5]}));
MSKand_opini2_d2 u_msc_6 (
    .ina({m_c_d1[6], m_c_d0[6]}), .inb({m_S1[6], m_S0[6]}),
    .rnd(r[28]), .s(s[28]), .clk(clk), .out({w_msc1[6], w_msc0[6]}));
MSKand_opini2_d2 u_mpx_6 (
    .ina({m_x_d1[6], m_x_d0[6]}), .inb({m_pp1[6], m_pp0[6]}),
    .rnd(r[29]), .s(s[29]), .clk(clk), .out({w_mpx1[6], w_mpx0[6]}));
MSKand_opini2_d2 u_msc_7 (
    .ina({m_c_d1[7], m_c_d0[7]}), .inb({m_S1[7], m_S0[7]}),
    .rnd(r[30]), .s(s[30]), .clk(clk), .out({w_msc1[7], w_msc0[7]}));
MSKand_opini2_d2 u_mpx_7 (
    .ina({m_x_d1[7], m_x_d0[7]}), .inb({m_pp1[7], m_pp0[7]}),
    .rnd(r[31]), .s(s[31]), .clk(clk), .out({w_mpx1[7], w_mpx0[7]}));
MSKand_opini2_d2 u_msc_8 (
    .ina({m_c_d1[8], m_c_d0[8]}), .inb({m_S1[8], m_S0[8]}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({w_msc1[8], w_msc0[8]}));
MSKand_opini2_d2 u_mpx_8 (
    .ina({m_x_d1[8], m_x_d0[8]}), .inb({m_pp1[8], m_pp0[8]}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({w_mpx1[8], w_mpx0[8]}));
MSKand_opini2_d2 u_msc_9 (
    .ina({m_c_d1[9], m_c_d0[9]}), .inb({m_S1[9], m_S0[9]}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({w_msc1[9], w_msc0[9]}));
MSKand_opini2_d2 u_mpx_9 (
    .ina({m_x_d1[9], m_x_d0[9]}), .inb({m_pp1[9], m_pp0[9]}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({w_mpx1[9], w_mpx0[9]}));
MSKand_opini2_d2 u_msc_10 (
    .ina({m_c_d1[10], m_c_d0[10]}), .inb({m_S1[10], m_S0[10]}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({w_msc1[10], w_msc0[10]}));
MSKand_opini2_d2 u_mpx_10 (
    .ina({m_x_d1[10], m_x_d0[10]}), .inb({m_pp1[10], m_pp0[10]}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({w_mpx1[10], w_mpx0[10]}));
MSKand_opini2_d2 u_msc_11 (
    .ina({m_c_d1[11], m_c_d0[11]}), .inb({m_S1[11], m_S0[11]}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({w_msc1[11], w_msc0[11]}));
MSKand_opini2_d2 u_mpx_11 (
    .ina({m_x_d1[11], m_x_d0[11]}), .inb({m_pp1[11], m_pp0[11]}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({w_mpx1[11], w_mpx0[11]}));
MSKand_opini2_d2 u_msc_12 (
    .ina({m_c_d1[12], m_c_d0[12]}), .inb({m_S1[12], m_S0[12]}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({w_msc1[12], w_msc0[12]}));
MSKand_opini2_d2 u_mpx_12 (
    .ina({m_x_d1[12], m_x_d0[12]}), .inb({m_pp1[12], m_pp0[12]}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({w_mpx1[12], w_mpx0[12]}));
MSKand_opini2_d2 u_msc_13 (
    .ina({m_c_d1[13], m_c_d0[13]}), .inb({m_S1[13], m_S0[13]}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({w_msc1[13], w_msc0[13]}));
MSKand_opini2_d2 u_mpx_13 (
    .ina({m_x_d1[13], m_x_d0[13]}), .inb({m_pp1[13], m_pp0[13]}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({w_mpx1[13], w_mpx0[13]}));
MSKand_opini2_d2 u_msc_14 (
    .ina({m_c_d1[14], m_c_d0[14]}), .inb({m_S1[14], m_S0[14]}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({w_msc1[14], w_msc0[14]}));
MSKand_opini2_d2 u_mpx_14 (
    .ina({m_x_d1[14], m_x_d0[14]}), .inb({m_pp1[14], m_pp0[14]}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({w_mpx1[14], w_mpx0[14]}));

// ===== mul final ripple add: num = S + C mod 2^16 (verified-adder dataflow, sub=0) =====
wire [14:0] m_fc0, m_fc1;
assign m_fc0[0] = 1'b0;
assign m_fc1[0] = 1'b0;
wire mp0_0 = m_S_d0[0] ^ m_C0[0];
wire mp1_0 = m_S_d1[0] ^ m_C1[0];
wire mg0_0, mg1_0, mt0_0, mt1_0;
MSKand_opini2_d2 u_mg_0 (
    .ina({m_S_d1[0], m_S_d0[0]}), .inb({m_C1[0], m_C0[0]}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({mg1_0, mg0_0}));
MSKand_opini2_d2 u_mt_0 (
    .ina({m_fc1[0], m_fc0[0]}), .inb({mp1_0, mp0_0}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({mt1_0, mt0_0}));
assign m_fc0[1] = mg0_0 ^ mt0_0;
assign m_fc1[1] = mg1_0 ^ mt1_0;
assign mprodw0[0] = mp0_0 ^ m_fc0[0];
assign mprodw1[0] = mp1_0 ^ m_fc1[0];
wire mp0_1 = m_S_d0[1] ^ m_C0[1];
wire mp1_1 = m_S_d1[1] ^ m_C1[1];
wire mg0_1, mg1_1, mt0_1, mt1_1;
MSKand_opini2_d2 u_mg_1 (
    .ina({m_S_d1[1], m_S_d0[1]}), .inb({m_C1[1], m_C0[1]}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({mg1_1, mg0_1}));
MSKand_opini2_d2 u_mt_1 (
    .ina({m_fc1[1], m_fc0[1]}), .inb({mp1_1, mp0_1}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({mt1_1, mt0_1}));
assign m_fc0[2] = mg0_1 ^ mt0_1;
assign m_fc1[2] = mg1_1 ^ mt1_1;
assign mprodw0[1] = mp0_1 ^ m_fc0[1];
assign mprodw1[1] = mp1_1 ^ m_fc1[1];
wire mp0_2 = m_S_d0[2] ^ m_C0[2];
wire mp1_2 = m_S_d1[2] ^ m_C1[2];
wire mg0_2, mg1_2, mt0_2, mt1_2;
MSKand_opini2_d2 u_mg_2 (
    .ina({m_S_d1[2], m_S_d0[2]}), .inb({m_C1[2], m_C0[2]}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({mg1_2, mg0_2}));
MSKand_opini2_d2 u_mt_2 (
    .ina({m_fc1[2], m_fc0[2]}), .inb({mp1_2, mp0_2}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({mt1_2, mt0_2}));
assign m_fc0[3] = mg0_2 ^ mt0_2;
assign m_fc1[3] = mg1_2 ^ mt1_2;
assign mprodw0[2] = mp0_2 ^ m_fc0[2];
assign mprodw1[2] = mp1_2 ^ m_fc1[2];
wire mp0_3 = m_S_d0[3] ^ m_C0[3];
wire mp1_3 = m_S_d1[3] ^ m_C1[3];
wire mg0_3, mg1_3, mt0_3, mt1_3;
MSKand_opini2_d2 u_mg_3 (
    .ina({m_S_d1[3], m_S_d0[3]}), .inb({m_C1[3], m_C0[3]}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({mg1_3, mg0_3}));
MSKand_opini2_d2 u_mt_3 (
    .ina({m_fc1[3], m_fc0[3]}), .inb({mp1_3, mp0_3}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({mt1_3, mt0_3}));
assign m_fc0[4] = mg0_3 ^ mt0_3;
assign m_fc1[4] = mg1_3 ^ mt1_3;
assign mprodw0[3] = mp0_3 ^ m_fc0[3];
assign mprodw1[3] = mp1_3 ^ m_fc1[3];
wire mp0_4 = m_S_d0[4] ^ m_C0[4];
wire mp1_4 = m_S_d1[4] ^ m_C1[4];
wire mg0_4, mg1_4, mt0_4, mt1_4;
MSKand_opini2_d2 u_mg_4 (
    .ina({m_S_d1[4], m_S_d0[4]}), .inb({m_C1[4], m_C0[4]}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({mg1_4, mg0_4}));
MSKand_opini2_d2 u_mt_4 (
    .ina({m_fc1[4], m_fc0[4]}), .inb({mp1_4, mp0_4}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({mt1_4, mt0_4}));
assign m_fc0[5] = mg0_4 ^ mt0_4;
assign m_fc1[5] = mg1_4 ^ mt1_4;
assign mprodw0[4] = mp0_4 ^ m_fc0[4];
assign mprodw1[4] = mp1_4 ^ m_fc1[4];
wire mp0_5 = m_S_d0[5] ^ m_C0[5];
wire mp1_5 = m_S_d1[5] ^ m_C1[5];
wire mg0_5, mg1_5, mt0_5, mt1_5;
MSKand_opini2_d2 u_mg_5 (
    .ina({m_S_d1[5], m_S_d0[5]}), .inb({m_C1[5], m_C0[5]}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({mg1_5, mg0_5}));
MSKand_opini2_d2 u_mt_5 (
    .ina({m_fc1[5], m_fc0[5]}), .inb({mp1_5, mp0_5}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({mt1_5, mt0_5}));
assign m_fc0[6] = mg0_5 ^ mt0_5;
assign m_fc1[6] = mg1_5 ^ mt1_5;
assign mprodw0[5] = mp0_5 ^ m_fc0[5];
assign mprodw1[5] = mp1_5 ^ m_fc1[5];
wire mp0_6 = m_S_d0[6] ^ m_C0[6];
wire mp1_6 = m_S_d1[6] ^ m_C1[6];
wire mg0_6, mg1_6, mt0_6, mt1_6;
MSKand_opini2_d2 u_mg_6 (
    .ina({m_S_d1[6], m_S_d0[6]}), .inb({m_C1[6], m_C0[6]}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({mg1_6, mg0_6}));
MSKand_opini2_d2 u_mt_6 (
    .ina({m_fc1[6], m_fc0[6]}), .inb({mp1_6, mp0_6}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({mt1_6, mt0_6}));
assign m_fc0[7] = mg0_6 ^ mt0_6;
assign m_fc1[7] = mg1_6 ^ mt1_6;
assign mprodw0[6] = mp0_6 ^ m_fc0[6];
assign mprodw1[6] = mp1_6 ^ m_fc1[6];
wire mp0_7 = m_S_d0[7] ^ m_C0[7];
wire mp1_7 = m_S_d1[7] ^ m_C1[7];
wire mg0_7, mg1_7, mt0_7, mt1_7;
MSKand_opini2_d2 u_mg_7 (
    .ina({m_S_d1[7], m_S_d0[7]}), .inb({m_C1[7], m_C0[7]}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({mg1_7, mg0_7}));
MSKand_opini2_d2 u_mt_7 (
    .ina({m_fc1[7], m_fc0[7]}), .inb({mp1_7, mp0_7}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({mt1_7, mt0_7}));
assign m_fc0[8] = mg0_7 ^ mt0_7;
assign m_fc1[8] = mg1_7 ^ mt1_7;
assign mprodw0[7] = mp0_7 ^ m_fc0[7];
assign mprodw1[7] = mp1_7 ^ m_fc1[7];
wire mp0_8 = m_S_d0[8] ^ m_C0[8];
wire mp1_8 = m_S_d1[8] ^ m_C1[8];
wire mg0_8, mg1_8, mt0_8, mt1_8;
MSKand_opini2_d2 u_mg_8 (
    .ina({m_S_d1[8], m_S_d0[8]}), .inb({m_C1[8], m_C0[8]}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({mg1_8, mg0_8}));
MSKand_opini2_d2 u_mt_8 (
    .ina({m_fc1[8], m_fc0[8]}), .inb({mp1_8, mp0_8}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({mt1_8, mt0_8}));
assign m_fc0[9] = mg0_8 ^ mt0_8;
assign m_fc1[9] = mg1_8 ^ mt1_8;
assign mprodw0[8] = mp0_8 ^ m_fc0[8];
assign mprodw1[8] = mp1_8 ^ m_fc1[8];
wire mp0_9 = m_S_d0[9] ^ m_C0[9];
wire mp1_9 = m_S_d1[9] ^ m_C1[9];
wire mg0_9, mg1_9, mt0_9, mt1_9;
MSKand_opini2_d2 u_mg_9 (
    .ina({m_S_d1[9], m_S_d0[9]}), .inb({m_C1[9], m_C0[9]}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({mg1_9, mg0_9}));
MSKand_opini2_d2 u_mt_9 (
    .ina({m_fc1[9], m_fc0[9]}), .inb({mp1_9, mp0_9}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({mt1_9, mt0_9}));
assign m_fc0[10] = mg0_9 ^ mt0_9;
assign m_fc1[10] = mg1_9 ^ mt1_9;
assign mprodw0[9] = mp0_9 ^ m_fc0[9];
assign mprodw1[9] = mp1_9 ^ m_fc1[9];
wire mp0_10 = m_S_d0[10] ^ m_C0[10];
wire mp1_10 = m_S_d1[10] ^ m_C1[10];
wire mg0_10, mg1_10, mt0_10, mt1_10;
MSKand_opini2_d2 u_mg_10 (
    .ina({m_S_d1[10], m_S_d0[10]}), .inb({m_C1[10], m_C0[10]}),
    .rnd(r[66]), .s(s[66]), .clk(clk), .out({mg1_10, mg0_10}));
MSKand_opini2_d2 u_mt_10 (
    .ina({m_fc1[10], m_fc0[10]}), .inb({mp1_10, mp0_10}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({mt1_10, mt0_10}));
assign m_fc0[11] = mg0_10 ^ mt0_10;
assign m_fc1[11] = mg1_10 ^ mt1_10;
assign mprodw0[10] = mp0_10 ^ m_fc0[10];
assign mprodw1[10] = mp1_10 ^ m_fc1[10];
wire mp0_11 = m_S_d0[11] ^ m_C0[11];
wire mp1_11 = m_S_d1[11] ^ m_C1[11];
wire mg0_11, mg1_11, mt0_11, mt1_11;
MSKand_opini2_d2 u_mg_11 (
    .ina({m_S_d1[11], m_S_d0[11]}), .inb({m_C1[11], m_C0[11]}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({mg1_11, mg0_11}));
MSKand_opini2_d2 u_mt_11 (
    .ina({m_fc1[11], m_fc0[11]}), .inb({mp1_11, mp0_11}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({mt1_11, mt0_11}));
assign m_fc0[12] = mg0_11 ^ mt0_11;
assign m_fc1[12] = mg1_11 ^ mt1_11;
assign mprodw0[11] = mp0_11 ^ m_fc0[11];
assign mprodw1[11] = mp1_11 ^ m_fc1[11];
wire mp0_12 = m_S_d0[12] ^ m_C0[12];
wire mp1_12 = m_S_d1[12] ^ m_C1[12];
wire mg0_12, mg1_12, mt0_12, mt1_12;
MSKand_opini2_d2 u_mg_12 (
    .ina({m_S_d1[12], m_S_d0[12]}), .inb({m_C1[12], m_C0[12]}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({mg1_12, mg0_12}));
MSKand_opini2_d2 u_mt_12 (
    .ina({m_fc1[12], m_fc0[12]}), .inb({mp1_12, mp0_12}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({mt1_12, mt0_12}));
assign m_fc0[13] = mg0_12 ^ mt0_12;
assign m_fc1[13] = mg1_12 ^ mt1_12;
assign mprodw0[12] = mp0_12 ^ m_fc0[12];
assign mprodw1[12] = mp1_12 ^ m_fc1[12];
wire mp0_13 = m_S_d0[13] ^ m_C0[13];
wire mp1_13 = m_S_d1[13] ^ m_C1[13];
wire mg0_13, mg1_13, mt0_13, mt1_13;
MSKand_opini2_d2 u_mg_13 (
    .ina({m_S_d1[13], m_S_d0[13]}), .inb({m_C1[13], m_C0[13]}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({mg1_13, mg0_13}));
MSKand_opini2_d2 u_mt_13 (
    .ina({m_fc1[13], m_fc0[13]}), .inb({mp1_13, mp0_13}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({mt1_13, mt0_13}));
assign m_fc0[14] = mg0_13 ^ mt0_13;
assign m_fc1[14] = mg1_13 ^ mt1_13;
assign mprodw0[13] = mp0_13 ^ m_fc0[13];
assign mprodw1[13] = mp1_13 ^ m_fc1[13];
wire mp0_14 = m_S_d0[14] ^ m_C0[14];
wire mp1_14 = m_S_d1[14] ^ m_C1[14];
wire mg0_14, mg1_14, mt0_14, mt1_14;
MSKand_opini2_d2 u_mg_14 (
    .ina({m_S_d1[14], m_S_d0[14]}), .inb({m_C1[14], m_C0[14]}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({mg1_14, mg0_14}));
MSKand_opini2_d2 u_mt_14 (
    .ina({m_fc1[14], m_fc0[14]}), .inb({mp1_14, mp0_14}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({mt1_14, mt0_14}));
wire m_fct0 = mg0_14 ^ mt0_14;
wire m_fct1 = mg1_14 ^ mt1_14;
assign mprodw0[14] = mp0_14 ^ m_fc0[14];
assign mprodw1[14] = mp1_14 ^ m_fc1[14];
// top bit: sum only, carry-out dropped (mod 2^16, EVM MUL)
wire mp0_15 = m_S_d0[15] ^ m_C0[15];
wire mp1_15 = m_S_d1[15] ^ m_C1[15];
assign mprodw0[15] = mp0_15 ^ m_fct0;
assign mprodw1[15] = mp1_15 ^ m_fct1;

// ===== denom ripple add: D = ri + x mod 2^16 (verified-adder dataflow, sub=0) =====
wire [14:0] a_fc0, a_fc1;
assign a_fc0[0] = 1'b0;
assign a_fc1[0] = 1'b0;
wire ap0_0 = hri_d0[0] ^ hx0[0];
wire ap1_0 = hri_d1[0] ^ hx1[0];
wire ag0_0, ag1_0, at0_0, at1_0;
MSKand_opini2_d2 u_ag_0 (
    .ina({hri_d1[0], hri_d0[0]}), .inb({hx1[0], hx0[0]}),
    .rnd(r[76]), .s(s[76]), .clk(clk), .out({ag1_0, ag0_0}));
MSKand_opini2_d2 u_at_0 (
    .ina({a_fc1[0], a_fc0[0]}), .inb({ap1_0, ap0_0}),
    .rnd(r[77]), .s(s[77]), .clk(clk), .out({at1_0, at0_0}));
assign a_fc0[1] = ag0_0 ^ at0_0;
assign a_fc1[1] = ag1_0 ^ at1_0;
assign a_sum0[0] = ap0_0 ^ a_fc0[0];
assign a_sum1[0] = ap1_0 ^ a_fc1[0];
wire ap0_1 = hri_d0[1] ^ hx0[1];
wire ap1_1 = hri_d1[1] ^ hx1[1];
wire ag0_1, ag1_1, at0_1, at1_1;
MSKand_opini2_d2 u_ag_1 (
    .ina({hri_d1[1], hri_d0[1]}), .inb({hx1[1], hx0[1]}),
    .rnd(r[78]), .s(s[78]), .clk(clk), .out({ag1_1, ag0_1}));
MSKand_opini2_d2 u_at_1 (
    .ina({a_fc1[1], a_fc0[1]}), .inb({ap1_1, ap0_1}),
    .rnd(r[79]), .s(s[79]), .clk(clk), .out({at1_1, at0_1}));
assign a_fc0[2] = ag0_1 ^ at0_1;
assign a_fc1[2] = ag1_1 ^ at1_1;
assign a_sum0[1] = ap0_1 ^ a_fc0[1];
assign a_sum1[1] = ap1_1 ^ a_fc1[1];
wire ap0_2 = hri_d0[2] ^ hx0[2];
wire ap1_2 = hri_d1[2] ^ hx1[2];
wire ag0_2, ag1_2, at0_2, at1_2;
MSKand_opini2_d2 u_ag_2 (
    .ina({hri_d1[2], hri_d0[2]}), .inb({hx1[2], hx0[2]}),
    .rnd(r[80]), .s(s[80]), .clk(clk), .out({ag1_2, ag0_2}));
MSKand_opini2_d2 u_at_2 (
    .ina({a_fc1[2], a_fc0[2]}), .inb({ap1_2, ap0_2}),
    .rnd(r[81]), .s(s[81]), .clk(clk), .out({at1_2, at0_2}));
assign a_fc0[3] = ag0_2 ^ at0_2;
assign a_fc1[3] = ag1_2 ^ at1_2;
assign a_sum0[2] = ap0_2 ^ a_fc0[2];
assign a_sum1[2] = ap1_2 ^ a_fc1[2];
wire ap0_3 = hri_d0[3] ^ hx0[3];
wire ap1_3 = hri_d1[3] ^ hx1[3];
wire ag0_3, ag1_3, at0_3, at1_3;
MSKand_opini2_d2 u_ag_3 (
    .ina({hri_d1[3], hri_d0[3]}), .inb({hx1[3], hx0[3]}),
    .rnd(r[82]), .s(s[82]), .clk(clk), .out({ag1_3, ag0_3}));
MSKand_opini2_d2 u_at_3 (
    .ina({a_fc1[3], a_fc0[3]}), .inb({ap1_3, ap0_3}),
    .rnd(r[83]), .s(s[83]), .clk(clk), .out({at1_3, at0_3}));
assign a_fc0[4] = ag0_3 ^ at0_3;
assign a_fc1[4] = ag1_3 ^ at1_3;
assign a_sum0[3] = ap0_3 ^ a_fc0[3];
assign a_sum1[3] = ap1_3 ^ a_fc1[3];
wire ap0_4 = hri_d0[4] ^ hx0[4];
wire ap1_4 = hri_d1[4] ^ hx1[4];
wire ag0_4, ag1_4, at0_4, at1_4;
MSKand_opini2_d2 u_ag_4 (
    .ina({hri_d1[4], hri_d0[4]}), .inb({hx1[4], hx0[4]}),
    .rnd(r[84]), .s(s[84]), .clk(clk), .out({ag1_4, ag0_4}));
MSKand_opini2_d2 u_at_4 (
    .ina({a_fc1[4], a_fc0[4]}), .inb({ap1_4, ap0_4}),
    .rnd(r[85]), .s(s[85]), .clk(clk), .out({at1_4, at0_4}));
assign a_fc0[5] = ag0_4 ^ at0_4;
assign a_fc1[5] = ag1_4 ^ at1_4;
assign a_sum0[4] = ap0_4 ^ a_fc0[4];
assign a_sum1[4] = ap1_4 ^ a_fc1[4];
wire ap0_5 = hri_d0[5] ^ hx0[5];
wire ap1_5 = hri_d1[5] ^ hx1[5];
wire ag0_5, ag1_5, at0_5, at1_5;
MSKand_opini2_d2 u_ag_5 (
    .ina({hri_d1[5], hri_d0[5]}), .inb({hx1[5], hx0[5]}),
    .rnd(r[86]), .s(s[86]), .clk(clk), .out({ag1_5, ag0_5}));
MSKand_opini2_d2 u_at_5 (
    .ina({a_fc1[5], a_fc0[5]}), .inb({ap1_5, ap0_5}),
    .rnd(r[87]), .s(s[87]), .clk(clk), .out({at1_5, at0_5}));
assign a_fc0[6] = ag0_5 ^ at0_5;
assign a_fc1[6] = ag1_5 ^ at1_5;
assign a_sum0[5] = ap0_5 ^ a_fc0[5];
assign a_sum1[5] = ap1_5 ^ a_fc1[5];
wire ap0_6 = hri_d0[6] ^ hx0[6];
wire ap1_6 = hri_d1[6] ^ hx1[6];
wire ag0_6, ag1_6, at0_6, at1_6;
MSKand_opini2_d2 u_ag_6 (
    .ina({hri_d1[6], hri_d0[6]}), .inb({hx1[6], hx0[6]}),
    .rnd(r[88]), .s(s[88]), .clk(clk), .out({ag1_6, ag0_6}));
MSKand_opini2_d2 u_at_6 (
    .ina({a_fc1[6], a_fc0[6]}), .inb({ap1_6, ap0_6}),
    .rnd(r[89]), .s(s[89]), .clk(clk), .out({at1_6, at0_6}));
assign a_fc0[7] = ag0_6 ^ at0_6;
assign a_fc1[7] = ag1_6 ^ at1_6;
assign a_sum0[6] = ap0_6 ^ a_fc0[6];
assign a_sum1[6] = ap1_6 ^ a_fc1[6];
wire ap0_7 = hri_d0[7] ^ hx0[7];
wire ap1_7 = hri_d1[7] ^ hx1[7];
wire ag0_7, ag1_7, at0_7, at1_7;
MSKand_opini2_d2 u_ag_7 (
    .ina({hri_d1[7], hri_d0[7]}), .inb({hx1[7], hx0[7]}),
    .rnd(r[90]), .s(s[90]), .clk(clk), .out({ag1_7, ag0_7}));
MSKand_opini2_d2 u_at_7 (
    .ina({a_fc1[7], a_fc0[7]}), .inb({ap1_7, ap0_7}),
    .rnd(r[91]), .s(s[91]), .clk(clk), .out({at1_7, at0_7}));
assign a_fc0[8] = ag0_7 ^ at0_7;
assign a_fc1[8] = ag1_7 ^ at1_7;
assign a_sum0[7] = ap0_7 ^ a_fc0[7];
assign a_sum1[7] = ap1_7 ^ a_fc1[7];
wire ap0_8 = hri_d0[8] ^ hx0[8];
wire ap1_8 = hri_d1[8] ^ hx1[8];
wire ag0_8, ag1_8, at0_8, at1_8;
MSKand_opini2_d2 u_ag_8 (
    .ina({hri_d1[8], hri_d0[8]}), .inb({hx1[8], hx0[8]}),
    .rnd(r[92]), .s(s[92]), .clk(clk), .out({ag1_8, ag0_8}));
MSKand_opini2_d2 u_at_8 (
    .ina({a_fc1[8], a_fc0[8]}), .inb({ap1_8, ap0_8}),
    .rnd(r[93]), .s(s[93]), .clk(clk), .out({at1_8, at0_8}));
assign a_fc0[9] = ag0_8 ^ at0_8;
assign a_fc1[9] = ag1_8 ^ at1_8;
assign a_sum0[8] = ap0_8 ^ a_fc0[8];
assign a_sum1[8] = ap1_8 ^ a_fc1[8];
wire ap0_9 = hri_d0[9] ^ hx0[9];
wire ap1_9 = hri_d1[9] ^ hx1[9];
wire ag0_9, ag1_9, at0_9, at1_9;
MSKand_opini2_d2 u_ag_9 (
    .ina({hri_d1[9], hri_d0[9]}), .inb({hx1[9], hx0[9]}),
    .rnd(r[94]), .s(s[94]), .clk(clk), .out({ag1_9, ag0_9}));
MSKand_opini2_d2 u_at_9 (
    .ina({a_fc1[9], a_fc0[9]}), .inb({ap1_9, ap0_9}),
    .rnd(r[95]), .s(s[95]), .clk(clk), .out({at1_9, at0_9}));
assign a_fc0[10] = ag0_9 ^ at0_9;
assign a_fc1[10] = ag1_9 ^ at1_9;
assign a_sum0[9] = ap0_9 ^ a_fc0[9];
assign a_sum1[9] = ap1_9 ^ a_fc1[9];
wire ap0_10 = hri_d0[10] ^ hx0[10];
wire ap1_10 = hri_d1[10] ^ hx1[10];
wire ag0_10, ag1_10, at0_10, at1_10;
MSKand_opini2_d2 u_ag_10 (
    .ina({hri_d1[10], hri_d0[10]}), .inb({hx1[10], hx0[10]}),
    .rnd(r[96]), .s(s[96]), .clk(clk), .out({ag1_10, ag0_10}));
MSKand_opini2_d2 u_at_10 (
    .ina({a_fc1[10], a_fc0[10]}), .inb({ap1_10, ap0_10}),
    .rnd(r[97]), .s(s[97]), .clk(clk), .out({at1_10, at0_10}));
assign a_fc0[11] = ag0_10 ^ at0_10;
assign a_fc1[11] = ag1_10 ^ at1_10;
assign a_sum0[10] = ap0_10 ^ a_fc0[10];
assign a_sum1[10] = ap1_10 ^ a_fc1[10];
wire ap0_11 = hri_d0[11] ^ hx0[11];
wire ap1_11 = hri_d1[11] ^ hx1[11];
wire ag0_11, ag1_11, at0_11, at1_11;
MSKand_opini2_d2 u_ag_11 (
    .ina({hri_d1[11], hri_d0[11]}), .inb({hx1[11], hx0[11]}),
    .rnd(r[98]), .s(s[98]), .clk(clk), .out({ag1_11, ag0_11}));
MSKand_opini2_d2 u_at_11 (
    .ina({a_fc1[11], a_fc0[11]}), .inb({ap1_11, ap0_11}),
    .rnd(r[99]), .s(s[99]), .clk(clk), .out({at1_11, at0_11}));
assign a_fc0[12] = ag0_11 ^ at0_11;
assign a_fc1[12] = ag1_11 ^ at1_11;
assign a_sum0[11] = ap0_11 ^ a_fc0[11];
assign a_sum1[11] = ap1_11 ^ a_fc1[11];
wire ap0_12 = hri_d0[12] ^ hx0[12];
wire ap1_12 = hri_d1[12] ^ hx1[12];
wire ag0_12, ag1_12, at0_12, at1_12;
MSKand_opini2_d2 u_ag_12 (
    .ina({hri_d1[12], hri_d0[12]}), .inb({hx1[12], hx0[12]}),
    .rnd(r[100]), .s(s[100]), .clk(clk), .out({ag1_12, ag0_12}));
MSKand_opini2_d2 u_at_12 (
    .ina({a_fc1[12], a_fc0[12]}), .inb({ap1_12, ap0_12}),
    .rnd(r[101]), .s(s[101]), .clk(clk), .out({at1_12, at0_12}));
assign a_fc0[13] = ag0_12 ^ at0_12;
assign a_fc1[13] = ag1_12 ^ at1_12;
assign a_sum0[12] = ap0_12 ^ a_fc0[12];
assign a_sum1[12] = ap1_12 ^ a_fc1[12];
wire ap0_13 = hri_d0[13] ^ hx0[13];
wire ap1_13 = hri_d1[13] ^ hx1[13];
wire ag0_13, ag1_13, at0_13, at1_13;
MSKand_opini2_d2 u_ag_13 (
    .ina({hri_d1[13], hri_d0[13]}), .inb({hx1[13], hx0[13]}),
    .rnd(r[102]), .s(s[102]), .clk(clk), .out({ag1_13, ag0_13}));
MSKand_opini2_d2 u_at_13 (
    .ina({a_fc1[13], a_fc0[13]}), .inb({ap1_13, ap0_13}),
    .rnd(r[103]), .s(s[103]), .clk(clk), .out({at1_13, at0_13}));
assign a_fc0[14] = ag0_13 ^ at0_13;
assign a_fc1[14] = ag1_13 ^ at1_13;
assign a_sum0[13] = ap0_13 ^ a_fc0[13];
assign a_sum1[13] = ap1_13 ^ a_fc1[13];
wire ap0_14 = hri_d0[14] ^ hx0[14];
wire ap1_14 = hri_d1[14] ^ hx1[14];
wire ag0_14, ag1_14, at0_14, at1_14;
MSKand_opini2_d2 u_ag_14 (
    .ina({hri_d1[14], hri_d0[14]}), .inb({hx1[14], hx0[14]}),
    .rnd(r[104]), .s(s[104]), .clk(clk), .out({ag1_14, ag0_14}));
MSKand_opini2_d2 u_at_14 (
    .ina({a_fc1[14], a_fc0[14]}), .inb({ap1_14, ap0_14}),
    .rnd(r[105]), .s(s[105]), .clk(clk), .out({at1_14, at0_14}));
wire a_fct0 = ag0_14 ^ at0_14;
wire a_fct1 = ag1_14 ^ at1_14;
assign a_sum0[14] = ap0_14 ^ a_fc0[14];
assign a_sum1[14] = ap1_14 ^ a_fc1[14];
// top bit: sum only, carry-out dropped (mod 2^16, EVM ADD)
wire ap0_15 = hri_d0[15] ^ hx0[15];
wire ap1_15 = hri_d1[15] ^ hx1[15];
assign a_sum0[15] = ap0_15 ^ a_fct0;
assign a_sum1[15] = ap1_15 ^ a_fct1;

// ===== div (N+1)-bit ripple subtract: T = Rsh + ~denom + 1 (sub=1) =====
// d_fc[0] = carry-in = public 1; d_Bn bit 16 = ~0 = public 1.
wire [16:0] d_fc0, d_fc1;
assign d_fc0[0] = 1'b1;
assign d_fc1[0] = 1'b0;
wire dp0_0 = d_Rsh_d0[0] ^ d_Bn0[0];
wire dp1_0 = d_Rsh_d1[0] ^ d_Bn1[0];
wire dg0_0, dg1_0, dt0_0, dt1_0;
MSKand_opini2_d2 u_dg_0 (
    .ina({d_Rsh_d1[0], d_Rsh_d0[0]}), .inb({d_Bn1[0], d_Bn0[0]}),
    .rnd(r[106]), .s(s[106]), .clk(clk), .out({dg1_0, dg0_0}));
MSKand_opini2_d2 u_dt_0 (
    .ina({d_fc1[0], d_fc0[0]}), .inb({dp1_0, dp0_0}),
    .rnd(r[107]), .s(s[107]), .clk(clk), .out({dt1_0, dt0_0}));
assign d_fc0[1] = dg0_0 ^ dt0_0;
assign d_fc1[1] = dg1_0 ^ dt1_0;
wire dp0_1 = d_Rsh_d0[1] ^ d_Bn0[1];
wire dp1_1 = d_Rsh_d1[1] ^ d_Bn1[1];
wire dg0_1, dg1_1, dt0_1, dt1_1;
MSKand_opini2_d2 u_dg_1 (
    .ina({d_Rsh_d1[1], d_Rsh_d0[1]}), .inb({d_Bn1[1], d_Bn0[1]}),
    .rnd(r[108]), .s(s[108]), .clk(clk), .out({dg1_1, dg0_1}));
MSKand_opini2_d2 u_dt_1 (
    .ina({d_fc1[1], d_fc0[1]}), .inb({dp1_1, dp0_1}),
    .rnd(r[109]), .s(s[109]), .clk(clk), .out({dt1_1, dt0_1}));
assign d_fc0[2] = dg0_1 ^ dt0_1;
assign d_fc1[2] = dg1_1 ^ dt1_1;
wire dp0_2 = d_Rsh_d0[2] ^ d_Bn0[2];
wire dp1_2 = d_Rsh_d1[2] ^ d_Bn1[2];
wire dg0_2, dg1_2, dt0_2, dt1_2;
MSKand_opini2_d2 u_dg_2 (
    .ina({d_Rsh_d1[2], d_Rsh_d0[2]}), .inb({d_Bn1[2], d_Bn0[2]}),
    .rnd(r[110]), .s(s[110]), .clk(clk), .out({dg1_2, dg0_2}));
MSKand_opini2_d2 u_dt_2 (
    .ina({d_fc1[2], d_fc0[2]}), .inb({dp1_2, dp0_2}),
    .rnd(r[111]), .s(s[111]), .clk(clk), .out({dt1_2, dt0_2}));
assign d_fc0[3] = dg0_2 ^ dt0_2;
assign d_fc1[3] = dg1_2 ^ dt1_2;
wire dp0_3 = d_Rsh_d0[3] ^ d_Bn0[3];
wire dp1_3 = d_Rsh_d1[3] ^ d_Bn1[3];
wire dg0_3, dg1_3, dt0_3, dt1_3;
MSKand_opini2_d2 u_dg_3 (
    .ina({d_Rsh_d1[3], d_Rsh_d0[3]}), .inb({d_Bn1[3], d_Bn0[3]}),
    .rnd(r[112]), .s(s[112]), .clk(clk), .out({dg1_3, dg0_3}));
MSKand_opini2_d2 u_dt_3 (
    .ina({d_fc1[3], d_fc0[3]}), .inb({dp1_3, dp0_3}),
    .rnd(r[113]), .s(s[113]), .clk(clk), .out({dt1_3, dt0_3}));
assign d_fc0[4] = dg0_3 ^ dt0_3;
assign d_fc1[4] = dg1_3 ^ dt1_3;
wire dp0_4 = d_Rsh_d0[4] ^ d_Bn0[4];
wire dp1_4 = d_Rsh_d1[4] ^ d_Bn1[4];
wire dg0_4, dg1_4, dt0_4, dt1_4;
MSKand_opini2_d2 u_dg_4 (
    .ina({d_Rsh_d1[4], d_Rsh_d0[4]}), .inb({d_Bn1[4], d_Bn0[4]}),
    .rnd(r[114]), .s(s[114]), .clk(clk), .out({dg1_4, dg0_4}));
MSKand_opini2_d2 u_dt_4 (
    .ina({d_fc1[4], d_fc0[4]}), .inb({dp1_4, dp0_4}),
    .rnd(r[115]), .s(s[115]), .clk(clk), .out({dt1_4, dt0_4}));
assign d_fc0[5] = dg0_4 ^ dt0_4;
assign d_fc1[5] = dg1_4 ^ dt1_4;
wire dp0_5 = d_Rsh_d0[5] ^ d_Bn0[5];
wire dp1_5 = d_Rsh_d1[5] ^ d_Bn1[5];
wire dg0_5, dg1_5, dt0_5, dt1_5;
MSKand_opini2_d2 u_dg_5 (
    .ina({d_Rsh_d1[5], d_Rsh_d0[5]}), .inb({d_Bn1[5], d_Bn0[5]}),
    .rnd(r[116]), .s(s[116]), .clk(clk), .out({dg1_5, dg0_5}));
MSKand_opini2_d2 u_dt_5 (
    .ina({d_fc1[5], d_fc0[5]}), .inb({dp1_5, dp0_5}),
    .rnd(r[117]), .s(s[117]), .clk(clk), .out({dt1_5, dt0_5}));
assign d_fc0[6] = dg0_5 ^ dt0_5;
assign d_fc1[6] = dg1_5 ^ dt1_5;
wire dp0_6 = d_Rsh_d0[6] ^ d_Bn0[6];
wire dp1_6 = d_Rsh_d1[6] ^ d_Bn1[6];
wire dg0_6, dg1_6, dt0_6, dt1_6;
MSKand_opini2_d2 u_dg_6 (
    .ina({d_Rsh_d1[6], d_Rsh_d0[6]}), .inb({d_Bn1[6], d_Bn0[6]}),
    .rnd(r[118]), .s(s[118]), .clk(clk), .out({dg1_6, dg0_6}));
MSKand_opini2_d2 u_dt_6 (
    .ina({d_fc1[6], d_fc0[6]}), .inb({dp1_6, dp0_6}),
    .rnd(r[119]), .s(s[119]), .clk(clk), .out({dt1_6, dt0_6}));
assign d_fc0[7] = dg0_6 ^ dt0_6;
assign d_fc1[7] = dg1_6 ^ dt1_6;
wire dp0_7 = d_Rsh_d0[7] ^ d_Bn0[7];
wire dp1_7 = d_Rsh_d1[7] ^ d_Bn1[7];
wire dg0_7, dg1_7, dt0_7, dt1_7;
MSKand_opini2_d2 u_dg_7 (
    .ina({d_Rsh_d1[7], d_Rsh_d0[7]}), .inb({d_Bn1[7], d_Bn0[7]}),
    .rnd(r[120]), .s(s[120]), .clk(clk), .out({dg1_7, dg0_7}));
MSKand_opini2_d2 u_dt_7 (
    .ina({d_fc1[7], d_fc0[7]}), .inb({dp1_7, dp0_7}),
    .rnd(r[121]), .s(s[121]), .clk(clk), .out({dt1_7, dt0_7}));
assign d_fc0[8] = dg0_7 ^ dt0_7;
assign d_fc1[8] = dg1_7 ^ dt1_7;
wire dp0_8 = d_Rsh_d0[8] ^ d_Bn0[8];
wire dp1_8 = d_Rsh_d1[8] ^ d_Bn1[8];
wire dg0_8, dg1_8, dt0_8, dt1_8;
MSKand_opini2_d2 u_dg_8 (
    .ina({d_Rsh_d1[8], d_Rsh_d0[8]}), .inb({d_Bn1[8], d_Bn0[8]}),
    .rnd(r[122]), .s(s[122]), .clk(clk), .out({dg1_8, dg0_8}));
MSKand_opini2_d2 u_dt_8 (
    .ina({d_fc1[8], d_fc0[8]}), .inb({dp1_8, dp0_8}),
    .rnd(r[123]), .s(s[123]), .clk(clk), .out({dt1_8, dt0_8}));
assign d_fc0[9] = dg0_8 ^ dt0_8;
assign d_fc1[9] = dg1_8 ^ dt1_8;
wire dp0_9 = d_Rsh_d0[9] ^ d_Bn0[9];
wire dp1_9 = d_Rsh_d1[9] ^ d_Bn1[9];
wire dg0_9, dg1_9, dt0_9, dt1_9;
MSKand_opini2_d2 u_dg_9 (
    .ina({d_Rsh_d1[9], d_Rsh_d0[9]}), .inb({d_Bn1[9], d_Bn0[9]}),
    .rnd(r[124]), .s(s[124]), .clk(clk), .out({dg1_9, dg0_9}));
MSKand_opini2_d2 u_dt_9 (
    .ina({d_fc1[9], d_fc0[9]}), .inb({dp1_9, dp0_9}),
    .rnd(r[125]), .s(s[125]), .clk(clk), .out({dt1_9, dt0_9}));
assign d_fc0[10] = dg0_9 ^ dt0_9;
assign d_fc1[10] = dg1_9 ^ dt1_9;
wire dp0_10 = d_Rsh_d0[10] ^ d_Bn0[10];
wire dp1_10 = d_Rsh_d1[10] ^ d_Bn1[10];
wire dg0_10, dg1_10, dt0_10, dt1_10;
MSKand_opini2_d2 u_dg_10 (
    .ina({d_Rsh_d1[10], d_Rsh_d0[10]}), .inb({d_Bn1[10], d_Bn0[10]}),
    .rnd(r[126]), .s(s[126]), .clk(clk), .out({dg1_10, dg0_10}));
MSKand_opini2_d2 u_dt_10 (
    .ina({d_fc1[10], d_fc0[10]}), .inb({dp1_10, dp0_10}),
    .rnd(r[127]), .s(s[127]), .clk(clk), .out({dt1_10, dt0_10}));
assign d_fc0[11] = dg0_10 ^ dt0_10;
assign d_fc1[11] = dg1_10 ^ dt1_10;
wire dp0_11 = d_Rsh_d0[11] ^ d_Bn0[11];
wire dp1_11 = d_Rsh_d1[11] ^ d_Bn1[11];
wire dg0_11, dg1_11, dt0_11, dt1_11;
MSKand_opini2_d2 u_dg_11 (
    .ina({d_Rsh_d1[11], d_Rsh_d0[11]}), .inb({d_Bn1[11], d_Bn0[11]}),
    .rnd(r[128]), .s(s[128]), .clk(clk), .out({dg1_11, dg0_11}));
MSKand_opini2_d2 u_dt_11 (
    .ina({d_fc1[11], d_fc0[11]}), .inb({dp1_11, dp0_11}),
    .rnd(r[129]), .s(s[129]), .clk(clk), .out({dt1_11, dt0_11}));
assign d_fc0[12] = dg0_11 ^ dt0_11;
assign d_fc1[12] = dg1_11 ^ dt1_11;
wire dp0_12 = d_Rsh_d0[12] ^ d_Bn0[12];
wire dp1_12 = d_Rsh_d1[12] ^ d_Bn1[12];
wire dg0_12, dg1_12, dt0_12, dt1_12;
MSKand_opini2_d2 u_dg_12 (
    .ina({d_Rsh_d1[12], d_Rsh_d0[12]}), .inb({d_Bn1[12], d_Bn0[12]}),
    .rnd(r[130]), .s(s[130]), .clk(clk), .out({dg1_12, dg0_12}));
MSKand_opini2_d2 u_dt_12 (
    .ina({d_fc1[12], d_fc0[12]}), .inb({dp1_12, dp0_12}),
    .rnd(r[131]), .s(s[131]), .clk(clk), .out({dt1_12, dt0_12}));
assign d_fc0[13] = dg0_12 ^ dt0_12;
assign d_fc1[13] = dg1_12 ^ dt1_12;
wire dp0_13 = d_Rsh_d0[13] ^ d_Bn0[13];
wire dp1_13 = d_Rsh_d1[13] ^ d_Bn1[13];
wire dg0_13, dg1_13, dt0_13, dt1_13;
MSKand_opini2_d2 u_dg_13 (
    .ina({d_Rsh_d1[13], d_Rsh_d0[13]}), .inb({d_Bn1[13], d_Bn0[13]}),
    .rnd(r[132]), .s(s[132]), .clk(clk), .out({dg1_13, dg0_13}));
MSKand_opini2_d2 u_dt_13 (
    .ina({d_fc1[13], d_fc0[13]}), .inb({dp1_13, dp0_13}),
    .rnd(r[133]), .s(s[133]), .clk(clk), .out({dt1_13, dt0_13}));
assign d_fc0[14] = dg0_13 ^ dt0_13;
assign d_fc1[14] = dg1_13 ^ dt1_13;
wire dp0_14 = d_Rsh_d0[14] ^ d_Bn0[14];
wire dp1_14 = d_Rsh_d1[14] ^ d_Bn1[14];
wire dg0_14, dg1_14, dt0_14, dt1_14;
MSKand_opini2_d2 u_dg_14 (
    .ina({d_Rsh_d1[14], d_Rsh_d0[14]}), .inb({d_Bn1[14], d_Bn0[14]}),
    .rnd(r[134]), .s(s[134]), .clk(clk), .out({dg1_14, dg0_14}));
MSKand_opini2_d2 u_dt_14 (
    .ina({d_fc1[14], d_fc0[14]}), .inb({dp1_14, dp0_14}),
    .rnd(r[135]), .s(s[135]), .clk(clk), .out({dt1_14, dt0_14}));
assign d_fc0[15] = dg0_14 ^ dt0_14;
assign d_fc1[15] = dg1_14 ^ dt1_14;
wire dp0_15 = d_Rsh_d0[15] ^ d_Bn0[15];
wire dp1_15 = d_Rsh_d1[15] ^ d_Bn1[15];
wire dg0_15, dg1_15, dt0_15, dt1_15;
MSKand_opini2_d2 u_dg_15 (
    .ina({d_Rsh_d1[15], d_Rsh_d0[15]}), .inb({d_Bn1[15], d_Bn0[15]}),
    .rnd(r[136]), .s(s[136]), .clk(clk), .out({dg1_15, dg0_15}));
MSKand_opini2_d2 u_dt_15 (
    .ina({d_fc1[15], d_fc0[15]}), .inb({dp1_15, dp0_15}),
    .rnd(r[137]), .s(s[137]), .clk(clk), .out({dt1_15, dt0_15}));
assign d_fc0[16] = dg0_15 ^ dt0_15;
assign d_fc1[16] = dg1_15 ^ dt1_15;
wire dp0_16 = d_Rsh_d0[16] ^ 1'b1;
wire dp1_16 = d_Rsh_d1[16] ^ 1'b0;
wire dg0_16, dg1_16, dt0_16, dt1_16;
MSKand_opini2_d2 u_dg_16 (
    .ina({d_Rsh_d1[16], d_Rsh_d0[16]}), .inb({1'b0, 1'b1}),
    .rnd(r[138]), .s(s[138]), .clk(clk), .out({dg1_16, dg0_16}));
MSKand_opini2_d2 u_dt_16 (
    .ina({d_fc1[16], d_fc0[16]}), .inb({dp1_16, dp0_16}),
    .rnd(r[139]), .s(s[139]), .clk(clk), .out({dt1_16, dt0_16}));
assign d_coutw0 = dg0_16 ^ dt0_16;
assign d_coutw1 = dg1_16 ^ dt1_16;
// difference bits (only [15:0] needed: both R' branches are < denom < 2^16)
assign d_T0[0] = dp0_0 ^ d_fc0[0];  assign d_T1[0] = dp1_0 ^ d_fc1[0];
assign d_T0[1] = dp0_1 ^ d_fc0[1];  assign d_T1[1] = dp1_1 ^ d_fc1[1];
assign d_T0[2] = dp0_2 ^ d_fc0[2];  assign d_T1[2] = dp1_2 ^ d_fc1[2];
assign d_T0[3] = dp0_3 ^ d_fc0[3];  assign d_T1[3] = dp1_3 ^ d_fc1[3];
assign d_T0[4] = dp0_4 ^ d_fc0[4];  assign d_T1[4] = dp1_4 ^ d_fc1[4];
assign d_T0[5] = dp0_5 ^ d_fc0[5];  assign d_T1[5] = dp1_5 ^ d_fc1[5];
assign d_T0[6] = dp0_6 ^ d_fc0[6];  assign d_T1[6] = dp1_6 ^ d_fc1[6];
assign d_T0[7] = dp0_7 ^ d_fc0[7];  assign d_T1[7] = dp1_7 ^ d_fc1[7];
assign d_T0[8] = dp0_8 ^ d_fc0[8];  assign d_T1[8] = dp1_8 ^ d_fc1[8];
assign d_T0[9] = dp0_9 ^ d_fc0[9];  assign d_T1[9] = dp1_9 ^ d_fc1[9];
assign d_T0[10] = dp0_10 ^ d_fc0[10];  assign d_T1[10] = dp1_10 ^ d_fc1[10];
assign d_T0[11] = dp0_11 ^ d_fc0[11];  assign d_T1[11] = dp1_11 ^ d_fc1[11];
assign d_T0[12] = dp0_12 ^ d_fc0[12];  assign d_T1[12] = dp1_12 ^ d_fc1[12];
assign d_T0[13] = dp0_13 ^ d_fc0[13];  assign d_T1[13] = dp1_13 ^ d_fc1[13];
assign d_T0[14] = dp0_14 ^ d_fc0[14];  assign d_T1[14] = dp1_14 ^ d_fc1[14];
assign d_T0[15] = dp0_15 ^ d_fc0[15];  assign d_T1[15] = dp1_15 ^ d_fc1[15];

// ===== div borrow-mux: w_dm[j] = d_coutr AND d_xm[j] (broadcast) =====
MSKand_opini2_d2 u_dm_0 (
    .ina({d_xm_d1[0], d_xm_d0[0]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[140]), .s(s[140]), .clk(clk), .out({w_dm1[0], w_dm0[0]}));
MSKand_opini2_d2 u_dm_1 (  // BUG UNDER TEST: reuses u_dm_0's randomness
    .ina({d_xm_d1[1], d_xm_d0[1]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[140]), .s(s[140]), .clk(clk), .out({w_dm1[1], w_dm0[1]}));
MSKand_opini2_d2 u_dm_2 (
    .ina({d_xm_d1[2], d_xm_d0[2]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[142]), .s(s[142]), .clk(clk), .out({w_dm1[2], w_dm0[2]}));
MSKand_opini2_d2 u_dm_3 (
    .ina({d_xm_d1[3], d_xm_d0[3]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[143]), .s(s[143]), .clk(clk), .out({w_dm1[3], w_dm0[3]}));
MSKand_opini2_d2 u_dm_4 (
    .ina({d_xm_d1[4], d_xm_d0[4]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[144]), .s(s[144]), .clk(clk), .out({w_dm1[4], w_dm0[4]}));
MSKand_opini2_d2 u_dm_5 (
    .ina({d_xm_d1[5], d_xm_d0[5]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[145]), .s(s[145]), .clk(clk), .out({w_dm1[5], w_dm0[5]}));
MSKand_opini2_d2 u_dm_6 (
    .ina({d_xm_d1[6], d_xm_d0[6]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[146]), .s(s[146]), .clk(clk), .out({w_dm1[6], w_dm0[6]}));
MSKand_opini2_d2 u_dm_7 (
    .ina({d_xm_d1[7], d_xm_d0[7]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[147]), .s(s[147]), .clk(clk), .out({w_dm1[7], w_dm0[7]}));
MSKand_opini2_d2 u_dm_8 (
    .ina({d_xm_d1[8], d_xm_d0[8]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[148]), .s(s[148]), .clk(clk), .out({w_dm1[8], w_dm0[8]}));
MSKand_opini2_d2 u_dm_9 (
    .ina({d_xm_d1[9], d_xm_d0[9]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[149]), .s(s[149]), .clk(clk), .out({w_dm1[9], w_dm0[9]}));
MSKand_opini2_d2 u_dm_10 (
    .ina({d_xm_d1[10], d_xm_d0[10]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[150]), .s(s[150]), .clk(clk), .out({w_dm1[10], w_dm0[10]}));
MSKand_opini2_d2 u_dm_11 (
    .ina({d_xm_d1[11], d_xm_d0[11]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[151]), .s(s[151]), .clk(clk), .out({w_dm1[11], w_dm0[11]}));
MSKand_opini2_d2 u_dm_12 (
    .ina({d_xm_d1[12], d_xm_d0[12]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[152]), .s(s[152]), .clk(clk), .out({w_dm1[12], w_dm0[12]}));
MSKand_opini2_d2 u_dm_13 (
    .ina({d_xm_d1[13], d_xm_d0[13]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[153]), .s(s[153]), .clk(clk), .out({w_dm1[13], w_dm0[13]}));
MSKand_opini2_d2 u_dm_14 (
    .ina({d_xm_d1[14], d_xm_d0[14]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[154]), .s(s[154]), .clk(clk), .out({w_dm1[14], w_dm0[14]}));
MSKand_opini2_d2 u_dm_15 (
    .ina({d_xm_d1[15], d_xm_d0[15]}), .inb({d_coutr1, d_coutr0}),
    .rnd(r[155]), .s(s[155]), .clk(clk), .out({w_dm1[15], w_dm0[15]}));

// ===== slippage compare: ok = (aout >= mo) via subtract borrow-out (sub=1) =====
// c_fc[0] = carry-in = public 1; b share 0 complemented share-locally (~mo).
wire [16:0] c_fc0, c_fc1;
assign c_fc0[0] = 1'b1;
assign c_fc1[0] = 1'b0;
wire cb0_0 = ~hmo0[0];
wire cp0_0 = d_Q_d0[0] ^ cb0_0;
wire cp1_0 = d_Q_d1[0] ^ hmo1[0];
wire cg0_0, cg1_0, ct0_0, ct1_0;
MSKand_opini2_d2 u_cg_0 (
    .ina({d_Q_d1[0], d_Q_d0[0]}), .inb({hmo1[0], cb0_0}),
    .rnd(r[156]), .s(s[156]), .clk(clk), .out({cg1_0, cg0_0}));
MSKand_opini2_d2 u_ct_0 (
    .ina({c_fc1[0], c_fc0[0]}), .inb({cp1_0, cp0_0}),
    .rnd(r[157]), .s(s[157]), .clk(clk), .out({ct1_0, ct0_0}));
assign c_fc0[1] = cg0_0 ^ ct0_0;
assign c_fc1[1] = cg1_0 ^ ct1_0;
wire cb0_1 = ~hmo0[1];
wire cp0_1 = d_Q_d0[1] ^ cb0_1;
wire cp1_1 = d_Q_d1[1] ^ hmo1[1];
wire cg0_1, cg1_1, ct0_1, ct1_1;
MSKand_opini2_d2 u_cg_1 (
    .ina({d_Q_d1[1], d_Q_d0[1]}), .inb({hmo1[1], cb0_1}),
    .rnd(r[158]), .s(s[158]), .clk(clk), .out({cg1_1, cg0_1}));
MSKand_opini2_d2 u_ct_1 (
    .ina({c_fc1[1], c_fc0[1]}), .inb({cp1_1, cp0_1}),
    .rnd(r[159]), .s(s[159]), .clk(clk), .out({ct1_1, ct0_1}));
assign c_fc0[2] = cg0_1 ^ ct0_1;
assign c_fc1[2] = cg1_1 ^ ct1_1;
wire cb0_2 = ~hmo0[2];
wire cp0_2 = d_Q_d0[2] ^ cb0_2;
wire cp1_2 = d_Q_d1[2] ^ hmo1[2];
wire cg0_2, cg1_2, ct0_2, ct1_2;
MSKand_opini2_d2 u_cg_2 (
    .ina({d_Q_d1[2], d_Q_d0[2]}), .inb({hmo1[2], cb0_2}),
    .rnd(r[160]), .s(s[160]), .clk(clk), .out({cg1_2, cg0_2}));
MSKand_opini2_d2 u_ct_2 (
    .ina({c_fc1[2], c_fc0[2]}), .inb({cp1_2, cp0_2}),
    .rnd(r[161]), .s(s[161]), .clk(clk), .out({ct1_2, ct0_2}));
assign c_fc0[3] = cg0_2 ^ ct0_2;
assign c_fc1[3] = cg1_2 ^ ct1_2;
wire cb0_3 = ~hmo0[3];
wire cp0_3 = d_Q_d0[3] ^ cb0_3;
wire cp1_3 = d_Q_d1[3] ^ hmo1[3];
wire cg0_3, cg1_3, ct0_3, ct1_3;
MSKand_opini2_d2 u_cg_3 (
    .ina({d_Q_d1[3], d_Q_d0[3]}), .inb({hmo1[3], cb0_3}),
    .rnd(r[162]), .s(s[162]), .clk(clk), .out({cg1_3, cg0_3}));
MSKand_opini2_d2 u_ct_3 (
    .ina({c_fc1[3], c_fc0[3]}), .inb({cp1_3, cp0_3}),
    .rnd(r[163]), .s(s[163]), .clk(clk), .out({ct1_3, ct0_3}));
assign c_fc0[4] = cg0_3 ^ ct0_3;
assign c_fc1[4] = cg1_3 ^ ct1_3;
wire cb0_4 = ~hmo0[4];
wire cp0_4 = d_Q_d0[4] ^ cb0_4;
wire cp1_4 = d_Q_d1[4] ^ hmo1[4];
wire cg0_4, cg1_4, ct0_4, ct1_4;
MSKand_opini2_d2 u_cg_4 (
    .ina({d_Q_d1[4], d_Q_d0[4]}), .inb({hmo1[4], cb0_4}),
    .rnd(r[164]), .s(s[164]), .clk(clk), .out({cg1_4, cg0_4}));
MSKand_opini2_d2 u_ct_4 (
    .ina({c_fc1[4], c_fc0[4]}), .inb({cp1_4, cp0_4}),
    .rnd(r[165]), .s(s[165]), .clk(clk), .out({ct1_4, ct0_4}));
assign c_fc0[5] = cg0_4 ^ ct0_4;
assign c_fc1[5] = cg1_4 ^ ct1_4;
wire cb0_5 = ~hmo0[5];
wire cp0_5 = d_Q_d0[5] ^ cb0_5;
wire cp1_5 = d_Q_d1[5] ^ hmo1[5];
wire cg0_5, cg1_5, ct0_5, ct1_5;
MSKand_opini2_d2 u_cg_5 (
    .ina({d_Q_d1[5], d_Q_d0[5]}), .inb({hmo1[5], cb0_5}),
    .rnd(r[166]), .s(s[166]), .clk(clk), .out({cg1_5, cg0_5}));
MSKand_opini2_d2 u_ct_5 (
    .ina({c_fc1[5], c_fc0[5]}), .inb({cp1_5, cp0_5}),
    .rnd(r[167]), .s(s[167]), .clk(clk), .out({ct1_5, ct0_5}));
assign c_fc0[6] = cg0_5 ^ ct0_5;
assign c_fc1[6] = cg1_5 ^ ct1_5;
wire cb0_6 = ~hmo0[6];
wire cp0_6 = d_Q_d0[6] ^ cb0_6;
wire cp1_6 = d_Q_d1[6] ^ hmo1[6];
wire cg0_6, cg1_6, ct0_6, ct1_6;
MSKand_opini2_d2 u_cg_6 (
    .ina({d_Q_d1[6], d_Q_d0[6]}), .inb({hmo1[6], cb0_6}),
    .rnd(r[168]), .s(s[168]), .clk(clk), .out({cg1_6, cg0_6}));
MSKand_opini2_d2 u_ct_6 (
    .ina({c_fc1[6], c_fc0[6]}), .inb({cp1_6, cp0_6}),
    .rnd(r[169]), .s(s[169]), .clk(clk), .out({ct1_6, ct0_6}));
assign c_fc0[7] = cg0_6 ^ ct0_6;
assign c_fc1[7] = cg1_6 ^ ct1_6;
wire cb0_7 = ~hmo0[7];
wire cp0_7 = d_Q_d0[7] ^ cb0_7;
wire cp1_7 = d_Q_d1[7] ^ hmo1[7];
wire cg0_7, cg1_7, ct0_7, ct1_7;
MSKand_opini2_d2 u_cg_7 (
    .ina({d_Q_d1[7], d_Q_d0[7]}), .inb({hmo1[7], cb0_7}),
    .rnd(r[170]), .s(s[170]), .clk(clk), .out({cg1_7, cg0_7}));
MSKand_opini2_d2 u_ct_7 (
    .ina({c_fc1[7], c_fc0[7]}), .inb({cp1_7, cp0_7}),
    .rnd(r[171]), .s(s[171]), .clk(clk), .out({ct1_7, ct0_7}));
assign c_fc0[8] = cg0_7 ^ ct0_7;
assign c_fc1[8] = cg1_7 ^ ct1_7;
wire cb0_8 = ~hmo0[8];
wire cp0_8 = d_Q_d0[8] ^ cb0_8;
wire cp1_8 = d_Q_d1[8] ^ hmo1[8];
wire cg0_8, cg1_8, ct0_8, ct1_8;
MSKand_opini2_d2 u_cg_8 (
    .ina({d_Q_d1[8], d_Q_d0[8]}), .inb({hmo1[8], cb0_8}),
    .rnd(r[172]), .s(s[172]), .clk(clk), .out({cg1_8, cg0_8}));
MSKand_opini2_d2 u_ct_8 (
    .ina({c_fc1[8], c_fc0[8]}), .inb({cp1_8, cp0_8}),
    .rnd(r[173]), .s(s[173]), .clk(clk), .out({ct1_8, ct0_8}));
assign c_fc0[9] = cg0_8 ^ ct0_8;
assign c_fc1[9] = cg1_8 ^ ct1_8;
wire cb0_9 = ~hmo0[9];
wire cp0_9 = d_Q_d0[9] ^ cb0_9;
wire cp1_9 = d_Q_d1[9] ^ hmo1[9];
wire cg0_9, cg1_9, ct0_9, ct1_9;
MSKand_opini2_d2 u_cg_9 (
    .ina({d_Q_d1[9], d_Q_d0[9]}), .inb({hmo1[9], cb0_9}),
    .rnd(r[174]), .s(s[174]), .clk(clk), .out({cg1_9, cg0_9}));
MSKand_opini2_d2 u_ct_9 (
    .ina({c_fc1[9], c_fc0[9]}), .inb({cp1_9, cp0_9}),
    .rnd(r[175]), .s(s[175]), .clk(clk), .out({ct1_9, ct0_9}));
assign c_fc0[10] = cg0_9 ^ ct0_9;
assign c_fc1[10] = cg1_9 ^ ct1_9;
wire cb0_10 = ~hmo0[10];
wire cp0_10 = d_Q_d0[10] ^ cb0_10;
wire cp1_10 = d_Q_d1[10] ^ hmo1[10];
wire cg0_10, cg1_10, ct0_10, ct1_10;
MSKand_opini2_d2 u_cg_10 (
    .ina({d_Q_d1[10], d_Q_d0[10]}), .inb({hmo1[10], cb0_10}),
    .rnd(r[176]), .s(s[176]), .clk(clk), .out({cg1_10, cg0_10}));
MSKand_opini2_d2 u_ct_10 (
    .ina({c_fc1[10], c_fc0[10]}), .inb({cp1_10, cp0_10}),
    .rnd(r[177]), .s(s[177]), .clk(clk), .out({ct1_10, ct0_10}));
assign c_fc0[11] = cg0_10 ^ ct0_10;
assign c_fc1[11] = cg1_10 ^ ct1_10;
wire cb0_11 = ~hmo0[11];
wire cp0_11 = d_Q_d0[11] ^ cb0_11;
wire cp1_11 = d_Q_d1[11] ^ hmo1[11];
wire cg0_11, cg1_11, ct0_11, ct1_11;
MSKand_opini2_d2 u_cg_11 (
    .ina({d_Q_d1[11], d_Q_d0[11]}), .inb({hmo1[11], cb0_11}),
    .rnd(r[178]), .s(s[178]), .clk(clk), .out({cg1_11, cg0_11}));
MSKand_opini2_d2 u_ct_11 (
    .ina({c_fc1[11], c_fc0[11]}), .inb({cp1_11, cp0_11}),
    .rnd(r[179]), .s(s[179]), .clk(clk), .out({ct1_11, ct0_11}));
assign c_fc0[12] = cg0_11 ^ ct0_11;
assign c_fc1[12] = cg1_11 ^ ct1_11;
wire cb0_12 = ~hmo0[12];
wire cp0_12 = d_Q_d0[12] ^ cb0_12;
wire cp1_12 = d_Q_d1[12] ^ hmo1[12];
wire cg0_12, cg1_12, ct0_12, ct1_12;
MSKand_opini2_d2 u_cg_12 (
    .ina({d_Q_d1[12], d_Q_d0[12]}), .inb({hmo1[12], cb0_12}),
    .rnd(r[180]), .s(s[180]), .clk(clk), .out({cg1_12, cg0_12}));
MSKand_opini2_d2 u_ct_12 (
    .ina({c_fc1[12], c_fc0[12]}), .inb({cp1_12, cp0_12}),
    .rnd(r[181]), .s(s[181]), .clk(clk), .out({ct1_12, ct0_12}));
assign c_fc0[13] = cg0_12 ^ ct0_12;
assign c_fc1[13] = cg1_12 ^ ct1_12;
wire cb0_13 = ~hmo0[13];
wire cp0_13 = d_Q_d0[13] ^ cb0_13;
wire cp1_13 = d_Q_d1[13] ^ hmo1[13];
wire cg0_13, cg1_13, ct0_13, ct1_13;
MSKand_opini2_d2 u_cg_13 (
    .ina({d_Q_d1[13], d_Q_d0[13]}), .inb({hmo1[13], cb0_13}),
    .rnd(r[182]), .s(s[182]), .clk(clk), .out({cg1_13, cg0_13}));
MSKand_opini2_d2 u_ct_13 (
    .ina({c_fc1[13], c_fc0[13]}), .inb({cp1_13, cp0_13}),
    .rnd(r[183]), .s(s[183]), .clk(clk), .out({ct1_13, ct0_13}));
assign c_fc0[14] = cg0_13 ^ ct0_13;
assign c_fc1[14] = cg1_13 ^ ct1_13;
wire cb0_14 = ~hmo0[14];
wire cp0_14 = d_Q_d0[14] ^ cb0_14;
wire cp1_14 = d_Q_d1[14] ^ hmo1[14];
wire cg0_14, cg1_14, ct0_14, ct1_14;
MSKand_opini2_d2 u_cg_14 (
    .ina({d_Q_d1[14], d_Q_d0[14]}), .inb({hmo1[14], cb0_14}),
    .rnd(r[184]), .s(s[184]), .clk(clk), .out({cg1_14, cg0_14}));
MSKand_opini2_d2 u_ct_14 (
    .ina({c_fc1[14], c_fc0[14]}), .inb({cp1_14, cp0_14}),
    .rnd(r[185]), .s(s[185]), .clk(clk), .out({ct1_14, ct0_14}));
assign c_fc0[15] = cg0_14 ^ ct0_14;
assign c_fc1[15] = cg1_14 ^ ct1_14;
wire cb0_15 = ~hmo0[15];
wire cp0_15 = d_Q_d0[15] ^ cb0_15;
wire cp1_15 = d_Q_d1[15] ^ hmo1[15];
wire cg0_15, cg1_15, ct0_15, ct1_15;
MSKand_opini2_d2 u_cg_15 (
    .ina({d_Q_d1[15], d_Q_d0[15]}), .inb({hmo1[15], cb0_15}),
    .rnd(r[186]), .s(s[186]), .clk(clk), .out({cg1_15, cg0_15}));
MSKand_opini2_d2 u_ct_15 (
    .ina({c_fc1[15], c_fc0[15]}), .inb({cp1_15, cp0_15}),
    .rnd(r[187]), .s(s[187]), .clk(clk), .out({ct1_15, ct0_15}));
assign c_fc0[16] = cg0_15 ^ ct0_15;
assign c_fc1[16] = cg1_15 ^ ct1_15;
assign c_coutw0 = c_fc0[16];
assign c_coutw1 = c_fc1[16];

// ===== reserve update: nro = ro - aout mod 2^16 (verified-adder dataflow, sub=1) =====
wire [14:0] s_fc0, s_fc1;
assign s_fc0[0] = 1'b1;
assign s_fc1[0] = 1'b0;
wire sb0_0 = ~d_Q0[0];
wire sp0_0 = hro_d0[0] ^ sb0_0;
wire sp1_0 = hro_d1[0] ^ d_Q1[0];
wire sg0_0, sg1_0, st0_0, st1_0;
MSKand_opini2_d2 u_sg_0 (
    .ina({hro_d1[0], hro_d0[0]}), .inb({d_Q1[0], sb0_0}),
    .rnd(r[188]), .s(s[188]), .clk(clk), .out({sg1_0, sg0_0}));
MSKand_opini2_d2 u_st_0 (
    .ina({s_fc1[0], s_fc0[0]}), .inb({sp1_0, sp0_0}),
    .rnd(r[189]), .s(s[189]), .clk(clk), .out({st1_0, st0_0}));
assign s_fc0[1] = sg0_0 ^ st0_0;
assign s_fc1[1] = sg1_0 ^ st1_0;
assign s_sum0[0] = sp0_0 ^ s_fc0[0];
assign s_sum1[0] = sp1_0 ^ s_fc1[0];
wire sb0_1 = ~d_Q0[1];
wire sp0_1 = hro_d0[1] ^ sb0_1;
wire sp1_1 = hro_d1[1] ^ d_Q1[1];
wire sg0_1, sg1_1, st0_1, st1_1;
MSKand_opini2_d2 u_sg_1 (
    .ina({hro_d1[1], hro_d0[1]}), .inb({d_Q1[1], sb0_1}),
    .rnd(r[190]), .s(s[190]), .clk(clk), .out({sg1_1, sg0_1}));
MSKand_opini2_d2 u_st_1 (
    .ina({s_fc1[1], s_fc0[1]}), .inb({sp1_1, sp0_1}),
    .rnd(r[191]), .s(s[191]), .clk(clk), .out({st1_1, st0_1}));
assign s_fc0[2] = sg0_1 ^ st0_1;
assign s_fc1[2] = sg1_1 ^ st1_1;
assign s_sum0[1] = sp0_1 ^ s_fc0[1];
assign s_sum1[1] = sp1_1 ^ s_fc1[1];
wire sb0_2 = ~d_Q0[2];
wire sp0_2 = hro_d0[2] ^ sb0_2;
wire sp1_2 = hro_d1[2] ^ d_Q1[2];
wire sg0_2, sg1_2, st0_2, st1_2;
MSKand_opini2_d2 u_sg_2 (
    .ina({hro_d1[2], hro_d0[2]}), .inb({d_Q1[2], sb0_2}),
    .rnd(r[192]), .s(s[192]), .clk(clk), .out({sg1_2, sg0_2}));
MSKand_opini2_d2 u_st_2 (
    .ina({s_fc1[2], s_fc0[2]}), .inb({sp1_2, sp0_2}),
    .rnd(r[193]), .s(s[193]), .clk(clk), .out({st1_2, st0_2}));
assign s_fc0[3] = sg0_2 ^ st0_2;
assign s_fc1[3] = sg1_2 ^ st1_2;
assign s_sum0[2] = sp0_2 ^ s_fc0[2];
assign s_sum1[2] = sp1_2 ^ s_fc1[2];
wire sb0_3 = ~d_Q0[3];
wire sp0_3 = hro_d0[3] ^ sb0_3;
wire sp1_3 = hro_d1[3] ^ d_Q1[3];
wire sg0_3, sg1_3, st0_3, st1_3;
MSKand_opini2_d2 u_sg_3 (
    .ina({hro_d1[3], hro_d0[3]}), .inb({d_Q1[3], sb0_3}),
    .rnd(r[194]), .s(s[194]), .clk(clk), .out({sg1_3, sg0_3}));
MSKand_opini2_d2 u_st_3 (
    .ina({s_fc1[3], s_fc0[3]}), .inb({sp1_3, sp0_3}),
    .rnd(r[195]), .s(s[195]), .clk(clk), .out({st1_3, st0_3}));
assign s_fc0[4] = sg0_3 ^ st0_3;
assign s_fc1[4] = sg1_3 ^ st1_3;
assign s_sum0[3] = sp0_3 ^ s_fc0[3];
assign s_sum1[3] = sp1_3 ^ s_fc1[3];
wire sb0_4 = ~d_Q0[4];
wire sp0_4 = hro_d0[4] ^ sb0_4;
wire sp1_4 = hro_d1[4] ^ d_Q1[4];
wire sg0_4, sg1_4, st0_4, st1_4;
MSKand_opini2_d2 u_sg_4 (
    .ina({hro_d1[4], hro_d0[4]}), .inb({d_Q1[4], sb0_4}),
    .rnd(r[196]), .s(s[196]), .clk(clk), .out({sg1_4, sg0_4}));
MSKand_opini2_d2 u_st_4 (
    .ina({s_fc1[4], s_fc0[4]}), .inb({sp1_4, sp0_4}),
    .rnd(r[197]), .s(s[197]), .clk(clk), .out({st1_4, st0_4}));
assign s_fc0[5] = sg0_4 ^ st0_4;
assign s_fc1[5] = sg1_4 ^ st1_4;
assign s_sum0[4] = sp0_4 ^ s_fc0[4];
assign s_sum1[4] = sp1_4 ^ s_fc1[4];
wire sb0_5 = ~d_Q0[5];
wire sp0_5 = hro_d0[5] ^ sb0_5;
wire sp1_5 = hro_d1[5] ^ d_Q1[5];
wire sg0_5, sg1_5, st0_5, st1_5;
MSKand_opini2_d2 u_sg_5 (
    .ina({hro_d1[5], hro_d0[5]}), .inb({d_Q1[5], sb0_5}),
    .rnd(r[198]), .s(s[198]), .clk(clk), .out({sg1_5, sg0_5}));
MSKand_opini2_d2 u_st_5 (
    .ina({s_fc1[5], s_fc0[5]}), .inb({sp1_5, sp0_5}),
    .rnd(r[199]), .s(s[199]), .clk(clk), .out({st1_5, st0_5}));
assign s_fc0[6] = sg0_5 ^ st0_5;
assign s_fc1[6] = sg1_5 ^ st1_5;
assign s_sum0[5] = sp0_5 ^ s_fc0[5];
assign s_sum1[5] = sp1_5 ^ s_fc1[5];
wire sb0_6 = ~d_Q0[6];
wire sp0_6 = hro_d0[6] ^ sb0_6;
wire sp1_6 = hro_d1[6] ^ d_Q1[6];
wire sg0_6, sg1_6, st0_6, st1_6;
MSKand_opini2_d2 u_sg_6 (
    .ina({hro_d1[6], hro_d0[6]}), .inb({d_Q1[6], sb0_6}),
    .rnd(r[200]), .s(s[200]), .clk(clk), .out({sg1_6, sg0_6}));
MSKand_opini2_d2 u_st_6 (
    .ina({s_fc1[6], s_fc0[6]}), .inb({sp1_6, sp0_6}),
    .rnd(r[201]), .s(s[201]), .clk(clk), .out({st1_6, st0_6}));
assign s_fc0[7] = sg0_6 ^ st0_6;
assign s_fc1[7] = sg1_6 ^ st1_6;
assign s_sum0[6] = sp0_6 ^ s_fc0[6];
assign s_sum1[6] = sp1_6 ^ s_fc1[6];
wire sb0_7 = ~d_Q0[7];
wire sp0_7 = hro_d0[7] ^ sb0_7;
wire sp1_7 = hro_d1[7] ^ d_Q1[7];
wire sg0_7, sg1_7, st0_7, st1_7;
MSKand_opini2_d2 u_sg_7 (
    .ina({hro_d1[7], hro_d0[7]}), .inb({d_Q1[7], sb0_7}),
    .rnd(r[202]), .s(s[202]), .clk(clk), .out({sg1_7, sg0_7}));
MSKand_opini2_d2 u_st_7 (
    .ina({s_fc1[7], s_fc0[7]}), .inb({sp1_7, sp0_7}),
    .rnd(r[203]), .s(s[203]), .clk(clk), .out({st1_7, st0_7}));
assign s_fc0[8] = sg0_7 ^ st0_7;
assign s_fc1[8] = sg1_7 ^ st1_7;
assign s_sum0[7] = sp0_7 ^ s_fc0[7];
assign s_sum1[7] = sp1_7 ^ s_fc1[7];
wire sb0_8 = ~d_Q0[8];
wire sp0_8 = hro_d0[8] ^ sb0_8;
wire sp1_8 = hro_d1[8] ^ d_Q1[8];
wire sg0_8, sg1_8, st0_8, st1_8;
MSKand_opini2_d2 u_sg_8 (
    .ina({hro_d1[8], hro_d0[8]}), .inb({d_Q1[8], sb0_8}),
    .rnd(r[204]), .s(s[204]), .clk(clk), .out({sg1_8, sg0_8}));
MSKand_opini2_d2 u_st_8 (
    .ina({s_fc1[8], s_fc0[8]}), .inb({sp1_8, sp0_8}),
    .rnd(r[205]), .s(s[205]), .clk(clk), .out({st1_8, st0_8}));
assign s_fc0[9] = sg0_8 ^ st0_8;
assign s_fc1[9] = sg1_8 ^ st1_8;
assign s_sum0[8] = sp0_8 ^ s_fc0[8];
assign s_sum1[8] = sp1_8 ^ s_fc1[8];
wire sb0_9 = ~d_Q0[9];
wire sp0_9 = hro_d0[9] ^ sb0_9;
wire sp1_9 = hro_d1[9] ^ d_Q1[9];
wire sg0_9, sg1_9, st0_9, st1_9;
MSKand_opini2_d2 u_sg_9 (
    .ina({hro_d1[9], hro_d0[9]}), .inb({d_Q1[9], sb0_9}),
    .rnd(r[206]), .s(s[206]), .clk(clk), .out({sg1_9, sg0_9}));
MSKand_opini2_d2 u_st_9 (
    .ina({s_fc1[9], s_fc0[9]}), .inb({sp1_9, sp0_9}),
    .rnd(r[207]), .s(s[207]), .clk(clk), .out({st1_9, st0_9}));
assign s_fc0[10] = sg0_9 ^ st0_9;
assign s_fc1[10] = sg1_9 ^ st1_9;
assign s_sum0[9] = sp0_9 ^ s_fc0[9];
assign s_sum1[9] = sp1_9 ^ s_fc1[9];
wire sb0_10 = ~d_Q0[10];
wire sp0_10 = hro_d0[10] ^ sb0_10;
wire sp1_10 = hro_d1[10] ^ d_Q1[10];
wire sg0_10, sg1_10, st0_10, st1_10;
MSKand_opini2_d2 u_sg_10 (
    .ina({hro_d1[10], hro_d0[10]}), .inb({d_Q1[10], sb0_10}),
    .rnd(r[208]), .s(s[208]), .clk(clk), .out({sg1_10, sg0_10}));
MSKand_opini2_d2 u_st_10 (
    .ina({s_fc1[10], s_fc0[10]}), .inb({sp1_10, sp0_10}),
    .rnd(r[209]), .s(s[209]), .clk(clk), .out({st1_10, st0_10}));
assign s_fc0[11] = sg0_10 ^ st0_10;
assign s_fc1[11] = sg1_10 ^ st1_10;
assign s_sum0[10] = sp0_10 ^ s_fc0[10];
assign s_sum1[10] = sp1_10 ^ s_fc1[10];
wire sb0_11 = ~d_Q0[11];
wire sp0_11 = hro_d0[11] ^ sb0_11;
wire sp1_11 = hro_d1[11] ^ d_Q1[11];
wire sg0_11, sg1_11, st0_11, st1_11;
MSKand_opini2_d2 u_sg_11 (
    .ina({hro_d1[11], hro_d0[11]}), .inb({d_Q1[11], sb0_11}),
    .rnd(r[210]), .s(s[210]), .clk(clk), .out({sg1_11, sg0_11}));
MSKand_opini2_d2 u_st_11 (
    .ina({s_fc1[11], s_fc0[11]}), .inb({sp1_11, sp0_11}),
    .rnd(r[211]), .s(s[211]), .clk(clk), .out({st1_11, st0_11}));
assign s_fc0[12] = sg0_11 ^ st0_11;
assign s_fc1[12] = sg1_11 ^ st1_11;
assign s_sum0[11] = sp0_11 ^ s_fc0[11];
assign s_sum1[11] = sp1_11 ^ s_fc1[11];
wire sb0_12 = ~d_Q0[12];
wire sp0_12 = hro_d0[12] ^ sb0_12;
wire sp1_12 = hro_d1[12] ^ d_Q1[12];
wire sg0_12, sg1_12, st0_12, st1_12;
MSKand_opini2_d2 u_sg_12 (
    .ina({hro_d1[12], hro_d0[12]}), .inb({d_Q1[12], sb0_12}),
    .rnd(r[212]), .s(s[212]), .clk(clk), .out({sg1_12, sg0_12}));
MSKand_opini2_d2 u_st_12 (
    .ina({s_fc1[12], s_fc0[12]}), .inb({sp1_12, sp0_12}),
    .rnd(r[213]), .s(s[213]), .clk(clk), .out({st1_12, st0_12}));
assign s_fc0[13] = sg0_12 ^ st0_12;
assign s_fc1[13] = sg1_12 ^ st1_12;
assign s_sum0[12] = sp0_12 ^ s_fc0[12];
assign s_sum1[12] = sp1_12 ^ s_fc1[12];
wire sb0_13 = ~d_Q0[13];
wire sp0_13 = hro_d0[13] ^ sb0_13;
wire sp1_13 = hro_d1[13] ^ d_Q1[13];
wire sg0_13, sg1_13, st0_13, st1_13;
MSKand_opini2_d2 u_sg_13 (
    .ina({hro_d1[13], hro_d0[13]}), .inb({d_Q1[13], sb0_13}),
    .rnd(r[214]), .s(s[214]), .clk(clk), .out({sg1_13, sg0_13}));
MSKand_opini2_d2 u_st_13 (
    .ina({s_fc1[13], s_fc0[13]}), .inb({sp1_13, sp0_13}),
    .rnd(r[215]), .s(s[215]), .clk(clk), .out({st1_13, st0_13}));
assign s_fc0[14] = sg0_13 ^ st0_13;
assign s_fc1[14] = sg1_13 ^ st1_13;
assign s_sum0[13] = sp0_13 ^ s_fc0[13];
assign s_sum1[13] = sp1_13 ^ s_fc1[13];
wire sb0_14 = ~d_Q0[14];
wire sp0_14 = hro_d0[14] ^ sb0_14;
wire sp1_14 = hro_d1[14] ^ d_Q1[14];
wire sg0_14, sg1_14, st0_14, st1_14;
MSKand_opini2_d2 u_sg_14 (
    .ina({hro_d1[14], hro_d0[14]}), .inb({d_Q1[14], sb0_14}),
    .rnd(r[216]), .s(s[216]), .clk(clk), .out({sg1_14, sg0_14}));
MSKand_opini2_d2 u_st_14 (
    .ina({s_fc1[14], s_fc0[14]}), .inb({sp1_14, sp0_14}),
    .rnd(r[217]), .s(s[217]), .clk(clk), .out({st1_14, st0_14}));
wire s_fct0 = sg0_14 ^ st0_14;
wire s_fct1 = sg1_14 ^ st1_14;
assign s_sum0[14] = sp0_14 ^ s_fc0[14];
assign s_sum1[14] = sp1_14 ^ s_fc1[14];
// top bit: sum only, carry-out dropped (mod 2^16, EVM SUB)
wire sb0_15 = ~d_Q0[15];
wire sp0_15 = hro_d0[15] ^ sb0_15;
wire sp1_15 = hro_d1[15] ^ d_Q1[15];
assign s_sum0[15] = sp0_15 ^ s_fct0;
assign s_sum1[15] = sp1_15 ^ s_fct1;

endmodule
