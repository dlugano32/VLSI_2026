`timescale 1ns/1ps

//! @title Configurable PRBS Generator
//! @file prbs_generator.sv
//! @brief Generates one of two selectable PRBS sequences using a shared LFSR.

module prbs_gen # (
    parameter int PRBS_ORDER_0 = 10,
    parameter int PRBS_ORDER_1 = 15,
    parameter int MAX_ORDER = ( PRBS_ORDER_0 > PRBS_ORDER_1 ) ? PRBS_ORDER_0 : PRBS_ORDER_1
) (
    input  logic                     i_clk,
    input  logic                     i_rst_n,
    input  logic                     i_en,
    input  logic                     i_sel,
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
            1'b0: begin
                //! PRBS10: x^10 + x^7 + 1
                lfsr_next[PRBS_ORDER_0-1:0] = {lfsr_r[PRBS_ORDER_0-2:0], lfsr_r[PRBS_ORDER_0-1] ^ lfsr_r[PRBS_ORDER_0-4]};
            end

            1'b1: begin
                //! PRBS15: x^15 + x^14 + 1
                lfsr_next = {lfsr_r[PRBS_ORDER_1-2:0], lfsr_r[PRBS_ORDER_1-1] ^ lfsr_r[PRBS_ORDER_1-2]};
            end

            default: begin
                lfsr_next = lfsr_r;
            end
        endcase
    end

    //! PRBS output
    always_comb begin
        case (i_sel)
            1'b0:    o_prbs = lfsr_r[PRBS_ORDER_0-1];
            1'b1:    o_prbs = lfsr_r[PRBS_ORDER_1-1];
            default: o_prbs = 1'b0;
        endcase
    end

endmodule