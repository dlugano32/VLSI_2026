class fir_par_gen;

    import fir_par_pkg::*;
    import fir_sop_pkg::*;

    mailbox #(fir_par_txn) gen2drv;

    int n_clk = 100;

    function new (mailbox #(fir_par_txn) gen2drv, int n_clk = 100);
        this.gen2drv = gen2drv;
        this.n_clk = n_clk;
    endfunction

    task load_coeffs(coeff_bus_t coeffs);
        fir_par_txn txn = new();

        txn.op     = fir_par_txn::LOAD_COEFFS;
        txn.coeffs = coeffs;

        gen2drv.put(txn);
    endtask

    task send_samples(par_din_t data);
        fir_par_txn txn = new();

        txn.op   = fir_par_txn::SEND_SAMPLES;
        txn.data = data;

        gen2drv.put(txn);
    endtask

    task send_rand(int n = 100);
        repeat (n) begin
            fir_par_txn txn = new();

            txn.op = fir_par_txn::SEND_SAMPLES;

            txn.randomize();

            gen2drv.put(txn);
        end
    endtask
    
    task wait_cycles(int n);
        repeat (n) begin
            fir_par_txn txn = new();
            txn.op = fir_par_txn::IDLE;
            gen2drv.put(txn);
        end
    endtask

    task send_constant(din_t value, int n_cycles);
        par_din_t data;

        foreach (data[lane])
            data[lane] = value;

        repeat (n_cycles)
            send_samples(data);
    endtask

    task send_stop ();
        fir_par_txn txn = new();

        txn.op = fir_par_txn::STOP;
        gen2drv.put(txn);
    endtask

    task send_zeros(int n_cycles = 10);
        send_constant(din_t'(0), n_cycles);
    endtask

    task send_plus_one(int n_cycles = 10);
        send_constant(din_t'(1), n_cycles);
    endtask

    task send_minus_one(int n_cycles = 10);
        send_constant(din_t'(-1), n_cycles);
    endtask

    task load_rrc_coeffs(string filename);
        coeff_t     coeff_mem [0:N_TAPS-1];
        coeff_bus_t coeffs;

        // Permite detectar si faltaron coeficientes en el archivo.
        foreach (coeff_mem[ix])
            coeff_mem[ix] = 'x;

        coeffs = '0;

        $readmemh(filename, coeff_mem);

        foreach (coeff_mem[ix]) begin
            if ($isunknown(coeff_mem[ix]))
                $fatal(1, "Coeficiente %0d no cargado desde %s", ix, filename);

            coeffs[ix] = coeff_mem[ix];
        end

        load_coeffs(coeffs);
    endtask

    task run();
        load_rrc_coeffs("uvm/coeffs_Q12_10.hex");

        send_zeros(25);
        send_rand(n_clk);
        send_zeros(25);
        wait_cycles(5);
        send_stop();
    endtask
    
endclass