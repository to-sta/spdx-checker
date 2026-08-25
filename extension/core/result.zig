// SPDX-License-Identifier: MIT
//! Constant-size results and transient events produced by the checker.

/// Why a run stopped before every selected file was processed.
pub const StopReason = enum {
    file_open_failed,
    fix_failed,
    license_mismatch,
};

/// Aggregate result of a check. It intentionally does not retain an entry for
/// every file, so memory use does not grow with the size of the codebase.
pub const CheckReport = struct {
    input_files: usize = 0,
    selected_files: usize = 0,
    checked_files: usize = 0,
    matched_files: usize = 0,
    fixed_files: usize = 0,
    mismatched_files: usize = 0,
    skipped_files: usize = 0,
    io_errors: usize = 0,
    elapsed_ns: i96 = 0,
    filtered_by_extension: bool = false,
    filtered_by_exclude: bool = false,
    stop_reason: ?StopReason = null,

    pub fn succeeded(self: CheckReport) bool {
        return self.stop_reason == null and
            self.mismatched_files == 0 and
            self.skipped_files == 0 and
            self.io_errors == 0;
    }
};

pub const Failure = struct {
    path: []const u8,
    err: anyerror,
};

pub const Mismatch = struct {
    path: []const u8,
    target_license: []const u8,
};

/// Events are observed while a run is in progress and discarded immediately
/// afterwards. Reporters can therefore stream diagnostics without accumulating
/// a per-file result list.
pub const Event = union(enum) {
    empty_path,
    open_failed: Failure,
    read_failed: Failure,
    fix_failed: Failure,
    fixed: Mismatch,
    mismatch: Mismatch,
};
