module test_instruction_decoder;
    // Inputs
    logic [31:0] instruction_in;

    // DUT outputs
    instruction::t instruction_out_dut;
    
    // REF outputs
    instruction::t instruction_out_ref;

    // DUT instance
    instruction_decoder dut (
        .instruction_in(instruction_in),
        .instruction_out(instruction_out_dut)
    );

    // REF instance
    ref_instruction_decoder golden (  
        .instruction_in(instruction_in),
        .instruction_out(instruction_out_ref)
    );

    // Test procedure
    initial begin
        $dumpfile("test_instruction_decoder.fst");
        $dumpvars;

        // ========================================
        // U-type instructions
        // ========================================
        
        // LUI x1, 0x12345
        instruction_in = 32'h12345_0B7; // LUI rd=1, imm=0x12345000
        #10;
        compare_outputs("LUI");

        // AUIPC x5, 0x00001
        instruction_in = 32'h00001_297; // AUIPC rd=5, imm=0x00001000
        #10;
        compare_outputs("AUIPC");

        // ========================================
        // J-type instruction
        // ========================================
        
        // JAL x1, offset
        instruction_in = 32'h008000EF; // JAL rd=1
        #10;
        compare_outputs("JAL");

        // ========================================
        // I-type jump instruction
        // ========================================
        
        // JALR x1, x2, 0
        instruction_in = 32'h000100E7; // JALR rd=1, rs1=2, imm=0
        #10;
        compare_outputs("JALR");

        // ========================================
        // B-type (Branch) instructions
        // ========================================
        
        // BEQ x1, x2, offset
        instruction_in = 32'h00208063; // BEQ rs1=1, rs2=2
        #10;
        compare_outputs("BEQ");

        // BNE x1, x2, offset
        instruction_in = 32'h00209063; // BNE rs1=1, rs2=2
        #10;
        compare_outputs("BNE");

        // BLT x1, x2, offset
        instruction_in = 32'h0020C063; // BLT rs1=1, rs2=2
        #10;
        compare_outputs("BLT");

        // BGE x1, x2, offset
        instruction_in = 32'h0020D063; // BGE rs1=1, rs2=2
        #10;
        compare_outputs("BGE");

        // BLTU x1, x2, offset
        instruction_in = 32'h0020E063; // BLTU rs1=1, rs2=2
        #10;
        compare_outputs("BLTU");

        // BGEU x1, x2, offset
        instruction_in = 32'h0020F063; // BGEU rs1=1, rs2=2
        #10;
        compare_outputs("BGEU");

        // ========================================
        // Load instructions
        // ========================================
        
        // LB x1, 0(x2)
        instruction_in = 32'h00010083; // LB rd=1, rs1=2, imm=0
        #10;
        compare_outputs("LB");

        // LH x1, 0(x2)
        instruction_in = 32'h00011083; // LH rd=1, rs1=2, imm=0
        #10;
        compare_outputs("LH");

        // LW x1, 4(x2)
        instruction_in = 32'h00412083; // LW rd=1, rs1=2, imm=4
        #10;
        compare_outputs("LW");

        // LBU x1, 0(x2)
        instruction_in = 32'h00014083; // LBU rd=1, rs1=2, imm=0
        #10;
        compare_outputs("LBU");

        // LHU x1, 0(x2)
        instruction_in = 32'h00015083; // LHU rd=1, rs1=2, imm=0
        #10;
        compare_outputs("LHU");

        // ========================================
        // Store instructions
        // ========================================
        
        // SB x1, 0(x2)
        instruction_in = 32'h00110023; // SB rs1=2, rs2=1, imm=0
        #10;
        compare_outputs("SB");

        // SH x1, 0(x2)
        instruction_in = 32'h00111023; // SH rs1=2, rs2=1, imm=0
        #10;
        compare_outputs("SH");

        // SW x1, 4(x2)
        instruction_in = 32'h00112223; // SW rs1=2, rs2=1, imm=4
        #10;
        compare_outputs("SW");

        // ========================================
        // I-type ALU instructions
        // ========================================
        
        // ADDI x1, x2, 100
        instruction_in = 32'h06410093; // ADDI rd=1, rs1=2, imm=100
        #10;
        compare_outputs("ADDI");

        // NOP (ADDI x0, x0, 0)
        instruction_in = 32'h00000013;
        #10;
        compare_outputs("NOP/ADDI");

        // SLTI x1, x2, 10
        instruction_in = 32'h00A12093; // SLTI rd=1, rs1=2, imm=10
        #10;
        compare_outputs("SLTI");

        // SLTIU x1, x2, 10
        instruction_in = 32'h00A13093; // SLTIU rd=1, rs1=2, imm=10
        #10;
        compare_outputs("SLTIU");

        // XORI x1, x2, 0xFF
        instruction_in = 32'h0FF14093; // XORI rd=1, rs1=2, imm=255
        #10;
        compare_outputs("XORI");

        // ORI x1, x2, 0xFF
        instruction_in = 32'h0FF16093; // ORI rd=1, rs1=2, imm=255
        #10;
        compare_outputs("ORI");

        // ANDI x1, x2, 0xFF
        instruction_in = 32'h0FF17093; // ANDI rd=1, rs1=2, imm=255
        #10;
        compare_outputs("ANDI");

        // SLLI x1, x2, 5
        instruction_in = 32'h00511093; // SLLI rd=1, rs1=2, shamt=5
        #10;
        compare_outputs("SLLI");

        // SRLI x1, x2, 5
        instruction_in = 32'h00515093; // SRLI rd=1, rs1=2, shamt=5
        #10;
        compare_outputs("SRLI");

        // SRAI x1, x2, 5
        instruction_in = 32'h40515093; // SRAI rd=1, rs1=2, shamt=5
        #10;
        compare_outputs("SRAI");

        // ========================================
        // R-type ALU instructions
        // ========================================
        
        // ADD x1, x2, x3
        instruction_in = 32'h003100B3; // ADD rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("ADD");

        // SUB x1, x2, x3
        instruction_in = 32'h403100B3; // SUB rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("SUB");

        // SLL x1, x2, x3
        instruction_in = 32'h003110B3; // SLL rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("SLL");

        // SLT x1, x2, x3
        instruction_in = 32'h003120B3; // SLT rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("SLT");

        // SLTU x1, x2, x3
        instruction_in = 32'h003130B3; // SLTU rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("SLTU");

        // XOR x1, x2, x3
        instruction_in = 32'h003140B3; // XOR rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("XOR");

        // SRL x1, x2, x3
        instruction_in = 32'h003150B3; // SRL rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("SRL");

        // SRA x1, x2, x3
        instruction_in = 32'h403150B3; // SRA rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("SRA");

        // OR x1, x2, x3
        instruction_in = 32'h003160B3; // OR rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("OR");

        // AND x1, x2, x3
        instruction_in = 32'h003170B3; // AND rd=1, rs1=2, rs2=3
        #10;
        compare_outputs("AND");

        // ========================================
        // FENCE instructions
        // ========================================
        
        // FENCE
        instruction_in = 32'h0FF0000F; // FENCE
        #10;
        compare_outputs("FENCE");

        // FENCE.I
        instruction_in = 32'h0000100F; // FENCE.I
        #10;
        compare_outputs("FENCE.I");

        // ========================================
        // System instructions
        // ========================================
        
        // ECALL
        instruction_in = 32'h00000073; // ECALL
        #10;
        compare_outputs("ECALL");

        // EBREAK
        instruction_in = 32'h00100073; // EBREAK
        #10;
        compare_outputs("EBREAK");

        // MRET
        instruction_in = 32'h30200073; // MRET
        #10;
        compare_outputs("MRET");

        // WFI
        instruction_in = 32'h10500073; // WFI
        #10;
        compare_outputs("WFI");

        // ========================================
        // CSR instructions
        // ========================================
        
        // CSRRW x1, mstatus, x2
        instruction_in = 32'h300110F3; // CSRRW rd=1, rs1=2, csr=0x300
        #10;
        compare_outputs("CSRRW");

        // CSRRS x1, mstatus, x2
        instruction_in = 32'h300120F3; // CSRRS rd=1, rs1=2, csr=0x300
        #10;
        compare_outputs("CSRRS");

        // CSRRC x1, mstatus, x2
        instruction_in = 32'h300130F3; // CSRRC rd=1, rs1=2, csr=0x300
        #10;
        compare_outputs("CSRRC");

        // CSRRWI x1, mstatus, 5
        instruction_in = 32'h3002D0F3; // CSRRWI rd=1, uimm=5, csr=0x300
        #10;
        compare_outputs("CSRRWI");

        // CSRRSI x1, mstatus, 5
        instruction_in = 32'h3002E0F3; // CSRRSI rd=1, uimm=5, csr=0x300
        #10;
        compare_outputs("CSRRSI");

        // CSRRCI x1, mstatus, 5
        instruction_in = 32'h3002F0F3; // CSRRCI rd=1, uimm=5, csr=0x300
        #10;
        compare_outputs("CSRRCI");

        // ========================================
        // ILLEGAL instructions
        // ========================================
        
        // Invalid opcode (all 1s)
        instruction_in = 32'hFFFFFFFF;
        #10;
        compare_outputs("ILLEGAL - all 1s");

        // Invalid opcode (all 0s except opcode bits = 0b1111111)
        instruction_in = 32'h0000007F;
        #10;
        compare_outputs("ILLEGAL - opcode 0x7F");

        // Invalid opcode (0b0000001)
        instruction_in = 32'h00000001;
        #10;
        compare_outputs("ILLEGAL - opcode 0x01");

        // Invalid funct3 for branch (3'b010)
        instruction_in = 32'h0020A063; // Branch with funct3=010
        #10;
        compare_outputs("ILLEGAL - bad branch funct3");

        // Invalid funct3 for load (3'b011)
        instruction_in = 32'h00013083; // Load with funct3=011
        #10;
        compare_outputs("ILLEGAL - bad load funct3");

        // Invalid funct3 for store (3'b011)
        instruction_in = 32'h00113023; // Store with funct3=011
        #10;
        compare_outputs("ILLEGAL - bad store funct3");

        // Invalid funct7 for R-type ADD (should be 0000000)
        instruction_in = 32'h013100B3; // R-type with funct7=0000001
        #10;
        compare_outputs("ILLEGAL - bad R-type funct7");

        // Invalid funct7 for SLLI (should be 0000000)
        instruction_in = 32'h40511093; // SLLI with funct7=0100000
        #10;
        compare_outputs("ILLEGAL - bad SLLI funct7");

        // Invalid system instruction (funct3=000 but not ECALL/EBREAK/MRET/WFI)
        instruction_in = 32'h00200073; // funct3=000, imm12=0x002
        #10;
        compare_outputs("ILLEGAL - bad system imm12");

        // Invalid funct3 for JALR (should be 000)
        instruction_in = 32'h000110E7; // JALR with funct3=001
        #10;
        compare_outputs("ILLEGAL - bad JALR funct3");

        $display("All tests completed!");
        $finish;
    end

    function void compare_outputs(string test_name);
        logic pass;
        pass = 1;

        if (instruction_out_dut.op !== instruction_out_ref.op) begin
            $error("[%s] Mismatch in op: DUT=%0d, REF=%0d", test_name, instruction_out_dut.op, instruction_out_ref.op);
            pass = 0;
        end

        if (instruction_out_dut.rd_address !== instruction_out_ref.rd_address) begin
            $error("[%s] Mismatch in rd: DUT=%0d, REF=%0d", test_name, instruction_out_dut.rd_address, instruction_out_ref.rd_address);
            pass = 0;
        end

        if (instruction_out_dut.rs1_address !== instruction_out_ref.rs1_address) begin
            $error("[%s] Mismatch in rs1: DUT=%0d, REF=%0d", test_name, instruction_out_dut.rs1_address, instruction_out_ref.rs1_address);
            pass = 0;
        end

        if (instruction_out_dut.rs2_address !== instruction_out_ref.rs2_address) begin
            $error("[%s] Mismatch in rs2: DUT=%0d, REF=%0d", test_name, instruction_out_dut.rs2_address, instruction_out_ref.rs2_address);
            pass = 0;
        end

        if (instruction_out_dut.csr !== instruction_out_ref.csr) begin
            $error("[%s] Mismatch in csr: DUT=%0d, REF=%0d", test_name, instruction_out_dut.csr, instruction_out_ref.csr);
            pass = 0;
        end

        if (instruction_out_dut.immediate !== instruction_out_ref.immediate) begin
            $error("[%s] Mismatch in immediate: DUT=0x%08h, REF=0x%08h", test_name, instruction_out_dut.immediate, instruction_out_ref.immediate);
            pass = 0;
        end

        if (pass) begin
            $display("[%s] PASS", test_name);
        end
    endfunction

endmodule
