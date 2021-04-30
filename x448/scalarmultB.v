// Scalar multiplication on curve448 for the standard base point.

// Rom for precomputed values.
module precomp_rom_448 (
        input clk,
        input [10:0] addr,  // 6 bit for round 4 bit for value
        output reg [447:0] data_out
);

   reg [447:0] ram[1791:0];

   // Initialize RAM from file
   parameter MEM_INIT_FILE = "";

   initial begin
      if (MEM_INIT_FILE != "") begin
	 $readmemh(MEM_INIT_FILE, ram);
      end
   end

   always @(posedge clk) begin
      // Place data from RAM
      data_out <= ram[addr];
   end

endmodule // precomp_rom_448

// scalar multiplication with the base point
module scalarmultB(input clk,
		   input rst,
		   input [447:0] K,
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

   reg [447:0] x2, y2, t2, z2, k;
   wire [447:0] x3, y3, t3, z3;
   wire	pt_req_ready;
   wire pt_req_busy;
   wire pt_res_valid;
   reg pt_req_valid;
   reg pt_res_ready;
   reg pt_affine;

   wire [448:0] x_precomp_data, y_precomp_data, t_precomp_data;
   wire [10:0] romaddr;

   point_add padd0(.clk(clk), .rst(rst),
		   .x1(px), .y1(py), .t1(pt), .z1(pz),
		   .x2(x2), .y2(y2), .t2(t2), .z2(z2),
		   .x3(x3), .y3(y3), .t3(t3), .z3(z3),
		   .affine(pt_affine),
		   .req_valid(pt_req_valid),
		   .req_ready(pt_req_ready),
		   .req_busy(pt_req_busy),
		   .res_valid(pt_res_valid),
		   .res_ready(pt_res_ready));

   // Precomputed table of i*16^j point multiplications of the base point
   // where i=0:15, j=0:111 with (x, y, t, z=1) cordinate format. 
   precomp_rom_448 #("./x_precomp_448.dat") x_mem
     (.clk(clk), .addr(romaddr), .data_out(x_precomp_data));

   precomp_rom_448 #("./y_precomp_448.dat") y_mem
     (.clk(clk), .addr(romaddr), .data_out(y_precomp_data));

   precomp_rom_448 #("./t_precomp_448.dat") t_mem
     (.clk(clk), .addr(romaddr), .data_out(t_precomp_data));

   reg [3:0] state;
   reg [6:0] i;
   localparam S_IDLE = 1;
   localparam S_PRELOAD_STEP1 = 2;
   localparam S_PRELOAD_STEP2 = 3;
   localparam S_LOOP_STEP1 = 4;
   localparam S_LOOP_STEP2 = 5;
   localparam S_LOOP_STEP3 = 6;
   localparam S_POST = 7;

   assign romaddr = { i[6:0], k[3:0] };

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
	 i <= 0;
         if (req_valid) begin
	    k <= K;
            req_ready <= 1;
            req_busy <= 1;
            state <= S_PRELOAD_STEP1;
         end
      end
      else if (state == S_PRELOAD_STEP1) begin
	 k <= { 4'b0, k[447:4] };
	 i <= i + 1;
	 state <= S_PRELOAD_STEP2;
      end
      else if (state == S_PRELOAD_STEP2) begin
	 px <= x_precomp_data;
	 py <= y_precomp_data;
	 pt <= t_precomp_data;
	 pz <= 448'd1;
	 state <= S_LOOP_STEP1;
      end
      else if (state == S_LOOP_STEP1) begin
	 if (i == 112) begin
	    res_valid <= 1;
	    req_busy <= 0;
	    state <= S_POST;
	 end
	 else begin
	    state <= S_LOOP_STEP2;
	 end
      end
      else if (state == S_LOOP_STEP2) begin
	 x2 <= x_precomp_data;
	 y2 <= y_precomp_data;
	 t2 <= t_precomp_data;
	 z2 <= 448'd1;
         pt_res_ready <= 0;
         pt_req_valid <= 1;
	 pt_affine <= (i == 111) ? affine : 0;
         if (pt_req_ready) begin
            pt_req_valid <= 0;
	    state <= S_LOOP_STEP3;
         end
      end
      else if (state == S_LOOP_STEP3) begin
         if (!pt_req_busy & pt_res_valid) begin
            //$display("padd i %d x=%d y=%d t=%d z=%d", i, x3, y3, t3, z3);
            px <= x3;
            py <= y3;
            pt <= t3;
            pz <= z3;
            pt_res_ready <= 1;
	    pt_affine <= 0;
	    k <= { 4'b0, k[447:4] };
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

endmodule // scalarmultB
