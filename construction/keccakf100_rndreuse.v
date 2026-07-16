// NEGATIVE CONTROL (must FAIL): identical to the target except u_chi_1
// consumes the SAME random bits as u_chi_0, active in the same cycles,
// instead of its dedicated pair. MATCHI must report multi-use.
// Masked Keccak-f[100] (16 rounds, w=4): one masked round unit — chi via
// 100 assumed-OPINI gadget leaves u_chi_* (one per state bit, DEDICATED
// r[k]/s[k] each), theta/rho/pi/iota strictly share-local — iterated in place
// by a public FSM. Dense sharing layout: port[2i]=share0, port[2i+1]=share1,
// state flat index w*(5y+x)+z (Keccak spec ordering).
// Schedule: load @0; round i occupies cycles [1+6i, 6+6i]; o (register)
// stable from cycle 97; state cleared (share-local, to public 0) at
// cycle 108; randoms fresh [0,118].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module keccakf100_rndreuse (clk, rst, go, a, r, s, o);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [199:0] a;
(* matchi_type = "random", matchi_active = "r_act" *) input [99:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [99:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [199:0] o;

// ---- activity windows from an idempotent cycle counter (public control;
// counts 1.. from the go pulse, saturates — the div256 pattern) ----
reg [7:0] cnt;
always @(posedge clk) begin
    if (rst)                       cnt <= 8'd0;
    else if (go)                   cnt <= 8'd1;
    else if (cnt != 8'd0 && cnt != 8'd121) cnt <= cnt + 8'd1;
end
(* keep *) wire a_act   = go || (cnt == 8'd1);   // operand consumed at load
(* keep *) wire r_act   = go || (cnt >= 8'd1 && cnt <= 8'd118);
(* keep *) wire s_act   =       (cnt >= 8'd1 && cnt <= 8'd119);
(* keep *) wire out_act = go || (cnt >= 8'd1 && cnt <= 8'd116);
(* keep *) wire clr     = (cnt == 8'd108);  // bounded sensitivity

// ---- public FSM: round counter + phase (control only, data-independent) ----
reg running;
reg [3:0] rnd_i;
reg [2:0] ph;
always @(posedge clk) begin
    if (rst) begin running <= 1'b0; rnd_i <= 0; ph <= 0; end
    else if (go) begin running <= 1'b1; rnd_i <= 0; ph <= 0; end
    else if (running) begin
        if (ph == 5) begin
            ph <= 0;
            if (rnd_i == 4'd15) begin running <= 1'b0; rnd_i <= 0; end
            else rnd_i <= rnd_i + 4'd1;
        end else ph <= ph + 3'd1;
    end
end

// ---- iota round constant (public, XORed into share 0 of lane (0,0)) ----
wire [3:0] rc_cur = (rnd_i == 4'd0) ? 4'h1 :
               (rnd_i == 4'd1) ? 4'h2 :
               (rnd_i == 4'd2) ? 4'ha :
               (rnd_i == 4'd3) ? 4'h0 :
               (rnd_i == 4'd4) ? 4'hb :
               (rnd_i == 4'd5) ? 4'h1 :
               (rnd_i == 4'd6) ? 4'h1 :
               (rnd_i == 4'd7) ? 4'h9 :
               (rnd_i == 4'd8) ? 4'ha :
               (rnd_i == 4'd9) ? 4'h8 :
               (rnd_i == 4'd10) ? 4'h9 :
               (rnd_i == 4'd11) ? 4'ha :
               (rnd_i == 4'd12) ? 4'hb :
               (rnd_i == 4'd13) ? 4'hb :
               (rnd_i == 4'd14) ? 4'h9 :
               (rnd_i == 4'd15) ? 4'h3 :
               4'd0;

// ---- state registers (per-share; NEVER mix share 0 and share 1) ----
reg [99:0] St0, St1;
wire [99:0] Bx0, Bx1;         // after theta+rho+pi (share-local wiring)
wire [99:0] w_chi0, w_chi1;   // chi gadget outputs

always @(posedge clk) begin
    if (rst || clr) begin
        St0 <= 0; St1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        St0 <= {a[198], a[196], a[194], a[192], a[190], a[188], a[186], a[184], a[182], a[180], a[178], a[176], a[174], a[172], a[170], a[168], a[166], a[164], a[162], a[160], a[158], a[156], a[154], a[152], a[150], a[148], a[146], a[144], a[142], a[140], a[138], a[136], a[134], a[132], a[130], a[128], a[126], a[124], a[122], a[120], a[118], a[116], a[114], a[112], a[110], a[108], a[106], a[104], a[102], a[100], a[98], a[96], a[94], a[92], a[90], a[88], a[86], a[84], a[82], a[80], a[78], a[76], a[74], a[72], a[70], a[68], a[66], a[64], a[62], a[60], a[58], a[56], a[54], a[52], a[50], a[48], a[46], a[44], a[42], a[40], a[38], a[36], a[34], a[32], a[30], a[28], a[26], a[24], a[22], a[20], a[18], a[16], a[14], a[12], a[10], a[8], a[6], a[4], a[2], a[0]};
        St1 <= {a[199], a[197], a[195], a[193], a[191], a[189], a[187], a[185], a[183], a[181], a[179], a[177], a[175], a[173], a[171], a[169], a[167], a[165], a[163], a[161], a[159], a[157], a[155], a[153], a[151], a[149], a[147], a[145], a[143], a[141], a[139], a[137], a[135], a[133], a[131], a[129], a[127], a[125], a[123], a[121], a[119], a[117], a[115], a[113], a[111], a[109], a[107], a[105], a[103], a[101], a[99], a[97], a[95], a[93], a[91], a[89], a[87], a[85], a[83], a[81], a[79], a[77], a[75], a[73], a[71], a[69], a[67], a[65], a[63], a[61], a[59], a[57], a[55], a[53], a[51], a[49], a[47], a[45], a[43], a[41], a[39], a[37], a[35], a[33], a[31], a[29], a[27], a[25], a[23], a[21], a[19], a[17], a[15], a[13], a[11], a[9], a[7], a[5], a[3], a[1]};
    end else if (running && ph == 5) begin
        // chi outer XOR + iota, all share-local (iota into share 0 only)
        St0 <= Bx0 ^ w_chi0 ^ {{96{1'b0}}, rc_cur};
        St1 <= Bx1 ^ w_chi1;
    end
end

// ---- theta (share-local XOR network) ----

wire [19:0] C0, D0;
assign C0[0] = St0[0] ^ St0[20] ^ St0[40] ^ St0[60] ^ St0[80];
assign C0[1] = St0[1] ^ St0[21] ^ St0[41] ^ St0[61] ^ St0[81];
assign C0[2] = St0[2] ^ St0[22] ^ St0[42] ^ St0[62] ^ St0[82];
assign C0[3] = St0[3] ^ St0[23] ^ St0[43] ^ St0[63] ^ St0[83];
assign C0[4] = St0[4] ^ St0[24] ^ St0[44] ^ St0[64] ^ St0[84];
assign C0[5] = St0[5] ^ St0[25] ^ St0[45] ^ St0[65] ^ St0[85];
assign C0[6] = St0[6] ^ St0[26] ^ St0[46] ^ St0[66] ^ St0[86];
assign C0[7] = St0[7] ^ St0[27] ^ St0[47] ^ St0[67] ^ St0[87];
assign C0[8] = St0[8] ^ St0[28] ^ St0[48] ^ St0[68] ^ St0[88];
assign C0[9] = St0[9] ^ St0[29] ^ St0[49] ^ St0[69] ^ St0[89];
assign C0[10] = St0[10] ^ St0[30] ^ St0[50] ^ St0[70] ^ St0[90];
assign C0[11] = St0[11] ^ St0[31] ^ St0[51] ^ St0[71] ^ St0[91];
assign C0[12] = St0[12] ^ St0[32] ^ St0[52] ^ St0[72] ^ St0[92];
assign C0[13] = St0[13] ^ St0[33] ^ St0[53] ^ St0[73] ^ St0[93];
assign C0[14] = St0[14] ^ St0[34] ^ St0[54] ^ St0[74] ^ St0[94];
assign C0[15] = St0[15] ^ St0[35] ^ St0[55] ^ St0[75] ^ St0[95];
assign C0[16] = St0[16] ^ St0[36] ^ St0[56] ^ St0[76] ^ St0[96];
assign C0[17] = St0[17] ^ St0[37] ^ St0[57] ^ St0[77] ^ St0[97];
assign C0[18] = St0[18] ^ St0[38] ^ St0[58] ^ St0[78] ^ St0[98];
assign C0[19] = St0[19] ^ St0[39] ^ St0[59] ^ St0[79] ^ St0[99];
assign D0[0] = C0[16] ^ C0[7];
assign D0[1] = C0[17] ^ C0[4];
assign D0[2] = C0[18] ^ C0[5];
assign D0[3] = C0[19] ^ C0[6];
assign D0[4] = C0[0] ^ C0[11];
assign D0[5] = C0[1] ^ C0[8];
assign D0[6] = C0[2] ^ C0[9];
assign D0[7] = C0[3] ^ C0[10];
assign D0[8] = C0[4] ^ C0[15];
assign D0[9] = C0[5] ^ C0[12];
assign D0[10] = C0[6] ^ C0[13];
assign D0[11] = C0[7] ^ C0[14];
assign D0[12] = C0[8] ^ C0[19];
assign D0[13] = C0[9] ^ C0[16];
assign D0[14] = C0[10] ^ C0[17];
assign D0[15] = C0[11] ^ C0[18];
assign D0[16] = C0[12] ^ C0[3];
assign D0[17] = C0[13] ^ C0[0];
assign D0[18] = C0[14] ^ C0[1];
assign D0[19] = C0[15] ^ C0[2];
wire [19:0] C1, D1;
assign C1[0] = St1[0] ^ St1[20] ^ St1[40] ^ St1[60] ^ St1[80];
assign C1[1] = St1[1] ^ St1[21] ^ St1[41] ^ St1[61] ^ St1[81];
assign C1[2] = St1[2] ^ St1[22] ^ St1[42] ^ St1[62] ^ St1[82];
assign C1[3] = St1[3] ^ St1[23] ^ St1[43] ^ St1[63] ^ St1[83];
assign C1[4] = St1[4] ^ St1[24] ^ St1[44] ^ St1[64] ^ St1[84];
assign C1[5] = St1[5] ^ St1[25] ^ St1[45] ^ St1[65] ^ St1[85];
assign C1[6] = St1[6] ^ St1[26] ^ St1[46] ^ St1[66] ^ St1[86];
assign C1[7] = St1[7] ^ St1[27] ^ St1[47] ^ St1[67] ^ St1[87];
assign C1[8] = St1[8] ^ St1[28] ^ St1[48] ^ St1[68] ^ St1[88];
assign C1[9] = St1[9] ^ St1[29] ^ St1[49] ^ St1[69] ^ St1[89];
assign C1[10] = St1[10] ^ St1[30] ^ St1[50] ^ St1[70] ^ St1[90];
assign C1[11] = St1[11] ^ St1[31] ^ St1[51] ^ St1[71] ^ St1[91];
assign C1[12] = St1[12] ^ St1[32] ^ St1[52] ^ St1[72] ^ St1[92];
assign C1[13] = St1[13] ^ St1[33] ^ St1[53] ^ St1[73] ^ St1[93];
assign C1[14] = St1[14] ^ St1[34] ^ St1[54] ^ St1[74] ^ St1[94];
assign C1[15] = St1[15] ^ St1[35] ^ St1[55] ^ St1[75] ^ St1[95];
assign C1[16] = St1[16] ^ St1[36] ^ St1[56] ^ St1[76] ^ St1[96];
assign C1[17] = St1[17] ^ St1[37] ^ St1[57] ^ St1[77] ^ St1[97];
assign C1[18] = St1[18] ^ St1[38] ^ St1[58] ^ St1[78] ^ St1[98];
assign C1[19] = St1[19] ^ St1[39] ^ St1[59] ^ St1[79] ^ St1[99];
assign D1[0] = C1[16] ^ C1[7];
assign D1[1] = C1[17] ^ C1[4];
assign D1[2] = C1[18] ^ C1[5];
assign D1[3] = C1[19] ^ C1[6];
assign D1[4] = C1[0] ^ C1[11];
assign D1[5] = C1[1] ^ C1[8];
assign D1[6] = C1[2] ^ C1[9];
assign D1[7] = C1[3] ^ C1[10];
assign D1[8] = C1[4] ^ C1[15];
assign D1[9] = C1[5] ^ C1[12];
assign D1[10] = C1[6] ^ C1[13];
assign D1[11] = C1[7] ^ C1[14];
assign D1[12] = C1[8] ^ C1[19];
assign D1[13] = C1[9] ^ C1[16];
assign D1[14] = C1[10] ^ C1[17];
assign D1[15] = C1[11] ^ C1[18];
assign D1[16] = C1[12] ^ C1[3];
assign D1[17] = C1[13] ^ C1[0];
assign D1[18] = C1[14] ^ C1[1];
assign D1[19] = C1[15] ^ C1[2];

// ---- rho + pi (pure wiring): Bx[(2x+3y)%5 lane-row perm][z] ----
assign Bx0[0] = St0[0] ^ D0[0];
assign Bx0[1] = St0[1] ^ D0[1];
assign Bx0[2] = St0[2] ^ D0[2];
assign Bx0[3] = St0[3] ^ D0[3];
assign Bx0[64] = St0[20] ^ D0[0];
assign Bx0[65] = St0[21] ^ D0[1];
assign Bx0[66] = St0[22] ^ D0[2];
assign Bx0[67] = St0[23] ^ D0[3];
assign Bx0[28] = St0[41] ^ D0[1];
assign Bx0[29] = St0[42] ^ D0[2];
assign Bx0[30] = St0[43] ^ D0[3];
assign Bx0[31] = St0[40] ^ D0[0];
assign Bx0[92] = St0[63] ^ D0[3];
assign Bx0[93] = St0[60] ^ D0[0];
assign Bx0[94] = St0[61] ^ D0[1];
assign Bx0[95] = St0[62] ^ D0[2];
assign Bx0[56] = St0[82] ^ D0[2];
assign Bx0[57] = St0[83] ^ D0[3];
assign Bx0[58] = St0[80] ^ D0[0];
assign Bx0[59] = St0[81] ^ D0[1];
assign Bx0[40] = St0[7] ^ D0[7];
assign Bx0[41] = St0[4] ^ D0[4];
assign Bx0[42] = St0[5] ^ D0[5];
assign Bx0[43] = St0[6] ^ D0[6];
assign Bx0[4] = St0[24] ^ D0[4];
assign Bx0[5] = St0[25] ^ D0[5];
assign Bx0[6] = St0[26] ^ D0[6];
assign Bx0[7] = St0[27] ^ D0[7];
assign Bx0[68] = St0[46] ^ D0[6];
assign Bx0[69] = St0[47] ^ D0[7];
assign Bx0[70] = St0[44] ^ D0[4];
assign Bx0[71] = St0[45] ^ D0[5];
assign Bx0[32] = St0[67] ^ D0[7];
assign Bx0[33] = St0[64] ^ D0[4];
assign Bx0[34] = St0[65] ^ D0[5];
assign Bx0[35] = St0[66] ^ D0[6];
assign Bx0[96] = St0[86] ^ D0[6];
assign Bx0[97] = St0[87] ^ D0[7];
assign Bx0[98] = St0[84] ^ D0[4];
assign Bx0[99] = St0[85] ^ D0[5];
assign Bx0[80] = St0[10] ^ D0[10];
assign Bx0[81] = St0[11] ^ D0[11];
assign Bx0[82] = St0[8] ^ D0[8];
assign Bx0[83] = St0[9] ^ D0[9];
assign Bx0[44] = St0[30] ^ D0[10];
assign Bx0[45] = St0[31] ^ D0[11];
assign Bx0[46] = St0[28] ^ D0[8];
assign Bx0[47] = St0[29] ^ D0[9];
assign Bx0[8] = St0[49] ^ D0[9];
assign Bx0[9] = St0[50] ^ D0[10];
assign Bx0[10] = St0[51] ^ D0[11];
assign Bx0[11] = St0[48] ^ D0[8];
assign Bx0[72] = St0[69] ^ D0[9];
assign Bx0[73] = St0[70] ^ D0[10];
assign Bx0[74] = St0[71] ^ D0[11];
assign Bx0[75] = St0[68] ^ D0[8];
assign Bx0[36] = St0[91] ^ D0[11];
assign Bx0[37] = St0[88] ^ D0[8];
assign Bx0[38] = St0[89] ^ D0[9];
assign Bx0[39] = St0[90] ^ D0[10];
assign Bx0[20] = St0[12] ^ D0[12];
assign Bx0[21] = St0[13] ^ D0[13];
assign Bx0[22] = St0[14] ^ D0[14];
assign Bx0[23] = St0[15] ^ D0[15];
assign Bx0[84] = St0[33] ^ D0[13];
assign Bx0[85] = St0[34] ^ D0[14];
assign Bx0[86] = St0[35] ^ D0[15];
assign Bx0[87] = St0[32] ^ D0[12];
assign Bx0[48] = St0[55] ^ D0[15];
assign Bx0[49] = St0[52] ^ D0[12];
assign Bx0[50] = St0[53] ^ D0[13];
assign Bx0[51] = St0[54] ^ D0[14];
assign Bx0[12] = St0[75] ^ D0[15];
assign Bx0[13] = St0[72] ^ D0[12];
assign Bx0[14] = St0[73] ^ D0[13];
assign Bx0[15] = St0[74] ^ D0[14];
assign Bx0[76] = St0[92] ^ D0[12];
assign Bx0[77] = St0[93] ^ D0[13];
assign Bx0[78] = St0[94] ^ D0[14];
assign Bx0[79] = St0[95] ^ D0[15];
assign Bx0[60] = St0[17] ^ D0[17];
assign Bx0[61] = St0[18] ^ D0[18];
assign Bx0[62] = St0[19] ^ D0[19];
assign Bx0[63] = St0[16] ^ D0[16];
assign Bx0[24] = St0[36] ^ D0[16];
assign Bx0[25] = St0[37] ^ D0[17];
assign Bx0[26] = St0[38] ^ D0[18];
assign Bx0[27] = St0[39] ^ D0[19];
assign Bx0[88] = St0[57] ^ D0[17];
assign Bx0[89] = St0[58] ^ D0[18];
assign Bx0[90] = St0[59] ^ D0[19];
assign Bx0[91] = St0[56] ^ D0[16];
assign Bx0[52] = St0[76] ^ D0[16];
assign Bx0[53] = St0[77] ^ D0[17];
assign Bx0[54] = St0[78] ^ D0[18];
assign Bx0[55] = St0[79] ^ D0[19];
assign Bx0[16] = St0[98] ^ D0[18];
assign Bx0[17] = St0[99] ^ D0[19];
assign Bx0[18] = St0[96] ^ D0[16];
assign Bx0[19] = St0[97] ^ D0[17];
assign Bx1[0] = St1[0] ^ D1[0];
assign Bx1[1] = St1[1] ^ D1[1];
assign Bx1[2] = St1[2] ^ D1[2];
assign Bx1[3] = St1[3] ^ D1[3];
assign Bx1[64] = St1[20] ^ D1[0];
assign Bx1[65] = St1[21] ^ D1[1];
assign Bx1[66] = St1[22] ^ D1[2];
assign Bx1[67] = St1[23] ^ D1[3];
assign Bx1[28] = St1[41] ^ D1[1];
assign Bx1[29] = St1[42] ^ D1[2];
assign Bx1[30] = St1[43] ^ D1[3];
assign Bx1[31] = St1[40] ^ D1[0];
assign Bx1[92] = St1[63] ^ D1[3];
assign Bx1[93] = St1[60] ^ D1[0];
assign Bx1[94] = St1[61] ^ D1[1];
assign Bx1[95] = St1[62] ^ D1[2];
assign Bx1[56] = St1[82] ^ D1[2];
assign Bx1[57] = St1[83] ^ D1[3];
assign Bx1[58] = St1[80] ^ D1[0];
assign Bx1[59] = St1[81] ^ D1[1];
assign Bx1[40] = St1[7] ^ D1[7];
assign Bx1[41] = St1[4] ^ D1[4];
assign Bx1[42] = St1[5] ^ D1[5];
assign Bx1[43] = St1[6] ^ D1[6];
assign Bx1[4] = St1[24] ^ D1[4];
assign Bx1[5] = St1[25] ^ D1[5];
assign Bx1[6] = St1[26] ^ D1[6];
assign Bx1[7] = St1[27] ^ D1[7];
assign Bx1[68] = St1[46] ^ D1[6];
assign Bx1[69] = St1[47] ^ D1[7];
assign Bx1[70] = St1[44] ^ D1[4];
assign Bx1[71] = St1[45] ^ D1[5];
assign Bx1[32] = St1[67] ^ D1[7];
assign Bx1[33] = St1[64] ^ D1[4];
assign Bx1[34] = St1[65] ^ D1[5];
assign Bx1[35] = St1[66] ^ D1[6];
assign Bx1[96] = St1[86] ^ D1[6];
assign Bx1[97] = St1[87] ^ D1[7];
assign Bx1[98] = St1[84] ^ D1[4];
assign Bx1[99] = St1[85] ^ D1[5];
assign Bx1[80] = St1[10] ^ D1[10];
assign Bx1[81] = St1[11] ^ D1[11];
assign Bx1[82] = St1[8] ^ D1[8];
assign Bx1[83] = St1[9] ^ D1[9];
assign Bx1[44] = St1[30] ^ D1[10];
assign Bx1[45] = St1[31] ^ D1[11];
assign Bx1[46] = St1[28] ^ D1[8];
assign Bx1[47] = St1[29] ^ D1[9];
assign Bx1[8] = St1[49] ^ D1[9];
assign Bx1[9] = St1[50] ^ D1[10];
assign Bx1[10] = St1[51] ^ D1[11];
assign Bx1[11] = St1[48] ^ D1[8];
assign Bx1[72] = St1[69] ^ D1[9];
assign Bx1[73] = St1[70] ^ D1[10];
assign Bx1[74] = St1[71] ^ D1[11];
assign Bx1[75] = St1[68] ^ D1[8];
assign Bx1[36] = St1[91] ^ D1[11];
assign Bx1[37] = St1[88] ^ D1[8];
assign Bx1[38] = St1[89] ^ D1[9];
assign Bx1[39] = St1[90] ^ D1[10];
assign Bx1[20] = St1[12] ^ D1[12];
assign Bx1[21] = St1[13] ^ D1[13];
assign Bx1[22] = St1[14] ^ D1[14];
assign Bx1[23] = St1[15] ^ D1[15];
assign Bx1[84] = St1[33] ^ D1[13];
assign Bx1[85] = St1[34] ^ D1[14];
assign Bx1[86] = St1[35] ^ D1[15];
assign Bx1[87] = St1[32] ^ D1[12];
assign Bx1[48] = St1[55] ^ D1[15];
assign Bx1[49] = St1[52] ^ D1[12];
assign Bx1[50] = St1[53] ^ D1[13];
assign Bx1[51] = St1[54] ^ D1[14];
assign Bx1[12] = St1[75] ^ D1[15];
assign Bx1[13] = St1[72] ^ D1[12];
assign Bx1[14] = St1[73] ^ D1[13];
assign Bx1[15] = St1[74] ^ D1[14];
assign Bx1[76] = St1[92] ^ D1[12];
assign Bx1[77] = St1[93] ^ D1[13];
assign Bx1[78] = St1[94] ^ D1[14];
assign Bx1[79] = St1[95] ^ D1[15];
assign Bx1[60] = St1[17] ^ D1[17];
assign Bx1[61] = St1[18] ^ D1[18];
assign Bx1[62] = St1[19] ^ D1[19];
assign Bx1[63] = St1[16] ^ D1[16];
assign Bx1[24] = St1[36] ^ D1[16];
assign Bx1[25] = St1[37] ^ D1[17];
assign Bx1[26] = St1[38] ^ D1[18];
assign Bx1[27] = St1[39] ^ D1[19];
assign Bx1[88] = St1[57] ^ D1[17];
assign Bx1[89] = St1[58] ^ D1[18];
assign Bx1[90] = St1[59] ^ D1[19];
assign Bx1[91] = St1[56] ^ D1[16];
assign Bx1[52] = St1[76] ^ D1[16];
assign Bx1[53] = St1[77] ^ D1[17];
assign Bx1[54] = St1[78] ^ D1[18];
assign Bx1[55] = St1[79] ^ D1[19];
assign Bx1[16] = St1[98] ^ D1[18];
assign Bx1[17] = St1[99] ^ D1[19];
assign Bx1[18] = St1[96] ^ D1[16];
assign Bx1[19] = St1[97] ^ D1[17];

// ---- chi: w_chi[x,y,z] = (~Bx[x+1,y,z]) AND Bx[x+2,y,z] ----
// NOT is share-local (complement share 0 only); nb_d* are the 1-cycle
// per-share balance registers feeding every gadget ina (contract ina@1).
wire [99:0] nb_src0, nb_src1;
wire [99:0] nb0 = ~nb_src0;   // share-local complement, share 0 only
wire [99:0] nb1 =  nb_src1;
reg  [99:0] nb_d0, nb_d1;
always @(posedge clk) begin
    nb_d0 <= nb0;
    nb_d1 <= nb1;
end
assign nb_src0[0] = Bx0[4];  assign nb_src1[0] = Bx1[4];
assign nb_src0[1] = Bx0[5];  assign nb_src1[1] = Bx1[5];
assign nb_src0[2] = Bx0[6];  assign nb_src1[2] = Bx1[6];
assign nb_src0[3] = Bx0[7];  assign nb_src1[3] = Bx1[7];
assign nb_src0[20] = Bx0[24];  assign nb_src1[20] = Bx1[24];
assign nb_src0[21] = Bx0[25];  assign nb_src1[21] = Bx1[25];
assign nb_src0[22] = Bx0[26];  assign nb_src1[22] = Bx1[26];
assign nb_src0[23] = Bx0[27];  assign nb_src1[23] = Bx1[27];
assign nb_src0[40] = Bx0[44];  assign nb_src1[40] = Bx1[44];
assign nb_src0[41] = Bx0[45];  assign nb_src1[41] = Bx1[45];
assign nb_src0[42] = Bx0[46];  assign nb_src1[42] = Bx1[46];
assign nb_src0[43] = Bx0[47];  assign nb_src1[43] = Bx1[47];
assign nb_src0[60] = Bx0[64];  assign nb_src1[60] = Bx1[64];
assign nb_src0[61] = Bx0[65];  assign nb_src1[61] = Bx1[65];
assign nb_src0[62] = Bx0[66];  assign nb_src1[62] = Bx1[66];
assign nb_src0[63] = Bx0[67];  assign nb_src1[63] = Bx1[67];
assign nb_src0[80] = Bx0[84];  assign nb_src1[80] = Bx1[84];
assign nb_src0[81] = Bx0[85];  assign nb_src1[81] = Bx1[85];
assign nb_src0[82] = Bx0[86];  assign nb_src1[82] = Bx1[86];
assign nb_src0[83] = Bx0[87];  assign nb_src1[83] = Bx1[87];
assign nb_src0[4] = Bx0[8];  assign nb_src1[4] = Bx1[8];
assign nb_src0[5] = Bx0[9];  assign nb_src1[5] = Bx1[9];
assign nb_src0[6] = Bx0[10];  assign nb_src1[6] = Bx1[10];
assign nb_src0[7] = Bx0[11];  assign nb_src1[7] = Bx1[11];
assign nb_src0[24] = Bx0[28];  assign nb_src1[24] = Bx1[28];
assign nb_src0[25] = Bx0[29];  assign nb_src1[25] = Bx1[29];
assign nb_src0[26] = Bx0[30];  assign nb_src1[26] = Bx1[30];
assign nb_src0[27] = Bx0[31];  assign nb_src1[27] = Bx1[31];
assign nb_src0[44] = Bx0[48];  assign nb_src1[44] = Bx1[48];
assign nb_src0[45] = Bx0[49];  assign nb_src1[45] = Bx1[49];
assign nb_src0[46] = Bx0[50];  assign nb_src1[46] = Bx1[50];
assign nb_src0[47] = Bx0[51];  assign nb_src1[47] = Bx1[51];
assign nb_src0[64] = Bx0[68];  assign nb_src1[64] = Bx1[68];
assign nb_src0[65] = Bx0[69];  assign nb_src1[65] = Bx1[69];
assign nb_src0[66] = Bx0[70];  assign nb_src1[66] = Bx1[70];
assign nb_src0[67] = Bx0[71];  assign nb_src1[67] = Bx1[71];
assign nb_src0[84] = Bx0[88];  assign nb_src1[84] = Bx1[88];
assign nb_src0[85] = Bx0[89];  assign nb_src1[85] = Bx1[89];
assign nb_src0[86] = Bx0[90];  assign nb_src1[86] = Bx1[90];
assign nb_src0[87] = Bx0[91];  assign nb_src1[87] = Bx1[91];
assign nb_src0[8] = Bx0[12];  assign nb_src1[8] = Bx1[12];
assign nb_src0[9] = Bx0[13];  assign nb_src1[9] = Bx1[13];
assign nb_src0[10] = Bx0[14];  assign nb_src1[10] = Bx1[14];
assign nb_src0[11] = Bx0[15];  assign nb_src1[11] = Bx1[15];
assign nb_src0[28] = Bx0[32];  assign nb_src1[28] = Bx1[32];
assign nb_src0[29] = Bx0[33];  assign nb_src1[29] = Bx1[33];
assign nb_src0[30] = Bx0[34];  assign nb_src1[30] = Bx1[34];
assign nb_src0[31] = Bx0[35];  assign nb_src1[31] = Bx1[35];
assign nb_src0[48] = Bx0[52];  assign nb_src1[48] = Bx1[52];
assign nb_src0[49] = Bx0[53];  assign nb_src1[49] = Bx1[53];
assign nb_src0[50] = Bx0[54];  assign nb_src1[50] = Bx1[54];
assign nb_src0[51] = Bx0[55];  assign nb_src1[51] = Bx1[55];
assign nb_src0[68] = Bx0[72];  assign nb_src1[68] = Bx1[72];
assign nb_src0[69] = Bx0[73];  assign nb_src1[69] = Bx1[73];
assign nb_src0[70] = Bx0[74];  assign nb_src1[70] = Bx1[74];
assign nb_src0[71] = Bx0[75];  assign nb_src1[71] = Bx1[75];
assign nb_src0[88] = Bx0[92];  assign nb_src1[88] = Bx1[92];
assign nb_src0[89] = Bx0[93];  assign nb_src1[89] = Bx1[93];
assign nb_src0[90] = Bx0[94];  assign nb_src1[90] = Bx1[94];
assign nb_src0[91] = Bx0[95];  assign nb_src1[91] = Bx1[95];
assign nb_src0[12] = Bx0[16];  assign nb_src1[12] = Bx1[16];
assign nb_src0[13] = Bx0[17];  assign nb_src1[13] = Bx1[17];
assign nb_src0[14] = Bx0[18];  assign nb_src1[14] = Bx1[18];
assign nb_src0[15] = Bx0[19];  assign nb_src1[15] = Bx1[19];
assign nb_src0[32] = Bx0[36];  assign nb_src1[32] = Bx1[36];
assign nb_src0[33] = Bx0[37];  assign nb_src1[33] = Bx1[37];
assign nb_src0[34] = Bx0[38];  assign nb_src1[34] = Bx1[38];
assign nb_src0[35] = Bx0[39];  assign nb_src1[35] = Bx1[39];
assign nb_src0[52] = Bx0[56];  assign nb_src1[52] = Bx1[56];
assign nb_src0[53] = Bx0[57];  assign nb_src1[53] = Bx1[57];
assign nb_src0[54] = Bx0[58];  assign nb_src1[54] = Bx1[58];
assign nb_src0[55] = Bx0[59];  assign nb_src1[55] = Bx1[59];
assign nb_src0[72] = Bx0[76];  assign nb_src1[72] = Bx1[76];
assign nb_src0[73] = Bx0[77];  assign nb_src1[73] = Bx1[77];
assign nb_src0[74] = Bx0[78];  assign nb_src1[74] = Bx1[78];
assign nb_src0[75] = Bx0[79];  assign nb_src1[75] = Bx1[79];
assign nb_src0[92] = Bx0[96];  assign nb_src1[92] = Bx1[96];
assign nb_src0[93] = Bx0[97];  assign nb_src1[93] = Bx1[97];
assign nb_src0[94] = Bx0[98];  assign nb_src1[94] = Bx1[98];
assign nb_src0[95] = Bx0[99];  assign nb_src1[95] = Bx1[99];
assign nb_src0[16] = Bx0[0];  assign nb_src1[16] = Bx1[0];
assign nb_src0[17] = Bx0[1];  assign nb_src1[17] = Bx1[1];
assign nb_src0[18] = Bx0[2];  assign nb_src1[18] = Bx1[2];
assign nb_src0[19] = Bx0[3];  assign nb_src1[19] = Bx1[3];
assign nb_src0[36] = Bx0[20];  assign nb_src1[36] = Bx1[20];
assign nb_src0[37] = Bx0[21];  assign nb_src1[37] = Bx1[21];
assign nb_src0[38] = Bx0[22];  assign nb_src1[38] = Bx1[22];
assign nb_src0[39] = Bx0[23];  assign nb_src1[39] = Bx1[23];
assign nb_src0[56] = Bx0[40];  assign nb_src1[56] = Bx1[40];
assign nb_src0[57] = Bx0[41];  assign nb_src1[57] = Bx1[41];
assign nb_src0[58] = Bx0[42];  assign nb_src1[58] = Bx1[42];
assign nb_src0[59] = Bx0[43];  assign nb_src1[59] = Bx1[43];
assign nb_src0[76] = Bx0[60];  assign nb_src1[76] = Bx1[60];
assign nb_src0[77] = Bx0[61];  assign nb_src1[77] = Bx1[61];
assign nb_src0[78] = Bx0[62];  assign nb_src1[78] = Bx1[62];
assign nb_src0[79] = Bx0[63];  assign nb_src1[79] = Bx1[63];
assign nb_src0[96] = Bx0[80];  assign nb_src1[96] = Bx1[80];
assign nb_src0[97] = Bx0[81];  assign nb_src1[97] = Bx1[81];
assign nb_src0[98] = Bx0[82];  assign nb_src1[98] = Bx1[82];
assign nb_src0[99] = Bx0[83];  assign nb_src1[99] = Bx1[83];

MSKand_opini2_d2 u_chi_0 (
    .ina({nb_d1[0], nb_d0[0]}), .inb({Bx1[8], Bx0[8]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({w_chi1[0], w_chi0[0]}));
MSKand_opini2_d2 u_chi_1 (  // BUG UNDER TEST: reuses u_chi_0's randomness
    .ina({nb_d1[1], nb_d0[1]}), .inb({Bx1[9], Bx0[9]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({w_chi1[1], w_chi0[1]}));
MSKand_opini2_d2 u_chi_2 (
    .ina({nb_d1[2], nb_d0[2]}), .inb({Bx1[10], Bx0[10]}),
    .rnd(r[2]), .s(s[2]), .clk(clk), .out({w_chi1[2], w_chi0[2]}));
MSKand_opini2_d2 u_chi_3 (
    .ina({nb_d1[3], nb_d0[3]}), .inb({Bx1[11], Bx0[11]}),
    .rnd(r[3]), .s(s[3]), .clk(clk), .out({w_chi1[3], w_chi0[3]}));
MSKand_opini2_d2 u_chi_20 (
    .ina({nb_d1[20], nb_d0[20]}), .inb({Bx1[28], Bx0[28]}),
    .rnd(r[20]), .s(s[20]), .clk(clk), .out({w_chi1[20], w_chi0[20]}));
MSKand_opini2_d2 u_chi_21 (
    .ina({nb_d1[21], nb_d0[21]}), .inb({Bx1[29], Bx0[29]}),
    .rnd(r[21]), .s(s[21]), .clk(clk), .out({w_chi1[21], w_chi0[21]}));
MSKand_opini2_d2 u_chi_22 (
    .ina({nb_d1[22], nb_d0[22]}), .inb({Bx1[30], Bx0[30]}),
    .rnd(r[22]), .s(s[22]), .clk(clk), .out({w_chi1[22], w_chi0[22]}));
MSKand_opini2_d2 u_chi_23 (
    .ina({nb_d1[23], nb_d0[23]}), .inb({Bx1[31], Bx0[31]}),
    .rnd(r[23]), .s(s[23]), .clk(clk), .out({w_chi1[23], w_chi0[23]}));
MSKand_opini2_d2 u_chi_40 (
    .ina({nb_d1[40], nb_d0[40]}), .inb({Bx1[48], Bx0[48]}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({w_chi1[40], w_chi0[40]}));
MSKand_opini2_d2 u_chi_41 (
    .ina({nb_d1[41], nb_d0[41]}), .inb({Bx1[49], Bx0[49]}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({w_chi1[41], w_chi0[41]}));
MSKand_opini2_d2 u_chi_42 (
    .ina({nb_d1[42], nb_d0[42]}), .inb({Bx1[50], Bx0[50]}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({w_chi1[42], w_chi0[42]}));
MSKand_opini2_d2 u_chi_43 (
    .ina({nb_d1[43], nb_d0[43]}), .inb({Bx1[51], Bx0[51]}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({w_chi1[43], w_chi0[43]}));
MSKand_opini2_d2 u_chi_60 (
    .ina({nb_d1[60], nb_d0[60]}), .inb({Bx1[68], Bx0[68]}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({w_chi1[60], w_chi0[60]}));
MSKand_opini2_d2 u_chi_61 (
    .ina({nb_d1[61], nb_d0[61]}), .inb({Bx1[69], Bx0[69]}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({w_chi1[61], w_chi0[61]}));
MSKand_opini2_d2 u_chi_62 (
    .ina({nb_d1[62], nb_d0[62]}), .inb({Bx1[70], Bx0[70]}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({w_chi1[62], w_chi0[62]}));
MSKand_opini2_d2 u_chi_63 (
    .ina({nb_d1[63], nb_d0[63]}), .inb({Bx1[71], Bx0[71]}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({w_chi1[63], w_chi0[63]}));
MSKand_opini2_d2 u_chi_80 (
    .ina({nb_d1[80], nb_d0[80]}), .inb({Bx1[88], Bx0[88]}),
    .rnd(r[80]), .s(s[80]), .clk(clk), .out({w_chi1[80], w_chi0[80]}));
MSKand_opini2_d2 u_chi_81 (
    .ina({nb_d1[81], nb_d0[81]}), .inb({Bx1[89], Bx0[89]}),
    .rnd(r[81]), .s(s[81]), .clk(clk), .out({w_chi1[81], w_chi0[81]}));
MSKand_opini2_d2 u_chi_82 (
    .ina({nb_d1[82], nb_d0[82]}), .inb({Bx1[90], Bx0[90]}),
    .rnd(r[82]), .s(s[82]), .clk(clk), .out({w_chi1[82], w_chi0[82]}));
MSKand_opini2_d2 u_chi_83 (
    .ina({nb_d1[83], nb_d0[83]}), .inb({Bx1[91], Bx0[91]}),
    .rnd(r[83]), .s(s[83]), .clk(clk), .out({w_chi1[83], w_chi0[83]}));
MSKand_opini2_d2 u_chi_4 (
    .ina({nb_d1[4], nb_d0[4]}), .inb({Bx1[12], Bx0[12]}),
    .rnd(r[4]), .s(s[4]), .clk(clk), .out({w_chi1[4], w_chi0[4]}));
MSKand_opini2_d2 u_chi_5 (
    .ina({nb_d1[5], nb_d0[5]}), .inb({Bx1[13], Bx0[13]}),
    .rnd(r[5]), .s(s[5]), .clk(clk), .out({w_chi1[5], w_chi0[5]}));
MSKand_opini2_d2 u_chi_6 (
    .ina({nb_d1[6], nb_d0[6]}), .inb({Bx1[14], Bx0[14]}),
    .rnd(r[6]), .s(s[6]), .clk(clk), .out({w_chi1[6], w_chi0[6]}));
MSKand_opini2_d2 u_chi_7 (
    .ina({nb_d1[7], nb_d0[7]}), .inb({Bx1[15], Bx0[15]}),
    .rnd(r[7]), .s(s[7]), .clk(clk), .out({w_chi1[7], w_chi0[7]}));
MSKand_opini2_d2 u_chi_24 (
    .ina({nb_d1[24], nb_d0[24]}), .inb({Bx1[32], Bx0[32]}),
    .rnd(r[24]), .s(s[24]), .clk(clk), .out({w_chi1[24], w_chi0[24]}));
MSKand_opini2_d2 u_chi_25 (
    .ina({nb_d1[25], nb_d0[25]}), .inb({Bx1[33], Bx0[33]}),
    .rnd(r[25]), .s(s[25]), .clk(clk), .out({w_chi1[25], w_chi0[25]}));
MSKand_opini2_d2 u_chi_26 (
    .ina({nb_d1[26], nb_d0[26]}), .inb({Bx1[34], Bx0[34]}),
    .rnd(r[26]), .s(s[26]), .clk(clk), .out({w_chi1[26], w_chi0[26]}));
MSKand_opini2_d2 u_chi_27 (
    .ina({nb_d1[27], nb_d0[27]}), .inb({Bx1[35], Bx0[35]}),
    .rnd(r[27]), .s(s[27]), .clk(clk), .out({w_chi1[27], w_chi0[27]}));
MSKand_opini2_d2 u_chi_44 (
    .ina({nb_d1[44], nb_d0[44]}), .inb({Bx1[52], Bx0[52]}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({w_chi1[44], w_chi0[44]}));
MSKand_opini2_d2 u_chi_45 (
    .ina({nb_d1[45], nb_d0[45]}), .inb({Bx1[53], Bx0[53]}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({w_chi1[45], w_chi0[45]}));
MSKand_opini2_d2 u_chi_46 (
    .ina({nb_d1[46], nb_d0[46]}), .inb({Bx1[54], Bx0[54]}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({w_chi1[46], w_chi0[46]}));
MSKand_opini2_d2 u_chi_47 (
    .ina({nb_d1[47], nb_d0[47]}), .inb({Bx1[55], Bx0[55]}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({w_chi1[47], w_chi0[47]}));
MSKand_opini2_d2 u_chi_64 (
    .ina({nb_d1[64], nb_d0[64]}), .inb({Bx1[72], Bx0[72]}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({w_chi1[64], w_chi0[64]}));
MSKand_opini2_d2 u_chi_65 (
    .ina({nb_d1[65], nb_d0[65]}), .inb({Bx1[73], Bx0[73]}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({w_chi1[65], w_chi0[65]}));
MSKand_opini2_d2 u_chi_66 (
    .ina({nb_d1[66], nb_d0[66]}), .inb({Bx1[74], Bx0[74]}),
    .rnd(r[66]), .s(s[66]), .clk(clk), .out({w_chi1[66], w_chi0[66]}));
MSKand_opini2_d2 u_chi_67 (
    .ina({nb_d1[67], nb_d0[67]}), .inb({Bx1[75], Bx0[75]}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({w_chi1[67], w_chi0[67]}));
MSKand_opini2_d2 u_chi_84 (
    .ina({nb_d1[84], nb_d0[84]}), .inb({Bx1[92], Bx0[92]}),
    .rnd(r[84]), .s(s[84]), .clk(clk), .out({w_chi1[84], w_chi0[84]}));
MSKand_opini2_d2 u_chi_85 (
    .ina({nb_d1[85], nb_d0[85]}), .inb({Bx1[93], Bx0[93]}),
    .rnd(r[85]), .s(s[85]), .clk(clk), .out({w_chi1[85], w_chi0[85]}));
MSKand_opini2_d2 u_chi_86 (
    .ina({nb_d1[86], nb_d0[86]}), .inb({Bx1[94], Bx0[94]}),
    .rnd(r[86]), .s(s[86]), .clk(clk), .out({w_chi1[86], w_chi0[86]}));
MSKand_opini2_d2 u_chi_87 (
    .ina({nb_d1[87], nb_d0[87]}), .inb({Bx1[95], Bx0[95]}),
    .rnd(r[87]), .s(s[87]), .clk(clk), .out({w_chi1[87], w_chi0[87]}));
MSKand_opini2_d2 u_chi_8 (
    .ina({nb_d1[8], nb_d0[8]}), .inb({Bx1[16], Bx0[16]}),
    .rnd(r[8]), .s(s[8]), .clk(clk), .out({w_chi1[8], w_chi0[8]}));
MSKand_opini2_d2 u_chi_9 (
    .ina({nb_d1[9], nb_d0[9]}), .inb({Bx1[17], Bx0[17]}),
    .rnd(r[9]), .s(s[9]), .clk(clk), .out({w_chi1[9], w_chi0[9]}));
MSKand_opini2_d2 u_chi_10 (
    .ina({nb_d1[10], nb_d0[10]}), .inb({Bx1[18], Bx0[18]}),
    .rnd(r[10]), .s(s[10]), .clk(clk), .out({w_chi1[10], w_chi0[10]}));
MSKand_opini2_d2 u_chi_11 (
    .ina({nb_d1[11], nb_d0[11]}), .inb({Bx1[19], Bx0[19]}),
    .rnd(r[11]), .s(s[11]), .clk(clk), .out({w_chi1[11], w_chi0[11]}));
MSKand_opini2_d2 u_chi_28 (
    .ina({nb_d1[28], nb_d0[28]}), .inb({Bx1[36], Bx0[36]}),
    .rnd(r[28]), .s(s[28]), .clk(clk), .out({w_chi1[28], w_chi0[28]}));
MSKand_opini2_d2 u_chi_29 (
    .ina({nb_d1[29], nb_d0[29]}), .inb({Bx1[37], Bx0[37]}),
    .rnd(r[29]), .s(s[29]), .clk(clk), .out({w_chi1[29], w_chi0[29]}));
MSKand_opini2_d2 u_chi_30 (
    .ina({nb_d1[30], nb_d0[30]}), .inb({Bx1[38], Bx0[38]}),
    .rnd(r[30]), .s(s[30]), .clk(clk), .out({w_chi1[30], w_chi0[30]}));
MSKand_opini2_d2 u_chi_31 (
    .ina({nb_d1[31], nb_d0[31]}), .inb({Bx1[39], Bx0[39]}),
    .rnd(r[31]), .s(s[31]), .clk(clk), .out({w_chi1[31], w_chi0[31]}));
MSKand_opini2_d2 u_chi_48 (
    .ina({nb_d1[48], nb_d0[48]}), .inb({Bx1[56], Bx0[56]}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({w_chi1[48], w_chi0[48]}));
MSKand_opini2_d2 u_chi_49 (
    .ina({nb_d1[49], nb_d0[49]}), .inb({Bx1[57], Bx0[57]}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({w_chi1[49], w_chi0[49]}));
MSKand_opini2_d2 u_chi_50 (
    .ina({nb_d1[50], nb_d0[50]}), .inb({Bx1[58], Bx0[58]}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({w_chi1[50], w_chi0[50]}));
MSKand_opini2_d2 u_chi_51 (
    .ina({nb_d1[51], nb_d0[51]}), .inb({Bx1[59], Bx0[59]}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({w_chi1[51], w_chi0[51]}));
MSKand_opini2_d2 u_chi_68 (
    .ina({nb_d1[68], nb_d0[68]}), .inb({Bx1[76], Bx0[76]}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({w_chi1[68], w_chi0[68]}));
MSKand_opini2_d2 u_chi_69 (
    .ina({nb_d1[69], nb_d0[69]}), .inb({Bx1[77], Bx0[77]}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({w_chi1[69], w_chi0[69]}));
MSKand_opini2_d2 u_chi_70 (
    .ina({nb_d1[70], nb_d0[70]}), .inb({Bx1[78], Bx0[78]}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({w_chi1[70], w_chi0[70]}));
MSKand_opini2_d2 u_chi_71 (
    .ina({nb_d1[71], nb_d0[71]}), .inb({Bx1[79], Bx0[79]}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({w_chi1[71], w_chi0[71]}));
MSKand_opini2_d2 u_chi_88 (
    .ina({nb_d1[88], nb_d0[88]}), .inb({Bx1[96], Bx0[96]}),
    .rnd(r[88]), .s(s[88]), .clk(clk), .out({w_chi1[88], w_chi0[88]}));
MSKand_opini2_d2 u_chi_89 (
    .ina({nb_d1[89], nb_d0[89]}), .inb({Bx1[97], Bx0[97]}),
    .rnd(r[89]), .s(s[89]), .clk(clk), .out({w_chi1[89], w_chi0[89]}));
MSKand_opini2_d2 u_chi_90 (
    .ina({nb_d1[90], nb_d0[90]}), .inb({Bx1[98], Bx0[98]}),
    .rnd(r[90]), .s(s[90]), .clk(clk), .out({w_chi1[90], w_chi0[90]}));
MSKand_opini2_d2 u_chi_91 (
    .ina({nb_d1[91], nb_d0[91]}), .inb({Bx1[99], Bx0[99]}),
    .rnd(r[91]), .s(s[91]), .clk(clk), .out({w_chi1[91], w_chi0[91]}));
MSKand_opini2_d2 u_chi_12 (
    .ina({nb_d1[12], nb_d0[12]}), .inb({Bx1[0], Bx0[0]}),
    .rnd(r[12]), .s(s[12]), .clk(clk), .out({w_chi1[12], w_chi0[12]}));
MSKand_opini2_d2 u_chi_13 (
    .ina({nb_d1[13], nb_d0[13]}), .inb({Bx1[1], Bx0[1]}),
    .rnd(r[13]), .s(s[13]), .clk(clk), .out({w_chi1[13], w_chi0[13]}));
MSKand_opini2_d2 u_chi_14 (
    .ina({nb_d1[14], nb_d0[14]}), .inb({Bx1[2], Bx0[2]}),
    .rnd(r[14]), .s(s[14]), .clk(clk), .out({w_chi1[14], w_chi0[14]}));
MSKand_opini2_d2 u_chi_15 (
    .ina({nb_d1[15], nb_d0[15]}), .inb({Bx1[3], Bx0[3]}),
    .rnd(r[15]), .s(s[15]), .clk(clk), .out({w_chi1[15], w_chi0[15]}));
MSKand_opini2_d2 u_chi_32 (
    .ina({nb_d1[32], nb_d0[32]}), .inb({Bx1[20], Bx0[20]}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({w_chi1[32], w_chi0[32]}));
MSKand_opini2_d2 u_chi_33 (
    .ina({nb_d1[33], nb_d0[33]}), .inb({Bx1[21], Bx0[21]}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({w_chi1[33], w_chi0[33]}));
MSKand_opini2_d2 u_chi_34 (
    .ina({nb_d1[34], nb_d0[34]}), .inb({Bx1[22], Bx0[22]}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({w_chi1[34], w_chi0[34]}));
MSKand_opini2_d2 u_chi_35 (
    .ina({nb_d1[35], nb_d0[35]}), .inb({Bx1[23], Bx0[23]}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({w_chi1[35], w_chi0[35]}));
MSKand_opini2_d2 u_chi_52 (
    .ina({nb_d1[52], nb_d0[52]}), .inb({Bx1[40], Bx0[40]}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({w_chi1[52], w_chi0[52]}));
MSKand_opini2_d2 u_chi_53 (
    .ina({nb_d1[53], nb_d0[53]}), .inb({Bx1[41], Bx0[41]}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({w_chi1[53], w_chi0[53]}));
MSKand_opini2_d2 u_chi_54 (
    .ina({nb_d1[54], nb_d0[54]}), .inb({Bx1[42], Bx0[42]}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({w_chi1[54], w_chi0[54]}));
MSKand_opini2_d2 u_chi_55 (
    .ina({nb_d1[55], nb_d0[55]}), .inb({Bx1[43], Bx0[43]}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({w_chi1[55], w_chi0[55]}));
MSKand_opini2_d2 u_chi_72 (
    .ina({nb_d1[72], nb_d0[72]}), .inb({Bx1[60], Bx0[60]}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({w_chi1[72], w_chi0[72]}));
MSKand_opini2_d2 u_chi_73 (
    .ina({nb_d1[73], nb_d0[73]}), .inb({Bx1[61], Bx0[61]}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({w_chi1[73], w_chi0[73]}));
MSKand_opini2_d2 u_chi_74 (
    .ina({nb_d1[74], nb_d0[74]}), .inb({Bx1[62], Bx0[62]}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({w_chi1[74], w_chi0[74]}));
MSKand_opini2_d2 u_chi_75 (
    .ina({nb_d1[75], nb_d0[75]}), .inb({Bx1[63], Bx0[63]}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({w_chi1[75], w_chi0[75]}));
MSKand_opini2_d2 u_chi_92 (
    .ina({nb_d1[92], nb_d0[92]}), .inb({Bx1[80], Bx0[80]}),
    .rnd(r[92]), .s(s[92]), .clk(clk), .out({w_chi1[92], w_chi0[92]}));
MSKand_opini2_d2 u_chi_93 (
    .ina({nb_d1[93], nb_d0[93]}), .inb({Bx1[81], Bx0[81]}),
    .rnd(r[93]), .s(s[93]), .clk(clk), .out({w_chi1[93], w_chi0[93]}));
MSKand_opini2_d2 u_chi_94 (
    .ina({nb_d1[94], nb_d0[94]}), .inb({Bx1[82], Bx0[82]}),
    .rnd(r[94]), .s(s[94]), .clk(clk), .out({w_chi1[94], w_chi0[94]}));
MSKand_opini2_d2 u_chi_95 (
    .ina({nb_d1[95], nb_d0[95]}), .inb({Bx1[83], Bx0[83]}),
    .rnd(r[95]), .s(s[95]), .clk(clk), .out({w_chi1[95], w_chi0[95]}));
MSKand_opini2_d2 u_chi_16 (
    .ina({nb_d1[16], nb_d0[16]}), .inb({Bx1[4], Bx0[4]}),
    .rnd(r[16]), .s(s[16]), .clk(clk), .out({w_chi1[16], w_chi0[16]}));
MSKand_opini2_d2 u_chi_17 (
    .ina({nb_d1[17], nb_d0[17]}), .inb({Bx1[5], Bx0[5]}),
    .rnd(r[17]), .s(s[17]), .clk(clk), .out({w_chi1[17], w_chi0[17]}));
MSKand_opini2_d2 u_chi_18 (
    .ina({nb_d1[18], nb_d0[18]}), .inb({Bx1[6], Bx0[6]}),
    .rnd(r[18]), .s(s[18]), .clk(clk), .out({w_chi1[18], w_chi0[18]}));
MSKand_opini2_d2 u_chi_19 (
    .ina({nb_d1[19], nb_d0[19]}), .inb({Bx1[7], Bx0[7]}),
    .rnd(r[19]), .s(s[19]), .clk(clk), .out({w_chi1[19], w_chi0[19]}));
MSKand_opini2_d2 u_chi_36 (
    .ina({nb_d1[36], nb_d0[36]}), .inb({Bx1[24], Bx0[24]}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({w_chi1[36], w_chi0[36]}));
MSKand_opini2_d2 u_chi_37 (
    .ina({nb_d1[37], nb_d0[37]}), .inb({Bx1[25], Bx0[25]}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({w_chi1[37], w_chi0[37]}));
MSKand_opini2_d2 u_chi_38 (
    .ina({nb_d1[38], nb_d0[38]}), .inb({Bx1[26], Bx0[26]}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({w_chi1[38], w_chi0[38]}));
MSKand_opini2_d2 u_chi_39 (
    .ina({nb_d1[39], nb_d0[39]}), .inb({Bx1[27], Bx0[27]}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({w_chi1[39], w_chi0[39]}));
MSKand_opini2_d2 u_chi_56 (
    .ina({nb_d1[56], nb_d0[56]}), .inb({Bx1[44], Bx0[44]}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({w_chi1[56], w_chi0[56]}));
MSKand_opini2_d2 u_chi_57 (
    .ina({nb_d1[57], nb_d0[57]}), .inb({Bx1[45], Bx0[45]}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({w_chi1[57], w_chi0[57]}));
MSKand_opini2_d2 u_chi_58 (
    .ina({nb_d1[58], nb_d0[58]}), .inb({Bx1[46], Bx0[46]}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({w_chi1[58], w_chi0[58]}));
MSKand_opini2_d2 u_chi_59 (
    .ina({nb_d1[59], nb_d0[59]}), .inb({Bx1[47], Bx0[47]}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({w_chi1[59], w_chi0[59]}));
MSKand_opini2_d2 u_chi_76 (
    .ina({nb_d1[76], nb_d0[76]}), .inb({Bx1[64], Bx0[64]}),
    .rnd(r[76]), .s(s[76]), .clk(clk), .out({w_chi1[76], w_chi0[76]}));
MSKand_opini2_d2 u_chi_77 (
    .ina({nb_d1[77], nb_d0[77]}), .inb({Bx1[65], Bx0[65]}),
    .rnd(r[77]), .s(s[77]), .clk(clk), .out({w_chi1[77], w_chi0[77]}));
MSKand_opini2_d2 u_chi_78 (
    .ina({nb_d1[78], nb_d0[78]}), .inb({Bx1[66], Bx0[66]}),
    .rnd(r[78]), .s(s[78]), .clk(clk), .out({w_chi1[78], w_chi0[78]}));
MSKand_opini2_d2 u_chi_79 (
    .ina({nb_d1[79], nb_d0[79]}), .inb({Bx1[67], Bx0[67]}),
    .rnd(r[79]), .s(s[79]), .clk(clk), .out({w_chi1[79], w_chi0[79]}));
MSKand_opini2_d2 u_chi_96 (
    .ina({nb_d1[96], nb_d0[96]}), .inb({Bx1[84], Bx0[84]}),
    .rnd(r[96]), .s(s[96]), .clk(clk), .out({w_chi1[96], w_chi0[96]}));
MSKand_opini2_d2 u_chi_97 (
    .ina({nb_d1[97], nb_d0[97]}), .inb({Bx1[85], Bx0[85]}),
    .rnd(r[97]), .s(s[97]), .clk(clk), .out({w_chi1[97], w_chi0[97]}));
MSKand_opini2_d2 u_chi_98 (
    .ina({nb_d1[98], nb_d0[98]}), .inb({Bx1[86], Bx0[86]}),
    .rnd(r[98]), .s(s[98]), .clk(clk), .out({w_chi1[98], w_chi0[98]}));
MSKand_opini2_d2 u_chi_99 (
    .ina({nb_d1[99], nb_d0[99]}), .inb({Bx1[87], Bx0[87]}),
    .rnd(r[99]), .s(s[99]), .clk(clk), .out({w_chi1[99], w_chi0[99]}));

// ---- outputs: dense re-pack of the state register ----
assign o[0] = St0[0];  assign o[1] = St1[0];
assign o[2] = St0[1];  assign o[3] = St1[1];
assign o[4] = St0[2];  assign o[5] = St1[2];
assign o[6] = St0[3];  assign o[7] = St1[3];
assign o[8] = St0[4];  assign o[9] = St1[4];
assign o[10] = St0[5];  assign o[11] = St1[5];
assign o[12] = St0[6];  assign o[13] = St1[6];
assign o[14] = St0[7];  assign o[15] = St1[7];
assign o[16] = St0[8];  assign o[17] = St1[8];
assign o[18] = St0[9];  assign o[19] = St1[9];
assign o[20] = St0[10];  assign o[21] = St1[10];
assign o[22] = St0[11];  assign o[23] = St1[11];
assign o[24] = St0[12];  assign o[25] = St1[12];
assign o[26] = St0[13];  assign o[27] = St1[13];
assign o[28] = St0[14];  assign o[29] = St1[14];
assign o[30] = St0[15];  assign o[31] = St1[15];
assign o[32] = St0[16];  assign o[33] = St1[16];
assign o[34] = St0[17];  assign o[35] = St1[17];
assign o[36] = St0[18];  assign o[37] = St1[18];
assign o[38] = St0[19];  assign o[39] = St1[19];
assign o[40] = St0[20];  assign o[41] = St1[20];
assign o[42] = St0[21];  assign o[43] = St1[21];
assign o[44] = St0[22];  assign o[45] = St1[22];
assign o[46] = St0[23];  assign o[47] = St1[23];
assign o[48] = St0[24];  assign o[49] = St1[24];
assign o[50] = St0[25];  assign o[51] = St1[25];
assign o[52] = St0[26];  assign o[53] = St1[26];
assign o[54] = St0[27];  assign o[55] = St1[27];
assign o[56] = St0[28];  assign o[57] = St1[28];
assign o[58] = St0[29];  assign o[59] = St1[29];
assign o[60] = St0[30];  assign o[61] = St1[30];
assign o[62] = St0[31];  assign o[63] = St1[31];
assign o[64] = St0[32];  assign o[65] = St1[32];
assign o[66] = St0[33];  assign o[67] = St1[33];
assign o[68] = St0[34];  assign o[69] = St1[34];
assign o[70] = St0[35];  assign o[71] = St1[35];
assign o[72] = St0[36];  assign o[73] = St1[36];
assign o[74] = St0[37];  assign o[75] = St1[37];
assign o[76] = St0[38];  assign o[77] = St1[38];
assign o[78] = St0[39];  assign o[79] = St1[39];
assign o[80] = St0[40];  assign o[81] = St1[40];
assign o[82] = St0[41];  assign o[83] = St1[41];
assign o[84] = St0[42];  assign o[85] = St1[42];
assign o[86] = St0[43];  assign o[87] = St1[43];
assign o[88] = St0[44];  assign o[89] = St1[44];
assign o[90] = St0[45];  assign o[91] = St1[45];
assign o[92] = St0[46];  assign o[93] = St1[46];
assign o[94] = St0[47];  assign o[95] = St1[47];
assign o[96] = St0[48];  assign o[97] = St1[48];
assign o[98] = St0[49];  assign o[99] = St1[49];
assign o[100] = St0[50];  assign o[101] = St1[50];
assign o[102] = St0[51];  assign o[103] = St1[51];
assign o[104] = St0[52];  assign o[105] = St1[52];
assign o[106] = St0[53];  assign o[107] = St1[53];
assign o[108] = St0[54];  assign o[109] = St1[54];
assign o[110] = St0[55];  assign o[111] = St1[55];
assign o[112] = St0[56];  assign o[113] = St1[56];
assign o[114] = St0[57];  assign o[115] = St1[57];
assign o[116] = St0[58];  assign o[117] = St1[58];
assign o[118] = St0[59];  assign o[119] = St1[59];
assign o[120] = St0[60];  assign o[121] = St1[60];
assign o[122] = St0[61];  assign o[123] = St1[61];
assign o[124] = St0[62];  assign o[125] = St1[62];
assign o[126] = St0[63];  assign o[127] = St1[63];
assign o[128] = St0[64];  assign o[129] = St1[64];
assign o[130] = St0[65];  assign o[131] = St1[65];
assign o[132] = St0[66];  assign o[133] = St1[66];
assign o[134] = St0[67];  assign o[135] = St1[67];
assign o[136] = St0[68];  assign o[137] = St1[68];
assign o[138] = St0[69];  assign o[139] = St1[69];
assign o[140] = St0[70];  assign o[141] = St1[70];
assign o[142] = St0[71];  assign o[143] = St1[71];
assign o[144] = St0[72];  assign o[145] = St1[72];
assign o[146] = St0[73];  assign o[147] = St1[73];
assign o[148] = St0[74];  assign o[149] = St1[74];
assign o[150] = St0[75];  assign o[151] = St1[75];
assign o[152] = St0[76];  assign o[153] = St1[76];
assign o[154] = St0[77];  assign o[155] = St1[77];
assign o[156] = St0[78];  assign o[157] = St1[78];
assign o[158] = St0[79];  assign o[159] = St1[79];
assign o[160] = St0[80];  assign o[161] = St1[80];
assign o[162] = St0[81];  assign o[163] = St1[81];
assign o[164] = St0[82];  assign o[165] = St1[82];
assign o[166] = St0[83];  assign o[167] = St1[83];
assign o[168] = St0[84];  assign o[169] = St1[84];
assign o[170] = St0[85];  assign o[171] = St1[85];
assign o[172] = St0[86];  assign o[173] = St1[86];
assign o[174] = St0[87];  assign o[175] = St1[87];
assign o[176] = St0[88];  assign o[177] = St1[88];
assign o[178] = St0[89];  assign o[179] = St1[89];
assign o[180] = St0[90];  assign o[181] = St1[90];
assign o[182] = St0[91];  assign o[183] = St1[91];
assign o[184] = St0[92];  assign o[185] = St1[92];
assign o[186] = St0[93];  assign o[187] = St1[93];
assign o[188] = St0[94];  assign o[189] = St1[94];
assign o[190] = St0[95];  assign o[191] = St1[95];
assign o[192] = St0[96];  assign o[193] = St1[96];
assign o[194] = St0[97];  assign o[195] = St1[97];
assign o[196] = St0[98];  assign o[197] = St1[98];
assign o[198] = St0[99];  assign o[199] = St1[99];

endmodule
