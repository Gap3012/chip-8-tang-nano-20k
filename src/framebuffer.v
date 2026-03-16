module framebuffer ( 
                //Control
                input clk,                  //Synchronous memory
                input rst,                  //To clear screen

                //CPU Interface
                input [7:0] addr,           //8-bit addressing for the 256 Bytes
                input we,                   //Write enable, if high we write, if low we 
                output reg[7:0] data_out,   //Byte data words, output, its a reg because it is assigned inside an always posedge block
                input [7:0] data_in,        //Byte data words, input

                //Display Interface
                input [7:0] display_addr,
                output reg[7:0] display_data_out);

    reg [7:0] fb [0:255];                   //256 addresses
    integer i;

    //CPU Interface
    always @ (posedge clk) begin
        if (rst) begin
            for (i = 0; i < 256; i = i + 1)
                fb[i] <= 8'h00;
        end 
        else if (we)
            fb[addr] <= data_in;
        else
            data_out <= fb[addr];
    end

    //Display Interface
    always @ (posedge clk) begin
        display_data_out <= fb[display_addr];
    end
    
    initial begin
        for (i = 0; i < 256; i = i + 1)
            fb[i] = 8'h00;
        $readmemh("mem/test_fb_stripes.mem", fb, 0);
    end

endmodule