import csv

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

def main ():

    transactions = {}

    PRBS_CONFIG = {
        0b000: (10, (10, 7)),
        0b001: (11, (11, 9)),
        0b010: (12, (12, 6, 4, 1)),
        0b011: (13, (13, 4, 3, 1)),
        0b100: (14, (14, 5, 3, 1)),
        0b101: (15, (15, 14)),
    }
    
    with open("TP2/prbs/prbs_output.csv", "r", encoding="utf-8") as file:
        reader = csv.DictReader(file)

        for row in reader:
            txn_id = int(row["transaction_id"])

            if txn_id not in transactions:
                transactions[txn_id] = {
                    "sel": int(row["sel"]),
                    "seed": int(row["seed"], 16),
                    "actual": [],
                }

            transactions[txn_id]["actual"].append(int(row["actual"]))

    total_errors = 0

    for txn_id, txn in transactions.items():

        sel    = txn["sel"]
        seed   = txn["seed"]
        actual = txn["actual"]

        order, taps = PRBS_CONFIG[sel]

        expected = generate_prbs(
            order=order,
            taps=taps,
            seed=seed,
            length=len(actual),
        )

        errors = 0

        for i, (exp, act) in enumerate(zip(expected, actual)):
            if exp != act:
                #print(
                #    f"[ERROR] txn={txn_id} sample={i} "
                #    f"expected={exp} actual={act}"
                #)
                errors += 1

        if errors == 0:
            print(
                f"[PASS] txn={txn_id} "
                f"PRBS{order} seed=0x{seed:X} "
                f"samples={len(actual)}"
            )
        else:
            print(
                f"[FAIL] txn={txn_id} "
                f"PRBS{order} seed=0x{seed:X} "
                f"errors={errors}/{len(actual)}"
            )

        total_errors += errors

    print()
    print(f"Total errors: {total_errors}")


if __name__ == "__main__":
    main()