// LABEL CONTROL: identical netlist but instantiates the PINI-relabelled
// leaf MSKand_opini2_d2_pini. Unlike the single-pass adder/iszero label
// controls, this datapath REUSES gadgets bubble-free with feedback, the
// structure MATCHI's transition rule guards for PINI leaves (cf.
// ./top_chain_pini). Verdict recorded either way.
// Iterative carry-save masked multiplier, prod = (A*B) mod 2^256. 1276 assumed-
// OPINI gadget leaves (256 PP-gating u_pp_*, 510 carry-save MAJ u_sc_*/u_px_*,
// 510 final-add u_g_*/u_t_* — the verified-adder dataflow; the top-bit
// carry gadgets are omitted, their carries are dropped by mod 2^256), each with
// a DEDICATED r[k]/s[k] random bit. Every XOR/shift is strictly share-local.
// Dense sharing layout (share index fastest): port[2i]=share0, port[2i+1]=share1.
// Schedule: load @0; iteration i occupies cycles [1+8i, 8+8i]; S,C final
// from cycle 8*256+1; ripple output stable ~cycle 2568; state cleared
// (share-local, to public 0) at cycle 2585; randoms fresh [0,3119].
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module mul256_pini (clk, rst, go, a, b, r, s, prod);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input go;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [511:0] a;
(* matchi_type = "sharings_dense", matchi_active = "b_act" *) input [511:0] b;
(* matchi_type = "random", matchi_active = "r_act" *) input [1275:0] r;
(* matchi_type = "random", matchi_active = "s_act" *) input [1275:0] s;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [511:0] prod;

// ---- activity shift register (single go pulse; windows are its taps) ----
(* keep *) wire act0 = go;
(* keep *) reg [3120:1] actr;
always @(posedge clk) begin
    if (rst) actr <= 3120'b0;
    else     actr <= {actr[3119:1], act0};
end
wire [3120:0] act = {actr, act0};
(* keep *) wire a_act   = |act[1:0];      // operands consumed only at the load edge
(* keep *) wire b_act   = |act[1:0];
(* keep *) wire r_act   = |act[3119:0];
(* keep *) wire s_act   = |act[3120:1];
(* keep *) wire out_act = |act[3117:0];
(* keep *) wire clr     = act[2585];  // bounded sensitivity: zero the state regs

// ---- public FSM: iteration counter + phase (control only, data-independent) ----
reg running;
reg [8:0] it;
reg [2:0] ph;
always @(posedge clk) begin
    if (rst) begin running <= 1'b0; it <= 0; ph <= 3'd0; end
    else if (go) begin running <= 1'b1; it <= 0; ph <= 3'd0; end
    else if (running) begin
        if (ph == 3'd7) begin
            ph <= 3'd0;
            if (it == 9'd255) begin running <= 1'b0; it <= 0; end
            else it <= it + 9'd1;
        end else ph <= ph + 3'd1;
    end
end

// ---- state registers (per-share; NEVER mix share 0 and share 1) ----
reg [255:0] aa0, aa1;          // multiplicand A, shifts left (public 0 in)
reg [255:0] bb0, bb1;          // multiplier B, shifts right (public 0 in)
reg [255:0] S0, S1, C0, C1;    // carry-save accumulator
reg [255:0] pp0, pp1;          // registered PP-gadget outputs
wire [255:0] w_pp0, w_pp1;
wire [254:0] w_sc0, w_sc1, w_px0, w_px1;   // top bit not computed (mod 2^256)
wire [254:0] maj0 = w_sc0 ^ w_px0;   // share-local XOR of two gadget outputs
wire [254:0] maj1 = w_sc1 ^ w_px1;   // (same pattern as the adder's g^t)

always @(posedge clk) begin
    if (rst || clr) begin
        aa0 <= 0; aa1 <= 0; bb0 <= 0; bb1 <= 0;
        S0 <= 0; S1 <= 0; C0 <= 0; C1 <= 0; pp0 <= 0; pp1 <= 0;
    end else if (go) begin        // dense-share unpack, share-local
        aa0 <= {a[510], a[508], a[506], a[504], a[502], a[500], a[498], a[496], a[494], a[492], a[490], a[488], a[486], a[484], a[482], a[480], a[478], a[476], a[474], a[472], a[470], a[468], a[466], a[464], a[462], a[460], a[458], a[456], a[454], a[452], a[450], a[448], a[446], a[444], a[442], a[440], a[438], a[436], a[434], a[432], a[430], a[428], a[426], a[424], a[422], a[420], a[418], a[416], a[414], a[412], a[410], a[408], a[406], a[404], a[402], a[400], a[398], a[396], a[394], a[392], a[390], a[388], a[386], a[384], a[382], a[380], a[378], a[376], a[374], a[372], a[370], a[368], a[366], a[364], a[362], a[360], a[358], a[356], a[354], a[352], a[350], a[348], a[346], a[344], a[342], a[340], a[338], a[336], a[334], a[332], a[330], a[328], a[326], a[324], a[322], a[320], a[318], a[316], a[314], a[312], a[310], a[308], a[306], a[304], a[302], a[300], a[298], a[296], a[294], a[292], a[290], a[288], a[286], a[284], a[282], a[280], a[278], a[276], a[274], a[272], a[270], a[268], a[266], a[264], a[262], a[260], a[258], a[256], a[254], a[252], a[250], a[248], a[246], a[244], a[242], a[240], a[238], a[236], a[234], a[232], a[230], a[228], a[226], a[224], a[222], a[220], a[218], a[216], a[214], a[212], a[210], a[208], a[206], a[204], a[202], a[200], a[198], a[196], a[194], a[192], a[190], a[188], a[186], a[184], a[182], a[180], a[178], a[176], a[174], a[172], a[170], a[168], a[166], a[164], a[162], a[160], a[158], a[156], a[154], a[152], a[150], a[148], a[146], a[144], a[142], a[140], a[138], a[136], a[134], a[132], a[130], a[128], a[126], a[124], a[122], a[120], a[118], a[116], a[114], a[112], a[110], a[108], a[106], a[104], a[102], a[100], a[98], a[96], a[94], a[92], a[90], a[88], a[86], a[84], a[82], a[80], a[78], a[76], a[74], a[72], a[70], a[68], a[66], a[64], a[62], a[60], a[58], a[56], a[54], a[52], a[50], a[48], a[46], a[44], a[42], a[40], a[38], a[36], a[34], a[32], a[30], a[28], a[26], a[24], a[22], a[20], a[18], a[16], a[14], a[12], a[10], a[8], a[6], a[4], a[2], a[0]};
        aa1 <= {a[511], a[509], a[507], a[505], a[503], a[501], a[499], a[497], a[495], a[493], a[491], a[489], a[487], a[485], a[483], a[481], a[479], a[477], a[475], a[473], a[471], a[469], a[467], a[465], a[463], a[461], a[459], a[457], a[455], a[453], a[451], a[449], a[447], a[445], a[443], a[441], a[439], a[437], a[435], a[433], a[431], a[429], a[427], a[425], a[423], a[421], a[419], a[417], a[415], a[413], a[411], a[409], a[407], a[405], a[403], a[401], a[399], a[397], a[395], a[393], a[391], a[389], a[387], a[385], a[383], a[381], a[379], a[377], a[375], a[373], a[371], a[369], a[367], a[365], a[363], a[361], a[359], a[357], a[355], a[353], a[351], a[349], a[347], a[345], a[343], a[341], a[339], a[337], a[335], a[333], a[331], a[329], a[327], a[325], a[323], a[321], a[319], a[317], a[315], a[313], a[311], a[309], a[307], a[305], a[303], a[301], a[299], a[297], a[295], a[293], a[291], a[289], a[287], a[285], a[283], a[281], a[279], a[277], a[275], a[273], a[271], a[269], a[267], a[265], a[263], a[261], a[259], a[257], a[255], a[253], a[251], a[249], a[247], a[245], a[243], a[241], a[239], a[237], a[235], a[233], a[231], a[229], a[227], a[225], a[223], a[221], a[219], a[217], a[215], a[213], a[211], a[209], a[207], a[205], a[203], a[201], a[199], a[197], a[195], a[193], a[191], a[189], a[187], a[185], a[183], a[181], a[179], a[177], a[175], a[173], a[171], a[169], a[167], a[165], a[163], a[161], a[159], a[157], a[155], a[153], a[151], a[149], a[147], a[145], a[143], a[141], a[139], a[137], a[135], a[133], a[131], a[129], a[127], a[125], a[123], a[121], a[119], a[117], a[115], a[113], a[111], a[109], a[107], a[105], a[103], a[101], a[99], a[97], a[95], a[93], a[91], a[89], a[87], a[85], a[83], a[81], a[79], a[77], a[75], a[73], a[71], a[69], a[67], a[65], a[63], a[61], a[59], a[57], a[55], a[53], a[51], a[49], a[47], a[45], a[43], a[41], a[39], a[37], a[35], a[33], a[31], a[29], a[27], a[25], a[23], a[21], a[19], a[17], a[15], a[13], a[11], a[9], a[7], a[5], a[3], a[1]};
        bb0 <= {b[510], b[508], b[506], b[504], b[502], b[500], b[498], b[496], b[494], b[492], b[490], b[488], b[486], b[484], b[482], b[480], b[478], b[476], b[474], b[472], b[470], b[468], b[466], b[464], b[462], b[460], b[458], b[456], b[454], b[452], b[450], b[448], b[446], b[444], b[442], b[440], b[438], b[436], b[434], b[432], b[430], b[428], b[426], b[424], b[422], b[420], b[418], b[416], b[414], b[412], b[410], b[408], b[406], b[404], b[402], b[400], b[398], b[396], b[394], b[392], b[390], b[388], b[386], b[384], b[382], b[380], b[378], b[376], b[374], b[372], b[370], b[368], b[366], b[364], b[362], b[360], b[358], b[356], b[354], b[352], b[350], b[348], b[346], b[344], b[342], b[340], b[338], b[336], b[334], b[332], b[330], b[328], b[326], b[324], b[322], b[320], b[318], b[316], b[314], b[312], b[310], b[308], b[306], b[304], b[302], b[300], b[298], b[296], b[294], b[292], b[290], b[288], b[286], b[284], b[282], b[280], b[278], b[276], b[274], b[272], b[270], b[268], b[266], b[264], b[262], b[260], b[258], b[256], b[254], b[252], b[250], b[248], b[246], b[244], b[242], b[240], b[238], b[236], b[234], b[232], b[230], b[228], b[226], b[224], b[222], b[220], b[218], b[216], b[214], b[212], b[210], b[208], b[206], b[204], b[202], b[200], b[198], b[196], b[194], b[192], b[190], b[188], b[186], b[184], b[182], b[180], b[178], b[176], b[174], b[172], b[170], b[168], b[166], b[164], b[162], b[160], b[158], b[156], b[154], b[152], b[150], b[148], b[146], b[144], b[142], b[140], b[138], b[136], b[134], b[132], b[130], b[128], b[126], b[124], b[122], b[120], b[118], b[116], b[114], b[112], b[110], b[108], b[106], b[104], b[102], b[100], b[98], b[96], b[94], b[92], b[90], b[88], b[86], b[84], b[82], b[80], b[78], b[76], b[74], b[72], b[70], b[68], b[66], b[64], b[62], b[60], b[58], b[56], b[54], b[52], b[50], b[48], b[46], b[44], b[42], b[40], b[38], b[36], b[34], b[32], b[30], b[28], b[26], b[24], b[22], b[20], b[18], b[16], b[14], b[12], b[10], b[8], b[6], b[4], b[2], b[0]};
        bb1 <= {b[511], b[509], b[507], b[505], b[503], b[501], b[499], b[497], b[495], b[493], b[491], b[489], b[487], b[485], b[483], b[481], b[479], b[477], b[475], b[473], b[471], b[469], b[467], b[465], b[463], b[461], b[459], b[457], b[455], b[453], b[451], b[449], b[447], b[445], b[443], b[441], b[439], b[437], b[435], b[433], b[431], b[429], b[427], b[425], b[423], b[421], b[419], b[417], b[415], b[413], b[411], b[409], b[407], b[405], b[403], b[401], b[399], b[397], b[395], b[393], b[391], b[389], b[387], b[385], b[383], b[381], b[379], b[377], b[375], b[373], b[371], b[369], b[367], b[365], b[363], b[361], b[359], b[357], b[355], b[353], b[351], b[349], b[347], b[345], b[343], b[341], b[339], b[337], b[335], b[333], b[331], b[329], b[327], b[325], b[323], b[321], b[319], b[317], b[315], b[313], b[311], b[309], b[307], b[305], b[303], b[301], b[299], b[297], b[295], b[293], b[291], b[289], b[287], b[285], b[283], b[281], b[279], b[277], b[275], b[273], b[271], b[269], b[267], b[265], b[263], b[261], b[259], b[257], b[255], b[253], b[251], b[249], b[247], b[245], b[243], b[241], b[239], b[237], b[235], b[233], b[231], b[229], b[227], b[225], b[223], b[221], b[219], b[217], b[215], b[213], b[211], b[209], b[207], b[205], b[203], b[201], b[199], b[197], b[195], b[193], b[191], b[189], b[187], b[185], b[183], b[181], b[179], b[177], b[175], b[173], b[171], b[169], b[167], b[165], b[163], b[161], b[159], b[157], b[155], b[153], b[151], b[149], b[147], b[145], b[143], b[141], b[139], b[137], b[135], b[133], b[131], b[129], b[127], b[125], b[123], b[121], b[119], b[117], b[115], b[113], b[111], b[109], b[107], b[105], b[103], b[101], b[99], b[97], b[95], b[93], b[91], b[89], b[87], b[85], b[83], b[81], b[79], b[77], b[75], b[73], b[71], b[69], b[67], b[65], b[63], b[61], b[59], b[57], b[55], b[53], b[51], b[49], b[47], b[45], b[43], b[41], b[39], b[37], b[35], b[33], b[31], b[29], b[27], b[25], b[23], b[21], b[19], b[17], b[15], b[13], b[11], b[9], b[7], b[5], b[3], b[1]};
        S0 <= 0; S1 <= 0; C0 <= 0; C1 <= 0; pp0 <= 0; pp1 <= 0;
    end else if (running) begin
        if (ph == 3'd3) begin pp0 <= w_pp0; pp1 <= w_pp1; end
        if (ph == 3'd7) begin
            S0 <= S0 ^ C0 ^ pp0;                    // share-local
            S1 <= S1 ^ C1 ^ pp1;
            C0 <= {maj0, 1'b0};                   // <<1 = mod 2^256 accumulate
            C1 <= {maj1, 1'b0};
            aa0 <= {aa0[254:0], 1'b0};          // A <<= 1 (per-share)
            aa1 <= {aa1[254:0], 1'b0};
            bb0 <= {1'b0, bb0[255:1]};          // B >>= 1 (per-share)
            bb1 <= {1'b0, bb1[255:1]};
        end
    end
end

// ---- 1-cycle per-share balance registers: every gadget ina arrives one
// cycle after its inb (gadget contract ina@1/inb@0 — the iszero256 pattern).
// Unconditional, so they drain by themselves one cycle after clr.
reg [255:0] aa_d0, aa_d1;      // ina of u_pp_*  (inb = bbit)
reg [255:0] c_d0, c_d1;        // ina of u_sc_*  (inb = S)
reg [255:0] x_d0, x_d1;        // ina of u_px_*  (inb = pp); x = S^C share-local
reg [255:0] S_d0, S_d1;        // final adder operand a := delayed S (b := C)
always @(posedge clk) begin
    aa_d0 <= aa0;       aa_d1 <= aa1;
    c_d0  <= C0;        c_d1  <= C1;
    x_d0  <= S0 ^ C0;   x_d1  <= S1 ^ C1;
    S_d0  <= S0;        S_d1  <= S1;
end


// ===== PP gating: PP[j] = aa[j] AND bbit  (bbit = current B bit, both shares fan out) =====
MSKand_opini2_d2_pini u_pp_0 (
    .ina({aa_d1[0], aa_d0[0]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[0]), .s(s[0]), .clk(clk), .out({w_pp1[0], w_pp0[0]}));
MSKand_opini2_d2_pini u_pp_1 (
    .ina({aa_d1[1], aa_d0[1]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[1]), .s(s[1]), .clk(clk), .out({w_pp1[1], w_pp0[1]}));
MSKand_opini2_d2_pini u_pp_2 (
    .ina({aa_d1[2], aa_d0[2]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[2]), .s(s[2]), .clk(clk), .out({w_pp1[2], w_pp0[2]}));
MSKand_opini2_d2_pini u_pp_3 (
    .ina({aa_d1[3], aa_d0[3]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[3]), .s(s[3]), .clk(clk), .out({w_pp1[3], w_pp0[3]}));
MSKand_opini2_d2_pini u_pp_4 (
    .ina({aa_d1[4], aa_d0[4]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[4]), .s(s[4]), .clk(clk), .out({w_pp1[4], w_pp0[4]}));
MSKand_opini2_d2_pini u_pp_5 (
    .ina({aa_d1[5], aa_d0[5]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[5]), .s(s[5]), .clk(clk), .out({w_pp1[5], w_pp0[5]}));
MSKand_opini2_d2_pini u_pp_6 (
    .ina({aa_d1[6], aa_d0[6]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[6]), .s(s[6]), .clk(clk), .out({w_pp1[6], w_pp0[6]}));
MSKand_opini2_d2_pini u_pp_7 (
    .ina({aa_d1[7], aa_d0[7]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[7]), .s(s[7]), .clk(clk), .out({w_pp1[7], w_pp0[7]}));
MSKand_opini2_d2_pini u_pp_8 (
    .ina({aa_d1[8], aa_d0[8]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[8]), .s(s[8]), .clk(clk), .out({w_pp1[8], w_pp0[8]}));
MSKand_opini2_d2_pini u_pp_9 (
    .ina({aa_d1[9], aa_d0[9]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[9]), .s(s[9]), .clk(clk), .out({w_pp1[9], w_pp0[9]}));
MSKand_opini2_d2_pini u_pp_10 (
    .ina({aa_d1[10], aa_d0[10]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[10]), .s(s[10]), .clk(clk), .out({w_pp1[10], w_pp0[10]}));
MSKand_opini2_d2_pini u_pp_11 (
    .ina({aa_d1[11], aa_d0[11]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[11]), .s(s[11]), .clk(clk), .out({w_pp1[11], w_pp0[11]}));
MSKand_opini2_d2_pini u_pp_12 (
    .ina({aa_d1[12], aa_d0[12]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[12]), .s(s[12]), .clk(clk), .out({w_pp1[12], w_pp0[12]}));
MSKand_opini2_d2_pini u_pp_13 (
    .ina({aa_d1[13], aa_d0[13]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[13]), .s(s[13]), .clk(clk), .out({w_pp1[13], w_pp0[13]}));
MSKand_opini2_d2_pini u_pp_14 (
    .ina({aa_d1[14], aa_d0[14]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[14]), .s(s[14]), .clk(clk), .out({w_pp1[14], w_pp0[14]}));
MSKand_opini2_d2_pini u_pp_15 (
    .ina({aa_d1[15], aa_d0[15]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[15]), .s(s[15]), .clk(clk), .out({w_pp1[15], w_pp0[15]}));
MSKand_opini2_d2_pini u_pp_16 (
    .ina({aa_d1[16], aa_d0[16]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[16]), .s(s[16]), .clk(clk), .out({w_pp1[16], w_pp0[16]}));
MSKand_opini2_d2_pini u_pp_17 (
    .ina({aa_d1[17], aa_d0[17]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[17]), .s(s[17]), .clk(clk), .out({w_pp1[17], w_pp0[17]}));
MSKand_opini2_d2_pini u_pp_18 (
    .ina({aa_d1[18], aa_d0[18]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[18]), .s(s[18]), .clk(clk), .out({w_pp1[18], w_pp0[18]}));
MSKand_opini2_d2_pini u_pp_19 (
    .ina({aa_d1[19], aa_d0[19]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[19]), .s(s[19]), .clk(clk), .out({w_pp1[19], w_pp0[19]}));
MSKand_opini2_d2_pini u_pp_20 (
    .ina({aa_d1[20], aa_d0[20]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[20]), .s(s[20]), .clk(clk), .out({w_pp1[20], w_pp0[20]}));
MSKand_opini2_d2_pini u_pp_21 (
    .ina({aa_d1[21], aa_d0[21]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[21]), .s(s[21]), .clk(clk), .out({w_pp1[21], w_pp0[21]}));
MSKand_opini2_d2_pini u_pp_22 (
    .ina({aa_d1[22], aa_d0[22]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[22]), .s(s[22]), .clk(clk), .out({w_pp1[22], w_pp0[22]}));
MSKand_opini2_d2_pini u_pp_23 (
    .ina({aa_d1[23], aa_d0[23]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[23]), .s(s[23]), .clk(clk), .out({w_pp1[23], w_pp0[23]}));
MSKand_opini2_d2_pini u_pp_24 (
    .ina({aa_d1[24], aa_d0[24]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[24]), .s(s[24]), .clk(clk), .out({w_pp1[24], w_pp0[24]}));
MSKand_opini2_d2_pini u_pp_25 (
    .ina({aa_d1[25], aa_d0[25]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[25]), .s(s[25]), .clk(clk), .out({w_pp1[25], w_pp0[25]}));
MSKand_opini2_d2_pini u_pp_26 (
    .ina({aa_d1[26], aa_d0[26]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[26]), .s(s[26]), .clk(clk), .out({w_pp1[26], w_pp0[26]}));
MSKand_opini2_d2_pini u_pp_27 (
    .ina({aa_d1[27], aa_d0[27]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[27]), .s(s[27]), .clk(clk), .out({w_pp1[27], w_pp0[27]}));
MSKand_opini2_d2_pini u_pp_28 (
    .ina({aa_d1[28], aa_d0[28]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[28]), .s(s[28]), .clk(clk), .out({w_pp1[28], w_pp0[28]}));
MSKand_opini2_d2_pini u_pp_29 (
    .ina({aa_d1[29], aa_d0[29]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[29]), .s(s[29]), .clk(clk), .out({w_pp1[29], w_pp0[29]}));
MSKand_opini2_d2_pini u_pp_30 (
    .ina({aa_d1[30], aa_d0[30]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[30]), .s(s[30]), .clk(clk), .out({w_pp1[30], w_pp0[30]}));
MSKand_opini2_d2_pini u_pp_31 (
    .ina({aa_d1[31], aa_d0[31]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[31]), .s(s[31]), .clk(clk), .out({w_pp1[31], w_pp0[31]}));
MSKand_opini2_d2_pini u_pp_32 (
    .ina({aa_d1[32], aa_d0[32]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[32]), .s(s[32]), .clk(clk), .out({w_pp1[32], w_pp0[32]}));
MSKand_opini2_d2_pini u_pp_33 (
    .ina({aa_d1[33], aa_d0[33]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[33]), .s(s[33]), .clk(clk), .out({w_pp1[33], w_pp0[33]}));
MSKand_opini2_d2_pini u_pp_34 (
    .ina({aa_d1[34], aa_d0[34]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[34]), .s(s[34]), .clk(clk), .out({w_pp1[34], w_pp0[34]}));
MSKand_opini2_d2_pini u_pp_35 (
    .ina({aa_d1[35], aa_d0[35]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[35]), .s(s[35]), .clk(clk), .out({w_pp1[35], w_pp0[35]}));
MSKand_opini2_d2_pini u_pp_36 (
    .ina({aa_d1[36], aa_d0[36]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[36]), .s(s[36]), .clk(clk), .out({w_pp1[36], w_pp0[36]}));
MSKand_opini2_d2_pini u_pp_37 (
    .ina({aa_d1[37], aa_d0[37]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[37]), .s(s[37]), .clk(clk), .out({w_pp1[37], w_pp0[37]}));
MSKand_opini2_d2_pini u_pp_38 (
    .ina({aa_d1[38], aa_d0[38]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[38]), .s(s[38]), .clk(clk), .out({w_pp1[38], w_pp0[38]}));
MSKand_opini2_d2_pini u_pp_39 (
    .ina({aa_d1[39], aa_d0[39]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[39]), .s(s[39]), .clk(clk), .out({w_pp1[39], w_pp0[39]}));
MSKand_opini2_d2_pini u_pp_40 (
    .ina({aa_d1[40], aa_d0[40]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[40]), .s(s[40]), .clk(clk), .out({w_pp1[40], w_pp0[40]}));
MSKand_opini2_d2_pini u_pp_41 (
    .ina({aa_d1[41], aa_d0[41]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[41]), .s(s[41]), .clk(clk), .out({w_pp1[41], w_pp0[41]}));
MSKand_opini2_d2_pini u_pp_42 (
    .ina({aa_d1[42], aa_d0[42]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[42]), .s(s[42]), .clk(clk), .out({w_pp1[42], w_pp0[42]}));
MSKand_opini2_d2_pini u_pp_43 (
    .ina({aa_d1[43], aa_d0[43]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[43]), .s(s[43]), .clk(clk), .out({w_pp1[43], w_pp0[43]}));
MSKand_opini2_d2_pini u_pp_44 (
    .ina({aa_d1[44], aa_d0[44]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[44]), .s(s[44]), .clk(clk), .out({w_pp1[44], w_pp0[44]}));
MSKand_opini2_d2_pini u_pp_45 (
    .ina({aa_d1[45], aa_d0[45]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[45]), .s(s[45]), .clk(clk), .out({w_pp1[45], w_pp0[45]}));
MSKand_opini2_d2_pini u_pp_46 (
    .ina({aa_d1[46], aa_d0[46]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[46]), .s(s[46]), .clk(clk), .out({w_pp1[46], w_pp0[46]}));
MSKand_opini2_d2_pini u_pp_47 (
    .ina({aa_d1[47], aa_d0[47]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[47]), .s(s[47]), .clk(clk), .out({w_pp1[47], w_pp0[47]}));
MSKand_opini2_d2_pini u_pp_48 (
    .ina({aa_d1[48], aa_d0[48]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[48]), .s(s[48]), .clk(clk), .out({w_pp1[48], w_pp0[48]}));
MSKand_opini2_d2_pini u_pp_49 (
    .ina({aa_d1[49], aa_d0[49]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[49]), .s(s[49]), .clk(clk), .out({w_pp1[49], w_pp0[49]}));
MSKand_opini2_d2_pini u_pp_50 (
    .ina({aa_d1[50], aa_d0[50]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[50]), .s(s[50]), .clk(clk), .out({w_pp1[50], w_pp0[50]}));
MSKand_opini2_d2_pini u_pp_51 (
    .ina({aa_d1[51], aa_d0[51]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[51]), .s(s[51]), .clk(clk), .out({w_pp1[51], w_pp0[51]}));
MSKand_opini2_d2_pini u_pp_52 (
    .ina({aa_d1[52], aa_d0[52]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[52]), .s(s[52]), .clk(clk), .out({w_pp1[52], w_pp0[52]}));
MSKand_opini2_d2_pini u_pp_53 (
    .ina({aa_d1[53], aa_d0[53]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[53]), .s(s[53]), .clk(clk), .out({w_pp1[53], w_pp0[53]}));
MSKand_opini2_d2_pini u_pp_54 (
    .ina({aa_d1[54], aa_d0[54]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[54]), .s(s[54]), .clk(clk), .out({w_pp1[54], w_pp0[54]}));
MSKand_opini2_d2_pini u_pp_55 (
    .ina({aa_d1[55], aa_d0[55]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[55]), .s(s[55]), .clk(clk), .out({w_pp1[55], w_pp0[55]}));
MSKand_opini2_d2_pini u_pp_56 (
    .ina({aa_d1[56], aa_d0[56]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[56]), .s(s[56]), .clk(clk), .out({w_pp1[56], w_pp0[56]}));
MSKand_opini2_d2_pini u_pp_57 (
    .ina({aa_d1[57], aa_d0[57]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[57]), .s(s[57]), .clk(clk), .out({w_pp1[57], w_pp0[57]}));
MSKand_opini2_d2_pini u_pp_58 (
    .ina({aa_d1[58], aa_d0[58]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[58]), .s(s[58]), .clk(clk), .out({w_pp1[58], w_pp0[58]}));
MSKand_opini2_d2_pini u_pp_59 (
    .ina({aa_d1[59], aa_d0[59]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[59]), .s(s[59]), .clk(clk), .out({w_pp1[59], w_pp0[59]}));
MSKand_opini2_d2_pini u_pp_60 (
    .ina({aa_d1[60], aa_d0[60]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[60]), .s(s[60]), .clk(clk), .out({w_pp1[60], w_pp0[60]}));
MSKand_opini2_d2_pini u_pp_61 (
    .ina({aa_d1[61], aa_d0[61]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[61]), .s(s[61]), .clk(clk), .out({w_pp1[61], w_pp0[61]}));
MSKand_opini2_d2_pini u_pp_62 (
    .ina({aa_d1[62], aa_d0[62]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[62]), .s(s[62]), .clk(clk), .out({w_pp1[62], w_pp0[62]}));
MSKand_opini2_d2_pini u_pp_63 (
    .ina({aa_d1[63], aa_d0[63]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[63]), .s(s[63]), .clk(clk), .out({w_pp1[63], w_pp0[63]}));
MSKand_opini2_d2_pini u_pp_64 (
    .ina({aa_d1[64], aa_d0[64]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[64]), .s(s[64]), .clk(clk), .out({w_pp1[64], w_pp0[64]}));
MSKand_opini2_d2_pini u_pp_65 (
    .ina({aa_d1[65], aa_d0[65]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[65]), .s(s[65]), .clk(clk), .out({w_pp1[65], w_pp0[65]}));
MSKand_opini2_d2_pini u_pp_66 (
    .ina({aa_d1[66], aa_d0[66]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[66]), .s(s[66]), .clk(clk), .out({w_pp1[66], w_pp0[66]}));
MSKand_opini2_d2_pini u_pp_67 (
    .ina({aa_d1[67], aa_d0[67]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[67]), .s(s[67]), .clk(clk), .out({w_pp1[67], w_pp0[67]}));
MSKand_opini2_d2_pini u_pp_68 (
    .ina({aa_d1[68], aa_d0[68]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[68]), .s(s[68]), .clk(clk), .out({w_pp1[68], w_pp0[68]}));
MSKand_opini2_d2_pini u_pp_69 (
    .ina({aa_d1[69], aa_d0[69]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[69]), .s(s[69]), .clk(clk), .out({w_pp1[69], w_pp0[69]}));
MSKand_opini2_d2_pini u_pp_70 (
    .ina({aa_d1[70], aa_d0[70]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[70]), .s(s[70]), .clk(clk), .out({w_pp1[70], w_pp0[70]}));
MSKand_opini2_d2_pini u_pp_71 (
    .ina({aa_d1[71], aa_d0[71]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[71]), .s(s[71]), .clk(clk), .out({w_pp1[71], w_pp0[71]}));
MSKand_opini2_d2_pini u_pp_72 (
    .ina({aa_d1[72], aa_d0[72]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[72]), .s(s[72]), .clk(clk), .out({w_pp1[72], w_pp0[72]}));
MSKand_opini2_d2_pini u_pp_73 (
    .ina({aa_d1[73], aa_d0[73]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[73]), .s(s[73]), .clk(clk), .out({w_pp1[73], w_pp0[73]}));
MSKand_opini2_d2_pini u_pp_74 (
    .ina({aa_d1[74], aa_d0[74]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[74]), .s(s[74]), .clk(clk), .out({w_pp1[74], w_pp0[74]}));
MSKand_opini2_d2_pini u_pp_75 (
    .ina({aa_d1[75], aa_d0[75]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[75]), .s(s[75]), .clk(clk), .out({w_pp1[75], w_pp0[75]}));
MSKand_opini2_d2_pini u_pp_76 (
    .ina({aa_d1[76], aa_d0[76]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[76]), .s(s[76]), .clk(clk), .out({w_pp1[76], w_pp0[76]}));
MSKand_opini2_d2_pini u_pp_77 (
    .ina({aa_d1[77], aa_d0[77]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[77]), .s(s[77]), .clk(clk), .out({w_pp1[77], w_pp0[77]}));
MSKand_opini2_d2_pini u_pp_78 (
    .ina({aa_d1[78], aa_d0[78]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[78]), .s(s[78]), .clk(clk), .out({w_pp1[78], w_pp0[78]}));
MSKand_opini2_d2_pini u_pp_79 (
    .ina({aa_d1[79], aa_d0[79]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[79]), .s(s[79]), .clk(clk), .out({w_pp1[79], w_pp0[79]}));
MSKand_opini2_d2_pini u_pp_80 (
    .ina({aa_d1[80], aa_d0[80]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[80]), .s(s[80]), .clk(clk), .out({w_pp1[80], w_pp0[80]}));
MSKand_opini2_d2_pini u_pp_81 (
    .ina({aa_d1[81], aa_d0[81]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[81]), .s(s[81]), .clk(clk), .out({w_pp1[81], w_pp0[81]}));
MSKand_opini2_d2_pini u_pp_82 (
    .ina({aa_d1[82], aa_d0[82]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[82]), .s(s[82]), .clk(clk), .out({w_pp1[82], w_pp0[82]}));
MSKand_opini2_d2_pini u_pp_83 (
    .ina({aa_d1[83], aa_d0[83]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[83]), .s(s[83]), .clk(clk), .out({w_pp1[83], w_pp0[83]}));
MSKand_opini2_d2_pini u_pp_84 (
    .ina({aa_d1[84], aa_d0[84]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[84]), .s(s[84]), .clk(clk), .out({w_pp1[84], w_pp0[84]}));
MSKand_opini2_d2_pini u_pp_85 (
    .ina({aa_d1[85], aa_d0[85]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[85]), .s(s[85]), .clk(clk), .out({w_pp1[85], w_pp0[85]}));
MSKand_opini2_d2_pini u_pp_86 (
    .ina({aa_d1[86], aa_d0[86]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[86]), .s(s[86]), .clk(clk), .out({w_pp1[86], w_pp0[86]}));
MSKand_opini2_d2_pini u_pp_87 (
    .ina({aa_d1[87], aa_d0[87]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[87]), .s(s[87]), .clk(clk), .out({w_pp1[87], w_pp0[87]}));
MSKand_opini2_d2_pini u_pp_88 (
    .ina({aa_d1[88], aa_d0[88]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[88]), .s(s[88]), .clk(clk), .out({w_pp1[88], w_pp0[88]}));
MSKand_opini2_d2_pini u_pp_89 (
    .ina({aa_d1[89], aa_d0[89]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[89]), .s(s[89]), .clk(clk), .out({w_pp1[89], w_pp0[89]}));
MSKand_opini2_d2_pini u_pp_90 (
    .ina({aa_d1[90], aa_d0[90]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[90]), .s(s[90]), .clk(clk), .out({w_pp1[90], w_pp0[90]}));
MSKand_opini2_d2_pini u_pp_91 (
    .ina({aa_d1[91], aa_d0[91]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[91]), .s(s[91]), .clk(clk), .out({w_pp1[91], w_pp0[91]}));
MSKand_opini2_d2_pini u_pp_92 (
    .ina({aa_d1[92], aa_d0[92]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[92]), .s(s[92]), .clk(clk), .out({w_pp1[92], w_pp0[92]}));
MSKand_opini2_d2_pini u_pp_93 (
    .ina({aa_d1[93], aa_d0[93]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[93]), .s(s[93]), .clk(clk), .out({w_pp1[93], w_pp0[93]}));
MSKand_opini2_d2_pini u_pp_94 (
    .ina({aa_d1[94], aa_d0[94]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[94]), .s(s[94]), .clk(clk), .out({w_pp1[94], w_pp0[94]}));
MSKand_opini2_d2_pini u_pp_95 (
    .ina({aa_d1[95], aa_d0[95]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[95]), .s(s[95]), .clk(clk), .out({w_pp1[95], w_pp0[95]}));
MSKand_opini2_d2_pini u_pp_96 (
    .ina({aa_d1[96], aa_d0[96]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[96]), .s(s[96]), .clk(clk), .out({w_pp1[96], w_pp0[96]}));
MSKand_opini2_d2_pini u_pp_97 (
    .ina({aa_d1[97], aa_d0[97]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[97]), .s(s[97]), .clk(clk), .out({w_pp1[97], w_pp0[97]}));
MSKand_opini2_d2_pini u_pp_98 (
    .ina({aa_d1[98], aa_d0[98]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[98]), .s(s[98]), .clk(clk), .out({w_pp1[98], w_pp0[98]}));
MSKand_opini2_d2_pini u_pp_99 (
    .ina({aa_d1[99], aa_d0[99]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[99]), .s(s[99]), .clk(clk), .out({w_pp1[99], w_pp0[99]}));
MSKand_opini2_d2_pini u_pp_100 (
    .ina({aa_d1[100], aa_d0[100]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[100]), .s(s[100]), .clk(clk), .out({w_pp1[100], w_pp0[100]}));
MSKand_opini2_d2_pini u_pp_101 (
    .ina({aa_d1[101], aa_d0[101]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[101]), .s(s[101]), .clk(clk), .out({w_pp1[101], w_pp0[101]}));
MSKand_opini2_d2_pini u_pp_102 (
    .ina({aa_d1[102], aa_d0[102]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[102]), .s(s[102]), .clk(clk), .out({w_pp1[102], w_pp0[102]}));
MSKand_opini2_d2_pini u_pp_103 (
    .ina({aa_d1[103], aa_d0[103]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[103]), .s(s[103]), .clk(clk), .out({w_pp1[103], w_pp0[103]}));
MSKand_opini2_d2_pini u_pp_104 (
    .ina({aa_d1[104], aa_d0[104]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[104]), .s(s[104]), .clk(clk), .out({w_pp1[104], w_pp0[104]}));
MSKand_opini2_d2_pini u_pp_105 (
    .ina({aa_d1[105], aa_d0[105]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[105]), .s(s[105]), .clk(clk), .out({w_pp1[105], w_pp0[105]}));
MSKand_opini2_d2_pini u_pp_106 (
    .ina({aa_d1[106], aa_d0[106]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[106]), .s(s[106]), .clk(clk), .out({w_pp1[106], w_pp0[106]}));
MSKand_opini2_d2_pini u_pp_107 (
    .ina({aa_d1[107], aa_d0[107]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[107]), .s(s[107]), .clk(clk), .out({w_pp1[107], w_pp0[107]}));
MSKand_opini2_d2_pini u_pp_108 (
    .ina({aa_d1[108], aa_d0[108]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[108]), .s(s[108]), .clk(clk), .out({w_pp1[108], w_pp0[108]}));
MSKand_opini2_d2_pini u_pp_109 (
    .ina({aa_d1[109], aa_d0[109]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[109]), .s(s[109]), .clk(clk), .out({w_pp1[109], w_pp0[109]}));
MSKand_opini2_d2_pini u_pp_110 (
    .ina({aa_d1[110], aa_d0[110]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[110]), .s(s[110]), .clk(clk), .out({w_pp1[110], w_pp0[110]}));
MSKand_opini2_d2_pini u_pp_111 (
    .ina({aa_d1[111], aa_d0[111]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[111]), .s(s[111]), .clk(clk), .out({w_pp1[111], w_pp0[111]}));
MSKand_opini2_d2_pini u_pp_112 (
    .ina({aa_d1[112], aa_d0[112]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[112]), .s(s[112]), .clk(clk), .out({w_pp1[112], w_pp0[112]}));
MSKand_opini2_d2_pini u_pp_113 (
    .ina({aa_d1[113], aa_d0[113]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[113]), .s(s[113]), .clk(clk), .out({w_pp1[113], w_pp0[113]}));
MSKand_opini2_d2_pini u_pp_114 (
    .ina({aa_d1[114], aa_d0[114]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[114]), .s(s[114]), .clk(clk), .out({w_pp1[114], w_pp0[114]}));
MSKand_opini2_d2_pini u_pp_115 (
    .ina({aa_d1[115], aa_d0[115]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[115]), .s(s[115]), .clk(clk), .out({w_pp1[115], w_pp0[115]}));
MSKand_opini2_d2_pini u_pp_116 (
    .ina({aa_d1[116], aa_d0[116]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[116]), .s(s[116]), .clk(clk), .out({w_pp1[116], w_pp0[116]}));
MSKand_opini2_d2_pini u_pp_117 (
    .ina({aa_d1[117], aa_d0[117]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[117]), .s(s[117]), .clk(clk), .out({w_pp1[117], w_pp0[117]}));
MSKand_opini2_d2_pini u_pp_118 (
    .ina({aa_d1[118], aa_d0[118]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[118]), .s(s[118]), .clk(clk), .out({w_pp1[118], w_pp0[118]}));
MSKand_opini2_d2_pini u_pp_119 (
    .ina({aa_d1[119], aa_d0[119]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[119]), .s(s[119]), .clk(clk), .out({w_pp1[119], w_pp0[119]}));
MSKand_opini2_d2_pini u_pp_120 (
    .ina({aa_d1[120], aa_d0[120]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[120]), .s(s[120]), .clk(clk), .out({w_pp1[120], w_pp0[120]}));
MSKand_opini2_d2_pini u_pp_121 (
    .ina({aa_d1[121], aa_d0[121]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[121]), .s(s[121]), .clk(clk), .out({w_pp1[121], w_pp0[121]}));
MSKand_opini2_d2_pini u_pp_122 (
    .ina({aa_d1[122], aa_d0[122]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[122]), .s(s[122]), .clk(clk), .out({w_pp1[122], w_pp0[122]}));
MSKand_opini2_d2_pini u_pp_123 (
    .ina({aa_d1[123], aa_d0[123]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[123]), .s(s[123]), .clk(clk), .out({w_pp1[123], w_pp0[123]}));
MSKand_opini2_d2_pini u_pp_124 (
    .ina({aa_d1[124], aa_d0[124]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[124]), .s(s[124]), .clk(clk), .out({w_pp1[124], w_pp0[124]}));
MSKand_opini2_d2_pini u_pp_125 (
    .ina({aa_d1[125], aa_d0[125]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[125]), .s(s[125]), .clk(clk), .out({w_pp1[125], w_pp0[125]}));
MSKand_opini2_d2_pini u_pp_126 (
    .ina({aa_d1[126], aa_d0[126]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[126]), .s(s[126]), .clk(clk), .out({w_pp1[126], w_pp0[126]}));
MSKand_opini2_d2_pini u_pp_127 (
    .ina({aa_d1[127], aa_d0[127]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[127]), .s(s[127]), .clk(clk), .out({w_pp1[127], w_pp0[127]}));
MSKand_opini2_d2_pini u_pp_128 (
    .ina({aa_d1[128], aa_d0[128]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[128]), .s(s[128]), .clk(clk), .out({w_pp1[128], w_pp0[128]}));
MSKand_opini2_d2_pini u_pp_129 (
    .ina({aa_d1[129], aa_d0[129]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[129]), .s(s[129]), .clk(clk), .out({w_pp1[129], w_pp0[129]}));
MSKand_opini2_d2_pini u_pp_130 (
    .ina({aa_d1[130], aa_d0[130]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[130]), .s(s[130]), .clk(clk), .out({w_pp1[130], w_pp0[130]}));
MSKand_opini2_d2_pini u_pp_131 (
    .ina({aa_d1[131], aa_d0[131]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[131]), .s(s[131]), .clk(clk), .out({w_pp1[131], w_pp0[131]}));
MSKand_opini2_d2_pini u_pp_132 (
    .ina({aa_d1[132], aa_d0[132]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[132]), .s(s[132]), .clk(clk), .out({w_pp1[132], w_pp0[132]}));
MSKand_opini2_d2_pini u_pp_133 (
    .ina({aa_d1[133], aa_d0[133]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[133]), .s(s[133]), .clk(clk), .out({w_pp1[133], w_pp0[133]}));
MSKand_opini2_d2_pini u_pp_134 (
    .ina({aa_d1[134], aa_d0[134]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[134]), .s(s[134]), .clk(clk), .out({w_pp1[134], w_pp0[134]}));
MSKand_opini2_d2_pini u_pp_135 (
    .ina({aa_d1[135], aa_d0[135]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[135]), .s(s[135]), .clk(clk), .out({w_pp1[135], w_pp0[135]}));
MSKand_opini2_d2_pini u_pp_136 (
    .ina({aa_d1[136], aa_d0[136]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[136]), .s(s[136]), .clk(clk), .out({w_pp1[136], w_pp0[136]}));
MSKand_opini2_d2_pini u_pp_137 (
    .ina({aa_d1[137], aa_d0[137]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[137]), .s(s[137]), .clk(clk), .out({w_pp1[137], w_pp0[137]}));
MSKand_opini2_d2_pini u_pp_138 (
    .ina({aa_d1[138], aa_d0[138]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[138]), .s(s[138]), .clk(clk), .out({w_pp1[138], w_pp0[138]}));
MSKand_opini2_d2_pini u_pp_139 (
    .ina({aa_d1[139], aa_d0[139]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[139]), .s(s[139]), .clk(clk), .out({w_pp1[139], w_pp0[139]}));
MSKand_opini2_d2_pini u_pp_140 (
    .ina({aa_d1[140], aa_d0[140]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[140]), .s(s[140]), .clk(clk), .out({w_pp1[140], w_pp0[140]}));
MSKand_opini2_d2_pini u_pp_141 (
    .ina({aa_d1[141], aa_d0[141]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[141]), .s(s[141]), .clk(clk), .out({w_pp1[141], w_pp0[141]}));
MSKand_opini2_d2_pini u_pp_142 (
    .ina({aa_d1[142], aa_d0[142]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[142]), .s(s[142]), .clk(clk), .out({w_pp1[142], w_pp0[142]}));
MSKand_opini2_d2_pini u_pp_143 (
    .ina({aa_d1[143], aa_d0[143]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[143]), .s(s[143]), .clk(clk), .out({w_pp1[143], w_pp0[143]}));
MSKand_opini2_d2_pini u_pp_144 (
    .ina({aa_d1[144], aa_d0[144]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[144]), .s(s[144]), .clk(clk), .out({w_pp1[144], w_pp0[144]}));
MSKand_opini2_d2_pini u_pp_145 (
    .ina({aa_d1[145], aa_d0[145]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[145]), .s(s[145]), .clk(clk), .out({w_pp1[145], w_pp0[145]}));
MSKand_opini2_d2_pini u_pp_146 (
    .ina({aa_d1[146], aa_d0[146]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[146]), .s(s[146]), .clk(clk), .out({w_pp1[146], w_pp0[146]}));
MSKand_opini2_d2_pini u_pp_147 (
    .ina({aa_d1[147], aa_d0[147]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[147]), .s(s[147]), .clk(clk), .out({w_pp1[147], w_pp0[147]}));
MSKand_opini2_d2_pini u_pp_148 (
    .ina({aa_d1[148], aa_d0[148]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[148]), .s(s[148]), .clk(clk), .out({w_pp1[148], w_pp0[148]}));
MSKand_opini2_d2_pini u_pp_149 (
    .ina({aa_d1[149], aa_d0[149]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[149]), .s(s[149]), .clk(clk), .out({w_pp1[149], w_pp0[149]}));
MSKand_opini2_d2_pini u_pp_150 (
    .ina({aa_d1[150], aa_d0[150]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[150]), .s(s[150]), .clk(clk), .out({w_pp1[150], w_pp0[150]}));
MSKand_opini2_d2_pini u_pp_151 (
    .ina({aa_d1[151], aa_d0[151]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[151]), .s(s[151]), .clk(clk), .out({w_pp1[151], w_pp0[151]}));
MSKand_opini2_d2_pini u_pp_152 (
    .ina({aa_d1[152], aa_d0[152]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[152]), .s(s[152]), .clk(clk), .out({w_pp1[152], w_pp0[152]}));
MSKand_opini2_d2_pini u_pp_153 (
    .ina({aa_d1[153], aa_d0[153]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[153]), .s(s[153]), .clk(clk), .out({w_pp1[153], w_pp0[153]}));
MSKand_opini2_d2_pini u_pp_154 (
    .ina({aa_d1[154], aa_d0[154]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[154]), .s(s[154]), .clk(clk), .out({w_pp1[154], w_pp0[154]}));
MSKand_opini2_d2_pini u_pp_155 (
    .ina({aa_d1[155], aa_d0[155]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[155]), .s(s[155]), .clk(clk), .out({w_pp1[155], w_pp0[155]}));
MSKand_opini2_d2_pini u_pp_156 (
    .ina({aa_d1[156], aa_d0[156]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[156]), .s(s[156]), .clk(clk), .out({w_pp1[156], w_pp0[156]}));
MSKand_opini2_d2_pini u_pp_157 (
    .ina({aa_d1[157], aa_d0[157]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[157]), .s(s[157]), .clk(clk), .out({w_pp1[157], w_pp0[157]}));
MSKand_opini2_d2_pini u_pp_158 (
    .ina({aa_d1[158], aa_d0[158]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[158]), .s(s[158]), .clk(clk), .out({w_pp1[158], w_pp0[158]}));
MSKand_opini2_d2_pini u_pp_159 (
    .ina({aa_d1[159], aa_d0[159]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[159]), .s(s[159]), .clk(clk), .out({w_pp1[159], w_pp0[159]}));
MSKand_opini2_d2_pini u_pp_160 (
    .ina({aa_d1[160], aa_d0[160]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[160]), .s(s[160]), .clk(clk), .out({w_pp1[160], w_pp0[160]}));
MSKand_opini2_d2_pini u_pp_161 (
    .ina({aa_d1[161], aa_d0[161]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[161]), .s(s[161]), .clk(clk), .out({w_pp1[161], w_pp0[161]}));
MSKand_opini2_d2_pini u_pp_162 (
    .ina({aa_d1[162], aa_d0[162]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[162]), .s(s[162]), .clk(clk), .out({w_pp1[162], w_pp0[162]}));
MSKand_opini2_d2_pini u_pp_163 (
    .ina({aa_d1[163], aa_d0[163]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[163]), .s(s[163]), .clk(clk), .out({w_pp1[163], w_pp0[163]}));
MSKand_opini2_d2_pini u_pp_164 (
    .ina({aa_d1[164], aa_d0[164]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[164]), .s(s[164]), .clk(clk), .out({w_pp1[164], w_pp0[164]}));
MSKand_opini2_d2_pini u_pp_165 (
    .ina({aa_d1[165], aa_d0[165]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[165]), .s(s[165]), .clk(clk), .out({w_pp1[165], w_pp0[165]}));
MSKand_opini2_d2_pini u_pp_166 (
    .ina({aa_d1[166], aa_d0[166]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[166]), .s(s[166]), .clk(clk), .out({w_pp1[166], w_pp0[166]}));
MSKand_opini2_d2_pini u_pp_167 (
    .ina({aa_d1[167], aa_d0[167]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[167]), .s(s[167]), .clk(clk), .out({w_pp1[167], w_pp0[167]}));
MSKand_opini2_d2_pini u_pp_168 (
    .ina({aa_d1[168], aa_d0[168]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[168]), .s(s[168]), .clk(clk), .out({w_pp1[168], w_pp0[168]}));
MSKand_opini2_d2_pini u_pp_169 (
    .ina({aa_d1[169], aa_d0[169]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[169]), .s(s[169]), .clk(clk), .out({w_pp1[169], w_pp0[169]}));
MSKand_opini2_d2_pini u_pp_170 (
    .ina({aa_d1[170], aa_d0[170]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[170]), .s(s[170]), .clk(clk), .out({w_pp1[170], w_pp0[170]}));
MSKand_opini2_d2_pini u_pp_171 (
    .ina({aa_d1[171], aa_d0[171]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[171]), .s(s[171]), .clk(clk), .out({w_pp1[171], w_pp0[171]}));
MSKand_opini2_d2_pini u_pp_172 (
    .ina({aa_d1[172], aa_d0[172]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[172]), .s(s[172]), .clk(clk), .out({w_pp1[172], w_pp0[172]}));
MSKand_opini2_d2_pini u_pp_173 (
    .ina({aa_d1[173], aa_d0[173]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[173]), .s(s[173]), .clk(clk), .out({w_pp1[173], w_pp0[173]}));
MSKand_opini2_d2_pini u_pp_174 (
    .ina({aa_d1[174], aa_d0[174]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[174]), .s(s[174]), .clk(clk), .out({w_pp1[174], w_pp0[174]}));
MSKand_opini2_d2_pini u_pp_175 (
    .ina({aa_d1[175], aa_d0[175]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[175]), .s(s[175]), .clk(clk), .out({w_pp1[175], w_pp0[175]}));
MSKand_opini2_d2_pini u_pp_176 (
    .ina({aa_d1[176], aa_d0[176]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[176]), .s(s[176]), .clk(clk), .out({w_pp1[176], w_pp0[176]}));
MSKand_opini2_d2_pini u_pp_177 (
    .ina({aa_d1[177], aa_d0[177]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[177]), .s(s[177]), .clk(clk), .out({w_pp1[177], w_pp0[177]}));
MSKand_opini2_d2_pini u_pp_178 (
    .ina({aa_d1[178], aa_d0[178]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[178]), .s(s[178]), .clk(clk), .out({w_pp1[178], w_pp0[178]}));
MSKand_opini2_d2_pini u_pp_179 (
    .ina({aa_d1[179], aa_d0[179]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[179]), .s(s[179]), .clk(clk), .out({w_pp1[179], w_pp0[179]}));
MSKand_opini2_d2_pini u_pp_180 (
    .ina({aa_d1[180], aa_d0[180]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[180]), .s(s[180]), .clk(clk), .out({w_pp1[180], w_pp0[180]}));
MSKand_opini2_d2_pini u_pp_181 (
    .ina({aa_d1[181], aa_d0[181]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[181]), .s(s[181]), .clk(clk), .out({w_pp1[181], w_pp0[181]}));
MSKand_opini2_d2_pini u_pp_182 (
    .ina({aa_d1[182], aa_d0[182]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[182]), .s(s[182]), .clk(clk), .out({w_pp1[182], w_pp0[182]}));
MSKand_opini2_d2_pini u_pp_183 (
    .ina({aa_d1[183], aa_d0[183]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[183]), .s(s[183]), .clk(clk), .out({w_pp1[183], w_pp0[183]}));
MSKand_opini2_d2_pini u_pp_184 (
    .ina({aa_d1[184], aa_d0[184]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[184]), .s(s[184]), .clk(clk), .out({w_pp1[184], w_pp0[184]}));
MSKand_opini2_d2_pini u_pp_185 (
    .ina({aa_d1[185], aa_d0[185]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[185]), .s(s[185]), .clk(clk), .out({w_pp1[185], w_pp0[185]}));
MSKand_opini2_d2_pini u_pp_186 (
    .ina({aa_d1[186], aa_d0[186]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[186]), .s(s[186]), .clk(clk), .out({w_pp1[186], w_pp0[186]}));
MSKand_opini2_d2_pini u_pp_187 (
    .ina({aa_d1[187], aa_d0[187]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[187]), .s(s[187]), .clk(clk), .out({w_pp1[187], w_pp0[187]}));
MSKand_opini2_d2_pini u_pp_188 (
    .ina({aa_d1[188], aa_d0[188]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[188]), .s(s[188]), .clk(clk), .out({w_pp1[188], w_pp0[188]}));
MSKand_opini2_d2_pini u_pp_189 (
    .ina({aa_d1[189], aa_d0[189]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[189]), .s(s[189]), .clk(clk), .out({w_pp1[189], w_pp0[189]}));
MSKand_opini2_d2_pini u_pp_190 (
    .ina({aa_d1[190], aa_d0[190]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[190]), .s(s[190]), .clk(clk), .out({w_pp1[190], w_pp0[190]}));
MSKand_opini2_d2_pini u_pp_191 (
    .ina({aa_d1[191], aa_d0[191]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[191]), .s(s[191]), .clk(clk), .out({w_pp1[191], w_pp0[191]}));
MSKand_opini2_d2_pini u_pp_192 (
    .ina({aa_d1[192], aa_d0[192]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[192]), .s(s[192]), .clk(clk), .out({w_pp1[192], w_pp0[192]}));
MSKand_opini2_d2_pini u_pp_193 (
    .ina({aa_d1[193], aa_d0[193]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[193]), .s(s[193]), .clk(clk), .out({w_pp1[193], w_pp0[193]}));
MSKand_opini2_d2_pini u_pp_194 (
    .ina({aa_d1[194], aa_d0[194]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[194]), .s(s[194]), .clk(clk), .out({w_pp1[194], w_pp0[194]}));
MSKand_opini2_d2_pini u_pp_195 (
    .ina({aa_d1[195], aa_d0[195]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[195]), .s(s[195]), .clk(clk), .out({w_pp1[195], w_pp0[195]}));
MSKand_opini2_d2_pini u_pp_196 (
    .ina({aa_d1[196], aa_d0[196]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[196]), .s(s[196]), .clk(clk), .out({w_pp1[196], w_pp0[196]}));
MSKand_opini2_d2_pini u_pp_197 (
    .ina({aa_d1[197], aa_d0[197]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[197]), .s(s[197]), .clk(clk), .out({w_pp1[197], w_pp0[197]}));
MSKand_opini2_d2_pini u_pp_198 (
    .ina({aa_d1[198], aa_d0[198]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[198]), .s(s[198]), .clk(clk), .out({w_pp1[198], w_pp0[198]}));
MSKand_opini2_d2_pini u_pp_199 (
    .ina({aa_d1[199], aa_d0[199]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[199]), .s(s[199]), .clk(clk), .out({w_pp1[199], w_pp0[199]}));
MSKand_opini2_d2_pini u_pp_200 (
    .ina({aa_d1[200], aa_d0[200]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[200]), .s(s[200]), .clk(clk), .out({w_pp1[200], w_pp0[200]}));
MSKand_opini2_d2_pini u_pp_201 (
    .ina({aa_d1[201], aa_d0[201]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[201]), .s(s[201]), .clk(clk), .out({w_pp1[201], w_pp0[201]}));
MSKand_opini2_d2_pini u_pp_202 (
    .ina({aa_d1[202], aa_d0[202]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[202]), .s(s[202]), .clk(clk), .out({w_pp1[202], w_pp0[202]}));
MSKand_opini2_d2_pini u_pp_203 (
    .ina({aa_d1[203], aa_d0[203]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[203]), .s(s[203]), .clk(clk), .out({w_pp1[203], w_pp0[203]}));
MSKand_opini2_d2_pini u_pp_204 (
    .ina({aa_d1[204], aa_d0[204]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[204]), .s(s[204]), .clk(clk), .out({w_pp1[204], w_pp0[204]}));
MSKand_opini2_d2_pini u_pp_205 (
    .ina({aa_d1[205], aa_d0[205]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[205]), .s(s[205]), .clk(clk), .out({w_pp1[205], w_pp0[205]}));
MSKand_opini2_d2_pini u_pp_206 (
    .ina({aa_d1[206], aa_d0[206]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[206]), .s(s[206]), .clk(clk), .out({w_pp1[206], w_pp0[206]}));
MSKand_opini2_d2_pini u_pp_207 (
    .ina({aa_d1[207], aa_d0[207]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[207]), .s(s[207]), .clk(clk), .out({w_pp1[207], w_pp0[207]}));
MSKand_opini2_d2_pini u_pp_208 (
    .ina({aa_d1[208], aa_d0[208]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[208]), .s(s[208]), .clk(clk), .out({w_pp1[208], w_pp0[208]}));
MSKand_opini2_d2_pini u_pp_209 (
    .ina({aa_d1[209], aa_d0[209]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[209]), .s(s[209]), .clk(clk), .out({w_pp1[209], w_pp0[209]}));
MSKand_opini2_d2_pini u_pp_210 (
    .ina({aa_d1[210], aa_d0[210]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[210]), .s(s[210]), .clk(clk), .out({w_pp1[210], w_pp0[210]}));
MSKand_opini2_d2_pini u_pp_211 (
    .ina({aa_d1[211], aa_d0[211]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[211]), .s(s[211]), .clk(clk), .out({w_pp1[211], w_pp0[211]}));
MSKand_opini2_d2_pini u_pp_212 (
    .ina({aa_d1[212], aa_d0[212]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[212]), .s(s[212]), .clk(clk), .out({w_pp1[212], w_pp0[212]}));
MSKand_opini2_d2_pini u_pp_213 (
    .ina({aa_d1[213], aa_d0[213]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[213]), .s(s[213]), .clk(clk), .out({w_pp1[213], w_pp0[213]}));
MSKand_opini2_d2_pini u_pp_214 (
    .ina({aa_d1[214], aa_d0[214]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[214]), .s(s[214]), .clk(clk), .out({w_pp1[214], w_pp0[214]}));
MSKand_opini2_d2_pini u_pp_215 (
    .ina({aa_d1[215], aa_d0[215]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[215]), .s(s[215]), .clk(clk), .out({w_pp1[215], w_pp0[215]}));
MSKand_opini2_d2_pini u_pp_216 (
    .ina({aa_d1[216], aa_d0[216]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[216]), .s(s[216]), .clk(clk), .out({w_pp1[216], w_pp0[216]}));
MSKand_opini2_d2_pini u_pp_217 (
    .ina({aa_d1[217], aa_d0[217]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[217]), .s(s[217]), .clk(clk), .out({w_pp1[217], w_pp0[217]}));
MSKand_opini2_d2_pini u_pp_218 (
    .ina({aa_d1[218], aa_d0[218]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[218]), .s(s[218]), .clk(clk), .out({w_pp1[218], w_pp0[218]}));
MSKand_opini2_d2_pini u_pp_219 (
    .ina({aa_d1[219], aa_d0[219]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[219]), .s(s[219]), .clk(clk), .out({w_pp1[219], w_pp0[219]}));
MSKand_opini2_d2_pini u_pp_220 (
    .ina({aa_d1[220], aa_d0[220]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[220]), .s(s[220]), .clk(clk), .out({w_pp1[220], w_pp0[220]}));
MSKand_opini2_d2_pini u_pp_221 (
    .ina({aa_d1[221], aa_d0[221]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[221]), .s(s[221]), .clk(clk), .out({w_pp1[221], w_pp0[221]}));
MSKand_opini2_d2_pini u_pp_222 (
    .ina({aa_d1[222], aa_d0[222]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[222]), .s(s[222]), .clk(clk), .out({w_pp1[222], w_pp0[222]}));
MSKand_opini2_d2_pini u_pp_223 (
    .ina({aa_d1[223], aa_d0[223]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[223]), .s(s[223]), .clk(clk), .out({w_pp1[223], w_pp0[223]}));
MSKand_opini2_d2_pini u_pp_224 (
    .ina({aa_d1[224], aa_d0[224]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[224]), .s(s[224]), .clk(clk), .out({w_pp1[224], w_pp0[224]}));
MSKand_opini2_d2_pini u_pp_225 (
    .ina({aa_d1[225], aa_d0[225]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[225]), .s(s[225]), .clk(clk), .out({w_pp1[225], w_pp0[225]}));
MSKand_opini2_d2_pini u_pp_226 (
    .ina({aa_d1[226], aa_d0[226]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[226]), .s(s[226]), .clk(clk), .out({w_pp1[226], w_pp0[226]}));
MSKand_opini2_d2_pini u_pp_227 (
    .ina({aa_d1[227], aa_d0[227]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[227]), .s(s[227]), .clk(clk), .out({w_pp1[227], w_pp0[227]}));
MSKand_opini2_d2_pini u_pp_228 (
    .ina({aa_d1[228], aa_d0[228]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[228]), .s(s[228]), .clk(clk), .out({w_pp1[228], w_pp0[228]}));
MSKand_opini2_d2_pini u_pp_229 (
    .ina({aa_d1[229], aa_d0[229]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[229]), .s(s[229]), .clk(clk), .out({w_pp1[229], w_pp0[229]}));
MSKand_opini2_d2_pini u_pp_230 (
    .ina({aa_d1[230], aa_d0[230]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[230]), .s(s[230]), .clk(clk), .out({w_pp1[230], w_pp0[230]}));
MSKand_opini2_d2_pini u_pp_231 (
    .ina({aa_d1[231], aa_d0[231]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[231]), .s(s[231]), .clk(clk), .out({w_pp1[231], w_pp0[231]}));
MSKand_opini2_d2_pini u_pp_232 (
    .ina({aa_d1[232], aa_d0[232]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[232]), .s(s[232]), .clk(clk), .out({w_pp1[232], w_pp0[232]}));
MSKand_opini2_d2_pini u_pp_233 (
    .ina({aa_d1[233], aa_d0[233]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[233]), .s(s[233]), .clk(clk), .out({w_pp1[233], w_pp0[233]}));
MSKand_opini2_d2_pini u_pp_234 (
    .ina({aa_d1[234], aa_d0[234]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[234]), .s(s[234]), .clk(clk), .out({w_pp1[234], w_pp0[234]}));
MSKand_opini2_d2_pini u_pp_235 (
    .ina({aa_d1[235], aa_d0[235]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[235]), .s(s[235]), .clk(clk), .out({w_pp1[235], w_pp0[235]}));
MSKand_opini2_d2_pini u_pp_236 (
    .ina({aa_d1[236], aa_d0[236]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[236]), .s(s[236]), .clk(clk), .out({w_pp1[236], w_pp0[236]}));
MSKand_opini2_d2_pini u_pp_237 (
    .ina({aa_d1[237], aa_d0[237]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[237]), .s(s[237]), .clk(clk), .out({w_pp1[237], w_pp0[237]}));
MSKand_opini2_d2_pini u_pp_238 (
    .ina({aa_d1[238], aa_d0[238]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[238]), .s(s[238]), .clk(clk), .out({w_pp1[238], w_pp0[238]}));
MSKand_opini2_d2_pini u_pp_239 (
    .ina({aa_d1[239], aa_d0[239]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[239]), .s(s[239]), .clk(clk), .out({w_pp1[239], w_pp0[239]}));
MSKand_opini2_d2_pini u_pp_240 (
    .ina({aa_d1[240], aa_d0[240]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[240]), .s(s[240]), .clk(clk), .out({w_pp1[240], w_pp0[240]}));
MSKand_opini2_d2_pini u_pp_241 (
    .ina({aa_d1[241], aa_d0[241]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[241]), .s(s[241]), .clk(clk), .out({w_pp1[241], w_pp0[241]}));
MSKand_opini2_d2_pini u_pp_242 (
    .ina({aa_d1[242], aa_d0[242]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[242]), .s(s[242]), .clk(clk), .out({w_pp1[242], w_pp0[242]}));
MSKand_opini2_d2_pini u_pp_243 (
    .ina({aa_d1[243], aa_d0[243]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[243]), .s(s[243]), .clk(clk), .out({w_pp1[243], w_pp0[243]}));
MSKand_opini2_d2_pini u_pp_244 (
    .ina({aa_d1[244], aa_d0[244]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[244]), .s(s[244]), .clk(clk), .out({w_pp1[244], w_pp0[244]}));
MSKand_opini2_d2_pini u_pp_245 (
    .ina({aa_d1[245], aa_d0[245]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[245]), .s(s[245]), .clk(clk), .out({w_pp1[245], w_pp0[245]}));
MSKand_opini2_d2_pini u_pp_246 (
    .ina({aa_d1[246], aa_d0[246]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[246]), .s(s[246]), .clk(clk), .out({w_pp1[246], w_pp0[246]}));
MSKand_opini2_d2_pini u_pp_247 (
    .ina({aa_d1[247], aa_d0[247]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[247]), .s(s[247]), .clk(clk), .out({w_pp1[247], w_pp0[247]}));
MSKand_opini2_d2_pini u_pp_248 (
    .ina({aa_d1[248], aa_d0[248]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[248]), .s(s[248]), .clk(clk), .out({w_pp1[248], w_pp0[248]}));
MSKand_opini2_d2_pini u_pp_249 (
    .ina({aa_d1[249], aa_d0[249]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[249]), .s(s[249]), .clk(clk), .out({w_pp1[249], w_pp0[249]}));
MSKand_opini2_d2_pini u_pp_250 (
    .ina({aa_d1[250], aa_d0[250]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[250]), .s(s[250]), .clk(clk), .out({w_pp1[250], w_pp0[250]}));
MSKand_opini2_d2_pini u_pp_251 (
    .ina({aa_d1[251], aa_d0[251]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[251]), .s(s[251]), .clk(clk), .out({w_pp1[251], w_pp0[251]}));
MSKand_opini2_d2_pini u_pp_252 (
    .ina({aa_d1[252], aa_d0[252]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[252]), .s(s[252]), .clk(clk), .out({w_pp1[252], w_pp0[252]}));
MSKand_opini2_d2_pini u_pp_253 (
    .ina({aa_d1[253], aa_d0[253]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[253]), .s(s[253]), .clk(clk), .out({w_pp1[253], w_pp0[253]}));
MSKand_opini2_d2_pini u_pp_254 (
    .ina({aa_d1[254], aa_d0[254]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[254]), .s(s[254]), .clk(clk), .out({w_pp1[254], w_pp0[254]}));
MSKand_opini2_d2_pini u_pp_255 (
    .ina({aa_d1[255], aa_d0[255]}), .inb({bb1[0], bb0[0]}),
    .rnd(r[255]), .s(s[255]), .clk(clk), .out({w_pp1[255], w_pp0[255]}));

// ===== carry-save MAJ: newC[j+1] = (S&C)[j] ^ (PP&(S^C))[j] =====
// (bit 255 omitted: its carry is dropped by the <<1 mod-2^256 accumulate)
MSKand_opini2_d2_pini u_sc_0 (
    .ina({c_d1[0], c_d0[0]}), .inb({S1[0], S0[0]}),
    .rnd(r[256]), .s(s[256]), .clk(clk), .out({w_sc1[0], w_sc0[0]}));
MSKand_opini2_d2_pini u_px_0 (
    .ina({x_d1[0], x_d0[0]}), .inb({pp1[0], pp0[0]}),
    .rnd(r[257]), .s(s[257]), .clk(clk), .out({w_px1[0], w_px0[0]}));
MSKand_opini2_d2_pini u_sc_1 (
    .ina({c_d1[1], c_d0[1]}), .inb({S1[1], S0[1]}),
    .rnd(r[258]), .s(s[258]), .clk(clk), .out({w_sc1[1], w_sc0[1]}));
MSKand_opini2_d2_pini u_px_1 (
    .ina({x_d1[1], x_d0[1]}), .inb({pp1[1], pp0[1]}),
    .rnd(r[259]), .s(s[259]), .clk(clk), .out({w_px1[1], w_px0[1]}));
MSKand_opini2_d2_pini u_sc_2 (
    .ina({c_d1[2], c_d0[2]}), .inb({S1[2], S0[2]}),
    .rnd(r[260]), .s(s[260]), .clk(clk), .out({w_sc1[2], w_sc0[2]}));
MSKand_opini2_d2_pini u_px_2 (
    .ina({x_d1[2], x_d0[2]}), .inb({pp1[2], pp0[2]}),
    .rnd(r[261]), .s(s[261]), .clk(clk), .out({w_px1[2], w_px0[2]}));
MSKand_opini2_d2_pini u_sc_3 (
    .ina({c_d1[3], c_d0[3]}), .inb({S1[3], S0[3]}),
    .rnd(r[262]), .s(s[262]), .clk(clk), .out({w_sc1[3], w_sc0[3]}));
MSKand_opini2_d2_pini u_px_3 (
    .ina({x_d1[3], x_d0[3]}), .inb({pp1[3], pp0[3]}),
    .rnd(r[263]), .s(s[263]), .clk(clk), .out({w_px1[3], w_px0[3]}));
MSKand_opini2_d2_pini u_sc_4 (
    .ina({c_d1[4], c_d0[4]}), .inb({S1[4], S0[4]}),
    .rnd(r[264]), .s(s[264]), .clk(clk), .out({w_sc1[4], w_sc0[4]}));
MSKand_opini2_d2_pini u_px_4 (
    .ina({x_d1[4], x_d0[4]}), .inb({pp1[4], pp0[4]}),
    .rnd(r[265]), .s(s[265]), .clk(clk), .out({w_px1[4], w_px0[4]}));
MSKand_opini2_d2_pini u_sc_5 (
    .ina({c_d1[5], c_d0[5]}), .inb({S1[5], S0[5]}),
    .rnd(r[266]), .s(s[266]), .clk(clk), .out({w_sc1[5], w_sc0[5]}));
MSKand_opini2_d2_pini u_px_5 (
    .ina({x_d1[5], x_d0[5]}), .inb({pp1[5], pp0[5]}),
    .rnd(r[267]), .s(s[267]), .clk(clk), .out({w_px1[5], w_px0[5]}));
MSKand_opini2_d2_pini u_sc_6 (
    .ina({c_d1[6], c_d0[6]}), .inb({S1[6], S0[6]}),
    .rnd(r[268]), .s(s[268]), .clk(clk), .out({w_sc1[6], w_sc0[6]}));
MSKand_opini2_d2_pini u_px_6 (
    .ina({x_d1[6], x_d0[6]}), .inb({pp1[6], pp0[6]}),
    .rnd(r[269]), .s(s[269]), .clk(clk), .out({w_px1[6], w_px0[6]}));
MSKand_opini2_d2_pini u_sc_7 (
    .ina({c_d1[7], c_d0[7]}), .inb({S1[7], S0[7]}),
    .rnd(r[270]), .s(s[270]), .clk(clk), .out({w_sc1[7], w_sc0[7]}));
MSKand_opini2_d2_pini u_px_7 (
    .ina({x_d1[7], x_d0[7]}), .inb({pp1[7], pp0[7]}),
    .rnd(r[271]), .s(s[271]), .clk(clk), .out({w_px1[7], w_px0[7]}));
MSKand_opini2_d2_pini u_sc_8 (
    .ina({c_d1[8], c_d0[8]}), .inb({S1[8], S0[8]}),
    .rnd(r[272]), .s(s[272]), .clk(clk), .out({w_sc1[8], w_sc0[8]}));
MSKand_opini2_d2_pini u_px_8 (
    .ina({x_d1[8], x_d0[8]}), .inb({pp1[8], pp0[8]}),
    .rnd(r[273]), .s(s[273]), .clk(clk), .out({w_px1[8], w_px0[8]}));
MSKand_opini2_d2_pini u_sc_9 (
    .ina({c_d1[9], c_d0[9]}), .inb({S1[9], S0[9]}),
    .rnd(r[274]), .s(s[274]), .clk(clk), .out({w_sc1[9], w_sc0[9]}));
MSKand_opini2_d2_pini u_px_9 (
    .ina({x_d1[9], x_d0[9]}), .inb({pp1[9], pp0[9]}),
    .rnd(r[275]), .s(s[275]), .clk(clk), .out({w_px1[9], w_px0[9]}));
MSKand_opini2_d2_pini u_sc_10 (
    .ina({c_d1[10], c_d0[10]}), .inb({S1[10], S0[10]}),
    .rnd(r[276]), .s(s[276]), .clk(clk), .out({w_sc1[10], w_sc0[10]}));
MSKand_opini2_d2_pini u_px_10 (
    .ina({x_d1[10], x_d0[10]}), .inb({pp1[10], pp0[10]}),
    .rnd(r[277]), .s(s[277]), .clk(clk), .out({w_px1[10], w_px0[10]}));
MSKand_opini2_d2_pini u_sc_11 (
    .ina({c_d1[11], c_d0[11]}), .inb({S1[11], S0[11]}),
    .rnd(r[278]), .s(s[278]), .clk(clk), .out({w_sc1[11], w_sc0[11]}));
MSKand_opini2_d2_pini u_px_11 (
    .ina({x_d1[11], x_d0[11]}), .inb({pp1[11], pp0[11]}),
    .rnd(r[279]), .s(s[279]), .clk(clk), .out({w_px1[11], w_px0[11]}));
MSKand_opini2_d2_pini u_sc_12 (
    .ina({c_d1[12], c_d0[12]}), .inb({S1[12], S0[12]}),
    .rnd(r[280]), .s(s[280]), .clk(clk), .out({w_sc1[12], w_sc0[12]}));
MSKand_opini2_d2_pini u_px_12 (
    .ina({x_d1[12], x_d0[12]}), .inb({pp1[12], pp0[12]}),
    .rnd(r[281]), .s(s[281]), .clk(clk), .out({w_px1[12], w_px0[12]}));
MSKand_opini2_d2_pini u_sc_13 (
    .ina({c_d1[13], c_d0[13]}), .inb({S1[13], S0[13]}),
    .rnd(r[282]), .s(s[282]), .clk(clk), .out({w_sc1[13], w_sc0[13]}));
MSKand_opini2_d2_pini u_px_13 (
    .ina({x_d1[13], x_d0[13]}), .inb({pp1[13], pp0[13]}),
    .rnd(r[283]), .s(s[283]), .clk(clk), .out({w_px1[13], w_px0[13]}));
MSKand_opini2_d2_pini u_sc_14 (
    .ina({c_d1[14], c_d0[14]}), .inb({S1[14], S0[14]}),
    .rnd(r[284]), .s(s[284]), .clk(clk), .out({w_sc1[14], w_sc0[14]}));
MSKand_opini2_d2_pini u_px_14 (
    .ina({x_d1[14], x_d0[14]}), .inb({pp1[14], pp0[14]}),
    .rnd(r[285]), .s(s[285]), .clk(clk), .out({w_px1[14], w_px0[14]}));
MSKand_opini2_d2_pini u_sc_15 (
    .ina({c_d1[15], c_d0[15]}), .inb({S1[15], S0[15]}),
    .rnd(r[286]), .s(s[286]), .clk(clk), .out({w_sc1[15], w_sc0[15]}));
MSKand_opini2_d2_pini u_px_15 (
    .ina({x_d1[15], x_d0[15]}), .inb({pp1[15], pp0[15]}),
    .rnd(r[287]), .s(s[287]), .clk(clk), .out({w_px1[15], w_px0[15]}));
MSKand_opini2_d2_pini u_sc_16 (
    .ina({c_d1[16], c_d0[16]}), .inb({S1[16], S0[16]}),
    .rnd(r[288]), .s(s[288]), .clk(clk), .out({w_sc1[16], w_sc0[16]}));
MSKand_opini2_d2_pini u_px_16 (
    .ina({x_d1[16], x_d0[16]}), .inb({pp1[16], pp0[16]}),
    .rnd(r[289]), .s(s[289]), .clk(clk), .out({w_px1[16], w_px0[16]}));
MSKand_opini2_d2_pini u_sc_17 (
    .ina({c_d1[17], c_d0[17]}), .inb({S1[17], S0[17]}),
    .rnd(r[290]), .s(s[290]), .clk(clk), .out({w_sc1[17], w_sc0[17]}));
MSKand_opini2_d2_pini u_px_17 (
    .ina({x_d1[17], x_d0[17]}), .inb({pp1[17], pp0[17]}),
    .rnd(r[291]), .s(s[291]), .clk(clk), .out({w_px1[17], w_px0[17]}));
MSKand_opini2_d2_pini u_sc_18 (
    .ina({c_d1[18], c_d0[18]}), .inb({S1[18], S0[18]}),
    .rnd(r[292]), .s(s[292]), .clk(clk), .out({w_sc1[18], w_sc0[18]}));
MSKand_opini2_d2_pini u_px_18 (
    .ina({x_d1[18], x_d0[18]}), .inb({pp1[18], pp0[18]}),
    .rnd(r[293]), .s(s[293]), .clk(clk), .out({w_px1[18], w_px0[18]}));
MSKand_opini2_d2_pini u_sc_19 (
    .ina({c_d1[19], c_d0[19]}), .inb({S1[19], S0[19]}),
    .rnd(r[294]), .s(s[294]), .clk(clk), .out({w_sc1[19], w_sc0[19]}));
MSKand_opini2_d2_pini u_px_19 (
    .ina({x_d1[19], x_d0[19]}), .inb({pp1[19], pp0[19]}),
    .rnd(r[295]), .s(s[295]), .clk(clk), .out({w_px1[19], w_px0[19]}));
MSKand_opini2_d2_pini u_sc_20 (
    .ina({c_d1[20], c_d0[20]}), .inb({S1[20], S0[20]}),
    .rnd(r[296]), .s(s[296]), .clk(clk), .out({w_sc1[20], w_sc0[20]}));
MSKand_opini2_d2_pini u_px_20 (
    .ina({x_d1[20], x_d0[20]}), .inb({pp1[20], pp0[20]}),
    .rnd(r[297]), .s(s[297]), .clk(clk), .out({w_px1[20], w_px0[20]}));
MSKand_opini2_d2_pini u_sc_21 (
    .ina({c_d1[21], c_d0[21]}), .inb({S1[21], S0[21]}),
    .rnd(r[298]), .s(s[298]), .clk(clk), .out({w_sc1[21], w_sc0[21]}));
MSKand_opini2_d2_pini u_px_21 (
    .ina({x_d1[21], x_d0[21]}), .inb({pp1[21], pp0[21]}),
    .rnd(r[299]), .s(s[299]), .clk(clk), .out({w_px1[21], w_px0[21]}));
MSKand_opini2_d2_pini u_sc_22 (
    .ina({c_d1[22], c_d0[22]}), .inb({S1[22], S0[22]}),
    .rnd(r[300]), .s(s[300]), .clk(clk), .out({w_sc1[22], w_sc0[22]}));
MSKand_opini2_d2_pini u_px_22 (
    .ina({x_d1[22], x_d0[22]}), .inb({pp1[22], pp0[22]}),
    .rnd(r[301]), .s(s[301]), .clk(clk), .out({w_px1[22], w_px0[22]}));
MSKand_opini2_d2_pini u_sc_23 (
    .ina({c_d1[23], c_d0[23]}), .inb({S1[23], S0[23]}),
    .rnd(r[302]), .s(s[302]), .clk(clk), .out({w_sc1[23], w_sc0[23]}));
MSKand_opini2_d2_pini u_px_23 (
    .ina({x_d1[23], x_d0[23]}), .inb({pp1[23], pp0[23]}),
    .rnd(r[303]), .s(s[303]), .clk(clk), .out({w_px1[23], w_px0[23]}));
MSKand_opini2_d2_pini u_sc_24 (
    .ina({c_d1[24], c_d0[24]}), .inb({S1[24], S0[24]}),
    .rnd(r[304]), .s(s[304]), .clk(clk), .out({w_sc1[24], w_sc0[24]}));
MSKand_opini2_d2_pini u_px_24 (
    .ina({x_d1[24], x_d0[24]}), .inb({pp1[24], pp0[24]}),
    .rnd(r[305]), .s(s[305]), .clk(clk), .out({w_px1[24], w_px0[24]}));
MSKand_opini2_d2_pini u_sc_25 (
    .ina({c_d1[25], c_d0[25]}), .inb({S1[25], S0[25]}),
    .rnd(r[306]), .s(s[306]), .clk(clk), .out({w_sc1[25], w_sc0[25]}));
MSKand_opini2_d2_pini u_px_25 (
    .ina({x_d1[25], x_d0[25]}), .inb({pp1[25], pp0[25]}),
    .rnd(r[307]), .s(s[307]), .clk(clk), .out({w_px1[25], w_px0[25]}));
MSKand_opini2_d2_pini u_sc_26 (
    .ina({c_d1[26], c_d0[26]}), .inb({S1[26], S0[26]}),
    .rnd(r[308]), .s(s[308]), .clk(clk), .out({w_sc1[26], w_sc0[26]}));
MSKand_opini2_d2_pini u_px_26 (
    .ina({x_d1[26], x_d0[26]}), .inb({pp1[26], pp0[26]}),
    .rnd(r[309]), .s(s[309]), .clk(clk), .out({w_px1[26], w_px0[26]}));
MSKand_opini2_d2_pini u_sc_27 (
    .ina({c_d1[27], c_d0[27]}), .inb({S1[27], S0[27]}),
    .rnd(r[310]), .s(s[310]), .clk(clk), .out({w_sc1[27], w_sc0[27]}));
MSKand_opini2_d2_pini u_px_27 (
    .ina({x_d1[27], x_d0[27]}), .inb({pp1[27], pp0[27]}),
    .rnd(r[311]), .s(s[311]), .clk(clk), .out({w_px1[27], w_px0[27]}));
MSKand_opini2_d2_pini u_sc_28 (
    .ina({c_d1[28], c_d0[28]}), .inb({S1[28], S0[28]}),
    .rnd(r[312]), .s(s[312]), .clk(clk), .out({w_sc1[28], w_sc0[28]}));
MSKand_opini2_d2_pini u_px_28 (
    .ina({x_d1[28], x_d0[28]}), .inb({pp1[28], pp0[28]}),
    .rnd(r[313]), .s(s[313]), .clk(clk), .out({w_px1[28], w_px0[28]}));
MSKand_opini2_d2_pini u_sc_29 (
    .ina({c_d1[29], c_d0[29]}), .inb({S1[29], S0[29]}),
    .rnd(r[314]), .s(s[314]), .clk(clk), .out({w_sc1[29], w_sc0[29]}));
MSKand_opini2_d2_pini u_px_29 (
    .ina({x_d1[29], x_d0[29]}), .inb({pp1[29], pp0[29]}),
    .rnd(r[315]), .s(s[315]), .clk(clk), .out({w_px1[29], w_px0[29]}));
MSKand_opini2_d2_pini u_sc_30 (
    .ina({c_d1[30], c_d0[30]}), .inb({S1[30], S0[30]}),
    .rnd(r[316]), .s(s[316]), .clk(clk), .out({w_sc1[30], w_sc0[30]}));
MSKand_opini2_d2_pini u_px_30 (
    .ina({x_d1[30], x_d0[30]}), .inb({pp1[30], pp0[30]}),
    .rnd(r[317]), .s(s[317]), .clk(clk), .out({w_px1[30], w_px0[30]}));
MSKand_opini2_d2_pini u_sc_31 (
    .ina({c_d1[31], c_d0[31]}), .inb({S1[31], S0[31]}),
    .rnd(r[318]), .s(s[318]), .clk(clk), .out({w_sc1[31], w_sc0[31]}));
MSKand_opini2_d2_pini u_px_31 (
    .ina({x_d1[31], x_d0[31]}), .inb({pp1[31], pp0[31]}),
    .rnd(r[319]), .s(s[319]), .clk(clk), .out({w_px1[31], w_px0[31]}));
MSKand_opini2_d2_pini u_sc_32 (
    .ina({c_d1[32], c_d0[32]}), .inb({S1[32], S0[32]}),
    .rnd(r[320]), .s(s[320]), .clk(clk), .out({w_sc1[32], w_sc0[32]}));
MSKand_opini2_d2_pini u_px_32 (
    .ina({x_d1[32], x_d0[32]}), .inb({pp1[32], pp0[32]}),
    .rnd(r[321]), .s(s[321]), .clk(clk), .out({w_px1[32], w_px0[32]}));
MSKand_opini2_d2_pini u_sc_33 (
    .ina({c_d1[33], c_d0[33]}), .inb({S1[33], S0[33]}),
    .rnd(r[322]), .s(s[322]), .clk(clk), .out({w_sc1[33], w_sc0[33]}));
MSKand_opini2_d2_pini u_px_33 (
    .ina({x_d1[33], x_d0[33]}), .inb({pp1[33], pp0[33]}),
    .rnd(r[323]), .s(s[323]), .clk(clk), .out({w_px1[33], w_px0[33]}));
MSKand_opini2_d2_pini u_sc_34 (
    .ina({c_d1[34], c_d0[34]}), .inb({S1[34], S0[34]}),
    .rnd(r[324]), .s(s[324]), .clk(clk), .out({w_sc1[34], w_sc0[34]}));
MSKand_opini2_d2_pini u_px_34 (
    .ina({x_d1[34], x_d0[34]}), .inb({pp1[34], pp0[34]}),
    .rnd(r[325]), .s(s[325]), .clk(clk), .out({w_px1[34], w_px0[34]}));
MSKand_opini2_d2_pini u_sc_35 (
    .ina({c_d1[35], c_d0[35]}), .inb({S1[35], S0[35]}),
    .rnd(r[326]), .s(s[326]), .clk(clk), .out({w_sc1[35], w_sc0[35]}));
MSKand_opini2_d2_pini u_px_35 (
    .ina({x_d1[35], x_d0[35]}), .inb({pp1[35], pp0[35]}),
    .rnd(r[327]), .s(s[327]), .clk(clk), .out({w_px1[35], w_px0[35]}));
MSKand_opini2_d2_pini u_sc_36 (
    .ina({c_d1[36], c_d0[36]}), .inb({S1[36], S0[36]}),
    .rnd(r[328]), .s(s[328]), .clk(clk), .out({w_sc1[36], w_sc0[36]}));
MSKand_opini2_d2_pini u_px_36 (
    .ina({x_d1[36], x_d0[36]}), .inb({pp1[36], pp0[36]}),
    .rnd(r[329]), .s(s[329]), .clk(clk), .out({w_px1[36], w_px0[36]}));
MSKand_opini2_d2_pini u_sc_37 (
    .ina({c_d1[37], c_d0[37]}), .inb({S1[37], S0[37]}),
    .rnd(r[330]), .s(s[330]), .clk(clk), .out({w_sc1[37], w_sc0[37]}));
MSKand_opini2_d2_pini u_px_37 (
    .ina({x_d1[37], x_d0[37]}), .inb({pp1[37], pp0[37]}),
    .rnd(r[331]), .s(s[331]), .clk(clk), .out({w_px1[37], w_px0[37]}));
MSKand_opini2_d2_pini u_sc_38 (
    .ina({c_d1[38], c_d0[38]}), .inb({S1[38], S0[38]}),
    .rnd(r[332]), .s(s[332]), .clk(clk), .out({w_sc1[38], w_sc0[38]}));
MSKand_opini2_d2_pini u_px_38 (
    .ina({x_d1[38], x_d0[38]}), .inb({pp1[38], pp0[38]}),
    .rnd(r[333]), .s(s[333]), .clk(clk), .out({w_px1[38], w_px0[38]}));
MSKand_opini2_d2_pini u_sc_39 (
    .ina({c_d1[39], c_d0[39]}), .inb({S1[39], S0[39]}),
    .rnd(r[334]), .s(s[334]), .clk(clk), .out({w_sc1[39], w_sc0[39]}));
MSKand_opini2_d2_pini u_px_39 (
    .ina({x_d1[39], x_d0[39]}), .inb({pp1[39], pp0[39]}),
    .rnd(r[335]), .s(s[335]), .clk(clk), .out({w_px1[39], w_px0[39]}));
MSKand_opini2_d2_pini u_sc_40 (
    .ina({c_d1[40], c_d0[40]}), .inb({S1[40], S0[40]}),
    .rnd(r[336]), .s(s[336]), .clk(clk), .out({w_sc1[40], w_sc0[40]}));
MSKand_opini2_d2_pini u_px_40 (
    .ina({x_d1[40], x_d0[40]}), .inb({pp1[40], pp0[40]}),
    .rnd(r[337]), .s(s[337]), .clk(clk), .out({w_px1[40], w_px0[40]}));
MSKand_opini2_d2_pini u_sc_41 (
    .ina({c_d1[41], c_d0[41]}), .inb({S1[41], S0[41]}),
    .rnd(r[338]), .s(s[338]), .clk(clk), .out({w_sc1[41], w_sc0[41]}));
MSKand_opini2_d2_pini u_px_41 (
    .ina({x_d1[41], x_d0[41]}), .inb({pp1[41], pp0[41]}),
    .rnd(r[339]), .s(s[339]), .clk(clk), .out({w_px1[41], w_px0[41]}));
MSKand_opini2_d2_pini u_sc_42 (
    .ina({c_d1[42], c_d0[42]}), .inb({S1[42], S0[42]}),
    .rnd(r[340]), .s(s[340]), .clk(clk), .out({w_sc1[42], w_sc0[42]}));
MSKand_opini2_d2_pini u_px_42 (
    .ina({x_d1[42], x_d0[42]}), .inb({pp1[42], pp0[42]}),
    .rnd(r[341]), .s(s[341]), .clk(clk), .out({w_px1[42], w_px0[42]}));
MSKand_opini2_d2_pini u_sc_43 (
    .ina({c_d1[43], c_d0[43]}), .inb({S1[43], S0[43]}),
    .rnd(r[342]), .s(s[342]), .clk(clk), .out({w_sc1[43], w_sc0[43]}));
MSKand_opini2_d2_pini u_px_43 (
    .ina({x_d1[43], x_d0[43]}), .inb({pp1[43], pp0[43]}),
    .rnd(r[343]), .s(s[343]), .clk(clk), .out({w_px1[43], w_px0[43]}));
MSKand_opini2_d2_pini u_sc_44 (
    .ina({c_d1[44], c_d0[44]}), .inb({S1[44], S0[44]}),
    .rnd(r[344]), .s(s[344]), .clk(clk), .out({w_sc1[44], w_sc0[44]}));
MSKand_opini2_d2_pini u_px_44 (
    .ina({x_d1[44], x_d0[44]}), .inb({pp1[44], pp0[44]}),
    .rnd(r[345]), .s(s[345]), .clk(clk), .out({w_px1[44], w_px0[44]}));
MSKand_opini2_d2_pini u_sc_45 (
    .ina({c_d1[45], c_d0[45]}), .inb({S1[45], S0[45]}),
    .rnd(r[346]), .s(s[346]), .clk(clk), .out({w_sc1[45], w_sc0[45]}));
MSKand_opini2_d2_pini u_px_45 (
    .ina({x_d1[45], x_d0[45]}), .inb({pp1[45], pp0[45]}),
    .rnd(r[347]), .s(s[347]), .clk(clk), .out({w_px1[45], w_px0[45]}));
MSKand_opini2_d2_pini u_sc_46 (
    .ina({c_d1[46], c_d0[46]}), .inb({S1[46], S0[46]}),
    .rnd(r[348]), .s(s[348]), .clk(clk), .out({w_sc1[46], w_sc0[46]}));
MSKand_opini2_d2_pini u_px_46 (
    .ina({x_d1[46], x_d0[46]}), .inb({pp1[46], pp0[46]}),
    .rnd(r[349]), .s(s[349]), .clk(clk), .out({w_px1[46], w_px0[46]}));
MSKand_opini2_d2_pini u_sc_47 (
    .ina({c_d1[47], c_d0[47]}), .inb({S1[47], S0[47]}),
    .rnd(r[350]), .s(s[350]), .clk(clk), .out({w_sc1[47], w_sc0[47]}));
MSKand_opini2_d2_pini u_px_47 (
    .ina({x_d1[47], x_d0[47]}), .inb({pp1[47], pp0[47]}),
    .rnd(r[351]), .s(s[351]), .clk(clk), .out({w_px1[47], w_px0[47]}));
MSKand_opini2_d2_pini u_sc_48 (
    .ina({c_d1[48], c_d0[48]}), .inb({S1[48], S0[48]}),
    .rnd(r[352]), .s(s[352]), .clk(clk), .out({w_sc1[48], w_sc0[48]}));
MSKand_opini2_d2_pini u_px_48 (
    .ina({x_d1[48], x_d0[48]}), .inb({pp1[48], pp0[48]}),
    .rnd(r[353]), .s(s[353]), .clk(clk), .out({w_px1[48], w_px0[48]}));
MSKand_opini2_d2_pini u_sc_49 (
    .ina({c_d1[49], c_d0[49]}), .inb({S1[49], S0[49]}),
    .rnd(r[354]), .s(s[354]), .clk(clk), .out({w_sc1[49], w_sc0[49]}));
MSKand_opini2_d2_pini u_px_49 (
    .ina({x_d1[49], x_d0[49]}), .inb({pp1[49], pp0[49]}),
    .rnd(r[355]), .s(s[355]), .clk(clk), .out({w_px1[49], w_px0[49]}));
MSKand_opini2_d2_pini u_sc_50 (
    .ina({c_d1[50], c_d0[50]}), .inb({S1[50], S0[50]}),
    .rnd(r[356]), .s(s[356]), .clk(clk), .out({w_sc1[50], w_sc0[50]}));
MSKand_opini2_d2_pini u_px_50 (
    .ina({x_d1[50], x_d0[50]}), .inb({pp1[50], pp0[50]}),
    .rnd(r[357]), .s(s[357]), .clk(clk), .out({w_px1[50], w_px0[50]}));
MSKand_opini2_d2_pini u_sc_51 (
    .ina({c_d1[51], c_d0[51]}), .inb({S1[51], S0[51]}),
    .rnd(r[358]), .s(s[358]), .clk(clk), .out({w_sc1[51], w_sc0[51]}));
MSKand_opini2_d2_pini u_px_51 (
    .ina({x_d1[51], x_d0[51]}), .inb({pp1[51], pp0[51]}),
    .rnd(r[359]), .s(s[359]), .clk(clk), .out({w_px1[51], w_px0[51]}));
MSKand_opini2_d2_pini u_sc_52 (
    .ina({c_d1[52], c_d0[52]}), .inb({S1[52], S0[52]}),
    .rnd(r[360]), .s(s[360]), .clk(clk), .out({w_sc1[52], w_sc0[52]}));
MSKand_opini2_d2_pini u_px_52 (
    .ina({x_d1[52], x_d0[52]}), .inb({pp1[52], pp0[52]}),
    .rnd(r[361]), .s(s[361]), .clk(clk), .out({w_px1[52], w_px0[52]}));
MSKand_opini2_d2_pini u_sc_53 (
    .ina({c_d1[53], c_d0[53]}), .inb({S1[53], S0[53]}),
    .rnd(r[362]), .s(s[362]), .clk(clk), .out({w_sc1[53], w_sc0[53]}));
MSKand_opini2_d2_pini u_px_53 (
    .ina({x_d1[53], x_d0[53]}), .inb({pp1[53], pp0[53]}),
    .rnd(r[363]), .s(s[363]), .clk(clk), .out({w_px1[53], w_px0[53]}));
MSKand_opini2_d2_pini u_sc_54 (
    .ina({c_d1[54], c_d0[54]}), .inb({S1[54], S0[54]}),
    .rnd(r[364]), .s(s[364]), .clk(clk), .out({w_sc1[54], w_sc0[54]}));
MSKand_opini2_d2_pini u_px_54 (
    .ina({x_d1[54], x_d0[54]}), .inb({pp1[54], pp0[54]}),
    .rnd(r[365]), .s(s[365]), .clk(clk), .out({w_px1[54], w_px0[54]}));
MSKand_opini2_d2_pini u_sc_55 (
    .ina({c_d1[55], c_d0[55]}), .inb({S1[55], S0[55]}),
    .rnd(r[366]), .s(s[366]), .clk(clk), .out({w_sc1[55], w_sc0[55]}));
MSKand_opini2_d2_pini u_px_55 (
    .ina({x_d1[55], x_d0[55]}), .inb({pp1[55], pp0[55]}),
    .rnd(r[367]), .s(s[367]), .clk(clk), .out({w_px1[55], w_px0[55]}));
MSKand_opini2_d2_pini u_sc_56 (
    .ina({c_d1[56], c_d0[56]}), .inb({S1[56], S0[56]}),
    .rnd(r[368]), .s(s[368]), .clk(clk), .out({w_sc1[56], w_sc0[56]}));
MSKand_opini2_d2_pini u_px_56 (
    .ina({x_d1[56], x_d0[56]}), .inb({pp1[56], pp0[56]}),
    .rnd(r[369]), .s(s[369]), .clk(clk), .out({w_px1[56], w_px0[56]}));
MSKand_opini2_d2_pini u_sc_57 (
    .ina({c_d1[57], c_d0[57]}), .inb({S1[57], S0[57]}),
    .rnd(r[370]), .s(s[370]), .clk(clk), .out({w_sc1[57], w_sc0[57]}));
MSKand_opini2_d2_pini u_px_57 (
    .ina({x_d1[57], x_d0[57]}), .inb({pp1[57], pp0[57]}),
    .rnd(r[371]), .s(s[371]), .clk(clk), .out({w_px1[57], w_px0[57]}));
MSKand_opini2_d2_pini u_sc_58 (
    .ina({c_d1[58], c_d0[58]}), .inb({S1[58], S0[58]}),
    .rnd(r[372]), .s(s[372]), .clk(clk), .out({w_sc1[58], w_sc0[58]}));
MSKand_opini2_d2_pini u_px_58 (
    .ina({x_d1[58], x_d0[58]}), .inb({pp1[58], pp0[58]}),
    .rnd(r[373]), .s(s[373]), .clk(clk), .out({w_px1[58], w_px0[58]}));
MSKand_opini2_d2_pini u_sc_59 (
    .ina({c_d1[59], c_d0[59]}), .inb({S1[59], S0[59]}),
    .rnd(r[374]), .s(s[374]), .clk(clk), .out({w_sc1[59], w_sc0[59]}));
MSKand_opini2_d2_pini u_px_59 (
    .ina({x_d1[59], x_d0[59]}), .inb({pp1[59], pp0[59]}),
    .rnd(r[375]), .s(s[375]), .clk(clk), .out({w_px1[59], w_px0[59]}));
MSKand_opini2_d2_pini u_sc_60 (
    .ina({c_d1[60], c_d0[60]}), .inb({S1[60], S0[60]}),
    .rnd(r[376]), .s(s[376]), .clk(clk), .out({w_sc1[60], w_sc0[60]}));
MSKand_opini2_d2_pini u_px_60 (
    .ina({x_d1[60], x_d0[60]}), .inb({pp1[60], pp0[60]}),
    .rnd(r[377]), .s(s[377]), .clk(clk), .out({w_px1[60], w_px0[60]}));
MSKand_opini2_d2_pini u_sc_61 (
    .ina({c_d1[61], c_d0[61]}), .inb({S1[61], S0[61]}),
    .rnd(r[378]), .s(s[378]), .clk(clk), .out({w_sc1[61], w_sc0[61]}));
MSKand_opini2_d2_pini u_px_61 (
    .ina({x_d1[61], x_d0[61]}), .inb({pp1[61], pp0[61]}),
    .rnd(r[379]), .s(s[379]), .clk(clk), .out({w_px1[61], w_px0[61]}));
MSKand_opini2_d2_pini u_sc_62 (
    .ina({c_d1[62], c_d0[62]}), .inb({S1[62], S0[62]}),
    .rnd(r[380]), .s(s[380]), .clk(clk), .out({w_sc1[62], w_sc0[62]}));
MSKand_opini2_d2_pini u_px_62 (
    .ina({x_d1[62], x_d0[62]}), .inb({pp1[62], pp0[62]}),
    .rnd(r[381]), .s(s[381]), .clk(clk), .out({w_px1[62], w_px0[62]}));
MSKand_opini2_d2_pini u_sc_63 (
    .ina({c_d1[63], c_d0[63]}), .inb({S1[63], S0[63]}),
    .rnd(r[382]), .s(s[382]), .clk(clk), .out({w_sc1[63], w_sc0[63]}));
MSKand_opini2_d2_pini u_px_63 (
    .ina({x_d1[63], x_d0[63]}), .inb({pp1[63], pp0[63]}),
    .rnd(r[383]), .s(s[383]), .clk(clk), .out({w_px1[63], w_px0[63]}));
MSKand_opini2_d2_pini u_sc_64 (
    .ina({c_d1[64], c_d0[64]}), .inb({S1[64], S0[64]}),
    .rnd(r[384]), .s(s[384]), .clk(clk), .out({w_sc1[64], w_sc0[64]}));
MSKand_opini2_d2_pini u_px_64 (
    .ina({x_d1[64], x_d0[64]}), .inb({pp1[64], pp0[64]}),
    .rnd(r[385]), .s(s[385]), .clk(clk), .out({w_px1[64], w_px0[64]}));
MSKand_opini2_d2_pini u_sc_65 (
    .ina({c_d1[65], c_d0[65]}), .inb({S1[65], S0[65]}),
    .rnd(r[386]), .s(s[386]), .clk(clk), .out({w_sc1[65], w_sc0[65]}));
MSKand_opini2_d2_pini u_px_65 (
    .ina({x_d1[65], x_d0[65]}), .inb({pp1[65], pp0[65]}),
    .rnd(r[387]), .s(s[387]), .clk(clk), .out({w_px1[65], w_px0[65]}));
MSKand_opini2_d2_pini u_sc_66 (
    .ina({c_d1[66], c_d0[66]}), .inb({S1[66], S0[66]}),
    .rnd(r[388]), .s(s[388]), .clk(clk), .out({w_sc1[66], w_sc0[66]}));
MSKand_opini2_d2_pini u_px_66 (
    .ina({x_d1[66], x_d0[66]}), .inb({pp1[66], pp0[66]}),
    .rnd(r[389]), .s(s[389]), .clk(clk), .out({w_px1[66], w_px0[66]}));
MSKand_opini2_d2_pini u_sc_67 (
    .ina({c_d1[67], c_d0[67]}), .inb({S1[67], S0[67]}),
    .rnd(r[390]), .s(s[390]), .clk(clk), .out({w_sc1[67], w_sc0[67]}));
MSKand_opini2_d2_pini u_px_67 (
    .ina({x_d1[67], x_d0[67]}), .inb({pp1[67], pp0[67]}),
    .rnd(r[391]), .s(s[391]), .clk(clk), .out({w_px1[67], w_px0[67]}));
MSKand_opini2_d2_pini u_sc_68 (
    .ina({c_d1[68], c_d0[68]}), .inb({S1[68], S0[68]}),
    .rnd(r[392]), .s(s[392]), .clk(clk), .out({w_sc1[68], w_sc0[68]}));
MSKand_opini2_d2_pini u_px_68 (
    .ina({x_d1[68], x_d0[68]}), .inb({pp1[68], pp0[68]}),
    .rnd(r[393]), .s(s[393]), .clk(clk), .out({w_px1[68], w_px0[68]}));
MSKand_opini2_d2_pini u_sc_69 (
    .ina({c_d1[69], c_d0[69]}), .inb({S1[69], S0[69]}),
    .rnd(r[394]), .s(s[394]), .clk(clk), .out({w_sc1[69], w_sc0[69]}));
MSKand_opini2_d2_pini u_px_69 (
    .ina({x_d1[69], x_d0[69]}), .inb({pp1[69], pp0[69]}),
    .rnd(r[395]), .s(s[395]), .clk(clk), .out({w_px1[69], w_px0[69]}));
MSKand_opini2_d2_pini u_sc_70 (
    .ina({c_d1[70], c_d0[70]}), .inb({S1[70], S0[70]}),
    .rnd(r[396]), .s(s[396]), .clk(clk), .out({w_sc1[70], w_sc0[70]}));
MSKand_opini2_d2_pini u_px_70 (
    .ina({x_d1[70], x_d0[70]}), .inb({pp1[70], pp0[70]}),
    .rnd(r[397]), .s(s[397]), .clk(clk), .out({w_px1[70], w_px0[70]}));
MSKand_opini2_d2_pini u_sc_71 (
    .ina({c_d1[71], c_d0[71]}), .inb({S1[71], S0[71]}),
    .rnd(r[398]), .s(s[398]), .clk(clk), .out({w_sc1[71], w_sc0[71]}));
MSKand_opini2_d2_pini u_px_71 (
    .ina({x_d1[71], x_d0[71]}), .inb({pp1[71], pp0[71]}),
    .rnd(r[399]), .s(s[399]), .clk(clk), .out({w_px1[71], w_px0[71]}));
MSKand_opini2_d2_pini u_sc_72 (
    .ina({c_d1[72], c_d0[72]}), .inb({S1[72], S0[72]}),
    .rnd(r[400]), .s(s[400]), .clk(clk), .out({w_sc1[72], w_sc0[72]}));
MSKand_opini2_d2_pini u_px_72 (
    .ina({x_d1[72], x_d0[72]}), .inb({pp1[72], pp0[72]}),
    .rnd(r[401]), .s(s[401]), .clk(clk), .out({w_px1[72], w_px0[72]}));
MSKand_opini2_d2_pini u_sc_73 (
    .ina({c_d1[73], c_d0[73]}), .inb({S1[73], S0[73]}),
    .rnd(r[402]), .s(s[402]), .clk(clk), .out({w_sc1[73], w_sc0[73]}));
MSKand_opini2_d2_pini u_px_73 (
    .ina({x_d1[73], x_d0[73]}), .inb({pp1[73], pp0[73]}),
    .rnd(r[403]), .s(s[403]), .clk(clk), .out({w_px1[73], w_px0[73]}));
MSKand_opini2_d2_pini u_sc_74 (
    .ina({c_d1[74], c_d0[74]}), .inb({S1[74], S0[74]}),
    .rnd(r[404]), .s(s[404]), .clk(clk), .out({w_sc1[74], w_sc0[74]}));
MSKand_opini2_d2_pini u_px_74 (
    .ina({x_d1[74], x_d0[74]}), .inb({pp1[74], pp0[74]}),
    .rnd(r[405]), .s(s[405]), .clk(clk), .out({w_px1[74], w_px0[74]}));
MSKand_opini2_d2_pini u_sc_75 (
    .ina({c_d1[75], c_d0[75]}), .inb({S1[75], S0[75]}),
    .rnd(r[406]), .s(s[406]), .clk(clk), .out({w_sc1[75], w_sc0[75]}));
MSKand_opini2_d2_pini u_px_75 (
    .ina({x_d1[75], x_d0[75]}), .inb({pp1[75], pp0[75]}),
    .rnd(r[407]), .s(s[407]), .clk(clk), .out({w_px1[75], w_px0[75]}));
MSKand_opini2_d2_pini u_sc_76 (
    .ina({c_d1[76], c_d0[76]}), .inb({S1[76], S0[76]}),
    .rnd(r[408]), .s(s[408]), .clk(clk), .out({w_sc1[76], w_sc0[76]}));
MSKand_opini2_d2_pini u_px_76 (
    .ina({x_d1[76], x_d0[76]}), .inb({pp1[76], pp0[76]}),
    .rnd(r[409]), .s(s[409]), .clk(clk), .out({w_px1[76], w_px0[76]}));
MSKand_opini2_d2_pini u_sc_77 (
    .ina({c_d1[77], c_d0[77]}), .inb({S1[77], S0[77]}),
    .rnd(r[410]), .s(s[410]), .clk(clk), .out({w_sc1[77], w_sc0[77]}));
MSKand_opini2_d2_pini u_px_77 (
    .ina({x_d1[77], x_d0[77]}), .inb({pp1[77], pp0[77]}),
    .rnd(r[411]), .s(s[411]), .clk(clk), .out({w_px1[77], w_px0[77]}));
MSKand_opini2_d2_pini u_sc_78 (
    .ina({c_d1[78], c_d0[78]}), .inb({S1[78], S0[78]}),
    .rnd(r[412]), .s(s[412]), .clk(clk), .out({w_sc1[78], w_sc0[78]}));
MSKand_opini2_d2_pini u_px_78 (
    .ina({x_d1[78], x_d0[78]}), .inb({pp1[78], pp0[78]}),
    .rnd(r[413]), .s(s[413]), .clk(clk), .out({w_px1[78], w_px0[78]}));
MSKand_opini2_d2_pini u_sc_79 (
    .ina({c_d1[79], c_d0[79]}), .inb({S1[79], S0[79]}),
    .rnd(r[414]), .s(s[414]), .clk(clk), .out({w_sc1[79], w_sc0[79]}));
MSKand_opini2_d2_pini u_px_79 (
    .ina({x_d1[79], x_d0[79]}), .inb({pp1[79], pp0[79]}),
    .rnd(r[415]), .s(s[415]), .clk(clk), .out({w_px1[79], w_px0[79]}));
MSKand_opini2_d2_pini u_sc_80 (
    .ina({c_d1[80], c_d0[80]}), .inb({S1[80], S0[80]}),
    .rnd(r[416]), .s(s[416]), .clk(clk), .out({w_sc1[80], w_sc0[80]}));
MSKand_opini2_d2_pini u_px_80 (
    .ina({x_d1[80], x_d0[80]}), .inb({pp1[80], pp0[80]}),
    .rnd(r[417]), .s(s[417]), .clk(clk), .out({w_px1[80], w_px0[80]}));
MSKand_opini2_d2_pini u_sc_81 (
    .ina({c_d1[81], c_d0[81]}), .inb({S1[81], S0[81]}),
    .rnd(r[418]), .s(s[418]), .clk(clk), .out({w_sc1[81], w_sc0[81]}));
MSKand_opini2_d2_pini u_px_81 (
    .ina({x_d1[81], x_d0[81]}), .inb({pp1[81], pp0[81]}),
    .rnd(r[419]), .s(s[419]), .clk(clk), .out({w_px1[81], w_px0[81]}));
MSKand_opini2_d2_pini u_sc_82 (
    .ina({c_d1[82], c_d0[82]}), .inb({S1[82], S0[82]}),
    .rnd(r[420]), .s(s[420]), .clk(clk), .out({w_sc1[82], w_sc0[82]}));
MSKand_opini2_d2_pini u_px_82 (
    .ina({x_d1[82], x_d0[82]}), .inb({pp1[82], pp0[82]}),
    .rnd(r[421]), .s(s[421]), .clk(clk), .out({w_px1[82], w_px0[82]}));
MSKand_opini2_d2_pini u_sc_83 (
    .ina({c_d1[83], c_d0[83]}), .inb({S1[83], S0[83]}),
    .rnd(r[422]), .s(s[422]), .clk(clk), .out({w_sc1[83], w_sc0[83]}));
MSKand_opini2_d2_pini u_px_83 (
    .ina({x_d1[83], x_d0[83]}), .inb({pp1[83], pp0[83]}),
    .rnd(r[423]), .s(s[423]), .clk(clk), .out({w_px1[83], w_px0[83]}));
MSKand_opini2_d2_pini u_sc_84 (
    .ina({c_d1[84], c_d0[84]}), .inb({S1[84], S0[84]}),
    .rnd(r[424]), .s(s[424]), .clk(clk), .out({w_sc1[84], w_sc0[84]}));
MSKand_opini2_d2_pini u_px_84 (
    .ina({x_d1[84], x_d0[84]}), .inb({pp1[84], pp0[84]}),
    .rnd(r[425]), .s(s[425]), .clk(clk), .out({w_px1[84], w_px0[84]}));
MSKand_opini2_d2_pini u_sc_85 (
    .ina({c_d1[85], c_d0[85]}), .inb({S1[85], S0[85]}),
    .rnd(r[426]), .s(s[426]), .clk(clk), .out({w_sc1[85], w_sc0[85]}));
MSKand_opini2_d2_pini u_px_85 (
    .ina({x_d1[85], x_d0[85]}), .inb({pp1[85], pp0[85]}),
    .rnd(r[427]), .s(s[427]), .clk(clk), .out({w_px1[85], w_px0[85]}));
MSKand_opini2_d2_pini u_sc_86 (
    .ina({c_d1[86], c_d0[86]}), .inb({S1[86], S0[86]}),
    .rnd(r[428]), .s(s[428]), .clk(clk), .out({w_sc1[86], w_sc0[86]}));
MSKand_opini2_d2_pini u_px_86 (
    .ina({x_d1[86], x_d0[86]}), .inb({pp1[86], pp0[86]}),
    .rnd(r[429]), .s(s[429]), .clk(clk), .out({w_px1[86], w_px0[86]}));
MSKand_opini2_d2_pini u_sc_87 (
    .ina({c_d1[87], c_d0[87]}), .inb({S1[87], S0[87]}),
    .rnd(r[430]), .s(s[430]), .clk(clk), .out({w_sc1[87], w_sc0[87]}));
MSKand_opini2_d2_pini u_px_87 (
    .ina({x_d1[87], x_d0[87]}), .inb({pp1[87], pp0[87]}),
    .rnd(r[431]), .s(s[431]), .clk(clk), .out({w_px1[87], w_px0[87]}));
MSKand_opini2_d2_pini u_sc_88 (
    .ina({c_d1[88], c_d0[88]}), .inb({S1[88], S0[88]}),
    .rnd(r[432]), .s(s[432]), .clk(clk), .out({w_sc1[88], w_sc0[88]}));
MSKand_opini2_d2_pini u_px_88 (
    .ina({x_d1[88], x_d0[88]}), .inb({pp1[88], pp0[88]}),
    .rnd(r[433]), .s(s[433]), .clk(clk), .out({w_px1[88], w_px0[88]}));
MSKand_opini2_d2_pini u_sc_89 (
    .ina({c_d1[89], c_d0[89]}), .inb({S1[89], S0[89]}),
    .rnd(r[434]), .s(s[434]), .clk(clk), .out({w_sc1[89], w_sc0[89]}));
MSKand_opini2_d2_pini u_px_89 (
    .ina({x_d1[89], x_d0[89]}), .inb({pp1[89], pp0[89]}),
    .rnd(r[435]), .s(s[435]), .clk(clk), .out({w_px1[89], w_px0[89]}));
MSKand_opini2_d2_pini u_sc_90 (
    .ina({c_d1[90], c_d0[90]}), .inb({S1[90], S0[90]}),
    .rnd(r[436]), .s(s[436]), .clk(clk), .out({w_sc1[90], w_sc0[90]}));
MSKand_opini2_d2_pini u_px_90 (
    .ina({x_d1[90], x_d0[90]}), .inb({pp1[90], pp0[90]}),
    .rnd(r[437]), .s(s[437]), .clk(clk), .out({w_px1[90], w_px0[90]}));
MSKand_opini2_d2_pini u_sc_91 (
    .ina({c_d1[91], c_d0[91]}), .inb({S1[91], S0[91]}),
    .rnd(r[438]), .s(s[438]), .clk(clk), .out({w_sc1[91], w_sc0[91]}));
MSKand_opini2_d2_pini u_px_91 (
    .ina({x_d1[91], x_d0[91]}), .inb({pp1[91], pp0[91]}),
    .rnd(r[439]), .s(s[439]), .clk(clk), .out({w_px1[91], w_px0[91]}));
MSKand_opini2_d2_pini u_sc_92 (
    .ina({c_d1[92], c_d0[92]}), .inb({S1[92], S0[92]}),
    .rnd(r[440]), .s(s[440]), .clk(clk), .out({w_sc1[92], w_sc0[92]}));
MSKand_opini2_d2_pini u_px_92 (
    .ina({x_d1[92], x_d0[92]}), .inb({pp1[92], pp0[92]}),
    .rnd(r[441]), .s(s[441]), .clk(clk), .out({w_px1[92], w_px0[92]}));
MSKand_opini2_d2_pini u_sc_93 (
    .ina({c_d1[93], c_d0[93]}), .inb({S1[93], S0[93]}),
    .rnd(r[442]), .s(s[442]), .clk(clk), .out({w_sc1[93], w_sc0[93]}));
MSKand_opini2_d2_pini u_px_93 (
    .ina({x_d1[93], x_d0[93]}), .inb({pp1[93], pp0[93]}),
    .rnd(r[443]), .s(s[443]), .clk(clk), .out({w_px1[93], w_px0[93]}));
MSKand_opini2_d2_pini u_sc_94 (
    .ina({c_d1[94], c_d0[94]}), .inb({S1[94], S0[94]}),
    .rnd(r[444]), .s(s[444]), .clk(clk), .out({w_sc1[94], w_sc0[94]}));
MSKand_opini2_d2_pini u_px_94 (
    .ina({x_d1[94], x_d0[94]}), .inb({pp1[94], pp0[94]}),
    .rnd(r[445]), .s(s[445]), .clk(clk), .out({w_px1[94], w_px0[94]}));
MSKand_opini2_d2_pini u_sc_95 (
    .ina({c_d1[95], c_d0[95]}), .inb({S1[95], S0[95]}),
    .rnd(r[446]), .s(s[446]), .clk(clk), .out({w_sc1[95], w_sc0[95]}));
MSKand_opini2_d2_pini u_px_95 (
    .ina({x_d1[95], x_d0[95]}), .inb({pp1[95], pp0[95]}),
    .rnd(r[447]), .s(s[447]), .clk(clk), .out({w_px1[95], w_px0[95]}));
MSKand_opini2_d2_pini u_sc_96 (
    .ina({c_d1[96], c_d0[96]}), .inb({S1[96], S0[96]}),
    .rnd(r[448]), .s(s[448]), .clk(clk), .out({w_sc1[96], w_sc0[96]}));
MSKand_opini2_d2_pini u_px_96 (
    .ina({x_d1[96], x_d0[96]}), .inb({pp1[96], pp0[96]}),
    .rnd(r[449]), .s(s[449]), .clk(clk), .out({w_px1[96], w_px0[96]}));
MSKand_opini2_d2_pini u_sc_97 (
    .ina({c_d1[97], c_d0[97]}), .inb({S1[97], S0[97]}),
    .rnd(r[450]), .s(s[450]), .clk(clk), .out({w_sc1[97], w_sc0[97]}));
MSKand_opini2_d2_pini u_px_97 (
    .ina({x_d1[97], x_d0[97]}), .inb({pp1[97], pp0[97]}),
    .rnd(r[451]), .s(s[451]), .clk(clk), .out({w_px1[97], w_px0[97]}));
MSKand_opini2_d2_pini u_sc_98 (
    .ina({c_d1[98], c_d0[98]}), .inb({S1[98], S0[98]}),
    .rnd(r[452]), .s(s[452]), .clk(clk), .out({w_sc1[98], w_sc0[98]}));
MSKand_opini2_d2_pini u_px_98 (
    .ina({x_d1[98], x_d0[98]}), .inb({pp1[98], pp0[98]}),
    .rnd(r[453]), .s(s[453]), .clk(clk), .out({w_px1[98], w_px0[98]}));
MSKand_opini2_d2_pini u_sc_99 (
    .ina({c_d1[99], c_d0[99]}), .inb({S1[99], S0[99]}),
    .rnd(r[454]), .s(s[454]), .clk(clk), .out({w_sc1[99], w_sc0[99]}));
MSKand_opini2_d2_pini u_px_99 (
    .ina({x_d1[99], x_d0[99]}), .inb({pp1[99], pp0[99]}),
    .rnd(r[455]), .s(s[455]), .clk(clk), .out({w_px1[99], w_px0[99]}));
MSKand_opini2_d2_pini u_sc_100 (
    .ina({c_d1[100], c_d0[100]}), .inb({S1[100], S0[100]}),
    .rnd(r[456]), .s(s[456]), .clk(clk), .out({w_sc1[100], w_sc0[100]}));
MSKand_opini2_d2_pini u_px_100 (
    .ina({x_d1[100], x_d0[100]}), .inb({pp1[100], pp0[100]}),
    .rnd(r[457]), .s(s[457]), .clk(clk), .out({w_px1[100], w_px0[100]}));
MSKand_opini2_d2_pini u_sc_101 (
    .ina({c_d1[101], c_d0[101]}), .inb({S1[101], S0[101]}),
    .rnd(r[458]), .s(s[458]), .clk(clk), .out({w_sc1[101], w_sc0[101]}));
MSKand_opini2_d2_pini u_px_101 (
    .ina({x_d1[101], x_d0[101]}), .inb({pp1[101], pp0[101]}),
    .rnd(r[459]), .s(s[459]), .clk(clk), .out({w_px1[101], w_px0[101]}));
MSKand_opini2_d2_pini u_sc_102 (
    .ina({c_d1[102], c_d0[102]}), .inb({S1[102], S0[102]}),
    .rnd(r[460]), .s(s[460]), .clk(clk), .out({w_sc1[102], w_sc0[102]}));
MSKand_opini2_d2_pini u_px_102 (
    .ina({x_d1[102], x_d0[102]}), .inb({pp1[102], pp0[102]}),
    .rnd(r[461]), .s(s[461]), .clk(clk), .out({w_px1[102], w_px0[102]}));
MSKand_opini2_d2_pini u_sc_103 (
    .ina({c_d1[103], c_d0[103]}), .inb({S1[103], S0[103]}),
    .rnd(r[462]), .s(s[462]), .clk(clk), .out({w_sc1[103], w_sc0[103]}));
MSKand_opini2_d2_pini u_px_103 (
    .ina({x_d1[103], x_d0[103]}), .inb({pp1[103], pp0[103]}),
    .rnd(r[463]), .s(s[463]), .clk(clk), .out({w_px1[103], w_px0[103]}));
MSKand_opini2_d2_pini u_sc_104 (
    .ina({c_d1[104], c_d0[104]}), .inb({S1[104], S0[104]}),
    .rnd(r[464]), .s(s[464]), .clk(clk), .out({w_sc1[104], w_sc0[104]}));
MSKand_opini2_d2_pini u_px_104 (
    .ina({x_d1[104], x_d0[104]}), .inb({pp1[104], pp0[104]}),
    .rnd(r[465]), .s(s[465]), .clk(clk), .out({w_px1[104], w_px0[104]}));
MSKand_opini2_d2_pini u_sc_105 (
    .ina({c_d1[105], c_d0[105]}), .inb({S1[105], S0[105]}),
    .rnd(r[466]), .s(s[466]), .clk(clk), .out({w_sc1[105], w_sc0[105]}));
MSKand_opini2_d2_pini u_px_105 (
    .ina({x_d1[105], x_d0[105]}), .inb({pp1[105], pp0[105]}),
    .rnd(r[467]), .s(s[467]), .clk(clk), .out({w_px1[105], w_px0[105]}));
MSKand_opini2_d2_pini u_sc_106 (
    .ina({c_d1[106], c_d0[106]}), .inb({S1[106], S0[106]}),
    .rnd(r[468]), .s(s[468]), .clk(clk), .out({w_sc1[106], w_sc0[106]}));
MSKand_opini2_d2_pini u_px_106 (
    .ina({x_d1[106], x_d0[106]}), .inb({pp1[106], pp0[106]}),
    .rnd(r[469]), .s(s[469]), .clk(clk), .out({w_px1[106], w_px0[106]}));
MSKand_opini2_d2_pini u_sc_107 (
    .ina({c_d1[107], c_d0[107]}), .inb({S1[107], S0[107]}),
    .rnd(r[470]), .s(s[470]), .clk(clk), .out({w_sc1[107], w_sc0[107]}));
MSKand_opini2_d2_pini u_px_107 (
    .ina({x_d1[107], x_d0[107]}), .inb({pp1[107], pp0[107]}),
    .rnd(r[471]), .s(s[471]), .clk(clk), .out({w_px1[107], w_px0[107]}));
MSKand_opini2_d2_pini u_sc_108 (
    .ina({c_d1[108], c_d0[108]}), .inb({S1[108], S0[108]}),
    .rnd(r[472]), .s(s[472]), .clk(clk), .out({w_sc1[108], w_sc0[108]}));
MSKand_opini2_d2_pini u_px_108 (
    .ina({x_d1[108], x_d0[108]}), .inb({pp1[108], pp0[108]}),
    .rnd(r[473]), .s(s[473]), .clk(clk), .out({w_px1[108], w_px0[108]}));
MSKand_opini2_d2_pini u_sc_109 (
    .ina({c_d1[109], c_d0[109]}), .inb({S1[109], S0[109]}),
    .rnd(r[474]), .s(s[474]), .clk(clk), .out({w_sc1[109], w_sc0[109]}));
MSKand_opini2_d2_pini u_px_109 (
    .ina({x_d1[109], x_d0[109]}), .inb({pp1[109], pp0[109]}),
    .rnd(r[475]), .s(s[475]), .clk(clk), .out({w_px1[109], w_px0[109]}));
MSKand_opini2_d2_pini u_sc_110 (
    .ina({c_d1[110], c_d0[110]}), .inb({S1[110], S0[110]}),
    .rnd(r[476]), .s(s[476]), .clk(clk), .out({w_sc1[110], w_sc0[110]}));
MSKand_opini2_d2_pini u_px_110 (
    .ina({x_d1[110], x_d0[110]}), .inb({pp1[110], pp0[110]}),
    .rnd(r[477]), .s(s[477]), .clk(clk), .out({w_px1[110], w_px0[110]}));
MSKand_opini2_d2_pini u_sc_111 (
    .ina({c_d1[111], c_d0[111]}), .inb({S1[111], S0[111]}),
    .rnd(r[478]), .s(s[478]), .clk(clk), .out({w_sc1[111], w_sc0[111]}));
MSKand_opini2_d2_pini u_px_111 (
    .ina({x_d1[111], x_d0[111]}), .inb({pp1[111], pp0[111]}),
    .rnd(r[479]), .s(s[479]), .clk(clk), .out({w_px1[111], w_px0[111]}));
MSKand_opini2_d2_pini u_sc_112 (
    .ina({c_d1[112], c_d0[112]}), .inb({S1[112], S0[112]}),
    .rnd(r[480]), .s(s[480]), .clk(clk), .out({w_sc1[112], w_sc0[112]}));
MSKand_opini2_d2_pini u_px_112 (
    .ina({x_d1[112], x_d0[112]}), .inb({pp1[112], pp0[112]}),
    .rnd(r[481]), .s(s[481]), .clk(clk), .out({w_px1[112], w_px0[112]}));
MSKand_opini2_d2_pini u_sc_113 (
    .ina({c_d1[113], c_d0[113]}), .inb({S1[113], S0[113]}),
    .rnd(r[482]), .s(s[482]), .clk(clk), .out({w_sc1[113], w_sc0[113]}));
MSKand_opini2_d2_pini u_px_113 (
    .ina({x_d1[113], x_d0[113]}), .inb({pp1[113], pp0[113]}),
    .rnd(r[483]), .s(s[483]), .clk(clk), .out({w_px1[113], w_px0[113]}));
MSKand_opini2_d2_pini u_sc_114 (
    .ina({c_d1[114], c_d0[114]}), .inb({S1[114], S0[114]}),
    .rnd(r[484]), .s(s[484]), .clk(clk), .out({w_sc1[114], w_sc0[114]}));
MSKand_opini2_d2_pini u_px_114 (
    .ina({x_d1[114], x_d0[114]}), .inb({pp1[114], pp0[114]}),
    .rnd(r[485]), .s(s[485]), .clk(clk), .out({w_px1[114], w_px0[114]}));
MSKand_opini2_d2_pini u_sc_115 (
    .ina({c_d1[115], c_d0[115]}), .inb({S1[115], S0[115]}),
    .rnd(r[486]), .s(s[486]), .clk(clk), .out({w_sc1[115], w_sc0[115]}));
MSKand_opini2_d2_pini u_px_115 (
    .ina({x_d1[115], x_d0[115]}), .inb({pp1[115], pp0[115]}),
    .rnd(r[487]), .s(s[487]), .clk(clk), .out({w_px1[115], w_px0[115]}));
MSKand_opini2_d2_pini u_sc_116 (
    .ina({c_d1[116], c_d0[116]}), .inb({S1[116], S0[116]}),
    .rnd(r[488]), .s(s[488]), .clk(clk), .out({w_sc1[116], w_sc0[116]}));
MSKand_opini2_d2_pini u_px_116 (
    .ina({x_d1[116], x_d0[116]}), .inb({pp1[116], pp0[116]}),
    .rnd(r[489]), .s(s[489]), .clk(clk), .out({w_px1[116], w_px0[116]}));
MSKand_opini2_d2_pini u_sc_117 (
    .ina({c_d1[117], c_d0[117]}), .inb({S1[117], S0[117]}),
    .rnd(r[490]), .s(s[490]), .clk(clk), .out({w_sc1[117], w_sc0[117]}));
MSKand_opini2_d2_pini u_px_117 (
    .ina({x_d1[117], x_d0[117]}), .inb({pp1[117], pp0[117]}),
    .rnd(r[491]), .s(s[491]), .clk(clk), .out({w_px1[117], w_px0[117]}));
MSKand_opini2_d2_pini u_sc_118 (
    .ina({c_d1[118], c_d0[118]}), .inb({S1[118], S0[118]}),
    .rnd(r[492]), .s(s[492]), .clk(clk), .out({w_sc1[118], w_sc0[118]}));
MSKand_opini2_d2_pini u_px_118 (
    .ina({x_d1[118], x_d0[118]}), .inb({pp1[118], pp0[118]}),
    .rnd(r[493]), .s(s[493]), .clk(clk), .out({w_px1[118], w_px0[118]}));
MSKand_opini2_d2_pini u_sc_119 (
    .ina({c_d1[119], c_d0[119]}), .inb({S1[119], S0[119]}),
    .rnd(r[494]), .s(s[494]), .clk(clk), .out({w_sc1[119], w_sc0[119]}));
MSKand_opini2_d2_pini u_px_119 (
    .ina({x_d1[119], x_d0[119]}), .inb({pp1[119], pp0[119]}),
    .rnd(r[495]), .s(s[495]), .clk(clk), .out({w_px1[119], w_px0[119]}));
MSKand_opini2_d2_pini u_sc_120 (
    .ina({c_d1[120], c_d0[120]}), .inb({S1[120], S0[120]}),
    .rnd(r[496]), .s(s[496]), .clk(clk), .out({w_sc1[120], w_sc0[120]}));
MSKand_opini2_d2_pini u_px_120 (
    .ina({x_d1[120], x_d0[120]}), .inb({pp1[120], pp0[120]}),
    .rnd(r[497]), .s(s[497]), .clk(clk), .out({w_px1[120], w_px0[120]}));
MSKand_opini2_d2_pini u_sc_121 (
    .ina({c_d1[121], c_d0[121]}), .inb({S1[121], S0[121]}),
    .rnd(r[498]), .s(s[498]), .clk(clk), .out({w_sc1[121], w_sc0[121]}));
MSKand_opini2_d2_pini u_px_121 (
    .ina({x_d1[121], x_d0[121]}), .inb({pp1[121], pp0[121]}),
    .rnd(r[499]), .s(s[499]), .clk(clk), .out({w_px1[121], w_px0[121]}));
MSKand_opini2_d2_pini u_sc_122 (
    .ina({c_d1[122], c_d0[122]}), .inb({S1[122], S0[122]}),
    .rnd(r[500]), .s(s[500]), .clk(clk), .out({w_sc1[122], w_sc0[122]}));
MSKand_opini2_d2_pini u_px_122 (
    .ina({x_d1[122], x_d0[122]}), .inb({pp1[122], pp0[122]}),
    .rnd(r[501]), .s(s[501]), .clk(clk), .out({w_px1[122], w_px0[122]}));
MSKand_opini2_d2_pini u_sc_123 (
    .ina({c_d1[123], c_d0[123]}), .inb({S1[123], S0[123]}),
    .rnd(r[502]), .s(s[502]), .clk(clk), .out({w_sc1[123], w_sc0[123]}));
MSKand_opini2_d2_pini u_px_123 (
    .ina({x_d1[123], x_d0[123]}), .inb({pp1[123], pp0[123]}),
    .rnd(r[503]), .s(s[503]), .clk(clk), .out({w_px1[123], w_px0[123]}));
MSKand_opini2_d2_pini u_sc_124 (
    .ina({c_d1[124], c_d0[124]}), .inb({S1[124], S0[124]}),
    .rnd(r[504]), .s(s[504]), .clk(clk), .out({w_sc1[124], w_sc0[124]}));
MSKand_opini2_d2_pini u_px_124 (
    .ina({x_d1[124], x_d0[124]}), .inb({pp1[124], pp0[124]}),
    .rnd(r[505]), .s(s[505]), .clk(clk), .out({w_px1[124], w_px0[124]}));
MSKand_opini2_d2_pini u_sc_125 (
    .ina({c_d1[125], c_d0[125]}), .inb({S1[125], S0[125]}),
    .rnd(r[506]), .s(s[506]), .clk(clk), .out({w_sc1[125], w_sc0[125]}));
MSKand_opini2_d2_pini u_px_125 (
    .ina({x_d1[125], x_d0[125]}), .inb({pp1[125], pp0[125]}),
    .rnd(r[507]), .s(s[507]), .clk(clk), .out({w_px1[125], w_px0[125]}));
MSKand_opini2_d2_pini u_sc_126 (
    .ina({c_d1[126], c_d0[126]}), .inb({S1[126], S0[126]}),
    .rnd(r[508]), .s(s[508]), .clk(clk), .out({w_sc1[126], w_sc0[126]}));
MSKand_opini2_d2_pini u_px_126 (
    .ina({x_d1[126], x_d0[126]}), .inb({pp1[126], pp0[126]}),
    .rnd(r[509]), .s(s[509]), .clk(clk), .out({w_px1[126], w_px0[126]}));
MSKand_opini2_d2_pini u_sc_127 (
    .ina({c_d1[127], c_d0[127]}), .inb({S1[127], S0[127]}),
    .rnd(r[510]), .s(s[510]), .clk(clk), .out({w_sc1[127], w_sc0[127]}));
MSKand_opini2_d2_pini u_px_127 (
    .ina({x_d1[127], x_d0[127]}), .inb({pp1[127], pp0[127]}),
    .rnd(r[511]), .s(s[511]), .clk(clk), .out({w_px1[127], w_px0[127]}));
MSKand_opini2_d2_pini u_sc_128 (
    .ina({c_d1[128], c_d0[128]}), .inb({S1[128], S0[128]}),
    .rnd(r[512]), .s(s[512]), .clk(clk), .out({w_sc1[128], w_sc0[128]}));
MSKand_opini2_d2_pini u_px_128 (
    .ina({x_d1[128], x_d0[128]}), .inb({pp1[128], pp0[128]}),
    .rnd(r[513]), .s(s[513]), .clk(clk), .out({w_px1[128], w_px0[128]}));
MSKand_opini2_d2_pini u_sc_129 (
    .ina({c_d1[129], c_d0[129]}), .inb({S1[129], S0[129]}),
    .rnd(r[514]), .s(s[514]), .clk(clk), .out({w_sc1[129], w_sc0[129]}));
MSKand_opini2_d2_pini u_px_129 (
    .ina({x_d1[129], x_d0[129]}), .inb({pp1[129], pp0[129]}),
    .rnd(r[515]), .s(s[515]), .clk(clk), .out({w_px1[129], w_px0[129]}));
MSKand_opini2_d2_pini u_sc_130 (
    .ina({c_d1[130], c_d0[130]}), .inb({S1[130], S0[130]}),
    .rnd(r[516]), .s(s[516]), .clk(clk), .out({w_sc1[130], w_sc0[130]}));
MSKand_opini2_d2_pini u_px_130 (
    .ina({x_d1[130], x_d0[130]}), .inb({pp1[130], pp0[130]}),
    .rnd(r[517]), .s(s[517]), .clk(clk), .out({w_px1[130], w_px0[130]}));
MSKand_opini2_d2_pini u_sc_131 (
    .ina({c_d1[131], c_d0[131]}), .inb({S1[131], S0[131]}),
    .rnd(r[518]), .s(s[518]), .clk(clk), .out({w_sc1[131], w_sc0[131]}));
MSKand_opini2_d2_pini u_px_131 (
    .ina({x_d1[131], x_d0[131]}), .inb({pp1[131], pp0[131]}),
    .rnd(r[519]), .s(s[519]), .clk(clk), .out({w_px1[131], w_px0[131]}));
MSKand_opini2_d2_pini u_sc_132 (
    .ina({c_d1[132], c_d0[132]}), .inb({S1[132], S0[132]}),
    .rnd(r[520]), .s(s[520]), .clk(clk), .out({w_sc1[132], w_sc0[132]}));
MSKand_opini2_d2_pini u_px_132 (
    .ina({x_d1[132], x_d0[132]}), .inb({pp1[132], pp0[132]}),
    .rnd(r[521]), .s(s[521]), .clk(clk), .out({w_px1[132], w_px0[132]}));
MSKand_opini2_d2_pini u_sc_133 (
    .ina({c_d1[133], c_d0[133]}), .inb({S1[133], S0[133]}),
    .rnd(r[522]), .s(s[522]), .clk(clk), .out({w_sc1[133], w_sc0[133]}));
MSKand_opini2_d2_pini u_px_133 (
    .ina({x_d1[133], x_d0[133]}), .inb({pp1[133], pp0[133]}),
    .rnd(r[523]), .s(s[523]), .clk(clk), .out({w_px1[133], w_px0[133]}));
MSKand_opini2_d2_pini u_sc_134 (
    .ina({c_d1[134], c_d0[134]}), .inb({S1[134], S0[134]}),
    .rnd(r[524]), .s(s[524]), .clk(clk), .out({w_sc1[134], w_sc0[134]}));
MSKand_opini2_d2_pini u_px_134 (
    .ina({x_d1[134], x_d0[134]}), .inb({pp1[134], pp0[134]}),
    .rnd(r[525]), .s(s[525]), .clk(clk), .out({w_px1[134], w_px0[134]}));
MSKand_opini2_d2_pini u_sc_135 (
    .ina({c_d1[135], c_d0[135]}), .inb({S1[135], S0[135]}),
    .rnd(r[526]), .s(s[526]), .clk(clk), .out({w_sc1[135], w_sc0[135]}));
MSKand_opini2_d2_pini u_px_135 (
    .ina({x_d1[135], x_d0[135]}), .inb({pp1[135], pp0[135]}),
    .rnd(r[527]), .s(s[527]), .clk(clk), .out({w_px1[135], w_px0[135]}));
MSKand_opini2_d2_pini u_sc_136 (
    .ina({c_d1[136], c_d0[136]}), .inb({S1[136], S0[136]}),
    .rnd(r[528]), .s(s[528]), .clk(clk), .out({w_sc1[136], w_sc0[136]}));
MSKand_opini2_d2_pini u_px_136 (
    .ina({x_d1[136], x_d0[136]}), .inb({pp1[136], pp0[136]}),
    .rnd(r[529]), .s(s[529]), .clk(clk), .out({w_px1[136], w_px0[136]}));
MSKand_opini2_d2_pini u_sc_137 (
    .ina({c_d1[137], c_d0[137]}), .inb({S1[137], S0[137]}),
    .rnd(r[530]), .s(s[530]), .clk(clk), .out({w_sc1[137], w_sc0[137]}));
MSKand_opini2_d2_pini u_px_137 (
    .ina({x_d1[137], x_d0[137]}), .inb({pp1[137], pp0[137]}),
    .rnd(r[531]), .s(s[531]), .clk(clk), .out({w_px1[137], w_px0[137]}));
MSKand_opini2_d2_pini u_sc_138 (
    .ina({c_d1[138], c_d0[138]}), .inb({S1[138], S0[138]}),
    .rnd(r[532]), .s(s[532]), .clk(clk), .out({w_sc1[138], w_sc0[138]}));
MSKand_opini2_d2_pini u_px_138 (
    .ina({x_d1[138], x_d0[138]}), .inb({pp1[138], pp0[138]}),
    .rnd(r[533]), .s(s[533]), .clk(clk), .out({w_px1[138], w_px0[138]}));
MSKand_opini2_d2_pini u_sc_139 (
    .ina({c_d1[139], c_d0[139]}), .inb({S1[139], S0[139]}),
    .rnd(r[534]), .s(s[534]), .clk(clk), .out({w_sc1[139], w_sc0[139]}));
MSKand_opini2_d2_pini u_px_139 (
    .ina({x_d1[139], x_d0[139]}), .inb({pp1[139], pp0[139]}),
    .rnd(r[535]), .s(s[535]), .clk(clk), .out({w_px1[139], w_px0[139]}));
MSKand_opini2_d2_pini u_sc_140 (
    .ina({c_d1[140], c_d0[140]}), .inb({S1[140], S0[140]}),
    .rnd(r[536]), .s(s[536]), .clk(clk), .out({w_sc1[140], w_sc0[140]}));
MSKand_opini2_d2_pini u_px_140 (
    .ina({x_d1[140], x_d0[140]}), .inb({pp1[140], pp0[140]}),
    .rnd(r[537]), .s(s[537]), .clk(clk), .out({w_px1[140], w_px0[140]}));
MSKand_opini2_d2_pini u_sc_141 (
    .ina({c_d1[141], c_d0[141]}), .inb({S1[141], S0[141]}),
    .rnd(r[538]), .s(s[538]), .clk(clk), .out({w_sc1[141], w_sc0[141]}));
MSKand_opini2_d2_pini u_px_141 (
    .ina({x_d1[141], x_d0[141]}), .inb({pp1[141], pp0[141]}),
    .rnd(r[539]), .s(s[539]), .clk(clk), .out({w_px1[141], w_px0[141]}));
MSKand_opini2_d2_pini u_sc_142 (
    .ina({c_d1[142], c_d0[142]}), .inb({S1[142], S0[142]}),
    .rnd(r[540]), .s(s[540]), .clk(clk), .out({w_sc1[142], w_sc0[142]}));
MSKand_opini2_d2_pini u_px_142 (
    .ina({x_d1[142], x_d0[142]}), .inb({pp1[142], pp0[142]}),
    .rnd(r[541]), .s(s[541]), .clk(clk), .out({w_px1[142], w_px0[142]}));
MSKand_opini2_d2_pini u_sc_143 (
    .ina({c_d1[143], c_d0[143]}), .inb({S1[143], S0[143]}),
    .rnd(r[542]), .s(s[542]), .clk(clk), .out({w_sc1[143], w_sc0[143]}));
MSKand_opini2_d2_pini u_px_143 (
    .ina({x_d1[143], x_d0[143]}), .inb({pp1[143], pp0[143]}),
    .rnd(r[543]), .s(s[543]), .clk(clk), .out({w_px1[143], w_px0[143]}));
MSKand_opini2_d2_pini u_sc_144 (
    .ina({c_d1[144], c_d0[144]}), .inb({S1[144], S0[144]}),
    .rnd(r[544]), .s(s[544]), .clk(clk), .out({w_sc1[144], w_sc0[144]}));
MSKand_opini2_d2_pini u_px_144 (
    .ina({x_d1[144], x_d0[144]}), .inb({pp1[144], pp0[144]}),
    .rnd(r[545]), .s(s[545]), .clk(clk), .out({w_px1[144], w_px0[144]}));
MSKand_opini2_d2_pini u_sc_145 (
    .ina({c_d1[145], c_d0[145]}), .inb({S1[145], S0[145]}),
    .rnd(r[546]), .s(s[546]), .clk(clk), .out({w_sc1[145], w_sc0[145]}));
MSKand_opini2_d2_pini u_px_145 (
    .ina({x_d1[145], x_d0[145]}), .inb({pp1[145], pp0[145]}),
    .rnd(r[547]), .s(s[547]), .clk(clk), .out({w_px1[145], w_px0[145]}));
MSKand_opini2_d2_pini u_sc_146 (
    .ina({c_d1[146], c_d0[146]}), .inb({S1[146], S0[146]}),
    .rnd(r[548]), .s(s[548]), .clk(clk), .out({w_sc1[146], w_sc0[146]}));
MSKand_opini2_d2_pini u_px_146 (
    .ina({x_d1[146], x_d0[146]}), .inb({pp1[146], pp0[146]}),
    .rnd(r[549]), .s(s[549]), .clk(clk), .out({w_px1[146], w_px0[146]}));
MSKand_opini2_d2_pini u_sc_147 (
    .ina({c_d1[147], c_d0[147]}), .inb({S1[147], S0[147]}),
    .rnd(r[550]), .s(s[550]), .clk(clk), .out({w_sc1[147], w_sc0[147]}));
MSKand_opini2_d2_pini u_px_147 (
    .ina({x_d1[147], x_d0[147]}), .inb({pp1[147], pp0[147]}),
    .rnd(r[551]), .s(s[551]), .clk(clk), .out({w_px1[147], w_px0[147]}));
MSKand_opini2_d2_pini u_sc_148 (
    .ina({c_d1[148], c_d0[148]}), .inb({S1[148], S0[148]}),
    .rnd(r[552]), .s(s[552]), .clk(clk), .out({w_sc1[148], w_sc0[148]}));
MSKand_opini2_d2_pini u_px_148 (
    .ina({x_d1[148], x_d0[148]}), .inb({pp1[148], pp0[148]}),
    .rnd(r[553]), .s(s[553]), .clk(clk), .out({w_px1[148], w_px0[148]}));
MSKand_opini2_d2_pini u_sc_149 (
    .ina({c_d1[149], c_d0[149]}), .inb({S1[149], S0[149]}),
    .rnd(r[554]), .s(s[554]), .clk(clk), .out({w_sc1[149], w_sc0[149]}));
MSKand_opini2_d2_pini u_px_149 (
    .ina({x_d1[149], x_d0[149]}), .inb({pp1[149], pp0[149]}),
    .rnd(r[555]), .s(s[555]), .clk(clk), .out({w_px1[149], w_px0[149]}));
MSKand_opini2_d2_pini u_sc_150 (
    .ina({c_d1[150], c_d0[150]}), .inb({S1[150], S0[150]}),
    .rnd(r[556]), .s(s[556]), .clk(clk), .out({w_sc1[150], w_sc0[150]}));
MSKand_opini2_d2_pini u_px_150 (
    .ina({x_d1[150], x_d0[150]}), .inb({pp1[150], pp0[150]}),
    .rnd(r[557]), .s(s[557]), .clk(clk), .out({w_px1[150], w_px0[150]}));
MSKand_opini2_d2_pini u_sc_151 (
    .ina({c_d1[151], c_d0[151]}), .inb({S1[151], S0[151]}),
    .rnd(r[558]), .s(s[558]), .clk(clk), .out({w_sc1[151], w_sc0[151]}));
MSKand_opini2_d2_pini u_px_151 (
    .ina({x_d1[151], x_d0[151]}), .inb({pp1[151], pp0[151]}),
    .rnd(r[559]), .s(s[559]), .clk(clk), .out({w_px1[151], w_px0[151]}));
MSKand_opini2_d2_pini u_sc_152 (
    .ina({c_d1[152], c_d0[152]}), .inb({S1[152], S0[152]}),
    .rnd(r[560]), .s(s[560]), .clk(clk), .out({w_sc1[152], w_sc0[152]}));
MSKand_opini2_d2_pini u_px_152 (
    .ina({x_d1[152], x_d0[152]}), .inb({pp1[152], pp0[152]}),
    .rnd(r[561]), .s(s[561]), .clk(clk), .out({w_px1[152], w_px0[152]}));
MSKand_opini2_d2_pini u_sc_153 (
    .ina({c_d1[153], c_d0[153]}), .inb({S1[153], S0[153]}),
    .rnd(r[562]), .s(s[562]), .clk(clk), .out({w_sc1[153], w_sc0[153]}));
MSKand_opini2_d2_pini u_px_153 (
    .ina({x_d1[153], x_d0[153]}), .inb({pp1[153], pp0[153]}),
    .rnd(r[563]), .s(s[563]), .clk(clk), .out({w_px1[153], w_px0[153]}));
MSKand_opini2_d2_pini u_sc_154 (
    .ina({c_d1[154], c_d0[154]}), .inb({S1[154], S0[154]}),
    .rnd(r[564]), .s(s[564]), .clk(clk), .out({w_sc1[154], w_sc0[154]}));
MSKand_opini2_d2_pini u_px_154 (
    .ina({x_d1[154], x_d0[154]}), .inb({pp1[154], pp0[154]}),
    .rnd(r[565]), .s(s[565]), .clk(clk), .out({w_px1[154], w_px0[154]}));
MSKand_opini2_d2_pini u_sc_155 (
    .ina({c_d1[155], c_d0[155]}), .inb({S1[155], S0[155]}),
    .rnd(r[566]), .s(s[566]), .clk(clk), .out({w_sc1[155], w_sc0[155]}));
MSKand_opini2_d2_pini u_px_155 (
    .ina({x_d1[155], x_d0[155]}), .inb({pp1[155], pp0[155]}),
    .rnd(r[567]), .s(s[567]), .clk(clk), .out({w_px1[155], w_px0[155]}));
MSKand_opini2_d2_pini u_sc_156 (
    .ina({c_d1[156], c_d0[156]}), .inb({S1[156], S0[156]}),
    .rnd(r[568]), .s(s[568]), .clk(clk), .out({w_sc1[156], w_sc0[156]}));
MSKand_opini2_d2_pini u_px_156 (
    .ina({x_d1[156], x_d0[156]}), .inb({pp1[156], pp0[156]}),
    .rnd(r[569]), .s(s[569]), .clk(clk), .out({w_px1[156], w_px0[156]}));
MSKand_opini2_d2_pini u_sc_157 (
    .ina({c_d1[157], c_d0[157]}), .inb({S1[157], S0[157]}),
    .rnd(r[570]), .s(s[570]), .clk(clk), .out({w_sc1[157], w_sc0[157]}));
MSKand_opini2_d2_pini u_px_157 (
    .ina({x_d1[157], x_d0[157]}), .inb({pp1[157], pp0[157]}),
    .rnd(r[571]), .s(s[571]), .clk(clk), .out({w_px1[157], w_px0[157]}));
MSKand_opini2_d2_pini u_sc_158 (
    .ina({c_d1[158], c_d0[158]}), .inb({S1[158], S0[158]}),
    .rnd(r[572]), .s(s[572]), .clk(clk), .out({w_sc1[158], w_sc0[158]}));
MSKand_opini2_d2_pini u_px_158 (
    .ina({x_d1[158], x_d0[158]}), .inb({pp1[158], pp0[158]}),
    .rnd(r[573]), .s(s[573]), .clk(clk), .out({w_px1[158], w_px0[158]}));
MSKand_opini2_d2_pini u_sc_159 (
    .ina({c_d1[159], c_d0[159]}), .inb({S1[159], S0[159]}),
    .rnd(r[574]), .s(s[574]), .clk(clk), .out({w_sc1[159], w_sc0[159]}));
MSKand_opini2_d2_pini u_px_159 (
    .ina({x_d1[159], x_d0[159]}), .inb({pp1[159], pp0[159]}),
    .rnd(r[575]), .s(s[575]), .clk(clk), .out({w_px1[159], w_px0[159]}));
MSKand_opini2_d2_pini u_sc_160 (
    .ina({c_d1[160], c_d0[160]}), .inb({S1[160], S0[160]}),
    .rnd(r[576]), .s(s[576]), .clk(clk), .out({w_sc1[160], w_sc0[160]}));
MSKand_opini2_d2_pini u_px_160 (
    .ina({x_d1[160], x_d0[160]}), .inb({pp1[160], pp0[160]}),
    .rnd(r[577]), .s(s[577]), .clk(clk), .out({w_px1[160], w_px0[160]}));
MSKand_opini2_d2_pini u_sc_161 (
    .ina({c_d1[161], c_d0[161]}), .inb({S1[161], S0[161]}),
    .rnd(r[578]), .s(s[578]), .clk(clk), .out({w_sc1[161], w_sc0[161]}));
MSKand_opini2_d2_pini u_px_161 (
    .ina({x_d1[161], x_d0[161]}), .inb({pp1[161], pp0[161]}),
    .rnd(r[579]), .s(s[579]), .clk(clk), .out({w_px1[161], w_px0[161]}));
MSKand_opini2_d2_pini u_sc_162 (
    .ina({c_d1[162], c_d0[162]}), .inb({S1[162], S0[162]}),
    .rnd(r[580]), .s(s[580]), .clk(clk), .out({w_sc1[162], w_sc0[162]}));
MSKand_opini2_d2_pini u_px_162 (
    .ina({x_d1[162], x_d0[162]}), .inb({pp1[162], pp0[162]}),
    .rnd(r[581]), .s(s[581]), .clk(clk), .out({w_px1[162], w_px0[162]}));
MSKand_opini2_d2_pini u_sc_163 (
    .ina({c_d1[163], c_d0[163]}), .inb({S1[163], S0[163]}),
    .rnd(r[582]), .s(s[582]), .clk(clk), .out({w_sc1[163], w_sc0[163]}));
MSKand_opini2_d2_pini u_px_163 (
    .ina({x_d1[163], x_d0[163]}), .inb({pp1[163], pp0[163]}),
    .rnd(r[583]), .s(s[583]), .clk(clk), .out({w_px1[163], w_px0[163]}));
MSKand_opini2_d2_pini u_sc_164 (
    .ina({c_d1[164], c_d0[164]}), .inb({S1[164], S0[164]}),
    .rnd(r[584]), .s(s[584]), .clk(clk), .out({w_sc1[164], w_sc0[164]}));
MSKand_opini2_d2_pini u_px_164 (
    .ina({x_d1[164], x_d0[164]}), .inb({pp1[164], pp0[164]}),
    .rnd(r[585]), .s(s[585]), .clk(clk), .out({w_px1[164], w_px0[164]}));
MSKand_opini2_d2_pini u_sc_165 (
    .ina({c_d1[165], c_d0[165]}), .inb({S1[165], S0[165]}),
    .rnd(r[586]), .s(s[586]), .clk(clk), .out({w_sc1[165], w_sc0[165]}));
MSKand_opini2_d2_pini u_px_165 (
    .ina({x_d1[165], x_d0[165]}), .inb({pp1[165], pp0[165]}),
    .rnd(r[587]), .s(s[587]), .clk(clk), .out({w_px1[165], w_px0[165]}));
MSKand_opini2_d2_pini u_sc_166 (
    .ina({c_d1[166], c_d0[166]}), .inb({S1[166], S0[166]}),
    .rnd(r[588]), .s(s[588]), .clk(clk), .out({w_sc1[166], w_sc0[166]}));
MSKand_opini2_d2_pini u_px_166 (
    .ina({x_d1[166], x_d0[166]}), .inb({pp1[166], pp0[166]}),
    .rnd(r[589]), .s(s[589]), .clk(clk), .out({w_px1[166], w_px0[166]}));
MSKand_opini2_d2_pini u_sc_167 (
    .ina({c_d1[167], c_d0[167]}), .inb({S1[167], S0[167]}),
    .rnd(r[590]), .s(s[590]), .clk(clk), .out({w_sc1[167], w_sc0[167]}));
MSKand_opini2_d2_pini u_px_167 (
    .ina({x_d1[167], x_d0[167]}), .inb({pp1[167], pp0[167]}),
    .rnd(r[591]), .s(s[591]), .clk(clk), .out({w_px1[167], w_px0[167]}));
MSKand_opini2_d2_pini u_sc_168 (
    .ina({c_d1[168], c_d0[168]}), .inb({S1[168], S0[168]}),
    .rnd(r[592]), .s(s[592]), .clk(clk), .out({w_sc1[168], w_sc0[168]}));
MSKand_opini2_d2_pini u_px_168 (
    .ina({x_d1[168], x_d0[168]}), .inb({pp1[168], pp0[168]}),
    .rnd(r[593]), .s(s[593]), .clk(clk), .out({w_px1[168], w_px0[168]}));
MSKand_opini2_d2_pini u_sc_169 (
    .ina({c_d1[169], c_d0[169]}), .inb({S1[169], S0[169]}),
    .rnd(r[594]), .s(s[594]), .clk(clk), .out({w_sc1[169], w_sc0[169]}));
MSKand_opini2_d2_pini u_px_169 (
    .ina({x_d1[169], x_d0[169]}), .inb({pp1[169], pp0[169]}),
    .rnd(r[595]), .s(s[595]), .clk(clk), .out({w_px1[169], w_px0[169]}));
MSKand_opini2_d2_pini u_sc_170 (
    .ina({c_d1[170], c_d0[170]}), .inb({S1[170], S0[170]}),
    .rnd(r[596]), .s(s[596]), .clk(clk), .out({w_sc1[170], w_sc0[170]}));
MSKand_opini2_d2_pini u_px_170 (
    .ina({x_d1[170], x_d0[170]}), .inb({pp1[170], pp0[170]}),
    .rnd(r[597]), .s(s[597]), .clk(clk), .out({w_px1[170], w_px0[170]}));
MSKand_opini2_d2_pini u_sc_171 (
    .ina({c_d1[171], c_d0[171]}), .inb({S1[171], S0[171]}),
    .rnd(r[598]), .s(s[598]), .clk(clk), .out({w_sc1[171], w_sc0[171]}));
MSKand_opini2_d2_pini u_px_171 (
    .ina({x_d1[171], x_d0[171]}), .inb({pp1[171], pp0[171]}),
    .rnd(r[599]), .s(s[599]), .clk(clk), .out({w_px1[171], w_px0[171]}));
MSKand_opini2_d2_pini u_sc_172 (
    .ina({c_d1[172], c_d0[172]}), .inb({S1[172], S0[172]}),
    .rnd(r[600]), .s(s[600]), .clk(clk), .out({w_sc1[172], w_sc0[172]}));
MSKand_opini2_d2_pini u_px_172 (
    .ina({x_d1[172], x_d0[172]}), .inb({pp1[172], pp0[172]}),
    .rnd(r[601]), .s(s[601]), .clk(clk), .out({w_px1[172], w_px0[172]}));
MSKand_opini2_d2_pini u_sc_173 (
    .ina({c_d1[173], c_d0[173]}), .inb({S1[173], S0[173]}),
    .rnd(r[602]), .s(s[602]), .clk(clk), .out({w_sc1[173], w_sc0[173]}));
MSKand_opini2_d2_pini u_px_173 (
    .ina({x_d1[173], x_d0[173]}), .inb({pp1[173], pp0[173]}),
    .rnd(r[603]), .s(s[603]), .clk(clk), .out({w_px1[173], w_px0[173]}));
MSKand_opini2_d2_pini u_sc_174 (
    .ina({c_d1[174], c_d0[174]}), .inb({S1[174], S0[174]}),
    .rnd(r[604]), .s(s[604]), .clk(clk), .out({w_sc1[174], w_sc0[174]}));
MSKand_opini2_d2_pini u_px_174 (
    .ina({x_d1[174], x_d0[174]}), .inb({pp1[174], pp0[174]}),
    .rnd(r[605]), .s(s[605]), .clk(clk), .out({w_px1[174], w_px0[174]}));
MSKand_opini2_d2_pini u_sc_175 (
    .ina({c_d1[175], c_d0[175]}), .inb({S1[175], S0[175]}),
    .rnd(r[606]), .s(s[606]), .clk(clk), .out({w_sc1[175], w_sc0[175]}));
MSKand_opini2_d2_pini u_px_175 (
    .ina({x_d1[175], x_d0[175]}), .inb({pp1[175], pp0[175]}),
    .rnd(r[607]), .s(s[607]), .clk(clk), .out({w_px1[175], w_px0[175]}));
MSKand_opini2_d2_pini u_sc_176 (
    .ina({c_d1[176], c_d0[176]}), .inb({S1[176], S0[176]}),
    .rnd(r[608]), .s(s[608]), .clk(clk), .out({w_sc1[176], w_sc0[176]}));
MSKand_opini2_d2_pini u_px_176 (
    .ina({x_d1[176], x_d0[176]}), .inb({pp1[176], pp0[176]}),
    .rnd(r[609]), .s(s[609]), .clk(clk), .out({w_px1[176], w_px0[176]}));
MSKand_opini2_d2_pini u_sc_177 (
    .ina({c_d1[177], c_d0[177]}), .inb({S1[177], S0[177]}),
    .rnd(r[610]), .s(s[610]), .clk(clk), .out({w_sc1[177], w_sc0[177]}));
MSKand_opini2_d2_pini u_px_177 (
    .ina({x_d1[177], x_d0[177]}), .inb({pp1[177], pp0[177]}),
    .rnd(r[611]), .s(s[611]), .clk(clk), .out({w_px1[177], w_px0[177]}));
MSKand_opini2_d2_pini u_sc_178 (
    .ina({c_d1[178], c_d0[178]}), .inb({S1[178], S0[178]}),
    .rnd(r[612]), .s(s[612]), .clk(clk), .out({w_sc1[178], w_sc0[178]}));
MSKand_opini2_d2_pini u_px_178 (
    .ina({x_d1[178], x_d0[178]}), .inb({pp1[178], pp0[178]}),
    .rnd(r[613]), .s(s[613]), .clk(clk), .out({w_px1[178], w_px0[178]}));
MSKand_opini2_d2_pini u_sc_179 (
    .ina({c_d1[179], c_d0[179]}), .inb({S1[179], S0[179]}),
    .rnd(r[614]), .s(s[614]), .clk(clk), .out({w_sc1[179], w_sc0[179]}));
MSKand_opini2_d2_pini u_px_179 (
    .ina({x_d1[179], x_d0[179]}), .inb({pp1[179], pp0[179]}),
    .rnd(r[615]), .s(s[615]), .clk(clk), .out({w_px1[179], w_px0[179]}));
MSKand_opini2_d2_pini u_sc_180 (
    .ina({c_d1[180], c_d0[180]}), .inb({S1[180], S0[180]}),
    .rnd(r[616]), .s(s[616]), .clk(clk), .out({w_sc1[180], w_sc0[180]}));
MSKand_opini2_d2_pini u_px_180 (
    .ina({x_d1[180], x_d0[180]}), .inb({pp1[180], pp0[180]}),
    .rnd(r[617]), .s(s[617]), .clk(clk), .out({w_px1[180], w_px0[180]}));
MSKand_opini2_d2_pini u_sc_181 (
    .ina({c_d1[181], c_d0[181]}), .inb({S1[181], S0[181]}),
    .rnd(r[618]), .s(s[618]), .clk(clk), .out({w_sc1[181], w_sc0[181]}));
MSKand_opini2_d2_pini u_px_181 (
    .ina({x_d1[181], x_d0[181]}), .inb({pp1[181], pp0[181]}),
    .rnd(r[619]), .s(s[619]), .clk(clk), .out({w_px1[181], w_px0[181]}));
MSKand_opini2_d2_pini u_sc_182 (
    .ina({c_d1[182], c_d0[182]}), .inb({S1[182], S0[182]}),
    .rnd(r[620]), .s(s[620]), .clk(clk), .out({w_sc1[182], w_sc0[182]}));
MSKand_opini2_d2_pini u_px_182 (
    .ina({x_d1[182], x_d0[182]}), .inb({pp1[182], pp0[182]}),
    .rnd(r[621]), .s(s[621]), .clk(clk), .out({w_px1[182], w_px0[182]}));
MSKand_opini2_d2_pini u_sc_183 (
    .ina({c_d1[183], c_d0[183]}), .inb({S1[183], S0[183]}),
    .rnd(r[622]), .s(s[622]), .clk(clk), .out({w_sc1[183], w_sc0[183]}));
MSKand_opini2_d2_pini u_px_183 (
    .ina({x_d1[183], x_d0[183]}), .inb({pp1[183], pp0[183]}),
    .rnd(r[623]), .s(s[623]), .clk(clk), .out({w_px1[183], w_px0[183]}));
MSKand_opini2_d2_pini u_sc_184 (
    .ina({c_d1[184], c_d0[184]}), .inb({S1[184], S0[184]}),
    .rnd(r[624]), .s(s[624]), .clk(clk), .out({w_sc1[184], w_sc0[184]}));
MSKand_opini2_d2_pini u_px_184 (
    .ina({x_d1[184], x_d0[184]}), .inb({pp1[184], pp0[184]}),
    .rnd(r[625]), .s(s[625]), .clk(clk), .out({w_px1[184], w_px0[184]}));
MSKand_opini2_d2_pini u_sc_185 (
    .ina({c_d1[185], c_d0[185]}), .inb({S1[185], S0[185]}),
    .rnd(r[626]), .s(s[626]), .clk(clk), .out({w_sc1[185], w_sc0[185]}));
MSKand_opini2_d2_pini u_px_185 (
    .ina({x_d1[185], x_d0[185]}), .inb({pp1[185], pp0[185]}),
    .rnd(r[627]), .s(s[627]), .clk(clk), .out({w_px1[185], w_px0[185]}));
MSKand_opini2_d2_pini u_sc_186 (
    .ina({c_d1[186], c_d0[186]}), .inb({S1[186], S0[186]}),
    .rnd(r[628]), .s(s[628]), .clk(clk), .out({w_sc1[186], w_sc0[186]}));
MSKand_opini2_d2_pini u_px_186 (
    .ina({x_d1[186], x_d0[186]}), .inb({pp1[186], pp0[186]}),
    .rnd(r[629]), .s(s[629]), .clk(clk), .out({w_px1[186], w_px0[186]}));
MSKand_opini2_d2_pini u_sc_187 (
    .ina({c_d1[187], c_d0[187]}), .inb({S1[187], S0[187]}),
    .rnd(r[630]), .s(s[630]), .clk(clk), .out({w_sc1[187], w_sc0[187]}));
MSKand_opini2_d2_pini u_px_187 (
    .ina({x_d1[187], x_d0[187]}), .inb({pp1[187], pp0[187]}),
    .rnd(r[631]), .s(s[631]), .clk(clk), .out({w_px1[187], w_px0[187]}));
MSKand_opini2_d2_pini u_sc_188 (
    .ina({c_d1[188], c_d0[188]}), .inb({S1[188], S0[188]}),
    .rnd(r[632]), .s(s[632]), .clk(clk), .out({w_sc1[188], w_sc0[188]}));
MSKand_opini2_d2_pini u_px_188 (
    .ina({x_d1[188], x_d0[188]}), .inb({pp1[188], pp0[188]}),
    .rnd(r[633]), .s(s[633]), .clk(clk), .out({w_px1[188], w_px0[188]}));
MSKand_opini2_d2_pini u_sc_189 (
    .ina({c_d1[189], c_d0[189]}), .inb({S1[189], S0[189]}),
    .rnd(r[634]), .s(s[634]), .clk(clk), .out({w_sc1[189], w_sc0[189]}));
MSKand_opini2_d2_pini u_px_189 (
    .ina({x_d1[189], x_d0[189]}), .inb({pp1[189], pp0[189]}),
    .rnd(r[635]), .s(s[635]), .clk(clk), .out({w_px1[189], w_px0[189]}));
MSKand_opini2_d2_pini u_sc_190 (
    .ina({c_d1[190], c_d0[190]}), .inb({S1[190], S0[190]}),
    .rnd(r[636]), .s(s[636]), .clk(clk), .out({w_sc1[190], w_sc0[190]}));
MSKand_opini2_d2_pini u_px_190 (
    .ina({x_d1[190], x_d0[190]}), .inb({pp1[190], pp0[190]}),
    .rnd(r[637]), .s(s[637]), .clk(clk), .out({w_px1[190], w_px0[190]}));
MSKand_opini2_d2_pini u_sc_191 (
    .ina({c_d1[191], c_d0[191]}), .inb({S1[191], S0[191]}),
    .rnd(r[638]), .s(s[638]), .clk(clk), .out({w_sc1[191], w_sc0[191]}));
MSKand_opini2_d2_pini u_px_191 (
    .ina({x_d1[191], x_d0[191]}), .inb({pp1[191], pp0[191]}),
    .rnd(r[639]), .s(s[639]), .clk(clk), .out({w_px1[191], w_px0[191]}));
MSKand_opini2_d2_pini u_sc_192 (
    .ina({c_d1[192], c_d0[192]}), .inb({S1[192], S0[192]}),
    .rnd(r[640]), .s(s[640]), .clk(clk), .out({w_sc1[192], w_sc0[192]}));
MSKand_opini2_d2_pini u_px_192 (
    .ina({x_d1[192], x_d0[192]}), .inb({pp1[192], pp0[192]}),
    .rnd(r[641]), .s(s[641]), .clk(clk), .out({w_px1[192], w_px0[192]}));
MSKand_opini2_d2_pini u_sc_193 (
    .ina({c_d1[193], c_d0[193]}), .inb({S1[193], S0[193]}),
    .rnd(r[642]), .s(s[642]), .clk(clk), .out({w_sc1[193], w_sc0[193]}));
MSKand_opini2_d2_pini u_px_193 (
    .ina({x_d1[193], x_d0[193]}), .inb({pp1[193], pp0[193]}),
    .rnd(r[643]), .s(s[643]), .clk(clk), .out({w_px1[193], w_px0[193]}));
MSKand_opini2_d2_pini u_sc_194 (
    .ina({c_d1[194], c_d0[194]}), .inb({S1[194], S0[194]}),
    .rnd(r[644]), .s(s[644]), .clk(clk), .out({w_sc1[194], w_sc0[194]}));
MSKand_opini2_d2_pini u_px_194 (
    .ina({x_d1[194], x_d0[194]}), .inb({pp1[194], pp0[194]}),
    .rnd(r[645]), .s(s[645]), .clk(clk), .out({w_px1[194], w_px0[194]}));
MSKand_opini2_d2_pini u_sc_195 (
    .ina({c_d1[195], c_d0[195]}), .inb({S1[195], S0[195]}),
    .rnd(r[646]), .s(s[646]), .clk(clk), .out({w_sc1[195], w_sc0[195]}));
MSKand_opini2_d2_pini u_px_195 (
    .ina({x_d1[195], x_d0[195]}), .inb({pp1[195], pp0[195]}),
    .rnd(r[647]), .s(s[647]), .clk(clk), .out({w_px1[195], w_px0[195]}));
MSKand_opini2_d2_pini u_sc_196 (
    .ina({c_d1[196], c_d0[196]}), .inb({S1[196], S0[196]}),
    .rnd(r[648]), .s(s[648]), .clk(clk), .out({w_sc1[196], w_sc0[196]}));
MSKand_opini2_d2_pini u_px_196 (
    .ina({x_d1[196], x_d0[196]}), .inb({pp1[196], pp0[196]}),
    .rnd(r[649]), .s(s[649]), .clk(clk), .out({w_px1[196], w_px0[196]}));
MSKand_opini2_d2_pini u_sc_197 (
    .ina({c_d1[197], c_d0[197]}), .inb({S1[197], S0[197]}),
    .rnd(r[650]), .s(s[650]), .clk(clk), .out({w_sc1[197], w_sc0[197]}));
MSKand_opini2_d2_pini u_px_197 (
    .ina({x_d1[197], x_d0[197]}), .inb({pp1[197], pp0[197]}),
    .rnd(r[651]), .s(s[651]), .clk(clk), .out({w_px1[197], w_px0[197]}));
MSKand_opini2_d2_pini u_sc_198 (
    .ina({c_d1[198], c_d0[198]}), .inb({S1[198], S0[198]}),
    .rnd(r[652]), .s(s[652]), .clk(clk), .out({w_sc1[198], w_sc0[198]}));
MSKand_opini2_d2_pini u_px_198 (
    .ina({x_d1[198], x_d0[198]}), .inb({pp1[198], pp0[198]}),
    .rnd(r[653]), .s(s[653]), .clk(clk), .out({w_px1[198], w_px0[198]}));
MSKand_opini2_d2_pini u_sc_199 (
    .ina({c_d1[199], c_d0[199]}), .inb({S1[199], S0[199]}),
    .rnd(r[654]), .s(s[654]), .clk(clk), .out({w_sc1[199], w_sc0[199]}));
MSKand_opini2_d2_pini u_px_199 (
    .ina({x_d1[199], x_d0[199]}), .inb({pp1[199], pp0[199]}),
    .rnd(r[655]), .s(s[655]), .clk(clk), .out({w_px1[199], w_px0[199]}));
MSKand_opini2_d2_pini u_sc_200 (
    .ina({c_d1[200], c_d0[200]}), .inb({S1[200], S0[200]}),
    .rnd(r[656]), .s(s[656]), .clk(clk), .out({w_sc1[200], w_sc0[200]}));
MSKand_opini2_d2_pini u_px_200 (
    .ina({x_d1[200], x_d0[200]}), .inb({pp1[200], pp0[200]}),
    .rnd(r[657]), .s(s[657]), .clk(clk), .out({w_px1[200], w_px0[200]}));
MSKand_opini2_d2_pini u_sc_201 (
    .ina({c_d1[201], c_d0[201]}), .inb({S1[201], S0[201]}),
    .rnd(r[658]), .s(s[658]), .clk(clk), .out({w_sc1[201], w_sc0[201]}));
MSKand_opini2_d2_pini u_px_201 (
    .ina({x_d1[201], x_d0[201]}), .inb({pp1[201], pp0[201]}),
    .rnd(r[659]), .s(s[659]), .clk(clk), .out({w_px1[201], w_px0[201]}));
MSKand_opini2_d2_pini u_sc_202 (
    .ina({c_d1[202], c_d0[202]}), .inb({S1[202], S0[202]}),
    .rnd(r[660]), .s(s[660]), .clk(clk), .out({w_sc1[202], w_sc0[202]}));
MSKand_opini2_d2_pini u_px_202 (
    .ina({x_d1[202], x_d0[202]}), .inb({pp1[202], pp0[202]}),
    .rnd(r[661]), .s(s[661]), .clk(clk), .out({w_px1[202], w_px0[202]}));
MSKand_opini2_d2_pini u_sc_203 (
    .ina({c_d1[203], c_d0[203]}), .inb({S1[203], S0[203]}),
    .rnd(r[662]), .s(s[662]), .clk(clk), .out({w_sc1[203], w_sc0[203]}));
MSKand_opini2_d2_pini u_px_203 (
    .ina({x_d1[203], x_d0[203]}), .inb({pp1[203], pp0[203]}),
    .rnd(r[663]), .s(s[663]), .clk(clk), .out({w_px1[203], w_px0[203]}));
MSKand_opini2_d2_pini u_sc_204 (
    .ina({c_d1[204], c_d0[204]}), .inb({S1[204], S0[204]}),
    .rnd(r[664]), .s(s[664]), .clk(clk), .out({w_sc1[204], w_sc0[204]}));
MSKand_opini2_d2_pini u_px_204 (
    .ina({x_d1[204], x_d0[204]}), .inb({pp1[204], pp0[204]}),
    .rnd(r[665]), .s(s[665]), .clk(clk), .out({w_px1[204], w_px0[204]}));
MSKand_opini2_d2_pini u_sc_205 (
    .ina({c_d1[205], c_d0[205]}), .inb({S1[205], S0[205]}),
    .rnd(r[666]), .s(s[666]), .clk(clk), .out({w_sc1[205], w_sc0[205]}));
MSKand_opini2_d2_pini u_px_205 (
    .ina({x_d1[205], x_d0[205]}), .inb({pp1[205], pp0[205]}),
    .rnd(r[667]), .s(s[667]), .clk(clk), .out({w_px1[205], w_px0[205]}));
MSKand_opini2_d2_pini u_sc_206 (
    .ina({c_d1[206], c_d0[206]}), .inb({S1[206], S0[206]}),
    .rnd(r[668]), .s(s[668]), .clk(clk), .out({w_sc1[206], w_sc0[206]}));
MSKand_opini2_d2_pini u_px_206 (
    .ina({x_d1[206], x_d0[206]}), .inb({pp1[206], pp0[206]}),
    .rnd(r[669]), .s(s[669]), .clk(clk), .out({w_px1[206], w_px0[206]}));
MSKand_opini2_d2_pini u_sc_207 (
    .ina({c_d1[207], c_d0[207]}), .inb({S1[207], S0[207]}),
    .rnd(r[670]), .s(s[670]), .clk(clk), .out({w_sc1[207], w_sc0[207]}));
MSKand_opini2_d2_pini u_px_207 (
    .ina({x_d1[207], x_d0[207]}), .inb({pp1[207], pp0[207]}),
    .rnd(r[671]), .s(s[671]), .clk(clk), .out({w_px1[207], w_px0[207]}));
MSKand_opini2_d2_pini u_sc_208 (
    .ina({c_d1[208], c_d0[208]}), .inb({S1[208], S0[208]}),
    .rnd(r[672]), .s(s[672]), .clk(clk), .out({w_sc1[208], w_sc0[208]}));
MSKand_opini2_d2_pini u_px_208 (
    .ina({x_d1[208], x_d0[208]}), .inb({pp1[208], pp0[208]}),
    .rnd(r[673]), .s(s[673]), .clk(clk), .out({w_px1[208], w_px0[208]}));
MSKand_opini2_d2_pini u_sc_209 (
    .ina({c_d1[209], c_d0[209]}), .inb({S1[209], S0[209]}),
    .rnd(r[674]), .s(s[674]), .clk(clk), .out({w_sc1[209], w_sc0[209]}));
MSKand_opini2_d2_pini u_px_209 (
    .ina({x_d1[209], x_d0[209]}), .inb({pp1[209], pp0[209]}),
    .rnd(r[675]), .s(s[675]), .clk(clk), .out({w_px1[209], w_px0[209]}));
MSKand_opini2_d2_pini u_sc_210 (
    .ina({c_d1[210], c_d0[210]}), .inb({S1[210], S0[210]}),
    .rnd(r[676]), .s(s[676]), .clk(clk), .out({w_sc1[210], w_sc0[210]}));
MSKand_opini2_d2_pini u_px_210 (
    .ina({x_d1[210], x_d0[210]}), .inb({pp1[210], pp0[210]}),
    .rnd(r[677]), .s(s[677]), .clk(clk), .out({w_px1[210], w_px0[210]}));
MSKand_opini2_d2_pini u_sc_211 (
    .ina({c_d1[211], c_d0[211]}), .inb({S1[211], S0[211]}),
    .rnd(r[678]), .s(s[678]), .clk(clk), .out({w_sc1[211], w_sc0[211]}));
MSKand_opini2_d2_pini u_px_211 (
    .ina({x_d1[211], x_d0[211]}), .inb({pp1[211], pp0[211]}),
    .rnd(r[679]), .s(s[679]), .clk(clk), .out({w_px1[211], w_px0[211]}));
MSKand_opini2_d2_pini u_sc_212 (
    .ina({c_d1[212], c_d0[212]}), .inb({S1[212], S0[212]}),
    .rnd(r[680]), .s(s[680]), .clk(clk), .out({w_sc1[212], w_sc0[212]}));
MSKand_opini2_d2_pini u_px_212 (
    .ina({x_d1[212], x_d0[212]}), .inb({pp1[212], pp0[212]}),
    .rnd(r[681]), .s(s[681]), .clk(clk), .out({w_px1[212], w_px0[212]}));
MSKand_opini2_d2_pini u_sc_213 (
    .ina({c_d1[213], c_d0[213]}), .inb({S1[213], S0[213]}),
    .rnd(r[682]), .s(s[682]), .clk(clk), .out({w_sc1[213], w_sc0[213]}));
MSKand_opini2_d2_pini u_px_213 (
    .ina({x_d1[213], x_d0[213]}), .inb({pp1[213], pp0[213]}),
    .rnd(r[683]), .s(s[683]), .clk(clk), .out({w_px1[213], w_px0[213]}));
MSKand_opini2_d2_pini u_sc_214 (
    .ina({c_d1[214], c_d0[214]}), .inb({S1[214], S0[214]}),
    .rnd(r[684]), .s(s[684]), .clk(clk), .out({w_sc1[214], w_sc0[214]}));
MSKand_opini2_d2_pini u_px_214 (
    .ina({x_d1[214], x_d0[214]}), .inb({pp1[214], pp0[214]}),
    .rnd(r[685]), .s(s[685]), .clk(clk), .out({w_px1[214], w_px0[214]}));
MSKand_opini2_d2_pini u_sc_215 (
    .ina({c_d1[215], c_d0[215]}), .inb({S1[215], S0[215]}),
    .rnd(r[686]), .s(s[686]), .clk(clk), .out({w_sc1[215], w_sc0[215]}));
MSKand_opini2_d2_pini u_px_215 (
    .ina({x_d1[215], x_d0[215]}), .inb({pp1[215], pp0[215]}),
    .rnd(r[687]), .s(s[687]), .clk(clk), .out({w_px1[215], w_px0[215]}));
MSKand_opini2_d2_pini u_sc_216 (
    .ina({c_d1[216], c_d0[216]}), .inb({S1[216], S0[216]}),
    .rnd(r[688]), .s(s[688]), .clk(clk), .out({w_sc1[216], w_sc0[216]}));
MSKand_opini2_d2_pini u_px_216 (
    .ina({x_d1[216], x_d0[216]}), .inb({pp1[216], pp0[216]}),
    .rnd(r[689]), .s(s[689]), .clk(clk), .out({w_px1[216], w_px0[216]}));
MSKand_opini2_d2_pini u_sc_217 (
    .ina({c_d1[217], c_d0[217]}), .inb({S1[217], S0[217]}),
    .rnd(r[690]), .s(s[690]), .clk(clk), .out({w_sc1[217], w_sc0[217]}));
MSKand_opini2_d2_pini u_px_217 (
    .ina({x_d1[217], x_d0[217]}), .inb({pp1[217], pp0[217]}),
    .rnd(r[691]), .s(s[691]), .clk(clk), .out({w_px1[217], w_px0[217]}));
MSKand_opini2_d2_pini u_sc_218 (
    .ina({c_d1[218], c_d0[218]}), .inb({S1[218], S0[218]}),
    .rnd(r[692]), .s(s[692]), .clk(clk), .out({w_sc1[218], w_sc0[218]}));
MSKand_opini2_d2_pini u_px_218 (
    .ina({x_d1[218], x_d0[218]}), .inb({pp1[218], pp0[218]}),
    .rnd(r[693]), .s(s[693]), .clk(clk), .out({w_px1[218], w_px0[218]}));
MSKand_opini2_d2_pini u_sc_219 (
    .ina({c_d1[219], c_d0[219]}), .inb({S1[219], S0[219]}),
    .rnd(r[694]), .s(s[694]), .clk(clk), .out({w_sc1[219], w_sc0[219]}));
MSKand_opini2_d2_pini u_px_219 (
    .ina({x_d1[219], x_d0[219]}), .inb({pp1[219], pp0[219]}),
    .rnd(r[695]), .s(s[695]), .clk(clk), .out({w_px1[219], w_px0[219]}));
MSKand_opini2_d2_pini u_sc_220 (
    .ina({c_d1[220], c_d0[220]}), .inb({S1[220], S0[220]}),
    .rnd(r[696]), .s(s[696]), .clk(clk), .out({w_sc1[220], w_sc0[220]}));
MSKand_opini2_d2_pini u_px_220 (
    .ina({x_d1[220], x_d0[220]}), .inb({pp1[220], pp0[220]}),
    .rnd(r[697]), .s(s[697]), .clk(clk), .out({w_px1[220], w_px0[220]}));
MSKand_opini2_d2_pini u_sc_221 (
    .ina({c_d1[221], c_d0[221]}), .inb({S1[221], S0[221]}),
    .rnd(r[698]), .s(s[698]), .clk(clk), .out({w_sc1[221], w_sc0[221]}));
MSKand_opini2_d2_pini u_px_221 (
    .ina({x_d1[221], x_d0[221]}), .inb({pp1[221], pp0[221]}),
    .rnd(r[699]), .s(s[699]), .clk(clk), .out({w_px1[221], w_px0[221]}));
MSKand_opini2_d2_pini u_sc_222 (
    .ina({c_d1[222], c_d0[222]}), .inb({S1[222], S0[222]}),
    .rnd(r[700]), .s(s[700]), .clk(clk), .out({w_sc1[222], w_sc0[222]}));
MSKand_opini2_d2_pini u_px_222 (
    .ina({x_d1[222], x_d0[222]}), .inb({pp1[222], pp0[222]}),
    .rnd(r[701]), .s(s[701]), .clk(clk), .out({w_px1[222], w_px0[222]}));
MSKand_opini2_d2_pini u_sc_223 (
    .ina({c_d1[223], c_d0[223]}), .inb({S1[223], S0[223]}),
    .rnd(r[702]), .s(s[702]), .clk(clk), .out({w_sc1[223], w_sc0[223]}));
MSKand_opini2_d2_pini u_px_223 (
    .ina({x_d1[223], x_d0[223]}), .inb({pp1[223], pp0[223]}),
    .rnd(r[703]), .s(s[703]), .clk(clk), .out({w_px1[223], w_px0[223]}));
MSKand_opini2_d2_pini u_sc_224 (
    .ina({c_d1[224], c_d0[224]}), .inb({S1[224], S0[224]}),
    .rnd(r[704]), .s(s[704]), .clk(clk), .out({w_sc1[224], w_sc0[224]}));
MSKand_opini2_d2_pini u_px_224 (
    .ina({x_d1[224], x_d0[224]}), .inb({pp1[224], pp0[224]}),
    .rnd(r[705]), .s(s[705]), .clk(clk), .out({w_px1[224], w_px0[224]}));
MSKand_opini2_d2_pini u_sc_225 (
    .ina({c_d1[225], c_d0[225]}), .inb({S1[225], S0[225]}),
    .rnd(r[706]), .s(s[706]), .clk(clk), .out({w_sc1[225], w_sc0[225]}));
MSKand_opini2_d2_pini u_px_225 (
    .ina({x_d1[225], x_d0[225]}), .inb({pp1[225], pp0[225]}),
    .rnd(r[707]), .s(s[707]), .clk(clk), .out({w_px1[225], w_px0[225]}));
MSKand_opini2_d2_pini u_sc_226 (
    .ina({c_d1[226], c_d0[226]}), .inb({S1[226], S0[226]}),
    .rnd(r[708]), .s(s[708]), .clk(clk), .out({w_sc1[226], w_sc0[226]}));
MSKand_opini2_d2_pini u_px_226 (
    .ina({x_d1[226], x_d0[226]}), .inb({pp1[226], pp0[226]}),
    .rnd(r[709]), .s(s[709]), .clk(clk), .out({w_px1[226], w_px0[226]}));
MSKand_opini2_d2_pini u_sc_227 (
    .ina({c_d1[227], c_d0[227]}), .inb({S1[227], S0[227]}),
    .rnd(r[710]), .s(s[710]), .clk(clk), .out({w_sc1[227], w_sc0[227]}));
MSKand_opini2_d2_pini u_px_227 (
    .ina({x_d1[227], x_d0[227]}), .inb({pp1[227], pp0[227]}),
    .rnd(r[711]), .s(s[711]), .clk(clk), .out({w_px1[227], w_px0[227]}));
MSKand_opini2_d2_pini u_sc_228 (
    .ina({c_d1[228], c_d0[228]}), .inb({S1[228], S0[228]}),
    .rnd(r[712]), .s(s[712]), .clk(clk), .out({w_sc1[228], w_sc0[228]}));
MSKand_opini2_d2_pini u_px_228 (
    .ina({x_d1[228], x_d0[228]}), .inb({pp1[228], pp0[228]}),
    .rnd(r[713]), .s(s[713]), .clk(clk), .out({w_px1[228], w_px0[228]}));
MSKand_opini2_d2_pini u_sc_229 (
    .ina({c_d1[229], c_d0[229]}), .inb({S1[229], S0[229]}),
    .rnd(r[714]), .s(s[714]), .clk(clk), .out({w_sc1[229], w_sc0[229]}));
MSKand_opini2_d2_pini u_px_229 (
    .ina({x_d1[229], x_d0[229]}), .inb({pp1[229], pp0[229]}),
    .rnd(r[715]), .s(s[715]), .clk(clk), .out({w_px1[229], w_px0[229]}));
MSKand_opini2_d2_pini u_sc_230 (
    .ina({c_d1[230], c_d0[230]}), .inb({S1[230], S0[230]}),
    .rnd(r[716]), .s(s[716]), .clk(clk), .out({w_sc1[230], w_sc0[230]}));
MSKand_opini2_d2_pini u_px_230 (
    .ina({x_d1[230], x_d0[230]}), .inb({pp1[230], pp0[230]}),
    .rnd(r[717]), .s(s[717]), .clk(clk), .out({w_px1[230], w_px0[230]}));
MSKand_opini2_d2_pini u_sc_231 (
    .ina({c_d1[231], c_d0[231]}), .inb({S1[231], S0[231]}),
    .rnd(r[718]), .s(s[718]), .clk(clk), .out({w_sc1[231], w_sc0[231]}));
MSKand_opini2_d2_pini u_px_231 (
    .ina({x_d1[231], x_d0[231]}), .inb({pp1[231], pp0[231]}),
    .rnd(r[719]), .s(s[719]), .clk(clk), .out({w_px1[231], w_px0[231]}));
MSKand_opini2_d2_pini u_sc_232 (
    .ina({c_d1[232], c_d0[232]}), .inb({S1[232], S0[232]}),
    .rnd(r[720]), .s(s[720]), .clk(clk), .out({w_sc1[232], w_sc0[232]}));
MSKand_opini2_d2_pini u_px_232 (
    .ina({x_d1[232], x_d0[232]}), .inb({pp1[232], pp0[232]}),
    .rnd(r[721]), .s(s[721]), .clk(clk), .out({w_px1[232], w_px0[232]}));
MSKand_opini2_d2_pini u_sc_233 (
    .ina({c_d1[233], c_d0[233]}), .inb({S1[233], S0[233]}),
    .rnd(r[722]), .s(s[722]), .clk(clk), .out({w_sc1[233], w_sc0[233]}));
MSKand_opini2_d2_pini u_px_233 (
    .ina({x_d1[233], x_d0[233]}), .inb({pp1[233], pp0[233]}),
    .rnd(r[723]), .s(s[723]), .clk(clk), .out({w_px1[233], w_px0[233]}));
MSKand_opini2_d2_pini u_sc_234 (
    .ina({c_d1[234], c_d0[234]}), .inb({S1[234], S0[234]}),
    .rnd(r[724]), .s(s[724]), .clk(clk), .out({w_sc1[234], w_sc0[234]}));
MSKand_opini2_d2_pini u_px_234 (
    .ina({x_d1[234], x_d0[234]}), .inb({pp1[234], pp0[234]}),
    .rnd(r[725]), .s(s[725]), .clk(clk), .out({w_px1[234], w_px0[234]}));
MSKand_opini2_d2_pini u_sc_235 (
    .ina({c_d1[235], c_d0[235]}), .inb({S1[235], S0[235]}),
    .rnd(r[726]), .s(s[726]), .clk(clk), .out({w_sc1[235], w_sc0[235]}));
MSKand_opini2_d2_pini u_px_235 (
    .ina({x_d1[235], x_d0[235]}), .inb({pp1[235], pp0[235]}),
    .rnd(r[727]), .s(s[727]), .clk(clk), .out({w_px1[235], w_px0[235]}));
MSKand_opini2_d2_pini u_sc_236 (
    .ina({c_d1[236], c_d0[236]}), .inb({S1[236], S0[236]}),
    .rnd(r[728]), .s(s[728]), .clk(clk), .out({w_sc1[236], w_sc0[236]}));
MSKand_opini2_d2_pini u_px_236 (
    .ina({x_d1[236], x_d0[236]}), .inb({pp1[236], pp0[236]}),
    .rnd(r[729]), .s(s[729]), .clk(clk), .out({w_px1[236], w_px0[236]}));
MSKand_opini2_d2_pini u_sc_237 (
    .ina({c_d1[237], c_d0[237]}), .inb({S1[237], S0[237]}),
    .rnd(r[730]), .s(s[730]), .clk(clk), .out({w_sc1[237], w_sc0[237]}));
MSKand_opini2_d2_pini u_px_237 (
    .ina({x_d1[237], x_d0[237]}), .inb({pp1[237], pp0[237]}),
    .rnd(r[731]), .s(s[731]), .clk(clk), .out({w_px1[237], w_px0[237]}));
MSKand_opini2_d2_pini u_sc_238 (
    .ina({c_d1[238], c_d0[238]}), .inb({S1[238], S0[238]}),
    .rnd(r[732]), .s(s[732]), .clk(clk), .out({w_sc1[238], w_sc0[238]}));
MSKand_opini2_d2_pini u_px_238 (
    .ina({x_d1[238], x_d0[238]}), .inb({pp1[238], pp0[238]}),
    .rnd(r[733]), .s(s[733]), .clk(clk), .out({w_px1[238], w_px0[238]}));
MSKand_opini2_d2_pini u_sc_239 (
    .ina({c_d1[239], c_d0[239]}), .inb({S1[239], S0[239]}),
    .rnd(r[734]), .s(s[734]), .clk(clk), .out({w_sc1[239], w_sc0[239]}));
MSKand_opini2_d2_pini u_px_239 (
    .ina({x_d1[239], x_d0[239]}), .inb({pp1[239], pp0[239]}),
    .rnd(r[735]), .s(s[735]), .clk(clk), .out({w_px1[239], w_px0[239]}));
MSKand_opini2_d2_pini u_sc_240 (
    .ina({c_d1[240], c_d0[240]}), .inb({S1[240], S0[240]}),
    .rnd(r[736]), .s(s[736]), .clk(clk), .out({w_sc1[240], w_sc0[240]}));
MSKand_opini2_d2_pini u_px_240 (
    .ina({x_d1[240], x_d0[240]}), .inb({pp1[240], pp0[240]}),
    .rnd(r[737]), .s(s[737]), .clk(clk), .out({w_px1[240], w_px0[240]}));
MSKand_opini2_d2_pini u_sc_241 (
    .ina({c_d1[241], c_d0[241]}), .inb({S1[241], S0[241]}),
    .rnd(r[738]), .s(s[738]), .clk(clk), .out({w_sc1[241], w_sc0[241]}));
MSKand_opini2_d2_pini u_px_241 (
    .ina({x_d1[241], x_d0[241]}), .inb({pp1[241], pp0[241]}),
    .rnd(r[739]), .s(s[739]), .clk(clk), .out({w_px1[241], w_px0[241]}));
MSKand_opini2_d2_pini u_sc_242 (
    .ina({c_d1[242], c_d0[242]}), .inb({S1[242], S0[242]}),
    .rnd(r[740]), .s(s[740]), .clk(clk), .out({w_sc1[242], w_sc0[242]}));
MSKand_opini2_d2_pini u_px_242 (
    .ina({x_d1[242], x_d0[242]}), .inb({pp1[242], pp0[242]}),
    .rnd(r[741]), .s(s[741]), .clk(clk), .out({w_px1[242], w_px0[242]}));
MSKand_opini2_d2_pini u_sc_243 (
    .ina({c_d1[243], c_d0[243]}), .inb({S1[243], S0[243]}),
    .rnd(r[742]), .s(s[742]), .clk(clk), .out({w_sc1[243], w_sc0[243]}));
MSKand_opini2_d2_pini u_px_243 (
    .ina({x_d1[243], x_d0[243]}), .inb({pp1[243], pp0[243]}),
    .rnd(r[743]), .s(s[743]), .clk(clk), .out({w_px1[243], w_px0[243]}));
MSKand_opini2_d2_pini u_sc_244 (
    .ina({c_d1[244], c_d0[244]}), .inb({S1[244], S0[244]}),
    .rnd(r[744]), .s(s[744]), .clk(clk), .out({w_sc1[244], w_sc0[244]}));
MSKand_opini2_d2_pini u_px_244 (
    .ina({x_d1[244], x_d0[244]}), .inb({pp1[244], pp0[244]}),
    .rnd(r[745]), .s(s[745]), .clk(clk), .out({w_px1[244], w_px0[244]}));
MSKand_opini2_d2_pini u_sc_245 (
    .ina({c_d1[245], c_d0[245]}), .inb({S1[245], S0[245]}),
    .rnd(r[746]), .s(s[746]), .clk(clk), .out({w_sc1[245], w_sc0[245]}));
MSKand_opini2_d2_pini u_px_245 (
    .ina({x_d1[245], x_d0[245]}), .inb({pp1[245], pp0[245]}),
    .rnd(r[747]), .s(s[747]), .clk(clk), .out({w_px1[245], w_px0[245]}));
MSKand_opini2_d2_pini u_sc_246 (
    .ina({c_d1[246], c_d0[246]}), .inb({S1[246], S0[246]}),
    .rnd(r[748]), .s(s[748]), .clk(clk), .out({w_sc1[246], w_sc0[246]}));
MSKand_opini2_d2_pini u_px_246 (
    .ina({x_d1[246], x_d0[246]}), .inb({pp1[246], pp0[246]}),
    .rnd(r[749]), .s(s[749]), .clk(clk), .out({w_px1[246], w_px0[246]}));
MSKand_opini2_d2_pini u_sc_247 (
    .ina({c_d1[247], c_d0[247]}), .inb({S1[247], S0[247]}),
    .rnd(r[750]), .s(s[750]), .clk(clk), .out({w_sc1[247], w_sc0[247]}));
MSKand_opini2_d2_pini u_px_247 (
    .ina({x_d1[247], x_d0[247]}), .inb({pp1[247], pp0[247]}),
    .rnd(r[751]), .s(s[751]), .clk(clk), .out({w_px1[247], w_px0[247]}));
MSKand_opini2_d2_pini u_sc_248 (
    .ina({c_d1[248], c_d0[248]}), .inb({S1[248], S0[248]}),
    .rnd(r[752]), .s(s[752]), .clk(clk), .out({w_sc1[248], w_sc0[248]}));
MSKand_opini2_d2_pini u_px_248 (
    .ina({x_d1[248], x_d0[248]}), .inb({pp1[248], pp0[248]}),
    .rnd(r[753]), .s(s[753]), .clk(clk), .out({w_px1[248], w_px0[248]}));
MSKand_opini2_d2_pini u_sc_249 (
    .ina({c_d1[249], c_d0[249]}), .inb({S1[249], S0[249]}),
    .rnd(r[754]), .s(s[754]), .clk(clk), .out({w_sc1[249], w_sc0[249]}));
MSKand_opini2_d2_pini u_px_249 (
    .ina({x_d1[249], x_d0[249]}), .inb({pp1[249], pp0[249]}),
    .rnd(r[755]), .s(s[755]), .clk(clk), .out({w_px1[249], w_px0[249]}));
MSKand_opini2_d2_pini u_sc_250 (
    .ina({c_d1[250], c_d0[250]}), .inb({S1[250], S0[250]}),
    .rnd(r[756]), .s(s[756]), .clk(clk), .out({w_sc1[250], w_sc0[250]}));
MSKand_opini2_d2_pini u_px_250 (
    .ina({x_d1[250], x_d0[250]}), .inb({pp1[250], pp0[250]}),
    .rnd(r[757]), .s(s[757]), .clk(clk), .out({w_px1[250], w_px0[250]}));
MSKand_opini2_d2_pini u_sc_251 (
    .ina({c_d1[251], c_d0[251]}), .inb({S1[251], S0[251]}),
    .rnd(r[758]), .s(s[758]), .clk(clk), .out({w_sc1[251], w_sc0[251]}));
MSKand_opini2_d2_pini u_px_251 (
    .ina({x_d1[251], x_d0[251]}), .inb({pp1[251], pp0[251]}),
    .rnd(r[759]), .s(s[759]), .clk(clk), .out({w_px1[251], w_px0[251]}));
MSKand_opini2_d2_pini u_sc_252 (
    .ina({c_d1[252], c_d0[252]}), .inb({S1[252], S0[252]}),
    .rnd(r[760]), .s(s[760]), .clk(clk), .out({w_sc1[252], w_sc0[252]}));
MSKand_opini2_d2_pini u_px_252 (
    .ina({x_d1[252], x_d0[252]}), .inb({pp1[252], pp0[252]}),
    .rnd(r[761]), .s(s[761]), .clk(clk), .out({w_px1[252], w_px0[252]}));
MSKand_opini2_d2_pini u_sc_253 (
    .ina({c_d1[253], c_d0[253]}), .inb({S1[253], S0[253]}),
    .rnd(r[762]), .s(s[762]), .clk(clk), .out({w_sc1[253], w_sc0[253]}));
MSKand_opini2_d2_pini u_px_253 (
    .ina({x_d1[253], x_d0[253]}), .inb({pp1[253], pp0[253]}),
    .rnd(r[763]), .s(s[763]), .clk(clk), .out({w_px1[253], w_px0[253]}));
MSKand_opini2_d2_pini u_sc_254 (
    .ina({c_d1[254], c_d0[254]}), .inb({S1[254], S0[254]}),
    .rnd(r[764]), .s(s[764]), .clk(clk), .out({w_sc1[254], w_sc0[254]}));
MSKand_opini2_d2_pini u_px_254 (
    .ina({x_d1[254], x_d0[254]}), .inb({pp1[254], pp0[254]}),
    .rnd(r[765]), .s(s[765]), .clk(clk), .out({w_px1[254], w_px0[254]}));

// ===== final ripple add: prod = S + C mod 2^256 (verified-adder dataflow, sub=0) =====
// (bit 255 needs no g/t gadgets: its carry-out is dropped by mod 2^256.
//  fc[1..254] feed gadget ports so they survive synthesis; the carry INTO the
//  top bit is kept as standalone scalars fct0/fct1 — abc may absorb them into
//  the prod XOR without leaving a driverless vector bit behind.)
wire [254:0] fc0, fc1;
assign fc0[0] = 1'b0;
assign fc1[0] = 1'b0;
wire p0_0 = S_d0[0] ^ C0[0];
wire p1_0 = S_d1[0] ^ C1[0];
wire g0_0, g1_0, t0_0, t1_0;
MSKand_opini2_d2_pini u_g_0 (
    .ina({S_d1[0], S_d0[0]}), .inb({C1[0], C0[0]}),
    .rnd(r[766]), .s(s[766]), .clk(clk), .out({g1_0, g0_0}));
MSKand_opini2_d2_pini u_t_0 (
    .ina({fc1[0], fc0[0]}), .inb({p1_0, p0_0}),
    .rnd(r[767]), .s(s[767]), .clk(clk), .out({t1_0, t0_0}));
assign fc0[1] = g0_0 ^ t0_0;
assign fc1[1] = g1_0 ^ t1_0;
assign prod[0]   = p0_0 ^ fc0[0];
assign prod[1] = p1_0 ^ fc1[0];
wire p0_1 = S_d0[1] ^ C0[1];
wire p1_1 = S_d1[1] ^ C1[1];
wire g0_1, g1_1, t0_1, t1_1;
MSKand_opini2_d2_pini u_g_1 (
    .ina({S_d1[1], S_d0[1]}), .inb({C1[1], C0[1]}),
    .rnd(r[768]), .s(s[768]), .clk(clk), .out({g1_1, g0_1}));
MSKand_opini2_d2_pini u_t_1 (
    .ina({fc1[1], fc0[1]}), .inb({p1_1, p0_1}),
    .rnd(r[769]), .s(s[769]), .clk(clk), .out({t1_1, t0_1}));
assign fc0[2] = g0_1 ^ t0_1;
assign fc1[2] = g1_1 ^ t1_1;
assign prod[2]   = p0_1 ^ fc0[1];
assign prod[3] = p1_1 ^ fc1[1];
wire p0_2 = S_d0[2] ^ C0[2];
wire p1_2 = S_d1[2] ^ C1[2];
wire g0_2, g1_2, t0_2, t1_2;
MSKand_opini2_d2_pini u_g_2 (
    .ina({S_d1[2], S_d0[2]}), .inb({C1[2], C0[2]}),
    .rnd(r[770]), .s(s[770]), .clk(clk), .out({g1_2, g0_2}));
MSKand_opini2_d2_pini u_t_2 (
    .ina({fc1[2], fc0[2]}), .inb({p1_2, p0_2}),
    .rnd(r[771]), .s(s[771]), .clk(clk), .out({t1_2, t0_2}));
assign fc0[3] = g0_2 ^ t0_2;
assign fc1[3] = g1_2 ^ t1_2;
assign prod[4]   = p0_2 ^ fc0[2];
assign prod[5] = p1_2 ^ fc1[2];
wire p0_3 = S_d0[3] ^ C0[3];
wire p1_3 = S_d1[3] ^ C1[3];
wire g0_3, g1_3, t0_3, t1_3;
MSKand_opini2_d2_pini u_g_3 (
    .ina({S_d1[3], S_d0[3]}), .inb({C1[3], C0[3]}),
    .rnd(r[772]), .s(s[772]), .clk(clk), .out({g1_3, g0_3}));
MSKand_opini2_d2_pini u_t_3 (
    .ina({fc1[3], fc0[3]}), .inb({p1_3, p0_3}),
    .rnd(r[773]), .s(s[773]), .clk(clk), .out({t1_3, t0_3}));
assign fc0[4] = g0_3 ^ t0_3;
assign fc1[4] = g1_3 ^ t1_3;
assign prod[6]   = p0_3 ^ fc0[3];
assign prod[7] = p1_3 ^ fc1[3];
wire p0_4 = S_d0[4] ^ C0[4];
wire p1_4 = S_d1[4] ^ C1[4];
wire g0_4, g1_4, t0_4, t1_4;
MSKand_opini2_d2_pini u_g_4 (
    .ina({S_d1[4], S_d0[4]}), .inb({C1[4], C0[4]}),
    .rnd(r[774]), .s(s[774]), .clk(clk), .out({g1_4, g0_4}));
MSKand_opini2_d2_pini u_t_4 (
    .ina({fc1[4], fc0[4]}), .inb({p1_4, p0_4}),
    .rnd(r[775]), .s(s[775]), .clk(clk), .out({t1_4, t0_4}));
assign fc0[5] = g0_4 ^ t0_4;
assign fc1[5] = g1_4 ^ t1_4;
assign prod[8]   = p0_4 ^ fc0[4];
assign prod[9] = p1_4 ^ fc1[4];
wire p0_5 = S_d0[5] ^ C0[5];
wire p1_5 = S_d1[5] ^ C1[5];
wire g0_5, g1_5, t0_5, t1_5;
MSKand_opini2_d2_pini u_g_5 (
    .ina({S_d1[5], S_d0[5]}), .inb({C1[5], C0[5]}),
    .rnd(r[776]), .s(s[776]), .clk(clk), .out({g1_5, g0_5}));
MSKand_opini2_d2_pini u_t_5 (
    .ina({fc1[5], fc0[5]}), .inb({p1_5, p0_5}),
    .rnd(r[777]), .s(s[777]), .clk(clk), .out({t1_5, t0_5}));
assign fc0[6] = g0_5 ^ t0_5;
assign fc1[6] = g1_5 ^ t1_5;
assign prod[10]   = p0_5 ^ fc0[5];
assign prod[11] = p1_5 ^ fc1[5];
wire p0_6 = S_d0[6] ^ C0[6];
wire p1_6 = S_d1[6] ^ C1[6];
wire g0_6, g1_6, t0_6, t1_6;
MSKand_opini2_d2_pini u_g_6 (
    .ina({S_d1[6], S_d0[6]}), .inb({C1[6], C0[6]}),
    .rnd(r[778]), .s(s[778]), .clk(clk), .out({g1_6, g0_6}));
MSKand_opini2_d2_pini u_t_6 (
    .ina({fc1[6], fc0[6]}), .inb({p1_6, p0_6}),
    .rnd(r[779]), .s(s[779]), .clk(clk), .out({t1_6, t0_6}));
assign fc0[7] = g0_6 ^ t0_6;
assign fc1[7] = g1_6 ^ t1_6;
assign prod[12]   = p0_6 ^ fc0[6];
assign prod[13] = p1_6 ^ fc1[6];
wire p0_7 = S_d0[7] ^ C0[7];
wire p1_7 = S_d1[7] ^ C1[7];
wire g0_7, g1_7, t0_7, t1_7;
MSKand_opini2_d2_pini u_g_7 (
    .ina({S_d1[7], S_d0[7]}), .inb({C1[7], C0[7]}),
    .rnd(r[780]), .s(s[780]), .clk(clk), .out({g1_7, g0_7}));
MSKand_opini2_d2_pini u_t_7 (
    .ina({fc1[7], fc0[7]}), .inb({p1_7, p0_7}),
    .rnd(r[781]), .s(s[781]), .clk(clk), .out({t1_7, t0_7}));
assign fc0[8] = g0_7 ^ t0_7;
assign fc1[8] = g1_7 ^ t1_7;
assign prod[14]   = p0_7 ^ fc0[7];
assign prod[15] = p1_7 ^ fc1[7];
wire p0_8 = S_d0[8] ^ C0[8];
wire p1_8 = S_d1[8] ^ C1[8];
wire g0_8, g1_8, t0_8, t1_8;
MSKand_opini2_d2_pini u_g_8 (
    .ina({S_d1[8], S_d0[8]}), .inb({C1[8], C0[8]}),
    .rnd(r[782]), .s(s[782]), .clk(clk), .out({g1_8, g0_8}));
MSKand_opini2_d2_pini u_t_8 (
    .ina({fc1[8], fc0[8]}), .inb({p1_8, p0_8}),
    .rnd(r[783]), .s(s[783]), .clk(clk), .out({t1_8, t0_8}));
assign fc0[9] = g0_8 ^ t0_8;
assign fc1[9] = g1_8 ^ t1_8;
assign prod[16]   = p0_8 ^ fc0[8];
assign prod[17] = p1_8 ^ fc1[8];
wire p0_9 = S_d0[9] ^ C0[9];
wire p1_9 = S_d1[9] ^ C1[9];
wire g0_9, g1_9, t0_9, t1_9;
MSKand_opini2_d2_pini u_g_9 (
    .ina({S_d1[9], S_d0[9]}), .inb({C1[9], C0[9]}),
    .rnd(r[784]), .s(s[784]), .clk(clk), .out({g1_9, g0_9}));
MSKand_opini2_d2_pini u_t_9 (
    .ina({fc1[9], fc0[9]}), .inb({p1_9, p0_9}),
    .rnd(r[785]), .s(s[785]), .clk(clk), .out({t1_9, t0_9}));
assign fc0[10] = g0_9 ^ t0_9;
assign fc1[10] = g1_9 ^ t1_9;
assign prod[18]   = p0_9 ^ fc0[9];
assign prod[19] = p1_9 ^ fc1[9];
wire p0_10 = S_d0[10] ^ C0[10];
wire p1_10 = S_d1[10] ^ C1[10];
wire g0_10, g1_10, t0_10, t1_10;
MSKand_opini2_d2_pini u_g_10 (
    .ina({S_d1[10], S_d0[10]}), .inb({C1[10], C0[10]}),
    .rnd(r[786]), .s(s[786]), .clk(clk), .out({g1_10, g0_10}));
MSKand_opini2_d2_pini u_t_10 (
    .ina({fc1[10], fc0[10]}), .inb({p1_10, p0_10}),
    .rnd(r[787]), .s(s[787]), .clk(clk), .out({t1_10, t0_10}));
assign fc0[11] = g0_10 ^ t0_10;
assign fc1[11] = g1_10 ^ t1_10;
assign prod[20]   = p0_10 ^ fc0[10];
assign prod[21] = p1_10 ^ fc1[10];
wire p0_11 = S_d0[11] ^ C0[11];
wire p1_11 = S_d1[11] ^ C1[11];
wire g0_11, g1_11, t0_11, t1_11;
MSKand_opini2_d2_pini u_g_11 (
    .ina({S_d1[11], S_d0[11]}), .inb({C1[11], C0[11]}),
    .rnd(r[788]), .s(s[788]), .clk(clk), .out({g1_11, g0_11}));
MSKand_opini2_d2_pini u_t_11 (
    .ina({fc1[11], fc0[11]}), .inb({p1_11, p0_11}),
    .rnd(r[789]), .s(s[789]), .clk(clk), .out({t1_11, t0_11}));
assign fc0[12] = g0_11 ^ t0_11;
assign fc1[12] = g1_11 ^ t1_11;
assign prod[22]   = p0_11 ^ fc0[11];
assign prod[23] = p1_11 ^ fc1[11];
wire p0_12 = S_d0[12] ^ C0[12];
wire p1_12 = S_d1[12] ^ C1[12];
wire g0_12, g1_12, t0_12, t1_12;
MSKand_opini2_d2_pini u_g_12 (
    .ina({S_d1[12], S_d0[12]}), .inb({C1[12], C0[12]}),
    .rnd(r[790]), .s(s[790]), .clk(clk), .out({g1_12, g0_12}));
MSKand_opini2_d2_pini u_t_12 (
    .ina({fc1[12], fc0[12]}), .inb({p1_12, p0_12}),
    .rnd(r[791]), .s(s[791]), .clk(clk), .out({t1_12, t0_12}));
assign fc0[13] = g0_12 ^ t0_12;
assign fc1[13] = g1_12 ^ t1_12;
assign prod[24]   = p0_12 ^ fc0[12];
assign prod[25] = p1_12 ^ fc1[12];
wire p0_13 = S_d0[13] ^ C0[13];
wire p1_13 = S_d1[13] ^ C1[13];
wire g0_13, g1_13, t0_13, t1_13;
MSKand_opini2_d2_pini u_g_13 (
    .ina({S_d1[13], S_d0[13]}), .inb({C1[13], C0[13]}),
    .rnd(r[792]), .s(s[792]), .clk(clk), .out({g1_13, g0_13}));
MSKand_opini2_d2_pini u_t_13 (
    .ina({fc1[13], fc0[13]}), .inb({p1_13, p0_13}),
    .rnd(r[793]), .s(s[793]), .clk(clk), .out({t1_13, t0_13}));
assign fc0[14] = g0_13 ^ t0_13;
assign fc1[14] = g1_13 ^ t1_13;
assign prod[26]   = p0_13 ^ fc0[13];
assign prod[27] = p1_13 ^ fc1[13];
wire p0_14 = S_d0[14] ^ C0[14];
wire p1_14 = S_d1[14] ^ C1[14];
wire g0_14, g1_14, t0_14, t1_14;
MSKand_opini2_d2_pini u_g_14 (
    .ina({S_d1[14], S_d0[14]}), .inb({C1[14], C0[14]}),
    .rnd(r[794]), .s(s[794]), .clk(clk), .out({g1_14, g0_14}));
MSKand_opini2_d2_pini u_t_14 (
    .ina({fc1[14], fc0[14]}), .inb({p1_14, p0_14}),
    .rnd(r[795]), .s(s[795]), .clk(clk), .out({t1_14, t0_14}));
assign fc0[15] = g0_14 ^ t0_14;
assign fc1[15] = g1_14 ^ t1_14;
assign prod[28]   = p0_14 ^ fc0[14];
assign prod[29] = p1_14 ^ fc1[14];
wire p0_15 = S_d0[15] ^ C0[15];
wire p1_15 = S_d1[15] ^ C1[15];
wire g0_15, g1_15, t0_15, t1_15;
MSKand_opini2_d2_pini u_g_15 (
    .ina({S_d1[15], S_d0[15]}), .inb({C1[15], C0[15]}),
    .rnd(r[796]), .s(s[796]), .clk(clk), .out({g1_15, g0_15}));
MSKand_opini2_d2_pini u_t_15 (
    .ina({fc1[15], fc0[15]}), .inb({p1_15, p0_15}),
    .rnd(r[797]), .s(s[797]), .clk(clk), .out({t1_15, t0_15}));
assign fc0[16] = g0_15 ^ t0_15;
assign fc1[16] = g1_15 ^ t1_15;
assign prod[30]   = p0_15 ^ fc0[15];
assign prod[31] = p1_15 ^ fc1[15];
wire p0_16 = S_d0[16] ^ C0[16];
wire p1_16 = S_d1[16] ^ C1[16];
wire g0_16, g1_16, t0_16, t1_16;
MSKand_opini2_d2_pini u_g_16 (
    .ina({S_d1[16], S_d0[16]}), .inb({C1[16], C0[16]}),
    .rnd(r[798]), .s(s[798]), .clk(clk), .out({g1_16, g0_16}));
MSKand_opini2_d2_pini u_t_16 (
    .ina({fc1[16], fc0[16]}), .inb({p1_16, p0_16}),
    .rnd(r[799]), .s(s[799]), .clk(clk), .out({t1_16, t0_16}));
assign fc0[17] = g0_16 ^ t0_16;
assign fc1[17] = g1_16 ^ t1_16;
assign prod[32]   = p0_16 ^ fc0[16];
assign prod[33] = p1_16 ^ fc1[16];
wire p0_17 = S_d0[17] ^ C0[17];
wire p1_17 = S_d1[17] ^ C1[17];
wire g0_17, g1_17, t0_17, t1_17;
MSKand_opini2_d2_pini u_g_17 (
    .ina({S_d1[17], S_d0[17]}), .inb({C1[17], C0[17]}),
    .rnd(r[800]), .s(s[800]), .clk(clk), .out({g1_17, g0_17}));
MSKand_opini2_d2_pini u_t_17 (
    .ina({fc1[17], fc0[17]}), .inb({p1_17, p0_17}),
    .rnd(r[801]), .s(s[801]), .clk(clk), .out({t1_17, t0_17}));
assign fc0[18] = g0_17 ^ t0_17;
assign fc1[18] = g1_17 ^ t1_17;
assign prod[34]   = p0_17 ^ fc0[17];
assign prod[35] = p1_17 ^ fc1[17];
wire p0_18 = S_d0[18] ^ C0[18];
wire p1_18 = S_d1[18] ^ C1[18];
wire g0_18, g1_18, t0_18, t1_18;
MSKand_opini2_d2_pini u_g_18 (
    .ina({S_d1[18], S_d0[18]}), .inb({C1[18], C0[18]}),
    .rnd(r[802]), .s(s[802]), .clk(clk), .out({g1_18, g0_18}));
MSKand_opini2_d2_pini u_t_18 (
    .ina({fc1[18], fc0[18]}), .inb({p1_18, p0_18}),
    .rnd(r[803]), .s(s[803]), .clk(clk), .out({t1_18, t0_18}));
assign fc0[19] = g0_18 ^ t0_18;
assign fc1[19] = g1_18 ^ t1_18;
assign prod[36]   = p0_18 ^ fc0[18];
assign prod[37] = p1_18 ^ fc1[18];
wire p0_19 = S_d0[19] ^ C0[19];
wire p1_19 = S_d1[19] ^ C1[19];
wire g0_19, g1_19, t0_19, t1_19;
MSKand_opini2_d2_pini u_g_19 (
    .ina({S_d1[19], S_d0[19]}), .inb({C1[19], C0[19]}),
    .rnd(r[804]), .s(s[804]), .clk(clk), .out({g1_19, g0_19}));
MSKand_opini2_d2_pini u_t_19 (
    .ina({fc1[19], fc0[19]}), .inb({p1_19, p0_19}),
    .rnd(r[805]), .s(s[805]), .clk(clk), .out({t1_19, t0_19}));
assign fc0[20] = g0_19 ^ t0_19;
assign fc1[20] = g1_19 ^ t1_19;
assign prod[38]   = p0_19 ^ fc0[19];
assign prod[39] = p1_19 ^ fc1[19];
wire p0_20 = S_d0[20] ^ C0[20];
wire p1_20 = S_d1[20] ^ C1[20];
wire g0_20, g1_20, t0_20, t1_20;
MSKand_opini2_d2_pini u_g_20 (
    .ina({S_d1[20], S_d0[20]}), .inb({C1[20], C0[20]}),
    .rnd(r[806]), .s(s[806]), .clk(clk), .out({g1_20, g0_20}));
MSKand_opini2_d2_pini u_t_20 (
    .ina({fc1[20], fc0[20]}), .inb({p1_20, p0_20}),
    .rnd(r[807]), .s(s[807]), .clk(clk), .out({t1_20, t0_20}));
assign fc0[21] = g0_20 ^ t0_20;
assign fc1[21] = g1_20 ^ t1_20;
assign prod[40]   = p0_20 ^ fc0[20];
assign prod[41] = p1_20 ^ fc1[20];
wire p0_21 = S_d0[21] ^ C0[21];
wire p1_21 = S_d1[21] ^ C1[21];
wire g0_21, g1_21, t0_21, t1_21;
MSKand_opini2_d2_pini u_g_21 (
    .ina({S_d1[21], S_d0[21]}), .inb({C1[21], C0[21]}),
    .rnd(r[808]), .s(s[808]), .clk(clk), .out({g1_21, g0_21}));
MSKand_opini2_d2_pini u_t_21 (
    .ina({fc1[21], fc0[21]}), .inb({p1_21, p0_21}),
    .rnd(r[809]), .s(s[809]), .clk(clk), .out({t1_21, t0_21}));
assign fc0[22] = g0_21 ^ t0_21;
assign fc1[22] = g1_21 ^ t1_21;
assign prod[42]   = p0_21 ^ fc0[21];
assign prod[43] = p1_21 ^ fc1[21];
wire p0_22 = S_d0[22] ^ C0[22];
wire p1_22 = S_d1[22] ^ C1[22];
wire g0_22, g1_22, t0_22, t1_22;
MSKand_opini2_d2_pini u_g_22 (
    .ina({S_d1[22], S_d0[22]}), .inb({C1[22], C0[22]}),
    .rnd(r[810]), .s(s[810]), .clk(clk), .out({g1_22, g0_22}));
MSKand_opini2_d2_pini u_t_22 (
    .ina({fc1[22], fc0[22]}), .inb({p1_22, p0_22}),
    .rnd(r[811]), .s(s[811]), .clk(clk), .out({t1_22, t0_22}));
assign fc0[23] = g0_22 ^ t0_22;
assign fc1[23] = g1_22 ^ t1_22;
assign prod[44]   = p0_22 ^ fc0[22];
assign prod[45] = p1_22 ^ fc1[22];
wire p0_23 = S_d0[23] ^ C0[23];
wire p1_23 = S_d1[23] ^ C1[23];
wire g0_23, g1_23, t0_23, t1_23;
MSKand_opini2_d2_pini u_g_23 (
    .ina({S_d1[23], S_d0[23]}), .inb({C1[23], C0[23]}),
    .rnd(r[812]), .s(s[812]), .clk(clk), .out({g1_23, g0_23}));
MSKand_opini2_d2_pini u_t_23 (
    .ina({fc1[23], fc0[23]}), .inb({p1_23, p0_23}),
    .rnd(r[813]), .s(s[813]), .clk(clk), .out({t1_23, t0_23}));
assign fc0[24] = g0_23 ^ t0_23;
assign fc1[24] = g1_23 ^ t1_23;
assign prod[46]   = p0_23 ^ fc0[23];
assign prod[47] = p1_23 ^ fc1[23];
wire p0_24 = S_d0[24] ^ C0[24];
wire p1_24 = S_d1[24] ^ C1[24];
wire g0_24, g1_24, t0_24, t1_24;
MSKand_opini2_d2_pini u_g_24 (
    .ina({S_d1[24], S_d0[24]}), .inb({C1[24], C0[24]}),
    .rnd(r[814]), .s(s[814]), .clk(clk), .out({g1_24, g0_24}));
MSKand_opini2_d2_pini u_t_24 (
    .ina({fc1[24], fc0[24]}), .inb({p1_24, p0_24}),
    .rnd(r[815]), .s(s[815]), .clk(clk), .out({t1_24, t0_24}));
assign fc0[25] = g0_24 ^ t0_24;
assign fc1[25] = g1_24 ^ t1_24;
assign prod[48]   = p0_24 ^ fc0[24];
assign prod[49] = p1_24 ^ fc1[24];
wire p0_25 = S_d0[25] ^ C0[25];
wire p1_25 = S_d1[25] ^ C1[25];
wire g0_25, g1_25, t0_25, t1_25;
MSKand_opini2_d2_pini u_g_25 (
    .ina({S_d1[25], S_d0[25]}), .inb({C1[25], C0[25]}),
    .rnd(r[816]), .s(s[816]), .clk(clk), .out({g1_25, g0_25}));
MSKand_opini2_d2_pini u_t_25 (
    .ina({fc1[25], fc0[25]}), .inb({p1_25, p0_25}),
    .rnd(r[817]), .s(s[817]), .clk(clk), .out({t1_25, t0_25}));
assign fc0[26] = g0_25 ^ t0_25;
assign fc1[26] = g1_25 ^ t1_25;
assign prod[50]   = p0_25 ^ fc0[25];
assign prod[51] = p1_25 ^ fc1[25];
wire p0_26 = S_d0[26] ^ C0[26];
wire p1_26 = S_d1[26] ^ C1[26];
wire g0_26, g1_26, t0_26, t1_26;
MSKand_opini2_d2_pini u_g_26 (
    .ina({S_d1[26], S_d0[26]}), .inb({C1[26], C0[26]}),
    .rnd(r[818]), .s(s[818]), .clk(clk), .out({g1_26, g0_26}));
MSKand_opini2_d2_pini u_t_26 (
    .ina({fc1[26], fc0[26]}), .inb({p1_26, p0_26}),
    .rnd(r[819]), .s(s[819]), .clk(clk), .out({t1_26, t0_26}));
assign fc0[27] = g0_26 ^ t0_26;
assign fc1[27] = g1_26 ^ t1_26;
assign prod[52]   = p0_26 ^ fc0[26];
assign prod[53] = p1_26 ^ fc1[26];
wire p0_27 = S_d0[27] ^ C0[27];
wire p1_27 = S_d1[27] ^ C1[27];
wire g0_27, g1_27, t0_27, t1_27;
MSKand_opini2_d2_pini u_g_27 (
    .ina({S_d1[27], S_d0[27]}), .inb({C1[27], C0[27]}),
    .rnd(r[820]), .s(s[820]), .clk(clk), .out({g1_27, g0_27}));
MSKand_opini2_d2_pini u_t_27 (
    .ina({fc1[27], fc0[27]}), .inb({p1_27, p0_27}),
    .rnd(r[821]), .s(s[821]), .clk(clk), .out({t1_27, t0_27}));
assign fc0[28] = g0_27 ^ t0_27;
assign fc1[28] = g1_27 ^ t1_27;
assign prod[54]   = p0_27 ^ fc0[27];
assign prod[55] = p1_27 ^ fc1[27];
wire p0_28 = S_d0[28] ^ C0[28];
wire p1_28 = S_d1[28] ^ C1[28];
wire g0_28, g1_28, t0_28, t1_28;
MSKand_opini2_d2_pini u_g_28 (
    .ina({S_d1[28], S_d0[28]}), .inb({C1[28], C0[28]}),
    .rnd(r[822]), .s(s[822]), .clk(clk), .out({g1_28, g0_28}));
MSKand_opini2_d2_pini u_t_28 (
    .ina({fc1[28], fc0[28]}), .inb({p1_28, p0_28}),
    .rnd(r[823]), .s(s[823]), .clk(clk), .out({t1_28, t0_28}));
assign fc0[29] = g0_28 ^ t0_28;
assign fc1[29] = g1_28 ^ t1_28;
assign prod[56]   = p0_28 ^ fc0[28];
assign prod[57] = p1_28 ^ fc1[28];
wire p0_29 = S_d0[29] ^ C0[29];
wire p1_29 = S_d1[29] ^ C1[29];
wire g0_29, g1_29, t0_29, t1_29;
MSKand_opini2_d2_pini u_g_29 (
    .ina({S_d1[29], S_d0[29]}), .inb({C1[29], C0[29]}),
    .rnd(r[824]), .s(s[824]), .clk(clk), .out({g1_29, g0_29}));
MSKand_opini2_d2_pini u_t_29 (
    .ina({fc1[29], fc0[29]}), .inb({p1_29, p0_29}),
    .rnd(r[825]), .s(s[825]), .clk(clk), .out({t1_29, t0_29}));
assign fc0[30] = g0_29 ^ t0_29;
assign fc1[30] = g1_29 ^ t1_29;
assign prod[58]   = p0_29 ^ fc0[29];
assign prod[59] = p1_29 ^ fc1[29];
wire p0_30 = S_d0[30] ^ C0[30];
wire p1_30 = S_d1[30] ^ C1[30];
wire g0_30, g1_30, t0_30, t1_30;
MSKand_opini2_d2_pini u_g_30 (
    .ina({S_d1[30], S_d0[30]}), .inb({C1[30], C0[30]}),
    .rnd(r[826]), .s(s[826]), .clk(clk), .out({g1_30, g0_30}));
MSKand_opini2_d2_pini u_t_30 (
    .ina({fc1[30], fc0[30]}), .inb({p1_30, p0_30}),
    .rnd(r[827]), .s(s[827]), .clk(clk), .out({t1_30, t0_30}));
assign fc0[31] = g0_30 ^ t0_30;
assign fc1[31] = g1_30 ^ t1_30;
assign prod[60]   = p0_30 ^ fc0[30];
assign prod[61] = p1_30 ^ fc1[30];
wire p0_31 = S_d0[31] ^ C0[31];
wire p1_31 = S_d1[31] ^ C1[31];
wire g0_31, g1_31, t0_31, t1_31;
MSKand_opini2_d2_pini u_g_31 (
    .ina({S_d1[31], S_d0[31]}), .inb({C1[31], C0[31]}),
    .rnd(r[828]), .s(s[828]), .clk(clk), .out({g1_31, g0_31}));
MSKand_opini2_d2_pini u_t_31 (
    .ina({fc1[31], fc0[31]}), .inb({p1_31, p0_31}),
    .rnd(r[829]), .s(s[829]), .clk(clk), .out({t1_31, t0_31}));
assign fc0[32] = g0_31 ^ t0_31;
assign fc1[32] = g1_31 ^ t1_31;
assign prod[62]   = p0_31 ^ fc0[31];
assign prod[63] = p1_31 ^ fc1[31];
wire p0_32 = S_d0[32] ^ C0[32];
wire p1_32 = S_d1[32] ^ C1[32];
wire g0_32, g1_32, t0_32, t1_32;
MSKand_opini2_d2_pini u_g_32 (
    .ina({S_d1[32], S_d0[32]}), .inb({C1[32], C0[32]}),
    .rnd(r[830]), .s(s[830]), .clk(clk), .out({g1_32, g0_32}));
MSKand_opini2_d2_pini u_t_32 (
    .ina({fc1[32], fc0[32]}), .inb({p1_32, p0_32}),
    .rnd(r[831]), .s(s[831]), .clk(clk), .out({t1_32, t0_32}));
assign fc0[33] = g0_32 ^ t0_32;
assign fc1[33] = g1_32 ^ t1_32;
assign prod[64]   = p0_32 ^ fc0[32];
assign prod[65] = p1_32 ^ fc1[32];
wire p0_33 = S_d0[33] ^ C0[33];
wire p1_33 = S_d1[33] ^ C1[33];
wire g0_33, g1_33, t0_33, t1_33;
MSKand_opini2_d2_pini u_g_33 (
    .ina({S_d1[33], S_d0[33]}), .inb({C1[33], C0[33]}),
    .rnd(r[832]), .s(s[832]), .clk(clk), .out({g1_33, g0_33}));
MSKand_opini2_d2_pini u_t_33 (
    .ina({fc1[33], fc0[33]}), .inb({p1_33, p0_33}),
    .rnd(r[833]), .s(s[833]), .clk(clk), .out({t1_33, t0_33}));
assign fc0[34] = g0_33 ^ t0_33;
assign fc1[34] = g1_33 ^ t1_33;
assign prod[66]   = p0_33 ^ fc0[33];
assign prod[67] = p1_33 ^ fc1[33];
wire p0_34 = S_d0[34] ^ C0[34];
wire p1_34 = S_d1[34] ^ C1[34];
wire g0_34, g1_34, t0_34, t1_34;
MSKand_opini2_d2_pini u_g_34 (
    .ina({S_d1[34], S_d0[34]}), .inb({C1[34], C0[34]}),
    .rnd(r[834]), .s(s[834]), .clk(clk), .out({g1_34, g0_34}));
MSKand_opini2_d2_pini u_t_34 (
    .ina({fc1[34], fc0[34]}), .inb({p1_34, p0_34}),
    .rnd(r[835]), .s(s[835]), .clk(clk), .out({t1_34, t0_34}));
assign fc0[35] = g0_34 ^ t0_34;
assign fc1[35] = g1_34 ^ t1_34;
assign prod[68]   = p0_34 ^ fc0[34];
assign prod[69] = p1_34 ^ fc1[34];
wire p0_35 = S_d0[35] ^ C0[35];
wire p1_35 = S_d1[35] ^ C1[35];
wire g0_35, g1_35, t0_35, t1_35;
MSKand_opini2_d2_pini u_g_35 (
    .ina({S_d1[35], S_d0[35]}), .inb({C1[35], C0[35]}),
    .rnd(r[836]), .s(s[836]), .clk(clk), .out({g1_35, g0_35}));
MSKand_opini2_d2_pini u_t_35 (
    .ina({fc1[35], fc0[35]}), .inb({p1_35, p0_35}),
    .rnd(r[837]), .s(s[837]), .clk(clk), .out({t1_35, t0_35}));
assign fc0[36] = g0_35 ^ t0_35;
assign fc1[36] = g1_35 ^ t1_35;
assign prod[70]   = p0_35 ^ fc0[35];
assign prod[71] = p1_35 ^ fc1[35];
wire p0_36 = S_d0[36] ^ C0[36];
wire p1_36 = S_d1[36] ^ C1[36];
wire g0_36, g1_36, t0_36, t1_36;
MSKand_opini2_d2_pini u_g_36 (
    .ina({S_d1[36], S_d0[36]}), .inb({C1[36], C0[36]}),
    .rnd(r[838]), .s(s[838]), .clk(clk), .out({g1_36, g0_36}));
MSKand_opini2_d2_pini u_t_36 (
    .ina({fc1[36], fc0[36]}), .inb({p1_36, p0_36}),
    .rnd(r[839]), .s(s[839]), .clk(clk), .out({t1_36, t0_36}));
assign fc0[37] = g0_36 ^ t0_36;
assign fc1[37] = g1_36 ^ t1_36;
assign prod[72]   = p0_36 ^ fc0[36];
assign prod[73] = p1_36 ^ fc1[36];
wire p0_37 = S_d0[37] ^ C0[37];
wire p1_37 = S_d1[37] ^ C1[37];
wire g0_37, g1_37, t0_37, t1_37;
MSKand_opini2_d2_pini u_g_37 (
    .ina({S_d1[37], S_d0[37]}), .inb({C1[37], C0[37]}),
    .rnd(r[840]), .s(s[840]), .clk(clk), .out({g1_37, g0_37}));
MSKand_opini2_d2_pini u_t_37 (
    .ina({fc1[37], fc0[37]}), .inb({p1_37, p0_37}),
    .rnd(r[841]), .s(s[841]), .clk(clk), .out({t1_37, t0_37}));
assign fc0[38] = g0_37 ^ t0_37;
assign fc1[38] = g1_37 ^ t1_37;
assign prod[74]   = p0_37 ^ fc0[37];
assign prod[75] = p1_37 ^ fc1[37];
wire p0_38 = S_d0[38] ^ C0[38];
wire p1_38 = S_d1[38] ^ C1[38];
wire g0_38, g1_38, t0_38, t1_38;
MSKand_opini2_d2_pini u_g_38 (
    .ina({S_d1[38], S_d0[38]}), .inb({C1[38], C0[38]}),
    .rnd(r[842]), .s(s[842]), .clk(clk), .out({g1_38, g0_38}));
MSKand_opini2_d2_pini u_t_38 (
    .ina({fc1[38], fc0[38]}), .inb({p1_38, p0_38}),
    .rnd(r[843]), .s(s[843]), .clk(clk), .out({t1_38, t0_38}));
assign fc0[39] = g0_38 ^ t0_38;
assign fc1[39] = g1_38 ^ t1_38;
assign prod[76]   = p0_38 ^ fc0[38];
assign prod[77] = p1_38 ^ fc1[38];
wire p0_39 = S_d0[39] ^ C0[39];
wire p1_39 = S_d1[39] ^ C1[39];
wire g0_39, g1_39, t0_39, t1_39;
MSKand_opini2_d2_pini u_g_39 (
    .ina({S_d1[39], S_d0[39]}), .inb({C1[39], C0[39]}),
    .rnd(r[844]), .s(s[844]), .clk(clk), .out({g1_39, g0_39}));
MSKand_opini2_d2_pini u_t_39 (
    .ina({fc1[39], fc0[39]}), .inb({p1_39, p0_39}),
    .rnd(r[845]), .s(s[845]), .clk(clk), .out({t1_39, t0_39}));
assign fc0[40] = g0_39 ^ t0_39;
assign fc1[40] = g1_39 ^ t1_39;
assign prod[78]   = p0_39 ^ fc0[39];
assign prod[79] = p1_39 ^ fc1[39];
wire p0_40 = S_d0[40] ^ C0[40];
wire p1_40 = S_d1[40] ^ C1[40];
wire g0_40, g1_40, t0_40, t1_40;
MSKand_opini2_d2_pini u_g_40 (
    .ina({S_d1[40], S_d0[40]}), .inb({C1[40], C0[40]}),
    .rnd(r[846]), .s(s[846]), .clk(clk), .out({g1_40, g0_40}));
MSKand_opini2_d2_pini u_t_40 (
    .ina({fc1[40], fc0[40]}), .inb({p1_40, p0_40}),
    .rnd(r[847]), .s(s[847]), .clk(clk), .out({t1_40, t0_40}));
assign fc0[41] = g0_40 ^ t0_40;
assign fc1[41] = g1_40 ^ t1_40;
assign prod[80]   = p0_40 ^ fc0[40];
assign prod[81] = p1_40 ^ fc1[40];
wire p0_41 = S_d0[41] ^ C0[41];
wire p1_41 = S_d1[41] ^ C1[41];
wire g0_41, g1_41, t0_41, t1_41;
MSKand_opini2_d2_pini u_g_41 (
    .ina({S_d1[41], S_d0[41]}), .inb({C1[41], C0[41]}),
    .rnd(r[848]), .s(s[848]), .clk(clk), .out({g1_41, g0_41}));
MSKand_opini2_d2_pini u_t_41 (
    .ina({fc1[41], fc0[41]}), .inb({p1_41, p0_41}),
    .rnd(r[849]), .s(s[849]), .clk(clk), .out({t1_41, t0_41}));
assign fc0[42] = g0_41 ^ t0_41;
assign fc1[42] = g1_41 ^ t1_41;
assign prod[82]   = p0_41 ^ fc0[41];
assign prod[83] = p1_41 ^ fc1[41];
wire p0_42 = S_d0[42] ^ C0[42];
wire p1_42 = S_d1[42] ^ C1[42];
wire g0_42, g1_42, t0_42, t1_42;
MSKand_opini2_d2_pini u_g_42 (
    .ina({S_d1[42], S_d0[42]}), .inb({C1[42], C0[42]}),
    .rnd(r[850]), .s(s[850]), .clk(clk), .out({g1_42, g0_42}));
MSKand_opini2_d2_pini u_t_42 (
    .ina({fc1[42], fc0[42]}), .inb({p1_42, p0_42}),
    .rnd(r[851]), .s(s[851]), .clk(clk), .out({t1_42, t0_42}));
assign fc0[43] = g0_42 ^ t0_42;
assign fc1[43] = g1_42 ^ t1_42;
assign prod[84]   = p0_42 ^ fc0[42];
assign prod[85] = p1_42 ^ fc1[42];
wire p0_43 = S_d0[43] ^ C0[43];
wire p1_43 = S_d1[43] ^ C1[43];
wire g0_43, g1_43, t0_43, t1_43;
MSKand_opini2_d2_pini u_g_43 (
    .ina({S_d1[43], S_d0[43]}), .inb({C1[43], C0[43]}),
    .rnd(r[852]), .s(s[852]), .clk(clk), .out({g1_43, g0_43}));
MSKand_opini2_d2_pini u_t_43 (
    .ina({fc1[43], fc0[43]}), .inb({p1_43, p0_43}),
    .rnd(r[853]), .s(s[853]), .clk(clk), .out({t1_43, t0_43}));
assign fc0[44] = g0_43 ^ t0_43;
assign fc1[44] = g1_43 ^ t1_43;
assign prod[86]   = p0_43 ^ fc0[43];
assign prod[87] = p1_43 ^ fc1[43];
wire p0_44 = S_d0[44] ^ C0[44];
wire p1_44 = S_d1[44] ^ C1[44];
wire g0_44, g1_44, t0_44, t1_44;
MSKand_opini2_d2_pini u_g_44 (
    .ina({S_d1[44], S_d0[44]}), .inb({C1[44], C0[44]}),
    .rnd(r[854]), .s(s[854]), .clk(clk), .out({g1_44, g0_44}));
MSKand_opini2_d2_pini u_t_44 (
    .ina({fc1[44], fc0[44]}), .inb({p1_44, p0_44}),
    .rnd(r[855]), .s(s[855]), .clk(clk), .out({t1_44, t0_44}));
assign fc0[45] = g0_44 ^ t0_44;
assign fc1[45] = g1_44 ^ t1_44;
assign prod[88]   = p0_44 ^ fc0[44];
assign prod[89] = p1_44 ^ fc1[44];
wire p0_45 = S_d0[45] ^ C0[45];
wire p1_45 = S_d1[45] ^ C1[45];
wire g0_45, g1_45, t0_45, t1_45;
MSKand_opini2_d2_pini u_g_45 (
    .ina({S_d1[45], S_d0[45]}), .inb({C1[45], C0[45]}),
    .rnd(r[856]), .s(s[856]), .clk(clk), .out({g1_45, g0_45}));
MSKand_opini2_d2_pini u_t_45 (
    .ina({fc1[45], fc0[45]}), .inb({p1_45, p0_45}),
    .rnd(r[857]), .s(s[857]), .clk(clk), .out({t1_45, t0_45}));
assign fc0[46] = g0_45 ^ t0_45;
assign fc1[46] = g1_45 ^ t1_45;
assign prod[90]   = p0_45 ^ fc0[45];
assign prod[91] = p1_45 ^ fc1[45];
wire p0_46 = S_d0[46] ^ C0[46];
wire p1_46 = S_d1[46] ^ C1[46];
wire g0_46, g1_46, t0_46, t1_46;
MSKand_opini2_d2_pini u_g_46 (
    .ina({S_d1[46], S_d0[46]}), .inb({C1[46], C0[46]}),
    .rnd(r[858]), .s(s[858]), .clk(clk), .out({g1_46, g0_46}));
MSKand_opini2_d2_pini u_t_46 (
    .ina({fc1[46], fc0[46]}), .inb({p1_46, p0_46}),
    .rnd(r[859]), .s(s[859]), .clk(clk), .out({t1_46, t0_46}));
assign fc0[47] = g0_46 ^ t0_46;
assign fc1[47] = g1_46 ^ t1_46;
assign prod[92]   = p0_46 ^ fc0[46];
assign prod[93] = p1_46 ^ fc1[46];
wire p0_47 = S_d0[47] ^ C0[47];
wire p1_47 = S_d1[47] ^ C1[47];
wire g0_47, g1_47, t0_47, t1_47;
MSKand_opini2_d2_pini u_g_47 (
    .ina({S_d1[47], S_d0[47]}), .inb({C1[47], C0[47]}),
    .rnd(r[860]), .s(s[860]), .clk(clk), .out({g1_47, g0_47}));
MSKand_opini2_d2_pini u_t_47 (
    .ina({fc1[47], fc0[47]}), .inb({p1_47, p0_47}),
    .rnd(r[861]), .s(s[861]), .clk(clk), .out({t1_47, t0_47}));
assign fc0[48] = g0_47 ^ t0_47;
assign fc1[48] = g1_47 ^ t1_47;
assign prod[94]   = p0_47 ^ fc0[47];
assign prod[95] = p1_47 ^ fc1[47];
wire p0_48 = S_d0[48] ^ C0[48];
wire p1_48 = S_d1[48] ^ C1[48];
wire g0_48, g1_48, t0_48, t1_48;
MSKand_opini2_d2_pini u_g_48 (
    .ina({S_d1[48], S_d0[48]}), .inb({C1[48], C0[48]}),
    .rnd(r[862]), .s(s[862]), .clk(clk), .out({g1_48, g0_48}));
MSKand_opini2_d2_pini u_t_48 (
    .ina({fc1[48], fc0[48]}), .inb({p1_48, p0_48}),
    .rnd(r[863]), .s(s[863]), .clk(clk), .out({t1_48, t0_48}));
assign fc0[49] = g0_48 ^ t0_48;
assign fc1[49] = g1_48 ^ t1_48;
assign prod[96]   = p0_48 ^ fc0[48];
assign prod[97] = p1_48 ^ fc1[48];
wire p0_49 = S_d0[49] ^ C0[49];
wire p1_49 = S_d1[49] ^ C1[49];
wire g0_49, g1_49, t0_49, t1_49;
MSKand_opini2_d2_pini u_g_49 (
    .ina({S_d1[49], S_d0[49]}), .inb({C1[49], C0[49]}),
    .rnd(r[864]), .s(s[864]), .clk(clk), .out({g1_49, g0_49}));
MSKand_opini2_d2_pini u_t_49 (
    .ina({fc1[49], fc0[49]}), .inb({p1_49, p0_49}),
    .rnd(r[865]), .s(s[865]), .clk(clk), .out({t1_49, t0_49}));
assign fc0[50] = g0_49 ^ t0_49;
assign fc1[50] = g1_49 ^ t1_49;
assign prod[98]   = p0_49 ^ fc0[49];
assign prod[99] = p1_49 ^ fc1[49];
wire p0_50 = S_d0[50] ^ C0[50];
wire p1_50 = S_d1[50] ^ C1[50];
wire g0_50, g1_50, t0_50, t1_50;
MSKand_opini2_d2_pini u_g_50 (
    .ina({S_d1[50], S_d0[50]}), .inb({C1[50], C0[50]}),
    .rnd(r[866]), .s(s[866]), .clk(clk), .out({g1_50, g0_50}));
MSKand_opini2_d2_pini u_t_50 (
    .ina({fc1[50], fc0[50]}), .inb({p1_50, p0_50}),
    .rnd(r[867]), .s(s[867]), .clk(clk), .out({t1_50, t0_50}));
assign fc0[51] = g0_50 ^ t0_50;
assign fc1[51] = g1_50 ^ t1_50;
assign prod[100]   = p0_50 ^ fc0[50];
assign prod[101] = p1_50 ^ fc1[50];
wire p0_51 = S_d0[51] ^ C0[51];
wire p1_51 = S_d1[51] ^ C1[51];
wire g0_51, g1_51, t0_51, t1_51;
MSKand_opini2_d2_pini u_g_51 (
    .ina({S_d1[51], S_d0[51]}), .inb({C1[51], C0[51]}),
    .rnd(r[868]), .s(s[868]), .clk(clk), .out({g1_51, g0_51}));
MSKand_opini2_d2_pini u_t_51 (
    .ina({fc1[51], fc0[51]}), .inb({p1_51, p0_51}),
    .rnd(r[869]), .s(s[869]), .clk(clk), .out({t1_51, t0_51}));
assign fc0[52] = g0_51 ^ t0_51;
assign fc1[52] = g1_51 ^ t1_51;
assign prod[102]   = p0_51 ^ fc0[51];
assign prod[103] = p1_51 ^ fc1[51];
wire p0_52 = S_d0[52] ^ C0[52];
wire p1_52 = S_d1[52] ^ C1[52];
wire g0_52, g1_52, t0_52, t1_52;
MSKand_opini2_d2_pini u_g_52 (
    .ina({S_d1[52], S_d0[52]}), .inb({C1[52], C0[52]}),
    .rnd(r[870]), .s(s[870]), .clk(clk), .out({g1_52, g0_52}));
MSKand_opini2_d2_pini u_t_52 (
    .ina({fc1[52], fc0[52]}), .inb({p1_52, p0_52}),
    .rnd(r[871]), .s(s[871]), .clk(clk), .out({t1_52, t0_52}));
assign fc0[53] = g0_52 ^ t0_52;
assign fc1[53] = g1_52 ^ t1_52;
assign prod[104]   = p0_52 ^ fc0[52];
assign prod[105] = p1_52 ^ fc1[52];
wire p0_53 = S_d0[53] ^ C0[53];
wire p1_53 = S_d1[53] ^ C1[53];
wire g0_53, g1_53, t0_53, t1_53;
MSKand_opini2_d2_pini u_g_53 (
    .ina({S_d1[53], S_d0[53]}), .inb({C1[53], C0[53]}),
    .rnd(r[872]), .s(s[872]), .clk(clk), .out({g1_53, g0_53}));
MSKand_opini2_d2_pini u_t_53 (
    .ina({fc1[53], fc0[53]}), .inb({p1_53, p0_53}),
    .rnd(r[873]), .s(s[873]), .clk(clk), .out({t1_53, t0_53}));
assign fc0[54] = g0_53 ^ t0_53;
assign fc1[54] = g1_53 ^ t1_53;
assign prod[106]   = p0_53 ^ fc0[53];
assign prod[107] = p1_53 ^ fc1[53];
wire p0_54 = S_d0[54] ^ C0[54];
wire p1_54 = S_d1[54] ^ C1[54];
wire g0_54, g1_54, t0_54, t1_54;
MSKand_opini2_d2_pini u_g_54 (
    .ina({S_d1[54], S_d0[54]}), .inb({C1[54], C0[54]}),
    .rnd(r[874]), .s(s[874]), .clk(clk), .out({g1_54, g0_54}));
MSKand_opini2_d2_pini u_t_54 (
    .ina({fc1[54], fc0[54]}), .inb({p1_54, p0_54}),
    .rnd(r[875]), .s(s[875]), .clk(clk), .out({t1_54, t0_54}));
assign fc0[55] = g0_54 ^ t0_54;
assign fc1[55] = g1_54 ^ t1_54;
assign prod[108]   = p0_54 ^ fc0[54];
assign prod[109] = p1_54 ^ fc1[54];
wire p0_55 = S_d0[55] ^ C0[55];
wire p1_55 = S_d1[55] ^ C1[55];
wire g0_55, g1_55, t0_55, t1_55;
MSKand_opini2_d2_pini u_g_55 (
    .ina({S_d1[55], S_d0[55]}), .inb({C1[55], C0[55]}),
    .rnd(r[876]), .s(s[876]), .clk(clk), .out({g1_55, g0_55}));
MSKand_opini2_d2_pini u_t_55 (
    .ina({fc1[55], fc0[55]}), .inb({p1_55, p0_55}),
    .rnd(r[877]), .s(s[877]), .clk(clk), .out({t1_55, t0_55}));
assign fc0[56] = g0_55 ^ t0_55;
assign fc1[56] = g1_55 ^ t1_55;
assign prod[110]   = p0_55 ^ fc0[55];
assign prod[111] = p1_55 ^ fc1[55];
wire p0_56 = S_d0[56] ^ C0[56];
wire p1_56 = S_d1[56] ^ C1[56];
wire g0_56, g1_56, t0_56, t1_56;
MSKand_opini2_d2_pini u_g_56 (
    .ina({S_d1[56], S_d0[56]}), .inb({C1[56], C0[56]}),
    .rnd(r[878]), .s(s[878]), .clk(clk), .out({g1_56, g0_56}));
MSKand_opini2_d2_pini u_t_56 (
    .ina({fc1[56], fc0[56]}), .inb({p1_56, p0_56}),
    .rnd(r[879]), .s(s[879]), .clk(clk), .out({t1_56, t0_56}));
assign fc0[57] = g0_56 ^ t0_56;
assign fc1[57] = g1_56 ^ t1_56;
assign prod[112]   = p0_56 ^ fc0[56];
assign prod[113] = p1_56 ^ fc1[56];
wire p0_57 = S_d0[57] ^ C0[57];
wire p1_57 = S_d1[57] ^ C1[57];
wire g0_57, g1_57, t0_57, t1_57;
MSKand_opini2_d2_pini u_g_57 (
    .ina({S_d1[57], S_d0[57]}), .inb({C1[57], C0[57]}),
    .rnd(r[880]), .s(s[880]), .clk(clk), .out({g1_57, g0_57}));
MSKand_opini2_d2_pini u_t_57 (
    .ina({fc1[57], fc0[57]}), .inb({p1_57, p0_57}),
    .rnd(r[881]), .s(s[881]), .clk(clk), .out({t1_57, t0_57}));
assign fc0[58] = g0_57 ^ t0_57;
assign fc1[58] = g1_57 ^ t1_57;
assign prod[114]   = p0_57 ^ fc0[57];
assign prod[115] = p1_57 ^ fc1[57];
wire p0_58 = S_d0[58] ^ C0[58];
wire p1_58 = S_d1[58] ^ C1[58];
wire g0_58, g1_58, t0_58, t1_58;
MSKand_opini2_d2_pini u_g_58 (
    .ina({S_d1[58], S_d0[58]}), .inb({C1[58], C0[58]}),
    .rnd(r[882]), .s(s[882]), .clk(clk), .out({g1_58, g0_58}));
MSKand_opini2_d2_pini u_t_58 (
    .ina({fc1[58], fc0[58]}), .inb({p1_58, p0_58}),
    .rnd(r[883]), .s(s[883]), .clk(clk), .out({t1_58, t0_58}));
assign fc0[59] = g0_58 ^ t0_58;
assign fc1[59] = g1_58 ^ t1_58;
assign prod[116]   = p0_58 ^ fc0[58];
assign prod[117] = p1_58 ^ fc1[58];
wire p0_59 = S_d0[59] ^ C0[59];
wire p1_59 = S_d1[59] ^ C1[59];
wire g0_59, g1_59, t0_59, t1_59;
MSKand_opini2_d2_pini u_g_59 (
    .ina({S_d1[59], S_d0[59]}), .inb({C1[59], C0[59]}),
    .rnd(r[884]), .s(s[884]), .clk(clk), .out({g1_59, g0_59}));
MSKand_opini2_d2_pini u_t_59 (
    .ina({fc1[59], fc0[59]}), .inb({p1_59, p0_59}),
    .rnd(r[885]), .s(s[885]), .clk(clk), .out({t1_59, t0_59}));
assign fc0[60] = g0_59 ^ t0_59;
assign fc1[60] = g1_59 ^ t1_59;
assign prod[118]   = p0_59 ^ fc0[59];
assign prod[119] = p1_59 ^ fc1[59];
wire p0_60 = S_d0[60] ^ C0[60];
wire p1_60 = S_d1[60] ^ C1[60];
wire g0_60, g1_60, t0_60, t1_60;
MSKand_opini2_d2_pini u_g_60 (
    .ina({S_d1[60], S_d0[60]}), .inb({C1[60], C0[60]}),
    .rnd(r[886]), .s(s[886]), .clk(clk), .out({g1_60, g0_60}));
MSKand_opini2_d2_pini u_t_60 (
    .ina({fc1[60], fc0[60]}), .inb({p1_60, p0_60}),
    .rnd(r[887]), .s(s[887]), .clk(clk), .out({t1_60, t0_60}));
assign fc0[61] = g0_60 ^ t0_60;
assign fc1[61] = g1_60 ^ t1_60;
assign prod[120]   = p0_60 ^ fc0[60];
assign prod[121] = p1_60 ^ fc1[60];
wire p0_61 = S_d0[61] ^ C0[61];
wire p1_61 = S_d1[61] ^ C1[61];
wire g0_61, g1_61, t0_61, t1_61;
MSKand_opini2_d2_pini u_g_61 (
    .ina({S_d1[61], S_d0[61]}), .inb({C1[61], C0[61]}),
    .rnd(r[888]), .s(s[888]), .clk(clk), .out({g1_61, g0_61}));
MSKand_opini2_d2_pini u_t_61 (
    .ina({fc1[61], fc0[61]}), .inb({p1_61, p0_61}),
    .rnd(r[889]), .s(s[889]), .clk(clk), .out({t1_61, t0_61}));
assign fc0[62] = g0_61 ^ t0_61;
assign fc1[62] = g1_61 ^ t1_61;
assign prod[122]   = p0_61 ^ fc0[61];
assign prod[123] = p1_61 ^ fc1[61];
wire p0_62 = S_d0[62] ^ C0[62];
wire p1_62 = S_d1[62] ^ C1[62];
wire g0_62, g1_62, t0_62, t1_62;
MSKand_opini2_d2_pini u_g_62 (
    .ina({S_d1[62], S_d0[62]}), .inb({C1[62], C0[62]}),
    .rnd(r[890]), .s(s[890]), .clk(clk), .out({g1_62, g0_62}));
MSKand_opini2_d2_pini u_t_62 (
    .ina({fc1[62], fc0[62]}), .inb({p1_62, p0_62}),
    .rnd(r[891]), .s(s[891]), .clk(clk), .out({t1_62, t0_62}));
assign fc0[63] = g0_62 ^ t0_62;
assign fc1[63] = g1_62 ^ t1_62;
assign prod[124]   = p0_62 ^ fc0[62];
assign prod[125] = p1_62 ^ fc1[62];
wire p0_63 = S_d0[63] ^ C0[63];
wire p1_63 = S_d1[63] ^ C1[63];
wire g0_63, g1_63, t0_63, t1_63;
MSKand_opini2_d2_pini u_g_63 (
    .ina({S_d1[63], S_d0[63]}), .inb({C1[63], C0[63]}),
    .rnd(r[892]), .s(s[892]), .clk(clk), .out({g1_63, g0_63}));
MSKand_opini2_d2_pini u_t_63 (
    .ina({fc1[63], fc0[63]}), .inb({p1_63, p0_63}),
    .rnd(r[893]), .s(s[893]), .clk(clk), .out({t1_63, t0_63}));
assign fc0[64] = g0_63 ^ t0_63;
assign fc1[64] = g1_63 ^ t1_63;
assign prod[126]   = p0_63 ^ fc0[63];
assign prod[127] = p1_63 ^ fc1[63];
wire p0_64 = S_d0[64] ^ C0[64];
wire p1_64 = S_d1[64] ^ C1[64];
wire g0_64, g1_64, t0_64, t1_64;
MSKand_opini2_d2_pini u_g_64 (
    .ina({S_d1[64], S_d0[64]}), .inb({C1[64], C0[64]}),
    .rnd(r[894]), .s(s[894]), .clk(clk), .out({g1_64, g0_64}));
MSKand_opini2_d2_pini u_t_64 (
    .ina({fc1[64], fc0[64]}), .inb({p1_64, p0_64}),
    .rnd(r[895]), .s(s[895]), .clk(clk), .out({t1_64, t0_64}));
assign fc0[65] = g0_64 ^ t0_64;
assign fc1[65] = g1_64 ^ t1_64;
assign prod[128]   = p0_64 ^ fc0[64];
assign prod[129] = p1_64 ^ fc1[64];
wire p0_65 = S_d0[65] ^ C0[65];
wire p1_65 = S_d1[65] ^ C1[65];
wire g0_65, g1_65, t0_65, t1_65;
MSKand_opini2_d2_pini u_g_65 (
    .ina({S_d1[65], S_d0[65]}), .inb({C1[65], C0[65]}),
    .rnd(r[896]), .s(s[896]), .clk(clk), .out({g1_65, g0_65}));
MSKand_opini2_d2_pini u_t_65 (
    .ina({fc1[65], fc0[65]}), .inb({p1_65, p0_65}),
    .rnd(r[897]), .s(s[897]), .clk(clk), .out({t1_65, t0_65}));
assign fc0[66] = g0_65 ^ t0_65;
assign fc1[66] = g1_65 ^ t1_65;
assign prod[130]   = p0_65 ^ fc0[65];
assign prod[131] = p1_65 ^ fc1[65];
wire p0_66 = S_d0[66] ^ C0[66];
wire p1_66 = S_d1[66] ^ C1[66];
wire g0_66, g1_66, t0_66, t1_66;
MSKand_opini2_d2_pini u_g_66 (
    .ina({S_d1[66], S_d0[66]}), .inb({C1[66], C0[66]}),
    .rnd(r[898]), .s(s[898]), .clk(clk), .out({g1_66, g0_66}));
MSKand_opini2_d2_pini u_t_66 (
    .ina({fc1[66], fc0[66]}), .inb({p1_66, p0_66}),
    .rnd(r[899]), .s(s[899]), .clk(clk), .out({t1_66, t0_66}));
assign fc0[67] = g0_66 ^ t0_66;
assign fc1[67] = g1_66 ^ t1_66;
assign prod[132]   = p0_66 ^ fc0[66];
assign prod[133] = p1_66 ^ fc1[66];
wire p0_67 = S_d0[67] ^ C0[67];
wire p1_67 = S_d1[67] ^ C1[67];
wire g0_67, g1_67, t0_67, t1_67;
MSKand_opini2_d2_pini u_g_67 (
    .ina({S_d1[67], S_d0[67]}), .inb({C1[67], C0[67]}),
    .rnd(r[900]), .s(s[900]), .clk(clk), .out({g1_67, g0_67}));
MSKand_opini2_d2_pini u_t_67 (
    .ina({fc1[67], fc0[67]}), .inb({p1_67, p0_67}),
    .rnd(r[901]), .s(s[901]), .clk(clk), .out({t1_67, t0_67}));
assign fc0[68] = g0_67 ^ t0_67;
assign fc1[68] = g1_67 ^ t1_67;
assign prod[134]   = p0_67 ^ fc0[67];
assign prod[135] = p1_67 ^ fc1[67];
wire p0_68 = S_d0[68] ^ C0[68];
wire p1_68 = S_d1[68] ^ C1[68];
wire g0_68, g1_68, t0_68, t1_68;
MSKand_opini2_d2_pini u_g_68 (
    .ina({S_d1[68], S_d0[68]}), .inb({C1[68], C0[68]}),
    .rnd(r[902]), .s(s[902]), .clk(clk), .out({g1_68, g0_68}));
MSKand_opini2_d2_pini u_t_68 (
    .ina({fc1[68], fc0[68]}), .inb({p1_68, p0_68}),
    .rnd(r[903]), .s(s[903]), .clk(clk), .out({t1_68, t0_68}));
assign fc0[69] = g0_68 ^ t0_68;
assign fc1[69] = g1_68 ^ t1_68;
assign prod[136]   = p0_68 ^ fc0[68];
assign prod[137] = p1_68 ^ fc1[68];
wire p0_69 = S_d0[69] ^ C0[69];
wire p1_69 = S_d1[69] ^ C1[69];
wire g0_69, g1_69, t0_69, t1_69;
MSKand_opini2_d2_pini u_g_69 (
    .ina({S_d1[69], S_d0[69]}), .inb({C1[69], C0[69]}),
    .rnd(r[904]), .s(s[904]), .clk(clk), .out({g1_69, g0_69}));
MSKand_opini2_d2_pini u_t_69 (
    .ina({fc1[69], fc0[69]}), .inb({p1_69, p0_69}),
    .rnd(r[905]), .s(s[905]), .clk(clk), .out({t1_69, t0_69}));
assign fc0[70] = g0_69 ^ t0_69;
assign fc1[70] = g1_69 ^ t1_69;
assign prod[138]   = p0_69 ^ fc0[69];
assign prod[139] = p1_69 ^ fc1[69];
wire p0_70 = S_d0[70] ^ C0[70];
wire p1_70 = S_d1[70] ^ C1[70];
wire g0_70, g1_70, t0_70, t1_70;
MSKand_opini2_d2_pini u_g_70 (
    .ina({S_d1[70], S_d0[70]}), .inb({C1[70], C0[70]}),
    .rnd(r[906]), .s(s[906]), .clk(clk), .out({g1_70, g0_70}));
MSKand_opini2_d2_pini u_t_70 (
    .ina({fc1[70], fc0[70]}), .inb({p1_70, p0_70}),
    .rnd(r[907]), .s(s[907]), .clk(clk), .out({t1_70, t0_70}));
assign fc0[71] = g0_70 ^ t0_70;
assign fc1[71] = g1_70 ^ t1_70;
assign prod[140]   = p0_70 ^ fc0[70];
assign prod[141] = p1_70 ^ fc1[70];
wire p0_71 = S_d0[71] ^ C0[71];
wire p1_71 = S_d1[71] ^ C1[71];
wire g0_71, g1_71, t0_71, t1_71;
MSKand_opini2_d2_pini u_g_71 (
    .ina({S_d1[71], S_d0[71]}), .inb({C1[71], C0[71]}),
    .rnd(r[908]), .s(s[908]), .clk(clk), .out({g1_71, g0_71}));
MSKand_opini2_d2_pini u_t_71 (
    .ina({fc1[71], fc0[71]}), .inb({p1_71, p0_71}),
    .rnd(r[909]), .s(s[909]), .clk(clk), .out({t1_71, t0_71}));
assign fc0[72] = g0_71 ^ t0_71;
assign fc1[72] = g1_71 ^ t1_71;
assign prod[142]   = p0_71 ^ fc0[71];
assign prod[143] = p1_71 ^ fc1[71];
wire p0_72 = S_d0[72] ^ C0[72];
wire p1_72 = S_d1[72] ^ C1[72];
wire g0_72, g1_72, t0_72, t1_72;
MSKand_opini2_d2_pini u_g_72 (
    .ina({S_d1[72], S_d0[72]}), .inb({C1[72], C0[72]}),
    .rnd(r[910]), .s(s[910]), .clk(clk), .out({g1_72, g0_72}));
MSKand_opini2_d2_pini u_t_72 (
    .ina({fc1[72], fc0[72]}), .inb({p1_72, p0_72}),
    .rnd(r[911]), .s(s[911]), .clk(clk), .out({t1_72, t0_72}));
assign fc0[73] = g0_72 ^ t0_72;
assign fc1[73] = g1_72 ^ t1_72;
assign prod[144]   = p0_72 ^ fc0[72];
assign prod[145] = p1_72 ^ fc1[72];
wire p0_73 = S_d0[73] ^ C0[73];
wire p1_73 = S_d1[73] ^ C1[73];
wire g0_73, g1_73, t0_73, t1_73;
MSKand_opini2_d2_pini u_g_73 (
    .ina({S_d1[73], S_d0[73]}), .inb({C1[73], C0[73]}),
    .rnd(r[912]), .s(s[912]), .clk(clk), .out({g1_73, g0_73}));
MSKand_opini2_d2_pini u_t_73 (
    .ina({fc1[73], fc0[73]}), .inb({p1_73, p0_73}),
    .rnd(r[913]), .s(s[913]), .clk(clk), .out({t1_73, t0_73}));
assign fc0[74] = g0_73 ^ t0_73;
assign fc1[74] = g1_73 ^ t1_73;
assign prod[146]   = p0_73 ^ fc0[73];
assign prod[147] = p1_73 ^ fc1[73];
wire p0_74 = S_d0[74] ^ C0[74];
wire p1_74 = S_d1[74] ^ C1[74];
wire g0_74, g1_74, t0_74, t1_74;
MSKand_opini2_d2_pini u_g_74 (
    .ina({S_d1[74], S_d0[74]}), .inb({C1[74], C0[74]}),
    .rnd(r[914]), .s(s[914]), .clk(clk), .out({g1_74, g0_74}));
MSKand_opini2_d2_pini u_t_74 (
    .ina({fc1[74], fc0[74]}), .inb({p1_74, p0_74}),
    .rnd(r[915]), .s(s[915]), .clk(clk), .out({t1_74, t0_74}));
assign fc0[75] = g0_74 ^ t0_74;
assign fc1[75] = g1_74 ^ t1_74;
assign prod[148]   = p0_74 ^ fc0[74];
assign prod[149] = p1_74 ^ fc1[74];
wire p0_75 = S_d0[75] ^ C0[75];
wire p1_75 = S_d1[75] ^ C1[75];
wire g0_75, g1_75, t0_75, t1_75;
MSKand_opini2_d2_pini u_g_75 (
    .ina({S_d1[75], S_d0[75]}), .inb({C1[75], C0[75]}),
    .rnd(r[916]), .s(s[916]), .clk(clk), .out({g1_75, g0_75}));
MSKand_opini2_d2_pini u_t_75 (
    .ina({fc1[75], fc0[75]}), .inb({p1_75, p0_75}),
    .rnd(r[917]), .s(s[917]), .clk(clk), .out({t1_75, t0_75}));
assign fc0[76] = g0_75 ^ t0_75;
assign fc1[76] = g1_75 ^ t1_75;
assign prod[150]   = p0_75 ^ fc0[75];
assign prod[151] = p1_75 ^ fc1[75];
wire p0_76 = S_d0[76] ^ C0[76];
wire p1_76 = S_d1[76] ^ C1[76];
wire g0_76, g1_76, t0_76, t1_76;
MSKand_opini2_d2_pini u_g_76 (
    .ina({S_d1[76], S_d0[76]}), .inb({C1[76], C0[76]}),
    .rnd(r[918]), .s(s[918]), .clk(clk), .out({g1_76, g0_76}));
MSKand_opini2_d2_pini u_t_76 (
    .ina({fc1[76], fc0[76]}), .inb({p1_76, p0_76}),
    .rnd(r[919]), .s(s[919]), .clk(clk), .out({t1_76, t0_76}));
assign fc0[77] = g0_76 ^ t0_76;
assign fc1[77] = g1_76 ^ t1_76;
assign prod[152]   = p0_76 ^ fc0[76];
assign prod[153] = p1_76 ^ fc1[76];
wire p0_77 = S_d0[77] ^ C0[77];
wire p1_77 = S_d1[77] ^ C1[77];
wire g0_77, g1_77, t0_77, t1_77;
MSKand_opini2_d2_pini u_g_77 (
    .ina({S_d1[77], S_d0[77]}), .inb({C1[77], C0[77]}),
    .rnd(r[920]), .s(s[920]), .clk(clk), .out({g1_77, g0_77}));
MSKand_opini2_d2_pini u_t_77 (
    .ina({fc1[77], fc0[77]}), .inb({p1_77, p0_77}),
    .rnd(r[921]), .s(s[921]), .clk(clk), .out({t1_77, t0_77}));
assign fc0[78] = g0_77 ^ t0_77;
assign fc1[78] = g1_77 ^ t1_77;
assign prod[154]   = p0_77 ^ fc0[77];
assign prod[155] = p1_77 ^ fc1[77];
wire p0_78 = S_d0[78] ^ C0[78];
wire p1_78 = S_d1[78] ^ C1[78];
wire g0_78, g1_78, t0_78, t1_78;
MSKand_opini2_d2_pini u_g_78 (
    .ina({S_d1[78], S_d0[78]}), .inb({C1[78], C0[78]}),
    .rnd(r[922]), .s(s[922]), .clk(clk), .out({g1_78, g0_78}));
MSKand_opini2_d2_pini u_t_78 (
    .ina({fc1[78], fc0[78]}), .inb({p1_78, p0_78}),
    .rnd(r[923]), .s(s[923]), .clk(clk), .out({t1_78, t0_78}));
assign fc0[79] = g0_78 ^ t0_78;
assign fc1[79] = g1_78 ^ t1_78;
assign prod[156]   = p0_78 ^ fc0[78];
assign prod[157] = p1_78 ^ fc1[78];
wire p0_79 = S_d0[79] ^ C0[79];
wire p1_79 = S_d1[79] ^ C1[79];
wire g0_79, g1_79, t0_79, t1_79;
MSKand_opini2_d2_pini u_g_79 (
    .ina({S_d1[79], S_d0[79]}), .inb({C1[79], C0[79]}),
    .rnd(r[924]), .s(s[924]), .clk(clk), .out({g1_79, g0_79}));
MSKand_opini2_d2_pini u_t_79 (
    .ina({fc1[79], fc0[79]}), .inb({p1_79, p0_79}),
    .rnd(r[925]), .s(s[925]), .clk(clk), .out({t1_79, t0_79}));
assign fc0[80] = g0_79 ^ t0_79;
assign fc1[80] = g1_79 ^ t1_79;
assign prod[158]   = p0_79 ^ fc0[79];
assign prod[159] = p1_79 ^ fc1[79];
wire p0_80 = S_d0[80] ^ C0[80];
wire p1_80 = S_d1[80] ^ C1[80];
wire g0_80, g1_80, t0_80, t1_80;
MSKand_opini2_d2_pini u_g_80 (
    .ina({S_d1[80], S_d0[80]}), .inb({C1[80], C0[80]}),
    .rnd(r[926]), .s(s[926]), .clk(clk), .out({g1_80, g0_80}));
MSKand_opini2_d2_pini u_t_80 (
    .ina({fc1[80], fc0[80]}), .inb({p1_80, p0_80}),
    .rnd(r[927]), .s(s[927]), .clk(clk), .out({t1_80, t0_80}));
assign fc0[81] = g0_80 ^ t0_80;
assign fc1[81] = g1_80 ^ t1_80;
assign prod[160]   = p0_80 ^ fc0[80];
assign prod[161] = p1_80 ^ fc1[80];
wire p0_81 = S_d0[81] ^ C0[81];
wire p1_81 = S_d1[81] ^ C1[81];
wire g0_81, g1_81, t0_81, t1_81;
MSKand_opini2_d2_pini u_g_81 (
    .ina({S_d1[81], S_d0[81]}), .inb({C1[81], C0[81]}),
    .rnd(r[928]), .s(s[928]), .clk(clk), .out({g1_81, g0_81}));
MSKand_opini2_d2_pini u_t_81 (
    .ina({fc1[81], fc0[81]}), .inb({p1_81, p0_81}),
    .rnd(r[929]), .s(s[929]), .clk(clk), .out({t1_81, t0_81}));
assign fc0[82] = g0_81 ^ t0_81;
assign fc1[82] = g1_81 ^ t1_81;
assign prod[162]   = p0_81 ^ fc0[81];
assign prod[163] = p1_81 ^ fc1[81];
wire p0_82 = S_d0[82] ^ C0[82];
wire p1_82 = S_d1[82] ^ C1[82];
wire g0_82, g1_82, t0_82, t1_82;
MSKand_opini2_d2_pini u_g_82 (
    .ina({S_d1[82], S_d0[82]}), .inb({C1[82], C0[82]}),
    .rnd(r[930]), .s(s[930]), .clk(clk), .out({g1_82, g0_82}));
MSKand_opini2_d2_pini u_t_82 (
    .ina({fc1[82], fc0[82]}), .inb({p1_82, p0_82}),
    .rnd(r[931]), .s(s[931]), .clk(clk), .out({t1_82, t0_82}));
assign fc0[83] = g0_82 ^ t0_82;
assign fc1[83] = g1_82 ^ t1_82;
assign prod[164]   = p0_82 ^ fc0[82];
assign prod[165] = p1_82 ^ fc1[82];
wire p0_83 = S_d0[83] ^ C0[83];
wire p1_83 = S_d1[83] ^ C1[83];
wire g0_83, g1_83, t0_83, t1_83;
MSKand_opini2_d2_pini u_g_83 (
    .ina({S_d1[83], S_d0[83]}), .inb({C1[83], C0[83]}),
    .rnd(r[932]), .s(s[932]), .clk(clk), .out({g1_83, g0_83}));
MSKand_opini2_d2_pini u_t_83 (
    .ina({fc1[83], fc0[83]}), .inb({p1_83, p0_83}),
    .rnd(r[933]), .s(s[933]), .clk(clk), .out({t1_83, t0_83}));
assign fc0[84] = g0_83 ^ t0_83;
assign fc1[84] = g1_83 ^ t1_83;
assign prod[166]   = p0_83 ^ fc0[83];
assign prod[167] = p1_83 ^ fc1[83];
wire p0_84 = S_d0[84] ^ C0[84];
wire p1_84 = S_d1[84] ^ C1[84];
wire g0_84, g1_84, t0_84, t1_84;
MSKand_opini2_d2_pini u_g_84 (
    .ina({S_d1[84], S_d0[84]}), .inb({C1[84], C0[84]}),
    .rnd(r[934]), .s(s[934]), .clk(clk), .out({g1_84, g0_84}));
MSKand_opini2_d2_pini u_t_84 (
    .ina({fc1[84], fc0[84]}), .inb({p1_84, p0_84}),
    .rnd(r[935]), .s(s[935]), .clk(clk), .out({t1_84, t0_84}));
assign fc0[85] = g0_84 ^ t0_84;
assign fc1[85] = g1_84 ^ t1_84;
assign prod[168]   = p0_84 ^ fc0[84];
assign prod[169] = p1_84 ^ fc1[84];
wire p0_85 = S_d0[85] ^ C0[85];
wire p1_85 = S_d1[85] ^ C1[85];
wire g0_85, g1_85, t0_85, t1_85;
MSKand_opini2_d2_pini u_g_85 (
    .ina({S_d1[85], S_d0[85]}), .inb({C1[85], C0[85]}),
    .rnd(r[936]), .s(s[936]), .clk(clk), .out({g1_85, g0_85}));
MSKand_opini2_d2_pini u_t_85 (
    .ina({fc1[85], fc0[85]}), .inb({p1_85, p0_85}),
    .rnd(r[937]), .s(s[937]), .clk(clk), .out({t1_85, t0_85}));
assign fc0[86] = g0_85 ^ t0_85;
assign fc1[86] = g1_85 ^ t1_85;
assign prod[170]   = p0_85 ^ fc0[85];
assign prod[171] = p1_85 ^ fc1[85];
wire p0_86 = S_d0[86] ^ C0[86];
wire p1_86 = S_d1[86] ^ C1[86];
wire g0_86, g1_86, t0_86, t1_86;
MSKand_opini2_d2_pini u_g_86 (
    .ina({S_d1[86], S_d0[86]}), .inb({C1[86], C0[86]}),
    .rnd(r[938]), .s(s[938]), .clk(clk), .out({g1_86, g0_86}));
MSKand_opini2_d2_pini u_t_86 (
    .ina({fc1[86], fc0[86]}), .inb({p1_86, p0_86}),
    .rnd(r[939]), .s(s[939]), .clk(clk), .out({t1_86, t0_86}));
assign fc0[87] = g0_86 ^ t0_86;
assign fc1[87] = g1_86 ^ t1_86;
assign prod[172]   = p0_86 ^ fc0[86];
assign prod[173] = p1_86 ^ fc1[86];
wire p0_87 = S_d0[87] ^ C0[87];
wire p1_87 = S_d1[87] ^ C1[87];
wire g0_87, g1_87, t0_87, t1_87;
MSKand_opini2_d2_pini u_g_87 (
    .ina({S_d1[87], S_d0[87]}), .inb({C1[87], C0[87]}),
    .rnd(r[940]), .s(s[940]), .clk(clk), .out({g1_87, g0_87}));
MSKand_opini2_d2_pini u_t_87 (
    .ina({fc1[87], fc0[87]}), .inb({p1_87, p0_87}),
    .rnd(r[941]), .s(s[941]), .clk(clk), .out({t1_87, t0_87}));
assign fc0[88] = g0_87 ^ t0_87;
assign fc1[88] = g1_87 ^ t1_87;
assign prod[174]   = p0_87 ^ fc0[87];
assign prod[175] = p1_87 ^ fc1[87];
wire p0_88 = S_d0[88] ^ C0[88];
wire p1_88 = S_d1[88] ^ C1[88];
wire g0_88, g1_88, t0_88, t1_88;
MSKand_opini2_d2_pini u_g_88 (
    .ina({S_d1[88], S_d0[88]}), .inb({C1[88], C0[88]}),
    .rnd(r[942]), .s(s[942]), .clk(clk), .out({g1_88, g0_88}));
MSKand_opini2_d2_pini u_t_88 (
    .ina({fc1[88], fc0[88]}), .inb({p1_88, p0_88}),
    .rnd(r[943]), .s(s[943]), .clk(clk), .out({t1_88, t0_88}));
assign fc0[89] = g0_88 ^ t0_88;
assign fc1[89] = g1_88 ^ t1_88;
assign prod[176]   = p0_88 ^ fc0[88];
assign prod[177] = p1_88 ^ fc1[88];
wire p0_89 = S_d0[89] ^ C0[89];
wire p1_89 = S_d1[89] ^ C1[89];
wire g0_89, g1_89, t0_89, t1_89;
MSKand_opini2_d2_pini u_g_89 (
    .ina({S_d1[89], S_d0[89]}), .inb({C1[89], C0[89]}),
    .rnd(r[944]), .s(s[944]), .clk(clk), .out({g1_89, g0_89}));
MSKand_opini2_d2_pini u_t_89 (
    .ina({fc1[89], fc0[89]}), .inb({p1_89, p0_89}),
    .rnd(r[945]), .s(s[945]), .clk(clk), .out({t1_89, t0_89}));
assign fc0[90] = g0_89 ^ t0_89;
assign fc1[90] = g1_89 ^ t1_89;
assign prod[178]   = p0_89 ^ fc0[89];
assign prod[179] = p1_89 ^ fc1[89];
wire p0_90 = S_d0[90] ^ C0[90];
wire p1_90 = S_d1[90] ^ C1[90];
wire g0_90, g1_90, t0_90, t1_90;
MSKand_opini2_d2_pini u_g_90 (
    .ina({S_d1[90], S_d0[90]}), .inb({C1[90], C0[90]}),
    .rnd(r[946]), .s(s[946]), .clk(clk), .out({g1_90, g0_90}));
MSKand_opini2_d2_pini u_t_90 (
    .ina({fc1[90], fc0[90]}), .inb({p1_90, p0_90}),
    .rnd(r[947]), .s(s[947]), .clk(clk), .out({t1_90, t0_90}));
assign fc0[91] = g0_90 ^ t0_90;
assign fc1[91] = g1_90 ^ t1_90;
assign prod[180]   = p0_90 ^ fc0[90];
assign prod[181] = p1_90 ^ fc1[90];
wire p0_91 = S_d0[91] ^ C0[91];
wire p1_91 = S_d1[91] ^ C1[91];
wire g0_91, g1_91, t0_91, t1_91;
MSKand_opini2_d2_pini u_g_91 (
    .ina({S_d1[91], S_d0[91]}), .inb({C1[91], C0[91]}),
    .rnd(r[948]), .s(s[948]), .clk(clk), .out({g1_91, g0_91}));
MSKand_opini2_d2_pini u_t_91 (
    .ina({fc1[91], fc0[91]}), .inb({p1_91, p0_91}),
    .rnd(r[949]), .s(s[949]), .clk(clk), .out({t1_91, t0_91}));
assign fc0[92] = g0_91 ^ t0_91;
assign fc1[92] = g1_91 ^ t1_91;
assign prod[182]   = p0_91 ^ fc0[91];
assign prod[183] = p1_91 ^ fc1[91];
wire p0_92 = S_d0[92] ^ C0[92];
wire p1_92 = S_d1[92] ^ C1[92];
wire g0_92, g1_92, t0_92, t1_92;
MSKand_opini2_d2_pini u_g_92 (
    .ina({S_d1[92], S_d0[92]}), .inb({C1[92], C0[92]}),
    .rnd(r[950]), .s(s[950]), .clk(clk), .out({g1_92, g0_92}));
MSKand_opini2_d2_pini u_t_92 (
    .ina({fc1[92], fc0[92]}), .inb({p1_92, p0_92}),
    .rnd(r[951]), .s(s[951]), .clk(clk), .out({t1_92, t0_92}));
assign fc0[93] = g0_92 ^ t0_92;
assign fc1[93] = g1_92 ^ t1_92;
assign prod[184]   = p0_92 ^ fc0[92];
assign prod[185] = p1_92 ^ fc1[92];
wire p0_93 = S_d0[93] ^ C0[93];
wire p1_93 = S_d1[93] ^ C1[93];
wire g0_93, g1_93, t0_93, t1_93;
MSKand_opini2_d2_pini u_g_93 (
    .ina({S_d1[93], S_d0[93]}), .inb({C1[93], C0[93]}),
    .rnd(r[952]), .s(s[952]), .clk(clk), .out({g1_93, g0_93}));
MSKand_opini2_d2_pini u_t_93 (
    .ina({fc1[93], fc0[93]}), .inb({p1_93, p0_93}),
    .rnd(r[953]), .s(s[953]), .clk(clk), .out({t1_93, t0_93}));
assign fc0[94] = g0_93 ^ t0_93;
assign fc1[94] = g1_93 ^ t1_93;
assign prod[186]   = p0_93 ^ fc0[93];
assign prod[187] = p1_93 ^ fc1[93];
wire p0_94 = S_d0[94] ^ C0[94];
wire p1_94 = S_d1[94] ^ C1[94];
wire g0_94, g1_94, t0_94, t1_94;
MSKand_opini2_d2_pini u_g_94 (
    .ina({S_d1[94], S_d0[94]}), .inb({C1[94], C0[94]}),
    .rnd(r[954]), .s(s[954]), .clk(clk), .out({g1_94, g0_94}));
MSKand_opini2_d2_pini u_t_94 (
    .ina({fc1[94], fc0[94]}), .inb({p1_94, p0_94}),
    .rnd(r[955]), .s(s[955]), .clk(clk), .out({t1_94, t0_94}));
assign fc0[95] = g0_94 ^ t0_94;
assign fc1[95] = g1_94 ^ t1_94;
assign prod[188]   = p0_94 ^ fc0[94];
assign prod[189] = p1_94 ^ fc1[94];
wire p0_95 = S_d0[95] ^ C0[95];
wire p1_95 = S_d1[95] ^ C1[95];
wire g0_95, g1_95, t0_95, t1_95;
MSKand_opini2_d2_pini u_g_95 (
    .ina({S_d1[95], S_d0[95]}), .inb({C1[95], C0[95]}),
    .rnd(r[956]), .s(s[956]), .clk(clk), .out({g1_95, g0_95}));
MSKand_opini2_d2_pini u_t_95 (
    .ina({fc1[95], fc0[95]}), .inb({p1_95, p0_95}),
    .rnd(r[957]), .s(s[957]), .clk(clk), .out({t1_95, t0_95}));
assign fc0[96] = g0_95 ^ t0_95;
assign fc1[96] = g1_95 ^ t1_95;
assign prod[190]   = p0_95 ^ fc0[95];
assign prod[191] = p1_95 ^ fc1[95];
wire p0_96 = S_d0[96] ^ C0[96];
wire p1_96 = S_d1[96] ^ C1[96];
wire g0_96, g1_96, t0_96, t1_96;
MSKand_opini2_d2_pini u_g_96 (
    .ina({S_d1[96], S_d0[96]}), .inb({C1[96], C0[96]}),
    .rnd(r[958]), .s(s[958]), .clk(clk), .out({g1_96, g0_96}));
MSKand_opini2_d2_pini u_t_96 (
    .ina({fc1[96], fc0[96]}), .inb({p1_96, p0_96}),
    .rnd(r[959]), .s(s[959]), .clk(clk), .out({t1_96, t0_96}));
assign fc0[97] = g0_96 ^ t0_96;
assign fc1[97] = g1_96 ^ t1_96;
assign prod[192]   = p0_96 ^ fc0[96];
assign prod[193] = p1_96 ^ fc1[96];
wire p0_97 = S_d0[97] ^ C0[97];
wire p1_97 = S_d1[97] ^ C1[97];
wire g0_97, g1_97, t0_97, t1_97;
MSKand_opini2_d2_pini u_g_97 (
    .ina({S_d1[97], S_d0[97]}), .inb({C1[97], C0[97]}),
    .rnd(r[960]), .s(s[960]), .clk(clk), .out({g1_97, g0_97}));
MSKand_opini2_d2_pini u_t_97 (
    .ina({fc1[97], fc0[97]}), .inb({p1_97, p0_97}),
    .rnd(r[961]), .s(s[961]), .clk(clk), .out({t1_97, t0_97}));
assign fc0[98] = g0_97 ^ t0_97;
assign fc1[98] = g1_97 ^ t1_97;
assign prod[194]   = p0_97 ^ fc0[97];
assign prod[195] = p1_97 ^ fc1[97];
wire p0_98 = S_d0[98] ^ C0[98];
wire p1_98 = S_d1[98] ^ C1[98];
wire g0_98, g1_98, t0_98, t1_98;
MSKand_opini2_d2_pini u_g_98 (
    .ina({S_d1[98], S_d0[98]}), .inb({C1[98], C0[98]}),
    .rnd(r[962]), .s(s[962]), .clk(clk), .out({g1_98, g0_98}));
MSKand_opini2_d2_pini u_t_98 (
    .ina({fc1[98], fc0[98]}), .inb({p1_98, p0_98}),
    .rnd(r[963]), .s(s[963]), .clk(clk), .out({t1_98, t0_98}));
assign fc0[99] = g0_98 ^ t0_98;
assign fc1[99] = g1_98 ^ t1_98;
assign prod[196]   = p0_98 ^ fc0[98];
assign prod[197] = p1_98 ^ fc1[98];
wire p0_99 = S_d0[99] ^ C0[99];
wire p1_99 = S_d1[99] ^ C1[99];
wire g0_99, g1_99, t0_99, t1_99;
MSKand_opini2_d2_pini u_g_99 (
    .ina({S_d1[99], S_d0[99]}), .inb({C1[99], C0[99]}),
    .rnd(r[964]), .s(s[964]), .clk(clk), .out({g1_99, g0_99}));
MSKand_opini2_d2_pini u_t_99 (
    .ina({fc1[99], fc0[99]}), .inb({p1_99, p0_99}),
    .rnd(r[965]), .s(s[965]), .clk(clk), .out({t1_99, t0_99}));
assign fc0[100] = g0_99 ^ t0_99;
assign fc1[100] = g1_99 ^ t1_99;
assign prod[198]   = p0_99 ^ fc0[99];
assign prod[199] = p1_99 ^ fc1[99];
wire p0_100 = S_d0[100] ^ C0[100];
wire p1_100 = S_d1[100] ^ C1[100];
wire g0_100, g1_100, t0_100, t1_100;
MSKand_opini2_d2_pini u_g_100 (
    .ina({S_d1[100], S_d0[100]}), .inb({C1[100], C0[100]}),
    .rnd(r[966]), .s(s[966]), .clk(clk), .out({g1_100, g0_100}));
MSKand_opini2_d2_pini u_t_100 (
    .ina({fc1[100], fc0[100]}), .inb({p1_100, p0_100}),
    .rnd(r[967]), .s(s[967]), .clk(clk), .out({t1_100, t0_100}));
assign fc0[101] = g0_100 ^ t0_100;
assign fc1[101] = g1_100 ^ t1_100;
assign prod[200]   = p0_100 ^ fc0[100];
assign prod[201] = p1_100 ^ fc1[100];
wire p0_101 = S_d0[101] ^ C0[101];
wire p1_101 = S_d1[101] ^ C1[101];
wire g0_101, g1_101, t0_101, t1_101;
MSKand_opini2_d2_pini u_g_101 (
    .ina({S_d1[101], S_d0[101]}), .inb({C1[101], C0[101]}),
    .rnd(r[968]), .s(s[968]), .clk(clk), .out({g1_101, g0_101}));
MSKand_opini2_d2_pini u_t_101 (
    .ina({fc1[101], fc0[101]}), .inb({p1_101, p0_101}),
    .rnd(r[969]), .s(s[969]), .clk(clk), .out({t1_101, t0_101}));
assign fc0[102] = g0_101 ^ t0_101;
assign fc1[102] = g1_101 ^ t1_101;
assign prod[202]   = p0_101 ^ fc0[101];
assign prod[203] = p1_101 ^ fc1[101];
wire p0_102 = S_d0[102] ^ C0[102];
wire p1_102 = S_d1[102] ^ C1[102];
wire g0_102, g1_102, t0_102, t1_102;
MSKand_opini2_d2_pini u_g_102 (
    .ina({S_d1[102], S_d0[102]}), .inb({C1[102], C0[102]}),
    .rnd(r[970]), .s(s[970]), .clk(clk), .out({g1_102, g0_102}));
MSKand_opini2_d2_pini u_t_102 (
    .ina({fc1[102], fc0[102]}), .inb({p1_102, p0_102}),
    .rnd(r[971]), .s(s[971]), .clk(clk), .out({t1_102, t0_102}));
assign fc0[103] = g0_102 ^ t0_102;
assign fc1[103] = g1_102 ^ t1_102;
assign prod[204]   = p0_102 ^ fc0[102];
assign prod[205] = p1_102 ^ fc1[102];
wire p0_103 = S_d0[103] ^ C0[103];
wire p1_103 = S_d1[103] ^ C1[103];
wire g0_103, g1_103, t0_103, t1_103;
MSKand_opini2_d2_pini u_g_103 (
    .ina({S_d1[103], S_d0[103]}), .inb({C1[103], C0[103]}),
    .rnd(r[972]), .s(s[972]), .clk(clk), .out({g1_103, g0_103}));
MSKand_opini2_d2_pini u_t_103 (
    .ina({fc1[103], fc0[103]}), .inb({p1_103, p0_103}),
    .rnd(r[973]), .s(s[973]), .clk(clk), .out({t1_103, t0_103}));
assign fc0[104] = g0_103 ^ t0_103;
assign fc1[104] = g1_103 ^ t1_103;
assign prod[206]   = p0_103 ^ fc0[103];
assign prod[207] = p1_103 ^ fc1[103];
wire p0_104 = S_d0[104] ^ C0[104];
wire p1_104 = S_d1[104] ^ C1[104];
wire g0_104, g1_104, t0_104, t1_104;
MSKand_opini2_d2_pini u_g_104 (
    .ina({S_d1[104], S_d0[104]}), .inb({C1[104], C0[104]}),
    .rnd(r[974]), .s(s[974]), .clk(clk), .out({g1_104, g0_104}));
MSKand_opini2_d2_pini u_t_104 (
    .ina({fc1[104], fc0[104]}), .inb({p1_104, p0_104}),
    .rnd(r[975]), .s(s[975]), .clk(clk), .out({t1_104, t0_104}));
assign fc0[105] = g0_104 ^ t0_104;
assign fc1[105] = g1_104 ^ t1_104;
assign prod[208]   = p0_104 ^ fc0[104];
assign prod[209] = p1_104 ^ fc1[104];
wire p0_105 = S_d0[105] ^ C0[105];
wire p1_105 = S_d1[105] ^ C1[105];
wire g0_105, g1_105, t0_105, t1_105;
MSKand_opini2_d2_pini u_g_105 (
    .ina({S_d1[105], S_d0[105]}), .inb({C1[105], C0[105]}),
    .rnd(r[976]), .s(s[976]), .clk(clk), .out({g1_105, g0_105}));
MSKand_opini2_d2_pini u_t_105 (
    .ina({fc1[105], fc0[105]}), .inb({p1_105, p0_105}),
    .rnd(r[977]), .s(s[977]), .clk(clk), .out({t1_105, t0_105}));
assign fc0[106] = g0_105 ^ t0_105;
assign fc1[106] = g1_105 ^ t1_105;
assign prod[210]   = p0_105 ^ fc0[105];
assign prod[211] = p1_105 ^ fc1[105];
wire p0_106 = S_d0[106] ^ C0[106];
wire p1_106 = S_d1[106] ^ C1[106];
wire g0_106, g1_106, t0_106, t1_106;
MSKand_opini2_d2_pini u_g_106 (
    .ina({S_d1[106], S_d0[106]}), .inb({C1[106], C0[106]}),
    .rnd(r[978]), .s(s[978]), .clk(clk), .out({g1_106, g0_106}));
MSKand_opini2_d2_pini u_t_106 (
    .ina({fc1[106], fc0[106]}), .inb({p1_106, p0_106}),
    .rnd(r[979]), .s(s[979]), .clk(clk), .out({t1_106, t0_106}));
assign fc0[107] = g0_106 ^ t0_106;
assign fc1[107] = g1_106 ^ t1_106;
assign prod[212]   = p0_106 ^ fc0[106];
assign prod[213] = p1_106 ^ fc1[106];
wire p0_107 = S_d0[107] ^ C0[107];
wire p1_107 = S_d1[107] ^ C1[107];
wire g0_107, g1_107, t0_107, t1_107;
MSKand_opini2_d2_pini u_g_107 (
    .ina({S_d1[107], S_d0[107]}), .inb({C1[107], C0[107]}),
    .rnd(r[980]), .s(s[980]), .clk(clk), .out({g1_107, g0_107}));
MSKand_opini2_d2_pini u_t_107 (
    .ina({fc1[107], fc0[107]}), .inb({p1_107, p0_107}),
    .rnd(r[981]), .s(s[981]), .clk(clk), .out({t1_107, t0_107}));
assign fc0[108] = g0_107 ^ t0_107;
assign fc1[108] = g1_107 ^ t1_107;
assign prod[214]   = p0_107 ^ fc0[107];
assign prod[215] = p1_107 ^ fc1[107];
wire p0_108 = S_d0[108] ^ C0[108];
wire p1_108 = S_d1[108] ^ C1[108];
wire g0_108, g1_108, t0_108, t1_108;
MSKand_opini2_d2_pini u_g_108 (
    .ina({S_d1[108], S_d0[108]}), .inb({C1[108], C0[108]}),
    .rnd(r[982]), .s(s[982]), .clk(clk), .out({g1_108, g0_108}));
MSKand_opini2_d2_pini u_t_108 (
    .ina({fc1[108], fc0[108]}), .inb({p1_108, p0_108}),
    .rnd(r[983]), .s(s[983]), .clk(clk), .out({t1_108, t0_108}));
assign fc0[109] = g0_108 ^ t0_108;
assign fc1[109] = g1_108 ^ t1_108;
assign prod[216]   = p0_108 ^ fc0[108];
assign prod[217] = p1_108 ^ fc1[108];
wire p0_109 = S_d0[109] ^ C0[109];
wire p1_109 = S_d1[109] ^ C1[109];
wire g0_109, g1_109, t0_109, t1_109;
MSKand_opini2_d2_pini u_g_109 (
    .ina({S_d1[109], S_d0[109]}), .inb({C1[109], C0[109]}),
    .rnd(r[984]), .s(s[984]), .clk(clk), .out({g1_109, g0_109}));
MSKand_opini2_d2_pini u_t_109 (
    .ina({fc1[109], fc0[109]}), .inb({p1_109, p0_109}),
    .rnd(r[985]), .s(s[985]), .clk(clk), .out({t1_109, t0_109}));
assign fc0[110] = g0_109 ^ t0_109;
assign fc1[110] = g1_109 ^ t1_109;
assign prod[218]   = p0_109 ^ fc0[109];
assign prod[219] = p1_109 ^ fc1[109];
wire p0_110 = S_d0[110] ^ C0[110];
wire p1_110 = S_d1[110] ^ C1[110];
wire g0_110, g1_110, t0_110, t1_110;
MSKand_opini2_d2_pini u_g_110 (
    .ina({S_d1[110], S_d0[110]}), .inb({C1[110], C0[110]}),
    .rnd(r[986]), .s(s[986]), .clk(clk), .out({g1_110, g0_110}));
MSKand_opini2_d2_pini u_t_110 (
    .ina({fc1[110], fc0[110]}), .inb({p1_110, p0_110}),
    .rnd(r[987]), .s(s[987]), .clk(clk), .out({t1_110, t0_110}));
assign fc0[111] = g0_110 ^ t0_110;
assign fc1[111] = g1_110 ^ t1_110;
assign prod[220]   = p0_110 ^ fc0[110];
assign prod[221] = p1_110 ^ fc1[110];
wire p0_111 = S_d0[111] ^ C0[111];
wire p1_111 = S_d1[111] ^ C1[111];
wire g0_111, g1_111, t0_111, t1_111;
MSKand_opini2_d2_pini u_g_111 (
    .ina({S_d1[111], S_d0[111]}), .inb({C1[111], C0[111]}),
    .rnd(r[988]), .s(s[988]), .clk(clk), .out({g1_111, g0_111}));
MSKand_opini2_d2_pini u_t_111 (
    .ina({fc1[111], fc0[111]}), .inb({p1_111, p0_111}),
    .rnd(r[989]), .s(s[989]), .clk(clk), .out({t1_111, t0_111}));
assign fc0[112] = g0_111 ^ t0_111;
assign fc1[112] = g1_111 ^ t1_111;
assign prod[222]   = p0_111 ^ fc0[111];
assign prod[223] = p1_111 ^ fc1[111];
wire p0_112 = S_d0[112] ^ C0[112];
wire p1_112 = S_d1[112] ^ C1[112];
wire g0_112, g1_112, t0_112, t1_112;
MSKand_opini2_d2_pini u_g_112 (
    .ina({S_d1[112], S_d0[112]}), .inb({C1[112], C0[112]}),
    .rnd(r[990]), .s(s[990]), .clk(clk), .out({g1_112, g0_112}));
MSKand_opini2_d2_pini u_t_112 (
    .ina({fc1[112], fc0[112]}), .inb({p1_112, p0_112}),
    .rnd(r[991]), .s(s[991]), .clk(clk), .out({t1_112, t0_112}));
assign fc0[113] = g0_112 ^ t0_112;
assign fc1[113] = g1_112 ^ t1_112;
assign prod[224]   = p0_112 ^ fc0[112];
assign prod[225] = p1_112 ^ fc1[112];
wire p0_113 = S_d0[113] ^ C0[113];
wire p1_113 = S_d1[113] ^ C1[113];
wire g0_113, g1_113, t0_113, t1_113;
MSKand_opini2_d2_pini u_g_113 (
    .ina({S_d1[113], S_d0[113]}), .inb({C1[113], C0[113]}),
    .rnd(r[992]), .s(s[992]), .clk(clk), .out({g1_113, g0_113}));
MSKand_opini2_d2_pini u_t_113 (
    .ina({fc1[113], fc0[113]}), .inb({p1_113, p0_113}),
    .rnd(r[993]), .s(s[993]), .clk(clk), .out({t1_113, t0_113}));
assign fc0[114] = g0_113 ^ t0_113;
assign fc1[114] = g1_113 ^ t1_113;
assign prod[226]   = p0_113 ^ fc0[113];
assign prod[227] = p1_113 ^ fc1[113];
wire p0_114 = S_d0[114] ^ C0[114];
wire p1_114 = S_d1[114] ^ C1[114];
wire g0_114, g1_114, t0_114, t1_114;
MSKand_opini2_d2_pini u_g_114 (
    .ina({S_d1[114], S_d0[114]}), .inb({C1[114], C0[114]}),
    .rnd(r[994]), .s(s[994]), .clk(clk), .out({g1_114, g0_114}));
MSKand_opini2_d2_pini u_t_114 (
    .ina({fc1[114], fc0[114]}), .inb({p1_114, p0_114}),
    .rnd(r[995]), .s(s[995]), .clk(clk), .out({t1_114, t0_114}));
assign fc0[115] = g0_114 ^ t0_114;
assign fc1[115] = g1_114 ^ t1_114;
assign prod[228]   = p0_114 ^ fc0[114];
assign prod[229] = p1_114 ^ fc1[114];
wire p0_115 = S_d0[115] ^ C0[115];
wire p1_115 = S_d1[115] ^ C1[115];
wire g0_115, g1_115, t0_115, t1_115;
MSKand_opini2_d2_pini u_g_115 (
    .ina({S_d1[115], S_d0[115]}), .inb({C1[115], C0[115]}),
    .rnd(r[996]), .s(s[996]), .clk(clk), .out({g1_115, g0_115}));
MSKand_opini2_d2_pini u_t_115 (
    .ina({fc1[115], fc0[115]}), .inb({p1_115, p0_115}),
    .rnd(r[997]), .s(s[997]), .clk(clk), .out({t1_115, t0_115}));
assign fc0[116] = g0_115 ^ t0_115;
assign fc1[116] = g1_115 ^ t1_115;
assign prod[230]   = p0_115 ^ fc0[115];
assign prod[231] = p1_115 ^ fc1[115];
wire p0_116 = S_d0[116] ^ C0[116];
wire p1_116 = S_d1[116] ^ C1[116];
wire g0_116, g1_116, t0_116, t1_116;
MSKand_opini2_d2_pini u_g_116 (
    .ina({S_d1[116], S_d0[116]}), .inb({C1[116], C0[116]}),
    .rnd(r[998]), .s(s[998]), .clk(clk), .out({g1_116, g0_116}));
MSKand_opini2_d2_pini u_t_116 (
    .ina({fc1[116], fc0[116]}), .inb({p1_116, p0_116}),
    .rnd(r[999]), .s(s[999]), .clk(clk), .out({t1_116, t0_116}));
assign fc0[117] = g0_116 ^ t0_116;
assign fc1[117] = g1_116 ^ t1_116;
assign prod[232]   = p0_116 ^ fc0[116];
assign prod[233] = p1_116 ^ fc1[116];
wire p0_117 = S_d0[117] ^ C0[117];
wire p1_117 = S_d1[117] ^ C1[117];
wire g0_117, g1_117, t0_117, t1_117;
MSKand_opini2_d2_pini u_g_117 (
    .ina({S_d1[117], S_d0[117]}), .inb({C1[117], C0[117]}),
    .rnd(r[1000]), .s(s[1000]), .clk(clk), .out({g1_117, g0_117}));
MSKand_opini2_d2_pini u_t_117 (
    .ina({fc1[117], fc0[117]}), .inb({p1_117, p0_117}),
    .rnd(r[1001]), .s(s[1001]), .clk(clk), .out({t1_117, t0_117}));
assign fc0[118] = g0_117 ^ t0_117;
assign fc1[118] = g1_117 ^ t1_117;
assign prod[234]   = p0_117 ^ fc0[117];
assign prod[235] = p1_117 ^ fc1[117];
wire p0_118 = S_d0[118] ^ C0[118];
wire p1_118 = S_d1[118] ^ C1[118];
wire g0_118, g1_118, t0_118, t1_118;
MSKand_opini2_d2_pini u_g_118 (
    .ina({S_d1[118], S_d0[118]}), .inb({C1[118], C0[118]}),
    .rnd(r[1002]), .s(s[1002]), .clk(clk), .out({g1_118, g0_118}));
MSKand_opini2_d2_pini u_t_118 (
    .ina({fc1[118], fc0[118]}), .inb({p1_118, p0_118}),
    .rnd(r[1003]), .s(s[1003]), .clk(clk), .out({t1_118, t0_118}));
assign fc0[119] = g0_118 ^ t0_118;
assign fc1[119] = g1_118 ^ t1_118;
assign prod[236]   = p0_118 ^ fc0[118];
assign prod[237] = p1_118 ^ fc1[118];
wire p0_119 = S_d0[119] ^ C0[119];
wire p1_119 = S_d1[119] ^ C1[119];
wire g0_119, g1_119, t0_119, t1_119;
MSKand_opini2_d2_pini u_g_119 (
    .ina({S_d1[119], S_d0[119]}), .inb({C1[119], C0[119]}),
    .rnd(r[1004]), .s(s[1004]), .clk(clk), .out({g1_119, g0_119}));
MSKand_opini2_d2_pini u_t_119 (
    .ina({fc1[119], fc0[119]}), .inb({p1_119, p0_119}),
    .rnd(r[1005]), .s(s[1005]), .clk(clk), .out({t1_119, t0_119}));
assign fc0[120] = g0_119 ^ t0_119;
assign fc1[120] = g1_119 ^ t1_119;
assign prod[238]   = p0_119 ^ fc0[119];
assign prod[239] = p1_119 ^ fc1[119];
wire p0_120 = S_d0[120] ^ C0[120];
wire p1_120 = S_d1[120] ^ C1[120];
wire g0_120, g1_120, t0_120, t1_120;
MSKand_opini2_d2_pini u_g_120 (
    .ina({S_d1[120], S_d0[120]}), .inb({C1[120], C0[120]}),
    .rnd(r[1006]), .s(s[1006]), .clk(clk), .out({g1_120, g0_120}));
MSKand_opini2_d2_pini u_t_120 (
    .ina({fc1[120], fc0[120]}), .inb({p1_120, p0_120}),
    .rnd(r[1007]), .s(s[1007]), .clk(clk), .out({t1_120, t0_120}));
assign fc0[121] = g0_120 ^ t0_120;
assign fc1[121] = g1_120 ^ t1_120;
assign prod[240]   = p0_120 ^ fc0[120];
assign prod[241] = p1_120 ^ fc1[120];
wire p0_121 = S_d0[121] ^ C0[121];
wire p1_121 = S_d1[121] ^ C1[121];
wire g0_121, g1_121, t0_121, t1_121;
MSKand_opini2_d2_pini u_g_121 (
    .ina({S_d1[121], S_d0[121]}), .inb({C1[121], C0[121]}),
    .rnd(r[1008]), .s(s[1008]), .clk(clk), .out({g1_121, g0_121}));
MSKand_opini2_d2_pini u_t_121 (
    .ina({fc1[121], fc0[121]}), .inb({p1_121, p0_121}),
    .rnd(r[1009]), .s(s[1009]), .clk(clk), .out({t1_121, t0_121}));
assign fc0[122] = g0_121 ^ t0_121;
assign fc1[122] = g1_121 ^ t1_121;
assign prod[242]   = p0_121 ^ fc0[121];
assign prod[243] = p1_121 ^ fc1[121];
wire p0_122 = S_d0[122] ^ C0[122];
wire p1_122 = S_d1[122] ^ C1[122];
wire g0_122, g1_122, t0_122, t1_122;
MSKand_opini2_d2_pini u_g_122 (
    .ina({S_d1[122], S_d0[122]}), .inb({C1[122], C0[122]}),
    .rnd(r[1010]), .s(s[1010]), .clk(clk), .out({g1_122, g0_122}));
MSKand_opini2_d2_pini u_t_122 (
    .ina({fc1[122], fc0[122]}), .inb({p1_122, p0_122}),
    .rnd(r[1011]), .s(s[1011]), .clk(clk), .out({t1_122, t0_122}));
assign fc0[123] = g0_122 ^ t0_122;
assign fc1[123] = g1_122 ^ t1_122;
assign prod[244]   = p0_122 ^ fc0[122];
assign prod[245] = p1_122 ^ fc1[122];
wire p0_123 = S_d0[123] ^ C0[123];
wire p1_123 = S_d1[123] ^ C1[123];
wire g0_123, g1_123, t0_123, t1_123;
MSKand_opini2_d2_pini u_g_123 (
    .ina({S_d1[123], S_d0[123]}), .inb({C1[123], C0[123]}),
    .rnd(r[1012]), .s(s[1012]), .clk(clk), .out({g1_123, g0_123}));
MSKand_opini2_d2_pini u_t_123 (
    .ina({fc1[123], fc0[123]}), .inb({p1_123, p0_123}),
    .rnd(r[1013]), .s(s[1013]), .clk(clk), .out({t1_123, t0_123}));
assign fc0[124] = g0_123 ^ t0_123;
assign fc1[124] = g1_123 ^ t1_123;
assign prod[246]   = p0_123 ^ fc0[123];
assign prod[247] = p1_123 ^ fc1[123];
wire p0_124 = S_d0[124] ^ C0[124];
wire p1_124 = S_d1[124] ^ C1[124];
wire g0_124, g1_124, t0_124, t1_124;
MSKand_opini2_d2_pini u_g_124 (
    .ina({S_d1[124], S_d0[124]}), .inb({C1[124], C0[124]}),
    .rnd(r[1014]), .s(s[1014]), .clk(clk), .out({g1_124, g0_124}));
MSKand_opini2_d2_pini u_t_124 (
    .ina({fc1[124], fc0[124]}), .inb({p1_124, p0_124}),
    .rnd(r[1015]), .s(s[1015]), .clk(clk), .out({t1_124, t0_124}));
assign fc0[125] = g0_124 ^ t0_124;
assign fc1[125] = g1_124 ^ t1_124;
assign prod[248]   = p0_124 ^ fc0[124];
assign prod[249] = p1_124 ^ fc1[124];
wire p0_125 = S_d0[125] ^ C0[125];
wire p1_125 = S_d1[125] ^ C1[125];
wire g0_125, g1_125, t0_125, t1_125;
MSKand_opini2_d2_pini u_g_125 (
    .ina({S_d1[125], S_d0[125]}), .inb({C1[125], C0[125]}),
    .rnd(r[1016]), .s(s[1016]), .clk(clk), .out({g1_125, g0_125}));
MSKand_opini2_d2_pini u_t_125 (
    .ina({fc1[125], fc0[125]}), .inb({p1_125, p0_125}),
    .rnd(r[1017]), .s(s[1017]), .clk(clk), .out({t1_125, t0_125}));
assign fc0[126] = g0_125 ^ t0_125;
assign fc1[126] = g1_125 ^ t1_125;
assign prod[250]   = p0_125 ^ fc0[125];
assign prod[251] = p1_125 ^ fc1[125];
wire p0_126 = S_d0[126] ^ C0[126];
wire p1_126 = S_d1[126] ^ C1[126];
wire g0_126, g1_126, t0_126, t1_126;
MSKand_opini2_d2_pini u_g_126 (
    .ina({S_d1[126], S_d0[126]}), .inb({C1[126], C0[126]}),
    .rnd(r[1018]), .s(s[1018]), .clk(clk), .out({g1_126, g0_126}));
MSKand_opini2_d2_pini u_t_126 (
    .ina({fc1[126], fc0[126]}), .inb({p1_126, p0_126}),
    .rnd(r[1019]), .s(s[1019]), .clk(clk), .out({t1_126, t0_126}));
assign fc0[127] = g0_126 ^ t0_126;
assign fc1[127] = g1_126 ^ t1_126;
assign prod[252]   = p0_126 ^ fc0[126];
assign prod[253] = p1_126 ^ fc1[126];
wire p0_127 = S_d0[127] ^ C0[127];
wire p1_127 = S_d1[127] ^ C1[127];
wire g0_127, g1_127, t0_127, t1_127;
MSKand_opini2_d2_pini u_g_127 (
    .ina({S_d1[127], S_d0[127]}), .inb({C1[127], C0[127]}),
    .rnd(r[1020]), .s(s[1020]), .clk(clk), .out({g1_127, g0_127}));
MSKand_opini2_d2_pini u_t_127 (
    .ina({fc1[127], fc0[127]}), .inb({p1_127, p0_127}),
    .rnd(r[1021]), .s(s[1021]), .clk(clk), .out({t1_127, t0_127}));
assign fc0[128] = g0_127 ^ t0_127;
assign fc1[128] = g1_127 ^ t1_127;
assign prod[254]   = p0_127 ^ fc0[127];
assign prod[255] = p1_127 ^ fc1[127];
wire p0_128 = S_d0[128] ^ C0[128];
wire p1_128 = S_d1[128] ^ C1[128];
wire g0_128, g1_128, t0_128, t1_128;
MSKand_opini2_d2_pini u_g_128 (
    .ina({S_d1[128], S_d0[128]}), .inb({C1[128], C0[128]}),
    .rnd(r[1022]), .s(s[1022]), .clk(clk), .out({g1_128, g0_128}));
MSKand_opini2_d2_pini u_t_128 (
    .ina({fc1[128], fc0[128]}), .inb({p1_128, p0_128}),
    .rnd(r[1023]), .s(s[1023]), .clk(clk), .out({t1_128, t0_128}));
assign fc0[129] = g0_128 ^ t0_128;
assign fc1[129] = g1_128 ^ t1_128;
assign prod[256]   = p0_128 ^ fc0[128];
assign prod[257] = p1_128 ^ fc1[128];
wire p0_129 = S_d0[129] ^ C0[129];
wire p1_129 = S_d1[129] ^ C1[129];
wire g0_129, g1_129, t0_129, t1_129;
MSKand_opini2_d2_pini u_g_129 (
    .ina({S_d1[129], S_d0[129]}), .inb({C1[129], C0[129]}),
    .rnd(r[1024]), .s(s[1024]), .clk(clk), .out({g1_129, g0_129}));
MSKand_opini2_d2_pini u_t_129 (
    .ina({fc1[129], fc0[129]}), .inb({p1_129, p0_129}),
    .rnd(r[1025]), .s(s[1025]), .clk(clk), .out({t1_129, t0_129}));
assign fc0[130] = g0_129 ^ t0_129;
assign fc1[130] = g1_129 ^ t1_129;
assign prod[258]   = p0_129 ^ fc0[129];
assign prod[259] = p1_129 ^ fc1[129];
wire p0_130 = S_d0[130] ^ C0[130];
wire p1_130 = S_d1[130] ^ C1[130];
wire g0_130, g1_130, t0_130, t1_130;
MSKand_opini2_d2_pini u_g_130 (
    .ina({S_d1[130], S_d0[130]}), .inb({C1[130], C0[130]}),
    .rnd(r[1026]), .s(s[1026]), .clk(clk), .out({g1_130, g0_130}));
MSKand_opini2_d2_pini u_t_130 (
    .ina({fc1[130], fc0[130]}), .inb({p1_130, p0_130}),
    .rnd(r[1027]), .s(s[1027]), .clk(clk), .out({t1_130, t0_130}));
assign fc0[131] = g0_130 ^ t0_130;
assign fc1[131] = g1_130 ^ t1_130;
assign prod[260]   = p0_130 ^ fc0[130];
assign prod[261] = p1_130 ^ fc1[130];
wire p0_131 = S_d0[131] ^ C0[131];
wire p1_131 = S_d1[131] ^ C1[131];
wire g0_131, g1_131, t0_131, t1_131;
MSKand_opini2_d2_pini u_g_131 (
    .ina({S_d1[131], S_d0[131]}), .inb({C1[131], C0[131]}),
    .rnd(r[1028]), .s(s[1028]), .clk(clk), .out({g1_131, g0_131}));
MSKand_opini2_d2_pini u_t_131 (
    .ina({fc1[131], fc0[131]}), .inb({p1_131, p0_131}),
    .rnd(r[1029]), .s(s[1029]), .clk(clk), .out({t1_131, t0_131}));
assign fc0[132] = g0_131 ^ t0_131;
assign fc1[132] = g1_131 ^ t1_131;
assign prod[262]   = p0_131 ^ fc0[131];
assign prod[263] = p1_131 ^ fc1[131];
wire p0_132 = S_d0[132] ^ C0[132];
wire p1_132 = S_d1[132] ^ C1[132];
wire g0_132, g1_132, t0_132, t1_132;
MSKand_opini2_d2_pini u_g_132 (
    .ina({S_d1[132], S_d0[132]}), .inb({C1[132], C0[132]}),
    .rnd(r[1030]), .s(s[1030]), .clk(clk), .out({g1_132, g0_132}));
MSKand_opini2_d2_pini u_t_132 (
    .ina({fc1[132], fc0[132]}), .inb({p1_132, p0_132}),
    .rnd(r[1031]), .s(s[1031]), .clk(clk), .out({t1_132, t0_132}));
assign fc0[133] = g0_132 ^ t0_132;
assign fc1[133] = g1_132 ^ t1_132;
assign prod[264]   = p0_132 ^ fc0[132];
assign prod[265] = p1_132 ^ fc1[132];
wire p0_133 = S_d0[133] ^ C0[133];
wire p1_133 = S_d1[133] ^ C1[133];
wire g0_133, g1_133, t0_133, t1_133;
MSKand_opini2_d2_pini u_g_133 (
    .ina({S_d1[133], S_d0[133]}), .inb({C1[133], C0[133]}),
    .rnd(r[1032]), .s(s[1032]), .clk(clk), .out({g1_133, g0_133}));
MSKand_opini2_d2_pini u_t_133 (
    .ina({fc1[133], fc0[133]}), .inb({p1_133, p0_133}),
    .rnd(r[1033]), .s(s[1033]), .clk(clk), .out({t1_133, t0_133}));
assign fc0[134] = g0_133 ^ t0_133;
assign fc1[134] = g1_133 ^ t1_133;
assign prod[266]   = p0_133 ^ fc0[133];
assign prod[267] = p1_133 ^ fc1[133];
wire p0_134 = S_d0[134] ^ C0[134];
wire p1_134 = S_d1[134] ^ C1[134];
wire g0_134, g1_134, t0_134, t1_134;
MSKand_opini2_d2_pini u_g_134 (
    .ina({S_d1[134], S_d0[134]}), .inb({C1[134], C0[134]}),
    .rnd(r[1034]), .s(s[1034]), .clk(clk), .out({g1_134, g0_134}));
MSKand_opini2_d2_pini u_t_134 (
    .ina({fc1[134], fc0[134]}), .inb({p1_134, p0_134}),
    .rnd(r[1035]), .s(s[1035]), .clk(clk), .out({t1_134, t0_134}));
assign fc0[135] = g0_134 ^ t0_134;
assign fc1[135] = g1_134 ^ t1_134;
assign prod[268]   = p0_134 ^ fc0[134];
assign prod[269] = p1_134 ^ fc1[134];
wire p0_135 = S_d0[135] ^ C0[135];
wire p1_135 = S_d1[135] ^ C1[135];
wire g0_135, g1_135, t0_135, t1_135;
MSKand_opini2_d2_pini u_g_135 (
    .ina({S_d1[135], S_d0[135]}), .inb({C1[135], C0[135]}),
    .rnd(r[1036]), .s(s[1036]), .clk(clk), .out({g1_135, g0_135}));
MSKand_opini2_d2_pini u_t_135 (
    .ina({fc1[135], fc0[135]}), .inb({p1_135, p0_135}),
    .rnd(r[1037]), .s(s[1037]), .clk(clk), .out({t1_135, t0_135}));
assign fc0[136] = g0_135 ^ t0_135;
assign fc1[136] = g1_135 ^ t1_135;
assign prod[270]   = p0_135 ^ fc0[135];
assign prod[271] = p1_135 ^ fc1[135];
wire p0_136 = S_d0[136] ^ C0[136];
wire p1_136 = S_d1[136] ^ C1[136];
wire g0_136, g1_136, t0_136, t1_136;
MSKand_opini2_d2_pini u_g_136 (
    .ina({S_d1[136], S_d0[136]}), .inb({C1[136], C0[136]}),
    .rnd(r[1038]), .s(s[1038]), .clk(clk), .out({g1_136, g0_136}));
MSKand_opini2_d2_pini u_t_136 (
    .ina({fc1[136], fc0[136]}), .inb({p1_136, p0_136}),
    .rnd(r[1039]), .s(s[1039]), .clk(clk), .out({t1_136, t0_136}));
assign fc0[137] = g0_136 ^ t0_136;
assign fc1[137] = g1_136 ^ t1_136;
assign prod[272]   = p0_136 ^ fc0[136];
assign prod[273] = p1_136 ^ fc1[136];
wire p0_137 = S_d0[137] ^ C0[137];
wire p1_137 = S_d1[137] ^ C1[137];
wire g0_137, g1_137, t0_137, t1_137;
MSKand_opini2_d2_pini u_g_137 (
    .ina({S_d1[137], S_d0[137]}), .inb({C1[137], C0[137]}),
    .rnd(r[1040]), .s(s[1040]), .clk(clk), .out({g1_137, g0_137}));
MSKand_opini2_d2_pini u_t_137 (
    .ina({fc1[137], fc0[137]}), .inb({p1_137, p0_137}),
    .rnd(r[1041]), .s(s[1041]), .clk(clk), .out({t1_137, t0_137}));
assign fc0[138] = g0_137 ^ t0_137;
assign fc1[138] = g1_137 ^ t1_137;
assign prod[274]   = p0_137 ^ fc0[137];
assign prod[275] = p1_137 ^ fc1[137];
wire p0_138 = S_d0[138] ^ C0[138];
wire p1_138 = S_d1[138] ^ C1[138];
wire g0_138, g1_138, t0_138, t1_138;
MSKand_opini2_d2_pini u_g_138 (
    .ina({S_d1[138], S_d0[138]}), .inb({C1[138], C0[138]}),
    .rnd(r[1042]), .s(s[1042]), .clk(clk), .out({g1_138, g0_138}));
MSKand_opini2_d2_pini u_t_138 (
    .ina({fc1[138], fc0[138]}), .inb({p1_138, p0_138}),
    .rnd(r[1043]), .s(s[1043]), .clk(clk), .out({t1_138, t0_138}));
assign fc0[139] = g0_138 ^ t0_138;
assign fc1[139] = g1_138 ^ t1_138;
assign prod[276]   = p0_138 ^ fc0[138];
assign prod[277] = p1_138 ^ fc1[138];
wire p0_139 = S_d0[139] ^ C0[139];
wire p1_139 = S_d1[139] ^ C1[139];
wire g0_139, g1_139, t0_139, t1_139;
MSKand_opini2_d2_pini u_g_139 (
    .ina({S_d1[139], S_d0[139]}), .inb({C1[139], C0[139]}),
    .rnd(r[1044]), .s(s[1044]), .clk(clk), .out({g1_139, g0_139}));
MSKand_opini2_d2_pini u_t_139 (
    .ina({fc1[139], fc0[139]}), .inb({p1_139, p0_139}),
    .rnd(r[1045]), .s(s[1045]), .clk(clk), .out({t1_139, t0_139}));
assign fc0[140] = g0_139 ^ t0_139;
assign fc1[140] = g1_139 ^ t1_139;
assign prod[278]   = p0_139 ^ fc0[139];
assign prod[279] = p1_139 ^ fc1[139];
wire p0_140 = S_d0[140] ^ C0[140];
wire p1_140 = S_d1[140] ^ C1[140];
wire g0_140, g1_140, t0_140, t1_140;
MSKand_opini2_d2_pini u_g_140 (
    .ina({S_d1[140], S_d0[140]}), .inb({C1[140], C0[140]}),
    .rnd(r[1046]), .s(s[1046]), .clk(clk), .out({g1_140, g0_140}));
MSKand_opini2_d2_pini u_t_140 (
    .ina({fc1[140], fc0[140]}), .inb({p1_140, p0_140}),
    .rnd(r[1047]), .s(s[1047]), .clk(clk), .out({t1_140, t0_140}));
assign fc0[141] = g0_140 ^ t0_140;
assign fc1[141] = g1_140 ^ t1_140;
assign prod[280]   = p0_140 ^ fc0[140];
assign prod[281] = p1_140 ^ fc1[140];
wire p0_141 = S_d0[141] ^ C0[141];
wire p1_141 = S_d1[141] ^ C1[141];
wire g0_141, g1_141, t0_141, t1_141;
MSKand_opini2_d2_pini u_g_141 (
    .ina({S_d1[141], S_d0[141]}), .inb({C1[141], C0[141]}),
    .rnd(r[1048]), .s(s[1048]), .clk(clk), .out({g1_141, g0_141}));
MSKand_opini2_d2_pini u_t_141 (
    .ina({fc1[141], fc0[141]}), .inb({p1_141, p0_141}),
    .rnd(r[1049]), .s(s[1049]), .clk(clk), .out({t1_141, t0_141}));
assign fc0[142] = g0_141 ^ t0_141;
assign fc1[142] = g1_141 ^ t1_141;
assign prod[282]   = p0_141 ^ fc0[141];
assign prod[283] = p1_141 ^ fc1[141];
wire p0_142 = S_d0[142] ^ C0[142];
wire p1_142 = S_d1[142] ^ C1[142];
wire g0_142, g1_142, t0_142, t1_142;
MSKand_opini2_d2_pini u_g_142 (
    .ina({S_d1[142], S_d0[142]}), .inb({C1[142], C0[142]}),
    .rnd(r[1050]), .s(s[1050]), .clk(clk), .out({g1_142, g0_142}));
MSKand_opini2_d2_pini u_t_142 (
    .ina({fc1[142], fc0[142]}), .inb({p1_142, p0_142}),
    .rnd(r[1051]), .s(s[1051]), .clk(clk), .out({t1_142, t0_142}));
assign fc0[143] = g0_142 ^ t0_142;
assign fc1[143] = g1_142 ^ t1_142;
assign prod[284]   = p0_142 ^ fc0[142];
assign prod[285] = p1_142 ^ fc1[142];
wire p0_143 = S_d0[143] ^ C0[143];
wire p1_143 = S_d1[143] ^ C1[143];
wire g0_143, g1_143, t0_143, t1_143;
MSKand_opini2_d2_pini u_g_143 (
    .ina({S_d1[143], S_d0[143]}), .inb({C1[143], C0[143]}),
    .rnd(r[1052]), .s(s[1052]), .clk(clk), .out({g1_143, g0_143}));
MSKand_opini2_d2_pini u_t_143 (
    .ina({fc1[143], fc0[143]}), .inb({p1_143, p0_143}),
    .rnd(r[1053]), .s(s[1053]), .clk(clk), .out({t1_143, t0_143}));
assign fc0[144] = g0_143 ^ t0_143;
assign fc1[144] = g1_143 ^ t1_143;
assign prod[286]   = p0_143 ^ fc0[143];
assign prod[287] = p1_143 ^ fc1[143];
wire p0_144 = S_d0[144] ^ C0[144];
wire p1_144 = S_d1[144] ^ C1[144];
wire g0_144, g1_144, t0_144, t1_144;
MSKand_opini2_d2_pini u_g_144 (
    .ina({S_d1[144], S_d0[144]}), .inb({C1[144], C0[144]}),
    .rnd(r[1054]), .s(s[1054]), .clk(clk), .out({g1_144, g0_144}));
MSKand_opini2_d2_pini u_t_144 (
    .ina({fc1[144], fc0[144]}), .inb({p1_144, p0_144}),
    .rnd(r[1055]), .s(s[1055]), .clk(clk), .out({t1_144, t0_144}));
assign fc0[145] = g0_144 ^ t0_144;
assign fc1[145] = g1_144 ^ t1_144;
assign prod[288]   = p0_144 ^ fc0[144];
assign prod[289] = p1_144 ^ fc1[144];
wire p0_145 = S_d0[145] ^ C0[145];
wire p1_145 = S_d1[145] ^ C1[145];
wire g0_145, g1_145, t0_145, t1_145;
MSKand_opini2_d2_pini u_g_145 (
    .ina({S_d1[145], S_d0[145]}), .inb({C1[145], C0[145]}),
    .rnd(r[1056]), .s(s[1056]), .clk(clk), .out({g1_145, g0_145}));
MSKand_opini2_d2_pini u_t_145 (
    .ina({fc1[145], fc0[145]}), .inb({p1_145, p0_145}),
    .rnd(r[1057]), .s(s[1057]), .clk(clk), .out({t1_145, t0_145}));
assign fc0[146] = g0_145 ^ t0_145;
assign fc1[146] = g1_145 ^ t1_145;
assign prod[290]   = p0_145 ^ fc0[145];
assign prod[291] = p1_145 ^ fc1[145];
wire p0_146 = S_d0[146] ^ C0[146];
wire p1_146 = S_d1[146] ^ C1[146];
wire g0_146, g1_146, t0_146, t1_146;
MSKand_opini2_d2_pini u_g_146 (
    .ina({S_d1[146], S_d0[146]}), .inb({C1[146], C0[146]}),
    .rnd(r[1058]), .s(s[1058]), .clk(clk), .out({g1_146, g0_146}));
MSKand_opini2_d2_pini u_t_146 (
    .ina({fc1[146], fc0[146]}), .inb({p1_146, p0_146}),
    .rnd(r[1059]), .s(s[1059]), .clk(clk), .out({t1_146, t0_146}));
assign fc0[147] = g0_146 ^ t0_146;
assign fc1[147] = g1_146 ^ t1_146;
assign prod[292]   = p0_146 ^ fc0[146];
assign prod[293] = p1_146 ^ fc1[146];
wire p0_147 = S_d0[147] ^ C0[147];
wire p1_147 = S_d1[147] ^ C1[147];
wire g0_147, g1_147, t0_147, t1_147;
MSKand_opini2_d2_pini u_g_147 (
    .ina({S_d1[147], S_d0[147]}), .inb({C1[147], C0[147]}),
    .rnd(r[1060]), .s(s[1060]), .clk(clk), .out({g1_147, g0_147}));
MSKand_opini2_d2_pini u_t_147 (
    .ina({fc1[147], fc0[147]}), .inb({p1_147, p0_147}),
    .rnd(r[1061]), .s(s[1061]), .clk(clk), .out({t1_147, t0_147}));
assign fc0[148] = g0_147 ^ t0_147;
assign fc1[148] = g1_147 ^ t1_147;
assign prod[294]   = p0_147 ^ fc0[147];
assign prod[295] = p1_147 ^ fc1[147];
wire p0_148 = S_d0[148] ^ C0[148];
wire p1_148 = S_d1[148] ^ C1[148];
wire g0_148, g1_148, t0_148, t1_148;
MSKand_opini2_d2_pini u_g_148 (
    .ina({S_d1[148], S_d0[148]}), .inb({C1[148], C0[148]}),
    .rnd(r[1062]), .s(s[1062]), .clk(clk), .out({g1_148, g0_148}));
MSKand_opini2_d2_pini u_t_148 (
    .ina({fc1[148], fc0[148]}), .inb({p1_148, p0_148}),
    .rnd(r[1063]), .s(s[1063]), .clk(clk), .out({t1_148, t0_148}));
assign fc0[149] = g0_148 ^ t0_148;
assign fc1[149] = g1_148 ^ t1_148;
assign prod[296]   = p0_148 ^ fc0[148];
assign prod[297] = p1_148 ^ fc1[148];
wire p0_149 = S_d0[149] ^ C0[149];
wire p1_149 = S_d1[149] ^ C1[149];
wire g0_149, g1_149, t0_149, t1_149;
MSKand_opini2_d2_pini u_g_149 (
    .ina({S_d1[149], S_d0[149]}), .inb({C1[149], C0[149]}),
    .rnd(r[1064]), .s(s[1064]), .clk(clk), .out({g1_149, g0_149}));
MSKand_opini2_d2_pini u_t_149 (
    .ina({fc1[149], fc0[149]}), .inb({p1_149, p0_149}),
    .rnd(r[1065]), .s(s[1065]), .clk(clk), .out({t1_149, t0_149}));
assign fc0[150] = g0_149 ^ t0_149;
assign fc1[150] = g1_149 ^ t1_149;
assign prod[298]   = p0_149 ^ fc0[149];
assign prod[299] = p1_149 ^ fc1[149];
wire p0_150 = S_d0[150] ^ C0[150];
wire p1_150 = S_d1[150] ^ C1[150];
wire g0_150, g1_150, t0_150, t1_150;
MSKand_opini2_d2_pini u_g_150 (
    .ina({S_d1[150], S_d0[150]}), .inb({C1[150], C0[150]}),
    .rnd(r[1066]), .s(s[1066]), .clk(clk), .out({g1_150, g0_150}));
MSKand_opini2_d2_pini u_t_150 (
    .ina({fc1[150], fc0[150]}), .inb({p1_150, p0_150}),
    .rnd(r[1067]), .s(s[1067]), .clk(clk), .out({t1_150, t0_150}));
assign fc0[151] = g0_150 ^ t0_150;
assign fc1[151] = g1_150 ^ t1_150;
assign prod[300]   = p0_150 ^ fc0[150];
assign prod[301] = p1_150 ^ fc1[150];
wire p0_151 = S_d0[151] ^ C0[151];
wire p1_151 = S_d1[151] ^ C1[151];
wire g0_151, g1_151, t0_151, t1_151;
MSKand_opini2_d2_pini u_g_151 (
    .ina({S_d1[151], S_d0[151]}), .inb({C1[151], C0[151]}),
    .rnd(r[1068]), .s(s[1068]), .clk(clk), .out({g1_151, g0_151}));
MSKand_opini2_d2_pini u_t_151 (
    .ina({fc1[151], fc0[151]}), .inb({p1_151, p0_151}),
    .rnd(r[1069]), .s(s[1069]), .clk(clk), .out({t1_151, t0_151}));
assign fc0[152] = g0_151 ^ t0_151;
assign fc1[152] = g1_151 ^ t1_151;
assign prod[302]   = p0_151 ^ fc0[151];
assign prod[303] = p1_151 ^ fc1[151];
wire p0_152 = S_d0[152] ^ C0[152];
wire p1_152 = S_d1[152] ^ C1[152];
wire g0_152, g1_152, t0_152, t1_152;
MSKand_opini2_d2_pini u_g_152 (
    .ina({S_d1[152], S_d0[152]}), .inb({C1[152], C0[152]}),
    .rnd(r[1070]), .s(s[1070]), .clk(clk), .out({g1_152, g0_152}));
MSKand_opini2_d2_pini u_t_152 (
    .ina({fc1[152], fc0[152]}), .inb({p1_152, p0_152}),
    .rnd(r[1071]), .s(s[1071]), .clk(clk), .out({t1_152, t0_152}));
assign fc0[153] = g0_152 ^ t0_152;
assign fc1[153] = g1_152 ^ t1_152;
assign prod[304]   = p0_152 ^ fc0[152];
assign prod[305] = p1_152 ^ fc1[152];
wire p0_153 = S_d0[153] ^ C0[153];
wire p1_153 = S_d1[153] ^ C1[153];
wire g0_153, g1_153, t0_153, t1_153;
MSKand_opini2_d2_pini u_g_153 (
    .ina({S_d1[153], S_d0[153]}), .inb({C1[153], C0[153]}),
    .rnd(r[1072]), .s(s[1072]), .clk(clk), .out({g1_153, g0_153}));
MSKand_opini2_d2_pini u_t_153 (
    .ina({fc1[153], fc0[153]}), .inb({p1_153, p0_153}),
    .rnd(r[1073]), .s(s[1073]), .clk(clk), .out({t1_153, t0_153}));
assign fc0[154] = g0_153 ^ t0_153;
assign fc1[154] = g1_153 ^ t1_153;
assign prod[306]   = p0_153 ^ fc0[153];
assign prod[307] = p1_153 ^ fc1[153];
wire p0_154 = S_d0[154] ^ C0[154];
wire p1_154 = S_d1[154] ^ C1[154];
wire g0_154, g1_154, t0_154, t1_154;
MSKand_opini2_d2_pini u_g_154 (
    .ina({S_d1[154], S_d0[154]}), .inb({C1[154], C0[154]}),
    .rnd(r[1074]), .s(s[1074]), .clk(clk), .out({g1_154, g0_154}));
MSKand_opini2_d2_pini u_t_154 (
    .ina({fc1[154], fc0[154]}), .inb({p1_154, p0_154}),
    .rnd(r[1075]), .s(s[1075]), .clk(clk), .out({t1_154, t0_154}));
assign fc0[155] = g0_154 ^ t0_154;
assign fc1[155] = g1_154 ^ t1_154;
assign prod[308]   = p0_154 ^ fc0[154];
assign prod[309] = p1_154 ^ fc1[154];
wire p0_155 = S_d0[155] ^ C0[155];
wire p1_155 = S_d1[155] ^ C1[155];
wire g0_155, g1_155, t0_155, t1_155;
MSKand_opini2_d2_pini u_g_155 (
    .ina({S_d1[155], S_d0[155]}), .inb({C1[155], C0[155]}),
    .rnd(r[1076]), .s(s[1076]), .clk(clk), .out({g1_155, g0_155}));
MSKand_opini2_d2_pini u_t_155 (
    .ina({fc1[155], fc0[155]}), .inb({p1_155, p0_155}),
    .rnd(r[1077]), .s(s[1077]), .clk(clk), .out({t1_155, t0_155}));
assign fc0[156] = g0_155 ^ t0_155;
assign fc1[156] = g1_155 ^ t1_155;
assign prod[310]   = p0_155 ^ fc0[155];
assign prod[311] = p1_155 ^ fc1[155];
wire p0_156 = S_d0[156] ^ C0[156];
wire p1_156 = S_d1[156] ^ C1[156];
wire g0_156, g1_156, t0_156, t1_156;
MSKand_opini2_d2_pini u_g_156 (
    .ina({S_d1[156], S_d0[156]}), .inb({C1[156], C0[156]}),
    .rnd(r[1078]), .s(s[1078]), .clk(clk), .out({g1_156, g0_156}));
MSKand_opini2_d2_pini u_t_156 (
    .ina({fc1[156], fc0[156]}), .inb({p1_156, p0_156}),
    .rnd(r[1079]), .s(s[1079]), .clk(clk), .out({t1_156, t0_156}));
assign fc0[157] = g0_156 ^ t0_156;
assign fc1[157] = g1_156 ^ t1_156;
assign prod[312]   = p0_156 ^ fc0[156];
assign prod[313] = p1_156 ^ fc1[156];
wire p0_157 = S_d0[157] ^ C0[157];
wire p1_157 = S_d1[157] ^ C1[157];
wire g0_157, g1_157, t0_157, t1_157;
MSKand_opini2_d2_pini u_g_157 (
    .ina({S_d1[157], S_d0[157]}), .inb({C1[157], C0[157]}),
    .rnd(r[1080]), .s(s[1080]), .clk(clk), .out({g1_157, g0_157}));
MSKand_opini2_d2_pini u_t_157 (
    .ina({fc1[157], fc0[157]}), .inb({p1_157, p0_157}),
    .rnd(r[1081]), .s(s[1081]), .clk(clk), .out({t1_157, t0_157}));
assign fc0[158] = g0_157 ^ t0_157;
assign fc1[158] = g1_157 ^ t1_157;
assign prod[314]   = p0_157 ^ fc0[157];
assign prod[315] = p1_157 ^ fc1[157];
wire p0_158 = S_d0[158] ^ C0[158];
wire p1_158 = S_d1[158] ^ C1[158];
wire g0_158, g1_158, t0_158, t1_158;
MSKand_opini2_d2_pini u_g_158 (
    .ina({S_d1[158], S_d0[158]}), .inb({C1[158], C0[158]}),
    .rnd(r[1082]), .s(s[1082]), .clk(clk), .out({g1_158, g0_158}));
MSKand_opini2_d2_pini u_t_158 (
    .ina({fc1[158], fc0[158]}), .inb({p1_158, p0_158}),
    .rnd(r[1083]), .s(s[1083]), .clk(clk), .out({t1_158, t0_158}));
assign fc0[159] = g0_158 ^ t0_158;
assign fc1[159] = g1_158 ^ t1_158;
assign prod[316]   = p0_158 ^ fc0[158];
assign prod[317] = p1_158 ^ fc1[158];
wire p0_159 = S_d0[159] ^ C0[159];
wire p1_159 = S_d1[159] ^ C1[159];
wire g0_159, g1_159, t0_159, t1_159;
MSKand_opini2_d2_pini u_g_159 (
    .ina({S_d1[159], S_d0[159]}), .inb({C1[159], C0[159]}),
    .rnd(r[1084]), .s(s[1084]), .clk(clk), .out({g1_159, g0_159}));
MSKand_opini2_d2_pini u_t_159 (
    .ina({fc1[159], fc0[159]}), .inb({p1_159, p0_159}),
    .rnd(r[1085]), .s(s[1085]), .clk(clk), .out({t1_159, t0_159}));
assign fc0[160] = g0_159 ^ t0_159;
assign fc1[160] = g1_159 ^ t1_159;
assign prod[318]   = p0_159 ^ fc0[159];
assign prod[319] = p1_159 ^ fc1[159];
wire p0_160 = S_d0[160] ^ C0[160];
wire p1_160 = S_d1[160] ^ C1[160];
wire g0_160, g1_160, t0_160, t1_160;
MSKand_opini2_d2_pini u_g_160 (
    .ina({S_d1[160], S_d0[160]}), .inb({C1[160], C0[160]}),
    .rnd(r[1086]), .s(s[1086]), .clk(clk), .out({g1_160, g0_160}));
MSKand_opini2_d2_pini u_t_160 (
    .ina({fc1[160], fc0[160]}), .inb({p1_160, p0_160}),
    .rnd(r[1087]), .s(s[1087]), .clk(clk), .out({t1_160, t0_160}));
assign fc0[161] = g0_160 ^ t0_160;
assign fc1[161] = g1_160 ^ t1_160;
assign prod[320]   = p0_160 ^ fc0[160];
assign prod[321] = p1_160 ^ fc1[160];
wire p0_161 = S_d0[161] ^ C0[161];
wire p1_161 = S_d1[161] ^ C1[161];
wire g0_161, g1_161, t0_161, t1_161;
MSKand_opini2_d2_pini u_g_161 (
    .ina({S_d1[161], S_d0[161]}), .inb({C1[161], C0[161]}),
    .rnd(r[1088]), .s(s[1088]), .clk(clk), .out({g1_161, g0_161}));
MSKand_opini2_d2_pini u_t_161 (
    .ina({fc1[161], fc0[161]}), .inb({p1_161, p0_161}),
    .rnd(r[1089]), .s(s[1089]), .clk(clk), .out({t1_161, t0_161}));
assign fc0[162] = g0_161 ^ t0_161;
assign fc1[162] = g1_161 ^ t1_161;
assign prod[322]   = p0_161 ^ fc0[161];
assign prod[323] = p1_161 ^ fc1[161];
wire p0_162 = S_d0[162] ^ C0[162];
wire p1_162 = S_d1[162] ^ C1[162];
wire g0_162, g1_162, t0_162, t1_162;
MSKand_opini2_d2_pini u_g_162 (
    .ina({S_d1[162], S_d0[162]}), .inb({C1[162], C0[162]}),
    .rnd(r[1090]), .s(s[1090]), .clk(clk), .out({g1_162, g0_162}));
MSKand_opini2_d2_pini u_t_162 (
    .ina({fc1[162], fc0[162]}), .inb({p1_162, p0_162}),
    .rnd(r[1091]), .s(s[1091]), .clk(clk), .out({t1_162, t0_162}));
assign fc0[163] = g0_162 ^ t0_162;
assign fc1[163] = g1_162 ^ t1_162;
assign prod[324]   = p0_162 ^ fc0[162];
assign prod[325] = p1_162 ^ fc1[162];
wire p0_163 = S_d0[163] ^ C0[163];
wire p1_163 = S_d1[163] ^ C1[163];
wire g0_163, g1_163, t0_163, t1_163;
MSKand_opini2_d2_pini u_g_163 (
    .ina({S_d1[163], S_d0[163]}), .inb({C1[163], C0[163]}),
    .rnd(r[1092]), .s(s[1092]), .clk(clk), .out({g1_163, g0_163}));
MSKand_opini2_d2_pini u_t_163 (
    .ina({fc1[163], fc0[163]}), .inb({p1_163, p0_163}),
    .rnd(r[1093]), .s(s[1093]), .clk(clk), .out({t1_163, t0_163}));
assign fc0[164] = g0_163 ^ t0_163;
assign fc1[164] = g1_163 ^ t1_163;
assign prod[326]   = p0_163 ^ fc0[163];
assign prod[327] = p1_163 ^ fc1[163];
wire p0_164 = S_d0[164] ^ C0[164];
wire p1_164 = S_d1[164] ^ C1[164];
wire g0_164, g1_164, t0_164, t1_164;
MSKand_opini2_d2_pini u_g_164 (
    .ina({S_d1[164], S_d0[164]}), .inb({C1[164], C0[164]}),
    .rnd(r[1094]), .s(s[1094]), .clk(clk), .out({g1_164, g0_164}));
MSKand_opini2_d2_pini u_t_164 (
    .ina({fc1[164], fc0[164]}), .inb({p1_164, p0_164}),
    .rnd(r[1095]), .s(s[1095]), .clk(clk), .out({t1_164, t0_164}));
assign fc0[165] = g0_164 ^ t0_164;
assign fc1[165] = g1_164 ^ t1_164;
assign prod[328]   = p0_164 ^ fc0[164];
assign prod[329] = p1_164 ^ fc1[164];
wire p0_165 = S_d0[165] ^ C0[165];
wire p1_165 = S_d1[165] ^ C1[165];
wire g0_165, g1_165, t0_165, t1_165;
MSKand_opini2_d2_pini u_g_165 (
    .ina({S_d1[165], S_d0[165]}), .inb({C1[165], C0[165]}),
    .rnd(r[1096]), .s(s[1096]), .clk(clk), .out({g1_165, g0_165}));
MSKand_opini2_d2_pini u_t_165 (
    .ina({fc1[165], fc0[165]}), .inb({p1_165, p0_165}),
    .rnd(r[1097]), .s(s[1097]), .clk(clk), .out({t1_165, t0_165}));
assign fc0[166] = g0_165 ^ t0_165;
assign fc1[166] = g1_165 ^ t1_165;
assign prod[330]   = p0_165 ^ fc0[165];
assign prod[331] = p1_165 ^ fc1[165];
wire p0_166 = S_d0[166] ^ C0[166];
wire p1_166 = S_d1[166] ^ C1[166];
wire g0_166, g1_166, t0_166, t1_166;
MSKand_opini2_d2_pini u_g_166 (
    .ina({S_d1[166], S_d0[166]}), .inb({C1[166], C0[166]}),
    .rnd(r[1098]), .s(s[1098]), .clk(clk), .out({g1_166, g0_166}));
MSKand_opini2_d2_pini u_t_166 (
    .ina({fc1[166], fc0[166]}), .inb({p1_166, p0_166}),
    .rnd(r[1099]), .s(s[1099]), .clk(clk), .out({t1_166, t0_166}));
assign fc0[167] = g0_166 ^ t0_166;
assign fc1[167] = g1_166 ^ t1_166;
assign prod[332]   = p0_166 ^ fc0[166];
assign prod[333] = p1_166 ^ fc1[166];
wire p0_167 = S_d0[167] ^ C0[167];
wire p1_167 = S_d1[167] ^ C1[167];
wire g0_167, g1_167, t0_167, t1_167;
MSKand_opini2_d2_pini u_g_167 (
    .ina({S_d1[167], S_d0[167]}), .inb({C1[167], C0[167]}),
    .rnd(r[1100]), .s(s[1100]), .clk(clk), .out({g1_167, g0_167}));
MSKand_opini2_d2_pini u_t_167 (
    .ina({fc1[167], fc0[167]}), .inb({p1_167, p0_167}),
    .rnd(r[1101]), .s(s[1101]), .clk(clk), .out({t1_167, t0_167}));
assign fc0[168] = g0_167 ^ t0_167;
assign fc1[168] = g1_167 ^ t1_167;
assign prod[334]   = p0_167 ^ fc0[167];
assign prod[335] = p1_167 ^ fc1[167];
wire p0_168 = S_d0[168] ^ C0[168];
wire p1_168 = S_d1[168] ^ C1[168];
wire g0_168, g1_168, t0_168, t1_168;
MSKand_opini2_d2_pini u_g_168 (
    .ina({S_d1[168], S_d0[168]}), .inb({C1[168], C0[168]}),
    .rnd(r[1102]), .s(s[1102]), .clk(clk), .out({g1_168, g0_168}));
MSKand_opini2_d2_pini u_t_168 (
    .ina({fc1[168], fc0[168]}), .inb({p1_168, p0_168}),
    .rnd(r[1103]), .s(s[1103]), .clk(clk), .out({t1_168, t0_168}));
assign fc0[169] = g0_168 ^ t0_168;
assign fc1[169] = g1_168 ^ t1_168;
assign prod[336]   = p0_168 ^ fc0[168];
assign prod[337] = p1_168 ^ fc1[168];
wire p0_169 = S_d0[169] ^ C0[169];
wire p1_169 = S_d1[169] ^ C1[169];
wire g0_169, g1_169, t0_169, t1_169;
MSKand_opini2_d2_pini u_g_169 (
    .ina({S_d1[169], S_d0[169]}), .inb({C1[169], C0[169]}),
    .rnd(r[1104]), .s(s[1104]), .clk(clk), .out({g1_169, g0_169}));
MSKand_opini2_d2_pini u_t_169 (
    .ina({fc1[169], fc0[169]}), .inb({p1_169, p0_169}),
    .rnd(r[1105]), .s(s[1105]), .clk(clk), .out({t1_169, t0_169}));
assign fc0[170] = g0_169 ^ t0_169;
assign fc1[170] = g1_169 ^ t1_169;
assign prod[338]   = p0_169 ^ fc0[169];
assign prod[339] = p1_169 ^ fc1[169];
wire p0_170 = S_d0[170] ^ C0[170];
wire p1_170 = S_d1[170] ^ C1[170];
wire g0_170, g1_170, t0_170, t1_170;
MSKand_opini2_d2_pini u_g_170 (
    .ina({S_d1[170], S_d0[170]}), .inb({C1[170], C0[170]}),
    .rnd(r[1106]), .s(s[1106]), .clk(clk), .out({g1_170, g0_170}));
MSKand_opini2_d2_pini u_t_170 (
    .ina({fc1[170], fc0[170]}), .inb({p1_170, p0_170}),
    .rnd(r[1107]), .s(s[1107]), .clk(clk), .out({t1_170, t0_170}));
assign fc0[171] = g0_170 ^ t0_170;
assign fc1[171] = g1_170 ^ t1_170;
assign prod[340]   = p0_170 ^ fc0[170];
assign prod[341] = p1_170 ^ fc1[170];
wire p0_171 = S_d0[171] ^ C0[171];
wire p1_171 = S_d1[171] ^ C1[171];
wire g0_171, g1_171, t0_171, t1_171;
MSKand_opini2_d2_pini u_g_171 (
    .ina({S_d1[171], S_d0[171]}), .inb({C1[171], C0[171]}),
    .rnd(r[1108]), .s(s[1108]), .clk(clk), .out({g1_171, g0_171}));
MSKand_opini2_d2_pini u_t_171 (
    .ina({fc1[171], fc0[171]}), .inb({p1_171, p0_171}),
    .rnd(r[1109]), .s(s[1109]), .clk(clk), .out({t1_171, t0_171}));
assign fc0[172] = g0_171 ^ t0_171;
assign fc1[172] = g1_171 ^ t1_171;
assign prod[342]   = p0_171 ^ fc0[171];
assign prod[343] = p1_171 ^ fc1[171];
wire p0_172 = S_d0[172] ^ C0[172];
wire p1_172 = S_d1[172] ^ C1[172];
wire g0_172, g1_172, t0_172, t1_172;
MSKand_opini2_d2_pini u_g_172 (
    .ina({S_d1[172], S_d0[172]}), .inb({C1[172], C0[172]}),
    .rnd(r[1110]), .s(s[1110]), .clk(clk), .out({g1_172, g0_172}));
MSKand_opini2_d2_pini u_t_172 (
    .ina({fc1[172], fc0[172]}), .inb({p1_172, p0_172}),
    .rnd(r[1111]), .s(s[1111]), .clk(clk), .out({t1_172, t0_172}));
assign fc0[173] = g0_172 ^ t0_172;
assign fc1[173] = g1_172 ^ t1_172;
assign prod[344]   = p0_172 ^ fc0[172];
assign prod[345] = p1_172 ^ fc1[172];
wire p0_173 = S_d0[173] ^ C0[173];
wire p1_173 = S_d1[173] ^ C1[173];
wire g0_173, g1_173, t0_173, t1_173;
MSKand_opini2_d2_pini u_g_173 (
    .ina({S_d1[173], S_d0[173]}), .inb({C1[173], C0[173]}),
    .rnd(r[1112]), .s(s[1112]), .clk(clk), .out({g1_173, g0_173}));
MSKand_opini2_d2_pini u_t_173 (
    .ina({fc1[173], fc0[173]}), .inb({p1_173, p0_173}),
    .rnd(r[1113]), .s(s[1113]), .clk(clk), .out({t1_173, t0_173}));
assign fc0[174] = g0_173 ^ t0_173;
assign fc1[174] = g1_173 ^ t1_173;
assign prod[346]   = p0_173 ^ fc0[173];
assign prod[347] = p1_173 ^ fc1[173];
wire p0_174 = S_d0[174] ^ C0[174];
wire p1_174 = S_d1[174] ^ C1[174];
wire g0_174, g1_174, t0_174, t1_174;
MSKand_opini2_d2_pini u_g_174 (
    .ina({S_d1[174], S_d0[174]}), .inb({C1[174], C0[174]}),
    .rnd(r[1114]), .s(s[1114]), .clk(clk), .out({g1_174, g0_174}));
MSKand_opini2_d2_pini u_t_174 (
    .ina({fc1[174], fc0[174]}), .inb({p1_174, p0_174}),
    .rnd(r[1115]), .s(s[1115]), .clk(clk), .out({t1_174, t0_174}));
assign fc0[175] = g0_174 ^ t0_174;
assign fc1[175] = g1_174 ^ t1_174;
assign prod[348]   = p0_174 ^ fc0[174];
assign prod[349] = p1_174 ^ fc1[174];
wire p0_175 = S_d0[175] ^ C0[175];
wire p1_175 = S_d1[175] ^ C1[175];
wire g0_175, g1_175, t0_175, t1_175;
MSKand_opini2_d2_pini u_g_175 (
    .ina({S_d1[175], S_d0[175]}), .inb({C1[175], C0[175]}),
    .rnd(r[1116]), .s(s[1116]), .clk(clk), .out({g1_175, g0_175}));
MSKand_opini2_d2_pini u_t_175 (
    .ina({fc1[175], fc0[175]}), .inb({p1_175, p0_175}),
    .rnd(r[1117]), .s(s[1117]), .clk(clk), .out({t1_175, t0_175}));
assign fc0[176] = g0_175 ^ t0_175;
assign fc1[176] = g1_175 ^ t1_175;
assign prod[350]   = p0_175 ^ fc0[175];
assign prod[351] = p1_175 ^ fc1[175];
wire p0_176 = S_d0[176] ^ C0[176];
wire p1_176 = S_d1[176] ^ C1[176];
wire g0_176, g1_176, t0_176, t1_176;
MSKand_opini2_d2_pini u_g_176 (
    .ina({S_d1[176], S_d0[176]}), .inb({C1[176], C0[176]}),
    .rnd(r[1118]), .s(s[1118]), .clk(clk), .out({g1_176, g0_176}));
MSKand_opini2_d2_pini u_t_176 (
    .ina({fc1[176], fc0[176]}), .inb({p1_176, p0_176}),
    .rnd(r[1119]), .s(s[1119]), .clk(clk), .out({t1_176, t0_176}));
assign fc0[177] = g0_176 ^ t0_176;
assign fc1[177] = g1_176 ^ t1_176;
assign prod[352]   = p0_176 ^ fc0[176];
assign prod[353] = p1_176 ^ fc1[176];
wire p0_177 = S_d0[177] ^ C0[177];
wire p1_177 = S_d1[177] ^ C1[177];
wire g0_177, g1_177, t0_177, t1_177;
MSKand_opini2_d2_pini u_g_177 (
    .ina({S_d1[177], S_d0[177]}), .inb({C1[177], C0[177]}),
    .rnd(r[1120]), .s(s[1120]), .clk(clk), .out({g1_177, g0_177}));
MSKand_opini2_d2_pini u_t_177 (
    .ina({fc1[177], fc0[177]}), .inb({p1_177, p0_177}),
    .rnd(r[1121]), .s(s[1121]), .clk(clk), .out({t1_177, t0_177}));
assign fc0[178] = g0_177 ^ t0_177;
assign fc1[178] = g1_177 ^ t1_177;
assign prod[354]   = p0_177 ^ fc0[177];
assign prod[355] = p1_177 ^ fc1[177];
wire p0_178 = S_d0[178] ^ C0[178];
wire p1_178 = S_d1[178] ^ C1[178];
wire g0_178, g1_178, t0_178, t1_178;
MSKand_opini2_d2_pini u_g_178 (
    .ina({S_d1[178], S_d0[178]}), .inb({C1[178], C0[178]}),
    .rnd(r[1122]), .s(s[1122]), .clk(clk), .out({g1_178, g0_178}));
MSKand_opini2_d2_pini u_t_178 (
    .ina({fc1[178], fc0[178]}), .inb({p1_178, p0_178}),
    .rnd(r[1123]), .s(s[1123]), .clk(clk), .out({t1_178, t0_178}));
assign fc0[179] = g0_178 ^ t0_178;
assign fc1[179] = g1_178 ^ t1_178;
assign prod[356]   = p0_178 ^ fc0[178];
assign prod[357] = p1_178 ^ fc1[178];
wire p0_179 = S_d0[179] ^ C0[179];
wire p1_179 = S_d1[179] ^ C1[179];
wire g0_179, g1_179, t0_179, t1_179;
MSKand_opini2_d2_pini u_g_179 (
    .ina({S_d1[179], S_d0[179]}), .inb({C1[179], C0[179]}),
    .rnd(r[1124]), .s(s[1124]), .clk(clk), .out({g1_179, g0_179}));
MSKand_opini2_d2_pini u_t_179 (
    .ina({fc1[179], fc0[179]}), .inb({p1_179, p0_179}),
    .rnd(r[1125]), .s(s[1125]), .clk(clk), .out({t1_179, t0_179}));
assign fc0[180] = g0_179 ^ t0_179;
assign fc1[180] = g1_179 ^ t1_179;
assign prod[358]   = p0_179 ^ fc0[179];
assign prod[359] = p1_179 ^ fc1[179];
wire p0_180 = S_d0[180] ^ C0[180];
wire p1_180 = S_d1[180] ^ C1[180];
wire g0_180, g1_180, t0_180, t1_180;
MSKand_opini2_d2_pini u_g_180 (
    .ina({S_d1[180], S_d0[180]}), .inb({C1[180], C0[180]}),
    .rnd(r[1126]), .s(s[1126]), .clk(clk), .out({g1_180, g0_180}));
MSKand_opini2_d2_pini u_t_180 (
    .ina({fc1[180], fc0[180]}), .inb({p1_180, p0_180}),
    .rnd(r[1127]), .s(s[1127]), .clk(clk), .out({t1_180, t0_180}));
assign fc0[181] = g0_180 ^ t0_180;
assign fc1[181] = g1_180 ^ t1_180;
assign prod[360]   = p0_180 ^ fc0[180];
assign prod[361] = p1_180 ^ fc1[180];
wire p0_181 = S_d0[181] ^ C0[181];
wire p1_181 = S_d1[181] ^ C1[181];
wire g0_181, g1_181, t0_181, t1_181;
MSKand_opini2_d2_pini u_g_181 (
    .ina({S_d1[181], S_d0[181]}), .inb({C1[181], C0[181]}),
    .rnd(r[1128]), .s(s[1128]), .clk(clk), .out({g1_181, g0_181}));
MSKand_opini2_d2_pini u_t_181 (
    .ina({fc1[181], fc0[181]}), .inb({p1_181, p0_181}),
    .rnd(r[1129]), .s(s[1129]), .clk(clk), .out({t1_181, t0_181}));
assign fc0[182] = g0_181 ^ t0_181;
assign fc1[182] = g1_181 ^ t1_181;
assign prod[362]   = p0_181 ^ fc0[181];
assign prod[363] = p1_181 ^ fc1[181];
wire p0_182 = S_d0[182] ^ C0[182];
wire p1_182 = S_d1[182] ^ C1[182];
wire g0_182, g1_182, t0_182, t1_182;
MSKand_opini2_d2_pini u_g_182 (
    .ina({S_d1[182], S_d0[182]}), .inb({C1[182], C0[182]}),
    .rnd(r[1130]), .s(s[1130]), .clk(clk), .out({g1_182, g0_182}));
MSKand_opini2_d2_pini u_t_182 (
    .ina({fc1[182], fc0[182]}), .inb({p1_182, p0_182}),
    .rnd(r[1131]), .s(s[1131]), .clk(clk), .out({t1_182, t0_182}));
assign fc0[183] = g0_182 ^ t0_182;
assign fc1[183] = g1_182 ^ t1_182;
assign prod[364]   = p0_182 ^ fc0[182];
assign prod[365] = p1_182 ^ fc1[182];
wire p0_183 = S_d0[183] ^ C0[183];
wire p1_183 = S_d1[183] ^ C1[183];
wire g0_183, g1_183, t0_183, t1_183;
MSKand_opini2_d2_pini u_g_183 (
    .ina({S_d1[183], S_d0[183]}), .inb({C1[183], C0[183]}),
    .rnd(r[1132]), .s(s[1132]), .clk(clk), .out({g1_183, g0_183}));
MSKand_opini2_d2_pini u_t_183 (
    .ina({fc1[183], fc0[183]}), .inb({p1_183, p0_183}),
    .rnd(r[1133]), .s(s[1133]), .clk(clk), .out({t1_183, t0_183}));
assign fc0[184] = g0_183 ^ t0_183;
assign fc1[184] = g1_183 ^ t1_183;
assign prod[366]   = p0_183 ^ fc0[183];
assign prod[367] = p1_183 ^ fc1[183];
wire p0_184 = S_d0[184] ^ C0[184];
wire p1_184 = S_d1[184] ^ C1[184];
wire g0_184, g1_184, t0_184, t1_184;
MSKand_opini2_d2_pini u_g_184 (
    .ina({S_d1[184], S_d0[184]}), .inb({C1[184], C0[184]}),
    .rnd(r[1134]), .s(s[1134]), .clk(clk), .out({g1_184, g0_184}));
MSKand_opini2_d2_pini u_t_184 (
    .ina({fc1[184], fc0[184]}), .inb({p1_184, p0_184}),
    .rnd(r[1135]), .s(s[1135]), .clk(clk), .out({t1_184, t0_184}));
assign fc0[185] = g0_184 ^ t0_184;
assign fc1[185] = g1_184 ^ t1_184;
assign prod[368]   = p0_184 ^ fc0[184];
assign prod[369] = p1_184 ^ fc1[184];
wire p0_185 = S_d0[185] ^ C0[185];
wire p1_185 = S_d1[185] ^ C1[185];
wire g0_185, g1_185, t0_185, t1_185;
MSKand_opini2_d2_pini u_g_185 (
    .ina({S_d1[185], S_d0[185]}), .inb({C1[185], C0[185]}),
    .rnd(r[1136]), .s(s[1136]), .clk(clk), .out({g1_185, g0_185}));
MSKand_opini2_d2_pini u_t_185 (
    .ina({fc1[185], fc0[185]}), .inb({p1_185, p0_185}),
    .rnd(r[1137]), .s(s[1137]), .clk(clk), .out({t1_185, t0_185}));
assign fc0[186] = g0_185 ^ t0_185;
assign fc1[186] = g1_185 ^ t1_185;
assign prod[370]   = p0_185 ^ fc0[185];
assign prod[371] = p1_185 ^ fc1[185];
wire p0_186 = S_d0[186] ^ C0[186];
wire p1_186 = S_d1[186] ^ C1[186];
wire g0_186, g1_186, t0_186, t1_186;
MSKand_opini2_d2_pini u_g_186 (
    .ina({S_d1[186], S_d0[186]}), .inb({C1[186], C0[186]}),
    .rnd(r[1138]), .s(s[1138]), .clk(clk), .out({g1_186, g0_186}));
MSKand_opini2_d2_pini u_t_186 (
    .ina({fc1[186], fc0[186]}), .inb({p1_186, p0_186}),
    .rnd(r[1139]), .s(s[1139]), .clk(clk), .out({t1_186, t0_186}));
assign fc0[187] = g0_186 ^ t0_186;
assign fc1[187] = g1_186 ^ t1_186;
assign prod[372]   = p0_186 ^ fc0[186];
assign prod[373] = p1_186 ^ fc1[186];
wire p0_187 = S_d0[187] ^ C0[187];
wire p1_187 = S_d1[187] ^ C1[187];
wire g0_187, g1_187, t0_187, t1_187;
MSKand_opini2_d2_pini u_g_187 (
    .ina({S_d1[187], S_d0[187]}), .inb({C1[187], C0[187]}),
    .rnd(r[1140]), .s(s[1140]), .clk(clk), .out({g1_187, g0_187}));
MSKand_opini2_d2_pini u_t_187 (
    .ina({fc1[187], fc0[187]}), .inb({p1_187, p0_187}),
    .rnd(r[1141]), .s(s[1141]), .clk(clk), .out({t1_187, t0_187}));
assign fc0[188] = g0_187 ^ t0_187;
assign fc1[188] = g1_187 ^ t1_187;
assign prod[374]   = p0_187 ^ fc0[187];
assign prod[375] = p1_187 ^ fc1[187];
wire p0_188 = S_d0[188] ^ C0[188];
wire p1_188 = S_d1[188] ^ C1[188];
wire g0_188, g1_188, t0_188, t1_188;
MSKand_opini2_d2_pini u_g_188 (
    .ina({S_d1[188], S_d0[188]}), .inb({C1[188], C0[188]}),
    .rnd(r[1142]), .s(s[1142]), .clk(clk), .out({g1_188, g0_188}));
MSKand_opini2_d2_pini u_t_188 (
    .ina({fc1[188], fc0[188]}), .inb({p1_188, p0_188}),
    .rnd(r[1143]), .s(s[1143]), .clk(clk), .out({t1_188, t0_188}));
assign fc0[189] = g0_188 ^ t0_188;
assign fc1[189] = g1_188 ^ t1_188;
assign prod[376]   = p0_188 ^ fc0[188];
assign prod[377] = p1_188 ^ fc1[188];
wire p0_189 = S_d0[189] ^ C0[189];
wire p1_189 = S_d1[189] ^ C1[189];
wire g0_189, g1_189, t0_189, t1_189;
MSKand_opini2_d2_pini u_g_189 (
    .ina({S_d1[189], S_d0[189]}), .inb({C1[189], C0[189]}),
    .rnd(r[1144]), .s(s[1144]), .clk(clk), .out({g1_189, g0_189}));
MSKand_opini2_d2_pini u_t_189 (
    .ina({fc1[189], fc0[189]}), .inb({p1_189, p0_189}),
    .rnd(r[1145]), .s(s[1145]), .clk(clk), .out({t1_189, t0_189}));
assign fc0[190] = g0_189 ^ t0_189;
assign fc1[190] = g1_189 ^ t1_189;
assign prod[378]   = p0_189 ^ fc0[189];
assign prod[379] = p1_189 ^ fc1[189];
wire p0_190 = S_d0[190] ^ C0[190];
wire p1_190 = S_d1[190] ^ C1[190];
wire g0_190, g1_190, t0_190, t1_190;
MSKand_opini2_d2_pini u_g_190 (
    .ina({S_d1[190], S_d0[190]}), .inb({C1[190], C0[190]}),
    .rnd(r[1146]), .s(s[1146]), .clk(clk), .out({g1_190, g0_190}));
MSKand_opini2_d2_pini u_t_190 (
    .ina({fc1[190], fc0[190]}), .inb({p1_190, p0_190}),
    .rnd(r[1147]), .s(s[1147]), .clk(clk), .out({t1_190, t0_190}));
assign fc0[191] = g0_190 ^ t0_190;
assign fc1[191] = g1_190 ^ t1_190;
assign prod[380]   = p0_190 ^ fc0[190];
assign prod[381] = p1_190 ^ fc1[190];
wire p0_191 = S_d0[191] ^ C0[191];
wire p1_191 = S_d1[191] ^ C1[191];
wire g0_191, g1_191, t0_191, t1_191;
MSKand_opini2_d2_pini u_g_191 (
    .ina({S_d1[191], S_d0[191]}), .inb({C1[191], C0[191]}),
    .rnd(r[1148]), .s(s[1148]), .clk(clk), .out({g1_191, g0_191}));
MSKand_opini2_d2_pini u_t_191 (
    .ina({fc1[191], fc0[191]}), .inb({p1_191, p0_191}),
    .rnd(r[1149]), .s(s[1149]), .clk(clk), .out({t1_191, t0_191}));
assign fc0[192] = g0_191 ^ t0_191;
assign fc1[192] = g1_191 ^ t1_191;
assign prod[382]   = p0_191 ^ fc0[191];
assign prod[383] = p1_191 ^ fc1[191];
wire p0_192 = S_d0[192] ^ C0[192];
wire p1_192 = S_d1[192] ^ C1[192];
wire g0_192, g1_192, t0_192, t1_192;
MSKand_opini2_d2_pini u_g_192 (
    .ina({S_d1[192], S_d0[192]}), .inb({C1[192], C0[192]}),
    .rnd(r[1150]), .s(s[1150]), .clk(clk), .out({g1_192, g0_192}));
MSKand_opini2_d2_pini u_t_192 (
    .ina({fc1[192], fc0[192]}), .inb({p1_192, p0_192}),
    .rnd(r[1151]), .s(s[1151]), .clk(clk), .out({t1_192, t0_192}));
assign fc0[193] = g0_192 ^ t0_192;
assign fc1[193] = g1_192 ^ t1_192;
assign prod[384]   = p0_192 ^ fc0[192];
assign prod[385] = p1_192 ^ fc1[192];
wire p0_193 = S_d0[193] ^ C0[193];
wire p1_193 = S_d1[193] ^ C1[193];
wire g0_193, g1_193, t0_193, t1_193;
MSKand_opini2_d2_pini u_g_193 (
    .ina({S_d1[193], S_d0[193]}), .inb({C1[193], C0[193]}),
    .rnd(r[1152]), .s(s[1152]), .clk(clk), .out({g1_193, g0_193}));
MSKand_opini2_d2_pini u_t_193 (
    .ina({fc1[193], fc0[193]}), .inb({p1_193, p0_193}),
    .rnd(r[1153]), .s(s[1153]), .clk(clk), .out({t1_193, t0_193}));
assign fc0[194] = g0_193 ^ t0_193;
assign fc1[194] = g1_193 ^ t1_193;
assign prod[386]   = p0_193 ^ fc0[193];
assign prod[387] = p1_193 ^ fc1[193];
wire p0_194 = S_d0[194] ^ C0[194];
wire p1_194 = S_d1[194] ^ C1[194];
wire g0_194, g1_194, t0_194, t1_194;
MSKand_opini2_d2_pini u_g_194 (
    .ina({S_d1[194], S_d0[194]}), .inb({C1[194], C0[194]}),
    .rnd(r[1154]), .s(s[1154]), .clk(clk), .out({g1_194, g0_194}));
MSKand_opini2_d2_pini u_t_194 (
    .ina({fc1[194], fc0[194]}), .inb({p1_194, p0_194}),
    .rnd(r[1155]), .s(s[1155]), .clk(clk), .out({t1_194, t0_194}));
assign fc0[195] = g0_194 ^ t0_194;
assign fc1[195] = g1_194 ^ t1_194;
assign prod[388]   = p0_194 ^ fc0[194];
assign prod[389] = p1_194 ^ fc1[194];
wire p0_195 = S_d0[195] ^ C0[195];
wire p1_195 = S_d1[195] ^ C1[195];
wire g0_195, g1_195, t0_195, t1_195;
MSKand_opini2_d2_pini u_g_195 (
    .ina({S_d1[195], S_d0[195]}), .inb({C1[195], C0[195]}),
    .rnd(r[1156]), .s(s[1156]), .clk(clk), .out({g1_195, g0_195}));
MSKand_opini2_d2_pini u_t_195 (
    .ina({fc1[195], fc0[195]}), .inb({p1_195, p0_195}),
    .rnd(r[1157]), .s(s[1157]), .clk(clk), .out({t1_195, t0_195}));
assign fc0[196] = g0_195 ^ t0_195;
assign fc1[196] = g1_195 ^ t1_195;
assign prod[390]   = p0_195 ^ fc0[195];
assign prod[391] = p1_195 ^ fc1[195];
wire p0_196 = S_d0[196] ^ C0[196];
wire p1_196 = S_d1[196] ^ C1[196];
wire g0_196, g1_196, t0_196, t1_196;
MSKand_opini2_d2_pini u_g_196 (
    .ina({S_d1[196], S_d0[196]}), .inb({C1[196], C0[196]}),
    .rnd(r[1158]), .s(s[1158]), .clk(clk), .out({g1_196, g0_196}));
MSKand_opini2_d2_pini u_t_196 (
    .ina({fc1[196], fc0[196]}), .inb({p1_196, p0_196}),
    .rnd(r[1159]), .s(s[1159]), .clk(clk), .out({t1_196, t0_196}));
assign fc0[197] = g0_196 ^ t0_196;
assign fc1[197] = g1_196 ^ t1_196;
assign prod[392]   = p0_196 ^ fc0[196];
assign prod[393] = p1_196 ^ fc1[196];
wire p0_197 = S_d0[197] ^ C0[197];
wire p1_197 = S_d1[197] ^ C1[197];
wire g0_197, g1_197, t0_197, t1_197;
MSKand_opini2_d2_pini u_g_197 (
    .ina({S_d1[197], S_d0[197]}), .inb({C1[197], C0[197]}),
    .rnd(r[1160]), .s(s[1160]), .clk(clk), .out({g1_197, g0_197}));
MSKand_opini2_d2_pini u_t_197 (
    .ina({fc1[197], fc0[197]}), .inb({p1_197, p0_197}),
    .rnd(r[1161]), .s(s[1161]), .clk(clk), .out({t1_197, t0_197}));
assign fc0[198] = g0_197 ^ t0_197;
assign fc1[198] = g1_197 ^ t1_197;
assign prod[394]   = p0_197 ^ fc0[197];
assign prod[395] = p1_197 ^ fc1[197];
wire p0_198 = S_d0[198] ^ C0[198];
wire p1_198 = S_d1[198] ^ C1[198];
wire g0_198, g1_198, t0_198, t1_198;
MSKand_opini2_d2_pini u_g_198 (
    .ina({S_d1[198], S_d0[198]}), .inb({C1[198], C0[198]}),
    .rnd(r[1162]), .s(s[1162]), .clk(clk), .out({g1_198, g0_198}));
MSKand_opini2_d2_pini u_t_198 (
    .ina({fc1[198], fc0[198]}), .inb({p1_198, p0_198}),
    .rnd(r[1163]), .s(s[1163]), .clk(clk), .out({t1_198, t0_198}));
assign fc0[199] = g0_198 ^ t0_198;
assign fc1[199] = g1_198 ^ t1_198;
assign prod[396]   = p0_198 ^ fc0[198];
assign prod[397] = p1_198 ^ fc1[198];
wire p0_199 = S_d0[199] ^ C0[199];
wire p1_199 = S_d1[199] ^ C1[199];
wire g0_199, g1_199, t0_199, t1_199;
MSKand_opini2_d2_pini u_g_199 (
    .ina({S_d1[199], S_d0[199]}), .inb({C1[199], C0[199]}),
    .rnd(r[1164]), .s(s[1164]), .clk(clk), .out({g1_199, g0_199}));
MSKand_opini2_d2_pini u_t_199 (
    .ina({fc1[199], fc0[199]}), .inb({p1_199, p0_199}),
    .rnd(r[1165]), .s(s[1165]), .clk(clk), .out({t1_199, t0_199}));
assign fc0[200] = g0_199 ^ t0_199;
assign fc1[200] = g1_199 ^ t1_199;
assign prod[398]   = p0_199 ^ fc0[199];
assign prod[399] = p1_199 ^ fc1[199];
wire p0_200 = S_d0[200] ^ C0[200];
wire p1_200 = S_d1[200] ^ C1[200];
wire g0_200, g1_200, t0_200, t1_200;
MSKand_opini2_d2_pini u_g_200 (
    .ina({S_d1[200], S_d0[200]}), .inb({C1[200], C0[200]}),
    .rnd(r[1166]), .s(s[1166]), .clk(clk), .out({g1_200, g0_200}));
MSKand_opini2_d2_pini u_t_200 (
    .ina({fc1[200], fc0[200]}), .inb({p1_200, p0_200}),
    .rnd(r[1167]), .s(s[1167]), .clk(clk), .out({t1_200, t0_200}));
assign fc0[201] = g0_200 ^ t0_200;
assign fc1[201] = g1_200 ^ t1_200;
assign prod[400]   = p0_200 ^ fc0[200];
assign prod[401] = p1_200 ^ fc1[200];
wire p0_201 = S_d0[201] ^ C0[201];
wire p1_201 = S_d1[201] ^ C1[201];
wire g0_201, g1_201, t0_201, t1_201;
MSKand_opini2_d2_pini u_g_201 (
    .ina({S_d1[201], S_d0[201]}), .inb({C1[201], C0[201]}),
    .rnd(r[1168]), .s(s[1168]), .clk(clk), .out({g1_201, g0_201}));
MSKand_opini2_d2_pini u_t_201 (
    .ina({fc1[201], fc0[201]}), .inb({p1_201, p0_201}),
    .rnd(r[1169]), .s(s[1169]), .clk(clk), .out({t1_201, t0_201}));
assign fc0[202] = g0_201 ^ t0_201;
assign fc1[202] = g1_201 ^ t1_201;
assign prod[402]   = p0_201 ^ fc0[201];
assign prod[403] = p1_201 ^ fc1[201];
wire p0_202 = S_d0[202] ^ C0[202];
wire p1_202 = S_d1[202] ^ C1[202];
wire g0_202, g1_202, t0_202, t1_202;
MSKand_opini2_d2_pini u_g_202 (
    .ina({S_d1[202], S_d0[202]}), .inb({C1[202], C0[202]}),
    .rnd(r[1170]), .s(s[1170]), .clk(clk), .out({g1_202, g0_202}));
MSKand_opini2_d2_pini u_t_202 (
    .ina({fc1[202], fc0[202]}), .inb({p1_202, p0_202}),
    .rnd(r[1171]), .s(s[1171]), .clk(clk), .out({t1_202, t0_202}));
assign fc0[203] = g0_202 ^ t0_202;
assign fc1[203] = g1_202 ^ t1_202;
assign prod[404]   = p0_202 ^ fc0[202];
assign prod[405] = p1_202 ^ fc1[202];
wire p0_203 = S_d0[203] ^ C0[203];
wire p1_203 = S_d1[203] ^ C1[203];
wire g0_203, g1_203, t0_203, t1_203;
MSKand_opini2_d2_pini u_g_203 (
    .ina({S_d1[203], S_d0[203]}), .inb({C1[203], C0[203]}),
    .rnd(r[1172]), .s(s[1172]), .clk(clk), .out({g1_203, g0_203}));
MSKand_opini2_d2_pini u_t_203 (
    .ina({fc1[203], fc0[203]}), .inb({p1_203, p0_203}),
    .rnd(r[1173]), .s(s[1173]), .clk(clk), .out({t1_203, t0_203}));
assign fc0[204] = g0_203 ^ t0_203;
assign fc1[204] = g1_203 ^ t1_203;
assign prod[406]   = p0_203 ^ fc0[203];
assign prod[407] = p1_203 ^ fc1[203];
wire p0_204 = S_d0[204] ^ C0[204];
wire p1_204 = S_d1[204] ^ C1[204];
wire g0_204, g1_204, t0_204, t1_204;
MSKand_opini2_d2_pini u_g_204 (
    .ina({S_d1[204], S_d0[204]}), .inb({C1[204], C0[204]}),
    .rnd(r[1174]), .s(s[1174]), .clk(clk), .out({g1_204, g0_204}));
MSKand_opini2_d2_pini u_t_204 (
    .ina({fc1[204], fc0[204]}), .inb({p1_204, p0_204}),
    .rnd(r[1175]), .s(s[1175]), .clk(clk), .out({t1_204, t0_204}));
assign fc0[205] = g0_204 ^ t0_204;
assign fc1[205] = g1_204 ^ t1_204;
assign prod[408]   = p0_204 ^ fc0[204];
assign prod[409] = p1_204 ^ fc1[204];
wire p0_205 = S_d0[205] ^ C0[205];
wire p1_205 = S_d1[205] ^ C1[205];
wire g0_205, g1_205, t0_205, t1_205;
MSKand_opini2_d2_pini u_g_205 (
    .ina({S_d1[205], S_d0[205]}), .inb({C1[205], C0[205]}),
    .rnd(r[1176]), .s(s[1176]), .clk(clk), .out({g1_205, g0_205}));
MSKand_opini2_d2_pini u_t_205 (
    .ina({fc1[205], fc0[205]}), .inb({p1_205, p0_205}),
    .rnd(r[1177]), .s(s[1177]), .clk(clk), .out({t1_205, t0_205}));
assign fc0[206] = g0_205 ^ t0_205;
assign fc1[206] = g1_205 ^ t1_205;
assign prod[410]   = p0_205 ^ fc0[205];
assign prod[411] = p1_205 ^ fc1[205];
wire p0_206 = S_d0[206] ^ C0[206];
wire p1_206 = S_d1[206] ^ C1[206];
wire g0_206, g1_206, t0_206, t1_206;
MSKand_opini2_d2_pini u_g_206 (
    .ina({S_d1[206], S_d0[206]}), .inb({C1[206], C0[206]}),
    .rnd(r[1178]), .s(s[1178]), .clk(clk), .out({g1_206, g0_206}));
MSKand_opini2_d2_pini u_t_206 (
    .ina({fc1[206], fc0[206]}), .inb({p1_206, p0_206}),
    .rnd(r[1179]), .s(s[1179]), .clk(clk), .out({t1_206, t0_206}));
assign fc0[207] = g0_206 ^ t0_206;
assign fc1[207] = g1_206 ^ t1_206;
assign prod[412]   = p0_206 ^ fc0[206];
assign prod[413] = p1_206 ^ fc1[206];
wire p0_207 = S_d0[207] ^ C0[207];
wire p1_207 = S_d1[207] ^ C1[207];
wire g0_207, g1_207, t0_207, t1_207;
MSKand_opini2_d2_pini u_g_207 (
    .ina({S_d1[207], S_d0[207]}), .inb({C1[207], C0[207]}),
    .rnd(r[1180]), .s(s[1180]), .clk(clk), .out({g1_207, g0_207}));
MSKand_opini2_d2_pini u_t_207 (
    .ina({fc1[207], fc0[207]}), .inb({p1_207, p0_207}),
    .rnd(r[1181]), .s(s[1181]), .clk(clk), .out({t1_207, t0_207}));
assign fc0[208] = g0_207 ^ t0_207;
assign fc1[208] = g1_207 ^ t1_207;
assign prod[414]   = p0_207 ^ fc0[207];
assign prod[415] = p1_207 ^ fc1[207];
wire p0_208 = S_d0[208] ^ C0[208];
wire p1_208 = S_d1[208] ^ C1[208];
wire g0_208, g1_208, t0_208, t1_208;
MSKand_opini2_d2_pini u_g_208 (
    .ina({S_d1[208], S_d0[208]}), .inb({C1[208], C0[208]}),
    .rnd(r[1182]), .s(s[1182]), .clk(clk), .out({g1_208, g0_208}));
MSKand_opini2_d2_pini u_t_208 (
    .ina({fc1[208], fc0[208]}), .inb({p1_208, p0_208}),
    .rnd(r[1183]), .s(s[1183]), .clk(clk), .out({t1_208, t0_208}));
assign fc0[209] = g0_208 ^ t0_208;
assign fc1[209] = g1_208 ^ t1_208;
assign prod[416]   = p0_208 ^ fc0[208];
assign prod[417] = p1_208 ^ fc1[208];
wire p0_209 = S_d0[209] ^ C0[209];
wire p1_209 = S_d1[209] ^ C1[209];
wire g0_209, g1_209, t0_209, t1_209;
MSKand_opini2_d2_pini u_g_209 (
    .ina({S_d1[209], S_d0[209]}), .inb({C1[209], C0[209]}),
    .rnd(r[1184]), .s(s[1184]), .clk(clk), .out({g1_209, g0_209}));
MSKand_opini2_d2_pini u_t_209 (
    .ina({fc1[209], fc0[209]}), .inb({p1_209, p0_209}),
    .rnd(r[1185]), .s(s[1185]), .clk(clk), .out({t1_209, t0_209}));
assign fc0[210] = g0_209 ^ t0_209;
assign fc1[210] = g1_209 ^ t1_209;
assign prod[418]   = p0_209 ^ fc0[209];
assign prod[419] = p1_209 ^ fc1[209];
wire p0_210 = S_d0[210] ^ C0[210];
wire p1_210 = S_d1[210] ^ C1[210];
wire g0_210, g1_210, t0_210, t1_210;
MSKand_opini2_d2_pini u_g_210 (
    .ina({S_d1[210], S_d0[210]}), .inb({C1[210], C0[210]}),
    .rnd(r[1186]), .s(s[1186]), .clk(clk), .out({g1_210, g0_210}));
MSKand_opini2_d2_pini u_t_210 (
    .ina({fc1[210], fc0[210]}), .inb({p1_210, p0_210}),
    .rnd(r[1187]), .s(s[1187]), .clk(clk), .out({t1_210, t0_210}));
assign fc0[211] = g0_210 ^ t0_210;
assign fc1[211] = g1_210 ^ t1_210;
assign prod[420]   = p0_210 ^ fc0[210];
assign prod[421] = p1_210 ^ fc1[210];
wire p0_211 = S_d0[211] ^ C0[211];
wire p1_211 = S_d1[211] ^ C1[211];
wire g0_211, g1_211, t0_211, t1_211;
MSKand_opini2_d2_pini u_g_211 (
    .ina({S_d1[211], S_d0[211]}), .inb({C1[211], C0[211]}),
    .rnd(r[1188]), .s(s[1188]), .clk(clk), .out({g1_211, g0_211}));
MSKand_opini2_d2_pini u_t_211 (
    .ina({fc1[211], fc0[211]}), .inb({p1_211, p0_211}),
    .rnd(r[1189]), .s(s[1189]), .clk(clk), .out({t1_211, t0_211}));
assign fc0[212] = g0_211 ^ t0_211;
assign fc1[212] = g1_211 ^ t1_211;
assign prod[422]   = p0_211 ^ fc0[211];
assign prod[423] = p1_211 ^ fc1[211];
wire p0_212 = S_d0[212] ^ C0[212];
wire p1_212 = S_d1[212] ^ C1[212];
wire g0_212, g1_212, t0_212, t1_212;
MSKand_opini2_d2_pini u_g_212 (
    .ina({S_d1[212], S_d0[212]}), .inb({C1[212], C0[212]}),
    .rnd(r[1190]), .s(s[1190]), .clk(clk), .out({g1_212, g0_212}));
MSKand_opini2_d2_pini u_t_212 (
    .ina({fc1[212], fc0[212]}), .inb({p1_212, p0_212}),
    .rnd(r[1191]), .s(s[1191]), .clk(clk), .out({t1_212, t0_212}));
assign fc0[213] = g0_212 ^ t0_212;
assign fc1[213] = g1_212 ^ t1_212;
assign prod[424]   = p0_212 ^ fc0[212];
assign prod[425] = p1_212 ^ fc1[212];
wire p0_213 = S_d0[213] ^ C0[213];
wire p1_213 = S_d1[213] ^ C1[213];
wire g0_213, g1_213, t0_213, t1_213;
MSKand_opini2_d2_pini u_g_213 (
    .ina({S_d1[213], S_d0[213]}), .inb({C1[213], C0[213]}),
    .rnd(r[1192]), .s(s[1192]), .clk(clk), .out({g1_213, g0_213}));
MSKand_opini2_d2_pini u_t_213 (
    .ina({fc1[213], fc0[213]}), .inb({p1_213, p0_213}),
    .rnd(r[1193]), .s(s[1193]), .clk(clk), .out({t1_213, t0_213}));
assign fc0[214] = g0_213 ^ t0_213;
assign fc1[214] = g1_213 ^ t1_213;
assign prod[426]   = p0_213 ^ fc0[213];
assign prod[427] = p1_213 ^ fc1[213];
wire p0_214 = S_d0[214] ^ C0[214];
wire p1_214 = S_d1[214] ^ C1[214];
wire g0_214, g1_214, t0_214, t1_214;
MSKand_opini2_d2_pini u_g_214 (
    .ina({S_d1[214], S_d0[214]}), .inb({C1[214], C0[214]}),
    .rnd(r[1194]), .s(s[1194]), .clk(clk), .out({g1_214, g0_214}));
MSKand_opini2_d2_pini u_t_214 (
    .ina({fc1[214], fc0[214]}), .inb({p1_214, p0_214}),
    .rnd(r[1195]), .s(s[1195]), .clk(clk), .out({t1_214, t0_214}));
assign fc0[215] = g0_214 ^ t0_214;
assign fc1[215] = g1_214 ^ t1_214;
assign prod[428]   = p0_214 ^ fc0[214];
assign prod[429] = p1_214 ^ fc1[214];
wire p0_215 = S_d0[215] ^ C0[215];
wire p1_215 = S_d1[215] ^ C1[215];
wire g0_215, g1_215, t0_215, t1_215;
MSKand_opini2_d2_pini u_g_215 (
    .ina({S_d1[215], S_d0[215]}), .inb({C1[215], C0[215]}),
    .rnd(r[1196]), .s(s[1196]), .clk(clk), .out({g1_215, g0_215}));
MSKand_opini2_d2_pini u_t_215 (
    .ina({fc1[215], fc0[215]}), .inb({p1_215, p0_215}),
    .rnd(r[1197]), .s(s[1197]), .clk(clk), .out({t1_215, t0_215}));
assign fc0[216] = g0_215 ^ t0_215;
assign fc1[216] = g1_215 ^ t1_215;
assign prod[430]   = p0_215 ^ fc0[215];
assign prod[431] = p1_215 ^ fc1[215];
wire p0_216 = S_d0[216] ^ C0[216];
wire p1_216 = S_d1[216] ^ C1[216];
wire g0_216, g1_216, t0_216, t1_216;
MSKand_opini2_d2_pini u_g_216 (
    .ina({S_d1[216], S_d0[216]}), .inb({C1[216], C0[216]}),
    .rnd(r[1198]), .s(s[1198]), .clk(clk), .out({g1_216, g0_216}));
MSKand_opini2_d2_pini u_t_216 (
    .ina({fc1[216], fc0[216]}), .inb({p1_216, p0_216}),
    .rnd(r[1199]), .s(s[1199]), .clk(clk), .out({t1_216, t0_216}));
assign fc0[217] = g0_216 ^ t0_216;
assign fc1[217] = g1_216 ^ t1_216;
assign prod[432]   = p0_216 ^ fc0[216];
assign prod[433] = p1_216 ^ fc1[216];
wire p0_217 = S_d0[217] ^ C0[217];
wire p1_217 = S_d1[217] ^ C1[217];
wire g0_217, g1_217, t0_217, t1_217;
MSKand_opini2_d2_pini u_g_217 (
    .ina({S_d1[217], S_d0[217]}), .inb({C1[217], C0[217]}),
    .rnd(r[1200]), .s(s[1200]), .clk(clk), .out({g1_217, g0_217}));
MSKand_opini2_d2_pini u_t_217 (
    .ina({fc1[217], fc0[217]}), .inb({p1_217, p0_217}),
    .rnd(r[1201]), .s(s[1201]), .clk(clk), .out({t1_217, t0_217}));
assign fc0[218] = g0_217 ^ t0_217;
assign fc1[218] = g1_217 ^ t1_217;
assign prod[434]   = p0_217 ^ fc0[217];
assign prod[435] = p1_217 ^ fc1[217];
wire p0_218 = S_d0[218] ^ C0[218];
wire p1_218 = S_d1[218] ^ C1[218];
wire g0_218, g1_218, t0_218, t1_218;
MSKand_opini2_d2_pini u_g_218 (
    .ina({S_d1[218], S_d0[218]}), .inb({C1[218], C0[218]}),
    .rnd(r[1202]), .s(s[1202]), .clk(clk), .out({g1_218, g0_218}));
MSKand_opini2_d2_pini u_t_218 (
    .ina({fc1[218], fc0[218]}), .inb({p1_218, p0_218}),
    .rnd(r[1203]), .s(s[1203]), .clk(clk), .out({t1_218, t0_218}));
assign fc0[219] = g0_218 ^ t0_218;
assign fc1[219] = g1_218 ^ t1_218;
assign prod[436]   = p0_218 ^ fc0[218];
assign prod[437] = p1_218 ^ fc1[218];
wire p0_219 = S_d0[219] ^ C0[219];
wire p1_219 = S_d1[219] ^ C1[219];
wire g0_219, g1_219, t0_219, t1_219;
MSKand_opini2_d2_pini u_g_219 (
    .ina({S_d1[219], S_d0[219]}), .inb({C1[219], C0[219]}),
    .rnd(r[1204]), .s(s[1204]), .clk(clk), .out({g1_219, g0_219}));
MSKand_opini2_d2_pini u_t_219 (
    .ina({fc1[219], fc0[219]}), .inb({p1_219, p0_219}),
    .rnd(r[1205]), .s(s[1205]), .clk(clk), .out({t1_219, t0_219}));
assign fc0[220] = g0_219 ^ t0_219;
assign fc1[220] = g1_219 ^ t1_219;
assign prod[438]   = p0_219 ^ fc0[219];
assign prod[439] = p1_219 ^ fc1[219];
wire p0_220 = S_d0[220] ^ C0[220];
wire p1_220 = S_d1[220] ^ C1[220];
wire g0_220, g1_220, t0_220, t1_220;
MSKand_opini2_d2_pini u_g_220 (
    .ina({S_d1[220], S_d0[220]}), .inb({C1[220], C0[220]}),
    .rnd(r[1206]), .s(s[1206]), .clk(clk), .out({g1_220, g0_220}));
MSKand_opini2_d2_pini u_t_220 (
    .ina({fc1[220], fc0[220]}), .inb({p1_220, p0_220}),
    .rnd(r[1207]), .s(s[1207]), .clk(clk), .out({t1_220, t0_220}));
assign fc0[221] = g0_220 ^ t0_220;
assign fc1[221] = g1_220 ^ t1_220;
assign prod[440]   = p0_220 ^ fc0[220];
assign prod[441] = p1_220 ^ fc1[220];
wire p0_221 = S_d0[221] ^ C0[221];
wire p1_221 = S_d1[221] ^ C1[221];
wire g0_221, g1_221, t0_221, t1_221;
MSKand_opini2_d2_pini u_g_221 (
    .ina({S_d1[221], S_d0[221]}), .inb({C1[221], C0[221]}),
    .rnd(r[1208]), .s(s[1208]), .clk(clk), .out({g1_221, g0_221}));
MSKand_opini2_d2_pini u_t_221 (
    .ina({fc1[221], fc0[221]}), .inb({p1_221, p0_221}),
    .rnd(r[1209]), .s(s[1209]), .clk(clk), .out({t1_221, t0_221}));
assign fc0[222] = g0_221 ^ t0_221;
assign fc1[222] = g1_221 ^ t1_221;
assign prod[442]   = p0_221 ^ fc0[221];
assign prod[443] = p1_221 ^ fc1[221];
wire p0_222 = S_d0[222] ^ C0[222];
wire p1_222 = S_d1[222] ^ C1[222];
wire g0_222, g1_222, t0_222, t1_222;
MSKand_opini2_d2_pini u_g_222 (
    .ina({S_d1[222], S_d0[222]}), .inb({C1[222], C0[222]}),
    .rnd(r[1210]), .s(s[1210]), .clk(clk), .out({g1_222, g0_222}));
MSKand_opini2_d2_pini u_t_222 (
    .ina({fc1[222], fc0[222]}), .inb({p1_222, p0_222}),
    .rnd(r[1211]), .s(s[1211]), .clk(clk), .out({t1_222, t0_222}));
assign fc0[223] = g0_222 ^ t0_222;
assign fc1[223] = g1_222 ^ t1_222;
assign prod[444]   = p0_222 ^ fc0[222];
assign prod[445] = p1_222 ^ fc1[222];
wire p0_223 = S_d0[223] ^ C0[223];
wire p1_223 = S_d1[223] ^ C1[223];
wire g0_223, g1_223, t0_223, t1_223;
MSKand_opini2_d2_pini u_g_223 (
    .ina({S_d1[223], S_d0[223]}), .inb({C1[223], C0[223]}),
    .rnd(r[1212]), .s(s[1212]), .clk(clk), .out({g1_223, g0_223}));
MSKand_opini2_d2_pini u_t_223 (
    .ina({fc1[223], fc0[223]}), .inb({p1_223, p0_223}),
    .rnd(r[1213]), .s(s[1213]), .clk(clk), .out({t1_223, t0_223}));
assign fc0[224] = g0_223 ^ t0_223;
assign fc1[224] = g1_223 ^ t1_223;
assign prod[446]   = p0_223 ^ fc0[223];
assign prod[447] = p1_223 ^ fc1[223];
wire p0_224 = S_d0[224] ^ C0[224];
wire p1_224 = S_d1[224] ^ C1[224];
wire g0_224, g1_224, t0_224, t1_224;
MSKand_opini2_d2_pini u_g_224 (
    .ina({S_d1[224], S_d0[224]}), .inb({C1[224], C0[224]}),
    .rnd(r[1214]), .s(s[1214]), .clk(clk), .out({g1_224, g0_224}));
MSKand_opini2_d2_pini u_t_224 (
    .ina({fc1[224], fc0[224]}), .inb({p1_224, p0_224}),
    .rnd(r[1215]), .s(s[1215]), .clk(clk), .out({t1_224, t0_224}));
assign fc0[225] = g0_224 ^ t0_224;
assign fc1[225] = g1_224 ^ t1_224;
assign prod[448]   = p0_224 ^ fc0[224];
assign prod[449] = p1_224 ^ fc1[224];
wire p0_225 = S_d0[225] ^ C0[225];
wire p1_225 = S_d1[225] ^ C1[225];
wire g0_225, g1_225, t0_225, t1_225;
MSKand_opini2_d2_pini u_g_225 (
    .ina({S_d1[225], S_d0[225]}), .inb({C1[225], C0[225]}),
    .rnd(r[1216]), .s(s[1216]), .clk(clk), .out({g1_225, g0_225}));
MSKand_opini2_d2_pini u_t_225 (
    .ina({fc1[225], fc0[225]}), .inb({p1_225, p0_225}),
    .rnd(r[1217]), .s(s[1217]), .clk(clk), .out({t1_225, t0_225}));
assign fc0[226] = g0_225 ^ t0_225;
assign fc1[226] = g1_225 ^ t1_225;
assign prod[450]   = p0_225 ^ fc0[225];
assign prod[451] = p1_225 ^ fc1[225];
wire p0_226 = S_d0[226] ^ C0[226];
wire p1_226 = S_d1[226] ^ C1[226];
wire g0_226, g1_226, t0_226, t1_226;
MSKand_opini2_d2_pini u_g_226 (
    .ina({S_d1[226], S_d0[226]}), .inb({C1[226], C0[226]}),
    .rnd(r[1218]), .s(s[1218]), .clk(clk), .out({g1_226, g0_226}));
MSKand_opini2_d2_pini u_t_226 (
    .ina({fc1[226], fc0[226]}), .inb({p1_226, p0_226}),
    .rnd(r[1219]), .s(s[1219]), .clk(clk), .out({t1_226, t0_226}));
assign fc0[227] = g0_226 ^ t0_226;
assign fc1[227] = g1_226 ^ t1_226;
assign prod[452]   = p0_226 ^ fc0[226];
assign prod[453] = p1_226 ^ fc1[226];
wire p0_227 = S_d0[227] ^ C0[227];
wire p1_227 = S_d1[227] ^ C1[227];
wire g0_227, g1_227, t0_227, t1_227;
MSKand_opini2_d2_pini u_g_227 (
    .ina({S_d1[227], S_d0[227]}), .inb({C1[227], C0[227]}),
    .rnd(r[1220]), .s(s[1220]), .clk(clk), .out({g1_227, g0_227}));
MSKand_opini2_d2_pini u_t_227 (
    .ina({fc1[227], fc0[227]}), .inb({p1_227, p0_227}),
    .rnd(r[1221]), .s(s[1221]), .clk(clk), .out({t1_227, t0_227}));
assign fc0[228] = g0_227 ^ t0_227;
assign fc1[228] = g1_227 ^ t1_227;
assign prod[454]   = p0_227 ^ fc0[227];
assign prod[455] = p1_227 ^ fc1[227];
wire p0_228 = S_d0[228] ^ C0[228];
wire p1_228 = S_d1[228] ^ C1[228];
wire g0_228, g1_228, t0_228, t1_228;
MSKand_opini2_d2_pini u_g_228 (
    .ina({S_d1[228], S_d0[228]}), .inb({C1[228], C0[228]}),
    .rnd(r[1222]), .s(s[1222]), .clk(clk), .out({g1_228, g0_228}));
MSKand_opini2_d2_pini u_t_228 (
    .ina({fc1[228], fc0[228]}), .inb({p1_228, p0_228}),
    .rnd(r[1223]), .s(s[1223]), .clk(clk), .out({t1_228, t0_228}));
assign fc0[229] = g0_228 ^ t0_228;
assign fc1[229] = g1_228 ^ t1_228;
assign prod[456]   = p0_228 ^ fc0[228];
assign prod[457] = p1_228 ^ fc1[228];
wire p0_229 = S_d0[229] ^ C0[229];
wire p1_229 = S_d1[229] ^ C1[229];
wire g0_229, g1_229, t0_229, t1_229;
MSKand_opini2_d2_pini u_g_229 (
    .ina({S_d1[229], S_d0[229]}), .inb({C1[229], C0[229]}),
    .rnd(r[1224]), .s(s[1224]), .clk(clk), .out({g1_229, g0_229}));
MSKand_opini2_d2_pini u_t_229 (
    .ina({fc1[229], fc0[229]}), .inb({p1_229, p0_229}),
    .rnd(r[1225]), .s(s[1225]), .clk(clk), .out({t1_229, t0_229}));
assign fc0[230] = g0_229 ^ t0_229;
assign fc1[230] = g1_229 ^ t1_229;
assign prod[458]   = p0_229 ^ fc0[229];
assign prod[459] = p1_229 ^ fc1[229];
wire p0_230 = S_d0[230] ^ C0[230];
wire p1_230 = S_d1[230] ^ C1[230];
wire g0_230, g1_230, t0_230, t1_230;
MSKand_opini2_d2_pini u_g_230 (
    .ina({S_d1[230], S_d0[230]}), .inb({C1[230], C0[230]}),
    .rnd(r[1226]), .s(s[1226]), .clk(clk), .out({g1_230, g0_230}));
MSKand_opini2_d2_pini u_t_230 (
    .ina({fc1[230], fc0[230]}), .inb({p1_230, p0_230}),
    .rnd(r[1227]), .s(s[1227]), .clk(clk), .out({t1_230, t0_230}));
assign fc0[231] = g0_230 ^ t0_230;
assign fc1[231] = g1_230 ^ t1_230;
assign prod[460]   = p0_230 ^ fc0[230];
assign prod[461] = p1_230 ^ fc1[230];
wire p0_231 = S_d0[231] ^ C0[231];
wire p1_231 = S_d1[231] ^ C1[231];
wire g0_231, g1_231, t0_231, t1_231;
MSKand_opini2_d2_pini u_g_231 (
    .ina({S_d1[231], S_d0[231]}), .inb({C1[231], C0[231]}),
    .rnd(r[1228]), .s(s[1228]), .clk(clk), .out({g1_231, g0_231}));
MSKand_opini2_d2_pini u_t_231 (
    .ina({fc1[231], fc0[231]}), .inb({p1_231, p0_231}),
    .rnd(r[1229]), .s(s[1229]), .clk(clk), .out({t1_231, t0_231}));
assign fc0[232] = g0_231 ^ t0_231;
assign fc1[232] = g1_231 ^ t1_231;
assign prod[462]   = p0_231 ^ fc0[231];
assign prod[463] = p1_231 ^ fc1[231];
wire p0_232 = S_d0[232] ^ C0[232];
wire p1_232 = S_d1[232] ^ C1[232];
wire g0_232, g1_232, t0_232, t1_232;
MSKand_opini2_d2_pini u_g_232 (
    .ina({S_d1[232], S_d0[232]}), .inb({C1[232], C0[232]}),
    .rnd(r[1230]), .s(s[1230]), .clk(clk), .out({g1_232, g0_232}));
MSKand_opini2_d2_pini u_t_232 (
    .ina({fc1[232], fc0[232]}), .inb({p1_232, p0_232}),
    .rnd(r[1231]), .s(s[1231]), .clk(clk), .out({t1_232, t0_232}));
assign fc0[233] = g0_232 ^ t0_232;
assign fc1[233] = g1_232 ^ t1_232;
assign prod[464]   = p0_232 ^ fc0[232];
assign prod[465] = p1_232 ^ fc1[232];
wire p0_233 = S_d0[233] ^ C0[233];
wire p1_233 = S_d1[233] ^ C1[233];
wire g0_233, g1_233, t0_233, t1_233;
MSKand_opini2_d2_pini u_g_233 (
    .ina({S_d1[233], S_d0[233]}), .inb({C1[233], C0[233]}),
    .rnd(r[1232]), .s(s[1232]), .clk(clk), .out({g1_233, g0_233}));
MSKand_opini2_d2_pini u_t_233 (
    .ina({fc1[233], fc0[233]}), .inb({p1_233, p0_233}),
    .rnd(r[1233]), .s(s[1233]), .clk(clk), .out({t1_233, t0_233}));
assign fc0[234] = g0_233 ^ t0_233;
assign fc1[234] = g1_233 ^ t1_233;
assign prod[466]   = p0_233 ^ fc0[233];
assign prod[467] = p1_233 ^ fc1[233];
wire p0_234 = S_d0[234] ^ C0[234];
wire p1_234 = S_d1[234] ^ C1[234];
wire g0_234, g1_234, t0_234, t1_234;
MSKand_opini2_d2_pini u_g_234 (
    .ina({S_d1[234], S_d0[234]}), .inb({C1[234], C0[234]}),
    .rnd(r[1234]), .s(s[1234]), .clk(clk), .out({g1_234, g0_234}));
MSKand_opini2_d2_pini u_t_234 (
    .ina({fc1[234], fc0[234]}), .inb({p1_234, p0_234}),
    .rnd(r[1235]), .s(s[1235]), .clk(clk), .out({t1_234, t0_234}));
assign fc0[235] = g0_234 ^ t0_234;
assign fc1[235] = g1_234 ^ t1_234;
assign prod[468]   = p0_234 ^ fc0[234];
assign prod[469] = p1_234 ^ fc1[234];
wire p0_235 = S_d0[235] ^ C0[235];
wire p1_235 = S_d1[235] ^ C1[235];
wire g0_235, g1_235, t0_235, t1_235;
MSKand_opini2_d2_pini u_g_235 (
    .ina({S_d1[235], S_d0[235]}), .inb({C1[235], C0[235]}),
    .rnd(r[1236]), .s(s[1236]), .clk(clk), .out({g1_235, g0_235}));
MSKand_opini2_d2_pini u_t_235 (
    .ina({fc1[235], fc0[235]}), .inb({p1_235, p0_235}),
    .rnd(r[1237]), .s(s[1237]), .clk(clk), .out({t1_235, t0_235}));
assign fc0[236] = g0_235 ^ t0_235;
assign fc1[236] = g1_235 ^ t1_235;
assign prod[470]   = p0_235 ^ fc0[235];
assign prod[471] = p1_235 ^ fc1[235];
wire p0_236 = S_d0[236] ^ C0[236];
wire p1_236 = S_d1[236] ^ C1[236];
wire g0_236, g1_236, t0_236, t1_236;
MSKand_opini2_d2_pini u_g_236 (
    .ina({S_d1[236], S_d0[236]}), .inb({C1[236], C0[236]}),
    .rnd(r[1238]), .s(s[1238]), .clk(clk), .out({g1_236, g0_236}));
MSKand_opini2_d2_pini u_t_236 (
    .ina({fc1[236], fc0[236]}), .inb({p1_236, p0_236}),
    .rnd(r[1239]), .s(s[1239]), .clk(clk), .out({t1_236, t0_236}));
assign fc0[237] = g0_236 ^ t0_236;
assign fc1[237] = g1_236 ^ t1_236;
assign prod[472]   = p0_236 ^ fc0[236];
assign prod[473] = p1_236 ^ fc1[236];
wire p0_237 = S_d0[237] ^ C0[237];
wire p1_237 = S_d1[237] ^ C1[237];
wire g0_237, g1_237, t0_237, t1_237;
MSKand_opini2_d2_pini u_g_237 (
    .ina({S_d1[237], S_d0[237]}), .inb({C1[237], C0[237]}),
    .rnd(r[1240]), .s(s[1240]), .clk(clk), .out({g1_237, g0_237}));
MSKand_opini2_d2_pini u_t_237 (
    .ina({fc1[237], fc0[237]}), .inb({p1_237, p0_237}),
    .rnd(r[1241]), .s(s[1241]), .clk(clk), .out({t1_237, t0_237}));
assign fc0[238] = g0_237 ^ t0_237;
assign fc1[238] = g1_237 ^ t1_237;
assign prod[474]   = p0_237 ^ fc0[237];
assign prod[475] = p1_237 ^ fc1[237];
wire p0_238 = S_d0[238] ^ C0[238];
wire p1_238 = S_d1[238] ^ C1[238];
wire g0_238, g1_238, t0_238, t1_238;
MSKand_opini2_d2_pini u_g_238 (
    .ina({S_d1[238], S_d0[238]}), .inb({C1[238], C0[238]}),
    .rnd(r[1242]), .s(s[1242]), .clk(clk), .out({g1_238, g0_238}));
MSKand_opini2_d2_pini u_t_238 (
    .ina({fc1[238], fc0[238]}), .inb({p1_238, p0_238}),
    .rnd(r[1243]), .s(s[1243]), .clk(clk), .out({t1_238, t0_238}));
assign fc0[239] = g0_238 ^ t0_238;
assign fc1[239] = g1_238 ^ t1_238;
assign prod[476]   = p0_238 ^ fc0[238];
assign prod[477] = p1_238 ^ fc1[238];
wire p0_239 = S_d0[239] ^ C0[239];
wire p1_239 = S_d1[239] ^ C1[239];
wire g0_239, g1_239, t0_239, t1_239;
MSKand_opini2_d2_pini u_g_239 (
    .ina({S_d1[239], S_d0[239]}), .inb({C1[239], C0[239]}),
    .rnd(r[1244]), .s(s[1244]), .clk(clk), .out({g1_239, g0_239}));
MSKand_opini2_d2_pini u_t_239 (
    .ina({fc1[239], fc0[239]}), .inb({p1_239, p0_239}),
    .rnd(r[1245]), .s(s[1245]), .clk(clk), .out({t1_239, t0_239}));
assign fc0[240] = g0_239 ^ t0_239;
assign fc1[240] = g1_239 ^ t1_239;
assign prod[478]   = p0_239 ^ fc0[239];
assign prod[479] = p1_239 ^ fc1[239];
wire p0_240 = S_d0[240] ^ C0[240];
wire p1_240 = S_d1[240] ^ C1[240];
wire g0_240, g1_240, t0_240, t1_240;
MSKand_opini2_d2_pini u_g_240 (
    .ina({S_d1[240], S_d0[240]}), .inb({C1[240], C0[240]}),
    .rnd(r[1246]), .s(s[1246]), .clk(clk), .out({g1_240, g0_240}));
MSKand_opini2_d2_pini u_t_240 (
    .ina({fc1[240], fc0[240]}), .inb({p1_240, p0_240}),
    .rnd(r[1247]), .s(s[1247]), .clk(clk), .out({t1_240, t0_240}));
assign fc0[241] = g0_240 ^ t0_240;
assign fc1[241] = g1_240 ^ t1_240;
assign prod[480]   = p0_240 ^ fc0[240];
assign prod[481] = p1_240 ^ fc1[240];
wire p0_241 = S_d0[241] ^ C0[241];
wire p1_241 = S_d1[241] ^ C1[241];
wire g0_241, g1_241, t0_241, t1_241;
MSKand_opini2_d2_pini u_g_241 (
    .ina({S_d1[241], S_d0[241]}), .inb({C1[241], C0[241]}),
    .rnd(r[1248]), .s(s[1248]), .clk(clk), .out({g1_241, g0_241}));
MSKand_opini2_d2_pini u_t_241 (
    .ina({fc1[241], fc0[241]}), .inb({p1_241, p0_241}),
    .rnd(r[1249]), .s(s[1249]), .clk(clk), .out({t1_241, t0_241}));
assign fc0[242] = g0_241 ^ t0_241;
assign fc1[242] = g1_241 ^ t1_241;
assign prod[482]   = p0_241 ^ fc0[241];
assign prod[483] = p1_241 ^ fc1[241];
wire p0_242 = S_d0[242] ^ C0[242];
wire p1_242 = S_d1[242] ^ C1[242];
wire g0_242, g1_242, t0_242, t1_242;
MSKand_opini2_d2_pini u_g_242 (
    .ina({S_d1[242], S_d0[242]}), .inb({C1[242], C0[242]}),
    .rnd(r[1250]), .s(s[1250]), .clk(clk), .out({g1_242, g0_242}));
MSKand_opini2_d2_pini u_t_242 (
    .ina({fc1[242], fc0[242]}), .inb({p1_242, p0_242}),
    .rnd(r[1251]), .s(s[1251]), .clk(clk), .out({t1_242, t0_242}));
assign fc0[243] = g0_242 ^ t0_242;
assign fc1[243] = g1_242 ^ t1_242;
assign prod[484]   = p0_242 ^ fc0[242];
assign prod[485] = p1_242 ^ fc1[242];
wire p0_243 = S_d0[243] ^ C0[243];
wire p1_243 = S_d1[243] ^ C1[243];
wire g0_243, g1_243, t0_243, t1_243;
MSKand_opini2_d2_pini u_g_243 (
    .ina({S_d1[243], S_d0[243]}), .inb({C1[243], C0[243]}),
    .rnd(r[1252]), .s(s[1252]), .clk(clk), .out({g1_243, g0_243}));
MSKand_opini2_d2_pini u_t_243 (
    .ina({fc1[243], fc0[243]}), .inb({p1_243, p0_243}),
    .rnd(r[1253]), .s(s[1253]), .clk(clk), .out({t1_243, t0_243}));
assign fc0[244] = g0_243 ^ t0_243;
assign fc1[244] = g1_243 ^ t1_243;
assign prod[486]   = p0_243 ^ fc0[243];
assign prod[487] = p1_243 ^ fc1[243];
wire p0_244 = S_d0[244] ^ C0[244];
wire p1_244 = S_d1[244] ^ C1[244];
wire g0_244, g1_244, t0_244, t1_244;
MSKand_opini2_d2_pini u_g_244 (
    .ina({S_d1[244], S_d0[244]}), .inb({C1[244], C0[244]}),
    .rnd(r[1254]), .s(s[1254]), .clk(clk), .out({g1_244, g0_244}));
MSKand_opini2_d2_pini u_t_244 (
    .ina({fc1[244], fc0[244]}), .inb({p1_244, p0_244}),
    .rnd(r[1255]), .s(s[1255]), .clk(clk), .out({t1_244, t0_244}));
assign fc0[245] = g0_244 ^ t0_244;
assign fc1[245] = g1_244 ^ t1_244;
assign prod[488]   = p0_244 ^ fc0[244];
assign prod[489] = p1_244 ^ fc1[244];
wire p0_245 = S_d0[245] ^ C0[245];
wire p1_245 = S_d1[245] ^ C1[245];
wire g0_245, g1_245, t0_245, t1_245;
MSKand_opini2_d2_pini u_g_245 (
    .ina({S_d1[245], S_d0[245]}), .inb({C1[245], C0[245]}),
    .rnd(r[1256]), .s(s[1256]), .clk(clk), .out({g1_245, g0_245}));
MSKand_opini2_d2_pini u_t_245 (
    .ina({fc1[245], fc0[245]}), .inb({p1_245, p0_245}),
    .rnd(r[1257]), .s(s[1257]), .clk(clk), .out({t1_245, t0_245}));
assign fc0[246] = g0_245 ^ t0_245;
assign fc1[246] = g1_245 ^ t1_245;
assign prod[490]   = p0_245 ^ fc0[245];
assign prod[491] = p1_245 ^ fc1[245];
wire p0_246 = S_d0[246] ^ C0[246];
wire p1_246 = S_d1[246] ^ C1[246];
wire g0_246, g1_246, t0_246, t1_246;
MSKand_opini2_d2_pini u_g_246 (
    .ina({S_d1[246], S_d0[246]}), .inb({C1[246], C0[246]}),
    .rnd(r[1258]), .s(s[1258]), .clk(clk), .out({g1_246, g0_246}));
MSKand_opini2_d2_pini u_t_246 (
    .ina({fc1[246], fc0[246]}), .inb({p1_246, p0_246}),
    .rnd(r[1259]), .s(s[1259]), .clk(clk), .out({t1_246, t0_246}));
assign fc0[247] = g0_246 ^ t0_246;
assign fc1[247] = g1_246 ^ t1_246;
assign prod[492]   = p0_246 ^ fc0[246];
assign prod[493] = p1_246 ^ fc1[246];
wire p0_247 = S_d0[247] ^ C0[247];
wire p1_247 = S_d1[247] ^ C1[247];
wire g0_247, g1_247, t0_247, t1_247;
MSKand_opini2_d2_pini u_g_247 (
    .ina({S_d1[247], S_d0[247]}), .inb({C1[247], C0[247]}),
    .rnd(r[1260]), .s(s[1260]), .clk(clk), .out({g1_247, g0_247}));
MSKand_opini2_d2_pini u_t_247 (
    .ina({fc1[247], fc0[247]}), .inb({p1_247, p0_247}),
    .rnd(r[1261]), .s(s[1261]), .clk(clk), .out({t1_247, t0_247}));
assign fc0[248] = g0_247 ^ t0_247;
assign fc1[248] = g1_247 ^ t1_247;
assign prod[494]   = p0_247 ^ fc0[247];
assign prod[495] = p1_247 ^ fc1[247];
wire p0_248 = S_d0[248] ^ C0[248];
wire p1_248 = S_d1[248] ^ C1[248];
wire g0_248, g1_248, t0_248, t1_248;
MSKand_opini2_d2_pini u_g_248 (
    .ina({S_d1[248], S_d0[248]}), .inb({C1[248], C0[248]}),
    .rnd(r[1262]), .s(s[1262]), .clk(clk), .out({g1_248, g0_248}));
MSKand_opini2_d2_pini u_t_248 (
    .ina({fc1[248], fc0[248]}), .inb({p1_248, p0_248}),
    .rnd(r[1263]), .s(s[1263]), .clk(clk), .out({t1_248, t0_248}));
assign fc0[249] = g0_248 ^ t0_248;
assign fc1[249] = g1_248 ^ t1_248;
assign prod[496]   = p0_248 ^ fc0[248];
assign prod[497] = p1_248 ^ fc1[248];
wire p0_249 = S_d0[249] ^ C0[249];
wire p1_249 = S_d1[249] ^ C1[249];
wire g0_249, g1_249, t0_249, t1_249;
MSKand_opini2_d2_pini u_g_249 (
    .ina({S_d1[249], S_d0[249]}), .inb({C1[249], C0[249]}),
    .rnd(r[1264]), .s(s[1264]), .clk(clk), .out({g1_249, g0_249}));
MSKand_opini2_d2_pini u_t_249 (
    .ina({fc1[249], fc0[249]}), .inb({p1_249, p0_249}),
    .rnd(r[1265]), .s(s[1265]), .clk(clk), .out({t1_249, t0_249}));
assign fc0[250] = g0_249 ^ t0_249;
assign fc1[250] = g1_249 ^ t1_249;
assign prod[498]   = p0_249 ^ fc0[249];
assign prod[499] = p1_249 ^ fc1[249];
wire p0_250 = S_d0[250] ^ C0[250];
wire p1_250 = S_d1[250] ^ C1[250];
wire g0_250, g1_250, t0_250, t1_250;
MSKand_opini2_d2_pini u_g_250 (
    .ina({S_d1[250], S_d0[250]}), .inb({C1[250], C0[250]}),
    .rnd(r[1266]), .s(s[1266]), .clk(clk), .out({g1_250, g0_250}));
MSKand_opini2_d2_pini u_t_250 (
    .ina({fc1[250], fc0[250]}), .inb({p1_250, p0_250}),
    .rnd(r[1267]), .s(s[1267]), .clk(clk), .out({t1_250, t0_250}));
assign fc0[251] = g0_250 ^ t0_250;
assign fc1[251] = g1_250 ^ t1_250;
assign prod[500]   = p0_250 ^ fc0[250];
assign prod[501] = p1_250 ^ fc1[250];
wire p0_251 = S_d0[251] ^ C0[251];
wire p1_251 = S_d1[251] ^ C1[251];
wire g0_251, g1_251, t0_251, t1_251;
MSKand_opini2_d2_pini u_g_251 (
    .ina({S_d1[251], S_d0[251]}), .inb({C1[251], C0[251]}),
    .rnd(r[1268]), .s(s[1268]), .clk(clk), .out({g1_251, g0_251}));
MSKand_opini2_d2_pini u_t_251 (
    .ina({fc1[251], fc0[251]}), .inb({p1_251, p0_251}),
    .rnd(r[1269]), .s(s[1269]), .clk(clk), .out({t1_251, t0_251}));
assign fc0[252] = g0_251 ^ t0_251;
assign fc1[252] = g1_251 ^ t1_251;
assign prod[502]   = p0_251 ^ fc0[251];
assign prod[503] = p1_251 ^ fc1[251];
wire p0_252 = S_d0[252] ^ C0[252];
wire p1_252 = S_d1[252] ^ C1[252];
wire g0_252, g1_252, t0_252, t1_252;
MSKand_opini2_d2_pini u_g_252 (
    .ina({S_d1[252], S_d0[252]}), .inb({C1[252], C0[252]}),
    .rnd(r[1270]), .s(s[1270]), .clk(clk), .out({g1_252, g0_252}));
MSKand_opini2_d2_pini u_t_252 (
    .ina({fc1[252], fc0[252]}), .inb({p1_252, p0_252}),
    .rnd(r[1271]), .s(s[1271]), .clk(clk), .out({t1_252, t0_252}));
assign fc0[253] = g0_252 ^ t0_252;
assign fc1[253] = g1_252 ^ t1_252;
assign prod[504]   = p0_252 ^ fc0[252];
assign prod[505] = p1_252 ^ fc1[252];
wire p0_253 = S_d0[253] ^ C0[253];
wire p1_253 = S_d1[253] ^ C1[253];
wire g0_253, g1_253, t0_253, t1_253;
MSKand_opini2_d2_pini u_g_253 (
    .ina({S_d1[253], S_d0[253]}), .inb({C1[253], C0[253]}),
    .rnd(r[1272]), .s(s[1272]), .clk(clk), .out({g1_253, g0_253}));
MSKand_opini2_d2_pini u_t_253 (
    .ina({fc1[253], fc0[253]}), .inb({p1_253, p0_253}),
    .rnd(r[1273]), .s(s[1273]), .clk(clk), .out({t1_253, t0_253}));
assign fc0[254] = g0_253 ^ t0_253;
assign fc1[254] = g1_253 ^ t1_253;
assign prod[506]   = p0_253 ^ fc0[253];
assign prod[507] = p1_253 ^ fc1[253];
wire p0_254 = S_d0[254] ^ C0[254];
wire p1_254 = S_d1[254] ^ C1[254];
wire g0_254, g1_254, t0_254, t1_254;
MSKand_opini2_d2_pini u_g_254 (
    .ina({S_d1[254], S_d0[254]}), .inb({C1[254], C0[254]}),
    .rnd(r[1274]), .s(s[1274]), .clk(clk), .out({g1_254, g0_254}));
MSKand_opini2_d2_pini u_t_254 (
    .ina({fc1[254], fc0[254]}), .inb({p1_254, p0_254}),
    .rnd(r[1275]), .s(s[1275]), .clk(clk), .out({t1_254, t0_254}));
wire fct0 = g0_254 ^ t0_254;
wire fct1 = g1_254 ^ t1_254;
assign prod[508]   = p0_254 ^ fc0[254];
assign prod[509] = p1_254 ^ fc1[254];
// top bit: sum only, carry-out dropped (mod 2^256, EVM MUL)
wire p0_255 = S_d0[255] ^ C0[255];
wire p1_255 = S_d1[255] ^ C1[255];
assign prod[510]   = p0_255 ^ fct0;
assign prod[511] = p1_255 ^ fct1;

endmodule
