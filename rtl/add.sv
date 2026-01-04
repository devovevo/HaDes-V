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
