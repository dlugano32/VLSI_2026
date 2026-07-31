`timescale 1ps/1ps

module prbs_next_state #(
    parameter int MAX_ORDER
) (
    input  logic [2 : 0]             i_sel,
    input  logic [MAX_ORDER - 1 : 0] i_lfsr,
    output logic [MAX_ORDER - 1 : 0] o_lfsr,
    output logic                     o_prbs
);

    //! Next-state logic
    always_comb begin
        o_lfsr = '0;

        case (i_sel)
            3'b000: begin
                //! PRBS10: x^10 + x^7 + 1
                o_lfsr[9:0] = {i_lfsr[8:0], i_lfsr[9] ^ i_lfsr[6]};
            end

            3'b001: begin
                //! PRBS11: x^11 + x^9 + 1
                o_lfsr[10:0] = {i_lfsr[9:0], i_lfsr[10] ^ i_lfsr[8]};
            end

            3'b010: begin
                //! PRBS12: x^12 + x^6 + x^4 + x + 1
                o_lfsr[11:0] = {i_lfsr[10:0], i_lfsr[11] ^ i_lfsr[5] ^ i_lfsr[3] ^ i_lfsr[0]};
            end

            3'b011: begin
                //! PRBS13: x^13 + x^4 + x^3 + x + 1
                o_lfsr[12:0] = {i_lfsr[11:0], i_lfsr[12] ^ i_lfsr[3] ^ i_lfsr[2] ^ i_lfsr[0]};
            end

            3'b100: begin
                //! PRBS14: x^14 + x^5 + x^3 + x + 1
                o_lfsr[13:0] = {i_lfsr[12:0], i_lfsr[13] ^ i_lfsr[4] ^ i_lfsr[2] ^ i_lfsr[0]};
            end

            3'b101: begin
                //! PRBS15: x^15 + x^14 + 1
                o_lfsr = {i_lfsr[13:0], i_lfsr[14] ^ i_lfsr[13]};
            end

            default: begin
                o_lfsr = i_lfsr;
            end
        endcase
    end

    //! PRBS output
    always_comb begin
        case (i_sel)
            3'b000: o_prbs = i_lfsr[9];
            3'b001: o_prbs = i_lfsr[10];
            3'b010: o_prbs = i_lfsr[11];
            3'b011: o_prbs = i_lfsr[12];
            3'b100: o_prbs = i_lfsr[13];
            3'b101: o_prbs = i_lfsr[14];
            default: o_prbs = '0;
        endcase
    end

endmodule