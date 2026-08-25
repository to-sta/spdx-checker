// SPDX-License-Identifier: MIT
//! Root for native unit tests across the reorganized modules.

test {
    _ = @import("core/header.zig");
    _ = @import("filesystem/glob.zig");
    _ = @import("filesystem/selector.zig");
}
