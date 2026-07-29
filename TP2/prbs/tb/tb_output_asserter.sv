//! @title Output asserter
//! @file tb_output_asserter.v
//! @author dlugano
//! @date 28/9/2024

module tb_output_asserter
#(
   parameter int NB_DATA         = 8,    //! Number of bits
   parameter int N_DATA          = 1024, //! Number of inputs samples
   parameter int N_CLK_DELAY     = 10,  //! Number of clock delays to start the assertion
   parameter     MEM_INIT_FILE   = "" //! File path
 )
(
   output logic signed [NB_DATA - 1 : 0]  o_expected,   //! Output expected signal
   output logic o_flag,                                 //! Flag to indicate the end of the signal sequence
   output logic [$clog2(N_DATA + N_CLK_DELAY + 1) - 1 : 0] o_cnt,
   input  logic signed [NB_DATA - 1 : 0]  i_asserted,   //! Input signal to be asserted
   input  logic i_en,
   input  logic i_clock,    //! System clock
   input  logic i_reset     //! Reset
);

   //! Local params
   localparam int NB_COUNT = $clog2(N_DATA + N_CLK_DELAY + 1);

    //! Vars
    logic signed [NB_DATA  - 1 : 0] data[N_DATA - 1 : 0];
    logic signed [NB_DATA  - 1 : 0] expected_data;
    logic        [NB_COUNT - 1 : 0] counter_reg;
    logic        [NB_COUNT - 1 : 0] counter_next;
    logic                           flag_w;

    logic        [NB_COUNT - 1 : 0] assertion_r;


    //! Read signal from file
    initial begin : mem_init
    if (MEM_INIT_FILE != "") begin
        $readmemh(MEM_INIT_FILE, data);
    end
    end

    //! Counter register
    always_ff @(posedge i_clock) begin : counter
       if(i_reset) begin
          counter_reg  <= '0;
      end
       else if( i_en )
          counter_reg  <= counter_next;
    end

    //! Counter next-state logic
    always_comb begin : counter_next_state
        flag_w        = (counter_reg == (N_DATA + N_CLK_DELAY));
        counter_next  = counter_reg;
        expected_data = '0;

        if (!flag_w) begin
            counter_next = counter_reg + 1'b1;
        end

        if (!flag_w && (counter_reg >= N_CLK_DELAY)) begin
            expected_data = data[counter_reg - N_CLK_DELAY];
        end
    end

    //! Output assertion
    always_ff @(posedge i_clock) begin : assertion_check
        if(i_reset) begin
            assertion_r <= '0;
        end else if (i_en && !flag_w && (counter_reg >= N_CLK_DELAY)) begin
            if (i_asserted !== data[counter_reg - N_CLK_DELAY]) begin
                // $display("ASSERTION FAILED in %0d: asserted = %0h, expected = %0h", counter_reg - N_CLK_DELAY, i_asserted, data[counter_reg - N_CLK_DELAY]);
            end else begin
                // $display("ASSERTION SUCCEEDED in %0d: asserted = %0h, expected = %0h", counter_reg - N_CLK_DELAY, i_asserted, data[counter_reg - N_CLK_DELAY]);
                assertion_r <= assertion_r + 1;
            end
        end
    end

    assign o_flag     = flag_w;
    assign o_expected = expected_data;
    assign o_cnt = assertion_r;

    endmodule