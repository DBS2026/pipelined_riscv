`timescale 1ns / 1ps

module riscv_top #(
    parameter IMEM_FILE = "program.hex"
) (
    input  wire clk,
    input  wire rst,
    output wire pc_f1
);

    // ---------------------------------------------------------------
    // wires
    // ---------------------------------------------------------------
    // hazard / forwarding
    wire        stall_f, stall_d, flush_d, flush_e;
    wire [1:0]  forward_a_e, forward_b_e;
    wire        forward_store_m;

    // IF
    wire [31:0] pc_f, pc_next_f, pc_plus4_f, instr_f;

    // ID
    wire [31:0] instr_d, pc_d, pc_plus4_d;
    wire        reg_write_d, alu_src_a_d, alu_src_b_d, mem_write_d, branch_d, jump_d;
    wire [1:0]  result_src_d, imm_src_d;
    wire [2:0]  alu_control_d;
    wire [31:0] imm_ext_d, rd1_d, rd2_d;

    wire [6:0]  opcode_d = instr_d[6:0];
    wire [2:0]  funct3_d = instr_d[14:12];
    wire [6:0]  funct7_d = instr_d[31:25];
    wire [4:0]  rs1_d    = instr_d[19:15];
    wire [4:0]  rs2_d    = instr_d[24:20];
    wire [4:0]  rd_d     = instr_d[11:7];

    // EX
    wire        reg_write_e, alu_src_a_e, alu_src_b_e, mem_write_e, branch_e, jump_e;
    wire [1:0]  result_src_e;
    wire [2:0]  alu_control_e, funct3_e;
    wire [31:0] rd1_e, rd2_e, pc_e, imm_ext_e, pc_plus4_e;
    wire [4:0]  rs1_e, rs2_e, rd_e;
    wire [31:0] src_a_e, src_b_e, alu_a_e, alu_b_e, alu_result_e;
    wire [31:0] branch_target_e, pc_target_e;
    wire        alu_zero_e, taken_e, pc_src_e;

    // jal/jalr target: ALU result with bit 0 cleared (RISC-V spec)
    wire [31:0] jump_target_e = {alu_result_e[31:1], 1'b0};

    // MEM
    wire        reg_write_m, mem_write_m;
    wire [1:0]  result_src_m;
    wire [31:0] alu_result_m, write_data_m, pc_plus4_m;
    wire [4:0]  rs2_m, rd_m;
    wire [31:0] fwd_value_m, store_data_m, read_data_m;

    // WB
    wire        reg_write_w;
    wire [1:0]  result_src_w;
    wire [31:0] alu_result_w, read_data_w, pc_plus4_w, result_w;
    wire [4:0]  rd_w;
    assign pc_f1=pc_f;
    // =================================================================
    // IF stage
    // =================================================================
    mux2 u_pc_mux (
        .d0 (pc_plus4_f), .d1 (pc_target_e), .sel (pc_src_e), .y (pc_next_f)
    );

    pc_reg u_pc (
        .clk (clk), .rst (rst), .en (~stall_f),
        .pc_next (pc_next_f), .pc (pc_f)
    );

    adder u_pc_plus4 (
        .a (pc_f), .b (32'd4), .y (pc_plus4_f)
    );

    imem #(.MEM_FILE(IMEM_FILE)) u_imem (
        .addr (pc_f), .instr (instr_f)
    );

    if_id_reg u_if_id (
        .clk (clk), .rst (rst), .clr (flush_d), .en (~stall_d),
        .instr_f (instr_f), .pc_f (pc_f), .pc_plus4_f (pc_plus4_f),
        .instr_d (instr_d), .pc_d (pc_d), .pc_plus4_d (pc_plus4_d)
    );

    // =================================================================
    // ID stage
    // =================================================================
    control_unit u_ctrl (
        .opcode      (opcode_d),
        .funct3      (funct3_d),
        .funct7      (funct7_d),
        .reg_write   (reg_write_d),
        .imm_src     (imm_src_d),
        .alu_src_a   (alu_src_a_d),
        .alu_src_b   (alu_src_b_d),
        .mem_write   (mem_write_d),
        .result_src  (result_src_d),
        .branch      (branch_d),
        .jump        (jump_d),
        .alu_control (alu_control_d)
    );

    regfile u_regfile (
        .clk (clk), .rst (rst),
        .we3 (reg_write_w),
        .a1  (rs1_d), .a2 (rs2_d), .a3 (rd_w),
        .wd3 (result_w),
        .rd1 (rd1_d), .rd2 (rd2_d)
    );

    imm_gen u_imm (
        .instr (instr_d), .imm_src (imm_src_d), .imm_ext (imm_ext_d)
    );

    hazard_unit u_hazard (
        .rs1_d       (rs1_d),
        .rs2_d       (rs2_d),
        .mem_write_d (mem_write_d),
        .rd_e        (rd_e),
        .load_e      (result_src_e[0]),   // result_src 01 = load
        .pc_src_e    (pc_src_e),
        .stall_f     (stall_f),
        .stall_d     (stall_d),
        .flush_d     (flush_d),
        .flush_e     (flush_e)
    );

    id_ex_reg u_id_ex (
        .clk (clk), .rst (rst), .clr (flush_e),
        .reg_write_d (reg_write_d), .result_src_d (result_src_d),
        .mem_write_d (mem_write_d), .jump_d (jump_d), .branch_d (branch_d),
        .alu_control_d (alu_control_d), .alu_src_a_d (alu_src_a_d),
        .alu_src_b_d (alu_src_b_d), .funct3_d (funct3_d),
        .rd1_d (rd1_d), .rd2_d (rd2_d), .pc_d (pc_d), .imm_ext_d (imm_ext_d),
        .pc_plus4_d (pc_plus4_d), .rs1_d (rs1_d), .rs2_d (rs2_d), .rd_d (rd_d),
        .reg_write_e (reg_write_e), .result_src_e (result_src_e),
        .mem_write_e (mem_write_e), .jump_e (jump_e), .branch_e (branch_e),
        .alu_control_e (alu_control_e), .alu_src_a_e (alu_src_a_e),
        .alu_src_b_e (alu_src_b_e), .funct3_e (funct3_e),
        .rd1_e (rd1_e), .rd2_e (rd2_e), .pc_e (pc_e), .imm_ext_e (imm_ext_e),
        .pc_plus4_e (pc_plus4_e), .rs1_e (rs1_e), .rs2_e (rs2_e), .rd_e (rd_e)
    );

    // =================================================================
    // EX stage
    // =================================================================
    forwarding_unit u_fwd (
        .rs1_e (rs1_e), .rs2_e (rs2_e),
        .rd_m (rd_m), .reg_write_m (reg_write_m),
        .rd_w (rd_w), .reg_write_w (reg_write_w),
        .forward_a_e (forward_a_e), .forward_b_e (forward_b_e)
    );

    mux3 u_fwd_a_mux (
        .d0 (rd1_e), .d1 (result_w), .d2 (fwd_value_m),
        .sel (forward_a_e), .y (src_a_e)
    );

    mux3 u_fwd_b_mux (
        .d0 (rd2_e), .d1 (result_w), .d2 (fwd_value_m),
        .sel (forward_b_e), .y (src_b_e)
    );

    mux2 u_alu_src_a_mux (
        .d0 (src_a_e), .d1 (pc_e), .sel (alu_src_a_e), .y (alu_a_e)
    );

    mux2 u_alu_src_b_mux (
        .d0 (src_b_e), .d1 (imm_ext_e), .sel (alu_src_b_e), .y (alu_b_e)
    );

    alu u_alu (
        .a (alu_a_e), .b (alu_b_e), .alu_control (alu_control_e),
        .result (alu_result_e), .zero (alu_zero_e)
    );

    adder u_branch_adder (
        .a (pc_e), .b (imm_ext_e), .y (branch_target_e)
    );

    branch_comp u_branch_comp (
        .a (src_a_e), .b (src_b_e), .funct3 (funct3_e), .taken (taken_e)
    );

    pc_src_logic u_pc_src (
        .jump_e (jump_e), .branch_e (branch_e), .taken_e (taken_e),
        .pc_src_e (pc_src_e)
    );

    mux2 u_target_mux (
        .d0 (branch_target_e), .d1 (jump_target_e), .sel (jump_e), .y (pc_target_e)
    );

    ex_mem_reg u_ex_mem (
        .clk (clk), .rst (rst),
        .reg_write_e (reg_write_e), .result_src_e (result_src_e),
        .mem_write_e (mem_write_e), .alu_result_e (alu_result_e),
        .write_data_e (src_b_e), .pc_plus4_e (pc_plus4_e),
        .rs2_e (rs2_e), .rd_e (rd_e),
        .reg_write_m (reg_write_m), .result_src_m (result_src_m),
        .mem_write_m (mem_write_m), .alu_result_m (alu_result_m),
        .write_data_m (write_data_m), .pc_plus4_m (pc_plus4_m),
        .rs2_m (rs2_m), .rd_m (rd_m)
    );

    // =================================================================
    // MEM stage
    // =================================================================
    // Value forwarded to EX: PC+4 for jal/jalr (result_src 10), else ALU result
    mux2 u_link_fwd_mux (
        .d0 (alu_result_m), .d1 (pc_plus4_m), .sel (result_src_m[1]), .y (fwd_value_m)
    );

    store_forward_unit u_store_fwd (
        .rs2_m (rs2_m), .mem_write_m (mem_write_m),
        .rd_w (rd_w), .reg_write_w (reg_write_w),
        .forward_store_m (forward_store_m)
    );

    mux2 u_store_data_mux (
        .d0 (write_data_m), .d1 (result_w), .sel (forward_store_m), .y (store_data_m)
    );

    dmem u_dmem (
        .clk (clk), .we (mem_write_m), .addr (alu_result_m),
        .wdata (store_data_m), .rdata (read_data_m)
    );

    mem_wb_reg u_mem_wb (
        .clk (clk), .rst (rst),
        .reg_write_m (reg_write_m), .result_src_m (result_src_m),
        .alu_result_m (alu_result_m), .read_data_m (read_data_m),
        .pc_plus4_m (pc_plus4_m), .rd_m (rd_m),
        .reg_write_w (reg_write_w), .result_src_w (result_src_w),
        .alu_result_w (alu_result_w), .read_data_w (read_data_w),
        .pc_plus4_w (pc_plus4_w), .rd_w (rd_w)
    );

    // =================================================================
    // WB stage
    // =================================================================
    mux3 u_result_mux (
        .d0 (alu_result_w), .d1 (read_data_w), .d2 (pc_plus4_w),
        .sel (result_src_w), .y (result_w)
    );

endmodule
