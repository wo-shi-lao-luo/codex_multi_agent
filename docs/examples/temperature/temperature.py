"""Pure temperature conversions for the library demo.

The functions accept finite real numeric values and return ordinary Python
floats, without physical-range validation or side effects.
"""


def celsius_to_fahrenheit(value):
    """Convert a finite real Celsius value to an ordinary Fahrenheit float.

    This pure conversion performs no physical-range validation. Floating-point
    arithmetic may introduce rounding, so callers should compare with tolerance.
    """
    return value * 9.0 / 5.0 + 32.0


def fahrenheit_to_celsius(value):
    """Convert a finite real Fahrenheit value to an ordinary Celsius float.

    This pure conversion performs no physical-range validation. Floating-point
    arithmetic may introduce rounding, so callers should compare with tolerance.
    """
    return (value - 32.0) * 5.0 / 9.0
