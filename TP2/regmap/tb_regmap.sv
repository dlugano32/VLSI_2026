`timescale 1ns/1ps

module tb_regmap ();

    localparam time CLK_PERIOD = 4ns;

    //! === DUT parameters ===
    //! Bus
    localparam int W_ADDR = 8;
    localparam int W_DATA = 32;

    //! Fir filter
    localparam int NB_COEFF = 12;
    localparam int N_TAPS = 19;

    //!DU
    localparam int NB_SAMPLE = 8;
    localparam int DU_W_ADDR = 8;

    //! Clock Measurement
    localparam int WIN_W = 19;
    localparam int CNT_W = 20;

    //! === DUT inputs/outputs ===
    logic clk;
    logic rst_n;

    //! Bus
    logic [W_ADDR - 1 : 0] addr;
    logic [W_DATA - 1 : 0] wdata;
    logic                  req;
    logic                  is_write;
    logic [W_DATA - 1 : 0] rdata;
    logic                  ack;

    //! PRBS configuration
    logic          o_prbs_enable;
    logic [2  : 0] o_prbs_order_sel;
    logic [14 : 0] o_prbs_seed;

    //! Fir configuration
    logic signed [NB_COEFF - 1 : 0] o_fir_taps [(N_TAPS+1)/2 - 1 : 0];

    //! DU configuration
    logic o_du_arm;
    logic o_du_rearm;
    logic [NB_SAMPLE - 1 : 0] o_du_threshold;
    logic [DU_W_ADDR - 1 : 0] o_du_rdaddr;

    //! DU status
    logic                     i_du_status;
    logic [NB_SAMPLE - 1 : 0] i_du_rddata;
    
    //! Clk Meas configuration
    logic [WIN_W - 1 : 0] o_clkmeas_window;
    logic [CNT_W - 1 : 0] i_clkmeas_count;
    logic                 i_clkmeas_status;

    //! General purpose control flags
    logic [15 : 0] o_ctrl_flags;

    //! === Regmap addr ===
    // PRBS
    localparam logic [W_ADDR - 1 : 0] ADDR_PRBS_CTRL      = 8'h00;
    localparam logic [W_ADDR - 1 : 0] ADDR_PRBS_SEED      = 8'h01;

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

    //! === Clock generator ===
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //! === DUT instantiation ===
    regmap # ( 
        .W_ADDR(W_ADDR),
        .W_DATA(W_DATA),
        .NB_COEFF(NB_COEFF),
        .N_TAPS(N_TAPS),
        .NB_SAMPLE(NB_SAMPLE),
        .DU_W_ADDR(DU_W_ADDR),
        .WIN_W(WIN_W),
        .CNT_W(CNT_W)
    ) u_regmap_dut (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .wdata(wdata),
        .req(req),
        .is_write(is_write),
        .rdata(rdata),
        .ack(ack),
        
        .o_prbs_enable(o_prbs_enable),
        .o_prbs_order_sel(o_prbs_order_sel),
        .o_prbs_seed(o_prbs_seed),
        .o_fir_taps(o_fir_taps),
        .o_du_arm(o_du_arm),
        .o_du_rearm(o_du_rearm),
        .o_du_threshold(o_du_threshold),
        .o_du_rdaddr(o_du_rdaddr),
        .i_du_status(i_du_status),
        .i_du_rddata(i_du_rddata),
        .o_clkmeas_window(o_clkmeas_window),
        .i_clkmeas_count(i_clkmeas_count),
        .i_clkmeas_status(i_clkmeas_status),
        .o_ctrl_flags(o_ctrl_flags)
    );


    //! Waveform generation
    initial begin
        $dumpfile("sim/waves/regmap.vcd");
        $dumpvars(0, tb_regmap);
    end

    initial begin

        // Initial values
        addr             = '0;
        wdata            = '0;
        req              = 1'b0;
        is_write         = 1'b0;

        i_clkmeas_count  = '0;
        i_clkmeas_status = 1'b0;

        i_du_status      = 1'b0;
        i_du_rddata      = '0;

        $display("");
        $display("========================================");
        $display("Regmap Simulation Started");
        $display("========================================");

        rst_n = 1'b0;

        repeat (5) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        repeat (2) @(posedge clk);

        // Test 1: CLKMEAS status sticky bit and count read

        $display("");
        $display("[TEST 1] CLKMEAS status and count read");

        i_clkmeas_count = CNT_W'(1000);

        @(negedge clk);
        i_clkmeas_status = 1'b1;

        @(negedge clk);
        i_clkmeas_status = 1'b0;

        repeat (5) @(posedge clk);

        // Check CLKMEAS_STATUS
        @(negedge clk);
        req      = 1'b1;
        is_write = 1'b0;
        addr     = ADDR_CLKMEAS_STATUS;
        wdata    = '0;

        @(negedge clk);
        req      = 1'b0;
        is_write = 1'b0;
        addr     = '0;

        if (!ack) begin
            $display("[ERROR] CLKMEAS_STATUS read did not generate ACK");
        end else if (rdata[0] !== 1'b1) begin
            $display("[ERROR] CLKMEAS_STATUS not detected. rdata=0x%08h", rdata);
        end else begin
            $display("[PASS] CLKMEAS_STATUS detected");
        end

        // Read CLKMEAS_COUNT.
        @(negedge clk);
        req      = 1'b1;
        is_write = 1'b0;
        addr     = ADDR_CLKMEAS_COUNT;
        wdata    = '0;

        @(negedge clk);
        req      = 1'b0;
        is_write = 1'b0;
        addr     = '0;

        if (!ack) begin
            $display("[ERROR] CLKMEAS_COUNT read did not generate ACK");
        end else begin
            $display("[PASS] CLKMEAS_COUNT correctly read: %0d", rdata[CNT_W - 1 : 0]);
        end

        // Read CLKMEAS_STATUS again.
        // Checking sticky bit logic
        @(negedge clk);
        req      = 1'b1;
        is_write = 1'b0;
        addr     = ADDR_CLKMEAS_STATUS;
        wdata    = '0;

        @(negedge clk);
        req      = 1'b0;
        is_write = 1'b0;
        addr     = '0;

        if (!ack) begin
            $display("[ERROR] Second CLKMEAS_STATUS read did not generate ACK");
        end else if (rdata[0] !== 1'b0) begin
            $display("[ERROR] CLKMEAS_STATUS was not cleared");
        end else begin
            $display("[PASS] CLKMEAS_STATUS cleared after read");
        end

        // Test 2: Write CLKMEAS_WINDOW

        $display("");
        $display("[TEST 2] CLKMEAS_WINDOW write");

        @(negedge clk);
        req      = 1'b1;
        is_write = 1'b1;
        addr     = ADDR_CLKMEAS_WINDOW;
        wdata[WIN_W - 1 : 0] = WIN_W'(250_000);

        @(negedge clk);
        req      = 1'b0;
        is_write = 1'b0;
        addr     = '0;
        wdata    = '0;

        if (!ack) begin
            $display("[ERROR] CLKMEAS_WINDOW write did not generate ACK");
        end else begin
            $display("[PASS] CLKMEAS_WINDOW output correctly updated: %0d", o_clkmeas_window);
        end


        // Test 3: Read CLKMEAS_WINDOW

        $display("");
        $display("[TEST 3] Read CLKMEAS_WINDOW");

        @(negedge clk);
        req      = 1'b1;
        is_write = 1'b0;
        addr     = ADDR_CLKMEAS_WINDOW;

        @(negedge clk);
        req      = 1'b0;
        is_write = 1'b0;
        addr     = '0;

        if (!ack) begin
            $display("[ERROR] CLKMEAS_WINDOW read did not generate ACK");
        end else begin
            $display("[PASS] CLKMEAS_WINDOW correctly read: %0d", rdata[WIN_W - 1 : 0]);
        end

        $display("");
        $display("========================================");
        $display("Regmap Simulation Finished");
        $display("========================================");
        $display("");

        $finish;
    end

    //! Simulation timeout
    initial begin
        #20us;

        $fatal(1, "Simulation timeout at time %0t.", $time);
    end

endmodule;