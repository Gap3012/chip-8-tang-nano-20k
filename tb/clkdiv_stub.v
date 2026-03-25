// clkdiv_stub.v
module CLKDIV(RESETN, HCLKIN, CLKOUT, CALIB);
input  RESETN;
input  HCLKIN;
output CLKOUT;
input  CALIB;

reg [2:0] cnt;
reg clkout_reg;

always @(posedge HCLKIN or negedge RESETN) begin
    if (!RESETN) begin
        cnt <= 0;
        clkout_reg <= 0;
    end else begin
        if (cnt == 3'd4) begin
            cnt <= 0;
            clkout_reg <= ~clkout_reg;
        end else
            cnt <= cnt + 1;
    end
end

assign CLKOUT = clkout_reg;
endmodule