// The Single Contains Testbench of main Cache_System and 3 individual 
//testbenches of cache_controller, cache_memory and main_memory.

`timescale 1ns / 1ps
module tb_cache_system;

  // DUT inputs
  reg         clk;
  reg         rst;
  reg         cpu_read;
  reg         cpu_write;
  reg  [31:0] cpu_address;
  reg  [31:0] cpu_wdata;
  // DUT outputs
  wire [7:0]  cpu_data_out;
  wire        ready;

  // Instantiate the cache system
  cache_system uut (
    .clk(clk),
    .rst(rst),
    .cpu_read(cpu_read),
    .cpu_write(cpu_write),
    .cpu_address(cpu_address),
    .cpu_wdata(cpu_wdata),
    .cpu_data_out(cpu_data_out),
    .ready(ready)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  // Helper task for write
  task write(input [31:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      cpu_address = addr;
      cpu_wdata = data;
      cpu_write = 1;
      wait (ready);
      @(posedge clk);
      cpu_write = 0;
      $display("[Time %0t] WRITE @%h = %h", $time, addr, data);
    end
  endtask

  // Helper task for read
  task read(input [31:0] addr, input [7:0] expected);
    begin
      @(posedge clk);
      cpu_address = addr;
      cpu_read = 1;
      wait (ready);
      @(posedge clk);
      cpu_read = 0;
      $display("[Time %0t] READ  @%h -> %h (expected: %h)", 
               $time, addr, cpu_data_out, expected);
    end
  endtask

  // Test sequence
  initial begin
    // Reset and init
    rst = 1; cpu_read = 0; cpu_write = 0;
    cpu_address = 0; cpu_wdata = 0;
    #20; rst = 0; #10;

    // ---- 6 WRITE OPERATIONS ----
    write(32'h00000020, 32'hAAAAAAAA);
    #20;  // expect: AA
    write(32'h00000040, 32'h55555555);#20;  // expect: 55
    write(32'h00000060, 32'hCAFEC0FF);#20;  // expect: FF
    write(32'h00000080, 32'h12345678);#20;  // expect: 78
    write(32'h000000A0, 32'hBEEF0001);#20;  // expect: 01
    write(32'h000000C0, 32'h00000000); #20; // expect: 00

    // Pause
    #20;

    // ---- 6 READ OPERATIONS ----
    read(32'h00000020, 8'hAA);
    read(32'h00000040, 8'h55);
    read(32'h00000060, 8'hFF);
    read(32'h00000080, 8'h78);
    read(32'h000000A0, 8'h01);
    read(32'h000000C0, 8'h00);

    #50;
    $finish;
  end

endmodule


`timescale 1ns / 1ps

module tb_cache_controller;
    // Clock & reset
    reg         clk;
    reg         rst;

    // CPU Interface
    reg         cpu_read;
    reg         cpu_write;
    reg  [31:0] cpu_address;

    // Memory & Cache status signals
    reg         mem_ready;
    reg         dirty_bit;
    reg         valid_bit;
    reg  [31:0] mem_data_in;    // Data returned by main memory
    reg  [31:0] cache_data_in;  // Data from cache on a hit
    reg         hit;            // Cache hit indicator

    // Outputs from UUT
    wire [31:0] mem_address;
    wire        mem_read;
    wire        mem_write;
    wire        cache_read_en;
    wire [7:0]  cpu_data_out;
    wire        ready;
    wire [7:0]  index;
    wire [1:0]  offset;
    wire [21:0] tag;

    // Instantiate the Unit Under Test
    cache_controller uut (
        .clk(clk),
        .rst(rst),
        .cpu_read(cpu_read),
        .cpu_write(cpu_write),
        .cpu_address(cpu_address),
        .mem_ready(mem_ready),
        .dirty_bit(dirty_bit),
        .valid_bit(valid_bit),
        .mem_data_in(mem_data_in),
        .cache_data_in(cache_data_in),
        .mem_address(mem_address),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .cache_read_en(cache_read_en),
        .cpu_data_out(cpu_data_out),
        .ready(ready),
        .hit(hit),
        .index(index),
        .offset(offset),
        .tag(tag)
    );

    // Clock generation: 100 MHz
    always #5 clk = ~clk;

    initial begin
        // Dump waves for debugging
        $dumpfile("tb_cache_controller.vcd");
        $dumpvars(0, tb_cache_controller);

        // Initialize signals
        clk           = 0;
        rst           = 1;
        cpu_read      = 0;
        cpu_write     = 0;
        cpu_address   = 0;
        mem_ready     = 0;
        dirty_bit     = 0;
        valid_bit     = 0;
        mem_data_in   = 0;
        cache_data_in = 0;
        hit           = 0;

        // Release reset after 20 ns
        #20 rst = 0;

        // Address = 0x0000_0004 → offset = 2'b00
        cpu_address   = 32'h0000_0004;
        cache_data_in = 32'hDFFFAAEF;  // low byte = 8'hEF
        valid_bit     = 1;
        dirty_bit     = 0;
        hit           = 1;
        cpu_read      = 1; 
        #10;  // go into COMPARE
        #10;  // allow outputs to settle
        $display("Test1(Read Hit): cpu_data_out = %02h, ready = %b", cpu_data_out, ready);

        cpu_read = 0;
        #10;


        // valid=0 → go straight to ALLOCATE
        cpu_address   = 32'h0000_0010;
        valid_bit     = 0;
        dirty_bit     = 0;
        hit           = 0;
        cpu_read      = 1;
        #10;  // COMPARE drives mem_read=1
        $display("  mem_read asserted? %b", mem_read);

        // Wait one cycle, then simulate memory ready
        #10 mem_ready   = 1;
        mem_data_in = 32'hA5A5A5A5;  // low byte = 8'hA5
        #10;
        $display("Test2(Read Miss Clean): cpu_data_out = %02h, ready = %b", cpu_data_out, ready);

        cpu_read  = 0;
        mem_ready = 0;
        #10;

       
        // valid=1, dirty=1 → WRITE_BACK, then ALLOCATE
        cpu_address   = 32'h0000_0020;
        valid_bit     = 1;
        dirty_bit     = 1;
        hit           = 0;
        cpu_read      = 1;
        #10;  // COMPARE → WRITE_BACK
        $display("  mem_write asserted? %b", mem_write);

        // Complete write-back
        #10 mem_ready = 1;
        #10 mem_ready = 0;

        // Now in ALLOCATE
        #10 mem_ready = 1;
        mem_data_in = 32'hF0F0F0F0;  // low byte = 8'hF0
        #10;
        $display("Test3(Read Miss Dirty): cpu_data_out = %02h, ready = %b", cpu_data_out, ready);

        // Clean up
        cpu_read  = 0;
        mem_ready = 0;
        #20 $finish;
    end
endmodule


`timescale 1ns / 1ps

module tb_cache_memory;
    // Clock & reset
    reg         clk;
    reg         rst;

    // Cache interface signals
    reg  [7:0]  index;
    reg  [1:0]  offset;
    reg         read_en;
    reg         write_en;
    reg         alloc_en;
    reg         cpu_write;
    reg  [31:0] cpu_wdata;
    reg  [31:0] cache_wdata;
    reg  [21:0] tag_in;

    // Outputs from DUT
    wire [31:0] cache_rdata;
    wire [21:0] tag_out;
    wire        valid_out;
    wire        dirty_out;
    wire        hit;
    wire [31:0] wb_data;

    // Instantiate DUT
    cache_memory uut (
        .clk         (clk),
        .rst         (rst),
        .index       (index),
        .offset      (offset),
        .read_en     (read_en),
        .write_en    (write_en),
        .alloc_en    (alloc_en),
        .cpu_write   (cpu_write),
        .cpu_wdata   (cpu_wdata),
        .cache_wdata (cache_wdata),
        .cache_rdata (cache_rdata),
        .tag_in      (tag_in),
        .tag_out     (tag_out),
        .valid_out   (valid_out),
        .dirty_out   (dirty_out),
        .hit         (hit),
        .wb_data     (wb_data)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    initial begin
        // Waveform dump
        $dumpfile("tb_cache_memory.vcd");
        $dumpvars(0, tb_cache_memory);

        // Initial values
        clk         = 0;
        rst         = 1;
        index       = 0;
        offset      = 0;
        read_en     = 0;
        write_en    = 0;
        alloc_en    = 0;
        cpu_write   = 0;
        cpu_wdata   = 0;
        cache_wdata = 0;
        tag_in      = 0;
        #20 rst = 0;  // release reset

        // 1) After reset, nothing valid
        #10 read_en = 1;
            $display("After reset: hit=%b valid=%b dirty=%b rdata=%h tag=%h", 
                     hit, valid_out, dirty_out, cache_rdata, tag_out);
        #10 read_en = 0;

        // 2) Allocate on read-miss (read miss, cpu_write=0)
        #10 index       = 8'd10;
            tag_in      = 22'h3AA;
            cache_wdata = 32'hAAAAFFFF;
            alloc_en    = 1;
            cpu_write   = 0;
        #10 alloc_en = 0;
            $display("Alloc read-miss: valid=%b dirty=%b tag=%h rdata=%h", 
                     valid_out, dirty_out, tag_out, cache_rdata);

        // 3) Read back the block: should hit and return DEADBEED low word
        #10 read_en = 1;
            $display("Read-back hit=%b rdata=%h tag=%h valid=%b dirty=%b", 
                     hit, cache_rdata, tag_out, valid_out, dirty_out);
        #10 read_en = 0;

        // 4) Write-hit: update word at same index
        #10 write_en  = 1;
            cpu_wdata  = 32'h12345678;
        #10 write_en = 0;
            $display("After write-hit: dirty=%b wb_data=%h", dirty_out, wb_data);

        // 5) Read-hit returns new data
        #10 read_en = 1;
            $display("Post-write read: hit=%b rdata=%h dirty=%b", 
                     hit, cache_rdata, dirty_out);
        #10 read_en = 0;

        // 6) Allocate on write-miss (write-allocate)
        #10 index      = 8'd20;
            tag_in     = 22'h1F0;
            cache_wdata= 32'hCAFEBABE;
            alloc_en   = 1;
            cpu_write  = 1;
            cpu_wdata  = 32'h0BADF00D;
        #10 alloc_en  = 0;
            $display("Alloc write-miss: valid=%b dirty=%b tag=%h data=%h", 
                     valid_out, dirty_out, tag_out, cache_rdata);

        // 7) Read back write-allocated block
        #10 read_en = 1;
            $display("Read write-alloc: hit=%b rdata=%h dirty=%b wb_data=%h", 
                     hit, cache_rdata, dirty_out, wb_data);
        #10 read_en = 0;

        // Finish
        #20 $finish;
    end
endmodule

`timescale 1ns / 1ps

module tb_main_memory;

    reg clk;
    reg rst;
    reg [31:0] mem_address;
    reg mem_read;
    reg mem_write;
    reg [31:0] mem_wdata;
    wire [31:0] mem_data_out;
    wire ready;
  
    
    main_memory uut (
        .clk         (clk),
        .rst         (rst),
        .mem_address       (mem_address),
        .mem_read      (mem_read),
        .mem_write     (mem_write),
        .mem_wdata    (mem_wdata),
        .mem_data_out    (mem_data_out),
        .ready   (ready)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_main_memory.vcd");
        $dumpvars(0, tb_main_memory);
        clk         = 0;
        rst         = 1;
        mem_address = 0;
        mem_read = 0;
        mem_write = 0;
        mem_wdata = 0;
        #20 
        rst = 0;    
        #10;
        
           
    // Write Operation
    mem_address = 32'h0000_0004;
    mem_wdata   = 32'hCAFE_CAFE;
    mem_write   = 1;
    #10;                // one clock
    mem_write   = 0;
    #10;                // wait for ready

    // Read from Same address    
    mem_address = 32'h0000_0004;
    mem_read    = 1;
    #10;
    mem_read    = 0;
    #10;
    
    // Read From empty address
    mem_address = 32'h0000_0008;
    mem_read    = 1;
    #10;
    mem_read    = 0;
    #10;   
    
    //Overwrite Previous address
    mem_address = 32'h0000_0004;
    mem_wdata   = 32'h1234_5678;
    mem_write   = 1;
    #10;
    mem_write   = 0;
    #10;
    
    //Read from Overwritten Address
    mem_address = 32'h0000_0004;
    mem_read    = 1;
    #10;
    mem_read    = 0;
    #10;
    $finish;
    
    end
endmodule

