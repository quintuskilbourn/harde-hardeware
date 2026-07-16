// LABEL CONTROL: identical netlist but instantiates the PINI-relabelled
// leaf MSKand_opini2_d2_pini. This datapath REUSES gadgets bubble-free
// with feedback, so MATCHI's transition rule for PINI leaves is EXPECTED
// to reject it (cf. div16_pini). Verdict recorded either way.
// Masked Keccak-f[200] (18 rounds, w=8): one masked round unit — chi via
// 200 assumed-OPINI gadget leaves u_chi_* (one per state bit, DEDICATED
// r[k]/s[k] each), theta/rho/pi/iota strictly share-local — iterated in place
// by a public FSM. Dense sharing layout: port[2i]=share0, port[2i+1]=share1,
// state flat index w*(5y+x)+z (Keccak spec ordering).
// Schedule: load @0; round i occupies cycles [1+6i, 6+6i]; o (register)
// stable from cycle 109; state cleared (share-local, to public 0) at
// cycle 120; randoms fresh [0,130].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module keccakf200_pini (clk, rst, go, a, r, s, o);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [399:0] a;
(* matchi_type = "random", matchi_active = "r_act" *) input [199:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [199:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [399:0] o;

// ---- activity windows from an idempotent cycle counter (public control;
// counts 1.. from the go pulse, saturates — the div256 pattern) ----
reg [8:0] cnt;
always @(posedge clk) begin
    if (rst)                       cnt <= 9'd0;
    else if (go)                   cnt <= 9'd1;
    else if (cnt != 9'd0 && cnt != 9'd133) cnt <= cnt + 9'd1;
end
(* keep *) wire a_act   = go || (cnt == 9'd1);   // operand consumed at load
(* keep *) wire r_act   = go || (cnt >= 9'd1 && cnt <= 9'd130);
(* keep *) wire s_act   =       (cnt >= 9'd1 && cnt <= 9'd131);
(* keep *) wire out_act = go || (cnt >= 9'd1 && cnt <= 9'd128);
(* keep *) wire clr     = (cnt == 9'd120);  // bounded sensitivity

// ---- public FSM: round counter + phase (control only, data-independent) ----
reg running;
reg [4:0] rnd_i;
reg [2:0] ph;
always @(posedge clk) begin
    if (rst) begin running <= 1'b0; rnd_i <= 0; ph <= 0; end
    else if (go) begin running <= 1'b1; rnd_i <= 0; ph <= 0; end
    else if (running) begin
        if (ph == 5) begin
            ph <= 0;
            if (rnd_i == 5'd17) begin running <= 1'b0; rnd_i <= 0; end
            else rnd_i <= rnd_i + 5'd1;
        end else ph <= ph + 3'd1;
    end
end

// ---- iota round constant (public, XORed into share 0 of lane (0,0)) ----
wire [7:0] rc_cur = (rnd_i == 5'd0) ? 8'h01 :
               (rnd_i == 5'd1) ? 8'h82 :
               (rnd_i == 5'd2) ? 8'h8a :
               (rnd_i == 5'd3) ? 8'h00 :
               (rnd_i == 5'd4) ? 8'h8b :
               (rnd_i == 5'd5) ? 8'h01 :
               (rnd_i == 5'd6) ? 8'h81 :
               (rnd_i == 5'd7) ? 8'h09 :
               (rnd_i == 5'd8) ? 8'h8a :
               (rnd_i == 5'd9) ? 8'h88 :
               (rnd_i == 5'd10) ? 8'h09 :
               (rnd_i == 5'd11) ? 8'h0a :
               (rnd_i == 5'd12) ? 8'h8b :
               (rnd_i == 5'd13) ? 8'h8b :
               (rnd_i == 5'd14) ? 8'h89 :
               (rnd_i == 5'd15) ? 8'h03 :
               (rnd_i == 5'd16) ? 8'h02 :
               (rnd_i == 5'd17) ? 8'h80 :
               8'd0;

// ---- state registers (per-share; NEVER mix share 0 and share 1) ----
reg [199:0] St0, St1;
wire [199:0] Bx0, Bx1;         // after theta+rho+pi (share-local wiring)
wire [199:0] w_chi0, w_chi1;   // chi gadget outputs

always @(posedge clk) begin
    if (rst || clr) begin
        St0 <= 0; St1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        St0 <= {a[398], a[396], a[394], a[392], a[390], a[388], a[386], a[384], a[382], a[380], a[378], a[376], a[374], a[372], a[370], a[368], a[366], a[364], a[362], a[360], a[358], a[356], a[354], a[352], a[350], a[348], a[346], a[344], a[342], a[340], a[338], a[336], a[334], a[332], a[330], a[328], a[326], a[324], a[322], a[320], a[318], a[316], a[314], a[312], a[310], a[308], a[306], a[304], a[302], a[300], a[298], a[296], a[294], a[292], a[290], a[288], a[286], a[284], a[282], a[280], a[278], a[276], a[274], a[272], a[270], a[268], a[266], a[264], a[262], a[260], a[258], a[256], a[254], a[252], a[250], a[248], a[246], a[244], a[242], a[240], a[238], a[236], a[234], a[232], a[230], a[228], a[226], a[224], a[222], a[220], a[218], a[216], a[214], a[212], a[210], a[208], a[206], a[204], a[202], a[200], a[198], a[196], a[194], a[192], a[190], a[188], a[186], a[184], a[182], a[180], a[178], a[176], a[174], a[172], a[170], a[168], a[166], a[164], a[162], a[160], a[158], a[156], a[154], a[152], a[150], a[148], a[146], a[144], a[142], a[140], a[138], a[136], a[134], a[132], a[130], a[128], a[126], a[124], a[122], a[120], a[118], a[116], a[114], a[112], a[110], a[108], a[106], a[104], a[102], a[100], a[98], a[96], a[94], a[92], a[90], a[88], a[86], a[84], a[82], a[80], a[78], a[76], a[74], a[72], a[70], a[68], a[66], a[64], a[62], a[60], a[58], a[56], a[54], a[52], a[50], a[48], a[46], a[44], a[42], a[40], a[38], a[36], a[34], a[32], a[30], a[28], a[26], a[24], a[22], a[20], a[18], a[16], a[14], a[12], a[10], a[8], a[6], a[4], a[2], a[0]};
        St1 <= {a[399], a[397], a[395], a[393], a[391], a[389], a[387], a[385], a[383], a[381], a[379], a[377], a[375], a[373], a[371], a[369], a[367], a[365], a[363], a[361], a[359], a[357], a[355], a[353], a[351], a[349], a[347], a[345], a[343], a[341], a[339], a[337], a[335], a[333], a[331], a[329], a[327], a[325], a[323], a[321], a[319], a[317], a[315], a[313], a[311], a[309], a[307], a[305], a[303], a[301], a[299], a[297], a[295], a[293], a[291], a[289], a[287], a[285], a[283], a[281], a[279], a[277], a[275], a[273], a[271], a[269], a[267], a[265], a[263], a[261], a[259], a[257], a[255], a[253], a[251], a[249], a[247], a[245], a[243], a[241], a[239], a[237], a[235], a[233], a[231], a[229], a[227], a[225], a[223], a[221], a[219], a[217], a[215], a[213], a[211], a[209], a[207], a[205], a[203], a[201], a[199], a[197], a[195], a[193], a[191], a[189], a[187], a[185], a[183], a[181], a[179], a[177], a[175], a[173], a[171], a[169], a[167], a[165], a[163], a[161], a[159], a[157], a[155], a[153], a[151], a[149], a[147], a[145], a[143], a[141], a[139], a[137], a[135], a[133], a[131], a[129], a[127], a[125], a[123], a[121], a[119], a[117], a[115], a[113], a[111], a[109], a[107], a[105], a[103], a[101], a[99], a[97], a[95], a[93], a[91], a[89], a[87], a[85], a[83], a[81], a[79], a[77], a[75], a[73], a[71], a[69], a[67], a[65], a[63], a[61], a[59], a[57], a[55], a[53], a[51], a[49], a[47], a[45], a[43], a[41], a[39], a[37], a[35], a[33], a[31], a[29], a[27], a[25], a[23], a[21], a[19], a[17], a[15], a[13], a[11], a[9], a[7], a[5], a[3], a[1]};
    end else if (running && ph == 5) begin
        // chi outer XOR + iota, all share-local (iota into share 0 only)
        St0 <= Bx0 ^ w_chi0 ^ {{192{1'b0}}, rc_cur};
        St1 <= Bx1 ^ w_chi1;
    end
end

// ---- theta (share-local XOR network) ----

wire [39:0] C0, D0;
assign C0[0] = St0[0] ^ St0[40] ^ St0[80] ^ St0[120] ^ St0[160];
assign C0[1] = St0[1] ^ St0[41] ^ St0[81] ^ St0[121] ^ St0[161];
assign C0[2] = St0[2] ^ St0[42] ^ St0[82] ^ St0[122] ^ St0[162];
assign C0[3] = St0[3] ^ St0[43] ^ St0[83] ^ St0[123] ^ St0[163];
assign C0[4] = St0[4] ^ St0[44] ^ St0[84] ^ St0[124] ^ St0[164];
assign C0[5] = St0[5] ^ St0[45] ^ St0[85] ^ St0[125] ^ St0[165];
assign C0[6] = St0[6] ^ St0[46] ^ St0[86] ^ St0[126] ^ St0[166];
assign C0[7] = St0[7] ^ St0[47] ^ St0[87] ^ St0[127] ^ St0[167];
assign C0[8] = St0[8] ^ St0[48] ^ St0[88] ^ St0[128] ^ St0[168];
assign C0[9] = St0[9] ^ St0[49] ^ St0[89] ^ St0[129] ^ St0[169];
assign C0[10] = St0[10] ^ St0[50] ^ St0[90] ^ St0[130] ^ St0[170];
assign C0[11] = St0[11] ^ St0[51] ^ St0[91] ^ St0[131] ^ St0[171];
assign C0[12] = St0[12] ^ St0[52] ^ St0[92] ^ St0[132] ^ St0[172];
assign C0[13] = St0[13] ^ St0[53] ^ St0[93] ^ St0[133] ^ St0[173];
assign C0[14] = St0[14] ^ St0[54] ^ St0[94] ^ St0[134] ^ St0[174];
assign C0[15] = St0[15] ^ St0[55] ^ St0[95] ^ St0[135] ^ St0[175];
assign C0[16] = St0[16] ^ St0[56] ^ St0[96] ^ St0[136] ^ St0[176];
assign C0[17] = St0[17] ^ St0[57] ^ St0[97] ^ St0[137] ^ St0[177];
assign C0[18] = St0[18] ^ St0[58] ^ St0[98] ^ St0[138] ^ St0[178];
assign C0[19] = St0[19] ^ St0[59] ^ St0[99] ^ St0[139] ^ St0[179];
assign C0[20] = St0[20] ^ St0[60] ^ St0[100] ^ St0[140] ^ St0[180];
assign C0[21] = St0[21] ^ St0[61] ^ St0[101] ^ St0[141] ^ St0[181];
assign C0[22] = St0[22] ^ St0[62] ^ St0[102] ^ St0[142] ^ St0[182];
assign C0[23] = St0[23] ^ St0[63] ^ St0[103] ^ St0[143] ^ St0[183];
assign C0[24] = St0[24] ^ St0[64] ^ St0[104] ^ St0[144] ^ St0[184];
assign C0[25] = St0[25] ^ St0[65] ^ St0[105] ^ St0[145] ^ St0[185];
assign C0[26] = St0[26] ^ St0[66] ^ St0[106] ^ St0[146] ^ St0[186];
assign C0[27] = St0[27] ^ St0[67] ^ St0[107] ^ St0[147] ^ St0[187];
assign C0[28] = St0[28] ^ St0[68] ^ St0[108] ^ St0[148] ^ St0[188];
assign C0[29] = St0[29] ^ St0[69] ^ St0[109] ^ St0[149] ^ St0[189];
assign C0[30] = St0[30] ^ St0[70] ^ St0[110] ^ St0[150] ^ St0[190];
assign C0[31] = St0[31] ^ St0[71] ^ St0[111] ^ St0[151] ^ St0[191];
assign C0[32] = St0[32] ^ St0[72] ^ St0[112] ^ St0[152] ^ St0[192];
assign C0[33] = St0[33] ^ St0[73] ^ St0[113] ^ St0[153] ^ St0[193];
assign C0[34] = St0[34] ^ St0[74] ^ St0[114] ^ St0[154] ^ St0[194];
assign C0[35] = St0[35] ^ St0[75] ^ St0[115] ^ St0[155] ^ St0[195];
assign C0[36] = St0[36] ^ St0[76] ^ St0[116] ^ St0[156] ^ St0[196];
assign C0[37] = St0[37] ^ St0[77] ^ St0[117] ^ St0[157] ^ St0[197];
assign C0[38] = St0[38] ^ St0[78] ^ St0[118] ^ St0[158] ^ St0[198];
assign C0[39] = St0[39] ^ St0[79] ^ St0[119] ^ St0[159] ^ St0[199];
assign D0[0] = C0[32] ^ C0[15];
assign D0[1] = C0[33] ^ C0[8];
assign D0[2] = C0[34] ^ C0[9];
assign D0[3] = C0[35] ^ C0[10];
assign D0[4] = C0[36] ^ C0[11];
assign D0[5] = C0[37] ^ C0[12];
assign D0[6] = C0[38] ^ C0[13];
assign D0[7] = C0[39] ^ C0[14];
assign D0[8] = C0[0] ^ C0[23];
assign D0[9] = C0[1] ^ C0[16];
assign D0[10] = C0[2] ^ C0[17];
assign D0[11] = C0[3] ^ C0[18];
assign D0[12] = C0[4] ^ C0[19];
assign D0[13] = C0[5] ^ C0[20];
assign D0[14] = C0[6] ^ C0[21];
assign D0[15] = C0[7] ^ C0[22];
assign D0[16] = C0[8] ^ C0[31];
assign D0[17] = C0[9] ^ C0[24];
assign D0[18] = C0[10] ^ C0[25];
assign D0[19] = C0[11] ^ C0[26];
assign D0[20] = C0[12] ^ C0[27];
assign D0[21] = C0[13] ^ C0[28];
assign D0[22] = C0[14] ^ C0[29];
assign D0[23] = C0[15] ^ C0[30];
assign D0[24] = C0[16] ^ C0[39];
assign D0[25] = C0[17] ^ C0[32];
assign D0[26] = C0[18] ^ C0[33];
assign D0[27] = C0[19] ^ C0[34];
assign D0[28] = C0[20] ^ C0[35];
assign D0[29] = C0[21] ^ C0[36];
assign D0[30] = C0[22] ^ C0[37];
assign D0[31] = C0[23] ^ C0[38];
assign D0[32] = C0[24] ^ C0[7];
assign D0[33] = C0[25] ^ C0[0];
assign D0[34] = C0[26] ^ C0[1];
assign D0[35] = C0[27] ^ C0[2];
assign D0[36] = C0[28] ^ C0[3];
assign D0[37] = C0[29] ^ C0[4];
assign D0[38] = C0[30] ^ C0[5];
assign D0[39] = C0[31] ^ C0[6];
wire [39:0] C1, D1;
assign C1[0] = St1[0] ^ St1[40] ^ St1[80] ^ St1[120] ^ St1[160];
assign C1[1] = St1[1] ^ St1[41] ^ St1[81] ^ St1[121] ^ St1[161];
assign C1[2] = St1[2] ^ St1[42] ^ St1[82] ^ St1[122] ^ St1[162];
assign C1[3] = St1[3] ^ St1[43] ^ St1[83] ^ St1[123] ^ St1[163];
assign C1[4] = St1[4] ^ St1[44] ^ St1[84] ^ St1[124] ^ St1[164];
assign C1[5] = St1[5] ^ St1[45] ^ St1[85] ^ St1[125] ^ St1[165];
assign C1[6] = St1[6] ^ St1[46] ^ St1[86] ^ St1[126] ^ St1[166];
assign C1[7] = St1[7] ^ St1[47] ^ St1[87] ^ St1[127] ^ St1[167];
assign C1[8] = St1[8] ^ St1[48] ^ St1[88] ^ St1[128] ^ St1[168];
assign C1[9] = St1[9] ^ St1[49] ^ St1[89] ^ St1[129] ^ St1[169];
assign C1[10] = St1[10] ^ St1[50] ^ St1[90] ^ St1[130] ^ St1[170];
assign C1[11] = St1[11] ^ St1[51] ^ St1[91] ^ St1[131] ^ St1[171];
assign C1[12] = St1[12] ^ St1[52] ^ St1[92] ^ St1[132] ^ St1[172];
assign C1[13] = St1[13] ^ St1[53] ^ St1[93] ^ St1[133] ^ St1[173];
assign C1[14] = St1[14] ^ St1[54] ^ St1[94] ^ St1[134] ^ St1[174];
assign C1[15] = St1[15] ^ St1[55] ^ St1[95] ^ St1[135] ^ St1[175];
assign C1[16] = St1[16] ^ St1[56] ^ St1[96] ^ St1[136] ^ St1[176];
assign C1[17] = St1[17] ^ St1[57] ^ St1[97] ^ St1[137] ^ St1[177];
assign C1[18] = St1[18] ^ St1[58] ^ St1[98] ^ St1[138] ^ St1[178];
assign C1[19] = St1[19] ^ St1[59] ^ St1[99] ^ St1[139] ^ St1[179];
assign C1[20] = St1[20] ^ St1[60] ^ St1[100] ^ St1[140] ^ St1[180];
assign C1[21] = St1[21] ^ St1[61] ^ St1[101] ^ St1[141] ^ St1[181];
assign C1[22] = St1[22] ^ St1[62] ^ St1[102] ^ St1[142] ^ St1[182];
assign C1[23] = St1[23] ^ St1[63] ^ St1[103] ^ St1[143] ^ St1[183];
assign C1[24] = St1[24] ^ St1[64] ^ St1[104] ^ St1[144] ^ St1[184];
assign C1[25] = St1[25] ^ St1[65] ^ St1[105] ^ St1[145] ^ St1[185];
assign C1[26] = St1[26] ^ St1[66] ^ St1[106] ^ St1[146] ^ St1[186];
assign C1[27] = St1[27] ^ St1[67] ^ St1[107] ^ St1[147] ^ St1[187];
assign C1[28] = St1[28] ^ St1[68] ^ St1[108] ^ St1[148] ^ St1[188];
assign C1[29] = St1[29] ^ St1[69] ^ St1[109] ^ St1[149] ^ St1[189];
assign C1[30] = St1[30] ^ St1[70] ^ St1[110] ^ St1[150] ^ St1[190];
assign C1[31] = St1[31] ^ St1[71] ^ St1[111] ^ St1[151] ^ St1[191];
assign C1[32] = St1[32] ^ St1[72] ^ St1[112] ^ St1[152] ^ St1[192];
assign C1[33] = St1[33] ^ St1[73] ^ St1[113] ^ St1[153] ^ St1[193];
assign C1[34] = St1[34] ^ St1[74] ^ St1[114] ^ St1[154] ^ St1[194];
assign C1[35] = St1[35] ^ St1[75] ^ St1[115] ^ St1[155] ^ St1[195];
assign C1[36] = St1[36] ^ St1[76] ^ St1[116] ^ St1[156] ^ St1[196];
assign C1[37] = St1[37] ^ St1[77] ^ St1[117] ^ St1[157] ^ St1[197];
assign C1[38] = St1[38] ^ St1[78] ^ St1[118] ^ St1[158] ^ St1[198];
assign C1[39] = St1[39] ^ St1[79] ^ St1[119] ^ St1[159] ^ St1[199];
assign D1[0] = C1[32] ^ C1[15];
assign D1[1] = C1[33] ^ C1[8];
assign D1[2] = C1[34] ^ C1[9];
assign D1[3] = C1[35] ^ C1[10];
assign D1[4] = C1[36] ^ C1[11];
assign D1[5] = C1[37] ^ C1[12];
assign D1[6] = C1[38] ^ C1[13];
assign D1[7] = C1[39] ^ C1[14];
assign D1[8] = C1[0] ^ C1[23];
assign D1[9] = C1[1] ^ C1[16];
assign D1[10] = C1[2] ^ C1[17];
assign D1[11] = C1[3] ^ C1[18];
assign D1[12] = C1[4] ^ C1[19];
assign D1[13] = C1[5] ^ C1[20];
assign D1[14] = C1[6] ^ C1[21];
assign D1[15] = C1[7] ^ C1[22];
assign D1[16] = C1[8] ^ C1[31];
assign D1[17] = C1[9] ^ C1[24];
assign D1[18] = C1[10] ^ C1[25];
assign D1[19] = C1[11] ^ C1[26];
assign D1[20] = C1[12] ^ C1[27];
assign D1[21] = C1[13] ^ C1[28];
assign D1[22] = C1[14] ^ C1[29];
assign D1[23] = C1[15] ^ C1[30];
assign D1[24] = C1[16] ^ C1[39];
assign D1[25] = C1[17] ^ C1[32];
assign D1[26] = C1[18] ^ C1[33];
assign D1[27] = C1[19] ^ C1[34];
assign D1[28] = C1[20] ^ C1[35];
assign D1[29] = C1[21] ^ C1[36];
assign D1[30] = C1[22] ^ C1[37];
assign D1[31] = C1[23] ^ C1[38];
assign D1[32] = C1[24] ^ C1[7];
assign D1[33] = C1[25] ^ C1[0];
assign D1[34] = C1[26] ^ C1[1];
assign D1[35] = C1[27] ^ C1[2];
assign D1[36] = C1[28] ^ C1[3];
assign D1[37] = C1[29] ^ C1[4];
assign D1[38] = C1[30] ^ C1[5];
assign D1[39] = C1[31] ^ C1[6];

// ---- rho + pi (pure wiring): Bx[(2x+3y)%5 lane-row perm][z] ----
assign Bx0[0] = St0[0] ^ D0[0];
assign Bx0[1] = St0[1] ^ D0[1];
assign Bx0[2] = St0[2] ^ D0[2];
assign Bx0[3] = St0[3] ^ D0[3];
assign Bx0[4] = St0[4] ^ D0[4];
assign Bx0[5] = St0[5] ^ D0[5];
assign Bx0[6] = St0[6] ^ D0[6];
assign Bx0[7] = St0[7] ^ D0[7];
assign Bx0[128] = St0[44] ^ D0[4];
assign Bx0[129] = St0[45] ^ D0[5];
assign Bx0[130] = St0[46] ^ D0[6];
assign Bx0[131] = St0[47] ^ D0[7];
assign Bx0[132] = St0[40] ^ D0[0];
assign Bx0[133] = St0[41] ^ D0[1];
assign Bx0[134] = St0[42] ^ D0[2];
assign Bx0[135] = St0[43] ^ D0[3];
assign Bx0[56] = St0[85] ^ D0[5];
assign Bx0[57] = St0[86] ^ D0[6];
assign Bx0[58] = St0[87] ^ D0[7];
assign Bx0[59] = St0[80] ^ D0[0];
assign Bx0[60] = St0[81] ^ D0[1];
assign Bx0[61] = St0[82] ^ D0[2];
assign Bx0[62] = St0[83] ^ D0[3];
assign Bx0[63] = St0[84] ^ D0[4];
assign Bx0[184] = St0[127] ^ D0[7];
assign Bx0[185] = St0[120] ^ D0[0];
assign Bx0[186] = St0[121] ^ D0[1];
assign Bx0[187] = St0[122] ^ D0[2];
assign Bx0[188] = St0[123] ^ D0[3];
assign Bx0[189] = St0[124] ^ D0[4];
assign Bx0[190] = St0[125] ^ D0[5];
assign Bx0[191] = St0[126] ^ D0[6];
assign Bx0[112] = St0[166] ^ D0[6];
assign Bx0[113] = St0[167] ^ D0[7];
assign Bx0[114] = St0[160] ^ D0[0];
assign Bx0[115] = St0[161] ^ D0[1];
assign Bx0[116] = St0[162] ^ D0[2];
assign Bx0[117] = St0[163] ^ D0[3];
assign Bx0[118] = St0[164] ^ D0[4];
assign Bx0[119] = St0[165] ^ D0[5];
assign Bx0[80] = St0[15] ^ D0[15];
assign Bx0[81] = St0[8] ^ D0[8];
assign Bx0[82] = St0[9] ^ D0[9];
assign Bx0[83] = St0[10] ^ D0[10];
assign Bx0[84] = St0[11] ^ D0[11];
assign Bx0[85] = St0[12] ^ D0[12];
assign Bx0[86] = St0[13] ^ D0[13];
assign Bx0[87] = St0[14] ^ D0[14];
assign Bx0[8] = St0[52] ^ D0[12];
assign Bx0[9] = St0[53] ^ D0[13];
assign Bx0[10] = St0[54] ^ D0[14];
assign Bx0[11] = St0[55] ^ D0[15];
assign Bx0[12] = St0[48] ^ D0[8];
assign Bx0[13] = St0[49] ^ D0[9];
assign Bx0[14] = St0[50] ^ D0[10];
assign Bx0[15] = St0[51] ^ D0[11];
assign Bx0[136] = St0[94] ^ D0[14];
assign Bx0[137] = St0[95] ^ D0[15];
assign Bx0[138] = St0[88] ^ D0[8];
assign Bx0[139] = St0[89] ^ D0[9];
assign Bx0[140] = St0[90] ^ D0[10];
assign Bx0[141] = St0[91] ^ D0[11];
assign Bx0[142] = St0[92] ^ D0[12];
assign Bx0[143] = St0[93] ^ D0[13];
assign Bx0[64] = St0[131] ^ D0[11];
assign Bx0[65] = St0[132] ^ D0[12];
assign Bx0[66] = St0[133] ^ D0[13];
assign Bx0[67] = St0[134] ^ D0[14];
assign Bx0[68] = St0[135] ^ D0[15];
assign Bx0[69] = St0[128] ^ D0[8];
assign Bx0[70] = St0[129] ^ D0[9];
assign Bx0[71] = St0[130] ^ D0[10];
assign Bx0[192] = St0[174] ^ D0[14];
assign Bx0[193] = St0[175] ^ D0[15];
assign Bx0[194] = St0[168] ^ D0[8];
assign Bx0[195] = St0[169] ^ D0[9];
assign Bx0[196] = St0[170] ^ D0[10];
assign Bx0[197] = St0[171] ^ D0[11];
assign Bx0[198] = St0[172] ^ D0[12];
assign Bx0[199] = St0[173] ^ D0[13];
assign Bx0[160] = St0[18] ^ D0[18];
assign Bx0[161] = St0[19] ^ D0[19];
assign Bx0[162] = St0[20] ^ D0[20];
assign Bx0[163] = St0[21] ^ D0[21];
assign Bx0[164] = St0[22] ^ D0[22];
assign Bx0[165] = St0[23] ^ D0[23];
assign Bx0[166] = St0[16] ^ D0[16];
assign Bx0[167] = St0[17] ^ D0[17];
assign Bx0[88] = St0[58] ^ D0[18];
assign Bx0[89] = St0[59] ^ D0[19];
assign Bx0[90] = St0[60] ^ D0[20];
assign Bx0[91] = St0[61] ^ D0[21];
assign Bx0[92] = St0[62] ^ D0[22];
assign Bx0[93] = St0[63] ^ D0[23];
assign Bx0[94] = St0[56] ^ D0[16];
assign Bx0[95] = St0[57] ^ D0[17];
assign Bx0[16] = St0[101] ^ D0[21];
assign Bx0[17] = St0[102] ^ D0[22];
assign Bx0[18] = St0[103] ^ D0[23];
assign Bx0[19] = St0[96] ^ D0[16];
assign Bx0[20] = St0[97] ^ D0[17];
assign Bx0[21] = St0[98] ^ D0[18];
assign Bx0[22] = St0[99] ^ D0[19];
assign Bx0[23] = St0[100] ^ D0[20];
assign Bx0[144] = St0[137] ^ D0[17];
assign Bx0[145] = St0[138] ^ D0[18];
assign Bx0[146] = St0[139] ^ D0[19];
assign Bx0[147] = St0[140] ^ D0[20];
assign Bx0[148] = St0[141] ^ D0[21];
assign Bx0[149] = St0[142] ^ D0[22];
assign Bx0[150] = St0[143] ^ D0[23];
assign Bx0[151] = St0[136] ^ D0[16];
assign Bx0[72] = St0[179] ^ D0[19];
assign Bx0[73] = St0[180] ^ D0[20];
assign Bx0[74] = St0[181] ^ D0[21];
assign Bx0[75] = St0[182] ^ D0[22];
assign Bx0[76] = St0[183] ^ D0[23];
assign Bx0[77] = St0[176] ^ D0[16];
assign Bx0[78] = St0[177] ^ D0[17];
assign Bx0[79] = St0[178] ^ D0[18];
assign Bx0[40] = St0[28] ^ D0[28];
assign Bx0[41] = St0[29] ^ D0[29];
assign Bx0[42] = St0[30] ^ D0[30];
assign Bx0[43] = St0[31] ^ D0[31];
assign Bx0[44] = St0[24] ^ D0[24];
assign Bx0[45] = St0[25] ^ D0[25];
assign Bx0[46] = St0[26] ^ D0[26];
assign Bx0[47] = St0[27] ^ D0[27];
assign Bx0[168] = St0[65] ^ D0[25];
assign Bx0[169] = St0[66] ^ D0[26];
assign Bx0[170] = St0[67] ^ D0[27];
assign Bx0[171] = St0[68] ^ D0[28];
assign Bx0[172] = St0[69] ^ D0[29];
assign Bx0[173] = St0[70] ^ D0[30];
assign Bx0[174] = St0[71] ^ D0[31];
assign Bx0[175] = St0[64] ^ D0[24];
assign Bx0[96] = St0[111] ^ D0[31];
assign Bx0[97] = St0[104] ^ D0[24];
assign Bx0[98] = St0[105] ^ D0[25];
assign Bx0[99] = St0[106] ^ D0[26];
assign Bx0[100] = St0[107] ^ D0[27];
assign Bx0[101] = St0[108] ^ D0[28];
assign Bx0[102] = St0[109] ^ D0[29];
assign Bx0[103] = St0[110] ^ D0[30];
assign Bx0[24] = St0[147] ^ D0[27];
assign Bx0[25] = St0[148] ^ D0[28];
assign Bx0[26] = St0[149] ^ D0[29];
assign Bx0[27] = St0[150] ^ D0[30];
assign Bx0[28] = St0[151] ^ D0[31];
assign Bx0[29] = St0[144] ^ D0[24];
assign Bx0[30] = St0[145] ^ D0[25];
assign Bx0[31] = St0[146] ^ D0[26];
assign Bx0[152] = St0[184] ^ D0[24];
assign Bx0[153] = St0[185] ^ D0[25];
assign Bx0[154] = St0[186] ^ D0[26];
assign Bx0[155] = St0[187] ^ D0[27];
assign Bx0[156] = St0[188] ^ D0[28];
assign Bx0[157] = St0[189] ^ D0[29];
assign Bx0[158] = St0[190] ^ D0[30];
assign Bx0[159] = St0[191] ^ D0[31];
assign Bx0[120] = St0[37] ^ D0[37];
assign Bx0[121] = St0[38] ^ D0[38];
assign Bx0[122] = St0[39] ^ D0[39];
assign Bx0[123] = St0[32] ^ D0[32];
assign Bx0[124] = St0[33] ^ D0[33];
assign Bx0[125] = St0[34] ^ D0[34];
assign Bx0[126] = St0[35] ^ D0[35];
assign Bx0[127] = St0[36] ^ D0[36];
assign Bx0[48] = St0[76] ^ D0[36];
assign Bx0[49] = St0[77] ^ D0[37];
assign Bx0[50] = St0[78] ^ D0[38];
assign Bx0[51] = St0[79] ^ D0[39];
assign Bx0[52] = St0[72] ^ D0[32];
assign Bx0[53] = St0[73] ^ D0[33];
assign Bx0[54] = St0[74] ^ D0[34];
assign Bx0[55] = St0[75] ^ D0[35];
assign Bx0[176] = St0[113] ^ D0[33];
assign Bx0[177] = St0[114] ^ D0[34];
assign Bx0[178] = St0[115] ^ D0[35];
assign Bx0[179] = St0[116] ^ D0[36];
assign Bx0[180] = St0[117] ^ D0[37];
assign Bx0[181] = St0[118] ^ D0[38];
assign Bx0[182] = St0[119] ^ D0[39];
assign Bx0[183] = St0[112] ^ D0[32];
assign Bx0[104] = St0[152] ^ D0[32];
assign Bx0[105] = St0[153] ^ D0[33];
assign Bx0[106] = St0[154] ^ D0[34];
assign Bx0[107] = St0[155] ^ D0[35];
assign Bx0[108] = St0[156] ^ D0[36];
assign Bx0[109] = St0[157] ^ D0[37];
assign Bx0[110] = St0[158] ^ D0[38];
assign Bx0[111] = St0[159] ^ D0[39];
assign Bx0[32] = St0[194] ^ D0[34];
assign Bx0[33] = St0[195] ^ D0[35];
assign Bx0[34] = St0[196] ^ D0[36];
assign Bx0[35] = St0[197] ^ D0[37];
assign Bx0[36] = St0[198] ^ D0[38];
assign Bx0[37] = St0[199] ^ D0[39];
assign Bx0[38] = St0[192] ^ D0[32];
assign Bx0[39] = St0[193] ^ D0[33];
assign Bx1[0] = St1[0] ^ D1[0];
assign Bx1[1] = St1[1] ^ D1[1];
assign Bx1[2] = St1[2] ^ D1[2];
assign Bx1[3] = St1[3] ^ D1[3];
assign Bx1[4] = St1[4] ^ D1[4];
assign Bx1[5] = St1[5] ^ D1[5];
assign Bx1[6] = St1[6] ^ D1[6];
assign Bx1[7] = St1[7] ^ D1[7];
assign Bx1[128] = St1[44] ^ D1[4];
assign Bx1[129] = St1[45] ^ D1[5];
assign Bx1[130] = St1[46] ^ D1[6];
assign Bx1[131] = St1[47] ^ D1[7];
assign Bx1[132] = St1[40] ^ D1[0];
assign Bx1[133] = St1[41] ^ D1[1];
assign Bx1[134] = St1[42] ^ D1[2];
assign Bx1[135] = St1[43] ^ D1[3];
assign Bx1[56] = St1[85] ^ D1[5];
assign Bx1[57] = St1[86] ^ D1[6];
assign Bx1[58] = St1[87] ^ D1[7];
assign Bx1[59] = St1[80] ^ D1[0];
assign Bx1[60] = St1[81] ^ D1[1];
assign Bx1[61] = St1[82] ^ D1[2];
assign Bx1[62] = St1[83] ^ D1[3];
assign Bx1[63] = St1[84] ^ D1[4];
assign Bx1[184] = St1[127] ^ D1[7];
assign Bx1[185] = St1[120] ^ D1[0];
assign Bx1[186] = St1[121] ^ D1[1];
assign Bx1[187] = St1[122] ^ D1[2];
assign Bx1[188] = St1[123] ^ D1[3];
assign Bx1[189] = St1[124] ^ D1[4];
assign Bx1[190] = St1[125] ^ D1[5];
assign Bx1[191] = St1[126] ^ D1[6];
assign Bx1[112] = St1[166] ^ D1[6];
assign Bx1[113] = St1[167] ^ D1[7];
assign Bx1[114] = St1[160] ^ D1[0];
assign Bx1[115] = St1[161] ^ D1[1];
assign Bx1[116] = St1[162] ^ D1[2];
assign Bx1[117] = St1[163] ^ D1[3];
assign Bx1[118] = St1[164] ^ D1[4];
assign Bx1[119] = St1[165] ^ D1[5];
assign Bx1[80] = St1[15] ^ D1[15];
assign Bx1[81] = St1[8] ^ D1[8];
assign Bx1[82] = St1[9] ^ D1[9];
assign Bx1[83] = St1[10] ^ D1[10];
assign Bx1[84] = St1[11] ^ D1[11];
assign Bx1[85] = St1[12] ^ D1[12];
assign Bx1[86] = St1[13] ^ D1[13];
assign Bx1[87] = St1[14] ^ D1[14];
assign Bx1[8] = St1[52] ^ D1[12];
assign Bx1[9] = St1[53] ^ D1[13];
assign Bx1[10] = St1[54] ^ D1[14];
assign Bx1[11] = St1[55] ^ D1[15];
assign Bx1[12] = St1[48] ^ D1[8];
assign Bx1[13] = St1[49] ^ D1[9];
assign Bx1[14] = St1[50] ^ D1[10];
assign Bx1[15] = St1[51] ^ D1[11];
assign Bx1[136] = St1[94] ^ D1[14];
assign Bx1[137] = St1[95] ^ D1[15];
assign Bx1[138] = St1[88] ^ D1[8];
assign Bx1[139] = St1[89] ^ D1[9];
assign Bx1[140] = St1[90] ^ D1[10];
assign Bx1[141] = St1[91] ^ D1[11];
assign Bx1[142] = St1[92] ^ D1[12];
assign Bx1[143] = St1[93] ^ D1[13];
assign Bx1[64] = St1[131] ^ D1[11];
assign Bx1[65] = St1[132] ^ D1[12];
assign Bx1[66] = St1[133] ^ D1[13];
assign Bx1[67] = St1[134] ^ D1[14];
assign Bx1[68] = St1[135] ^ D1[15];
assign Bx1[69] = St1[128] ^ D1[8];
assign Bx1[70] = St1[129] ^ D1[9];
assign Bx1[71] = St1[130] ^ D1[10];
assign Bx1[192] = St1[174] ^ D1[14];
assign Bx1[193] = St1[175] ^ D1[15];
assign Bx1[194] = St1[168] ^ D1[8];
assign Bx1[195] = St1[169] ^ D1[9];
assign Bx1[196] = St1[170] ^ D1[10];
assign Bx1[197] = St1[171] ^ D1[11];
assign Bx1[198] = St1[172] ^ D1[12];
assign Bx1[199] = St1[173] ^ D1[13];
assign Bx1[160] = St1[18] ^ D1[18];
assign Bx1[161] = St1[19] ^ D1[19];
assign Bx1[162] = St1[20] ^ D1[20];
assign Bx1[163] = St1[21] ^ D1[21];
assign Bx1[164] = St1[22] ^ D1[22];
assign Bx1[165] = St1[23] ^ D1[23];
assign Bx1[166] = St1[16] ^ D1[16];
assign Bx1[167] = St1[17] ^ D1[17];
assign Bx1[88] = St1[58] ^ D1[18];
assign Bx1[89] = St1[59] ^ D1[19];
assign Bx1[90] = St1[60] ^ D1[20];
assign Bx1[91] = St1[61] ^ D1[21];
assign Bx1[92] = St1[62] ^ D1[22];
assign Bx1[93] = St1[63] ^ D1[23];
assign Bx1[94] = St1[56] ^ D1[16];
assign Bx1[95] = St1[57] ^ D1[17];
assign Bx1[16] = St1[101] ^ D1[21];
assign Bx1[17] = St1[102] ^ D1[22];
assign Bx1[18] = St1[103] ^ D1[23];
assign Bx1[19] = St1[96] ^ D1[16];
assign Bx1[20] = St1[97] ^ D1[17];
assign Bx1[21] = St1[98] ^ D1[18];
assign Bx1[22] = St1[99] ^ D1[19];
assign Bx1[23] = St1[100] ^ D1[20];
assign Bx1[144] = St1[137] ^ D1[17];
assign Bx1[145] = St1[138] ^ D1[18];
assign Bx1[146] = St1[139] ^ D1[19];
assign Bx1[147] = St1[140] ^ D1[20];
assign Bx1[148] = St1[141] ^ D1[21];
assign Bx1[149] = St1[142] ^ D1[22];
assign Bx1[150] = St1[143] ^ D1[23];
assign Bx1[151] = St1[136] ^ D1[16];
assign Bx1[72] = St1[179] ^ D1[19];
assign Bx1[73] = St1[180] ^ D1[20];
assign Bx1[74] = St1[181] ^ D1[21];
assign Bx1[75] = St1[182] ^ D1[22];
assign Bx1[76] = St1[183] ^ D1[23];
assign Bx1[77] = St1[176] ^ D1[16];
assign Bx1[78] = St1[177] ^ D1[17];
assign Bx1[79] = St1[178] ^ D1[18];
assign Bx1[40] = St1[28] ^ D1[28];
assign Bx1[41] = St1[29] ^ D1[29];
assign Bx1[42] = St1[30] ^ D1[30];
assign Bx1[43] = St1[31] ^ D1[31];
assign Bx1[44] = St1[24] ^ D1[24];
assign Bx1[45] = St1[25] ^ D1[25];
assign Bx1[46] = St1[26] ^ D1[26];
assign Bx1[47] = St1[27] ^ D1[27];
assign Bx1[168] = St1[65] ^ D1[25];
assign Bx1[169] = St1[66] ^ D1[26];
assign Bx1[170] = St1[67] ^ D1[27];
assign Bx1[171] = St1[68] ^ D1[28];
assign Bx1[172] = St1[69] ^ D1[29];
assign Bx1[173] = St1[70] ^ D1[30];
assign Bx1[174] = St1[71] ^ D1[31];
assign Bx1[175] = St1[64] ^ D1[24];
assign Bx1[96] = St1[111] ^ D1[31];
assign Bx1[97] = St1[104] ^ D1[24];
assign Bx1[98] = St1[105] ^ D1[25];
assign Bx1[99] = St1[106] ^ D1[26];
assign Bx1[100] = St1[107] ^ D1[27];
assign Bx1[101] = St1[108] ^ D1[28];
assign Bx1[102] = St1[109] ^ D1[29];
assign Bx1[103] = St1[110] ^ D1[30];
assign Bx1[24] = St1[147] ^ D1[27];
assign Bx1[25] = St1[148] ^ D1[28];
assign Bx1[26] = St1[149] ^ D1[29];
assign Bx1[27] = St1[150] ^ D1[30];
assign Bx1[28] = St1[151] ^ D1[31];
assign Bx1[29] = St1[144] ^ D1[24];
assign Bx1[30] = St1[145] ^ D1[25];
assign Bx1[31] = St1[146] ^ D1[26];
assign Bx1[152] = St1[184] ^ D1[24];
assign Bx1[153] = St1[185] ^ D1[25];
assign Bx1[154] = St1[186] ^ D1[26];
assign Bx1[155] = St1[187] ^ D1[27];
assign Bx1[156] = St1[188] ^ D1[28];
assign Bx1[157] = St1[189] ^ D1[29];
assign Bx1[158] = St1[190] ^ D1[30];
assign Bx1[159] = St1[191] ^ D1[31];
assign Bx1[120] = St1[37] ^ D1[37];
assign Bx1[121] = St1[38] ^ D1[38];
assign Bx1[122] = St1[39] ^ D1[39];
assign Bx1[123] = St1[32] ^ D1[32];
assign Bx1[124] = St1[33] ^ D1[33];
assign Bx1[125] = St1[34] ^ D1[34];
assign Bx1[126] = St1[35] ^ D1[35];
assign Bx1[127] = St1[36] ^ D1[36];
assign Bx1[48] = St1[76] ^ D1[36];
assign Bx1[49] = St1[77] ^ D1[37];
assign Bx1[50] = St1[78] ^ D1[38];
assign Bx1[51] = St1[79] ^ D1[39];
assign Bx1[52] = St1[72] ^ D1[32];
assign Bx1[53] = St1[73] ^ D1[33];
assign Bx1[54] = St1[74] ^ D1[34];
assign Bx1[55] = St1[75] ^ D1[35];
assign Bx1[176] = St1[113] ^ D1[33];
assign Bx1[177] = St1[114] ^ D1[34];
assign Bx1[178] = St1[115] ^ D1[35];
assign Bx1[179] = St1[116] ^ D1[36];
assign Bx1[180] = St1[117] ^ D1[37];
assign Bx1[181] = St1[118] ^ D1[38];
assign Bx1[182] = St1[119] ^ D1[39];
assign Bx1[183] = St1[112] ^ D1[32];
assign Bx1[104] = St1[152] ^ D1[32];
assign Bx1[105] = St1[153] ^ D1[33];
assign Bx1[106] = St1[154] ^ D1[34];
assign Bx1[107] = St1[155] ^ D1[35];
assign Bx1[108] = St1[156] ^ D1[36];
assign Bx1[109] = St1[157] ^ D1[37];
assign Bx1[110] = St1[158] ^ D1[38];
assign Bx1[111] = St1[159] ^ D1[39];
assign Bx1[32] = St1[194] ^ D1[34];
assign Bx1[33] = St1[195] ^ D1[35];
assign Bx1[34] = St1[196] ^ D1[36];
assign Bx1[35] = St1[197] ^ D1[37];
assign Bx1[36] = St1[198] ^ D1[38];
assign Bx1[37] = St1[199] ^ D1[39];
assign Bx1[38] = St1[192] ^ D1[32];
assign Bx1[39] = St1[193] ^ D1[33];

// ---- chi: w_chi[x,y,z] = (~Bx[x+1,y,z]) AND Bx[x+2,y,z] ----
// NOT is share-local (complement share 0 only); nb_d* are the 1-cycle
// per-share balance registers feeding every gadget ina (contract ina@1).
wire [199:0] nb_src0, nb_src1;
wire [199:0] nb0 = ~nb_src0;   // share-local complement, share 0 only
wire [199:0] nb1 =  nb_src1;
reg  [199:0] nb_d0, nb_d1;
always @(posedge clk) begin
    nb_d0 <= nb0;
    nb_d1 <= nb1;
end
assign nb_src0[0] = Bx0[8];  assign nb_src1[0] = Bx1[8];
assign nb_src0[1] = Bx0[9];  assign nb_src1[1] = Bx1[9];
assign nb_src0[2] = Bx0[10];  assign nb_src1[2] = Bx1[10];
assign nb_src0[3] = Bx0[11];  assign nb_src1[3] = Bx1[11];
assign nb_src0[4] = Bx0[12];  assign nb_src1[4] = Bx1[12];
assign nb_src0[5] = Bx0[13];  assign nb_src1[5] = Bx1[13];
assign nb_src0[6] = Bx0[14];  assign nb_src1[6] = Bx1[14];
assign nb_src0[7] = Bx0[15];  assign nb_src1[7] = Bx1[15];
assign nb_src0[40] = Bx0[48];  assign nb_src1[40] = Bx1[48];
assign nb_src0[41] = Bx0[49];  assign nb_src1[41] = Bx1[49];
assign nb_src0[42] = Bx0[50];  assign nb_src1[42] = Bx1[50];
assign nb_src0[43] = Bx0[51];  assign nb_src1[43] = Bx1[51];
assign nb_src0[44] = Bx0[52];  assign nb_src1[44] = Bx1[52];
assign nb_src0[45] = Bx0[53];  assign nb_src1[45] = Bx1[53];
assign nb_src0[46] = Bx0[54];  assign nb_src1[46] = Bx1[54];
assign nb_src0[47] = Bx0[55];  assign nb_src1[47] = Bx1[55];
assign nb_src0[80] = Bx0[88];  assign nb_src1[80] = Bx1[88];
assign nb_src0[81] = Bx0[89];  assign nb_src1[81] = Bx1[89];
assign nb_src0[82] = Bx0[90];  assign nb_src1[82] = Bx1[90];
assign nb_src0[83] = Bx0[91];  assign nb_src1[83] = Bx1[91];
assign nb_src0[84] = Bx0[92];  assign nb_src1[84] = Bx1[92];
assign nb_src0[85] = Bx0[93];  assign nb_src1[85] = Bx1[93];
assign nb_src0[86] = Bx0[94];  assign nb_src1[86] = Bx1[94];
assign nb_src0[87] = Bx0[95];  assign nb_src1[87] = Bx1[95];
assign nb_src0[120] = Bx0[128];  assign nb_src1[120] = Bx1[128];
assign nb_src0[121] = Bx0[129];  assign nb_src1[121] = Bx1[129];
assign nb_src0[122] = Bx0[130];  assign nb_src1[122] = Bx1[130];
assign nb_src0[123] = Bx0[131];  assign nb_src1[123] = Bx1[131];
assign nb_src0[124] = Bx0[132];  assign nb_src1[124] = Bx1[132];
assign nb_src0[125] = Bx0[133];  assign nb_src1[125] = Bx1[133];
assign nb_src0[126] = Bx0[134];  assign nb_src1[126] = Bx1[134];
assign nb_src0[127] = Bx0[135];  assign nb_src1[127] = Bx1[135];
assign nb_src0[160] = Bx0[168];  assign nb_src1[160] = Bx1[168];
assign nb_src0[161] = Bx0[169];  assign nb_src1[161] = Bx1[169];
assign nb_src0[162] = Bx0[170];  assign nb_src1[162] = Bx1[170];
assign nb_src0[163] = Bx0[171];  assign nb_src1[163] = Bx1[171];
assign nb_src0[164] = Bx0[172];  assign nb_src1[164] = Bx1[172];
assign nb_src0[165] = Bx0[173];  assign nb_src1[165] = Bx1[173];
assign nb_src0[166] = Bx0[174];  assign nb_src1[166] = Bx1[174];
assign nb_src0[167] = Bx0[175];  assign nb_src1[167] = Bx1[175];
assign nb_src0[8] = Bx0[16];  assign nb_src1[8] = Bx1[16];
assign nb_src0[9] = Bx0[17];  assign nb_src1[9] = Bx1[17];
assign nb_src0[10] = Bx0[18];  assign nb_src1[10] = Bx1[18];
assign nb_src0[11] = Bx0[19];  assign nb_src1[11] = Bx1[19];
assign nb_src0[12] = Bx0[20];  assign nb_src1[12] = Bx1[20];
assign nb_src0[13] = Bx0[21];  assign nb_src1[13] = Bx1[21];
assign nb_src0[14] = Bx0[22];  assign nb_src1[14] = Bx1[22];
assign nb_src0[15] = Bx0[23];  assign nb_src1[15] = Bx1[23];
assign nb_src0[48] = Bx0[56];  assign nb_src1[48] = Bx1[56];
assign nb_src0[49] = Bx0[57];  assign nb_src1[49] = Bx1[57];
assign nb_src0[50] = Bx0[58];  assign nb_src1[50] = Bx1[58];
assign nb_src0[51] = Bx0[59];  assign nb_src1[51] = Bx1[59];
assign nb_src0[52] = Bx0[60];  assign nb_src1[52] = Bx1[60];
assign nb_src0[53] = Bx0[61];  assign nb_src1[53] = Bx1[61];
assign nb_src0[54] = Bx0[62];  assign nb_src1[54] = Bx1[62];
assign nb_src0[55] = Bx0[63];  assign nb_src1[55] = Bx1[63];
assign nb_src0[88] = Bx0[96];  assign nb_src1[88] = Bx1[96];
assign nb_src0[89] = Bx0[97];  assign nb_src1[89] = Bx1[97];
assign nb_src0[90] = Bx0[98];  assign nb_src1[90] = Bx1[98];
assign nb_src0[91] = Bx0[99];  assign nb_src1[91] = Bx1[99];
assign nb_src0[92] = Bx0[100];  assign nb_src1[92] = Bx1[100];
assign nb_src0[93] = Bx0[101];  assign nb_src1[93] = Bx1[101];
assign nb_src0[94] = Bx0[102];  assign nb_src1[94] = Bx1[102];
assign nb_src0[95] = Bx0[103];  assign nb_src1[95] = Bx1[103];
assign nb_src0[128] = Bx0[136];  assign nb_src1[128] = Bx1[136];
assign nb_src0[129] = Bx0[137];  assign nb_src1[129] = Bx1[137];
assign nb_src0[130] = Bx0[138];  assign nb_src1[130] = Bx1[138];
assign nb_src0[131] = Bx0[139];  assign nb_src1[131] = Bx1[139];
assign nb_src0[132] = Bx0[140];  assign nb_src1[132] = Bx1[140];
assign nb_src0[133] = Bx0[141];  assign nb_src1[133] = Bx1[141];
assign nb_src0[134] = Bx0[142];  assign nb_src1[134] = Bx1[142];
assign nb_src0[135] = Bx0[143];  assign nb_src1[135] = Bx1[143];
assign nb_src0[168] = Bx0[176];  assign nb_src1[168] = Bx1[176];
assign nb_src0[169] = Bx0[177];  assign nb_src1[169] = Bx1[177];
assign nb_src0[170] = Bx0[178];  assign nb_src1[170] = Bx1[178];
assign nb_src0[171] = Bx0[179];  assign nb_src1[171] = Bx1[179];
assign nb_src0[172] = Bx0[180];  assign nb_src1[172] = Bx1[180];
assign nb_src0[173] = Bx0[181];  assign nb_src1[173] = Bx1[181];
assign nb_src0[174] = Bx0[182];  assign nb_src1[174] = Bx1[182];
assign nb_src0[175] = Bx0[183];  assign nb_src1[175] = Bx1[183];
assign nb_src0[16] = Bx0[24];  assign nb_src1[16] = Bx1[24];
assign nb_src0[17] = Bx0[25];  assign nb_src1[17] = Bx1[25];
assign nb_src0[18] = Bx0[26];  assign nb_src1[18] = Bx1[26];
assign nb_src0[19] = Bx0[27];  assign nb_src1[19] = Bx1[27];
assign nb_src0[20] = Bx0[28];  assign nb_src1[20] = Bx1[28];
assign nb_src0[21] = Bx0[29];  assign nb_src1[21] = Bx1[29];
assign nb_src0[22] = Bx0[30];  assign nb_src1[22] = Bx1[30];
assign nb_src0[23] = Bx0[31];  assign nb_src1[23] = Bx1[31];
assign nb_src0[56] = Bx0[64];  assign nb_src1[56] = Bx1[64];
assign nb_src0[57] = Bx0[65];  assign nb_src1[57] = Bx1[65];
assign nb_src0[58] = Bx0[66];  assign nb_src1[58] = Bx1[66];
assign nb_src0[59] = Bx0[67];  assign nb_src1[59] = Bx1[67];
assign nb_src0[60] = Bx0[68];  assign nb_src1[60] = Bx1[68];
assign nb_src0[61] = Bx0[69];  assign nb_src1[61] = Bx1[69];
assign nb_src0[62] = Bx0[70];  assign nb_src1[62] = Bx1[70];
assign nb_src0[63] = Bx0[71];  assign nb_src1[63] = Bx1[71];
assign nb_src0[96] = Bx0[104];  assign nb_src1[96] = Bx1[104];
assign nb_src0[97] = Bx0[105];  assign nb_src1[97] = Bx1[105];
assign nb_src0[98] = Bx0[106];  assign nb_src1[98] = Bx1[106];
assign nb_src0[99] = Bx0[107];  assign nb_src1[99] = Bx1[107];
assign nb_src0[100] = Bx0[108];  assign nb_src1[100] = Bx1[108];
assign nb_src0[101] = Bx0[109];  assign nb_src1[101] = Bx1[109];
assign nb_src0[102] = Bx0[110];  assign nb_src1[102] = Bx1[110];
assign nb_src0[103] = Bx0[111];  assign nb_src1[103] = Bx1[111];
assign nb_src0[136] = Bx0[144];  assign nb_src1[136] = Bx1[144];
assign nb_src0[137] = Bx0[145];  assign nb_src1[137] = Bx1[145];
assign nb_src0[138] = Bx0[146];  assign nb_src1[138] = Bx1[146];
assign nb_src0[139] = Bx0[147];  assign nb_src1[139] = Bx1[147];
assign nb_src0[140] = Bx0[148];  assign nb_src1[140] = Bx1[148];
assign nb_src0[141] = Bx0[149];  assign nb_src1[141] = Bx1[149];
assign nb_src0[142] = Bx0[150];  assign nb_src1[142] = Bx1[150];
assign nb_src0[143] = Bx0[151];  assign nb_src1[143] = Bx1[151];
assign nb_src0[176] = Bx0[184];  assign nb_src1[176] = Bx1[184];
assign nb_src0[177] = Bx0[185];  assign nb_src1[177] = Bx1[185];
assign nb_src0[178] = Bx0[186];  assign nb_src1[178] = Bx1[186];
assign nb_src0[179] = Bx0[187];  assign nb_src1[179] = Bx1[187];
assign nb_src0[180] = Bx0[188];  assign nb_src1[180] = Bx1[188];
assign nb_src0[181] = Bx0[189];  assign nb_src1[181] = Bx1[189];
assign nb_src0[182] = Bx0[190];  assign nb_src1[182] = Bx1[190];
assign nb_src0[183] = Bx0[191];  assign nb_src1[183] = Bx1[191];
assign nb_src0[24] = Bx0[32];  assign nb_src1[24] = Bx1[32];
assign nb_src0[25] = Bx0[33];  assign nb_src1[25] = Bx1[33];
assign nb_src0[26] = Bx0[34];  assign nb_src1[26] = Bx1[34];
assign nb_src0[27] = Bx0[35];  assign nb_src1[27] = Bx1[35];
assign nb_src0[28] = Bx0[36];  assign nb_src1[28] = Bx1[36];
assign nb_src0[29] = Bx0[37];  assign nb_src1[29] = Bx1[37];
assign nb_src0[30] = Bx0[38];  assign nb_src1[30] = Bx1[38];
assign nb_src0[31] = Bx0[39];  assign nb_src1[31] = Bx1[39];
assign nb_src0[64] = Bx0[72];  assign nb_src1[64] = Bx1[72];
assign nb_src0[65] = Bx0[73];  assign nb_src1[65] = Bx1[73];
assign nb_src0[66] = Bx0[74];  assign nb_src1[66] = Bx1[74];
assign nb_src0[67] = Bx0[75];  assign nb_src1[67] = Bx1[75];
assign nb_src0[68] = Bx0[76];  assign nb_src1[68] = Bx1[76];
assign nb_src0[69] = Bx0[77];  assign nb_src1[69] = Bx1[77];
assign nb_src0[70] = Bx0[78];  assign nb_src1[70] = Bx1[78];
assign nb_src0[71] = Bx0[79];  assign nb_src1[71] = Bx1[79];
assign nb_src0[104] = Bx0[112];  assign nb_src1[104] = Bx1[112];
assign nb_src0[105] = Bx0[113];  assign nb_src1[105] = Bx1[113];
assign nb_src0[106] = Bx0[114];  assign nb_src1[106] = Bx1[114];
assign nb_src0[107] = Bx0[115];  assign nb_src1[107] = Bx1[115];
assign nb_src0[108] = Bx0[116];  assign nb_src1[108] = Bx1[116];
assign nb_src0[109] = Bx0[117];  assign nb_src1[109] = Bx1[117];
assign nb_src0[110] = Bx0[118];  assign nb_src1[110] = Bx1[118];
assign nb_src0[111] = Bx0[119];  assign nb_src1[111] = Bx1[119];
assign nb_src0[144] = Bx0[152];  assign nb_src1[144] = Bx1[152];
assign nb_src0[145] = Bx0[153];  assign nb_src1[145] = Bx1[153];
assign nb_src0[146] = Bx0[154];  assign nb_src1[146] = Bx1[154];
assign nb_src0[147] = Bx0[155];  assign nb_src1[147] = Bx1[155];
assign nb_src0[148] = Bx0[156];  assign nb_src1[148] = Bx1[156];
assign nb_src0[149] = Bx0[157];  assign nb_src1[149] = Bx1[157];
assign nb_src0[150] = Bx0[158];  assign nb_src1[150] = Bx1[158];
assign nb_src0[151] = Bx0[159];  assign nb_src1[151] = Bx1[159];
assign nb_src0[184] = Bx0[192];  assign nb_src1[184] = Bx1[192];
assign nb_src0[185] = Bx0[193];  assign nb_src1[185] = Bx1[193];
assign nb_src0[186] = Bx0[194];  assign nb_src1[186] = Bx1[194];
assign nb_src0[187] = Bx0[195];  assign nb_src1[187] = Bx1[195];
assign nb_src0[188] = Bx0[196];  assign nb_src1[188] = Bx1[196];
assign nb_src0[189] = Bx0[197];  assign nb_src1[189] = Bx1[197];
assign nb_src0[190] = Bx0[198];  assign nb_src1[190] = Bx1[198];
assign nb_src0[191] = Bx0[199];  assign nb_src1[191] = Bx1[199];
assign nb_src0[32] = Bx0[0];  assign nb_src1[32] = Bx1[0];
assign nb_src0[33] = Bx0[1];  assign nb_src1[33] = Bx1[1];
assign nb_src0[34] = Bx0[2];  assign nb_src1[34] = Bx1[2];
assign nb_src0[35] = Bx0[3];  assign nb_src1[35] = Bx1[3];
assign nb_src0[36] = Bx0[4];  assign nb_src1[36] = Bx1[4];
assign nb_src0[37] = Bx0[5];  assign nb_src1[37] = Bx1[5];
assign nb_src0[38] = Bx0[6];  assign nb_src1[38] = Bx1[6];
assign nb_src0[39] = Bx0[7];  assign nb_src1[39] = Bx1[7];
assign nb_src0[72] = Bx0[40];  assign nb_src1[72] = Bx1[40];
assign nb_src0[73] = Bx0[41];  assign nb_src1[73] = Bx1[41];
assign nb_src0[74] = Bx0[42];  assign nb_src1[74] = Bx1[42];
assign nb_src0[75] = Bx0[43];  assign nb_src1[75] = Bx1[43];
assign nb_src0[76] = Bx0[44];  assign nb_src1[76] = Bx1[44];
assign nb_src0[77] = Bx0[45];  assign nb_src1[77] = Bx1[45];
assign nb_src0[78] = Bx0[46];  assign nb_src1[78] = Bx1[46];
assign nb_src0[79] = Bx0[47];  assign nb_src1[79] = Bx1[47];
assign nb_src0[112] = Bx0[80];  assign nb_src1[112] = Bx1[80];
assign nb_src0[113] = Bx0[81];  assign nb_src1[113] = Bx1[81];
assign nb_src0[114] = Bx0[82];  assign nb_src1[114] = Bx1[82];
assign nb_src0[115] = Bx0[83];  assign nb_src1[115] = Bx1[83];
assign nb_src0[116] = Bx0[84];  assign nb_src1[116] = Bx1[84];
assign nb_src0[117] = Bx0[85];  assign nb_src1[117] = Bx1[85];
assign nb_src0[118] = Bx0[86];  assign nb_src1[118] = Bx1[86];
assign nb_src0[119] = Bx0[87];  assign nb_src1[119] = Bx1[87];
assign nb_src0[152] = Bx0[120];  assign nb_src1[152] = Bx1[120];
assign nb_src0[153] = Bx0[121];  assign nb_src1[153] = Bx1[121];
assign nb_src0[154] = Bx0[122];  assign nb_src1[154] = Bx1[122];
assign nb_src0[155] = Bx0[123];  assign nb_src1[155] = Bx1[123];
assign nb_src0[156] = Bx0[124];  assign nb_src1[156] = Bx1[124];
assign nb_src0[157] = Bx0[125];  assign nb_src1[157] = Bx1[125];
assign nb_src0[158] = Bx0[126];  assign nb_src1[158] = Bx1[126];
assign nb_src0[159] = Bx0[127];  assign nb_src1[159] = Bx1[127];
assign nb_src0[192] = Bx0[160];  assign nb_src1[192] = Bx1[160];
assign nb_src0[193] = Bx0[161];  assign nb_src1[193] = Bx1[161];
assign nb_src0[194] = Bx0[162];  assign nb_src1[194] = Bx1[162];
assign nb_src0[195] = Bx0[163];  assign nb_src1[195] = Bx1[163];
assign nb_src0[196] = Bx0[164];  assign nb_src1[196] = Bx1[164];
assign nb_src0[197] = Bx0[165];  assign nb_src1[197] = Bx1[165];
assign nb_src0[198] = Bx0[166];  assign nb_src1[198] = Bx1[166];
assign nb_src0[199] = Bx0[167];  assign nb_src1[199] = Bx1[167];

MSKand_opini2_d2_pini u_chi_0 (
    .ina({nb_d1[0], nb_d0[0]}), .inb({Bx1[16], Bx0[16]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({w_chi1[0], w_chi0[0]}));
MSKand_opini2_d2_pini u_chi_1 (
    .ina({nb_d1[1], nb_d0[1]}), .inb({Bx1[17], Bx0[17]}),
    .rnd(r[1]), .s(s[1]), .clk(clk), .out({w_chi1[1], w_chi0[1]}));
MSKand_opini2_d2_pini u_chi_2 (
    .ina({nb_d1[2], nb_d0[2]}), .inb({Bx1[18], Bx0[18]}),
    .rnd(r[2]), .s(s[2]), .clk(clk), .out({w_chi1[2], w_chi0[2]}));
MSKand_opini2_d2_pini u_chi_3 (
    .ina({nb_d1[3], nb_d0[3]}), .inb({Bx1[19], Bx0[19]}),
    .rnd(r[3]), .s(s[3]), .clk(clk), .out({w_chi1[3], w_chi0[3]}));
MSKand_opini2_d2_pini u_chi_4 (
    .ina({nb_d1[4], nb_d0[4]}), .inb({Bx1[20], Bx0[20]}),
    .rnd(r[4]), .s(s[4]), .clk(clk), .out({w_chi1[4], w_chi0[4]}));
MSKand_opini2_d2_pini u_chi_5 (
    .ina({nb_d1[5], nb_d0[5]}), .inb({Bx1[21], Bx0[21]}),
    .rnd(r[5]), .s(s[5]), .clk(clk), .out({w_chi1[5], w_chi0[5]}));
MSKand_opini2_d2_pini u_chi_6 (
    .ina({nb_d1[6], nb_d0[6]}), .inb({Bx1[22], Bx0[22]}),
    .rnd(r[6]), .s(s[6]), .clk(clk), .out({w_chi1[6], w_chi0[6]}));
MSKand_opini2_d2_pini u_chi_7 (
    .ina({nb_d1[7], nb_d0[7]}), .inb({Bx1[23], Bx0[23]}),
    .rnd(r[7]), .s(s[7]), .clk(clk), .out({w_chi1[7], w_chi0[7]}));
MSKand_opini2_d2_pini u_chi_40 (
    .ina({nb_d1[40], nb_d0[40]}), .inb({Bx1[56], Bx0[56]}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({w_chi1[40], w_chi0[40]}));
MSKand_opini2_d2_pini u_chi_41 (
    .ina({nb_d1[41], nb_d0[41]}), .inb({Bx1[57], Bx0[57]}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({w_chi1[41], w_chi0[41]}));
MSKand_opini2_d2_pini u_chi_42 (
    .ina({nb_d1[42], nb_d0[42]}), .inb({Bx1[58], Bx0[58]}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({w_chi1[42], w_chi0[42]}));
MSKand_opini2_d2_pini u_chi_43 (
    .ina({nb_d1[43], nb_d0[43]}), .inb({Bx1[59], Bx0[59]}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({w_chi1[43], w_chi0[43]}));
MSKand_opini2_d2_pini u_chi_44 (
    .ina({nb_d1[44], nb_d0[44]}), .inb({Bx1[60], Bx0[60]}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({w_chi1[44], w_chi0[44]}));
MSKand_opini2_d2_pini u_chi_45 (
    .ina({nb_d1[45], nb_d0[45]}), .inb({Bx1[61], Bx0[61]}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({w_chi1[45], w_chi0[45]}));
MSKand_opini2_d2_pini u_chi_46 (
    .ina({nb_d1[46], nb_d0[46]}), .inb({Bx1[62], Bx0[62]}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({w_chi1[46], w_chi0[46]}));
MSKand_opini2_d2_pini u_chi_47 (
    .ina({nb_d1[47], nb_d0[47]}), .inb({Bx1[63], Bx0[63]}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({w_chi1[47], w_chi0[47]}));
MSKand_opini2_d2_pini u_chi_80 (
    .ina({nb_d1[80], nb_d0[80]}), .inb({Bx1[96], Bx0[96]}),
    .rnd(r[80]), .s(s[80]), .clk(clk), .out({w_chi1[80], w_chi0[80]}));
MSKand_opini2_d2_pini u_chi_81 (
    .ina({nb_d1[81], nb_d0[81]}), .inb({Bx1[97], Bx0[97]}),
    .rnd(r[81]), .s(s[81]), .clk(clk), .out({w_chi1[81], w_chi0[81]}));
MSKand_opini2_d2_pini u_chi_82 (
    .ina({nb_d1[82], nb_d0[82]}), .inb({Bx1[98], Bx0[98]}),
    .rnd(r[82]), .s(s[82]), .clk(clk), .out({w_chi1[82], w_chi0[82]}));
MSKand_opini2_d2_pini u_chi_83 (
    .ina({nb_d1[83], nb_d0[83]}), .inb({Bx1[99], Bx0[99]}),
    .rnd(r[83]), .s(s[83]), .clk(clk), .out({w_chi1[83], w_chi0[83]}));
MSKand_opini2_d2_pini u_chi_84 (
    .ina({nb_d1[84], nb_d0[84]}), .inb({Bx1[100], Bx0[100]}),
    .rnd(r[84]), .s(s[84]), .clk(clk), .out({w_chi1[84], w_chi0[84]}));
MSKand_opini2_d2_pini u_chi_85 (
    .ina({nb_d1[85], nb_d0[85]}), .inb({Bx1[101], Bx0[101]}),
    .rnd(r[85]), .s(s[85]), .clk(clk), .out({w_chi1[85], w_chi0[85]}));
MSKand_opini2_d2_pini u_chi_86 (
    .ina({nb_d1[86], nb_d0[86]}), .inb({Bx1[102], Bx0[102]}),
    .rnd(r[86]), .s(s[86]), .clk(clk), .out({w_chi1[86], w_chi0[86]}));
MSKand_opini2_d2_pini u_chi_87 (
    .ina({nb_d1[87], nb_d0[87]}), .inb({Bx1[103], Bx0[103]}),
    .rnd(r[87]), .s(s[87]), .clk(clk), .out({w_chi1[87], w_chi0[87]}));
MSKand_opini2_d2_pini u_chi_120 (
    .ina({nb_d1[120], nb_d0[120]}), .inb({Bx1[136], Bx0[136]}),
    .rnd(r[120]), .s(s[120]), .clk(clk), .out({w_chi1[120], w_chi0[120]}));
MSKand_opini2_d2_pini u_chi_121 (
    .ina({nb_d1[121], nb_d0[121]}), .inb({Bx1[137], Bx0[137]}),
    .rnd(r[121]), .s(s[121]), .clk(clk), .out({w_chi1[121], w_chi0[121]}));
MSKand_opini2_d2_pini u_chi_122 (
    .ina({nb_d1[122], nb_d0[122]}), .inb({Bx1[138], Bx0[138]}),
    .rnd(r[122]), .s(s[122]), .clk(clk), .out({w_chi1[122], w_chi0[122]}));
MSKand_opini2_d2_pini u_chi_123 (
    .ina({nb_d1[123], nb_d0[123]}), .inb({Bx1[139], Bx0[139]}),
    .rnd(r[123]), .s(s[123]), .clk(clk), .out({w_chi1[123], w_chi0[123]}));
MSKand_opini2_d2_pini u_chi_124 (
    .ina({nb_d1[124], nb_d0[124]}), .inb({Bx1[140], Bx0[140]}),
    .rnd(r[124]), .s(s[124]), .clk(clk), .out({w_chi1[124], w_chi0[124]}));
MSKand_opini2_d2_pini u_chi_125 (
    .ina({nb_d1[125], nb_d0[125]}), .inb({Bx1[141], Bx0[141]}),
    .rnd(r[125]), .s(s[125]), .clk(clk), .out({w_chi1[125], w_chi0[125]}));
MSKand_opini2_d2_pini u_chi_126 (
    .ina({nb_d1[126], nb_d0[126]}), .inb({Bx1[142], Bx0[142]}),
    .rnd(r[126]), .s(s[126]), .clk(clk), .out({w_chi1[126], w_chi0[126]}));
MSKand_opini2_d2_pini u_chi_127 (
    .ina({nb_d1[127], nb_d0[127]}), .inb({Bx1[143], Bx0[143]}),
    .rnd(r[127]), .s(s[127]), .clk(clk), .out({w_chi1[127], w_chi0[127]}));
MSKand_opini2_d2_pini u_chi_160 (
    .ina({nb_d1[160], nb_d0[160]}), .inb({Bx1[176], Bx0[176]}),
    .rnd(r[160]), .s(s[160]), .clk(clk), .out({w_chi1[160], w_chi0[160]}));
MSKand_opini2_d2_pini u_chi_161 (
    .ina({nb_d1[161], nb_d0[161]}), .inb({Bx1[177], Bx0[177]}),
    .rnd(r[161]), .s(s[161]), .clk(clk), .out({w_chi1[161], w_chi0[161]}));
MSKand_opini2_d2_pini u_chi_162 (
    .ina({nb_d1[162], nb_d0[162]}), .inb({Bx1[178], Bx0[178]}),
    .rnd(r[162]), .s(s[162]), .clk(clk), .out({w_chi1[162], w_chi0[162]}));
MSKand_opini2_d2_pini u_chi_163 (
    .ina({nb_d1[163], nb_d0[163]}), .inb({Bx1[179], Bx0[179]}),
    .rnd(r[163]), .s(s[163]), .clk(clk), .out({w_chi1[163], w_chi0[163]}));
MSKand_opini2_d2_pini u_chi_164 (
    .ina({nb_d1[164], nb_d0[164]}), .inb({Bx1[180], Bx0[180]}),
    .rnd(r[164]), .s(s[164]), .clk(clk), .out({w_chi1[164], w_chi0[164]}));
MSKand_opini2_d2_pini u_chi_165 (
    .ina({nb_d1[165], nb_d0[165]}), .inb({Bx1[181], Bx0[181]}),
    .rnd(r[165]), .s(s[165]), .clk(clk), .out({w_chi1[165], w_chi0[165]}));
MSKand_opini2_d2_pini u_chi_166 (
    .ina({nb_d1[166], nb_d0[166]}), .inb({Bx1[182], Bx0[182]}),
    .rnd(r[166]), .s(s[166]), .clk(clk), .out({w_chi1[166], w_chi0[166]}));
MSKand_opini2_d2_pini u_chi_167 (
    .ina({nb_d1[167], nb_d0[167]}), .inb({Bx1[183], Bx0[183]}),
    .rnd(r[167]), .s(s[167]), .clk(clk), .out({w_chi1[167], w_chi0[167]}));
MSKand_opini2_d2_pini u_chi_8 (
    .ina({nb_d1[8], nb_d0[8]}), .inb({Bx1[24], Bx0[24]}),
    .rnd(r[8]), .s(s[8]), .clk(clk), .out({w_chi1[8], w_chi0[8]}));
MSKand_opini2_d2_pini u_chi_9 (
    .ina({nb_d1[9], nb_d0[9]}), .inb({Bx1[25], Bx0[25]}),
    .rnd(r[9]), .s(s[9]), .clk(clk), .out({w_chi1[9], w_chi0[9]}));
MSKand_opini2_d2_pini u_chi_10 (
    .ina({nb_d1[10], nb_d0[10]}), .inb({Bx1[26], Bx0[26]}),
    .rnd(r[10]), .s(s[10]), .clk(clk), .out({w_chi1[10], w_chi0[10]}));
MSKand_opini2_d2_pini u_chi_11 (
    .ina({nb_d1[11], nb_d0[11]}), .inb({Bx1[27], Bx0[27]}),
    .rnd(r[11]), .s(s[11]), .clk(clk), .out({w_chi1[11], w_chi0[11]}));
MSKand_opini2_d2_pini u_chi_12 (
    .ina({nb_d1[12], nb_d0[12]}), .inb({Bx1[28], Bx0[28]}),
    .rnd(r[12]), .s(s[12]), .clk(clk), .out({w_chi1[12], w_chi0[12]}));
MSKand_opini2_d2_pini u_chi_13 (
    .ina({nb_d1[13], nb_d0[13]}), .inb({Bx1[29], Bx0[29]}),
    .rnd(r[13]), .s(s[13]), .clk(clk), .out({w_chi1[13], w_chi0[13]}));
MSKand_opini2_d2_pini u_chi_14 (
    .ina({nb_d1[14], nb_d0[14]}), .inb({Bx1[30], Bx0[30]}),
    .rnd(r[14]), .s(s[14]), .clk(clk), .out({w_chi1[14], w_chi0[14]}));
MSKand_opini2_d2_pini u_chi_15 (
    .ina({nb_d1[15], nb_d0[15]}), .inb({Bx1[31], Bx0[31]}),
    .rnd(r[15]), .s(s[15]), .clk(clk), .out({w_chi1[15], w_chi0[15]}));
MSKand_opini2_d2_pini u_chi_48 (
    .ina({nb_d1[48], nb_d0[48]}), .inb({Bx1[64], Bx0[64]}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({w_chi1[48], w_chi0[48]}));
MSKand_opini2_d2_pini u_chi_49 (
    .ina({nb_d1[49], nb_d0[49]}), .inb({Bx1[65], Bx0[65]}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({w_chi1[49], w_chi0[49]}));
MSKand_opini2_d2_pini u_chi_50 (
    .ina({nb_d1[50], nb_d0[50]}), .inb({Bx1[66], Bx0[66]}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({w_chi1[50], w_chi0[50]}));
MSKand_opini2_d2_pini u_chi_51 (
    .ina({nb_d1[51], nb_d0[51]}), .inb({Bx1[67], Bx0[67]}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({w_chi1[51], w_chi0[51]}));
MSKand_opini2_d2_pini u_chi_52 (
    .ina({nb_d1[52], nb_d0[52]}), .inb({Bx1[68], Bx0[68]}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({w_chi1[52], w_chi0[52]}));
MSKand_opini2_d2_pini u_chi_53 (
    .ina({nb_d1[53], nb_d0[53]}), .inb({Bx1[69], Bx0[69]}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({w_chi1[53], w_chi0[53]}));
MSKand_opini2_d2_pini u_chi_54 (
    .ina({nb_d1[54], nb_d0[54]}), .inb({Bx1[70], Bx0[70]}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({w_chi1[54], w_chi0[54]}));
MSKand_opini2_d2_pini u_chi_55 (
    .ina({nb_d1[55], nb_d0[55]}), .inb({Bx1[71], Bx0[71]}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({w_chi1[55], w_chi0[55]}));
MSKand_opini2_d2_pini u_chi_88 (
    .ina({nb_d1[88], nb_d0[88]}), .inb({Bx1[104], Bx0[104]}),
    .rnd(r[88]), .s(s[88]), .clk(clk), .out({w_chi1[88], w_chi0[88]}));
MSKand_opini2_d2_pini u_chi_89 (
    .ina({nb_d1[89], nb_d0[89]}), .inb({Bx1[105], Bx0[105]}),
    .rnd(r[89]), .s(s[89]), .clk(clk), .out({w_chi1[89], w_chi0[89]}));
MSKand_opini2_d2_pini u_chi_90 (
    .ina({nb_d1[90], nb_d0[90]}), .inb({Bx1[106], Bx0[106]}),
    .rnd(r[90]), .s(s[90]), .clk(clk), .out({w_chi1[90], w_chi0[90]}));
MSKand_opini2_d2_pini u_chi_91 (
    .ina({nb_d1[91], nb_d0[91]}), .inb({Bx1[107], Bx0[107]}),
    .rnd(r[91]), .s(s[91]), .clk(clk), .out({w_chi1[91], w_chi0[91]}));
MSKand_opini2_d2_pini u_chi_92 (
    .ina({nb_d1[92], nb_d0[92]}), .inb({Bx1[108], Bx0[108]}),
    .rnd(r[92]), .s(s[92]), .clk(clk), .out({w_chi1[92], w_chi0[92]}));
MSKand_opini2_d2_pini u_chi_93 (
    .ina({nb_d1[93], nb_d0[93]}), .inb({Bx1[109], Bx0[109]}),
    .rnd(r[93]), .s(s[93]), .clk(clk), .out({w_chi1[93], w_chi0[93]}));
MSKand_opini2_d2_pini u_chi_94 (
    .ina({nb_d1[94], nb_d0[94]}), .inb({Bx1[110], Bx0[110]}),
    .rnd(r[94]), .s(s[94]), .clk(clk), .out({w_chi1[94], w_chi0[94]}));
MSKand_opini2_d2_pini u_chi_95 (
    .ina({nb_d1[95], nb_d0[95]}), .inb({Bx1[111], Bx0[111]}),
    .rnd(r[95]), .s(s[95]), .clk(clk), .out({w_chi1[95], w_chi0[95]}));
MSKand_opini2_d2_pini u_chi_128 (
    .ina({nb_d1[128], nb_d0[128]}), .inb({Bx1[144], Bx0[144]}),
    .rnd(r[128]), .s(s[128]), .clk(clk), .out({w_chi1[128], w_chi0[128]}));
MSKand_opini2_d2_pini u_chi_129 (
    .ina({nb_d1[129], nb_d0[129]}), .inb({Bx1[145], Bx0[145]}),
    .rnd(r[129]), .s(s[129]), .clk(clk), .out({w_chi1[129], w_chi0[129]}));
MSKand_opini2_d2_pini u_chi_130 (
    .ina({nb_d1[130], nb_d0[130]}), .inb({Bx1[146], Bx0[146]}),
    .rnd(r[130]), .s(s[130]), .clk(clk), .out({w_chi1[130], w_chi0[130]}));
MSKand_opini2_d2_pini u_chi_131 (
    .ina({nb_d1[131], nb_d0[131]}), .inb({Bx1[147], Bx0[147]}),
    .rnd(r[131]), .s(s[131]), .clk(clk), .out({w_chi1[131], w_chi0[131]}));
MSKand_opini2_d2_pini u_chi_132 (
    .ina({nb_d1[132], nb_d0[132]}), .inb({Bx1[148], Bx0[148]}),
    .rnd(r[132]), .s(s[132]), .clk(clk), .out({w_chi1[132], w_chi0[132]}));
MSKand_opini2_d2_pini u_chi_133 (
    .ina({nb_d1[133], nb_d0[133]}), .inb({Bx1[149], Bx0[149]}),
    .rnd(r[133]), .s(s[133]), .clk(clk), .out({w_chi1[133], w_chi0[133]}));
MSKand_opini2_d2_pini u_chi_134 (
    .ina({nb_d1[134], nb_d0[134]}), .inb({Bx1[150], Bx0[150]}),
    .rnd(r[134]), .s(s[134]), .clk(clk), .out({w_chi1[134], w_chi0[134]}));
MSKand_opini2_d2_pini u_chi_135 (
    .ina({nb_d1[135], nb_d0[135]}), .inb({Bx1[151], Bx0[151]}),
    .rnd(r[135]), .s(s[135]), .clk(clk), .out({w_chi1[135], w_chi0[135]}));
MSKand_opini2_d2_pini u_chi_168 (
    .ina({nb_d1[168], nb_d0[168]}), .inb({Bx1[184], Bx0[184]}),
    .rnd(r[168]), .s(s[168]), .clk(clk), .out({w_chi1[168], w_chi0[168]}));
MSKand_opini2_d2_pini u_chi_169 (
    .ina({nb_d1[169], nb_d0[169]}), .inb({Bx1[185], Bx0[185]}),
    .rnd(r[169]), .s(s[169]), .clk(clk), .out({w_chi1[169], w_chi0[169]}));
MSKand_opini2_d2_pini u_chi_170 (
    .ina({nb_d1[170], nb_d0[170]}), .inb({Bx1[186], Bx0[186]}),
    .rnd(r[170]), .s(s[170]), .clk(clk), .out({w_chi1[170], w_chi0[170]}));
MSKand_opini2_d2_pini u_chi_171 (
    .ina({nb_d1[171], nb_d0[171]}), .inb({Bx1[187], Bx0[187]}),
    .rnd(r[171]), .s(s[171]), .clk(clk), .out({w_chi1[171], w_chi0[171]}));
MSKand_opini2_d2_pini u_chi_172 (
    .ina({nb_d1[172], nb_d0[172]}), .inb({Bx1[188], Bx0[188]}),
    .rnd(r[172]), .s(s[172]), .clk(clk), .out({w_chi1[172], w_chi0[172]}));
MSKand_opini2_d2_pini u_chi_173 (
    .ina({nb_d1[173], nb_d0[173]}), .inb({Bx1[189], Bx0[189]}),
    .rnd(r[173]), .s(s[173]), .clk(clk), .out({w_chi1[173], w_chi0[173]}));
MSKand_opini2_d2_pini u_chi_174 (
    .ina({nb_d1[174], nb_d0[174]}), .inb({Bx1[190], Bx0[190]}),
    .rnd(r[174]), .s(s[174]), .clk(clk), .out({w_chi1[174], w_chi0[174]}));
MSKand_opini2_d2_pini u_chi_175 (
    .ina({nb_d1[175], nb_d0[175]}), .inb({Bx1[191], Bx0[191]}),
    .rnd(r[175]), .s(s[175]), .clk(clk), .out({w_chi1[175], w_chi0[175]}));
MSKand_opini2_d2_pini u_chi_16 (
    .ina({nb_d1[16], nb_d0[16]}), .inb({Bx1[32], Bx0[32]}),
    .rnd(r[16]), .s(s[16]), .clk(clk), .out({w_chi1[16], w_chi0[16]}));
MSKand_opini2_d2_pini u_chi_17 (
    .ina({nb_d1[17], nb_d0[17]}), .inb({Bx1[33], Bx0[33]}),
    .rnd(r[17]), .s(s[17]), .clk(clk), .out({w_chi1[17], w_chi0[17]}));
MSKand_opini2_d2_pini u_chi_18 (
    .ina({nb_d1[18], nb_d0[18]}), .inb({Bx1[34], Bx0[34]}),
    .rnd(r[18]), .s(s[18]), .clk(clk), .out({w_chi1[18], w_chi0[18]}));
MSKand_opini2_d2_pini u_chi_19 (
    .ina({nb_d1[19], nb_d0[19]}), .inb({Bx1[35], Bx0[35]}),
    .rnd(r[19]), .s(s[19]), .clk(clk), .out({w_chi1[19], w_chi0[19]}));
MSKand_opini2_d2_pini u_chi_20 (
    .ina({nb_d1[20], nb_d0[20]}), .inb({Bx1[36], Bx0[36]}),
    .rnd(r[20]), .s(s[20]), .clk(clk), .out({w_chi1[20], w_chi0[20]}));
MSKand_opini2_d2_pini u_chi_21 (
    .ina({nb_d1[21], nb_d0[21]}), .inb({Bx1[37], Bx0[37]}),
    .rnd(r[21]), .s(s[21]), .clk(clk), .out({w_chi1[21], w_chi0[21]}));
MSKand_opini2_d2_pini u_chi_22 (
    .ina({nb_d1[22], nb_d0[22]}), .inb({Bx1[38], Bx0[38]}),
    .rnd(r[22]), .s(s[22]), .clk(clk), .out({w_chi1[22], w_chi0[22]}));
MSKand_opini2_d2_pini u_chi_23 (
    .ina({nb_d1[23], nb_d0[23]}), .inb({Bx1[39], Bx0[39]}),
    .rnd(r[23]), .s(s[23]), .clk(clk), .out({w_chi1[23], w_chi0[23]}));
MSKand_opini2_d2_pini u_chi_56 (
    .ina({nb_d1[56], nb_d0[56]}), .inb({Bx1[72], Bx0[72]}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({w_chi1[56], w_chi0[56]}));
MSKand_opini2_d2_pini u_chi_57 (
    .ina({nb_d1[57], nb_d0[57]}), .inb({Bx1[73], Bx0[73]}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({w_chi1[57], w_chi0[57]}));
MSKand_opini2_d2_pini u_chi_58 (
    .ina({nb_d1[58], nb_d0[58]}), .inb({Bx1[74], Bx0[74]}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({w_chi1[58], w_chi0[58]}));
MSKand_opini2_d2_pini u_chi_59 (
    .ina({nb_d1[59], nb_d0[59]}), .inb({Bx1[75], Bx0[75]}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({w_chi1[59], w_chi0[59]}));
MSKand_opini2_d2_pini u_chi_60 (
    .ina({nb_d1[60], nb_d0[60]}), .inb({Bx1[76], Bx0[76]}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({w_chi1[60], w_chi0[60]}));
MSKand_opini2_d2_pini u_chi_61 (
    .ina({nb_d1[61], nb_d0[61]}), .inb({Bx1[77], Bx0[77]}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({w_chi1[61], w_chi0[61]}));
MSKand_opini2_d2_pini u_chi_62 (
    .ina({nb_d1[62], nb_d0[62]}), .inb({Bx1[78], Bx0[78]}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({w_chi1[62], w_chi0[62]}));
MSKand_opini2_d2_pini u_chi_63 (
    .ina({nb_d1[63], nb_d0[63]}), .inb({Bx1[79], Bx0[79]}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({w_chi1[63], w_chi0[63]}));
MSKand_opini2_d2_pini u_chi_96 (
    .ina({nb_d1[96], nb_d0[96]}), .inb({Bx1[112], Bx0[112]}),
    .rnd(r[96]), .s(s[96]), .clk(clk), .out({w_chi1[96], w_chi0[96]}));
MSKand_opini2_d2_pini u_chi_97 (
    .ina({nb_d1[97], nb_d0[97]}), .inb({Bx1[113], Bx0[113]}),
    .rnd(r[97]), .s(s[97]), .clk(clk), .out({w_chi1[97], w_chi0[97]}));
MSKand_opini2_d2_pini u_chi_98 (
    .ina({nb_d1[98], nb_d0[98]}), .inb({Bx1[114], Bx0[114]}),
    .rnd(r[98]), .s(s[98]), .clk(clk), .out({w_chi1[98], w_chi0[98]}));
MSKand_opini2_d2_pini u_chi_99 (
    .ina({nb_d1[99], nb_d0[99]}), .inb({Bx1[115], Bx0[115]}),
    .rnd(r[99]), .s(s[99]), .clk(clk), .out({w_chi1[99], w_chi0[99]}));
MSKand_opini2_d2_pini u_chi_100 (
    .ina({nb_d1[100], nb_d0[100]}), .inb({Bx1[116], Bx0[116]}),
    .rnd(r[100]), .s(s[100]), .clk(clk), .out({w_chi1[100], w_chi0[100]}));
MSKand_opini2_d2_pini u_chi_101 (
    .ina({nb_d1[101], nb_d0[101]}), .inb({Bx1[117], Bx0[117]}),
    .rnd(r[101]), .s(s[101]), .clk(clk), .out({w_chi1[101], w_chi0[101]}));
MSKand_opini2_d2_pini u_chi_102 (
    .ina({nb_d1[102], nb_d0[102]}), .inb({Bx1[118], Bx0[118]}),
    .rnd(r[102]), .s(s[102]), .clk(clk), .out({w_chi1[102], w_chi0[102]}));
MSKand_opini2_d2_pini u_chi_103 (
    .ina({nb_d1[103], nb_d0[103]}), .inb({Bx1[119], Bx0[119]}),
    .rnd(r[103]), .s(s[103]), .clk(clk), .out({w_chi1[103], w_chi0[103]}));
MSKand_opini2_d2_pini u_chi_136 (
    .ina({nb_d1[136], nb_d0[136]}), .inb({Bx1[152], Bx0[152]}),
    .rnd(r[136]), .s(s[136]), .clk(clk), .out({w_chi1[136], w_chi0[136]}));
MSKand_opini2_d2_pini u_chi_137 (
    .ina({nb_d1[137], nb_d0[137]}), .inb({Bx1[153], Bx0[153]}),
    .rnd(r[137]), .s(s[137]), .clk(clk), .out({w_chi1[137], w_chi0[137]}));
MSKand_opini2_d2_pini u_chi_138 (
    .ina({nb_d1[138], nb_d0[138]}), .inb({Bx1[154], Bx0[154]}),
    .rnd(r[138]), .s(s[138]), .clk(clk), .out({w_chi1[138], w_chi0[138]}));
MSKand_opini2_d2_pini u_chi_139 (
    .ina({nb_d1[139], nb_d0[139]}), .inb({Bx1[155], Bx0[155]}),
    .rnd(r[139]), .s(s[139]), .clk(clk), .out({w_chi1[139], w_chi0[139]}));
MSKand_opini2_d2_pini u_chi_140 (
    .ina({nb_d1[140], nb_d0[140]}), .inb({Bx1[156], Bx0[156]}),
    .rnd(r[140]), .s(s[140]), .clk(clk), .out({w_chi1[140], w_chi0[140]}));
MSKand_opini2_d2_pini u_chi_141 (
    .ina({nb_d1[141], nb_d0[141]}), .inb({Bx1[157], Bx0[157]}),
    .rnd(r[141]), .s(s[141]), .clk(clk), .out({w_chi1[141], w_chi0[141]}));
MSKand_opini2_d2_pini u_chi_142 (
    .ina({nb_d1[142], nb_d0[142]}), .inb({Bx1[158], Bx0[158]}),
    .rnd(r[142]), .s(s[142]), .clk(clk), .out({w_chi1[142], w_chi0[142]}));
MSKand_opini2_d2_pini u_chi_143 (
    .ina({nb_d1[143], nb_d0[143]}), .inb({Bx1[159], Bx0[159]}),
    .rnd(r[143]), .s(s[143]), .clk(clk), .out({w_chi1[143], w_chi0[143]}));
MSKand_opini2_d2_pini u_chi_176 (
    .ina({nb_d1[176], nb_d0[176]}), .inb({Bx1[192], Bx0[192]}),
    .rnd(r[176]), .s(s[176]), .clk(clk), .out({w_chi1[176], w_chi0[176]}));
MSKand_opini2_d2_pini u_chi_177 (
    .ina({nb_d1[177], nb_d0[177]}), .inb({Bx1[193], Bx0[193]}),
    .rnd(r[177]), .s(s[177]), .clk(clk), .out({w_chi1[177], w_chi0[177]}));
MSKand_opini2_d2_pini u_chi_178 (
    .ina({nb_d1[178], nb_d0[178]}), .inb({Bx1[194], Bx0[194]}),
    .rnd(r[178]), .s(s[178]), .clk(clk), .out({w_chi1[178], w_chi0[178]}));
MSKand_opini2_d2_pini u_chi_179 (
    .ina({nb_d1[179], nb_d0[179]}), .inb({Bx1[195], Bx0[195]}),
    .rnd(r[179]), .s(s[179]), .clk(clk), .out({w_chi1[179], w_chi0[179]}));
MSKand_opini2_d2_pini u_chi_180 (
    .ina({nb_d1[180], nb_d0[180]}), .inb({Bx1[196], Bx0[196]}),
    .rnd(r[180]), .s(s[180]), .clk(clk), .out({w_chi1[180], w_chi0[180]}));
MSKand_opini2_d2_pini u_chi_181 (
    .ina({nb_d1[181], nb_d0[181]}), .inb({Bx1[197], Bx0[197]}),
    .rnd(r[181]), .s(s[181]), .clk(clk), .out({w_chi1[181], w_chi0[181]}));
MSKand_opini2_d2_pini u_chi_182 (
    .ina({nb_d1[182], nb_d0[182]}), .inb({Bx1[198], Bx0[198]}),
    .rnd(r[182]), .s(s[182]), .clk(clk), .out({w_chi1[182], w_chi0[182]}));
MSKand_opini2_d2_pini u_chi_183 (
    .ina({nb_d1[183], nb_d0[183]}), .inb({Bx1[199], Bx0[199]}),
    .rnd(r[183]), .s(s[183]), .clk(clk), .out({w_chi1[183], w_chi0[183]}));
MSKand_opini2_d2_pini u_chi_24 (
    .ina({nb_d1[24], nb_d0[24]}), .inb({Bx1[0], Bx0[0]}),
    .rnd(r[24]), .s(s[24]), .clk(clk), .out({w_chi1[24], w_chi0[24]}));
MSKand_opini2_d2_pini u_chi_25 (
    .ina({nb_d1[25], nb_d0[25]}), .inb({Bx1[1], Bx0[1]}),
    .rnd(r[25]), .s(s[25]), .clk(clk), .out({w_chi1[25], w_chi0[25]}));
MSKand_opini2_d2_pini u_chi_26 (
    .ina({nb_d1[26], nb_d0[26]}), .inb({Bx1[2], Bx0[2]}),
    .rnd(r[26]), .s(s[26]), .clk(clk), .out({w_chi1[26], w_chi0[26]}));
MSKand_opini2_d2_pini u_chi_27 (
    .ina({nb_d1[27], nb_d0[27]}), .inb({Bx1[3], Bx0[3]}),
    .rnd(r[27]), .s(s[27]), .clk(clk), .out({w_chi1[27], w_chi0[27]}));
MSKand_opini2_d2_pini u_chi_28 (
    .ina({nb_d1[28], nb_d0[28]}), .inb({Bx1[4], Bx0[4]}),
    .rnd(r[28]), .s(s[28]), .clk(clk), .out({w_chi1[28], w_chi0[28]}));
MSKand_opini2_d2_pini u_chi_29 (
    .ina({nb_d1[29], nb_d0[29]}), .inb({Bx1[5], Bx0[5]}),
    .rnd(r[29]), .s(s[29]), .clk(clk), .out({w_chi1[29], w_chi0[29]}));
MSKand_opini2_d2_pini u_chi_30 (
    .ina({nb_d1[30], nb_d0[30]}), .inb({Bx1[6], Bx0[6]}),
    .rnd(r[30]), .s(s[30]), .clk(clk), .out({w_chi1[30], w_chi0[30]}));
MSKand_opini2_d2_pini u_chi_31 (
    .ina({nb_d1[31], nb_d0[31]}), .inb({Bx1[7], Bx0[7]}),
    .rnd(r[31]), .s(s[31]), .clk(clk), .out({w_chi1[31], w_chi0[31]}));
MSKand_opini2_d2_pini u_chi_64 (
    .ina({nb_d1[64], nb_d0[64]}), .inb({Bx1[40], Bx0[40]}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({w_chi1[64], w_chi0[64]}));
MSKand_opini2_d2_pini u_chi_65 (
    .ina({nb_d1[65], nb_d0[65]}), .inb({Bx1[41], Bx0[41]}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({w_chi1[65], w_chi0[65]}));
MSKand_opini2_d2_pini u_chi_66 (
    .ina({nb_d1[66], nb_d0[66]}), .inb({Bx1[42], Bx0[42]}),
    .rnd(r[66]), .s(s[66]), .clk(clk), .out({w_chi1[66], w_chi0[66]}));
MSKand_opini2_d2_pini u_chi_67 (
    .ina({nb_d1[67], nb_d0[67]}), .inb({Bx1[43], Bx0[43]}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({w_chi1[67], w_chi0[67]}));
MSKand_opini2_d2_pini u_chi_68 (
    .ina({nb_d1[68], nb_d0[68]}), .inb({Bx1[44], Bx0[44]}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({w_chi1[68], w_chi0[68]}));
MSKand_opini2_d2_pini u_chi_69 (
    .ina({nb_d1[69], nb_d0[69]}), .inb({Bx1[45], Bx0[45]}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({w_chi1[69], w_chi0[69]}));
MSKand_opini2_d2_pini u_chi_70 (
    .ina({nb_d1[70], nb_d0[70]}), .inb({Bx1[46], Bx0[46]}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({w_chi1[70], w_chi0[70]}));
MSKand_opini2_d2_pini u_chi_71 (
    .ina({nb_d1[71], nb_d0[71]}), .inb({Bx1[47], Bx0[47]}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({w_chi1[71], w_chi0[71]}));
MSKand_opini2_d2_pini u_chi_104 (
    .ina({nb_d1[104], nb_d0[104]}), .inb({Bx1[80], Bx0[80]}),
    .rnd(r[104]), .s(s[104]), .clk(clk), .out({w_chi1[104], w_chi0[104]}));
MSKand_opini2_d2_pini u_chi_105 (
    .ina({nb_d1[105], nb_d0[105]}), .inb({Bx1[81], Bx0[81]}),
    .rnd(r[105]), .s(s[105]), .clk(clk), .out({w_chi1[105], w_chi0[105]}));
MSKand_opini2_d2_pini u_chi_106 (
    .ina({nb_d1[106], nb_d0[106]}), .inb({Bx1[82], Bx0[82]}),
    .rnd(r[106]), .s(s[106]), .clk(clk), .out({w_chi1[106], w_chi0[106]}));
MSKand_opini2_d2_pini u_chi_107 (
    .ina({nb_d1[107], nb_d0[107]}), .inb({Bx1[83], Bx0[83]}),
    .rnd(r[107]), .s(s[107]), .clk(clk), .out({w_chi1[107], w_chi0[107]}));
MSKand_opini2_d2_pini u_chi_108 (
    .ina({nb_d1[108], nb_d0[108]}), .inb({Bx1[84], Bx0[84]}),
    .rnd(r[108]), .s(s[108]), .clk(clk), .out({w_chi1[108], w_chi0[108]}));
MSKand_opini2_d2_pini u_chi_109 (
    .ina({nb_d1[109], nb_d0[109]}), .inb({Bx1[85], Bx0[85]}),
    .rnd(r[109]), .s(s[109]), .clk(clk), .out({w_chi1[109], w_chi0[109]}));
MSKand_opini2_d2_pini u_chi_110 (
    .ina({nb_d1[110], nb_d0[110]}), .inb({Bx1[86], Bx0[86]}),
    .rnd(r[110]), .s(s[110]), .clk(clk), .out({w_chi1[110], w_chi0[110]}));
MSKand_opini2_d2_pini u_chi_111 (
    .ina({nb_d1[111], nb_d0[111]}), .inb({Bx1[87], Bx0[87]}),
    .rnd(r[111]), .s(s[111]), .clk(clk), .out({w_chi1[111], w_chi0[111]}));
MSKand_opini2_d2_pini u_chi_144 (
    .ina({nb_d1[144], nb_d0[144]}), .inb({Bx1[120], Bx0[120]}),
    .rnd(r[144]), .s(s[144]), .clk(clk), .out({w_chi1[144], w_chi0[144]}));
MSKand_opini2_d2_pini u_chi_145 (
    .ina({nb_d1[145], nb_d0[145]}), .inb({Bx1[121], Bx0[121]}),
    .rnd(r[145]), .s(s[145]), .clk(clk), .out({w_chi1[145], w_chi0[145]}));
MSKand_opini2_d2_pini u_chi_146 (
    .ina({nb_d1[146], nb_d0[146]}), .inb({Bx1[122], Bx0[122]}),
    .rnd(r[146]), .s(s[146]), .clk(clk), .out({w_chi1[146], w_chi0[146]}));
MSKand_opini2_d2_pini u_chi_147 (
    .ina({nb_d1[147], nb_d0[147]}), .inb({Bx1[123], Bx0[123]}),
    .rnd(r[147]), .s(s[147]), .clk(clk), .out({w_chi1[147], w_chi0[147]}));
MSKand_opini2_d2_pini u_chi_148 (
    .ina({nb_d1[148], nb_d0[148]}), .inb({Bx1[124], Bx0[124]}),
    .rnd(r[148]), .s(s[148]), .clk(clk), .out({w_chi1[148], w_chi0[148]}));
MSKand_opini2_d2_pini u_chi_149 (
    .ina({nb_d1[149], nb_d0[149]}), .inb({Bx1[125], Bx0[125]}),
    .rnd(r[149]), .s(s[149]), .clk(clk), .out({w_chi1[149], w_chi0[149]}));
MSKand_opini2_d2_pini u_chi_150 (
    .ina({nb_d1[150], nb_d0[150]}), .inb({Bx1[126], Bx0[126]}),
    .rnd(r[150]), .s(s[150]), .clk(clk), .out({w_chi1[150], w_chi0[150]}));
MSKand_opini2_d2_pini u_chi_151 (
    .ina({nb_d1[151], nb_d0[151]}), .inb({Bx1[127], Bx0[127]}),
    .rnd(r[151]), .s(s[151]), .clk(clk), .out({w_chi1[151], w_chi0[151]}));
MSKand_opini2_d2_pini u_chi_184 (
    .ina({nb_d1[184], nb_d0[184]}), .inb({Bx1[160], Bx0[160]}),
    .rnd(r[184]), .s(s[184]), .clk(clk), .out({w_chi1[184], w_chi0[184]}));
MSKand_opini2_d2_pini u_chi_185 (
    .ina({nb_d1[185], nb_d0[185]}), .inb({Bx1[161], Bx0[161]}),
    .rnd(r[185]), .s(s[185]), .clk(clk), .out({w_chi1[185], w_chi0[185]}));
MSKand_opini2_d2_pini u_chi_186 (
    .ina({nb_d1[186], nb_d0[186]}), .inb({Bx1[162], Bx0[162]}),
    .rnd(r[186]), .s(s[186]), .clk(clk), .out({w_chi1[186], w_chi0[186]}));
MSKand_opini2_d2_pini u_chi_187 (
    .ina({nb_d1[187], nb_d0[187]}), .inb({Bx1[163], Bx0[163]}),
    .rnd(r[187]), .s(s[187]), .clk(clk), .out({w_chi1[187], w_chi0[187]}));
MSKand_opini2_d2_pini u_chi_188 (
    .ina({nb_d1[188], nb_d0[188]}), .inb({Bx1[164], Bx0[164]}),
    .rnd(r[188]), .s(s[188]), .clk(clk), .out({w_chi1[188], w_chi0[188]}));
MSKand_opini2_d2_pini u_chi_189 (
    .ina({nb_d1[189], nb_d0[189]}), .inb({Bx1[165], Bx0[165]}),
    .rnd(r[189]), .s(s[189]), .clk(clk), .out({w_chi1[189], w_chi0[189]}));
MSKand_opini2_d2_pini u_chi_190 (
    .ina({nb_d1[190], nb_d0[190]}), .inb({Bx1[166], Bx0[166]}),
    .rnd(r[190]), .s(s[190]), .clk(clk), .out({w_chi1[190], w_chi0[190]}));
MSKand_opini2_d2_pini u_chi_191 (
    .ina({nb_d1[191], nb_d0[191]}), .inb({Bx1[167], Bx0[167]}),
    .rnd(r[191]), .s(s[191]), .clk(clk), .out({w_chi1[191], w_chi0[191]}));
MSKand_opini2_d2_pini u_chi_32 (
    .ina({nb_d1[32], nb_d0[32]}), .inb({Bx1[8], Bx0[8]}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({w_chi1[32], w_chi0[32]}));
MSKand_opini2_d2_pini u_chi_33 (
    .ina({nb_d1[33], nb_d0[33]}), .inb({Bx1[9], Bx0[9]}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({w_chi1[33], w_chi0[33]}));
MSKand_opini2_d2_pini u_chi_34 (
    .ina({nb_d1[34], nb_d0[34]}), .inb({Bx1[10], Bx0[10]}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({w_chi1[34], w_chi0[34]}));
MSKand_opini2_d2_pini u_chi_35 (
    .ina({nb_d1[35], nb_d0[35]}), .inb({Bx1[11], Bx0[11]}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({w_chi1[35], w_chi0[35]}));
MSKand_opini2_d2_pini u_chi_36 (
    .ina({nb_d1[36], nb_d0[36]}), .inb({Bx1[12], Bx0[12]}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({w_chi1[36], w_chi0[36]}));
MSKand_opini2_d2_pini u_chi_37 (
    .ina({nb_d1[37], nb_d0[37]}), .inb({Bx1[13], Bx0[13]}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({w_chi1[37], w_chi0[37]}));
MSKand_opini2_d2_pini u_chi_38 (
    .ina({nb_d1[38], nb_d0[38]}), .inb({Bx1[14], Bx0[14]}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({w_chi1[38], w_chi0[38]}));
MSKand_opini2_d2_pini u_chi_39 (
    .ina({nb_d1[39], nb_d0[39]}), .inb({Bx1[15], Bx0[15]}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({w_chi1[39], w_chi0[39]}));
MSKand_opini2_d2_pini u_chi_72 (
    .ina({nb_d1[72], nb_d0[72]}), .inb({Bx1[48], Bx0[48]}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({w_chi1[72], w_chi0[72]}));
MSKand_opini2_d2_pini u_chi_73 (
    .ina({nb_d1[73], nb_d0[73]}), .inb({Bx1[49], Bx0[49]}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({w_chi1[73], w_chi0[73]}));
MSKand_opini2_d2_pini u_chi_74 (
    .ina({nb_d1[74], nb_d0[74]}), .inb({Bx1[50], Bx0[50]}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({w_chi1[74], w_chi0[74]}));
MSKand_opini2_d2_pini u_chi_75 (
    .ina({nb_d1[75], nb_d0[75]}), .inb({Bx1[51], Bx0[51]}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({w_chi1[75], w_chi0[75]}));
MSKand_opini2_d2_pini u_chi_76 (
    .ina({nb_d1[76], nb_d0[76]}), .inb({Bx1[52], Bx0[52]}),
    .rnd(r[76]), .s(s[76]), .clk(clk), .out({w_chi1[76], w_chi0[76]}));
MSKand_opini2_d2_pini u_chi_77 (
    .ina({nb_d1[77], nb_d0[77]}), .inb({Bx1[53], Bx0[53]}),
    .rnd(r[77]), .s(s[77]), .clk(clk), .out({w_chi1[77], w_chi0[77]}));
MSKand_opini2_d2_pini u_chi_78 (
    .ina({nb_d1[78], nb_d0[78]}), .inb({Bx1[54], Bx0[54]}),
    .rnd(r[78]), .s(s[78]), .clk(clk), .out({w_chi1[78], w_chi0[78]}));
MSKand_opini2_d2_pini u_chi_79 (
    .ina({nb_d1[79], nb_d0[79]}), .inb({Bx1[55], Bx0[55]}),
    .rnd(r[79]), .s(s[79]), .clk(clk), .out({w_chi1[79], w_chi0[79]}));
MSKand_opini2_d2_pini u_chi_112 (
    .ina({nb_d1[112], nb_d0[112]}), .inb({Bx1[88], Bx0[88]}),
    .rnd(r[112]), .s(s[112]), .clk(clk), .out({w_chi1[112], w_chi0[112]}));
MSKand_opini2_d2_pini u_chi_113 (
    .ina({nb_d1[113], nb_d0[113]}), .inb({Bx1[89], Bx0[89]}),
    .rnd(r[113]), .s(s[113]), .clk(clk), .out({w_chi1[113], w_chi0[113]}));
MSKand_opini2_d2_pini u_chi_114 (
    .ina({nb_d1[114], nb_d0[114]}), .inb({Bx1[90], Bx0[90]}),
    .rnd(r[114]), .s(s[114]), .clk(clk), .out({w_chi1[114], w_chi0[114]}));
MSKand_opini2_d2_pini u_chi_115 (
    .ina({nb_d1[115], nb_d0[115]}), .inb({Bx1[91], Bx0[91]}),
    .rnd(r[115]), .s(s[115]), .clk(clk), .out({w_chi1[115], w_chi0[115]}));
MSKand_opini2_d2_pini u_chi_116 (
    .ina({nb_d1[116], nb_d0[116]}), .inb({Bx1[92], Bx0[92]}),
    .rnd(r[116]), .s(s[116]), .clk(clk), .out({w_chi1[116], w_chi0[116]}));
MSKand_opini2_d2_pini u_chi_117 (
    .ina({nb_d1[117], nb_d0[117]}), .inb({Bx1[93], Bx0[93]}),
    .rnd(r[117]), .s(s[117]), .clk(clk), .out({w_chi1[117], w_chi0[117]}));
MSKand_opini2_d2_pini u_chi_118 (
    .ina({nb_d1[118], nb_d0[118]}), .inb({Bx1[94], Bx0[94]}),
    .rnd(r[118]), .s(s[118]), .clk(clk), .out({w_chi1[118], w_chi0[118]}));
MSKand_opini2_d2_pini u_chi_119 (
    .ina({nb_d1[119], nb_d0[119]}), .inb({Bx1[95], Bx0[95]}),
    .rnd(r[119]), .s(s[119]), .clk(clk), .out({w_chi1[119], w_chi0[119]}));
MSKand_opini2_d2_pini u_chi_152 (
    .ina({nb_d1[152], nb_d0[152]}), .inb({Bx1[128], Bx0[128]}),
    .rnd(r[152]), .s(s[152]), .clk(clk), .out({w_chi1[152], w_chi0[152]}));
MSKand_opini2_d2_pini u_chi_153 (
    .ina({nb_d1[153], nb_d0[153]}), .inb({Bx1[129], Bx0[129]}),
    .rnd(r[153]), .s(s[153]), .clk(clk), .out({w_chi1[153], w_chi0[153]}));
MSKand_opini2_d2_pini u_chi_154 (
    .ina({nb_d1[154], nb_d0[154]}), .inb({Bx1[130], Bx0[130]}),
    .rnd(r[154]), .s(s[154]), .clk(clk), .out({w_chi1[154], w_chi0[154]}));
MSKand_opini2_d2_pini u_chi_155 (
    .ina({nb_d1[155], nb_d0[155]}), .inb({Bx1[131], Bx0[131]}),
    .rnd(r[155]), .s(s[155]), .clk(clk), .out({w_chi1[155], w_chi0[155]}));
MSKand_opini2_d2_pini u_chi_156 (
    .ina({nb_d1[156], nb_d0[156]}), .inb({Bx1[132], Bx0[132]}),
    .rnd(r[156]), .s(s[156]), .clk(clk), .out({w_chi1[156], w_chi0[156]}));
MSKand_opini2_d2_pini u_chi_157 (
    .ina({nb_d1[157], nb_d0[157]}), .inb({Bx1[133], Bx0[133]}),
    .rnd(r[157]), .s(s[157]), .clk(clk), .out({w_chi1[157], w_chi0[157]}));
MSKand_opini2_d2_pini u_chi_158 (
    .ina({nb_d1[158], nb_d0[158]}), .inb({Bx1[134], Bx0[134]}),
    .rnd(r[158]), .s(s[158]), .clk(clk), .out({w_chi1[158], w_chi0[158]}));
MSKand_opini2_d2_pini u_chi_159 (
    .ina({nb_d1[159], nb_d0[159]}), .inb({Bx1[135], Bx0[135]}),
    .rnd(r[159]), .s(s[159]), .clk(clk), .out({w_chi1[159], w_chi0[159]}));
MSKand_opini2_d2_pini u_chi_192 (
    .ina({nb_d1[192], nb_d0[192]}), .inb({Bx1[168], Bx0[168]}),
    .rnd(r[192]), .s(s[192]), .clk(clk), .out({w_chi1[192], w_chi0[192]}));
MSKand_opini2_d2_pini u_chi_193 (
    .ina({nb_d1[193], nb_d0[193]}), .inb({Bx1[169], Bx0[169]}),
    .rnd(r[193]), .s(s[193]), .clk(clk), .out({w_chi1[193], w_chi0[193]}));
MSKand_opini2_d2_pini u_chi_194 (
    .ina({nb_d1[194], nb_d0[194]}), .inb({Bx1[170], Bx0[170]}),
    .rnd(r[194]), .s(s[194]), .clk(clk), .out({w_chi1[194], w_chi0[194]}));
MSKand_opini2_d2_pini u_chi_195 (
    .ina({nb_d1[195], nb_d0[195]}), .inb({Bx1[171], Bx0[171]}),
    .rnd(r[195]), .s(s[195]), .clk(clk), .out({w_chi1[195], w_chi0[195]}));
MSKand_opini2_d2_pini u_chi_196 (
    .ina({nb_d1[196], nb_d0[196]}), .inb({Bx1[172], Bx0[172]}),
    .rnd(r[196]), .s(s[196]), .clk(clk), .out({w_chi1[196], w_chi0[196]}));
MSKand_opini2_d2_pini u_chi_197 (
    .ina({nb_d1[197], nb_d0[197]}), .inb({Bx1[173], Bx0[173]}),
    .rnd(r[197]), .s(s[197]), .clk(clk), .out({w_chi1[197], w_chi0[197]}));
MSKand_opini2_d2_pini u_chi_198 (
    .ina({nb_d1[198], nb_d0[198]}), .inb({Bx1[174], Bx0[174]}),
    .rnd(r[198]), .s(s[198]), .clk(clk), .out({w_chi1[198], w_chi0[198]}));
MSKand_opini2_d2_pini u_chi_199 (
    .ina({nb_d1[199], nb_d0[199]}), .inb({Bx1[175], Bx0[175]}),
    .rnd(r[199]), .s(s[199]), .clk(clk), .out({w_chi1[199], w_chi0[199]}));

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
assign o[200] = St0[100];  assign o[201] = St1[100];
assign o[202] = St0[101];  assign o[203] = St1[101];
assign o[204] = St0[102];  assign o[205] = St1[102];
assign o[206] = St0[103];  assign o[207] = St1[103];
assign o[208] = St0[104];  assign o[209] = St1[104];
assign o[210] = St0[105];  assign o[211] = St1[105];
assign o[212] = St0[106];  assign o[213] = St1[106];
assign o[214] = St0[107];  assign o[215] = St1[107];
assign o[216] = St0[108];  assign o[217] = St1[108];
assign o[218] = St0[109];  assign o[219] = St1[109];
assign o[220] = St0[110];  assign o[221] = St1[110];
assign o[222] = St0[111];  assign o[223] = St1[111];
assign o[224] = St0[112];  assign o[225] = St1[112];
assign o[226] = St0[113];  assign o[227] = St1[113];
assign o[228] = St0[114];  assign o[229] = St1[114];
assign o[230] = St0[115];  assign o[231] = St1[115];
assign o[232] = St0[116];  assign o[233] = St1[116];
assign o[234] = St0[117];  assign o[235] = St1[117];
assign o[236] = St0[118];  assign o[237] = St1[118];
assign o[238] = St0[119];  assign o[239] = St1[119];
assign o[240] = St0[120];  assign o[241] = St1[120];
assign o[242] = St0[121];  assign o[243] = St1[121];
assign o[244] = St0[122];  assign o[245] = St1[122];
assign o[246] = St0[123];  assign o[247] = St1[123];
assign o[248] = St0[124];  assign o[249] = St1[124];
assign o[250] = St0[125];  assign o[251] = St1[125];
assign o[252] = St0[126];  assign o[253] = St1[126];
assign o[254] = St0[127];  assign o[255] = St1[127];
assign o[256] = St0[128];  assign o[257] = St1[128];
assign o[258] = St0[129];  assign o[259] = St1[129];
assign o[260] = St0[130];  assign o[261] = St1[130];
assign o[262] = St0[131];  assign o[263] = St1[131];
assign o[264] = St0[132];  assign o[265] = St1[132];
assign o[266] = St0[133];  assign o[267] = St1[133];
assign o[268] = St0[134];  assign o[269] = St1[134];
assign o[270] = St0[135];  assign o[271] = St1[135];
assign o[272] = St0[136];  assign o[273] = St1[136];
assign o[274] = St0[137];  assign o[275] = St1[137];
assign o[276] = St0[138];  assign o[277] = St1[138];
assign o[278] = St0[139];  assign o[279] = St1[139];
assign o[280] = St0[140];  assign o[281] = St1[140];
assign o[282] = St0[141];  assign o[283] = St1[141];
assign o[284] = St0[142];  assign o[285] = St1[142];
assign o[286] = St0[143];  assign o[287] = St1[143];
assign o[288] = St0[144];  assign o[289] = St1[144];
assign o[290] = St0[145];  assign o[291] = St1[145];
assign o[292] = St0[146];  assign o[293] = St1[146];
assign o[294] = St0[147];  assign o[295] = St1[147];
assign o[296] = St0[148];  assign o[297] = St1[148];
assign o[298] = St0[149];  assign o[299] = St1[149];
assign o[300] = St0[150];  assign o[301] = St1[150];
assign o[302] = St0[151];  assign o[303] = St1[151];
assign o[304] = St0[152];  assign o[305] = St1[152];
assign o[306] = St0[153];  assign o[307] = St1[153];
assign o[308] = St0[154];  assign o[309] = St1[154];
assign o[310] = St0[155];  assign o[311] = St1[155];
assign o[312] = St0[156];  assign o[313] = St1[156];
assign o[314] = St0[157];  assign o[315] = St1[157];
assign o[316] = St0[158];  assign o[317] = St1[158];
assign o[318] = St0[159];  assign o[319] = St1[159];
assign o[320] = St0[160];  assign o[321] = St1[160];
assign o[322] = St0[161];  assign o[323] = St1[161];
assign o[324] = St0[162];  assign o[325] = St1[162];
assign o[326] = St0[163];  assign o[327] = St1[163];
assign o[328] = St0[164];  assign o[329] = St1[164];
assign o[330] = St0[165];  assign o[331] = St1[165];
assign o[332] = St0[166];  assign o[333] = St1[166];
assign o[334] = St0[167];  assign o[335] = St1[167];
assign o[336] = St0[168];  assign o[337] = St1[168];
assign o[338] = St0[169];  assign o[339] = St1[169];
assign o[340] = St0[170];  assign o[341] = St1[170];
assign o[342] = St0[171];  assign o[343] = St1[171];
assign o[344] = St0[172];  assign o[345] = St1[172];
assign o[346] = St0[173];  assign o[347] = St1[173];
assign o[348] = St0[174];  assign o[349] = St1[174];
assign o[350] = St0[175];  assign o[351] = St1[175];
assign o[352] = St0[176];  assign o[353] = St1[176];
assign o[354] = St0[177];  assign o[355] = St1[177];
assign o[356] = St0[178];  assign o[357] = St1[178];
assign o[358] = St0[179];  assign o[359] = St1[179];
assign o[360] = St0[180];  assign o[361] = St1[180];
assign o[362] = St0[181];  assign o[363] = St1[181];
assign o[364] = St0[182];  assign o[365] = St1[182];
assign o[366] = St0[183];  assign o[367] = St1[183];
assign o[368] = St0[184];  assign o[369] = St1[184];
assign o[370] = St0[185];  assign o[371] = St1[185];
assign o[372] = St0[186];  assign o[373] = St1[186];
assign o[374] = St0[187];  assign o[375] = St1[187];
assign o[376] = St0[188];  assign o[377] = St1[188];
assign o[378] = St0[189];  assign o[379] = St1[189];
assign o[380] = St0[190];  assign o[381] = St1[190];
assign o[382] = St0[191];  assign o[383] = St1[191];
assign o[384] = St0[192];  assign o[385] = St1[192];
assign o[386] = St0[193];  assign o[387] = St1[193];
assign o[388] = St0[194];  assign o[389] = St1[194];
assign o[390] = St0[195];  assign o[391] = St1[195];
assign o[392] = St0[196];  assign o[393] = St1[196];
assign o[394] = St0[197];  assign o[395] = St1[197];
assign o[396] = St0[198];  assign o[397] = St1[198];
assign o[398] = St0[199];  assign o[399] = St1[199];

endmodule
