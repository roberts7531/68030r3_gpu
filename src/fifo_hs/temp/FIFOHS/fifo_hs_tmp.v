//Copyright (C)2014-2024 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.9.01
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Created Time: Tue Feb 24 19:27:56 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	FIFO_HS_Top your_instance_name(
		.Data(Data_i), //input [31:0] Data
		.WrClk(WrClk_i), //input WrClk
		.RdClk(RdClk_i), //input RdClk
		.WrEn(WrEn_i), //input WrEn
		.RdEn(RdEn_i), //input RdEn
		.Q(Q_o), //output [7:0] Q
		.Empty(Empty_o), //output Empty
		.Full(Full_o) //output Full
	);

//--------Copy end-------------------
