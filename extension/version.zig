// SPDX-License-Identifier: MIT
const std = @import("std");

const VERSION = 0x000114; // Version 0.1.20
// This breaks down as:
// 0x00 = major (0)
// 0x01 = minor (1)  
// 0x14 = patch (20 in hex)

pub const MAJOR = (VERSION >> 16) & 0xFF;
pub const MINOR = (VERSION >> 8) & 0xFF;
pub const PATCH = VERSION & 0xFF;