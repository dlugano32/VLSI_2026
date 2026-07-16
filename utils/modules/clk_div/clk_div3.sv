`timescale 1ps/1ps

module clk_div3 (
    input  logic i_rst,
    input  logic i_clk,
    output logic o_clk
);

    logic [1:0] cnt_rise_r;
    logic [1:0] cnt_rise_next;

    logic [1:0] cnt_fall_r;
    logic [1:0] cnt_fall_next;

    logic rise_flag;
    logic fall_flag;

    //! Rising-edge modulo-3 counter
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            cnt_rise_r <= '0;
        end else begin
            cnt_rise_r <= cnt_rise_next;
        end
    end

    assign cnt_rise_next = (cnt_rise_r == 2) ? 0 : cnt_rise_r + 1;

    assign rise_flag = (cnt_rise_r == 0);

    //! Falling-edge modulo-3 counter
    always_ff @(negedge i_clk) begin
        if (i_rst) begin
            cnt_fall_r <= '0;
        end else begin
            cnt_fall_r <= cnt_fall_next;
        end
    end

    assign cnt_fall_next = (cnt_fall_r == 2) ? 0 : cnt_fall_r + 1;

    assign fall_flag = (cnt_fall_r == 0);

    assign o_clk = rise_flag | fall_flag;

endmodule