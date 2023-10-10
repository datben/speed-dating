const std = @import("std");
const zap = @import("zap");
const json = @import("json");
const types = @import("./types.zig");
const Tokens = @import("./types.zig").Tokens;
const endpoint = @import("./endpoint.zig");

const alloc = std.heap.page_allocator;

pub fn main() !void {
    const handler = struct {
        pub var market: types.Market = types.Market{};

        fn get(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
            return endpoint.endpoint_http_api_get(&market, e, r);
        }
    };

    try handler.market.create_orderbook(0, Tokens.A, Tokens.B);
    try handler.market.create_orderbook(1, Tokens.A, Tokens.C);
    try handler.market.create_orderbook(2, Tokens.C, Tokens.B);

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
        .get = handler.get,
    });
    try listener.addEndpoint(&ep);

    listener.listen() catch {};

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
