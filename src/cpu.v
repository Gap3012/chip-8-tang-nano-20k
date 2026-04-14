module cpu( // Control
            input clk,
            input rst,
            input cpu_tick,     //Divided clock so CPU runs at 1000-500Hz

            // Memory interface
            output reg[11:0] mem_addr,
            input  [7:0]  mem_data_out,
            output reg[7:0]  mem_data_in,
            output reg mem_we,

            // Framebuffer interface
            output reg[7:0] fb_addr,
            input [7:0] fb_data_out,
            output reg[7:0]  fb_data_in,
            output reg fb_we,
            output reg fb_rst,  //To clear frame buffer. Active high

            // Keypad interface
            input  [15:0] keys);

    //State machine
    localparam FETCH_HIGH = 3'd0;
    localparam FETCH_LOW  = 3'd1;
    localparam DECODE     = 3'd2;
    localparam EXECUTE    = 3'd3;

    reg [2:0] state;
    reg [2:0] next_state;
    reg execution_done_comb;

    reg [5:0] latched_x;
    reg [4:0] latched_y;

    //Registers
    reg [7:0] V [15:0];
    reg [11:0] I;
    reg [7:0] t_reg;
    reg [7:0] s_reg;
    reg [11:0] PC;
    reg [3:0] SP;
    reg [11:0] stack [15:0];
    reg [15:0] IR;

    reg [15:0] lfsr;

    //Decode variables
    wire [3:0] op           = IR[15:12];
    wire [3:0] x            = IR[11:8];
    wire [3:0] y            = IR[7:4];
    wire [3:0] n            = IR[3:0];
    wire [7:0] kk           = IR[7:0];
    wire [11:0] nnn         = IR[11:0];
    wire [8:0] add_result   = V[x] + V[y];
    wire [3:0] SP_minus1    = SP - 1;

    integer i;

    reg [3:0] key_index;

    //DXYN instruction
    localparam DRAW_IDLE             = 3'd0;
    localparam DRAW_FETCH            = 3'd1;
    localparam DRAW_WRITE_LEFT       = 3'd2;
    localparam DRAW_WRITE_RIGHT      = 3'd3;
    localparam DRAW_WRITE_RIGHT_WAIT = 3'd4;
    localparam DRAW_WRITE_RIGHT2     = 3'd5;

    reg [2:0] draw_state;
    reg [3:0] draw_row;
    reg drawing;

    wire [5:0] wrapped_x = V[x] & 6'h3F;
    wire [4:0] wrapped_y = (V[y] + draw_row) & 5'h1F;

    //BCD Instruction
    localparam BCD_IDLE     = 2'd0;
    localparam BCD_HUNDREDS = 2'd1;
    localparam BCD_TENS     = 2'd2;
    localparam BCD_ONES     = 2'd3;

    reg [1:0] bcd_state;

    wire [7:0] bcd_hundreds = V[x] / 100;
    wire [7:0] bcd_tens     = (V[x] / 10) % 10;
    wire [7:0] bcd_ones     = V[x] % 10;

    //Fx55 / Fx65
    reg [3:0] ld_index;
    reg [1:0] ld_state;

    localparam LD_ST_IDLE   = 2'd0;
    localparam LD_ST_WRITE  = 2'd1;

    localparam LD_RD_IDLE   = 2'd0;
    localparam LD_RD_FETCH  = 2'd1;
    localparam LD_RD_STORE  = 2'd2;

    //RNG
    reg [15:0] entropy;
    initial entropy = 16'h0001;
    always @(posedge clk) begin
        entropy <= entropy + 1;  // free running
    end

    //Sound and Delay timers
    reg [18:0]  timer_counter;  //Allows to turn 27MHz into 60Hz for the timer decrements
    reg         timer_tick;

    //Key detection
    reg key_was_pressed;

    //60Hz timer tick generation
    always @(posedge clk) begin
        if (rst) begin
            timer_counter <= 0;
            timer_tick    <= 0;
        end else if (timer_counter == 19'd449999) begin // 27MHz / 450000 = 60Hz
            timer_counter <= 0;
            timer_tick    <= 1;
        end else begin
            timer_counter <= timer_counter + 1;
            timer_tick    <= 0;
        end
    end

    // Block 1 - sequential
    always @(posedge clk) begin

        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[11] ^ lfsr[10]};
        
        if (timer_tick) begin
            if (t_reg > 0) t_reg <= t_reg - 1;
            if (s_reg > 0) s_reg <= s_reg - 1;
        end        
        
        if (rst) begin
            state      <= FETCH_HIGH;
            PC         <= 12'h200;
            SP         <= 4'd0;
            IR         <= 16'h0000;
            I          <= 12'h000;
            lfsr       <= 16'hACE1;
            draw_state <= DRAW_IDLE;
            bcd_state  <= BCD_HUNDREDS;
            ld_state   <= LD_ST_IDLE;
            drawing    <= 1'b0;
            latched_x  <= 6'h0;
            latched_y  <= 5'h0;
            fb_rst     <= 1'b0;
            fb_we      <= 1'b0;
            mem_we     <= 1'b0;
            for (i = 0; i < 16; i = i + 1)
                V[i] <= 8'h00;
            t_reg <= 8'h00;
            s_reg <= 8'h00;
            key_was_pressed <= 0;
        end
        else if (cpu_tick) begin
            $display("PC=%03h IR=%04h ld_index=%04h ld_state=%02h exec = %01h| V0=%02h V1=%02h V2=%02h V3=%02h V4=%02h V5=%02h V6=%02h V7=%02h V8=%02h V9=%02h VA=%02h VB=%02h VC=%02h VD=%02h VE=%02h VF=%02h | I=%04h",
            PC, IR, ld_index, ld_state, execution_done_comb,
            V[0], V[1], V[2], V[3], V[4], V[5], V[6], V[7],
            V[8], V[9], V[10], V[11], V[12], V[13], V[14], V[15],
            I);
            case (state)
                FETCH_HIGH: begin
                    mem_addr <= PC;
                    PC       <= PC + 1;
                    fb_rst   <= 0;
                    mem_we   <= 0;
                end

                FETCH_LOW: begin
                    mem_addr  <= PC;
                    IR[15:8]  <= mem_data_out;
                    PC        <= PC + 1;
                end

                DECODE: begin
                    IR[7:0] <= mem_data_out;
                end

                EXECUTE: begin
                    case (op)
                        4'h0: begin
                            case (kk)
                                8'hE0: begin
                                    fb_rst <= 1;
                                end
                                8'hEE: begin
                                    PC <= stack[SP_minus1];
                                    SP <= SP_minus1;
                                end
                                default: ;
                            endcase
                        end

                        4'h1: begin
                            PC <= nnn;
                        end

                        4'h2: begin
                            stack[SP] <= PC;
                            SP        <= SP + 1;
                            PC        <= nnn;
                        end

                        4'h3: begin
                            if (V[x] == kk) PC <= PC + 2;
                        end

                        4'h4: begin
                            if (V[x] != kk) PC <= PC + 2;
                        end

                        4'h5: begin
                            if (V[x] == V[y]) PC <= PC + 2;
                        end

                        4'h6: begin
                            V[x] <= kk;
                        end

                        4'h7: begin
                            V[x] <= V[x] + kk;
                        end

                        4'h8: begin
                            case (n)
                                4'h0: V[x] <= V[y];
                                4'h1: V[x] <= V[x] | V[y];
                                4'h2: V[x] <= V[x] & V[y];
                                4'h3: V[x] <= V[x] ^ V[y];
                                4'h4: begin
                                    V[x]  <= add_result[7:0];
                                    V[15] <= add_result[8];
                                end
                                4'h5: begin
                                    V[15] <= (V[x] >= V[y]) ? 8'h1 : 8'h0;
                                    V[x]  <= V[x] - V[y];
                                end
                                4'h6: begin
                                    V[15] <= V[x][0];
                                    V[x]  <= V[x] >> 1;
                                end
                                4'h7: begin
                                    V[15] <= (V[y] >= V[x]) ? 8'h1 : 8'h0;
                                    V[x]  <= V[y] - V[x];
                                end
                                4'hE: begin
                                    V[15] <= V[x][7];
                                    V[x]  <= V[x] << 1;
                                end
                                default: ;
                            endcase
                        end

                        4'h9: begin
                            if (V[x] != V[y]) PC <= PC + 2;
                        end

                        4'hA: begin
                            I <= nnn;
                        end

                        4'hB: begin
                            PC <= nnn + V[0];
                        end

                        4'hC: begin
                            V[x] <= (lfsr[7:0] ^ entropy[7:0]) & kk;
                        end

                        4'hD: begin
                            case (draw_state)
                                DRAW_IDLE: begin
                                    draw_row   <= 4'h0;
                                    V[15]      <= 8'h0;
                                    fb_we      <= 0;
                                    drawing    <= 1'b1;
                                    draw_state <= DRAW_FETCH;
                                end

                                DRAW_FETCH: begin
                                    fb_we      <= 0;
                                    mem_addr   <= I + draw_row;
                                    fb_addr    <= wrapped_y * 8 + wrapped_x[5:3];
                                    latched_x  <= wrapped_x;
                                    latched_y  <= wrapped_y;
                                    draw_state <= DRAW_WRITE_LEFT;
                                end

                                DRAW_WRITE_LEFT: begin
                                    fb_data_in <= (mem_data_out >> latched_x[2:0]) ^ fb_data_out;
                                    fb_we      <= 1;
                                    if ((mem_data_out & fb_data_out) != 8'h0)
                                        V[15] <= 8'h1;
                                    if (latched_x[2:0] == 0) begin
                                        // aligned — no right byte needed
                                        if (draw_row == n - 1) begin
                                            drawing    <= 1'b0;
                                            draw_state <= DRAW_IDLE;
                                        end else begin
                                            draw_row   <= draw_row + 1;
                                            draw_state <= DRAW_FETCH;
                                        end
                                    end else begin
                                        draw_state <= DRAW_WRITE_RIGHT;
                                    end
                                end

                                DRAW_WRITE_RIGHT: begin
                                    fb_we <= 0;
                                    if (latched_x[5:3] == 3'h7) begin
                                        // right byte would overflow row — clip it
                                        if (draw_row == n - 1) begin
                                            drawing    <= 1'b0;
                                            draw_state <= DRAW_IDLE;
                                        end else begin
                                            draw_row   <= draw_row + 1;
                                            draw_state <= DRAW_FETCH;
                                        end
                                    end else begin
                                        fb_addr    <= latched_y * 8 + latched_x[5:3] + 1;
                                        draw_state <= DRAW_WRITE_RIGHT_WAIT;
                                    end
                                end

                                DRAW_WRITE_RIGHT_WAIT: begin
                                    fb_we      <= 0;
                                    draw_state <= DRAW_WRITE_RIGHT2;
                                end

                                DRAW_WRITE_RIGHT2: begin
                                    fb_data_in <= (mem_data_out << (8 - latched_x[2:0])) ^ fb_data_out;
                                    fb_we      <= 1;
                                    if (((mem_data_out << (8 - latched_x[2:0])) & fb_data_out) != 8'h0)
                                        V[15] <= 8'h1;
                                    if (draw_row == n - 1) begin
                                        drawing    <= 1'b0;
                                        draw_state <= DRAW_IDLE;
                                    end else begin
                                        draw_row   <= draw_row + 1;
                                        draw_state <= DRAW_FETCH;
                                    end
                                end

                                default: draw_state <= DRAW_IDLE;
                            endcase
                        end

                        4'hE: begin
                            case (kk)
                                8'h9E: begin
                                    if (keys[V[x][3:0]]) PC <= PC + 2;
                                end
                                8'hA1: begin
                                    if (!keys[V[x][3:0]]) PC <= PC + 2;
                                end
                                default: ;
                            endcase
                        end

                        4'hF: begin
                            case (kk)
                                8'h07: begin
                                    V[x] <= t_reg;
                                end

                                8'h0A: begin
                                    if (keys == 16'h0000) begin
                                        key_was_pressed <= 1'b0;
                                        PC              <= PC - 2;
                                    end else if (!key_was_pressed) begin
                                        V[x]            <= key_index;
                                        key_was_pressed <= 1'b1;
                                        // no rewind — advance normally
                                    end else begin
                                        // key still held after capture — wait for release
                                        PC <= PC - 2;
                                    end
                                end

                                8'h15: begin
                                    t_reg <= V[x];
                                end

                                8'h18: begin
                                    s_reg <= V[x];
                                end

                                8'h1E: begin
                                    I <= I + V[x];
                                end

                                8'h29: begin
                                    I <= (V[x][3:0] << 2) + V[x][3:0];
                                end

                                8'h33: begin
                                    case (bcd_state)
                                        BCD_IDLE: begin
                                            mem_we    <= 0;
                                            bcd_state <= BCD_HUNDREDS;
                                        end
                                        BCD_HUNDREDS: begin
                                            mem_data_in <= bcd_hundreds;
                                            mem_addr    <= I;
                                            mem_we      <= 1;
                                            bcd_state   <= BCD_TENS;
                                        end
                                        BCD_TENS: begin
                                            mem_data_in <= bcd_tens;
                                            mem_addr    <= I + 1;
                                            mem_we      <= 1;
                                            bcd_state   <= BCD_ONES;
                                        end
                                        BCD_ONES: begin
                                            mem_data_in <= bcd_ones;
                                            mem_addr    <= I + 2;
                                            mem_we      <= 1;
                                            bcd_state   <= BCD_IDLE;
                                        end
                                        default: ;
                                    endcase
                                end

                                8'h55: begin
                                    case (ld_state)
                                        LD_ST_IDLE: begin
                                            mem_we   <= 0;
                                            ld_index <= 0;
                                            ld_state <= LD_ST_WRITE;
                                        end

                                        LD_ST_WRITE: begin
                                            mem_addr    <= I + ld_index;
                                            mem_data_in <= V[ld_index];
                                            mem_we      <= 1;
                                            if (ld_index == x) begin
                                                ld_state <= LD_ST_IDLE;
                                                ld_index <= 0;
                                            end else begin
                                                ld_index <= ld_index + 1;
                                            end
                                        end
                                        
                                        default: ;
                                    endcase
                                end

                                8'h65: begin
                                    case (ld_state)
                                        LD_RD_IDLE: begin
                                            ld_index <= 0;
                                            ld_state <= LD_RD_FETCH;
                                        end
                                        LD_RD_FETCH: begin
                                            mem_addr <= I + ld_index;
                                            ld_state <= LD_RD_STORE;
                                        end
                                        LD_RD_STORE: begin
                                            if (ld_index <= x) begin
                                                V[ld_index] <= mem_data_out;
                                                ld_index    <= ld_index + 1;
                                                ld_state    <= LD_RD_FETCH;
                                            end else begin
                                                ld_state <= LD_RD_IDLE;
                                            end
                                        end
                                        default: ;
                                    endcase
                                end

                                default: ;
                            endcase
                        end

                        default: ;
                    endcase
                end

                default: ;
            endcase
            state <= next_state;
        end
    end

    // Block 2 - combinational - next state logic
    always @(*) begin
        case (state)
            FETCH_HIGH: next_state = FETCH_LOW;
            FETCH_LOW:  next_state = DECODE;
            DECODE:     next_state = EXECUTE;
            EXECUTE: begin
                if (execution_done_comb)
                    next_state = FETCH_HIGH;
                else
                    next_state = EXECUTE;
            end
            default: next_state = FETCH_HIGH;
        endcase
    end

    // Block 3 - combinational - key indexer
    always @(*) begin
        key_index = 4'h0;
        if      (keys[0])  key_index = 4'hF;
        else if (keys[1])  key_index = 4'h0;
        else if (keys[2])  key_index = 4'hE;
        else if (keys[3])  key_index = 4'hD;
        else if (keys[4])  key_index = 4'h1;
        else if (keys[5])  key_index = 4'h2;
        else if (keys[6])  key_index = 4'h3;
        else if (keys[7])  key_index = 4'hA;
        else if (keys[8])  key_index = 4'h4;
        else if (keys[9])  key_index = 4'h5;
        else if (keys[10]) key_index = 4'h6;
        else if (keys[11]) key_index = 4'hB;
        else if (keys[12]) key_index = 4'h7;
        else if (keys[13]) key_index = 4'h8;
        else if (keys[14]) key_index = 4'h9;
        else if (keys[15]) key_index = 4'hC;
    end

    // Block 4 - combinational - execution done
    always @(*) begin
        execution_done_comb = 0;
        if (state == EXECUTE) begin
            case (op)
                4'h1: execution_done_comb = 1;
                4'h2: execution_done_comb = 1;
                4'h3: execution_done_comb = 1;
                4'h4: execution_done_comb = 1;
                4'h5: execution_done_comb = 1;
                4'h6: execution_done_comb = 1;
                4'h7: execution_done_comb = 1;
                4'h8: execution_done_comb = 1;
                4'h9: execution_done_comb = 1;
                4'hA: execution_done_comb = 1;
                4'hB: execution_done_comb = 1;
                4'hC: execution_done_comb = 1;
                4'hE: execution_done_comb = 1;
                4'h0: execution_done_comb = (kk == 8'hE0) || (kk == 8'hEE);
                4'hD: execution_done_comb = (draw_state == DRAW_IDLE) && (draw_row != 4'h0);
                4'hF: begin
                    case (kk)
                        8'h07: execution_done_comb = 1;
                        8'h0A: execution_done_comb = 1;
                        8'h15: execution_done_comb = 1;
                        8'h18: execution_done_comb = 1;
                        8'h1E: execution_done_comb = 1;
                        8'h29: execution_done_comb = 1;
                        8'h33: execution_done_comb = (bcd_state == BCD_ONES);
                        8'h55: execution_done_comb = (ld_state == LD_ST_WRITE) && (ld_index == x);
                        8'h65: execution_done_comb = (ld_state == LD_RD_STORE) && (ld_index == x);
                        default: execution_done_comb = 1;
                    endcase
                end
                default: execution_done_comb = 1;
            endcase
        end
    end

endmodule