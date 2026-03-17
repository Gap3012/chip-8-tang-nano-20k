module key (input clk,                     //Key matrix decoder
            input rst,
            output reg [3:0] row,  
            input [3:0] col,
            output reg [15:0] keys);

    localparam delay_ms = 20;                                   //Debounce local parameter
    localparam CLK_HZ = 27_000_000;
    localparam debounce_counter_threshold = CLK_HZ / 1000 * delay_ms;

    reg [1:0] fsm_row_counter;          //Goes from 0 to 3 (4 rows). Loops around automatically
    reg [19:0] debounce_counter;        //Up to 1M+ counts. 20ms is 540k clock cycles.

    always @ (posedge clk) begin
        if (rst) begin
            fsm_row_counter     <= 2'd0;
            keys                <= 16'd0;
            debounce_counter    <= 20'd0;
            row                 <= 4'b1111;
        end else begin
            debounce_counter <= debounce_counter + 1;
            if(debounce_counter > debounce_counter_threshold - 1) begin
                //Reset signals
                debounce_counter <= 0;
                fsm_row_counter <= fsm_row_counter + 1;
                //Detecting key press
                keys[fsm_row_counter*4 + 0] <= ~col[0];
                keys[fsm_row_counter*4 + 1] <= ~col[1];
                keys[fsm_row_counter*4 + 2] <= ~col[2];
                keys[fsm_row_counter*4 + 3] <= ~col[3];
                //Driving rows active low. For the next
                case(fsm_row_counter + 1)
                    2'd0: row <= 4'b1110;
                    2'd1: row <= 4'b1101;
                    2'd2: row <= 4'b1011;
                    2'd3: row <= 4'b0111;
                    default: row <= 4'b1111;
                endcase
            end
        end
    end    
endmodule    