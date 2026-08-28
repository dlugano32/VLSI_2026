`timescale 1ps/1ps

module top #(
    parameter int W_ADDR = 8,
    parameter int W_DATA = 32
) (
    input  logic                i_clk_cpu,
    input  logic                i_clk_dsp,
    input  logic                i_arst_n,

    input  logic [W_ADDR-1 : 0] i_addr,
    input  logic [W_DATA-1 : 0] i_wdata,
    input  logic                i_req,
    input  logic                i_is_write,
    output logic [W_DATA-1 : 0] o_rdata,
    output logic                o_ack
);

    //==========================================================================
    // Local parameters
    //==========================================================================
    localparam int PRBS_ORDER_W = 3;
    localparam int PRBS_SEED_W  = 15;
    localparam int P            = 4;

    localparam int FIR_N_TAPS   = 19;
    localparam int FIR_N_COEFFS = (FIR_N_TAPS + 1) / 2;

    localparam int FIR_COEFF_W    = 12;
    localparam int FIR_COEFF_FRAC = 10;

    localparam int FIR_SAMPLE_W    = 12;
    localparam int FIR_SAMPLE_FRAC = 10;

    localparam int DU_DEPTH  = 256;
    localparam int DU_W_ADDR = $clog2(DU_DEPTH);

    localparam int WIN_W = 19;
    localparam int CNT_W = 20;

    //==========================================================================
    // CPU-domain
    //==========================================================================
    //! PRBS
    logic                               prbs_start_cpu;
    logic                               prbs_stop_cpu;
    logic        [PRBS_ORDER_W - 1 : 0] prbs_order_sel_cpu;
    logic         [PRBS_SEED_W - 1 : 0] prbs_seed_cpu;
    logic                               prbs_running_cpu;

    //! FIR
    logic signed  [FIR_COEFF_W - 1 : 0] fir_taps_shadow_cpu [FIR_N_COEFFS - 1 : 0];
    logic                               fir_commit_cpu;
    logic                               fir_enable_cpu;
    logic                               fir_busy_cpu;

    //! DU
    logic                               du_arm_cpu;
    logic                               du_rd_en_cpu;
    logic                       [1 : 0] du_mode_cpu;
    logic                       [1 : 0] du_select_cpu;
    logic           [DU_W_ADDR - 1 : 0] du_rdaddr_cpu;
    logic signed [FIR_SAMPLE_W - 1 : 0] du_threshold_cpu;
    logic                       [3 : 0] du_done_cpu;
    logic                               du_rd_valid_cpu;
    logic signed [FIR_SAMPLE_W - 1 : 0] du_rddata_cpu;
    logic           [DU_W_ADDR - 1 : 0] du_rdptr_cpu;
    logic                               du_armed_cpu_r;

    logic                       [P-1:0] du_done_lane;
    logic                               du_rd_en_lane    [P - 1 : 0];
    logic           [DU_W_ADDR - 1 : 0] du_rdaddr_lane   [P - 1 : 0];
    logic signed [FIR_SAMPLE_W - 1 : 0] du_odata_lane    [P - 1 : 0];
    logic                               du_rd_valid_lane [P - 1 : 0];
    logic           [DU_W_ADDR - 1 : 0] du_ptr_lane      [P - 1 : 0];

    //! Frequency meter
    logic               [WIN_W - 1 : 0] clkmeas_window_cpu;
    logic                               clkmeas_start_cpu;
    logic               [CNT_W - 1 : 0] clkmeas_count_cpu;
    logic                               clkmeas_done_cpu;

    //==========================================================================
    // DSP-domain
    //==========================================================================
    //! FIR
    logic signed  [FIR_COEFF_W - 1 : 0] fir_taps_active_dsp [FIR_N_COEFFS - 1 : 0];
    logic signed                [1 : 0] fir_pam2_dsp                   [P - 1 : 0];
    logic signed [FIR_SAMPLE_W - 1 : 0] fir_odata_dsp                  [P - 1 : 0];
    logic fir_enable_dsp;

    //! PRBS
    logic prbs_start_dsp;
    logic prbs_stop_dsp;
    logic prbs_running_dsp;
    logic prbs_bits_dsp [P-1 : 0];

    //! DU
    logic du_arm_dsp;
    logic du_trigger_dsp;
    logic signed [FIR_SAMPLE_W - 1 : 0] du_threshold_dsp;


    //==========================================================================
    // Reset synchronizers
    //==========================================================================
    // i_arst_n asserts both resets asynchronously. Each reset is released only
    // after being synchronized to its corresponding clock domain.

    logic rst_cpu_n;
    logic rst_dsp_n;
    
    rst_n_sync #(
        .PIPE (2)
    ) u_rst_sync_cpu (
        .o_rst_n (rst_cpu_n),
        .i_rst_n (i_arst_n),
        .i_clk   (i_clk_cpu)
    );

    rst_n_sync #(
        .PIPE (2)
    ) u_rst_sync_dsp (
        .o_rst_n (rst_dsp_n),
        .i_rst_n (i_arst_n),
        .i_clk   (i_clk_dsp)
    );

    //==========================================================================
    // CPU-domain register map
    //==========================================================================
    regmap #(
        .W_ADDR    (W_ADDR),
        .W_DATA    (W_DATA),
        .NB_COEFF  (FIR_COEFF_W),
        .NB_SAMPLE (FIR_SAMPLE_W),
        .DU_W_ADDR (DU_W_ADDR),
        .WIN_W     (WIN_W),
        .CNT_W     (CNT_W)
    ) u_regmap (
        .i_clk            (i_clk_cpu),
        .i_rst_n          (rst_cpu_n),
        .i_addr           (i_addr),
        .i_wdata          (i_wdata),
        .i_req            (i_req),
        .i_is_write       (i_is_write),
        .o_rdata          (o_rdata),
        .o_ack            (o_ack),

        .o_prbs_start     (prbs_start_cpu),
        .o_prbs_stop      (prbs_stop_cpu),
        .o_prbs_order_sel (prbs_order_sel_cpu),
        .o_prbs_seed      (prbs_seed_cpu),
        .i_prbs_running   (prbs_running_cpu),

        .o_fir_taps       (fir_taps_shadow_cpu),
        .o_fir_commit     (fir_commit_cpu),
        .o_fir_enable     (fir_enable_cpu),
        .i_fir_busy       (fir_busy_cpu),

        .o_du_arm         (du_arm_cpu),
        .o_du_rd_en       (du_rd_en_cpu),
        .o_du_mode        (du_mode_cpu),
        .o_du_select      (du_select_cpu),
        .o_du_rdaddr      (du_rdaddr_cpu),
        .o_du_threshold   (du_threshold_cpu),
        .i_du_status      (du_done_cpu),
        .i_du_rd_valid    (du_rd_valid_cpu),
        .i_du_rddata      (du_rddata_cpu),
        .i_du_rdptr       (du_rdptr_cpu),

        .o_clkmeas_window (clkmeas_window_cpu),
        .o_clkmeas_start  (clkmeas_start_cpu),
        .i_clkmeas_count  (clkmeas_count_cpu),
        .i_clkmeas_status (clkmeas_done_cpu)
    );

    //==========================================================================
    // PRBS
    //==========================================================================
    sync_pulse #(
        .PIPE (3)
    ) u_prbs_start_cdc (
        .o_pulse (prbs_start_dsp),
        .i_pulse (prbs_start_cpu),
        .i_rst_n (rst_dsp_n),
        .i_clk   (i_clk_dsp)
    );

    sync_pulse #(
        .PIPE (3)
    ) u_prbs_stop_cdc (
        .o_pulse (prbs_stop_dsp),
        .i_pulse (prbs_stop_cpu),
        .i_rst_n (rst_dsp_n),
        .i_clk   (i_clk_dsp)
    );

    sync_level #(
        .PIPE (3)
    ) u_prbs_running_cdc (
        .o_data  (prbs_running_cpu),
        .i_data  (prbs_running_dsp),
        .i_rst_n (rst_cpu_n),
        .i_clk   (i_clk_cpu)
    );

    // prbs_parallel captures seed and order internally when start_dsp is high.
    prbs_parallel u_prbs_4 (
        .o_prbs    (prbs_bits_dsp),
        .o_running (prbs_running_dsp),
        .i_clk     (i_clk_dsp),
        .i_rst_n   (rst_dsp_n),
        .i_start   (prbs_start_dsp),
        .i_stop    (prbs_stop_dsp),
        .i_sel     (prbs_order_sel_cpu),
        .i_seed    (prbs_seed_cpu)
    );

    prbs_to_pam2 #(
        .P (P)
    ) u_prbs_to_pam2(
        .i_prbs_bits (prbs_bits_dsp),
        .o_pam2      (fir_pam2_dsp)
    );

    //==========================================================================
    // FIR Filter
    //==========================================================================

    sync_level #(
        .PIPE (3)
    ) u_fir_enable_cdc (
        .o_data  (fir_enable_dsp),
        .i_data  (fir_enable_cpu),
        .i_rst_n (rst_dsp_n),
        .i_clk   (i_clk_dsp)
    );

    coeff_handshake #(
        .N_COEFFS (FIR_N_COEFFS),
        .NB_COEFF (FIR_COEFF_W)
    ) u_fir_coeff_handshake (
        .i_clk_cpu         (i_clk_cpu),
        .i_rst_cpu_n       (rst_cpu_n),
        .i_commit_cpu      (fir_commit_cpu),
        .i_taps_shadow_cpu (fir_taps_shadow_cpu),
        .o_busy_cpu        (fir_busy_cpu),

        .i_clk_dsp         (i_clk_dsp),
        .i_rst_dsp_n       (rst_dsp_n),
        .o_taps_active_dsp (fir_taps_active_dsp)
    );

    fir_parallel #(
        .NB_O     (FIR_SAMPLE_W),
        .NBF_O    (FIR_SAMPLE_FRAC),
        .NB_TAPS  (FIR_COEFF_W),
        .NBF_TAPS (FIR_COEFF_FRAC),
        .N_TAPS   (FIR_N_TAPS),
        .P        (P)
    ) u_fir_parallel (
        .o_data  (fir_odata_dsp),
        .i_data  (fir_pam2_dsp),
        .i_taps  (fir_taps_active_dsp),
        .i_en    (fir_enable_dsp),
        .i_rst_n (rst_dsp_n),
        .i_clk   (i_clk_dsp)
    );

    //==========================================================================
    // DU
    //==========================================================================
    sync_pulse #(
        .PIPE (3)
    ) u_arm_sync (
        .o_pulse (du_arm_dsp),
        .i_pulse (du_arm_cpu),
        .i_rst_n (rst_dsp_n),
        .i_clk   (i_clk_dsp)
    );

    //! DU threshold
    always_ff @(posedge i_clk_dsp or negedge rst_dsp_n) begin
        if(!rst_dsp_n) begin
            du_threshold_dsp <= '0;
        end else begin
            if(du_arm_dsp)
                du_threshold_dsp <= du_threshold_cpu;
        end
    end

    assign du_trigger_dsp =
        (fir_odata_dsp[0] >= du_threshold_dsp) ||
        (fir_odata_dsp[1] >= du_threshold_dsp) ||
        (fir_odata_dsp[2] >= du_threshold_dsp) ||
        (fir_odata_dsp[3] >= du_threshold_dsp);

    //! DU to Regmap - Mux
    always_comb begin
        du_rddata_cpu   = '0;
        du_rd_valid_cpu = '0;
        du_rdptr_cpu    = '0;

        case (du_select_cpu)
            2'b00: begin
                du_rddata_cpu   = du_odata_lane    [0];
                du_rd_valid_cpu = du_rd_valid_lane [0];
                du_rdptr_cpu    = du_ptr_lane      [0];
            end

            2'b01: begin
                du_rddata_cpu   = du_odata_lane    [1];
                du_rd_valid_cpu = du_rd_valid_lane [1];
                du_rdptr_cpu    = du_ptr_lane      [1];
            end

            2'b10: begin
                du_rddata_cpu   = du_odata_lane    [2];
                du_rd_valid_cpu = du_rd_valid_lane [2];
                du_rdptr_cpu    = du_ptr_lane      [2];
            end

            2'b11: begin
                du_rddata_cpu   = du_odata_lane    [3];
                du_rd_valid_cpu = du_rd_valid_lane [3];
                du_rdptr_cpu    = du_ptr_lane      [3];
            end
        endcase
    end

    genvar i;
    generate
        for(i = 0; i<P ; i++) begin : gen_du_lane
            assign du_rdaddr_lane[i] = du_rdaddr_cpu;
            assign du_rd_en_lane[i]  = du_rd_en_cpu && (du_select_cpu == i);

            du #(
                .WIDTH(FIR_SAMPLE_W),
                .DEPTH(DU_DEPTH)
            ) u_du_parallel (
                // DSP domain
                .i_wr_clk   (i_clk_dsp),
                .i_wr_rst_n (rst_dsp_n),
                .i_arm      (du_arm_dsp),
                .i_trigger  (du_trigger_dsp),
                .i_data     (fir_odata_dsp[i]),

                // CPU domain
                .i_rd_clk   (i_clk_cpu),
                .i_rd_rst_n (rst_cpu_n),
                .i_mode     (du_mode_cpu),  // Bundled-data when du is armed
                .i_rd_en    (du_rd_en_lane[i]),
                .i_rdaddr   (du_rdaddr_lane[i]),

                .o_data     (du_odata_lane[i]),
                .o_rd_valid (du_rd_valid_lane[i]),
                .o_ptr      (du_ptr_lane[i]),
                .o_done     (du_done_lane[i])
            );

            assign du_done_cpu [i] = du_done_lane[i] && !du_armed_cpu_r && !du_arm_cpu;
        end
    endgenerate

    always_ff @(posedge i_clk_cpu or negedge rst_cpu_n) begin
        if(!rst_cpu_n) begin
            du_armed_cpu_r <= '0;
        end else if (du_arm_cpu) begin
            du_armed_cpu_r <= 1'b1;
        end else if (!(|du_done_lane))
            du_armed_cpu_r <= '0;
    end

    //==========================================================================
    // Frequency measurement
    //==========================================================================
    freq_meas #(
        .WIN_W(WIN_W),
        .CNT_W(CNT_W)
    ) u_freq_meas (
        .o_count      (clkmeas_count_cpu),
        .o_done       (clkmeas_done_cpu),
        .i_window_len (clkmeas_window_cpu),
        .i_start      (clkmeas_start_cpu),
        .i_rst_ref_n  (rst_cpu_n),
        .i_rst_in_n   (rst_dsp_n),
        .i_clk_ref    (i_clk_cpu),
        .i_clk_in     (i_clk_dsp)
    );

endmodule
