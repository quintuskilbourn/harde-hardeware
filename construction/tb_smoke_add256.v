// Functional smoke test for top_add256_opini2 (NOT a security check — MATCHI
// is the separate verification step). Shares each operand with a random mask,
// holds inputs steady, waits out the ripple (carry_i valid ~2i + gadget
// latency 3), recombines sum shares, compares against x+y / x-y mod 2^256.
`timescale 1ns/1ps
module tb;
reg clk = 0, rst = 1, go = 0, sub;
reg [511:0] a, b, r, s;
wire [511:0] sum;
wire [1:0] cout;

top_add256_opini2 dut (.clk(clk), .rst(rst), .go(go), .sub(sub),
                       .a(a), .b(b), .r(r), .s(s), .sum(sum), .cout(cout));

always #5 clk = ~clk;

integer k, errors;
// fresh gadget randoms every cycle
always @(negedge clk) begin
    for (k = 0; k < 16; k = k + 1) begin
        r[k*32 +: 32] = $random;
        s[k*32 +: 32] = $random;
    end
end

reg [255:0] am, bm, got, expd;
integer j;
task check(input [255:0] x, input [255:0] y, input subv);
    begin
        for (j = 0; j < 8; j = j + 1) begin
            am[j*32 +: 32] = $random;
            bm[j*32 +: 32] = $random;
        end
        sub = subv;
        for (j = 0; j < 256; j = j + 1) begin
            a[2*j] = x[j] ^ am[j];  a[2*j+1] = am[j];
            b[2*j] = y[j] ^ bm[j];  b[2*j+1] = bm[j];
        end
        repeat (600) @(negedge clk);
        for (j = 0; j < 256; j = j + 1) got[j] = sum[2*j] ^ sum[2*j+1];
        expd = subv ? (x - y) : (x + y);
        if (got !== expd) begin
            errors = errors + 1;
            $display("FAIL sub=%0d", subv);
            $display("  x  =%h", x);
            $display("  y  =%h", y);
            $display("  got=%h", got);
            $display("  exp=%h", expd);
        end else begin
            $display("PASS sub=%0d cout=%b", subv, cout[0]^cout[1]);
        end
    end
endtask

initial begin
    errors = 0;
    #40 rst = 0;
    check(256'h0, 256'h0, 1'b0);
    check({256{1'b1}}, 256'h1, 1'b0);                          // full-length carry ripple
    check(256'hdeadbeef_01234567_89abcdef_fedcba98_76543210_0f1e2d3c_4b5a6978_87a9cbed,
          256'hc0ffee00_aa55aa55_5aa55aa5_11223344_55667788_99aabbcc_ddeeff00_13579bdf, 1'b0);
    check(256'h1, 256'h2, 1'b1);                               // 1-2 = -1 (all ones)
    check(256'h8000000000000000_0000000000000000_0000000000000000_0000000000000000,
          256'h1, 1'b1);
    check(256'hc0ffee00_aa55aa55_5aa55aa5_11223344_55667788_99aabbcc_ddeeff00_13579bdf,
          256'hdeadbeef_01234567_89abcdef_fedcba98_76543210_0f1e2d3c_4b5a6978_87a9cbed, 1'b1);
    if (errors == 0) $display("SMOKE: ALL PASS");
    else             $display("SMOKE: %0d FAILURES", errors);
    $finish;
end
endmodule
