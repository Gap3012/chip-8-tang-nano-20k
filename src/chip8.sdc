//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12.02 
//Created Time: 2026-03-14 23:13:02
create_clock -name I_clk -period 37.037 -waveform {0 18.518} [get_ports {I_clk}]
create_generated_clock -name pix_clk -source [get_ports {I_clk}] -divide_by 1 [get_nets {video/pix_clk}]