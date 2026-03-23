module display (
    //Control
    input pixel_clk,
    input rst,
    //Framebuffer Interface
    input  [7:0] fb_data_out,
    output [7:0] fb_addr,
    //Output
    output           de,
    output           hsync,
    output           vsync,
    output     [7:0] data_r,
    output     [7:0] data_g,
    output     [7:0] data_b
);

//Horizontal Sync Parameters
localparam h_active      = 800;
localparam h_front_porch = 40;
localparam h_sync_pulse  = 128;
localparam h_back_porch  = 88;
localparam h_total       = 1496;
localparam h_sync_start  = h_active + h_front_porch;
localparam h_sync_end    = h_sync_start + h_sync_pulse;

//Vertical Sync Parameters
localparam v_active      = 600;
localparam v_front_porch = 1;
localparam v_sync_pulse  = 4;
localparam v_back_porch  = 23;
localparam v_total       = 662;
localparam v_sync_start  = v_active + v_front_porch;
localparam v_sync_end    = v_sync_start + v_sync_pulse;

//Counter registers
reg [10:0] hcount;
reg [10:0] vcount;

//Scaling
wire [5:0] chip8_x = ((hcount + 2) < 768) ? (hcount + 2) / 12 : 63;
wire [5:0] chip8_y = (vcount < 576) ? vcount / 18 : 31;

//Sync/timing assigns
assign hsync = ((hcount >= h_sync_start) && (hcount < h_sync_end)) ? 1'b1 : 1'b0;
assign vsync = ((vcount >= v_sync_start) && (vcount < v_sync_end)) ? 1'b1 : 1'b0;

//FB address pipeline — two cycle latency
wire [7:0] fb_addr_internal = chip8_y * 8 + chip8_x[5:3];
reg  [7:0] fb_addr_reg;
always @(posedge pixel_clk) begin
    fb_addr_reg <= fb_addr_internal;
end
assign fb_addr = fb_addr_reg;

//chip8_x[2:0] pipeline — must match fb latency (2 cycles)
reg [2:0] chip8_x_bit_d1;
reg [2:0] chip8_x_bit_d2;
always @(posedge pixel_clk) begin
    chip8_x_bit_d1 <= chip8_x[2:0];
    chip8_x_bit_d2 <= chip8_x_bit_d1;
end

//de pipeline — must match fb latency (2 cycles)
reg de_reg1;
reg de_reg2;
always @(posedge pixel_clk) begin
    de_reg1 <= (hcount < h_active) && (vcount < v_active);
    de_reg2 <= de_reg1;
end
assign de = de_reg2;

//Color output
//de pipeline — must match fb latency (2 cycles)
reg de_reg1;
reg de_reg2;
always @(posedge pixel_clk) begin
    de_reg1 <= (hcount < h_active) && (vcount < v_active);
    de_reg2 <= de_reg1;
end
assign de = de_reg2;

//chip8_valid pipeline — gates boundary pixels, must match fb latency (2 cycles)
wire chip8_valid = ((hcount + 2) < 768) && (vcount < 576);
reg chip8_valid_d1;
reg chip8_valid_d2;
always @(posedge pixel_clk) begin
    chip8_valid_d1 <= chip8_valid;
    chip8_valid_d2 <= chip8_valid_d1;
end

assign data_r = (chip8_valid_d2 && fb_data_out[7 - chip8_x_bit_d2]) ? 8'hFF : 8'h00;
assign data_g = (chip8_valid_d2 && fb_data_out[7 - chip8_x_bit_d2]) ? 8'hA0 : 8'h00;
assign data_b = 8'd0;

//Counter logic
always @(posedge pixel_clk) begin
    if (rst) begin
        hcount <= 0;
        vcount <= 0;
    end else begin
        if (hcount < h_total - 1)
            hcount <= hcount + 1;
        else begin
            hcount <= 0;
            if (vcount < v_total - 1)
                vcount <= vcount + 1;
            else
                vcount <= 0;
        end
    end
end

endmodule