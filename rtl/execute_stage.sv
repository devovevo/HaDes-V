/* File: add.sv */
module add (
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic        is_sub_i,
    output logic [31:0] sum_o,
    output logic        carry_o,
    output logic        overflow_o,
    output logic        zero_o
);
    logic [31:0] b_mod;
    logic [32:0] sum_ext;

    assign b_mod      = is_sub_i ? ~b_i : b_i;
    // Adder with Carry-In (is_sub_i acts as +1 for 2's complement subtraction)
    assign sum_ext    = {1'b0, a_i} + {1'b0, b_mod} + {32'b0, is_sub_i};
    assign sum_o      = sum_ext[31:0];

    assign zero_o     = (sum_o == 32'b0);
    assign carry_o    = sum_ext[32];
    // Overflow = (Operands have same sign) AND (Result has different sign)
    assign overflow_o = (~(a_i[31] ^ b_mod[31]) & (a_i[31] ^ sum_ext[31]));

endmodule


/* File: shift.sv */
module shift (
    input  logic [31:0] a_i,
    input  logic [4:0]  shamt_i,
    input  logic        right_i,
    input  logic        arith_i,
    output logic [31:0] shft_o
);
    always_comb begin
        if (right_i) begin
            if (arith_i) 
                shft_o = $signed(a_i) >>> shamt_i;
            else 
                shft_o = a_i >> shamt_i;
        end else begin
            shft_o = a_i << shamt_i;
        end
    end
endmodule

/* File: branch_unit.sv */
module branch_unit (
    input  instruction::t instruction_i,
    input  logic [31:0]   pc_i,
    input  logic [31:0]   alu_result_i,   // From main ALU (rs1-rs2 for branches, rs1+imm for JALR)
    input  logic          alu_carry_i,    // Carry out from ALU subtraction
    input  logic          alu_overflow_i, // Overflow from ALU subtraction  
    input  logic          alu_zero_i,     // Zero flag from ALU
    
    output logic          branch_taken_o,
    output logic [31:0]   target_address_o,
    output logic          misaligned_o    // Target address is not 4-byte aligned
);

    // --- 1. Condition Logic (Should we branch?) ---
    // Derive all comparison results from ALU subtraction (rs1 - rs2)
    // When ALU computes rs1 - rs2:
    //   EQ:  zero
    //   NE:  !zero  
    //   LT:  sign XOR overflow (signed)
    //   GE:  !(sign XOR overflow) (signed)
    //   LTU: !carry (unsigned, borrow = no carry)
    //   GEU: carry (unsigned)
    logic beq, bne, blt, bge, bltu, bgeu;
    logic sign;
    
    assign sign = alu_result_i[31];
    assign beq  = alu_zero_i;
    assign bne  = ~alu_zero_i;
    assign blt  = sign ^ alu_overflow_i;
    assign bge  = ~(sign ^ alu_overflow_i);
    assign bltu = ~alu_carry_i;
    assign bgeu = alu_carry_i;

    always_comb begin
        case (instruction_i.op)
            op::JAL, op::JALR: branch_taken_o = 1'b1;
            op::BEQ:           branch_taken_o = beq;
            op::BNE:           branch_taken_o = bne;
            op::BLT:           branch_taken_o = blt;
            op::BGE:           branch_taken_o = bge;
            op::BLTU:          branch_taken_o = bltu;
            op::BGEU:          branch_taken_o = bgeu;
            default:           branch_taken_o = 1'b0;
        endcase
    end

    // --- 2. Target Calculation (Where do we go?) ---
    // Dedicated adder to calculate PC + Imm in parallel with Main ALU.
    // This allows us to output the target address even if the Main ALU is doing something else.
    logic [31:0] pc_plus_imm;
    assign pc_plus_imm = pc_i + instruction_i.immediate;

    always_comb begin
        if (instruction_i.op == op::JALR) begin
            // JALR target is RS1 + Imm (calculated by Main ALU)
            // Do NOT clear LSB here - detect misalignment instead
            target_address_o = alu_result_i;
        end else begin
            // For JAL, BRANCH, and AUIPC.
            // Also leaks "PC + Imm" for other instructions to match reference behavior.
            target_address_o = pc_plus_imm;
        end
    end

    // Misalignment detection: target must be 4-byte aligned when branch is taken
    assign misaligned_o = branch_taken_o && (target_address_o[1:0] != 2'b00);

endmodule

/* File: execute_stage.sv */
module execute_stage (
    input logic clk,
    input logic rst,

    // Inputs
    input logic [31:0]   rs1_data_inn,
    input logic [31:0]   rs2_data_inn,
    input instruction::t instruction_in,
    input logic [31:0]   program_counter_in,

    // Outputs
    output logic [31:0]   source_data_reg_out,
    output logic [31:0]   rd_data_reg_out,
    output instruction::t instruction_reg_out,
    output logic [31:0]   program_counter_reg_out,
    output logic [31:0]   next_program_counter_reg_out,
    output forwarding::t  forwarding_out,

    // Pipeline control
    input  pipeline_status::forwards_t  status_forwards_in,
    output pipeline_status::forwards_t  status_forwards_out,
    input  pipeline_status::backwards_t status_backwards_in,
    output pipeline_status::backwards_t status_backwards_out,
    input  logic [31:0] jump_address_backwards_in, 
    output logic [31:0] jump_address_backwards_out
);

    // --- Internal Signals ---
    logic [31:0] a_op, b_op;
    logic [31:0] add_result, shift_result, logic_result;
    logic [31:0] rd_data;    
    logic [31:0] source_data;
    logic        rd_valid;
    
    // --- 1. Operand Muxing (Updated for JALR) ---
    always_comb begin : operand_mux
        // Default A: rs1
        a_op = rs1_data_inn; 
        case (instruction_in.op)
            op::AUIPC: a_op = program_counter_in;
            op::JAL:   a_op = program_counter_in;
            default:   a_op = rs1_data_inn;
        endcase

        // Default B: rs2
        // Note: Branches use rs2 for comparison (rs1 - rs2), target address computed in branch_unit
        case (instruction_in.op)
            // Immediates (AUIPC immediate is already shifted by decoder)
            op::ADDI, op::SLTI, op::SLTIU, op::XORI, op::ORI, op::ANDI,
            op::SLLI, op::SRLI, op::SRAI,
            op::LB, op::LH, op::LW, op::LBU, op::LHU, op::SB, op::SH, op::SW,
            op::JALR, op::JAL, op::AUIPC: begin
                b_op = instruction_in.immediate;
            end
            // Branches and R-type use rs2
            default:   b_op = rs2_data_inn; 
        endcase
    end

    // --- 2. ALU Instantiations ---
    // Enable subtraction for SUB, SLT/SLTU comparisons, and branch comparisons
    logic is_sub;
    assign is_sub = (instruction_in.op == op::SUB) || 
                    (instruction_in.op == op::SLT) || (instruction_in.op == op::SLTI) ||
                    (instruction_in.op == op::SLTU) || (instruction_in.op == op::SLTIU) ||
                    (instruction_in.op == op::BEQ) || (instruction_in.op == op::BNE) ||
                    (instruction_in.op == op::BLT) || (instruction_in.op == op::BGE) ||
                    (instruction_in.op == op::BLTU) || (instruction_in.op == op::BGEU);
    
    logic alu_carry, alu_overflow, alu_zero;
    add alu_add (
        .a_i      (a_op),
        .b_i      (b_op),
        .is_sub_i (is_sub),
        .sum_o    (add_result),
        .carry_o  (alu_carry), 
        .overflow_o (alu_overflow), 
        .zero_o   (alu_zero) 
    );

    shift alu_shift (
        .a_i      (a_op),
        .shamt_i  (b_op[4:0]),
        .right_i  (instruction_in.op == op::SRL || instruction_in.op == op::SRA || 
                   instruction_in.op == op::SRLI || instruction_in.op == op::SRAI),
        .arith_i  (instruction_in.op == op::SRA || instruction_in.op == op::SRAI),
        .shft_o   (shift_result)
    );

    assign logic_result = (instruction_in.op == op::AND || instruction_in.op == op::ANDI) ? (a_op & b_op) :
                          (instruction_in.op == op::OR  || instruction_in.op == op::ORI)  ? (a_op | b_op) :
                          (a_op ^ b_op); 

    // --- 3. Branch Unit Instantiation (THIS REPLACES YOUR MANUAL LOGIC) ---
    logic branch_taken;
    logic [31:0] branch_target;

    logic jump_misaligned;
    branch_unit branch_logic (
        .instruction_i    (instruction_in),
        .pc_i             (program_counter_in),
        .alu_result_i     (add_result),
        .alu_carry_i      (alu_carry),
        .alu_overflow_i   (alu_overflow),
        .alu_zero_i       (alu_zero),
        .branch_taken_o   (branch_taken),
        .target_address_o (branch_target),
        .misaligned_o     (jump_misaligned)
    );

    // Jump address: pass through from downstream if JUMP, else use our computed target
    // When status_backwards_in is JUMP, pass through jump_address_backwards_in
    // When we generate our own JUMP (branch_taken), use branch_target
    assign jump_address_backwards_out = (status_backwards_in == pipeline_status::JUMP) ? jump_address_backwards_in : branch_target;

    // --- 4. Result Muxing ---
    // SLT comparison results using ALU subtraction outputs
    // SLTU: a < b (unsigned) is true when subtraction has NO carry (borrow occurred)
    logic sltu_result;
    assign sltu_result = ~alu_carry;
    // SLT: a < b (signed) is true when sign bit of result differs from expected
    // Result is negative XOR overflow occurred
    logic slt_result;
    assign slt_result = add_result[31] ^ alu_overflow;

    always_comb begin : result_mux
        rd_valid = 1'b1;
        case (instruction_in.op)
            op::LUI: rd_data = instruction_in.immediate;
            op::JAL, op::JALR: rd_data = program_counter_in + 4; 
            // Load instructions: rd_data is memory address, but can't forward (data not yet loaded)
            op::LB, op::LH, op::LW, op::LBU, op::LHU: begin
                rd_data = add_result;
                rd_valid = 1'b0;  // Can't forward - actual data comes from memory stage
            end
            op::SB, op::SH, op::SW, op::AUIPC,
            op::ADDI, op::ADD, op::SUB: rd_data = add_result;
            op::SLLI, op::SLL, op::SRLI, op::SRL, op::SRAI, op::SRA: rd_data = shift_result;
            op::ANDI, op::AND, op::ORI, op::OR, op::XORI, op::XOR: rd_data = logic_result;
            // Set less than instructions
            op::SLT, op::SLTI: rd_data = {31'b0, slt_result};
            op::SLTU, op::SLTIU: rd_data = {31'b0, sltu_result};
            // Branch instructions output 1 if taken, 0 if not
            op::BEQ, op::BNE, op::BLT, op::BGE, op::BLTU, op::BGEU: rd_data = {31'b0, branch_taken};
            default: begin
                rd_data = 32'b0;
                rd_valid = 1'b0;
            end
        endcase
    end

    // --- 5. Forwarding ---
    // Address is rd_address when status is VALID (even with misalignment), else 0 for BUBBLE
    // data_valid is only true when we have valid forwardable data (not loads, no errors)
    forwarding::t forwarding;
    assign forwarding.address = (status_forwards_in == pipeline_status::VALID) ? instruction_in.rd_address : 5'b0;
    assign forwarding.data    = rd_data;
    assign forwarding.data_valid = rd_valid && (status_forwards_in == pipeline_status::VALID) && !jump_misaligned;
    assign forwarding_out = forwarding;

    // --- 6. Source Data Mux ---
    always_comb begin : source_mux
        case (instruction_in.op)
            op::CSRRW, op::CSRRS, op::CSRRC: source_data = rs1_data_inn;
            op::CSRRWI, op::CSRRSI, op::CSRRCI: source_data = instruction_in.immediate;
            default: source_data = rs2_data_inn; 
        endcase
    end

    // --- 7. Pipeline Control ---
    // Backwards status: pass through STALL/JUMP from downstream, generate own JUMP for branches
    always_comb begin : control_backwards
        if (status_backwards_in == pipeline_status::STALL) begin
            status_backwards_out = pipeline_status::STALL;
        end else if (status_backwards_in == pipeline_status::JUMP) begin
            // Pass through JUMP from downstream
            status_backwards_out = pipeline_status::JUMP;
        end else if (branch_taken && (status_forwards_in == pipeline_status::VALID)) begin
            // Generate our own JUMP for local branch
            status_backwards_out = pipeline_status::JUMP;
        end else begin
            status_backwards_out = pipeline_status::READY;
        end
    end

    // --- 8. Pipeline Registers ---
    pipeline_status::forwards_t status_forwards;
    assign status_forwards_out = status_forwards;

    logic [31:0] next_program_counter;
    assign next_program_counter = branch_taken ? branch_target : (program_counter_in + 4);

    always_ff @(posedge clk) begin
        if (rst) begin
            status_forwards          <= pipeline_status::BUBBLE;
            program_counter_reg_out  <= constants::RESET_ADDRESS;
            next_program_counter_reg_out <= constants::RESET_ADDRESS;
            instruction_reg_out      <= instruction::NOP;
            source_data_reg_out      <= 32'b0;
            rd_data_reg_out          <= 32'b0;
        end else begin
            if (status_forwards_in == pipeline_status::VALID) begin
                case (status_backwards_in)
                    pipeline_status::READY: begin
                        // Check for misaligned jump target
                        if (jump_misaligned) begin
                            status_forwards <= pipeline_status::FETCH_MISALIGNED;
                        end else begin
                            status_forwards <= pipeline_status::VALID;
                        end
                        program_counter_reg_out  <= program_counter_in;
                        
                        // FIX: Use branch_target for taken branches, else PC+4
                        next_program_counter_reg_out <= next_program_counter;
                        
                        instruction_reg_out      <= instruction_in;
                        source_data_reg_out      <= source_data;
                        rd_data_reg_out          <= rd_data;
                    end
                    pipeline_status::STALL: begin
                        // Hold
                    end
                    pipeline_status::JUMP: begin
                        // Squash - set BUBBLE status but still update data registers
                        status_forwards          <= pipeline_status::BUBBLE;
                        program_counter_reg_out  <= program_counter_in;
                        next_program_counter_reg_out <= next_program_counter;
                        instruction_reg_out      <= instruction_in;
                        source_data_reg_out      <= source_data;
                        rd_data_reg_out          <= rd_data;
                    end
                    default: status_forwards <= pipeline_status::BUBBLE;
                endcase
            end else begin
                // BUBBLE or other non-VALID status: still update all registers
                status_forwards <= status_forwards_in;
                program_counter_reg_out  <= program_counter_in;
                next_program_counter_reg_out <= next_program_counter;
                instruction_reg_out      <= instruction_in;
                source_data_reg_out      <= source_data;
                rd_data_reg_out          <= rd_data;
            end
        end
    end

endmodule
