`timescale 1ns / 1ps
//======================================================================
// control_unit.v -- Control blocks
//   control_unit : main decoder + ALU decoder (ID stage)
//   imm_gen      : immediate generator (ID stage)
//   pc_src_logic : next-PC select, PCSrc = Jump | (Branch & taken) (EX)
//
// Supported instructions (23):
//   R-type : add sub and or xor sll srl slt
//   I-type : addi andi ori xori slli srli slti
//   Memory : lw sw
//   Branch : beq bne blt bge
//   Jump   : jal jalr
//

//======================================================================
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg        reg_write,
    output reg  [1:0] imm_src,     // 00=I 01=S 10=B 11=J
    output reg        alu_src_a,   // 0 = rs1 , 1 = PC
    output reg        alu_src_b,   // 0 = rs2 , 1 = immediate
    output reg        mem_write,
    output reg  [1:0] result_src,  // 00=ALU 01=MemData 10=PC+4
    output reg        branch,
    output reg        jump,
    output reg  [2:0] alu_control
);

    localparam OP_R      = 7'b0110011;
    localparam OP_I_ALU  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;

    localparam ALU_ADD = 3'b000, ALU_SUB = 3'b001, ALU_AND = 3'b010,
               ALU_OR  = 3'b011, ALU_XOR = 3'b100, ALU_SLL = 3'b101,
               ALU_SRL = 3'b110, ALU_SLT = 3'b111;

    // ------------- legality checks (unsupported -> NOP) -------------
    reg r_valid, i_valid, br_valid;
    always @(*) begin
        // R-type: funct7 must be 0000000, except SUB (0100000, funct3=000)
        case (funct3)
            3'b000:  r_valid = (funct7 == 7'b0000000) || (funct7 == 7'b0100000); // add/sub
            3'b001,                 // sll
            3'b010,                 // slt
            3'b100,                 // xor
            3'b101,                 // srl  (sra not supported)
            3'b110,                 // or
            3'b111:  r_valid = (funct7 == 7'b0000000);
            default: r_valid = 1'b0; // sltu
        endcase

        // I-type ALU
        case (funct3)
            3'b000, 3'b010, 3'b100, 3'b110, 3'b111: i_valid = 1'b1; // addi slti xori ori andi
            3'b001, 3'b101: i_valid = (funct7 == 7'b0000000);       // slli srli (srai not supported)
            default:        i_valid = 1'b0;                          // sltiu
        endcase

        // Branch: beq bne blt bge
        case (funct3)
            3'b000, 3'b001, 3'b100, 3'b101: br_valid = 1'b1;
            default:                        br_valid = 1'b0;
        endcase
    end

    // ---------------- main decoder ----------------
    reg [1:0] alu_op;   // 00 = ADD, 10 = use funct3/funct7

    always @(*) begin
        // safe defaults (NOP)
        reg_write  = 1'b0;
        imm_src    = 2'b00;
        alu_src_a  = 1'b0;
        alu_src_b  = 1'b0;
        mem_write  = 1'b0;
        result_src = 2'b00;
        branch     = 1'b0;
        jump       = 1'b0;
        alu_op     = 2'b00;

        case (opcode)
            OP_R: if (r_valid) begin
                reg_write = 1'b1; alu_op = 2'b10;
            end
            OP_I_ALU: if (i_valid) begin
                reg_write = 1'b1; imm_src = 2'b00; alu_src_b = 1'b1; alu_op = 2'b10;
            end
            OP_LOAD: if (funct3 == 3'b010) begin        // lw only
                reg_write = 1'b1; imm_src = 2'b00; alu_src_b = 1'b1;
                result_src = 2'b01;
            end
            OP_STORE: if (funct3 == 3'b010) begin       // sw only
                imm_src = 2'b01; alu_src_b = 1'b1; mem_write = 1'b1;
            end
            OP_BRANCH: if (br_valid) begin
                imm_src = 2'b10; branch = 1'b1;
            end
            OP_JAL: begin
                reg_write = 1'b1; imm_src = 2'b11;
                alu_src_a = 1'b1; alu_src_b = 1'b1;      // target = PC + imm
                result_src = 2'b10; jump = 1'b1;
            end
            OP_JALR: if (funct3 == 3'b000) begin
                reg_write = 1'b1; imm_src = 2'b00;
                alu_src_b = 1'b1;                        // target = rs1 + imm
                result_src = 2'b10; jump = 1'b1;
            end
            default: ; // NOP
        endcase
    end

    // ---------------- ALU decoder ----------------
    always @(*) begin
        if (alu_op == 2'b00)
            alu_control = ALU_ADD;
        else begin
            case (funct3)
                3'b000:  alu_control = (opcode == OP_R && funct7[5]) ? ALU_SUB : ALU_ADD;
                3'b001:  alu_control = ALU_SLL;
                3'b010:  alu_control = ALU_SLT;
                3'b100:  alu_control = ALU_XOR;
                3'b101:  alu_control = ALU_SRL;
                3'b110:  alu_control = ALU_OR;
                3'b111:  alu_control = ALU_AND;
                default: alu_control = ALU_ADD;
            endcase
        end
    end

endmodule


//======================================================================
// imm_gen -- Immediate generator (I, S, B, J; no U-type)
//======================================================================
module imm_gen (
    input  wire [31:0] instr,
    input  wire [1:0]  imm_src,
    output reg  [31:0] imm_ext
);
    always @(*) begin
        case (imm_src)
            2'b00: imm_ext = {{20{instr[31]}}, instr[31:20]};                                          // I
            2'b01: imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};                             // S
            2'b10: imm_ext = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};  // B
            2'b11: imm_ext = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};// J
        endcase
    end
endmodule


//======================================================================
// pc_src_logic -- selects the branch/jump target when a jump is in EX
//                 or a branch in EX is taken
//======================================================================
module pc_src_logic (
    input  wire jump_e,
    input  wire branch_e,
    input  wire taken_e,
    output wire pc_src_e
);
    assign pc_src_e = jump_e | (branch_e & taken_e);
endmodule
