const std = @import("std");
const zap = @import("zap");
const json = @import("json");
const ErrorSD = @import("./error.zig").ErrorSD;
const utils = @import("./utils.zig");
const mem = std.mem;
const Allocator = mem.Allocator;

pub const Tokens = enum {
    A,
    B,
    C,

    pub const len = 3;

    pub fn to_int(self: Tokens) usize {
        return @intFromEnum(self);
    }

    pub fn all() [Tokens.len]Tokens {
        return .{ Tokens.A, Tokens.B, Tokens.C };
    }
};

pub const Market = struct {
    tokens: [Tokens.len]Tokens,
    markets: std.AutoHashMap(u32, Orderbook),
    users: std.AutoHashMap(u64, User),
    allocator: Allocator,

    const Self = @This();

    pub fn init(alloc: Allocator) !Self {
        return Self{ .tokens = Tokens.all(), .markets = std.AutoHashMap(u32, Orderbook).init(alloc), .users = std.AutoHashMap(u64, User).init(alloc), .allocator = alloc };
    }

    pub fn to_json(self: Market) ![]const u8 {
        return json.toSlice(self.allocator, .{ .tokens = self.tokens, .markets = self.markets });
    }

    pub fn create_orderbook(
        self: *Market,
        id: u32,
        base: Tokens,
        quote: Tokens,
    ) !void {
        return self.markets.put(id, try Orderbook.init(self.allocator, id, base, quote));
    }

    pub fn add_order(self: Market, m_id: u32, is_buy: bool, order: Order) !void {
        if (self.markets.getPtr(m_id)) |ptr| {
            return ptr.add_order(is_buy, order);
        } else {
            return;
        }
    }

    pub fn create_user(self: *Market, user_id: u32, pwd_hash: []const u8) !void {
        var new_user = try User.init(self.allocator, user_id, pwd_hash);
        try new_user.balance.appendNTimes(10000, Tokens.len);
        try self.users.put(user_id, new_user);
        return;
    }

    pub fn get_user(self: Market, user_id: u64) !*User {
        if (self.users.getPtr(user_id)) |ptr| {
            return ptr;
        } else {
            return ErrorSD.UserNotFound;
        }
    }
};

pub const Orderbook = struct {
    id: u32,
    base: Tokens,
    quote: Tokens,
    buy: std.ArrayList(Order),
    sell: std.ArrayList(Order),
    allocator: Allocator,

    const Self = @This();

    pub fn init(alloc: Allocator, id: u32, base: Tokens, quote: Tokens) !Self {
        return Self{ .id = id, .base = base, .quote = quote, .buy = std.ArrayList(Order).init(alloc), .sell = std.ArrayList(Order).init(alloc), .allocator = alloc };
    }

    pub fn deinit(self: *Orderbook) void {
        self.buy.deinit();
        self.sell.deinit();
    }

    pub fn to_json(self: *Orderbook) ![]const u8 {
        return json.toSlice(self.alloc, self);
    }

    pub fn add_order(self: *Orderbook, is_buy: bool, order: Order) !void {
        if (is_buy) {
            return self.buy.append(order);
        } else {
            return self.sell.append(order);
        }
    }

    pub fn match_price(buy: i64, sell: i64) i64 {
        return @divFloor(buy + sell, 2);
    }

    pub fn match_orders(self: *Orderbook) !std.AutoHashMap(u64, std.ArrayList(i64)) {
        if ((self.buy.items.len == 0) or (self.sell.items.len == 0)) {
            return std.AutoHashMap(u64, std.ArrayList(i64)).init(self.allocator);
        }

        std.sort.insertion(Order, self.buy.items, {}, cmp_order_price_asc);
        std.sort.insertion(Order, self.sell.items, {}, cmp_order_price_desc);

        var best_buy_order = &self.buy.items[self.buy.items.len - 1];
        var best_sell_order = &self.sell.items[self.sell.items.len - 1];
        var can_match = best_buy_order.price >= best_sell_order.price;

        var users_updates = std.AutoHashMap(u64, std.ArrayList(i64)).init(self.allocator);

        while (can_match) {
            const quantity = @min(best_buy_order.quantity, best_sell_order.quantity);

            best_buy_order.quantity -= quantity;
            best_sell_order.quantity -= quantity;
            const matched_price = match_price(best_buy_order.price, best_sell_order.price);

            // TODO : refactor to fn
            var buy_entry = users_updates.getPtr(best_buy_order.user_id);
            if (buy_entry) |entry| {
                entry.items[self.base.to_int()] += quantity;
            } else {
                var new_value = try std.ArrayList(i64).initCapacity(self.allocator, Tokens.len);
                try new_value.appendNTimes(0, Tokens.len);
                new_value.items[self.base.to_int()] = quantity;
                try users_updates.put(best_buy_order.user_id, new_value);
            }

            var sell_entry = users_updates.getPtr(best_sell_order.user_id);
            if (sell_entry) |entry| {
                entry.items[self.quote.to_int()] += quantity * matched_price;
            } else {
                var new_value = try std.ArrayList(i64).initCapacity(self.allocator, Tokens.len);
                try new_value.appendNTimes(0, Tokens.len);
                new_value.items[self.quote.to_int()] = quantity * matched_price;
                try users_updates.put(best_buy_order.user_id, new_value);
            }

            if (best_buy_order.quantity == 0) {
                _ = self.buy.pop();
            }
            if (best_sell_order.quantity == 0) {
                _ = self.sell.pop();
            }

            if ((self.buy.items.len == 0) or (self.sell.items.len == 0)) {
                can_match = false;
            } else {
                best_buy_order = &self.buy.items[self.buy.items.len - 1];
                best_sell_order = &self.buy.items[self.buy.items.len - 1];
                can_match = best_buy_order.price >= best_sell_order.price;
            }
        }
        return users_updates;
    }
};

fn cmp_order_price_asc(context: void, left: Order, right: Order) bool {
    _ = context;
    return left.price < right.price;
}

fn cmp_order_price_desc(context: void, left: Order, right: Order) bool {
    _ = context;
    return left.price > right.price;
}

pub const Order = struct {
    id: u64,
    quantity: i64,
    price: i64,
    user_id: u64,
};

pub const User = struct {
    user_id: u32,
    pwd_hash: []const u8,
    balance: std.ArrayList(i64),
    balance_locked: std.ArrayList(i64),
    allocator: Allocator,

    const Self = @This();

    pub fn init(alloc: Allocator, user_id: u32, pwd_hash: []const u8) !Self {
        return Self{ .user_id = user_id, .pwd_hash = pwd_hash, .balance = try std.ArrayList(i64).initCapacity(alloc, Tokens.len), .balance_locked = try std.ArrayList(i64).initCapacity(alloc, Tokens.len), .allocator = alloc };
    }

    pub fn to_json(self: *User) ![]const u8 {
        return json.toSlice(self.allocator, .{ .user_id = self.user_id, .balance = self.balance });
    }

    pub fn add_balance_delta(self: *User, delta: std.ArrayList(i64)) void {
        for (0..Tokens.len) |i| {
            self.balance.items[i] += delta.items[i];
        }
    }

    pub fn add_token_delta(self: *User, token: Tokens, delta: i64) !void {
        if (delta < 0 and self.balance.items[token.to_int()] < -delta) {
            return ErrorSD.NotEnoughtToken;
        } else {
            self.balance.items[token.to_int()] += delta;
        }
    }

    pub fn lock_token(self: *User, token: Tokens, amount: i64) !void {
        if (amount + self.balance_locked.items[token.to_int()] <= self.balance.items[token.to_int()]) {
            self.balance_locked.items[token.to_int()] += amount;
        } else {
            return ErrorSD.NotEnoughtToken;
        }
    }

    pub fn unlock_token(self: *User, token: Tokens, amount: i64) !void {
        if (amount <= self.balance_locked.items[token.to_int()]) {
            self.balance_locked.items[token.to_int()] -= amount;
        } else {
            return ErrorSD.NotEnoughtToken;
        }
    }

    pub fn check_pwd(self: *User, pwd_hash: []u8) bool {
        return std.mem.eql(u8, self.pwd_hash, pwd_hash);
    }

    pub fn denit(self: *User) void {
        self.balance.deinit();
        self.balance_locked.deinit();
    }
};
