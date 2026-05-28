`timescale 1ns/1ps

//! @title IIR Filter - Testbench
//! @file tb_iir.v
//! @author dlugano
//! @date 28/9/2024

module tb_iir ();
  parameter int NB_I   = 8;
  parameter int NB_F   = 7;
  parameter int NB_O   = 8;
  parameter int NBF_O  = 7;
  parameter int NB_A   = 8;
  parameter int NBF_A  = 7;

  parameter int N_IDATA = 1000;
  parameter int N_ODATA = 1000;
  parameter int N_CLK_DELAY = 0;
 
  logic signed [NB_O     -1 : 0] o_data;
  logic signed [NB_O     -1 : 0] o_expected;
  logic signed [NB_I     -1 : 0] i_data;
  logic i_en;
  logic i_srst;
  logic clk;

  logic i_flag;
  logic o_flag;

  parameter hex i_a = 8'h7D; //! a = 0.98 in S(8,7)

  //! Instance of FIR
  iir
    #(
      .NB_O      (NB_O),    
      .NBF_O     (NBF_O),   
      .NB_A      (NB_A),
      .NBF_A     (NBF_A)
    )
    u_iir_0 
      (
        .o_data  (o_data),
        .i_data  (i_data),
        .i_a     (i_a),
        .i_srst  (i_srst),
        .i_en    (i_en),
        .clk     (clk)
      );

    tb_signal_generator
    #(
      .NB_DATA(NB_I),
      .N_DATA(N_IDATA),
      .MEM_INIT_FILE("sim/tb/x_t.hex")
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
      .MEM_INIT_FILE("sim/tb/y_t.hex")
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
  initial begin $dumpfile("sim/waves/iir.vcd"); 
  $dumpvars(0,tb_iir); end

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