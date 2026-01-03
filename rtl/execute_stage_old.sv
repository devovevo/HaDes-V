/* Copyright (c) 2024 Tobias Scheipel, David Beikircher, Florian Riedl
 * Embedded Architectures & Systems Group, Graz University of Technology
 * SPDX-License-Identifier: MIT
 * ---------------------------------------------------------------------
 * File: execute_stage.sv
 */

module add(
    input logic [31:0]  a_in,
    input logic [31:0]  b_in,
    input logic         neg_b_in,
    output logic [31:0] sum_out,
    output logic        carry_out,
    output logic        overflow_out,
    output logic        zero_out
);
    logic [31:0] b_mod;
    logic [32:0] sum_ext;

    assign b_mod = neg_b_in ? ~b_in : b_in;
    assign sum_ext = {1'b0, a_in} + {1'b0, b_mod} + {31'b0, neg_b_in};
    assign sum_out = sum_ext[31:0];

    assign zero_out = (sum_out == 32'b0);
    assign carry_out = sum_ext[32];
    assign overflow_out = (~(a_in[31] ^ b_mod[31]) & (a_in[31] ^ sum_ext[31]));
endmodule

module shift(
    input logic [31:0] a_in,
    input logic [4:0]  shamt_i,
    input logic        right_i,
    input logic        arith_i,
    output logic [31:0] shft_o
);
    always_comb begin
        if (right_i) begin
            if (arith_i) begin
                shft_o = $signed(a_in) >>> shamt_i;
            end else begin
                shft_o = a_in >> shamt_i;
            end
        end else begin
            shft_o = a_in << shamt_i;
        end
    end
endmodule

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
    logic [31:0] source_data_reg;
    logic [31:0] rd_data_reg;
    instruction::t instruction_reg;
    logic [31:0] program_counter_reg;
    logic [31:0] next_program_counter_reg;

    assign source_data_reg_out = source_data_reg;
    assign rd_data_reg_out = rd_data_reg;
    assign instruction_reg_out = instruction_reg;
    assign program_counter_reg_out = program_counter_reg;
    assign next_program_counter_reg_out = next_program_counter_reg;

    logic [31:0] a_op;
    always_comb begin
        case (instruction_in.op)
            op::JAL,
            op::JALR,
            op::BEQ,
            op::BNE,
            op::BLT,
            op::BGE,
            op::BLTU,
            op::BGEU,
            op::AUIPC: begin
                a_op = program_counter_in;
            end
            op::LB,
            op::LH,
            op::LW,
            op::LBU,
            op::LHU,
            op::SB,
            op::SH,
            op::SW,
            op::ADDI,
            op::SLTI,
            op::SLTIU,
            op::XORI,
            op::ORI,
            op::ANDI,
            op::SLLI,
            op::SRLI,
            op::SRAI,
            op::ADD,
            op::SUB,
            op::SLL,
            op::SLT,
            op::SLTU,
            op::XOR,
            op::SRL,
            op::SRA,
            op::OR,
            op::AND: begin
                a_op = rs1_data_inn;
            end
            default: begin
                a_op = 32'b0;
            end
        endcase
    end

    logic [31:0] b_op;
    always_comb begin
        case (instruction_in.op)
            op::LB,
            op::LH,
            op::LW,
            op::LBU,
            op::LHU,
            op::SB,
            op::SH,
            op::SW,
            op::ADDI,
            op::SLTI,
            op::SLTIU,
            op::XORI,
            op::ORI,
            op::ANDI,
            op::JAL,
            op::JALR,
            op::SLLI,
            op::SRLI,
            op::SRAI,
            op::BEQ,
            op::BNE,
            op::BLT,
            op::BGE,
            op::BLTU,
            op::BGEU: begin
                b_op = instruction_in.immediate;
            end
            op::ADD,
            op::SUB,
            op::SLL,
            op::SLT,
            op::SLTU,
            op::XOR,
            op::SRL,
            op::SRA,
            op::OR,
            op::AND: begin
                b_op = rs2_data_inn;
            end
            op::AUIPC: begin
                b_op = {instruction_in.immediate[19:0], 12'b0};
            end
            default: begin
                b_op = 32'b0;
            end
        endcase
    end

    logic [31:0] add_result;
    logic        add_carry;
    logic        add_overflow;
    logic        add_zero;
    add alu_add(
        .a_in(a_op),
        .b_in(b_op),
        .neg_b_in(instruction_in.op == op::SUB),
        .sum_out(add_result),
        .carry_out(add_carry),
        .overflow_out(add_overflow),
        .zero_out(add_zero)
    );

    logic [31:0] shift_result;
    logic        shift_right = (instruction_in.op == op::SRL) || (instruction_in.op == op::SRA) || (instruction_in.op == op::SRLI) || (instruction_in.op == op::SRAI);
    logic        shift_arith = (instruction_in.op == op::SRA) || (instruction_in.op == op::SRAI);
    shift alu_shift(
        .a_in(a_op),
        .shamt_i(b_op[4:0]),
        .right_i(shift_right),
        .arith_i(shift_arith),
        .shft_o(shift_result)
    );

    logic [31:0] and_result = a_op & b_op;
    logic [31:0] or_result  = a_op | b_op;
    logic [31:0] xor_result = a_op ^ b_op;
    
    logic beq = (rs1_data_inn == rs2_data_inn);
    logic bne = (rs1_data_inn != rs2_data_inn);
    logic blt = ($signed(rs1_data_inn) < $signed(rs2_data_inn));
    logic bge = ($signed(rs1_data_inn) >= $signed(rs2_data_inn));
    logic bltu = (rs1_data_inn < rs2_data_inn);
    logic bgeu = (rs1_data_inn >= rs2_data_inn);

    // Determine next PC
    logic branch_taken;
    always_comb begin
        case (instruction_in.op)
            op::JAL,
            op::JALR: begin
                branch_taken = 1'b1;
            end
            op::BEQ: begin
                branch_taken = beq;
            end
            op::BNE: begin
                branch_taken = bne;
            end
            op::BLT: begin
                branch_taken = blt;
            end
            op::BGE: begin
                branch_taken = bge;
            end
            op::BLTU: begin
                branch_taken = bltu;
            end
            op::BGEU: begin
                branch_taken = bgeu;
            end
            default: begin
                branch_taken = 1'b0;
            end
        endcase
    end

    logic [31:0] next_pc_default = program_counter_in + 32'd4;
    logic [31:0] next_pc;
    always_comb begin
        if (branch_taken) begin
            if (instruction_in.op == op::JALR) begin
                next_pc = {add_result[31:1], 1'b0}; // Ensure LSB is zero
            end else begin
                next_pc = add_result;
            end
        end else begin
            next_pc = next_pc_default;
        end
    end

    // jump_address_backwards_out is the current registered PC (only meaningful when JUMP status)
    // TODO: Probably should be something else
    assign jump_address_backwards_out = next_pc;

    // Determine rd data
    logic [31:0] rd_data;
    logic        valid = 1'b1;
    always_comb begin
        case (instruction_in.op)
            op::LUI: begin
                rd_data = instruction_in.immediate;
            end
            op::SW,
            op::SH,
            op::SB,
            op::LW,
            op::LH,
            op::LB,
            op::LHU,
            op::LBU,
            op::AUIPC,
            op::ADDI,
            op::ADD,
            op::SUB: begin
                rd_data = add_result;
            end
            op::SLLI,
            op::SLL,
            op::SRLI,
            op::SRAI,
            op::SRL,
            op::SRA: begin
                rd_data = shift_result;
            end
            op::ANDI,
            op::AND: begin
                rd_data = and_result;
            end
            op::ORI,
            op::OR: begin
                rd_data = or_result;
            end
            op::XORI,
            op::XOR: begin
                rd_data = xor_result;
            end
            op::JAL,
            op::JALR: begin
                rd_data = next_pc_default;
            end
            default: begin
                rd_data = 32'b0;
                valid = 1'b0;
            end
        endcase
    end

    // Determine source data
    // Default is rs2_data (used for stores), CSR ops use rs1 or immediate
    logic [31:0] source_data;
    always_comb begin
        case (instruction_in.op)
            op::CSRRW,
            op::CSRRS,
            op::CSRRC: begin
                source_data = rs1_data_inn;
            end
            op::CSRRWI,
            op::CSRRSI,
            op::CSRRCI: begin
                source_data = instruction_in.immediate;
            end
            default: begin
                // Default to rs2_data for stores and all other instructions
                source_data = rs2_data_inn;
            end
        endcase
    end

    // Forwarding output - based on registered (output) instruction, not input
    // data_valid is true only when status_forwards is VALID
    forwarding::t forwarding = '{
        address: instruction_reg.rd_address, 
        data: rd_data_reg, 
        data_valid: (status_forwards == pipeline_status::VALID)
    };
    assign forwarding_out = forwarding;

    // Forward pipeline control signals
    pipeline_status::forwards_t status_forwards;
    assign status_forwards_out = status_forwards;

    // Backward pipeline status
    pipeline_status::backwards_t status_backwards;
    always_comb begin
        if (status_backwards_in == pipeline_status::STALL) begin
            status_backwards = pipeline_status::STALL;
        end else if (branch_taken) begin
            status_backwards = pipeline_status::JUMP;
        end else begin
            status_backwards = pipeline_status::READY;
        end
    end
    assign status_backwards_out = status_backwards;

    // Pipeline registers
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset stuff TODO
            program_counter_reg <= constants::RESET_ADDRESS;
            next_program_counter_reg <= constants::RESET_ADDRESS;

            instruction_reg <= instruction::NOP;
            source_data_reg <= 32'b0;
            rd_data_reg <= 32'b0;

            status_forwards <= pipeline_status::BUBBLE;
        end else begin
            if (status_forwards_in == pipeline_status::VALID) begin
                // TODO
                case (status_backwards_in)
                    pipeline_status::READY: begin
                        // Update registers
                        program_counter_reg <= program_counter_in;
                        next_program_counter_reg <= next_pc;

                        instruction_reg <= instruction_in;
                        source_data_reg <= source_data;
                        rd_data_reg <= rd_data;

                        // Update status
                        status_forwards <= pipeline_status::VALID;
                    end
                    pipeline_status::STALL: begin
                        // Hold / bubble
                        // Do nothing
                    end
                    pipeline_status::JUMP: begin
                        // Squash - insert bubble
                        // Still update with actual data (ignored due to BUBBLE status)
                        program_counter_reg <= program_counter_in;
                        next_program_counter_reg <= next_pc;

                        instruction_reg <= instruction_in;
                        source_data_reg <= source_data;
                        rd_data_reg <= rd_data;

                        status_forwards <= pipeline_status::BUBBLE;
                    end
                endcase
            end else begin
                // Hold / bubble
                status_forwards <= status_forwards_in;
                instruction_reg <= instruction_in;
                program_counter_reg <= program_counter_in;
            end
        end
    end
    
endmodule
