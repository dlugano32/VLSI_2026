//! @title FIR Filter - Testbench
//! @file tb_fir.v
//! @author dlugano
//! @date 28/9/2024

`timescale 1ns/1ps

module tb_fir ();
  parameter int NB_I      = 2;
  parameter int NB_O      = 12;
  parameter int NBF_O     = 10;
  parameter int NB_TAPS   = 12;
  parameter int NBF_TAPS  = 10;
  parameter int N_TAPS    = 19;

  parameter int N_IDATA = 38;
  parameter int N_CLK_DELAY = 1;
 
  logic signed [NB_O     -1 : 0] o_data;
  logic signed [NB_O     -1 : 0] o_expected;
  logic signed [NB_I     -1 : 0] i_data;
  logic signed [NB_TAPS - 1 : 0] i_taps [N_TAPS - 1 : 0];
  logic i_en;
  logic i_srst;
  logic clk;


  logic i_flag;
  logic o_flag;


    initial begin
        $readmemh("coeffs_Q12_10.hex", i_taps);
    end
  //! Instance of FIR
  fir_pam2
    #(
      .NB_O      (NB_O),    
      .NBF_O     (NBF_O),   
      .NB_TAPS   (NB_TAPS),
      .NBF_TAPS  (NBF_TAPS),
      .N_TAPS    (N_TAPS)
    )
    u_fir_pam2_0 
      (
        .o_data  (o_data),
        .i_data  (i_data),
        .i_taps  (i_taps),
        .i_srst  (i_srst),
        .i_en    (i_en),
        .clk     (clk)
      );

  signal_generator
    #(
      .NB_DATA(NB_I),
      .N_DATA(N_IDATA),
      .MEM_INIT_FILE("impulse_input_Q2_0.hex")
    )
    u_signal_generator_0
      (
        .o_signal(i_data),
        .o_flag(i_flag),
        .i_en(i_en),
        .i_clock(clk),
        .i_reset(i_srst)
      );

    output_asserter
    #(
      .NB_DATA(NB_O),
      .N_DATA(N_IDATA),
      .N_CLK_DELAY(N_CLK_DELAY),
      .MEM_INIT_FILE("impulse_expected_Q12_10.hex")
    )
    u_output_asserter_0
      (
        .o_expected(o_expected),
        .o_flag(o_flag),
        .i_asserted(o_data),
        .i_en(i_en),
        .i_clock(clk),
        .i_reset(i_srst)
      );

  // Clock
  always #5 clk = ~clk;

  initial begin
      $display("");
      $display("Simulation Started");
  
      clk     = 1'b0;
      i_en    = 1'b0;
      i_srst  = 1'b1;
  
      repeat (5) @(posedge clk);
  
      i_srst = 1'b0;
  
      repeat (2) @(posedge clk);
  
      i_en = 1'b1;
  
      wait(o_flag);
  
      @(posedge clk);
  
      i_en = 1'b0;
  
      $display("Simulation Finished");
      $display("");
  
      $finish;
  end

endmodule