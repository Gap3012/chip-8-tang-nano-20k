module framebuffer ( 
    input clk,
    input rst,
    // CPU Interface
    input  [7:0] addr,
    input        we,
    output reg [7:0] data_out,
    input  [7:0] data_in,
    // Display Interface
    input  [7:0] display_addr,
    output reg [7:0] display_data_out
);

    reg [7:0] fb [0:255];
    reg resetting;
    reg [7:0] rst_counter;

    // CPU write + reset logic
    always @ (posedge clk) begin
        if (rst) begin
            resetting   <= 1;
            rst_counter <= 0;
        end else if (resetting) begin
            fb[rst_counter] <= 8'h00;
            if (rst_counter == 8'hFF)
                resetting <= 0;
            else
                rst_counter <= rst_counter + 1;
        end else if (we) begin
            fb[addr] <= data_in;
        end
        data_out <= fb[addr];
    end

    // Display read port
    always @ (posedge clk) begin
        display_data_out <= fb[display_addr];
    end

    initial begin
        $readmemh("mem/empty_fb.mem", fb, 0, 255);
        $readmemh("mem/ibm_logo_fb.mem", fb, 0);
    end

endmodule