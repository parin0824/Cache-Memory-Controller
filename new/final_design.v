// The file contains 3 Modules Cache Controller, Main Memory and Cache Memory. They are connect in Main Top Level Module 
// called cache system. Furthermore there is a IP Block of Clock Divder whose code is not present in this file just the clk_div_inst.
//There is a constrint file as well con1.xdc--set_param synth.elaboration.rodinMoreOptions {rt::set_parameter dissolveMemorySizeLimit 131072}
// It raises Vivado’s internal limit for how large a memory it will “dissolve” into registers before erroring.


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

    // Cache memory (1KB)
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
        .mem_wdata   (wb_data),       
        .mem_data_out(mem_data_out),
        .ready       (mem_ready)
    );

endmodule



// Cache Controller Module //

`timescale 1ns / 1ps

module cache_controller (
    input  wire         clk,
    input  wire         rst,
    input  wire         cpu_read,
    input  wire         cpu_write,
    input  wire [31:0]  cpu_address,
    input  wire         mem_ready,
    input  wire         dirty_bit,
    input  wire         valid_bit,
    input  wire [31:0]  mem_data_in,
    input  wire [31:0]  cache_data_in,
    output reg  [31:0]  mem_address,
    output reg          mem_read,
    output reg          mem_write,
    output reg          cache_read_en,
    output reg  [7:0]   cpu_data_out,
    output reg          ready,
    input  wire         hit,
    output reg  [7:0]   index,
    output reg  [1:0]   offset,
    output reg  [21:0]  tag
);

    reg [1:0] current_state, next_state;
    localparam IDLE       = 2'b00,
               COMPARE    = 2'b01,
               WRITE_BACK = 2'b10,
               ALLOCATE   = 2'b11;

    // Split CPU address
    always @(*) begin
        tag    = cpu_address[31:10];
        index  = cpu_address[9:2];
        offset = cpu_address[1:0];
    end

    // State register
    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    // Next state & outputs
    always @(*) begin
        // defaults
        mem_read      = 0;
        mem_write     = 0;
        cache_read_en = 0;
        mem_address   = 0;
        ready         = 0;
        cpu_data_out  = 8'h00;
        next_state    = current_state;

        //IDLE State

        case (current_state)
        IDLE: begin
            if (cpu_read || cpu_write)
                next_state = COMPARE;
        end
    //Compare State
        COMPARE: begin
            cache_read_en = 1;
            if (hit) begin
                cpu_data_out = cache_data_in[offset*8 +: 8];
                ready        = 1;
                next_state   = IDLE;
            end else if (valid_bit && dirty_bit)
                next_state = WRITE_BACK;
            else
                next_state = ALLOCATE;
        end
//Write Back State
        WRITE_BACK: begin
            mem_write   = 1;
            mem_address = {tag, index, 2'b00};
            if (mem_ready)
                next_state = ALLOCATE;
        end
// Allocate State
        ALLOCATE: begin
            mem_read    = 1;
            mem_address = {tag, index, 2'b00};
            if (mem_ready) begin
                cpu_data_out = mem_data_in[offset*8 +: 8];
                ready        = 1;
                next_state   = IDLE;
            end
        end

        default: next_state = IDLE;
        endcase
    end

endmodule



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
