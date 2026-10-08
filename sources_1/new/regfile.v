`timescale 1ns / 1ps
//======================================================================
// regfile.v -- State-holding blocks
//   regfile    : 32 x 32-bit register file
//   pc_reg     : program counter
//   if_id_reg  : IF/ID  pipeline register
//   id_ex_reg  : ID/EX  pipeline register
//   ex_mem_reg : EX/MEM pipeline register
//   mem_wb_reg : MEM/WB pipeline register
//======================================================================

//----------------------------------------------------------------------
// regfile
//  - Two asynchronous read ports (ID), one rising-edge write port (WB)
//  - Write-through bypass: a same-cycle read of the register being
//    written returns the new value
//  - x0 is hardwired to zero
//----------------------------------------------------------------------
module regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire        we3,
    input  wire [4:0]  a1,
    input  wire [4:0]  a2,
    input  wire [4:0]  a3,
    input  wire [31:0] wd3,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] regs [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'd0;
    end

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we3 && (a3 != 5'd0))
            regs[a3] <= wd3;
    end

    assign rd1 = (a1 == 5'd0)        ? 32'd0 :
                 (we3 && (a3 == a1)) ? wd3   : regs[a1];
    assign rd2 = (a2 == 5'd0)        ? 32'd0 :
                 (we3 && (a3 == a2)) ? wd3   : regs[a2];
endmodule

//----------------------------------------------------------------------
// pc_reg -- holds its value while en = 0 (load-use stall)
//----------------------------------------------------------------------
module pc_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (rst)     pc <= 32'd0;
        else if (en) pc <= pc_next;
    end
endmodule

//----------------------------------------------------------------------
// if_id_reg -- clr = flush (taken branch/jump), en = 0 holds (stall)
//----------------------------------------------------------------------
module if_id_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        clr,
    input  wire        en,
    input  wire [31:0] instr_f,
    input  wire [31:0] pc_f,
    input  wire [31:0] pc_plus4_f,
    output reg  [31:0] instr_d,
    output reg  [31:0] pc_d,
    output reg  [31:0] pc_plus4_d
);
    always @(posedge clk) begin
        if (rst || clr) begin
            instr_d    <= 32'd0;
            pc_d       <= 32'd0;
            pc_plus4_d <= 32'd0;
        end else if (en) begin
            instr_d    <= instr_f;
            pc_d       <= pc_f;
            pc_plus4_d <= pc_plus4_f;
        end
    end
endmodule

//----------------------------------------------------------------------
// id_ex_reg -- clr inserts a bubble (load-use stall or flush)
//----------------------------------------------------------------------
module id_ex_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        clr,
    // control
    input  wire        reg_write_d,
    input  wire [1:0]  result_src_d,
    input  wire        mem_write_d,
    input  wire        jump_d,
    input  wire        branch_d,
    input  wire [2:0]  alu_control_d,
    input  wire        alu_src_a_d,
    input  wire        alu_src_b_d,
    input  wire [2:0]  funct3_d,
    // data
    input  wire [31:0] rd1_d,
    input  wire [31:0] rd2_d,
    input  wire [31:0] pc_d,
    input  wire [31:0] imm_ext_d,
    input  wire [31:0] pc_plus4_d,
    input  wire [4:0]  rs1_d,
    input  wire [4:0]  rs2_d,
    input  wire [4:0]  rd_d,

    output reg         reg_write_e,
    output reg  [1:0]  result_src_e,
    output reg         mem_write_e,
    output reg         jump_e,
    output reg         branch_e,
    output reg  [2:0]  alu_control_e,
    output reg         alu_src_a_e,
    output reg         alu_src_b_e,
    output reg  [2:0]  funct3_e,
    output reg  [31:0] rd1_e,
    output reg  [31:0] rd2_e,
    output reg  [31:0] pc_e,
    output reg  [31:0] imm_ext_e,
    output reg  [31:0] pc_plus4_e,
    output reg  [4:0]  rs1_e,
    output reg  [4:0]  rs2_e,
    output reg  [4:0]  rd_e
);
    always @(posedge clk) begin
        if (rst || clr) begin
            reg_write_e   <= 1'b0;   result_src_e <= 2'b00;  mem_write_e <= 1'b0;
            jump_e        <= 1'b0;   branch_e     <= 1'b0;   alu_control_e <= 3'b000;
            alu_src_a_e   <= 1'b0;   alu_src_b_e  <= 1'b0;   funct3_e    <= 3'b000;
            rd1_e <= 32'd0; rd2_e <= 32'd0; pc_e <= 32'd0;
            imm_ext_e <= 32'd0; pc_plus4_e <= 32'd0;
            rs1_e <= 5'd0; rs2_e <= 5'd0; rd_e <= 5'd0;
        end else begin
            reg_write_e   <= reg_write_d;   result_src_e <= result_src_d;
            mem_write_e   <= mem_write_d;   jump_e       <= jump_d;
            branch_e      <= branch_d;      alu_control_e <= alu_control_d;
            alu_src_a_e   <= alu_src_a_d;   alu_src_b_e  <= alu_src_b_d;
            funct3_e      <= funct3_d;
            rd1_e <= rd1_d; rd2_e <= rd2_d; pc_e <= pc_d;
            imm_ext_e <= imm_ext_d; pc_plus4_e <= pc_plus4_d;
            rs1_e <= rs1_d; rs2_e <= rs2_d; rd_e <= rd_d;
        end
    end
endmodule

//----------------------------------------------------------------------
// ex_mem_reg
//----------------------------------------------------------------------
module ex_mem_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        reg_write_e,
    input  wire [1:0]  result_src_e,
    input  wire        mem_write_e,
    input  wire [31:0] alu_result_e,
    input  wire [31:0] write_data_e,
    input  wire [31:0] pc_plus4_e,
    input  wire [4:0]  rs2_e,
    input  wire [4:0]  rd_e,

    output reg         reg_write_m,
    output reg  [1:0]  result_src_m,
    output reg         mem_write_m,
    output reg  [31:0] alu_result_m,
    output reg  [31:0] write_data_m,
    output reg  [31:0] pc_plus4_m,
    output reg  [4:0]  rs2_m,
    output reg  [4:0]  rd_m
);
    always @(posedge clk) begin
        if (rst) begin
            reg_write_m  <= 1'b0;  result_src_m <= 2'b00; mem_write_m <= 1'b0;
            alu_result_m <= 32'd0; write_data_m <= 32'd0; pc_plus4_m  <= 32'd0;
            rs2_m        <= 5'd0;  rd_m         <= 5'd0;
        end else begin
            reg_write_m  <= reg_write_e;  result_src_m <= result_src_e;
            mem_write_m  <= mem_write_e;
            alu_result_m <= alu_result_e; write_data_m <= write_data_e;
            pc_plus4_m   <= pc_plus4_e;
            rs2_m        <= rs2_e;        rd_m         <= rd_e;
        end
    end
endmodule

//----------------------------------------------------------------------
// mem_wb_reg
//----------------------------------------------------------------------
module mem_wb_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        reg_write_m,
    input  wire [1:0]  result_src_m,
    input  wire [31:0] alu_result_m,
    input  wire [31:0] read_data_m,
    input  wire [31:0] pc_plus4_m,
    input  wire [4:0]  rd_m,

    output reg         reg_write_w,
    output reg  [1:0]  result_src_w,
    output reg  [31:0] alu_result_w,
    output reg  [31:0] read_data_w,
    output reg  [31:0] pc_plus4_w,
    output reg  [4:0]  rd_w
);
    always @(posedge clk) begin
        if (rst) begin
            reg_write_w  <= 1'b0;  result_src_w <= 2'b00;
            alu_result_w <= 32'd0; read_data_w  <= 32'd0;
            pc_plus4_w   <= 32'd0; rd_w         <= 5'd0;
        end else begin
            reg_write_w  <= reg_write_m;  result_src_w <= result_src_m;
            alu_result_w <= alu_result_m; read_data_w  <= read_data_m;
            pc_plus4_w   <= pc_plus4_m;   rd_w         <= rd_m;
        end
    end
endmodule
