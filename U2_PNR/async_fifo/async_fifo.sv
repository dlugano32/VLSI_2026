`timescale 1ns/1ps

module async_fifo #(
    parameter int WIDTH = 8,
    parameter int ADDR  = 4
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

    localparam int DEPTH = 1<<ADDR;
    localparam int NB_PTR = ADDR + 1; //! Bit extra para detectar wrap

    //! Memoria de la FIFO
    logic [WIDTH - 1 : 0] mem [DEPTH - 1 : 0];

    //! Direcciones físicas de la memoria
    logic [ADDR - 1 : 0] w_addr;
    logic [ADDR - 1 : 0] r_addr;

    //! Punteros binarios extendidos
    logic [NB_PTR - 1 : 0] w_ptr;
    logic [NB_PTR - 1 : 0] r_ptr;
    logic [NB_PTR - 1 : 0] w_ptr_next;
    logic [NB_PTR - 1 : 0] r_ptr_next;

    //! Punteros codificados en Gray
    logic [NB_PTR - 1 : 0] w_ptr_gr;
    logic [NB_PTR - 1 : 0] r_ptr_gr;

    //! Registro de punteros codificados en Gray
    logic [NB_PTR - 1 : 0] r_ptr_gr_reg;
    logic [NB_PTR - 1 : 0] w_ptr_gr_reg;

    //! Punteros sincronizados entre dominios de clock
    logic [NB_PTR - 1 : 0] sync_w_ptr_gr; //! w_ptr_gr sincronizado hacia i_clk_r
    logic [NB_PTR - 1 : 0] sync_r_ptr_gr; //! r_ptr_gr sincronizado hacia i_clk_w

    //! Operaciones válidas de escritura y lectura
    logic w_push;
    logic r_pop;

    //! Escribir memoria
    always_ff @(posedge i_clk_w) begin : write_mem
        if (w_push) begin
            mem[w_addr] <= i_data;
        end
    end

    //! Leer memoria
    always_ff @(posedge i_clk_w) begin : read_mem
        if (i_rst_r) begin
            o_data <= '0;
        end else if (r_pop)
            o_data <= mem[r_addr];
    end

    //! FIFO de escritura
    always_ff @(posedge i_clk_w) begin : write_ptr
        if (i_rst_w) begin
            w_ptr <= '0;
        end else if (w_push) begin
            w_ptr       <= w_ptr_next;
        end
    end

    assign w_push = i_w_en && ~o_full;
    assign w_ptr_next = w_push ? w_ptr + 1'b1 : w_ptr;
    assign w_addr = w_ptr[ADDR - 1 : 0]; //! Dirección sin el bit de wrap

    //! FIFO de lectura
    always_ff @(posedge i_clk_w) begin : read_ptr
        if (i_rst_r) begin
            r_ptr  <= '0;
        end else if (r_pop) begin
            r_ptr  <= r_ptr_next;
        end
    end

    assign r_pop = i_r_en && ~o_empty;
    assign r_ptr_next = r_pop ? r_ptr + 1'b1 : r_ptr;
    assign r_addr = r_ptr[ADDR - 1 : 0]; //! Dirección sin el bit de wrap

    //! Conversión a Gray
    //! Se usa Gray porque entre incrementos consecutivos cambia un solo bit.
    //! Esto reduce el riesgo de metaestabilidad al cruzar los punteros entre dominios de clock.
    assign w_ptr_gr = w_ptr ^ (w_ptr >> 1);
    assign r_ptr_gr = r_ptr ^ (r_ptr >> 1);

    always_ff @(posedge i_clk_w) begin : r_ptr_reg
        r_ptr_gr_reg <= r_ptr_gr;
    end

    always_ff @(posedge i_clk_w) begin : w_ptr_reg
        w_ptr_gr_reg <= w_ptr_gr;
    end
    
    //! sync_w_ptr_gr:
    //!     w_ptr_gr debe sincronizarse desde i_clk_w hacia i_clk_r.
    sync_bus #(
        .NB_DATA (NB_PTR),
        .PIPE    (3)
    ) u_sync_w_ptr (
        .i_clk  (i_clk_r),
        .i_rst  (i_rst_r),
        .i_data (w_ptr_gr_reg),
        .o_data (sync_w_ptr_gr)
    );

    //! sync_r_ptr_gr:
    //!     r_ptr_gr debe sincronizarse desde i_clk_r hacia i_clk_w.
    sync_bus #(
        .NB_DATA (NB_PTR),
        .PIPE    (3)
    ) u_sync_r_ptr (
        .i_clk  (i_clk_w),
        .i_rst  (i_rst_w),
        .i_data (r_ptr_gr_reg),
        .o_data (sync_r_ptr_gr)
    );

    //! Condicion Empty
    //! La FIFO está vacía cuando el puntero de lectura alcanza al puntero de escritura sincronizado al dominio de lectura.
    //! La condicion es bloqueante a la lectura.
    assign o_empty = (sync_w_ptr_gr == r_ptr_gr);

    //! Condicion Full
    //! La FIFO está llena cuando el puntero de escritura está una vuelta por delante del puntero de lectura sincronizado al dominio de escritura.
    //! En Gray, esta condición se detecta invirtiendo los dos MSB del puntero de lectura sincronizado.
    assign o_full = (w_ptr_gr == {~sync_r_ptr_gr[NB_PTR - 1 -: 2], sync_r_ptr_gr[NB_PTR - 3 : 0]});

endmodule