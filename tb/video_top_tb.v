`timescale 1ns/1ps
module video_top_tb;

    //Control
    reg             I_clk; //27Mhz
    reg             I_rst;

    //CPU Interface
    /*
    reg  [7:0]      cpu_fb_addr;
    reg             cpu_fb_we;
    reg             cpu_fb_rst;
    wire [7:0]      cpu_fb_data_out;
    reg  [7:0]      cpu_fb_data_in;
    */
    //Physical Output to HDMI
    wire            O_tmds_clk_p;    
    wire            O_tmds_clk_n;    
    wire [2:0]      O_tmds_data_p;   
    wire [2:0]      O_tmds_data_n;

// ── CPU tick divider ──────────────────────────────────────────
    // 27MHz / 40000 = ~675Hz (within 500-1000Hz range)
    reg [15:0] cpu_tick_counter;
    reg        cpu_tick;

    always @(posedge I_clk or posedge I_rst) begin
        if (I_rst) begin
            cpu_tick_counter <= 0;
            cpu_tick         <= 0;
        end else if (cpu_tick_counter == 16'd53999) begin // 27MHz / 54000 = exactly 500Hz
            cpu_tick_counter <= 0;
            cpu_tick         <= 1;
        end else begin
            cpu_tick_counter <= cpu_tick_counter + 1;
            cpu_tick         <= 0;
        end
    end

    // instantiate video_top
    video_top video(
        .I_clk(I_clk),
        .I_rst(I_rst),
        //CPU Interface
        .cpu_fb_addr(8'd0),
        .cpu_fb_we(1'd0),
        .cpu_fb_rst(1'd0),
        .cpu_fb_data_out(),
        .cpu_fb_data_in(8'd0),
        .cpu_tick(cpu_tick),

        .O_tmds_clk_n(O_tmds_clk_n),
        .O_tmds_clk_p(O_tmds_clk_p),
        .O_tmds_data_n(O_tmds_data_n),
        .O_tmds_data_p(O_tmds_data_p));

    // Clock generation - 27MHz
    initial I_clk = 0;
    always #18.5 I_clk = ~I_clk; // 27MHz = ~37ns period

    // Reset and run
    initial begin
        $dumpfile("video_top_tb.vcd");
        $dumpvars(0, video_top_tb);
        
        I_rst = 1;
        repeat(10) @(posedge I_clk);
        I_rst = 0;
        
        // Run for 2 full frames worth of pixel clocks
        // 1 frame = 1650 * 750 = 1,237,500 pixel clocks
        // At 74.25MHz that's ~16.7ms
        #20_000_000; // 5ms in nanoseconds
        
        $finish;
    end

endmodule