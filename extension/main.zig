// SPDX-License-Identifier: MIT
const std = @import("std");
const py = @import("python.zig").py;
const ParseError = @import("errors.zig").ParseError;
const Colors = @import("utils/output.zig").Colors;
const printLine = @import("utils/output.zig").printLine;
const checker = @import("checker.zig");
const parse = @import("parse.zig");

// Version information
const MAJOR = @import("version.zig").MAJOR;
const MINOR = @import("version.zig").MINOR;
const PATCH = @import("version.zig").PATCH;

// Aliases for Python C API types and functions
const PyObject = py.PyObject;
const PyMethodDef = py.PyMethodDef;
const PyModuleDef = py.PyModuleDef;
const PyModuleDef_Base = py.PyModuleDef_Base;
const Py_BuildValue = py.Py_BuildValue;
const PyModule_Create = py.PyModule_Create;
const METH_NOARGS = py.METH_NOARGS;
const PyArg_ParseTuple = py.PyArg_ParseTuple;
const PyLong_FromLong = py.PyLong_FromLong;
extern var PyExc_ValueError: [*c]py.PyObject;

/// Buffer backing the buffered stdout writer used for CLI-style output.
const stdout_buffer_size = 1024;

/// Sets a `ValueError` matching the given `checker.CheckError`.
fn setPyErrorForCheckError(err: checker.CheckError) void {
    const message = switch (err) {
        error.FilterByExtensionFailed => "Failed to filter file paths by extensions.",
        error.FilterByExcludeFailed => "Failed to filter file paths by exclude patterns.",
        error.FileOpenFailed => "Could not open file",
        error.FixFailed => "Could not add license header to file",
        error.LicenseMismatchStop => "File does not match target license.",
        error.SomeFilesMismatched => "Some files did not match the target license.",
    };
    py.PyErr_SetString(PyExc_ValueError, message);
}

fn printParsedArguments(stdout: *std.Io.Writer, colors: anytype, parsed_args: parse.Arguments) void {
    printLine(stdout, "{s}spdx_checker {s}v{d}.{d}.{d}{s}\n\n", .{ colors.bold, colors.purple, MAJOR, MINOR, PATCH, colors.reset });
    printLine(stdout, "{s}Parsed Arguments:{s}\n\n", .{ colors.bold, colors.reset });
    printLine(stdout, "\tTarget License:\t\t{s}\"{s}\"{s}\n", .{ colors.blue, parsed_args.target_license, colors.reset });
    printLine(stdout, "\tFix Mode:\t\t{s}{}{s}\n", .{ colors.blue, parsed_args.fix, colors.reset });
    printLine(stdout, "\tContinue on Error:\t{s}{}{s}\n", .{ colors.blue, parsed_args.continue_on_error, colors.reset });
    printLine(stdout, "\tExtensions:\t\t", .{});
    for (parsed_args.extensions) |ext| {
        printLine(stdout, "{s}.{s}{s} ", .{ colors.green, ext, colors.reset });
    }
    printLine(stdout, "\n\tExclude:\t\t", .{});
    for (parsed_args.exclude) |pattern| {
        printLine(stdout, "{s}{s}{s} ", .{ colors.red, pattern, colors.reset });
    }
    printLine(stdout, "\n", .{});
}

fn spdx_license_checker(self: [*c]PyObject, args: [*c]PyObject, kwargs: [*c]PyObject) callconv(.c) [*c]PyObject {
    _ = self;

    var gpa = std.heap.DebugAllocator(.{ .safety = true, .thread_safe = true }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // We're not running under `pub fn main`, so there's no std.process.Init
    // to pull an `io` handle from. Spin up our own Io backend instead.
    var io_threaded: std.Io.Threaded = .init(allocator, .{});
    defer io_threaded.deinit();
    const io = io_threaded.io();

    var parsed_args = parse.Arguments.parse(args, kwargs, allocator) catch |err| {
        // Check if a Python error is already set for missing arguments
        if (py.PyErr_Occurred() != null) {
            return null; // Just return null, Python error is already set
        }

        switch (err) {
            ParseError.ParseFailed => {
                py.PyErr_SetString(PyExc_ValueError, "Failed to parse arguments");
            },
            ParseError.InvalidList => {
                py.PyErr_SetString(PyExc_ValueError, "Invalid list provided");
            },
            ParseError.InvalidListItem => {
                py.PyErr_SetString(PyExc_ValueError, "Invalid list item");
            },
            ParseError.InvalidString => {
                py.PyErr_SetString(PyExc_ValueError, "Expected list of strings");
            },
            ParseError.OutOfMemory => {
                py.PyErr_SetString(PyExc_ValueError, "Out of memory");
            },
        }
        return null;
    };
    defer parsed_args.deinit();

    // Allocate a buffer for stdout
    var stdout_buffer: [stdout_buffer_size]u8 = undefined;
    var stdout_file_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    // Determines if the terminal supports colors
    // if not, Colors.select() will return no-op color codes
    const colors = Colors.select(io);

    printParsedArguments(stdout, colors, parsed_args);

    _ = checker.run(allocator, io, stdout, colors, &parsed_args) catch |err| {
        setPyErrorForCheckError(err);
        return null;
    };

    return py.PyLong_FromLong(0);
}

var Methods = [_]PyMethodDef{
    PyMethodDef{
        .ml_name = "check_license",
        .ml_meth = @ptrCast(&spdx_license_checker),
        .ml_flags = py.METH_VARARGS | py.METH_KEYWORDS,
        .ml_doc =
        \\Check if files contain the specified SPDX license identifier in the
        \\first line against the target license.
        \\
        \\Parameters
        \\----------
        \\target_license: str
        \\    The SPDX license identifier to check against.
        \\file_paths: list
        \\    file_paths: A list of file paths to check.
        \\fix: bool, optional (default=False)
        \\    If True, the tool will attempt to add the correct SPDX license header
        \\    to files that do not match the target license. Default is False.
        \\continue_on_error: bool, optional (default=False)
        \\    If True, the tool will continue checking other files even if one file
        \\    does not match the target license. Default is True.
        \\
        \\Returns
        \\-------
        \\bool
        \\    Returns a Python integer object (0) on success.
        \\    Raises ValueError and returns null on error.
        \\
        \\Raises
        \\-------
        \\ValueError
        \\    If the target license is not a valid SPDX license identifier.
        \\    If any file does not match the target license.
        \\
        \\Examples
        \\--------
        \\>>> import spdx_checker
        \\>>> spdx_checker.check_license("MIT", ["file1.txt", "file2.txt"])
        \\
        ,
    },
    PyMethodDef{
        .ml_name = null,
        .ml_meth = null,
        .ml_flags = 0,
        .ml_doc = null,
    },
};

const ModuleBase = extern struct {
    ob_refcnt: u64 = 1,
    ob_type: ?*u8 = null,
};

var module = PyModuleDef{
    .m_base = std.mem.zeroes(PyModuleDef_Base), // Safe zero initialization
    .m_name = "spdx_checker",
    .m_doc = null,
    .m_size = -1,
    .m_methods = &Methods,
    .m_slots = null,
    .m_traverse = null,
    .m_clear = null,
    .m_free = null,
};

pub export fn PyInit_spdx_checker() [*]PyObject {
    return PyModule_Create(&module);
}