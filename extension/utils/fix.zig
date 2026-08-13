const std = @import("std");
const Arguments = @import("../parse.zig").Arguments;
const output = @import("output.zig");
const CommentStyles = output.CommentStyles;

/// Files at or below this size are copied into a stack buffer instead of
/// being heap-allocated, avoiding an allocation for the common case.
const stack_buffer_size = 4096;

/// Large enough to hold a comment prefix/postfix plus a typical SPDX license
/// expression (e.g. "MIT", "Apache-2.0", "GPL-3.0-or-later").
const header_buffer_size = 256;

/// Adds an SPDX license header to the beginning of a file.
///
/// This function reads the entire contents of the given file, constructs a license header
/// using the specified license and file extension's comment style, and writes the header
/// followed by the original file content back to the file. If the new content is shorter
/// than the original, the file is truncated to the new length.
///
/// - `args`: Contains the target license to be added as a header.
/// - `file`: The file to which the license header will be added.
/// - `file_extension`: The extension of the file, used to determine the comment style.
///
/// Errors:
/// Returns any I/O or formatting errors encountered during reading, writing, or formatting.
pub fn addLicenseHeader(allocator: std.mem.Allocator, io: std.Io, args: Arguments, file: std.Io.File, file_extension: []const u8) !void {
    const file_stat = try file.stat(io);

    // Avoid unnecessary allocation for small files - use stack buffer when possible
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

    const prefix, const postfix = .{ try CommentStyles.getPrefix(file_extension), try CommentStyles.getPostfix(file_extension) };

    // Format the SPDX header
    var header_buffer: [header_buffer_size]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buffer, "{s}{s}{s}{s}\n", .{ prefix, output.spdx_prefix, args.target_license, postfix });

    // Write header first
    try file.writePositionalAll(io, header, 0);

    // Then write original content
    try file.writePositionalAll(io, file_buffer[0..bytes_read], header.len);
    try file.setLength(io, header.len + bytes_read);
}
