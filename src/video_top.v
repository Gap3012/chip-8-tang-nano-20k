module video_top
(
    //Control
    input               I_clk, //27Mhz
    input               I_rst,
    
    //Framebuffer pass-through
    output     [7:0]  fb_display_addr,
    input      [7:0]  fb_display_data_out,

    //Physical Output to HDMI
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   ,//{r,g,b}
    output     [2:0]  O_tmds_data_n);

//==================================================

wire        I_rst_n = ~I_rst;

//--------------------------
wire        disp_vs;
wire        disp_hs;
wire        disp_de;
wire [ 7:0] disp_data_r;
wire [ 7:0] disp_data_g;
wire [ 7:0] disp_data_b;
//------------------------------------
//HDMI4 TX
wire serial_clk;
wire pll_lock;
wire hdmi4_rst_n;
wire pix_clk;

//Instantiate
//==============================================================================
//TMDS TX(HDMI4)
TMDS_rPLL u_tmds_rpll
(.clkin     (I_clk     )     //input clk 
,.clkout    (serial_clk)     //output clk 
,.lock      (pll_lock  )     //output lock
);

assign hdmi4_rst_n = I_rst_n & pll_lock;

CLKDIV u_clkdiv
(.RESETN(hdmi4_rst_n)
,.HCLKIN(serial_clk) //clk  x5
,.CLKOUT(pix_clk)    //clk  x1
,.CALIB (1'b1)
);
defparam u_clkdiv.DIV_MODE="5";
defparam u_clkdiv.GSREN="false";

//Display
display display(
    .pixel_clk(pix_clk),
    .rst(~hdmi4_rst_n),             //Display expects active high
    .fb_data_out(fb_display_data_out),
    .fb_addr(fb_display_addr),
    .de(disp_de),
    .vsync(disp_vs),
    .hsync(disp_hs),
    .data_r(disp_data_r),
    .data_g(disp_data_g),
    .data_b(disp_data_b));

//The physical signal generator
DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (hdmi4_rst_n   ),  //asynchronous reset, low active
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (pix_clk       ),  //pixel clock
    .I_rgb_vs      (disp_vs     ), 
    .I_rgb_hs      (disp_hs     ),    
    .I_rgb_de      (disp_de     ), 
    .I_rgb_r       (  disp_data_r ),  //tp0_data_r
    .I_rgb_g       (  disp_data_g  ),  
    .I_rgb_b       (  disp_data_b  ),  
    .O_tmds_clk_p  (O_tmds_clk_p  ),
    .O_tmds_clk_n  (O_tmds_clk_n  ),
    .O_tmds_data_p (O_tmds_data_p ),  //{r,g,b}
    .O_tmds_data_n (O_tmds_data_n )
);
endmodule