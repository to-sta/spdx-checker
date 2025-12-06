const std = @import("std");

/// Color codes for terminal output
/// - `ansi`: ANSI escape codes for colored output
/// - `none`: No color codes (plain text)
pub const Colors = struct {
    pub const ansi = ColorSet{
        .reset = "\x1b[0m",
        .bold = "\x1b[1m",
        .underline = "\x1b[4m",
        .red = "\x1b[31m",
        .green = "\x1b[32m",
        .yellow = "\x1b[33m",
        .blue = "\x1b[34m",
        .purple = "\x1b[35m",
    };
    pub const none = ColorSet{
        .reset = "",
        .bold = "",
        .underline = "",
        .red = "",
        .green = "",
        .yellow = "",
        .blue = "",
        .purple = "",
    };

    /// Selects the appropriate ColorSet based on terminal capabilities
    pub fn select() ColorSet {
        if (std.fs.File.stdout().isTty()) {
            return ansi;
        } else {
            return none;
        }
    }
};


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
        .{ "kt", Style{ .prefix = "// ", .postfix = "" } },
        .{ "kts", Style{ .prefix = "// ", .postfix = "" } },
        .{ "swift", Style{ .prefix = "// ", .postfix = "" } },
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

pub const ColorSet = struct {
    reset: []const u8,
    bold: []const u8,
    underline: []const u8,
    red: []const u8,
    green: []const u8,
    yellow: []const u8,
    blue: []const u8,
    purple: []const u8,
};

