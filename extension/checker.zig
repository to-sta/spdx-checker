// SPDX-License-Identifier: MIT
//! Core SPDX license-checking logic.
//!
//! This module contains the business logic for walking a list of files,
//! checking (and optionally fixing) their SPDX license header, and printing
//! CLI-style progress/summary output. It has no direct dependency on the
//! Python C API - `main.zig` is responsible for translating `CheckError`
//! values returned from `run()` into Python exceptions.
const std = @import("std");
const parse = @import("parse.zig");
const filter = @import("utils/filter.zig");
const fix = @import("utils/fix.zig");
const output = @import("utils/output.zig");

const Arguments = parse.Arguments;
const ColorSet = output.ColorSet;
const printLine = output.printLine;

/// Errors that stop the check early and are surfaced to Python as a
/// `ValueError` by `main.zig`.
pub const CheckError = error{
    FilterByExtensionFailed,
    FilterByExcludeFailed,
    FileOpenFailed,
    FixFailed,
    LicenseMismatchStop,
    SomeFilesMismatched,
};

/// Summary of a completed check run, returned when no `CheckError` occurred.
pub const CheckResult = struct {
    checked_files: usize,
    matched_files: usize,
    elapsed_ns: i96,
    original_file_count: usize,
    final_file_count: usize,
    filtered_by_extension: bool,
    filtered_by_exclude: bool,
};

/// Outcome of checking (and possibly fixing) a single file.
const FileOutcome = enum {
    skipped_empty,
    read_error,
    open_failed,
    fix_failed,
    matched,
    fixed,
    mismatch_warning,
};

/// Line buffer sized to read just the first line of a file for the license
/// header check.
const line_buffer_size = 256;
/// Buffer backing the file's buffered `Io.Reader`.
const reader_buffer_size = 256;

/// Bundles the dependencies needed to check a single file so they don't need
/// to be threaded through as separate parameters.
const FileContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    stdout: *std.Io.Writer,
    colors: ColorSet,
    args: *const Arguments,
    cwd: std.Io.Dir,

    fn processFile(
        self: FileContext,
        file_path: []const u8,
        reader_buffer: []u8,
        line_buffer: []u8,
    ) CheckError!FileOutcome {
        const trimmed_path = std.mem.trim(u8, file_path, " \t\n\r");

        if (trimmed_path.len == 0) {
            printLine(self.stdout, "{s}Warning:{s} Skipping empty file path.\n", .{ self.colors.yellow, self.colors.reset });
            return .skipped_empty;
        }

        const file = self.cwd.openFile(self.io, trimmed_path, .{ .mode = .read_write }) catch |err| {
            printLine(self.stdout, "{s}E:{s} Could not open file: {s} {}\n", .{ self.colors.red, self.colors.reset, trimmed_path, err });
            if (!self.args.continue_on_error) {
                return error.FileOpenFailed;
            }
            return .open_failed;
        };
        defer file.close(self.io);

        // Read first line via the file's buffered Io.Reader.
        var file_reader = file.reader(self.io, reader_buffer);
        const bytes_read = file_reader.interface.readSliceShort(line_buffer) catch {
            printLine(self.stdout, "{s}E:{s} reading file: {s}\n", .{ self.colors.red, self.colors.reset, trimmed_path });
            return .read_error;
        };

        const newline_pos = std.mem.indexOf(u8, line_buffer[0..bytes_read], "\n") orelse bytes_read;
        const first_line = line_buffer[0..newline_pos];

        if (std.mem.indexOf(u8, first_line, self.args.target_license) != null) {
            return .matched;
        }

        if (self.args.fix) {
            const file_extension = filter.getFileExtension(trimmed_path);

            fix.addLicenseHeader(self.allocator, self.io, self.args.*, file, file_extension) catch |err| {
                printLine(self.stdout, "{s}E:{s} {s}\t{}\n", .{ self.colors.red, self.colors.reset, trimmed_path, err });
                if (!self.args.continue_on_error) {
                    return error.FixFailed;
                }
                return .fix_failed;
            };
            printLine(self.stdout, "{s}F:{s}{s} target license mismatch '{s}'.\n", .{ self.colors.green, self.colors.reset, trimmed_path, self.args.target_license });
            return .fixed;
        }

        if (self.args.continue_on_error) {
            printLine(self.stdout, "{s}W:{s}{s} target license mismatch '{s}'.\n", .{ self.colors.yellow, self.colors.reset, trimmed_path, self.args.target_license });
            return .mismatch_warning;
        }

        printLine(self.stdout, "File '{s}' does not match target license '{s}'.\n", .{ trimmed_path, self.args.target_license });
        return error.LicenseMismatchStop;
    }
};

/// Runs the SPDX license check over `args.file_paths`, printing CLI-style
/// progress and a summary to `stdout`. Filters `args.file_paths` in place by
/// extension and exclude pattern before checking.
///
/// Returns a `CheckResult` on success (including the "no files after
/// filtering" case), or a `CheckError` if the check needs to stop early.
pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    stdout: *std.Io.Writer,
    colors: ColorSet,
    args: *Arguments,
) CheckError!CheckResult {
    const start_ts = std.Io.Clock.Timestamp.now(io, .awake);
    const cwd = std.Io.Dir.cwd();

    const original_file_count = args.file_paths.len;
    const filtered_by_extension = filter.filterByExtensions(allocator, args.extensions, &args.file_paths) catch {
        return error.FilterByExtensionFailed;
    };
    const filtered_by_exclude = filter.filterByGlobPattern(allocator, args.exclude, &args.file_paths) catch {
        return error.FilterByExcludeFailed;
    };

    if (args.file_paths.len == 0) {
        printLine(stdout, "\n{s}No files to process after filtering by provided extensions.{s}\n\n", .{ colors.yellow, colors.reset });
        return CheckResult{
            .checked_files = 0,
            .matched_files = 0,
            .elapsed_ns = start_ts.untilNow(io).raw.nanoseconds,
            .original_file_count = original_file_count,
            .final_file_count = 0,
            .filtered_by_extension = filtered_by_extension,
            .filtered_by_exclude = filtered_by_exclude,
        };
    }

    printLine(stdout, "\n\n{s}Warnings / Errors:{s}\n\n", .{ colors.bold, colors.reset });

    var checked_files: usize = 0;
    var matched_files: usize = 0;
    var line_buffer: [line_buffer_size]u8 = undefined;
    var reader_buffer: [reader_buffer_size]u8 = undefined;

    const ctx = FileContext{
        .allocator = allocator,
        .io = io,
        .stdout = stdout,
        .colors = colors,
        .args = args,
        .cwd = cwd,
    };

    for (args.file_paths) |file_path| {
        // Increment checked files count, so it can be printed in summary later
        checked_files += 1;

        const outcome = ctx.processFile(file_path, &reader_buffer, &line_buffer) catch |err| {
            if (err == error.LicenseMismatchStop) {
                const elapsed_ns = start_ts.untilNow(io).raw.nanoseconds;
                const elapsed_ms = @divTrunc(elapsed_ns, std.time.ns_per_ms);
                printLine(stdout, "Files with license '{s}': {d} / {d} Files\n", .{ args.target_license, matched_files, checked_files });
                printLine(stdout, "License check completed in ({d}ns) {d}ms \n", .{ elapsed_ns, elapsed_ms });
            }
            return err;
        };

        switch (outcome) {
            .matched, .fixed => matched_files += 1,
            .skipped_empty, .read_error, .open_failed, .fix_failed, .mismatch_warning => {},
        }
    }

    const elapsed_ns = start_ts.untilNow(io).raw.nanoseconds;
    const elapsed_ms = @divTrunc(elapsed_ns, std.time.ns_per_ms);

    printLine(stdout, "\n{s}Summary:{s}\n\n", .{ colors.bold, colors.reset });
    printLine(stdout, "Files with license:\t\t{d}/{d} Files\n", .{ matched_files, checked_files });
    printLine(stdout, "License check completed in {s}({d}ns) {d}ms {s}\n\n", .{ colors.bold, elapsed_ns, elapsed_ms, colors.reset });

    if (filtered_by_extension) {
        printLine(stdout, "{s}Note:{s} File paths were filtered down from {d} to {d} by extensions provided.\n\n", .{ colors.yellow, colors.reset, original_file_count, args.file_paths.len });
    }

    if (filtered_by_exclude) {
        printLine(stdout, "{s}Note:{s} File paths were filtered down by exclude patterns provided.\n\n", .{ colors.yellow, colors.reset });
    }

    if (matched_files != checked_files) {
        return error.SomeFilesMismatched;
    }

    return CheckResult{
        .checked_files = checked_files,
        .matched_files = matched_files,
        .elapsed_ns = elapsed_ns,
        .original_file_count = original_file_count,
        .final_file_count = args.file_paths.len,
        .filtered_by_extension = filtered_by_extension,
        .filtered_by_exclude = filtered_by_exclude,
    };
}
