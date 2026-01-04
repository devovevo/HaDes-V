module test_memory_stage;
    logic clk;
    logic rst;

    import clk_params::*;
    import pipeline_status::*;

    // Testbench code would go here
    initial begin
        clk = 0;
        forever #(SIM_CYCLES_PER_SYS_CLK / 2) clk = ~clk;
    end

    initial begin
        rst = 1;
        #(SIM_CYCLES_PER_SYS_CLK * 2);
        rst = 0;
    end

    // Inputs
    logic [31:0]   source_data_in;
    logic [31:0]   rd_data_in;
    instruction::t instruction_in;
    logic [31:0]   program_counter_in;
    logic [31:0]   next_program_counter_in;
    pipeline_status::forwards_t status_forwards_in;
    pipeline_status::backwards_t status_backwards_in;
    logic [31:0] jump_address_backwards_in;

    // DUT Outputs
    logic [31:0]   source_data_reg_out;
    logic [31:0]   rd_data_reg_out;
    instruction::t instruction_reg_out;
    logic [31:0]   program_counter_reg_out;
    logic [31:0]   next_program_counter_reg_out;
    forwarding::t  forwarding_out;
    pipeline_status::forwards_t status_forwards_out;
    pipeline_status::backwards_t status_backwards_out;
    logic [31:0] jump_address_backwards_out;

    // Instantiate DUT
    memory_stage dut (
        .clk(clk),
        .rst(rst),
        .wb(wb_dut),
        .source_data_in(source_data_in),
        .rd_data_in(rd_data_in),
        .instruction_in(instruction_in),
        .program_counter_in(program_counter_in),
        .next_program_counter_in(next_program_counter_in),
        .source_data_reg_out(source_data_reg_out),
        .rd_data_reg_out(rd_data_reg_out),
        .instruction_reg_out(instruction_reg_out),
        .program_counter_reg_out(program_counter_reg_out),
        .next_program_counter_reg_out(next_program_counter_reg_out),
        .forwarding_out(forwarding_out),
        .status_forwards_in(status_forwards_in),
        .status_forwards_out(status_forwards_out),
        .status_backwards_in(status_backwards_in),
        .status_backwards_out(status_backwards_out),
        .jump_address_backwards_in(jump_address_backwards_in),
        .jump_address_backwards_out(jump_address_backwards_out)
    );

    // --------------------------------------------------------------------------------------------
    // Wishbone test infrastructure (RAM + interconnect)
    wishbone_interface wb_dut();
    wishbone_interface wb_ref();
    wishbone_interface wb_slave_dut[1]();
    wishbone_interface wb_slave_ref[1]();
    wishbone_interface wb_dummy_dut();
    wishbone_interface wb_dummy_ref();

    // Wishbone interconnect for DUT
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

    // Ref Outputs
    logic [31:0]   ref_source_data_reg_out;
    logic [31:0]   ref_rd_data_reg_out;
    instruction::t ref_instruction_reg_out;
    logic [31:0]   ref_program_counter_reg_out;
    logic [31:0]   ref_next_program_counter_reg_out;
    forwarding::t  ref_forwarding_out;
    pipeline_status::forwards_t ref_status_forwards_out;
    pipeline_status::backwards_t ref_status_backwards_out;
    logic [31:0] ref_jump_address_backwards_out;

    // Test helpers
    logic [31:0] addr;
    logic [31:0] write_data;

    // Instantiate Reference Model
    ref_memory_stage ref_dut (
        .clk(clk),
        .rst(rst),
        .wb(wb_ref),
        .source_data_in(source_data_in),
        .rd_data_in(rd_data_in),
        .instruction_in(instruction_in),
        .program_counter_in(program_counter_in),
        .next_program_counter_in(next_program_counter_in),
        .source_data_reg_out(ref_source_data_reg_out),
        .rd_data_reg_out(ref_rd_data_reg_out),
        .instruction_reg_out(ref_instruction_reg_out),
        .program_counter_reg_out(ref_program_counter_reg_out),
        .next_program_counter_reg_out(ref_next_program_counter_reg_out),
        .forwarding_out(ref_forwarding_out),
        .status_forwards_in(status_forwards_in),
        .status_forwards_out(ref_status_forwards_out),
        .status_backwards_in(status_backwards_in),
        .status_backwards_out(ref_status_backwards_out),
        .jump_address_backwards_in(jump_address_backwards_in),
        .jump_address_backwards_out(ref_jump_address_backwards_out)
    );

    // Simple helper for constructing instructions
    function automatic instruction::t make_instr(
        op::t opcode,
        logic [4:0] rd = 5'd0,
        logic [4:0] rs1 = 5'd0,
        logic [4:0] rs2 = 5'd0,
        logic [11:0] imm12 = 12'd0
    );
        instruction::t instr;
        instr.op = opcode;
        instr.rd_address = rd;
        instr.rs1_address = rs1;
        instr.rs2_address = rs2;
        instr.immediate = {{20{imm12[11]}}, imm12};
        return instr;
    endfunction

    // Test procedure
    initial begin
        $dumpfile("test_memory_stage.fst");
        $dumpvars(0, test_memory_stage);

        // Initialize inputs
        source_data_in = 32'h00000000;
        rd_data_in = 32'h00000000;
        instruction_in = instruction::NOP;
        program_counter_in = 32'h00000000;
        next_program_counter_in = 32'h00000004;
        status_forwards_in = pipeline_status::BUBBLE;
        status_backwards_in = pipeline_status::READY;
        jump_address_backwards_in = 32'h00000000;

        // Wait for reset deassertion
        @(negedge rst);
        #(SIM_CYCLES_PER_SYS_CLK);

        // ---------------------------------------------------------------------
        // Test A: Aligned store (SW) then aligned load (LW)
        // ---------------------------------------------------------------------

        addr = 32'h0000_0100; // within RAM
        write_data = 32'h1234_5678;

        // Issue SW
        instruction_in = make_instr(op::SW, .rs1(5'd0), .rs2(5'd0));
        instruction_in.op = op::SW;
        source_data_in = write_data;
        rd_data_in = addr; // byte address
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk);
        // wait a few cycles for bus ACK
        repeat (3) begin @(posedge clk); end

        // Now issue LW from same address
        instruction_in = make_instr(op::LW, .rd(5'd3));
        instruction_in.op = op::LW;
        rd_data_in = addr;
        source_data_in = 32'b0;
        @(posedge clk);
        repeat (2) @(posedge clk);
        compare_outputs("Aligned SW->LW");

        // ---------------------------------------------------------------------
        // Test B: Byte/halfword loads (LB/LBU, LH/LHU)
        // ---------------------------------------------------------------------
        // Write a 32-bit pattern then load bytes/halves
        addr = 32'h0000_0200;
        write_data = 32'h8123_4567; // MSB 0x81 to test sign-extension
        // SW to addr
        instruction_in = make_instr(op::SW);
        instruction_in.op = op::SW;
        source_data_in = write_data;
        rd_data_in = addr;
        @(posedge clk); repeat(2) @(posedge clk);

        // LBU offset 0 -> expect 0x67
        instruction_in = make_instr(op::LBU, .rd(5'd4));
        instruction_in.op = op::LBU;
        rd_data_in = addr + 0;
        @(posedge clk); repeat(2) @(posedge clk);
        compare_outputs("LBU offset0");

        // LB offset 3 -> expect sign-extended 0x81 -> 0xFFFF_FF81
        instruction_in = make_instr(op::LB, .rd(5'd5));
        instruction_in.op = op::LB;
        rd_data_in = addr + 3;
        @(posedge clk); repeat(2) @(posedge clk);
        compare_outputs("LB offset3 sign-extend");

        // SH then LH/LHU
        addr = 32'h0000_0300;
        instruction_in = make_instr(op::SW);
        instruction_in.op = op::SW;
        source_data_in = 32'h0000_ABCD;
        rd_data_in = addr;
        @(posedge clk); repeat(2) @(posedge clk);

        // LH offset 0 should return 0x0000_ABCD sign-extended if msb set
        instruction_in = make_instr(op::LH, .rd(5'd6));
        instruction_in.op = op::LH;
        rd_data_in = addr + 0;
        @(posedge clk); repeat(2) @(posedge clk);
        compare_outputs("LH offset0");

        // LHU offset 0 should zero-extend
        instruction_in = make_instr(op::LHU, .rd(5'd7));
        instruction_in.op = op::LHU;
        rd_data_in = addr + 0;
        @(posedge clk); repeat(2) @(posedge clk);
        compare_outputs("LHU offset0");

        // ---------------------------------------------------------------------
        // Test C: Unaligned loads/stores should produce MISALIGNED status
        // ---------------------------------------------------------------------
        // LH at odd address -> misaligned
        instruction_in = make_instr(op::LH, .rd(5'd8));
        instruction_in.op = op::LH;
        rd_data_in = 32'h0000_0401; // odd
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        compare_outputs("MISALIGNED LH");

        // SW at unaligned (addr %4 !=0) for word store -> store misaligned
        instruction_in = make_instr(op::SW);
        instruction_in.op = op::SW;
        rd_data_in = 32'h0000_0502; // not word aligned
        source_data_in = 32'hDEAD_BEEF;
        @(posedge clk); #1;
        compare_outputs("MISALIGNED SW");

        // ---------------------------------------------------------------------
        // Test D: CSR ops pass through rd_data_in (memory stage should forward ALU/CSR results)
        // ---------------------------------------------------------------------
        instruction_in = make_instr(op::CSRRW, .rd(5'd9));
        instruction_in.op = op::CSRRW;
        rd_data_in = 32'hCAFEBABE;
        source_data_in = 32'h0;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); repeat(1) @(posedge clk);
        compare_outputs("CSR pass-through");

        $display("All memory-stage tests executed (compare DUT vs REF outputs above).");
        $finish;
    end

    function compare_outputs(string test);
        // Always print detailed state after each test
        log_state(test);
        if (source_data_reg_out !== ref_source_data_reg_out) begin
            $display("Test %s FAILED: source_data_reg_out mismatch: got %h, expected %h", test, source_data_reg_out, ref_source_data_reg_out);
            return 0;
        end
        if (rd_data_reg_out !== ref_rd_data_reg_out) begin
            $display("Test %s FAILED: rd_data_reg_out mismatch: got %h, expected %h", test, rd_data_reg_out, ref_rd_data_reg_out);
            return 0;
        end
        if (instruction_reg_out !== ref_instruction_reg_out) begin
            $display("Test %s FAILED: instruction_reg_out mismatch: got %h, expected %h", test, instruction_reg_out, ref_instruction_reg_out);
            return 0;
        end
        if (program_counter_reg_out !== ref_program_counter_reg_out) begin
            $display("Test %s FAILED: program_counter_reg_out mismatch: got %h, expected %h", test, program_counter_reg_out, ref_program_counter_reg_out);
            return 0;
        end
        if (next_program_counter_reg_out !== ref_next_program_counter_reg_out) begin
            $display("Test %s FAILED: next_program_counter_reg_out mismatch: got %h, expected %h", test, next_program_counter_reg_out, ref_next_program_counter_reg_out);
            return 0;
        end
        if (forwarding_out !== ref_forwarding_out) begin
            $display("Test %s FAILED: forwarding_out mismatch: got {data_valid=%0d, data=%08h, address=%0d}, expected {data_valid=%0d, data=%08h, address=%0d}", test, forwarding_out.data_valid, forwarding_out.data, forwarding_out.address, ref_forwarding_out.data_valid, ref_forwarding_out.data, ref_forwarding_out.address);
            return 0;
        end
        if (status_forwards_out !== ref_status_forwards_out) begin
            $display("Test %s FAILED: status_forwards_out mismatch", test);
            return 0;
        end
        if (status_backwards_out !== ref_status_backwards_out) begin
            $display("Test %s FAILED: status_backwards_out mismatch", test);
            return 0;
        end
        if (jump_address_backwards_out !== ref_jump_address_backwards_out) begin
            $display("Test %s FAILED: jump_address_backwards_out mismatch: got %h, expected %h", test, jump_address_backwards_out, ref_jump_address_backwards_out);
            return 0;
        end
        $display("Test %s PASSED", test);
        return 1;
    endfunction

    // Detailed logger for inputs and outputs (DUT vs REF)
    task log_state(string label);
        $display("\n--- State dump for %s ---", label);
        $display("  INPUTS:");
        $display("    PC_in=%08h next_PC_in=%08h", program_counter_in, next_program_counter_in);
        $display("    source_data_in=%08h rd_data_in=%08h", source_data_in, rd_data_in);
        $display("    instruction_in.op=%s rd=%0d rs1=%0d rs2=%0d imm=%08h csr=%0d",
                 instruction_in.op.name(), instruction_in.rd_address, instruction_in.rs1_address, instruction_in.rs2_address, instruction_in.immediate, instruction_in.csr);
        $display("    status_forwards_in=%0d status_backwards_in=%0d jump_addr_backwards_in=%08h",
                 status_forwards_in, status_backwards_in, jump_address_backwards_in);

        $display("  DUT OUTPUTS:");
        $display("    rd_data_reg_out=%08h source_data_reg_out=%08h", rd_data_reg_out, source_data_reg_out);
        $display("    instruction_reg_out.op=%s rd=%0d rs1=%0d rs2=%0d imm=%08h csr=%0d",
                 instruction_reg_out.op.name(), instruction_reg_out.rd_address, instruction_reg_out.rs1_address, instruction_reg_out.rs2_address, instruction_reg_out.immediate, instruction_reg_out.csr);
        $display("    program_counter_reg_out=%08h next_program_counter_reg_out=%08h", program_counter_reg_out, next_program_counter_reg_out);
        $display("    forwarding_out: valid=%0d data=%08h addr=%0d", forwarding_out.data_valid, forwarding_out.data, forwarding_out.address);
        $display("    status_forwards_out=%0d status_backwards_out=%0d jump_address_backwards_out=%08h",
                 status_forwards_out, status_backwards_out, jump_address_backwards_out);

        $display("  REF OUTPUTS:");
        $display("    rd_data_reg_out=%08h source_data_reg_out=%08h", ref_rd_data_reg_out, ref_source_data_reg_out);
        $display("    instruction_reg_out.op=%s rd=%0d rs1=%0d rs2=%0d imm=%08h csr=%0d",
                 ref_instruction_reg_out.op.name(), ref_instruction_reg_out.rd_address, ref_instruction_reg_out.rs1_address, ref_instruction_reg_out.rs2_address, ref_instruction_reg_out.immediate, ref_instruction_reg_out.csr);
        $display("    program_counter_reg_out=%08h next_program_counter_reg_out=%08h", ref_program_counter_reg_out, ref_next_program_counter_reg_out);
        $display("    forwarding_out: valid=%0d data=%08h addr=%0d", ref_forwarding_out.data_valid, ref_forwarding_out.data, ref_forwarding_out.address);
        $display("    status_forwards_out=%0d status_backwards_out=%0d jump_address_backwards_out=%08h",
                 ref_status_forwards_out, ref_status_backwards_out, ref_jump_address_backwards_out);
        $display("--- End state dump for %s ---\n", label);
    endtask

endmodule
