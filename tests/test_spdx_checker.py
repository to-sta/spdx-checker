import spdx_checker
import pytest


def test_spdx_checker_accepts_matching_files():
    """
    Test the SPDX checker with a specific license and file paths.
    This test checks if the SPDX checker can correctly identify and fix
    license issues in the specified files.
    """
    # Run the SPDX checker with the specified parameters
    result = spdx_checker.check_license(
        target_license="MIT",
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


def test_optional_lists_accept_none():
    result = spdx_checker.check_license(
        target_license="MIT",
        file_paths=["tests/first/example.py"],
        extensions=None,
        exclude=None,
    )

    assert result == 0


def test_mismatch_raises_value_error(tmp_path):
    source_file = tmp_path / "example.py"
    source_file.write_text("print('missing header')\n", encoding="utf-8")

    with pytest.raises(ValueError, match="does not match target license"):
        spdx_checker.check_license(
            target_license="MIT",
            file_paths=[str(source_file)],
            continue_on_error=False,
        )


@pytest.mark.parametrize(
    "first_line",
    [
        "#ifndef Py_LIMITED_API",
        "# SPDX-License-Identifier: MIT-0",
        "MIT",
    ],
)
def test_target_license_must_match_exact_spdx_header(tmp_path, first_line):
    source_file = tmp_path / "example.py"
    source_file.write_text(f"{first_line}\n", encoding="utf-8")

    with pytest.raises(ValueError, match="does not match target license"):
        spdx_checker.check_license(
            target_license="MIT",
            file_paths=[str(source_file)],
            continue_on_error=False,
        )


def test_fix_adds_header(tmp_path):
    source_file = tmp_path / "example.py"
    source_file.write_text("print('missing header')\n", encoding="utf-8")

    result = spdx_checker.check_license(
        target_license="MIT",
        file_paths=[str(source_file)],
        fix=True,
    )

    assert result == 0
    assert source_file.read_text(encoding="utf-8").startswith(
        "# SPDX-License-Identifier: MIT\n"
    )
