// SPDX-License-Identifier: MIT
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

pub const CommentStyles = struct {
    const Style = struct {
        prefix: []const u8,
        postfix: []const u8,
    };

    pub const styles = std.StaticStringMap(Style).initComptime(.{
        // Supported file extensions and their comment styles
        // file extensions, prefix and postfix
        // if no postfix, use empty string.
        .{ "c", Style{ .prefix = "// ", .postfix = "" } },
        .{ "h", Style{ .prefix = "// ", .postfix = "" } },
        .{ "cpp", Style{ .prefix = "// ", .postfix = "" } },
        .{ "hpp", Style{ .prefix = "// ", .postfix = "" } },
        .{ "cc", Style{ .prefix = "// ", .postfix = "" } },
        .{ "cxx", Style{ .prefix = "// ", .postfix = "" } },
        .{ "js", Style{ .prefix = "// ", .postfix = "" } },
        .{ "ts", Style{ .prefix = "// ", .postfix = "" } },
        .{ "tsx", Style{ .prefix = "// ", .postfix = "" } },
        .{ "jsx", Style{ .prefix = "// ", .postfix = "" } },
        .{ "java", Style{ .prefix = "// ", .postfix = "" } },
        .{ "go", Style{ .prefix = "// ", .postfix = "" } },
        .{ "rs", Style{ .prefix = "// ", .postfix = "" } },
        .{ "svelte", Style{ .prefix = "// ", .postfix = "" } },
        .{ "vue", Style{ .prefix = "// ", .postfix = "" } },
        .{ "zig", Style{ .prefix = "// ", .postfix = "" } },
        .{ "py", Style{ .prefix = "# ", .postfix = "" } },
        .{ "sh", Style{ .prefix = "# ", .postfix = "" } },
        .{ "bash", Style{ .prefix = "# ", .postfix = "" } },
        .{ "css", Style{ .prefix = "/* ", .postfix = " */" } },
        .{ "html", Style{ .prefix = "<!-- ", .postfix = " -->" } },
        .{ "xml", Style{ .prefix = "<!-- ", .postfix = " -->" } },
    });

    pub fn getPrefix(lang: []const u8) ![]const u8 {
        if (styles.get(lang)) |style| {
            return style.prefix;
        }
        return error.UnrecognizedFileExtension;
    }

    pub fn getPostfix(lang: []const u8) ![]const u8 {
        if (styles.get(lang)) |style| {
            return style.postfix;
        }
        return error.UnrecognizedFileExtension;
    }
};

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
    const prefix = try CommentStyles.getPrefix(file_extension);
    const postfix = try CommentStyles.getPostfix(file_extension);

    const header_slice = try std.fmt.bufPrint(&header_buf, "{s}SPDX-License-Identifier: {s}{s}\n", .{ prefix, args.target_license, postfix });
    const header_len = header_slice.len;

    try file.seekTo(0);
    try file.writeAll(header_buf[0..header_len]);
    try file.writeAll(file_buf[0..bytes_read]);

    try file.setEndPos(header_len + bytes_read);
}

pub fn filterByExtensions(allocator: std.mem.Allocator, extensions: [][]const u8, file_paths: *[][]const u8) !bool {
    if (extensions.len == 0) {
        return false;
    }

    var filtered = try std.ArrayList([]const u8).initCapacity(allocator, file_paths.len);
    defer filtered.deinit(allocator);

    for (file_paths.*) |path| {
        const file_ext = getFileExtension(path);

        for (extensions) |ext| {
            if (std.mem.eql(u8, file_ext, ext)) {
                try filtered.append(allocator, path);
                break;
            }
        }
    }

    if (file_paths.len > filtered.items.len) {
        // Free previous allocation to avoid memory leak
        allocator.free(file_paths.*);
        // Overwrite file_paths with filtered results
        file_paths.* = try allocator.dupe([]const u8, filtered.items);
        return true;
    }
    return false;
}
