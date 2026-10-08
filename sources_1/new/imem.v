`timescale 1ns / 1ps
//======================================================================
// imem.v -- Instruction memory (combinational read ROM)
//  1024 x 32-bit words = 4 KB, loaded from a hex file via $readmemh.
//  Zero-filled first so words past the end of the program read as 0
//  (a NOP-like encoding) instead of X.
//======================================================================
module imem #(
    parameter MEM_FILE = "program.hex"
) (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] mem [0:1023];
    integer i;

    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'd0;
        $readmemh(MEM_FILE, mem);
    end

    assign instr = mem[addr[11:2]];

endmodule
