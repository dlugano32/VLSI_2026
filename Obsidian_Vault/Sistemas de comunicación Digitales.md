Este es un resumen de la clase del 18/5 donde vimos como aplicar los RRC para obtener una transmisión sin ISI. El pdf correspondiente a la clase es 'Clase_3_Filtros_RC_RRC_VLSI.pdf'

# ISI, Raised Cosine, Root Raised Cosine y upsampling

## 1. Idea general del enlace digital

Una cadena básica de comunicaciones digitales en banda base puede pensarse así:

```text
bits → mapper → símbolos ak → upsample → filtro RRC TX → canal → filtro RRC RX → downsample → decisor
```

Donde:

- **Mapper:** convierte bits en símbolos.
- **Upsample:** aumenta la cantidad de muestras por símbolo insertando ceros.
- **Filtro RRC TX:** conforma el pulso y limita el ancho de banda.
- **Canal:** agrega ruido, distorsión o ISI adicional.
- **Filtro RRC RX:** actúa como filtro adaptado y completa la respuesta Raised Cosine total.
- **Downsample:** toma una muestra por símbolo en el instante correcto.
- **Decisor:** decide qué símbolo fue transmitido.

Esta estructura coincide con la cadena TX–canal–RX presentada en el apunte de filtros RC/RRC.

---

## 2. Interferencia entre símbolos, ISI

En comunicaciones digitales no se transmiten símbolos instantáneos ideales. Cada símbolo se transmite mediante un pulso desplazado en el tiempo.

La señal transmitida puede escribirse como:

```math
s(t)=\sum_k a_k p(t-kT)
```

donde:

- `ak` es el símbolo transmitido.
- `p(t)` es el pulso usado para transmitir cada símbolo.
- `T` es el período de símbolo.

Cuando el receptor muestrea en el instante `t = nT`, idealmente debería obtener solamente el símbolo `an`. Sin embargo, en general recibe:

```math
s(nT)=a_n p(0)+\sum_{k\neq n} a_k p((n-k)T)
```

El segundo término es la **interferencia entre símbolos**, o **ISI**.

La ISI aparece cuando los pulsos vecinos todavía tienen valor distinto de cero en el instante en que se quiere decidir el símbolo actual.

---

## 3. Condición de Nyquist para ISI nula

Para que no haya ISI, el pulso total del enlace debe cumplir:

```math
p(nT)=
\begin{cases}
1, & n=0 \\
0, & n\neq 0
\end{cases}
```

Esto significa:

- En el instante del símbolo actual, el pulso debe valer 1.
- En los instantes correspondientes a los demás símbolos, debe valer 0.

La idea importante es:

> No hace falta que los pulsos no se superpongan.  
> Hace falta que no interfieran en los instantes de muestreo.

Es decir, puede haber superposición temporal entre pulsos, pero si cada pulso tiene ceros justo en los tiempos de decisión de los otros símbolos, entonces no hay ISI.

---

## 4. Raised Cosine, RC

El filtro **Raised Cosine**, o **RC**, es una solución práctica al criterio de Nyquist.

Su objetivo es producir un pulso que cumpla la condición de ISI nula, pero con ancho de banda controlado.

El parámetro principal es el **roll-off**:

```math
\beta
```

donde:

```text
0 ≤ β ≤ 1
```

El ancho de banda del filtro RC es:

```math
W_{RC}=\frac{1+\beta}{2T}
```

Interpretación:

- `β = 0`: mínimo ancho de banda, pero transición abrupta y colas temporales largas.
- `β` mayor: más ancho de banda, transición más suave y mayor tolerancia temporal.

Resumen:

```text
menor β → mayor eficiencia espectral, filtro más exigente
mayor β → más ancho de banda, mayor tolerancia al timing
```

El RC cumple directamente:

```math
h_{RC}(nT)=0 \quad \text{para } n\neq 0
```

Por eso, como respuesta total del enlace, permite ISI nula.

---

## 5. Root Raised Cosine, RRC

En un sistema real normalmente no se implementa directamente un único filtro RC.

En cambio, se divide la respuesta RC total en dos filtros:

```text
RRC en transmisión + RRC en recepción
```

En frecuencia:

```math
H_{RRC}(f)\cdot H_{RRC}(f)=H_{RC}(f)
```

Es decir:

```math
H_{RRC}(f)=\sqrt{H_{RC}(f)}
```

Por eso se llama **Root Raised Cosine**.

La idea es:

```text
TX usa RRC
RX usa RRC
TX + RX equivalen a RC
```

Esto permite cumplir dos objetivos al mismo tiempo:

1. Que la respuesta total del enlace sea Raised Cosine, para tener ISI nula.
2. Que el filtro de recepción sea un **matched filter**, maximizando la SNR en presencia de ruido blanco.

Punto importante:

> Un RRC individual no tiene ISI nula por sí solo.  
> La ISI nula aparece después de pasar por el RRC de transmisión y el RRC de recepción.

En tiempo:

```math
h_{RRC}(t) * h_{RRC}(t)=h_{RC}(t)
```

---

## 6. Qué hace el upsampling

El upsampling suele ser una de las partes más confusas.

Supongamos que los símbolos son:

```text
a[k] = [1, -1, 1]
```

Esto está a **1 muestra por símbolo**.

Si hacemos upsampling por `L = 4`, insertamos ceros entre símbolos:

```text
x[n] = [1, 0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0]
```

Entonces:

- No se inventa información nueva.
- Se crea una grilla temporal más fina.
- Los símbolos no nulos quedan separados por `L` muestras.
- La señal queda preparada para ser filtrada por el RRC.

La frase correcta es:

> El upsampling crea una representación digital a mayor tasa de muestreo para poder aplicar el filtro de conformación de pulso.

---

## 7. Upsampling y espectro

Al hacer upsampling aparecen **imágenes espectrales**.

Por eso el bloque siguiente suele ser un filtro interpolador o de conformación de pulso.

En este caso, el filtro RRC TX cumple ambas funciones:

- Da forma temporal al pulso.
- Limita el ancho de banda.
- Atenúa imágenes espectrales generadas por el upsampling.
- Prepara la señal para que el enlace completo cumpla Nyquist.

Entonces:

```text
upsampling ≠ ISI nula
```

El upsampling por sí solo no garantiza nada respecto a la ISI.

La ISI nula la garantiza la respuesta total:

```math
H_{RRC}(f)\cdot H_{RRC}(f)=H_{RC}(f)
```

---

## 8. Qué hace el filtro RRC de transmisión

Después del upsampling, la señal tiene impulsos separados por ceros.

El filtro RRC TX convierte esa secuencia en una señal suave:

```text
símbolos upsampleados → convolución con hRRC[n] → señal conformada
```

Conceptualmente:

> El filtro RRC TX reemplaza cada símbolo por una copia escalada y desplazada del pulso RRC.

Entonces, si el símbolo vale `+1`, se agrega un pulso positivo.

Si vale `-1`, se agrega un pulso invertido.

La señal transmitida es la suma de todos esos pulsos.

---

## 9. Qué hace el canal

El canal puede introducir:

- Ruido.
- Atenuación.
- Distorsión.
- Limitación de ancho de banda.
- Multipath o ecos.
- ISI adicional.

En el caso ideal, se suele analizar primero un canal sin distorsión y con ruido blanco, AWGN.

En ese caso, el diseño RRC TX + RRC RX permite lograr:

```text
ISI nula + máxima SNR en el instante de muestreo
```

---

## 10. Qué hace el filtro RRC de recepción

El filtro RRC RX cumple dos funciones principales.

Primero, completa el Raised Cosine total:

```math
H_{RRC}(f)\cdot H_{RRC}(f)=H_{RC}(f)
```

Segundo, actúa como **matched filter** del filtro de transmisión.

Eso significa que maximiza la relación señal-ruido en el instante de decisión, bajo la hipótesis de ruido blanco.

Después del RRC RX, la señal todavía tiene varias muestras por símbolo.

Por eso todavía falta hacer downsampling.

---

## 11. Downsampling y fase de muestreo

Si usamos:

```text
sps = 4
```

entonces después del filtro RX hay 4 muestras por símbolo.

Para recuperar una muestra por símbolo, hacemos downsample. Pero hay varias fases posibles:

```text
fase 0: y[0], y[4], y[8], ...
fase 1: y[1], y[5], y[9], ...
fase 2: y[2], y[6], y[10], ...
fase 3: y[3], y[7], y[11], ...
```

La fase correcta es aquella donde el ojo está más abierto y la ISI es mínima.

En una simulación simple, muchas veces se conoce el retardo del filtro y se toma:

```text
y[delay :: sps]
```

En un sistema real, la fase correcta la determina un bloque de **timing recovery**.

---

## 12. Diagrama de ojo

El diagrama de ojo sirve para visualizar la calidad de la señal recibida.

Se obtiene superponiendo segmentos de señal de duración típicamente `2T`.

Un ojo abierto indica:

- Baja ISI.
- Buena SNR.
- Buen margen para decidir el símbolo.

Un ojo cerrado indica:

- Mucha ISI.
- Mucho ruido.
- Problemas de timing.
- Mayor probabilidad de error.

El punto ideal de muestreo está donde el ojo tiene mayor apertura vertical.

---

## 13. Resumen conceptual corto

```text
ISI:
Interferencia de símbolos vecinos en el instante de decisión.

Nyquist:
Condición para que los pulsos valgan cero en los instantes de los otros símbolos.

RC:
Filtro total ideal del enlace que cumple ISI nula con ancho de banda controlado.

RRC:
Raíz espectral del RC. Se usa uno en TX y otro en RX.

RRC TX + RRC RX:
Equivalen a un RC total.

Upsampling:
Inserta ceros entre símbolos para aumentar las muestras por símbolo.

Filtro RRC TX:
Conforma los pulsos y limita el espectro.

Canal:
Agrega ruido y posibles distorsiones.

Filtro RRC RX:
Matched filter + completa el RC total.

Downsampling:
Toma una muestra por símbolo en el instante óptimo.

Decisor:
Recupera los símbolos transmitidos.
```

---

## 14. Frase clave para recordar

> El upsampling permite representar digitalmente la forma del pulso con varias muestras por símbolo.  
> El RRC de transmisión conforma la señal y limita el ancho de banda.  
> El RRC de recepción completa la respuesta Raised Cosine total y maximiza la SNR.  
> La ISI nula se obtiene en los instantes de muestreo cuando la respuesta total TX+RX cumple el criterio de Nyquist.
