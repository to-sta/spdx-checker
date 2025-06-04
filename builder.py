import os
import sysconfig
import platform
from setuptools.command.build_ext import build_ext
import re


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
CIBW_ARCH = os.getenv("CIBW_ARCH")
# CIBW_PLATFORM = os.getenv("CIBW_PLATFORM")


def get_zig_target_triple_from_CIBW() -> str:
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

    platform = os.environ.get("CIBW_PLATFORM")
    arch = os.environ.get("CIBW_ARCH")

    if platform is None or arch is None:
        raise RuntimeError("CIBW_PLATFORM or CIBW_ARCH not set")

    arch_map = {
        "x86_64": "x86_64",
        "i686": "x86",
        "aarch64": "aarch64",
    }
    os_map = {
        "windows": "windows",
        "linux": "linux",
        "macos": "macos",
    }

    zig_arch = arch_map.get(arch, arch)
    zig_os = os_map.get(platform, platform)

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

        if CIBW_ARCH:
            # CIBW_BUILD is set, so we are building in a CI environment
            cmd += ["-target", get_zig_target_triple_from_CIBW()]
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
