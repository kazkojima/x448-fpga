// Point add implementation on curve448 based on
//
//  Hisil, Hüseyin & Wong, Kenneth & Carter, Gary & Dawson, Ed. (2008).
//  Twisted Edwards Curves Revisited. Lect. Notes Comput. Sci.. 5350. 326-343.
//  10.1007/978-3-540-89255-7_20.

`define P448 448'd726838724295606890549323807888004534353641360687318060281490199180612328166730772686396383698676545930088884461843637361053498018365439
`define K448 448'd726838724295606890549323807888004534353641360687318060281490199180612328166730772686396383698676545930088884461843637361053498018326358

// Point addition on 448 curve
module point_add(input clk,
		 input rst,
		 input [447:0] x1,
		 input [447:0] y1,
		 input [447:0] t1,
		 input [447:0] z1,
		 input [447:0] x2,
		 input [447:0] y2,
		 input [447:0] t2,
		 input [447:0] z2,
		 output reg [447:0] x3,
		 output reg [447:0] y3,
		 output reg [447:0] t3,
		 output reg [447:0] z3,
		 input affine,
		 input req_valid,
		 output reg req_ready,
		 output reg req_busy,
		 output reg res_valid,
		 input res_ready);

   reg [447:0] op_in_1, op_in_2;
   wire [447:0] add_out;
   wire [447:0] sub_out;
   wire [447:0] mul_out;
   wire mul_req_ready;
   wire mul_req_busy;
   wire mul_res_valid;
   reg mul_req_valid;
   reg mul_res_ready;
   wire [447:0] inv_in;
   wire [447:0] inv_out;
   wire inv_req_ready;
   wire inv_req_busy;
   wire inv_res_valid;
   reg inv_req_valid;
   reg inv_res_ready;
   wire [447:0] P, k;

   assign P = `P448;
   assign k = `K448;

   addmod add0(.a(op_in_1), .b(op_in_2), .z(add_out));
   submod sub0(.a(op_in_1), .b(op_in_2), .z(sub_out));
   multmod mul0(.clk(clk), .rst(rst),
		.X(op_in_1), .Y(op_in_2), .Z(mul_out),
		.req_valid(mul_req_valid),
		.req_ready(mul_req_ready),
		.req_busy(mul_req_busy),
		.res_valid(mul_res_valid),
		.res_ready(mul_res_ready));
   inv_montgomery #(.N(448)) inv0
     (.clk(clk), .rst(rst),
      .X(inv_in), .M(P), .R(inv_out), .real_inverse(1'b1),
      .req_valid(inv_req_valid),
      .req_ready(inv_req_ready),
      .req_busy(inv_req_busy),
      .res_valid(inv_res_valid),
      .res_ready(inv_res_ready));
   
   reg [447:0] a, b, c, d, e, f, g, h, ri;
   // e=r1, f=r2, g=r3, h=r4, i=ri

   reg [4:0] state;
   reg [1:0] m_state;
   reg [1:0] op_state;

   localparam S_IDLE = 0;
   localparam S_ACK = 1;
   localparam S_MUL_a = 2;
   localparam S_MUL_b = 3;
   localparam S_MUL_c = 4;
   localparam S_MUL_k = 5;
   localparam S_MUL_d = 6;
   localparam S_ADD_1 = 7;
   localparam S_ADD_2 = 8;
   localparam S_ADD_3 = 9;
   localparam S_MUL_4 = 10;
   localparam S_SUB_e = 11;
   localparam S_SUB_f = 12;
   localparam S_ADD_g = 13;
   localparam S_SUB_h = 14;
   localparam S_MUL_x = 15;
   localparam S_MUL_y = 16;
   localparam S_MUL_t = 17;
   localparam S_MUL_z = 18;
   localparam S_INV_M = 19;
   localparam S_NRM_X = 20;
   localparam S_NRM_Y = 21;
   localparam S_NRM_T = 22;
   localparam S_POST = 23;

   localparam O_INIT = 0;
   localparam O_OK = 1;

   localparam M_INIT = 1;
   localparam M_WAIT = 2;

   assign inv_in = z3;

   always @(posedge clk) begin
      if (rst) begin
	 state <= S_IDLE;
	 mul_res_ready <= 0;
	 mul_req_valid <= 0;
	 inv_res_ready <= 0;
	 inv_req_valid <= 0;
	 m_state <= M_INIT;
	 req_ready <= 0;
	 res_valid <= 0;
	 req_busy <= 0;
      end // if (rst)
      else if (state == S_IDLE) begin
	 if (req_valid) begin
	    req_ready <= 1;
	    req_busy <= 1;
	    state <= S_ACK;
	 end
      end
      else if (state == S_ACK) begin
	 req_ready <= 0;
	 state <= S_MUL_a;
	 op_state <= O_INIT;
      end
      else if (state == S_POST) begin
	 if (res_ready) begin
	    res_valid <= 0;
	    state <= S_IDLE;
	 end
      end
      else if (op_state != O_OK) begin
	 if (state == S_MUL_a) begin
	    op_in_1 <= x1;
	    op_in_2 <= x2;
	 end
	 else if (state == S_MUL_b) begin
	    op_in_1 <= y1;
	    op_in_2 <= y2;
	 end
	 else if (state == S_MUL_c) begin
	    op_in_1 <= t1;
	    op_in_2 <= t2;
	 end
	 else if (state == S_MUL_k) begin
	    op_in_1 <= k;
	    op_in_2 <= c;
	 end
	 else if (state == S_MUL_d) begin
	    op_in_1 <= z1;
	    op_in_2 <= z2;
	 end
	 else if (state == S_ADD_1) begin
	    op_in_1 <= x1;
	    op_in_2 <= y1;
	 end
	 else if (state == S_ADD_2) begin
	    op_in_1 <= x2;
	    op_in_2 <= y2;
	 end
	 else if (state == S_ADD_3) begin
	    op_in_1 <= a;
	    op_in_2 <= b;
	 end
	 else if (state == S_MUL_4) begin
	    op_in_1 <= e;
	    op_in_2 <= f;
	 end
	 else if (state == S_SUB_e) begin
	    op_in_1 <= h;
	    op_in_2 <= g;
	 end
	 else if (state == S_SUB_f | state == S_ADD_g) begin
	    op_in_1 <= d;
	    op_in_2 <= c;
	 end
	 else if (state == S_SUB_h) begin
	    op_in_1 <= b;
	    op_in_2 <= a;
	 end
	 else if (state == S_MUL_x) begin
	    op_in_1 <= e;
	    op_in_2 <= f;
	 end
	 else if (state == S_MUL_y) begin
	    op_in_1 <= g;
	    op_in_2 <= h;
	 end
	 else if (state == S_MUL_t) begin
	    op_in_1 <= e;
	    op_in_2 <= h;
	 end
	 else if (state == S_MUL_z) begin
	    op_in_1 <= f;
	    op_in_2 <= g;
	 end
	 else if (state == S_NRM_X) begin
	    op_in_1 <= x3;
	    op_in_2 <= ri;
	 end
	 else if (state == S_NRM_Y) begin
	    op_in_1 <= y3;
	    // op_in_2 is already set to inv.
	 end
	 else if (state == S_NRM_T) begin
	    op_in_1 <= x3;
	    op_in_2 <= y3;
	 end
	 op_state <= O_OK;
      end // if (op_state != O_OK)
      else if (state == S_MUL_a) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("a %d", mul_out);
	       a <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_MUL_b;
	    end
	 end
      end // if (state == S_MUL_a)
      else if (state == S_MUL_b) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("b %d", mul_out);
	       b <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_MUL_c;
	    end
	 end
      end // if (state == S_MUL_b)
      else if (state == S_MUL_c) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("c %d", mul_out);
	       c <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_MUL_k;
	    end
	 end
      end // if (state == S_MUL_c)
      else if (state == S_MUL_k) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("c=c*k %d", mul_out);
	       c <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_MUL_d;
	    end
	 end
      end // if (state == S_MUL_k)
      else if (state == S_MUL_d) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("d %d", mul_out);
	       d <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_ADD_1;
	    end
	 end
      end // if (state == S_MUL_d)
      else if (state == S_ADD_1) begin
	 //$display("r1 %d", add_out);
	 e <= add_out;
	 op_state <= O_INIT;
	 state <= S_ADD_2;
      end
      else if (state == S_ADD_2) begin
	 //$display("r2 %d", add_out);
	 f <= add_out;
	 op_state <= O_INIT;
	 state <= S_ADD_3;
      end
      else if (state == S_ADD_3) begin
	 //$display("r3 %d", add_out);
	 g <= add_out;
	 op_state <= O_INIT;
	 state <= S_MUL_4;
      end
      else if (state == S_MUL_4) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("r4 %d", mul_out);
	       h <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_SUB_e;
	    end
	 end
      end // if (state == S_MUL_4)
      else if (state == S_SUB_e) begin
	 //$display("e %d", sub_out);
	 e <= sub_out;
	 op_state <= O_INIT;
	 state <= S_SUB_f;
      end
      else if (state == S_SUB_f) begin
	 //$display("f %d", sub_out);
	 f <= sub_out;
	 op_state <= O_INIT;
	 state <= S_ADD_g;
      end
      else if (state == S_ADD_g) begin
	 //$display("g %d", add_out);
	 g <= add_out;
	 op_state <= O_INIT;
	 state <= S_SUB_h;
      end
      else if (state == S_SUB_h) begin
	 //$display("h %d", sub_out);
	 h <= sub_out;
	 op_state <= O_INIT;
	 state <= S_MUL_x;
      end
      else if (state == S_MUL_x) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("x3 %d", mul_out);
	       x3 <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_MUL_y;
	    end
	 end
      end // if (state == S_MUL_x)
      else if (state == S_MUL_y) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("y3 %d", mul_out);
	       y3 <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_MUL_t;
	    end
	 end
      end // if (state == S_MUL_y)
      else if (state == S_MUL_t) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("t3 %d", mul_out);
	       t3 <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_MUL_z;
	    end
	 end
      end // if (state == S_MUL_t)
      else if (state == S_MUL_z) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       //$display("z3 %d", mul_out);
	       z3 <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       if (!affine) begin
		  res_valid <= 1;
		  req_busy <= 0;
		  op_state <= O_INIT;
		  state <= S_POST;
	       end
	       else begin
		  state <= S_INV_M;
	       end
	    end
	 end
      end // if (state == S_MUL_z)
      else if (state == S_INV_M) begin
	 if (m_state == M_INIT) begin
	    inv_res_ready <= 0;
	    inv_req_valid <= 1;
	    if (inv_req_ready) begin
	       inv_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!inv_req_busy & inv_res_valid) begin
	       ri <= inv_out;
	       inv_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_NRM_X;
	    end
	 end
      end // if (state == S_INV_M)
      else if (state == S_NRM_X) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       x3 <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       op_state <= O_INIT;
	       state <= S_NRM_Y;
	    end
	 end
      end
      else if (state == S_NRM_Y) begin
	 if (m_state == M_INIT) begin
	    mul_res_ready <= 0;
	    mul_req_valid <= 1;
	    if (mul_req_ready) begin
	       mul_req_valid <= 0;
	       m_state <= M_WAIT;
	    end
	 end
	 else if (m_state == M_WAIT) begin
	    if (!mul_req_busy & mul_res_valid) begin
	       y3 <= mul_out;
               mul_res_ready <= 1;
               m_state <= M_INIT;
               op_state <= O_INIT;
               state <= S_NRM_T;
            end
         end
      end // if (state == S_NRM_Y)
      else if (state == S_NRM_T) begin
         if (m_state == M_INIT) begin
            mul_res_ready <= 0;
            mul_req_valid <= 1;
            if (mul_req_ready) begin
               mul_req_valid <= 0;
               m_state <= M_WAIT;
            end
         end
         else if (m_state == M_WAIT) begin
            if (!mul_req_busy & mul_res_valid) begin
               t3 <= mul_out;
	       z3 <= 448'd1;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       res_valid <= 1;
	       req_busy <= 0;
	       op_state <= O_INIT;
	       state <= S_POST;
	    end
	 end
      end // if (state == S_NRM_T)
   end // always @ (posedge clk)

endmodule
