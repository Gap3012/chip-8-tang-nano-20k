`timescale 1ns/1ps
module tb_clk;
reg clk;

always #18.5 clk = ~clk;

initial begin
    $dumpfile("tb_clk.vcd");
    $dumpvars(0, tb_clk);
    clk = 0;
    #1000;
    $finish;
end
endmodule