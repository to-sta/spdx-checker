const std = @import("std");
/// Cleans the first line of a file by removing common comment prefixes and surrounding whitespace.
///
/// This function is intended to extract meaningful content from the first line of source files,
/// such as license identifiers, by stripping away comment markers used in various languages
/// (e.g., `//`, `/*`, `#`, `<!--`) and any leading or trailing whitespace or comment terminators.
///
/// Supported comment styles:
/// - C/C++/JavaScript single-line (`//`)
/// - C-style block (`/* ... */`)
/// - Python/Unix shell (`#`)
/// - HTML (`<!-- ... -->`)
///
/// Returns the cleaned line as a slice, suitable for further processing.
///
/// Params:
///   args: Struct containing the `first_line` to clean.
///
/// Returns:
///   The cleaned line as a `[]const u8` slice.
pub fn cleanFirstLine(args: struct { first_line: []const u8 }) []const u8 {
    // Remove comments for html, python and javascript files
    var trimmed = std.mem.trimLeft(u8, args.first_line, " \t");

    // Ignore comment prefix if present
    if (std.mem.startsWith(u8, trimmed, "//")) {
        trimmed = std.mem.trimLeft(u8, trimmed[2..], " \t");
    } else if (std.mem.startsWith(u8, trimmed, "/*")) {
        trimmed = std.mem.trimLeft(u8, trimmed[2..], " \t");
    } else if (std.mem.startsWith(u8, trimmed, "#")) {
        trimmed = std.mem.trimLeft(u8, trimmed[1..], " \t");
    } else if (std.mem.startsWith(u8, trimmed, "<!--")) {
        trimmed = std.mem.trimLeft(u8, trimmed[4..], " \t");
        // Also trim the right side if it ends with "-->"
        if (std.mem.endsWith(u8, trimmed, "-->")) {
            trimmed = std.mem.trimRight(u8, trimmed[0 .. trimmed.len - 3], " \t");
        }
    } else if (std.mem.startsWith(u8, trimmed, "/*")) {
        // Handles cases like: /* SPDX-License-Identifier: ... */
        trimmed = std.mem.trimLeft(u8, trimmed[2..], " \t");
        // Also trim the right side if it ends with "*/"
        if (std.mem.endsWith(u8, trimmed, "*/")) {
            trimmed = std.mem.trimRight(u8, trimmed[0 .. trimmed.len - 2], " \t");
        }
    }

    // Trim both sides to remove any extra whitespace
    trimmed = std.mem.trim(u8, trimmed, " \t\r\n*/");

    return trimmed;
}

/// This function prints a summary of the SPDX license check results.
/// It displays information about the target license, scanned files,
/// files without the correct license, and elapsed time.
pub fn printSummary(args: struct { targetLicense: []const u8, validLicenseCounter: usize, arrayScannedFiles: std.ArrayList([]const u8), arrayNoLicense: std.ArrayList([]const u8), startNanos: i128, endNanos: i128 }) void {
    std.debug.print("========================================\n", .{});
    std.debug.print("           SPDX License Checker\n", .{});
    std.debug.print("========================================\n\n", .{});

    std.debug.print("Target license: {s}\n\n", .{args.targetLicense});

    std.debug.print("Scanned Files:\n", .{});
    std.debug.print("----------------------------------------\n", .{});
    for (args.arrayScannedFiles.items) |file_path| {
        std.debug.print("- {s}\n", .{file_path});
    }

    std.debug.print("\nFiles Without Correct License::\n", .{});
    std.debug.print("----------------------------------------\n", .{});
    for (args.arrayNoLicense.items) |file_path| {
        std.debug.print("- {s}\n", .{file_path});
    }

    std.debug.print("\nSummary:\n", .{});
    std.debug.print("----------------------------------------\n", .{});
    std.debug.print("Files with correct license: {d} / {d}\n", .{ args.validLicenseCounter, args.validLicenseCounter + args.arrayNoLicense.items.len });

    const elapsedNanos = args.endNanos - args.startNanos;
    const elapsed_millis = @divTrunc(elapsedNanos, std.time.ns_per_ms);
    std.debug.print("\nTime elapsed: {d}ns (~ {d}ms)\n\n", .{ elapsedNanos, elapsed_millis });
}


