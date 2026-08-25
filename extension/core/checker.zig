// SPDX-License-Identifier: MIT
//! Python- and presentation-independent checking pipeline.

const std = @import("std");
const header = @import("header.zig");
const Config = @import("config.zig").Config;
const result = @import("result.zig");
const selector = @import("../filesystem/selector.zig");
const fixer = @import("../filesystem/fixer.zig");

pub const CheckReport = result.CheckReport;
pub const Event = result.Event;

const line_buffer_size = 256;
const reader_buffer_size = 256;

const FileOutcome = enum {
    skipped_empty,
    read_error,
    open_failed,
    fix_failed,
    matched,
    fixed,
    mismatch,
};

fn processFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    cwd: std.Io.Dir,
    config: Config,
    observer: anytype,
    file_path: []const u8,
    reader_buffer: []u8,
    line_buffer: []u8,
) FileOutcome {
    const trimmed_path = std.mem.trim(u8, file_path, " \t\n\r");
    if (trimmed_path.len == 0) {
        observer.onEvent(.empty_path);
        return .skipped_empty;
    }

    const file = cwd.openFile(io, trimmed_path, .{
        .mode = if (config.fix) .read_write else .read_only,
    }) catch |err| {
        observer.onEvent(.{ .open_failed = .{ .path = trimmed_path, .err = err } });
        return .open_failed;
    };
    defer file.close(io);

    var file_reader = file.reader(io, reader_buffer);
    const bytes_read = file_reader.interface.readSliceShort(line_buffer) catch |err| {
        observer.onEvent(.{ .read_failed = .{ .path = trimmed_path, .err = err } });
        return .read_error;
    };

    const newline_position = std.mem.indexOf(u8, line_buffer[0..bytes_read], "\n") orelse bytes_read;
    const first_line = line_buffer[0..newline_position];
    if (header.firstLineHasTarget(first_line, config.target_license)) return .matched;

    if (config.fix) {
        fixer.addLicenseHeader(
            allocator,
            io,
            config.target_license,
            file,
            selector.extension(trimmed_path),
        ) catch |err| {
            observer.onEvent(.{ .fix_failed = .{ .path = trimmed_path, .err = err } });
            return .fix_failed;
        };
        observer.onEvent(.{ .fixed = .{
            .path = trimmed_path,
            .target_license = config.target_license,
        } });
        return .fixed;
    }

    observer.onEvent(.{ .mismatch = .{
        .path = trimmed_path,
        .target_license = config.target_license,
    } });
    return .mismatch;
}

/// Checks every selected file and returns a constant-size aggregate report.
/// Per-file diagnostics are sent to `observer` and can be streamed immediately.
pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    config: Config,
    observer: anytype,
) CheckReport {
    const start_timestamp = std.Io.Clock.Timestamp.now(io, .awake);
    var report = CheckReport{ .input_files = config.file_paths.len };

    // Count selected files without materializing a second path array.
    for (config.file_paths) |file_path| {
        switch (selector.select(config, file_path)) {
            .include => report.selected_files += 1,
            .excluded_by_extension => report.filtered_by_extension = true,
            .excluded_by_pattern => report.filtered_by_exclude = true,
        }
    }

    var line_buffer: [line_buffer_size]u8 = undefined;
    var reader_buffer: [reader_buffer_size]u8 = undefined;
    const cwd = std.Io.Dir.cwd();

    for (config.file_paths) |file_path| {
        if (selector.select(config, file_path) != .include) continue;
        report.checked_files += 1;

        const outcome = processFile(
            allocator,
            io,
            cwd,
            config,
            observer,
            file_path,
            &reader_buffer,
            &line_buffer,
        );

        switch (outcome) {
            .matched => report.matched_files += 1,
            .fixed => {
                report.matched_files += 1;
                report.fixed_files += 1;
            },
            .mismatch => {
                report.mismatched_files += 1;
                if (!config.continue_on_error) {
                    report.stop_reason = .license_mismatch;
                }
            },
            .skipped_empty => report.skipped_files += 1,
            .read_error => report.io_errors += 1,
            .open_failed => {
                report.io_errors += 1;
                if (!config.continue_on_error) report.stop_reason = .file_open_failed;
            },
            .fix_failed => {
                report.io_errors += 1;
                if (!config.continue_on_error) report.stop_reason = .fix_failed;
            },
        }

        if (report.stop_reason != null) break;
    }

    report.elapsed_ns = start_timestamp.untilNow(io).raw.nanoseconds;
    return report;
}
