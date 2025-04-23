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
    output reg  [31:0]  mem_address,
    output reg          mem_read,
    output reg          mem_write,      
    output reg  [7:0]   cpu_data_out,
    output reg          ready,
    input  wire         hit,
    output reg  [7:0]   index,     
    output reg  [1:0]   offset,      
    output reg  [21:0]  tag          
);

    reg [1:0] current_state, next_state;
    localparam  IDLE       = 2'b00,
                COMPARE    = 2'b01,
                WRITE_BACK = 2'b10,
                ALLOCATE   = 2'b11;

    // Split the CPU address into tag, index, and offset:
    // Tag: bits [31:10] (22 bits)
    // Index: bits [9:2] (8 bits)
    // Offset: bits [1:0] (2 bits)
    always @(*) begin
        tag    = cpu_address[31:10];
        index  = cpu_address[9:2];
        offset = cpu_address[1:0];
    end

    // State register update.
    always @(posedge clk or posedge rst) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next-state and output logic.
    always @(*) begin
        // Default assignments
        mem_read     = 0;
        mem_write    = 0;
        mem_address  = 32'b0;
        ready        = 0;
        cpu_data_out = 8'h00;
        next_state   = current_state;
        
        case (current_state)
            IDLE: begin
                ready = 1;
                if (cpu_read || cpu_write)
                    next_state = COMPARE;
                else
                    next_state = IDLE;
            end

            COMPARE: begin
                if (hit) begin
                    // On hit, operation completes.
                    ready = 1;
                    next_state = IDLE;
                end else begin
                    // On miss, if the cache line is both valid and dirty,
                    // write it back first; otherwise allocate new data.
                    if (valid_bit && dirty_bit)
                        next_state = WRITE_BACK;
                    else
                        next_state = ALLOCATE;
                end
            end

            WRITE_BACK: begin
                mem_write   = 1;
                // Form a 4-byte aligned address from {tag, index, 2'b00}
                mem_address = {tag, index, 2'b00};
                if (mem_ready)
                    next_state = ALLOCATE;
                else
                    next_state = WRITE_BACK;
            end

            ALLOCATE: begin
                mem_read    = 1;
                mem_address = {tag, index, 2'b00};
                if (mem_ready) begin
                    // Extract the requested byte from the 32-bit word using the offset.
                    cpu_data_out = mem_data_in[offset*8 +: 8];
                    ready = 1;
                    next_state = IDLE;
                end else begin
                    next_state = ALLOCATE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
