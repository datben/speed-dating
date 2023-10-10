const std = @import("std");
const zap = @import("zap");
const json = @import("json");
const types = @import("./types.zig");
const Tokens = @import("./types.zig").Tokens;
const utils = @import("./utils.zig");
const ErrorSD = @import("./error.zig").ErrorSD;
const err = @import("./error.zig");

const alloc = std.heap.page_allocator;

// - /api/market
// - /api/market/{market_id}/{is_buy}/{quantity}/{price}/{user_id}
// - /api/user/balance/{user_id}
// - /api/user/create/{pwd}
pub fn endpoint_http_api_get(market: *types.Market, e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    if (r.path) |path| {
        const parsed_path = utils.parse_path(path) catch return;
        const params = parsed_path.items[1..];
        if (std.mem.eql(u8, params[0], "market")) {
            const market_params = params[1..];
            if (market_params.len == 0) {
                return handle_get_market(market, e, r) catch return;
            } else if (market_params.len == 5) {
                return handle_place_order(market, e, r, market_params) catch return;
            }
        } else if (std.mem.eql(u8, params[0], "user")) {
            const user_params = params[1..];
            if (std.mem.eql(u8, user_params[0], "create")) {
                return handle_create_user(market, e, r) catch return;
            } else if (std.mem.eql(u8, user_params[0], "balance")) {
                return handle_get_balance(market, e, r, user_params) catch return;
            }
        }
    }
}

fn handle_get_market(market: *types.Market, e: *zap.SimpleEndpoint, r: zap.SimpleRequest) !void {
    _ = e;
    return r.sendJson(try market.to_json());
}

fn handle_create_user(market: *types.Market, e: *zap.SimpleEndpoint, r: zap.SimpleRequest) !void {
    _ = e;
    var rng = utils.RndGen();
    const id = rng.random().int(u64);
    market.create_user(id, 1234) catch return err.send_error(r, 400, ErrorSD.InternalServerError) catch return;
    return r.sendJson(json.toSlice(alloc, .{ .user_id = id }) catch return err.send_error(r, 400, ErrorSD.InternalServerError) catch return) catch return;
}

fn handle_get_balance(market: *types.Market, e: *zap.SimpleEndpoint, r: zap.SimpleRequest, user_params: [][]const u8) !void {
    _ = e;
    const user_id = std.fmt.parseInt(u64, user_params[1], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
    const user = market.get_user(user_id) catch return err.send_error(r, 400, ErrorSD.UserNotFound) catch return;
    const user_json = user.to_json() catch return err.send_error(r, 400, ErrorSD.InternalServerError) catch return;
    r.sendJson(user_json) catch return;
}

fn handle_place_order(market: *types.Market, e: *zap.SimpleEndpoint, r: zap.SimpleRequest, market_params: [][]const u8) !void {
    _ = e;
    var rng = utils.RndGen();
    const market_id = std.fmt.parseInt(u32, market_params[0], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
    if (market.markets.contains(market_id) == false) {
        return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
    }
    const current_market = market.markets.get(market_id).?;

    const is_buy_int = std.fmt.parseInt(u8, market_params[1], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
    const quantity = std.fmt.parseInt(i64, market_params[2], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
    const price = std.fmt.parseInt(i64, market_params[3], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;

    if (price < 0 or quantity < 0) {
        return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
    }

    const user_id = std.fmt.parseInt(u64, market_params[4], 10) catch return err.send_error(r, 400, ErrorSD.BadRequest) catch return;
    const order_id = rng.random().int(u64);
    const is_buy = is_buy_int == 0;
    market.add_order(market_id, is_buy, .{ .id = order_id, .price = price, .quantity = quantity, .user_id = user_id }) catch return err.send_error(r, 400, ErrorSD.InternalServerError) catch return;
    const user = market.get_user(user_id) catch return err.send_error(r, 400, ErrorSD.InternalServerError) catch return;

    if (is_buy) {
        user.add_token_delta(current_market.quote, -price * quantity) catch return err.send_error(r, 400, ErrorSD.NotEnoughtToken) catch return;
    } else {
        user.add_token_delta(current_market.base, -quantity) catch return err.send_error(r, 400, ErrorSD.NotEnoughtToken) catch return;
    }

    r.sendJson(json.toSlice(alloc, .{ .order_id = order_id }) catch return err.send_error(r, 400, ErrorSD.InternalServerError) catch return) catch return;
}
