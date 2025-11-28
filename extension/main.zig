const std = @import("std");
const py = @import("python.zig").py;
const ParseError = @import("errors.zig").ParseError;
const Colors = @import("utils.zig").Colors;
const utils = @import("utils.zig");
const parse = @import("parse.zig");

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

fn spdx_license_checker(self: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    _ = self;

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = false, .thread_safe = true }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var parsed_args = parse.Arguments.parse(args, allocator) catch |err| {
        // Return null on error, because Python exception is already set.
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

    stdout.print("{s}spdx_checker {s}v0.1.11{s}\n\n", .{Colors.Bold, Colors.Purple, Colors.Reset}) catch {};
    stdout.print("{s}Parsed Arguments:{s}\n\n", .{Colors.Bold, Colors.Reset}) catch {};
    stdout.print("\tTarget License:\t\t{s}\"{s}\"{s}\n", .{Colors.Blue, parsed_args.target_license, Colors.Reset}) catch {};
    stdout.print("\tFix Mode:\t\t{s}{}{s}\n", .{Colors.Blue, parsed_args.fix, Colors.Reset}) catch {};
    stdout.print("\tContinue on Error:\t{s}{}{s}\n\n", .{Colors.Blue, parsed_args.continue_on_error, Colors.Reset}) catch {};

    const start_nanos = std.time.nanoTimestamp();

    // Validate target license
    const cwd = std.fs.cwd();

    var checked_files: usize = 0;
    var matched_files: usize = 0;
    var line_buffer: [256]u8 = undefined;

    stdout.print("{s}Warnings / Errors:{s}\n\n", .{Colors.Bold, Colors.Reset}) catch {};
    for (parsed_args.file_paths) |file_path| {
        // Increment checked files count, so it can be printed in summary later
        checked_files += 1;

        const trimmed_path = std.mem.trim(u8, file_path, " \t\n\r");

        if (trimmed_path.len == 0) {
            stdout.print("{s}Warning:{s} Skipping empty file path.\n", .{ Colors.Yellow, Colors.Reset }) catch {};
            continue;
        }

        const file = cwd.openFile(trimmed_path, .{ .mode = .read_write }) catch |err| {
            std.debug.print("{s}Error:{s} Could not open file: {s} {}\n", .{ Colors.Red, Colors.Reset, trimmed_path, err });
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
            std.debug.print("Error reading file: {s}\n", .{trimmed_path});
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
                const file_extension = utils.getFileExtension(trimmed_path);

                utils.addLicenseHeader(allocator, parsed_args, file, file_extension) catch |err| {
                    stdout.print("{s}E:{s} {s}\t{}\n", .{ Colors.Red, Colors.Reset, trimmed_path, err }) catch {};
                    if (!parsed_args.continue_on_error) {
                        py.PyErr_SetString(PyExc_ValueError, "Could not add license header to file");
                        return null;
                    } else {
                        continue;
                    }
                };
                stdout.print("{s}F:{s} File '{s}' does not match target license '{s}'.\n", .{ Colors.Green, Colors.Reset, trimmed_path, parsed_args.target_license }) catch {};
                matched_files += 1;
                continue;
            } else if (parsed_args.continue_on_error) {
                stdout.print("{s}W:{s} File '{s}' does not match target license '{s}'. Continuing due to continue_on_error flag.\n", .{ Colors.Yellow, Colors.Reset, trimmed_path, parsed_args.target_license }) catch {};
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

    stdout.print("\n{s}Summary:{s}\n\n", .{ Colors.Bold, Colors.Reset }) catch {};
    stdout.print("Files with license {s}\"{s}\"{s}:\t{d}/{d} Files\n", .{ Colors.Blue,  parsed_args.target_license, Colors.Reset, matched_files, checked_files }) catch {};
    stdout.print("License check completed in {s}({d}ns) {d}ms {s}\n\n", .{ Colors.Bold,end_nanos - start_nanos, elapsed_ms, Colors.Reset}) catch {};
    
    if (matched_files != checked_files) {
        // Error case: not all files matched
        py.PyErr_SetString(PyExc_ValueError, "Some files did not match the target license.");
        return null;
    }

    // Return None on success
    const none = py.Py_GetConstantBorrowed(py.Py_CONSTANT_NONE);
    py.Py_IncRef(none);
    return py.PyLong_FromLong(0);
}

var Methods = [_]PyMethodDef{
    PyMethodDef{
        .ml_name = "check_license",
        .ml_meth = spdx_license_checker,
        .ml_flags = py.METH_VARARGS,
        .ml_doc =
        \\Checks agains a list of allowed SPDX Licenses and then checks each file's 
        \\first line against the target license.
        \\
        \\Parameters
        \\----------
        \\target_license: str
        \\    The SPDX license identifier to check against.
        \\file_paths: list
        \\    file_paths: A list of file paths to check.
        \\fix: bool, optional
        \\    If True, the tool will attempt to add the correct SPDX license header
        \\    to files that do not match the target license. Default is False.
        \\continue_on_error: bool, optional
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
