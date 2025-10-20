# SPDX License Checker

`spdx-checker` is a fast Python package for validating and analyzing SPDX license headers in your projects. It leverages Zig for exceptional speed and efficiency. The checker raises an error immediately if any file contains an incorrect or missing license header.

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