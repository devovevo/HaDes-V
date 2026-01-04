/* Copyright (c) 2024 Tobias Scheipel, David Beikircher, Florian Riedl
 * Embedded Architectures & Systems Group, Graz University of Technology
 * SPDX-License-Identifier: MIT
 * ---------------------------------------------------------------------
 * File: memory_stage.sv
 */

module memory_stage (
    input logic clk,
    input logic rst,

    // Memory interface
    wishbone_interface.master wb,

    // Inputs
    input logic [31:0]   source_data_in,
    input logic [31:0]   rd_data_in,
    input instruction::t instruction_in,
    input logic [31:0]   program_counter_in,
    input logic [31:0]   next_program_counter_in,

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
    // ref_memory_stage golden(.*);

    assign jump_address_backwards_out = jump_address_backwards_in;

    // --- 1. Address & Data Alignment (Combinational) ---
    logic [1:0] addr_offset;
    assign addr_offset = rd_data_in[1:0];

    logic load_op, store_op, aligned;
    logic [3:0] sel;
    
    // Determine operation type and Wishbone Selects
    always_comb begin : wb_control
        load_op  = 1'b0;
        store_op = 1'b0;
        aligned  = 1'b1;
        sel      = 4'b0000;

        case (instruction_in.op)
            op::LB, op::LBU: begin
                load_op = 1'b1;
                sel = 4'b0001 << addr_offset;
            end
            op::LH, op::LHU: begin
                load_op = 1'b1;
                aligned = (addr_offset[0] == 1'b0);
                sel = 4'b0011 << addr_offset;
            end
            op::LW: begin
                load_op = 1'b1;
                aligned = (addr_offset == 2'b00);
                sel = 4'b1111;
            end
            op::SB: begin
                store_op = 1'b1;
                sel = 4'b0001 << addr_offset;
            end
            op::SH: begin
                store_op = 1'b1;
                aligned = (addr_offset[0] == 1'b0);
                sel = 4'b0011 << addr_offset;
            end
            op::SW: begin
                store_op = 1'b1;
                aligned = (addr_offset == 2'b00);
                sel = 4'b1111;
            end
            default: ; 
        endcase
    end

    // Wishbone assignments
    // We only cycle the bus if Valid, Memory Op, Aligned, and not in an error state
    assign wb.cyc = (status_forwards_in == pipeline_status::VALID) && (load_op || store_op) && aligned;
    assign wb.stb = wb.cyc;
    // We only write on Store operations, and when Valid, No Jump, and Aligned
    assign wb.we  = (status_forwards_in == pipeline_status::VALID) && (status_backwards_in != pipeline_status::JUMP) && store_op && aligned;
    assign wb.adr = {2'b0, rd_data_in[31:2]};
    assign wb.sel = sel;
    assign wb.dat_mosi = source_data_in << (addr_offset * 8);

    // --- 2. Read Data Processing (Combinational) ---
    logic [31:0] raw_read_shifted;
    logic [31:0] final_read_data;

    assign raw_read_shifted = wb.dat_miso >> (addr_offset * 8);

    always_comb begin : read_processing
        case (instruction_in.op)
            op::LB:  final_read_data = {{24{raw_read_shifted[7]}},  raw_read_shifted[7:0]};
            op::LBU: final_read_data = {24'b0,                       raw_read_shifted[7:0]};
            op::LH:  final_read_data = {{16{raw_read_shifted[15]}}, raw_read_shifted[15:0]};
            op::LHU: final_read_data = {16'b0,                       raw_read_shifted[15:0]};
            default: final_read_data = raw_read_shifted; // LW or non-load pass-through
        endcase
    end

    // --- 3. Result Selection (Combinational) ---
    logic [31:0] result_data;
    
    always_comb begin : result_mux
        // If it's a Load, we use the data from memory (final_read_data)
        // If it's a Store or ALU op (passed from Execute), we use rd_data_in
        if (load_op) begin
            result_data = final_read_data;
        end else begin
            result_data = rd_data_in;
        end
    end

    // --- 4. Pipeline Control (Backwards) ---
    // Calculate if we are waiting for memory
    logic memory_busy;
    assign memory_busy = (load_op || store_op) && aligned && (status_forwards_in == pipeline_status::VALID) && !(wb.ack || wb.err);

    always_comb begin : control_backwards
        if (memory_busy) begin
            // If we are waiting for memory, we must STALL upstream
            status_backwards_out = pipeline_status::STALL;
        end else begin
            // Otherwise pass through downstream status (STALL/JUMP/READY)
            status_backwards_out = status_backwards_in;
        end
    end

    // --- 5. Forwarding (Combinational) ---
    forwarding::t forwarding;
    
    // Address is valid if we are valid, so can proceed
    assign forwarding.address = (status_forwards_in == pipeline_status::VALID) ? instruction_in.rd_address : 5'b0;
    
    // Data depends on operation:
    // - Load: Valid only if we have ACK (data is ready)
    // - Store/ALU: Valid immediately (data passed through)
    assign forwarding.data = result_data;

    logic csr_op = (instruction_in.op == op::CSRRW) || (instruction_in.op == op::CSRRS) || (instruction_in.op == op::CSRRC) ||
                           (instruction_in.op == op::CSRRWI) || (instruction_in.op == op::CSRRSI) || (instruction_in.op == op::CSRRCI);
    // Valid if we have valid instruction, it's a load, aligned, and we got ACK
    assign forwarding.data_valid = (status_forwards_in == pipeline_status::VALID && ((!csr_op && !load_op) || (load_op && aligned && wb.ack))) ? 1'b1 : 1'b0;
    
    assign forwarding_out = forwarding;

    // --- 6. Pipeline Registers (Sequential) ---
    pipeline_status::forwards_t status_forwards;
    assign status_forwards_out = status_forwards;

    always_ff @(posedge clk) begin
        if (rst) begin
            status_forwards              <= pipeline_status::BUBBLE;
            program_counter_reg_out      <= constants::RESET_ADDRESS;
            next_program_counter_reg_out <= constants::RESET_ADDRESS;
            instruction_reg_out          <= instruction::NOP;
            source_data_reg_out          <= 32'b0;
            rd_data_reg_out              <= 32'b0;
        end else begin
            // Update Logic: Only proceed if input is VALID AND we aren't waiting for memory
            if (status_forwards_in == pipeline_status::VALID) begin
                case (status_backwards_in)
                    pipeline_status::READY: begin
                        // If not busy waiting on memory, update all registers
                        if (!memory_busy) begin
                            program_counter_reg_out      <= program_counter_in;
                            next_program_counter_reg_out <= next_program_counter_in;
                            instruction_reg_out          <= instruction_in;
                            source_data_reg_out          <= source_data_in;
                            rd_data_reg_out              <= result_data;
                            status_forwards              <= pipeline_status::VALID;
                        end

                        // Status Calculation
                        if (load_op) begin
                            if (!aligned) begin
                                status_forwards <= pipeline_status::LOAD_MISALIGNED;
                            end else if (wb.ack) begin
                                status_forwards <= pipeline_status::VALID;
                            end else if (wb.err) begin
                                status_forwards <= pipeline_status::LOAD_FAULT;
                            end
                        end

                        if (store_op) begin
                            if (!aligned) begin
                                status_forwards <= pipeline_status::STORE_MISALIGNED;
                            end else if (wb.ack) begin
                                status_forwards <= pipeline_status::VALID;
                            end else if (wb.err) begin
                                status_forwards <= pipeline_status::STORE_FAULT;
                            end
                        end
                    end

                    pipeline_status::JUMP: begin
                        // Update registers but Squash status (Bubble)
                        status_forwards              <= pipeline_status::BUBBLE;
                        program_counter_reg_out      <= program_counter_in;
                        next_program_counter_reg_out <= next_program_counter_in;
                        instruction_reg_out          <= instruction_in;
                        source_data_reg_out          <= source_data_in;
                        rd_data_reg_out              <= result_data;
                    end

                    default: begin
                        // STALL: Do nothing, hold current registers
                    end
                endcase
            end else begin
                status_forwards              <= status_forwards_in;
                program_counter_reg_out      <= program_counter_in;
                next_program_counter_reg_out <= next_program_counter_in;
                instruction_reg_out          <= instruction_in;
                source_data_reg_out          <= source_data_in;
                rd_data_reg_out              <= rd_data_in;
            end
        end
    end

endmodule
