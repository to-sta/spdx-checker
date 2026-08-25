// SPDX-License-Identifier: MIT
//! Configuration consumed by the checker core.
//!
//! These are borrowed values. Ownership belongs to the adapter that creates a
//! `Config` (the CPython adapter in normal package use).

pub const Config = struct {
    target_license: []const u8,
    file_paths: []const []const u8,
    extensions: []const []const u8,
    exclude: []const []const u8,
    fix: bool,
    continue_on_error: bool,
};
