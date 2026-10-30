# TP3 — Ejercicio 1a

`reference_model.py` contiene el modelo. `reference_model.ipynb` lo ejecuta,
verifica las salidas y genera las figuras del informe.

- `fir_model(window, coefficients)` calcula una salida. La ventana empieza
  por la muestra más reciente. Multiplica, suma con `FixedPoint` y al final
  aplica `trunc` y saturación.
- `resample_zeros_fixed(samples, h, history)` arma las ventanas del FIR directo.
- `resample_polyphase_fixed(samples, h, history)` arma las ventanas y selecciona
  los coeficientes de la fase correspondiente.

Las dos funciones devuelven `(output, next_history)`. Si se omite `history`,
parten de memoria en cero. Para seguir con otro bloque se entrega la memoria
devuelta por la llamada anterior:

```python
history = None
for start in range(0, len(samples), PIN):
    block = samples[start:start + PIN]
    output, history = resample_polyphase_fixed(block, h, history)
```

`verify_blocks` comprueba que las dos arquitecturas procesadas en bloques de 90
entradas produzcan lo mismo que al procesar toda la señal. No hay otra clase
ni otra implementación del filtro. La latencia del pipeline RTL se alinea en
el testbench.

Ejecutar `python TP3/model/reference_model.py` desde la raíz genera los vectores
y verifica el ejercicio 1a: 2070 entradas, 2760 salidas, L=4, M=3, N=64.
Ejecutar todas las celdas del notebook también genera las seis figuras en
`TP3/docs/pics`, con los mismos nombres usados por el informe.

Los archivos en `vectors` mantienen una palabra Q1.11 hexadecimal por línea:
coeficientes completos, coeficientes por fase, estímulo y salida esperada.
Los archivos `stimulus_gapped_q1_11.hex` y `stimulus_gapped_valid.txt` se
conservan para los ejercicios 4/5. No forman parte del cálculo del FIR.
