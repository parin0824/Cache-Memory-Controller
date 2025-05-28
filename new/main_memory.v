`timescale 1ns / 1ps
// ===============================
// Main Memory (16 KB single-port BRAM model)
// ===============================
module main_memory (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] mem_address,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] mem_wdata,
    output reg  [31:0] mem_data_out,
    output reg         ready
);
    // 16 KB = 4096 words × 32 bits
    (* ram_style = "block" *)
    reg [31:0] mem_array [0:4095];

    always @(posedge clk) begin
        if (rst) begin
            ready        <= 1'b0;
            mem_data_out <= 32'b0;
        end else begin
            if (mem_read) begin
                mem_data_out <= mem_array[mem_address[13:2]];
                ready        <= 1'b1;
            end else if (mem_write) begin
                mem_array[mem_address[13:2]] <= mem_wdata;
                ready        <= 1'b1;
            end else begin
                ready        <= 1'b0;
            end
        end
    end

endmodule
