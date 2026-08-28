`timescale 1ps/1ps

module coeff_handshake #(
    parameter int N_COEFFS = 10,
    parameter int NB_COEFF = 12
) (
    input  logic i_clk_cpu,
    input  logic i_rst_cpu_n,
    input  logic i_commit_cpu,
    input  logic signed [NB_COEFF - 1 : 0] i_taps_shadow_cpu [N_COEFFS - 1 : 0],
    output logic o_busy_cpu,

    input  logic i_clk_dsp,
    input  logic i_rst_dsp_n,
    output logic signed [NB_COEFF - 1 : 0] o_taps_active_dsp [N_COEFFS - 1 : 0]
);

    logic signed [NB_COEFF - 1 : 0] taps_active_dsp_r [N_COEFFS - 1 : 0];

    //! CPU
    logic busy_cpu_r;
    logic commit_cpu;
    logic ack_cpu;

    //! DSP
    logic ack_dsp_r;
    logic commit_dsp;

    assign commit_cpu = i_commit_cpu && !busy_cpu_r;

    always_ff @(posedge i_clk_cpu or negedge i_rst_cpu_n) begin
        if(!i_rst_cpu_n) begin
            busy_cpu_r <= '0;        
        end else begin

            if (ack_cpu) begin
                busy_cpu_r <= '0;
            end else if (commit_cpu) begin
                busy_cpu_r <= 1'b1;
            end
        end
    end

    always_ff @(posedge i_clk_dsp or negedge i_rst_dsp_n) begin
        if(!i_rst_dsp_n) begin
            ack_dsp_r <= '0;

            for(int i = 0; i < N_COEFFS; i++)
                taps_active_dsp_r[i] <= '0;

        end else begin
            ack_dsp_r <= 1'b0;

            if (commit_dsp) begin
                ack_dsp_r <= 1'b1;

                for (int i = 0; i < N_COEFFS; i++)
                    taps_active_dsp_r[i] <= i_taps_shadow_cpu[i];
            end
        end
    end

    sync_pulse #(
        .PIPE (3)
    ) u_commit_cdc (
        .o_pulse (commit_dsp),
        .i_pulse (commit_cpu),
        .i_rst_n (i_rst_dsp_n),
        .i_clk   (i_clk_dsp)
    );

    req_toggle #(
        .PIPE(3)
    ) u_ack_cdc (
        .i_clk_a(i_clk_dsp),
        .i_clk_b(i_clk_cpu),
        .i_rst_a(i_rst_dsp_n),
        .i_rst_b(i_rst_cpu_n),
        .i_req(ack_dsp_r),
        .o_req(ack_cpu)
    );

    assign o_busy_cpu = busy_cpu_r || commit_cpu;
    assign o_taps_active_dsp = taps_active_dsp_r;
endmodule
