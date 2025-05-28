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

        case (current_state)
        IDLE: begin
            if (cpu_read || cpu_write)
                next_state = COMPARE;
        end

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

        WRITE_BACK: begin
            mem_write   = 1;
            mem_address = {tag, index, 2'b00};
            if (mem_ready)
                next_state = ALLOCATE;
        end

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
