in 0 0_0 # x[0]
in 1 0_1 # x[1]
in 2 1_0 # y[0]
in 3 1_1 # y[1]
ref 4 # r01 = r10
reg 4 # reg[r01]
and 0 5 # x0 * reg[r01]
xor 6 5 # not(x0) * reg[r01]
xor 3 4 # y1 + r01
and 1 5 # x1 * reg[r01]
xor 9 5 # not(x1) * reg[r01]
xor 2 4 # y0 + r01
reg 2 # reg[y0]
reg 3 # reg[y1]
reg 7 # reg[u01]
reg 8 # reg[v01]
reg 10 # reg[u10]
reg 11 # reg[v10]
and 0 12 # x0 * reg[y0]
reg 18 # reg[x0 * reg[y0]]
and 0 15 # x0 * reg[v01]
reg 20 # reg[x0 * reg[v01]]
and 1 13 # x1 * reg[y1]
reg 22 # reg[x1 * reg[y1]]
and 1 17 # x1 * reg[v10]
reg 24 # reg[x1 * reg[v10]]
xor 19 14
xor 26 21 # z0
xor 23 16
xor 28 25 # z1
out 27 2_0 # z[0]
out 29 2_1 # z[1]
