import sysconfig
import platform
from setuptools.command.build_ext import build_ext

INSTALL_BASE = sysconfig.get_config_var("installed_base")
LIB_DIR = sysconfig.get_config_var("LIBDIR")
INCLUDE_DIR = sysconfig.get_config_var("INCLUDEPY")
PYTHON_VERSION = sysconfig.get_config_var("py_version_short")
PACKAGE_NAME = "spdx_checker"


class ZigBuilder(build_ext):
    def build_extension(self, ext) -> None:

        is_windows = platform.system() == "Windows"

        self.spawn(
            [
                "zig",
                "build-lib",
                "-lc",
                "-dynamic",
                "-D",
                "ReleaseFast",
                # *(["-target", "x86-64-windows-msvc"] if is_windows else []),
                "-I",
                INCLUDE_DIR,
                "-L",
                LIB_DIR,
                f"-femit-bin={self.get_ext_fullpath(ext.name)}",
                "-l",
                f"{'python3' if is_windows else 'python' + PYTHON_VERSION}",
                ext.sources[0],
            ]
        )
