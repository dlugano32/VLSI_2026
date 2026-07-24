`timescale 1ns/1ps

module regressor #(
    parameter int NB_DATA = 2,
    parameter int N_TAPS  = 19,
    parameter int P = 4         //! Number of parallel input samples per cycle
) (
    output logic signed [NB_DATA - 1 : 0] o_reg [N_TAPS - 2 : 0],
    input  logic signed [NB_DATA - 1 : 0] i_x   [P - 1 : 0],
    input  logic i_en,      //! Enable   
    input  logic i_rst_n,  //! Reset
    input  logic i_clk      //! Clock
);

    //! Number of delayed samples required by the FIR regressor
    localparam int N_REGS = N_TAPS - 1;

    //! Number of register levels required for P parallel data paths
    localparam int LEVELS = (N_REGS + P - 1) / P;

    //! Parallel delay lines: each column corresponds to one input lane
    logic signed [NB_DATA - 1 : 0] regs [LEVELS - 1 : 0][P - 1 : 0];

    genvar i, j;

    //! Generate the P parallel shift-register chains
    generate
        for (i = 0; i < LEVELS; i++) begin : gen_level
            for (j = 0; j < P; j++) begin : gen_reg

                localparam int IDX = i * P + j;

                if (IDX < N_REGS) begin : gen_valid_reg

                    if (i == 0) begin : gen_first_level
                        always_ff @(posedge i_clk) begin
                            if (!i_rst_n)
                                regs[i][j] <= '0;
                            else if (i_en)
                                regs[i][j] <= i_x[P-1-j];
                        end

                    end else begin : gen_delay_level
                        always_ff @(posedge i_clk) begin
                            if (!i_rst_n)
                                regs[i][j] <= '0;
                            else if (i_en)
                                regs[i][j] <= regs[i-1][j];
                        end
                    end
                end
            end
        end
    endgenerate

    //! Assign the register array into the output regressor
    generate
        for (i = 0; i < LEVELS; i++) begin : assign_level
            for (j = 0; j < P; j++) begin : assign_reg

                localparam int IDX = i*P + j;

                if (IDX < N_REGS) begin : valid_output
                    assign o_reg[IDX] = regs[i][j];
                end

            end
        end
    endgenerate

endmodule