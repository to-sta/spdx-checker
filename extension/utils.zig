const std = @import("std");


pub fn cleanFirstLine(allocator: std.mem.Allocator, args: struct { first_line: []const u8 }) ![]const u8 {
    // Remove whitespace first
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

    // Create a working copy
    var working = try allocator.dupe(u8, temp_buf[0..idx]);
    defer allocator.free(working); // We'll replace this with the final result

    // Process comments (modify working slice bounds)
    var start: usize = 0;
    var end: usize = working.len;

    if (std.mem.startsWith(u8, working, "//")) {
        start = 2;
    } else if (std.mem.startsWith(u8, working, "/*")) {
        start = 2;
        end = working.len - 2;
    } else if (std.mem.startsWith(u8, working, "#")) {
        start = 1;
    } else if (std.mem.startsWith(u8, working, "<!--")) {
        start = 4;
        end = working.len - 3;
    }

    var result = working[start..end];
    if (std.mem.startsWith(u8, result, "SPDX-License-Identifier:")) {
        result = result[24..];
    }

    // Return a copy that the caller owns
    return allocator.dupe(u8, result);
}

/// This function prints a summary of the SPDX license check results.
/// It displays information about the target license, scanned files,
/// files without the correct license, and elapsed time.
pub fn printSummary(args: struct { targetLicense: []const u8, validLicenseCounter: usize, arrayScannedFiles: std.ArrayList([]const u8), arrayWrongLicense: std.ArrayList([]const u8), startNanos: i128, endNanos: i128 }) void {
    std.debug.print("========================================\n", .{});
    std.debug.print("           SPDX License Checker\n", .{});
    std.debug.print("========================================\n\n", .{});

    std.debug.print("Target license: {s}\n\n", .{args.targetLicense});

    std.debug.print("Scanned Files:\n", .{});
    std.debug.print("----------------------------------------\n", .{});
    for (args.arrayScannedFiles.items) |file_path| {
        std.debug.print("- {s}\n", .{file_path});
    }

    std.debug.print("\nFiles Without Correct License:\n", .{});
    std.debug.print("----------------------------------------\n", .{});
    for (args.arrayWrongLicense.items) |file_path| {
        std.debug.print("- {s}\n", .{file_path});
    }

    std.debug.print("\nSummary:\n", .{});
    std.debug.print("----------------------------------------\n", .{});
    std.debug.print("Files with correct license: {d} / {d}\n", .{ args.validLicenseCounter, args.validLicenseCounter + args.arrayWrongLicense.items.len });

    const elapsedNanos = args.endNanos - args.startNanos;
    const elapsed_millis = @divTrunc(elapsedNanos, std.time.ns_per_ms);
    std.debug.print("\nTime elapsed: {d}ns (~ {d}ms)\n\n", .{ elapsedNanos, elapsed_millis });
}
