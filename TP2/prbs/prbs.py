from pathlib import Path

def generate_prbs(order: int, taps: tuple[int, ...], seed: int, length: int) -> list[int]:
    if order <= 1:
        raise ValueError("El orden del PRBS debe ser mayor que 1.")

    if length <= 0:
        raise ValueError("La longitud debe ser positiva.")

    if any(tap < 1 or tap > order for tap in taps):
        raise ValueError("Los taps deben estar entre 1 y el orden del PRBS.")

    mask = (1 << order) - 1 # Ej.: Order 15 -> Mask = 15'b111111111111111
    state = seed & mask     # Se inicializa el primer estado del lfsr como la mask 

    if state == 0:
        raise ValueError("La semilla activa no puede ser cero.")

    sequence = []

    for _ in range(length):
        output_bit = (state >> (order - 1)) & 1 # Se toma el LSB como parte de la secuencia
        sequence.append(output_bit)

        feedback = 0

        for tap in taps:
            feedback ^= (state >> (tap - 1)) & 1 # Se realiza la xor entre taps para obtener el fb

        state = ((state << 1) & mask) | feedback # Se hace el shift y se agrega el bit de feedback

    return sequence


def save_mem_file(filename: str, sequence: list[int]) -> None:

    path = Path(filename)

    with path.open("w", encoding="utf-8") as file:
        for bit in sequence:
            file.write(f"{bit}\n")

    print(f"Archivo generado: {path.resolve()}")
    print(f"Cantidad de bits: {len(sequence)}")


def main() -> None:

    # PRBS10:
    # P(x) = x^10 + x^7 + 1
    prbs10 = generate_prbs(
        order=10,
        taps=(10, 7),
        seed=0x3FF,
        length=2**10,
    )

    # PRBS15:
    # P(x) = x^15 + x^14 + 1
    prbs15 = generate_prbs(
        order=15,
        taps=(15, 14),
        seed=0x7FFF,
        length=2**12,
    )

    save_mem_file("TP2/prbs/mem/prbs10_reference.mem", prbs10)
    save_mem_file("TP2/prbs/mem/prbs15_reference.mem", prbs15)

if __name__ == "__main__":
    main()