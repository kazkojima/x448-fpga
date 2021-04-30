# An FPGA implementation of some x448 operations

This is my trial of a verilog implementation of some operations on curve448. See references below for each algorithm/implementation.

* add/sub/multiplication on GF(2^448-2^224-1). [4]
* Montgomery modular inverse. [2]
* Point addition on the twisted Edwards curve - curve448. [3]
* Scalar multiplication on the standard base point.

The target FPGA is ECP5-85G and yosys/nextpnr-ecp5 open software developing system is assumed. All operations except scalar multiplication with a given base point are tested successfully on the real chip with 36Mhz clock.

The routing of the scalar multiplication circuit takes ~40 hours on my PC :-(

scalarmult.v is a simple implementation of the scalar multiplication with a given base point, though its routing doesn't end successfully yet.


## Not secure

There are almost no countermeasures implemented against well-known attacks. See the references for them.

## Performance

Testbench shows ~4740 cycles are needed to complete a point addition and ~189680 cycles for a scalar multiplication on the standard base point of which x-cordinate is -\sqrt{5}/3 (0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa955555555555555555555555555555555555555555555555555555555).

## Device utilisation for scalar multiplication on the standard base point

```
Info: 	       TRELLIS_SLICE: 30458/41820    72%
Info: 	          TRELLIS_IO:    13/  365     3%
Info: 	                DCCA:     1/   56     1%
Info: 	              DP16KD:   150/  208    72%
Info: 	          MULT18X18D:     0/  156     0%
Info: 	              ALU54B:     0/   78     0%
Info: 	             EHXPLLL:     1/    4    25%
```

## x448.jl

jl/x448.jl is a collection of Julia functions written to help I understand each algorithm and verify the results of its execution on the FPGA counterpart. gen_precomp_448() generates precomputed data files [xyt]_precomp_448.dat which is a tabel of kB where B is the standard base point
```
 (484559149530404593699549205258669689569094240458212040187660132787056912146709081364401144455726350866276831544947397859048262938744149,
  494088759867433727674302672526735089350544552303727723746126484473087719117037293890093462157703888342865036477787453078312060500281069)
```
where k = i*16^j for i in 0:15, j in 0:111. For example, the 3+5*16-th line of x_precomp_448.dat is (3*16^5)B.

## References

[1] Bernstein, Daniel & Duif, Niels & Lange, Tanja & Schwabe, Peter & Yang,
  Bo-Yin. (2011). High-Speed High-Security Signatures.
  Journal of Cryptographic Engineering. 2. 124-142.
  10.1007/978-3-642-23951-9_9.

[2] Dormale, G.M. & Bulens, P. & Quisquater, Jean-Jacques. (2005).
  An improved Montgomery modular inversion targeted for efficient
  implementation on FPGA. 441 - 444. 10.1109/FPT.2004.1393320. 

[3]  Hisil, Hüseyin & Wong, Kenneth & Carter, Gary & Dawson, Ed. (2008).
  Twisted Edwards Curves Revisited. Lect. Notes Comput. Sci.. 5350. 326-343.
  10.1007/978-3-540-89255-7_20.

[4] Mehrabi, Ali & Doche, Christophe. (2019). Low-Cost, Low-Power FPGA
  Implementation of ED25519 and CURVE25519 Point Multiplication.
  Information. 10. 285. 10.3390/info10090285.

[5] Turan, Furkan & Verbauwhede, Ingrid. (2019). Compact and flexible FPGA
  implementation of ED25519 and X25519. ACM Transactions on Embedded
  Computing Systems. 18. 1-21. 10.1145/3312742.
