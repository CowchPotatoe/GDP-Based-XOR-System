// NOTE: In this GDP top module, start and restart are active-low at the pins.
//       They are inverted before entering the CU, so CU sees active-high start/restart.

module GDP_mod(sum, start, restart, clk, n, done);

  input        start, clk, restart;
  input  [7:0] n;
  output [7:0] sum;
  output       done;

  wire        WE, RAE, RBE, OE, IE;
  wire [1:0]  WA, RAA, RBA, SH;
  wire [2:0]  ALU;

  CU control (
    .IE(IE), .WE(WE), .WA(WA),
    .RAE(RAE), .RAA(RAA), .RBE(RBE), .RBA(RBA),
    .ALU(ALU), .SH(SH), .OE(OE),
    .start(~start), .clk(clk), .restart(~restart)
  );

  DP datapath (sum, n, clk, IE, WE, WA, RAE, RAA, RBE, RBA, ALU, SH, OE);

  assign done = OE;

endmodule


module CU(IE, WE, WA, RAE, RAA, RBE, RBA, ALU, SH, OE, start, clk, restart);

  input        start, clk, restart;   // active-high *inside* CU
  output reg   IE, WE, RAE, RBE, OE;
  output reg [1:0] WA, RAA, RBA, SH;
  output reg [2:0] ALU;

  reg [3:0] state, nextstate;

  // Change / add states per your state graph
  parameter S0 = 4'b0000; // idle/start state
  parameter S1 = 4'b0001; // input X -> R1
  parameter S2 = 4'b0010; // input Y -> R2
  parameter S3 = 4'b0011; // R3 <- NOT R1 (~X)
  parameter S4 = 4'b0100; // R3 <- R3 & R2 (~X & Y)
  parameter S5 = 4'b0101; // R2 <- NOT R2 (~Y)
  parameter S6 = 4'b0110; // R2 <- R1 & R2 (X & ~Y)
  parameter S7 = 4'b0111; // R0 <- R3 | R2 ((~X&Y)|(X&~Y))
  parameter S8 = 4'b1000; // Output Z (R0)


  initial state = S0;

  // State register (synchronous restart)
  always @(posedge clk) begin
    if (restart) state <= S0;
    else         state <= nextstate;
  end

  // Next-state logic (COMPLETE per your state graph)
  always @(*) begin
    nextstate = state; // default
    
    case (state)
          S0: begin
            if (start) nextstate = S1;
          end
          S1: begin
            nextstate = S2;       // read X
          end
          S2: begin
            nextstate = S3;       // read Y
          end
          S3: begin
            nextstate = S4;       // ~X
          end
          S4: begin
            nextstate = S5;       // ~X & Y
          end
          S5: begin
            nextstate = S6;       // ~Y 
          end
          S6: begin
            nextstate = S7;       // X & ~Y 
          end      
          S7: begin
            nextstate = S8;       // (~X & Y) or (X & ~Y)
          end
          S8: begin
            nextstate = S0;       // output, restart
          end
          default: nextstate = S0;
        endcase
  end

  // Output logic (COMPLETE per your state graph)
  always @(*) begin
    // Input and Write enable
    IE = (state == S1) || (state == S2); 
    // Write enable
    WE = (state == S1) || (state == S2) || (state == S3) || (state == S4) || (state == S5) || (state == S6) || (state == S7);
    // Write address
    WA[1] = (state == S2) || (state == S3) || (state == S4) || (state == S5) || (state == S6);
    WA[0] = (state == S1) || (state == S3) || (state == S4); 

    // Read-A enable
    RAE = (state == S3) || (state == S4) || (state == S5) || (state == S6) || (state == S7)|| (state == S8);
    // Port A read address
    RAA[1] = (state == S4) || (state == S5) || (state == S7);
    RAA[0] = (state == S3) || (state == S4) || (state == S6) || (state == S7);

    // Read-B enable
    RBE = (state == S4) || (state == S6) || (state == S7);
    // Port B read address
    RBA[1] = (state == S4) || (state == S6) || (state == S7);
    RBA[0] = 1'b0;
    // ALU
    ALU[2] = 1'b0;
    ALU[1] = (state == S3) || (state == S5) || (state == S7);
    ALU[0] = (state == S3) || (state == S4) || (state == S5) || (state == S6);   
    
    // Shifter
    SH = 2'b00;  
    // Output enable
    OE = (state == S8);
  end
endmodule


module DP(sum, nIn, clk, IE, WE, WA, RAE, RAA, RBE, RBA, ALU, SH, OE);

  input        clk, IE, WE, RAE, RBE, OE;
  input  [1:0] WA, RAA, RBA, SH;
  input  [2:0] ALU;
  input  [7:0] nIn;

  output wire [7:0] sum;

  reg  [7:0] rfIn;
  wire [7:0] RFa, RFb, aluOut, shOut, n;

  initial rfIn = 8'h00;

  always @(*) rfIn = n;

  mux8     muxs   (n, shOut, nIn, IE);
  Regfile  RF     (clk, RAA, RFa, RBA, RFb, WE, WA, rfIn, RAE, RBE);
  alu      theALU (RFa, RFb, ALU, aluOut);
  shifter  SHIFT  (shOut, aluOut, SH);
  buff     buffer1(sum, shOut, OE);

endmodule


// ALU
module alu (a, b, sel, out);
  input  [7:0] a, b;
  input  [2:0] sel;
  output reg [7:0] out;

  always @(*) begin
    case (sel)
      3'b000: out = a;       // PASSA
      3'b001: out = a & b;   // AND
      3'b010: out = a | b;   // OR
      3'b011: out = ~a;      // NOT (bitwise)
      3'b100: out = a + b;   // ADD
      3'b101: out = a - b;   // SUB
      3'b110: out = a + 8'd1;// INC
      3'b111: out = a - 8'd1;// DEC
    endcase
  end
endmodule


// Final buffer (tri-states output unless OE=1)
module buff(output reg [7:0] result, input [7:0] a, input buf1);
  always @(*) begin
    if (buf1 == 1'b1) result = a;
    else              result = 8'bzzzz_zzzz;
  end
endmodule


// 2-to-1 mux (sel = 0 -> choose a)
module mux8(output reg [7:0] result, input [7:0] a, input [7:0] b, input sel);
  always @(*) begin
    if (sel == 1'b0) result = a;
    else             result = b;
  end
endmodule


// Regfile for GDP
module Regfile(
  input        clk,
  input  [1:0] RAA,     // Port A read address
  output [7:0] ReadA,   // Port A read data
  input  [1:0] RBA,     // Port B read address
  output [7:0] ReadB,   // Port B read data
  input        WE,      // Write enable
  input  [1:0] WA,      // Write address
  input  [7:0] INPUT_D, // Write data
  input        RAE,     // Read-A enable
  input        RBE      // Read-B enable
);

  reg [7:0] REG_F [0:3];

  always @(posedge clk)
    if (WE) REG_F[WA] <= INPUT_D;

  assign ReadA = (RAE) ? REG_F[RAA] : 8'h00;
  assign ReadB = (RBE) ? REG_F[RBA] : 8'h00;

endmodule


// Shifter
module shifter(output reg [7:0] out, input [7:0] a, input [1:0] sh);
  always @(*) begin
    case (sh)
      2'b00: out = a;
      2'b01: out = a << 1;
      2'b10: out = a >> 1;
      2'b11: out = {a[6:0], a[7]}; // rotate-left by 1
    endcase
  end
endmodule
