const std = @import("std");
const zap = @import("zap");
const json = @import("json");
const types = @import("./types.zig");
const Tokens = @import("./types.zig").Tokens;

var RndGen = std.rand.DefaultPrng.init(0);
const alloc = std.heap.page_allocator;

const ErrorSD = error{
    BadRequest,
};

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
                if (market_id >= market.markets.items.len) {
                    return r.sendError(ErrorSD.BadRequest, 400);
                }
                const is_buy = std.fmt.parseInt(u8, market_params[1], 10) catch return r.sendError(ErrorSD.BadRequest, 400);
                const quantity = std.fmt.parseInt(u64, market_params[2], 10) catch return r.sendError(ErrorSD.BadRequest, 400);
                const price = std.fmt.parseInt(u64, market_params[3], 10) catch return r.sendError(ErrorSD.BadRequest, 400);
                const order_id = RndGen.random().int(u64);
                market.add_order(market_id, is_buy == 0, .{ .id = order_id, .price = price, .quantity = quantity }) catch return;
            }
        }
    }
}

pub fn main() !void {
    try market.add_orderbook(types.Orderbook{ .id = 0, .base = Tokens.A, .quote = Tokens.B });

    try market.add_order(0, true, .{ .id = 0, .price = 200, .quantity = 100, .user_id = 100 });

    try market.add_order(0, true, .{ .id = 0, .price = 100, .quantity = 100, .user_id = 100 });
    try market.add_order(0, false, .{ .id = 0, .price = 200, .quantity = 100, .user_id = 100 });
    std.debug.print("{s}", .{market.to_json_pretty() catch return});

    _ = try market.markets.items[0].match_orders();

    std.debug.print("{s}", .{market.to_json_pretty() catch return});

    // // setup listener
    // var listener = zap.SimpleEndpointListener.init(
    //     alloc,
    //     .{
    //         .port = 3000,
    //         .on_request = null,
    //         .log = true,
    //         .max_clients = 1000,
    //     },
    // );
    // defer listener.deinit();

    // var ep = zap.SimpleEndpoint.init(.{
    //     .path = "/api",
    //     .get = endpoint_http_api_get,
    // });
    // try listener.addEndpoint(&ep);

    // listener.listen() catch {};

    // zap.start(.{
    //     .threads = 1,
    //     .workers = 1,
    // });
}
