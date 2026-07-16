// Faithful d=2 O-PINI2 masked-AND gadget (Cassiers-Standaert, Algorithm 3;
// cross-checked against leansec/oracle/opini2_iterated.nl and OPINI2.lean).
//   = HPC2 AND core (z0,z1)  +  zero-sharing OUTPUT REFRESH:
//     one fresh bit s, s1 = s0, driven into TWO physically-distinct output
//     refresh registers Reg[s0], Reg[s1]; c_i = Reg[ z_i XOR Reg[s_i] ].
// The two refresh registers are kept distinct (keep/DONT_TOUCH) per Alg.3
// (equal inputs do NOT authorize merging two physical probe locations).
//
// NOTE: MATCHI treats this as an *assumed* leaf (black box); it reads only the
// port annotations below, not these internals. The refresh is built faithfully
// for structural fidelity, but MATCHI's verdict is driven by matchi_prop="OPINI".
//
// Pipeline latencies: inb@0, rnd@0, ina@1, s@1, out@3.
(* matchi_prop = "OPINI", matchi_strat = "assumed", matchi_shares = 2, matchi_arch = "pipeline" *)
module MSKand_opini2_d2 (ina, inb, rnd, s, clk, out);

(* matchi_type = "sharing", matchi_latency = 1 *) input [1:0] ina;
(* matchi_type = "sharing", matchi_latency = 0 *) input [1:0] inb;
(* matchi_type = "random",  matchi_latency = 0 *) input rnd;
(* matchi_type = "random",  matchi_latency = 1 *) input s;
(* matchi_type = "clock" *)                       input clk;
(* matchi_type = "sharing", matchi_latency = 3 *) output [1:0] out;

// ---- HPC2 AND core (z_i valid combinationally at internal latency 2) ----
reg rnd_prev;
reg inb0_prev, inb1_prev;
reg aibi0, aibi1;
reg u0, u1, v0, v1, w0, w1;

always @(posedge clk) begin
    rnd_prev  <= rnd;
    inb0_prev <= inb[0];
    inb1_prev <= inb[1];
    v0 <= inb[1] ^ rnd;
    v1 <= inb[0] ^ rnd;
    aibi0 <= ina[0] & inb0_prev;
    aibi1 <= ina[1] & inb1_prev;
    u0 <= ~ina[0] & rnd_prev;
    u1 <= ~ina[1] & rnd_prev;
    w0 <= ina[0] & v0;
    w1 <= ina[1] & v1;
end

wire z0 = aibi0 ^ u0 ^ w0;   // internal latency 2
wire z1 = aibi1 ^ u1 ^ w1;   // internal latency 2

// ---- zero-sharing output refresh (Algorithm 3) ----
// s fed at latency 1, so Reg[s] is available at latency 2 to align with z.
(* keep = "yes", DONT_TOUCH = "yes" *) reg s0_r;
(* keep = "yes", DONT_TOUCH = "yes" *) reg s1_r;   // physically distinct, s1 = s0
reg c0, c1;
always @(posedge clk) begin
    s0_r <= s;
    s1_r <= s;
    c0 <= z0 ^ s0_r;         // Reg[ z0 XOR Reg[s0] ] -> latency 3
    c1 <= z1 ^ s1_r;         // Reg[ z1 XOR Reg[s1] ] -> latency 3
end

assign out[0] = c0;
assign out[1] = c1;

endmodule
