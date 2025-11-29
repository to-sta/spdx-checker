# SPDX-License-Identifier: MIT
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
    # WINDOWS only, workaround for Python versions < 3.13.
    LIB_DIR = os.path.join(INSTALL_BASE, "libs")


class ZigBuilder(build_ext):
    """Build extension with zig."""

    def build_extension(self, ext) -> None:
        system = platform.system()
        is_windows = system == "Windows"
        is_macos = system == "Darwin"

        out_path = self.get_ext_fullpath(ext.name)
        cmd = [
            "zig",
            "build-lib",
            "-lc",
            "-dynamic",
            "-D",
            "ReleaseFast",
            "-I",
            INCLUDE_DIR,
            f"-femit-bin={out_path}",
        ]

        if is_windows:
            cmd.extend(["-L", LIB_DIR, "-l", "python3"])
        elif is_macos:
            cmd.extend(["-target", "aarch64-macos.11.0", "-fallow-shlib-undefined"])

        cmd.append(ext.sources[0])
        self.spawn(cmd)
