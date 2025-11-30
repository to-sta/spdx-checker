// SPDX-License-Identifier: MIT
const std = @import("std");
const py = @import("python.zig").py;
const ParseError = @import("errors.zig").ParseError;

pub const Arguments = struct {
    target_license: []const u8,
    file_paths: [][]const u8,
    fix: bool,
    continue_on_error: bool,
    extensions: [][]const u8,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *Arguments) void {
        self.allocator.free(self.file_paths);
        self.allocator.free(self.extensions);
    }

    pub fn parse(args: [*c]py.PyObject, kwargs: [*c]py.PyObject, allocator: std.mem.Allocator) ParseError!Arguments {
        // Variables to hold parsed values
        var target_license_ptr: [*:0]const u8 = undefined;
        var file_paths_obj: [*c]py.PyObject = undefined;
        var extensions_obj: [*c]py.PyObject = null;
        var fix_int: c_int = 0;
        var continue_on_error_int: c_int = 0;

        const kw_target: [*c]u8 = @constCast("target_license");
        const kw_files: [*c]u8 = @constCast("file_paths");
        const kw_ext: [*c]u8 = @constCast("extensions");
        const kw_fix: [*c]u8 = @constCast("fix");
        const kw_cont: [*c]u8 = @constCast("continue_on_error");

        const kwlist = [_][*c]u8{
            kw_target,
            kw_files,
            kw_ext,
            kw_fix,
            kw_cont,
            null,
        };

        // Args and Kwargs parsing
        // python docs: https://docs.python.org/3/c-api/arg.html#c.PyArg_ParseTupleAndKeywords
        const results = py.PyArg_ParseTupleAndKeywords(
            args,
            kwargs,
            "sO!|Opp",
            @constCast(&kwlist),
            &target_license_ptr,
            &py.PyList_Type,
            &file_paths_obj,
            &extensions_obj,
            &fix_int,
            &continue_on_error_int,
        ); 

        if (results == 0) {
            return error.ParseFailed;
        }
        
        // If extensions are not provided, set to an empty list
        if (extensions_obj == null) {
            extensions_obj = py.PyList_New(0);
        }

        const target_license: []const u8 = std.mem.span(target_license_ptr);
        const fix = fix_int != 0;
        const continue_on_error = continue_on_error_int != 0;

        const file_paths_len = py.PyList_Size(file_paths_obj);
        if (file_paths_len < 0) {
            return error.InvalidList;
        }

        const extensions_len: isize = if (extensions_obj != py.Py_None()) py.PyList_Size(extensions_obj) else 0;
        if (extensions_len < 0) {
            return error.InvalidList;
        }

        const file_paths = allocator.alloc([]const u8, @intCast(file_paths_len)) catch |err| {
            return err;
        };
        errdefer allocator.free(file_paths);

        const extensions = allocator.alloc([]const u8, @intCast(extensions_len)) catch |err| {
            return err;
        };
        errdefer allocator.free(extensions);

        var i: isize = 0;
        while (i < file_paths_len) : (i += 1) {
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

        if (extensions_len > 0) {
            var j: isize = 0;
            while (j < extensions_len) : (j += 1) {
                const item = py.PyList_GetItem(extensions_obj, j);
                if (item == null) {
                    allocator.free(extensions);
                    py.PyErr_SetString(py.PyExc_TypeError, "Invalid list item");
                    return error.InvalidListItem;
                }

                const ext_bytes = py.PyUnicode_AsUTF8String(item);
                if (ext_bytes == null) {
                    allocator.free(extensions);
                    if (py.PyErr_Occurred() == null) {
                        py.PyErr_SetString(py.PyExc_TypeError, "Expected list of strings");
                    }
                    return error.InvalidString;
                }
                const ext_ptr: [*:0]const u8 = @ptrCast(py.PyBytes_AsString(ext_bytes));

                extensions[@intCast(j)] = std.mem.span(ext_ptr);
            }
        }

        return Arguments{
            .target_license = target_license,
            .file_paths = file_paths,
            .fix = fix,
            .continue_on_error = continue_on_error,
            .allocator = allocator,
            .extensions = extensions,
        };
    }
};
