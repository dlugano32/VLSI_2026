typedef enum bit [1:0] {
    BUS_READ,
    BUS_WRITE,
    BUS_IDLE
} bus_kind_e;

class top_txn;

    bus_kind_e     kind;
    bit    [7 : 0] addr;
    logic [31 : 0] wdata;
    logic [31 : 0] rdata;
    int unsigned   idle_cycles;
    bit            completed;

    function new();
        kind        = BUS_IDLE;
        addr        = '0;
        wdata       = '0;
        rdata       = '0;
        idle_cycles = 0;
        completed   = 0;
    endfunction

    function void display(string tag = "TXN");
        case (kind)
            BUS_WRITE: $display("[%s] WRITE addr=0x%02h data=0x%08h", tag, addr, wdata);
            BUS_READ : $display("[%s] READ  addr=0x%02h data=0x%08h", tag, addr, rdata);
            BUS_IDLE : $display("[%s] IDLE  cycles=%0d", tag, idle_cycles);
        endcase
    endfunction

endclass
