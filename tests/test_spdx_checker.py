import spdx_checker

spdx_checker.check_license(
    "MIT",
    [ "first/example.py", "first/second/example.vue", "first/second/third/example.html", "first/second/third/fourth/example.css"]
)

