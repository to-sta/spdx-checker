# SPDX License Checker

`spdx-checker` is a fast Python package for validating and analyzing SPDX license headers in your projects. It leverages Zig for exceptional speed and efficiency. The checker raises an error immediately if any file contains an incorrect or missing license header.

### Supported platforms
The wheels published by the GitHub Actions workflow are built with cibuildwheel. The table below lists all supported operating systems and Python versions for the pre-built wheels.

| Operating System | Python versions / ABI |
|---|---|
| macOS (arm64) | 3.11, 3.12, 3.13 (cp311, cp312, cp313 — macosx_arm64) |
| manylinux (x86_64) | 3.11, 3.12, 3.13 (cp311, cp312, cp313 — manylinux_x86_64) |
| musllinux (x86_64) | 3.11, 3.12, 3.13 (cp311, cp312, cp313 — musllinux_x86_64) |
| Windows (amd64) | 3.11, 3.12, 3.13 (cp311, cp312, cp313 — win_amd64) |


## Example Usage

```python
import spdx_checker

spdx_checker.check_license(
    "MIT",
    ["example1.py", "example2.svelte", "example3.html"],
    extensions=["zig", "py", "svelte"],
    exclude=["**/__init__.py"],
    fix=True,
    continue_on_error=False,
)
```

## Development

Install the project in editable mode and run both test suites:

```shell
uv pip install -e .
uv run pytest
zig test extension/tests.zig
```

The native extension is organized into four boundaries:

- `extension/core`: configuration, checking, headers, and aggregate results
- `extension/filesystem`: path selection, glob matching, and file mutation
- `extension/presentation`: streamed terminal output and colors
- `extension/python`: CPython argument, exception, and module adapters

The checker core does not depend on CPython or terminal presentation. It emits
transient events and returns a constant-size aggregate report, so report memory
does not grow with the number of checked files.

## License

[MIT](LICENSE)
