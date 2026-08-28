`timescale 1ps/1ps

module du #(
    parameter  int WIDTH  = 12,
    parameter  int DEPTH  = 256, //! Debe ser siempre potencia de dos
    localparam int ADDR_W = $clog2(DEPTH)
) (
    // DSP domain
    input  logic                        i_wr_clk,
    input  logic                        i_wr_rst_n,
    input  logic                        i_arm,
    input  logic                        i_trigger,
    input  logic                [1 : 0] i_mode,
    input  logic signed [WIDTH - 1 : 0] i_data,

    // CPU domain
    input  logic                        i_rd_clk,
    input  logic                        i_rd_rst_n,
    input  logic                        i_rd_en,
    input  logic       [ADDR_W - 1 : 0] i_rdaddr,

    output logic signed [WIDTH - 1 : 0] o_data,
    output logic                        o_rd_valid,
    output logic       [ADDR_W - 1 : 0] o_ptr,
    output logic                        o_done
);

    logic signed [WIDTH  - 1 : 0] mem [DEPTH - 1 : 0];

    logic        [ADDR_W - 1 : 0] ptr_wr;

    logic        [ADDR_W - 1 : 0] target;
    logic        [ADDR_W - 1 : 0] post_tr_cnt_r;
    
    logic w_en;
    logic capture_done;

    logic done_wr;
    logic done_rd;
    
    typedef enum bit [1:0] {PRE, MID, POST} mode_e;
    typedef enum bit [1:0] {IDLE, RUN, CAPTURING, DONE} state_e;
    
    state_e state_r;
    state_e state_next;

    mode_e mode_r;

    always_ff @(posedge i_wr_clk or negedge i_wr_rst_n) begin
        if(!i_wr_rst_n) begin
            mode_r <= MID;
        end else if(i_arm) begin    //! Dado que el modo proviene del regmap, desde otro dominio de clock. Primero se deja estable el modo y luego se da la señal de arm
            case(i_mode)
                PRE, MID, POST : mode_r <= mode_e'(i_mode);
                default : mode_r <= MID; //! En caso de que la entrada tome un valor prohibido
            endcase
        end
    end

    //! FSM
    always_ff @(posedge i_wr_clk or negedge i_wr_rst_n) begin
        if(!i_wr_rst_n) begin
            state_r <= IDLE;
        end else begin
            state_r <= state_next;
        end
    end

    //! Next state logic
    always_comb begin
        state_next = state_r;

        //! A new arm request restarts the acquisition from any state.
        if(i_arm) begin
            state_next = RUN;
        end else begin
            case(state_r)
                IDLE : begin
                    state_next = IDLE;
                end
                
                RUN: begin
                    if(i_trigger) begin
                        if(mode_r == PRE) begin
                            state_next = DONE;
                        end else begin
                            state_next = CAPTURING;
                        end
                    end
                end

                CAPTURING: begin
                    if(capture_done) begin
                        state_next = DONE;
                    end
                end

                DONE: begin
                    state_next = DONE;
                end

                default: state_next = IDLE;
            endcase
        end
    end

    //! w_en para los diferentes modos
    always_comb begin
        case (mode_r)
            PRE: begin
                w_en = (state_r == RUN);    //! Queremos que escriba siempre
            end

            MID: begin
                w_en = (state_r == RUN) || (state_r == CAPTURING); //! Queremos que escriba en RUN y en CAPTURING
            end

            POST: begin
                w_en = (state_r == RUN && i_trigger) || (state_r == CAPTURING); //! Queremos que escriba solo despues del trigger
            end

            default: begin
                w_en = 1'b0;
            end
        endcase
    end

    assign target = (mode_r == MID) ? ((DEPTH/2) - 1) : (DEPTH - 1);
    assign capture_done = (state_r == CAPTURING) && (post_tr_cnt_r == target);

    //! Write mem
    always_ff @(posedge i_wr_clk) begin
        if (w_en && !i_arm) //! When rearmed, memory writing stops
            mem[ptr_wr] <= i_data;
    end

    //! Write pointer
    always_ff @(posedge i_wr_clk or negedge i_wr_rst_n) begin
        if(!i_wr_rst_n) begin
            ptr_wr <= '0;
        end else if(i_arm) begin
            ptr_wr <= '0;
        end else if(w_en) begin
            ptr_wr <= ptr_wr + 1'b1;
        end
    end

    //! Post trigger counter
    always_ff @(posedge i_wr_clk or negedge i_wr_rst_n) begin
        if(!i_wr_rst_n) begin
            post_tr_cnt_r <= '0;
        end else if(i_arm) begin
            post_tr_cnt_r <= '0;
        end else if (state_next == CAPTURING) begin
            post_tr_cnt_r <= post_tr_cnt_r + 1'b1;
        end
    end

    assign done_wr = (state_r == DONE);

    sync_level #(
        .PIPE(3)
    ) u_sync_done (
        .o_data(done_rd),
        .i_data(done_wr),
        .i_rst_n(i_rd_rst_n),
        .i_clk(i_rd_clk)
    );

    //! Read Mem
    always_ff @(posedge i_rd_clk or negedge i_rd_rst_n) begin
        if (!i_rd_rst_n) begin
            o_data     <= '0;
            o_ptr      <= '0;
            o_rd_valid <= '0;
            o_done     <= '0;
        end else begin
            o_rd_valid <= i_rd_en && done_rd;

            if(i_rd_en && done_rd)
                o_data <= mem[i_rdaddr];

            if(done_rd)
                o_ptr <= ptr_wr;

            o_done <= done_rd;
        end
    end

endmodule
