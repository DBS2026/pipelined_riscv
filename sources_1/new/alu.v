`timescale 1ns / 1ps
//======================================================================
// alu.v -- Datapath arithmetic and selection blocks
//   alu          : 32-bit ALU (ADD SUB AND OR XOR SLL SRL SLT)
//   adder        : 32-bit adder (PC+4, branch target)
//   branch_comp  : branch condition (BEQ BNE BLT BGE)
//   mux2         : 2-to-1 multiplexer
//   mux3         : 3-to-1 multiplexer
//======================================================================

//----------------------------------------------------------------------
// alu
//----------------------------------------------------------------------
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);
    localparam ALU_ADD = 3'b000;
    localparam ALU_SUB = 3'b001;
    localparam ALU_AND = 3'b010;
    localparam ALU_OR  = 3'b011;
    localparam ALU_XOR = 3'b100;
    localparam ALU_SLL = 3'b101;
    localparam ALU_SRL = 3'b110;
    localparam ALU_SLT = 3'b111;

    always @(*) begin
        case (alu_control)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_AND: result = a & b;
            ALU_OR : result = a | b;
            ALU_XOR: result = a ^ b;
            ALU_SLL: result = a << b[4:0];
            ALU_SRL: result = a >> b[4:0];
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule

//----------------------------------------------------------------------
// adder
//----------------------------------------------------------------------
module adder (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] y
);
    assign y = a + b;
endmodule

//----------------------------------------------------------------------
// branch_comp -- evaluates the branch condition selected by funct3
//----------------------------------------------------------------------
module branch_comp (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  funct3,
    output reg         taken
);
    always @(*) begin
        case (funct3)
            3'b000:  taken = (a == b);                    // BEQ
            3'b001:  taken = (a != b);                    // BNE
            3'b100:  taken = ($signed(a) <  $signed(b));  // BLT
            3'b101:  taken = ($signed(a) >= $signed(b));  // BGE
            default: taken = 1'b0;
        endcase
    end
endmodule

//----------------------------------------------------------------------
// mux2 -- sel=0 -> d0, sel=1 -> d1
//----------------------------------------------------------------------
module mux2 #(parameter W = 32) (
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    input  wire         sel,
    output wire [W-1:0] y
);
    assign y = sel ? d1 : d0;
endmodule

//----------------------------------------------------------------------
// mux3 -- sel=00 -> d0, 01 -> d1, 10 -> d2 (11 -> d0)
//----------------------------------------------------------------------
module mux3 #(parameter W = 32) (
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    input  wire [W-1:0] d2,
    input  wire [1:0]   sel,
    output wire [W-1:0] y
);
    assign y = (sel == 2'b10) ? d2 :
               (sel == 2'b01) ? d1 : d0;
endmodule
