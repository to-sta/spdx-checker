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
    var is_target_license_valid = false;
    for (spdx_licenses) |spdx_license| {
        if (std.mem.eql(u8, args.target_license, spdx_license)) {
            is_target_license_valid = true;
            break;
        }
    }
    if (!is_target_license_valid) {
        std.debug.print("Error: Target license '{s}' is not a recognized SPDX license.\n", .{args.target_license});
        return false;
    }
    return true;
}

fn spdx_license_checker(self: [*c]PyObject, args: [*c]PyObject) callconv(.C) [*c]PyObject {
    _ = self;

    var target_license_ptr: [*:0]u8 = undefined;
    var file_paths_string_ptr: [*:0]u8 = undefined;

    if (py.PyArg_ParseTuple(args, "ss", &target_license_ptr, &file_paths_string_ptr) == 0) {
        std.debug.print("Expected two string arguments: target_license, file_paths_string\n", .{});
        py.PyErr_SetString(py.PyExc_ValueError, "Expected two string arguments: target_license, file_paths_string");
    }

    const target_license = std.mem.span(target_license_ptr);
    const file_paths_string = std.mem.span(file_paths_string_ptr);
    const start_nanos = std.time.nanoTimestamp();

    const validLicense = checkIfLicenseIsValid(.{
        .target_license = target_license,
    });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    if (!validLicense) {
        const errorMessage = std.fmt.allocPrintZ(
            gpa.allocator(),
            "Invalid target license {s} provided.",
            .{target_license},
        ) catch "Invalid target license provided.";

        py.PyErr_SetString(py.PyExc_ValueError, errorMessage);
        gpa.allocator().free(errorMessage);

        return null;
    }

    const cwd = std.fs.cwd();
    var arrayScannedFiles = std.ArrayList([]const u8).init(gpa.allocator());
    defer arrayScannedFiles.deinit();
    var arrayWrongLicense = std.ArrayList([]const u8).init(gpa.allocator());
    defer arrayWrongLicense.deinit();
    var validLicenseCounter: u8 = 0;
    var file_paths_iterator = std.mem.splitScalar(u8, file_paths_string, ',');

    while (file_paths_iterator.next()) |relativeFilePath| {
        arrayScannedFiles.append(relativeFilePath) catch |err| {
            std.debug.print("Error appending to array: {}\n", .{err});
        };
        if (relativeFilePath.len == 0) continue;

        const trimmed_path = std.mem.trim(u8, relativeFilePath, " \t\r\n");
        if (trimmed_path.len == 0) continue;

        const file = cwd.openFile(trimmed_path, .{}) catch {
            const errorMessage = std.fmt.allocPrintZ(
                gpa.allocator(),
                "File {s} could not be opened.",
                .{trimmed_path},
            ) catch "File could not be opened.";

            py.PyErr_SetString(PyExc_ValueError, errorMessage);
            gpa.allocator().free(errorMessage);

            return null;
        };
        defer file.close();

        var buf = std.io.bufferedReader(file.reader());
        var inStream = buf.reader();
        const firstLineOpt = inStream.readUntilDelimiterOrEofAlloc(gpa.allocator(), '\n', 1024) catch |err| {
            std.debug.print("Error reading file '{s}': {}\n", .{ trimmed_path, err });
            continue;
        };
        defer if (firstLineOpt) |firstLine| gpa.allocator().free(firstLine);

        if (firstLineOpt) |firstLine| {
            const trimmedFirstLine = utils.cleanFirstLine(gpa.allocator(), .{ .first_line = firstLine }) catch {
                py.PyErr_SetString(PyExc_ValueError, "Error cleaning first line of file.");
                return null;
            };
            defer gpa.allocator().free(trimmedFirstLine);

            if (std.mem.eql(u8, trimmedFirstLine, target_license)) {
                validLicenseCounter += 1;
                continue;
            } else {
                arrayWrongLicense.append(trimmed_path) catch {
                    py.PyErr_SetString(PyExc_ValueError, "Error appending wrong license file path.");
                    return null;
                };
            }
        }
    }

    const end_nanos = std.time.nanoTimestamp();

    utils.printSummary(.{
        .targetLicense = target_license,
        .validLicenseCounter = validLicenseCounter,
        .arrayScannedFiles = arrayScannedFiles,
        .arrayWrongLicense = arrayWrongLicense,
        .startNanos = start_nanos,
        .endNanos = end_nanos,
    });

    if (arrayWrongLicense.items.len > 0) {
        py.PyErr_SetString(PyExc_ValueError, "There are files that do not match the target license.");
    }

    return py.PyLong_FromLong(1);
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
        \\file_paths: str
        \\    file_paths_string: Comma-separated file paths to check.
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
        \\>>> spdx_checker.check_license("MIT", "file1.txt,file2.txt")
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

var module = PyModuleDef{
    .m_base = PyModuleDef_Base{
        .ob_base = PyObject{
            .unnamed_0 = .{ .ob_refcnt = @as(c_longlong, 0xffffffff) }, // previously ob_base = PyObject{.ob_refcnt = 1, ...}
            .ob_type = null,
        },
        .m_init = null,
        .m_index = 0,
        .m_copy = null,
    },
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
