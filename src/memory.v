module memory ( input clk,                  //Synchronous memory
                input [11:0] addr,          //12-bit addressing for the 4KB
                input we,                   //Write enable, if high we write, if low we read
                output reg[7:0] data_out,   //Byte data words, output, its a reg because it is assigned inside an always posedge block
                input [7:0] data_in);       //Byte data words, input
                
    reg [7:0] ram [0:4095];

    always @ (posedge clk) begin
        if (we)
            ram[addr] <= data_in;
        else
            data_out <= ram[addr];
    end

    integer i;
    initial begin
        for (i = 0; i < 4096; i = i + 1)
            ram[i] = 8'h00;
        $readmemh("mem/sprites.mem", ram, 0, 79);
        $readmemh("mem/test_subroutine_rom.mem", ram, 512);
    end

endmodule