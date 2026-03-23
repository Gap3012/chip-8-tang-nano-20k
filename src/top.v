module top (
    input   I_clk,
    input   I_rst,
    output          O_tmds_clk_p,
    output          O_tmds_clk_n,
    output  [2:0]   O_tmds_data_p,
    output  [2:0]   O_tmds_data_n);
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

// framebuffer <> Display wires
wire [7:0] fb_disp_addr;
wire [7:0] fb_disp_data;

// framebuffer <> CPU wires
wire [7:0] fb_addr;
wire [7:0] fb_data_in;
wire [7:0] fb_data_out;
wire fb_we;
wire fb_rst;
// memory wires
wire [11:0] mem_addr;
wire [7:0] mem_data_out;
wire [7:0] mem_data_in;
wire mem_we;

// instantiate CPU
cpu cpu (
    //Control
    .clk(I_clk),
    .rst(I_rst),
    .cpu_tick(cpu_tick),
    //Memory Interface
    .mem_addr(mem_addr),
    .mem_data_in(mem_data_in),
    .mem_data_out(mem_data_out),
    .mem_we(mem_we),
    //Framebuffer Interface
    .fb_addr(fb_addr),
    .fb_data_in(fb_data_in),
    .fb_data_out(fb_data_out),
    .fb_we(fb_we),
    .fb_rst(fb_rst),
    //Keys
    .keys(16'd0));

// intantiate memory
memory memory(
    .clk(I_clk),
    .addr(mem_addr),
    .data_in(mem_data_in),
    .data_out(mem_data_out),
    .we(mem_we));

// instantiate framebuffer
framebuffer fb (
    //Control
    .clk(I_clk),
    .rst(fb_rst),
    //Display wires
    .display_addr(fb_disp_addr),
    .display_data_out(fb_disp_data),
    //CPU Wires
    .we(fb_we),
    .data_in(fb_data_in), 
    .data_out(fb_data_out),
    .addr(fb_addr));

// instantiate video_top
video_top video(
    .I_clk(I_clk),
    .I_rst(I_rst),
    .fb_display_addr(fb_disp_addr),
    .fb_display_data_out(fb_disp_data),
    .O_tmds_clk_n(O_tmds_clk_n),
    .O_tmds_clk_p(O_tmds_clk_p),
    .O_tmds_data_n(O_tmds_data_n),
    .O_tmds_data_p(O_tmds_data_p));
endmodule