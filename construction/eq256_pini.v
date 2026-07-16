// LABEL CONTROL (EXPECTED PASS, single-pass): identical to eq256 but
// instantiates the PINI-relabelled leaf MSKand_opini2_d2_pini. Single-pass
// => PINI composition already suffices => PASS. Recorded, NOT counted as
// non-vacuity (same reasoning as iszero256_pini).
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module eq256_pini (clk, rst, go, a, b, r, s, out);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [511:0] a;
(* matchi_type = "sharings_dense", matchi_active = "b_act" *) input [511:0] b;
(* matchi_type = "random", matchi_active = "r_act" *) input [255:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [255:0] s;
(* matchi_type = "sharing", matchi_active = "out_act" *) output [1:0] out;

// ---- activity shift register (single go-pulse propagated; E=32 overlapped execs) ----
(* keep *) wire act0 = go;
(* keep *) reg [72:1] actr;
always @(posedge clk) begin
    if (rst) actr <= 72'b0;
    else     actr <= {actr[71:1], act0};
end
wire [72:0] act = {actr, act0};
(* keep *) wire a_act   = |act[40:0];
(* keep *) wire b_act   = |act[40:0];
(* keep *) wire r_act   = |act[68:0];
(* keep *) wire s_act   = |act[69:1];
(* keep *) wire out_act = |act[72:0];

// ---- EQ input stage: d = A XOR B, SHARE-LOCAL (d_s = a_s ^ b_s for each
// share s — matching shares of two different sharings; never two shares of
// the same secret; zero gadgets). d == 0 iff A == B. ----

wire d0_0 = a[0] ^ b[0];  wire d1_0 = a[1] ^ b[1];
wire d0_1 = a[2] ^ b[2];  wire d1_1 = a[3] ^ b[3];
wire d0_2 = a[4] ^ b[4];  wire d1_2 = a[5] ^ b[5];
wire d0_3 = a[6] ^ b[6];  wire d1_3 = a[7] ^ b[7];
wire d0_4 = a[8] ^ b[8];  wire d1_4 = a[9] ^ b[9];
wire d0_5 = a[10] ^ b[10];  wire d1_5 = a[11] ^ b[11];
wire d0_6 = a[12] ^ b[12];  wire d1_6 = a[13] ^ b[13];
wire d0_7 = a[14] ^ b[14];  wire d1_7 = a[15] ^ b[15];
wire d0_8 = a[16] ^ b[16];  wire d1_8 = a[17] ^ b[17];
wire d0_9 = a[18] ^ b[18];  wire d1_9 = a[19] ^ b[19];
wire d0_10 = a[20] ^ b[20];  wire d1_10 = a[21] ^ b[21];
wire d0_11 = a[22] ^ b[22];  wire d1_11 = a[23] ^ b[23];
wire d0_12 = a[24] ^ b[24];  wire d1_12 = a[25] ^ b[25];
wire d0_13 = a[26] ^ b[26];  wire d1_13 = a[27] ^ b[27];
wire d0_14 = a[28] ^ b[28];  wire d1_14 = a[29] ^ b[29];
wire d0_15 = a[30] ^ b[30];  wire d1_15 = a[31] ^ b[31];
wire d0_16 = a[32] ^ b[32];  wire d1_16 = a[33] ^ b[33];
wire d0_17 = a[34] ^ b[34];  wire d1_17 = a[35] ^ b[35];
wire d0_18 = a[36] ^ b[36];  wire d1_18 = a[37] ^ b[37];
wire d0_19 = a[38] ^ b[38];  wire d1_19 = a[39] ^ b[39];
wire d0_20 = a[40] ^ b[40];  wire d1_20 = a[41] ^ b[41];
wire d0_21 = a[42] ^ b[42];  wire d1_21 = a[43] ^ b[43];
wire d0_22 = a[44] ^ b[44];  wire d1_22 = a[45] ^ b[45];
wire d0_23 = a[46] ^ b[46];  wire d1_23 = a[47] ^ b[47];
wire d0_24 = a[48] ^ b[48];  wire d1_24 = a[49] ^ b[49];
wire d0_25 = a[50] ^ b[50];  wire d1_25 = a[51] ^ b[51];
wire d0_26 = a[52] ^ b[52];  wire d1_26 = a[53] ^ b[53];
wire d0_27 = a[54] ^ b[54];  wire d1_27 = a[55] ^ b[55];
wire d0_28 = a[56] ^ b[56];  wire d1_28 = a[57] ^ b[57];
wire d0_29 = a[58] ^ b[58];  wire d1_29 = a[59] ^ b[59];
wire d0_30 = a[60] ^ b[60];  wire d1_30 = a[61] ^ b[61];
wire d0_31 = a[62] ^ b[62];  wire d1_31 = a[63] ^ b[63];
wire d0_32 = a[64] ^ b[64];  wire d1_32 = a[65] ^ b[65];
wire d0_33 = a[66] ^ b[66];  wire d1_33 = a[67] ^ b[67];
wire d0_34 = a[68] ^ b[68];  wire d1_34 = a[69] ^ b[69];
wire d0_35 = a[70] ^ b[70];  wire d1_35 = a[71] ^ b[71];
wire d0_36 = a[72] ^ b[72];  wire d1_36 = a[73] ^ b[73];
wire d0_37 = a[74] ^ b[74];  wire d1_37 = a[75] ^ b[75];
wire d0_38 = a[76] ^ b[76];  wire d1_38 = a[77] ^ b[77];
wire d0_39 = a[78] ^ b[78];  wire d1_39 = a[79] ^ b[79];
wire d0_40 = a[80] ^ b[80];  wire d1_40 = a[81] ^ b[81];
wire d0_41 = a[82] ^ b[82];  wire d1_41 = a[83] ^ b[83];
wire d0_42 = a[84] ^ b[84];  wire d1_42 = a[85] ^ b[85];
wire d0_43 = a[86] ^ b[86];  wire d1_43 = a[87] ^ b[87];
wire d0_44 = a[88] ^ b[88];  wire d1_44 = a[89] ^ b[89];
wire d0_45 = a[90] ^ b[90];  wire d1_45 = a[91] ^ b[91];
wire d0_46 = a[92] ^ b[92];  wire d1_46 = a[93] ^ b[93];
wire d0_47 = a[94] ^ b[94];  wire d1_47 = a[95] ^ b[95];
wire d0_48 = a[96] ^ b[96];  wire d1_48 = a[97] ^ b[97];
wire d0_49 = a[98] ^ b[98];  wire d1_49 = a[99] ^ b[99];
wire d0_50 = a[100] ^ b[100];  wire d1_50 = a[101] ^ b[101];
wire d0_51 = a[102] ^ b[102];  wire d1_51 = a[103] ^ b[103];
wire d0_52 = a[104] ^ b[104];  wire d1_52 = a[105] ^ b[105];
wire d0_53 = a[106] ^ b[106];  wire d1_53 = a[107] ^ b[107];
wire d0_54 = a[108] ^ b[108];  wire d1_54 = a[109] ^ b[109];
wire d0_55 = a[110] ^ b[110];  wire d1_55 = a[111] ^ b[111];
wire d0_56 = a[112] ^ b[112];  wire d1_56 = a[113] ^ b[113];
wire d0_57 = a[114] ^ b[114];  wire d1_57 = a[115] ^ b[115];
wire d0_58 = a[116] ^ b[116];  wire d1_58 = a[117] ^ b[117];
wire d0_59 = a[118] ^ b[118];  wire d1_59 = a[119] ^ b[119];
wire d0_60 = a[120] ^ b[120];  wire d1_60 = a[121] ^ b[121];
wire d0_61 = a[122] ^ b[122];  wire d1_61 = a[123] ^ b[123];
wire d0_62 = a[124] ^ b[124];  wire d1_62 = a[125] ^ b[125];
wire d0_63 = a[126] ^ b[126];  wire d1_63 = a[127] ^ b[127];
wire d0_64 = a[128] ^ b[128];  wire d1_64 = a[129] ^ b[129];
wire d0_65 = a[130] ^ b[130];  wire d1_65 = a[131] ^ b[131];
wire d0_66 = a[132] ^ b[132];  wire d1_66 = a[133] ^ b[133];
wire d0_67 = a[134] ^ b[134];  wire d1_67 = a[135] ^ b[135];
wire d0_68 = a[136] ^ b[136];  wire d1_68 = a[137] ^ b[137];
wire d0_69 = a[138] ^ b[138];  wire d1_69 = a[139] ^ b[139];
wire d0_70 = a[140] ^ b[140];  wire d1_70 = a[141] ^ b[141];
wire d0_71 = a[142] ^ b[142];  wire d1_71 = a[143] ^ b[143];
wire d0_72 = a[144] ^ b[144];  wire d1_72 = a[145] ^ b[145];
wire d0_73 = a[146] ^ b[146];  wire d1_73 = a[147] ^ b[147];
wire d0_74 = a[148] ^ b[148];  wire d1_74 = a[149] ^ b[149];
wire d0_75 = a[150] ^ b[150];  wire d1_75 = a[151] ^ b[151];
wire d0_76 = a[152] ^ b[152];  wire d1_76 = a[153] ^ b[153];
wire d0_77 = a[154] ^ b[154];  wire d1_77 = a[155] ^ b[155];
wire d0_78 = a[156] ^ b[156];  wire d1_78 = a[157] ^ b[157];
wire d0_79 = a[158] ^ b[158];  wire d1_79 = a[159] ^ b[159];
wire d0_80 = a[160] ^ b[160];  wire d1_80 = a[161] ^ b[161];
wire d0_81 = a[162] ^ b[162];  wire d1_81 = a[163] ^ b[163];
wire d0_82 = a[164] ^ b[164];  wire d1_82 = a[165] ^ b[165];
wire d0_83 = a[166] ^ b[166];  wire d1_83 = a[167] ^ b[167];
wire d0_84 = a[168] ^ b[168];  wire d1_84 = a[169] ^ b[169];
wire d0_85 = a[170] ^ b[170];  wire d1_85 = a[171] ^ b[171];
wire d0_86 = a[172] ^ b[172];  wire d1_86 = a[173] ^ b[173];
wire d0_87 = a[174] ^ b[174];  wire d1_87 = a[175] ^ b[175];
wire d0_88 = a[176] ^ b[176];  wire d1_88 = a[177] ^ b[177];
wire d0_89 = a[178] ^ b[178];  wire d1_89 = a[179] ^ b[179];
wire d0_90 = a[180] ^ b[180];  wire d1_90 = a[181] ^ b[181];
wire d0_91 = a[182] ^ b[182];  wire d1_91 = a[183] ^ b[183];
wire d0_92 = a[184] ^ b[184];  wire d1_92 = a[185] ^ b[185];
wire d0_93 = a[186] ^ b[186];  wire d1_93 = a[187] ^ b[187];
wire d0_94 = a[188] ^ b[188];  wire d1_94 = a[189] ^ b[189];
wire d0_95 = a[190] ^ b[190];  wire d1_95 = a[191] ^ b[191];
wire d0_96 = a[192] ^ b[192];  wire d1_96 = a[193] ^ b[193];
wire d0_97 = a[194] ^ b[194];  wire d1_97 = a[195] ^ b[195];
wire d0_98 = a[196] ^ b[196];  wire d1_98 = a[197] ^ b[197];
wire d0_99 = a[198] ^ b[198];  wire d1_99 = a[199] ^ b[199];
wire d0_100 = a[200] ^ b[200];  wire d1_100 = a[201] ^ b[201];
wire d0_101 = a[202] ^ b[202];  wire d1_101 = a[203] ^ b[203];
wire d0_102 = a[204] ^ b[204];  wire d1_102 = a[205] ^ b[205];
wire d0_103 = a[206] ^ b[206];  wire d1_103 = a[207] ^ b[207];
wire d0_104 = a[208] ^ b[208];  wire d1_104 = a[209] ^ b[209];
wire d0_105 = a[210] ^ b[210];  wire d1_105 = a[211] ^ b[211];
wire d0_106 = a[212] ^ b[212];  wire d1_106 = a[213] ^ b[213];
wire d0_107 = a[214] ^ b[214];  wire d1_107 = a[215] ^ b[215];
wire d0_108 = a[216] ^ b[216];  wire d1_108 = a[217] ^ b[217];
wire d0_109 = a[218] ^ b[218];  wire d1_109 = a[219] ^ b[219];
wire d0_110 = a[220] ^ b[220];  wire d1_110 = a[221] ^ b[221];
wire d0_111 = a[222] ^ b[222];  wire d1_111 = a[223] ^ b[223];
wire d0_112 = a[224] ^ b[224];  wire d1_112 = a[225] ^ b[225];
wire d0_113 = a[226] ^ b[226];  wire d1_113 = a[227] ^ b[227];
wire d0_114 = a[228] ^ b[228];  wire d1_114 = a[229] ^ b[229];
wire d0_115 = a[230] ^ b[230];  wire d1_115 = a[231] ^ b[231];
wire d0_116 = a[232] ^ b[232];  wire d1_116 = a[233] ^ b[233];
wire d0_117 = a[234] ^ b[234];  wire d1_117 = a[235] ^ b[235];
wire d0_118 = a[236] ^ b[236];  wire d1_118 = a[237] ^ b[237];
wire d0_119 = a[238] ^ b[238];  wire d1_119 = a[239] ^ b[239];
wire d0_120 = a[240] ^ b[240];  wire d1_120 = a[241] ^ b[241];
wire d0_121 = a[242] ^ b[242];  wire d1_121 = a[243] ^ b[243];
wire d0_122 = a[244] ^ b[244];  wire d1_122 = a[245] ^ b[245];
wire d0_123 = a[246] ^ b[246];  wire d1_123 = a[247] ^ b[247];
wire d0_124 = a[248] ^ b[248];  wire d1_124 = a[249] ^ b[249];
wire d0_125 = a[250] ^ b[250];  wire d1_125 = a[251] ^ b[251];
wire d0_126 = a[252] ^ b[252];  wire d1_126 = a[253] ^ b[253];
wire d0_127 = a[254] ^ b[254];  wire d1_127 = a[255] ^ b[255];
wire d0_128 = a[256] ^ b[256];  wire d1_128 = a[257] ^ b[257];
wire d0_129 = a[258] ^ b[258];  wire d1_129 = a[259] ^ b[259];
wire d0_130 = a[260] ^ b[260];  wire d1_130 = a[261] ^ b[261];
wire d0_131 = a[262] ^ b[262];  wire d1_131 = a[263] ^ b[263];
wire d0_132 = a[264] ^ b[264];  wire d1_132 = a[265] ^ b[265];
wire d0_133 = a[266] ^ b[266];  wire d1_133 = a[267] ^ b[267];
wire d0_134 = a[268] ^ b[268];  wire d1_134 = a[269] ^ b[269];
wire d0_135 = a[270] ^ b[270];  wire d1_135 = a[271] ^ b[271];
wire d0_136 = a[272] ^ b[272];  wire d1_136 = a[273] ^ b[273];
wire d0_137 = a[274] ^ b[274];  wire d1_137 = a[275] ^ b[275];
wire d0_138 = a[276] ^ b[276];  wire d1_138 = a[277] ^ b[277];
wire d0_139 = a[278] ^ b[278];  wire d1_139 = a[279] ^ b[279];
wire d0_140 = a[280] ^ b[280];  wire d1_140 = a[281] ^ b[281];
wire d0_141 = a[282] ^ b[282];  wire d1_141 = a[283] ^ b[283];
wire d0_142 = a[284] ^ b[284];  wire d1_142 = a[285] ^ b[285];
wire d0_143 = a[286] ^ b[286];  wire d1_143 = a[287] ^ b[287];
wire d0_144 = a[288] ^ b[288];  wire d1_144 = a[289] ^ b[289];
wire d0_145 = a[290] ^ b[290];  wire d1_145 = a[291] ^ b[291];
wire d0_146 = a[292] ^ b[292];  wire d1_146 = a[293] ^ b[293];
wire d0_147 = a[294] ^ b[294];  wire d1_147 = a[295] ^ b[295];
wire d0_148 = a[296] ^ b[296];  wire d1_148 = a[297] ^ b[297];
wire d0_149 = a[298] ^ b[298];  wire d1_149 = a[299] ^ b[299];
wire d0_150 = a[300] ^ b[300];  wire d1_150 = a[301] ^ b[301];
wire d0_151 = a[302] ^ b[302];  wire d1_151 = a[303] ^ b[303];
wire d0_152 = a[304] ^ b[304];  wire d1_152 = a[305] ^ b[305];
wire d0_153 = a[306] ^ b[306];  wire d1_153 = a[307] ^ b[307];
wire d0_154 = a[308] ^ b[308];  wire d1_154 = a[309] ^ b[309];
wire d0_155 = a[310] ^ b[310];  wire d1_155 = a[311] ^ b[311];
wire d0_156 = a[312] ^ b[312];  wire d1_156 = a[313] ^ b[313];
wire d0_157 = a[314] ^ b[314];  wire d1_157 = a[315] ^ b[315];
wire d0_158 = a[316] ^ b[316];  wire d1_158 = a[317] ^ b[317];
wire d0_159 = a[318] ^ b[318];  wire d1_159 = a[319] ^ b[319];
wire d0_160 = a[320] ^ b[320];  wire d1_160 = a[321] ^ b[321];
wire d0_161 = a[322] ^ b[322];  wire d1_161 = a[323] ^ b[323];
wire d0_162 = a[324] ^ b[324];  wire d1_162 = a[325] ^ b[325];
wire d0_163 = a[326] ^ b[326];  wire d1_163 = a[327] ^ b[327];
wire d0_164 = a[328] ^ b[328];  wire d1_164 = a[329] ^ b[329];
wire d0_165 = a[330] ^ b[330];  wire d1_165 = a[331] ^ b[331];
wire d0_166 = a[332] ^ b[332];  wire d1_166 = a[333] ^ b[333];
wire d0_167 = a[334] ^ b[334];  wire d1_167 = a[335] ^ b[335];
wire d0_168 = a[336] ^ b[336];  wire d1_168 = a[337] ^ b[337];
wire d0_169 = a[338] ^ b[338];  wire d1_169 = a[339] ^ b[339];
wire d0_170 = a[340] ^ b[340];  wire d1_170 = a[341] ^ b[341];
wire d0_171 = a[342] ^ b[342];  wire d1_171 = a[343] ^ b[343];
wire d0_172 = a[344] ^ b[344];  wire d1_172 = a[345] ^ b[345];
wire d0_173 = a[346] ^ b[346];  wire d1_173 = a[347] ^ b[347];
wire d0_174 = a[348] ^ b[348];  wire d1_174 = a[349] ^ b[349];
wire d0_175 = a[350] ^ b[350];  wire d1_175 = a[351] ^ b[351];
wire d0_176 = a[352] ^ b[352];  wire d1_176 = a[353] ^ b[353];
wire d0_177 = a[354] ^ b[354];  wire d1_177 = a[355] ^ b[355];
wire d0_178 = a[356] ^ b[356];  wire d1_178 = a[357] ^ b[357];
wire d0_179 = a[358] ^ b[358];  wire d1_179 = a[359] ^ b[359];
wire d0_180 = a[360] ^ b[360];  wire d1_180 = a[361] ^ b[361];
wire d0_181 = a[362] ^ b[362];  wire d1_181 = a[363] ^ b[363];
wire d0_182 = a[364] ^ b[364];  wire d1_182 = a[365] ^ b[365];
wire d0_183 = a[366] ^ b[366];  wire d1_183 = a[367] ^ b[367];
wire d0_184 = a[368] ^ b[368];  wire d1_184 = a[369] ^ b[369];
wire d0_185 = a[370] ^ b[370];  wire d1_185 = a[371] ^ b[371];
wire d0_186 = a[372] ^ b[372];  wire d1_186 = a[373] ^ b[373];
wire d0_187 = a[374] ^ b[374];  wire d1_187 = a[375] ^ b[375];
wire d0_188 = a[376] ^ b[376];  wire d1_188 = a[377] ^ b[377];
wire d0_189 = a[378] ^ b[378];  wire d1_189 = a[379] ^ b[379];
wire d0_190 = a[380] ^ b[380];  wire d1_190 = a[381] ^ b[381];
wire d0_191 = a[382] ^ b[382];  wire d1_191 = a[383] ^ b[383];
wire d0_192 = a[384] ^ b[384];  wire d1_192 = a[385] ^ b[385];
wire d0_193 = a[386] ^ b[386];  wire d1_193 = a[387] ^ b[387];
wire d0_194 = a[388] ^ b[388];  wire d1_194 = a[389] ^ b[389];
wire d0_195 = a[390] ^ b[390];  wire d1_195 = a[391] ^ b[391];
wire d0_196 = a[392] ^ b[392];  wire d1_196 = a[393] ^ b[393];
wire d0_197 = a[394] ^ b[394];  wire d1_197 = a[395] ^ b[395];
wire d0_198 = a[396] ^ b[396];  wire d1_198 = a[397] ^ b[397];
wire d0_199 = a[398] ^ b[398];  wire d1_199 = a[399] ^ b[399];
wire d0_200 = a[400] ^ b[400];  wire d1_200 = a[401] ^ b[401];
wire d0_201 = a[402] ^ b[402];  wire d1_201 = a[403] ^ b[403];
wire d0_202 = a[404] ^ b[404];  wire d1_202 = a[405] ^ b[405];
wire d0_203 = a[406] ^ b[406];  wire d1_203 = a[407] ^ b[407];
wire d0_204 = a[408] ^ b[408];  wire d1_204 = a[409] ^ b[409];
wire d0_205 = a[410] ^ b[410];  wire d1_205 = a[411] ^ b[411];
wire d0_206 = a[412] ^ b[412];  wire d1_206 = a[413] ^ b[413];
wire d0_207 = a[414] ^ b[414];  wire d1_207 = a[415] ^ b[415];
wire d0_208 = a[416] ^ b[416];  wire d1_208 = a[417] ^ b[417];
wire d0_209 = a[418] ^ b[418];  wire d1_209 = a[419] ^ b[419];
wire d0_210 = a[420] ^ b[420];  wire d1_210 = a[421] ^ b[421];
wire d0_211 = a[422] ^ b[422];  wire d1_211 = a[423] ^ b[423];
wire d0_212 = a[424] ^ b[424];  wire d1_212 = a[425] ^ b[425];
wire d0_213 = a[426] ^ b[426];  wire d1_213 = a[427] ^ b[427];
wire d0_214 = a[428] ^ b[428];  wire d1_214 = a[429] ^ b[429];
wire d0_215 = a[430] ^ b[430];  wire d1_215 = a[431] ^ b[431];
wire d0_216 = a[432] ^ b[432];  wire d1_216 = a[433] ^ b[433];
wire d0_217 = a[434] ^ b[434];  wire d1_217 = a[435] ^ b[435];
wire d0_218 = a[436] ^ b[436];  wire d1_218 = a[437] ^ b[437];
wire d0_219 = a[438] ^ b[438];  wire d1_219 = a[439] ^ b[439];
wire d0_220 = a[440] ^ b[440];  wire d1_220 = a[441] ^ b[441];
wire d0_221 = a[442] ^ b[442];  wire d1_221 = a[443] ^ b[443];
wire d0_222 = a[444] ^ b[444];  wire d1_222 = a[445] ^ b[445];
wire d0_223 = a[446] ^ b[446];  wire d1_223 = a[447] ^ b[447];
wire d0_224 = a[448] ^ b[448];  wire d1_224 = a[449] ^ b[449];
wire d0_225 = a[450] ^ b[450];  wire d1_225 = a[451] ^ b[451];
wire d0_226 = a[452] ^ b[452];  wire d1_226 = a[453] ^ b[453];
wire d0_227 = a[454] ^ b[454];  wire d1_227 = a[455] ^ b[455];
wire d0_228 = a[456] ^ b[456];  wire d1_228 = a[457] ^ b[457];
wire d0_229 = a[458] ^ b[458];  wire d1_229 = a[459] ^ b[459];
wire d0_230 = a[460] ^ b[460];  wire d1_230 = a[461] ^ b[461];
wire d0_231 = a[462] ^ b[462];  wire d1_231 = a[463] ^ b[463];
wire d0_232 = a[464] ^ b[464];  wire d1_232 = a[465] ^ b[465];
wire d0_233 = a[466] ^ b[466];  wire d1_233 = a[467] ^ b[467];
wire d0_234 = a[468] ^ b[468];  wire d1_234 = a[469] ^ b[469];
wire d0_235 = a[470] ^ b[470];  wire d1_235 = a[471] ^ b[471];
wire d0_236 = a[472] ^ b[472];  wire d1_236 = a[473] ^ b[473];
wire d0_237 = a[474] ^ b[474];  wire d1_237 = a[475] ^ b[475];
wire d0_238 = a[476] ^ b[476];  wire d1_238 = a[477] ^ b[477];
wire d0_239 = a[478] ^ b[478];  wire d1_239 = a[479] ^ b[479];
wire d0_240 = a[480] ^ b[480];  wire d1_240 = a[481] ^ b[481];
wire d0_241 = a[482] ^ b[482];  wire d1_241 = a[483] ^ b[483];
wire d0_242 = a[484] ^ b[484];  wire d1_242 = a[485] ^ b[485];
wire d0_243 = a[486] ^ b[486];  wire d1_243 = a[487] ^ b[487];
wire d0_244 = a[488] ^ b[488];  wire d1_244 = a[489] ^ b[489];
wire d0_245 = a[490] ^ b[490];  wire d1_245 = a[491] ^ b[491];
wire d0_246 = a[492] ^ b[492];  wire d1_246 = a[493] ^ b[493];
wire d0_247 = a[494] ^ b[494];  wire d1_247 = a[495] ^ b[495];
wire d0_248 = a[496] ^ b[496];  wire d1_248 = a[497] ^ b[497];
wire d0_249 = a[498] ^ b[498];  wire d1_249 = a[499] ^ b[499];
wire d0_250 = a[500] ^ b[500];  wire d1_250 = a[501] ^ b[501];
wire d0_251 = a[502] ^ b[502];  wire d1_251 = a[503] ^ b[503];
wire d0_252 = a[504] ^ b[504];  wire d1_252 = a[505] ^ b[505];
wire d0_253 = a[506] ^ b[506];  wire d1_253 = a[507] ^ b[507];
wire d0_254 = a[508] ^ b[508];  wire d1_254 = a[509] ^ b[509];
wire d0_255 = a[510] ^ b[510];  wire d1_255 = a[511] ^ b[511];

// ===== OR-reduce level 0: 256 masked bits -> 128 =====
wire nx0_0 = d0_0 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_0 = d0_1 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_0, ina1_0;
always @(posedge clk) begin
    ina0_0 <= nx0_0;
    ina1_0 <= d1_0;
end
wire w0_0, w1_0;
MSKand_opini2_d2_pini u_or_0 (
    .ina({ina1_0, ina0_0}), .inb({d1_1, ny0_0}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({w1_0, w0_0}));
wire or0_0 = w0_0 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_0 = w1_0;
wire nx0_1 = d0_2 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_1 = d0_3 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_1, ina1_1;
always @(posedge clk) begin
    ina0_1 <= nx0_1;
    ina1_1 <= d1_2;
end
wire w0_1, w1_1;
MSKand_opini2_d2_pini u_or_1 (
    .ina({ina1_1, ina0_1}), .inb({d1_3, ny0_1}),
    .rnd(r[1]), .s(s[1]), .clk(clk), .out({w1_1, w0_1}));
wire or0_1 = w0_1 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_1 = w1_1;
wire nx0_2 = d0_4 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_2 = d0_5 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_2, ina1_2;
always @(posedge clk) begin
    ina0_2 <= nx0_2;
    ina1_2 <= d1_4;
end
wire w0_2, w1_2;
MSKand_opini2_d2_pini u_or_2 (
    .ina({ina1_2, ina0_2}), .inb({d1_5, ny0_2}),
    .rnd(r[2]), .s(s[2]), .clk(clk), .out({w1_2, w0_2}));
wire or0_2 = w0_2 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_2 = w1_2;
wire nx0_3 = d0_6 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_3 = d0_7 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_3, ina1_3;
always @(posedge clk) begin
    ina0_3 <= nx0_3;
    ina1_3 <= d1_6;
end
wire w0_3, w1_3;
MSKand_opini2_d2_pini u_or_3 (
    .ina({ina1_3, ina0_3}), .inb({d1_7, ny0_3}),
    .rnd(r[3]), .s(s[3]), .clk(clk), .out({w1_3, w0_3}));
wire or0_3 = w0_3 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_3 = w1_3;
wire nx0_4 = d0_8 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_4 = d0_9 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_4, ina1_4;
always @(posedge clk) begin
    ina0_4 <= nx0_4;
    ina1_4 <= d1_8;
end
wire w0_4, w1_4;
MSKand_opini2_d2_pini u_or_4 (
    .ina({ina1_4, ina0_4}), .inb({d1_9, ny0_4}),
    .rnd(r[4]), .s(s[4]), .clk(clk), .out({w1_4, w0_4}));
wire or0_4 = w0_4 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_4 = w1_4;
wire nx0_5 = d0_10 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_5 = d0_11 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_5, ina1_5;
always @(posedge clk) begin
    ina0_5 <= nx0_5;
    ina1_5 <= d1_10;
end
wire w0_5, w1_5;
MSKand_opini2_d2_pini u_or_5 (
    .ina({ina1_5, ina0_5}), .inb({d1_11, ny0_5}),
    .rnd(r[5]), .s(s[5]), .clk(clk), .out({w1_5, w0_5}));
wire or0_5 = w0_5 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_5 = w1_5;
wire nx0_6 = d0_12 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_6 = d0_13 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_6, ina1_6;
always @(posedge clk) begin
    ina0_6 <= nx0_6;
    ina1_6 <= d1_12;
end
wire w0_6, w1_6;
MSKand_opini2_d2_pini u_or_6 (
    .ina({ina1_6, ina0_6}), .inb({d1_13, ny0_6}),
    .rnd(r[6]), .s(s[6]), .clk(clk), .out({w1_6, w0_6}));
wire or0_6 = w0_6 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_6 = w1_6;
wire nx0_7 = d0_14 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_7 = d0_15 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_7, ina1_7;
always @(posedge clk) begin
    ina0_7 <= nx0_7;
    ina1_7 <= d1_14;
end
wire w0_7, w1_7;
MSKand_opini2_d2_pini u_or_7 (
    .ina({ina1_7, ina0_7}), .inb({d1_15, ny0_7}),
    .rnd(r[7]), .s(s[7]), .clk(clk), .out({w1_7, w0_7}));
wire or0_7 = w0_7 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_7 = w1_7;
wire nx0_8 = d0_16 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_8 = d0_17 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_8, ina1_8;
always @(posedge clk) begin
    ina0_8 <= nx0_8;
    ina1_8 <= d1_16;
end
wire w0_8, w1_8;
MSKand_opini2_d2_pini u_or_8 (
    .ina({ina1_8, ina0_8}), .inb({d1_17, ny0_8}),
    .rnd(r[8]), .s(s[8]), .clk(clk), .out({w1_8, w0_8}));
wire or0_8 = w0_8 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_8 = w1_8;
wire nx0_9 = d0_18 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_9 = d0_19 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_9, ina1_9;
always @(posedge clk) begin
    ina0_9 <= nx0_9;
    ina1_9 <= d1_18;
end
wire w0_9, w1_9;
MSKand_opini2_d2_pini u_or_9 (
    .ina({ina1_9, ina0_9}), .inb({d1_19, ny0_9}),
    .rnd(r[9]), .s(s[9]), .clk(clk), .out({w1_9, w0_9}));
wire or0_9 = w0_9 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_9 = w1_9;
wire nx0_10 = d0_20 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_10 = d0_21 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_10, ina1_10;
always @(posedge clk) begin
    ina0_10 <= nx0_10;
    ina1_10 <= d1_20;
end
wire w0_10, w1_10;
MSKand_opini2_d2_pini u_or_10 (
    .ina({ina1_10, ina0_10}), .inb({d1_21, ny0_10}),
    .rnd(r[10]), .s(s[10]), .clk(clk), .out({w1_10, w0_10}));
wire or0_10 = w0_10 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_10 = w1_10;
wire nx0_11 = d0_22 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_11 = d0_23 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_11, ina1_11;
always @(posedge clk) begin
    ina0_11 <= nx0_11;
    ina1_11 <= d1_22;
end
wire w0_11, w1_11;
MSKand_opini2_d2_pini u_or_11 (
    .ina({ina1_11, ina0_11}), .inb({d1_23, ny0_11}),
    .rnd(r[11]), .s(s[11]), .clk(clk), .out({w1_11, w0_11}));
wire or0_11 = w0_11 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_11 = w1_11;
wire nx0_12 = d0_24 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_12 = d0_25 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_12, ina1_12;
always @(posedge clk) begin
    ina0_12 <= nx0_12;
    ina1_12 <= d1_24;
end
wire w0_12, w1_12;
MSKand_opini2_d2_pini u_or_12 (
    .ina({ina1_12, ina0_12}), .inb({d1_25, ny0_12}),
    .rnd(r[12]), .s(s[12]), .clk(clk), .out({w1_12, w0_12}));
wire or0_12 = w0_12 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_12 = w1_12;
wire nx0_13 = d0_26 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_13 = d0_27 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_13, ina1_13;
always @(posedge clk) begin
    ina0_13 <= nx0_13;
    ina1_13 <= d1_26;
end
wire w0_13, w1_13;
MSKand_opini2_d2_pini u_or_13 (
    .ina({ina1_13, ina0_13}), .inb({d1_27, ny0_13}),
    .rnd(r[13]), .s(s[13]), .clk(clk), .out({w1_13, w0_13}));
wire or0_13 = w0_13 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_13 = w1_13;
wire nx0_14 = d0_28 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_14 = d0_29 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_14, ina1_14;
always @(posedge clk) begin
    ina0_14 <= nx0_14;
    ina1_14 <= d1_28;
end
wire w0_14, w1_14;
MSKand_opini2_d2_pini u_or_14 (
    .ina({ina1_14, ina0_14}), .inb({d1_29, ny0_14}),
    .rnd(r[14]), .s(s[14]), .clk(clk), .out({w1_14, w0_14}));
wire or0_14 = w0_14 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_14 = w1_14;
wire nx0_15 = d0_30 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_15 = d0_31 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_15, ina1_15;
always @(posedge clk) begin
    ina0_15 <= nx0_15;
    ina1_15 <= d1_30;
end
wire w0_15, w1_15;
MSKand_opini2_d2_pini u_or_15 (
    .ina({ina1_15, ina0_15}), .inb({d1_31, ny0_15}),
    .rnd(r[15]), .s(s[15]), .clk(clk), .out({w1_15, w0_15}));
wire or0_15 = w0_15 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_15 = w1_15;
wire nx0_16 = d0_32 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_16 = d0_33 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_16, ina1_16;
always @(posedge clk) begin
    ina0_16 <= nx0_16;
    ina1_16 <= d1_32;
end
wire w0_16, w1_16;
MSKand_opini2_d2_pini u_or_16 (
    .ina({ina1_16, ina0_16}), .inb({d1_33, ny0_16}),
    .rnd(r[16]), .s(s[16]), .clk(clk), .out({w1_16, w0_16}));
wire or0_16 = w0_16 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_16 = w1_16;
wire nx0_17 = d0_34 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_17 = d0_35 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_17, ina1_17;
always @(posedge clk) begin
    ina0_17 <= nx0_17;
    ina1_17 <= d1_34;
end
wire w0_17, w1_17;
MSKand_opini2_d2_pini u_or_17 (
    .ina({ina1_17, ina0_17}), .inb({d1_35, ny0_17}),
    .rnd(r[17]), .s(s[17]), .clk(clk), .out({w1_17, w0_17}));
wire or0_17 = w0_17 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_17 = w1_17;
wire nx0_18 = d0_36 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_18 = d0_37 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_18, ina1_18;
always @(posedge clk) begin
    ina0_18 <= nx0_18;
    ina1_18 <= d1_36;
end
wire w0_18, w1_18;
MSKand_opini2_d2_pini u_or_18 (
    .ina({ina1_18, ina0_18}), .inb({d1_37, ny0_18}),
    .rnd(r[18]), .s(s[18]), .clk(clk), .out({w1_18, w0_18}));
wire or0_18 = w0_18 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_18 = w1_18;
wire nx0_19 = d0_38 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_19 = d0_39 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_19, ina1_19;
always @(posedge clk) begin
    ina0_19 <= nx0_19;
    ina1_19 <= d1_38;
end
wire w0_19, w1_19;
MSKand_opini2_d2_pini u_or_19 (
    .ina({ina1_19, ina0_19}), .inb({d1_39, ny0_19}),
    .rnd(r[19]), .s(s[19]), .clk(clk), .out({w1_19, w0_19}));
wire or0_19 = w0_19 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_19 = w1_19;
wire nx0_20 = d0_40 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_20 = d0_41 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_20, ina1_20;
always @(posedge clk) begin
    ina0_20 <= nx0_20;
    ina1_20 <= d1_40;
end
wire w0_20, w1_20;
MSKand_opini2_d2_pini u_or_20 (
    .ina({ina1_20, ina0_20}), .inb({d1_41, ny0_20}),
    .rnd(r[20]), .s(s[20]), .clk(clk), .out({w1_20, w0_20}));
wire or0_20 = w0_20 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_20 = w1_20;
wire nx0_21 = d0_42 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_21 = d0_43 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_21, ina1_21;
always @(posedge clk) begin
    ina0_21 <= nx0_21;
    ina1_21 <= d1_42;
end
wire w0_21, w1_21;
MSKand_opini2_d2_pini u_or_21 (
    .ina({ina1_21, ina0_21}), .inb({d1_43, ny0_21}),
    .rnd(r[21]), .s(s[21]), .clk(clk), .out({w1_21, w0_21}));
wire or0_21 = w0_21 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_21 = w1_21;
wire nx0_22 = d0_44 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_22 = d0_45 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_22, ina1_22;
always @(posedge clk) begin
    ina0_22 <= nx0_22;
    ina1_22 <= d1_44;
end
wire w0_22, w1_22;
MSKand_opini2_d2_pini u_or_22 (
    .ina({ina1_22, ina0_22}), .inb({d1_45, ny0_22}),
    .rnd(r[22]), .s(s[22]), .clk(clk), .out({w1_22, w0_22}));
wire or0_22 = w0_22 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_22 = w1_22;
wire nx0_23 = d0_46 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_23 = d0_47 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_23, ina1_23;
always @(posedge clk) begin
    ina0_23 <= nx0_23;
    ina1_23 <= d1_46;
end
wire w0_23, w1_23;
MSKand_opini2_d2_pini u_or_23 (
    .ina({ina1_23, ina0_23}), .inb({d1_47, ny0_23}),
    .rnd(r[23]), .s(s[23]), .clk(clk), .out({w1_23, w0_23}));
wire or0_23 = w0_23 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_23 = w1_23;
wire nx0_24 = d0_48 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_24 = d0_49 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_24, ina1_24;
always @(posedge clk) begin
    ina0_24 <= nx0_24;
    ina1_24 <= d1_48;
end
wire w0_24, w1_24;
MSKand_opini2_d2_pini u_or_24 (
    .ina({ina1_24, ina0_24}), .inb({d1_49, ny0_24}),
    .rnd(r[24]), .s(s[24]), .clk(clk), .out({w1_24, w0_24}));
wire or0_24 = w0_24 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_24 = w1_24;
wire nx0_25 = d0_50 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_25 = d0_51 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_25, ina1_25;
always @(posedge clk) begin
    ina0_25 <= nx0_25;
    ina1_25 <= d1_50;
end
wire w0_25, w1_25;
MSKand_opini2_d2_pini u_or_25 (
    .ina({ina1_25, ina0_25}), .inb({d1_51, ny0_25}),
    .rnd(r[25]), .s(s[25]), .clk(clk), .out({w1_25, w0_25}));
wire or0_25 = w0_25 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_25 = w1_25;
wire nx0_26 = d0_52 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_26 = d0_53 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_26, ina1_26;
always @(posedge clk) begin
    ina0_26 <= nx0_26;
    ina1_26 <= d1_52;
end
wire w0_26, w1_26;
MSKand_opini2_d2_pini u_or_26 (
    .ina({ina1_26, ina0_26}), .inb({d1_53, ny0_26}),
    .rnd(r[26]), .s(s[26]), .clk(clk), .out({w1_26, w0_26}));
wire or0_26 = w0_26 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_26 = w1_26;
wire nx0_27 = d0_54 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_27 = d0_55 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_27, ina1_27;
always @(posedge clk) begin
    ina0_27 <= nx0_27;
    ina1_27 <= d1_54;
end
wire w0_27, w1_27;
MSKand_opini2_d2_pini u_or_27 (
    .ina({ina1_27, ina0_27}), .inb({d1_55, ny0_27}),
    .rnd(r[27]), .s(s[27]), .clk(clk), .out({w1_27, w0_27}));
wire or0_27 = w0_27 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_27 = w1_27;
wire nx0_28 = d0_56 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_28 = d0_57 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_28, ina1_28;
always @(posedge clk) begin
    ina0_28 <= nx0_28;
    ina1_28 <= d1_56;
end
wire w0_28, w1_28;
MSKand_opini2_d2_pini u_or_28 (
    .ina({ina1_28, ina0_28}), .inb({d1_57, ny0_28}),
    .rnd(r[28]), .s(s[28]), .clk(clk), .out({w1_28, w0_28}));
wire or0_28 = w0_28 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_28 = w1_28;
wire nx0_29 = d0_58 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_29 = d0_59 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_29, ina1_29;
always @(posedge clk) begin
    ina0_29 <= nx0_29;
    ina1_29 <= d1_58;
end
wire w0_29, w1_29;
MSKand_opini2_d2_pini u_or_29 (
    .ina({ina1_29, ina0_29}), .inb({d1_59, ny0_29}),
    .rnd(r[29]), .s(s[29]), .clk(clk), .out({w1_29, w0_29}));
wire or0_29 = w0_29 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_29 = w1_29;
wire nx0_30 = d0_60 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_30 = d0_61 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_30, ina1_30;
always @(posedge clk) begin
    ina0_30 <= nx0_30;
    ina1_30 <= d1_60;
end
wire w0_30, w1_30;
MSKand_opini2_d2_pini u_or_30 (
    .ina({ina1_30, ina0_30}), .inb({d1_61, ny0_30}),
    .rnd(r[30]), .s(s[30]), .clk(clk), .out({w1_30, w0_30}));
wire or0_30 = w0_30 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_30 = w1_30;
wire nx0_31 = d0_62 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_31 = d0_63 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_31, ina1_31;
always @(posedge clk) begin
    ina0_31 <= nx0_31;
    ina1_31 <= d1_62;
end
wire w0_31, w1_31;
MSKand_opini2_d2_pini u_or_31 (
    .ina({ina1_31, ina0_31}), .inb({d1_63, ny0_31}),
    .rnd(r[31]), .s(s[31]), .clk(clk), .out({w1_31, w0_31}));
wire or0_31 = w0_31 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_31 = w1_31;
wire nx0_32 = d0_64 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_32 = d0_65 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_32, ina1_32;
always @(posedge clk) begin
    ina0_32 <= nx0_32;
    ina1_32 <= d1_64;
end
wire w0_32, w1_32;
MSKand_opini2_d2_pini u_or_32 (
    .ina({ina1_32, ina0_32}), .inb({d1_65, ny0_32}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({w1_32, w0_32}));
wire or0_32 = w0_32 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_32 = w1_32;
wire nx0_33 = d0_66 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_33 = d0_67 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_33, ina1_33;
always @(posedge clk) begin
    ina0_33 <= nx0_33;
    ina1_33 <= d1_66;
end
wire w0_33, w1_33;
MSKand_opini2_d2_pini u_or_33 (
    .ina({ina1_33, ina0_33}), .inb({d1_67, ny0_33}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({w1_33, w0_33}));
wire or0_33 = w0_33 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_33 = w1_33;
wire nx0_34 = d0_68 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_34 = d0_69 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_34, ina1_34;
always @(posedge clk) begin
    ina0_34 <= nx0_34;
    ina1_34 <= d1_68;
end
wire w0_34, w1_34;
MSKand_opini2_d2_pini u_or_34 (
    .ina({ina1_34, ina0_34}), .inb({d1_69, ny0_34}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({w1_34, w0_34}));
wire or0_34 = w0_34 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_34 = w1_34;
wire nx0_35 = d0_70 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_35 = d0_71 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_35, ina1_35;
always @(posedge clk) begin
    ina0_35 <= nx0_35;
    ina1_35 <= d1_70;
end
wire w0_35, w1_35;
MSKand_opini2_d2_pini u_or_35 (
    .ina({ina1_35, ina0_35}), .inb({d1_71, ny0_35}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({w1_35, w0_35}));
wire or0_35 = w0_35 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_35 = w1_35;
wire nx0_36 = d0_72 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_36 = d0_73 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_36, ina1_36;
always @(posedge clk) begin
    ina0_36 <= nx0_36;
    ina1_36 <= d1_72;
end
wire w0_36, w1_36;
MSKand_opini2_d2_pini u_or_36 (
    .ina({ina1_36, ina0_36}), .inb({d1_73, ny0_36}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({w1_36, w0_36}));
wire or0_36 = w0_36 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_36 = w1_36;
wire nx0_37 = d0_74 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_37 = d0_75 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_37, ina1_37;
always @(posedge clk) begin
    ina0_37 <= nx0_37;
    ina1_37 <= d1_74;
end
wire w0_37, w1_37;
MSKand_opini2_d2_pini u_or_37 (
    .ina({ina1_37, ina0_37}), .inb({d1_75, ny0_37}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({w1_37, w0_37}));
wire or0_37 = w0_37 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_37 = w1_37;
wire nx0_38 = d0_76 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_38 = d0_77 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_38, ina1_38;
always @(posedge clk) begin
    ina0_38 <= nx0_38;
    ina1_38 <= d1_76;
end
wire w0_38, w1_38;
MSKand_opini2_d2_pini u_or_38 (
    .ina({ina1_38, ina0_38}), .inb({d1_77, ny0_38}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({w1_38, w0_38}));
wire or0_38 = w0_38 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_38 = w1_38;
wire nx0_39 = d0_78 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_39 = d0_79 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_39, ina1_39;
always @(posedge clk) begin
    ina0_39 <= nx0_39;
    ina1_39 <= d1_78;
end
wire w0_39, w1_39;
MSKand_opini2_d2_pini u_or_39 (
    .ina({ina1_39, ina0_39}), .inb({d1_79, ny0_39}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({w1_39, w0_39}));
wire or0_39 = w0_39 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_39 = w1_39;
wire nx0_40 = d0_80 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_40 = d0_81 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_40, ina1_40;
always @(posedge clk) begin
    ina0_40 <= nx0_40;
    ina1_40 <= d1_80;
end
wire w0_40, w1_40;
MSKand_opini2_d2_pini u_or_40 (
    .ina({ina1_40, ina0_40}), .inb({d1_81, ny0_40}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({w1_40, w0_40}));
wire or0_40 = w0_40 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_40 = w1_40;
wire nx0_41 = d0_82 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_41 = d0_83 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_41, ina1_41;
always @(posedge clk) begin
    ina0_41 <= nx0_41;
    ina1_41 <= d1_82;
end
wire w0_41, w1_41;
MSKand_opini2_d2_pini u_or_41 (
    .ina({ina1_41, ina0_41}), .inb({d1_83, ny0_41}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({w1_41, w0_41}));
wire or0_41 = w0_41 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_41 = w1_41;
wire nx0_42 = d0_84 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_42 = d0_85 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_42, ina1_42;
always @(posedge clk) begin
    ina0_42 <= nx0_42;
    ina1_42 <= d1_84;
end
wire w0_42, w1_42;
MSKand_opini2_d2_pini u_or_42 (
    .ina({ina1_42, ina0_42}), .inb({d1_85, ny0_42}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({w1_42, w0_42}));
wire or0_42 = w0_42 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_42 = w1_42;
wire nx0_43 = d0_86 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_43 = d0_87 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_43, ina1_43;
always @(posedge clk) begin
    ina0_43 <= nx0_43;
    ina1_43 <= d1_86;
end
wire w0_43, w1_43;
MSKand_opini2_d2_pini u_or_43 (
    .ina({ina1_43, ina0_43}), .inb({d1_87, ny0_43}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({w1_43, w0_43}));
wire or0_43 = w0_43 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_43 = w1_43;
wire nx0_44 = d0_88 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_44 = d0_89 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_44, ina1_44;
always @(posedge clk) begin
    ina0_44 <= nx0_44;
    ina1_44 <= d1_88;
end
wire w0_44, w1_44;
MSKand_opini2_d2_pini u_or_44 (
    .ina({ina1_44, ina0_44}), .inb({d1_89, ny0_44}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({w1_44, w0_44}));
wire or0_44 = w0_44 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_44 = w1_44;
wire nx0_45 = d0_90 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_45 = d0_91 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_45, ina1_45;
always @(posedge clk) begin
    ina0_45 <= nx0_45;
    ina1_45 <= d1_90;
end
wire w0_45, w1_45;
MSKand_opini2_d2_pini u_or_45 (
    .ina({ina1_45, ina0_45}), .inb({d1_91, ny0_45}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({w1_45, w0_45}));
wire or0_45 = w0_45 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_45 = w1_45;
wire nx0_46 = d0_92 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_46 = d0_93 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_46, ina1_46;
always @(posedge clk) begin
    ina0_46 <= nx0_46;
    ina1_46 <= d1_92;
end
wire w0_46, w1_46;
MSKand_opini2_d2_pini u_or_46 (
    .ina({ina1_46, ina0_46}), .inb({d1_93, ny0_46}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({w1_46, w0_46}));
wire or0_46 = w0_46 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_46 = w1_46;
wire nx0_47 = d0_94 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_47 = d0_95 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_47, ina1_47;
always @(posedge clk) begin
    ina0_47 <= nx0_47;
    ina1_47 <= d1_94;
end
wire w0_47, w1_47;
MSKand_opini2_d2_pini u_or_47 (
    .ina({ina1_47, ina0_47}), .inb({d1_95, ny0_47}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({w1_47, w0_47}));
wire or0_47 = w0_47 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_47 = w1_47;
wire nx0_48 = d0_96 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_48 = d0_97 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_48, ina1_48;
always @(posedge clk) begin
    ina0_48 <= nx0_48;
    ina1_48 <= d1_96;
end
wire w0_48, w1_48;
MSKand_opini2_d2_pini u_or_48 (
    .ina({ina1_48, ina0_48}), .inb({d1_97, ny0_48}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({w1_48, w0_48}));
wire or0_48 = w0_48 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_48 = w1_48;
wire nx0_49 = d0_98 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_49 = d0_99 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_49, ina1_49;
always @(posedge clk) begin
    ina0_49 <= nx0_49;
    ina1_49 <= d1_98;
end
wire w0_49, w1_49;
MSKand_opini2_d2_pini u_or_49 (
    .ina({ina1_49, ina0_49}), .inb({d1_99, ny0_49}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({w1_49, w0_49}));
wire or0_49 = w0_49 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_49 = w1_49;
wire nx0_50 = d0_100 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_50 = d0_101 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_50, ina1_50;
always @(posedge clk) begin
    ina0_50 <= nx0_50;
    ina1_50 <= d1_100;
end
wire w0_50, w1_50;
MSKand_opini2_d2_pini u_or_50 (
    .ina({ina1_50, ina0_50}), .inb({d1_101, ny0_50}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({w1_50, w0_50}));
wire or0_50 = w0_50 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_50 = w1_50;
wire nx0_51 = d0_102 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_51 = d0_103 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_51, ina1_51;
always @(posedge clk) begin
    ina0_51 <= nx0_51;
    ina1_51 <= d1_102;
end
wire w0_51, w1_51;
MSKand_opini2_d2_pini u_or_51 (
    .ina({ina1_51, ina0_51}), .inb({d1_103, ny0_51}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({w1_51, w0_51}));
wire or0_51 = w0_51 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_51 = w1_51;
wire nx0_52 = d0_104 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_52 = d0_105 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_52, ina1_52;
always @(posedge clk) begin
    ina0_52 <= nx0_52;
    ina1_52 <= d1_104;
end
wire w0_52, w1_52;
MSKand_opini2_d2_pini u_or_52 (
    .ina({ina1_52, ina0_52}), .inb({d1_105, ny0_52}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({w1_52, w0_52}));
wire or0_52 = w0_52 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_52 = w1_52;
wire nx0_53 = d0_106 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_53 = d0_107 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_53, ina1_53;
always @(posedge clk) begin
    ina0_53 <= nx0_53;
    ina1_53 <= d1_106;
end
wire w0_53, w1_53;
MSKand_opini2_d2_pini u_or_53 (
    .ina({ina1_53, ina0_53}), .inb({d1_107, ny0_53}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({w1_53, w0_53}));
wire or0_53 = w0_53 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_53 = w1_53;
wire nx0_54 = d0_108 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_54 = d0_109 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_54, ina1_54;
always @(posedge clk) begin
    ina0_54 <= nx0_54;
    ina1_54 <= d1_108;
end
wire w0_54, w1_54;
MSKand_opini2_d2_pini u_or_54 (
    .ina({ina1_54, ina0_54}), .inb({d1_109, ny0_54}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({w1_54, w0_54}));
wire or0_54 = w0_54 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_54 = w1_54;
wire nx0_55 = d0_110 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_55 = d0_111 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_55, ina1_55;
always @(posedge clk) begin
    ina0_55 <= nx0_55;
    ina1_55 <= d1_110;
end
wire w0_55, w1_55;
MSKand_opini2_d2_pini u_or_55 (
    .ina({ina1_55, ina0_55}), .inb({d1_111, ny0_55}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({w1_55, w0_55}));
wire or0_55 = w0_55 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_55 = w1_55;
wire nx0_56 = d0_112 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_56 = d0_113 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_56, ina1_56;
always @(posedge clk) begin
    ina0_56 <= nx0_56;
    ina1_56 <= d1_112;
end
wire w0_56, w1_56;
MSKand_opini2_d2_pini u_or_56 (
    .ina({ina1_56, ina0_56}), .inb({d1_113, ny0_56}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({w1_56, w0_56}));
wire or0_56 = w0_56 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_56 = w1_56;
wire nx0_57 = d0_114 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_57 = d0_115 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_57, ina1_57;
always @(posedge clk) begin
    ina0_57 <= nx0_57;
    ina1_57 <= d1_114;
end
wire w0_57, w1_57;
MSKand_opini2_d2_pini u_or_57 (
    .ina({ina1_57, ina0_57}), .inb({d1_115, ny0_57}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({w1_57, w0_57}));
wire or0_57 = w0_57 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_57 = w1_57;
wire nx0_58 = d0_116 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_58 = d0_117 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_58, ina1_58;
always @(posedge clk) begin
    ina0_58 <= nx0_58;
    ina1_58 <= d1_116;
end
wire w0_58, w1_58;
MSKand_opini2_d2_pini u_or_58 (
    .ina({ina1_58, ina0_58}), .inb({d1_117, ny0_58}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({w1_58, w0_58}));
wire or0_58 = w0_58 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_58 = w1_58;
wire nx0_59 = d0_118 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_59 = d0_119 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_59, ina1_59;
always @(posedge clk) begin
    ina0_59 <= nx0_59;
    ina1_59 <= d1_118;
end
wire w0_59, w1_59;
MSKand_opini2_d2_pini u_or_59 (
    .ina({ina1_59, ina0_59}), .inb({d1_119, ny0_59}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({w1_59, w0_59}));
wire or0_59 = w0_59 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_59 = w1_59;
wire nx0_60 = d0_120 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_60 = d0_121 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_60, ina1_60;
always @(posedge clk) begin
    ina0_60 <= nx0_60;
    ina1_60 <= d1_120;
end
wire w0_60, w1_60;
MSKand_opini2_d2_pini u_or_60 (
    .ina({ina1_60, ina0_60}), .inb({d1_121, ny0_60}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({w1_60, w0_60}));
wire or0_60 = w0_60 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_60 = w1_60;
wire nx0_61 = d0_122 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_61 = d0_123 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_61, ina1_61;
always @(posedge clk) begin
    ina0_61 <= nx0_61;
    ina1_61 <= d1_122;
end
wire w0_61, w1_61;
MSKand_opini2_d2_pini u_or_61 (
    .ina({ina1_61, ina0_61}), .inb({d1_123, ny0_61}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({w1_61, w0_61}));
wire or0_61 = w0_61 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_61 = w1_61;
wire nx0_62 = d0_124 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_62 = d0_125 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_62, ina1_62;
always @(posedge clk) begin
    ina0_62 <= nx0_62;
    ina1_62 <= d1_124;
end
wire w0_62, w1_62;
MSKand_opini2_d2_pini u_or_62 (
    .ina({ina1_62, ina0_62}), .inb({d1_125, ny0_62}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({w1_62, w0_62}));
wire or0_62 = w0_62 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_62 = w1_62;
wire nx0_63 = d0_126 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_63 = d0_127 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_63, ina1_63;
always @(posedge clk) begin
    ina0_63 <= nx0_63;
    ina1_63 <= d1_126;
end
wire w0_63, w1_63;
MSKand_opini2_d2_pini u_or_63 (
    .ina({ina1_63, ina0_63}), .inb({d1_127, ny0_63}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({w1_63, w0_63}));
wire or0_63 = w0_63 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_63 = w1_63;
wire nx0_64 = d0_128 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_64 = d0_129 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_64, ina1_64;
always @(posedge clk) begin
    ina0_64 <= nx0_64;
    ina1_64 <= d1_128;
end
wire w0_64, w1_64;
MSKand_opini2_d2_pini u_or_64 (
    .ina({ina1_64, ina0_64}), .inb({d1_129, ny0_64}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({w1_64, w0_64}));
wire or0_64 = w0_64 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_64 = w1_64;
wire nx0_65 = d0_130 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_65 = d0_131 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_65, ina1_65;
always @(posedge clk) begin
    ina0_65 <= nx0_65;
    ina1_65 <= d1_130;
end
wire w0_65, w1_65;
MSKand_opini2_d2_pini u_or_65 (
    .ina({ina1_65, ina0_65}), .inb({d1_131, ny0_65}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({w1_65, w0_65}));
wire or0_65 = w0_65 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_65 = w1_65;
wire nx0_66 = d0_132 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_66 = d0_133 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_66, ina1_66;
always @(posedge clk) begin
    ina0_66 <= nx0_66;
    ina1_66 <= d1_132;
end
wire w0_66, w1_66;
MSKand_opini2_d2_pini u_or_66 (
    .ina({ina1_66, ina0_66}), .inb({d1_133, ny0_66}),
    .rnd(r[66]), .s(s[66]), .clk(clk), .out({w1_66, w0_66}));
wire or0_66 = w0_66 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_66 = w1_66;
wire nx0_67 = d0_134 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_67 = d0_135 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_67, ina1_67;
always @(posedge clk) begin
    ina0_67 <= nx0_67;
    ina1_67 <= d1_134;
end
wire w0_67, w1_67;
MSKand_opini2_d2_pini u_or_67 (
    .ina({ina1_67, ina0_67}), .inb({d1_135, ny0_67}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({w1_67, w0_67}));
wire or0_67 = w0_67 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_67 = w1_67;
wire nx0_68 = d0_136 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_68 = d0_137 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_68, ina1_68;
always @(posedge clk) begin
    ina0_68 <= nx0_68;
    ina1_68 <= d1_136;
end
wire w0_68, w1_68;
MSKand_opini2_d2_pini u_or_68 (
    .ina({ina1_68, ina0_68}), .inb({d1_137, ny0_68}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({w1_68, w0_68}));
wire or0_68 = w0_68 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_68 = w1_68;
wire nx0_69 = d0_138 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_69 = d0_139 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_69, ina1_69;
always @(posedge clk) begin
    ina0_69 <= nx0_69;
    ina1_69 <= d1_138;
end
wire w0_69, w1_69;
MSKand_opini2_d2_pini u_or_69 (
    .ina({ina1_69, ina0_69}), .inb({d1_139, ny0_69}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({w1_69, w0_69}));
wire or0_69 = w0_69 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_69 = w1_69;
wire nx0_70 = d0_140 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_70 = d0_141 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_70, ina1_70;
always @(posedge clk) begin
    ina0_70 <= nx0_70;
    ina1_70 <= d1_140;
end
wire w0_70, w1_70;
MSKand_opini2_d2_pini u_or_70 (
    .ina({ina1_70, ina0_70}), .inb({d1_141, ny0_70}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({w1_70, w0_70}));
wire or0_70 = w0_70 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_70 = w1_70;
wire nx0_71 = d0_142 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_71 = d0_143 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_71, ina1_71;
always @(posedge clk) begin
    ina0_71 <= nx0_71;
    ina1_71 <= d1_142;
end
wire w0_71, w1_71;
MSKand_opini2_d2_pini u_or_71 (
    .ina({ina1_71, ina0_71}), .inb({d1_143, ny0_71}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({w1_71, w0_71}));
wire or0_71 = w0_71 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_71 = w1_71;
wire nx0_72 = d0_144 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_72 = d0_145 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_72, ina1_72;
always @(posedge clk) begin
    ina0_72 <= nx0_72;
    ina1_72 <= d1_144;
end
wire w0_72, w1_72;
MSKand_opini2_d2_pini u_or_72 (
    .ina({ina1_72, ina0_72}), .inb({d1_145, ny0_72}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({w1_72, w0_72}));
wire or0_72 = w0_72 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_72 = w1_72;
wire nx0_73 = d0_146 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_73 = d0_147 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_73, ina1_73;
always @(posedge clk) begin
    ina0_73 <= nx0_73;
    ina1_73 <= d1_146;
end
wire w0_73, w1_73;
MSKand_opini2_d2_pini u_or_73 (
    .ina({ina1_73, ina0_73}), .inb({d1_147, ny0_73}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({w1_73, w0_73}));
wire or0_73 = w0_73 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_73 = w1_73;
wire nx0_74 = d0_148 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_74 = d0_149 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_74, ina1_74;
always @(posedge clk) begin
    ina0_74 <= nx0_74;
    ina1_74 <= d1_148;
end
wire w0_74, w1_74;
MSKand_opini2_d2_pini u_or_74 (
    .ina({ina1_74, ina0_74}), .inb({d1_149, ny0_74}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({w1_74, w0_74}));
wire or0_74 = w0_74 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_74 = w1_74;
wire nx0_75 = d0_150 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_75 = d0_151 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_75, ina1_75;
always @(posedge clk) begin
    ina0_75 <= nx0_75;
    ina1_75 <= d1_150;
end
wire w0_75, w1_75;
MSKand_opini2_d2_pini u_or_75 (
    .ina({ina1_75, ina0_75}), .inb({d1_151, ny0_75}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({w1_75, w0_75}));
wire or0_75 = w0_75 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_75 = w1_75;
wire nx0_76 = d0_152 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_76 = d0_153 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_76, ina1_76;
always @(posedge clk) begin
    ina0_76 <= nx0_76;
    ina1_76 <= d1_152;
end
wire w0_76, w1_76;
MSKand_opini2_d2_pini u_or_76 (
    .ina({ina1_76, ina0_76}), .inb({d1_153, ny0_76}),
    .rnd(r[76]), .s(s[76]), .clk(clk), .out({w1_76, w0_76}));
wire or0_76 = w0_76 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_76 = w1_76;
wire nx0_77 = d0_154 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_77 = d0_155 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_77, ina1_77;
always @(posedge clk) begin
    ina0_77 <= nx0_77;
    ina1_77 <= d1_154;
end
wire w0_77, w1_77;
MSKand_opini2_d2_pini u_or_77 (
    .ina({ina1_77, ina0_77}), .inb({d1_155, ny0_77}),
    .rnd(r[77]), .s(s[77]), .clk(clk), .out({w1_77, w0_77}));
wire or0_77 = w0_77 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_77 = w1_77;
wire nx0_78 = d0_156 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_78 = d0_157 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_78, ina1_78;
always @(posedge clk) begin
    ina0_78 <= nx0_78;
    ina1_78 <= d1_156;
end
wire w0_78, w1_78;
MSKand_opini2_d2_pini u_or_78 (
    .ina({ina1_78, ina0_78}), .inb({d1_157, ny0_78}),
    .rnd(r[78]), .s(s[78]), .clk(clk), .out({w1_78, w0_78}));
wire or0_78 = w0_78 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_78 = w1_78;
wire nx0_79 = d0_158 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_79 = d0_159 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_79, ina1_79;
always @(posedge clk) begin
    ina0_79 <= nx0_79;
    ina1_79 <= d1_158;
end
wire w0_79, w1_79;
MSKand_opini2_d2_pini u_or_79 (
    .ina({ina1_79, ina0_79}), .inb({d1_159, ny0_79}),
    .rnd(r[79]), .s(s[79]), .clk(clk), .out({w1_79, w0_79}));
wire or0_79 = w0_79 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_79 = w1_79;
wire nx0_80 = d0_160 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_80 = d0_161 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_80, ina1_80;
always @(posedge clk) begin
    ina0_80 <= nx0_80;
    ina1_80 <= d1_160;
end
wire w0_80, w1_80;
MSKand_opini2_d2_pini u_or_80 (
    .ina({ina1_80, ina0_80}), .inb({d1_161, ny0_80}),
    .rnd(r[80]), .s(s[80]), .clk(clk), .out({w1_80, w0_80}));
wire or0_80 = w0_80 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_80 = w1_80;
wire nx0_81 = d0_162 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_81 = d0_163 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_81, ina1_81;
always @(posedge clk) begin
    ina0_81 <= nx0_81;
    ina1_81 <= d1_162;
end
wire w0_81, w1_81;
MSKand_opini2_d2_pini u_or_81 (
    .ina({ina1_81, ina0_81}), .inb({d1_163, ny0_81}),
    .rnd(r[81]), .s(s[81]), .clk(clk), .out({w1_81, w0_81}));
wire or0_81 = w0_81 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_81 = w1_81;
wire nx0_82 = d0_164 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_82 = d0_165 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_82, ina1_82;
always @(posedge clk) begin
    ina0_82 <= nx0_82;
    ina1_82 <= d1_164;
end
wire w0_82, w1_82;
MSKand_opini2_d2_pini u_or_82 (
    .ina({ina1_82, ina0_82}), .inb({d1_165, ny0_82}),
    .rnd(r[82]), .s(s[82]), .clk(clk), .out({w1_82, w0_82}));
wire or0_82 = w0_82 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_82 = w1_82;
wire nx0_83 = d0_166 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_83 = d0_167 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_83, ina1_83;
always @(posedge clk) begin
    ina0_83 <= nx0_83;
    ina1_83 <= d1_166;
end
wire w0_83, w1_83;
MSKand_opini2_d2_pini u_or_83 (
    .ina({ina1_83, ina0_83}), .inb({d1_167, ny0_83}),
    .rnd(r[83]), .s(s[83]), .clk(clk), .out({w1_83, w0_83}));
wire or0_83 = w0_83 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_83 = w1_83;
wire nx0_84 = d0_168 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_84 = d0_169 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_84, ina1_84;
always @(posedge clk) begin
    ina0_84 <= nx0_84;
    ina1_84 <= d1_168;
end
wire w0_84, w1_84;
MSKand_opini2_d2_pini u_or_84 (
    .ina({ina1_84, ina0_84}), .inb({d1_169, ny0_84}),
    .rnd(r[84]), .s(s[84]), .clk(clk), .out({w1_84, w0_84}));
wire or0_84 = w0_84 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_84 = w1_84;
wire nx0_85 = d0_170 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_85 = d0_171 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_85, ina1_85;
always @(posedge clk) begin
    ina0_85 <= nx0_85;
    ina1_85 <= d1_170;
end
wire w0_85, w1_85;
MSKand_opini2_d2_pini u_or_85 (
    .ina({ina1_85, ina0_85}), .inb({d1_171, ny0_85}),
    .rnd(r[85]), .s(s[85]), .clk(clk), .out({w1_85, w0_85}));
wire or0_85 = w0_85 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_85 = w1_85;
wire nx0_86 = d0_172 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_86 = d0_173 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_86, ina1_86;
always @(posedge clk) begin
    ina0_86 <= nx0_86;
    ina1_86 <= d1_172;
end
wire w0_86, w1_86;
MSKand_opini2_d2_pini u_or_86 (
    .ina({ina1_86, ina0_86}), .inb({d1_173, ny0_86}),
    .rnd(r[86]), .s(s[86]), .clk(clk), .out({w1_86, w0_86}));
wire or0_86 = w0_86 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_86 = w1_86;
wire nx0_87 = d0_174 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_87 = d0_175 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_87, ina1_87;
always @(posedge clk) begin
    ina0_87 <= nx0_87;
    ina1_87 <= d1_174;
end
wire w0_87, w1_87;
MSKand_opini2_d2_pini u_or_87 (
    .ina({ina1_87, ina0_87}), .inb({d1_175, ny0_87}),
    .rnd(r[87]), .s(s[87]), .clk(clk), .out({w1_87, w0_87}));
wire or0_87 = w0_87 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_87 = w1_87;
wire nx0_88 = d0_176 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_88 = d0_177 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_88, ina1_88;
always @(posedge clk) begin
    ina0_88 <= nx0_88;
    ina1_88 <= d1_176;
end
wire w0_88, w1_88;
MSKand_opini2_d2_pini u_or_88 (
    .ina({ina1_88, ina0_88}), .inb({d1_177, ny0_88}),
    .rnd(r[88]), .s(s[88]), .clk(clk), .out({w1_88, w0_88}));
wire or0_88 = w0_88 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_88 = w1_88;
wire nx0_89 = d0_178 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_89 = d0_179 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_89, ina1_89;
always @(posedge clk) begin
    ina0_89 <= nx0_89;
    ina1_89 <= d1_178;
end
wire w0_89, w1_89;
MSKand_opini2_d2_pini u_or_89 (
    .ina({ina1_89, ina0_89}), .inb({d1_179, ny0_89}),
    .rnd(r[89]), .s(s[89]), .clk(clk), .out({w1_89, w0_89}));
wire or0_89 = w0_89 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_89 = w1_89;
wire nx0_90 = d0_180 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_90 = d0_181 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_90, ina1_90;
always @(posedge clk) begin
    ina0_90 <= nx0_90;
    ina1_90 <= d1_180;
end
wire w0_90, w1_90;
MSKand_opini2_d2_pini u_or_90 (
    .ina({ina1_90, ina0_90}), .inb({d1_181, ny0_90}),
    .rnd(r[90]), .s(s[90]), .clk(clk), .out({w1_90, w0_90}));
wire or0_90 = w0_90 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_90 = w1_90;
wire nx0_91 = d0_182 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_91 = d0_183 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_91, ina1_91;
always @(posedge clk) begin
    ina0_91 <= nx0_91;
    ina1_91 <= d1_182;
end
wire w0_91, w1_91;
MSKand_opini2_d2_pini u_or_91 (
    .ina({ina1_91, ina0_91}), .inb({d1_183, ny0_91}),
    .rnd(r[91]), .s(s[91]), .clk(clk), .out({w1_91, w0_91}));
wire or0_91 = w0_91 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_91 = w1_91;
wire nx0_92 = d0_184 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_92 = d0_185 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_92, ina1_92;
always @(posedge clk) begin
    ina0_92 <= nx0_92;
    ina1_92 <= d1_184;
end
wire w0_92, w1_92;
MSKand_opini2_d2_pini u_or_92 (
    .ina({ina1_92, ina0_92}), .inb({d1_185, ny0_92}),
    .rnd(r[92]), .s(s[92]), .clk(clk), .out({w1_92, w0_92}));
wire or0_92 = w0_92 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_92 = w1_92;
wire nx0_93 = d0_186 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_93 = d0_187 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_93, ina1_93;
always @(posedge clk) begin
    ina0_93 <= nx0_93;
    ina1_93 <= d1_186;
end
wire w0_93, w1_93;
MSKand_opini2_d2_pini u_or_93 (
    .ina({ina1_93, ina0_93}), .inb({d1_187, ny0_93}),
    .rnd(r[93]), .s(s[93]), .clk(clk), .out({w1_93, w0_93}));
wire or0_93 = w0_93 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_93 = w1_93;
wire nx0_94 = d0_188 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_94 = d0_189 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_94, ina1_94;
always @(posedge clk) begin
    ina0_94 <= nx0_94;
    ina1_94 <= d1_188;
end
wire w0_94, w1_94;
MSKand_opini2_d2_pini u_or_94 (
    .ina({ina1_94, ina0_94}), .inb({d1_189, ny0_94}),
    .rnd(r[94]), .s(s[94]), .clk(clk), .out({w1_94, w0_94}));
wire or0_94 = w0_94 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_94 = w1_94;
wire nx0_95 = d0_190 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_95 = d0_191 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_95, ina1_95;
always @(posedge clk) begin
    ina0_95 <= nx0_95;
    ina1_95 <= d1_190;
end
wire w0_95, w1_95;
MSKand_opini2_d2_pini u_or_95 (
    .ina({ina1_95, ina0_95}), .inb({d1_191, ny0_95}),
    .rnd(r[95]), .s(s[95]), .clk(clk), .out({w1_95, w0_95}));
wire or0_95 = w0_95 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_95 = w1_95;
wire nx0_96 = d0_192 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_96 = d0_193 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_96, ina1_96;
always @(posedge clk) begin
    ina0_96 <= nx0_96;
    ina1_96 <= d1_192;
end
wire w0_96, w1_96;
MSKand_opini2_d2_pini u_or_96 (
    .ina({ina1_96, ina0_96}), .inb({d1_193, ny0_96}),
    .rnd(r[96]), .s(s[96]), .clk(clk), .out({w1_96, w0_96}));
wire or0_96 = w0_96 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_96 = w1_96;
wire nx0_97 = d0_194 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_97 = d0_195 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_97, ina1_97;
always @(posedge clk) begin
    ina0_97 <= nx0_97;
    ina1_97 <= d1_194;
end
wire w0_97, w1_97;
MSKand_opini2_d2_pini u_or_97 (
    .ina({ina1_97, ina0_97}), .inb({d1_195, ny0_97}),
    .rnd(r[97]), .s(s[97]), .clk(clk), .out({w1_97, w0_97}));
wire or0_97 = w0_97 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_97 = w1_97;
wire nx0_98 = d0_196 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_98 = d0_197 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_98, ina1_98;
always @(posedge clk) begin
    ina0_98 <= nx0_98;
    ina1_98 <= d1_196;
end
wire w0_98, w1_98;
MSKand_opini2_d2_pini u_or_98 (
    .ina({ina1_98, ina0_98}), .inb({d1_197, ny0_98}),
    .rnd(r[98]), .s(s[98]), .clk(clk), .out({w1_98, w0_98}));
wire or0_98 = w0_98 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_98 = w1_98;
wire nx0_99 = d0_198 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_99 = d0_199 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_99, ina1_99;
always @(posedge clk) begin
    ina0_99 <= nx0_99;
    ina1_99 <= d1_198;
end
wire w0_99, w1_99;
MSKand_opini2_d2_pini u_or_99 (
    .ina({ina1_99, ina0_99}), .inb({d1_199, ny0_99}),
    .rnd(r[99]), .s(s[99]), .clk(clk), .out({w1_99, w0_99}));
wire or0_99 = w0_99 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_99 = w1_99;
wire nx0_100 = d0_200 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_100 = d0_201 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_100, ina1_100;
always @(posedge clk) begin
    ina0_100 <= nx0_100;
    ina1_100 <= d1_200;
end
wire w0_100, w1_100;
MSKand_opini2_d2_pini u_or_100 (
    .ina({ina1_100, ina0_100}), .inb({d1_201, ny0_100}),
    .rnd(r[100]), .s(s[100]), .clk(clk), .out({w1_100, w0_100}));
wire or0_100 = w0_100 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_100 = w1_100;
wire nx0_101 = d0_202 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_101 = d0_203 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_101, ina1_101;
always @(posedge clk) begin
    ina0_101 <= nx0_101;
    ina1_101 <= d1_202;
end
wire w0_101, w1_101;
MSKand_opini2_d2_pini u_or_101 (
    .ina({ina1_101, ina0_101}), .inb({d1_203, ny0_101}),
    .rnd(r[101]), .s(s[101]), .clk(clk), .out({w1_101, w0_101}));
wire or0_101 = w0_101 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_101 = w1_101;
wire nx0_102 = d0_204 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_102 = d0_205 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_102, ina1_102;
always @(posedge clk) begin
    ina0_102 <= nx0_102;
    ina1_102 <= d1_204;
end
wire w0_102, w1_102;
MSKand_opini2_d2_pini u_or_102 (
    .ina({ina1_102, ina0_102}), .inb({d1_205, ny0_102}),
    .rnd(r[102]), .s(s[102]), .clk(clk), .out({w1_102, w0_102}));
wire or0_102 = w0_102 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_102 = w1_102;
wire nx0_103 = d0_206 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_103 = d0_207 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_103, ina1_103;
always @(posedge clk) begin
    ina0_103 <= nx0_103;
    ina1_103 <= d1_206;
end
wire w0_103, w1_103;
MSKand_opini2_d2_pini u_or_103 (
    .ina({ina1_103, ina0_103}), .inb({d1_207, ny0_103}),
    .rnd(r[103]), .s(s[103]), .clk(clk), .out({w1_103, w0_103}));
wire or0_103 = w0_103 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_103 = w1_103;
wire nx0_104 = d0_208 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_104 = d0_209 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_104, ina1_104;
always @(posedge clk) begin
    ina0_104 <= nx0_104;
    ina1_104 <= d1_208;
end
wire w0_104, w1_104;
MSKand_opini2_d2_pini u_or_104 (
    .ina({ina1_104, ina0_104}), .inb({d1_209, ny0_104}),
    .rnd(r[104]), .s(s[104]), .clk(clk), .out({w1_104, w0_104}));
wire or0_104 = w0_104 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_104 = w1_104;
wire nx0_105 = d0_210 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_105 = d0_211 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_105, ina1_105;
always @(posedge clk) begin
    ina0_105 <= nx0_105;
    ina1_105 <= d1_210;
end
wire w0_105, w1_105;
MSKand_opini2_d2_pini u_or_105 (
    .ina({ina1_105, ina0_105}), .inb({d1_211, ny0_105}),
    .rnd(r[105]), .s(s[105]), .clk(clk), .out({w1_105, w0_105}));
wire or0_105 = w0_105 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_105 = w1_105;
wire nx0_106 = d0_212 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_106 = d0_213 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_106, ina1_106;
always @(posedge clk) begin
    ina0_106 <= nx0_106;
    ina1_106 <= d1_212;
end
wire w0_106, w1_106;
MSKand_opini2_d2_pini u_or_106 (
    .ina({ina1_106, ina0_106}), .inb({d1_213, ny0_106}),
    .rnd(r[106]), .s(s[106]), .clk(clk), .out({w1_106, w0_106}));
wire or0_106 = w0_106 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_106 = w1_106;
wire nx0_107 = d0_214 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_107 = d0_215 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_107, ina1_107;
always @(posedge clk) begin
    ina0_107 <= nx0_107;
    ina1_107 <= d1_214;
end
wire w0_107, w1_107;
MSKand_opini2_d2_pini u_or_107 (
    .ina({ina1_107, ina0_107}), .inb({d1_215, ny0_107}),
    .rnd(r[107]), .s(s[107]), .clk(clk), .out({w1_107, w0_107}));
wire or0_107 = w0_107 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_107 = w1_107;
wire nx0_108 = d0_216 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_108 = d0_217 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_108, ina1_108;
always @(posedge clk) begin
    ina0_108 <= nx0_108;
    ina1_108 <= d1_216;
end
wire w0_108, w1_108;
MSKand_opini2_d2_pini u_or_108 (
    .ina({ina1_108, ina0_108}), .inb({d1_217, ny0_108}),
    .rnd(r[108]), .s(s[108]), .clk(clk), .out({w1_108, w0_108}));
wire or0_108 = w0_108 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_108 = w1_108;
wire nx0_109 = d0_218 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_109 = d0_219 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_109, ina1_109;
always @(posedge clk) begin
    ina0_109 <= nx0_109;
    ina1_109 <= d1_218;
end
wire w0_109, w1_109;
MSKand_opini2_d2_pini u_or_109 (
    .ina({ina1_109, ina0_109}), .inb({d1_219, ny0_109}),
    .rnd(r[109]), .s(s[109]), .clk(clk), .out({w1_109, w0_109}));
wire or0_109 = w0_109 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_109 = w1_109;
wire nx0_110 = d0_220 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_110 = d0_221 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_110, ina1_110;
always @(posedge clk) begin
    ina0_110 <= nx0_110;
    ina1_110 <= d1_220;
end
wire w0_110, w1_110;
MSKand_opini2_d2_pini u_or_110 (
    .ina({ina1_110, ina0_110}), .inb({d1_221, ny0_110}),
    .rnd(r[110]), .s(s[110]), .clk(clk), .out({w1_110, w0_110}));
wire or0_110 = w0_110 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_110 = w1_110;
wire nx0_111 = d0_222 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_111 = d0_223 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_111, ina1_111;
always @(posedge clk) begin
    ina0_111 <= nx0_111;
    ina1_111 <= d1_222;
end
wire w0_111, w1_111;
MSKand_opini2_d2_pini u_or_111 (
    .ina({ina1_111, ina0_111}), .inb({d1_223, ny0_111}),
    .rnd(r[111]), .s(s[111]), .clk(clk), .out({w1_111, w0_111}));
wire or0_111 = w0_111 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_111 = w1_111;
wire nx0_112 = d0_224 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_112 = d0_225 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_112, ina1_112;
always @(posedge clk) begin
    ina0_112 <= nx0_112;
    ina1_112 <= d1_224;
end
wire w0_112, w1_112;
MSKand_opini2_d2_pini u_or_112 (
    .ina({ina1_112, ina0_112}), .inb({d1_225, ny0_112}),
    .rnd(r[112]), .s(s[112]), .clk(clk), .out({w1_112, w0_112}));
wire or0_112 = w0_112 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_112 = w1_112;
wire nx0_113 = d0_226 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_113 = d0_227 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_113, ina1_113;
always @(posedge clk) begin
    ina0_113 <= nx0_113;
    ina1_113 <= d1_226;
end
wire w0_113, w1_113;
MSKand_opini2_d2_pini u_or_113 (
    .ina({ina1_113, ina0_113}), .inb({d1_227, ny0_113}),
    .rnd(r[113]), .s(s[113]), .clk(clk), .out({w1_113, w0_113}));
wire or0_113 = w0_113 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_113 = w1_113;
wire nx0_114 = d0_228 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_114 = d0_229 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_114, ina1_114;
always @(posedge clk) begin
    ina0_114 <= nx0_114;
    ina1_114 <= d1_228;
end
wire w0_114, w1_114;
MSKand_opini2_d2_pini u_or_114 (
    .ina({ina1_114, ina0_114}), .inb({d1_229, ny0_114}),
    .rnd(r[114]), .s(s[114]), .clk(clk), .out({w1_114, w0_114}));
wire or0_114 = w0_114 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_114 = w1_114;
wire nx0_115 = d0_230 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_115 = d0_231 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_115, ina1_115;
always @(posedge clk) begin
    ina0_115 <= nx0_115;
    ina1_115 <= d1_230;
end
wire w0_115, w1_115;
MSKand_opini2_d2_pini u_or_115 (
    .ina({ina1_115, ina0_115}), .inb({d1_231, ny0_115}),
    .rnd(r[115]), .s(s[115]), .clk(clk), .out({w1_115, w0_115}));
wire or0_115 = w0_115 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_115 = w1_115;
wire nx0_116 = d0_232 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_116 = d0_233 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_116, ina1_116;
always @(posedge clk) begin
    ina0_116 <= nx0_116;
    ina1_116 <= d1_232;
end
wire w0_116, w1_116;
MSKand_opini2_d2_pini u_or_116 (
    .ina({ina1_116, ina0_116}), .inb({d1_233, ny0_116}),
    .rnd(r[116]), .s(s[116]), .clk(clk), .out({w1_116, w0_116}));
wire or0_116 = w0_116 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_116 = w1_116;
wire nx0_117 = d0_234 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_117 = d0_235 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_117, ina1_117;
always @(posedge clk) begin
    ina0_117 <= nx0_117;
    ina1_117 <= d1_234;
end
wire w0_117, w1_117;
MSKand_opini2_d2_pini u_or_117 (
    .ina({ina1_117, ina0_117}), .inb({d1_235, ny0_117}),
    .rnd(r[117]), .s(s[117]), .clk(clk), .out({w1_117, w0_117}));
wire or0_117 = w0_117 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_117 = w1_117;
wire nx0_118 = d0_236 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_118 = d0_237 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_118, ina1_118;
always @(posedge clk) begin
    ina0_118 <= nx0_118;
    ina1_118 <= d1_236;
end
wire w0_118, w1_118;
MSKand_opini2_d2_pini u_or_118 (
    .ina({ina1_118, ina0_118}), .inb({d1_237, ny0_118}),
    .rnd(r[118]), .s(s[118]), .clk(clk), .out({w1_118, w0_118}));
wire or0_118 = w0_118 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_118 = w1_118;
wire nx0_119 = d0_238 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_119 = d0_239 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_119, ina1_119;
always @(posedge clk) begin
    ina0_119 <= nx0_119;
    ina1_119 <= d1_238;
end
wire w0_119, w1_119;
MSKand_opini2_d2_pini u_or_119 (
    .ina({ina1_119, ina0_119}), .inb({d1_239, ny0_119}),
    .rnd(r[119]), .s(s[119]), .clk(clk), .out({w1_119, w0_119}));
wire or0_119 = w0_119 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_119 = w1_119;
wire nx0_120 = d0_240 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_120 = d0_241 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_120, ina1_120;
always @(posedge clk) begin
    ina0_120 <= nx0_120;
    ina1_120 <= d1_240;
end
wire w0_120, w1_120;
MSKand_opini2_d2_pini u_or_120 (
    .ina({ina1_120, ina0_120}), .inb({d1_241, ny0_120}),
    .rnd(r[120]), .s(s[120]), .clk(clk), .out({w1_120, w0_120}));
wire or0_120 = w0_120 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_120 = w1_120;
wire nx0_121 = d0_242 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_121 = d0_243 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_121, ina1_121;
always @(posedge clk) begin
    ina0_121 <= nx0_121;
    ina1_121 <= d1_242;
end
wire w0_121, w1_121;
MSKand_opini2_d2_pini u_or_121 (
    .ina({ina1_121, ina0_121}), .inb({d1_243, ny0_121}),
    .rnd(r[121]), .s(s[121]), .clk(clk), .out({w1_121, w0_121}));
wire or0_121 = w0_121 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_121 = w1_121;
wire nx0_122 = d0_244 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_122 = d0_245 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_122, ina1_122;
always @(posedge clk) begin
    ina0_122 <= nx0_122;
    ina1_122 <= d1_244;
end
wire w0_122, w1_122;
MSKand_opini2_d2_pini u_or_122 (
    .ina({ina1_122, ina0_122}), .inb({d1_245, ny0_122}),
    .rnd(r[122]), .s(s[122]), .clk(clk), .out({w1_122, w0_122}));
wire or0_122 = w0_122 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_122 = w1_122;
wire nx0_123 = d0_246 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_123 = d0_247 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_123, ina1_123;
always @(posedge clk) begin
    ina0_123 <= nx0_123;
    ina1_123 <= d1_246;
end
wire w0_123, w1_123;
MSKand_opini2_d2_pini u_or_123 (
    .ina({ina1_123, ina0_123}), .inb({d1_247, ny0_123}),
    .rnd(r[123]), .s(s[123]), .clk(clk), .out({w1_123, w0_123}));
wire or0_123 = w0_123 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_123 = w1_123;
wire nx0_124 = d0_248 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_124 = d0_249 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_124, ina1_124;
always @(posedge clk) begin
    ina0_124 <= nx0_124;
    ina1_124 <= d1_248;
end
wire w0_124, w1_124;
MSKand_opini2_d2_pini u_or_124 (
    .ina({ina1_124, ina0_124}), .inb({d1_249, ny0_124}),
    .rnd(r[124]), .s(s[124]), .clk(clk), .out({w1_124, w0_124}));
wire or0_124 = w0_124 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_124 = w1_124;
wire nx0_125 = d0_250 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_125 = d0_251 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_125, ina1_125;
always @(posedge clk) begin
    ina0_125 <= nx0_125;
    ina1_125 <= d1_250;
end
wire w0_125, w1_125;
MSKand_opini2_d2_pini u_or_125 (
    .ina({ina1_125, ina0_125}), .inb({d1_251, ny0_125}),
    .rnd(r[125]), .s(s[125]), .clk(clk), .out({w1_125, w0_125}));
wire or0_125 = w0_125 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_125 = w1_125;
wire nx0_126 = d0_252 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_126 = d0_253 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_126, ina1_126;
always @(posedge clk) begin
    ina0_126 <= nx0_126;
    ina1_126 <= d1_252;
end
wire w0_126, w1_126;
MSKand_opini2_d2_pini u_or_126 (
    .ina({ina1_126, ina0_126}), .inb({d1_253, ny0_126}),
    .rnd(r[126]), .s(s[126]), .clk(clk), .out({w1_126, w0_126}));
wire or0_126 = w0_126 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_126 = w1_126;
wire nx0_127 = d0_254 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_127 = d0_255 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_127, ina1_127;
always @(posedge clk) begin
    ina0_127 <= nx0_127;
    ina1_127 <= d1_254;
end
wire w0_127, w1_127;
MSKand_opini2_d2_pini u_or_127 (
    .ina({ina1_127, ina0_127}), .inb({d1_255, ny0_127}),
    .rnd(r[127]), .s(s[127]), .clk(clk), .out({w1_127, w0_127}));
wire or0_127 = w0_127 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_127 = w1_127;

// ===== OR-reduce level 1: 128 masked bits -> 64 =====
wire nx0_128 = or0_0 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_128 = or0_1 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_128, ina1_128;
always @(posedge clk) begin
    ina0_128 <= nx0_128;
    ina1_128 <= or1_0;
end
wire w0_128, w1_128;
MSKand_opini2_d2_pini u_or_128 (
    .ina({ina1_128, ina0_128}), .inb({or1_1, ny0_128}),
    .rnd(r[128]), .s(s[128]), .clk(clk), .out({w1_128, w0_128}));
wire or0_128 = w0_128 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_128 = w1_128;
wire nx0_129 = or0_2 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_129 = or0_3 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_129, ina1_129;
always @(posedge clk) begin
    ina0_129 <= nx0_129;
    ina1_129 <= or1_2;
end
wire w0_129, w1_129;
MSKand_opini2_d2_pini u_or_129 (
    .ina({ina1_129, ina0_129}), .inb({or1_3, ny0_129}),
    .rnd(r[129]), .s(s[129]), .clk(clk), .out({w1_129, w0_129}));
wire or0_129 = w0_129 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_129 = w1_129;
wire nx0_130 = or0_4 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_130 = or0_5 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_130, ina1_130;
always @(posedge clk) begin
    ina0_130 <= nx0_130;
    ina1_130 <= or1_4;
end
wire w0_130, w1_130;
MSKand_opini2_d2_pini u_or_130 (
    .ina({ina1_130, ina0_130}), .inb({or1_5, ny0_130}),
    .rnd(r[130]), .s(s[130]), .clk(clk), .out({w1_130, w0_130}));
wire or0_130 = w0_130 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_130 = w1_130;
wire nx0_131 = or0_6 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_131 = or0_7 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_131, ina1_131;
always @(posedge clk) begin
    ina0_131 <= nx0_131;
    ina1_131 <= or1_6;
end
wire w0_131, w1_131;
MSKand_opini2_d2_pini u_or_131 (
    .ina({ina1_131, ina0_131}), .inb({or1_7, ny0_131}),
    .rnd(r[131]), .s(s[131]), .clk(clk), .out({w1_131, w0_131}));
wire or0_131 = w0_131 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_131 = w1_131;
wire nx0_132 = or0_8 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_132 = or0_9 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_132, ina1_132;
always @(posedge clk) begin
    ina0_132 <= nx0_132;
    ina1_132 <= or1_8;
end
wire w0_132, w1_132;
MSKand_opini2_d2_pini u_or_132 (
    .ina({ina1_132, ina0_132}), .inb({or1_9, ny0_132}),
    .rnd(r[132]), .s(s[132]), .clk(clk), .out({w1_132, w0_132}));
wire or0_132 = w0_132 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_132 = w1_132;
wire nx0_133 = or0_10 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_133 = or0_11 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_133, ina1_133;
always @(posedge clk) begin
    ina0_133 <= nx0_133;
    ina1_133 <= or1_10;
end
wire w0_133, w1_133;
MSKand_opini2_d2_pini u_or_133 (
    .ina({ina1_133, ina0_133}), .inb({or1_11, ny0_133}),
    .rnd(r[133]), .s(s[133]), .clk(clk), .out({w1_133, w0_133}));
wire or0_133 = w0_133 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_133 = w1_133;
wire nx0_134 = or0_12 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_134 = or0_13 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_134, ina1_134;
always @(posedge clk) begin
    ina0_134 <= nx0_134;
    ina1_134 <= or1_12;
end
wire w0_134, w1_134;
MSKand_opini2_d2_pini u_or_134 (
    .ina({ina1_134, ina0_134}), .inb({or1_13, ny0_134}),
    .rnd(r[134]), .s(s[134]), .clk(clk), .out({w1_134, w0_134}));
wire or0_134 = w0_134 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_134 = w1_134;
wire nx0_135 = or0_14 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_135 = or0_15 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_135, ina1_135;
always @(posedge clk) begin
    ina0_135 <= nx0_135;
    ina1_135 <= or1_14;
end
wire w0_135, w1_135;
MSKand_opini2_d2_pini u_or_135 (
    .ina({ina1_135, ina0_135}), .inb({or1_15, ny0_135}),
    .rnd(r[135]), .s(s[135]), .clk(clk), .out({w1_135, w0_135}));
wire or0_135 = w0_135 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_135 = w1_135;
wire nx0_136 = or0_16 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_136 = or0_17 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_136, ina1_136;
always @(posedge clk) begin
    ina0_136 <= nx0_136;
    ina1_136 <= or1_16;
end
wire w0_136, w1_136;
MSKand_opini2_d2_pini u_or_136 (
    .ina({ina1_136, ina0_136}), .inb({or1_17, ny0_136}),
    .rnd(r[136]), .s(s[136]), .clk(clk), .out({w1_136, w0_136}));
wire or0_136 = w0_136 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_136 = w1_136;
wire nx0_137 = or0_18 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_137 = or0_19 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_137, ina1_137;
always @(posedge clk) begin
    ina0_137 <= nx0_137;
    ina1_137 <= or1_18;
end
wire w0_137, w1_137;
MSKand_opini2_d2_pini u_or_137 (
    .ina({ina1_137, ina0_137}), .inb({or1_19, ny0_137}),
    .rnd(r[137]), .s(s[137]), .clk(clk), .out({w1_137, w0_137}));
wire or0_137 = w0_137 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_137 = w1_137;
wire nx0_138 = or0_20 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_138 = or0_21 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_138, ina1_138;
always @(posedge clk) begin
    ina0_138 <= nx0_138;
    ina1_138 <= or1_20;
end
wire w0_138, w1_138;
MSKand_opini2_d2_pini u_or_138 (
    .ina({ina1_138, ina0_138}), .inb({or1_21, ny0_138}),
    .rnd(r[138]), .s(s[138]), .clk(clk), .out({w1_138, w0_138}));
wire or0_138 = w0_138 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_138 = w1_138;
wire nx0_139 = or0_22 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_139 = or0_23 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_139, ina1_139;
always @(posedge clk) begin
    ina0_139 <= nx0_139;
    ina1_139 <= or1_22;
end
wire w0_139, w1_139;
MSKand_opini2_d2_pini u_or_139 (
    .ina({ina1_139, ina0_139}), .inb({or1_23, ny0_139}),
    .rnd(r[139]), .s(s[139]), .clk(clk), .out({w1_139, w0_139}));
wire or0_139 = w0_139 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_139 = w1_139;
wire nx0_140 = or0_24 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_140 = or0_25 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_140, ina1_140;
always @(posedge clk) begin
    ina0_140 <= nx0_140;
    ina1_140 <= or1_24;
end
wire w0_140, w1_140;
MSKand_opini2_d2_pini u_or_140 (
    .ina({ina1_140, ina0_140}), .inb({or1_25, ny0_140}),
    .rnd(r[140]), .s(s[140]), .clk(clk), .out({w1_140, w0_140}));
wire or0_140 = w0_140 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_140 = w1_140;
wire nx0_141 = or0_26 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_141 = or0_27 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_141, ina1_141;
always @(posedge clk) begin
    ina0_141 <= nx0_141;
    ina1_141 <= or1_26;
end
wire w0_141, w1_141;
MSKand_opini2_d2_pini u_or_141 (
    .ina({ina1_141, ina0_141}), .inb({or1_27, ny0_141}),
    .rnd(r[141]), .s(s[141]), .clk(clk), .out({w1_141, w0_141}));
wire or0_141 = w0_141 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_141 = w1_141;
wire nx0_142 = or0_28 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_142 = or0_29 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_142, ina1_142;
always @(posedge clk) begin
    ina0_142 <= nx0_142;
    ina1_142 <= or1_28;
end
wire w0_142, w1_142;
MSKand_opini2_d2_pini u_or_142 (
    .ina({ina1_142, ina0_142}), .inb({or1_29, ny0_142}),
    .rnd(r[142]), .s(s[142]), .clk(clk), .out({w1_142, w0_142}));
wire or0_142 = w0_142 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_142 = w1_142;
wire nx0_143 = or0_30 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_143 = or0_31 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_143, ina1_143;
always @(posedge clk) begin
    ina0_143 <= nx0_143;
    ina1_143 <= or1_30;
end
wire w0_143, w1_143;
MSKand_opini2_d2_pini u_or_143 (
    .ina({ina1_143, ina0_143}), .inb({or1_31, ny0_143}),
    .rnd(r[143]), .s(s[143]), .clk(clk), .out({w1_143, w0_143}));
wire or0_143 = w0_143 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_143 = w1_143;
wire nx0_144 = or0_32 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_144 = or0_33 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_144, ina1_144;
always @(posedge clk) begin
    ina0_144 <= nx0_144;
    ina1_144 <= or1_32;
end
wire w0_144, w1_144;
MSKand_opini2_d2_pini u_or_144 (
    .ina({ina1_144, ina0_144}), .inb({or1_33, ny0_144}),
    .rnd(r[144]), .s(s[144]), .clk(clk), .out({w1_144, w0_144}));
wire or0_144 = w0_144 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_144 = w1_144;
wire nx0_145 = or0_34 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_145 = or0_35 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_145, ina1_145;
always @(posedge clk) begin
    ina0_145 <= nx0_145;
    ina1_145 <= or1_34;
end
wire w0_145, w1_145;
MSKand_opini2_d2_pini u_or_145 (
    .ina({ina1_145, ina0_145}), .inb({or1_35, ny0_145}),
    .rnd(r[145]), .s(s[145]), .clk(clk), .out({w1_145, w0_145}));
wire or0_145 = w0_145 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_145 = w1_145;
wire nx0_146 = or0_36 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_146 = or0_37 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_146, ina1_146;
always @(posedge clk) begin
    ina0_146 <= nx0_146;
    ina1_146 <= or1_36;
end
wire w0_146, w1_146;
MSKand_opini2_d2_pini u_or_146 (
    .ina({ina1_146, ina0_146}), .inb({or1_37, ny0_146}),
    .rnd(r[146]), .s(s[146]), .clk(clk), .out({w1_146, w0_146}));
wire or0_146 = w0_146 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_146 = w1_146;
wire nx0_147 = or0_38 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_147 = or0_39 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_147, ina1_147;
always @(posedge clk) begin
    ina0_147 <= nx0_147;
    ina1_147 <= or1_38;
end
wire w0_147, w1_147;
MSKand_opini2_d2_pini u_or_147 (
    .ina({ina1_147, ina0_147}), .inb({or1_39, ny0_147}),
    .rnd(r[147]), .s(s[147]), .clk(clk), .out({w1_147, w0_147}));
wire or0_147 = w0_147 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_147 = w1_147;
wire nx0_148 = or0_40 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_148 = or0_41 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_148, ina1_148;
always @(posedge clk) begin
    ina0_148 <= nx0_148;
    ina1_148 <= or1_40;
end
wire w0_148, w1_148;
MSKand_opini2_d2_pini u_or_148 (
    .ina({ina1_148, ina0_148}), .inb({or1_41, ny0_148}),
    .rnd(r[148]), .s(s[148]), .clk(clk), .out({w1_148, w0_148}));
wire or0_148 = w0_148 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_148 = w1_148;
wire nx0_149 = or0_42 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_149 = or0_43 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_149, ina1_149;
always @(posedge clk) begin
    ina0_149 <= nx0_149;
    ina1_149 <= or1_42;
end
wire w0_149, w1_149;
MSKand_opini2_d2_pini u_or_149 (
    .ina({ina1_149, ina0_149}), .inb({or1_43, ny0_149}),
    .rnd(r[149]), .s(s[149]), .clk(clk), .out({w1_149, w0_149}));
wire or0_149 = w0_149 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_149 = w1_149;
wire nx0_150 = or0_44 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_150 = or0_45 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_150, ina1_150;
always @(posedge clk) begin
    ina0_150 <= nx0_150;
    ina1_150 <= or1_44;
end
wire w0_150, w1_150;
MSKand_opini2_d2_pini u_or_150 (
    .ina({ina1_150, ina0_150}), .inb({or1_45, ny0_150}),
    .rnd(r[150]), .s(s[150]), .clk(clk), .out({w1_150, w0_150}));
wire or0_150 = w0_150 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_150 = w1_150;
wire nx0_151 = or0_46 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_151 = or0_47 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_151, ina1_151;
always @(posedge clk) begin
    ina0_151 <= nx0_151;
    ina1_151 <= or1_46;
end
wire w0_151, w1_151;
MSKand_opini2_d2_pini u_or_151 (
    .ina({ina1_151, ina0_151}), .inb({or1_47, ny0_151}),
    .rnd(r[151]), .s(s[151]), .clk(clk), .out({w1_151, w0_151}));
wire or0_151 = w0_151 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_151 = w1_151;
wire nx0_152 = or0_48 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_152 = or0_49 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_152, ina1_152;
always @(posedge clk) begin
    ina0_152 <= nx0_152;
    ina1_152 <= or1_48;
end
wire w0_152, w1_152;
MSKand_opini2_d2_pini u_or_152 (
    .ina({ina1_152, ina0_152}), .inb({or1_49, ny0_152}),
    .rnd(r[152]), .s(s[152]), .clk(clk), .out({w1_152, w0_152}));
wire or0_152 = w0_152 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_152 = w1_152;
wire nx0_153 = or0_50 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_153 = or0_51 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_153, ina1_153;
always @(posedge clk) begin
    ina0_153 <= nx0_153;
    ina1_153 <= or1_50;
end
wire w0_153, w1_153;
MSKand_opini2_d2_pini u_or_153 (
    .ina({ina1_153, ina0_153}), .inb({or1_51, ny0_153}),
    .rnd(r[153]), .s(s[153]), .clk(clk), .out({w1_153, w0_153}));
wire or0_153 = w0_153 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_153 = w1_153;
wire nx0_154 = or0_52 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_154 = or0_53 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_154, ina1_154;
always @(posedge clk) begin
    ina0_154 <= nx0_154;
    ina1_154 <= or1_52;
end
wire w0_154, w1_154;
MSKand_opini2_d2_pini u_or_154 (
    .ina({ina1_154, ina0_154}), .inb({or1_53, ny0_154}),
    .rnd(r[154]), .s(s[154]), .clk(clk), .out({w1_154, w0_154}));
wire or0_154 = w0_154 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_154 = w1_154;
wire nx0_155 = or0_54 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_155 = or0_55 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_155, ina1_155;
always @(posedge clk) begin
    ina0_155 <= nx0_155;
    ina1_155 <= or1_54;
end
wire w0_155, w1_155;
MSKand_opini2_d2_pini u_or_155 (
    .ina({ina1_155, ina0_155}), .inb({or1_55, ny0_155}),
    .rnd(r[155]), .s(s[155]), .clk(clk), .out({w1_155, w0_155}));
wire or0_155 = w0_155 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_155 = w1_155;
wire nx0_156 = or0_56 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_156 = or0_57 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_156, ina1_156;
always @(posedge clk) begin
    ina0_156 <= nx0_156;
    ina1_156 <= or1_56;
end
wire w0_156, w1_156;
MSKand_opini2_d2_pini u_or_156 (
    .ina({ina1_156, ina0_156}), .inb({or1_57, ny0_156}),
    .rnd(r[156]), .s(s[156]), .clk(clk), .out({w1_156, w0_156}));
wire or0_156 = w0_156 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_156 = w1_156;
wire nx0_157 = or0_58 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_157 = or0_59 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_157, ina1_157;
always @(posedge clk) begin
    ina0_157 <= nx0_157;
    ina1_157 <= or1_58;
end
wire w0_157, w1_157;
MSKand_opini2_d2_pini u_or_157 (
    .ina({ina1_157, ina0_157}), .inb({or1_59, ny0_157}),
    .rnd(r[157]), .s(s[157]), .clk(clk), .out({w1_157, w0_157}));
wire or0_157 = w0_157 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_157 = w1_157;
wire nx0_158 = or0_60 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_158 = or0_61 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_158, ina1_158;
always @(posedge clk) begin
    ina0_158 <= nx0_158;
    ina1_158 <= or1_60;
end
wire w0_158, w1_158;
MSKand_opini2_d2_pini u_or_158 (
    .ina({ina1_158, ina0_158}), .inb({or1_61, ny0_158}),
    .rnd(r[158]), .s(s[158]), .clk(clk), .out({w1_158, w0_158}));
wire or0_158 = w0_158 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_158 = w1_158;
wire nx0_159 = or0_62 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_159 = or0_63 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_159, ina1_159;
always @(posedge clk) begin
    ina0_159 <= nx0_159;
    ina1_159 <= or1_62;
end
wire w0_159, w1_159;
MSKand_opini2_d2_pini u_or_159 (
    .ina({ina1_159, ina0_159}), .inb({or1_63, ny0_159}),
    .rnd(r[159]), .s(s[159]), .clk(clk), .out({w1_159, w0_159}));
wire or0_159 = w0_159 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_159 = w1_159;
wire nx0_160 = or0_64 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_160 = or0_65 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_160, ina1_160;
always @(posedge clk) begin
    ina0_160 <= nx0_160;
    ina1_160 <= or1_64;
end
wire w0_160, w1_160;
MSKand_opini2_d2_pini u_or_160 (
    .ina({ina1_160, ina0_160}), .inb({or1_65, ny0_160}),
    .rnd(r[160]), .s(s[160]), .clk(clk), .out({w1_160, w0_160}));
wire or0_160 = w0_160 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_160 = w1_160;
wire nx0_161 = or0_66 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_161 = or0_67 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_161, ina1_161;
always @(posedge clk) begin
    ina0_161 <= nx0_161;
    ina1_161 <= or1_66;
end
wire w0_161, w1_161;
MSKand_opini2_d2_pini u_or_161 (
    .ina({ina1_161, ina0_161}), .inb({or1_67, ny0_161}),
    .rnd(r[161]), .s(s[161]), .clk(clk), .out({w1_161, w0_161}));
wire or0_161 = w0_161 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_161 = w1_161;
wire nx0_162 = or0_68 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_162 = or0_69 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_162, ina1_162;
always @(posedge clk) begin
    ina0_162 <= nx0_162;
    ina1_162 <= or1_68;
end
wire w0_162, w1_162;
MSKand_opini2_d2_pini u_or_162 (
    .ina({ina1_162, ina0_162}), .inb({or1_69, ny0_162}),
    .rnd(r[162]), .s(s[162]), .clk(clk), .out({w1_162, w0_162}));
wire or0_162 = w0_162 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_162 = w1_162;
wire nx0_163 = or0_70 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_163 = or0_71 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_163, ina1_163;
always @(posedge clk) begin
    ina0_163 <= nx0_163;
    ina1_163 <= or1_70;
end
wire w0_163, w1_163;
MSKand_opini2_d2_pini u_or_163 (
    .ina({ina1_163, ina0_163}), .inb({or1_71, ny0_163}),
    .rnd(r[163]), .s(s[163]), .clk(clk), .out({w1_163, w0_163}));
wire or0_163 = w0_163 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_163 = w1_163;
wire nx0_164 = or0_72 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_164 = or0_73 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_164, ina1_164;
always @(posedge clk) begin
    ina0_164 <= nx0_164;
    ina1_164 <= or1_72;
end
wire w0_164, w1_164;
MSKand_opini2_d2_pini u_or_164 (
    .ina({ina1_164, ina0_164}), .inb({or1_73, ny0_164}),
    .rnd(r[164]), .s(s[164]), .clk(clk), .out({w1_164, w0_164}));
wire or0_164 = w0_164 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_164 = w1_164;
wire nx0_165 = or0_74 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_165 = or0_75 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_165, ina1_165;
always @(posedge clk) begin
    ina0_165 <= nx0_165;
    ina1_165 <= or1_74;
end
wire w0_165, w1_165;
MSKand_opini2_d2_pini u_or_165 (
    .ina({ina1_165, ina0_165}), .inb({or1_75, ny0_165}),
    .rnd(r[165]), .s(s[165]), .clk(clk), .out({w1_165, w0_165}));
wire or0_165 = w0_165 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_165 = w1_165;
wire nx0_166 = or0_76 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_166 = or0_77 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_166, ina1_166;
always @(posedge clk) begin
    ina0_166 <= nx0_166;
    ina1_166 <= or1_76;
end
wire w0_166, w1_166;
MSKand_opini2_d2_pini u_or_166 (
    .ina({ina1_166, ina0_166}), .inb({or1_77, ny0_166}),
    .rnd(r[166]), .s(s[166]), .clk(clk), .out({w1_166, w0_166}));
wire or0_166 = w0_166 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_166 = w1_166;
wire nx0_167 = or0_78 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_167 = or0_79 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_167, ina1_167;
always @(posedge clk) begin
    ina0_167 <= nx0_167;
    ina1_167 <= or1_78;
end
wire w0_167, w1_167;
MSKand_opini2_d2_pini u_or_167 (
    .ina({ina1_167, ina0_167}), .inb({or1_79, ny0_167}),
    .rnd(r[167]), .s(s[167]), .clk(clk), .out({w1_167, w0_167}));
wire or0_167 = w0_167 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_167 = w1_167;
wire nx0_168 = or0_80 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_168 = or0_81 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_168, ina1_168;
always @(posedge clk) begin
    ina0_168 <= nx0_168;
    ina1_168 <= or1_80;
end
wire w0_168, w1_168;
MSKand_opini2_d2_pini u_or_168 (
    .ina({ina1_168, ina0_168}), .inb({or1_81, ny0_168}),
    .rnd(r[168]), .s(s[168]), .clk(clk), .out({w1_168, w0_168}));
wire or0_168 = w0_168 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_168 = w1_168;
wire nx0_169 = or0_82 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_169 = or0_83 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_169, ina1_169;
always @(posedge clk) begin
    ina0_169 <= nx0_169;
    ina1_169 <= or1_82;
end
wire w0_169, w1_169;
MSKand_opini2_d2_pini u_or_169 (
    .ina({ina1_169, ina0_169}), .inb({or1_83, ny0_169}),
    .rnd(r[169]), .s(s[169]), .clk(clk), .out({w1_169, w0_169}));
wire or0_169 = w0_169 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_169 = w1_169;
wire nx0_170 = or0_84 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_170 = or0_85 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_170, ina1_170;
always @(posedge clk) begin
    ina0_170 <= nx0_170;
    ina1_170 <= or1_84;
end
wire w0_170, w1_170;
MSKand_opini2_d2_pini u_or_170 (
    .ina({ina1_170, ina0_170}), .inb({or1_85, ny0_170}),
    .rnd(r[170]), .s(s[170]), .clk(clk), .out({w1_170, w0_170}));
wire or0_170 = w0_170 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_170 = w1_170;
wire nx0_171 = or0_86 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_171 = or0_87 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_171, ina1_171;
always @(posedge clk) begin
    ina0_171 <= nx0_171;
    ina1_171 <= or1_86;
end
wire w0_171, w1_171;
MSKand_opini2_d2_pini u_or_171 (
    .ina({ina1_171, ina0_171}), .inb({or1_87, ny0_171}),
    .rnd(r[171]), .s(s[171]), .clk(clk), .out({w1_171, w0_171}));
wire or0_171 = w0_171 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_171 = w1_171;
wire nx0_172 = or0_88 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_172 = or0_89 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_172, ina1_172;
always @(posedge clk) begin
    ina0_172 <= nx0_172;
    ina1_172 <= or1_88;
end
wire w0_172, w1_172;
MSKand_opini2_d2_pini u_or_172 (
    .ina({ina1_172, ina0_172}), .inb({or1_89, ny0_172}),
    .rnd(r[172]), .s(s[172]), .clk(clk), .out({w1_172, w0_172}));
wire or0_172 = w0_172 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_172 = w1_172;
wire nx0_173 = or0_90 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_173 = or0_91 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_173, ina1_173;
always @(posedge clk) begin
    ina0_173 <= nx0_173;
    ina1_173 <= or1_90;
end
wire w0_173, w1_173;
MSKand_opini2_d2_pini u_or_173 (
    .ina({ina1_173, ina0_173}), .inb({or1_91, ny0_173}),
    .rnd(r[173]), .s(s[173]), .clk(clk), .out({w1_173, w0_173}));
wire or0_173 = w0_173 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_173 = w1_173;
wire nx0_174 = or0_92 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_174 = or0_93 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_174, ina1_174;
always @(posedge clk) begin
    ina0_174 <= nx0_174;
    ina1_174 <= or1_92;
end
wire w0_174, w1_174;
MSKand_opini2_d2_pini u_or_174 (
    .ina({ina1_174, ina0_174}), .inb({or1_93, ny0_174}),
    .rnd(r[174]), .s(s[174]), .clk(clk), .out({w1_174, w0_174}));
wire or0_174 = w0_174 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_174 = w1_174;
wire nx0_175 = or0_94 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_175 = or0_95 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_175, ina1_175;
always @(posedge clk) begin
    ina0_175 <= nx0_175;
    ina1_175 <= or1_94;
end
wire w0_175, w1_175;
MSKand_opini2_d2_pini u_or_175 (
    .ina({ina1_175, ina0_175}), .inb({or1_95, ny0_175}),
    .rnd(r[175]), .s(s[175]), .clk(clk), .out({w1_175, w0_175}));
wire or0_175 = w0_175 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_175 = w1_175;
wire nx0_176 = or0_96 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_176 = or0_97 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_176, ina1_176;
always @(posedge clk) begin
    ina0_176 <= nx0_176;
    ina1_176 <= or1_96;
end
wire w0_176, w1_176;
MSKand_opini2_d2_pini u_or_176 (
    .ina({ina1_176, ina0_176}), .inb({or1_97, ny0_176}),
    .rnd(r[176]), .s(s[176]), .clk(clk), .out({w1_176, w0_176}));
wire or0_176 = w0_176 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_176 = w1_176;
wire nx0_177 = or0_98 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_177 = or0_99 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_177, ina1_177;
always @(posedge clk) begin
    ina0_177 <= nx0_177;
    ina1_177 <= or1_98;
end
wire w0_177, w1_177;
MSKand_opini2_d2_pini u_or_177 (
    .ina({ina1_177, ina0_177}), .inb({or1_99, ny0_177}),
    .rnd(r[177]), .s(s[177]), .clk(clk), .out({w1_177, w0_177}));
wire or0_177 = w0_177 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_177 = w1_177;
wire nx0_178 = or0_100 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_178 = or0_101 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_178, ina1_178;
always @(posedge clk) begin
    ina0_178 <= nx0_178;
    ina1_178 <= or1_100;
end
wire w0_178, w1_178;
MSKand_opini2_d2_pini u_or_178 (
    .ina({ina1_178, ina0_178}), .inb({or1_101, ny0_178}),
    .rnd(r[178]), .s(s[178]), .clk(clk), .out({w1_178, w0_178}));
wire or0_178 = w0_178 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_178 = w1_178;
wire nx0_179 = or0_102 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_179 = or0_103 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_179, ina1_179;
always @(posedge clk) begin
    ina0_179 <= nx0_179;
    ina1_179 <= or1_102;
end
wire w0_179, w1_179;
MSKand_opini2_d2_pini u_or_179 (
    .ina({ina1_179, ina0_179}), .inb({or1_103, ny0_179}),
    .rnd(r[179]), .s(s[179]), .clk(clk), .out({w1_179, w0_179}));
wire or0_179 = w0_179 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_179 = w1_179;
wire nx0_180 = or0_104 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_180 = or0_105 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_180, ina1_180;
always @(posedge clk) begin
    ina0_180 <= nx0_180;
    ina1_180 <= or1_104;
end
wire w0_180, w1_180;
MSKand_opini2_d2_pini u_or_180 (
    .ina({ina1_180, ina0_180}), .inb({or1_105, ny0_180}),
    .rnd(r[180]), .s(s[180]), .clk(clk), .out({w1_180, w0_180}));
wire or0_180 = w0_180 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_180 = w1_180;
wire nx0_181 = or0_106 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_181 = or0_107 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_181, ina1_181;
always @(posedge clk) begin
    ina0_181 <= nx0_181;
    ina1_181 <= or1_106;
end
wire w0_181, w1_181;
MSKand_opini2_d2_pini u_or_181 (
    .ina({ina1_181, ina0_181}), .inb({or1_107, ny0_181}),
    .rnd(r[181]), .s(s[181]), .clk(clk), .out({w1_181, w0_181}));
wire or0_181 = w0_181 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_181 = w1_181;
wire nx0_182 = or0_108 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_182 = or0_109 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_182, ina1_182;
always @(posedge clk) begin
    ina0_182 <= nx0_182;
    ina1_182 <= or1_108;
end
wire w0_182, w1_182;
MSKand_opini2_d2_pini u_or_182 (
    .ina({ina1_182, ina0_182}), .inb({or1_109, ny0_182}),
    .rnd(r[182]), .s(s[182]), .clk(clk), .out({w1_182, w0_182}));
wire or0_182 = w0_182 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_182 = w1_182;
wire nx0_183 = or0_110 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_183 = or0_111 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_183, ina1_183;
always @(posedge clk) begin
    ina0_183 <= nx0_183;
    ina1_183 <= or1_110;
end
wire w0_183, w1_183;
MSKand_opini2_d2_pini u_or_183 (
    .ina({ina1_183, ina0_183}), .inb({or1_111, ny0_183}),
    .rnd(r[183]), .s(s[183]), .clk(clk), .out({w1_183, w0_183}));
wire or0_183 = w0_183 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_183 = w1_183;
wire nx0_184 = or0_112 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_184 = or0_113 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_184, ina1_184;
always @(posedge clk) begin
    ina0_184 <= nx0_184;
    ina1_184 <= or1_112;
end
wire w0_184, w1_184;
MSKand_opini2_d2_pini u_or_184 (
    .ina({ina1_184, ina0_184}), .inb({or1_113, ny0_184}),
    .rnd(r[184]), .s(s[184]), .clk(clk), .out({w1_184, w0_184}));
wire or0_184 = w0_184 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_184 = w1_184;
wire nx0_185 = or0_114 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_185 = or0_115 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_185, ina1_185;
always @(posedge clk) begin
    ina0_185 <= nx0_185;
    ina1_185 <= or1_114;
end
wire w0_185, w1_185;
MSKand_opini2_d2_pini u_or_185 (
    .ina({ina1_185, ina0_185}), .inb({or1_115, ny0_185}),
    .rnd(r[185]), .s(s[185]), .clk(clk), .out({w1_185, w0_185}));
wire or0_185 = w0_185 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_185 = w1_185;
wire nx0_186 = or0_116 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_186 = or0_117 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_186, ina1_186;
always @(posedge clk) begin
    ina0_186 <= nx0_186;
    ina1_186 <= or1_116;
end
wire w0_186, w1_186;
MSKand_opini2_d2_pini u_or_186 (
    .ina({ina1_186, ina0_186}), .inb({or1_117, ny0_186}),
    .rnd(r[186]), .s(s[186]), .clk(clk), .out({w1_186, w0_186}));
wire or0_186 = w0_186 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_186 = w1_186;
wire nx0_187 = or0_118 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_187 = or0_119 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_187, ina1_187;
always @(posedge clk) begin
    ina0_187 <= nx0_187;
    ina1_187 <= or1_118;
end
wire w0_187, w1_187;
MSKand_opini2_d2_pini u_or_187 (
    .ina({ina1_187, ina0_187}), .inb({or1_119, ny0_187}),
    .rnd(r[187]), .s(s[187]), .clk(clk), .out({w1_187, w0_187}));
wire or0_187 = w0_187 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_187 = w1_187;
wire nx0_188 = or0_120 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_188 = or0_121 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_188, ina1_188;
always @(posedge clk) begin
    ina0_188 <= nx0_188;
    ina1_188 <= or1_120;
end
wire w0_188, w1_188;
MSKand_opini2_d2_pini u_or_188 (
    .ina({ina1_188, ina0_188}), .inb({or1_121, ny0_188}),
    .rnd(r[188]), .s(s[188]), .clk(clk), .out({w1_188, w0_188}));
wire or0_188 = w0_188 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_188 = w1_188;
wire nx0_189 = or0_122 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_189 = or0_123 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_189, ina1_189;
always @(posedge clk) begin
    ina0_189 <= nx0_189;
    ina1_189 <= or1_122;
end
wire w0_189, w1_189;
MSKand_opini2_d2_pini u_or_189 (
    .ina({ina1_189, ina0_189}), .inb({or1_123, ny0_189}),
    .rnd(r[189]), .s(s[189]), .clk(clk), .out({w1_189, w0_189}));
wire or0_189 = w0_189 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_189 = w1_189;
wire nx0_190 = or0_124 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_190 = or0_125 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_190, ina1_190;
always @(posedge clk) begin
    ina0_190 <= nx0_190;
    ina1_190 <= or1_124;
end
wire w0_190, w1_190;
MSKand_opini2_d2_pini u_or_190 (
    .ina({ina1_190, ina0_190}), .inb({or1_125, ny0_190}),
    .rnd(r[190]), .s(s[190]), .clk(clk), .out({w1_190, w0_190}));
wire or0_190 = w0_190 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_190 = w1_190;
wire nx0_191 = or0_126 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_191 = or0_127 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_191, ina1_191;
always @(posedge clk) begin
    ina0_191 <= nx0_191;
    ina1_191 <= or1_126;
end
wire w0_191, w1_191;
MSKand_opini2_d2_pini u_or_191 (
    .ina({ina1_191, ina0_191}), .inb({or1_127, ny0_191}),
    .rnd(r[191]), .s(s[191]), .clk(clk), .out({w1_191, w0_191}));
wire or0_191 = w0_191 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_191 = w1_191;

// ===== OR-reduce level 2: 64 masked bits -> 32 =====
wire nx0_192 = or0_128 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_192 = or0_129 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_192, ina1_192;
always @(posedge clk) begin
    ina0_192 <= nx0_192;
    ina1_192 <= or1_128;
end
wire w0_192, w1_192;
MSKand_opini2_d2_pini u_or_192 (
    .ina({ina1_192, ina0_192}), .inb({or1_129, ny0_192}),
    .rnd(r[192]), .s(s[192]), .clk(clk), .out({w1_192, w0_192}));
wire or0_192 = w0_192 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_192 = w1_192;
wire nx0_193 = or0_130 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_193 = or0_131 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_193, ina1_193;
always @(posedge clk) begin
    ina0_193 <= nx0_193;
    ina1_193 <= or1_130;
end
wire w0_193, w1_193;
MSKand_opini2_d2_pini u_or_193 (
    .ina({ina1_193, ina0_193}), .inb({or1_131, ny0_193}),
    .rnd(r[193]), .s(s[193]), .clk(clk), .out({w1_193, w0_193}));
wire or0_193 = w0_193 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_193 = w1_193;
wire nx0_194 = or0_132 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_194 = or0_133 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_194, ina1_194;
always @(posedge clk) begin
    ina0_194 <= nx0_194;
    ina1_194 <= or1_132;
end
wire w0_194, w1_194;
MSKand_opini2_d2_pini u_or_194 (
    .ina({ina1_194, ina0_194}), .inb({or1_133, ny0_194}),
    .rnd(r[194]), .s(s[194]), .clk(clk), .out({w1_194, w0_194}));
wire or0_194 = w0_194 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_194 = w1_194;
wire nx0_195 = or0_134 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_195 = or0_135 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_195, ina1_195;
always @(posedge clk) begin
    ina0_195 <= nx0_195;
    ina1_195 <= or1_134;
end
wire w0_195, w1_195;
MSKand_opini2_d2_pini u_or_195 (
    .ina({ina1_195, ina0_195}), .inb({or1_135, ny0_195}),
    .rnd(r[195]), .s(s[195]), .clk(clk), .out({w1_195, w0_195}));
wire or0_195 = w0_195 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_195 = w1_195;
wire nx0_196 = or0_136 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_196 = or0_137 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_196, ina1_196;
always @(posedge clk) begin
    ina0_196 <= nx0_196;
    ina1_196 <= or1_136;
end
wire w0_196, w1_196;
MSKand_opini2_d2_pini u_or_196 (
    .ina({ina1_196, ina0_196}), .inb({or1_137, ny0_196}),
    .rnd(r[196]), .s(s[196]), .clk(clk), .out({w1_196, w0_196}));
wire or0_196 = w0_196 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_196 = w1_196;
wire nx0_197 = or0_138 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_197 = or0_139 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_197, ina1_197;
always @(posedge clk) begin
    ina0_197 <= nx0_197;
    ina1_197 <= or1_138;
end
wire w0_197, w1_197;
MSKand_opini2_d2_pini u_or_197 (
    .ina({ina1_197, ina0_197}), .inb({or1_139, ny0_197}),
    .rnd(r[197]), .s(s[197]), .clk(clk), .out({w1_197, w0_197}));
wire or0_197 = w0_197 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_197 = w1_197;
wire nx0_198 = or0_140 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_198 = or0_141 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_198, ina1_198;
always @(posedge clk) begin
    ina0_198 <= nx0_198;
    ina1_198 <= or1_140;
end
wire w0_198, w1_198;
MSKand_opini2_d2_pini u_or_198 (
    .ina({ina1_198, ina0_198}), .inb({or1_141, ny0_198}),
    .rnd(r[198]), .s(s[198]), .clk(clk), .out({w1_198, w0_198}));
wire or0_198 = w0_198 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_198 = w1_198;
wire nx0_199 = or0_142 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_199 = or0_143 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_199, ina1_199;
always @(posedge clk) begin
    ina0_199 <= nx0_199;
    ina1_199 <= or1_142;
end
wire w0_199, w1_199;
MSKand_opini2_d2_pini u_or_199 (
    .ina({ina1_199, ina0_199}), .inb({or1_143, ny0_199}),
    .rnd(r[199]), .s(s[199]), .clk(clk), .out({w1_199, w0_199}));
wire or0_199 = w0_199 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_199 = w1_199;
wire nx0_200 = or0_144 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_200 = or0_145 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_200, ina1_200;
always @(posedge clk) begin
    ina0_200 <= nx0_200;
    ina1_200 <= or1_144;
end
wire w0_200, w1_200;
MSKand_opini2_d2_pini u_or_200 (
    .ina({ina1_200, ina0_200}), .inb({or1_145, ny0_200}),
    .rnd(r[200]), .s(s[200]), .clk(clk), .out({w1_200, w0_200}));
wire or0_200 = w0_200 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_200 = w1_200;
wire nx0_201 = or0_146 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_201 = or0_147 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_201, ina1_201;
always @(posedge clk) begin
    ina0_201 <= nx0_201;
    ina1_201 <= or1_146;
end
wire w0_201, w1_201;
MSKand_opini2_d2_pini u_or_201 (
    .ina({ina1_201, ina0_201}), .inb({or1_147, ny0_201}),
    .rnd(r[201]), .s(s[201]), .clk(clk), .out({w1_201, w0_201}));
wire or0_201 = w0_201 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_201 = w1_201;
wire nx0_202 = or0_148 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_202 = or0_149 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_202, ina1_202;
always @(posedge clk) begin
    ina0_202 <= nx0_202;
    ina1_202 <= or1_148;
end
wire w0_202, w1_202;
MSKand_opini2_d2_pini u_or_202 (
    .ina({ina1_202, ina0_202}), .inb({or1_149, ny0_202}),
    .rnd(r[202]), .s(s[202]), .clk(clk), .out({w1_202, w0_202}));
wire or0_202 = w0_202 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_202 = w1_202;
wire nx0_203 = or0_150 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_203 = or0_151 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_203, ina1_203;
always @(posedge clk) begin
    ina0_203 <= nx0_203;
    ina1_203 <= or1_150;
end
wire w0_203, w1_203;
MSKand_opini2_d2_pini u_or_203 (
    .ina({ina1_203, ina0_203}), .inb({or1_151, ny0_203}),
    .rnd(r[203]), .s(s[203]), .clk(clk), .out({w1_203, w0_203}));
wire or0_203 = w0_203 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_203 = w1_203;
wire nx0_204 = or0_152 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_204 = or0_153 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_204, ina1_204;
always @(posedge clk) begin
    ina0_204 <= nx0_204;
    ina1_204 <= or1_152;
end
wire w0_204, w1_204;
MSKand_opini2_d2_pini u_or_204 (
    .ina({ina1_204, ina0_204}), .inb({or1_153, ny0_204}),
    .rnd(r[204]), .s(s[204]), .clk(clk), .out({w1_204, w0_204}));
wire or0_204 = w0_204 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_204 = w1_204;
wire nx0_205 = or0_154 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_205 = or0_155 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_205, ina1_205;
always @(posedge clk) begin
    ina0_205 <= nx0_205;
    ina1_205 <= or1_154;
end
wire w0_205, w1_205;
MSKand_opini2_d2_pini u_or_205 (
    .ina({ina1_205, ina0_205}), .inb({or1_155, ny0_205}),
    .rnd(r[205]), .s(s[205]), .clk(clk), .out({w1_205, w0_205}));
wire or0_205 = w0_205 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_205 = w1_205;
wire nx0_206 = or0_156 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_206 = or0_157 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_206, ina1_206;
always @(posedge clk) begin
    ina0_206 <= nx0_206;
    ina1_206 <= or1_156;
end
wire w0_206, w1_206;
MSKand_opini2_d2_pini u_or_206 (
    .ina({ina1_206, ina0_206}), .inb({or1_157, ny0_206}),
    .rnd(r[206]), .s(s[206]), .clk(clk), .out({w1_206, w0_206}));
wire or0_206 = w0_206 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_206 = w1_206;
wire nx0_207 = or0_158 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_207 = or0_159 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_207, ina1_207;
always @(posedge clk) begin
    ina0_207 <= nx0_207;
    ina1_207 <= or1_158;
end
wire w0_207, w1_207;
MSKand_opini2_d2_pini u_or_207 (
    .ina({ina1_207, ina0_207}), .inb({or1_159, ny0_207}),
    .rnd(r[207]), .s(s[207]), .clk(clk), .out({w1_207, w0_207}));
wire or0_207 = w0_207 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_207 = w1_207;
wire nx0_208 = or0_160 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_208 = or0_161 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_208, ina1_208;
always @(posedge clk) begin
    ina0_208 <= nx0_208;
    ina1_208 <= or1_160;
end
wire w0_208, w1_208;
MSKand_opini2_d2_pini u_or_208 (
    .ina({ina1_208, ina0_208}), .inb({or1_161, ny0_208}),
    .rnd(r[208]), .s(s[208]), .clk(clk), .out({w1_208, w0_208}));
wire or0_208 = w0_208 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_208 = w1_208;
wire nx0_209 = or0_162 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_209 = or0_163 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_209, ina1_209;
always @(posedge clk) begin
    ina0_209 <= nx0_209;
    ina1_209 <= or1_162;
end
wire w0_209, w1_209;
MSKand_opini2_d2_pini u_or_209 (
    .ina({ina1_209, ina0_209}), .inb({or1_163, ny0_209}),
    .rnd(r[209]), .s(s[209]), .clk(clk), .out({w1_209, w0_209}));
wire or0_209 = w0_209 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_209 = w1_209;
wire nx0_210 = or0_164 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_210 = or0_165 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_210, ina1_210;
always @(posedge clk) begin
    ina0_210 <= nx0_210;
    ina1_210 <= or1_164;
end
wire w0_210, w1_210;
MSKand_opini2_d2_pini u_or_210 (
    .ina({ina1_210, ina0_210}), .inb({or1_165, ny0_210}),
    .rnd(r[210]), .s(s[210]), .clk(clk), .out({w1_210, w0_210}));
wire or0_210 = w0_210 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_210 = w1_210;
wire nx0_211 = or0_166 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_211 = or0_167 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_211, ina1_211;
always @(posedge clk) begin
    ina0_211 <= nx0_211;
    ina1_211 <= or1_166;
end
wire w0_211, w1_211;
MSKand_opini2_d2_pini u_or_211 (
    .ina({ina1_211, ina0_211}), .inb({or1_167, ny0_211}),
    .rnd(r[211]), .s(s[211]), .clk(clk), .out({w1_211, w0_211}));
wire or0_211 = w0_211 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_211 = w1_211;
wire nx0_212 = or0_168 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_212 = or0_169 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_212, ina1_212;
always @(posedge clk) begin
    ina0_212 <= nx0_212;
    ina1_212 <= or1_168;
end
wire w0_212, w1_212;
MSKand_opini2_d2_pini u_or_212 (
    .ina({ina1_212, ina0_212}), .inb({or1_169, ny0_212}),
    .rnd(r[212]), .s(s[212]), .clk(clk), .out({w1_212, w0_212}));
wire or0_212 = w0_212 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_212 = w1_212;
wire nx0_213 = or0_170 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_213 = or0_171 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_213, ina1_213;
always @(posedge clk) begin
    ina0_213 <= nx0_213;
    ina1_213 <= or1_170;
end
wire w0_213, w1_213;
MSKand_opini2_d2_pini u_or_213 (
    .ina({ina1_213, ina0_213}), .inb({or1_171, ny0_213}),
    .rnd(r[213]), .s(s[213]), .clk(clk), .out({w1_213, w0_213}));
wire or0_213 = w0_213 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_213 = w1_213;
wire nx0_214 = or0_172 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_214 = or0_173 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_214, ina1_214;
always @(posedge clk) begin
    ina0_214 <= nx0_214;
    ina1_214 <= or1_172;
end
wire w0_214, w1_214;
MSKand_opini2_d2_pini u_or_214 (
    .ina({ina1_214, ina0_214}), .inb({or1_173, ny0_214}),
    .rnd(r[214]), .s(s[214]), .clk(clk), .out({w1_214, w0_214}));
wire or0_214 = w0_214 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_214 = w1_214;
wire nx0_215 = or0_174 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_215 = or0_175 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_215, ina1_215;
always @(posedge clk) begin
    ina0_215 <= nx0_215;
    ina1_215 <= or1_174;
end
wire w0_215, w1_215;
MSKand_opini2_d2_pini u_or_215 (
    .ina({ina1_215, ina0_215}), .inb({or1_175, ny0_215}),
    .rnd(r[215]), .s(s[215]), .clk(clk), .out({w1_215, w0_215}));
wire or0_215 = w0_215 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_215 = w1_215;
wire nx0_216 = or0_176 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_216 = or0_177 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_216, ina1_216;
always @(posedge clk) begin
    ina0_216 <= nx0_216;
    ina1_216 <= or1_176;
end
wire w0_216, w1_216;
MSKand_opini2_d2_pini u_or_216 (
    .ina({ina1_216, ina0_216}), .inb({or1_177, ny0_216}),
    .rnd(r[216]), .s(s[216]), .clk(clk), .out({w1_216, w0_216}));
wire or0_216 = w0_216 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_216 = w1_216;
wire nx0_217 = or0_178 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_217 = or0_179 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_217, ina1_217;
always @(posedge clk) begin
    ina0_217 <= nx0_217;
    ina1_217 <= or1_178;
end
wire w0_217, w1_217;
MSKand_opini2_d2_pini u_or_217 (
    .ina({ina1_217, ina0_217}), .inb({or1_179, ny0_217}),
    .rnd(r[217]), .s(s[217]), .clk(clk), .out({w1_217, w0_217}));
wire or0_217 = w0_217 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_217 = w1_217;
wire nx0_218 = or0_180 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_218 = or0_181 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_218, ina1_218;
always @(posedge clk) begin
    ina0_218 <= nx0_218;
    ina1_218 <= or1_180;
end
wire w0_218, w1_218;
MSKand_opini2_d2_pini u_or_218 (
    .ina({ina1_218, ina0_218}), .inb({or1_181, ny0_218}),
    .rnd(r[218]), .s(s[218]), .clk(clk), .out({w1_218, w0_218}));
wire or0_218 = w0_218 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_218 = w1_218;
wire nx0_219 = or0_182 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_219 = or0_183 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_219, ina1_219;
always @(posedge clk) begin
    ina0_219 <= nx0_219;
    ina1_219 <= or1_182;
end
wire w0_219, w1_219;
MSKand_opini2_d2_pini u_or_219 (
    .ina({ina1_219, ina0_219}), .inb({or1_183, ny0_219}),
    .rnd(r[219]), .s(s[219]), .clk(clk), .out({w1_219, w0_219}));
wire or0_219 = w0_219 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_219 = w1_219;
wire nx0_220 = or0_184 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_220 = or0_185 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_220, ina1_220;
always @(posedge clk) begin
    ina0_220 <= nx0_220;
    ina1_220 <= or1_184;
end
wire w0_220, w1_220;
MSKand_opini2_d2_pini u_or_220 (
    .ina({ina1_220, ina0_220}), .inb({or1_185, ny0_220}),
    .rnd(r[220]), .s(s[220]), .clk(clk), .out({w1_220, w0_220}));
wire or0_220 = w0_220 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_220 = w1_220;
wire nx0_221 = or0_186 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_221 = or0_187 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_221, ina1_221;
always @(posedge clk) begin
    ina0_221 <= nx0_221;
    ina1_221 <= or1_186;
end
wire w0_221, w1_221;
MSKand_opini2_d2_pini u_or_221 (
    .ina({ina1_221, ina0_221}), .inb({or1_187, ny0_221}),
    .rnd(r[221]), .s(s[221]), .clk(clk), .out({w1_221, w0_221}));
wire or0_221 = w0_221 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_221 = w1_221;
wire nx0_222 = or0_188 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_222 = or0_189 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_222, ina1_222;
always @(posedge clk) begin
    ina0_222 <= nx0_222;
    ina1_222 <= or1_188;
end
wire w0_222, w1_222;
MSKand_opini2_d2_pini u_or_222 (
    .ina({ina1_222, ina0_222}), .inb({or1_189, ny0_222}),
    .rnd(r[222]), .s(s[222]), .clk(clk), .out({w1_222, w0_222}));
wire or0_222 = w0_222 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_222 = w1_222;
wire nx0_223 = or0_190 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_223 = or0_191 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_223, ina1_223;
always @(posedge clk) begin
    ina0_223 <= nx0_223;
    ina1_223 <= or1_190;
end
wire w0_223, w1_223;
MSKand_opini2_d2_pini u_or_223 (
    .ina({ina1_223, ina0_223}), .inb({or1_191, ny0_223}),
    .rnd(r[223]), .s(s[223]), .clk(clk), .out({w1_223, w0_223}));
wire or0_223 = w0_223 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_223 = w1_223;

// ===== OR-reduce level 3: 32 masked bits -> 16 =====
wire nx0_224 = or0_192 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_224 = or0_193 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_224, ina1_224;
always @(posedge clk) begin
    ina0_224 <= nx0_224;
    ina1_224 <= or1_192;
end
wire w0_224, w1_224;
MSKand_opini2_d2_pini u_or_224 (
    .ina({ina1_224, ina0_224}), .inb({or1_193, ny0_224}),
    .rnd(r[224]), .s(s[224]), .clk(clk), .out({w1_224, w0_224}));
wire or0_224 = w0_224 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_224 = w1_224;
wire nx0_225 = or0_194 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_225 = or0_195 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_225, ina1_225;
always @(posedge clk) begin
    ina0_225 <= nx0_225;
    ina1_225 <= or1_194;
end
wire w0_225, w1_225;
MSKand_opini2_d2_pini u_or_225 (
    .ina({ina1_225, ina0_225}), .inb({or1_195, ny0_225}),
    .rnd(r[225]), .s(s[225]), .clk(clk), .out({w1_225, w0_225}));
wire or0_225 = w0_225 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_225 = w1_225;
wire nx0_226 = or0_196 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_226 = or0_197 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_226, ina1_226;
always @(posedge clk) begin
    ina0_226 <= nx0_226;
    ina1_226 <= or1_196;
end
wire w0_226, w1_226;
MSKand_opini2_d2_pini u_or_226 (
    .ina({ina1_226, ina0_226}), .inb({or1_197, ny0_226}),
    .rnd(r[226]), .s(s[226]), .clk(clk), .out({w1_226, w0_226}));
wire or0_226 = w0_226 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_226 = w1_226;
wire nx0_227 = or0_198 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_227 = or0_199 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_227, ina1_227;
always @(posedge clk) begin
    ina0_227 <= nx0_227;
    ina1_227 <= or1_198;
end
wire w0_227, w1_227;
MSKand_opini2_d2_pini u_or_227 (
    .ina({ina1_227, ina0_227}), .inb({or1_199, ny0_227}),
    .rnd(r[227]), .s(s[227]), .clk(clk), .out({w1_227, w0_227}));
wire or0_227 = w0_227 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_227 = w1_227;
wire nx0_228 = or0_200 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_228 = or0_201 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_228, ina1_228;
always @(posedge clk) begin
    ina0_228 <= nx0_228;
    ina1_228 <= or1_200;
end
wire w0_228, w1_228;
MSKand_opini2_d2_pini u_or_228 (
    .ina({ina1_228, ina0_228}), .inb({or1_201, ny0_228}),
    .rnd(r[228]), .s(s[228]), .clk(clk), .out({w1_228, w0_228}));
wire or0_228 = w0_228 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_228 = w1_228;
wire nx0_229 = or0_202 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_229 = or0_203 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_229, ina1_229;
always @(posedge clk) begin
    ina0_229 <= nx0_229;
    ina1_229 <= or1_202;
end
wire w0_229, w1_229;
MSKand_opini2_d2_pini u_or_229 (
    .ina({ina1_229, ina0_229}), .inb({or1_203, ny0_229}),
    .rnd(r[229]), .s(s[229]), .clk(clk), .out({w1_229, w0_229}));
wire or0_229 = w0_229 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_229 = w1_229;
wire nx0_230 = or0_204 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_230 = or0_205 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_230, ina1_230;
always @(posedge clk) begin
    ina0_230 <= nx0_230;
    ina1_230 <= or1_204;
end
wire w0_230, w1_230;
MSKand_opini2_d2_pini u_or_230 (
    .ina({ina1_230, ina0_230}), .inb({or1_205, ny0_230}),
    .rnd(r[230]), .s(s[230]), .clk(clk), .out({w1_230, w0_230}));
wire or0_230 = w0_230 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_230 = w1_230;
wire nx0_231 = or0_206 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_231 = or0_207 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_231, ina1_231;
always @(posedge clk) begin
    ina0_231 <= nx0_231;
    ina1_231 <= or1_206;
end
wire w0_231, w1_231;
MSKand_opini2_d2_pini u_or_231 (
    .ina({ina1_231, ina0_231}), .inb({or1_207, ny0_231}),
    .rnd(r[231]), .s(s[231]), .clk(clk), .out({w1_231, w0_231}));
wire or0_231 = w0_231 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_231 = w1_231;
wire nx0_232 = or0_208 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_232 = or0_209 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_232, ina1_232;
always @(posedge clk) begin
    ina0_232 <= nx0_232;
    ina1_232 <= or1_208;
end
wire w0_232, w1_232;
MSKand_opini2_d2_pini u_or_232 (
    .ina({ina1_232, ina0_232}), .inb({or1_209, ny0_232}),
    .rnd(r[232]), .s(s[232]), .clk(clk), .out({w1_232, w0_232}));
wire or0_232 = w0_232 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_232 = w1_232;
wire nx0_233 = or0_210 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_233 = or0_211 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_233, ina1_233;
always @(posedge clk) begin
    ina0_233 <= nx0_233;
    ina1_233 <= or1_210;
end
wire w0_233, w1_233;
MSKand_opini2_d2_pini u_or_233 (
    .ina({ina1_233, ina0_233}), .inb({or1_211, ny0_233}),
    .rnd(r[233]), .s(s[233]), .clk(clk), .out({w1_233, w0_233}));
wire or0_233 = w0_233 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_233 = w1_233;
wire nx0_234 = or0_212 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_234 = or0_213 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_234, ina1_234;
always @(posedge clk) begin
    ina0_234 <= nx0_234;
    ina1_234 <= or1_212;
end
wire w0_234, w1_234;
MSKand_opini2_d2_pini u_or_234 (
    .ina({ina1_234, ina0_234}), .inb({or1_213, ny0_234}),
    .rnd(r[234]), .s(s[234]), .clk(clk), .out({w1_234, w0_234}));
wire or0_234 = w0_234 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_234 = w1_234;
wire nx0_235 = or0_214 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_235 = or0_215 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_235, ina1_235;
always @(posedge clk) begin
    ina0_235 <= nx0_235;
    ina1_235 <= or1_214;
end
wire w0_235, w1_235;
MSKand_opini2_d2_pini u_or_235 (
    .ina({ina1_235, ina0_235}), .inb({or1_215, ny0_235}),
    .rnd(r[235]), .s(s[235]), .clk(clk), .out({w1_235, w0_235}));
wire or0_235 = w0_235 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_235 = w1_235;
wire nx0_236 = or0_216 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_236 = or0_217 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_236, ina1_236;
always @(posedge clk) begin
    ina0_236 <= nx0_236;
    ina1_236 <= or1_216;
end
wire w0_236, w1_236;
MSKand_opini2_d2_pini u_or_236 (
    .ina({ina1_236, ina0_236}), .inb({or1_217, ny0_236}),
    .rnd(r[236]), .s(s[236]), .clk(clk), .out({w1_236, w0_236}));
wire or0_236 = w0_236 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_236 = w1_236;
wire nx0_237 = or0_218 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_237 = or0_219 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_237, ina1_237;
always @(posedge clk) begin
    ina0_237 <= nx0_237;
    ina1_237 <= or1_218;
end
wire w0_237, w1_237;
MSKand_opini2_d2_pini u_or_237 (
    .ina({ina1_237, ina0_237}), .inb({or1_219, ny0_237}),
    .rnd(r[237]), .s(s[237]), .clk(clk), .out({w1_237, w0_237}));
wire or0_237 = w0_237 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_237 = w1_237;
wire nx0_238 = or0_220 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_238 = or0_221 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_238, ina1_238;
always @(posedge clk) begin
    ina0_238 <= nx0_238;
    ina1_238 <= or1_220;
end
wire w0_238, w1_238;
MSKand_opini2_d2_pini u_or_238 (
    .ina({ina1_238, ina0_238}), .inb({or1_221, ny0_238}),
    .rnd(r[238]), .s(s[238]), .clk(clk), .out({w1_238, w0_238}));
wire or0_238 = w0_238 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_238 = w1_238;
wire nx0_239 = or0_222 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_239 = or0_223 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_239, ina1_239;
always @(posedge clk) begin
    ina0_239 <= nx0_239;
    ina1_239 <= or1_222;
end
wire w0_239, w1_239;
MSKand_opini2_d2_pini u_or_239 (
    .ina({ina1_239, ina0_239}), .inb({or1_223, ny0_239}),
    .rnd(r[239]), .s(s[239]), .clk(clk), .out({w1_239, w0_239}));
wire or0_239 = w0_239 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_239 = w1_239;

// ===== OR-reduce level 4: 16 masked bits -> 8 =====
wire nx0_240 = or0_224 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_240 = or0_225 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_240, ina1_240;
always @(posedge clk) begin
    ina0_240 <= nx0_240;
    ina1_240 <= or1_224;
end
wire w0_240, w1_240;
MSKand_opini2_d2_pini u_or_240 (
    .ina({ina1_240, ina0_240}), .inb({or1_225, ny0_240}),
    .rnd(r[240]), .s(s[240]), .clk(clk), .out({w1_240, w0_240}));
wire or0_240 = w0_240 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_240 = w1_240;
wire nx0_241 = or0_226 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_241 = or0_227 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_241, ina1_241;
always @(posedge clk) begin
    ina0_241 <= nx0_241;
    ina1_241 <= or1_226;
end
wire w0_241, w1_241;
MSKand_opini2_d2_pini u_or_241 (
    .ina({ina1_241, ina0_241}), .inb({or1_227, ny0_241}),
    .rnd(r[241]), .s(s[241]), .clk(clk), .out({w1_241, w0_241}));
wire or0_241 = w0_241 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_241 = w1_241;
wire nx0_242 = or0_228 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_242 = or0_229 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_242, ina1_242;
always @(posedge clk) begin
    ina0_242 <= nx0_242;
    ina1_242 <= or1_228;
end
wire w0_242, w1_242;
MSKand_opini2_d2_pini u_or_242 (
    .ina({ina1_242, ina0_242}), .inb({or1_229, ny0_242}),
    .rnd(r[242]), .s(s[242]), .clk(clk), .out({w1_242, w0_242}));
wire or0_242 = w0_242 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_242 = w1_242;
wire nx0_243 = or0_230 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_243 = or0_231 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_243, ina1_243;
always @(posedge clk) begin
    ina0_243 <= nx0_243;
    ina1_243 <= or1_230;
end
wire w0_243, w1_243;
MSKand_opini2_d2_pini u_or_243 (
    .ina({ina1_243, ina0_243}), .inb({or1_231, ny0_243}),
    .rnd(r[243]), .s(s[243]), .clk(clk), .out({w1_243, w0_243}));
wire or0_243 = w0_243 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_243 = w1_243;
wire nx0_244 = or0_232 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_244 = or0_233 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_244, ina1_244;
always @(posedge clk) begin
    ina0_244 <= nx0_244;
    ina1_244 <= or1_232;
end
wire w0_244, w1_244;
MSKand_opini2_d2_pini u_or_244 (
    .ina({ina1_244, ina0_244}), .inb({or1_233, ny0_244}),
    .rnd(r[244]), .s(s[244]), .clk(clk), .out({w1_244, w0_244}));
wire or0_244 = w0_244 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_244 = w1_244;
wire nx0_245 = or0_234 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_245 = or0_235 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_245, ina1_245;
always @(posedge clk) begin
    ina0_245 <= nx0_245;
    ina1_245 <= or1_234;
end
wire w0_245, w1_245;
MSKand_opini2_d2_pini u_or_245 (
    .ina({ina1_245, ina0_245}), .inb({or1_235, ny0_245}),
    .rnd(r[245]), .s(s[245]), .clk(clk), .out({w1_245, w0_245}));
wire or0_245 = w0_245 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_245 = w1_245;
wire nx0_246 = or0_236 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_246 = or0_237 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_246, ina1_246;
always @(posedge clk) begin
    ina0_246 <= nx0_246;
    ina1_246 <= or1_236;
end
wire w0_246, w1_246;
MSKand_opini2_d2_pini u_or_246 (
    .ina({ina1_246, ina0_246}), .inb({or1_237, ny0_246}),
    .rnd(r[246]), .s(s[246]), .clk(clk), .out({w1_246, w0_246}));
wire or0_246 = w0_246 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_246 = w1_246;
wire nx0_247 = or0_238 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_247 = or0_239 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_247, ina1_247;
always @(posedge clk) begin
    ina0_247 <= nx0_247;
    ina1_247 <= or1_238;
end
wire w0_247, w1_247;
MSKand_opini2_d2_pini u_or_247 (
    .ina({ina1_247, ina0_247}), .inb({or1_239, ny0_247}),
    .rnd(r[247]), .s(s[247]), .clk(clk), .out({w1_247, w0_247}));
wire or0_247 = w0_247 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_247 = w1_247;

// ===== OR-reduce level 5: 8 masked bits -> 4 =====
wire nx0_248 = or0_240 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_248 = or0_241 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_248, ina1_248;
always @(posedge clk) begin
    ina0_248 <= nx0_248;
    ina1_248 <= or1_240;
end
wire w0_248, w1_248;
MSKand_opini2_d2_pini u_or_248 (
    .ina({ina1_248, ina0_248}), .inb({or1_241, ny0_248}),
    .rnd(r[248]), .s(s[248]), .clk(clk), .out({w1_248, w0_248}));
wire or0_248 = w0_248 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_248 = w1_248;
wire nx0_249 = or0_242 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_249 = or0_243 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_249, ina1_249;
always @(posedge clk) begin
    ina0_249 <= nx0_249;
    ina1_249 <= or1_242;
end
wire w0_249, w1_249;
MSKand_opini2_d2_pini u_or_249 (
    .ina({ina1_249, ina0_249}), .inb({or1_243, ny0_249}),
    .rnd(r[249]), .s(s[249]), .clk(clk), .out({w1_249, w0_249}));
wire or0_249 = w0_249 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_249 = w1_249;
wire nx0_250 = or0_244 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_250 = or0_245 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_250, ina1_250;
always @(posedge clk) begin
    ina0_250 <= nx0_250;
    ina1_250 <= or1_244;
end
wire w0_250, w1_250;
MSKand_opini2_d2_pini u_or_250 (
    .ina({ina1_250, ina0_250}), .inb({or1_245, ny0_250}),
    .rnd(r[250]), .s(s[250]), .clk(clk), .out({w1_250, w0_250}));
wire or0_250 = w0_250 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_250 = w1_250;
wire nx0_251 = or0_246 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_251 = or0_247 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_251, ina1_251;
always @(posedge clk) begin
    ina0_251 <= nx0_251;
    ina1_251 <= or1_246;
end
wire w0_251, w1_251;
MSKand_opini2_d2_pini u_or_251 (
    .ina({ina1_251, ina0_251}), .inb({or1_247, ny0_251}),
    .rnd(r[251]), .s(s[251]), .clk(clk), .out({w1_251, w0_251}));
wire or0_251 = w0_251 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_251 = w1_251;

// ===== OR-reduce level 6: 4 masked bits -> 2 =====
wire nx0_252 = or0_248 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_252 = or0_249 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_252, ina1_252;
always @(posedge clk) begin
    ina0_252 <= nx0_252;
    ina1_252 <= or1_248;
end
wire w0_252, w1_252;
MSKand_opini2_d2_pini u_or_252 (
    .ina({ina1_252, ina0_252}), .inb({or1_249, ny0_252}),
    .rnd(r[252]), .s(s[252]), .clk(clk), .out({w1_252, w0_252}));
wire or0_252 = w0_252 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_252 = w1_252;
wire nx0_253 = or0_250 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_253 = or0_251 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_253, ina1_253;
always @(posedge clk) begin
    ina0_253 <= nx0_253;
    ina1_253 <= or1_250;
end
wire w0_253, w1_253;
MSKand_opini2_d2_pini u_or_253 (
    .ina({ina1_253, ina0_253}), .inb({or1_251, ny0_253}),
    .rnd(r[253]), .s(s[253]), .clk(clk), .out({w1_253, w0_253}));
wire or0_253 = w0_253 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_253 = w1_253;

// ===== OR-reduce level 7: 2 masked bits -> 1 =====
wire nx0_254 = or0_252 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_254 = or0_253 ^ 1'b1;   // NOT childB, share-local (share 0)
// 1-cycle balance reg on the ina path (share-local, per-share): presents ina
// one cycle after inb, matching the gadget's ina@1 / inb@0 latency contract.
(* keep = "yes" *) reg ina0_254, ina1_254;
always @(posedge clk) begin
    ina0_254 <= nx0_254;
    ina1_254 <= or1_252;
end
wire w0_254, w1_254;
MSKand_opini2_d2_pini u_or_254 (
    .ina({ina1_254, ina0_254}), .inb({or1_253, ny0_254}),
    .rnd(r[254]), .s(s[254]), .clk(clk), .out({w1_254, w0_254}));
wire or0_254 = w0_254 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_254 = w1_254;

// ---- EQ = ISZERO(A^B) = NOT( OR-reduce(d) ) : share-local complement ----
assign out[0] = or0_254 ^ 1'b1;
assign out[1] = or1_254;

endmodule
