"""
SPDX License Checker - Type Stub File (package layout)

This stub file provides type hints for the Zig-compiled spdx_checker extension.
"""


def check_license(target_license: str, file_paths: list[str]) -> int:
    """
    Checks against a list of allowed SPDX Licenses and then checks each file's 
    first line against the target license.

    Parameters
    ----------
    target_license : str
        The SPDX license identifier to check against (e.g., "MIT", "Apache-2.0").
    file_paths : list[str]
        A list of file paths to check for license headers.

    Returns
    -------
    int
        The number of files that contain the target license in their first line.

    Raises
    ------
    ValueError
        If the target license is not a valid SPDX license identifier.
        If any file does not match the target license.

    Examples
    --------
    >>> import spdx_checker
    >>> spdx_checker.check_license("MIT", ["file1.py", "file2.py"])
    2
    """
    ...
