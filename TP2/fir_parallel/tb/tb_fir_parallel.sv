`timescale 1ps/1ps

//! @title Parallel FIR Filter - Testbench
//! @file tb_parallel_fir.sv
//! @author dlugano
//! @date 24/6/2025

module tb_fir_parallel ();
    //! Parameters
    parameter int NB_I      = 2;
    parameter int NB_F      = 0;

    parameter int NB_O      = 12;
    parameter int NBF_O     = 10;

    parameter int NB_TAPS   = 12;
    parameter int NBF_TAPS  = 10;

    parameter int N_TAPS    = 19;
    localparam int N_PREADD = (N_TAPS + 1) / 2;

    parameter int P = 4;
    
    parameter int N_IDATA = 192;
    parameter int N_ODATA = 210;
  
    //! Clock periods
    parameter time CLK_IN_T  = 4_000ps; //! 250 MHz
    parameter time CLK_OUT_T = 1_000ps; //! 1 GHz
    parameter int N_CLK_DELAY = 9;      //! Carga de xn (4 clk_out) + Registro prod_reg (4 clk_out) + Registro o_data (1 clk_out)

    
    //! Vars for the Filter
    logic signed [NB_O - 1 : 0] yn [P - 1 : 0];
    logic signed [NB_I - 1 : 0] xn [P - 1 : 0];
    logic signed [NB_TAPS - 1 : 0] i_taps [N_PREADD - 1 : 0];
    logic i_en;
    logic i_rst_n;

    logic clk_in;
    logic clk_out;

    //! Aux Vars
    logic signed [NB_I    - 1 : 0] i_data [N_IDATA - 1 : 0];
    logic signed [NB_O    - 1 : 0] o_data;

    logic signed [NB_O     -1 : 0] o_expected;

    logic [$clog2(N_IDATA + 1) - 1 : 0] cnt_in;
    logic [$clog2(P) - 1       : 0] cnt_out;

    logic o_flag;

    initial begin
        assert ((N_IDATA % P) == 0)
            else $fatal(1, "N_IDATA must be a multiple of P");
    end

    //! Read taps
    initial begin
        $readmemh("sim/tb/coeffs_Q12_10.hex", i_taps);
    end

    //! Input-clock generation: 250MHz
    initial clk_in = 1'b0;
    always #(CLK_IN_T / 2) clk_in = ~clk_in;

    //! Output-clock generation: 1GHz
    initial clk_out = 1'b0;
    always #(CLK_OUT_T / 2) clk_out = ~clk_out;

    //! Input data
    always @(posedge clk_in) begin
        if(!i_rst_n) begin
            xn[0]  <= 'b0;
            xn[1]  <= 'b0;
            xn[2]  <= 'b0;
            xn[3]  <= 'b0;
            cnt_in <= 'b0;
        end
        else if(i_en) begin
            if (cnt_in < N_IDATA) begin
                xn[0] <= i_data[cnt_in];
                xn[1] <= i_data[cnt_in + 1];
                xn[2] <= i_data[cnt_in + 2];
                xn[3] <= i_data[cnt_in + 3];

                cnt_in <= cnt_in + P;
            end else begin
                //! Zero padding to obtain the FIR convolution tail
                xn[0] <= '0;
                xn[1] <= '0;
                xn[2] <= '0;
                xn[3] <= '0;
            end
        end
    end

    //! Instance of FIR
    fir_parallel
        #(
        .NB_O      (NB_O),    
        .NBF_O     (NBF_O),   
        .NB_TAPS   (NB_TAPS),
        .NBF_TAPS  (NBF_TAPS),
        .N_TAPS    (N_TAPS),
        .P         (P)
        )
        u_fir_pam2_0 
        (
            .o_data  (yn),
            .i_data  (xn),
            .i_taps  (i_taps),
            .i_en    (i_en),
            .i_rst_n (i_rst_n),
            .i_clk   (clk_in)
        );

    //! Output data
    always @(posedge clk_out) begin
        if(!i_rst_n) begin
            o_data  <= 'b0;
            cnt_out <= 'b0;
        end
        else if (i_en) begin
            o_data <= yn[cnt_out];

            if (cnt_out == P - 1)
                cnt_out <= '0;
            else
                cnt_out <= cnt_out + 1'b1;
        end
    end

    tb_output_asserter
    #(
    .NB_DATA(NB_O),
    .N_DATA(N_ODATA),
    .N_CLK_DELAY(N_CLK_DELAY),
    .MEM_INIT_FILE("sim/tb/pam2_expected_Q12_10.hex")
    )
    u_output_asserter_0
    (
        .o_expected(o_expected),
        .o_flag(o_flag),
        .i_asserted(o_data),
        .i_en(i_en),
        .i_clock(clk_out),
        .i_reset(~i_rst_n)
    );


    //! Waves
    initial begin $dumpfile("sim/waves/tb_top_fir_parallel.vcd"); 
    $dumpvars(0,tb_fir_parallel); end


    initial begin
        $display("");
        $display("Simulation Started");

        i_en    = 1'b0;
        i_rst_n = 1'b0;

        $readmemh("sim/tb/pam2_input_Q2_0.hex", i_data);
    
        repeat (5) @(posedge clk_in);
    
        i_rst_n = 1'b1;
    
        repeat (5) @(posedge clk_in);
    
        i_en = 1'b1;
    
        wait(o_flag);
    
        @(posedge clk_in);
    
        i_en = 1'b0;
    
        $display("Simulation Finished");
        $display("");
    
        $finish;
    end

    endmodule