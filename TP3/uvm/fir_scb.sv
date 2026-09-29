class fir_scb;
    import fir_pkg::*;

    mailbox #(data_t) mon2scb;

    data_t expected_data [0 : N_EXPECTED-1];
    string reference_file;

    int unsigned checked_count = 0;
    int unsigned error_count   = 0;
    bit          done          = 0;

    function new(mailbox #(data_t) mon2scb);
        this.mon2scb = mon2scb;
        reference_file = "uvm/vectors/expected_q1_11.hex";
    endfunction

    task load_reference();
        $display("Reference file: %s", reference_file);

        foreach (expected_data[ix])
            expected_data[ix] = 'x;

        $readmemh(reference_file, expected_data);

        foreach (expected_data[ix]) begin
            if ($isunknown(expected_data[ix]))
                $fatal(1, "Salida esperada %0d no cargada desde %s", ix, reference_file);
        end
    endtask

    task run();
        data_t actual;

        load_reference();

        while (checked_count < N_EXPECTED) begin
            mon2scb.get(actual);

            if (actual !== expected_data[checked_count]) begin
                $error(
                    "Mismatch sample=%0d expected=0x%03h (%0d) actual=0x%03h (%0d)",
                    checked_count,
                    expected_data[checked_count],
                    $signed(expected_data[checked_count]),
                    actual,
                    $signed(actual)
                );
                error_count++;
            end

            checked_count++;
        end

        done = 1'b1;
    endtask

endclass
