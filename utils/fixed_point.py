from dataclasses import dataclass
import numpy as np

@dataclass(frozen=True)
class FixedPointFormat:
    """
    Representa un formato fixed-point signed en complemento a dos.

    Convención:
    - NB  : cantidad total de bits, incluyendo signo.
    - NBF : cantidad de bits fraccionales.
    - NBI : cantidad de bits enteros, incluyendo signo.

    El valor real se interpreta como:

        x_real = x_int / 2**NBF

    donde x_int es el entero almacenado en complemento a dos.
    """

    NB: int
    NBF: int

    def __post_init__(self):
        if self.NB <= 0:
            raise ValueError("NB debe ser positivo.")
        if self.NBF < 0:
            raise ValueError("NBF no puede ser negativo.")
        if self.NBF >= self.NB:
            raise ValueError("NBF debe ser menor que NB para formato signed.")

    @property
    def NBI(self) -> int:
        """Bits enteros incluyendo el bit de signo."""
        return self.NB - self.NBF

    @property
    def scale(self) -> int:
        """Factor de escala entre real e entero."""
        return 2 ** self.NBF

    @property
    def int_min(self) -> int:
        """Mínimo entero representable."""
        return -2 ** (self.NB - 1)

    @property
    def int_max(self) -> int:
        """Máximo entero representable."""
        return 2 ** (self.NB - 1) - 1

    @property
    def real_min(self) -> float:
        """Mínimo valor real representable."""
        return self.int_min / self.scale

    @property
    def real_max(self) -> float:
        """Máximo valor real representable."""
        return self.int_max / self.scale

    @property
    def resolution(self) -> float:
        """Paso de cuantización."""
        return 1 / self.scale

    def info(self) -> None:
        """Imprime un resumen del formato."""
        print(f"Formato: Q({self.NB}, {self.NBF}) signed")
        print(f"Bits enteros incluyendo signo: {self.NBI}")
        print(f"Bits fraccionales           : {self.NBF}")
        print(f"Resolución                  : {self.resolution}")
        print(f"Rango entero                : [{self.int_min}, {self.int_max}]")
        print(f"Rango real                  : [{self.real_min}, {self.real_max}]")

    def can_represent(self, x) -> np.ndarray:
        """
        Verifica si uno o varios valores reales están dentro del rango representable.
        """
        x = np.asarray(x)
        return (x >= self.real_min) & (x <= self.real_max)

    def required_integer_bits(self, x) -> int:
        """
        Estima cuántos bits enteros incluyendo signo se necesitan para representar x.

        Esto sirve para analizar si el formato tiene suficiente rango.
        """
        x = np.asarray(x)
        max_abs = np.max(np.abs(x))

        if max_abs == 0:
            return 1

        # Para signed complemento a dos, se requiere que:
        # -2^(NBI-1) <= x < 2^(NBI-1)
        return int(np.ceil(np.log2(max_abs + 1e-15))) + 1

    def quantize(self, x, rounding="round", overflow="saturate"):
        """
        Cuantiza valores reales al formato fixed-point.

        Parameters
        ----------
        x : float or np.ndarray
            Valor o array de valores reales.
        rounding : str
            "round" o "trunc".
        overflow : str
            "saturate", "wrap" o "raise".

        Returns
        -------
        x_q : np.ndarray
            Valor cuantizado reconstruido como float.
        x_int : np.ndarray
            Entero escalado que representa al valor fixed-point.
        """
        x = np.asarray(x, dtype=float)
        x_scaled = x * self.scale

        if rounding == "round":
            x_int = np.round(x_scaled)
        elif rounding == "trunc":
            x_int = np.trunc(x_scaled)
        else:
            raise ValueError("rounding debe ser 'round' o 'trunc'.")

        x_int = x_int.astype(int)

        if overflow == "saturate":
            x_int = np.clip(x_int, self.int_min, self.int_max)

        elif overflow == "wrap":
            x_int = self._wrap_integer(x_int)

        elif overflow == "raise":
            if np.any((x_int < self.int_min) | (x_int > self.int_max)):
                raise OverflowError("El valor excede el rango representable.")
        else:
            raise ValueError("overflow debe ser 'saturate', 'wrap' o 'raise'.")

        x_q = x_int / self.scale
        return x_q, x_int

    def _wrap_integer(self, x_int):
        """
        Aplica wrap-around en complemento a dos.
        """
        modulo = 2 ** self.NB
        wrapped = ((x_int - self.int_min) % modulo) + self.int_min
        return wrapped.astype(int)

    def dequantize(self, x_int):
        """
        Convierte enteros fixed-point a valores reales.
        """
        x_int = np.asarray(x_int, dtype=int)

        if np.any((x_int < self.int_min) | (x_int > self.int_max)):
            raise ValueError("x_int contiene valores fuera del rango entero del formato.")

        return x_int / self.scale

    def quantization_error(self, x, rounding="round", overflow="saturate"):
        """
        Calcula el error de cuantización.
        """
        x = np.asarray(x, dtype=float)
        x_q, _ = self.quantize(x, rounding=rounding, overflow=overflow)
        return x_q - x

    def error_metrics(self, x, rounding="round", overflow="saturate") -> dict:
        """
        Devuelve métricas simples del error de cuantización.
        """
        err = self.quantization_error(x, rounding=rounding, overflow=overflow)

        return {
            "mse": float(np.mean(err ** 2)),
            "mae": float(np.mean(np.abs(err))),
            "max_abs_error": float(np.max(np.abs(err))),
            "mean_error": float(np.mean(err)),
        }

    def to_binary(self, x_int):
        """
        Convierte enteros signed al string binario de NB bits en complemento a dos.
        """
        x_int = np.asarray(x_int, dtype=int)

        if np.any((x_int < self.int_min) | (x_int > self.int_max)):
            raise ValueError("x_int contiene valores fuera del rango entero del formato.")

        unsigned = np.where(x_int < 0, x_int + 2 ** self.NB, x_int)
        return np.array([format(v, f"0{self.NB}b") for v in unsigned])

    def to_hex(self, x_int):
        """
        Convierte enteros signed a hexadecimal de ancho suficiente.
        """
        x_int = np.asarray(x_int, dtype=int)

        if np.any((x_int < self.int_min) | (x_int > self.int_max)):
            raise ValueError("x_int contiene valores fuera del rango entero del formato.")

        unsigned = np.where(x_int < 0, x_int + 2 ** self.NB, x_int)
        n_hex = int(np.ceil(self.NB / 4))
        return np.array([format(v, f"0{n_hex}X") for v in unsigned])


class FixedPoint:
    """
    Representa un número fixed-point signed en complemento a dos.

    Esta clase usa FixedPointFormat para describir el formato numérico.

    Ejemplo:
        Q8_6 = FixedPoint.Format(8, 6)

        a = FixedPoint(1.0, Q8_6)
        b = FixedPoint(0.5, Q8_6)

        p = a * b          # Q(16,12)
        y = p.resize(Q8_6) # Q(8,6)
    """

    # FixedPoint.Format(8, 6) equivale a FixedPointFormat(8, 6)
    Format = FixedPointFormat

    def __init__(
        self,
        value,
        fmt,
        *,
        from_int=False,
        rounding="trunc",
        overflow="saturate"
    ):
        """
        Crea un número fixed-point.

        Parameters
        ----------
        value:
            Si from_int=False, se interpreta como valor real.
            Si from_int=True, se interpreta como entero escalado.

        fmt:
            Instancia de FixedPointFormat.

        from_int:
            Indica si value ya es el entero interno fixed-point.

        rounding:
            Modo de cuantización si value es real.
            Opciones: "trunc", "round".

        overflow:
            Modo de manejo de overflow.
            Opciones: "saturate", "wrap", "raise".
        """
        if not isinstance(fmt, FixedPointFormat):
            raise TypeError("fmt debe ser una instancia de FixedPointFormat.")

        self.fmt = fmt

        if from_int:
            int_value = int(value)
        else:
            int_value = self._quantize_float(value, rounding=rounding)

        self.int_value = self._handle_overflow(int_value, overflow=overflow)

    @property
    def NB(self):
        return self.fmt.NB

    @property
    def NBF(self):
        return self.fmt.NBF

    @property
    def NBI(self):
        return self.fmt.NBI

    @property
    def scale(self):
        return self.fmt.scale

    @property
    def real_value(self):
        return self.int_value / self.scale

    def _quantize_float(self, value, rounding="trunc"):
        """
        Convierte un valor real al entero escalado.
        """
        scaled = float(value) * self.scale

        if rounding == "trunc":
            q = np.trunc(scaled)
        elif rounding == "round":
            q = np.round(scaled)
        else:
            raise ValueError("rounding debe ser 'trunc' o 'round'.")

        return int(q)

    def _handle_overflow(self, value, overflow="saturate"):
        """
        Aplica saturación, wrap o raise usando el rango del formato.
        """
        if overflow == "saturate":
            return int(np.clip(value, self.fmt.int_min, self.fmt.int_max))

        if overflow == "wrap":
            modulo = 2 ** self.NB
            wrapped = ((value - self.fmt.int_min) % modulo) + self.fmt.int_min
            return int(wrapped)

        if overflow == "raise":
            if value < self.fmt.int_min or value > self.fmt.int_max:
                raise OverflowError(
                    f"Valor entero {value} fuera de rango para {self.fmt}. "
                    f"Rango permitido: [{self.fmt.int_min}, {self.fmt.int_max}]"
                )
            return int(value)

        raise ValueError("overflow debe ser 'saturate', 'wrap' o 'raise'.")

    def resize(self, fmt_out, *, rounding="trunc", overflow="saturate"):
        """
        Cambia el formato fixed-point.

        Ejemplo:
            Q(16,12) -> Q(8,6)

        Si se reducen bits fraccionales, se desplaza a derecha.
        Si aumentan bits fraccionales, se desplaza a izquierda.

        rounding:
            "trunc"     : truncamiento hacia cero.
            "round"     : redondeo simple.
        """
        if not isinstance(fmt_out, FixedPointFormat):
            raise TypeError("fmt_out debe ser una instancia de FixedPointFormat.")

        shift = self.NBF - fmt_out.NBF
        value = self.int_value

        if shift > 0:
            if rounding == "trunc":
                # Shift aritmético en enteros signed.
                # Ejemplo: -5 >> 1 = -3
                value_out = value >> shift

            elif rounding == "round":
                # Redondeo simétrico simple.
                if value >= 0:
                    value_out = (value + (1 << (shift - 1))) >> shift
                else:
                    value_out = -((-value + (1 << (shift - 1))) >> shift)

            else:
                raise ValueError("rounding debe ser 'trunc' o 'round'.")

        elif shift < 0:
            value_out = value << (-shift)

        else:
            value_out = value

        return FixedPoint(
            value_out,
            fmt_out,
            from_int=True,
            overflow=overflow
        )

    def __add__(self, other):
        """
        Sobrecarga del operador +.

        Cuando escribís:
            c = a + b

        Python ejecuta:
            c = a.__add__(b)

        Regla:
            - Se alinean los bits fraccionales.
            - La suma crece un bit para evitar overflow inmediato.
        """
        if not isinstance(other, FixedPoint):
            raise TypeError("Solo se puede sumar FixedPoint con FixedPoint.")

        nbf_out = max(self.NBF, other.NBF)

        # Alineación de punto binario.
        fmt_a = FixedPointFormat(
            NB=self.NB + (nbf_out - self.NBF),
            NBF=nbf_out
        )

        fmt_b = FixedPointFormat(
            NB=other.NB + (nbf_out - other.NBF),
            NBF=nbf_out
        )

        a = self.resize(fmt_a, rounding="shift", overflow="raise")
        b = other.resize(fmt_b, rounding="shift", overflow="raise")

        int_out = a.int_value + b.int_value

        fmt_out = FixedPointFormat(
            NB=max(a.NB, b.NB) + 1,
            NBF=nbf_out
        )

        return FixedPoint(
            int_out,
            fmt_out,
            from_int=True,
            overflow="raise"
        )

    def __neg__(self):
        """
        Sobrecarga del operador unario -.

        Cuando escribís:
            b = -a

        Python ejecuta:
            b = a.__neg__()
        """
        fmt_out = FixedPointFormat(
            NB=self.NB + 1,
            NBF=self.NBF
        )

        return FixedPoint(
            -self.int_value,
            fmt_out,
            from_int=True,
            overflow="raise"
        )

    def __sub__(self, other):
        """
        Sobrecarga del operador -.

        Cuando escribís:
            c = a - b

        Python ejecuta:
            c = a.__sub__(b)
        """
        if not isinstance(other, FixedPoint):
            raise TypeError("Solo se puede restar FixedPoint con FixedPoint.")

        return self + (-other)

    def __mul__(self, other):
        """
        Sobrecarga del operador *.

        Cuando escribís:
            p = a * b

        Python ejecuta:
            p = a.__mul__(b)

        Regla fixed-point:
            Q(NB1, NBF1) * Q(NB2, NBF2)
            -> Q(NB1 + NB2, NBF1 + NBF2)
        """
        if not isinstance(other, FixedPoint):
            raise TypeError("Solo se puede multiplicar FixedPoint con FixedPoint.")

        int_out = self.int_value * other.int_value

        fmt_out = FixedPointFormat(
            NB=self.NB + other.NB,
            NBF=self.NBF + other.NBF
        )

        return FixedPoint(
            int_out,
            fmt_out,
            from_int=True,
            overflow="raise"
        )

    def to_hex(self):
        """
        Devuelve el valor entero interno como hexadecimal en complemento a dos.
        """
        return self.fmt.to_hex([self.int_value])[0]

    def to_binary(self):
        """
        Devuelve el valor entero interno como binario en complemento a dos.
        """
        return self.fmt.to_binary([self.int_value])[0]

    def copy(self):
        """
        Devuelve una copia del número fixed-point.
        """
        return FixedPoint(
            self.int_value,
            self.fmt,
            from_int=True,
            overflow="raise"
        )

    def __repr__(self):
        """
        Representación amigable del objeto.

        Python la usa cuando hacés:
            print(a)
        o cuando dejás:
            a
        al final de una celda.
        """
        return (
            f"FixedPoint("
            f"int={self.int_value}, "
            f"real={self.real_value:.8f}, "
            f"fmt=Q({self.NB},{self.NBF})"
            f")"
        )