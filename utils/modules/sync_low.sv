//! @title Synchronizer
//! @file sync_low.sv
//! @author Damian Lugano
//! @date 11-5-2026

//! - Syncronizer module to transfer a signal from one clock domain to another. It uses a two-stage flip-flop synchronizer to minimize the risk of metastability. 
//!     The output `o_req` will be high for one clock cycle of `clk_b` when a falling edge is detected on `i_req` in the `clk_a` domain.
//!     Standard cells are usually used for this. When using personalized cells, it is important to notify PD team to ensure that the FFs from the synchronizer 
//!     are close to each other to minimize the delay.

module sync_low
  (
    input  logic i_req,
    output logic o_req,
    input  clk_a,
    input  clk_b
  );

  logic r_req_a;
  logic r_req_b [2];

  always_ff @(posedge clk_a) begin
    r_req_a <= i_req;
  end

  always_ff @(posedge clk_b) begin
    r_req_b[0] <= r_req_a;
    r_req_b[1] <= r_req_b[0];
  end

  assign o_req = ((r_req_b[0]) & (~r_req_b[1]));