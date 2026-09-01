import numpy as np


def matrix_power_gf2(A, power):
    result = np.eye(A.shape[0], dtype=int)
    base = A.copy()
    while power > 0:
        if power % 2 == 1:
            result = np.dot(result, base) % 2
        base = np.dot(base, base) % 2
        power //= 2
    return result

def main():

    PRBS = 10
    P = 4
    TAPS = [7, 10]

    A = np.zeros((PRBS,PRBS))

    for tap in TAPS:
        A[0, tap - 1] = 1

    A[1:,:-1] = np.eye(PRBS-1)

    print(A)
    print("")
    print(matrix_power_gf2(A,P))

if __name__ == "__main__":
    main()