// z = (a + b) % (BigInt(2)^448-BigInt(2)^224-1)
module addmod(input [447:0] a,
	      input [447:0] b,
	      output [447:0] z);

   wire [448:0] zs;
   wire [448:0] zc;
   wire [448:0] sum;
   wire sel;

   csa csa0(.a(a), .b(b), .c({223'b0,1'b1,224'b0}),
	    .sum(zs), .cout(zc), .carry_in(1'b1));

   assign sum = zs + zc;
   assign z = (sum[448:448]) ? sum[447:0] : (a + b);
endmodule // addmod
