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
    exclude: [][]const u8,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *Arguments) void {
        self.allocator.free(self.file_paths);
        self.allocator.free(self.extensions);
        self.allocator.free(self.exclude);
    }

    /// Converts a Python list of `len` strings into a newly allocated slice
    /// of Zig strings.
    ///
    /// `list_obj` must be a Python list with at least `len` items, and `len`
    /// must be non-negative (as returned by a successful `PyList_Size` call).
    fn pyStringListToSlice(allocator: std.mem.Allocator, list_obj: [*c]py.PyObject, len: isize) ParseError![][]const u8 {
        const result = try allocator.alloc([]const u8, @intCast(len));
        errdefer allocator.free(result);

        var idx: isize = 0;
        while (idx < len) : (idx += 1) {
            const item = py.PyList_GetItem(list_obj, idx);
            if (item == null) {
                py.PyErr_SetString(py.PyExc_TypeError, "Invalid list item");
                return error.InvalidListItem;
            }

            const item_bytes = py.PyUnicode_AsUTF8String(item);
            if (item_bytes == null) {
                if (py.PyErr_Occurred() == null) {
                    py.PyErr_SetString(py.PyExc_TypeError, "Expected list of strings");
                }
                return error.InvalidString;
            }
            const item_ptr: [*:0]const u8 = @ptrCast(py.PyBytes_AsString(item_bytes));

            result[@intCast(idx)] = std.mem.span(item_ptr);
        }

        return result;
    }

    pub fn parse(args: [*c]py.PyObject, kwargs: [*c]py.PyObject, allocator: std.mem.Allocator) ParseError!Arguments {
        // Variables to hold parsed values
        var target_license_ptr: [*:0]const u8 = undefined;
        var file_paths_obj: [*c]py.PyObject = undefined;
        var extensions_obj: [*c]py.PyObject = null;
        var exclude_obj: [*c]py.PyObject = null;
        var fix_int: c_int = 0;
        var continue_on_error_int: c_int = 0;

        const kw_target: [*c]u8 = @constCast("target_license");
        const kw_files: [*c]u8 = @constCast("file_paths");
        const kw_ext: [*c]u8 = @constCast("extensions");
        const kw_exclude: [*c]u8 = @constCast("exclude");
        const kw_fix: [*c]u8 = @constCast("fix");
        const kw_cont: [*c]u8 = @constCast("continue_on_error");

        const kwlist = [_][*c]u8{
            kw_target,
            kw_files,
            kw_ext,
            kw_exclude,
            kw_fix,
            kw_cont,
            null,
        };

        // Args and Kwargs parsing
        // Python docs: https://docs.python.org/3/c-api/arg.html#c.PyArg_ParseTupleAndKeywords
        //
        // Format: "sO|OOpp"
        //
        //  s: string (target_license)
        //  O: object (file_paths, list-ness verified manually via PyList_Check below,
        //     since `O!` requires taking the address of `PyList_Type`, which is an
        //     opaque type under Py_LIMITED_API and can no longer be referenced directly)
        //  |: indicates the following arguments are optional
        //  O: object (extensions, optional)
        //  O: object (exclude, optional)
        //  p: boolean as int (fix, optional)
        //  p: boolean as int (continue_on_error, optional)
        const results = py.PyArg_ParseTupleAndKeywords(
            args,
            kwargs,
            "sO|OOpp",
            @constCast(&kwlist),
            &target_license_ptr,
            &file_paths_obj,
            &extensions_obj,
            &exclude_obj,
            &fix_int,
            &continue_on_error_int,
        );

        if (results == 0) {
            return error.ParseFailed;
        }

        if (py.PyList_Check(file_paths_obj) == 0) {
            py.PyErr_SetString(py.PyExc_TypeError, "file_paths must be a list");
            return error.InvalidList;
        }

        // If extensions are not provided, set to an empty list
        if (extensions_obj == null) {
            extensions_obj = py.PyList_New(0);
        }

        if (exclude_obj == null) {
            exclude_obj = py.PyList_New(0);
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

        const exclude_pattern_len = py.PyList_Size(exclude_obj);
        if (exclude_pattern_len < 0) {
            return error.InvalidList;
        }

        const file_paths = try pyStringListToSlice(allocator, file_paths_obj, file_paths_len);
        errdefer allocator.free(file_paths);

        const extensions = try pyStringListToSlice(allocator, extensions_obj, extensions_len);
        errdefer allocator.free(extensions);

        const exclude = try pyStringListToSlice(allocator, exclude_obj, exclude_pattern_len);
        errdefer allocator.free(exclude);

        return Arguments{
            .target_license = target_license,
            .file_paths = file_paths,
            .fix = fix,
            .continue_on_error = continue_on_error,
            .allocator = allocator,
            .extensions = extensions,
            .exclude = exclude,
        };
    }
};
