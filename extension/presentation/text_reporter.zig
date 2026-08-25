// SPDX-License-Identifier: MIT
//! Streaming, human-readable presentation of checker events.

const std = @import("std");
const Config = @import("../core/config.zig").Config;
const result = @import("../core/result.zig");
const version = @import("../core/version.zig");
const ColorSet = @import("colors.zig").ColorSet;

pub const TextReporter = struct {
    stdout: *std.Io.Writer,
    colors: ColorSet,
    config: Config,
    diagnostics_started: bool = false,

    fn print(self: *TextReporter, comptime format: []const u8, args: anytype) void {
        self.stdout.print(format, args) catch {};
    }

    pub fn printArguments(self: *TextReporter) void {
        self.print("{s}spdx_checker {s}v{d}.{d}.{d}{s}\n\n", .{
            self.colors.bold,
            self.colors.purple,
            version.MAJOR,
            version.MINOR,
            version.PATCH,
            self.colors.reset,
        });
        self.print("{s}Parsed Arguments:{s}\n\n", .{ self.colors.bold, self.colors.reset });
        self.print("\tTarget License:\t\t{s}\"{s}\"{s}\n", .{ self.colors.blue, self.config.target_license, self.colors.reset });
        self.print("\tFix Mode:\t\t{s}{}{s}\n", .{ self.colors.blue, self.config.fix, self.colors.reset });
        self.print("\tContinue on Error:\t{s}{}{s}\n", .{ self.colors.blue, self.config.continue_on_error, self.colors.reset });
        self.print("\tExtensions:\t\t", .{});
        for (self.config.extensions) |file_extension| {
            self.print("{s}.{s}{s} ", .{ self.colors.green, file_extension, self.colors.reset });
        }
        self.print("\n\tExclude:\t\t", .{});
        for (self.config.exclude) |pattern| {
            self.print("{s}{s}{s} ", .{ self.colors.red, pattern, self.colors.reset });
        }
        self.print("\n", .{});
    }

    fn startDiagnostics(self: *TextReporter) void {
        if (self.diagnostics_started) return;
        self.diagnostics_started = true;
        self.print("\n{s}Warnings / Errors:{s}\n\n", .{ self.colors.bold, self.colors.reset });
    }

    pub fn onEvent(self: *TextReporter, event: result.Event) void {
        self.startDiagnostics();
        switch (event) {
            .empty_path => self.print("{s}Warning:{s} Skipping empty file path.\n", .{ self.colors.yellow, self.colors.reset }),
            .open_failed => |failure| self.print("{s}E:{s} Could not open file: {s} {}\n", .{ self.colors.red, self.colors.reset, failure.path, failure.err }),
            .read_failed => |failure| self.print("{s}E:{s} reading file: {s} {}\n", .{ self.colors.red, self.colors.reset, failure.path, failure.err }),
            .fix_failed => |failure| self.print("{s}E:{s} {s}\t{}\n", .{ self.colors.red, self.colors.reset, failure.path, failure.err }),
            .fixed => |mismatch| self.print("{s}F:{s}{s} target license mismatch '{s}'.\n", .{ self.colors.green, self.colors.reset, mismatch.path, mismatch.target_license }),
            .mismatch => |mismatch| {
                if (self.config.continue_on_error) {
                    self.print("{s}W:{s}{s} target license mismatch '{s}'.\n", .{ self.colors.yellow, self.colors.reset, mismatch.path, mismatch.target_license });
                } else {
                    self.print("File '{s}' does not match target license '{s}'.\n", .{ mismatch.path, mismatch.target_license });
                }
            },
        }
    }

    pub fn printReport(self: *TextReporter, report: result.CheckReport) void {
        if (report.selected_files == 0) {
            self.print("\n{s}No files to process after filtering by provided extensions.{s}\n\n", .{ self.colors.yellow, self.colors.reset });
            return;
        }

        const elapsed_ms = @divTrunc(report.elapsed_ns, std.time.ns_per_ms);
        self.print("\n{s}Summary:{s}\n\n", .{ self.colors.bold, self.colors.reset });
        self.print("Files with license:\t\t{d}/{d} Files\n", .{ report.matched_files, report.checked_files });
        self.print("License check completed in {s}({d}ns) {d}ms {s}\n\n", .{ self.colors.bold, report.elapsed_ns, elapsed_ms, self.colors.reset });

        if (report.filtered_by_extension) {
            self.print("{s}Note:{s} File paths were filtered down from {d} to {d} by extensions provided.\n\n", .{ self.colors.yellow, self.colors.reset, report.input_files, report.selected_files });
        }
        if (report.filtered_by_exclude) {
            self.print("{s}Note:{s} File paths were filtered down by exclude patterns provided.\n\n", .{ self.colors.yellow, self.colors.reset });
        }
    }
};
