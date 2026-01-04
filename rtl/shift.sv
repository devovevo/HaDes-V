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
