module tb_display;

    // Clock generation
    reg pixel_clk;
    always #20 pixel_clk = ~pixel_clk;  //25MHz

    reg clk_27;
    always #18.5 clk_27 = ~clk_27;      //27MHz

    // DUT inputs
    reg rst;
    wire [7:0] fb_data_out;

    // DUT outputs
    wire [7:0] fb_addr;
    wire de, hsync, vsync;
    wire [7:0] data_r, data_g, data_b;

    // Instantiate DUT
    display dut (
        .pixel_clk(pixel_clk),
        .rst(rst),
        .fb_data_out(fb_data_out),
        .fb_addr(fb_addr),
        .de(de),
        .hsync(hsync),
        .vsync(vsync),
        .data_r(data_r),
        .data_g(data_g),
        .data_b(data_b));

    framebuffer fb (
        .clk(clk_27),
        .rst(1'd0),
        .display_addr(fb_addr),
        .display_data_out(fb_data_out),
        //Connected to nothing
        .we(1'b0),
        .data_in(8'h00), 
        .data_out(),
        .addr(8'h00));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_display);
        
        pixel_clk       <= 0;
        clk_27          <= 0;
        rst             <= 1;
        repeat(4) @(posedge pixel_clk);     // hold reset for 4 cycles
        rst <= 0;
        
        repeat(420000) @(posedge pixel_clk);  // run for 420000 cycles, watch it loop
        
        $finish;
    end
endmodule