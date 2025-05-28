//`timescale 1ns / 1ps

//module top_level (
//    input  wire         clk,         // Primary clock input (e.g., 100 MHz)
//    input  wire         rst,         // System reset (active high)
//    // CPU interface signals:
//    input  wire         cpu_read,
//    input  wire         cpu_write,
//    input  wire [31:0]  cpu_address,
//    input  wire [31:0]  cpu_wdata,
//    output wire [7:0]   cpu_data_out,
//    output wire         ready
//);

//    // -------------------------------------------------------
//    // Clock Wizard Instantiation
//    // -------------------------------------------------------
//    // The Clocking Wizard IP (named clk_wiz_0) generates a slower clock.
//    // The following ports are assumed:
//    //   - clk_in1  : primary clock input.
//    //   - reset    : reset (active high) for the clocking wizard.
//    //   - clk_out1 : the generated slower clock.
//    //   - locked   : signal that goes high once the clock is stable.
//    wire slow_clk;
//    wire clk_locked; 
    
//    clk_wiz_0 clk_wiz_inst (
//        .clk_in1  (clk),         // Primary input clock (e.g., 100 MHz)
//        .reset    (rst),         // Reset input to the clock wizard (active high)
//        .clk_out1 (slow_clk),    // Generated slower clock (e.g., 10 MHz)
//        .locked   (clk_locked)   // Indicates that the output clock is stable
//    );
    
   
//    cache_system u_cache_system (
//        .clk         (slow_clk),      // Use the clock output from the Clock Wizard
//        .rst         (rst),           // System reset
//        .cpu_read    (cpu_read),
//        .cpu_write   (cpu_write),
//        .cpu_address (cpu_address),
//        .cpu_wdata   (cpu_wdata),
//        .cpu_data_out(cpu_data_out),
//        .ready       (ready)
//    );

//endmodule
