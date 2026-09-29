class fir_gen;

    import fir_pkg::*;

    mailbox #(fir_txn) gen2drv;
    string stimulus_file;

    function new (mailbox #(fir_txn) gen2drv);
        this.gen2drv = gen2drv;
        stimulus_file = "uvm/vectors/stimulus_q1_11.hex";
    endfunction

    task send_sample(data_t data);
        fir_txn txn = new();

        txn.op   = fir_txn::SEND_SAMPLE;
        txn.data = data;

        gen2drv.put(txn);

        // El DUT recibe una muestra a f_s cada L clocks de L*f_s
        wait_cycles(INTERPOLATION - 1);
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

    task run();
        data_t samples [0 : N_INPUTS-1];

        $display("Stimulus file: %s", stimulus_file);

        foreach (samples[ix])
            samples[ix] = 'x;

        $readmemh(stimulus_file, samples);

        foreach (samples[ix]) begin
            if ($isunknown(samples[ix]))
                $fatal(1, "Muestra %0d no cargada desde %s", ix, stimulus_file);

            send_sample(samples[ix]);
        end

        // Permite que ambas lineas de retardo entreguen la cola completa
        repeat (FLUSH_SAMPLES) send_sample(data_t'(0));

        send_stop();
    endtask
    
endclass
