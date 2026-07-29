`timescale 1ns/1ps

//! @title Configurable PRBS Generator
//! @file prbs_generator.sv
//! @brief Generates one of two selectable PRBS sequences using a shared LFSR.

module prbs_gen # (
    parameter int MAX_ORDER = 15,
    parameter int P = 4
) (
    input  logic                     i_clk,
    input  logic                     i_rst_n,
    input  logic                     i_en,
    input  logic [2             : 0] i_sel,
    input  logic [MAX_ORDER - 1 : 0] i_seed,

    output logic o_prbs [P - 1 : 0]
);

    logic [MAX_ORDER - 1 : 0] lfsr_r;
    logic [MAX_ORDER - 1 : 0] lfsr_next;

    logic [MAX_ORDER - 1 : 0] state_w [P : 0];

    genvar i;

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            lfsr_r <= i_seed;
        end else if (i_en) begin
            lfsr_r <= lfsr_next;
        end
    end

    assign state_w [0] = lfsr_r;
    assign lfsr_next = state_w[P];
    
    generate
        for (i = 0; i < P; i++) begin : gen_prbs_step
            prbs_next_state #(
                .MAX_ORDER(MAX_ORDER)
            ) u_prbs_next_state (
                .i_sel  (i_sel),
                .i_lfsr (state_w[i]),
                .o_lfsr (state_w[i+1]),
                .o_prbs (o_prbs[i])
            );
        end
    endgenerate

endmodule