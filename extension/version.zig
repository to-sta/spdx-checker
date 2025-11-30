// SPDX-License-Identifier: MIT
const std = @import("std");

const VERSION = 0x000112; // Version 0.1.18
// This breaks down as:
// 0x00 = major (0)
// 0x01 = minor (1)  
// 0x12 = patch (18 in hex)

pub const MAJOR = (VERSION >> 16) & 0xFF;
pub const MINOR = (VERSION >> 8) & 0xFF;
pub const PATCH = VERSION & 0xFF;