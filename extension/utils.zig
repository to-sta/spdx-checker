const std = @import("std");
const Arguments = @import("parse.zig").Arguments;

pub const Colors = struct {
    pub const Reset = "\x1b[0m";
    pub const Bold = "\x1b[1m";
    pub const Underline = "\x1b[4m";
    pub const Red = "\x1b[31m";
    pub const Green = "\x1b[32m";
    pub const Yellow = "\x1b[33m";
    pub const Blue = "\x1b[34m";
    pub const Purple = "\x1b[35m";
};

pub fn cleanFirstLine(allocator: std.mem.Allocator, args: struct { first_line: []const u8 }) ![]const u8 {
    var temp_buf: [256]u8 = undefined;
    var idx: usize = 0;
    for (args.first_line) |c| {
        if (!std.ascii.isWhitespace(c)) {
            if (idx < temp_buf.len) {
                temp_buf[idx] = c;
                idx += 1;
            }
        }
    }

    var working = temp_buf[0..idx];

    var start: usize = 0;
    var end: usize = working.len;

    if (std.mem.startsWith(u8, working, "//")) {
        start = 2;
    } else if (std.mem.startsWith(u8, working, "/*")) {
        start = 2;
        // Only subtract if we have enough characters
        if (working.len >= 4) { // "/*" + at least 2 more chars for "*/"
            end = working.len - 2;
        } else {
            // If string is too short, just use everything after "/*"
            end = working.len;
        }
    } else if (std.mem.startsWith(u8, working, "#")) {
        start = 1;
    } else if (std.mem.startsWith(u8, working, "<!--")) {
        start = 4;
        // Only subtract if we have enough characters
        if (working.len >= 7) { // "<!--" + at least 3 more chars for "-->"
            end = working.len - 3;
        } else {
            // If string is too short, just use everything after "<!--"
            end = working.len;
        }
    }

    // Ensure start doesn't exceed end
    if (start > end) {
        start = end;
    }

    var result = working[start..end];
    if (std.mem.startsWith(u8, result, "SPDX-License-Identifier:")) {
        const spdx_prefix_len = "SPDX-License-Identifier:".len;
        if (result.len > spdx_prefix_len) {
            result = result[spdx_prefix_len..];
        } else {
            result = result[result.len..]; // Empty slice
        }
    }

    // Return a copy that the caller owns (caller must free this!)
    return allocator.dupe(u8, result);
}

pub fn getFileExtension(file_path: []const u8) []const u8 {
    const dot_index = std.mem.lastIndexOf(u8, file_path, ".");
    if (dot_index) |idx| {
        return file_path[idx + 1 ..];
    } else {
        return "";
    }
}

pub fn getFilePrefix(file_extension: []const u8) ![]const u8 {
    const prefix_map = std.StaticStringMap([]const u8).initComptime(.{
        // C-style comments
        .{ "c", "// " },
        .{ "h", "// " },
        .{ "cpp", "// " },
        .{ "hpp", "// " },
        .{ "cc", "// " },
        .{ "cxx", "// " },
        .{ "js", "// " },
        .{ "ts", "// " },
        .{ "tsx", "// " },
        .{ "jsx", "// " },
        .{ "java", "// " },
        .{ "go", "// " },
        .{ "rs", "// " },
        .{ "svelte", "// " },
        .{ "vue", "// " },
        .{ "zig", "// " },

        // Hash comments
        .{ "py", "# " },
        .{ "sh", "# " },
        .{ "bash", "# " },

        // Block comments
        .{ "css", "/* " },
        .{ "c-block", "/* " },

        // XML/HTML comments
        .{ "html", "<!-- " },
        .{ "xml", "<!-- " },
    });
    return prefix_map.get(file_extension) orelse error.UnrecognizedFileExtension;
}

pub fn getFilePostfix(file_extension: []const u8) ![]const u8 {
    const postfix_map = std.StaticStringMap([]const u8).initComptime(.{
        // C-style comments
        .{ "c", "" },
        .{ "h", "" },
        .{ "cpp", "" },
        .{ "hpp", "" },
        .{ "cc", "" },
        .{ "cxx", "" },
        .{ "js", "" },
        .{ "ts", "" },
        .{ "tsx", "" },
        .{ "jsx", "" },
        .{ "java", "" },
        .{ "go", "" },
        .{ "rs", "" },
        .{ "svelte", "" },
        .{ "vue", "" },
        .{ "zig", "" },

        // Hash comments
        .{ "py", "" },
        .{ "sh", "" },
        .{ "bash", "" },

        // Block comments
        .{ "css", " */" },
        .{ "c-block", " */" },

        // XML/HTML comments
        .{ "html", " -->" },
        .{ "xml", " -->" },
    });
    return postfix_map.get(file_extension) orelse error.UnrecognizedFileExtension;
}

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
    try file.seekTo(0);
    const stat = try file.stat();
    var file_buf = try allocator.alloc(u8, stat.size);
    defer allocator.free(file_buf);

    const bytes_read = try file.readAll(file_buf);

    var header_buf: [128]u8 = undefined;
    const prefix = try getFilePrefix(file_extension);
    const postfix = try getFilePostfix(file_extension);

    const header_slice = try std.fmt.bufPrint(&header_buf, "{s}SPDX-License-Identifier: {s}{s}\n", .{ prefix, args.target_license, postfix });
    const header_len = header_slice.len;

    try file.seekTo(0);
    try file.writeAll(header_buf[0..header_len]);
    try file.writeAll(file_buf[0..bytes_read]);

    try file.setEndPos(header_len + bytes_read);
}
