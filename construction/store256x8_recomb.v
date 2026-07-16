// NEGATIVE CONTROL (must FAIL): identical to the target plus one share-
// recombining register (leak0 <= rdata[0]^rdata[1]). MATCHI must flag the
// gate sensitive in multiple shares (glitch leakage).
// Masked storage path: 8 x 256-bit two-share scratchpad, two physically-
// separate lanes (share 0: m0_*, share 1: m1_*), public addresses, registered
// per-lane read port, 2-cycle two-lane paging pipeline. No gadgets, no
// randomness — every gate touches exactly one share of one value.
// Dense sharing layout: port[2i]=share0, port[2i+1]=share1.
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module store256x8_recomb (clk, rst, we, waddr, wdata, raddr, rdata,
                  pg_go, pg_from, pg_to, leak_o);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input we;
(* matchi_type = "control" *) input [2:0] waddr;
(* matchi_type = "control" *) input [2:0] raddr;
(* matchi_type = "control" *) input pg_go;
(* matchi_type = "control" *) input [2:0] pg_from;
(* matchi_type = "control" *) input [2:0] pg_to;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [511:0] wdata;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [511:0] rdata;
(* matchi_type = "sharing", matchi_active = "out_act" *) output [1:0] leak_o;

// ---- activity: wdata is consumed exactly when we is high; outputs (and the
// scratchpad) are sensitive from the first write to the end of the trace ----
reg seen_w;
always @(posedge clk) begin
    if (rst) seen_w <= 1'b0;
    else if (we) seen_w <= 1'b1;
end
(* keep *) wire a_act   = we;
(* keep *) wire out_act = we || seen_w;

// ---- lane registers: 8 words per lane, explicit (no memory inference) ----
reg [255:0] m0_0;
reg [255:0] m0_1;
reg [255:0] m0_2;
reg [255:0] m0_3;
reg [255:0] m0_4;
reg [255:0] m0_5;
reg [255:0] m0_6;
reg [255:0] m0_7;
reg [255:0] m1_0;
reg [255:0] m1_1;
reg [255:0] m1_2;
reg [255:0] m1_3;
reg [255:0] m1_4;
reg [255:0] m1_5;
reg [255:0] m1_6;
reg [255:0] m1_7;

// ---- per-lane write decode (lane k logic sees only share-k bits) ----
wire [255:0] wd0 = {wdata[510], wdata[508], wdata[506], wdata[504], wdata[502], wdata[500], wdata[498], wdata[496], wdata[494], wdata[492], wdata[490], wdata[488], wdata[486], wdata[484], wdata[482], wdata[480], wdata[478], wdata[476], wdata[474], wdata[472], wdata[470], wdata[468], wdata[466], wdata[464], wdata[462], wdata[460], wdata[458], wdata[456], wdata[454], wdata[452], wdata[450], wdata[448], wdata[446], wdata[444], wdata[442], wdata[440], wdata[438], wdata[436], wdata[434], wdata[432], wdata[430], wdata[428], wdata[426], wdata[424], wdata[422], wdata[420], wdata[418], wdata[416], wdata[414], wdata[412], wdata[410], wdata[408], wdata[406], wdata[404], wdata[402], wdata[400], wdata[398], wdata[396], wdata[394], wdata[392], wdata[390], wdata[388], wdata[386], wdata[384], wdata[382], wdata[380], wdata[378], wdata[376], wdata[374], wdata[372], wdata[370], wdata[368], wdata[366], wdata[364], wdata[362], wdata[360], wdata[358], wdata[356], wdata[354], wdata[352], wdata[350], wdata[348], wdata[346], wdata[344], wdata[342], wdata[340], wdata[338], wdata[336], wdata[334], wdata[332], wdata[330], wdata[328], wdata[326], wdata[324], wdata[322], wdata[320], wdata[318], wdata[316], wdata[314], wdata[312], wdata[310], wdata[308], wdata[306], wdata[304], wdata[302], wdata[300], wdata[298], wdata[296], wdata[294], wdata[292], wdata[290], wdata[288], wdata[286], wdata[284], wdata[282], wdata[280], wdata[278], wdata[276], wdata[274], wdata[272], wdata[270], wdata[268], wdata[266], wdata[264], wdata[262], wdata[260], wdata[258], wdata[256], wdata[254], wdata[252], wdata[250], wdata[248], wdata[246], wdata[244], wdata[242], wdata[240], wdata[238], wdata[236], wdata[234], wdata[232], wdata[230], wdata[228], wdata[226], wdata[224], wdata[222], wdata[220], wdata[218], wdata[216], wdata[214], wdata[212], wdata[210], wdata[208], wdata[206], wdata[204], wdata[202], wdata[200], wdata[198], wdata[196], wdata[194], wdata[192], wdata[190], wdata[188], wdata[186], wdata[184], wdata[182], wdata[180], wdata[178], wdata[176], wdata[174], wdata[172], wdata[170], wdata[168], wdata[166], wdata[164], wdata[162], wdata[160], wdata[158], wdata[156], wdata[154], wdata[152], wdata[150], wdata[148], wdata[146], wdata[144], wdata[142], wdata[140], wdata[138], wdata[136], wdata[134], wdata[132], wdata[130], wdata[128], wdata[126], wdata[124], wdata[122], wdata[120], wdata[118], wdata[116], wdata[114], wdata[112], wdata[110], wdata[108], wdata[106], wdata[104], wdata[102], wdata[100], wdata[98], wdata[96], wdata[94], wdata[92], wdata[90], wdata[88], wdata[86], wdata[84], wdata[82], wdata[80], wdata[78], wdata[76], wdata[74], wdata[72], wdata[70], wdata[68], wdata[66], wdata[64], wdata[62], wdata[60], wdata[58], wdata[56], wdata[54], wdata[52], wdata[50], wdata[48], wdata[46], wdata[44], wdata[42], wdata[40], wdata[38], wdata[36], wdata[34], wdata[32], wdata[30], wdata[28], wdata[26], wdata[24], wdata[22], wdata[20], wdata[18], wdata[16], wdata[14], wdata[12], wdata[10], wdata[8], wdata[6], wdata[4], wdata[2], wdata[0]};
wire [255:0] wd1 = {wdata[511], wdata[509], wdata[507], wdata[505], wdata[503], wdata[501], wdata[499], wdata[497], wdata[495], wdata[493], wdata[491], wdata[489], wdata[487], wdata[485], wdata[483], wdata[481], wdata[479], wdata[477], wdata[475], wdata[473], wdata[471], wdata[469], wdata[467], wdata[465], wdata[463], wdata[461], wdata[459], wdata[457], wdata[455], wdata[453], wdata[451], wdata[449], wdata[447], wdata[445], wdata[443], wdata[441], wdata[439], wdata[437], wdata[435], wdata[433], wdata[431], wdata[429], wdata[427], wdata[425], wdata[423], wdata[421], wdata[419], wdata[417], wdata[415], wdata[413], wdata[411], wdata[409], wdata[407], wdata[405], wdata[403], wdata[401], wdata[399], wdata[397], wdata[395], wdata[393], wdata[391], wdata[389], wdata[387], wdata[385], wdata[383], wdata[381], wdata[379], wdata[377], wdata[375], wdata[373], wdata[371], wdata[369], wdata[367], wdata[365], wdata[363], wdata[361], wdata[359], wdata[357], wdata[355], wdata[353], wdata[351], wdata[349], wdata[347], wdata[345], wdata[343], wdata[341], wdata[339], wdata[337], wdata[335], wdata[333], wdata[331], wdata[329], wdata[327], wdata[325], wdata[323], wdata[321], wdata[319], wdata[317], wdata[315], wdata[313], wdata[311], wdata[309], wdata[307], wdata[305], wdata[303], wdata[301], wdata[299], wdata[297], wdata[295], wdata[293], wdata[291], wdata[289], wdata[287], wdata[285], wdata[283], wdata[281], wdata[279], wdata[277], wdata[275], wdata[273], wdata[271], wdata[269], wdata[267], wdata[265], wdata[263], wdata[261], wdata[259], wdata[257], wdata[255], wdata[253], wdata[251], wdata[249], wdata[247], wdata[245], wdata[243], wdata[241], wdata[239], wdata[237], wdata[235], wdata[233], wdata[231], wdata[229], wdata[227], wdata[225], wdata[223], wdata[221], wdata[219], wdata[217], wdata[215], wdata[213], wdata[211], wdata[209], wdata[207], wdata[205], wdata[203], wdata[201], wdata[199], wdata[197], wdata[195], wdata[193], wdata[191], wdata[189], wdata[187], wdata[185], wdata[183], wdata[181], wdata[179], wdata[177], wdata[175], wdata[173], wdata[171], wdata[169], wdata[167], wdata[165], wdata[163], wdata[161], wdata[159], wdata[157], wdata[155], wdata[153], wdata[151], wdata[149], wdata[147], wdata[145], wdata[143], wdata[141], wdata[139], wdata[137], wdata[135], wdata[133], wdata[131], wdata[129], wdata[127], wdata[125], wdata[123], wdata[121], wdata[119], wdata[117], wdata[115], wdata[113], wdata[111], wdata[109], wdata[107], wdata[105], wdata[103], wdata[101], wdata[99], wdata[97], wdata[95], wdata[93], wdata[91], wdata[89], wdata[87], wdata[85], wdata[83], wdata[81], wdata[79], wdata[77], wdata[75], wdata[73], wdata[71], wdata[69], wdata[67], wdata[65], wdata[63], wdata[61], wdata[59], wdata[57], wdata[55], wdata[53], wdata[51], wdata[49], wdata[47], wdata[45], wdata[43], wdata[41], wdata[39], wdata[37], wdata[35], wdata[33], wdata[31], wdata[29], wdata[27], wdata[25], wdata[23], wdata[21], wdata[19], wdata[17], wdata[15], wdata[13], wdata[11], wdata[9], wdata[7], wdata[5], wdata[3], wdata[1]};

// ---- transition-safe paging: both lane registers load at the SAME edge,
// each from its own lane's read mux; write-back one cycle later ----
reg pg_rd, pg_wr;                 // 2-cycle sequence (public control)
reg [2:0] pg_src, pg_dst;
reg [255:0] pg0, pg1;           // physically-separate paging lanes
always @(posedge clk) begin
    if (rst) begin pg_rd <= 1'b0; pg_wr <= 1'b0; end
    else begin
        pg_rd <= pg_go;
        pg_wr <= pg_rd;
        if (pg_go) begin pg_src <= pg_from; pg_dst <= pg_to; end
        if (pg_rd) begin
            pg0 <= ((pg_src == 3'd0) ? m0_0 : ((pg_src == 3'd1) ? m0_1 : ((pg_src == 3'd2) ? m0_2 : ((pg_src == 3'd3) ? m0_3 : ((pg_src == 3'd4) ? m0_4 : ((pg_src == 3'd5) ? m0_5 : ((pg_src == 3'd6) ? m0_6 : m0_7)))))));   // share 0 lane
            pg1 <= ((pg_src == 3'd0) ? m1_0 : ((pg_src == 3'd1) ? m1_1 : ((pg_src == 3'd2) ? m1_2 : ((pg_src == 3'd3) ? m1_3 : ((pg_src == 3'd4) ? m1_4 : ((pg_src == 3'd5) ? m1_5 : ((pg_src == 3'd6) ? m1_6 : m1_7)))))));   // share 1 lane — SAME edge
        end
    end
end

// ---- lane 0 writes (SSTORE + paging write-back) ----
always @(posedge clk) begin
    if (we && waddr == 3'd0) m0_0 <= wd0;
    if (we && waddr == 3'd1) m0_1 <= wd0;
    if (we && waddr == 3'd2) m0_2 <= wd0;
    if (we && waddr == 3'd3) m0_3 <= wd0;
    if (we && waddr == 3'd4) m0_4 <= wd0;
    if (we && waddr == 3'd5) m0_5 <= wd0;
    if (we && waddr == 3'd6) m0_6 <= wd0;
    if (we && waddr == 3'd7) m0_7 <= wd0;
    if (pg_wr && pg_dst == 3'd0) m0_0 <= pg0;
    if (pg_wr && pg_dst == 3'd1) m0_1 <= pg0;
    if (pg_wr && pg_dst == 3'd2) m0_2 <= pg0;
    if (pg_wr && pg_dst == 3'd3) m0_3 <= pg0;
    if (pg_wr && pg_dst == 3'd4) m0_4 <= pg0;
    if (pg_wr && pg_dst == 3'd5) m0_5 <= pg0;
    if (pg_wr && pg_dst == 3'd6) m0_6 <= pg0;
    if (pg_wr && pg_dst == 3'd7) m0_7 <= pg0;
end
always @(posedge clk) begin
    if (we && waddr == 3'd0) m1_0 <= wd1;
    if (we && waddr == 3'd1) m1_1 <= wd1;
    if (we && waddr == 3'd2) m1_2 <= wd1;
    if (we && waddr == 3'd3) m1_3 <= wd1;
    if (we && waddr == 3'd4) m1_4 <= wd1;
    if (we && waddr == 3'd5) m1_5 <= wd1;
    if (we && waddr == 3'd6) m1_6 <= wd1;
    if (we && waddr == 3'd7) m1_7 <= wd1;
    if (pg_wr && pg_dst == 3'd0) m1_0 <= pg1;
    if (pg_wr && pg_dst == 3'd1) m1_1 <= pg1;
    if (pg_wr && pg_dst == 3'd2) m1_2 <= pg1;
    if (pg_wr && pg_dst == 3'd3) m1_3 <= pg1;
    if (pg_wr && pg_dst == 3'd4) m1_4 <= pg1;
    if (pg_wr && pg_dst == 3'd5) m1_5 <= pg1;
    if (pg_wr && pg_dst == 3'd6) m1_6 <= pg1;
    if (pg_wr && pg_dst == 3'd7) m1_7 <= pg1;
end

// ---- registered per-lane read port (SLOAD); transitions stay in-lane ----
reg [255:0] rreg0, rreg1;
always @(posedge clk) begin
    rreg0 <= ((raddr == 3'd0) ? m0_0 : ((raddr == 3'd1) ? m0_1 : ((raddr == 3'd2) ? m0_2 : ((raddr == 3'd3) ? m0_3 : ((raddr == 3'd4) ? m0_4 : ((raddr == 3'd5) ? m0_5 : ((raddr == 3'd6) ? m0_6 : m0_7)))))));
    rreg1 <= ((raddr == 3'd0) ? m1_0 : ((raddr == 3'd1) ? m1_1 : ((raddr == 3'd2) ? m1_2 : ((raddr == 3'd3) ? m1_3 : ((raddr == 3'd4) ? m1_4 : ((raddr == 3'd5) ? m1_5 : ((raddr == 3'd6) ? m1_6 : m1_7)))))));
end
assign rdata[0] = rreg0[0];  assign rdata[1] = rreg1[0];
assign rdata[2] = rreg0[1];  assign rdata[3] = rreg1[1];
assign rdata[4] = rreg0[2];  assign rdata[5] = rreg1[2];
assign rdata[6] = rreg0[3];  assign rdata[7] = rreg1[3];
assign rdata[8] = rreg0[4];  assign rdata[9] = rreg1[4];
assign rdata[10] = rreg0[5];  assign rdata[11] = rreg1[5];
assign rdata[12] = rreg0[6];  assign rdata[13] = rreg1[6];
assign rdata[14] = rreg0[7];  assign rdata[15] = rreg1[7];
assign rdata[16] = rreg0[8];  assign rdata[17] = rreg1[8];
assign rdata[18] = rreg0[9];  assign rdata[19] = rreg1[9];
assign rdata[20] = rreg0[10];  assign rdata[21] = rreg1[10];
assign rdata[22] = rreg0[11];  assign rdata[23] = rreg1[11];
assign rdata[24] = rreg0[12];  assign rdata[25] = rreg1[12];
assign rdata[26] = rreg0[13];  assign rdata[27] = rreg1[13];
assign rdata[28] = rreg0[14];  assign rdata[29] = rreg1[14];
assign rdata[30] = rreg0[15];  assign rdata[31] = rreg1[15];
assign rdata[32] = rreg0[16];  assign rdata[33] = rreg1[16];
assign rdata[34] = rreg0[17];  assign rdata[35] = rreg1[17];
assign rdata[36] = rreg0[18];  assign rdata[37] = rreg1[18];
assign rdata[38] = rreg0[19];  assign rdata[39] = rreg1[19];
assign rdata[40] = rreg0[20];  assign rdata[41] = rreg1[20];
assign rdata[42] = rreg0[21];  assign rdata[43] = rreg1[21];
assign rdata[44] = rreg0[22];  assign rdata[45] = rreg1[22];
assign rdata[46] = rreg0[23];  assign rdata[47] = rreg1[23];
assign rdata[48] = rreg0[24];  assign rdata[49] = rreg1[24];
assign rdata[50] = rreg0[25];  assign rdata[51] = rreg1[25];
assign rdata[52] = rreg0[26];  assign rdata[53] = rreg1[26];
assign rdata[54] = rreg0[27];  assign rdata[55] = rreg1[27];
assign rdata[56] = rreg0[28];  assign rdata[57] = rreg1[28];
assign rdata[58] = rreg0[29];  assign rdata[59] = rreg1[29];
assign rdata[60] = rreg0[30];  assign rdata[61] = rreg1[30];
assign rdata[62] = rreg0[31];  assign rdata[63] = rreg1[31];
assign rdata[64] = rreg0[32];  assign rdata[65] = rreg1[32];
assign rdata[66] = rreg0[33];  assign rdata[67] = rreg1[33];
assign rdata[68] = rreg0[34];  assign rdata[69] = rreg1[34];
assign rdata[70] = rreg0[35];  assign rdata[71] = rreg1[35];
assign rdata[72] = rreg0[36];  assign rdata[73] = rreg1[36];
assign rdata[74] = rreg0[37];  assign rdata[75] = rreg1[37];
assign rdata[76] = rreg0[38];  assign rdata[77] = rreg1[38];
assign rdata[78] = rreg0[39];  assign rdata[79] = rreg1[39];
assign rdata[80] = rreg0[40];  assign rdata[81] = rreg1[40];
assign rdata[82] = rreg0[41];  assign rdata[83] = rreg1[41];
assign rdata[84] = rreg0[42];  assign rdata[85] = rreg1[42];
assign rdata[86] = rreg0[43];  assign rdata[87] = rreg1[43];
assign rdata[88] = rreg0[44];  assign rdata[89] = rreg1[44];
assign rdata[90] = rreg0[45];  assign rdata[91] = rreg1[45];
assign rdata[92] = rreg0[46];  assign rdata[93] = rreg1[46];
assign rdata[94] = rreg0[47];  assign rdata[95] = rreg1[47];
assign rdata[96] = rreg0[48];  assign rdata[97] = rreg1[48];
assign rdata[98] = rreg0[49];  assign rdata[99] = rreg1[49];
assign rdata[100] = rreg0[50];  assign rdata[101] = rreg1[50];
assign rdata[102] = rreg0[51];  assign rdata[103] = rreg1[51];
assign rdata[104] = rreg0[52];  assign rdata[105] = rreg1[52];
assign rdata[106] = rreg0[53];  assign rdata[107] = rreg1[53];
assign rdata[108] = rreg0[54];  assign rdata[109] = rreg1[54];
assign rdata[110] = rreg0[55];  assign rdata[111] = rreg1[55];
assign rdata[112] = rreg0[56];  assign rdata[113] = rreg1[56];
assign rdata[114] = rreg0[57];  assign rdata[115] = rreg1[57];
assign rdata[116] = rreg0[58];  assign rdata[117] = rreg1[58];
assign rdata[118] = rreg0[59];  assign rdata[119] = rreg1[59];
assign rdata[120] = rreg0[60];  assign rdata[121] = rreg1[60];
assign rdata[122] = rreg0[61];  assign rdata[123] = rreg1[61];
assign rdata[124] = rreg0[62];  assign rdata[125] = rreg1[62];
assign rdata[126] = rreg0[63];  assign rdata[127] = rreg1[63];
assign rdata[128] = rreg0[64];  assign rdata[129] = rreg1[64];
assign rdata[130] = rreg0[65];  assign rdata[131] = rreg1[65];
assign rdata[132] = rreg0[66];  assign rdata[133] = rreg1[66];
assign rdata[134] = rreg0[67];  assign rdata[135] = rreg1[67];
assign rdata[136] = rreg0[68];  assign rdata[137] = rreg1[68];
assign rdata[138] = rreg0[69];  assign rdata[139] = rreg1[69];
assign rdata[140] = rreg0[70];  assign rdata[141] = rreg1[70];
assign rdata[142] = rreg0[71];  assign rdata[143] = rreg1[71];
assign rdata[144] = rreg0[72];  assign rdata[145] = rreg1[72];
assign rdata[146] = rreg0[73];  assign rdata[147] = rreg1[73];
assign rdata[148] = rreg0[74];  assign rdata[149] = rreg1[74];
assign rdata[150] = rreg0[75];  assign rdata[151] = rreg1[75];
assign rdata[152] = rreg0[76];  assign rdata[153] = rreg1[76];
assign rdata[154] = rreg0[77];  assign rdata[155] = rreg1[77];
assign rdata[156] = rreg0[78];  assign rdata[157] = rreg1[78];
assign rdata[158] = rreg0[79];  assign rdata[159] = rreg1[79];
assign rdata[160] = rreg0[80];  assign rdata[161] = rreg1[80];
assign rdata[162] = rreg0[81];  assign rdata[163] = rreg1[81];
assign rdata[164] = rreg0[82];  assign rdata[165] = rreg1[82];
assign rdata[166] = rreg0[83];  assign rdata[167] = rreg1[83];
assign rdata[168] = rreg0[84];  assign rdata[169] = rreg1[84];
assign rdata[170] = rreg0[85];  assign rdata[171] = rreg1[85];
assign rdata[172] = rreg0[86];  assign rdata[173] = rreg1[86];
assign rdata[174] = rreg0[87];  assign rdata[175] = rreg1[87];
assign rdata[176] = rreg0[88];  assign rdata[177] = rreg1[88];
assign rdata[178] = rreg0[89];  assign rdata[179] = rreg1[89];
assign rdata[180] = rreg0[90];  assign rdata[181] = rreg1[90];
assign rdata[182] = rreg0[91];  assign rdata[183] = rreg1[91];
assign rdata[184] = rreg0[92];  assign rdata[185] = rreg1[92];
assign rdata[186] = rreg0[93];  assign rdata[187] = rreg1[93];
assign rdata[188] = rreg0[94];  assign rdata[189] = rreg1[94];
assign rdata[190] = rreg0[95];  assign rdata[191] = rreg1[95];
assign rdata[192] = rreg0[96];  assign rdata[193] = rreg1[96];
assign rdata[194] = rreg0[97];  assign rdata[195] = rreg1[97];
assign rdata[196] = rreg0[98];  assign rdata[197] = rreg1[98];
assign rdata[198] = rreg0[99];  assign rdata[199] = rreg1[99];
assign rdata[200] = rreg0[100];  assign rdata[201] = rreg1[100];
assign rdata[202] = rreg0[101];  assign rdata[203] = rreg1[101];
assign rdata[204] = rreg0[102];  assign rdata[205] = rreg1[102];
assign rdata[206] = rreg0[103];  assign rdata[207] = rreg1[103];
assign rdata[208] = rreg0[104];  assign rdata[209] = rreg1[104];
assign rdata[210] = rreg0[105];  assign rdata[211] = rreg1[105];
assign rdata[212] = rreg0[106];  assign rdata[213] = rreg1[106];
assign rdata[214] = rreg0[107];  assign rdata[215] = rreg1[107];
assign rdata[216] = rreg0[108];  assign rdata[217] = rreg1[108];
assign rdata[218] = rreg0[109];  assign rdata[219] = rreg1[109];
assign rdata[220] = rreg0[110];  assign rdata[221] = rreg1[110];
assign rdata[222] = rreg0[111];  assign rdata[223] = rreg1[111];
assign rdata[224] = rreg0[112];  assign rdata[225] = rreg1[112];
assign rdata[226] = rreg0[113];  assign rdata[227] = rreg1[113];
assign rdata[228] = rreg0[114];  assign rdata[229] = rreg1[114];
assign rdata[230] = rreg0[115];  assign rdata[231] = rreg1[115];
assign rdata[232] = rreg0[116];  assign rdata[233] = rreg1[116];
assign rdata[234] = rreg0[117];  assign rdata[235] = rreg1[117];
assign rdata[236] = rreg0[118];  assign rdata[237] = rreg1[118];
assign rdata[238] = rreg0[119];  assign rdata[239] = rreg1[119];
assign rdata[240] = rreg0[120];  assign rdata[241] = rreg1[120];
assign rdata[242] = rreg0[121];  assign rdata[243] = rreg1[121];
assign rdata[244] = rreg0[122];  assign rdata[245] = rreg1[122];
assign rdata[246] = rreg0[123];  assign rdata[247] = rreg1[123];
assign rdata[248] = rreg0[124];  assign rdata[249] = rreg1[124];
assign rdata[250] = rreg0[125];  assign rdata[251] = rreg1[125];
assign rdata[252] = rreg0[126];  assign rdata[253] = rreg1[126];
assign rdata[254] = rreg0[127];  assign rdata[255] = rreg1[127];
assign rdata[256] = rreg0[128];  assign rdata[257] = rreg1[128];
assign rdata[258] = rreg0[129];  assign rdata[259] = rreg1[129];
assign rdata[260] = rreg0[130];  assign rdata[261] = rreg1[130];
assign rdata[262] = rreg0[131];  assign rdata[263] = rreg1[131];
assign rdata[264] = rreg0[132];  assign rdata[265] = rreg1[132];
assign rdata[266] = rreg0[133];  assign rdata[267] = rreg1[133];
assign rdata[268] = rreg0[134];  assign rdata[269] = rreg1[134];
assign rdata[270] = rreg0[135];  assign rdata[271] = rreg1[135];
assign rdata[272] = rreg0[136];  assign rdata[273] = rreg1[136];
assign rdata[274] = rreg0[137];  assign rdata[275] = rreg1[137];
assign rdata[276] = rreg0[138];  assign rdata[277] = rreg1[138];
assign rdata[278] = rreg0[139];  assign rdata[279] = rreg1[139];
assign rdata[280] = rreg0[140];  assign rdata[281] = rreg1[140];
assign rdata[282] = rreg0[141];  assign rdata[283] = rreg1[141];
assign rdata[284] = rreg0[142];  assign rdata[285] = rreg1[142];
assign rdata[286] = rreg0[143];  assign rdata[287] = rreg1[143];
assign rdata[288] = rreg0[144];  assign rdata[289] = rreg1[144];
assign rdata[290] = rreg0[145];  assign rdata[291] = rreg1[145];
assign rdata[292] = rreg0[146];  assign rdata[293] = rreg1[146];
assign rdata[294] = rreg0[147];  assign rdata[295] = rreg1[147];
assign rdata[296] = rreg0[148];  assign rdata[297] = rreg1[148];
assign rdata[298] = rreg0[149];  assign rdata[299] = rreg1[149];
assign rdata[300] = rreg0[150];  assign rdata[301] = rreg1[150];
assign rdata[302] = rreg0[151];  assign rdata[303] = rreg1[151];
assign rdata[304] = rreg0[152];  assign rdata[305] = rreg1[152];
assign rdata[306] = rreg0[153];  assign rdata[307] = rreg1[153];
assign rdata[308] = rreg0[154];  assign rdata[309] = rreg1[154];
assign rdata[310] = rreg0[155];  assign rdata[311] = rreg1[155];
assign rdata[312] = rreg0[156];  assign rdata[313] = rreg1[156];
assign rdata[314] = rreg0[157];  assign rdata[315] = rreg1[157];
assign rdata[316] = rreg0[158];  assign rdata[317] = rreg1[158];
assign rdata[318] = rreg0[159];  assign rdata[319] = rreg1[159];
assign rdata[320] = rreg0[160];  assign rdata[321] = rreg1[160];
assign rdata[322] = rreg0[161];  assign rdata[323] = rreg1[161];
assign rdata[324] = rreg0[162];  assign rdata[325] = rreg1[162];
assign rdata[326] = rreg0[163];  assign rdata[327] = rreg1[163];
assign rdata[328] = rreg0[164];  assign rdata[329] = rreg1[164];
assign rdata[330] = rreg0[165];  assign rdata[331] = rreg1[165];
assign rdata[332] = rreg0[166];  assign rdata[333] = rreg1[166];
assign rdata[334] = rreg0[167];  assign rdata[335] = rreg1[167];
assign rdata[336] = rreg0[168];  assign rdata[337] = rreg1[168];
assign rdata[338] = rreg0[169];  assign rdata[339] = rreg1[169];
assign rdata[340] = rreg0[170];  assign rdata[341] = rreg1[170];
assign rdata[342] = rreg0[171];  assign rdata[343] = rreg1[171];
assign rdata[344] = rreg0[172];  assign rdata[345] = rreg1[172];
assign rdata[346] = rreg0[173];  assign rdata[347] = rreg1[173];
assign rdata[348] = rreg0[174];  assign rdata[349] = rreg1[174];
assign rdata[350] = rreg0[175];  assign rdata[351] = rreg1[175];
assign rdata[352] = rreg0[176];  assign rdata[353] = rreg1[176];
assign rdata[354] = rreg0[177];  assign rdata[355] = rreg1[177];
assign rdata[356] = rreg0[178];  assign rdata[357] = rreg1[178];
assign rdata[358] = rreg0[179];  assign rdata[359] = rreg1[179];
assign rdata[360] = rreg0[180];  assign rdata[361] = rreg1[180];
assign rdata[362] = rreg0[181];  assign rdata[363] = rreg1[181];
assign rdata[364] = rreg0[182];  assign rdata[365] = rreg1[182];
assign rdata[366] = rreg0[183];  assign rdata[367] = rreg1[183];
assign rdata[368] = rreg0[184];  assign rdata[369] = rreg1[184];
assign rdata[370] = rreg0[185];  assign rdata[371] = rreg1[185];
assign rdata[372] = rreg0[186];  assign rdata[373] = rreg1[186];
assign rdata[374] = rreg0[187];  assign rdata[375] = rreg1[187];
assign rdata[376] = rreg0[188];  assign rdata[377] = rreg1[188];
assign rdata[378] = rreg0[189];  assign rdata[379] = rreg1[189];
assign rdata[380] = rreg0[190];  assign rdata[381] = rreg1[190];
assign rdata[382] = rreg0[191];  assign rdata[383] = rreg1[191];
assign rdata[384] = rreg0[192];  assign rdata[385] = rreg1[192];
assign rdata[386] = rreg0[193];  assign rdata[387] = rreg1[193];
assign rdata[388] = rreg0[194];  assign rdata[389] = rreg1[194];
assign rdata[390] = rreg0[195];  assign rdata[391] = rreg1[195];
assign rdata[392] = rreg0[196];  assign rdata[393] = rreg1[196];
assign rdata[394] = rreg0[197];  assign rdata[395] = rreg1[197];
assign rdata[396] = rreg0[198];  assign rdata[397] = rreg1[198];
assign rdata[398] = rreg0[199];  assign rdata[399] = rreg1[199];
assign rdata[400] = rreg0[200];  assign rdata[401] = rreg1[200];
assign rdata[402] = rreg0[201];  assign rdata[403] = rreg1[201];
assign rdata[404] = rreg0[202];  assign rdata[405] = rreg1[202];
assign rdata[406] = rreg0[203];  assign rdata[407] = rreg1[203];
assign rdata[408] = rreg0[204];  assign rdata[409] = rreg1[204];
assign rdata[410] = rreg0[205];  assign rdata[411] = rreg1[205];
assign rdata[412] = rreg0[206];  assign rdata[413] = rreg1[206];
assign rdata[414] = rreg0[207];  assign rdata[415] = rreg1[207];
assign rdata[416] = rreg0[208];  assign rdata[417] = rreg1[208];
assign rdata[418] = rreg0[209];  assign rdata[419] = rreg1[209];
assign rdata[420] = rreg0[210];  assign rdata[421] = rreg1[210];
assign rdata[422] = rreg0[211];  assign rdata[423] = rreg1[211];
assign rdata[424] = rreg0[212];  assign rdata[425] = rreg1[212];
assign rdata[426] = rreg0[213];  assign rdata[427] = rreg1[213];
assign rdata[428] = rreg0[214];  assign rdata[429] = rreg1[214];
assign rdata[430] = rreg0[215];  assign rdata[431] = rreg1[215];
assign rdata[432] = rreg0[216];  assign rdata[433] = rreg1[216];
assign rdata[434] = rreg0[217];  assign rdata[435] = rreg1[217];
assign rdata[436] = rreg0[218];  assign rdata[437] = rreg1[218];
assign rdata[438] = rreg0[219];  assign rdata[439] = rreg1[219];
assign rdata[440] = rreg0[220];  assign rdata[441] = rreg1[220];
assign rdata[442] = rreg0[221];  assign rdata[443] = rreg1[221];
assign rdata[444] = rreg0[222];  assign rdata[445] = rreg1[222];
assign rdata[446] = rreg0[223];  assign rdata[447] = rreg1[223];
assign rdata[448] = rreg0[224];  assign rdata[449] = rreg1[224];
assign rdata[450] = rreg0[225];  assign rdata[451] = rreg1[225];
assign rdata[452] = rreg0[226];  assign rdata[453] = rreg1[226];
assign rdata[454] = rreg0[227];  assign rdata[455] = rreg1[227];
assign rdata[456] = rreg0[228];  assign rdata[457] = rreg1[228];
assign rdata[458] = rreg0[229];  assign rdata[459] = rreg1[229];
assign rdata[460] = rreg0[230];  assign rdata[461] = rreg1[230];
assign rdata[462] = rreg0[231];  assign rdata[463] = rreg1[231];
assign rdata[464] = rreg0[232];  assign rdata[465] = rreg1[232];
assign rdata[466] = rreg0[233];  assign rdata[467] = rreg1[233];
assign rdata[468] = rreg0[234];  assign rdata[469] = rreg1[234];
assign rdata[470] = rreg0[235];  assign rdata[471] = rreg1[235];
assign rdata[472] = rreg0[236];  assign rdata[473] = rreg1[236];
assign rdata[474] = rreg0[237];  assign rdata[475] = rreg1[237];
assign rdata[476] = rreg0[238];  assign rdata[477] = rreg1[238];
assign rdata[478] = rreg0[239];  assign rdata[479] = rreg1[239];
assign rdata[480] = rreg0[240];  assign rdata[481] = rreg1[240];
assign rdata[482] = rreg0[241];  assign rdata[483] = rreg1[241];
assign rdata[484] = rreg0[242];  assign rdata[485] = rreg1[242];
assign rdata[486] = rreg0[243];  assign rdata[487] = rreg1[243];
assign rdata[488] = rreg0[244];  assign rdata[489] = rreg1[244];
assign rdata[490] = rreg0[245];  assign rdata[491] = rreg1[245];
assign rdata[492] = rreg0[246];  assign rdata[493] = rreg1[246];
assign rdata[494] = rreg0[247];  assign rdata[495] = rreg1[247];
assign rdata[496] = rreg0[248];  assign rdata[497] = rreg1[248];
assign rdata[498] = rreg0[249];  assign rdata[499] = rreg1[249];
assign rdata[500] = rreg0[250];  assign rdata[501] = rreg1[250];
assign rdata[502] = rreg0[251];  assign rdata[503] = rreg1[251];
assign rdata[504] = rreg0[252];  assign rdata[505] = rreg1[252];
assign rdata[506] = rreg0[253];  assign rdata[507] = rreg1[253];
assign rdata[508] = rreg0[254];  assign rdata[509] = rreg1[254];
assign rdata[510] = rreg0[255];  assign rdata[511] = rreg1[255];

// BUG UNDER TEST: recombine the two shares of rdata bit 0. leak0 holds
// rdata[0]^rdata[1] (both shares) -> the XOR gate is sensitive in ShareSet{0}
// AND ShareSet{1} -> MATCHI glitch leakage. Driven onto share 0 of leak_o.
(* keep = "yes" *) reg leak0, leak1;
always @(posedge clk) begin
    leak0 <= rdata[0] ^ rdata[1];
    leak1 <= 1'b0;
end
assign leak_o = {leak1, leak0};

endmodule
