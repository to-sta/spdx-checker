// SPDX-License-Identifier: MIT
//! CPython extension entry point and adapter orchestration.

const std = @import("std");
const py = @import("c_api.zig").py;
const arguments = @import("arguments.zig");
const exceptions = @import("exceptions.zig");
const checker = @import("../core/checker.zig");
const colors = @import("../presentation/colors.zig");
const TextReporter = @import("../presentation/text_reporter.zig").TextReporter;

const PyObject = py.PyObject;
const stdout_buffer_size = 1024;

fn checkLicense(self: [*c]PyObject, args: [*c]PyObject, kwargs: [*c]PyObject) callconv(.c) [*c]PyObject {
    _ = self;

    var general_purpose_allocator = std.heap.DebugAllocator(.{ .safety = true, .thread_safe = true }){};
    defer _ = general_purpose_allocator.deinit();
    const allocator = general_purpose_allocator.allocator();

    var io_threaded: std.Io.Threaded = .init(allocator, .{});
    defer io_threaded.deinit();
    const io = io_threaded.io();

    var parsed_arguments = arguments.parse(args, kwargs, allocator) catch |parse_error| {
        if (py.PyErr_Occurred() == null) exceptions.setParseError(parse_error);
        return null;
    };
    defer parsed_arguments.deinit();
    const config = parsed_arguments.config();

    var stdout_buffer: [stdout_buffer_size]u8 = undefined;
    var stdout_file_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    var reporter = TextReporter{
        .stdout = stdout,
        .colors = colors.select(io),
        .config = config,
    };
    reporter.printArguments();

    const report = checker.run(allocator, io, config, &reporter);
    reporter.printReport(report);

    if (!report.succeeded()) {
        exceptions.setCheckError(report);
        return null;
    }
    return py.PyLong_FromLong(0);
}

var methods = [_]py.PyMethodDef{
    .{
        .ml_name = "check_license",
        .ml_meth = @ptrCast(&checkLicense),
        .ml_flags = py.METH_VARARGS | py.METH_KEYWORDS,
        .ml_doc = "Check whether files contain the requested SPDX license header.",
    },
    .{
        .ml_name = null,
        .ml_meth = null,
        .ml_flags = 0,
        .ml_doc = null,
    },
};

var module = py.PyModuleDef{
    .m_base = std.mem.zeroes(py.PyModuleDef_Base),
    .m_name = "spdx_checker",
    .m_doc = null,
    .m_size = -1,
    .m_methods = &methods,
    .m_slots = null,
    .m_traverse = null,
    .m_clear = null,
    .m_free = null,
};

pub fn init() [*]PyObject {
    return py.PyModule_Create(&module);
}
