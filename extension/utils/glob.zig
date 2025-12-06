// SPDX-License-Identifier: MIT
const std = @import("std");

/// Simple glob pattern matching supporting '*', '**' and '?'
/// - '*' matches zero or more characters within a single path segment (does not cross '/')
/// - '**' matches zero or more path segments (can cross '/')
/// - '?' matches any single character except '/'
/// This function returns true if the given name matches the glob pattern.
pub fn match(pattern: []const u8, name: []const u8) bool {
    var px: usize = 0;
    var nx: usize = 0;
    var star_px: ?usize = null;
    var star_nx: ?usize = null;
    var doublestar_px: ?usize = null;
    var doublestar_nx: ?usize = null;

    while (px < pattern.len or nx < name.len) {
        if (px < pattern.len) {
            const c = pattern[px];

            switch (c) {
                '?' => {
                    // matches any single character except '/'
                    if (nx < name.len and name[nx] != '/') {
                        px += 1;
                        nx += 1;
                        continue;
                    }
                },
                '*' => {
                    // Check if this is '**'
                    if (px + 1 < pattern.len and pattern[px + 1] == '*') {
                        // '**' matches zero or more path segments
                        // Skip past '**'
                        px += 2;

                        // Skip optional '/' after '**'
                        if (px < pattern.len and pattern[px] == '/') {
                            px += 1;
                        }

                        // Save backtrack position for '**'
                        doublestar_px = px;
                        doublestar_nx = nx;

                        // Try matching the rest of the pattern immediately (zero-length match)
                        continue;
                    } else {
                        // Single '*' matches zero or more characters within a segment (stops at '/')
                        // Save backtrack position for '*'
                        star_px = px;
                        star_nx = nx;
                        px += 1;
                        continue;
                    }
                },
                '/' => {
                    // literal '/' must match exactly
                    if (nx < name.len and name[nx] == '/') {
                        px += 1;
                        nx += 1;
                        continue;
                    }
                },
                else => {
                    // literal character match
                    if (nx < name.len and name[nx] == c) {
                        px += 1;
                        nx += 1;
                        continue;
                    }
                },
            }
        }

        // Try backtracking with single star first (doesn't cross '/')
        if (star_px) |spx| {
            if (star_nx) |snx| {
                // Can only backtrack with * if we haven't hit a '/' yet
                if (snx < name.len and name[snx] != '/') {
                    px = spx + 1;
                    nx = snx + 1;
                    star_nx = snx + 1;
                    continue;
                } else {
                    // Hit a '/', can't use star backtrack anymore
                    star_px = null;
                    star_nx = null;
                }
            }
        }

        // Try backtracking with double star (can cross '/')
        if (doublestar_px) |dspx| {
            if (doublestar_nx) |dsnx| {
                if (dsnx < name.len) {
                    px = dspx;
                    nx = dsnx + 1;
                    doublestar_nx = dsnx + 1;
                    continue;
                }
            }
        }

        return false;
    }

    // Skip any trailing stars
    while (px < pattern.len and pattern[px] == '*') {
        px += 1;
    }

    return px == pattern.len and nx == name.len;
}

test "glob match - exact match" {
    try std.testing.expect(match("foo", "foo"));
    try std.testing.expect(!match("foo", "bar"));
    try std.testing.expect(!match("foo", "foobar"));
}

test "glob match - single star within segment" {
    try std.testing.expect(match("*.py", "test.py"));
    try std.testing.expect(match("*.py", "example.py"));
    try std.testing.expect(match("test*.py", "test123.py"));
    try std.testing.expect(match("*test.py", "mytest.py"));
    try std.testing.expect(match("*.py", ".py"));
    try std.testing.expect(!match("*.py", "test.txt"));
    try std.testing.expect(!match("*.py", "path/to/test.py")); // * doesn't cross /
}

test "glob match - question mark" {
    try std.testing.expect(match("test?.py", "test1.py"));
    try std.testing.expect(match("test?.py", "testa.py"));
    try std.testing.expect(!match("test?.py", "test.py"));
    try std.testing.expect(!match("test?.py", "test12.py"));
    try std.testing.expect(!match("test?.py", "test/.py")); // ? doesn't match /
}

test "glob match - double star matches zero segments" {
    try std.testing.expect(match("**/test.py", "test.py"));
    try std.testing.expect(match("**/*.py", "test.py"));
}

test "glob match - double star matches single segment" {
    try std.testing.expect(match("**/test.py", "dir/test.py"));
    try std.testing.expect(match("**/*.py", "dir/test.py"));
}

test "glob match - double star matches multiple segments" {
    try std.testing.expect(match("**/test.py", "a/b/c/test.py"));
    try std.testing.expect(match("**/*.py", "a/b/c/test.py"));
    try std.testing.expect(match("**/subdir/*.py", "a/b/subdir/test.py"));
}

test "glob match - double star with prefix" {
    try std.testing.expect(match("src/**/*.py", "src/test.py"));
    try std.testing.expect(match("src/**/*.py", "src/a/test.py"));
    try std.testing.expect(match("src/**/*.py", "src/a/b/c/test.py"));
    try std.testing.expect(!match("src/**/*.py", "other/test.py"));
}

test "glob match - double star with suffix" {
    try std.testing.expect(match("**/__init__.py", "__init__.py"));
    try std.testing.expect(match("**/__init__.py", "tests/__init__.py"));
    try std.testing.expect(match("**/__init__.py", "tests/first/__init__.py"));
    try std.testing.expect(match("**/__init__.py", "tests/first/second/__init__.py"));
    try std.testing.expect(!match("**/__init__.py", "tests/test.py"));
}

test "glob match - complex patterns" {
    try std.testing.expect(match("src/**/test_*.py", "src/test_main.py"));
    try std.testing.expect(match("src/**/test_*.py", "src/a/test_utils.py"));
    try std.testing.expect(match("src/**/test_*.py", "src/a/b/test_helpers.py"));
    try std.testing.expect(!match("src/**/test_*.py", "src/main.py"));
}

test "glob match - multiple stars" {
    try std.testing.expect(match("**/test/**/file.txt", "test/file.txt"));
    try std.testing.expect(match("**/test/**/file.txt", "a/test/file.txt"));
    try std.testing.expect(match("**/test/**/file.txt", "a/test/b/file.txt"));
    try std.testing.expect(match("**/test/**/file.txt", "a/b/test/c/d/file.txt"));
}

test "glob match - edge cases" {
    try std.testing.expect(match("", ""));
    try std.testing.expect(!match("", "test"));
    try std.testing.expect(match("**", ""));
    try std.testing.expect(match("**", "a"));
    try std.testing.expect(match("**", "a/b/c"));
    try std.testing.expect(match("*", ""));
    try std.testing.expect(match("*", "test"));
    try std.testing.expect(!match("*", "a/b"));
}

test "glob match - path separators" {
    try std.testing.expect(match("a/b/c", "a/b/c"));
    try std.testing.expect(!match("a/b/c", "a/b/d"));
    try std.testing.expect(match("a/*/c", "a/b/c"));
    try std.testing.expect(!match("a/*/c", "a/b/d/c")); // * doesn't cross /
    try std.testing.expect(match("a/**/c", "a/b/d/c")); // ** does cross /
}

test "glob match - real world patterns" {
    // Python __pycache__ directories
    try std.testing.expect(match("**/__pycache__", "src/__pycache__"));
    try std.testing.expect(match("**/__pycache__", "src/tests/__pycache__"));
    try std.testing.expect(match("**/__pycache__/**", "src/__pycache__/test.pyc"));

    // Node modules
    try std.testing.expect(match("**/node_modules/**", "node_modules/pkg/index.js"));
    try std.testing.expect(match("**/node_modules/**", "a/b/node_modules/pkg/index.js"));

    // Build artifacts
    try std.testing.expect(match("**/dist/*.js", "dist/main.js"));
    try std.testing.expect(match("**/dist/*.js", "packages/core/dist/index.js"));

    // Test files
    try std.testing.expect(match("**/test_*.py", "test_main.py"));
    try std.testing.expect(match("**/test_*.py", "tests/test_utils.py"));
    try std.testing.expect(match("**/test_*.py", "src/core/tests/test_helpers.py"));
}
