// Scalar multiplication on curve448 for the given base point.

// scalar multiplication with the given base point
// Assume that the MSB of K is 1.
module scalarmult(input clk,
		  input rst,
		  input [447:0] K,
		  input [447:0] bx,
		  input [447:0] by,
		  input [447:0] bt,
		  input [447:0] bz,
		  output reg [447:0] px,
		  output reg [447:0] py,
		  output reg [447:0] pt,
		  output reg [447:0] pz,
		  input affine,
		  input req_valid,
		  output reg req_ready,
		  output reg req_busy,
		  output reg res_valid,
		  input res_ready);

   reg [447:0] qx, qy, qt, qz, k;
   wire [447:0] x1, y1, t1, z1, x2, y2, t2, z2;
   wire [447:0] x3, y3, t3, z3;
   wire	pt_req_ready;
   wire pt_req_busy;
   wire pt_res_valid;
   reg pt_req_valid;
   reg pt_res_ready;
   reg pt_affine;

   point_add padd0(.clk(clk), .rst(rst),
		   .x1(x1), .y1(y1), .t1(t1), .z1(z1),
		   .x2(x2), .y2(y2), .t2(t2), .z2(z2),
		   .x3(x3), .y3(y3), .t3(t3), .z3(z3),
		   .affine(pt_affine),
		   .req_valid(pt_req_valid),
		   .req_ready(pt_req_ready),
		   .req_busy(pt_req_busy),
		   .res_valid(pt_res_valid),
		   .res_ready(pt_res_ready));

   reg [8:0] i;
   reg [3:0] state;

   localparam N = 448;

   localparam S_IDLE = 1;
   localparam S_PRELOAD_STEP1 = 2;
   localparam S_PRELOAD_STEP2 = 3;
   localparam S_LOOP_STEP1 = 4;
   localparam S_LOOP_STEP2 = 5;
   localparam S_LOOP_STEP3 = 6;
   localparam S_LOOP_STEP4 = 7;
   localparam S_LOOP_STEP5 = 8;
   localparam S_POST = 9;

   wire kbit;
   wire sel0, sel1;

   assign kbit = k[N-2];
   assign sel0 = (state == S_LOOP_STEP4 | state == S_LOOP_STEP5) & (kbit == 0);
   assign sel1 = (state == S_LOOP_STEP4 | state == S_LOOP_STEP5) & (kbit == 1);
   assign x1 = sel1 ? qx : px;
   assign y1 = sel1 ? qy : py;
   assign t1 = sel1 ? qt : pt;
   assign z1 = sel1 ? qz : pz;
   assign x2 = sel0 ? px : qx;
   assign y2 = sel0 ? py : qy;
   assign t2 = sel0 ? pt : qt;
   assign z2 = sel0 ? pz : qz;

   always @(posedge clk) begin
      if (rst) begin
         pt_res_ready <= 0;
         pt_req_valid <= 0;
	 pt_affine <= 0;
         req_ready <= 0;
         res_valid <= 0;
         req_busy <= 0;
	 state <= S_IDLE;
      end
      else if (state == S_IDLE) begin
	 i <= 1;
         if (req_valid) begin
	    k <= K;
            req_ready <= 1;
            req_busy <= 1;
            state <= S_PRELOAD_STEP1;
         end
      end
      else if (state == S_PRELOAD_STEP1) begin
	 px <= bx;
	 py <= by;
	 pt <= bt;
	 pz <= bz;
	 qx <= bx;
	 qy <= by;
	 qt <= bt;
	 qz <= bz;
         pt_res_ready <= 0;
         pt_req_valid <= 1;
	 pt_affine <= 0;
         if (pt_req_ready) begin
            pt_req_valid <= 0;
	    state <= S_PRELOAD_STEP2;
         end
      end
      else if (state == S_PRELOAD_STEP2) begin
         if (!pt_req_busy & pt_res_valid) begin
            //$display("1st double x=%d y=%d t=%d z=%d", x3, y3, t3, z3);
            qx <= x3;
            qy <= y3;
            qt <= t3;
            qz <= z3;
            pt_res_ready <= 1;
            state <= S_LOOP_STEP1;
         end
      end
      else if (state == S_LOOP_STEP1) begin
	 if (i == N) begin
	    res_valid <= 1;
	    req_busy <= 0;
	    state <= S_POST;
	 end
	 else begin
	    state <= S_LOOP_STEP2;
	 end
      end
      else if (state == S_LOOP_STEP2) begin
         pt_res_ready <= 0;
         pt_req_valid <= 1;
	 pt_affine <= (i == N-1) ? affine : 0;
         if (pt_req_ready) begin
            pt_req_valid <= 0;
	    state <= S_LOOP_STEP3;
         end
      end
      else if (state == S_LOOP_STEP3) begin
         if (!pt_req_busy & pt_res_valid) begin
            //$display("phase1 i=%d kbit=%d x=%d y=%d t=%d z=%d", i, kbit, x3, y3, t3, z3);
	    if (kbit) begin
               px <= x3;
               py <= y3;
               pt <= t3;
               pz <= z3;
	    end
	    else begin
               qx <= x3;
               qy <= y3;
               qt <= t3;
               qz <= z3;
	    end
            pt_res_ready <= 1;
            state <= S_LOOP_STEP4;
         end
      end
      else if (state == S_LOOP_STEP4) begin
         pt_res_ready <= 0;
         pt_req_valid <= 1;
	 pt_affine <= (i == N-1) ? affine : 0;
         if (pt_req_ready) begin
            pt_req_valid <= 0;
	    state <= S_LOOP_STEP5;
         end
      end
      else if (state == S_LOOP_STEP5) begin
         if (!pt_req_busy & pt_res_valid) begin
            //$display("phase2 i=%d kbit=%d x=%d y=%d t=%d z=%d", i, kbit, x3, y3, t3, z3);
	    if (kbit) begin
               qx <= x3;
               qy <= y3;
               qt <= t3;
               qz <= z3;
	    end
	    else begin
               px <= x3;
               py <= y3;
               pt <= t3;
               pz <= z3;
	    end
            pt_res_ready <= 1;
	    pt_affine <= 0;
	    k <= { k[446:0], 1'b0 };
	    i <= i + 1;
            state <= S_LOOP_STEP1;
         end
      end
      else if (state == S_POST) begin
         if (res_ready) begin
            res_valid <= 0;
            state <= S_IDLE;
         end
      end
   end // always @ (posedge clk)

endmodule // scalarmult
