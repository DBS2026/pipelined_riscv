`timescale 1ns / 1ps
//======================================================================
// tb_riscv.v -- self-checking testbench
//  Runs program.hex, then compares every register, the data-memory
//  words listed in expected.txt, and the load-use stall count.
//
//  iverilog -o sim tb_riscv.v riscv_top.v alu.v control_unit.v \
//           dmem.v imem.v regfile.v hazard_unit.v && vvp sim
//======================================================================
module tb_riscv;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    riscv_top #(.IMEM_FILE("program.hex")) dut (.clk(clk), .rst(rst));

    integer stall_cycles = 0, cycles = 0;
    always @(posedge clk) if (!rst) begin
        cycles = cycles + 1;
        if (dut.stall_f) stall_cycles = stall_cycles + 1;
    end

    integer fd, n, idx, errors, exp_stalls;
    reg [7:0]  kind;
    reg [31:0] val;

    initial begin
        $dumpfile("riscv.vcd");
        $dumpvars(0, tb_riscv);
        repeat (2) @(posedge clk);
        rst = 0;
        repeat (400) @(posedge clk);

        errors = 0; exp_stalls = -1;
        fd = $fopen("expected.txt", "r");
        if (fd == 0) begin $display("cannot open expected.txt"); $finish; end
        while (!$feof(fd)) begin
            n = $fscanf(fd, "%c %d %h\n", kind, idx, val);
            if (kind == "R" && n == 3) begin
                if (dut.u_regfile.regs[idx] !== val) begin
                    $display("FAIL x%0d = %h, expected %h", idx, dut.u_regfile.regs[idx], val);
                    errors = errors + 1;
                end
            end else if (kind == "M" && n == 3) begin
                if (dut.u_dmem.mem[idx] !== val) begin
                    $display("FAIL mem[%0d] = %h, expected %h", idx*4, dut.u_dmem.mem[idx], val);
                    errors = errors + 1;
                end
            end else if (kind == "S") begin
                exp_stalls = idx;
            end
        end
        $fclose(fd);

        if (stall_cycles !== exp_stalls) begin
            $display("FAIL stall cycles = %0d, expected %0d", stall_cycles, exp_stalls);
            errors = errors + 1;
        end

        $display("load-use stall cycles: %0d (expected %0d)", stall_cycles, exp_stalls);
        if (errors == 0) $display("*** ALL CHECKS PASSED ***");
        else             $display("*** %0d CHECK(S) FAILED ***", errors);
        $finish;
    end
endmodule
