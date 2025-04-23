`timescale 1ns / 1ps

module cache_memory (
    input clk,
    input rst,
    input  wire [7:0] index,      // 8-bit index for 256 cache lines
    input  wire [1:0] offset,     // 2-bit offset (external use; cache internal data is 32-bit)
    input  wire       read_en,    // Read enable
    input  wire       write_en,   // Write enable (for a write hit)
    input  wire       alloc_en,   // Allocation enable (on a miss)
    input  wire [31:0] cpu_wdata,  // Data from CPU for a write hit
    input  wire [31:0] cache_wdata,// Data from main memory on allocation
    output reg [31:0] cache_rdata, // 32-bit cached data output
    input  wire [21:0] tag_in,     // Incoming tag (22 bits)
    output reg [21:0] tag_out,     // Stored tag for the cache line
    output reg       valid_out,     // Valid bit for the cache line
    output reg       dirty_out,     // Dirty bit for the cache line
    output wire      hit            // Hit signal (computed inside the module)
);

    reg [21:0] tag_array   [0:255];
    reg        valid_array [0:255];
    reg        dirty_array [0:255];
    reg [31:0] data_array  [0:255];
    integer i;

    // Compute hit: the cache line is a hit if the stored tag equals tag_in and the valid bit is high.
    assign hit = ((tag_array[index] == tag_in) && valid_array[index]);

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
            // On a read, output the cache data and metadata.
            if (read_en) begin
                cache_rdata <= data_array[index];
                tag_out     <= tag_array[index];
                valid_out   <= valid_array[index];
                dirty_out   <= dirty_array[index];
            end
            
            // Write operation: update the data and mark the entry as dirty.
            if (write_en) begin
                data_array[index]  <= cpu_wdata;
                dirty_array[index] <= 1'b1;
            end

            // Allocation: fetch new data from main memory, update tag, and mark as valid (and clean).
            if (alloc_en) begin
                data_array[index]  <= cache_wdata;
                tag_array[index]   <= tag_in;
                valid_array[index] <= 1'b1;
                dirty_array[index] <= 1'b0;
            end
        end
    end

endmodule
