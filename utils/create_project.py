#!/usr/bin/env python3
"""
VLSI Project Generator - Full Flow
RTL + TB + UVM + C Model + Synthesis + P&R + Lint
Synopsys tools + SAED 14nm Multi-Vt

Usage: python3 create_project.py <name> [--top <module>] [--clk_period <ns>]
"""
import argparse, os

def create_dir(p):
    os.makedirs(p, exist_ok=True); print(f"  [DIR]  {p}")
def create_file(p, c):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p,"w") as f: f.write(c)
    print(f"  [FILE] {p}")

def rtl_template(top):
    return f"""`timescale 1ns/1ps
module {top} #(parameter int WIDTH = 8) (
    input  logic i_clk, input logic i_rst, input logic i_enable,
    output logic [WIDTH-1:0] o_count
);
    logic [WIDTH-1:0] count_reg;
    always_ff @(posedge i_clk)
        if (i_rst) count_reg <= '0;
        else if (i_enable) count_reg <= count_reg + 1'b1;
    assign o_count = count_reg;
endmodule
"""

def tb_template(top, cp):
    h=cp/2
    return f"""`timescale 1ns/1ps
module tb_{top};
    localparam int WIDTH=8;
    logic clk,rst,enable; logic [WIDTH-1:0] count;
    {top} #(.WIDTH(WIDTH)) dut(.i_clk(clk),.i_rst(rst),.i_enable(enable),.o_count(count));
    initial clk=0; always #{h} clk=~clk;
    initial begin $dumpfile("sim/waves/{top}.vcd"); $dumpvars(0,tb_{top}); end
    int errors=0;
    task automatic check(string name, logic [WIDTH-1:0] exp);
        if(count!==exp) begin $display("  [FAIL] %s: exp %0d got %0d",name,exp,count); errors++; end
        else $display("  [PASS] %s: count=%0d",name,count);
    endtask
    initial begin
        $display("\\n=== TB: {top} ===\\n");
        rst=1;enable=0; repeat(3) @(posedge clk); rst=0;
        @(posedge clk); check("Reset",0);
        enable=1; repeat(10) @(posedge clk); check("Count10",10);
        enable=0; repeat(5) @(posedge clk); check("Pause",10);
        enable=1; repeat(5) @(posedge clk); check("Resume",15);
        repeat(241) @(posedge clk); check("Wrap",0);
        repeat(5) @(posedge clk); rst=1; @(posedge clk); check("MidRst",0); rst=0;
        repeat(2) @(posedge clk);
        $display("\\n=== %s ===\\n",errors==0?"ALL TESTS PASSED":$sformatf("%0d FAILED",errors));
        $finish;
    end
endmodule
"""

def sdc_template(top,cp):
    return f"""set PERIOD {cp}
set CONSTRAINT [expr {{$PERIOD * 0.10}}]
create_clock -period $PERIOD -name i_clk [get_ports i_clk]
set_input_delay  -clock i_clk $CONSTRAINT [remove_from_collection [all_inputs] [get_ports i_clk]]
set_output_delay -clock i_clk $CONSTRAINT [all_outputs]
"""

def syn_tcl_template(top):
    template = r"""set TOP __TOP__
###############################################################################
# syn.tcl  --  Sintesis de __TOP__ en SAED14 (Synopsys, compile_fusion):
#   - 4 flavors de celda como ref_libs (HVT/RVT/LVT/SLVT) + clock gating
#   - corners coherentes celda+parasitic: slow(ss+Cmax) / fast(ff+Cmin)
#
# Requiere env var LIB_BASE apuntando a libs_14.  Ej:
#   export LIB_BASE=/work/apesce/vlsi/.../libs_14
###############################################################################

set TOP __TOP__
set LIB_BASE $::env(LIB_BASE)
set PROJ_ROOT [file normalize [file dirname [info script]]/../..]

# Directorio de salida ESCRIBIBLE (evita el problema de ownership UID 2001).
# Si recuperas permiso en syn/outputs, podes volver a $PROJ_ROOT/syn/outputs.
set OUT_DIR $PROJ_ROOT/syn/outputs
file mkdir $OUT_DIR
# Trabajar dentro de OUT_DIR para que logs / WORK / .svf caigan ahi:
cd $OUT_DIR

###############################################################################
# Referencias fisicas (.ndm frame_timing) -- TODOS los flavors, base + cg
###############################################################################
set NDM_HVT      ${LIB_BASE}/ndm/saed14hvt_base_frame_timing.ndm
set NDM_RVT      ${LIB_BASE}/ndm/saed14rvt_base_frame_timing.ndm
set NDM_LVT      ${LIB_BASE}/ndm/saed14lvt_base_frame_timing.ndm
set NDM_SLVT     ${LIB_BASE}/ndm/saed14slvt_base_frame_timing.ndm
set NDM_HVT_CG   ${LIB_BASE}/ndm/saed14hvt_cg_frame_timing.ndm
set NDM_RVT_CG   ${LIB_BASE}/ndm/saed14rvt_cg_frame_timing.ndm
set NDM_LVT_CG   ${LIB_BASE}/ndm/saed14lvt_cg_frame_timing.ndm
set NDM_SLVT_CG  ${LIB_BASE}/ndm/saed14slvt_cg_frame_timing.ndm

set REF_NDMS [list \
    $NDM_HVT  $NDM_RVT  $NDM_LVT  $NDM_SLVT \
    $NDM_HVT_CG $NDM_RVT_CG $NDM_LVT_CG $NDM_SLVT_CG ]

###############################################################################
# Librerias de timing (.db)
#   target/link = corner SLOW (ss, 0.72V, 125C): peor caso setup.
#   Incluimos los 4 flavors base + cg.
###############################################################################
set DB ${LIB_BASE}/db
set SLOW_DBS [list \
    ${DB}/saed14hvt_base_ss0p72v125c.db  \
    ${DB}/saed14rvt_base_ss0p72v125c.db  \
    ${DB}/saed14lvt_base_ss0p72v125c.db  \
    ${DB}/saed14slvt_base_ss0p72v125c.db \
    ${DB}/saed14hvt_cg_ss0p72v125c.db    \
    ${DB}/saed14rvt_cg_ss0p72v125c.db    \
    ${DB}/saed14lvt_cg_ss0p72v125c.db    \
    ${DB}/saed14slvt_cg_ss0p72v125c.db   ]

set link_library   [concat "*" $SLOW_DBS]
set target_library $SLOW_DBS

###############################################################################
# Crear la .nlib de trabajo con el tech file de SAED14
###############################################################################
create_lib ${TOP}.nlib \
    -technology ${LIB_BASE}/physical/saed14nm_1p9m_mw.tf \
    -ref_libs $REF_NDMS

###############################################################################
# Leer RTL
###############################################################################
analyze -format sverilog ${PROJ_ROOT}/rtl/${TOP}.sv
# analyze -format sverilog ${PROJ_ROOT}/other_rtl.sv
elaborate ${TOP}
set_top_module ${TOP}

###############################################################################
# Parasitics (tluplus) -- dos especificaciones: Cmax (slow) y Cmin (fast)
###############################################################################
read_parasitic_tech -tlup ${LIB_BASE}/physical/saed14nm_1p9m_Cmax.tlup \
    -layermap ${LIB_BASE}/physical/saed14nm_tf_itf_tluplus.map -name Cmax
read_parasitic_tech -tlup ${LIB_BASE}/physical/saed14nm_1p9m_Cmin.tlup \
    -layermap ${LIB_BASE}/physical/saed14nm_tf_itf_tluplus.map -name Cmin

###############################################################################
# Corners + escenarios (multicorner-multimode)
#   slow : ss + Cmax  -> setup
#   fast : ff + Cmin  -> hold
###############################################################################
create_corner slow
create_corner fast
set_parasitic_parameters -late_spec Cmax -early_spec Cmax -corner slow
set_parasitic_parameters -late_spec Cmin -early_spec Cmin -corner fast

create_scenario -name func_slow -corner slow
source ${PROJ_ROOT}/syn/inputs/${TOP}.sdc

create_scenario -name func_fast -corner fast
source ${PROJ_ROOT}/syn/inputs/${TOP}.sdc

set_scenario_status func_slow -setup true  -hold false
set_scenario_status func_fast -setup false -hold true

###############################################################################
# Sintesis
###############################################################################
compile_fusion

###############################################################################
# Reportes y salidas
###############################################################################
report_timing > $OUT_DIR/timing.rpt
report_area   > $OUT_DIR/area.rpt
report_power  > $OUT_DIR/power.rpt
report_qor    > $OUT_DIR/qor.rpt
catch {report_threshold_voltage_group > ${PROJ_ROOT}/pnr/outputs/vt_groups.rpt}

write_verilog $OUT_DIR/${TOP}_netlist.v
write_sdc -output $OUT_DIR/${TOP}.sdc
save_lib

echo "=== Synthesis SAED14 complete ==="
echo "=== Outputs en: $OUT_DIR ==="
"""
    return template.replace("__TOP__", top)



def pnr_tcl_template(top):
    template = r"""###############################################################################
# run_fifo_pd_14.tcl
# Flujo de Physical Design para __TOP__ en SAED14 (Fusion Compiler).
#
# Cubre: setup libreria -> floorplan -> expand -> PG -> pin placement ->
#        SETUP DE TIMING (corner + parasitics + SDC) -> place_opt.
#
# Uso:   fc_shell> source run_fifo_pd_14.tcl
###############################################################################

###############################################################################
# 0) VARIABLES DE PROYECTO
###############################################################################
set PROJ_ROOT [ file normalize [ file dirname [ info script ]]/../..]
set DESIGN_NAME   __TOP__
set LIBS_14       ../../../../../libs_14
set NETLIST       ../../syn/outputs/__TOP___netlist.v
set SDC_FILE      ../../syn/outputs/__TOP__.sdc
set TECH_FILE     $LIBS_14/physical/saed14nm_1p9m_mw.tf
set NLIB          ${DESIGN_NAME}.nlib

# Reference libraries: TODOS los flavors (base) para PD.
# (los .ndm frame_timing traen geometria + timing juntos)
set REF_LIBS [list \
    $LIBS_14/ndm/saed14rvt_base_frame_timing.ndm  \
    $LIBS_14/ndm/saed14hvt_base_frame_timing.ndm  \
    $LIBS_14/ndm/saed14lvt_base_frame_timing.ndm  \
    $LIBS_14/ndm/saed14slvt_base_frame_timing.ndm \
    $LIBS_14/ndm/saed14rvt_cg_frame_timing.ndm    \
    $LIBS_14/ndm/saed14hvt_cg_frame_timing.ndm    \
    $LIBS_14/ndm/saed14lvt_cg_frame_timing.ndm    \
    $LIBS_14/ndm/saed14slvt_cg_frame_timing.ndm   \
]

# Parasitics (tluplus). Cmax = peor caso setup.
set TLUP_MAX  $LIBS_14/physical/saed14nm_1p9m_Cmax.tlup
set TLUP_MIN  $LIBS_14/physical/saed14nm_1p9m_Cmin.tlup

set PIN_CONSTRAINTS ../inputs/pins.tcl


###############################################################################
# 1) LIBRERIA DE TRABAJO Y NETLIST
#    Recreamos la .nlib desde cero en cada corrida (script re-ejecutable).
###############################################################################
# Cerrar la lib si quedo abierta de una corrida previa en la misma sesion
if {[get_libs -quiet $NLIB] ne ""} {
    close_lib $NLIB
}
# Borrar la .nlib del disco si existe (asi arranca siempre limpia)
if {[file exists $NLIB]} {
    file delete -force $NLIB
}
create_lib $NLIB -technology $TECH_FILE -ref_libs $REF_LIBS

read_verilog_outline -top $DESIGN_NAME $NETLIST
current_design $DESIGN_NAME
###############################################################################
# 2) FLOORPLAN
###############################################################################
initialize_floorplan -core_utilization 0.8 -core_offset 5
report_design -floorplan


###############################################################################
# 3) EXPANDIR OUTLINE
###############################################################################
expand_outline


###############################################################################
# 4) POWER / GROUND (UPF mono-voltaje + conexion logica)
###############################################################################
create_power_domain PD_TOP
create_supply_port  VDD
create_supply_port  VSS
create_supply_net   VDD -domain PD_TOP
create_supply_net   VSS -domain PD_TOP
connect_supply_net  VDD -ports VDD
connect_supply_net  VSS -ports VSS
set_domain_supply_net PD_TOP -primary_power_net VDD -primary_ground_net VSS
commit_upf
connect_pg_net -automatic


###############################################################################
# 5) MALLA PG (ring -> mesh -> rails)
#    OJO: SAED14 puede tener nombres/cantidad de capas distintos a SAED32.
#    Verifica con 'get_layers' que M7/M8/M1 existan; si el stack difiere,
#    ajusta los nombres de capa abajo.
###############################################################################
create_pg_ring_pattern ring_pat \
    -horizontal_layer M7 -horizontal_width {1} -horizontal_spacing {0.6} \
    -vertical_layer   M8 -vertical_width   {1} -vertical_spacing   {0.6} \
    -corner_bridge false
set_pg_strategy ring_strat -core \
    -pattern {{name: ring_pat} {nets: {VDD VSS}} {offset: {1 1}}} \
    -extension {{stop: design_boundary}}
compile_pg -strategies ring_strat

create_pg_mesh_pattern mesh_pat \
    -layers { \
        {{vertical_layer:   M8} {width: 1} {spacing: interleaving} {pitch: 8}} \
        {{horizontal_layer: M7} {width: 1} {spacing: interleaving} {pitch: 8}} \
    }
set_pg_strategy mesh_strat -core \
    -pattern {{name: mesh_pat} {nets: {VDD VSS}}} \
    -extension {{stop: outermost_ring}}
compile_pg -strategies mesh_strat

create_pg_std_cell_conn_pattern rail_pat -layers {M1}
set_pg_strategy rail_strat -core \
    -pattern {{name: rail_pat} {nets: {VDD VSS}}}
compile_pg -strategies rail_strat


###############################################################################
# 6) PIN PLACEMENT
###############################################################################
source $PIN_CONSTRAINTS
place_pins -self
check_pin_placement -pin_spacing true -layers true -sides true


###############################################################################
# 7) SETUP DE TIMING  <<< LO NUEVO: esto es lo que faltaba para place_opt
#    place_opt necesita: (a) un corner con parasitics, (b) el SDC con clocks.
###############################################################################

# --- 7.1 Leer las constraints (SDC) con clk_wr / clk_rd ---
read_sdc $SDC_FILE

# --- 7.2 Crear un corner y asociarle los parasitics (tluplus) ---
read_parasitic_tech -tlup $TLUP_MAX -layermap $LIBS_14/physical/saed14nm_tf_itf_tluplus.map -name maxTLU
set_parasitic_parameters -late_spec maxTLU -early_spec maxTLU

# --- 7.3 Definir el VOLTAJE del corner ---
#     Sin esto: "No voltages defined" y power 0.0/nan (OPT-006), y place_opt
#     no puede optimizar potencia. 0.72V porque sintetizamos en ss0p72v125c.
set_voltage 0.72 -object_list VDD
set_voltage 0.00 -object_list VSS

# --- 7.4 Habilitar buffers/inversores para OPTIMIZACION ---
#     Sin esto: "Cannot find usable buffers or inverters" (OPT-045) y
#     place_opt aborta en el initial placement. Marcamos todos los BUF/INV
#     de los 4 flavors con proposito de optimizacion y hold.
set_lib_cell_purpose -include {optimization hold} [get_lib_cells "*/SAED*14_BUF_*"]
set_lib_cell_purpose -include {optimization hold} [get_lib_cells "*/SAED*14_INV_*"]

# --- 7.5 Chequear que el timing este sano antes de optimizar ---
report_timing -max_paths 5


###############################################################################
# 8) PLACEMENT DE CELDAS + OPTIMIZACION
###############################################################################
place_opt

report_utilization
report_qor
report_timing -max_paths 10

###############################################################################
# 9) CTS (Clock Tree Synthesis)
###############################################################################
source ../inputs/cts.tcl

###############################################################################
# 10) Routing
###############################################################################
route_auto
route_opt

###############################################################################
# 11) Reportes
###############################################################################
report_timing > ${PROJ_ROOT}/pnr/outputs/timing.rpt
report_area > ${PROJ_ROOT}/pnr/outputs/area.rpt
report_power > ${PROJ_ROOT}/pnr/outputs/power.rpt
report_qor > ${PROJ_ROOT}/pnr/outputs/qor.rpt
catch {report_threshold_voltage_group > ${PROJ_ROOT}/pnr/outputs/vt_groups.rpt}
check_routes > ${PROJ_ROOT}/pnr/outputs/check_routes.rpt
 
###############################################################################
# 12) SAVE
###############################################################################
save_block -as fifo_routed
save_lib

puts "INFO: Routing completado. Guardado como fifo_routed."
puts ""
puts "Finished"

"""
    return template.replace("__TOP__", top)



def cts_template(top):
    template = r"""###############################################################################
# cts.tcl  --  Clock Tree Synthesis para __TOP__ (SAED14, Fusion Compiler)
#
# Se corre DESPUES de place_opt, sobre la misma sesion / .nlib.#
# Uso:  fc_shell> source cts.tcl
###############################################################################

###############################################################################
# 1) REGLA DE RUTEO DE RELOJ (non-default routing rule)
#    Doble ancho y doble espaciado respecto al default del tech, usando
#    multiplicadores (asi no hay que saber los valores exactos por capa).
#    Doble ancho  -> menos resistencia -> menos latencia y menos variabilidad.
#    Doble espacio -> menos crosstalk sobre el reloj (lo mas sensible).
###############################################################################
create_routing_rule clk_2w2s \
    -default_reference_rule \
    -multiplier_width   2 \
    -multiplier_spacing 2

###############################################################################
# 2) ASOCIAR LA REGLA AL DOMINIO DE RELOJ
#    Acotamos el ruteo del reloj a capas intermedias M3-M5:
#    - por debajo (M1/M2) es muy resistivo y esta el rail de PG en M1.
#    - por arriba (M7/M8) esta tu malla PG (ring + mesh).
###############################################################################
set_clock_routing_rules -clocks [get_clocks i_clk] \
    -rules clk_2w2s -min_routing_layer M3 -max_routing_layer M5

###############################################################################
# 3) CTS - ETAPA 1: construir los arboles (sin rutear todavia)
#    Partimos clock_opt para inspeccionar los arboles antes de rutear.
###############################################################################
clock_opt -to build_clock

# --- Reportes de los arboles recien construidos (por dominio) ---
#report_clock_qor -type latency
#report_clock_qor -type local_skew

###############################################################################
# 4) CTS - ETAPA 2: rutear el arbol + optimizacion final
#    route_clock: detail-routea el arbol.
#    final_opto : reoptimiza con latencias REALES (ya no ideales),
#                 re-placea/legaliza y hace global route de las senales.
###############################################################################
clock_opt -from route_clock -to final_opto

###############################################################################
# 5) QoR POST-CTS (ahora con relojes reales, no ideales)
###############################################################################
#report_qor
#report_clock_qor
#report_timing -max_paths 10

# Guardar el estado post-CTS
"""
    return template.replace("__TOP__", top)



def pins_template(top):
    template = r"""###############################################################################
# fifo_pins.tcl
# Restricciones de PIN PLACEMENT para fifo_async.
#
# ESTE es el archivo que editas para iterar el conexionado.
# Lo lee run_fifo_pd.tcl justo antes de place_pins.
#
# Numeracion de lados (Fusion Compiler), rectangulo:
#   lado 1 = borde IZQUIERDO  (vertical)
#   lado 2 = borde SUPERIOR   (horizontal)
#   lado 3 = borde DERECHO    (vertical)
#   lado 4 = borde INFERIOR   (horizontal)
# La numeracion arranca en el borde izquierdo y crece en sentido HORARIO.
#
###############################################################################

# Limpiamos restricciones previas para que cada corrida sea limpia.
remove_individual_pin_constraints
remove_bundle_pin_constraints
# (si existen bundles de una corrida previa, los borramos)
if {[sizeof_collection [get_bundles -quiet *]] > 0} {
    remove_bundles [get_bundles *]
}


###############################################################################
# 1) PINS CONSTRAINTS
###############################################################################
set_block_pin_constraints -allowed_layers {M3 M4} -self

# Entradas en lado izquierdo
set_individual_pin_constraints -ports {i_clk i_rst i_enable} -allowed_layers {M3} -sides 1

# Salidas en lado derecho
set_individual_pin_constraints -ports {o_count[0] o_count[1] o_count[2] o_count[3] o_count[4] o_count[5] o_count[6] o_count[7]} -allowed_layers {{M3}} -sides 3


###############################################################################
# 2) BUNDLES: agrupar y ordenar los buses de datos
#    Mantiene cada bus junto, en orden y sin pines ajenos intercalados.
#
#    OJO: el orden de las nets en el bundle define el orden fisico.
#    Las construimos bit 0 -> bit 7 para que -bundle_order increasing
#    coloque el bus de menor a mayor (de abajo hacia arriba en un lado
#    vertical).
###############################################################################

# --- Bundle del bus de salida o_count[7:0] ---
create_bundle -name b_odata [get_nets { \
    o_count[0]  o_count[1]  o_count[2]  o_count[3]  \
    o_count[4]  o_count[5]  o_count[6]  o_count[7]  }]

set_bundle_pin_constraints \
    -bundles [get_bundles b_odata] \
    -keep_pins_together true \
    -bundle_order increasing \
    -pin_spacing 5 \
    -sides 3


###############################################################################
# NOTAS PARA ITERAR
# - Si un bus queda al reves (bit 15 abajo), cambia -bundle_order a decreasing.
# - Para separar los pines del bus:  -pin_spacing <n_tracks>  dentro del
#   set_bundle_pin_constraints.
# - Para restringir capas del bus:   -allowed_layers {M2 M3 ...}
# - Las senales de control (clk/rst/en) quedan como pines individuales en su
#   lado; si las queres ordenar tambien, se pueden meter en su propio bundle.
###############################################################################
"""
    return template.replace("__TOP__", top)




def gui_syn_tcl_template(top):
    return f"""set TOP {top}
set LIB_BASE $::env(LIB_BASE)
set PROJ_ROOT [file normalize [file dirname [info script]]/../..]
open_lib ${{PROJ_ROOT}}/syn/scripts/${{TOP}}.nlib
open_block ${{TOP}}
start_gui
"""

def gui_pnr_tcl_template(top):
    return f"""set TOP {top}
set LIB_BASE $::env(LIB_BASE)
set PROJ_ROOT [file normalize [file dirname [info script]]/../..]
open_lib ${{PROJ_ROOT}}/pnr/outputs/${{TOP}}_pnr.nlib
open_block ${{TOP}}
start_gui
"""

def ndm_tcl_template():
    return """set LIB_BASE $::env(LIB_BASE)
set_app_options -name lib.logic_model.auto_remove_timing_only_designs -value true
file delete -force ${LIB_BASE}/ndm/saed32hvt_tt0p_v125c.ndm
create_workspace saed32hvt_tt0p_v125c -technology ${LIB_BASE}/physical/saed32nm_1p9m_mw.tf
read_db ${LIB_BASE}/db/saed32hvt_tt0p78v125c.db
read_db ${LIB_BASE}/db/saed32hvt_tt0p85v125c.db
read_lef ${LIB_BASE}/physical/saed32nm_hvt_1p9m.lef
catch {check_workspace}
file delete -force check_workspace.ems
commit_workspace -output ${LIB_BASE}/ndm/saed32hvt_tt0p_v125c.ndm
remove_workspace
file delete -force ${LIB_BASE}/ndm/saed32lvt_tt0p_v125c.ndm
create_workspace saed32lvt_tt0p_v125c -technology ${LIB_BASE}/physical/saed32nm_1p9m_mw.tf
read_db ${LIB_BASE}/db/saed32lvt_tt0p78v125c.db
read_db ${LIB_BASE}/db/saed32lvt_tt0p85v125c.db
read_lef ${LIB_BASE}/physical/saed32nm_lvt_1p9m.lef
catch {check_workspace}
file delete -force check_workspace.ems
commit_workspace -output ${LIB_BASE}/ndm/saed32lvt_tt0p_v125c.ndm
remove_workspace
echo "=== NDM complete ==="
exit
"""

def spyglass_tcl_template(top):
    return f"""set TOP {top}
set PROJ_ROOT [file normalize [file dirname [info script]]/..]
new_project ${{TOP}} -projectwdir ${{PROJ_ROOT}}/lint/work -force
read_file -type verilog ${{PROJ_ROOT}}/rtl/${{TOP}}.sv
set_option enableSV09 yes
set_option top ${{TOP}}
read_file -type sgdc ${{PROJ_ROOT}}/lint/${{TOP}}.sgdc
if {{[file exists ${{PROJ_ROOT}}/lint/${{TOP}}.swl]}} {{
    read_file -type waiver ${{PROJ_ROOT}}/lint/${{TOP}}.swl
}}
current_goal lint/lint_rtl
run_goal
current_goal cdc/cdc_verify_struct
run_goal
exit -force
"""

def sgdc_template(top):
    return f"""current_design {top}
clock -name clk
reset -name rst -value 1
"""

def cmodel_template(top):
    return f"""#include <stdio.h>
#include <stdint.h>
static uint8_t model_count = 0;
void cmodel_reset() {{ model_count = 0; }}
int cmodel_step(int rst, int enable) {{
    if (rst) model_count = 0;
    else if (enable) model_count++;
    return model_count;
}}
int cmodel_get_count() {{ return model_count; }}
#ifndef DPI_MODE
int main() {{
    printf("=== C Model: {top} ===\\n");
    cmodel_reset();
    int r;
    r=cmodel_step(1,0); printf("Reset: %d (exp 0)\\n",r);
    cmodel_step(0,0);
    for(int i=0;i<10;i++) r=cmodel_step(0,1); printf("Count10: %d (exp 10)\\n",r);
    for(int i=0;i<5;i++) r=cmodel_step(0,0); printf("Pause: %d (exp 10)\\n",r);
    for(int i=0;i<246;i++) r=cmodel_step(0,1); printf("Wrap: %d (exp 0)\\n",r);
    printf("=== Done ===\\n");
    return 0;
}}
#endif
"""

def uvm_dpi_template(top):
    return """import "DPI-C" function void cmodel_reset();
import "DPI-C" function int  cmodel_step(int rst, int enable);
import "DPI-C" function int  cmodel_get_count();
"""

def uvm_transaction_template(top):
    return f"""class {top}_transaction extends uvm_sequence_item;
    `uvm_object_utils({top}_transaction)
    rand bit rst;
    rand bit enable;
    logic [7:0] count;
    function new(string name="{top}_transaction"); super.new(name); endfunction
    function string convert2string();
        return $sformatf("rst=%0b en=%0b count=%0d",rst,enable,count);
    endfunction
endclass
"""

def uvm_if_template(top):
    return f"""interface {top}_if(input logic clk);
    logic rst, enable;
    logic [7:0] count;
    clocking drv_cb @(posedge clk); output rst; output enable; input count; endclocking
    clocking mon_cb @(posedge clk); input rst; input enable; input count; endclocking
endinterface
"""

def uvm_driver_template(top):
    return f"""class {top}_driver extends uvm_driver #({top}_transaction);
    `uvm_component_utils({top}_driver)
    virtual {top}_if vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual {top}_if)::get(this,"","vif",vif))
            `uvm_fatal("NOVIF","Virtual interface not found")
    endfunction
    task run_phase(uvm_phase phase);
        {top}_transaction tx;
        forever begin
            seq_item_port.get_next_item(tx);
            @(vif.drv_cb);
            vif.drv_cb.rst<=tx.rst;
            vif.drv_cb.enable<=tx.enable;
            seq_item_port.item_done();
        end
    endtask
endclass
"""

def uvm_monitor_template(top):
    return f"""class {top}_monitor extends uvm_monitor;
    `uvm_component_utils({top}_monitor)
    virtual {top}_if vif;
    uvm_analysis_port #({top}_transaction) ap;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap=new("ap",this);
        if(!uvm_config_db#(virtual {top}_if)::get(this,"","vif",vif))
            `uvm_fatal("NOVIF","Virtual interface not found")
    endfunction
    task run_phase(uvm_phase phase);
        {top}_transaction tx;
        forever begin
            @(vif.mon_cb);
            tx={top}_transaction::type_id::create("tx");
            tx.rst=vif.mon_cb.rst; tx.enable=vif.mon_cb.enable; tx.count=vif.mon_cb.count;
            ap.write(tx);
        end
    endtask
endclass
"""

def uvm_scoreboard_template(top):
    return f"""class {top}_scoreboard extends uvm_scoreboard;
    `uvm_component_utils({top}_scoreboard)
    uvm_analysis_imp #({top}_transaction, {top}_scoreboard) imp;
    int pass_count=0, fail_count=0, total=0;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase); imp=new("imp",this); cmodel_reset();
    endfunction
    function void write({top}_transaction tx);
        int expected; total++;
        if($isunknown(tx.count)) begin cmodel_step(tx.rst,tx.enable); return; end
        expected=cmodel_get_count();
        if(tx.count===expected[7:0]) begin
            pass_count++;
            if(total%50==0) `uvm_info("SCBD",$sformatf("[%0d] PASS: DUT=%0d C=%0d",total,tx.count,expected[7:0]),UVM_MEDIUM)
        end else begin
            fail_count++;
            `uvm_error("SCBD",$sformatf("[%0d] MISMATCH: DUT=%0d C=%0d",total,tx.count,expected[7:0]))
        end
        cmodel_step(tx.rst,tx.enable);
    endfunction
    function void report_phase(uvm_phase phase);
        `uvm_info("SCBD",$sformatf("\\n=== Total:%0d PASS:%0d FAIL:%0d ===",total,pass_count,fail_count),UVM_LOW)
        if(fail_count>0) `uvm_error("SCBD","*** TEST FAILED ***")
        else `uvm_info("SCBD","*** TEST PASSED ***",UVM_LOW)
    endfunction
endclass
"""

def uvm_agent_template(top):
    return f"""class {top}_agent extends uvm_agent;
    `uvm_component_utils({top}_agent)
    {top}_driver drv; {top}_monitor mon;
    uvm_sequencer #({top}_transaction) seqr;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv={top}_driver::type_id::create("drv",this);
        mon={top}_monitor::type_id::create("mon",this);
        seqr=uvm_sequencer#({top}_transaction)::type_id::create("seqr",this);
    endfunction
    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass
"""

def uvm_env_template(top):
    return f"""class {top}_env extends uvm_env;
    `uvm_component_utils({top}_env)
    {top}_agent agt; {top}_scoreboard scbd;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt={top}_agent::type_id::create("agt",this);
        scbd={top}_scoreboard::type_id::create("scbd",this);
    endfunction
    function void connect_phase(uvm_phase phase);
        agt.mon.ap.connect(scbd.imp);
    endfunction
endclass
"""

def uvm_sequences_template(top):
    return f"""class {top}_reset_seq extends uvm_sequence #({top}_transaction);
    `uvm_object_utils({top}_reset_seq)
    int num_cycles=3;
    function new(string name="{top}_reset_seq"); super.new(name); endfunction
    task body();
        {top}_transaction tx;
        repeat(num_cycles) begin tx={top}_transaction::type_id::create("tx"); start_item(tx); tx.rst=1;tx.enable=0; finish_item(tx); end
    endtask
endclass

class {top}_count_seq extends uvm_sequence #({top}_transaction);
    `uvm_object_utils({top}_count_seq)
    int num_cycles=20;
    function new(string name="{top}_count_seq"); super.new(name); endfunction
    task body();
        {top}_transaction tx;
        repeat(num_cycles) begin tx={top}_transaction::type_id::create("tx"); start_item(tx); tx.rst=0;tx.enable=1; finish_item(tx); end
    endtask
endclass

class {top}_pause_seq extends uvm_sequence #({top}_transaction);
    `uvm_object_utils({top}_pause_seq)
    int num_cycles=5;
    function new(string name="{top}_pause_seq"); super.new(name); endfunction
    task body();
        {top}_transaction tx;
        repeat(num_cycles) begin tx={top}_transaction::type_id::create("tx"); start_item(tx); tx.rst=0;tx.enable=0; finish_item(tx); end
    endtask
endclass

class {top}_random_seq extends uvm_sequence #({top}_transaction);
    `uvm_object_utils({top}_random_seq)
    int num_cycles=500;
    function new(string name="{top}_random_seq"); super.new(name); endfunction
    task body();
        {top}_transaction tx;
        repeat(num_cycles) begin
            tx={top}_transaction::type_id::create("tx"); start_item(tx);
            assert(tx.randomize() with {{ rst dist {{0:=95,1:=5}}; }});
            finish_item(tx);
        end
    endtask
endclass
"""

def uvm_test_template(top):
    return f"""class {top}_base_test extends uvm_test;
    `uvm_component_utils({top}_base_test)
    {top}_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase); env={top}_env::type_id::create("env",this);
    endfunction
    task run_phase(uvm_phase phase);
        {top}_reset_seq rst_seq; {top}_count_seq cnt_seq;
        {top}_pause_seq pse_seq; {top}_random_seq rnd_seq;
        phase.raise_objection(this);
        `uvm_info("TEST","=== Starting test ===",UVM_LOW)
        rst_seq={top}_reset_seq::type_id::create("rst_seq"); rst_seq.start(env.agt.seqr);
        cnt_seq={top}_count_seq::type_id::create("cnt_seq"); cnt_seq.num_cycles=20; cnt_seq.start(env.agt.seqr);
        pse_seq={top}_pause_seq::type_id::create("pse_seq"); pse_seq.start(env.agt.seqr);
        cnt_seq={top}_count_seq::type_id::create("cnt2"); cnt_seq.num_cycles=236; cnt_seq.start(env.agt.seqr);
        rnd_seq={top}_random_seq::type_id::create("rnd_seq"); rnd_seq.num_cycles=500; rnd_seq.start(env.agt.seqr);
        `uvm_info("TEST","=== Test complete ===",UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass
"""

def uvm_tb_top_template(top):
    return f"""`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "{top}_dpi.sv"
`include "{top}_transaction.sv"
`include "{top}_if.sv"
`include "{top}_driver.sv"
`include "{top}_monitor.sv"
`include "{top}_scoreboard.sv"
`include "{top}_agent.sv"
`include "{top}_env.sv"
`include "{top}_sequences.sv"
`include "{top}_test.sv"

module tb_top;
    logic clk; initial clk=0; always #1 clk=~clk;
    {top}_if cif(clk);
    {top} dut(.i_clk(clk),.i_rst(cif.rst),.i_enable(cif.enable),.o_count(cif.count));
    initial begin
        uvm_config_db#(virtual {top}_if)::set(null,"*","vif",cif);
        run_test("{top}_base_test");
    end
    initial begin $dumpfile("uvm_waves.vcd"); $dumpvars(0,tb_top); end
endmodule
"""

def makefile_template(top):
    template = r"""TOP:=__TOP__
PROJ_ROOT:=$(shell cd .. && pwd)
FC_SHELL:=/opt/synopsys/fusioncompiler/X-2025.06-SP3/bin/fc_shell
LM_SHELL:=/opt/synopsys/fusioncompiler/X-2025.06-SP3/bin/lm_shell
VCS:=vcs -sverilog -debug_access+all -full64
VERDI:=/opt/synopsys/verdi/Y-2026.03/bin/verdi
SPYGLASS:=/opt/synopsys/spyglass/Y-2026.03/SPYGLASS_HOME/bin/sg_shell
export LIB_BASE:=$(shell d=$(PROJ_ROOT);while [ ! -d "$$d/libs_14" ]&&[ "$$d" != "/" ];do d=$$(dirname "$$d");done;echo "$$d/libs_14")
export VCS_HOME:=/opt/synopsys/vcs/Y-2026.03-SP1
export SPYGLASS_HOME:=/opt/synopsys/spyglass/Y-2026.03/SPYGLASS_HOME
export PATH:=$(VCS_HOME)/bin:$(PATH)

.PHONY: help sim uvm cmodel syn pnr ndm lint waves gui-syn gui-pnr clean nuke

help: ## Show help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST)|awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n",$$1,$$2}'

sim: ## Simple VCS simulation
	@mkdir -p $(PROJ_ROOT)/sim/waves
	cd $(PROJ_ROOT)&&$(VCS) rtl/$(TOP).sv sim/tb/tb_$(TOP).sv -o sim/simv 2>&1|tee sim/compile.log
	cd $(PROJ_ROOT)&&sim/simv 2>&1|tee sim/sim.log

uvm: ## UVM testbench + C model DPI
	@mkdir -p $(PROJ_ROOT)/sim/waves
	cd $(PROJ_ROOT)&&rm -rf sim/simv_uvm sim/simv_uvm.daidir&&$(VCS) -ntb_opts uvm -timescale=1ns/1ps -CFLAGS "-DDPI_MODE" +incdir+uvm/ rtl/$(TOP).sv c_model/$(TOP)_model.c uvm/tb_top.sv -o sim/simv_uvm 2>&1|tee sim/uvm_compile.log
	cd $(PROJ_ROOT)&&sim/simv_uvm +UVM_TESTNAME=$(TOP)_base_test 2>&1|tee sim/uvm_sim.log

cmodel: ## C model standalone test
	cd $(PROJ_ROOT)/c_model&&gcc $(TOP)_model.c -o $(TOP)_model&&./$(TOP)_model

lint: ## SpyGlass lint + CDC
	@mkdir -p $(PROJ_ROOT)/lint/work
	export SPYGLASS_HOME=$(SPYGLASS_HOME)&&cd $(PROJ_ROOT)/lint&&$(SPYGLASS) -tcl run_spyglass.tcl 2>&1|tee spyglass.log

syn: ## Synthesis (multi-Vt MCMM)
	@mkdir -p $(PROJ_ROOT)/syn/outputs $(PROJ_ROOT)/syn/logs
	@rm -rf $(PROJ_ROOT)/syn/scripts/$(TOP).nlib
	cd $(PROJ_ROOT)/syn/scripts&&$(FC_SHELL) -f syn.tcl|tee $(PROJ_ROOT)/syn/logs/syn.log

pnr: ## Place & Route
	@mkdir -p $(PROJ_ROOT)/pnr/outputs $(PROJ_ROOT)/pnr/logs
	cd $(PROJ_ROOT)/pnr/scripts&&$(FC_SHELL) -f pnr.tcl|tee $(PROJ_ROOT)/pnr/logs/pnr.log

ndm: ## Create NDM libs (run once)
	@mkdir -p $(LIB_BASE)/ndm
	cd $(PROJ_ROOT)/syn/scripts&&$(LM_SHELL) -f create_ndm.tcl|tee $(PROJ_ROOT)/syn/logs/ndm.log

waves: ## Open Verdi waveforms (X11)
	cd $(PROJ_ROOT)&&$(VERDI) -ssf sim/waves/$(TOP).vcd &

gui-syn: ## Open FC GUI with post-synthesis design
	cd $(PROJ_ROOT)/syn/scripts&&$(FC_SHELL) -f gui_syn.tcl &

gui-pnr: ## Open FC GUI with post-P&R design
	cd $(PROJ_ROOT)/pnr/scripts&&$(FC_SHELL) -f gui_pnr.tcl &

clean: ## Remove outputs
	rm -rf $(PROJ_ROOT)/syn/outputs/* $(PROJ_ROOT)/pnr/outputs/* $(PROJ_ROOT)/syn/logs/* $(PROJ_ROOT)/pnr/logs/*
	rm -rf $(PROJ_ROOT)/syn/scripts/*.nlib $(PROJ_ROOT)/syn/scripts/HDL_LIBRARIES $(PROJ_ROOT)/syn/scripts/*.svf
	rm -rf $(PROJ_ROOT)/pnr/scripts/*.nlib $(PROJ_ROOT)/pnr/scripts/HDL_LIBRARIES
	rm -rf $(PROJ_ROOT)/sim/simv* $(PROJ_ROOT)/sim/*.log $(PROJ_ROOT)/sim/waves/*.vcd $(PROJ_ROOT)/sim/csrc
	rm -rf $(PROJ_ROOT)/csrc $(PROJ_ROOT)/simv.daidir $(PROJ_ROOT)/ucli.key
	rm -rf $(PROJ_ROOT)/lint/work $(PROJ_ROOT)/lint/*.log $(PROJ_ROOT)/c_model/$(TOP)_model

nuke: clean ## + remove NDMs
	rm -rf $(LIB_BASE)/ndm/*.ndm

timing:     ## Syn timing report
	@cat $(PROJ_ROOT)/syn/outputs/timing.rpt
area:       ## Syn area report
	@cat $(PROJ_ROOT)/syn/outputs/area.rpt
power:      ## Syn power report
	@cat $(PROJ_ROOT)/syn/outputs/power.rpt
qor:        ## Syn QoR report
	@cat $(PROJ_ROOT)/syn/outputs/qor.rpt
vt:         ## Syn Vt groups report
	@cat $(PROJ_ROOT)/syn/outputs/vt_groups.rpt
pnr-timing: ## PnR timing report
	@cat $(PROJ_ROOT)/pnr/outputs/timing.rpt
pnr-area:   ## PnR area report
	@cat $(PROJ_ROOT)/pnr/outputs/area.rpt
pnr-power:  ## PnR power report
	@cat $(PROJ_ROOT)/pnr/outputs/power.rpt
pnr-qor:    ## PnR QoR report
	@cat $(PROJ_ROOT)/pnr/outputs/qor.rpt
pnr-vt:     ## PnR Vt groups report
	@cat $(PROJ_ROOT)/pnr/outputs/vt_groups.rpt

"""
    return template.replace("__TOP__", top)



def main():
    p=argparse.ArgumentParser(description="VLSI Project Generator")
    p.add_argument("project"); p.add_argument("--top"); p.add_argument("--clk_period",type=float,default=2.0); p.add_argument("--base",default=".")
    a=p.parse_args(); top=a.top or a.project; root=os.path.join(os.path.abspath(a.base),a.project)
    print(f"\n{'='*55}\n  VLSI Project Generator\n  Project: {a.project} | Top: {top} | Clk: {a.clk_period}ns\n{'='*55}\n")
    for d in ["rtl","sim/tb","sim/waves","sim/csrc","syn/scripts","syn/inputs","syn/outputs","syn/logs","pnr/scripts","pnr/inputs","pnr/outputs","pnr/logs","lint","c_model","uvm","work"]:
        create_dir(os.path.join(root,d))
    create_file(os.path.join(root,"rtl",f"{top}.sv"),rtl_template(top))
    create_file(os.path.join(root,"sim","tb",f"tb_{top}.sv"),tb_template(top,a.clk_period))
    create_file(os.path.join(root,"syn","inputs",f"{top}.sdc"),sdc_template(top,a.clk_period))
    create_file(os.path.join(root,"pnr","inputs",f"cts.tcl"),cts_template(top))
    create_file(os.path.join(root,"pnr","inputs",f"pins.tcl"),pins_template(top))
    create_file(os.path.join(root,"syn","scripts","syn.tcl"),syn_tcl_template(top))
    create_file(os.path.join(root,"pnr","scripts","pnr.tcl"),pnr_tcl_template(top))
    create_file(os.path.join(root,"syn","scripts","gui_syn.tcl"),gui_syn_tcl_template(top))
    create_file(os.path.join(root,"pnr","scripts","gui_pnr.tcl"),gui_pnr_tcl_template(top))
    create_file(os.path.join(root,"syn","scripts","create_ndm.tcl"),ndm_tcl_template())
    create_file(os.path.join(root,"lint","run_spyglass.tcl"),spyglass_tcl_template(top))
    create_file(os.path.join(root,"lint",f"{top}.sgdc"),sgdc_template(top))
    create_file(os.path.join(root,"c_model",f"{top}_model.c"),cmodel_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_dpi.sv"),uvm_dpi_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_transaction.sv"),uvm_transaction_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_if.sv"),uvm_if_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_driver.sv"),uvm_driver_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_monitor.sv"),uvm_monitor_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_scoreboard.sv"),uvm_scoreboard_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_agent.sv"),uvm_agent_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_env.sv"),uvm_env_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_sequences.sv"),uvm_sequences_template(top))
    create_file(os.path.join(root,"uvm",f"{top}_test.sv"),uvm_test_template(top))
    create_file(os.path.join(root,"uvm","tb_top.sv"),uvm_tb_top_template(top))
    create_file(os.path.join(root,"work","Makefile"),makefile_template(top))
    print(f"\n{'='*55}\n  Done! {root}\n{'='*55}")
    print(f"""
  Flow:  cd {a.project}/work
    make cmodel    make sim     make uvm     make lint
    make ndm       make syn     make pnr     make help
    make gui-syn   make gui-pnr make waves
""")

if __name__=="__main__": main()
