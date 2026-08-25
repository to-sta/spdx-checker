// SPDX-License-Identifier: MIT
//! Small path-glob matcher supporting `*`, `**`, and `?`.

pub fn match(pattern: []const u8, name: []const u8) bool {
    var pattern_index: usize = 0;
    var name_index: usize = 0;
    var star_pattern: ?usize = null;
    var star_name: ?usize = null;
    var doublestar_pattern: ?usize = null;
    var doublestar_name: ?usize = null;

    while (pattern_index < pattern.len or name_index < name.len) {
        if (pattern_index < pattern.len) {
            switch (pattern[pattern_index]) {
                '?' => {
                    if (name_index < name.len and name[name_index] != '/') {
                        pattern_index += 1;
                        name_index += 1;
                        continue;
                    }
                },
                '*' => {
                    if (pattern_index + 1 < pattern.len and pattern[pattern_index + 1] == '*') {
                        pattern_index += 2;
                        if (pattern_index < pattern.len and pattern[pattern_index] == '/') {
                            pattern_index += 1;
                        }
                        doublestar_pattern = pattern_index;
                        doublestar_name = name_index;
                        continue;
                    }

                    star_pattern = pattern_index;
                    star_name = name_index;
                    pattern_index += 1;
                    continue;
                },
                '/' => {
                    if (name_index < name.len and name[name_index] == '/') {
                        pattern_index += 1;
                        name_index += 1;
                        continue;
                    }
                },
                else => |character| {
                    if (name_index < name.len and name[name_index] == character) {
                        pattern_index += 1;
                        name_index += 1;
                        continue;
                    }
                },
            }
        }

        if (star_pattern) |saved_pattern| {
            if (star_name) |saved_name| {
                if (saved_name < name.len and name[saved_name] != '/') {
                    pattern_index = saved_pattern + 1;
                    name_index = saved_name + 1;
                    star_name = saved_name + 1;
                    continue;
                }
                star_pattern = null;
                star_name = null;
            }
        }

        if (doublestar_pattern) |saved_pattern| {
            if (doublestar_name) |saved_name| {
                if (saved_name < name.len) {
                    pattern_index = saved_pattern;
                    name_index = saved_name + 1;
                    doublestar_name = saved_name + 1;
                    continue;
                }
            }
        }

        return false;
    }

    while (pattern_index < pattern.len and pattern[pattern_index] == '*') {
        pattern_index += 1;
    }
    return pattern_index == pattern.len and name_index == name.len;
}

const std = @import("std");

test "glob handles recursive exclusions" {
    try std.testing.expect(match("**/__init__.py", "tests/first/__init__.py"));
    try std.testing.expect(match("src/**/*.py", "src/a/b/test.py"));
    try std.testing.expect(!match("*.py", "src/test.py"));
}
