//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12 (64-bit)
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Created Time: Wed Mar  4 16:53:24 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    Gowin_rPLL_dynamic your_instance_name(
        .clkout(clkout), //output clkout
        .lock(lock), //output lock
        .reset(reset), //input reset
        .clkin(clkin), //input clkin
        .fbdsel(fbdsel), //input [5:0] fbdsel
        .idsel(idsel), //input [5:0] idsel
        .odsel(odsel) //input [5:0] odsel
    );

//--------Copy end-------------------
