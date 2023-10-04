const std = @import("std");
const zap = @import("zap");
const String = @import("./zigstring.zig").String;
const json = @import("json");

const alloc = std.heap.page_allocator;
const token = "ABCDEFG";

const HTTP_RESPONSE: []const u8 =
    \\ <html><body>
    \\   Hello from ZAP!!!
    \\ </body></html>
;

const Market = struct {
    name: []const u8,
    base: []const u8,
    quote: []const u8,

    buy: std.ArrayList(Order) = std.ArrayList(Order).init(alloc),
    sell: std.ArrayList(Order) = std.ArrayList(Order).init(alloc),

    fn to_json(self: Market) ![]const u8 {
        return json.toSlice(alloc, self);
    }
};

const Order = struct {
    id: u64,
    quantity: u64,
    price: u64,

    fn random() Order {
        return .{
            .id = 0,
            .quantity = 0,
            .price = 0,
        };
    }
};

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
        if (std.mem.eql(u8, params[1], "market")) {
            var m = Market{
                .name = "abc",
                .base = "a",
                .quote = "b",
            };
            r.sendJson(m.to_json() catch return) catch return;
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

    // create mini endpoint
    var ep = zap.SimpleEndpoint.init(.{
        .path = "/api",
        .get = endpoint_http_api_get,
    });

    try listener.addEndpoint(&ep);

    listener.listen() catch {};

    // start worker threads
    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
