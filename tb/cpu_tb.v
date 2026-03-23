module tb_cpu;

    reg clk;            //Internal TB variable called clk to drive the system. @ 27MHz
    reg rst;            //To reset the CPU
    reg cpu_tick;        //To drive the CPU tick, which is gonna be 500Hz

    //Memory interface to wire CPU and Mem together.
    wire [11:0] mem_addr;    
    wire [7:0] mem_data_in;
    wire [7:0] mem_data_out;
    wire mem_we;

    //Tied off for now
    reg [15:0] keys         = 16'd0;
    reg [7:0] fb_data_out   = 8'd0;

    //Instantiate CPU
    cpu c0 (
        .clk        (clk),
        .rst        (rst),
        .cpu_tick   (cpu_tick),
        .mem_addr   (mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in),
        .mem_we     (mem_we),
        // framebuffer ports tied off
        .fb_data_out(fb_data_out),
        .fb_addr    (),      // leave unconnected
        .fb_data_in (),      // leave unconnected
        .fb_we      (),      // leave unconnected
        .fb_rst     (),      // leave unconnected
        // keypad
        .keys       (keys)
    );

    //Instantiate Memory
    memory m0 (
        .clk      (clk),
        .addr     (mem_addr),
        .data_in  (mem_data_in),
        .data_out (mem_data_out),
        .we       (mem_we)
    );

    integer tick_count;
    
    always #5 clk = ~clk;   //Toggle clock at 5n
    
    //Clock divider. Will divide by 4. In reality it will do 27Mhz -> 500Hz
    always @(posedge clk) begin
        if (rst) begin
            tick_count <= 0;
            cpu_tick   <= 0;
        end
        else begin
            tick_count <= tick_count + 1;
            cpu_tick   <= 0;
            if (tick_count == 3) begin
                cpu_tick   <= 1;
                tick_count <= 0;
            end
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cpu);
        
        clk      <= 0;
        rst      <= 1;
        
        repeat(4) @(posedge clk);  // hold reset for 4 cycles
        rst <= 0;
        
        repeat(200) @(posedge clk);  // run for 200 cycles, watch it loop
        
        $finish;
    end

endmodule