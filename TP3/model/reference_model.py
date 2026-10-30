"""TP3, ejercicio 1a: remuestreador 4/3 directo y polifasico.

fir_model calcula una salida del FIR, como un arbol de multiplicadores y
sumadores del RTL. Las otras dos funciones arman sus ventanas de entrada.
Cada una devuelve las salidas y la memoria para la siguiente llamada.
FixedPoint hace todas las multiplicaciones, sumas y el truncamiento/saturacion.
"""

from pathlib import Path
import sys
import numpy as np
from scipy.signal import firwin

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))
from utils.fixed_point import FixedPoint, FixedPointFormat

# Equivalentes a los parameter/localparam del RTL.
L = 4
M = 3
N = 64
PIN = 90
POUT = 120
DATA_FORMAT = FixedPointFormat(12, 11)
COEFF_FORMAT = FixedPointFormat(12, 11)


def design_coefficients():
    h_float = firwin(N, 1 / max(L, M), window="hamming", fs=2.0) * L
    h_quantized, h_integer = COEFF_FORMAT.quantize(h_float, rounding="round", overflow="raise")
    return h_float, h_quantized, h_integer.astype(np.int64)


def generate_stimulus(sample_count=2070, seed=42):
    rng = np.random.default_rng(seed)
    n = np.arange(sample_count)
    signal = (np.sin(2 * np.pi * 0.073 * n)
              + 0.63 * np.sin(2 * np.pi * 0.181 * n + 0.37)
              + 0.04 * rng.standard_normal(sample_count))
    signal = signal * (10 ** (-6 / 20)) / np.max(np.abs(signal))
    quantized, integer = DATA_FORMAT.quantize(signal, rounding="round", overflow="raise")
    return quantized, integer.astype(np.int64)


def polyphase_coefficients(h):
    phases = np.zeros((L, N // L), dtype=np.int64)
    for phase in range(L):
        for tap in range(N // L):
            phases[phase, tap] = h[tap * L + phase]
    return phases


def fir_model(window, coefficients):
    """UNA salida: window[0] es la muestra mas reciente, window[1] la anterior.

    Entradas y coeficientes son palabras enteras Q1.11 ya cuantizadas.
    """
    # Multiplicadores: productos completos de 24 bits y 22 bits fraccionales.
    products = []
    for tap in range(len(coefficients)):
        x = FixedPoint(window[tap], DATA_FORMAT, from_int=True, overflow="raise")
        h = FixedPoint(coefficients[tap], COEFF_FORMAT, from_int=True, overflow="raise")
        products.append(x * h)

    # Arbol de sumas. FixedPoint agrega un bit por nivel automaticamente.
    # 64 productos -> 6 niveles -> 30 bits; 16 productos -> 4 niveles -> 28 bits.
    while len(products) > 1:
        next_level = []
        for tap in range(0, len(products), 2):
            next_level.append(products[tap] + products[tap + 1])
        products = next_level

    # Unico recorte: shift aritmetico de 11 bits y saturacion signed a 12 bits.
    output = products[0].resize(DATA_FORMAT, rounding="trunc", overflow="saturate")
    return output.int_value


def interp_zeros(samples, h, history=None):
    """Directo: insertar ceros, FIR de 64 taps, conservar una de cada 3 salidas.

    history guarda las ultimas 63 muestras de tasa alta, en orden temporal.
    Si no se entrega historia, se parte de reset. No se agrega la cola del FIR.
    """
    if len(samples) % M != 0:
        raise ValueError("La cantidad de entradas debe ser multiplo de M")
    if history is None:
        history = np.zeros(N - 1, dtype=np.int64)

    # Regresor: primero la historia; despues [x0,0,0,0,x1,0,0,0,...].
    regressor = np.zeros(N - 1 + len(samples) * L, dtype=np.int64)
    for index in range(N - 1):
        regressor[index] = history[index]
    for index in range(len(samples)):
        regressor[N - 1 + index * L] = samples[index]

    output = np.zeros(len(samples) * L // M, dtype=np.int64)
    for n in range(len(output)):
        newest = N - 1 + n * M
        window = np.zeros(N, dtype=np.int64)
        for tap in range(N):
            window[tap] = regressor[newest - tap]
        output[n] = fir_model(window, h)

    # Registros que se conservan para el bloque siguiente.
    next_history = regressor[-(N - 1):].copy()
    return output, next_history


def interp_poly(samples, h, history=None):
    """Polifasico: FIR de 16 taps con fase p=(3*n)%4 y muestra m=(3*n)//4.

    history guarda las ultimas 15 entradas, en orden temporal.
    La cantidad de entradas es multiplo de 3: cada llamada arranca en fase 0.
    """
    if len(samples) % M != 0:
        raise ValueError("La cantidad de entradas debe ser multiplo de M")
    taps = N // L
    if history is None:
        history = np.zeros(taps - 1, dtype=np.int64)
    phases = polyphase_coefficients(h)

    regressor = np.zeros(taps - 1 + len(samples), dtype=np.int64)
    for index in range(taps - 1):
        regressor[index] = history[index]
    for index in range(len(samples)):
        regressor[taps - 1 + index] = samples[index]

    output = np.zeros(len(samples) * L // M, dtype=np.int64)
    for n in range(len(output)):
        m = (n * M) // L  # Cociente: muestra de entrada de referencia.
        p = (n * M) % L   # Resto: fase 0,3,2,1,0,3,2,1,...
        newest = taps - 1 + m
        window = np.zeros(taps, dtype=np.int64)
        for tap in range(taps):
            window[tap] = regressor[newest - tap]
        output[n] = fir_model(window, phases[p])

    next_history = regressor[-(taps - 1):].copy()
    return output, next_history


def verify_blocks(samples, h, expected):
    """Ejercicio 1a: bloques de 90 deben dar lo mismo que la secuencia completa."""
    for resampler in (interp_zeros, interp_poly):
        history = None
        for start in range(0, len(samples), PIN):
            block = samples[start:start + PIN]
            output, history = resampler(block, h, history)
            output_start = start * L // M
            np.testing.assert_array_equal(output, expected[output_start:output_start + POUT])


def export_hex(path, values, fmt):
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savetxt(path, fmt.to_hex(values), fmt="%s")


def export_vectors(samples, h, expected):
    directory = Path(__file__).with_name("vectors")
    phases = polyphase_coefficients(h)
    export_hex(directory / "coefficients_q1_11.hex", h, COEFF_FORMAT)
    export_hex(directory / "coefficients_polyphase_q1_11.hex", phases.flatten(), COEFF_FORMAT)
    export_hex(directory / "stimulus_q1_11.hex", samples, DATA_FORMAT)
    export_hex(directory / "expected_q1_11.hex", expected, DATA_FORMAT)

    # Vectores adicionales para los ejercicios 4/5: el FIR no consume los huecos.
    # Se mantienen los mismos archivos y semilla de la version anterior.
    rng = np.random.default_rng(43)
    blocks = samples.reshape(-1, PIN)
    valid = rng.permutation(np.tile([True, False], len(blocks)))
    data = rng.integers(-2048, 2048, size=(len(valid), PIN), dtype=np.int64)
    block_index = 0
    for cycle in range(len(valid)):
        if valid[cycle]:
            data[cycle] = blocks[block_index]
            block_index = block_index + 1
    export_hex(directory / "stimulus_gapped_q1_11.hex", data.flatten(), DATA_FORMAT)
    np.savetxt(directory / "stimulus_gapped_valid.txt", valid.astype(int), fmt="%d")


def main():
    _, _, h = design_coefficients()
    _, samples = generate_stimulus()
    direct, _ = interp_zeros(samples, h)
    polyphase, _ = interp_poly(samples, h)
    np.testing.assert_array_equal(direct, polyphase)
    verify_blocks(samples, h, direct)
    export_vectors(samples, h, direct)
    print(f"OK: {len(samples)} entradas -> {len(direct)} salidas; directo = polifasico = bloques")

if __name__ == "__main__":
    main()
