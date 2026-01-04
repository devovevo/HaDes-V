/* Copyright (c) 2024 Tobias Scheipel, David Beikircher, Florian Riedl
 * Embedded Architectures & Systems Group, Graz University of Technology
 * SPDX-License-Identifier: MIT
 * ---------------------------------------------------------------------
 * File: cpu.sv
 */



module cpu (
    input logic clk,
    input logic rst,

    wishbone_interface.master memory_fetch_port,
    wishbone_interface.master memory_mem_port,

    input logic external_interrupt_in,
    input logic timer_interrupt_in
);

    // Pipeline signals
    // Fetch <-> Decode
    logic [31:0] fetch_instruction;
    logic [31:0] fetch_program_counter;
    pipeline_status::forwards_t fetch_status_forwards;
    pipeline_status::backwards_t fetch_status_backwards;
    logic [31:0] jump_addr_fetch;

    // Decode <-> Execute
    logic [31:0] decode_rs1_data;
    logic [31:0] decode_rs2_data;
    logic [31:0] decode_program_counter;
    instruction::t decode_instruction;
    pipeline_status::forwards_t decode_status_forwards;
    pipeline_status::backwards_t decode_status_backwards;
    logic [31:0] jump_addr_decode;

    // Execute <-> Memory
    logic [31:0] exe_source_data;
    logic [31:0] exe_rd_data;
    logic [31:0] exe_program_counter;
    logic [31:0] exe_next_program_counter;
    instruction::t exe_instruction;
    forwarding::t exe_forwarding;
    pipeline_status::forwards_t exe_status_forwards;
    pipeline_status::backwards_t exe_status_backwards;
    logic [31:0] jump_addr_execute;

    // Memory <-> Writeback
    logic [31:0] mem_source_data;
    logic [31:0] mem_rd_data;
    logic [31:0] mem_program_counter;
    logic [31:0] mem_next_program_counter;
    instruction::t mem_instruction;
    forwarding::t mem_forwarding;
    pipeline_status::forwards_t mem_status_forwards;
    pipeline_status::backwards_t mem_status_backwards;
    logic [31:0] jump_addr_memory;

    // Writeback forwarding
    forwarding::t wb_forwarding;

    // Instantiate stages and wire them together
    fetch_stage fetch (
        .clk(clk),
        .rst(rst),
        .wb(memory_fetch_port),

        .instruction_reg_out(fetch_instruction),
        .program_counter_reg_out(fetch_program_counter),

        .status_forwards_out(fetch_status_forwards),
        .status_backwards_in(fetch_status_backwards),
        .jump_address_backwards_in(jump_addr_fetch)
    );

    decode_stage decode (
        .clk(clk),
        .rst(rst),

        .instruction_in(fetch_instruction),
        .program_counter_in(fetch_program_counter),
        .exe_forwarding_in(exe_forwarding),
        .mem_forwarding_in(mem_forwarding),
        .wb_forwarding_in(wb_forwarding),

        .rs1_data_reg_out(decode_rs1_data),
        .rs2_data_reg_out(decode_rs2_data),
        .program_counter_reg_out(decode_program_counter),
        .instruction_reg_out(decode_instruction),

        .status_forwards_in(fetch_status_forwards),
        .status_forwards_out(decode_status_forwards),
        .status_backwards_in(decode_status_backwards),
        .status_backwards_out(fetch_status_backwards),
        .jump_address_backwards_in(jump_addr_decode),
        .jump_address_backwards_out(jump_addr_fetch)
    );

    execute_stage execute (
        .clk(clk),
        .rst(rst),

        .rs1_data_inn(decode_rs1_data),
        .rs2_data_inn(decode_rs2_data),
        .instruction_in(decode_instruction),
        .program_counter_in(decode_program_counter),

        .source_data_reg_out(exe_source_data),
        .rd_data_reg_out(exe_rd_data),
        .instruction_reg_out(exe_instruction),
        .program_counter_reg_out(exe_program_counter),
        .next_program_counter_reg_out(exe_next_program_counter),
        .forwarding_out(exe_forwarding),

        .status_forwards_in(decode_status_forwards),
        .status_forwards_out(exe_status_forwards),
        .status_backwards_in(exe_status_backwards),
        .status_backwards_out(decode_status_backwards),
        .jump_address_backwards_in(jump_addr_execute),
        .jump_address_backwards_out(jump_addr_decode)
    );

    memory_stage memory (
        .clk(clk),
        .rst(rst),

        .wb(memory_mem_port),

        .source_data_in(exe_source_data),
        .rd_data_in(exe_rd_data),
        .instruction_in(exe_instruction),
        .program_counter_in(exe_program_counter),
        .next_program_counter_in(exe_next_program_counter),

        .source_data_reg_out(mem_source_data),
        .rd_data_reg_out(mem_rd_data),
        .instruction_reg_out(mem_instruction),
        .program_counter_reg_out(mem_program_counter),
        .next_program_counter_reg_out(mem_next_program_counter),
        .forwarding_out(mem_forwarding),

        .status_forwards_in(exe_status_forwards),
        .status_forwards_out(mem_status_forwards),
        .status_backwards_in(mem_status_backwards),
        .status_backwards_out(exe_status_backwards),
        .jump_address_backwards_in(jump_addr_memory),
        .jump_address_backwards_out(jump_addr_execute)
    );

    writeback_stage writeback (
        .clk(clk),
        .rst(rst),

        .source_data_in(mem_source_data),
        .rd_data_in(mem_rd_data),
        .instruction_in(mem_instruction),
        .program_counter_in(mem_program_counter),
        .next_program_counter_in(mem_next_program_counter),

        .external_interrupt_in(external_interrupt_in),
        .timer_interrupt_in(timer_interrupt_in),

        .forwarding_out(wb_forwarding),

        .status_forwards_in(mem_status_forwards),
        .status_backwards_out(mem_status_backwards),
        .jump_address_backwards_out(jump_addr_memory)
    );

endmodule
