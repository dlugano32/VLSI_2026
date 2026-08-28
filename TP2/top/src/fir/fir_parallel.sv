`timescale 1ns/1ps

module fir_parallel #(
    parameter int NB_O     = 12,
    parameter int NBF_O    = 10,

    parameter int NB_TAPS  = 12,
    parameter int NBF_TAPS = 10,

    parameter int N_TAPS   = 19,

    parameter int P = 4

) (
    output logic signed [NB_O - 1 : 0]    o_data [P - 1 : 0],
    input  logic signed [       1 : 0]    i_data [P - 1 : 0],
    input  logic signed [NB_TAPS - 1 : 0] i_taps [((N_TAPS + 1) / 2) - 1 : 0],

    input  logic i_en,     //! Enable
    input  logic i_rst_n,  //! Reset
    input  logic i_clk     //! Clock
);

    localparam int NB_DATA = 2;

    logic signed [NB_DATA - 1 : 0] regs  [N_TAPS - 2: 0];

    logic signed [NB_DATA - 1 : 0] sop_x [P - 1 : 0][N_TAPS - 1 : 0];

    logic signed    [NB_O - 1 : 0] sop_y [P - 1 : 0];


    genvar i,j,k;

    regressor #(
        .NB_DATA(NB_DATA),
        .N_TAPS (N_TAPS),
        .P      (P)
    ) u_regressor (
        .o_reg   (regs),
        .i_x     (i_data),
        .i_en    (i_en),
        .i_rst_n (i_rst_n),
        .i_clk   (i_clk)
    );

    generate
        for (i = 0; i < P; i++) begin : gen_sop

            //! Current-cycle inputs, ordered from newest to oldest
            for (j = 0; j < i+1; j++) begin : gen_current_input
                assign sop_x[i][i-j] = i_data[j];
            end

            //! Samples stored in the regressor
            for (k = i + 1; k < N_TAPS; k++) begin : gen_delayed_inputs
                assign sop_x[i][k] = regs[k-i-1];
            end

            sop #(
                .NB_O     (NB_O),
                .NBF_O    (NBF_O),
                .NB_TAPS  (NB_TAPS),
                .NBF_TAPS (NBF_TAPS),
                .N_TAPS   (N_TAPS)
            ) u_sop (
                .o_y     (sop_y[i]),
                .i_x     (sop_x[i]),
                .i_taps  (i_taps),
                .i_en    (i_en),
                .i_rst_n (i_rst_n),
                .i_clk   (i_clk)
            );

        end
    endgenerate

    //! Pipeline
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int lane = 0; lane < P; lane++)
                o_data[lane] <= '0;
        end else if(i_en) begin
            for (int lane = 0; lane < P; lane++)
                o_data[lane] <= sop_y[lane];
        end
    end

endmodule