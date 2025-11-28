pub const py = @cImport({
    @cDefine("Py_LIMITED_API", "0x030D0000");
    @cDefine("PY_SSIZE_T_CLEAN", {});
    @cInclude("Python.h");
});