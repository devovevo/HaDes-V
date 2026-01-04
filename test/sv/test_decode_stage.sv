module test_decode_stage;
    import clk_params::*;

    logic clk;
    logic rst;

    initial begin
        clk = 0;
        forever #(SIM_CYCLES_PER_SYS_CLK / 2) clk = ~clk;
    end

    // Inputs
    logic [31:0]  instruction_in;
    logic [31:0]  program_counter_in;
    forwarding::t exe_forwarding_in;
    forwarding::t mem_forwarding_in;
    forwarding::t wb_forwarding_in;
    pipeline_status::forwards_t  status_forwards_in;
    pipeline_status::backwards_t status_backwards_in;
    logic [31:0] jump_address_backwards_in;

    // DUT Outputs
    logic [31:0]   rs1_data_reg_out;
    logic [31:0]   rs2_data_reg_out;
    logic [31:0]   program_counter_reg_out;
    instruction::t instruction_reg_out;
    pipeline_status::forwards_t  status_forwards_out;
    pipeline_status::backwards_t status_backwards_out;
    logic [31:0] jump_address_backwards_out;

    // Instantiate the DUT
    decode_stage dut (
        .clk(clk),
        .rst(rst),
        .instruction_in(instruction_in),
        .program_counter_in(program_counter_in),
        .exe_forwarding_in(exe_forwarding_in),
        .mem_forwarding_in(mem_forwarding_in),
        .wb_forwarding_in(wb_forwarding_in),
        .rs1_data_reg_out(rs1_data_reg_out),
        .rs2_data_reg_out(rs2_data_reg_out),
        .program_counter_reg_out(program_counter_reg_out),
        .instruction_reg_out(instruction_reg_out),
        .status_forwards_in(status_forwards_in),
        .status_forwards_out(status_forwards_out),
        .status_backwards_in(status_backwards_in),
        .status_backwards_out(status_backwards_out),
        .jump_address_backwards_in(jump_address_backwards_in),
        .jump_address_backwards_out(jump_address_backwards_out)
    );

    // REF Outputs
    logic [31:0]   rs1_data_reg_out_ref;
    logic [31:0]   rs2_data_reg_out_ref;
    logic [31:0]   program_counter_reg_out_ref;
    instruction::t instruction_reg_out_ref;
    pipeline_status::forwards_t  status_forwards_out_ref;
    pipeline_status::backwards_t status_backwards_out_ref;
    logic [31:0] jump_address_backwards_out_ref;

    // Instantiate the REF
    ref_decode_stage ref_inst (
        .clk(clk),
        .rst(rst),
        .instruction_in(instruction_in),
        .program_counter_in(program_counter_in),
        .exe_forwarding_in(exe_forwarding_in),
        .mem_forwarding_in(mem_forwarding_in),
        .wb_forwarding_in(wb_forwarding_in),
        .rs1_data_reg_out(rs1_data_reg_out_ref),
        .rs2_data_reg_out(rs2_data_reg_out_ref),
        .program_counter_reg_out(program_counter_reg_out_ref),
        .instruction_reg_out(instruction_reg_out_ref),
        .status_forwards_in(status_forwards_in),
        .status_forwards_out(status_forwards_out_ref),
        .status_backwards_in(status_backwards_in),
        .status_backwards_out(status_backwards_out_ref),
        .jump_address_backwards_in(jump_address_backwards_in),
        .jump_address_backwards_out(jump_address_backwards_out_ref)
    );

    // Logging task
    task log_state(string label);
        $display("[%0t] %s", $time, label);
        $display("  INPUTS: PC=%08h INSTR=%08h status_fwd_in=%0d status_bwd_in=%0d",
                 program_counter_in, instruction_in, status_forwards_in, status_backwards_in);
        $display("  DUT: RS1=%08h RS2=%08h PC_out=%08h INSTR_out=%08h",
                 rs1_data_reg_out, rs2_data_reg_out, program_counter_reg_out, instruction_reg_out);
        $display("  REF: RS1=%08h RS2=%08h PC_out=%08h INSTR_out=%08h",
                 rs1_data_reg_out_ref, rs2_data_reg_out_ref, program_counter_reg_out_ref, instruction_reg_out_ref);
        $display("  DUT status: fwd_out=%0d bwd_out=%0d  jump_addr=%08h",
                 status_forwards_out, status_backwards_out, jump_address_backwards_out);
        $display("  REF status: fwd_out=%0d bwd_out=%0d  jump_addr=%08h",
                 status_forwards_out_ref, status_backwards_out_ref, jump_address_backwards_out_ref);
    endtask

    // Testbench procedure
    initial begin
        // Dump waveforms for GTKWave
        $dumpfile("test_decode_stage.fst");
        $dumpvars(0, test_decode_stage);

        $display("\n=== Decode Stage Testbench Started ===\n");

        rst = 1;
        instruction_in = '0;
        program_counter_in = '0;
        exe_forwarding_in = '0;
        mem_forwarding_in = '0;
        wb_forwarding_in = '0;
        status_forwards_in = pipeline_status::BUBBLE;
        status_backwards_in = pipeline_status::READY;
        jump_address_backwards_in = '0;

        @(posedge clk); #1;
        rst = 0;
        log_state("After reset");

        // Test 1: NOP
        instruction_in = 32'h00000013; // NOP (addi x0, x0, 0)
        program_counter_in = 32'h00000000;
        @(posedge clk); #1;
        log_state("Test 1: NOP");
        if (!compare_outputs("NOP")) fail_test("Test 1 failed.");

        // Test 2: ADDI x2, x0, 5
        instruction_in = 32'h00500113;
        program_counter_in = 32'h00000004;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 2: ADDI x2, x0, 5");
        if (!compare_outputs("ADDI")) fail_test("Test 2 failed.");

        // Test 3: ADDI x3, x2, 10 with exe forwarding for x2 = 5
        // Instruction: ADDI x3, x2, 10  =>  imm=10, rs1=x2, funct3=000, rd=x3, opcode=0010011
        // Encoding: imm[11:0]=0x00A, rs1=00010, funct3=000, rd=00011, opcode=0010011
        // = 0000_0000_1010_00010_000_00011_0010011 = 0x00A10193
        instruction_in = 32'h00A10193; // ADDI x3, x2, 10
        program_counter_in = 32'h00000008;
        exe_forwarding_in.data_valid = 1'b1;
        exe_forwarding_in.address = 5'd2;  // x2
        exe_forwarding_in.data = 32'd5;    // forwarded value
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 3: ADDI x3, x2, 10 with exe fwd x2=5");
        if (!compare_outputs("ADDI+FWD")) fail_test("Test 3 failed.");

        // Clear forwarding for subsequent tests
        exe_forwarding_in = '0;

        // =====================================================
        // Test 4: STALL - check what REF does with PC/instruction
        // =====================================================
        // First, set up a valid instruction
        instruction_in = 32'h00C00193; // ADDI x3, x0, 12
        program_counter_in = 32'h0000000C;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 4a: Setup before STALL");
        
        // Now change input but signal STALL - check if REF updates or holds
        instruction_in = 32'h00D00213; // ADDI x4, x0, 13 (different instruction)
        program_counter_in = 32'h00000010; // different PC
        status_backwards_in = pipeline_status::STALL;
        @(posedge clk); #1;
        log_state("Test 4b: During STALL - REF PC/instr updated or held?");
        // Log what REF actually does - don't fail yet, just observe
        $display("  [INFO] REF PC_out=%08h (old=0x0C, new=0x10)", program_counter_reg_out_ref);
        $display("  [INFO] If REF shows 0x10, it updates on STALL. If 0x0C, it holds.");
        if (!compare_outputs("STALL")) fail_test("Test 4 failed.");

        // =====================================================
        // Test 5: JUMP - should insert bubble
        // =====================================================
        instruction_in = 32'h00D00213; // ADDI x4, x0, 13
        program_counter_in = 32'h00000010;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::JUMP;
        @(posedge clk); #1;
        log_state("Test 5: JUMP (should bubble)");
        if (!compare_outputs("JUMP")) fail_test("Test 5 failed.");

        // =====================================================
        // Test 6: BUBBLE propagation
        // =====================================================
        instruction_in = 32'h00E00293; // ADDI x5, x0, 14
        program_counter_in = 32'h00000014;
        status_forwards_in = pipeline_status::BUBBLE;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 6: BUBBLE propagation");
        if (!compare_outputs("BUBBLE")) fail_test("Test 6 failed.");

        // =====================================================
        // Test 7: MEM forwarding (rs1)
        // =====================================================
        // ADD x6, x5, x4 - reads x5 (rs1) and x4 (rs2)
        // Encoding: 0000000_00100_00101_000_00110_0110011 = 0x00428333
        instruction_in = 32'h00428333; // ADD x6, x5, x4
        program_counter_in = 32'h00000018;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        mem_forwarding_in.data_valid = 1'b1;
        mem_forwarding_in.address = 5'd5;  // x5
        mem_forwarding_in.data = 32'h0000_00AA;
        @(posedge clk); #1;
        log_state("Test 7: ADD x6, x5, x4 with mem fwd x5=0xAA");
        if (!compare_outputs("MEM_FWD")) fail_test("Test 7 failed.");
        mem_forwarding_in = '0;

        // =====================================================
        // Test 8: WB forwarding (rs2)
        // =====================================================
        // ADD x7, x5, x4 - reads x5 (rs1) and x4 (rs2)
        instruction_in = 32'h00428333; // ADD x6, x5, x4
        program_counter_in = 32'h0000001C;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        wb_forwarding_in.data_valid = 1'b1;
        wb_forwarding_in.address = 5'd4;  // x4
        wb_forwarding_in.data = 32'h0000_00BB;
        @(posedge clk); #1;
        log_state("Test 8: ADD x6, x5, x4 with wb fwd x4=0xBB");
        if (!compare_outputs("WB_FWD")) fail_test("Test 8 failed.");
        wb_forwarding_in = '0;

        // =====================================================
        // Test 9: Multiple forwarding (exe > mem > wb priority)
        // =====================================================
        instruction_in = 32'h00428333; // ADD x6, x5, x4
        program_counter_in = 32'h00000020;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        // All forward x5, but exe should win
        exe_forwarding_in.data_valid = 1'b1;
        exe_forwarding_in.address = 5'd5;
        exe_forwarding_in.data = 32'h0000_0011; // should be used
        mem_forwarding_in.data_valid = 1'b1;
        mem_forwarding_in.address = 5'd5;
        mem_forwarding_in.data = 32'h0000_0022; // should be ignored
        wb_forwarding_in.data_valid = 1'b1;
        wb_forwarding_in.address = 5'd5;
        wb_forwarding_in.data = 32'h0000_0033; // should be ignored
        @(posedge clk); #1;
        log_state("Test 9: Forwarding priority (exe>mem>wb)");
        if (!compare_outputs("FWD_PRIORITY")) fail_test("Test 9 failed.");
        exe_forwarding_in = '0;
        mem_forwarding_in = '0;
        wb_forwarding_in = '0;

        // =====================================================
        // Test 10: LUI instruction
        // =====================================================
        // LUI x8, 0x12345  =>  imm[31:12]=0x12345, rd=x8, opcode=0110111
        // = 0001_0010_0011_0100_0101_01000_0110111 = 0x12345437
        instruction_in = 32'h12345437; // LUI x8, 0x12345
        program_counter_in = 32'h00000024;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 10: LUI x8, 0x12345");
        if (!compare_outputs("LUI")) fail_test("Test 10 failed.");

        // =====================================================
        // Test 11: JAL instruction
        // =====================================================
        // JAL x1, 0x100 (offset 256)
        // Encoding is complex, using pre-computed: 0x100000EF
        instruction_in = 32'h100000EF; // JAL x1, 256
        program_counter_in = 32'h00000028;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 11: JAL x1, 256");
        if (!compare_outputs("JAL")) fail_test("Test 11 failed.");

        // =====================================================
        // Test 12: BEQ instruction (branch)
        // =====================================================
        // BEQ x1, x2, 16  =>  imm=16, rs2=x2, rs1=x1, funct3=000, opcode=1100011
        // Encoding: 0x00208863
        instruction_in = 32'h00208863; // BEQ x1, x2, 16
        program_counter_in = 32'h0000002C;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 12: BEQ x1, x2, 16");
        if (!compare_outputs("BEQ")) fail_test("Test 12 failed.");

        // =====================================================
        // Test 13: SW instruction (store)
        // =====================================================
        // SW x2, 4(x1)  =>  imm=4, rs2=x2, rs1=x1, funct3=010, opcode=0100011
        // Encoding: 0x0020A223
        instruction_in = 32'h0020A223; // SW x2, 4(x1)
        program_counter_in = 32'h00000030;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 13: SW x2, 4(x1)");
        if (!compare_outputs("SW")) fail_test("Test 13 failed.");

        // =====================================================
        // Test 14: LW instruction (load)
        // =====================================================
        // LW x3, 8(x1)  =>  imm=8, rs1=x1, funct3=010, rd=x3, opcode=0000011
        // Encoding: 0x0080A183
        instruction_in = 32'h0080A183; // LW x3, 8(x1)
        program_counter_in = 32'h00000034;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 14: LW x3, 8(x1)");
        if (!compare_outputs("LW")) fail_test("Test 14 failed.");

        // =====================================================
        // Test 15: ECALL instruction
        // =====================================================
        instruction_in = 32'h00000073; // ECALL
        program_counter_in = 32'h00000038;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 15: ECALL");
        if (!compare_outputs("ECALL")) fail_test("Test 15 failed.");

        // =====================================================
        // Test 16: EBREAK instruction
        // =====================================================
        instruction_in = 32'h00100073; // EBREAK
        program_counter_in = 32'h0000003C;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 16: EBREAK");
        if (!compare_outputs("EBREAK")) fail_test("Test 16 failed.");

        // =====================================================
        // Test 17: Jump address passthrough
        // =====================================================
        instruction_in = 32'h00000013; // NOP
        program_counter_in = 32'h00000040;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        jump_address_backwards_in = 32'h0000_1000; // Jump target from later stage
        @(posedge clk); #1;
        log_state("Test 17: Jump address passthrough");
        if (!compare_outputs("JUMP_ADDR")) fail_test("Test 17 failed.");
        jump_address_backwards_in = '0;

        // =====================================================
        // Test 18: Forwarding to x0 should be ignored
        // =====================================================
        // ADDI x1, x0, 5 - rs1 is x0, forwarding should NOT apply
        instruction_in = 32'h00500093; // ADDI x1, x0, 5
        program_counter_in = 32'h00000044;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        exe_forwarding_in.data_valid = 1'b1;
        exe_forwarding_in.address = 5'd0;  // x0
        exe_forwarding_in.data = 32'hFFFF_FFFF; // should be ignored
        @(posedge clk); #1;
        log_state("Test 18: Forwarding to x0 ignored");
        if (!compare_outputs("X0_FWD")) fail_test("Test 18 failed.");
        exe_forwarding_in = '0;

        // =====================================================
        // Test 19: ILLEGAL instruction
        // =====================================================
        instruction_in = 32'hFFFF_FFFF; // Illegal
        program_counter_in = 32'h00000048;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 19: ILLEGAL instruction");
        if (!compare_outputs("ILLEGAL")) fail_test("Test 19 failed.");

        // =====================================================
        // Test 20: Recovery from STALL
        // =====================================================
        // Setup
        instruction_in = 32'h01400313; // ADDI x6, x0, 20
        program_counter_in = 32'h0000004C;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::STALL;
        @(posedge clk); #1;
        log_state("Test 20a: STALL");
        
        // Now ready - should process
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 20b: Recovery from STALL");
        if (!compare_outputs("STALL_RECOVER")) fail_test("Test 20 failed.");

        // =====================================================
        // Test 21: CSRRW then dependent ADDI - observe bubbles/stalls
        // CSRRW x3, csr=0x300 (mstatus), rs1=x2
        instruction_in = 32'h300111F3; // CSRRW x3, csr=0x300, rs1=x2
        program_counter_in = 32'h00000050;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 21a: CSRRW x3, csr=0x001, rs1=x2");
        if (!compare_outputs("CSRRW")) fail_test("Test 21a failed.");

        // Dependent instruction: ADDI x4, x3, 1  (reads rd=x3)
        instruction_in = 32'h00118213; // ADDI x4, x3, 1
        program_counter_in = 32'h00000054;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 21b: ADDI x4, x3, 1 (depends on CSRRW result)");
        if (!compare_outputs("CSRRW+ADDI")) fail_test("Test 21b failed.");

        // =====================================================
        // Test 22: CSRRS (read CSR into rd) then a NOP - check behavior
        // CSRRS x3, csr=0x300, rs1=x0  (reads CSR only)
        instruction_in = 32'h300021F3; // CSRRS x3, csr=0x300, rs1=x0
        program_counter_in = 32'h00000058;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 22a: CSRRS x3, csr=0x300, rs1=x0");
        if (!compare_outputs("CSRRS")) fail_test("Test 22a failed.");

        instruction_in = 32'h00000013; // NOP
        program_counter_in = 32'h0000005C;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 22b: NOP after CSRRS");
        if (!compare_outputs("CSRRS+NOP")) fail_test("Test 22b failed.");

        // =====================================================
        // Test 23: CSRRWI (immediate) then dependent ADDI
        // CSRRWI x5, csr=0x305, zimm=1  (write immediate to CSR, rd gets old CSR)
        instruction_in = 32'h3050AAF3; // CSRRWI x5, csr=0x305, zimm=1
        program_counter_in = 32'h00000060;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 23a: CSRRWI x5, csr=0x305, zimm=1");
        if (!compare_outputs("CSRRWI")) fail_test("Test 23a failed.");

        // Dependent: ADDI x6, x5, 2
        instruction_in = 32'h00228313; // ADDI x6, x5, 2
        program_counter_in = 32'h00000064;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 23b: ADDI x6, x5, 2 (depends on CSRRWI result)");
        if (!compare_outputs("CSRRWI+ADDI")) fail_test("Test 23b failed.");

        // =====================================================
        // Test 24: Insert STALL during CSR to see hold/propagation
        instruction_in = 32'h300111F3; // CSRRW x3, csr=0x300, rs1=x2
        program_counter_in = 32'h00000068;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::STALL;
        @(posedge clk); #1;
        log_state("Test 24a: CSRRW while STALL asserted");

        // Now change inputs while STALL is asserted (REF may hold)
        instruction_in = 32'h00A00013; // ADDI x0, x0, 10 (different)
        program_counter_in = 32'h0000006C;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::STALL;
        @(posedge clk); #1;
        log_state("Test 24b: Inputs changed during STALL");
        if (!compare_outputs("CSR_STALL")) fail_test("Test 24 failed.");

        // Release STALL and ensure recovery
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 24c: Recovery after STALL during CSR");
        if (!compare_outputs("CSR_STALL_RECOVER")) fail_test("Test 24 recovery failed.");

        repeat(2) begin
            @(posedge clk);
            #1;
        end   // Wait a few cycles before finishing

        $display("\n=== All tests passed ===\n");
        $finish;
    end

    function automatic int compare_outputs(string test_name);
        int pass = 1;

        if (rs1_data_reg_out !== rs1_data_reg_out_ref) begin
            $display("  [FAIL] rs1_data_reg_out: DUT=%h REF=%h", rs1_data_reg_out, rs1_data_reg_out_ref);
            pass = 0;
        end
        if (rs2_data_reg_out !== rs2_data_reg_out_ref) begin
            $display("  [FAIL] rs2_data_reg_out: DUT=%h REF=%h", rs2_data_reg_out, rs2_data_reg_out_ref);
            pass = 0;
        end
        if (program_counter_reg_out !== program_counter_reg_out_ref) begin
            $display("  [FAIL] program_counter_reg_out: DUT=%h REF=%h", program_counter_reg_out, program_counter_reg_out_ref);
            pass = 0;
        end
        if (instruction_reg_out !== instruction_reg_out_ref) begin
            $display("  [FAIL] instruction_reg_out: DUT=%h REF=%h", instruction_reg_out, instruction_reg_out_ref);
            pass = 0;
        end
        if (status_forwards_out !== status_forwards_out_ref) begin
            $display("  [FAIL] status_forwards_out: DUT=%h REF=%h", status_forwards_out, status_forwards_out_ref);
            pass = 0;
        end
        if (status_backwards_out !== status_backwards_out_ref) begin
            $display("  [FAIL] status_backwards_out: DUT=%h REF=%h", status_backwards_out, status_backwards_out_ref);
            pass = 0;
        end
        if (jump_address_backwards_out !== jump_address_backwards_out_ref) begin
            $display("  [FAIL] jump_address_backwards_out: DUT=%h REF=%h", jump_address_backwards_out, jump_address_backwards_out_ref);
            pass = 0;
        end

        if (pass) $display("  [PASS] %s", test_name);
        return pass;
    endfunction

    // Task to fail a test with delay for waveform visibility
    task fail_test(string msg);
        $display("\n!!! TEST FAILED: %s !!!\n", msg);
        // Wait several clock cycles so signals are visible in waveform
        repeat(2) begin
            @(posedge clk);
            #1;
        end
        $fatal(1, msg);
    endtask

endmodule
