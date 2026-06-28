## Ejercicios PNR

### Ejercicio 1: Dimensionamiento del floorplan
El sintetizador reportó que el fltro FIR de 19 taps tiene un área de celda de 3200 µm²

a) Calculá el core area necesario para una utilización del 60%.

$$
\text{Utilización} =
\frac{\text{Área total de celdas}}{\text{Core Area}}
\times 100\%
$$

$$
\text{Core Area} =
\frac{\text{Área total de celdas}}{\text{Utilización}}
=
\frac{3200\ \mu\text{m}^2}{0.6}
=
5333.33\ \mu\text{m}^2
$$

b) Calculá las dimensiones del core si querés un aspect ratio (altura/ancho) de 1.0 (cuadrado).

$$
W = L = \sqrt{\text{Core Area}} = \sqrt{5333.33\ \mu\text{m}^2} = 73\mu\text{m}
$$

c) Calculá el die area si usás un core offset de {3, 3, 3, 3} µm.

$$
\text{Die Area} = (73+3+3)\mu\text{m} \times (73+3+3)\mu\text{m} = 79 \times 79 \mu\text{m}^2 = 6241\ \mu\text{m}^2
$$

d) Escribí el comando initialize_floorplan con esos valores.

Forma con utilización y offset:

```initialize_floorplan -core_utilization 0.5 -core_offset {3 3 3 3}```

Forma con dimensiones fijas:

```initialize_floorplan -core_size {73 73} -core_offset {3 3 3 3}```

e) Qué pasa si aumentás la utilización al 80%? Y al 90%?

Al 80% el Core Area es $4000\ \mu\text{m}^2$

Al 90% el Core area es $3555.55\ \mu\text{m}^2$

Esto quiere decir que a medida que la utilización sea mayor, menor va a ser el área efectiva de ruteo y buffering disponible y por lo tanto, habrá mayor congestión y riesgo de DRC violations.


### Ejercicio 2: Análisis de placement
Después de correr ```place_opt``` en el filtro IIR, obtenés este QoR:

* WNS = -0.082 ns (VIOLATED)
* TNS = -0.214 ns
* Area = 4250.3 um^2
* InstCnt = 287
* LVT percent = 94%

a) ¿Qué significa WNS negativo? ¿El chip funciona?

El WNS negativo significa que el path más lento llega 82pS tarde respecto del flanco positivo del clock. Por lo tanto, el diseño luego de hacer el placement físico no cierra timing. 

b) ¿El sintetizador ya cerró timing por qué viola post-placement?

El sintetizador cierra timing para condiciones ideales de conexionado de celdas, sin tener en cuenta los delays en los wires reales.

c) 94% de celdas son LVT. ¿Qué intenta hacer el sintetizador?

El sintetizador está intentando cerrar timing con celdas LVT, que son más rápidas, pero a costo de potencia.

d) ¿Qué opciones tenés para cerrar timing? Nombrá al menos 3.

Las opciones son:
* Modificar el RTL haciendo pipelining o cambiando de arquitectura.
* Disminuir la utilización del core area para que haya menor congestión y los delays de los path sean menores.
* Utilizar celdas más rápidas en el placement fisico.


e) Si bajás la frecuencia de 500MHz a 400MHz, ¿el problema desaparece? ¿Por qué?

El periodo de 500MHz es 2ns y de 400MHz es 2.5ns. El diseño no cierra timing por 82pS, por lo que con un margen de 500pS extra debería cerrar timing.


### 9.3 Ejercicio 3: Clock Tree
Tenés un diseño con las siguientes características:

* Clock a 1 GHz (período = 1.0ns)
* Tsetup = 0.10ns
* Tclk→Q = 0.12ns
* Tcomb = 0.60ns
* Skew del clock tree = 0.08ns (FF receptor llega el clock más tarde)

a) Calculá el slack de setup sin considerar el skew.

$ Slack_{setup} = T_{period} - T_{clk\rightarrow Q} - T_{comb} - T_{setup} = 1ns - 0.12ns - 0.6ns - 0.1ns = +0.18ns $

b) Calculá el slack de setup con el skew. ¿Mejora o empeora?

$ Slack_{setup} = T_{period} + T_{skew} - T_{clk\rightarrow Q} - T_{comb} - T_{setup} = 1ns +0.08ns - 0.12ns - 0.6ns - 0.1ns = +0.26ns $

Mejora el slack de setup porque el skew del clock significa que tiene un delay.


c) ¿Qué valor máximo de skew podés tolerar antes de que setup viole?

Para que se viole el setup, el skew del clock debe ser menor a $ -0.18nS$

d) Calculá el slack de hold con Thold = 0.04ns y el mismo skew de 0.08ns.

$ Slack_{hold} = T_{clk\rightarrow Q} + T_{comb} - T_{hold} - T_{skew} = 0.12ns + 0.6ns - 0.04ns - 0.08ns = +0.6nS

e) ¿El skew ayuda o perjudica el hold check?

El skew perjudica el hold check, ya que mientras mas tarde el clock en llegar, menor es el margen para registrar el dato.

### 9.4 Ejercicio 4: Routing y DRC
Mirando el reporte de routing del filtro FIR obtenés:
```
Total open nets: 3
DRC violations: 12
- Spacing violations (M2): 7
- Width violations (M3): 3
- Via enclosure (VIA23): 2
Average horizontal track utilization: 78.3%
Peak horizontal track utilization: 103.2%
```
a) ¿Qué significa "3 open nets"? ¿El chip puede fabricarse así?

Significa que quedaron 3 conexiones del netlist que no se pudieron conectar. El chip NO puede fabricarse de esta forma ya que no funcionaría correctamente.

b) La utilización peak de 103.2\% es problemática. ¿Qué significa?

Significa que para cierta región del die hay una demanda de ruteo que supera la capacidad del espacio disponible para hacerlo.

c) ¿Cuál es la causa más probable de la congestión?

La causa es que la utilización sea muy alta (>80\%) y no haya suficiente espacio para hacer las conexiones.

d) Nombrá dos formas de reducir la congestión sin cambiar la lógica del diseño.

Se puede aumentar la utilización, aumentando el core area, o redistribuir las celdas problemáticas manualmente.

e) Un error de "Via enclosure" significa que el wire no envuelve correctamente la via. ¿Cómo lo arregla FC automáticamente?

FC tiene una regla de via fixing en ```route_opt``` que agrega metal extra para cumplir el enclosure mínimo.

### 9.5 Ejercicio 5: Comparación pre/post routing

Corré el flujo completo del filtro FIR (syn + pnr) y completá esta tabla:

Se hizo sintesis a 500MHz

| Métrica                     | Post-Sintesis  | Post-Placement  | Post-Routing |
|----------------------------:|---------------:|:---------------:|-------------:|
| WNS (ns)                    | +0.01nS        | +0.00ns         | -0.02ns      |
| TNS (ns)                    | -1.79ns        | -1.80ns         | -1.92        |
| Area ($\mu\text{m}$^2)      | 3034           | 3234            | 3371         |
| %LVT                        | 55             | 53              | 38%          |
| #Celdas                     | 857            | 900             | 993          |
| Potencia Dinámica ($\mu W$) | 54.3           | 79.0            | 90.0         |

a) ¿El WNS empeoró entre síntesis y routing? ¿Cuánto?

Si, empeoró porque en síntesis no se tienen en cuenta los delays de los wires que interconectan las celdas, ni el skew de los clocks, etc.

b) ¿El área cambió entre síntesis y routing? ¿Por qué?

Sí, el área cambió. En síntesis se reporta una estimación basada en las celdas lógicas utilizadas. Durante implementación física pueden insertarse buffers o cambiar el tipo de celdas para cumplir timing, aumentando el área efectiva.

c) ¿El % de LVT cambió? Si aumentó post-routing, ¿por qué?
El % de LVT disminuyó. Esto puede ser porque la herramienta haya hecho optimizaciones para reducir el leakage power, al tener algo de margen en el timing.

### 9.6 Ejercicio Integrador: Filtro FIR de 19 taps - Flujo completo

Corré el flujo completo (syn + pnr) del filtro FIR que diseñaron en el TP.

#### Paso 1: Síntesis

``` make syn ```

Se hizo la sintesis a 1GHz

Del reporte post-síntesis respondé:

a) ¿Cuántas celdas tiene el diseño sintetizado?

El diseño tiene 923 celdas

b) ¿Cuántos flip-flops? (en el reporte de área, buscá DFFX)

El diseño tiene 159 FF

c) ¿Cuál es el slack? ¿Qué frecuencia máxima soporta?

El slack es 0.00ns. Por lo que la frecuencia máxima que soporta esta sintesis es 1GHz.

d) ¿Qué porcentaje de celdas son LVT vs HVT?

El porcentaje de LVT es 77\% y el de HVT 23\%

#### Paso 2: Floorplan

Con el área de síntesis, calculá el tamaño del core para 60% de utilización y editá el floorplan.tcl.

El área total de las celdas es $3151\mu\text{m}^2$, por lo que a 60% de utilización el área del floorplan sería $5252\mu\text{m}^2$

#### Paso 3: P&R

``` make pnr ```

Del reporte post-P&R respondé:

a) ¿El timing cerró? Compará WNS pre y post routing.

El timing cerró en 0.00nS. Pre y post routing el WNS es el mismo, sin embargo el TNS post sintesis es de 0.82ns y el post-routing de 1.15ns.

b) ¿Cuántos buffers insertó el CTS?

Post sintesis había solo 1 buffer en el diseño. Luego del CTS se insertaron 60 buffers más, para dar un total de 61

c) ¿Cuál es la longitud total de wire? ¿En qué capas están los wires más largos?

La longitud total del wire (Net Lenght creo) $50685\mu\text{m}$

d) ¿Hay DRC violations? Si hay, de qué tipo.

Si, hay 5 violaciones. 

e) ¿Cuál es la potencia total? ¿Qué porcentaje es dinámica vs leakage?

La potencia total es 1.13mW. Siendo la potencia dinámica 0.162mW y la de leakage 0.331mW

#### Paso 4: Análisis en la GUI

Abrí FC con ``` make gui-syn ``` y explorá el layout del filtro:

a) Identificá los registros del shift register (los 18 DFFs de delay).

b) Identificá la cadena de multiplicadores/sumadores.

c) Usá Highlight -> Clock Tree para ver el árbol de clock.

d) Deshabilitá M3 y M4 en el panel de capas. ¿Qué ven?