`timescale 1ps/1ps

module sync_rst_n #(
    parameter int PIPE = 3
) (
    input  logic i_clk,
    input  logic i_arst_n,
    output logic o_rst_n
);

    logic pipe_r [PIPE - 1 : 0];

    always_ff @(posedge i_clk or negedge i_arst_n)
        if (!i_arst_n) begin
            for (int i = 0; i<PIPE; i++) begin
                pipe_r[i] <= '0;    //! Active reset
            end
        end else begin
            pipe_r[0] <= 1'b1;

            for (int i = 1; i < PIPE; i++) begin
                pipe_r[i] <= pipe_r[i - 1];
            end
        end
    
    assign o_rst_n = pipe_r[PIPE - 1];
    
endmodule