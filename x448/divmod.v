// Division in GF(2^448-2^224-1) to test multmod and invmod_M.

`define P448 448'd726838724295606890549323807888004534353641360687318060281490199180612328166730772686396383698676545930088884461843637361053498018365439

module divmod(input clk,
	      input rst,
	      input [447:0] x,
	      input [447:0] y,
	      output reg [447:0] z,
	      input req_valid,
	      output reg req_ready,
	      output reg req_busy,
	      output reg res_valid,
	      input res_ready);

   reg [447:0] op_in_1, op_in_2;
   wire [447:0] mul_out;
   wire mul_req_ready;
   wire mul_req_busy;
   wire mul_res_valid;
   reg mul_req_valid;
   reg mul_res_ready;
   reg [447:0] ri;
   wire [447:0] inv_in;
   wire [447:0] inv_out;
   wire inv_req_ready;
   wire inv_req_busy;
   wire inv_res_valid;
   reg inv_req_valid;
   reg inv_res_ready;

   multmod mul0(.clk(clk), .rst(rst),
		.X(op_in_1), .Y(op_in_2), .Z(mul_out),
		.req_valid(mul_req_valid),
		.req_ready(mul_req_ready),
		.req_busy(mul_req_busy),
		.res_valid(mul_res_valid),
		.res_ready(mul_res_ready));
   inv_montgomery #(.N(448)) inv0
     (.clk(clk), .rst(rst),
      .X(inv_in), .M(`P448), .R(inv_out), .real_inverse(1'b1),
      .req_valid(inv_req_valid),
      .req_ready(inv_req_ready),
      .req_busy(inv_req_busy),
      .res_valid(inv_res_valid),
      .res_ready(inv_res_ready));

   reg [4:0] state;
   reg [1:0] op_state;
   reg [1:0] m_state;

   localparam O_INIT = 0;
   localparam O_ARG1 = 1;
   localparam O_ARG2 = 2;
   localparam O_OK = 3;

   localparam M_INIT = 1;
   localparam M_WAIT = 2;

   localparam S_IDLE = 1;
   localparam S_INV_M = 2;
   localparam S_MULT = 3;
   localparam S_POST = 23;

   assign inv_in = y;
   
   always @(posedge clk) begin
      if (rst) begin
	 state <= S_IDLE;
	 op_state <= O_INIT;
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
	    state <= S_INV_M;
	 end
      end
      else if (state == S_POST) begin
	 if (res_ready) begin
	    res_valid <= 0;
	    state <= S_IDLE;
	 end
      end
      else if (op_state != O_OK) begin
	 if (state == S_INV_M) begin
	    req_ready <= 0;
	    op_state <= O_OK;
	 end
	 else if (state == S_MULT) begin
	    op_in_1 <= x;
	    op_in_2 <= ri;
	    op_state <= O_OK;
	 end
      end
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
	       state <= S_MULT;
	    end
	 end
      end // if (state == S_INV_M)
      else if (state == S_MULT) begin
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
	       z <= mul_out;
	       mul_res_ready <= 1;
	       m_state <= M_INIT;
	       res_valid <= 1;
	       req_busy <= 0;
	       op_state <= O_INIT;
	       state <= S_POST;
	    end
	 end
      end // if (state == S_NRM_X)
   end // always @ (posedge clk)

endmodule // divmod_point_add

