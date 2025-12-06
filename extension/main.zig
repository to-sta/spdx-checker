// SPDX-License-Identifier: MIT
const std = @import("std");
const py = @import("python.zig").py;
const ParseError = @import("errors.zig").ParseError;
const Colors = @import("utils/output.zig").Colors;
const filter = @import("utils/filter.zig");
const fix = @import("utils/fix.zig");
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

fn spdx_license_checker(self: [*c]PyObject, args: [*c]PyObject, kwargs: [*c]PyObject) callconv(.c) [*c]PyObject {
    _ = self;

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true, .thread_safe = true }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

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
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);

    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    // Determines if the terminal supports colors
    // if not, Colors.select() will return no-op color codes
    const colors = Colors.select();

    stdout.print("{s}spdx_checker {s}v{d}.{d}.{d}{s}\n\n", .{ colors.bold, colors.purple, MAJOR, MINOR, PATCH, colors.reset }) catch {};
    stdout.print("{s}Parsed Arguments:{s}\n\n", .{ colors.bold, colors.reset }) catch {};
    stdout.print("\tTarget License:\t\t{s}\"{s}\"{s}\n", .{ colors.blue, parsed_args.target_license, colors.reset }) catch {};
    stdout.print("\tFix Mode:\t\t{s}{}{s}\n", .{ colors.blue, parsed_args.fix, colors.reset }) catch {};
    stdout.print("\tContinue on Error:\t{s}{}{s}\n", .{ colors.blue, parsed_args.continue_on_error, colors.reset }) catch {};
    stdout.print("\tExtensions:\t\t", .{}) catch {};
    for (parsed_args.extensions) |ext| {
        stdout.print("{s}.{s}{s} ", .{ colors.green, ext, colors.reset }) catch {};
    }
    stdout.print("\n\tExclude:\t\t", .{}) catch {};
    for (parsed_args.exclude) |pattern| {
        stdout.print("{s}{s}{s} ", .{ colors.red, pattern, colors.reset }) catch {};
    }
    stdout.print("\n", .{}) catch {};

    const start_nanos = std.time.nanoTimestamp();

    const cwd = std.fs.cwd();
    var checked_files: usize = 0;
    var matched_files: usize = 0;
    var line_buffer: [256]u8 = undefined;

    // Filter file paths by extensions
    const original_file_count = parsed_args.file_paths.len;
    const is_filtered = filter.filterByExtensions(allocator, parsed_args.extensions, &parsed_args.file_paths) catch {
        py.PyErr_SetString(PyExc_ValueError, "Failed to filter file paths by extensions.");
        return null;
    };

    const is_excluded = filter.filterByGlobPattern(allocator, parsed_args.exclude, &parsed_args.file_paths) catch {
        py.PyErr_SetString(PyExc_ValueError, "Failed to filter file paths by exclude patterns.");
        return null;
    };


    // Check if file paths list length is zero after filtering
    if (parsed_args.file_paths.len == 0) {
        stdout.print("\n{s}No files to process after filtering by provided extensions.{s}\n\n", .{ colors.yellow, colors.reset }) catch {};
        return py.PyLong_FromLong(0);
    }

    stdout.print("\n\n{s}Warnings / Errors:{s}\n\n", .{ colors.bold, colors.reset }) catch {};
    for (parsed_args.file_paths) |file_path| {
        // Increment checked files count, so it can be printed in summary later
        checked_files += 1;

        const trimmed_path = std.mem.trim(u8, file_path, " \t\n\r");

        if (trimmed_path.len == 0) {
            stdout.print("{s}Warning:{s} Skipping empty file path.\n", .{ colors.yellow, colors.reset }) catch {};
            continue;
        }

        const file = cwd.openFile(trimmed_path, .{ .mode = .read_write }) catch |err| {
            stdout.print("{s}E:{s} Could not open file: {s} {}\n", .{ colors.red, colors.reset, trimmed_path, err }) catch {};
            if (!parsed_args.continue_on_error) {
                py.PyErr_SetString(PyExc_ValueError, "Could not open file");
                return null;
            } else {
                continue;
            }
        };
        defer file.close();

        // Read first line
        const bytes_read = file.read(line_buffer[0..]) catch {
            stdout.print("{s}E:{s} reading file: {s}\n", .{ colors.red, colors.reset, trimmed_path }) catch {};
            continue;
        };

        // Find newline position
        const newline_pos = std.mem.indexOf(u8, line_buffer[0..bytes_read], "\n") orelse bytes_read;
        const first_line = line_buffer[0..newline_pos];

        if (std.mem.indexOf(u8, first_line, parsed_args.target_license) != null) {
            matched_files += 1;
        } else {
            if (parsed_args.fix) {

                // Here you would implement the fixing logic
                // For now, just print a message
                const file_extension = filter.getFileExtension(trimmed_path);

                fix.addLicenseHeader(allocator, parsed_args, file, file_extension) catch |err| {
                    stdout.print("{s}E:{s} {s}\t{}\n", .{ colors.red, colors.reset, trimmed_path, err }) catch {};
                    if (!parsed_args.continue_on_error) {
                        py.PyErr_SetString(PyExc_ValueError, "Could not add license header to file");
                        return null;
                    } else {
                        continue;
                    }
                };
                stdout.print("{s}F:{s}{s} target license mismatch '{s}'.\n", .{ colors.green, colors.reset, trimmed_path, parsed_args.target_license }) catch {};
                matched_files += 1;
                continue;
            } else if (parsed_args.continue_on_error) {
                stdout.print("{s}W:{s}{s} target license mismatch '{s}'.\n", .{ colors.yellow, colors.reset, trimmed_path, parsed_args.target_license }) catch {};
                continue;
            } else {
                stdout.print("File '{s}' does not match target license '{s}'.\n", .{ trimmed_path, parsed_args.target_license }) catch {};
                py.PyErr_SetString(PyExc_ValueError, "File does not match target license.");
                const end_nanos = std.time.nanoTimestamp();
                const elapsed_ms = @divTrunc(end_nanos - start_nanos, std.time.ns_per_ms);
                stdout.print("Files with license '{s}': {d} / {d} Files\n", .{ parsed_args.target_license, matched_files, checked_files }) catch {};
                stdout.print("License check completed in ({d}ns) {d}ms \n", .{ end_nanos - start_nanos, elapsed_ms }) catch {};
                return null;
            }
        }
    }

    const end_nanos = std.time.nanoTimestamp();
    const elapsed_ms = @divTrunc(end_nanos - start_nanos, std.time.ns_per_ms);

    stdout.print("\n{s}Summary:{s}\n\n", .{ colors.bold, colors.reset }) catch {};
    stdout.print("Files with license:\t\t{d}/{d} Files\n", .{ matched_files, checked_files }) catch {};
    stdout.print("License check completed in {s}({d}ns) {d}ms {s}\n\n", .{ colors.bold, end_nanos - start_nanos, elapsed_ms, colors.reset }) catch {};

    if (is_filtered) {
        stdout.print("{s}Note:{s} File paths were filtered down from {d} to {d} by extensions provided.\n\n", .{ colors.yellow, colors.reset, original_file_count, parsed_args.file_paths.len }) catch {};
    }

    if (is_excluded) {
        stdout.print("{s}Note:{s} File paths were filtered down by exclude patterns provided.\n\n", .{ colors.yellow, colors.reset }) catch {};
    }

    if (matched_files != checked_files) {
        // Error case: not all files matched
        py.PyErr_SetString(PyExc_ValueError, "Some files did not match the target license.");
        return null;
    }

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
