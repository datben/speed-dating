const std = @import("std");
const zap = @import("zap");
const json = @import("json");
const types = @import("./types.zig");
const Tokens = @import("./types.zig").Tokens;
const utils = @import("./utils.zig");
const ErrorSD = @import("./error.zig").ErrorSD;
const err = @import("./error.zig");

// - /api/market
// - /api/market/{market_id}/{is_buy}/{quantity}/{price}/{user_id}
// - /api/user/balance/{user_id}
// - /api/user/create/{pwd}
pub fn endpoint_http_api_get(market: types.Market, e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    _ = e;
    var rng = utils.RndGen();
    if (r.path) |path| {
        const parsed_path = utils.parse_path(path) catch return;
        const params = parsed_path.items[1..];
        if (std.mem.eql(u8, params[0], "market")) {
            const market_params = params[1..];
            if (market_params.len == 0) {
                r.sendJson(market.to_json() catch return) catch return;
            } else if (market_params.len == 5) {
                const market_id = std.fmt.parseInt(u32, market_params[0], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
                if (market.markets.contains(market_id) == false) {
                    return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
                }
                const is_buy = std.fmt.parseInt(u8, market_params[1], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
                const quantity = std.fmt.parseInt(u64, market_params[2], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
                const price = std.fmt.parseInt(u64, market_params[3], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
                const used_id = std.fmt.parseInt(u64, market_params[4], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
                const order_id = rng.random().int(u64);
                market.add_order(market_id, is_buy == 0, .{ .id = order_id, .price = price, .quantity = quantity, .user_id = used_id }) catch return err.send_error(r, 400, ErrorSD.InternalServerError) catch return;
            }
        } else if (std.mem.eql(u8, params[0], "user")) {
            const user_params = params[1..];
            if (std.mem.eql(u8, user_params[0], "create")) {
                const id = rng.random().int(u64);
                market.create_user(id, 1234) catch return err.send_error(r, 400, ErrorSD.InternalServerError) catch return;
            }
        }
    }
}
