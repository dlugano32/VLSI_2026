"""Modelo fixed-point de referencia para el interpolador del TP3.

La aritmetica de este archivo define el contrato que debe respetar el RTL:

* muestras, coeficientes y salida: signed Q1.11 (12 bits);
* productos: Q2.22 (24 bits), sin recorte intermedio;
* acumulador: 28 bits, con cuatro bits de guarda;
* salida: truncamiento por descarte de LSB y saturacion signed.

Se implementan las dos formas del interpolador: insercion explicita de ceros y
descomposicion polifasica. Ambas rutas usan la misma funcion MAC fixed-point.
"""

from dataclasses import dataclass
from pathlib import Path
import sys

import numpy as np
from scipy.signal import firwin

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from utils.fixed_point import FixedPoint, FixedPointFormat


@dataclass(frozen=True)
class InterpolatorConfig:
    """Parametros estructurales y formatos numericos del interpolador."""

    interpolation: int = 4
    taps: int = 16
    nb_data:   int = 12
    nbf_data:  int = 11
    nb_coeff:  int = 12
    nbf_coeff: int = 11

    def __post_init__(self) -> None:
        if self.interpolation <= 0:
            raise ValueError("El factor de interpolacion debe ser positivo")
        if self.taps <= 0 or self.taps % self.interpolation:
            raise ValueError("La cantidad de taps debe ser multiplo de L")
        if self.nb_data <= self.nbf_data:
            raise ValueError("El formato de datos debe tener bit de signo")
        if self.nb_coeff <= self.nbf_coeff:
            raise ValueError("El formato de coeficientes debe tener bit de signo")

    @property
    def data_format(self) -> FixedPointFormat:
        return FixedPointFormat(self.nb_data, self.nbf_data)

    @property
    def coefficient_format(self) -> FixedPointFormat:
        return FixedPointFormat(self.nb_coeff, self.nbf_coeff)

    @property
    def output_format(self) -> FixedPointFormat:
        return self.data_format

    @property
    def product_format(self) -> FixedPointFormat:
        return FixedPointFormat(self.nb_data + self.nb_coeff, self.nbf_data + self.nbf_coeff)

    @property
    def guard_bits(self) -> int:
        return int(np.ceil(np.log2(self.taps)))

    @property
    def accumulator_format(self) -> FixedPointFormat:
        return FixedPointFormat( self.product_format.NB + self.guard_bits, self.product_format.NBF)


def design_coefficients(
    config: InterpolatorConfig,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Diseña y cuantiza el pasabajos anti-imagen.

    ``firwin`` usa una frecuencia de Nyquist normalizada a uno. Por eso el
    borde ideal para interpolacion por L es 1/L. Se usa ventana de Hamming y,
    por defecto, ganancia DC igual a L para conservar la amplitud luego de
    insertar L-1 ceros.

    Returns
    -------
    h_float:
        Coeficientes antes de cuantizar, incluyendo la compensacion de ganancia.
    h_quantized:
        Coeficientes cuantizados reconstruidos como ``float``.
    h_integer:
        Palabras signed Q1.11 que deben copiarse al RTL.
    """
    h_float = firwin(
        config.taps,
        cutoff=1.0 / config.interpolation,
        window="hamming",
        pass_zero="lowpass",
        scale=True,
        fs=2.0,
    )
        
    h_float = h_float * config.interpolation

    h_quantized, h_integer = config.coefficient_format.quantize(
        h_float,
        rounding="round",
        overflow="raise",
    )
    return h_float, h_quantized, h_integer.astype(np.int64)


def generate_stimulus(
    config: InterpolatorConfig,
    sample_count: int = 2000,
    seed: int = 42,
) -> tuple[np.ndarray, np.ndarray]:
    
    """Genera el estimulo comun: dos tonos, ruido bajo y pico a -6 dBFS."""
    if sample_count <= 0:
        raise ValueError("sample_count debe ser positivo")

    rng = np.random.default_rng(seed)
    n = np.arange(sample_count, dtype=float)

    signal = (
        np.sin(2.0 * np.pi * 0.073 * n)
        + 0.63 * np.sin(2.0 * np.pi * 0.181 * n + 0.37)
        + 0.04 * rng.standard_normal(sample_count)
    )
    target_peak = 10.0 ** (-6.0 / 20.0)
    signal *= target_peak / np.max(np.abs(signal))

    quantized, integer = config.data_format.quantize(
        signal,
        rounding="round",
        overflow="raise",
    )
    return quantized, integer.astype(np.int64)


def polyphase_coefficients(
    coefficients: np.ndarray,
    config: InterpolatorConfig,
) -> np.ndarray:
    """Separa h[k] en L fases: phases[p, r] = h[r*L + p]."""

    coefficients = np.asarray(coefficients, dtype=np.int64)

    return np.asarray(
        [coefficients[phase::config.interpolation] for phase in range(config.interpolation)],
        dtype=np.int64,
    )


def fir_model(
    i_data: np.ndarray,
    i_taps: np.ndarray,
    config: InterpolatorConfig,
) -> np.ndarray:
    """FIR fixed-point, con la misma aritmetica prevista para el RTL."""

    x = [
        FixedPoint(value, config.data_format, from_int=True, overflow="raise")
        for value in i_data
    ]
    
    h = [
        FixedPoint(value, config.coefficient_format, from_int=True, overflow="raise")
        for value in i_taps
    ]

    y = []

    # Convolucion completa.
    for n in range(len(x) + len(h) - 1):
        acc = FixedPoint(
            0,
            config.accumulator_format,
            from_int=True,
            overflow="raise",
        )

        for k in range(len(h)):
            x_idx = n - k

            if 0 <= x_idx < len(x):
                prod = x[x_idx] * h[k] # Producto full resolution
                acc = acc + prod       # El acumulador tiene 4 bits de guarda

        # Truncado y saturación a la resolución de salida
        y_n = acc.resize(
            config.output_format,
            rounding="trunc",
            overflow="saturate",
        )
        y.append(y_n.int_value)

    return np.asarray(y, dtype=np.int64)


def interpolate_zeros_fixed(
    samples: np.ndarray,
    coefficients: np.ndarray,
    config: InterpolatorConfig,
) -> np.ndarray:
    """Interpolador directo: inserta L-1 ceros y aplica el FIR completo."""

    upsampled = np.zeros(len(samples) * config.interpolation, dtype=np.int64)
    upsampled[::config.interpolation] = samples

    return fir_model(upsampled, coefficients, config)


def interpolate_polyphase_fixed(
    samples: np.ndarray,
    coefficients: np.ndarray,
    config: InterpolatorConfig,
) -> np.ndarray:
    """Interpolador polifasico: filtra con h[p::L] y entrelaza las fases."""

    phases = polyphase_coefficients(coefficients, config)
    phase_outputs = []

    for phase_coefficients in phases:
        phase_outputs.append(
            fir_model(samples, phase_coefficients, config)
        )

    # La convolucion directa incluye los L-1 ceros que quedan al final de la
    # secuencia interpolada. Se conserva esa longitud para comparar ambas
    # implementaciones muestra por muestra; las posiciones extra quedan en cero.
    output_length = len(samples) * config.interpolation + len(coefficients) - 1
    y = np.zeros(output_length, dtype=np.int64)

    for phase, phase_output in enumerate(phase_outputs):
        phase_indices = phase + config.interpolation * np.arange(len(phase_output))
        valid = phase_indices < output_length
        y[phase_indices[valid]] = phase_output[valid]

    return y


def export_hex(path: Path, values: np.ndarray, fmt: FixedPointFormat) -> None:
    """Exporta una palabra hexadecimal en complemento a dos por linea."""

    path.parent.mkdir(parents=True, exist_ok=True)
    np.savetxt(path, fmt.to_hex(values), fmt="%s")


def main() -> None:

    output_dir = Path(__file__).with_name("vectors")
    config = InterpolatorConfig()

    _, _, coefficients = design_coefficients(config)
    phases = polyphase_coefficients(coefficients, config)
    _, samples = generate_stimulus(config)
    direct = interpolate_zeros_fixed(samples, coefficients, config)
    polyphase = interpolate_polyphase_fixed(samples, coefficients, config)

    if not np.array_equal(direct, polyphase):
        mismatch = int(np.flatnonzero(direct != polyphase)[0])
        raise AssertionError(f"Las arquitecturas difieren en la muestra {mismatch}")

    paths = {
        "coefficients": output_dir / "coefficients_q1_11.hex",
        "polyphase_coefficients": output_dir / "coefficients_polyphase_q1_11.hex",
        "stimulus": output_dir / "stimulus_q1_11.hex",
        "expected": output_dir / "expected_q1_11.hex",
    }
    export_hex(paths["coefficients"], coefficients, config.coefficient_format)
    export_hex(paths["polyphase_coefficients"], phases.reshape(-1), config.coefficient_format)
    export_hex(paths["stimulus"], samples, config.data_format)
    export_hex(paths["expected"], direct, config.output_format)


    print(f"L={config.interpolation}, N={config.taps}")
    print(
        "Formatos: "
        f"entrada Q({config.data_format.NB},{config.data_format.NBF}), "
        f"producto Q({config.product_format.NB},{config.product_format.NBF}), "
        f"acumulador Q({config.accumulator_format.NB},{config.accumulator_format.NBF})"
    )
    print(f"Coeficientes enteros: {coefficients.tolist()}")
    
if __name__ == "__main__":
    main()
