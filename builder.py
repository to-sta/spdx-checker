import sysconfig
import platform
from setuptools.command.build_ext import build_ext
from setuptools import Extension, setup
from setuptools.build_meta import build_wheel as _build_wheel
from setuptools.build_meta import build_sdist as _build_sdist


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


def build_wheel(wheel_directory, config_settings=None, metadata_directory=None):
    spdx_checker = Extension(name="spdx_checker", sources=["extension/main.zig"])

    original_setup = setup

    def custom_setup(*args, **kwargs):
        kwargs.update(
            {
                "ext_modules": [spdx_checker],
                "cmdclass": {"build_ext": ZigBuilder},
                "py_modules": ["builder"],
            }
        )
        return original_setup(*args, **kwargs)

    # Replace setup temporarily
    import setuptools

    setuptools.setup = custom_setup

    try:
        return _build_wheel(wheel_directory, config_settings, metadata_directory)
    finally:
        setuptools.setup = original_setup


def build_sdist(sdist_directory, config_settings=None):
    return _build_sdist(sdist_directory, config_settings)
