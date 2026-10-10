"""Verify the complete temperature library boundary with independent numeric expectations.

Only finite integer/float samples are in scope; invalid-input policies are unspecified.
"""

import unittest

from temperature import celsius_to_fahrenheit, fahrenheit_to_celsius


# Absolute error allowance for ordinary floating-point conversions in the accepted samples.
TOLERANCE = 1e-9


class TemperatureTests(unittest.TestCase):
    """Check public conversions, return types and composition without replacing real functions."""

    def test_celsius_reference_points(self):
        """CASE-01: Celsius reference integers yield expected Fahrenheit floats within tolerance."""
        for celsius, expected_fahrenheit in ((0, 32.0), (100, 212.0), (-40, -40.0)):
            with self.subTest(celsius=celsius, expected_fahrenheit=expected_fahrenheit):
                actual = celsius_to_fahrenheit(celsius)

                self.assertIs(type(actual), float)
                self.assertLessEqual(abs(actual - expected_fahrenheit), TOLERANCE)

    def test_fahrenheit_reference_points(self):
        """CASE-02: Fahrenheit reference integers yield expected Celsius floats within tolerance."""
        for fahrenheit, expected_celsius in ((32, 0.0), (212, 100.0), (-40, -40.0)):
            with self.subTest(fahrenheit=fahrenheit, expected_celsius=expected_celsius):
                actual = fahrenheit_to_celsius(fahrenheit)

                self.assertIs(type(actual), float)
                self.assertLessEqual(abs(actual - expected_celsius), TOLERANCE)

    def test_fractional_conversions(self):
        """CASE-03: Positive/negative fractions retain expected float values in both directions."""
        for celsius, fahrenheit in ((37.5, 99.5), (-12.5, 9.5)):
            with self.subTest(direction="C to F", celsius=celsius, expected=fahrenheit):
                actual = celsius_to_fahrenheit(celsius)

                self.assertIs(type(actual), float)
                self.assertLessEqual(abs(actual - fahrenheit), TOLERANCE)

            with self.subTest(direction="F to C", fahrenheit=fahrenheit, expected=celsius):
                actual = fahrenheit_to_celsius(fahrenheit)

                self.assertIs(type(actual), float)
                self.assertLessEqual(abs(actual - celsius), TOLERANCE)

    def test_round_trips(self):
        """CASE-04: Both real compositions yield floats and recover each input within 1e-9."""
        for original in (-100.5, -40, 0, 37.5, 100, 1000.25):
            with self.subTest(direction="C to F to C", original=original):
                intermediate = celsius_to_fahrenheit(original)
                final = fahrenheit_to_celsius(intermediate)

                self.assertIs(type(intermediate), float)
                self.assertIs(type(final), float)
                self.assertLessEqual(abs(final - original), TOLERANCE)

            with self.subTest(direction="F to C to F", original=original):
                intermediate = fahrenheit_to_celsius(original)
                final = celsius_to_fahrenheit(intermediate)

                self.assertIs(type(intermediate), float)
                self.assertIs(type(final), float)
                self.assertLessEqual(abs(final - original), TOLERANCE)


if __name__ == "__main__":
    unittest.main()
