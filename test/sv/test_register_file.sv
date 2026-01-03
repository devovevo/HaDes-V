module test_register_file;
    import clk_params::*;
    
    logic clk;
    logic rst;

    // System clock
    initial begin
        clk = 1;
        forever begin
            #(int'(SIM_CYCLES_PER_SYS_CLK / 2));
            clk = ~clk;
        end
    end

    // Input signals
    logic [4:0]  read_address1;
    logic [4:0]  read_address2;
    logic [4:0]  write_address;
    logic [31:0] write_data;
    logic        write_enable;

    // DUT output signals
    logic [31:0] read_data1_dut;
    logic [31:0] read_data2_dut;

    // Reference signals
    logic [31:0] read_data1_ref;
    logic [31:0] read_data2_ref;

    // Register files
    register_file dut (
        .clk(clk),
        .rst(rst),
        .read_address1(read_address1),
        .read_data1(read_data1_dut),
        .read_address2(read_address2),
        .read_data2(read_data2_dut),
        .write_address(write_address),
        .write_data(write_data),
        .write_enable(write_enable)
    );

    ref_register_file golden (
        .clk(clk),
        .rst(rst),
        .read_address1(read_address1),
        .read_data1(read_data1_ref),
        .read_address2(read_address2),
        .read_data2(read_data2_ref),
        .write_address(write_address),
        .write_data(write_data),
        .write_enable(write_enable)
    );
    
    // Test procedure
    initial begin
        $dumpfile("test_register_file.fst");
        $dumpvars;

        // Reset both modules
        read_address1 = 5'b0;
        read_address2 = 5'b0;
        write_address = 5'b0;
        write_data = 32'b0;
        write_enable = 1'b0;
        rst = 1;
        @(posedge clk); #1;
        rst = 0;
        @(posedge clk); #1;

        compare_registers();

        // Write to register 1
        read_address1 = 5'd1;
        write_address = 5'd1;
        write_data = 32'hDEADBEEF;
        write_enable = 1;
        @(posedge clk); #1;  // Write happens on this edge
        compare_registers();

        // Write to register 2
        read_address2 = 5'd2;
        write_address = 5'd2;
        write_data = 32'hCAFEBABE;
        write_enable = 1;
        @(posedge clk); #1;  // Write happens on this edge
        compare_registers();

        // Write to register 0 (should have no effect)
        read_address1 = 5'd0;
        write_address = 5'd0;
        write_data = 32'hFFFFFFFF;
        write_enable = 1;
        @(posedge clk); #1;  // Write happens on this edge
        compare_registers();

        // Try writing when write_enable is low
        write_address = 5'd2;
        write_data = 32'h12345678;
        write_enable = 0;
        @(posedge clk); #1;  // No write should happen
        compare_registers();

        repeat (5) begin
            @(posedge clk); #1;
        end

        $display("All tests completed.");
        $finish;
    end

    function void compare_registers();
        if (read_data1_dut !== read_data1_ref) begin
            $error("Mismatch on read_data1: DUT=%h, REF=%h", read_data1_dut, read_data1_ref);
        end
        if (read_data2_dut !== read_data2_ref) begin
            $error("Mismatch on read_data2: DUT=%h, REF=%h", read_data2_dut, read_data2_ref);
        end
    endfunction
endmodule
