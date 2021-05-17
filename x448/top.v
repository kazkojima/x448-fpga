`timescale 1 ns / 1 ps

`define P448 448'd726838724295606890549323807888004534353641360687318060281490199180612328166730772686396383698676545930088884461843637361053498018365439

//`define impl_invm
//`define impl_multmod
//`define impl_divmod
//`define impl_point_add
`define impl_scalarmultB
//`define impl_scalarmult

module pll_12_48(input clki, output clko);
    (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
    EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .CLKOP_FPHASE(0),
        .CLKOP_CPHASE(11),
        .OUTDIVIDER_MUXA("DIVA"),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(16),
        .CLKFB_DIV(24),
        .CLKI_DIV(6),
        .FEEDBK_PATH("CLKOP")
    ) pll_i (
        .CLKI(clki),
        .CLKFB(clko),
        .CLKOP(clko),
        .RST(1'b0),
        .STDBY(1'b0),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b0),
        .PHASESTEP(1'b0),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
    );
endmodule

module top(input wire clk,
           input wire rstn,
           output tp0,
           output tp1,
           output tp2,
           output [7:0] led);

   reg [7:0] state;
   reg [7:0] count;
   reg rst;
   wire [447:0] x3_out, y3_out, t3_out, z3_out;
   wire req_ready, req_busy, res_valid;
   reg res_ready;

   wire refclk;

   pll_12_48 pll_inst(clk, refclk);

/*
   addmod addmod0(.a(448'd484559149530404593699549205258669689569094240458212040187660132787056912146709081364401144455726350866276831544947397859048262938744149),
		  .b(448'd628930339897224761877458712630456916313059351224950674660715238218025224359569994148177859636458751997369808394808543907584068268720738),
		  .z(x3_out));

   submod submod0(.a(448'd386650765132022465027684110001122071528512230995844654566885171824469808339548302826182620393508556933557755477912304405578833189099448),
		  .b(448'd628930339897224761877458712630456916313059351224950674660715238218025224359569994148177859636458751997369808394808543907584068268720738),
		  .z(x3_out));
*/

`ifdef impl_invm
`define result_out 448'd363419362147803445274661903944002267176820680343659030140745099590306164083365386343198191849338272965044442230921818680526749009182720

   inv_montgomery #(.N(448)) inv0
   (.clk(refclk), .rst(rst), .X(448'd2), .M(`P448), .R(x3_out),
    .real_inverse(1'b1),
    .req_valid(1'b1), .req_ready(req_ready), .req_busy(req_busy),
    .res_valid(res_valid), .res_ready(res_ready));
`endif

`ifdef impl_divmod
`define result_out 448'd605698936913005742124436506573337111961367800572765050234575165983834620156719927025398764077201448398182858003395517610050880478554794

   divmod divmod0
     (.clk(refclk), .rst(rst), .x(448'd484559149530404593699549205258669689569094240458212040187660132787056912146709081364401144455726350866276831544947397859048262938744149), .y(448'd2), .z(x3_out), .req_valid(1'b1),
    .req_ready(req_ready), .req_busy(req_busy), .res_valid(res_valid),
    .res_ready(res_ready));
`endif

`ifdef impl_multmod
`define result_out 448'd387304051755042505631669743731884414390525906745274713463103348481248176085515023438354995513075395833444908195326698307529995922079670

   multmod multmod0
     (.clk(refclk), .rst(rst), .X(448'd484559149530404593699549205258669689569094240458212040187660132787056912146709081364401144455726350866276831544947397859048262938744149), .Y(448'd628930339897224761877458712630456916313059351224950674660715238218025224359569994148177859636458751997369808394808543907584068268720738), .Z(x3_out), .req_valid(1'b1),
    .req_ready(req_ready), .req_busy(req_busy), .res_valid(res_valid),
    .res_ready(res_ready));
`endif

`ifdef impl_point_add
`define result_pt
`define result_xout 448'd239406078818472299991463352497332512588600063788186615857229092651287249414877974559561078996047194872547741055700750472741020795598748
`define result_yout 448'd180575390692171734403313167632075320967115782217538592690930447779446627482491412766369358427480484723601566614743776441506943161105356
    point_add padd0(.clk(refclk), .rst(rst),
		   .x1(448'd484559149530404593699549205258669689569094240458212040187660132787056912146709081364401144455726350866276831544947397859048262938744149),
		   .y1(448'd494088759867433727674302672526735089350544552303727723746126484473087719117037293890093462157703888342865036477787453078312060500281069),
                   .t1(448'd299332065086798893892792585768169115335193388885713727450493159256883112363806410010007269777745784758601856431980405082175935897068546),
		   .z1(448'd1),
 		   .x2(448'd209710714663589237570084264541991420589833663592202160838176801982171960997051286469552065490170659385708816452452440655275673121357616),
		   .y2(448'd603515570432573637134887094808958022419371301976351441963100315034426774344109511210661998660350679225364893651728492312845104034682937),
                   .t2(448'd624639617048901649469143983520127300687758596573400282135048038701309735379063725196352955729285151265142951805238799778043241111531754),
		   .z2(448'd1),
		   .x3(x3_out), .y3(y3_out), .t3(t3_out), .z3(z3_out),
		   .affine(1'b1),
 		   .req_valid(1'b1),
		   .req_ready(req_ready),
		   .req_busy(req_busy),
		   .res_valid(res_valid),
		   .res_ready(res_ready));
`endif

`ifdef impl_scalarmultB
`define result_pt
`define result_xout 448'd569800053202636238213339737806379973166958128821502594164753810496485879402241447651619753965278911521961406266873284268697177328388402
`define result_yout 448'd677116538079273952496732858461525350221407247609618233032402431353853502073759166157999250616634017133730362794125374547072115326627962

     scalarmultB smlt0(.clk(refclk), .rst(rst),
		     .K(448'd247118570853021187691440210094409250541228771220512102386125227674683654432806238365365140771578793833887595672402707518477526965646183),
		     .px(x3_out), .py(y3_out), .pt(t3_out), .pz(z3_out),
		     .affine(1'b1),
		     .req_valid(1'b1),
		     .req_ready(req_ready),
		     .req_busy(req_busy),
		     .res_valid(res_valid),
		     .res_ready(res_ready));
`endif

`ifdef impl_scalarmult
`define result_pt
`define result_xout 448'd602423168803771815688641455231997130575101805413631089821110505683516441381320993444673353108477965428550843196265375489693152726374369
`define result_yout 448'd22422774163568646215703207455430131237724354698486692118541383776931663468693726037774581901193965953311787319979638247242545558398548

     scalarmult smlt0(.clk(refclk), .rst(rst),
		      .K(448'd547118570853021187691440210094409250541228771220512102386125227674683654432806238365365140771578793833887595672402707518477526965646183 | { 1'b1, 447'b0 }),
		      .bx(448'd484559149530404593699549205258669689569094240458212040187660132787056912146709081364401144455726350866276831544947397859048262938744149),
		      .by(448'd494088759867433727674302672526735089350544552303727723746126484473087719117037293890093462157703888342865036477787453078312060500281069),
		      .bt(448'd299332065086798893892792585768169115335193388885713727450493159256883112363806410010007269777745784758601856431980405082175935897068546),
		      .bz(448'd1),
		      .px(x3_out), .py(y3_out), .pt(t3_out), .pz(z3_out),
		      .affine(1'b1),
		      .req_valid(1'b1),
		      .req_ready(req_ready),
		      .req_busy(req_busy),
		      .res_valid(res_valid),
		      .res_ready(res_ready));
`endif

   assign led[7:0] = ~count;
   assign tp0 = res_valid;
   assign tp1 = req_busy;

   always @(posedge refclk) begin
      if (rstn == 0) begin
	 rst <= 1;
	 res_ready <= 0;
	 state <= 0;
	 count <= 0;
      end
      else begin
	 state <= state + 1;
      end
      if (state > 3) begin
	 rst <= 0;
      end
      if (!rst) begin
	 if (res_valid & !res_ready) begin
	    res_ready <= 1;
`ifdef result_pt
	    if ((x3_out == `result_xout) & (y3_out == `result_yout)) begin
`else
	    if (x3_out == `result_out) begin
`endif
	       count <= count + 1;
	    end
	 end
 	 else if (!res_valid) begin
	    res_ready <= 0;
	 end
     end
   end

endmodule // testbench
