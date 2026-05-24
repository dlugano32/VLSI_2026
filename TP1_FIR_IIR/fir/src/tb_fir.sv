`timescale 1ns/1ps

//! @title FIR Filter - Testbench
//! @file tb_fir.v
//! @author dlugano
//! @date 28/9/2024

module tb_fir ();
  parameter int NB_I      = 2;
  parameter int NB_F      = 0;
  parameter int NB_O      = 12;
  parameter int NBF_O     = 10;
  parameter int NB_TAPS   = 12;
  parameter int NBF_TAPS  = 10;
  parameter int N_TAPS    = 19;

  //parameter int N_IDATA = 38;
  parameter int N_IDATA = 192;
  //parameter int N_ODATA = 56;
  parameter int N_ODATA = 210;
  parameter int N_CLK_DELAY = 2;
 
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
      $readmemh("sim/tb/coeffs_Q12_10.hex", i_taps);
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

    tb_signal_generator
    #(
      .NB_DATA(NB_I),
      .N_DATA(N_IDATA),
      //.MEM_INIT_FILE("sim/tb/impulse_input_Q2_0.hex")
      .MEM_INIT_FILE("sim/tb/pam2_input_Q2_0.hex")
    )
    u_signal_generator_0
      (
        .o_signal(i_data),
        .o_flag(i_flag),
        .i_en(i_en),
        .i_clock(clk),
        .i_reset(i_srst)
      );

    tb_output_asserter
    #(
      .NB_DATA(NB_O),
      .N_DATA(N_ODATA),
      .N_CLK_DELAY(N_CLK_DELAY),
      //.MEM_INIT_FILE("sim/tb/impulse_expected_Q12_10.hex")
      .MEM_INIT_FILE("sim/tb/pam2_expected_Q12_10.hex")
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

  //! Clock
  initial clk=0;
  always #5 clk = ~clk;
  
  //! Waves
  initial begin $dumpfile("sim/waves/fir.vcd"); 
  $dumpvars(0,tb_fir); end

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