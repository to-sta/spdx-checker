// SPDX-License-Identifier: MIT

const py = @import("c_api.zig").py;
const ParseError = @import("arguments.zig").ParseError;
const result = @import("../core/result.zig");

extern var PyExc_ValueError: [*c]py.PyObject;

pub fn setParseError(parse_error: ParseError) void {
    const message = switch (parse_error) {
        error.ParseFailed => "Failed to parse arguments",
        error.InvalidList => "Invalid list provided",
        error.InvalidListItem => "Invalid list item",
        error.InvalidString => "Expected list of strings",
        error.OutOfMemory => "Out of memory",
    };
    py.PyErr_SetString(PyExc_ValueError, message);
}

pub fn setCheckError(report: result.CheckReport) void {
    const message = if (report.stop_reason) |reason| switch (reason) {
        .file_open_failed => "Could not open file",
        .fix_failed => "Could not add license header to file",
        .license_mismatch => "File does not match target license.",
    } else "Some files did not match the target license.";
    py.PyErr_SetString(PyExc_ValueError, message);
}
