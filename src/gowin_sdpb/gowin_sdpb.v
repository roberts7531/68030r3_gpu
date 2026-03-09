//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.12 (64-bit)
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Created Time: Fri Mar  6 00:17:46 2026

module Gowin_SDPB (dout, clka, cea, reseta, clkb, ceb, resetb, oce, ada, din, adb);

output [7:0] dout;
input clka;
input cea;
input reseta;
input clkb;
input ceb;
input resetb;
input oce;
input [12:0] ada;
input [7:0] din;
input [12:0] adb;

wire [27:0] sdpb_inst_0_dout_w;
wire [3:0] sdpb_inst_0_dout;
wire [27:0] sdpb_inst_1_dout_w;
wire [7:4] sdpb_inst_1_dout;
wire [23:0] sdpb_inst_2_dout_w;
wire [7:0] sdpb_inst_2_dout;
wire dff_q_0;
wire gw_gnd;

assign gw_gnd = 1'b0;

SDPB sdpb_inst_0 (
    .DO({sdpb_inst_0_dout_w[27:0],sdpb_inst_0_dout[3:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({gw_gnd,gw_gnd,ada[12]}),
    .BLKSELB({gw_gnd,gw_gnd,adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[3:0]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_0.READ_MODE = 1'b0;
defparam sdpb_inst_0.BIT_WIDTH_0 = 4;
defparam sdpb_inst_0.BIT_WIDTH_1 = 4;
defparam sdpb_inst_0.BLK_SEL_0 = 3'b000;
defparam sdpb_inst_0.BLK_SEL_1 = 3'b000;
defparam sdpb_inst_0.RESET_MODE = "SYNC";
defparam sdpb_inst_0.INIT_RAM_00 = 256'h0000000000000000000000000000000000000000000000000000000000004321;

SDPB sdpb_inst_1 (
    .DO({sdpb_inst_1_dout_w[27:0],sdpb_inst_1_dout[7:4]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({gw_gnd,gw_gnd,ada[12]}),
    .BLKSELB({gw_gnd,gw_gnd,adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:4]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_1.READ_MODE = 1'b0;
defparam sdpb_inst_1.BIT_WIDTH_0 = 4;
defparam sdpb_inst_1.BIT_WIDTH_1 = 4;
defparam sdpb_inst_1.BLK_SEL_0 = 3'b000;
defparam sdpb_inst_1.BLK_SEL_1 = 3'b000;
defparam sdpb_inst_1.RESET_MODE = "SYNC";
defparam sdpb_inst_1.INIT_RAM_00 = 256'h0000000000000000000000000000000000000000000000000000000000004444;

SDPB sdpb_inst_2 (
    .DO({sdpb_inst_2_dout_w[23:0],sdpb_inst_2_dout[7:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({gw_gnd,ada[12],ada[11]}),
    .BLKSELB({gw_gnd,adb[12],adb[11]}),
    .ADA({ada[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:0]}),
    .ADB({adb[10:0],gw_gnd,gw_gnd,gw_gnd})
);

defparam sdpb_inst_2.READ_MODE = 1'b0;
defparam sdpb_inst_2.BIT_WIDTH_0 = 8;
defparam sdpb_inst_2.BIT_WIDTH_1 = 8;
defparam sdpb_inst_2.BLK_SEL_0 = 3'b010;
defparam sdpb_inst_2.BLK_SEL_1 = 3'b010;
defparam sdpb_inst_2.RESET_MODE = "SYNC";

DFFE dff_inst_0 (
  .Q(dff_q_0),
  .D(adb[12]),
  .CLK(clkb),
  .CE(ceb)
);
MUX2 mux_inst_2 (
  .O(dout[0]),
  .I0(sdpb_inst_0_dout[0]),
  .I1(sdpb_inst_2_dout[0]),
  .S0(dff_q_0)
);
MUX2 mux_inst_5 (
  .O(dout[1]),
  .I0(sdpb_inst_0_dout[1]),
  .I1(sdpb_inst_2_dout[1]),
  .S0(dff_q_0)
);
MUX2 mux_inst_8 (
  .O(dout[2]),
  .I0(sdpb_inst_0_dout[2]),
  .I1(sdpb_inst_2_dout[2]),
  .S0(dff_q_0)
);
MUX2 mux_inst_11 (
  .O(dout[3]),
  .I0(sdpb_inst_0_dout[3]),
  .I1(sdpb_inst_2_dout[3]),
  .S0(dff_q_0)
);
MUX2 mux_inst_14 (
  .O(dout[4]),
  .I0(sdpb_inst_1_dout[4]),
  .I1(sdpb_inst_2_dout[4]),
  .S0(dff_q_0)
);
MUX2 mux_inst_17 (
  .O(dout[5]),
  .I0(sdpb_inst_1_dout[5]),
  .I1(sdpb_inst_2_dout[5]),
  .S0(dff_q_0)
);
MUX2 mux_inst_20 (
  .O(dout[6]),
  .I0(sdpb_inst_1_dout[6]),
  .I1(sdpb_inst_2_dout[6]),
  .S0(dff_q_0)
);
MUX2 mux_inst_23 (
  .O(dout[7]),
  .I0(sdpb_inst_1_dout[7]),
  .I1(sdpb_inst_2_dout[7]),
  .S0(dff_q_0)
);
endmodule //Gowin_SDPB
