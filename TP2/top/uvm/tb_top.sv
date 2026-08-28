`timescale 1ps/1ps

module tb_top;

    import top_pkg::*;

    localparam time CLK_CPU_PERIOD = 5ns; //! 200 MHz
    localparam time CLK_DSP_PERIOD = 1ns; //! 1 GHz

    logic i_clk_cpu = 1'b0;
    logic i_clk_dsp = 1'b0;

    always #(CLK_CPU_PERIOD / 2) i_clk_cpu = ~i_clk_cpu;
    always #(CLK_DSP_PERIOD / 2) i_clk_dsp = ~i_clk_dsp;

    top_if tif (.clk_cpu(i_clk_cpu));

    top u_top (
        .i_clk_cpu  (i_clk_cpu),
        .i_clk_dsp  (i_clk_dsp),
        .i_arst_n   (tif.arst_n),
        .i_addr     (tif.addr),
        .i_wdata    (tif.wdata),
        .i_req      (tif.req),
        .i_is_write (tif.is_write),
        .o_rdata    (tif.rdata),
        .o_ack      (tif.ack)
    );

    tb_program u_tb (tif);

    initial begin
        #500us;
        $fatal(1, "Top integration simulation timeout.");
    end

endmodule

program automatic tb_program (top_if tif);

    import top_pkg::*;

    top_env env;

    initial begin
        env = new(tif);
        env.run();
        env.report();
        $finish;
    end

endprogram
