// SPDX-License-Identifier: MIT
const std = @import("std");
const py = @import("python.zig").py;
const ParseError = @import("errors.zig").ParseError;

pub const Arguments = struct {
    target_license: []const u8,
    file_paths: [][]const u8,
    fix: bool,
    continue_on_error: bool,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *Arguments) void {
        self.allocator.free(self.file_paths);
    }

    pub fn parse(args: *py.PyObject, allocator: std.mem.Allocator) ParseError!Arguments {
        var target_license_ptr: [*:0]const u8 = undefined;
        var file_paths_obj: *py.PyObject = undefined;
        var fix_int: c_int = 0;
        var continue_on_error_int: c_int = 0;

        if (py.PyArg_ParseTuple(args, "sO!|pp", &target_license_ptr, &py.PyList_Type, &file_paths_obj, &fix_int, &continue_on_error_int) == 0) {
            return error.ParseFailed;
        }

        const target_license = std.mem.span(target_license_ptr);
        const fix = fix_int != 0;
        const continue_on_error = continue_on_error_int != 0;

        const list_len = py.PyList_Size(file_paths_obj);
        if (list_len < 0) {
            return error.InvalidList;
        }

        // This is likely where the error comes from - allocator.alloc can return OutOfMemory
        const file_paths = allocator.alloc([]const u8, @intCast(list_len)) catch |err| {
            return err;
        };
        errdefer allocator.free(file_paths);

        var i: isize = 0;
        while (i < list_len) : (i += 1) {
            const item = py.PyList_GetItem(file_paths_obj, i);
            if (item == null) {
                allocator.free(file_paths);
                py.PyErr_SetString(py.PyExc_TypeError, "Invalid list item");
                return error.InvalidListItem;
            }

            const filepath_bytes = py.PyUnicode_AsUTF8String(item);
            if (filepath_bytes == null) {
                allocator.free(file_paths);
                if (py.PyErr_Occurred() == null) {
                    py.PyErr_SetString(py.PyExc_TypeError, "Expected list of strings");
                }
                return error.InvalidString;
            }
            const filepath_ptr: [*:0]const u8 = @ptrCast(py.PyBytes_AsString(filepath_bytes));

            file_paths[@intCast(i)] = std.mem.span(filepath_ptr);
        }

        return Arguments{
            .target_license = target_license,
            .file_paths = file_paths,
            .fix = fix,
            .continue_on_error = continue_on_error,
            .allocator = allocator,
        };
    }
};
