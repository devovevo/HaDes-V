module test_execute_stage;
    import clk_params::*;

    logic clk;
    logic rst;

    initial begin
        clk = 0;
        forever #(SIM_CYCLES_PER_SYS_CLK / 2) clk = ~clk;
    end

    // Inputs
    logic [31:0]   rs1_data_in;
    logic [31:0]   rs2_data_in;
    instruction::t instruction_in;
    logic [31:0]   program_counter_in;
    pipeline_status::forwards_t  status_forwards_in;
    pipeline_status::backwards_t status_backwards_in;
    logic [31:0] jump_address_backwards_in;

    // DUT Outputs
    logic [31:0]   source_data_reg_out;
    logic [31:0]   rd_data_reg_out;
    instruction::t instruction_reg_out;
    logic [31:0]   program_counter_reg_out;
    logic [31:0]   next_program_counter_reg_out;
    forwarding::t  forwarding_out;
    pipeline_status::forwards_t  status_forwards_out;
    pipeline_status::backwards_t status_backwards_out;
    logic [31:0] jump_address_backwards_out;

    // Instantiate the DUT
    execute_stage dut (
        .clk(clk),
        .rst(rst),
        .rs1_data_inn(rs1_data_in),
        .rs2_data_inn(rs2_data_in),
        .instruction_in(instruction_in),
        .program_counter_in(program_counter_in),
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

    // REF Outputs
    logic [31:0]   source_data_reg_out_ref;
    logic [31:0]   rd_data_reg_out_ref;
    instruction::t instruction_reg_out_ref;
    logic [31:0]   program_counter_reg_out_ref;
    logic [31:0]   next_program_counter_reg_out_ref;
    forwarding::t  forwarding_out_ref;
    pipeline_status::forwards_t  status_forwards_out_ref;
    pipeline_status::backwards_t status_backwards_out_ref;
    logic [31:0] jump_address_backwards_out_ref;

    // Instantiate the REF - TEMPORARILY DISABLED due to DPI library "Settle region did not converge" error
    // The reference library appears to have an internal issue. Testing DUT only for now.
    ref_execute_stage ref_inst (
        .clk(clk),
        .rst(rst),
        .rs1_data_in(rs1_data_in),
        .rs2_data_in(rs2_data_in),
        .instruction_in(instruction_in),
        .program_counter_in(program_counter_in),
        .source_data_reg_out(source_data_reg_out_ref),
        .rd_data_reg_out(rd_data_reg_out_ref),
        .instruction_reg_out(instruction_reg_out_ref),
        .program_counter_reg_out(program_counter_reg_out_ref),
        .next_program_counter_reg_out(next_program_counter_reg_out_ref),
        .forwarding_out(forwarding_out_ref),
        .status_forwards_in(status_forwards_in),
        .status_forwards_out(status_forwards_out_ref),
        .status_backwards_in(status_backwards_in),
        .status_backwards_out(status_backwards_out_ref),
        .jump_address_backwards_in(jump_address_backwards_in),
        .jump_address_backwards_out(jump_address_backwards_out_ref)
    );
    
    // Assign REF outputs to match DUT for now (skip comparison)
    // assign source_data_reg_out_ref = source_data_reg_out;
    // assign rd_data_reg_out_ref = rd_data_reg_out;
    // assign instruction_reg_out_ref = instruction_reg_out;
    // assign program_counter_reg_out_ref = program_counter_reg_out;
    // assign next_program_counter_reg_out_ref = next_program_counter_reg_out;
    // assign forwarding_out_ref = forwarding_out;
    // assign status_forwards_out_ref = status_forwards_out;
    // assign status_backwards_out_ref = status_backwards_out;
    // assign jump_address_backwards_out_ref = jump_address_backwards_out;

    // Logging task
    task log_state(string label);
        $display("[%0t] %s", $time, label);
        $display("  INPUTS: PC=%08h rs1=%08h rs2=%08h op=%s",
                 program_counter_in, rs1_data_in, rs2_data_in, instruction_in.op.name());
        $display("  INPUTS: imm=%08h rd_addr=%0d status_fwd_in=%0d status_bwd_in=%0d",
                 instruction_in.immediate, instruction_in.rd_address, status_forwards_in, status_backwards_in);
        $display("  DUT: rd_data=%08h src_data=%08h PC_out=%08h next_PC=%08h",
                 rd_data_reg_out, source_data_reg_out, program_counter_reg_out, next_program_counter_reg_out);
        $display("  REF: rd_data=%08h src_data=%08h PC_out=%08h next_PC=%08h",
                 rd_data_reg_out_ref, source_data_reg_out_ref, program_counter_reg_out_ref, next_program_counter_reg_out_ref);
        $display("  DUT status: fwd_out=%0d bwd_out=%0d jump_addr=%08h",
                 status_forwards_out, status_backwards_out, jump_address_backwards_out);
        $display("  REF status: fwd_out=%0d bwd_out=%0d jump_addr=%08h",
                 status_forwards_out_ref, status_backwards_out_ref, jump_address_backwards_out_ref);
        $display("  DUT fwd: valid=%0d data=%08h addr=%0d",
                 forwarding_out.data_valid, forwarding_out.data, forwarding_out.address);
        $display("  REF fwd: valid=%0d data=%08h addr=%0d",
                 forwarding_out_ref.data_valid, forwarding_out_ref.data, forwarding_out_ref.address);
    endtask

    // Helper function to create instruction struct
    function automatic instruction::t make_instr(
        op::t opcode,
        logic [4:0] rd = 5'd0,
        logic [4:0] rs1 = 5'd0,
        logic [4:0] rs2 = 5'd0,
        logic [31:0] imm = 32'd0
    );
        instruction::t instr;
        instr.op = opcode;
        instr.rd_address = rd;
        instr.rs1_address = rs1;
        instr.rs2_address = rs2;
        instr.csr = csr::t'(12'b0);
        instr.immediate = imm;
        return instr;
    endfunction

    // Testbench procedure
    initial begin
        // Initialize inputs BEFORE simulation starts (time 0)
        rst = 1;
        rs1_data_in = 32'b0;
        rs2_data_in = 32'b0;
        instruction_in.op = op::ADDI;
        instruction_in.rd_address = 5'b0;
        instruction_in.rs1_address = 5'b0;
        instruction_in.rs2_address = 5'b0;
        instruction_in.csr = csr::MSTATUS;
        instruction_in.immediate = 32'b0;
        program_counter_in = 32'h0004_0000;
        status_forwards_in = pipeline_status::BUBBLE;
        status_backwards_in = pipeline_status::READY;
        jump_address_backwards_in = 32'b0;

        // Dump waveforms for GTKWave
        $dumpfile("test_execute_stage.fst");
        $dumpvars(0, test_execute_stage);

        $display("\n=== Execute Stage Testbench Started ===\n");

        // Hold reset for a few cycles
        repeat(3) @(posedge clk);
        #1;
        rst = 0;
        @(posedge clk); #1;
        log_state("After reset");

        // =====================================================
        // Test 1: NOP (ADDI x0, x0, 0)
        // =====================================================
        instruction_in = instruction::NOP;
        program_counter_in = 32'h0004_0000;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::READY;
        @(posedge clk); #1;
        log_state("Test 1: NOP");
        if (!compare_outputs("NOP")) fail_test("Test 1 failed.");

        // =====================================================
        // Test 2: ADD x3, x1, x2 (basic register addition)
        // =====================================================
        instruction_in = make_instr(op::ADD, .rd(5'd3), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'd100;
        rs2_data_in = 32'd50;
        program_counter_in = 32'h0004_0004;
        @(posedge clk); #1;
        log_state("Test 2: ADD x3, x1, x2 (100 + 50)");
        if (!compare_outputs("ADD")) fail_test("Test 2 failed.");

        // =====================================================
        // Test 3: SUB x4, x1, x2 (basic register subtraction)
        // =====================================================
        instruction_in = make_instr(op::SUB, .rd(5'd4), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'd100;
        rs2_data_in = 32'd30;
        program_counter_in = 32'h0004_0008;
        @(posedge clk); #1;
        log_state("Test 3: SUB x4, x1, x2 (100 - 30)");
        if (!compare_outputs("SUB")) fail_test("Test 3 failed.");

        // =====================================================
        // Test 4: ADDI x5, x1, 25 (immediate addition)
        // =====================================================
        instruction_in = make_instr(op::ADDI, .rd(5'd5), .rs1(5'd1), .imm(32'd25));
        rs1_data_in = 32'd100;
        program_counter_in = 32'h0004_000C;
        @(posedge clk); #1;
        log_state("Test 4: ADDI x5, x1, 25 (100 + 25)");
        if (!compare_outputs("ADDI")) fail_test("Test 4 failed.");

        // =====================================================
        // Test 5: ADDI with negative immediate
        // =====================================================
        instruction_in = make_instr(op::ADDI, .rd(5'd5), .rs1(5'd1), .imm(32'hFFFF_FFF6)); // -10
        rs1_data_in = 32'd100;
        program_counter_in = 32'h0004_0010;
        @(posedge clk); #1;
        log_state("Test 5: ADDI x5, x1, -10 (100 + (-10))");
        if (!compare_outputs("ADDI_NEG")) fail_test("Test 5 failed.");

        // =====================================================
        // Test 6: AND x6, x1, x2
        // =====================================================
        instruction_in = make_instr(op::AND, .rd(5'd6), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'hFF00_FF00;
        rs2_data_in = 32'h0F0F_0F0F;
        program_counter_in = 32'h0004_0014;
        @(posedge clk); #1;
        log_state("Test 6: AND x6, x1, x2");
        if (!compare_outputs("AND")) fail_test("Test 6 failed.");

        // =====================================================
        // Test 7: OR x7, x1, x2
        // =====================================================
        instruction_in = make_instr(op::OR, .rd(5'd7), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'hFF00_FF00;
        rs2_data_in = 32'h0F0F_0F0F;
        program_counter_in = 32'h0004_0018;
        @(posedge clk); #1;
        log_state("Test 7: OR x7, x1, x2");
        if (!compare_outputs("OR")) fail_test("Test 7 failed.");

        // =====================================================
        // Test 8: XOR x8, x1, x2
        // =====================================================
        instruction_in = make_instr(op::XOR, .rd(5'd8), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'hFF00_FF00;
        rs2_data_in = 32'h0F0F_0F0F;
        program_counter_in = 32'h0004_001C;
        @(posedge clk); #1;
        log_state("Test 8: XOR x8, x1, x2");
        if (!compare_outputs("XOR")) fail_test("Test 8 failed.");

        // =====================================================
        // Test 9: ANDI x9, x1, 0xFF
        // =====================================================
        instruction_in = make_instr(op::ANDI, .rd(5'd9), .rs1(5'd1), .imm(32'h0000_00FF));
        rs1_data_in = 32'h1234_5678;
        program_counter_in = 32'h0004_0020;
        @(posedge clk); #1;
        log_state("Test 9: ANDI x9, x1, 0xFF");
        if (!compare_outputs("ANDI")) fail_test("Test 9 failed.");

        // =====================================================
        // Test 10: ORI x10, x1, 0xFF00
        // =====================================================
        instruction_in = make_instr(op::ORI, .rd(5'd10), .rs1(5'd1), .imm(32'h0000_FF00));
        rs1_data_in = 32'h0000_00FF;
        program_counter_in = 32'h0004_0024;
        @(posedge clk); #1;
        log_state("Test 10: ORI x10, x1, 0xFF00");
        if (!compare_outputs("ORI")) fail_test("Test 10 failed.");

        // =====================================================
        // Test 11: XORI x11, x1, 0xFFFF
        // =====================================================
        instruction_in = make_instr(op::XORI, .rd(5'd11), .rs1(5'd1), .imm(32'h0000_FFFF));
        rs1_data_in = 32'h0000_FF00;
        program_counter_in = 32'h0004_0028;
        @(posedge clk); #1;
        log_state("Test 11: XORI x11, x1, 0xFFFF");
        if (!compare_outputs("XORI")) fail_test("Test 11 failed.");

        // =====================================================
        // Test 12: SLL x12, x1, x2 (shift left logical)
        // =====================================================
        instruction_in = make_instr(op::SLL, .rd(5'd12), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'h0000_0001;
        rs2_data_in = 32'd4; // shift by 4
        program_counter_in = 32'h0004_002C;
        @(posedge clk); #1;
        log_state("Test 12: SLL x12, x1, x2 (1 << 4)");
        if (!compare_outputs("SLL")) fail_test("Test 12 failed.");

        // =====================================================
        // Test 13: SRL x13, x1, x2 (shift right logical)
        // =====================================================
        instruction_in = make_instr(op::SRL, .rd(5'd13), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'h8000_0000;
        rs2_data_in = 32'd4; // shift by 4
        program_counter_in = 32'h0004_0030;
        @(posedge clk); #1;
        log_state("Test 13: SRL x13, x1, x2 (0x80000000 >> 4)");
        if (!compare_outputs("SRL")) fail_test("Test 13 failed.");

        // =====================================================
        // Test 14: SRA x14, x1, x2 (shift right arithmetic)
        // =====================================================
        instruction_in = make_instr(op::SRA, .rd(5'd14), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'h8000_0000; // negative number
        rs2_data_in = 32'd4; // shift by 4
        program_counter_in = 32'h0004_0034;
        @(posedge clk); #1;
        log_state("Test 14: SRA x14, x1, x2 (0x80000000 >>> 4)");
        if (!compare_outputs("SRA")) fail_test("Test 14 failed.");

        // =====================================================
        // Test 15: SLLI x15, x1, 8
        // =====================================================
        instruction_in = make_instr(op::SLLI, .rd(5'd15), .rs1(5'd1), .imm(32'd8));
        rs1_data_in = 32'h0000_00FF;
        program_counter_in = 32'h0004_0038;
        @(posedge clk); #1;
        log_state("Test 15: SLLI x15, x1, 8");
        if (!compare_outputs("SLLI")) fail_test("Test 15 failed.");

        // =====================================================
        // Test 16: SRLI x16, x1, 8
        // =====================================================
        instruction_in = make_instr(op::SRLI, .rd(5'd16), .rs1(5'd1), .imm(32'd8));
        rs1_data_in = 32'hFF00_0000;
        program_counter_in = 32'h0004_003C;
        @(posedge clk); #1;
        log_state("Test 16: SRLI x16, x1, 8");
        if (!compare_outputs("SRLI")) fail_test("Test 16 failed.");

        // =====================================================
        // Test 17: SRAI x17, x1, 8
        // =====================================================
        instruction_in = make_instr(op::SRAI, .rd(5'd17), .rs1(5'd1), .imm(32'd8));
        rs1_data_in = 32'hFF00_0000; // negative
        program_counter_in = 32'h0004_0040;
        @(posedge clk); #1;
        log_state("Test 17: SRAI x17, x1, 8");
        if (!compare_outputs("SRAI")) fail_test("Test 17 failed.");

        // =====================================================
        // Test 18: LUI x18, 0x12345
        // =====================================================
        instruction_in = make_instr(op::LUI, .rd(5'd18), .imm(32'h1234_5000));
        rs1_data_in = 32'd0;
        program_counter_in = 32'h0004_0044;
        @(posedge clk); #1;
        log_state("Test 18: LUI x18, 0x12345");
        if (!compare_outputs("LUI")) fail_test("Test 18 failed.");

        // =====================================================
        // Test 19: AUIPC x19, 0x1000
        // =====================================================
        instruction_in = make_instr(op::AUIPC, .rd(5'd19), .imm(32'h0000_1000)); // upper bits
        program_counter_in = 32'h0004_0048;
        @(posedge clk); #1;
        log_state("Test 19: AUIPC x19, 0x1000");
        if (!compare_outputs("AUIPC")) fail_test("Test 19 failed.");

        // =====================================================
        // Test 20: JAL x1, 0x100 (unconditional jump)
        // =====================================================
        instruction_in = make_instr(op::JAL, .rd(5'd1), .imm(32'h0000_0100));
        program_counter_in = 32'h0004_004C;
        @(posedge clk); #1;
        log_state("Test 20: JAL x1, 0x100");
        if (!compare_outputs("JAL")) fail_test("Test 20 failed.");

        // =====================================================
        // Test 21: JALR x1, x2, 0x10
        // =====================================================
        instruction_in = make_instr(op::JALR, .rd(5'd1), .rs1(5'd2), .imm(32'h0000_0010));
        rs1_data_in = 32'h0004_0100;
        program_counter_in = 32'h0004_0050;
        @(posedge clk); #1;
        log_state("Test 21: JALR x1, x2, 0x10");
        if (!compare_outputs("JALR")) fail_test("Test 21 failed.");

        // =====================================================
        // Test 22: BEQ x1, x2, 16 (branch taken)
        // =====================================================
        instruction_in = make_instr(op::BEQ, .rs1(5'd1), .rs2(5'd2), .imm(32'd16));
        rs1_data_in = 32'd100;
        rs2_data_in = 32'd100; // equal
        program_counter_in = 32'h0004_0054;
        @(posedge clk); #1;
        log_state("Test 22: BEQ taken (rs1 == rs2)");
        if (!compare_outputs("BEQ_TAKEN")) fail_test("Test 22 failed.");

        // =====================================================
        // Test 23: BEQ x1, x2, 16 (branch not taken)
        // =====================================================
        instruction_in = make_instr(op::BEQ, .rs1(5'd1), .rs2(5'd2), .imm(32'd16));
        rs1_data_in = 32'd100;
        rs2_data_in = 32'd50; // not equal
        program_counter_in = 32'h0004_0058;
        @(posedge clk); #1;
        log_state("Test 23: BEQ not taken (rs1 != rs2)");
        if (!compare_outputs("BEQ_NOT_TAKEN")) fail_test("Test 23 failed.");

        // =====================================================
        // Test 24: BNE x1, x2, 16 (branch taken)
        // =====================================================
        instruction_in = make_instr(op::BNE, .rs1(5'd1), .rs2(5'd2), .imm(32'd16));
        rs1_data_in = 32'd100;
        rs2_data_in = 32'd50; // not equal
        program_counter_in = 32'h0004_005C;
        @(posedge clk); #1;
        log_state("Test 24: BNE taken (rs1 != rs2)");
        if (!compare_outputs("BNE_TAKEN")) fail_test("Test 24 failed.");

        // =====================================================
        // Test 25: BLT x1, x2, 16 (signed less than, taken)
        // =====================================================
        instruction_in = make_instr(op::BLT, .rs1(5'd1), .rs2(5'd2), .imm(32'd16));
        rs1_data_in = 32'hFFFF_FFFF; // -1 signed
        rs2_data_in = 32'd1;         // +1
        program_counter_in = 32'h0004_0060;
        @(posedge clk); #1;
        log_state("Test 25: BLT taken (-1 < 1)");
        if (!compare_outputs("BLT_TAKEN")) fail_test("Test 25 failed.");

        // =====================================================
        // Test 26: BGE x1, x2, 16 (signed greater or equal, taken)
        // =====================================================
        instruction_in = make_instr(op::BGE, .rs1(5'd1), .rs2(5'd2), .imm(32'd16));
        rs1_data_in = 32'd100;
        rs2_data_in = 32'd100; // equal
        program_counter_in = 32'h0004_0064;
        @(posedge clk); #1;
        log_state("Test 26: BGE taken (100 >= 100)");
        if (!compare_outputs("BGE_TAKEN")) fail_test("Test 26 failed.");

        // =====================================================
        // Test 27: BLTU x1, x2, 16 (unsigned less than)
        // =====================================================
        instruction_in = make_instr(op::BLTU, .rs1(5'd1), .rs2(5'd2), .imm(32'd16));
        rs1_data_in = 32'd1;
        rs2_data_in = 32'hFFFF_FFFF; // large unsigned
        program_counter_in = 32'h0004_0068;
        @(posedge clk); #1;
        log_state("Test 27: BLTU taken (1 < 0xFFFFFFFF unsigned)");
        if (!compare_outputs("BLTU_TAKEN")) fail_test("Test 27 failed.");

        // =====================================================
        // Test 28: BGEU x1, x2, 16 (unsigned greater or equal)
        // =====================================================
        instruction_in = make_instr(op::BGEU, .rs1(5'd1), .rs2(5'd2), .imm(32'd16));
        rs1_data_in = 32'hFFFF_FFFF;
        rs2_data_in = 32'd1;
        program_counter_in = 32'h0004_006C;
        @(posedge clk); #1;
        log_state("Test 28: BGEU taken (0xFFFFFFFF >= 1 unsigned)");
        if (!compare_outputs("BGEU_TAKEN")) fail_test("Test 28 failed.");

        // =====================================================
        // Test 29: LW x3, 8(x1) (load word - address calculation)
        // =====================================================
        instruction_in = make_instr(op::LW, .rd(5'd3), .rs1(5'd1), .imm(32'd8));
        rs1_data_in = 32'h0001_0000;
        program_counter_in = 32'h0004_0070;
        @(posedge clk); #1;
        log_state("Test 29: LW x3, 8(x1) - address calc");
        if (!compare_outputs("LW")) fail_test("Test 29 failed.");

        // =====================================================
        // Test 30: SW x2, 4(x1) (store word - source data)
        // =====================================================
        instruction_in = make_instr(op::SW, .rs1(5'd1), .rs2(5'd2), .imm(32'd4));
        rs1_data_in = 32'h0001_0000;
        rs2_data_in = 32'hDEAD_BEEF; // data to store
        program_counter_in = 32'h0004_0074;
        @(posedge clk); #1;
        log_state("Test 30: SW x2, 4(x1) - store data");
        if (!compare_outputs("SW")) fail_test("Test 30 failed.");

        // =====================================================
        // Test 31: LB (load byte)
        // =====================================================
        instruction_in = make_instr(op::LB, .rd(5'd3), .rs1(5'd1), .imm(32'd2));
        rs1_data_in = 32'h0001_0000;
        program_counter_in = 32'h0004_0078;
        @(posedge clk); #1;
        log_state("Test 31: LB x3, 2(x1)");
        if (!compare_outputs("LB")) fail_test("Test 31 failed.");

        // =====================================================
        // Test 32: SB (store byte)
        // =====================================================
        instruction_in = make_instr(op::SB, .rs1(5'd1), .rs2(5'd2), .imm(32'd1));
        rs1_data_in = 32'h0001_0000;
        rs2_data_in = 32'h0000_00AB;
        program_counter_in = 32'h0004_007C;
        @(posedge clk); #1;
        log_state("Test 32: SB x2, 1(x1)");
        if (!compare_outputs("SB")) fail_test("Test 32 failed.");

        // =====================================================
        // Test 33: LH (load halfword)
        // =====================================================
        instruction_in = make_instr(op::LH, .rd(5'd3), .rs1(5'd1), .imm(32'd2));
        rs1_data_in = 32'h0001_0000;
        program_counter_in = 32'h0004_0080;
        @(posedge clk); #1;
        log_state("Test 33: LH x3, 2(x1)");
        if (!compare_outputs("LH")) fail_test("Test 33 failed.");

        // =====================================================
        // Test 34: SH (store halfword)
        // =====================================================
        instruction_in = make_instr(op::SH, .rs1(5'd1), .rs2(5'd2), .imm(32'd2));
        rs1_data_in = 32'h0001_0000;
        rs2_data_in = 32'h0000_ABCD;
        program_counter_in = 32'h0004_0084;
        @(posedge clk); #1;
        log_state("Test 34: SH x2, 2(x1)");
        if (!compare_outputs("SH")) fail_test("Test 34 failed.");

        // =====================================================
        // Test 35: LBU (load byte unsigned)
        // =====================================================
        instruction_in = make_instr(op::LBU, .rd(5'd3), .rs1(5'd1), .imm(32'd0));
        rs1_data_in = 32'h0001_0000;
        program_counter_in = 32'h0004_0088;
        @(posedge clk); #1;
        log_state("Test 35: LBU x3, 0(x1)");
        if (!compare_outputs("LBU")) fail_test("Test 35 failed.");

        // =====================================================
        // Test 36: LHU (load halfword unsigned)
        // =====================================================
        instruction_in = make_instr(op::LHU, .rd(5'd3), .rs1(5'd1), .imm(32'd0));
        rs1_data_in = 32'h0001_0000;
        program_counter_in = 32'h0004_008C;
        @(posedge clk); #1;
        log_state("Test 36: LHU x3, 0(x1)");
        if (!compare_outputs("LHU")) fail_test("Test 36 failed.");

        // =====================================================
        // Test 37: SLTI (set less than immediate signed)
        // =====================================================
        instruction_in = make_instr(op::SLTI, .rd(5'd3), .rs1(5'd1), .imm(32'd10));
        rs1_data_in = 32'd5;
        program_counter_in = 32'h0004_0090;
        @(posedge clk); #1;
        log_state("Test 37: SLTI x3, x1, 10 (5 < 10)");
        if (!compare_outputs("SLTI")) fail_test("Test 37 failed.");

        // =====================================================
        // Test 38: SLTIU (set less than immediate unsigned)
        // =====================================================
        instruction_in = make_instr(op::SLTIU, .rd(5'd3), .rs1(5'd1), .imm(32'd10));
        rs1_data_in = 32'hFFFF_FFFF; // large unsigned, should NOT be < 10
        program_counter_in = 32'h0004_0094;
        @(posedge clk); #1;
        log_state("Test 38: SLTIU x3, x1, 10 (0xFFFFFFFF < 10 unsigned = false)");
        if (!compare_outputs("SLTIU")) fail_test("Test 38 failed.");

        // =====================================================
        // Test 39: SLT (set less than signed)
        // =====================================================
        instruction_in = make_instr(op::SLT, .rd(5'd3), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'hFFFF_FFFF; // -1 signed
        rs2_data_in = 32'd1;
        program_counter_in = 32'h0004_0098;
        @(posedge clk); #1;
        log_state("Test 39: SLT x3, x1, x2 (-1 < 1 signed = true)");
        if (!compare_outputs("SLT")) fail_test("Test 39 failed.");

        // =====================================================
        // Test 40: SLTU (set less than unsigned)
        // =====================================================
        instruction_in = make_instr(op::SLTU, .rd(5'd3), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'd1;
        rs2_data_in = 32'hFFFF_FFFF;
        program_counter_in = 32'h0004_009C;
        @(posedge clk); #1;
        log_state("Test 40: SLTU x3, x1, x2 (1 < 0xFFFFFFFF unsigned = true)");
        if (!compare_outputs("SLTU")) fail_test("Test 40 failed.");

        // =====================================================
        // Test 41: CSRRW (CSR read/write - source data test)
        // =====================================================
        instruction_in = make_instr(op::CSRRW, .rd(5'd3), .rs1(5'd1));
        rs1_data_in = 32'h1234_5678;
        program_counter_in = 32'h0004_00A0;
        @(posedge clk); #1;
        log_state("Test 41: CSRRW - source_data should be rs1");
        if (!compare_outputs("CSRRW")) fail_test("Test 41 failed.");

        // =====================================================
        // Test 42: CSRRWI (CSR read/write immediate - source data test)
        // =====================================================
        instruction_in = make_instr(op::CSRRWI, .rd(5'd3), .imm(32'd31));
        program_counter_in = 32'h0004_00A4;
        @(posedge clk); #1;
        log_state("Test 42: CSRRWI - source_data should be immediate");
        if (!compare_outputs("CSRRWI")) fail_test("Test 42 failed.");

        // =====================================================
        // Test 43: Pipeline STALL
        // =====================================================
        instruction_in = make_instr(op::ADD, .rd(5'd3), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'd200;
        rs2_data_in = 32'd100;
        program_counter_in = 32'h0004_00A8;
        status_forwards_in = pipeline_status::VALID;
        status_backwards_in = pipeline_status::STALL;
        @(posedge clk); #1;
        log_state("Test 43: Pipeline STALL");
        if (!compare_outputs("STALL")) fail_test("Test 43 failed.");

        // =====================================================
        // Test 44: Pipeline JUMP (squash)
        // =====================================================
        status_backwards_in = pipeline_status::JUMP;
        @(posedge clk); #1;
        log_state("Test 44: Pipeline JUMP (squash)");
        if (!compare_outputs("JUMP_SQUASH")) fail_test("Test 44 failed.");

        // =====================================================
        // Test 45: Recovery from JUMP
        // =====================================================
        status_backwards_in = pipeline_status::READY;
        instruction_in = make_instr(op::ADDI, .rd(5'd5), .rs1(5'd0), .imm(32'd42));
        rs1_data_in = 32'd0;
        program_counter_in = 32'h0004_00AC;
        @(posedge clk); #1;
        log_state("Test 45: Recovery from JUMP");
        if (!compare_outputs("JUMP_RECOVER")) fail_test("Test 45 failed.");

        // =====================================================
        // Test 46: BUBBLE propagation
        // =====================================================
        status_forwards_in = pipeline_status::BUBBLE;
        status_backwards_in = pipeline_status::READY;
        instruction_in = make_instr(op::ADD, .rd(5'd6), .rs1(5'd1), .rs2(5'd2));
        program_counter_in = 32'h0004_00B0;
        @(posedge clk); #1;
        log_state("Test 46: BUBBLE propagation");
        if (!compare_outputs("BUBBLE")) fail_test("Test 46 failed.");

        // =====================================================
        // Test 47: Forwarding output validity
        // =====================================================
        status_forwards_in = pipeline_status::VALID;
        instruction_in = make_instr(op::ADD, .rd(5'd10), .rs1(5'd1), .rs2(5'd2));
        rs1_data_in = 32'd50;
        rs2_data_in = 32'd25;
        program_counter_in = 32'h0004_00B4;
        @(posedge clk); #1;
        log_state("Test 47: Forwarding output (rd=x10, data=75)");
        if (!compare_outputs("FWD_OUT")) fail_test("Test 47 failed.");

        // =====================================================
        // Test 48: Jump address backwards passthrough
        // =====================================================
        instruction_in = instruction::NOP;
        program_counter_in = 32'h0004_00B8;
        jump_address_backwards_in = 32'h0000_8000;
        @(posedge clk); #1;
        log_state("Test 48: Jump address backwards passthrough");
        if (!compare_outputs("JUMP_ADDR_PASS")) fail_test("Test 48 failed.");
        jump_address_backwards_in = '0;

        // =====================================================
        // Test 49: Negative branch offset (BEQ backwards)
        // =====================================================
        instruction_in = make_instr(op::BEQ, .rs1(5'd1), .rs2(5'd2), .imm(32'hFFFF_FFF0)); // -16
        rs1_data_in = 32'd100;
        rs2_data_in = 32'd100;
        program_counter_in = 32'h0004_00BC;
        @(posedge clk); #1;
        log_state("Test 49: BEQ backwards (-16)");
        if (!compare_outputs("BEQ_BACKWARD")) fail_test("Test 49 failed.");

        // =====================================================
        // Test 50: JALR LSB clearing (ensure bit 0 is cleared)
        // =====================================================
        instruction_in = make_instr(op::JALR, .rd(5'd1), .rs1(5'd2), .imm(32'd1));
        rs1_data_in = 32'h0004_0100;
        program_counter_in = 32'h0004_00C0;
        @(posedge clk); #1;
        log_state("Test 50: JALR LSB clearing");
        if (!compare_outputs("JALR_LSB")) fail_test("Test 50 failed.");

        repeat(2) begin
            @(posedge clk);
            #1;
        end

        $display("\n=== All tests passed ===\n");
        $finish;
    end

    function automatic int compare_outputs(string test_name);
        int pass = 1;

        if (source_data_reg_out !== source_data_reg_out_ref) begin
            $display("  [FAIL] source_data_reg_out: DUT=%h REF=%h", source_data_reg_out, source_data_reg_out_ref);
            pass = 0;
        end
        if (rd_data_reg_out !== rd_data_reg_out_ref) begin
            $display("  [FAIL] rd_data_reg_out: DUT=%h REF=%h", rd_data_reg_out, rd_data_reg_out_ref);
            pass = 0;
        end
        if (instruction_reg_out !== instruction_reg_out_ref) begin
            $display("  [FAIL] instruction_reg_out: DUT=%p REF=%p", instruction_reg_out, instruction_reg_out_ref);
            pass = 0;
        end
        if (program_counter_reg_out !== program_counter_reg_out_ref) begin
            $display("  [FAIL] program_counter_reg_out: DUT=%h REF=%h", program_counter_reg_out, program_counter_reg_out_ref);
            pass = 0;
        end
        if (next_program_counter_reg_out !== next_program_counter_reg_out_ref) begin
            $display("  [FAIL] next_program_counter_reg_out: DUT=%h REF=%h", next_program_counter_reg_out, next_program_counter_reg_out_ref);
            pass = 0;
        end
        if (forwarding_out !== forwarding_out_ref) begin
            $display("  [FAIL] forwarding_out: DUT={valid=%0d, data=%h, addr=%0d} REF={valid=%0d, data=%h, addr=%0d}",
                     forwarding_out.data_valid, forwarding_out.data, forwarding_out.address,
                     forwarding_out_ref.data_valid, forwarding_out_ref.data, forwarding_out_ref.address);
            pass = 0;
        end
        if (status_forwards_out !== status_forwards_out_ref) begin
            $display("  [FAIL] status_forwards_out: DUT=%0d REF=%0d", status_forwards_out, status_forwards_out_ref);
            pass = 0;
        end
        if (status_backwards_out !== status_backwards_out_ref) begin
            $display("  [FAIL] status_backwards_out: DUT=%0d REF=%0d", status_backwards_out, status_backwards_out_ref);
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
        repeat(2) begin
            @(posedge clk);
            #1;
        end
        $fatal(1, msg);
    endtask

endmodule
