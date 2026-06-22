`timescale 1ns/1ps

module sync_bus #(
    parameter int WIDTH = 8,
    parameter int PIPE  = 4
) (
    input  logic i_clk_a,
    input  logic i_clk_b,
    input  logic i_rst_a,
    input  logic i_rst_b,
    input  logic [WIDTH - 1 : 0] i_data,
    output logic [WIDTH - 1 : 0] o_data
);

    //! Source-domain toggle
    logic [WIDTH - 1 : 0] toggle;

    //! Destination-domain synchronization pipeline
    logic [WIDTH - 1 : 0] pipe [PIPE - 1 : 0];

    //! Toggle generation in source clock domain
    genvar i;
    generate
        for(i=0; i<WIDTH ; i++) begin
            always_ff @(posedge i_clk_a) begin : src_toggle
                if (i_rst_a) begin
                    toggle[i] <= '0;
                end else if (i_data[i]) begin
                    toggle[i] <= ~toggle[i];
                end
            end
        end
    endgenerate

    //! Toggle synchronization into destination clock domain
    always_ff @(posedge i_clk_b) begin : dst_pipe
        if (i_rst_b) begin
            for (int i = 0; i < PIPE; i++) begin
                pipe[i] <= '0;
            end
        end else begin
            pipe[0] <= toggle;

            for (int i = 1; i < PIPE; i++) begin
                pipe[i] <= pipe[i - 1];
            end
        end
    end

    //! Edge detection in destination clock domain
    generate
        for (i=0; i<WIDTH; i++)
            assign o_data[i] = pipe[PIPE - 1][i] ^ pipe[PIPE - 2][i];
    endgenerate

endmodule