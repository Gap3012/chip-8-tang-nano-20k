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

//For 720p@60Hz
//Horizontal Sync Parameters
localparam h_active      = 1280;
localparam h_front_porch = 110;
localparam h_sync_pulse  = 40;
localparam h_back_porch  = 220;
localparam h_total       = 1650;
localparam h_sync_start  = h_active + h_front_porch;
localparam h_sync_end    = h_sync_start + h_sync_pulse;

//Vertical Sync Parameters
localparam v_active      = 720;
localparam v_front_porch = 5;
localparam v_sync_pulse  = 5;
localparam v_back_porch  = 20;
localparam v_total       = 750;
localparam v_sync_start  = v_active + v_front_porch;
localparam v_sync_end    = v_sync_start + v_sync_pulse;

//Counter registers
reg [10:0] hcount;
reg [10:0] vcount;

//Scaling. 20x. Square pixels centered
wire [5:0] chip8_x = (hcount) / 20;
wire [5:0] chip8_x_prefetch = ((hcount + 1) < 1280) ? ((hcount + 1) / 20) : 6'd63;  //Clamped so it doesn't go out of bounds
wire [5:0] chip8_y = (vcount >= 40) ? ((vcount - 40) / 20) : 6'd0;

//Sync/timing assigns
assign hsync = ((hcount >= h_sync_start) && (hcount < h_sync_end)) ? 1'b1 : 1'b0;
assign vsync = ((vcount >= v_sync_start) && (vcount < v_sync_end)) ? 1'b1 : 1'b0;

assign fb_addr = chip8_y * 8 + chip8_x_prefetch[5:3];

// 1 cycle pipeline to match BRAM bypass latency
reg       chip8_valid_d1;

always @(posedge pixel_clk) begin
    chip8_valid_d1 <= (hcount < 1280) && (vcount >= 40) && (vcount < 680);
end

assign de = (hcount < h_active) && (vcount < v_active);

assign data_r = (chip8_valid_d1 && fb_data_out[7 - chip8_x[2:0]]) ? 8'hFF : 8'h00;
assign data_g = (chip8_valid_d1 && fb_data_out[7 - chip8_x[2:0]]) ? 8'hA0 : 8'h00;
assign data_b = 8'h00;

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