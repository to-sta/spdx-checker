// SPDX-License-Identifier: MIT
//! Translation from CPython arguments into an owned core configuration.

const std = @import("std");
const py = @import("c_api.zig").py;
const Config = @import("../core/config.zig").Config;

pub const ParseError = error{
    ParseFailed,
    InvalidList,
    InvalidListItem,
    InvalidString,
    OutOfMemory,
};

pub const OwnedArguments = struct {
    allocator: std.mem.Allocator,
    target_license: []u8,
    file_paths: [][]const u8,
    extensions: [][]const u8,
    exclude: [][]const u8,
    fix: bool,
    continue_on_error: bool,

    pub fn config(self: *const OwnedArguments) Config {
        return .{
            .target_license = self.target_license,
            .file_paths = self.file_paths,
            .extensions = self.extensions,
            .exclude = self.exclude,
            .fix = self.fix,
            .continue_on_error = self.continue_on_error,
        };
    }

    fn freeStrings(allocator: std.mem.Allocator, values: [][]const u8) void {
        for (values) |value| allocator.free(value);
        allocator.free(values);
    }

    pub fn deinit(self: *OwnedArguments) void {
        self.allocator.free(self.target_license);
        freeStrings(self.allocator, self.file_paths);
        freeStrings(self.allocator, self.extensions);
        freeStrings(self.allocator, self.exclude);
    }
};

fn pyStringListToOwnedSlice(
    allocator: std.mem.Allocator,
    list_object: [*c]py.PyObject,
    length: isize,
) ParseError![][]const u8 {
    const values = try allocator.alloc([]const u8, @intCast(length));
    var initialized: usize = 0;
    errdefer {
        for (values[0..initialized]) |value| allocator.free(value);
        allocator.free(values);
    }

    var index: isize = 0;
    while (index < length) : (index += 1) {
        const item = py.PyList_GetItem(list_object, index);
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
        defer py.Py_DecRef(item_bytes);

        const item_pointer = py.PyBytes_AsString(item_bytes);
        if (item_pointer == null) return error.InvalidString;
        const item_span: [*:0]const u8 = @ptrCast(item_pointer);
        values[initialized] = try allocator.dupe(u8, std.mem.span(item_span));
        initialized += 1;
    }
    return values;
}

fn optionalListLength(object: [*c]py.PyObject, name: [*:0]const u8) ParseError!isize {
    if (object == null or object == py.Py_None()) return 0;
    if (py.PyList_Check(object) == 0) {
        _ = py.PyErr_Format(py.PyExc_TypeError, "%s must be a list or None", name);
        return error.InvalidList;
    }
    const length = py.PyList_Size(object);
    if (length < 0) return error.InvalidList;
    return length;
}

pub fn parse(
    args: [*c]py.PyObject,
    kwargs: [*c]py.PyObject,
    allocator: std.mem.Allocator,
) ParseError!OwnedArguments {
    var target_license_pointer: [*:0]const u8 = undefined;
    var file_paths_object: [*c]py.PyObject = undefined;
    var extensions_object: [*c]py.PyObject = null;
    var exclude_object: [*c]py.PyObject = null;
    var fix_integer: c_int = 0;
    var continue_on_error_integer: c_int = 0;

    const keyword_list = [_][*c]u8{
        @constCast("target_license"),
        @constCast("file_paths"),
        @constCast("extensions"),
        @constCast("exclude"),
        @constCast("fix"),
        @constCast("continue_on_error"),
        null,
    };

    const parsed = py.PyArg_ParseTupleAndKeywords(
        args,
        kwargs,
        "sO|OOpp",
        @constCast(&keyword_list),
        &target_license_pointer,
        &file_paths_object,
        &extensions_object,
        &exclude_object,
        &fix_integer,
        &continue_on_error_integer,
    );
    if (parsed == 0) return error.ParseFailed;

    if (py.PyList_Check(file_paths_object) == 0) {
        py.PyErr_SetString(py.PyExc_TypeError, "file_paths must be a list");
        return error.InvalidList;
    }

    const file_paths_length = py.PyList_Size(file_paths_object);
    if (file_paths_length < 0) return error.InvalidList;
    const extensions_length = try optionalListLength(extensions_object, "extensions");
    const exclude_length = try optionalListLength(exclude_object, "exclude");

    const target_license = try allocator.dupe(u8, std.mem.span(target_license_pointer));
    errdefer allocator.free(target_license);

    const file_paths = try pyStringListToOwnedSlice(allocator, file_paths_object, file_paths_length);
    errdefer OwnedArguments.freeStrings(allocator, file_paths);

    const extensions = try pyStringListToOwnedSlice(allocator, extensions_object, extensions_length);
    errdefer OwnedArguments.freeStrings(allocator, extensions);

    const exclude = try pyStringListToOwnedSlice(allocator, exclude_object, exclude_length);
    errdefer OwnedArguments.freeStrings(allocator, exclude);

    return .{
        .allocator = allocator,
        .target_license = target_license,
        .file_paths = file_paths,
        .extensions = extensions,
        .exclude = exclude,
        .fix = fix_integer != 0,
        .continue_on_error = continue_on_error_integer != 0,
    };
}
