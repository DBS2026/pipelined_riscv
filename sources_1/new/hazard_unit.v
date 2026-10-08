`timescale 1ns / 1ps
//======================================================================
// hazard_unit.v -- Pipeline hazard blocks
//   hazard_unit        : load-use stall + branch/jump flush
//   forwarding_unit    : EX-stage operand forwarding (MEM->EX, WB->EX)
//   store_forward_unit : MEM-stage store-data forwarding (lw -> sw)
//======================================================================

//----------------------------------------------------------------------
// hazard_unit
//  A store that only needs the loaded value as its DATA (rs2) does not
//  stall; store_forward_unit supplies that value in the MEM stage.
//  A store that needs it for the ADDRESS (rs1) still stalls.
//----------------------------------------------------------------------
module hazard_unit (
    input  wire [4:0] rs1_d,
    input  wire [4:0] rs2_d,
    input  wire       mem_write_d,   // instruction in ID is a store
    input  wire [4:0] rd_e,
    input  wire       load_e,        // instruction in EX is a load
    input  wire       pc_src_e,      // branch/jump in EX is taken

    output wire       stall_f,
    output wire       stall_d,
    output wire       flush_d,
    output wire       flush_e
);
    wire rs1_hit = (rd_e == rs1_d);
    wire rs2_hit = (rd_e == rs2_d) && !mem_write_d;

    wire load_use_hazard = load_e && (rd_e != 5'd0) && (rs1_hit || rs2_hit);

    assign stall_f = load_use_hazard;
    assign stall_d = load_use_hazard;
    assign flush_d = pc_src_e;
    assign flush_e = load_use_hazard || pc_src_e;
endmodule

//----------------------------------------------------------------------
// forwarding_unit  (10 = from MEM, 01 = from WB, 00 = register file)
//----------------------------------------------------------------------
module forwarding_unit (
    input  wire [4:0] rs1_e,
    input  wire [4:0] rs2_e,
    input  wire [4:0] rd_m,
    input  wire       reg_write_m,
    input  wire [4:0] rd_w,
    input  wire       reg_write_w,

    output reg  [1:0] forward_a_e,
    output reg  [1:0] forward_b_e
);
    always @(*) begin
        if (reg_write_m && (rd_m != 5'd0) && (rd_m == rs1_e))
            forward_a_e = 2'b10;
        else if (reg_write_w && (rd_w != 5'd0) && (rd_w == rs1_e))
            forward_a_e = 2'b01;
        else
            forward_a_e = 2'b00;
    end

    always @(*) begin
        if (reg_write_m && (rd_m != 5'd0) && (rd_m == rs2_e))
            forward_b_e = 2'b10;
        else if (reg_write_w && (rd_w != 5'd0) && (rd_w == rs2_e))
            forward_b_e = 2'b01;
        else
            forward_b_e = 2'b00;
    end
endmodule

//----------------------------------------------------------------------
// store_forward_unit
//  The instruction in WB is the one directly ahead of the store in MEM,
//  so its result is always the newest value of the store's rs2.
//----------------------------------------------------------------------
module store_forward_unit (
    input  wire [4:0] rs2_m,
    input  wire       mem_write_m,
    input  wire [4:0] rd_w,
    input  wire       reg_write_w,

    output wire       forward_store_m
);
    assign forward_store_m = mem_write_m && reg_write_w &&
                             (rd_w != 5'd0) && (rd_w == rs2_m);
endmodule
