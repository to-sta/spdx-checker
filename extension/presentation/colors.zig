// SPDX-License-Identifier: MIT

const std = @import("std");

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

pub fn select(io: std.Io) ColorSet {
    return if (std.Io.File.stdout().isTty(io) catch false) ansi else none;
}
