/* Copyright (c) 2024 Tobias Scheipel, David Beikircher, Florian Riedl
 * Embedded Architectures & Systems Group, Graz University of Technology
 * SPDX-License-Identifier: MIT
 * ---------------------------------------------------------------------
 * File: decode_stage.sv
 */

module decode_stage (
    input logic clk,
    input logic rst,

    // Inputs
    input logic [31:0]  instruction_in,
    input logic [31:0]  program_counter_in,
    input forwarding::t exe_forwarding_in,
    input forwarding::t mem_forwarding_in,
    input forwarding::t wb_forwarding_in,

    // Output Registers
    output logic [31:0]   rs1_data_reg_out,
    output logic [31:0]   rs2_data_reg_out,
    output logic [31:0]   program_counter_reg_out,
    output instruction::t instruction_reg_out,

    // Pipeline control
    input  pipeline_status::forwards_t  status_forwards_in,
    output pipeline_status::forwards_t  status_forwards_out,
    input  pipeline_status::backwards_t status_backwards_in,
    output pipeline_status::backwards_t status_backwards_out,
    input  logic [31:0] jump_address_backwards_in,
    output logic [31:0] jump_address_backwards_out
);
    instruction::t instruction_out;

    instruction_decoder decoder (
        .instruction_in(instruction_in),
        .instruction_out(instruction_out)
    );

    logic [31:0] rs1_data_reg_file;
    logic [31:0] rs2_data_reg_file;

    register_file reg_file (
        .clk(clk),
        .rst(rst),
        // read ports
        .read_address1(instruction_out.rs1_address),
        .read_data1(rs1_data_reg_file),
        .read_address2(instruction_out.rs2_address),
        .read_data2(rs2_data_reg_file),
        // write port
        .write_address(wb_forwarding_in.address),
        .write_data(wb_forwarding_in.data),
        .write_enable(wb_forwarding_in.data_valid)
    );

    pipeline_status::forwards_t status_forwards;

    logic [31:0] rs1_data_reg;
    logic [31:0] rs2_data_reg;
    instruction::t instruction_reg;
    logic [31:0] program_counter_reg;

    // Registered outputs
    assign instruction_reg_out = instruction_reg;
    assign program_counter_reg_out = program_counter_reg;
    assign rs1_data_reg_out = rs1_data_reg;
    assign rs2_data_reg_out = rs2_data_reg;
    assign status_forwards_out = status_forwards;

    // Combinational pass-through for backwards signals
    assign jump_address_backwards_out = jump_address_backwards_in;

    // -------------------------------------------------------------------------
    // Hazard Detection Logic
    // -------------------------------------------------------------------------
    logic hazard_stall;

    always_comb begin
        hazard_stall = 1'b0;

        // Check RS1 Forwarding Hazard (GPR only)
        if (instruction_out.rs1_address != 5'b0) begin
            if (instruction_out.rs1_address == exe_forwarding_in.address && !exe_forwarding_in.data_valid) begin
                hazard_stall = 1'b1;
            end else if (instruction_out.rs1_address == mem_forwarding_in.address && !mem_forwarding_in.data_valid) begin
                hazard_stall = 1'b1;
            end
        end

        // Check RS2 Forwarding Hazard (GPR only)
        if (instruction_out.rs2_address != 5'b0) begin
            if (instruction_out.rs2_address == exe_forwarding_in.address && !exe_forwarding_in.data_valid) begin
                hazard_stall = 1'b1;
            end else if (instruction_out.rs2_address == mem_forwarding_in.address && !mem_forwarding_in.data_valid) begin
                hazard_stall = 1'b1;
            end
        end
    end
    
    assign status_backwards_out = hazard_stall ? pipeline_status::STALL : status_backwards_in;

    // -------------------------------------------------------------------------
    // Forwarding Logic (Data Path)
    // -------------------------------------------------------------------------
    logic [31:0] rs1_data_next;

    always_comb begin
        rs1_data_next = rs1_data_reg_file;
        if (instruction_out.rs1_address != 5'b0) begin
            if (instruction_out.rs1_address == exe_forwarding_in.address && exe_forwarding_in.data_valid) begin
                rs1_data_next = exe_forwarding_in.data;
            end else if (instruction_out.rs1_address == mem_forwarding_in.address && mem_forwarding_in.data_valid) begin
                rs1_data_next = mem_forwarding_in.data;
            end
        end
    end

    logic [31:0] rs2_data_next;

    always_comb begin
        rs2_data_next = rs2_data_reg_file;
        if (instruction_out.rs2_address != 5'b0) begin
            if (instruction_out.rs2_address == exe_forwarding_in.address && exe_forwarding_in.data_valid) begin
                rs2_data_next = exe_forwarding_in.data;
            end else if (instruction_out.rs2_address == mem_forwarding_in.address && mem_forwarding_in.data_valid) begin
                rs2_data_next = mem_forwarding_in.data;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Pipeline Registers
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            rs1_data_reg <= 32'b0;
            rs2_data_reg <= 32'b0;
            instruction_reg <= instruction::NOP;
            program_counter_reg <= constants::RESET_ADDRESS;
            status_forwards <= pipeline_status::BUBBLE;
        end else begin
            // Status and data register updates depend on pipeline control
            if (status_forwards_in == pipeline_status::VALID) begin
                case (status_backwards_in)
                    pipeline_status::READY: begin
                        if (hazard_stall) begin
                            instruction_reg <= instruction::NOP;
                            status_forwards <= pipeline_status::BUBBLE;
                        end else begin
                            // Update instruction and PC registers
                            instruction_reg <= instruction_out;
                            program_counter_reg <= program_counter_in;

                            rs1_data_reg <= rs1_data_next;
                            rs2_data_reg <= rs2_data_next;

                            // Update status
                            if (instruction_out.op == op::ECALL) begin
                                status_forwards <= pipeline_status::ECALL;
                            end else if (instruction_out.op == op::EBREAK) begin
                                status_forwards <= pipeline_status::EBREAK;
                            end else if (instruction_out.op == op::ILLEGAL) begin
                                status_forwards <= pipeline_status::ILLEGAL_INSTRUCTION;
                            end else begin
                                status_forwards <= pipeline_status::VALID;
                            end
                        end
                    end
                    pipeline_status::JUMP: begin
                        // Squash - insert bubble
                        // Still update PC/instruction (data is ignored due to BUBBLE status)
                        instruction_reg <= instruction_out;
                        rs1_data_reg <= rs1_data_next;
                        rs2_data_reg <= rs2_data_next;

                        program_counter_reg <= program_counter_in;
                        status_forwards <= pipeline_status::BUBBLE;
                    end
                    default: begin
                        // Nothing
                    end
                endcase
            end else begin
                // Propagate non-valid status (BUBBLE from previous stage)
                instruction_reg <= instruction_out;
                program_counter_reg <= program_counter_in;
                status_forwards <= status_forwards_in;
            end
        end
    end

endmodule
