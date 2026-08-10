`timescale 1ns/1ps

module async_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH  = 4
) (
    input  logic                 i_rd_clk,
    input  logic                 i_wr_clk,
    input  logic                 i_arst_n,
    input  logic                 i_wr_en,
    input  logic                 i_rd_en,
    input  logic [WIDTH - 1 : 0] i_data,
    output logic [WIDTH - 1 : 0] o_data,
    output logic                 o_empty,
    output logic                 o_full
);

    localparam int ADDR_W = $clog2(DEPTH);
    localparam int PTR_W  = ADDR_W + 1;     //! Bit extra para detectar wrap

    //! Memoria de la FIFO
    logic [WIDTH  - 1 : 0] mem [DEPTH - 1 : 0];

    //! Direcciones físicas de la memoria
    logic [ADDR_W - 1 : 0] wr_addr;
    logic [ADDR_W - 1 : 0] rd_addr;

    //! Reset de punteros sincronizados a sus respectivos dominios de clock
    logic rd_rst_n;
    logic wr_rst_n;

    //! Punteros binarios extendidos
    logic [PTR_W - 1 : 0] rd_ptr_r;
    logic [PTR_W - 1 : 0] wr_ptr_r;
    logic [PTR_W - 1 : 0] rd_ptr_next;
    logic [PTR_W - 1 : 0] wr_ptr_next;

    //! Punteros codificados en Gray
    logic [PTR_W - 1 : 0] wr_ptr_gr_r;
    logic [PTR_W - 1 : 0] rd_ptr_gr_r;
    logic [PTR_W - 1 : 0] wr_ptr_gr_next;
    logic [PTR_W - 1 : 0] rd_ptr_gr_next;

    //! Punteros sincronizados entre dominios de clock
    logic [PTR_W - 1 : 0] wr_ptr_gr_sync;   //! wr_ptr_gr_sync sincronizado hacia i_clk_r
    logic [PTR_W - 1 : 0] rd_ptr_gr_sync;   //! rd_ptr_gr_sync sincronizado hacia i_clk_w

    //! Operaciones válidas de escritura y lectura
    logic wr_push;
    logic rd_pop;

    sync_rst_n #(
        .PIPE(3)
    ) sync_rd_rst_n (
        .i_clk(i_rd_clk),
        .i_arst_n(i_arst_n),
        .o_rst_n(rd_rst_n)
    );

    sync_rst_n #(
        .PIPE(3)
    ) sync_wr_rst_n (
        .i_clk(i_wr_clk),
        .i_arst_n(i_arst_n),
        .o_rst_n(wr_rst_n)
    );

    //! Escribir memoria
    always_ff @(posedge i_wr_clk) begin
        if(wr_push) begin
            mem[wr_addr] <= i_data;
        end
    end

    assign wr_addr = wr_ptr_r[ADDR_W - 1 : 0];
    assign wr_push = (~o_full) && i_wr_en;


    //! Escribir memoria
    always_ff @(posedge i_rd_clk) begin
        if(rd_pop) begin
            o_data <= mem[rd_addr];
        end
    end
    assign rd_addr = rd_ptr_r[ADDR_W - 1 : 0];
    assign rd_pop = (~o_empty) && i_rd_en;


    //! FIFO de escritura
    always_ff @(posedge i_wr_clk) begin
        if(!wr_rst_n) begin
            wr_ptr_r <= '0;
        end else if(wr_push)begin
            wr_ptr_r <= wr_ptr_next;
        end
    end

    assign wr_ptr_next = wr_push ? (wr_ptr_r + 1'b1) : wr_ptr_r;


    //! FIFO de lectura
    always_ff @(posedge i_rd_clk) begin
        if(!rd_rst_n) begin
            rd_ptr_r <= '0;
        end else if(rd_pop) begin
            rd_ptr_r <= rd_ptr_next;
        end
    end

    assign rd_ptr_next = rd_pop ? (rd_ptr_r + 1'b1) : rd_ptr_r;

    //! Conversión a Gray
    //! Se usa Gray porque entre incrementos consecutivos cambia un solo bit.
    //! Esto reduce el riesgo de incoherencia al cruzar los punteros entre dominios de clock.

    //! Conversion Gray del puntero de escritura
    assign wr_ptr_gr_next = wr_ptr_next ^ (wr_ptr_next >> 1);

    always_ff @(posedge i_wr_clk) begin
        if(!wr_rst_n) begin
            wr_ptr_gr_r <= '0;
        end else begin
            wr_ptr_gr_r <= wr_ptr_gr_next;
        end
    end


    //! Conversion Gray del puntero de lectura
    assign rd_ptr_gr_next = rd_ptr_next ^ (rd_ptr_next >> 1);

    always_ff @(posedge i_rd_clk) begin
        if(!rd_rst_n) begin
            rd_ptr_gr_r <= '0;
        end else begin
            rd_ptr_gr_r <= rd_ptr_gr_next;
        end
    end

    //! Cruce de dominio de punteros
    sync_bus #(
        .PIPE(3),
        .WIDTH(PTR_W)
    ) u_sync_rd_ptr_gr (
        .o_data(rd_ptr_gr_sync),
        .i_data(rd_ptr_gr_r),
        .i_rst_n(wr_rst_n),
        .i_clk(i_wr_clk)
    );

    sync_bus #(
        .PIPE(3),
        .WIDTH(PTR_W)
    ) u_sync_wr_ptr_gr (
        .o_data(wr_ptr_gr_sync),
        .i_data(wr_ptr_gr_r),
        .i_rst_n(rd_rst_n),
        .i_clk(i_rd_clk)
    );

    //! Condicion Empty
    //! La FIFO está vacía cuando el puntero de lectura alcanza al puntero de escritura sincronizado al dominio de lectura.
    //! La condicion es bloqueante a la lectura.
    assign o_empty =  (rd_ptr_gr_r == wr_ptr_gr_sync);

    //! Condicion Full
    //! La FIFO está llena cuando el puntero de escritura está una vuelta por delante del puntero de lectura sincronizado al dominio de escritura.
    //! En Gray, esta condición se detecta invirtiendo los dos MSB del puntero de lectura sincronizado.
    assign o_full  =  (wr_ptr_gr_r == {~rd_ptr_gr_sync[PTR_W - 1 -: 2], rd_ptr_gr_sync[PTR_W - 3 : 0]});

endmodule