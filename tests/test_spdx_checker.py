import pytest
import spdx_checker

def test_spdx_checker():
    """
    Test the SPDX checker with a specific license and file paths.
    This test checks if the SPDX checker can correctly identify and fix
    license issues in the specified files.
    """
    # Run the SPDX checker with the specified parameters
    result = spdx_checker.check_license(
        target_license="GPL-3.0",
        file_paths=[
            "tests/first/example.py",
            "tests/first/second/example.vue",
            "tests/first/second/__init__.py",
            "tests/first/second/third/example.html",
            "tests/first/second/third/fourth/example.css",
        ],
        extensions=["py", "vue", "html", "css"],
        exclude=[
            "**/__init__.py",
        ],
        fix=False,
        continue_on_error=True,
    )

    # Assert that the result is as expected
    assert result is not None
    assert result == 0
