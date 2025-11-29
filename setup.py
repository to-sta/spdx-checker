# SPDX-License-Identifier: MIT
from setuptools import setup, Extension, find_packages
from pathlib import Path

from builder import ZigBuilder

spdx_checker_ext = Extension(
    name="spdx_checker.spdx_checker",
    sources=["extension/main.zig"],
    py_limited_api=True,
)

setup(
    ext_modules=[spdx_checker_ext],
    cmdclass={"build_ext": ZigBuilder},
    long_description=(Path(__file__).parent / "README.md").read_text(encoding="utf-8"),
    long_description_content_type="text/markdown",
    packages=find_packages(include=["spdx_checker"]),
    package_data={
        "spdx_checker": [
            "py.typed",
            "__init__.pyi",
            "spdx_checker.pyi",
        ]
    },
    include_package_data=True,
    python_requires=">=3.11",
    options={"bdist_wheel": {"py_limited_api": "cp311"}},
    zip_safe=False,
)
