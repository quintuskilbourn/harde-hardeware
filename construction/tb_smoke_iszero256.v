// Functional smoke test for iszero256 (NOT a security check — MATCHI is the
// separate verification step). Shares the 256-bit operand with a random mask,
// holds the input steady, waits out the 8-level tree (final output latency
// ~24 cycles), recombines the ISZERO output shares, compares against
// (x == 0 ? 1 : 0). Fresh gadget randoms every cycle (recombined output is
// mask-independent, so a stable input settles to the correct value).
`timescale 1ns/1ps
module tb;
reg clk = 0, rst = 1, go = 0;
reg [511:0] a;
reg [255:0] r, s;
wire [1:0] out;

iszero256 dut (.clk(clk), .rst(rst), .go(go), .a(a), .r(r), .s(s), .out(out));

always #5 clk = ~clk;

integer k, errors;
// fresh gadget randoms every cycle
always @(negedge clk) begin
    for (k = 0; k < 8; k = k + 1) begin
        r[k*32 +: 32] = $random;
        s[k*32 +: 32] = $random;
    end
end

reg [255:0] am;
reg got, expd;
integer j;
task check(input [255:0] x);
    begin
        for (j = 0; j < 8; j = j + 1) am[j*32 +: 32] = $random;
        for (j = 0; j < 256; j = j + 1) begin
            a[2*j]   = x[j] ^ am[j];
            a[2*j+1] = am[j];
        end
        repeat (200) @(negedge clk);   // >> tree depth (~24 cycles)
        got  = out[0] ^ out[1];
        expd = (x == 256'h0) ? 1'b1 : 1'b0;
        if (got !== expd) begin
            errors = errors + 1;
            $display("FAIL  x=%h  got=%b  exp=%b", x, got, expd);
        end else begin
            $display("PASS  iszero=%b  x=%h", got, x);
        end
    end
endtask

initial begin
    errors = 0;
    #40 rst = 0;
    check(256'h0);                                              // input = 0    -> 1
    check(256'h1);                                              // input = 1    -> 0
    check({256{1'b1}});                                         // all ones     -> 0
    check(256'h8000000000000000_0000000000000000_0000000000000000_0000000000000000); // single high bit -> 0
    check(256'hdeadbeef_01234567_89abcdef_fedcba98_76543210_0f1e2d3c_4b5a6978_87a9cbed); // random -> 0
    check(256'h0);                                             // 0 again (transition from nonzero) -> 1
    if (errors == 0) $display("SMOKE: ALL PASS");
    else             $display("SMOKE: %0d FAILURES", errors);
    $finish;
end
endmodule
