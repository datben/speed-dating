const std = @import("std");
const zap = @import("zap");
const json = @import("json");
const types = @import("./types.zig");

const alloc = std.heap.page_allocator;

var market = types.Market{};

fn parse_path(path: []const u8) !std.ArrayList([]const u8) {
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

fn endpoint_http_api_get(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    _ = e;
    if (r.path) |path| {
        const parsed_path = parse_path(path) catch return;
        const params = parsed_path.items[1..];
        if (std.mem.eql(u8, params[0], "market")) {
            const market_params = params[1..];
            if (market_params.len == 0) {
                r.sendJson(market.to_json() catch return) catch return;
            } else if (market_params.len == 4) {
                const market_id = std.fmt.parseInt(u32, market_params[0], 10) catch return;
                const is_buy = std.fmt.parseInt(u8, market_params[1], 10) catch return;
                const quantity = std.fmt.parseInt(u64, market_params[2], 10) catch return;
                const price = std.fmt.parseInt(u64, market_params[3], 10) catch return;
                market.add_order(market_id, is_buy == 0, .{ .id = 0, .price = price, .quantity = quantity }) catch return;
            }
        }
    }
}

pub fn main() !void {
    // setup listener
    var listener = zap.SimpleEndpointListener.init(
        alloc,
        .{
            .port = 3000,
            .on_request = null,
            .log = true,
            .max_clients = 1000,
        },
    );
    defer listener.deinit();

    var ep = zap.SimpleEndpoint.init(.{
        .path = "/api",
        .get = endpoint_http_api_get,
    });
    try listener.addEndpoint(&ep);

    listener.listen() catch {};

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
