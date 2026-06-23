def expect_nonzero(action: String, result: Int) raises:
    if result == 0:
        raise Error("expected non-zero for " + action)


def expect_negative(action: String, value: Int64) raises:
    if value >= 0:
        raise Error("expected negative for " + action + ", got: " + String(value))


def expect_zero(action: String, result: Int) raises:
    if result != 0:
        raise Error("expected zero for " + action + ", got: " + String(result))


def expect_equal_int(action: String, actual: Int, expected: Int) raises:
    if actual != expected:
        raise Error(
            "unexpected value for "
            + action
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )
