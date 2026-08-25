// SPDX-License-Identifier: MIT
//! Allocation-free path selection.

const std = @import("std");
const glob = @import("glob.zig");
const Config = @import("../core/config.zig").Config;

pub const Decision = enum {
    include,
    excluded_by_extension,
    excluded_by_pattern,
};

pub fn extension(path: []const u8) []const u8 {
    const dot_index = std.mem.lastIndexOf(u8, path, ".") orelse return "";
    return path[dot_index + 1 ..];
}

pub fn select(config: Config, path: []const u8) Decision {
    if (config.extensions.len != 0) {
        const file_extension = extension(path);
        var matches_extension = false;
        for (config.extensions) |allowed| {
            if (std.mem.eql(u8, file_extension, allowed)) {
                matches_extension = true;
                break;
            }
        }
        if (!matches_extension) return .excluded_by_extension;
    }

    for (config.exclude) |pattern| {
        if (glob.match(pattern, path)) return .excluded_by_pattern;
    }
    return .include;
}

test "selection applies extensions before exclusions" {
    const config = Config{
        .target_license = "MIT",
        .file_paths = &.{},
        .extensions = &.{"py"},
        .exclude = &.{"**/generated.py"},
        .fix = false,
        .continue_on_error = true,
    };

    try std.testing.expectEqual(Decision.include, select(config, "src/main.py"));
    try std.testing.expectEqual(Decision.excluded_by_extension, select(config, "src/main.c"));
    try std.testing.expectEqual(Decision.excluded_by_pattern, select(config, "src/generated.py"));
}
