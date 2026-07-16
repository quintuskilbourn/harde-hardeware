// MATCHI testbench for the 256-bit adder tops. Same convention as the verified
// 8-bit tb (./tb_add8.v): values are irrelevant to MATCHI
// (symbolic); only signal-activity timing is read from the VCD. Inputs are
// re-randomized every cycle so the annotated activity windows match physics.
// Widened to 512-bit share vectors and run long enough to cover the deepest
// activity window (out [0,1030]); the $random fills are looped since $random
// is 32-bit.
`timescale 1ns/1ps
`ifndef TOPMOD
`define TOPMOD top_add256_opini2
`endif
`ifndef SUBVAL
`define SUBVAL 1'b0
`endif
module tb ();
parameter HP = 5;
reg clk, rst, go, sub;
reg [511:0] a, b, r, s;
wire [511:0] sum;
wire [1:0] cout;
`ifdef RECOMB
wire leak_o;
`endif

always #HP clk = ~clk;

`TOPMOD dut (.clk(clk), .rst(rst), .go(go), .sub(sub),
             .a(a), .b(b), .r(r), .s(s), .sum(sum), .cout(cout)
`ifdef RECOMB
             , .leak_o(leak_o)
`endif
);

integer i, w;
task randfill;
    begin
        for (w = 0; w < 16; w = w + 1) begin
            a[w*32 +: 32] = $random;
            b[w*32 +: 32] = $random;
            r[w*32 +: 32] = $random;
            s[w*32 +: 32] = $random;
        end
    end
endtask

initial begin
`ifdef DUMPFILE
    $dumpfile(`DUMPFILE); $dumpvars(0, tb);
`endif
    clk = 1'b1; rst = 1'b1; go = 1'b0; sub = `SUBVAL;
    a = 512'h0; b = 512'h0; r = 512'h0; s = 512'h0;
    #(6*HP);
    @(negedge clk); rst = 1'b0;
    #(4*HP);
    // cycle 0: one-cycle go pulse
    @(negedge clk); go = 1'b1; randfill;
    @(negedge clk); go = 1'b0; randfill;
    for (i = 0; i < 1100; i = i + 1) begin
        @(negedge clk); randfill;
    end
    $finish;
end
endmodule
