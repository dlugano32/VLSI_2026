`timescale 1ps/1ps

module fir_tb;

    import fir_tb_pkg::*;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~ clk;

    fir_if vif (clk);

    // interp_zeros dut (
    //     .i_clk   (clk),
    //     .i_rst   (vif.i_rst),
    //     .i_valid (vif.i_valid),
    //     .i_data  (vif.i_data),
    //     .o_valid (vif.o_valid),
    //     .o_data  (vif.o_data)
    // );

    interp_poly dut (
        .i_clk   (clk),
        .i_rst   (vif.i_rst),
        .i_valid (vif.i_valid),
        .i_data  (vif.i_data),
        .o_valid (vif.o_valid),
        .o_data  (vif.o_data)
    );

    fir_program u_tb (.vif(vif), .clk(clk));

endmodule

program automatic fir_program (fir_if vif, input logic clk);

    import fir_tb_pkg::*;

    fir_env env;

    initial begin
        $display("");
        $display("=== Simulation started ===");
        $display("");

        env = new(vif);
        env.run();
        
        $display("");
        $display("=== Simulation Finished ===");
        $display("");

        $finish;
    end

endprogram
