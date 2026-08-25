// SPDX-License-Identifier: MIT
//! SPDX header recognition and formatting metadata.

const std = @import("std");

pub const spdx_prefix = "SPDX-License-Identifier: ";

const line_styles = [_]CommentStyle{
    .{ .prefix = "# ", .postfix = "" },
    .{ .prefix = "// ", .postfix = "" },
    .{ .prefix = "/* ", .postfix = " */" },
    .{ .prefix = "<!-- ", .postfix = " -->" },
};

pub fn firstLineHasTarget(first_line: []const u8, target_license: []const u8) bool {
    const line = std.mem.trim(u8, first_line, " \t\r");

    for (line_styles) |style| {
        if (!std.mem.startsWith(u8, line, style.prefix)) continue;
        if (!std.mem.endsWith(u8, line, style.postfix)) continue;

        const content_end = line.len - style.postfix.len;
        const content = line[style.prefix.len..content_end];
        if (!std.mem.startsWith(u8, content, spdx_prefix)) return false;

        const identifier = content[spdx_prefix.len..];
        return std.mem.eql(u8, identifier, target_license);
    }

    return false;
}

pub const CommentStyle = struct {
    prefix: []const u8,
    postfix: []const u8,
};

const styles = std.StaticStringMap(CommentStyle).initComptime(.{
    .{ "c", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "h", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "cpp", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "hpp", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "cc", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "cxx", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "js", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "ts", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "tsx", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "jsx", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "java", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "kt", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "kts", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "swift", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "go", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "rs", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "svelte", CommentStyle{ .prefix = "<!-- ", .postfix = " -->" } },
    .{ "vue", CommentStyle{ .prefix = "<!-- ", .postfix = " -->" } },
    .{ "zig", CommentStyle{ .prefix = "// ", .postfix = "" } },
    .{ "py", CommentStyle{ .prefix = "# ", .postfix = "" } },
    .{ "sh", CommentStyle{ .prefix = "# ", .postfix = "" } },
    .{ "bash", CommentStyle{ .prefix = "# ", .postfix = "" } },
    .{ "css", CommentStyle{ .prefix = "/* ", .postfix = " */" } },
    .{ "html", CommentStyle{ .prefix = "<!-- ", .postfix = " -->" } },
    .{ "xml", CommentStyle{ .prefix = "<!-- ", .postfix = " -->" } },
});

pub fn commentStyle(extension: []const u8) !CommentStyle {
    return styles.get(extension) orelse error.UnrecognizedFileExtension;
}

test "target license recognition requires an exact SPDX header" {
    try std.testing.expect(firstLineHasTarget("# SPDX-License-Identifier: MIT", "MIT"));
    try std.testing.expect(firstLineHasTarget("// SPDX-License-Identifier: MIT", "MIT"));
    try std.testing.expect(firstLineHasTarget("/* SPDX-License-Identifier: MIT */", "MIT"));
    try std.testing.expect(firstLineHasTarget("<!-- SPDX-License-Identifier: MIT -->", "MIT"));
    try std.testing.expect(firstLineHasTarget("# SPDX-License-Identifier: PSF-2.0 AND (MIT OR Apache-2.0)", "PSF-2.0 AND (MIT OR Apache-2.0)"));

    try std.testing.expect(!firstLineHasTarget("# SPDX-License-Identifier: Apache-2.0", "MIT"));
    try std.testing.expect(!firstLineHasTarget("# SPDX-License-Identifier: MIT-0", "MIT"));
    try std.testing.expect(!firstLineHasTarget("#ifndef Py_LIMITED_API", "MIT"));
    try std.testing.expect(!firstLineHasTarget("MIT", "MIT"));
    try std.testing.expect(!firstLineHasTarget("not SPDX-License-Identifier: MIT", "MIT"));
}

test "comment styles include markup and source files" {
    try std.testing.expectEqualStrings("<!-- ", (try commentStyle("html")).prefix);
    try std.testing.expectEqualStrings("# ", (try commentStyle("py")).prefix);
}
