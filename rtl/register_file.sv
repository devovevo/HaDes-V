module register_file (
    input logic clk,
    input logic rst, // Still unused logically, but kept for interface consistency
    // read ports
    input  logic [4:0]  read_address1,
    output logic [31:0] read_data1,
    input  logic [4:0]  read_address2,
    output logic [31:0] read_data2,
    // write port
    input  logic [4:0]  write_address,
    input  logic [31:0] write_data,
    input  logic        write_enable
);

    reg [31:0] file [31:0];

    // --- FIX 1: Simulation Initialization (Optional but Recommended) ---
    // This helps waveforms look clean (green) instead of red (X) at the start.
    // Most FPGA tools will also honor this as the power-on value.
    initial begin
        for (int i = 0; i < 32; i++) begin
            file[i] = 32'b0;
        end
    end

    // --- FIX 2: Hardwire x0 to 0 on the READ path ---
    // This guarantees x0 is 0 without needing to reset the memory array.
    assign read_data1 = (read_address1 == 0) ? 32'b0 : (read_address1 == write_address) ? write_data : file[read_address1];
    assign read_data2 = (read_address2 == 0) ? 32'b0 : (read_address2 == write_address) ? write_data : file[read_address2];

    always_ff @(posedge clk) begin
        // Note: No hardware reset needed here if you use the read-path fix above.
        if (write_enable && write_address != 0) begin
            file[write_address] <= write_data;
        end
    end

endmodule
