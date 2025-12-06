const std = @import("std");
const Arguments = @import("../parse.zig").Arguments;
const CommentStyles = @import("output.zig").CommentStyles;

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
pub fn addLicenseHeader(allocator: std.mem.Allocator, args: Arguments, file: std.fs.File, file_extension: []const u8) !void {
    const file_stat = try file.stat();

    // Avoid unnecessary allocation for small files - use stack buffer when possible
    var stack_buffer: [4096]u8 = undefined;
    var file_buffer: []u8 = undefined;
    var heap_allocated = false;

    if (file_stat.size <= stack_buffer.len) {
        file_buffer = stack_buffer[0..file_stat.size];
    } else {
        file_buffer = try allocator.alloc(u8, file_stat.size);
        heap_allocated = true;
    }
    defer if (heap_allocated) allocator.free(file_buffer);

    try file.seekTo(0);
    const bytes_read = try file.readAll(file_buffer);

    const prefix, const postfix = .{ 
        try CommentStyles.getPrefix(file_extension), 
        try CommentStyles.getPostfix(file_extension) 
    };

    // Format the SPDX header
    var header_buffer: [256]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buffer, "{s}SPDX-License-Identifier: {s}{s}\n", .{ prefix, args.target_license, postfix });

    // Write header first
    try file.seekTo(0);
    try file.writeAll(header);

    // Then write original content
    try file.writeAll(file_buffer[0..bytes_read]);
    try file.setEndPos(try file.getPos());
}