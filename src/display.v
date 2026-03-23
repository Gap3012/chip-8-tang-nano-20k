module display (
    //Control
    input pixel_clk,        //Runs at the generated pixel clock by the PLL
    input rst,

    //Framebuffer Interface
    input [7:0] fb_data_out,
    output [7:0] fb_addr,

    //Output
    output              de,    //Data Enable   
    output              hsync,    
    output              vsync,
    output     [7:0]    data_r,    
    output     [7:0]    data_g,
    output     [7:0]    data_b);

    //Horizontal Sync Parameters
    localparam h_active         = 800;
    localparam h_front_porch    = 40;
    localparam h_sync_pulse     = 128;
    localparam h_back_porch     = 88;
    localparam h_total          = 1496; //Increased to fix refresh rate, and make it 60Hz
    localparam h_sync_start     = h_active + h_front_porch;
    localparam h_sync_end       = h_sync_start + h_sync_pulse;

    //Vertical Sync Parameters
    localparam v_active         = 600;
    localparam v_front_porch    = 1;
    localparam v_sync_pulse     = 4;
    localparam v_back_porch     = 23;
    localparam v_total          = 662;  //Increased to fix refresh rate, and make it 60Hz
    localparam v_sync_start     = v_active + v_front_porch;
    localparam v_sync_end       = v_sync_start + v_sync_pulse;

    //Counter registers
    reg[10:0] hcount;            //H counter. 2048 values.
    reg[10:0] vcount;            //V counter. 2048 values.
    reg de_reg;                  //Registering de to make it synchronous. Fixes pixel misalignment artifacts

    //Scaling
    wire [5:0] chip8_x    = (hcount+1)/12;    //0 to 63, delayed by 1 because of memory latency, we prefetch the next pixel
    wire [5:0] chip8_y    = vcount/18;    //0 to 31

    //Assigns
    assign hsync    = ((hcount >= h_sync_start) && (hcount < h_sync_end)) ? 1'b1 : 1'b0;    //hcount between hsync start and end
    assign vsync    = ((vcount >= v_sync_start) && (vcount < v_sync_end)) ? 1'b1 : 1'b0;    //vcount between vsync start and end 
    assign de = de_reg;
    assign fb_addr  =  chip8_y * 8 + chip8_x[5:3];  //This is equivalent to 8y + x/8. Dividing by 8 is shifing right by 3 pos

    //Technicolor
    assign data_r   = 8'd0; //Always off
    assign data_b   = 8'd0; //Always off
    assign data_g   = (fb_data_out[7 - chip8_x[2:0]]) ? 8'hFF : 8'h00;

    //assign data_r = (hcount < 213) ? 8'hFF : 8'h00;
    //assign data_g = (hcount >= 213 && hcount < 426) ? 8'hFF : 8'h00;
    //assign data_b = (hcount >= 426) ? 8'hFF : 8'h00;

    //Sequential Block to count
    always @(posedge pixel_clk) begin
        if (rst) begin
            //Reset counters
            hcount <= 0;
            vcount <= 0;
        end else begin
            if (hcount < h_total - 1)
                hcount <= hcount + 1;
            else begin
                hcount <= 0;
                if(vcount < v_total - 1) 
                    vcount <= vcount + 1;
                else
                    vcount <= 0;
            end
        end
    end

    //Synchronously make de_reg active on the active region
    always @(posedge pixel_clk)
        de_reg <= (hcount < h_active) && (vcount < v_active);
endmodule