`timescale 1ns/1ps

module regmap # ( 
    //! Bus
    parameter int W_ADDR = 8,
    parameter int W_DATA = 32,

    //! Fir filter
    parameter  int NB_COEFF = 12,
    localparam int N_TAPS = 19,

    //!DU
    parameter int NB_SAMPLE = 12,
    parameter int DU_W_ADDR = 10,

    //! Clock Measurement
    parameter int WIN_W = 19,
    parameter int CNT_W = 20
) (
    input  logic i_clk,
    input  logic i_rst_n,

    //! Bus
    input  logic           [W_ADDR - 1 : 0] addr,
    input  logic           [W_DATA - 1 : 0] wdata,
    input  logic                            req,
    input  logic                            is_write,
    output logic           [W_DATA - 1 : 0] rdata,
    output logic                            ack,

    //! PRBS configuration
    output logic                            o_prbs_start,
    output logic                            o_prbs_stop,
    output logic                   [2  : 0] o_prbs_order_sel,
    output logic                   [14 : 0] o_prbs_seed,
    input  logic                            i_prbs_running,

    //! Fir configuration
    output logic signed  [NB_COEFF - 1 : 0] o_fir_taps [(N_TAPS+1)/2 - 1 : 0],
    output logic                            o_fir_commit,
    input  logic                            i_fir_busy,

    //! DU configuration
    output logic                            o_du_arm,
    output logic                            o_du_rd_en,
    output logic                    [1 : 0] o_du_mode,
    output logic                    [1 : 0] o_du_select,
    output logic        [DU_W_ADDR - 1 : 0] o_du_rdaddr,
    output logic signed [NB_SAMPLE - 1 : 0] o_du_threshold,

    //! DU status
    input logic                     [3 : 0] i_du_status,
    input logic                             i_du_rd_valid,
    input logic signed  [NB_SAMPLE - 1 : 0] i_du_rddata,
    input logic         [DU_W_ADDR - 1 : 0] i_du_rdptr,
    
    //! Clk Meas configuration
    output logic            [WIN_W - 1 : 0] o_clkmeas_window,
    output logic                            o_clkmeas_start,
    input  logic            [CNT_W - 1 : 0] i_clkmeas_count,
    input  logic                            i_clkmeas_status

);

    //! === Regmap addr ===
    // PRBS
    localparam logic [W_ADDR - 1 : 0] ADDR_PRBS_CTRL      = 8'h00;
    localparam logic [W_ADDR - 1 : 0] ADDR_PRBS_SEED      = 8'h01;
    localparam logic [W_ADDR - 1 : 0] ADDR_PRBS_STATUS    = 8'h02;

    // FIR
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_0      = 8'h10;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_1      = 8'h11;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_2      = 8'h12;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_3      = 8'h13;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_4      = 8'h14;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_5      = 8'h15;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_6      = 8'h16;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_7      = 8'h17;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_8      = 8'h18;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_TAP_9      = 8'h19;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_CTRL       = 8'h1A;
    localparam logic [W_ADDR - 1 : 0] ADDR_FIR_STATUS     = 8'h1B;

    // DU
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_CTRL        = 8'h20;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_THRESHOLD   = 8'h21;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_STATUS      = 8'h22;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_RDADDR      = 8'h23;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_RDDATA      = 8'h24;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_RDPTR       = 8'h25;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_SELECT      = 8'h26;

    // Clk Meas
    localparam logic [W_ADDR - 1 : 0] ADDR_CLKMEAS_CTRL   = 8'h30;
    localparam logic [W_ADDR - 1 : 0] ADDR_CLKMEAS_WINDOW = 8'h31;
    localparam logic [W_ADDR - 1 : 0] ADDR_CLKMEAS_COUNT  = 8'h32;
    localparam logic [W_ADDR - 1 : 0] ADDR_CLKMEAS_STATUS = 8'h33;

    //! === Vars ===
    logic           [W_DATA - 1 : 0] rdata_r;
    logic           [W_DATA - 1 : 0] rdata_next;
    logic                            ack_r;

    //! === Regmap ===
    // PRBS
    logic                            prbs_start_r;
    logic                            prbs_stop_r;
    logic                   [2  : 0] prbs_order_sel_r;
    logic                   [14 : 0] prbs_seed_r;

    // FIR
    logic signed  [NB_COEFF - 1 : 0] fir_taps_r [(N_TAPS+1)/2 - 1 : 0];
    logic                            fir_commit_r;

    // DU
    logic                            du_arm_r;
    logic                    [1 : 0] du_mode_r;
    logic signed [NB_SAMPLE - 1 : 0] du_threshold_r;
    logic                    [1 : 0] du_select_r;
    logic        [DU_W_ADDR - 1 : 0] du_rdaddr_r;
    logic                            du_read_pending_r;
    
    // Clk Meas
    logic                            clkmeas_start_r;
    logic            [WIN_W - 1 : 0] clkmeas_window_r;

    //! Logica secuencial del regmap
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            ack_r   <= '0;
            rdata_r <= '0;

            // Inicialización de registros
            prbs_start_r     <= '0;
            prbs_stop_r      <= '0;
            prbs_order_sel_r <= '0;
            prbs_seed_r      <= '0;

            for(integer i = 0; i< (N_TAPS+1)/2; i++)
                fir_taps_r[i] <= '0;

            fir_commit_r <= '0;

            du_arm_r          <= '0;
            du_mode_r         <= '0;
            du_threshold_r    <= '0;
            du_select_r       <= '0;
            du_rdaddr_r       <= '0;
            du_read_pending_r <= '0;

            clkmeas_start_r  <= '0;
            clkmeas_window_r <= '0;
        end else begin
            ack_r           <= 1'b0; // Pulse
            prbs_start_r    <= 1'b0; // Pulse
            prbs_stop_r     <= 1'b0; // Pulse
            fir_commit_r    <= 1'b0; // Pulse
            du_arm_r        <= 1'b0; // Pulse
            clkmeas_start_r <= 1'b0; // Pulse

            // La lectura de memoria de la DU es la unica transaccion con latencia, por ser una lectura sincronica.
            // Mientras esta pendiente no se aceptan nuevas solicitudes.
            if (du_read_pending_r) begin
                if (i_du_rd_valid) begin
                    rdata_r <= {{(W_DATA - NB_SAMPLE){i_du_rddata[NB_SAMPLE - 1]}},i_du_rddata}; // Extension de signo
                    ack_r <= 1'b1;
                    du_read_pending_r <= 1'b0;
                end
            end else if(req) begin
                if(is_write) begin  // Write registers
                    ack_r <= 1'b1;

                    case (addr)
                        ADDR_PRBS_CTRL: begin
                            prbs_start_r     <= wdata[0];
                            prbs_stop_r      <= wdata[1];
                            prbs_order_sel_r <= wdata[4 : 2];
                        end

                        ADDR_PRBS_SEED: begin
                            prbs_seed_r <= wdata[14 : 0];
                        end

                        ADDR_FIR_TAP_0: begin
                            fir_taps_r[0] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_TAP_1: begin
                            fir_taps_r[1] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_TAP_2: begin
                            fir_taps_r[2] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_TAP_3: begin
                            fir_taps_r[3] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_TAP_4: begin
                            fir_taps_r[4] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_TAP_5: begin
                            fir_taps_r[5] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_TAP_6: begin
                            fir_taps_r[6] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_TAP_7: begin
                            fir_taps_r[7] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_TAP_8: begin
                            fir_taps_r[8] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_TAP_9: begin
                            fir_taps_r[9] <= $signed(wdata[NB_COEFF - 1 : 0]);
                        end

                        ADDR_FIR_CTRL: begin
                            fir_commit_r <= wdata[0];
                        end
                        
                        ADDR_DU_CTRL: begin
                            du_arm_r   <= wdata[0];
                            du_mode_r  <= wdata[2:1];
                        end

                        ADDR_DU_THRESHOLD: begin
                            du_threshold_r <= wdata[NB_SAMPLE - 1 : 0];
                        end

                        ADDR_DU_RDADDR: begin
                            du_rdaddr_r <= wdata[DU_W_ADDR - 1 : 0];
                        end

                        ADDR_DU_SELECT: begin
                            du_select_r <= wdata[1 : 0];
                        end

                        ADDR_CLKMEAS_CTRL: begin
                            clkmeas_start_r <= wdata[0];
                        end

                        ADDR_CLKMEAS_WINDOW: begin
                            clkmeas_window_r <= wdata[WIN_W - 1 : 0];
                        end

                        default: begin
                            // Invalid or RO address: ignore write.
                        end
                    endcase
                end else if (addr == ADDR_DU_RDDATA) begin
                    du_read_pending_r <= 1'b1;
                end else begin // Read registers
                    rdata_r <= rdata_next;
                    ack_r <= 1'b1;
                end
            end
        end
    end

    //! Logica combinacional del regmap
    always_comb begin   //Read registers
        rdata_next = '0;    // Default value
        
        case (addr)

            ADDR_PRBS_CTRL: begin
                rdata_next[0]     = 1'b0; // START pulse (WO)
                rdata_next[1]     = 1'b0; // STOP pulse (WO)
                rdata_next[4 : 2] = prbs_order_sel_r;
            end

            ADDR_PRBS_SEED: begin
                rdata_next[14 : 0 ] = prbs_seed_r;
            end

            ADDR_PRBS_STATUS: begin
                rdata_next[0] = i_prbs_running;
            end

            ADDR_FIR_TAP_0: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[0][NB_COEFF - 1]}},
                    fir_taps_r[0]
                };
            end

            ADDR_FIR_TAP_1: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[1][NB_COEFF - 1]}},
                    fir_taps_r[1]
                };            
            end

            ADDR_FIR_TAP_2: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[2][NB_COEFF - 1]}},
                    fir_taps_r[2]
                };
            end

            ADDR_FIR_TAP_3: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[3][NB_COEFF - 1]}},
                    fir_taps_r[3]
                };
            end

            ADDR_FIR_TAP_4: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[4][NB_COEFF - 1]}},
                    fir_taps_r[4]
                };
            end

            ADDR_FIR_TAP_5: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[5][NB_COEFF - 1]}},
                    fir_taps_r[5]
                };
            end

            ADDR_FIR_TAP_6: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[6][NB_COEFF - 1]}},
                    fir_taps_r[6]
                };
            end

            ADDR_FIR_TAP_7: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[7][NB_COEFF - 1]}},
                    fir_taps_r[7]
                };
            end

            ADDR_FIR_TAP_8: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[8][NB_COEFF - 1]}},
                    fir_taps_r[8]
                };
            end

            ADDR_FIR_TAP_9: begin
                rdata_next = {
                    {(W_DATA - NB_COEFF){fir_taps_r[9][NB_COEFF - 1]}},
                    fir_taps_r[9]
                };
            end

            ADDR_FIR_CTRL: begin
                rdata_next[0] = 1'b0; // COMMIT pulse (WO)
            end

            ADDR_FIR_STATUS: begin
                rdata_next[0] = i_fir_busy;
            end

            ADDR_DU_CTRL: begin
                rdata_next[0]   = 1'b0;     // Pulso (WO)
                rdata_next[2:1] = du_mode_r;
            end
            
            ADDR_DU_THRESHOLD: begin
                rdata_next = {{(W_DATA - NB_SAMPLE){du_threshold_r[NB_SAMPLE - 1]}}, du_threshold_r};
            end

            ADDR_DU_STATUS: begin
                rdata_next[3 : 0] = i_du_status;
            end

            ADDR_DU_RDADDR: begin
                rdata_next[DU_W_ADDR - 1 : 0] = du_rdaddr_r;
            end

            ADDR_DU_RDDATA: begin
                rdata_next = {{(W_DATA - NB_SAMPLE){i_du_rddata[NB_SAMPLE - 1]}}, i_du_rddata};
            end

            ADDR_DU_RDPTR: begin
                rdata_next[DU_W_ADDR - 1 : 0] = i_du_rdptr;
            end

            ADDR_DU_SELECT: begin
                rdata_next[1 : 0] = du_select_r;
            end

            ADDR_CLKMEAS_CTRL: begin
                rdata_next[0] = 1'b0; //Pulso clkmeas_start (WO)
            end

            ADDR_CLKMEAS_WINDOW: begin
                rdata_next [WIN_W - 1 : 0] = clkmeas_window_r;
            end

            ADDR_CLKMEAS_COUNT: begin
                rdata_next [CNT_W - 1 : 0] = i_clkmeas_count;
            end

            ADDR_CLKMEAS_STATUS: begin
                rdata_next[0] = i_clkmeas_status;
            end

            default: begin
                rdata_next = '0;
            end
        endcase
    end

    //! Asignación de registros a salidas
    assign ack = ack_r;
    assign rdata = rdata_r;

    assign o_prbs_start     = prbs_start_r;
    assign o_prbs_stop      = prbs_stop_r;
    assign o_prbs_order_sel = prbs_order_sel_r;
    assign o_prbs_seed      = prbs_seed_r;
    assign o_fir_taps       = fir_taps_r;
    assign o_fir_commit     = fir_commit_r;
    assign o_du_arm         = du_arm_r;
    assign o_du_mode        = du_mode_r;
    assign o_du_select      = du_select_r;
    assign o_du_threshold   = du_threshold_r;
    assign o_du_rdaddr      = du_rdaddr_r;
    assign o_du_rd_en       = req && !is_write && (addr == ADDR_DU_RDDATA) && !du_read_pending_r;
    assign o_clkmeas_window = clkmeas_window_r;
    assign o_clkmeas_start  = clkmeas_start_r;

endmodule
