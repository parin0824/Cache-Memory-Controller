`timescale 1ns / 1ps
// ===============================
// Cache System (Top Module)
// ===============================
module cache_system (
    input  wire        clk,
    input  wire        rst,
    input  wire        cpu_read,
    input  wire        cpu_write,
    input  wire [31:0] cpu_address,
    input  wire [31:0] cpu_wdata,
    output wire [7:0]  cpu_data_out,
    output wire        ready
);

    // Clock Divider IP
    wire slow_clk, clk_locked;
    clk_divider_cache clk_div_inst (
        .clk_in1  (clk),
        .reset    (rst),
        .clk_out1 (slow_clk),
        .locked   (clk_locked)
    );

    // Wires between modules
    wire [7:0]   index;
    wire [1:0]   offset;
    wire [21:0]  tag;
    wire [31:0]  cache_rdata;
    wire [31:0]  mem_data_out;
    wire         valid_out, dirty_out, hit;
    wire         mem_read, mem_write, mem_ready;
    wire         cache_read_en;
    wire [31:0]  mem_address;
    wire [31:0]  cache_wdata = mem_data_out;
    wire [31:0]  wb_data;      // data to write back to memory

    // Cache controller
    cache_controller CC_Module (
        .clk           (slow_clk),
        .rst           (rst),
        .cpu_read      (cpu_read),
        .cpu_write     (cpu_write),
        .cpu_address   (cpu_address),
        .mem_ready     (mem_ready),
        .dirty_bit     (dirty_out),
        .valid_bit     (valid_out),
        .mem_data_in   (mem_data_out),
        .cache_data_in (cache_rdata),
        .mem_address   (mem_address),
        .mem_read      (mem_read),
        .mem_write     (mem_write),
        .cache_read_en (cache_read_en),
        .cpu_data_out  (cpu_data_out),
        .ready         (ready),
        .hit           (hit),
        .index         (index),
        .offset        (offset),
        .tag           (tag)
    );

    // Cache memory
    cache_memory Cache_Module (
        .clk         (slow_clk),
        .rst         (rst),
        .index       (index),
        .offset      (offset),
        .read_en     (cache_read_en),
        .write_en    (hit && cpu_write),
        .alloc_en    ((cpu_read || cpu_write) && !hit),
        .cpu_write   (cpu_write),
        .cpu_wdata   (cpu_wdata),
        .cache_wdata (cache_wdata),
        .cache_rdata (cache_rdata),
        .tag_in      (tag),
        .tag_out     (), 
        .valid_out   (valid_out),
        .dirty_out   (dirty_out),
        .hit         (hit),
        .wb_data     (wb_data)        // expose for write-back
    );

    // Main memory (16 KB)
    main_memory MM_Module (
        .clk         (slow_clk),
        .rst         (rst),
        .mem_address (mem_address),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .mem_wdata   (wb_data),       // now uses real cache data
        .mem_data_out(mem_data_out),
        .ready       (mem_ready)
    );

endmodule
