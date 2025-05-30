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

        if is_windows:
            cmd += ["-l", "python3"]
        elif is_macos:
            cmd += ["-l", 'python' + PYTHON_VERSION]

        cmd.append(ext.sources[0])

        self.spawn(cmd)

