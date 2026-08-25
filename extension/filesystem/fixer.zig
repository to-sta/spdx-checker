// SPDX-License-Identifier: MIT
//! In-place SPDX header insertion.

const std = @import("std");
const header = @import("../core/header.zig");

const stack_buffer_size = 4096;
const header_buffer_size = 256;

pub fn addLicenseHeader(
    allocator: std.mem.Allocator,
    io: std.Io,
    target_license: []const u8,
    file: std.Io.File,
    file_extension: []const u8,
) !void {
    const file_stat = try file.stat(io);

    var stack_buffer: [stack_buffer_size]u8 = undefined;
    var file_buffer: []u8 = undefined;
    var heap_allocated = false;

    if (file_stat.size <= stack_buffer.len) {
        file_buffer = stack_buffer[0..file_stat.size];
    } else {
        file_buffer = try allocator.alloc(u8, file_stat.size);
        heap_allocated = true;
    }
    defer if (heap_allocated) allocator.free(file_buffer);

    const bytes_read = try file.readPositionalAll(io, file_buffer, 0);
    const style = try header.commentStyle(file_extension);

    var formatted_header_buffer: [header_buffer_size]u8 = undefined;
    const formatted_header = try std.fmt.bufPrint(
        &formatted_header_buffer,
        "{s}{s}{s}{s}\n",
        .{ style.prefix, header.spdx_prefix, target_license, style.postfix },
    );

    try file.writePositionalAll(io, formatted_header, 0);
    try file.writePositionalAll(io, file_buffer[0..bytes_read], formatted_header.len);
    try file.setLength(io, formatted_header.len + bytes_read);
}
