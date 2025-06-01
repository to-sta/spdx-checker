const std = @import("std");
const py = @cImport({
    @cDefine("Py_LIMITED_API", "0x030D0000");
    @cDefine("PY_SSIZE_T_CLEAN", {});

    @cInclude("Python.h");
});
const print = std.debug.print;

const utils = @import("utils.zig");
const spdx_licenses = @import("licenses.zig").licensesIdentfiers;

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

fn checkIfLicenseIsValid(args: struct { target_license: []const u8 }) bool {
    for (spdx_licenses) |spdx_license| {
        if (std.mem.eql(u8, args.target_license, spdx_license)) {
            return true;
        }
    }
    return false;
}

fn spdx_license_checker(self: [*c]PyObject, args: [*c]PyObject) callconv(.C) [*c]PyObject {
    _ = self;

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true, .thread_safe = true }){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("MEMORY LEAK DETECTED!\n", .{});
        }
    }

    var target_license_ptr: [*:0]u8 = undefined;
    var file_paths_obj: [*c]PyObject = null;

    if (py.PyArg_ParseTuple(args, "sO!", &target_license_ptr, &py.PyList_Type, &file_paths_obj) == 0) {
        py.PyErr_SetString(py.PyExc_ValueError, "Expected two arguments: target_license (str), file_paths (list)");
        return null;
    }

    // Copy the license string from Python memory to Zig memory
    const license_len = std.mem.len(target_license_ptr);
    const target_license_slice = gpa.allocator().dupe(u8, target_license_ptr[0..license_len]) catch {
        py.PyErr_SetString(PyExc_ValueError, "Failed to allocate memory for target license.");
        return null;
    };
    defer gpa.allocator().free(target_license_slice);

    if (!checkIfLicenseIsValid(.{ .target_license = target_license_slice })) {
        py.PyErr_SetString(PyExc_ValueError, "Invalid target license.");
        return null;
    }

    var file_paths_string = std.ArrayList([]const u8).init(gpa.allocator());
    defer {
        for (file_paths_string.items) |path| {
            gpa.allocator().free(path);
        }
        file_paths_string.deinit();
    }

    const py_list_len = py.PyList_Size(file_paths_obj);
    if (py_list_len < 0) {
        py.PyErr_SetString(PyExc_ValueError, "Failed to get length of file_paths list.");
        return null;
    }
    var i: isize = 0;
    while (i < py_list_len) : (i += 1) {
        const item = py.PyList_GetItem(file_paths_obj, i);
        if (item == null or py.PyUnicode_Check(item) == 0) {
            py.PyErr_SetString(PyExc_ValueError, "All items in file_paths must be strings.");
            return null;
        }
        const py_bytes = py.PyUnicode_AsUTF8String(item);
        if (py_bytes == null) {
            py.PyErr_SetString(PyExc_ValueError, "Failed to decode file path as UTF-8.");
            return null;
        }
        defer py.Py_DecRef(py_bytes);
        const cstr = py.PyBytes_AsString(py_bytes);
        if (cstr == null) {
            py.PyErr_SetString(PyExc_ValueError, "Failed to extract UTF-8 bytes from file path.");
            return null;
        }
        const py_size = py.PyBytes_Size(py_bytes);
        if (py_size < 0) {
            py.PyErr_SetString(PyExc_ValueError, "Failed to get byte size of file path.");
            return null;
        }
        const cstr_len = @as(usize, @intCast(py_size));
        const path_slice = @as([*]const u8, @ptrCast(cstr))[0..cstr_len];

        const owned_path = gpa.allocator().dupe(u8, path_slice) catch {
            py.PyErr_SetString(PyExc_ValueError, "Failed to allocate memory for file path.");
            return null;
        };
        file_paths_string.append(owned_path) catch {
            py.PyErr_SetString(PyExc_ValueError, "Failed to append file path.");
            return null;
        };
    }

    const start_nanos = std.time.nanoTimestamp();
    const cwd = std.fs.cwd();

    var checked_files: usize = 0;
    var files_with_license: usize = 0;
    var line_buffer: [4096]u8 = undefined;

    for (file_paths_string.items) |file_path| {
        const trimmed_path = std.mem.trim(u8, file_path, " \t\r\n");

        if (trimmed_path.len == 0) continue;

        const file = cwd.openFile(trimmed_path, .{}) catch {
            std.debug.print("Could not open file: {s}\n", .{trimmed_path});
            continue;
        };
        defer file.close();

        // Read first line directly into buffer (no allocation)
        const bytes_read = file.reader().readAll(&line_buffer) catch {
            std.debug.print("Error reading file: {s}\n", .{trimmed_path});
            continue;
        };

        // Find newline position
        const newline_pos = std.mem.indexOf(u8, line_buffer[0..bytes_read], "\n") orelse bytes_read;
        const first_line = line_buffer[0..newline_pos];

        // Simple substring search (like Python's "in")
        if (std.mem.indexOf(u8, first_line, target_license_slice) != null) {
            files_with_license += 1;
        } else {
            std.debug.print("File '{s}' does not match target license '{s}'.\n", .{ trimmed_path, target_license_slice });
            py.PyErr_SetString(PyExc_ValueError, "File does not match target license.");
            const end_nanos = std.time.nanoTimestamp();
            const elapsed_ms = @divTrunc(end_nanos - start_nanos, std.time.ns_per_ms);
            checked_files += 1;
            std.debug.print("Files with license '{s}': {d} / {d} Files\n", .{ target_license_slice, files_with_license, checked_files });
            std.debug.print("License check completed in ({d}ns) {d}ms \n", .{ end_nanos - start_nanos, elapsed_ms });
            return null;
        }
        checked_files += 1;
    }

    const end_nanos = std.time.nanoTimestamp();
    const elapsed_ms = @divTrunc(end_nanos - start_nanos, std.time.ns_per_ms);

    std.debug.print("Files with license '{s}': {d} / {d} Files\n", .{ target_license_slice, files_with_license, checked_files });
    std.debug.print("License check completed in ({d}ns) {d}ms \n", .{ end_nanos - start_nanos, elapsed_ms });

    return py.PyLong_FromLong(@intCast(files_with_license));
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
        \\
        \\Returns
        \\-------
        \\bool
        \\    Returns a Python integer object (1) on success.
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
