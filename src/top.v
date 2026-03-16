module top (
    input   I_clk,
    input   I_rst,
    output          O_tmds_clk_p,
    output          O_tmds_clk_n,
    output  [2:0]   O_tmds_data_p,
    output  [2:0]   O_tmds_data_n);

// framebuffer wires
wire [7:0] fb_addr;
wire [7:0] fb_data;

//TODO: Add CPU and Memory

// instantiate framebuffer
framebuffer fb (
    .clk(I_clk),
    .rst(1'd0),
    .display_addr(fb_addr),
    .display_data_out(fb_data),
    //Connected to nothing
    .we(1'b0),
    .data_in(8'h00), 
    .data_out(),
    .addr(8'h00));

// instantiate video_top
video_top video(
    .I_clk(I_clk),
    .I_rst(I_rst),
    .fb_display_addr(fb_addr),
    .fb_display_data_out(fb_data),
    .O_tmds_clk_n(O_tmds_clk_n),
    .O_tmds_clk_p(O_tmds_clk_p),
    .O_tmds_data_n(O_tmds_data_n),
    .O_tmds_data_p(O_tmds_data_p));
endmodule