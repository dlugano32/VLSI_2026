`timescale 1ps/1ps

module fir_par_tb;

    import fir_par_tb_pkg::*;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~ clk;

    fir_par_if vif (clk);

    fir_par dut (
        .clk(clk),
        .i_arst_n(vif.i_arst_n),
        .i_en(vif.i_en),
        .i_coeffs(vif.i_coeffs),
        .i_data(vif.i_data),
        .o_data(vif.o_data)
    );

    fir_par_program u_tb (.vif(vif), .clk(clk));

endmodule

program automatic fir_par_program (fir_par_if vif, input logic clk);

    import fir_par_tb_pkg::*;

    fir_par_env env;

    initial begin
        env = new(vif);
        env.run();
        $finish;
    end

endprogram