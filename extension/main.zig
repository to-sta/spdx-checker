// SPDX-License-Identifier: MIT
//! Root module for the CPython extension.

const python_module = @import("python/module.zig");
const PyObject = @import("python/c_api.zig").py.PyObject;

pub export fn PyInit_spdx_checker() [*]PyObject {
    return python_module.init();
}
