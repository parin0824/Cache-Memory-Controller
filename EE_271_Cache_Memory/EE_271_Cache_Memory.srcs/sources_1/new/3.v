`timescale 1ns / 1ps

module main_memory (
    input             clk,
    input             rst,          // Synchronous reset
    input      [31:0] mem_address,  // Byte address (must be 4-byte aligned)
    input             mem_read,     // High to perform a read operation
    input             mem_write,    // High to perform a write operation
    input      [31:0] mem_wdata,    // Data to be written (one 32-bit word)
    output reg [31:0] mem_data_out, // Data read from memory (one 32-bit word)
    output reg        ready         // Indicates that the operation is complete
);

    // 16 KB = 16,384 bytes. With 32-bit words (4 bytes each), we need 16,384/4 = 4096 words.
    // Force the synthesis tool to implement this memory as Block RAM.
    (* ram_style = "block" *)
    reg [31:0] mem_array [0:4095];

    // Note: We intentionally omit any initialization here so that synthesis won't try to
    // dissolve the memory into individual bits. For simulation, you can include initialization
    // in a separate file or inside synthesis directives if needed.

    // Use a synchronous reset (remove rst from the sensitivity list).
    always @(posedge clk) begin
        if (rst) begin
            // On reset, update outputs only.
            mem_data_out <= 32'b0;
            ready        <= 1'b0;
        end else begin
            if (mem_read) begin
                // Use mem_address[31:2] as the word index (convert 4-byte aligned address)
                mem_data_out <= mem_array[mem_address[31:2]];
                ready        <= 1'b1;
            end else if (mem_write) begin
                mem_array[mem_address[31:2]] <= mem_wdata;
                ready        <= 1'b1;
            end else begin
                ready        <= 1'b0;
            end
        end
    end

endmodule
