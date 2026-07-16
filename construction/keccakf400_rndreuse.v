// NEGATIVE CONTROL (must FAIL): identical to the target except u_chi_1
// consumes the SAME random bits as u_chi_0, active in the same cycles,
// instead of its dedicated pair. MATCHI must report multi-use.
// Masked Keccak-f[400] (20 rounds, w=16): one masked round unit — chi via
// 400 assumed-OPINI gadget leaves u_chi_* (one per state bit, DEDICATED
// r[k]/s[k] each), theta/rho/pi/iota strictly share-local — iterated in place
// by a public FSM. Dense sharing layout: port[2i]=share0, port[2i+1]=share1,
// state flat index w*(5y+x)+z (Keccak spec ordering).
// Schedule: load @0; round i occupies cycles [1+6i, 6+6i]; o (register)
// stable from cycle 121; state cleared (share-local, to public 0) at
// cycle 132; randoms fresh [0,634].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module keccakf400_rndreuse (clk, rst, go, a, r, s, o);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [799:0] a;
(* matchi_type = "random", matchi_active = "r_act" *) input [399:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [399:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [799:0] o;

// ---- activity windows from an idempotent cycle counter (public control;
// counts 1.. from the go pulse, saturates — the div256 pattern) ----
reg [10:0] cnt;
always @(posedge clk) begin
    if (rst)                       cnt <= 11'd0;
    else if (go)                   cnt <= 11'd1;
    else if (cnt != 11'd0 && cnt != 11'd637) cnt <= cnt + 11'd1;
end
(* keep *) wire a_act   = go || (cnt == 11'd1);   // operand consumed at load
(* keep *) wire r_act   = go || (cnt >= 11'd1 && cnt <= 11'd634);
(* keep *) wire s_act   =       (cnt >= 11'd1 && cnt <= 11'd635);
(* keep *) wire out_act = go || (cnt >= 11'd1 && cnt <= 11'd632);
(* keep *) wire clr     = (cnt == 11'd132);  // bounded sensitivity

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
            if (rnd_i == 5'd19) begin running <= 1'b0; rnd_i <= 0; end
            else rnd_i <= rnd_i + 5'd1;
        end else ph <= ph + 3'd1;
    end
end

// ---- iota round constant (public, XORed into share 0 of lane (0,0)) ----
wire [15:0] rc_cur = (rnd_i == 5'd0) ? 16'h0001 :
               (rnd_i == 5'd1) ? 16'h8082 :
               (rnd_i == 5'd2) ? 16'h808a :
               (rnd_i == 5'd3) ? 16'h8000 :
               (rnd_i == 5'd4) ? 16'h808b :
               (rnd_i == 5'd5) ? 16'h0001 :
               (rnd_i == 5'd6) ? 16'h8081 :
               (rnd_i == 5'd7) ? 16'h8009 :
               (rnd_i == 5'd8) ? 16'h008a :
               (rnd_i == 5'd9) ? 16'h0088 :
               (rnd_i == 5'd10) ? 16'h8009 :
               (rnd_i == 5'd11) ? 16'h000a :
               (rnd_i == 5'd12) ? 16'h808b :
               (rnd_i == 5'd13) ? 16'h008b :
               (rnd_i == 5'd14) ? 16'h8089 :
               (rnd_i == 5'd15) ? 16'h8003 :
               (rnd_i == 5'd16) ? 16'h8002 :
               (rnd_i == 5'd17) ? 16'h0080 :
               (rnd_i == 5'd18) ? 16'h800a :
               (rnd_i == 5'd19) ? 16'h000a :
               16'd0;

// ---- state registers (per-share; NEVER mix share 0 and share 1) ----
reg [399:0] St0, St1;
wire [399:0] Bx0, Bx1;         // after theta+rho+pi (share-local wiring)
wire [399:0] w_chi0, w_chi1;   // chi gadget outputs

always @(posedge clk) begin
    if (rst || clr) begin
        St0 <= 0; St1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        St0 <= {a[798], a[796], a[794], a[792], a[790], a[788], a[786], a[784], a[782], a[780], a[778], a[776], a[774], a[772], a[770], a[768], a[766], a[764], a[762], a[760], a[758], a[756], a[754], a[752], a[750], a[748], a[746], a[744], a[742], a[740], a[738], a[736], a[734], a[732], a[730], a[728], a[726], a[724], a[722], a[720], a[718], a[716], a[714], a[712], a[710], a[708], a[706], a[704], a[702], a[700], a[698], a[696], a[694], a[692], a[690], a[688], a[686], a[684], a[682], a[680], a[678], a[676], a[674], a[672], a[670], a[668], a[666], a[664], a[662], a[660], a[658], a[656], a[654], a[652], a[650], a[648], a[646], a[644], a[642], a[640], a[638], a[636], a[634], a[632], a[630], a[628], a[626], a[624], a[622], a[620], a[618], a[616], a[614], a[612], a[610], a[608], a[606], a[604], a[602], a[600], a[598], a[596], a[594], a[592], a[590], a[588], a[586], a[584], a[582], a[580], a[578], a[576], a[574], a[572], a[570], a[568], a[566], a[564], a[562], a[560], a[558], a[556], a[554], a[552], a[550], a[548], a[546], a[544], a[542], a[540], a[538], a[536], a[534], a[532], a[530], a[528], a[526], a[524], a[522], a[520], a[518], a[516], a[514], a[512], a[510], a[508], a[506], a[504], a[502], a[500], a[498], a[496], a[494], a[492], a[490], a[488], a[486], a[484], a[482], a[480], a[478], a[476], a[474], a[472], a[470], a[468], a[466], a[464], a[462], a[460], a[458], a[456], a[454], a[452], a[450], a[448], a[446], a[444], a[442], a[440], a[438], a[436], a[434], a[432], a[430], a[428], a[426], a[424], a[422], a[420], a[418], a[416], a[414], a[412], a[410], a[408], a[406], a[404], a[402], a[400], a[398], a[396], a[394], a[392], a[390], a[388], a[386], a[384], a[382], a[380], a[378], a[376], a[374], a[372], a[370], a[368], a[366], a[364], a[362], a[360], a[358], a[356], a[354], a[352], a[350], a[348], a[346], a[344], a[342], a[340], a[338], a[336], a[334], a[332], a[330], a[328], a[326], a[324], a[322], a[320], a[318], a[316], a[314], a[312], a[310], a[308], a[306], a[304], a[302], a[300], a[298], a[296], a[294], a[292], a[290], a[288], a[286], a[284], a[282], a[280], a[278], a[276], a[274], a[272], a[270], a[268], a[266], a[264], a[262], a[260], a[258], a[256], a[254], a[252], a[250], a[248], a[246], a[244], a[242], a[240], a[238], a[236], a[234], a[232], a[230], a[228], a[226], a[224], a[222], a[220], a[218], a[216], a[214], a[212], a[210], a[208], a[206], a[204], a[202], a[200], a[198], a[196], a[194], a[192], a[190], a[188], a[186], a[184], a[182], a[180], a[178], a[176], a[174], a[172], a[170], a[168], a[166], a[164], a[162], a[160], a[158], a[156], a[154], a[152], a[150], a[148], a[146], a[144], a[142], a[140], a[138], a[136], a[134], a[132], a[130], a[128], a[126], a[124], a[122], a[120], a[118], a[116], a[114], a[112], a[110], a[108], a[106], a[104], a[102], a[100], a[98], a[96], a[94], a[92], a[90], a[88], a[86], a[84], a[82], a[80], a[78], a[76], a[74], a[72], a[70], a[68], a[66], a[64], a[62], a[60], a[58], a[56], a[54], a[52], a[50], a[48], a[46], a[44], a[42], a[40], a[38], a[36], a[34], a[32], a[30], a[28], a[26], a[24], a[22], a[20], a[18], a[16], a[14], a[12], a[10], a[8], a[6], a[4], a[2], a[0]};
        St1 <= {a[799], a[797], a[795], a[793], a[791], a[789], a[787], a[785], a[783], a[781], a[779], a[777], a[775], a[773], a[771], a[769], a[767], a[765], a[763], a[761], a[759], a[757], a[755], a[753], a[751], a[749], a[747], a[745], a[743], a[741], a[739], a[737], a[735], a[733], a[731], a[729], a[727], a[725], a[723], a[721], a[719], a[717], a[715], a[713], a[711], a[709], a[707], a[705], a[703], a[701], a[699], a[697], a[695], a[693], a[691], a[689], a[687], a[685], a[683], a[681], a[679], a[677], a[675], a[673], a[671], a[669], a[667], a[665], a[663], a[661], a[659], a[657], a[655], a[653], a[651], a[649], a[647], a[645], a[643], a[641], a[639], a[637], a[635], a[633], a[631], a[629], a[627], a[625], a[623], a[621], a[619], a[617], a[615], a[613], a[611], a[609], a[607], a[605], a[603], a[601], a[599], a[597], a[595], a[593], a[591], a[589], a[587], a[585], a[583], a[581], a[579], a[577], a[575], a[573], a[571], a[569], a[567], a[565], a[563], a[561], a[559], a[557], a[555], a[553], a[551], a[549], a[547], a[545], a[543], a[541], a[539], a[537], a[535], a[533], a[531], a[529], a[527], a[525], a[523], a[521], a[519], a[517], a[515], a[513], a[511], a[509], a[507], a[505], a[503], a[501], a[499], a[497], a[495], a[493], a[491], a[489], a[487], a[485], a[483], a[481], a[479], a[477], a[475], a[473], a[471], a[469], a[467], a[465], a[463], a[461], a[459], a[457], a[455], a[453], a[451], a[449], a[447], a[445], a[443], a[441], a[439], a[437], a[435], a[433], a[431], a[429], a[427], a[425], a[423], a[421], a[419], a[417], a[415], a[413], a[411], a[409], a[407], a[405], a[403], a[401], a[399], a[397], a[395], a[393], a[391], a[389], a[387], a[385], a[383], a[381], a[379], a[377], a[375], a[373], a[371], a[369], a[367], a[365], a[363], a[361], a[359], a[357], a[355], a[353], a[351], a[349], a[347], a[345], a[343], a[341], a[339], a[337], a[335], a[333], a[331], a[329], a[327], a[325], a[323], a[321], a[319], a[317], a[315], a[313], a[311], a[309], a[307], a[305], a[303], a[301], a[299], a[297], a[295], a[293], a[291], a[289], a[287], a[285], a[283], a[281], a[279], a[277], a[275], a[273], a[271], a[269], a[267], a[265], a[263], a[261], a[259], a[257], a[255], a[253], a[251], a[249], a[247], a[245], a[243], a[241], a[239], a[237], a[235], a[233], a[231], a[229], a[227], a[225], a[223], a[221], a[219], a[217], a[215], a[213], a[211], a[209], a[207], a[205], a[203], a[201], a[199], a[197], a[195], a[193], a[191], a[189], a[187], a[185], a[183], a[181], a[179], a[177], a[175], a[173], a[171], a[169], a[167], a[165], a[163], a[161], a[159], a[157], a[155], a[153], a[151], a[149], a[147], a[145], a[143], a[141], a[139], a[137], a[135], a[133], a[131], a[129], a[127], a[125], a[123], a[121], a[119], a[117], a[115], a[113], a[111], a[109], a[107], a[105], a[103], a[101], a[99], a[97], a[95], a[93], a[91], a[89], a[87], a[85], a[83], a[81], a[79], a[77], a[75], a[73], a[71], a[69], a[67], a[65], a[63], a[61], a[59], a[57], a[55], a[53], a[51], a[49], a[47], a[45], a[43], a[41], a[39], a[37], a[35], a[33], a[31], a[29], a[27], a[25], a[23], a[21], a[19], a[17], a[15], a[13], a[11], a[9], a[7], a[5], a[3], a[1]};
    end else if (running && ph == 5) begin
        // chi outer XOR + iota, all share-local (iota into share 0 only)
        St0 <= Bx0 ^ w_chi0 ^ {{384{1'b0}}, rc_cur};
        St1 <= Bx1 ^ w_chi1;
    end
end

// ---- theta (share-local XOR network) ----

wire [79:0] C0, D0;
assign C0[0] = St0[0] ^ St0[80] ^ St0[160] ^ St0[240] ^ St0[320];
assign C0[1] = St0[1] ^ St0[81] ^ St0[161] ^ St0[241] ^ St0[321];
assign C0[2] = St0[2] ^ St0[82] ^ St0[162] ^ St0[242] ^ St0[322];
assign C0[3] = St0[3] ^ St0[83] ^ St0[163] ^ St0[243] ^ St0[323];
assign C0[4] = St0[4] ^ St0[84] ^ St0[164] ^ St0[244] ^ St0[324];
assign C0[5] = St0[5] ^ St0[85] ^ St0[165] ^ St0[245] ^ St0[325];
assign C0[6] = St0[6] ^ St0[86] ^ St0[166] ^ St0[246] ^ St0[326];
assign C0[7] = St0[7] ^ St0[87] ^ St0[167] ^ St0[247] ^ St0[327];
assign C0[8] = St0[8] ^ St0[88] ^ St0[168] ^ St0[248] ^ St0[328];
assign C0[9] = St0[9] ^ St0[89] ^ St0[169] ^ St0[249] ^ St0[329];
assign C0[10] = St0[10] ^ St0[90] ^ St0[170] ^ St0[250] ^ St0[330];
assign C0[11] = St0[11] ^ St0[91] ^ St0[171] ^ St0[251] ^ St0[331];
assign C0[12] = St0[12] ^ St0[92] ^ St0[172] ^ St0[252] ^ St0[332];
assign C0[13] = St0[13] ^ St0[93] ^ St0[173] ^ St0[253] ^ St0[333];
assign C0[14] = St0[14] ^ St0[94] ^ St0[174] ^ St0[254] ^ St0[334];
assign C0[15] = St0[15] ^ St0[95] ^ St0[175] ^ St0[255] ^ St0[335];
assign C0[16] = St0[16] ^ St0[96] ^ St0[176] ^ St0[256] ^ St0[336];
assign C0[17] = St0[17] ^ St0[97] ^ St0[177] ^ St0[257] ^ St0[337];
assign C0[18] = St0[18] ^ St0[98] ^ St0[178] ^ St0[258] ^ St0[338];
assign C0[19] = St0[19] ^ St0[99] ^ St0[179] ^ St0[259] ^ St0[339];
assign C0[20] = St0[20] ^ St0[100] ^ St0[180] ^ St0[260] ^ St0[340];
assign C0[21] = St0[21] ^ St0[101] ^ St0[181] ^ St0[261] ^ St0[341];
assign C0[22] = St0[22] ^ St0[102] ^ St0[182] ^ St0[262] ^ St0[342];
assign C0[23] = St0[23] ^ St0[103] ^ St0[183] ^ St0[263] ^ St0[343];
assign C0[24] = St0[24] ^ St0[104] ^ St0[184] ^ St0[264] ^ St0[344];
assign C0[25] = St0[25] ^ St0[105] ^ St0[185] ^ St0[265] ^ St0[345];
assign C0[26] = St0[26] ^ St0[106] ^ St0[186] ^ St0[266] ^ St0[346];
assign C0[27] = St0[27] ^ St0[107] ^ St0[187] ^ St0[267] ^ St0[347];
assign C0[28] = St0[28] ^ St0[108] ^ St0[188] ^ St0[268] ^ St0[348];
assign C0[29] = St0[29] ^ St0[109] ^ St0[189] ^ St0[269] ^ St0[349];
assign C0[30] = St0[30] ^ St0[110] ^ St0[190] ^ St0[270] ^ St0[350];
assign C0[31] = St0[31] ^ St0[111] ^ St0[191] ^ St0[271] ^ St0[351];
assign C0[32] = St0[32] ^ St0[112] ^ St0[192] ^ St0[272] ^ St0[352];
assign C0[33] = St0[33] ^ St0[113] ^ St0[193] ^ St0[273] ^ St0[353];
assign C0[34] = St0[34] ^ St0[114] ^ St0[194] ^ St0[274] ^ St0[354];
assign C0[35] = St0[35] ^ St0[115] ^ St0[195] ^ St0[275] ^ St0[355];
assign C0[36] = St0[36] ^ St0[116] ^ St0[196] ^ St0[276] ^ St0[356];
assign C0[37] = St0[37] ^ St0[117] ^ St0[197] ^ St0[277] ^ St0[357];
assign C0[38] = St0[38] ^ St0[118] ^ St0[198] ^ St0[278] ^ St0[358];
assign C0[39] = St0[39] ^ St0[119] ^ St0[199] ^ St0[279] ^ St0[359];
assign C0[40] = St0[40] ^ St0[120] ^ St0[200] ^ St0[280] ^ St0[360];
assign C0[41] = St0[41] ^ St0[121] ^ St0[201] ^ St0[281] ^ St0[361];
assign C0[42] = St0[42] ^ St0[122] ^ St0[202] ^ St0[282] ^ St0[362];
assign C0[43] = St0[43] ^ St0[123] ^ St0[203] ^ St0[283] ^ St0[363];
assign C0[44] = St0[44] ^ St0[124] ^ St0[204] ^ St0[284] ^ St0[364];
assign C0[45] = St0[45] ^ St0[125] ^ St0[205] ^ St0[285] ^ St0[365];
assign C0[46] = St0[46] ^ St0[126] ^ St0[206] ^ St0[286] ^ St0[366];
assign C0[47] = St0[47] ^ St0[127] ^ St0[207] ^ St0[287] ^ St0[367];
assign C0[48] = St0[48] ^ St0[128] ^ St0[208] ^ St0[288] ^ St0[368];
assign C0[49] = St0[49] ^ St0[129] ^ St0[209] ^ St0[289] ^ St0[369];
assign C0[50] = St0[50] ^ St0[130] ^ St0[210] ^ St0[290] ^ St0[370];
assign C0[51] = St0[51] ^ St0[131] ^ St0[211] ^ St0[291] ^ St0[371];
assign C0[52] = St0[52] ^ St0[132] ^ St0[212] ^ St0[292] ^ St0[372];
assign C0[53] = St0[53] ^ St0[133] ^ St0[213] ^ St0[293] ^ St0[373];
assign C0[54] = St0[54] ^ St0[134] ^ St0[214] ^ St0[294] ^ St0[374];
assign C0[55] = St0[55] ^ St0[135] ^ St0[215] ^ St0[295] ^ St0[375];
assign C0[56] = St0[56] ^ St0[136] ^ St0[216] ^ St0[296] ^ St0[376];
assign C0[57] = St0[57] ^ St0[137] ^ St0[217] ^ St0[297] ^ St0[377];
assign C0[58] = St0[58] ^ St0[138] ^ St0[218] ^ St0[298] ^ St0[378];
assign C0[59] = St0[59] ^ St0[139] ^ St0[219] ^ St0[299] ^ St0[379];
assign C0[60] = St0[60] ^ St0[140] ^ St0[220] ^ St0[300] ^ St0[380];
assign C0[61] = St0[61] ^ St0[141] ^ St0[221] ^ St0[301] ^ St0[381];
assign C0[62] = St0[62] ^ St0[142] ^ St0[222] ^ St0[302] ^ St0[382];
assign C0[63] = St0[63] ^ St0[143] ^ St0[223] ^ St0[303] ^ St0[383];
assign C0[64] = St0[64] ^ St0[144] ^ St0[224] ^ St0[304] ^ St0[384];
assign C0[65] = St0[65] ^ St0[145] ^ St0[225] ^ St0[305] ^ St0[385];
assign C0[66] = St0[66] ^ St0[146] ^ St0[226] ^ St0[306] ^ St0[386];
assign C0[67] = St0[67] ^ St0[147] ^ St0[227] ^ St0[307] ^ St0[387];
assign C0[68] = St0[68] ^ St0[148] ^ St0[228] ^ St0[308] ^ St0[388];
assign C0[69] = St0[69] ^ St0[149] ^ St0[229] ^ St0[309] ^ St0[389];
assign C0[70] = St0[70] ^ St0[150] ^ St0[230] ^ St0[310] ^ St0[390];
assign C0[71] = St0[71] ^ St0[151] ^ St0[231] ^ St0[311] ^ St0[391];
assign C0[72] = St0[72] ^ St0[152] ^ St0[232] ^ St0[312] ^ St0[392];
assign C0[73] = St0[73] ^ St0[153] ^ St0[233] ^ St0[313] ^ St0[393];
assign C0[74] = St0[74] ^ St0[154] ^ St0[234] ^ St0[314] ^ St0[394];
assign C0[75] = St0[75] ^ St0[155] ^ St0[235] ^ St0[315] ^ St0[395];
assign C0[76] = St0[76] ^ St0[156] ^ St0[236] ^ St0[316] ^ St0[396];
assign C0[77] = St0[77] ^ St0[157] ^ St0[237] ^ St0[317] ^ St0[397];
assign C0[78] = St0[78] ^ St0[158] ^ St0[238] ^ St0[318] ^ St0[398];
assign C0[79] = St0[79] ^ St0[159] ^ St0[239] ^ St0[319] ^ St0[399];
assign D0[0] = C0[64] ^ C0[31];
assign D0[1] = C0[65] ^ C0[16];
assign D0[2] = C0[66] ^ C0[17];
assign D0[3] = C0[67] ^ C0[18];
assign D0[4] = C0[68] ^ C0[19];
assign D0[5] = C0[69] ^ C0[20];
assign D0[6] = C0[70] ^ C0[21];
assign D0[7] = C0[71] ^ C0[22];
assign D0[8] = C0[72] ^ C0[23];
assign D0[9] = C0[73] ^ C0[24];
assign D0[10] = C0[74] ^ C0[25];
assign D0[11] = C0[75] ^ C0[26];
assign D0[12] = C0[76] ^ C0[27];
assign D0[13] = C0[77] ^ C0[28];
assign D0[14] = C0[78] ^ C0[29];
assign D0[15] = C0[79] ^ C0[30];
assign D0[16] = C0[0] ^ C0[47];
assign D0[17] = C0[1] ^ C0[32];
assign D0[18] = C0[2] ^ C0[33];
assign D0[19] = C0[3] ^ C0[34];
assign D0[20] = C0[4] ^ C0[35];
assign D0[21] = C0[5] ^ C0[36];
assign D0[22] = C0[6] ^ C0[37];
assign D0[23] = C0[7] ^ C0[38];
assign D0[24] = C0[8] ^ C0[39];
assign D0[25] = C0[9] ^ C0[40];
assign D0[26] = C0[10] ^ C0[41];
assign D0[27] = C0[11] ^ C0[42];
assign D0[28] = C0[12] ^ C0[43];
assign D0[29] = C0[13] ^ C0[44];
assign D0[30] = C0[14] ^ C0[45];
assign D0[31] = C0[15] ^ C0[46];
assign D0[32] = C0[16] ^ C0[63];
assign D0[33] = C0[17] ^ C0[48];
assign D0[34] = C0[18] ^ C0[49];
assign D0[35] = C0[19] ^ C0[50];
assign D0[36] = C0[20] ^ C0[51];
assign D0[37] = C0[21] ^ C0[52];
assign D0[38] = C0[22] ^ C0[53];
assign D0[39] = C0[23] ^ C0[54];
assign D0[40] = C0[24] ^ C0[55];
assign D0[41] = C0[25] ^ C0[56];
assign D0[42] = C0[26] ^ C0[57];
assign D0[43] = C0[27] ^ C0[58];
assign D0[44] = C0[28] ^ C0[59];
assign D0[45] = C0[29] ^ C0[60];
assign D0[46] = C0[30] ^ C0[61];
assign D0[47] = C0[31] ^ C0[62];
assign D0[48] = C0[32] ^ C0[79];
assign D0[49] = C0[33] ^ C0[64];
assign D0[50] = C0[34] ^ C0[65];
assign D0[51] = C0[35] ^ C0[66];
assign D0[52] = C0[36] ^ C0[67];
assign D0[53] = C0[37] ^ C0[68];
assign D0[54] = C0[38] ^ C0[69];
assign D0[55] = C0[39] ^ C0[70];
assign D0[56] = C0[40] ^ C0[71];
assign D0[57] = C0[41] ^ C0[72];
assign D0[58] = C0[42] ^ C0[73];
assign D0[59] = C0[43] ^ C0[74];
assign D0[60] = C0[44] ^ C0[75];
assign D0[61] = C0[45] ^ C0[76];
assign D0[62] = C0[46] ^ C0[77];
assign D0[63] = C0[47] ^ C0[78];
assign D0[64] = C0[48] ^ C0[15];
assign D0[65] = C0[49] ^ C0[0];
assign D0[66] = C0[50] ^ C0[1];
assign D0[67] = C0[51] ^ C0[2];
assign D0[68] = C0[52] ^ C0[3];
assign D0[69] = C0[53] ^ C0[4];
assign D0[70] = C0[54] ^ C0[5];
assign D0[71] = C0[55] ^ C0[6];
assign D0[72] = C0[56] ^ C0[7];
assign D0[73] = C0[57] ^ C0[8];
assign D0[74] = C0[58] ^ C0[9];
assign D0[75] = C0[59] ^ C0[10];
assign D0[76] = C0[60] ^ C0[11];
assign D0[77] = C0[61] ^ C0[12];
assign D0[78] = C0[62] ^ C0[13];
assign D0[79] = C0[63] ^ C0[14];
wire [79:0] C1, D1;
assign C1[0] = St1[0] ^ St1[80] ^ St1[160] ^ St1[240] ^ St1[320];
assign C1[1] = St1[1] ^ St1[81] ^ St1[161] ^ St1[241] ^ St1[321];
assign C1[2] = St1[2] ^ St1[82] ^ St1[162] ^ St1[242] ^ St1[322];
assign C1[3] = St1[3] ^ St1[83] ^ St1[163] ^ St1[243] ^ St1[323];
assign C1[4] = St1[4] ^ St1[84] ^ St1[164] ^ St1[244] ^ St1[324];
assign C1[5] = St1[5] ^ St1[85] ^ St1[165] ^ St1[245] ^ St1[325];
assign C1[6] = St1[6] ^ St1[86] ^ St1[166] ^ St1[246] ^ St1[326];
assign C1[7] = St1[7] ^ St1[87] ^ St1[167] ^ St1[247] ^ St1[327];
assign C1[8] = St1[8] ^ St1[88] ^ St1[168] ^ St1[248] ^ St1[328];
assign C1[9] = St1[9] ^ St1[89] ^ St1[169] ^ St1[249] ^ St1[329];
assign C1[10] = St1[10] ^ St1[90] ^ St1[170] ^ St1[250] ^ St1[330];
assign C1[11] = St1[11] ^ St1[91] ^ St1[171] ^ St1[251] ^ St1[331];
assign C1[12] = St1[12] ^ St1[92] ^ St1[172] ^ St1[252] ^ St1[332];
assign C1[13] = St1[13] ^ St1[93] ^ St1[173] ^ St1[253] ^ St1[333];
assign C1[14] = St1[14] ^ St1[94] ^ St1[174] ^ St1[254] ^ St1[334];
assign C1[15] = St1[15] ^ St1[95] ^ St1[175] ^ St1[255] ^ St1[335];
assign C1[16] = St1[16] ^ St1[96] ^ St1[176] ^ St1[256] ^ St1[336];
assign C1[17] = St1[17] ^ St1[97] ^ St1[177] ^ St1[257] ^ St1[337];
assign C1[18] = St1[18] ^ St1[98] ^ St1[178] ^ St1[258] ^ St1[338];
assign C1[19] = St1[19] ^ St1[99] ^ St1[179] ^ St1[259] ^ St1[339];
assign C1[20] = St1[20] ^ St1[100] ^ St1[180] ^ St1[260] ^ St1[340];
assign C1[21] = St1[21] ^ St1[101] ^ St1[181] ^ St1[261] ^ St1[341];
assign C1[22] = St1[22] ^ St1[102] ^ St1[182] ^ St1[262] ^ St1[342];
assign C1[23] = St1[23] ^ St1[103] ^ St1[183] ^ St1[263] ^ St1[343];
assign C1[24] = St1[24] ^ St1[104] ^ St1[184] ^ St1[264] ^ St1[344];
assign C1[25] = St1[25] ^ St1[105] ^ St1[185] ^ St1[265] ^ St1[345];
assign C1[26] = St1[26] ^ St1[106] ^ St1[186] ^ St1[266] ^ St1[346];
assign C1[27] = St1[27] ^ St1[107] ^ St1[187] ^ St1[267] ^ St1[347];
assign C1[28] = St1[28] ^ St1[108] ^ St1[188] ^ St1[268] ^ St1[348];
assign C1[29] = St1[29] ^ St1[109] ^ St1[189] ^ St1[269] ^ St1[349];
assign C1[30] = St1[30] ^ St1[110] ^ St1[190] ^ St1[270] ^ St1[350];
assign C1[31] = St1[31] ^ St1[111] ^ St1[191] ^ St1[271] ^ St1[351];
assign C1[32] = St1[32] ^ St1[112] ^ St1[192] ^ St1[272] ^ St1[352];
assign C1[33] = St1[33] ^ St1[113] ^ St1[193] ^ St1[273] ^ St1[353];
assign C1[34] = St1[34] ^ St1[114] ^ St1[194] ^ St1[274] ^ St1[354];
assign C1[35] = St1[35] ^ St1[115] ^ St1[195] ^ St1[275] ^ St1[355];
assign C1[36] = St1[36] ^ St1[116] ^ St1[196] ^ St1[276] ^ St1[356];
assign C1[37] = St1[37] ^ St1[117] ^ St1[197] ^ St1[277] ^ St1[357];
assign C1[38] = St1[38] ^ St1[118] ^ St1[198] ^ St1[278] ^ St1[358];
assign C1[39] = St1[39] ^ St1[119] ^ St1[199] ^ St1[279] ^ St1[359];
assign C1[40] = St1[40] ^ St1[120] ^ St1[200] ^ St1[280] ^ St1[360];
assign C1[41] = St1[41] ^ St1[121] ^ St1[201] ^ St1[281] ^ St1[361];
assign C1[42] = St1[42] ^ St1[122] ^ St1[202] ^ St1[282] ^ St1[362];
assign C1[43] = St1[43] ^ St1[123] ^ St1[203] ^ St1[283] ^ St1[363];
assign C1[44] = St1[44] ^ St1[124] ^ St1[204] ^ St1[284] ^ St1[364];
assign C1[45] = St1[45] ^ St1[125] ^ St1[205] ^ St1[285] ^ St1[365];
assign C1[46] = St1[46] ^ St1[126] ^ St1[206] ^ St1[286] ^ St1[366];
assign C1[47] = St1[47] ^ St1[127] ^ St1[207] ^ St1[287] ^ St1[367];
assign C1[48] = St1[48] ^ St1[128] ^ St1[208] ^ St1[288] ^ St1[368];
assign C1[49] = St1[49] ^ St1[129] ^ St1[209] ^ St1[289] ^ St1[369];
assign C1[50] = St1[50] ^ St1[130] ^ St1[210] ^ St1[290] ^ St1[370];
assign C1[51] = St1[51] ^ St1[131] ^ St1[211] ^ St1[291] ^ St1[371];
assign C1[52] = St1[52] ^ St1[132] ^ St1[212] ^ St1[292] ^ St1[372];
assign C1[53] = St1[53] ^ St1[133] ^ St1[213] ^ St1[293] ^ St1[373];
assign C1[54] = St1[54] ^ St1[134] ^ St1[214] ^ St1[294] ^ St1[374];
assign C1[55] = St1[55] ^ St1[135] ^ St1[215] ^ St1[295] ^ St1[375];
assign C1[56] = St1[56] ^ St1[136] ^ St1[216] ^ St1[296] ^ St1[376];
assign C1[57] = St1[57] ^ St1[137] ^ St1[217] ^ St1[297] ^ St1[377];
assign C1[58] = St1[58] ^ St1[138] ^ St1[218] ^ St1[298] ^ St1[378];
assign C1[59] = St1[59] ^ St1[139] ^ St1[219] ^ St1[299] ^ St1[379];
assign C1[60] = St1[60] ^ St1[140] ^ St1[220] ^ St1[300] ^ St1[380];
assign C1[61] = St1[61] ^ St1[141] ^ St1[221] ^ St1[301] ^ St1[381];
assign C1[62] = St1[62] ^ St1[142] ^ St1[222] ^ St1[302] ^ St1[382];
assign C1[63] = St1[63] ^ St1[143] ^ St1[223] ^ St1[303] ^ St1[383];
assign C1[64] = St1[64] ^ St1[144] ^ St1[224] ^ St1[304] ^ St1[384];
assign C1[65] = St1[65] ^ St1[145] ^ St1[225] ^ St1[305] ^ St1[385];
assign C1[66] = St1[66] ^ St1[146] ^ St1[226] ^ St1[306] ^ St1[386];
assign C1[67] = St1[67] ^ St1[147] ^ St1[227] ^ St1[307] ^ St1[387];
assign C1[68] = St1[68] ^ St1[148] ^ St1[228] ^ St1[308] ^ St1[388];
assign C1[69] = St1[69] ^ St1[149] ^ St1[229] ^ St1[309] ^ St1[389];
assign C1[70] = St1[70] ^ St1[150] ^ St1[230] ^ St1[310] ^ St1[390];
assign C1[71] = St1[71] ^ St1[151] ^ St1[231] ^ St1[311] ^ St1[391];
assign C1[72] = St1[72] ^ St1[152] ^ St1[232] ^ St1[312] ^ St1[392];
assign C1[73] = St1[73] ^ St1[153] ^ St1[233] ^ St1[313] ^ St1[393];
assign C1[74] = St1[74] ^ St1[154] ^ St1[234] ^ St1[314] ^ St1[394];
assign C1[75] = St1[75] ^ St1[155] ^ St1[235] ^ St1[315] ^ St1[395];
assign C1[76] = St1[76] ^ St1[156] ^ St1[236] ^ St1[316] ^ St1[396];
assign C1[77] = St1[77] ^ St1[157] ^ St1[237] ^ St1[317] ^ St1[397];
assign C1[78] = St1[78] ^ St1[158] ^ St1[238] ^ St1[318] ^ St1[398];
assign C1[79] = St1[79] ^ St1[159] ^ St1[239] ^ St1[319] ^ St1[399];
assign D1[0] = C1[64] ^ C1[31];
assign D1[1] = C1[65] ^ C1[16];
assign D1[2] = C1[66] ^ C1[17];
assign D1[3] = C1[67] ^ C1[18];
assign D1[4] = C1[68] ^ C1[19];
assign D1[5] = C1[69] ^ C1[20];
assign D1[6] = C1[70] ^ C1[21];
assign D1[7] = C1[71] ^ C1[22];
assign D1[8] = C1[72] ^ C1[23];
assign D1[9] = C1[73] ^ C1[24];
assign D1[10] = C1[74] ^ C1[25];
assign D1[11] = C1[75] ^ C1[26];
assign D1[12] = C1[76] ^ C1[27];
assign D1[13] = C1[77] ^ C1[28];
assign D1[14] = C1[78] ^ C1[29];
assign D1[15] = C1[79] ^ C1[30];
assign D1[16] = C1[0] ^ C1[47];
assign D1[17] = C1[1] ^ C1[32];
assign D1[18] = C1[2] ^ C1[33];
assign D1[19] = C1[3] ^ C1[34];
assign D1[20] = C1[4] ^ C1[35];
assign D1[21] = C1[5] ^ C1[36];
assign D1[22] = C1[6] ^ C1[37];
assign D1[23] = C1[7] ^ C1[38];
assign D1[24] = C1[8] ^ C1[39];
assign D1[25] = C1[9] ^ C1[40];
assign D1[26] = C1[10] ^ C1[41];
assign D1[27] = C1[11] ^ C1[42];
assign D1[28] = C1[12] ^ C1[43];
assign D1[29] = C1[13] ^ C1[44];
assign D1[30] = C1[14] ^ C1[45];
assign D1[31] = C1[15] ^ C1[46];
assign D1[32] = C1[16] ^ C1[63];
assign D1[33] = C1[17] ^ C1[48];
assign D1[34] = C1[18] ^ C1[49];
assign D1[35] = C1[19] ^ C1[50];
assign D1[36] = C1[20] ^ C1[51];
assign D1[37] = C1[21] ^ C1[52];
assign D1[38] = C1[22] ^ C1[53];
assign D1[39] = C1[23] ^ C1[54];
assign D1[40] = C1[24] ^ C1[55];
assign D1[41] = C1[25] ^ C1[56];
assign D1[42] = C1[26] ^ C1[57];
assign D1[43] = C1[27] ^ C1[58];
assign D1[44] = C1[28] ^ C1[59];
assign D1[45] = C1[29] ^ C1[60];
assign D1[46] = C1[30] ^ C1[61];
assign D1[47] = C1[31] ^ C1[62];
assign D1[48] = C1[32] ^ C1[79];
assign D1[49] = C1[33] ^ C1[64];
assign D1[50] = C1[34] ^ C1[65];
assign D1[51] = C1[35] ^ C1[66];
assign D1[52] = C1[36] ^ C1[67];
assign D1[53] = C1[37] ^ C1[68];
assign D1[54] = C1[38] ^ C1[69];
assign D1[55] = C1[39] ^ C1[70];
assign D1[56] = C1[40] ^ C1[71];
assign D1[57] = C1[41] ^ C1[72];
assign D1[58] = C1[42] ^ C1[73];
assign D1[59] = C1[43] ^ C1[74];
assign D1[60] = C1[44] ^ C1[75];
assign D1[61] = C1[45] ^ C1[76];
assign D1[62] = C1[46] ^ C1[77];
assign D1[63] = C1[47] ^ C1[78];
assign D1[64] = C1[48] ^ C1[15];
assign D1[65] = C1[49] ^ C1[0];
assign D1[66] = C1[50] ^ C1[1];
assign D1[67] = C1[51] ^ C1[2];
assign D1[68] = C1[52] ^ C1[3];
assign D1[69] = C1[53] ^ C1[4];
assign D1[70] = C1[54] ^ C1[5];
assign D1[71] = C1[55] ^ C1[6];
assign D1[72] = C1[56] ^ C1[7];
assign D1[73] = C1[57] ^ C1[8];
assign D1[74] = C1[58] ^ C1[9];
assign D1[75] = C1[59] ^ C1[10];
assign D1[76] = C1[60] ^ C1[11];
assign D1[77] = C1[61] ^ C1[12];
assign D1[78] = C1[62] ^ C1[13];
assign D1[79] = C1[63] ^ C1[14];

// ---- rho + pi (pure wiring): Bx[(2x+3y)%5 lane-row perm][z] ----
assign Bx0[0] = St0[0] ^ D0[0];
assign Bx0[1] = St0[1] ^ D0[1];
assign Bx0[2] = St0[2] ^ D0[2];
assign Bx0[3] = St0[3] ^ D0[3];
assign Bx0[4] = St0[4] ^ D0[4];
assign Bx0[5] = St0[5] ^ D0[5];
assign Bx0[6] = St0[6] ^ D0[6];
assign Bx0[7] = St0[7] ^ D0[7];
assign Bx0[8] = St0[8] ^ D0[8];
assign Bx0[9] = St0[9] ^ D0[9];
assign Bx0[10] = St0[10] ^ D0[10];
assign Bx0[11] = St0[11] ^ D0[11];
assign Bx0[12] = St0[12] ^ D0[12];
assign Bx0[13] = St0[13] ^ D0[13];
assign Bx0[14] = St0[14] ^ D0[14];
assign Bx0[15] = St0[15] ^ D0[15];
assign Bx0[256] = St0[92] ^ D0[12];
assign Bx0[257] = St0[93] ^ D0[13];
assign Bx0[258] = St0[94] ^ D0[14];
assign Bx0[259] = St0[95] ^ D0[15];
assign Bx0[260] = St0[80] ^ D0[0];
assign Bx0[261] = St0[81] ^ D0[1];
assign Bx0[262] = St0[82] ^ D0[2];
assign Bx0[263] = St0[83] ^ D0[3];
assign Bx0[264] = St0[84] ^ D0[4];
assign Bx0[265] = St0[85] ^ D0[5];
assign Bx0[266] = St0[86] ^ D0[6];
assign Bx0[267] = St0[87] ^ D0[7];
assign Bx0[268] = St0[88] ^ D0[8];
assign Bx0[269] = St0[89] ^ D0[9];
assign Bx0[270] = St0[90] ^ D0[10];
assign Bx0[271] = St0[91] ^ D0[11];
assign Bx0[112] = St0[173] ^ D0[13];
assign Bx0[113] = St0[174] ^ D0[14];
assign Bx0[114] = St0[175] ^ D0[15];
assign Bx0[115] = St0[160] ^ D0[0];
assign Bx0[116] = St0[161] ^ D0[1];
assign Bx0[117] = St0[162] ^ D0[2];
assign Bx0[118] = St0[163] ^ D0[3];
assign Bx0[119] = St0[164] ^ D0[4];
assign Bx0[120] = St0[165] ^ D0[5];
assign Bx0[121] = St0[166] ^ D0[6];
assign Bx0[122] = St0[167] ^ D0[7];
assign Bx0[123] = St0[168] ^ D0[8];
assign Bx0[124] = St0[169] ^ D0[9];
assign Bx0[125] = St0[170] ^ D0[10];
assign Bx0[126] = St0[171] ^ D0[11];
assign Bx0[127] = St0[172] ^ D0[12];
assign Bx0[368] = St0[247] ^ D0[7];
assign Bx0[369] = St0[248] ^ D0[8];
assign Bx0[370] = St0[249] ^ D0[9];
assign Bx0[371] = St0[250] ^ D0[10];
assign Bx0[372] = St0[251] ^ D0[11];
assign Bx0[373] = St0[252] ^ D0[12];
assign Bx0[374] = St0[253] ^ D0[13];
assign Bx0[375] = St0[254] ^ D0[14];
assign Bx0[376] = St0[255] ^ D0[15];
assign Bx0[377] = St0[240] ^ D0[0];
assign Bx0[378] = St0[241] ^ D0[1];
assign Bx0[379] = St0[242] ^ D0[2];
assign Bx0[380] = St0[243] ^ D0[3];
assign Bx0[381] = St0[244] ^ D0[4];
assign Bx0[382] = St0[245] ^ D0[5];
assign Bx0[383] = St0[246] ^ D0[6];
assign Bx0[224] = St0[334] ^ D0[14];
assign Bx0[225] = St0[335] ^ D0[15];
assign Bx0[226] = St0[320] ^ D0[0];
assign Bx0[227] = St0[321] ^ D0[1];
assign Bx0[228] = St0[322] ^ D0[2];
assign Bx0[229] = St0[323] ^ D0[3];
assign Bx0[230] = St0[324] ^ D0[4];
assign Bx0[231] = St0[325] ^ D0[5];
assign Bx0[232] = St0[326] ^ D0[6];
assign Bx0[233] = St0[327] ^ D0[7];
assign Bx0[234] = St0[328] ^ D0[8];
assign Bx0[235] = St0[329] ^ D0[9];
assign Bx0[236] = St0[330] ^ D0[10];
assign Bx0[237] = St0[331] ^ D0[11];
assign Bx0[238] = St0[332] ^ D0[12];
assign Bx0[239] = St0[333] ^ D0[13];
assign Bx0[160] = St0[31] ^ D0[31];
assign Bx0[161] = St0[16] ^ D0[16];
assign Bx0[162] = St0[17] ^ D0[17];
assign Bx0[163] = St0[18] ^ D0[18];
assign Bx0[164] = St0[19] ^ D0[19];
assign Bx0[165] = St0[20] ^ D0[20];
assign Bx0[166] = St0[21] ^ D0[21];
assign Bx0[167] = St0[22] ^ D0[22];
assign Bx0[168] = St0[23] ^ D0[23];
assign Bx0[169] = St0[24] ^ D0[24];
assign Bx0[170] = St0[25] ^ D0[25];
assign Bx0[171] = St0[26] ^ D0[26];
assign Bx0[172] = St0[27] ^ D0[27];
assign Bx0[173] = St0[28] ^ D0[28];
assign Bx0[174] = St0[29] ^ D0[29];
assign Bx0[175] = St0[30] ^ D0[30];
assign Bx0[16] = St0[100] ^ D0[20];
assign Bx0[17] = St0[101] ^ D0[21];
assign Bx0[18] = St0[102] ^ D0[22];
assign Bx0[19] = St0[103] ^ D0[23];
assign Bx0[20] = St0[104] ^ D0[24];
assign Bx0[21] = St0[105] ^ D0[25];
assign Bx0[22] = St0[106] ^ D0[26];
assign Bx0[23] = St0[107] ^ D0[27];
assign Bx0[24] = St0[108] ^ D0[28];
assign Bx0[25] = St0[109] ^ D0[29];
assign Bx0[26] = St0[110] ^ D0[30];
assign Bx0[27] = St0[111] ^ D0[31];
assign Bx0[28] = St0[96] ^ D0[16];
assign Bx0[29] = St0[97] ^ D0[17];
assign Bx0[30] = St0[98] ^ D0[18];
assign Bx0[31] = St0[99] ^ D0[19];
assign Bx0[272] = St0[182] ^ D0[22];
assign Bx0[273] = St0[183] ^ D0[23];
assign Bx0[274] = St0[184] ^ D0[24];
assign Bx0[275] = St0[185] ^ D0[25];
assign Bx0[276] = St0[186] ^ D0[26];
assign Bx0[277] = St0[187] ^ D0[27];
assign Bx0[278] = St0[188] ^ D0[28];
assign Bx0[279] = St0[189] ^ D0[29];
assign Bx0[280] = St0[190] ^ D0[30];
assign Bx0[281] = St0[191] ^ D0[31];
assign Bx0[282] = St0[176] ^ D0[16];
assign Bx0[283] = St0[177] ^ D0[17];
assign Bx0[284] = St0[178] ^ D0[18];
assign Bx0[285] = St0[179] ^ D0[19];
assign Bx0[286] = St0[180] ^ D0[20];
assign Bx0[287] = St0[181] ^ D0[21];
assign Bx0[128] = St0[259] ^ D0[19];
assign Bx0[129] = St0[260] ^ D0[20];
assign Bx0[130] = St0[261] ^ D0[21];
assign Bx0[131] = St0[262] ^ D0[22];
assign Bx0[132] = St0[263] ^ D0[23];
assign Bx0[133] = St0[264] ^ D0[24];
assign Bx0[134] = St0[265] ^ D0[25];
assign Bx0[135] = St0[266] ^ D0[26];
assign Bx0[136] = St0[267] ^ D0[27];
assign Bx0[137] = St0[268] ^ D0[28];
assign Bx0[138] = St0[269] ^ D0[29];
assign Bx0[139] = St0[270] ^ D0[30];
assign Bx0[140] = St0[271] ^ D0[31];
assign Bx0[141] = St0[256] ^ D0[16];
assign Bx0[142] = St0[257] ^ D0[17];
assign Bx0[143] = St0[258] ^ D0[18];
assign Bx0[384] = St0[350] ^ D0[30];
assign Bx0[385] = St0[351] ^ D0[31];
assign Bx0[386] = St0[336] ^ D0[16];
assign Bx0[387] = St0[337] ^ D0[17];
assign Bx0[388] = St0[338] ^ D0[18];
assign Bx0[389] = St0[339] ^ D0[19];
assign Bx0[390] = St0[340] ^ D0[20];
assign Bx0[391] = St0[341] ^ D0[21];
assign Bx0[392] = St0[342] ^ D0[22];
assign Bx0[393] = St0[343] ^ D0[23];
assign Bx0[394] = St0[344] ^ D0[24];
assign Bx0[395] = St0[345] ^ D0[25];
assign Bx0[396] = St0[346] ^ D0[26];
assign Bx0[397] = St0[347] ^ D0[27];
assign Bx0[398] = St0[348] ^ D0[28];
assign Bx0[399] = St0[349] ^ D0[29];
assign Bx0[320] = St0[34] ^ D0[34];
assign Bx0[321] = St0[35] ^ D0[35];
assign Bx0[322] = St0[36] ^ D0[36];
assign Bx0[323] = St0[37] ^ D0[37];
assign Bx0[324] = St0[38] ^ D0[38];
assign Bx0[325] = St0[39] ^ D0[39];
assign Bx0[326] = St0[40] ^ D0[40];
assign Bx0[327] = St0[41] ^ D0[41];
assign Bx0[328] = St0[42] ^ D0[42];
assign Bx0[329] = St0[43] ^ D0[43];
assign Bx0[330] = St0[44] ^ D0[44];
assign Bx0[331] = St0[45] ^ D0[45];
assign Bx0[332] = St0[46] ^ D0[46];
assign Bx0[333] = St0[47] ^ D0[47];
assign Bx0[334] = St0[32] ^ D0[32];
assign Bx0[335] = St0[33] ^ D0[33];
assign Bx0[176] = St0[122] ^ D0[42];
assign Bx0[177] = St0[123] ^ D0[43];
assign Bx0[178] = St0[124] ^ D0[44];
assign Bx0[179] = St0[125] ^ D0[45];
assign Bx0[180] = St0[126] ^ D0[46];
assign Bx0[181] = St0[127] ^ D0[47];
assign Bx0[182] = St0[112] ^ D0[32];
assign Bx0[183] = St0[113] ^ D0[33];
assign Bx0[184] = St0[114] ^ D0[34];
assign Bx0[185] = St0[115] ^ D0[35];
assign Bx0[186] = St0[116] ^ D0[36];
assign Bx0[187] = St0[117] ^ D0[37];
assign Bx0[188] = St0[118] ^ D0[38];
assign Bx0[189] = St0[119] ^ D0[39];
assign Bx0[190] = St0[120] ^ D0[40];
assign Bx0[191] = St0[121] ^ D0[41];
assign Bx0[32] = St0[197] ^ D0[37];
assign Bx0[33] = St0[198] ^ D0[38];
assign Bx0[34] = St0[199] ^ D0[39];
assign Bx0[35] = St0[200] ^ D0[40];
assign Bx0[36] = St0[201] ^ D0[41];
assign Bx0[37] = St0[202] ^ D0[42];
assign Bx0[38] = St0[203] ^ D0[43];
assign Bx0[39] = St0[204] ^ D0[44];
assign Bx0[40] = St0[205] ^ D0[45];
assign Bx0[41] = St0[206] ^ D0[46];
assign Bx0[42] = St0[207] ^ D0[47];
assign Bx0[43] = St0[192] ^ D0[32];
assign Bx0[44] = St0[193] ^ D0[33];
assign Bx0[45] = St0[194] ^ D0[34];
assign Bx0[46] = St0[195] ^ D0[35];
assign Bx0[47] = St0[196] ^ D0[36];
assign Bx0[288] = St0[273] ^ D0[33];
assign Bx0[289] = St0[274] ^ D0[34];
assign Bx0[290] = St0[275] ^ D0[35];
assign Bx0[291] = St0[276] ^ D0[36];
assign Bx0[292] = St0[277] ^ D0[37];
assign Bx0[293] = St0[278] ^ D0[38];
assign Bx0[294] = St0[279] ^ D0[39];
assign Bx0[295] = St0[280] ^ D0[40];
assign Bx0[296] = St0[281] ^ D0[41];
assign Bx0[297] = St0[282] ^ D0[42];
assign Bx0[298] = St0[283] ^ D0[43];
assign Bx0[299] = St0[284] ^ D0[44];
assign Bx0[300] = St0[285] ^ D0[45];
assign Bx0[301] = St0[286] ^ D0[46];
assign Bx0[302] = St0[287] ^ D0[47];
assign Bx0[303] = St0[272] ^ D0[32];
assign Bx0[144] = St0[355] ^ D0[35];
assign Bx0[145] = St0[356] ^ D0[36];
assign Bx0[146] = St0[357] ^ D0[37];
assign Bx0[147] = St0[358] ^ D0[38];
assign Bx0[148] = St0[359] ^ D0[39];
assign Bx0[149] = St0[360] ^ D0[40];
assign Bx0[150] = St0[361] ^ D0[41];
assign Bx0[151] = St0[362] ^ D0[42];
assign Bx0[152] = St0[363] ^ D0[43];
assign Bx0[153] = St0[364] ^ D0[44];
assign Bx0[154] = St0[365] ^ D0[45];
assign Bx0[155] = St0[366] ^ D0[46];
assign Bx0[156] = St0[367] ^ D0[47];
assign Bx0[157] = St0[352] ^ D0[32];
assign Bx0[158] = St0[353] ^ D0[33];
assign Bx0[159] = St0[354] ^ D0[34];
assign Bx0[80] = St0[52] ^ D0[52];
assign Bx0[81] = St0[53] ^ D0[53];
assign Bx0[82] = St0[54] ^ D0[54];
assign Bx0[83] = St0[55] ^ D0[55];
assign Bx0[84] = St0[56] ^ D0[56];
assign Bx0[85] = St0[57] ^ D0[57];
assign Bx0[86] = St0[58] ^ D0[58];
assign Bx0[87] = St0[59] ^ D0[59];
assign Bx0[88] = St0[60] ^ D0[60];
assign Bx0[89] = St0[61] ^ D0[61];
assign Bx0[90] = St0[62] ^ D0[62];
assign Bx0[91] = St0[63] ^ D0[63];
assign Bx0[92] = St0[48] ^ D0[48];
assign Bx0[93] = St0[49] ^ D0[49];
assign Bx0[94] = St0[50] ^ D0[50];
assign Bx0[95] = St0[51] ^ D0[51];
assign Bx0[336] = St0[137] ^ D0[57];
assign Bx0[337] = St0[138] ^ D0[58];
assign Bx0[338] = St0[139] ^ D0[59];
assign Bx0[339] = St0[140] ^ D0[60];
assign Bx0[340] = St0[141] ^ D0[61];
assign Bx0[341] = St0[142] ^ D0[62];
assign Bx0[342] = St0[143] ^ D0[63];
assign Bx0[343] = St0[128] ^ D0[48];
assign Bx0[344] = St0[129] ^ D0[49];
assign Bx0[345] = St0[130] ^ D0[50];
assign Bx0[346] = St0[131] ^ D0[51];
assign Bx0[347] = St0[132] ^ D0[52];
assign Bx0[348] = St0[133] ^ D0[53];
assign Bx0[349] = St0[134] ^ D0[54];
assign Bx0[350] = St0[135] ^ D0[55];
assign Bx0[351] = St0[136] ^ D0[56];
assign Bx0[192] = St0[215] ^ D0[55];
assign Bx0[193] = St0[216] ^ D0[56];
assign Bx0[194] = St0[217] ^ D0[57];
assign Bx0[195] = St0[218] ^ D0[58];
assign Bx0[196] = St0[219] ^ D0[59];
assign Bx0[197] = St0[220] ^ D0[60];
assign Bx0[198] = St0[221] ^ D0[61];
assign Bx0[199] = St0[222] ^ D0[62];
assign Bx0[200] = St0[223] ^ D0[63];
assign Bx0[201] = St0[208] ^ D0[48];
assign Bx0[202] = St0[209] ^ D0[49];
assign Bx0[203] = St0[210] ^ D0[50];
assign Bx0[204] = St0[211] ^ D0[51];
assign Bx0[205] = St0[212] ^ D0[52];
assign Bx0[206] = St0[213] ^ D0[53];
assign Bx0[207] = St0[214] ^ D0[54];
assign Bx0[48] = St0[299] ^ D0[59];
assign Bx0[49] = St0[300] ^ D0[60];
assign Bx0[50] = St0[301] ^ D0[61];
assign Bx0[51] = St0[302] ^ D0[62];
assign Bx0[52] = St0[303] ^ D0[63];
assign Bx0[53] = St0[288] ^ D0[48];
assign Bx0[54] = St0[289] ^ D0[49];
assign Bx0[55] = St0[290] ^ D0[50];
assign Bx0[56] = St0[291] ^ D0[51];
assign Bx0[57] = St0[292] ^ D0[52];
assign Bx0[58] = St0[293] ^ D0[53];
assign Bx0[59] = St0[294] ^ D0[54];
assign Bx0[60] = St0[295] ^ D0[55];
assign Bx0[61] = St0[296] ^ D0[56];
assign Bx0[62] = St0[297] ^ D0[57];
assign Bx0[63] = St0[298] ^ D0[58];
assign Bx0[304] = St0[376] ^ D0[56];
assign Bx0[305] = St0[377] ^ D0[57];
assign Bx0[306] = St0[378] ^ D0[58];
assign Bx0[307] = St0[379] ^ D0[59];
assign Bx0[308] = St0[380] ^ D0[60];
assign Bx0[309] = St0[381] ^ D0[61];
assign Bx0[310] = St0[382] ^ D0[62];
assign Bx0[311] = St0[383] ^ D0[63];
assign Bx0[312] = St0[368] ^ D0[48];
assign Bx0[313] = St0[369] ^ D0[49];
assign Bx0[314] = St0[370] ^ D0[50];
assign Bx0[315] = St0[371] ^ D0[51];
assign Bx0[316] = St0[372] ^ D0[52];
assign Bx0[317] = St0[373] ^ D0[53];
assign Bx0[318] = St0[374] ^ D0[54];
assign Bx0[319] = St0[375] ^ D0[55];
assign Bx0[240] = St0[69] ^ D0[69];
assign Bx0[241] = St0[70] ^ D0[70];
assign Bx0[242] = St0[71] ^ D0[71];
assign Bx0[243] = St0[72] ^ D0[72];
assign Bx0[244] = St0[73] ^ D0[73];
assign Bx0[245] = St0[74] ^ D0[74];
assign Bx0[246] = St0[75] ^ D0[75];
assign Bx0[247] = St0[76] ^ D0[76];
assign Bx0[248] = St0[77] ^ D0[77];
assign Bx0[249] = St0[78] ^ D0[78];
assign Bx0[250] = St0[79] ^ D0[79];
assign Bx0[251] = St0[64] ^ D0[64];
assign Bx0[252] = St0[65] ^ D0[65];
assign Bx0[253] = St0[66] ^ D0[66];
assign Bx0[254] = St0[67] ^ D0[67];
assign Bx0[255] = St0[68] ^ D0[68];
assign Bx0[96] = St0[156] ^ D0[76];
assign Bx0[97] = St0[157] ^ D0[77];
assign Bx0[98] = St0[158] ^ D0[78];
assign Bx0[99] = St0[159] ^ D0[79];
assign Bx0[100] = St0[144] ^ D0[64];
assign Bx0[101] = St0[145] ^ D0[65];
assign Bx0[102] = St0[146] ^ D0[66];
assign Bx0[103] = St0[147] ^ D0[67];
assign Bx0[104] = St0[148] ^ D0[68];
assign Bx0[105] = St0[149] ^ D0[69];
assign Bx0[106] = St0[150] ^ D0[70];
assign Bx0[107] = St0[151] ^ D0[71];
assign Bx0[108] = St0[152] ^ D0[72];
assign Bx0[109] = St0[153] ^ D0[73];
assign Bx0[110] = St0[154] ^ D0[74];
assign Bx0[111] = St0[155] ^ D0[75];
assign Bx0[352] = St0[233] ^ D0[73];
assign Bx0[353] = St0[234] ^ D0[74];
assign Bx0[354] = St0[235] ^ D0[75];
assign Bx0[355] = St0[236] ^ D0[76];
assign Bx0[356] = St0[237] ^ D0[77];
assign Bx0[357] = St0[238] ^ D0[78];
assign Bx0[358] = St0[239] ^ D0[79];
assign Bx0[359] = St0[224] ^ D0[64];
assign Bx0[360] = St0[225] ^ D0[65];
assign Bx0[361] = St0[226] ^ D0[66];
assign Bx0[362] = St0[227] ^ D0[67];
assign Bx0[363] = St0[228] ^ D0[68];
assign Bx0[364] = St0[229] ^ D0[69];
assign Bx0[365] = St0[230] ^ D0[70];
assign Bx0[366] = St0[231] ^ D0[71];
assign Bx0[367] = St0[232] ^ D0[72];
assign Bx0[208] = St0[312] ^ D0[72];
assign Bx0[209] = St0[313] ^ D0[73];
assign Bx0[210] = St0[314] ^ D0[74];
assign Bx0[211] = St0[315] ^ D0[75];
assign Bx0[212] = St0[316] ^ D0[76];
assign Bx0[213] = St0[317] ^ D0[77];
assign Bx0[214] = St0[318] ^ D0[78];
assign Bx0[215] = St0[319] ^ D0[79];
assign Bx0[216] = St0[304] ^ D0[64];
assign Bx0[217] = St0[305] ^ D0[65];
assign Bx0[218] = St0[306] ^ D0[66];
assign Bx0[219] = St0[307] ^ D0[67];
assign Bx0[220] = St0[308] ^ D0[68];
assign Bx0[221] = St0[309] ^ D0[69];
assign Bx0[222] = St0[310] ^ D0[70];
assign Bx0[223] = St0[311] ^ D0[71];
assign Bx0[64] = St0[386] ^ D0[66];
assign Bx0[65] = St0[387] ^ D0[67];
assign Bx0[66] = St0[388] ^ D0[68];
assign Bx0[67] = St0[389] ^ D0[69];
assign Bx0[68] = St0[390] ^ D0[70];
assign Bx0[69] = St0[391] ^ D0[71];
assign Bx0[70] = St0[392] ^ D0[72];
assign Bx0[71] = St0[393] ^ D0[73];
assign Bx0[72] = St0[394] ^ D0[74];
assign Bx0[73] = St0[395] ^ D0[75];
assign Bx0[74] = St0[396] ^ D0[76];
assign Bx0[75] = St0[397] ^ D0[77];
assign Bx0[76] = St0[398] ^ D0[78];
assign Bx0[77] = St0[399] ^ D0[79];
assign Bx0[78] = St0[384] ^ D0[64];
assign Bx0[79] = St0[385] ^ D0[65];
assign Bx1[0] = St1[0] ^ D1[0];
assign Bx1[1] = St1[1] ^ D1[1];
assign Bx1[2] = St1[2] ^ D1[2];
assign Bx1[3] = St1[3] ^ D1[3];
assign Bx1[4] = St1[4] ^ D1[4];
assign Bx1[5] = St1[5] ^ D1[5];
assign Bx1[6] = St1[6] ^ D1[6];
assign Bx1[7] = St1[7] ^ D1[7];
assign Bx1[8] = St1[8] ^ D1[8];
assign Bx1[9] = St1[9] ^ D1[9];
assign Bx1[10] = St1[10] ^ D1[10];
assign Bx1[11] = St1[11] ^ D1[11];
assign Bx1[12] = St1[12] ^ D1[12];
assign Bx1[13] = St1[13] ^ D1[13];
assign Bx1[14] = St1[14] ^ D1[14];
assign Bx1[15] = St1[15] ^ D1[15];
assign Bx1[256] = St1[92] ^ D1[12];
assign Bx1[257] = St1[93] ^ D1[13];
assign Bx1[258] = St1[94] ^ D1[14];
assign Bx1[259] = St1[95] ^ D1[15];
assign Bx1[260] = St1[80] ^ D1[0];
assign Bx1[261] = St1[81] ^ D1[1];
assign Bx1[262] = St1[82] ^ D1[2];
assign Bx1[263] = St1[83] ^ D1[3];
assign Bx1[264] = St1[84] ^ D1[4];
assign Bx1[265] = St1[85] ^ D1[5];
assign Bx1[266] = St1[86] ^ D1[6];
assign Bx1[267] = St1[87] ^ D1[7];
assign Bx1[268] = St1[88] ^ D1[8];
assign Bx1[269] = St1[89] ^ D1[9];
assign Bx1[270] = St1[90] ^ D1[10];
assign Bx1[271] = St1[91] ^ D1[11];
assign Bx1[112] = St1[173] ^ D1[13];
assign Bx1[113] = St1[174] ^ D1[14];
assign Bx1[114] = St1[175] ^ D1[15];
assign Bx1[115] = St1[160] ^ D1[0];
assign Bx1[116] = St1[161] ^ D1[1];
assign Bx1[117] = St1[162] ^ D1[2];
assign Bx1[118] = St1[163] ^ D1[3];
assign Bx1[119] = St1[164] ^ D1[4];
assign Bx1[120] = St1[165] ^ D1[5];
assign Bx1[121] = St1[166] ^ D1[6];
assign Bx1[122] = St1[167] ^ D1[7];
assign Bx1[123] = St1[168] ^ D1[8];
assign Bx1[124] = St1[169] ^ D1[9];
assign Bx1[125] = St1[170] ^ D1[10];
assign Bx1[126] = St1[171] ^ D1[11];
assign Bx1[127] = St1[172] ^ D1[12];
assign Bx1[368] = St1[247] ^ D1[7];
assign Bx1[369] = St1[248] ^ D1[8];
assign Bx1[370] = St1[249] ^ D1[9];
assign Bx1[371] = St1[250] ^ D1[10];
assign Bx1[372] = St1[251] ^ D1[11];
assign Bx1[373] = St1[252] ^ D1[12];
assign Bx1[374] = St1[253] ^ D1[13];
assign Bx1[375] = St1[254] ^ D1[14];
assign Bx1[376] = St1[255] ^ D1[15];
assign Bx1[377] = St1[240] ^ D1[0];
assign Bx1[378] = St1[241] ^ D1[1];
assign Bx1[379] = St1[242] ^ D1[2];
assign Bx1[380] = St1[243] ^ D1[3];
assign Bx1[381] = St1[244] ^ D1[4];
assign Bx1[382] = St1[245] ^ D1[5];
assign Bx1[383] = St1[246] ^ D1[6];
assign Bx1[224] = St1[334] ^ D1[14];
assign Bx1[225] = St1[335] ^ D1[15];
assign Bx1[226] = St1[320] ^ D1[0];
assign Bx1[227] = St1[321] ^ D1[1];
assign Bx1[228] = St1[322] ^ D1[2];
assign Bx1[229] = St1[323] ^ D1[3];
assign Bx1[230] = St1[324] ^ D1[4];
assign Bx1[231] = St1[325] ^ D1[5];
assign Bx1[232] = St1[326] ^ D1[6];
assign Bx1[233] = St1[327] ^ D1[7];
assign Bx1[234] = St1[328] ^ D1[8];
assign Bx1[235] = St1[329] ^ D1[9];
assign Bx1[236] = St1[330] ^ D1[10];
assign Bx1[237] = St1[331] ^ D1[11];
assign Bx1[238] = St1[332] ^ D1[12];
assign Bx1[239] = St1[333] ^ D1[13];
assign Bx1[160] = St1[31] ^ D1[31];
assign Bx1[161] = St1[16] ^ D1[16];
assign Bx1[162] = St1[17] ^ D1[17];
assign Bx1[163] = St1[18] ^ D1[18];
assign Bx1[164] = St1[19] ^ D1[19];
assign Bx1[165] = St1[20] ^ D1[20];
assign Bx1[166] = St1[21] ^ D1[21];
assign Bx1[167] = St1[22] ^ D1[22];
assign Bx1[168] = St1[23] ^ D1[23];
assign Bx1[169] = St1[24] ^ D1[24];
assign Bx1[170] = St1[25] ^ D1[25];
assign Bx1[171] = St1[26] ^ D1[26];
assign Bx1[172] = St1[27] ^ D1[27];
assign Bx1[173] = St1[28] ^ D1[28];
assign Bx1[174] = St1[29] ^ D1[29];
assign Bx1[175] = St1[30] ^ D1[30];
assign Bx1[16] = St1[100] ^ D1[20];
assign Bx1[17] = St1[101] ^ D1[21];
assign Bx1[18] = St1[102] ^ D1[22];
assign Bx1[19] = St1[103] ^ D1[23];
assign Bx1[20] = St1[104] ^ D1[24];
assign Bx1[21] = St1[105] ^ D1[25];
assign Bx1[22] = St1[106] ^ D1[26];
assign Bx1[23] = St1[107] ^ D1[27];
assign Bx1[24] = St1[108] ^ D1[28];
assign Bx1[25] = St1[109] ^ D1[29];
assign Bx1[26] = St1[110] ^ D1[30];
assign Bx1[27] = St1[111] ^ D1[31];
assign Bx1[28] = St1[96] ^ D1[16];
assign Bx1[29] = St1[97] ^ D1[17];
assign Bx1[30] = St1[98] ^ D1[18];
assign Bx1[31] = St1[99] ^ D1[19];
assign Bx1[272] = St1[182] ^ D1[22];
assign Bx1[273] = St1[183] ^ D1[23];
assign Bx1[274] = St1[184] ^ D1[24];
assign Bx1[275] = St1[185] ^ D1[25];
assign Bx1[276] = St1[186] ^ D1[26];
assign Bx1[277] = St1[187] ^ D1[27];
assign Bx1[278] = St1[188] ^ D1[28];
assign Bx1[279] = St1[189] ^ D1[29];
assign Bx1[280] = St1[190] ^ D1[30];
assign Bx1[281] = St1[191] ^ D1[31];
assign Bx1[282] = St1[176] ^ D1[16];
assign Bx1[283] = St1[177] ^ D1[17];
assign Bx1[284] = St1[178] ^ D1[18];
assign Bx1[285] = St1[179] ^ D1[19];
assign Bx1[286] = St1[180] ^ D1[20];
assign Bx1[287] = St1[181] ^ D1[21];
assign Bx1[128] = St1[259] ^ D1[19];
assign Bx1[129] = St1[260] ^ D1[20];
assign Bx1[130] = St1[261] ^ D1[21];
assign Bx1[131] = St1[262] ^ D1[22];
assign Bx1[132] = St1[263] ^ D1[23];
assign Bx1[133] = St1[264] ^ D1[24];
assign Bx1[134] = St1[265] ^ D1[25];
assign Bx1[135] = St1[266] ^ D1[26];
assign Bx1[136] = St1[267] ^ D1[27];
assign Bx1[137] = St1[268] ^ D1[28];
assign Bx1[138] = St1[269] ^ D1[29];
assign Bx1[139] = St1[270] ^ D1[30];
assign Bx1[140] = St1[271] ^ D1[31];
assign Bx1[141] = St1[256] ^ D1[16];
assign Bx1[142] = St1[257] ^ D1[17];
assign Bx1[143] = St1[258] ^ D1[18];
assign Bx1[384] = St1[350] ^ D1[30];
assign Bx1[385] = St1[351] ^ D1[31];
assign Bx1[386] = St1[336] ^ D1[16];
assign Bx1[387] = St1[337] ^ D1[17];
assign Bx1[388] = St1[338] ^ D1[18];
assign Bx1[389] = St1[339] ^ D1[19];
assign Bx1[390] = St1[340] ^ D1[20];
assign Bx1[391] = St1[341] ^ D1[21];
assign Bx1[392] = St1[342] ^ D1[22];
assign Bx1[393] = St1[343] ^ D1[23];
assign Bx1[394] = St1[344] ^ D1[24];
assign Bx1[395] = St1[345] ^ D1[25];
assign Bx1[396] = St1[346] ^ D1[26];
assign Bx1[397] = St1[347] ^ D1[27];
assign Bx1[398] = St1[348] ^ D1[28];
assign Bx1[399] = St1[349] ^ D1[29];
assign Bx1[320] = St1[34] ^ D1[34];
assign Bx1[321] = St1[35] ^ D1[35];
assign Bx1[322] = St1[36] ^ D1[36];
assign Bx1[323] = St1[37] ^ D1[37];
assign Bx1[324] = St1[38] ^ D1[38];
assign Bx1[325] = St1[39] ^ D1[39];
assign Bx1[326] = St1[40] ^ D1[40];
assign Bx1[327] = St1[41] ^ D1[41];
assign Bx1[328] = St1[42] ^ D1[42];
assign Bx1[329] = St1[43] ^ D1[43];
assign Bx1[330] = St1[44] ^ D1[44];
assign Bx1[331] = St1[45] ^ D1[45];
assign Bx1[332] = St1[46] ^ D1[46];
assign Bx1[333] = St1[47] ^ D1[47];
assign Bx1[334] = St1[32] ^ D1[32];
assign Bx1[335] = St1[33] ^ D1[33];
assign Bx1[176] = St1[122] ^ D1[42];
assign Bx1[177] = St1[123] ^ D1[43];
assign Bx1[178] = St1[124] ^ D1[44];
assign Bx1[179] = St1[125] ^ D1[45];
assign Bx1[180] = St1[126] ^ D1[46];
assign Bx1[181] = St1[127] ^ D1[47];
assign Bx1[182] = St1[112] ^ D1[32];
assign Bx1[183] = St1[113] ^ D1[33];
assign Bx1[184] = St1[114] ^ D1[34];
assign Bx1[185] = St1[115] ^ D1[35];
assign Bx1[186] = St1[116] ^ D1[36];
assign Bx1[187] = St1[117] ^ D1[37];
assign Bx1[188] = St1[118] ^ D1[38];
assign Bx1[189] = St1[119] ^ D1[39];
assign Bx1[190] = St1[120] ^ D1[40];
assign Bx1[191] = St1[121] ^ D1[41];
assign Bx1[32] = St1[197] ^ D1[37];
assign Bx1[33] = St1[198] ^ D1[38];
assign Bx1[34] = St1[199] ^ D1[39];
assign Bx1[35] = St1[200] ^ D1[40];
assign Bx1[36] = St1[201] ^ D1[41];
assign Bx1[37] = St1[202] ^ D1[42];
assign Bx1[38] = St1[203] ^ D1[43];
assign Bx1[39] = St1[204] ^ D1[44];
assign Bx1[40] = St1[205] ^ D1[45];
assign Bx1[41] = St1[206] ^ D1[46];
assign Bx1[42] = St1[207] ^ D1[47];
assign Bx1[43] = St1[192] ^ D1[32];
assign Bx1[44] = St1[193] ^ D1[33];
assign Bx1[45] = St1[194] ^ D1[34];
assign Bx1[46] = St1[195] ^ D1[35];
assign Bx1[47] = St1[196] ^ D1[36];
assign Bx1[288] = St1[273] ^ D1[33];
assign Bx1[289] = St1[274] ^ D1[34];
assign Bx1[290] = St1[275] ^ D1[35];
assign Bx1[291] = St1[276] ^ D1[36];
assign Bx1[292] = St1[277] ^ D1[37];
assign Bx1[293] = St1[278] ^ D1[38];
assign Bx1[294] = St1[279] ^ D1[39];
assign Bx1[295] = St1[280] ^ D1[40];
assign Bx1[296] = St1[281] ^ D1[41];
assign Bx1[297] = St1[282] ^ D1[42];
assign Bx1[298] = St1[283] ^ D1[43];
assign Bx1[299] = St1[284] ^ D1[44];
assign Bx1[300] = St1[285] ^ D1[45];
assign Bx1[301] = St1[286] ^ D1[46];
assign Bx1[302] = St1[287] ^ D1[47];
assign Bx1[303] = St1[272] ^ D1[32];
assign Bx1[144] = St1[355] ^ D1[35];
assign Bx1[145] = St1[356] ^ D1[36];
assign Bx1[146] = St1[357] ^ D1[37];
assign Bx1[147] = St1[358] ^ D1[38];
assign Bx1[148] = St1[359] ^ D1[39];
assign Bx1[149] = St1[360] ^ D1[40];
assign Bx1[150] = St1[361] ^ D1[41];
assign Bx1[151] = St1[362] ^ D1[42];
assign Bx1[152] = St1[363] ^ D1[43];
assign Bx1[153] = St1[364] ^ D1[44];
assign Bx1[154] = St1[365] ^ D1[45];
assign Bx1[155] = St1[366] ^ D1[46];
assign Bx1[156] = St1[367] ^ D1[47];
assign Bx1[157] = St1[352] ^ D1[32];
assign Bx1[158] = St1[353] ^ D1[33];
assign Bx1[159] = St1[354] ^ D1[34];
assign Bx1[80] = St1[52] ^ D1[52];
assign Bx1[81] = St1[53] ^ D1[53];
assign Bx1[82] = St1[54] ^ D1[54];
assign Bx1[83] = St1[55] ^ D1[55];
assign Bx1[84] = St1[56] ^ D1[56];
assign Bx1[85] = St1[57] ^ D1[57];
assign Bx1[86] = St1[58] ^ D1[58];
assign Bx1[87] = St1[59] ^ D1[59];
assign Bx1[88] = St1[60] ^ D1[60];
assign Bx1[89] = St1[61] ^ D1[61];
assign Bx1[90] = St1[62] ^ D1[62];
assign Bx1[91] = St1[63] ^ D1[63];
assign Bx1[92] = St1[48] ^ D1[48];
assign Bx1[93] = St1[49] ^ D1[49];
assign Bx1[94] = St1[50] ^ D1[50];
assign Bx1[95] = St1[51] ^ D1[51];
assign Bx1[336] = St1[137] ^ D1[57];
assign Bx1[337] = St1[138] ^ D1[58];
assign Bx1[338] = St1[139] ^ D1[59];
assign Bx1[339] = St1[140] ^ D1[60];
assign Bx1[340] = St1[141] ^ D1[61];
assign Bx1[341] = St1[142] ^ D1[62];
assign Bx1[342] = St1[143] ^ D1[63];
assign Bx1[343] = St1[128] ^ D1[48];
assign Bx1[344] = St1[129] ^ D1[49];
assign Bx1[345] = St1[130] ^ D1[50];
assign Bx1[346] = St1[131] ^ D1[51];
assign Bx1[347] = St1[132] ^ D1[52];
assign Bx1[348] = St1[133] ^ D1[53];
assign Bx1[349] = St1[134] ^ D1[54];
assign Bx1[350] = St1[135] ^ D1[55];
assign Bx1[351] = St1[136] ^ D1[56];
assign Bx1[192] = St1[215] ^ D1[55];
assign Bx1[193] = St1[216] ^ D1[56];
assign Bx1[194] = St1[217] ^ D1[57];
assign Bx1[195] = St1[218] ^ D1[58];
assign Bx1[196] = St1[219] ^ D1[59];
assign Bx1[197] = St1[220] ^ D1[60];
assign Bx1[198] = St1[221] ^ D1[61];
assign Bx1[199] = St1[222] ^ D1[62];
assign Bx1[200] = St1[223] ^ D1[63];
assign Bx1[201] = St1[208] ^ D1[48];
assign Bx1[202] = St1[209] ^ D1[49];
assign Bx1[203] = St1[210] ^ D1[50];
assign Bx1[204] = St1[211] ^ D1[51];
assign Bx1[205] = St1[212] ^ D1[52];
assign Bx1[206] = St1[213] ^ D1[53];
assign Bx1[207] = St1[214] ^ D1[54];
assign Bx1[48] = St1[299] ^ D1[59];
assign Bx1[49] = St1[300] ^ D1[60];
assign Bx1[50] = St1[301] ^ D1[61];
assign Bx1[51] = St1[302] ^ D1[62];
assign Bx1[52] = St1[303] ^ D1[63];
assign Bx1[53] = St1[288] ^ D1[48];
assign Bx1[54] = St1[289] ^ D1[49];
assign Bx1[55] = St1[290] ^ D1[50];
assign Bx1[56] = St1[291] ^ D1[51];
assign Bx1[57] = St1[292] ^ D1[52];
assign Bx1[58] = St1[293] ^ D1[53];
assign Bx1[59] = St1[294] ^ D1[54];
assign Bx1[60] = St1[295] ^ D1[55];
assign Bx1[61] = St1[296] ^ D1[56];
assign Bx1[62] = St1[297] ^ D1[57];
assign Bx1[63] = St1[298] ^ D1[58];
assign Bx1[304] = St1[376] ^ D1[56];
assign Bx1[305] = St1[377] ^ D1[57];
assign Bx1[306] = St1[378] ^ D1[58];
assign Bx1[307] = St1[379] ^ D1[59];
assign Bx1[308] = St1[380] ^ D1[60];
assign Bx1[309] = St1[381] ^ D1[61];
assign Bx1[310] = St1[382] ^ D1[62];
assign Bx1[311] = St1[383] ^ D1[63];
assign Bx1[312] = St1[368] ^ D1[48];
assign Bx1[313] = St1[369] ^ D1[49];
assign Bx1[314] = St1[370] ^ D1[50];
assign Bx1[315] = St1[371] ^ D1[51];
assign Bx1[316] = St1[372] ^ D1[52];
assign Bx1[317] = St1[373] ^ D1[53];
assign Bx1[318] = St1[374] ^ D1[54];
assign Bx1[319] = St1[375] ^ D1[55];
assign Bx1[240] = St1[69] ^ D1[69];
assign Bx1[241] = St1[70] ^ D1[70];
assign Bx1[242] = St1[71] ^ D1[71];
assign Bx1[243] = St1[72] ^ D1[72];
assign Bx1[244] = St1[73] ^ D1[73];
assign Bx1[245] = St1[74] ^ D1[74];
assign Bx1[246] = St1[75] ^ D1[75];
assign Bx1[247] = St1[76] ^ D1[76];
assign Bx1[248] = St1[77] ^ D1[77];
assign Bx1[249] = St1[78] ^ D1[78];
assign Bx1[250] = St1[79] ^ D1[79];
assign Bx1[251] = St1[64] ^ D1[64];
assign Bx1[252] = St1[65] ^ D1[65];
assign Bx1[253] = St1[66] ^ D1[66];
assign Bx1[254] = St1[67] ^ D1[67];
assign Bx1[255] = St1[68] ^ D1[68];
assign Bx1[96] = St1[156] ^ D1[76];
assign Bx1[97] = St1[157] ^ D1[77];
assign Bx1[98] = St1[158] ^ D1[78];
assign Bx1[99] = St1[159] ^ D1[79];
assign Bx1[100] = St1[144] ^ D1[64];
assign Bx1[101] = St1[145] ^ D1[65];
assign Bx1[102] = St1[146] ^ D1[66];
assign Bx1[103] = St1[147] ^ D1[67];
assign Bx1[104] = St1[148] ^ D1[68];
assign Bx1[105] = St1[149] ^ D1[69];
assign Bx1[106] = St1[150] ^ D1[70];
assign Bx1[107] = St1[151] ^ D1[71];
assign Bx1[108] = St1[152] ^ D1[72];
assign Bx1[109] = St1[153] ^ D1[73];
assign Bx1[110] = St1[154] ^ D1[74];
assign Bx1[111] = St1[155] ^ D1[75];
assign Bx1[352] = St1[233] ^ D1[73];
assign Bx1[353] = St1[234] ^ D1[74];
assign Bx1[354] = St1[235] ^ D1[75];
assign Bx1[355] = St1[236] ^ D1[76];
assign Bx1[356] = St1[237] ^ D1[77];
assign Bx1[357] = St1[238] ^ D1[78];
assign Bx1[358] = St1[239] ^ D1[79];
assign Bx1[359] = St1[224] ^ D1[64];
assign Bx1[360] = St1[225] ^ D1[65];
assign Bx1[361] = St1[226] ^ D1[66];
assign Bx1[362] = St1[227] ^ D1[67];
assign Bx1[363] = St1[228] ^ D1[68];
assign Bx1[364] = St1[229] ^ D1[69];
assign Bx1[365] = St1[230] ^ D1[70];
assign Bx1[366] = St1[231] ^ D1[71];
assign Bx1[367] = St1[232] ^ D1[72];
assign Bx1[208] = St1[312] ^ D1[72];
assign Bx1[209] = St1[313] ^ D1[73];
assign Bx1[210] = St1[314] ^ D1[74];
assign Bx1[211] = St1[315] ^ D1[75];
assign Bx1[212] = St1[316] ^ D1[76];
assign Bx1[213] = St1[317] ^ D1[77];
assign Bx1[214] = St1[318] ^ D1[78];
assign Bx1[215] = St1[319] ^ D1[79];
assign Bx1[216] = St1[304] ^ D1[64];
assign Bx1[217] = St1[305] ^ D1[65];
assign Bx1[218] = St1[306] ^ D1[66];
assign Bx1[219] = St1[307] ^ D1[67];
assign Bx1[220] = St1[308] ^ D1[68];
assign Bx1[221] = St1[309] ^ D1[69];
assign Bx1[222] = St1[310] ^ D1[70];
assign Bx1[223] = St1[311] ^ D1[71];
assign Bx1[64] = St1[386] ^ D1[66];
assign Bx1[65] = St1[387] ^ D1[67];
assign Bx1[66] = St1[388] ^ D1[68];
assign Bx1[67] = St1[389] ^ D1[69];
assign Bx1[68] = St1[390] ^ D1[70];
assign Bx1[69] = St1[391] ^ D1[71];
assign Bx1[70] = St1[392] ^ D1[72];
assign Bx1[71] = St1[393] ^ D1[73];
assign Bx1[72] = St1[394] ^ D1[74];
assign Bx1[73] = St1[395] ^ D1[75];
assign Bx1[74] = St1[396] ^ D1[76];
assign Bx1[75] = St1[397] ^ D1[77];
assign Bx1[76] = St1[398] ^ D1[78];
assign Bx1[77] = St1[399] ^ D1[79];
assign Bx1[78] = St1[384] ^ D1[64];
assign Bx1[79] = St1[385] ^ D1[65];

// ---- chi: w_chi[x,y,z] = (~Bx[x+1,y,z]) AND Bx[x+2,y,z] ----
// NOT is share-local (complement share 0 only); nb_d* are the 1-cycle
// per-share balance registers feeding every gadget ina (contract ina@1).
wire [399:0] nb_src0, nb_src1;
wire [399:0] nb0 = ~nb_src0;   // share-local complement, share 0 only
wire [399:0] nb1 =  nb_src1;
reg  [399:0] nb_d0, nb_d1;
always @(posedge clk) begin
    nb_d0 <= nb0;
    nb_d1 <= nb1;
end
assign nb_src0[0] = Bx0[16];  assign nb_src1[0] = Bx1[16];
assign nb_src0[1] = Bx0[17];  assign nb_src1[1] = Bx1[17];
assign nb_src0[2] = Bx0[18];  assign nb_src1[2] = Bx1[18];
assign nb_src0[3] = Bx0[19];  assign nb_src1[3] = Bx1[19];
assign nb_src0[4] = Bx0[20];  assign nb_src1[4] = Bx1[20];
assign nb_src0[5] = Bx0[21];  assign nb_src1[5] = Bx1[21];
assign nb_src0[6] = Bx0[22];  assign nb_src1[6] = Bx1[22];
assign nb_src0[7] = Bx0[23];  assign nb_src1[7] = Bx1[23];
assign nb_src0[8] = Bx0[24];  assign nb_src1[8] = Bx1[24];
assign nb_src0[9] = Bx0[25];  assign nb_src1[9] = Bx1[25];
assign nb_src0[10] = Bx0[26];  assign nb_src1[10] = Bx1[26];
assign nb_src0[11] = Bx0[27];  assign nb_src1[11] = Bx1[27];
assign nb_src0[12] = Bx0[28];  assign nb_src1[12] = Bx1[28];
assign nb_src0[13] = Bx0[29];  assign nb_src1[13] = Bx1[29];
assign nb_src0[14] = Bx0[30];  assign nb_src1[14] = Bx1[30];
assign nb_src0[15] = Bx0[31];  assign nb_src1[15] = Bx1[31];
assign nb_src0[80] = Bx0[96];  assign nb_src1[80] = Bx1[96];
assign nb_src0[81] = Bx0[97];  assign nb_src1[81] = Bx1[97];
assign nb_src0[82] = Bx0[98];  assign nb_src1[82] = Bx1[98];
assign nb_src0[83] = Bx0[99];  assign nb_src1[83] = Bx1[99];
assign nb_src0[84] = Bx0[100];  assign nb_src1[84] = Bx1[100];
assign nb_src0[85] = Bx0[101];  assign nb_src1[85] = Bx1[101];
assign nb_src0[86] = Bx0[102];  assign nb_src1[86] = Bx1[102];
assign nb_src0[87] = Bx0[103];  assign nb_src1[87] = Bx1[103];
assign nb_src0[88] = Bx0[104];  assign nb_src1[88] = Bx1[104];
assign nb_src0[89] = Bx0[105];  assign nb_src1[89] = Bx1[105];
assign nb_src0[90] = Bx0[106];  assign nb_src1[90] = Bx1[106];
assign nb_src0[91] = Bx0[107];  assign nb_src1[91] = Bx1[107];
assign nb_src0[92] = Bx0[108];  assign nb_src1[92] = Bx1[108];
assign nb_src0[93] = Bx0[109];  assign nb_src1[93] = Bx1[109];
assign nb_src0[94] = Bx0[110];  assign nb_src1[94] = Bx1[110];
assign nb_src0[95] = Bx0[111];  assign nb_src1[95] = Bx1[111];
assign nb_src0[160] = Bx0[176];  assign nb_src1[160] = Bx1[176];
assign nb_src0[161] = Bx0[177];  assign nb_src1[161] = Bx1[177];
assign nb_src0[162] = Bx0[178];  assign nb_src1[162] = Bx1[178];
assign nb_src0[163] = Bx0[179];  assign nb_src1[163] = Bx1[179];
assign nb_src0[164] = Bx0[180];  assign nb_src1[164] = Bx1[180];
assign nb_src0[165] = Bx0[181];  assign nb_src1[165] = Bx1[181];
assign nb_src0[166] = Bx0[182];  assign nb_src1[166] = Bx1[182];
assign nb_src0[167] = Bx0[183];  assign nb_src1[167] = Bx1[183];
assign nb_src0[168] = Bx0[184];  assign nb_src1[168] = Bx1[184];
assign nb_src0[169] = Bx0[185];  assign nb_src1[169] = Bx1[185];
assign nb_src0[170] = Bx0[186];  assign nb_src1[170] = Bx1[186];
assign nb_src0[171] = Bx0[187];  assign nb_src1[171] = Bx1[187];
assign nb_src0[172] = Bx0[188];  assign nb_src1[172] = Bx1[188];
assign nb_src0[173] = Bx0[189];  assign nb_src1[173] = Bx1[189];
assign nb_src0[174] = Bx0[190];  assign nb_src1[174] = Bx1[190];
assign nb_src0[175] = Bx0[191];  assign nb_src1[175] = Bx1[191];
assign nb_src0[240] = Bx0[256];  assign nb_src1[240] = Bx1[256];
assign nb_src0[241] = Bx0[257];  assign nb_src1[241] = Bx1[257];
assign nb_src0[242] = Bx0[258];  assign nb_src1[242] = Bx1[258];
assign nb_src0[243] = Bx0[259];  assign nb_src1[243] = Bx1[259];
assign nb_src0[244] = Bx0[260];  assign nb_src1[244] = Bx1[260];
assign nb_src0[245] = Bx0[261];  assign nb_src1[245] = Bx1[261];
assign nb_src0[246] = Bx0[262];  assign nb_src1[246] = Bx1[262];
assign nb_src0[247] = Bx0[263];  assign nb_src1[247] = Bx1[263];
assign nb_src0[248] = Bx0[264];  assign nb_src1[248] = Bx1[264];
assign nb_src0[249] = Bx0[265];  assign nb_src1[249] = Bx1[265];
assign nb_src0[250] = Bx0[266];  assign nb_src1[250] = Bx1[266];
assign nb_src0[251] = Bx0[267];  assign nb_src1[251] = Bx1[267];
assign nb_src0[252] = Bx0[268];  assign nb_src1[252] = Bx1[268];
assign nb_src0[253] = Bx0[269];  assign nb_src1[253] = Bx1[269];
assign nb_src0[254] = Bx0[270];  assign nb_src1[254] = Bx1[270];
assign nb_src0[255] = Bx0[271];  assign nb_src1[255] = Bx1[271];
assign nb_src0[320] = Bx0[336];  assign nb_src1[320] = Bx1[336];
assign nb_src0[321] = Bx0[337];  assign nb_src1[321] = Bx1[337];
assign nb_src0[322] = Bx0[338];  assign nb_src1[322] = Bx1[338];
assign nb_src0[323] = Bx0[339];  assign nb_src1[323] = Bx1[339];
assign nb_src0[324] = Bx0[340];  assign nb_src1[324] = Bx1[340];
assign nb_src0[325] = Bx0[341];  assign nb_src1[325] = Bx1[341];
assign nb_src0[326] = Bx0[342];  assign nb_src1[326] = Bx1[342];
assign nb_src0[327] = Bx0[343];  assign nb_src1[327] = Bx1[343];
assign nb_src0[328] = Bx0[344];  assign nb_src1[328] = Bx1[344];
assign nb_src0[329] = Bx0[345];  assign nb_src1[329] = Bx1[345];
assign nb_src0[330] = Bx0[346];  assign nb_src1[330] = Bx1[346];
assign nb_src0[331] = Bx0[347];  assign nb_src1[331] = Bx1[347];
assign nb_src0[332] = Bx0[348];  assign nb_src1[332] = Bx1[348];
assign nb_src0[333] = Bx0[349];  assign nb_src1[333] = Bx1[349];
assign nb_src0[334] = Bx0[350];  assign nb_src1[334] = Bx1[350];
assign nb_src0[335] = Bx0[351];  assign nb_src1[335] = Bx1[351];
assign nb_src0[16] = Bx0[32];  assign nb_src1[16] = Bx1[32];
assign nb_src0[17] = Bx0[33];  assign nb_src1[17] = Bx1[33];
assign nb_src0[18] = Bx0[34];  assign nb_src1[18] = Bx1[34];
assign nb_src0[19] = Bx0[35];  assign nb_src1[19] = Bx1[35];
assign nb_src0[20] = Bx0[36];  assign nb_src1[20] = Bx1[36];
assign nb_src0[21] = Bx0[37];  assign nb_src1[21] = Bx1[37];
assign nb_src0[22] = Bx0[38];  assign nb_src1[22] = Bx1[38];
assign nb_src0[23] = Bx0[39];  assign nb_src1[23] = Bx1[39];
assign nb_src0[24] = Bx0[40];  assign nb_src1[24] = Bx1[40];
assign nb_src0[25] = Bx0[41];  assign nb_src1[25] = Bx1[41];
assign nb_src0[26] = Bx0[42];  assign nb_src1[26] = Bx1[42];
assign nb_src0[27] = Bx0[43];  assign nb_src1[27] = Bx1[43];
assign nb_src0[28] = Bx0[44];  assign nb_src1[28] = Bx1[44];
assign nb_src0[29] = Bx0[45];  assign nb_src1[29] = Bx1[45];
assign nb_src0[30] = Bx0[46];  assign nb_src1[30] = Bx1[46];
assign nb_src0[31] = Bx0[47];  assign nb_src1[31] = Bx1[47];
assign nb_src0[96] = Bx0[112];  assign nb_src1[96] = Bx1[112];
assign nb_src0[97] = Bx0[113];  assign nb_src1[97] = Bx1[113];
assign nb_src0[98] = Bx0[114];  assign nb_src1[98] = Bx1[114];
assign nb_src0[99] = Bx0[115];  assign nb_src1[99] = Bx1[115];
assign nb_src0[100] = Bx0[116];  assign nb_src1[100] = Bx1[116];
assign nb_src0[101] = Bx0[117];  assign nb_src1[101] = Bx1[117];
assign nb_src0[102] = Bx0[118];  assign nb_src1[102] = Bx1[118];
assign nb_src0[103] = Bx0[119];  assign nb_src1[103] = Bx1[119];
assign nb_src0[104] = Bx0[120];  assign nb_src1[104] = Bx1[120];
assign nb_src0[105] = Bx0[121];  assign nb_src1[105] = Bx1[121];
assign nb_src0[106] = Bx0[122];  assign nb_src1[106] = Bx1[122];
assign nb_src0[107] = Bx0[123];  assign nb_src1[107] = Bx1[123];
assign nb_src0[108] = Bx0[124];  assign nb_src1[108] = Bx1[124];
assign nb_src0[109] = Bx0[125];  assign nb_src1[109] = Bx1[125];
assign nb_src0[110] = Bx0[126];  assign nb_src1[110] = Bx1[126];
assign nb_src0[111] = Bx0[127];  assign nb_src1[111] = Bx1[127];
assign nb_src0[176] = Bx0[192];  assign nb_src1[176] = Bx1[192];
assign nb_src0[177] = Bx0[193];  assign nb_src1[177] = Bx1[193];
assign nb_src0[178] = Bx0[194];  assign nb_src1[178] = Bx1[194];
assign nb_src0[179] = Bx0[195];  assign nb_src1[179] = Bx1[195];
assign nb_src0[180] = Bx0[196];  assign nb_src1[180] = Bx1[196];
assign nb_src0[181] = Bx0[197];  assign nb_src1[181] = Bx1[197];
assign nb_src0[182] = Bx0[198];  assign nb_src1[182] = Bx1[198];
assign nb_src0[183] = Bx0[199];  assign nb_src1[183] = Bx1[199];
assign nb_src0[184] = Bx0[200];  assign nb_src1[184] = Bx1[200];
assign nb_src0[185] = Bx0[201];  assign nb_src1[185] = Bx1[201];
assign nb_src0[186] = Bx0[202];  assign nb_src1[186] = Bx1[202];
assign nb_src0[187] = Bx0[203];  assign nb_src1[187] = Bx1[203];
assign nb_src0[188] = Bx0[204];  assign nb_src1[188] = Bx1[204];
assign nb_src0[189] = Bx0[205];  assign nb_src1[189] = Bx1[205];
assign nb_src0[190] = Bx0[206];  assign nb_src1[190] = Bx1[206];
assign nb_src0[191] = Bx0[207];  assign nb_src1[191] = Bx1[207];
assign nb_src0[256] = Bx0[272];  assign nb_src1[256] = Bx1[272];
assign nb_src0[257] = Bx0[273];  assign nb_src1[257] = Bx1[273];
assign nb_src0[258] = Bx0[274];  assign nb_src1[258] = Bx1[274];
assign nb_src0[259] = Bx0[275];  assign nb_src1[259] = Bx1[275];
assign nb_src0[260] = Bx0[276];  assign nb_src1[260] = Bx1[276];
assign nb_src0[261] = Bx0[277];  assign nb_src1[261] = Bx1[277];
assign nb_src0[262] = Bx0[278];  assign nb_src1[262] = Bx1[278];
assign nb_src0[263] = Bx0[279];  assign nb_src1[263] = Bx1[279];
assign nb_src0[264] = Bx0[280];  assign nb_src1[264] = Bx1[280];
assign nb_src0[265] = Bx0[281];  assign nb_src1[265] = Bx1[281];
assign nb_src0[266] = Bx0[282];  assign nb_src1[266] = Bx1[282];
assign nb_src0[267] = Bx0[283];  assign nb_src1[267] = Bx1[283];
assign nb_src0[268] = Bx0[284];  assign nb_src1[268] = Bx1[284];
assign nb_src0[269] = Bx0[285];  assign nb_src1[269] = Bx1[285];
assign nb_src0[270] = Bx0[286];  assign nb_src1[270] = Bx1[286];
assign nb_src0[271] = Bx0[287];  assign nb_src1[271] = Bx1[287];
assign nb_src0[336] = Bx0[352];  assign nb_src1[336] = Bx1[352];
assign nb_src0[337] = Bx0[353];  assign nb_src1[337] = Bx1[353];
assign nb_src0[338] = Bx0[354];  assign nb_src1[338] = Bx1[354];
assign nb_src0[339] = Bx0[355];  assign nb_src1[339] = Bx1[355];
assign nb_src0[340] = Bx0[356];  assign nb_src1[340] = Bx1[356];
assign nb_src0[341] = Bx0[357];  assign nb_src1[341] = Bx1[357];
assign nb_src0[342] = Bx0[358];  assign nb_src1[342] = Bx1[358];
assign nb_src0[343] = Bx0[359];  assign nb_src1[343] = Bx1[359];
assign nb_src0[344] = Bx0[360];  assign nb_src1[344] = Bx1[360];
assign nb_src0[345] = Bx0[361];  assign nb_src1[345] = Bx1[361];
assign nb_src0[346] = Bx0[362];  assign nb_src1[346] = Bx1[362];
assign nb_src0[347] = Bx0[363];  assign nb_src1[347] = Bx1[363];
assign nb_src0[348] = Bx0[364];  assign nb_src1[348] = Bx1[364];
assign nb_src0[349] = Bx0[365];  assign nb_src1[349] = Bx1[365];
assign nb_src0[350] = Bx0[366];  assign nb_src1[350] = Bx1[366];
assign nb_src0[351] = Bx0[367];  assign nb_src1[351] = Bx1[367];
assign nb_src0[32] = Bx0[48];  assign nb_src1[32] = Bx1[48];
assign nb_src0[33] = Bx0[49];  assign nb_src1[33] = Bx1[49];
assign nb_src0[34] = Bx0[50];  assign nb_src1[34] = Bx1[50];
assign nb_src0[35] = Bx0[51];  assign nb_src1[35] = Bx1[51];
assign nb_src0[36] = Bx0[52];  assign nb_src1[36] = Bx1[52];
assign nb_src0[37] = Bx0[53];  assign nb_src1[37] = Bx1[53];
assign nb_src0[38] = Bx0[54];  assign nb_src1[38] = Bx1[54];
assign nb_src0[39] = Bx0[55];  assign nb_src1[39] = Bx1[55];
assign nb_src0[40] = Bx0[56];  assign nb_src1[40] = Bx1[56];
assign nb_src0[41] = Bx0[57];  assign nb_src1[41] = Bx1[57];
assign nb_src0[42] = Bx0[58];  assign nb_src1[42] = Bx1[58];
assign nb_src0[43] = Bx0[59];  assign nb_src1[43] = Bx1[59];
assign nb_src0[44] = Bx0[60];  assign nb_src1[44] = Bx1[60];
assign nb_src0[45] = Bx0[61];  assign nb_src1[45] = Bx1[61];
assign nb_src0[46] = Bx0[62];  assign nb_src1[46] = Bx1[62];
assign nb_src0[47] = Bx0[63];  assign nb_src1[47] = Bx1[63];
assign nb_src0[112] = Bx0[128];  assign nb_src1[112] = Bx1[128];
assign nb_src0[113] = Bx0[129];  assign nb_src1[113] = Bx1[129];
assign nb_src0[114] = Bx0[130];  assign nb_src1[114] = Bx1[130];
assign nb_src0[115] = Bx0[131];  assign nb_src1[115] = Bx1[131];
assign nb_src0[116] = Bx0[132];  assign nb_src1[116] = Bx1[132];
assign nb_src0[117] = Bx0[133];  assign nb_src1[117] = Bx1[133];
assign nb_src0[118] = Bx0[134];  assign nb_src1[118] = Bx1[134];
assign nb_src0[119] = Bx0[135];  assign nb_src1[119] = Bx1[135];
assign nb_src0[120] = Bx0[136];  assign nb_src1[120] = Bx1[136];
assign nb_src0[121] = Bx0[137];  assign nb_src1[121] = Bx1[137];
assign nb_src0[122] = Bx0[138];  assign nb_src1[122] = Bx1[138];
assign nb_src0[123] = Bx0[139];  assign nb_src1[123] = Bx1[139];
assign nb_src0[124] = Bx0[140];  assign nb_src1[124] = Bx1[140];
assign nb_src0[125] = Bx0[141];  assign nb_src1[125] = Bx1[141];
assign nb_src0[126] = Bx0[142];  assign nb_src1[126] = Bx1[142];
assign nb_src0[127] = Bx0[143];  assign nb_src1[127] = Bx1[143];
assign nb_src0[192] = Bx0[208];  assign nb_src1[192] = Bx1[208];
assign nb_src0[193] = Bx0[209];  assign nb_src1[193] = Bx1[209];
assign nb_src0[194] = Bx0[210];  assign nb_src1[194] = Bx1[210];
assign nb_src0[195] = Bx0[211];  assign nb_src1[195] = Bx1[211];
assign nb_src0[196] = Bx0[212];  assign nb_src1[196] = Bx1[212];
assign nb_src0[197] = Bx0[213];  assign nb_src1[197] = Bx1[213];
assign nb_src0[198] = Bx0[214];  assign nb_src1[198] = Bx1[214];
assign nb_src0[199] = Bx0[215];  assign nb_src1[199] = Bx1[215];
assign nb_src0[200] = Bx0[216];  assign nb_src1[200] = Bx1[216];
assign nb_src0[201] = Bx0[217];  assign nb_src1[201] = Bx1[217];
assign nb_src0[202] = Bx0[218];  assign nb_src1[202] = Bx1[218];
assign nb_src0[203] = Bx0[219];  assign nb_src1[203] = Bx1[219];
assign nb_src0[204] = Bx0[220];  assign nb_src1[204] = Bx1[220];
assign nb_src0[205] = Bx0[221];  assign nb_src1[205] = Bx1[221];
assign nb_src0[206] = Bx0[222];  assign nb_src1[206] = Bx1[222];
assign nb_src0[207] = Bx0[223];  assign nb_src1[207] = Bx1[223];
assign nb_src0[272] = Bx0[288];  assign nb_src1[272] = Bx1[288];
assign nb_src0[273] = Bx0[289];  assign nb_src1[273] = Bx1[289];
assign nb_src0[274] = Bx0[290];  assign nb_src1[274] = Bx1[290];
assign nb_src0[275] = Bx0[291];  assign nb_src1[275] = Bx1[291];
assign nb_src0[276] = Bx0[292];  assign nb_src1[276] = Bx1[292];
assign nb_src0[277] = Bx0[293];  assign nb_src1[277] = Bx1[293];
assign nb_src0[278] = Bx0[294];  assign nb_src1[278] = Bx1[294];
assign nb_src0[279] = Bx0[295];  assign nb_src1[279] = Bx1[295];
assign nb_src0[280] = Bx0[296];  assign nb_src1[280] = Bx1[296];
assign nb_src0[281] = Bx0[297];  assign nb_src1[281] = Bx1[297];
assign nb_src0[282] = Bx0[298];  assign nb_src1[282] = Bx1[298];
assign nb_src0[283] = Bx0[299];  assign nb_src1[283] = Bx1[299];
assign nb_src0[284] = Bx0[300];  assign nb_src1[284] = Bx1[300];
assign nb_src0[285] = Bx0[301];  assign nb_src1[285] = Bx1[301];
assign nb_src0[286] = Bx0[302];  assign nb_src1[286] = Bx1[302];
assign nb_src0[287] = Bx0[303];  assign nb_src1[287] = Bx1[303];
assign nb_src0[352] = Bx0[368];  assign nb_src1[352] = Bx1[368];
assign nb_src0[353] = Bx0[369];  assign nb_src1[353] = Bx1[369];
assign nb_src0[354] = Bx0[370];  assign nb_src1[354] = Bx1[370];
assign nb_src0[355] = Bx0[371];  assign nb_src1[355] = Bx1[371];
assign nb_src0[356] = Bx0[372];  assign nb_src1[356] = Bx1[372];
assign nb_src0[357] = Bx0[373];  assign nb_src1[357] = Bx1[373];
assign nb_src0[358] = Bx0[374];  assign nb_src1[358] = Bx1[374];
assign nb_src0[359] = Bx0[375];  assign nb_src1[359] = Bx1[375];
assign nb_src0[360] = Bx0[376];  assign nb_src1[360] = Bx1[376];
assign nb_src0[361] = Bx0[377];  assign nb_src1[361] = Bx1[377];
assign nb_src0[362] = Bx0[378];  assign nb_src1[362] = Bx1[378];
assign nb_src0[363] = Bx0[379];  assign nb_src1[363] = Bx1[379];
assign nb_src0[364] = Bx0[380];  assign nb_src1[364] = Bx1[380];
assign nb_src0[365] = Bx0[381];  assign nb_src1[365] = Bx1[381];
assign nb_src0[366] = Bx0[382];  assign nb_src1[366] = Bx1[382];
assign nb_src0[367] = Bx0[383];  assign nb_src1[367] = Bx1[383];
assign nb_src0[48] = Bx0[64];  assign nb_src1[48] = Bx1[64];
assign nb_src0[49] = Bx0[65];  assign nb_src1[49] = Bx1[65];
assign nb_src0[50] = Bx0[66];  assign nb_src1[50] = Bx1[66];
assign nb_src0[51] = Bx0[67];  assign nb_src1[51] = Bx1[67];
assign nb_src0[52] = Bx0[68];  assign nb_src1[52] = Bx1[68];
assign nb_src0[53] = Bx0[69];  assign nb_src1[53] = Bx1[69];
assign nb_src0[54] = Bx0[70];  assign nb_src1[54] = Bx1[70];
assign nb_src0[55] = Bx0[71];  assign nb_src1[55] = Bx1[71];
assign nb_src0[56] = Bx0[72];  assign nb_src1[56] = Bx1[72];
assign nb_src0[57] = Bx0[73];  assign nb_src1[57] = Bx1[73];
assign nb_src0[58] = Bx0[74];  assign nb_src1[58] = Bx1[74];
assign nb_src0[59] = Bx0[75];  assign nb_src1[59] = Bx1[75];
assign nb_src0[60] = Bx0[76];  assign nb_src1[60] = Bx1[76];
assign nb_src0[61] = Bx0[77];  assign nb_src1[61] = Bx1[77];
assign nb_src0[62] = Bx0[78];  assign nb_src1[62] = Bx1[78];
assign nb_src0[63] = Bx0[79];  assign nb_src1[63] = Bx1[79];
assign nb_src0[128] = Bx0[144];  assign nb_src1[128] = Bx1[144];
assign nb_src0[129] = Bx0[145];  assign nb_src1[129] = Bx1[145];
assign nb_src0[130] = Bx0[146];  assign nb_src1[130] = Bx1[146];
assign nb_src0[131] = Bx0[147];  assign nb_src1[131] = Bx1[147];
assign nb_src0[132] = Bx0[148];  assign nb_src1[132] = Bx1[148];
assign nb_src0[133] = Bx0[149];  assign nb_src1[133] = Bx1[149];
assign nb_src0[134] = Bx0[150];  assign nb_src1[134] = Bx1[150];
assign nb_src0[135] = Bx0[151];  assign nb_src1[135] = Bx1[151];
assign nb_src0[136] = Bx0[152];  assign nb_src1[136] = Bx1[152];
assign nb_src0[137] = Bx0[153];  assign nb_src1[137] = Bx1[153];
assign nb_src0[138] = Bx0[154];  assign nb_src1[138] = Bx1[154];
assign nb_src0[139] = Bx0[155];  assign nb_src1[139] = Bx1[155];
assign nb_src0[140] = Bx0[156];  assign nb_src1[140] = Bx1[156];
assign nb_src0[141] = Bx0[157];  assign nb_src1[141] = Bx1[157];
assign nb_src0[142] = Bx0[158];  assign nb_src1[142] = Bx1[158];
assign nb_src0[143] = Bx0[159];  assign nb_src1[143] = Bx1[159];
assign nb_src0[208] = Bx0[224];  assign nb_src1[208] = Bx1[224];
assign nb_src0[209] = Bx0[225];  assign nb_src1[209] = Bx1[225];
assign nb_src0[210] = Bx0[226];  assign nb_src1[210] = Bx1[226];
assign nb_src0[211] = Bx0[227];  assign nb_src1[211] = Bx1[227];
assign nb_src0[212] = Bx0[228];  assign nb_src1[212] = Bx1[228];
assign nb_src0[213] = Bx0[229];  assign nb_src1[213] = Bx1[229];
assign nb_src0[214] = Bx0[230];  assign nb_src1[214] = Bx1[230];
assign nb_src0[215] = Bx0[231];  assign nb_src1[215] = Bx1[231];
assign nb_src0[216] = Bx0[232];  assign nb_src1[216] = Bx1[232];
assign nb_src0[217] = Bx0[233];  assign nb_src1[217] = Bx1[233];
assign nb_src0[218] = Bx0[234];  assign nb_src1[218] = Bx1[234];
assign nb_src0[219] = Bx0[235];  assign nb_src1[219] = Bx1[235];
assign nb_src0[220] = Bx0[236];  assign nb_src1[220] = Bx1[236];
assign nb_src0[221] = Bx0[237];  assign nb_src1[221] = Bx1[237];
assign nb_src0[222] = Bx0[238];  assign nb_src1[222] = Bx1[238];
assign nb_src0[223] = Bx0[239];  assign nb_src1[223] = Bx1[239];
assign nb_src0[288] = Bx0[304];  assign nb_src1[288] = Bx1[304];
assign nb_src0[289] = Bx0[305];  assign nb_src1[289] = Bx1[305];
assign nb_src0[290] = Bx0[306];  assign nb_src1[290] = Bx1[306];
assign nb_src0[291] = Bx0[307];  assign nb_src1[291] = Bx1[307];
assign nb_src0[292] = Bx0[308];  assign nb_src1[292] = Bx1[308];
assign nb_src0[293] = Bx0[309];  assign nb_src1[293] = Bx1[309];
assign nb_src0[294] = Bx0[310];  assign nb_src1[294] = Bx1[310];
assign nb_src0[295] = Bx0[311];  assign nb_src1[295] = Bx1[311];
assign nb_src0[296] = Bx0[312];  assign nb_src1[296] = Bx1[312];
assign nb_src0[297] = Bx0[313];  assign nb_src1[297] = Bx1[313];
assign nb_src0[298] = Bx0[314];  assign nb_src1[298] = Bx1[314];
assign nb_src0[299] = Bx0[315];  assign nb_src1[299] = Bx1[315];
assign nb_src0[300] = Bx0[316];  assign nb_src1[300] = Bx1[316];
assign nb_src0[301] = Bx0[317];  assign nb_src1[301] = Bx1[317];
assign nb_src0[302] = Bx0[318];  assign nb_src1[302] = Bx1[318];
assign nb_src0[303] = Bx0[319];  assign nb_src1[303] = Bx1[319];
assign nb_src0[368] = Bx0[384];  assign nb_src1[368] = Bx1[384];
assign nb_src0[369] = Bx0[385];  assign nb_src1[369] = Bx1[385];
assign nb_src0[370] = Bx0[386];  assign nb_src1[370] = Bx1[386];
assign nb_src0[371] = Bx0[387];  assign nb_src1[371] = Bx1[387];
assign nb_src0[372] = Bx0[388];  assign nb_src1[372] = Bx1[388];
assign nb_src0[373] = Bx0[389];  assign nb_src1[373] = Bx1[389];
assign nb_src0[374] = Bx0[390];  assign nb_src1[374] = Bx1[390];
assign nb_src0[375] = Bx0[391];  assign nb_src1[375] = Bx1[391];
assign nb_src0[376] = Bx0[392];  assign nb_src1[376] = Bx1[392];
assign nb_src0[377] = Bx0[393];  assign nb_src1[377] = Bx1[393];
assign nb_src0[378] = Bx0[394];  assign nb_src1[378] = Bx1[394];
assign nb_src0[379] = Bx0[395];  assign nb_src1[379] = Bx1[395];
assign nb_src0[380] = Bx0[396];  assign nb_src1[380] = Bx1[396];
assign nb_src0[381] = Bx0[397];  assign nb_src1[381] = Bx1[397];
assign nb_src0[382] = Bx0[398];  assign nb_src1[382] = Bx1[398];
assign nb_src0[383] = Bx0[399];  assign nb_src1[383] = Bx1[399];
assign nb_src0[64] = Bx0[0];  assign nb_src1[64] = Bx1[0];
assign nb_src0[65] = Bx0[1];  assign nb_src1[65] = Bx1[1];
assign nb_src0[66] = Bx0[2];  assign nb_src1[66] = Bx1[2];
assign nb_src0[67] = Bx0[3];  assign nb_src1[67] = Bx1[3];
assign nb_src0[68] = Bx0[4];  assign nb_src1[68] = Bx1[4];
assign nb_src0[69] = Bx0[5];  assign nb_src1[69] = Bx1[5];
assign nb_src0[70] = Bx0[6];  assign nb_src1[70] = Bx1[6];
assign nb_src0[71] = Bx0[7];  assign nb_src1[71] = Bx1[7];
assign nb_src0[72] = Bx0[8];  assign nb_src1[72] = Bx1[8];
assign nb_src0[73] = Bx0[9];  assign nb_src1[73] = Bx1[9];
assign nb_src0[74] = Bx0[10];  assign nb_src1[74] = Bx1[10];
assign nb_src0[75] = Bx0[11];  assign nb_src1[75] = Bx1[11];
assign nb_src0[76] = Bx0[12];  assign nb_src1[76] = Bx1[12];
assign nb_src0[77] = Bx0[13];  assign nb_src1[77] = Bx1[13];
assign nb_src0[78] = Bx0[14];  assign nb_src1[78] = Bx1[14];
assign nb_src0[79] = Bx0[15];  assign nb_src1[79] = Bx1[15];
assign nb_src0[144] = Bx0[80];  assign nb_src1[144] = Bx1[80];
assign nb_src0[145] = Bx0[81];  assign nb_src1[145] = Bx1[81];
assign nb_src0[146] = Bx0[82];  assign nb_src1[146] = Bx1[82];
assign nb_src0[147] = Bx0[83];  assign nb_src1[147] = Bx1[83];
assign nb_src0[148] = Bx0[84];  assign nb_src1[148] = Bx1[84];
assign nb_src0[149] = Bx0[85];  assign nb_src1[149] = Bx1[85];
assign nb_src0[150] = Bx0[86];  assign nb_src1[150] = Bx1[86];
assign nb_src0[151] = Bx0[87];  assign nb_src1[151] = Bx1[87];
assign nb_src0[152] = Bx0[88];  assign nb_src1[152] = Bx1[88];
assign nb_src0[153] = Bx0[89];  assign nb_src1[153] = Bx1[89];
assign nb_src0[154] = Bx0[90];  assign nb_src1[154] = Bx1[90];
assign nb_src0[155] = Bx0[91];  assign nb_src1[155] = Bx1[91];
assign nb_src0[156] = Bx0[92];  assign nb_src1[156] = Bx1[92];
assign nb_src0[157] = Bx0[93];  assign nb_src1[157] = Bx1[93];
assign nb_src0[158] = Bx0[94];  assign nb_src1[158] = Bx1[94];
assign nb_src0[159] = Bx0[95];  assign nb_src1[159] = Bx1[95];
assign nb_src0[224] = Bx0[160];  assign nb_src1[224] = Bx1[160];
assign nb_src0[225] = Bx0[161];  assign nb_src1[225] = Bx1[161];
assign nb_src0[226] = Bx0[162];  assign nb_src1[226] = Bx1[162];
assign nb_src0[227] = Bx0[163];  assign nb_src1[227] = Bx1[163];
assign nb_src0[228] = Bx0[164];  assign nb_src1[228] = Bx1[164];
assign nb_src0[229] = Bx0[165];  assign nb_src1[229] = Bx1[165];
assign nb_src0[230] = Bx0[166];  assign nb_src1[230] = Bx1[166];
assign nb_src0[231] = Bx0[167];  assign nb_src1[231] = Bx1[167];
assign nb_src0[232] = Bx0[168];  assign nb_src1[232] = Bx1[168];
assign nb_src0[233] = Bx0[169];  assign nb_src1[233] = Bx1[169];
assign nb_src0[234] = Bx0[170];  assign nb_src1[234] = Bx1[170];
assign nb_src0[235] = Bx0[171];  assign nb_src1[235] = Bx1[171];
assign nb_src0[236] = Bx0[172];  assign nb_src1[236] = Bx1[172];
assign nb_src0[237] = Bx0[173];  assign nb_src1[237] = Bx1[173];
assign nb_src0[238] = Bx0[174];  assign nb_src1[238] = Bx1[174];
assign nb_src0[239] = Bx0[175];  assign nb_src1[239] = Bx1[175];
assign nb_src0[304] = Bx0[240];  assign nb_src1[304] = Bx1[240];
assign nb_src0[305] = Bx0[241];  assign nb_src1[305] = Bx1[241];
assign nb_src0[306] = Bx0[242];  assign nb_src1[306] = Bx1[242];
assign nb_src0[307] = Bx0[243];  assign nb_src1[307] = Bx1[243];
assign nb_src0[308] = Bx0[244];  assign nb_src1[308] = Bx1[244];
assign nb_src0[309] = Bx0[245];  assign nb_src1[309] = Bx1[245];
assign nb_src0[310] = Bx0[246];  assign nb_src1[310] = Bx1[246];
assign nb_src0[311] = Bx0[247];  assign nb_src1[311] = Bx1[247];
assign nb_src0[312] = Bx0[248];  assign nb_src1[312] = Bx1[248];
assign nb_src0[313] = Bx0[249];  assign nb_src1[313] = Bx1[249];
assign nb_src0[314] = Bx0[250];  assign nb_src1[314] = Bx1[250];
assign nb_src0[315] = Bx0[251];  assign nb_src1[315] = Bx1[251];
assign nb_src0[316] = Bx0[252];  assign nb_src1[316] = Bx1[252];
assign nb_src0[317] = Bx0[253];  assign nb_src1[317] = Bx1[253];
assign nb_src0[318] = Bx0[254];  assign nb_src1[318] = Bx1[254];
assign nb_src0[319] = Bx0[255];  assign nb_src1[319] = Bx1[255];
assign nb_src0[384] = Bx0[320];  assign nb_src1[384] = Bx1[320];
assign nb_src0[385] = Bx0[321];  assign nb_src1[385] = Bx1[321];
assign nb_src0[386] = Bx0[322];  assign nb_src1[386] = Bx1[322];
assign nb_src0[387] = Bx0[323];  assign nb_src1[387] = Bx1[323];
assign nb_src0[388] = Bx0[324];  assign nb_src1[388] = Bx1[324];
assign nb_src0[389] = Bx0[325];  assign nb_src1[389] = Bx1[325];
assign nb_src0[390] = Bx0[326];  assign nb_src1[390] = Bx1[326];
assign nb_src0[391] = Bx0[327];  assign nb_src1[391] = Bx1[327];
assign nb_src0[392] = Bx0[328];  assign nb_src1[392] = Bx1[328];
assign nb_src0[393] = Bx0[329];  assign nb_src1[393] = Bx1[329];
assign nb_src0[394] = Bx0[330];  assign nb_src1[394] = Bx1[330];
assign nb_src0[395] = Bx0[331];  assign nb_src1[395] = Bx1[331];
assign nb_src0[396] = Bx0[332];  assign nb_src1[396] = Bx1[332];
assign nb_src0[397] = Bx0[333];  assign nb_src1[397] = Bx1[333];
assign nb_src0[398] = Bx0[334];  assign nb_src1[398] = Bx1[334];
assign nb_src0[399] = Bx0[335];  assign nb_src1[399] = Bx1[335];

MSKand_opini2_d2 u_chi_0 (
    .ina({nb_d1[0], nb_d0[0]}), .inb({Bx1[32], Bx0[32]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({w_chi1[0], w_chi0[0]}));
MSKand_opini2_d2 u_chi_1 (  // BUG UNDER TEST: reuses u_chi_0's randomness
    .ina({nb_d1[1], nb_d0[1]}), .inb({Bx1[33], Bx0[33]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({w_chi1[1], w_chi0[1]}));
MSKand_opini2_d2 u_chi_2 (
    .ina({nb_d1[2], nb_d0[2]}), .inb({Bx1[34], Bx0[34]}),
    .rnd(r[2]), .s(s[2]), .clk(clk), .out({w_chi1[2], w_chi0[2]}));
MSKand_opini2_d2 u_chi_3 (
    .ina({nb_d1[3], nb_d0[3]}), .inb({Bx1[35], Bx0[35]}),
    .rnd(r[3]), .s(s[3]), .clk(clk), .out({w_chi1[3], w_chi0[3]}));
MSKand_opini2_d2 u_chi_4 (
    .ina({nb_d1[4], nb_d0[4]}), .inb({Bx1[36], Bx0[36]}),
    .rnd(r[4]), .s(s[4]), .clk(clk), .out({w_chi1[4], w_chi0[4]}));
MSKand_opini2_d2 u_chi_5 (
    .ina({nb_d1[5], nb_d0[5]}), .inb({Bx1[37], Bx0[37]}),
    .rnd(r[5]), .s(s[5]), .clk(clk), .out({w_chi1[5], w_chi0[5]}));
MSKand_opini2_d2 u_chi_6 (
    .ina({nb_d1[6], nb_d0[6]}), .inb({Bx1[38], Bx0[38]}),
    .rnd(r[6]), .s(s[6]), .clk(clk), .out({w_chi1[6], w_chi0[6]}));
MSKand_opini2_d2 u_chi_7 (
    .ina({nb_d1[7], nb_d0[7]}), .inb({Bx1[39], Bx0[39]}),
    .rnd(r[7]), .s(s[7]), .clk(clk), .out({w_chi1[7], w_chi0[7]}));
MSKand_opini2_d2 u_chi_8 (
    .ina({nb_d1[8], nb_d0[8]}), .inb({Bx1[40], Bx0[40]}),
    .rnd(r[8]), .s(s[8]), .clk(clk), .out({w_chi1[8], w_chi0[8]}));
MSKand_opini2_d2 u_chi_9 (
    .ina({nb_d1[9], nb_d0[9]}), .inb({Bx1[41], Bx0[41]}),
    .rnd(r[9]), .s(s[9]), .clk(clk), .out({w_chi1[9], w_chi0[9]}));
MSKand_opini2_d2 u_chi_10 (
    .ina({nb_d1[10], nb_d0[10]}), .inb({Bx1[42], Bx0[42]}),
    .rnd(r[10]), .s(s[10]), .clk(clk), .out({w_chi1[10], w_chi0[10]}));
MSKand_opini2_d2 u_chi_11 (
    .ina({nb_d1[11], nb_d0[11]}), .inb({Bx1[43], Bx0[43]}),
    .rnd(r[11]), .s(s[11]), .clk(clk), .out({w_chi1[11], w_chi0[11]}));
MSKand_opini2_d2 u_chi_12 (
    .ina({nb_d1[12], nb_d0[12]}), .inb({Bx1[44], Bx0[44]}),
    .rnd(r[12]), .s(s[12]), .clk(clk), .out({w_chi1[12], w_chi0[12]}));
MSKand_opini2_d2 u_chi_13 (
    .ina({nb_d1[13], nb_d0[13]}), .inb({Bx1[45], Bx0[45]}),
    .rnd(r[13]), .s(s[13]), .clk(clk), .out({w_chi1[13], w_chi0[13]}));
MSKand_opini2_d2 u_chi_14 (
    .ina({nb_d1[14], nb_d0[14]}), .inb({Bx1[46], Bx0[46]}),
    .rnd(r[14]), .s(s[14]), .clk(clk), .out({w_chi1[14], w_chi0[14]}));
MSKand_opini2_d2 u_chi_15 (
    .ina({nb_d1[15], nb_d0[15]}), .inb({Bx1[47], Bx0[47]}),
    .rnd(r[15]), .s(s[15]), .clk(clk), .out({w_chi1[15], w_chi0[15]}));
MSKand_opini2_d2 u_chi_80 (
    .ina({nb_d1[80], nb_d0[80]}), .inb({Bx1[112], Bx0[112]}),
    .rnd(r[80]), .s(s[80]), .clk(clk), .out({w_chi1[80], w_chi0[80]}));
MSKand_opini2_d2 u_chi_81 (
    .ina({nb_d1[81], nb_d0[81]}), .inb({Bx1[113], Bx0[113]}),
    .rnd(r[81]), .s(s[81]), .clk(clk), .out({w_chi1[81], w_chi0[81]}));
MSKand_opini2_d2 u_chi_82 (
    .ina({nb_d1[82], nb_d0[82]}), .inb({Bx1[114], Bx0[114]}),
    .rnd(r[82]), .s(s[82]), .clk(clk), .out({w_chi1[82], w_chi0[82]}));
MSKand_opini2_d2 u_chi_83 (
    .ina({nb_d1[83], nb_d0[83]}), .inb({Bx1[115], Bx0[115]}),
    .rnd(r[83]), .s(s[83]), .clk(clk), .out({w_chi1[83], w_chi0[83]}));
MSKand_opini2_d2 u_chi_84 (
    .ina({nb_d1[84], nb_d0[84]}), .inb({Bx1[116], Bx0[116]}),
    .rnd(r[84]), .s(s[84]), .clk(clk), .out({w_chi1[84], w_chi0[84]}));
MSKand_opini2_d2 u_chi_85 (
    .ina({nb_d1[85], nb_d0[85]}), .inb({Bx1[117], Bx0[117]}),
    .rnd(r[85]), .s(s[85]), .clk(clk), .out({w_chi1[85], w_chi0[85]}));
MSKand_opini2_d2 u_chi_86 (
    .ina({nb_d1[86], nb_d0[86]}), .inb({Bx1[118], Bx0[118]}),
    .rnd(r[86]), .s(s[86]), .clk(clk), .out({w_chi1[86], w_chi0[86]}));
MSKand_opini2_d2 u_chi_87 (
    .ina({nb_d1[87], nb_d0[87]}), .inb({Bx1[119], Bx0[119]}),
    .rnd(r[87]), .s(s[87]), .clk(clk), .out({w_chi1[87], w_chi0[87]}));
MSKand_opini2_d2 u_chi_88 (
    .ina({nb_d1[88], nb_d0[88]}), .inb({Bx1[120], Bx0[120]}),
    .rnd(r[88]), .s(s[88]), .clk(clk), .out({w_chi1[88], w_chi0[88]}));
MSKand_opini2_d2 u_chi_89 (
    .ina({nb_d1[89], nb_d0[89]}), .inb({Bx1[121], Bx0[121]}),
    .rnd(r[89]), .s(s[89]), .clk(clk), .out({w_chi1[89], w_chi0[89]}));
MSKand_opini2_d2 u_chi_90 (
    .ina({nb_d1[90], nb_d0[90]}), .inb({Bx1[122], Bx0[122]}),
    .rnd(r[90]), .s(s[90]), .clk(clk), .out({w_chi1[90], w_chi0[90]}));
MSKand_opini2_d2 u_chi_91 (
    .ina({nb_d1[91], nb_d0[91]}), .inb({Bx1[123], Bx0[123]}),
    .rnd(r[91]), .s(s[91]), .clk(clk), .out({w_chi1[91], w_chi0[91]}));
MSKand_opini2_d2 u_chi_92 (
    .ina({nb_d1[92], nb_d0[92]}), .inb({Bx1[124], Bx0[124]}),
    .rnd(r[92]), .s(s[92]), .clk(clk), .out({w_chi1[92], w_chi0[92]}));
MSKand_opini2_d2 u_chi_93 (
    .ina({nb_d1[93], nb_d0[93]}), .inb({Bx1[125], Bx0[125]}),
    .rnd(r[93]), .s(s[93]), .clk(clk), .out({w_chi1[93], w_chi0[93]}));
MSKand_opini2_d2 u_chi_94 (
    .ina({nb_d1[94], nb_d0[94]}), .inb({Bx1[126], Bx0[126]}),
    .rnd(r[94]), .s(s[94]), .clk(clk), .out({w_chi1[94], w_chi0[94]}));
MSKand_opini2_d2 u_chi_95 (
    .ina({nb_d1[95], nb_d0[95]}), .inb({Bx1[127], Bx0[127]}),
    .rnd(r[95]), .s(s[95]), .clk(clk), .out({w_chi1[95], w_chi0[95]}));
MSKand_opini2_d2 u_chi_160 (
    .ina({nb_d1[160], nb_d0[160]}), .inb({Bx1[192], Bx0[192]}),
    .rnd(r[160]), .s(s[160]), .clk(clk), .out({w_chi1[160], w_chi0[160]}));
MSKand_opini2_d2 u_chi_161 (
    .ina({nb_d1[161], nb_d0[161]}), .inb({Bx1[193], Bx0[193]}),
    .rnd(r[161]), .s(s[161]), .clk(clk), .out({w_chi1[161], w_chi0[161]}));
MSKand_opini2_d2 u_chi_162 (
    .ina({nb_d1[162], nb_d0[162]}), .inb({Bx1[194], Bx0[194]}),
    .rnd(r[162]), .s(s[162]), .clk(clk), .out({w_chi1[162], w_chi0[162]}));
MSKand_opini2_d2 u_chi_163 (
    .ina({nb_d1[163], nb_d0[163]}), .inb({Bx1[195], Bx0[195]}),
    .rnd(r[163]), .s(s[163]), .clk(clk), .out({w_chi1[163], w_chi0[163]}));
MSKand_opini2_d2 u_chi_164 (
    .ina({nb_d1[164], nb_d0[164]}), .inb({Bx1[196], Bx0[196]}),
    .rnd(r[164]), .s(s[164]), .clk(clk), .out({w_chi1[164], w_chi0[164]}));
MSKand_opini2_d2 u_chi_165 (
    .ina({nb_d1[165], nb_d0[165]}), .inb({Bx1[197], Bx0[197]}),
    .rnd(r[165]), .s(s[165]), .clk(clk), .out({w_chi1[165], w_chi0[165]}));
MSKand_opini2_d2 u_chi_166 (
    .ina({nb_d1[166], nb_d0[166]}), .inb({Bx1[198], Bx0[198]}),
    .rnd(r[166]), .s(s[166]), .clk(clk), .out({w_chi1[166], w_chi0[166]}));
MSKand_opini2_d2 u_chi_167 (
    .ina({nb_d1[167], nb_d0[167]}), .inb({Bx1[199], Bx0[199]}),
    .rnd(r[167]), .s(s[167]), .clk(clk), .out({w_chi1[167], w_chi0[167]}));
MSKand_opini2_d2 u_chi_168 (
    .ina({nb_d1[168], nb_d0[168]}), .inb({Bx1[200], Bx0[200]}),
    .rnd(r[168]), .s(s[168]), .clk(clk), .out({w_chi1[168], w_chi0[168]}));
MSKand_opini2_d2 u_chi_169 (
    .ina({nb_d1[169], nb_d0[169]}), .inb({Bx1[201], Bx0[201]}),
    .rnd(r[169]), .s(s[169]), .clk(clk), .out({w_chi1[169], w_chi0[169]}));
MSKand_opini2_d2 u_chi_170 (
    .ina({nb_d1[170], nb_d0[170]}), .inb({Bx1[202], Bx0[202]}),
    .rnd(r[170]), .s(s[170]), .clk(clk), .out({w_chi1[170], w_chi0[170]}));
MSKand_opini2_d2 u_chi_171 (
    .ina({nb_d1[171], nb_d0[171]}), .inb({Bx1[203], Bx0[203]}),
    .rnd(r[171]), .s(s[171]), .clk(clk), .out({w_chi1[171], w_chi0[171]}));
MSKand_opini2_d2 u_chi_172 (
    .ina({nb_d1[172], nb_d0[172]}), .inb({Bx1[204], Bx0[204]}),
    .rnd(r[172]), .s(s[172]), .clk(clk), .out({w_chi1[172], w_chi0[172]}));
MSKand_opini2_d2 u_chi_173 (
    .ina({nb_d1[173], nb_d0[173]}), .inb({Bx1[205], Bx0[205]}),
    .rnd(r[173]), .s(s[173]), .clk(clk), .out({w_chi1[173], w_chi0[173]}));
MSKand_opini2_d2 u_chi_174 (
    .ina({nb_d1[174], nb_d0[174]}), .inb({Bx1[206], Bx0[206]}),
    .rnd(r[174]), .s(s[174]), .clk(clk), .out({w_chi1[174], w_chi0[174]}));
MSKand_opini2_d2 u_chi_175 (
    .ina({nb_d1[175], nb_d0[175]}), .inb({Bx1[207], Bx0[207]}),
    .rnd(r[175]), .s(s[175]), .clk(clk), .out({w_chi1[175], w_chi0[175]}));
MSKand_opini2_d2 u_chi_240 (
    .ina({nb_d1[240], nb_d0[240]}), .inb({Bx1[272], Bx0[272]}),
    .rnd(r[240]), .s(s[240]), .clk(clk), .out({w_chi1[240], w_chi0[240]}));
MSKand_opini2_d2 u_chi_241 (
    .ina({nb_d1[241], nb_d0[241]}), .inb({Bx1[273], Bx0[273]}),
    .rnd(r[241]), .s(s[241]), .clk(clk), .out({w_chi1[241], w_chi0[241]}));
MSKand_opini2_d2 u_chi_242 (
    .ina({nb_d1[242], nb_d0[242]}), .inb({Bx1[274], Bx0[274]}),
    .rnd(r[242]), .s(s[242]), .clk(clk), .out({w_chi1[242], w_chi0[242]}));
MSKand_opini2_d2 u_chi_243 (
    .ina({nb_d1[243], nb_d0[243]}), .inb({Bx1[275], Bx0[275]}),
    .rnd(r[243]), .s(s[243]), .clk(clk), .out({w_chi1[243], w_chi0[243]}));
MSKand_opini2_d2 u_chi_244 (
    .ina({nb_d1[244], nb_d0[244]}), .inb({Bx1[276], Bx0[276]}),
    .rnd(r[244]), .s(s[244]), .clk(clk), .out({w_chi1[244], w_chi0[244]}));
MSKand_opini2_d2 u_chi_245 (
    .ina({nb_d1[245], nb_d0[245]}), .inb({Bx1[277], Bx0[277]}),
    .rnd(r[245]), .s(s[245]), .clk(clk), .out({w_chi1[245], w_chi0[245]}));
MSKand_opini2_d2 u_chi_246 (
    .ina({nb_d1[246], nb_d0[246]}), .inb({Bx1[278], Bx0[278]}),
    .rnd(r[246]), .s(s[246]), .clk(clk), .out({w_chi1[246], w_chi0[246]}));
MSKand_opini2_d2 u_chi_247 (
    .ina({nb_d1[247], nb_d0[247]}), .inb({Bx1[279], Bx0[279]}),
    .rnd(r[247]), .s(s[247]), .clk(clk), .out({w_chi1[247], w_chi0[247]}));
MSKand_opini2_d2 u_chi_248 (
    .ina({nb_d1[248], nb_d0[248]}), .inb({Bx1[280], Bx0[280]}),
    .rnd(r[248]), .s(s[248]), .clk(clk), .out({w_chi1[248], w_chi0[248]}));
MSKand_opini2_d2 u_chi_249 (
    .ina({nb_d1[249], nb_d0[249]}), .inb({Bx1[281], Bx0[281]}),
    .rnd(r[249]), .s(s[249]), .clk(clk), .out({w_chi1[249], w_chi0[249]}));
MSKand_opini2_d2 u_chi_250 (
    .ina({nb_d1[250], nb_d0[250]}), .inb({Bx1[282], Bx0[282]}),
    .rnd(r[250]), .s(s[250]), .clk(clk), .out({w_chi1[250], w_chi0[250]}));
MSKand_opini2_d2 u_chi_251 (
    .ina({nb_d1[251], nb_d0[251]}), .inb({Bx1[283], Bx0[283]}),
    .rnd(r[251]), .s(s[251]), .clk(clk), .out({w_chi1[251], w_chi0[251]}));
MSKand_opini2_d2 u_chi_252 (
    .ina({nb_d1[252], nb_d0[252]}), .inb({Bx1[284], Bx0[284]}),
    .rnd(r[252]), .s(s[252]), .clk(clk), .out({w_chi1[252], w_chi0[252]}));
MSKand_opini2_d2 u_chi_253 (
    .ina({nb_d1[253], nb_d0[253]}), .inb({Bx1[285], Bx0[285]}),
    .rnd(r[253]), .s(s[253]), .clk(clk), .out({w_chi1[253], w_chi0[253]}));
MSKand_opini2_d2 u_chi_254 (
    .ina({nb_d1[254], nb_d0[254]}), .inb({Bx1[286], Bx0[286]}),
    .rnd(r[254]), .s(s[254]), .clk(clk), .out({w_chi1[254], w_chi0[254]}));
MSKand_opini2_d2 u_chi_255 (
    .ina({nb_d1[255], nb_d0[255]}), .inb({Bx1[287], Bx0[287]}),
    .rnd(r[255]), .s(s[255]), .clk(clk), .out({w_chi1[255], w_chi0[255]}));
MSKand_opini2_d2 u_chi_320 (
    .ina({nb_d1[320], nb_d0[320]}), .inb({Bx1[352], Bx0[352]}),
    .rnd(r[320]), .s(s[320]), .clk(clk), .out({w_chi1[320], w_chi0[320]}));
MSKand_opini2_d2 u_chi_321 (
    .ina({nb_d1[321], nb_d0[321]}), .inb({Bx1[353], Bx0[353]}),
    .rnd(r[321]), .s(s[321]), .clk(clk), .out({w_chi1[321], w_chi0[321]}));
MSKand_opini2_d2 u_chi_322 (
    .ina({nb_d1[322], nb_d0[322]}), .inb({Bx1[354], Bx0[354]}),
    .rnd(r[322]), .s(s[322]), .clk(clk), .out({w_chi1[322], w_chi0[322]}));
MSKand_opini2_d2 u_chi_323 (
    .ina({nb_d1[323], nb_d0[323]}), .inb({Bx1[355], Bx0[355]}),
    .rnd(r[323]), .s(s[323]), .clk(clk), .out({w_chi1[323], w_chi0[323]}));
MSKand_opini2_d2 u_chi_324 (
    .ina({nb_d1[324], nb_d0[324]}), .inb({Bx1[356], Bx0[356]}),
    .rnd(r[324]), .s(s[324]), .clk(clk), .out({w_chi1[324], w_chi0[324]}));
MSKand_opini2_d2 u_chi_325 (
    .ina({nb_d1[325], nb_d0[325]}), .inb({Bx1[357], Bx0[357]}),
    .rnd(r[325]), .s(s[325]), .clk(clk), .out({w_chi1[325], w_chi0[325]}));
MSKand_opini2_d2 u_chi_326 (
    .ina({nb_d1[326], nb_d0[326]}), .inb({Bx1[358], Bx0[358]}),
    .rnd(r[326]), .s(s[326]), .clk(clk), .out({w_chi1[326], w_chi0[326]}));
MSKand_opini2_d2 u_chi_327 (
    .ina({nb_d1[327], nb_d0[327]}), .inb({Bx1[359], Bx0[359]}),
    .rnd(r[327]), .s(s[327]), .clk(clk), .out({w_chi1[327], w_chi0[327]}));
MSKand_opini2_d2 u_chi_328 (
    .ina({nb_d1[328], nb_d0[328]}), .inb({Bx1[360], Bx0[360]}),
    .rnd(r[328]), .s(s[328]), .clk(clk), .out({w_chi1[328], w_chi0[328]}));
MSKand_opini2_d2 u_chi_329 (
    .ina({nb_d1[329], nb_d0[329]}), .inb({Bx1[361], Bx0[361]}),
    .rnd(r[329]), .s(s[329]), .clk(clk), .out({w_chi1[329], w_chi0[329]}));
MSKand_opini2_d2 u_chi_330 (
    .ina({nb_d1[330], nb_d0[330]}), .inb({Bx1[362], Bx0[362]}),
    .rnd(r[330]), .s(s[330]), .clk(clk), .out({w_chi1[330], w_chi0[330]}));
MSKand_opini2_d2 u_chi_331 (
    .ina({nb_d1[331], nb_d0[331]}), .inb({Bx1[363], Bx0[363]}),
    .rnd(r[331]), .s(s[331]), .clk(clk), .out({w_chi1[331], w_chi0[331]}));
MSKand_opini2_d2 u_chi_332 (
    .ina({nb_d1[332], nb_d0[332]}), .inb({Bx1[364], Bx0[364]}),
    .rnd(r[332]), .s(s[332]), .clk(clk), .out({w_chi1[332], w_chi0[332]}));
MSKand_opini2_d2 u_chi_333 (
    .ina({nb_d1[333], nb_d0[333]}), .inb({Bx1[365], Bx0[365]}),
    .rnd(r[333]), .s(s[333]), .clk(clk), .out({w_chi1[333], w_chi0[333]}));
MSKand_opini2_d2 u_chi_334 (
    .ina({nb_d1[334], nb_d0[334]}), .inb({Bx1[366], Bx0[366]}),
    .rnd(r[334]), .s(s[334]), .clk(clk), .out({w_chi1[334], w_chi0[334]}));
MSKand_opini2_d2 u_chi_335 (
    .ina({nb_d1[335], nb_d0[335]}), .inb({Bx1[367], Bx0[367]}),
    .rnd(r[335]), .s(s[335]), .clk(clk), .out({w_chi1[335], w_chi0[335]}));
MSKand_opini2_d2 u_chi_16 (
    .ina({nb_d1[16], nb_d0[16]}), .inb({Bx1[48], Bx0[48]}),
    .rnd(r[16]), .s(s[16]), .clk(clk), .out({w_chi1[16], w_chi0[16]}));
MSKand_opini2_d2 u_chi_17 (
    .ina({nb_d1[17], nb_d0[17]}), .inb({Bx1[49], Bx0[49]}),
    .rnd(r[17]), .s(s[17]), .clk(clk), .out({w_chi1[17], w_chi0[17]}));
MSKand_opini2_d2 u_chi_18 (
    .ina({nb_d1[18], nb_d0[18]}), .inb({Bx1[50], Bx0[50]}),
    .rnd(r[18]), .s(s[18]), .clk(clk), .out({w_chi1[18], w_chi0[18]}));
MSKand_opini2_d2 u_chi_19 (
    .ina({nb_d1[19], nb_d0[19]}), .inb({Bx1[51], Bx0[51]}),
    .rnd(r[19]), .s(s[19]), .clk(clk), .out({w_chi1[19], w_chi0[19]}));
MSKand_opini2_d2 u_chi_20 (
    .ina({nb_d1[20], nb_d0[20]}), .inb({Bx1[52], Bx0[52]}),
    .rnd(r[20]), .s(s[20]), .clk(clk), .out({w_chi1[20], w_chi0[20]}));
MSKand_opini2_d2 u_chi_21 (
    .ina({nb_d1[21], nb_d0[21]}), .inb({Bx1[53], Bx0[53]}),
    .rnd(r[21]), .s(s[21]), .clk(clk), .out({w_chi1[21], w_chi0[21]}));
MSKand_opini2_d2 u_chi_22 (
    .ina({nb_d1[22], nb_d0[22]}), .inb({Bx1[54], Bx0[54]}),
    .rnd(r[22]), .s(s[22]), .clk(clk), .out({w_chi1[22], w_chi0[22]}));
MSKand_opini2_d2 u_chi_23 (
    .ina({nb_d1[23], nb_d0[23]}), .inb({Bx1[55], Bx0[55]}),
    .rnd(r[23]), .s(s[23]), .clk(clk), .out({w_chi1[23], w_chi0[23]}));
MSKand_opini2_d2 u_chi_24 (
    .ina({nb_d1[24], nb_d0[24]}), .inb({Bx1[56], Bx0[56]}),
    .rnd(r[24]), .s(s[24]), .clk(clk), .out({w_chi1[24], w_chi0[24]}));
MSKand_opini2_d2 u_chi_25 (
    .ina({nb_d1[25], nb_d0[25]}), .inb({Bx1[57], Bx0[57]}),
    .rnd(r[25]), .s(s[25]), .clk(clk), .out({w_chi1[25], w_chi0[25]}));
MSKand_opini2_d2 u_chi_26 (
    .ina({nb_d1[26], nb_d0[26]}), .inb({Bx1[58], Bx0[58]}),
    .rnd(r[26]), .s(s[26]), .clk(clk), .out({w_chi1[26], w_chi0[26]}));
MSKand_opini2_d2 u_chi_27 (
    .ina({nb_d1[27], nb_d0[27]}), .inb({Bx1[59], Bx0[59]}),
    .rnd(r[27]), .s(s[27]), .clk(clk), .out({w_chi1[27], w_chi0[27]}));
MSKand_opini2_d2 u_chi_28 (
    .ina({nb_d1[28], nb_d0[28]}), .inb({Bx1[60], Bx0[60]}),
    .rnd(r[28]), .s(s[28]), .clk(clk), .out({w_chi1[28], w_chi0[28]}));
MSKand_opini2_d2 u_chi_29 (
    .ina({nb_d1[29], nb_d0[29]}), .inb({Bx1[61], Bx0[61]}),
    .rnd(r[29]), .s(s[29]), .clk(clk), .out({w_chi1[29], w_chi0[29]}));
MSKand_opini2_d2 u_chi_30 (
    .ina({nb_d1[30], nb_d0[30]}), .inb({Bx1[62], Bx0[62]}),
    .rnd(r[30]), .s(s[30]), .clk(clk), .out({w_chi1[30], w_chi0[30]}));
MSKand_opini2_d2 u_chi_31 (
    .ina({nb_d1[31], nb_d0[31]}), .inb({Bx1[63], Bx0[63]}),
    .rnd(r[31]), .s(s[31]), .clk(clk), .out({w_chi1[31], w_chi0[31]}));
MSKand_opini2_d2 u_chi_96 (
    .ina({nb_d1[96], nb_d0[96]}), .inb({Bx1[128], Bx0[128]}),
    .rnd(r[96]), .s(s[96]), .clk(clk), .out({w_chi1[96], w_chi0[96]}));
MSKand_opini2_d2 u_chi_97 (
    .ina({nb_d1[97], nb_d0[97]}), .inb({Bx1[129], Bx0[129]}),
    .rnd(r[97]), .s(s[97]), .clk(clk), .out({w_chi1[97], w_chi0[97]}));
MSKand_opini2_d2 u_chi_98 (
    .ina({nb_d1[98], nb_d0[98]}), .inb({Bx1[130], Bx0[130]}),
    .rnd(r[98]), .s(s[98]), .clk(clk), .out({w_chi1[98], w_chi0[98]}));
MSKand_opini2_d2 u_chi_99 (
    .ina({nb_d1[99], nb_d0[99]}), .inb({Bx1[131], Bx0[131]}),
    .rnd(r[99]), .s(s[99]), .clk(clk), .out({w_chi1[99], w_chi0[99]}));
MSKand_opini2_d2 u_chi_100 (
    .ina({nb_d1[100], nb_d0[100]}), .inb({Bx1[132], Bx0[132]}),
    .rnd(r[100]), .s(s[100]), .clk(clk), .out({w_chi1[100], w_chi0[100]}));
MSKand_opini2_d2 u_chi_101 (
    .ina({nb_d1[101], nb_d0[101]}), .inb({Bx1[133], Bx0[133]}),
    .rnd(r[101]), .s(s[101]), .clk(clk), .out({w_chi1[101], w_chi0[101]}));
MSKand_opini2_d2 u_chi_102 (
    .ina({nb_d1[102], nb_d0[102]}), .inb({Bx1[134], Bx0[134]}),
    .rnd(r[102]), .s(s[102]), .clk(clk), .out({w_chi1[102], w_chi0[102]}));
MSKand_opini2_d2 u_chi_103 (
    .ina({nb_d1[103], nb_d0[103]}), .inb({Bx1[135], Bx0[135]}),
    .rnd(r[103]), .s(s[103]), .clk(clk), .out({w_chi1[103], w_chi0[103]}));
MSKand_opini2_d2 u_chi_104 (
    .ina({nb_d1[104], nb_d0[104]}), .inb({Bx1[136], Bx0[136]}),
    .rnd(r[104]), .s(s[104]), .clk(clk), .out({w_chi1[104], w_chi0[104]}));
MSKand_opini2_d2 u_chi_105 (
    .ina({nb_d1[105], nb_d0[105]}), .inb({Bx1[137], Bx0[137]}),
    .rnd(r[105]), .s(s[105]), .clk(clk), .out({w_chi1[105], w_chi0[105]}));
MSKand_opini2_d2 u_chi_106 (
    .ina({nb_d1[106], nb_d0[106]}), .inb({Bx1[138], Bx0[138]}),
    .rnd(r[106]), .s(s[106]), .clk(clk), .out({w_chi1[106], w_chi0[106]}));
MSKand_opini2_d2 u_chi_107 (
    .ina({nb_d1[107], nb_d0[107]}), .inb({Bx1[139], Bx0[139]}),
    .rnd(r[107]), .s(s[107]), .clk(clk), .out({w_chi1[107], w_chi0[107]}));
MSKand_opini2_d2 u_chi_108 (
    .ina({nb_d1[108], nb_d0[108]}), .inb({Bx1[140], Bx0[140]}),
    .rnd(r[108]), .s(s[108]), .clk(clk), .out({w_chi1[108], w_chi0[108]}));
MSKand_opini2_d2 u_chi_109 (
    .ina({nb_d1[109], nb_d0[109]}), .inb({Bx1[141], Bx0[141]}),
    .rnd(r[109]), .s(s[109]), .clk(clk), .out({w_chi1[109], w_chi0[109]}));
MSKand_opini2_d2 u_chi_110 (
    .ina({nb_d1[110], nb_d0[110]}), .inb({Bx1[142], Bx0[142]}),
    .rnd(r[110]), .s(s[110]), .clk(clk), .out({w_chi1[110], w_chi0[110]}));
MSKand_opini2_d2 u_chi_111 (
    .ina({nb_d1[111], nb_d0[111]}), .inb({Bx1[143], Bx0[143]}),
    .rnd(r[111]), .s(s[111]), .clk(clk), .out({w_chi1[111], w_chi0[111]}));
MSKand_opini2_d2 u_chi_176 (
    .ina({nb_d1[176], nb_d0[176]}), .inb({Bx1[208], Bx0[208]}),
    .rnd(r[176]), .s(s[176]), .clk(clk), .out({w_chi1[176], w_chi0[176]}));
MSKand_opini2_d2 u_chi_177 (
    .ina({nb_d1[177], nb_d0[177]}), .inb({Bx1[209], Bx0[209]}),
    .rnd(r[177]), .s(s[177]), .clk(clk), .out({w_chi1[177], w_chi0[177]}));
MSKand_opini2_d2 u_chi_178 (
    .ina({nb_d1[178], nb_d0[178]}), .inb({Bx1[210], Bx0[210]}),
    .rnd(r[178]), .s(s[178]), .clk(clk), .out({w_chi1[178], w_chi0[178]}));
MSKand_opini2_d2 u_chi_179 (
    .ina({nb_d1[179], nb_d0[179]}), .inb({Bx1[211], Bx0[211]}),
    .rnd(r[179]), .s(s[179]), .clk(clk), .out({w_chi1[179], w_chi0[179]}));
MSKand_opini2_d2 u_chi_180 (
    .ina({nb_d1[180], nb_d0[180]}), .inb({Bx1[212], Bx0[212]}),
    .rnd(r[180]), .s(s[180]), .clk(clk), .out({w_chi1[180], w_chi0[180]}));
MSKand_opini2_d2 u_chi_181 (
    .ina({nb_d1[181], nb_d0[181]}), .inb({Bx1[213], Bx0[213]}),
    .rnd(r[181]), .s(s[181]), .clk(clk), .out({w_chi1[181], w_chi0[181]}));
MSKand_opini2_d2 u_chi_182 (
    .ina({nb_d1[182], nb_d0[182]}), .inb({Bx1[214], Bx0[214]}),
    .rnd(r[182]), .s(s[182]), .clk(clk), .out({w_chi1[182], w_chi0[182]}));
MSKand_opini2_d2 u_chi_183 (
    .ina({nb_d1[183], nb_d0[183]}), .inb({Bx1[215], Bx0[215]}),
    .rnd(r[183]), .s(s[183]), .clk(clk), .out({w_chi1[183], w_chi0[183]}));
MSKand_opini2_d2 u_chi_184 (
    .ina({nb_d1[184], nb_d0[184]}), .inb({Bx1[216], Bx0[216]}),
    .rnd(r[184]), .s(s[184]), .clk(clk), .out({w_chi1[184], w_chi0[184]}));
MSKand_opini2_d2 u_chi_185 (
    .ina({nb_d1[185], nb_d0[185]}), .inb({Bx1[217], Bx0[217]}),
    .rnd(r[185]), .s(s[185]), .clk(clk), .out({w_chi1[185], w_chi0[185]}));
MSKand_opini2_d2 u_chi_186 (
    .ina({nb_d1[186], nb_d0[186]}), .inb({Bx1[218], Bx0[218]}),
    .rnd(r[186]), .s(s[186]), .clk(clk), .out({w_chi1[186], w_chi0[186]}));
MSKand_opini2_d2 u_chi_187 (
    .ina({nb_d1[187], nb_d0[187]}), .inb({Bx1[219], Bx0[219]}),
    .rnd(r[187]), .s(s[187]), .clk(clk), .out({w_chi1[187], w_chi0[187]}));
MSKand_opini2_d2 u_chi_188 (
    .ina({nb_d1[188], nb_d0[188]}), .inb({Bx1[220], Bx0[220]}),
    .rnd(r[188]), .s(s[188]), .clk(clk), .out({w_chi1[188], w_chi0[188]}));
MSKand_opini2_d2 u_chi_189 (
    .ina({nb_d1[189], nb_d0[189]}), .inb({Bx1[221], Bx0[221]}),
    .rnd(r[189]), .s(s[189]), .clk(clk), .out({w_chi1[189], w_chi0[189]}));
MSKand_opini2_d2 u_chi_190 (
    .ina({nb_d1[190], nb_d0[190]}), .inb({Bx1[222], Bx0[222]}),
    .rnd(r[190]), .s(s[190]), .clk(clk), .out({w_chi1[190], w_chi0[190]}));
MSKand_opini2_d2 u_chi_191 (
    .ina({nb_d1[191], nb_d0[191]}), .inb({Bx1[223], Bx0[223]}),
    .rnd(r[191]), .s(s[191]), .clk(clk), .out({w_chi1[191], w_chi0[191]}));
MSKand_opini2_d2 u_chi_256 (
    .ina({nb_d1[256], nb_d0[256]}), .inb({Bx1[288], Bx0[288]}),
    .rnd(r[256]), .s(s[256]), .clk(clk), .out({w_chi1[256], w_chi0[256]}));
MSKand_opini2_d2 u_chi_257 (
    .ina({nb_d1[257], nb_d0[257]}), .inb({Bx1[289], Bx0[289]}),
    .rnd(r[257]), .s(s[257]), .clk(clk), .out({w_chi1[257], w_chi0[257]}));
MSKand_opini2_d2 u_chi_258 (
    .ina({nb_d1[258], nb_d0[258]}), .inb({Bx1[290], Bx0[290]}),
    .rnd(r[258]), .s(s[258]), .clk(clk), .out({w_chi1[258], w_chi0[258]}));
MSKand_opini2_d2 u_chi_259 (
    .ina({nb_d1[259], nb_d0[259]}), .inb({Bx1[291], Bx0[291]}),
    .rnd(r[259]), .s(s[259]), .clk(clk), .out({w_chi1[259], w_chi0[259]}));
MSKand_opini2_d2 u_chi_260 (
    .ina({nb_d1[260], nb_d0[260]}), .inb({Bx1[292], Bx0[292]}),
    .rnd(r[260]), .s(s[260]), .clk(clk), .out({w_chi1[260], w_chi0[260]}));
MSKand_opini2_d2 u_chi_261 (
    .ina({nb_d1[261], nb_d0[261]}), .inb({Bx1[293], Bx0[293]}),
    .rnd(r[261]), .s(s[261]), .clk(clk), .out({w_chi1[261], w_chi0[261]}));
MSKand_opini2_d2 u_chi_262 (
    .ina({nb_d1[262], nb_d0[262]}), .inb({Bx1[294], Bx0[294]}),
    .rnd(r[262]), .s(s[262]), .clk(clk), .out({w_chi1[262], w_chi0[262]}));
MSKand_opini2_d2 u_chi_263 (
    .ina({nb_d1[263], nb_d0[263]}), .inb({Bx1[295], Bx0[295]}),
    .rnd(r[263]), .s(s[263]), .clk(clk), .out({w_chi1[263], w_chi0[263]}));
MSKand_opini2_d2 u_chi_264 (
    .ina({nb_d1[264], nb_d0[264]}), .inb({Bx1[296], Bx0[296]}),
    .rnd(r[264]), .s(s[264]), .clk(clk), .out({w_chi1[264], w_chi0[264]}));
MSKand_opini2_d2 u_chi_265 (
    .ina({nb_d1[265], nb_d0[265]}), .inb({Bx1[297], Bx0[297]}),
    .rnd(r[265]), .s(s[265]), .clk(clk), .out({w_chi1[265], w_chi0[265]}));
MSKand_opini2_d2 u_chi_266 (
    .ina({nb_d1[266], nb_d0[266]}), .inb({Bx1[298], Bx0[298]}),
    .rnd(r[266]), .s(s[266]), .clk(clk), .out({w_chi1[266], w_chi0[266]}));
MSKand_opini2_d2 u_chi_267 (
    .ina({nb_d1[267], nb_d0[267]}), .inb({Bx1[299], Bx0[299]}),
    .rnd(r[267]), .s(s[267]), .clk(clk), .out({w_chi1[267], w_chi0[267]}));
MSKand_opini2_d2 u_chi_268 (
    .ina({nb_d1[268], nb_d0[268]}), .inb({Bx1[300], Bx0[300]}),
    .rnd(r[268]), .s(s[268]), .clk(clk), .out({w_chi1[268], w_chi0[268]}));
MSKand_opini2_d2 u_chi_269 (
    .ina({nb_d1[269], nb_d0[269]}), .inb({Bx1[301], Bx0[301]}),
    .rnd(r[269]), .s(s[269]), .clk(clk), .out({w_chi1[269], w_chi0[269]}));
MSKand_opini2_d2 u_chi_270 (
    .ina({nb_d1[270], nb_d0[270]}), .inb({Bx1[302], Bx0[302]}),
    .rnd(r[270]), .s(s[270]), .clk(clk), .out({w_chi1[270], w_chi0[270]}));
MSKand_opini2_d2 u_chi_271 (
    .ina({nb_d1[271], nb_d0[271]}), .inb({Bx1[303], Bx0[303]}),
    .rnd(r[271]), .s(s[271]), .clk(clk), .out({w_chi1[271], w_chi0[271]}));
MSKand_opini2_d2 u_chi_336 (
    .ina({nb_d1[336], nb_d0[336]}), .inb({Bx1[368], Bx0[368]}),
    .rnd(r[336]), .s(s[336]), .clk(clk), .out({w_chi1[336], w_chi0[336]}));
MSKand_opini2_d2 u_chi_337 (
    .ina({nb_d1[337], nb_d0[337]}), .inb({Bx1[369], Bx0[369]}),
    .rnd(r[337]), .s(s[337]), .clk(clk), .out({w_chi1[337], w_chi0[337]}));
MSKand_opini2_d2 u_chi_338 (
    .ina({nb_d1[338], nb_d0[338]}), .inb({Bx1[370], Bx0[370]}),
    .rnd(r[338]), .s(s[338]), .clk(clk), .out({w_chi1[338], w_chi0[338]}));
MSKand_opini2_d2 u_chi_339 (
    .ina({nb_d1[339], nb_d0[339]}), .inb({Bx1[371], Bx0[371]}),
    .rnd(r[339]), .s(s[339]), .clk(clk), .out({w_chi1[339], w_chi0[339]}));
MSKand_opini2_d2 u_chi_340 (
    .ina({nb_d1[340], nb_d0[340]}), .inb({Bx1[372], Bx0[372]}),
    .rnd(r[340]), .s(s[340]), .clk(clk), .out({w_chi1[340], w_chi0[340]}));
MSKand_opini2_d2 u_chi_341 (
    .ina({nb_d1[341], nb_d0[341]}), .inb({Bx1[373], Bx0[373]}),
    .rnd(r[341]), .s(s[341]), .clk(clk), .out({w_chi1[341], w_chi0[341]}));
MSKand_opini2_d2 u_chi_342 (
    .ina({nb_d1[342], nb_d0[342]}), .inb({Bx1[374], Bx0[374]}),
    .rnd(r[342]), .s(s[342]), .clk(clk), .out({w_chi1[342], w_chi0[342]}));
MSKand_opini2_d2 u_chi_343 (
    .ina({nb_d1[343], nb_d0[343]}), .inb({Bx1[375], Bx0[375]}),
    .rnd(r[343]), .s(s[343]), .clk(clk), .out({w_chi1[343], w_chi0[343]}));
MSKand_opini2_d2 u_chi_344 (
    .ina({nb_d1[344], nb_d0[344]}), .inb({Bx1[376], Bx0[376]}),
    .rnd(r[344]), .s(s[344]), .clk(clk), .out({w_chi1[344], w_chi0[344]}));
MSKand_opini2_d2 u_chi_345 (
    .ina({nb_d1[345], nb_d0[345]}), .inb({Bx1[377], Bx0[377]}),
    .rnd(r[345]), .s(s[345]), .clk(clk), .out({w_chi1[345], w_chi0[345]}));
MSKand_opini2_d2 u_chi_346 (
    .ina({nb_d1[346], nb_d0[346]}), .inb({Bx1[378], Bx0[378]}),
    .rnd(r[346]), .s(s[346]), .clk(clk), .out({w_chi1[346], w_chi0[346]}));
MSKand_opini2_d2 u_chi_347 (
    .ina({nb_d1[347], nb_d0[347]}), .inb({Bx1[379], Bx0[379]}),
    .rnd(r[347]), .s(s[347]), .clk(clk), .out({w_chi1[347], w_chi0[347]}));
MSKand_opini2_d2 u_chi_348 (
    .ina({nb_d1[348], nb_d0[348]}), .inb({Bx1[380], Bx0[380]}),
    .rnd(r[348]), .s(s[348]), .clk(clk), .out({w_chi1[348], w_chi0[348]}));
MSKand_opini2_d2 u_chi_349 (
    .ina({nb_d1[349], nb_d0[349]}), .inb({Bx1[381], Bx0[381]}),
    .rnd(r[349]), .s(s[349]), .clk(clk), .out({w_chi1[349], w_chi0[349]}));
MSKand_opini2_d2 u_chi_350 (
    .ina({nb_d1[350], nb_d0[350]}), .inb({Bx1[382], Bx0[382]}),
    .rnd(r[350]), .s(s[350]), .clk(clk), .out({w_chi1[350], w_chi0[350]}));
MSKand_opini2_d2 u_chi_351 (
    .ina({nb_d1[351], nb_d0[351]}), .inb({Bx1[383], Bx0[383]}),
    .rnd(r[351]), .s(s[351]), .clk(clk), .out({w_chi1[351], w_chi0[351]}));
MSKand_opini2_d2 u_chi_32 (
    .ina({nb_d1[32], nb_d0[32]}), .inb({Bx1[64], Bx0[64]}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({w_chi1[32], w_chi0[32]}));
MSKand_opini2_d2 u_chi_33 (
    .ina({nb_d1[33], nb_d0[33]}), .inb({Bx1[65], Bx0[65]}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({w_chi1[33], w_chi0[33]}));
MSKand_opini2_d2 u_chi_34 (
    .ina({nb_d1[34], nb_d0[34]}), .inb({Bx1[66], Bx0[66]}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({w_chi1[34], w_chi0[34]}));
MSKand_opini2_d2 u_chi_35 (
    .ina({nb_d1[35], nb_d0[35]}), .inb({Bx1[67], Bx0[67]}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({w_chi1[35], w_chi0[35]}));
MSKand_opini2_d2 u_chi_36 (
    .ina({nb_d1[36], nb_d0[36]}), .inb({Bx1[68], Bx0[68]}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({w_chi1[36], w_chi0[36]}));
MSKand_opini2_d2 u_chi_37 (
    .ina({nb_d1[37], nb_d0[37]}), .inb({Bx1[69], Bx0[69]}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({w_chi1[37], w_chi0[37]}));
MSKand_opini2_d2 u_chi_38 (
    .ina({nb_d1[38], nb_d0[38]}), .inb({Bx1[70], Bx0[70]}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({w_chi1[38], w_chi0[38]}));
MSKand_opini2_d2 u_chi_39 (
    .ina({nb_d1[39], nb_d0[39]}), .inb({Bx1[71], Bx0[71]}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({w_chi1[39], w_chi0[39]}));
MSKand_opini2_d2 u_chi_40 (
    .ina({nb_d1[40], nb_d0[40]}), .inb({Bx1[72], Bx0[72]}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({w_chi1[40], w_chi0[40]}));
MSKand_opini2_d2 u_chi_41 (
    .ina({nb_d1[41], nb_d0[41]}), .inb({Bx1[73], Bx0[73]}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({w_chi1[41], w_chi0[41]}));
MSKand_opini2_d2 u_chi_42 (
    .ina({nb_d1[42], nb_d0[42]}), .inb({Bx1[74], Bx0[74]}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({w_chi1[42], w_chi0[42]}));
MSKand_opini2_d2 u_chi_43 (
    .ina({nb_d1[43], nb_d0[43]}), .inb({Bx1[75], Bx0[75]}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({w_chi1[43], w_chi0[43]}));
MSKand_opini2_d2 u_chi_44 (
    .ina({nb_d1[44], nb_d0[44]}), .inb({Bx1[76], Bx0[76]}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({w_chi1[44], w_chi0[44]}));
MSKand_opini2_d2 u_chi_45 (
    .ina({nb_d1[45], nb_d0[45]}), .inb({Bx1[77], Bx0[77]}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({w_chi1[45], w_chi0[45]}));
MSKand_opini2_d2 u_chi_46 (
    .ina({nb_d1[46], nb_d0[46]}), .inb({Bx1[78], Bx0[78]}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({w_chi1[46], w_chi0[46]}));
MSKand_opini2_d2 u_chi_47 (
    .ina({nb_d1[47], nb_d0[47]}), .inb({Bx1[79], Bx0[79]}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({w_chi1[47], w_chi0[47]}));
MSKand_opini2_d2 u_chi_112 (
    .ina({nb_d1[112], nb_d0[112]}), .inb({Bx1[144], Bx0[144]}),
    .rnd(r[112]), .s(s[112]), .clk(clk), .out({w_chi1[112], w_chi0[112]}));
MSKand_opini2_d2 u_chi_113 (
    .ina({nb_d1[113], nb_d0[113]}), .inb({Bx1[145], Bx0[145]}),
    .rnd(r[113]), .s(s[113]), .clk(clk), .out({w_chi1[113], w_chi0[113]}));
MSKand_opini2_d2 u_chi_114 (
    .ina({nb_d1[114], nb_d0[114]}), .inb({Bx1[146], Bx0[146]}),
    .rnd(r[114]), .s(s[114]), .clk(clk), .out({w_chi1[114], w_chi0[114]}));
MSKand_opini2_d2 u_chi_115 (
    .ina({nb_d1[115], nb_d0[115]}), .inb({Bx1[147], Bx0[147]}),
    .rnd(r[115]), .s(s[115]), .clk(clk), .out({w_chi1[115], w_chi0[115]}));
MSKand_opini2_d2 u_chi_116 (
    .ina({nb_d1[116], nb_d0[116]}), .inb({Bx1[148], Bx0[148]}),
    .rnd(r[116]), .s(s[116]), .clk(clk), .out({w_chi1[116], w_chi0[116]}));
MSKand_opini2_d2 u_chi_117 (
    .ina({nb_d1[117], nb_d0[117]}), .inb({Bx1[149], Bx0[149]}),
    .rnd(r[117]), .s(s[117]), .clk(clk), .out({w_chi1[117], w_chi0[117]}));
MSKand_opini2_d2 u_chi_118 (
    .ina({nb_d1[118], nb_d0[118]}), .inb({Bx1[150], Bx0[150]}),
    .rnd(r[118]), .s(s[118]), .clk(clk), .out({w_chi1[118], w_chi0[118]}));
MSKand_opini2_d2 u_chi_119 (
    .ina({nb_d1[119], nb_d0[119]}), .inb({Bx1[151], Bx0[151]}),
    .rnd(r[119]), .s(s[119]), .clk(clk), .out({w_chi1[119], w_chi0[119]}));
MSKand_opini2_d2 u_chi_120 (
    .ina({nb_d1[120], nb_d0[120]}), .inb({Bx1[152], Bx0[152]}),
    .rnd(r[120]), .s(s[120]), .clk(clk), .out({w_chi1[120], w_chi0[120]}));
MSKand_opini2_d2 u_chi_121 (
    .ina({nb_d1[121], nb_d0[121]}), .inb({Bx1[153], Bx0[153]}),
    .rnd(r[121]), .s(s[121]), .clk(clk), .out({w_chi1[121], w_chi0[121]}));
MSKand_opini2_d2 u_chi_122 (
    .ina({nb_d1[122], nb_d0[122]}), .inb({Bx1[154], Bx0[154]}),
    .rnd(r[122]), .s(s[122]), .clk(clk), .out({w_chi1[122], w_chi0[122]}));
MSKand_opini2_d2 u_chi_123 (
    .ina({nb_d1[123], nb_d0[123]}), .inb({Bx1[155], Bx0[155]}),
    .rnd(r[123]), .s(s[123]), .clk(clk), .out({w_chi1[123], w_chi0[123]}));
MSKand_opini2_d2 u_chi_124 (
    .ina({nb_d1[124], nb_d0[124]}), .inb({Bx1[156], Bx0[156]}),
    .rnd(r[124]), .s(s[124]), .clk(clk), .out({w_chi1[124], w_chi0[124]}));
MSKand_opini2_d2 u_chi_125 (
    .ina({nb_d1[125], nb_d0[125]}), .inb({Bx1[157], Bx0[157]}),
    .rnd(r[125]), .s(s[125]), .clk(clk), .out({w_chi1[125], w_chi0[125]}));
MSKand_opini2_d2 u_chi_126 (
    .ina({nb_d1[126], nb_d0[126]}), .inb({Bx1[158], Bx0[158]}),
    .rnd(r[126]), .s(s[126]), .clk(clk), .out({w_chi1[126], w_chi0[126]}));
MSKand_opini2_d2 u_chi_127 (
    .ina({nb_d1[127], nb_d0[127]}), .inb({Bx1[159], Bx0[159]}),
    .rnd(r[127]), .s(s[127]), .clk(clk), .out({w_chi1[127], w_chi0[127]}));
MSKand_opini2_d2 u_chi_192 (
    .ina({nb_d1[192], nb_d0[192]}), .inb({Bx1[224], Bx0[224]}),
    .rnd(r[192]), .s(s[192]), .clk(clk), .out({w_chi1[192], w_chi0[192]}));
MSKand_opini2_d2 u_chi_193 (
    .ina({nb_d1[193], nb_d0[193]}), .inb({Bx1[225], Bx0[225]}),
    .rnd(r[193]), .s(s[193]), .clk(clk), .out({w_chi1[193], w_chi0[193]}));
MSKand_opini2_d2 u_chi_194 (
    .ina({nb_d1[194], nb_d0[194]}), .inb({Bx1[226], Bx0[226]}),
    .rnd(r[194]), .s(s[194]), .clk(clk), .out({w_chi1[194], w_chi0[194]}));
MSKand_opini2_d2 u_chi_195 (
    .ina({nb_d1[195], nb_d0[195]}), .inb({Bx1[227], Bx0[227]}),
    .rnd(r[195]), .s(s[195]), .clk(clk), .out({w_chi1[195], w_chi0[195]}));
MSKand_opini2_d2 u_chi_196 (
    .ina({nb_d1[196], nb_d0[196]}), .inb({Bx1[228], Bx0[228]}),
    .rnd(r[196]), .s(s[196]), .clk(clk), .out({w_chi1[196], w_chi0[196]}));
MSKand_opini2_d2 u_chi_197 (
    .ina({nb_d1[197], nb_d0[197]}), .inb({Bx1[229], Bx0[229]}),
    .rnd(r[197]), .s(s[197]), .clk(clk), .out({w_chi1[197], w_chi0[197]}));
MSKand_opini2_d2 u_chi_198 (
    .ina({nb_d1[198], nb_d0[198]}), .inb({Bx1[230], Bx0[230]}),
    .rnd(r[198]), .s(s[198]), .clk(clk), .out({w_chi1[198], w_chi0[198]}));
MSKand_opini2_d2 u_chi_199 (
    .ina({nb_d1[199], nb_d0[199]}), .inb({Bx1[231], Bx0[231]}),
    .rnd(r[199]), .s(s[199]), .clk(clk), .out({w_chi1[199], w_chi0[199]}));
MSKand_opini2_d2 u_chi_200 (
    .ina({nb_d1[200], nb_d0[200]}), .inb({Bx1[232], Bx0[232]}),
    .rnd(r[200]), .s(s[200]), .clk(clk), .out({w_chi1[200], w_chi0[200]}));
MSKand_opini2_d2 u_chi_201 (
    .ina({nb_d1[201], nb_d0[201]}), .inb({Bx1[233], Bx0[233]}),
    .rnd(r[201]), .s(s[201]), .clk(clk), .out({w_chi1[201], w_chi0[201]}));
MSKand_opini2_d2 u_chi_202 (
    .ina({nb_d1[202], nb_d0[202]}), .inb({Bx1[234], Bx0[234]}),
    .rnd(r[202]), .s(s[202]), .clk(clk), .out({w_chi1[202], w_chi0[202]}));
MSKand_opini2_d2 u_chi_203 (
    .ina({nb_d1[203], nb_d0[203]}), .inb({Bx1[235], Bx0[235]}),
    .rnd(r[203]), .s(s[203]), .clk(clk), .out({w_chi1[203], w_chi0[203]}));
MSKand_opini2_d2 u_chi_204 (
    .ina({nb_d1[204], nb_d0[204]}), .inb({Bx1[236], Bx0[236]}),
    .rnd(r[204]), .s(s[204]), .clk(clk), .out({w_chi1[204], w_chi0[204]}));
MSKand_opini2_d2 u_chi_205 (
    .ina({nb_d1[205], nb_d0[205]}), .inb({Bx1[237], Bx0[237]}),
    .rnd(r[205]), .s(s[205]), .clk(clk), .out({w_chi1[205], w_chi0[205]}));
MSKand_opini2_d2 u_chi_206 (
    .ina({nb_d1[206], nb_d0[206]}), .inb({Bx1[238], Bx0[238]}),
    .rnd(r[206]), .s(s[206]), .clk(clk), .out({w_chi1[206], w_chi0[206]}));
MSKand_opini2_d2 u_chi_207 (
    .ina({nb_d1[207], nb_d0[207]}), .inb({Bx1[239], Bx0[239]}),
    .rnd(r[207]), .s(s[207]), .clk(clk), .out({w_chi1[207], w_chi0[207]}));
MSKand_opini2_d2 u_chi_272 (
    .ina({nb_d1[272], nb_d0[272]}), .inb({Bx1[304], Bx0[304]}),
    .rnd(r[272]), .s(s[272]), .clk(clk), .out({w_chi1[272], w_chi0[272]}));
MSKand_opini2_d2 u_chi_273 (
    .ina({nb_d1[273], nb_d0[273]}), .inb({Bx1[305], Bx0[305]}),
    .rnd(r[273]), .s(s[273]), .clk(clk), .out({w_chi1[273], w_chi0[273]}));
MSKand_opini2_d2 u_chi_274 (
    .ina({nb_d1[274], nb_d0[274]}), .inb({Bx1[306], Bx0[306]}),
    .rnd(r[274]), .s(s[274]), .clk(clk), .out({w_chi1[274], w_chi0[274]}));
MSKand_opini2_d2 u_chi_275 (
    .ina({nb_d1[275], nb_d0[275]}), .inb({Bx1[307], Bx0[307]}),
    .rnd(r[275]), .s(s[275]), .clk(clk), .out({w_chi1[275], w_chi0[275]}));
MSKand_opini2_d2 u_chi_276 (
    .ina({nb_d1[276], nb_d0[276]}), .inb({Bx1[308], Bx0[308]}),
    .rnd(r[276]), .s(s[276]), .clk(clk), .out({w_chi1[276], w_chi0[276]}));
MSKand_opini2_d2 u_chi_277 (
    .ina({nb_d1[277], nb_d0[277]}), .inb({Bx1[309], Bx0[309]}),
    .rnd(r[277]), .s(s[277]), .clk(clk), .out({w_chi1[277], w_chi0[277]}));
MSKand_opini2_d2 u_chi_278 (
    .ina({nb_d1[278], nb_d0[278]}), .inb({Bx1[310], Bx0[310]}),
    .rnd(r[278]), .s(s[278]), .clk(clk), .out({w_chi1[278], w_chi0[278]}));
MSKand_opini2_d2 u_chi_279 (
    .ina({nb_d1[279], nb_d0[279]}), .inb({Bx1[311], Bx0[311]}),
    .rnd(r[279]), .s(s[279]), .clk(clk), .out({w_chi1[279], w_chi0[279]}));
MSKand_opini2_d2 u_chi_280 (
    .ina({nb_d1[280], nb_d0[280]}), .inb({Bx1[312], Bx0[312]}),
    .rnd(r[280]), .s(s[280]), .clk(clk), .out({w_chi1[280], w_chi0[280]}));
MSKand_opini2_d2 u_chi_281 (
    .ina({nb_d1[281], nb_d0[281]}), .inb({Bx1[313], Bx0[313]}),
    .rnd(r[281]), .s(s[281]), .clk(clk), .out({w_chi1[281], w_chi0[281]}));
MSKand_opini2_d2 u_chi_282 (
    .ina({nb_d1[282], nb_d0[282]}), .inb({Bx1[314], Bx0[314]}),
    .rnd(r[282]), .s(s[282]), .clk(clk), .out({w_chi1[282], w_chi0[282]}));
MSKand_opini2_d2 u_chi_283 (
    .ina({nb_d1[283], nb_d0[283]}), .inb({Bx1[315], Bx0[315]}),
    .rnd(r[283]), .s(s[283]), .clk(clk), .out({w_chi1[283], w_chi0[283]}));
MSKand_opini2_d2 u_chi_284 (
    .ina({nb_d1[284], nb_d0[284]}), .inb({Bx1[316], Bx0[316]}),
    .rnd(r[284]), .s(s[284]), .clk(clk), .out({w_chi1[284], w_chi0[284]}));
MSKand_opini2_d2 u_chi_285 (
    .ina({nb_d1[285], nb_d0[285]}), .inb({Bx1[317], Bx0[317]}),
    .rnd(r[285]), .s(s[285]), .clk(clk), .out({w_chi1[285], w_chi0[285]}));
MSKand_opini2_d2 u_chi_286 (
    .ina({nb_d1[286], nb_d0[286]}), .inb({Bx1[318], Bx0[318]}),
    .rnd(r[286]), .s(s[286]), .clk(clk), .out({w_chi1[286], w_chi0[286]}));
MSKand_opini2_d2 u_chi_287 (
    .ina({nb_d1[287], nb_d0[287]}), .inb({Bx1[319], Bx0[319]}),
    .rnd(r[287]), .s(s[287]), .clk(clk), .out({w_chi1[287], w_chi0[287]}));
MSKand_opini2_d2 u_chi_352 (
    .ina({nb_d1[352], nb_d0[352]}), .inb({Bx1[384], Bx0[384]}),
    .rnd(r[352]), .s(s[352]), .clk(clk), .out({w_chi1[352], w_chi0[352]}));
MSKand_opini2_d2 u_chi_353 (
    .ina({nb_d1[353], nb_d0[353]}), .inb({Bx1[385], Bx0[385]}),
    .rnd(r[353]), .s(s[353]), .clk(clk), .out({w_chi1[353], w_chi0[353]}));
MSKand_opini2_d2 u_chi_354 (
    .ina({nb_d1[354], nb_d0[354]}), .inb({Bx1[386], Bx0[386]}),
    .rnd(r[354]), .s(s[354]), .clk(clk), .out({w_chi1[354], w_chi0[354]}));
MSKand_opini2_d2 u_chi_355 (
    .ina({nb_d1[355], nb_d0[355]}), .inb({Bx1[387], Bx0[387]}),
    .rnd(r[355]), .s(s[355]), .clk(clk), .out({w_chi1[355], w_chi0[355]}));
MSKand_opini2_d2 u_chi_356 (
    .ina({nb_d1[356], nb_d0[356]}), .inb({Bx1[388], Bx0[388]}),
    .rnd(r[356]), .s(s[356]), .clk(clk), .out({w_chi1[356], w_chi0[356]}));
MSKand_opini2_d2 u_chi_357 (
    .ina({nb_d1[357], nb_d0[357]}), .inb({Bx1[389], Bx0[389]}),
    .rnd(r[357]), .s(s[357]), .clk(clk), .out({w_chi1[357], w_chi0[357]}));
MSKand_opini2_d2 u_chi_358 (
    .ina({nb_d1[358], nb_d0[358]}), .inb({Bx1[390], Bx0[390]}),
    .rnd(r[358]), .s(s[358]), .clk(clk), .out({w_chi1[358], w_chi0[358]}));
MSKand_opini2_d2 u_chi_359 (
    .ina({nb_d1[359], nb_d0[359]}), .inb({Bx1[391], Bx0[391]}),
    .rnd(r[359]), .s(s[359]), .clk(clk), .out({w_chi1[359], w_chi0[359]}));
MSKand_opini2_d2 u_chi_360 (
    .ina({nb_d1[360], nb_d0[360]}), .inb({Bx1[392], Bx0[392]}),
    .rnd(r[360]), .s(s[360]), .clk(clk), .out({w_chi1[360], w_chi0[360]}));
MSKand_opini2_d2 u_chi_361 (
    .ina({nb_d1[361], nb_d0[361]}), .inb({Bx1[393], Bx0[393]}),
    .rnd(r[361]), .s(s[361]), .clk(clk), .out({w_chi1[361], w_chi0[361]}));
MSKand_opini2_d2 u_chi_362 (
    .ina({nb_d1[362], nb_d0[362]}), .inb({Bx1[394], Bx0[394]}),
    .rnd(r[362]), .s(s[362]), .clk(clk), .out({w_chi1[362], w_chi0[362]}));
MSKand_opini2_d2 u_chi_363 (
    .ina({nb_d1[363], nb_d0[363]}), .inb({Bx1[395], Bx0[395]}),
    .rnd(r[363]), .s(s[363]), .clk(clk), .out({w_chi1[363], w_chi0[363]}));
MSKand_opini2_d2 u_chi_364 (
    .ina({nb_d1[364], nb_d0[364]}), .inb({Bx1[396], Bx0[396]}),
    .rnd(r[364]), .s(s[364]), .clk(clk), .out({w_chi1[364], w_chi0[364]}));
MSKand_opini2_d2 u_chi_365 (
    .ina({nb_d1[365], nb_d0[365]}), .inb({Bx1[397], Bx0[397]}),
    .rnd(r[365]), .s(s[365]), .clk(clk), .out({w_chi1[365], w_chi0[365]}));
MSKand_opini2_d2 u_chi_366 (
    .ina({nb_d1[366], nb_d0[366]}), .inb({Bx1[398], Bx0[398]}),
    .rnd(r[366]), .s(s[366]), .clk(clk), .out({w_chi1[366], w_chi0[366]}));
MSKand_opini2_d2 u_chi_367 (
    .ina({nb_d1[367], nb_d0[367]}), .inb({Bx1[399], Bx0[399]}),
    .rnd(r[367]), .s(s[367]), .clk(clk), .out({w_chi1[367], w_chi0[367]}));
MSKand_opini2_d2 u_chi_48 (
    .ina({nb_d1[48], nb_d0[48]}), .inb({Bx1[0], Bx0[0]}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({w_chi1[48], w_chi0[48]}));
MSKand_opini2_d2 u_chi_49 (
    .ina({nb_d1[49], nb_d0[49]}), .inb({Bx1[1], Bx0[1]}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({w_chi1[49], w_chi0[49]}));
MSKand_opini2_d2 u_chi_50 (
    .ina({nb_d1[50], nb_d0[50]}), .inb({Bx1[2], Bx0[2]}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({w_chi1[50], w_chi0[50]}));
MSKand_opini2_d2 u_chi_51 (
    .ina({nb_d1[51], nb_d0[51]}), .inb({Bx1[3], Bx0[3]}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({w_chi1[51], w_chi0[51]}));
MSKand_opini2_d2 u_chi_52 (
    .ina({nb_d1[52], nb_d0[52]}), .inb({Bx1[4], Bx0[4]}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({w_chi1[52], w_chi0[52]}));
MSKand_opini2_d2 u_chi_53 (
    .ina({nb_d1[53], nb_d0[53]}), .inb({Bx1[5], Bx0[5]}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({w_chi1[53], w_chi0[53]}));
MSKand_opini2_d2 u_chi_54 (
    .ina({nb_d1[54], nb_d0[54]}), .inb({Bx1[6], Bx0[6]}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({w_chi1[54], w_chi0[54]}));
MSKand_opini2_d2 u_chi_55 (
    .ina({nb_d1[55], nb_d0[55]}), .inb({Bx1[7], Bx0[7]}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({w_chi1[55], w_chi0[55]}));
MSKand_opini2_d2 u_chi_56 (
    .ina({nb_d1[56], nb_d0[56]}), .inb({Bx1[8], Bx0[8]}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({w_chi1[56], w_chi0[56]}));
MSKand_opini2_d2 u_chi_57 (
    .ina({nb_d1[57], nb_d0[57]}), .inb({Bx1[9], Bx0[9]}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({w_chi1[57], w_chi0[57]}));
MSKand_opini2_d2 u_chi_58 (
    .ina({nb_d1[58], nb_d0[58]}), .inb({Bx1[10], Bx0[10]}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({w_chi1[58], w_chi0[58]}));
MSKand_opini2_d2 u_chi_59 (
    .ina({nb_d1[59], nb_d0[59]}), .inb({Bx1[11], Bx0[11]}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({w_chi1[59], w_chi0[59]}));
MSKand_opini2_d2 u_chi_60 (
    .ina({nb_d1[60], nb_d0[60]}), .inb({Bx1[12], Bx0[12]}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({w_chi1[60], w_chi0[60]}));
MSKand_opini2_d2 u_chi_61 (
    .ina({nb_d1[61], nb_d0[61]}), .inb({Bx1[13], Bx0[13]}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({w_chi1[61], w_chi0[61]}));
MSKand_opini2_d2 u_chi_62 (
    .ina({nb_d1[62], nb_d0[62]}), .inb({Bx1[14], Bx0[14]}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({w_chi1[62], w_chi0[62]}));
MSKand_opini2_d2 u_chi_63 (
    .ina({nb_d1[63], nb_d0[63]}), .inb({Bx1[15], Bx0[15]}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({w_chi1[63], w_chi0[63]}));
MSKand_opini2_d2 u_chi_128 (
    .ina({nb_d1[128], nb_d0[128]}), .inb({Bx1[80], Bx0[80]}),
    .rnd(r[128]), .s(s[128]), .clk(clk), .out({w_chi1[128], w_chi0[128]}));
MSKand_opini2_d2 u_chi_129 (
    .ina({nb_d1[129], nb_d0[129]}), .inb({Bx1[81], Bx0[81]}),
    .rnd(r[129]), .s(s[129]), .clk(clk), .out({w_chi1[129], w_chi0[129]}));
MSKand_opini2_d2 u_chi_130 (
    .ina({nb_d1[130], nb_d0[130]}), .inb({Bx1[82], Bx0[82]}),
    .rnd(r[130]), .s(s[130]), .clk(clk), .out({w_chi1[130], w_chi0[130]}));
MSKand_opini2_d2 u_chi_131 (
    .ina({nb_d1[131], nb_d0[131]}), .inb({Bx1[83], Bx0[83]}),
    .rnd(r[131]), .s(s[131]), .clk(clk), .out({w_chi1[131], w_chi0[131]}));
MSKand_opini2_d2 u_chi_132 (
    .ina({nb_d1[132], nb_d0[132]}), .inb({Bx1[84], Bx0[84]}),
    .rnd(r[132]), .s(s[132]), .clk(clk), .out({w_chi1[132], w_chi0[132]}));
MSKand_opini2_d2 u_chi_133 (
    .ina({nb_d1[133], nb_d0[133]}), .inb({Bx1[85], Bx0[85]}),
    .rnd(r[133]), .s(s[133]), .clk(clk), .out({w_chi1[133], w_chi0[133]}));
MSKand_opini2_d2 u_chi_134 (
    .ina({nb_d1[134], nb_d0[134]}), .inb({Bx1[86], Bx0[86]}),
    .rnd(r[134]), .s(s[134]), .clk(clk), .out({w_chi1[134], w_chi0[134]}));
MSKand_opini2_d2 u_chi_135 (
    .ina({nb_d1[135], nb_d0[135]}), .inb({Bx1[87], Bx0[87]}),
    .rnd(r[135]), .s(s[135]), .clk(clk), .out({w_chi1[135], w_chi0[135]}));
MSKand_opini2_d2 u_chi_136 (
    .ina({nb_d1[136], nb_d0[136]}), .inb({Bx1[88], Bx0[88]}),
    .rnd(r[136]), .s(s[136]), .clk(clk), .out({w_chi1[136], w_chi0[136]}));
MSKand_opini2_d2 u_chi_137 (
    .ina({nb_d1[137], nb_d0[137]}), .inb({Bx1[89], Bx0[89]}),
    .rnd(r[137]), .s(s[137]), .clk(clk), .out({w_chi1[137], w_chi0[137]}));
MSKand_opini2_d2 u_chi_138 (
    .ina({nb_d1[138], nb_d0[138]}), .inb({Bx1[90], Bx0[90]}),
    .rnd(r[138]), .s(s[138]), .clk(clk), .out({w_chi1[138], w_chi0[138]}));
MSKand_opini2_d2 u_chi_139 (
    .ina({nb_d1[139], nb_d0[139]}), .inb({Bx1[91], Bx0[91]}),
    .rnd(r[139]), .s(s[139]), .clk(clk), .out({w_chi1[139], w_chi0[139]}));
MSKand_opini2_d2 u_chi_140 (
    .ina({nb_d1[140], nb_d0[140]}), .inb({Bx1[92], Bx0[92]}),
    .rnd(r[140]), .s(s[140]), .clk(clk), .out({w_chi1[140], w_chi0[140]}));
MSKand_opini2_d2 u_chi_141 (
    .ina({nb_d1[141], nb_d0[141]}), .inb({Bx1[93], Bx0[93]}),
    .rnd(r[141]), .s(s[141]), .clk(clk), .out({w_chi1[141], w_chi0[141]}));
MSKand_opini2_d2 u_chi_142 (
    .ina({nb_d1[142], nb_d0[142]}), .inb({Bx1[94], Bx0[94]}),
    .rnd(r[142]), .s(s[142]), .clk(clk), .out({w_chi1[142], w_chi0[142]}));
MSKand_opini2_d2 u_chi_143 (
    .ina({nb_d1[143], nb_d0[143]}), .inb({Bx1[95], Bx0[95]}),
    .rnd(r[143]), .s(s[143]), .clk(clk), .out({w_chi1[143], w_chi0[143]}));
MSKand_opini2_d2 u_chi_208 (
    .ina({nb_d1[208], nb_d0[208]}), .inb({Bx1[160], Bx0[160]}),
    .rnd(r[208]), .s(s[208]), .clk(clk), .out({w_chi1[208], w_chi0[208]}));
MSKand_opini2_d2 u_chi_209 (
    .ina({nb_d1[209], nb_d0[209]}), .inb({Bx1[161], Bx0[161]}),
    .rnd(r[209]), .s(s[209]), .clk(clk), .out({w_chi1[209], w_chi0[209]}));
MSKand_opini2_d2 u_chi_210 (
    .ina({nb_d1[210], nb_d0[210]}), .inb({Bx1[162], Bx0[162]}),
    .rnd(r[210]), .s(s[210]), .clk(clk), .out({w_chi1[210], w_chi0[210]}));
MSKand_opini2_d2 u_chi_211 (
    .ina({nb_d1[211], nb_d0[211]}), .inb({Bx1[163], Bx0[163]}),
    .rnd(r[211]), .s(s[211]), .clk(clk), .out({w_chi1[211], w_chi0[211]}));
MSKand_opini2_d2 u_chi_212 (
    .ina({nb_d1[212], nb_d0[212]}), .inb({Bx1[164], Bx0[164]}),
    .rnd(r[212]), .s(s[212]), .clk(clk), .out({w_chi1[212], w_chi0[212]}));
MSKand_opini2_d2 u_chi_213 (
    .ina({nb_d1[213], nb_d0[213]}), .inb({Bx1[165], Bx0[165]}),
    .rnd(r[213]), .s(s[213]), .clk(clk), .out({w_chi1[213], w_chi0[213]}));
MSKand_opini2_d2 u_chi_214 (
    .ina({nb_d1[214], nb_d0[214]}), .inb({Bx1[166], Bx0[166]}),
    .rnd(r[214]), .s(s[214]), .clk(clk), .out({w_chi1[214], w_chi0[214]}));
MSKand_opini2_d2 u_chi_215 (
    .ina({nb_d1[215], nb_d0[215]}), .inb({Bx1[167], Bx0[167]}),
    .rnd(r[215]), .s(s[215]), .clk(clk), .out({w_chi1[215], w_chi0[215]}));
MSKand_opini2_d2 u_chi_216 (
    .ina({nb_d1[216], nb_d0[216]}), .inb({Bx1[168], Bx0[168]}),
    .rnd(r[216]), .s(s[216]), .clk(clk), .out({w_chi1[216], w_chi0[216]}));
MSKand_opini2_d2 u_chi_217 (
    .ina({nb_d1[217], nb_d0[217]}), .inb({Bx1[169], Bx0[169]}),
    .rnd(r[217]), .s(s[217]), .clk(clk), .out({w_chi1[217], w_chi0[217]}));
MSKand_opini2_d2 u_chi_218 (
    .ina({nb_d1[218], nb_d0[218]}), .inb({Bx1[170], Bx0[170]}),
    .rnd(r[218]), .s(s[218]), .clk(clk), .out({w_chi1[218], w_chi0[218]}));
MSKand_opini2_d2 u_chi_219 (
    .ina({nb_d1[219], nb_d0[219]}), .inb({Bx1[171], Bx0[171]}),
    .rnd(r[219]), .s(s[219]), .clk(clk), .out({w_chi1[219], w_chi0[219]}));
MSKand_opini2_d2 u_chi_220 (
    .ina({nb_d1[220], nb_d0[220]}), .inb({Bx1[172], Bx0[172]}),
    .rnd(r[220]), .s(s[220]), .clk(clk), .out({w_chi1[220], w_chi0[220]}));
MSKand_opini2_d2 u_chi_221 (
    .ina({nb_d1[221], nb_d0[221]}), .inb({Bx1[173], Bx0[173]}),
    .rnd(r[221]), .s(s[221]), .clk(clk), .out({w_chi1[221], w_chi0[221]}));
MSKand_opini2_d2 u_chi_222 (
    .ina({nb_d1[222], nb_d0[222]}), .inb({Bx1[174], Bx0[174]}),
    .rnd(r[222]), .s(s[222]), .clk(clk), .out({w_chi1[222], w_chi0[222]}));
MSKand_opini2_d2 u_chi_223 (
    .ina({nb_d1[223], nb_d0[223]}), .inb({Bx1[175], Bx0[175]}),
    .rnd(r[223]), .s(s[223]), .clk(clk), .out({w_chi1[223], w_chi0[223]}));
MSKand_opini2_d2 u_chi_288 (
    .ina({nb_d1[288], nb_d0[288]}), .inb({Bx1[240], Bx0[240]}),
    .rnd(r[288]), .s(s[288]), .clk(clk), .out({w_chi1[288], w_chi0[288]}));
MSKand_opini2_d2 u_chi_289 (
    .ina({nb_d1[289], nb_d0[289]}), .inb({Bx1[241], Bx0[241]}),
    .rnd(r[289]), .s(s[289]), .clk(clk), .out({w_chi1[289], w_chi0[289]}));
MSKand_opini2_d2 u_chi_290 (
    .ina({nb_d1[290], nb_d0[290]}), .inb({Bx1[242], Bx0[242]}),
    .rnd(r[290]), .s(s[290]), .clk(clk), .out({w_chi1[290], w_chi0[290]}));
MSKand_opini2_d2 u_chi_291 (
    .ina({nb_d1[291], nb_d0[291]}), .inb({Bx1[243], Bx0[243]}),
    .rnd(r[291]), .s(s[291]), .clk(clk), .out({w_chi1[291], w_chi0[291]}));
MSKand_opini2_d2 u_chi_292 (
    .ina({nb_d1[292], nb_d0[292]}), .inb({Bx1[244], Bx0[244]}),
    .rnd(r[292]), .s(s[292]), .clk(clk), .out({w_chi1[292], w_chi0[292]}));
MSKand_opini2_d2 u_chi_293 (
    .ina({nb_d1[293], nb_d0[293]}), .inb({Bx1[245], Bx0[245]}),
    .rnd(r[293]), .s(s[293]), .clk(clk), .out({w_chi1[293], w_chi0[293]}));
MSKand_opini2_d2 u_chi_294 (
    .ina({nb_d1[294], nb_d0[294]}), .inb({Bx1[246], Bx0[246]}),
    .rnd(r[294]), .s(s[294]), .clk(clk), .out({w_chi1[294], w_chi0[294]}));
MSKand_opini2_d2 u_chi_295 (
    .ina({nb_d1[295], nb_d0[295]}), .inb({Bx1[247], Bx0[247]}),
    .rnd(r[295]), .s(s[295]), .clk(clk), .out({w_chi1[295], w_chi0[295]}));
MSKand_opini2_d2 u_chi_296 (
    .ina({nb_d1[296], nb_d0[296]}), .inb({Bx1[248], Bx0[248]}),
    .rnd(r[296]), .s(s[296]), .clk(clk), .out({w_chi1[296], w_chi0[296]}));
MSKand_opini2_d2 u_chi_297 (
    .ina({nb_d1[297], nb_d0[297]}), .inb({Bx1[249], Bx0[249]}),
    .rnd(r[297]), .s(s[297]), .clk(clk), .out({w_chi1[297], w_chi0[297]}));
MSKand_opini2_d2 u_chi_298 (
    .ina({nb_d1[298], nb_d0[298]}), .inb({Bx1[250], Bx0[250]}),
    .rnd(r[298]), .s(s[298]), .clk(clk), .out({w_chi1[298], w_chi0[298]}));
MSKand_opini2_d2 u_chi_299 (
    .ina({nb_d1[299], nb_d0[299]}), .inb({Bx1[251], Bx0[251]}),
    .rnd(r[299]), .s(s[299]), .clk(clk), .out({w_chi1[299], w_chi0[299]}));
MSKand_opini2_d2 u_chi_300 (
    .ina({nb_d1[300], nb_d0[300]}), .inb({Bx1[252], Bx0[252]}),
    .rnd(r[300]), .s(s[300]), .clk(clk), .out({w_chi1[300], w_chi0[300]}));
MSKand_opini2_d2 u_chi_301 (
    .ina({nb_d1[301], nb_d0[301]}), .inb({Bx1[253], Bx0[253]}),
    .rnd(r[301]), .s(s[301]), .clk(clk), .out({w_chi1[301], w_chi0[301]}));
MSKand_opini2_d2 u_chi_302 (
    .ina({nb_d1[302], nb_d0[302]}), .inb({Bx1[254], Bx0[254]}),
    .rnd(r[302]), .s(s[302]), .clk(clk), .out({w_chi1[302], w_chi0[302]}));
MSKand_opini2_d2 u_chi_303 (
    .ina({nb_d1[303], nb_d0[303]}), .inb({Bx1[255], Bx0[255]}),
    .rnd(r[303]), .s(s[303]), .clk(clk), .out({w_chi1[303], w_chi0[303]}));
MSKand_opini2_d2 u_chi_368 (
    .ina({nb_d1[368], nb_d0[368]}), .inb({Bx1[320], Bx0[320]}),
    .rnd(r[368]), .s(s[368]), .clk(clk), .out({w_chi1[368], w_chi0[368]}));
MSKand_opini2_d2 u_chi_369 (
    .ina({nb_d1[369], nb_d0[369]}), .inb({Bx1[321], Bx0[321]}),
    .rnd(r[369]), .s(s[369]), .clk(clk), .out({w_chi1[369], w_chi0[369]}));
MSKand_opini2_d2 u_chi_370 (
    .ina({nb_d1[370], nb_d0[370]}), .inb({Bx1[322], Bx0[322]}),
    .rnd(r[370]), .s(s[370]), .clk(clk), .out({w_chi1[370], w_chi0[370]}));
MSKand_opini2_d2 u_chi_371 (
    .ina({nb_d1[371], nb_d0[371]}), .inb({Bx1[323], Bx0[323]}),
    .rnd(r[371]), .s(s[371]), .clk(clk), .out({w_chi1[371], w_chi0[371]}));
MSKand_opini2_d2 u_chi_372 (
    .ina({nb_d1[372], nb_d0[372]}), .inb({Bx1[324], Bx0[324]}),
    .rnd(r[372]), .s(s[372]), .clk(clk), .out({w_chi1[372], w_chi0[372]}));
MSKand_opini2_d2 u_chi_373 (
    .ina({nb_d1[373], nb_d0[373]}), .inb({Bx1[325], Bx0[325]}),
    .rnd(r[373]), .s(s[373]), .clk(clk), .out({w_chi1[373], w_chi0[373]}));
MSKand_opini2_d2 u_chi_374 (
    .ina({nb_d1[374], nb_d0[374]}), .inb({Bx1[326], Bx0[326]}),
    .rnd(r[374]), .s(s[374]), .clk(clk), .out({w_chi1[374], w_chi0[374]}));
MSKand_opini2_d2 u_chi_375 (
    .ina({nb_d1[375], nb_d0[375]}), .inb({Bx1[327], Bx0[327]}),
    .rnd(r[375]), .s(s[375]), .clk(clk), .out({w_chi1[375], w_chi0[375]}));
MSKand_opini2_d2 u_chi_376 (
    .ina({nb_d1[376], nb_d0[376]}), .inb({Bx1[328], Bx0[328]}),
    .rnd(r[376]), .s(s[376]), .clk(clk), .out({w_chi1[376], w_chi0[376]}));
MSKand_opini2_d2 u_chi_377 (
    .ina({nb_d1[377], nb_d0[377]}), .inb({Bx1[329], Bx0[329]}),
    .rnd(r[377]), .s(s[377]), .clk(clk), .out({w_chi1[377], w_chi0[377]}));
MSKand_opini2_d2 u_chi_378 (
    .ina({nb_d1[378], nb_d0[378]}), .inb({Bx1[330], Bx0[330]}),
    .rnd(r[378]), .s(s[378]), .clk(clk), .out({w_chi1[378], w_chi0[378]}));
MSKand_opini2_d2 u_chi_379 (
    .ina({nb_d1[379], nb_d0[379]}), .inb({Bx1[331], Bx0[331]}),
    .rnd(r[379]), .s(s[379]), .clk(clk), .out({w_chi1[379], w_chi0[379]}));
MSKand_opini2_d2 u_chi_380 (
    .ina({nb_d1[380], nb_d0[380]}), .inb({Bx1[332], Bx0[332]}),
    .rnd(r[380]), .s(s[380]), .clk(clk), .out({w_chi1[380], w_chi0[380]}));
MSKand_opini2_d2 u_chi_381 (
    .ina({nb_d1[381], nb_d0[381]}), .inb({Bx1[333], Bx0[333]}),
    .rnd(r[381]), .s(s[381]), .clk(clk), .out({w_chi1[381], w_chi0[381]}));
MSKand_opini2_d2 u_chi_382 (
    .ina({nb_d1[382], nb_d0[382]}), .inb({Bx1[334], Bx0[334]}),
    .rnd(r[382]), .s(s[382]), .clk(clk), .out({w_chi1[382], w_chi0[382]}));
MSKand_opini2_d2 u_chi_383 (
    .ina({nb_d1[383], nb_d0[383]}), .inb({Bx1[335], Bx0[335]}),
    .rnd(r[383]), .s(s[383]), .clk(clk), .out({w_chi1[383], w_chi0[383]}));
MSKand_opini2_d2 u_chi_64 (
    .ina({nb_d1[64], nb_d0[64]}), .inb({Bx1[16], Bx0[16]}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({w_chi1[64], w_chi0[64]}));
MSKand_opini2_d2 u_chi_65 (
    .ina({nb_d1[65], nb_d0[65]}), .inb({Bx1[17], Bx0[17]}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({w_chi1[65], w_chi0[65]}));
MSKand_opini2_d2 u_chi_66 (
    .ina({nb_d1[66], nb_d0[66]}), .inb({Bx1[18], Bx0[18]}),
    .rnd(r[66]), .s(s[66]), .clk(clk), .out({w_chi1[66], w_chi0[66]}));
MSKand_opini2_d2 u_chi_67 (
    .ina({nb_d1[67], nb_d0[67]}), .inb({Bx1[19], Bx0[19]}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({w_chi1[67], w_chi0[67]}));
MSKand_opini2_d2 u_chi_68 (
    .ina({nb_d1[68], nb_d0[68]}), .inb({Bx1[20], Bx0[20]}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({w_chi1[68], w_chi0[68]}));
MSKand_opini2_d2 u_chi_69 (
    .ina({nb_d1[69], nb_d0[69]}), .inb({Bx1[21], Bx0[21]}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({w_chi1[69], w_chi0[69]}));
MSKand_opini2_d2 u_chi_70 (
    .ina({nb_d1[70], nb_d0[70]}), .inb({Bx1[22], Bx0[22]}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({w_chi1[70], w_chi0[70]}));
MSKand_opini2_d2 u_chi_71 (
    .ina({nb_d1[71], nb_d0[71]}), .inb({Bx1[23], Bx0[23]}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({w_chi1[71], w_chi0[71]}));
MSKand_opini2_d2 u_chi_72 (
    .ina({nb_d1[72], nb_d0[72]}), .inb({Bx1[24], Bx0[24]}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({w_chi1[72], w_chi0[72]}));
MSKand_opini2_d2 u_chi_73 (
    .ina({nb_d1[73], nb_d0[73]}), .inb({Bx1[25], Bx0[25]}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({w_chi1[73], w_chi0[73]}));
MSKand_opini2_d2 u_chi_74 (
    .ina({nb_d1[74], nb_d0[74]}), .inb({Bx1[26], Bx0[26]}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({w_chi1[74], w_chi0[74]}));
MSKand_opini2_d2 u_chi_75 (
    .ina({nb_d1[75], nb_d0[75]}), .inb({Bx1[27], Bx0[27]}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({w_chi1[75], w_chi0[75]}));
MSKand_opini2_d2 u_chi_76 (
    .ina({nb_d1[76], nb_d0[76]}), .inb({Bx1[28], Bx0[28]}),
    .rnd(r[76]), .s(s[76]), .clk(clk), .out({w_chi1[76], w_chi0[76]}));
MSKand_opini2_d2 u_chi_77 (
    .ina({nb_d1[77], nb_d0[77]}), .inb({Bx1[29], Bx0[29]}),
    .rnd(r[77]), .s(s[77]), .clk(clk), .out({w_chi1[77], w_chi0[77]}));
MSKand_opini2_d2 u_chi_78 (
    .ina({nb_d1[78], nb_d0[78]}), .inb({Bx1[30], Bx0[30]}),
    .rnd(r[78]), .s(s[78]), .clk(clk), .out({w_chi1[78], w_chi0[78]}));
MSKand_opini2_d2 u_chi_79 (
    .ina({nb_d1[79], nb_d0[79]}), .inb({Bx1[31], Bx0[31]}),
    .rnd(r[79]), .s(s[79]), .clk(clk), .out({w_chi1[79], w_chi0[79]}));
MSKand_opini2_d2 u_chi_144 (
    .ina({nb_d1[144], nb_d0[144]}), .inb({Bx1[96], Bx0[96]}),
    .rnd(r[144]), .s(s[144]), .clk(clk), .out({w_chi1[144], w_chi0[144]}));
MSKand_opini2_d2 u_chi_145 (
    .ina({nb_d1[145], nb_d0[145]}), .inb({Bx1[97], Bx0[97]}),
    .rnd(r[145]), .s(s[145]), .clk(clk), .out({w_chi1[145], w_chi0[145]}));
MSKand_opini2_d2 u_chi_146 (
    .ina({nb_d1[146], nb_d0[146]}), .inb({Bx1[98], Bx0[98]}),
    .rnd(r[146]), .s(s[146]), .clk(clk), .out({w_chi1[146], w_chi0[146]}));
MSKand_opini2_d2 u_chi_147 (
    .ina({nb_d1[147], nb_d0[147]}), .inb({Bx1[99], Bx0[99]}),
    .rnd(r[147]), .s(s[147]), .clk(clk), .out({w_chi1[147], w_chi0[147]}));
MSKand_opini2_d2 u_chi_148 (
    .ina({nb_d1[148], nb_d0[148]}), .inb({Bx1[100], Bx0[100]}),
    .rnd(r[148]), .s(s[148]), .clk(clk), .out({w_chi1[148], w_chi0[148]}));
MSKand_opini2_d2 u_chi_149 (
    .ina({nb_d1[149], nb_d0[149]}), .inb({Bx1[101], Bx0[101]}),
    .rnd(r[149]), .s(s[149]), .clk(clk), .out({w_chi1[149], w_chi0[149]}));
MSKand_opini2_d2 u_chi_150 (
    .ina({nb_d1[150], nb_d0[150]}), .inb({Bx1[102], Bx0[102]}),
    .rnd(r[150]), .s(s[150]), .clk(clk), .out({w_chi1[150], w_chi0[150]}));
MSKand_opini2_d2 u_chi_151 (
    .ina({nb_d1[151], nb_d0[151]}), .inb({Bx1[103], Bx0[103]}),
    .rnd(r[151]), .s(s[151]), .clk(clk), .out({w_chi1[151], w_chi0[151]}));
MSKand_opini2_d2 u_chi_152 (
    .ina({nb_d1[152], nb_d0[152]}), .inb({Bx1[104], Bx0[104]}),
    .rnd(r[152]), .s(s[152]), .clk(clk), .out({w_chi1[152], w_chi0[152]}));
MSKand_opini2_d2 u_chi_153 (
    .ina({nb_d1[153], nb_d0[153]}), .inb({Bx1[105], Bx0[105]}),
    .rnd(r[153]), .s(s[153]), .clk(clk), .out({w_chi1[153], w_chi0[153]}));
MSKand_opini2_d2 u_chi_154 (
    .ina({nb_d1[154], nb_d0[154]}), .inb({Bx1[106], Bx0[106]}),
    .rnd(r[154]), .s(s[154]), .clk(clk), .out({w_chi1[154], w_chi0[154]}));
MSKand_opini2_d2 u_chi_155 (
    .ina({nb_d1[155], nb_d0[155]}), .inb({Bx1[107], Bx0[107]}),
    .rnd(r[155]), .s(s[155]), .clk(clk), .out({w_chi1[155], w_chi0[155]}));
MSKand_opini2_d2 u_chi_156 (
    .ina({nb_d1[156], nb_d0[156]}), .inb({Bx1[108], Bx0[108]}),
    .rnd(r[156]), .s(s[156]), .clk(clk), .out({w_chi1[156], w_chi0[156]}));
MSKand_opini2_d2 u_chi_157 (
    .ina({nb_d1[157], nb_d0[157]}), .inb({Bx1[109], Bx0[109]}),
    .rnd(r[157]), .s(s[157]), .clk(clk), .out({w_chi1[157], w_chi0[157]}));
MSKand_opini2_d2 u_chi_158 (
    .ina({nb_d1[158], nb_d0[158]}), .inb({Bx1[110], Bx0[110]}),
    .rnd(r[158]), .s(s[158]), .clk(clk), .out({w_chi1[158], w_chi0[158]}));
MSKand_opini2_d2 u_chi_159 (
    .ina({nb_d1[159], nb_d0[159]}), .inb({Bx1[111], Bx0[111]}),
    .rnd(r[159]), .s(s[159]), .clk(clk), .out({w_chi1[159], w_chi0[159]}));
MSKand_opini2_d2 u_chi_224 (
    .ina({nb_d1[224], nb_d0[224]}), .inb({Bx1[176], Bx0[176]}),
    .rnd(r[224]), .s(s[224]), .clk(clk), .out({w_chi1[224], w_chi0[224]}));
MSKand_opini2_d2 u_chi_225 (
    .ina({nb_d1[225], nb_d0[225]}), .inb({Bx1[177], Bx0[177]}),
    .rnd(r[225]), .s(s[225]), .clk(clk), .out({w_chi1[225], w_chi0[225]}));
MSKand_opini2_d2 u_chi_226 (
    .ina({nb_d1[226], nb_d0[226]}), .inb({Bx1[178], Bx0[178]}),
    .rnd(r[226]), .s(s[226]), .clk(clk), .out({w_chi1[226], w_chi0[226]}));
MSKand_opini2_d2 u_chi_227 (
    .ina({nb_d1[227], nb_d0[227]}), .inb({Bx1[179], Bx0[179]}),
    .rnd(r[227]), .s(s[227]), .clk(clk), .out({w_chi1[227], w_chi0[227]}));
MSKand_opini2_d2 u_chi_228 (
    .ina({nb_d1[228], nb_d0[228]}), .inb({Bx1[180], Bx0[180]}),
    .rnd(r[228]), .s(s[228]), .clk(clk), .out({w_chi1[228], w_chi0[228]}));
MSKand_opini2_d2 u_chi_229 (
    .ina({nb_d1[229], nb_d0[229]}), .inb({Bx1[181], Bx0[181]}),
    .rnd(r[229]), .s(s[229]), .clk(clk), .out({w_chi1[229], w_chi0[229]}));
MSKand_opini2_d2 u_chi_230 (
    .ina({nb_d1[230], nb_d0[230]}), .inb({Bx1[182], Bx0[182]}),
    .rnd(r[230]), .s(s[230]), .clk(clk), .out({w_chi1[230], w_chi0[230]}));
MSKand_opini2_d2 u_chi_231 (
    .ina({nb_d1[231], nb_d0[231]}), .inb({Bx1[183], Bx0[183]}),
    .rnd(r[231]), .s(s[231]), .clk(clk), .out({w_chi1[231], w_chi0[231]}));
MSKand_opini2_d2 u_chi_232 (
    .ina({nb_d1[232], nb_d0[232]}), .inb({Bx1[184], Bx0[184]}),
    .rnd(r[232]), .s(s[232]), .clk(clk), .out({w_chi1[232], w_chi0[232]}));
MSKand_opini2_d2 u_chi_233 (
    .ina({nb_d1[233], nb_d0[233]}), .inb({Bx1[185], Bx0[185]}),
    .rnd(r[233]), .s(s[233]), .clk(clk), .out({w_chi1[233], w_chi0[233]}));
MSKand_opini2_d2 u_chi_234 (
    .ina({nb_d1[234], nb_d0[234]}), .inb({Bx1[186], Bx0[186]}),
    .rnd(r[234]), .s(s[234]), .clk(clk), .out({w_chi1[234], w_chi0[234]}));
MSKand_opini2_d2 u_chi_235 (
    .ina({nb_d1[235], nb_d0[235]}), .inb({Bx1[187], Bx0[187]}),
    .rnd(r[235]), .s(s[235]), .clk(clk), .out({w_chi1[235], w_chi0[235]}));
MSKand_opini2_d2 u_chi_236 (
    .ina({nb_d1[236], nb_d0[236]}), .inb({Bx1[188], Bx0[188]}),
    .rnd(r[236]), .s(s[236]), .clk(clk), .out({w_chi1[236], w_chi0[236]}));
MSKand_opini2_d2 u_chi_237 (
    .ina({nb_d1[237], nb_d0[237]}), .inb({Bx1[189], Bx0[189]}),
    .rnd(r[237]), .s(s[237]), .clk(clk), .out({w_chi1[237], w_chi0[237]}));
MSKand_opini2_d2 u_chi_238 (
    .ina({nb_d1[238], nb_d0[238]}), .inb({Bx1[190], Bx0[190]}),
    .rnd(r[238]), .s(s[238]), .clk(clk), .out({w_chi1[238], w_chi0[238]}));
MSKand_opini2_d2 u_chi_239 (
    .ina({nb_d1[239], nb_d0[239]}), .inb({Bx1[191], Bx0[191]}),
    .rnd(r[239]), .s(s[239]), .clk(clk), .out({w_chi1[239], w_chi0[239]}));
MSKand_opini2_d2 u_chi_304 (
    .ina({nb_d1[304], nb_d0[304]}), .inb({Bx1[256], Bx0[256]}),
    .rnd(r[304]), .s(s[304]), .clk(clk), .out({w_chi1[304], w_chi0[304]}));
MSKand_opini2_d2 u_chi_305 (
    .ina({nb_d1[305], nb_d0[305]}), .inb({Bx1[257], Bx0[257]}),
    .rnd(r[305]), .s(s[305]), .clk(clk), .out({w_chi1[305], w_chi0[305]}));
MSKand_opini2_d2 u_chi_306 (
    .ina({nb_d1[306], nb_d0[306]}), .inb({Bx1[258], Bx0[258]}),
    .rnd(r[306]), .s(s[306]), .clk(clk), .out({w_chi1[306], w_chi0[306]}));
MSKand_opini2_d2 u_chi_307 (
    .ina({nb_d1[307], nb_d0[307]}), .inb({Bx1[259], Bx0[259]}),
    .rnd(r[307]), .s(s[307]), .clk(clk), .out({w_chi1[307], w_chi0[307]}));
MSKand_opini2_d2 u_chi_308 (
    .ina({nb_d1[308], nb_d0[308]}), .inb({Bx1[260], Bx0[260]}),
    .rnd(r[308]), .s(s[308]), .clk(clk), .out({w_chi1[308], w_chi0[308]}));
MSKand_opini2_d2 u_chi_309 (
    .ina({nb_d1[309], nb_d0[309]}), .inb({Bx1[261], Bx0[261]}),
    .rnd(r[309]), .s(s[309]), .clk(clk), .out({w_chi1[309], w_chi0[309]}));
MSKand_opini2_d2 u_chi_310 (
    .ina({nb_d1[310], nb_d0[310]}), .inb({Bx1[262], Bx0[262]}),
    .rnd(r[310]), .s(s[310]), .clk(clk), .out({w_chi1[310], w_chi0[310]}));
MSKand_opini2_d2 u_chi_311 (
    .ina({nb_d1[311], nb_d0[311]}), .inb({Bx1[263], Bx0[263]}),
    .rnd(r[311]), .s(s[311]), .clk(clk), .out({w_chi1[311], w_chi0[311]}));
MSKand_opini2_d2 u_chi_312 (
    .ina({nb_d1[312], nb_d0[312]}), .inb({Bx1[264], Bx0[264]}),
    .rnd(r[312]), .s(s[312]), .clk(clk), .out({w_chi1[312], w_chi0[312]}));
MSKand_opini2_d2 u_chi_313 (
    .ina({nb_d1[313], nb_d0[313]}), .inb({Bx1[265], Bx0[265]}),
    .rnd(r[313]), .s(s[313]), .clk(clk), .out({w_chi1[313], w_chi0[313]}));
MSKand_opini2_d2 u_chi_314 (
    .ina({nb_d1[314], nb_d0[314]}), .inb({Bx1[266], Bx0[266]}),
    .rnd(r[314]), .s(s[314]), .clk(clk), .out({w_chi1[314], w_chi0[314]}));
MSKand_opini2_d2 u_chi_315 (
    .ina({nb_d1[315], nb_d0[315]}), .inb({Bx1[267], Bx0[267]}),
    .rnd(r[315]), .s(s[315]), .clk(clk), .out({w_chi1[315], w_chi0[315]}));
MSKand_opini2_d2 u_chi_316 (
    .ina({nb_d1[316], nb_d0[316]}), .inb({Bx1[268], Bx0[268]}),
    .rnd(r[316]), .s(s[316]), .clk(clk), .out({w_chi1[316], w_chi0[316]}));
MSKand_opini2_d2 u_chi_317 (
    .ina({nb_d1[317], nb_d0[317]}), .inb({Bx1[269], Bx0[269]}),
    .rnd(r[317]), .s(s[317]), .clk(clk), .out({w_chi1[317], w_chi0[317]}));
MSKand_opini2_d2 u_chi_318 (
    .ina({nb_d1[318], nb_d0[318]}), .inb({Bx1[270], Bx0[270]}),
    .rnd(r[318]), .s(s[318]), .clk(clk), .out({w_chi1[318], w_chi0[318]}));
MSKand_opini2_d2 u_chi_319 (
    .ina({nb_d1[319], nb_d0[319]}), .inb({Bx1[271], Bx0[271]}),
    .rnd(r[319]), .s(s[319]), .clk(clk), .out({w_chi1[319], w_chi0[319]}));
MSKand_opini2_d2 u_chi_384 (
    .ina({nb_d1[384], nb_d0[384]}), .inb({Bx1[336], Bx0[336]}),
    .rnd(r[384]), .s(s[384]), .clk(clk), .out({w_chi1[384], w_chi0[384]}));
MSKand_opini2_d2 u_chi_385 (
    .ina({nb_d1[385], nb_d0[385]}), .inb({Bx1[337], Bx0[337]}),
    .rnd(r[385]), .s(s[385]), .clk(clk), .out({w_chi1[385], w_chi0[385]}));
MSKand_opini2_d2 u_chi_386 (
    .ina({nb_d1[386], nb_d0[386]}), .inb({Bx1[338], Bx0[338]}),
    .rnd(r[386]), .s(s[386]), .clk(clk), .out({w_chi1[386], w_chi0[386]}));
MSKand_opini2_d2 u_chi_387 (
    .ina({nb_d1[387], nb_d0[387]}), .inb({Bx1[339], Bx0[339]}),
    .rnd(r[387]), .s(s[387]), .clk(clk), .out({w_chi1[387], w_chi0[387]}));
MSKand_opini2_d2 u_chi_388 (
    .ina({nb_d1[388], nb_d0[388]}), .inb({Bx1[340], Bx0[340]}),
    .rnd(r[388]), .s(s[388]), .clk(clk), .out({w_chi1[388], w_chi0[388]}));
MSKand_opini2_d2 u_chi_389 (
    .ina({nb_d1[389], nb_d0[389]}), .inb({Bx1[341], Bx0[341]}),
    .rnd(r[389]), .s(s[389]), .clk(clk), .out({w_chi1[389], w_chi0[389]}));
MSKand_opini2_d2 u_chi_390 (
    .ina({nb_d1[390], nb_d0[390]}), .inb({Bx1[342], Bx0[342]}),
    .rnd(r[390]), .s(s[390]), .clk(clk), .out({w_chi1[390], w_chi0[390]}));
MSKand_opini2_d2 u_chi_391 (
    .ina({nb_d1[391], nb_d0[391]}), .inb({Bx1[343], Bx0[343]}),
    .rnd(r[391]), .s(s[391]), .clk(clk), .out({w_chi1[391], w_chi0[391]}));
MSKand_opini2_d2 u_chi_392 (
    .ina({nb_d1[392], nb_d0[392]}), .inb({Bx1[344], Bx0[344]}),
    .rnd(r[392]), .s(s[392]), .clk(clk), .out({w_chi1[392], w_chi0[392]}));
MSKand_opini2_d2 u_chi_393 (
    .ina({nb_d1[393], nb_d0[393]}), .inb({Bx1[345], Bx0[345]}),
    .rnd(r[393]), .s(s[393]), .clk(clk), .out({w_chi1[393], w_chi0[393]}));
MSKand_opini2_d2 u_chi_394 (
    .ina({nb_d1[394], nb_d0[394]}), .inb({Bx1[346], Bx0[346]}),
    .rnd(r[394]), .s(s[394]), .clk(clk), .out({w_chi1[394], w_chi0[394]}));
MSKand_opini2_d2 u_chi_395 (
    .ina({nb_d1[395], nb_d0[395]}), .inb({Bx1[347], Bx0[347]}),
    .rnd(r[395]), .s(s[395]), .clk(clk), .out({w_chi1[395], w_chi0[395]}));
MSKand_opini2_d2 u_chi_396 (
    .ina({nb_d1[396], nb_d0[396]}), .inb({Bx1[348], Bx0[348]}),
    .rnd(r[396]), .s(s[396]), .clk(clk), .out({w_chi1[396], w_chi0[396]}));
MSKand_opini2_d2 u_chi_397 (
    .ina({nb_d1[397], nb_d0[397]}), .inb({Bx1[349], Bx0[349]}),
    .rnd(r[397]), .s(s[397]), .clk(clk), .out({w_chi1[397], w_chi0[397]}));
MSKand_opini2_d2 u_chi_398 (
    .ina({nb_d1[398], nb_d0[398]}), .inb({Bx1[350], Bx0[350]}),
    .rnd(r[398]), .s(s[398]), .clk(clk), .out({w_chi1[398], w_chi0[398]}));
MSKand_opini2_d2 u_chi_399 (
    .ina({nb_d1[399], nb_d0[399]}), .inb({Bx1[351], Bx0[351]}),
    .rnd(r[399]), .s(s[399]), .clk(clk), .out({w_chi1[399], w_chi0[399]}));

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
assign o[400] = St0[200];  assign o[401] = St1[200];
assign o[402] = St0[201];  assign o[403] = St1[201];
assign o[404] = St0[202];  assign o[405] = St1[202];
assign o[406] = St0[203];  assign o[407] = St1[203];
assign o[408] = St0[204];  assign o[409] = St1[204];
assign o[410] = St0[205];  assign o[411] = St1[205];
assign o[412] = St0[206];  assign o[413] = St1[206];
assign o[414] = St0[207];  assign o[415] = St1[207];
assign o[416] = St0[208];  assign o[417] = St1[208];
assign o[418] = St0[209];  assign o[419] = St1[209];
assign o[420] = St0[210];  assign o[421] = St1[210];
assign o[422] = St0[211];  assign o[423] = St1[211];
assign o[424] = St0[212];  assign o[425] = St1[212];
assign o[426] = St0[213];  assign o[427] = St1[213];
assign o[428] = St0[214];  assign o[429] = St1[214];
assign o[430] = St0[215];  assign o[431] = St1[215];
assign o[432] = St0[216];  assign o[433] = St1[216];
assign o[434] = St0[217];  assign o[435] = St1[217];
assign o[436] = St0[218];  assign o[437] = St1[218];
assign o[438] = St0[219];  assign o[439] = St1[219];
assign o[440] = St0[220];  assign o[441] = St1[220];
assign o[442] = St0[221];  assign o[443] = St1[221];
assign o[444] = St0[222];  assign o[445] = St1[222];
assign o[446] = St0[223];  assign o[447] = St1[223];
assign o[448] = St0[224];  assign o[449] = St1[224];
assign o[450] = St0[225];  assign o[451] = St1[225];
assign o[452] = St0[226];  assign o[453] = St1[226];
assign o[454] = St0[227];  assign o[455] = St1[227];
assign o[456] = St0[228];  assign o[457] = St1[228];
assign o[458] = St0[229];  assign o[459] = St1[229];
assign o[460] = St0[230];  assign o[461] = St1[230];
assign o[462] = St0[231];  assign o[463] = St1[231];
assign o[464] = St0[232];  assign o[465] = St1[232];
assign o[466] = St0[233];  assign o[467] = St1[233];
assign o[468] = St0[234];  assign o[469] = St1[234];
assign o[470] = St0[235];  assign o[471] = St1[235];
assign o[472] = St0[236];  assign o[473] = St1[236];
assign o[474] = St0[237];  assign o[475] = St1[237];
assign o[476] = St0[238];  assign o[477] = St1[238];
assign o[478] = St0[239];  assign o[479] = St1[239];
assign o[480] = St0[240];  assign o[481] = St1[240];
assign o[482] = St0[241];  assign o[483] = St1[241];
assign o[484] = St0[242];  assign o[485] = St1[242];
assign o[486] = St0[243];  assign o[487] = St1[243];
assign o[488] = St0[244];  assign o[489] = St1[244];
assign o[490] = St0[245];  assign o[491] = St1[245];
assign o[492] = St0[246];  assign o[493] = St1[246];
assign o[494] = St0[247];  assign o[495] = St1[247];
assign o[496] = St0[248];  assign o[497] = St1[248];
assign o[498] = St0[249];  assign o[499] = St1[249];
assign o[500] = St0[250];  assign o[501] = St1[250];
assign o[502] = St0[251];  assign o[503] = St1[251];
assign o[504] = St0[252];  assign o[505] = St1[252];
assign o[506] = St0[253];  assign o[507] = St1[253];
assign o[508] = St0[254];  assign o[509] = St1[254];
assign o[510] = St0[255];  assign o[511] = St1[255];
assign o[512] = St0[256];  assign o[513] = St1[256];
assign o[514] = St0[257];  assign o[515] = St1[257];
assign o[516] = St0[258];  assign o[517] = St1[258];
assign o[518] = St0[259];  assign o[519] = St1[259];
assign o[520] = St0[260];  assign o[521] = St1[260];
assign o[522] = St0[261];  assign o[523] = St1[261];
assign o[524] = St0[262];  assign o[525] = St1[262];
assign o[526] = St0[263];  assign o[527] = St1[263];
assign o[528] = St0[264];  assign o[529] = St1[264];
assign o[530] = St0[265];  assign o[531] = St1[265];
assign o[532] = St0[266];  assign o[533] = St1[266];
assign o[534] = St0[267];  assign o[535] = St1[267];
assign o[536] = St0[268];  assign o[537] = St1[268];
assign o[538] = St0[269];  assign o[539] = St1[269];
assign o[540] = St0[270];  assign o[541] = St1[270];
assign o[542] = St0[271];  assign o[543] = St1[271];
assign o[544] = St0[272];  assign o[545] = St1[272];
assign o[546] = St0[273];  assign o[547] = St1[273];
assign o[548] = St0[274];  assign o[549] = St1[274];
assign o[550] = St0[275];  assign o[551] = St1[275];
assign o[552] = St0[276];  assign o[553] = St1[276];
assign o[554] = St0[277];  assign o[555] = St1[277];
assign o[556] = St0[278];  assign o[557] = St1[278];
assign o[558] = St0[279];  assign o[559] = St1[279];
assign o[560] = St0[280];  assign o[561] = St1[280];
assign o[562] = St0[281];  assign o[563] = St1[281];
assign o[564] = St0[282];  assign o[565] = St1[282];
assign o[566] = St0[283];  assign o[567] = St1[283];
assign o[568] = St0[284];  assign o[569] = St1[284];
assign o[570] = St0[285];  assign o[571] = St1[285];
assign o[572] = St0[286];  assign o[573] = St1[286];
assign o[574] = St0[287];  assign o[575] = St1[287];
assign o[576] = St0[288];  assign o[577] = St1[288];
assign o[578] = St0[289];  assign o[579] = St1[289];
assign o[580] = St0[290];  assign o[581] = St1[290];
assign o[582] = St0[291];  assign o[583] = St1[291];
assign o[584] = St0[292];  assign o[585] = St1[292];
assign o[586] = St0[293];  assign o[587] = St1[293];
assign o[588] = St0[294];  assign o[589] = St1[294];
assign o[590] = St0[295];  assign o[591] = St1[295];
assign o[592] = St0[296];  assign o[593] = St1[296];
assign o[594] = St0[297];  assign o[595] = St1[297];
assign o[596] = St0[298];  assign o[597] = St1[298];
assign o[598] = St0[299];  assign o[599] = St1[299];
assign o[600] = St0[300];  assign o[601] = St1[300];
assign o[602] = St0[301];  assign o[603] = St1[301];
assign o[604] = St0[302];  assign o[605] = St1[302];
assign o[606] = St0[303];  assign o[607] = St1[303];
assign o[608] = St0[304];  assign o[609] = St1[304];
assign o[610] = St0[305];  assign o[611] = St1[305];
assign o[612] = St0[306];  assign o[613] = St1[306];
assign o[614] = St0[307];  assign o[615] = St1[307];
assign o[616] = St0[308];  assign o[617] = St1[308];
assign o[618] = St0[309];  assign o[619] = St1[309];
assign o[620] = St0[310];  assign o[621] = St1[310];
assign o[622] = St0[311];  assign o[623] = St1[311];
assign o[624] = St0[312];  assign o[625] = St1[312];
assign o[626] = St0[313];  assign o[627] = St1[313];
assign o[628] = St0[314];  assign o[629] = St1[314];
assign o[630] = St0[315];  assign o[631] = St1[315];
assign o[632] = St0[316];  assign o[633] = St1[316];
assign o[634] = St0[317];  assign o[635] = St1[317];
assign o[636] = St0[318];  assign o[637] = St1[318];
assign o[638] = St0[319];  assign o[639] = St1[319];
assign o[640] = St0[320];  assign o[641] = St1[320];
assign o[642] = St0[321];  assign o[643] = St1[321];
assign o[644] = St0[322];  assign o[645] = St1[322];
assign o[646] = St0[323];  assign o[647] = St1[323];
assign o[648] = St0[324];  assign o[649] = St1[324];
assign o[650] = St0[325];  assign o[651] = St1[325];
assign o[652] = St0[326];  assign o[653] = St1[326];
assign o[654] = St0[327];  assign o[655] = St1[327];
assign o[656] = St0[328];  assign o[657] = St1[328];
assign o[658] = St0[329];  assign o[659] = St1[329];
assign o[660] = St0[330];  assign o[661] = St1[330];
assign o[662] = St0[331];  assign o[663] = St1[331];
assign o[664] = St0[332];  assign o[665] = St1[332];
assign o[666] = St0[333];  assign o[667] = St1[333];
assign o[668] = St0[334];  assign o[669] = St1[334];
assign o[670] = St0[335];  assign o[671] = St1[335];
assign o[672] = St0[336];  assign o[673] = St1[336];
assign o[674] = St0[337];  assign o[675] = St1[337];
assign o[676] = St0[338];  assign o[677] = St1[338];
assign o[678] = St0[339];  assign o[679] = St1[339];
assign o[680] = St0[340];  assign o[681] = St1[340];
assign o[682] = St0[341];  assign o[683] = St1[341];
assign o[684] = St0[342];  assign o[685] = St1[342];
assign o[686] = St0[343];  assign o[687] = St1[343];
assign o[688] = St0[344];  assign o[689] = St1[344];
assign o[690] = St0[345];  assign o[691] = St1[345];
assign o[692] = St0[346];  assign o[693] = St1[346];
assign o[694] = St0[347];  assign o[695] = St1[347];
assign o[696] = St0[348];  assign o[697] = St1[348];
assign o[698] = St0[349];  assign o[699] = St1[349];
assign o[700] = St0[350];  assign o[701] = St1[350];
assign o[702] = St0[351];  assign o[703] = St1[351];
assign o[704] = St0[352];  assign o[705] = St1[352];
assign o[706] = St0[353];  assign o[707] = St1[353];
assign o[708] = St0[354];  assign o[709] = St1[354];
assign o[710] = St0[355];  assign o[711] = St1[355];
assign o[712] = St0[356];  assign o[713] = St1[356];
assign o[714] = St0[357];  assign o[715] = St1[357];
assign o[716] = St0[358];  assign o[717] = St1[358];
assign o[718] = St0[359];  assign o[719] = St1[359];
assign o[720] = St0[360];  assign o[721] = St1[360];
assign o[722] = St0[361];  assign o[723] = St1[361];
assign o[724] = St0[362];  assign o[725] = St1[362];
assign o[726] = St0[363];  assign o[727] = St1[363];
assign o[728] = St0[364];  assign o[729] = St1[364];
assign o[730] = St0[365];  assign o[731] = St1[365];
assign o[732] = St0[366];  assign o[733] = St1[366];
assign o[734] = St0[367];  assign o[735] = St1[367];
assign o[736] = St0[368];  assign o[737] = St1[368];
assign o[738] = St0[369];  assign o[739] = St1[369];
assign o[740] = St0[370];  assign o[741] = St1[370];
assign o[742] = St0[371];  assign o[743] = St1[371];
assign o[744] = St0[372];  assign o[745] = St1[372];
assign o[746] = St0[373];  assign o[747] = St1[373];
assign o[748] = St0[374];  assign o[749] = St1[374];
assign o[750] = St0[375];  assign o[751] = St1[375];
assign o[752] = St0[376];  assign o[753] = St1[376];
assign o[754] = St0[377];  assign o[755] = St1[377];
assign o[756] = St0[378];  assign o[757] = St1[378];
assign o[758] = St0[379];  assign o[759] = St1[379];
assign o[760] = St0[380];  assign o[761] = St1[380];
assign o[762] = St0[381];  assign o[763] = St1[381];
assign o[764] = St0[382];  assign o[765] = St1[382];
assign o[766] = St0[383];  assign o[767] = St1[383];
assign o[768] = St0[384];  assign o[769] = St1[384];
assign o[770] = St0[385];  assign o[771] = St1[385];
assign o[772] = St0[386];  assign o[773] = St1[386];
assign o[774] = St0[387];  assign o[775] = St1[387];
assign o[776] = St0[388];  assign o[777] = St1[388];
assign o[778] = St0[389];  assign o[779] = St1[389];
assign o[780] = St0[390];  assign o[781] = St1[390];
assign o[782] = St0[391];  assign o[783] = St1[391];
assign o[784] = St0[392];  assign o[785] = St1[392];
assign o[786] = St0[393];  assign o[787] = St1[393];
assign o[788] = St0[394];  assign o[789] = St1[394];
assign o[790] = St0[395];  assign o[791] = St1[395];
assign o[792] = St0[396];  assign o[793] = St1[396];
assign o[794] = St0[397];  assign o[795] = St1[397];
assign o[796] = St0[398];  assign o[797] = St1[398];
assign o[798] = St0[399];  assign o[799] = St1[399];

endmodule
