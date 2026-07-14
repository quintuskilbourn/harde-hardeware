#!/bin/bash
# Generate the EXACT SILVER-format NANG45 netlist for the single-bit DOM-AND,
# using the identical yosys flow as hpc2_silver_run.sh, then run SILVER.
set -uo pipefail
export PATH=~/sec-tools/oss-cad-suite/bin:$PATH
OV=~/sec-tools/work/openverify
SILVER=~/sec-tools/SILVER
SRCV=~/sec-tools/work/dom_and.v            # single-bit, already SILVER-annotated
W=$WORK/dom_silver; rm -rf "$W"; mkdir -p "$W"; cd "$W"
TOP=dom_and
source ~/sec-tools/oss-cad-suite/environment 2>/dev/null

SYN="$W/syn.v"; FIN="$W/fin.v"
yosys -q -p "read_verilog $SRCV; synth -top $TOP -flatten; \
  dfflibmap -liberty $OV/nangate45_pruned.lib; abc -g AND,NAND,OR,NOR,XOR,XNOR; \
  techmap -map $OV/gatemap.v; opt_clean -purge; write_verilog -noattr $SYN" 2>"$W/yosys.log" \
  || { echo "YOSYS FAIL"; tail -30 "$W/yosys.log"; exit 1; }

# Re-annotate SILVER attributes (single-bit dom_and port names)
sed -E \
 -e 's/^([[:space:]]*)input ClkxCI;/\1(* SILVER="clock" *) input ClkxCI;/' \
 -e 's/^([[:space:]]*)input \[1:0\] AxDI;/\1(* SILVER="[0:0]_0,[0:0]_1" *) input [1:0] AxDI;/' \
 -e 's/^([[:space:]]*)input \[1:0\] BxDI;/\1(* SILVER="[1:1]_0,[1:1]_1" *) input [1:0] BxDI;/' \
 -e 's/^([[:space:]]*)input ZxDI;/\1(* SILVER="refresh" *) input ZxDI;/' \
 -e 's/^([[:space:]]*)output \[1:0\] CxDO;/\1(* SILVER="[2:2]_0,[2:2]_1" *) output [1:0] CxDO;/' \
 "$SYN" | sed -E '/^[[:space:]]*wire (\[1:0\] )?(ClkxCI|AxDI|BxDI|ZxDI|CxDO);/d' > "$FIN"

echo "=== FIN.V (the artifact) ==="
cat "$FIN"
echo "=== SILVER VERDICT ==="
( cd "$SILVER"; LD_LIBRARY_PATH="$SILVER/lib" ./bin/verify --cores 4 --verbose 1 --verilog 1 \
   --verilog-libfile cell/Library.txt --verilog-libname NANG45 \
   --verilog-design_file "$FIN" --verilog-module_name "$TOP" ) 2>&1 \
   | sed 's/\x1b\[[0-9;]*m//g' | grep -iE "probe|PASS|FAIL|PINI|SNI|NI |uniform|error|gate|signal" | head -60
echo "=== DONE rc (139 after verdict = OK) ==="
