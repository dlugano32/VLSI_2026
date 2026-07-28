module regmap # ( 
    //! Bus
    parameter int W_ADDR = 8,
    parameter int W_DATA = 32,

    //! Fir filter
    parameter int NB_COEFF = 12,
    parameter int N_TAPS = 19,

    //!DU (TODO: Revisar valores)
    parameter int NB_SAMPLE = 8,
    parameter int DU_W_ADDR = 8,

    //! Clock Measurement
    parameter int WIN_W = 19,
    parameter int CNT_W = 20
) (
    input  logic clk,
    input  logic rst_n,

    //! Bus
    input  logic [W_ADDR - 1 : 0] addr,
    input  logic [W_DATA - 1 : 0] wdata,
    input  logic                  req,
    input  logic                  is_write,
    output logic [W_DATA - 1 : 0] rdata,
    output logic                  ack,

    //! PRBS configuration
    output logic          o_prbs_enable,
    output logic [2  : 0] o_prbs_order_sel,
    output logic [14 : 0] o_prbs_seed,

    //! Fir configuration
    output logic signed [NB_COEFF - 1 : 0] o_fir_taps [(N_TAPS+1)/2 - 1 : 0],

    //! DU configuration
    output logic o_du_arm,
    output logic o_du_rearm,
    output logic [NB_SAMPLE - 1 : 0] o_du_threshold,
    output logic [DU_W_ADDR - 1 : 0] o_du_rdaddr,

    //! DU status
    input  logic                     i_du_status,
    input  logic [NB_SAMPLE - 1 : 0] i_du_rddata,
    
    //! Clk Meas configuration
    output logic [WIN_W - 1 : 0] o_clkmeas_window,
    input  logic [CNT_W - 1 : 0] i_clkmeas_count,
    input  logic                 i_clkmeas_status,

    //! General purpose control flags
    output logic [15 : 0] o_ctrl_flags
);

    //! === Regmap addr ===
    // PRBS
    localparam logic [W_ADDR - 1 : 0] ADDR_PRBS_CTRL      = 8'h00;
    localparam logic [W_ADDR - 1 : 0] ADDR_PRBS_SEED      = 8'h01;

    // FIR (TODO : Revisar si conviene poner dos taps por addr)
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

    // DU
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_CTRL        = 8'h20;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_THRESHOLD   = 8'h21;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_STATUS      = 8'h22;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_RDADDR      = 8'h23;
    localparam logic [W_ADDR - 1 : 0] ADDR_DU_RDDATA      = 8'h24;

    // Clk Meas
    localparam logic [W_ADDR - 1 : 0] ADDR_CLKMEAS_WINDOW = 8'h30;
    localparam logic [W_ADDR - 1 : 0] ADDR_CLKMEAS_COUNT  = 8'h31;
    localparam logic [W_ADDR - 1 : 0] ADDR_CLKMEAS_STATUS = 8'h32;

    // General-purpose control flags
    localparam logic [W_ADDR - 1 : 0] ADDR_CTRL_FLAG      = 8'h40;


    //! === Vars ===
    logic [W_DATA - 1 : 0] rdata_r;
    logic [W_DATA - 1 : 0] rdata_next;
    logic                  ack_r;

    //! === Regmap ===
    // PRBS
    logic          prbs_enable_r;
    logic [2  : 0] prbs_order_sel_r;
    logic [14 : 0] prbs_seed_r;

    // FIR
    logic signed [NB_COEFF - 1 : 0] fir_taps_r [(N_TAPS+1)/2 - 1 : 0];

    // DU 
    logic  du_arm_r;
    logic  du_rearm_r;
    logic [NB_SAMPLE - 1 : 0] du_threshold_r;
    logic                     du_status_r;
    logic [DU_W_ADDR - 1 : 0] du_rdaddr_r;
    
    // Clkl Meas
    logic [WIN_W - 1 : 0] clkmeas_window_r;
    logic                 clkmeas_status_r;

    // General purpose flags
    logic [15 : 0] ctrl_flags_r;

    genvar i;

    //! Logica secuencial del regmap
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            ack_r   <= '0;
            rdata_r <= '0;

            // Inicialización de registros
            prbs_enable_r    <= '0;
            prbs_order_sel_r <= '0;
            prbs_seed_r      <= '1;

            du_arm_r         <= '0;
            du_rearm_r       <= '0;
            du_threshold_r   <= '0;
            du_status_r      <= '0;
            du_rdaddr_r      <= '0;

            clkmeas_window_r <= '0;
            clkmeas_status_r <= '0;

            ctrl_flags_r     <= '0;

            for (i = 0; i < (N_TAPS + 1) / 2; i++) begin
                fir_taps_r[i] <= '0;
            end

        end else begin
            ack_r   <= req; // Ack sigue a req un ciclo de clk despues

            du_rearm_r <= 1'b0; // Pulse

            if (i_clkmeas_status) begin // Sticky bit
                clkmeas_status_r <= 1'b1;
            end else if (req && !is_write && addr == ADDR_CLKMEAS_STATUS) begin
                clkmeas_status_r <= 1'b0;
            end

            if (i_du_status) begin // Sticky bit
                du_status_r <= 1'b1;
            end else if (req && !is_write && addr == ADDR_DU_STATUS) begin
                du_status_r <= 1'b0;
            end
            
            
            if(req) begin
                if(is_write) begin  // Write registers
                    case (addr)
                        ADDR_PRBS_CTRL: begin
                            prbs_enable_r    <= wdata[0];
                            prbs_order_sel_r <= wdata[3 : 1];
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
                        
                        ADDR_DU_CTRL: begin
                            du_arm_r   <= wdata[0];
                            du_rearm_r <= wdata[1];
                        end

                        ADDR_DU_THRESHOLD: begin
                            du_threshold_r <= wdata[NB_SAMPLE - 1 : 0];
                        end

                        ADDR_DU_RDADDR: begin
                            du_rdaddr_r <= wdata[DU_W_ADDR - 1 : 0];
                        end

                        ADDR_CLKMEAS_WINDOW: begin
                            clkmeas_window_r <= wdata[WIN_W - 1 : 0];
                        end

                        ADDR_CTRL_FLAG: begin
                            ctrl_flags_r <= wdata[15 : 0];
                        end

                        default: begin
                            // Invalid or RO address: ignore write.
                        end
                    endcase
                end else begin // Read registers
                    rdata_r <= rdata_next;
                end
            end
        end
    end

    //! Logica combinacional del regmap
    always_comb begin   //Read registers
        rdata_next = '0;    // Default value
        
        case (addr)

            ADDR_PRBS_CTRL: begin
                rdata_next[0]     = prbs_enable_r;
                rdata_next[3 : 1] = prbs_order_sel_r;
            end

            ADDR_PRBS_SEED: begin
                rdata_next[14 : 0 ] = prbs_seed_r;
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

            ADDR_DU_CTRL: begin
                rdata_next[0] = du_arm_r;
                rdata_next[1] = du_rearm_r;
            end
            
            ADDR_DU_THRESHOLD: begin
                rdata_next[NB_SAMPLE - 1 : 0] = du_threshold_r;
            end

            ADDR_DU_STATUS: begin
                rdata_next[0] = du_status_r;
            end

            ADDR_DU_RDADDR: begin
                rdata_next[DU_W_ADDR - 1 : 0] = du_rdaddr_r;
            end

            ADDR_DU_RDDATA: begin
                rdata_next [NB_SAMPLE - 1 : 0] = i_du_rddata;
            end

            ADDR_CLKMEAS_WINDOW: begin
                rdata_next [WIN_W - 1 : 0] = clkmeas_window_r;
            end

            ADDR_CLKMEAS_COUNT: begin
                rdata_next [CNT_W - 1 : 0] = i_clkmeas_count;
            end

            ADDR_CLKMEAS_STATUS: begin
                rdata_next[0] = clkmeas_status_r;
            end

            ADDR_CTRL_FLAG: begin
                rdata_next[15 : 0] = ctrl_flags_r;
            end

            default: begin
                rdata_next = '0;
            end
        endcase
    end

    //! Asignación de registros a salidas
    assign ack = ack_r;
    assign rdata = rdata_r;

    assign o_prbs_enable    = prbs_enable_r;
    assign o_prbs_order_sel = prbs_order_sel_r;
    assign o_prbs_seed      = prbs_seed_r;
    assign o_fir_taps       = fir_taps_r;
    assign o_du_arm         = du_arm_r;
    assign o_du_rearm       = du_rearm_r;
    assign o_du_threshold = du_threshold_r;
    assign o_du_rdaddr      = du_rdaddr_r;
    assign o_clkmeas_window = clkmeas_window_r;
    assign o_ctrl_flags     = ctrl_flags_r;
endmodule