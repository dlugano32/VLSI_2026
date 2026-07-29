`timescale 1ns/1ps

//! @title Configurable PRBS Generator
//! @file prbs_generator.sv
//! @brief Generates one of two selectable PRBS sequences using a shared LFSR.

// TODO: Dudas sobre el paralelismo

module prbs_gen # (
    parameter int MAX_ORDER = 15
) (
    input  logic                     i_clk,
    input  logic                     i_rst_n,
    input  logic                     i_en,
    input  logic [2 : 0]             i_sel,
    input  logic [MAX_ORDER - 1 : 0] i_seed

    output logic                     o_prbs,
);

    logic [MAX_ORDER - 1 : 0] lfsr_r;
    logic [MAX_ORDER - 1 : 0] lfsr_next;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            lfsr_r <= i_seed;
        end else if (i_en) begin
            lfsr_r <= lfsr_next;
        end
    end

    //! Next-state logic
    always_comb begin
        lfsr_next = '0;

        case (i_sel)
            3'b000: begin
                //! PRBS10: x^10 + x^7 + 1
                lfsr_next[9:0] = {lfsr_r[8:0], lfsr_r[9] ^ lfsr_r[6]};
            end

            3'b001: begin
                //! PRBS11: x^11 + x^9 + 1
                lfsr_next[10:0] = {lfsr_r[9:0], lfsr_r[10] ^ lfsr_r[8]};
            end

            3'b010: begin
                //! PRBS12: x^12 + x^6 + x^4 + x + 1
                lfsr_next[11:0] = {lfsr_r[10:0], lfsr_r[11] ^ lfsr_r[5] ^ lfsr_r[3] ^ lfsr_r[0]};
            end

            3'b011: begin
                //! PRBS13: x^13 + x^4 + x^3 + x + 1
                lfsr_next[12:0] = {lfsr_r[11:0], lfsr_r[12] ^ lfsr_r[3] ^ lfsr_r[2] ^ lfsr_r[0]};
            end

            3'b100: begin
                //! PRBS14: x^14 + x^5 + x^3 + x + 1
                lfsr_next[13:0] = {lfsr_r[12:0], lfsr_r[13] ^ lfsr_r[4] ^ lfsr_r[2] ^ lfsr_r[0]};
            end

            3'b101: begin
                //! PRBS15: x^15 + x^14 + 1
                lfsr_next = {lfsr_r[13:0], lfsr_r[14] ^ lfsr_r[13]};
            end

            default: begin
                lfsr_next = lfsr_r;
            end
        endcase
    end

    //! PRBS output
    always_comb begin
        case (i_sel)
            3'b000: o_prbs = lfsr_r[9];
            3'b001: o_prbs = lfsr_r[10];
            3'b010: o_prbs = lfsr_r[11];
            3'b011: o_prbs = lfsr_r[12];
            3'b100: o_prbs = lfsr_r[13];
            3'b101: o_prbs = lfsr_r[14];
            default: o_prbs = '0;
        endcase
    end

endmodule