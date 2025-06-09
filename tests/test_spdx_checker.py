import spdx_checker

spdx_checker.check_license(
    "MIT",
    [
        "tests/first/example.py",
        "tests/first/second/example.vue",
        "tests/first/second/third/example.html",
        "tests/first/second/third/fourth/example.css",
    ],
)
