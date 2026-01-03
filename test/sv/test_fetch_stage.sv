module test_fetch_stage;
    import clk_params::*;
    import pipeline_status::*;

    /*verilator lint_off UNUSED*/
    logic clk;
    logic rst;
    /*verilator lint_on UNUSED*/

    // System clock
    initial begin
        clk = 1;
        forever begin
            #(int'(SIM_CYCLES_PER_SYS_CLK / 2));
            clk = ~clk;
        end
    end

    // --------------------------------------------------------------------------------------------
    // Test bench variables
    int error_count = 0;
    int test_count = 0;

    // --------------------------------------------------------------------------------------------
    // Wishbone interface for DUT
    wishbone_interface wb_dut();
    
    // Wishbone interface for reference (separate to allow independent control)
    wishbone_interface wb_ref();
    
    // Wishbone slave interfaces for interconnect
    wishbone_interface wb_slave_dut[1]();
    wishbone_interface wb_slave_ref[1]();
    
    // Dummy wishbone interfaces for unused port_b
    wishbone_interface wb_dummy_dut();
    wishbone_interface wb_dummy_ref();

    // DUT signals
    logic [31:0] dut_instruction_reg_out;
    logic [31:0] dut_program_counter_reg_out;
    pipeline_status::forwards_t dut_status_forwards_out;
    pipeline_status::backwards_t dut_status_backwards_in;
    logic [31:0] dut_jump_address_backwards_in;

    // Reference signals
    logic [31:0] ref_instruction_reg_out;
    logic [31:0] ref_program_counter_reg_out;
    pipeline_status::forwards_t ref_status_forwards_out;
    pipeline_status::backwards_t ref_status_backwards_in;
    logic [31:0] ref_jump_address_backwards_in;

    // Device under test
    fetch_stage dut (
        .clk(clk),
        .rst(rst),
        .wb(wb_dut),
        .instruction_reg_out(dut_instruction_reg_out),
        .program_counter_reg_out(dut_program_counter_reg_out),
        .status_forwards_out(dut_status_forwards_out),
        .status_backwards_in(dut_status_backwards_in),
        .jump_address_backwards_in(dut_jump_address_backwards_in)
    );

    // Reference implementation
    ref_fetch_stage ref_dut (
        .clk(clk),
        .rst(rst),
        .wb(wb_ref),
        .instruction_reg_out(ref_instruction_reg_out),
        .program_counter_reg_out(ref_program_counter_reg_out),
        .status_forwards_out(ref_status_forwards_out),
        .status_backwards_in(ref_status_backwards_in),
        .jump_address_backwards_in(ref_jump_address_backwards_in)
    );

    // Wishbone interconnect for DUT
    // Wishbone uses word addresses. RESET_ADDRESS is byte address, so >> 2 for word address.
    wishbone_interconnect #(
        .NUM_SLAVES(1),
        .SLAVE_ADDRESS(32'(constants::RESET_ADDRESS >> 2)),
        .SLAVE_SIZE(32'(constants::MEMORY_SIZE))
    ) interconnect_dut (
        .clk(clk),
        .rst(rst),
        .master(wb_dut),
        .slaves(wb_slave_dut)
    );

    // Wishbone RAM for DUT
    wishbone_ram #(
        .ADDRESS(constants::RESET_ADDRESS >> 2),
        .SIZE(constants::MEMORY_SIZE)
    ) ram_dut (
        .clk(clk),
        .rst(rst),
        .port_a(wb_slave_dut[0]),
        .port_b(wb_dummy_dut)
    );

    // Wishbone interconnect for reference
    wishbone_interconnect #(
        .NUM_SLAVES(1),
        .SLAVE_ADDRESS(32'(constants::RESET_ADDRESS >> 2)),
        .SLAVE_SIZE(32'(constants::MEMORY_SIZE))
    ) interconnect_ref (
        .clk(clk),
        .rst(rst),
        .master(wb_ref),
        .slaves(wb_slave_ref)
    );

    // Wishbone RAM for reference
    wishbone_ram #(
        .ADDRESS(constants::RESET_ADDRESS >> 2),
        .SIZE(constants::MEMORY_SIZE)
    ) ram_ref (
        .clk(clk),
        .rst(rst),
        .port_a(wb_slave_ref[0]),
        .port_b(wb_dummy_ref)
    );

    // --------------------------------------------------------------------------------------------
    // |                                    Main Test Function                                    |
    // --------------------------------------------------------------------------------------------
    initial begin
        logic [31:0] pc_before_stall;
        logic [31:0] jump_target;
        
        $dumpfile("test_fetch_stage.fst");
        $dumpvars;

        // Initialize test memory with distinct instruction patterns for verification
        // Memory is initialized via init.mem file loaded by wishbone_ram module
        reset_inputs();

        // Test 1: Reset behavior
        $display("------------------------------ (%6d ns) Test 1: Reset behavior", $time());
        perform_rst();
        
        // Check PC is at RESET_ADDRESS after reset
        if (dut_program_counter_reg_out !== ref_program_counter_reg_out) begin
            $display("ERROR: PC mismatch after reset. DUT: 0x%x, REF: 0x%x", 
                dut_program_counter_reg_out, ref_program_counter_reg_out);
            error_count++;
        end
        
        // Should be in BUBBLE state after reset
        if (dut_status_forwards_out !== pipeline_status::BUBBLE) begin
            $display("ERROR: DUT status should be BUBBLE after reset, got %s", 
                dut_status_forwards_out.name());
            error_count++;
        end
        
        // Now transition to READY and wait for first instruction fetch
        $display("------------------------------ (%6d ns) Test 1b: First fetch after reset", $time());
        dut_status_backwards_in = pipeline_status::READY;
        ref_status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        @(posedge clk); #1;
        compare_outputs("After first fetch");
        
        // Test 2: Continue normal instruction fetch - multiple cycles
        $display("------------------------------ (%6d ns) Test 2: Continue normal fetch sequence (READY)", $time());
        repeat(4) begin
            @(posedge clk); #1;
            compare_outputs($sformatf("READY at PC=0x%x", dut_program_counter_reg_out));
        end

        // Test 3: Stall behavior
        $display("------------------------------ (%6d ns) Test 3: Stall behavior", $time());
        dut_status_backwards_in = pipeline_status::STALL;
        ref_status_backwards_in = pipeline_status::STALL;
        @(posedge clk); #1;
        compare_outputs("During STALL");
        
        // PC should not advance during stall
        pc_before_stall = dut_program_counter_reg_out;
        @(posedge clk); #1;
        if (dut_program_counter_reg_out !== pc_before_stall) begin
            $display("ERROR: PC should not advance during stall");
            error_count++;
        end

        // Test 4: Jump behavior
        $display("------------------------------ (%6d ns) Test 4: Jump behavior", $time());
        // Jump to a valid address within RAM range (RESET_ADDRESS to RESET_ADDRESS + MEMORY_SIZE*4)
        jump_target = constants::RESET_ADDRESS + 32'h100;
        dut_status_backwards_in = pipeline_status::JUMP;
        dut_jump_address_backwards_in = jump_target;
        ref_status_backwards_in = pipeline_status::JUMP;
        ref_jump_address_backwards_in = jump_target;
        
        @(posedge clk); #1;
        compare_outputs("After JUMP command");
        
        // Status should be BUBBLE after jump (instruction pipeline is flushed)
        if (dut_status_forwards_out !== pipeline_status::BUBBLE) begin
            $display("ERROR: DUT status should be BUBBLE after JUMP");
            error_count++;
        end

        // After jump, PC should be at the jump target
        @(posedge clk); #1;
        if (dut_program_counter_reg_out !== jump_target) begin
            $display("ERROR: PC should be at jump target. Expected 0x%x, got 0x%x", 
                jump_target, dut_program_counter_reg_out);
            error_count++;
        end

        // Test 5: Back to normal operation
        $display("------------------------------ (%6d ns) Test 5: Resume normal operation", $time());
        dut_status_backwards_in = pipeline_status::READY;
        ref_status_backwards_in = pipeline_status::READY;
        
        repeat(4) begin
            @(posedge clk); #1;
            compare_outputs("Resuming normal operation");
        end

        // --------------------------------------------------------------------------------------------
        // Signal test done
        print_test_done();

        // Stop simulation
        $finish();
    end

    // --------------------------------------------------------------------------------------------
    // Helper functions
    // --------------------------------------------------------------------------------------------
    function void reset_inputs();
        dut_status_backwards_in = pipeline_status::READY;
        dut_jump_address_backwards_in = 32'h0;
        ref_status_backwards_in = pipeline_status::READY;
        ref_jump_address_backwards_in = 32'h0;
    endfunction

    function void perform_rst();
        @(negedge clk); #1;
        rst = 1;
        reset_inputs();
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;
    endfunction

    function void compare_outputs(string test_label);
        test_count++;
        
        // Compare instruction output
        if (dut_instruction_reg_out !== ref_instruction_reg_out) begin
            $display("ERROR (%s): Instruction mismatch. DUT: 0x%x, REF: 0x%x", 
                test_label, dut_instruction_reg_out, ref_instruction_reg_out);
            error_count++;
        end
        
        // Compare program counter output
        if (dut_program_counter_reg_out !== ref_program_counter_reg_out) begin
            $display("ERROR (%s): PC mismatch. DUT: 0x%x, REF: 0x%x", 
                test_label, dut_program_counter_reg_out, ref_program_counter_reg_out);
            error_count++;
        end
        
        // Compare status forwards output
        if (dut_status_forwards_out !== ref_status_forwards_out) begin
            $display("ERROR (%s): Status forwards mismatch. DUT: %s, REF: %s", 
                test_label, dut_status_forwards_out.name(), ref_status_forwards_out.name());
            error_count++;
        end
    endfunction

    // --------------------------------------------------------------------------------------------
    function void print_test_done();
        $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        $display("!!!!!!!!!!!!!!!! TEST SUMMARY !!!!!!!!!!!!!!!!!!!");
        $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        $display("Total comparison points: %d", test_count);
        
        if (error_count != 0) begin
            $display("\033[0;31m"); // color_red
            $display("Some test(s) FAILED! (# Errors: %4d)", error_count);
        end else begin
            $display("\033[0;32m"); // color green
            $display("All tests PASSED! (# Errors: %4d)", error_count);
        end
        $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        $display("\033[0m"); // color off
    endfunction

endmodule
