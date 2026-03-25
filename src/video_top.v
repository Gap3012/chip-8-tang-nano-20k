module video_top
(
    //Control
    input               I_clk, //27Mhz
    input               I_rst,

    //CPU Interface
    input  [7:0]        cpu_fb_addr,
    input               cpu_fb_we,
    input               cpu_fb_rst,
    output [7:0]        cpu_fb_data_out,
    input  [7:0]        cpu_fb_data_in,
    input               cpu_tick,

    //Physical Output to HDMI
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   ,//{r,g,b}
    output     [2:0]  O_tmds_data_n);

    //==================================================

    wire        I_rst_n = ~I_rst;

    //Display Wires-------------------------------------
    wire        disp_vs;
    wire        disp_hs;
    wire        disp_de;
    wire [7:0] disp_data_r;
    wire [7:0] disp_data_g;
    wire [7:0] disp_data_b;
    wire [7:0] fb_display_data_out;
    wire [7:0] fb_display_addr;
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

    // Clear state machine
    reg [1:0]  clear_state;
    localparam CLEAR_IDLE       = 2'd0;
    localparam CLEAR_ACTIVE     = 2'd1;
    localparam CLEAR_DONE       = 2'd2;

    reg  [7:0] clear_addr;

    wire clearing = (clear_state == CLEAR_ACTIVE);
    wire [7:0] bram_adb  = clearing ? clear_addr      : fb_display_addr;
    wire       bram_wreb = clearing ? 1'b1            : 1'b0;

    always @(posedge pix_clk) begin
        case(clear_state)
            CLEAR_IDLE: begin
                if(cpu_fb_rst) begin
                     clear_state <= CLEAR_ACTIVE;
                     clear_addr <= 8'd0;
                end
            end

            CLEAR_ACTIVE: begin
                if(clear_addr < 8'hFF)
                    clear_addr <= clear_addr + 1;
                else begin
                    clear_addr <= 8'd0; //Reset this counter
                    clear_state <= CLEAR_DONE;
                end    
            end
            
            CLEAR_DONE: begin
                if(!cpu_fb_rst) clear_state <= CLEAR_IDLE;
            end

            default: clear_state <= CLEAR_IDLE;
        endcase
    end

    //Framebuffer. Port A is CPU port @ 500Hz, Port B is Display Port @ pixel clk speed
    Gowin_DP framebuffer(
        .douta(cpu_fb_data_out),    //output [7:0] data for CPU read
        .doutb(fb_display_data_out),//output [7:0] data for Display read
        .clka(cpu_tick),            //input Clock for Port A
        .ocea(1'b1),                //input tied to 1
        .cea(1'b1),                 //input tied to 1
        .reseta(I_rst),             //input tied to I_rst
        .wrea(cpu_fb_we),           //input we from CPU
        .clkb(pix_clk),             //input Clock for Port B
        .oceb(1'b1),                //input tied to 1
        .ceb(1'b1),                 //input tied to 1
        .resetb(I_rst),             //input tied to I_rst
        .wreb(bram_wreb),           //input tied to 0, port b is read only 
        .ada(cpu_fb_addr),          //input [7:0] CPU address
        .dina(cpu_fb_data_in),      //input [7:0] Data from CPU to write
        .adb(bram_adb),             //input [7:0] Display address
        .dinb(8'd0)                 //input [7:0] Tied to 0 for clearing purposes
    );

    //Display
    display display(
        .pixel_clk(pix_clk),
        .rst(~hdmi4_rst_n),             //Display expects active high
        .fb_data_out(fb_display_data_out),  //Input
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