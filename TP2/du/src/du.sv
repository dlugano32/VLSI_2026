`timescale 1ps/1ps

module du #(
    parameter  int WIDTH  = 12,
    parameter  int DEPTH  = 1024, //! Debe ser siempre potencia de dos
    localparam int ADDR_W = $clog2(DEPTH)
) (
    input  logic                   i_arm, // Pulse synced from CPU
    input  logic                   i_trigger,
    input  logic [          1 : 0] i_mode,
    input  logic [WIDTH   - 1 : 0] i_data,
    input  logic                   i_clk,
    input  logic                   i_rst_n,

    input  logic [ADDR_W  - 1 : 0] i_rdaddr,

    output logic [WIDTH  - 1 : 0]  o_data,
    output logic [ADDR_W - 1 : 0]  o_ptr,
    output logic                   o_done
);

    logic [WIDTH  - 1 : 0] mem [DEPTH - 1 : 0];
    logic [ADDR_W - 1 : 0] ptr_wr;
    
    logic [ADDR_W - 1 : 0] target;
    logic [ADDR_W - 1 : 0] post_tr_cnt_r;
    
    logic w_en;
    logic capture_done;
    
    typedef enum bit [1:0] {PRE, MID, POST} mode_e;
    typedef enum bit [1:0] {IDLE, RUN, CAPTURING, DONE} state_e;
    
    state_e state_r;
    state_e state_next;

    mode_e mode_r;

    always_ff @(posedge i_clk) begin
        if(!i_rst_n) begin
            mode_r <= MID;
        end else if(i_arm) begin    //! Dado que el modo proviene del regmap, desde otro dominio de clock. Primero se deja estable el modo y luego se da la señal de arm
            case(i_mode)
                PRE, MID, POST : mode_r <= i_mode;
                default : mode_r <= MID; //! En caso de que la entrada tome un valor prohibido
            endcase
        end
    end

    //! FSM
    always_ff @(posedge i_clk) begin
        if(!i_rst_n) begin
            state_r <= IDLE;
        end else begin
            state_r <= state_next;
        end
    end

    //! Next state logic
    always_comb begin
        state_next = state_r;
        case(state_r)
            IDLE : begin
                if(i_arm) begin
                    state_next = RUN;
                end
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
                if(i_arm) begin
                    state_next = RUN;
                end
            end

            default: state_next = IDLE;
        endcase
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
    always_ff @(posedge i_clk) begin
        if (w_en) begin
            mem[ptr_wr]<=i_data;
        end
    end

    //! Write pointer
    always_ff @(posedge i_clk) begin
        if(!i_rst_n) begin
            ptr_wr <= '0;
        end else if(w_en) begin
            ptr_wr <= ptr_wr + 1'b1;
        end else if(i_arm) begin
            ptr_wr <= '0;
        end
    end

    //! Post trigger counter
    always_ff @(posedge i_clk) begin
        if(!i_rst_n) begin
            post_tr_cnt_r <= '0;
        end else if (state_next == CAPTURING) begin
            post_tr_cnt_r <= post_tr_cnt_r + 1'b1;
        end else if(i_arm) begin
            post_tr_cnt_r <= '0;
        end
    end

    //! Read Mem
    //! TODO: Entiendo que se puede hacer de forma combinacional porque el dato va a estar estable
    //! Sin embargo me surge la duda si en terminos de recursos lo que infiere, que sería
    //! un banco de registros y un mux grande, para la lectura es mas o menos eficiente que una 
    //! lectura como si fuera una bram sincrónica
    always_comb begin
        if(state_r == DONE)
            o_data = mem[i_rdaddr];
        else
            o_data = '0;
    end
    
    assign o_ptr =  (state_r == DONE) ? ptr_wr : '0;
    assign o_done = (state_r == DONE); //! Synced to CPU

endmodule;