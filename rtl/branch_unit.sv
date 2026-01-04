
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
