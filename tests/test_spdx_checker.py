import spdx_checker
import unittest


class TestSpdxChecker(unittest.TestCase):
    def test_check_license_raises_value_error(self):
        with self.assertRaises(ValueError):
            spdx_checker.check_license(
                "MIT",
                [
                    "tests/first/example.py",
                    "tests/first/second/example.vue",
                    "tests/first/second/third/example.html",
                    "tests/first/second/third/fourth/example.css",
                ],
            )


if __name__ == "__main__":
    unittest.main()
