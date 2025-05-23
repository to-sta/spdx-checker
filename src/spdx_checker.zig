const std = @import("std");
const utils = @import("utils.zig");
const py = @import("pydust");

const root = @This();

const spdx_licenses = @import("licenses.zig").licensesIdentfiers;

/// Checks if the provided `target_license` is a valid SPDX license.
///
/// Iterates through the list of known SPDX licenses (`spdx_licenses`) and compares
/// each entry with the given `target_license`. If a match is found, the function returns `true`.
/// If no match is found, an error message is printed and the function returns `false`.
///
/// Params:
///   args: A struct containing the `target_license` as a slice of `u8`.
///
/// Returns:
///   `true` if the `target_license` is recognized as a valid SPDX license, `false` otherwise.
fn checkIfLicenseIsValid(args: struct { target_license: []const u8 }) bool {
    // Check if the target_license itself is a valid SPDX license
    var is_target_license_valid = false;
    for (spdx_licenses) |spdx_license| {
        if (std.mem.eql(u8, args.target_license, spdx_license)) {
            is_target_license_valid = true;
            break;
        }
    }
    if (!is_target_license_valid) {
        std.debug.print("Error: Target license '{s}' is not a recognized SPDX license.\n", .{args.target_license});
        return false;
    }
    return true;
}

/// Checks whether all files in the provided list have the specified SPDX license identifier.
///
/// This function performs the following steps:
/// 1. Validates the target license against a list of allowed SPDX licenses.
/// 2. Splits the input string of file paths (comma-separated) and iterates over each file.
/// 3. For each file:
///    - Trims whitespace from the file path.
///    - Attempts to open the file and read its first line.
///    - Checks if the first line contains a valid SPDX license identifier.
///    - Compares the found license with the target license.
///    - Tracks files with missing or mismatched licenses.
/// 4. Prints a summary of the results, including files scanned and those missing the license.
/// 5. Returns `true` if all files have the correct license, or raises a `ValueError` if any file is missing or has a different license.
///
/// Arguments:
/// - `args.target_license`: The SPDX license identifier to check for (e.g., "MIT").
/// - `args.file_paths_string`: A comma-separated string of file paths to check.
///
/// Returns:
/// - `true` if all files have the correct SPDX license identifier.
/// - Raises a `ValueError` if any file is missing the license or has a different license.
///
/// Errors:
/// - Returns `false` or raises a `ValueError` on file I/O errors, invalid license, or allocation failures.
///
/// Example:
/// ```zig
/// const result = try spdx_license_checker(.{
///     .target_license = "MIT",
///     .file_paths_string = "src/main.zig,src/lib.zig",
/// });
/// ```
pub fn spdx_license_checker(args: struct { target_license: []const u8, file_paths_string: []const u8 }) !bool {
    // Timing the function, START
    const start_nanos = std.time.nanoTimestamp();

    const validLicense = checkIfLicenseIsValid(.{
        .target_license = args.target_license,
    });

    if (!validLicense) {
        std.debug.print("Allowed licenses:\n", .{});
        std.debug.print("----------------------------------------\n\n", .{});
        for (spdx_licenses) |spdx_license| {
            std.debug.print(" - {s}\n", .{spdx_license});
        }
        return py.ValueError.raise("Invalid license");
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const cwd = std.fs.cwd();

    var arrayScannedFiles = std.ArrayList([]const u8).init(gpa.allocator());
    defer arrayScannedFiles.deinit();
    // Output with no license and with license
    var arrayNoLicense = std.ArrayList([]const u8).init(gpa.allocator());
    defer arrayNoLicense.deinit();

    var validLicenseCounter: u8 = 0;

    // Split the file paths string by commas
    var file_paths_iterator = std.mem.split(u8, args.file_paths_string, ",");

    while (file_paths_iterator.next()) |relativeFilePath| {
        // Skip empty lines
        arrayScannedFiles.append(relativeFilePath) catch |err| {
            std.debug.print("Error appending to array: {}\n", .{err});
            return false;
        };
        if (relativeFilePath.len == 0) continue;

        // Trim whitespace from the file path
        const trimmed_path = std.mem.trim(u8, relativeFilePath, " \t\r\n");
        if (trimmed_path.len == 0) continue;

        const file = cwd.openFile(trimmed_path, .{}) catch |err| {
            std.debug.print("Error opening file '{s}': {}\n", .{ trimmed_path, err });
            return false;
        };
        defer file.close();

        var buf = std.io.bufferedReader(file.reader());
        var inStream = buf.reader();
        const firstLineOpt = inStream.readUntilDelimiterOrEofAlloc(gpa.allocator(), '\n', 1024) catch |err| {
            std.debug.print("Error reading file '{s}': {}\n", .{ trimmed_path, err });
            return false;
        };
        defer if (firstLineOpt) |firstLine| gpa.allocator().free(firstLine);

        if (firstLineOpt) |firstLine| {
            const trimmedFirstLine = utils.cleanFirstLine(.{ .first_line = firstLine });

            if (std.mem.startsWith(u8, trimmedFirstLine, "SPDX-License-Identifier:")) {
                const license = std.mem.trimLeft(u8, trimmedFirstLine[24..], " \t");
                if (!std.mem.eql(u8, license, args.target_license)) {
                    std.debug.print("Error: File '{s}' has a different license '{s}' than the target license '{s}'.\n", .{
                        trimmed_path,
                        license,
                        args.target_license,
                    });
                    return false;
                } else {
                    validLicenseCounter += 1;
                }
            } else {
                arrayNoLicense.append(trimmed_path) catch |err| {
                    std.debug.print("Error appending to array: {}\n", .{err});
                    return false;
                };
            }
        } else {
            std.debug.print("Warning: File '{s}' is empty or could not read first line.\n", .{trimmed_path});
        }
    }

    const end_nanos = std.time.nanoTimestamp();

    utils.printSummary(.{
        .targetLicense = args.target_license,
        .validLicenseCounter = validLicenseCounter,
        .arrayScannedFiles = arrayScannedFiles,
        .arrayNoLicense = arrayNoLicense,
        .startNanos = start_nanos,
        .endNanos = end_nanos,
    });

    if (arrayNoLicense.items.len > 0) {
        return py.ValueError.raise("There are files that do not match the target license.");
    }

    return true;
}

comptime {
    py.rootmodule(root);
}
