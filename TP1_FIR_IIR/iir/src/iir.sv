`timescale 1ns/1ps

module iir #(
    parameter int NB_O  = 8,
    parameter int NBF_O = 7,
    parameter int NB_A  = 8,
    parameter int NBF_A = 7
) (
    output logic signed [NB_O - 1 : 0] o_data,
    input  logic signed [7        : 0] i_data,
    input  logic signed [NB_A - 1 : 0] i_a, //! a = 0.98 = 8'h7D
    input  logic i_en,
    input  logic i_srst,
    input  logic i_clk
);

    //! Input format
    localparam int NB_I   = 8;
    localparam int NBF_I  = 7;

    //! Internal format: S(16,14)
    localparam int NB_FB  = NB_O + NB_A;
    localparam int NBF_FB = NBF_O + NBF_A;

    //! Registers
    logic signed [NB_I  - 1 : 0] x1_reg;
    logic signed [NB_O  - 1 : 0] y1_reg;

    //! Combinational signals
    logic signed [NB_I        : 0] diff;
    logic signed [NB_FB   - 1 : 0] diff_ext;

    logic signed [NB_FB   - 1 : 0] feedback;

    logic signed [NB_FB       : 0] y_sum;
    logic signed [NB_O    - 1 : 0] y_next;

    //! y[n] = x[n] - x[n-1] + a y[n-1]

    always_ff @(posedge i_clk) begin : regs
        if (i_srst) begin
            x1_reg <= '0;
            y1_reg <= '0;
        end else if (i_en) begin
            x1_reg <= i_data;
            y1_reg <= y_next;
        end
    end

    //! diff = x[n] - x[n-1]
    //! S(8,7) - S(8,7) -> S(9,7)
    assign diff = $signed({i_data[NB_I - 1], i_data}) -
                  $signed({x1_reg[NB_I - 1], x1_reg});

    //! diff_ext = diff resized to S(16,14)
    assign diff_ext = $signed({diff, {(NBF_FB - NBF_I){1'b0}}});
    
    //! feedback = a * y[n-1]
    //! S(8,7) * S(8,7) -> S(16,14)
    assign feedback = i_a * y1_reg;

    //! y_sum = x[n] - x[n-1] + a y[n-1] = diff_ext + feedback
    //! y_sum = S(16,14) + S(16,14) -> S(17,14)
    assign y_sum = $signed({diff_ext[NB_FB - 1] , diff_ext}) + 
                   $signed({feedback[NB_FB - 1], feedback});
    
    //! S(17,14) -> S(8,7)
    truncNsat #(
        .NB_I   (NB_FB + 1),
        .NBF_I  (NBF_FB),
        .NB_O   (NB_O),
        .NBF_O  (NBF_O)
    ) u_truncNsat_sum (
        .i_data (y_sum),
        .o_data (y_next)
    );

    assign o_data = y_next;

endmodule