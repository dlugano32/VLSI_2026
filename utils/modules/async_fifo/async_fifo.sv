`timescale 1ns/1ps

module async_fifo #(
    parameter int DEPTH = 4,
    parameter int WIDTH = 8
) (
    input  logic                 i_clk_r,
    input  logic                 i_clk_w,
    input  logic                 i_rst_r,
    input  logic                 i_rst_w,
    input  logic                 i_w_en,
    input  logic                 i_r_en,
    input  logic [WIDTH - 1 : 0] i_data,
    output logic [WIDTH - 1 : 0] o_data,
    output logic                 o_empty,
    output logic                 o_full
);

    localparam int ADDR_W = $clog2(DEPTH);
    localparam int NB_PTR = ADDR_W + 1; //! Bit extra para detectar wrap

    //! Memoria de la FIFO
    logic [WIDTH - 1 : 0] mem [DEPTH - 1 : 0];

    //! Direcciones físicas de la memoria
    logic [ADDR_W - 1 : 0] w_addr;
    logic [ADDR_W - 1 : 0] r_addr;

    //! Punteros binarios extendidos
    logic [NB_PTR - 1 : 0] w_ptr;
    logic [NB_PTR - 1 : 0] r_ptr;
    logic [NB_PTR - 1 : 0] w_ptr_next;
    logic [NB_PTR - 1 : 0] r_ptr_next;

    //! Punteros codificados en Gray
    logic [NB_PTR - 1 : 0] w_ptr_gr;
    logic [NB_PTR - 1 : 0] r_ptr_gr;

    //! Punteros sincronizados entre dominios de clock
    logic [NB_PTR - 1 : 0] sync_w_ptr_gr; //! w_ptr_gr sincronizado hacia i_clk_r
    logic [NB_PTR - 1 : 0] sync_r_ptr_gr; //! r_ptr_gr sincronizado hacia i_clk_w

    //! Operaciones válidas de escritura y lectura
    logic w_push;
    logic r_pop;

    //! FIFO de escritura
    always_ff @(posedge i_clk_w) begin : write_fifo
        if (i_rst_w) begin
            w_ptr <= '0;
        end else if (w_push) begin
            mem[w_addr] <= i_data;
            w_ptr       <= w_ptr_next;
        end
    end

    assign w_push = i_w_en && ~o_full;
    assign w_ptr_next = w_push ? w_ptr + 1'b1 : w_ptr;
    assign w_addr = w_ptr[ADDR_W - 1 : 0]; //! Dirección sin el bit de wrap

    //! FIFO de lectura
    always_ff @(posedge i_clk_r) begin : read_fifo
        if (i_rst_r) begin
            r_ptr  <= '0;
            o_data <= '0;
        end else if (r_pop) begin
            o_data <= mem[r_addr];
            r_ptr  <= r_ptr_next;
        end
    end

    assign r_pop = i_r_en && ~o_empty;
    assign r_ptr_next = r_pop ? r_ptr + 1'b1 : r_ptr;
    assign r_addr = r_ptr[ADDR_W - 1 : 0]; //! Dirección sin el bit de wrap

    //! Conversión a Gray
    //! Se usa Gray porque entre incrementos consecutivos cambia un solo bit.
    //! Esto reduce el riesgo de metaestabilidad al cruzar punteros entre dominios de clock.
    assign w_ptr_gr = w_ptr ^ (w_ptr >> 1);
    assign r_ptr_gr = r_ptr ^ (r_ptr >> 1);

    //! Condicion Empty
    //! La FIFO está vacía cuando el puntero de lectura alcanza al puntero de escritura sincronizado al dominio de lectura.
    //! La condicion es bloqueante a la lectura.
    assign o_empty = (sync_w_ptr_gr == r_ptr_gr);

    //! Condicion Full
    //! La FIFO está llena cuando el puntero de escritura está una vuelta por delante del puntero de lectura sincronizado al dominio de escritura.
    //! En Gray, esta condición se detecta invirtiendo los dos MSB del puntero de lectura sincronizado.
    assign o_full = (w_ptr_gr == {~sync_r_ptr_gr[NB_PTR - 1 -: 2], sync_r_ptr_gr[NB_PTR - 3 : 0]});

    
    //! sync_w_ptr_gr:
    //!     w_ptr_gr debe sincronizarse desde i_clk_w hacia i_clk_r.
    sync_bus #(
        .NB_DATA (NB_PTR),
        .PIPE    (3)
    ) u_sync_w_ptr (
        .i_clk  (i_clk_r),
        .i_rst  (i_rst_r),
        .i_data (w_ptr_gr),
        .o_data (sync_w_ptr_gr)
    );

    //! sync_r_ptr_gr:
    //!     r_ptr_gr debe sincronizarse desde i_clk_r hacia i_clk_w.
    sync_bus #(
        .NB_DATA (NB_PTR),
        .PIPE    (3)
    ) u_sync_w_ptr (
        .i_clk  (i_clk_w),
        .i_rst  (i_rst_w),
        .i_data (r_ptr_gr),
        .o_data (sync_r_ptr_gr)
    );

endmodule