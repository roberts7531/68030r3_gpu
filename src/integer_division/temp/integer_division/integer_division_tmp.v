//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12 (64-bit)
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Created Time: Tue Mar  3 21:43:54 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	Integer_Division_Top your_instance_name(
		.clk(clk), //input clk
		.rstn(rstn), //input rstn
		.dividend(dividend), //input [20:0] dividend
		.divisor(divisor), //input [10:0] divisor
		.remainder(remainder), //output [10:0] remainder
		.quotient(quotient) //output [20:0] quotient
	);

//--------Copy end-------------------
