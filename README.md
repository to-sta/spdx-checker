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

spdx_checker.check_license("MIT", ["example1.py", "example2.svelte", "example3.html"])
```

## Development

Issues with uv caching

```
To force uv to ignore existing installed versions, pass --reinstall to any installation command (e.g., uv sync --reinstall or uv pip install --reinstall ...).
```

## License

[MIT](LICENSE)