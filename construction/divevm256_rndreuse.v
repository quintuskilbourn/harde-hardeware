// NEGATIVE CONTROL (must FAIL): identical to the target except gating
// gadget u_gq_1 consumes the SAME random bits as u_gq_0, active in the
// same cycles — the bug is in the NEW composition stage, so the control
// exercises exactly what this top adds. MATCHI must report multi-use.
// EVM DIV/MOD (B==0 -> 0): restoring-divider core (770 gadgets, bubble-
// free reuse) + OR-reduce nonzero tree over B (255 gadgets) + broadcast-
// AND output gating (512 gadgets). NG=1537, each with a DEDICATED
// r[k]/s[k] random bit. Every XOR/NOT is strictly share-local.
// Dense sharing layout (share index fastest): port[2i]=share0, port[2i+1]=share1.
// Schedule: load @0; div iterations [1, 135168]; nzr (=B!=0) captured @80;
// qe/rem_e recombine stably from ~135173; state cleared @135184;
// randoms fresh [0,135718].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module divevm256_rndreuse (clk, rst, go, a, b, r, s, qe, reme);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [511:0] a;
(* matchi_type = "sharings_dense", matchi_active = "b_act" *) input [511:0] b;
(* matchi_type = "random", matchi_active = "r_act" *) input [1536:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [1536:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [511:0] qe;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [511:0] reme;

// ---- activity windows from an idempotent cycle counter (public control) ----
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
(* keep *) wire zcap    = (cnt == 19'd80);   // nonzero-tree capture

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

// ---- div-core state registers (per-share; NEVER mix share 0 and share 1) ----
reg [255:0] R0, R1;            // partial remainder
reg [255:0] A0, A1;            // dividend, shifts left (public 0 in)
reg [255:0] Q0, Q1;            // quotient, shifts left (cout in)
reg [255:0] Bn0, Bn1;          // ~B, complement share-local (share 0 only)
reg [255:0] Bz0, Bz1;          // B held for the nonzero tree (per-share)
reg [255:0] Treg0, Treg1;      // registered subtract result (settled)
reg coutr0, coutr1;              // registered carry-out = quotient bit
reg nzr0, nzr1;                  // registered tree root = (B != 0) sharing
wire [256:0] Rsh0 = {R0, A0[255]};   // Rsh = R<<1 | msb(A), per share
wire [256:0] Rsh1 = {R1, A1[255]};
wire [255:0] w_m0, w_m1;       // borrow-mux gadget outputs
wire nz0, nz1;                   // nonzero-tree root wires (pre-capture)
// (* keep *): T/coutw feed only register inputs; without keep, abc absorbs
// their XOR drivers into the register cone and MATCHI hits a driverless wire.
(* keep *) wire [255:0] T0, T1;   // subtract difference bits (settled by M1)
(* keep *) wire coutw0, coutw1;     // subtract carry-out = NOT borrow

always @(posedge clk) begin
    if (rst || clr) begin
        R0 <= 0; R1 <= 0; A0 <= 0; A1 <= 0; Q0 <= 0; Q1 <= 0;
        Bn0 <= 0; Bn1 <= 0; Bz0 <= 0; Bz1 <= 0; Treg0 <= 0; Treg1 <= 0;
        coutr0 <= 0; coutr1 <= 0; nzr0 <= 0; nzr1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        A0 <= {a[510], a[508], a[506], a[504], a[502], a[500], a[498], a[496], a[494], a[492], a[490], a[488], a[486], a[484], a[482], a[480], a[478], a[476], a[474], a[472], a[470], a[468], a[466], a[464], a[462], a[460], a[458], a[456], a[454], a[452], a[450], a[448], a[446], a[444], a[442], a[440], a[438], a[436], a[434], a[432], a[430], a[428], a[426], a[424], a[422], a[420], a[418], a[416], a[414], a[412], a[410], a[408], a[406], a[404], a[402], a[400], a[398], a[396], a[394], a[392], a[390], a[388], a[386], a[384], a[382], a[380], a[378], a[376], a[374], a[372], a[370], a[368], a[366], a[364], a[362], a[360], a[358], a[356], a[354], a[352], a[350], a[348], a[346], a[344], a[342], a[340], a[338], a[336], a[334], a[332], a[330], a[328], a[326], a[324], a[322], a[320], a[318], a[316], a[314], a[312], a[310], a[308], a[306], a[304], a[302], a[300], a[298], a[296], a[294], a[292], a[290], a[288], a[286], a[284], a[282], a[280], a[278], a[276], a[274], a[272], a[270], a[268], a[266], a[264], a[262], a[260], a[258], a[256], a[254], a[252], a[250], a[248], a[246], a[244], a[242], a[240], a[238], a[236], a[234], a[232], a[230], a[228], a[226], a[224], a[222], a[220], a[218], a[216], a[214], a[212], a[210], a[208], a[206], a[204], a[202], a[200], a[198], a[196], a[194], a[192], a[190], a[188], a[186], a[184], a[182], a[180], a[178], a[176], a[174], a[172], a[170], a[168], a[166], a[164], a[162], a[160], a[158], a[156], a[154], a[152], a[150], a[148], a[146], a[144], a[142], a[140], a[138], a[136], a[134], a[132], a[130], a[128], a[126], a[124], a[122], a[120], a[118], a[116], a[114], a[112], a[110], a[108], a[106], a[104], a[102], a[100], a[98], a[96], a[94], a[92], a[90], a[88], a[86], a[84], a[82], a[80], a[78], a[76], a[74], a[72], a[70], a[68], a[66], a[64], a[62], a[60], a[58], a[56], a[54], a[52], a[50], a[48], a[46], a[44], a[42], a[40], a[38], a[36], a[34], a[32], a[30], a[28], a[26], a[24], a[22], a[20], a[18], a[16], a[14], a[12], a[10], a[8], a[6], a[4], a[2], a[0]};
        A1 <= {a[511], a[509], a[507], a[505], a[503], a[501], a[499], a[497], a[495], a[493], a[491], a[489], a[487], a[485], a[483], a[481], a[479], a[477], a[475], a[473], a[471], a[469], a[467], a[465], a[463], a[461], a[459], a[457], a[455], a[453], a[451], a[449], a[447], a[445], a[443], a[441], a[439], a[437], a[435], a[433], a[431], a[429], a[427], a[425], a[423], a[421], a[419], a[417], a[415], a[413], a[411], a[409], a[407], a[405], a[403], a[401], a[399], a[397], a[395], a[393], a[391], a[389], a[387], a[385], a[383], a[381], a[379], a[377], a[375], a[373], a[371], a[369], a[367], a[365], a[363], a[361], a[359], a[357], a[355], a[353], a[351], a[349], a[347], a[345], a[343], a[341], a[339], a[337], a[335], a[333], a[331], a[329], a[327], a[325], a[323], a[321], a[319], a[317], a[315], a[313], a[311], a[309], a[307], a[305], a[303], a[301], a[299], a[297], a[295], a[293], a[291], a[289], a[287], a[285], a[283], a[281], a[279], a[277], a[275], a[273], a[271], a[269], a[267], a[265], a[263], a[261], a[259], a[257], a[255], a[253], a[251], a[249], a[247], a[245], a[243], a[241], a[239], a[237], a[235], a[233], a[231], a[229], a[227], a[225], a[223], a[221], a[219], a[217], a[215], a[213], a[211], a[209], a[207], a[205], a[203], a[201], a[199], a[197], a[195], a[193], a[191], a[189], a[187], a[185], a[183], a[181], a[179], a[177], a[175], a[173], a[171], a[169], a[167], a[165], a[163], a[161], a[159], a[157], a[155], a[153], a[151], a[149], a[147], a[145], a[143], a[141], a[139], a[137], a[135], a[133], a[131], a[129], a[127], a[125], a[123], a[121], a[119], a[117], a[115], a[113], a[111], a[109], a[107], a[105], a[103], a[101], a[99], a[97], a[95], a[93], a[91], a[89], a[87], a[85], a[83], a[81], a[79], a[77], a[75], a[73], a[71], a[69], a[67], a[65], a[63], a[61], a[59], a[57], a[55], a[53], a[51], a[49], a[47], a[45], a[43], a[41], a[39], a[37], a[35], a[33], a[31], a[29], a[27], a[25], a[23], a[21], a[19], a[17], a[15], a[13], a[11], a[9], a[7], a[5], a[3], a[1]};
        Bn0 <= ~{b[510], b[508], b[506], b[504], b[502], b[500], b[498], b[496], b[494], b[492], b[490], b[488], b[486], b[484], b[482], b[480], b[478], b[476], b[474], b[472], b[470], b[468], b[466], b[464], b[462], b[460], b[458], b[456], b[454], b[452], b[450], b[448], b[446], b[444], b[442], b[440], b[438], b[436], b[434], b[432], b[430], b[428], b[426], b[424], b[422], b[420], b[418], b[416], b[414], b[412], b[410], b[408], b[406], b[404], b[402], b[400], b[398], b[396], b[394], b[392], b[390], b[388], b[386], b[384], b[382], b[380], b[378], b[376], b[374], b[372], b[370], b[368], b[366], b[364], b[362], b[360], b[358], b[356], b[354], b[352], b[350], b[348], b[346], b[344], b[342], b[340], b[338], b[336], b[334], b[332], b[330], b[328], b[326], b[324], b[322], b[320], b[318], b[316], b[314], b[312], b[310], b[308], b[306], b[304], b[302], b[300], b[298], b[296], b[294], b[292], b[290], b[288], b[286], b[284], b[282], b[280], b[278], b[276], b[274], b[272], b[270], b[268], b[266], b[264], b[262], b[260], b[258], b[256], b[254], b[252], b[250], b[248], b[246], b[244], b[242], b[240], b[238], b[236], b[234], b[232], b[230], b[228], b[226], b[224], b[222], b[220], b[218], b[216], b[214], b[212], b[210], b[208], b[206], b[204], b[202], b[200], b[198], b[196], b[194], b[192], b[190], b[188], b[186], b[184], b[182], b[180], b[178], b[176], b[174], b[172], b[170], b[168], b[166], b[164], b[162], b[160], b[158], b[156], b[154], b[152], b[150], b[148], b[146], b[144], b[142], b[140], b[138], b[136], b[134], b[132], b[130], b[128], b[126], b[124], b[122], b[120], b[118], b[116], b[114], b[112], b[110], b[108], b[106], b[104], b[102], b[100], b[98], b[96], b[94], b[92], b[90], b[88], b[86], b[84], b[82], b[80], b[78], b[76], b[74], b[72], b[70], b[68], b[66], b[64], b[62], b[60], b[58], b[56], b[54], b[52], b[50], b[48], b[46], b[44], b[42], b[40], b[38], b[36], b[34], b[32], b[30], b[28], b[26], b[24], b[22], b[20], b[18], b[16], b[14], b[12], b[10], b[8], b[6], b[4], b[2], b[0]};   // share-local NOT: complement share 0
        Bn1 <= {b[511], b[509], b[507], b[505], b[503], b[501], b[499], b[497], b[495], b[493], b[491], b[489], b[487], b[485], b[483], b[481], b[479], b[477], b[475], b[473], b[471], b[469], b[467], b[465], b[463], b[461], b[459], b[457], b[455], b[453], b[451], b[449], b[447], b[445], b[443], b[441], b[439], b[437], b[435], b[433], b[431], b[429], b[427], b[425], b[423], b[421], b[419], b[417], b[415], b[413], b[411], b[409], b[407], b[405], b[403], b[401], b[399], b[397], b[395], b[393], b[391], b[389], b[387], b[385], b[383], b[381], b[379], b[377], b[375], b[373], b[371], b[369], b[367], b[365], b[363], b[361], b[359], b[357], b[355], b[353], b[351], b[349], b[347], b[345], b[343], b[341], b[339], b[337], b[335], b[333], b[331], b[329], b[327], b[325], b[323], b[321], b[319], b[317], b[315], b[313], b[311], b[309], b[307], b[305], b[303], b[301], b[299], b[297], b[295], b[293], b[291], b[289], b[287], b[285], b[283], b[281], b[279], b[277], b[275], b[273], b[271], b[269], b[267], b[265], b[263], b[261], b[259], b[257], b[255], b[253], b[251], b[249], b[247], b[245], b[243], b[241], b[239], b[237], b[235], b[233], b[231], b[229], b[227], b[225], b[223], b[221], b[219], b[217], b[215], b[213], b[211], b[209], b[207], b[205], b[203], b[201], b[199], b[197], b[195], b[193], b[191], b[189], b[187], b[185], b[183], b[181], b[179], b[177], b[175], b[173], b[171], b[169], b[167], b[165], b[163], b[161], b[159], b[157], b[155], b[153], b[151], b[149], b[147], b[145], b[143], b[141], b[139], b[137], b[135], b[133], b[131], b[129], b[127], b[125], b[123], b[121], b[119], b[117], b[115], b[113], b[111], b[109], b[107], b[105], b[103], b[101], b[99], b[97], b[95], b[93], b[91], b[89], b[87], b[85], b[83], b[81], b[79], b[77], b[75], b[73], b[71], b[69], b[67], b[65], b[63], b[61], b[59], b[57], b[55], b[53], b[51], b[49], b[47], b[45], b[43], b[41], b[39], b[37], b[35], b[33], b[31], b[29], b[27], b[25], b[23], b[21], b[19], b[17], b[15], b[13], b[11], b[9], b[7], b[5], b[3], b[1]};    // share 1 untouched
        Bz0 <= {b[510], b[508], b[506], b[504], b[502], b[500], b[498], b[496], b[494], b[492], b[490], b[488], b[486], b[484], b[482], b[480], b[478], b[476], b[474], b[472], b[470], b[468], b[466], b[464], b[462], b[460], b[458], b[456], b[454], b[452], b[450], b[448], b[446], b[444], b[442], b[440], b[438], b[436], b[434], b[432], b[430], b[428], b[426], b[424], b[422], b[420], b[418], b[416], b[414], b[412], b[410], b[408], b[406], b[404], b[402], b[400], b[398], b[396], b[394], b[392], b[390], b[388], b[386], b[384], b[382], b[380], b[378], b[376], b[374], b[372], b[370], b[368], b[366], b[364], b[362], b[360], b[358], b[356], b[354], b[352], b[350], b[348], b[346], b[344], b[342], b[340], b[338], b[336], b[334], b[332], b[330], b[328], b[326], b[324], b[322], b[320], b[318], b[316], b[314], b[312], b[310], b[308], b[306], b[304], b[302], b[300], b[298], b[296], b[294], b[292], b[290], b[288], b[286], b[284], b[282], b[280], b[278], b[276], b[274], b[272], b[270], b[268], b[266], b[264], b[262], b[260], b[258], b[256], b[254], b[252], b[250], b[248], b[246], b[244], b[242], b[240], b[238], b[236], b[234], b[232], b[230], b[228], b[226], b[224], b[222], b[220], b[218], b[216], b[214], b[212], b[210], b[208], b[206], b[204], b[202], b[200], b[198], b[196], b[194], b[192], b[190], b[188], b[186], b[184], b[182], b[180], b[178], b[176], b[174], b[172], b[170], b[168], b[166], b[164], b[162], b[160], b[158], b[156], b[154], b[152], b[150], b[148], b[146], b[144], b[142], b[140], b[138], b[136], b[134], b[132], b[130], b[128], b[126], b[124], b[122], b[120], b[118], b[116], b[114], b[112], b[110], b[108], b[106], b[104], b[102], b[100], b[98], b[96], b[94], b[92], b[90], b[88], b[86], b[84], b[82], b[80], b[78], b[76], b[74], b[72], b[70], b[68], b[66], b[64], b[62], b[60], b[58], b[56], b[54], b[52], b[50], b[48], b[46], b[44], b[42], b[40], b[38], b[36], b[34], b[32], b[30], b[28], b[26], b[24], b[22], b[20], b[18], b[16], b[14], b[12], b[10], b[8], b[6], b[4], b[2], b[0]};    // uncomplemented copy for the tree
        Bz1 <= {b[511], b[509], b[507], b[505], b[503], b[501], b[499], b[497], b[495], b[493], b[491], b[489], b[487], b[485], b[483], b[481], b[479], b[477], b[475], b[473], b[471], b[469], b[467], b[465], b[463], b[461], b[459], b[457], b[455], b[453], b[451], b[449], b[447], b[445], b[443], b[441], b[439], b[437], b[435], b[433], b[431], b[429], b[427], b[425], b[423], b[421], b[419], b[417], b[415], b[413], b[411], b[409], b[407], b[405], b[403], b[401], b[399], b[397], b[395], b[393], b[391], b[389], b[387], b[385], b[383], b[381], b[379], b[377], b[375], b[373], b[371], b[369], b[367], b[365], b[363], b[361], b[359], b[357], b[355], b[353], b[351], b[349], b[347], b[345], b[343], b[341], b[339], b[337], b[335], b[333], b[331], b[329], b[327], b[325], b[323], b[321], b[319], b[317], b[315], b[313], b[311], b[309], b[307], b[305], b[303], b[301], b[299], b[297], b[295], b[293], b[291], b[289], b[287], b[285], b[283], b[281], b[279], b[277], b[275], b[273], b[271], b[269], b[267], b[265], b[263], b[261], b[259], b[257], b[255], b[253], b[251], b[249], b[247], b[245], b[243], b[241], b[239], b[237], b[235], b[233], b[231], b[229], b[227], b[225], b[223], b[221], b[219], b[217], b[215], b[213], b[211], b[209], b[207], b[205], b[203], b[201], b[199], b[197], b[195], b[193], b[191], b[189], b[187], b[185], b[183], b[181], b[179], b[177], b[175], b[173], b[171], b[169], b[167], b[165], b[163], b[161], b[159], b[157], b[155], b[153], b[151], b[149], b[147], b[145], b[143], b[141], b[139], b[137], b[135], b[133], b[131], b[129], b[127], b[125], b[123], b[121], b[119], b[117], b[115], b[113], b[111], b[109], b[107], b[105], b[103], b[101], b[99], b[97], b[95], b[93], b[91], b[89], b[87], b[85], b[83], b[81], b[79], b[77], b[75], b[73], b[71], b[69], b[67], b[65], b[63], b[61], b[59], b[57], b[55], b[53], b[51], b[49], b[47], b[45], b[43], b[41], b[39], b[37], b[35], b[33], b[31], b[29], b[27], b[25], b[23], b[21], b[19], b[17], b[15], b[13], b[11], b[9], b[7], b[5], b[3], b[1]};
        R0 <= 0; R1 <= 0; Q0 <= 0; Q1 <= 0;
        Treg0 <= 0; Treg1 <= 0; coutr0 <= 0; coutr1 <= 0;
        nzr0 <= 0; nzr1 <= 0;
    end else begin
        if (running) begin
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
        if (zcap) begin               // consistent share pair of (B != 0)
            nzr0 <= nz0; nzr1 <= nz1;
        end
    end
end

// ---- 1-cycle per-share balance registers: every gadget ina arrives one
// cycle after its inb (gadget contract ina@1/inb@0 — the iszero256 pattern).
// Unconditional, so they drain by themselves one cycle after clr.
reg [256:0] Rsh_d0, Rsh_d1;      // ina of u_g_*  (inb = Bn)
reg [255:0] xm_d0, xm_d1;      // ina of u_m_*  (inb = coutr); xm = Rsh^Treg
reg [255:0] q_d0, q_d1;        // ina of u_gq_* (inb = nzr broadcast)
reg [255:0] rm_d0, rm_d1;      // ina of u_gr_* (inb = nzr broadcast)
always @(posedge clk) begin
    Rsh_d0 <= Rsh0;                       Rsh_d1 <= Rsh1;
    xm_d0  <= Rsh0[255:0] ^ Treg0;      xm_d1  <= Rsh1[255:0] ^ Treg1;
    q_d0   <= Q0;                         q_d1   <= Q1;
    rm_d0  <= R0;                         rm_d1  <= R1;
end


// ===== (N+1)-bit ripple subtract: T = Rsh + ~B + 1 (verified-adder dataflow, sub=1) =====
// fc[0] = carry-in = public 1 (share pair (1,0)); Bn bit 256 = ~0 = public 1.
wire [256:0] fc0, fc1;
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
wire p0_16 = Rsh_d0[16] ^ Bn0[16];
wire p1_16 = Rsh_d1[16] ^ Bn1[16];
wire g0_16, g1_16, t0_16, t1_16;
MSKand_opini2_d2 u_g_16 (
    .ina({Rsh_d1[16], Rsh_d0[16]}), .inb({Bn1[16], Bn0[16]}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({g1_16, g0_16}));
MSKand_opini2_d2 u_t_16 (
    .ina({fc1[16], fc0[16]}), .inb({p1_16, p0_16}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({t1_16, t0_16}));
assign fc0[17] = g0_16 ^ t0_16;
assign fc1[17] = g1_16 ^ t1_16;
wire p0_17 = Rsh_d0[17] ^ Bn0[17];
wire p1_17 = Rsh_d1[17] ^ Bn1[17];
wire g0_17, g1_17, t0_17, t1_17;
MSKand_opini2_d2 u_g_17 (
    .ina({Rsh_d1[17], Rsh_d0[17]}), .inb({Bn1[17], Bn0[17]}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({g1_17, g0_17}));
MSKand_opini2_d2 u_t_17 (
    .ina({fc1[17], fc0[17]}), .inb({p1_17, p0_17}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({t1_17, t0_17}));
assign fc0[18] = g0_17 ^ t0_17;
assign fc1[18] = g1_17 ^ t1_17;
wire p0_18 = Rsh_d0[18] ^ Bn0[18];
wire p1_18 = Rsh_d1[18] ^ Bn1[18];
wire g0_18, g1_18, t0_18, t1_18;
MSKand_opini2_d2 u_g_18 (
    .ina({Rsh_d1[18], Rsh_d0[18]}), .inb({Bn1[18], Bn0[18]}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({g1_18, g0_18}));
MSKand_opini2_d2 u_t_18 (
    .ina({fc1[18], fc0[18]}), .inb({p1_18, p0_18}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({t1_18, t0_18}));
assign fc0[19] = g0_18 ^ t0_18;
assign fc1[19] = g1_18 ^ t1_18;
wire p0_19 = Rsh_d0[19] ^ Bn0[19];
wire p1_19 = Rsh_d1[19] ^ Bn1[19];
wire g0_19, g1_19, t0_19, t1_19;
MSKand_opini2_d2 u_g_19 (
    .ina({Rsh_d1[19], Rsh_d0[19]}), .inb({Bn1[19], Bn0[19]}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({g1_19, g0_19}));
MSKand_opini2_d2 u_t_19 (
    .ina({fc1[19], fc0[19]}), .inb({p1_19, p0_19}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({t1_19, t0_19}));
assign fc0[20] = g0_19 ^ t0_19;
assign fc1[20] = g1_19 ^ t1_19;
wire p0_20 = Rsh_d0[20] ^ Bn0[20];
wire p1_20 = Rsh_d1[20] ^ Bn1[20];
wire g0_20, g1_20, t0_20, t1_20;
MSKand_opini2_d2 u_g_20 (
    .ina({Rsh_d1[20], Rsh_d0[20]}), .inb({Bn1[20], Bn0[20]}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({g1_20, g0_20}));
MSKand_opini2_d2 u_t_20 (
    .ina({fc1[20], fc0[20]}), .inb({p1_20, p0_20}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({t1_20, t0_20}));
assign fc0[21] = g0_20 ^ t0_20;
assign fc1[21] = g1_20 ^ t1_20;
wire p0_21 = Rsh_d0[21] ^ Bn0[21];
wire p1_21 = Rsh_d1[21] ^ Bn1[21];
wire g0_21, g1_21, t0_21, t1_21;
MSKand_opini2_d2 u_g_21 (
    .ina({Rsh_d1[21], Rsh_d0[21]}), .inb({Bn1[21], Bn0[21]}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({g1_21, g0_21}));
MSKand_opini2_d2 u_t_21 (
    .ina({fc1[21], fc0[21]}), .inb({p1_21, p0_21}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({t1_21, t0_21}));
assign fc0[22] = g0_21 ^ t0_21;
assign fc1[22] = g1_21 ^ t1_21;
wire p0_22 = Rsh_d0[22] ^ Bn0[22];
wire p1_22 = Rsh_d1[22] ^ Bn1[22];
wire g0_22, g1_22, t0_22, t1_22;
MSKand_opini2_d2 u_g_22 (
    .ina({Rsh_d1[22], Rsh_d0[22]}), .inb({Bn1[22], Bn0[22]}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({g1_22, g0_22}));
MSKand_opini2_d2 u_t_22 (
    .ina({fc1[22], fc0[22]}), .inb({p1_22, p0_22}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({t1_22, t0_22}));
assign fc0[23] = g0_22 ^ t0_22;
assign fc1[23] = g1_22 ^ t1_22;
wire p0_23 = Rsh_d0[23] ^ Bn0[23];
wire p1_23 = Rsh_d1[23] ^ Bn1[23];
wire g0_23, g1_23, t0_23, t1_23;
MSKand_opini2_d2 u_g_23 (
    .ina({Rsh_d1[23], Rsh_d0[23]}), .inb({Bn1[23], Bn0[23]}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({g1_23, g0_23}));
MSKand_opini2_d2 u_t_23 (
    .ina({fc1[23], fc0[23]}), .inb({p1_23, p0_23}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({t1_23, t0_23}));
assign fc0[24] = g0_23 ^ t0_23;
assign fc1[24] = g1_23 ^ t1_23;
wire p0_24 = Rsh_d0[24] ^ Bn0[24];
wire p1_24 = Rsh_d1[24] ^ Bn1[24];
wire g0_24, g1_24, t0_24, t1_24;
MSKand_opini2_d2 u_g_24 (
    .ina({Rsh_d1[24], Rsh_d0[24]}), .inb({Bn1[24], Bn0[24]}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({g1_24, g0_24}));
MSKand_opini2_d2 u_t_24 (
    .ina({fc1[24], fc0[24]}), .inb({p1_24, p0_24}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({t1_24, t0_24}));
assign fc0[25] = g0_24 ^ t0_24;
assign fc1[25] = g1_24 ^ t1_24;
wire p0_25 = Rsh_d0[25] ^ Bn0[25];
wire p1_25 = Rsh_d1[25] ^ Bn1[25];
wire g0_25, g1_25, t0_25, t1_25;
MSKand_opini2_d2 u_g_25 (
    .ina({Rsh_d1[25], Rsh_d0[25]}), .inb({Bn1[25], Bn0[25]}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({g1_25, g0_25}));
MSKand_opini2_d2 u_t_25 (
    .ina({fc1[25], fc0[25]}), .inb({p1_25, p0_25}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({t1_25, t0_25}));
assign fc0[26] = g0_25 ^ t0_25;
assign fc1[26] = g1_25 ^ t1_25;
wire p0_26 = Rsh_d0[26] ^ Bn0[26];
wire p1_26 = Rsh_d1[26] ^ Bn1[26];
wire g0_26, g1_26, t0_26, t1_26;
MSKand_opini2_d2 u_g_26 (
    .ina({Rsh_d1[26], Rsh_d0[26]}), .inb({Bn1[26], Bn0[26]}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({g1_26, g0_26}));
MSKand_opini2_d2 u_t_26 (
    .ina({fc1[26], fc0[26]}), .inb({p1_26, p0_26}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({t1_26, t0_26}));
assign fc0[27] = g0_26 ^ t0_26;
assign fc1[27] = g1_26 ^ t1_26;
wire p0_27 = Rsh_d0[27] ^ Bn0[27];
wire p1_27 = Rsh_d1[27] ^ Bn1[27];
wire g0_27, g1_27, t0_27, t1_27;
MSKand_opini2_d2 u_g_27 (
    .ina({Rsh_d1[27], Rsh_d0[27]}), .inb({Bn1[27], Bn0[27]}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({g1_27, g0_27}));
MSKand_opini2_d2 u_t_27 (
    .ina({fc1[27], fc0[27]}), .inb({p1_27, p0_27}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({t1_27, t0_27}));
assign fc0[28] = g0_27 ^ t0_27;
assign fc1[28] = g1_27 ^ t1_27;
wire p0_28 = Rsh_d0[28] ^ Bn0[28];
wire p1_28 = Rsh_d1[28] ^ Bn1[28];
wire g0_28, g1_28, t0_28, t1_28;
MSKand_opini2_d2 u_g_28 (
    .ina({Rsh_d1[28], Rsh_d0[28]}), .inb({Bn1[28], Bn0[28]}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({g1_28, g0_28}));
MSKand_opini2_d2 u_t_28 (
    .ina({fc1[28], fc0[28]}), .inb({p1_28, p0_28}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({t1_28, t0_28}));
assign fc0[29] = g0_28 ^ t0_28;
assign fc1[29] = g1_28 ^ t1_28;
wire p0_29 = Rsh_d0[29] ^ Bn0[29];
wire p1_29 = Rsh_d1[29] ^ Bn1[29];
wire g0_29, g1_29, t0_29, t1_29;
MSKand_opini2_d2 u_g_29 (
    .ina({Rsh_d1[29], Rsh_d0[29]}), .inb({Bn1[29], Bn0[29]}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({g1_29, g0_29}));
MSKand_opini2_d2 u_t_29 (
    .ina({fc1[29], fc0[29]}), .inb({p1_29, p0_29}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({t1_29, t0_29}));
assign fc0[30] = g0_29 ^ t0_29;
assign fc1[30] = g1_29 ^ t1_29;
wire p0_30 = Rsh_d0[30] ^ Bn0[30];
wire p1_30 = Rsh_d1[30] ^ Bn1[30];
wire g0_30, g1_30, t0_30, t1_30;
MSKand_opini2_d2 u_g_30 (
    .ina({Rsh_d1[30], Rsh_d0[30]}), .inb({Bn1[30], Bn0[30]}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({g1_30, g0_30}));
MSKand_opini2_d2 u_t_30 (
    .ina({fc1[30], fc0[30]}), .inb({p1_30, p0_30}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({t1_30, t0_30}));
assign fc0[31] = g0_30 ^ t0_30;
assign fc1[31] = g1_30 ^ t1_30;
wire p0_31 = Rsh_d0[31] ^ Bn0[31];
wire p1_31 = Rsh_d1[31] ^ Bn1[31];
wire g0_31, g1_31, t0_31, t1_31;
MSKand_opini2_d2 u_g_31 (
    .ina({Rsh_d1[31], Rsh_d0[31]}), .inb({Bn1[31], Bn0[31]}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({g1_31, g0_31}));
MSKand_opini2_d2 u_t_31 (
    .ina({fc1[31], fc0[31]}), .inb({p1_31, p0_31}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({t1_31, t0_31}));
assign fc0[32] = g0_31 ^ t0_31;
assign fc1[32] = g1_31 ^ t1_31;
wire p0_32 = Rsh_d0[32] ^ Bn0[32];
wire p1_32 = Rsh_d1[32] ^ Bn1[32];
wire g0_32, g1_32, t0_32, t1_32;
MSKand_opini2_d2 u_g_32 (
    .ina({Rsh_d1[32], Rsh_d0[32]}), .inb({Bn1[32], Bn0[32]}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({g1_32, g0_32}));
MSKand_opini2_d2 u_t_32 (
    .ina({fc1[32], fc0[32]}), .inb({p1_32, p0_32}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({t1_32, t0_32}));
assign fc0[33] = g0_32 ^ t0_32;
assign fc1[33] = g1_32 ^ t1_32;
wire p0_33 = Rsh_d0[33] ^ Bn0[33];
wire p1_33 = Rsh_d1[33] ^ Bn1[33];
wire g0_33, g1_33, t0_33, t1_33;
MSKand_opini2_d2 u_g_33 (
    .ina({Rsh_d1[33], Rsh_d0[33]}), .inb({Bn1[33], Bn0[33]}),
    .rnd(r[66]), .s(s[66]), .clk(clk), .out({g1_33, g0_33}));
MSKand_opini2_d2 u_t_33 (
    .ina({fc1[33], fc0[33]}), .inb({p1_33, p0_33}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({t1_33, t0_33}));
assign fc0[34] = g0_33 ^ t0_33;
assign fc1[34] = g1_33 ^ t1_33;
wire p0_34 = Rsh_d0[34] ^ Bn0[34];
wire p1_34 = Rsh_d1[34] ^ Bn1[34];
wire g0_34, g1_34, t0_34, t1_34;
MSKand_opini2_d2 u_g_34 (
    .ina({Rsh_d1[34], Rsh_d0[34]}), .inb({Bn1[34], Bn0[34]}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({g1_34, g0_34}));
MSKand_opini2_d2 u_t_34 (
    .ina({fc1[34], fc0[34]}), .inb({p1_34, p0_34}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({t1_34, t0_34}));
assign fc0[35] = g0_34 ^ t0_34;
assign fc1[35] = g1_34 ^ t1_34;
wire p0_35 = Rsh_d0[35] ^ Bn0[35];
wire p1_35 = Rsh_d1[35] ^ Bn1[35];
wire g0_35, g1_35, t0_35, t1_35;
MSKand_opini2_d2 u_g_35 (
    .ina({Rsh_d1[35], Rsh_d0[35]}), .inb({Bn1[35], Bn0[35]}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({g1_35, g0_35}));
MSKand_opini2_d2 u_t_35 (
    .ina({fc1[35], fc0[35]}), .inb({p1_35, p0_35}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({t1_35, t0_35}));
assign fc0[36] = g0_35 ^ t0_35;
assign fc1[36] = g1_35 ^ t1_35;
wire p0_36 = Rsh_d0[36] ^ Bn0[36];
wire p1_36 = Rsh_d1[36] ^ Bn1[36];
wire g0_36, g1_36, t0_36, t1_36;
MSKand_opini2_d2 u_g_36 (
    .ina({Rsh_d1[36], Rsh_d0[36]}), .inb({Bn1[36], Bn0[36]}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({g1_36, g0_36}));
MSKand_opini2_d2 u_t_36 (
    .ina({fc1[36], fc0[36]}), .inb({p1_36, p0_36}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({t1_36, t0_36}));
assign fc0[37] = g0_36 ^ t0_36;
assign fc1[37] = g1_36 ^ t1_36;
wire p0_37 = Rsh_d0[37] ^ Bn0[37];
wire p1_37 = Rsh_d1[37] ^ Bn1[37];
wire g0_37, g1_37, t0_37, t1_37;
MSKand_opini2_d2 u_g_37 (
    .ina({Rsh_d1[37], Rsh_d0[37]}), .inb({Bn1[37], Bn0[37]}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({g1_37, g0_37}));
MSKand_opini2_d2 u_t_37 (
    .ina({fc1[37], fc0[37]}), .inb({p1_37, p0_37}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({t1_37, t0_37}));
assign fc0[38] = g0_37 ^ t0_37;
assign fc1[38] = g1_37 ^ t1_37;
wire p0_38 = Rsh_d0[38] ^ Bn0[38];
wire p1_38 = Rsh_d1[38] ^ Bn1[38];
wire g0_38, g1_38, t0_38, t1_38;
MSKand_opini2_d2 u_g_38 (
    .ina({Rsh_d1[38], Rsh_d0[38]}), .inb({Bn1[38], Bn0[38]}),
    .rnd(r[76]), .s(s[76]), .clk(clk), .out({g1_38, g0_38}));
MSKand_opini2_d2 u_t_38 (
    .ina({fc1[38], fc0[38]}), .inb({p1_38, p0_38}),
    .rnd(r[77]), .s(s[77]), .clk(clk), .out({t1_38, t0_38}));
assign fc0[39] = g0_38 ^ t0_38;
assign fc1[39] = g1_38 ^ t1_38;
wire p0_39 = Rsh_d0[39] ^ Bn0[39];
wire p1_39 = Rsh_d1[39] ^ Bn1[39];
wire g0_39, g1_39, t0_39, t1_39;
MSKand_opini2_d2 u_g_39 (
    .ina({Rsh_d1[39], Rsh_d0[39]}), .inb({Bn1[39], Bn0[39]}),
    .rnd(r[78]), .s(s[78]), .clk(clk), .out({g1_39, g0_39}));
MSKand_opini2_d2 u_t_39 (
    .ina({fc1[39], fc0[39]}), .inb({p1_39, p0_39}),
    .rnd(r[79]), .s(s[79]), .clk(clk), .out({t1_39, t0_39}));
assign fc0[40] = g0_39 ^ t0_39;
assign fc1[40] = g1_39 ^ t1_39;
wire p0_40 = Rsh_d0[40] ^ Bn0[40];
wire p1_40 = Rsh_d1[40] ^ Bn1[40];
wire g0_40, g1_40, t0_40, t1_40;
MSKand_opini2_d2 u_g_40 (
    .ina({Rsh_d1[40], Rsh_d0[40]}), .inb({Bn1[40], Bn0[40]}),
    .rnd(r[80]), .s(s[80]), .clk(clk), .out({g1_40, g0_40}));
MSKand_opini2_d2 u_t_40 (
    .ina({fc1[40], fc0[40]}), .inb({p1_40, p0_40}),
    .rnd(r[81]), .s(s[81]), .clk(clk), .out({t1_40, t0_40}));
assign fc0[41] = g0_40 ^ t0_40;
assign fc1[41] = g1_40 ^ t1_40;
wire p0_41 = Rsh_d0[41] ^ Bn0[41];
wire p1_41 = Rsh_d1[41] ^ Bn1[41];
wire g0_41, g1_41, t0_41, t1_41;
MSKand_opini2_d2 u_g_41 (
    .ina({Rsh_d1[41], Rsh_d0[41]}), .inb({Bn1[41], Bn0[41]}),
    .rnd(r[82]), .s(s[82]), .clk(clk), .out({g1_41, g0_41}));
MSKand_opini2_d2 u_t_41 (
    .ina({fc1[41], fc0[41]}), .inb({p1_41, p0_41}),
    .rnd(r[83]), .s(s[83]), .clk(clk), .out({t1_41, t0_41}));
assign fc0[42] = g0_41 ^ t0_41;
assign fc1[42] = g1_41 ^ t1_41;
wire p0_42 = Rsh_d0[42] ^ Bn0[42];
wire p1_42 = Rsh_d1[42] ^ Bn1[42];
wire g0_42, g1_42, t0_42, t1_42;
MSKand_opini2_d2 u_g_42 (
    .ina({Rsh_d1[42], Rsh_d0[42]}), .inb({Bn1[42], Bn0[42]}),
    .rnd(r[84]), .s(s[84]), .clk(clk), .out({g1_42, g0_42}));
MSKand_opini2_d2 u_t_42 (
    .ina({fc1[42], fc0[42]}), .inb({p1_42, p0_42}),
    .rnd(r[85]), .s(s[85]), .clk(clk), .out({t1_42, t0_42}));
assign fc0[43] = g0_42 ^ t0_42;
assign fc1[43] = g1_42 ^ t1_42;
wire p0_43 = Rsh_d0[43] ^ Bn0[43];
wire p1_43 = Rsh_d1[43] ^ Bn1[43];
wire g0_43, g1_43, t0_43, t1_43;
MSKand_opini2_d2 u_g_43 (
    .ina({Rsh_d1[43], Rsh_d0[43]}), .inb({Bn1[43], Bn0[43]}),
    .rnd(r[86]), .s(s[86]), .clk(clk), .out({g1_43, g0_43}));
MSKand_opini2_d2 u_t_43 (
    .ina({fc1[43], fc0[43]}), .inb({p1_43, p0_43}),
    .rnd(r[87]), .s(s[87]), .clk(clk), .out({t1_43, t0_43}));
assign fc0[44] = g0_43 ^ t0_43;
assign fc1[44] = g1_43 ^ t1_43;
wire p0_44 = Rsh_d0[44] ^ Bn0[44];
wire p1_44 = Rsh_d1[44] ^ Bn1[44];
wire g0_44, g1_44, t0_44, t1_44;
MSKand_opini2_d2 u_g_44 (
    .ina({Rsh_d1[44], Rsh_d0[44]}), .inb({Bn1[44], Bn0[44]}),
    .rnd(r[88]), .s(s[88]), .clk(clk), .out({g1_44, g0_44}));
MSKand_opini2_d2 u_t_44 (
    .ina({fc1[44], fc0[44]}), .inb({p1_44, p0_44}),
    .rnd(r[89]), .s(s[89]), .clk(clk), .out({t1_44, t0_44}));
assign fc0[45] = g0_44 ^ t0_44;
assign fc1[45] = g1_44 ^ t1_44;
wire p0_45 = Rsh_d0[45] ^ Bn0[45];
wire p1_45 = Rsh_d1[45] ^ Bn1[45];
wire g0_45, g1_45, t0_45, t1_45;
MSKand_opini2_d2 u_g_45 (
    .ina({Rsh_d1[45], Rsh_d0[45]}), .inb({Bn1[45], Bn0[45]}),
    .rnd(r[90]), .s(s[90]), .clk(clk), .out({g1_45, g0_45}));
MSKand_opini2_d2 u_t_45 (
    .ina({fc1[45], fc0[45]}), .inb({p1_45, p0_45}),
    .rnd(r[91]), .s(s[91]), .clk(clk), .out({t1_45, t0_45}));
assign fc0[46] = g0_45 ^ t0_45;
assign fc1[46] = g1_45 ^ t1_45;
wire p0_46 = Rsh_d0[46] ^ Bn0[46];
wire p1_46 = Rsh_d1[46] ^ Bn1[46];
wire g0_46, g1_46, t0_46, t1_46;
MSKand_opini2_d2 u_g_46 (
    .ina({Rsh_d1[46], Rsh_d0[46]}), .inb({Bn1[46], Bn0[46]}),
    .rnd(r[92]), .s(s[92]), .clk(clk), .out({g1_46, g0_46}));
MSKand_opini2_d2 u_t_46 (
    .ina({fc1[46], fc0[46]}), .inb({p1_46, p0_46}),
    .rnd(r[93]), .s(s[93]), .clk(clk), .out({t1_46, t0_46}));
assign fc0[47] = g0_46 ^ t0_46;
assign fc1[47] = g1_46 ^ t1_46;
wire p0_47 = Rsh_d0[47] ^ Bn0[47];
wire p1_47 = Rsh_d1[47] ^ Bn1[47];
wire g0_47, g1_47, t0_47, t1_47;
MSKand_opini2_d2 u_g_47 (
    .ina({Rsh_d1[47], Rsh_d0[47]}), .inb({Bn1[47], Bn0[47]}),
    .rnd(r[94]), .s(s[94]), .clk(clk), .out({g1_47, g0_47}));
MSKand_opini2_d2 u_t_47 (
    .ina({fc1[47], fc0[47]}), .inb({p1_47, p0_47}),
    .rnd(r[95]), .s(s[95]), .clk(clk), .out({t1_47, t0_47}));
assign fc0[48] = g0_47 ^ t0_47;
assign fc1[48] = g1_47 ^ t1_47;
wire p0_48 = Rsh_d0[48] ^ Bn0[48];
wire p1_48 = Rsh_d1[48] ^ Bn1[48];
wire g0_48, g1_48, t0_48, t1_48;
MSKand_opini2_d2 u_g_48 (
    .ina({Rsh_d1[48], Rsh_d0[48]}), .inb({Bn1[48], Bn0[48]}),
    .rnd(r[96]), .s(s[96]), .clk(clk), .out({g1_48, g0_48}));
MSKand_opini2_d2 u_t_48 (
    .ina({fc1[48], fc0[48]}), .inb({p1_48, p0_48}),
    .rnd(r[97]), .s(s[97]), .clk(clk), .out({t1_48, t0_48}));
assign fc0[49] = g0_48 ^ t0_48;
assign fc1[49] = g1_48 ^ t1_48;
wire p0_49 = Rsh_d0[49] ^ Bn0[49];
wire p1_49 = Rsh_d1[49] ^ Bn1[49];
wire g0_49, g1_49, t0_49, t1_49;
MSKand_opini2_d2 u_g_49 (
    .ina({Rsh_d1[49], Rsh_d0[49]}), .inb({Bn1[49], Bn0[49]}),
    .rnd(r[98]), .s(s[98]), .clk(clk), .out({g1_49, g0_49}));
MSKand_opini2_d2 u_t_49 (
    .ina({fc1[49], fc0[49]}), .inb({p1_49, p0_49}),
    .rnd(r[99]), .s(s[99]), .clk(clk), .out({t1_49, t0_49}));
assign fc0[50] = g0_49 ^ t0_49;
assign fc1[50] = g1_49 ^ t1_49;
wire p0_50 = Rsh_d0[50] ^ Bn0[50];
wire p1_50 = Rsh_d1[50] ^ Bn1[50];
wire g0_50, g1_50, t0_50, t1_50;
MSKand_opini2_d2 u_g_50 (
    .ina({Rsh_d1[50], Rsh_d0[50]}), .inb({Bn1[50], Bn0[50]}),
    .rnd(r[100]), .s(s[100]), .clk(clk), .out({g1_50, g0_50}));
MSKand_opini2_d2 u_t_50 (
    .ina({fc1[50], fc0[50]}), .inb({p1_50, p0_50}),
    .rnd(r[101]), .s(s[101]), .clk(clk), .out({t1_50, t0_50}));
assign fc0[51] = g0_50 ^ t0_50;
assign fc1[51] = g1_50 ^ t1_50;
wire p0_51 = Rsh_d0[51] ^ Bn0[51];
wire p1_51 = Rsh_d1[51] ^ Bn1[51];
wire g0_51, g1_51, t0_51, t1_51;
MSKand_opini2_d2 u_g_51 (
    .ina({Rsh_d1[51], Rsh_d0[51]}), .inb({Bn1[51], Bn0[51]}),
    .rnd(r[102]), .s(s[102]), .clk(clk), .out({g1_51, g0_51}));
MSKand_opini2_d2 u_t_51 (
    .ina({fc1[51], fc0[51]}), .inb({p1_51, p0_51}),
    .rnd(r[103]), .s(s[103]), .clk(clk), .out({t1_51, t0_51}));
assign fc0[52] = g0_51 ^ t0_51;
assign fc1[52] = g1_51 ^ t1_51;
wire p0_52 = Rsh_d0[52] ^ Bn0[52];
wire p1_52 = Rsh_d1[52] ^ Bn1[52];
wire g0_52, g1_52, t0_52, t1_52;
MSKand_opini2_d2 u_g_52 (
    .ina({Rsh_d1[52], Rsh_d0[52]}), .inb({Bn1[52], Bn0[52]}),
    .rnd(r[104]), .s(s[104]), .clk(clk), .out({g1_52, g0_52}));
MSKand_opini2_d2 u_t_52 (
    .ina({fc1[52], fc0[52]}), .inb({p1_52, p0_52}),
    .rnd(r[105]), .s(s[105]), .clk(clk), .out({t1_52, t0_52}));
assign fc0[53] = g0_52 ^ t0_52;
assign fc1[53] = g1_52 ^ t1_52;
wire p0_53 = Rsh_d0[53] ^ Bn0[53];
wire p1_53 = Rsh_d1[53] ^ Bn1[53];
wire g0_53, g1_53, t0_53, t1_53;
MSKand_opini2_d2 u_g_53 (
    .ina({Rsh_d1[53], Rsh_d0[53]}), .inb({Bn1[53], Bn0[53]}),
    .rnd(r[106]), .s(s[106]), .clk(clk), .out({g1_53, g0_53}));
MSKand_opini2_d2 u_t_53 (
    .ina({fc1[53], fc0[53]}), .inb({p1_53, p0_53}),
    .rnd(r[107]), .s(s[107]), .clk(clk), .out({t1_53, t0_53}));
assign fc0[54] = g0_53 ^ t0_53;
assign fc1[54] = g1_53 ^ t1_53;
wire p0_54 = Rsh_d0[54] ^ Bn0[54];
wire p1_54 = Rsh_d1[54] ^ Bn1[54];
wire g0_54, g1_54, t0_54, t1_54;
MSKand_opini2_d2 u_g_54 (
    .ina({Rsh_d1[54], Rsh_d0[54]}), .inb({Bn1[54], Bn0[54]}),
    .rnd(r[108]), .s(s[108]), .clk(clk), .out({g1_54, g0_54}));
MSKand_opini2_d2 u_t_54 (
    .ina({fc1[54], fc0[54]}), .inb({p1_54, p0_54}),
    .rnd(r[109]), .s(s[109]), .clk(clk), .out({t1_54, t0_54}));
assign fc0[55] = g0_54 ^ t0_54;
assign fc1[55] = g1_54 ^ t1_54;
wire p0_55 = Rsh_d0[55] ^ Bn0[55];
wire p1_55 = Rsh_d1[55] ^ Bn1[55];
wire g0_55, g1_55, t0_55, t1_55;
MSKand_opini2_d2 u_g_55 (
    .ina({Rsh_d1[55], Rsh_d0[55]}), .inb({Bn1[55], Bn0[55]}),
    .rnd(r[110]), .s(s[110]), .clk(clk), .out({g1_55, g0_55}));
MSKand_opini2_d2 u_t_55 (
    .ina({fc1[55], fc0[55]}), .inb({p1_55, p0_55}),
    .rnd(r[111]), .s(s[111]), .clk(clk), .out({t1_55, t0_55}));
assign fc0[56] = g0_55 ^ t0_55;
assign fc1[56] = g1_55 ^ t1_55;
wire p0_56 = Rsh_d0[56] ^ Bn0[56];
wire p1_56 = Rsh_d1[56] ^ Bn1[56];
wire g0_56, g1_56, t0_56, t1_56;
MSKand_opini2_d2 u_g_56 (
    .ina({Rsh_d1[56], Rsh_d0[56]}), .inb({Bn1[56], Bn0[56]}),
    .rnd(r[112]), .s(s[112]), .clk(clk), .out({g1_56, g0_56}));
MSKand_opini2_d2 u_t_56 (
    .ina({fc1[56], fc0[56]}), .inb({p1_56, p0_56}),
    .rnd(r[113]), .s(s[113]), .clk(clk), .out({t1_56, t0_56}));
assign fc0[57] = g0_56 ^ t0_56;
assign fc1[57] = g1_56 ^ t1_56;
wire p0_57 = Rsh_d0[57] ^ Bn0[57];
wire p1_57 = Rsh_d1[57] ^ Bn1[57];
wire g0_57, g1_57, t0_57, t1_57;
MSKand_opini2_d2 u_g_57 (
    .ina({Rsh_d1[57], Rsh_d0[57]}), .inb({Bn1[57], Bn0[57]}),
    .rnd(r[114]), .s(s[114]), .clk(clk), .out({g1_57, g0_57}));
MSKand_opini2_d2 u_t_57 (
    .ina({fc1[57], fc0[57]}), .inb({p1_57, p0_57}),
    .rnd(r[115]), .s(s[115]), .clk(clk), .out({t1_57, t0_57}));
assign fc0[58] = g0_57 ^ t0_57;
assign fc1[58] = g1_57 ^ t1_57;
wire p0_58 = Rsh_d0[58] ^ Bn0[58];
wire p1_58 = Rsh_d1[58] ^ Bn1[58];
wire g0_58, g1_58, t0_58, t1_58;
MSKand_opini2_d2 u_g_58 (
    .ina({Rsh_d1[58], Rsh_d0[58]}), .inb({Bn1[58], Bn0[58]}),
    .rnd(r[116]), .s(s[116]), .clk(clk), .out({g1_58, g0_58}));
MSKand_opini2_d2 u_t_58 (
    .ina({fc1[58], fc0[58]}), .inb({p1_58, p0_58}),
    .rnd(r[117]), .s(s[117]), .clk(clk), .out({t1_58, t0_58}));
assign fc0[59] = g0_58 ^ t0_58;
assign fc1[59] = g1_58 ^ t1_58;
wire p0_59 = Rsh_d0[59] ^ Bn0[59];
wire p1_59 = Rsh_d1[59] ^ Bn1[59];
wire g0_59, g1_59, t0_59, t1_59;
MSKand_opini2_d2 u_g_59 (
    .ina({Rsh_d1[59], Rsh_d0[59]}), .inb({Bn1[59], Bn0[59]}),
    .rnd(r[118]), .s(s[118]), .clk(clk), .out({g1_59, g0_59}));
MSKand_opini2_d2 u_t_59 (
    .ina({fc1[59], fc0[59]}), .inb({p1_59, p0_59}),
    .rnd(r[119]), .s(s[119]), .clk(clk), .out({t1_59, t0_59}));
assign fc0[60] = g0_59 ^ t0_59;
assign fc1[60] = g1_59 ^ t1_59;
wire p0_60 = Rsh_d0[60] ^ Bn0[60];
wire p1_60 = Rsh_d1[60] ^ Bn1[60];
wire g0_60, g1_60, t0_60, t1_60;
MSKand_opini2_d2 u_g_60 (
    .ina({Rsh_d1[60], Rsh_d0[60]}), .inb({Bn1[60], Bn0[60]}),
    .rnd(r[120]), .s(s[120]), .clk(clk), .out({g1_60, g0_60}));
MSKand_opini2_d2 u_t_60 (
    .ina({fc1[60], fc0[60]}), .inb({p1_60, p0_60}),
    .rnd(r[121]), .s(s[121]), .clk(clk), .out({t1_60, t0_60}));
assign fc0[61] = g0_60 ^ t0_60;
assign fc1[61] = g1_60 ^ t1_60;
wire p0_61 = Rsh_d0[61] ^ Bn0[61];
wire p1_61 = Rsh_d1[61] ^ Bn1[61];
wire g0_61, g1_61, t0_61, t1_61;
MSKand_opini2_d2 u_g_61 (
    .ina({Rsh_d1[61], Rsh_d0[61]}), .inb({Bn1[61], Bn0[61]}),
    .rnd(r[122]), .s(s[122]), .clk(clk), .out({g1_61, g0_61}));
MSKand_opini2_d2 u_t_61 (
    .ina({fc1[61], fc0[61]}), .inb({p1_61, p0_61}),
    .rnd(r[123]), .s(s[123]), .clk(clk), .out({t1_61, t0_61}));
assign fc0[62] = g0_61 ^ t0_61;
assign fc1[62] = g1_61 ^ t1_61;
wire p0_62 = Rsh_d0[62] ^ Bn0[62];
wire p1_62 = Rsh_d1[62] ^ Bn1[62];
wire g0_62, g1_62, t0_62, t1_62;
MSKand_opini2_d2 u_g_62 (
    .ina({Rsh_d1[62], Rsh_d0[62]}), .inb({Bn1[62], Bn0[62]}),
    .rnd(r[124]), .s(s[124]), .clk(clk), .out({g1_62, g0_62}));
MSKand_opini2_d2 u_t_62 (
    .ina({fc1[62], fc0[62]}), .inb({p1_62, p0_62}),
    .rnd(r[125]), .s(s[125]), .clk(clk), .out({t1_62, t0_62}));
assign fc0[63] = g0_62 ^ t0_62;
assign fc1[63] = g1_62 ^ t1_62;
wire p0_63 = Rsh_d0[63] ^ Bn0[63];
wire p1_63 = Rsh_d1[63] ^ Bn1[63];
wire g0_63, g1_63, t0_63, t1_63;
MSKand_opini2_d2 u_g_63 (
    .ina({Rsh_d1[63], Rsh_d0[63]}), .inb({Bn1[63], Bn0[63]}),
    .rnd(r[126]), .s(s[126]), .clk(clk), .out({g1_63, g0_63}));
MSKand_opini2_d2 u_t_63 (
    .ina({fc1[63], fc0[63]}), .inb({p1_63, p0_63}),
    .rnd(r[127]), .s(s[127]), .clk(clk), .out({t1_63, t0_63}));
assign fc0[64] = g0_63 ^ t0_63;
assign fc1[64] = g1_63 ^ t1_63;
wire p0_64 = Rsh_d0[64] ^ Bn0[64];
wire p1_64 = Rsh_d1[64] ^ Bn1[64];
wire g0_64, g1_64, t0_64, t1_64;
MSKand_opini2_d2 u_g_64 (
    .ina({Rsh_d1[64], Rsh_d0[64]}), .inb({Bn1[64], Bn0[64]}),
    .rnd(r[128]), .s(s[128]), .clk(clk), .out({g1_64, g0_64}));
MSKand_opini2_d2 u_t_64 (
    .ina({fc1[64], fc0[64]}), .inb({p1_64, p0_64}),
    .rnd(r[129]), .s(s[129]), .clk(clk), .out({t1_64, t0_64}));
assign fc0[65] = g0_64 ^ t0_64;
assign fc1[65] = g1_64 ^ t1_64;
wire p0_65 = Rsh_d0[65] ^ Bn0[65];
wire p1_65 = Rsh_d1[65] ^ Bn1[65];
wire g0_65, g1_65, t0_65, t1_65;
MSKand_opini2_d2 u_g_65 (
    .ina({Rsh_d1[65], Rsh_d0[65]}), .inb({Bn1[65], Bn0[65]}),
    .rnd(r[130]), .s(s[130]), .clk(clk), .out({g1_65, g0_65}));
MSKand_opini2_d2 u_t_65 (
    .ina({fc1[65], fc0[65]}), .inb({p1_65, p0_65}),
    .rnd(r[131]), .s(s[131]), .clk(clk), .out({t1_65, t0_65}));
assign fc0[66] = g0_65 ^ t0_65;
assign fc1[66] = g1_65 ^ t1_65;
wire p0_66 = Rsh_d0[66] ^ Bn0[66];
wire p1_66 = Rsh_d1[66] ^ Bn1[66];
wire g0_66, g1_66, t0_66, t1_66;
MSKand_opini2_d2 u_g_66 (
    .ina({Rsh_d1[66], Rsh_d0[66]}), .inb({Bn1[66], Bn0[66]}),
    .rnd(r[132]), .s(s[132]), .clk(clk), .out({g1_66, g0_66}));
MSKand_opini2_d2 u_t_66 (
    .ina({fc1[66], fc0[66]}), .inb({p1_66, p0_66}),
    .rnd(r[133]), .s(s[133]), .clk(clk), .out({t1_66, t0_66}));
assign fc0[67] = g0_66 ^ t0_66;
assign fc1[67] = g1_66 ^ t1_66;
wire p0_67 = Rsh_d0[67] ^ Bn0[67];
wire p1_67 = Rsh_d1[67] ^ Bn1[67];
wire g0_67, g1_67, t0_67, t1_67;
MSKand_opini2_d2 u_g_67 (
    .ina({Rsh_d1[67], Rsh_d0[67]}), .inb({Bn1[67], Bn0[67]}),
    .rnd(r[134]), .s(s[134]), .clk(clk), .out({g1_67, g0_67}));
MSKand_opini2_d2 u_t_67 (
    .ina({fc1[67], fc0[67]}), .inb({p1_67, p0_67}),
    .rnd(r[135]), .s(s[135]), .clk(clk), .out({t1_67, t0_67}));
assign fc0[68] = g0_67 ^ t0_67;
assign fc1[68] = g1_67 ^ t1_67;
wire p0_68 = Rsh_d0[68] ^ Bn0[68];
wire p1_68 = Rsh_d1[68] ^ Bn1[68];
wire g0_68, g1_68, t0_68, t1_68;
MSKand_opini2_d2 u_g_68 (
    .ina({Rsh_d1[68], Rsh_d0[68]}), .inb({Bn1[68], Bn0[68]}),
    .rnd(r[136]), .s(s[136]), .clk(clk), .out({g1_68, g0_68}));
MSKand_opini2_d2 u_t_68 (
    .ina({fc1[68], fc0[68]}), .inb({p1_68, p0_68}),
    .rnd(r[137]), .s(s[137]), .clk(clk), .out({t1_68, t0_68}));
assign fc0[69] = g0_68 ^ t0_68;
assign fc1[69] = g1_68 ^ t1_68;
wire p0_69 = Rsh_d0[69] ^ Bn0[69];
wire p1_69 = Rsh_d1[69] ^ Bn1[69];
wire g0_69, g1_69, t0_69, t1_69;
MSKand_opini2_d2 u_g_69 (
    .ina({Rsh_d1[69], Rsh_d0[69]}), .inb({Bn1[69], Bn0[69]}),
    .rnd(r[138]), .s(s[138]), .clk(clk), .out({g1_69, g0_69}));
MSKand_opini2_d2 u_t_69 (
    .ina({fc1[69], fc0[69]}), .inb({p1_69, p0_69}),
    .rnd(r[139]), .s(s[139]), .clk(clk), .out({t1_69, t0_69}));
assign fc0[70] = g0_69 ^ t0_69;
assign fc1[70] = g1_69 ^ t1_69;
wire p0_70 = Rsh_d0[70] ^ Bn0[70];
wire p1_70 = Rsh_d1[70] ^ Bn1[70];
wire g0_70, g1_70, t0_70, t1_70;
MSKand_opini2_d2 u_g_70 (
    .ina({Rsh_d1[70], Rsh_d0[70]}), .inb({Bn1[70], Bn0[70]}),
    .rnd(r[140]), .s(s[140]), .clk(clk), .out({g1_70, g0_70}));
MSKand_opini2_d2 u_t_70 (
    .ina({fc1[70], fc0[70]}), .inb({p1_70, p0_70}),
    .rnd(r[141]), .s(s[141]), .clk(clk), .out({t1_70, t0_70}));
assign fc0[71] = g0_70 ^ t0_70;
assign fc1[71] = g1_70 ^ t1_70;
wire p0_71 = Rsh_d0[71] ^ Bn0[71];
wire p1_71 = Rsh_d1[71] ^ Bn1[71];
wire g0_71, g1_71, t0_71, t1_71;
MSKand_opini2_d2 u_g_71 (
    .ina({Rsh_d1[71], Rsh_d0[71]}), .inb({Bn1[71], Bn0[71]}),
    .rnd(r[142]), .s(s[142]), .clk(clk), .out({g1_71, g0_71}));
MSKand_opini2_d2 u_t_71 (
    .ina({fc1[71], fc0[71]}), .inb({p1_71, p0_71}),
    .rnd(r[143]), .s(s[143]), .clk(clk), .out({t1_71, t0_71}));
assign fc0[72] = g0_71 ^ t0_71;
assign fc1[72] = g1_71 ^ t1_71;
wire p0_72 = Rsh_d0[72] ^ Bn0[72];
wire p1_72 = Rsh_d1[72] ^ Bn1[72];
wire g0_72, g1_72, t0_72, t1_72;
MSKand_opini2_d2 u_g_72 (
    .ina({Rsh_d1[72], Rsh_d0[72]}), .inb({Bn1[72], Bn0[72]}),
    .rnd(r[144]), .s(s[144]), .clk(clk), .out({g1_72, g0_72}));
MSKand_opini2_d2 u_t_72 (
    .ina({fc1[72], fc0[72]}), .inb({p1_72, p0_72}),
    .rnd(r[145]), .s(s[145]), .clk(clk), .out({t1_72, t0_72}));
assign fc0[73] = g0_72 ^ t0_72;
assign fc1[73] = g1_72 ^ t1_72;
wire p0_73 = Rsh_d0[73] ^ Bn0[73];
wire p1_73 = Rsh_d1[73] ^ Bn1[73];
wire g0_73, g1_73, t0_73, t1_73;
MSKand_opini2_d2 u_g_73 (
    .ina({Rsh_d1[73], Rsh_d0[73]}), .inb({Bn1[73], Bn0[73]}),
    .rnd(r[146]), .s(s[146]), .clk(clk), .out({g1_73, g0_73}));
MSKand_opini2_d2 u_t_73 (
    .ina({fc1[73], fc0[73]}), .inb({p1_73, p0_73}),
    .rnd(r[147]), .s(s[147]), .clk(clk), .out({t1_73, t0_73}));
assign fc0[74] = g0_73 ^ t0_73;
assign fc1[74] = g1_73 ^ t1_73;
wire p0_74 = Rsh_d0[74] ^ Bn0[74];
wire p1_74 = Rsh_d1[74] ^ Bn1[74];
wire g0_74, g1_74, t0_74, t1_74;
MSKand_opini2_d2 u_g_74 (
    .ina({Rsh_d1[74], Rsh_d0[74]}), .inb({Bn1[74], Bn0[74]}),
    .rnd(r[148]), .s(s[148]), .clk(clk), .out({g1_74, g0_74}));
MSKand_opini2_d2 u_t_74 (
    .ina({fc1[74], fc0[74]}), .inb({p1_74, p0_74}),
    .rnd(r[149]), .s(s[149]), .clk(clk), .out({t1_74, t0_74}));
assign fc0[75] = g0_74 ^ t0_74;
assign fc1[75] = g1_74 ^ t1_74;
wire p0_75 = Rsh_d0[75] ^ Bn0[75];
wire p1_75 = Rsh_d1[75] ^ Bn1[75];
wire g0_75, g1_75, t0_75, t1_75;
MSKand_opini2_d2 u_g_75 (
    .ina({Rsh_d1[75], Rsh_d0[75]}), .inb({Bn1[75], Bn0[75]}),
    .rnd(r[150]), .s(s[150]), .clk(clk), .out({g1_75, g0_75}));
MSKand_opini2_d2 u_t_75 (
    .ina({fc1[75], fc0[75]}), .inb({p1_75, p0_75}),
    .rnd(r[151]), .s(s[151]), .clk(clk), .out({t1_75, t0_75}));
assign fc0[76] = g0_75 ^ t0_75;
assign fc1[76] = g1_75 ^ t1_75;
wire p0_76 = Rsh_d0[76] ^ Bn0[76];
wire p1_76 = Rsh_d1[76] ^ Bn1[76];
wire g0_76, g1_76, t0_76, t1_76;
MSKand_opini2_d2 u_g_76 (
    .ina({Rsh_d1[76], Rsh_d0[76]}), .inb({Bn1[76], Bn0[76]}),
    .rnd(r[152]), .s(s[152]), .clk(clk), .out({g1_76, g0_76}));
MSKand_opini2_d2 u_t_76 (
    .ina({fc1[76], fc0[76]}), .inb({p1_76, p0_76}),
    .rnd(r[153]), .s(s[153]), .clk(clk), .out({t1_76, t0_76}));
assign fc0[77] = g0_76 ^ t0_76;
assign fc1[77] = g1_76 ^ t1_76;
wire p0_77 = Rsh_d0[77] ^ Bn0[77];
wire p1_77 = Rsh_d1[77] ^ Bn1[77];
wire g0_77, g1_77, t0_77, t1_77;
MSKand_opini2_d2 u_g_77 (
    .ina({Rsh_d1[77], Rsh_d0[77]}), .inb({Bn1[77], Bn0[77]}),
    .rnd(r[154]), .s(s[154]), .clk(clk), .out({g1_77, g0_77}));
MSKand_opini2_d2 u_t_77 (
    .ina({fc1[77], fc0[77]}), .inb({p1_77, p0_77}),
    .rnd(r[155]), .s(s[155]), .clk(clk), .out({t1_77, t0_77}));
assign fc0[78] = g0_77 ^ t0_77;
assign fc1[78] = g1_77 ^ t1_77;
wire p0_78 = Rsh_d0[78] ^ Bn0[78];
wire p1_78 = Rsh_d1[78] ^ Bn1[78];
wire g0_78, g1_78, t0_78, t1_78;
MSKand_opini2_d2 u_g_78 (
    .ina({Rsh_d1[78], Rsh_d0[78]}), .inb({Bn1[78], Bn0[78]}),
    .rnd(r[156]), .s(s[156]), .clk(clk), .out({g1_78, g0_78}));
MSKand_opini2_d2 u_t_78 (
    .ina({fc1[78], fc0[78]}), .inb({p1_78, p0_78}),
    .rnd(r[157]), .s(s[157]), .clk(clk), .out({t1_78, t0_78}));
assign fc0[79] = g0_78 ^ t0_78;
assign fc1[79] = g1_78 ^ t1_78;
wire p0_79 = Rsh_d0[79] ^ Bn0[79];
wire p1_79 = Rsh_d1[79] ^ Bn1[79];
wire g0_79, g1_79, t0_79, t1_79;
MSKand_opini2_d2 u_g_79 (
    .ina({Rsh_d1[79], Rsh_d0[79]}), .inb({Bn1[79], Bn0[79]}),
    .rnd(r[158]), .s(s[158]), .clk(clk), .out({g1_79, g0_79}));
MSKand_opini2_d2 u_t_79 (
    .ina({fc1[79], fc0[79]}), .inb({p1_79, p0_79}),
    .rnd(r[159]), .s(s[159]), .clk(clk), .out({t1_79, t0_79}));
assign fc0[80] = g0_79 ^ t0_79;
assign fc1[80] = g1_79 ^ t1_79;
wire p0_80 = Rsh_d0[80] ^ Bn0[80];
wire p1_80 = Rsh_d1[80] ^ Bn1[80];
wire g0_80, g1_80, t0_80, t1_80;
MSKand_opini2_d2 u_g_80 (
    .ina({Rsh_d1[80], Rsh_d0[80]}), .inb({Bn1[80], Bn0[80]}),
    .rnd(r[160]), .s(s[160]), .clk(clk), .out({g1_80, g0_80}));
MSKand_opini2_d2 u_t_80 (
    .ina({fc1[80], fc0[80]}), .inb({p1_80, p0_80}),
    .rnd(r[161]), .s(s[161]), .clk(clk), .out({t1_80, t0_80}));
assign fc0[81] = g0_80 ^ t0_80;
assign fc1[81] = g1_80 ^ t1_80;
wire p0_81 = Rsh_d0[81] ^ Bn0[81];
wire p1_81 = Rsh_d1[81] ^ Bn1[81];
wire g0_81, g1_81, t0_81, t1_81;
MSKand_opini2_d2 u_g_81 (
    .ina({Rsh_d1[81], Rsh_d0[81]}), .inb({Bn1[81], Bn0[81]}),
    .rnd(r[162]), .s(s[162]), .clk(clk), .out({g1_81, g0_81}));
MSKand_opini2_d2 u_t_81 (
    .ina({fc1[81], fc0[81]}), .inb({p1_81, p0_81}),
    .rnd(r[163]), .s(s[163]), .clk(clk), .out({t1_81, t0_81}));
assign fc0[82] = g0_81 ^ t0_81;
assign fc1[82] = g1_81 ^ t1_81;
wire p0_82 = Rsh_d0[82] ^ Bn0[82];
wire p1_82 = Rsh_d1[82] ^ Bn1[82];
wire g0_82, g1_82, t0_82, t1_82;
MSKand_opini2_d2 u_g_82 (
    .ina({Rsh_d1[82], Rsh_d0[82]}), .inb({Bn1[82], Bn0[82]}),
    .rnd(r[164]), .s(s[164]), .clk(clk), .out({g1_82, g0_82}));
MSKand_opini2_d2 u_t_82 (
    .ina({fc1[82], fc0[82]}), .inb({p1_82, p0_82}),
    .rnd(r[165]), .s(s[165]), .clk(clk), .out({t1_82, t0_82}));
assign fc0[83] = g0_82 ^ t0_82;
assign fc1[83] = g1_82 ^ t1_82;
wire p0_83 = Rsh_d0[83] ^ Bn0[83];
wire p1_83 = Rsh_d1[83] ^ Bn1[83];
wire g0_83, g1_83, t0_83, t1_83;
MSKand_opini2_d2 u_g_83 (
    .ina({Rsh_d1[83], Rsh_d0[83]}), .inb({Bn1[83], Bn0[83]}),
    .rnd(r[166]), .s(s[166]), .clk(clk), .out({g1_83, g0_83}));
MSKand_opini2_d2 u_t_83 (
    .ina({fc1[83], fc0[83]}), .inb({p1_83, p0_83}),
    .rnd(r[167]), .s(s[167]), .clk(clk), .out({t1_83, t0_83}));
assign fc0[84] = g0_83 ^ t0_83;
assign fc1[84] = g1_83 ^ t1_83;
wire p0_84 = Rsh_d0[84] ^ Bn0[84];
wire p1_84 = Rsh_d1[84] ^ Bn1[84];
wire g0_84, g1_84, t0_84, t1_84;
MSKand_opini2_d2 u_g_84 (
    .ina({Rsh_d1[84], Rsh_d0[84]}), .inb({Bn1[84], Bn0[84]}),
    .rnd(r[168]), .s(s[168]), .clk(clk), .out({g1_84, g0_84}));
MSKand_opini2_d2 u_t_84 (
    .ina({fc1[84], fc0[84]}), .inb({p1_84, p0_84}),
    .rnd(r[169]), .s(s[169]), .clk(clk), .out({t1_84, t0_84}));
assign fc0[85] = g0_84 ^ t0_84;
assign fc1[85] = g1_84 ^ t1_84;
wire p0_85 = Rsh_d0[85] ^ Bn0[85];
wire p1_85 = Rsh_d1[85] ^ Bn1[85];
wire g0_85, g1_85, t0_85, t1_85;
MSKand_opini2_d2 u_g_85 (
    .ina({Rsh_d1[85], Rsh_d0[85]}), .inb({Bn1[85], Bn0[85]}),
    .rnd(r[170]), .s(s[170]), .clk(clk), .out({g1_85, g0_85}));
MSKand_opini2_d2 u_t_85 (
    .ina({fc1[85], fc0[85]}), .inb({p1_85, p0_85}),
    .rnd(r[171]), .s(s[171]), .clk(clk), .out({t1_85, t0_85}));
assign fc0[86] = g0_85 ^ t0_85;
assign fc1[86] = g1_85 ^ t1_85;
wire p0_86 = Rsh_d0[86] ^ Bn0[86];
wire p1_86 = Rsh_d1[86] ^ Bn1[86];
wire g0_86, g1_86, t0_86, t1_86;
MSKand_opini2_d2 u_g_86 (
    .ina({Rsh_d1[86], Rsh_d0[86]}), .inb({Bn1[86], Bn0[86]}),
    .rnd(r[172]), .s(s[172]), .clk(clk), .out({g1_86, g0_86}));
MSKand_opini2_d2 u_t_86 (
    .ina({fc1[86], fc0[86]}), .inb({p1_86, p0_86}),
    .rnd(r[173]), .s(s[173]), .clk(clk), .out({t1_86, t0_86}));
assign fc0[87] = g0_86 ^ t0_86;
assign fc1[87] = g1_86 ^ t1_86;
wire p0_87 = Rsh_d0[87] ^ Bn0[87];
wire p1_87 = Rsh_d1[87] ^ Bn1[87];
wire g0_87, g1_87, t0_87, t1_87;
MSKand_opini2_d2 u_g_87 (
    .ina({Rsh_d1[87], Rsh_d0[87]}), .inb({Bn1[87], Bn0[87]}),
    .rnd(r[174]), .s(s[174]), .clk(clk), .out({g1_87, g0_87}));
MSKand_opini2_d2 u_t_87 (
    .ina({fc1[87], fc0[87]}), .inb({p1_87, p0_87}),
    .rnd(r[175]), .s(s[175]), .clk(clk), .out({t1_87, t0_87}));
assign fc0[88] = g0_87 ^ t0_87;
assign fc1[88] = g1_87 ^ t1_87;
wire p0_88 = Rsh_d0[88] ^ Bn0[88];
wire p1_88 = Rsh_d1[88] ^ Bn1[88];
wire g0_88, g1_88, t0_88, t1_88;
MSKand_opini2_d2 u_g_88 (
    .ina({Rsh_d1[88], Rsh_d0[88]}), .inb({Bn1[88], Bn0[88]}),
    .rnd(r[176]), .s(s[176]), .clk(clk), .out({g1_88, g0_88}));
MSKand_opini2_d2 u_t_88 (
    .ina({fc1[88], fc0[88]}), .inb({p1_88, p0_88}),
    .rnd(r[177]), .s(s[177]), .clk(clk), .out({t1_88, t0_88}));
assign fc0[89] = g0_88 ^ t0_88;
assign fc1[89] = g1_88 ^ t1_88;
wire p0_89 = Rsh_d0[89] ^ Bn0[89];
wire p1_89 = Rsh_d1[89] ^ Bn1[89];
wire g0_89, g1_89, t0_89, t1_89;
MSKand_opini2_d2 u_g_89 (
    .ina({Rsh_d1[89], Rsh_d0[89]}), .inb({Bn1[89], Bn0[89]}),
    .rnd(r[178]), .s(s[178]), .clk(clk), .out({g1_89, g0_89}));
MSKand_opini2_d2 u_t_89 (
    .ina({fc1[89], fc0[89]}), .inb({p1_89, p0_89}),
    .rnd(r[179]), .s(s[179]), .clk(clk), .out({t1_89, t0_89}));
assign fc0[90] = g0_89 ^ t0_89;
assign fc1[90] = g1_89 ^ t1_89;
wire p0_90 = Rsh_d0[90] ^ Bn0[90];
wire p1_90 = Rsh_d1[90] ^ Bn1[90];
wire g0_90, g1_90, t0_90, t1_90;
MSKand_opini2_d2 u_g_90 (
    .ina({Rsh_d1[90], Rsh_d0[90]}), .inb({Bn1[90], Bn0[90]}),
    .rnd(r[180]), .s(s[180]), .clk(clk), .out({g1_90, g0_90}));
MSKand_opini2_d2 u_t_90 (
    .ina({fc1[90], fc0[90]}), .inb({p1_90, p0_90}),
    .rnd(r[181]), .s(s[181]), .clk(clk), .out({t1_90, t0_90}));
assign fc0[91] = g0_90 ^ t0_90;
assign fc1[91] = g1_90 ^ t1_90;
wire p0_91 = Rsh_d0[91] ^ Bn0[91];
wire p1_91 = Rsh_d1[91] ^ Bn1[91];
wire g0_91, g1_91, t0_91, t1_91;
MSKand_opini2_d2 u_g_91 (
    .ina({Rsh_d1[91], Rsh_d0[91]}), .inb({Bn1[91], Bn0[91]}),
    .rnd(r[182]), .s(s[182]), .clk(clk), .out({g1_91, g0_91}));
MSKand_opini2_d2 u_t_91 (
    .ina({fc1[91], fc0[91]}), .inb({p1_91, p0_91}),
    .rnd(r[183]), .s(s[183]), .clk(clk), .out({t1_91, t0_91}));
assign fc0[92] = g0_91 ^ t0_91;
assign fc1[92] = g1_91 ^ t1_91;
wire p0_92 = Rsh_d0[92] ^ Bn0[92];
wire p1_92 = Rsh_d1[92] ^ Bn1[92];
wire g0_92, g1_92, t0_92, t1_92;
MSKand_opini2_d2 u_g_92 (
    .ina({Rsh_d1[92], Rsh_d0[92]}), .inb({Bn1[92], Bn0[92]}),
    .rnd(r[184]), .s(s[184]), .clk(clk), .out({g1_92, g0_92}));
MSKand_opini2_d2 u_t_92 (
    .ina({fc1[92], fc0[92]}), .inb({p1_92, p0_92}),
    .rnd(r[185]), .s(s[185]), .clk(clk), .out({t1_92, t0_92}));
assign fc0[93] = g0_92 ^ t0_92;
assign fc1[93] = g1_92 ^ t1_92;
wire p0_93 = Rsh_d0[93] ^ Bn0[93];
wire p1_93 = Rsh_d1[93] ^ Bn1[93];
wire g0_93, g1_93, t0_93, t1_93;
MSKand_opini2_d2 u_g_93 (
    .ina({Rsh_d1[93], Rsh_d0[93]}), .inb({Bn1[93], Bn0[93]}),
    .rnd(r[186]), .s(s[186]), .clk(clk), .out({g1_93, g0_93}));
MSKand_opini2_d2 u_t_93 (
    .ina({fc1[93], fc0[93]}), .inb({p1_93, p0_93}),
    .rnd(r[187]), .s(s[187]), .clk(clk), .out({t1_93, t0_93}));
assign fc0[94] = g0_93 ^ t0_93;
assign fc1[94] = g1_93 ^ t1_93;
wire p0_94 = Rsh_d0[94] ^ Bn0[94];
wire p1_94 = Rsh_d1[94] ^ Bn1[94];
wire g0_94, g1_94, t0_94, t1_94;
MSKand_opini2_d2 u_g_94 (
    .ina({Rsh_d1[94], Rsh_d0[94]}), .inb({Bn1[94], Bn0[94]}),
    .rnd(r[188]), .s(s[188]), .clk(clk), .out({g1_94, g0_94}));
MSKand_opini2_d2 u_t_94 (
    .ina({fc1[94], fc0[94]}), .inb({p1_94, p0_94}),
    .rnd(r[189]), .s(s[189]), .clk(clk), .out({t1_94, t0_94}));
assign fc0[95] = g0_94 ^ t0_94;
assign fc1[95] = g1_94 ^ t1_94;
wire p0_95 = Rsh_d0[95] ^ Bn0[95];
wire p1_95 = Rsh_d1[95] ^ Bn1[95];
wire g0_95, g1_95, t0_95, t1_95;
MSKand_opini2_d2 u_g_95 (
    .ina({Rsh_d1[95], Rsh_d0[95]}), .inb({Bn1[95], Bn0[95]}),
    .rnd(r[190]), .s(s[190]), .clk(clk), .out({g1_95, g0_95}));
MSKand_opini2_d2 u_t_95 (
    .ina({fc1[95], fc0[95]}), .inb({p1_95, p0_95}),
    .rnd(r[191]), .s(s[191]), .clk(clk), .out({t1_95, t0_95}));
assign fc0[96] = g0_95 ^ t0_95;
assign fc1[96] = g1_95 ^ t1_95;
wire p0_96 = Rsh_d0[96] ^ Bn0[96];
wire p1_96 = Rsh_d1[96] ^ Bn1[96];
wire g0_96, g1_96, t0_96, t1_96;
MSKand_opini2_d2 u_g_96 (
    .ina({Rsh_d1[96], Rsh_d0[96]}), .inb({Bn1[96], Bn0[96]}),
    .rnd(r[192]), .s(s[192]), .clk(clk), .out({g1_96, g0_96}));
MSKand_opini2_d2 u_t_96 (
    .ina({fc1[96], fc0[96]}), .inb({p1_96, p0_96}),
    .rnd(r[193]), .s(s[193]), .clk(clk), .out({t1_96, t0_96}));
assign fc0[97] = g0_96 ^ t0_96;
assign fc1[97] = g1_96 ^ t1_96;
wire p0_97 = Rsh_d0[97] ^ Bn0[97];
wire p1_97 = Rsh_d1[97] ^ Bn1[97];
wire g0_97, g1_97, t0_97, t1_97;
MSKand_opini2_d2 u_g_97 (
    .ina({Rsh_d1[97], Rsh_d0[97]}), .inb({Bn1[97], Bn0[97]}),
    .rnd(r[194]), .s(s[194]), .clk(clk), .out({g1_97, g0_97}));
MSKand_opini2_d2 u_t_97 (
    .ina({fc1[97], fc0[97]}), .inb({p1_97, p0_97}),
    .rnd(r[195]), .s(s[195]), .clk(clk), .out({t1_97, t0_97}));
assign fc0[98] = g0_97 ^ t0_97;
assign fc1[98] = g1_97 ^ t1_97;
wire p0_98 = Rsh_d0[98] ^ Bn0[98];
wire p1_98 = Rsh_d1[98] ^ Bn1[98];
wire g0_98, g1_98, t0_98, t1_98;
MSKand_opini2_d2 u_g_98 (
    .ina({Rsh_d1[98], Rsh_d0[98]}), .inb({Bn1[98], Bn0[98]}),
    .rnd(r[196]), .s(s[196]), .clk(clk), .out({g1_98, g0_98}));
MSKand_opini2_d2 u_t_98 (
    .ina({fc1[98], fc0[98]}), .inb({p1_98, p0_98}),
    .rnd(r[197]), .s(s[197]), .clk(clk), .out({t1_98, t0_98}));
assign fc0[99] = g0_98 ^ t0_98;
assign fc1[99] = g1_98 ^ t1_98;
wire p0_99 = Rsh_d0[99] ^ Bn0[99];
wire p1_99 = Rsh_d1[99] ^ Bn1[99];
wire g0_99, g1_99, t0_99, t1_99;
MSKand_opini2_d2 u_g_99 (
    .ina({Rsh_d1[99], Rsh_d0[99]}), .inb({Bn1[99], Bn0[99]}),
    .rnd(r[198]), .s(s[198]), .clk(clk), .out({g1_99, g0_99}));
MSKand_opini2_d2 u_t_99 (
    .ina({fc1[99], fc0[99]}), .inb({p1_99, p0_99}),
    .rnd(r[199]), .s(s[199]), .clk(clk), .out({t1_99, t0_99}));
assign fc0[100] = g0_99 ^ t0_99;
assign fc1[100] = g1_99 ^ t1_99;
wire p0_100 = Rsh_d0[100] ^ Bn0[100];
wire p1_100 = Rsh_d1[100] ^ Bn1[100];
wire g0_100, g1_100, t0_100, t1_100;
MSKand_opini2_d2 u_g_100 (
    .ina({Rsh_d1[100], Rsh_d0[100]}), .inb({Bn1[100], Bn0[100]}),
    .rnd(r[200]), .s(s[200]), .clk(clk), .out({g1_100, g0_100}));
MSKand_opini2_d2 u_t_100 (
    .ina({fc1[100], fc0[100]}), .inb({p1_100, p0_100}),
    .rnd(r[201]), .s(s[201]), .clk(clk), .out({t1_100, t0_100}));
assign fc0[101] = g0_100 ^ t0_100;
assign fc1[101] = g1_100 ^ t1_100;
wire p0_101 = Rsh_d0[101] ^ Bn0[101];
wire p1_101 = Rsh_d1[101] ^ Bn1[101];
wire g0_101, g1_101, t0_101, t1_101;
MSKand_opini2_d2 u_g_101 (
    .ina({Rsh_d1[101], Rsh_d0[101]}), .inb({Bn1[101], Bn0[101]}),
    .rnd(r[202]), .s(s[202]), .clk(clk), .out({g1_101, g0_101}));
MSKand_opini2_d2 u_t_101 (
    .ina({fc1[101], fc0[101]}), .inb({p1_101, p0_101}),
    .rnd(r[203]), .s(s[203]), .clk(clk), .out({t1_101, t0_101}));
assign fc0[102] = g0_101 ^ t0_101;
assign fc1[102] = g1_101 ^ t1_101;
wire p0_102 = Rsh_d0[102] ^ Bn0[102];
wire p1_102 = Rsh_d1[102] ^ Bn1[102];
wire g0_102, g1_102, t0_102, t1_102;
MSKand_opini2_d2 u_g_102 (
    .ina({Rsh_d1[102], Rsh_d0[102]}), .inb({Bn1[102], Bn0[102]}),
    .rnd(r[204]), .s(s[204]), .clk(clk), .out({g1_102, g0_102}));
MSKand_opini2_d2 u_t_102 (
    .ina({fc1[102], fc0[102]}), .inb({p1_102, p0_102}),
    .rnd(r[205]), .s(s[205]), .clk(clk), .out({t1_102, t0_102}));
assign fc0[103] = g0_102 ^ t0_102;
assign fc1[103] = g1_102 ^ t1_102;
wire p0_103 = Rsh_d0[103] ^ Bn0[103];
wire p1_103 = Rsh_d1[103] ^ Bn1[103];
wire g0_103, g1_103, t0_103, t1_103;
MSKand_opini2_d2 u_g_103 (
    .ina({Rsh_d1[103], Rsh_d0[103]}), .inb({Bn1[103], Bn0[103]}),
    .rnd(r[206]), .s(s[206]), .clk(clk), .out({g1_103, g0_103}));
MSKand_opini2_d2 u_t_103 (
    .ina({fc1[103], fc0[103]}), .inb({p1_103, p0_103}),
    .rnd(r[207]), .s(s[207]), .clk(clk), .out({t1_103, t0_103}));
assign fc0[104] = g0_103 ^ t0_103;
assign fc1[104] = g1_103 ^ t1_103;
wire p0_104 = Rsh_d0[104] ^ Bn0[104];
wire p1_104 = Rsh_d1[104] ^ Bn1[104];
wire g0_104, g1_104, t0_104, t1_104;
MSKand_opini2_d2 u_g_104 (
    .ina({Rsh_d1[104], Rsh_d0[104]}), .inb({Bn1[104], Bn0[104]}),
    .rnd(r[208]), .s(s[208]), .clk(clk), .out({g1_104, g0_104}));
MSKand_opini2_d2 u_t_104 (
    .ina({fc1[104], fc0[104]}), .inb({p1_104, p0_104}),
    .rnd(r[209]), .s(s[209]), .clk(clk), .out({t1_104, t0_104}));
assign fc0[105] = g0_104 ^ t0_104;
assign fc1[105] = g1_104 ^ t1_104;
wire p0_105 = Rsh_d0[105] ^ Bn0[105];
wire p1_105 = Rsh_d1[105] ^ Bn1[105];
wire g0_105, g1_105, t0_105, t1_105;
MSKand_opini2_d2 u_g_105 (
    .ina({Rsh_d1[105], Rsh_d0[105]}), .inb({Bn1[105], Bn0[105]}),
    .rnd(r[210]), .s(s[210]), .clk(clk), .out({g1_105, g0_105}));
MSKand_opini2_d2 u_t_105 (
    .ina({fc1[105], fc0[105]}), .inb({p1_105, p0_105}),
    .rnd(r[211]), .s(s[211]), .clk(clk), .out({t1_105, t0_105}));
assign fc0[106] = g0_105 ^ t0_105;
assign fc1[106] = g1_105 ^ t1_105;
wire p0_106 = Rsh_d0[106] ^ Bn0[106];
wire p1_106 = Rsh_d1[106] ^ Bn1[106];
wire g0_106, g1_106, t0_106, t1_106;
MSKand_opini2_d2 u_g_106 (
    .ina({Rsh_d1[106], Rsh_d0[106]}), .inb({Bn1[106], Bn0[106]}),
    .rnd(r[212]), .s(s[212]), .clk(clk), .out({g1_106, g0_106}));
MSKand_opini2_d2 u_t_106 (
    .ina({fc1[106], fc0[106]}), .inb({p1_106, p0_106}),
    .rnd(r[213]), .s(s[213]), .clk(clk), .out({t1_106, t0_106}));
assign fc0[107] = g0_106 ^ t0_106;
assign fc1[107] = g1_106 ^ t1_106;
wire p0_107 = Rsh_d0[107] ^ Bn0[107];
wire p1_107 = Rsh_d1[107] ^ Bn1[107];
wire g0_107, g1_107, t0_107, t1_107;
MSKand_opini2_d2 u_g_107 (
    .ina({Rsh_d1[107], Rsh_d0[107]}), .inb({Bn1[107], Bn0[107]}),
    .rnd(r[214]), .s(s[214]), .clk(clk), .out({g1_107, g0_107}));
MSKand_opini2_d2 u_t_107 (
    .ina({fc1[107], fc0[107]}), .inb({p1_107, p0_107}),
    .rnd(r[215]), .s(s[215]), .clk(clk), .out({t1_107, t0_107}));
assign fc0[108] = g0_107 ^ t0_107;
assign fc1[108] = g1_107 ^ t1_107;
wire p0_108 = Rsh_d0[108] ^ Bn0[108];
wire p1_108 = Rsh_d1[108] ^ Bn1[108];
wire g0_108, g1_108, t0_108, t1_108;
MSKand_opini2_d2 u_g_108 (
    .ina({Rsh_d1[108], Rsh_d0[108]}), .inb({Bn1[108], Bn0[108]}),
    .rnd(r[216]), .s(s[216]), .clk(clk), .out({g1_108, g0_108}));
MSKand_opini2_d2 u_t_108 (
    .ina({fc1[108], fc0[108]}), .inb({p1_108, p0_108}),
    .rnd(r[217]), .s(s[217]), .clk(clk), .out({t1_108, t0_108}));
assign fc0[109] = g0_108 ^ t0_108;
assign fc1[109] = g1_108 ^ t1_108;
wire p0_109 = Rsh_d0[109] ^ Bn0[109];
wire p1_109 = Rsh_d1[109] ^ Bn1[109];
wire g0_109, g1_109, t0_109, t1_109;
MSKand_opini2_d2 u_g_109 (
    .ina({Rsh_d1[109], Rsh_d0[109]}), .inb({Bn1[109], Bn0[109]}),
    .rnd(r[218]), .s(s[218]), .clk(clk), .out({g1_109, g0_109}));
MSKand_opini2_d2 u_t_109 (
    .ina({fc1[109], fc0[109]}), .inb({p1_109, p0_109}),
    .rnd(r[219]), .s(s[219]), .clk(clk), .out({t1_109, t0_109}));
assign fc0[110] = g0_109 ^ t0_109;
assign fc1[110] = g1_109 ^ t1_109;
wire p0_110 = Rsh_d0[110] ^ Bn0[110];
wire p1_110 = Rsh_d1[110] ^ Bn1[110];
wire g0_110, g1_110, t0_110, t1_110;
MSKand_opini2_d2 u_g_110 (
    .ina({Rsh_d1[110], Rsh_d0[110]}), .inb({Bn1[110], Bn0[110]}),
    .rnd(r[220]), .s(s[220]), .clk(clk), .out({g1_110, g0_110}));
MSKand_opini2_d2 u_t_110 (
    .ina({fc1[110], fc0[110]}), .inb({p1_110, p0_110}),
    .rnd(r[221]), .s(s[221]), .clk(clk), .out({t1_110, t0_110}));
assign fc0[111] = g0_110 ^ t0_110;
assign fc1[111] = g1_110 ^ t1_110;
wire p0_111 = Rsh_d0[111] ^ Bn0[111];
wire p1_111 = Rsh_d1[111] ^ Bn1[111];
wire g0_111, g1_111, t0_111, t1_111;
MSKand_opini2_d2 u_g_111 (
    .ina({Rsh_d1[111], Rsh_d0[111]}), .inb({Bn1[111], Bn0[111]}),
    .rnd(r[222]), .s(s[222]), .clk(clk), .out({g1_111, g0_111}));
MSKand_opini2_d2 u_t_111 (
    .ina({fc1[111], fc0[111]}), .inb({p1_111, p0_111}),
    .rnd(r[223]), .s(s[223]), .clk(clk), .out({t1_111, t0_111}));
assign fc0[112] = g0_111 ^ t0_111;
assign fc1[112] = g1_111 ^ t1_111;
wire p0_112 = Rsh_d0[112] ^ Bn0[112];
wire p1_112 = Rsh_d1[112] ^ Bn1[112];
wire g0_112, g1_112, t0_112, t1_112;
MSKand_opini2_d2 u_g_112 (
    .ina({Rsh_d1[112], Rsh_d0[112]}), .inb({Bn1[112], Bn0[112]}),
    .rnd(r[224]), .s(s[224]), .clk(clk), .out({g1_112, g0_112}));
MSKand_opini2_d2 u_t_112 (
    .ina({fc1[112], fc0[112]}), .inb({p1_112, p0_112}),
    .rnd(r[225]), .s(s[225]), .clk(clk), .out({t1_112, t0_112}));
assign fc0[113] = g0_112 ^ t0_112;
assign fc1[113] = g1_112 ^ t1_112;
wire p0_113 = Rsh_d0[113] ^ Bn0[113];
wire p1_113 = Rsh_d1[113] ^ Bn1[113];
wire g0_113, g1_113, t0_113, t1_113;
MSKand_opini2_d2 u_g_113 (
    .ina({Rsh_d1[113], Rsh_d0[113]}), .inb({Bn1[113], Bn0[113]}),
    .rnd(r[226]), .s(s[226]), .clk(clk), .out({g1_113, g0_113}));
MSKand_opini2_d2 u_t_113 (
    .ina({fc1[113], fc0[113]}), .inb({p1_113, p0_113}),
    .rnd(r[227]), .s(s[227]), .clk(clk), .out({t1_113, t0_113}));
assign fc0[114] = g0_113 ^ t0_113;
assign fc1[114] = g1_113 ^ t1_113;
wire p0_114 = Rsh_d0[114] ^ Bn0[114];
wire p1_114 = Rsh_d1[114] ^ Bn1[114];
wire g0_114, g1_114, t0_114, t1_114;
MSKand_opini2_d2 u_g_114 (
    .ina({Rsh_d1[114], Rsh_d0[114]}), .inb({Bn1[114], Bn0[114]}),
    .rnd(r[228]), .s(s[228]), .clk(clk), .out({g1_114, g0_114}));
MSKand_opini2_d2 u_t_114 (
    .ina({fc1[114], fc0[114]}), .inb({p1_114, p0_114}),
    .rnd(r[229]), .s(s[229]), .clk(clk), .out({t1_114, t0_114}));
assign fc0[115] = g0_114 ^ t0_114;
assign fc1[115] = g1_114 ^ t1_114;
wire p0_115 = Rsh_d0[115] ^ Bn0[115];
wire p1_115 = Rsh_d1[115] ^ Bn1[115];
wire g0_115, g1_115, t0_115, t1_115;
MSKand_opini2_d2 u_g_115 (
    .ina({Rsh_d1[115], Rsh_d0[115]}), .inb({Bn1[115], Bn0[115]}),
    .rnd(r[230]), .s(s[230]), .clk(clk), .out({g1_115, g0_115}));
MSKand_opini2_d2 u_t_115 (
    .ina({fc1[115], fc0[115]}), .inb({p1_115, p0_115}),
    .rnd(r[231]), .s(s[231]), .clk(clk), .out({t1_115, t0_115}));
assign fc0[116] = g0_115 ^ t0_115;
assign fc1[116] = g1_115 ^ t1_115;
wire p0_116 = Rsh_d0[116] ^ Bn0[116];
wire p1_116 = Rsh_d1[116] ^ Bn1[116];
wire g0_116, g1_116, t0_116, t1_116;
MSKand_opini2_d2 u_g_116 (
    .ina({Rsh_d1[116], Rsh_d0[116]}), .inb({Bn1[116], Bn0[116]}),
    .rnd(r[232]), .s(s[232]), .clk(clk), .out({g1_116, g0_116}));
MSKand_opini2_d2 u_t_116 (
    .ina({fc1[116], fc0[116]}), .inb({p1_116, p0_116}),
    .rnd(r[233]), .s(s[233]), .clk(clk), .out({t1_116, t0_116}));
assign fc0[117] = g0_116 ^ t0_116;
assign fc1[117] = g1_116 ^ t1_116;
wire p0_117 = Rsh_d0[117] ^ Bn0[117];
wire p1_117 = Rsh_d1[117] ^ Bn1[117];
wire g0_117, g1_117, t0_117, t1_117;
MSKand_opini2_d2 u_g_117 (
    .ina({Rsh_d1[117], Rsh_d0[117]}), .inb({Bn1[117], Bn0[117]}),
    .rnd(r[234]), .s(s[234]), .clk(clk), .out({g1_117, g0_117}));
MSKand_opini2_d2 u_t_117 (
    .ina({fc1[117], fc0[117]}), .inb({p1_117, p0_117}),
    .rnd(r[235]), .s(s[235]), .clk(clk), .out({t1_117, t0_117}));
assign fc0[118] = g0_117 ^ t0_117;
assign fc1[118] = g1_117 ^ t1_117;
wire p0_118 = Rsh_d0[118] ^ Bn0[118];
wire p1_118 = Rsh_d1[118] ^ Bn1[118];
wire g0_118, g1_118, t0_118, t1_118;
MSKand_opini2_d2 u_g_118 (
    .ina({Rsh_d1[118], Rsh_d0[118]}), .inb({Bn1[118], Bn0[118]}),
    .rnd(r[236]), .s(s[236]), .clk(clk), .out({g1_118, g0_118}));
MSKand_opini2_d2 u_t_118 (
    .ina({fc1[118], fc0[118]}), .inb({p1_118, p0_118}),
    .rnd(r[237]), .s(s[237]), .clk(clk), .out({t1_118, t0_118}));
assign fc0[119] = g0_118 ^ t0_118;
assign fc1[119] = g1_118 ^ t1_118;
wire p0_119 = Rsh_d0[119] ^ Bn0[119];
wire p1_119 = Rsh_d1[119] ^ Bn1[119];
wire g0_119, g1_119, t0_119, t1_119;
MSKand_opini2_d2 u_g_119 (
    .ina({Rsh_d1[119], Rsh_d0[119]}), .inb({Bn1[119], Bn0[119]}),
    .rnd(r[238]), .s(s[238]), .clk(clk), .out({g1_119, g0_119}));
MSKand_opini2_d2 u_t_119 (
    .ina({fc1[119], fc0[119]}), .inb({p1_119, p0_119}),
    .rnd(r[239]), .s(s[239]), .clk(clk), .out({t1_119, t0_119}));
assign fc0[120] = g0_119 ^ t0_119;
assign fc1[120] = g1_119 ^ t1_119;
wire p0_120 = Rsh_d0[120] ^ Bn0[120];
wire p1_120 = Rsh_d1[120] ^ Bn1[120];
wire g0_120, g1_120, t0_120, t1_120;
MSKand_opini2_d2 u_g_120 (
    .ina({Rsh_d1[120], Rsh_d0[120]}), .inb({Bn1[120], Bn0[120]}),
    .rnd(r[240]), .s(s[240]), .clk(clk), .out({g1_120, g0_120}));
MSKand_opini2_d2 u_t_120 (
    .ina({fc1[120], fc0[120]}), .inb({p1_120, p0_120}),
    .rnd(r[241]), .s(s[241]), .clk(clk), .out({t1_120, t0_120}));
assign fc0[121] = g0_120 ^ t0_120;
assign fc1[121] = g1_120 ^ t1_120;
wire p0_121 = Rsh_d0[121] ^ Bn0[121];
wire p1_121 = Rsh_d1[121] ^ Bn1[121];
wire g0_121, g1_121, t0_121, t1_121;
MSKand_opini2_d2 u_g_121 (
    .ina({Rsh_d1[121], Rsh_d0[121]}), .inb({Bn1[121], Bn0[121]}),
    .rnd(r[242]), .s(s[242]), .clk(clk), .out({g1_121, g0_121}));
MSKand_opini2_d2 u_t_121 (
    .ina({fc1[121], fc0[121]}), .inb({p1_121, p0_121}),
    .rnd(r[243]), .s(s[243]), .clk(clk), .out({t1_121, t0_121}));
assign fc0[122] = g0_121 ^ t0_121;
assign fc1[122] = g1_121 ^ t1_121;
wire p0_122 = Rsh_d0[122] ^ Bn0[122];
wire p1_122 = Rsh_d1[122] ^ Bn1[122];
wire g0_122, g1_122, t0_122, t1_122;
MSKand_opini2_d2 u_g_122 (
    .ina({Rsh_d1[122], Rsh_d0[122]}), .inb({Bn1[122], Bn0[122]}),
    .rnd(r[244]), .s(s[244]), .clk(clk), .out({g1_122, g0_122}));
MSKand_opini2_d2 u_t_122 (
    .ina({fc1[122], fc0[122]}), .inb({p1_122, p0_122}),
    .rnd(r[245]), .s(s[245]), .clk(clk), .out({t1_122, t0_122}));
assign fc0[123] = g0_122 ^ t0_122;
assign fc1[123] = g1_122 ^ t1_122;
wire p0_123 = Rsh_d0[123] ^ Bn0[123];
wire p1_123 = Rsh_d1[123] ^ Bn1[123];
wire g0_123, g1_123, t0_123, t1_123;
MSKand_opini2_d2 u_g_123 (
    .ina({Rsh_d1[123], Rsh_d0[123]}), .inb({Bn1[123], Bn0[123]}),
    .rnd(r[246]), .s(s[246]), .clk(clk), .out({g1_123, g0_123}));
MSKand_opini2_d2 u_t_123 (
    .ina({fc1[123], fc0[123]}), .inb({p1_123, p0_123}),
    .rnd(r[247]), .s(s[247]), .clk(clk), .out({t1_123, t0_123}));
assign fc0[124] = g0_123 ^ t0_123;
assign fc1[124] = g1_123 ^ t1_123;
wire p0_124 = Rsh_d0[124] ^ Bn0[124];
wire p1_124 = Rsh_d1[124] ^ Bn1[124];
wire g0_124, g1_124, t0_124, t1_124;
MSKand_opini2_d2 u_g_124 (
    .ina({Rsh_d1[124], Rsh_d0[124]}), .inb({Bn1[124], Bn0[124]}),
    .rnd(r[248]), .s(s[248]), .clk(clk), .out({g1_124, g0_124}));
MSKand_opini2_d2 u_t_124 (
    .ina({fc1[124], fc0[124]}), .inb({p1_124, p0_124}),
    .rnd(r[249]), .s(s[249]), .clk(clk), .out({t1_124, t0_124}));
assign fc0[125] = g0_124 ^ t0_124;
assign fc1[125] = g1_124 ^ t1_124;
wire p0_125 = Rsh_d0[125] ^ Bn0[125];
wire p1_125 = Rsh_d1[125] ^ Bn1[125];
wire g0_125, g1_125, t0_125, t1_125;
MSKand_opini2_d2 u_g_125 (
    .ina({Rsh_d1[125], Rsh_d0[125]}), .inb({Bn1[125], Bn0[125]}),
    .rnd(r[250]), .s(s[250]), .clk(clk), .out({g1_125, g0_125}));
MSKand_opini2_d2 u_t_125 (
    .ina({fc1[125], fc0[125]}), .inb({p1_125, p0_125}),
    .rnd(r[251]), .s(s[251]), .clk(clk), .out({t1_125, t0_125}));
assign fc0[126] = g0_125 ^ t0_125;
assign fc1[126] = g1_125 ^ t1_125;
wire p0_126 = Rsh_d0[126] ^ Bn0[126];
wire p1_126 = Rsh_d1[126] ^ Bn1[126];
wire g0_126, g1_126, t0_126, t1_126;
MSKand_opini2_d2 u_g_126 (
    .ina({Rsh_d1[126], Rsh_d0[126]}), .inb({Bn1[126], Bn0[126]}),
    .rnd(r[252]), .s(s[252]), .clk(clk), .out({g1_126, g0_126}));
MSKand_opini2_d2 u_t_126 (
    .ina({fc1[126], fc0[126]}), .inb({p1_126, p0_126}),
    .rnd(r[253]), .s(s[253]), .clk(clk), .out({t1_126, t0_126}));
assign fc0[127] = g0_126 ^ t0_126;
assign fc1[127] = g1_126 ^ t1_126;
wire p0_127 = Rsh_d0[127] ^ Bn0[127];
wire p1_127 = Rsh_d1[127] ^ Bn1[127];
wire g0_127, g1_127, t0_127, t1_127;
MSKand_opini2_d2 u_g_127 (
    .ina({Rsh_d1[127], Rsh_d0[127]}), .inb({Bn1[127], Bn0[127]}),
    .rnd(r[254]), .s(s[254]), .clk(clk), .out({g1_127, g0_127}));
MSKand_opini2_d2 u_t_127 (
    .ina({fc1[127], fc0[127]}), .inb({p1_127, p0_127}),
    .rnd(r[255]), .s(s[255]), .clk(clk), .out({t1_127, t0_127}));
assign fc0[128] = g0_127 ^ t0_127;
assign fc1[128] = g1_127 ^ t1_127;
wire p0_128 = Rsh_d0[128] ^ Bn0[128];
wire p1_128 = Rsh_d1[128] ^ Bn1[128];
wire g0_128, g1_128, t0_128, t1_128;
MSKand_opini2_d2 u_g_128 (
    .ina({Rsh_d1[128], Rsh_d0[128]}), .inb({Bn1[128], Bn0[128]}),
    .rnd(r[256]), .s(s[256]), .clk(clk), .out({g1_128, g0_128}));
MSKand_opini2_d2 u_t_128 (
    .ina({fc1[128], fc0[128]}), .inb({p1_128, p0_128}),
    .rnd(r[257]), .s(s[257]), .clk(clk), .out({t1_128, t0_128}));
assign fc0[129] = g0_128 ^ t0_128;
assign fc1[129] = g1_128 ^ t1_128;
wire p0_129 = Rsh_d0[129] ^ Bn0[129];
wire p1_129 = Rsh_d1[129] ^ Bn1[129];
wire g0_129, g1_129, t0_129, t1_129;
MSKand_opini2_d2 u_g_129 (
    .ina({Rsh_d1[129], Rsh_d0[129]}), .inb({Bn1[129], Bn0[129]}),
    .rnd(r[258]), .s(s[258]), .clk(clk), .out({g1_129, g0_129}));
MSKand_opini2_d2 u_t_129 (
    .ina({fc1[129], fc0[129]}), .inb({p1_129, p0_129}),
    .rnd(r[259]), .s(s[259]), .clk(clk), .out({t1_129, t0_129}));
assign fc0[130] = g0_129 ^ t0_129;
assign fc1[130] = g1_129 ^ t1_129;
wire p0_130 = Rsh_d0[130] ^ Bn0[130];
wire p1_130 = Rsh_d1[130] ^ Bn1[130];
wire g0_130, g1_130, t0_130, t1_130;
MSKand_opini2_d2 u_g_130 (
    .ina({Rsh_d1[130], Rsh_d0[130]}), .inb({Bn1[130], Bn0[130]}),
    .rnd(r[260]), .s(s[260]), .clk(clk), .out({g1_130, g0_130}));
MSKand_opini2_d2 u_t_130 (
    .ina({fc1[130], fc0[130]}), .inb({p1_130, p0_130}),
    .rnd(r[261]), .s(s[261]), .clk(clk), .out({t1_130, t0_130}));
assign fc0[131] = g0_130 ^ t0_130;
assign fc1[131] = g1_130 ^ t1_130;
wire p0_131 = Rsh_d0[131] ^ Bn0[131];
wire p1_131 = Rsh_d1[131] ^ Bn1[131];
wire g0_131, g1_131, t0_131, t1_131;
MSKand_opini2_d2 u_g_131 (
    .ina({Rsh_d1[131], Rsh_d0[131]}), .inb({Bn1[131], Bn0[131]}),
    .rnd(r[262]), .s(s[262]), .clk(clk), .out({g1_131, g0_131}));
MSKand_opini2_d2 u_t_131 (
    .ina({fc1[131], fc0[131]}), .inb({p1_131, p0_131}),
    .rnd(r[263]), .s(s[263]), .clk(clk), .out({t1_131, t0_131}));
assign fc0[132] = g0_131 ^ t0_131;
assign fc1[132] = g1_131 ^ t1_131;
wire p0_132 = Rsh_d0[132] ^ Bn0[132];
wire p1_132 = Rsh_d1[132] ^ Bn1[132];
wire g0_132, g1_132, t0_132, t1_132;
MSKand_opini2_d2 u_g_132 (
    .ina({Rsh_d1[132], Rsh_d0[132]}), .inb({Bn1[132], Bn0[132]}),
    .rnd(r[264]), .s(s[264]), .clk(clk), .out({g1_132, g0_132}));
MSKand_opini2_d2 u_t_132 (
    .ina({fc1[132], fc0[132]}), .inb({p1_132, p0_132}),
    .rnd(r[265]), .s(s[265]), .clk(clk), .out({t1_132, t0_132}));
assign fc0[133] = g0_132 ^ t0_132;
assign fc1[133] = g1_132 ^ t1_132;
wire p0_133 = Rsh_d0[133] ^ Bn0[133];
wire p1_133 = Rsh_d1[133] ^ Bn1[133];
wire g0_133, g1_133, t0_133, t1_133;
MSKand_opini2_d2 u_g_133 (
    .ina({Rsh_d1[133], Rsh_d0[133]}), .inb({Bn1[133], Bn0[133]}),
    .rnd(r[266]), .s(s[266]), .clk(clk), .out({g1_133, g0_133}));
MSKand_opini2_d2 u_t_133 (
    .ina({fc1[133], fc0[133]}), .inb({p1_133, p0_133}),
    .rnd(r[267]), .s(s[267]), .clk(clk), .out({t1_133, t0_133}));
assign fc0[134] = g0_133 ^ t0_133;
assign fc1[134] = g1_133 ^ t1_133;
wire p0_134 = Rsh_d0[134] ^ Bn0[134];
wire p1_134 = Rsh_d1[134] ^ Bn1[134];
wire g0_134, g1_134, t0_134, t1_134;
MSKand_opini2_d2 u_g_134 (
    .ina({Rsh_d1[134], Rsh_d0[134]}), .inb({Bn1[134], Bn0[134]}),
    .rnd(r[268]), .s(s[268]), .clk(clk), .out({g1_134, g0_134}));
MSKand_opini2_d2 u_t_134 (
    .ina({fc1[134], fc0[134]}), .inb({p1_134, p0_134}),
    .rnd(r[269]), .s(s[269]), .clk(clk), .out({t1_134, t0_134}));
assign fc0[135] = g0_134 ^ t0_134;
assign fc1[135] = g1_134 ^ t1_134;
wire p0_135 = Rsh_d0[135] ^ Bn0[135];
wire p1_135 = Rsh_d1[135] ^ Bn1[135];
wire g0_135, g1_135, t0_135, t1_135;
MSKand_opini2_d2 u_g_135 (
    .ina({Rsh_d1[135], Rsh_d0[135]}), .inb({Bn1[135], Bn0[135]}),
    .rnd(r[270]), .s(s[270]), .clk(clk), .out({g1_135, g0_135}));
MSKand_opini2_d2 u_t_135 (
    .ina({fc1[135], fc0[135]}), .inb({p1_135, p0_135}),
    .rnd(r[271]), .s(s[271]), .clk(clk), .out({t1_135, t0_135}));
assign fc0[136] = g0_135 ^ t0_135;
assign fc1[136] = g1_135 ^ t1_135;
wire p0_136 = Rsh_d0[136] ^ Bn0[136];
wire p1_136 = Rsh_d1[136] ^ Bn1[136];
wire g0_136, g1_136, t0_136, t1_136;
MSKand_opini2_d2 u_g_136 (
    .ina({Rsh_d1[136], Rsh_d0[136]}), .inb({Bn1[136], Bn0[136]}),
    .rnd(r[272]), .s(s[272]), .clk(clk), .out({g1_136, g0_136}));
MSKand_opini2_d2 u_t_136 (
    .ina({fc1[136], fc0[136]}), .inb({p1_136, p0_136}),
    .rnd(r[273]), .s(s[273]), .clk(clk), .out({t1_136, t0_136}));
assign fc0[137] = g0_136 ^ t0_136;
assign fc1[137] = g1_136 ^ t1_136;
wire p0_137 = Rsh_d0[137] ^ Bn0[137];
wire p1_137 = Rsh_d1[137] ^ Bn1[137];
wire g0_137, g1_137, t0_137, t1_137;
MSKand_opini2_d2 u_g_137 (
    .ina({Rsh_d1[137], Rsh_d0[137]}), .inb({Bn1[137], Bn0[137]}),
    .rnd(r[274]), .s(s[274]), .clk(clk), .out({g1_137, g0_137}));
MSKand_opini2_d2 u_t_137 (
    .ina({fc1[137], fc0[137]}), .inb({p1_137, p0_137}),
    .rnd(r[275]), .s(s[275]), .clk(clk), .out({t1_137, t0_137}));
assign fc0[138] = g0_137 ^ t0_137;
assign fc1[138] = g1_137 ^ t1_137;
wire p0_138 = Rsh_d0[138] ^ Bn0[138];
wire p1_138 = Rsh_d1[138] ^ Bn1[138];
wire g0_138, g1_138, t0_138, t1_138;
MSKand_opini2_d2 u_g_138 (
    .ina({Rsh_d1[138], Rsh_d0[138]}), .inb({Bn1[138], Bn0[138]}),
    .rnd(r[276]), .s(s[276]), .clk(clk), .out({g1_138, g0_138}));
MSKand_opini2_d2 u_t_138 (
    .ina({fc1[138], fc0[138]}), .inb({p1_138, p0_138}),
    .rnd(r[277]), .s(s[277]), .clk(clk), .out({t1_138, t0_138}));
assign fc0[139] = g0_138 ^ t0_138;
assign fc1[139] = g1_138 ^ t1_138;
wire p0_139 = Rsh_d0[139] ^ Bn0[139];
wire p1_139 = Rsh_d1[139] ^ Bn1[139];
wire g0_139, g1_139, t0_139, t1_139;
MSKand_opini2_d2 u_g_139 (
    .ina({Rsh_d1[139], Rsh_d0[139]}), .inb({Bn1[139], Bn0[139]}),
    .rnd(r[278]), .s(s[278]), .clk(clk), .out({g1_139, g0_139}));
MSKand_opini2_d2 u_t_139 (
    .ina({fc1[139], fc0[139]}), .inb({p1_139, p0_139}),
    .rnd(r[279]), .s(s[279]), .clk(clk), .out({t1_139, t0_139}));
assign fc0[140] = g0_139 ^ t0_139;
assign fc1[140] = g1_139 ^ t1_139;
wire p0_140 = Rsh_d0[140] ^ Bn0[140];
wire p1_140 = Rsh_d1[140] ^ Bn1[140];
wire g0_140, g1_140, t0_140, t1_140;
MSKand_opini2_d2 u_g_140 (
    .ina({Rsh_d1[140], Rsh_d0[140]}), .inb({Bn1[140], Bn0[140]}),
    .rnd(r[280]), .s(s[280]), .clk(clk), .out({g1_140, g0_140}));
MSKand_opini2_d2 u_t_140 (
    .ina({fc1[140], fc0[140]}), .inb({p1_140, p0_140}),
    .rnd(r[281]), .s(s[281]), .clk(clk), .out({t1_140, t0_140}));
assign fc0[141] = g0_140 ^ t0_140;
assign fc1[141] = g1_140 ^ t1_140;
wire p0_141 = Rsh_d0[141] ^ Bn0[141];
wire p1_141 = Rsh_d1[141] ^ Bn1[141];
wire g0_141, g1_141, t0_141, t1_141;
MSKand_opini2_d2 u_g_141 (
    .ina({Rsh_d1[141], Rsh_d0[141]}), .inb({Bn1[141], Bn0[141]}),
    .rnd(r[282]), .s(s[282]), .clk(clk), .out({g1_141, g0_141}));
MSKand_opini2_d2 u_t_141 (
    .ina({fc1[141], fc0[141]}), .inb({p1_141, p0_141}),
    .rnd(r[283]), .s(s[283]), .clk(clk), .out({t1_141, t0_141}));
assign fc0[142] = g0_141 ^ t0_141;
assign fc1[142] = g1_141 ^ t1_141;
wire p0_142 = Rsh_d0[142] ^ Bn0[142];
wire p1_142 = Rsh_d1[142] ^ Bn1[142];
wire g0_142, g1_142, t0_142, t1_142;
MSKand_opini2_d2 u_g_142 (
    .ina({Rsh_d1[142], Rsh_d0[142]}), .inb({Bn1[142], Bn0[142]}),
    .rnd(r[284]), .s(s[284]), .clk(clk), .out({g1_142, g0_142}));
MSKand_opini2_d2 u_t_142 (
    .ina({fc1[142], fc0[142]}), .inb({p1_142, p0_142}),
    .rnd(r[285]), .s(s[285]), .clk(clk), .out({t1_142, t0_142}));
assign fc0[143] = g0_142 ^ t0_142;
assign fc1[143] = g1_142 ^ t1_142;
wire p0_143 = Rsh_d0[143] ^ Bn0[143];
wire p1_143 = Rsh_d1[143] ^ Bn1[143];
wire g0_143, g1_143, t0_143, t1_143;
MSKand_opini2_d2 u_g_143 (
    .ina({Rsh_d1[143], Rsh_d0[143]}), .inb({Bn1[143], Bn0[143]}),
    .rnd(r[286]), .s(s[286]), .clk(clk), .out({g1_143, g0_143}));
MSKand_opini2_d2 u_t_143 (
    .ina({fc1[143], fc0[143]}), .inb({p1_143, p0_143}),
    .rnd(r[287]), .s(s[287]), .clk(clk), .out({t1_143, t0_143}));
assign fc0[144] = g0_143 ^ t0_143;
assign fc1[144] = g1_143 ^ t1_143;
wire p0_144 = Rsh_d0[144] ^ Bn0[144];
wire p1_144 = Rsh_d1[144] ^ Bn1[144];
wire g0_144, g1_144, t0_144, t1_144;
MSKand_opini2_d2 u_g_144 (
    .ina({Rsh_d1[144], Rsh_d0[144]}), .inb({Bn1[144], Bn0[144]}),
    .rnd(r[288]), .s(s[288]), .clk(clk), .out({g1_144, g0_144}));
MSKand_opini2_d2 u_t_144 (
    .ina({fc1[144], fc0[144]}), .inb({p1_144, p0_144}),
    .rnd(r[289]), .s(s[289]), .clk(clk), .out({t1_144, t0_144}));
assign fc0[145] = g0_144 ^ t0_144;
assign fc1[145] = g1_144 ^ t1_144;
wire p0_145 = Rsh_d0[145] ^ Bn0[145];
wire p1_145 = Rsh_d1[145] ^ Bn1[145];
wire g0_145, g1_145, t0_145, t1_145;
MSKand_opini2_d2 u_g_145 (
    .ina({Rsh_d1[145], Rsh_d0[145]}), .inb({Bn1[145], Bn0[145]}),
    .rnd(r[290]), .s(s[290]), .clk(clk), .out({g1_145, g0_145}));
MSKand_opini2_d2 u_t_145 (
    .ina({fc1[145], fc0[145]}), .inb({p1_145, p0_145}),
    .rnd(r[291]), .s(s[291]), .clk(clk), .out({t1_145, t0_145}));
assign fc0[146] = g0_145 ^ t0_145;
assign fc1[146] = g1_145 ^ t1_145;
wire p0_146 = Rsh_d0[146] ^ Bn0[146];
wire p1_146 = Rsh_d1[146] ^ Bn1[146];
wire g0_146, g1_146, t0_146, t1_146;
MSKand_opini2_d2 u_g_146 (
    .ina({Rsh_d1[146], Rsh_d0[146]}), .inb({Bn1[146], Bn0[146]}),
    .rnd(r[292]), .s(s[292]), .clk(clk), .out({g1_146, g0_146}));
MSKand_opini2_d2 u_t_146 (
    .ina({fc1[146], fc0[146]}), .inb({p1_146, p0_146}),
    .rnd(r[293]), .s(s[293]), .clk(clk), .out({t1_146, t0_146}));
assign fc0[147] = g0_146 ^ t0_146;
assign fc1[147] = g1_146 ^ t1_146;
wire p0_147 = Rsh_d0[147] ^ Bn0[147];
wire p1_147 = Rsh_d1[147] ^ Bn1[147];
wire g0_147, g1_147, t0_147, t1_147;
MSKand_opini2_d2 u_g_147 (
    .ina({Rsh_d1[147], Rsh_d0[147]}), .inb({Bn1[147], Bn0[147]}),
    .rnd(r[294]), .s(s[294]), .clk(clk), .out({g1_147, g0_147}));
MSKand_opini2_d2 u_t_147 (
    .ina({fc1[147], fc0[147]}), .inb({p1_147, p0_147}),
    .rnd(r[295]), .s(s[295]), .clk(clk), .out({t1_147, t0_147}));
assign fc0[148] = g0_147 ^ t0_147;
assign fc1[148] = g1_147 ^ t1_147;
wire p0_148 = Rsh_d0[148] ^ Bn0[148];
wire p1_148 = Rsh_d1[148] ^ Bn1[148];
wire g0_148, g1_148, t0_148, t1_148;
MSKand_opini2_d2 u_g_148 (
    .ina({Rsh_d1[148], Rsh_d0[148]}), .inb({Bn1[148], Bn0[148]}),
    .rnd(r[296]), .s(s[296]), .clk(clk), .out({g1_148, g0_148}));
MSKand_opini2_d2 u_t_148 (
    .ina({fc1[148], fc0[148]}), .inb({p1_148, p0_148}),
    .rnd(r[297]), .s(s[297]), .clk(clk), .out({t1_148, t0_148}));
assign fc0[149] = g0_148 ^ t0_148;
assign fc1[149] = g1_148 ^ t1_148;
wire p0_149 = Rsh_d0[149] ^ Bn0[149];
wire p1_149 = Rsh_d1[149] ^ Bn1[149];
wire g0_149, g1_149, t0_149, t1_149;
MSKand_opini2_d2 u_g_149 (
    .ina({Rsh_d1[149], Rsh_d0[149]}), .inb({Bn1[149], Bn0[149]}),
    .rnd(r[298]), .s(s[298]), .clk(clk), .out({g1_149, g0_149}));
MSKand_opini2_d2 u_t_149 (
    .ina({fc1[149], fc0[149]}), .inb({p1_149, p0_149}),
    .rnd(r[299]), .s(s[299]), .clk(clk), .out({t1_149, t0_149}));
assign fc0[150] = g0_149 ^ t0_149;
assign fc1[150] = g1_149 ^ t1_149;
wire p0_150 = Rsh_d0[150] ^ Bn0[150];
wire p1_150 = Rsh_d1[150] ^ Bn1[150];
wire g0_150, g1_150, t0_150, t1_150;
MSKand_opini2_d2 u_g_150 (
    .ina({Rsh_d1[150], Rsh_d0[150]}), .inb({Bn1[150], Bn0[150]}),
    .rnd(r[300]), .s(s[300]), .clk(clk), .out({g1_150, g0_150}));
MSKand_opini2_d2 u_t_150 (
    .ina({fc1[150], fc0[150]}), .inb({p1_150, p0_150}),
    .rnd(r[301]), .s(s[301]), .clk(clk), .out({t1_150, t0_150}));
assign fc0[151] = g0_150 ^ t0_150;
assign fc1[151] = g1_150 ^ t1_150;
wire p0_151 = Rsh_d0[151] ^ Bn0[151];
wire p1_151 = Rsh_d1[151] ^ Bn1[151];
wire g0_151, g1_151, t0_151, t1_151;
MSKand_opini2_d2 u_g_151 (
    .ina({Rsh_d1[151], Rsh_d0[151]}), .inb({Bn1[151], Bn0[151]}),
    .rnd(r[302]), .s(s[302]), .clk(clk), .out({g1_151, g0_151}));
MSKand_opini2_d2 u_t_151 (
    .ina({fc1[151], fc0[151]}), .inb({p1_151, p0_151}),
    .rnd(r[303]), .s(s[303]), .clk(clk), .out({t1_151, t0_151}));
assign fc0[152] = g0_151 ^ t0_151;
assign fc1[152] = g1_151 ^ t1_151;
wire p0_152 = Rsh_d0[152] ^ Bn0[152];
wire p1_152 = Rsh_d1[152] ^ Bn1[152];
wire g0_152, g1_152, t0_152, t1_152;
MSKand_opini2_d2 u_g_152 (
    .ina({Rsh_d1[152], Rsh_d0[152]}), .inb({Bn1[152], Bn0[152]}),
    .rnd(r[304]), .s(s[304]), .clk(clk), .out({g1_152, g0_152}));
MSKand_opini2_d2 u_t_152 (
    .ina({fc1[152], fc0[152]}), .inb({p1_152, p0_152}),
    .rnd(r[305]), .s(s[305]), .clk(clk), .out({t1_152, t0_152}));
assign fc0[153] = g0_152 ^ t0_152;
assign fc1[153] = g1_152 ^ t1_152;
wire p0_153 = Rsh_d0[153] ^ Bn0[153];
wire p1_153 = Rsh_d1[153] ^ Bn1[153];
wire g0_153, g1_153, t0_153, t1_153;
MSKand_opini2_d2 u_g_153 (
    .ina({Rsh_d1[153], Rsh_d0[153]}), .inb({Bn1[153], Bn0[153]}),
    .rnd(r[306]), .s(s[306]), .clk(clk), .out({g1_153, g0_153}));
MSKand_opini2_d2 u_t_153 (
    .ina({fc1[153], fc0[153]}), .inb({p1_153, p0_153}),
    .rnd(r[307]), .s(s[307]), .clk(clk), .out({t1_153, t0_153}));
assign fc0[154] = g0_153 ^ t0_153;
assign fc1[154] = g1_153 ^ t1_153;
wire p0_154 = Rsh_d0[154] ^ Bn0[154];
wire p1_154 = Rsh_d1[154] ^ Bn1[154];
wire g0_154, g1_154, t0_154, t1_154;
MSKand_opini2_d2 u_g_154 (
    .ina({Rsh_d1[154], Rsh_d0[154]}), .inb({Bn1[154], Bn0[154]}),
    .rnd(r[308]), .s(s[308]), .clk(clk), .out({g1_154, g0_154}));
MSKand_opini2_d2 u_t_154 (
    .ina({fc1[154], fc0[154]}), .inb({p1_154, p0_154}),
    .rnd(r[309]), .s(s[309]), .clk(clk), .out({t1_154, t0_154}));
assign fc0[155] = g0_154 ^ t0_154;
assign fc1[155] = g1_154 ^ t1_154;
wire p0_155 = Rsh_d0[155] ^ Bn0[155];
wire p1_155 = Rsh_d1[155] ^ Bn1[155];
wire g0_155, g1_155, t0_155, t1_155;
MSKand_opini2_d2 u_g_155 (
    .ina({Rsh_d1[155], Rsh_d0[155]}), .inb({Bn1[155], Bn0[155]}),
    .rnd(r[310]), .s(s[310]), .clk(clk), .out({g1_155, g0_155}));
MSKand_opini2_d2 u_t_155 (
    .ina({fc1[155], fc0[155]}), .inb({p1_155, p0_155}),
    .rnd(r[311]), .s(s[311]), .clk(clk), .out({t1_155, t0_155}));
assign fc0[156] = g0_155 ^ t0_155;
assign fc1[156] = g1_155 ^ t1_155;
wire p0_156 = Rsh_d0[156] ^ Bn0[156];
wire p1_156 = Rsh_d1[156] ^ Bn1[156];
wire g0_156, g1_156, t0_156, t1_156;
MSKand_opini2_d2 u_g_156 (
    .ina({Rsh_d1[156], Rsh_d0[156]}), .inb({Bn1[156], Bn0[156]}),
    .rnd(r[312]), .s(s[312]), .clk(clk), .out({g1_156, g0_156}));
MSKand_opini2_d2 u_t_156 (
    .ina({fc1[156], fc0[156]}), .inb({p1_156, p0_156}),
    .rnd(r[313]), .s(s[313]), .clk(clk), .out({t1_156, t0_156}));
assign fc0[157] = g0_156 ^ t0_156;
assign fc1[157] = g1_156 ^ t1_156;
wire p0_157 = Rsh_d0[157] ^ Bn0[157];
wire p1_157 = Rsh_d1[157] ^ Bn1[157];
wire g0_157, g1_157, t0_157, t1_157;
MSKand_opini2_d2 u_g_157 (
    .ina({Rsh_d1[157], Rsh_d0[157]}), .inb({Bn1[157], Bn0[157]}),
    .rnd(r[314]), .s(s[314]), .clk(clk), .out({g1_157, g0_157}));
MSKand_opini2_d2 u_t_157 (
    .ina({fc1[157], fc0[157]}), .inb({p1_157, p0_157}),
    .rnd(r[315]), .s(s[315]), .clk(clk), .out({t1_157, t0_157}));
assign fc0[158] = g0_157 ^ t0_157;
assign fc1[158] = g1_157 ^ t1_157;
wire p0_158 = Rsh_d0[158] ^ Bn0[158];
wire p1_158 = Rsh_d1[158] ^ Bn1[158];
wire g0_158, g1_158, t0_158, t1_158;
MSKand_opini2_d2 u_g_158 (
    .ina({Rsh_d1[158], Rsh_d0[158]}), .inb({Bn1[158], Bn0[158]}),
    .rnd(r[316]), .s(s[316]), .clk(clk), .out({g1_158, g0_158}));
MSKand_opini2_d2 u_t_158 (
    .ina({fc1[158], fc0[158]}), .inb({p1_158, p0_158}),
    .rnd(r[317]), .s(s[317]), .clk(clk), .out({t1_158, t0_158}));
assign fc0[159] = g0_158 ^ t0_158;
assign fc1[159] = g1_158 ^ t1_158;
wire p0_159 = Rsh_d0[159] ^ Bn0[159];
wire p1_159 = Rsh_d1[159] ^ Bn1[159];
wire g0_159, g1_159, t0_159, t1_159;
MSKand_opini2_d2 u_g_159 (
    .ina({Rsh_d1[159], Rsh_d0[159]}), .inb({Bn1[159], Bn0[159]}),
    .rnd(r[318]), .s(s[318]), .clk(clk), .out({g1_159, g0_159}));
MSKand_opini2_d2 u_t_159 (
    .ina({fc1[159], fc0[159]}), .inb({p1_159, p0_159}),
    .rnd(r[319]), .s(s[319]), .clk(clk), .out({t1_159, t0_159}));
assign fc0[160] = g0_159 ^ t0_159;
assign fc1[160] = g1_159 ^ t1_159;
wire p0_160 = Rsh_d0[160] ^ Bn0[160];
wire p1_160 = Rsh_d1[160] ^ Bn1[160];
wire g0_160, g1_160, t0_160, t1_160;
MSKand_opini2_d2 u_g_160 (
    .ina({Rsh_d1[160], Rsh_d0[160]}), .inb({Bn1[160], Bn0[160]}),
    .rnd(r[320]), .s(s[320]), .clk(clk), .out({g1_160, g0_160}));
MSKand_opini2_d2 u_t_160 (
    .ina({fc1[160], fc0[160]}), .inb({p1_160, p0_160}),
    .rnd(r[321]), .s(s[321]), .clk(clk), .out({t1_160, t0_160}));
assign fc0[161] = g0_160 ^ t0_160;
assign fc1[161] = g1_160 ^ t1_160;
wire p0_161 = Rsh_d0[161] ^ Bn0[161];
wire p1_161 = Rsh_d1[161] ^ Bn1[161];
wire g0_161, g1_161, t0_161, t1_161;
MSKand_opini2_d2 u_g_161 (
    .ina({Rsh_d1[161], Rsh_d0[161]}), .inb({Bn1[161], Bn0[161]}),
    .rnd(r[322]), .s(s[322]), .clk(clk), .out({g1_161, g0_161}));
MSKand_opini2_d2 u_t_161 (
    .ina({fc1[161], fc0[161]}), .inb({p1_161, p0_161}),
    .rnd(r[323]), .s(s[323]), .clk(clk), .out({t1_161, t0_161}));
assign fc0[162] = g0_161 ^ t0_161;
assign fc1[162] = g1_161 ^ t1_161;
wire p0_162 = Rsh_d0[162] ^ Bn0[162];
wire p1_162 = Rsh_d1[162] ^ Bn1[162];
wire g0_162, g1_162, t0_162, t1_162;
MSKand_opini2_d2 u_g_162 (
    .ina({Rsh_d1[162], Rsh_d0[162]}), .inb({Bn1[162], Bn0[162]}),
    .rnd(r[324]), .s(s[324]), .clk(clk), .out({g1_162, g0_162}));
MSKand_opini2_d2 u_t_162 (
    .ina({fc1[162], fc0[162]}), .inb({p1_162, p0_162}),
    .rnd(r[325]), .s(s[325]), .clk(clk), .out({t1_162, t0_162}));
assign fc0[163] = g0_162 ^ t0_162;
assign fc1[163] = g1_162 ^ t1_162;
wire p0_163 = Rsh_d0[163] ^ Bn0[163];
wire p1_163 = Rsh_d1[163] ^ Bn1[163];
wire g0_163, g1_163, t0_163, t1_163;
MSKand_opini2_d2 u_g_163 (
    .ina({Rsh_d1[163], Rsh_d0[163]}), .inb({Bn1[163], Bn0[163]}),
    .rnd(r[326]), .s(s[326]), .clk(clk), .out({g1_163, g0_163}));
MSKand_opini2_d2 u_t_163 (
    .ina({fc1[163], fc0[163]}), .inb({p1_163, p0_163}),
    .rnd(r[327]), .s(s[327]), .clk(clk), .out({t1_163, t0_163}));
assign fc0[164] = g0_163 ^ t0_163;
assign fc1[164] = g1_163 ^ t1_163;
wire p0_164 = Rsh_d0[164] ^ Bn0[164];
wire p1_164 = Rsh_d1[164] ^ Bn1[164];
wire g0_164, g1_164, t0_164, t1_164;
MSKand_opini2_d2 u_g_164 (
    .ina({Rsh_d1[164], Rsh_d0[164]}), .inb({Bn1[164], Bn0[164]}),
    .rnd(r[328]), .s(s[328]), .clk(clk), .out({g1_164, g0_164}));
MSKand_opini2_d2 u_t_164 (
    .ina({fc1[164], fc0[164]}), .inb({p1_164, p0_164}),
    .rnd(r[329]), .s(s[329]), .clk(clk), .out({t1_164, t0_164}));
assign fc0[165] = g0_164 ^ t0_164;
assign fc1[165] = g1_164 ^ t1_164;
wire p0_165 = Rsh_d0[165] ^ Bn0[165];
wire p1_165 = Rsh_d1[165] ^ Bn1[165];
wire g0_165, g1_165, t0_165, t1_165;
MSKand_opini2_d2 u_g_165 (
    .ina({Rsh_d1[165], Rsh_d0[165]}), .inb({Bn1[165], Bn0[165]}),
    .rnd(r[330]), .s(s[330]), .clk(clk), .out({g1_165, g0_165}));
MSKand_opini2_d2 u_t_165 (
    .ina({fc1[165], fc0[165]}), .inb({p1_165, p0_165}),
    .rnd(r[331]), .s(s[331]), .clk(clk), .out({t1_165, t0_165}));
assign fc0[166] = g0_165 ^ t0_165;
assign fc1[166] = g1_165 ^ t1_165;
wire p0_166 = Rsh_d0[166] ^ Bn0[166];
wire p1_166 = Rsh_d1[166] ^ Bn1[166];
wire g0_166, g1_166, t0_166, t1_166;
MSKand_opini2_d2 u_g_166 (
    .ina({Rsh_d1[166], Rsh_d0[166]}), .inb({Bn1[166], Bn0[166]}),
    .rnd(r[332]), .s(s[332]), .clk(clk), .out({g1_166, g0_166}));
MSKand_opini2_d2 u_t_166 (
    .ina({fc1[166], fc0[166]}), .inb({p1_166, p0_166}),
    .rnd(r[333]), .s(s[333]), .clk(clk), .out({t1_166, t0_166}));
assign fc0[167] = g0_166 ^ t0_166;
assign fc1[167] = g1_166 ^ t1_166;
wire p0_167 = Rsh_d0[167] ^ Bn0[167];
wire p1_167 = Rsh_d1[167] ^ Bn1[167];
wire g0_167, g1_167, t0_167, t1_167;
MSKand_opini2_d2 u_g_167 (
    .ina({Rsh_d1[167], Rsh_d0[167]}), .inb({Bn1[167], Bn0[167]}),
    .rnd(r[334]), .s(s[334]), .clk(clk), .out({g1_167, g0_167}));
MSKand_opini2_d2 u_t_167 (
    .ina({fc1[167], fc0[167]}), .inb({p1_167, p0_167}),
    .rnd(r[335]), .s(s[335]), .clk(clk), .out({t1_167, t0_167}));
assign fc0[168] = g0_167 ^ t0_167;
assign fc1[168] = g1_167 ^ t1_167;
wire p0_168 = Rsh_d0[168] ^ Bn0[168];
wire p1_168 = Rsh_d1[168] ^ Bn1[168];
wire g0_168, g1_168, t0_168, t1_168;
MSKand_opini2_d2 u_g_168 (
    .ina({Rsh_d1[168], Rsh_d0[168]}), .inb({Bn1[168], Bn0[168]}),
    .rnd(r[336]), .s(s[336]), .clk(clk), .out({g1_168, g0_168}));
MSKand_opini2_d2 u_t_168 (
    .ina({fc1[168], fc0[168]}), .inb({p1_168, p0_168}),
    .rnd(r[337]), .s(s[337]), .clk(clk), .out({t1_168, t0_168}));
assign fc0[169] = g0_168 ^ t0_168;
assign fc1[169] = g1_168 ^ t1_168;
wire p0_169 = Rsh_d0[169] ^ Bn0[169];
wire p1_169 = Rsh_d1[169] ^ Bn1[169];
wire g0_169, g1_169, t0_169, t1_169;
MSKand_opini2_d2 u_g_169 (
    .ina({Rsh_d1[169], Rsh_d0[169]}), .inb({Bn1[169], Bn0[169]}),
    .rnd(r[338]), .s(s[338]), .clk(clk), .out({g1_169, g0_169}));
MSKand_opini2_d2 u_t_169 (
    .ina({fc1[169], fc0[169]}), .inb({p1_169, p0_169}),
    .rnd(r[339]), .s(s[339]), .clk(clk), .out({t1_169, t0_169}));
assign fc0[170] = g0_169 ^ t0_169;
assign fc1[170] = g1_169 ^ t1_169;
wire p0_170 = Rsh_d0[170] ^ Bn0[170];
wire p1_170 = Rsh_d1[170] ^ Bn1[170];
wire g0_170, g1_170, t0_170, t1_170;
MSKand_opini2_d2 u_g_170 (
    .ina({Rsh_d1[170], Rsh_d0[170]}), .inb({Bn1[170], Bn0[170]}),
    .rnd(r[340]), .s(s[340]), .clk(clk), .out({g1_170, g0_170}));
MSKand_opini2_d2 u_t_170 (
    .ina({fc1[170], fc0[170]}), .inb({p1_170, p0_170}),
    .rnd(r[341]), .s(s[341]), .clk(clk), .out({t1_170, t0_170}));
assign fc0[171] = g0_170 ^ t0_170;
assign fc1[171] = g1_170 ^ t1_170;
wire p0_171 = Rsh_d0[171] ^ Bn0[171];
wire p1_171 = Rsh_d1[171] ^ Bn1[171];
wire g0_171, g1_171, t0_171, t1_171;
MSKand_opini2_d2 u_g_171 (
    .ina({Rsh_d1[171], Rsh_d0[171]}), .inb({Bn1[171], Bn0[171]}),
    .rnd(r[342]), .s(s[342]), .clk(clk), .out({g1_171, g0_171}));
MSKand_opini2_d2 u_t_171 (
    .ina({fc1[171], fc0[171]}), .inb({p1_171, p0_171}),
    .rnd(r[343]), .s(s[343]), .clk(clk), .out({t1_171, t0_171}));
assign fc0[172] = g0_171 ^ t0_171;
assign fc1[172] = g1_171 ^ t1_171;
wire p0_172 = Rsh_d0[172] ^ Bn0[172];
wire p1_172 = Rsh_d1[172] ^ Bn1[172];
wire g0_172, g1_172, t0_172, t1_172;
MSKand_opini2_d2 u_g_172 (
    .ina({Rsh_d1[172], Rsh_d0[172]}), .inb({Bn1[172], Bn0[172]}),
    .rnd(r[344]), .s(s[344]), .clk(clk), .out({g1_172, g0_172}));
MSKand_opini2_d2 u_t_172 (
    .ina({fc1[172], fc0[172]}), .inb({p1_172, p0_172}),
    .rnd(r[345]), .s(s[345]), .clk(clk), .out({t1_172, t0_172}));
assign fc0[173] = g0_172 ^ t0_172;
assign fc1[173] = g1_172 ^ t1_172;
wire p0_173 = Rsh_d0[173] ^ Bn0[173];
wire p1_173 = Rsh_d1[173] ^ Bn1[173];
wire g0_173, g1_173, t0_173, t1_173;
MSKand_opini2_d2 u_g_173 (
    .ina({Rsh_d1[173], Rsh_d0[173]}), .inb({Bn1[173], Bn0[173]}),
    .rnd(r[346]), .s(s[346]), .clk(clk), .out({g1_173, g0_173}));
MSKand_opini2_d2 u_t_173 (
    .ina({fc1[173], fc0[173]}), .inb({p1_173, p0_173}),
    .rnd(r[347]), .s(s[347]), .clk(clk), .out({t1_173, t0_173}));
assign fc0[174] = g0_173 ^ t0_173;
assign fc1[174] = g1_173 ^ t1_173;
wire p0_174 = Rsh_d0[174] ^ Bn0[174];
wire p1_174 = Rsh_d1[174] ^ Bn1[174];
wire g0_174, g1_174, t0_174, t1_174;
MSKand_opini2_d2 u_g_174 (
    .ina({Rsh_d1[174], Rsh_d0[174]}), .inb({Bn1[174], Bn0[174]}),
    .rnd(r[348]), .s(s[348]), .clk(clk), .out({g1_174, g0_174}));
MSKand_opini2_d2 u_t_174 (
    .ina({fc1[174], fc0[174]}), .inb({p1_174, p0_174}),
    .rnd(r[349]), .s(s[349]), .clk(clk), .out({t1_174, t0_174}));
assign fc0[175] = g0_174 ^ t0_174;
assign fc1[175] = g1_174 ^ t1_174;
wire p0_175 = Rsh_d0[175] ^ Bn0[175];
wire p1_175 = Rsh_d1[175] ^ Bn1[175];
wire g0_175, g1_175, t0_175, t1_175;
MSKand_opini2_d2 u_g_175 (
    .ina({Rsh_d1[175], Rsh_d0[175]}), .inb({Bn1[175], Bn0[175]}),
    .rnd(r[350]), .s(s[350]), .clk(clk), .out({g1_175, g0_175}));
MSKand_opini2_d2 u_t_175 (
    .ina({fc1[175], fc0[175]}), .inb({p1_175, p0_175}),
    .rnd(r[351]), .s(s[351]), .clk(clk), .out({t1_175, t0_175}));
assign fc0[176] = g0_175 ^ t0_175;
assign fc1[176] = g1_175 ^ t1_175;
wire p0_176 = Rsh_d0[176] ^ Bn0[176];
wire p1_176 = Rsh_d1[176] ^ Bn1[176];
wire g0_176, g1_176, t0_176, t1_176;
MSKand_opini2_d2 u_g_176 (
    .ina({Rsh_d1[176], Rsh_d0[176]}), .inb({Bn1[176], Bn0[176]}),
    .rnd(r[352]), .s(s[352]), .clk(clk), .out({g1_176, g0_176}));
MSKand_opini2_d2 u_t_176 (
    .ina({fc1[176], fc0[176]}), .inb({p1_176, p0_176}),
    .rnd(r[353]), .s(s[353]), .clk(clk), .out({t1_176, t0_176}));
assign fc0[177] = g0_176 ^ t0_176;
assign fc1[177] = g1_176 ^ t1_176;
wire p0_177 = Rsh_d0[177] ^ Bn0[177];
wire p1_177 = Rsh_d1[177] ^ Bn1[177];
wire g0_177, g1_177, t0_177, t1_177;
MSKand_opini2_d2 u_g_177 (
    .ina({Rsh_d1[177], Rsh_d0[177]}), .inb({Bn1[177], Bn0[177]}),
    .rnd(r[354]), .s(s[354]), .clk(clk), .out({g1_177, g0_177}));
MSKand_opini2_d2 u_t_177 (
    .ina({fc1[177], fc0[177]}), .inb({p1_177, p0_177}),
    .rnd(r[355]), .s(s[355]), .clk(clk), .out({t1_177, t0_177}));
assign fc0[178] = g0_177 ^ t0_177;
assign fc1[178] = g1_177 ^ t1_177;
wire p0_178 = Rsh_d0[178] ^ Bn0[178];
wire p1_178 = Rsh_d1[178] ^ Bn1[178];
wire g0_178, g1_178, t0_178, t1_178;
MSKand_opini2_d2 u_g_178 (
    .ina({Rsh_d1[178], Rsh_d0[178]}), .inb({Bn1[178], Bn0[178]}),
    .rnd(r[356]), .s(s[356]), .clk(clk), .out({g1_178, g0_178}));
MSKand_opini2_d2 u_t_178 (
    .ina({fc1[178], fc0[178]}), .inb({p1_178, p0_178}),
    .rnd(r[357]), .s(s[357]), .clk(clk), .out({t1_178, t0_178}));
assign fc0[179] = g0_178 ^ t0_178;
assign fc1[179] = g1_178 ^ t1_178;
wire p0_179 = Rsh_d0[179] ^ Bn0[179];
wire p1_179 = Rsh_d1[179] ^ Bn1[179];
wire g0_179, g1_179, t0_179, t1_179;
MSKand_opini2_d2 u_g_179 (
    .ina({Rsh_d1[179], Rsh_d0[179]}), .inb({Bn1[179], Bn0[179]}),
    .rnd(r[358]), .s(s[358]), .clk(clk), .out({g1_179, g0_179}));
MSKand_opini2_d2 u_t_179 (
    .ina({fc1[179], fc0[179]}), .inb({p1_179, p0_179}),
    .rnd(r[359]), .s(s[359]), .clk(clk), .out({t1_179, t0_179}));
assign fc0[180] = g0_179 ^ t0_179;
assign fc1[180] = g1_179 ^ t1_179;
wire p0_180 = Rsh_d0[180] ^ Bn0[180];
wire p1_180 = Rsh_d1[180] ^ Bn1[180];
wire g0_180, g1_180, t0_180, t1_180;
MSKand_opini2_d2 u_g_180 (
    .ina({Rsh_d1[180], Rsh_d0[180]}), .inb({Bn1[180], Bn0[180]}),
    .rnd(r[360]), .s(s[360]), .clk(clk), .out({g1_180, g0_180}));
MSKand_opini2_d2 u_t_180 (
    .ina({fc1[180], fc0[180]}), .inb({p1_180, p0_180}),
    .rnd(r[361]), .s(s[361]), .clk(clk), .out({t1_180, t0_180}));
assign fc0[181] = g0_180 ^ t0_180;
assign fc1[181] = g1_180 ^ t1_180;
wire p0_181 = Rsh_d0[181] ^ Bn0[181];
wire p1_181 = Rsh_d1[181] ^ Bn1[181];
wire g0_181, g1_181, t0_181, t1_181;
MSKand_opini2_d2 u_g_181 (
    .ina({Rsh_d1[181], Rsh_d0[181]}), .inb({Bn1[181], Bn0[181]}),
    .rnd(r[362]), .s(s[362]), .clk(clk), .out({g1_181, g0_181}));
MSKand_opini2_d2 u_t_181 (
    .ina({fc1[181], fc0[181]}), .inb({p1_181, p0_181}),
    .rnd(r[363]), .s(s[363]), .clk(clk), .out({t1_181, t0_181}));
assign fc0[182] = g0_181 ^ t0_181;
assign fc1[182] = g1_181 ^ t1_181;
wire p0_182 = Rsh_d0[182] ^ Bn0[182];
wire p1_182 = Rsh_d1[182] ^ Bn1[182];
wire g0_182, g1_182, t0_182, t1_182;
MSKand_opini2_d2 u_g_182 (
    .ina({Rsh_d1[182], Rsh_d0[182]}), .inb({Bn1[182], Bn0[182]}),
    .rnd(r[364]), .s(s[364]), .clk(clk), .out({g1_182, g0_182}));
MSKand_opini2_d2 u_t_182 (
    .ina({fc1[182], fc0[182]}), .inb({p1_182, p0_182}),
    .rnd(r[365]), .s(s[365]), .clk(clk), .out({t1_182, t0_182}));
assign fc0[183] = g0_182 ^ t0_182;
assign fc1[183] = g1_182 ^ t1_182;
wire p0_183 = Rsh_d0[183] ^ Bn0[183];
wire p1_183 = Rsh_d1[183] ^ Bn1[183];
wire g0_183, g1_183, t0_183, t1_183;
MSKand_opini2_d2 u_g_183 (
    .ina({Rsh_d1[183], Rsh_d0[183]}), .inb({Bn1[183], Bn0[183]}),
    .rnd(r[366]), .s(s[366]), .clk(clk), .out({g1_183, g0_183}));
MSKand_opini2_d2 u_t_183 (
    .ina({fc1[183], fc0[183]}), .inb({p1_183, p0_183}),
    .rnd(r[367]), .s(s[367]), .clk(clk), .out({t1_183, t0_183}));
assign fc0[184] = g0_183 ^ t0_183;
assign fc1[184] = g1_183 ^ t1_183;
wire p0_184 = Rsh_d0[184] ^ Bn0[184];
wire p1_184 = Rsh_d1[184] ^ Bn1[184];
wire g0_184, g1_184, t0_184, t1_184;
MSKand_opini2_d2 u_g_184 (
    .ina({Rsh_d1[184], Rsh_d0[184]}), .inb({Bn1[184], Bn0[184]}),
    .rnd(r[368]), .s(s[368]), .clk(clk), .out({g1_184, g0_184}));
MSKand_opini2_d2 u_t_184 (
    .ina({fc1[184], fc0[184]}), .inb({p1_184, p0_184}),
    .rnd(r[369]), .s(s[369]), .clk(clk), .out({t1_184, t0_184}));
assign fc0[185] = g0_184 ^ t0_184;
assign fc1[185] = g1_184 ^ t1_184;
wire p0_185 = Rsh_d0[185] ^ Bn0[185];
wire p1_185 = Rsh_d1[185] ^ Bn1[185];
wire g0_185, g1_185, t0_185, t1_185;
MSKand_opini2_d2 u_g_185 (
    .ina({Rsh_d1[185], Rsh_d0[185]}), .inb({Bn1[185], Bn0[185]}),
    .rnd(r[370]), .s(s[370]), .clk(clk), .out({g1_185, g0_185}));
MSKand_opini2_d2 u_t_185 (
    .ina({fc1[185], fc0[185]}), .inb({p1_185, p0_185}),
    .rnd(r[371]), .s(s[371]), .clk(clk), .out({t1_185, t0_185}));
assign fc0[186] = g0_185 ^ t0_185;
assign fc1[186] = g1_185 ^ t1_185;
wire p0_186 = Rsh_d0[186] ^ Bn0[186];
wire p1_186 = Rsh_d1[186] ^ Bn1[186];
wire g0_186, g1_186, t0_186, t1_186;
MSKand_opini2_d2 u_g_186 (
    .ina({Rsh_d1[186], Rsh_d0[186]}), .inb({Bn1[186], Bn0[186]}),
    .rnd(r[372]), .s(s[372]), .clk(clk), .out({g1_186, g0_186}));
MSKand_opini2_d2 u_t_186 (
    .ina({fc1[186], fc0[186]}), .inb({p1_186, p0_186}),
    .rnd(r[373]), .s(s[373]), .clk(clk), .out({t1_186, t0_186}));
assign fc0[187] = g0_186 ^ t0_186;
assign fc1[187] = g1_186 ^ t1_186;
wire p0_187 = Rsh_d0[187] ^ Bn0[187];
wire p1_187 = Rsh_d1[187] ^ Bn1[187];
wire g0_187, g1_187, t0_187, t1_187;
MSKand_opini2_d2 u_g_187 (
    .ina({Rsh_d1[187], Rsh_d0[187]}), .inb({Bn1[187], Bn0[187]}),
    .rnd(r[374]), .s(s[374]), .clk(clk), .out({g1_187, g0_187}));
MSKand_opini2_d2 u_t_187 (
    .ina({fc1[187], fc0[187]}), .inb({p1_187, p0_187}),
    .rnd(r[375]), .s(s[375]), .clk(clk), .out({t1_187, t0_187}));
assign fc0[188] = g0_187 ^ t0_187;
assign fc1[188] = g1_187 ^ t1_187;
wire p0_188 = Rsh_d0[188] ^ Bn0[188];
wire p1_188 = Rsh_d1[188] ^ Bn1[188];
wire g0_188, g1_188, t0_188, t1_188;
MSKand_opini2_d2 u_g_188 (
    .ina({Rsh_d1[188], Rsh_d0[188]}), .inb({Bn1[188], Bn0[188]}),
    .rnd(r[376]), .s(s[376]), .clk(clk), .out({g1_188, g0_188}));
MSKand_opini2_d2 u_t_188 (
    .ina({fc1[188], fc0[188]}), .inb({p1_188, p0_188}),
    .rnd(r[377]), .s(s[377]), .clk(clk), .out({t1_188, t0_188}));
assign fc0[189] = g0_188 ^ t0_188;
assign fc1[189] = g1_188 ^ t1_188;
wire p0_189 = Rsh_d0[189] ^ Bn0[189];
wire p1_189 = Rsh_d1[189] ^ Bn1[189];
wire g0_189, g1_189, t0_189, t1_189;
MSKand_opini2_d2 u_g_189 (
    .ina({Rsh_d1[189], Rsh_d0[189]}), .inb({Bn1[189], Bn0[189]}),
    .rnd(r[378]), .s(s[378]), .clk(clk), .out({g1_189, g0_189}));
MSKand_opini2_d2 u_t_189 (
    .ina({fc1[189], fc0[189]}), .inb({p1_189, p0_189}),
    .rnd(r[379]), .s(s[379]), .clk(clk), .out({t1_189, t0_189}));
assign fc0[190] = g0_189 ^ t0_189;
assign fc1[190] = g1_189 ^ t1_189;
wire p0_190 = Rsh_d0[190] ^ Bn0[190];
wire p1_190 = Rsh_d1[190] ^ Bn1[190];
wire g0_190, g1_190, t0_190, t1_190;
MSKand_opini2_d2 u_g_190 (
    .ina({Rsh_d1[190], Rsh_d0[190]}), .inb({Bn1[190], Bn0[190]}),
    .rnd(r[380]), .s(s[380]), .clk(clk), .out({g1_190, g0_190}));
MSKand_opini2_d2 u_t_190 (
    .ina({fc1[190], fc0[190]}), .inb({p1_190, p0_190}),
    .rnd(r[381]), .s(s[381]), .clk(clk), .out({t1_190, t0_190}));
assign fc0[191] = g0_190 ^ t0_190;
assign fc1[191] = g1_190 ^ t1_190;
wire p0_191 = Rsh_d0[191] ^ Bn0[191];
wire p1_191 = Rsh_d1[191] ^ Bn1[191];
wire g0_191, g1_191, t0_191, t1_191;
MSKand_opini2_d2 u_g_191 (
    .ina({Rsh_d1[191], Rsh_d0[191]}), .inb({Bn1[191], Bn0[191]}),
    .rnd(r[382]), .s(s[382]), .clk(clk), .out({g1_191, g0_191}));
MSKand_opini2_d2 u_t_191 (
    .ina({fc1[191], fc0[191]}), .inb({p1_191, p0_191}),
    .rnd(r[383]), .s(s[383]), .clk(clk), .out({t1_191, t0_191}));
assign fc0[192] = g0_191 ^ t0_191;
assign fc1[192] = g1_191 ^ t1_191;
wire p0_192 = Rsh_d0[192] ^ Bn0[192];
wire p1_192 = Rsh_d1[192] ^ Bn1[192];
wire g0_192, g1_192, t0_192, t1_192;
MSKand_opini2_d2 u_g_192 (
    .ina({Rsh_d1[192], Rsh_d0[192]}), .inb({Bn1[192], Bn0[192]}),
    .rnd(r[384]), .s(s[384]), .clk(clk), .out({g1_192, g0_192}));
MSKand_opini2_d2 u_t_192 (
    .ina({fc1[192], fc0[192]}), .inb({p1_192, p0_192}),
    .rnd(r[385]), .s(s[385]), .clk(clk), .out({t1_192, t0_192}));
assign fc0[193] = g0_192 ^ t0_192;
assign fc1[193] = g1_192 ^ t1_192;
wire p0_193 = Rsh_d0[193] ^ Bn0[193];
wire p1_193 = Rsh_d1[193] ^ Bn1[193];
wire g0_193, g1_193, t0_193, t1_193;
MSKand_opini2_d2 u_g_193 (
    .ina({Rsh_d1[193], Rsh_d0[193]}), .inb({Bn1[193], Bn0[193]}),
    .rnd(r[386]), .s(s[386]), .clk(clk), .out({g1_193, g0_193}));
MSKand_opini2_d2 u_t_193 (
    .ina({fc1[193], fc0[193]}), .inb({p1_193, p0_193}),
    .rnd(r[387]), .s(s[387]), .clk(clk), .out({t1_193, t0_193}));
assign fc0[194] = g0_193 ^ t0_193;
assign fc1[194] = g1_193 ^ t1_193;
wire p0_194 = Rsh_d0[194] ^ Bn0[194];
wire p1_194 = Rsh_d1[194] ^ Bn1[194];
wire g0_194, g1_194, t0_194, t1_194;
MSKand_opini2_d2 u_g_194 (
    .ina({Rsh_d1[194], Rsh_d0[194]}), .inb({Bn1[194], Bn0[194]}),
    .rnd(r[388]), .s(s[388]), .clk(clk), .out({g1_194, g0_194}));
MSKand_opini2_d2 u_t_194 (
    .ina({fc1[194], fc0[194]}), .inb({p1_194, p0_194}),
    .rnd(r[389]), .s(s[389]), .clk(clk), .out({t1_194, t0_194}));
assign fc0[195] = g0_194 ^ t0_194;
assign fc1[195] = g1_194 ^ t1_194;
wire p0_195 = Rsh_d0[195] ^ Bn0[195];
wire p1_195 = Rsh_d1[195] ^ Bn1[195];
wire g0_195, g1_195, t0_195, t1_195;
MSKand_opini2_d2 u_g_195 (
    .ina({Rsh_d1[195], Rsh_d0[195]}), .inb({Bn1[195], Bn0[195]}),
    .rnd(r[390]), .s(s[390]), .clk(clk), .out({g1_195, g0_195}));
MSKand_opini2_d2 u_t_195 (
    .ina({fc1[195], fc0[195]}), .inb({p1_195, p0_195}),
    .rnd(r[391]), .s(s[391]), .clk(clk), .out({t1_195, t0_195}));
assign fc0[196] = g0_195 ^ t0_195;
assign fc1[196] = g1_195 ^ t1_195;
wire p0_196 = Rsh_d0[196] ^ Bn0[196];
wire p1_196 = Rsh_d1[196] ^ Bn1[196];
wire g0_196, g1_196, t0_196, t1_196;
MSKand_opini2_d2 u_g_196 (
    .ina({Rsh_d1[196], Rsh_d0[196]}), .inb({Bn1[196], Bn0[196]}),
    .rnd(r[392]), .s(s[392]), .clk(clk), .out({g1_196, g0_196}));
MSKand_opini2_d2 u_t_196 (
    .ina({fc1[196], fc0[196]}), .inb({p1_196, p0_196}),
    .rnd(r[393]), .s(s[393]), .clk(clk), .out({t1_196, t0_196}));
assign fc0[197] = g0_196 ^ t0_196;
assign fc1[197] = g1_196 ^ t1_196;
wire p0_197 = Rsh_d0[197] ^ Bn0[197];
wire p1_197 = Rsh_d1[197] ^ Bn1[197];
wire g0_197, g1_197, t0_197, t1_197;
MSKand_opini2_d2 u_g_197 (
    .ina({Rsh_d1[197], Rsh_d0[197]}), .inb({Bn1[197], Bn0[197]}),
    .rnd(r[394]), .s(s[394]), .clk(clk), .out({g1_197, g0_197}));
MSKand_opini2_d2 u_t_197 (
    .ina({fc1[197], fc0[197]}), .inb({p1_197, p0_197}),
    .rnd(r[395]), .s(s[395]), .clk(clk), .out({t1_197, t0_197}));
assign fc0[198] = g0_197 ^ t0_197;
assign fc1[198] = g1_197 ^ t1_197;
wire p0_198 = Rsh_d0[198] ^ Bn0[198];
wire p1_198 = Rsh_d1[198] ^ Bn1[198];
wire g0_198, g1_198, t0_198, t1_198;
MSKand_opini2_d2 u_g_198 (
    .ina({Rsh_d1[198], Rsh_d0[198]}), .inb({Bn1[198], Bn0[198]}),
    .rnd(r[396]), .s(s[396]), .clk(clk), .out({g1_198, g0_198}));
MSKand_opini2_d2 u_t_198 (
    .ina({fc1[198], fc0[198]}), .inb({p1_198, p0_198}),
    .rnd(r[397]), .s(s[397]), .clk(clk), .out({t1_198, t0_198}));
assign fc0[199] = g0_198 ^ t0_198;
assign fc1[199] = g1_198 ^ t1_198;
wire p0_199 = Rsh_d0[199] ^ Bn0[199];
wire p1_199 = Rsh_d1[199] ^ Bn1[199];
wire g0_199, g1_199, t0_199, t1_199;
MSKand_opini2_d2 u_g_199 (
    .ina({Rsh_d1[199], Rsh_d0[199]}), .inb({Bn1[199], Bn0[199]}),
    .rnd(r[398]), .s(s[398]), .clk(clk), .out({g1_199, g0_199}));
MSKand_opini2_d2 u_t_199 (
    .ina({fc1[199], fc0[199]}), .inb({p1_199, p0_199}),
    .rnd(r[399]), .s(s[399]), .clk(clk), .out({t1_199, t0_199}));
assign fc0[200] = g0_199 ^ t0_199;
assign fc1[200] = g1_199 ^ t1_199;
wire p0_200 = Rsh_d0[200] ^ Bn0[200];
wire p1_200 = Rsh_d1[200] ^ Bn1[200];
wire g0_200, g1_200, t0_200, t1_200;
MSKand_opini2_d2 u_g_200 (
    .ina({Rsh_d1[200], Rsh_d0[200]}), .inb({Bn1[200], Bn0[200]}),
    .rnd(r[400]), .s(s[400]), .clk(clk), .out({g1_200, g0_200}));
MSKand_opini2_d2 u_t_200 (
    .ina({fc1[200], fc0[200]}), .inb({p1_200, p0_200}),
    .rnd(r[401]), .s(s[401]), .clk(clk), .out({t1_200, t0_200}));
assign fc0[201] = g0_200 ^ t0_200;
assign fc1[201] = g1_200 ^ t1_200;
wire p0_201 = Rsh_d0[201] ^ Bn0[201];
wire p1_201 = Rsh_d1[201] ^ Bn1[201];
wire g0_201, g1_201, t0_201, t1_201;
MSKand_opini2_d2 u_g_201 (
    .ina({Rsh_d1[201], Rsh_d0[201]}), .inb({Bn1[201], Bn0[201]}),
    .rnd(r[402]), .s(s[402]), .clk(clk), .out({g1_201, g0_201}));
MSKand_opini2_d2 u_t_201 (
    .ina({fc1[201], fc0[201]}), .inb({p1_201, p0_201}),
    .rnd(r[403]), .s(s[403]), .clk(clk), .out({t1_201, t0_201}));
assign fc0[202] = g0_201 ^ t0_201;
assign fc1[202] = g1_201 ^ t1_201;
wire p0_202 = Rsh_d0[202] ^ Bn0[202];
wire p1_202 = Rsh_d1[202] ^ Bn1[202];
wire g0_202, g1_202, t0_202, t1_202;
MSKand_opini2_d2 u_g_202 (
    .ina({Rsh_d1[202], Rsh_d0[202]}), .inb({Bn1[202], Bn0[202]}),
    .rnd(r[404]), .s(s[404]), .clk(clk), .out({g1_202, g0_202}));
MSKand_opini2_d2 u_t_202 (
    .ina({fc1[202], fc0[202]}), .inb({p1_202, p0_202}),
    .rnd(r[405]), .s(s[405]), .clk(clk), .out({t1_202, t0_202}));
assign fc0[203] = g0_202 ^ t0_202;
assign fc1[203] = g1_202 ^ t1_202;
wire p0_203 = Rsh_d0[203] ^ Bn0[203];
wire p1_203 = Rsh_d1[203] ^ Bn1[203];
wire g0_203, g1_203, t0_203, t1_203;
MSKand_opini2_d2 u_g_203 (
    .ina({Rsh_d1[203], Rsh_d0[203]}), .inb({Bn1[203], Bn0[203]}),
    .rnd(r[406]), .s(s[406]), .clk(clk), .out({g1_203, g0_203}));
MSKand_opini2_d2 u_t_203 (
    .ina({fc1[203], fc0[203]}), .inb({p1_203, p0_203}),
    .rnd(r[407]), .s(s[407]), .clk(clk), .out({t1_203, t0_203}));
assign fc0[204] = g0_203 ^ t0_203;
assign fc1[204] = g1_203 ^ t1_203;
wire p0_204 = Rsh_d0[204] ^ Bn0[204];
wire p1_204 = Rsh_d1[204] ^ Bn1[204];
wire g0_204, g1_204, t0_204, t1_204;
MSKand_opini2_d2 u_g_204 (
    .ina({Rsh_d1[204], Rsh_d0[204]}), .inb({Bn1[204], Bn0[204]}),
    .rnd(r[408]), .s(s[408]), .clk(clk), .out({g1_204, g0_204}));
MSKand_opini2_d2 u_t_204 (
    .ina({fc1[204], fc0[204]}), .inb({p1_204, p0_204}),
    .rnd(r[409]), .s(s[409]), .clk(clk), .out({t1_204, t0_204}));
assign fc0[205] = g0_204 ^ t0_204;
assign fc1[205] = g1_204 ^ t1_204;
wire p0_205 = Rsh_d0[205] ^ Bn0[205];
wire p1_205 = Rsh_d1[205] ^ Bn1[205];
wire g0_205, g1_205, t0_205, t1_205;
MSKand_opini2_d2 u_g_205 (
    .ina({Rsh_d1[205], Rsh_d0[205]}), .inb({Bn1[205], Bn0[205]}),
    .rnd(r[410]), .s(s[410]), .clk(clk), .out({g1_205, g0_205}));
MSKand_opini2_d2 u_t_205 (
    .ina({fc1[205], fc0[205]}), .inb({p1_205, p0_205}),
    .rnd(r[411]), .s(s[411]), .clk(clk), .out({t1_205, t0_205}));
assign fc0[206] = g0_205 ^ t0_205;
assign fc1[206] = g1_205 ^ t1_205;
wire p0_206 = Rsh_d0[206] ^ Bn0[206];
wire p1_206 = Rsh_d1[206] ^ Bn1[206];
wire g0_206, g1_206, t0_206, t1_206;
MSKand_opini2_d2 u_g_206 (
    .ina({Rsh_d1[206], Rsh_d0[206]}), .inb({Bn1[206], Bn0[206]}),
    .rnd(r[412]), .s(s[412]), .clk(clk), .out({g1_206, g0_206}));
MSKand_opini2_d2 u_t_206 (
    .ina({fc1[206], fc0[206]}), .inb({p1_206, p0_206}),
    .rnd(r[413]), .s(s[413]), .clk(clk), .out({t1_206, t0_206}));
assign fc0[207] = g0_206 ^ t0_206;
assign fc1[207] = g1_206 ^ t1_206;
wire p0_207 = Rsh_d0[207] ^ Bn0[207];
wire p1_207 = Rsh_d1[207] ^ Bn1[207];
wire g0_207, g1_207, t0_207, t1_207;
MSKand_opini2_d2 u_g_207 (
    .ina({Rsh_d1[207], Rsh_d0[207]}), .inb({Bn1[207], Bn0[207]}),
    .rnd(r[414]), .s(s[414]), .clk(clk), .out({g1_207, g0_207}));
MSKand_opini2_d2 u_t_207 (
    .ina({fc1[207], fc0[207]}), .inb({p1_207, p0_207}),
    .rnd(r[415]), .s(s[415]), .clk(clk), .out({t1_207, t0_207}));
assign fc0[208] = g0_207 ^ t0_207;
assign fc1[208] = g1_207 ^ t1_207;
wire p0_208 = Rsh_d0[208] ^ Bn0[208];
wire p1_208 = Rsh_d1[208] ^ Bn1[208];
wire g0_208, g1_208, t0_208, t1_208;
MSKand_opini2_d2 u_g_208 (
    .ina({Rsh_d1[208], Rsh_d0[208]}), .inb({Bn1[208], Bn0[208]}),
    .rnd(r[416]), .s(s[416]), .clk(clk), .out({g1_208, g0_208}));
MSKand_opini2_d2 u_t_208 (
    .ina({fc1[208], fc0[208]}), .inb({p1_208, p0_208}),
    .rnd(r[417]), .s(s[417]), .clk(clk), .out({t1_208, t0_208}));
assign fc0[209] = g0_208 ^ t0_208;
assign fc1[209] = g1_208 ^ t1_208;
wire p0_209 = Rsh_d0[209] ^ Bn0[209];
wire p1_209 = Rsh_d1[209] ^ Bn1[209];
wire g0_209, g1_209, t0_209, t1_209;
MSKand_opini2_d2 u_g_209 (
    .ina({Rsh_d1[209], Rsh_d0[209]}), .inb({Bn1[209], Bn0[209]}),
    .rnd(r[418]), .s(s[418]), .clk(clk), .out({g1_209, g0_209}));
MSKand_opini2_d2 u_t_209 (
    .ina({fc1[209], fc0[209]}), .inb({p1_209, p0_209}),
    .rnd(r[419]), .s(s[419]), .clk(clk), .out({t1_209, t0_209}));
assign fc0[210] = g0_209 ^ t0_209;
assign fc1[210] = g1_209 ^ t1_209;
wire p0_210 = Rsh_d0[210] ^ Bn0[210];
wire p1_210 = Rsh_d1[210] ^ Bn1[210];
wire g0_210, g1_210, t0_210, t1_210;
MSKand_opini2_d2 u_g_210 (
    .ina({Rsh_d1[210], Rsh_d0[210]}), .inb({Bn1[210], Bn0[210]}),
    .rnd(r[420]), .s(s[420]), .clk(clk), .out({g1_210, g0_210}));
MSKand_opini2_d2 u_t_210 (
    .ina({fc1[210], fc0[210]}), .inb({p1_210, p0_210}),
    .rnd(r[421]), .s(s[421]), .clk(clk), .out({t1_210, t0_210}));
assign fc0[211] = g0_210 ^ t0_210;
assign fc1[211] = g1_210 ^ t1_210;
wire p0_211 = Rsh_d0[211] ^ Bn0[211];
wire p1_211 = Rsh_d1[211] ^ Bn1[211];
wire g0_211, g1_211, t0_211, t1_211;
MSKand_opini2_d2 u_g_211 (
    .ina({Rsh_d1[211], Rsh_d0[211]}), .inb({Bn1[211], Bn0[211]}),
    .rnd(r[422]), .s(s[422]), .clk(clk), .out({g1_211, g0_211}));
MSKand_opini2_d2 u_t_211 (
    .ina({fc1[211], fc0[211]}), .inb({p1_211, p0_211}),
    .rnd(r[423]), .s(s[423]), .clk(clk), .out({t1_211, t0_211}));
assign fc0[212] = g0_211 ^ t0_211;
assign fc1[212] = g1_211 ^ t1_211;
wire p0_212 = Rsh_d0[212] ^ Bn0[212];
wire p1_212 = Rsh_d1[212] ^ Bn1[212];
wire g0_212, g1_212, t0_212, t1_212;
MSKand_opini2_d2 u_g_212 (
    .ina({Rsh_d1[212], Rsh_d0[212]}), .inb({Bn1[212], Bn0[212]}),
    .rnd(r[424]), .s(s[424]), .clk(clk), .out({g1_212, g0_212}));
MSKand_opini2_d2 u_t_212 (
    .ina({fc1[212], fc0[212]}), .inb({p1_212, p0_212}),
    .rnd(r[425]), .s(s[425]), .clk(clk), .out({t1_212, t0_212}));
assign fc0[213] = g0_212 ^ t0_212;
assign fc1[213] = g1_212 ^ t1_212;
wire p0_213 = Rsh_d0[213] ^ Bn0[213];
wire p1_213 = Rsh_d1[213] ^ Bn1[213];
wire g0_213, g1_213, t0_213, t1_213;
MSKand_opini2_d2 u_g_213 (
    .ina({Rsh_d1[213], Rsh_d0[213]}), .inb({Bn1[213], Bn0[213]}),
    .rnd(r[426]), .s(s[426]), .clk(clk), .out({g1_213, g0_213}));
MSKand_opini2_d2 u_t_213 (
    .ina({fc1[213], fc0[213]}), .inb({p1_213, p0_213}),
    .rnd(r[427]), .s(s[427]), .clk(clk), .out({t1_213, t0_213}));
assign fc0[214] = g0_213 ^ t0_213;
assign fc1[214] = g1_213 ^ t1_213;
wire p0_214 = Rsh_d0[214] ^ Bn0[214];
wire p1_214 = Rsh_d1[214] ^ Bn1[214];
wire g0_214, g1_214, t0_214, t1_214;
MSKand_opini2_d2 u_g_214 (
    .ina({Rsh_d1[214], Rsh_d0[214]}), .inb({Bn1[214], Bn0[214]}),
    .rnd(r[428]), .s(s[428]), .clk(clk), .out({g1_214, g0_214}));
MSKand_opini2_d2 u_t_214 (
    .ina({fc1[214], fc0[214]}), .inb({p1_214, p0_214}),
    .rnd(r[429]), .s(s[429]), .clk(clk), .out({t1_214, t0_214}));
assign fc0[215] = g0_214 ^ t0_214;
assign fc1[215] = g1_214 ^ t1_214;
wire p0_215 = Rsh_d0[215] ^ Bn0[215];
wire p1_215 = Rsh_d1[215] ^ Bn1[215];
wire g0_215, g1_215, t0_215, t1_215;
MSKand_opini2_d2 u_g_215 (
    .ina({Rsh_d1[215], Rsh_d0[215]}), .inb({Bn1[215], Bn0[215]}),
    .rnd(r[430]), .s(s[430]), .clk(clk), .out({g1_215, g0_215}));
MSKand_opini2_d2 u_t_215 (
    .ina({fc1[215], fc0[215]}), .inb({p1_215, p0_215}),
    .rnd(r[431]), .s(s[431]), .clk(clk), .out({t1_215, t0_215}));
assign fc0[216] = g0_215 ^ t0_215;
assign fc1[216] = g1_215 ^ t1_215;
wire p0_216 = Rsh_d0[216] ^ Bn0[216];
wire p1_216 = Rsh_d1[216] ^ Bn1[216];
wire g0_216, g1_216, t0_216, t1_216;
MSKand_opini2_d2 u_g_216 (
    .ina({Rsh_d1[216], Rsh_d0[216]}), .inb({Bn1[216], Bn0[216]}),
    .rnd(r[432]), .s(s[432]), .clk(clk), .out({g1_216, g0_216}));
MSKand_opini2_d2 u_t_216 (
    .ina({fc1[216], fc0[216]}), .inb({p1_216, p0_216}),
    .rnd(r[433]), .s(s[433]), .clk(clk), .out({t1_216, t0_216}));
assign fc0[217] = g0_216 ^ t0_216;
assign fc1[217] = g1_216 ^ t1_216;
wire p0_217 = Rsh_d0[217] ^ Bn0[217];
wire p1_217 = Rsh_d1[217] ^ Bn1[217];
wire g0_217, g1_217, t0_217, t1_217;
MSKand_opini2_d2 u_g_217 (
    .ina({Rsh_d1[217], Rsh_d0[217]}), .inb({Bn1[217], Bn0[217]}),
    .rnd(r[434]), .s(s[434]), .clk(clk), .out({g1_217, g0_217}));
MSKand_opini2_d2 u_t_217 (
    .ina({fc1[217], fc0[217]}), .inb({p1_217, p0_217}),
    .rnd(r[435]), .s(s[435]), .clk(clk), .out({t1_217, t0_217}));
assign fc0[218] = g0_217 ^ t0_217;
assign fc1[218] = g1_217 ^ t1_217;
wire p0_218 = Rsh_d0[218] ^ Bn0[218];
wire p1_218 = Rsh_d1[218] ^ Bn1[218];
wire g0_218, g1_218, t0_218, t1_218;
MSKand_opini2_d2 u_g_218 (
    .ina({Rsh_d1[218], Rsh_d0[218]}), .inb({Bn1[218], Bn0[218]}),
    .rnd(r[436]), .s(s[436]), .clk(clk), .out({g1_218, g0_218}));
MSKand_opini2_d2 u_t_218 (
    .ina({fc1[218], fc0[218]}), .inb({p1_218, p0_218}),
    .rnd(r[437]), .s(s[437]), .clk(clk), .out({t1_218, t0_218}));
assign fc0[219] = g0_218 ^ t0_218;
assign fc1[219] = g1_218 ^ t1_218;
wire p0_219 = Rsh_d0[219] ^ Bn0[219];
wire p1_219 = Rsh_d1[219] ^ Bn1[219];
wire g0_219, g1_219, t0_219, t1_219;
MSKand_opini2_d2 u_g_219 (
    .ina({Rsh_d1[219], Rsh_d0[219]}), .inb({Bn1[219], Bn0[219]}),
    .rnd(r[438]), .s(s[438]), .clk(clk), .out({g1_219, g0_219}));
MSKand_opini2_d2 u_t_219 (
    .ina({fc1[219], fc0[219]}), .inb({p1_219, p0_219}),
    .rnd(r[439]), .s(s[439]), .clk(clk), .out({t1_219, t0_219}));
assign fc0[220] = g0_219 ^ t0_219;
assign fc1[220] = g1_219 ^ t1_219;
wire p0_220 = Rsh_d0[220] ^ Bn0[220];
wire p1_220 = Rsh_d1[220] ^ Bn1[220];
wire g0_220, g1_220, t0_220, t1_220;
MSKand_opini2_d2 u_g_220 (
    .ina({Rsh_d1[220], Rsh_d0[220]}), .inb({Bn1[220], Bn0[220]}),
    .rnd(r[440]), .s(s[440]), .clk(clk), .out({g1_220, g0_220}));
MSKand_opini2_d2 u_t_220 (
    .ina({fc1[220], fc0[220]}), .inb({p1_220, p0_220}),
    .rnd(r[441]), .s(s[441]), .clk(clk), .out({t1_220, t0_220}));
assign fc0[221] = g0_220 ^ t0_220;
assign fc1[221] = g1_220 ^ t1_220;
wire p0_221 = Rsh_d0[221] ^ Bn0[221];
wire p1_221 = Rsh_d1[221] ^ Bn1[221];
wire g0_221, g1_221, t0_221, t1_221;
MSKand_opini2_d2 u_g_221 (
    .ina({Rsh_d1[221], Rsh_d0[221]}), .inb({Bn1[221], Bn0[221]}),
    .rnd(r[442]), .s(s[442]), .clk(clk), .out({g1_221, g0_221}));
MSKand_opini2_d2 u_t_221 (
    .ina({fc1[221], fc0[221]}), .inb({p1_221, p0_221}),
    .rnd(r[443]), .s(s[443]), .clk(clk), .out({t1_221, t0_221}));
assign fc0[222] = g0_221 ^ t0_221;
assign fc1[222] = g1_221 ^ t1_221;
wire p0_222 = Rsh_d0[222] ^ Bn0[222];
wire p1_222 = Rsh_d1[222] ^ Bn1[222];
wire g0_222, g1_222, t0_222, t1_222;
MSKand_opini2_d2 u_g_222 (
    .ina({Rsh_d1[222], Rsh_d0[222]}), .inb({Bn1[222], Bn0[222]}),
    .rnd(r[444]), .s(s[444]), .clk(clk), .out({g1_222, g0_222}));
MSKand_opini2_d2 u_t_222 (
    .ina({fc1[222], fc0[222]}), .inb({p1_222, p0_222}),
    .rnd(r[445]), .s(s[445]), .clk(clk), .out({t1_222, t0_222}));
assign fc0[223] = g0_222 ^ t0_222;
assign fc1[223] = g1_222 ^ t1_222;
wire p0_223 = Rsh_d0[223] ^ Bn0[223];
wire p1_223 = Rsh_d1[223] ^ Bn1[223];
wire g0_223, g1_223, t0_223, t1_223;
MSKand_opini2_d2 u_g_223 (
    .ina({Rsh_d1[223], Rsh_d0[223]}), .inb({Bn1[223], Bn0[223]}),
    .rnd(r[446]), .s(s[446]), .clk(clk), .out({g1_223, g0_223}));
MSKand_opini2_d2 u_t_223 (
    .ina({fc1[223], fc0[223]}), .inb({p1_223, p0_223}),
    .rnd(r[447]), .s(s[447]), .clk(clk), .out({t1_223, t0_223}));
assign fc0[224] = g0_223 ^ t0_223;
assign fc1[224] = g1_223 ^ t1_223;
wire p0_224 = Rsh_d0[224] ^ Bn0[224];
wire p1_224 = Rsh_d1[224] ^ Bn1[224];
wire g0_224, g1_224, t0_224, t1_224;
MSKand_opini2_d2 u_g_224 (
    .ina({Rsh_d1[224], Rsh_d0[224]}), .inb({Bn1[224], Bn0[224]}),
    .rnd(r[448]), .s(s[448]), .clk(clk), .out({g1_224, g0_224}));
MSKand_opini2_d2 u_t_224 (
    .ina({fc1[224], fc0[224]}), .inb({p1_224, p0_224}),
    .rnd(r[449]), .s(s[449]), .clk(clk), .out({t1_224, t0_224}));
assign fc0[225] = g0_224 ^ t0_224;
assign fc1[225] = g1_224 ^ t1_224;
wire p0_225 = Rsh_d0[225] ^ Bn0[225];
wire p1_225 = Rsh_d1[225] ^ Bn1[225];
wire g0_225, g1_225, t0_225, t1_225;
MSKand_opini2_d2 u_g_225 (
    .ina({Rsh_d1[225], Rsh_d0[225]}), .inb({Bn1[225], Bn0[225]}),
    .rnd(r[450]), .s(s[450]), .clk(clk), .out({g1_225, g0_225}));
MSKand_opini2_d2 u_t_225 (
    .ina({fc1[225], fc0[225]}), .inb({p1_225, p0_225}),
    .rnd(r[451]), .s(s[451]), .clk(clk), .out({t1_225, t0_225}));
assign fc0[226] = g0_225 ^ t0_225;
assign fc1[226] = g1_225 ^ t1_225;
wire p0_226 = Rsh_d0[226] ^ Bn0[226];
wire p1_226 = Rsh_d1[226] ^ Bn1[226];
wire g0_226, g1_226, t0_226, t1_226;
MSKand_opini2_d2 u_g_226 (
    .ina({Rsh_d1[226], Rsh_d0[226]}), .inb({Bn1[226], Bn0[226]}),
    .rnd(r[452]), .s(s[452]), .clk(clk), .out({g1_226, g0_226}));
MSKand_opini2_d2 u_t_226 (
    .ina({fc1[226], fc0[226]}), .inb({p1_226, p0_226}),
    .rnd(r[453]), .s(s[453]), .clk(clk), .out({t1_226, t0_226}));
assign fc0[227] = g0_226 ^ t0_226;
assign fc1[227] = g1_226 ^ t1_226;
wire p0_227 = Rsh_d0[227] ^ Bn0[227];
wire p1_227 = Rsh_d1[227] ^ Bn1[227];
wire g0_227, g1_227, t0_227, t1_227;
MSKand_opini2_d2 u_g_227 (
    .ina({Rsh_d1[227], Rsh_d0[227]}), .inb({Bn1[227], Bn0[227]}),
    .rnd(r[454]), .s(s[454]), .clk(clk), .out({g1_227, g0_227}));
MSKand_opini2_d2 u_t_227 (
    .ina({fc1[227], fc0[227]}), .inb({p1_227, p0_227}),
    .rnd(r[455]), .s(s[455]), .clk(clk), .out({t1_227, t0_227}));
assign fc0[228] = g0_227 ^ t0_227;
assign fc1[228] = g1_227 ^ t1_227;
wire p0_228 = Rsh_d0[228] ^ Bn0[228];
wire p1_228 = Rsh_d1[228] ^ Bn1[228];
wire g0_228, g1_228, t0_228, t1_228;
MSKand_opini2_d2 u_g_228 (
    .ina({Rsh_d1[228], Rsh_d0[228]}), .inb({Bn1[228], Bn0[228]}),
    .rnd(r[456]), .s(s[456]), .clk(clk), .out({g1_228, g0_228}));
MSKand_opini2_d2 u_t_228 (
    .ina({fc1[228], fc0[228]}), .inb({p1_228, p0_228}),
    .rnd(r[457]), .s(s[457]), .clk(clk), .out({t1_228, t0_228}));
assign fc0[229] = g0_228 ^ t0_228;
assign fc1[229] = g1_228 ^ t1_228;
wire p0_229 = Rsh_d0[229] ^ Bn0[229];
wire p1_229 = Rsh_d1[229] ^ Bn1[229];
wire g0_229, g1_229, t0_229, t1_229;
MSKand_opini2_d2 u_g_229 (
    .ina({Rsh_d1[229], Rsh_d0[229]}), .inb({Bn1[229], Bn0[229]}),
    .rnd(r[458]), .s(s[458]), .clk(clk), .out({g1_229, g0_229}));
MSKand_opini2_d2 u_t_229 (
    .ina({fc1[229], fc0[229]}), .inb({p1_229, p0_229}),
    .rnd(r[459]), .s(s[459]), .clk(clk), .out({t1_229, t0_229}));
assign fc0[230] = g0_229 ^ t0_229;
assign fc1[230] = g1_229 ^ t1_229;
wire p0_230 = Rsh_d0[230] ^ Bn0[230];
wire p1_230 = Rsh_d1[230] ^ Bn1[230];
wire g0_230, g1_230, t0_230, t1_230;
MSKand_opini2_d2 u_g_230 (
    .ina({Rsh_d1[230], Rsh_d0[230]}), .inb({Bn1[230], Bn0[230]}),
    .rnd(r[460]), .s(s[460]), .clk(clk), .out({g1_230, g0_230}));
MSKand_opini2_d2 u_t_230 (
    .ina({fc1[230], fc0[230]}), .inb({p1_230, p0_230}),
    .rnd(r[461]), .s(s[461]), .clk(clk), .out({t1_230, t0_230}));
assign fc0[231] = g0_230 ^ t0_230;
assign fc1[231] = g1_230 ^ t1_230;
wire p0_231 = Rsh_d0[231] ^ Bn0[231];
wire p1_231 = Rsh_d1[231] ^ Bn1[231];
wire g0_231, g1_231, t0_231, t1_231;
MSKand_opini2_d2 u_g_231 (
    .ina({Rsh_d1[231], Rsh_d0[231]}), .inb({Bn1[231], Bn0[231]}),
    .rnd(r[462]), .s(s[462]), .clk(clk), .out({g1_231, g0_231}));
MSKand_opini2_d2 u_t_231 (
    .ina({fc1[231], fc0[231]}), .inb({p1_231, p0_231}),
    .rnd(r[463]), .s(s[463]), .clk(clk), .out({t1_231, t0_231}));
assign fc0[232] = g0_231 ^ t0_231;
assign fc1[232] = g1_231 ^ t1_231;
wire p0_232 = Rsh_d0[232] ^ Bn0[232];
wire p1_232 = Rsh_d1[232] ^ Bn1[232];
wire g0_232, g1_232, t0_232, t1_232;
MSKand_opini2_d2 u_g_232 (
    .ina({Rsh_d1[232], Rsh_d0[232]}), .inb({Bn1[232], Bn0[232]}),
    .rnd(r[464]), .s(s[464]), .clk(clk), .out({g1_232, g0_232}));
MSKand_opini2_d2 u_t_232 (
    .ina({fc1[232], fc0[232]}), .inb({p1_232, p0_232}),
    .rnd(r[465]), .s(s[465]), .clk(clk), .out({t1_232, t0_232}));
assign fc0[233] = g0_232 ^ t0_232;
assign fc1[233] = g1_232 ^ t1_232;
wire p0_233 = Rsh_d0[233] ^ Bn0[233];
wire p1_233 = Rsh_d1[233] ^ Bn1[233];
wire g0_233, g1_233, t0_233, t1_233;
MSKand_opini2_d2 u_g_233 (
    .ina({Rsh_d1[233], Rsh_d0[233]}), .inb({Bn1[233], Bn0[233]}),
    .rnd(r[466]), .s(s[466]), .clk(clk), .out({g1_233, g0_233}));
MSKand_opini2_d2 u_t_233 (
    .ina({fc1[233], fc0[233]}), .inb({p1_233, p0_233}),
    .rnd(r[467]), .s(s[467]), .clk(clk), .out({t1_233, t0_233}));
assign fc0[234] = g0_233 ^ t0_233;
assign fc1[234] = g1_233 ^ t1_233;
wire p0_234 = Rsh_d0[234] ^ Bn0[234];
wire p1_234 = Rsh_d1[234] ^ Bn1[234];
wire g0_234, g1_234, t0_234, t1_234;
MSKand_opini2_d2 u_g_234 (
    .ina({Rsh_d1[234], Rsh_d0[234]}), .inb({Bn1[234], Bn0[234]}),
    .rnd(r[468]), .s(s[468]), .clk(clk), .out({g1_234, g0_234}));
MSKand_opini2_d2 u_t_234 (
    .ina({fc1[234], fc0[234]}), .inb({p1_234, p0_234}),
    .rnd(r[469]), .s(s[469]), .clk(clk), .out({t1_234, t0_234}));
assign fc0[235] = g0_234 ^ t0_234;
assign fc1[235] = g1_234 ^ t1_234;
wire p0_235 = Rsh_d0[235] ^ Bn0[235];
wire p1_235 = Rsh_d1[235] ^ Bn1[235];
wire g0_235, g1_235, t0_235, t1_235;
MSKand_opini2_d2 u_g_235 (
    .ina({Rsh_d1[235], Rsh_d0[235]}), .inb({Bn1[235], Bn0[235]}),
    .rnd(r[470]), .s(s[470]), .clk(clk), .out({g1_235, g0_235}));
MSKand_opini2_d2 u_t_235 (
    .ina({fc1[235], fc0[235]}), .inb({p1_235, p0_235}),
    .rnd(r[471]), .s(s[471]), .clk(clk), .out({t1_235, t0_235}));
assign fc0[236] = g0_235 ^ t0_235;
assign fc1[236] = g1_235 ^ t1_235;
wire p0_236 = Rsh_d0[236] ^ Bn0[236];
wire p1_236 = Rsh_d1[236] ^ Bn1[236];
wire g0_236, g1_236, t0_236, t1_236;
MSKand_opini2_d2 u_g_236 (
    .ina({Rsh_d1[236], Rsh_d0[236]}), .inb({Bn1[236], Bn0[236]}),
    .rnd(r[472]), .s(s[472]), .clk(clk), .out({g1_236, g0_236}));
MSKand_opini2_d2 u_t_236 (
    .ina({fc1[236], fc0[236]}), .inb({p1_236, p0_236}),
    .rnd(r[473]), .s(s[473]), .clk(clk), .out({t1_236, t0_236}));
assign fc0[237] = g0_236 ^ t0_236;
assign fc1[237] = g1_236 ^ t1_236;
wire p0_237 = Rsh_d0[237] ^ Bn0[237];
wire p1_237 = Rsh_d1[237] ^ Bn1[237];
wire g0_237, g1_237, t0_237, t1_237;
MSKand_opini2_d2 u_g_237 (
    .ina({Rsh_d1[237], Rsh_d0[237]}), .inb({Bn1[237], Bn0[237]}),
    .rnd(r[474]), .s(s[474]), .clk(clk), .out({g1_237, g0_237}));
MSKand_opini2_d2 u_t_237 (
    .ina({fc1[237], fc0[237]}), .inb({p1_237, p0_237}),
    .rnd(r[475]), .s(s[475]), .clk(clk), .out({t1_237, t0_237}));
assign fc0[238] = g0_237 ^ t0_237;
assign fc1[238] = g1_237 ^ t1_237;
wire p0_238 = Rsh_d0[238] ^ Bn0[238];
wire p1_238 = Rsh_d1[238] ^ Bn1[238];
wire g0_238, g1_238, t0_238, t1_238;
MSKand_opini2_d2 u_g_238 (
    .ina({Rsh_d1[238], Rsh_d0[238]}), .inb({Bn1[238], Bn0[238]}),
    .rnd(r[476]), .s(s[476]), .clk(clk), .out({g1_238, g0_238}));
MSKand_opini2_d2 u_t_238 (
    .ina({fc1[238], fc0[238]}), .inb({p1_238, p0_238}),
    .rnd(r[477]), .s(s[477]), .clk(clk), .out({t1_238, t0_238}));
assign fc0[239] = g0_238 ^ t0_238;
assign fc1[239] = g1_238 ^ t1_238;
wire p0_239 = Rsh_d0[239] ^ Bn0[239];
wire p1_239 = Rsh_d1[239] ^ Bn1[239];
wire g0_239, g1_239, t0_239, t1_239;
MSKand_opini2_d2 u_g_239 (
    .ina({Rsh_d1[239], Rsh_d0[239]}), .inb({Bn1[239], Bn0[239]}),
    .rnd(r[478]), .s(s[478]), .clk(clk), .out({g1_239, g0_239}));
MSKand_opini2_d2 u_t_239 (
    .ina({fc1[239], fc0[239]}), .inb({p1_239, p0_239}),
    .rnd(r[479]), .s(s[479]), .clk(clk), .out({t1_239, t0_239}));
assign fc0[240] = g0_239 ^ t0_239;
assign fc1[240] = g1_239 ^ t1_239;
wire p0_240 = Rsh_d0[240] ^ Bn0[240];
wire p1_240 = Rsh_d1[240] ^ Bn1[240];
wire g0_240, g1_240, t0_240, t1_240;
MSKand_opini2_d2 u_g_240 (
    .ina({Rsh_d1[240], Rsh_d0[240]}), .inb({Bn1[240], Bn0[240]}),
    .rnd(r[480]), .s(s[480]), .clk(clk), .out({g1_240, g0_240}));
MSKand_opini2_d2 u_t_240 (
    .ina({fc1[240], fc0[240]}), .inb({p1_240, p0_240}),
    .rnd(r[481]), .s(s[481]), .clk(clk), .out({t1_240, t0_240}));
assign fc0[241] = g0_240 ^ t0_240;
assign fc1[241] = g1_240 ^ t1_240;
wire p0_241 = Rsh_d0[241] ^ Bn0[241];
wire p1_241 = Rsh_d1[241] ^ Bn1[241];
wire g0_241, g1_241, t0_241, t1_241;
MSKand_opini2_d2 u_g_241 (
    .ina({Rsh_d1[241], Rsh_d0[241]}), .inb({Bn1[241], Bn0[241]}),
    .rnd(r[482]), .s(s[482]), .clk(clk), .out({g1_241, g0_241}));
MSKand_opini2_d2 u_t_241 (
    .ina({fc1[241], fc0[241]}), .inb({p1_241, p0_241}),
    .rnd(r[483]), .s(s[483]), .clk(clk), .out({t1_241, t0_241}));
assign fc0[242] = g0_241 ^ t0_241;
assign fc1[242] = g1_241 ^ t1_241;
wire p0_242 = Rsh_d0[242] ^ Bn0[242];
wire p1_242 = Rsh_d1[242] ^ Bn1[242];
wire g0_242, g1_242, t0_242, t1_242;
MSKand_opini2_d2 u_g_242 (
    .ina({Rsh_d1[242], Rsh_d0[242]}), .inb({Bn1[242], Bn0[242]}),
    .rnd(r[484]), .s(s[484]), .clk(clk), .out({g1_242, g0_242}));
MSKand_opini2_d2 u_t_242 (
    .ina({fc1[242], fc0[242]}), .inb({p1_242, p0_242}),
    .rnd(r[485]), .s(s[485]), .clk(clk), .out({t1_242, t0_242}));
assign fc0[243] = g0_242 ^ t0_242;
assign fc1[243] = g1_242 ^ t1_242;
wire p0_243 = Rsh_d0[243] ^ Bn0[243];
wire p1_243 = Rsh_d1[243] ^ Bn1[243];
wire g0_243, g1_243, t0_243, t1_243;
MSKand_opini2_d2 u_g_243 (
    .ina({Rsh_d1[243], Rsh_d0[243]}), .inb({Bn1[243], Bn0[243]}),
    .rnd(r[486]), .s(s[486]), .clk(clk), .out({g1_243, g0_243}));
MSKand_opini2_d2 u_t_243 (
    .ina({fc1[243], fc0[243]}), .inb({p1_243, p0_243}),
    .rnd(r[487]), .s(s[487]), .clk(clk), .out({t1_243, t0_243}));
assign fc0[244] = g0_243 ^ t0_243;
assign fc1[244] = g1_243 ^ t1_243;
wire p0_244 = Rsh_d0[244] ^ Bn0[244];
wire p1_244 = Rsh_d1[244] ^ Bn1[244];
wire g0_244, g1_244, t0_244, t1_244;
MSKand_opini2_d2 u_g_244 (
    .ina({Rsh_d1[244], Rsh_d0[244]}), .inb({Bn1[244], Bn0[244]}),
    .rnd(r[488]), .s(s[488]), .clk(clk), .out({g1_244, g0_244}));
MSKand_opini2_d2 u_t_244 (
    .ina({fc1[244], fc0[244]}), .inb({p1_244, p0_244}),
    .rnd(r[489]), .s(s[489]), .clk(clk), .out({t1_244, t0_244}));
assign fc0[245] = g0_244 ^ t0_244;
assign fc1[245] = g1_244 ^ t1_244;
wire p0_245 = Rsh_d0[245] ^ Bn0[245];
wire p1_245 = Rsh_d1[245] ^ Bn1[245];
wire g0_245, g1_245, t0_245, t1_245;
MSKand_opini2_d2 u_g_245 (
    .ina({Rsh_d1[245], Rsh_d0[245]}), .inb({Bn1[245], Bn0[245]}),
    .rnd(r[490]), .s(s[490]), .clk(clk), .out({g1_245, g0_245}));
MSKand_opini2_d2 u_t_245 (
    .ina({fc1[245], fc0[245]}), .inb({p1_245, p0_245}),
    .rnd(r[491]), .s(s[491]), .clk(clk), .out({t1_245, t0_245}));
assign fc0[246] = g0_245 ^ t0_245;
assign fc1[246] = g1_245 ^ t1_245;
wire p0_246 = Rsh_d0[246] ^ Bn0[246];
wire p1_246 = Rsh_d1[246] ^ Bn1[246];
wire g0_246, g1_246, t0_246, t1_246;
MSKand_opini2_d2 u_g_246 (
    .ina({Rsh_d1[246], Rsh_d0[246]}), .inb({Bn1[246], Bn0[246]}),
    .rnd(r[492]), .s(s[492]), .clk(clk), .out({g1_246, g0_246}));
MSKand_opini2_d2 u_t_246 (
    .ina({fc1[246], fc0[246]}), .inb({p1_246, p0_246}),
    .rnd(r[493]), .s(s[493]), .clk(clk), .out({t1_246, t0_246}));
assign fc0[247] = g0_246 ^ t0_246;
assign fc1[247] = g1_246 ^ t1_246;
wire p0_247 = Rsh_d0[247] ^ Bn0[247];
wire p1_247 = Rsh_d1[247] ^ Bn1[247];
wire g0_247, g1_247, t0_247, t1_247;
MSKand_opini2_d2 u_g_247 (
    .ina({Rsh_d1[247], Rsh_d0[247]}), .inb({Bn1[247], Bn0[247]}),
    .rnd(r[494]), .s(s[494]), .clk(clk), .out({g1_247, g0_247}));
MSKand_opini2_d2 u_t_247 (
    .ina({fc1[247], fc0[247]}), .inb({p1_247, p0_247}),
    .rnd(r[495]), .s(s[495]), .clk(clk), .out({t1_247, t0_247}));
assign fc0[248] = g0_247 ^ t0_247;
assign fc1[248] = g1_247 ^ t1_247;
wire p0_248 = Rsh_d0[248] ^ Bn0[248];
wire p1_248 = Rsh_d1[248] ^ Bn1[248];
wire g0_248, g1_248, t0_248, t1_248;
MSKand_opini2_d2 u_g_248 (
    .ina({Rsh_d1[248], Rsh_d0[248]}), .inb({Bn1[248], Bn0[248]}),
    .rnd(r[496]), .s(s[496]), .clk(clk), .out({g1_248, g0_248}));
MSKand_opini2_d2 u_t_248 (
    .ina({fc1[248], fc0[248]}), .inb({p1_248, p0_248}),
    .rnd(r[497]), .s(s[497]), .clk(clk), .out({t1_248, t0_248}));
assign fc0[249] = g0_248 ^ t0_248;
assign fc1[249] = g1_248 ^ t1_248;
wire p0_249 = Rsh_d0[249] ^ Bn0[249];
wire p1_249 = Rsh_d1[249] ^ Bn1[249];
wire g0_249, g1_249, t0_249, t1_249;
MSKand_opini2_d2 u_g_249 (
    .ina({Rsh_d1[249], Rsh_d0[249]}), .inb({Bn1[249], Bn0[249]}),
    .rnd(r[498]), .s(s[498]), .clk(clk), .out({g1_249, g0_249}));
MSKand_opini2_d2 u_t_249 (
    .ina({fc1[249], fc0[249]}), .inb({p1_249, p0_249}),
    .rnd(r[499]), .s(s[499]), .clk(clk), .out({t1_249, t0_249}));
assign fc0[250] = g0_249 ^ t0_249;
assign fc1[250] = g1_249 ^ t1_249;
wire p0_250 = Rsh_d0[250] ^ Bn0[250];
wire p1_250 = Rsh_d1[250] ^ Bn1[250];
wire g0_250, g1_250, t0_250, t1_250;
MSKand_opini2_d2 u_g_250 (
    .ina({Rsh_d1[250], Rsh_d0[250]}), .inb({Bn1[250], Bn0[250]}),
    .rnd(r[500]), .s(s[500]), .clk(clk), .out({g1_250, g0_250}));
MSKand_opini2_d2 u_t_250 (
    .ina({fc1[250], fc0[250]}), .inb({p1_250, p0_250}),
    .rnd(r[501]), .s(s[501]), .clk(clk), .out({t1_250, t0_250}));
assign fc0[251] = g0_250 ^ t0_250;
assign fc1[251] = g1_250 ^ t1_250;
wire p0_251 = Rsh_d0[251] ^ Bn0[251];
wire p1_251 = Rsh_d1[251] ^ Bn1[251];
wire g0_251, g1_251, t0_251, t1_251;
MSKand_opini2_d2 u_g_251 (
    .ina({Rsh_d1[251], Rsh_d0[251]}), .inb({Bn1[251], Bn0[251]}),
    .rnd(r[502]), .s(s[502]), .clk(clk), .out({g1_251, g0_251}));
MSKand_opini2_d2 u_t_251 (
    .ina({fc1[251], fc0[251]}), .inb({p1_251, p0_251}),
    .rnd(r[503]), .s(s[503]), .clk(clk), .out({t1_251, t0_251}));
assign fc0[252] = g0_251 ^ t0_251;
assign fc1[252] = g1_251 ^ t1_251;
wire p0_252 = Rsh_d0[252] ^ Bn0[252];
wire p1_252 = Rsh_d1[252] ^ Bn1[252];
wire g0_252, g1_252, t0_252, t1_252;
MSKand_opini2_d2 u_g_252 (
    .ina({Rsh_d1[252], Rsh_d0[252]}), .inb({Bn1[252], Bn0[252]}),
    .rnd(r[504]), .s(s[504]), .clk(clk), .out({g1_252, g0_252}));
MSKand_opini2_d2 u_t_252 (
    .ina({fc1[252], fc0[252]}), .inb({p1_252, p0_252}),
    .rnd(r[505]), .s(s[505]), .clk(clk), .out({t1_252, t0_252}));
assign fc0[253] = g0_252 ^ t0_252;
assign fc1[253] = g1_252 ^ t1_252;
wire p0_253 = Rsh_d0[253] ^ Bn0[253];
wire p1_253 = Rsh_d1[253] ^ Bn1[253];
wire g0_253, g1_253, t0_253, t1_253;
MSKand_opini2_d2 u_g_253 (
    .ina({Rsh_d1[253], Rsh_d0[253]}), .inb({Bn1[253], Bn0[253]}),
    .rnd(r[506]), .s(s[506]), .clk(clk), .out({g1_253, g0_253}));
MSKand_opini2_d2 u_t_253 (
    .ina({fc1[253], fc0[253]}), .inb({p1_253, p0_253}),
    .rnd(r[507]), .s(s[507]), .clk(clk), .out({t1_253, t0_253}));
assign fc0[254] = g0_253 ^ t0_253;
assign fc1[254] = g1_253 ^ t1_253;
wire p0_254 = Rsh_d0[254] ^ Bn0[254];
wire p1_254 = Rsh_d1[254] ^ Bn1[254];
wire g0_254, g1_254, t0_254, t1_254;
MSKand_opini2_d2 u_g_254 (
    .ina({Rsh_d1[254], Rsh_d0[254]}), .inb({Bn1[254], Bn0[254]}),
    .rnd(r[508]), .s(s[508]), .clk(clk), .out({g1_254, g0_254}));
MSKand_opini2_d2 u_t_254 (
    .ina({fc1[254], fc0[254]}), .inb({p1_254, p0_254}),
    .rnd(r[509]), .s(s[509]), .clk(clk), .out({t1_254, t0_254}));
assign fc0[255] = g0_254 ^ t0_254;
assign fc1[255] = g1_254 ^ t1_254;
wire p0_255 = Rsh_d0[255] ^ Bn0[255];
wire p1_255 = Rsh_d1[255] ^ Bn1[255];
wire g0_255, g1_255, t0_255, t1_255;
MSKand_opini2_d2 u_g_255 (
    .ina({Rsh_d1[255], Rsh_d0[255]}), .inb({Bn1[255], Bn0[255]}),
    .rnd(r[510]), .s(s[510]), .clk(clk), .out({g1_255, g0_255}));
MSKand_opini2_d2 u_t_255 (
    .ina({fc1[255], fc0[255]}), .inb({p1_255, p0_255}),
    .rnd(r[511]), .s(s[511]), .clk(clk), .out({t1_255, t0_255}));
assign fc0[256] = g0_255 ^ t0_255;
assign fc1[256] = g1_255 ^ t1_255;
wire p0_256 = Rsh_d0[256] ^ 1'b1;
wire p1_256 = Rsh_d1[256] ^ 1'b0;
wire g0_256, g1_256, t0_256, t1_256;
MSKand_opini2_d2 u_g_256 (
    .ina({Rsh_d1[256], Rsh_d0[256]}), .inb({1'b0, 1'b1}),
    .rnd(r[512]), .s(s[512]), .clk(clk), .out({g1_256, g0_256}));
MSKand_opini2_d2 u_t_256 (
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
MSKand_opini2_d2 u_m_0 (
    .ina({xm_d1[0], xm_d0[0]}), .inb({coutr1, coutr0}),
    .rnd(r[514]), .s(s[514]), .clk(clk), .out({w_m1[0], w_m0[0]}));
MSKand_opini2_d2 u_m_1 (
    .ina({xm_d1[1], xm_d0[1]}), .inb({coutr1, coutr0}),
    .rnd(r[515]), .s(s[515]), .clk(clk), .out({w_m1[1], w_m0[1]}));
MSKand_opini2_d2 u_m_2 (
    .ina({xm_d1[2], xm_d0[2]}), .inb({coutr1, coutr0}),
    .rnd(r[516]), .s(s[516]), .clk(clk), .out({w_m1[2], w_m0[2]}));
MSKand_opini2_d2 u_m_3 (
    .ina({xm_d1[3], xm_d0[3]}), .inb({coutr1, coutr0}),
    .rnd(r[517]), .s(s[517]), .clk(clk), .out({w_m1[3], w_m0[3]}));
MSKand_opini2_d2 u_m_4 (
    .ina({xm_d1[4], xm_d0[4]}), .inb({coutr1, coutr0}),
    .rnd(r[518]), .s(s[518]), .clk(clk), .out({w_m1[4], w_m0[4]}));
MSKand_opini2_d2 u_m_5 (
    .ina({xm_d1[5], xm_d0[5]}), .inb({coutr1, coutr0}),
    .rnd(r[519]), .s(s[519]), .clk(clk), .out({w_m1[5], w_m0[5]}));
MSKand_opini2_d2 u_m_6 (
    .ina({xm_d1[6], xm_d0[6]}), .inb({coutr1, coutr0}),
    .rnd(r[520]), .s(s[520]), .clk(clk), .out({w_m1[6], w_m0[6]}));
MSKand_opini2_d2 u_m_7 (
    .ina({xm_d1[7], xm_d0[7]}), .inb({coutr1, coutr0}),
    .rnd(r[521]), .s(s[521]), .clk(clk), .out({w_m1[7], w_m0[7]}));
MSKand_opini2_d2 u_m_8 (
    .ina({xm_d1[8], xm_d0[8]}), .inb({coutr1, coutr0}),
    .rnd(r[522]), .s(s[522]), .clk(clk), .out({w_m1[8], w_m0[8]}));
MSKand_opini2_d2 u_m_9 (
    .ina({xm_d1[9], xm_d0[9]}), .inb({coutr1, coutr0}),
    .rnd(r[523]), .s(s[523]), .clk(clk), .out({w_m1[9], w_m0[9]}));
MSKand_opini2_d2 u_m_10 (
    .ina({xm_d1[10], xm_d0[10]}), .inb({coutr1, coutr0}),
    .rnd(r[524]), .s(s[524]), .clk(clk), .out({w_m1[10], w_m0[10]}));
MSKand_opini2_d2 u_m_11 (
    .ina({xm_d1[11], xm_d0[11]}), .inb({coutr1, coutr0}),
    .rnd(r[525]), .s(s[525]), .clk(clk), .out({w_m1[11], w_m0[11]}));
MSKand_opini2_d2 u_m_12 (
    .ina({xm_d1[12], xm_d0[12]}), .inb({coutr1, coutr0}),
    .rnd(r[526]), .s(s[526]), .clk(clk), .out({w_m1[12], w_m0[12]}));
MSKand_opini2_d2 u_m_13 (
    .ina({xm_d1[13], xm_d0[13]}), .inb({coutr1, coutr0}),
    .rnd(r[527]), .s(s[527]), .clk(clk), .out({w_m1[13], w_m0[13]}));
MSKand_opini2_d2 u_m_14 (
    .ina({xm_d1[14], xm_d0[14]}), .inb({coutr1, coutr0}),
    .rnd(r[528]), .s(s[528]), .clk(clk), .out({w_m1[14], w_m0[14]}));
MSKand_opini2_d2 u_m_15 (
    .ina({xm_d1[15], xm_d0[15]}), .inb({coutr1, coutr0}),
    .rnd(r[529]), .s(s[529]), .clk(clk), .out({w_m1[15], w_m0[15]}));
MSKand_opini2_d2 u_m_16 (
    .ina({xm_d1[16], xm_d0[16]}), .inb({coutr1, coutr0}),
    .rnd(r[530]), .s(s[530]), .clk(clk), .out({w_m1[16], w_m0[16]}));
MSKand_opini2_d2 u_m_17 (
    .ina({xm_d1[17], xm_d0[17]}), .inb({coutr1, coutr0}),
    .rnd(r[531]), .s(s[531]), .clk(clk), .out({w_m1[17], w_m0[17]}));
MSKand_opini2_d2 u_m_18 (
    .ina({xm_d1[18], xm_d0[18]}), .inb({coutr1, coutr0}),
    .rnd(r[532]), .s(s[532]), .clk(clk), .out({w_m1[18], w_m0[18]}));
MSKand_opini2_d2 u_m_19 (
    .ina({xm_d1[19], xm_d0[19]}), .inb({coutr1, coutr0}),
    .rnd(r[533]), .s(s[533]), .clk(clk), .out({w_m1[19], w_m0[19]}));
MSKand_opini2_d2 u_m_20 (
    .ina({xm_d1[20], xm_d0[20]}), .inb({coutr1, coutr0}),
    .rnd(r[534]), .s(s[534]), .clk(clk), .out({w_m1[20], w_m0[20]}));
MSKand_opini2_d2 u_m_21 (
    .ina({xm_d1[21], xm_d0[21]}), .inb({coutr1, coutr0}),
    .rnd(r[535]), .s(s[535]), .clk(clk), .out({w_m1[21], w_m0[21]}));
MSKand_opini2_d2 u_m_22 (
    .ina({xm_d1[22], xm_d0[22]}), .inb({coutr1, coutr0}),
    .rnd(r[536]), .s(s[536]), .clk(clk), .out({w_m1[22], w_m0[22]}));
MSKand_opini2_d2 u_m_23 (
    .ina({xm_d1[23], xm_d0[23]}), .inb({coutr1, coutr0}),
    .rnd(r[537]), .s(s[537]), .clk(clk), .out({w_m1[23], w_m0[23]}));
MSKand_opini2_d2 u_m_24 (
    .ina({xm_d1[24], xm_d0[24]}), .inb({coutr1, coutr0}),
    .rnd(r[538]), .s(s[538]), .clk(clk), .out({w_m1[24], w_m0[24]}));
MSKand_opini2_d2 u_m_25 (
    .ina({xm_d1[25], xm_d0[25]}), .inb({coutr1, coutr0}),
    .rnd(r[539]), .s(s[539]), .clk(clk), .out({w_m1[25], w_m0[25]}));
MSKand_opini2_d2 u_m_26 (
    .ina({xm_d1[26], xm_d0[26]}), .inb({coutr1, coutr0}),
    .rnd(r[540]), .s(s[540]), .clk(clk), .out({w_m1[26], w_m0[26]}));
MSKand_opini2_d2 u_m_27 (
    .ina({xm_d1[27], xm_d0[27]}), .inb({coutr1, coutr0}),
    .rnd(r[541]), .s(s[541]), .clk(clk), .out({w_m1[27], w_m0[27]}));
MSKand_opini2_d2 u_m_28 (
    .ina({xm_d1[28], xm_d0[28]}), .inb({coutr1, coutr0}),
    .rnd(r[542]), .s(s[542]), .clk(clk), .out({w_m1[28], w_m0[28]}));
MSKand_opini2_d2 u_m_29 (
    .ina({xm_d1[29], xm_d0[29]}), .inb({coutr1, coutr0}),
    .rnd(r[543]), .s(s[543]), .clk(clk), .out({w_m1[29], w_m0[29]}));
MSKand_opini2_d2 u_m_30 (
    .ina({xm_d1[30], xm_d0[30]}), .inb({coutr1, coutr0}),
    .rnd(r[544]), .s(s[544]), .clk(clk), .out({w_m1[30], w_m0[30]}));
MSKand_opini2_d2 u_m_31 (
    .ina({xm_d1[31], xm_d0[31]}), .inb({coutr1, coutr0}),
    .rnd(r[545]), .s(s[545]), .clk(clk), .out({w_m1[31], w_m0[31]}));
MSKand_opini2_d2 u_m_32 (
    .ina({xm_d1[32], xm_d0[32]}), .inb({coutr1, coutr0}),
    .rnd(r[546]), .s(s[546]), .clk(clk), .out({w_m1[32], w_m0[32]}));
MSKand_opini2_d2 u_m_33 (
    .ina({xm_d1[33], xm_d0[33]}), .inb({coutr1, coutr0}),
    .rnd(r[547]), .s(s[547]), .clk(clk), .out({w_m1[33], w_m0[33]}));
MSKand_opini2_d2 u_m_34 (
    .ina({xm_d1[34], xm_d0[34]}), .inb({coutr1, coutr0}),
    .rnd(r[548]), .s(s[548]), .clk(clk), .out({w_m1[34], w_m0[34]}));
MSKand_opini2_d2 u_m_35 (
    .ina({xm_d1[35], xm_d0[35]}), .inb({coutr1, coutr0}),
    .rnd(r[549]), .s(s[549]), .clk(clk), .out({w_m1[35], w_m0[35]}));
MSKand_opini2_d2 u_m_36 (
    .ina({xm_d1[36], xm_d0[36]}), .inb({coutr1, coutr0}),
    .rnd(r[550]), .s(s[550]), .clk(clk), .out({w_m1[36], w_m0[36]}));
MSKand_opini2_d2 u_m_37 (
    .ina({xm_d1[37], xm_d0[37]}), .inb({coutr1, coutr0}),
    .rnd(r[551]), .s(s[551]), .clk(clk), .out({w_m1[37], w_m0[37]}));
MSKand_opini2_d2 u_m_38 (
    .ina({xm_d1[38], xm_d0[38]}), .inb({coutr1, coutr0}),
    .rnd(r[552]), .s(s[552]), .clk(clk), .out({w_m1[38], w_m0[38]}));
MSKand_opini2_d2 u_m_39 (
    .ina({xm_d1[39], xm_d0[39]}), .inb({coutr1, coutr0}),
    .rnd(r[553]), .s(s[553]), .clk(clk), .out({w_m1[39], w_m0[39]}));
MSKand_opini2_d2 u_m_40 (
    .ina({xm_d1[40], xm_d0[40]}), .inb({coutr1, coutr0}),
    .rnd(r[554]), .s(s[554]), .clk(clk), .out({w_m1[40], w_m0[40]}));
MSKand_opini2_d2 u_m_41 (
    .ina({xm_d1[41], xm_d0[41]}), .inb({coutr1, coutr0}),
    .rnd(r[555]), .s(s[555]), .clk(clk), .out({w_m1[41], w_m0[41]}));
MSKand_opini2_d2 u_m_42 (
    .ina({xm_d1[42], xm_d0[42]}), .inb({coutr1, coutr0}),
    .rnd(r[556]), .s(s[556]), .clk(clk), .out({w_m1[42], w_m0[42]}));
MSKand_opini2_d2 u_m_43 (
    .ina({xm_d1[43], xm_d0[43]}), .inb({coutr1, coutr0}),
    .rnd(r[557]), .s(s[557]), .clk(clk), .out({w_m1[43], w_m0[43]}));
MSKand_opini2_d2 u_m_44 (
    .ina({xm_d1[44], xm_d0[44]}), .inb({coutr1, coutr0}),
    .rnd(r[558]), .s(s[558]), .clk(clk), .out({w_m1[44], w_m0[44]}));
MSKand_opini2_d2 u_m_45 (
    .ina({xm_d1[45], xm_d0[45]}), .inb({coutr1, coutr0}),
    .rnd(r[559]), .s(s[559]), .clk(clk), .out({w_m1[45], w_m0[45]}));
MSKand_opini2_d2 u_m_46 (
    .ina({xm_d1[46], xm_d0[46]}), .inb({coutr1, coutr0}),
    .rnd(r[560]), .s(s[560]), .clk(clk), .out({w_m1[46], w_m0[46]}));
MSKand_opini2_d2 u_m_47 (
    .ina({xm_d1[47], xm_d0[47]}), .inb({coutr1, coutr0}),
    .rnd(r[561]), .s(s[561]), .clk(clk), .out({w_m1[47], w_m0[47]}));
MSKand_opini2_d2 u_m_48 (
    .ina({xm_d1[48], xm_d0[48]}), .inb({coutr1, coutr0}),
    .rnd(r[562]), .s(s[562]), .clk(clk), .out({w_m1[48], w_m0[48]}));
MSKand_opini2_d2 u_m_49 (
    .ina({xm_d1[49], xm_d0[49]}), .inb({coutr1, coutr0}),
    .rnd(r[563]), .s(s[563]), .clk(clk), .out({w_m1[49], w_m0[49]}));
MSKand_opini2_d2 u_m_50 (
    .ina({xm_d1[50], xm_d0[50]}), .inb({coutr1, coutr0}),
    .rnd(r[564]), .s(s[564]), .clk(clk), .out({w_m1[50], w_m0[50]}));
MSKand_opini2_d2 u_m_51 (
    .ina({xm_d1[51], xm_d0[51]}), .inb({coutr1, coutr0}),
    .rnd(r[565]), .s(s[565]), .clk(clk), .out({w_m1[51], w_m0[51]}));
MSKand_opini2_d2 u_m_52 (
    .ina({xm_d1[52], xm_d0[52]}), .inb({coutr1, coutr0}),
    .rnd(r[566]), .s(s[566]), .clk(clk), .out({w_m1[52], w_m0[52]}));
MSKand_opini2_d2 u_m_53 (
    .ina({xm_d1[53], xm_d0[53]}), .inb({coutr1, coutr0}),
    .rnd(r[567]), .s(s[567]), .clk(clk), .out({w_m1[53], w_m0[53]}));
MSKand_opini2_d2 u_m_54 (
    .ina({xm_d1[54], xm_d0[54]}), .inb({coutr1, coutr0}),
    .rnd(r[568]), .s(s[568]), .clk(clk), .out({w_m1[54], w_m0[54]}));
MSKand_opini2_d2 u_m_55 (
    .ina({xm_d1[55], xm_d0[55]}), .inb({coutr1, coutr0}),
    .rnd(r[569]), .s(s[569]), .clk(clk), .out({w_m1[55], w_m0[55]}));
MSKand_opini2_d2 u_m_56 (
    .ina({xm_d1[56], xm_d0[56]}), .inb({coutr1, coutr0}),
    .rnd(r[570]), .s(s[570]), .clk(clk), .out({w_m1[56], w_m0[56]}));
MSKand_opini2_d2 u_m_57 (
    .ina({xm_d1[57], xm_d0[57]}), .inb({coutr1, coutr0}),
    .rnd(r[571]), .s(s[571]), .clk(clk), .out({w_m1[57], w_m0[57]}));
MSKand_opini2_d2 u_m_58 (
    .ina({xm_d1[58], xm_d0[58]}), .inb({coutr1, coutr0}),
    .rnd(r[572]), .s(s[572]), .clk(clk), .out({w_m1[58], w_m0[58]}));
MSKand_opini2_d2 u_m_59 (
    .ina({xm_d1[59], xm_d0[59]}), .inb({coutr1, coutr0}),
    .rnd(r[573]), .s(s[573]), .clk(clk), .out({w_m1[59], w_m0[59]}));
MSKand_opini2_d2 u_m_60 (
    .ina({xm_d1[60], xm_d0[60]}), .inb({coutr1, coutr0}),
    .rnd(r[574]), .s(s[574]), .clk(clk), .out({w_m1[60], w_m0[60]}));
MSKand_opini2_d2 u_m_61 (
    .ina({xm_d1[61], xm_d0[61]}), .inb({coutr1, coutr0}),
    .rnd(r[575]), .s(s[575]), .clk(clk), .out({w_m1[61], w_m0[61]}));
MSKand_opini2_d2 u_m_62 (
    .ina({xm_d1[62], xm_d0[62]}), .inb({coutr1, coutr0}),
    .rnd(r[576]), .s(s[576]), .clk(clk), .out({w_m1[62], w_m0[62]}));
MSKand_opini2_d2 u_m_63 (
    .ina({xm_d1[63], xm_d0[63]}), .inb({coutr1, coutr0}),
    .rnd(r[577]), .s(s[577]), .clk(clk), .out({w_m1[63], w_m0[63]}));
MSKand_opini2_d2 u_m_64 (
    .ina({xm_d1[64], xm_d0[64]}), .inb({coutr1, coutr0}),
    .rnd(r[578]), .s(s[578]), .clk(clk), .out({w_m1[64], w_m0[64]}));
MSKand_opini2_d2 u_m_65 (
    .ina({xm_d1[65], xm_d0[65]}), .inb({coutr1, coutr0}),
    .rnd(r[579]), .s(s[579]), .clk(clk), .out({w_m1[65], w_m0[65]}));
MSKand_opini2_d2 u_m_66 (
    .ina({xm_d1[66], xm_d0[66]}), .inb({coutr1, coutr0}),
    .rnd(r[580]), .s(s[580]), .clk(clk), .out({w_m1[66], w_m0[66]}));
MSKand_opini2_d2 u_m_67 (
    .ina({xm_d1[67], xm_d0[67]}), .inb({coutr1, coutr0}),
    .rnd(r[581]), .s(s[581]), .clk(clk), .out({w_m1[67], w_m0[67]}));
MSKand_opini2_d2 u_m_68 (
    .ina({xm_d1[68], xm_d0[68]}), .inb({coutr1, coutr0}),
    .rnd(r[582]), .s(s[582]), .clk(clk), .out({w_m1[68], w_m0[68]}));
MSKand_opini2_d2 u_m_69 (
    .ina({xm_d1[69], xm_d0[69]}), .inb({coutr1, coutr0}),
    .rnd(r[583]), .s(s[583]), .clk(clk), .out({w_m1[69], w_m0[69]}));
MSKand_opini2_d2 u_m_70 (
    .ina({xm_d1[70], xm_d0[70]}), .inb({coutr1, coutr0}),
    .rnd(r[584]), .s(s[584]), .clk(clk), .out({w_m1[70], w_m0[70]}));
MSKand_opini2_d2 u_m_71 (
    .ina({xm_d1[71], xm_d0[71]}), .inb({coutr1, coutr0}),
    .rnd(r[585]), .s(s[585]), .clk(clk), .out({w_m1[71], w_m0[71]}));
MSKand_opini2_d2 u_m_72 (
    .ina({xm_d1[72], xm_d0[72]}), .inb({coutr1, coutr0}),
    .rnd(r[586]), .s(s[586]), .clk(clk), .out({w_m1[72], w_m0[72]}));
MSKand_opini2_d2 u_m_73 (
    .ina({xm_d1[73], xm_d0[73]}), .inb({coutr1, coutr0}),
    .rnd(r[587]), .s(s[587]), .clk(clk), .out({w_m1[73], w_m0[73]}));
MSKand_opini2_d2 u_m_74 (
    .ina({xm_d1[74], xm_d0[74]}), .inb({coutr1, coutr0}),
    .rnd(r[588]), .s(s[588]), .clk(clk), .out({w_m1[74], w_m0[74]}));
MSKand_opini2_d2 u_m_75 (
    .ina({xm_d1[75], xm_d0[75]}), .inb({coutr1, coutr0}),
    .rnd(r[589]), .s(s[589]), .clk(clk), .out({w_m1[75], w_m0[75]}));
MSKand_opini2_d2 u_m_76 (
    .ina({xm_d1[76], xm_d0[76]}), .inb({coutr1, coutr0}),
    .rnd(r[590]), .s(s[590]), .clk(clk), .out({w_m1[76], w_m0[76]}));
MSKand_opini2_d2 u_m_77 (
    .ina({xm_d1[77], xm_d0[77]}), .inb({coutr1, coutr0}),
    .rnd(r[591]), .s(s[591]), .clk(clk), .out({w_m1[77], w_m0[77]}));
MSKand_opini2_d2 u_m_78 (
    .ina({xm_d1[78], xm_d0[78]}), .inb({coutr1, coutr0}),
    .rnd(r[592]), .s(s[592]), .clk(clk), .out({w_m1[78], w_m0[78]}));
MSKand_opini2_d2 u_m_79 (
    .ina({xm_d1[79], xm_d0[79]}), .inb({coutr1, coutr0}),
    .rnd(r[593]), .s(s[593]), .clk(clk), .out({w_m1[79], w_m0[79]}));
MSKand_opini2_d2 u_m_80 (
    .ina({xm_d1[80], xm_d0[80]}), .inb({coutr1, coutr0}),
    .rnd(r[594]), .s(s[594]), .clk(clk), .out({w_m1[80], w_m0[80]}));
MSKand_opini2_d2 u_m_81 (
    .ina({xm_d1[81], xm_d0[81]}), .inb({coutr1, coutr0}),
    .rnd(r[595]), .s(s[595]), .clk(clk), .out({w_m1[81], w_m0[81]}));
MSKand_opini2_d2 u_m_82 (
    .ina({xm_d1[82], xm_d0[82]}), .inb({coutr1, coutr0}),
    .rnd(r[596]), .s(s[596]), .clk(clk), .out({w_m1[82], w_m0[82]}));
MSKand_opini2_d2 u_m_83 (
    .ina({xm_d1[83], xm_d0[83]}), .inb({coutr1, coutr0}),
    .rnd(r[597]), .s(s[597]), .clk(clk), .out({w_m1[83], w_m0[83]}));
MSKand_opini2_d2 u_m_84 (
    .ina({xm_d1[84], xm_d0[84]}), .inb({coutr1, coutr0}),
    .rnd(r[598]), .s(s[598]), .clk(clk), .out({w_m1[84], w_m0[84]}));
MSKand_opini2_d2 u_m_85 (
    .ina({xm_d1[85], xm_d0[85]}), .inb({coutr1, coutr0}),
    .rnd(r[599]), .s(s[599]), .clk(clk), .out({w_m1[85], w_m0[85]}));
MSKand_opini2_d2 u_m_86 (
    .ina({xm_d1[86], xm_d0[86]}), .inb({coutr1, coutr0}),
    .rnd(r[600]), .s(s[600]), .clk(clk), .out({w_m1[86], w_m0[86]}));
MSKand_opini2_d2 u_m_87 (
    .ina({xm_d1[87], xm_d0[87]}), .inb({coutr1, coutr0}),
    .rnd(r[601]), .s(s[601]), .clk(clk), .out({w_m1[87], w_m0[87]}));
MSKand_opini2_d2 u_m_88 (
    .ina({xm_d1[88], xm_d0[88]}), .inb({coutr1, coutr0}),
    .rnd(r[602]), .s(s[602]), .clk(clk), .out({w_m1[88], w_m0[88]}));
MSKand_opini2_d2 u_m_89 (
    .ina({xm_d1[89], xm_d0[89]}), .inb({coutr1, coutr0}),
    .rnd(r[603]), .s(s[603]), .clk(clk), .out({w_m1[89], w_m0[89]}));
MSKand_opini2_d2 u_m_90 (
    .ina({xm_d1[90], xm_d0[90]}), .inb({coutr1, coutr0}),
    .rnd(r[604]), .s(s[604]), .clk(clk), .out({w_m1[90], w_m0[90]}));
MSKand_opini2_d2 u_m_91 (
    .ina({xm_d1[91], xm_d0[91]}), .inb({coutr1, coutr0}),
    .rnd(r[605]), .s(s[605]), .clk(clk), .out({w_m1[91], w_m0[91]}));
MSKand_opini2_d2 u_m_92 (
    .ina({xm_d1[92], xm_d0[92]}), .inb({coutr1, coutr0}),
    .rnd(r[606]), .s(s[606]), .clk(clk), .out({w_m1[92], w_m0[92]}));
MSKand_opini2_d2 u_m_93 (
    .ina({xm_d1[93], xm_d0[93]}), .inb({coutr1, coutr0}),
    .rnd(r[607]), .s(s[607]), .clk(clk), .out({w_m1[93], w_m0[93]}));
MSKand_opini2_d2 u_m_94 (
    .ina({xm_d1[94], xm_d0[94]}), .inb({coutr1, coutr0}),
    .rnd(r[608]), .s(s[608]), .clk(clk), .out({w_m1[94], w_m0[94]}));
MSKand_opini2_d2 u_m_95 (
    .ina({xm_d1[95], xm_d0[95]}), .inb({coutr1, coutr0}),
    .rnd(r[609]), .s(s[609]), .clk(clk), .out({w_m1[95], w_m0[95]}));
MSKand_opini2_d2 u_m_96 (
    .ina({xm_d1[96], xm_d0[96]}), .inb({coutr1, coutr0}),
    .rnd(r[610]), .s(s[610]), .clk(clk), .out({w_m1[96], w_m0[96]}));
MSKand_opini2_d2 u_m_97 (
    .ina({xm_d1[97], xm_d0[97]}), .inb({coutr1, coutr0}),
    .rnd(r[611]), .s(s[611]), .clk(clk), .out({w_m1[97], w_m0[97]}));
MSKand_opini2_d2 u_m_98 (
    .ina({xm_d1[98], xm_d0[98]}), .inb({coutr1, coutr0}),
    .rnd(r[612]), .s(s[612]), .clk(clk), .out({w_m1[98], w_m0[98]}));
MSKand_opini2_d2 u_m_99 (
    .ina({xm_d1[99], xm_d0[99]}), .inb({coutr1, coutr0}),
    .rnd(r[613]), .s(s[613]), .clk(clk), .out({w_m1[99], w_m0[99]}));
MSKand_opini2_d2 u_m_100 (
    .ina({xm_d1[100], xm_d0[100]}), .inb({coutr1, coutr0}),
    .rnd(r[614]), .s(s[614]), .clk(clk), .out({w_m1[100], w_m0[100]}));
MSKand_opini2_d2 u_m_101 (
    .ina({xm_d1[101], xm_d0[101]}), .inb({coutr1, coutr0}),
    .rnd(r[615]), .s(s[615]), .clk(clk), .out({w_m1[101], w_m0[101]}));
MSKand_opini2_d2 u_m_102 (
    .ina({xm_d1[102], xm_d0[102]}), .inb({coutr1, coutr0}),
    .rnd(r[616]), .s(s[616]), .clk(clk), .out({w_m1[102], w_m0[102]}));
MSKand_opini2_d2 u_m_103 (
    .ina({xm_d1[103], xm_d0[103]}), .inb({coutr1, coutr0}),
    .rnd(r[617]), .s(s[617]), .clk(clk), .out({w_m1[103], w_m0[103]}));
MSKand_opini2_d2 u_m_104 (
    .ina({xm_d1[104], xm_d0[104]}), .inb({coutr1, coutr0}),
    .rnd(r[618]), .s(s[618]), .clk(clk), .out({w_m1[104], w_m0[104]}));
MSKand_opini2_d2 u_m_105 (
    .ina({xm_d1[105], xm_d0[105]}), .inb({coutr1, coutr0}),
    .rnd(r[619]), .s(s[619]), .clk(clk), .out({w_m1[105], w_m0[105]}));
MSKand_opini2_d2 u_m_106 (
    .ina({xm_d1[106], xm_d0[106]}), .inb({coutr1, coutr0}),
    .rnd(r[620]), .s(s[620]), .clk(clk), .out({w_m1[106], w_m0[106]}));
MSKand_opini2_d2 u_m_107 (
    .ina({xm_d1[107], xm_d0[107]}), .inb({coutr1, coutr0}),
    .rnd(r[621]), .s(s[621]), .clk(clk), .out({w_m1[107], w_m0[107]}));
MSKand_opini2_d2 u_m_108 (
    .ina({xm_d1[108], xm_d0[108]}), .inb({coutr1, coutr0}),
    .rnd(r[622]), .s(s[622]), .clk(clk), .out({w_m1[108], w_m0[108]}));
MSKand_opini2_d2 u_m_109 (
    .ina({xm_d1[109], xm_d0[109]}), .inb({coutr1, coutr0}),
    .rnd(r[623]), .s(s[623]), .clk(clk), .out({w_m1[109], w_m0[109]}));
MSKand_opini2_d2 u_m_110 (
    .ina({xm_d1[110], xm_d0[110]}), .inb({coutr1, coutr0}),
    .rnd(r[624]), .s(s[624]), .clk(clk), .out({w_m1[110], w_m0[110]}));
MSKand_opini2_d2 u_m_111 (
    .ina({xm_d1[111], xm_d0[111]}), .inb({coutr1, coutr0}),
    .rnd(r[625]), .s(s[625]), .clk(clk), .out({w_m1[111], w_m0[111]}));
MSKand_opini2_d2 u_m_112 (
    .ina({xm_d1[112], xm_d0[112]}), .inb({coutr1, coutr0}),
    .rnd(r[626]), .s(s[626]), .clk(clk), .out({w_m1[112], w_m0[112]}));
MSKand_opini2_d2 u_m_113 (
    .ina({xm_d1[113], xm_d0[113]}), .inb({coutr1, coutr0}),
    .rnd(r[627]), .s(s[627]), .clk(clk), .out({w_m1[113], w_m0[113]}));
MSKand_opini2_d2 u_m_114 (
    .ina({xm_d1[114], xm_d0[114]}), .inb({coutr1, coutr0}),
    .rnd(r[628]), .s(s[628]), .clk(clk), .out({w_m1[114], w_m0[114]}));
MSKand_opini2_d2 u_m_115 (
    .ina({xm_d1[115], xm_d0[115]}), .inb({coutr1, coutr0}),
    .rnd(r[629]), .s(s[629]), .clk(clk), .out({w_m1[115], w_m0[115]}));
MSKand_opini2_d2 u_m_116 (
    .ina({xm_d1[116], xm_d0[116]}), .inb({coutr1, coutr0}),
    .rnd(r[630]), .s(s[630]), .clk(clk), .out({w_m1[116], w_m0[116]}));
MSKand_opini2_d2 u_m_117 (
    .ina({xm_d1[117], xm_d0[117]}), .inb({coutr1, coutr0}),
    .rnd(r[631]), .s(s[631]), .clk(clk), .out({w_m1[117], w_m0[117]}));
MSKand_opini2_d2 u_m_118 (
    .ina({xm_d1[118], xm_d0[118]}), .inb({coutr1, coutr0}),
    .rnd(r[632]), .s(s[632]), .clk(clk), .out({w_m1[118], w_m0[118]}));
MSKand_opini2_d2 u_m_119 (
    .ina({xm_d1[119], xm_d0[119]}), .inb({coutr1, coutr0}),
    .rnd(r[633]), .s(s[633]), .clk(clk), .out({w_m1[119], w_m0[119]}));
MSKand_opini2_d2 u_m_120 (
    .ina({xm_d1[120], xm_d0[120]}), .inb({coutr1, coutr0}),
    .rnd(r[634]), .s(s[634]), .clk(clk), .out({w_m1[120], w_m0[120]}));
MSKand_opini2_d2 u_m_121 (
    .ina({xm_d1[121], xm_d0[121]}), .inb({coutr1, coutr0}),
    .rnd(r[635]), .s(s[635]), .clk(clk), .out({w_m1[121], w_m0[121]}));
MSKand_opini2_d2 u_m_122 (
    .ina({xm_d1[122], xm_d0[122]}), .inb({coutr1, coutr0}),
    .rnd(r[636]), .s(s[636]), .clk(clk), .out({w_m1[122], w_m0[122]}));
MSKand_opini2_d2 u_m_123 (
    .ina({xm_d1[123], xm_d0[123]}), .inb({coutr1, coutr0}),
    .rnd(r[637]), .s(s[637]), .clk(clk), .out({w_m1[123], w_m0[123]}));
MSKand_opini2_d2 u_m_124 (
    .ina({xm_d1[124], xm_d0[124]}), .inb({coutr1, coutr0}),
    .rnd(r[638]), .s(s[638]), .clk(clk), .out({w_m1[124], w_m0[124]}));
MSKand_opini2_d2 u_m_125 (
    .ina({xm_d1[125], xm_d0[125]}), .inb({coutr1, coutr0}),
    .rnd(r[639]), .s(s[639]), .clk(clk), .out({w_m1[125], w_m0[125]}));
MSKand_opini2_d2 u_m_126 (
    .ina({xm_d1[126], xm_d0[126]}), .inb({coutr1, coutr0}),
    .rnd(r[640]), .s(s[640]), .clk(clk), .out({w_m1[126], w_m0[126]}));
MSKand_opini2_d2 u_m_127 (
    .ina({xm_d1[127], xm_d0[127]}), .inb({coutr1, coutr0}),
    .rnd(r[641]), .s(s[641]), .clk(clk), .out({w_m1[127], w_m0[127]}));
MSKand_opini2_d2 u_m_128 (
    .ina({xm_d1[128], xm_d0[128]}), .inb({coutr1, coutr0}),
    .rnd(r[642]), .s(s[642]), .clk(clk), .out({w_m1[128], w_m0[128]}));
MSKand_opini2_d2 u_m_129 (
    .ina({xm_d1[129], xm_d0[129]}), .inb({coutr1, coutr0}),
    .rnd(r[643]), .s(s[643]), .clk(clk), .out({w_m1[129], w_m0[129]}));
MSKand_opini2_d2 u_m_130 (
    .ina({xm_d1[130], xm_d0[130]}), .inb({coutr1, coutr0}),
    .rnd(r[644]), .s(s[644]), .clk(clk), .out({w_m1[130], w_m0[130]}));
MSKand_opini2_d2 u_m_131 (
    .ina({xm_d1[131], xm_d0[131]}), .inb({coutr1, coutr0}),
    .rnd(r[645]), .s(s[645]), .clk(clk), .out({w_m1[131], w_m0[131]}));
MSKand_opini2_d2 u_m_132 (
    .ina({xm_d1[132], xm_d0[132]}), .inb({coutr1, coutr0}),
    .rnd(r[646]), .s(s[646]), .clk(clk), .out({w_m1[132], w_m0[132]}));
MSKand_opini2_d2 u_m_133 (
    .ina({xm_d1[133], xm_d0[133]}), .inb({coutr1, coutr0}),
    .rnd(r[647]), .s(s[647]), .clk(clk), .out({w_m1[133], w_m0[133]}));
MSKand_opini2_d2 u_m_134 (
    .ina({xm_d1[134], xm_d0[134]}), .inb({coutr1, coutr0}),
    .rnd(r[648]), .s(s[648]), .clk(clk), .out({w_m1[134], w_m0[134]}));
MSKand_opini2_d2 u_m_135 (
    .ina({xm_d1[135], xm_d0[135]}), .inb({coutr1, coutr0}),
    .rnd(r[649]), .s(s[649]), .clk(clk), .out({w_m1[135], w_m0[135]}));
MSKand_opini2_d2 u_m_136 (
    .ina({xm_d1[136], xm_d0[136]}), .inb({coutr1, coutr0}),
    .rnd(r[650]), .s(s[650]), .clk(clk), .out({w_m1[136], w_m0[136]}));
MSKand_opini2_d2 u_m_137 (
    .ina({xm_d1[137], xm_d0[137]}), .inb({coutr1, coutr0}),
    .rnd(r[651]), .s(s[651]), .clk(clk), .out({w_m1[137], w_m0[137]}));
MSKand_opini2_d2 u_m_138 (
    .ina({xm_d1[138], xm_d0[138]}), .inb({coutr1, coutr0}),
    .rnd(r[652]), .s(s[652]), .clk(clk), .out({w_m1[138], w_m0[138]}));
MSKand_opini2_d2 u_m_139 (
    .ina({xm_d1[139], xm_d0[139]}), .inb({coutr1, coutr0}),
    .rnd(r[653]), .s(s[653]), .clk(clk), .out({w_m1[139], w_m0[139]}));
MSKand_opini2_d2 u_m_140 (
    .ina({xm_d1[140], xm_d0[140]}), .inb({coutr1, coutr0}),
    .rnd(r[654]), .s(s[654]), .clk(clk), .out({w_m1[140], w_m0[140]}));
MSKand_opini2_d2 u_m_141 (
    .ina({xm_d1[141], xm_d0[141]}), .inb({coutr1, coutr0}),
    .rnd(r[655]), .s(s[655]), .clk(clk), .out({w_m1[141], w_m0[141]}));
MSKand_opini2_d2 u_m_142 (
    .ina({xm_d1[142], xm_d0[142]}), .inb({coutr1, coutr0}),
    .rnd(r[656]), .s(s[656]), .clk(clk), .out({w_m1[142], w_m0[142]}));
MSKand_opini2_d2 u_m_143 (
    .ina({xm_d1[143], xm_d0[143]}), .inb({coutr1, coutr0}),
    .rnd(r[657]), .s(s[657]), .clk(clk), .out({w_m1[143], w_m0[143]}));
MSKand_opini2_d2 u_m_144 (
    .ina({xm_d1[144], xm_d0[144]}), .inb({coutr1, coutr0}),
    .rnd(r[658]), .s(s[658]), .clk(clk), .out({w_m1[144], w_m0[144]}));
MSKand_opini2_d2 u_m_145 (
    .ina({xm_d1[145], xm_d0[145]}), .inb({coutr1, coutr0}),
    .rnd(r[659]), .s(s[659]), .clk(clk), .out({w_m1[145], w_m0[145]}));
MSKand_opini2_d2 u_m_146 (
    .ina({xm_d1[146], xm_d0[146]}), .inb({coutr1, coutr0}),
    .rnd(r[660]), .s(s[660]), .clk(clk), .out({w_m1[146], w_m0[146]}));
MSKand_opini2_d2 u_m_147 (
    .ina({xm_d1[147], xm_d0[147]}), .inb({coutr1, coutr0}),
    .rnd(r[661]), .s(s[661]), .clk(clk), .out({w_m1[147], w_m0[147]}));
MSKand_opini2_d2 u_m_148 (
    .ina({xm_d1[148], xm_d0[148]}), .inb({coutr1, coutr0}),
    .rnd(r[662]), .s(s[662]), .clk(clk), .out({w_m1[148], w_m0[148]}));
MSKand_opini2_d2 u_m_149 (
    .ina({xm_d1[149], xm_d0[149]}), .inb({coutr1, coutr0}),
    .rnd(r[663]), .s(s[663]), .clk(clk), .out({w_m1[149], w_m0[149]}));
MSKand_opini2_d2 u_m_150 (
    .ina({xm_d1[150], xm_d0[150]}), .inb({coutr1, coutr0}),
    .rnd(r[664]), .s(s[664]), .clk(clk), .out({w_m1[150], w_m0[150]}));
MSKand_opini2_d2 u_m_151 (
    .ina({xm_d1[151], xm_d0[151]}), .inb({coutr1, coutr0}),
    .rnd(r[665]), .s(s[665]), .clk(clk), .out({w_m1[151], w_m0[151]}));
MSKand_opini2_d2 u_m_152 (
    .ina({xm_d1[152], xm_d0[152]}), .inb({coutr1, coutr0}),
    .rnd(r[666]), .s(s[666]), .clk(clk), .out({w_m1[152], w_m0[152]}));
MSKand_opini2_d2 u_m_153 (
    .ina({xm_d1[153], xm_d0[153]}), .inb({coutr1, coutr0}),
    .rnd(r[667]), .s(s[667]), .clk(clk), .out({w_m1[153], w_m0[153]}));
MSKand_opini2_d2 u_m_154 (
    .ina({xm_d1[154], xm_d0[154]}), .inb({coutr1, coutr0}),
    .rnd(r[668]), .s(s[668]), .clk(clk), .out({w_m1[154], w_m0[154]}));
MSKand_opini2_d2 u_m_155 (
    .ina({xm_d1[155], xm_d0[155]}), .inb({coutr1, coutr0}),
    .rnd(r[669]), .s(s[669]), .clk(clk), .out({w_m1[155], w_m0[155]}));
MSKand_opini2_d2 u_m_156 (
    .ina({xm_d1[156], xm_d0[156]}), .inb({coutr1, coutr0}),
    .rnd(r[670]), .s(s[670]), .clk(clk), .out({w_m1[156], w_m0[156]}));
MSKand_opini2_d2 u_m_157 (
    .ina({xm_d1[157], xm_d0[157]}), .inb({coutr1, coutr0}),
    .rnd(r[671]), .s(s[671]), .clk(clk), .out({w_m1[157], w_m0[157]}));
MSKand_opini2_d2 u_m_158 (
    .ina({xm_d1[158], xm_d0[158]}), .inb({coutr1, coutr0}),
    .rnd(r[672]), .s(s[672]), .clk(clk), .out({w_m1[158], w_m0[158]}));
MSKand_opini2_d2 u_m_159 (
    .ina({xm_d1[159], xm_d0[159]}), .inb({coutr1, coutr0}),
    .rnd(r[673]), .s(s[673]), .clk(clk), .out({w_m1[159], w_m0[159]}));
MSKand_opini2_d2 u_m_160 (
    .ina({xm_d1[160], xm_d0[160]}), .inb({coutr1, coutr0}),
    .rnd(r[674]), .s(s[674]), .clk(clk), .out({w_m1[160], w_m0[160]}));
MSKand_opini2_d2 u_m_161 (
    .ina({xm_d1[161], xm_d0[161]}), .inb({coutr1, coutr0}),
    .rnd(r[675]), .s(s[675]), .clk(clk), .out({w_m1[161], w_m0[161]}));
MSKand_opini2_d2 u_m_162 (
    .ina({xm_d1[162], xm_d0[162]}), .inb({coutr1, coutr0}),
    .rnd(r[676]), .s(s[676]), .clk(clk), .out({w_m1[162], w_m0[162]}));
MSKand_opini2_d2 u_m_163 (
    .ina({xm_d1[163], xm_d0[163]}), .inb({coutr1, coutr0}),
    .rnd(r[677]), .s(s[677]), .clk(clk), .out({w_m1[163], w_m0[163]}));
MSKand_opini2_d2 u_m_164 (
    .ina({xm_d1[164], xm_d0[164]}), .inb({coutr1, coutr0}),
    .rnd(r[678]), .s(s[678]), .clk(clk), .out({w_m1[164], w_m0[164]}));
MSKand_opini2_d2 u_m_165 (
    .ina({xm_d1[165], xm_d0[165]}), .inb({coutr1, coutr0}),
    .rnd(r[679]), .s(s[679]), .clk(clk), .out({w_m1[165], w_m0[165]}));
MSKand_opini2_d2 u_m_166 (
    .ina({xm_d1[166], xm_d0[166]}), .inb({coutr1, coutr0}),
    .rnd(r[680]), .s(s[680]), .clk(clk), .out({w_m1[166], w_m0[166]}));
MSKand_opini2_d2 u_m_167 (
    .ina({xm_d1[167], xm_d0[167]}), .inb({coutr1, coutr0}),
    .rnd(r[681]), .s(s[681]), .clk(clk), .out({w_m1[167], w_m0[167]}));
MSKand_opini2_d2 u_m_168 (
    .ina({xm_d1[168], xm_d0[168]}), .inb({coutr1, coutr0}),
    .rnd(r[682]), .s(s[682]), .clk(clk), .out({w_m1[168], w_m0[168]}));
MSKand_opini2_d2 u_m_169 (
    .ina({xm_d1[169], xm_d0[169]}), .inb({coutr1, coutr0}),
    .rnd(r[683]), .s(s[683]), .clk(clk), .out({w_m1[169], w_m0[169]}));
MSKand_opini2_d2 u_m_170 (
    .ina({xm_d1[170], xm_d0[170]}), .inb({coutr1, coutr0}),
    .rnd(r[684]), .s(s[684]), .clk(clk), .out({w_m1[170], w_m0[170]}));
MSKand_opini2_d2 u_m_171 (
    .ina({xm_d1[171], xm_d0[171]}), .inb({coutr1, coutr0}),
    .rnd(r[685]), .s(s[685]), .clk(clk), .out({w_m1[171], w_m0[171]}));
MSKand_opini2_d2 u_m_172 (
    .ina({xm_d1[172], xm_d0[172]}), .inb({coutr1, coutr0}),
    .rnd(r[686]), .s(s[686]), .clk(clk), .out({w_m1[172], w_m0[172]}));
MSKand_opini2_d2 u_m_173 (
    .ina({xm_d1[173], xm_d0[173]}), .inb({coutr1, coutr0}),
    .rnd(r[687]), .s(s[687]), .clk(clk), .out({w_m1[173], w_m0[173]}));
MSKand_opini2_d2 u_m_174 (
    .ina({xm_d1[174], xm_d0[174]}), .inb({coutr1, coutr0}),
    .rnd(r[688]), .s(s[688]), .clk(clk), .out({w_m1[174], w_m0[174]}));
MSKand_opini2_d2 u_m_175 (
    .ina({xm_d1[175], xm_d0[175]}), .inb({coutr1, coutr0}),
    .rnd(r[689]), .s(s[689]), .clk(clk), .out({w_m1[175], w_m0[175]}));
MSKand_opini2_d2 u_m_176 (
    .ina({xm_d1[176], xm_d0[176]}), .inb({coutr1, coutr0}),
    .rnd(r[690]), .s(s[690]), .clk(clk), .out({w_m1[176], w_m0[176]}));
MSKand_opini2_d2 u_m_177 (
    .ina({xm_d1[177], xm_d0[177]}), .inb({coutr1, coutr0}),
    .rnd(r[691]), .s(s[691]), .clk(clk), .out({w_m1[177], w_m0[177]}));
MSKand_opini2_d2 u_m_178 (
    .ina({xm_d1[178], xm_d0[178]}), .inb({coutr1, coutr0}),
    .rnd(r[692]), .s(s[692]), .clk(clk), .out({w_m1[178], w_m0[178]}));
MSKand_opini2_d2 u_m_179 (
    .ina({xm_d1[179], xm_d0[179]}), .inb({coutr1, coutr0}),
    .rnd(r[693]), .s(s[693]), .clk(clk), .out({w_m1[179], w_m0[179]}));
MSKand_opini2_d2 u_m_180 (
    .ina({xm_d1[180], xm_d0[180]}), .inb({coutr1, coutr0}),
    .rnd(r[694]), .s(s[694]), .clk(clk), .out({w_m1[180], w_m0[180]}));
MSKand_opini2_d2 u_m_181 (
    .ina({xm_d1[181], xm_d0[181]}), .inb({coutr1, coutr0}),
    .rnd(r[695]), .s(s[695]), .clk(clk), .out({w_m1[181], w_m0[181]}));
MSKand_opini2_d2 u_m_182 (
    .ina({xm_d1[182], xm_d0[182]}), .inb({coutr1, coutr0}),
    .rnd(r[696]), .s(s[696]), .clk(clk), .out({w_m1[182], w_m0[182]}));
MSKand_opini2_d2 u_m_183 (
    .ina({xm_d1[183], xm_d0[183]}), .inb({coutr1, coutr0}),
    .rnd(r[697]), .s(s[697]), .clk(clk), .out({w_m1[183], w_m0[183]}));
MSKand_opini2_d2 u_m_184 (
    .ina({xm_d1[184], xm_d0[184]}), .inb({coutr1, coutr0}),
    .rnd(r[698]), .s(s[698]), .clk(clk), .out({w_m1[184], w_m0[184]}));
MSKand_opini2_d2 u_m_185 (
    .ina({xm_d1[185], xm_d0[185]}), .inb({coutr1, coutr0}),
    .rnd(r[699]), .s(s[699]), .clk(clk), .out({w_m1[185], w_m0[185]}));
MSKand_opini2_d2 u_m_186 (
    .ina({xm_d1[186], xm_d0[186]}), .inb({coutr1, coutr0}),
    .rnd(r[700]), .s(s[700]), .clk(clk), .out({w_m1[186], w_m0[186]}));
MSKand_opini2_d2 u_m_187 (
    .ina({xm_d1[187], xm_d0[187]}), .inb({coutr1, coutr0}),
    .rnd(r[701]), .s(s[701]), .clk(clk), .out({w_m1[187], w_m0[187]}));
MSKand_opini2_d2 u_m_188 (
    .ina({xm_d1[188], xm_d0[188]}), .inb({coutr1, coutr0}),
    .rnd(r[702]), .s(s[702]), .clk(clk), .out({w_m1[188], w_m0[188]}));
MSKand_opini2_d2 u_m_189 (
    .ina({xm_d1[189], xm_d0[189]}), .inb({coutr1, coutr0}),
    .rnd(r[703]), .s(s[703]), .clk(clk), .out({w_m1[189], w_m0[189]}));
MSKand_opini2_d2 u_m_190 (
    .ina({xm_d1[190], xm_d0[190]}), .inb({coutr1, coutr0}),
    .rnd(r[704]), .s(s[704]), .clk(clk), .out({w_m1[190], w_m0[190]}));
MSKand_opini2_d2 u_m_191 (
    .ina({xm_d1[191], xm_d0[191]}), .inb({coutr1, coutr0}),
    .rnd(r[705]), .s(s[705]), .clk(clk), .out({w_m1[191], w_m0[191]}));
MSKand_opini2_d2 u_m_192 (
    .ina({xm_d1[192], xm_d0[192]}), .inb({coutr1, coutr0}),
    .rnd(r[706]), .s(s[706]), .clk(clk), .out({w_m1[192], w_m0[192]}));
MSKand_opini2_d2 u_m_193 (
    .ina({xm_d1[193], xm_d0[193]}), .inb({coutr1, coutr0}),
    .rnd(r[707]), .s(s[707]), .clk(clk), .out({w_m1[193], w_m0[193]}));
MSKand_opini2_d2 u_m_194 (
    .ina({xm_d1[194], xm_d0[194]}), .inb({coutr1, coutr0}),
    .rnd(r[708]), .s(s[708]), .clk(clk), .out({w_m1[194], w_m0[194]}));
MSKand_opini2_d2 u_m_195 (
    .ina({xm_d1[195], xm_d0[195]}), .inb({coutr1, coutr0}),
    .rnd(r[709]), .s(s[709]), .clk(clk), .out({w_m1[195], w_m0[195]}));
MSKand_opini2_d2 u_m_196 (
    .ina({xm_d1[196], xm_d0[196]}), .inb({coutr1, coutr0}),
    .rnd(r[710]), .s(s[710]), .clk(clk), .out({w_m1[196], w_m0[196]}));
MSKand_opini2_d2 u_m_197 (
    .ina({xm_d1[197], xm_d0[197]}), .inb({coutr1, coutr0}),
    .rnd(r[711]), .s(s[711]), .clk(clk), .out({w_m1[197], w_m0[197]}));
MSKand_opini2_d2 u_m_198 (
    .ina({xm_d1[198], xm_d0[198]}), .inb({coutr1, coutr0}),
    .rnd(r[712]), .s(s[712]), .clk(clk), .out({w_m1[198], w_m0[198]}));
MSKand_opini2_d2 u_m_199 (
    .ina({xm_d1[199], xm_d0[199]}), .inb({coutr1, coutr0}),
    .rnd(r[713]), .s(s[713]), .clk(clk), .out({w_m1[199], w_m0[199]}));
MSKand_opini2_d2 u_m_200 (
    .ina({xm_d1[200], xm_d0[200]}), .inb({coutr1, coutr0}),
    .rnd(r[714]), .s(s[714]), .clk(clk), .out({w_m1[200], w_m0[200]}));
MSKand_opini2_d2 u_m_201 (
    .ina({xm_d1[201], xm_d0[201]}), .inb({coutr1, coutr0}),
    .rnd(r[715]), .s(s[715]), .clk(clk), .out({w_m1[201], w_m0[201]}));
MSKand_opini2_d2 u_m_202 (
    .ina({xm_d1[202], xm_d0[202]}), .inb({coutr1, coutr0}),
    .rnd(r[716]), .s(s[716]), .clk(clk), .out({w_m1[202], w_m0[202]}));
MSKand_opini2_d2 u_m_203 (
    .ina({xm_d1[203], xm_d0[203]}), .inb({coutr1, coutr0}),
    .rnd(r[717]), .s(s[717]), .clk(clk), .out({w_m1[203], w_m0[203]}));
MSKand_opini2_d2 u_m_204 (
    .ina({xm_d1[204], xm_d0[204]}), .inb({coutr1, coutr0}),
    .rnd(r[718]), .s(s[718]), .clk(clk), .out({w_m1[204], w_m0[204]}));
MSKand_opini2_d2 u_m_205 (
    .ina({xm_d1[205], xm_d0[205]}), .inb({coutr1, coutr0}),
    .rnd(r[719]), .s(s[719]), .clk(clk), .out({w_m1[205], w_m0[205]}));
MSKand_opini2_d2 u_m_206 (
    .ina({xm_d1[206], xm_d0[206]}), .inb({coutr1, coutr0}),
    .rnd(r[720]), .s(s[720]), .clk(clk), .out({w_m1[206], w_m0[206]}));
MSKand_opini2_d2 u_m_207 (
    .ina({xm_d1[207], xm_d0[207]}), .inb({coutr1, coutr0}),
    .rnd(r[721]), .s(s[721]), .clk(clk), .out({w_m1[207], w_m0[207]}));
MSKand_opini2_d2 u_m_208 (
    .ina({xm_d1[208], xm_d0[208]}), .inb({coutr1, coutr0}),
    .rnd(r[722]), .s(s[722]), .clk(clk), .out({w_m1[208], w_m0[208]}));
MSKand_opini2_d2 u_m_209 (
    .ina({xm_d1[209], xm_d0[209]}), .inb({coutr1, coutr0}),
    .rnd(r[723]), .s(s[723]), .clk(clk), .out({w_m1[209], w_m0[209]}));
MSKand_opini2_d2 u_m_210 (
    .ina({xm_d1[210], xm_d0[210]}), .inb({coutr1, coutr0}),
    .rnd(r[724]), .s(s[724]), .clk(clk), .out({w_m1[210], w_m0[210]}));
MSKand_opini2_d2 u_m_211 (
    .ina({xm_d1[211], xm_d0[211]}), .inb({coutr1, coutr0}),
    .rnd(r[725]), .s(s[725]), .clk(clk), .out({w_m1[211], w_m0[211]}));
MSKand_opini2_d2 u_m_212 (
    .ina({xm_d1[212], xm_d0[212]}), .inb({coutr1, coutr0}),
    .rnd(r[726]), .s(s[726]), .clk(clk), .out({w_m1[212], w_m0[212]}));
MSKand_opini2_d2 u_m_213 (
    .ina({xm_d1[213], xm_d0[213]}), .inb({coutr1, coutr0}),
    .rnd(r[727]), .s(s[727]), .clk(clk), .out({w_m1[213], w_m0[213]}));
MSKand_opini2_d2 u_m_214 (
    .ina({xm_d1[214], xm_d0[214]}), .inb({coutr1, coutr0}),
    .rnd(r[728]), .s(s[728]), .clk(clk), .out({w_m1[214], w_m0[214]}));
MSKand_opini2_d2 u_m_215 (
    .ina({xm_d1[215], xm_d0[215]}), .inb({coutr1, coutr0}),
    .rnd(r[729]), .s(s[729]), .clk(clk), .out({w_m1[215], w_m0[215]}));
MSKand_opini2_d2 u_m_216 (
    .ina({xm_d1[216], xm_d0[216]}), .inb({coutr1, coutr0}),
    .rnd(r[730]), .s(s[730]), .clk(clk), .out({w_m1[216], w_m0[216]}));
MSKand_opini2_d2 u_m_217 (
    .ina({xm_d1[217], xm_d0[217]}), .inb({coutr1, coutr0}),
    .rnd(r[731]), .s(s[731]), .clk(clk), .out({w_m1[217], w_m0[217]}));
MSKand_opini2_d2 u_m_218 (
    .ina({xm_d1[218], xm_d0[218]}), .inb({coutr1, coutr0}),
    .rnd(r[732]), .s(s[732]), .clk(clk), .out({w_m1[218], w_m0[218]}));
MSKand_opini2_d2 u_m_219 (
    .ina({xm_d1[219], xm_d0[219]}), .inb({coutr1, coutr0}),
    .rnd(r[733]), .s(s[733]), .clk(clk), .out({w_m1[219], w_m0[219]}));
MSKand_opini2_d2 u_m_220 (
    .ina({xm_d1[220], xm_d0[220]}), .inb({coutr1, coutr0}),
    .rnd(r[734]), .s(s[734]), .clk(clk), .out({w_m1[220], w_m0[220]}));
MSKand_opini2_d2 u_m_221 (
    .ina({xm_d1[221], xm_d0[221]}), .inb({coutr1, coutr0}),
    .rnd(r[735]), .s(s[735]), .clk(clk), .out({w_m1[221], w_m0[221]}));
MSKand_opini2_d2 u_m_222 (
    .ina({xm_d1[222], xm_d0[222]}), .inb({coutr1, coutr0}),
    .rnd(r[736]), .s(s[736]), .clk(clk), .out({w_m1[222], w_m0[222]}));
MSKand_opini2_d2 u_m_223 (
    .ina({xm_d1[223], xm_d0[223]}), .inb({coutr1, coutr0}),
    .rnd(r[737]), .s(s[737]), .clk(clk), .out({w_m1[223], w_m0[223]}));
MSKand_opini2_d2 u_m_224 (
    .ina({xm_d1[224], xm_d0[224]}), .inb({coutr1, coutr0}),
    .rnd(r[738]), .s(s[738]), .clk(clk), .out({w_m1[224], w_m0[224]}));
MSKand_opini2_d2 u_m_225 (
    .ina({xm_d1[225], xm_d0[225]}), .inb({coutr1, coutr0}),
    .rnd(r[739]), .s(s[739]), .clk(clk), .out({w_m1[225], w_m0[225]}));
MSKand_opini2_d2 u_m_226 (
    .ina({xm_d1[226], xm_d0[226]}), .inb({coutr1, coutr0}),
    .rnd(r[740]), .s(s[740]), .clk(clk), .out({w_m1[226], w_m0[226]}));
MSKand_opini2_d2 u_m_227 (
    .ina({xm_d1[227], xm_d0[227]}), .inb({coutr1, coutr0}),
    .rnd(r[741]), .s(s[741]), .clk(clk), .out({w_m1[227], w_m0[227]}));
MSKand_opini2_d2 u_m_228 (
    .ina({xm_d1[228], xm_d0[228]}), .inb({coutr1, coutr0}),
    .rnd(r[742]), .s(s[742]), .clk(clk), .out({w_m1[228], w_m0[228]}));
MSKand_opini2_d2 u_m_229 (
    .ina({xm_d1[229], xm_d0[229]}), .inb({coutr1, coutr0}),
    .rnd(r[743]), .s(s[743]), .clk(clk), .out({w_m1[229], w_m0[229]}));
MSKand_opini2_d2 u_m_230 (
    .ina({xm_d1[230], xm_d0[230]}), .inb({coutr1, coutr0}),
    .rnd(r[744]), .s(s[744]), .clk(clk), .out({w_m1[230], w_m0[230]}));
MSKand_opini2_d2 u_m_231 (
    .ina({xm_d1[231], xm_d0[231]}), .inb({coutr1, coutr0}),
    .rnd(r[745]), .s(s[745]), .clk(clk), .out({w_m1[231], w_m0[231]}));
MSKand_opini2_d2 u_m_232 (
    .ina({xm_d1[232], xm_d0[232]}), .inb({coutr1, coutr0}),
    .rnd(r[746]), .s(s[746]), .clk(clk), .out({w_m1[232], w_m0[232]}));
MSKand_opini2_d2 u_m_233 (
    .ina({xm_d1[233], xm_d0[233]}), .inb({coutr1, coutr0}),
    .rnd(r[747]), .s(s[747]), .clk(clk), .out({w_m1[233], w_m0[233]}));
MSKand_opini2_d2 u_m_234 (
    .ina({xm_d1[234], xm_d0[234]}), .inb({coutr1, coutr0}),
    .rnd(r[748]), .s(s[748]), .clk(clk), .out({w_m1[234], w_m0[234]}));
MSKand_opini2_d2 u_m_235 (
    .ina({xm_d1[235], xm_d0[235]}), .inb({coutr1, coutr0}),
    .rnd(r[749]), .s(s[749]), .clk(clk), .out({w_m1[235], w_m0[235]}));
MSKand_opini2_d2 u_m_236 (
    .ina({xm_d1[236], xm_d0[236]}), .inb({coutr1, coutr0}),
    .rnd(r[750]), .s(s[750]), .clk(clk), .out({w_m1[236], w_m0[236]}));
MSKand_opini2_d2 u_m_237 (
    .ina({xm_d1[237], xm_d0[237]}), .inb({coutr1, coutr0}),
    .rnd(r[751]), .s(s[751]), .clk(clk), .out({w_m1[237], w_m0[237]}));
MSKand_opini2_d2 u_m_238 (
    .ina({xm_d1[238], xm_d0[238]}), .inb({coutr1, coutr0}),
    .rnd(r[752]), .s(s[752]), .clk(clk), .out({w_m1[238], w_m0[238]}));
MSKand_opini2_d2 u_m_239 (
    .ina({xm_d1[239], xm_d0[239]}), .inb({coutr1, coutr0}),
    .rnd(r[753]), .s(s[753]), .clk(clk), .out({w_m1[239], w_m0[239]}));
MSKand_opini2_d2 u_m_240 (
    .ina({xm_d1[240], xm_d0[240]}), .inb({coutr1, coutr0}),
    .rnd(r[754]), .s(s[754]), .clk(clk), .out({w_m1[240], w_m0[240]}));
MSKand_opini2_d2 u_m_241 (
    .ina({xm_d1[241], xm_d0[241]}), .inb({coutr1, coutr0}),
    .rnd(r[755]), .s(s[755]), .clk(clk), .out({w_m1[241], w_m0[241]}));
MSKand_opini2_d2 u_m_242 (
    .ina({xm_d1[242], xm_d0[242]}), .inb({coutr1, coutr0}),
    .rnd(r[756]), .s(s[756]), .clk(clk), .out({w_m1[242], w_m0[242]}));
MSKand_opini2_d2 u_m_243 (
    .ina({xm_d1[243], xm_d0[243]}), .inb({coutr1, coutr0}),
    .rnd(r[757]), .s(s[757]), .clk(clk), .out({w_m1[243], w_m0[243]}));
MSKand_opini2_d2 u_m_244 (
    .ina({xm_d1[244], xm_d0[244]}), .inb({coutr1, coutr0}),
    .rnd(r[758]), .s(s[758]), .clk(clk), .out({w_m1[244], w_m0[244]}));
MSKand_opini2_d2 u_m_245 (
    .ina({xm_d1[245], xm_d0[245]}), .inb({coutr1, coutr0}),
    .rnd(r[759]), .s(s[759]), .clk(clk), .out({w_m1[245], w_m0[245]}));
MSKand_opini2_d2 u_m_246 (
    .ina({xm_d1[246], xm_d0[246]}), .inb({coutr1, coutr0}),
    .rnd(r[760]), .s(s[760]), .clk(clk), .out({w_m1[246], w_m0[246]}));
MSKand_opini2_d2 u_m_247 (
    .ina({xm_d1[247], xm_d0[247]}), .inb({coutr1, coutr0}),
    .rnd(r[761]), .s(s[761]), .clk(clk), .out({w_m1[247], w_m0[247]}));
MSKand_opini2_d2 u_m_248 (
    .ina({xm_d1[248], xm_d0[248]}), .inb({coutr1, coutr0}),
    .rnd(r[762]), .s(s[762]), .clk(clk), .out({w_m1[248], w_m0[248]}));
MSKand_opini2_d2 u_m_249 (
    .ina({xm_d1[249], xm_d0[249]}), .inb({coutr1, coutr0}),
    .rnd(r[763]), .s(s[763]), .clk(clk), .out({w_m1[249], w_m0[249]}));
MSKand_opini2_d2 u_m_250 (
    .ina({xm_d1[250], xm_d0[250]}), .inb({coutr1, coutr0}),
    .rnd(r[764]), .s(s[764]), .clk(clk), .out({w_m1[250], w_m0[250]}));
MSKand_opini2_d2 u_m_251 (
    .ina({xm_d1[251], xm_d0[251]}), .inb({coutr1, coutr0}),
    .rnd(r[765]), .s(s[765]), .clk(clk), .out({w_m1[251], w_m0[251]}));
MSKand_opini2_d2 u_m_252 (
    .ina({xm_d1[252], xm_d0[252]}), .inb({coutr1, coutr0}),
    .rnd(r[766]), .s(s[766]), .clk(clk), .out({w_m1[252], w_m0[252]}));
MSKand_opini2_d2 u_m_253 (
    .ina({xm_d1[253], xm_d0[253]}), .inb({coutr1, coutr0}),
    .rnd(r[767]), .s(s[767]), .clk(clk), .out({w_m1[253], w_m0[253]}));
MSKand_opini2_d2 u_m_254 (
    .ina({xm_d1[254], xm_d0[254]}), .inb({coutr1, coutr0}),
    .rnd(r[768]), .s(s[768]), .clk(clk), .out({w_m1[254], w_m0[254]}));
MSKand_opini2_d2 u_m_255 (
    .ina({xm_d1[255], xm_d0[255]}), .inb({coutr1, coutr0}),
    .rnd(r[769]), .s(s[769]), .clk(clk), .out({w_m1[255], w_m0[255]}));

// ===== nonzero-tree OR-reduce level 0: 256 masked bits -> 128 =====
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
    .rnd(r[770]), .s(s[770]), .clk(clk), .out({w1_0, w0_0}));
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
    .rnd(r[771]), .s(s[771]), .clk(clk), .out({w1_1, w0_1}));
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
    .rnd(r[772]), .s(s[772]), .clk(clk), .out({w1_2, w0_2}));
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
    .rnd(r[773]), .s(s[773]), .clk(clk), .out({w1_3, w0_3}));
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
    .rnd(r[774]), .s(s[774]), .clk(clk), .out({w1_4, w0_4}));
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
    .rnd(r[775]), .s(s[775]), .clk(clk), .out({w1_5, w0_5}));
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
    .rnd(r[776]), .s(s[776]), .clk(clk), .out({w1_6, w0_6}));
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
    .rnd(r[777]), .s(s[777]), .clk(clk), .out({w1_7, w0_7}));
wire or0_7 = w0_7 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_7 = w1_7;
wire nx0_8 = Bz0[16] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_8 = Bz0[17] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_8, ina1_8;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_8 <= nx0_8;
    ina1_8 <= Bz1[16];
end
wire w0_8, w1_8;
MSKand_opini2_d2 u_or_8 (
    .ina({ina1_8, ina0_8}), .inb({Bz1[17], ny0_8}),
    .rnd(r[778]), .s(s[778]), .clk(clk), .out({w1_8, w0_8}));
wire or0_8 = w0_8 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_8 = w1_8;
wire nx0_9 = Bz0[18] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_9 = Bz0[19] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_9, ina1_9;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_9 <= nx0_9;
    ina1_9 <= Bz1[18];
end
wire w0_9, w1_9;
MSKand_opini2_d2 u_or_9 (
    .ina({ina1_9, ina0_9}), .inb({Bz1[19], ny0_9}),
    .rnd(r[779]), .s(s[779]), .clk(clk), .out({w1_9, w0_9}));
wire or0_9 = w0_9 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_9 = w1_9;
wire nx0_10 = Bz0[20] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_10 = Bz0[21] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_10, ina1_10;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_10 <= nx0_10;
    ina1_10 <= Bz1[20];
end
wire w0_10, w1_10;
MSKand_opini2_d2 u_or_10 (
    .ina({ina1_10, ina0_10}), .inb({Bz1[21], ny0_10}),
    .rnd(r[780]), .s(s[780]), .clk(clk), .out({w1_10, w0_10}));
wire or0_10 = w0_10 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_10 = w1_10;
wire nx0_11 = Bz0[22] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_11 = Bz0[23] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_11, ina1_11;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_11 <= nx0_11;
    ina1_11 <= Bz1[22];
end
wire w0_11, w1_11;
MSKand_opini2_d2 u_or_11 (
    .ina({ina1_11, ina0_11}), .inb({Bz1[23], ny0_11}),
    .rnd(r[781]), .s(s[781]), .clk(clk), .out({w1_11, w0_11}));
wire or0_11 = w0_11 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_11 = w1_11;
wire nx0_12 = Bz0[24] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_12 = Bz0[25] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_12, ina1_12;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_12 <= nx0_12;
    ina1_12 <= Bz1[24];
end
wire w0_12, w1_12;
MSKand_opini2_d2 u_or_12 (
    .ina({ina1_12, ina0_12}), .inb({Bz1[25], ny0_12}),
    .rnd(r[782]), .s(s[782]), .clk(clk), .out({w1_12, w0_12}));
wire or0_12 = w0_12 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_12 = w1_12;
wire nx0_13 = Bz0[26] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_13 = Bz0[27] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_13, ina1_13;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_13 <= nx0_13;
    ina1_13 <= Bz1[26];
end
wire w0_13, w1_13;
MSKand_opini2_d2 u_or_13 (
    .ina({ina1_13, ina0_13}), .inb({Bz1[27], ny0_13}),
    .rnd(r[783]), .s(s[783]), .clk(clk), .out({w1_13, w0_13}));
wire or0_13 = w0_13 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_13 = w1_13;
wire nx0_14 = Bz0[28] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_14 = Bz0[29] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_14, ina1_14;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_14 <= nx0_14;
    ina1_14 <= Bz1[28];
end
wire w0_14, w1_14;
MSKand_opini2_d2 u_or_14 (
    .ina({ina1_14, ina0_14}), .inb({Bz1[29], ny0_14}),
    .rnd(r[784]), .s(s[784]), .clk(clk), .out({w1_14, w0_14}));
wire or0_14 = w0_14 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_14 = w1_14;
wire nx0_15 = Bz0[30] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_15 = Bz0[31] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_15, ina1_15;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_15 <= nx0_15;
    ina1_15 <= Bz1[30];
end
wire w0_15, w1_15;
MSKand_opini2_d2 u_or_15 (
    .ina({ina1_15, ina0_15}), .inb({Bz1[31], ny0_15}),
    .rnd(r[785]), .s(s[785]), .clk(clk), .out({w1_15, w0_15}));
wire or0_15 = w0_15 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_15 = w1_15;
wire nx0_16 = Bz0[32] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_16 = Bz0[33] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_16, ina1_16;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_16 <= nx0_16;
    ina1_16 <= Bz1[32];
end
wire w0_16, w1_16;
MSKand_opini2_d2 u_or_16 (
    .ina({ina1_16, ina0_16}), .inb({Bz1[33], ny0_16}),
    .rnd(r[786]), .s(s[786]), .clk(clk), .out({w1_16, w0_16}));
wire or0_16 = w0_16 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_16 = w1_16;
wire nx0_17 = Bz0[34] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_17 = Bz0[35] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_17, ina1_17;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_17 <= nx0_17;
    ina1_17 <= Bz1[34];
end
wire w0_17, w1_17;
MSKand_opini2_d2 u_or_17 (
    .ina({ina1_17, ina0_17}), .inb({Bz1[35], ny0_17}),
    .rnd(r[787]), .s(s[787]), .clk(clk), .out({w1_17, w0_17}));
wire or0_17 = w0_17 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_17 = w1_17;
wire nx0_18 = Bz0[36] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_18 = Bz0[37] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_18, ina1_18;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_18 <= nx0_18;
    ina1_18 <= Bz1[36];
end
wire w0_18, w1_18;
MSKand_opini2_d2 u_or_18 (
    .ina({ina1_18, ina0_18}), .inb({Bz1[37], ny0_18}),
    .rnd(r[788]), .s(s[788]), .clk(clk), .out({w1_18, w0_18}));
wire or0_18 = w0_18 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_18 = w1_18;
wire nx0_19 = Bz0[38] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_19 = Bz0[39] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_19, ina1_19;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_19 <= nx0_19;
    ina1_19 <= Bz1[38];
end
wire w0_19, w1_19;
MSKand_opini2_d2 u_or_19 (
    .ina({ina1_19, ina0_19}), .inb({Bz1[39], ny0_19}),
    .rnd(r[789]), .s(s[789]), .clk(clk), .out({w1_19, w0_19}));
wire or0_19 = w0_19 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_19 = w1_19;
wire nx0_20 = Bz0[40] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_20 = Bz0[41] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_20, ina1_20;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_20 <= nx0_20;
    ina1_20 <= Bz1[40];
end
wire w0_20, w1_20;
MSKand_opini2_d2 u_or_20 (
    .ina({ina1_20, ina0_20}), .inb({Bz1[41], ny0_20}),
    .rnd(r[790]), .s(s[790]), .clk(clk), .out({w1_20, w0_20}));
wire or0_20 = w0_20 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_20 = w1_20;
wire nx0_21 = Bz0[42] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_21 = Bz0[43] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_21, ina1_21;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_21 <= nx0_21;
    ina1_21 <= Bz1[42];
end
wire w0_21, w1_21;
MSKand_opini2_d2 u_or_21 (
    .ina({ina1_21, ina0_21}), .inb({Bz1[43], ny0_21}),
    .rnd(r[791]), .s(s[791]), .clk(clk), .out({w1_21, w0_21}));
wire or0_21 = w0_21 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_21 = w1_21;
wire nx0_22 = Bz0[44] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_22 = Bz0[45] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_22, ina1_22;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_22 <= nx0_22;
    ina1_22 <= Bz1[44];
end
wire w0_22, w1_22;
MSKand_opini2_d2 u_or_22 (
    .ina({ina1_22, ina0_22}), .inb({Bz1[45], ny0_22}),
    .rnd(r[792]), .s(s[792]), .clk(clk), .out({w1_22, w0_22}));
wire or0_22 = w0_22 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_22 = w1_22;
wire nx0_23 = Bz0[46] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_23 = Bz0[47] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_23, ina1_23;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_23 <= nx0_23;
    ina1_23 <= Bz1[46];
end
wire w0_23, w1_23;
MSKand_opini2_d2 u_or_23 (
    .ina({ina1_23, ina0_23}), .inb({Bz1[47], ny0_23}),
    .rnd(r[793]), .s(s[793]), .clk(clk), .out({w1_23, w0_23}));
wire or0_23 = w0_23 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_23 = w1_23;
wire nx0_24 = Bz0[48] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_24 = Bz0[49] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_24, ina1_24;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_24 <= nx0_24;
    ina1_24 <= Bz1[48];
end
wire w0_24, w1_24;
MSKand_opini2_d2 u_or_24 (
    .ina({ina1_24, ina0_24}), .inb({Bz1[49], ny0_24}),
    .rnd(r[794]), .s(s[794]), .clk(clk), .out({w1_24, w0_24}));
wire or0_24 = w0_24 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_24 = w1_24;
wire nx0_25 = Bz0[50] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_25 = Bz0[51] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_25, ina1_25;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_25 <= nx0_25;
    ina1_25 <= Bz1[50];
end
wire w0_25, w1_25;
MSKand_opini2_d2 u_or_25 (
    .ina({ina1_25, ina0_25}), .inb({Bz1[51], ny0_25}),
    .rnd(r[795]), .s(s[795]), .clk(clk), .out({w1_25, w0_25}));
wire or0_25 = w0_25 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_25 = w1_25;
wire nx0_26 = Bz0[52] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_26 = Bz0[53] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_26, ina1_26;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_26 <= nx0_26;
    ina1_26 <= Bz1[52];
end
wire w0_26, w1_26;
MSKand_opini2_d2 u_or_26 (
    .ina({ina1_26, ina0_26}), .inb({Bz1[53], ny0_26}),
    .rnd(r[796]), .s(s[796]), .clk(clk), .out({w1_26, w0_26}));
wire or0_26 = w0_26 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_26 = w1_26;
wire nx0_27 = Bz0[54] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_27 = Bz0[55] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_27, ina1_27;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_27 <= nx0_27;
    ina1_27 <= Bz1[54];
end
wire w0_27, w1_27;
MSKand_opini2_d2 u_or_27 (
    .ina({ina1_27, ina0_27}), .inb({Bz1[55], ny0_27}),
    .rnd(r[797]), .s(s[797]), .clk(clk), .out({w1_27, w0_27}));
wire or0_27 = w0_27 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_27 = w1_27;
wire nx0_28 = Bz0[56] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_28 = Bz0[57] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_28, ina1_28;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_28 <= nx0_28;
    ina1_28 <= Bz1[56];
end
wire w0_28, w1_28;
MSKand_opini2_d2 u_or_28 (
    .ina({ina1_28, ina0_28}), .inb({Bz1[57], ny0_28}),
    .rnd(r[798]), .s(s[798]), .clk(clk), .out({w1_28, w0_28}));
wire or0_28 = w0_28 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_28 = w1_28;
wire nx0_29 = Bz0[58] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_29 = Bz0[59] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_29, ina1_29;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_29 <= nx0_29;
    ina1_29 <= Bz1[58];
end
wire w0_29, w1_29;
MSKand_opini2_d2 u_or_29 (
    .ina({ina1_29, ina0_29}), .inb({Bz1[59], ny0_29}),
    .rnd(r[799]), .s(s[799]), .clk(clk), .out({w1_29, w0_29}));
wire or0_29 = w0_29 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_29 = w1_29;
wire nx0_30 = Bz0[60] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_30 = Bz0[61] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_30, ina1_30;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_30 <= nx0_30;
    ina1_30 <= Bz1[60];
end
wire w0_30, w1_30;
MSKand_opini2_d2 u_or_30 (
    .ina({ina1_30, ina0_30}), .inb({Bz1[61], ny0_30}),
    .rnd(r[800]), .s(s[800]), .clk(clk), .out({w1_30, w0_30}));
wire or0_30 = w0_30 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_30 = w1_30;
wire nx0_31 = Bz0[62] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_31 = Bz0[63] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_31, ina1_31;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_31 <= nx0_31;
    ina1_31 <= Bz1[62];
end
wire w0_31, w1_31;
MSKand_opini2_d2 u_or_31 (
    .ina({ina1_31, ina0_31}), .inb({Bz1[63], ny0_31}),
    .rnd(r[801]), .s(s[801]), .clk(clk), .out({w1_31, w0_31}));
wire or0_31 = w0_31 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_31 = w1_31;
wire nx0_32 = Bz0[64] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_32 = Bz0[65] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_32, ina1_32;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_32 <= nx0_32;
    ina1_32 <= Bz1[64];
end
wire w0_32, w1_32;
MSKand_opini2_d2 u_or_32 (
    .ina({ina1_32, ina0_32}), .inb({Bz1[65], ny0_32}),
    .rnd(r[802]), .s(s[802]), .clk(clk), .out({w1_32, w0_32}));
wire or0_32 = w0_32 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_32 = w1_32;
wire nx0_33 = Bz0[66] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_33 = Bz0[67] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_33, ina1_33;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_33 <= nx0_33;
    ina1_33 <= Bz1[66];
end
wire w0_33, w1_33;
MSKand_opini2_d2 u_or_33 (
    .ina({ina1_33, ina0_33}), .inb({Bz1[67], ny0_33}),
    .rnd(r[803]), .s(s[803]), .clk(clk), .out({w1_33, w0_33}));
wire or0_33 = w0_33 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_33 = w1_33;
wire nx0_34 = Bz0[68] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_34 = Bz0[69] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_34, ina1_34;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_34 <= nx0_34;
    ina1_34 <= Bz1[68];
end
wire w0_34, w1_34;
MSKand_opini2_d2 u_or_34 (
    .ina({ina1_34, ina0_34}), .inb({Bz1[69], ny0_34}),
    .rnd(r[804]), .s(s[804]), .clk(clk), .out({w1_34, w0_34}));
wire or0_34 = w0_34 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_34 = w1_34;
wire nx0_35 = Bz0[70] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_35 = Bz0[71] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_35, ina1_35;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_35 <= nx0_35;
    ina1_35 <= Bz1[70];
end
wire w0_35, w1_35;
MSKand_opini2_d2 u_or_35 (
    .ina({ina1_35, ina0_35}), .inb({Bz1[71], ny0_35}),
    .rnd(r[805]), .s(s[805]), .clk(clk), .out({w1_35, w0_35}));
wire or0_35 = w0_35 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_35 = w1_35;
wire nx0_36 = Bz0[72] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_36 = Bz0[73] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_36, ina1_36;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_36 <= nx0_36;
    ina1_36 <= Bz1[72];
end
wire w0_36, w1_36;
MSKand_opini2_d2 u_or_36 (
    .ina({ina1_36, ina0_36}), .inb({Bz1[73], ny0_36}),
    .rnd(r[806]), .s(s[806]), .clk(clk), .out({w1_36, w0_36}));
wire or0_36 = w0_36 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_36 = w1_36;
wire nx0_37 = Bz0[74] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_37 = Bz0[75] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_37, ina1_37;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_37 <= nx0_37;
    ina1_37 <= Bz1[74];
end
wire w0_37, w1_37;
MSKand_opini2_d2 u_or_37 (
    .ina({ina1_37, ina0_37}), .inb({Bz1[75], ny0_37}),
    .rnd(r[807]), .s(s[807]), .clk(clk), .out({w1_37, w0_37}));
wire or0_37 = w0_37 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_37 = w1_37;
wire nx0_38 = Bz0[76] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_38 = Bz0[77] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_38, ina1_38;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_38 <= nx0_38;
    ina1_38 <= Bz1[76];
end
wire w0_38, w1_38;
MSKand_opini2_d2 u_or_38 (
    .ina({ina1_38, ina0_38}), .inb({Bz1[77], ny0_38}),
    .rnd(r[808]), .s(s[808]), .clk(clk), .out({w1_38, w0_38}));
wire or0_38 = w0_38 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_38 = w1_38;
wire nx0_39 = Bz0[78] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_39 = Bz0[79] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_39, ina1_39;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_39 <= nx0_39;
    ina1_39 <= Bz1[78];
end
wire w0_39, w1_39;
MSKand_opini2_d2 u_or_39 (
    .ina({ina1_39, ina0_39}), .inb({Bz1[79], ny0_39}),
    .rnd(r[809]), .s(s[809]), .clk(clk), .out({w1_39, w0_39}));
wire or0_39 = w0_39 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_39 = w1_39;
wire nx0_40 = Bz0[80] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_40 = Bz0[81] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_40, ina1_40;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_40 <= nx0_40;
    ina1_40 <= Bz1[80];
end
wire w0_40, w1_40;
MSKand_opini2_d2 u_or_40 (
    .ina({ina1_40, ina0_40}), .inb({Bz1[81], ny0_40}),
    .rnd(r[810]), .s(s[810]), .clk(clk), .out({w1_40, w0_40}));
wire or0_40 = w0_40 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_40 = w1_40;
wire nx0_41 = Bz0[82] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_41 = Bz0[83] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_41, ina1_41;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_41 <= nx0_41;
    ina1_41 <= Bz1[82];
end
wire w0_41, w1_41;
MSKand_opini2_d2 u_or_41 (
    .ina({ina1_41, ina0_41}), .inb({Bz1[83], ny0_41}),
    .rnd(r[811]), .s(s[811]), .clk(clk), .out({w1_41, w0_41}));
wire or0_41 = w0_41 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_41 = w1_41;
wire nx0_42 = Bz0[84] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_42 = Bz0[85] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_42, ina1_42;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_42 <= nx0_42;
    ina1_42 <= Bz1[84];
end
wire w0_42, w1_42;
MSKand_opini2_d2 u_or_42 (
    .ina({ina1_42, ina0_42}), .inb({Bz1[85], ny0_42}),
    .rnd(r[812]), .s(s[812]), .clk(clk), .out({w1_42, w0_42}));
wire or0_42 = w0_42 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_42 = w1_42;
wire nx0_43 = Bz0[86] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_43 = Bz0[87] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_43, ina1_43;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_43 <= nx0_43;
    ina1_43 <= Bz1[86];
end
wire w0_43, w1_43;
MSKand_opini2_d2 u_or_43 (
    .ina({ina1_43, ina0_43}), .inb({Bz1[87], ny0_43}),
    .rnd(r[813]), .s(s[813]), .clk(clk), .out({w1_43, w0_43}));
wire or0_43 = w0_43 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_43 = w1_43;
wire nx0_44 = Bz0[88] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_44 = Bz0[89] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_44, ina1_44;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_44 <= nx0_44;
    ina1_44 <= Bz1[88];
end
wire w0_44, w1_44;
MSKand_opini2_d2 u_or_44 (
    .ina({ina1_44, ina0_44}), .inb({Bz1[89], ny0_44}),
    .rnd(r[814]), .s(s[814]), .clk(clk), .out({w1_44, w0_44}));
wire or0_44 = w0_44 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_44 = w1_44;
wire nx0_45 = Bz0[90] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_45 = Bz0[91] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_45, ina1_45;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_45 <= nx0_45;
    ina1_45 <= Bz1[90];
end
wire w0_45, w1_45;
MSKand_opini2_d2 u_or_45 (
    .ina({ina1_45, ina0_45}), .inb({Bz1[91], ny0_45}),
    .rnd(r[815]), .s(s[815]), .clk(clk), .out({w1_45, w0_45}));
wire or0_45 = w0_45 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_45 = w1_45;
wire nx0_46 = Bz0[92] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_46 = Bz0[93] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_46, ina1_46;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_46 <= nx0_46;
    ina1_46 <= Bz1[92];
end
wire w0_46, w1_46;
MSKand_opini2_d2 u_or_46 (
    .ina({ina1_46, ina0_46}), .inb({Bz1[93], ny0_46}),
    .rnd(r[816]), .s(s[816]), .clk(clk), .out({w1_46, w0_46}));
wire or0_46 = w0_46 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_46 = w1_46;
wire nx0_47 = Bz0[94] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_47 = Bz0[95] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_47, ina1_47;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_47 <= nx0_47;
    ina1_47 <= Bz1[94];
end
wire w0_47, w1_47;
MSKand_opini2_d2 u_or_47 (
    .ina({ina1_47, ina0_47}), .inb({Bz1[95], ny0_47}),
    .rnd(r[817]), .s(s[817]), .clk(clk), .out({w1_47, w0_47}));
wire or0_47 = w0_47 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_47 = w1_47;
wire nx0_48 = Bz0[96] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_48 = Bz0[97] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_48, ina1_48;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_48 <= nx0_48;
    ina1_48 <= Bz1[96];
end
wire w0_48, w1_48;
MSKand_opini2_d2 u_or_48 (
    .ina({ina1_48, ina0_48}), .inb({Bz1[97], ny0_48}),
    .rnd(r[818]), .s(s[818]), .clk(clk), .out({w1_48, w0_48}));
wire or0_48 = w0_48 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_48 = w1_48;
wire nx0_49 = Bz0[98] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_49 = Bz0[99] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_49, ina1_49;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_49 <= nx0_49;
    ina1_49 <= Bz1[98];
end
wire w0_49, w1_49;
MSKand_opini2_d2 u_or_49 (
    .ina({ina1_49, ina0_49}), .inb({Bz1[99], ny0_49}),
    .rnd(r[819]), .s(s[819]), .clk(clk), .out({w1_49, w0_49}));
wire or0_49 = w0_49 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_49 = w1_49;
wire nx0_50 = Bz0[100] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_50 = Bz0[101] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_50, ina1_50;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_50 <= nx0_50;
    ina1_50 <= Bz1[100];
end
wire w0_50, w1_50;
MSKand_opini2_d2 u_or_50 (
    .ina({ina1_50, ina0_50}), .inb({Bz1[101], ny0_50}),
    .rnd(r[820]), .s(s[820]), .clk(clk), .out({w1_50, w0_50}));
wire or0_50 = w0_50 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_50 = w1_50;
wire nx0_51 = Bz0[102] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_51 = Bz0[103] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_51, ina1_51;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_51 <= nx0_51;
    ina1_51 <= Bz1[102];
end
wire w0_51, w1_51;
MSKand_opini2_d2 u_or_51 (
    .ina({ina1_51, ina0_51}), .inb({Bz1[103], ny0_51}),
    .rnd(r[821]), .s(s[821]), .clk(clk), .out({w1_51, w0_51}));
wire or0_51 = w0_51 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_51 = w1_51;
wire nx0_52 = Bz0[104] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_52 = Bz0[105] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_52, ina1_52;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_52 <= nx0_52;
    ina1_52 <= Bz1[104];
end
wire w0_52, w1_52;
MSKand_opini2_d2 u_or_52 (
    .ina({ina1_52, ina0_52}), .inb({Bz1[105], ny0_52}),
    .rnd(r[822]), .s(s[822]), .clk(clk), .out({w1_52, w0_52}));
wire or0_52 = w0_52 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_52 = w1_52;
wire nx0_53 = Bz0[106] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_53 = Bz0[107] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_53, ina1_53;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_53 <= nx0_53;
    ina1_53 <= Bz1[106];
end
wire w0_53, w1_53;
MSKand_opini2_d2 u_or_53 (
    .ina({ina1_53, ina0_53}), .inb({Bz1[107], ny0_53}),
    .rnd(r[823]), .s(s[823]), .clk(clk), .out({w1_53, w0_53}));
wire or0_53 = w0_53 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_53 = w1_53;
wire nx0_54 = Bz0[108] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_54 = Bz0[109] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_54, ina1_54;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_54 <= nx0_54;
    ina1_54 <= Bz1[108];
end
wire w0_54, w1_54;
MSKand_opini2_d2 u_or_54 (
    .ina({ina1_54, ina0_54}), .inb({Bz1[109], ny0_54}),
    .rnd(r[824]), .s(s[824]), .clk(clk), .out({w1_54, w0_54}));
wire or0_54 = w0_54 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_54 = w1_54;
wire nx0_55 = Bz0[110] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_55 = Bz0[111] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_55, ina1_55;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_55 <= nx0_55;
    ina1_55 <= Bz1[110];
end
wire w0_55, w1_55;
MSKand_opini2_d2 u_or_55 (
    .ina({ina1_55, ina0_55}), .inb({Bz1[111], ny0_55}),
    .rnd(r[825]), .s(s[825]), .clk(clk), .out({w1_55, w0_55}));
wire or0_55 = w0_55 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_55 = w1_55;
wire nx0_56 = Bz0[112] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_56 = Bz0[113] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_56, ina1_56;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_56 <= nx0_56;
    ina1_56 <= Bz1[112];
end
wire w0_56, w1_56;
MSKand_opini2_d2 u_or_56 (
    .ina({ina1_56, ina0_56}), .inb({Bz1[113], ny0_56}),
    .rnd(r[826]), .s(s[826]), .clk(clk), .out({w1_56, w0_56}));
wire or0_56 = w0_56 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_56 = w1_56;
wire nx0_57 = Bz0[114] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_57 = Bz0[115] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_57, ina1_57;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_57 <= nx0_57;
    ina1_57 <= Bz1[114];
end
wire w0_57, w1_57;
MSKand_opini2_d2 u_or_57 (
    .ina({ina1_57, ina0_57}), .inb({Bz1[115], ny0_57}),
    .rnd(r[827]), .s(s[827]), .clk(clk), .out({w1_57, w0_57}));
wire or0_57 = w0_57 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_57 = w1_57;
wire nx0_58 = Bz0[116] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_58 = Bz0[117] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_58, ina1_58;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_58 <= nx0_58;
    ina1_58 <= Bz1[116];
end
wire w0_58, w1_58;
MSKand_opini2_d2 u_or_58 (
    .ina({ina1_58, ina0_58}), .inb({Bz1[117], ny0_58}),
    .rnd(r[828]), .s(s[828]), .clk(clk), .out({w1_58, w0_58}));
wire or0_58 = w0_58 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_58 = w1_58;
wire nx0_59 = Bz0[118] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_59 = Bz0[119] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_59, ina1_59;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_59 <= nx0_59;
    ina1_59 <= Bz1[118];
end
wire w0_59, w1_59;
MSKand_opini2_d2 u_or_59 (
    .ina({ina1_59, ina0_59}), .inb({Bz1[119], ny0_59}),
    .rnd(r[829]), .s(s[829]), .clk(clk), .out({w1_59, w0_59}));
wire or0_59 = w0_59 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_59 = w1_59;
wire nx0_60 = Bz0[120] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_60 = Bz0[121] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_60, ina1_60;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_60 <= nx0_60;
    ina1_60 <= Bz1[120];
end
wire w0_60, w1_60;
MSKand_opini2_d2 u_or_60 (
    .ina({ina1_60, ina0_60}), .inb({Bz1[121], ny0_60}),
    .rnd(r[830]), .s(s[830]), .clk(clk), .out({w1_60, w0_60}));
wire or0_60 = w0_60 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_60 = w1_60;
wire nx0_61 = Bz0[122] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_61 = Bz0[123] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_61, ina1_61;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_61 <= nx0_61;
    ina1_61 <= Bz1[122];
end
wire w0_61, w1_61;
MSKand_opini2_d2 u_or_61 (
    .ina({ina1_61, ina0_61}), .inb({Bz1[123], ny0_61}),
    .rnd(r[831]), .s(s[831]), .clk(clk), .out({w1_61, w0_61}));
wire or0_61 = w0_61 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_61 = w1_61;
wire nx0_62 = Bz0[124] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_62 = Bz0[125] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_62, ina1_62;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_62 <= nx0_62;
    ina1_62 <= Bz1[124];
end
wire w0_62, w1_62;
MSKand_opini2_d2 u_or_62 (
    .ina({ina1_62, ina0_62}), .inb({Bz1[125], ny0_62}),
    .rnd(r[832]), .s(s[832]), .clk(clk), .out({w1_62, w0_62}));
wire or0_62 = w0_62 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_62 = w1_62;
wire nx0_63 = Bz0[126] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_63 = Bz0[127] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_63, ina1_63;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_63 <= nx0_63;
    ina1_63 <= Bz1[126];
end
wire w0_63, w1_63;
MSKand_opini2_d2 u_or_63 (
    .ina({ina1_63, ina0_63}), .inb({Bz1[127], ny0_63}),
    .rnd(r[833]), .s(s[833]), .clk(clk), .out({w1_63, w0_63}));
wire or0_63 = w0_63 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_63 = w1_63;
wire nx0_64 = Bz0[128] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_64 = Bz0[129] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_64, ina1_64;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_64 <= nx0_64;
    ina1_64 <= Bz1[128];
end
wire w0_64, w1_64;
MSKand_opini2_d2 u_or_64 (
    .ina({ina1_64, ina0_64}), .inb({Bz1[129], ny0_64}),
    .rnd(r[834]), .s(s[834]), .clk(clk), .out({w1_64, w0_64}));
wire or0_64 = w0_64 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_64 = w1_64;
wire nx0_65 = Bz0[130] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_65 = Bz0[131] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_65, ina1_65;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_65 <= nx0_65;
    ina1_65 <= Bz1[130];
end
wire w0_65, w1_65;
MSKand_opini2_d2 u_or_65 (
    .ina({ina1_65, ina0_65}), .inb({Bz1[131], ny0_65}),
    .rnd(r[835]), .s(s[835]), .clk(clk), .out({w1_65, w0_65}));
wire or0_65 = w0_65 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_65 = w1_65;
wire nx0_66 = Bz0[132] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_66 = Bz0[133] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_66, ina1_66;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_66 <= nx0_66;
    ina1_66 <= Bz1[132];
end
wire w0_66, w1_66;
MSKand_opini2_d2 u_or_66 (
    .ina({ina1_66, ina0_66}), .inb({Bz1[133], ny0_66}),
    .rnd(r[836]), .s(s[836]), .clk(clk), .out({w1_66, w0_66}));
wire or0_66 = w0_66 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_66 = w1_66;
wire nx0_67 = Bz0[134] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_67 = Bz0[135] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_67, ina1_67;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_67 <= nx0_67;
    ina1_67 <= Bz1[134];
end
wire w0_67, w1_67;
MSKand_opini2_d2 u_or_67 (
    .ina({ina1_67, ina0_67}), .inb({Bz1[135], ny0_67}),
    .rnd(r[837]), .s(s[837]), .clk(clk), .out({w1_67, w0_67}));
wire or0_67 = w0_67 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_67 = w1_67;
wire nx0_68 = Bz0[136] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_68 = Bz0[137] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_68, ina1_68;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_68 <= nx0_68;
    ina1_68 <= Bz1[136];
end
wire w0_68, w1_68;
MSKand_opini2_d2 u_or_68 (
    .ina({ina1_68, ina0_68}), .inb({Bz1[137], ny0_68}),
    .rnd(r[838]), .s(s[838]), .clk(clk), .out({w1_68, w0_68}));
wire or0_68 = w0_68 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_68 = w1_68;
wire nx0_69 = Bz0[138] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_69 = Bz0[139] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_69, ina1_69;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_69 <= nx0_69;
    ina1_69 <= Bz1[138];
end
wire w0_69, w1_69;
MSKand_opini2_d2 u_or_69 (
    .ina({ina1_69, ina0_69}), .inb({Bz1[139], ny0_69}),
    .rnd(r[839]), .s(s[839]), .clk(clk), .out({w1_69, w0_69}));
wire or0_69 = w0_69 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_69 = w1_69;
wire nx0_70 = Bz0[140] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_70 = Bz0[141] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_70, ina1_70;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_70 <= nx0_70;
    ina1_70 <= Bz1[140];
end
wire w0_70, w1_70;
MSKand_opini2_d2 u_or_70 (
    .ina({ina1_70, ina0_70}), .inb({Bz1[141], ny0_70}),
    .rnd(r[840]), .s(s[840]), .clk(clk), .out({w1_70, w0_70}));
wire or0_70 = w0_70 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_70 = w1_70;
wire nx0_71 = Bz0[142] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_71 = Bz0[143] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_71, ina1_71;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_71 <= nx0_71;
    ina1_71 <= Bz1[142];
end
wire w0_71, w1_71;
MSKand_opini2_d2 u_or_71 (
    .ina({ina1_71, ina0_71}), .inb({Bz1[143], ny0_71}),
    .rnd(r[841]), .s(s[841]), .clk(clk), .out({w1_71, w0_71}));
wire or0_71 = w0_71 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_71 = w1_71;
wire nx0_72 = Bz0[144] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_72 = Bz0[145] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_72, ina1_72;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_72 <= nx0_72;
    ina1_72 <= Bz1[144];
end
wire w0_72, w1_72;
MSKand_opini2_d2 u_or_72 (
    .ina({ina1_72, ina0_72}), .inb({Bz1[145], ny0_72}),
    .rnd(r[842]), .s(s[842]), .clk(clk), .out({w1_72, w0_72}));
wire or0_72 = w0_72 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_72 = w1_72;
wire nx0_73 = Bz0[146] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_73 = Bz0[147] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_73, ina1_73;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_73 <= nx0_73;
    ina1_73 <= Bz1[146];
end
wire w0_73, w1_73;
MSKand_opini2_d2 u_or_73 (
    .ina({ina1_73, ina0_73}), .inb({Bz1[147], ny0_73}),
    .rnd(r[843]), .s(s[843]), .clk(clk), .out({w1_73, w0_73}));
wire or0_73 = w0_73 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_73 = w1_73;
wire nx0_74 = Bz0[148] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_74 = Bz0[149] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_74, ina1_74;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_74 <= nx0_74;
    ina1_74 <= Bz1[148];
end
wire w0_74, w1_74;
MSKand_opini2_d2 u_or_74 (
    .ina({ina1_74, ina0_74}), .inb({Bz1[149], ny0_74}),
    .rnd(r[844]), .s(s[844]), .clk(clk), .out({w1_74, w0_74}));
wire or0_74 = w0_74 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_74 = w1_74;
wire nx0_75 = Bz0[150] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_75 = Bz0[151] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_75, ina1_75;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_75 <= nx0_75;
    ina1_75 <= Bz1[150];
end
wire w0_75, w1_75;
MSKand_opini2_d2 u_or_75 (
    .ina({ina1_75, ina0_75}), .inb({Bz1[151], ny0_75}),
    .rnd(r[845]), .s(s[845]), .clk(clk), .out({w1_75, w0_75}));
wire or0_75 = w0_75 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_75 = w1_75;
wire nx0_76 = Bz0[152] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_76 = Bz0[153] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_76, ina1_76;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_76 <= nx0_76;
    ina1_76 <= Bz1[152];
end
wire w0_76, w1_76;
MSKand_opini2_d2 u_or_76 (
    .ina({ina1_76, ina0_76}), .inb({Bz1[153], ny0_76}),
    .rnd(r[846]), .s(s[846]), .clk(clk), .out({w1_76, w0_76}));
wire or0_76 = w0_76 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_76 = w1_76;
wire nx0_77 = Bz0[154] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_77 = Bz0[155] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_77, ina1_77;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_77 <= nx0_77;
    ina1_77 <= Bz1[154];
end
wire w0_77, w1_77;
MSKand_opini2_d2 u_or_77 (
    .ina({ina1_77, ina0_77}), .inb({Bz1[155], ny0_77}),
    .rnd(r[847]), .s(s[847]), .clk(clk), .out({w1_77, w0_77}));
wire or0_77 = w0_77 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_77 = w1_77;
wire nx0_78 = Bz0[156] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_78 = Bz0[157] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_78, ina1_78;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_78 <= nx0_78;
    ina1_78 <= Bz1[156];
end
wire w0_78, w1_78;
MSKand_opini2_d2 u_or_78 (
    .ina({ina1_78, ina0_78}), .inb({Bz1[157], ny0_78}),
    .rnd(r[848]), .s(s[848]), .clk(clk), .out({w1_78, w0_78}));
wire or0_78 = w0_78 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_78 = w1_78;
wire nx0_79 = Bz0[158] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_79 = Bz0[159] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_79, ina1_79;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_79 <= nx0_79;
    ina1_79 <= Bz1[158];
end
wire w0_79, w1_79;
MSKand_opini2_d2 u_or_79 (
    .ina({ina1_79, ina0_79}), .inb({Bz1[159], ny0_79}),
    .rnd(r[849]), .s(s[849]), .clk(clk), .out({w1_79, w0_79}));
wire or0_79 = w0_79 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_79 = w1_79;
wire nx0_80 = Bz0[160] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_80 = Bz0[161] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_80, ina1_80;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_80 <= nx0_80;
    ina1_80 <= Bz1[160];
end
wire w0_80, w1_80;
MSKand_opini2_d2 u_or_80 (
    .ina({ina1_80, ina0_80}), .inb({Bz1[161], ny0_80}),
    .rnd(r[850]), .s(s[850]), .clk(clk), .out({w1_80, w0_80}));
wire or0_80 = w0_80 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_80 = w1_80;
wire nx0_81 = Bz0[162] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_81 = Bz0[163] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_81, ina1_81;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_81 <= nx0_81;
    ina1_81 <= Bz1[162];
end
wire w0_81, w1_81;
MSKand_opini2_d2 u_or_81 (
    .ina({ina1_81, ina0_81}), .inb({Bz1[163], ny0_81}),
    .rnd(r[851]), .s(s[851]), .clk(clk), .out({w1_81, w0_81}));
wire or0_81 = w0_81 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_81 = w1_81;
wire nx0_82 = Bz0[164] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_82 = Bz0[165] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_82, ina1_82;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_82 <= nx0_82;
    ina1_82 <= Bz1[164];
end
wire w0_82, w1_82;
MSKand_opini2_d2 u_or_82 (
    .ina({ina1_82, ina0_82}), .inb({Bz1[165], ny0_82}),
    .rnd(r[852]), .s(s[852]), .clk(clk), .out({w1_82, w0_82}));
wire or0_82 = w0_82 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_82 = w1_82;
wire nx0_83 = Bz0[166] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_83 = Bz0[167] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_83, ina1_83;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_83 <= nx0_83;
    ina1_83 <= Bz1[166];
end
wire w0_83, w1_83;
MSKand_opini2_d2 u_or_83 (
    .ina({ina1_83, ina0_83}), .inb({Bz1[167], ny0_83}),
    .rnd(r[853]), .s(s[853]), .clk(clk), .out({w1_83, w0_83}));
wire or0_83 = w0_83 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_83 = w1_83;
wire nx0_84 = Bz0[168] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_84 = Bz0[169] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_84, ina1_84;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_84 <= nx0_84;
    ina1_84 <= Bz1[168];
end
wire w0_84, w1_84;
MSKand_opini2_d2 u_or_84 (
    .ina({ina1_84, ina0_84}), .inb({Bz1[169], ny0_84}),
    .rnd(r[854]), .s(s[854]), .clk(clk), .out({w1_84, w0_84}));
wire or0_84 = w0_84 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_84 = w1_84;
wire nx0_85 = Bz0[170] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_85 = Bz0[171] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_85, ina1_85;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_85 <= nx0_85;
    ina1_85 <= Bz1[170];
end
wire w0_85, w1_85;
MSKand_opini2_d2 u_or_85 (
    .ina({ina1_85, ina0_85}), .inb({Bz1[171], ny0_85}),
    .rnd(r[855]), .s(s[855]), .clk(clk), .out({w1_85, w0_85}));
wire or0_85 = w0_85 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_85 = w1_85;
wire nx0_86 = Bz0[172] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_86 = Bz0[173] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_86, ina1_86;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_86 <= nx0_86;
    ina1_86 <= Bz1[172];
end
wire w0_86, w1_86;
MSKand_opini2_d2 u_or_86 (
    .ina({ina1_86, ina0_86}), .inb({Bz1[173], ny0_86}),
    .rnd(r[856]), .s(s[856]), .clk(clk), .out({w1_86, w0_86}));
wire or0_86 = w0_86 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_86 = w1_86;
wire nx0_87 = Bz0[174] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_87 = Bz0[175] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_87, ina1_87;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_87 <= nx0_87;
    ina1_87 <= Bz1[174];
end
wire w0_87, w1_87;
MSKand_opini2_d2 u_or_87 (
    .ina({ina1_87, ina0_87}), .inb({Bz1[175], ny0_87}),
    .rnd(r[857]), .s(s[857]), .clk(clk), .out({w1_87, w0_87}));
wire or0_87 = w0_87 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_87 = w1_87;
wire nx0_88 = Bz0[176] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_88 = Bz0[177] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_88, ina1_88;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_88 <= nx0_88;
    ina1_88 <= Bz1[176];
end
wire w0_88, w1_88;
MSKand_opini2_d2 u_or_88 (
    .ina({ina1_88, ina0_88}), .inb({Bz1[177], ny0_88}),
    .rnd(r[858]), .s(s[858]), .clk(clk), .out({w1_88, w0_88}));
wire or0_88 = w0_88 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_88 = w1_88;
wire nx0_89 = Bz0[178] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_89 = Bz0[179] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_89, ina1_89;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_89 <= nx0_89;
    ina1_89 <= Bz1[178];
end
wire w0_89, w1_89;
MSKand_opini2_d2 u_or_89 (
    .ina({ina1_89, ina0_89}), .inb({Bz1[179], ny0_89}),
    .rnd(r[859]), .s(s[859]), .clk(clk), .out({w1_89, w0_89}));
wire or0_89 = w0_89 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_89 = w1_89;
wire nx0_90 = Bz0[180] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_90 = Bz0[181] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_90, ina1_90;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_90 <= nx0_90;
    ina1_90 <= Bz1[180];
end
wire w0_90, w1_90;
MSKand_opini2_d2 u_or_90 (
    .ina({ina1_90, ina0_90}), .inb({Bz1[181], ny0_90}),
    .rnd(r[860]), .s(s[860]), .clk(clk), .out({w1_90, w0_90}));
wire or0_90 = w0_90 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_90 = w1_90;
wire nx0_91 = Bz0[182] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_91 = Bz0[183] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_91, ina1_91;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_91 <= nx0_91;
    ina1_91 <= Bz1[182];
end
wire w0_91, w1_91;
MSKand_opini2_d2 u_or_91 (
    .ina({ina1_91, ina0_91}), .inb({Bz1[183], ny0_91}),
    .rnd(r[861]), .s(s[861]), .clk(clk), .out({w1_91, w0_91}));
wire or0_91 = w0_91 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_91 = w1_91;
wire nx0_92 = Bz0[184] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_92 = Bz0[185] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_92, ina1_92;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_92 <= nx0_92;
    ina1_92 <= Bz1[184];
end
wire w0_92, w1_92;
MSKand_opini2_d2 u_or_92 (
    .ina({ina1_92, ina0_92}), .inb({Bz1[185], ny0_92}),
    .rnd(r[862]), .s(s[862]), .clk(clk), .out({w1_92, w0_92}));
wire or0_92 = w0_92 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_92 = w1_92;
wire nx0_93 = Bz0[186] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_93 = Bz0[187] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_93, ina1_93;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_93 <= nx0_93;
    ina1_93 <= Bz1[186];
end
wire w0_93, w1_93;
MSKand_opini2_d2 u_or_93 (
    .ina({ina1_93, ina0_93}), .inb({Bz1[187], ny0_93}),
    .rnd(r[863]), .s(s[863]), .clk(clk), .out({w1_93, w0_93}));
wire or0_93 = w0_93 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_93 = w1_93;
wire nx0_94 = Bz0[188] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_94 = Bz0[189] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_94, ina1_94;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_94 <= nx0_94;
    ina1_94 <= Bz1[188];
end
wire w0_94, w1_94;
MSKand_opini2_d2 u_or_94 (
    .ina({ina1_94, ina0_94}), .inb({Bz1[189], ny0_94}),
    .rnd(r[864]), .s(s[864]), .clk(clk), .out({w1_94, w0_94}));
wire or0_94 = w0_94 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_94 = w1_94;
wire nx0_95 = Bz0[190] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_95 = Bz0[191] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_95, ina1_95;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_95 <= nx0_95;
    ina1_95 <= Bz1[190];
end
wire w0_95, w1_95;
MSKand_opini2_d2 u_or_95 (
    .ina({ina1_95, ina0_95}), .inb({Bz1[191], ny0_95}),
    .rnd(r[865]), .s(s[865]), .clk(clk), .out({w1_95, w0_95}));
wire or0_95 = w0_95 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_95 = w1_95;
wire nx0_96 = Bz0[192] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_96 = Bz0[193] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_96, ina1_96;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_96 <= nx0_96;
    ina1_96 <= Bz1[192];
end
wire w0_96, w1_96;
MSKand_opini2_d2 u_or_96 (
    .ina({ina1_96, ina0_96}), .inb({Bz1[193], ny0_96}),
    .rnd(r[866]), .s(s[866]), .clk(clk), .out({w1_96, w0_96}));
wire or0_96 = w0_96 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_96 = w1_96;
wire nx0_97 = Bz0[194] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_97 = Bz0[195] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_97, ina1_97;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_97 <= nx0_97;
    ina1_97 <= Bz1[194];
end
wire w0_97, w1_97;
MSKand_opini2_d2 u_or_97 (
    .ina({ina1_97, ina0_97}), .inb({Bz1[195], ny0_97}),
    .rnd(r[867]), .s(s[867]), .clk(clk), .out({w1_97, w0_97}));
wire or0_97 = w0_97 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_97 = w1_97;
wire nx0_98 = Bz0[196] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_98 = Bz0[197] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_98, ina1_98;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_98 <= nx0_98;
    ina1_98 <= Bz1[196];
end
wire w0_98, w1_98;
MSKand_opini2_d2 u_or_98 (
    .ina({ina1_98, ina0_98}), .inb({Bz1[197], ny0_98}),
    .rnd(r[868]), .s(s[868]), .clk(clk), .out({w1_98, w0_98}));
wire or0_98 = w0_98 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_98 = w1_98;
wire nx0_99 = Bz0[198] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_99 = Bz0[199] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_99, ina1_99;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_99 <= nx0_99;
    ina1_99 <= Bz1[198];
end
wire w0_99, w1_99;
MSKand_opini2_d2 u_or_99 (
    .ina({ina1_99, ina0_99}), .inb({Bz1[199], ny0_99}),
    .rnd(r[869]), .s(s[869]), .clk(clk), .out({w1_99, w0_99}));
wire or0_99 = w0_99 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_99 = w1_99;
wire nx0_100 = Bz0[200] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_100 = Bz0[201] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_100, ina1_100;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_100 <= nx0_100;
    ina1_100 <= Bz1[200];
end
wire w0_100, w1_100;
MSKand_opini2_d2 u_or_100 (
    .ina({ina1_100, ina0_100}), .inb({Bz1[201], ny0_100}),
    .rnd(r[870]), .s(s[870]), .clk(clk), .out({w1_100, w0_100}));
wire or0_100 = w0_100 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_100 = w1_100;
wire nx0_101 = Bz0[202] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_101 = Bz0[203] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_101, ina1_101;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_101 <= nx0_101;
    ina1_101 <= Bz1[202];
end
wire w0_101, w1_101;
MSKand_opini2_d2 u_or_101 (
    .ina({ina1_101, ina0_101}), .inb({Bz1[203], ny0_101}),
    .rnd(r[871]), .s(s[871]), .clk(clk), .out({w1_101, w0_101}));
wire or0_101 = w0_101 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_101 = w1_101;
wire nx0_102 = Bz0[204] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_102 = Bz0[205] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_102, ina1_102;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_102 <= nx0_102;
    ina1_102 <= Bz1[204];
end
wire w0_102, w1_102;
MSKand_opini2_d2 u_or_102 (
    .ina({ina1_102, ina0_102}), .inb({Bz1[205], ny0_102}),
    .rnd(r[872]), .s(s[872]), .clk(clk), .out({w1_102, w0_102}));
wire or0_102 = w0_102 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_102 = w1_102;
wire nx0_103 = Bz0[206] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_103 = Bz0[207] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_103, ina1_103;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_103 <= nx0_103;
    ina1_103 <= Bz1[206];
end
wire w0_103, w1_103;
MSKand_opini2_d2 u_or_103 (
    .ina({ina1_103, ina0_103}), .inb({Bz1[207], ny0_103}),
    .rnd(r[873]), .s(s[873]), .clk(clk), .out({w1_103, w0_103}));
wire or0_103 = w0_103 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_103 = w1_103;
wire nx0_104 = Bz0[208] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_104 = Bz0[209] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_104, ina1_104;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_104 <= nx0_104;
    ina1_104 <= Bz1[208];
end
wire w0_104, w1_104;
MSKand_opini2_d2 u_or_104 (
    .ina({ina1_104, ina0_104}), .inb({Bz1[209], ny0_104}),
    .rnd(r[874]), .s(s[874]), .clk(clk), .out({w1_104, w0_104}));
wire or0_104 = w0_104 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_104 = w1_104;
wire nx0_105 = Bz0[210] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_105 = Bz0[211] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_105, ina1_105;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_105 <= nx0_105;
    ina1_105 <= Bz1[210];
end
wire w0_105, w1_105;
MSKand_opini2_d2 u_or_105 (
    .ina({ina1_105, ina0_105}), .inb({Bz1[211], ny0_105}),
    .rnd(r[875]), .s(s[875]), .clk(clk), .out({w1_105, w0_105}));
wire or0_105 = w0_105 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_105 = w1_105;
wire nx0_106 = Bz0[212] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_106 = Bz0[213] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_106, ina1_106;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_106 <= nx0_106;
    ina1_106 <= Bz1[212];
end
wire w0_106, w1_106;
MSKand_opini2_d2 u_or_106 (
    .ina({ina1_106, ina0_106}), .inb({Bz1[213], ny0_106}),
    .rnd(r[876]), .s(s[876]), .clk(clk), .out({w1_106, w0_106}));
wire or0_106 = w0_106 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_106 = w1_106;
wire nx0_107 = Bz0[214] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_107 = Bz0[215] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_107, ina1_107;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_107 <= nx0_107;
    ina1_107 <= Bz1[214];
end
wire w0_107, w1_107;
MSKand_opini2_d2 u_or_107 (
    .ina({ina1_107, ina0_107}), .inb({Bz1[215], ny0_107}),
    .rnd(r[877]), .s(s[877]), .clk(clk), .out({w1_107, w0_107}));
wire or0_107 = w0_107 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_107 = w1_107;
wire nx0_108 = Bz0[216] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_108 = Bz0[217] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_108, ina1_108;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_108 <= nx0_108;
    ina1_108 <= Bz1[216];
end
wire w0_108, w1_108;
MSKand_opini2_d2 u_or_108 (
    .ina({ina1_108, ina0_108}), .inb({Bz1[217], ny0_108}),
    .rnd(r[878]), .s(s[878]), .clk(clk), .out({w1_108, w0_108}));
wire or0_108 = w0_108 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_108 = w1_108;
wire nx0_109 = Bz0[218] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_109 = Bz0[219] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_109, ina1_109;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_109 <= nx0_109;
    ina1_109 <= Bz1[218];
end
wire w0_109, w1_109;
MSKand_opini2_d2 u_or_109 (
    .ina({ina1_109, ina0_109}), .inb({Bz1[219], ny0_109}),
    .rnd(r[879]), .s(s[879]), .clk(clk), .out({w1_109, w0_109}));
wire or0_109 = w0_109 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_109 = w1_109;
wire nx0_110 = Bz0[220] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_110 = Bz0[221] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_110, ina1_110;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_110 <= nx0_110;
    ina1_110 <= Bz1[220];
end
wire w0_110, w1_110;
MSKand_opini2_d2 u_or_110 (
    .ina({ina1_110, ina0_110}), .inb({Bz1[221], ny0_110}),
    .rnd(r[880]), .s(s[880]), .clk(clk), .out({w1_110, w0_110}));
wire or0_110 = w0_110 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_110 = w1_110;
wire nx0_111 = Bz0[222] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_111 = Bz0[223] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_111, ina1_111;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_111 <= nx0_111;
    ina1_111 <= Bz1[222];
end
wire w0_111, w1_111;
MSKand_opini2_d2 u_or_111 (
    .ina({ina1_111, ina0_111}), .inb({Bz1[223], ny0_111}),
    .rnd(r[881]), .s(s[881]), .clk(clk), .out({w1_111, w0_111}));
wire or0_111 = w0_111 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_111 = w1_111;
wire nx0_112 = Bz0[224] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_112 = Bz0[225] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_112, ina1_112;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_112 <= nx0_112;
    ina1_112 <= Bz1[224];
end
wire w0_112, w1_112;
MSKand_opini2_d2 u_or_112 (
    .ina({ina1_112, ina0_112}), .inb({Bz1[225], ny0_112}),
    .rnd(r[882]), .s(s[882]), .clk(clk), .out({w1_112, w0_112}));
wire or0_112 = w0_112 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_112 = w1_112;
wire nx0_113 = Bz0[226] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_113 = Bz0[227] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_113, ina1_113;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_113 <= nx0_113;
    ina1_113 <= Bz1[226];
end
wire w0_113, w1_113;
MSKand_opini2_d2 u_or_113 (
    .ina({ina1_113, ina0_113}), .inb({Bz1[227], ny0_113}),
    .rnd(r[883]), .s(s[883]), .clk(clk), .out({w1_113, w0_113}));
wire or0_113 = w0_113 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_113 = w1_113;
wire nx0_114 = Bz0[228] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_114 = Bz0[229] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_114, ina1_114;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_114 <= nx0_114;
    ina1_114 <= Bz1[228];
end
wire w0_114, w1_114;
MSKand_opini2_d2 u_or_114 (
    .ina({ina1_114, ina0_114}), .inb({Bz1[229], ny0_114}),
    .rnd(r[884]), .s(s[884]), .clk(clk), .out({w1_114, w0_114}));
wire or0_114 = w0_114 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_114 = w1_114;
wire nx0_115 = Bz0[230] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_115 = Bz0[231] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_115, ina1_115;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_115 <= nx0_115;
    ina1_115 <= Bz1[230];
end
wire w0_115, w1_115;
MSKand_opini2_d2 u_or_115 (
    .ina({ina1_115, ina0_115}), .inb({Bz1[231], ny0_115}),
    .rnd(r[885]), .s(s[885]), .clk(clk), .out({w1_115, w0_115}));
wire or0_115 = w0_115 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_115 = w1_115;
wire nx0_116 = Bz0[232] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_116 = Bz0[233] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_116, ina1_116;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_116 <= nx0_116;
    ina1_116 <= Bz1[232];
end
wire w0_116, w1_116;
MSKand_opini2_d2 u_or_116 (
    .ina({ina1_116, ina0_116}), .inb({Bz1[233], ny0_116}),
    .rnd(r[886]), .s(s[886]), .clk(clk), .out({w1_116, w0_116}));
wire or0_116 = w0_116 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_116 = w1_116;
wire nx0_117 = Bz0[234] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_117 = Bz0[235] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_117, ina1_117;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_117 <= nx0_117;
    ina1_117 <= Bz1[234];
end
wire w0_117, w1_117;
MSKand_opini2_d2 u_or_117 (
    .ina({ina1_117, ina0_117}), .inb({Bz1[235], ny0_117}),
    .rnd(r[887]), .s(s[887]), .clk(clk), .out({w1_117, w0_117}));
wire or0_117 = w0_117 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_117 = w1_117;
wire nx0_118 = Bz0[236] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_118 = Bz0[237] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_118, ina1_118;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_118 <= nx0_118;
    ina1_118 <= Bz1[236];
end
wire w0_118, w1_118;
MSKand_opini2_d2 u_or_118 (
    .ina({ina1_118, ina0_118}), .inb({Bz1[237], ny0_118}),
    .rnd(r[888]), .s(s[888]), .clk(clk), .out({w1_118, w0_118}));
wire or0_118 = w0_118 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_118 = w1_118;
wire nx0_119 = Bz0[238] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_119 = Bz0[239] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_119, ina1_119;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_119 <= nx0_119;
    ina1_119 <= Bz1[238];
end
wire w0_119, w1_119;
MSKand_opini2_d2 u_or_119 (
    .ina({ina1_119, ina0_119}), .inb({Bz1[239], ny0_119}),
    .rnd(r[889]), .s(s[889]), .clk(clk), .out({w1_119, w0_119}));
wire or0_119 = w0_119 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_119 = w1_119;
wire nx0_120 = Bz0[240] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_120 = Bz0[241] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_120, ina1_120;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_120 <= nx0_120;
    ina1_120 <= Bz1[240];
end
wire w0_120, w1_120;
MSKand_opini2_d2 u_or_120 (
    .ina({ina1_120, ina0_120}), .inb({Bz1[241], ny0_120}),
    .rnd(r[890]), .s(s[890]), .clk(clk), .out({w1_120, w0_120}));
wire or0_120 = w0_120 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_120 = w1_120;
wire nx0_121 = Bz0[242] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_121 = Bz0[243] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_121, ina1_121;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_121 <= nx0_121;
    ina1_121 <= Bz1[242];
end
wire w0_121, w1_121;
MSKand_opini2_d2 u_or_121 (
    .ina({ina1_121, ina0_121}), .inb({Bz1[243], ny0_121}),
    .rnd(r[891]), .s(s[891]), .clk(clk), .out({w1_121, w0_121}));
wire or0_121 = w0_121 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_121 = w1_121;
wire nx0_122 = Bz0[244] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_122 = Bz0[245] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_122, ina1_122;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_122 <= nx0_122;
    ina1_122 <= Bz1[244];
end
wire w0_122, w1_122;
MSKand_opini2_d2 u_or_122 (
    .ina({ina1_122, ina0_122}), .inb({Bz1[245], ny0_122}),
    .rnd(r[892]), .s(s[892]), .clk(clk), .out({w1_122, w0_122}));
wire or0_122 = w0_122 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_122 = w1_122;
wire nx0_123 = Bz0[246] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_123 = Bz0[247] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_123, ina1_123;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_123 <= nx0_123;
    ina1_123 <= Bz1[246];
end
wire w0_123, w1_123;
MSKand_opini2_d2 u_or_123 (
    .ina({ina1_123, ina0_123}), .inb({Bz1[247], ny0_123}),
    .rnd(r[893]), .s(s[893]), .clk(clk), .out({w1_123, w0_123}));
wire or0_123 = w0_123 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_123 = w1_123;
wire nx0_124 = Bz0[248] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_124 = Bz0[249] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_124, ina1_124;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_124 <= nx0_124;
    ina1_124 <= Bz1[248];
end
wire w0_124, w1_124;
MSKand_opini2_d2 u_or_124 (
    .ina({ina1_124, ina0_124}), .inb({Bz1[249], ny0_124}),
    .rnd(r[894]), .s(s[894]), .clk(clk), .out({w1_124, w0_124}));
wire or0_124 = w0_124 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_124 = w1_124;
wire nx0_125 = Bz0[250] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_125 = Bz0[251] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_125, ina1_125;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_125 <= nx0_125;
    ina1_125 <= Bz1[250];
end
wire w0_125, w1_125;
MSKand_opini2_d2 u_or_125 (
    .ina({ina1_125, ina0_125}), .inb({Bz1[251], ny0_125}),
    .rnd(r[895]), .s(s[895]), .clk(clk), .out({w1_125, w0_125}));
wire or0_125 = w0_125 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_125 = w1_125;
wire nx0_126 = Bz0[252] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_126 = Bz0[253] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_126, ina1_126;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_126 <= nx0_126;
    ina1_126 <= Bz1[252];
end
wire w0_126, w1_126;
MSKand_opini2_d2 u_or_126 (
    .ina({ina1_126, ina0_126}), .inb({Bz1[253], ny0_126}),
    .rnd(r[896]), .s(s[896]), .clk(clk), .out({w1_126, w0_126}));
wire or0_126 = w0_126 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_126 = w1_126;
wire nx0_127 = Bz0[254] ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_127 = Bz0[255] ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_127, ina1_127;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_127 <= nx0_127;
    ina1_127 <= Bz1[254];
end
wire w0_127, w1_127;
MSKand_opini2_d2 u_or_127 (
    .ina({ina1_127, ina0_127}), .inb({Bz1[255], ny0_127}),
    .rnd(r[897]), .s(s[897]), .clk(clk), .out({w1_127, w0_127}));
wire or0_127 = w0_127 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_127 = w1_127;

// ===== nonzero-tree OR-reduce level 1: 128 masked bits -> 64 =====
wire nx0_128 = or0_0 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_128 = or0_1 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_128, ina1_128;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_128 <= nx0_128;
    ina1_128 <= or1_0;
end
wire w0_128, w1_128;
MSKand_opini2_d2 u_or_128 (
    .ina({ina1_128, ina0_128}), .inb({or1_1, ny0_128}),
    .rnd(r[898]), .s(s[898]), .clk(clk), .out({w1_128, w0_128}));
wire or0_128 = w0_128 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_128 = w1_128;
wire nx0_129 = or0_2 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_129 = or0_3 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_129, ina1_129;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_129 <= nx0_129;
    ina1_129 <= or1_2;
end
wire w0_129, w1_129;
MSKand_opini2_d2 u_or_129 (
    .ina({ina1_129, ina0_129}), .inb({or1_3, ny0_129}),
    .rnd(r[899]), .s(s[899]), .clk(clk), .out({w1_129, w0_129}));
wire or0_129 = w0_129 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_129 = w1_129;
wire nx0_130 = or0_4 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_130 = or0_5 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_130, ina1_130;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_130 <= nx0_130;
    ina1_130 <= or1_4;
end
wire w0_130, w1_130;
MSKand_opini2_d2 u_or_130 (
    .ina({ina1_130, ina0_130}), .inb({or1_5, ny0_130}),
    .rnd(r[900]), .s(s[900]), .clk(clk), .out({w1_130, w0_130}));
wire or0_130 = w0_130 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_130 = w1_130;
wire nx0_131 = or0_6 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_131 = or0_7 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_131, ina1_131;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_131 <= nx0_131;
    ina1_131 <= or1_6;
end
wire w0_131, w1_131;
MSKand_opini2_d2 u_or_131 (
    .ina({ina1_131, ina0_131}), .inb({or1_7, ny0_131}),
    .rnd(r[901]), .s(s[901]), .clk(clk), .out({w1_131, w0_131}));
wire or0_131 = w0_131 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_131 = w1_131;
wire nx0_132 = or0_8 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_132 = or0_9 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_132, ina1_132;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_132 <= nx0_132;
    ina1_132 <= or1_8;
end
wire w0_132, w1_132;
MSKand_opini2_d2 u_or_132 (
    .ina({ina1_132, ina0_132}), .inb({or1_9, ny0_132}),
    .rnd(r[902]), .s(s[902]), .clk(clk), .out({w1_132, w0_132}));
wire or0_132 = w0_132 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_132 = w1_132;
wire nx0_133 = or0_10 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_133 = or0_11 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_133, ina1_133;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_133 <= nx0_133;
    ina1_133 <= or1_10;
end
wire w0_133, w1_133;
MSKand_opini2_d2 u_or_133 (
    .ina({ina1_133, ina0_133}), .inb({or1_11, ny0_133}),
    .rnd(r[903]), .s(s[903]), .clk(clk), .out({w1_133, w0_133}));
wire or0_133 = w0_133 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_133 = w1_133;
wire nx0_134 = or0_12 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_134 = or0_13 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_134, ina1_134;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_134 <= nx0_134;
    ina1_134 <= or1_12;
end
wire w0_134, w1_134;
MSKand_opini2_d2 u_or_134 (
    .ina({ina1_134, ina0_134}), .inb({or1_13, ny0_134}),
    .rnd(r[904]), .s(s[904]), .clk(clk), .out({w1_134, w0_134}));
wire or0_134 = w0_134 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_134 = w1_134;
wire nx0_135 = or0_14 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_135 = or0_15 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_135, ina1_135;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_135 <= nx0_135;
    ina1_135 <= or1_14;
end
wire w0_135, w1_135;
MSKand_opini2_d2 u_or_135 (
    .ina({ina1_135, ina0_135}), .inb({or1_15, ny0_135}),
    .rnd(r[905]), .s(s[905]), .clk(clk), .out({w1_135, w0_135}));
wire or0_135 = w0_135 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_135 = w1_135;
wire nx0_136 = or0_16 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_136 = or0_17 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_136, ina1_136;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_136 <= nx0_136;
    ina1_136 <= or1_16;
end
wire w0_136, w1_136;
MSKand_opini2_d2 u_or_136 (
    .ina({ina1_136, ina0_136}), .inb({or1_17, ny0_136}),
    .rnd(r[906]), .s(s[906]), .clk(clk), .out({w1_136, w0_136}));
wire or0_136 = w0_136 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_136 = w1_136;
wire nx0_137 = or0_18 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_137 = or0_19 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_137, ina1_137;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_137 <= nx0_137;
    ina1_137 <= or1_18;
end
wire w0_137, w1_137;
MSKand_opini2_d2 u_or_137 (
    .ina({ina1_137, ina0_137}), .inb({or1_19, ny0_137}),
    .rnd(r[907]), .s(s[907]), .clk(clk), .out({w1_137, w0_137}));
wire or0_137 = w0_137 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_137 = w1_137;
wire nx0_138 = or0_20 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_138 = or0_21 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_138, ina1_138;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_138 <= nx0_138;
    ina1_138 <= or1_20;
end
wire w0_138, w1_138;
MSKand_opini2_d2 u_or_138 (
    .ina({ina1_138, ina0_138}), .inb({or1_21, ny0_138}),
    .rnd(r[908]), .s(s[908]), .clk(clk), .out({w1_138, w0_138}));
wire or0_138 = w0_138 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_138 = w1_138;
wire nx0_139 = or0_22 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_139 = or0_23 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_139, ina1_139;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_139 <= nx0_139;
    ina1_139 <= or1_22;
end
wire w0_139, w1_139;
MSKand_opini2_d2 u_or_139 (
    .ina({ina1_139, ina0_139}), .inb({or1_23, ny0_139}),
    .rnd(r[909]), .s(s[909]), .clk(clk), .out({w1_139, w0_139}));
wire or0_139 = w0_139 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_139 = w1_139;
wire nx0_140 = or0_24 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_140 = or0_25 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_140, ina1_140;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_140 <= nx0_140;
    ina1_140 <= or1_24;
end
wire w0_140, w1_140;
MSKand_opini2_d2 u_or_140 (
    .ina({ina1_140, ina0_140}), .inb({or1_25, ny0_140}),
    .rnd(r[910]), .s(s[910]), .clk(clk), .out({w1_140, w0_140}));
wire or0_140 = w0_140 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_140 = w1_140;
wire nx0_141 = or0_26 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_141 = or0_27 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_141, ina1_141;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_141 <= nx0_141;
    ina1_141 <= or1_26;
end
wire w0_141, w1_141;
MSKand_opini2_d2 u_or_141 (
    .ina({ina1_141, ina0_141}), .inb({or1_27, ny0_141}),
    .rnd(r[911]), .s(s[911]), .clk(clk), .out({w1_141, w0_141}));
wire or0_141 = w0_141 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_141 = w1_141;
wire nx0_142 = or0_28 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_142 = or0_29 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_142, ina1_142;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_142 <= nx0_142;
    ina1_142 <= or1_28;
end
wire w0_142, w1_142;
MSKand_opini2_d2 u_or_142 (
    .ina({ina1_142, ina0_142}), .inb({or1_29, ny0_142}),
    .rnd(r[912]), .s(s[912]), .clk(clk), .out({w1_142, w0_142}));
wire or0_142 = w0_142 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_142 = w1_142;
wire nx0_143 = or0_30 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_143 = or0_31 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_143, ina1_143;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_143 <= nx0_143;
    ina1_143 <= or1_30;
end
wire w0_143, w1_143;
MSKand_opini2_d2 u_or_143 (
    .ina({ina1_143, ina0_143}), .inb({or1_31, ny0_143}),
    .rnd(r[913]), .s(s[913]), .clk(clk), .out({w1_143, w0_143}));
wire or0_143 = w0_143 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_143 = w1_143;
wire nx0_144 = or0_32 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_144 = or0_33 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_144, ina1_144;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_144 <= nx0_144;
    ina1_144 <= or1_32;
end
wire w0_144, w1_144;
MSKand_opini2_d2 u_or_144 (
    .ina({ina1_144, ina0_144}), .inb({or1_33, ny0_144}),
    .rnd(r[914]), .s(s[914]), .clk(clk), .out({w1_144, w0_144}));
wire or0_144 = w0_144 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_144 = w1_144;
wire nx0_145 = or0_34 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_145 = or0_35 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_145, ina1_145;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_145 <= nx0_145;
    ina1_145 <= or1_34;
end
wire w0_145, w1_145;
MSKand_opini2_d2 u_or_145 (
    .ina({ina1_145, ina0_145}), .inb({or1_35, ny0_145}),
    .rnd(r[915]), .s(s[915]), .clk(clk), .out({w1_145, w0_145}));
wire or0_145 = w0_145 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_145 = w1_145;
wire nx0_146 = or0_36 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_146 = or0_37 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_146, ina1_146;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_146 <= nx0_146;
    ina1_146 <= or1_36;
end
wire w0_146, w1_146;
MSKand_opini2_d2 u_or_146 (
    .ina({ina1_146, ina0_146}), .inb({or1_37, ny0_146}),
    .rnd(r[916]), .s(s[916]), .clk(clk), .out({w1_146, w0_146}));
wire or0_146 = w0_146 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_146 = w1_146;
wire nx0_147 = or0_38 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_147 = or0_39 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_147, ina1_147;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_147 <= nx0_147;
    ina1_147 <= or1_38;
end
wire w0_147, w1_147;
MSKand_opini2_d2 u_or_147 (
    .ina({ina1_147, ina0_147}), .inb({or1_39, ny0_147}),
    .rnd(r[917]), .s(s[917]), .clk(clk), .out({w1_147, w0_147}));
wire or0_147 = w0_147 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_147 = w1_147;
wire nx0_148 = or0_40 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_148 = or0_41 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_148, ina1_148;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_148 <= nx0_148;
    ina1_148 <= or1_40;
end
wire w0_148, w1_148;
MSKand_opini2_d2 u_or_148 (
    .ina({ina1_148, ina0_148}), .inb({or1_41, ny0_148}),
    .rnd(r[918]), .s(s[918]), .clk(clk), .out({w1_148, w0_148}));
wire or0_148 = w0_148 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_148 = w1_148;
wire nx0_149 = or0_42 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_149 = or0_43 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_149, ina1_149;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_149 <= nx0_149;
    ina1_149 <= or1_42;
end
wire w0_149, w1_149;
MSKand_opini2_d2 u_or_149 (
    .ina({ina1_149, ina0_149}), .inb({or1_43, ny0_149}),
    .rnd(r[919]), .s(s[919]), .clk(clk), .out({w1_149, w0_149}));
wire or0_149 = w0_149 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_149 = w1_149;
wire nx0_150 = or0_44 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_150 = or0_45 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_150, ina1_150;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_150 <= nx0_150;
    ina1_150 <= or1_44;
end
wire w0_150, w1_150;
MSKand_opini2_d2 u_or_150 (
    .ina({ina1_150, ina0_150}), .inb({or1_45, ny0_150}),
    .rnd(r[920]), .s(s[920]), .clk(clk), .out({w1_150, w0_150}));
wire or0_150 = w0_150 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_150 = w1_150;
wire nx0_151 = or0_46 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_151 = or0_47 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_151, ina1_151;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_151 <= nx0_151;
    ina1_151 <= or1_46;
end
wire w0_151, w1_151;
MSKand_opini2_d2 u_or_151 (
    .ina({ina1_151, ina0_151}), .inb({or1_47, ny0_151}),
    .rnd(r[921]), .s(s[921]), .clk(clk), .out({w1_151, w0_151}));
wire or0_151 = w0_151 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_151 = w1_151;
wire nx0_152 = or0_48 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_152 = or0_49 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_152, ina1_152;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_152 <= nx0_152;
    ina1_152 <= or1_48;
end
wire w0_152, w1_152;
MSKand_opini2_d2 u_or_152 (
    .ina({ina1_152, ina0_152}), .inb({or1_49, ny0_152}),
    .rnd(r[922]), .s(s[922]), .clk(clk), .out({w1_152, w0_152}));
wire or0_152 = w0_152 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_152 = w1_152;
wire nx0_153 = or0_50 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_153 = or0_51 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_153, ina1_153;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_153 <= nx0_153;
    ina1_153 <= or1_50;
end
wire w0_153, w1_153;
MSKand_opini2_d2 u_or_153 (
    .ina({ina1_153, ina0_153}), .inb({or1_51, ny0_153}),
    .rnd(r[923]), .s(s[923]), .clk(clk), .out({w1_153, w0_153}));
wire or0_153 = w0_153 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_153 = w1_153;
wire nx0_154 = or0_52 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_154 = or0_53 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_154, ina1_154;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_154 <= nx0_154;
    ina1_154 <= or1_52;
end
wire w0_154, w1_154;
MSKand_opini2_d2 u_or_154 (
    .ina({ina1_154, ina0_154}), .inb({or1_53, ny0_154}),
    .rnd(r[924]), .s(s[924]), .clk(clk), .out({w1_154, w0_154}));
wire or0_154 = w0_154 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_154 = w1_154;
wire nx0_155 = or0_54 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_155 = or0_55 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_155, ina1_155;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_155 <= nx0_155;
    ina1_155 <= or1_54;
end
wire w0_155, w1_155;
MSKand_opini2_d2 u_or_155 (
    .ina({ina1_155, ina0_155}), .inb({or1_55, ny0_155}),
    .rnd(r[925]), .s(s[925]), .clk(clk), .out({w1_155, w0_155}));
wire or0_155 = w0_155 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_155 = w1_155;
wire nx0_156 = or0_56 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_156 = or0_57 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_156, ina1_156;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_156 <= nx0_156;
    ina1_156 <= or1_56;
end
wire w0_156, w1_156;
MSKand_opini2_d2 u_or_156 (
    .ina({ina1_156, ina0_156}), .inb({or1_57, ny0_156}),
    .rnd(r[926]), .s(s[926]), .clk(clk), .out({w1_156, w0_156}));
wire or0_156 = w0_156 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_156 = w1_156;
wire nx0_157 = or0_58 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_157 = or0_59 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_157, ina1_157;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_157 <= nx0_157;
    ina1_157 <= or1_58;
end
wire w0_157, w1_157;
MSKand_opini2_d2 u_or_157 (
    .ina({ina1_157, ina0_157}), .inb({or1_59, ny0_157}),
    .rnd(r[927]), .s(s[927]), .clk(clk), .out({w1_157, w0_157}));
wire or0_157 = w0_157 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_157 = w1_157;
wire nx0_158 = or0_60 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_158 = or0_61 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_158, ina1_158;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_158 <= nx0_158;
    ina1_158 <= or1_60;
end
wire w0_158, w1_158;
MSKand_opini2_d2 u_or_158 (
    .ina({ina1_158, ina0_158}), .inb({or1_61, ny0_158}),
    .rnd(r[928]), .s(s[928]), .clk(clk), .out({w1_158, w0_158}));
wire or0_158 = w0_158 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_158 = w1_158;
wire nx0_159 = or0_62 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_159 = or0_63 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_159, ina1_159;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_159 <= nx0_159;
    ina1_159 <= or1_62;
end
wire w0_159, w1_159;
MSKand_opini2_d2 u_or_159 (
    .ina({ina1_159, ina0_159}), .inb({or1_63, ny0_159}),
    .rnd(r[929]), .s(s[929]), .clk(clk), .out({w1_159, w0_159}));
wire or0_159 = w0_159 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_159 = w1_159;
wire nx0_160 = or0_64 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_160 = or0_65 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_160, ina1_160;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_160 <= nx0_160;
    ina1_160 <= or1_64;
end
wire w0_160, w1_160;
MSKand_opini2_d2 u_or_160 (
    .ina({ina1_160, ina0_160}), .inb({or1_65, ny0_160}),
    .rnd(r[930]), .s(s[930]), .clk(clk), .out({w1_160, w0_160}));
wire or0_160 = w0_160 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_160 = w1_160;
wire nx0_161 = or0_66 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_161 = or0_67 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_161, ina1_161;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_161 <= nx0_161;
    ina1_161 <= or1_66;
end
wire w0_161, w1_161;
MSKand_opini2_d2 u_or_161 (
    .ina({ina1_161, ina0_161}), .inb({or1_67, ny0_161}),
    .rnd(r[931]), .s(s[931]), .clk(clk), .out({w1_161, w0_161}));
wire or0_161 = w0_161 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_161 = w1_161;
wire nx0_162 = or0_68 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_162 = or0_69 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_162, ina1_162;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_162 <= nx0_162;
    ina1_162 <= or1_68;
end
wire w0_162, w1_162;
MSKand_opini2_d2 u_or_162 (
    .ina({ina1_162, ina0_162}), .inb({or1_69, ny0_162}),
    .rnd(r[932]), .s(s[932]), .clk(clk), .out({w1_162, w0_162}));
wire or0_162 = w0_162 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_162 = w1_162;
wire nx0_163 = or0_70 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_163 = or0_71 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_163, ina1_163;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_163 <= nx0_163;
    ina1_163 <= or1_70;
end
wire w0_163, w1_163;
MSKand_opini2_d2 u_or_163 (
    .ina({ina1_163, ina0_163}), .inb({or1_71, ny0_163}),
    .rnd(r[933]), .s(s[933]), .clk(clk), .out({w1_163, w0_163}));
wire or0_163 = w0_163 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_163 = w1_163;
wire nx0_164 = or0_72 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_164 = or0_73 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_164, ina1_164;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_164 <= nx0_164;
    ina1_164 <= or1_72;
end
wire w0_164, w1_164;
MSKand_opini2_d2 u_or_164 (
    .ina({ina1_164, ina0_164}), .inb({or1_73, ny0_164}),
    .rnd(r[934]), .s(s[934]), .clk(clk), .out({w1_164, w0_164}));
wire or0_164 = w0_164 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_164 = w1_164;
wire nx0_165 = or0_74 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_165 = or0_75 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_165, ina1_165;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_165 <= nx0_165;
    ina1_165 <= or1_74;
end
wire w0_165, w1_165;
MSKand_opini2_d2 u_or_165 (
    .ina({ina1_165, ina0_165}), .inb({or1_75, ny0_165}),
    .rnd(r[935]), .s(s[935]), .clk(clk), .out({w1_165, w0_165}));
wire or0_165 = w0_165 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_165 = w1_165;
wire nx0_166 = or0_76 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_166 = or0_77 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_166, ina1_166;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_166 <= nx0_166;
    ina1_166 <= or1_76;
end
wire w0_166, w1_166;
MSKand_opini2_d2 u_or_166 (
    .ina({ina1_166, ina0_166}), .inb({or1_77, ny0_166}),
    .rnd(r[936]), .s(s[936]), .clk(clk), .out({w1_166, w0_166}));
wire or0_166 = w0_166 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_166 = w1_166;
wire nx0_167 = or0_78 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_167 = or0_79 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_167, ina1_167;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_167 <= nx0_167;
    ina1_167 <= or1_78;
end
wire w0_167, w1_167;
MSKand_opini2_d2 u_or_167 (
    .ina({ina1_167, ina0_167}), .inb({or1_79, ny0_167}),
    .rnd(r[937]), .s(s[937]), .clk(clk), .out({w1_167, w0_167}));
wire or0_167 = w0_167 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_167 = w1_167;
wire nx0_168 = or0_80 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_168 = or0_81 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_168, ina1_168;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_168 <= nx0_168;
    ina1_168 <= or1_80;
end
wire w0_168, w1_168;
MSKand_opini2_d2 u_or_168 (
    .ina({ina1_168, ina0_168}), .inb({or1_81, ny0_168}),
    .rnd(r[938]), .s(s[938]), .clk(clk), .out({w1_168, w0_168}));
wire or0_168 = w0_168 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_168 = w1_168;
wire nx0_169 = or0_82 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_169 = or0_83 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_169, ina1_169;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_169 <= nx0_169;
    ina1_169 <= or1_82;
end
wire w0_169, w1_169;
MSKand_opini2_d2 u_or_169 (
    .ina({ina1_169, ina0_169}), .inb({or1_83, ny0_169}),
    .rnd(r[939]), .s(s[939]), .clk(clk), .out({w1_169, w0_169}));
wire or0_169 = w0_169 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_169 = w1_169;
wire nx0_170 = or0_84 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_170 = or0_85 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_170, ina1_170;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_170 <= nx0_170;
    ina1_170 <= or1_84;
end
wire w0_170, w1_170;
MSKand_opini2_d2 u_or_170 (
    .ina({ina1_170, ina0_170}), .inb({or1_85, ny0_170}),
    .rnd(r[940]), .s(s[940]), .clk(clk), .out({w1_170, w0_170}));
wire or0_170 = w0_170 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_170 = w1_170;
wire nx0_171 = or0_86 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_171 = or0_87 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_171, ina1_171;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_171 <= nx0_171;
    ina1_171 <= or1_86;
end
wire w0_171, w1_171;
MSKand_opini2_d2 u_or_171 (
    .ina({ina1_171, ina0_171}), .inb({or1_87, ny0_171}),
    .rnd(r[941]), .s(s[941]), .clk(clk), .out({w1_171, w0_171}));
wire or0_171 = w0_171 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_171 = w1_171;
wire nx0_172 = or0_88 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_172 = or0_89 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_172, ina1_172;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_172 <= nx0_172;
    ina1_172 <= or1_88;
end
wire w0_172, w1_172;
MSKand_opini2_d2 u_or_172 (
    .ina({ina1_172, ina0_172}), .inb({or1_89, ny0_172}),
    .rnd(r[942]), .s(s[942]), .clk(clk), .out({w1_172, w0_172}));
wire or0_172 = w0_172 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_172 = w1_172;
wire nx0_173 = or0_90 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_173 = or0_91 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_173, ina1_173;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_173 <= nx0_173;
    ina1_173 <= or1_90;
end
wire w0_173, w1_173;
MSKand_opini2_d2 u_or_173 (
    .ina({ina1_173, ina0_173}), .inb({or1_91, ny0_173}),
    .rnd(r[943]), .s(s[943]), .clk(clk), .out({w1_173, w0_173}));
wire or0_173 = w0_173 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_173 = w1_173;
wire nx0_174 = or0_92 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_174 = or0_93 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_174, ina1_174;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_174 <= nx0_174;
    ina1_174 <= or1_92;
end
wire w0_174, w1_174;
MSKand_opini2_d2 u_or_174 (
    .ina({ina1_174, ina0_174}), .inb({or1_93, ny0_174}),
    .rnd(r[944]), .s(s[944]), .clk(clk), .out({w1_174, w0_174}));
wire or0_174 = w0_174 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_174 = w1_174;
wire nx0_175 = or0_94 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_175 = or0_95 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_175, ina1_175;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_175 <= nx0_175;
    ina1_175 <= or1_94;
end
wire w0_175, w1_175;
MSKand_opini2_d2 u_or_175 (
    .ina({ina1_175, ina0_175}), .inb({or1_95, ny0_175}),
    .rnd(r[945]), .s(s[945]), .clk(clk), .out({w1_175, w0_175}));
wire or0_175 = w0_175 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_175 = w1_175;
wire nx0_176 = or0_96 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_176 = or0_97 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_176, ina1_176;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_176 <= nx0_176;
    ina1_176 <= or1_96;
end
wire w0_176, w1_176;
MSKand_opini2_d2 u_or_176 (
    .ina({ina1_176, ina0_176}), .inb({or1_97, ny0_176}),
    .rnd(r[946]), .s(s[946]), .clk(clk), .out({w1_176, w0_176}));
wire or0_176 = w0_176 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_176 = w1_176;
wire nx0_177 = or0_98 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_177 = or0_99 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_177, ina1_177;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_177 <= nx0_177;
    ina1_177 <= or1_98;
end
wire w0_177, w1_177;
MSKand_opini2_d2 u_or_177 (
    .ina({ina1_177, ina0_177}), .inb({or1_99, ny0_177}),
    .rnd(r[947]), .s(s[947]), .clk(clk), .out({w1_177, w0_177}));
wire or0_177 = w0_177 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_177 = w1_177;
wire nx0_178 = or0_100 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_178 = or0_101 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_178, ina1_178;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_178 <= nx0_178;
    ina1_178 <= or1_100;
end
wire w0_178, w1_178;
MSKand_opini2_d2 u_or_178 (
    .ina({ina1_178, ina0_178}), .inb({or1_101, ny0_178}),
    .rnd(r[948]), .s(s[948]), .clk(clk), .out({w1_178, w0_178}));
wire or0_178 = w0_178 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_178 = w1_178;
wire nx0_179 = or0_102 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_179 = or0_103 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_179, ina1_179;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_179 <= nx0_179;
    ina1_179 <= or1_102;
end
wire w0_179, w1_179;
MSKand_opini2_d2 u_or_179 (
    .ina({ina1_179, ina0_179}), .inb({or1_103, ny0_179}),
    .rnd(r[949]), .s(s[949]), .clk(clk), .out({w1_179, w0_179}));
wire or0_179 = w0_179 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_179 = w1_179;
wire nx0_180 = or0_104 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_180 = or0_105 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_180, ina1_180;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_180 <= nx0_180;
    ina1_180 <= or1_104;
end
wire w0_180, w1_180;
MSKand_opini2_d2 u_or_180 (
    .ina({ina1_180, ina0_180}), .inb({or1_105, ny0_180}),
    .rnd(r[950]), .s(s[950]), .clk(clk), .out({w1_180, w0_180}));
wire or0_180 = w0_180 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_180 = w1_180;
wire nx0_181 = or0_106 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_181 = or0_107 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_181, ina1_181;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_181 <= nx0_181;
    ina1_181 <= or1_106;
end
wire w0_181, w1_181;
MSKand_opini2_d2 u_or_181 (
    .ina({ina1_181, ina0_181}), .inb({or1_107, ny0_181}),
    .rnd(r[951]), .s(s[951]), .clk(clk), .out({w1_181, w0_181}));
wire or0_181 = w0_181 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_181 = w1_181;
wire nx0_182 = or0_108 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_182 = or0_109 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_182, ina1_182;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_182 <= nx0_182;
    ina1_182 <= or1_108;
end
wire w0_182, w1_182;
MSKand_opini2_d2 u_or_182 (
    .ina({ina1_182, ina0_182}), .inb({or1_109, ny0_182}),
    .rnd(r[952]), .s(s[952]), .clk(clk), .out({w1_182, w0_182}));
wire or0_182 = w0_182 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_182 = w1_182;
wire nx0_183 = or0_110 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_183 = or0_111 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_183, ina1_183;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_183 <= nx0_183;
    ina1_183 <= or1_110;
end
wire w0_183, w1_183;
MSKand_opini2_d2 u_or_183 (
    .ina({ina1_183, ina0_183}), .inb({or1_111, ny0_183}),
    .rnd(r[953]), .s(s[953]), .clk(clk), .out({w1_183, w0_183}));
wire or0_183 = w0_183 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_183 = w1_183;
wire nx0_184 = or0_112 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_184 = or0_113 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_184, ina1_184;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_184 <= nx0_184;
    ina1_184 <= or1_112;
end
wire w0_184, w1_184;
MSKand_opini2_d2 u_or_184 (
    .ina({ina1_184, ina0_184}), .inb({or1_113, ny0_184}),
    .rnd(r[954]), .s(s[954]), .clk(clk), .out({w1_184, w0_184}));
wire or0_184 = w0_184 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_184 = w1_184;
wire nx0_185 = or0_114 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_185 = or0_115 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_185, ina1_185;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_185 <= nx0_185;
    ina1_185 <= or1_114;
end
wire w0_185, w1_185;
MSKand_opini2_d2 u_or_185 (
    .ina({ina1_185, ina0_185}), .inb({or1_115, ny0_185}),
    .rnd(r[955]), .s(s[955]), .clk(clk), .out({w1_185, w0_185}));
wire or0_185 = w0_185 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_185 = w1_185;
wire nx0_186 = or0_116 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_186 = or0_117 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_186, ina1_186;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_186 <= nx0_186;
    ina1_186 <= or1_116;
end
wire w0_186, w1_186;
MSKand_opini2_d2 u_or_186 (
    .ina({ina1_186, ina0_186}), .inb({or1_117, ny0_186}),
    .rnd(r[956]), .s(s[956]), .clk(clk), .out({w1_186, w0_186}));
wire or0_186 = w0_186 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_186 = w1_186;
wire nx0_187 = or0_118 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_187 = or0_119 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_187, ina1_187;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_187 <= nx0_187;
    ina1_187 <= or1_118;
end
wire w0_187, w1_187;
MSKand_opini2_d2 u_or_187 (
    .ina({ina1_187, ina0_187}), .inb({or1_119, ny0_187}),
    .rnd(r[957]), .s(s[957]), .clk(clk), .out({w1_187, w0_187}));
wire or0_187 = w0_187 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_187 = w1_187;
wire nx0_188 = or0_120 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_188 = or0_121 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_188, ina1_188;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_188 <= nx0_188;
    ina1_188 <= or1_120;
end
wire w0_188, w1_188;
MSKand_opini2_d2 u_or_188 (
    .ina({ina1_188, ina0_188}), .inb({or1_121, ny0_188}),
    .rnd(r[958]), .s(s[958]), .clk(clk), .out({w1_188, w0_188}));
wire or0_188 = w0_188 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_188 = w1_188;
wire nx0_189 = or0_122 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_189 = or0_123 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_189, ina1_189;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_189 <= nx0_189;
    ina1_189 <= or1_122;
end
wire w0_189, w1_189;
MSKand_opini2_d2 u_or_189 (
    .ina({ina1_189, ina0_189}), .inb({or1_123, ny0_189}),
    .rnd(r[959]), .s(s[959]), .clk(clk), .out({w1_189, w0_189}));
wire or0_189 = w0_189 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_189 = w1_189;
wire nx0_190 = or0_124 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_190 = or0_125 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_190, ina1_190;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_190 <= nx0_190;
    ina1_190 <= or1_124;
end
wire w0_190, w1_190;
MSKand_opini2_d2 u_or_190 (
    .ina({ina1_190, ina0_190}), .inb({or1_125, ny0_190}),
    .rnd(r[960]), .s(s[960]), .clk(clk), .out({w1_190, w0_190}));
wire or0_190 = w0_190 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_190 = w1_190;
wire nx0_191 = or0_126 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_191 = or0_127 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_191, ina1_191;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_191 <= nx0_191;
    ina1_191 <= or1_126;
end
wire w0_191, w1_191;
MSKand_opini2_d2 u_or_191 (
    .ina({ina1_191, ina0_191}), .inb({or1_127, ny0_191}),
    .rnd(r[961]), .s(s[961]), .clk(clk), .out({w1_191, w0_191}));
wire or0_191 = w0_191 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_191 = w1_191;

// ===== nonzero-tree OR-reduce level 2: 64 masked bits -> 32 =====
wire nx0_192 = or0_128 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_192 = or0_129 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_192, ina1_192;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_192 <= nx0_192;
    ina1_192 <= or1_128;
end
wire w0_192, w1_192;
MSKand_opini2_d2 u_or_192 (
    .ina({ina1_192, ina0_192}), .inb({or1_129, ny0_192}),
    .rnd(r[962]), .s(s[962]), .clk(clk), .out({w1_192, w0_192}));
wire or0_192 = w0_192 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_192 = w1_192;
wire nx0_193 = or0_130 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_193 = or0_131 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_193, ina1_193;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_193 <= nx0_193;
    ina1_193 <= or1_130;
end
wire w0_193, w1_193;
MSKand_opini2_d2 u_or_193 (
    .ina({ina1_193, ina0_193}), .inb({or1_131, ny0_193}),
    .rnd(r[963]), .s(s[963]), .clk(clk), .out({w1_193, w0_193}));
wire or0_193 = w0_193 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_193 = w1_193;
wire nx0_194 = or0_132 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_194 = or0_133 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_194, ina1_194;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_194 <= nx0_194;
    ina1_194 <= or1_132;
end
wire w0_194, w1_194;
MSKand_opini2_d2 u_or_194 (
    .ina({ina1_194, ina0_194}), .inb({or1_133, ny0_194}),
    .rnd(r[964]), .s(s[964]), .clk(clk), .out({w1_194, w0_194}));
wire or0_194 = w0_194 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_194 = w1_194;
wire nx0_195 = or0_134 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_195 = or0_135 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_195, ina1_195;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_195 <= nx0_195;
    ina1_195 <= or1_134;
end
wire w0_195, w1_195;
MSKand_opini2_d2 u_or_195 (
    .ina({ina1_195, ina0_195}), .inb({or1_135, ny0_195}),
    .rnd(r[965]), .s(s[965]), .clk(clk), .out({w1_195, w0_195}));
wire or0_195 = w0_195 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_195 = w1_195;
wire nx0_196 = or0_136 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_196 = or0_137 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_196, ina1_196;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_196 <= nx0_196;
    ina1_196 <= or1_136;
end
wire w0_196, w1_196;
MSKand_opini2_d2 u_or_196 (
    .ina({ina1_196, ina0_196}), .inb({or1_137, ny0_196}),
    .rnd(r[966]), .s(s[966]), .clk(clk), .out({w1_196, w0_196}));
wire or0_196 = w0_196 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_196 = w1_196;
wire nx0_197 = or0_138 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_197 = or0_139 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_197, ina1_197;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_197 <= nx0_197;
    ina1_197 <= or1_138;
end
wire w0_197, w1_197;
MSKand_opini2_d2 u_or_197 (
    .ina({ina1_197, ina0_197}), .inb({or1_139, ny0_197}),
    .rnd(r[967]), .s(s[967]), .clk(clk), .out({w1_197, w0_197}));
wire or0_197 = w0_197 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_197 = w1_197;
wire nx0_198 = or0_140 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_198 = or0_141 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_198, ina1_198;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_198 <= nx0_198;
    ina1_198 <= or1_140;
end
wire w0_198, w1_198;
MSKand_opini2_d2 u_or_198 (
    .ina({ina1_198, ina0_198}), .inb({or1_141, ny0_198}),
    .rnd(r[968]), .s(s[968]), .clk(clk), .out({w1_198, w0_198}));
wire or0_198 = w0_198 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_198 = w1_198;
wire nx0_199 = or0_142 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_199 = or0_143 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_199, ina1_199;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_199 <= nx0_199;
    ina1_199 <= or1_142;
end
wire w0_199, w1_199;
MSKand_opini2_d2 u_or_199 (
    .ina({ina1_199, ina0_199}), .inb({or1_143, ny0_199}),
    .rnd(r[969]), .s(s[969]), .clk(clk), .out({w1_199, w0_199}));
wire or0_199 = w0_199 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_199 = w1_199;
wire nx0_200 = or0_144 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_200 = or0_145 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_200, ina1_200;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_200 <= nx0_200;
    ina1_200 <= or1_144;
end
wire w0_200, w1_200;
MSKand_opini2_d2 u_or_200 (
    .ina({ina1_200, ina0_200}), .inb({or1_145, ny0_200}),
    .rnd(r[970]), .s(s[970]), .clk(clk), .out({w1_200, w0_200}));
wire or0_200 = w0_200 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_200 = w1_200;
wire nx0_201 = or0_146 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_201 = or0_147 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_201, ina1_201;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_201 <= nx0_201;
    ina1_201 <= or1_146;
end
wire w0_201, w1_201;
MSKand_opini2_d2 u_or_201 (
    .ina({ina1_201, ina0_201}), .inb({or1_147, ny0_201}),
    .rnd(r[971]), .s(s[971]), .clk(clk), .out({w1_201, w0_201}));
wire or0_201 = w0_201 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_201 = w1_201;
wire nx0_202 = or0_148 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_202 = or0_149 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_202, ina1_202;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_202 <= nx0_202;
    ina1_202 <= or1_148;
end
wire w0_202, w1_202;
MSKand_opini2_d2 u_or_202 (
    .ina({ina1_202, ina0_202}), .inb({or1_149, ny0_202}),
    .rnd(r[972]), .s(s[972]), .clk(clk), .out({w1_202, w0_202}));
wire or0_202 = w0_202 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_202 = w1_202;
wire nx0_203 = or0_150 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_203 = or0_151 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_203, ina1_203;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_203 <= nx0_203;
    ina1_203 <= or1_150;
end
wire w0_203, w1_203;
MSKand_opini2_d2 u_or_203 (
    .ina({ina1_203, ina0_203}), .inb({or1_151, ny0_203}),
    .rnd(r[973]), .s(s[973]), .clk(clk), .out({w1_203, w0_203}));
wire or0_203 = w0_203 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_203 = w1_203;
wire nx0_204 = or0_152 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_204 = or0_153 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_204, ina1_204;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_204 <= nx0_204;
    ina1_204 <= or1_152;
end
wire w0_204, w1_204;
MSKand_opini2_d2 u_or_204 (
    .ina({ina1_204, ina0_204}), .inb({or1_153, ny0_204}),
    .rnd(r[974]), .s(s[974]), .clk(clk), .out({w1_204, w0_204}));
wire or0_204 = w0_204 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_204 = w1_204;
wire nx0_205 = or0_154 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_205 = or0_155 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_205, ina1_205;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_205 <= nx0_205;
    ina1_205 <= or1_154;
end
wire w0_205, w1_205;
MSKand_opini2_d2 u_or_205 (
    .ina({ina1_205, ina0_205}), .inb({or1_155, ny0_205}),
    .rnd(r[975]), .s(s[975]), .clk(clk), .out({w1_205, w0_205}));
wire or0_205 = w0_205 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_205 = w1_205;
wire nx0_206 = or0_156 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_206 = or0_157 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_206, ina1_206;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_206 <= nx0_206;
    ina1_206 <= or1_156;
end
wire w0_206, w1_206;
MSKand_opini2_d2 u_or_206 (
    .ina({ina1_206, ina0_206}), .inb({or1_157, ny0_206}),
    .rnd(r[976]), .s(s[976]), .clk(clk), .out({w1_206, w0_206}));
wire or0_206 = w0_206 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_206 = w1_206;
wire nx0_207 = or0_158 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_207 = or0_159 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_207, ina1_207;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_207 <= nx0_207;
    ina1_207 <= or1_158;
end
wire w0_207, w1_207;
MSKand_opini2_d2 u_or_207 (
    .ina({ina1_207, ina0_207}), .inb({or1_159, ny0_207}),
    .rnd(r[977]), .s(s[977]), .clk(clk), .out({w1_207, w0_207}));
wire or0_207 = w0_207 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_207 = w1_207;
wire nx0_208 = or0_160 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_208 = or0_161 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_208, ina1_208;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_208 <= nx0_208;
    ina1_208 <= or1_160;
end
wire w0_208, w1_208;
MSKand_opini2_d2 u_or_208 (
    .ina({ina1_208, ina0_208}), .inb({or1_161, ny0_208}),
    .rnd(r[978]), .s(s[978]), .clk(clk), .out({w1_208, w0_208}));
wire or0_208 = w0_208 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_208 = w1_208;
wire nx0_209 = or0_162 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_209 = or0_163 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_209, ina1_209;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_209 <= nx0_209;
    ina1_209 <= or1_162;
end
wire w0_209, w1_209;
MSKand_opini2_d2 u_or_209 (
    .ina({ina1_209, ina0_209}), .inb({or1_163, ny0_209}),
    .rnd(r[979]), .s(s[979]), .clk(clk), .out({w1_209, w0_209}));
wire or0_209 = w0_209 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_209 = w1_209;
wire nx0_210 = or0_164 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_210 = or0_165 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_210, ina1_210;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_210 <= nx0_210;
    ina1_210 <= or1_164;
end
wire w0_210, w1_210;
MSKand_opini2_d2 u_or_210 (
    .ina({ina1_210, ina0_210}), .inb({or1_165, ny0_210}),
    .rnd(r[980]), .s(s[980]), .clk(clk), .out({w1_210, w0_210}));
wire or0_210 = w0_210 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_210 = w1_210;
wire nx0_211 = or0_166 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_211 = or0_167 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_211, ina1_211;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_211 <= nx0_211;
    ina1_211 <= or1_166;
end
wire w0_211, w1_211;
MSKand_opini2_d2 u_or_211 (
    .ina({ina1_211, ina0_211}), .inb({or1_167, ny0_211}),
    .rnd(r[981]), .s(s[981]), .clk(clk), .out({w1_211, w0_211}));
wire or0_211 = w0_211 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_211 = w1_211;
wire nx0_212 = or0_168 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_212 = or0_169 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_212, ina1_212;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_212 <= nx0_212;
    ina1_212 <= or1_168;
end
wire w0_212, w1_212;
MSKand_opini2_d2 u_or_212 (
    .ina({ina1_212, ina0_212}), .inb({or1_169, ny0_212}),
    .rnd(r[982]), .s(s[982]), .clk(clk), .out({w1_212, w0_212}));
wire or0_212 = w0_212 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_212 = w1_212;
wire nx0_213 = or0_170 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_213 = or0_171 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_213, ina1_213;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_213 <= nx0_213;
    ina1_213 <= or1_170;
end
wire w0_213, w1_213;
MSKand_opini2_d2 u_or_213 (
    .ina({ina1_213, ina0_213}), .inb({or1_171, ny0_213}),
    .rnd(r[983]), .s(s[983]), .clk(clk), .out({w1_213, w0_213}));
wire or0_213 = w0_213 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_213 = w1_213;
wire nx0_214 = or0_172 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_214 = or0_173 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_214, ina1_214;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_214 <= nx0_214;
    ina1_214 <= or1_172;
end
wire w0_214, w1_214;
MSKand_opini2_d2 u_or_214 (
    .ina({ina1_214, ina0_214}), .inb({or1_173, ny0_214}),
    .rnd(r[984]), .s(s[984]), .clk(clk), .out({w1_214, w0_214}));
wire or0_214 = w0_214 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_214 = w1_214;
wire nx0_215 = or0_174 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_215 = or0_175 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_215, ina1_215;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_215 <= nx0_215;
    ina1_215 <= or1_174;
end
wire w0_215, w1_215;
MSKand_opini2_d2 u_or_215 (
    .ina({ina1_215, ina0_215}), .inb({or1_175, ny0_215}),
    .rnd(r[985]), .s(s[985]), .clk(clk), .out({w1_215, w0_215}));
wire or0_215 = w0_215 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_215 = w1_215;
wire nx0_216 = or0_176 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_216 = or0_177 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_216, ina1_216;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_216 <= nx0_216;
    ina1_216 <= or1_176;
end
wire w0_216, w1_216;
MSKand_opini2_d2 u_or_216 (
    .ina({ina1_216, ina0_216}), .inb({or1_177, ny0_216}),
    .rnd(r[986]), .s(s[986]), .clk(clk), .out({w1_216, w0_216}));
wire or0_216 = w0_216 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_216 = w1_216;
wire nx0_217 = or0_178 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_217 = or0_179 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_217, ina1_217;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_217 <= nx0_217;
    ina1_217 <= or1_178;
end
wire w0_217, w1_217;
MSKand_opini2_d2 u_or_217 (
    .ina({ina1_217, ina0_217}), .inb({or1_179, ny0_217}),
    .rnd(r[987]), .s(s[987]), .clk(clk), .out({w1_217, w0_217}));
wire or0_217 = w0_217 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_217 = w1_217;
wire nx0_218 = or0_180 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_218 = or0_181 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_218, ina1_218;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_218 <= nx0_218;
    ina1_218 <= or1_180;
end
wire w0_218, w1_218;
MSKand_opini2_d2 u_or_218 (
    .ina({ina1_218, ina0_218}), .inb({or1_181, ny0_218}),
    .rnd(r[988]), .s(s[988]), .clk(clk), .out({w1_218, w0_218}));
wire or0_218 = w0_218 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_218 = w1_218;
wire nx0_219 = or0_182 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_219 = or0_183 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_219, ina1_219;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_219 <= nx0_219;
    ina1_219 <= or1_182;
end
wire w0_219, w1_219;
MSKand_opini2_d2 u_or_219 (
    .ina({ina1_219, ina0_219}), .inb({or1_183, ny0_219}),
    .rnd(r[989]), .s(s[989]), .clk(clk), .out({w1_219, w0_219}));
wire or0_219 = w0_219 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_219 = w1_219;
wire nx0_220 = or0_184 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_220 = or0_185 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_220, ina1_220;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_220 <= nx0_220;
    ina1_220 <= or1_184;
end
wire w0_220, w1_220;
MSKand_opini2_d2 u_or_220 (
    .ina({ina1_220, ina0_220}), .inb({or1_185, ny0_220}),
    .rnd(r[990]), .s(s[990]), .clk(clk), .out({w1_220, w0_220}));
wire or0_220 = w0_220 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_220 = w1_220;
wire nx0_221 = or0_186 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_221 = or0_187 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_221, ina1_221;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_221 <= nx0_221;
    ina1_221 <= or1_186;
end
wire w0_221, w1_221;
MSKand_opini2_d2 u_or_221 (
    .ina({ina1_221, ina0_221}), .inb({or1_187, ny0_221}),
    .rnd(r[991]), .s(s[991]), .clk(clk), .out({w1_221, w0_221}));
wire or0_221 = w0_221 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_221 = w1_221;
wire nx0_222 = or0_188 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_222 = or0_189 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_222, ina1_222;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_222 <= nx0_222;
    ina1_222 <= or1_188;
end
wire w0_222, w1_222;
MSKand_opini2_d2 u_or_222 (
    .ina({ina1_222, ina0_222}), .inb({or1_189, ny0_222}),
    .rnd(r[992]), .s(s[992]), .clk(clk), .out({w1_222, w0_222}));
wire or0_222 = w0_222 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_222 = w1_222;
wire nx0_223 = or0_190 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_223 = or0_191 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_223, ina1_223;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_223 <= nx0_223;
    ina1_223 <= or1_190;
end
wire w0_223, w1_223;
MSKand_opini2_d2 u_or_223 (
    .ina({ina1_223, ina0_223}), .inb({or1_191, ny0_223}),
    .rnd(r[993]), .s(s[993]), .clk(clk), .out({w1_223, w0_223}));
wire or0_223 = w0_223 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_223 = w1_223;

// ===== nonzero-tree OR-reduce level 3: 32 masked bits -> 16 =====
wire nx0_224 = or0_192 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_224 = or0_193 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_224, ina1_224;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_224 <= nx0_224;
    ina1_224 <= or1_192;
end
wire w0_224, w1_224;
MSKand_opini2_d2 u_or_224 (
    .ina({ina1_224, ina0_224}), .inb({or1_193, ny0_224}),
    .rnd(r[994]), .s(s[994]), .clk(clk), .out({w1_224, w0_224}));
wire or0_224 = w0_224 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_224 = w1_224;
wire nx0_225 = or0_194 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_225 = or0_195 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_225, ina1_225;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_225 <= nx0_225;
    ina1_225 <= or1_194;
end
wire w0_225, w1_225;
MSKand_opini2_d2 u_or_225 (
    .ina({ina1_225, ina0_225}), .inb({or1_195, ny0_225}),
    .rnd(r[995]), .s(s[995]), .clk(clk), .out({w1_225, w0_225}));
wire or0_225 = w0_225 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_225 = w1_225;
wire nx0_226 = or0_196 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_226 = or0_197 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_226, ina1_226;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_226 <= nx0_226;
    ina1_226 <= or1_196;
end
wire w0_226, w1_226;
MSKand_opini2_d2 u_or_226 (
    .ina({ina1_226, ina0_226}), .inb({or1_197, ny0_226}),
    .rnd(r[996]), .s(s[996]), .clk(clk), .out({w1_226, w0_226}));
wire or0_226 = w0_226 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_226 = w1_226;
wire nx0_227 = or0_198 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_227 = or0_199 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_227, ina1_227;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_227 <= nx0_227;
    ina1_227 <= or1_198;
end
wire w0_227, w1_227;
MSKand_opini2_d2 u_or_227 (
    .ina({ina1_227, ina0_227}), .inb({or1_199, ny0_227}),
    .rnd(r[997]), .s(s[997]), .clk(clk), .out({w1_227, w0_227}));
wire or0_227 = w0_227 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_227 = w1_227;
wire nx0_228 = or0_200 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_228 = or0_201 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_228, ina1_228;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_228 <= nx0_228;
    ina1_228 <= or1_200;
end
wire w0_228, w1_228;
MSKand_opini2_d2 u_or_228 (
    .ina({ina1_228, ina0_228}), .inb({or1_201, ny0_228}),
    .rnd(r[998]), .s(s[998]), .clk(clk), .out({w1_228, w0_228}));
wire or0_228 = w0_228 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_228 = w1_228;
wire nx0_229 = or0_202 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_229 = or0_203 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_229, ina1_229;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_229 <= nx0_229;
    ina1_229 <= or1_202;
end
wire w0_229, w1_229;
MSKand_opini2_d2 u_or_229 (
    .ina({ina1_229, ina0_229}), .inb({or1_203, ny0_229}),
    .rnd(r[999]), .s(s[999]), .clk(clk), .out({w1_229, w0_229}));
wire or0_229 = w0_229 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_229 = w1_229;
wire nx0_230 = or0_204 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_230 = or0_205 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_230, ina1_230;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_230 <= nx0_230;
    ina1_230 <= or1_204;
end
wire w0_230, w1_230;
MSKand_opini2_d2 u_or_230 (
    .ina({ina1_230, ina0_230}), .inb({or1_205, ny0_230}),
    .rnd(r[1000]), .s(s[1000]), .clk(clk), .out({w1_230, w0_230}));
wire or0_230 = w0_230 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_230 = w1_230;
wire nx0_231 = or0_206 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_231 = or0_207 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_231, ina1_231;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_231 <= nx0_231;
    ina1_231 <= or1_206;
end
wire w0_231, w1_231;
MSKand_opini2_d2 u_or_231 (
    .ina({ina1_231, ina0_231}), .inb({or1_207, ny0_231}),
    .rnd(r[1001]), .s(s[1001]), .clk(clk), .out({w1_231, w0_231}));
wire or0_231 = w0_231 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_231 = w1_231;
wire nx0_232 = or0_208 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_232 = or0_209 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_232, ina1_232;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_232 <= nx0_232;
    ina1_232 <= or1_208;
end
wire w0_232, w1_232;
MSKand_opini2_d2 u_or_232 (
    .ina({ina1_232, ina0_232}), .inb({or1_209, ny0_232}),
    .rnd(r[1002]), .s(s[1002]), .clk(clk), .out({w1_232, w0_232}));
wire or0_232 = w0_232 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_232 = w1_232;
wire nx0_233 = or0_210 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_233 = or0_211 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_233, ina1_233;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_233 <= nx0_233;
    ina1_233 <= or1_210;
end
wire w0_233, w1_233;
MSKand_opini2_d2 u_or_233 (
    .ina({ina1_233, ina0_233}), .inb({or1_211, ny0_233}),
    .rnd(r[1003]), .s(s[1003]), .clk(clk), .out({w1_233, w0_233}));
wire or0_233 = w0_233 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_233 = w1_233;
wire nx0_234 = or0_212 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_234 = or0_213 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_234, ina1_234;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_234 <= nx0_234;
    ina1_234 <= or1_212;
end
wire w0_234, w1_234;
MSKand_opini2_d2 u_or_234 (
    .ina({ina1_234, ina0_234}), .inb({or1_213, ny0_234}),
    .rnd(r[1004]), .s(s[1004]), .clk(clk), .out({w1_234, w0_234}));
wire or0_234 = w0_234 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_234 = w1_234;
wire nx0_235 = or0_214 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_235 = or0_215 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_235, ina1_235;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_235 <= nx0_235;
    ina1_235 <= or1_214;
end
wire w0_235, w1_235;
MSKand_opini2_d2 u_or_235 (
    .ina({ina1_235, ina0_235}), .inb({or1_215, ny0_235}),
    .rnd(r[1005]), .s(s[1005]), .clk(clk), .out({w1_235, w0_235}));
wire or0_235 = w0_235 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_235 = w1_235;
wire nx0_236 = or0_216 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_236 = or0_217 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_236, ina1_236;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_236 <= nx0_236;
    ina1_236 <= or1_216;
end
wire w0_236, w1_236;
MSKand_opini2_d2 u_or_236 (
    .ina({ina1_236, ina0_236}), .inb({or1_217, ny0_236}),
    .rnd(r[1006]), .s(s[1006]), .clk(clk), .out({w1_236, w0_236}));
wire or0_236 = w0_236 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_236 = w1_236;
wire nx0_237 = or0_218 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_237 = or0_219 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_237, ina1_237;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_237 <= nx0_237;
    ina1_237 <= or1_218;
end
wire w0_237, w1_237;
MSKand_opini2_d2 u_or_237 (
    .ina({ina1_237, ina0_237}), .inb({or1_219, ny0_237}),
    .rnd(r[1007]), .s(s[1007]), .clk(clk), .out({w1_237, w0_237}));
wire or0_237 = w0_237 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_237 = w1_237;
wire nx0_238 = or0_220 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_238 = or0_221 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_238, ina1_238;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_238 <= nx0_238;
    ina1_238 <= or1_220;
end
wire w0_238, w1_238;
MSKand_opini2_d2 u_or_238 (
    .ina({ina1_238, ina0_238}), .inb({or1_221, ny0_238}),
    .rnd(r[1008]), .s(s[1008]), .clk(clk), .out({w1_238, w0_238}));
wire or0_238 = w0_238 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_238 = w1_238;
wire nx0_239 = or0_222 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_239 = or0_223 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_239, ina1_239;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_239 <= nx0_239;
    ina1_239 <= or1_222;
end
wire w0_239, w1_239;
MSKand_opini2_d2 u_or_239 (
    .ina({ina1_239, ina0_239}), .inb({or1_223, ny0_239}),
    .rnd(r[1009]), .s(s[1009]), .clk(clk), .out({w1_239, w0_239}));
wire or0_239 = w0_239 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_239 = w1_239;

// ===== nonzero-tree OR-reduce level 4: 16 masked bits -> 8 =====
wire nx0_240 = or0_224 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_240 = or0_225 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_240, ina1_240;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_240 <= nx0_240;
    ina1_240 <= or1_224;
end
wire w0_240, w1_240;
MSKand_opini2_d2 u_or_240 (
    .ina({ina1_240, ina0_240}), .inb({or1_225, ny0_240}),
    .rnd(r[1010]), .s(s[1010]), .clk(clk), .out({w1_240, w0_240}));
wire or0_240 = w0_240 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_240 = w1_240;
wire nx0_241 = or0_226 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_241 = or0_227 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_241, ina1_241;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_241 <= nx0_241;
    ina1_241 <= or1_226;
end
wire w0_241, w1_241;
MSKand_opini2_d2 u_or_241 (
    .ina({ina1_241, ina0_241}), .inb({or1_227, ny0_241}),
    .rnd(r[1011]), .s(s[1011]), .clk(clk), .out({w1_241, w0_241}));
wire or0_241 = w0_241 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_241 = w1_241;
wire nx0_242 = or0_228 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_242 = or0_229 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_242, ina1_242;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_242 <= nx0_242;
    ina1_242 <= or1_228;
end
wire w0_242, w1_242;
MSKand_opini2_d2 u_or_242 (
    .ina({ina1_242, ina0_242}), .inb({or1_229, ny0_242}),
    .rnd(r[1012]), .s(s[1012]), .clk(clk), .out({w1_242, w0_242}));
wire or0_242 = w0_242 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_242 = w1_242;
wire nx0_243 = or0_230 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_243 = or0_231 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_243, ina1_243;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_243 <= nx0_243;
    ina1_243 <= or1_230;
end
wire w0_243, w1_243;
MSKand_opini2_d2 u_or_243 (
    .ina({ina1_243, ina0_243}), .inb({or1_231, ny0_243}),
    .rnd(r[1013]), .s(s[1013]), .clk(clk), .out({w1_243, w0_243}));
wire or0_243 = w0_243 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_243 = w1_243;
wire nx0_244 = or0_232 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_244 = or0_233 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_244, ina1_244;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_244 <= nx0_244;
    ina1_244 <= or1_232;
end
wire w0_244, w1_244;
MSKand_opini2_d2 u_or_244 (
    .ina({ina1_244, ina0_244}), .inb({or1_233, ny0_244}),
    .rnd(r[1014]), .s(s[1014]), .clk(clk), .out({w1_244, w0_244}));
wire or0_244 = w0_244 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_244 = w1_244;
wire nx0_245 = or0_234 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_245 = or0_235 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_245, ina1_245;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_245 <= nx0_245;
    ina1_245 <= or1_234;
end
wire w0_245, w1_245;
MSKand_opini2_d2 u_or_245 (
    .ina({ina1_245, ina0_245}), .inb({or1_235, ny0_245}),
    .rnd(r[1015]), .s(s[1015]), .clk(clk), .out({w1_245, w0_245}));
wire or0_245 = w0_245 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_245 = w1_245;
wire nx0_246 = or0_236 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_246 = or0_237 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_246, ina1_246;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_246 <= nx0_246;
    ina1_246 <= or1_236;
end
wire w0_246, w1_246;
MSKand_opini2_d2 u_or_246 (
    .ina({ina1_246, ina0_246}), .inb({or1_237, ny0_246}),
    .rnd(r[1016]), .s(s[1016]), .clk(clk), .out({w1_246, w0_246}));
wire or0_246 = w0_246 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_246 = w1_246;
wire nx0_247 = or0_238 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_247 = or0_239 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_247, ina1_247;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_247 <= nx0_247;
    ina1_247 <= or1_238;
end
wire w0_247, w1_247;
MSKand_opini2_d2 u_or_247 (
    .ina({ina1_247, ina0_247}), .inb({or1_239, ny0_247}),
    .rnd(r[1017]), .s(s[1017]), .clk(clk), .out({w1_247, w0_247}));
wire or0_247 = w0_247 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_247 = w1_247;

// ===== nonzero-tree OR-reduce level 5: 8 masked bits -> 4 =====
wire nx0_248 = or0_240 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_248 = or0_241 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_248, ina1_248;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_248 <= nx0_248;
    ina1_248 <= or1_240;
end
wire w0_248, w1_248;
MSKand_opini2_d2 u_or_248 (
    .ina({ina1_248, ina0_248}), .inb({or1_241, ny0_248}),
    .rnd(r[1018]), .s(s[1018]), .clk(clk), .out({w1_248, w0_248}));
wire or0_248 = w0_248 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_248 = w1_248;
wire nx0_249 = or0_242 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_249 = or0_243 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_249, ina1_249;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_249 <= nx0_249;
    ina1_249 <= or1_242;
end
wire w0_249, w1_249;
MSKand_opini2_d2 u_or_249 (
    .ina({ina1_249, ina0_249}), .inb({or1_243, ny0_249}),
    .rnd(r[1019]), .s(s[1019]), .clk(clk), .out({w1_249, w0_249}));
wire or0_249 = w0_249 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_249 = w1_249;
wire nx0_250 = or0_244 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_250 = or0_245 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_250, ina1_250;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_250 <= nx0_250;
    ina1_250 <= or1_244;
end
wire w0_250, w1_250;
MSKand_opini2_d2 u_or_250 (
    .ina({ina1_250, ina0_250}), .inb({or1_245, ny0_250}),
    .rnd(r[1020]), .s(s[1020]), .clk(clk), .out({w1_250, w0_250}));
wire or0_250 = w0_250 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_250 = w1_250;
wire nx0_251 = or0_246 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_251 = or0_247 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_251, ina1_251;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_251 <= nx0_251;
    ina1_251 <= or1_246;
end
wire w0_251, w1_251;
MSKand_opini2_d2 u_or_251 (
    .ina({ina1_251, ina0_251}), .inb({or1_247, ny0_251}),
    .rnd(r[1021]), .s(s[1021]), .clk(clk), .out({w1_251, w0_251}));
wire or0_251 = w0_251 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_251 = w1_251;

// ===== nonzero-tree OR-reduce level 6: 4 masked bits -> 2 =====
wire nx0_252 = or0_248 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_252 = or0_249 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_252, ina1_252;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_252 <= nx0_252;
    ina1_252 <= or1_248;
end
wire w0_252, w1_252;
MSKand_opini2_d2 u_or_252 (
    .ina({ina1_252, ina0_252}), .inb({or1_249, ny0_252}),
    .rnd(r[1022]), .s(s[1022]), .clk(clk), .out({w1_252, w0_252}));
wire or0_252 = w0_252 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_252 = w1_252;
wire nx0_253 = or0_250 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_253 = or0_251 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_253, ina1_253;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_253 <= nx0_253;
    ina1_253 <= or1_250;
end
wire w0_253, w1_253;
MSKand_opini2_d2 u_or_253 (
    .ina({ina1_253, ina0_253}), .inb({or1_251, ny0_253}),
    .rnd(r[1023]), .s(s[1023]), .clk(clk), .out({w1_253, w0_253}));
wire or0_253 = w0_253 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_253 = w1_253;

// ===== nonzero-tree OR-reduce level 7: 2 masked bits -> 1 =====
wire nx0_254 = or0_252 ^ 1'b1;   // NOT childA, share-local (share 0)
wire ny0_254 = or0_253 ^ 1'b1;   // NOT childB, share-local (share 0)
(* keep = "yes" *) reg ina0_254, ina1_254;   // 1-cycle ina balance reg (per-share)
always @(posedge clk) begin
    ina0_254 <= nx0_254;
    ina1_254 <= or1_252;
end
wire w0_254, w1_254;
MSKand_opini2_d2 u_or_254 (
    .ina({ina1_254, ina0_254}), .inb({or1_253, ny0_254}),
    .rnd(r[1024]), .s(s[1024]), .clk(clk), .out({w1_254, w0_254}));
wire or0_254 = w0_254 ^ 1'b1;   // OR = NOT(AND(..)), share-local (share 0)
wire or1_254 = w1_254;

// tree root = OR-reduce(B) = (B != 0) — exactly the gate NOT(ISZERO(B))
assign nz0 = or0_254;
assign nz1 = or1_254;

// ===== EVM zero-gating: qe[j] = Q[j] AND (B!=0), reme[j] = R[j] AND (B!=0) =====
wire wq0_0, wq1_0;
MSKand_opini2_d2 u_gq_0 (
    .ina({q_d1[0], q_d0[0]}), .inb({nzr1, nzr0}),
    .rnd(r[1025]), .s(s[1025]), .clk(clk), .out({wq1_0, wq0_0}));
assign qe[0] = wq0_0;  assign qe[1] = wq1_0;
wire wq0_1, wq1_1;
MSKand_opini2_d2 u_gq_1 (  // BUG UNDER TEST: reuses u_gq_0's randomness
    .ina({q_d1[1], q_d0[1]}), .inb({nzr1, nzr0}),
    .rnd(r[1025]), .s(s[1025]), .clk(clk), .out({wq1_1, wq0_1}));
assign qe[2] = wq0_1;  assign qe[3] = wq1_1;
wire wq0_2, wq1_2;
MSKand_opini2_d2 u_gq_2 (
    .ina({q_d1[2], q_d0[2]}), .inb({nzr1, nzr0}),
    .rnd(r[1027]), .s(s[1027]), .clk(clk), .out({wq1_2, wq0_2}));
assign qe[4] = wq0_2;  assign qe[5] = wq1_2;
wire wq0_3, wq1_3;
MSKand_opini2_d2 u_gq_3 (
    .ina({q_d1[3], q_d0[3]}), .inb({nzr1, nzr0}),
    .rnd(r[1028]), .s(s[1028]), .clk(clk), .out({wq1_3, wq0_3}));
assign qe[6] = wq0_3;  assign qe[7] = wq1_3;
wire wq0_4, wq1_4;
MSKand_opini2_d2 u_gq_4 (
    .ina({q_d1[4], q_d0[4]}), .inb({nzr1, nzr0}),
    .rnd(r[1029]), .s(s[1029]), .clk(clk), .out({wq1_4, wq0_4}));
assign qe[8] = wq0_4;  assign qe[9] = wq1_4;
wire wq0_5, wq1_5;
MSKand_opini2_d2 u_gq_5 (
    .ina({q_d1[5], q_d0[5]}), .inb({nzr1, nzr0}),
    .rnd(r[1030]), .s(s[1030]), .clk(clk), .out({wq1_5, wq0_5}));
assign qe[10] = wq0_5;  assign qe[11] = wq1_5;
wire wq0_6, wq1_6;
MSKand_opini2_d2 u_gq_6 (
    .ina({q_d1[6], q_d0[6]}), .inb({nzr1, nzr0}),
    .rnd(r[1031]), .s(s[1031]), .clk(clk), .out({wq1_6, wq0_6}));
assign qe[12] = wq0_6;  assign qe[13] = wq1_6;
wire wq0_7, wq1_7;
MSKand_opini2_d2 u_gq_7 (
    .ina({q_d1[7], q_d0[7]}), .inb({nzr1, nzr0}),
    .rnd(r[1032]), .s(s[1032]), .clk(clk), .out({wq1_7, wq0_7}));
assign qe[14] = wq0_7;  assign qe[15] = wq1_7;
wire wq0_8, wq1_8;
MSKand_opini2_d2 u_gq_8 (
    .ina({q_d1[8], q_d0[8]}), .inb({nzr1, nzr0}),
    .rnd(r[1033]), .s(s[1033]), .clk(clk), .out({wq1_8, wq0_8}));
assign qe[16] = wq0_8;  assign qe[17] = wq1_8;
wire wq0_9, wq1_9;
MSKand_opini2_d2 u_gq_9 (
    .ina({q_d1[9], q_d0[9]}), .inb({nzr1, nzr0}),
    .rnd(r[1034]), .s(s[1034]), .clk(clk), .out({wq1_9, wq0_9}));
assign qe[18] = wq0_9;  assign qe[19] = wq1_9;
wire wq0_10, wq1_10;
MSKand_opini2_d2 u_gq_10 (
    .ina({q_d1[10], q_d0[10]}), .inb({nzr1, nzr0}),
    .rnd(r[1035]), .s(s[1035]), .clk(clk), .out({wq1_10, wq0_10}));
assign qe[20] = wq0_10;  assign qe[21] = wq1_10;
wire wq0_11, wq1_11;
MSKand_opini2_d2 u_gq_11 (
    .ina({q_d1[11], q_d0[11]}), .inb({nzr1, nzr0}),
    .rnd(r[1036]), .s(s[1036]), .clk(clk), .out({wq1_11, wq0_11}));
assign qe[22] = wq0_11;  assign qe[23] = wq1_11;
wire wq0_12, wq1_12;
MSKand_opini2_d2 u_gq_12 (
    .ina({q_d1[12], q_d0[12]}), .inb({nzr1, nzr0}),
    .rnd(r[1037]), .s(s[1037]), .clk(clk), .out({wq1_12, wq0_12}));
assign qe[24] = wq0_12;  assign qe[25] = wq1_12;
wire wq0_13, wq1_13;
MSKand_opini2_d2 u_gq_13 (
    .ina({q_d1[13], q_d0[13]}), .inb({nzr1, nzr0}),
    .rnd(r[1038]), .s(s[1038]), .clk(clk), .out({wq1_13, wq0_13}));
assign qe[26] = wq0_13;  assign qe[27] = wq1_13;
wire wq0_14, wq1_14;
MSKand_opini2_d2 u_gq_14 (
    .ina({q_d1[14], q_d0[14]}), .inb({nzr1, nzr0}),
    .rnd(r[1039]), .s(s[1039]), .clk(clk), .out({wq1_14, wq0_14}));
assign qe[28] = wq0_14;  assign qe[29] = wq1_14;
wire wq0_15, wq1_15;
MSKand_opini2_d2 u_gq_15 (
    .ina({q_d1[15], q_d0[15]}), .inb({nzr1, nzr0}),
    .rnd(r[1040]), .s(s[1040]), .clk(clk), .out({wq1_15, wq0_15}));
assign qe[30] = wq0_15;  assign qe[31] = wq1_15;
wire wq0_16, wq1_16;
MSKand_opini2_d2 u_gq_16 (
    .ina({q_d1[16], q_d0[16]}), .inb({nzr1, nzr0}),
    .rnd(r[1041]), .s(s[1041]), .clk(clk), .out({wq1_16, wq0_16}));
assign qe[32] = wq0_16;  assign qe[33] = wq1_16;
wire wq0_17, wq1_17;
MSKand_opini2_d2 u_gq_17 (
    .ina({q_d1[17], q_d0[17]}), .inb({nzr1, nzr0}),
    .rnd(r[1042]), .s(s[1042]), .clk(clk), .out({wq1_17, wq0_17}));
assign qe[34] = wq0_17;  assign qe[35] = wq1_17;
wire wq0_18, wq1_18;
MSKand_opini2_d2 u_gq_18 (
    .ina({q_d1[18], q_d0[18]}), .inb({nzr1, nzr0}),
    .rnd(r[1043]), .s(s[1043]), .clk(clk), .out({wq1_18, wq0_18}));
assign qe[36] = wq0_18;  assign qe[37] = wq1_18;
wire wq0_19, wq1_19;
MSKand_opini2_d2 u_gq_19 (
    .ina({q_d1[19], q_d0[19]}), .inb({nzr1, nzr0}),
    .rnd(r[1044]), .s(s[1044]), .clk(clk), .out({wq1_19, wq0_19}));
assign qe[38] = wq0_19;  assign qe[39] = wq1_19;
wire wq0_20, wq1_20;
MSKand_opini2_d2 u_gq_20 (
    .ina({q_d1[20], q_d0[20]}), .inb({nzr1, nzr0}),
    .rnd(r[1045]), .s(s[1045]), .clk(clk), .out({wq1_20, wq0_20}));
assign qe[40] = wq0_20;  assign qe[41] = wq1_20;
wire wq0_21, wq1_21;
MSKand_opini2_d2 u_gq_21 (
    .ina({q_d1[21], q_d0[21]}), .inb({nzr1, nzr0}),
    .rnd(r[1046]), .s(s[1046]), .clk(clk), .out({wq1_21, wq0_21}));
assign qe[42] = wq0_21;  assign qe[43] = wq1_21;
wire wq0_22, wq1_22;
MSKand_opini2_d2 u_gq_22 (
    .ina({q_d1[22], q_d0[22]}), .inb({nzr1, nzr0}),
    .rnd(r[1047]), .s(s[1047]), .clk(clk), .out({wq1_22, wq0_22}));
assign qe[44] = wq0_22;  assign qe[45] = wq1_22;
wire wq0_23, wq1_23;
MSKand_opini2_d2 u_gq_23 (
    .ina({q_d1[23], q_d0[23]}), .inb({nzr1, nzr0}),
    .rnd(r[1048]), .s(s[1048]), .clk(clk), .out({wq1_23, wq0_23}));
assign qe[46] = wq0_23;  assign qe[47] = wq1_23;
wire wq0_24, wq1_24;
MSKand_opini2_d2 u_gq_24 (
    .ina({q_d1[24], q_d0[24]}), .inb({nzr1, nzr0}),
    .rnd(r[1049]), .s(s[1049]), .clk(clk), .out({wq1_24, wq0_24}));
assign qe[48] = wq0_24;  assign qe[49] = wq1_24;
wire wq0_25, wq1_25;
MSKand_opini2_d2 u_gq_25 (
    .ina({q_d1[25], q_d0[25]}), .inb({nzr1, nzr0}),
    .rnd(r[1050]), .s(s[1050]), .clk(clk), .out({wq1_25, wq0_25}));
assign qe[50] = wq0_25;  assign qe[51] = wq1_25;
wire wq0_26, wq1_26;
MSKand_opini2_d2 u_gq_26 (
    .ina({q_d1[26], q_d0[26]}), .inb({nzr1, nzr0}),
    .rnd(r[1051]), .s(s[1051]), .clk(clk), .out({wq1_26, wq0_26}));
assign qe[52] = wq0_26;  assign qe[53] = wq1_26;
wire wq0_27, wq1_27;
MSKand_opini2_d2 u_gq_27 (
    .ina({q_d1[27], q_d0[27]}), .inb({nzr1, nzr0}),
    .rnd(r[1052]), .s(s[1052]), .clk(clk), .out({wq1_27, wq0_27}));
assign qe[54] = wq0_27;  assign qe[55] = wq1_27;
wire wq0_28, wq1_28;
MSKand_opini2_d2 u_gq_28 (
    .ina({q_d1[28], q_d0[28]}), .inb({nzr1, nzr0}),
    .rnd(r[1053]), .s(s[1053]), .clk(clk), .out({wq1_28, wq0_28}));
assign qe[56] = wq0_28;  assign qe[57] = wq1_28;
wire wq0_29, wq1_29;
MSKand_opini2_d2 u_gq_29 (
    .ina({q_d1[29], q_d0[29]}), .inb({nzr1, nzr0}),
    .rnd(r[1054]), .s(s[1054]), .clk(clk), .out({wq1_29, wq0_29}));
assign qe[58] = wq0_29;  assign qe[59] = wq1_29;
wire wq0_30, wq1_30;
MSKand_opini2_d2 u_gq_30 (
    .ina({q_d1[30], q_d0[30]}), .inb({nzr1, nzr0}),
    .rnd(r[1055]), .s(s[1055]), .clk(clk), .out({wq1_30, wq0_30}));
assign qe[60] = wq0_30;  assign qe[61] = wq1_30;
wire wq0_31, wq1_31;
MSKand_opini2_d2 u_gq_31 (
    .ina({q_d1[31], q_d0[31]}), .inb({nzr1, nzr0}),
    .rnd(r[1056]), .s(s[1056]), .clk(clk), .out({wq1_31, wq0_31}));
assign qe[62] = wq0_31;  assign qe[63] = wq1_31;
wire wq0_32, wq1_32;
MSKand_opini2_d2 u_gq_32 (
    .ina({q_d1[32], q_d0[32]}), .inb({nzr1, nzr0}),
    .rnd(r[1057]), .s(s[1057]), .clk(clk), .out({wq1_32, wq0_32}));
assign qe[64] = wq0_32;  assign qe[65] = wq1_32;
wire wq0_33, wq1_33;
MSKand_opini2_d2 u_gq_33 (
    .ina({q_d1[33], q_d0[33]}), .inb({nzr1, nzr0}),
    .rnd(r[1058]), .s(s[1058]), .clk(clk), .out({wq1_33, wq0_33}));
assign qe[66] = wq0_33;  assign qe[67] = wq1_33;
wire wq0_34, wq1_34;
MSKand_opini2_d2 u_gq_34 (
    .ina({q_d1[34], q_d0[34]}), .inb({nzr1, nzr0}),
    .rnd(r[1059]), .s(s[1059]), .clk(clk), .out({wq1_34, wq0_34}));
assign qe[68] = wq0_34;  assign qe[69] = wq1_34;
wire wq0_35, wq1_35;
MSKand_opini2_d2 u_gq_35 (
    .ina({q_d1[35], q_d0[35]}), .inb({nzr1, nzr0}),
    .rnd(r[1060]), .s(s[1060]), .clk(clk), .out({wq1_35, wq0_35}));
assign qe[70] = wq0_35;  assign qe[71] = wq1_35;
wire wq0_36, wq1_36;
MSKand_opini2_d2 u_gq_36 (
    .ina({q_d1[36], q_d0[36]}), .inb({nzr1, nzr0}),
    .rnd(r[1061]), .s(s[1061]), .clk(clk), .out({wq1_36, wq0_36}));
assign qe[72] = wq0_36;  assign qe[73] = wq1_36;
wire wq0_37, wq1_37;
MSKand_opini2_d2 u_gq_37 (
    .ina({q_d1[37], q_d0[37]}), .inb({nzr1, nzr0}),
    .rnd(r[1062]), .s(s[1062]), .clk(clk), .out({wq1_37, wq0_37}));
assign qe[74] = wq0_37;  assign qe[75] = wq1_37;
wire wq0_38, wq1_38;
MSKand_opini2_d2 u_gq_38 (
    .ina({q_d1[38], q_d0[38]}), .inb({nzr1, nzr0}),
    .rnd(r[1063]), .s(s[1063]), .clk(clk), .out({wq1_38, wq0_38}));
assign qe[76] = wq0_38;  assign qe[77] = wq1_38;
wire wq0_39, wq1_39;
MSKand_opini2_d2 u_gq_39 (
    .ina({q_d1[39], q_d0[39]}), .inb({nzr1, nzr0}),
    .rnd(r[1064]), .s(s[1064]), .clk(clk), .out({wq1_39, wq0_39}));
assign qe[78] = wq0_39;  assign qe[79] = wq1_39;
wire wq0_40, wq1_40;
MSKand_opini2_d2 u_gq_40 (
    .ina({q_d1[40], q_d0[40]}), .inb({nzr1, nzr0}),
    .rnd(r[1065]), .s(s[1065]), .clk(clk), .out({wq1_40, wq0_40}));
assign qe[80] = wq0_40;  assign qe[81] = wq1_40;
wire wq0_41, wq1_41;
MSKand_opini2_d2 u_gq_41 (
    .ina({q_d1[41], q_d0[41]}), .inb({nzr1, nzr0}),
    .rnd(r[1066]), .s(s[1066]), .clk(clk), .out({wq1_41, wq0_41}));
assign qe[82] = wq0_41;  assign qe[83] = wq1_41;
wire wq0_42, wq1_42;
MSKand_opini2_d2 u_gq_42 (
    .ina({q_d1[42], q_d0[42]}), .inb({nzr1, nzr0}),
    .rnd(r[1067]), .s(s[1067]), .clk(clk), .out({wq1_42, wq0_42}));
assign qe[84] = wq0_42;  assign qe[85] = wq1_42;
wire wq0_43, wq1_43;
MSKand_opini2_d2 u_gq_43 (
    .ina({q_d1[43], q_d0[43]}), .inb({nzr1, nzr0}),
    .rnd(r[1068]), .s(s[1068]), .clk(clk), .out({wq1_43, wq0_43}));
assign qe[86] = wq0_43;  assign qe[87] = wq1_43;
wire wq0_44, wq1_44;
MSKand_opini2_d2 u_gq_44 (
    .ina({q_d1[44], q_d0[44]}), .inb({nzr1, nzr0}),
    .rnd(r[1069]), .s(s[1069]), .clk(clk), .out({wq1_44, wq0_44}));
assign qe[88] = wq0_44;  assign qe[89] = wq1_44;
wire wq0_45, wq1_45;
MSKand_opini2_d2 u_gq_45 (
    .ina({q_d1[45], q_d0[45]}), .inb({nzr1, nzr0}),
    .rnd(r[1070]), .s(s[1070]), .clk(clk), .out({wq1_45, wq0_45}));
assign qe[90] = wq0_45;  assign qe[91] = wq1_45;
wire wq0_46, wq1_46;
MSKand_opini2_d2 u_gq_46 (
    .ina({q_d1[46], q_d0[46]}), .inb({nzr1, nzr0}),
    .rnd(r[1071]), .s(s[1071]), .clk(clk), .out({wq1_46, wq0_46}));
assign qe[92] = wq0_46;  assign qe[93] = wq1_46;
wire wq0_47, wq1_47;
MSKand_opini2_d2 u_gq_47 (
    .ina({q_d1[47], q_d0[47]}), .inb({nzr1, nzr0}),
    .rnd(r[1072]), .s(s[1072]), .clk(clk), .out({wq1_47, wq0_47}));
assign qe[94] = wq0_47;  assign qe[95] = wq1_47;
wire wq0_48, wq1_48;
MSKand_opini2_d2 u_gq_48 (
    .ina({q_d1[48], q_d0[48]}), .inb({nzr1, nzr0}),
    .rnd(r[1073]), .s(s[1073]), .clk(clk), .out({wq1_48, wq0_48}));
assign qe[96] = wq0_48;  assign qe[97] = wq1_48;
wire wq0_49, wq1_49;
MSKand_opini2_d2 u_gq_49 (
    .ina({q_d1[49], q_d0[49]}), .inb({nzr1, nzr0}),
    .rnd(r[1074]), .s(s[1074]), .clk(clk), .out({wq1_49, wq0_49}));
assign qe[98] = wq0_49;  assign qe[99] = wq1_49;
wire wq0_50, wq1_50;
MSKand_opini2_d2 u_gq_50 (
    .ina({q_d1[50], q_d0[50]}), .inb({nzr1, nzr0}),
    .rnd(r[1075]), .s(s[1075]), .clk(clk), .out({wq1_50, wq0_50}));
assign qe[100] = wq0_50;  assign qe[101] = wq1_50;
wire wq0_51, wq1_51;
MSKand_opini2_d2 u_gq_51 (
    .ina({q_d1[51], q_d0[51]}), .inb({nzr1, nzr0}),
    .rnd(r[1076]), .s(s[1076]), .clk(clk), .out({wq1_51, wq0_51}));
assign qe[102] = wq0_51;  assign qe[103] = wq1_51;
wire wq0_52, wq1_52;
MSKand_opini2_d2 u_gq_52 (
    .ina({q_d1[52], q_d0[52]}), .inb({nzr1, nzr0}),
    .rnd(r[1077]), .s(s[1077]), .clk(clk), .out({wq1_52, wq0_52}));
assign qe[104] = wq0_52;  assign qe[105] = wq1_52;
wire wq0_53, wq1_53;
MSKand_opini2_d2 u_gq_53 (
    .ina({q_d1[53], q_d0[53]}), .inb({nzr1, nzr0}),
    .rnd(r[1078]), .s(s[1078]), .clk(clk), .out({wq1_53, wq0_53}));
assign qe[106] = wq0_53;  assign qe[107] = wq1_53;
wire wq0_54, wq1_54;
MSKand_opini2_d2 u_gq_54 (
    .ina({q_d1[54], q_d0[54]}), .inb({nzr1, nzr0}),
    .rnd(r[1079]), .s(s[1079]), .clk(clk), .out({wq1_54, wq0_54}));
assign qe[108] = wq0_54;  assign qe[109] = wq1_54;
wire wq0_55, wq1_55;
MSKand_opini2_d2 u_gq_55 (
    .ina({q_d1[55], q_d0[55]}), .inb({nzr1, nzr0}),
    .rnd(r[1080]), .s(s[1080]), .clk(clk), .out({wq1_55, wq0_55}));
assign qe[110] = wq0_55;  assign qe[111] = wq1_55;
wire wq0_56, wq1_56;
MSKand_opini2_d2 u_gq_56 (
    .ina({q_d1[56], q_d0[56]}), .inb({nzr1, nzr0}),
    .rnd(r[1081]), .s(s[1081]), .clk(clk), .out({wq1_56, wq0_56}));
assign qe[112] = wq0_56;  assign qe[113] = wq1_56;
wire wq0_57, wq1_57;
MSKand_opini2_d2 u_gq_57 (
    .ina({q_d1[57], q_d0[57]}), .inb({nzr1, nzr0}),
    .rnd(r[1082]), .s(s[1082]), .clk(clk), .out({wq1_57, wq0_57}));
assign qe[114] = wq0_57;  assign qe[115] = wq1_57;
wire wq0_58, wq1_58;
MSKand_opini2_d2 u_gq_58 (
    .ina({q_d1[58], q_d0[58]}), .inb({nzr1, nzr0}),
    .rnd(r[1083]), .s(s[1083]), .clk(clk), .out({wq1_58, wq0_58}));
assign qe[116] = wq0_58;  assign qe[117] = wq1_58;
wire wq0_59, wq1_59;
MSKand_opini2_d2 u_gq_59 (
    .ina({q_d1[59], q_d0[59]}), .inb({nzr1, nzr0}),
    .rnd(r[1084]), .s(s[1084]), .clk(clk), .out({wq1_59, wq0_59}));
assign qe[118] = wq0_59;  assign qe[119] = wq1_59;
wire wq0_60, wq1_60;
MSKand_opini2_d2 u_gq_60 (
    .ina({q_d1[60], q_d0[60]}), .inb({nzr1, nzr0}),
    .rnd(r[1085]), .s(s[1085]), .clk(clk), .out({wq1_60, wq0_60}));
assign qe[120] = wq0_60;  assign qe[121] = wq1_60;
wire wq0_61, wq1_61;
MSKand_opini2_d2 u_gq_61 (
    .ina({q_d1[61], q_d0[61]}), .inb({nzr1, nzr0}),
    .rnd(r[1086]), .s(s[1086]), .clk(clk), .out({wq1_61, wq0_61}));
assign qe[122] = wq0_61;  assign qe[123] = wq1_61;
wire wq0_62, wq1_62;
MSKand_opini2_d2 u_gq_62 (
    .ina({q_d1[62], q_d0[62]}), .inb({nzr1, nzr0}),
    .rnd(r[1087]), .s(s[1087]), .clk(clk), .out({wq1_62, wq0_62}));
assign qe[124] = wq0_62;  assign qe[125] = wq1_62;
wire wq0_63, wq1_63;
MSKand_opini2_d2 u_gq_63 (
    .ina({q_d1[63], q_d0[63]}), .inb({nzr1, nzr0}),
    .rnd(r[1088]), .s(s[1088]), .clk(clk), .out({wq1_63, wq0_63}));
assign qe[126] = wq0_63;  assign qe[127] = wq1_63;
wire wq0_64, wq1_64;
MSKand_opini2_d2 u_gq_64 (
    .ina({q_d1[64], q_d0[64]}), .inb({nzr1, nzr0}),
    .rnd(r[1089]), .s(s[1089]), .clk(clk), .out({wq1_64, wq0_64}));
assign qe[128] = wq0_64;  assign qe[129] = wq1_64;
wire wq0_65, wq1_65;
MSKand_opini2_d2 u_gq_65 (
    .ina({q_d1[65], q_d0[65]}), .inb({nzr1, nzr0}),
    .rnd(r[1090]), .s(s[1090]), .clk(clk), .out({wq1_65, wq0_65}));
assign qe[130] = wq0_65;  assign qe[131] = wq1_65;
wire wq0_66, wq1_66;
MSKand_opini2_d2 u_gq_66 (
    .ina({q_d1[66], q_d0[66]}), .inb({nzr1, nzr0}),
    .rnd(r[1091]), .s(s[1091]), .clk(clk), .out({wq1_66, wq0_66}));
assign qe[132] = wq0_66;  assign qe[133] = wq1_66;
wire wq0_67, wq1_67;
MSKand_opini2_d2 u_gq_67 (
    .ina({q_d1[67], q_d0[67]}), .inb({nzr1, nzr0}),
    .rnd(r[1092]), .s(s[1092]), .clk(clk), .out({wq1_67, wq0_67}));
assign qe[134] = wq0_67;  assign qe[135] = wq1_67;
wire wq0_68, wq1_68;
MSKand_opini2_d2 u_gq_68 (
    .ina({q_d1[68], q_d0[68]}), .inb({nzr1, nzr0}),
    .rnd(r[1093]), .s(s[1093]), .clk(clk), .out({wq1_68, wq0_68}));
assign qe[136] = wq0_68;  assign qe[137] = wq1_68;
wire wq0_69, wq1_69;
MSKand_opini2_d2 u_gq_69 (
    .ina({q_d1[69], q_d0[69]}), .inb({nzr1, nzr0}),
    .rnd(r[1094]), .s(s[1094]), .clk(clk), .out({wq1_69, wq0_69}));
assign qe[138] = wq0_69;  assign qe[139] = wq1_69;
wire wq0_70, wq1_70;
MSKand_opini2_d2 u_gq_70 (
    .ina({q_d1[70], q_d0[70]}), .inb({nzr1, nzr0}),
    .rnd(r[1095]), .s(s[1095]), .clk(clk), .out({wq1_70, wq0_70}));
assign qe[140] = wq0_70;  assign qe[141] = wq1_70;
wire wq0_71, wq1_71;
MSKand_opini2_d2 u_gq_71 (
    .ina({q_d1[71], q_d0[71]}), .inb({nzr1, nzr0}),
    .rnd(r[1096]), .s(s[1096]), .clk(clk), .out({wq1_71, wq0_71}));
assign qe[142] = wq0_71;  assign qe[143] = wq1_71;
wire wq0_72, wq1_72;
MSKand_opini2_d2 u_gq_72 (
    .ina({q_d1[72], q_d0[72]}), .inb({nzr1, nzr0}),
    .rnd(r[1097]), .s(s[1097]), .clk(clk), .out({wq1_72, wq0_72}));
assign qe[144] = wq0_72;  assign qe[145] = wq1_72;
wire wq0_73, wq1_73;
MSKand_opini2_d2 u_gq_73 (
    .ina({q_d1[73], q_d0[73]}), .inb({nzr1, nzr0}),
    .rnd(r[1098]), .s(s[1098]), .clk(clk), .out({wq1_73, wq0_73}));
assign qe[146] = wq0_73;  assign qe[147] = wq1_73;
wire wq0_74, wq1_74;
MSKand_opini2_d2 u_gq_74 (
    .ina({q_d1[74], q_d0[74]}), .inb({nzr1, nzr0}),
    .rnd(r[1099]), .s(s[1099]), .clk(clk), .out({wq1_74, wq0_74}));
assign qe[148] = wq0_74;  assign qe[149] = wq1_74;
wire wq0_75, wq1_75;
MSKand_opini2_d2 u_gq_75 (
    .ina({q_d1[75], q_d0[75]}), .inb({nzr1, nzr0}),
    .rnd(r[1100]), .s(s[1100]), .clk(clk), .out({wq1_75, wq0_75}));
assign qe[150] = wq0_75;  assign qe[151] = wq1_75;
wire wq0_76, wq1_76;
MSKand_opini2_d2 u_gq_76 (
    .ina({q_d1[76], q_d0[76]}), .inb({nzr1, nzr0}),
    .rnd(r[1101]), .s(s[1101]), .clk(clk), .out({wq1_76, wq0_76}));
assign qe[152] = wq0_76;  assign qe[153] = wq1_76;
wire wq0_77, wq1_77;
MSKand_opini2_d2 u_gq_77 (
    .ina({q_d1[77], q_d0[77]}), .inb({nzr1, nzr0}),
    .rnd(r[1102]), .s(s[1102]), .clk(clk), .out({wq1_77, wq0_77}));
assign qe[154] = wq0_77;  assign qe[155] = wq1_77;
wire wq0_78, wq1_78;
MSKand_opini2_d2 u_gq_78 (
    .ina({q_d1[78], q_d0[78]}), .inb({nzr1, nzr0}),
    .rnd(r[1103]), .s(s[1103]), .clk(clk), .out({wq1_78, wq0_78}));
assign qe[156] = wq0_78;  assign qe[157] = wq1_78;
wire wq0_79, wq1_79;
MSKand_opini2_d2 u_gq_79 (
    .ina({q_d1[79], q_d0[79]}), .inb({nzr1, nzr0}),
    .rnd(r[1104]), .s(s[1104]), .clk(clk), .out({wq1_79, wq0_79}));
assign qe[158] = wq0_79;  assign qe[159] = wq1_79;
wire wq0_80, wq1_80;
MSKand_opini2_d2 u_gq_80 (
    .ina({q_d1[80], q_d0[80]}), .inb({nzr1, nzr0}),
    .rnd(r[1105]), .s(s[1105]), .clk(clk), .out({wq1_80, wq0_80}));
assign qe[160] = wq0_80;  assign qe[161] = wq1_80;
wire wq0_81, wq1_81;
MSKand_opini2_d2 u_gq_81 (
    .ina({q_d1[81], q_d0[81]}), .inb({nzr1, nzr0}),
    .rnd(r[1106]), .s(s[1106]), .clk(clk), .out({wq1_81, wq0_81}));
assign qe[162] = wq0_81;  assign qe[163] = wq1_81;
wire wq0_82, wq1_82;
MSKand_opini2_d2 u_gq_82 (
    .ina({q_d1[82], q_d0[82]}), .inb({nzr1, nzr0}),
    .rnd(r[1107]), .s(s[1107]), .clk(clk), .out({wq1_82, wq0_82}));
assign qe[164] = wq0_82;  assign qe[165] = wq1_82;
wire wq0_83, wq1_83;
MSKand_opini2_d2 u_gq_83 (
    .ina({q_d1[83], q_d0[83]}), .inb({nzr1, nzr0}),
    .rnd(r[1108]), .s(s[1108]), .clk(clk), .out({wq1_83, wq0_83}));
assign qe[166] = wq0_83;  assign qe[167] = wq1_83;
wire wq0_84, wq1_84;
MSKand_opini2_d2 u_gq_84 (
    .ina({q_d1[84], q_d0[84]}), .inb({nzr1, nzr0}),
    .rnd(r[1109]), .s(s[1109]), .clk(clk), .out({wq1_84, wq0_84}));
assign qe[168] = wq0_84;  assign qe[169] = wq1_84;
wire wq0_85, wq1_85;
MSKand_opini2_d2 u_gq_85 (
    .ina({q_d1[85], q_d0[85]}), .inb({nzr1, nzr0}),
    .rnd(r[1110]), .s(s[1110]), .clk(clk), .out({wq1_85, wq0_85}));
assign qe[170] = wq0_85;  assign qe[171] = wq1_85;
wire wq0_86, wq1_86;
MSKand_opini2_d2 u_gq_86 (
    .ina({q_d1[86], q_d0[86]}), .inb({nzr1, nzr0}),
    .rnd(r[1111]), .s(s[1111]), .clk(clk), .out({wq1_86, wq0_86}));
assign qe[172] = wq0_86;  assign qe[173] = wq1_86;
wire wq0_87, wq1_87;
MSKand_opini2_d2 u_gq_87 (
    .ina({q_d1[87], q_d0[87]}), .inb({nzr1, nzr0}),
    .rnd(r[1112]), .s(s[1112]), .clk(clk), .out({wq1_87, wq0_87}));
assign qe[174] = wq0_87;  assign qe[175] = wq1_87;
wire wq0_88, wq1_88;
MSKand_opini2_d2 u_gq_88 (
    .ina({q_d1[88], q_d0[88]}), .inb({nzr1, nzr0}),
    .rnd(r[1113]), .s(s[1113]), .clk(clk), .out({wq1_88, wq0_88}));
assign qe[176] = wq0_88;  assign qe[177] = wq1_88;
wire wq0_89, wq1_89;
MSKand_opini2_d2 u_gq_89 (
    .ina({q_d1[89], q_d0[89]}), .inb({nzr1, nzr0}),
    .rnd(r[1114]), .s(s[1114]), .clk(clk), .out({wq1_89, wq0_89}));
assign qe[178] = wq0_89;  assign qe[179] = wq1_89;
wire wq0_90, wq1_90;
MSKand_opini2_d2 u_gq_90 (
    .ina({q_d1[90], q_d0[90]}), .inb({nzr1, nzr0}),
    .rnd(r[1115]), .s(s[1115]), .clk(clk), .out({wq1_90, wq0_90}));
assign qe[180] = wq0_90;  assign qe[181] = wq1_90;
wire wq0_91, wq1_91;
MSKand_opini2_d2 u_gq_91 (
    .ina({q_d1[91], q_d0[91]}), .inb({nzr1, nzr0}),
    .rnd(r[1116]), .s(s[1116]), .clk(clk), .out({wq1_91, wq0_91}));
assign qe[182] = wq0_91;  assign qe[183] = wq1_91;
wire wq0_92, wq1_92;
MSKand_opini2_d2 u_gq_92 (
    .ina({q_d1[92], q_d0[92]}), .inb({nzr1, nzr0}),
    .rnd(r[1117]), .s(s[1117]), .clk(clk), .out({wq1_92, wq0_92}));
assign qe[184] = wq0_92;  assign qe[185] = wq1_92;
wire wq0_93, wq1_93;
MSKand_opini2_d2 u_gq_93 (
    .ina({q_d1[93], q_d0[93]}), .inb({nzr1, nzr0}),
    .rnd(r[1118]), .s(s[1118]), .clk(clk), .out({wq1_93, wq0_93}));
assign qe[186] = wq0_93;  assign qe[187] = wq1_93;
wire wq0_94, wq1_94;
MSKand_opini2_d2 u_gq_94 (
    .ina({q_d1[94], q_d0[94]}), .inb({nzr1, nzr0}),
    .rnd(r[1119]), .s(s[1119]), .clk(clk), .out({wq1_94, wq0_94}));
assign qe[188] = wq0_94;  assign qe[189] = wq1_94;
wire wq0_95, wq1_95;
MSKand_opini2_d2 u_gq_95 (
    .ina({q_d1[95], q_d0[95]}), .inb({nzr1, nzr0}),
    .rnd(r[1120]), .s(s[1120]), .clk(clk), .out({wq1_95, wq0_95}));
assign qe[190] = wq0_95;  assign qe[191] = wq1_95;
wire wq0_96, wq1_96;
MSKand_opini2_d2 u_gq_96 (
    .ina({q_d1[96], q_d0[96]}), .inb({nzr1, nzr0}),
    .rnd(r[1121]), .s(s[1121]), .clk(clk), .out({wq1_96, wq0_96}));
assign qe[192] = wq0_96;  assign qe[193] = wq1_96;
wire wq0_97, wq1_97;
MSKand_opini2_d2 u_gq_97 (
    .ina({q_d1[97], q_d0[97]}), .inb({nzr1, nzr0}),
    .rnd(r[1122]), .s(s[1122]), .clk(clk), .out({wq1_97, wq0_97}));
assign qe[194] = wq0_97;  assign qe[195] = wq1_97;
wire wq0_98, wq1_98;
MSKand_opini2_d2 u_gq_98 (
    .ina({q_d1[98], q_d0[98]}), .inb({nzr1, nzr0}),
    .rnd(r[1123]), .s(s[1123]), .clk(clk), .out({wq1_98, wq0_98}));
assign qe[196] = wq0_98;  assign qe[197] = wq1_98;
wire wq0_99, wq1_99;
MSKand_opini2_d2 u_gq_99 (
    .ina({q_d1[99], q_d0[99]}), .inb({nzr1, nzr0}),
    .rnd(r[1124]), .s(s[1124]), .clk(clk), .out({wq1_99, wq0_99}));
assign qe[198] = wq0_99;  assign qe[199] = wq1_99;
wire wq0_100, wq1_100;
MSKand_opini2_d2 u_gq_100 (
    .ina({q_d1[100], q_d0[100]}), .inb({nzr1, nzr0}),
    .rnd(r[1125]), .s(s[1125]), .clk(clk), .out({wq1_100, wq0_100}));
assign qe[200] = wq0_100;  assign qe[201] = wq1_100;
wire wq0_101, wq1_101;
MSKand_opini2_d2 u_gq_101 (
    .ina({q_d1[101], q_d0[101]}), .inb({nzr1, nzr0}),
    .rnd(r[1126]), .s(s[1126]), .clk(clk), .out({wq1_101, wq0_101}));
assign qe[202] = wq0_101;  assign qe[203] = wq1_101;
wire wq0_102, wq1_102;
MSKand_opini2_d2 u_gq_102 (
    .ina({q_d1[102], q_d0[102]}), .inb({nzr1, nzr0}),
    .rnd(r[1127]), .s(s[1127]), .clk(clk), .out({wq1_102, wq0_102}));
assign qe[204] = wq0_102;  assign qe[205] = wq1_102;
wire wq0_103, wq1_103;
MSKand_opini2_d2 u_gq_103 (
    .ina({q_d1[103], q_d0[103]}), .inb({nzr1, nzr0}),
    .rnd(r[1128]), .s(s[1128]), .clk(clk), .out({wq1_103, wq0_103}));
assign qe[206] = wq0_103;  assign qe[207] = wq1_103;
wire wq0_104, wq1_104;
MSKand_opini2_d2 u_gq_104 (
    .ina({q_d1[104], q_d0[104]}), .inb({nzr1, nzr0}),
    .rnd(r[1129]), .s(s[1129]), .clk(clk), .out({wq1_104, wq0_104}));
assign qe[208] = wq0_104;  assign qe[209] = wq1_104;
wire wq0_105, wq1_105;
MSKand_opini2_d2 u_gq_105 (
    .ina({q_d1[105], q_d0[105]}), .inb({nzr1, nzr0}),
    .rnd(r[1130]), .s(s[1130]), .clk(clk), .out({wq1_105, wq0_105}));
assign qe[210] = wq0_105;  assign qe[211] = wq1_105;
wire wq0_106, wq1_106;
MSKand_opini2_d2 u_gq_106 (
    .ina({q_d1[106], q_d0[106]}), .inb({nzr1, nzr0}),
    .rnd(r[1131]), .s(s[1131]), .clk(clk), .out({wq1_106, wq0_106}));
assign qe[212] = wq0_106;  assign qe[213] = wq1_106;
wire wq0_107, wq1_107;
MSKand_opini2_d2 u_gq_107 (
    .ina({q_d1[107], q_d0[107]}), .inb({nzr1, nzr0}),
    .rnd(r[1132]), .s(s[1132]), .clk(clk), .out({wq1_107, wq0_107}));
assign qe[214] = wq0_107;  assign qe[215] = wq1_107;
wire wq0_108, wq1_108;
MSKand_opini2_d2 u_gq_108 (
    .ina({q_d1[108], q_d0[108]}), .inb({nzr1, nzr0}),
    .rnd(r[1133]), .s(s[1133]), .clk(clk), .out({wq1_108, wq0_108}));
assign qe[216] = wq0_108;  assign qe[217] = wq1_108;
wire wq0_109, wq1_109;
MSKand_opini2_d2 u_gq_109 (
    .ina({q_d1[109], q_d0[109]}), .inb({nzr1, nzr0}),
    .rnd(r[1134]), .s(s[1134]), .clk(clk), .out({wq1_109, wq0_109}));
assign qe[218] = wq0_109;  assign qe[219] = wq1_109;
wire wq0_110, wq1_110;
MSKand_opini2_d2 u_gq_110 (
    .ina({q_d1[110], q_d0[110]}), .inb({nzr1, nzr0}),
    .rnd(r[1135]), .s(s[1135]), .clk(clk), .out({wq1_110, wq0_110}));
assign qe[220] = wq0_110;  assign qe[221] = wq1_110;
wire wq0_111, wq1_111;
MSKand_opini2_d2 u_gq_111 (
    .ina({q_d1[111], q_d0[111]}), .inb({nzr1, nzr0}),
    .rnd(r[1136]), .s(s[1136]), .clk(clk), .out({wq1_111, wq0_111}));
assign qe[222] = wq0_111;  assign qe[223] = wq1_111;
wire wq0_112, wq1_112;
MSKand_opini2_d2 u_gq_112 (
    .ina({q_d1[112], q_d0[112]}), .inb({nzr1, nzr0}),
    .rnd(r[1137]), .s(s[1137]), .clk(clk), .out({wq1_112, wq0_112}));
assign qe[224] = wq0_112;  assign qe[225] = wq1_112;
wire wq0_113, wq1_113;
MSKand_opini2_d2 u_gq_113 (
    .ina({q_d1[113], q_d0[113]}), .inb({nzr1, nzr0}),
    .rnd(r[1138]), .s(s[1138]), .clk(clk), .out({wq1_113, wq0_113}));
assign qe[226] = wq0_113;  assign qe[227] = wq1_113;
wire wq0_114, wq1_114;
MSKand_opini2_d2 u_gq_114 (
    .ina({q_d1[114], q_d0[114]}), .inb({nzr1, nzr0}),
    .rnd(r[1139]), .s(s[1139]), .clk(clk), .out({wq1_114, wq0_114}));
assign qe[228] = wq0_114;  assign qe[229] = wq1_114;
wire wq0_115, wq1_115;
MSKand_opini2_d2 u_gq_115 (
    .ina({q_d1[115], q_d0[115]}), .inb({nzr1, nzr0}),
    .rnd(r[1140]), .s(s[1140]), .clk(clk), .out({wq1_115, wq0_115}));
assign qe[230] = wq0_115;  assign qe[231] = wq1_115;
wire wq0_116, wq1_116;
MSKand_opini2_d2 u_gq_116 (
    .ina({q_d1[116], q_d0[116]}), .inb({nzr1, nzr0}),
    .rnd(r[1141]), .s(s[1141]), .clk(clk), .out({wq1_116, wq0_116}));
assign qe[232] = wq0_116;  assign qe[233] = wq1_116;
wire wq0_117, wq1_117;
MSKand_opini2_d2 u_gq_117 (
    .ina({q_d1[117], q_d0[117]}), .inb({nzr1, nzr0}),
    .rnd(r[1142]), .s(s[1142]), .clk(clk), .out({wq1_117, wq0_117}));
assign qe[234] = wq0_117;  assign qe[235] = wq1_117;
wire wq0_118, wq1_118;
MSKand_opini2_d2 u_gq_118 (
    .ina({q_d1[118], q_d0[118]}), .inb({nzr1, nzr0}),
    .rnd(r[1143]), .s(s[1143]), .clk(clk), .out({wq1_118, wq0_118}));
assign qe[236] = wq0_118;  assign qe[237] = wq1_118;
wire wq0_119, wq1_119;
MSKand_opini2_d2 u_gq_119 (
    .ina({q_d1[119], q_d0[119]}), .inb({nzr1, nzr0}),
    .rnd(r[1144]), .s(s[1144]), .clk(clk), .out({wq1_119, wq0_119}));
assign qe[238] = wq0_119;  assign qe[239] = wq1_119;
wire wq0_120, wq1_120;
MSKand_opini2_d2 u_gq_120 (
    .ina({q_d1[120], q_d0[120]}), .inb({nzr1, nzr0}),
    .rnd(r[1145]), .s(s[1145]), .clk(clk), .out({wq1_120, wq0_120}));
assign qe[240] = wq0_120;  assign qe[241] = wq1_120;
wire wq0_121, wq1_121;
MSKand_opini2_d2 u_gq_121 (
    .ina({q_d1[121], q_d0[121]}), .inb({nzr1, nzr0}),
    .rnd(r[1146]), .s(s[1146]), .clk(clk), .out({wq1_121, wq0_121}));
assign qe[242] = wq0_121;  assign qe[243] = wq1_121;
wire wq0_122, wq1_122;
MSKand_opini2_d2 u_gq_122 (
    .ina({q_d1[122], q_d0[122]}), .inb({nzr1, nzr0}),
    .rnd(r[1147]), .s(s[1147]), .clk(clk), .out({wq1_122, wq0_122}));
assign qe[244] = wq0_122;  assign qe[245] = wq1_122;
wire wq0_123, wq1_123;
MSKand_opini2_d2 u_gq_123 (
    .ina({q_d1[123], q_d0[123]}), .inb({nzr1, nzr0}),
    .rnd(r[1148]), .s(s[1148]), .clk(clk), .out({wq1_123, wq0_123}));
assign qe[246] = wq0_123;  assign qe[247] = wq1_123;
wire wq0_124, wq1_124;
MSKand_opini2_d2 u_gq_124 (
    .ina({q_d1[124], q_d0[124]}), .inb({nzr1, nzr0}),
    .rnd(r[1149]), .s(s[1149]), .clk(clk), .out({wq1_124, wq0_124}));
assign qe[248] = wq0_124;  assign qe[249] = wq1_124;
wire wq0_125, wq1_125;
MSKand_opini2_d2 u_gq_125 (
    .ina({q_d1[125], q_d0[125]}), .inb({nzr1, nzr0}),
    .rnd(r[1150]), .s(s[1150]), .clk(clk), .out({wq1_125, wq0_125}));
assign qe[250] = wq0_125;  assign qe[251] = wq1_125;
wire wq0_126, wq1_126;
MSKand_opini2_d2 u_gq_126 (
    .ina({q_d1[126], q_d0[126]}), .inb({nzr1, nzr0}),
    .rnd(r[1151]), .s(s[1151]), .clk(clk), .out({wq1_126, wq0_126}));
assign qe[252] = wq0_126;  assign qe[253] = wq1_126;
wire wq0_127, wq1_127;
MSKand_opini2_d2 u_gq_127 (
    .ina({q_d1[127], q_d0[127]}), .inb({nzr1, nzr0}),
    .rnd(r[1152]), .s(s[1152]), .clk(clk), .out({wq1_127, wq0_127}));
assign qe[254] = wq0_127;  assign qe[255] = wq1_127;
wire wq0_128, wq1_128;
MSKand_opini2_d2 u_gq_128 (
    .ina({q_d1[128], q_d0[128]}), .inb({nzr1, nzr0}),
    .rnd(r[1153]), .s(s[1153]), .clk(clk), .out({wq1_128, wq0_128}));
assign qe[256] = wq0_128;  assign qe[257] = wq1_128;
wire wq0_129, wq1_129;
MSKand_opini2_d2 u_gq_129 (
    .ina({q_d1[129], q_d0[129]}), .inb({nzr1, nzr0}),
    .rnd(r[1154]), .s(s[1154]), .clk(clk), .out({wq1_129, wq0_129}));
assign qe[258] = wq0_129;  assign qe[259] = wq1_129;
wire wq0_130, wq1_130;
MSKand_opini2_d2 u_gq_130 (
    .ina({q_d1[130], q_d0[130]}), .inb({nzr1, nzr0}),
    .rnd(r[1155]), .s(s[1155]), .clk(clk), .out({wq1_130, wq0_130}));
assign qe[260] = wq0_130;  assign qe[261] = wq1_130;
wire wq0_131, wq1_131;
MSKand_opini2_d2 u_gq_131 (
    .ina({q_d1[131], q_d0[131]}), .inb({nzr1, nzr0}),
    .rnd(r[1156]), .s(s[1156]), .clk(clk), .out({wq1_131, wq0_131}));
assign qe[262] = wq0_131;  assign qe[263] = wq1_131;
wire wq0_132, wq1_132;
MSKand_opini2_d2 u_gq_132 (
    .ina({q_d1[132], q_d0[132]}), .inb({nzr1, nzr0}),
    .rnd(r[1157]), .s(s[1157]), .clk(clk), .out({wq1_132, wq0_132}));
assign qe[264] = wq0_132;  assign qe[265] = wq1_132;
wire wq0_133, wq1_133;
MSKand_opini2_d2 u_gq_133 (
    .ina({q_d1[133], q_d0[133]}), .inb({nzr1, nzr0}),
    .rnd(r[1158]), .s(s[1158]), .clk(clk), .out({wq1_133, wq0_133}));
assign qe[266] = wq0_133;  assign qe[267] = wq1_133;
wire wq0_134, wq1_134;
MSKand_opini2_d2 u_gq_134 (
    .ina({q_d1[134], q_d0[134]}), .inb({nzr1, nzr0}),
    .rnd(r[1159]), .s(s[1159]), .clk(clk), .out({wq1_134, wq0_134}));
assign qe[268] = wq0_134;  assign qe[269] = wq1_134;
wire wq0_135, wq1_135;
MSKand_opini2_d2 u_gq_135 (
    .ina({q_d1[135], q_d0[135]}), .inb({nzr1, nzr0}),
    .rnd(r[1160]), .s(s[1160]), .clk(clk), .out({wq1_135, wq0_135}));
assign qe[270] = wq0_135;  assign qe[271] = wq1_135;
wire wq0_136, wq1_136;
MSKand_opini2_d2 u_gq_136 (
    .ina({q_d1[136], q_d0[136]}), .inb({nzr1, nzr0}),
    .rnd(r[1161]), .s(s[1161]), .clk(clk), .out({wq1_136, wq0_136}));
assign qe[272] = wq0_136;  assign qe[273] = wq1_136;
wire wq0_137, wq1_137;
MSKand_opini2_d2 u_gq_137 (
    .ina({q_d1[137], q_d0[137]}), .inb({nzr1, nzr0}),
    .rnd(r[1162]), .s(s[1162]), .clk(clk), .out({wq1_137, wq0_137}));
assign qe[274] = wq0_137;  assign qe[275] = wq1_137;
wire wq0_138, wq1_138;
MSKand_opini2_d2 u_gq_138 (
    .ina({q_d1[138], q_d0[138]}), .inb({nzr1, nzr0}),
    .rnd(r[1163]), .s(s[1163]), .clk(clk), .out({wq1_138, wq0_138}));
assign qe[276] = wq0_138;  assign qe[277] = wq1_138;
wire wq0_139, wq1_139;
MSKand_opini2_d2 u_gq_139 (
    .ina({q_d1[139], q_d0[139]}), .inb({nzr1, nzr0}),
    .rnd(r[1164]), .s(s[1164]), .clk(clk), .out({wq1_139, wq0_139}));
assign qe[278] = wq0_139;  assign qe[279] = wq1_139;
wire wq0_140, wq1_140;
MSKand_opini2_d2 u_gq_140 (
    .ina({q_d1[140], q_d0[140]}), .inb({nzr1, nzr0}),
    .rnd(r[1165]), .s(s[1165]), .clk(clk), .out({wq1_140, wq0_140}));
assign qe[280] = wq0_140;  assign qe[281] = wq1_140;
wire wq0_141, wq1_141;
MSKand_opini2_d2 u_gq_141 (
    .ina({q_d1[141], q_d0[141]}), .inb({nzr1, nzr0}),
    .rnd(r[1166]), .s(s[1166]), .clk(clk), .out({wq1_141, wq0_141}));
assign qe[282] = wq0_141;  assign qe[283] = wq1_141;
wire wq0_142, wq1_142;
MSKand_opini2_d2 u_gq_142 (
    .ina({q_d1[142], q_d0[142]}), .inb({nzr1, nzr0}),
    .rnd(r[1167]), .s(s[1167]), .clk(clk), .out({wq1_142, wq0_142}));
assign qe[284] = wq0_142;  assign qe[285] = wq1_142;
wire wq0_143, wq1_143;
MSKand_opini2_d2 u_gq_143 (
    .ina({q_d1[143], q_d0[143]}), .inb({nzr1, nzr0}),
    .rnd(r[1168]), .s(s[1168]), .clk(clk), .out({wq1_143, wq0_143}));
assign qe[286] = wq0_143;  assign qe[287] = wq1_143;
wire wq0_144, wq1_144;
MSKand_opini2_d2 u_gq_144 (
    .ina({q_d1[144], q_d0[144]}), .inb({nzr1, nzr0}),
    .rnd(r[1169]), .s(s[1169]), .clk(clk), .out({wq1_144, wq0_144}));
assign qe[288] = wq0_144;  assign qe[289] = wq1_144;
wire wq0_145, wq1_145;
MSKand_opini2_d2 u_gq_145 (
    .ina({q_d1[145], q_d0[145]}), .inb({nzr1, nzr0}),
    .rnd(r[1170]), .s(s[1170]), .clk(clk), .out({wq1_145, wq0_145}));
assign qe[290] = wq0_145;  assign qe[291] = wq1_145;
wire wq0_146, wq1_146;
MSKand_opini2_d2 u_gq_146 (
    .ina({q_d1[146], q_d0[146]}), .inb({nzr1, nzr0}),
    .rnd(r[1171]), .s(s[1171]), .clk(clk), .out({wq1_146, wq0_146}));
assign qe[292] = wq0_146;  assign qe[293] = wq1_146;
wire wq0_147, wq1_147;
MSKand_opini2_d2 u_gq_147 (
    .ina({q_d1[147], q_d0[147]}), .inb({nzr1, nzr0}),
    .rnd(r[1172]), .s(s[1172]), .clk(clk), .out({wq1_147, wq0_147}));
assign qe[294] = wq0_147;  assign qe[295] = wq1_147;
wire wq0_148, wq1_148;
MSKand_opini2_d2 u_gq_148 (
    .ina({q_d1[148], q_d0[148]}), .inb({nzr1, nzr0}),
    .rnd(r[1173]), .s(s[1173]), .clk(clk), .out({wq1_148, wq0_148}));
assign qe[296] = wq0_148;  assign qe[297] = wq1_148;
wire wq0_149, wq1_149;
MSKand_opini2_d2 u_gq_149 (
    .ina({q_d1[149], q_d0[149]}), .inb({nzr1, nzr0}),
    .rnd(r[1174]), .s(s[1174]), .clk(clk), .out({wq1_149, wq0_149}));
assign qe[298] = wq0_149;  assign qe[299] = wq1_149;
wire wq0_150, wq1_150;
MSKand_opini2_d2 u_gq_150 (
    .ina({q_d1[150], q_d0[150]}), .inb({nzr1, nzr0}),
    .rnd(r[1175]), .s(s[1175]), .clk(clk), .out({wq1_150, wq0_150}));
assign qe[300] = wq0_150;  assign qe[301] = wq1_150;
wire wq0_151, wq1_151;
MSKand_opini2_d2 u_gq_151 (
    .ina({q_d1[151], q_d0[151]}), .inb({nzr1, nzr0}),
    .rnd(r[1176]), .s(s[1176]), .clk(clk), .out({wq1_151, wq0_151}));
assign qe[302] = wq0_151;  assign qe[303] = wq1_151;
wire wq0_152, wq1_152;
MSKand_opini2_d2 u_gq_152 (
    .ina({q_d1[152], q_d0[152]}), .inb({nzr1, nzr0}),
    .rnd(r[1177]), .s(s[1177]), .clk(clk), .out({wq1_152, wq0_152}));
assign qe[304] = wq0_152;  assign qe[305] = wq1_152;
wire wq0_153, wq1_153;
MSKand_opini2_d2 u_gq_153 (
    .ina({q_d1[153], q_d0[153]}), .inb({nzr1, nzr0}),
    .rnd(r[1178]), .s(s[1178]), .clk(clk), .out({wq1_153, wq0_153}));
assign qe[306] = wq0_153;  assign qe[307] = wq1_153;
wire wq0_154, wq1_154;
MSKand_opini2_d2 u_gq_154 (
    .ina({q_d1[154], q_d0[154]}), .inb({nzr1, nzr0}),
    .rnd(r[1179]), .s(s[1179]), .clk(clk), .out({wq1_154, wq0_154}));
assign qe[308] = wq0_154;  assign qe[309] = wq1_154;
wire wq0_155, wq1_155;
MSKand_opini2_d2 u_gq_155 (
    .ina({q_d1[155], q_d0[155]}), .inb({nzr1, nzr0}),
    .rnd(r[1180]), .s(s[1180]), .clk(clk), .out({wq1_155, wq0_155}));
assign qe[310] = wq0_155;  assign qe[311] = wq1_155;
wire wq0_156, wq1_156;
MSKand_opini2_d2 u_gq_156 (
    .ina({q_d1[156], q_d0[156]}), .inb({nzr1, nzr0}),
    .rnd(r[1181]), .s(s[1181]), .clk(clk), .out({wq1_156, wq0_156}));
assign qe[312] = wq0_156;  assign qe[313] = wq1_156;
wire wq0_157, wq1_157;
MSKand_opini2_d2 u_gq_157 (
    .ina({q_d1[157], q_d0[157]}), .inb({nzr1, nzr0}),
    .rnd(r[1182]), .s(s[1182]), .clk(clk), .out({wq1_157, wq0_157}));
assign qe[314] = wq0_157;  assign qe[315] = wq1_157;
wire wq0_158, wq1_158;
MSKand_opini2_d2 u_gq_158 (
    .ina({q_d1[158], q_d0[158]}), .inb({nzr1, nzr0}),
    .rnd(r[1183]), .s(s[1183]), .clk(clk), .out({wq1_158, wq0_158}));
assign qe[316] = wq0_158;  assign qe[317] = wq1_158;
wire wq0_159, wq1_159;
MSKand_opini2_d2 u_gq_159 (
    .ina({q_d1[159], q_d0[159]}), .inb({nzr1, nzr0}),
    .rnd(r[1184]), .s(s[1184]), .clk(clk), .out({wq1_159, wq0_159}));
assign qe[318] = wq0_159;  assign qe[319] = wq1_159;
wire wq0_160, wq1_160;
MSKand_opini2_d2 u_gq_160 (
    .ina({q_d1[160], q_d0[160]}), .inb({nzr1, nzr0}),
    .rnd(r[1185]), .s(s[1185]), .clk(clk), .out({wq1_160, wq0_160}));
assign qe[320] = wq0_160;  assign qe[321] = wq1_160;
wire wq0_161, wq1_161;
MSKand_opini2_d2 u_gq_161 (
    .ina({q_d1[161], q_d0[161]}), .inb({nzr1, nzr0}),
    .rnd(r[1186]), .s(s[1186]), .clk(clk), .out({wq1_161, wq0_161}));
assign qe[322] = wq0_161;  assign qe[323] = wq1_161;
wire wq0_162, wq1_162;
MSKand_opini2_d2 u_gq_162 (
    .ina({q_d1[162], q_d0[162]}), .inb({nzr1, nzr0}),
    .rnd(r[1187]), .s(s[1187]), .clk(clk), .out({wq1_162, wq0_162}));
assign qe[324] = wq0_162;  assign qe[325] = wq1_162;
wire wq0_163, wq1_163;
MSKand_opini2_d2 u_gq_163 (
    .ina({q_d1[163], q_d0[163]}), .inb({nzr1, nzr0}),
    .rnd(r[1188]), .s(s[1188]), .clk(clk), .out({wq1_163, wq0_163}));
assign qe[326] = wq0_163;  assign qe[327] = wq1_163;
wire wq0_164, wq1_164;
MSKand_opini2_d2 u_gq_164 (
    .ina({q_d1[164], q_d0[164]}), .inb({nzr1, nzr0}),
    .rnd(r[1189]), .s(s[1189]), .clk(clk), .out({wq1_164, wq0_164}));
assign qe[328] = wq0_164;  assign qe[329] = wq1_164;
wire wq0_165, wq1_165;
MSKand_opini2_d2 u_gq_165 (
    .ina({q_d1[165], q_d0[165]}), .inb({nzr1, nzr0}),
    .rnd(r[1190]), .s(s[1190]), .clk(clk), .out({wq1_165, wq0_165}));
assign qe[330] = wq0_165;  assign qe[331] = wq1_165;
wire wq0_166, wq1_166;
MSKand_opini2_d2 u_gq_166 (
    .ina({q_d1[166], q_d0[166]}), .inb({nzr1, nzr0}),
    .rnd(r[1191]), .s(s[1191]), .clk(clk), .out({wq1_166, wq0_166}));
assign qe[332] = wq0_166;  assign qe[333] = wq1_166;
wire wq0_167, wq1_167;
MSKand_opini2_d2 u_gq_167 (
    .ina({q_d1[167], q_d0[167]}), .inb({nzr1, nzr0}),
    .rnd(r[1192]), .s(s[1192]), .clk(clk), .out({wq1_167, wq0_167}));
assign qe[334] = wq0_167;  assign qe[335] = wq1_167;
wire wq0_168, wq1_168;
MSKand_opini2_d2 u_gq_168 (
    .ina({q_d1[168], q_d0[168]}), .inb({nzr1, nzr0}),
    .rnd(r[1193]), .s(s[1193]), .clk(clk), .out({wq1_168, wq0_168}));
assign qe[336] = wq0_168;  assign qe[337] = wq1_168;
wire wq0_169, wq1_169;
MSKand_opini2_d2 u_gq_169 (
    .ina({q_d1[169], q_d0[169]}), .inb({nzr1, nzr0}),
    .rnd(r[1194]), .s(s[1194]), .clk(clk), .out({wq1_169, wq0_169}));
assign qe[338] = wq0_169;  assign qe[339] = wq1_169;
wire wq0_170, wq1_170;
MSKand_opini2_d2 u_gq_170 (
    .ina({q_d1[170], q_d0[170]}), .inb({nzr1, nzr0}),
    .rnd(r[1195]), .s(s[1195]), .clk(clk), .out({wq1_170, wq0_170}));
assign qe[340] = wq0_170;  assign qe[341] = wq1_170;
wire wq0_171, wq1_171;
MSKand_opini2_d2 u_gq_171 (
    .ina({q_d1[171], q_d0[171]}), .inb({nzr1, nzr0}),
    .rnd(r[1196]), .s(s[1196]), .clk(clk), .out({wq1_171, wq0_171}));
assign qe[342] = wq0_171;  assign qe[343] = wq1_171;
wire wq0_172, wq1_172;
MSKand_opini2_d2 u_gq_172 (
    .ina({q_d1[172], q_d0[172]}), .inb({nzr1, nzr0}),
    .rnd(r[1197]), .s(s[1197]), .clk(clk), .out({wq1_172, wq0_172}));
assign qe[344] = wq0_172;  assign qe[345] = wq1_172;
wire wq0_173, wq1_173;
MSKand_opini2_d2 u_gq_173 (
    .ina({q_d1[173], q_d0[173]}), .inb({nzr1, nzr0}),
    .rnd(r[1198]), .s(s[1198]), .clk(clk), .out({wq1_173, wq0_173}));
assign qe[346] = wq0_173;  assign qe[347] = wq1_173;
wire wq0_174, wq1_174;
MSKand_opini2_d2 u_gq_174 (
    .ina({q_d1[174], q_d0[174]}), .inb({nzr1, nzr0}),
    .rnd(r[1199]), .s(s[1199]), .clk(clk), .out({wq1_174, wq0_174}));
assign qe[348] = wq0_174;  assign qe[349] = wq1_174;
wire wq0_175, wq1_175;
MSKand_opini2_d2 u_gq_175 (
    .ina({q_d1[175], q_d0[175]}), .inb({nzr1, nzr0}),
    .rnd(r[1200]), .s(s[1200]), .clk(clk), .out({wq1_175, wq0_175}));
assign qe[350] = wq0_175;  assign qe[351] = wq1_175;
wire wq0_176, wq1_176;
MSKand_opini2_d2 u_gq_176 (
    .ina({q_d1[176], q_d0[176]}), .inb({nzr1, nzr0}),
    .rnd(r[1201]), .s(s[1201]), .clk(clk), .out({wq1_176, wq0_176}));
assign qe[352] = wq0_176;  assign qe[353] = wq1_176;
wire wq0_177, wq1_177;
MSKand_opini2_d2 u_gq_177 (
    .ina({q_d1[177], q_d0[177]}), .inb({nzr1, nzr0}),
    .rnd(r[1202]), .s(s[1202]), .clk(clk), .out({wq1_177, wq0_177}));
assign qe[354] = wq0_177;  assign qe[355] = wq1_177;
wire wq0_178, wq1_178;
MSKand_opini2_d2 u_gq_178 (
    .ina({q_d1[178], q_d0[178]}), .inb({nzr1, nzr0}),
    .rnd(r[1203]), .s(s[1203]), .clk(clk), .out({wq1_178, wq0_178}));
assign qe[356] = wq0_178;  assign qe[357] = wq1_178;
wire wq0_179, wq1_179;
MSKand_opini2_d2 u_gq_179 (
    .ina({q_d1[179], q_d0[179]}), .inb({nzr1, nzr0}),
    .rnd(r[1204]), .s(s[1204]), .clk(clk), .out({wq1_179, wq0_179}));
assign qe[358] = wq0_179;  assign qe[359] = wq1_179;
wire wq0_180, wq1_180;
MSKand_opini2_d2 u_gq_180 (
    .ina({q_d1[180], q_d0[180]}), .inb({nzr1, nzr0}),
    .rnd(r[1205]), .s(s[1205]), .clk(clk), .out({wq1_180, wq0_180}));
assign qe[360] = wq0_180;  assign qe[361] = wq1_180;
wire wq0_181, wq1_181;
MSKand_opini2_d2 u_gq_181 (
    .ina({q_d1[181], q_d0[181]}), .inb({nzr1, nzr0}),
    .rnd(r[1206]), .s(s[1206]), .clk(clk), .out({wq1_181, wq0_181}));
assign qe[362] = wq0_181;  assign qe[363] = wq1_181;
wire wq0_182, wq1_182;
MSKand_opini2_d2 u_gq_182 (
    .ina({q_d1[182], q_d0[182]}), .inb({nzr1, nzr0}),
    .rnd(r[1207]), .s(s[1207]), .clk(clk), .out({wq1_182, wq0_182}));
assign qe[364] = wq0_182;  assign qe[365] = wq1_182;
wire wq0_183, wq1_183;
MSKand_opini2_d2 u_gq_183 (
    .ina({q_d1[183], q_d0[183]}), .inb({nzr1, nzr0}),
    .rnd(r[1208]), .s(s[1208]), .clk(clk), .out({wq1_183, wq0_183}));
assign qe[366] = wq0_183;  assign qe[367] = wq1_183;
wire wq0_184, wq1_184;
MSKand_opini2_d2 u_gq_184 (
    .ina({q_d1[184], q_d0[184]}), .inb({nzr1, nzr0}),
    .rnd(r[1209]), .s(s[1209]), .clk(clk), .out({wq1_184, wq0_184}));
assign qe[368] = wq0_184;  assign qe[369] = wq1_184;
wire wq0_185, wq1_185;
MSKand_opini2_d2 u_gq_185 (
    .ina({q_d1[185], q_d0[185]}), .inb({nzr1, nzr0}),
    .rnd(r[1210]), .s(s[1210]), .clk(clk), .out({wq1_185, wq0_185}));
assign qe[370] = wq0_185;  assign qe[371] = wq1_185;
wire wq0_186, wq1_186;
MSKand_opini2_d2 u_gq_186 (
    .ina({q_d1[186], q_d0[186]}), .inb({nzr1, nzr0}),
    .rnd(r[1211]), .s(s[1211]), .clk(clk), .out({wq1_186, wq0_186}));
assign qe[372] = wq0_186;  assign qe[373] = wq1_186;
wire wq0_187, wq1_187;
MSKand_opini2_d2 u_gq_187 (
    .ina({q_d1[187], q_d0[187]}), .inb({nzr1, nzr0}),
    .rnd(r[1212]), .s(s[1212]), .clk(clk), .out({wq1_187, wq0_187}));
assign qe[374] = wq0_187;  assign qe[375] = wq1_187;
wire wq0_188, wq1_188;
MSKand_opini2_d2 u_gq_188 (
    .ina({q_d1[188], q_d0[188]}), .inb({nzr1, nzr0}),
    .rnd(r[1213]), .s(s[1213]), .clk(clk), .out({wq1_188, wq0_188}));
assign qe[376] = wq0_188;  assign qe[377] = wq1_188;
wire wq0_189, wq1_189;
MSKand_opini2_d2 u_gq_189 (
    .ina({q_d1[189], q_d0[189]}), .inb({nzr1, nzr0}),
    .rnd(r[1214]), .s(s[1214]), .clk(clk), .out({wq1_189, wq0_189}));
assign qe[378] = wq0_189;  assign qe[379] = wq1_189;
wire wq0_190, wq1_190;
MSKand_opini2_d2 u_gq_190 (
    .ina({q_d1[190], q_d0[190]}), .inb({nzr1, nzr0}),
    .rnd(r[1215]), .s(s[1215]), .clk(clk), .out({wq1_190, wq0_190}));
assign qe[380] = wq0_190;  assign qe[381] = wq1_190;
wire wq0_191, wq1_191;
MSKand_opini2_d2 u_gq_191 (
    .ina({q_d1[191], q_d0[191]}), .inb({nzr1, nzr0}),
    .rnd(r[1216]), .s(s[1216]), .clk(clk), .out({wq1_191, wq0_191}));
assign qe[382] = wq0_191;  assign qe[383] = wq1_191;
wire wq0_192, wq1_192;
MSKand_opini2_d2 u_gq_192 (
    .ina({q_d1[192], q_d0[192]}), .inb({nzr1, nzr0}),
    .rnd(r[1217]), .s(s[1217]), .clk(clk), .out({wq1_192, wq0_192}));
assign qe[384] = wq0_192;  assign qe[385] = wq1_192;
wire wq0_193, wq1_193;
MSKand_opini2_d2 u_gq_193 (
    .ina({q_d1[193], q_d0[193]}), .inb({nzr1, nzr0}),
    .rnd(r[1218]), .s(s[1218]), .clk(clk), .out({wq1_193, wq0_193}));
assign qe[386] = wq0_193;  assign qe[387] = wq1_193;
wire wq0_194, wq1_194;
MSKand_opini2_d2 u_gq_194 (
    .ina({q_d1[194], q_d0[194]}), .inb({nzr1, nzr0}),
    .rnd(r[1219]), .s(s[1219]), .clk(clk), .out({wq1_194, wq0_194}));
assign qe[388] = wq0_194;  assign qe[389] = wq1_194;
wire wq0_195, wq1_195;
MSKand_opini2_d2 u_gq_195 (
    .ina({q_d1[195], q_d0[195]}), .inb({nzr1, nzr0}),
    .rnd(r[1220]), .s(s[1220]), .clk(clk), .out({wq1_195, wq0_195}));
assign qe[390] = wq0_195;  assign qe[391] = wq1_195;
wire wq0_196, wq1_196;
MSKand_opini2_d2 u_gq_196 (
    .ina({q_d1[196], q_d0[196]}), .inb({nzr1, nzr0}),
    .rnd(r[1221]), .s(s[1221]), .clk(clk), .out({wq1_196, wq0_196}));
assign qe[392] = wq0_196;  assign qe[393] = wq1_196;
wire wq0_197, wq1_197;
MSKand_opini2_d2 u_gq_197 (
    .ina({q_d1[197], q_d0[197]}), .inb({nzr1, nzr0}),
    .rnd(r[1222]), .s(s[1222]), .clk(clk), .out({wq1_197, wq0_197}));
assign qe[394] = wq0_197;  assign qe[395] = wq1_197;
wire wq0_198, wq1_198;
MSKand_opini2_d2 u_gq_198 (
    .ina({q_d1[198], q_d0[198]}), .inb({nzr1, nzr0}),
    .rnd(r[1223]), .s(s[1223]), .clk(clk), .out({wq1_198, wq0_198}));
assign qe[396] = wq0_198;  assign qe[397] = wq1_198;
wire wq0_199, wq1_199;
MSKand_opini2_d2 u_gq_199 (
    .ina({q_d1[199], q_d0[199]}), .inb({nzr1, nzr0}),
    .rnd(r[1224]), .s(s[1224]), .clk(clk), .out({wq1_199, wq0_199}));
assign qe[398] = wq0_199;  assign qe[399] = wq1_199;
wire wq0_200, wq1_200;
MSKand_opini2_d2 u_gq_200 (
    .ina({q_d1[200], q_d0[200]}), .inb({nzr1, nzr0}),
    .rnd(r[1225]), .s(s[1225]), .clk(clk), .out({wq1_200, wq0_200}));
assign qe[400] = wq0_200;  assign qe[401] = wq1_200;
wire wq0_201, wq1_201;
MSKand_opini2_d2 u_gq_201 (
    .ina({q_d1[201], q_d0[201]}), .inb({nzr1, nzr0}),
    .rnd(r[1226]), .s(s[1226]), .clk(clk), .out({wq1_201, wq0_201}));
assign qe[402] = wq0_201;  assign qe[403] = wq1_201;
wire wq0_202, wq1_202;
MSKand_opini2_d2 u_gq_202 (
    .ina({q_d1[202], q_d0[202]}), .inb({nzr1, nzr0}),
    .rnd(r[1227]), .s(s[1227]), .clk(clk), .out({wq1_202, wq0_202}));
assign qe[404] = wq0_202;  assign qe[405] = wq1_202;
wire wq0_203, wq1_203;
MSKand_opini2_d2 u_gq_203 (
    .ina({q_d1[203], q_d0[203]}), .inb({nzr1, nzr0}),
    .rnd(r[1228]), .s(s[1228]), .clk(clk), .out({wq1_203, wq0_203}));
assign qe[406] = wq0_203;  assign qe[407] = wq1_203;
wire wq0_204, wq1_204;
MSKand_opini2_d2 u_gq_204 (
    .ina({q_d1[204], q_d0[204]}), .inb({nzr1, nzr0}),
    .rnd(r[1229]), .s(s[1229]), .clk(clk), .out({wq1_204, wq0_204}));
assign qe[408] = wq0_204;  assign qe[409] = wq1_204;
wire wq0_205, wq1_205;
MSKand_opini2_d2 u_gq_205 (
    .ina({q_d1[205], q_d0[205]}), .inb({nzr1, nzr0}),
    .rnd(r[1230]), .s(s[1230]), .clk(clk), .out({wq1_205, wq0_205}));
assign qe[410] = wq0_205;  assign qe[411] = wq1_205;
wire wq0_206, wq1_206;
MSKand_opini2_d2 u_gq_206 (
    .ina({q_d1[206], q_d0[206]}), .inb({nzr1, nzr0}),
    .rnd(r[1231]), .s(s[1231]), .clk(clk), .out({wq1_206, wq0_206}));
assign qe[412] = wq0_206;  assign qe[413] = wq1_206;
wire wq0_207, wq1_207;
MSKand_opini2_d2 u_gq_207 (
    .ina({q_d1[207], q_d0[207]}), .inb({nzr1, nzr0}),
    .rnd(r[1232]), .s(s[1232]), .clk(clk), .out({wq1_207, wq0_207}));
assign qe[414] = wq0_207;  assign qe[415] = wq1_207;
wire wq0_208, wq1_208;
MSKand_opini2_d2 u_gq_208 (
    .ina({q_d1[208], q_d0[208]}), .inb({nzr1, nzr0}),
    .rnd(r[1233]), .s(s[1233]), .clk(clk), .out({wq1_208, wq0_208}));
assign qe[416] = wq0_208;  assign qe[417] = wq1_208;
wire wq0_209, wq1_209;
MSKand_opini2_d2 u_gq_209 (
    .ina({q_d1[209], q_d0[209]}), .inb({nzr1, nzr0}),
    .rnd(r[1234]), .s(s[1234]), .clk(clk), .out({wq1_209, wq0_209}));
assign qe[418] = wq0_209;  assign qe[419] = wq1_209;
wire wq0_210, wq1_210;
MSKand_opini2_d2 u_gq_210 (
    .ina({q_d1[210], q_d0[210]}), .inb({nzr1, nzr0}),
    .rnd(r[1235]), .s(s[1235]), .clk(clk), .out({wq1_210, wq0_210}));
assign qe[420] = wq0_210;  assign qe[421] = wq1_210;
wire wq0_211, wq1_211;
MSKand_opini2_d2 u_gq_211 (
    .ina({q_d1[211], q_d0[211]}), .inb({nzr1, nzr0}),
    .rnd(r[1236]), .s(s[1236]), .clk(clk), .out({wq1_211, wq0_211}));
assign qe[422] = wq0_211;  assign qe[423] = wq1_211;
wire wq0_212, wq1_212;
MSKand_opini2_d2 u_gq_212 (
    .ina({q_d1[212], q_d0[212]}), .inb({nzr1, nzr0}),
    .rnd(r[1237]), .s(s[1237]), .clk(clk), .out({wq1_212, wq0_212}));
assign qe[424] = wq0_212;  assign qe[425] = wq1_212;
wire wq0_213, wq1_213;
MSKand_opini2_d2 u_gq_213 (
    .ina({q_d1[213], q_d0[213]}), .inb({nzr1, nzr0}),
    .rnd(r[1238]), .s(s[1238]), .clk(clk), .out({wq1_213, wq0_213}));
assign qe[426] = wq0_213;  assign qe[427] = wq1_213;
wire wq0_214, wq1_214;
MSKand_opini2_d2 u_gq_214 (
    .ina({q_d1[214], q_d0[214]}), .inb({nzr1, nzr0}),
    .rnd(r[1239]), .s(s[1239]), .clk(clk), .out({wq1_214, wq0_214}));
assign qe[428] = wq0_214;  assign qe[429] = wq1_214;
wire wq0_215, wq1_215;
MSKand_opini2_d2 u_gq_215 (
    .ina({q_d1[215], q_d0[215]}), .inb({nzr1, nzr0}),
    .rnd(r[1240]), .s(s[1240]), .clk(clk), .out({wq1_215, wq0_215}));
assign qe[430] = wq0_215;  assign qe[431] = wq1_215;
wire wq0_216, wq1_216;
MSKand_opini2_d2 u_gq_216 (
    .ina({q_d1[216], q_d0[216]}), .inb({nzr1, nzr0}),
    .rnd(r[1241]), .s(s[1241]), .clk(clk), .out({wq1_216, wq0_216}));
assign qe[432] = wq0_216;  assign qe[433] = wq1_216;
wire wq0_217, wq1_217;
MSKand_opini2_d2 u_gq_217 (
    .ina({q_d1[217], q_d0[217]}), .inb({nzr1, nzr0}),
    .rnd(r[1242]), .s(s[1242]), .clk(clk), .out({wq1_217, wq0_217}));
assign qe[434] = wq0_217;  assign qe[435] = wq1_217;
wire wq0_218, wq1_218;
MSKand_opini2_d2 u_gq_218 (
    .ina({q_d1[218], q_d0[218]}), .inb({nzr1, nzr0}),
    .rnd(r[1243]), .s(s[1243]), .clk(clk), .out({wq1_218, wq0_218}));
assign qe[436] = wq0_218;  assign qe[437] = wq1_218;
wire wq0_219, wq1_219;
MSKand_opini2_d2 u_gq_219 (
    .ina({q_d1[219], q_d0[219]}), .inb({nzr1, nzr0}),
    .rnd(r[1244]), .s(s[1244]), .clk(clk), .out({wq1_219, wq0_219}));
assign qe[438] = wq0_219;  assign qe[439] = wq1_219;
wire wq0_220, wq1_220;
MSKand_opini2_d2 u_gq_220 (
    .ina({q_d1[220], q_d0[220]}), .inb({nzr1, nzr0}),
    .rnd(r[1245]), .s(s[1245]), .clk(clk), .out({wq1_220, wq0_220}));
assign qe[440] = wq0_220;  assign qe[441] = wq1_220;
wire wq0_221, wq1_221;
MSKand_opini2_d2 u_gq_221 (
    .ina({q_d1[221], q_d0[221]}), .inb({nzr1, nzr0}),
    .rnd(r[1246]), .s(s[1246]), .clk(clk), .out({wq1_221, wq0_221}));
assign qe[442] = wq0_221;  assign qe[443] = wq1_221;
wire wq0_222, wq1_222;
MSKand_opini2_d2 u_gq_222 (
    .ina({q_d1[222], q_d0[222]}), .inb({nzr1, nzr0}),
    .rnd(r[1247]), .s(s[1247]), .clk(clk), .out({wq1_222, wq0_222}));
assign qe[444] = wq0_222;  assign qe[445] = wq1_222;
wire wq0_223, wq1_223;
MSKand_opini2_d2 u_gq_223 (
    .ina({q_d1[223], q_d0[223]}), .inb({nzr1, nzr0}),
    .rnd(r[1248]), .s(s[1248]), .clk(clk), .out({wq1_223, wq0_223}));
assign qe[446] = wq0_223;  assign qe[447] = wq1_223;
wire wq0_224, wq1_224;
MSKand_opini2_d2 u_gq_224 (
    .ina({q_d1[224], q_d0[224]}), .inb({nzr1, nzr0}),
    .rnd(r[1249]), .s(s[1249]), .clk(clk), .out({wq1_224, wq0_224}));
assign qe[448] = wq0_224;  assign qe[449] = wq1_224;
wire wq0_225, wq1_225;
MSKand_opini2_d2 u_gq_225 (
    .ina({q_d1[225], q_d0[225]}), .inb({nzr1, nzr0}),
    .rnd(r[1250]), .s(s[1250]), .clk(clk), .out({wq1_225, wq0_225}));
assign qe[450] = wq0_225;  assign qe[451] = wq1_225;
wire wq0_226, wq1_226;
MSKand_opini2_d2 u_gq_226 (
    .ina({q_d1[226], q_d0[226]}), .inb({nzr1, nzr0}),
    .rnd(r[1251]), .s(s[1251]), .clk(clk), .out({wq1_226, wq0_226}));
assign qe[452] = wq0_226;  assign qe[453] = wq1_226;
wire wq0_227, wq1_227;
MSKand_opini2_d2 u_gq_227 (
    .ina({q_d1[227], q_d0[227]}), .inb({nzr1, nzr0}),
    .rnd(r[1252]), .s(s[1252]), .clk(clk), .out({wq1_227, wq0_227}));
assign qe[454] = wq0_227;  assign qe[455] = wq1_227;
wire wq0_228, wq1_228;
MSKand_opini2_d2 u_gq_228 (
    .ina({q_d1[228], q_d0[228]}), .inb({nzr1, nzr0}),
    .rnd(r[1253]), .s(s[1253]), .clk(clk), .out({wq1_228, wq0_228}));
assign qe[456] = wq0_228;  assign qe[457] = wq1_228;
wire wq0_229, wq1_229;
MSKand_opini2_d2 u_gq_229 (
    .ina({q_d1[229], q_d0[229]}), .inb({nzr1, nzr0}),
    .rnd(r[1254]), .s(s[1254]), .clk(clk), .out({wq1_229, wq0_229}));
assign qe[458] = wq0_229;  assign qe[459] = wq1_229;
wire wq0_230, wq1_230;
MSKand_opini2_d2 u_gq_230 (
    .ina({q_d1[230], q_d0[230]}), .inb({nzr1, nzr0}),
    .rnd(r[1255]), .s(s[1255]), .clk(clk), .out({wq1_230, wq0_230}));
assign qe[460] = wq0_230;  assign qe[461] = wq1_230;
wire wq0_231, wq1_231;
MSKand_opini2_d2 u_gq_231 (
    .ina({q_d1[231], q_d0[231]}), .inb({nzr1, nzr0}),
    .rnd(r[1256]), .s(s[1256]), .clk(clk), .out({wq1_231, wq0_231}));
assign qe[462] = wq0_231;  assign qe[463] = wq1_231;
wire wq0_232, wq1_232;
MSKand_opini2_d2 u_gq_232 (
    .ina({q_d1[232], q_d0[232]}), .inb({nzr1, nzr0}),
    .rnd(r[1257]), .s(s[1257]), .clk(clk), .out({wq1_232, wq0_232}));
assign qe[464] = wq0_232;  assign qe[465] = wq1_232;
wire wq0_233, wq1_233;
MSKand_opini2_d2 u_gq_233 (
    .ina({q_d1[233], q_d0[233]}), .inb({nzr1, nzr0}),
    .rnd(r[1258]), .s(s[1258]), .clk(clk), .out({wq1_233, wq0_233}));
assign qe[466] = wq0_233;  assign qe[467] = wq1_233;
wire wq0_234, wq1_234;
MSKand_opini2_d2 u_gq_234 (
    .ina({q_d1[234], q_d0[234]}), .inb({nzr1, nzr0}),
    .rnd(r[1259]), .s(s[1259]), .clk(clk), .out({wq1_234, wq0_234}));
assign qe[468] = wq0_234;  assign qe[469] = wq1_234;
wire wq0_235, wq1_235;
MSKand_opini2_d2 u_gq_235 (
    .ina({q_d1[235], q_d0[235]}), .inb({nzr1, nzr0}),
    .rnd(r[1260]), .s(s[1260]), .clk(clk), .out({wq1_235, wq0_235}));
assign qe[470] = wq0_235;  assign qe[471] = wq1_235;
wire wq0_236, wq1_236;
MSKand_opini2_d2 u_gq_236 (
    .ina({q_d1[236], q_d0[236]}), .inb({nzr1, nzr0}),
    .rnd(r[1261]), .s(s[1261]), .clk(clk), .out({wq1_236, wq0_236}));
assign qe[472] = wq0_236;  assign qe[473] = wq1_236;
wire wq0_237, wq1_237;
MSKand_opini2_d2 u_gq_237 (
    .ina({q_d1[237], q_d0[237]}), .inb({nzr1, nzr0}),
    .rnd(r[1262]), .s(s[1262]), .clk(clk), .out({wq1_237, wq0_237}));
assign qe[474] = wq0_237;  assign qe[475] = wq1_237;
wire wq0_238, wq1_238;
MSKand_opini2_d2 u_gq_238 (
    .ina({q_d1[238], q_d0[238]}), .inb({nzr1, nzr0}),
    .rnd(r[1263]), .s(s[1263]), .clk(clk), .out({wq1_238, wq0_238}));
assign qe[476] = wq0_238;  assign qe[477] = wq1_238;
wire wq0_239, wq1_239;
MSKand_opini2_d2 u_gq_239 (
    .ina({q_d1[239], q_d0[239]}), .inb({nzr1, nzr0}),
    .rnd(r[1264]), .s(s[1264]), .clk(clk), .out({wq1_239, wq0_239}));
assign qe[478] = wq0_239;  assign qe[479] = wq1_239;
wire wq0_240, wq1_240;
MSKand_opini2_d2 u_gq_240 (
    .ina({q_d1[240], q_d0[240]}), .inb({nzr1, nzr0}),
    .rnd(r[1265]), .s(s[1265]), .clk(clk), .out({wq1_240, wq0_240}));
assign qe[480] = wq0_240;  assign qe[481] = wq1_240;
wire wq0_241, wq1_241;
MSKand_opini2_d2 u_gq_241 (
    .ina({q_d1[241], q_d0[241]}), .inb({nzr1, nzr0}),
    .rnd(r[1266]), .s(s[1266]), .clk(clk), .out({wq1_241, wq0_241}));
assign qe[482] = wq0_241;  assign qe[483] = wq1_241;
wire wq0_242, wq1_242;
MSKand_opini2_d2 u_gq_242 (
    .ina({q_d1[242], q_d0[242]}), .inb({nzr1, nzr0}),
    .rnd(r[1267]), .s(s[1267]), .clk(clk), .out({wq1_242, wq0_242}));
assign qe[484] = wq0_242;  assign qe[485] = wq1_242;
wire wq0_243, wq1_243;
MSKand_opini2_d2 u_gq_243 (
    .ina({q_d1[243], q_d0[243]}), .inb({nzr1, nzr0}),
    .rnd(r[1268]), .s(s[1268]), .clk(clk), .out({wq1_243, wq0_243}));
assign qe[486] = wq0_243;  assign qe[487] = wq1_243;
wire wq0_244, wq1_244;
MSKand_opini2_d2 u_gq_244 (
    .ina({q_d1[244], q_d0[244]}), .inb({nzr1, nzr0}),
    .rnd(r[1269]), .s(s[1269]), .clk(clk), .out({wq1_244, wq0_244}));
assign qe[488] = wq0_244;  assign qe[489] = wq1_244;
wire wq0_245, wq1_245;
MSKand_opini2_d2 u_gq_245 (
    .ina({q_d1[245], q_d0[245]}), .inb({nzr1, nzr0}),
    .rnd(r[1270]), .s(s[1270]), .clk(clk), .out({wq1_245, wq0_245}));
assign qe[490] = wq0_245;  assign qe[491] = wq1_245;
wire wq0_246, wq1_246;
MSKand_opini2_d2 u_gq_246 (
    .ina({q_d1[246], q_d0[246]}), .inb({nzr1, nzr0}),
    .rnd(r[1271]), .s(s[1271]), .clk(clk), .out({wq1_246, wq0_246}));
assign qe[492] = wq0_246;  assign qe[493] = wq1_246;
wire wq0_247, wq1_247;
MSKand_opini2_d2 u_gq_247 (
    .ina({q_d1[247], q_d0[247]}), .inb({nzr1, nzr0}),
    .rnd(r[1272]), .s(s[1272]), .clk(clk), .out({wq1_247, wq0_247}));
assign qe[494] = wq0_247;  assign qe[495] = wq1_247;
wire wq0_248, wq1_248;
MSKand_opini2_d2 u_gq_248 (
    .ina({q_d1[248], q_d0[248]}), .inb({nzr1, nzr0}),
    .rnd(r[1273]), .s(s[1273]), .clk(clk), .out({wq1_248, wq0_248}));
assign qe[496] = wq0_248;  assign qe[497] = wq1_248;
wire wq0_249, wq1_249;
MSKand_opini2_d2 u_gq_249 (
    .ina({q_d1[249], q_d0[249]}), .inb({nzr1, nzr0}),
    .rnd(r[1274]), .s(s[1274]), .clk(clk), .out({wq1_249, wq0_249}));
assign qe[498] = wq0_249;  assign qe[499] = wq1_249;
wire wq0_250, wq1_250;
MSKand_opini2_d2 u_gq_250 (
    .ina({q_d1[250], q_d0[250]}), .inb({nzr1, nzr0}),
    .rnd(r[1275]), .s(s[1275]), .clk(clk), .out({wq1_250, wq0_250}));
assign qe[500] = wq0_250;  assign qe[501] = wq1_250;
wire wq0_251, wq1_251;
MSKand_opini2_d2 u_gq_251 (
    .ina({q_d1[251], q_d0[251]}), .inb({nzr1, nzr0}),
    .rnd(r[1276]), .s(s[1276]), .clk(clk), .out({wq1_251, wq0_251}));
assign qe[502] = wq0_251;  assign qe[503] = wq1_251;
wire wq0_252, wq1_252;
MSKand_opini2_d2 u_gq_252 (
    .ina({q_d1[252], q_d0[252]}), .inb({nzr1, nzr0}),
    .rnd(r[1277]), .s(s[1277]), .clk(clk), .out({wq1_252, wq0_252}));
assign qe[504] = wq0_252;  assign qe[505] = wq1_252;
wire wq0_253, wq1_253;
MSKand_opini2_d2 u_gq_253 (
    .ina({q_d1[253], q_d0[253]}), .inb({nzr1, nzr0}),
    .rnd(r[1278]), .s(s[1278]), .clk(clk), .out({wq1_253, wq0_253}));
assign qe[506] = wq0_253;  assign qe[507] = wq1_253;
wire wq0_254, wq1_254;
MSKand_opini2_d2 u_gq_254 (
    .ina({q_d1[254], q_d0[254]}), .inb({nzr1, nzr0}),
    .rnd(r[1279]), .s(s[1279]), .clk(clk), .out({wq1_254, wq0_254}));
assign qe[508] = wq0_254;  assign qe[509] = wq1_254;
wire wq0_255, wq1_255;
MSKand_opini2_d2 u_gq_255 (
    .ina({q_d1[255], q_d0[255]}), .inb({nzr1, nzr0}),
    .rnd(r[1280]), .s(s[1280]), .clk(clk), .out({wq1_255, wq0_255}));
assign qe[510] = wq0_255;  assign qe[511] = wq1_255;
wire wr0_0, wr1_0;
MSKand_opini2_d2 u_gr_0 (
    .ina({rm_d1[0], rm_d0[0]}), .inb({nzr1, nzr0}),
    .rnd(r[1281]), .s(s[1281]), .clk(clk), .out({wr1_0, wr0_0}));
assign reme[0] = wr0_0;  assign reme[1] = wr1_0;
wire wr0_1, wr1_1;
MSKand_opini2_d2 u_gr_1 (
    .ina({rm_d1[1], rm_d0[1]}), .inb({nzr1, nzr0}),
    .rnd(r[1282]), .s(s[1282]), .clk(clk), .out({wr1_1, wr0_1}));
assign reme[2] = wr0_1;  assign reme[3] = wr1_1;
wire wr0_2, wr1_2;
MSKand_opini2_d2 u_gr_2 (
    .ina({rm_d1[2], rm_d0[2]}), .inb({nzr1, nzr0}),
    .rnd(r[1283]), .s(s[1283]), .clk(clk), .out({wr1_2, wr0_2}));
assign reme[4] = wr0_2;  assign reme[5] = wr1_2;
wire wr0_3, wr1_3;
MSKand_opini2_d2 u_gr_3 (
    .ina({rm_d1[3], rm_d0[3]}), .inb({nzr1, nzr0}),
    .rnd(r[1284]), .s(s[1284]), .clk(clk), .out({wr1_3, wr0_3}));
assign reme[6] = wr0_3;  assign reme[7] = wr1_3;
wire wr0_4, wr1_4;
MSKand_opini2_d2 u_gr_4 (
    .ina({rm_d1[4], rm_d0[4]}), .inb({nzr1, nzr0}),
    .rnd(r[1285]), .s(s[1285]), .clk(clk), .out({wr1_4, wr0_4}));
assign reme[8] = wr0_4;  assign reme[9] = wr1_4;
wire wr0_5, wr1_5;
MSKand_opini2_d2 u_gr_5 (
    .ina({rm_d1[5], rm_d0[5]}), .inb({nzr1, nzr0}),
    .rnd(r[1286]), .s(s[1286]), .clk(clk), .out({wr1_5, wr0_5}));
assign reme[10] = wr0_5;  assign reme[11] = wr1_5;
wire wr0_6, wr1_6;
MSKand_opini2_d2 u_gr_6 (
    .ina({rm_d1[6], rm_d0[6]}), .inb({nzr1, nzr0}),
    .rnd(r[1287]), .s(s[1287]), .clk(clk), .out({wr1_6, wr0_6}));
assign reme[12] = wr0_6;  assign reme[13] = wr1_6;
wire wr0_7, wr1_7;
MSKand_opini2_d2 u_gr_7 (
    .ina({rm_d1[7], rm_d0[7]}), .inb({nzr1, nzr0}),
    .rnd(r[1288]), .s(s[1288]), .clk(clk), .out({wr1_7, wr0_7}));
assign reme[14] = wr0_7;  assign reme[15] = wr1_7;
wire wr0_8, wr1_8;
MSKand_opini2_d2 u_gr_8 (
    .ina({rm_d1[8], rm_d0[8]}), .inb({nzr1, nzr0}),
    .rnd(r[1289]), .s(s[1289]), .clk(clk), .out({wr1_8, wr0_8}));
assign reme[16] = wr0_8;  assign reme[17] = wr1_8;
wire wr0_9, wr1_9;
MSKand_opini2_d2 u_gr_9 (
    .ina({rm_d1[9], rm_d0[9]}), .inb({nzr1, nzr0}),
    .rnd(r[1290]), .s(s[1290]), .clk(clk), .out({wr1_9, wr0_9}));
assign reme[18] = wr0_9;  assign reme[19] = wr1_9;
wire wr0_10, wr1_10;
MSKand_opini2_d2 u_gr_10 (
    .ina({rm_d1[10], rm_d0[10]}), .inb({nzr1, nzr0}),
    .rnd(r[1291]), .s(s[1291]), .clk(clk), .out({wr1_10, wr0_10}));
assign reme[20] = wr0_10;  assign reme[21] = wr1_10;
wire wr0_11, wr1_11;
MSKand_opini2_d2 u_gr_11 (
    .ina({rm_d1[11], rm_d0[11]}), .inb({nzr1, nzr0}),
    .rnd(r[1292]), .s(s[1292]), .clk(clk), .out({wr1_11, wr0_11}));
assign reme[22] = wr0_11;  assign reme[23] = wr1_11;
wire wr0_12, wr1_12;
MSKand_opini2_d2 u_gr_12 (
    .ina({rm_d1[12], rm_d0[12]}), .inb({nzr1, nzr0}),
    .rnd(r[1293]), .s(s[1293]), .clk(clk), .out({wr1_12, wr0_12}));
assign reme[24] = wr0_12;  assign reme[25] = wr1_12;
wire wr0_13, wr1_13;
MSKand_opini2_d2 u_gr_13 (
    .ina({rm_d1[13], rm_d0[13]}), .inb({nzr1, nzr0}),
    .rnd(r[1294]), .s(s[1294]), .clk(clk), .out({wr1_13, wr0_13}));
assign reme[26] = wr0_13;  assign reme[27] = wr1_13;
wire wr0_14, wr1_14;
MSKand_opini2_d2 u_gr_14 (
    .ina({rm_d1[14], rm_d0[14]}), .inb({nzr1, nzr0}),
    .rnd(r[1295]), .s(s[1295]), .clk(clk), .out({wr1_14, wr0_14}));
assign reme[28] = wr0_14;  assign reme[29] = wr1_14;
wire wr0_15, wr1_15;
MSKand_opini2_d2 u_gr_15 (
    .ina({rm_d1[15], rm_d0[15]}), .inb({nzr1, nzr0}),
    .rnd(r[1296]), .s(s[1296]), .clk(clk), .out({wr1_15, wr0_15}));
assign reme[30] = wr0_15;  assign reme[31] = wr1_15;
wire wr0_16, wr1_16;
MSKand_opini2_d2 u_gr_16 (
    .ina({rm_d1[16], rm_d0[16]}), .inb({nzr1, nzr0}),
    .rnd(r[1297]), .s(s[1297]), .clk(clk), .out({wr1_16, wr0_16}));
assign reme[32] = wr0_16;  assign reme[33] = wr1_16;
wire wr0_17, wr1_17;
MSKand_opini2_d2 u_gr_17 (
    .ina({rm_d1[17], rm_d0[17]}), .inb({nzr1, nzr0}),
    .rnd(r[1298]), .s(s[1298]), .clk(clk), .out({wr1_17, wr0_17}));
assign reme[34] = wr0_17;  assign reme[35] = wr1_17;
wire wr0_18, wr1_18;
MSKand_opini2_d2 u_gr_18 (
    .ina({rm_d1[18], rm_d0[18]}), .inb({nzr1, nzr0}),
    .rnd(r[1299]), .s(s[1299]), .clk(clk), .out({wr1_18, wr0_18}));
assign reme[36] = wr0_18;  assign reme[37] = wr1_18;
wire wr0_19, wr1_19;
MSKand_opini2_d2 u_gr_19 (
    .ina({rm_d1[19], rm_d0[19]}), .inb({nzr1, nzr0}),
    .rnd(r[1300]), .s(s[1300]), .clk(clk), .out({wr1_19, wr0_19}));
assign reme[38] = wr0_19;  assign reme[39] = wr1_19;
wire wr0_20, wr1_20;
MSKand_opini2_d2 u_gr_20 (
    .ina({rm_d1[20], rm_d0[20]}), .inb({nzr1, nzr0}),
    .rnd(r[1301]), .s(s[1301]), .clk(clk), .out({wr1_20, wr0_20}));
assign reme[40] = wr0_20;  assign reme[41] = wr1_20;
wire wr0_21, wr1_21;
MSKand_opini2_d2 u_gr_21 (
    .ina({rm_d1[21], rm_d0[21]}), .inb({nzr1, nzr0}),
    .rnd(r[1302]), .s(s[1302]), .clk(clk), .out({wr1_21, wr0_21}));
assign reme[42] = wr0_21;  assign reme[43] = wr1_21;
wire wr0_22, wr1_22;
MSKand_opini2_d2 u_gr_22 (
    .ina({rm_d1[22], rm_d0[22]}), .inb({nzr1, nzr0}),
    .rnd(r[1303]), .s(s[1303]), .clk(clk), .out({wr1_22, wr0_22}));
assign reme[44] = wr0_22;  assign reme[45] = wr1_22;
wire wr0_23, wr1_23;
MSKand_opini2_d2 u_gr_23 (
    .ina({rm_d1[23], rm_d0[23]}), .inb({nzr1, nzr0}),
    .rnd(r[1304]), .s(s[1304]), .clk(clk), .out({wr1_23, wr0_23}));
assign reme[46] = wr0_23;  assign reme[47] = wr1_23;
wire wr0_24, wr1_24;
MSKand_opini2_d2 u_gr_24 (
    .ina({rm_d1[24], rm_d0[24]}), .inb({nzr1, nzr0}),
    .rnd(r[1305]), .s(s[1305]), .clk(clk), .out({wr1_24, wr0_24}));
assign reme[48] = wr0_24;  assign reme[49] = wr1_24;
wire wr0_25, wr1_25;
MSKand_opini2_d2 u_gr_25 (
    .ina({rm_d1[25], rm_d0[25]}), .inb({nzr1, nzr0}),
    .rnd(r[1306]), .s(s[1306]), .clk(clk), .out({wr1_25, wr0_25}));
assign reme[50] = wr0_25;  assign reme[51] = wr1_25;
wire wr0_26, wr1_26;
MSKand_opini2_d2 u_gr_26 (
    .ina({rm_d1[26], rm_d0[26]}), .inb({nzr1, nzr0}),
    .rnd(r[1307]), .s(s[1307]), .clk(clk), .out({wr1_26, wr0_26}));
assign reme[52] = wr0_26;  assign reme[53] = wr1_26;
wire wr0_27, wr1_27;
MSKand_opini2_d2 u_gr_27 (
    .ina({rm_d1[27], rm_d0[27]}), .inb({nzr1, nzr0}),
    .rnd(r[1308]), .s(s[1308]), .clk(clk), .out({wr1_27, wr0_27}));
assign reme[54] = wr0_27;  assign reme[55] = wr1_27;
wire wr0_28, wr1_28;
MSKand_opini2_d2 u_gr_28 (
    .ina({rm_d1[28], rm_d0[28]}), .inb({nzr1, nzr0}),
    .rnd(r[1309]), .s(s[1309]), .clk(clk), .out({wr1_28, wr0_28}));
assign reme[56] = wr0_28;  assign reme[57] = wr1_28;
wire wr0_29, wr1_29;
MSKand_opini2_d2 u_gr_29 (
    .ina({rm_d1[29], rm_d0[29]}), .inb({nzr1, nzr0}),
    .rnd(r[1310]), .s(s[1310]), .clk(clk), .out({wr1_29, wr0_29}));
assign reme[58] = wr0_29;  assign reme[59] = wr1_29;
wire wr0_30, wr1_30;
MSKand_opini2_d2 u_gr_30 (
    .ina({rm_d1[30], rm_d0[30]}), .inb({nzr1, nzr0}),
    .rnd(r[1311]), .s(s[1311]), .clk(clk), .out({wr1_30, wr0_30}));
assign reme[60] = wr0_30;  assign reme[61] = wr1_30;
wire wr0_31, wr1_31;
MSKand_opini2_d2 u_gr_31 (
    .ina({rm_d1[31], rm_d0[31]}), .inb({nzr1, nzr0}),
    .rnd(r[1312]), .s(s[1312]), .clk(clk), .out({wr1_31, wr0_31}));
assign reme[62] = wr0_31;  assign reme[63] = wr1_31;
wire wr0_32, wr1_32;
MSKand_opini2_d2 u_gr_32 (
    .ina({rm_d1[32], rm_d0[32]}), .inb({nzr1, nzr0}),
    .rnd(r[1313]), .s(s[1313]), .clk(clk), .out({wr1_32, wr0_32}));
assign reme[64] = wr0_32;  assign reme[65] = wr1_32;
wire wr0_33, wr1_33;
MSKand_opini2_d2 u_gr_33 (
    .ina({rm_d1[33], rm_d0[33]}), .inb({nzr1, nzr0}),
    .rnd(r[1314]), .s(s[1314]), .clk(clk), .out({wr1_33, wr0_33}));
assign reme[66] = wr0_33;  assign reme[67] = wr1_33;
wire wr0_34, wr1_34;
MSKand_opini2_d2 u_gr_34 (
    .ina({rm_d1[34], rm_d0[34]}), .inb({nzr1, nzr0}),
    .rnd(r[1315]), .s(s[1315]), .clk(clk), .out({wr1_34, wr0_34}));
assign reme[68] = wr0_34;  assign reme[69] = wr1_34;
wire wr0_35, wr1_35;
MSKand_opini2_d2 u_gr_35 (
    .ina({rm_d1[35], rm_d0[35]}), .inb({nzr1, nzr0}),
    .rnd(r[1316]), .s(s[1316]), .clk(clk), .out({wr1_35, wr0_35}));
assign reme[70] = wr0_35;  assign reme[71] = wr1_35;
wire wr0_36, wr1_36;
MSKand_opini2_d2 u_gr_36 (
    .ina({rm_d1[36], rm_d0[36]}), .inb({nzr1, nzr0}),
    .rnd(r[1317]), .s(s[1317]), .clk(clk), .out({wr1_36, wr0_36}));
assign reme[72] = wr0_36;  assign reme[73] = wr1_36;
wire wr0_37, wr1_37;
MSKand_opini2_d2 u_gr_37 (
    .ina({rm_d1[37], rm_d0[37]}), .inb({nzr1, nzr0}),
    .rnd(r[1318]), .s(s[1318]), .clk(clk), .out({wr1_37, wr0_37}));
assign reme[74] = wr0_37;  assign reme[75] = wr1_37;
wire wr0_38, wr1_38;
MSKand_opini2_d2 u_gr_38 (
    .ina({rm_d1[38], rm_d0[38]}), .inb({nzr1, nzr0}),
    .rnd(r[1319]), .s(s[1319]), .clk(clk), .out({wr1_38, wr0_38}));
assign reme[76] = wr0_38;  assign reme[77] = wr1_38;
wire wr0_39, wr1_39;
MSKand_opini2_d2 u_gr_39 (
    .ina({rm_d1[39], rm_d0[39]}), .inb({nzr1, nzr0}),
    .rnd(r[1320]), .s(s[1320]), .clk(clk), .out({wr1_39, wr0_39}));
assign reme[78] = wr0_39;  assign reme[79] = wr1_39;
wire wr0_40, wr1_40;
MSKand_opini2_d2 u_gr_40 (
    .ina({rm_d1[40], rm_d0[40]}), .inb({nzr1, nzr0}),
    .rnd(r[1321]), .s(s[1321]), .clk(clk), .out({wr1_40, wr0_40}));
assign reme[80] = wr0_40;  assign reme[81] = wr1_40;
wire wr0_41, wr1_41;
MSKand_opini2_d2 u_gr_41 (
    .ina({rm_d1[41], rm_d0[41]}), .inb({nzr1, nzr0}),
    .rnd(r[1322]), .s(s[1322]), .clk(clk), .out({wr1_41, wr0_41}));
assign reme[82] = wr0_41;  assign reme[83] = wr1_41;
wire wr0_42, wr1_42;
MSKand_opini2_d2 u_gr_42 (
    .ina({rm_d1[42], rm_d0[42]}), .inb({nzr1, nzr0}),
    .rnd(r[1323]), .s(s[1323]), .clk(clk), .out({wr1_42, wr0_42}));
assign reme[84] = wr0_42;  assign reme[85] = wr1_42;
wire wr0_43, wr1_43;
MSKand_opini2_d2 u_gr_43 (
    .ina({rm_d1[43], rm_d0[43]}), .inb({nzr1, nzr0}),
    .rnd(r[1324]), .s(s[1324]), .clk(clk), .out({wr1_43, wr0_43}));
assign reme[86] = wr0_43;  assign reme[87] = wr1_43;
wire wr0_44, wr1_44;
MSKand_opini2_d2 u_gr_44 (
    .ina({rm_d1[44], rm_d0[44]}), .inb({nzr1, nzr0}),
    .rnd(r[1325]), .s(s[1325]), .clk(clk), .out({wr1_44, wr0_44}));
assign reme[88] = wr0_44;  assign reme[89] = wr1_44;
wire wr0_45, wr1_45;
MSKand_opini2_d2 u_gr_45 (
    .ina({rm_d1[45], rm_d0[45]}), .inb({nzr1, nzr0}),
    .rnd(r[1326]), .s(s[1326]), .clk(clk), .out({wr1_45, wr0_45}));
assign reme[90] = wr0_45;  assign reme[91] = wr1_45;
wire wr0_46, wr1_46;
MSKand_opini2_d2 u_gr_46 (
    .ina({rm_d1[46], rm_d0[46]}), .inb({nzr1, nzr0}),
    .rnd(r[1327]), .s(s[1327]), .clk(clk), .out({wr1_46, wr0_46}));
assign reme[92] = wr0_46;  assign reme[93] = wr1_46;
wire wr0_47, wr1_47;
MSKand_opini2_d2 u_gr_47 (
    .ina({rm_d1[47], rm_d0[47]}), .inb({nzr1, nzr0}),
    .rnd(r[1328]), .s(s[1328]), .clk(clk), .out({wr1_47, wr0_47}));
assign reme[94] = wr0_47;  assign reme[95] = wr1_47;
wire wr0_48, wr1_48;
MSKand_opini2_d2 u_gr_48 (
    .ina({rm_d1[48], rm_d0[48]}), .inb({nzr1, nzr0}),
    .rnd(r[1329]), .s(s[1329]), .clk(clk), .out({wr1_48, wr0_48}));
assign reme[96] = wr0_48;  assign reme[97] = wr1_48;
wire wr0_49, wr1_49;
MSKand_opini2_d2 u_gr_49 (
    .ina({rm_d1[49], rm_d0[49]}), .inb({nzr1, nzr0}),
    .rnd(r[1330]), .s(s[1330]), .clk(clk), .out({wr1_49, wr0_49}));
assign reme[98] = wr0_49;  assign reme[99] = wr1_49;
wire wr0_50, wr1_50;
MSKand_opini2_d2 u_gr_50 (
    .ina({rm_d1[50], rm_d0[50]}), .inb({nzr1, nzr0}),
    .rnd(r[1331]), .s(s[1331]), .clk(clk), .out({wr1_50, wr0_50}));
assign reme[100] = wr0_50;  assign reme[101] = wr1_50;
wire wr0_51, wr1_51;
MSKand_opini2_d2 u_gr_51 (
    .ina({rm_d1[51], rm_d0[51]}), .inb({nzr1, nzr0}),
    .rnd(r[1332]), .s(s[1332]), .clk(clk), .out({wr1_51, wr0_51}));
assign reme[102] = wr0_51;  assign reme[103] = wr1_51;
wire wr0_52, wr1_52;
MSKand_opini2_d2 u_gr_52 (
    .ina({rm_d1[52], rm_d0[52]}), .inb({nzr1, nzr0}),
    .rnd(r[1333]), .s(s[1333]), .clk(clk), .out({wr1_52, wr0_52}));
assign reme[104] = wr0_52;  assign reme[105] = wr1_52;
wire wr0_53, wr1_53;
MSKand_opini2_d2 u_gr_53 (
    .ina({rm_d1[53], rm_d0[53]}), .inb({nzr1, nzr0}),
    .rnd(r[1334]), .s(s[1334]), .clk(clk), .out({wr1_53, wr0_53}));
assign reme[106] = wr0_53;  assign reme[107] = wr1_53;
wire wr0_54, wr1_54;
MSKand_opini2_d2 u_gr_54 (
    .ina({rm_d1[54], rm_d0[54]}), .inb({nzr1, nzr0}),
    .rnd(r[1335]), .s(s[1335]), .clk(clk), .out({wr1_54, wr0_54}));
assign reme[108] = wr0_54;  assign reme[109] = wr1_54;
wire wr0_55, wr1_55;
MSKand_opini2_d2 u_gr_55 (
    .ina({rm_d1[55], rm_d0[55]}), .inb({nzr1, nzr0}),
    .rnd(r[1336]), .s(s[1336]), .clk(clk), .out({wr1_55, wr0_55}));
assign reme[110] = wr0_55;  assign reme[111] = wr1_55;
wire wr0_56, wr1_56;
MSKand_opini2_d2 u_gr_56 (
    .ina({rm_d1[56], rm_d0[56]}), .inb({nzr1, nzr0}),
    .rnd(r[1337]), .s(s[1337]), .clk(clk), .out({wr1_56, wr0_56}));
assign reme[112] = wr0_56;  assign reme[113] = wr1_56;
wire wr0_57, wr1_57;
MSKand_opini2_d2 u_gr_57 (
    .ina({rm_d1[57], rm_d0[57]}), .inb({nzr1, nzr0}),
    .rnd(r[1338]), .s(s[1338]), .clk(clk), .out({wr1_57, wr0_57}));
assign reme[114] = wr0_57;  assign reme[115] = wr1_57;
wire wr0_58, wr1_58;
MSKand_opini2_d2 u_gr_58 (
    .ina({rm_d1[58], rm_d0[58]}), .inb({nzr1, nzr0}),
    .rnd(r[1339]), .s(s[1339]), .clk(clk), .out({wr1_58, wr0_58}));
assign reme[116] = wr0_58;  assign reme[117] = wr1_58;
wire wr0_59, wr1_59;
MSKand_opini2_d2 u_gr_59 (
    .ina({rm_d1[59], rm_d0[59]}), .inb({nzr1, nzr0}),
    .rnd(r[1340]), .s(s[1340]), .clk(clk), .out({wr1_59, wr0_59}));
assign reme[118] = wr0_59;  assign reme[119] = wr1_59;
wire wr0_60, wr1_60;
MSKand_opini2_d2 u_gr_60 (
    .ina({rm_d1[60], rm_d0[60]}), .inb({nzr1, nzr0}),
    .rnd(r[1341]), .s(s[1341]), .clk(clk), .out({wr1_60, wr0_60}));
assign reme[120] = wr0_60;  assign reme[121] = wr1_60;
wire wr0_61, wr1_61;
MSKand_opini2_d2 u_gr_61 (
    .ina({rm_d1[61], rm_d0[61]}), .inb({nzr1, nzr0}),
    .rnd(r[1342]), .s(s[1342]), .clk(clk), .out({wr1_61, wr0_61}));
assign reme[122] = wr0_61;  assign reme[123] = wr1_61;
wire wr0_62, wr1_62;
MSKand_opini2_d2 u_gr_62 (
    .ina({rm_d1[62], rm_d0[62]}), .inb({nzr1, nzr0}),
    .rnd(r[1343]), .s(s[1343]), .clk(clk), .out({wr1_62, wr0_62}));
assign reme[124] = wr0_62;  assign reme[125] = wr1_62;
wire wr0_63, wr1_63;
MSKand_opini2_d2 u_gr_63 (
    .ina({rm_d1[63], rm_d0[63]}), .inb({nzr1, nzr0}),
    .rnd(r[1344]), .s(s[1344]), .clk(clk), .out({wr1_63, wr0_63}));
assign reme[126] = wr0_63;  assign reme[127] = wr1_63;
wire wr0_64, wr1_64;
MSKand_opini2_d2 u_gr_64 (
    .ina({rm_d1[64], rm_d0[64]}), .inb({nzr1, nzr0}),
    .rnd(r[1345]), .s(s[1345]), .clk(clk), .out({wr1_64, wr0_64}));
assign reme[128] = wr0_64;  assign reme[129] = wr1_64;
wire wr0_65, wr1_65;
MSKand_opini2_d2 u_gr_65 (
    .ina({rm_d1[65], rm_d0[65]}), .inb({nzr1, nzr0}),
    .rnd(r[1346]), .s(s[1346]), .clk(clk), .out({wr1_65, wr0_65}));
assign reme[130] = wr0_65;  assign reme[131] = wr1_65;
wire wr0_66, wr1_66;
MSKand_opini2_d2 u_gr_66 (
    .ina({rm_d1[66], rm_d0[66]}), .inb({nzr1, nzr0}),
    .rnd(r[1347]), .s(s[1347]), .clk(clk), .out({wr1_66, wr0_66}));
assign reme[132] = wr0_66;  assign reme[133] = wr1_66;
wire wr0_67, wr1_67;
MSKand_opini2_d2 u_gr_67 (
    .ina({rm_d1[67], rm_d0[67]}), .inb({nzr1, nzr0}),
    .rnd(r[1348]), .s(s[1348]), .clk(clk), .out({wr1_67, wr0_67}));
assign reme[134] = wr0_67;  assign reme[135] = wr1_67;
wire wr0_68, wr1_68;
MSKand_opini2_d2 u_gr_68 (
    .ina({rm_d1[68], rm_d0[68]}), .inb({nzr1, nzr0}),
    .rnd(r[1349]), .s(s[1349]), .clk(clk), .out({wr1_68, wr0_68}));
assign reme[136] = wr0_68;  assign reme[137] = wr1_68;
wire wr0_69, wr1_69;
MSKand_opini2_d2 u_gr_69 (
    .ina({rm_d1[69], rm_d0[69]}), .inb({nzr1, nzr0}),
    .rnd(r[1350]), .s(s[1350]), .clk(clk), .out({wr1_69, wr0_69}));
assign reme[138] = wr0_69;  assign reme[139] = wr1_69;
wire wr0_70, wr1_70;
MSKand_opini2_d2 u_gr_70 (
    .ina({rm_d1[70], rm_d0[70]}), .inb({nzr1, nzr0}),
    .rnd(r[1351]), .s(s[1351]), .clk(clk), .out({wr1_70, wr0_70}));
assign reme[140] = wr0_70;  assign reme[141] = wr1_70;
wire wr0_71, wr1_71;
MSKand_opini2_d2 u_gr_71 (
    .ina({rm_d1[71], rm_d0[71]}), .inb({nzr1, nzr0}),
    .rnd(r[1352]), .s(s[1352]), .clk(clk), .out({wr1_71, wr0_71}));
assign reme[142] = wr0_71;  assign reme[143] = wr1_71;
wire wr0_72, wr1_72;
MSKand_opini2_d2 u_gr_72 (
    .ina({rm_d1[72], rm_d0[72]}), .inb({nzr1, nzr0}),
    .rnd(r[1353]), .s(s[1353]), .clk(clk), .out({wr1_72, wr0_72}));
assign reme[144] = wr0_72;  assign reme[145] = wr1_72;
wire wr0_73, wr1_73;
MSKand_opini2_d2 u_gr_73 (
    .ina({rm_d1[73], rm_d0[73]}), .inb({nzr1, nzr0}),
    .rnd(r[1354]), .s(s[1354]), .clk(clk), .out({wr1_73, wr0_73}));
assign reme[146] = wr0_73;  assign reme[147] = wr1_73;
wire wr0_74, wr1_74;
MSKand_opini2_d2 u_gr_74 (
    .ina({rm_d1[74], rm_d0[74]}), .inb({nzr1, nzr0}),
    .rnd(r[1355]), .s(s[1355]), .clk(clk), .out({wr1_74, wr0_74}));
assign reme[148] = wr0_74;  assign reme[149] = wr1_74;
wire wr0_75, wr1_75;
MSKand_opini2_d2 u_gr_75 (
    .ina({rm_d1[75], rm_d0[75]}), .inb({nzr1, nzr0}),
    .rnd(r[1356]), .s(s[1356]), .clk(clk), .out({wr1_75, wr0_75}));
assign reme[150] = wr0_75;  assign reme[151] = wr1_75;
wire wr0_76, wr1_76;
MSKand_opini2_d2 u_gr_76 (
    .ina({rm_d1[76], rm_d0[76]}), .inb({nzr1, nzr0}),
    .rnd(r[1357]), .s(s[1357]), .clk(clk), .out({wr1_76, wr0_76}));
assign reme[152] = wr0_76;  assign reme[153] = wr1_76;
wire wr0_77, wr1_77;
MSKand_opini2_d2 u_gr_77 (
    .ina({rm_d1[77], rm_d0[77]}), .inb({nzr1, nzr0}),
    .rnd(r[1358]), .s(s[1358]), .clk(clk), .out({wr1_77, wr0_77}));
assign reme[154] = wr0_77;  assign reme[155] = wr1_77;
wire wr0_78, wr1_78;
MSKand_opini2_d2 u_gr_78 (
    .ina({rm_d1[78], rm_d0[78]}), .inb({nzr1, nzr0}),
    .rnd(r[1359]), .s(s[1359]), .clk(clk), .out({wr1_78, wr0_78}));
assign reme[156] = wr0_78;  assign reme[157] = wr1_78;
wire wr0_79, wr1_79;
MSKand_opini2_d2 u_gr_79 (
    .ina({rm_d1[79], rm_d0[79]}), .inb({nzr1, nzr0}),
    .rnd(r[1360]), .s(s[1360]), .clk(clk), .out({wr1_79, wr0_79}));
assign reme[158] = wr0_79;  assign reme[159] = wr1_79;
wire wr0_80, wr1_80;
MSKand_opini2_d2 u_gr_80 (
    .ina({rm_d1[80], rm_d0[80]}), .inb({nzr1, nzr0}),
    .rnd(r[1361]), .s(s[1361]), .clk(clk), .out({wr1_80, wr0_80}));
assign reme[160] = wr0_80;  assign reme[161] = wr1_80;
wire wr0_81, wr1_81;
MSKand_opini2_d2 u_gr_81 (
    .ina({rm_d1[81], rm_d0[81]}), .inb({nzr1, nzr0}),
    .rnd(r[1362]), .s(s[1362]), .clk(clk), .out({wr1_81, wr0_81}));
assign reme[162] = wr0_81;  assign reme[163] = wr1_81;
wire wr0_82, wr1_82;
MSKand_opini2_d2 u_gr_82 (
    .ina({rm_d1[82], rm_d0[82]}), .inb({nzr1, nzr0}),
    .rnd(r[1363]), .s(s[1363]), .clk(clk), .out({wr1_82, wr0_82}));
assign reme[164] = wr0_82;  assign reme[165] = wr1_82;
wire wr0_83, wr1_83;
MSKand_opini2_d2 u_gr_83 (
    .ina({rm_d1[83], rm_d0[83]}), .inb({nzr1, nzr0}),
    .rnd(r[1364]), .s(s[1364]), .clk(clk), .out({wr1_83, wr0_83}));
assign reme[166] = wr0_83;  assign reme[167] = wr1_83;
wire wr0_84, wr1_84;
MSKand_opini2_d2 u_gr_84 (
    .ina({rm_d1[84], rm_d0[84]}), .inb({nzr1, nzr0}),
    .rnd(r[1365]), .s(s[1365]), .clk(clk), .out({wr1_84, wr0_84}));
assign reme[168] = wr0_84;  assign reme[169] = wr1_84;
wire wr0_85, wr1_85;
MSKand_opini2_d2 u_gr_85 (
    .ina({rm_d1[85], rm_d0[85]}), .inb({nzr1, nzr0}),
    .rnd(r[1366]), .s(s[1366]), .clk(clk), .out({wr1_85, wr0_85}));
assign reme[170] = wr0_85;  assign reme[171] = wr1_85;
wire wr0_86, wr1_86;
MSKand_opini2_d2 u_gr_86 (
    .ina({rm_d1[86], rm_d0[86]}), .inb({nzr1, nzr0}),
    .rnd(r[1367]), .s(s[1367]), .clk(clk), .out({wr1_86, wr0_86}));
assign reme[172] = wr0_86;  assign reme[173] = wr1_86;
wire wr0_87, wr1_87;
MSKand_opini2_d2 u_gr_87 (
    .ina({rm_d1[87], rm_d0[87]}), .inb({nzr1, nzr0}),
    .rnd(r[1368]), .s(s[1368]), .clk(clk), .out({wr1_87, wr0_87}));
assign reme[174] = wr0_87;  assign reme[175] = wr1_87;
wire wr0_88, wr1_88;
MSKand_opini2_d2 u_gr_88 (
    .ina({rm_d1[88], rm_d0[88]}), .inb({nzr1, nzr0}),
    .rnd(r[1369]), .s(s[1369]), .clk(clk), .out({wr1_88, wr0_88}));
assign reme[176] = wr0_88;  assign reme[177] = wr1_88;
wire wr0_89, wr1_89;
MSKand_opini2_d2 u_gr_89 (
    .ina({rm_d1[89], rm_d0[89]}), .inb({nzr1, nzr0}),
    .rnd(r[1370]), .s(s[1370]), .clk(clk), .out({wr1_89, wr0_89}));
assign reme[178] = wr0_89;  assign reme[179] = wr1_89;
wire wr0_90, wr1_90;
MSKand_opini2_d2 u_gr_90 (
    .ina({rm_d1[90], rm_d0[90]}), .inb({nzr1, nzr0}),
    .rnd(r[1371]), .s(s[1371]), .clk(clk), .out({wr1_90, wr0_90}));
assign reme[180] = wr0_90;  assign reme[181] = wr1_90;
wire wr0_91, wr1_91;
MSKand_opini2_d2 u_gr_91 (
    .ina({rm_d1[91], rm_d0[91]}), .inb({nzr1, nzr0}),
    .rnd(r[1372]), .s(s[1372]), .clk(clk), .out({wr1_91, wr0_91}));
assign reme[182] = wr0_91;  assign reme[183] = wr1_91;
wire wr0_92, wr1_92;
MSKand_opini2_d2 u_gr_92 (
    .ina({rm_d1[92], rm_d0[92]}), .inb({nzr1, nzr0}),
    .rnd(r[1373]), .s(s[1373]), .clk(clk), .out({wr1_92, wr0_92}));
assign reme[184] = wr0_92;  assign reme[185] = wr1_92;
wire wr0_93, wr1_93;
MSKand_opini2_d2 u_gr_93 (
    .ina({rm_d1[93], rm_d0[93]}), .inb({nzr1, nzr0}),
    .rnd(r[1374]), .s(s[1374]), .clk(clk), .out({wr1_93, wr0_93}));
assign reme[186] = wr0_93;  assign reme[187] = wr1_93;
wire wr0_94, wr1_94;
MSKand_opini2_d2 u_gr_94 (
    .ina({rm_d1[94], rm_d0[94]}), .inb({nzr1, nzr0}),
    .rnd(r[1375]), .s(s[1375]), .clk(clk), .out({wr1_94, wr0_94}));
assign reme[188] = wr0_94;  assign reme[189] = wr1_94;
wire wr0_95, wr1_95;
MSKand_opini2_d2 u_gr_95 (
    .ina({rm_d1[95], rm_d0[95]}), .inb({nzr1, nzr0}),
    .rnd(r[1376]), .s(s[1376]), .clk(clk), .out({wr1_95, wr0_95}));
assign reme[190] = wr0_95;  assign reme[191] = wr1_95;
wire wr0_96, wr1_96;
MSKand_opini2_d2 u_gr_96 (
    .ina({rm_d1[96], rm_d0[96]}), .inb({nzr1, nzr0}),
    .rnd(r[1377]), .s(s[1377]), .clk(clk), .out({wr1_96, wr0_96}));
assign reme[192] = wr0_96;  assign reme[193] = wr1_96;
wire wr0_97, wr1_97;
MSKand_opini2_d2 u_gr_97 (
    .ina({rm_d1[97], rm_d0[97]}), .inb({nzr1, nzr0}),
    .rnd(r[1378]), .s(s[1378]), .clk(clk), .out({wr1_97, wr0_97}));
assign reme[194] = wr0_97;  assign reme[195] = wr1_97;
wire wr0_98, wr1_98;
MSKand_opini2_d2 u_gr_98 (
    .ina({rm_d1[98], rm_d0[98]}), .inb({nzr1, nzr0}),
    .rnd(r[1379]), .s(s[1379]), .clk(clk), .out({wr1_98, wr0_98}));
assign reme[196] = wr0_98;  assign reme[197] = wr1_98;
wire wr0_99, wr1_99;
MSKand_opini2_d2 u_gr_99 (
    .ina({rm_d1[99], rm_d0[99]}), .inb({nzr1, nzr0}),
    .rnd(r[1380]), .s(s[1380]), .clk(clk), .out({wr1_99, wr0_99}));
assign reme[198] = wr0_99;  assign reme[199] = wr1_99;
wire wr0_100, wr1_100;
MSKand_opini2_d2 u_gr_100 (
    .ina({rm_d1[100], rm_d0[100]}), .inb({nzr1, nzr0}),
    .rnd(r[1381]), .s(s[1381]), .clk(clk), .out({wr1_100, wr0_100}));
assign reme[200] = wr0_100;  assign reme[201] = wr1_100;
wire wr0_101, wr1_101;
MSKand_opini2_d2 u_gr_101 (
    .ina({rm_d1[101], rm_d0[101]}), .inb({nzr1, nzr0}),
    .rnd(r[1382]), .s(s[1382]), .clk(clk), .out({wr1_101, wr0_101}));
assign reme[202] = wr0_101;  assign reme[203] = wr1_101;
wire wr0_102, wr1_102;
MSKand_opini2_d2 u_gr_102 (
    .ina({rm_d1[102], rm_d0[102]}), .inb({nzr1, nzr0}),
    .rnd(r[1383]), .s(s[1383]), .clk(clk), .out({wr1_102, wr0_102}));
assign reme[204] = wr0_102;  assign reme[205] = wr1_102;
wire wr0_103, wr1_103;
MSKand_opini2_d2 u_gr_103 (
    .ina({rm_d1[103], rm_d0[103]}), .inb({nzr1, nzr0}),
    .rnd(r[1384]), .s(s[1384]), .clk(clk), .out({wr1_103, wr0_103}));
assign reme[206] = wr0_103;  assign reme[207] = wr1_103;
wire wr0_104, wr1_104;
MSKand_opini2_d2 u_gr_104 (
    .ina({rm_d1[104], rm_d0[104]}), .inb({nzr1, nzr0}),
    .rnd(r[1385]), .s(s[1385]), .clk(clk), .out({wr1_104, wr0_104}));
assign reme[208] = wr0_104;  assign reme[209] = wr1_104;
wire wr0_105, wr1_105;
MSKand_opini2_d2 u_gr_105 (
    .ina({rm_d1[105], rm_d0[105]}), .inb({nzr1, nzr0}),
    .rnd(r[1386]), .s(s[1386]), .clk(clk), .out({wr1_105, wr0_105}));
assign reme[210] = wr0_105;  assign reme[211] = wr1_105;
wire wr0_106, wr1_106;
MSKand_opini2_d2 u_gr_106 (
    .ina({rm_d1[106], rm_d0[106]}), .inb({nzr1, nzr0}),
    .rnd(r[1387]), .s(s[1387]), .clk(clk), .out({wr1_106, wr0_106}));
assign reme[212] = wr0_106;  assign reme[213] = wr1_106;
wire wr0_107, wr1_107;
MSKand_opini2_d2 u_gr_107 (
    .ina({rm_d1[107], rm_d0[107]}), .inb({nzr1, nzr0}),
    .rnd(r[1388]), .s(s[1388]), .clk(clk), .out({wr1_107, wr0_107}));
assign reme[214] = wr0_107;  assign reme[215] = wr1_107;
wire wr0_108, wr1_108;
MSKand_opini2_d2 u_gr_108 (
    .ina({rm_d1[108], rm_d0[108]}), .inb({nzr1, nzr0}),
    .rnd(r[1389]), .s(s[1389]), .clk(clk), .out({wr1_108, wr0_108}));
assign reme[216] = wr0_108;  assign reme[217] = wr1_108;
wire wr0_109, wr1_109;
MSKand_opini2_d2 u_gr_109 (
    .ina({rm_d1[109], rm_d0[109]}), .inb({nzr1, nzr0}),
    .rnd(r[1390]), .s(s[1390]), .clk(clk), .out({wr1_109, wr0_109}));
assign reme[218] = wr0_109;  assign reme[219] = wr1_109;
wire wr0_110, wr1_110;
MSKand_opini2_d2 u_gr_110 (
    .ina({rm_d1[110], rm_d0[110]}), .inb({nzr1, nzr0}),
    .rnd(r[1391]), .s(s[1391]), .clk(clk), .out({wr1_110, wr0_110}));
assign reme[220] = wr0_110;  assign reme[221] = wr1_110;
wire wr0_111, wr1_111;
MSKand_opini2_d2 u_gr_111 (
    .ina({rm_d1[111], rm_d0[111]}), .inb({nzr1, nzr0}),
    .rnd(r[1392]), .s(s[1392]), .clk(clk), .out({wr1_111, wr0_111}));
assign reme[222] = wr0_111;  assign reme[223] = wr1_111;
wire wr0_112, wr1_112;
MSKand_opini2_d2 u_gr_112 (
    .ina({rm_d1[112], rm_d0[112]}), .inb({nzr1, nzr0}),
    .rnd(r[1393]), .s(s[1393]), .clk(clk), .out({wr1_112, wr0_112}));
assign reme[224] = wr0_112;  assign reme[225] = wr1_112;
wire wr0_113, wr1_113;
MSKand_opini2_d2 u_gr_113 (
    .ina({rm_d1[113], rm_d0[113]}), .inb({nzr1, nzr0}),
    .rnd(r[1394]), .s(s[1394]), .clk(clk), .out({wr1_113, wr0_113}));
assign reme[226] = wr0_113;  assign reme[227] = wr1_113;
wire wr0_114, wr1_114;
MSKand_opini2_d2 u_gr_114 (
    .ina({rm_d1[114], rm_d0[114]}), .inb({nzr1, nzr0}),
    .rnd(r[1395]), .s(s[1395]), .clk(clk), .out({wr1_114, wr0_114}));
assign reme[228] = wr0_114;  assign reme[229] = wr1_114;
wire wr0_115, wr1_115;
MSKand_opini2_d2 u_gr_115 (
    .ina({rm_d1[115], rm_d0[115]}), .inb({nzr1, nzr0}),
    .rnd(r[1396]), .s(s[1396]), .clk(clk), .out({wr1_115, wr0_115}));
assign reme[230] = wr0_115;  assign reme[231] = wr1_115;
wire wr0_116, wr1_116;
MSKand_opini2_d2 u_gr_116 (
    .ina({rm_d1[116], rm_d0[116]}), .inb({nzr1, nzr0}),
    .rnd(r[1397]), .s(s[1397]), .clk(clk), .out({wr1_116, wr0_116}));
assign reme[232] = wr0_116;  assign reme[233] = wr1_116;
wire wr0_117, wr1_117;
MSKand_opini2_d2 u_gr_117 (
    .ina({rm_d1[117], rm_d0[117]}), .inb({nzr1, nzr0}),
    .rnd(r[1398]), .s(s[1398]), .clk(clk), .out({wr1_117, wr0_117}));
assign reme[234] = wr0_117;  assign reme[235] = wr1_117;
wire wr0_118, wr1_118;
MSKand_opini2_d2 u_gr_118 (
    .ina({rm_d1[118], rm_d0[118]}), .inb({nzr1, nzr0}),
    .rnd(r[1399]), .s(s[1399]), .clk(clk), .out({wr1_118, wr0_118}));
assign reme[236] = wr0_118;  assign reme[237] = wr1_118;
wire wr0_119, wr1_119;
MSKand_opini2_d2 u_gr_119 (
    .ina({rm_d1[119], rm_d0[119]}), .inb({nzr1, nzr0}),
    .rnd(r[1400]), .s(s[1400]), .clk(clk), .out({wr1_119, wr0_119}));
assign reme[238] = wr0_119;  assign reme[239] = wr1_119;
wire wr0_120, wr1_120;
MSKand_opini2_d2 u_gr_120 (
    .ina({rm_d1[120], rm_d0[120]}), .inb({nzr1, nzr0}),
    .rnd(r[1401]), .s(s[1401]), .clk(clk), .out({wr1_120, wr0_120}));
assign reme[240] = wr0_120;  assign reme[241] = wr1_120;
wire wr0_121, wr1_121;
MSKand_opini2_d2 u_gr_121 (
    .ina({rm_d1[121], rm_d0[121]}), .inb({nzr1, nzr0}),
    .rnd(r[1402]), .s(s[1402]), .clk(clk), .out({wr1_121, wr0_121}));
assign reme[242] = wr0_121;  assign reme[243] = wr1_121;
wire wr0_122, wr1_122;
MSKand_opini2_d2 u_gr_122 (
    .ina({rm_d1[122], rm_d0[122]}), .inb({nzr1, nzr0}),
    .rnd(r[1403]), .s(s[1403]), .clk(clk), .out({wr1_122, wr0_122}));
assign reme[244] = wr0_122;  assign reme[245] = wr1_122;
wire wr0_123, wr1_123;
MSKand_opini2_d2 u_gr_123 (
    .ina({rm_d1[123], rm_d0[123]}), .inb({nzr1, nzr0}),
    .rnd(r[1404]), .s(s[1404]), .clk(clk), .out({wr1_123, wr0_123}));
assign reme[246] = wr0_123;  assign reme[247] = wr1_123;
wire wr0_124, wr1_124;
MSKand_opini2_d2 u_gr_124 (
    .ina({rm_d1[124], rm_d0[124]}), .inb({nzr1, nzr0}),
    .rnd(r[1405]), .s(s[1405]), .clk(clk), .out({wr1_124, wr0_124}));
assign reme[248] = wr0_124;  assign reme[249] = wr1_124;
wire wr0_125, wr1_125;
MSKand_opini2_d2 u_gr_125 (
    .ina({rm_d1[125], rm_d0[125]}), .inb({nzr1, nzr0}),
    .rnd(r[1406]), .s(s[1406]), .clk(clk), .out({wr1_125, wr0_125}));
assign reme[250] = wr0_125;  assign reme[251] = wr1_125;
wire wr0_126, wr1_126;
MSKand_opini2_d2 u_gr_126 (
    .ina({rm_d1[126], rm_d0[126]}), .inb({nzr1, nzr0}),
    .rnd(r[1407]), .s(s[1407]), .clk(clk), .out({wr1_126, wr0_126}));
assign reme[252] = wr0_126;  assign reme[253] = wr1_126;
wire wr0_127, wr1_127;
MSKand_opini2_d2 u_gr_127 (
    .ina({rm_d1[127], rm_d0[127]}), .inb({nzr1, nzr0}),
    .rnd(r[1408]), .s(s[1408]), .clk(clk), .out({wr1_127, wr0_127}));
assign reme[254] = wr0_127;  assign reme[255] = wr1_127;
wire wr0_128, wr1_128;
MSKand_opini2_d2 u_gr_128 (
    .ina({rm_d1[128], rm_d0[128]}), .inb({nzr1, nzr0}),
    .rnd(r[1409]), .s(s[1409]), .clk(clk), .out({wr1_128, wr0_128}));
assign reme[256] = wr0_128;  assign reme[257] = wr1_128;
wire wr0_129, wr1_129;
MSKand_opini2_d2 u_gr_129 (
    .ina({rm_d1[129], rm_d0[129]}), .inb({nzr1, nzr0}),
    .rnd(r[1410]), .s(s[1410]), .clk(clk), .out({wr1_129, wr0_129}));
assign reme[258] = wr0_129;  assign reme[259] = wr1_129;
wire wr0_130, wr1_130;
MSKand_opini2_d2 u_gr_130 (
    .ina({rm_d1[130], rm_d0[130]}), .inb({nzr1, nzr0}),
    .rnd(r[1411]), .s(s[1411]), .clk(clk), .out({wr1_130, wr0_130}));
assign reme[260] = wr0_130;  assign reme[261] = wr1_130;
wire wr0_131, wr1_131;
MSKand_opini2_d2 u_gr_131 (
    .ina({rm_d1[131], rm_d0[131]}), .inb({nzr1, nzr0}),
    .rnd(r[1412]), .s(s[1412]), .clk(clk), .out({wr1_131, wr0_131}));
assign reme[262] = wr0_131;  assign reme[263] = wr1_131;
wire wr0_132, wr1_132;
MSKand_opini2_d2 u_gr_132 (
    .ina({rm_d1[132], rm_d0[132]}), .inb({nzr1, nzr0}),
    .rnd(r[1413]), .s(s[1413]), .clk(clk), .out({wr1_132, wr0_132}));
assign reme[264] = wr0_132;  assign reme[265] = wr1_132;
wire wr0_133, wr1_133;
MSKand_opini2_d2 u_gr_133 (
    .ina({rm_d1[133], rm_d0[133]}), .inb({nzr1, nzr0}),
    .rnd(r[1414]), .s(s[1414]), .clk(clk), .out({wr1_133, wr0_133}));
assign reme[266] = wr0_133;  assign reme[267] = wr1_133;
wire wr0_134, wr1_134;
MSKand_opini2_d2 u_gr_134 (
    .ina({rm_d1[134], rm_d0[134]}), .inb({nzr1, nzr0}),
    .rnd(r[1415]), .s(s[1415]), .clk(clk), .out({wr1_134, wr0_134}));
assign reme[268] = wr0_134;  assign reme[269] = wr1_134;
wire wr0_135, wr1_135;
MSKand_opini2_d2 u_gr_135 (
    .ina({rm_d1[135], rm_d0[135]}), .inb({nzr1, nzr0}),
    .rnd(r[1416]), .s(s[1416]), .clk(clk), .out({wr1_135, wr0_135}));
assign reme[270] = wr0_135;  assign reme[271] = wr1_135;
wire wr0_136, wr1_136;
MSKand_opini2_d2 u_gr_136 (
    .ina({rm_d1[136], rm_d0[136]}), .inb({nzr1, nzr0}),
    .rnd(r[1417]), .s(s[1417]), .clk(clk), .out({wr1_136, wr0_136}));
assign reme[272] = wr0_136;  assign reme[273] = wr1_136;
wire wr0_137, wr1_137;
MSKand_opini2_d2 u_gr_137 (
    .ina({rm_d1[137], rm_d0[137]}), .inb({nzr1, nzr0}),
    .rnd(r[1418]), .s(s[1418]), .clk(clk), .out({wr1_137, wr0_137}));
assign reme[274] = wr0_137;  assign reme[275] = wr1_137;
wire wr0_138, wr1_138;
MSKand_opini2_d2 u_gr_138 (
    .ina({rm_d1[138], rm_d0[138]}), .inb({nzr1, nzr0}),
    .rnd(r[1419]), .s(s[1419]), .clk(clk), .out({wr1_138, wr0_138}));
assign reme[276] = wr0_138;  assign reme[277] = wr1_138;
wire wr0_139, wr1_139;
MSKand_opini2_d2 u_gr_139 (
    .ina({rm_d1[139], rm_d0[139]}), .inb({nzr1, nzr0}),
    .rnd(r[1420]), .s(s[1420]), .clk(clk), .out({wr1_139, wr0_139}));
assign reme[278] = wr0_139;  assign reme[279] = wr1_139;
wire wr0_140, wr1_140;
MSKand_opini2_d2 u_gr_140 (
    .ina({rm_d1[140], rm_d0[140]}), .inb({nzr1, nzr0}),
    .rnd(r[1421]), .s(s[1421]), .clk(clk), .out({wr1_140, wr0_140}));
assign reme[280] = wr0_140;  assign reme[281] = wr1_140;
wire wr0_141, wr1_141;
MSKand_opini2_d2 u_gr_141 (
    .ina({rm_d1[141], rm_d0[141]}), .inb({nzr1, nzr0}),
    .rnd(r[1422]), .s(s[1422]), .clk(clk), .out({wr1_141, wr0_141}));
assign reme[282] = wr0_141;  assign reme[283] = wr1_141;
wire wr0_142, wr1_142;
MSKand_opini2_d2 u_gr_142 (
    .ina({rm_d1[142], rm_d0[142]}), .inb({nzr1, nzr0}),
    .rnd(r[1423]), .s(s[1423]), .clk(clk), .out({wr1_142, wr0_142}));
assign reme[284] = wr0_142;  assign reme[285] = wr1_142;
wire wr0_143, wr1_143;
MSKand_opini2_d2 u_gr_143 (
    .ina({rm_d1[143], rm_d0[143]}), .inb({nzr1, nzr0}),
    .rnd(r[1424]), .s(s[1424]), .clk(clk), .out({wr1_143, wr0_143}));
assign reme[286] = wr0_143;  assign reme[287] = wr1_143;
wire wr0_144, wr1_144;
MSKand_opini2_d2 u_gr_144 (
    .ina({rm_d1[144], rm_d0[144]}), .inb({nzr1, nzr0}),
    .rnd(r[1425]), .s(s[1425]), .clk(clk), .out({wr1_144, wr0_144}));
assign reme[288] = wr0_144;  assign reme[289] = wr1_144;
wire wr0_145, wr1_145;
MSKand_opini2_d2 u_gr_145 (
    .ina({rm_d1[145], rm_d0[145]}), .inb({nzr1, nzr0}),
    .rnd(r[1426]), .s(s[1426]), .clk(clk), .out({wr1_145, wr0_145}));
assign reme[290] = wr0_145;  assign reme[291] = wr1_145;
wire wr0_146, wr1_146;
MSKand_opini2_d2 u_gr_146 (
    .ina({rm_d1[146], rm_d0[146]}), .inb({nzr1, nzr0}),
    .rnd(r[1427]), .s(s[1427]), .clk(clk), .out({wr1_146, wr0_146}));
assign reme[292] = wr0_146;  assign reme[293] = wr1_146;
wire wr0_147, wr1_147;
MSKand_opini2_d2 u_gr_147 (
    .ina({rm_d1[147], rm_d0[147]}), .inb({nzr1, nzr0}),
    .rnd(r[1428]), .s(s[1428]), .clk(clk), .out({wr1_147, wr0_147}));
assign reme[294] = wr0_147;  assign reme[295] = wr1_147;
wire wr0_148, wr1_148;
MSKand_opini2_d2 u_gr_148 (
    .ina({rm_d1[148], rm_d0[148]}), .inb({nzr1, nzr0}),
    .rnd(r[1429]), .s(s[1429]), .clk(clk), .out({wr1_148, wr0_148}));
assign reme[296] = wr0_148;  assign reme[297] = wr1_148;
wire wr0_149, wr1_149;
MSKand_opini2_d2 u_gr_149 (
    .ina({rm_d1[149], rm_d0[149]}), .inb({nzr1, nzr0}),
    .rnd(r[1430]), .s(s[1430]), .clk(clk), .out({wr1_149, wr0_149}));
assign reme[298] = wr0_149;  assign reme[299] = wr1_149;
wire wr0_150, wr1_150;
MSKand_opini2_d2 u_gr_150 (
    .ina({rm_d1[150], rm_d0[150]}), .inb({nzr1, nzr0}),
    .rnd(r[1431]), .s(s[1431]), .clk(clk), .out({wr1_150, wr0_150}));
assign reme[300] = wr0_150;  assign reme[301] = wr1_150;
wire wr0_151, wr1_151;
MSKand_opini2_d2 u_gr_151 (
    .ina({rm_d1[151], rm_d0[151]}), .inb({nzr1, nzr0}),
    .rnd(r[1432]), .s(s[1432]), .clk(clk), .out({wr1_151, wr0_151}));
assign reme[302] = wr0_151;  assign reme[303] = wr1_151;
wire wr0_152, wr1_152;
MSKand_opini2_d2 u_gr_152 (
    .ina({rm_d1[152], rm_d0[152]}), .inb({nzr1, nzr0}),
    .rnd(r[1433]), .s(s[1433]), .clk(clk), .out({wr1_152, wr0_152}));
assign reme[304] = wr0_152;  assign reme[305] = wr1_152;
wire wr0_153, wr1_153;
MSKand_opini2_d2 u_gr_153 (
    .ina({rm_d1[153], rm_d0[153]}), .inb({nzr1, nzr0}),
    .rnd(r[1434]), .s(s[1434]), .clk(clk), .out({wr1_153, wr0_153}));
assign reme[306] = wr0_153;  assign reme[307] = wr1_153;
wire wr0_154, wr1_154;
MSKand_opini2_d2 u_gr_154 (
    .ina({rm_d1[154], rm_d0[154]}), .inb({nzr1, nzr0}),
    .rnd(r[1435]), .s(s[1435]), .clk(clk), .out({wr1_154, wr0_154}));
assign reme[308] = wr0_154;  assign reme[309] = wr1_154;
wire wr0_155, wr1_155;
MSKand_opini2_d2 u_gr_155 (
    .ina({rm_d1[155], rm_d0[155]}), .inb({nzr1, nzr0}),
    .rnd(r[1436]), .s(s[1436]), .clk(clk), .out({wr1_155, wr0_155}));
assign reme[310] = wr0_155;  assign reme[311] = wr1_155;
wire wr0_156, wr1_156;
MSKand_opini2_d2 u_gr_156 (
    .ina({rm_d1[156], rm_d0[156]}), .inb({nzr1, nzr0}),
    .rnd(r[1437]), .s(s[1437]), .clk(clk), .out({wr1_156, wr0_156}));
assign reme[312] = wr0_156;  assign reme[313] = wr1_156;
wire wr0_157, wr1_157;
MSKand_opini2_d2 u_gr_157 (
    .ina({rm_d1[157], rm_d0[157]}), .inb({nzr1, nzr0}),
    .rnd(r[1438]), .s(s[1438]), .clk(clk), .out({wr1_157, wr0_157}));
assign reme[314] = wr0_157;  assign reme[315] = wr1_157;
wire wr0_158, wr1_158;
MSKand_opini2_d2 u_gr_158 (
    .ina({rm_d1[158], rm_d0[158]}), .inb({nzr1, nzr0}),
    .rnd(r[1439]), .s(s[1439]), .clk(clk), .out({wr1_158, wr0_158}));
assign reme[316] = wr0_158;  assign reme[317] = wr1_158;
wire wr0_159, wr1_159;
MSKand_opini2_d2 u_gr_159 (
    .ina({rm_d1[159], rm_d0[159]}), .inb({nzr1, nzr0}),
    .rnd(r[1440]), .s(s[1440]), .clk(clk), .out({wr1_159, wr0_159}));
assign reme[318] = wr0_159;  assign reme[319] = wr1_159;
wire wr0_160, wr1_160;
MSKand_opini2_d2 u_gr_160 (
    .ina({rm_d1[160], rm_d0[160]}), .inb({nzr1, nzr0}),
    .rnd(r[1441]), .s(s[1441]), .clk(clk), .out({wr1_160, wr0_160}));
assign reme[320] = wr0_160;  assign reme[321] = wr1_160;
wire wr0_161, wr1_161;
MSKand_opini2_d2 u_gr_161 (
    .ina({rm_d1[161], rm_d0[161]}), .inb({nzr1, nzr0}),
    .rnd(r[1442]), .s(s[1442]), .clk(clk), .out({wr1_161, wr0_161}));
assign reme[322] = wr0_161;  assign reme[323] = wr1_161;
wire wr0_162, wr1_162;
MSKand_opini2_d2 u_gr_162 (
    .ina({rm_d1[162], rm_d0[162]}), .inb({nzr1, nzr0}),
    .rnd(r[1443]), .s(s[1443]), .clk(clk), .out({wr1_162, wr0_162}));
assign reme[324] = wr0_162;  assign reme[325] = wr1_162;
wire wr0_163, wr1_163;
MSKand_opini2_d2 u_gr_163 (
    .ina({rm_d1[163], rm_d0[163]}), .inb({nzr1, nzr0}),
    .rnd(r[1444]), .s(s[1444]), .clk(clk), .out({wr1_163, wr0_163}));
assign reme[326] = wr0_163;  assign reme[327] = wr1_163;
wire wr0_164, wr1_164;
MSKand_opini2_d2 u_gr_164 (
    .ina({rm_d1[164], rm_d0[164]}), .inb({nzr1, nzr0}),
    .rnd(r[1445]), .s(s[1445]), .clk(clk), .out({wr1_164, wr0_164}));
assign reme[328] = wr0_164;  assign reme[329] = wr1_164;
wire wr0_165, wr1_165;
MSKand_opini2_d2 u_gr_165 (
    .ina({rm_d1[165], rm_d0[165]}), .inb({nzr1, nzr0}),
    .rnd(r[1446]), .s(s[1446]), .clk(clk), .out({wr1_165, wr0_165}));
assign reme[330] = wr0_165;  assign reme[331] = wr1_165;
wire wr0_166, wr1_166;
MSKand_opini2_d2 u_gr_166 (
    .ina({rm_d1[166], rm_d0[166]}), .inb({nzr1, nzr0}),
    .rnd(r[1447]), .s(s[1447]), .clk(clk), .out({wr1_166, wr0_166}));
assign reme[332] = wr0_166;  assign reme[333] = wr1_166;
wire wr0_167, wr1_167;
MSKand_opini2_d2 u_gr_167 (
    .ina({rm_d1[167], rm_d0[167]}), .inb({nzr1, nzr0}),
    .rnd(r[1448]), .s(s[1448]), .clk(clk), .out({wr1_167, wr0_167}));
assign reme[334] = wr0_167;  assign reme[335] = wr1_167;
wire wr0_168, wr1_168;
MSKand_opini2_d2 u_gr_168 (
    .ina({rm_d1[168], rm_d0[168]}), .inb({nzr1, nzr0}),
    .rnd(r[1449]), .s(s[1449]), .clk(clk), .out({wr1_168, wr0_168}));
assign reme[336] = wr0_168;  assign reme[337] = wr1_168;
wire wr0_169, wr1_169;
MSKand_opini2_d2 u_gr_169 (
    .ina({rm_d1[169], rm_d0[169]}), .inb({nzr1, nzr0}),
    .rnd(r[1450]), .s(s[1450]), .clk(clk), .out({wr1_169, wr0_169}));
assign reme[338] = wr0_169;  assign reme[339] = wr1_169;
wire wr0_170, wr1_170;
MSKand_opini2_d2 u_gr_170 (
    .ina({rm_d1[170], rm_d0[170]}), .inb({nzr1, nzr0}),
    .rnd(r[1451]), .s(s[1451]), .clk(clk), .out({wr1_170, wr0_170}));
assign reme[340] = wr0_170;  assign reme[341] = wr1_170;
wire wr0_171, wr1_171;
MSKand_opini2_d2 u_gr_171 (
    .ina({rm_d1[171], rm_d0[171]}), .inb({nzr1, nzr0}),
    .rnd(r[1452]), .s(s[1452]), .clk(clk), .out({wr1_171, wr0_171}));
assign reme[342] = wr0_171;  assign reme[343] = wr1_171;
wire wr0_172, wr1_172;
MSKand_opini2_d2 u_gr_172 (
    .ina({rm_d1[172], rm_d0[172]}), .inb({nzr1, nzr0}),
    .rnd(r[1453]), .s(s[1453]), .clk(clk), .out({wr1_172, wr0_172}));
assign reme[344] = wr0_172;  assign reme[345] = wr1_172;
wire wr0_173, wr1_173;
MSKand_opini2_d2 u_gr_173 (
    .ina({rm_d1[173], rm_d0[173]}), .inb({nzr1, nzr0}),
    .rnd(r[1454]), .s(s[1454]), .clk(clk), .out({wr1_173, wr0_173}));
assign reme[346] = wr0_173;  assign reme[347] = wr1_173;
wire wr0_174, wr1_174;
MSKand_opini2_d2 u_gr_174 (
    .ina({rm_d1[174], rm_d0[174]}), .inb({nzr1, nzr0}),
    .rnd(r[1455]), .s(s[1455]), .clk(clk), .out({wr1_174, wr0_174}));
assign reme[348] = wr0_174;  assign reme[349] = wr1_174;
wire wr0_175, wr1_175;
MSKand_opini2_d2 u_gr_175 (
    .ina({rm_d1[175], rm_d0[175]}), .inb({nzr1, nzr0}),
    .rnd(r[1456]), .s(s[1456]), .clk(clk), .out({wr1_175, wr0_175}));
assign reme[350] = wr0_175;  assign reme[351] = wr1_175;
wire wr0_176, wr1_176;
MSKand_opini2_d2 u_gr_176 (
    .ina({rm_d1[176], rm_d0[176]}), .inb({nzr1, nzr0}),
    .rnd(r[1457]), .s(s[1457]), .clk(clk), .out({wr1_176, wr0_176}));
assign reme[352] = wr0_176;  assign reme[353] = wr1_176;
wire wr0_177, wr1_177;
MSKand_opini2_d2 u_gr_177 (
    .ina({rm_d1[177], rm_d0[177]}), .inb({nzr1, nzr0}),
    .rnd(r[1458]), .s(s[1458]), .clk(clk), .out({wr1_177, wr0_177}));
assign reme[354] = wr0_177;  assign reme[355] = wr1_177;
wire wr0_178, wr1_178;
MSKand_opini2_d2 u_gr_178 (
    .ina({rm_d1[178], rm_d0[178]}), .inb({nzr1, nzr0}),
    .rnd(r[1459]), .s(s[1459]), .clk(clk), .out({wr1_178, wr0_178}));
assign reme[356] = wr0_178;  assign reme[357] = wr1_178;
wire wr0_179, wr1_179;
MSKand_opini2_d2 u_gr_179 (
    .ina({rm_d1[179], rm_d0[179]}), .inb({nzr1, nzr0}),
    .rnd(r[1460]), .s(s[1460]), .clk(clk), .out({wr1_179, wr0_179}));
assign reme[358] = wr0_179;  assign reme[359] = wr1_179;
wire wr0_180, wr1_180;
MSKand_opini2_d2 u_gr_180 (
    .ina({rm_d1[180], rm_d0[180]}), .inb({nzr1, nzr0}),
    .rnd(r[1461]), .s(s[1461]), .clk(clk), .out({wr1_180, wr0_180}));
assign reme[360] = wr0_180;  assign reme[361] = wr1_180;
wire wr0_181, wr1_181;
MSKand_opini2_d2 u_gr_181 (
    .ina({rm_d1[181], rm_d0[181]}), .inb({nzr1, nzr0}),
    .rnd(r[1462]), .s(s[1462]), .clk(clk), .out({wr1_181, wr0_181}));
assign reme[362] = wr0_181;  assign reme[363] = wr1_181;
wire wr0_182, wr1_182;
MSKand_opini2_d2 u_gr_182 (
    .ina({rm_d1[182], rm_d0[182]}), .inb({nzr1, nzr0}),
    .rnd(r[1463]), .s(s[1463]), .clk(clk), .out({wr1_182, wr0_182}));
assign reme[364] = wr0_182;  assign reme[365] = wr1_182;
wire wr0_183, wr1_183;
MSKand_opini2_d2 u_gr_183 (
    .ina({rm_d1[183], rm_d0[183]}), .inb({nzr1, nzr0}),
    .rnd(r[1464]), .s(s[1464]), .clk(clk), .out({wr1_183, wr0_183}));
assign reme[366] = wr0_183;  assign reme[367] = wr1_183;
wire wr0_184, wr1_184;
MSKand_opini2_d2 u_gr_184 (
    .ina({rm_d1[184], rm_d0[184]}), .inb({nzr1, nzr0}),
    .rnd(r[1465]), .s(s[1465]), .clk(clk), .out({wr1_184, wr0_184}));
assign reme[368] = wr0_184;  assign reme[369] = wr1_184;
wire wr0_185, wr1_185;
MSKand_opini2_d2 u_gr_185 (
    .ina({rm_d1[185], rm_d0[185]}), .inb({nzr1, nzr0}),
    .rnd(r[1466]), .s(s[1466]), .clk(clk), .out({wr1_185, wr0_185}));
assign reme[370] = wr0_185;  assign reme[371] = wr1_185;
wire wr0_186, wr1_186;
MSKand_opini2_d2 u_gr_186 (
    .ina({rm_d1[186], rm_d0[186]}), .inb({nzr1, nzr0}),
    .rnd(r[1467]), .s(s[1467]), .clk(clk), .out({wr1_186, wr0_186}));
assign reme[372] = wr0_186;  assign reme[373] = wr1_186;
wire wr0_187, wr1_187;
MSKand_opini2_d2 u_gr_187 (
    .ina({rm_d1[187], rm_d0[187]}), .inb({nzr1, nzr0}),
    .rnd(r[1468]), .s(s[1468]), .clk(clk), .out({wr1_187, wr0_187}));
assign reme[374] = wr0_187;  assign reme[375] = wr1_187;
wire wr0_188, wr1_188;
MSKand_opini2_d2 u_gr_188 (
    .ina({rm_d1[188], rm_d0[188]}), .inb({nzr1, nzr0}),
    .rnd(r[1469]), .s(s[1469]), .clk(clk), .out({wr1_188, wr0_188}));
assign reme[376] = wr0_188;  assign reme[377] = wr1_188;
wire wr0_189, wr1_189;
MSKand_opini2_d2 u_gr_189 (
    .ina({rm_d1[189], rm_d0[189]}), .inb({nzr1, nzr0}),
    .rnd(r[1470]), .s(s[1470]), .clk(clk), .out({wr1_189, wr0_189}));
assign reme[378] = wr0_189;  assign reme[379] = wr1_189;
wire wr0_190, wr1_190;
MSKand_opini2_d2 u_gr_190 (
    .ina({rm_d1[190], rm_d0[190]}), .inb({nzr1, nzr0}),
    .rnd(r[1471]), .s(s[1471]), .clk(clk), .out({wr1_190, wr0_190}));
assign reme[380] = wr0_190;  assign reme[381] = wr1_190;
wire wr0_191, wr1_191;
MSKand_opini2_d2 u_gr_191 (
    .ina({rm_d1[191], rm_d0[191]}), .inb({nzr1, nzr0}),
    .rnd(r[1472]), .s(s[1472]), .clk(clk), .out({wr1_191, wr0_191}));
assign reme[382] = wr0_191;  assign reme[383] = wr1_191;
wire wr0_192, wr1_192;
MSKand_opini2_d2 u_gr_192 (
    .ina({rm_d1[192], rm_d0[192]}), .inb({nzr1, nzr0}),
    .rnd(r[1473]), .s(s[1473]), .clk(clk), .out({wr1_192, wr0_192}));
assign reme[384] = wr0_192;  assign reme[385] = wr1_192;
wire wr0_193, wr1_193;
MSKand_opini2_d2 u_gr_193 (
    .ina({rm_d1[193], rm_d0[193]}), .inb({nzr1, nzr0}),
    .rnd(r[1474]), .s(s[1474]), .clk(clk), .out({wr1_193, wr0_193}));
assign reme[386] = wr0_193;  assign reme[387] = wr1_193;
wire wr0_194, wr1_194;
MSKand_opini2_d2 u_gr_194 (
    .ina({rm_d1[194], rm_d0[194]}), .inb({nzr1, nzr0}),
    .rnd(r[1475]), .s(s[1475]), .clk(clk), .out({wr1_194, wr0_194}));
assign reme[388] = wr0_194;  assign reme[389] = wr1_194;
wire wr0_195, wr1_195;
MSKand_opini2_d2 u_gr_195 (
    .ina({rm_d1[195], rm_d0[195]}), .inb({nzr1, nzr0}),
    .rnd(r[1476]), .s(s[1476]), .clk(clk), .out({wr1_195, wr0_195}));
assign reme[390] = wr0_195;  assign reme[391] = wr1_195;
wire wr0_196, wr1_196;
MSKand_opini2_d2 u_gr_196 (
    .ina({rm_d1[196], rm_d0[196]}), .inb({nzr1, nzr0}),
    .rnd(r[1477]), .s(s[1477]), .clk(clk), .out({wr1_196, wr0_196}));
assign reme[392] = wr0_196;  assign reme[393] = wr1_196;
wire wr0_197, wr1_197;
MSKand_opini2_d2 u_gr_197 (
    .ina({rm_d1[197], rm_d0[197]}), .inb({nzr1, nzr0}),
    .rnd(r[1478]), .s(s[1478]), .clk(clk), .out({wr1_197, wr0_197}));
assign reme[394] = wr0_197;  assign reme[395] = wr1_197;
wire wr0_198, wr1_198;
MSKand_opini2_d2 u_gr_198 (
    .ina({rm_d1[198], rm_d0[198]}), .inb({nzr1, nzr0}),
    .rnd(r[1479]), .s(s[1479]), .clk(clk), .out({wr1_198, wr0_198}));
assign reme[396] = wr0_198;  assign reme[397] = wr1_198;
wire wr0_199, wr1_199;
MSKand_opini2_d2 u_gr_199 (
    .ina({rm_d1[199], rm_d0[199]}), .inb({nzr1, nzr0}),
    .rnd(r[1480]), .s(s[1480]), .clk(clk), .out({wr1_199, wr0_199}));
assign reme[398] = wr0_199;  assign reme[399] = wr1_199;
wire wr0_200, wr1_200;
MSKand_opini2_d2 u_gr_200 (
    .ina({rm_d1[200], rm_d0[200]}), .inb({nzr1, nzr0}),
    .rnd(r[1481]), .s(s[1481]), .clk(clk), .out({wr1_200, wr0_200}));
assign reme[400] = wr0_200;  assign reme[401] = wr1_200;
wire wr0_201, wr1_201;
MSKand_opini2_d2 u_gr_201 (
    .ina({rm_d1[201], rm_d0[201]}), .inb({nzr1, nzr0}),
    .rnd(r[1482]), .s(s[1482]), .clk(clk), .out({wr1_201, wr0_201}));
assign reme[402] = wr0_201;  assign reme[403] = wr1_201;
wire wr0_202, wr1_202;
MSKand_opini2_d2 u_gr_202 (
    .ina({rm_d1[202], rm_d0[202]}), .inb({nzr1, nzr0}),
    .rnd(r[1483]), .s(s[1483]), .clk(clk), .out({wr1_202, wr0_202}));
assign reme[404] = wr0_202;  assign reme[405] = wr1_202;
wire wr0_203, wr1_203;
MSKand_opini2_d2 u_gr_203 (
    .ina({rm_d1[203], rm_d0[203]}), .inb({nzr1, nzr0}),
    .rnd(r[1484]), .s(s[1484]), .clk(clk), .out({wr1_203, wr0_203}));
assign reme[406] = wr0_203;  assign reme[407] = wr1_203;
wire wr0_204, wr1_204;
MSKand_opini2_d2 u_gr_204 (
    .ina({rm_d1[204], rm_d0[204]}), .inb({nzr1, nzr0}),
    .rnd(r[1485]), .s(s[1485]), .clk(clk), .out({wr1_204, wr0_204}));
assign reme[408] = wr0_204;  assign reme[409] = wr1_204;
wire wr0_205, wr1_205;
MSKand_opini2_d2 u_gr_205 (
    .ina({rm_d1[205], rm_d0[205]}), .inb({nzr1, nzr0}),
    .rnd(r[1486]), .s(s[1486]), .clk(clk), .out({wr1_205, wr0_205}));
assign reme[410] = wr0_205;  assign reme[411] = wr1_205;
wire wr0_206, wr1_206;
MSKand_opini2_d2 u_gr_206 (
    .ina({rm_d1[206], rm_d0[206]}), .inb({nzr1, nzr0}),
    .rnd(r[1487]), .s(s[1487]), .clk(clk), .out({wr1_206, wr0_206}));
assign reme[412] = wr0_206;  assign reme[413] = wr1_206;
wire wr0_207, wr1_207;
MSKand_opini2_d2 u_gr_207 (
    .ina({rm_d1[207], rm_d0[207]}), .inb({nzr1, nzr0}),
    .rnd(r[1488]), .s(s[1488]), .clk(clk), .out({wr1_207, wr0_207}));
assign reme[414] = wr0_207;  assign reme[415] = wr1_207;
wire wr0_208, wr1_208;
MSKand_opini2_d2 u_gr_208 (
    .ina({rm_d1[208], rm_d0[208]}), .inb({nzr1, nzr0}),
    .rnd(r[1489]), .s(s[1489]), .clk(clk), .out({wr1_208, wr0_208}));
assign reme[416] = wr0_208;  assign reme[417] = wr1_208;
wire wr0_209, wr1_209;
MSKand_opini2_d2 u_gr_209 (
    .ina({rm_d1[209], rm_d0[209]}), .inb({nzr1, nzr0}),
    .rnd(r[1490]), .s(s[1490]), .clk(clk), .out({wr1_209, wr0_209}));
assign reme[418] = wr0_209;  assign reme[419] = wr1_209;
wire wr0_210, wr1_210;
MSKand_opini2_d2 u_gr_210 (
    .ina({rm_d1[210], rm_d0[210]}), .inb({nzr1, nzr0}),
    .rnd(r[1491]), .s(s[1491]), .clk(clk), .out({wr1_210, wr0_210}));
assign reme[420] = wr0_210;  assign reme[421] = wr1_210;
wire wr0_211, wr1_211;
MSKand_opini2_d2 u_gr_211 (
    .ina({rm_d1[211], rm_d0[211]}), .inb({nzr1, nzr0}),
    .rnd(r[1492]), .s(s[1492]), .clk(clk), .out({wr1_211, wr0_211}));
assign reme[422] = wr0_211;  assign reme[423] = wr1_211;
wire wr0_212, wr1_212;
MSKand_opini2_d2 u_gr_212 (
    .ina({rm_d1[212], rm_d0[212]}), .inb({nzr1, nzr0}),
    .rnd(r[1493]), .s(s[1493]), .clk(clk), .out({wr1_212, wr0_212}));
assign reme[424] = wr0_212;  assign reme[425] = wr1_212;
wire wr0_213, wr1_213;
MSKand_opini2_d2 u_gr_213 (
    .ina({rm_d1[213], rm_d0[213]}), .inb({nzr1, nzr0}),
    .rnd(r[1494]), .s(s[1494]), .clk(clk), .out({wr1_213, wr0_213}));
assign reme[426] = wr0_213;  assign reme[427] = wr1_213;
wire wr0_214, wr1_214;
MSKand_opini2_d2 u_gr_214 (
    .ina({rm_d1[214], rm_d0[214]}), .inb({nzr1, nzr0}),
    .rnd(r[1495]), .s(s[1495]), .clk(clk), .out({wr1_214, wr0_214}));
assign reme[428] = wr0_214;  assign reme[429] = wr1_214;
wire wr0_215, wr1_215;
MSKand_opini2_d2 u_gr_215 (
    .ina({rm_d1[215], rm_d0[215]}), .inb({nzr1, nzr0}),
    .rnd(r[1496]), .s(s[1496]), .clk(clk), .out({wr1_215, wr0_215}));
assign reme[430] = wr0_215;  assign reme[431] = wr1_215;
wire wr0_216, wr1_216;
MSKand_opini2_d2 u_gr_216 (
    .ina({rm_d1[216], rm_d0[216]}), .inb({nzr1, nzr0}),
    .rnd(r[1497]), .s(s[1497]), .clk(clk), .out({wr1_216, wr0_216}));
assign reme[432] = wr0_216;  assign reme[433] = wr1_216;
wire wr0_217, wr1_217;
MSKand_opini2_d2 u_gr_217 (
    .ina({rm_d1[217], rm_d0[217]}), .inb({nzr1, nzr0}),
    .rnd(r[1498]), .s(s[1498]), .clk(clk), .out({wr1_217, wr0_217}));
assign reme[434] = wr0_217;  assign reme[435] = wr1_217;
wire wr0_218, wr1_218;
MSKand_opini2_d2 u_gr_218 (
    .ina({rm_d1[218], rm_d0[218]}), .inb({nzr1, nzr0}),
    .rnd(r[1499]), .s(s[1499]), .clk(clk), .out({wr1_218, wr0_218}));
assign reme[436] = wr0_218;  assign reme[437] = wr1_218;
wire wr0_219, wr1_219;
MSKand_opini2_d2 u_gr_219 (
    .ina({rm_d1[219], rm_d0[219]}), .inb({nzr1, nzr0}),
    .rnd(r[1500]), .s(s[1500]), .clk(clk), .out({wr1_219, wr0_219}));
assign reme[438] = wr0_219;  assign reme[439] = wr1_219;
wire wr0_220, wr1_220;
MSKand_opini2_d2 u_gr_220 (
    .ina({rm_d1[220], rm_d0[220]}), .inb({nzr1, nzr0}),
    .rnd(r[1501]), .s(s[1501]), .clk(clk), .out({wr1_220, wr0_220}));
assign reme[440] = wr0_220;  assign reme[441] = wr1_220;
wire wr0_221, wr1_221;
MSKand_opini2_d2 u_gr_221 (
    .ina({rm_d1[221], rm_d0[221]}), .inb({nzr1, nzr0}),
    .rnd(r[1502]), .s(s[1502]), .clk(clk), .out({wr1_221, wr0_221}));
assign reme[442] = wr0_221;  assign reme[443] = wr1_221;
wire wr0_222, wr1_222;
MSKand_opini2_d2 u_gr_222 (
    .ina({rm_d1[222], rm_d0[222]}), .inb({nzr1, nzr0}),
    .rnd(r[1503]), .s(s[1503]), .clk(clk), .out({wr1_222, wr0_222}));
assign reme[444] = wr0_222;  assign reme[445] = wr1_222;
wire wr0_223, wr1_223;
MSKand_opini2_d2 u_gr_223 (
    .ina({rm_d1[223], rm_d0[223]}), .inb({nzr1, nzr0}),
    .rnd(r[1504]), .s(s[1504]), .clk(clk), .out({wr1_223, wr0_223}));
assign reme[446] = wr0_223;  assign reme[447] = wr1_223;
wire wr0_224, wr1_224;
MSKand_opini2_d2 u_gr_224 (
    .ina({rm_d1[224], rm_d0[224]}), .inb({nzr1, nzr0}),
    .rnd(r[1505]), .s(s[1505]), .clk(clk), .out({wr1_224, wr0_224}));
assign reme[448] = wr0_224;  assign reme[449] = wr1_224;
wire wr0_225, wr1_225;
MSKand_opini2_d2 u_gr_225 (
    .ina({rm_d1[225], rm_d0[225]}), .inb({nzr1, nzr0}),
    .rnd(r[1506]), .s(s[1506]), .clk(clk), .out({wr1_225, wr0_225}));
assign reme[450] = wr0_225;  assign reme[451] = wr1_225;
wire wr0_226, wr1_226;
MSKand_opini2_d2 u_gr_226 (
    .ina({rm_d1[226], rm_d0[226]}), .inb({nzr1, nzr0}),
    .rnd(r[1507]), .s(s[1507]), .clk(clk), .out({wr1_226, wr0_226}));
assign reme[452] = wr0_226;  assign reme[453] = wr1_226;
wire wr0_227, wr1_227;
MSKand_opini2_d2 u_gr_227 (
    .ina({rm_d1[227], rm_d0[227]}), .inb({nzr1, nzr0}),
    .rnd(r[1508]), .s(s[1508]), .clk(clk), .out({wr1_227, wr0_227}));
assign reme[454] = wr0_227;  assign reme[455] = wr1_227;
wire wr0_228, wr1_228;
MSKand_opini2_d2 u_gr_228 (
    .ina({rm_d1[228], rm_d0[228]}), .inb({nzr1, nzr0}),
    .rnd(r[1509]), .s(s[1509]), .clk(clk), .out({wr1_228, wr0_228}));
assign reme[456] = wr0_228;  assign reme[457] = wr1_228;
wire wr0_229, wr1_229;
MSKand_opini2_d2 u_gr_229 (
    .ina({rm_d1[229], rm_d0[229]}), .inb({nzr1, nzr0}),
    .rnd(r[1510]), .s(s[1510]), .clk(clk), .out({wr1_229, wr0_229}));
assign reme[458] = wr0_229;  assign reme[459] = wr1_229;
wire wr0_230, wr1_230;
MSKand_opini2_d2 u_gr_230 (
    .ina({rm_d1[230], rm_d0[230]}), .inb({nzr1, nzr0}),
    .rnd(r[1511]), .s(s[1511]), .clk(clk), .out({wr1_230, wr0_230}));
assign reme[460] = wr0_230;  assign reme[461] = wr1_230;
wire wr0_231, wr1_231;
MSKand_opini2_d2 u_gr_231 (
    .ina({rm_d1[231], rm_d0[231]}), .inb({nzr1, nzr0}),
    .rnd(r[1512]), .s(s[1512]), .clk(clk), .out({wr1_231, wr0_231}));
assign reme[462] = wr0_231;  assign reme[463] = wr1_231;
wire wr0_232, wr1_232;
MSKand_opini2_d2 u_gr_232 (
    .ina({rm_d1[232], rm_d0[232]}), .inb({nzr1, nzr0}),
    .rnd(r[1513]), .s(s[1513]), .clk(clk), .out({wr1_232, wr0_232}));
assign reme[464] = wr0_232;  assign reme[465] = wr1_232;
wire wr0_233, wr1_233;
MSKand_opini2_d2 u_gr_233 (
    .ina({rm_d1[233], rm_d0[233]}), .inb({nzr1, nzr0}),
    .rnd(r[1514]), .s(s[1514]), .clk(clk), .out({wr1_233, wr0_233}));
assign reme[466] = wr0_233;  assign reme[467] = wr1_233;
wire wr0_234, wr1_234;
MSKand_opini2_d2 u_gr_234 (
    .ina({rm_d1[234], rm_d0[234]}), .inb({nzr1, nzr0}),
    .rnd(r[1515]), .s(s[1515]), .clk(clk), .out({wr1_234, wr0_234}));
assign reme[468] = wr0_234;  assign reme[469] = wr1_234;
wire wr0_235, wr1_235;
MSKand_opini2_d2 u_gr_235 (
    .ina({rm_d1[235], rm_d0[235]}), .inb({nzr1, nzr0}),
    .rnd(r[1516]), .s(s[1516]), .clk(clk), .out({wr1_235, wr0_235}));
assign reme[470] = wr0_235;  assign reme[471] = wr1_235;
wire wr0_236, wr1_236;
MSKand_opini2_d2 u_gr_236 (
    .ina({rm_d1[236], rm_d0[236]}), .inb({nzr1, nzr0}),
    .rnd(r[1517]), .s(s[1517]), .clk(clk), .out({wr1_236, wr0_236}));
assign reme[472] = wr0_236;  assign reme[473] = wr1_236;
wire wr0_237, wr1_237;
MSKand_opini2_d2 u_gr_237 (
    .ina({rm_d1[237], rm_d0[237]}), .inb({nzr1, nzr0}),
    .rnd(r[1518]), .s(s[1518]), .clk(clk), .out({wr1_237, wr0_237}));
assign reme[474] = wr0_237;  assign reme[475] = wr1_237;
wire wr0_238, wr1_238;
MSKand_opini2_d2 u_gr_238 (
    .ina({rm_d1[238], rm_d0[238]}), .inb({nzr1, nzr0}),
    .rnd(r[1519]), .s(s[1519]), .clk(clk), .out({wr1_238, wr0_238}));
assign reme[476] = wr0_238;  assign reme[477] = wr1_238;
wire wr0_239, wr1_239;
MSKand_opini2_d2 u_gr_239 (
    .ina({rm_d1[239], rm_d0[239]}), .inb({nzr1, nzr0}),
    .rnd(r[1520]), .s(s[1520]), .clk(clk), .out({wr1_239, wr0_239}));
assign reme[478] = wr0_239;  assign reme[479] = wr1_239;
wire wr0_240, wr1_240;
MSKand_opini2_d2 u_gr_240 (
    .ina({rm_d1[240], rm_d0[240]}), .inb({nzr1, nzr0}),
    .rnd(r[1521]), .s(s[1521]), .clk(clk), .out({wr1_240, wr0_240}));
assign reme[480] = wr0_240;  assign reme[481] = wr1_240;
wire wr0_241, wr1_241;
MSKand_opini2_d2 u_gr_241 (
    .ina({rm_d1[241], rm_d0[241]}), .inb({nzr1, nzr0}),
    .rnd(r[1522]), .s(s[1522]), .clk(clk), .out({wr1_241, wr0_241}));
assign reme[482] = wr0_241;  assign reme[483] = wr1_241;
wire wr0_242, wr1_242;
MSKand_opini2_d2 u_gr_242 (
    .ina({rm_d1[242], rm_d0[242]}), .inb({nzr1, nzr0}),
    .rnd(r[1523]), .s(s[1523]), .clk(clk), .out({wr1_242, wr0_242}));
assign reme[484] = wr0_242;  assign reme[485] = wr1_242;
wire wr0_243, wr1_243;
MSKand_opini2_d2 u_gr_243 (
    .ina({rm_d1[243], rm_d0[243]}), .inb({nzr1, nzr0}),
    .rnd(r[1524]), .s(s[1524]), .clk(clk), .out({wr1_243, wr0_243}));
assign reme[486] = wr0_243;  assign reme[487] = wr1_243;
wire wr0_244, wr1_244;
MSKand_opini2_d2 u_gr_244 (
    .ina({rm_d1[244], rm_d0[244]}), .inb({nzr1, nzr0}),
    .rnd(r[1525]), .s(s[1525]), .clk(clk), .out({wr1_244, wr0_244}));
assign reme[488] = wr0_244;  assign reme[489] = wr1_244;
wire wr0_245, wr1_245;
MSKand_opini2_d2 u_gr_245 (
    .ina({rm_d1[245], rm_d0[245]}), .inb({nzr1, nzr0}),
    .rnd(r[1526]), .s(s[1526]), .clk(clk), .out({wr1_245, wr0_245}));
assign reme[490] = wr0_245;  assign reme[491] = wr1_245;
wire wr0_246, wr1_246;
MSKand_opini2_d2 u_gr_246 (
    .ina({rm_d1[246], rm_d0[246]}), .inb({nzr1, nzr0}),
    .rnd(r[1527]), .s(s[1527]), .clk(clk), .out({wr1_246, wr0_246}));
assign reme[492] = wr0_246;  assign reme[493] = wr1_246;
wire wr0_247, wr1_247;
MSKand_opini2_d2 u_gr_247 (
    .ina({rm_d1[247], rm_d0[247]}), .inb({nzr1, nzr0}),
    .rnd(r[1528]), .s(s[1528]), .clk(clk), .out({wr1_247, wr0_247}));
assign reme[494] = wr0_247;  assign reme[495] = wr1_247;
wire wr0_248, wr1_248;
MSKand_opini2_d2 u_gr_248 (
    .ina({rm_d1[248], rm_d0[248]}), .inb({nzr1, nzr0}),
    .rnd(r[1529]), .s(s[1529]), .clk(clk), .out({wr1_248, wr0_248}));
assign reme[496] = wr0_248;  assign reme[497] = wr1_248;
wire wr0_249, wr1_249;
MSKand_opini2_d2 u_gr_249 (
    .ina({rm_d1[249], rm_d0[249]}), .inb({nzr1, nzr0}),
    .rnd(r[1530]), .s(s[1530]), .clk(clk), .out({wr1_249, wr0_249}));
assign reme[498] = wr0_249;  assign reme[499] = wr1_249;
wire wr0_250, wr1_250;
MSKand_opini2_d2 u_gr_250 (
    .ina({rm_d1[250], rm_d0[250]}), .inb({nzr1, nzr0}),
    .rnd(r[1531]), .s(s[1531]), .clk(clk), .out({wr1_250, wr0_250}));
assign reme[500] = wr0_250;  assign reme[501] = wr1_250;
wire wr0_251, wr1_251;
MSKand_opini2_d2 u_gr_251 (
    .ina({rm_d1[251], rm_d0[251]}), .inb({nzr1, nzr0}),
    .rnd(r[1532]), .s(s[1532]), .clk(clk), .out({wr1_251, wr0_251}));
assign reme[502] = wr0_251;  assign reme[503] = wr1_251;
wire wr0_252, wr1_252;
MSKand_opini2_d2 u_gr_252 (
    .ina({rm_d1[252], rm_d0[252]}), .inb({nzr1, nzr0}),
    .rnd(r[1533]), .s(s[1533]), .clk(clk), .out({wr1_252, wr0_252}));
assign reme[504] = wr0_252;  assign reme[505] = wr1_252;
wire wr0_253, wr1_253;
MSKand_opini2_d2 u_gr_253 (
    .ina({rm_d1[253], rm_d0[253]}), .inb({nzr1, nzr0}),
    .rnd(r[1534]), .s(s[1534]), .clk(clk), .out({wr1_253, wr0_253}));
assign reme[506] = wr0_253;  assign reme[507] = wr1_253;
wire wr0_254, wr1_254;
MSKand_opini2_d2 u_gr_254 (
    .ina({rm_d1[254], rm_d0[254]}), .inb({nzr1, nzr0}),
    .rnd(r[1535]), .s(s[1535]), .clk(clk), .out({wr1_254, wr0_254}));
assign reme[508] = wr0_254;  assign reme[509] = wr1_254;
wire wr0_255, wr1_255;
MSKand_opini2_d2 u_gr_255 (
    .ina({rm_d1[255], rm_d0[255]}), .inb({nzr1, nzr0}),
    .rnd(r[1536]), .s(s[1536]), .clk(clk), .out({wr1_255, wr0_255}));
assign reme[510] = wr0_255;  assign reme[511] = wr1_255;

endmodule
