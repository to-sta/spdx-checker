const std = @import("std");
const glob = @import("glob.zig");

pub fn getFileExtension(file_path: []const u8) []const u8 {
    const dot_index = std.mem.lastIndexOf(u8, file_path, ".");
    if (dot_index) |idx| {
        return file_path[idx + 1 ..];
    } else {
        return "";
    }
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
        // Overwrite file_paths with filtered results
        allocator.free(file_paths.*);
        file_paths.* = try allocator.dupe([]const u8, filtered.items);
        return true;
    }
    return false;
}

pub fn filterByGlobPattern(allocator: std.mem.Allocator, patterns: [][]const u8, file_paths: *[][]const u8) !bool {
    if (patterns.len == 0) {
        return false;
    }

    var filtered = try std.ArrayList([]const u8).initCapacity(allocator, file_paths.len);
    defer filtered.deinit(allocator);

    for (file_paths.*) |path| {
        var should_exclude = false;
        for (patterns) |pattern| {
            const matches = glob.match(pattern, path);
            if (matches) {
                should_exclude = true;
                break;
            }
        }
        if (!should_exclude) {
            try filtered.append(allocator, path);
        }
    }

    if (file_paths.len > filtered.items.len) {
        // Free previous allocation to avoid memory leak
        // Overwrite file_paths with filtered results
        allocator.free(file_paths.*);
        file_paths.* = try allocator.dupe([]const u8, filtered.items);
        return true;
    }
    return false;
}