module top (
    //Control
    input   I_clk,
    input   I_rst,
    //HDMI
    output          O_tmds_clk_p,
    output          O_tmds_clk_n,
    output  [2:0]   O_tmds_data_p,
    output  [2:0]   O_tmds_data_n,
    //Keypad
    input   [3:0]   col,
    output  [3:0]   row);
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

// key wires
wire [15:0] keys;

// intantiate memory
memory memory(
    .clk(I_clk),
    .addr(mem_addr),
    .data_in(mem_data_in),
    .data_out(mem_data_out),
    .we(mem_we));

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
    .keys(keys));   //Input

// instantiate video_top
video_top video(
    .I_clk(I_clk),
    .I_rst(I_rst),
    //CPU Interface
    .cpu_fb_addr(fb_addr),
    .cpu_fb_we(fb_we),
    .cpu_fb_rst(fb_rst),
    .cpu_fb_data_out(fb_data_out),
    .cpu_fb_data_in(fb_data_in),
    .cpu_tick(cpu_tick),
    //HDMI Output
    .O_tmds_clk_n(O_tmds_clk_n),
    .O_tmds_clk_p(O_tmds_clk_p),
    .O_tmds_data_n(O_tmds_data_n),
    .O_tmds_data_p(O_tmds_data_p));

// instantiate key
key key(
    .clk(I_clk),
    .rst(I_rst),
    .row(row),
    .col(col),
    .keys(keys)     //Output
);
endmodule