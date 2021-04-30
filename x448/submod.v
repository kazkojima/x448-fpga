`define P448 448'd726838724295606890549323807888004534353641360687318060281490199180612328166730772686396383698676545930088884461843637361053498018365439

// t = (a - b) % (BigInt(2)^448-BigInt(2)^224-1)
// return (t < 0) ? t + (BigInt(2)^448-BigInt(2)^224-1) : t
module submod(input [447:0] a,
	      input [447:0] b,
	      output [447:0] z);

   wire [448:0] zs;
   wire [448:0] zc;
   wire [448:0] ws;
   wire [448:0] wc;
   wire [448:0] sum, alt;
   wire sel;

   csa csa0(.a(a), .b(~b), .c(448'd0), .sum(zs), .cout(zc), .carry_in(1'b0));
   csa csa1(.a(a), .b(~b), .c(`P448), .sum(ws), .cout(wc), .carry_in(1'b0));

   assign sum = zs + zc + 1;
   assign alt = ws + wc + 1;
   assign z = (sum[448:448]) ? sum[447:0] : alt[447:0];

endmodule // submod
