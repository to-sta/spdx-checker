"""
SPDX License Checker - Type Stub File (package layout)

This stub file provides type hints for the Zig-compiled spdx_checker extension.
"""

def check_license(target_license: str, file_paths: list[str], extensions: list[str] | None = None, exclude: list[str] | None = None, fix: bool = False, continue_on_error: bool = True) -> int:
    """
    Checks against a list of allowed SPDX Licenses and then checks each file's
    first line against the target license.

    Parameters
    ----------
    target_license : str
        The SPDX license identifier to check against (e.g., "MIT", "Apache-2.0").
    file_paths : list[str]
        A list of file paths to check for license headers.
    extensions : list[str] | None, optional
        A list of file extensions to include in the check. If None, all files are checked
    exclude : list[str] | None, optional
        A list of glob patterns to exclude certain files from the check.
    fix : bool, optional (default=False)
        If True, attempts to fix files that do not match the target license by adding SPDX license headers.
    continue_on_error : bool, optional (default=True)
        If True, continues checking other files even if one file fails the license check.

    Returns
    -------
    int
        0 if all files match the target license

    Raises
    ------
    ValueError
        If any file does not match the target license.
    """
    ...

__all__ = ["check_license"]