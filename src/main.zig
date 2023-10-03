const std = @import("std");
const zap = @import("zap");

const a = std.heap.page_allocator;
const token = "ABCDEFG";

const HTTP_RESPONSE: []const u8 =
    \\ <html><body>
    \\   Hello from ZAP!!!
    \\ </body></html>
;

fn endpoint_http_get(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    _ = e;
    r.sendBody(HTTP_RESPONSE) catch return;
}

pub fn main() !void {
    // setup listener
    var listener = zap.SimpleEndpointListener.init(
        a,
        .{
            .port = 3000,
            .on_request = null,
            .log = true,
            .max_clients = 10,
            .max_body_size = 1 * 1024,
        },
    );
    defer listener.deinit();

    // create mini endpoint
    var ep = zap.SimpleEndpoint.init(.{
        .path = "/api",
        .get = endpoint_http_get,
    });

    try listener.addEndpoint(&ep);

    listener.listen() catch {};

    // start worker threads
    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
