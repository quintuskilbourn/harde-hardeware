#!/usr/bin/env python3
import contextlib
import io
import unittest
from pathlib import Path

import netlist2lean as n


def rejected(fn):
    with contextlib.redirect_stderr(io.StringIO()):
        with unittest.TestCase().assertRaises(SystemExit):
            fn()


class Netlist2LeanTests(unittest.TestCase):
    def test_hpc2_schedule_is_exact(self):
        root = Path(__file__).resolve().parent
        text = (root / "netlists" / "hpc2.v").read_text()
        built = n.build(n.parse_netlist(text, "hpc2_top"))
        arrivals = n.parse_input_arrivals(["0=1"], built["input_sharings"])
        sources = {
            gate: arrivals[sharing]
            for (sharing, _share), gate in built["inp_gate"].items()
        }
        n.schedule(built["gates"], sources)
        n.validate_schedule(built["gates"])

    def test_mixed_arrival_cone_is_rejected(self):
        text = """
module mixed(A, B, O);
  (* SILVER="[0:0]_0" *) input A;
  (* SILVER="[1:1]_0" *) input B;
  (* SILVER="[2:2]_0" *) output O;
  AND2_X1 u (.A1(A), .A2(B), .ZN(O));
endmodule
"""
        built = n.build(n.parse_netlist(text, "mixed"))
        arrivals = n.parse_input_arrivals(["1=1"], built["input_sharings"])
        sources = {
            gate: arrivals[sharing]
            for (sharing, _share), gate in built["inp_gate"].items()
        }
        n.schedule(built["gates"], sources)
        rejected(lambda: n.validate_schedule(built["gates"]))

    def test_dff_requires_clock_and_q(self):
        text = """
module bad(A, CLK, O);
  (* SILVER="[0:0]_0" *) input A;
  (* SILVER="clock" *) input CLK;
  (* SILVER="[1:1]_0" *) output O;
  DFF_X1 u (.D(A), .QN(O));
endmodule
"""
        rejected(lambda: n.parse_netlist(text, "bad"))

    def test_dff_clock_must_use_annotated_clock(self):
        text = """
module bad_clock(A, CLK, OTHER, O);
  (* SILVER="[0:0]_0" *) input A;
  (* SILVER="clock" *) input CLK;
  input OTHER;
  (* SILVER="[1:1]_0" *) output O;
  DFF_X1 u (.D(A), .CK(OTHER), .Q(O), .QN(unused));
endmodule
"""
        parsed = n.parse_netlist(text, "bad_clock")
        rejected(lambda: n.build(parsed))

    def test_duplicate_share_coordinate_is_rejected(self):
        text = """
module duplicate(A, B, O);
  (* SILVER="[0:0]_0" *) input A;
  (* SILVER="[0:0]_0" *) input B;
  (* SILVER="[1:1]_0" *) output O;
  AND2_X1 u (.A1(A), .A2(B), .ZN(O));
endmodule
"""
        parsed = n.parse_netlist(text, "duplicate")
        rejected(lambda: n.build(parsed))

    def test_multiple_drivers_are_rejected(self):
        text = """
module drivers(A, B, O);
  (* SILVER="[0:0]_0" *) input A;
  (* SILVER="[1:1]_0" *) input B;
  (* SILVER="[2:2]_0" *) output O;
  AND2_X1 u0 (.A1(A), .A2(B), .ZN(O));
  XOR2_X1 u1 (.A(A), .B(B), .Z(O));
endmodule
"""
        parsed = n.parse_netlist(text, "drivers")
        rejected(lambda: n.build(parsed))


if __name__ == "__main__":
    unittest.main()
