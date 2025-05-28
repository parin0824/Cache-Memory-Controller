`timescale 1ns / 1ps
// ===============================
// Cache Memory (256 × 32-bit, direct-mapped)
// ===============================
module cache_memory (
    input  wire         clk,
    input  wire         rst,
    input  wire [7:0]   index,
    input  wire [1:0]   offset,
    input  wire         read_en,
    input  wire         write_en,   // for write-hits
    input  wire         alloc_en,   // on misses
    input  wire         cpu_write,  // tells us if the miss was a write
    input  wire [31:0]  cpu_wdata,  // CPU's write data
    input  wire [31:0]  cache_wdata,// data from memory on allocate
    output reg  [31:0]  cache_rdata,
    input  wire [21:0]  tag_in,
    output reg  [21:0]  tag_out,
    output reg          valid_out,
    output reg          dirty_out,
    output wire         hit,
    output wire [31:0]  wb_data     // data to write back on eviction
);

    // Storage arrays
    reg [21:0] tag_array   [0:255];
    reg        valid_array [0:255];
    reg        dirty_array [0:255];
    reg [31:0] data_array  [0:255];
    integer    i;

    // Hit logic
    assign hit     = valid_array[index] && (tag_array[index] == tag_in);
    // Always expose the full word for write-back
    assign wb_data = data_array[index];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 256; i = i + 1) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
                data_array[i]  <= 32'b0;
                tag_array[i]   <= 22'b0;
            end
            cache_rdata <= 32'b0;
            tag_out     <= 22'b0;
            valid_out   <= 1'b0;
            dirty_out   <= 1'b0;
        end else begin
            // On a cache read:
            if (read_en) begin
                cache_rdata <= data_array[index];
                tag_out     <= tag_array[index];
                valid_out   <= valid_array[index];
                dirty_out   <= dirty_array[index];
            end
            // On a write-hit (update full word):
            if (write_en) begin
                data_array[index]  <= cpu_wdata;
                dirty_array[index] <= 1'b1;
            end
            // On an allocate (miss):
            if (alloc_en) begin
                tag_array[index]   <= tag_in;
                valid_array[index] <= 1'b1;
                if (cpu_write) begin
                    // Write-allocate: store CPU's data
                    data_array[index]  <= cpu_wdata;
                    dirty_array[index] <= 1'b1;
                end else begin
                    // Read-miss allocate: store fetched block
                    data_array[index]  <= cache_wdata;
                    dirty_array[index] <= 1'b0;
                end
            end
        end
    end

endmodule
