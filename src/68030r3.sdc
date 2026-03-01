//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2026-02-28 23:38:39
create_clock -name sysclock -period 37 -waveform {0 18} [get_ports {clk}]
create_clock -name syclk2 -period 37.037 -waveform {0 18.518} [get_nets {clk_d}]
create_clock -name pixclk -period 15.385 -waveform {0 7.692} [get_nets {pix_clk}]
