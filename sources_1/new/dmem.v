`timescale 1ns / 1ps
//======================================================================
// dmem.v -- Data memory, 4 KB, byte-addressed, little-endian
//  Word access only (lw / sw). addr[1:0] is ignored, so every access
//  is word-aligned.
//======================================================================
module dmem (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:1023];
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'd0;
    end

    wire [9:0] word_addr = addr[11:2];

    // synchronous write
    always @(posedge clk) begin
        if (we)
            mem[word_addr] <= wdata;
    end

    // combinational read
    assign rdata = mem[word_addr];

endmodule
