/* Copyright (c) 2024 Tobias Scheipel, David Beikircher, Florian Riedl
 * Embedded Architectures & Systems Group, Graz University of Technology
 * SPDX-License-Identifier: MIT
 * ---------------------------------------------------------------------
 * File: fetch_stage.sv
 */

module fetch_stage (
    input logic clk,
    input logic rst,

    // Memory interface
    wishbone_interface.master wb,

    //  Output data
    output logic [31:0] instruction_reg_out,
    output logic [31:0] program_counter_reg_out,

    // Pipeline control
    output pipeline_status::forwards_t  status_forwards_out,
    input  pipeline_status::backwards_t status_backwards_in,
    input  logic [31:0] jump_address_backwards_in
);

    // TODO: Delete the following line and implement this module.
    // ref_fetch_stage golden(.*);

    pipeline_status::forwards_t status_forwards;

    reg [31:0] pc;
    reg [31:0] pc_out;
    reg [31:0] instruction;
    bit cyc = 1'b1;

    assign wb.cyc = cyc;
    assign wb.stb = cyc;
    assign wb.we  = 1'b0;
    assign wb.sel = 4'b1111;
    assign wb.adr = {2'b0, pc[31:2]};  // Convert byte address to word address for wishbone
    assign wb.dat_mosi = 32'b0;

    assign instruction_reg_out     = instruction;
    assign program_counter_reg_out = pc_out;
    assign status_forwards_out     = status_forwards;

    always_ff @(posedge clk) begin
        if (rst) begin
            // cyc <= 1'b0;
            status_forwards <= pipeline_status::BUBBLE;
            pc <= constants::RESET_ADDRESS;  // Store as byte address
            pc_out <= constants::RESET_ADDRESS;
        end else begin
            case (status_backwards_in)
                pipeline_status::JUMP: begin
                    // cyc <= 1'b0;
                    pc <= jump_address_backwards_in;
                    pc_out <= pc;  // Output current PC (next sequential) during jump cycle
                    status_forwards <= pipeline_status::BUBBLE;
                end
                pipeline_status::READY: begin
                    // cyc <= 1'b1;
                    if (wb.ack) begin
                        instruction <= wb.dat_miso;
                        pc_out <= pc;
                        status_forwards <= pipeline_status::VALID;
                    end else if (wb.err) begin
                        status_forwards <= pipeline_status::FETCH_FAULT;
                    end else begin
                        status_forwards <= pipeline_status::BUBBLE;
                    end

                    if (wb.ack || wb.err) begin
                        pc <= pc + 4;
                    end
                end
                default: begin
                    // Nothing for now
                end
            endcase
        end
    end

endmodule
