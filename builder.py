import os
import sysconfig
import platform
from setuptools.command.build_ext import build_ext


INSTALL_BASE = sysconfig.get_config_var("installed_base")
LIB_DIR = sysconfig.get_config_var("LIBDIR")
INCLUDE_DIR = sysconfig.get_config_var("INCLUDEPY")
PYTHON_VERSION = sysconfig.get_config_var("py_version_short")
PACKAGE_NAME = "spdx_checker"

if LIB_DIR is None:
    # WINODWS only, workaround for Python versions < 3.13.
    LIB_DIR = os.path.join(INSTALL_BASE, "libs")

# Zig Targets to build for different platforms
# <cpu-arch>-<os>-<abi>
CIBW_BUILD = os.getenv("CIBW_BUILD")
# CIBW_PLATFORM = os.getenv("CIBW_PLATFORM")


def get_zig_target_triple_from_CIBW(cibw_build: str) -> str:
    """
    Get the Zig target triple from the CIBW_BUILD environment variable.
    This is used to determine the target architecture and OS for building.

    CIBW_BUILD is expected to be in the format:
    cp<pyver>-<os>_<arch>
    where <pyver> is the Python version, <os> is the operating system, and <arch> is the architecture.
    E.g. "cp36-macosx_x86_64" or "cp311-macosx_arm64".

    Zig target triples are in the format:
    <cpu-arch>-<os>-gnu
    where <cpu-arch> is the architecture (e.g., x86_64, aarch64) and <os> is the operating system (e.g., linux, macos, windows).
    E.g. "x86_64-macos-gnu" or "aarch64-linux-gnu".

    This function will translate the CIBW_BUILD format to the Zig target triple format.
    E.g. "cp311-macosx_arm64" -> "aarch64-macos-gnu".


    Returns
    -------
    str: The Zig target triple in the format <cpu-arch>-<os>-gnu.

    Raises
    -------
    ValueError: If the CIBW_BUILD format is invalid.
    """
    if not cibw_build:
        raise ValueError("CIBW_BUILD is not set or empty")

    # Match patterns like cp311-macosx_arm64 or cp36-manylinux_x86_64
    # Split based on '-' and then '_'
    try:
        _, os_arch = cibw_build.split("-", 1)
        os_part, arch_part = os_arch.split("_", 1)
    except ValueError:
        raise ValueError(f"Invalid CIBW_BUILD format: {cibw_build}")

    # Map CIBW arch to Zig arch
    arch_map = {
        "x86_64": "x86_64",
        "amd64": "x86_64",
        "i686": "x86",
        "arm64": "aarch64",
        "aarch64": "aarch64",
    }
    # Map CIBW OS to Zig OS
    os_map = {
        "manylinux": "linux",
        "linux": "linux",
        "macosx": "macos",
        "win": "windows",
        "windows": "windows",
    }

    if arch_part not in arch_map:
        raise ValueError(f"Unknown architecture: {arch_part}")
    if os_part not in os_map:
        raise ValueError(f"Unknown OS: {os_part}")

    zig_arch = arch_map[arch_part]
    zig_os = os_map[os_part]

    return f"{zig_arch}-{zig_os}"


class ZigBuilder(build_ext):
    def build_extension(self, ext) -> None:
        is_windows = platform.system() == "Windows"
        is_macos = platform.system() == "Darwin"

        cmd = [
            "zig",
            "build-lib",
            "-lc",
            "-dynamic",
            "-D",
            "ReleaseFast",
            "-I",
            INCLUDE_DIR,
            "-L",
            LIB_DIR,
            f"-femit-bin={self.get_ext_fullpath(ext.name)}",
        ]

        if CIBW_BUILD:
            # CIBW_BUILD is set, so we are building in a CI environment
            cmd += ["-target", get_zig_target_triple_from_CIBW(cibw_build=CIBW_BUILD)]
        else:
            raise ValueError(
                "CIBW_BUILD environment variable is not set. "
                "This script is intended to be run in a CI environment."
            )

        if is_windows:
            cmd += ["-l", "python3"]
        elif is_macos:
            cmd += ["-l", "python" + PYTHON_VERSION]

        cmd.append(ext.sources[0])

        self.spawn(cmd)
