from setuptools import setup, Extension
from pathlib import Path

from builder import ZigBuilder

spdx_checker = Extension(name="spdx_checker", sources=["extension/main.zig"], py_limited_api=True)

setup(
    ext_modules=[spdx_checker],
    cmdclass={"build_ext": ZigBuilder},
    long_description=(Path(__file__).parent / "README.md").read_text(encoding="utf-8"),
    long_description_content_type="text/markdown",
    py_modules=["builder"],
    packages=["spdx_checker"],
    package_data={"spdx_checker": ["py.typed", "__init__.pyi"]},
    python_requires=">=3.11",
)
