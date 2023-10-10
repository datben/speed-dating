const std = @import("std");
const alloc = std.heap.page_allocator;

pub fn RndGen() std.rand.Xoroshiro128 {
    return std.rand.Xoroshiro128.init(@intCast(std.time.milliTimestamp()));
}

pub fn parse_path(path: []const u8) !std.ArrayList([]const u8) {
    var params = std.ArrayList([]const u8).init(alloc);
    var start: usize = 1;
    for (path[1..], 1..) |char, index| {
        if (char == '/') {
            try params.append(path[start..index]);
            start = index + 1;
        } else if (index == path.len - 1) {
            try params.append(path[start .. index + 1]);
        }
    }
    return params;
}
