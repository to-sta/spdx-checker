// SPDX-License-Identifier: MIT

const VERSION = 0x000117; // Version 0.1.23

pub const MAJOR = (VERSION >> 16) & 0xFF;
pub const MINOR = (VERSION >> 8) & 0xFF;
pub const PATCH = VERSION & 0xFF;
