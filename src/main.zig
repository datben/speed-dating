const std = @import("std");
const zap = @import("zap");
const json = @import("json");
const types = @import("./types.zig");
const Tokens = @import("./types.zig").Tokens;
const endpoint = @import("./endpoint.zig");
const mem = std.mem;
const Allocator = mem.Allocator;

const default_alloc = std.heap.page_allocator;

pub fn main() !void {
    const handler = struct {
        var market: types.Market = undefined;

        pub fn init(alloc: Allocator) !void {
            market = try types.Market.init(alloc);
            return;
        }

        fn get(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
            return endpoint.endpoint_http_api_get(&market, e, r);
        }
    };
    try handler.init(default_alloc);

    try handler.market.create_orderbook(0, Tokens.A, Tokens.B);
    try handler.market.create_orderbook(1, Tokens.A, Tokens.C);
    try handler.market.create_orderbook(2, Tokens.C, Tokens.B);

    // setup listener
    var listener = zap.SimpleEndpointListener.init(
        default_alloc,
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
        .get = handler.get,
    });
    try listener.addEndpoint(&ep);

    listener.listen() catch {};

    std.debug.print("\nlisten on http://localhost:3000\n", .{});

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
