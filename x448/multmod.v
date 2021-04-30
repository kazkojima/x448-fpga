// Multiplication mod 2^448-2^224-1 implementation based on
//
//  Mehrabi, Ali & Doche, Christophe. (2019). Low-Cost, Low-Power FPGA
//  Implementation of ED25519 and CURVE25519 Point Multiplication.
//  Information. 10. 285. 10.3390/info10090285.

//`include "./csa.v"

`define P448 448'd726838724295606890549323807888004534353641360687318060281490199180612328166730772686396383698676545930088884461843637361053498018365439

// Input X, Y in 0:P-1
// Output Z in 0:P-1 where Z = X*Y mod P448
module multmod
  (input clk,
   input rst,
   input [447:0] X,
   input [447:0] Y,
   output reg [447:0] Z,
   input req_valid,
   output reg req_ready,
   output reg req_busy,
   output reg res_valid,
   input res_ready);

   wire [447:0] P;
   reg [2:0] lut1idx;
   reg [452:0] ms, mc;
   reg [452:0] s, c;
   wire [452:0] s1, c1, s2, c2, s3, c3, sn, cn;
   reg [233:0] l, n;
   reg [449:0] x;
   reg [448:0] z;
   wire [448:0] t;
   wire [450:0] sy7, cy7;
   wire [448:0] rs, rc;
   reg [7:0] k;
   reg [4:0] state;

   localparam S_IDLE = 1;
   localparam S_PRECOMP = 2;
   localparam S_PRECOMP_END = 3;
   localparam S_LOOP = 4;
   localparam S_REDUCE_STEP1 = 6;
   localparam S_REDUCE_STEP2 = 7;
   localparam S_REDUCE_STEP3 = 8;
   localparam S_REDUCE_STEP4 = 9;
   localparam S_POST = 10;

   assign P = `P448;

   csa #(.N(450)) y7(.a({ Y, 2'b0 }), .b({ 1'b0, Y, 1'b0 }), .c({ 2'b0, Y }),
		     .carry_in(1'b0), .sum(sy7), .cout(cy7));
   csa #(.N(448)) re(.a(s[447:0]), .b(c[447:0]), .c({ 214'b0, l[233:3] }),
		     .carry_in(1'b0), .sum(rs), .cout(rc));

   // Precomputed lut of i*8*(BigInt(2)^224+1) for i=0:23
   function [233:0] lut2(input [4:0] addr);
      lut2 = { addr, 219'b0, addr, 3'b0 };
   endfunction

   // Carry save form of i*Y for i in 0:7
   always @(posedge clk) begin
      if (lut1idx[2:0] == 0) begin
	 ms <= 0;
	 mc <= 0;
      end
      else if (lut1idx[2:0] == 1) begin
	 ms <= Y;
	 mc <= 0;
      end
      else if (lut1idx[2:0] == 2) begin
	 ms <= { Y, 1'b0 };
	 mc <= 0;
      end
      else if (lut1idx[2:0] == 3) begin
	 ms <= { Y, 1'b0 };
	 mc <= Y;
      end
      else if (lut1idx[2:0] == 4) begin
	 ms <= { Y, 2'b0 };
	 mc <= 0;
      end
      else if (lut1idx[2:0] == 5) begin
	 ms <= { Y, 2'b0 };
	 mc <= Y;
      end
      else if (lut1idx[2:0] == 6) begin
	 ms <= { Y, 2'b0 };
	 mc <= { Y, 1'b0 };
      end
      else if (lut1idx[2:0] == 7) begin
	 ms <= sy7;
	 mc <= cy7;
      end
   end

   assign s1 = { s[447:0], 3'b0 };
   assign c1 = { c[447:0], 3'b0 };
   assign s2 = (s1 ^ ms) ^ c1;
   assign c2 = { ((s1 & ms) | (s1 & c1) | (ms & c1)), 1'b0 };
   assign s3 = (s2 ^ mc) ^ c2;
   assign c3 = { ((s2 & mc) | (s2 & c2) | (mc & c2)), 1'b0 };
   assign sn = { s3[452:234], (s3[233:0] ^ n) } ^ c3;
   assign cn = { ((s3[233:0] & n) | (s3 & c3) | (n & c3[233:0])), 1'b0 };
   assign t = z + { 1'b1, 223'b0, 1'b1 };
/*
   always @* begin
      if (state == S_LOOP) begin
	 s1 = { s[447:0], 3'b0 };
	 c1 = { c[447:0], 3'b0 };
	 s2 = (s1 ^ ms) ^ c1;
	 c2 = { ((s1 & ms) | (s1 & c1) | (ms & c1)), 1'b0 };
         s3 = (s2 ^ mc) ^ c2;
         c3 = { ((s2 & mc) | (s2 & c2) | (mc & c2)), 1'b0 };
         sn = { s3[452:234], (s3[233:0] ^ n) } ^ c3;
         cn = { ((s3[233:0] & n) | (s3 & c3) | (n & c3[233:0])), 1'b0 };
      end // if (state == S_LOOP)
      else if (state == S_REDUCE_STEP4) begin
	 t = z + { 1'b1, 223'b0, 1'b1 };
      end
   end
*/

   always @(posedge clk) begin
      if (rst) begin
	 state <= S_IDLE;
	 req_ready <= 0;
	 res_valid <= 0;
	 req_busy <= 0;
      end
      else begin
	 if (state == S_IDLE) begin
	    if (req_valid == 1'b1) begin
	       req_ready <= 1;
	       req_busy <= 1;
	       x <= X;
	       s <= 0;
	       c <= 0;
	       n <= 0;
	       lut1idx <= 0;
	       state <= S_PRECOMP;
	    end
	 end
	 else if (state == S_PRECOMP) begin
	    req_ready <= 0;
	    // for k = 150
	    lut1idx <= x[449:447];
	    x <= { x[446:0], 3'b0 };
	    state <= S_PRECOMP_END;
	 end // if (state == S_PRECOMP)
	 else if (state == S_PRECOMP_END) begin
	    k <= 150;
	    lut1idx <= x[449:447];
	    x <= { x[446:0], 3'b0 };
	    state <= S_LOOP;
	 end
	 else if (state == S_LOOP) begin
	    //$display("k %d s %d c %d\n s1+c1 %d\n s2+c1 %d\n s3+c3", k, sn, cn, sn+cn, s1+c1, s2+c2, s3+c3);
	    s <= sn;
	    c <= cn;
	    n <= lut2(sn[451:448] + cn[451:448]);
	    lut1idx <= x[449:447];
	    x <= { x[446:0], 3'b0 };
	    k <= k - 1;
	    state <= (k == 1) ? S_REDUCE_STEP1 : S_LOOP;
	 end // if (state == S_LOOP)
	 else if (state == S_REDUCE_STEP1) begin
	    //$display("reduce step1: s %d c %d n %d", s, c, n);
	    l <= lut2(s[451:448] + c[451:448]);
	    state <= S_REDUCE_STEP2;
	 end
	 else if (state == S_REDUCE_STEP2) begin
	    //$display("reduce step2: rs %d rc %d n %d", rs, rc, n);
	    s <= rs;
	    c <= rc;
	    l <= lut2(rs[448:448] + rc[448:448]);
	    state <= S_REDUCE_STEP3;
	 end
	 else if (state == S_REDUCE_STEP3) begin
	    //$display("reduce step3: rs %d rc %d", rs, rc);
	    z <= rs + rc;
	    state <= S_REDUCE_STEP4;
	 end
	 else if (state == S_REDUCE_STEP4) begin
	    Z <= (t[448:448]) ? t[447:0] : z[447:0];
	    res_valid <= 1;
	    req_busy <= 0;
	    state <= S_POST;
	 end
	 else if (state == S_POST) begin
	    if (res_ready == 1'b1) begin
	       res_valid <= 0;
	       state <= S_IDLE;
	    end
	 end
      end   
   end
endmodule // multmod
