`timescale 1ns / 1ps

module cache_system (
    input             clk,
    input             rst,
    // CPU interface signals:
    input             cpu_read,
    input             cpu_write,
    input      [31:0] cpu_address,
    input      [31:0] cpu_wdata,
    output     [7:0]  cpu_data_out,
    output            ready
);

    // Wires between cache controller and cache memory:
    wire [7:0]   index;
    wire [1:0]   offset;
    wire [21:0]  tag;
    wire [31:0]  cache_rdata;
    wire [21:0]  tag_out;
    wire         valid_out;
    wire         dirty_out;
    wire         hit;
    
    // Wires for main memory:
    wire [31:0] mem_address;
    wire        mem_read;
    wire        mem_write;
    wire [31:0] mem_data_out;
    wire        mem_ready;
    
    // When allocating, the data from main memory is loaded into cache.
    wire [31:0] cache_wdata;
    assign cache_wdata = mem_data_out;
    
    // Instantiate the Cache Controller.
    cache_controller cache_controller (
        .clk(clk),
        .rst(rst),
        .cpu_read(cpu_read),
        .cpu_write(cpu_write),
        .cpu_address(cpu_address),
        .mem_ready(mem_ready),
        .dirty_bit(dirty_out),
        .valid_bit(valid_out),
        .mem_data_in(mem_data_out),
        .mem_address(mem_address),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .cpu_data_out(cpu_data_out),
        .ready(ready),
        .hit(hit),
        .index(index),
        .offset(offset),
        .tag(tag)
    );
    
    // Instantiate the Cache Memory.
    cache_memory cache_memory (
        .clk(clk),
        .rst(rst),
        .index(index),
        .offset(offset),
        .read_en(cpu_read),     // For simplicity, use cpu_read for reading.
        .write_en(cpu_write),   // Write enable for write hits.
        .alloc_en((cpu_read || cpu_write) && ~hit),  // Allocate on miss.
        .cpu_wdata(cpu_wdata),
        .cache_wdata(cache_wdata),
        .cache_rdata(cache_rdata),
        .tag_in(tag),
        .tag_out(tag_out),
        .valid_out(valid_out),
        .dirty_out(dirty_out),
        .hit(hit)
    );
    
    // Instantiate the Main Memory (16 KB).
    main_memory main_memory (
        .clk(clk),
        .rst(rst),
        .mem_address(mem_address),
        .mem_read(mem_read),
        .mem_write(mem_write),
        // Here, we assume no write data comes from cache to main memory
        // (for simplicity, we tie mem_wdata to 0).
        .mem_wdata(32'b0),
        .mem_data_out(mem_data_out),
        .ready(mem_ready)
    );

endmodule
