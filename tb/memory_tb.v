module tb_memory;

    reg clk;            //Internal TB variable called clk to drive the clock of the memory chip
    reg we;             //To drive the write enable memory input
    reg [11:0]addr;     //To drive the address port of the memory chip
    reg [7:0]data_in;   //To drive the data input to the memory chip
    wire [7:0]data_out; //To read the memory output

    //Instantiate the memory chip
    memory m0 ( .clk (clk),
                .we (we),
                .addr (addr),
                .data_in (data_in),
                .data_out (data_out));

    // Generate a clock that should be driven to design
    // This clock will flip its value every 5ns -> time period = 10ns -> freq = 100 MHz
    always #5 clk = ~clk;

    // This initial block forms the stimulus of the testbench
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_memory);
        // 1. Initialize testbench variables
        clk <= 0;       //Clock starts at low
        we <= 0;        //Start with reading
        addr <= 12'h200;    //Read our first ROM Program data
        data_in <= 0;    //Initialize to 0

        // 2. Drive rest of the stimulus, reset is asserted in between
        #100    addr <=  12'h201;       //Read the next value
        #100    addr <=  12'h201;       //Read the next value
        #100    addr <=  12'hF00;       //Set to other place in memory to write
        #10     data_in <=  8'hFF;      //Write this
        #10     we <= 1;                //Write enable
        #10     we <= 0;                //Write disable
        #50     addr <=  12'h000;       //Read Sprite
        // 3. Finish the stimulus after 200ns
        #30 $finish;
    end
endmodule