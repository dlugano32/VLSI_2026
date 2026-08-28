`timescale 1ps/1ps

module prbs_to_pam2 #(
    parameter int P = 4
) (
    output logic signed [1:0] o_pam2      [P-1:0],
    input  logic              i_prbs_bits [P-1:0]
);

    always_comb begin
        for (int i = 0; i < P; i++) begin
            o_pam2[i] = i_prbs_bits[i] ? 2'sb01 : 2'sb11;
        end
    end

endmodule