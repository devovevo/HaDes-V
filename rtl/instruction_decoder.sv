/* Copyright (c) 2024 Tobias Scheipel, David Beikircher, Florian Riedl
 * Embedded Architectures & Systems Group, Graz University of Technology
 * SPDX-License-Identifier: MIT
 * ---------------------------------------------------------------------
 * File: instruction_decoder.sv
 */

module instruction_decoder (
    input  logic [31:0]   instruction_in,
    output instruction::t instruction_out
);

    // Extract fields from instruction
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    csr::t       csr_addr;

    assign opcode   = instruction_in[6:0];
    assign funct3   = instruction_in[14:12];
    assign funct7   = instruction_in[31:25];
    assign rd       = instruction_in[11:7];
    assign rs1      = instruction_in[19:15];
    assign rs2      = instruction_in[24:20];
    assign csr_addr = csr::t'(instruction_in[31:20]);

    // Immediate values for different instruction formats
    logic [31:0] imm_i;  // I-type
    logic [31:0] imm_s;  // S-type
    logic [31:0] imm_b;  // B-type
    logic [31:0] imm_u;  // U-type
    logic [31:0] imm_j;  // J-type

    // I-type immediate: imm[11:0] -> sign-extended
    assign imm_i = {{20{instruction_in[31]}}, instruction_in[31:20]};

    // S-type immediate: imm[11:5] | imm[4:0]
    assign imm_s = {{20{instruction_in[31]}}, instruction_in[31:25], instruction_in[11:7]};

    // B-type immediate: imm[12|10:5] | imm[4:1|11] (bit 0 is always 0)
    assign imm_b = {{19{instruction_in[31]}}, instruction_in[31], instruction_in[7], instruction_in[30:25], instruction_in[11:8], 1'b0};

    // U-type immediate: imm[31:12] << 12
    assign imm_u = {instruction_in[31:12], 12'b0};

    // J-type immediate: imm[20|10:1|11|19:12] (bit 0 is always 0)
    assign imm_j = {{11{instruction_in[31]}}, instruction_in[31], instruction_in[19:12], instruction_in[20], instruction_in[30:21], 1'b0};

    always_comb begin
        // Default to ILLEGAL instruction
        instruction_out.op          = op::ILLEGAL;
        instruction_out.rd_address  = rd;
        instruction_out.rs1_address = rs1;
        instruction_out.rs2_address = rs2;
        instruction_out.csr         = csr_addr;
        instruction_out.immediate   = 32'b0;

        case (opcode)
            7'b0110111: begin // LUI
                instruction_out.op          = op::LUI;
                instruction_out.immediate   = imm_u;
                instruction_out.rs1_address = 5'b0;
                instruction_out.rs2_address = 5'b0;
            end

            7'b0010111: begin // AUIPC
                instruction_out.op          = op::AUIPC;
                instruction_out.immediate   = imm_u;
                instruction_out.rs1_address = 5'b0;
                instruction_out.rs2_address = 5'b0;
            end

            7'b1101111: begin // JAL
                instruction_out.op          = op::JAL;
                instruction_out.immediate   = imm_j;
                instruction_out.rs1_address = 5'b0;
                instruction_out.rs2_address = 5'b0;
            end

            7'b1100111: begin // JALR
                instruction_out.immediate   = imm_i;
                instruction_out.rs2_address = 5'b0;
                if (funct3 == 3'b000)
                    instruction_out.op = op::JALR;
                else
                    instruction_out.op = op::ILLEGAL;
            end

            7'b1100011: begin // Branch instructions
                instruction_out.immediate  = imm_b;
                instruction_out.rd_address = 5'b0;
                case (funct3)
                    3'b000: instruction_out.op = op::BEQ;
                    3'b001: instruction_out.op = op::BNE;
                    3'b100: instruction_out.op = op::BLT;
                    3'b101: instruction_out.op = op::BGE;
                    3'b110: instruction_out.op = op::BLTU;
                    3'b111: instruction_out.op = op::BGEU;
                    default: begin
                        instruction_out.op          = op::ILLEGAL;
                        instruction_out.rs2_address = 5'b0;
                    end
                endcase
            end

            7'b0000011: begin // Load instructions
                instruction_out.immediate   = imm_i;
                instruction_out.rs2_address = 5'b0;
                case (funct3)
                    3'b000: instruction_out.op = op::LB;
                    3'b001: instruction_out.op = op::LH;
                    3'b010: instruction_out.op = op::LW;
                    3'b100: instruction_out.op = op::LBU;
                    3'b101: instruction_out.op = op::LHU;
                    default: instruction_out.op = op::ILLEGAL;
                endcase
            end

            7'b0100011: begin // Store instructions
                instruction_out.immediate  = imm_s;
                instruction_out.rd_address = 5'b0;
                case (funct3)
                    3'b000: instruction_out.op = op::SB;
                    3'b001: instruction_out.op = op::SH;
                    3'b010: instruction_out.op = op::SW;
                    default: begin
                        instruction_out.op          = op::ILLEGAL;
                        instruction_out.rs2_address = 5'b0;
                    end
                endcase
            end

            7'b0010011: begin // I-type ALU instructions
                instruction_out.rs2_address = 5'b0;
                case (funct3)
                    3'b000: begin
                        instruction_out.op        = op::ADDI;
                        instruction_out.immediate = imm_i;
                    end
                    3'b010: begin
                        instruction_out.op        = op::SLTI;
                        instruction_out.immediate = imm_i;
                    end
                    3'b011: begin
                        instruction_out.op        = op::SLTIU;
                        instruction_out.immediate = imm_i;
                    end
                    3'b100: begin
                        instruction_out.op        = op::XORI;
                        instruction_out.immediate = imm_i;
                    end
                    3'b110: begin
                        instruction_out.op        = op::ORI;
                        instruction_out.immediate = imm_i;
                    end
                    3'b111: begin
                        instruction_out.op        = op::ANDI;
                        instruction_out.immediate = imm_i;
                    end
                    3'b001: begin // SLLI
                        if (funct7 == 7'b0000000) begin
                            instruction_out.op        = op::SLLI;
                            instruction_out.immediate = {27'b0, rs2}; // shamt is in rs2 field
                        end else begin
                            instruction_out.op = op::ILLEGAL;
                            // immediate stays 0 (default)
                        end
                    end
                    3'b101: begin // SRLI/SRAI
                        if (funct7 == 7'b0000000) begin
                            instruction_out.op        = op::SRLI;
                            instruction_out.immediate = {27'b0, rs2}; // shamt is in rs2 field
                        end else if (funct7 == 7'b0100000) begin
                            instruction_out.op        = op::SRAI;
                            instruction_out.immediate = {27'b0, rs2}; // shamt is in rs2 field
                        end else begin
                            instruction_out.op = op::ILLEGAL;
                            // immediate stays 0 (default)
                        end
                    end
                    default: instruction_out.op = op::ILLEGAL;
                endcase
            end

            7'b0110011: begin // R-type ALU instructions
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: instruction_out.op = op::ADD;
                    {7'b0100000, 3'b000}: instruction_out.op = op::SUB;
                    {7'b0000000, 3'b001}: instruction_out.op = op::SLL;
                    {7'b0000000, 3'b010}: instruction_out.op = op::SLT;
                    {7'b0000000, 3'b011}: instruction_out.op = op::SLTU;
                    {7'b0000000, 3'b100}: instruction_out.op = op::XOR;
                    {7'b0000000, 3'b101}: instruction_out.op = op::SRL;
                    {7'b0100000, 3'b101}: instruction_out.op = op::SRA;
                    {7'b0000000, 3'b110}: instruction_out.op = op::OR;
                    {7'b0000000, 3'b111}: instruction_out.op = op::AND;
                    default: begin
                        instruction_out.op          = op::ILLEGAL;
                        instruction_out.rs2_address = 5'b0;
                    end
                endcase
            end

            7'b0001111: begin // FENCE instructions
                instruction_out.immediate   = imm_i;
                instruction_out.rd_address  = 5'b0;
                instruction_out.rs1_address = 5'b0;
                instruction_out.rs2_address = 5'b0;
                case (funct3)
                    3'b000: instruction_out.op = op::FENCE;
                    3'b001: instruction_out.op = op::FENCE_I;
                    default: instruction_out.op = op::ILLEGAL;
                endcase
            end

            7'b1110011: begin // System instructions
                instruction_out.rs2_address = 5'b0;
                case (funct3)
                    3'b000: begin // ECALL, EBREAK, MRET, WFI
                        instruction_out.rd_address  = 5'b0;
                        instruction_out.rs1_address = 5'b0;
                        case (instruction_in[31:20])
                            12'b000000000000: instruction_out.op = op::ECALL;
                            12'b000000000001: instruction_out.op = op::EBREAK;
                            12'b001100000010: instruction_out.op = op::MRET;
                            12'b000100000101: instruction_out.op = op::WFI;
                            default: instruction_out.op = op::ILLEGAL;
                        endcase
                    end
                    3'b001: begin // CSRRW
                        instruction_out.op = op::CSRRW;
                    end
                    3'b010: begin // CSRRS
                        instruction_out.op = op::CSRRS;
                    end
                    3'b011: begin // CSRRC
                        instruction_out.op = op::CSRRC;
                    end
                    3'b101: begin // CSRRWI
                        instruction_out.op          = op::CSRRWI;
                        instruction_out.rs1_address = 5'b0;
                        instruction_out.immediate   = {27'b0, rs1}; // uimm is in rs1 field
                    end
                    3'b110: begin // CSRRSI
                        instruction_out.op          = op::CSRRSI;
                        instruction_out.rs1_address = 5'b0;
                        instruction_out.immediate   = {27'b0, rs1}; // uimm is in rs1 field
                    end
                    3'b111: begin // CSRRCI
                        instruction_out.op          = op::CSRRCI;
                        instruction_out.rs1_address = 5'b0;
                        instruction_out.immediate   = {27'b0, rs1}; // uimm is in rs1 field
                    end
                    default: instruction_out.op = op::ILLEGAL;
                endcase
            end

            default: begin
                instruction_out.op          = op::ILLEGAL;
                instruction_out.rs2_address = 5'b0;
            end
        endcase
    end

endmodule
