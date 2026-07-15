#!/usr/bin/env python3
"""
netlist2lean — SILVER-format NANG45 netlist  ->  Lean `GadgetInstance` literal.

WHY THIS EXISTS (the trust story)
---------------------------------
leansec proves side-channel properties about a Lean `Circuit`.  Until now that
Circuit was HAND-TRANSCRIBED from the RTL, so the kernel proof bound to a
transcription, not the hardware.  This tool closes that gap MECHANICALLY:

    N (the netlist) is the single source of truth.
      SILVER reads N            -> verdict
      this parser reads THE SAME N -> Lean Circuit C -> kernel verdict
    If SILVER-on-N and kernel-on-C agree, that cross-validates (a) this small,
    auditable parser and (b) the verdict.

This tool is UNTRUSTED.  Its job is to be small and auditable enough that a human
(and codex-verify) can confirm it drops/rewires NO gate.  A parser that produces
a circuit that "verifies" but does not match the netlist is exactly the hollow
result the leansec project exists to prevent — so faithfulness, not cleverness,
is the whole design goal.

INPUT  : a SILVER-annotated, flattened, standard-cell Verilog netlist (`fin.v`),
         the EXACT artifact SILVER's `./bin/verify --verilog 1` ingests.  Cells
         are instantiations from SILVER's `cell/Library.txt` (constrained NANG45).
OUTPUT : a Lean source file defining `circuit : Circuit`, `member`, and
         `gadget : GadgetInstance`, structurally identical in shape to the
         hand gadgets in `LeanSec/Gadgets/*.lean`.  With `--witness-out`, also
         emit a separate Lean module containing the parsed cell/output order,
         a cell-granular atomic circuit, and a kernel-checked
         `SupportedCellExpansion` for the generated `circuit`.

CELL -> Lean GateKind  (Lean's closed library is {and, xor, not, reg, mux, const,
rnd, inp, ini, ctl}; there is NO nand/nor/or/xnor/buf kind, so composite cells
are EXPANDED into latency-0 primitive trees):

    INV  (A->ZN/Y)          -> .not
    BUF  (A->Y)             -> .and(a,a)          (identity; single member node)
    AND2 (A1 A2->ZN/Y)      -> .and
    XOR2 (A B->Z/Y)         -> .xor
    NAND2(A1 A2->ZN/Y)      -> .not(.and(a,b))    [2 gates; output = the .not]
    XNOR2(A B->ZN/Y)        -> .not(.xor(a,b))    [2 gates; output = the .not]
    NOR2 (A1 A2->ZN/Y)      -> .not(or) via De Morgan .and(.not a,.not b) then... :
                               nor(a,b)=.and(.not a,.not b)          [3 gates]
    OR2  (A1 A2->ZN/Y)      -> or(a,b)=.not(.and(.not a,.not b))      [4 gates]
    DFF  (D,CK->Q[,QN])     -> .reg (latency-1 D input); QN = .not(reg) if used
    SDFF (D,SE,SI,CK->Q)    -> .reg(.mux(SE,D,SI)); both mux and Q are members
    const 1'b0/1'h0         -> .const false ;  1'b1/1'h1 -> .const true

By default, only each source/standard-cell output is a member (eligible probe).
`--conservative-members` additionally makes primitive expansion-internal nodes
members.  That closes `GadgetInstance.WF` under immediate combinational inputs
and proves security for a probe set at least as strong as SILVER's cell-output
set; use it when an anchor must establish `pini`, whose definition includes WF.

FAITHFULNESS OF THE EXPANSION (the load-bearing argument, checked against
LeanSec/Expansion.lean):
  * eval  : each expansion computes the SAME Boolean function of the same input
            nets, so the cell OUTPUT net carries the identical value.
  * glitch: `glitchGates` returns only the FRONTIER (cone leaves: sources +
            register outputs) of a gate's latency-0 cone, walking the raw circuit
            structure.  It NEVER returns internal combinational nodes.  So a cell
            expanded into a latency-0 primitive tree has the IDENTICAL glitch
            frontier as the single cell would.  Internal expansion nodes are
            marked NON-member, so `memberNodes` (probe candidates) and the
            post-expansion `.filter g.member` see EXACTLY ONE probeable node per
            SILVER cell — matching SILVER's one-probe-per-cell model.

SCHEDULE (horizon / member / output cycle) is NOT in the netlist; it is derived
mechanically by register-depth on the built gate graph:
    cyc(input source)= the explicit --input-arrival for its sharing (default 0)
    cyc(other source)= 0
    cyc(comb gate)   = max cyc over its latency-0 driver gates
    cyc(reg)         = cyc(D-driver) + 1
    horizon          = max cyc + 1
    member(g, c)     = (c == cyc(g))  for every source / cell-output / reg / QN
                       gate;  internal expansion nodes are never members.
The share/refresh/output roles come from the (* SILVER=... *) port annotations.
SILVER's flattened format does not retain the source RTL's `fv_latency`
metadata, so staggered arrivals must be supplied explicitly and are recorded in
the generated Lean literal.

Usage:
    netlist2lean.py <netlist.v> --module NAME --namespace NS \
        [--input-arrival SHARING=CYCLE] [--conservative-members] \
        [--horizon N] [--out FILE] \
        [--witness-out FILE --witness-namespace NS]
"""

import argparse
import re
import sys
from dataclasses import dataclass, field


# --------------------------------------------------------------------------- #
# Cell library.  Mirrors SILVER's cell/Library.txt (constrained NANG45) plus the
# generic function names.  Each entry: silver function, ordered input pin names,
# the single output pin name.  Any cell not here is a HARD ERROR (never a silent
# drop).  Kept as an explicit table (more auditable than parsing the .txt).
# --------------------------------------------------------------------------- #
CELLS = {
    # celltype           : (func, [input pins],   output pin)
    "INV_X1":   ("not",  ["A"],         "ZN"),
    "INV_X2":   ("not",  ["A"],         "ZN"),
    "NOT":      ("not",  ["A"],         "Y"),
    "BUF_X1":   ("buf",  ["A"],         "Z"),
    "BUF_X2":   ("buf",  ["A"],         "Z"),
    "BUF":      ("buf",  ["A"],         "Y"),
    "AND2_X1":  ("and",  ["A1", "A2"],  "ZN"),
    "AND2_X2":  ("and",  ["A1", "A2"],  "ZN"),
    "AND":      ("and",  ["A", "B"],    "Y"),
    "NAND2_X1": ("nand", ["A1", "A2"],  "ZN"),
    "NAND2_X2": ("nand", ["A1", "A2"],  "ZN"),
    "NAND":     ("nand", ["A", "B"],    "Y"),
    "OR2_X1":   ("or",   ["A1", "A2"],  "ZN"),
    "OR2_X2":   ("or",   ["A1", "A2"],  "ZN"),
    "OR":       ("or",   ["A", "B"],    "Y"),
    "NOR2_X1":  ("nor",  ["A1", "A2"],  "ZN"),
    "NOR2_X2":  ("nor",  ["A1", "A2"],  "ZN"),
    "NOR":      ("nor",  ["A", "B"],    "Y"),
    "XOR2_X1":  ("xor",  ["A", "B"],    "Z"),
    "XOR2_X2":  ("xor",  ["A", "B"],    "Z"),
    "XOR":      ("xor",  ["A", "B"],    "Y"),
    "XNOR2_X1": ("xnor", ["A", "B"],    "ZN"),
    "XNOR2_X2": ("xnor", ["A", "B"],    "ZN"),
    "XNOR":     ("xnor", ["A", "B"],    "Y"),
}

# Exact Lean constructors in CellRefinement.SupportedCombCell.  Keeping this
# second table explicit makes additions fail closed: a Python-supported cell
# cannot silently lack a Lean witness constructor.
CELL_LEAN_CTORS = {
    "INV_X1": "invX1", "INV_X2": "invX2", "NOT": "not",
    "BUF_X1": "bufX1", "BUF_X2": "bufX2", "BUF": "buf",
    "AND2_X1": "and2X1", "AND2_X2": "and2X2", "AND": "and",
    "NAND2_X1": "nand2X1", "NAND2_X2": "nand2X2", "NAND": "nand",
    "OR2_X1": "or2X1", "OR2_X2": "or2X2", "OR": "or",
    "NOR2_X1": "nor2X1", "NOR2_X2": "nor2X2", "NOR": "nor",
    "XOR2_X1": "xor2X1", "XOR2_X2": "xor2X2", "XOR": "xor",
    "XNOR2_X1": "xnor2X1", "XNOR2_X2": "xnor2X2", "XNOR": "xnor",
}
if set(CELL_LEAN_CTORS) != set(CELLS):
    raise RuntimeError("CELL_LEAN_CTORS must cover exactly the CELLS table")
# Sequential cells handled specially (clock pin dropped, Q/QN split).
DFF_CELLS = {
    "DFF_X1": {"D": "D", "CK": "CK", "Q": "Q", "QN": "QN"},
    "DFF_X2": {"D": "D", "CK": "CK", "Q": "Q", "QN": "QN"},
    "DFF":    {"D": "D", "CK": "C",  "Q": "Q", "QN": None},
}

# Scan sequential cells are deliberately disjoint from DFF_CELLS.  They must
# never reach the ordinary-DFF expansion, which would silently discard SE/SI.
# The generic alias follows DFF's C clock spelling; Nangate-style aliases use
# CK.  QN is supported for X1/X2 and emitted as .not(Q) when consumed.
SCAN_DFF_CELLS = {
    "SDFF_X1": {"D": "D", "SE": "SE", "SI": "SI", "CK": "CK",
                 "Q": "Q", "QN": "QN"},
    "SDFF_X2": {"D": "D", "SE": "SE", "SI": "SI", "CK": "CK",
                 "Q": "Q", "QN": "QN"},
    "SDFF":    {"D": "D", "SE": "SE", "SI": "SI", "CK": "C",
                 "Q": "Q", "QN": None},
}
if not set(DFF_CELLS).isdisjoint(SCAN_DFF_CELLS):
    raise RuntimeError("ordinary and scan DFF tables must be disjoint")
SCAN_DFF_LEAN_CTORS = {
    "SDFF_X1": "sdffX1", "SDFF_X2": "sdffX2", "SDFF": "sdff",
}
if set(SCAN_DFF_LEAN_CTORS) != set(SCAN_DFF_CELLS):
    raise RuntimeError("SCAN_DFF_LEAN_CTORS must cover exactly scan DFFs")


def die(msg):
    sys.stderr.write("netlist2lean: FATAL: " + msg + "\n")
    sys.exit(1)


# --------------------------------------------------------------------------- #
# Parsing the netlist into a neutral structural form.
# --------------------------------------------------------------------------- #
@dataclass
class Port:
    name: str
    direction: str          # "input" | "output"
    width: int              # number of bits
    silver: str | None      # raw SILVER attribute string or None


@dataclass
class Inst:
    celltype: str
    name: str
    conns: dict             # pin name -> net token (str)


@dataclass
class Netlist:
    module: str
    ports: list             # list[Port]
    insts: list             # list[Inst]


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)   # C block comments
    text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.S)  # Verilog (* attrs *)
    text = re.sub(r"//[^\n]*", " ", text)                # line comments
    return text


def parse_netlist(text, module_name):
    """Parse module_name out of a yosys `write_verilog -noattr` netlist.

    NOTE: SILVER port annotations `(* SILVER=... *)` are re-added AFTER -noattr,
    so we must scan them BEFORE stripping block comments.
    """
    # --- 1. capture the SILVER port annotations (block-comment attributes) ----
    ann = {}  # port name -> silver string
    for m in re.finditer(
        r'\(\*\s*SILVER\s*=\s*"([^"]*)"\s*\*\)\s*(input|output)\s*'
        r'(\[\s*\d+\s*:\s*\d+\s*\])?\s*(\\?[^\s;]+)\s*;',
        text,
    ):
        name = m.group(4).strip()
        if name in ann:
            die(f"duplicate SILVER annotation for port {name!r}")
        ann[name] = m.group(1)

    body = strip_comments(text)

    # --- 2. locate the module ------------------------------------------------
    mm = re.search(r"\bmodule\s+" + re.escape(module_name) + r"\b(.*?)\bendmodule\b",
                   body, flags=re.S)
    if not mm:
        die(f"module {module_name!r} not found")
    mbody = mm.group(1)

    if re.search(r"\bassign\b", mbody):
        die("continuous assignments are outside the accepted flattened "
            "structural-Verilog subset")

    # --- 3. ports ------------------------------------------------------------
    ports = []
    seen = set()
    for m in re.finditer(
        r"\b(input|output)\b\s*(\[\s*(\d+)\s*:\s*(\d+)\s*\])?\s*(\\?[^\s;,]+)\s*;",
        mbody,
    ):
        direction = m.group(1)
        if m.group(2):
            hi, lo = int(m.group(3)), int(m.group(4))
            width = abs(hi - lo) + 1
        else:
            width = 1
        name = m.group(5).strip()
        if name in seen:
            die(f"duplicate port declaration {name!r}")
        seen.add(name)
        ports.append(Port(name=name, direction=direction, width=width,
                          silver=ann.get(name)))

    # --- 4. instances --------------------------------------------------------
    insts = []
    # An instance:  CELLTYPE  INSTNAME ( ... ) ;
    # Cell/inst names are ordinary identifiers; the connection list is inside the
    # outermost ( ... ).  We match cell types we know so we never mis-scan.
    known = set(CELLS) | set(DFF_CELLS) | set(SCAN_DFF_CELLS)
    for m in re.finditer(
        r"\b([A-Za-z_][A-Za-z0-9_]*)\s+(\\?\S+|\w+)\s*\((.*?)\)\s*;",
        mbody, flags=re.S,
    ):
        celltype = m.group(1)
        if celltype not in known:
            die(f"unknown cell type or module instance {celltype!r} "
                "(not in library table)")
        instname = m.group(2).strip()
        connstr = m.group(3)
        conns = {}
        for pm in re.finditer(r"\.(\w+)\s*\(\s*([^)]*?)\s*\)", connstr):
            pin, net = pm.group(1), pm.group(2).strip()
            if pin in conns:
                die(f"cell {instname}: duplicate connection for pin {pin}")
            if not net:
                die(f"cell {instname}: empty connection for pin {pin}")
            conns[pin] = net
        if celltype in CELLS:
            _, input_pins, output_pin = CELLS[celltype]
            required = set(input_pins) | {output_pin}
            allowed = required
        elif celltype in DFF_CELLS:
            pins = DFF_CELLS[celltype]
            required = {pins["D"], pins["CK"], pins["Q"]}
            allowed = required | ({pins["QN"]} if pins.get("QN") else set())
        else:
            pins = SCAN_DFF_CELLS[celltype]
            required = {pins["D"], pins["SE"], pins["SI"], pins["CK"],
                        pins["Q"]}
            allowed = required | ({pins["QN"]} if pins.get("QN") else set())
        missing = required - set(conns)
        extra = set(conns) - allowed
        if missing:
            die(f"cell {instname} ({celltype}): missing pins {sorted(missing)}")
        if extra:
            die(f"cell {instname} ({celltype}): unknown pins {sorted(extra)}")
        insts.append(Inst(celltype=celltype, name=instname, conns=conns))

    return Netlist(module=module_name, ports=ports, insts=insts)


# --------------------------------------------------------------------------- #
# Net expansion: a bus port `AxDI [1:0]` yields nets `AxDI[0]`, `AxDI[1]`.
# A single-bit port yields the bare name.  Bit order: LSB (index 0) first, so the
# annotation list `..._0,..._1` aligns to bits 0,1 (matches the hand gadgets).
# --------------------------------------------------------------------------- #
def bus_bits(port):
    if port.width == 1:
        return [port.name]
    return [f"{port.name}[{i}]" for i in range(port.width)]


def parse_silver_shares(silver):
    """`"[0:0]_0,[0:0]_1"` -> [(sharing, share), ...] in bit order.
    Sharing id = the number in `[k:k]`; share = the suffix after `_`."""
    out = []
    for entry in silver.split(","):
        entry = entry.strip()
        mm = re.fullmatch(r"\[\s*(\d+)\s*:\s*(\d+)\s*\]\s*_\s*(\d+)", entry)
        if not mm:
            die(f"cannot parse SILVER share entry {entry!r}")
        if mm.group(1) != mm.group(2):
            die(f"SILVER sharing range must be [k:k], got {entry!r}")
        sharing = int(mm.group(1))
        share = int(mm.group(3))
        out.append((sharing, share))
    return out


# --------------------------------------------------------------------------- #
# Lean gate model being built.
# --------------------------------------------------------------------------- #
@dataclass
class LeanGate:
    kind: str                     # e.g. ".and", ".xor", ".not", ".reg",
                                  # ".inp 0 1", ".rnd 0", ".const false"
    inputs: list = field(default_factory=list)   # list[(src_idx, latency)]
    member: bool = True           # False for internal expansion nodes
    label: str = ""               # human comment
    cyc: int = -1                 # scheduled cycle (filled by schedule())


@dataclass
class WitnessStep:
    """One ordered output in the Lean `SupportedCellExpansion` certificate."""
    gate: int
    kind: str                     # "root" | "combinational" | "scan"
    frontier_root: int | None = None
    celltype: str | None = None
    input_gates: list = field(default_factory=list)
    label: str = ""


NET_CONST = {"1'b0": ("const", False), "1'h0": ("const", False),
             "1'b1": ("const", True),  "1'h1": ("const", True),
             "1'd0": ("const", False), "1'd1": ("const", True)}


def build(nl):
    """Turn the neutral Netlist into a list[LeanGate] plus role maps.

    Returns dict with: gates, net_out (net -> gate idx), input_sharings (set of
    sharing ids), d, output_map (share -> net), rnd_ids (set), inp_gate (per
    (sharing,share) the gate idx), warnings (list of documented drops)."""
    gates = []
    net_out = {}        # net token -> index of the gate DRIVING it
    warnings = []
    witness_steps = []

    def emit(kind, inputs=None, member=True, label=""):
        gates.append(LeanGate(kind=kind, inputs=inputs or [],
                              member=member, label=label))
        return len(gates) - 1

    def witness_root(gate, frontier_root=None, label=""):
        witness_steps.append(WitnessStep(
            gate=gate, kind="root",
            frontier_root=gate if frontier_root is None else frontier_root,
            label=label))

    # ---- classify ports -----------------------------------------------------
    input_sharings = {}   # sharing id -> {share: net}
    output_map = {}       # share -> net (output sharing)
    output_sharings = set()
    rnd_ids = {}          # net -> rnd id
    clock_nets = set()
    d = None

    # An unannotated primary net used directly as a scan-enable pin is public
    # control, not fresh randomness.  Derived SE nets retain their real driver.
    scan_enable_nets = {
        inst.conns[SCAN_DFF_CELLS[inst.celltype]["SE"]]
        for inst in nl.insts if inst.celltype in SCAN_DFF_CELLS
    }
    control_ids = {}
    next_control = 0
    next_rnd = 0
    for p in nl.ports:
        if p.silver is None:
            # A port with no SILVER annotation on an *input* is, per SILVER's
            # convention, fresh randomness; on an output it is a plain output.
            if p.direction == "input":
                for net in bus_bits(p):
                    if net in scan_enable_nets:
                        control_ids[net] = next_control
                        next_control += 1
                    else:
                        rnd_ids[net] = next_rnd
                        next_rnd += 1
            continue
        s = p.silver.strip()
        if s == "clock":
            if p.direction != "input":
                die(f"clock annotation is only valid on an input, got {p.name}")
            clock_nets.update(bus_bits(p))
        elif s == "refresh":
            if p.direction != "input":
                die(f"refresh annotation is only valid on an input, got {p.name}")
            for net in bus_bits(p):
                rnd_ids[net] = next_rnd
                next_rnd += 1
        else:
            shares = parse_silver_shares(s)
            bits = bus_bits(p)
            if len(shares) != len(bits):
                die(f"port {p.name}: {len(shares)} share labels vs {len(bits)} bits")
            for net, (sharing, share) in zip(bits, shares):
                if p.direction == "input":
                    sharing_map = input_sharings.setdefault(sharing, {})
                    if share in sharing_map:
                        die(f"duplicate input share coordinate ({sharing}, {share})")
                    sharing_map[share] = net
                    d = max(d or 0, share + 1)
                else:  # output sharing
                    if share in output_map:
                        die(f"duplicate output share index {share}")
                    output_map[share] = net
                    output_sharings.add(sharing)
                    d = max(d or 0, share + 1)

    if not input_sharings:
        die("no input share annotations found")
    if not output_map:
        die("no output share annotation found")
    input_ids = sorted(input_sharings)
    if input_ids != list(range(len(input_ids))):
        die(f"input sharing ids must be contiguous from zero, got {input_ids}")
    expected_shares = set(range(d))
    for sharing, shares in input_sharings.items():
        if set(shares) != expected_shares:
            die(f"input sharing {sharing} must contain shares {sorted(expected_shares)}, "
                f"got {sorted(shares)}")
    if len(output_sharings) != 1:
        die(f"exactly one output sharing is supported, got {sorted(output_sharings)}")
    if set(output_map) != expected_shares:
        die(f"output must contain shares {sorted(expected_shares)}, "
            f"got {sorted(output_map)}")

    # Every structural net has at most one driver. Module outputs are sinks;
    # module inputs and cell output pins are drivers.
    drivers = {}
    def claim_driver(net, owner):
        if net in NET_CONST:
            die(f"{owner} attempts to drive constant token {net!r}")
        if net in drivers:
            die(f"net {net!r} has multiple drivers: {drivers[net]} and {owner}")
        drivers[net] = owner

    for p in nl.ports:
        if p.direction == "input":
            for net in bus_bits(p):
                claim_driver(net, f"input port {p.name}")
    for inst in nl.insts:
        if inst.celltype in CELLS:
            output_pins = [CELLS[inst.celltype][2]]
        elif inst.celltype in DFF_CELLS:
            pins = DFF_CELLS[inst.celltype]
            output_pins = [pins["Q"]]
            if pins.get("QN") and pins["QN"] in inst.conns:
                output_pins.append(pins["QN"])
        else:
            pins = SCAN_DFF_CELLS[inst.celltype]
            output_pins = [pins["Q"]]
            if pins.get("QN") and pins["QN"] in inst.conns:
                output_pins.append(pins["QN"])
        for pin in output_pins:
            claim_driver(inst.conns[pin], f"{inst.name}.{pin}")

    # ---- source gates -------------------------------------------------------
    inp_gate = {}
    for sharing in sorted(input_sharings):
        for share in sorted(input_sharings[sharing]):
            net = input_sharings[sharing][share]
            idx = emit(f".inp {sharing} {share}", label=f"{net} = inp {sharing} {share}")
            net_out[net] = idx
            inp_gate[(sharing, share)] = idx
            witness_root(idx, label=f"input {net}")
    for net, rid in rnd_ids.items():
        idx = emit(f".rnd {rid}", label=f"{net} = rnd {rid}")
        net_out[net] = idx
        witness_root(idx, label=f"randomness {net}")
    for net, cid in control_ids.items():
        idx = emit(f".ctl {cid}", label=f"{net} = ctl {cid}")
        net_out[net] = idx
        witness_root(idx, label=f"control {net}")

    # ---- constants (created lazily on demand) -------------------------------
    const_gate = {}
    def const_idx(val):
        if val not in const_gate:
            const_gate[val] = emit(f".const {'true' if val else 'false'}",
                                   label=f"const {val}")
            witness_root(const_gate[val], label=f"constant {val}")
        return const_gate[val]

    def net_index(tok):
        """Resolve a net TOKEN to a driving gate index (must already exist)."""
        if tok in NET_CONST:
            _, val = NET_CONST[tok]
            return const_idx(val)
        if tok not in net_out:
            die(f"net {tok!r} has no driver (undriven / mis-parsed)")
        return net_out[tok]

    # ---- pass A: reserve reg gates + QN nots (may be referenced early) -------
    regs = []   # (reg_idx, sampled-data net, instance)
    scan_regs = []  # (reg_idx, instance); mux inputs are patched after comb pass
    for inst in nl.insts:
        if inst.celltype not in DFF_CELLS and inst.celltype not in SCAN_DFF_CELLS:
            continue
        is_scan = inst.celltype in SCAN_DFF_CELLS
        pins = (SCAN_DFF_CELLS[inst.celltype] if is_scan
                else DFF_CELLS[inst.celltype])
        qnet = inst.conns[pins["Q"]]
        dnet = inst.conns[pins["D"]]
        cknet = inst.conns[pins["CK"]]
        if cknet not in clock_nets:
            die(f"{inst.celltype} {inst.name}: clock net {cknet!r} is not "
                "SILVER-annotated clock")
        sampled = f"mux({inst.conns[pins['SE']]}, {dnet}, " \
                  f"{inst.conns[pins['SI']]})" if is_scan else dnet
        reg_idx = emit(".reg", inputs=[(0, 1)], label=f"reg <- {sampled}")
        net_out[qnet] = reg_idx
        if is_scan:
            scan_regs.append((reg_idx, inst))
        else:
            regs.append((reg_idx, dnet, inst))
        witness_root(reg_idx, label=f"{inst.name}.Q")
        # QN: only materialize if the net is actually consumed somewhere.
        qn_pin = pins.get("QN")
        qnn = inst.conns.get(qn_pin) if qn_pin else None
        if qnn is not None and qnn not in NET_CONST:
            if net_consumed(nl, qnn):
                not_idx = emit(".not", inputs=[(reg_idx, 0)], label=f"QN of {inst.name}")
                net_out[qnn] = not_idx
                witness_root(not_idx, frontier_root=reg_idx,
                             label=f"{inst.name}.QN")
            else:
                warnings.append(f"dropped unused QN net {qnn!r} of "
                                f"{inst.celltype} {inst.name} "
                                f"(no fanout; unobservable duplicate of reg value)")

    # ---- pass B: combinational cells in topological order --------------------
    comb = [i for i in nl.insts if i.celltype in CELLS]
    ordered = toposort_comb(comb, net_out)

    for inst in ordered:
        func, in_pins, out_pin = CELLS[inst.celltype]
        outnet = inst.conns.get(out_pin)
        if outnet is None:
            die(f"cell {inst.name} ({inst.celltype}): missing output pin {out_pin}")
        innets = []
        for pin in in_pins:
            if pin not in inst.conns:
                die(f"cell {inst.name}: missing input pin {pin}")
            innets.append(inst.conns[pin])
        in_idx = [net_index(t) for t in innets]
        out_idx = expand_cell(func, in_idx, emit, inst.name)
        net_out[outnet] = out_idx
        witness_steps.append(WitnessStep(
            gate=out_idx, kind="combinational", celltype=inst.celltype,
            input_gates=list(in_idx), label=inst.name))

    # ---- pass C: scan sampled-data muxes ------------------------------------
    # Q roots were reserved above so sequential feedback is resolvable.  The
    # muxes are emitted only after ordinary combinational drivers, keeping every
    # latency-zero mux input earlier than the mux for ZeroOrdered witnesses.
    for reg_idx, inst in scan_regs:
        pins = SCAN_DFF_CELLS[inst.celltype]
        se_idx = net_index(inst.conns[pins["SE"]])
        d_idx = net_index(inst.conns[pins["D"]])
        si_idx = net_index(inst.conns[pins["SI"]])
        mux_idx = emit(".mux", [(se_idx, 0), (d_idx, 0), (si_idx, 0)],
                       label=f"scan mux of {inst.name}")
        gates[reg_idx].inputs = [(mux_idx, 1)]
        witness_steps.append(WitnessStep(
            gate=mux_idx, kind="scan", celltype=inst.celltype,
            input_gates=[se_idx, d_idx, si_idx], label=inst.name))

    # ---- patch reg D inputs -------------------------------------------------
    for reg_idx, dnet, inst in regs:
        gates[reg_idx].inputs = [(net_index(dnet), 1)]

    return {
        "gates": gates, "net_out": net_out, "input_sharings": input_sharings,
        "output_map": output_map, "rnd_ids": rnd_ids, "d": d,
        "inp_gate": inp_gate, "control_ids": control_ids, "warnings": warnings,
        "witness_steps": witness_steps,
    }


def net_consumed(nl, net):
    """True if `net` appears as an INPUT connection of any instance or is a
    module output port."""
    for p in nl.ports:
        if p.direction == "output" and net in bus_bits(p):
            return True
    for inst in nl.insts:
        # collect its output pins to exclude
        out_pins = set()
        if inst.celltype in CELLS:
            out_pins = {CELLS[inst.celltype][2]}
        elif inst.celltype in DFF_CELLS or inst.celltype in SCAN_DFF_CELLS:
            pins = (DFF_CELLS[inst.celltype]
                    if inst.celltype in DFF_CELLS
                    else SCAN_DFF_CELLS[inst.celltype])
            out_pins = {pins["Q"], pins.get("QN")}
        for pin, tok in inst.conns.items():
            if pin in out_pins:
                continue
            if tok == net:
                return True
    return False


def toposort_comb(comb, net_out_roots):
    """Order combinational cells so every input net is driven before use.
    Roots already resolved = keys of net_out_roots (inputs, rnd, reg Q/QN)."""
    resolved = set(net_out_roots)
    # map net -> producing comb inst
    producer = {}
    for inst in comb:
        _, _, out_pin = CELLS[inst.celltype]
        producer[inst.conns[out_pin]] = inst
    ordered = []
    placed = set()
    made_progress = True
    remaining = list(comb)
    guard = 0
    while remaining:
        guard += 1
        if guard > len(comb) + 5:
            die("combinational cycle detected (netlist not acyclic) — refusing")
        nxt = []
        progressed = False
        for inst in remaining:
            _, in_pins, _ = CELLS[inst.celltype]
            innets = [inst.conns[p] for p in in_pins]
            if all((t in resolved) or (t in NET_CONST) or (t in producer and
                    producer[t].conns[CELLS[producer[t].celltype][2]] in resolved
                    ) for t in innets):
                ordered.append(inst)
                resolved.add(inst.conns[CELLS[inst.celltype][2]])
                progressed = True
            else:
                nxt.append(inst)
        if not progressed:
            die("combinational cycle detected (no progress) — refusing")
        remaining = nxt
    return ordered


def expand_cell(func, in_idx, emit, name):
    """Emit primitive Lean gates for a combinational cell; return the OUTPUT gate
    index (the only member).  Internal gates are member=False."""
    if func == "and":
        return emit(".and", [(in_idx[0], 0), (in_idx[1], 0)], label=name)
    if func == "xor":
        return emit(".xor", [(in_idx[0], 0), (in_idx[1], 0)], label=name)
    if func == "not":
        return emit(".not", [(in_idx[0], 0)], label=name)
    if func == "buf":
        # identity as a single member gate: and(a,a) = a
        return emit(".and", [(in_idx[0], 0), (in_idx[0], 0)], label=name + " (buf)")
    if func == "nand":
        a = emit(".and", [(in_idx[0], 0), (in_idx[1], 0)], member=False,
                 label=name + " (nand internal and)")
        return emit(".not", [(a, 0)], label=name)
    if func == "xnor":
        x = emit(".xor", [(in_idx[0], 0), (in_idx[1], 0)], member=False,
                 label=name + " (xnor internal xor)")
        return emit(".not", [(x, 0)], label=name)
    if func == "nor":
        na = emit(".not", [(in_idx[0], 0)], member=False, label=name + " (nor !a)")
        nb = emit(".not", [(in_idx[1], 0)], member=False, label=name + " (nor !b)")
        return emit(".and", [(na, 0), (nb, 0)], label=name)  # nor = !a & !b
    if func == "or":
        na = emit(".not", [(in_idx[0], 0)], member=False, label=name + " (or !a)")
        nb = emit(".not", [(in_idx[1], 0)], member=False, label=name + " (or !b)")
        aa = emit(".and", [(na, 0), (nb, 0)], member=False, label=name + " (or !a&!b)")
        return emit(".not", [(aa, 0)], label=name)           # or = !(!a & !b)
    die(f"no expansion for cell function {func!r}")


# --------------------------------------------------------------------------- #
# Schedule: register-depth cycle for every gate.
# --------------------------------------------------------------------------- #
def schedule(gates, source_cycles=None):
    source_cycles = source_cycles or {}
    cyc = [None] * len(gates)
    visiting = [False] * len(gates)

    def resolve(i):
        if cyc[i] is not None:
            return cyc[i]
        if visiting[i]:
            die(f"sequential loop through gate {i} — schedule undefined")
        visiting[i] = True
        g = gates[i]
        if g.kind.startswith(".reg"):
            # reg output cycle = D-driver cycle + 1
            (src, _lat) = g.inputs[0]
            c = resolve(src) + 1
        elif g.inputs:
            c = max(resolve(src) for (src, _lat) in g.inputs)
        else:
            c = source_cycles.get(i, 0)   # source (inp/rnd/const)
        cyc[i] = c
        visiting[i] = False
        return c

    for i in range(len(gates)):
        resolve(i)
    for i, g in enumerate(gates):
        g.cyc = cyc[i]
    return cyc


def validate_schedule(gates):
    """Reject edges whose driver is not present at the consumer's read cycle.

    Lean inputs are fixed only at their declared arrival cycle; they are not
    implicitly stable afterward. Exact cycle alignment therefore prevents a
    mixed-arrival combinational cone from silently reading a pinned-false input.
    It also makes conservative membership closed under immediate predecessors.
    """
    for dst, gate in enumerate(gates):
        for src, latency in gate.inputs:
            # Public controls are evaluated at the consumer cycle and may be
            # reused across cycles.  Unlike inp/rnd, they have no single
            # declared arrival that must equal the consumer schedule.
            if gates[src].kind.startswith(".ctl"):
                continue
            expected = gates[src].cyc + latency
            if gate.cyc != expected:
                die(f"schedule mismatch on edge {src}->{dst}: source cycle "
                    f"{gates[src].cyc} + latency {latency} != destination "
                    f"cycle {gate.cyc}; mixed-arrival cones are unsupported")


# --------------------------------------------------------------------------- #
# Lean emission.
# --------------------------------------------------------------------------- #
def emit_lean(built, cyc, module, namespace, horizon_override, input_arrivals,
              conservative_members):
    gates = built["gates"]
    horizon = (horizon_override if horizon_override is not None
               else max(cyc) + 1)
    d = built["d"]
    input_sharings = built["input_sharings"]
    output_map = built["output_map"]
    inp_gate = built["inp_gate"]
    rnd_ids = built["rnd_ids"]
    input_count = len(input_sharings)

    # member: list of (gate, cyc) for member gates
    members = [(i, gates[i].cyc) for i in range(len(gates)) if gates[i].member]
    # group by cycle for a compact `member`
    by_cyc = {}
    for gi, c in members:
        by_cyc.setdefault(c, []).append(gi)

    lines = []
    L = lines.append
    L("import LeanSec.Gadget")
    L("")
    L(f"/-! GENERATED by tools/netlist2lean/netlist2lean.py from a SILVER-format")
    L(f"    NANG45 netlist (module `{module}`).  DO NOT EDIT BY HAND — regenerate.")
    L(f"    The proved object below is DERIVED from the netlist SILVER verifies,")
    L(f"    not hand-transcribed.  See LeanSec/Netlist/TRUST.md. -/")
    if conservative_members:
        L("/- Primitive expansion nodes are members: conservative vs SILVER cells. -/")
    L("")
    L(f"namespace {namespace}")
    L("")
    L("open LeanSec LeanSec.Gadget")
    L("")
    L("def circuit : Circuit :=")
    L("  { gates := #[")
    for i, g in enumerate(gates):
        ins = ", ".join(f"({s}, {l})" for (s, l) in g.inputs)
        comma = "," if i < len(gates) - 1 else ""
        tag = "" if g.member else "  -- internal (non-member)"
        L(f"      {{ kind := {g.kind}, inputs := [{ins}] }}{comma}"
          f"    -- {i}: {g.label}{tag}")
    L("    ] }")
    L("")
    # member function
    L("def member (n : Node) : Bool :=")
    conds = []
    for c in sorted(by_cyc):
        gs = sorted(by_cyc[c])
        lst = ", ".join(str(x) for x in gs)
        conds.append(f"  (n.cycle == {c} && [{lst}].contains n.gate)")
    L(" ||\n".join(conds))
    L("")
    # gadget
    L("def gadget : GadgetInstance :=")
    L("  { circuit := circuit")
    L(f"    horizon := {horizon}")
    L(f"    d := {d}")
    L(f"    inputCount := {input_count}")
    if all(arrival == 0 for arrival in input_arrivals.values()):
        L("    inputArrival := fun sharing share => .inp sharing share 0")
    else:
        L("    inputArrival := fun sharing share =>")
        for k, (sharing, arrival) in enumerate(sorted(input_arrivals.items())):
            if k == 0:
                L(f"      if sharing == {sharing} then .inp sharing share {arrival}")
            else:
                L(f"      else if sharing == {sharing} then .inp sharing share {arrival}")
        L("      else .inp sharing share 0")
    # output map
    outs = sorted(output_map)
    out_nodes = []
    for share in outs:
        net = output_map[share]
        gi = built["net_out"][net]
        out_nodes.append((share, gi, gates[gi].cyc))
    L("    output := fun share =>")
    if len(out_nodes) == 1:
        _share, gi, oc = out_nodes[0]
        L(f"      {{ gate := {gi}, cycle := {oc} }}")
    else:
        for k, (share, gi, oc) in enumerate(out_nodes):
            kw = "if" if k == 0 else "      else if"
            if k < len(out_nodes) - 1:
                L(f"      {kw} share == {share} then "
                  f"{{ gate := {gi}, cycle := {oc} }}")
            else:
                L(f"      else {{ gate := {gi}, cycle := {oc} }}")
    L("    member := member")
    # randomness: each rnd id at each cycle in [0, horizon)
    rset = sorted(set(rnd_ids.values()))
    rnd_list = ", ".join(f".rnd {r} {c}" for r in rset for c in range(horizon))
    L(f"    randomness := [{rnd_list}] }}")
    L("")
    L(f"end {namespace}")
    L("")
    return "\n".join(lines), horizon, members


def atomic_gates_for_witness(built):
    """Build the same-sized cell-granular circuit used by the capstone.

    Expansion-internal indices are inert constants.  Roots retain only the
    topology needed for their singleton frontier.  Every supported cell output
    directly consumes the preceding root/cell outputs named by the parsed
    wiring; the Boolean kind chosen for binary atomic cells is irrelevant to
    frontier semantics, so `.and` is used uniformly.
    """
    expanded = built["gates"]
    atomic = [LeanGate(kind=".const false", label="atomic placeholder")
              for _ in expanded]
    for step in built["witness_steps"]:
        if step.kind == "root":
            if step.frontier_root == step.gate:
                gate = expanded[step.gate]
                atomic[step.gate] = LeanGate(
                    kind=gate.kind, inputs=list(gate.inputs),
                    label=f"root: {step.label}")
            else:
                atomic[step.gate] = LeanGate(
                    kind=".not", inputs=[(step.frontier_root, 0)],
                    label=f"root alias: {step.label}")
            continue

        inputs = step.input_gates
        if step.kind == "scan":
            kind = ".mux"
            atomic_inputs = [(inputs[0], 0), (inputs[1], 0), (inputs[2], 0)]
        else:
            func = CELLS[step.celltype][0]
            if func == "not":
                kind, atomic_inputs = ".not", [(inputs[0], 0)]
            elif func == "buf":
                kind, atomic_inputs = ".and", [(inputs[0], 0), (inputs[0], 0)]
            else:
                kind = ".and"
                atomic_inputs = [(inputs[0], 0), (inputs[1], 0)]
        atomic[step.gate] = LeanGate(
            kind=kind, inputs=atomic_inputs,
            label=f"atomic {step.celltype}: {step.label}")
    return atomic


def nat_tail_pattern(depth):
    pattern = "n"
    for _ in range(depth):
        pattern = f".succ ({pattern})"
    return pattern


def emit_witness_lean(built, module, circuit_namespace, witness_namespace):
    """Emit the Lean re-validation certificate for one generated circuit."""
    steps = built["witness_steps"]
    outputs = [step.gate for step in steps]
    output_index = {gate: index for index, gate in enumerate(outputs)}
    if len(output_index) != len(outputs):
        die("internal witness error: duplicate root/cell-output gate")

    has_scan = any(step.kind == "scan" for step in steps)
    for index, step in enumerate(steps):
        if step.kind == "root":
            continue
        if step.kind == "combinational" and step.celltype not in CELL_LEAN_CTORS:
            die(f"internal witness error: no Lean cell for {step.celltype}")
        if step.kind == "scan" and step.celltype not in SCAN_DFF_LEAN_CTORS:
            die(f"internal witness error: no Lean scan cell for {step.celltype}")
        for driver in step.input_gates:
            if driver not in output_index:
                die(f"witness cell {step.label}: driver gate {driver} is not a "
                    "root or cell output")
            if output_index[driver] >= index:
                die(f"witness cell {step.label}: driver gate {driver} is not "
                    "earlier in the parsed output order")

    atomic = atomic_gates_for_witness(built)
    lines = []
    L = lines.append
    L(f"import {circuit_namespace}")
    if has_scan:
        L("import LeanSec.Netlist.ScanParserWitness")
    else:
        L("import LeanSec.Netlist.ParserWitness")
    L("")
    L(f"/-! GENERATED by tools/netlist2lean/netlist2lean.py from module `{module}`.")
    L("    This module re-validates the generated primitive circuit against the")
    L("    parser's explicit root/cell-output order and cell-granular wiring. -/")
    L("")
    L(f"namespace {witness_namespace}")
    L("")
    L("open LeanSec LeanSec.Expansion")
    L("open LeanSec.Netlist.CellRefinement")
    L("open LeanSec.Netlist.CircuitRefinementGeneric")
    L("open LeanSec.Netlist.CircuitRefinementClosed")
    L("open LeanSec.Netlist.ParserWitness")
    if has_scan:
        L("open LeanSec.Netlist.ScanCellRefinement")
        L("open LeanSec.Netlist.ScanParserWitness")
    L("")
    L("def atomicCircuit : Circuit :=")
    L("  { gates := #[")
    for i, gate in enumerate(atomic):
        inputs = ", ".join(f"({src}, {latency})"
                           for src, latency in gate.inputs)
        comma = "," if i < len(atomic) - 1 else ""
        L(f"      {{ kind := {gate.kind}, inputs := [{inputs}] }}{comma}"
          f"    -- {i}: {gate.label}")
    L("    ] }")
    L("")
    L("/-- Parsed roots and standard-cell outputs in dependency order. -/")
    L("def parsedOutputs : List Nat :=")
    L("  [" + ", ".join(str(gate) for gate in outputs) + "]")
    L("")
    L("set_option maxRecDepth 10000 in")
    L("set_option maxHeartbeats 8000000 in")
    L("/-- Kernel-checked re-validation of the generated circuit and cell wiring. -/")
    L("def supportedCellExpansion :")
    construction = ("SupportedScanCellExpansion" if has_scan
                    else "SupportedCellExpansion")
    L(f"    {construction} {circuit_namespace}.circuit atomicCircuit := by")
    L("  refine {")
    L("    outputs := parsedOutputs")
    L("    expandedZeroOrdered := zeroOrdered_of_finite (by")
    L(f"      unfold {circuit_namespace}.circuit")
    L("      decide)")
    L("    atomicZeroOrdered := zeroOrdered_of_finite (by")
    L("      unfold atomicCircuit")
    L("      decide)")
    L("    expandedOutputBound := outputBound_of_finite (by")
    L(f"      unfold {circuit_namespace}.circuit parsedOutputs")
    L("      decide)")
    L("    atomicOutputBound := outputBound_of_finite (by")
    L("      unfold atomicCircuit parsedOutputs")
    L("      decide)")
    L("    step := ?_ }")
    L("  intro index gate hgate")
    L("  exact match index with")
    # Fully concretizing frontier proof.  Used for the shapes on which the
    # single-spine `rw` walk is unsound as a tactic strategy: consumed-QN
    # root aliases (two frontier layers), BUF (the atomic side needs
    # `(x ++ x).eraseDups = x.eraseDups`, which only holds after
    # concretization), and OR/NOR expansions (their primitive trees have
    # SIBLING branches, and `rw [orderedFrontier]` only unfolds the leftmost
    # occurrence, walking one spine and leaving the sibling folded — a latent
    # bug flushed out by the first netlist to exercise these cells,
    # tools/netlist2lean/netlists/xor_refresh.v).  The `repeat` unfolds every
    # `orderedFrontier` occurrence on both sides to literal lists and `decide`
    # closes the residual concrete equality.
    def concretized_frontier_proof(circuit_name, close=")"):
        L("        (by")
        L(f"          repeat (rw [orderedFrontier]; try simp [{circuit_name}, "
          "SupportedCombCell.function])")
        L(f"          all_goals decide{close}")

    for index, step in enumerate(steps):
        L(f"  | {index} => by")
        L("      simp [parsedOutputs] at hgate")
        L("      subst gate")
        if step.kind == "root":
            L(f"      exact .root {step.frontier_root}")
            if step.frontier_root != step.gate:
                concretized_frontier_proof(f"{circuit_namespace}.circuit")
                concretized_frontier_proof("atomicCircuit")
            else:
                L("        (by")
                L("          rw [orderedFrontier]")
                L(f"          simp [{circuit_namespace}.circuit])")
                L("        (by")
                L("          rw [orderedFrontier]")
                L("          simp [atomicCircuit])")
        elif step.kind == "combinational":
            drivers = list(step.input_gates)
            if len(drivers) == 1:
                drivers.append(drivers[0])
            a_gate, b_gate = drivers
            a_index, b_index = output_index[a_gate], output_index[b_gate]
            ctor = CELL_LEAN_CTORS[step.celltype]
            L(f"      exact .combinational .{ctor}")
            L(f"        {a_index} {a_gate} {b_index} {b_gate}")
            L("        (by decide) (by decide)")
            L("        (by unfold parsedOutputs; decide)")
            L("        (by unfold parsedOutputs; decide)")
            func = CELLS[step.celltype][0]
            if func in ("or", "nor", "buf"):
                concretized_frontier_proof(f"{circuit_namespace}.circuit")
                concretized_frontier_proof("atomicCircuit")
            else:
                expansion_depth = {
                    "not": 1, "and": 1, "xor": 1,
                    "nand": 2, "xnor": 2,
                }[func]
                L("        (by")
                for depth in range(expansion_depth):
                    L("          rw [orderedFrontier]")
                    if depth + 1 < expansion_depth:
                        L(f"          simp [{circuit_namespace}.circuit]")
                    else:
                        if expansion_depth == 1:
                            L(f"          simp [{circuit_namespace}.circuit,")
                            L("            SupportedCombCell.function])")
                        else:
                            L("          simp [SupportedCombCell.function])")
                L("        (by")
                L("          rw [orderedFrontier]")
                L("          simp [atomicCircuit,")
                L("            SupportedCombCell.function])")
        else:
            se_gate, d_gate, si_gate = step.input_gates
            se_index = output_index[se_gate]
            d_index = output_index[d_gate]
            si_index = output_index[si_gate]
            ctor = SCAN_DFF_LEAN_CTORS[step.celltype]
            L(f"      exact .scanMux .{ctor}")
            L(f"        {se_index} {se_gate} {d_index} {d_gate} "
              f"{si_index} {si_gate}")
            L("        (by decide) (by decide) (by decide)")
            L("        (by unfold parsedOutputs; decide)")
            L("        (by unfold parsedOutputs; decide)")
            L("        (by unfold parsedOutputs; decide)")
            L("        (by")
            L("          rw [orderedFrontier]")
            L(f"          simp [{circuit_namespace}.circuit, scanMuxFrontier])")
            L("        (by")
            L("          rw [orderedFrontier]")
            L("          simp [atomicCircuit, scanMuxFrontier])")
    L(f"  | {nat_tail_pattern(len(steps))} => by simp [parsedOutputs] at hgate")
    L("")
    L("/-- The E4 capstone now applies to this exact generated circuit. -/")
    L("theorem parsedOutputs_frontier_refinement :")
    L("    ∀ (index gate : Nat), parsedOutputs[index]? = some gate →")
    L(f"      glitchGates {circuit_namespace}.circuit")
    L(f"          {circuit_namespace}.circuit.gates.size gate =")
    L("        glitchGates atomicCircuit atomicCircuit.gates.size gate := by")
    L("  simpa only [supportedCellExpansion] using")
    capstone = ("parser_scan_wholeCircuit_frontier_refinement" if has_scan
                else "parser_generic_wholeCircuit_frontier_refinement")
    L(f"    {capstone} supportedCellExpansion")
    L("")
    L(f"end {witness_namespace}")
    L("")
    return "\n".join(lines)


def parse_input_arrivals(specs, input_sharings):
    """Parse repeatable SHARING=CYCLE overrides, defaulting each sharing to 0."""
    arrivals = {sharing: 0 for sharing in input_sharings}
    seen = set()
    for spec in specs:
        mm = re.fullmatch(r"(\d+)=(\d+)", spec)
        if not mm:
            die(f"invalid --input-arrival {spec!r}; expected SHARING=CYCLE")
        sharing, cycle = int(mm.group(1)), int(mm.group(2))
        if sharing not in input_sharings:
            die(f"--input-arrival names unknown sharing {sharing}")
        if sharing in seen:
            die(f"duplicate --input-arrival for sharing {sharing}")
        seen.add(sharing)
        arrivals[sharing] = cycle
    return arrivals


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("netlist")
    ap.add_argument("--module", required=True)
    ap.add_argument("--namespace", required=True)
    ap.add_argument("--horizon", type=int, default=None,
                    help="override computed horizon (default: max reg-depth + 1)")
    ap.add_argument("--input-arrival", action="append", default=[],
                    metavar="SHARING=CYCLE",
                    help="arrival cycle for one input sharing (repeatable; default 0)")
    ap.add_argument("--conservative-members", action="store_true",
                    help="make primitive expansion nodes eligible probes (WF-closed)")
    ap.add_argument("--out", default=None)
    ap.add_argument("--witness-out", default=None,
                    help="also write a SupportedCellExpansion witness module")
    ap.add_argument("--witness-namespace", default=None,
                    help="namespace for --witness-out (required with it)")
    args = ap.parse_args()

    if bool(args.witness_out) != bool(args.witness_namespace):
        die("--witness-out and --witness-namespace must be supplied together")

    with open(args.netlist) as f:
        text = f.read()
    nl = parse_netlist(text, args.module)
    built = build(nl)
    if args.conservative_members:
        for gate in built["gates"]:
            gate.member = True
    input_arrivals = parse_input_arrivals(args.input_arrival,
                                          built["input_sharings"])
    source_cycles = {
        gate: input_arrivals[sharing]
        for (sharing, _share), gate in built["inp_gate"].items()
    }
    cyc = schedule(built["gates"], source_cycles)
    validate_schedule(built["gates"])
    lean, horizon, members = emit_lean(built, cyc, args.module, args.namespace,
                                       args.horizon, input_arrivals,
                                       args.conservative_members)
    witness_lean = None
    if args.witness_out:
        witness_lean = emit_witness_lean(
            built, args.module, args.namespace, args.witness_namespace)

    sys.stderr.write(f"netlist2lean: module={args.module} "
                     f"gates={len(built['gates'])} members={len(members)} "
                     f"horizon={horizon} d={built['d']} "
                     f"inputCount={len(built['input_sharings'])}\n")
    for w in built["warnings"]:
        sys.stderr.write(f"netlist2lean: NOTE: {w}\n")

    if args.out:
        with open(args.out, "w") as f:
            f.write(lean)
        sys.stderr.write(f"netlist2lean: wrote {args.out}\n")
    else:
        sys.stdout.write(lean)
    if args.witness_out:
        with open(args.witness_out, "w") as f:
            f.write(witness_lean)
        sys.stderr.write(f"netlist2lean: wrote {args.witness_out}\n")


if __name__ == "__main__":
    main()
