// LABEL CONTROL: identical netlist but instantiates the PINI-relabelled
// leaf MSKand_opini2_d2_pini. This datapath REUSES gadgets bubble-free
// with feedback, the structure MATCHI's transition rule guards for PINI
// leaves (cf. ./top_chain_pini). Verdict recorded either way.
// Iterative restoring divider, q = A/B, rem = A%B (B != 0). 770 assumed-OPINI
// gadget leaves (514 subtract u_g_*/u_t_* — the verified-adder dataflow
// with sub=1 — plus 256 borrow-mux u_m_*), each with a DEDICATED r[k]/s[k]
// random bit. Every XOR/NOT/shift is strictly share-local.
// Dense sharing layout (share index fastest): port[2i]=share0, port[2i+1]=share1.
// Schedule: load @0; iteration i occupies cycles [1+528i, 528+528i]; q/rem
// (registers) stable from cycle 135169; state cleared (share-local, to
// public 0) at cycle 135184; randoms fresh [0,135718].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module div256_pini (clk, rst, go, a, b, r, s, q, rem);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [511:0] a;
(* matchi_type = "sharings_dense", matchi_active = "b_act" *) input [511:0] b;
(* matchi_type = "random", matchi_active = "r_act" *) input [769:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [769:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [511:0] q;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [511:0] rem;

// ---- activity windows from an idempotent cycle counter (public control;
// counts 1.. from the go pulse, saturates — see generator header) ----
reg [18:0] cnt;
always @(posedge clk) begin
    if (rst)                       cnt <= 19'd0;
    else if (go)                   cnt <= 19'd1;
    else if (cnt != 19'd0 && cnt != 19'd135721) cnt <= cnt + 19'd1;
end
(* keep *) wire a_act   = go || (cnt == 19'd1);   // operands consumed at load
(* keep *) wire b_act   = go || (cnt == 19'd1);
(* keep *) wire r_act   = go || (cnt >= 19'd1 && cnt <= 19'd135718);
(* keep *) wire s_act   =       (cnt >= 19'd1 && cnt <= 19'd135719);
(* keep *) wire out_act = go || (cnt >= 19'd1 && cnt <= 19'd135716);
(* keep *) wire clr     = (cnt == 19'd135184);  // bounded sensitivity

// ---- public FSM: iteration counter + phase (control only, data-independent) ----
reg running;
reg [8:0] it;
reg [9:0] ph;
always @(posedge clk) begin
    if (rst) begin running <= 1'b0; it <= 0; ph <= 0; end
    else if (go) begin running <= 1'b1; it <= 0; ph <= 0; end
    else if (running) begin
        if (ph == 527) begin
            ph <= 0;
            if (it == 9'd255) begin running <= 1'b0; it <= 0; end
            else it <= it + 9'd1;
        end else ph <= ph + 1'b1;
    end
end

// ---- state registers (per-share; NEVER mix share 0 and share 1) ----
reg [255:0] R0, R1;            // partial remainder
reg [255:0] A0, A1;            // dividend, shifts left (public 0 in)
reg [255:0] Q0, Q1;            // quotient, shifts left (cout in)
reg [255:0] Bn0, Bn1;          // ~B, complement share-local (share 0 only)
reg [255:0] Treg0, Treg1;      // registered subtract result (settled)
reg coutr0, coutr1;              // registered carry-out = quotient bit
wire [256:0] Rsh0 = {R0, A0[255]};   // Rsh = R<<1 | msb(A), per share
wire [256:0] Rsh1 = {R1, A1[255]};
wire [255:0] w_m0, w_m1;       // borrow-mux gadget outputs
// (* keep *): T/coutw feed only register inputs; without keep, abc absorbs
// their XOR drivers into the register cone and MATCHI hits a driverless wire.
(* keep *) wire [255:0] T0, T1;   // subtract difference bits (settled by M1)
(* keep *) wire coutw0, coutw1;     // subtract carry-out = NOT borrow

always @(posedge clk) begin
    if (rst || clr) begin
        R0 <= 0; R1 <= 0; A0 <= 0; A1 <= 0; Q0 <= 0; Q1 <= 0;
        Bn0 <= 0; Bn1 <= 0; Treg0 <= 0; Treg1 <= 0; coutr0 <= 0; coutr1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        A0 <= {a[510], a[508], a[506], a[504], a[502], a[500], a[498], a[496], a[494], a[492], a[490], a[488], a[486], a[484], a[482], a[480], a[478], a[476], a[474], a[472], a[470], a[468], a[466], a[464], a[462], a[460], a[458], a[456], a[454], a[452], a[450], a[448], a[446], a[444], a[442], a[440], a[438], a[436], a[434], a[432], a[430], a[428], a[426], a[424], a[422], a[420], a[418], a[416], a[414], a[412], a[410], a[408], a[406], a[404], a[402], a[400], a[398], a[396], a[394], a[392], a[390], a[388], a[386], a[384], a[382], a[380], a[378], a[376], a[374], a[372], a[370], a[368], a[366], a[364], a[362], a[360], a[358], a[356], a[354], a[352], a[350], a[348], a[346], a[344], a[342], a[340], a[338], a[336], a[334], a[332], a[330], a[328], a[326], a[324], a[322], a[320], a[318], a[316], a[314], a[312], a[310], a[308], a[306], a[304], a[302], a[300], a[298], a[296], a[294], a[292], a[290], a[288], a[286], a[284], a[282], a[280], a[278], a[276], a[274], a[272], a[270], a[268], a[266], a[264], a[262], a[260], a[258], a[256], a[254], a[252], a[250], a[248], a[246], a[244], a[242], a[240], a[238], a[236], a[234], a[232], a[230], a[228], a[226], a[224], a[222], a[220], a[218], a[216], a[214], a[212], a[210], a[208], a[206], a[204], a[202], a[200], a[198], a[196], a[194], a[192], a[190], a[188], a[186], a[184], a[182], a[180], a[178], a[176], a[174], a[172], a[170], a[168], a[166], a[164], a[162], a[160], a[158], a[156], a[154], a[152], a[150], a[148], a[146], a[144], a[142], a[140], a[138], a[136], a[134], a[132], a[130], a[128], a[126], a[124], a[122], a[120], a[118], a[116], a[114], a[112], a[110], a[108], a[106], a[104], a[102], a[100], a[98], a[96], a[94], a[92], a[90], a[88], a[86], a[84], a[82], a[80], a[78], a[76], a[74], a[72], a[70], a[68], a[66], a[64], a[62], a[60], a[58], a[56], a[54], a[52], a[50], a[48], a[46], a[44], a[42], a[40], a[38], a[36], a[34], a[32], a[30], a[28], a[26], a[24], a[22], a[20], a[18], a[16], a[14], a[12], a[10], a[8], a[6], a[4], a[2], a[0]};
        A1 <= {a[511], a[509], a[507], a[505], a[503], a[501], a[499], a[497], a[495], a[493], a[491], a[489], a[487], a[485], a[483], a[481], a[479], a[477], a[475], a[473], a[471], a[469], a[467], a[465], a[463], a[461], a[459], a[457], a[455], a[453], a[451], a[449], a[447], a[445], a[443], a[441], a[439], a[437], a[435], a[433], a[431], a[429], a[427], a[425], a[423], a[421], a[419], a[417], a[415], a[413], a[411], a[409], a[407], a[405], a[403], a[401], a[399], a[397], a[395], a[393], a[391], a[389], a[387], a[385], a[383], a[381], a[379], a[377], a[375], a[373], a[371], a[369], a[367], a[365], a[363], a[361], a[359], a[357], a[355], a[353], a[351], a[349], a[347], a[345], a[343], a[341], a[339], a[337], a[335], a[333], a[331], a[329], a[327], a[325], a[323], a[321], a[319], a[317], a[315], a[313], a[311], a[309], a[307], a[305], a[303], a[301], a[299], a[297], a[295], a[293], a[291], a[289], a[287], a[285], a[283], a[281], a[279], a[277], a[275], a[273], a[271], a[269], a[267], a[265], a[263], a[261], a[259], a[257], a[255], a[253], a[251], a[249], a[247], a[245], a[243], a[241], a[239], a[237], a[235], a[233], a[231], a[229], a[227], a[225], a[223], a[221], a[219], a[217], a[215], a[213], a[211], a[209], a[207], a[205], a[203], a[201], a[199], a[197], a[195], a[193], a[191], a[189], a[187], a[185], a[183], a[181], a[179], a[177], a[175], a[173], a[171], a[169], a[167], a[165], a[163], a[161], a[159], a[157], a[155], a[153], a[151], a[149], a[147], a[145], a[143], a[141], a[139], a[137], a[135], a[133], a[131], a[129], a[127], a[125], a[123], a[121], a[119], a[117], a[115], a[113], a[111], a[109], a[107], a[105], a[103], a[101], a[99], a[97], a[95], a[93], a[91], a[89], a[87], a[85], a[83], a[81], a[79], a[77], a[75], a[73], a[71], a[69], a[67], a[65], a[63], a[61], a[59], a[57], a[55], a[53], a[51], a[49], a[47], a[45], a[43], a[41], a[39], a[37], a[35], a[33], a[31], a[29], a[27], a[25], a[23], a[21], a[19], a[17], a[15], a[13], a[11], a[9], a[7], a[5], a[3], a[1]};
        Bn0 <= ~{b[510], b[508], b[506], b[504], b[502], b[500], b[498], b[496], b[494], b[492], b[490], b[488], b[486], b[484], b[482], b[480], b[478], b[476], b[474], b[472], b[470], b[468], b[466], b[464], b[462], b[460], b[458], b[456], b[454], b[452], b[450], b[448], b[446], b[444], b[442], b[440], b[438], b[436], b[434], b[432], b[430], b[428], b[426], b[424], b[422], b[420], b[418], b[416], b[414], b[412], b[410], b[408], b[406], b[404], b[402], b[400], b[398], b[396], b[394], b[392], b[390], b[388], b[386], b[384], b[382], b[380], b[378], b[376], b[374], b[372], b[370], b[368], b[366], b[364], b[362], b[360], b[358], b[356], b[354], b[352], b[350], b[348], b[346], b[344], b[342], b[340], b[338], b[336], b[334], b[332], b[330], b[328], b[326], b[324], b[322], b[320], b[318], b[316], b[314], b[312], b[310], b[308], b[306], b[304], b[302], b[300], b[298], b[296], b[294], b[292], b[290], b[288], b[286], b[284], b[282], b[280], b[278], b[276], b[274], b[272], b[270], b[268], b[266], b[264], b[262], b[260], b[258], b[256], b[254], b[252], b[250], b[248], b[246], b[244], b[242], b[240], b[238], b[236], b[234], b[232], b[230], b[228], b[226], b[224], b[222], b[220], b[218], b[216], b[214], b[212], b[210], b[208], b[206], b[204], b[202], b[200], b[198], b[196], b[194], b[192], b[190], b[188], b[186], b[184], b[182], b[180], b[178], b[176], b[174], b[172], b[170], b[168], b[166], b[164], b[162], b[160], b[158], b[156], b[154], b[152], b[150], b[148], b[146], b[144], b[142], b[140], b[138], b[136], b[134], b[132], b[130], b[128], b[126], b[124], b[122], b[120], b[118], b[116], b[114], b[112], b[110], b[108], b[106], b[104], b[102], b[100], b[98], b[96], b[94], b[92], b[90], b[88], b[86], b[84], b[82], b[80], b[78], b[76], b[74], b[72], b[70], b[68], b[66], b[64], b[62], b[60], b[58], b[56], b[54], b[52], b[50], b[48], b[46], b[44], b[42], b[40], b[38], b[36], b[34], b[32], b[30], b[28], b[26], b[24], b[22], b[20], b[18], b[16], b[14], b[12], b[10], b[8], b[6], b[4], b[2], b[0]};   // share-local NOT: complement share 0
        Bn1 <= {b[511], b[509], b[507], b[505], b[503], b[501], b[499], b[497], b[495], b[493], b[491], b[489], b[487], b[485], b[483], b[481], b[479], b[477], b[475], b[473], b[471], b[469], b[467], b[465], b[463], b[461], b[459], b[457], b[455], b[453], b[451], b[449], b[447], b[445], b[443], b[441], b[439], b[437], b[435], b[433], b[431], b[429], b[427], b[425], b[423], b[421], b[419], b[417], b[415], b[413], b[411], b[409], b[407], b[405], b[403], b[401], b[399], b[397], b[395], b[393], b[391], b[389], b[387], b[385], b[383], b[381], b[379], b[377], b[375], b[373], b[371], b[369], b[367], b[365], b[363], b[361], b[359], b[357], b[355], b[353], b[351], b[349], b[347], b[345], b[343], b[341], b[339], b[337], b[335], b[333], b[331], b[329], b[327], b[325], b[323], b[321], b[319], b[317], b[315], b[313], b[311], b[309], b[307], b[305], b[303], b[301], b[299], b[297], b[295], b[293], b[291], b[289], b[287], b[285], b[283], b[281], b[279], b[277], b[275], b[273], b[271], b[269], b[267], b[265], b[263], b[261], b[259], b[257], b[255], b[253], b[251], b[249], b[247], b[245], b[243], b[241], b[239], b[237], b[235], b[233], b[231], b[229], b[227], b[225], b[223], b[221], b[219], b[217], b[215], b[213], b[211], b[209], b[207], b[205], b[203], b[201], b[199], b[197], b[195], b[193], b[191], b[189], b[187], b[185], b[183], b[181], b[179], b[177], b[175], b[173], b[171], b[169], b[167], b[165], b[163], b[161], b[159], b[157], b[155], b[153], b[151], b[149], b[147], b[145], b[143], b[141], b[139], b[137], b[135], b[133], b[131], b[129], b[127], b[125], b[123], b[121], b[119], b[117], b[115], b[113], b[111], b[109], b[107], b[105], b[103], b[101], b[99], b[97], b[95], b[93], b[91], b[89], b[87], b[85], b[83], b[81], b[79], b[77], b[75], b[73], b[71], b[69], b[67], b[65], b[63], b[61], b[59], b[57], b[55], b[53], b[51], b[49], b[47], b[45], b[43], b[41], b[39], b[37], b[35], b[33], b[31], b[29], b[27], b[25], b[23], b[21], b[19], b[17], b[15], b[13], b[11], b[9], b[7], b[5], b[3], b[1]};    // share 1 untouched
        R0 <= 0; R1 <= 0; Q0 <= 0; Q1 <= 0;
        Treg0 <= 0; Treg1 <= 0; coutr0 <= 0; coutr1 <= 0;
    end else if (running) begin
        if (ph == 519) begin   // subtract ripple settled: capture T, cout
            Treg0 <= T0; Treg1 <= T1;
            coutr0 <= coutw0; coutr1 <= coutw1;
        end
        if (ph == 527) begin    // iteration update (all share-local)
            R0 <= Rsh0[255:0] ^ w_m0;   // R' = cout ? T : Rsh
            R1 <= Rsh1[255:0] ^ w_m1;
            Q0 <= {Q0[254:0], coutr0};   // quotient bit, MSB first
            Q1 <= {Q1[254:0], coutr1};
            A0 <= {A0[254:0], 1'b0};     // A <<= 1 (per-share)
            A1 <= {A1[254:0], 1'b0};
        end
    end
end

// ---- 1-cycle per-share balance registers: every gadget ina arrives one
// cycle after its inb (gadget contract ina@1/inb@0 — the iszero256 pattern).
// Unconditional, so they drain by themselves one cycle after clr.
reg [256:0] Rsh_d0, Rsh_d1;      // ina of u_g_*  (inb = Bn)
reg [255:0] xm_d0, xm_d1;      // ina of u_m_*  (inb = coutr); xm = Rsh^Treg
always @(posedge clk) begin
    Rsh_d0 <= Rsh0;                       Rsh_d1 <= Rsh1;
    xm_d0  <= Rsh0[255:0] ^ Treg0;      xm_d1  <= Rsh1[255:0] ^ Treg1;
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
assign q[32] = Q0[16];  assign q[33] = Q1[16];  assign rem[32] = R0[16];  assign rem[33] = R1[16];
assign q[34] = Q0[17];  assign q[35] = Q1[17];  assign rem[34] = R0[17];  assign rem[35] = R1[17];
assign q[36] = Q0[18];  assign q[37] = Q1[18];  assign rem[36] = R0[18];  assign rem[37] = R1[18];
assign q[38] = Q0[19];  assign q[39] = Q1[19];  assign rem[38] = R0[19];  assign rem[39] = R1[19];
assign q[40] = Q0[20];  assign q[41] = Q1[20];  assign rem[40] = R0[20];  assign rem[41] = R1[20];
assign q[42] = Q0[21];  assign q[43] = Q1[21];  assign rem[42] = R0[21];  assign rem[43] = R1[21];
assign q[44] = Q0[22];  assign q[45] = Q1[22];  assign rem[44] = R0[22];  assign rem[45] = R1[22];
assign q[46] = Q0[23];  assign q[47] = Q1[23];  assign rem[46] = R0[23];  assign rem[47] = R1[23];
assign q[48] = Q0[24];  assign q[49] = Q1[24];  assign rem[48] = R0[24];  assign rem[49] = R1[24];
assign q[50] = Q0[25];  assign q[51] = Q1[25];  assign rem[50] = R0[25];  assign rem[51] = R1[25];
assign q[52] = Q0[26];  assign q[53] = Q1[26];  assign rem[52] = R0[26];  assign rem[53] = R1[26];
assign q[54] = Q0[27];  assign q[55] = Q1[27];  assign rem[54] = R0[27];  assign rem[55] = R1[27];
assign q[56] = Q0[28];  assign q[57] = Q1[28];  assign rem[56] = R0[28];  assign rem[57] = R1[28];
assign q[58] = Q0[29];  assign q[59] = Q1[29];  assign rem[58] = R0[29];  assign rem[59] = R1[29];
assign q[60] = Q0[30];  assign q[61] = Q1[30];  assign rem[60] = R0[30];  assign rem[61] = R1[30];
assign q[62] = Q0[31];  assign q[63] = Q1[31];  assign rem[62] = R0[31];  assign rem[63] = R1[31];
assign q[64] = Q0[32];  assign q[65] = Q1[32];  assign rem[64] = R0[32];  assign rem[65] = R1[32];
assign q[66] = Q0[33];  assign q[67] = Q1[33];  assign rem[66] = R0[33];  assign rem[67] = R1[33];
assign q[68] = Q0[34];  assign q[69] = Q1[34];  assign rem[68] = R0[34];  assign rem[69] = R1[34];
assign q[70] = Q0[35];  assign q[71] = Q1[35];  assign rem[70] = R0[35];  assign rem[71] = R1[35];
assign q[72] = Q0[36];  assign q[73] = Q1[36];  assign rem[72] = R0[36];  assign rem[73] = R1[36];
assign q[74] = Q0[37];  assign q[75] = Q1[37];  assign rem[74] = R0[37];  assign rem[75] = R1[37];
assign q[76] = Q0[38];  assign q[77] = Q1[38];  assign rem[76] = R0[38];  assign rem[77] = R1[38];
assign q[78] = Q0[39];  assign q[79] = Q1[39];  assign rem[78] = R0[39];  assign rem[79] = R1[39];
assign q[80] = Q0[40];  assign q[81] = Q1[40];  assign rem[80] = R0[40];  assign rem[81] = R1[40];
assign q[82] = Q0[41];  assign q[83] = Q1[41];  assign rem[82] = R0[41];  assign rem[83] = R1[41];
assign q[84] = Q0[42];  assign q[85] = Q1[42];  assign rem[84] = R0[42];  assign rem[85] = R1[42];
assign q[86] = Q0[43];  assign q[87] = Q1[43];  assign rem[86] = R0[43];  assign rem[87] = R1[43];
assign q[88] = Q0[44];  assign q[89] = Q1[44];  assign rem[88] = R0[44];  assign rem[89] = R1[44];
assign q[90] = Q0[45];  assign q[91] = Q1[45];  assign rem[90] = R0[45];  assign rem[91] = R1[45];
assign q[92] = Q0[46];  assign q[93] = Q1[46];  assign rem[92] = R0[46];  assign rem[93] = R1[46];
assign q[94] = Q0[47];  assign q[95] = Q1[47];  assign rem[94] = R0[47];  assign rem[95] = R1[47];
assign q[96] = Q0[48];  assign q[97] = Q1[48];  assign rem[96] = R0[48];  assign rem[97] = R1[48];
assign q[98] = Q0[49];  assign q[99] = Q1[49];  assign rem[98] = R0[49];  assign rem[99] = R1[49];
assign q[100] = Q0[50];  assign q[101] = Q1[50];  assign rem[100] = R0[50];  assign rem[101] = R1[50];
assign q[102] = Q0[51];  assign q[103] = Q1[51];  assign rem[102] = R0[51];  assign rem[103] = R1[51];
assign q[104] = Q0[52];  assign q[105] = Q1[52];  assign rem[104] = R0[52];  assign rem[105] = R1[52];
assign q[106] = Q0[53];  assign q[107] = Q1[53];  assign rem[106] = R0[53];  assign rem[107] = R1[53];
assign q[108] = Q0[54];  assign q[109] = Q1[54];  assign rem[108] = R0[54];  assign rem[109] = R1[54];
assign q[110] = Q0[55];  assign q[111] = Q1[55];  assign rem[110] = R0[55];  assign rem[111] = R1[55];
assign q[112] = Q0[56];  assign q[113] = Q1[56];  assign rem[112] = R0[56];  assign rem[113] = R1[56];
assign q[114] = Q0[57];  assign q[115] = Q1[57];  assign rem[114] = R0[57];  assign rem[115] = R1[57];
assign q[116] = Q0[58];  assign q[117] = Q1[58];  assign rem[116] = R0[58];  assign rem[117] = R1[58];
assign q[118] = Q0[59];  assign q[119] = Q1[59];  assign rem[118] = R0[59];  assign rem[119] = R1[59];
assign q[120] = Q0[60];  assign q[121] = Q1[60];  assign rem[120] = R0[60];  assign rem[121] = R1[60];
assign q[122] = Q0[61];  assign q[123] = Q1[61];  assign rem[122] = R0[61];  assign rem[123] = R1[61];
assign q[124] = Q0[62];  assign q[125] = Q1[62];  assign rem[124] = R0[62];  assign rem[125] = R1[62];
assign q[126] = Q0[63];  assign q[127] = Q1[63];  assign rem[126] = R0[63];  assign rem[127] = R1[63];
assign q[128] = Q0[64];  assign q[129] = Q1[64];  assign rem[128] = R0[64];  assign rem[129] = R1[64];
assign q[130] = Q0[65];  assign q[131] = Q1[65];  assign rem[130] = R0[65];  assign rem[131] = R1[65];
assign q[132] = Q0[66];  assign q[133] = Q1[66];  assign rem[132] = R0[66];  assign rem[133] = R1[66];
assign q[134] = Q0[67];  assign q[135] = Q1[67];  assign rem[134] = R0[67];  assign rem[135] = R1[67];
assign q[136] = Q0[68];  assign q[137] = Q1[68];  assign rem[136] = R0[68];  assign rem[137] = R1[68];
assign q[138] = Q0[69];  assign q[139] = Q1[69];  assign rem[138] = R0[69];  assign rem[139] = R1[69];
assign q[140] = Q0[70];  assign q[141] = Q1[70];  assign rem[140] = R0[70];  assign rem[141] = R1[70];
assign q[142] = Q0[71];  assign q[143] = Q1[71];  assign rem[142] = R0[71];  assign rem[143] = R1[71];
assign q[144] = Q0[72];  assign q[145] = Q1[72];  assign rem[144] = R0[72];  assign rem[145] = R1[72];
assign q[146] = Q0[73];  assign q[147] = Q1[73];  assign rem[146] = R0[73];  assign rem[147] = R1[73];
assign q[148] = Q0[74];  assign q[149] = Q1[74];  assign rem[148] = R0[74];  assign rem[149] = R1[74];
assign q[150] = Q0[75];  assign q[151] = Q1[75];  assign rem[150] = R0[75];  assign rem[151] = R1[75];
assign q[152] = Q0[76];  assign q[153] = Q1[76];  assign rem[152] = R0[76];  assign rem[153] = R1[76];
assign q[154] = Q0[77];  assign q[155] = Q1[77];  assign rem[154] = R0[77];  assign rem[155] = R1[77];
assign q[156] = Q0[78];  assign q[157] = Q1[78];  assign rem[156] = R0[78];  assign rem[157] = R1[78];
assign q[158] = Q0[79];  assign q[159] = Q1[79];  assign rem[158] = R0[79];  assign rem[159] = R1[79];
assign q[160] = Q0[80];  assign q[161] = Q1[80];  assign rem[160] = R0[80];  assign rem[161] = R1[80];
assign q[162] = Q0[81];  assign q[163] = Q1[81];  assign rem[162] = R0[81];  assign rem[163] = R1[81];
assign q[164] = Q0[82];  assign q[165] = Q1[82];  assign rem[164] = R0[82];  assign rem[165] = R1[82];
assign q[166] = Q0[83];  assign q[167] = Q1[83];  assign rem[166] = R0[83];  assign rem[167] = R1[83];
assign q[168] = Q0[84];  assign q[169] = Q1[84];  assign rem[168] = R0[84];  assign rem[169] = R1[84];
assign q[170] = Q0[85];  assign q[171] = Q1[85];  assign rem[170] = R0[85];  assign rem[171] = R1[85];
assign q[172] = Q0[86];  assign q[173] = Q1[86];  assign rem[172] = R0[86];  assign rem[173] = R1[86];
assign q[174] = Q0[87];  assign q[175] = Q1[87];  assign rem[174] = R0[87];  assign rem[175] = R1[87];
assign q[176] = Q0[88];  assign q[177] = Q1[88];  assign rem[176] = R0[88];  assign rem[177] = R1[88];
assign q[178] = Q0[89];  assign q[179] = Q1[89];  assign rem[178] = R0[89];  assign rem[179] = R1[89];
assign q[180] = Q0[90];  assign q[181] = Q1[90];  assign rem[180] = R0[90];  assign rem[181] = R1[90];
assign q[182] = Q0[91];  assign q[183] = Q1[91];  assign rem[182] = R0[91];  assign rem[183] = R1[91];
assign q[184] = Q0[92];  assign q[185] = Q1[92];  assign rem[184] = R0[92];  assign rem[185] = R1[92];
assign q[186] = Q0[93];  assign q[187] = Q1[93];  assign rem[186] = R0[93];  assign rem[187] = R1[93];
assign q[188] = Q0[94];  assign q[189] = Q1[94];  assign rem[188] = R0[94];  assign rem[189] = R1[94];
assign q[190] = Q0[95];  assign q[191] = Q1[95];  assign rem[190] = R0[95];  assign rem[191] = R1[95];
assign q[192] = Q0[96];  assign q[193] = Q1[96];  assign rem[192] = R0[96];  assign rem[193] = R1[96];
assign q[194] = Q0[97];  assign q[195] = Q1[97];  assign rem[194] = R0[97];  assign rem[195] = R1[97];
assign q[196] = Q0[98];  assign q[197] = Q1[98];  assign rem[196] = R0[98];  assign rem[197] = R1[98];
assign q[198] = Q0[99];  assign q[199] = Q1[99];  assign rem[198] = R0[99];  assign rem[199] = R1[99];
assign q[200] = Q0[100];  assign q[201] = Q1[100];  assign rem[200] = R0[100];  assign rem[201] = R1[100];
assign q[202] = Q0[101];  assign q[203] = Q1[101];  assign rem[202] = R0[101];  assign rem[203] = R1[101];
assign q[204] = Q0[102];  assign q[205] = Q1[102];  assign rem[204] = R0[102];  assign rem[205] = R1[102];
assign q[206] = Q0[103];  assign q[207] = Q1[103];  assign rem[206] = R0[103];  assign rem[207] = R1[103];
assign q[208] = Q0[104];  assign q[209] = Q1[104];  assign rem[208] = R0[104];  assign rem[209] = R1[104];
assign q[210] = Q0[105];  assign q[211] = Q1[105];  assign rem[210] = R0[105];  assign rem[211] = R1[105];
assign q[212] = Q0[106];  assign q[213] = Q1[106];  assign rem[212] = R0[106];  assign rem[213] = R1[106];
assign q[214] = Q0[107];  assign q[215] = Q1[107];  assign rem[214] = R0[107];  assign rem[215] = R1[107];
assign q[216] = Q0[108];  assign q[217] = Q1[108];  assign rem[216] = R0[108];  assign rem[217] = R1[108];
assign q[218] = Q0[109];  assign q[219] = Q1[109];  assign rem[218] = R0[109];  assign rem[219] = R1[109];
assign q[220] = Q0[110];  assign q[221] = Q1[110];  assign rem[220] = R0[110];  assign rem[221] = R1[110];
assign q[222] = Q0[111];  assign q[223] = Q1[111];  assign rem[222] = R0[111];  assign rem[223] = R1[111];
assign q[224] = Q0[112];  assign q[225] = Q1[112];  assign rem[224] = R0[112];  assign rem[225] = R1[112];
assign q[226] = Q0[113];  assign q[227] = Q1[113];  assign rem[226] = R0[113];  assign rem[227] = R1[113];
assign q[228] = Q0[114];  assign q[229] = Q1[114];  assign rem[228] = R0[114];  assign rem[229] = R1[114];
assign q[230] = Q0[115];  assign q[231] = Q1[115];  assign rem[230] = R0[115];  assign rem[231] = R1[115];
assign q[232] = Q0[116];  assign q[233] = Q1[116];  assign rem[232] = R0[116];  assign rem[233] = R1[116];
assign q[234] = Q0[117];  assign q[235] = Q1[117];  assign rem[234] = R0[117];  assign rem[235] = R1[117];
assign q[236] = Q0[118];  assign q[237] = Q1[118];  assign rem[236] = R0[118];  assign rem[237] = R1[118];
assign q[238] = Q0[119];  assign q[239] = Q1[119];  assign rem[238] = R0[119];  assign rem[239] = R1[119];
assign q[240] = Q0[120];  assign q[241] = Q1[120];  assign rem[240] = R0[120];  assign rem[241] = R1[120];
assign q[242] = Q0[121];  assign q[243] = Q1[121];  assign rem[242] = R0[121];  assign rem[243] = R1[121];
assign q[244] = Q0[122];  assign q[245] = Q1[122];  assign rem[244] = R0[122];  assign rem[245] = R1[122];
assign q[246] = Q0[123];  assign q[247] = Q1[123];  assign rem[246] = R0[123];  assign rem[247] = R1[123];
assign q[248] = Q0[124];  assign q[249] = Q1[124];  assign rem[248] = R0[124];  assign rem[249] = R1[124];
assign q[250] = Q0[125];  assign q[251] = Q1[125];  assign rem[250] = R0[125];  assign rem[251] = R1[125];
assign q[252] = Q0[126];  assign q[253] = Q1[126];  assign rem[252] = R0[126];  assign rem[253] = R1[126];
assign q[254] = Q0[127];  assign q[255] = Q1[127];  assign rem[254] = R0[127];  assign rem[255] = R1[127];
assign q[256] = Q0[128];  assign q[257] = Q1[128];  assign rem[256] = R0[128];  assign rem[257] = R1[128];
assign q[258] = Q0[129];  assign q[259] = Q1[129];  assign rem[258] = R0[129];  assign rem[259] = R1[129];
assign q[260] = Q0[130];  assign q[261] = Q1[130];  assign rem[260] = R0[130];  assign rem[261] = R1[130];
assign q[262] = Q0[131];  assign q[263] = Q1[131];  assign rem[262] = R0[131];  assign rem[263] = R1[131];
assign q[264] = Q0[132];  assign q[265] = Q1[132];  assign rem[264] = R0[132];  assign rem[265] = R1[132];
assign q[266] = Q0[133];  assign q[267] = Q1[133];  assign rem[266] = R0[133];  assign rem[267] = R1[133];
assign q[268] = Q0[134];  assign q[269] = Q1[134];  assign rem[268] = R0[134];  assign rem[269] = R1[134];
assign q[270] = Q0[135];  assign q[271] = Q1[135];  assign rem[270] = R0[135];  assign rem[271] = R1[135];
assign q[272] = Q0[136];  assign q[273] = Q1[136];  assign rem[272] = R0[136];  assign rem[273] = R1[136];
assign q[274] = Q0[137];  assign q[275] = Q1[137];  assign rem[274] = R0[137];  assign rem[275] = R1[137];
assign q[276] = Q0[138];  assign q[277] = Q1[138];  assign rem[276] = R0[138];  assign rem[277] = R1[138];
assign q[278] = Q0[139];  assign q[279] = Q1[139];  assign rem[278] = R0[139];  assign rem[279] = R1[139];
assign q[280] = Q0[140];  assign q[281] = Q1[140];  assign rem[280] = R0[140];  assign rem[281] = R1[140];
assign q[282] = Q0[141];  assign q[283] = Q1[141];  assign rem[282] = R0[141];  assign rem[283] = R1[141];
assign q[284] = Q0[142];  assign q[285] = Q1[142];  assign rem[284] = R0[142];  assign rem[285] = R1[142];
assign q[286] = Q0[143];  assign q[287] = Q1[143];  assign rem[286] = R0[143];  assign rem[287] = R1[143];
assign q[288] = Q0[144];  assign q[289] = Q1[144];  assign rem[288] = R0[144];  assign rem[289] = R1[144];
assign q[290] = Q0[145];  assign q[291] = Q1[145];  assign rem[290] = R0[145];  assign rem[291] = R1[145];
assign q[292] = Q0[146];  assign q[293] = Q1[146];  assign rem[292] = R0[146];  assign rem[293] = R1[146];
assign q[294] = Q0[147];  assign q[295] = Q1[147];  assign rem[294] = R0[147];  assign rem[295] = R1[147];
assign q[296] = Q0[148];  assign q[297] = Q1[148];  assign rem[296] = R0[148];  assign rem[297] = R1[148];
assign q[298] = Q0[149];  assign q[299] = Q1[149];  assign rem[298] = R0[149];  assign rem[299] = R1[149];
assign q[300] = Q0[150];  assign q[301] = Q1[150];  assign rem[300] = R0[150];  assign rem[301] = R1[150];
assign q[302] = Q0[151];  assign q[303] = Q1[151];  assign rem[302] = R0[151];  assign rem[303] = R1[151];
assign q[304] = Q0[152];  assign q[305] = Q1[152];  assign rem[304] = R0[152];  assign rem[305] = R1[152];
assign q[306] = Q0[153];  assign q[307] = Q1[153];  assign rem[306] = R0[153];  assign rem[307] = R1[153];
assign q[308] = Q0[154];  assign q[309] = Q1[154];  assign rem[308] = R0[154];  assign rem[309] = R1[154];
assign q[310] = Q0[155];  assign q[311] = Q1[155];  assign rem[310] = R0[155];  assign rem[311] = R1[155];
assign q[312] = Q0[156];  assign q[313] = Q1[156];  assign rem[312] = R0[156];  assign rem[313] = R1[156];
assign q[314] = Q0[157];  assign q[315] = Q1[157];  assign rem[314] = R0[157];  assign rem[315] = R1[157];
assign q[316] = Q0[158];  assign q[317] = Q1[158];  assign rem[316] = R0[158];  assign rem[317] = R1[158];
assign q[318] = Q0[159];  assign q[319] = Q1[159];  assign rem[318] = R0[159];  assign rem[319] = R1[159];
assign q[320] = Q0[160];  assign q[321] = Q1[160];  assign rem[320] = R0[160];  assign rem[321] = R1[160];
assign q[322] = Q0[161];  assign q[323] = Q1[161];  assign rem[322] = R0[161];  assign rem[323] = R1[161];
assign q[324] = Q0[162];  assign q[325] = Q1[162];  assign rem[324] = R0[162];  assign rem[325] = R1[162];
assign q[326] = Q0[163];  assign q[327] = Q1[163];  assign rem[326] = R0[163];  assign rem[327] = R1[163];
assign q[328] = Q0[164];  assign q[329] = Q1[164];  assign rem[328] = R0[164];  assign rem[329] = R1[164];
assign q[330] = Q0[165];  assign q[331] = Q1[165];  assign rem[330] = R0[165];  assign rem[331] = R1[165];
assign q[332] = Q0[166];  assign q[333] = Q1[166];  assign rem[332] = R0[166];  assign rem[333] = R1[166];
assign q[334] = Q0[167];  assign q[335] = Q1[167];  assign rem[334] = R0[167];  assign rem[335] = R1[167];
assign q[336] = Q0[168];  assign q[337] = Q1[168];  assign rem[336] = R0[168];  assign rem[337] = R1[168];
assign q[338] = Q0[169];  assign q[339] = Q1[169];  assign rem[338] = R0[169];  assign rem[339] = R1[169];
assign q[340] = Q0[170];  assign q[341] = Q1[170];  assign rem[340] = R0[170];  assign rem[341] = R1[170];
assign q[342] = Q0[171];  assign q[343] = Q1[171];  assign rem[342] = R0[171];  assign rem[343] = R1[171];
assign q[344] = Q0[172];  assign q[345] = Q1[172];  assign rem[344] = R0[172];  assign rem[345] = R1[172];
assign q[346] = Q0[173];  assign q[347] = Q1[173];  assign rem[346] = R0[173];  assign rem[347] = R1[173];
assign q[348] = Q0[174];  assign q[349] = Q1[174];  assign rem[348] = R0[174];  assign rem[349] = R1[174];
assign q[350] = Q0[175];  assign q[351] = Q1[175];  assign rem[350] = R0[175];  assign rem[351] = R1[175];
assign q[352] = Q0[176];  assign q[353] = Q1[176];  assign rem[352] = R0[176];  assign rem[353] = R1[176];
assign q[354] = Q0[177];  assign q[355] = Q1[177];  assign rem[354] = R0[177];  assign rem[355] = R1[177];
assign q[356] = Q0[178];  assign q[357] = Q1[178];  assign rem[356] = R0[178];  assign rem[357] = R1[178];
assign q[358] = Q0[179];  assign q[359] = Q1[179];  assign rem[358] = R0[179];  assign rem[359] = R1[179];
assign q[360] = Q0[180];  assign q[361] = Q1[180];  assign rem[360] = R0[180];  assign rem[361] = R1[180];
assign q[362] = Q0[181];  assign q[363] = Q1[181];  assign rem[362] = R0[181];  assign rem[363] = R1[181];
assign q[364] = Q0[182];  assign q[365] = Q1[182];  assign rem[364] = R0[182];  assign rem[365] = R1[182];
assign q[366] = Q0[183];  assign q[367] = Q1[183];  assign rem[366] = R0[183];  assign rem[367] = R1[183];
assign q[368] = Q0[184];  assign q[369] = Q1[184];  assign rem[368] = R0[184];  assign rem[369] = R1[184];
assign q[370] = Q0[185];  assign q[371] = Q1[185];  assign rem[370] = R0[185];  assign rem[371] = R1[185];
assign q[372] = Q0[186];  assign q[373] = Q1[186];  assign rem[372] = R0[186];  assign rem[373] = R1[186];
assign q[374] = Q0[187];  assign q[375] = Q1[187];  assign rem[374] = R0[187];  assign rem[375] = R1[187];
assign q[376] = Q0[188];  assign q[377] = Q1[188];  assign rem[376] = R0[188];  assign rem[377] = R1[188];
assign q[378] = Q0[189];  assign q[379] = Q1[189];  assign rem[378] = R0[189];  assign rem[379] = R1[189];
assign q[380] = Q0[190];  assign q[381] = Q1[190];  assign rem[380] = R0[190];  assign rem[381] = R1[190];
assign q[382] = Q0[191];  assign q[383] = Q1[191];  assign rem[382] = R0[191];  assign rem[383] = R1[191];
assign q[384] = Q0[192];  assign q[385] = Q1[192];  assign rem[384] = R0[192];  assign rem[385] = R1[192];
assign q[386] = Q0[193];  assign q[387] = Q1[193];  assign rem[386] = R0[193];  assign rem[387] = R1[193];
assign q[388] = Q0[194];  assign q[389] = Q1[194];  assign rem[388] = R0[194];  assign rem[389] = R1[194];
assign q[390] = Q0[195];  assign q[391] = Q1[195];  assign rem[390] = R0[195];  assign rem[391] = R1[195];
assign q[392] = Q0[196];  assign q[393] = Q1[196];  assign rem[392] = R0[196];  assign rem[393] = R1[196];
assign q[394] = Q0[197];  assign q[395] = Q1[197];  assign rem[394] = R0[197];  assign rem[395] = R1[197];
assign q[396] = Q0[198];  assign q[397] = Q1[198];  assign rem[396] = R0[198];  assign rem[397] = R1[198];
assign q[398] = Q0[199];  assign q[399] = Q1[199];  assign rem[398] = R0[199];  assign rem[399] = R1[199];
assign q[400] = Q0[200];  assign q[401] = Q1[200];  assign rem[400] = R0[200];  assign rem[401] = R1[200];
assign q[402] = Q0[201];  assign q[403] = Q1[201];  assign rem[402] = R0[201];  assign rem[403] = R1[201];
assign q[404] = Q0[202];  assign q[405] = Q1[202];  assign rem[404] = R0[202];  assign rem[405] = R1[202];
assign q[406] = Q0[203];  assign q[407] = Q1[203];  assign rem[406] = R0[203];  assign rem[407] = R1[203];
assign q[408] = Q0[204];  assign q[409] = Q1[204];  assign rem[408] = R0[204];  assign rem[409] = R1[204];
assign q[410] = Q0[205];  assign q[411] = Q1[205];  assign rem[410] = R0[205];  assign rem[411] = R1[205];
assign q[412] = Q0[206];  assign q[413] = Q1[206];  assign rem[412] = R0[206];  assign rem[413] = R1[206];
assign q[414] = Q0[207];  assign q[415] = Q1[207];  assign rem[414] = R0[207];  assign rem[415] = R1[207];
assign q[416] = Q0[208];  assign q[417] = Q1[208];  assign rem[416] = R0[208];  assign rem[417] = R1[208];
assign q[418] = Q0[209];  assign q[419] = Q1[209];  assign rem[418] = R0[209];  assign rem[419] = R1[209];
assign q[420] = Q0[210];  assign q[421] = Q1[210];  assign rem[420] = R0[210];  assign rem[421] = R1[210];
assign q[422] = Q0[211];  assign q[423] = Q1[211];  assign rem[422] = R0[211];  assign rem[423] = R1[211];
assign q[424] = Q0[212];  assign q[425] = Q1[212];  assign rem[424] = R0[212];  assign rem[425] = R1[212];
assign q[426] = Q0[213];  assign q[427] = Q1[213];  assign rem[426] = R0[213];  assign rem[427] = R1[213];
assign q[428] = Q0[214];  assign q[429] = Q1[214];  assign rem[428] = R0[214];  assign rem[429] = R1[214];
assign q[430] = Q0[215];  assign q[431] = Q1[215];  assign rem[430] = R0[215];  assign rem[431] = R1[215];
assign q[432] = Q0[216];  assign q[433] = Q1[216];  assign rem[432] = R0[216];  assign rem[433] = R1[216];
assign q[434] = Q0[217];  assign q[435] = Q1[217];  assign rem[434] = R0[217];  assign rem[435] = R1[217];
assign q[436] = Q0[218];  assign q[437] = Q1[218];  assign rem[436] = R0[218];  assign rem[437] = R1[218];
assign q[438] = Q0[219];  assign q[439] = Q1[219];  assign rem[438] = R0[219];  assign rem[439] = R1[219];
assign q[440] = Q0[220];  assign q[441] = Q1[220];  assign rem[440] = R0[220];  assign rem[441] = R1[220];
assign q[442] = Q0[221];  assign q[443] = Q1[221];  assign rem[442] = R0[221];  assign rem[443] = R1[221];
assign q[444] = Q0[222];  assign q[445] = Q1[222];  assign rem[444] = R0[222];  assign rem[445] = R1[222];
assign q[446] = Q0[223];  assign q[447] = Q1[223];  assign rem[446] = R0[223];  assign rem[447] = R1[223];
assign q[448] = Q0[224];  assign q[449] = Q1[224];  assign rem[448] = R0[224];  assign rem[449] = R1[224];
assign q[450] = Q0[225];  assign q[451] = Q1[225];  assign rem[450] = R0[225];  assign rem[451] = R1[225];
assign q[452] = Q0[226];  assign q[453] = Q1[226];  assign rem[452] = R0[226];  assign rem[453] = R1[226];
assign q[454] = Q0[227];  assign q[455] = Q1[227];  assign rem[454] = R0[227];  assign rem[455] = R1[227];
assign q[456] = Q0[228];  assign q[457] = Q1[228];  assign rem[456] = R0[228];  assign rem[457] = R1[228];
assign q[458] = Q0[229];  assign q[459] = Q1[229];  assign rem[458] = R0[229];  assign rem[459] = R1[229];
assign q[460] = Q0[230];  assign q[461] = Q1[230];  assign rem[460] = R0[230];  assign rem[461] = R1[230];
assign q[462] = Q0[231];  assign q[463] = Q1[231];  assign rem[462] = R0[231];  assign rem[463] = R1[231];
assign q[464] = Q0[232];  assign q[465] = Q1[232];  assign rem[464] = R0[232];  assign rem[465] = R1[232];
assign q[466] = Q0[233];  assign q[467] = Q1[233];  assign rem[466] = R0[233];  assign rem[467] = R1[233];
assign q[468] = Q0[234];  assign q[469] = Q1[234];  assign rem[468] = R0[234];  assign rem[469] = R1[234];
assign q[470] = Q0[235];  assign q[471] = Q1[235];  assign rem[470] = R0[235];  assign rem[471] = R1[235];
assign q[472] = Q0[236];  assign q[473] = Q1[236];  assign rem[472] = R0[236];  assign rem[473] = R1[236];
assign q[474] = Q0[237];  assign q[475] = Q1[237];  assign rem[474] = R0[237];  assign rem[475] = R1[237];
assign q[476] = Q0[238];  assign q[477] = Q1[238];  assign rem[476] = R0[238];  assign rem[477] = R1[238];
assign q[478] = Q0[239];  assign q[479] = Q1[239];  assign rem[478] = R0[239];  assign rem[479] = R1[239];
assign q[480] = Q0[240];  assign q[481] = Q1[240];  assign rem[480] = R0[240];  assign rem[481] = R1[240];
assign q[482] = Q0[241];  assign q[483] = Q1[241];  assign rem[482] = R0[241];  assign rem[483] = R1[241];
assign q[484] = Q0[242];  assign q[485] = Q1[242];  assign rem[484] = R0[242];  assign rem[485] = R1[242];
assign q[486] = Q0[243];  assign q[487] = Q1[243];  assign rem[486] = R0[243];  assign rem[487] = R1[243];
assign q[488] = Q0[244];  assign q[489] = Q1[244];  assign rem[488] = R0[244];  assign rem[489] = R1[244];
assign q[490] = Q0[245];  assign q[491] = Q1[245];  assign rem[490] = R0[245];  assign rem[491] = R1[245];
assign q[492] = Q0[246];  assign q[493] = Q1[246];  assign rem[492] = R0[246];  assign rem[493] = R1[246];
assign q[494] = Q0[247];  assign q[495] = Q1[247];  assign rem[494] = R0[247];  assign rem[495] = R1[247];
assign q[496] = Q0[248];  assign q[497] = Q1[248];  assign rem[496] = R0[248];  assign rem[497] = R1[248];
assign q[498] = Q0[249];  assign q[499] = Q1[249];  assign rem[498] = R0[249];  assign rem[499] = R1[249];
assign q[500] = Q0[250];  assign q[501] = Q1[250];  assign rem[500] = R0[250];  assign rem[501] = R1[250];
assign q[502] = Q0[251];  assign q[503] = Q1[251];  assign rem[502] = R0[251];  assign rem[503] = R1[251];
assign q[504] = Q0[252];  assign q[505] = Q1[252];  assign rem[504] = R0[252];  assign rem[505] = R1[252];
assign q[506] = Q0[253];  assign q[507] = Q1[253];  assign rem[506] = R0[253];  assign rem[507] = R1[253];
assign q[508] = Q0[254];  assign q[509] = Q1[254];  assign rem[508] = R0[254];  assign rem[509] = R1[254];
assign q[510] = Q0[255];  assign q[511] = Q1[255];  assign rem[510] = R0[255];  assign rem[511] = R1[255];

// ===== (N+1)-bit ripple subtract: T = Rsh + ~B + 1 (verified-adder dataflow, sub=1) =====
// fc[0] = carry-in = public 1 (share pair (1,0)); Bn bit 256 = ~0 = public 1.
wire [256:0] fc0, fc1;
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
wire p0_16 = Rsh_d0[16] ^ Bn0[16];
wire p1_16 = Rsh_d1[16] ^ Bn1[16];
wire g0_16, g1_16, t0_16, t1_16;
MSKand_opini2_d2_pini u_g_16 (
    .ina({Rsh_d1[16], Rsh_d0[16]}), .inb({Bn1[16], Bn0[16]}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({g1_16, g0_16}));
MSKand_opini2_d2_pini u_t_16 (
    .ina({fc1[16], fc0[16]}), .inb({p1_16, p0_16}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({t1_16, t0_16}));
assign fc0[17] = g0_16 ^ t0_16;
assign fc1[17] = g1_16 ^ t1_16;
wire p0_17 = Rsh_d0[17] ^ Bn0[17];
wire p1_17 = Rsh_d1[17] ^ Bn1[17];
wire g0_17, g1_17, t0_17, t1_17;
MSKand_opini2_d2_pini u_g_17 (
    .ina({Rsh_d1[17], Rsh_d0[17]}), .inb({Bn1[17], Bn0[17]}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({g1_17, g0_17}));
MSKand_opini2_d2_pini u_t_17 (
    .ina({fc1[17], fc0[17]}), .inb({p1_17, p0_17}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({t1_17, t0_17}));
assign fc0[18] = g0_17 ^ t0_17;
assign fc1[18] = g1_17 ^ t1_17;
wire p0_18 = Rsh_d0[18] ^ Bn0[18];
wire p1_18 = Rsh_d1[18] ^ Bn1[18];
wire g0_18, g1_18, t0_18, t1_18;
MSKand_opini2_d2_pini u_g_18 (
    .ina({Rsh_d1[18], Rsh_d0[18]}), .inb({Bn1[18], Bn0[18]}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({g1_18, g0_18}));
MSKand_opini2_d2_pini u_t_18 (
    .ina({fc1[18], fc0[18]}), .inb({p1_18, p0_18}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({t1_18, t0_18}));
assign fc0[19] = g0_18 ^ t0_18;
assign fc1[19] = g1_18 ^ t1_18;
wire p0_19 = Rsh_d0[19] ^ Bn0[19];
wire p1_19 = Rsh_d1[19] ^ Bn1[19];
wire g0_19, g1_19, t0_19, t1_19;
MSKand_opini2_d2_pini u_g_19 (
    .ina({Rsh_d1[19], Rsh_d0[19]}), .inb({Bn1[19], Bn0[19]}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({g1_19, g0_19}));
MSKand_opini2_d2_pini u_t_19 (
    .ina({fc1[19], fc0[19]}), .inb({p1_19, p0_19}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({t1_19, t0_19}));
assign fc0[20] = g0_19 ^ t0_19;
assign fc1[20] = g1_19 ^ t1_19;
wire p0_20 = Rsh_d0[20] ^ Bn0[20];
wire p1_20 = Rsh_d1[20] ^ Bn1[20];
wire g0_20, g1_20, t0_20, t1_20;
MSKand_opini2_d2_pini u_g_20 (
    .ina({Rsh_d1[20], Rsh_d0[20]}), .inb({Bn1[20], Bn0[20]}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({g1_20, g0_20}));
MSKand_opini2_d2_pini u_t_20 (
    .ina({fc1[20], fc0[20]}), .inb({p1_20, p0_20}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({t1_20, t0_20}));
assign fc0[21] = g0_20 ^ t0_20;
assign fc1[21] = g1_20 ^ t1_20;
wire p0_21 = Rsh_d0[21] ^ Bn0[21];
wire p1_21 = Rsh_d1[21] ^ Bn1[21];
wire g0_21, g1_21, t0_21, t1_21;
MSKand_opini2_d2_pini u_g_21 (
    .ina({Rsh_d1[21], Rsh_d0[21]}), .inb({Bn1[21], Bn0[21]}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({g1_21, g0_21}));
MSKand_opini2_d2_pini u_t_21 (
    .ina({fc1[21], fc0[21]}), .inb({p1_21, p0_21}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({t1_21, t0_21}));
assign fc0[22] = g0_21 ^ t0_21;
assign fc1[22] = g1_21 ^ t1_21;
wire p0_22 = Rsh_d0[22] ^ Bn0[22];
wire p1_22 = Rsh_d1[22] ^ Bn1[22];
wire g0_22, g1_22, t0_22, t1_22;
MSKand_opini2_d2_pini u_g_22 (
    .ina({Rsh_d1[22], Rsh_d0[22]}), .inb({Bn1[22], Bn0[22]}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({g1_22, g0_22}));
MSKand_opini2_d2_pini u_t_22 (
    .ina({fc1[22], fc0[22]}), .inb({p1_22, p0_22}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({t1_22, t0_22}));
assign fc0[23] = g0_22 ^ t0_22;
assign fc1[23] = g1_22 ^ t1_22;
wire p0_23 = Rsh_d0[23] ^ Bn0[23];
wire p1_23 = Rsh_d1[23] ^ Bn1[23];
wire g0_23, g1_23, t0_23, t1_23;
MSKand_opini2_d2_pini u_g_23 (
    .ina({Rsh_d1[23], Rsh_d0[23]}), .inb({Bn1[23], Bn0[23]}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({g1_23, g0_23}));
MSKand_opini2_d2_pini u_t_23 (
    .ina({fc1[23], fc0[23]}), .inb({p1_23, p0_23}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({t1_23, t0_23}));
assign fc0[24] = g0_23 ^ t0_23;
assign fc1[24] = g1_23 ^ t1_23;
wire p0_24 = Rsh_d0[24] ^ Bn0[24];
wire p1_24 = Rsh_d1[24] ^ Bn1[24];
wire g0_24, g1_24, t0_24, t1_24;
MSKand_opini2_d2_pini u_g_24 (
    .ina({Rsh_d1[24], Rsh_d0[24]}), .inb({Bn1[24], Bn0[24]}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({g1_24, g0_24}));
MSKand_opini2_d2_pini u_t_24 (
    .ina({fc1[24], fc0[24]}), .inb({p1_24, p0_24}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({t1_24, t0_24}));
assign fc0[25] = g0_24 ^ t0_24;
assign fc1[25] = g1_24 ^ t1_24;
wire p0_25 = Rsh_d0[25] ^ Bn0[25];
wire p1_25 = Rsh_d1[25] ^ Bn1[25];
wire g0_25, g1_25, t0_25, t1_25;
MSKand_opini2_d2_pini u_g_25 (
    .ina({Rsh_d1[25], Rsh_d0[25]}), .inb({Bn1[25], Bn0[25]}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({g1_25, g0_25}));
MSKand_opini2_d2_pini u_t_25 (
    .ina({fc1[25], fc0[25]}), .inb({p1_25, p0_25}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({t1_25, t0_25}));
assign fc0[26] = g0_25 ^ t0_25;
assign fc1[26] = g1_25 ^ t1_25;
wire p0_26 = Rsh_d0[26] ^ Bn0[26];
wire p1_26 = Rsh_d1[26] ^ Bn1[26];
wire g0_26, g1_26, t0_26, t1_26;
MSKand_opini2_d2_pini u_g_26 (
    .ina({Rsh_d1[26], Rsh_d0[26]}), .inb({Bn1[26], Bn0[26]}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({g1_26, g0_26}));
MSKand_opini2_d2_pini u_t_26 (
    .ina({fc1[26], fc0[26]}), .inb({p1_26, p0_26}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({t1_26, t0_26}));
assign fc0[27] = g0_26 ^ t0_26;
assign fc1[27] = g1_26 ^ t1_26;
wire p0_27 = Rsh_d0[27] ^ Bn0[27];
wire p1_27 = Rsh_d1[27] ^ Bn1[27];
wire g0_27, g1_27, t0_27, t1_27;
MSKand_opini2_d2_pini u_g_27 (
    .ina({Rsh_d1[27], Rsh_d0[27]}), .inb({Bn1[27], Bn0[27]}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({g1_27, g0_27}));
MSKand_opini2_d2_pini u_t_27 (
    .ina({fc1[27], fc0[27]}), .inb({p1_27, p0_27}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({t1_27, t0_27}));
assign fc0[28] = g0_27 ^ t0_27;
assign fc1[28] = g1_27 ^ t1_27;
wire p0_28 = Rsh_d0[28] ^ Bn0[28];
wire p1_28 = Rsh_d1[28] ^ Bn1[28];
wire g0_28, g1_28, t0_28, t1_28;
MSKand_opini2_d2_pini u_g_28 (
    .ina({Rsh_d1[28], Rsh_d0[28]}), .inb({Bn1[28], Bn0[28]}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({g1_28, g0_28}));
MSKand_opini2_d2_pini u_t_28 (
    .ina({fc1[28], fc0[28]}), .inb({p1_28, p0_28}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({t1_28, t0_28}));
assign fc0[29] = g0_28 ^ t0_28;
assign fc1[29] = g1_28 ^ t1_28;
wire p0_29 = Rsh_d0[29] ^ Bn0[29];
wire p1_29 = Rsh_d1[29] ^ Bn1[29];
wire g0_29, g1_29, t0_29, t1_29;
MSKand_opini2_d2_pini u_g_29 (
    .ina({Rsh_d1[29], Rsh_d0[29]}), .inb({Bn1[29], Bn0[29]}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({g1_29, g0_29}));
MSKand_opini2_d2_pini u_t_29 (
    .ina({fc1[29], fc0[29]}), .inb({p1_29, p0_29}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({t1_29, t0_29}));
assign fc0[30] = g0_29 ^ t0_29;
assign fc1[30] = g1_29 ^ t1_29;
wire p0_30 = Rsh_d0[30] ^ Bn0[30];
wire p1_30 = Rsh_d1[30] ^ Bn1[30];
wire g0_30, g1_30, t0_30, t1_30;
MSKand_opini2_d2_pini u_g_30 (
    .ina({Rsh_d1[30], Rsh_d0[30]}), .inb({Bn1[30], Bn0[30]}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({g1_30, g0_30}));
MSKand_opini2_d2_pini u_t_30 (
    .ina({fc1[30], fc0[30]}), .inb({p1_30, p0_30}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({t1_30, t0_30}));
assign fc0[31] = g0_30 ^ t0_30;
assign fc1[31] = g1_30 ^ t1_30;
wire p0_31 = Rsh_d0[31] ^ Bn0[31];
wire p1_31 = Rsh_d1[31] ^ Bn1[31];
wire g0_31, g1_31, t0_31, t1_31;
MSKand_opini2_d2_pini u_g_31 (
    .ina({Rsh_d1[31], Rsh_d0[31]}), .inb({Bn1[31], Bn0[31]}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({g1_31, g0_31}));
MSKand_opini2_d2_pini u_t_31 (
    .ina({fc1[31], fc0[31]}), .inb({p1_31, p0_31}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({t1_31, t0_31}));
assign fc0[32] = g0_31 ^ t0_31;
assign fc1[32] = g1_31 ^ t1_31;
wire p0_32 = Rsh_d0[32] ^ Bn0[32];
wire p1_32 = Rsh_d1[32] ^ Bn1[32];
wire g0_32, g1_32, t0_32, t1_32;
MSKand_opini2_d2_pini u_g_32 (
    .ina({Rsh_d1[32], Rsh_d0[32]}), .inb({Bn1[32], Bn0[32]}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({g1_32, g0_32}));
MSKand_opini2_d2_pini u_t_32 (
    .ina({fc1[32], fc0[32]}), .inb({p1_32, p0_32}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({t1_32, t0_32}));
assign fc0[33] = g0_32 ^ t0_32;
assign fc1[33] = g1_32 ^ t1_32;
wire p0_33 = Rsh_d0[33] ^ Bn0[33];
wire p1_33 = Rsh_d1[33] ^ Bn1[33];
wire g0_33, g1_33, t0_33, t1_33;
MSKand_opini2_d2_pini u_g_33 (
    .ina({Rsh_d1[33], Rsh_d0[33]}), .inb({Bn1[33], Bn0[33]}),
    .rnd(r[66]), .s(s[66]), .clk(clk), .out({g1_33, g0_33}));
MSKand_opini2_d2_pini u_t_33 (
    .ina({fc1[33], fc0[33]}), .inb({p1_33, p0_33}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({t1_33, t0_33}));
assign fc0[34] = g0_33 ^ t0_33;
assign fc1[34] = g1_33 ^ t1_33;
wire p0_34 = Rsh_d0[34] ^ Bn0[34];
wire p1_34 = Rsh_d1[34] ^ Bn1[34];
wire g0_34, g1_34, t0_34, t1_34;
MSKand_opini2_d2_pini u_g_34 (
    .ina({Rsh_d1[34], Rsh_d0[34]}), .inb({Bn1[34], Bn0[34]}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({g1_34, g0_34}));
MSKand_opini2_d2_pini u_t_34 (
    .ina({fc1[34], fc0[34]}), .inb({p1_34, p0_34}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({t1_34, t0_34}));
assign fc0[35] = g0_34 ^ t0_34;
assign fc1[35] = g1_34 ^ t1_34;
wire p0_35 = Rsh_d0[35] ^ Bn0[35];
wire p1_35 = Rsh_d1[35] ^ Bn1[35];
wire g0_35, g1_35, t0_35, t1_35;
MSKand_opini2_d2_pini u_g_35 (
    .ina({Rsh_d1[35], Rsh_d0[35]}), .inb({Bn1[35], Bn0[35]}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({g1_35, g0_35}));
MSKand_opini2_d2_pini u_t_35 (
    .ina({fc1[35], fc0[35]}), .inb({p1_35, p0_35}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({t1_35, t0_35}));
assign fc0[36] = g0_35 ^ t0_35;
assign fc1[36] = g1_35 ^ t1_35;
wire p0_36 = Rsh_d0[36] ^ Bn0[36];
wire p1_36 = Rsh_d1[36] ^ Bn1[36];
wire g0_36, g1_36, t0_36, t1_36;
MSKand_opini2_d2_pini u_g_36 (
    .ina({Rsh_d1[36], Rsh_d0[36]}), .inb({Bn1[36], Bn0[36]}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({g1_36, g0_36}));
MSKand_opini2_d2_pini u_t_36 (
    .ina({fc1[36], fc0[36]}), .inb({p1_36, p0_36}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({t1_36, t0_36}));
assign fc0[37] = g0_36 ^ t0_36;
assign fc1[37] = g1_36 ^ t1_36;
wire p0_37 = Rsh_d0[37] ^ Bn0[37];
wire p1_37 = Rsh_d1[37] ^ Bn1[37];
wire g0_37, g1_37, t0_37, t1_37;
MSKand_opini2_d2_pini u_g_37 (
    .ina({Rsh_d1[37], Rsh_d0[37]}), .inb({Bn1[37], Bn0[37]}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({g1_37, g0_37}));
MSKand_opini2_d2_pini u_t_37 (
    .ina({fc1[37], fc0[37]}), .inb({p1_37, p0_37}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({t1_37, t0_37}));
assign fc0[38] = g0_37 ^ t0_37;
assign fc1[38] = g1_37 ^ t1_37;
wire p0_38 = Rsh_d0[38] ^ Bn0[38];
wire p1_38 = Rsh_d1[38] ^ Bn1[38];
wire g0_38, g1_38, t0_38, t1_38;
MSKand_opini2_d2_pini u_g_38 (
    .ina({Rsh_d1[38], Rsh_d0[38]}), .inb({Bn1[38], Bn0[38]}),
    .rnd(r[76]), .s(s[76]), .clk(clk), .out({g1_38, g0_38}));
MSKand_opini2_d2_pini u_t_38 (
    .ina({fc1[38], fc0[38]}), .inb({p1_38, p0_38}),
    .rnd(r[77]), .s(s[77]), .clk(clk), .out({t1_38, t0_38}));
assign fc0[39] = g0_38 ^ t0_38;
assign fc1[39] = g1_38 ^ t1_38;
wire p0_39 = Rsh_d0[39] ^ Bn0[39];
wire p1_39 = Rsh_d1[39] ^ Bn1[39];
wire g0_39, g1_39, t0_39, t1_39;
MSKand_opini2_d2_pini u_g_39 (
    .ina({Rsh_d1[39], Rsh_d0[39]}), .inb({Bn1[39], Bn0[39]}),
    .rnd(r[78]), .s(s[78]), .clk(clk), .out({g1_39, g0_39}));
MSKand_opini2_d2_pini u_t_39 (
    .ina({fc1[39], fc0[39]}), .inb({p1_39, p0_39}),
    .rnd(r[79]), .s(s[79]), .clk(clk), .out({t1_39, t0_39}));
assign fc0[40] = g0_39 ^ t0_39;
assign fc1[40] = g1_39 ^ t1_39;
wire p0_40 = Rsh_d0[40] ^ Bn0[40];
wire p1_40 = Rsh_d1[40] ^ Bn1[40];
wire g0_40, g1_40, t0_40, t1_40;
MSKand_opini2_d2_pini u_g_40 (
    .ina({Rsh_d1[40], Rsh_d0[40]}), .inb({Bn1[40], Bn0[40]}),
    .rnd(r[80]), .s(s[80]), .clk(clk), .out({g1_40, g0_40}));
MSKand_opini2_d2_pini u_t_40 (
    .ina({fc1[40], fc0[40]}), .inb({p1_40, p0_40}),
    .rnd(r[81]), .s(s[81]), .clk(clk), .out({t1_40, t0_40}));
assign fc0[41] = g0_40 ^ t0_40;
assign fc1[41] = g1_40 ^ t1_40;
wire p0_41 = Rsh_d0[41] ^ Bn0[41];
wire p1_41 = Rsh_d1[41] ^ Bn1[41];
wire g0_41, g1_41, t0_41, t1_41;
MSKand_opini2_d2_pini u_g_41 (
    .ina({Rsh_d1[41], Rsh_d0[41]}), .inb({Bn1[41], Bn0[41]}),
    .rnd(r[82]), .s(s[82]), .clk(clk), .out({g1_41, g0_41}));
MSKand_opini2_d2_pini u_t_41 (
    .ina({fc1[41], fc0[41]}), .inb({p1_41, p0_41}),
    .rnd(r[83]), .s(s[83]), .clk(clk), .out({t1_41, t0_41}));
assign fc0[42] = g0_41 ^ t0_41;
assign fc1[42] = g1_41 ^ t1_41;
wire p0_42 = Rsh_d0[42] ^ Bn0[42];
wire p1_42 = Rsh_d1[42] ^ Bn1[42];
wire g0_42, g1_42, t0_42, t1_42;
MSKand_opini2_d2_pini u_g_42 (
    .ina({Rsh_d1[42], Rsh_d0[42]}), .inb({Bn1[42], Bn0[42]}),
    .rnd(r[84]), .s(s[84]), .clk(clk), .out({g1_42, g0_42}));
MSKand_opini2_d2_pini u_t_42 (
    .ina({fc1[42], fc0[42]}), .inb({p1_42, p0_42}),
    .rnd(r[85]), .s(s[85]), .clk(clk), .out({t1_42, t0_42}));
assign fc0[43] = g0_42 ^ t0_42;
assign fc1[43] = g1_42 ^ t1_42;
wire p0_43 = Rsh_d0[43] ^ Bn0[43];
wire p1_43 = Rsh_d1[43] ^ Bn1[43];
wire g0_43, g1_43, t0_43, t1_43;
MSKand_opini2_d2_pini u_g_43 (
    .ina({Rsh_d1[43], Rsh_d0[43]}), .inb({Bn1[43], Bn0[43]}),
    .rnd(r[86]), .s(s[86]), .clk(clk), .out({g1_43, g0_43}));
MSKand_opini2_d2_pini u_t_43 (
    .ina({fc1[43], fc0[43]}), .inb({p1_43, p0_43}),
    .rnd(r[87]), .s(s[87]), .clk(clk), .out({t1_43, t0_43}));
assign fc0[44] = g0_43 ^ t0_43;
assign fc1[44] = g1_43 ^ t1_43;
wire p0_44 = Rsh_d0[44] ^ Bn0[44];
wire p1_44 = Rsh_d1[44] ^ Bn1[44];
wire g0_44, g1_44, t0_44, t1_44;
MSKand_opini2_d2_pini u_g_44 (
    .ina({Rsh_d1[44], Rsh_d0[44]}), .inb({Bn1[44], Bn0[44]}),
    .rnd(r[88]), .s(s[88]), .clk(clk), .out({g1_44, g0_44}));
MSKand_opini2_d2_pini u_t_44 (
    .ina({fc1[44], fc0[44]}), .inb({p1_44, p0_44}),
    .rnd(r[89]), .s(s[89]), .clk(clk), .out({t1_44, t0_44}));
assign fc0[45] = g0_44 ^ t0_44;
assign fc1[45] = g1_44 ^ t1_44;
wire p0_45 = Rsh_d0[45] ^ Bn0[45];
wire p1_45 = Rsh_d1[45] ^ Bn1[45];
wire g0_45, g1_45, t0_45, t1_45;
MSKand_opini2_d2_pini u_g_45 (
    .ina({Rsh_d1[45], Rsh_d0[45]}), .inb({Bn1[45], Bn0[45]}),
    .rnd(r[90]), .s(s[90]), .clk(clk), .out({g1_45, g0_45}));
MSKand_opini2_d2_pini u_t_45 (
    .ina({fc1[45], fc0[45]}), .inb({p1_45, p0_45}),
    .rnd(r[91]), .s(s[91]), .clk(clk), .out({t1_45, t0_45}));
assign fc0[46] = g0_45 ^ t0_45;
assign fc1[46] = g1_45 ^ t1_45;
wire p0_46 = Rsh_d0[46] ^ Bn0[46];
wire p1_46 = Rsh_d1[46] ^ Bn1[46];
wire g0_46, g1_46, t0_46, t1_46;
MSKand_opini2_d2_pini u_g_46 (
    .ina({Rsh_d1[46], Rsh_d0[46]}), .inb({Bn1[46], Bn0[46]}),
    .rnd(r[92]), .s(s[92]), .clk(clk), .out({g1_46, g0_46}));
MSKand_opini2_d2_pini u_t_46 (
    .ina({fc1[46], fc0[46]}), .inb({p1_46, p0_46}),
    .rnd(r[93]), .s(s[93]), .clk(clk), .out({t1_46, t0_46}));
assign fc0[47] = g0_46 ^ t0_46;
assign fc1[47] = g1_46 ^ t1_46;
wire p0_47 = Rsh_d0[47] ^ Bn0[47];
wire p1_47 = Rsh_d1[47] ^ Bn1[47];
wire g0_47, g1_47, t0_47, t1_47;
MSKand_opini2_d2_pini u_g_47 (
    .ina({Rsh_d1[47], Rsh_d0[47]}), .inb({Bn1[47], Bn0[47]}),
    .rnd(r[94]), .s(s[94]), .clk(clk), .out({g1_47, g0_47}));
MSKand_opini2_d2_pini u_t_47 (
    .ina({fc1[47], fc0[47]}), .inb({p1_47, p0_47}),
    .rnd(r[95]), .s(s[95]), .clk(clk), .out({t1_47, t0_47}));
assign fc0[48] = g0_47 ^ t0_47;
assign fc1[48] = g1_47 ^ t1_47;
wire p0_48 = Rsh_d0[48] ^ Bn0[48];
wire p1_48 = Rsh_d1[48] ^ Bn1[48];
wire g0_48, g1_48, t0_48, t1_48;
MSKand_opini2_d2_pini u_g_48 (
    .ina({Rsh_d1[48], Rsh_d0[48]}), .inb({Bn1[48], Bn0[48]}),
    .rnd(r[96]), .s(s[96]), .clk(clk), .out({g1_48, g0_48}));
MSKand_opini2_d2_pini u_t_48 (
    .ina({fc1[48], fc0[48]}), .inb({p1_48, p0_48}),
    .rnd(r[97]), .s(s[97]), .clk(clk), .out({t1_48, t0_48}));
assign fc0[49] = g0_48 ^ t0_48;
assign fc1[49] = g1_48 ^ t1_48;
wire p0_49 = Rsh_d0[49] ^ Bn0[49];
wire p1_49 = Rsh_d1[49] ^ Bn1[49];
wire g0_49, g1_49, t0_49, t1_49;
MSKand_opini2_d2_pini u_g_49 (
    .ina({Rsh_d1[49], Rsh_d0[49]}), .inb({Bn1[49], Bn0[49]}),
    .rnd(r[98]), .s(s[98]), .clk(clk), .out({g1_49, g0_49}));
MSKand_opini2_d2_pini u_t_49 (
    .ina({fc1[49], fc0[49]}), .inb({p1_49, p0_49}),
    .rnd(r[99]), .s(s[99]), .clk(clk), .out({t1_49, t0_49}));
assign fc0[50] = g0_49 ^ t0_49;
assign fc1[50] = g1_49 ^ t1_49;
wire p0_50 = Rsh_d0[50] ^ Bn0[50];
wire p1_50 = Rsh_d1[50] ^ Bn1[50];
wire g0_50, g1_50, t0_50, t1_50;
MSKand_opini2_d2_pini u_g_50 (
    .ina({Rsh_d1[50], Rsh_d0[50]}), .inb({Bn1[50], Bn0[50]}),
    .rnd(r[100]), .s(s[100]), .clk(clk), .out({g1_50, g0_50}));
MSKand_opini2_d2_pini u_t_50 (
    .ina({fc1[50], fc0[50]}), .inb({p1_50, p0_50}),
    .rnd(r[101]), .s(s[101]), .clk(clk), .out({t1_50, t0_50}));
assign fc0[51] = g0_50 ^ t0_50;
assign fc1[51] = g1_50 ^ t1_50;
wire p0_51 = Rsh_d0[51] ^ Bn0[51];
wire p1_51 = Rsh_d1[51] ^ Bn1[51];
wire g0_51, g1_51, t0_51, t1_51;
MSKand_opini2_d2_pini u_g_51 (
    .ina({Rsh_d1[51], Rsh_d0[51]}), .inb({Bn1[51], Bn0[51]}),
    .rnd(r[102]), .s(s[102]), .clk(clk), .out({g1_51, g0_51}));
MSKand_opini2_d2_pini u_t_51 (
    .ina({fc1[51], fc0[51]}), .inb({p1_51, p0_51}),
    .rnd(r[103]), .s(s[103]), .clk(clk), .out({t1_51, t0_51}));
assign fc0[52] = g0_51 ^ t0_51;
assign fc1[52] = g1_51 ^ t1_51;
wire p0_52 = Rsh_d0[52] ^ Bn0[52];
wire p1_52 = Rsh_d1[52] ^ Bn1[52];
wire g0_52, g1_52, t0_52, t1_52;
MSKand_opini2_d2_pini u_g_52 (
    .ina({Rsh_d1[52], Rsh_d0[52]}), .inb({Bn1[52], Bn0[52]}),
    .rnd(r[104]), .s(s[104]), .clk(clk), .out({g1_52, g0_52}));
MSKand_opini2_d2_pini u_t_52 (
    .ina({fc1[52], fc0[52]}), .inb({p1_52, p0_52}),
    .rnd(r[105]), .s(s[105]), .clk(clk), .out({t1_52, t0_52}));
assign fc0[53] = g0_52 ^ t0_52;
assign fc1[53] = g1_52 ^ t1_52;
wire p0_53 = Rsh_d0[53] ^ Bn0[53];
wire p1_53 = Rsh_d1[53] ^ Bn1[53];
wire g0_53, g1_53, t0_53, t1_53;
MSKand_opini2_d2_pini u_g_53 (
    .ina({Rsh_d1[53], Rsh_d0[53]}), .inb({Bn1[53], Bn0[53]}),
    .rnd(r[106]), .s(s[106]), .clk(clk), .out({g1_53, g0_53}));
MSKand_opini2_d2_pini u_t_53 (
    .ina({fc1[53], fc0[53]}), .inb({p1_53, p0_53}),
    .rnd(r[107]), .s(s[107]), .clk(clk), .out({t1_53, t0_53}));
assign fc0[54] = g0_53 ^ t0_53;
assign fc1[54] = g1_53 ^ t1_53;
wire p0_54 = Rsh_d0[54] ^ Bn0[54];
wire p1_54 = Rsh_d1[54] ^ Bn1[54];
wire g0_54, g1_54, t0_54, t1_54;
MSKand_opini2_d2_pini u_g_54 (
    .ina({Rsh_d1[54], Rsh_d0[54]}), .inb({Bn1[54], Bn0[54]}),
    .rnd(r[108]), .s(s[108]), .clk(clk), .out({g1_54, g0_54}));
MSKand_opini2_d2_pini u_t_54 (
    .ina({fc1[54], fc0[54]}), .inb({p1_54, p0_54}),
    .rnd(r[109]), .s(s[109]), .clk(clk), .out({t1_54, t0_54}));
assign fc0[55] = g0_54 ^ t0_54;
assign fc1[55] = g1_54 ^ t1_54;
wire p0_55 = Rsh_d0[55] ^ Bn0[55];
wire p1_55 = Rsh_d1[55] ^ Bn1[55];
wire g0_55, g1_55, t0_55, t1_55;
MSKand_opini2_d2_pini u_g_55 (
    .ina({Rsh_d1[55], Rsh_d0[55]}), .inb({Bn1[55], Bn0[55]}),
    .rnd(r[110]), .s(s[110]), .clk(clk), .out({g1_55, g0_55}));
MSKand_opini2_d2_pini u_t_55 (
    .ina({fc1[55], fc0[55]}), .inb({p1_55, p0_55}),
    .rnd(r[111]), .s(s[111]), .clk(clk), .out({t1_55, t0_55}));
assign fc0[56] = g0_55 ^ t0_55;
assign fc1[56] = g1_55 ^ t1_55;
wire p0_56 = Rsh_d0[56] ^ Bn0[56];
wire p1_56 = Rsh_d1[56] ^ Bn1[56];
wire g0_56, g1_56, t0_56, t1_56;
MSKand_opini2_d2_pini u_g_56 (
    .ina({Rsh_d1[56], Rsh_d0[56]}), .inb({Bn1[56], Bn0[56]}),
    .rnd(r[112]), .s(s[112]), .clk(clk), .out({g1_56, g0_56}));
MSKand_opini2_d2_pini u_t_56 (
    .ina({fc1[56], fc0[56]}), .inb({p1_56, p0_56}),
    .rnd(r[113]), .s(s[113]), .clk(clk), .out({t1_56, t0_56}));
assign fc0[57] = g0_56 ^ t0_56;
assign fc1[57] = g1_56 ^ t1_56;
wire p0_57 = Rsh_d0[57] ^ Bn0[57];
wire p1_57 = Rsh_d1[57] ^ Bn1[57];
wire g0_57, g1_57, t0_57, t1_57;
MSKand_opini2_d2_pini u_g_57 (
    .ina({Rsh_d1[57], Rsh_d0[57]}), .inb({Bn1[57], Bn0[57]}),
    .rnd(r[114]), .s(s[114]), .clk(clk), .out({g1_57, g0_57}));
MSKand_opini2_d2_pini u_t_57 (
    .ina({fc1[57], fc0[57]}), .inb({p1_57, p0_57}),
    .rnd(r[115]), .s(s[115]), .clk(clk), .out({t1_57, t0_57}));
assign fc0[58] = g0_57 ^ t0_57;
assign fc1[58] = g1_57 ^ t1_57;
wire p0_58 = Rsh_d0[58] ^ Bn0[58];
wire p1_58 = Rsh_d1[58] ^ Bn1[58];
wire g0_58, g1_58, t0_58, t1_58;
MSKand_opini2_d2_pini u_g_58 (
    .ina({Rsh_d1[58], Rsh_d0[58]}), .inb({Bn1[58], Bn0[58]}),
    .rnd(r[116]), .s(s[116]), .clk(clk), .out({g1_58, g0_58}));
MSKand_opini2_d2_pini u_t_58 (
    .ina({fc1[58], fc0[58]}), .inb({p1_58, p0_58}),
    .rnd(r[117]), .s(s[117]), .clk(clk), .out({t1_58, t0_58}));
assign fc0[59] = g0_58 ^ t0_58;
assign fc1[59] = g1_58 ^ t1_58;
wire p0_59 = Rsh_d0[59] ^ Bn0[59];
wire p1_59 = Rsh_d1[59] ^ Bn1[59];
wire g0_59, g1_59, t0_59, t1_59;
MSKand_opini2_d2_pini u_g_59 (
    .ina({Rsh_d1[59], Rsh_d0[59]}), .inb({Bn1[59], Bn0[59]}),
    .rnd(r[118]), .s(s[118]), .clk(clk), .out({g1_59, g0_59}));
MSKand_opini2_d2_pini u_t_59 (
    .ina({fc1[59], fc0[59]}), .inb({p1_59, p0_59}),
    .rnd(r[119]), .s(s[119]), .clk(clk), .out({t1_59, t0_59}));
assign fc0[60] = g0_59 ^ t0_59;
assign fc1[60] = g1_59 ^ t1_59;
wire p0_60 = Rsh_d0[60] ^ Bn0[60];
wire p1_60 = Rsh_d1[60] ^ Bn1[60];
wire g0_60, g1_60, t0_60, t1_60;
MSKand_opini2_d2_pini u_g_60 (
    .ina({Rsh_d1[60], Rsh_d0[60]}), .inb({Bn1[60], Bn0[60]}),
    .rnd(r[120]), .s(s[120]), .clk(clk), .out({g1_60, g0_60}));
MSKand_opini2_d2_pini u_t_60 (
    .ina({fc1[60], fc0[60]}), .inb({p1_60, p0_60}),
    .rnd(r[121]), .s(s[121]), .clk(clk), .out({t1_60, t0_60}));
assign fc0[61] = g0_60 ^ t0_60;
assign fc1[61] = g1_60 ^ t1_60;
wire p0_61 = Rsh_d0[61] ^ Bn0[61];
wire p1_61 = Rsh_d1[61] ^ Bn1[61];
wire g0_61, g1_61, t0_61, t1_61;
MSKand_opini2_d2_pini u_g_61 (
    .ina({Rsh_d1[61], Rsh_d0[61]}), .inb({Bn1[61], Bn0[61]}),
    .rnd(r[122]), .s(s[122]), .clk(clk), .out({g1_61, g0_61}));
MSKand_opini2_d2_pini u_t_61 (
    .ina({fc1[61], fc0[61]}), .inb({p1_61, p0_61}),
    .rnd(r[123]), .s(s[123]), .clk(clk), .out({t1_61, t0_61}));
assign fc0[62] = g0_61 ^ t0_61;
assign fc1[62] = g1_61 ^ t1_61;
wire p0_62 = Rsh_d0[62] ^ Bn0[62];
wire p1_62 = Rsh_d1[62] ^ Bn1[62];
wire g0_62, g1_62, t0_62, t1_62;
MSKand_opini2_d2_pini u_g_62 (
    .ina({Rsh_d1[62], Rsh_d0[62]}), .inb({Bn1[62], Bn0[62]}),
    .rnd(r[124]), .s(s[124]), .clk(clk), .out({g1_62, g0_62}));
MSKand_opini2_d2_pini u_t_62 (
    .ina({fc1[62], fc0[62]}), .inb({p1_62, p0_62}),
    .rnd(r[125]), .s(s[125]), .clk(clk), .out({t1_62, t0_62}));
assign fc0[63] = g0_62 ^ t0_62;
assign fc1[63] = g1_62 ^ t1_62;
wire p0_63 = Rsh_d0[63] ^ Bn0[63];
wire p1_63 = Rsh_d1[63] ^ Bn1[63];
wire g0_63, g1_63, t0_63, t1_63;
MSKand_opini2_d2_pini u_g_63 (
    .ina({Rsh_d1[63], Rsh_d0[63]}), .inb({Bn1[63], Bn0[63]}),
    .rnd(r[126]), .s(s[126]), .clk(clk), .out({g1_63, g0_63}));
MSKand_opini2_d2_pini u_t_63 (
    .ina({fc1[63], fc0[63]}), .inb({p1_63, p0_63}),
    .rnd(r[127]), .s(s[127]), .clk(clk), .out({t1_63, t0_63}));
assign fc0[64] = g0_63 ^ t0_63;
assign fc1[64] = g1_63 ^ t1_63;
wire p0_64 = Rsh_d0[64] ^ Bn0[64];
wire p1_64 = Rsh_d1[64] ^ Bn1[64];
wire g0_64, g1_64, t0_64, t1_64;
MSKand_opini2_d2_pini u_g_64 (
    .ina({Rsh_d1[64], Rsh_d0[64]}), .inb({Bn1[64], Bn0[64]}),
    .rnd(r[128]), .s(s[128]), .clk(clk), .out({g1_64, g0_64}));
MSKand_opini2_d2_pini u_t_64 (
    .ina({fc1[64], fc0[64]}), .inb({p1_64, p0_64}),
    .rnd(r[129]), .s(s[129]), .clk(clk), .out({t1_64, t0_64}));
assign fc0[65] = g0_64 ^ t0_64;
assign fc1[65] = g1_64 ^ t1_64;
wire p0_65 = Rsh_d0[65] ^ Bn0[65];
wire p1_65 = Rsh_d1[65] ^ Bn1[65];
wire g0_65, g1_65, t0_65, t1_65;
MSKand_opini2_d2_pini u_g_65 (
    .ina({Rsh_d1[65], Rsh_d0[65]}), .inb({Bn1[65], Bn0[65]}),
    .rnd(r[130]), .s(s[130]), .clk(clk), .out({g1_65, g0_65}));
MSKand_opini2_d2_pini u_t_65 (
    .ina({fc1[65], fc0[65]}), .inb({p1_65, p0_65}),
    .rnd(r[131]), .s(s[131]), .clk(clk), .out({t1_65, t0_65}));
assign fc0[66] = g0_65 ^ t0_65;
assign fc1[66] = g1_65 ^ t1_65;
wire p0_66 = Rsh_d0[66] ^ Bn0[66];
wire p1_66 = Rsh_d1[66] ^ Bn1[66];
wire g0_66, g1_66, t0_66, t1_66;
MSKand_opini2_d2_pini u_g_66 (
    .ina({Rsh_d1[66], Rsh_d0[66]}), .inb({Bn1[66], Bn0[66]}),
    .rnd(r[132]), .s(s[132]), .clk(clk), .out({g1_66, g0_66}));
MSKand_opini2_d2_pini u_t_66 (
    .ina({fc1[66], fc0[66]}), .inb({p1_66, p0_66}),
    .rnd(r[133]), .s(s[133]), .clk(clk), .out({t1_66, t0_66}));
assign fc0[67] = g0_66 ^ t0_66;
assign fc1[67] = g1_66 ^ t1_66;
wire p0_67 = Rsh_d0[67] ^ Bn0[67];
wire p1_67 = Rsh_d1[67] ^ Bn1[67];
wire g0_67, g1_67, t0_67, t1_67;
MSKand_opini2_d2_pini u_g_67 (
    .ina({Rsh_d1[67], Rsh_d0[67]}), .inb({Bn1[67], Bn0[67]}),
    .rnd(r[134]), .s(s[134]), .clk(clk), .out({g1_67, g0_67}));
MSKand_opini2_d2_pini u_t_67 (
    .ina({fc1[67], fc0[67]}), .inb({p1_67, p0_67}),
    .rnd(r[135]), .s(s[135]), .clk(clk), .out({t1_67, t0_67}));
assign fc0[68] = g0_67 ^ t0_67;
assign fc1[68] = g1_67 ^ t1_67;
wire p0_68 = Rsh_d0[68] ^ Bn0[68];
wire p1_68 = Rsh_d1[68] ^ Bn1[68];
wire g0_68, g1_68, t0_68, t1_68;
MSKand_opini2_d2_pini u_g_68 (
    .ina({Rsh_d1[68], Rsh_d0[68]}), .inb({Bn1[68], Bn0[68]}),
    .rnd(r[136]), .s(s[136]), .clk(clk), .out({g1_68, g0_68}));
MSKand_opini2_d2_pini u_t_68 (
    .ina({fc1[68], fc0[68]}), .inb({p1_68, p0_68}),
    .rnd(r[137]), .s(s[137]), .clk(clk), .out({t1_68, t0_68}));
assign fc0[69] = g0_68 ^ t0_68;
assign fc1[69] = g1_68 ^ t1_68;
wire p0_69 = Rsh_d0[69] ^ Bn0[69];
wire p1_69 = Rsh_d1[69] ^ Bn1[69];
wire g0_69, g1_69, t0_69, t1_69;
MSKand_opini2_d2_pini u_g_69 (
    .ina({Rsh_d1[69], Rsh_d0[69]}), .inb({Bn1[69], Bn0[69]}),
    .rnd(r[138]), .s(s[138]), .clk(clk), .out({g1_69, g0_69}));
MSKand_opini2_d2_pini u_t_69 (
    .ina({fc1[69], fc0[69]}), .inb({p1_69, p0_69}),
    .rnd(r[139]), .s(s[139]), .clk(clk), .out({t1_69, t0_69}));
assign fc0[70] = g0_69 ^ t0_69;
assign fc1[70] = g1_69 ^ t1_69;
wire p0_70 = Rsh_d0[70] ^ Bn0[70];
wire p1_70 = Rsh_d1[70] ^ Bn1[70];
wire g0_70, g1_70, t0_70, t1_70;
MSKand_opini2_d2_pini u_g_70 (
    .ina({Rsh_d1[70], Rsh_d0[70]}), .inb({Bn1[70], Bn0[70]}),
    .rnd(r[140]), .s(s[140]), .clk(clk), .out({g1_70, g0_70}));
MSKand_opini2_d2_pini u_t_70 (
    .ina({fc1[70], fc0[70]}), .inb({p1_70, p0_70}),
    .rnd(r[141]), .s(s[141]), .clk(clk), .out({t1_70, t0_70}));
assign fc0[71] = g0_70 ^ t0_70;
assign fc1[71] = g1_70 ^ t1_70;
wire p0_71 = Rsh_d0[71] ^ Bn0[71];
wire p1_71 = Rsh_d1[71] ^ Bn1[71];
wire g0_71, g1_71, t0_71, t1_71;
MSKand_opini2_d2_pini u_g_71 (
    .ina({Rsh_d1[71], Rsh_d0[71]}), .inb({Bn1[71], Bn0[71]}),
    .rnd(r[142]), .s(s[142]), .clk(clk), .out({g1_71, g0_71}));
MSKand_opini2_d2_pini u_t_71 (
    .ina({fc1[71], fc0[71]}), .inb({p1_71, p0_71}),
    .rnd(r[143]), .s(s[143]), .clk(clk), .out({t1_71, t0_71}));
assign fc0[72] = g0_71 ^ t0_71;
assign fc1[72] = g1_71 ^ t1_71;
wire p0_72 = Rsh_d0[72] ^ Bn0[72];
wire p1_72 = Rsh_d1[72] ^ Bn1[72];
wire g0_72, g1_72, t0_72, t1_72;
MSKand_opini2_d2_pini u_g_72 (
    .ina({Rsh_d1[72], Rsh_d0[72]}), .inb({Bn1[72], Bn0[72]}),
    .rnd(r[144]), .s(s[144]), .clk(clk), .out({g1_72, g0_72}));
MSKand_opini2_d2_pini u_t_72 (
    .ina({fc1[72], fc0[72]}), .inb({p1_72, p0_72}),
    .rnd(r[145]), .s(s[145]), .clk(clk), .out({t1_72, t0_72}));
assign fc0[73] = g0_72 ^ t0_72;
assign fc1[73] = g1_72 ^ t1_72;
wire p0_73 = Rsh_d0[73] ^ Bn0[73];
wire p1_73 = Rsh_d1[73] ^ Bn1[73];
wire g0_73, g1_73, t0_73, t1_73;
MSKand_opini2_d2_pini u_g_73 (
    .ina({Rsh_d1[73], Rsh_d0[73]}), .inb({Bn1[73], Bn0[73]}),
    .rnd(r[146]), .s(s[146]), .clk(clk), .out({g1_73, g0_73}));
MSKand_opini2_d2_pini u_t_73 (
    .ina({fc1[73], fc0[73]}), .inb({p1_73, p0_73}),
    .rnd(r[147]), .s(s[147]), .clk(clk), .out({t1_73, t0_73}));
assign fc0[74] = g0_73 ^ t0_73;
assign fc1[74] = g1_73 ^ t1_73;
wire p0_74 = Rsh_d0[74] ^ Bn0[74];
wire p1_74 = Rsh_d1[74] ^ Bn1[74];
wire g0_74, g1_74, t0_74, t1_74;
MSKand_opini2_d2_pini u_g_74 (
    .ina({Rsh_d1[74], Rsh_d0[74]}), .inb({Bn1[74], Bn0[74]}),
    .rnd(r[148]), .s(s[148]), .clk(clk), .out({g1_74, g0_74}));
MSKand_opini2_d2_pini u_t_74 (
    .ina({fc1[74], fc0[74]}), .inb({p1_74, p0_74}),
    .rnd(r[149]), .s(s[149]), .clk(clk), .out({t1_74, t0_74}));
assign fc0[75] = g0_74 ^ t0_74;
assign fc1[75] = g1_74 ^ t1_74;
wire p0_75 = Rsh_d0[75] ^ Bn0[75];
wire p1_75 = Rsh_d1[75] ^ Bn1[75];
wire g0_75, g1_75, t0_75, t1_75;
MSKand_opini2_d2_pini u_g_75 (
    .ina({Rsh_d1[75], Rsh_d0[75]}), .inb({Bn1[75], Bn0[75]}),
    .rnd(r[150]), .s(s[150]), .clk(clk), .out({g1_75, g0_75}));
MSKand_opini2_d2_pini u_t_75 (
    .ina({fc1[75], fc0[75]}), .inb({p1_75, p0_75}),
    .rnd(r[151]), .s(s[151]), .clk(clk), .out({t1_75, t0_75}));
assign fc0[76] = g0_75 ^ t0_75;
assign fc1[76] = g1_75 ^ t1_75;
wire p0_76 = Rsh_d0[76] ^ Bn0[76];
wire p1_76 = Rsh_d1[76] ^ Bn1[76];
wire g0_76, g1_76, t0_76, t1_76;
MSKand_opini2_d2_pini u_g_76 (
    .ina({Rsh_d1[76], Rsh_d0[76]}), .inb({Bn1[76], Bn0[76]}),
    .rnd(r[152]), .s(s[152]), .clk(clk), .out({g1_76, g0_76}));
MSKand_opini2_d2_pini u_t_76 (
    .ina({fc1[76], fc0[76]}), .inb({p1_76, p0_76}),
    .rnd(r[153]), .s(s[153]), .clk(clk), .out({t1_76, t0_76}));
assign fc0[77] = g0_76 ^ t0_76;
assign fc1[77] = g1_76 ^ t1_76;
wire p0_77 = Rsh_d0[77] ^ Bn0[77];
wire p1_77 = Rsh_d1[77] ^ Bn1[77];
wire g0_77, g1_77, t0_77, t1_77;
MSKand_opini2_d2_pini u_g_77 (
    .ina({Rsh_d1[77], Rsh_d0[77]}), .inb({Bn1[77], Bn0[77]}),
    .rnd(r[154]), .s(s[154]), .clk(clk), .out({g1_77, g0_77}));
MSKand_opini2_d2_pini u_t_77 (
    .ina({fc1[77], fc0[77]}), .inb({p1_77, p0_77}),
    .rnd(r[155]), .s(s[155]), .clk(clk), .out({t1_77, t0_77}));
assign fc0[78] = g0_77 ^ t0_77;
assign fc1[78] = g1_77 ^ t1_77;
wire p0_78 = Rsh_d0[78] ^ Bn0[78];
wire p1_78 = Rsh_d1[78] ^ Bn1[78];
wire g0_78, g1_78, t0_78, t1_78;
MSKand_opini2_d2_pini u_g_78 (
    .ina({Rsh_d1[78], Rsh_d0[78]}), .inb({Bn1[78], Bn0[78]}),
    .rnd(r[156]), .s(s[156]), .clk(clk), .out({g1_78, g0_78}));
MSKand_opini2_d2_pini u_t_78 (
    .ina({fc1[78], fc0[78]}), .inb({p1_78, p0_78}),
    .rnd(r[157]), .s(s[157]), .clk(clk), .out({t1_78, t0_78}));
assign fc0[79] = g0_78 ^ t0_78;
assign fc1[79] = g1_78 ^ t1_78;
wire p0_79 = Rsh_d0[79] ^ Bn0[79];
wire p1_79 = Rsh_d1[79] ^ Bn1[79];
wire g0_79, g1_79, t0_79, t1_79;
MSKand_opini2_d2_pini u_g_79 (
    .ina({Rsh_d1[79], Rsh_d0[79]}), .inb({Bn1[79], Bn0[79]}),
    .rnd(r[158]), .s(s[158]), .clk(clk), .out({g1_79, g0_79}));
MSKand_opini2_d2_pini u_t_79 (
    .ina({fc1[79], fc0[79]}), .inb({p1_79, p0_79}),
    .rnd(r[159]), .s(s[159]), .clk(clk), .out({t1_79, t0_79}));
assign fc0[80] = g0_79 ^ t0_79;
assign fc1[80] = g1_79 ^ t1_79;
wire p0_80 = Rsh_d0[80] ^ Bn0[80];
wire p1_80 = Rsh_d1[80] ^ Bn1[80];
wire g0_80, g1_80, t0_80, t1_80;
MSKand_opini2_d2_pini u_g_80 (
    .ina({Rsh_d1[80], Rsh_d0[80]}), .inb({Bn1[80], Bn0[80]}),
    .rnd(r[160]), .s(s[160]), .clk(clk), .out({g1_80, g0_80}));
MSKand_opini2_d2_pini u_t_80 (
    .ina({fc1[80], fc0[80]}), .inb({p1_80, p0_80}),
    .rnd(r[161]), .s(s[161]), .clk(clk), .out({t1_80, t0_80}));
assign fc0[81] = g0_80 ^ t0_80;
assign fc1[81] = g1_80 ^ t1_80;
wire p0_81 = Rsh_d0[81] ^ Bn0[81];
wire p1_81 = Rsh_d1[81] ^ Bn1[81];
wire g0_81, g1_81, t0_81, t1_81;
MSKand_opini2_d2_pini u_g_81 (
    .ina({Rsh_d1[81], Rsh_d0[81]}), .inb({Bn1[81], Bn0[81]}),
    .rnd(r[162]), .s(s[162]), .clk(clk), .out({g1_81, g0_81}));
MSKand_opini2_d2_pini u_t_81 (
    .ina({fc1[81], fc0[81]}), .inb({p1_81, p0_81}),
    .rnd(r[163]), .s(s[163]), .clk(clk), .out({t1_81, t0_81}));
assign fc0[82] = g0_81 ^ t0_81;
assign fc1[82] = g1_81 ^ t1_81;
wire p0_82 = Rsh_d0[82] ^ Bn0[82];
wire p1_82 = Rsh_d1[82] ^ Bn1[82];
wire g0_82, g1_82, t0_82, t1_82;
MSKand_opini2_d2_pini u_g_82 (
    .ina({Rsh_d1[82], Rsh_d0[82]}), .inb({Bn1[82], Bn0[82]}),
    .rnd(r[164]), .s(s[164]), .clk(clk), .out({g1_82, g0_82}));
MSKand_opini2_d2_pini u_t_82 (
    .ina({fc1[82], fc0[82]}), .inb({p1_82, p0_82}),
    .rnd(r[165]), .s(s[165]), .clk(clk), .out({t1_82, t0_82}));
assign fc0[83] = g0_82 ^ t0_82;
assign fc1[83] = g1_82 ^ t1_82;
wire p0_83 = Rsh_d0[83] ^ Bn0[83];
wire p1_83 = Rsh_d1[83] ^ Bn1[83];
wire g0_83, g1_83, t0_83, t1_83;
MSKand_opini2_d2_pini u_g_83 (
    .ina({Rsh_d1[83], Rsh_d0[83]}), .inb({Bn1[83], Bn0[83]}),
    .rnd(r[166]), .s(s[166]), .clk(clk), .out({g1_83, g0_83}));
MSKand_opini2_d2_pini u_t_83 (
    .ina({fc1[83], fc0[83]}), .inb({p1_83, p0_83}),
    .rnd(r[167]), .s(s[167]), .clk(clk), .out({t1_83, t0_83}));
assign fc0[84] = g0_83 ^ t0_83;
assign fc1[84] = g1_83 ^ t1_83;
wire p0_84 = Rsh_d0[84] ^ Bn0[84];
wire p1_84 = Rsh_d1[84] ^ Bn1[84];
wire g0_84, g1_84, t0_84, t1_84;
MSKand_opini2_d2_pini u_g_84 (
    .ina({Rsh_d1[84], Rsh_d0[84]}), .inb({Bn1[84], Bn0[84]}),
    .rnd(r[168]), .s(s[168]), .clk(clk), .out({g1_84, g0_84}));
MSKand_opini2_d2_pini u_t_84 (
    .ina({fc1[84], fc0[84]}), .inb({p1_84, p0_84}),
    .rnd(r[169]), .s(s[169]), .clk(clk), .out({t1_84, t0_84}));
assign fc0[85] = g0_84 ^ t0_84;
assign fc1[85] = g1_84 ^ t1_84;
wire p0_85 = Rsh_d0[85] ^ Bn0[85];
wire p1_85 = Rsh_d1[85] ^ Bn1[85];
wire g0_85, g1_85, t0_85, t1_85;
MSKand_opini2_d2_pini u_g_85 (
    .ina({Rsh_d1[85], Rsh_d0[85]}), .inb({Bn1[85], Bn0[85]}),
    .rnd(r[170]), .s(s[170]), .clk(clk), .out({g1_85, g0_85}));
MSKand_opini2_d2_pini u_t_85 (
    .ina({fc1[85], fc0[85]}), .inb({p1_85, p0_85}),
    .rnd(r[171]), .s(s[171]), .clk(clk), .out({t1_85, t0_85}));
assign fc0[86] = g0_85 ^ t0_85;
assign fc1[86] = g1_85 ^ t1_85;
wire p0_86 = Rsh_d0[86] ^ Bn0[86];
wire p1_86 = Rsh_d1[86] ^ Bn1[86];
wire g0_86, g1_86, t0_86, t1_86;
MSKand_opini2_d2_pini u_g_86 (
    .ina({Rsh_d1[86], Rsh_d0[86]}), .inb({Bn1[86], Bn0[86]}),
    .rnd(r[172]), .s(s[172]), .clk(clk), .out({g1_86, g0_86}));
MSKand_opini2_d2_pini u_t_86 (
    .ina({fc1[86], fc0[86]}), .inb({p1_86, p0_86}),
    .rnd(r[173]), .s(s[173]), .clk(clk), .out({t1_86, t0_86}));
assign fc0[87] = g0_86 ^ t0_86;
assign fc1[87] = g1_86 ^ t1_86;
wire p0_87 = Rsh_d0[87] ^ Bn0[87];
wire p1_87 = Rsh_d1[87] ^ Bn1[87];
wire g0_87, g1_87, t0_87, t1_87;
MSKand_opini2_d2_pini u_g_87 (
    .ina({Rsh_d1[87], Rsh_d0[87]}), .inb({Bn1[87], Bn0[87]}),
    .rnd(r[174]), .s(s[174]), .clk(clk), .out({g1_87, g0_87}));
MSKand_opini2_d2_pini u_t_87 (
    .ina({fc1[87], fc0[87]}), .inb({p1_87, p0_87}),
    .rnd(r[175]), .s(s[175]), .clk(clk), .out({t1_87, t0_87}));
assign fc0[88] = g0_87 ^ t0_87;
assign fc1[88] = g1_87 ^ t1_87;
wire p0_88 = Rsh_d0[88] ^ Bn0[88];
wire p1_88 = Rsh_d1[88] ^ Bn1[88];
wire g0_88, g1_88, t0_88, t1_88;
MSKand_opini2_d2_pini u_g_88 (
    .ina({Rsh_d1[88], Rsh_d0[88]}), .inb({Bn1[88], Bn0[88]}),
    .rnd(r[176]), .s(s[176]), .clk(clk), .out({g1_88, g0_88}));
MSKand_opini2_d2_pini u_t_88 (
    .ina({fc1[88], fc0[88]}), .inb({p1_88, p0_88}),
    .rnd(r[177]), .s(s[177]), .clk(clk), .out({t1_88, t0_88}));
assign fc0[89] = g0_88 ^ t0_88;
assign fc1[89] = g1_88 ^ t1_88;
wire p0_89 = Rsh_d0[89] ^ Bn0[89];
wire p1_89 = Rsh_d1[89] ^ Bn1[89];
wire g0_89, g1_89, t0_89, t1_89;
MSKand_opini2_d2_pini u_g_89 (
    .ina({Rsh_d1[89], Rsh_d0[89]}), .inb({Bn1[89], Bn0[89]}),
    .rnd(r[178]), .s(s[178]), .clk(clk), .out({g1_89, g0_89}));
MSKand_opini2_d2_pini u_t_89 (
    .ina({fc1[89], fc0[89]}), .inb({p1_89, p0_89}),
    .rnd(r[179]), .s(s[179]), .clk(clk), .out({t1_89, t0_89}));
assign fc0[90] = g0_89 ^ t0_89;
assign fc1[90] = g1_89 ^ t1_89;
wire p0_90 = Rsh_d0[90] ^ Bn0[90];
wire p1_90 = Rsh_d1[90] ^ Bn1[90];
wire g0_90, g1_90, t0_90, t1_90;
MSKand_opini2_d2_pini u_g_90 (
    .ina({Rsh_d1[90], Rsh_d0[90]}), .inb({Bn1[90], Bn0[90]}),
    .rnd(r[180]), .s(s[180]), .clk(clk), .out({g1_90, g0_90}));
MSKand_opini2_d2_pini u_t_90 (
    .ina({fc1[90], fc0[90]}), .inb({p1_90, p0_90}),
    .rnd(r[181]), .s(s[181]), .clk(clk), .out({t1_90, t0_90}));
assign fc0[91] = g0_90 ^ t0_90;
assign fc1[91] = g1_90 ^ t1_90;
wire p0_91 = Rsh_d0[91] ^ Bn0[91];
wire p1_91 = Rsh_d1[91] ^ Bn1[91];
wire g0_91, g1_91, t0_91, t1_91;
MSKand_opini2_d2_pini u_g_91 (
    .ina({Rsh_d1[91], Rsh_d0[91]}), .inb({Bn1[91], Bn0[91]}),
    .rnd(r[182]), .s(s[182]), .clk(clk), .out({g1_91, g0_91}));
MSKand_opini2_d2_pini u_t_91 (
    .ina({fc1[91], fc0[91]}), .inb({p1_91, p0_91}),
    .rnd(r[183]), .s(s[183]), .clk(clk), .out({t1_91, t0_91}));
assign fc0[92] = g0_91 ^ t0_91;
assign fc1[92] = g1_91 ^ t1_91;
wire p0_92 = Rsh_d0[92] ^ Bn0[92];
wire p1_92 = Rsh_d1[92] ^ Bn1[92];
wire g0_92, g1_92, t0_92, t1_92;
MSKand_opini2_d2_pini u_g_92 (
    .ina({Rsh_d1[92], Rsh_d0[92]}), .inb({Bn1[92], Bn0[92]}),
    .rnd(r[184]), .s(s[184]), .clk(clk), .out({g1_92, g0_92}));
MSKand_opini2_d2_pini u_t_92 (
    .ina({fc1[92], fc0[92]}), .inb({p1_92, p0_92}),
    .rnd(r[185]), .s(s[185]), .clk(clk), .out({t1_92, t0_92}));
assign fc0[93] = g0_92 ^ t0_92;
assign fc1[93] = g1_92 ^ t1_92;
wire p0_93 = Rsh_d0[93] ^ Bn0[93];
wire p1_93 = Rsh_d1[93] ^ Bn1[93];
wire g0_93, g1_93, t0_93, t1_93;
MSKand_opini2_d2_pini u_g_93 (
    .ina({Rsh_d1[93], Rsh_d0[93]}), .inb({Bn1[93], Bn0[93]}),
    .rnd(r[186]), .s(s[186]), .clk(clk), .out({g1_93, g0_93}));
MSKand_opini2_d2_pini u_t_93 (
    .ina({fc1[93], fc0[93]}), .inb({p1_93, p0_93}),
    .rnd(r[187]), .s(s[187]), .clk(clk), .out({t1_93, t0_93}));
assign fc0[94] = g0_93 ^ t0_93;
assign fc1[94] = g1_93 ^ t1_93;
wire p0_94 = Rsh_d0[94] ^ Bn0[94];
wire p1_94 = Rsh_d1[94] ^ Bn1[94];
wire g0_94, g1_94, t0_94, t1_94;
MSKand_opini2_d2_pini u_g_94 (
    .ina({Rsh_d1[94], Rsh_d0[94]}), .inb({Bn1[94], Bn0[94]}),
    .rnd(r[188]), .s(s[188]), .clk(clk), .out({g1_94, g0_94}));
MSKand_opini2_d2_pini u_t_94 (
    .ina({fc1[94], fc0[94]}), .inb({p1_94, p0_94}),
    .rnd(r[189]), .s(s[189]), .clk(clk), .out({t1_94, t0_94}));
assign fc0[95] = g0_94 ^ t0_94;
assign fc1[95] = g1_94 ^ t1_94;
wire p0_95 = Rsh_d0[95] ^ Bn0[95];
wire p1_95 = Rsh_d1[95] ^ Bn1[95];
wire g0_95, g1_95, t0_95, t1_95;
MSKand_opini2_d2_pini u_g_95 (
    .ina({Rsh_d1[95], Rsh_d0[95]}), .inb({Bn1[95], Bn0[95]}),
    .rnd(r[190]), .s(s[190]), .clk(clk), .out({g1_95, g0_95}));
MSKand_opini2_d2_pini u_t_95 (
    .ina({fc1[95], fc0[95]}), .inb({p1_95, p0_95}),
    .rnd(r[191]), .s(s[191]), .clk(clk), .out({t1_95, t0_95}));
assign fc0[96] = g0_95 ^ t0_95;
assign fc1[96] = g1_95 ^ t1_95;
wire p0_96 = Rsh_d0[96] ^ Bn0[96];
wire p1_96 = Rsh_d1[96] ^ Bn1[96];
wire g0_96, g1_96, t0_96, t1_96;
MSKand_opini2_d2_pini u_g_96 (
    .ina({Rsh_d1[96], Rsh_d0[96]}), .inb({Bn1[96], Bn0[96]}),
    .rnd(r[192]), .s(s[192]), .clk(clk), .out({g1_96, g0_96}));
MSKand_opini2_d2_pini u_t_96 (
    .ina({fc1[96], fc0[96]}), .inb({p1_96, p0_96}),
    .rnd(r[193]), .s(s[193]), .clk(clk), .out({t1_96, t0_96}));
assign fc0[97] = g0_96 ^ t0_96;
assign fc1[97] = g1_96 ^ t1_96;
wire p0_97 = Rsh_d0[97] ^ Bn0[97];
wire p1_97 = Rsh_d1[97] ^ Bn1[97];
wire g0_97, g1_97, t0_97, t1_97;
MSKand_opini2_d2_pini u_g_97 (
    .ina({Rsh_d1[97], Rsh_d0[97]}), .inb({Bn1[97], Bn0[97]}),
    .rnd(r[194]), .s(s[194]), .clk(clk), .out({g1_97, g0_97}));
MSKand_opini2_d2_pini u_t_97 (
    .ina({fc1[97], fc0[97]}), .inb({p1_97, p0_97}),
    .rnd(r[195]), .s(s[195]), .clk(clk), .out({t1_97, t0_97}));
assign fc0[98] = g0_97 ^ t0_97;
assign fc1[98] = g1_97 ^ t1_97;
wire p0_98 = Rsh_d0[98] ^ Bn0[98];
wire p1_98 = Rsh_d1[98] ^ Bn1[98];
wire g0_98, g1_98, t0_98, t1_98;
MSKand_opini2_d2_pini u_g_98 (
    .ina({Rsh_d1[98], Rsh_d0[98]}), .inb({Bn1[98], Bn0[98]}),
    .rnd(r[196]), .s(s[196]), .clk(clk), .out({g1_98, g0_98}));
MSKand_opini2_d2_pini u_t_98 (
    .ina({fc1[98], fc0[98]}), .inb({p1_98, p0_98}),
    .rnd(r[197]), .s(s[197]), .clk(clk), .out({t1_98, t0_98}));
assign fc0[99] = g0_98 ^ t0_98;
assign fc1[99] = g1_98 ^ t1_98;
wire p0_99 = Rsh_d0[99] ^ Bn0[99];
wire p1_99 = Rsh_d1[99] ^ Bn1[99];
wire g0_99, g1_99, t0_99, t1_99;
MSKand_opini2_d2_pini u_g_99 (
    .ina({Rsh_d1[99], Rsh_d0[99]}), .inb({Bn1[99], Bn0[99]}),
    .rnd(r[198]), .s(s[198]), .clk(clk), .out({g1_99, g0_99}));
MSKand_opini2_d2_pini u_t_99 (
    .ina({fc1[99], fc0[99]}), .inb({p1_99, p0_99}),
    .rnd(r[199]), .s(s[199]), .clk(clk), .out({t1_99, t0_99}));
assign fc0[100] = g0_99 ^ t0_99;
assign fc1[100] = g1_99 ^ t1_99;
wire p0_100 = Rsh_d0[100] ^ Bn0[100];
wire p1_100 = Rsh_d1[100] ^ Bn1[100];
wire g0_100, g1_100, t0_100, t1_100;
MSKand_opini2_d2_pini u_g_100 (
    .ina({Rsh_d1[100], Rsh_d0[100]}), .inb({Bn1[100], Bn0[100]}),
    .rnd(r[200]), .s(s[200]), .clk(clk), .out({g1_100, g0_100}));
MSKand_opini2_d2_pini u_t_100 (
    .ina({fc1[100], fc0[100]}), .inb({p1_100, p0_100}),
    .rnd(r[201]), .s(s[201]), .clk(clk), .out({t1_100, t0_100}));
assign fc0[101] = g0_100 ^ t0_100;
assign fc1[101] = g1_100 ^ t1_100;
wire p0_101 = Rsh_d0[101] ^ Bn0[101];
wire p1_101 = Rsh_d1[101] ^ Bn1[101];
wire g0_101, g1_101, t0_101, t1_101;
MSKand_opini2_d2_pini u_g_101 (
    .ina({Rsh_d1[101], Rsh_d0[101]}), .inb({Bn1[101], Bn0[101]}),
    .rnd(r[202]), .s(s[202]), .clk(clk), .out({g1_101, g0_101}));
MSKand_opini2_d2_pini u_t_101 (
    .ina({fc1[101], fc0[101]}), .inb({p1_101, p0_101}),
    .rnd(r[203]), .s(s[203]), .clk(clk), .out({t1_101, t0_101}));
assign fc0[102] = g0_101 ^ t0_101;
assign fc1[102] = g1_101 ^ t1_101;
wire p0_102 = Rsh_d0[102] ^ Bn0[102];
wire p1_102 = Rsh_d1[102] ^ Bn1[102];
wire g0_102, g1_102, t0_102, t1_102;
MSKand_opini2_d2_pini u_g_102 (
    .ina({Rsh_d1[102], Rsh_d0[102]}), .inb({Bn1[102], Bn0[102]}),
    .rnd(r[204]), .s(s[204]), .clk(clk), .out({g1_102, g0_102}));
MSKand_opini2_d2_pini u_t_102 (
    .ina({fc1[102], fc0[102]}), .inb({p1_102, p0_102}),
    .rnd(r[205]), .s(s[205]), .clk(clk), .out({t1_102, t0_102}));
assign fc0[103] = g0_102 ^ t0_102;
assign fc1[103] = g1_102 ^ t1_102;
wire p0_103 = Rsh_d0[103] ^ Bn0[103];
wire p1_103 = Rsh_d1[103] ^ Bn1[103];
wire g0_103, g1_103, t0_103, t1_103;
MSKand_opini2_d2_pini u_g_103 (
    .ina({Rsh_d1[103], Rsh_d0[103]}), .inb({Bn1[103], Bn0[103]}),
    .rnd(r[206]), .s(s[206]), .clk(clk), .out({g1_103, g0_103}));
MSKand_opini2_d2_pini u_t_103 (
    .ina({fc1[103], fc0[103]}), .inb({p1_103, p0_103}),
    .rnd(r[207]), .s(s[207]), .clk(clk), .out({t1_103, t0_103}));
assign fc0[104] = g0_103 ^ t0_103;
assign fc1[104] = g1_103 ^ t1_103;
wire p0_104 = Rsh_d0[104] ^ Bn0[104];
wire p1_104 = Rsh_d1[104] ^ Bn1[104];
wire g0_104, g1_104, t0_104, t1_104;
MSKand_opini2_d2_pini u_g_104 (
    .ina({Rsh_d1[104], Rsh_d0[104]}), .inb({Bn1[104], Bn0[104]}),
    .rnd(r[208]), .s(s[208]), .clk(clk), .out({g1_104, g0_104}));
MSKand_opini2_d2_pini u_t_104 (
    .ina({fc1[104], fc0[104]}), .inb({p1_104, p0_104}),
    .rnd(r[209]), .s(s[209]), .clk(clk), .out({t1_104, t0_104}));
assign fc0[105] = g0_104 ^ t0_104;
assign fc1[105] = g1_104 ^ t1_104;
wire p0_105 = Rsh_d0[105] ^ Bn0[105];
wire p1_105 = Rsh_d1[105] ^ Bn1[105];
wire g0_105, g1_105, t0_105, t1_105;
MSKand_opini2_d2_pini u_g_105 (
    .ina({Rsh_d1[105], Rsh_d0[105]}), .inb({Bn1[105], Bn0[105]}),
    .rnd(r[210]), .s(s[210]), .clk(clk), .out({g1_105, g0_105}));
MSKand_opini2_d2_pini u_t_105 (
    .ina({fc1[105], fc0[105]}), .inb({p1_105, p0_105}),
    .rnd(r[211]), .s(s[211]), .clk(clk), .out({t1_105, t0_105}));
assign fc0[106] = g0_105 ^ t0_105;
assign fc1[106] = g1_105 ^ t1_105;
wire p0_106 = Rsh_d0[106] ^ Bn0[106];
wire p1_106 = Rsh_d1[106] ^ Bn1[106];
wire g0_106, g1_106, t0_106, t1_106;
MSKand_opini2_d2_pini u_g_106 (
    .ina({Rsh_d1[106], Rsh_d0[106]}), .inb({Bn1[106], Bn0[106]}),
    .rnd(r[212]), .s(s[212]), .clk(clk), .out({g1_106, g0_106}));
MSKand_opini2_d2_pini u_t_106 (
    .ina({fc1[106], fc0[106]}), .inb({p1_106, p0_106}),
    .rnd(r[213]), .s(s[213]), .clk(clk), .out({t1_106, t0_106}));
assign fc0[107] = g0_106 ^ t0_106;
assign fc1[107] = g1_106 ^ t1_106;
wire p0_107 = Rsh_d0[107] ^ Bn0[107];
wire p1_107 = Rsh_d1[107] ^ Bn1[107];
wire g0_107, g1_107, t0_107, t1_107;
MSKand_opini2_d2_pini u_g_107 (
    .ina({Rsh_d1[107], Rsh_d0[107]}), .inb({Bn1[107], Bn0[107]}),
    .rnd(r[214]), .s(s[214]), .clk(clk), .out({g1_107, g0_107}));
MSKand_opini2_d2_pini u_t_107 (
    .ina({fc1[107], fc0[107]}), .inb({p1_107, p0_107}),
    .rnd(r[215]), .s(s[215]), .clk(clk), .out({t1_107, t0_107}));
assign fc0[108] = g0_107 ^ t0_107;
assign fc1[108] = g1_107 ^ t1_107;
wire p0_108 = Rsh_d0[108] ^ Bn0[108];
wire p1_108 = Rsh_d1[108] ^ Bn1[108];
wire g0_108, g1_108, t0_108, t1_108;
MSKand_opini2_d2_pini u_g_108 (
    .ina({Rsh_d1[108], Rsh_d0[108]}), .inb({Bn1[108], Bn0[108]}),
    .rnd(r[216]), .s(s[216]), .clk(clk), .out({g1_108, g0_108}));
MSKand_opini2_d2_pini u_t_108 (
    .ina({fc1[108], fc0[108]}), .inb({p1_108, p0_108}),
    .rnd(r[217]), .s(s[217]), .clk(clk), .out({t1_108, t0_108}));
assign fc0[109] = g0_108 ^ t0_108;
assign fc1[109] = g1_108 ^ t1_108;
wire p0_109 = Rsh_d0[109] ^ Bn0[109];
wire p1_109 = Rsh_d1[109] ^ Bn1[109];
wire g0_109, g1_109, t0_109, t1_109;
MSKand_opini2_d2_pini u_g_109 (
    .ina({Rsh_d1[109], Rsh_d0[109]}), .inb({Bn1[109], Bn0[109]}),
    .rnd(r[218]), .s(s[218]), .clk(clk), .out({g1_109, g0_109}));
MSKand_opini2_d2_pini u_t_109 (
    .ina({fc1[109], fc0[109]}), .inb({p1_109, p0_109}),
    .rnd(r[219]), .s(s[219]), .clk(clk), .out({t1_109, t0_109}));
assign fc0[110] = g0_109 ^ t0_109;
assign fc1[110] = g1_109 ^ t1_109;
wire p0_110 = Rsh_d0[110] ^ Bn0[110];
wire p1_110 = Rsh_d1[110] ^ Bn1[110];
wire g0_110, g1_110, t0_110, t1_110;
MSKand_opini2_d2_pini u_g_110 (
    .ina({Rsh_d1[110], Rsh_d0[110]}), .inb({Bn1[110], Bn0[110]}),
    .rnd(r[220]), .s(s[220]), .clk(clk), .out({g1_110, g0_110}));
MSKand_opini2_d2_pini u_t_110 (
    .ina({fc1[110], fc0[110]}), .inb({p1_110, p0_110}),
    .rnd(r[221]), .s(s[221]), .clk(clk), .out({t1_110, t0_110}));
assign fc0[111] = g0_110 ^ t0_110;
assign fc1[111] = g1_110 ^ t1_110;
wire p0_111 = Rsh_d0[111] ^ Bn0[111];
wire p1_111 = Rsh_d1[111] ^ Bn1[111];
wire g0_111, g1_111, t0_111, t1_111;
MSKand_opini2_d2_pini u_g_111 (
    .ina({Rsh_d1[111], Rsh_d0[111]}), .inb({Bn1[111], Bn0[111]}),
    .rnd(r[222]), .s(s[222]), .clk(clk), .out({g1_111, g0_111}));
MSKand_opini2_d2_pini u_t_111 (
    .ina({fc1[111], fc0[111]}), .inb({p1_111, p0_111}),
    .rnd(r[223]), .s(s[223]), .clk(clk), .out({t1_111, t0_111}));
assign fc0[112] = g0_111 ^ t0_111;
assign fc1[112] = g1_111 ^ t1_111;
wire p0_112 = Rsh_d0[112] ^ Bn0[112];
wire p1_112 = Rsh_d1[112] ^ Bn1[112];
wire g0_112, g1_112, t0_112, t1_112;
MSKand_opini2_d2_pini u_g_112 (
    .ina({Rsh_d1[112], Rsh_d0[112]}), .inb({Bn1[112], Bn0[112]}),
    .rnd(r[224]), .s(s[224]), .clk(clk), .out({g1_112, g0_112}));
MSKand_opini2_d2_pini u_t_112 (
    .ina({fc1[112], fc0[112]}), .inb({p1_112, p0_112}),
    .rnd(r[225]), .s(s[225]), .clk(clk), .out({t1_112, t0_112}));
assign fc0[113] = g0_112 ^ t0_112;
assign fc1[113] = g1_112 ^ t1_112;
wire p0_113 = Rsh_d0[113] ^ Bn0[113];
wire p1_113 = Rsh_d1[113] ^ Bn1[113];
wire g0_113, g1_113, t0_113, t1_113;
MSKand_opini2_d2_pini u_g_113 (
    .ina({Rsh_d1[113], Rsh_d0[113]}), .inb({Bn1[113], Bn0[113]}),
    .rnd(r[226]), .s(s[226]), .clk(clk), .out({g1_113, g0_113}));
MSKand_opini2_d2_pini u_t_113 (
    .ina({fc1[113], fc0[113]}), .inb({p1_113, p0_113}),
    .rnd(r[227]), .s(s[227]), .clk(clk), .out({t1_113, t0_113}));
assign fc0[114] = g0_113 ^ t0_113;
assign fc1[114] = g1_113 ^ t1_113;
wire p0_114 = Rsh_d0[114] ^ Bn0[114];
wire p1_114 = Rsh_d1[114] ^ Bn1[114];
wire g0_114, g1_114, t0_114, t1_114;
MSKand_opini2_d2_pini u_g_114 (
    .ina({Rsh_d1[114], Rsh_d0[114]}), .inb({Bn1[114], Bn0[114]}),
    .rnd(r[228]), .s(s[228]), .clk(clk), .out({g1_114, g0_114}));
MSKand_opini2_d2_pini u_t_114 (
    .ina({fc1[114], fc0[114]}), .inb({p1_114, p0_114}),
    .rnd(r[229]), .s(s[229]), .clk(clk), .out({t1_114, t0_114}));
assign fc0[115] = g0_114 ^ t0_114;
assign fc1[115] = g1_114 ^ t1_114;
wire p0_115 = Rsh_d0[115] ^ Bn0[115];
wire p1_115 = Rsh_d1[115] ^ Bn1[115];
wire g0_115, g1_115, t0_115, t1_115;
MSKand_opini2_d2_pini u_g_115 (
    .ina({Rsh_d1[115], Rsh_d0[115]}), .inb({Bn1[115], Bn0[115]}),
    .rnd(r[230]), .s(s[230]), .clk(clk), .out({g1_115, g0_115}));
MSKand_opini2_d2_pini u_t_115 (
    .ina({fc1[115], fc0[115]}), .inb({p1_115, p0_115}),
    .rnd(r[231]), .s(s[231]), .clk(clk), .out({t1_115, t0_115}));
assign fc0[116] = g0_115 ^ t0_115;
assign fc1[116] = g1_115 ^ t1_115;
wire p0_116 = Rsh_d0[116] ^ Bn0[116];
wire p1_116 = Rsh_d1[116] ^ Bn1[116];
wire g0_116, g1_116, t0_116, t1_116;
MSKand_opini2_d2_pini u_g_116 (
    .ina({Rsh_d1[116], Rsh_d0[116]}), .inb({Bn1[116], Bn0[116]}),
    .rnd(r[232]), .s(s[232]), .clk(clk), .out({g1_116, g0_116}));
MSKand_opini2_d2_pini u_t_116 (
    .ina({fc1[116], fc0[116]}), .inb({p1_116, p0_116}),
    .rnd(r[233]), .s(s[233]), .clk(clk), .out({t1_116, t0_116}));
assign fc0[117] = g0_116 ^ t0_116;
assign fc1[117] = g1_116 ^ t1_116;
wire p0_117 = Rsh_d0[117] ^ Bn0[117];
wire p1_117 = Rsh_d1[117] ^ Bn1[117];
wire g0_117, g1_117, t0_117, t1_117;
MSKand_opini2_d2_pini u_g_117 (
    .ina({Rsh_d1[117], Rsh_d0[117]}), .inb({Bn1[117], Bn0[117]}),
    .rnd(r[234]), .s(s[234]), .clk(clk), .out({g1_117, g0_117}));
MSKand_opini2_d2_pini u_t_117 (
    .ina({fc1[117], fc0[117]}), .inb({p1_117, p0_117}),
    .rnd(r[235]), .s(s[235]), .clk(clk), .out({t1_117, t0_117}));
assign fc0[118] = g0_117 ^ t0_117;
assign fc1[118] = g1_117 ^ t1_117;
wire p0_118 = Rsh_d0[118] ^ Bn0[118];
wire p1_118 = Rsh_d1[118] ^ Bn1[118];
wire g0_118, g1_118, t0_118, t1_118;
MSKand_opini2_d2_pini u_g_118 (
    .ina({Rsh_d1[118], Rsh_d0[118]}), .inb({Bn1[118], Bn0[118]}),
    .rnd(r[236]), .s(s[236]), .clk(clk), .out({g1_118, g0_118}));
MSKand_opini2_d2_pini u_t_118 (
    .ina({fc1[118], fc0[118]}), .inb({p1_118, p0_118}),
    .rnd(r[237]), .s(s[237]), .clk(clk), .out({t1_118, t0_118}));
assign fc0[119] = g0_118 ^ t0_118;
assign fc1[119] = g1_118 ^ t1_118;
wire p0_119 = Rsh_d0[119] ^ Bn0[119];
wire p1_119 = Rsh_d1[119] ^ Bn1[119];
wire g0_119, g1_119, t0_119, t1_119;
MSKand_opini2_d2_pini u_g_119 (
    .ina({Rsh_d1[119], Rsh_d0[119]}), .inb({Bn1[119], Bn0[119]}),
    .rnd(r[238]), .s(s[238]), .clk(clk), .out({g1_119, g0_119}));
MSKand_opini2_d2_pini u_t_119 (
    .ina({fc1[119], fc0[119]}), .inb({p1_119, p0_119}),
    .rnd(r[239]), .s(s[239]), .clk(clk), .out({t1_119, t0_119}));
assign fc0[120] = g0_119 ^ t0_119;
assign fc1[120] = g1_119 ^ t1_119;
wire p0_120 = Rsh_d0[120] ^ Bn0[120];
wire p1_120 = Rsh_d1[120] ^ Bn1[120];
wire g0_120, g1_120, t0_120, t1_120;
MSKand_opini2_d2_pini u_g_120 (
    .ina({Rsh_d1[120], Rsh_d0[120]}), .inb({Bn1[120], Bn0[120]}),
    .rnd(r[240]), .s(s[240]), .clk(clk), .out({g1_120, g0_120}));
MSKand_opini2_d2_pini u_t_120 (
    .ina({fc1[120], fc0[120]}), .inb({p1_120, p0_120}),
    .rnd(r[241]), .s(s[241]), .clk(clk), .out({t1_120, t0_120}));
assign fc0[121] = g0_120 ^ t0_120;
assign fc1[121] = g1_120 ^ t1_120;
wire p0_121 = Rsh_d0[121] ^ Bn0[121];
wire p1_121 = Rsh_d1[121] ^ Bn1[121];
wire g0_121, g1_121, t0_121, t1_121;
MSKand_opini2_d2_pini u_g_121 (
    .ina({Rsh_d1[121], Rsh_d0[121]}), .inb({Bn1[121], Bn0[121]}),
    .rnd(r[242]), .s(s[242]), .clk(clk), .out({g1_121, g0_121}));
MSKand_opini2_d2_pini u_t_121 (
    .ina({fc1[121], fc0[121]}), .inb({p1_121, p0_121}),
    .rnd(r[243]), .s(s[243]), .clk(clk), .out({t1_121, t0_121}));
assign fc0[122] = g0_121 ^ t0_121;
assign fc1[122] = g1_121 ^ t1_121;
wire p0_122 = Rsh_d0[122] ^ Bn0[122];
wire p1_122 = Rsh_d1[122] ^ Bn1[122];
wire g0_122, g1_122, t0_122, t1_122;
MSKand_opini2_d2_pini u_g_122 (
    .ina({Rsh_d1[122], Rsh_d0[122]}), .inb({Bn1[122], Bn0[122]}),
    .rnd(r[244]), .s(s[244]), .clk(clk), .out({g1_122, g0_122}));
MSKand_opini2_d2_pini u_t_122 (
    .ina({fc1[122], fc0[122]}), .inb({p1_122, p0_122}),
    .rnd(r[245]), .s(s[245]), .clk(clk), .out({t1_122, t0_122}));
assign fc0[123] = g0_122 ^ t0_122;
assign fc1[123] = g1_122 ^ t1_122;
wire p0_123 = Rsh_d0[123] ^ Bn0[123];
wire p1_123 = Rsh_d1[123] ^ Bn1[123];
wire g0_123, g1_123, t0_123, t1_123;
MSKand_opini2_d2_pini u_g_123 (
    .ina({Rsh_d1[123], Rsh_d0[123]}), .inb({Bn1[123], Bn0[123]}),
    .rnd(r[246]), .s(s[246]), .clk(clk), .out({g1_123, g0_123}));
MSKand_opini2_d2_pini u_t_123 (
    .ina({fc1[123], fc0[123]}), .inb({p1_123, p0_123}),
    .rnd(r[247]), .s(s[247]), .clk(clk), .out({t1_123, t0_123}));
assign fc0[124] = g0_123 ^ t0_123;
assign fc1[124] = g1_123 ^ t1_123;
wire p0_124 = Rsh_d0[124] ^ Bn0[124];
wire p1_124 = Rsh_d1[124] ^ Bn1[124];
wire g0_124, g1_124, t0_124, t1_124;
MSKand_opini2_d2_pini u_g_124 (
    .ina({Rsh_d1[124], Rsh_d0[124]}), .inb({Bn1[124], Bn0[124]}),
    .rnd(r[248]), .s(s[248]), .clk(clk), .out({g1_124, g0_124}));
MSKand_opini2_d2_pini u_t_124 (
    .ina({fc1[124], fc0[124]}), .inb({p1_124, p0_124}),
    .rnd(r[249]), .s(s[249]), .clk(clk), .out({t1_124, t0_124}));
assign fc0[125] = g0_124 ^ t0_124;
assign fc1[125] = g1_124 ^ t1_124;
wire p0_125 = Rsh_d0[125] ^ Bn0[125];
wire p1_125 = Rsh_d1[125] ^ Bn1[125];
wire g0_125, g1_125, t0_125, t1_125;
MSKand_opini2_d2_pini u_g_125 (
    .ina({Rsh_d1[125], Rsh_d0[125]}), .inb({Bn1[125], Bn0[125]}),
    .rnd(r[250]), .s(s[250]), .clk(clk), .out({g1_125, g0_125}));
MSKand_opini2_d2_pini u_t_125 (
    .ina({fc1[125], fc0[125]}), .inb({p1_125, p0_125}),
    .rnd(r[251]), .s(s[251]), .clk(clk), .out({t1_125, t0_125}));
assign fc0[126] = g0_125 ^ t0_125;
assign fc1[126] = g1_125 ^ t1_125;
wire p0_126 = Rsh_d0[126] ^ Bn0[126];
wire p1_126 = Rsh_d1[126] ^ Bn1[126];
wire g0_126, g1_126, t0_126, t1_126;
MSKand_opini2_d2_pini u_g_126 (
    .ina({Rsh_d1[126], Rsh_d0[126]}), .inb({Bn1[126], Bn0[126]}),
    .rnd(r[252]), .s(s[252]), .clk(clk), .out({g1_126, g0_126}));
MSKand_opini2_d2_pini u_t_126 (
    .ina({fc1[126], fc0[126]}), .inb({p1_126, p0_126}),
    .rnd(r[253]), .s(s[253]), .clk(clk), .out({t1_126, t0_126}));
assign fc0[127] = g0_126 ^ t0_126;
assign fc1[127] = g1_126 ^ t1_126;
wire p0_127 = Rsh_d0[127] ^ Bn0[127];
wire p1_127 = Rsh_d1[127] ^ Bn1[127];
wire g0_127, g1_127, t0_127, t1_127;
MSKand_opini2_d2_pini u_g_127 (
    .ina({Rsh_d1[127], Rsh_d0[127]}), .inb({Bn1[127], Bn0[127]}),
    .rnd(r[254]), .s(s[254]), .clk(clk), .out({g1_127, g0_127}));
MSKand_opini2_d2_pini u_t_127 (
    .ina({fc1[127], fc0[127]}), .inb({p1_127, p0_127}),
    .rnd(r[255]), .s(s[255]), .clk(clk), .out({t1_127, t0_127}));
assign fc0[128] = g0_127 ^ t0_127;
assign fc1[128] = g1_127 ^ t1_127;
wire p0_128 = Rsh_d0[128] ^ Bn0[128];
wire p1_128 = Rsh_d1[128] ^ Bn1[128];
wire g0_128, g1_128, t0_128, t1_128;
MSKand_opini2_d2_pini u_g_128 (
    .ina({Rsh_d1[128], Rsh_d0[128]}), .inb({Bn1[128], Bn0[128]}),
    .rnd(r[256]), .s(s[256]), .clk(clk), .out({g1_128, g0_128}));
MSKand_opini2_d2_pini u_t_128 (
    .ina({fc1[128], fc0[128]}), .inb({p1_128, p0_128}),
    .rnd(r[257]), .s(s[257]), .clk(clk), .out({t1_128, t0_128}));
assign fc0[129] = g0_128 ^ t0_128;
assign fc1[129] = g1_128 ^ t1_128;
wire p0_129 = Rsh_d0[129] ^ Bn0[129];
wire p1_129 = Rsh_d1[129] ^ Bn1[129];
wire g0_129, g1_129, t0_129, t1_129;
MSKand_opini2_d2_pini u_g_129 (
    .ina({Rsh_d1[129], Rsh_d0[129]}), .inb({Bn1[129], Bn0[129]}),
    .rnd(r[258]), .s(s[258]), .clk(clk), .out({g1_129, g0_129}));
MSKand_opini2_d2_pini u_t_129 (
    .ina({fc1[129], fc0[129]}), .inb({p1_129, p0_129}),
    .rnd(r[259]), .s(s[259]), .clk(clk), .out({t1_129, t0_129}));
assign fc0[130] = g0_129 ^ t0_129;
assign fc1[130] = g1_129 ^ t1_129;
wire p0_130 = Rsh_d0[130] ^ Bn0[130];
wire p1_130 = Rsh_d1[130] ^ Bn1[130];
wire g0_130, g1_130, t0_130, t1_130;
MSKand_opini2_d2_pini u_g_130 (
    .ina({Rsh_d1[130], Rsh_d0[130]}), .inb({Bn1[130], Bn0[130]}),
    .rnd(r[260]), .s(s[260]), .clk(clk), .out({g1_130, g0_130}));
MSKand_opini2_d2_pini u_t_130 (
    .ina({fc1[130], fc0[130]}), .inb({p1_130, p0_130}),
    .rnd(r[261]), .s(s[261]), .clk(clk), .out({t1_130, t0_130}));
assign fc0[131] = g0_130 ^ t0_130;
assign fc1[131] = g1_130 ^ t1_130;
wire p0_131 = Rsh_d0[131] ^ Bn0[131];
wire p1_131 = Rsh_d1[131] ^ Bn1[131];
wire g0_131, g1_131, t0_131, t1_131;
MSKand_opini2_d2_pini u_g_131 (
    .ina({Rsh_d1[131], Rsh_d0[131]}), .inb({Bn1[131], Bn0[131]}),
    .rnd(r[262]), .s(s[262]), .clk(clk), .out({g1_131, g0_131}));
MSKand_opini2_d2_pini u_t_131 (
    .ina({fc1[131], fc0[131]}), .inb({p1_131, p0_131}),
    .rnd(r[263]), .s(s[263]), .clk(clk), .out({t1_131, t0_131}));
assign fc0[132] = g0_131 ^ t0_131;
assign fc1[132] = g1_131 ^ t1_131;
wire p0_132 = Rsh_d0[132] ^ Bn0[132];
wire p1_132 = Rsh_d1[132] ^ Bn1[132];
wire g0_132, g1_132, t0_132, t1_132;
MSKand_opini2_d2_pini u_g_132 (
    .ina({Rsh_d1[132], Rsh_d0[132]}), .inb({Bn1[132], Bn0[132]}),
    .rnd(r[264]), .s(s[264]), .clk(clk), .out({g1_132, g0_132}));
MSKand_opini2_d2_pini u_t_132 (
    .ina({fc1[132], fc0[132]}), .inb({p1_132, p0_132}),
    .rnd(r[265]), .s(s[265]), .clk(clk), .out({t1_132, t0_132}));
assign fc0[133] = g0_132 ^ t0_132;
assign fc1[133] = g1_132 ^ t1_132;
wire p0_133 = Rsh_d0[133] ^ Bn0[133];
wire p1_133 = Rsh_d1[133] ^ Bn1[133];
wire g0_133, g1_133, t0_133, t1_133;
MSKand_opini2_d2_pini u_g_133 (
    .ina({Rsh_d1[133], Rsh_d0[133]}), .inb({Bn1[133], Bn0[133]}),
    .rnd(r[266]), .s(s[266]), .clk(clk), .out({g1_133, g0_133}));
MSKand_opini2_d2_pini u_t_133 (
    .ina({fc1[133], fc0[133]}), .inb({p1_133, p0_133}),
    .rnd(r[267]), .s(s[267]), .clk(clk), .out({t1_133, t0_133}));
assign fc0[134] = g0_133 ^ t0_133;
assign fc1[134] = g1_133 ^ t1_133;
wire p0_134 = Rsh_d0[134] ^ Bn0[134];
wire p1_134 = Rsh_d1[134] ^ Bn1[134];
wire g0_134, g1_134, t0_134, t1_134;
MSKand_opini2_d2_pini u_g_134 (
    .ina({Rsh_d1[134], Rsh_d0[134]}), .inb({Bn1[134], Bn0[134]}),
    .rnd(r[268]), .s(s[268]), .clk(clk), .out({g1_134, g0_134}));
MSKand_opini2_d2_pini u_t_134 (
    .ina({fc1[134], fc0[134]}), .inb({p1_134, p0_134}),
    .rnd(r[269]), .s(s[269]), .clk(clk), .out({t1_134, t0_134}));
assign fc0[135] = g0_134 ^ t0_134;
assign fc1[135] = g1_134 ^ t1_134;
wire p0_135 = Rsh_d0[135] ^ Bn0[135];
wire p1_135 = Rsh_d1[135] ^ Bn1[135];
wire g0_135, g1_135, t0_135, t1_135;
MSKand_opini2_d2_pini u_g_135 (
    .ina({Rsh_d1[135], Rsh_d0[135]}), .inb({Bn1[135], Bn0[135]}),
    .rnd(r[270]), .s(s[270]), .clk(clk), .out({g1_135, g0_135}));
MSKand_opini2_d2_pini u_t_135 (
    .ina({fc1[135], fc0[135]}), .inb({p1_135, p0_135}),
    .rnd(r[271]), .s(s[271]), .clk(clk), .out({t1_135, t0_135}));
assign fc0[136] = g0_135 ^ t0_135;
assign fc1[136] = g1_135 ^ t1_135;
wire p0_136 = Rsh_d0[136] ^ Bn0[136];
wire p1_136 = Rsh_d1[136] ^ Bn1[136];
wire g0_136, g1_136, t0_136, t1_136;
MSKand_opini2_d2_pini u_g_136 (
    .ina({Rsh_d1[136], Rsh_d0[136]}), .inb({Bn1[136], Bn0[136]}),
    .rnd(r[272]), .s(s[272]), .clk(clk), .out({g1_136, g0_136}));
MSKand_opini2_d2_pini u_t_136 (
    .ina({fc1[136], fc0[136]}), .inb({p1_136, p0_136}),
    .rnd(r[273]), .s(s[273]), .clk(clk), .out({t1_136, t0_136}));
assign fc0[137] = g0_136 ^ t0_136;
assign fc1[137] = g1_136 ^ t1_136;
wire p0_137 = Rsh_d0[137] ^ Bn0[137];
wire p1_137 = Rsh_d1[137] ^ Bn1[137];
wire g0_137, g1_137, t0_137, t1_137;
MSKand_opini2_d2_pini u_g_137 (
    .ina({Rsh_d1[137], Rsh_d0[137]}), .inb({Bn1[137], Bn0[137]}),
    .rnd(r[274]), .s(s[274]), .clk(clk), .out({g1_137, g0_137}));
MSKand_opini2_d2_pini u_t_137 (
    .ina({fc1[137], fc0[137]}), .inb({p1_137, p0_137}),
    .rnd(r[275]), .s(s[275]), .clk(clk), .out({t1_137, t0_137}));
assign fc0[138] = g0_137 ^ t0_137;
assign fc1[138] = g1_137 ^ t1_137;
wire p0_138 = Rsh_d0[138] ^ Bn0[138];
wire p1_138 = Rsh_d1[138] ^ Bn1[138];
wire g0_138, g1_138, t0_138, t1_138;
MSKand_opini2_d2_pini u_g_138 (
    .ina({Rsh_d1[138], Rsh_d0[138]}), .inb({Bn1[138], Bn0[138]}),
    .rnd(r[276]), .s(s[276]), .clk(clk), .out({g1_138, g0_138}));
MSKand_opini2_d2_pini u_t_138 (
    .ina({fc1[138], fc0[138]}), .inb({p1_138, p0_138}),
    .rnd(r[277]), .s(s[277]), .clk(clk), .out({t1_138, t0_138}));
assign fc0[139] = g0_138 ^ t0_138;
assign fc1[139] = g1_138 ^ t1_138;
wire p0_139 = Rsh_d0[139] ^ Bn0[139];
wire p1_139 = Rsh_d1[139] ^ Bn1[139];
wire g0_139, g1_139, t0_139, t1_139;
MSKand_opini2_d2_pini u_g_139 (
    .ina({Rsh_d1[139], Rsh_d0[139]}), .inb({Bn1[139], Bn0[139]}),
    .rnd(r[278]), .s(s[278]), .clk(clk), .out({g1_139, g0_139}));
MSKand_opini2_d2_pini u_t_139 (
    .ina({fc1[139], fc0[139]}), .inb({p1_139, p0_139}),
    .rnd(r[279]), .s(s[279]), .clk(clk), .out({t1_139, t0_139}));
assign fc0[140] = g0_139 ^ t0_139;
assign fc1[140] = g1_139 ^ t1_139;
wire p0_140 = Rsh_d0[140] ^ Bn0[140];
wire p1_140 = Rsh_d1[140] ^ Bn1[140];
wire g0_140, g1_140, t0_140, t1_140;
MSKand_opini2_d2_pini u_g_140 (
    .ina({Rsh_d1[140], Rsh_d0[140]}), .inb({Bn1[140], Bn0[140]}),
    .rnd(r[280]), .s(s[280]), .clk(clk), .out({g1_140, g0_140}));
MSKand_opini2_d2_pini u_t_140 (
    .ina({fc1[140], fc0[140]}), .inb({p1_140, p0_140}),
    .rnd(r[281]), .s(s[281]), .clk(clk), .out({t1_140, t0_140}));
assign fc0[141] = g0_140 ^ t0_140;
assign fc1[141] = g1_140 ^ t1_140;
wire p0_141 = Rsh_d0[141] ^ Bn0[141];
wire p1_141 = Rsh_d1[141] ^ Bn1[141];
wire g0_141, g1_141, t0_141, t1_141;
MSKand_opini2_d2_pini u_g_141 (
    .ina({Rsh_d1[141], Rsh_d0[141]}), .inb({Bn1[141], Bn0[141]}),
    .rnd(r[282]), .s(s[282]), .clk(clk), .out({g1_141, g0_141}));
MSKand_opini2_d2_pini u_t_141 (
    .ina({fc1[141], fc0[141]}), .inb({p1_141, p0_141}),
    .rnd(r[283]), .s(s[283]), .clk(clk), .out({t1_141, t0_141}));
assign fc0[142] = g0_141 ^ t0_141;
assign fc1[142] = g1_141 ^ t1_141;
wire p0_142 = Rsh_d0[142] ^ Bn0[142];
wire p1_142 = Rsh_d1[142] ^ Bn1[142];
wire g0_142, g1_142, t0_142, t1_142;
MSKand_opini2_d2_pini u_g_142 (
    .ina({Rsh_d1[142], Rsh_d0[142]}), .inb({Bn1[142], Bn0[142]}),
    .rnd(r[284]), .s(s[284]), .clk(clk), .out({g1_142, g0_142}));
MSKand_opini2_d2_pini u_t_142 (
    .ina({fc1[142], fc0[142]}), .inb({p1_142, p0_142}),
    .rnd(r[285]), .s(s[285]), .clk(clk), .out({t1_142, t0_142}));
assign fc0[143] = g0_142 ^ t0_142;
assign fc1[143] = g1_142 ^ t1_142;
wire p0_143 = Rsh_d0[143] ^ Bn0[143];
wire p1_143 = Rsh_d1[143] ^ Bn1[143];
wire g0_143, g1_143, t0_143, t1_143;
MSKand_opini2_d2_pini u_g_143 (
    .ina({Rsh_d1[143], Rsh_d0[143]}), .inb({Bn1[143], Bn0[143]}),
    .rnd(r[286]), .s(s[286]), .clk(clk), .out({g1_143, g0_143}));
MSKand_opini2_d2_pini u_t_143 (
    .ina({fc1[143], fc0[143]}), .inb({p1_143, p0_143}),
    .rnd(r[287]), .s(s[287]), .clk(clk), .out({t1_143, t0_143}));
assign fc0[144] = g0_143 ^ t0_143;
assign fc1[144] = g1_143 ^ t1_143;
wire p0_144 = Rsh_d0[144] ^ Bn0[144];
wire p1_144 = Rsh_d1[144] ^ Bn1[144];
wire g0_144, g1_144, t0_144, t1_144;
MSKand_opini2_d2_pini u_g_144 (
    .ina({Rsh_d1[144], Rsh_d0[144]}), .inb({Bn1[144], Bn0[144]}),
    .rnd(r[288]), .s(s[288]), .clk(clk), .out({g1_144, g0_144}));
MSKand_opini2_d2_pini u_t_144 (
    .ina({fc1[144], fc0[144]}), .inb({p1_144, p0_144}),
    .rnd(r[289]), .s(s[289]), .clk(clk), .out({t1_144, t0_144}));
assign fc0[145] = g0_144 ^ t0_144;
assign fc1[145] = g1_144 ^ t1_144;
wire p0_145 = Rsh_d0[145] ^ Bn0[145];
wire p1_145 = Rsh_d1[145] ^ Bn1[145];
wire g0_145, g1_145, t0_145, t1_145;
MSKand_opini2_d2_pini u_g_145 (
    .ina({Rsh_d1[145], Rsh_d0[145]}), .inb({Bn1[145], Bn0[145]}),
    .rnd(r[290]), .s(s[290]), .clk(clk), .out({g1_145, g0_145}));
MSKand_opini2_d2_pini u_t_145 (
    .ina({fc1[145], fc0[145]}), .inb({p1_145, p0_145}),
    .rnd(r[291]), .s(s[291]), .clk(clk), .out({t1_145, t0_145}));
assign fc0[146] = g0_145 ^ t0_145;
assign fc1[146] = g1_145 ^ t1_145;
wire p0_146 = Rsh_d0[146] ^ Bn0[146];
wire p1_146 = Rsh_d1[146] ^ Bn1[146];
wire g0_146, g1_146, t0_146, t1_146;
MSKand_opini2_d2_pini u_g_146 (
    .ina({Rsh_d1[146], Rsh_d0[146]}), .inb({Bn1[146], Bn0[146]}),
    .rnd(r[292]), .s(s[292]), .clk(clk), .out({g1_146, g0_146}));
MSKand_opini2_d2_pini u_t_146 (
    .ina({fc1[146], fc0[146]}), .inb({p1_146, p0_146}),
    .rnd(r[293]), .s(s[293]), .clk(clk), .out({t1_146, t0_146}));
assign fc0[147] = g0_146 ^ t0_146;
assign fc1[147] = g1_146 ^ t1_146;
wire p0_147 = Rsh_d0[147] ^ Bn0[147];
wire p1_147 = Rsh_d1[147] ^ Bn1[147];
wire g0_147, g1_147, t0_147, t1_147;
MSKand_opini2_d2_pini u_g_147 (
    .ina({Rsh_d1[147], Rsh_d0[147]}), .inb({Bn1[147], Bn0[147]}),
    .rnd(r[294]), .s(s[294]), .clk(clk), .out({g1_147, g0_147}));
MSKand_opini2_d2_pini u_t_147 (
    .ina({fc1[147], fc0[147]}), .inb({p1_147, p0_147}),
    .rnd(r[295]), .s(s[295]), .clk(clk), .out({t1_147, t0_147}));
assign fc0[148] = g0_147 ^ t0_147;
assign fc1[148] = g1_147 ^ t1_147;
wire p0_148 = Rsh_d0[148] ^ Bn0[148];
wire p1_148 = Rsh_d1[148] ^ Bn1[148];
wire g0_148, g1_148, t0_148, t1_148;
MSKand_opini2_d2_pini u_g_148 (
    .ina({Rsh_d1[148], Rsh_d0[148]}), .inb({Bn1[148], Bn0[148]}),
    .rnd(r[296]), .s(s[296]), .clk(clk), .out({g1_148, g0_148}));
MSKand_opini2_d2_pini u_t_148 (
    .ina({fc1[148], fc0[148]}), .inb({p1_148, p0_148}),
    .rnd(r[297]), .s(s[297]), .clk(clk), .out({t1_148, t0_148}));
assign fc0[149] = g0_148 ^ t0_148;
assign fc1[149] = g1_148 ^ t1_148;
wire p0_149 = Rsh_d0[149] ^ Bn0[149];
wire p1_149 = Rsh_d1[149] ^ Bn1[149];
wire g0_149, g1_149, t0_149, t1_149;
MSKand_opini2_d2_pini u_g_149 (
    .ina({Rsh_d1[149], Rsh_d0[149]}), .inb({Bn1[149], Bn0[149]}),
    .rnd(r[298]), .s(s[298]), .clk(clk), .out({g1_149, g0_149}));
MSKand_opini2_d2_pini u_t_149 (
    .ina({fc1[149], fc0[149]}), .inb({p1_149, p0_149}),
    .rnd(r[299]), .s(s[299]), .clk(clk), .out({t1_149, t0_149}));
assign fc0[150] = g0_149 ^ t0_149;
assign fc1[150] = g1_149 ^ t1_149;
wire p0_150 = Rsh_d0[150] ^ Bn0[150];
wire p1_150 = Rsh_d1[150] ^ Bn1[150];
wire g0_150, g1_150, t0_150, t1_150;
MSKand_opini2_d2_pini u_g_150 (
    .ina({Rsh_d1[150], Rsh_d0[150]}), .inb({Bn1[150], Bn0[150]}),
    .rnd(r[300]), .s(s[300]), .clk(clk), .out({g1_150, g0_150}));
MSKand_opini2_d2_pini u_t_150 (
    .ina({fc1[150], fc0[150]}), .inb({p1_150, p0_150}),
    .rnd(r[301]), .s(s[301]), .clk(clk), .out({t1_150, t0_150}));
assign fc0[151] = g0_150 ^ t0_150;
assign fc1[151] = g1_150 ^ t1_150;
wire p0_151 = Rsh_d0[151] ^ Bn0[151];
wire p1_151 = Rsh_d1[151] ^ Bn1[151];
wire g0_151, g1_151, t0_151, t1_151;
MSKand_opini2_d2_pini u_g_151 (
    .ina({Rsh_d1[151], Rsh_d0[151]}), .inb({Bn1[151], Bn0[151]}),
    .rnd(r[302]), .s(s[302]), .clk(clk), .out({g1_151, g0_151}));
MSKand_opini2_d2_pini u_t_151 (
    .ina({fc1[151], fc0[151]}), .inb({p1_151, p0_151}),
    .rnd(r[303]), .s(s[303]), .clk(clk), .out({t1_151, t0_151}));
assign fc0[152] = g0_151 ^ t0_151;
assign fc1[152] = g1_151 ^ t1_151;
wire p0_152 = Rsh_d0[152] ^ Bn0[152];
wire p1_152 = Rsh_d1[152] ^ Bn1[152];
wire g0_152, g1_152, t0_152, t1_152;
MSKand_opini2_d2_pini u_g_152 (
    .ina({Rsh_d1[152], Rsh_d0[152]}), .inb({Bn1[152], Bn0[152]}),
    .rnd(r[304]), .s(s[304]), .clk(clk), .out({g1_152, g0_152}));
MSKand_opini2_d2_pini u_t_152 (
    .ina({fc1[152], fc0[152]}), .inb({p1_152, p0_152}),
    .rnd(r[305]), .s(s[305]), .clk(clk), .out({t1_152, t0_152}));
assign fc0[153] = g0_152 ^ t0_152;
assign fc1[153] = g1_152 ^ t1_152;
wire p0_153 = Rsh_d0[153] ^ Bn0[153];
wire p1_153 = Rsh_d1[153] ^ Bn1[153];
wire g0_153, g1_153, t0_153, t1_153;
MSKand_opini2_d2_pini u_g_153 (
    .ina({Rsh_d1[153], Rsh_d0[153]}), .inb({Bn1[153], Bn0[153]}),
    .rnd(r[306]), .s(s[306]), .clk(clk), .out({g1_153, g0_153}));
MSKand_opini2_d2_pini u_t_153 (
    .ina({fc1[153], fc0[153]}), .inb({p1_153, p0_153}),
    .rnd(r[307]), .s(s[307]), .clk(clk), .out({t1_153, t0_153}));
assign fc0[154] = g0_153 ^ t0_153;
assign fc1[154] = g1_153 ^ t1_153;
wire p0_154 = Rsh_d0[154] ^ Bn0[154];
wire p1_154 = Rsh_d1[154] ^ Bn1[154];
wire g0_154, g1_154, t0_154, t1_154;
MSKand_opini2_d2_pini u_g_154 (
    .ina({Rsh_d1[154], Rsh_d0[154]}), .inb({Bn1[154], Bn0[154]}),
    .rnd(r[308]), .s(s[308]), .clk(clk), .out({g1_154, g0_154}));
MSKand_opini2_d2_pini u_t_154 (
    .ina({fc1[154], fc0[154]}), .inb({p1_154, p0_154}),
    .rnd(r[309]), .s(s[309]), .clk(clk), .out({t1_154, t0_154}));
assign fc0[155] = g0_154 ^ t0_154;
assign fc1[155] = g1_154 ^ t1_154;
wire p0_155 = Rsh_d0[155] ^ Bn0[155];
wire p1_155 = Rsh_d1[155] ^ Bn1[155];
wire g0_155, g1_155, t0_155, t1_155;
MSKand_opini2_d2_pini u_g_155 (
    .ina({Rsh_d1[155], Rsh_d0[155]}), .inb({Bn1[155], Bn0[155]}),
    .rnd(r[310]), .s(s[310]), .clk(clk), .out({g1_155, g0_155}));
MSKand_opini2_d2_pini u_t_155 (
    .ina({fc1[155], fc0[155]}), .inb({p1_155, p0_155}),
    .rnd(r[311]), .s(s[311]), .clk(clk), .out({t1_155, t0_155}));
assign fc0[156] = g0_155 ^ t0_155;
assign fc1[156] = g1_155 ^ t1_155;
wire p0_156 = Rsh_d0[156] ^ Bn0[156];
wire p1_156 = Rsh_d1[156] ^ Bn1[156];
wire g0_156, g1_156, t0_156, t1_156;
MSKand_opini2_d2_pini u_g_156 (
    .ina({Rsh_d1[156], Rsh_d0[156]}), .inb({Bn1[156], Bn0[156]}),
    .rnd(r[312]), .s(s[312]), .clk(clk), .out({g1_156, g0_156}));
MSKand_opini2_d2_pini u_t_156 (
    .ina({fc1[156], fc0[156]}), .inb({p1_156, p0_156}),
    .rnd(r[313]), .s(s[313]), .clk(clk), .out({t1_156, t0_156}));
assign fc0[157] = g0_156 ^ t0_156;
assign fc1[157] = g1_156 ^ t1_156;
wire p0_157 = Rsh_d0[157] ^ Bn0[157];
wire p1_157 = Rsh_d1[157] ^ Bn1[157];
wire g0_157, g1_157, t0_157, t1_157;
MSKand_opini2_d2_pini u_g_157 (
    .ina({Rsh_d1[157], Rsh_d0[157]}), .inb({Bn1[157], Bn0[157]}),
    .rnd(r[314]), .s(s[314]), .clk(clk), .out({g1_157, g0_157}));
MSKand_opini2_d2_pini u_t_157 (
    .ina({fc1[157], fc0[157]}), .inb({p1_157, p0_157}),
    .rnd(r[315]), .s(s[315]), .clk(clk), .out({t1_157, t0_157}));
assign fc0[158] = g0_157 ^ t0_157;
assign fc1[158] = g1_157 ^ t1_157;
wire p0_158 = Rsh_d0[158] ^ Bn0[158];
wire p1_158 = Rsh_d1[158] ^ Bn1[158];
wire g0_158, g1_158, t0_158, t1_158;
MSKand_opini2_d2_pini u_g_158 (
    .ina({Rsh_d1[158], Rsh_d0[158]}), .inb({Bn1[158], Bn0[158]}),
    .rnd(r[316]), .s(s[316]), .clk(clk), .out({g1_158, g0_158}));
MSKand_opini2_d2_pini u_t_158 (
    .ina({fc1[158], fc0[158]}), .inb({p1_158, p0_158}),
    .rnd(r[317]), .s(s[317]), .clk(clk), .out({t1_158, t0_158}));
assign fc0[159] = g0_158 ^ t0_158;
assign fc1[159] = g1_158 ^ t1_158;
wire p0_159 = Rsh_d0[159] ^ Bn0[159];
wire p1_159 = Rsh_d1[159] ^ Bn1[159];
wire g0_159, g1_159, t0_159, t1_159;
MSKand_opini2_d2_pini u_g_159 (
    .ina({Rsh_d1[159], Rsh_d0[159]}), .inb({Bn1[159], Bn0[159]}),
    .rnd(r[318]), .s(s[318]), .clk(clk), .out({g1_159, g0_159}));
MSKand_opini2_d2_pini u_t_159 (
    .ina({fc1[159], fc0[159]}), .inb({p1_159, p0_159}),
    .rnd(r[319]), .s(s[319]), .clk(clk), .out({t1_159, t0_159}));
assign fc0[160] = g0_159 ^ t0_159;
assign fc1[160] = g1_159 ^ t1_159;
wire p0_160 = Rsh_d0[160] ^ Bn0[160];
wire p1_160 = Rsh_d1[160] ^ Bn1[160];
wire g0_160, g1_160, t0_160, t1_160;
MSKand_opini2_d2_pini u_g_160 (
    .ina({Rsh_d1[160], Rsh_d0[160]}), .inb({Bn1[160], Bn0[160]}),
    .rnd(r[320]), .s(s[320]), .clk(clk), .out({g1_160, g0_160}));
MSKand_opini2_d2_pini u_t_160 (
    .ina({fc1[160], fc0[160]}), .inb({p1_160, p0_160}),
    .rnd(r[321]), .s(s[321]), .clk(clk), .out({t1_160, t0_160}));
assign fc0[161] = g0_160 ^ t0_160;
assign fc1[161] = g1_160 ^ t1_160;
wire p0_161 = Rsh_d0[161] ^ Bn0[161];
wire p1_161 = Rsh_d1[161] ^ Bn1[161];
wire g0_161, g1_161, t0_161, t1_161;
MSKand_opini2_d2_pini u_g_161 (
    .ina({Rsh_d1[161], Rsh_d0[161]}), .inb({Bn1[161], Bn0[161]}),
    .rnd(r[322]), .s(s[322]), .clk(clk), .out({g1_161, g0_161}));
MSKand_opini2_d2_pini u_t_161 (
    .ina({fc1[161], fc0[161]}), .inb({p1_161, p0_161}),
    .rnd(r[323]), .s(s[323]), .clk(clk), .out({t1_161, t0_161}));
assign fc0[162] = g0_161 ^ t0_161;
assign fc1[162] = g1_161 ^ t1_161;
wire p0_162 = Rsh_d0[162] ^ Bn0[162];
wire p1_162 = Rsh_d1[162] ^ Bn1[162];
wire g0_162, g1_162, t0_162, t1_162;
MSKand_opini2_d2_pini u_g_162 (
    .ina({Rsh_d1[162], Rsh_d0[162]}), .inb({Bn1[162], Bn0[162]}),
    .rnd(r[324]), .s(s[324]), .clk(clk), .out({g1_162, g0_162}));
MSKand_opini2_d2_pini u_t_162 (
    .ina({fc1[162], fc0[162]}), .inb({p1_162, p0_162}),
    .rnd(r[325]), .s(s[325]), .clk(clk), .out({t1_162, t0_162}));
assign fc0[163] = g0_162 ^ t0_162;
assign fc1[163] = g1_162 ^ t1_162;
wire p0_163 = Rsh_d0[163] ^ Bn0[163];
wire p1_163 = Rsh_d1[163] ^ Bn1[163];
wire g0_163, g1_163, t0_163, t1_163;
MSKand_opini2_d2_pini u_g_163 (
    .ina({Rsh_d1[163], Rsh_d0[163]}), .inb({Bn1[163], Bn0[163]}),
    .rnd(r[326]), .s(s[326]), .clk(clk), .out({g1_163, g0_163}));
MSKand_opini2_d2_pini u_t_163 (
    .ina({fc1[163], fc0[163]}), .inb({p1_163, p0_163}),
    .rnd(r[327]), .s(s[327]), .clk(clk), .out({t1_163, t0_163}));
assign fc0[164] = g0_163 ^ t0_163;
assign fc1[164] = g1_163 ^ t1_163;
wire p0_164 = Rsh_d0[164] ^ Bn0[164];
wire p1_164 = Rsh_d1[164] ^ Bn1[164];
wire g0_164, g1_164, t0_164, t1_164;
MSKand_opini2_d2_pini u_g_164 (
    .ina({Rsh_d1[164], Rsh_d0[164]}), .inb({Bn1[164], Bn0[164]}),
    .rnd(r[328]), .s(s[328]), .clk(clk), .out({g1_164, g0_164}));
MSKand_opini2_d2_pini u_t_164 (
    .ina({fc1[164], fc0[164]}), .inb({p1_164, p0_164}),
    .rnd(r[329]), .s(s[329]), .clk(clk), .out({t1_164, t0_164}));
assign fc0[165] = g0_164 ^ t0_164;
assign fc1[165] = g1_164 ^ t1_164;
wire p0_165 = Rsh_d0[165] ^ Bn0[165];
wire p1_165 = Rsh_d1[165] ^ Bn1[165];
wire g0_165, g1_165, t0_165, t1_165;
MSKand_opini2_d2_pini u_g_165 (
    .ina({Rsh_d1[165], Rsh_d0[165]}), .inb({Bn1[165], Bn0[165]}),
    .rnd(r[330]), .s(s[330]), .clk(clk), .out({g1_165, g0_165}));
MSKand_opini2_d2_pini u_t_165 (
    .ina({fc1[165], fc0[165]}), .inb({p1_165, p0_165}),
    .rnd(r[331]), .s(s[331]), .clk(clk), .out({t1_165, t0_165}));
assign fc0[166] = g0_165 ^ t0_165;
assign fc1[166] = g1_165 ^ t1_165;
wire p0_166 = Rsh_d0[166] ^ Bn0[166];
wire p1_166 = Rsh_d1[166] ^ Bn1[166];
wire g0_166, g1_166, t0_166, t1_166;
MSKand_opini2_d2_pini u_g_166 (
    .ina({Rsh_d1[166], Rsh_d0[166]}), .inb({Bn1[166], Bn0[166]}),
    .rnd(r[332]), .s(s[332]), .clk(clk), .out({g1_166, g0_166}));
MSKand_opini2_d2_pini u_t_166 (
    .ina({fc1[166], fc0[166]}), .inb({p1_166, p0_166}),
    .rnd(r[333]), .s(s[333]), .clk(clk), .out({t1_166, t0_166}));
assign fc0[167] = g0_166 ^ t0_166;
assign fc1[167] = g1_166 ^ t1_166;
wire p0_167 = Rsh_d0[167] ^ Bn0[167];
wire p1_167 = Rsh_d1[167] ^ Bn1[167];
wire g0_167, g1_167, t0_167, t1_167;
MSKand_opini2_d2_pini u_g_167 (
    .ina({Rsh_d1[167], Rsh_d0[167]}), .inb({Bn1[167], Bn0[167]}),
    .rnd(r[334]), .s(s[334]), .clk(clk), .out({g1_167, g0_167}));
MSKand_opini2_d2_pini u_t_167 (
    .ina({fc1[167], fc0[167]}), .inb({p1_167, p0_167}),
    .rnd(r[335]), .s(s[335]), .clk(clk), .out({t1_167, t0_167}));
assign fc0[168] = g0_167 ^ t0_167;
assign fc1[168] = g1_167 ^ t1_167;
wire p0_168 = Rsh_d0[168] ^ Bn0[168];
wire p1_168 = Rsh_d1[168] ^ Bn1[168];
wire g0_168, g1_168, t0_168, t1_168;
MSKand_opini2_d2_pini u_g_168 (
    .ina({Rsh_d1[168], Rsh_d0[168]}), .inb({Bn1[168], Bn0[168]}),
    .rnd(r[336]), .s(s[336]), .clk(clk), .out({g1_168, g0_168}));
MSKand_opini2_d2_pini u_t_168 (
    .ina({fc1[168], fc0[168]}), .inb({p1_168, p0_168}),
    .rnd(r[337]), .s(s[337]), .clk(clk), .out({t1_168, t0_168}));
assign fc0[169] = g0_168 ^ t0_168;
assign fc1[169] = g1_168 ^ t1_168;
wire p0_169 = Rsh_d0[169] ^ Bn0[169];
wire p1_169 = Rsh_d1[169] ^ Bn1[169];
wire g0_169, g1_169, t0_169, t1_169;
MSKand_opini2_d2_pini u_g_169 (
    .ina({Rsh_d1[169], Rsh_d0[169]}), .inb({Bn1[169], Bn0[169]}),
    .rnd(r[338]), .s(s[338]), .clk(clk), .out({g1_169, g0_169}));
MSKand_opini2_d2_pini u_t_169 (
    .ina({fc1[169], fc0[169]}), .inb({p1_169, p0_169}),
    .rnd(r[339]), .s(s[339]), .clk(clk), .out({t1_169, t0_169}));
assign fc0[170] = g0_169 ^ t0_169;
assign fc1[170] = g1_169 ^ t1_169;
wire p0_170 = Rsh_d0[170] ^ Bn0[170];
wire p1_170 = Rsh_d1[170] ^ Bn1[170];
wire g0_170, g1_170, t0_170, t1_170;
MSKand_opini2_d2_pini u_g_170 (
    .ina({Rsh_d1[170], Rsh_d0[170]}), .inb({Bn1[170], Bn0[170]}),
    .rnd(r[340]), .s(s[340]), .clk(clk), .out({g1_170, g0_170}));
MSKand_opini2_d2_pini u_t_170 (
    .ina({fc1[170], fc0[170]}), .inb({p1_170, p0_170}),
    .rnd(r[341]), .s(s[341]), .clk(clk), .out({t1_170, t0_170}));
assign fc0[171] = g0_170 ^ t0_170;
assign fc1[171] = g1_170 ^ t1_170;
wire p0_171 = Rsh_d0[171] ^ Bn0[171];
wire p1_171 = Rsh_d1[171] ^ Bn1[171];
wire g0_171, g1_171, t0_171, t1_171;
MSKand_opini2_d2_pini u_g_171 (
    .ina({Rsh_d1[171], Rsh_d0[171]}), .inb({Bn1[171], Bn0[171]}),
    .rnd(r[342]), .s(s[342]), .clk(clk), .out({g1_171, g0_171}));
MSKand_opini2_d2_pini u_t_171 (
    .ina({fc1[171], fc0[171]}), .inb({p1_171, p0_171}),
    .rnd(r[343]), .s(s[343]), .clk(clk), .out({t1_171, t0_171}));
assign fc0[172] = g0_171 ^ t0_171;
assign fc1[172] = g1_171 ^ t1_171;
wire p0_172 = Rsh_d0[172] ^ Bn0[172];
wire p1_172 = Rsh_d1[172] ^ Bn1[172];
wire g0_172, g1_172, t0_172, t1_172;
MSKand_opini2_d2_pini u_g_172 (
    .ina({Rsh_d1[172], Rsh_d0[172]}), .inb({Bn1[172], Bn0[172]}),
    .rnd(r[344]), .s(s[344]), .clk(clk), .out({g1_172, g0_172}));
MSKand_opini2_d2_pini u_t_172 (
    .ina({fc1[172], fc0[172]}), .inb({p1_172, p0_172}),
    .rnd(r[345]), .s(s[345]), .clk(clk), .out({t1_172, t0_172}));
assign fc0[173] = g0_172 ^ t0_172;
assign fc1[173] = g1_172 ^ t1_172;
wire p0_173 = Rsh_d0[173] ^ Bn0[173];
wire p1_173 = Rsh_d1[173] ^ Bn1[173];
wire g0_173, g1_173, t0_173, t1_173;
MSKand_opini2_d2_pini u_g_173 (
    .ina({Rsh_d1[173], Rsh_d0[173]}), .inb({Bn1[173], Bn0[173]}),
    .rnd(r[346]), .s(s[346]), .clk(clk), .out({g1_173, g0_173}));
MSKand_opini2_d2_pini u_t_173 (
    .ina({fc1[173], fc0[173]}), .inb({p1_173, p0_173}),
    .rnd(r[347]), .s(s[347]), .clk(clk), .out({t1_173, t0_173}));
assign fc0[174] = g0_173 ^ t0_173;
assign fc1[174] = g1_173 ^ t1_173;
wire p0_174 = Rsh_d0[174] ^ Bn0[174];
wire p1_174 = Rsh_d1[174] ^ Bn1[174];
wire g0_174, g1_174, t0_174, t1_174;
MSKand_opini2_d2_pini u_g_174 (
    .ina({Rsh_d1[174], Rsh_d0[174]}), .inb({Bn1[174], Bn0[174]}),
    .rnd(r[348]), .s(s[348]), .clk(clk), .out({g1_174, g0_174}));
MSKand_opini2_d2_pini u_t_174 (
    .ina({fc1[174], fc0[174]}), .inb({p1_174, p0_174}),
    .rnd(r[349]), .s(s[349]), .clk(clk), .out({t1_174, t0_174}));
assign fc0[175] = g0_174 ^ t0_174;
assign fc1[175] = g1_174 ^ t1_174;
wire p0_175 = Rsh_d0[175] ^ Bn0[175];
wire p1_175 = Rsh_d1[175] ^ Bn1[175];
wire g0_175, g1_175, t0_175, t1_175;
MSKand_opini2_d2_pini u_g_175 (
    .ina({Rsh_d1[175], Rsh_d0[175]}), .inb({Bn1[175], Bn0[175]}),
    .rnd(r[350]), .s(s[350]), .clk(clk), .out({g1_175, g0_175}));
MSKand_opini2_d2_pini u_t_175 (
    .ina({fc1[175], fc0[175]}), .inb({p1_175, p0_175}),
    .rnd(r[351]), .s(s[351]), .clk(clk), .out({t1_175, t0_175}));
assign fc0[176] = g0_175 ^ t0_175;
assign fc1[176] = g1_175 ^ t1_175;
wire p0_176 = Rsh_d0[176] ^ Bn0[176];
wire p1_176 = Rsh_d1[176] ^ Bn1[176];
wire g0_176, g1_176, t0_176, t1_176;
MSKand_opini2_d2_pini u_g_176 (
    .ina({Rsh_d1[176], Rsh_d0[176]}), .inb({Bn1[176], Bn0[176]}),
    .rnd(r[352]), .s(s[352]), .clk(clk), .out({g1_176, g0_176}));
MSKand_opini2_d2_pini u_t_176 (
    .ina({fc1[176], fc0[176]}), .inb({p1_176, p0_176}),
    .rnd(r[353]), .s(s[353]), .clk(clk), .out({t1_176, t0_176}));
assign fc0[177] = g0_176 ^ t0_176;
assign fc1[177] = g1_176 ^ t1_176;
wire p0_177 = Rsh_d0[177] ^ Bn0[177];
wire p1_177 = Rsh_d1[177] ^ Bn1[177];
wire g0_177, g1_177, t0_177, t1_177;
MSKand_opini2_d2_pini u_g_177 (
    .ina({Rsh_d1[177], Rsh_d0[177]}), .inb({Bn1[177], Bn0[177]}),
    .rnd(r[354]), .s(s[354]), .clk(clk), .out({g1_177, g0_177}));
MSKand_opini2_d2_pini u_t_177 (
    .ina({fc1[177], fc0[177]}), .inb({p1_177, p0_177}),
    .rnd(r[355]), .s(s[355]), .clk(clk), .out({t1_177, t0_177}));
assign fc0[178] = g0_177 ^ t0_177;
assign fc1[178] = g1_177 ^ t1_177;
wire p0_178 = Rsh_d0[178] ^ Bn0[178];
wire p1_178 = Rsh_d1[178] ^ Bn1[178];
wire g0_178, g1_178, t0_178, t1_178;
MSKand_opini2_d2_pini u_g_178 (
    .ina({Rsh_d1[178], Rsh_d0[178]}), .inb({Bn1[178], Bn0[178]}),
    .rnd(r[356]), .s(s[356]), .clk(clk), .out({g1_178, g0_178}));
MSKand_opini2_d2_pini u_t_178 (
    .ina({fc1[178], fc0[178]}), .inb({p1_178, p0_178}),
    .rnd(r[357]), .s(s[357]), .clk(clk), .out({t1_178, t0_178}));
assign fc0[179] = g0_178 ^ t0_178;
assign fc1[179] = g1_178 ^ t1_178;
wire p0_179 = Rsh_d0[179] ^ Bn0[179];
wire p1_179 = Rsh_d1[179] ^ Bn1[179];
wire g0_179, g1_179, t0_179, t1_179;
MSKand_opini2_d2_pini u_g_179 (
    .ina({Rsh_d1[179], Rsh_d0[179]}), .inb({Bn1[179], Bn0[179]}),
    .rnd(r[358]), .s(s[358]), .clk(clk), .out({g1_179, g0_179}));
MSKand_opini2_d2_pini u_t_179 (
    .ina({fc1[179], fc0[179]}), .inb({p1_179, p0_179}),
    .rnd(r[359]), .s(s[359]), .clk(clk), .out({t1_179, t0_179}));
assign fc0[180] = g0_179 ^ t0_179;
assign fc1[180] = g1_179 ^ t1_179;
wire p0_180 = Rsh_d0[180] ^ Bn0[180];
wire p1_180 = Rsh_d1[180] ^ Bn1[180];
wire g0_180, g1_180, t0_180, t1_180;
MSKand_opini2_d2_pini u_g_180 (
    .ina({Rsh_d1[180], Rsh_d0[180]}), .inb({Bn1[180], Bn0[180]}),
    .rnd(r[360]), .s(s[360]), .clk(clk), .out({g1_180, g0_180}));
MSKand_opini2_d2_pini u_t_180 (
    .ina({fc1[180], fc0[180]}), .inb({p1_180, p0_180}),
    .rnd(r[361]), .s(s[361]), .clk(clk), .out({t1_180, t0_180}));
assign fc0[181] = g0_180 ^ t0_180;
assign fc1[181] = g1_180 ^ t1_180;
wire p0_181 = Rsh_d0[181] ^ Bn0[181];
wire p1_181 = Rsh_d1[181] ^ Bn1[181];
wire g0_181, g1_181, t0_181, t1_181;
MSKand_opini2_d2_pini u_g_181 (
    .ina({Rsh_d1[181], Rsh_d0[181]}), .inb({Bn1[181], Bn0[181]}),
    .rnd(r[362]), .s(s[362]), .clk(clk), .out({g1_181, g0_181}));
MSKand_opini2_d2_pini u_t_181 (
    .ina({fc1[181], fc0[181]}), .inb({p1_181, p0_181}),
    .rnd(r[363]), .s(s[363]), .clk(clk), .out({t1_181, t0_181}));
assign fc0[182] = g0_181 ^ t0_181;
assign fc1[182] = g1_181 ^ t1_181;
wire p0_182 = Rsh_d0[182] ^ Bn0[182];
wire p1_182 = Rsh_d1[182] ^ Bn1[182];
wire g0_182, g1_182, t0_182, t1_182;
MSKand_opini2_d2_pini u_g_182 (
    .ina({Rsh_d1[182], Rsh_d0[182]}), .inb({Bn1[182], Bn0[182]}),
    .rnd(r[364]), .s(s[364]), .clk(clk), .out({g1_182, g0_182}));
MSKand_opini2_d2_pini u_t_182 (
    .ina({fc1[182], fc0[182]}), .inb({p1_182, p0_182}),
    .rnd(r[365]), .s(s[365]), .clk(clk), .out({t1_182, t0_182}));
assign fc0[183] = g0_182 ^ t0_182;
assign fc1[183] = g1_182 ^ t1_182;
wire p0_183 = Rsh_d0[183] ^ Bn0[183];
wire p1_183 = Rsh_d1[183] ^ Bn1[183];
wire g0_183, g1_183, t0_183, t1_183;
MSKand_opini2_d2_pini u_g_183 (
    .ina({Rsh_d1[183], Rsh_d0[183]}), .inb({Bn1[183], Bn0[183]}),
    .rnd(r[366]), .s(s[366]), .clk(clk), .out({g1_183, g0_183}));
MSKand_opini2_d2_pini u_t_183 (
    .ina({fc1[183], fc0[183]}), .inb({p1_183, p0_183}),
    .rnd(r[367]), .s(s[367]), .clk(clk), .out({t1_183, t0_183}));
assign fc0[184] = g0_183 ^ t0_183;
assign fc1[184] = g1_183 ^ t1_183;
wire p0_184 = Rsh_d0[184] ^ Bn0[184];
wire p1_184 = Rsh_d1[184] ^ Bn1[184];
wire g0_184, g1_184, t0_184, t1_184;
MSKand_opini2_d2_pini u_g_184 (
    .ina({Rsh_d1[184], Rsh_d0[184]}), .inb({Bn1[184], Bn0[184]}),
    .rnd(r[368]), .s(s[368]), .clk(clk), .out({g1_184, g0_184}));
MSKand_opini2_d2_pini u_t_184 (
    .ina({fc1[184], fc0[184]}), .inb({p1_184, p0_184}),
    .rnd(r[369]), .s(s[369]), .clk(clk), .out({t1_184, t0_184}));
assign fc0[185] = g0_184 ^ t0_184;
assign fc1[185] = g1_184 ^ t1_184;
wire p0_185 = Rsh_d0[185] ^ Bn0[185];
wire p1_185 = Rsh_d1[185] ^ Bn1[185];
wire g0_185, g1_185, t0_185, t1_185;
MSKand_opini2_d2_pini u_g_185 (
    .ina({Rsh_d1[185], Rsh_d0[185]}), .inb({Bn1[185], Bn0[185]}),
    .rnd(r[370]), .s(s[370]), .clk(clk), .out({g1_185, g0_185}));
MSKand_opini2_d2_pini u_t_185 (
    .ina({fc1[185], fc0[185]}), .inb({p1_185, p0_185}),
    .rnd(r[371]), .s(s[371]), .clk(clk), .out({t1_185, t0_185}));
assign fc0[186] = g0_185 ^ t0_185;
assign fc1[186] = g1_185 ^ t1_185;
wire p0_186 = Rsh_d0[186] ^ Bn0[186];
wire p1_186 = Rsh_d1[186] ^ Bn1[186];
wire g0_186, g1_186, t0_186, t1_186;
MSKand_opini2_d2_pini u_g_186 (
    .ina({Rsh_d1[186], Rsh_d0[186]}), .inb({Bn1[186], Bn0[186]}),
    .rnd(r[372]), .s(s[372]), .clk(clk), .out({g1_186, g0_186}));
MSKand_opini2_d2_pini u_t_186 (
    .ina({fc1[186], fc0[186]}), .inb({p1_186, p0_186}),
    .rnd(r[373]), .s(s[373]), .clk(clk), .out({t1_186, t0_186}));
assign fc0[187] = g0_186 ^ t0_186;
assign fc1[187] = g1_186 ^ t1_186;
wire p0_187 = Rsh_d0[187] ^ Bn0[187];
wire p1_187 = Rsh_d1[187] ^ Bn1[187];
wire g0_187, g1_187, t0_187, t1_187;
MSKand_opini2_d2_pini u_g_187 (
    .ina({Rsh_d1[187], Rsh_d0[187]}), .inb({Bn1[187], Bn0[187]}),
    .rnd(r[374]), .s(s[374]), .clk(clk), .out({g1_187, g0_187}));
MSKand_opini2_d2_pini u_t_187 (
    .ina({fc1[187], fc0[187]}), .inb({p1_187, p0_187}),
    .rnd(r[375]), .s(s[375]), .clk(clk), .out({t1_187, t0_187}));
assign fc0[188] = g0_187 ^ t0_187;
assign fc1[188] = g1_187 ^ t1_187;
wire p0_188 = Rsh_d0[188] ^ Bn0[188];
wire p1_188 = Rsh_d1[188] ^ Bn1[188];
wire g0_188, g1_188, t0_188, t1_188;
MSKand_opini2_d2_pini u_g_188 (
    .ina({Rsh_d1[188], Rsh_d0[188]}), .inb({Bn1[188], Bn0[188]}),
    .rnd(r[376]), .s(s[376]), .clk(clk), .out({g1_188, g0_188}));
MSKand_opini2_d2_pini u_t_188 (
    .ina({fc1[188], fc0[188]}), .inb({p1_188, p0_188}),
    .rnd(r[377]), .s(s[377]), .clk(clk), .out({t1_188, t0_188}));
assign fc0[189] = g0_188 ^ t0_188;
assign fc1[189] = g1_188 ^ t1_188;
wire p0_189 = Rsh_d0[189] ^ Bn0[189];
wire p1_189 = Rsh_d1[189] ^ Bn1[189];
wire g0_189, g1_189, t0_189, t1_189;
MSKand_opini2_d2_pini u_g_189 (
    .ina({Rsh_d1[189], Rsh_d0[189]}), .inb({Bn1[189], Bn0[189]}),
    .rnd(r[378]), .s(s[378]), .clk(clk), .out({g1_189, g0_189}));
MSKand_opini2_d2_pini u_t_189 (
    .ina({fc1[189], fc0[189]}), .inb({p1_189, p0_189}),
    .rnd(r[379]), .s(s[379]), .clk(clk), .out({t1_189, t0_189}));
assign fc0[190] = g0_189 ^ t0_189;
assign fc1[190] = g1_189 ^ t1_189;
wire p0_190 = Rsh_d0[190] ^ Bn0[190];
wire p1_190 = Rsh_d1[190] ^ Bn1[190];
wire g0_190, g1_190, t0_190, t1_190;
MSKand_opini2_d2_pini u_g_190 (
    .ina({Rsh_d1[190], Rsh_d0[190]}), .inb({Bn1[190], Bn0[190]}),
    .rnd(r[380]), .s(s[380]), .clk(clk), .out({g1_190, g0_190}));
MSKand_opini2_d2_pini u_t_190 (
    .ina({fc1[190], fc0[190]}), .inb({p1_190, p0_190}),
    .rnd(r[381]), .s(s[381]), .clk(clk), .out({t1_190, t0_190}));
assign fc0[191] = g0_190 ^ t0_190;
assign fc1[191] = g1_190 ^ t1_190;
wire p0_191 = Rsh_d0[191] ^ Bn0[191];
wire p1_191 = Rsh_d1[191] ^ Bn1[191];
wire g0_191, g1_191, t0_191, t1_191;
MSKand_opini2_d2_pini u_g_191 (
    .ina({Rsh_d1[191], Rsh_d0[191]}), .inb({Bn1[191], Bn0[191]}),
    .rnd(r[382]), .s(s[382]), .clk(clk), .out({g1_191, g0_191}));
MSKand_opini2_d2_pini u_t_191 (
    .ina({fc1[191], fc0[191]}), .inb({p1_191, p0_191}),
    .rnd(r[383]), .s(s[383]), .clk(clk), .out({t1_191, t0_191}));
assign fc0[192] = g0_191 ^ t0_191;
assign fc1[192] = g1_191 ^ t1_191;
wire p0_192 = Rsh_d0[192] ^ Bn0[192];
wire p1_192 = Rsh_d1[192] ^ Bn1[192];
wire g0_192, g1_192, t0_192, t1_192;
MSKand_opini2_d2_pini u_g_192 (
    .ina({Rsh_d1[192], Rsh_d0[192]}), .inb({Bn1[192], Bn0[192]}),
    .rnd(r[384]), .s(s[384]), .clk(clk), .out({g1_192, g0_192}));
MSKand_opini2_d2_pini u_t_192 (
    .ina({fc1[192], fc0[192]}), .inb({p1_192, p0_192}),
    .rnd(r[385]), .s(s[385]), .clk(clk), .out({t1_192, t0_192}));
assign fc0[193] = g0_192 ^ t0_192;
assign fc1[193] = g1_192 ^ t1_192;
wire p0_193 = Rsh_d0[193] ^ Bn0[193];
wire p1_193 = Rsh_d1[193] ^ Bn1[193];
wire g0_193, g1_193, t0_193, t1_193;
MSKand_opini2_d2_pini u_g_193 (
    .ina({Rsh_d1[193], Rsh_d0[193]}), .inb({Bn1[193], Bn0[193]}),
    .rnd(r[386]), .s(s[386]), .clk(clk), .out({g1_193, g0_193}));
MSKand_opini2_d2_pini u_t_193 (
    .ina({fc1[193], fc0[193]}), .inb({p1_193, p0_193}),
    .rnd(r[387]), .s(s[387]), .clk(clk), .out({t1_193, t0_193}));
assign fc0[194] = g0_193 ^ t0_193;
assign fc1[194] = g1_193 ^ t1_193;
wire p0_194 = Rsh_d0[194] ^ Bn0[194];
wire p1_194 = Rsh_d1[194] ^ Bn1[194];
wire g0_194, g1_194, t0_194, t1_194;
MSKand_opini2_d2_pini u_g_194 (
    .ina({Rsh_d1[194], Rsh_d0[194]}), .inb({Bn1[194], Bn0[194]}),
    .rnd(r[388]), .s(s[388]), .clk(clk), .out({g1_194, g0_194}));
MSKand_opini2_d2_pini u_t_194 (
    .ina({fc1[194], fc0[194]}), .inb({p1_194, p0_194}),
    .rnd(r[389]), .s(s[389]), .clk(clk), .out({t1_194, t0_194}));
assign fc0[195] = g0_194 ^ t0_194;
assign fc1[195] = g1_194 ^ t1_194;
wire p0_195 = Rsh_d0[195] ^ Bn0[195];
wire p1_195 = Rsh_d1[195] ^ Bn1[195];
wire g0_195, g1_195, t0_195, t1_195;
MSKand_opini2_d2_pini u_g_195 (
    .ina({Rsh_d1[195], Rsh_d0[195]}), .inb({Bn1[195], Bn0[195]}),
    .rnd(r[390]), .s(s[390]), .clk(clk), .out({g1_195, g0_195}));
MSKand_opini2_d2_pini u_t_195 (
    .ina({fc1[195], fc0[195]}), .inb({p1_195, p0_195}),
    .rnd(r[391]), .s(s[391]), .clk(clk), .out({t1_195, t0_195}));
assign fc0[196] = g0_195 ^ t0_195;
assign fc1[196] = g1_195 ^ t1_195;
wire p0_196 = Rsh_d0[196] ^ Bn0[196];
wire p1_196 = Rsh_d1[196] ^ Bn1[196];
wire g0_196, g1_196, t0_196, t1_196;
MSKand_opini2_d2_pini u_g_196 (
    .ina({Rsh_d1[196], Rsh_d0[196]}), .inb({Bn1[196], Bn0[196]}),
    .rnd(r[392]), .s(s[392]), .clk(clk), .out({g1_196, g0_196}));
MSKand_opini2_d2_pini u_t_196 (
    .ina({fc1[196], fc0[196]}), .inb({p1_196, p0_196}),
    .rnd(r[393]), .s(s[393]), .clk(clk), .out({t1_196, t0_196}));
assign fc0[197] = g0_196 ^ t0_196;
assign fc1[197] = g1_196 ^ t1_196;
wire p0_197 = Rsh_d0[197] ^ Bn0[197];
wire p1_197 = Rsh_d1[197] ^ Bn1[197];
wire g0_197, g1_197, t0_197, t1_197;
MSKand_opini2_d2_pini u_g_197 (
    .ina({Rsh_d1[197], Rsh_d0[197]}), .inb({Bn1[197], Bn0[197]}),
    .rnd(r[394]), .s(s[394]), .clk(clk), .out({g1_197, g0_197}));
MSKand_opini2_d2_pini u_t_197 (
    .ina({fc1[197], fc0[197]}), .inb({p1_197, p0_197}),
    .rnd(r[395]), .s(s[395]), .clk(clk), .out({t1_197, t0_197}));
assign fc0[198] = g0_197 ^ t0_197;
assign fc1[198] = g1_197 ^ t1_197;
wire p0_198 = Rsh_d0[198] ^ Bn0[198];
wire p1_198 = Rsh_d1[198] ^ Bn1[198];
wire g0_198, g1_198, t0_198, t1_198;
MSKand_opini2_d2_pini u_g_198 (
    .ina({Rsh_d1[198], Rsh_d0[198]}), .inb({Bn1[198], Bn0[198]}),
    .rnd(r[396]), .s(s[396]), .clk(clk), .out({g1_198, g0_198}));
MSKand_opini2_d2_pini u_t_198 (
    .ina({fc1[198], fc0[198]}), .inb({p1_198, p0_198}),
    .rnd(r[397]), .s(s[397]), .clk(clk), .out({t1_198, t0_198}));
assign fc0[199] = g0_198 ^ t0_198;
assign fc1[199] = g1_198 ^ t1_198;
wire p0_199 = Rsh_d0[199] ^ Bn0[199];
wire p1_199 = Rsh_d1[199] ^ Bn1[199];
wire g0_199, g1_199, t0_199, t1_199;
MSKand_opini2_d2_pini u_g_199 (
    .ina({Rsh_d1[199], Rsh_d0[199]}), .inb({Bn1[199], Bn0[199]}),
    .rnd(r[398]), .s(s[398]), .clk(clk), .out({g1_199, g0_199}));
MSKand_opini2_d2_pini u_t_199 (
    .ina({fc1[199], fc0[199]}), .inb({p1_199, p0_199}),
    .rnd(r[399]), .s(s[399]), .clk(clk), .out({t1_199, t0_199}));
assign fc0[200] = g0_199 ^ t0_199;
assign fc1[200] = g1_199 ^ t1_199;
wire p0_200 = Rsh_d0[200] ^ Bn0[200];
wire p1_200 = Rsh_d1[200] ^ Bn1[200];
wire g0_200, g1_200, t0_200, t1_200;
MSKand_opini2_d2_pini u_g_200 (
    .ina({Rsh_d1[200], Rsh_d0[200]}), .inb({Bn1[200], Bn0[200]}),
    .rnd(r[400]), .s(s[400]), .clk(clk), .out({g1_200, g0_200}));
MSKand_opini2_d2_pini u_t_200 (
    .ina({fc1[200], fc0[200]}), .inb({p1_200, p0_200}),
    .rnd(r[401]), .s(s[401]), .clk(clk), .out({t1_200, t0_200}));
assign fc0[201] = g0_200 ^ t0_200;
assign fc1[201] = g1_200 ^ t1_200;
wire p0_201 = Rsh_d0[201] ^ Bn0[201];
wire p1_201 = Rsh_d1[201] ^ Bn1[201];
wire g0_201, g1_201, t0_201, t1_201;
MSKand_opini2_d2_pini u_g_201 (
    .ina({Rsh_d1[201], Rsh_d0[201]}), .inb({Bn1[201], Bn0[201]}),
    .rnd(r[402]), .s(s[402]), .clk(clk), .out({g1_201, g0_201}));
MSKand_opini2_d2_pini u_t_201 (
    .ina({fc1[201], fc0[201]}), .inb({p1_201, p0_201}),
    .rnd(r[403]), .s(s[403]), .clk(clk), .out({t1_201, t0_201}));
assign fc0[202] = g0_201 ^ t0_201;
assign fc1[202] = g1_201 ^ t1_201;
wire p0_202 = Rsh_d0[202] ^ Bn0[202];
wire p1_202 = Rsh_d1[202] ^ Bn1[202];
wire g0_202, g1_202, t0_202, t1_202;
MSKand_opini2_d2_pini u_g_202 (
    .ina({Rsh_d1[202], Rsh_d0[202]}), .inb({Bn1[202], Bn0[202]}),
    .rnd(r[404]), .s(s[404]), .clk(clk), .out({g1_202, g0_202}));
MSKand_opini2_d2_pini u_t_202 (
    .ina({fc1[202], fc0[202]}), .inb({p1_202, p0_202}),
    .rnd(r[405]), .s(s[405]), .clk(clk), .out({t1_202, t0_202}));
assign fc0[203] = g0_202 ^ t0_202;
assign fc1[203] = g1_202 ^ t1_202;
wire p0_203 = Rsh_d0[203] ^ Bn0[203];
wire p1_203 = Rsh_d1[203] ^ Bn1[203];
wire g0_203, g1_203, t0_203, t1_203;
MSKand_opini2_d2_pini u_g_203 (
    .ina({Rsh_d1[203], Rsh_d0[203]}), .inb({Bn1[203], Bn0[203]}),
    .rnd(r[406]), .s(s[406]), .clk(clk), .out({g1_203, g0_203}));
MSKand_opini2_d2_pini u_t_203 (
    .ina({fc1[203], fc0[203]}), .inb({p1_203, p0_203}),
    .rnd(r[407]), .s(s[407]), .clk(clk), .out({t1_203, t0_203}));
assign fc0[204] = g0_203 ^ t0_203;
assign fc1[204] = g1_203 ^ t1_203;
wire p0_204 = Rsh_d0[204] ^ Bn0[204];
wire p1_204 = Rsh_d1[204] ^ Bn1[204];
wire g0_204, g1_204, t0_204, t1_204;
MSKand_opini2_d2_pini u_g_204 (
    .ina({Rsh_d1[204], Rsh_d0[204]}), .inb({Bn1[204], Bn0[204]}),
    .rnd(r[408]), .s(s[408]), .clk(clk), .out({g1_204, g0_204}));
MSKand_opini2_d2_pini u_t_204 (
    .ina({fc1[204], fc0[204]}), .inb({p1_204, p0_204}),
    .rnd(r[409]), .s(s[409]), .clk(clk), .out({t1_204, t0_204}));
assign fc0[205] = g0_204 ^ t0_204;
assign fc1[205] = g1_204 ^ t1_204;
wire p0_205 = Rsh_d0[205] ^ Bn0[205];
wire p1_205 = Rsh_d1[205] ^ Bn1[205];
wire g0_205, g1_205, t0_205, t1_205;
MSKand_opini2_d2_pini u_g_205 (
    .ina({Rsh_d1[205], Rsh_d0[205]}), .inb({Bn1[205], Bn0[205]}),
    .rnd(r[410]), .s(s[410]), .clk(clk), .out({g1_205, g0_205}));
MSKand_opini2_d2_pini u_t_205 (
    .ina({fc1[205], fc0[205]}), .inb({p1_205, p0_205}),
    .rnd(r[411]), .s(s[411]), .clk(clk), .out({t1_205, t0_205}));
assign fc0[206] = g0_205 ^ t0_205;
assign fc1[206] = g1_205 ^ t1_205;
wire p0_206 = Rsh_d0[206] ^ Bn0[206];
wire p1_206 = Rsh_d1[206] ^ Bn1[206];
wire g0_206, g1_206, t0_206, t1_206;
MSKand_opini2_d2_pini u_g_206 (
    .ina({Rsh_d1[206], Rsh_d0[206]}), .inb({Bn1[206], Bn0[206]}),
    .rnd(r[412]), .s(s[412]), .clk(clk), .out({g1_206, g0_206}));
MSKand_opini2_d2_pini u_t_206 (
    .ina({fc1[206], fc0[206]}), .inb({p1_206, p0_206}),
    .rnd(r[413]), .s(s[413]), .clk(clk), .out({t1_206, t0_206}));
assign fc0[207] = g0_206 ^ t0_206;
assign fc1[207] = g1_206 ^ t1_206;
wire p0_207 = Rsh_d0[207] ^ Bn0[207];
wire p1_207 = Rsh_d1[207] ^ Bn1[207];
wire g0_207, g1_207, t0_207, t1_207;
MSKand_opini2_d2_pini u_g_207 (
    .ina({Rsh_d1[207], Rsh_d0[207]}), .inb({Bn1[207], Bn0[207]}),
    .rnd(r[414]), .s(s[414]), .clk(clk), .out({g1_207, g0_207}));
MSKand_opini2_d2_pini u_t_207 (
    .ina({fc1[207], fc0[207]}), .inb({p1_207, p0_207}),
    .rnd(r[415]), .s(s[415]), .clk(clk), .out({t1_207, t0_207}));
assign fc0[208] = g0_207 ^ t0_207;
assign fc1[208] = g1_207 ^ t1_207;
wire p0_208 = Rsh_d0[208] ^ Bn0[208];
wire p1_208 = Rsh_d1[208] ^ Bn1[208];
wire g0_208, g1_208, t0_208, t1_208;
MSKand_opini2_d2_pini u_g_208 (
    .ina({Rsh_d1[208], Rsh_d0[208]}), .inb({Bn1[208], Bn0[208]}),
    .rnd(r[416]), .s(s[416]), .clk(clk), .out({g1_208, g0_208}));
MSKand_opini2_d2_pini u_t_208 (
    .ina({fc1[208], fc0[208]}), .inb({p1_208, p0_208}),
    .rnd(r[417]), .s(s[417]), .clk(clk), .out({t1_208, t0_208}));
assign fc0[209] = g0_208 ^ t0_208;
assign fc1[209] = g1_208 ^ t1_208;
wire p0_209 = Rsh_d0[209] ^ Bn0[209];
wire p1_209 = Rsh_d1[209] ^ Bn1[209];
wire g0_209, g1_209, t0_209, t1_209;
MSKand_opini2_d2_pini u_g_209 (
    .ina({Rsh_d1[209], Rsh_d0[209]}), .inb({Bn1[209], Bn0[209]}),
    .rnd(r[418]), .s(s[418]), .clk(clk), .out({g1_209, g0_209}));
MSKand_opini2_d2_pini u_t_209 (
    .ina({fc1[209], fc0[209]}), .inb({p1_209, p0_209}),
    .rnd(r[419]), .s(s[419]), .clk(clk), .out({t1_209, t0_209}));
assign fc0[210] = g0_209 ^ t0_209;
assign fc1[210] = g1_209 ^ t1_209;
wire p0_210 = Rsh_d0[210] ^ Bn0[210];
wire p1_210 = Rsh_d1[210] ^ Bn1[210];
wire g0_210, g1_210, t0_210, t1_210;
MSKand_opini2_d2_pini u_g_210 (
    .ina({Rsh_d1[210], Rsh_d0[210]}), .inb({Bn1[210], Bn0[210]}),
    .rnd(r[420]), .s(s[420]), .clk(clk), .out({g1_210, g0_210}));
MSKand_opini2_d2_pini u_t_210 (
    .ina({fc1[210], fc0[210]}), .inb({p1_210, p0_210}),
    .rnd(r[421]), .s(s[421]), .clk(clk), .out({t1_210, t0_210}));
assign fc0[211] = g0_210 ^ t0_210;
assign fc1[211] = g1_210 ^ t1_210;
wire p0_211 = Rsh_d0[211] ^ Bn0[211];
wire p1_211 = Rsh_d1[211] ^ Bn1[211];
wire g0_211, g1_211, t0_211, t1_211;
MSKand_opini2_d2_pini u_g_211 (
    .ina({Rsh_d1[211], Rsh_d0[211]}), .inb({Bn1[211], Bn0[211]}),
    .rnd(r[422]), .s(s[422]), .clk(clk), .out({g1_211, g0_211}));
MSKand_opini2_d2_pini u_t_211 (
    .ina({fc1[211], fc0[211]}), .inb({p1_211, p0_211}),
    .rnd(r[423]), .s(s[423]), .clk(clk), .out({t1_211, t0_211}));
assign fc0[212] = g0_211 ^ t0_211;
assign fc1[212] = g1_211 ^ t1_211;
wire p0_212 = Rsh_d0[212] ^ Bn0[212];
wire p1_212 = Rsh_d1[212] ^ Bn1[212];
wire g0_212, g1_212, t0_212, t1_212;
MSKand_opini2_d2_pini u_g_212 (
    .ina({Rsh_d1[212], Rsh_d0[212]}), .inb({Bn1[212], Bn0[212]}),
    .rnd(r[424]), .s(s[424]), .clk(clk), .out({g1_212, g0_212}));
MSKand_opini2_d2_pini u_t_212 (
    .ina({fc1[212], fc0[212]}), .inb({p1_212, p0_212}),
    .rnd(r[425]), .s(s[425]), .clk(clk), .out({t1_212, t0_212}));
assign fc0[213] = g0_212 ^ t0_212;
assign fc1[213] = g1_212 ^ t1_212;
wire p0_213 = Rsh_d0[213] ^ Bn0[213];
wire p1_213 = Rsh_d1[213] ^ Bn1[213];
wire g0_213, g1_213, t0_213, t1_213;
MSKand_opini2_d2_pini u_g_213 (
    .ina({Rsh_d1[213], Rsh_d0[213]}), .inb({Bn1[213], Bn0[213]}),
    .rnd(r[426]), .s(s[426]), .clk(clk), .out({g1_213, g0_213}));
MSKand_opini2_d2_pini u_t_213 (
    .ina({fc1[213], fc0[213]}), .inb({p1_213, p0_213}),
    .rnd(r[427]), .s(s[427]), .clk(clk), .out({t1_213, t0_213}));
assign fc0[214] = g0_213 ^ t0_213;
assign fc1[214] = g1_213 ^ t1_213;
wire p0_214 = Rsh_d0[214] ^ Bn0[214];
wire p1_214 = Rsh_d1[214] ^ Bn1[214];
wire g0_214, g1_214, t0_214, t1_214;
MSKand_opini2_d2_pini u_g_214 (
    .ina({Rsh_d1[214], Rsh_d0[214]}), .inb({Bn1[214], Bn0[214]}),
    .rnd(r[428]), .s(s[428]), .clk(clk), .out({g1_214, g0_214}));
MSKand_opini2_d2_pini u_t_214 (
    .ina({fc1[214], fc0[214]}), .inb({p1_214, p0_214}),
    .rnd(r[429]), .s(s[429]), .clk(clk), .out({t1_214, t0_214}));
assign fc0[215] = g0_214 ^ t0_214;
assign fc1[215] = g1_214 ^ t1_214;
wire p0_215 = Rsh_d0[215] ^ Bn0[215];
wire p1_215 = Rsh_d1[215] ^ Bn1[215];
wire g0_215, g1_215, t0_215, t1_215;
MSKand_opini2_d2_pini u_g_215 (
    .ina({Rsh_d1[215], Rsh_d0[215]}), .inb({Bn1[215], Bn0[215]}),
    .rnd(r[430]), .s(s[430]), .clk(clk), .out({g1_215, g0_215}));
MSKand_opini2_d2_pini u_t_215 (
    .ina({fc1[215], fc0[215]}), .inb({p1_215, p0_215}),
    .rnd(r[431]), .s(s[431]), .clk(clk), .out({t1_215, t0_215}));
assign fc0[216] = g0_215 ^ t0_215;
assign fc1[216] = g1_215 ^ t1_215;
wire p0_216 = Rsh_d0[216] ^ Bn0[216];
wire p1_216 = Rsh_d1[216] ^ Bn1[216];
wire g0_216, g1_216, t0_216, t1_216;
MSKand_opini2_d2_pini u_g_216 (
    .ina({Rsh_d1[216], Rsh_d0[216]}), .inb({Bn1[216], Bn0[216]}),
    .rnd(r[432]), .s(s[432]), .clk(clk), .out({g1_216, g0_216}));
MSKand_opini2_d2_pini u_t_216 (
    .ina({fc1[216], fc0[216]}), .inb({p1_216, p0_216}),
    .rnd(r[433]), .s(s[433]), .clk(clk), .out({t1_216, t0_216}));
assign fc0[217] = g0_216 ^ t0_216;
assign fc1[217] = g1_216 ^ t1_216;
wire p0_217 = Rsh_d0[217] ^ Bn0[217];
wire p1_217 = Rsh_d1[217] ^ Bn1[217];
wire g0_217, g1_217, t0_217, t1_217;
MSKand_opini2_d2_pini u_g_217 (
    .ina({Rsh_d1[217], Rsh_d0[217]}), .inb({Bn1[217], Bn0[217]}),
    .rnd(r[434]), .s(s[434]), .clk(clk), .out({g1_217, g0_217}));
MSKand_opini2_d2_pini u_t_217 (
    .ina({fc1[217], fc0[217]}), .inb({p1_217, p0_217}),
    .rnd(r[435]), .s(s[435]), .clk(clk), .out({t1_217, t0_217}));
assign fc0[218] = g0_217 ^ t0_217;
assign fc1[218] = g1_217 ^ t1_217;
wire p0_218 = Rsh_d0[218] ^ Bn0[218];
wire p1_218 = Rsh_d1[218] ^ Bn1[218];
wire g0_218, g1_218, t0_218, t1_218;
MSKand_opini2_d2_pini u_g_218 (
    .ina({Rsh_d1[218], Rsh_d0[218]}), .inb({Bn1[218], Bn0[218]}),
    .rnd(r[436]), .s(s[436]), .clk(clk), .out({g1_218, g0_218}));
MSKand_opini2_d2_pini u_t_218 (
    .ina({fc1[218], fc0[218]}), .inb({p1_218, p0_218}),
    .rnd(r[437]), .s(s[437]), .clk(clk), .out({t1_218, t0_218}));
assign fc0[219] = g0_218 ^ t0_218;
assign fc1[219] = g1_218 ^ t1_218;
wire p0_219 = Rsh_d0[219] ^ Bn0[219];
wire p1_219 = Rsh_d1[219] ^ Bn1[219];
wire g0_219, g1_219, t0_219, t1_219;
MSKand_opini2_d2_pini u_g_219 (
    .ina({Rsh_d1[219], Rsh_d0[219]}), .inb({Bn1[219], Bn0[219]}),
    .rnd(r[438]), .s(s[438]), .clk(clk), .out({g1_219, g0_219}));
MSKand_opini2_d2_pini u_t_219 (
    .ina({fc1[219], fc0[219]}), .inb({p1_219, p0_219}),
    .rnd(r[439]), .s(s[439]), .clk(clk), .out({t1_219, t0_219}));
assign fc0[220] = g0_219 ^ t0_219;
assign fc1[220] = g1_219 ^ t1_219;
wire p0_220 = Rsh_d0[220] ^ Bn0[220];
wire p1_220 = Rsh_d1[220] ^ Bn1[220];
wire g0_220, g1_220, t0_220, t1_220;
MSKand_opini2_d2_pini u_g_220 (
    .ina({Rsh_d1[220], Rsh_d0[220]}), .inb({Bn1[220], Bn0[220]}),
    .rnd(r[440]), .s(s[440]), .clk(clk), .out({g1_220, g0_220}));
MSKand_opini2_d2_pini u_t_220 (
    .ina({fc1[220], fc0[220]}), .inb({p1_220, p0_220}),
    .rnd(r[441]), .s(s[441]), .clk(clk), .out({t1_220, t0_220}));
assign fc0[221] = g0_220 ^ t0_220;
assign fc1[221] = g1_220 ^ t1_220;
wire p0_221 = Rsh_d0[221] ^ Bn0[221];
wire p1_221 = Rsh_d1[221] ^ Bn1[221];
wire g0_221, g1_221, t0_221, t1_221;
MSKand_opini2_d2_pini u_g_221 (
    .ina({Rsh_d1[221], Rsh_d0[221]}), .inb({Bn1[221], Bn0[221]}),
    .rnd(r[442]), .s(s[442]), .clk(clk), .out({g1_221, g0_221}));
MSKand_opini2_d2_pini u_t_221 (
    .ina({fc1[221], fc0[221]}), .inb({p1_221, p0_221}),
    .rnd(r[443]), .s(s[443]), .clk(clk), .out({t1_221, t0_221}));
assign fc0[222] = g0_221 ^ t0_221;
assign fc1[222] = g1_221 ^ t1_221;
wire p0_222 = Rsh_d0[222] ^ Bn0[222];
wire p1_222 = Rsh_d1[222] ^ Bn1[222];
wire g0_222, g1_222, t0_222, t1_222;
MSKand_opini2_d2_pini u_g_222 (
    .ina({Rsh_d1[222], Rsh_d0[222]}), .inb({Bn1[222], Bn0[222]}),
    .rnd(r[444]), .s(s[444]), .clk(clk), .out({g1_222, g0_222}));
MSKand_opini2_d2_pini u_t_222 (
    .ina({fc1[222], fc0[222]}), .inb({p1_222, p0_222}),
    .rnd(r[445]), .s(s[445]), .clk(clk), .out({t1_222, t0_222}));
assign fc0[223] = g0_222 ^ t0_222;
assign fc1[223] = g1_222 ^ t1_222;
wire p0_223 = Rsh_d0[223] ^ Bn0[223];
wire p1_223 = Rsh_d1[223] ^ Bn1[223];
wire g0_223, g1_223, t0_223, t1_223;
MSKand_opini2_d2_pini u_g_223 (
    .ina({Rsh_d1[223], Rsh_d0[223]}), .inb({Bn1[223], Bn0[223]}),
    .rnd(r[446]), .s(s[446]), .clk(clk), .out({g1_223, g0_223}));
MSKand_opini2_d2_pini u_t_223 (
    .ina({fc1[223], fc0[223]}), .inb({p1_223, p0_223}),
    .rnd(r[447]), .s(s[447]), .clk(clk), .out({t1_223, t0_223}));
assign fc0[224] = g0_223 ^ t0_223;
assign fc1[224] = g1_223 ^ t1_223;
wire p0_224 = Rsh_d0[224] ^ Bn0[224];
wire p1_224 = Rsh_d1[224] ^ Bn1[224];
wire g0_224, g1_224, t0_224, t1_224;
MSKand_opini2_d2_pini u_g_224 (
    .ina({Rsh_d1[224], Rsh_d0[224]}), .inb({Bn1[224], Bn0[224]}),
    .rnd(r[448]), .s(s[448]), .clk(clk), .out({g1_224, g0_224}));
MSKand_opini2_d2_pini u_t_224 (
    .ina({fc1[224], fc0[224]}), .inb({p1_224, p0_224}),
    .rnd(r[449]), .s(s[449]), .clk(clk), .out({t1_224, t0_224}));
assign fc0[225] = g0_224 ^ t0_224;
assign fc1[225] = g1_224 ^ t1_224;
wire p0_225 = Rsh_d0[225] ^ Bn0[225];
wire p1_225 = Rsh_d1[225] ^ Bn1[225];
wire g0_225, g1_225, t0_225, t1_225;
MSKand_opini2_d2_pini u_g_225 (
    .ina({Rsh_d1[225], Rsh_d0[225]}), .inb({Bn1[225], Bn0[225]}),
    .rnd(r[450]), .s(s[450]), .clk(clk), .out({g1_225, g0_225}));
MSKand_opini2_d2_pini u_t_225 (
    .ina({fc1[225], fc0[225]}), .inb({p1_225, p0_225}),
    .rnd(r[451]), .s(s[451]), .clk(clk), .out({t1_225, t0_225}));
assign fc0[226] = g0_225 ^ t0_225;
assign fc1[226] = g1_225 ^ t1_225;
wire p0_226 = Rsh_d0[226] ^ Bn0[226];
wire p1_226 = Rsh_d1[226] ^ Bn1[226];
wire g0_226, g1_226, t0_226, t1_226;
MSKand_opini2_d2_pini u_g_226 (
    .ina({Rsh_d1[226], Rsh_d0[226]}), .inb({Bn1[226], Bn0[226]}),
    .rnd(r[452]), .s(s[452]), .clk(clk), .out({g1_226, g0_226}));
MSKand_opini2_d2_pini u_t_226 (
    .ina({fc1[226], fc0[226]}), .inb({p1_226, p0_226}),
    .rnd(r[453]), .s(s[453]), .clk(clk), .out({t1_226, t0_226}));
assign fc0[227] = g0_226 ^ t0_226;
assign fc1[227] = g1_226 ^ t1_226;
wire p0_227 = Rsh_d0[227] ^ Bn0[227];
wire p1_227 = Rsh_d1[227] ^ Bn1[227];
wire g0_227, g1_227, t0_227, t1_227;
MSKand_opini2_d2_pini u_g_227 (
    .ina({Rsh_d1[227], Rsh_d0[227]}), .inb({Bn1[227], Bn0[227]}),
    .rnd(r[454]), .s(s[454]), .clk(clk), .out({g1_227, g0_227}));
MSKand_opini2_d2_pini u_t_227 (
    .ina({fc1[227], fc0[227]}), .inb({p1_227, p0_227}),
    .rnd(r[455]), .s(s[455]), .clk(clk), .out({t1_227, t0_227}));
assign fc0[228] = g0_227 ^ t0_227;
assign fc1[228] = g1_227 ^ t1_227;
wire p0_228 = Rsh_d0[228] ^ Bn0[228];
wire p1_228 = Rsh_d1[228] ^ Bn1[228];
wire g0_228, g1_228, t0_228, t1_228;
MSKand_opini2_d2_pini u_g_228 (
    .ina({Rsh_d1[228], Rsh_d0[228]}), .inb({Bn1[228], Bn0[228]}),
    .rnd(r[456]), .s(s[456]), .clk(clk), .out({g1_228, g0_228}));
MSKand_opini2_d2_pini u_t_228 (
    .ina({fc1[228], fc0[228]}), .inb({p1_228, p0_228}),
    .rnd(r[457]), .s(s[457]), .clk(clk), .out({t1_228, t0_228}));
assign fc0[229] = g0_228 ^ t0_228;
assign fc1[229] = g1_228 ^ t1_228;
wire p0_229 = Rsh_d0[229] ^ Bn0[229];
wire p1_229 = Rsh_d1[229] ^ Bn1[229];
wire g0_229, g1_229, t0_229, t1_229;
MSKand_opini2_d2_pini u_g_229 (
    .ina({Rsh_d1[229], Rsh_d0[229]}), .inb({Bn1[229], Bn0[229]}),
    .rnd(r[458]), .s(s[458]), .clk(clk), .out({g1_229, g0_229}));
MSKand_opini2_d2_pini u_t_229 (
    .ina({fc1[229], fc0[229]}), .inb({p1_229, p0_229}),
    .rnd(r[459]), .s(s[459]), .clk(clk), .out({t1_229, t0_229}));
assign fc0[230] = g0_229 ^ t0_229;
assign fc1[230] = g1_229 ^ t1_229;
wire p0_230 = Rsh_d0[230] ^ Bn0[230];
wire p1_230 = Rsh_d1[230] ^ Bn1[230];
wire g0_230, g1_230, t0_230, t1_230;
MSKand_opini2_d2_pini u_g_230 (
    .ina({Rsh_d1[230], Rsh_d0[230]}), .inb({Bn1[230], Bn0[230]}),
    .rnd(r[460]), .s(s[460]), .clk(clk), .out({g1_230, g0_230}));
MSKand_opini2_d2_pini u_t_230 (
    .ina({fc1[230], fc0[230]}), .inb({p1_230, p0_230}),
    .rnd(r[461]), .s(s[461]), .clk(clk), .out({t1_230, t0_230}));
assign fc0[231] = g0_230 ^ t0_230;
assign fc1[231] = g1_230 ^ t1_230;
wire p0_231 = Rsh_d0[231] ^ Bn0[231];
wire p1_231 = Rsh_d1[231] ^ Bn1[231];
wire g0_231, g1_231, t0_231, t1_231;
MSKand_opini2_d2_pini u_g_231 (
    .ina({Rsh_d1[231], Rsh_d0[231]}), .inb({Bn1[231], Bn0[231]}),
    .rnd(r[462]), .s(s[462]), .clk(clk), .out({g1_231, g0_231}));
MSKand_opini2_d2_pini u_t_231 (
    .ina({fc1[231], fc0[231]}), .inb({p1_231, p0_231}),
    .rnd(r[463]), .s(s[463]), .clk(clk), .out({t1_231, t0_231}));
assign fc0[232] = g0_231 ^ t0_231;
assign fc1[232] = g1_231 ^ t1_231;
wire p0_232 = Rsh_d0[232] ^ Bn0[232];
wire p1_232 = Rsh_d1[232] ^ Bn1[232];
wire g0_232, g1_232, t0_232, t1_232;
MSKand_opini2_d2_pini u_g_232 (
    .ina({Rsh_d1[232], Rsh_d0[232]}), .inb({Bn1[232], Bn0[232]}),
    .rnd(r[464]), .s(s[464]), .clk(clk), .out({g1_232, g0_232}));
MSKand_opini2_d2_pini u_t_232 (
    .ina({fc1[232], fc0[232]}), .inb({p1_232, p0_232}),
    .rnd(r[465]), .s(s[465]), .clk(clk), .out({t1_232, t0_232}));
assign fc0[233] = g0_232 ^ t0_232;
assign fc1[233] = g1_232 ^ t1_232;
wire p0_233 = Rsh_d0[233] ^ Bn0[233];
wire p1_233 = Rsh_d1[233] ^ Bn1[233];
wire g0_233, g1_233, t0_233, t1_233;
MSKand_opini2_d2_pini u_g_233 (
    .ina({Rsh_d1[233], Rsh_d0[233]}), .inb({Bn1[233], Bn0[233]}),
    .rnd(r[466]), .s(s[466]), .clk(clk), .out({g1_233, g0_233}));
MSKand_opini2_d2_pini u_t_233 (
    .ina({fc1[233], fc0[233]}), .inb({p1_233, p0_233}),
    .rnd(r[467]), .s(s[467]), .clk(clk), .out({t1_233, t0_233}));
assign fc0[234] = g0_233 ^ t0_233;
assign fc1[234] = g1_233 ^ t1_233;
wire p0_234 = Rsh_d0[234] ^ Bn0[234];
wire p1_234 = Rsh_d1[234] ^ Bn1[234];
wire g0_234, g1_234, t0_234, t1_234;
MSKand_opini2_d2_pini u_g_234 (
    .ina({Rsh_d1[234], Rsh_d0[234]}), .inb({Bn1[234], Bn0[234]}),
    .rnd(r[468]), .s(s[468]), .clk(clk), .out({g1_234, g0_234}));
MSKand_opini2_d2_pini u_t_234 (
    .ina({fc1[234], fc0[234]}), .inb({p1_234, p0_234}),
    .rnd(r[469]), .s(s[469]), .clk(clk), .out({t1_234, t0_234}));
assign fc0[235] = g0_234 ^ t0_234;
assign fc1[235] = g1_234 ^ t1_234;
wire p0_235 = Rsh_d0[235] ^ Bn0[235];
wire p1_235 = Rsh_d1[235] ^ Bn1[235];
wire g0_235, g1_235, t0_235, t1_235;
MSKand_opini2_d2_pini u_g_235 (
    .ina({Rsh_d1[235], Rsh_d0[235]}), .inb({Bn1[235], Bn0[235]}),
    .rnd(r[470]), .s(s[470]), .clk(clk), .out({g1_235, g0_235}));
MSKand_opini2_d2_pini u_t_235 (
    .ina({fc1[235], fc0[235]}), .inb({p1_235, p0_235}),
    .rnd(r[471]), .s(s[471]), .clk(clk), .out({t1_235, t0_235}));
assign fc0[236] = g0_235 ^ t0_235;
assign fc1[236] = g1_235 ^ t1_235;
wire p0_236 = Rsh_d0[236] ^ Bn0[236];
wire p1_236 = Rsh_d1[236] ^ Bn1[236];
wire g0_236, g1_236, t0_236, t1_236;
MSKand_opini2_d2_pini u_g_236 (
    .ina({Rsh_d1[236], Rsh_d0[236]}), .inb({Bn1[236], Bn0[236]}),
    .rnd(r[472]), .s(s[472]), .clk(clk), .out({g1_236, g0_236}));
MSKand_opini2_d2_pini u_t_236 (
    .ina({fc1[236], fc0[236]}), .inb({p1_236, p0_236}),
    .rnd(r[473]), .s(s[473]), .clk(clk), .out({t1_236, t0_236}));
assign fc0[237] = g0_236 ^ t0_236;
assign fc1[237] = g1_236 ^ t1_236;
wire p0_237 = Rsh_d0[237] ^ Bn0[237];
wire p1_237 = Rsh_d1[237] ^ Bn1[237];
wire g0_237, g1_237, t0_237, t1_237;
MSKand_opini2_d2_pini u_g_237 (
    .ina({Rsh_d1[237], Rsh_d0[237]}), .inb({Bn1[237], Bn0[237]}),
    .rnd(r[474]), .s(s[474]), .clk(clk), .out({g1_237, g0_237}));
MSKand_opini2_d2_pini u_t_237 (
    .ina({fc1[237], fc0[237]}), .inb({p1_237, p0_237}),
    .rnd(r[475]), .s(s[475]), .clk(clk), .out({t1_237, t0_237}));
assign fc0[238] = g0_237 ^ t0_237;
assign fc1[238] = g1_237 ^ t1_237;
wire p0_238 = Rsh_d0[238] ^ Bn0[238];
wire p1_238 = Rsh_d1[238] ^ Bn1[238];
wire g0_238, g1_238, t0_238, t1_238;
MSKand_opini2_d2_pini u_g_238 (
    .ina({Rsh_d1[238], Rsh_d0[238]}), .inb({Bn1[238], Bn0[238]}),
    .rnd(r[476]), .s(s[476]), .clk(clk), .out({g1_238, g0_238}));
MSKand_opini2_d2_pini u_t_238 (
    .ina({fc1[238], fc0[238]}), .inb({p1_238, p0_238}),
    .rnd(r[477]), .s(s[477]), .clk(clk), .out({t1_238, t0_238}));
assign fc0[239] = g0_238 ^ t0_238;
assign fc1[239] = g1_238 ^ t1_238;
wire p0_239 = Rsh_d0[239] ^ Bn0[239];
wire p1_239 = Rsh_d1[239] ^ Bn1[239];
wire g0_239, g1_239, t0_239, t1_239;
MSKand_opini2_d2_pini u_g_239 (
    .ina({Rsh_d1[239], Rsh_d0[239]}), .inb({Bn1[239], Bn0[239]}),
    .rnd(r[478]), .s(s[478]), .clk(clk), .out({g1_239, g0_239}));
MSKand_opini2_d2_pini u_t_239 (
    .ina({fc1[239], fc0[239]}), .inb({p1_239, p0_239}),
    .rnd(r[479]), .s(s[479]), .clk(clk), .out({t1_239, t0_239}));
assign fc0[240] = g0_239 ^ t0_239;
assign fc1[240] = g1_239 ^ t1_239;
wire p0_240 = Rsh_d0[240] ^ Bn0[240];
wire p1_240 = Rsh_d1[240] ^ Bn1[240];
wire g0_240, g1_240, t0_240, t1_240;
MSKand_opini2_d2_pini u_g_240 (
    .ina({Rsh_d1[240], Rsh_d0[240]}), .inb({Bn1[240], Bn0[240]}),
    .rnd(r[480]), .s(s[480]), .clk(clk), .out({g1_240, g0_240}));
MSKand_opini2_d2_pini u_t_240 (
    .ina({fc1[240], fc0[240]}), .inb({p1_240, p0_240}),
    .rnd(r[481]), .s(s[481]), .clk(clk), .out({t1_240, t0_240}));
assign fc0[241] = g0_240 ^ t0_240;
assign fc1[241] = g1_240 ^ t1_240;
wire p0_241 = Rsh_d0[241] ^ Bn0[241];
wire p1_241 = Rsh_d1[241] ^ Bn1[241];
wire g0_241, g1_241, t0_241, t1_241;
MSKand_opini2_d2_pini u_g_241 (
    .ina({Rsh_d1[241], Rsh_d0[241]}), .inb({Bn1[241], Bn0[241]}),
    .rnd(r[482]), .s(s[482]), .clk(clk), .out({g1_241, g0_241}));
MSKand_opini2_d2_pini u_t_241 (
    .ina({fc1[241], fc0[241]}), .inb({p1_241, p0_241}),
    .rnd(r[483]), .s(s[483]), .clk(clk), .out({t1_241, t0_241}));
assign fc0[242] = g0_241 ^ t0_241;
assign fc1[242] = g1_241 ^ t1_241;
wire p0_242 = Rsh_d0[242] ^ Bn0[242];
wire p1_242 = Rsh_d1[242] ^ Bn1[242];
wire g0_242, g1_242, t0_242, t1_242;
MSKand_opini2_d2_pini u_g_242 (
    .ina({Rsh_d1[242], Rsh_d0[242]}), .inb({Bn1[242], Bn0[242]}),
    .rnd(r[484]), .s(s[484]), .clk(clk), .out({g1_242, g0_242}));
MSKand_opini2_d2_pini u_t_242 (
    .ina({fc1[242], fc0[242]}), .inb({p1_242, p0_242}),
    .rnd(r[485]), .s(s[485]), .clk(clk), .out({t1_242, t0_242}));
assign fc0[243] = g0_242 ^ t0_242;
assign fc1[243] = g1_242 ^ t1_242;
wire p0_243 = Rsh_d0[243] ^ Bn0[243];
wire p1_243 = Rsh_d1[243] ^ Bn1[243];
wire g0_243, g1_243, t0_243, t1_243;
MSKand_opini2_d2_pini u_g_243 (
    .ina({Rsh_d1[243], Rsh_d0[243]}), .inb({Bn1[243], Bn0[243]}),
    .rnd(r[486]), .s(s[486]), .clk(clk), .out({g1_243, g0_243}));
MSKand_opini2_d2_pini u_t_243 (
    .ina({fc1[243], fc0[243]}), .inb({p1_243, p0_243}),
    .rnd(r[487]), .s(s[487]), .clk(clk), .out({t1_243, t0_243}));
assign fc0[244] = g0_243 ^ t0_243;
assign fc1[244] = g1_243 ^ t1_243;
wire p0_244 = Rsh_d0[244] ^ Bn0[244];
wire p1_244 = Rsh_d1[244] ^ Bn1[244];
wire g0_244, g1_244, t0_244, t1_244;
MSKand_opini2_d2_pini u_g_244 (
    .ina({Rsh_d1[244], Rsh_d0[244]}), .inb({Bn1[244], Bn0[244]}),
    .rnd(r[488]), .s(s[488]), .clk(clk), .out({g1_244, g0_244}));
MSKand_opini2_d2_pini u_t_244 (
    .ina({fc1[244], fc0[244]}), .inb({p1_244, p0_244}),
    .rnd(r[489]), .s(s[489]), .clk(clk), .out({t1_244, t0_244}));
assign fc0[245] = g0_244 ^ t0_244;
assign fc1[245] = g1_244 ^ t1_244;
wire p0_245 = Rsh_d0[245] ^ Bn0[245];
wire p1_245 = Rsh_d1[245] ^ Bn1[245];
wire g0_245, g1_245, t0_245, t1_245;
MSKand_opini2_d2_pini u_g_245 (
    .ina({Rsh_d1[245], Rsh_d0[245]}), .inb({Bn1[245], Bn0[245]}),
    .rnd(r[490]), .s(s[490]), .clk(clk), .out({g1_245, g0_245}));
MSKand_opini2_d2_pini u_t_245 (
    .ina({fc1[245], fc0[245]}), .inb({p1_245, p0_245}),
    .rnd(r[491]), .s(s[491]), .clk(clk), .out({t1_245, t0_245}));
assign fc0[246] = g0_245 ^ t0_245;
assign fc1[246] = g1_245 ^ t1_245;
wire p0_246 = Rsh_d0[246] ^ Bn0[246];
wire p1_246 = Rsh_d1[246] ^ Bn1[246];
wire g0_246, g1_246, t0_246, t1_246;
MSKand_opini2_d2_pini u_g_246 (
    .ina({Rsh_d1[246], Rsh_d0[246]}), .inb({Bn1[246], Bn0[246]}),
    .rnd(r[492]), .s(s[492]), .clk(clk), .out({g1_246, g0_246}));
MSKand_opini2_d2_pini u_t_246 (
    .ina({fc1[246], fc0[246]}), .inb({p1_246, p0_246}),
    .rnd(r[493]), .s(s[493]), .clk(clk), .out({t1_246, t0_246}));
assign fc0[247] = g0_246 ^ t0_246;
assign fc1[247] = g1_246 ^ t1_246;
wire p0_247 = Rsh_d0[247] ^ Bn0[247];
wire p1_247 = Rsh_d1[247] ^ Bn1[247];
wire g0_247, g1_247, t0_247, t1_247;
MSKand_opini2_d2_pini u_g_247 (
    .ina({Rsh_d1[247], Rsh_d0[247]}), .inb({Bn1[247], Bn0[247]}),
    .rnd(r[494]), .s(s[494]), .clk(clk), .out({g1_247, g0_247}));
MSKand_opini2_d2_pini u_t_247 (
    .ina({fc1[247], fc0[247]}), .inb({p1_247, p0_247}),
    .rnd(r[495]), .s(s[495]), .clk(clk), .out({t1_247, t0_247}));
assign fc0[248] = g0_247 ^ t0_247;
assign fc1[248] = g1_247 ^ t1_247;
wire p0_248 = Rsh_d0[248] ^ Bn0[248];
wire p1_248 = Rsh_d1[248] ^ Bn1[248];
wire g0_248, g1_248, t0_248, t1_248;
MSKand_opini2_d2_pini u_g_248 (
    .ina({Rsh_d1[248], Rsh_d0[248]}), .inb({Bn1[248], Bn0[248]}),
    .rnd(r[496]), .s(s[496]), .clk(clk), .out({g1_248, g0_248}));
MSKand_opini2_d2_pini u_t_248 (
    .ina({fc1[248], fc0[248]}), .inb({p1_248, p0_248}),
    .rnd(r[497]), .s(s[497]), .clk(clk), .out({t1_248, t0_248}));
assign fc0[249] = g0_248 ^ t0_248;
assign fc1[249] = g1_248 ^ t1_248;
wire p0_249 = Rsh_d0[249] ^ Bn0[249];
wire p1_249 = Rsh_d1[249] ^ Bn1[249];
wire g0_249, g1_249, t0_249, t1_249;
MSKand_opini2_d2_pini u_g_249 (
    .ina({Rsh_d1[249], Rsh_d0[249]}), .inb({Bn1[249], Bn0[249]}),
    .rnd(r[498]), .s(s[498]), .clk(clk), .out({g1_249, g0_249}));
MSKand_opini2_d2_pini u_t_249 (
    .ina({fc1[249], fc0[249]}), .inb({p1_249, p0_249}),
    .rnd(r[499]), .s(s[499]), .clk(clk), .out({t1_249, t0_249}));
assign fc0[250] = g0_249 ^ t0_249;
assign fc1[250] = g1_249 ^ t1_249;
wire p0_250 = Rsh_d0[250] ^ Bn0[250];
wire p1_250 = Rsh_d1[250] ^ Bn1[250];
wire g0_250, g1_250, t0_250, t1_250;
MSKand_opini2_d2_pini u_g_250 (
    .ina({Rsh_d1[250], Rsh_d0[250]}), .inb({Bn1[250], Bn0[250]}),
    .rnd(r[500]), .s(s[500]), .clk(clk), .out({g1_250, g0_250}));
MSKand_opini2_d2_pini u_t_250 (
    .ina({fc1[250], fc0[250]}), .inb({p1_250, p0_250}),
    .rnd(r[501]), .s(s[501]), .clk(clk), .out({t1_250, t0_250}));
assign fc0[251] = g0_250 ^ t0_250;
assign fc1[251] = g1_250 ^ t1_250;
wire p0_251 = Rsh_d0[251] ^ Bn0[251];
wire p1_251 = Rsh_d1[251] ^ Bn1[251];
wire g0_251, g1_251, t0_251, t1_251;
MSKand_opini2_d2_pini u_g_251 (
    .ina({Rsh_d1[251], Rsh_d0[251]}), .inb({Bn1[251], Bn0[251]}),
    .rnd(r[502]), .s(s[502]), .clk(clk), .out({g1_251, g0_251}));
MSKand_opini2_d2_pini u_t_251 (
    .ina({fc1[251], fc0[251]}), .inb({p1_251, p0_251}),
    .rnd(r[503]), .s(s[503]), .clk(clk), .out({t1_251, t0_251}));
assign fc0[252] = g0_251 ^ t0_251;
assign fc1[252] = g1_251 ^ t1_251;
wire p0_252 = Rsh_d0[252] ^ Bn0[252];
wire p1_252 = Rsh_d1[252] ^ Bn1[252];
wire g0_252, g1_252, t0_252, t1_252;
MSKand_opini2_d2_pini u_g_252 (
    .ina({Rsh_d1[252], Rsh_d0[252]}), .inb({Bn1[252], Bn0[252]}),
    .rnd(r[504]), .s(s[504]), .clk(clk), .out({g1_252, g0_252}));
MSKand_opini2_d2_pini u_t_252 (
    .ina({fc1[252], fc0[252]}), .inb({p1_252, p0_252}),
    .rnd(r[505]), .s(s[505]), .clk(clk), .out({t1_252, t0_252}));
assign fc0[253] = g0_252 ^ t0_252;
assign fc1[253] = g1_252 ^ t1_252;
wire p0_253 = Rsh_d0[253] ^ Bn0[253];
wire p1_253 = Rsh_d1[253] ^ Bn1[253];
wire g0_253, g1_253, t0_253, t1_253;
MSKand_opini2_d2_pini u_g_253 (
    .ina({Rsh_d1[253], Rsh_d0[253]}), .inb({Bn1[253], Bn0[253]}),
    .rnd(r[506]), .s(s[506]), .clk(clk), .out({g1_253, g0_253}));
MSKand_opini2_d2_pini u_t_253 (
    .ina({fc1[253], fc0[253]}), .inb({p1_253, p0_253}),
    .rnd(r[507]), .s(s[507]), .clk(clk), .out({t1_253, t0_253}));
assign fc0[254] = g0_253 ^ t0_253;
assign fc1[254] = g1_253 ^ t1_253;
wire p0_254 = Rsh_d0[254] ^ Bn0[254];
wire p1_254 = Rsh_d1[254] ^ Bn1[254];
wire g0_254, g1_254, t0_254, t1_254;
MSKand_opini2_d2_pini u_g_254 (
    .ina({Rsh_d1[254], Rsh_d0[254]}), .inb({Bn1[254], Bn0[254]}),
    .rnd(r[508]), .s(s[508]), .clk(clk), .out({g1_254, g0_254}));
MSKand_opini2_d2_pini u_t_254 (
    .ina({fc1[254], fc0[254]}), .inb({p1_254, p0_254}),
    .rnd(r[509]), .s(s[509]), .clk(clk), .out({t1_254, t0_254}));
assign fc0[255] = g0_254 ^ t0_254;
assign fc1[255] = g1_254 ^ t1_254;
wire p0_255 = Rsh_d0[255] ^ Bn0[255];
wire p1_255 = Rsh_d1[255] ^ Bn1[255];
wire g0_255, g1_255, t0_255, t1_255;
MSKand_opini2_d2_pini u_g_255 (
    .ina({Rsh_d1[255], Rsh_d0[255]}), .inb({Bn1[255], Bn0[255]}),
    .rnd(r[510]), .s(s[510]), .clk(clk), .out({g1_255, g0_255}));
MSKand_opini2_d2_pini u_t_255 (
    .ina({fc1[255], fc0[255]}), .inb({p1_255, p0_255}),
    .rnd(r[511]), .s(s[511]), .clk(clk), .out({t1_255, t0_255}));
assign fc0[256] = g0_255 ^ t0_255;
assign fc1[256] = g1_255 ^ t1_255;
wire p0_256 = Rsh_d0[256] ^ 1'b1;
wire p1_256 = Rsh_d1[256] ^ 1'b0;
wire g0_256, g1_256, t0_256, t1_256;
MSKand_opini2_d2_pini u_g_256 (
    .ina({Rsh_d1[256], Rsh_d0[256]}), .inb({1'b0, 1'b1}),
    .rnd(r[512]), .s(s[512]), .clk(clk), .out({g1_256, g0_256}));
MSKand_opini2_d2_pini u_t_256 (
    .ina({fc1[256], fc0[256]}), .inb({p1_256, p0_256}),
    .rnd(r[513]), .s(s[513]), .clk(clk), .out({t1_256, t0_256}));
assign coutw0 = g0_256 ^ t0_256;
assign coutw1 = g1_256 ^ t1_256;
// difference bits (only [255:0] needed: both R' branches are < B < 2^256)
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
assign T0[16] = p0_16 ^ fc0[16];  assign T1[16] = p1_16 ^ fc1[16];
assign T0[17] = p0_17 ^ fc0[17];  assign T1[17] = p1_17 ^ fc1[17];
assign T0[18] = p0_18 ^ fc0[18];  assign T1[18] = p1_18 ^ fc1[18];
assign T0[19] = p0_19 ^ fc0[19];  assign T1[19] = p1_19 ^ fc1[19];
assign T0[20] = p0_20 ^ fc0[20];  assign T1[20] = p1_20 ^ fc1[20];
assign T0[21] = p0_21 ^ fc0[21];  assign T1[21] = p1_21 ^ fc1[21];
assign T0[22] = p0_22 ^ fc0[22];  assign T1[22] = p1_22 ^ fc1[22];
assign T0[23] = p0_23 ^ fc0[23];  assign T1[23] = p1_23 ^ fc1[23];
assign T0[24] = p0_24 ^ fc0[24];  assign T1[24] = p1_24 ^ fc1[24];
assign T0[25] = p0_25 ^ fc0[25];  assign T1[25] = p1_25 ^ fc1[25];
assign T0[26] = p0_26 ^ fc0[26];  assign T1[26] = p1_26 ^ fc1[26];
assign T0[27] = p0_27 ^ fc0[27];  assign T1[27] = p1_27 ^ fc1[27];
assign T0[28] = p0_28 ^ fc0[28];  assign T1[28] = p1_28 ^ fc1[28];
assign T0[29] = p0_29 ^ fc0[29];  assign T1[29] = p1_29 ^ fc1[29];
assign T0[30] = p0_30 ^ fc0[30];  assign T1[30] = p1_30 ^ fc1[30];
assign T0[31] = p0_31 ^ fc0[31];  assign T1[31] = p1_31 ^ fc1[31];
assign T0[32] = p0_32 ^ fc0[32];  assign T1[32] = p1_32 ^ fc1[32];
assign T0[33] = p0_33 ^ fc0[33];  assign T1[33] = p1_33 ^ fc1[33];
assign T0[34] = p0_34 ^ fc0[34];  assign T1[34] = p1_34 ^ fc1[34];
assign T0[35] = p0_35 ^ fc0[35];  assign T1[35] = p1_35 ^ fc1[35];
assign T0[36] = p0_36 ^ fc0[36];  assign T1[36] = p1_36 ^ fc1[36];
assign T0[37] = p0_37 ^ fc0[37];  assign T1[37] = p1_37 ^ fc1[37];
assign T0[38] = p0_38 ^ fc0[38];  assign T1[38] = p1_38 ^ fc1[38];
assign T0[39] = p0_39 ^ fc0[39];  assign T1[39] = p1_39 ^ fc1[39];
assign T0[40] = p0_40 ^ fc0[40];  assign T1[40] = p1_40 ^ fc1[40];
assign T0[41] = p0_41 ^ fc0[41];  assign T1[41] = p1_41 ^ fc1[41];
assign T0[42] = p0_42 ^ fc0[42];  assign T1[42] = p1_42 ^ fc1[42];
assign T0[43] = p0_43 ^ fc0[43];  assign T1[43] = p1_43 ^ fc1[43];
assign T0[44] = p0_44 ^ fc0[44];  assign T1[44] = p1_44 ^ fc1[44];
assign T0[45] = p0_45 ^ fc0[45];  assign T1[45] = p1_45 ^ fc1[45];
assign T0[46] = p0_46 ^ fc0[46];  assign T1[46] = p1_46 ^ fc1[46];
assign T0[47] = p0_47 ^ fc0[47];  assign T1[47] = p1_47 ^ fc1[47];
assign T0[48] = p0_48 ^ fc0[48];  assign T1[48] = p1_48 ^ fc1[48];
assign T0[49] = p0_49 ^ fc0[49];  assign T1[49] = p1_49 ^ fc1[49];
assign T0[50] = p0_50 ^ fc0[50];  assign T1[50] = p1_50 ^ fc1[50];
assign T0[51] = p0_51 ^ fc0[51];  assign T1[51] = p1_51 ^ fc1[51];
assign T0[52] = p0_52 ^ fc0[52];  assign T1[52] = p1_52 ^ fc1[52];
assign T0[53] = p0_53 ^ fc0[53];  assign T1[53] = p1_53 ^ fc1[53];
assign T0[54] = p0_54 ^ fc0[54];  assign T1[54] = p1_54 ^ fc1[54];
assign T0[55] = p0_55 ^ fc0[55];  assign T1[55] = p1_55 ^ fc1[55];
assign T0[56] = p0_56 ^ fc0[56];  assign T1[56] = p1_56 ^ fc1[56];
assign T0[57] = p0_57 ^ fc0[57];  assign T1[57] = p1_57 ^ fc1[57];
assign T0[58] = p0_58 ^ fc0[58];  assign T1[58] = p1_58 ^ fc1[58];
assign T0[59] = p0_59 ^ fc0[59];  assign T1[59] = p1_59 ^ fc1[59];
assign T0[60] = p0_60 ^ fc0[60];  assign T1[60] = p1_60 ^ fc1[60];
assign T0[61] = p0_61 ^ fc0[61];  assign T1[61] = p1_61 ^ fc1[61];
assign T0[62] = p0_62 ^ fc0[62];  assign T1[62] = p1_62 ^ fc1[62];
assign T0[63] = p0_63 ^ fc0[63];  assign T1[63] = p1_63 ^ fc1[63];
assign T0[64] = p0_64 ^ fc0[64];  assign T1[64] = p1_64 ^ fc1[64];
assign T0[65] = p0_65 ^ fc0[65];  assign T1[65] = p1_65 ^ fc1[65];
assign T0[66] = p0_66 ^ fc0[66];  assign T1[66] = p1_66 ^ fc1[66];
assign T0[67] = p0_67 ^ fc0[67];  assign T1[67] = p1_67 ^ fc1[67];
assign T0[68] = p0_68 ^ fc0[68];  assign T1[68] = p1_68 ^ fc1[68];
assign T0[69] = p0_69 ^ fc0[69];  assign T1[69] = p1_69 ^ fc1[69];
assign T0[70] = p0_70 ^ fc0[70];  assign T1[70] = p1_70 ^ fc1[70];
assign T0[71] = p0_71 ^ fc0[71];  assign T1[71] = p1_71 ^ fc1[71];
assign T0[72] = p0_72 ^ fc0[72];  assign T1[72] = p1_72 ^ fc1[72];
assign T0[73] = p0_73 ^ fc0[73];  assign T1[73] = p1_73 ^ fc1[73];
assign T0[74] = p0_74 ^ fc0[74];  assign T1[74] = p1_74 ^ fc1[74];
assign T0[75] = p0_75 ^ fc0[75];  assign T1[75] = p1_75 ^ fc1[75];
assign T0[76] = p0_76 ^ fc0[76];  assign T1[76] = p1_76 ^ fc1[76];
assign T0[77] = p0_77 ^ fc0[77];  assign T1[77] = p1_77 ^ fc1[77];
assign T0[78] = p0_78 ^ fc0[78];  assign T1[78] = p1_78 ^ fc1[78];
assign T0[79] = p0_79 ^ fc0[79];  assign T1[79] = p1_79 ^ fc1[79];
assign T0[80] = p0_80 ^ fc0[80];  assign T1[80] = p1_80 ^ fc1[80];
assign T0[81] = p0_81 ^ fc0[81];  assign T1[81] = p1_81 ^ fc1[81];
assign T0[82] = p0_82 ^ fc0[82];  assign T1[82] = p1_82 ^ fc1[82];
assign T0[83] = p0_83 ^ fc0[83];  assign T1[83] = p1_83 ^ fc1[83];
assign T0[84] = p0_84 ^ fc0[84];  assign T1[84] = p1_84 ^ fc1[84];
assign T0[85] = p0_85 ^ fc0[85];  assign T1[85] = p1_85 ^ fc1[85];
assign T0[86] = p0_86 ^ fc0[86];  assign T1[86] = p1_86 ^ fc1[86];
assign T0[87] = p0_87 ^ fc0[87];  assign T1[87] = p1_87 ^ fc1[87];
assign T0[88] = p0_88 ^ fc0[88];  assign T1[88] = p1_88 ^ fc1[88];
assign T0[89] = p0_89 ^ fc0[89];  assign T1[89] = p1_89 ^ fc1[89];
assign T0[90] = p0_90 ^ fc0[90];  assign T1[90] = p1_90 ^ fc1[90];
assign T0[91] = p0_91 ^ fc0[91];  assign T1[91] = p1_91 ^ fc1[91];
assign T0[92] = p0_92 ^ fc0[92];  assign T1[92] = p1_92 ^ fc1[92];
assign T0[93] = p0_93 ^ fc0[93];  assign T1[93] = p1_93 ^ fc1[93];
assign T0[94] = p0_94 ^ fc0[94];  assign T1[94] = p1_94 ^ fc1[94];
assign T0[95] = p0_95 ^ fc0[95];  assign T1[95] = p1_95 ^ fc1[95];
assign T0[96] = p0_96 ^ fc0[96];  assign T1[96] = p1_96 ^ fc1[96];
assign T0[97] = p0_97 ^ fc0[97];  assign T1[97] = p1_97 ^ fc1[97];
assign T0[98] = p0_98 ^ fc0[98];  assign T1[98] = p1_98 ^ fc1[98];
assign T0[99] = p0_99 ^ fc0[99];  assign T1[99] = p1_99 ^ fc1[99];
assign T0[100] = p0_100 ^ fc0[100];  assign T1[100] = p1_100 ^ fc1[100];
assign T0[101] = p0_101 ^ fc0[101];  assign T1[101] = p1_101 ^ fc1[101];
assign T0[102] = p0_102 ^ fc0[102];  assign T1[102] = p1_102 ^ fc1[102];
assign T0[103] = p0_103 ^ fc0[103];  assign T1[103] = p1_103 ^ fc1[103];
assign T0[104] = p0_104 ^ fc0[104];  assign T1[104] = p1_104 ^ fc1[104];
assign T0[105] = p0_105 ^ fc0[105];  assign T1[105] = p1_105 ^ fc1[105];
assign T0[106] = p0_106 ^ fc0[106];  assign T1[106] = p1_106 ^ fc1[106];
assign T0[107] = p0_107 ^ fc0[107];  assign T1[107] = p1_107 ^ fc1[107];
assign T0[108] = p0_108 ^ fc0[108];  assign T1[108] = p1_108 ^ fc1[108];
assign T0[109] = p0_109 ^ fc0[109];  assign T1[109] = p1_109 ^ fc1[109];
assign T0[110] = p0_110 ^ fc0[110];  assign T1[110] = p1_110 ^ fc1[110];
assign T0[111] = p0_111 ^ fc0[111];  assign T1[111] = p1_111 ^ fc1[111];
assign T0[112] = p0_112 ^ fc0[112];  assign T1[112] = p1_112 ^ fc1[112];
assign T0[113] = p0_113 ^ fc0[113];  assign T1[113] = p1_113 ^ fc1[113];
assign T0[114] = p0_114 ^ fc0[114];  assign T1[114] = p1_114 ^ fc1[114];
assign T0[115] = p0_115 ^ fc0[115];  assign T1[115] = p1_115 ^ fc1[115];
assign T0[116] = p0_116 ^ fc0[116];  assign T1[116] = p1_116 ^ fc1[116];
assign T0[117] = p0_117 ^ fc0[117];  assign T1[117] = p1_117 ^ fc1[117];
assign T0[118] = p0_118 ^ fc0[118];  assign T1[118] = p1_118 ^ fc1[118];
assign T0[119] = p0_119 ^ fc0[119];  assign T1[119] = p1_119 ^ fc1[119];
assign T0[120] = p0_120 ^ fc0[120];  assign T1[120] = p1_120 ^ fc1[120];
assign T0[121] = p0_121 ^ fc0[121];  assign T1[121] = p1_121 ^ fc1[121];
assign T0[122] = p0_122 ^ fc0[122];  assign T1[122] = p1_122 ^ fc1[122];
assign T0[123] = p0_123 ^ fc0[123];  assign T1[123] = p1_123 ^ fc1[123];
assign T0[124] = p0_124 ^ fc0[124];  assign T1[124] = p1_124 ^ fc1[124];
assign T0[125] = p0_125 ^ fc0[125];  assign T1[125] = p1_125 ^ fc1[125];
assign T0[126] = p0_126 ^ fc0[126];  assign T1[126] = p1_126 ^ fc1[126];
assign T0[127] = p0_127 ^ fc0[127];  assign T1[127] = p1_127 ^ fc1[127];
assign T0[128] = p0_128 ^ fc0[128];  assign T1[128] = p1_128 ^ fc1[128];
assign T0[129] = p0_129 ^ fc0[129];  assign T1[129] = p1_129 ^ fc1[129];
assign T0[130] = p0_130 ^ fc0[130];  assign T1[130] = p1_130 ^ fc1[130];
assign T0[131] = p0_131 ^ fc0[131];  assign T1[131] = p1_131 ^ fc1[131];
assign T0[132] = p0_132 ^ fc0[132];  assign T1[132] = p1_132 ^ fc1[132];
assign T0[133] = p0_133 ^ fc0[133];  assign T1[133] = p1_133 ^ fc1[133];
assign T0[134] = p0_134 ^ fc0[134];  assign T1[134] = p1_134 ^ fc1[134];
assign T0[135] = p0_135 ^ fc0[135];  assign T1[135] = p1_135 ^ fc1[135];
assign T0[136] = p0_136 ^ fc0[136];  assign T1[136] = p1_136 ^ fc1[136];
assign T0[137] = p0_137 ^ fc0[137];  assign T1[137] = p1_137 ^ fc1[137];
assign T0[138] = p0_138 ^ fc0[138];  assign T1[138] = p1_138 ^ fc1[138];
assign T0[139] = p0_139 ^ fc0[139];  assign T1[139] = p1_139 ^ fc1[139];
assign T0[140] = p0_140 ^ fc0[140];  assign T1[140] = p1_140 ^ fc1[140];
assign T0[141] = p0_141 ^ fc0[141];  assign T1[141] = p1_141 ^ fc1[141];
assign T0[142] = p0_142 ^ fc0[142];  assign T1[142] = p1_142 ^ fc1[142];
assign T0[143] = p0_143 ^ fc0[143];  assign T1[143] = p1_143 ^ fc1[143];
assign T0[144] = p0_144 ^ fc0[144];  assign T1[144] = p1_144 ^ fc1[144];
assign T0[145] = p0_145 ^ fc0[145];  assign T1[145] = p1_145 ^ fc1[145];
assign T0[146] = p0_146 ^ fc0[146];  assign T1[146] = p1_146 ^ fc1[146];
assign T0[147] = p0_147 ^ fc0[147];  assign T1[147] = p1_147 ^ fc1[147];
assign T0[148] = p0_148 ^ fc0[148];  assign T1[148] = p1_148 ^ fc1[148];
assign T0[149] = p0_149 ^ fc0[149];  assign T1[149] = p1_149 ^ fc1[149];
assign T0[150] = p0_150 ^ fc0[150];  assign T1[150] = p1_150 ^ fc1[150];
assign T0[151] = p0_151 ^ fc0[151];  assign T1[151] = p1_151 ^ fc1[151];
assign T0[152] = p0_152 ^ fc0[152];  assign T1[152] = p1_152 ^ fc1[152];
assign T0[153] = p0_153 ^ fc0[153];  assign T1[153] = p1_153 ^ fc1[153];
assign T0[154] = p0_154 ^ fc0[154];  assign T1[154] = p1_154 ^ fc1[154];
assign T0[155] = p0_155 ^ fc0[155];  assign T1[155] = p1_155 ^ fc1[155];
assign T0[156] = p0_156 ^ fc0[156];  assign T1[156] = p1_156 ^ fc1[156];
assign T0[157] = p0_157 ^ fc0[157];  assign T1[157] = p1_157 ^ fc1[157];
assign T0[158] = p0_158 ^ fc0[158];  assign T1[158] = p1_158 ^ fc1[158];
assign T0[159] = p0_159 ^ fc0[159];  assign T1[159] = p1_159 ^ fc1[159];
assign T0[160] = p0_160 ^ fc0[160];  assign T1[160] = p1_160 ^ fc1[160];
assign T0[161] = p0_161 ^ fc0[161];  assign T1[161] = p1_161 ^ fc1[161];
assign T0[162] = p0_162 ^ fc0[162];  assign T1[162] = p1_162 ^ fc1[162];
assign T0[163] = p0_163 ^ fc0[163];  assign T1[163] = p1_163 ^ fc1[163];
assign T0[164] = p0_164 ^ fc0[164];  assign T1[164] = p1_164 ^ fc1[164];
assign T0[165] = p0_165 ^ fc0[165];  assign T1[165] = p1_165 ^ fc1[165];
assign T0[166] = p0_166 ^ fc0[166];  assign T1[166] = p1_166 ^ fc1[166];
assign T0[167] = p0_167 ^ fc0[167];  assign T1[167] = p1_167 ^ fc1[167];
assign T0[168] = p0_168 ^ fc0[168];  assign T1[168] = p1_168 ^ fc1[168];
assign T0[169] = p0_169 ^ fc0[169];  assign T1[169] = p1_169 ^ fc1[169];
assign T0[170] = p0_170 ^ fc0[170];  assign T1[170] = p1_170 ^ fc1[170];
assign T0[171] = p0_171 ^ fc0[171];  assign T1[171] = p1_171 ^ fc1[171];
assign T0[172] = p0_172 ^ fc0[172];  assign T1[172] = p1_172 ^ fc1[172];
assign T0[173] = p0_173 ^ fc0[173];  assign T1[173] = p1_173 ^ fc1[173];
assign T0[174] = p0_174 ^ fc0[174];  assign T1[174] = p1_174 ^ fc1[174];
assign T0[175] = p0_175 ^ fc0[175];  assign T1[175] = p1_175 ^ fc1[175];
assign T0[176] = p0_176 ^ fc0[176];  assign T1[176] = p1_176 ^ fc1[176];
assign T0[177] = p0_177 ^ fc0[177];  assign T1[177] = p1_177 ^ fc1[177];
assign T0[178] = p0_178 ^ fc0[178];  assign T1[178] = p1_178 ^ fc1[178];
assign T0[179] = p0_179 ^ fc0[179];  assign T1[179] = p1_179 ^ fc1[179];
assign T0[180] = p0_180 ^ fc0[180];  assign T1[180] = p1_180 ^ fc1[180];
assign T0[181] = p0_181 ^ fc0[181];  assign T1[181] = p1_181 ^ fc1[181];
assign T0[182] = p0_182 ^ fc0[182];  assign T1[182] = p1_182 ^ fc1[182];
assign T0[183] = p0_183 ^ fc0[183];  assign T1[183] = p1_183 ^ fc1[183];
assign T0[184] = p0_184 ^ fc0[184];  assign T1[184] = p1_184 ^ fc1[184];
assign T0[185] = p0_185 ^ fc0[185];  assign T1[185] = p1_185 ^ fc1[185];
assign T0[186] = p0_186 ^ fc0[186];  assign T1[186] = p1_186 ^ fc1[186];
assign T0[187] = p0_187 ^ fc0[187];  assign T1[187] = p1_187 ^ fc1[187];
assign T0[188] = p0_188 ^ fc0[188];  assign T1[188] = p1_188 ^ fc1[188];
assign T0[189] = p0_189 ^ fc0[189];  assign T1[189] = p1_189 ^ fc1[189];
assign T0[190] = p0_190 ^ fc0[190];  assign T1[190] = p1_190 ^ fc1[190];
assign T0[191] = p0_191 ^ fc0[191];  assign T1[191] = p1_191 ^ fc1[191];
assign T0[192] = p0_192 ^ fc0[192];  assign T1[192] = p1_192 ^ fc1[192];
assign T0[193] = p0_193 ^ fc0[193];  assign T1[193] = p1_193 ^ fc1[193];
assign T0[194] = p0_194 ^ fc0[194];  assign T1[194] = p1_194 ^ fc1[194];
assign T0[195] = p0_195 ^ fc0[195];  assign T1[195] = p1_195 ^ fc1[195];
assign T0[196] = p0_196 ^ fc0[196];  assign T1[196] = p1_196 ^ fc1[196];
assign T0[197] = p0_197 ^ fc0[197];  assign T1[197] = p1_197 ^ fc1[197];
assign T0[198] = p0_198 ^ fc0[198];  assign T1[198] = p1_198 ^ fc1[198];
assign T0[199] = p0_199 ^ fc0[199];  assign T1[199] = p1_199 ^ fc1[199];
assign T0[200] = p0_200 ^ fc0[200];  assign T1[200] = p1_200 ^ fc1[200];
assign T0[201] = p0_201 ^ fc0[201];  assign T1[201] = p1_201 ^ fc1[201];
assign T0[202] = p0_202 ^ fc0[202];  assign T1[202] = p1_202 ^ fc1[202];
assign T0[203] = p0_203 ^ fc0[203];  assign T1[203] = p1_203 ^ fc1[203];
assign T0[204] = p0_204 ^ fc0[204];  assign T1[204] = p1_204 ^ fc1[204];
assign T0[205] = p0_205 ^ fc0[205];  assign T1[205] = p1_205 ^ fc1[205];
assign T0[206] = p0_206 ^ fc0[206];  assign T1[206] = p1_206 ^ fc1[206];
assign T0[207] = p0_207 ^ fc0[207];  assign T1[207] = p1_207 ^ fc1[207];
assign T0[208] = p0_208 ^ fc0[208];  assign T1[208] = p1_208 ^ fc1[208];
assign T0[209] = p0_209 ^ fc0[209];  assign T1[209] = p1_209 ^ fc1[209];
assign T0[210] = p0_210 ^ fc0[210];  assign T1[210] = p1_210 ^ fc1[210];
assign T0[211] = p0_211 ^ fc0[211];  assign T1[211] = p1_211 ^ fc1[211];
assign T0[212] = p0_212 ^ fc0[212];  assign T1[212] = p1_212 ^ fc1[212];
assign T0[213] = p0_213 ^ fc0[213];  assign T1[213] = p1_213 ^ fc1[213];
assign T0[214] = p0_214 ^ fc0[214];  assign T1[214] = p1_214 ^ fc1[214];
assign T0[215] = p0_215 ^ fc0[215];  assign T1[215] = p1_215 ^ fc1[215];
assign T0[216] = p0_216 ^ fc0[216];  assign T1[216] = p1_216 ^ fc1[216];
assign T0[217] = p0_217 ^ fc0[217];  assign T1[217] = p1_217 ^ fc1[217];
assign T0[218] = p0_218 ^ fc0[218];  assign T1[218] = p1_218 ^ fc1[218];
assign T0[219] = p0_219 ^ fc0[219];  assign T1[219] = p1_219 ^ fc1[219];
assign T0[220] = p0_220 ^ fc0[220];  assign T1[220] = p1_220 ^ fc1[220];
assign T0[221] = p0_221 ^ fc0[221];  assign T1[221] = p1_221 ^ fc1[221];
assign T0[222] = p0_222 ^ fc0[222];  assign T1[222] = p1_222 ^ fc1[222];
assign T0[223] = p0_223 ^ fc0[223];  assign T1[223] = p1_223 ^ fc1[223];
assign T0[224] = p0_224 ^ fc0[224];  assign T1[224] = p1_224 ^ fc1[224];
assign T0[225] = p0_225 ^ fc0[225];  assign T1[225] = p1_225 ^ fc1[225];
assign T0[226] = p0_226 ^ fc0[226];  assign T1[226] = p1_226 ^ fc1[226];
assign T0[227] = p0_227 ^ fc0[227];  assign T1[227] = p1_227 ^ fc1[227];
assign T0[228] = p0_228 ^ fc0[228];  assign T1[228] = p1_228 ^ fc1[228];
assign T0[229] = p0_229 ^ fc0[229];  assign T1[229] = p1_229 ^ fc1[229];
assign T0[230] = p0_230 ^ fc0[230];  assign T1[230] = p1_230 ^ fc1[230];
assign T0[231] = p0_231 ^ fc0[231];  assign T1[231] = p1_231 ^ fc1[231];
assign T0[232] = p0_232 ^ fc0[232];  assign T1[232] = p1_232 ^ fc1[232];
assign T0[233] = p0_233 ^ fc0[233];  assign T1[233] = p1_233 ^ fc1[233];
assign T0[234] = p0_234 ^ fc0[234];  assign T1[234] = p1_234 ^ fc1[234];
assign T0[235] = p0_235 ^ fc0[235];  assign T1[235] = p1_235 ^ fc1[235];
assign T0[236] = p0_236 ^ fc0[236];  assign T1[236] = p1_236 ^ fc1[236];
assign T0[237] = p0_237 ^ fc0[237];  assign T1[237] = p1_237 ^ fc1[237];
assign T0[238] = p0_238 ^ fc0[238];  assign T1[238] = p1_238 ^ fc1[238];
assign T0[239] = p0_239 ^ fc0[239];  assign T1[239] = p1_239 ^ fc1[239];
assign T0[240] = p0_240 ^ fc0[240];  assign T1[240] = p1_240 ^ fc1[240];
assign T0[241] = p0_241 ^ fc0[241];  assign T1[241] = p1_241 ^ fc1[241];
assign T0[242] = p0_242 ^ fc0[242];  assign T1[242] = p1_242 ^ fc1[242];
assign T0[243] = p0_243 ^ fc0[243];  assign T1[243] = p1_243 ^ fc1[243];
assign T0[244] = p0_244 ^ fc0[244];  assign T1[244] = p1_244 ^ fc1[244];
assign T0[245] = p0_245 ^ fc0[245];  assign T1[245] = p1_245 ^ fc1[245];
assign T0[246] = p0_246 ^ fc0[246];  assign T1[246] = p1_246 ^ fc1[246];
assign T0[247] = p0_247 ^ fc0[247];  assign T1[247] = p1_247 ^ fc1[247];
assign T0[248] = p0_248 ^ fc0[248];  assign T1[248] = p1_248 ^ fc1[248];
assign T0[249] = p0_249 ^ fc0[249];  assign T1[249] = p1_249 ^ fc1[249];
assign T0[250] = p0_250 ^ fc0[250];  assign T1[250] = p1_250 ^ fc1[250];
assign T0[251] = p0_251 ^ fc0[251];  assign T1[251] = p1_251 ^ fc1[251];
assign T0[252] = p0_252 ^ fc0[252];  assign T1[252] = p1_252 ^ fc1[252];
assign T0[253] = p0_253 ^ fc0[253];  assign T1[253] = p1_253 ^ fc1[253];
assign T0[254] = p0_254 ^ fc0[254];  assign T1[254] = p1_254 ^ fc1[254];
assign T0[255] = p0_255 ^ fc0[255];  assign T1[255] = p1_255 ^ fc1[255];

// ===== borrow-mux: w_m[j] = coutr AND xm[j]  (coutr broadcast to both shares) =====
MSKand_opini2_d2_pini u_m_0 (
    .ina({xm_d1[0], xm_d0[0]}), .inb({coutr1, coutr0}),
    .rnd(r[514]), .s(s[514]), .clk(clk), .out({w_m1[0], w_m0[0]}));
MSKand_opini2_d2_pini u_m_1 (
    .ina({xm_d1[1], xm_d0[1]}), .inb({coutr1, coutr0}),
    .rnd(r[515]), .s(s[515]), .clk(clk), .out({w_m1[1], w_m0[1]}));
MSKand_opini2_d2_pini u_m_2 (
    .ina({xm_d1[2], xm_d0[2]}), .inb({coutr1, coutr0}),
    .rnd(r[516]), .s(s[516]), .clk(clk), .out({w_m1[2], w_m0[2]}));
MSKand_opini2_d2_pini u_m_3 (
    .ina({xm_d1[3], xm_d0[3]}), .inb({coutr1, coutr0}),
    .rnd(r[517]), .s(s[517]), .clk(clk), .out({w_m1[3], w_m0[3]}));
MSKand_opini2_d2_pini u_m_4 (
    .ina({xm_d1[4], xm_d0[4]}), .inb({coutr1, coutr0}),
    .rnd(r[518]), .s(s[518]), .clk(clk), .out({w_m1[4], w_m0[4]}));
MSKand_opini2_d2_pini u_m_5 (
    .ina({xm_d1[5], xm_d0[5]}), .inb({coutr1, coutr0}),
    .rnd(r[519]), .s(s[519]), .clk(clk), .out({w_m1[5], w_m0[5]}));
MSKand_opini2_d2_pini u_m_6 (
    .ina({xm_d1[6], xm_d0[6]}), .inb({coutr1, coutr0}),
    .rnd(r[520]), .s(s[520]), .clk(clk), .out({w_m1[6], w_m0[6]}));
MSKand_opini2_d2_pini u_m_7 (
    .ina({xm_d1[7], xm_d0[7]}), .inb({coutr1, coutr0}),
    .rnd(r[521]), .s(s[521]), .clk(clk), .out({w_m1[7], w_m0[7]}));
MSKand_opini2_d2_pini u_m_8 (
    .ina({xm_d1[8], xm_d0[8]}), .inb({coutr1, coutr0}),
    .rnd(r[522]), .s(s[522]), .clk(clk), .out({w_m1[8], w_m0[8]}));
MSKand_opini2_d2_pini u_m_9 (
    .ina({xm_d1[9], xm_d0[9]}), .inb({coutr1, coutr0}),
    .rnd(r[523]), .s(s[523]), .clk(clk), .out({w_m1[9], w_m0[9]}));
MSKand_opini2_d2_pini u_m_10 (
    .ina({xm_d1[10], xm_d0[10]}), .inb({coutr1, coutr0}),
    .rnd(r[524]), .s(s[524]), .clk(clk), .out({w_m1[10], w_m0[10]}));
MSKand_opini2_d2_pini u_m_11 (
    .ina({xm_d1[11], xm_d0[11]}), .inb({coutr1, coutr0}),
    .rnd(r[525]), .s(s[525]), .clk(clk), .out({w_m1[11], w_m0[11]}));
MSKand_opini2_d2_pini u_m_12 (
    .ina({xm_d1[12], xm_d0[12]}), .inb({coutr1, coutr0}),
    .rnd(r[526]), .s(s[526]), .clk(clk), .out({w_m1[12], w_m0[12]}));
MSKand_opini2_d2_pini u_m_13 (
    .ina({xm_d1[13], xm_d0[13]}), .inb({coutr1, coutr0}),
    .rnd(r[527]), .s(s[527]), .clk(clk), .out({w_m1[13], w_m0[13]}));
MSKand_opini2_d2_pini u_m_14 (
    .ina({xm_d1[14], xm_d0[14]}), .inb({coutr1, coutr0}),
    .rnd(r[528]), .s(s[528]), .clk(clk), .out({w_m1[14], w_m0[14]}));
MSKand_opini2_d2_pini u_m_15 (
    .ina({xm_d1[15], xm_d0[15]}), .inb({coutr1, coutr0}),
    .rnd(r[529]), .s(s[529]), .clk(clk), .out({w_m1[15], w_m0[15]}));
MSKand_opini2_d2_pini u_m_16 (
    .ina({xm_d1[16], xm_d0[16]}), .inb({coutr1, coutr0}),
    .rnd(r[530]), .s(s[530]), .clk(clk), .out({w_m1[16], w_m0[16]}));
MSKand_opini2_d2_pini u_m_17 (
    .ina({xm_d1[17], xm_d0[17]}), .inb({coutr1, coutr0}),
    .rnd(r[531]), .s(s[531]), .clk(clk), .out({w_m1[17], w_m0[17]}));
MSKand_opini2_d2_pini u_m_18 (
    .ina({xm_d1[18], xm_d0[18]}), .inb({coutr1, coutr0}),
    .rnd(r[532]), .s(s[532]), .clk(clk), .out({w_m1[18], w_m0[18]}));
MSKand_opini2_d2_pini u_m_19 (
    .ina({xm_d1[19], xm_d0[19]}), .inb({coutr1, coutr0}),
    .rnd(r[533]), .s(s[533]), .clk(clk), .out({w_m1[19], w_m0[19]}));
MSKand_opini2_d2_pini u_m_20 (
    .ina({xm_d1[20], xm_d0[20]}), .inb({coutr1, coutr0}),
    .rnd(r[534]), .s(s[534]), .clk(clk), .out({w_m1[20], w_m0[20]}));
MSKand_opini2_d2_pini u_m_21 (
    .ina({xm_d1[21], xm_d0[21]}), .inb({coutr1, coutr0}),
    .rnd(r[535]), .s(s[535]), .clk(clk), .out({w_m1[21], w_m0[21]}));
MSKand_opini2_d2_pini u_m_22 (
    .ina({xm_d1[22], xm_d0[22]}), .inb({coutr1, coutr0}),
    .rnd(r[536]), .s(s[536]), .clk(clk), .out({w_m1[22], w_m0[22]}));
MSKand_opini2_d2_pini u_m_23 (
    .ina({xm_d1[23], xm_d0[23]}), .inb({coutr1, coutr0}),
    .rnd(r[537]), .s(s[537]), .clk(clk), .out({w_m1[23], w_m0[23]}));
MSKand_opini2_d2_pini u_m_24 (
    .ina({xm_d1[24], xm_d0[24]}), .inb({coutr1, coutr0}),
    .rnd(r[538]), .s(s[538]), .clk(clk), .out({w_m1[24], w_m0[24]}));
MSKand_opini2_d2_pini u_m_25 (
    .ina({xm_d1[25], xm_d0[25]}), .inb({coutr1, coutr0}),
    .rnd(r[539]), .s(s[539]), .clk(clk), .out({w_m1[25], w_m0[25]}));
MSKand_opini2_d2_pini u_m_26 (
    .ina({xm_d1[26], xm_d0[26]}), .inb({coutr1, coutr0}),
    .rnd(r[540]), .s(s[540]), .clk(clk), .out({w_m1[26], w_m0[26]}));
MSKand_opini2_d2_pini u_m_27 (
    .ina({xm_d1[27], xm_d0[27]}), .inb({coutr1, coutr0}),
    .rnd(r[541]), .s(s[541]), .clk(clk), .out({w_m1[27], w_m0[27]}));
MSKand_opini2_d2_pini u_m_28 (
    .ina({xm_d1[28], xm_d0[28]}), .inb({coutr1, coutr0}),
    .rnd(r[542]), .s(s[542]), .clk(clk), .out({w_m1[28], w_m0[28]}));
MSKand_opini2_d2_pini u_m_29 (
    .ina({xm_d1[29], xm_d0[29]}), .inb({coutr1, coutr0}),
    .rnd(r[543]), .s(s[543]), .clk(clk), .out({w_m1[29], w_m0[29]}));
MSKand_opini2_d2_pini u_m_30 (
    .ina({xm_d1[30], xm_d0[30]}), .inb({coutr1, coutr0}),
    .rnd(r[544]), .s(s[544]), .clk(clk), .out({w_m1[30], w_m0[30]}));
MSKand_opini2_d2_pini u_m_31 (
    .ina({xm_d1[31], xm_d0[31]}), .inb({coutr1, coutr0}),
    .rnd(r[545]), .s(s[545]), .clk(clk), .out({w_m1[31], w_m0[31]}));
MSKand_opini2_d2_pini u_m_32 (
    .ina({xm_d1[32], xm_d0[32]}), .inb({coutr1, coutr0}),
    .rnd(r[546]), .s(s[546]), .clk(clk), .out({w_m1[32], w_m0[32]}));
MSKand_opini2_d2_pini u_m_33 (
    .ina({xm_d1[33], xm_d0[33]}), .inb({coutr1, coutr0}),
    .rnd(r[547]), .s(s[547]), .clk(clk), .out({w_m1[33], w_m0[33]}));
MSKand_opini2_d2_pini u_m_34 (
    .ina({xm_d1[34], xm_d0[34]}), .inb({coutr1, coutr0}),
    .rnd(r[548]), .s(s[548]), .clk(clk), .out({w_m1[34], w_m0[34]}));
MSKand_opini2_d2_pini u_m_35 (
    .ina({xm_d1[35], xm_d0[35]}), .inb({coutr1, coutr0}),
    .rnd(r[549]), .s(s[549]), .clk(clk), .out({w_m1[35], w_m0[35]}));
MSKand_opini2_d2_pini u_m_36 (
    .ina({xm_d1[36], xm_d0[36]}), .inb({coutr1, coutr0}),
    .rnd(r[550]), .s(s[550]), .clk(clk), .out({w_m1[36], w_m0[36]}));
MSKand_opini2_d2_pini u_m_37 (
    .ina({xm_d1[37], xm_d0[37]}), .inb({coutr1, coutr0}),
    .rnd(r[551]), .s(s[551]), .clk(clk), .out({w_m1[37], w_m0[37]}));
MSKand_opini2_d2_pini u_m_38 (
    .ina({xm_d1[38], xm_d0[38]}), .inb({coutr1, coutr0}),
    .rnd(r[552]), .s(s[552]), .clk(clk), .out({w_m1[38], w_m0[38]}));
MSKand_opini2_d2_pini u_m_39 (
    .ina({xm_d1[39], xm_d0[39]}), .inb({coutr1, coutr0}),
    .rnd(r[553]), .s(s[553]), .clk(clk), .out({w_m1[39], w_m0[39]}));
MSKand_opini2_d2_pini u_m_40 (
    .ina({xm_d1[40], xm_d0[40]}), .inb({coutr1, coutr0}),
    .rnd(r[554]), .s(s[554]), .clk(clk), .out({w_m1[40], w_m0[40]}));
MSKand_opini2_d2_pini u_m_41 (
    .ina({xm_d1[41], xm_d0[41]}), .inb({coutr1, coutr0}),
    .rnd(r[555]), .s(s[555]), .clk(clk), .out({w_m1[41], w_m0[41]}));
MSKand_opini2_d2_pini u_m_42 (
    .ina({xm_d1[42], xm_d0[42]}), .inb({coutr1, coutr0}),
    .rnd(r[556]), .s(s[556]), .clk(clk), .out({w_m1[42], w_m0[42]}));
MSKand_opini2_d2_pini u_m_43 (
    .ina({xm_d1[43], xm_d0[43]}), .inb({coutr1, coutr0}),
    .rnd(r[557]), .s(s[557]), .clk(clk), .out({w_m1[43], w_m0[43]}));
MSKand_opini2_d2_pini u_m_44 (
    .ina({xm_d1[44], xm_d0[44]}), .inb({coutr1, coutr0}),
    .rnd(r[558]), .s(s[558]), .clk(clk), .out({w_m1[44], w_m0[44]}));
MSKand_opini2_d2_pini u_m_45 (
    .ina({xm_d1[45], xm_d0[45]}), .inb({coutr1, coutr0}),
    .rnd(r[559]), .s(s[559]), .clk(clk), .out({w_m1[45], w_m0[45]}));
MSKand_opini2_d2_pini u_m_46 (
    .ina({xm_d1[46], xm_d0[46]}), .inb({coutr1, coutr0}),
    .rnd(r[560]), .s(s[560]), .clk(clk), .out({w_m1[46], w_m0[46]}));
MSKand_opini2_d2_pini u_m_47 (
    .ina({xm_d1[47], xm_d0[47]}), .inb({coutr1, coutr0}),
    .rnd(r[561]), .s(s[561]), .clk(clk), .out({w_m1[47], w_m0[47]}));
MSKand_opini2_d2_pini u_m_48 (
    .ina({xm_d1[48], xm_d0[48]}), .inb({coutr1, coutr0}),
    .rnd(r[562]), .s(s[562]), .clk(clk), .out({w_m1[48], w_m0[48]}));
MSKand_opini2_d2_pini u_m_49 (
    .ina({xm_d1[49], xm_d0[49]}), .inb({coutr1, coutr0}),
    .rnd(r[563]), .s(s[563]), .clk(clk), .out({w_m1[49], w_m0[49]}));
MSKand_opini2_d2_pini u_m_50 (
    .ina({xm_d1[50], xm_d0[50]}), .inb({coutr1, coutr0}),
    .rnd(r[564]), .s(s[564]), .clk(clk), .out({w_m1[50], w_m0[50]}));
MSKand_opini2_d2_pini u_m_51 (
    .ina({xm_d1[51], xm_d0[51]}), .inb({coutr1, coutr0}),
    .rnd(r[565]), .s(s[565]), .clk(clk), .out({w_m1[51], w_m0[51]}));
MSKand_opini2_d2_pini u_m_52 (
    .ina({xm_d1[52], xm_d0[52]}), .inb({coutr1, coutr0}),
    .rnd(r[566]), .s(s[566]), .clk(clk), .out({w_m1[52], w_m0[52]}));
MSKand_opini2_d2_pini u_m_53 (
    .ina({xm_d1[53], xm_d0[53]}), .inb({coutr1, coutr0}),
    .rnd(r[567]), .s(s[567]), .clk(clk), .out({w_m1[53], w_m0[53]}));
MSKand_opini2_d2_pini u_m_54 (
    .ina({xm_d1[54], xm_d0[54]}), .inb({coutr1, coutr0}),
    .rnd(r[568]), .s(s[568]), .clk(clk), .out({w_m1[54], w_m0[54]}));
MSKand_opini2_d2_pini u_m_55 (
    .ina({xm_d1[55], xm_d0[55]}), .inb({coutr1, coutr0}),
    .rnd(r[569]), .s(s[569]), .clk(clk), .out({w_m1[55], w_m0[55]}));
MSKand_opini2_d2_pini u_m_56 (
    .ina({xm_d1[56], xm_d0[56]}), .inb({coutr1, coutr0}),
    .rnd(r[570]), .s(s[570]), .clk(clk), .out({w_m1[56], w_m0[56]}));
MSKand_opini2_d2_pini u_m_57 (
    .ina({xm_d1[57], xm_d0[57]}), .inb({coutr1, coutr0}),
    .rnd(r[571]), .s(s[571]), .clk(clk), .out({w_m1[57], w_m0[57]}));
MSKand_opini2_d2_pini u_m_58 (
    .ina({xm_d1[58], xm_d0[58]}), .inb({coutr1, coutr0}),
    .rnd(r[572]), .s(s[572]), .clk(clk), .out({w_m1[58], w_m0[58]}));
MSKand_opini2_d2_pini u_m_59 (
    .ina({xm_d1[59], xm_d0[59]}), .inb({coutr1, coutr0}),
    .rnd(r[573]), .s(s[573]), .clk(clk), .out({w_m1[59], w_m0[59]}));
MSKand_opini2_d2_pini u_m_60 (
    .ina({xm_d1[60], xm_d0[60]}), .inb({coutr1, coutr0}),
    .rnd(r[574]), .s(s[574]), .clk(clk), .out({w_m1[60], w_m0[60]}));
MSKand_opini2_d2_pini u_m_61 (
    .ina({xm_d1[61], xm_d0[61]}), .inb({coutr1, coutr0}),
    .rnd(r[575]), .s(s[575]), .clk(clk), .out({w_m1[61], w_m0[61]}));
MSKand_opini2_d2_pini u_m_62 (
    .ina({xm_d1[62], xm_d0[62]}), .inb({coutr1, coutr0}),
    .rnd(r[576]), .s(s[576]), .clk(clk), .out({w_m1[62], w_m0[62]}));
MSKand_opini2_d2_pini u_m_63 (
    .ina({xm_d1[63], xm_d0[63]}), .inb({coutr1, coutr0}),
    .rnd(r[577]), .s(s[577]), .clk(clk), .out({w_m1[63], w_m0[63]}));
MSKand_opini2_d2_pini u_m_64 (
    .ina({xm_d1[64], xm_d0[64]}), .inb({coutr1, coutr0}),
    .rnd(r[578]), .s(s[578]), .clk(clk), .out({w_m1[64], w_m0[64]}));
MSKand_opini2_d2_pini u_m_65 (
    .ina({xm_d1[65], xm_d0[65]}), .inb({coutr1, coutr0}),
    .rnd(r[579]), .s(s[579]), .clk(clk), .out({w_m1[65], w_m0[65]}));
MSKand_opini2_d2_pini u_m_66 (
    .ina({xm_d1[66], xm_d0[66]}), .inb({coutr1, coutr0}),
    .rnd(r[580]), .s(s[580]), .clk(clk), .out({w_m1[66], w_m0[66]}));
MSKand_opini2_d2_pini u_m_67 (
    .ina({xm_d1[67], xm_d0[67]}), .inb({coutr1, coutr0}),
    .rnd(r[581]), .s(s[581]), .clk(clk), .out({w_m1[67], w_m0[67]}));
MSKand_opini2_d2_pini u_m_68 (
    .ina({xm_d1[68], xm_d0[68]}), .inb({coutr1, coutr0}),
    .rnd(r[582]), .s(s[582]), .clk(clk), .out({w_m1[68], w_m0[68]}));
MSKand_opini2_d2_pini u_m_69 (
    .ina({xm_d1[69], xm_d0[69]}), .inb({coutr1, coutr0}),
    .rnd(r[583]), .s(s[583]), .clk(clk), .out({w_m1[69], w_m0[69]}));
MSKand_opini2_d2_pini u_m_70 (
    .ina({xm_d1[70], xm_d0[70]}), .inb({coutr1, coutr0}),
    .rnd(r[584]), .s(s[584]), .clk(clk), .out({w_m1[70], w_m0[70]}));
MSKand_opini2_d2_pini u_m_71 (
    .ina({xm_d1[71], xm_d0[71]}), .inb({coutr1, coutr0}),
    .rnd(r[585]), .s(s[585]), .clk(clk), .out({w_m1[71], w_m0[71]}));
MSKand_opini2_d2_pini u_m_72 (
    .ina({xm_d1[72], xm_d0[72]}), .inb({coutr1, coutr0}),
    .rnd(r[586]), .s(s[586]), .clk(clk), .out({w_m1[72], w_m0[72]}));
MSKand_opini2_d2_pini u_m_73 (
    .ina({xm_d1[73], xm_d0[73]}), .inb({coutr1, coutr0}),
    .rnd(r[587]), .s(s[587]), .clk(clk), .out({w_m1[73], w_m0[73]}));
MSKand_opini2_d2_pini u_m_74 (
    .ina({xm_d1[74], xm_d0[74]}), .inb({coutr1, coutr0}),
    .rnd(r[588]), .s(s[588]), .clk(clk), .out({w_m1[74], w_m0[74]}));
MSKand_opini2_d2_pini u_m_75 (
    .ina({xm_d1[75], xm_d0[75]}), .inb({coutr1, coutr0}),
    .rnd(r[589]), .s(s[589]), .clk(clk), .out({w_m1[75], w_m0[75]}));
MSKand_opini2_d2_pini u_m_76 (
    .ina({xm_d1[76], xm_d0[76]}), .inb({coutr1, coutr0}),
    .rnd(r[590]), .s(s[590]), .clk(clk), .out({w_m1[76], w_m0[76]}));
MSKand_opini2_d2_pini u_m_77 (
    .ina({xm_d1[77], xm_d0[77]}), .inb({coutr1, coutr0}),
    .rnd(r[591]), .s(s[591]), .clk(clk), .out({w_m1[77], w_m0[77]}));
MSKand_opini2_d2_pini u_m_78 (
    .ina({xm_d1[78], xm_d0[78]}), .inb({coutr1, coutr0}),
    .rnd(r[592]), .s(s[592]), .clk(clk), .out({w_m1[78], w_m0[78]}));
MSKand_opini2_d2_pini u_m_79 (
    .ina({xm_d1[79], xm_d0[79]}), .inb({coutr1, coutr0}),
    .rnd(r[593]), .s(s[593]), .clk(clk), .out({w_m1[79], w_m0[79]}));
MSKand_opini2_d2_pini u_m_80 (
    .ina({xm_d1[80], xm_d0[80]}), .inb({coutr1, coutr0}),
    .rnd(r[594]), .s(s[594]), .clk(clk), .out({w_m1[80], w_m0[80]}));
MSKand_opini2_d2_pini u_m_81 (
    .ina({xm_d1[81], xm_d0[81]}), .inb({coutr1, coutr0}),
    .rnd(r[595]), .s(s[595]), .clk(clk), .out({w_m1[81], w_m0[81]}));
MSKand_opini2_d2_pini u_m_82 (
    .ina({xm_d1[82], xm_d0[82]}), .inb({coutr1, coutr0}),
    .rnd(r[596]), .s(s[596]), .clk(clk), .out({w_m1[82], w_m0[82]}));
MSKand_opini2_d2_pini u_m_83 (
    .ina({xm_d1[83], xm_d0[83]}), .inb({coutr1, coutr0}),
    .rnd(r[597]), .s(s[597]), .clk(clk), .out({w_m1[83], w_m0[83]}));
MSKand_opini2_d2_pini u_m_84 (
    .ina({xm_d1[84], xm_d0[84]}), .inb({coutr1, coutr0}),
    .rnd(r[598]), .s(s[598]), .clk(clk), .out({w_m1[84], w_m0[84]}));
MSKand_opini2_d2_pini u_m_85 (
    .ina({xm_d1[85], xm_d0[85]}), .inb({coutr1, coutr0}),
    .rnd(r[599]), .s(s[599]), .clk(clk), .out({w_m1[85], w_m0[85]}));
MSKand_opini2_d2_pini u_m_86 (
    .ina({xm_d1[86], xm_d0[86]}), .inb({coutr1, coutr0}),
    .rnd(r[600]), .s(s[600]), .clk(clk), .out({w_m1[86], w_m0[86]}));
MSKand_opini2_d2_pini u_m_87 (
    .ina({xm_d1[87], xm_d0[87]}), .inb({coutr1, coutr0}),
    .rnd(r[601]), .s(s[601]), .clk(clk), .out({w_m1[87], w_m0[87]}));
MSKand_opini2_d2_pini u_m_88 (
    .ina({xm_d1[88], xm_d0[88]}), .inb({coutr1, coutr0}),
    .rnd(r[602]), .s(s[602]), .clk(clk), .out({w_m1[88], w_m0[88]}));
MSKand_opini2_d2_pini u_m_89 (
    .ina({xm_d1[89], xm_d0[89]}), .inb({coutr1, coutr0}),
    .rnd(r[603]), .s(s[603]), .clk(clk), .out({w_m1[89], w_m0[89]}));
MSKand_opini2_d2_pini u_m_90 (
    .ina({xm_d1[90], xm_d0[90]}), .inb({coutr1, coutr0}),
    .rnd(r[604]), .s(s[604]), .clk(clk), .out({w_m1[90], w_m0[90]}));
MSKand_opini2_d2_pini u_m_91 (
    .ina({xm_d1[91], xm_d0[91]}), .inb({coutr1, coutr0}),
    .rnd(r[605]), .s(s[605]), .clk(clk), .out({w_m1[91], w_m0[91]}));
MSKand_opini2_d2_pini u_m_92 (
    .ina({xm_d1[92], xm_d0[92]}), .inb({coutr1, coutr0}),
    .rnd(r[606]), .s(s[606]), .clk(clk), .out({w_m1[92], w_m0[92]}));
MSKand_opini2_d2_pini u_m_93 (
    .ina({xm_d1[93], xm_d0[93]}), .inb({coutr1, coutr0}),
    .rnd(r[607]), .s(s[607]), .clk(clk), .out({w_m1[93], w_m0[93]}));
MSKand_opini2_d2_pini u_m_94 (
    .ina({xm_d1[94], xm_d0[94]}), .inb({coutr1, coutr0}),
    .rnd(r[608]), .s(s[608]), .clk(clk), .out({w_m1[94], w_m0[94]}));
MSKand_opini2_d2_pini u_m_95 (
    .ina({xm_d1[95], xm_d0[95]}), .inb({coutr1, coutr0}),
    .rnd(r[609]), .s(s[609]), .clk(clk), .out({w_m1[95], w_m0[95]}));
MSKand_opini2_d2_pini u_m_96 (
    .ina({xm_d1[96], xm_d0[96]}), .inb({coutr1, coutr0}),
    .rnd(r[610]), .s(s[610]), .clk(clk), .out({w_m1[96], w_m0[96]}));
MSKand_opini2_d2_pini u_m_97 (
    .ina({xm_d1[97], xm_d0[97]}), .inb({coutr1, coutr0}),
    .rnd(r[611]), .s(s[611]), .clk(clk), .out({w_m1[97], w_m0[97]}));
MSKand_opini2_d2_pini u_m_98 (
    .ina({xm_d1[98], xm_d0[98]}), .inb({coutr1, coutr0}),
    .rnd(r[612]), .s(s[612]), .clk(clk), .out({w_m1[98], w_m0[98]}));
MSKand_opini2_d2_pini u_m_99 (
    .ina({xm_d1[99], xm_d0[99]}), .inb({coutr1, coutr0}),
    .rnd(r[613]), .s(s[613]), .clk(clk), .out({w_m1[99], w_m0[99]}));
MSKand_opini2_d2_pini u_m_100 (
    .ina({xm_d1[100], xm_d0[100]}), .inb({coutr1, coutr0}),
    .rnd(r[614]), .s(s[614]), .clk(clk), .out({w_m1[100], w_m0[100]}));
MSKand_opini2_d2_pini u_m_101 (
    .ina({xm_d1[101], xm_d0[101]}), .inb({coutr1, coutr0}),
    .rnd(r[615]), .s(s[615]), .clk(clk), .out({w_m1[101], w_m0[101]}));
MSKand_opini2_d2_pini u_m_102 (
    .ina({xm_d1[102], xm_d0[102]}), .inb({coutr1, coutr0}),
    .rnd(r[616]), .s(s[616]), .clk(clk), .out({w_m1[102], w_m0[102]}));
MSKand_opini2_d2_pini u_m_103 (
    .ina({xm_d1[103], xm_d0[103]}), .inb({coutr1, coutr0}),
    .rnd(r[617]), .s(s[617]), .clk(clk), .out({w_m1[103], w_m0[103]}));
MSKand_opini2_d2_pini u_m_104 (
    .ina({xm_d1[104], xm_d0[104]}), .inb({coutr1, coutr0}),
    .rnd(r[618]), .s(s[618]), .clk(clk), .out({w_m1[104], w_m0[104]}));
MSKand_opini2_d2_pini u_m_105 (
    .ina({xm_d1[105], xm_d0[105]}), .inb({coutr1, coutr0}),
    .rnd(r[619]), .s(s[619]), .clk(clk), .out({w_m1[105], w_m0[105]}));
MSKand_opini2_d2_pini u_m_106 (
    .ina({xm_d1[106], xm_d0[106]}), .inb({coutr1, coutr0}),
    .rnd(r[620]), .s(s[620]), .clk(clk), .out({w_m1[106], w_m0[106]}));
MSKand_opini2_d2_pini u_m_107 (
    .ina({xm_d1[107], xm_d0[107]}), .inb({coutr1, coutr0}),
    .rnd(r[621]), .s(s[621]), .clk(clk), .out({w_m1[107], w_m0[107]}));
MSKand_opini2_d2_pini u_m_108 (
    .ina({xm_d1[108], xm_d0[108]}), .inb({coutr1, coutr0}),
    .rnd(r[622]), .s(s[622]), .clk(clk), .out({w_m1[108], w_m0[108]}));
MSKand_opini2_d2_pini u_m_109 (
    .ina({xm_d1[109], xm_d0[109]}), .inb({coutr1, coutr0}),
    .rnd(r[623]), .s(s[623]), .clk(clk), .out({w_m1[109], w_m0[109]}));
MSKand_opini2_d2_pini u_m_110 (
    .ina({xm_d1[110], xm_d0[110]}), .inb({coutr1, coutr0}),
    .rnd(r[624]), .s(s[624]), .clk(clk), .out({w_m1[110], w_m0[110]}));
MSKand_opini2_d2_pini u_m_111 (
    .ina({xm_d1[111], xm_d0[111]}), .inb({coutr1, coutr0}),
    .rnd(r[625]), .s(s[625]), .clk(clk), .out({w_m1[111], w_m0[111]}));
MSKand_opini2_d2_pini u_m_112 (
    .ina({xm_d1[112], xm_d0[112]}), .inb({coutr1, coutr0}),
    .rnd(r[626]), .s(s[626]), .clk(clk), .out({w_m1[112], w_m0[112]}));
MSKand_opini2_d2_pini u_m_113 (
    .ina({xm_d1[113], xm_d0[113]}), .inb({coutr1, coutr0}),
    .rnd(r[627]), .s(s[627]), .clk(clk), .out({w_m1[113], w_m0[113]}));
MSKand_opini2_d2_pini u_m_114 (
    .ina({xm_d1[114], xm_d0[114]}), .inb({coutr1, coutr0}),
    .rnd(r[628]), .s(s[628]), .clk(clk), .out({w_m1[114], w_m0[114]}));
MSKand_opini2_d2_pini u_m_115 (
    .ina({xm_d1[115], xm_d0[115]}), .inb({coutr1, coutr0}),
    .rnd(r[629]), .s(s[629]), .clk(clk), .out({w_m1[115], w_m0[115]}));
MSKand_opini2_d2_pini u_m_116 (
    .ina({xm_d1[116], xm_d0[116]}), .inb({coutr1, coutr0}),
    .rnd(r[630]), .s(s[630]), .clk(clk), .out({w_m1[116], w_m0[116]}));
MSKand_opini2_d2_pini u_m_117 (
    .ina({xm_d1[117], xm_d0[117]}), .inb({coutr1, coutr0}),
    .rnd(r[631]), .s(s[631]), .clk(clk), .out({w_m1[117], w_m0[117]}));
MSKand_opini2_d2_pini u_m_118 (
    .ina({xm_d1[118], xm_d0[118]}), .inb({coutr1, coutr0}),
    .rnd(r[632]), .s(s[632]), .clk(clk), .out({w_m1[118], w_m0[118]}));
MSKand_opini2_d2_pini u_m_119 (
    .ina({xm_d1[119], xm_d0[119]}), .inb({coutr1, coutr0}),
    .rnd(r[633]), .s(s[633]), .clk(clk), .out({w_m1[119], w_m0[119]}));
MSKand_opini2_d2_pini u_m_120 (
    .ina({xm_d1[120], xm_d0[120]}), .inb({coutr1, coutr0}),
    .rnd(r[634]), .s(s[634]), .clk(clk), .out({w_m1[120], w_m0[120]}));
MSKand_opini2_d2_pini u_m_121 (
    .ina({xm_d1[121], xm_d0[121]}), .inb({coutr1, coutr0}),
    .rnd(r[635]), .s(s[635]), .clk(clk), .out({w_m1[121], w_m0[121]}));
MSKand_opini2_d2_pini u_m_122 (
    .ina({xm_d1[122], xm_d0[122]}), .inb({coutr1, coutr0}),
    .rnd(r[636]), .s(s[636]), .clk(clk), .out({w_m1[122], w_m0[122]}));
MSKand_opini2_d2_pini u_m_123 (
    .ina({xm_d1[123], xm_d0[123]}), .inb({coutr1, coutr0}),
    .rnd(r[637]), .s(s[637]), .clk(clk), .out({w_m1[123], w_m0[123]}));
MSKand_opini2_d2_pini u_m_124 (
    .ina({xm_d1[124], xm_d0[124]}), .inb({coutr1, coutr0}),
    .rnd(r[638]), .s(s[638]), .clk(clk), .out({w_m1[124], w_m0[124]}));
MSKand_opini2_d2_pini u_m_125 (
    .ina({xm_d1[125], xm_d0[125]}), .inb({coutr1, coutr0}),
    .rnd(r[639]), .s(s[639]), .clk(clk), .out({w_m1[125], w_m0[125]}));
MSKand_opini2_d2_pini u_m_126 (
    .ina({xm_d1[126], xm_d0[126]}), .inb({coutr1, coutr0}),
    .rnd(r[640]), .s(s[640]), .clk(clk), .out({w_m1[126], w_m0[126]}));
MSKand_opini2_d2_pini u_m_127 (
    .ina({xm_d1[127], xm_d0[127]}), .inb({coutr1, coutr0}),
    .rnd(r[641]), .s(s[641]), .clk(clk), .out({w_m1[127], w_m0[127]}));
MSKand_opini2_d2_pini u_m_128 (
    .ina({xm_d1[128], xm_d0[128]}), .inb({coutr1, coutr0}),
    .rnd(r[642]), .s(s[642]), .clk(clk), .out({w_m1[128], w_m0[128]}));
MSKand_opini2_d2_pini u_m_129 (
    .ina({xm_d1[129], xm_d0[129]}), .inb({coutr1, coutr0}),
    .rnd(r[643]), .s(s[643]), .clk(clk), .out({w_m1[129], w_m0[129]}));
MSKand_opini2_d2_pini u_m_130 (
    .ina({xm_d1[130], xm_d0[130]}), .inb({coutr1, coutr0}),
    .rnd(r[644]), .s(s[644]), .clk(clk), .out({w_m1[130], w_m0[130]}));
MSKand_opini2_d2_pini u_m_131 (
    .ina({xm_d1[131], xm_d0[131]}), .inb({coutr1, coutr0}),
    .rnd(r[645]), .s(s[645]), .clk(clk), .out({w_m1[131], w_m0[131]}));
MSKand_opini2_d2_pini u_m_132 (
    .ina({xm_d1[132], xm_d0[132]}), .inb({coutr1, coutr0}),
    .rnd(r[646]), .s(s[646]), .clk(clk), .out({w_m1[132], w_m0[132]}));
MSKand_opini2_d2_pini u_m_133 (
    .ina({xm_d1[133], xm_d0[133]}), .inb({coutr1, coutr0}),
    .rnd(r[647]), .s(s[647]), .clk(clk), .out({w_m1[133], w_m0[133]}));
MSKand_opini2_d2_pini u_m_134 (
    .ina({xm_d1[134], xm_d0[134]}), .inb({coutr1, coutr0}),
    .rnd(r[648]), .s(s[648]), .clk(clk), .out({w_m1[134], w_m0[134]}));
MSKand_opini2_d2_pini u_m_135 (
    .ina({xm_d1[135], xm_d0[135]}), .inb({coutr1, coutr0}),
    .rnd(r[649]), .s(s[649]), .clk(clk), .out({w_m1[135], w_m0[135]}));
MSKand_opini2_d2_pini u_m_136 (
    .ina({xm_d1[136], xm_d0[136]}), .inb({coutr1, coutr0}),
    .rnd(r[650]), .s(s[650]), .clk(clk), .out({w_m1[136], w_m0[136]}));
MSKand_opini2_d2_pini u_m_137 (
    .ina({xm_d1[137], xm_d0[137]}), .inb({coutr1, coutr0}),
    .rnd(r[651]), .s(s[651]), .clk(clk), .out({w_m1[137], w_m0[137]}));
MSKand_opini2_d2_pini u_m_138 (
    .ina({xm_d1[138], xm_d0[138]}), .inb({coutr1, coutr0}),
    .rnd(r[652]), .s(s[652]), .clk(clk), .out({w_m1[138], w_m0[138]}));
MSKand_opini2_d2_pini u_m_139 (
    .ina({xm_d1[139], xm_d0[139]}), .inb({coutr1, coutr0}),
    .rnd(r[653]), .s(s[653]), .clk(clk), .out({w_m1[139], w_m0[139]}));
MSKand_opini2_d2_pini u_m_140 (
    .ina({xm_d1[140], xm_d0[140]}), .inb({coutr1, coutr0}),
    .rnd(r[654]), .s(s[654]), .clk(clk), .out({w_m1[140], w_m0[140]}));
MSKand_opini2_d2_pini u_m_141 (
    .ina({xm_d1[141], xm_d0[141]}), .inb({coutr1, coutr0}),
    .rnd(r[655]), .s(s[655]), .clk(clk), .out({w_m1[141], w_m0[141]}));
MSKand_opini2_d2_pini u_m_142 (
    .ina({xm_d1[142], xm_d0[142]}), .inb({coutr1, coutr0}),
    .rnd(r[656]), .s(s[656]), .clk(clk), .out({w_m1[142], w_m0[142]}));
MSKand_opini2_d2_pini u_m_143 (
    .ina({xm_d1[143], xm_d0[143]}), .inb({coutr1, coutr0}),
    .rnd(r[657]), .s(s[657]), .clk(clk), .out({w_m1[143], w_m0[143]}));
MSKand_opini2_d2_pini u_m_144 (
    .ina({xm_d1[144], xm_d0[144]}), .inb({coutr1, coutr0}),
    .rnd(r[658]), .s(s[658]), .clk(clk), .out({w_m1[144], w_m0[144]}));
MSKand_opini2_d2_pini u_m_145 (
    .ina({xm_d1[145], xm_d0[145]}), .inb({coutr1, coutr0}),
    .rnd(r[659]), .s(s[659]), .clk(clk), .out({w_m1[145], w_m0[145]}));
MSKand_opini2_d2_pini u_m_146 (
    .ina({xm_d1[146], xm_d0[146]}), .inb({coutr1, coutr0}),
    .rnd(r[660]), .s(s[660]), .clk(clk), .out({w_m1[146], w_m0[146]}));
MSKand_opini2_d2_pini u_m_147 (
    .ina({xm_d1[147], xm_d0[147]}), .inb({coutr1, coutr0}),
    .rnd(r[661]), .s(s[661]), .clk(clk), .out({w_m1[147], w_m0[147]}));
MSKand_opini2_d2_pini u_m_148 (
    .ina({xm_d1[148], xm_d0[148]}), .inb({coutr1, coutr0}),
    .rnd(r[662]), .s(s[662]), .clk(clk), .out({w_m1[148], w_m0[148]}));
MSKand_opini2_d2_pini u_m_149 (
    .ina({xm_d1[149], xm_d0[149]}), .inb({coutr1, coutr0}),
    .rnd(r[663]), .s(s[663]), .clk(clk), .out({w_m1[149], w_m0[149]}));
MSKand_opini2_d2_pini u_m_150 (
    .ina({xm_d1[150], xm_d0[150]}), .inb({coutr1, coutr0}),
    .rnd(r[664]), .s(s[664]), .clk(clk), .out({w_m1[150], w_m0[150]}));
MSKand_opini2_d2_pini u_m_151 (
    .ina({xm_d1[151], xm_d0[151]}), .inb({coutr1, coutr0}),
    .rnd(r[665]), .s(s[665]), .clk(clk), .out({w_m1[151], w_m0[151]}));
MSKand_opini2_d2_pini u_m_152 (
    .ina({xm_d1[152], xm_d0[152]}), .inb({coutr1, coutr0}),
    .rnd(r[666]), .s(s[666]), .clk(clk), .out({w_m1[152], w_m0[152]}));
MSKand_opini2_d2_pini u_m_153 (
    .ina({xm_d1[153], xm_d0[153]}), .inb({coutr1, coutr0}),
    .rnd(r[667]), .s(s[667]), .clk(clk), .out({w_m1[153], w_m0[153]}));
MSKand_opini2_d2_pini u_m_154 (
    .ina({xm_d1[154], xm_d0[154]}), .inb({coutr1, coutr0}),
    .rnd(r[668]), .s(s[668]), .clk(clk), .out({w_m1[154], w_m0[154]}));
MSKand_opini2_d2_pini u_m_155 (
    .ina({xm_d1[155], xm_d0[155]}), .inb({coutr1, coutr0}),
    .rnd(r[669]), .s(s[669]), .clk(clk), .out({w_m1[155], w_m0[155]}));
MSKand_opini2_d2_pini u_m_156 (
    .ina({xm_d1[156], xm_d0[156]}), .inb({coutr1, coutr0}),
    .rnd(r[670]), .s(s[670]), .clk(clk), .out({w_m1[156], w_m0[156]}));
MSKand_opini2_d2_pini u_m_157 (
    .ina({xm_d1[157], xm_d0[157]}), .inb({coutr1, coutr0}),
    .rnd(r[671]), .s(s[671]), .clk(clk), .out({w_m1[157], w_m0[157]}));
MSKand_opini2_d2_pini u_m_158 (
    .ina({xm_d1[158], xm_d0[158]}), .inb({coutr1, coutr0}),
    .rnd(r[672]), .s(s[672]), .clk(clk), .out({w_m1[158], w_m0[158]}));
MSKand_opini2_d2_pini u_m_159 (
    .ina({xm_d1[159], xm_d0[159]}), .inb({coutr1, coutr0}),
    .rnd(r[673]), .s(s[673]), .clk(clk), .out({w_m1[159], w_m0[159]}));
MSKand_opini2_d2_pini u_m_160 (
    .ina({xm_d1[160], xm_d0[160]}), .inb({coutr1, coutr0}),
    .rnd(r[674]), .s(s[674]), .clk(clk), .out({w_m1[160], w_m0[160]}));
MSKand_opini2_d2_pini u_m_161 (
    .ina({xm_d1[161], xm_d0[161]}), .inb({coutr1, coutr0}),
    .rnd(r[675]), .s(s[675]), .clk(clk), .out({w_m1[161], w_m0[161]}));
MSKand_opini2_d2_pini u_m_162 (
    .ina({xm_d1[162], xm_d0[162]}), .inb({coutr1, coutr0}),
    .rnd(r[676]), .s(s[676]), .clk(clk), .out({w_m1[162], w_m0[162]}));
MSKand_opini2_d2_pini u_m_163 (
    .ina({xm_d1[163], xm_d0[163]}), .inb({coutr1, coutr0}),
    .rnd(r[677]), .s(s[677]), .clk(clk), .out({w_m1[163], w_m0[163]}));
MSKand_opini2_d2_pini u_m_164 (
    .ina({xm_d1[164], xm_d0[164]}), .inb({coutr1, coutr0}),
    .rnd(r[678]), .s(s[678]), .clk(clk), .out({w_m1[164], w_m0[164]}));
MSKand_opini2_d2_pini u_m_165 (
    .ina({xm_d1[165], xm_d0[165]}), .inb({coutr1, coutr0}),
    .rnd(r[679]), .s(s[679]), .clk(clk), .out({w_m1[165], w_m0[165]}));
MSKand_opini2_d2_pini u_m_166 (
    .ina({xm_d1[166], xm_d0[166]}), .inb({coutr1, coutr0}),
    .rnd(r[680]), .s(s[680]), .clk(clk), .out({w_m1[166], w_m0[166]}));
MSKand_opini2_d2_pini u_m_167 (
    .ina({xm_d1[167], xm_d0[167]}), .inb({coutr1, coutr0}),
    .rnd(r[681]), .s(s[681]), .clk(clk), .out({w_m1[167], w_m0[167]}));
MSKand_opini2_d2_pini u_m_168 (
    .ina({xm_d1[168], xm_d0[168]}), .inb({coutr1, coutr0}),
    .rnd(r[682]), .s(s[682]), .clk(clk), .out({w_m1[168], w_m0[168]}));
MSKand_opini2_d2_pini u_m_169 (
    .ina({xm_d1[169], xm_d0[169]}), .inb({coutr1, coutr0}),
    .rnd(r[683]), .s(s[683]), .clk(clk), .out({w_m1[169], w_m0[169]}));
MSKand_opini2_d2_pini u_m_170 (
    .ina({xm_d1[170], xm_d0[170]}), .inb({coutr1, coutr0}),
    .rnd(r[684]), .s(s[684]), .clk(clk), .out({w_m1[170], w_m0[170]}));
MSKand_opini2_d2_pini u_m_171 (
    .ina({xm_d1[171], xm_d0[171]}), .inb({coutr1, coutr0}),
    .rnd(r[685]), .s(s[685]), .clk(clk), .out({w_m1[171], w_m0[171]}));
MSKand_opini2_d2_pini u_m_172 (
    .ina({xm_d1[172], xm_d0[172]}), .inb({coutr1, coutr0}),
    .rnd(r[686]), .s(s[686]), .clk(clk), .out({w_m1[172], w_m0[172]}));
MSKand_opini2_d2_pini u_m_173 (
    .ina({xm_d1[173], xm_d0[173]}), .inb({coutr1, coutr0}),
    .rnd(r[687]), .s(s[687]), .clk(clk), .out({w_m1[173], w_m0[173]}));
MSKand_opini2_d2_pini u_m_174 (
    .ina({xm_d1[174], xm_d0[174]}), .inb({coutr1, coutr0}),
    .rnd(r[688]), .s(s[688]), .clk(clk), .out({w_m1[174], w_m0[174]}));
MSKand_opini2_d2_pini u_m_175 (
    .ina({xm_d1[175], xm_d0[175]}), .inb({coutr1, coutr0}),
    .rnd(r[689]), .s(s[689]), .clk(clk), .out({w_m1[175], w_m0[175]}));
MSKand_opini2_d2_pini u_m_176 (
    .ina({xm_d1[176], xm_d0[176]}), .inb({coutr1, coutr0}),
    .rnd(r[690]), .s(s[690]), .clk(clk), .out({w_m1[176], w_m0[176]}));
MSKand_opini2_d2_pini u_m_177 (
    .ina({xm_d1[177], xm_d0[177]}), .inb({coutr1, coutr0}),
    .rnd(r[691]), .s(s[691]), .clk(clk), .out({w_m1[177], w_m0[177]}));
MSKand_opini2_d2_pini u_m_178 (
    .ina({xm_d1[178], xm_d0[178]}), .inb({coutr1, coutr0}),
    .rnd(r[692]), .s(s[692]), .clk(clk), .out({w_m1[178], w_m0[178]}));
MSKand_opini2_d2_pini u_m_179 (
    .ina({xm_d1[179], xm_d0[179]}), .inb({coutr1, coutr0}),
    .rnd(r[693]), .s(s[693]), .clk(clk), .out({w_m1[179], w_m0[179]}));
MSKand_opini2_d2_pini u_m_180 (
    .ina({xm_d1[180], xm_d0[180]}), .inb({coutr1, coutr0}),
    .rnd(r[694]), .s(s[694]), .clk(clk), .out({w_m1[180], w_m0[180]}));
MSKand_opini2_d2_pini u_m_181 (
    .ina({xm_d1[181], xm_d0[181]}), .inb({coutr1, coutr0}),
    .rnd(r[695]), .s(s[695]), .clk(clk), .out({w_m1[181], w_m0[181]}));
MSKand_opini2_d2_pini u_m_182 (
    .ina({xm_d1[182], xm_d0[182]}), .inb({coutr1, coutr0}),
    .rnd(r[696]), .s(s[696]), .clk(clk), .out({w_m1[182], w_m0[182]}));
MSKand_opini2_d2_pini u_m_183 (
    .ina({xm_d1[183], xm_d0[183]}), .inb({coutr1, coutr0}),
    .rnd(r[697]), .s(s[697]), .clk(clk), .out({w_m1[183], w_m0[183]}));
MSKand_opini2_d2_pini u_m_184 (
    .ina({xm_d1[184], xm_d0[184]}), .inb({coutr1, coutr0}),
    .rnd(r[698]), .s(s[698]), .clk(clk), .out({w_m1[184], w_m0[184]}));
MSKand_opini2_d2_pini u_m_185 (
    .ina({xm_d1[185], xm_d0[185]}), .inb({coutr1, coutr0}),
    .rnd(r[699]), .s(s[699]), .clk(clk), .out({w_m1[185], w_m0[185]}));
MSKand_opini2_d2_pini u_m_186 (
    .ina({xm_d1[186], xm_d0[186]}), .inb({coutr1, coutr0}),
    .rnd(r[700]), .s(s[700]), .clk(clk), .out({w_m1[186], w_m0[186]}));
MSKand_opini2_d2_pini u_m_187 (
    .ina({xm_d1[187], xm_d0[187]}), .inb({coutr1, coutr0}),
    .rnd(r[701]), .s(s[701]), .clk(clk), .out({w_m1[187], w_m0[187]}));
MSKand_opini2_d2_pini u_m_188 (
    .ina({xm_d1[188], xm_d0[188]}), .inb({coutr1, coutr0}),
    .rnd(r[702]), .s(s[702]), .clk(clk), .out({w_m1[188], w_m0[188]}));
MSKand_opini2_d2_pini u_m_189 (
    .ina({xm_d1[189], xm_d0[189]}), .inb({coutr1, coutr0}),
    .rnd(r[703]), .s(s[703]), .clk(clk), .out({w_m1[189], w_m0[189]}));
MSKand_opini2_d2_pini u_m_190 (
    .ina({xm_d1[190], xm_d0[190]}), .inb({coutr1, coutr0}),
    .rnd(r[704]), .s(s[704]), .clk(clk), .out({w_m1[190], w_m0[190]}));
MSKand_opini2_d2_pini u_m_191 (
    .ina({xm_d1[191], xm_d0[191]}), .inb({coutr1, coutr0}),
    .rnd(r[705]), .s(s[705]), .clk(clk), .out({w_m1[191], w_m0[191]}));
MSKand_opini2_d2_pini u_m_192 (
    .ina({xm_d1[192], xm_d0[192]}), .inb({coutr1, coutr0}),
    .rnd(r[706]), .s(s[706]), .clk(clk), .out({w_m1[192], w_m0[192]}));
MSKand_opini2_d2_pini u_m_193 (
    .ina({xm_d1[193], xm_d0[193]}), .inb({coutr1, coutr0}),
    .rnd(r[707]), .s(s[707]), .clk(clk), .out({w_m1[193], w_m0[193]}));
MSKand_opini2_d2_pini u_m_194 (
    .ina({xm_d1[194], xm_d0[194]}), .inb({coutr1, coutr0}),
    .rnd(r[708]), .s(s[708]), .clk(clk), .out({w_m1[194], w_m0[194]}));
MSKand_opini2_d2_pini u_m_195 (
    .ina({xm_d1[195], xm_d0[195]}), .inb({coutr1, coutr0}),
    .rnd(r[709]), .s(s[709]), .clk(clk), .out({w_m1[195], w_m0[195]}));
MSKand_opini2_d2_pini u_m_196 (
    .ina({xm_d1[196], xm_d0[196]}), .inb({coutr1, coutr0}),
    .rnd(r[710]), .s(s[710]), .clk(clk), .out({w_m1[196], w_m0[196]}));
MSKand_opini2_d2_pini u_m_197 (
    .ina({xm_d1[197], xm_d0[197]}), .inb({coutr1, coutr0}),
    .rnd(r[711]), .s(s[711]), .clk(clk), .out({w_m1[197], w_m0[197]}));
MSKand_opini2_d2_pini u_m_198 (
    .ina({xm_d1[198], xm_d0[198]}), .inb({coutr1, coutr0}),
    .rnd(r[712]), .s(s[712]), .clk(clk), .out({w_m1[198], w_m0[198]}));
MSKand_opini2_d2_pini u_m_199 (
    .ina({xm_d1[199], xm_d0[199]}), .inb({coutr1, coutr0}),
    .rnd(r[713]), .s(s[713]), .clk(clk), .out({w_m1[199], w_m0[199]}));
MSKand_opini2_d2_pini u_m_200 (
    .ina({xm_d1[200], xm_d0[200]}), .inb({coutr1, coutr0}),
    .rnd(r[714]), .s(s[714]), .clk(clk), .out({w_m1[200], w_m0[200]}));
MSKand_opini2_d2_pini u_m_201 (
    .ina({xm_d1[201], xm_d0[201]}), .inb({coutr1, coutr0}),
    .rnd(r[715]), .s(s[715]), .clk(clk), .out({w_m1[201], w_m0[201]}));
MSKand_opini2_d2_pini u_m_202 (
    .ina({xm_d1[202], xm_d0[202]}), .inb({coutr1, coutr0}),
    .rnd(r[716]), .s(s[716]), .clk(clk), .out({w_m1[202], w_m0[202]}));
MSKand_opini2_d2_pini u_m_203 (
    .ina({xm_d1[203], xm_d0[203]}), .inb({coutr1, coutr0}),
    .rnd(r[717]), .s(s[717]), .clk(clk), .out({w_m1[203], w_m0[203]}));
MSKand_opini2_d2_pini u_m_204 (
    .ina({xm_d1[204], xm_d0[204]}), .inb({coutr1, coutr0}),
    .rnd(r[718]), .s(s[718]), .clk(clk), .out({w_m1[204], w_m0[204]}));
MSKand_opini2_d2_pini u_m_205 (
    .ina({xm_d1[205], xm_d0[205]}), .inb({coutr1, coutr0}),
    .rnd(r[719]), .s(s[719]), .clk(clk), .out({w_m1[205], w_m0[205]}));
MSKand_opini2_d2_pini u_m_206 (
    .ina({xm_d1[206], xm_d0[206]}), .inb({coutr1, coutr0}),
    .rnd(r[720]), .s(s[720]), .clk(clk), .out({w_m1[206], w_m0[206]}));
MSKand_opini2_d2_pini u_m_207 (
    .ina({xm_d1[207], xm_d0[207]}), .inb({coutr1, coutr0}),
    .rnd(r[721]), .s(s[721]), .clk(clk), .out({w_m1[207], w_m0[207]}));
MSKand_opini2_d2_pini u_m_208 (
    .ina({xm_d1[208], xm_d0[208]}), .inb({coutr1, coutr0}),
    .rnd(r[722]), .s(s[722]), .clk(clk), .out({w_m1[208], w_m0[208]}));
MSKand_opini2_d2_pini u_m_209 (
    .ina({xm_d1[209], xm_d0[209]}), .inb({coutr1, coutr0}),
    .rnd(r[723]), .s(s[723]), .clk(clk), .out({w_m1[209], w_m0[209]}));
MSKand_opini2_d2_pini u_m_210 (
    .ina({xm_d1[210], xm_d0[210]}), .inb({coutr1, coutr0}),
    .rnd(r[724]), .s(s[724]), .clk(clk), .out({w_m1[210], w_m0[210]}));
MSKand_opini2_d2_pini u_m_211 (
    .ina({xm_d1[211], xm_d0[211]}), .inb({coutr1, coutr0}),
    .rnd(r[725]), .s(s[725]), .clk(clk), .out({w_m1[211], w_m0[211]}));
MSKand_opini2_d2_pini u_m_212 (
    .ina({xm_d1[212], xm_d0[212]}), .inb({coutr1, coutr0}),
    .rnd(r[726]), .s(s[726]), .clk(clk), .out({w_m1[212], w_m0[212]}));
MSKand_opini2_d2_pini u_m_213 (
    .ina({xm_d1[213], xm_d0[213]}), .inb({coutr1, coutr0}),
    .rnd(r[727]), .s(s[727]), .clk(clk), .out({w_m1[213], w_m0[213]}));
MSKand_opini2_d2_pini u_m_214 (
    .ina({xm_d1[214], xm_d0[214]}), .inb({coutr1, coutr0}),
    .rnd(r[728]), .s(s[728]), .clk(clk), .out({w_m1[214], w_m0[214]}));
MSKand_opini2_d2_pini u_m_215 (
    .ina({xm_d1[215], xm_d0[215]}), .inb({coutr1, coutr0}),
    .rnd(r[729]), .s(s[729]), .clk(clk), .out({w_m1[215], w_m0[215]}));
MSKand_opini2_d2_pini u_m_216 (
    .ina({xm_d1[216], xm_d0[216]}), .inb({coutr1, coutr0}),
    .rnd(r[730]), .s(s[730]), .clk(clk), .out({w_m1[216], w_m0[216]}));
MSKand_opini2_d2_pini u_m_217 (
    .ina({xm_d1[217], xm_d0[217]}), .inb({coutr1, coutr0}),
    .rnd(r[731]), .s(s[731]), .clk(clk), .out({w_m1[217], w_m0[217]}));
MSKand_opini2_d2_pini u_m_218 (
    .ina({xm_d1[218], xm_d0[218]}), .inb({coutr1, coutr0}),
    .rnd(r[732]), .s(s[732]), .clk(clk), .out({w_m1[218], w_m0[218]}));
MSKand_opini2_d2_pini u_m_219 (
    .ina({xm_d1[219], xm_d0[219]}), .inb({coutr1, coutr0}),
    .rnd(r[733]), .s(s[733]), .clk(clk), .out({w_m1[219], w_m0[219]}));
MSKand_opini2_d2_pini u_m_220 (
    .ina({xm_d1[220], xm_d0[220]}), .inb({coutr1, coutr0}),
    .rnd(r[734]), .s(s[734]), .clk(clk), .out({w_m1[220], w_m0[220]}));
MSKand_opini2_d2_pini u_m_221 (
    .ina({xm_d1[221], xm_d0[221]}), .inb({coutr1, coutr0}),
    .rnd(r[735]), .s(s[735]), .clk(clk), .out({w_m1[221], w_m0[221]}));
MSKand_opini2_d2_pini u_m_222 (
    .ina({xm_d1[222], xm_d0[222]}), .inb({coutr1, coutr0}),
    .rnd(r[736]), .s(s[736]), .clk(clk), .out({w_m1[222], w_m0[222]}));
MSKand_opini2_d2_pini u_m_223 (
    .ina({xm_d1[223], xm_d0[223]}), .inb({coutr1, coutr0}),
    .rnd(r[737]), .s(s[737]), .clk(clk), .out({w_m1[223], w_m0[223]}));
MSKand_opini2_d2_pini u_m_224 (
    .ina({xm_d1[224], xm_d0[224]}), .inb({coutr1, coutr0}),
    .rnd(r[738]), .s(s[738]), .clk(clk), .out({w_m1[224], w_m0[224]}));
MSKand_opini2_d2_pini u_m_225 (
    .ina({xm_d1[225], xm_d0[225]}), .inb({coutr1, coutr0}),
    .rnd(r[739]), .s(s[739]), .clk(clk), .out({w_m1[225], w_m0[225]}));
MSKand_opini2_d2_pini u_m_226 (
    .ina({xm_d1[226], xm_d0[226]}), .inb({coutr1, coutr0}),
    .rnd(r[740]), .s(s[740]), .clk(clk), .out({w_m1[226], w_m0[226]}));
MSKand_opini2_d2_pini u_m_227 (
    .ina({xm_d1[227], xm_d0[227]}), .inb({coutr1, coutr0}),
    .rnd(r[741]), .s(s[741]), .clk(clk), .out({w_m1[227], w_m0[227]}));
MSKand_opini2_d2_pini u_m_228 (
    .ina({xm_d1[228], xm_d0[228]}), .inb({coutr1, coutr0}),
    .rnd(r[742]), .s(s[742]), .clk(clk), .out({w_m1[228], w_m0[228]}));
MSKand_opini2_d2_pini u_m_229 (
    .ina({xm_d1[229], xm_d0[229]}), .inb({coutr1, coutr0}),
    .rnd(r[743]), .s(s[743]), .clk(clk), .out({w_m1[229], w_m0[229]}));
MSKand_opini2_d2_pini u_m_230 (
    .ina({xm_d1[230], xm_d0[230]}), .inb({coutr1, coutr0}),
    .rnd(r[744]), .s(s[744]), .clk(clk), .out({w_m1[230], w_m0[230]}));
MSKand_opini2_d2_pini u_m_231 (
    .ina({xm_d1[231], xm_d0[231]}), .inb({coutr1, coutr0}),
    .rnd(r[745]), .s(s[745]), .clk(clk), .out({w_m1[231], w_m0[231]}));
MSKand_opini2_d2_pini u_m_232 (
    .ina({xm_d1[232], xm_d0[232]}), .inb({coutr1, coutr0}),
    .rnd(r[746]), .s(s[746]), .clk(clk), .out({w_m1[232], w_m0[232]}));
MSKand_opini2_d2_pini u_m_233 (
    .ina({xm_d1[233], xm_d0[233]}), .inb({coutr1, coutr0}),
    .rnd(r[747]), .s(s[747]), .clk(clk), .out({w_m1[233], w_m0[233]}));
MSKand_opini2_d2_pini u_m_234 (
    .ina({xm_d1[234], xm_d0[234]}), .inb({coutr1, coutr0}),
    .rnd(r[748]), .s(s[748]), .clk(clk), .out({w_m1[234], w_m0[234]}));
MSKand_opini2_d2_pini u_m_235 (
    .ina({xm_d1[235], xm_d0[235]}), .inb({coutr1, coutr0}),
    .rnd(r[749]), .s(s[749]), .clk(clk), .out({w_m1[235], w_m0[235]}));
MSKand_opini2_d2_pini u_m_236 (
    .ina({xm_d1[236], xm_d0[236]}), .inb({coutr1, coutr0}),
    .rnd(r[750]), .s(s[750]), .clk(clk), .out({w_m1[236], w_m0[236]}));
MSKand_opini2_d2_pini u_m_237 (
    .ina({xm_d1[237], xm_d0[237]}), .inb({coutr1, coutr0}),
    .rnd(r[751]), .s(s[751]), .clk(clk), .out({w_m1[237], w_m0[237]}));
MSKand_opini2_d2_pini u_m_238 (
    .ina({xm_d1[238], xm_d0[238]}), .inb({coutr1, coutr0}),
    .rnd(r[752]), .s(s[752]), .clk(clk), .out({w_m1[238], w_m0[238]}));
MSKand_opini2_d2_pini u_m_239 (
    .ina({xm_d1[239], xm_d0[239]}), .inb({coutr1, coutr0}),
    .rnd(r[753]), .s(s[753]), .clk(clk), .out({w_m1[239], w_m0[239]}));
MSKand_opini2_d2_pini u_m_240 (
    .ina({xm_d1[240], xm_d0[240]}), .inb({coutr1, coutr0}),
    .rnd(r[754]), .s(s[754]), .clk(clk), .out({w_m1[240], w_m0[240]}));
MSKand_opini2_d2_pini u_m_241 (
    .ina({xm_d1[241], xm_d0[241]}), .inb({coutr1, coutr0}),
    .rnd(r[755]), .s(s[755]), .clk(clk), .out({w_m1[241], w_m0[241]}));
MSKand_opini2_d2_pini u_m_242 (
    .ina({xm_d1[242], xm_d0[242]}), .inb({coutr1, coutr0}),
    .rnd(r[756]), .s(s[756]), .clk(clk), .out({w_m1[242], w_m0[242]}));
MSKand_opini2_d2_pini u_m_243 (
    .ina({xm_d1[243], xm_d0[243]}), .inb({coutr1, coutr0}),
    .rnd(r[757]), .s(s[757]), .clk(clk), .out({w_m1[243], w_m0[243]}));
MSKand_opini2_d2_pini u_m_244 (
    .ina({xm_d1[244], xm_d0[244]}), .inb({coutr1, coutr0}),
    .rnd(r[758]), .s(s[758]), .clk(clk), .out({w_m1[244], w_m0[244]}));
MSKand_opini2_d2_pini u_m_245 (
    .ina({xm_d1[245], xm_d0[245]}), .inb({coutr1, coutr0}),
    .rnd(r[759]), .s(s[759]), .clk(clk), .out({w_m1[245], w_m0[245]}));
MSKand_opini2_d2_pini u_m_246 (
    .ina({xm_d1[246], xm_d0[246]}), .inb({coutr1, coutr0}),
    .rnd(r[760]), .s(s[760]), .clk(clk), .out({w_m1[246], w_m0[246]}));
MSKand_opini2_d2_pini u_m_247 (
    .ina({xm_d1[247], xm_d0[247]}), .inb({coutr1, coutr0}),
    .rnd(r[761]), .s(s[761]), .clk(clk), .out({w_m1[247], w_m0[247]}));
MSKand_opini2_d2_pini u_m_248 (
    .ina({xm_d1[248], xm_d0[248]}), .inb({coutr1, coutr0}),
    .rnd(r[762]), .s(s[762]), .clk(clk), .out({w_m1[248], w_m0[248]}));
MSKand_opini2_d2_pini u_m_249 (
    .ina({xm_d1[249], xm_d0[249]}), .inb({coutr1, coutr0}),
    .rnd(r[763]), .s(s[763]), .clk(clk), .out({w_m1[249], w_m0[249]}));
MSKand_opini2_d2_pini u_m_250 (
    .ina({xm_d1[250], xm_d0[250]}), .inb({coutr1, coutr0}),
    .rnd(r[764]), .s(s[764]), .clk(clk), .out({w_m1[250], w_m0[250]}));
MSKand_opini2_d2_pini u_m_251 (
    .ina({xm_d1[251], xm_d0[251]}), .inb({coutr1, coutr0}),
    .rnd(r[765]), .s(s[765]), .clk(clk), .out({w_m1[251], w_m0[251]}));
MSKand_opini2_d2_pini u_m_252 (
    .ina({xm_d1[252], xm_d0[252]}), .inb({coutr1, coutr0}),
    .rnd(r[766]), .s(s[766]), .clk(clk), .out({w_m1[252], w_m0[252]}));
MSKand_opini2_d2_pini u_m_253 (
    .ina({xm_d1[253], xm_d0[253]}), .inb({coutr1, coutr0}),
    .rnd(r[767]), .s(s[767]), .clk(clk), .out({w_m1[253], w_m0[253]}));
MSKand_opini2_d2_pini u_m_254 (
    .ina({xm_d1[254], xm_d0[254]}), .inb({coutr1, coutr0}),
    .rnd(r[768]), .s(s[768]), .clk(clk), .out({w_m1[254], w_m0[254]}));
MSKand_opini2_d2_pini u_m_255 (
    .ina({xm_d1[255], xm_d0[255]}), .inb({coutr1, coutr0}),
    .rnd(r[769]), .s(s[769]), .clk(clk), .out({w_m1[255], w_m0[255]}));

endmodule
