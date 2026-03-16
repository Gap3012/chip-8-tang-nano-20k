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

    reg [2:0] state;        //State machine
    reg [2:0] next_state;   //Following state of the machine   
    reg execution_done_comb;//Flag for when execution state is done and we can restart the state machine, combinational

    //Registers
    reg [7:0] V [15:0];     //V0 to VF registers
    reg [11:0] I;           //Address register
    reg [7:0] t_reg;        //Timer register
    reg [7:0] s_reg;        //Sound register
    reg [11:0] PC;          //Program Counter, stores the address of instruction to fetch
    reg [3:0] SP;           //Stack pointer, points to current stack level to return
    reg [11:0] stack [15:0];//16x12-bit stack with addresses, so we can have 16 levels of nested function calls
    reg [15:0] IR;          //Instruction Register, stores the fetched instruction for decode

    reg [15:0] lfsr;        //16-bit LFSR for random number generation

    //Decode variables
    wire [3:0] op           = IR[15:12];
    wire [3:0] x            = IR[11:8];
    wire [3:0] y            = IR[7:4];
    wire [3:0] n            = IR[3:0];
    wire [7:0] kk           = IR[7:0];
    wire [11:0] nnn         = IR[11:0];
    wire [8:0] add_result   = V[x] + V[y];
    wire [3:0] SP_minus1    = SP - 1;

    //Needed for execution
    integer i;

    //Key presses
    reg [3:0] key_index;

    //DXYN instruction
    localparam DRAW_IDLE    = 2'd0;
    localparam DRAW_FETCH   = 2'd1;
    localparam DRAW_WRITE   = 2'd2;

    reg [1:0] draw_state;    
    reg [3:0] draw_row;     //Sprites can go from N=1 to N=15 

    wire [5:0] wrapped_x = V[x] & 6'h3F;                //This is equal to doing V[X] % 64
    wire [4:0] wrapped_y = (V[y] + draw_row) & 5'h1F;   //This is equal to doing (V[y] + draw_row) % 32
    wire [2:0] bit_pos = wrapped_x[2:0];                //This is equivalent to doing x % 8. To find which exact pixel to draw from that word

    //BCD Instruction
    localparam BCD_IDLE     = 2'd0;
    localparam BCD_HUNDREDS = 2'd1;
    localparam BCD_TENS     = 2'd2;
    localparam BCD_ONES     = 2'd3;

    reg [1:0] bcd_state;

    wire [7:0] bcd_hundreds = V[x] / 100;
    wire [7:0] bcd_tens     = (V[x] / 10) % 10;
    wire [7:0] bcd_ones     = V[x] % 10;

    //Fx55
    reg [3:0] ld_index;                                 //4-bits from 0 to 15. Useful in both Fx55 and Fx65
    reg [1:0] ld_state;                                 //2-bits from 0 to 4. Useful in both Fx55 and Fx65

    localparam LD_ST_IDLE   = 2'd0;
    localparam LD_ST_WRITE  = 2'd1;                     //Either writes to mem or reads from memory

    //Fx65
    localparam LD_RD_IDLE   = 2'd0;
    localparam LD_RD_FETCH  = 2'd1;
    localparam LD_RD_STORE  = 2'd2;

    // Block 1 - sequential - state register update
    always @(posedge clk) begin
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[11] ^ lfsr[10]};    //Generate randomness at full speed
        if (rst) begin
            state <= FETCH_HIGH;
            PC    <= 12'h200;
            SP    <= 4'd0;
            IR    <= 16'h0000;
            I     <= 12'h000;
            lfsr <= 16'hACE1;           // non-zero seed

            draw_state <= DRAW_IDLE;
            bcd_state <= BCD_HUNDREDS;
            ld_state <= LD_ST_IDLE;

            for (i = 0; i < 16; i = i + 1)
                V[i] <= 8'h00;

            t_reg <= 8'h00;
            s_reg <= 8'h00;
        end
        else if(cpu_tick) begin
            case (state)
                FETCH_HIGH: begin
                    mem_addr <= PC; //Set address bus to read memory, will take one cycle to happen so we can't read yet
                    PC <= PC + 1;   //Increment Program Counter
                    fb_rst <= 0;    //Deassert fb reset just in case
                    mem_we <= 0;    //Deassert memory we just in case
                end

                FETCH_LOW: begin
                    mem_addr <= PC;                 //Set address bus to read memory, will take one cycle to happen so we can read the High Byte now
                    IR[15:8] <= mem_data_out;       //Reading High Byte that is now available
                    PC <= PC + 1;                   //Increment Program Counter
                end

                DECODE: begin
                    IR[7:0] <= mem_data_out;        //Reading Low Byte that is now available
                end

                EXECUTE: begin
                    case (op)
                        4'h0: begin
                            case (kk)
                                8'hE0: begin        //Clear Display
                                    fb_rst <= 1;    
                                    
                                end

                                8'hEE: begin            //Return from Subroutine
                                    PC <= stack[SP_minus1];  // evaluates to stack[SP-1] correctly
                                    SP <= SP_minus1;
                                    
                                end

                                default: ;
                            endcase
                        end

                        4'h1: begin                 //JP addr instruction
                            PC <= nnn;      
                            
                        end

                        4'h2: begin                 //Call Subroutine
                            stack[SP] <= PC;        //Store actual program counter
                            SP <= SP + 1;           //Increment stack pointer
                            PC <= nnn;              //Set program counter to subroutine call address
                            
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
                                4'h0: begin
                                    V[x] <= V[y];
                                end

                                4'h1: begin
                                    V[x] <= V[x] | V[y];
                                end

                                4'h2: begin
                                    V[x] <= V[x] & V[y];
                                end

                                4'h3: begin
                                    V[x] <= V[x] ^ V[y];
                                end                     

                                4'h4: begin
                                    V[x] <= add_result[7:0];
                                    V[15] <= add_result[8]; //VF
                                end           

                                4'h5: begin
                                    if (V[x] > V[y]) V[15] <= 8'h1;
                                    else V[15] <= 8'h0;
                                    V[x] <= V[x] - V[y];
                                end

                                4'h6: begin
                                    V[15] <= V[x][0];   //LSB of Vx goes to VF
                                    V[x] <= V[x] >> 1;  //Shift right by 1. Is dividing by 2
                                end

                                4'h7: begin
                                    if (V[y] > V[x]) V[15] <= 8'h1;
                                    else V[15] <= 8'h0;
                                    V[x] <= V[y] - V[x];
                                end

                                4'hE: begin
                                    V[15] <= V[x][7];   //MSB of Vx goes to VF
                                    V[x] <= V[x] << 1;  //Shift lefy by 1. Is multiplying by 2
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
                            V[x] <= lfsr[7:0] & kk;
                            
                        end

                        4'hD: begin
                            case (draw_state)
                                DRAW_IDLE: begin
                                    draw_row <= 4'h0;   //Set draw row to the first row
                                    V[15] <= 8'h0;      //Set collision flag to 0. VF
                                    fb_we <= 0;         //Set Write Enable to 0 just in case
                                    draw_state <= DRAW_FETCH;
                                end

                                DRAW_FETCH: begin
                                    fb_we <= 0;         //To avoid corrupting data
                                    mem_addr <= I + draw_row;                   //Request sprite byte
                                    //Compute framebuffer address
                                    fb_addr <= wrapped_y * 8 + wrapped_x[5:3];  //This is equivalent to 8y + x/8. Dividing by 8 is shifing right by 3 pos
                                    draw_state <= DRAW_WRITE;
                                end

                                DRAW_WRITE: begin
                                    //XOR into framebuffer
                                    fb_data_in <= mem_data_out ^ fb_data_out;
                                    fb_we <= 1;
                                    //Check for collision
                                    if ((mem_data_out & fb_data_out) != 8'h0)
                                        V[15] <= 8'h1;
                                    if (draw_row == n - 1) begin
                                        draw_state <= DRAW_IDLE;    //Reset, we are done drawing
                                        
                                    end
                                    else begin
                                        draw_row <= draw_row + 1;   //Next row pls
                                        draw_state <= DRAW_FETCH;
                                    end
                                end

                                default: begin
                                    
                                    draw_state <= DRAW_IDLE;
                                end

                            endcase
                        end

                        4'hE: begin
                            case(kk)
                                8'h9E: begin
                                    if (keys[V[x][3:0]])  // only use lower nibble, guaranteed 0-15)
                                        PC <= PC + 2;
                                    
                                end

                                8'hA1: begin
                                    if (!keys[V[x][3:0]])  // only use lower nibble, guaranteed 0-15)
                                        PC <= PC + 2;
                                                                        
                                end

                                default: begin
                                    
                                end
                            endcase
                        end

                        4'hF: begin
                            case(kk)
                                8'h07: begin
                                    V[x] <= t_reg;
                                    
                                end

                                8'h0A: begin
                                    if (keys != 16'h0000) begin        // any key pressed?
                                        V[x] <= key_index;             // store which key
                                                   // now we're done
                                    end
                                    // if no key pressed, execution_done stays 0
                                    // CPU stays in EXECUTE, falls back here every cpu_tick                                    
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
                                    I <= (V[x][3:0] << 2) + V[x][3:0];  // x*4 + x = x*5 so its cheaper than x5 mult
                                    
                                end

                                8'h33: begin
                                    case(bcd_state)
                                        BCD_IDLE: begin
                                            mem_we <= 0;
                                            bcd_state <= BCD_HUNDREDS;
                                        end

                                        BCD_HUNDREDS: begin
                                            mem_data_in <= bcd_hundreds;
                                            mem_addr <= I;
                                            mem_we <= 1;
                                            bcd_state <= BCD_TENS;
                                        end

                                        BCD_TENS: begin
                                            mem_data_in <= bcd_tens;
                                            mem_addr <= I + 1;
                                            mem_we <= 1;
                                            bcd_state <= BCD_ONES;
                                        end

                                        BCD_ONES: begin
                                            mem_data_in <= bcd_ones;
                                            mem_addr <= I + 2;
                                            mem_we <= 1;
                                            bcd_state <= BCD_IDLE;
                                            
                                        end
                                    endcase
                                end

                                8'h55: begin
                                    case(ld_state)
                                        LD_ST_IDLE: begin
                                            mem_we <= 0;
                                            ld_index <= 0;
                                            ld_state <= LD_ST_WRITE;
                                        end

                                        LD_ST_WRITE: begin
                                            if (ld_index <= x) begin        //If load index less or equal to x. When it reaches x+1 it`s done
                                                mem_addr <= I + ld_index;   //Address I + index 
                                                mem_data_in <= V[ld_index]; //V[i], from V0 to VF
                                                mem_we <= 1;                //Write enable
                                                ld_index <= ld_index + 1;
                                            end else begin
                                                ld_state <= LD_ST_IDLE;
                                                mem_we <= 0;
                                                
                                            end
                                        end

                                        default: begin
                                            
                                        end
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
                                                V[ld_index] <= mem_data_out;    //Data is now available
                                                ld_index <= ld_index + 1;
                                                ld_state <= LD_RD_FETCH;
                                            end else begin
                                                ld_state <= LD_RD_IDLE;
                                                
                                            end
                                        end

                                        default: begin
                                            
                                        end
                                    endcase
                                end
                            endcase
                        end

                    endcase
                end

                default: begin
                    
                end
            
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
                    next_state = EXECUTE;  // stay here
            end
            default: next_state = FETCH_HIGH;
        endcase
    end

    // Block 3 - combinational - key indexer
    always @(*) begin
        key_index = 4'h0;  // default
        if      (keys[0])  key_index = 4'h0;
        else if (keys[1])  key_index = 4'h1;
        else if (keys[2])  key_index = 4'h2;
        else if (keys[3])  key_index = 4'h3;
        else if (keys[4])  key_index = 4'h4;
        else if (keys[5])  key_index = 4'h5;
        else if (keys[6])  key_index = 4'h6;
        else if (keys[7])  key_index = 4'h7;
        else if (keys[8])  key_index = 4'h8;
        else if (keys[9])  key_index = 4'h9;
        else if (keys[10]) key_index = 4'hA;
        else if (keys[11]) key_index = 4'hB;
        else if (keys[12]) key_index = 4'hC;
        else if (keys[13]) key_index = 4'hD;
        else if (keys[14]) key_index = 4'hE;
        else if (keys[15]) key_index = 4'hF;
    end

    // Block 4 - combinational execution done calculator, to update instantly
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
                        8'h0A: execution_done_comb = (keys != 16'h0000);
                        8'h15: execution_done_comb = 1;
                        8'h18: execution_done_comb = 1;
                        8'h1E: execution_done_comb = 1;
                        8'h29: execution_done_comb = 1;
                        8'h33: execution_done_comb = (bcd_state == BCD_ONES);
                        8'h55: execution_done_comb = (ld_state == LD_ST_WRITE) && (ld_index > x);
                        8'h65: execution_done_comb = (ld_state == LD_RD_STORE) && (ld_index > x);
                        default: execution_done_comb = 1;
                    endcase
                end
                default: execution_done_comb = 1;
            endcase
        end
    end

endmodule