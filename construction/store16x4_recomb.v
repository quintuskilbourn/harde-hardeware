// NEGATIVE CONTROL (must FAIL): identical to the target plus one share-
// recombining register (leak0 <= rdata[0]^rdata[1]). MATCHI must flag the
// gate sensitive in multiple shares (glitch leakage).
// Masked storage path: 4 x 16-bit two-share scratchpad, two physically-
// separate lanes (share 0: m0_*, share 1: m1_*), public addresses, registered
// per-lane read port, 2-cycle two-lane paging pipeline. No gadgets, no
// randomness — every gate touches exactly one share of one value.
// Dense sharing layout: port[2i]=share0, port[2i+1]=share1.
(* matchi_prop = "PINI", matchi_strat = "composite_top", matchi_arch = "loopy", matchi_shares = 2 *)
module store16x4_recomb (clk, rst, we, waddr, wdata, raddr, rdata,
                  pg_go, pg_from, pg_to, leak_o);
(* matchi_type = "clock" *)   input clk;
(* matchi_type = "control" *) input rst;
(* matchi_type = "control" *) input we;
(* matchi_type = "control" *) input [1:0] waddr;
(* matchi_type = "control" *) input [1:0] raddr;
(* matchi_type = "control" *) input pg_go;
(* matchi_type = "control" *) input [1:0] pg_from;
(* matchi_type = "control" *) input [1:0] pg_to;
(* matchi_type = "sharings_dense", matchi_active = "a_act" *) input [31:0] wdata;
(* matchi_type = "sharings_dense", matchi_active = "out_act" *) output [31:0] rdata;
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

// ---- lane registers: 4 words per lane, explicit (no memory inference) ----
reg [15:0] m0_0;
reg [15:0] m0_1;
reg [15:0] m0_2;
reg [15:0] m0_3;
reg [15:0] m1_0;
reg [15:0] m1_1;
reg [15:0] m1_2;
reg [15:0] m1_3;

// ---- per-lane write decode (lane k logic sees only share-k bits) ----
wire [15:0] wd0 = {wdata[30], wdata[28], wdata[26], wdata[24], wdata[22], wdata[20], wdata[18], wdata[16], wdata[14], wdata[12], wdata[10], wdata[8], wdata[6], wdata[4], wdata[2], wdata[0]};
wire [15:0] wd1 = {wdata[31], wdata[29], wdata[27], wdata[25], wdata[23], wdata[21], wdata[19], wdata[17], wdata[15], wdata[13], wdata[11], wdata[9], wdata[7], wdata[5], wdata[3], wdata[1]};

// ---- transition-safe paging: both lane registers load at the SAME edge,
// each from its own lane's read mux; write-back one cycle later ----
reg pg_rd, pg_wr;                 // 2-cycle sequence (public control)
reg [1:0] pg_src, pg_dst;
reg [15:0] pg0, pg1;           // physically-separate paging lanes
always @(posedge clk) begin
    if (rst) begin pg_rd <= 1'b0; pg_wr <= 1'b0; end
    else begin
        pg_rd <= pg_go;
        pg_wr <= pg_rd;
        if (pg_go) begin pg_src <= pg_from; pg_dst <= pg_to; end
        if (pg_rd) begin
            pg0 <= ((pg_src == 2'd0) ? m0_0 : ((pg_src == 2'd1) ? m0_1 : ((pg_src == 2'd2) ? m0_2 : m0_3)));   // share 0 lane
            pg1 <= ((pg_src == 2'd0) ? m1_0 : ((pg_src == 2'd1) ? m1_1 : ((pg_src == 2'd2) ? m1_2 : m1_3)));   // share 1 lane — SAME edge
        end
    end
end

// ---- lane 0 writes (SSTORE + paging write-back) ----
always @(posedge clk) begin
    if (we && waddr == 2'd0) m0_0 <= wd0;
    if (we && waddr == 2'd1) m0_1 <= wd0;
    if (we && waddr == 2'd2) m0_2 <= wd0;
    if (we && waddr == 2'd3) m0_3 <= wd0;
    if (pg_wr && pg_dst == 2'd0) m0_0 <= pg0;
    if (pg_wr && pg_dst == 2'd1) m0_1 <= pg0;
    if (pg_wr && pg_dst == 2'd2) m0_2 <= pg0;
    if (pg_wr && pg_dst == 2'd3) m0_3 <= pg0;
end
always @(posedge clk) begin
    if (we && waddr == 2'd0) m1_0 <= wd1;
    if (we && waddr == 2'd1) m1_1 <= wd1;
    if (we && waddr == 2'd2) m1_2 <= wd1;
    if (we && waddr == 2'd3) m1_3 <= wd1;
    if (pg_wr && pg_dst == 2'd0) m1_0 <= pg1;
    if (pg_wr && pg_dst == 2'd1) m1_1 <= pg1;
    if (pg_wr && pg_dst == 2'd2) m1_2 <= pg1;
    if (pg_wr && pg_dst == 2'd3) m1_3 <= pg1;
end

// ---- registered per-lane read port (SLOAD); transitions stay in-lane ----
reg [15:0] rreg0, rreg1;
always @(posedge clk) begin
    rreg0 <= ((raddr == 2'd0) ? m0_0 : ((raddr == 2'd1) ? m0_1 : ((raddr == 2'd2) ? m0_2 : m0_3)));
    rreg1 <= ((raddr == 2'd0) ? m1_0 : ((raddr == 2'd1) ? m1_1 : ((raddr == 2'd2) ? m1_2 : m1_3)));
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
