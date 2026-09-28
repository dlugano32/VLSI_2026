class fir_gen;

    import fir_pkg::*;

    mailbox #(fir_txn) gen2drv;

    int n_clk = 100;

    function new (mailbox #(fir_txn) gen2drv, int n_clk = 100);
        this.gen2drv = gen2drv;
        this.n_clk = n_clk;
    endfunction

    task load_coeffs(coeff_bus_t coeffs);
        fir_txn txn = new();

        txn.op     = fir_txn::LOAD_COEFFS;
        txn.coeffs = coeffs;

        gen2drv.put(txn);
    endtask

    task send_sample(din_t data);
        fir_txn txn = new();

        txn.op   = fir_txn::SEND_SAMPLE;
        txn.data = data;

        gen2drv.put(txn);
    endtask

    task send_rand(int n = 100);
        repeat (n) begin
            fir_txn txn = new();

            txn.op = fir_txn::SEND_SAMPLE;

            txn.randomize(data);

            gen2drv.put(txn);
        end
    endtask
    
    task wait_cycles(int n);
        repeat (n) begin
            fir_txn txn = new();
            txn.op = fir_txn::IDLE;
            gen2drv.put(txn);
        end
    endtask

    task send_stop ();
        fir_txn txn = new();

        txn.op = fir_txn::STOP;
        gen2drv.put(txn);
    endtask

    task send_zeros(int n = 10);
        repeat (n)
            send_sample(din_t'(0));
    endtask

    task send_plus_one(int n = 10);
        repeat (n)
            send_sample(din_t'(1));
    endtask

    task send_minus_one(int n = 10);
        repeat (n)
            send_sample(din_t'(-1));
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