//! @title Signal Generator
//! @file tb_signal_generator.v
//! @author dlugano
//! @date 28/9/2024

//! - Signal generator from a file

module tb_signal_generator
   #(
      parameter int NB_DATA       = 8,    //! Number of bits
      parameter int N_DATA        = 1024, //! Number of inputs samples
      parameter     MEM_INIT_FILE = ""    //! File path
    )
   (
      output logic signed [NB_DATA - 1 : 0] o_signal,  //! Output signal
      output logic o_flag,      //! Flag to indicate the end of the signal sequence
      input  logic i_en,      //! Enable signal
      input  logic i_clock,   //! System clock
      input  logic i_reset    //! Reset
   );

   //! Local params
   localparam int NB_COUNT = $clog2(N_DATA + 1);

   //! Vars
   logic signed [NB_DATA   - 1 : 0] data [N_DATA - 1 : 0];
   logic        [NB_COUNT  - 1 : 0] counter_reg;
   logic        [NB_COUNT  - 1 : 0] counter_next;
   logic                            flag_w;

   //! Read signal from file
   initial begin : mem_init
     if (MEM_INIT_FILE != "") begin
       $readmemh(MEM_INIT_FILE, data);
     end
   end

    //! Signal generator
    always_ff @(posedge i_clock) begin : counter
        if(i_reset) begin
            counter_reg <= '0;
        end
        else if(i_en) begin
            counter_reg <= counter_next;
        end
    end

    always_comb begin : signal_gen
        flag_w       = (counter_reg == N_DATA);
        counter_next = counter_reg;
        o_signal     = '0;

        if (!flag_w) begin
            o_signal     = data[counter_reg];
            counter_next = counter_reg + 1'b1;
        end
    end

    assign o_flag = flag_w;

endmodule