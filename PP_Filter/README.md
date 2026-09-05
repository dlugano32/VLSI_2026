# Filtro polifásico `pp_filter`

Este bloque implementa un conversor de tasa `UP/DW = 4/3`. En cada ciclo recibe
30 muestras consecutivas y construye 40 salidas consecutivas:

```text
PAR_IN   = 30
PAR_OUT  = 40 = 30 * 4/3
UP       = 4
DW       = 3
N_PROTO_TAPS = 19 (filtro serie completo)
N_TAPS   = 5     (por fase, ceil(19/4))
N_PHASES = 4
```

La idea central de la implementación es:

- `start_idx` selecciona **qué ventana de 5 muestras** procesa una salida.
- `phase_idx` selecciona **qué juego de 5 coeficientes** procesa esa ventana.

Los dos son `localparam` dentro de un `generate`. No son contadores ni señales
que cambien durante la simulación: al elaborar el diseño se crean 40 instancias
de `fir`, cada una con una ventana y una fase cableadas de manera fija.

## Organización de las muestras

Supongamos que en un ciclo se presenta el vector (escrito en orden temporal):

```text
i_data[0]=x[0], i_data[1]=x[1], ..., i_data[29]=x[29]
```

Aquí se usa la convención de que el índice menor contiene la muestra más
antigua del vector. Cada fase necesita también las 4 muestras inmediatamente
anteriores, ya que tiene 5 taps. El registro `mem` las conserva del bloque
anterior:

```systemverilog
mem <= i_data[PAR_IN - 1 -: (N_TAPS-1)];
```

Con los parámetros actuales equivale a:

```systemverilog
mem <= i_data[29:26];
```

Después de procesar el vector anterior, `mem[0:3]` representa
`x[-4] ... x[-1]`. La concatenación

```systemverilog
regresor = {i_data, mem};
```

queda ordenada, vista por índice creciente, así:

```text
regresor[ 0] = x[-4]
regresor[ 1] = x[-3]
...
regresor[ 3] = x[-1]
regresor[ 4] = x[ 0]
regresor[ 5] = x[ 1]
...
regresor[33] = x[29]
```

Por eso

```systemverilog
regresor[start_idx +: N_TAPS]
```

selecciona las posiciones `start_idx` a `start_idx+4`. En términos de las
muestras `x`, el FIR de la salida `ix` recibe:

```text
x[start_idx-4], ..., x[start_idx]
```

Dentro de `fir`, `i_data[t]` se multiplica por `i_coeffs[t]`. Con este orden de
buses, `coeff[0]` multiplica la muestra más antigua y `coeff[4]` la más nueva.

## Valores `start_idx` y `phase_idx`

Para la salida paralela número `ix`, la posición equivalente sobre el eje de
entrada es:

```text
posición = ix * DW / UP = ix * 3/4
```

La división entera por 4 separa esa posición en cociente y resto:

```systemverilog
start_idx = (ix * 3) / 4;  // cociente: muestra de entrada de referencia
phase_idx = (ix * 3) % 4;  // resto: fase fraccionaria 0, 1, 2 o 3
```

En otras palabras:

```text
ix*3 = 4*start_idx + phase_idx
```

Ejemplos:

- `ix=0`: `0*3 = 4*0 + 0`. Ventana que termina en `x[0]`, fase 0.
- `ix=1`: `1*3 = 4*0 + 3`. La misma ventana, pero fase 3.
- `ix=2`: `2*3 = 4*1 + 2`. Avanza una muestra y usa la fase 2.
- `ix=3`: `3*3 = 4*2 + 1`. Avanza otra muestra y usa la fase 1.
- `ix=4`: `4*3 = 4*3 + 0`. Ventana que termina en `x[3]`, fase 0.

La secuencia de fases es `0, 3, 2, 1`, y no `0, 1, 2, 3`, porque se avanza
`DW=3` unidades módulo `UP=4`:

```text
phase_idx = (3*ix) mod 4 = 0, 3, 2, 1, 0, 3, 2, 1, ...
```

## Simulación simbólica de un vector completo

`x[a:b]` indica las 5 muestras consecutivas desde `x[a]` hasta `x[b]`,
inclusive. La tabla muestra lo que queda cableado en las 40 instancias:

| `ix` | `ix*3/4` | `start_idx` | `phase_idx` | ventana del FIR |
|---:|---:|---:|---:|:---|
| 0  | 0.00  | 0  | 0 | `x[-4:0]` |
| 1  | 0.75  | 0  | 3 | `x[-4:0]` |
| 2  | 1.50  | 1  | 2 | `x[-3:1]` |
| 3  | 2.25  | 2  | 1 | `x[-2:2]` |
| 4  | 3.00  | 3  | 0 | `x[-1:3]` |
| 5  | 3.75  | 3  | 3 | `x[-1:3]` |
| 6  | 4.50  | 4  | 2 | `x[0:4]` |
| 7  | 5.25  | 5  | 1 | `x[1:5]` |
| 8  | 6.00  | 6  | 0 | `x[2:6]` |
| 9  | 6.75  | 6  | 3 | `x[2:6]` |
| 10 | 7.50  | 7  | 2 | `x[3:7]` |
| 11 | 8.25  | 8  | 1 | `x[4:8]` |
| 12 | 9.00  | 9  | 0 | `x[5:9]` |
| 13 | 9.75  | 9  | 3 | `x[5:9]` |
| 14 | 10.50 | 10 | 2 | `x[6:10]` |
| 15 | 11.25 | 11 | 1 | `x[7:11]` |
| 16 | 12.00 | 12 | 0 | `x[8:12]` |
| 17 | 12.75 | 12 | 3 | `x[8:12]` |
| 18 | 13.50 | 13 | 2 | `x[9:13]` |
| 19 | 14.25 | 14 | 1 | `x[10:14]` |
| 20 | 15.00 | 15 | 0 | `x[11:15]` |
| 21 | 15.75 | 15 | 3 | `x[11:15]` |
| 22 | 16.50 | 16 | 2 | `x[12:16]` |
| 23 | 17.25 | 17 | 1 | `x[13:17]` |
| 24 | 18.00 | 18 | 0 | `x[14:18]` |
| 25 | 18.75 | 18 | 3 | `x[14:18]` |
| 26 | 19.50 | 19 | 2 | `x[15:19]` |
| 27 | 20.25 | 20 | 1 | `x[16:20]` |
| 28 | 21.00 | 21 | 0 | `x[17:21]` |
| 29 | 21.75 | 21 | 3 | `x[17:21]` |
| 30 | 22.50 | 22 | 2 | `x[18:22]` |
| 31 | 23.25 | 23 | 1 | `x[19:23]` |
| 32 | 24.00 | 24 | 0 | `x[20:24]` |
| 33 | 24.75 | 24 | 3 | `x[20:24]` |
| 34 | 25.50 | 25 | 2 | `x[21:25]` |
| 35 | 26.25 | 26 | 1 | `x[22:26]` |
| 36 | 27.00 | 27 | 0 | `x[23:27]` |
| 37 | 27.75 | 27 | 3 | `x[23:27]` |
| 38 | 28.50 | 28 | 2 | `x[24:28]` |
| 39 | 29.25 | 29 | 1 | `x[25:29]` |

`start_idx` puede repetirse. Esto es correcto: al interpolar, algunas posiciones
de salida caen dentro del mismo intervalo de entrada y usan la misma ventana con
otra fase de coeficientes.

## Coeficientes `i_coeffs[phase_idx]`

Los tipos de los coeficientes son conceptualmente:

```text
i_coeffs[phase][tap]
          0..3  0..4
```

Es decir, existen cuatro bancos:

```text
i_coeffs[0][0..4] = c[0][0..4]  // fase 0
i_coeffs[1][0..4] = c[1][0..4]  // fase 1
i_coeffs[2][0..4] = c[2][0..4]  // fase 2
i_coeffs[3][0..4] = c[3][0..4]  // fase 3
```

Para cualquier salida `ix`, antes de saturar y truncar:

```text
acc[ix] = sumatoria, t=0..4, de:
          x[start_idx - 4 + t] * i_coeffs[phase_idx][t]
```

Las primeras salidas son:

```text
acc[0] = sum(x[-4+t] * i_coeffs[0][t]), t=0..4
acc[1] = sum(x[-4+t] * i_coeffs[3][t]), t=0..4
acc[2] = sum(x[-3+t] * i_coeffs[2][t]), t=0..4
acc[3] = sum(x[-2+t] * i_coeffs[1][t]), t=0..4
acc[4] = sum(x[-1+t] * i_coeffs[0][t]), t=0..4
```

`acc[0]` y `acc[1]` usan exactamente las mismas muestras, pero dan valores
distintos porque emplean las fases 0 y 3, respectivamente.

### Ejemplo numérico simplificado

Este ejemplo no pretende ser un filtro real; solamente permite seguir los
índices. Supongamos:

```text
x[n] = n + 10

todos los coeficientes valen 0, excepto:
i_coeffs[0][4] = 1
i_coeffs[1][4] = 2
i_coeffs[2][4] = 3
i_coeffs[3][4] = 4
```

Como sólo `coeff[4]` es distinto de cero, cada FIR toma la muestra más nueva
de su ventana. Antes de `sat_trunc` se obtiene:

```text
ix=0: start=0, phase=0 -> x[0] * 1 = 10
ix=1: start=0, phase=3 -> x[0] * 4 = 40
ix=2: start=1, phase=2 -> x[1] * 3 = 33
ix=3: start=2, phase=1 -> x[2] * 2 = 24
ix=4: start=3, phase=0 -> x[3] * 1 = 13
ix=5: start=3, phase=3 -> x[3] * 4 = 52
```

Esto separa visualmente el efecto de `start_idx` del de `phase_idx`.

## Continuidad entre dos vectores de entrada

En el vector siguiente entran `x[30] ... x[59]`. Para ese momento `mem` ya
guardó `x[26] ... x[29]`, de modo que:

```text
regresor = x[26], x[27], ..., x[29], x[30], ..., x[59]
```

La salida local `ix=0` usa `x[26:30]`; la salida `ix=39` usa `x[55:59]`.
Por lo tanto, ninguna ventana de convolución se rompe al cruzar el límite de los
vectores paralelos.

En general, para el bloque `b`, donde `i_data[j] = x[30*b+j]`, el FIR de salida
`ix` recibe:

```text
x[30*b + start_idx - 4 : 30*b + start_idx]
```

## Registros y latencia

En un flanco de reloj ocurren en paralelo:

1. `pp_filter` guarda en `mem` las últimas 4 muestras del vector actual.
2. Cada `fir` registra su ventana en `data_r` y su fase en `coeffs_r`.
3. Cada `fir` registra en `o_data` el resultado calculado con los `data_r` y
   `coeffs_r` que tenía antes del flanco.

Un vector presentado y capturado en un flanco produce su vector de resultados
registrado en el flanco siguiente: la latencia entre la captura de entrada y la
actualización correspondiente de salida es un ciclo.
