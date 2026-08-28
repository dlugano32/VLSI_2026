interface top_if #(
    parameter int W_ADDR = 8,
    parameter int W_DATA = 32
) (
    input logic clk_cpu
);

    logic                arst_n;
    logic [W_ADDR-1 : 0] addr;
    logic [W_DATA-1 : 0] wdata;
    logic                req;
    logic                is_write;
    logic [W_DATA-1 : 0] rdata;
    logic                ack;

    clocking cb_drv @(posedge clk_cpu);
        default input #1step output #1ps;
        output addr, wdata, req, is_write;
        input  rdata, ack;
    endclocking

    modport DRV (clocking cb_drv, output arst_n, input clk_cpu);

    clocking cb_mon @(posedge clk_cpu);
        default input #1step;
        input arst_n, addr, wdata, req, is_write, rdata, ack;
    endclocking

    modport MON (clocking cb_mon, input clk_cpu);

endinterface
