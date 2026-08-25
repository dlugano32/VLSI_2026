class prbs_txn;

    localparam int WIDTH = 15;

    rand bit [WIDTH - 1 : 0] seed;
    rand bit [2 : 0]         sel;
    rand int unsigned        cycles;

    constraint c_sel {
        sel inside {[3'b000 : 3'b101]};
    }

    constraint c_seed {
        if( sel == 3'b000) { seed[14:10] == '0; seed[9:0]   != '0; } else
        if( sel == 3'b001) { seed[14:11] == '0; seed[10:0]  != '0; } else
        if( sel == 3'b010) { seed[14:12] == '0; seed[11:0]  != '0; } else
        if( sel == 3'b011) { seed[14:13] == '0; seed[12:0]  != '0; } else
        if( sel == 3'b100) { seed[14]    == '0; seed[13:0]  != '0; } else
                            {                   seed[14:0]  != '0; }
    }

    constraint c_n {
        cycles inside {[100 : 1000]};
    }

    function void display(string tag = "");
        $display("[%s] seed=0x%0h sel=%03b cycles=%0d", tag, seed, sel, cycles);
    endfunction

endclass
