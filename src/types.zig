const std = @import("std");
const zap = @import("zap");
const json = @import("json");

const alloc = std.heap.page_allocator;

pub const Market = struct {
    markets: std.ArrayList(Orderbook) = std.ArrayList(Orderbook).init(alloc),

    pub fn to_json(self: Market) ![]const u8 {
        return json.toSlice(alloc, self);
    }

    pub fn add_orderbook(self: *Market, orderbook: Orderbook) !void {
        return self.markets.append(orderbook);
    }

    pub fn add_order(self: Market, m_id: u32, is_buy: bool, order: Order) !void {
        return self.markets.items[m_id].add_order(is_buy, order);
    }
};

pub const Orderbook = struct {
    id: u32,
    base: []const u8,
    quote: []const u8,
    buy: std.ArrayList(Order) = std.ArrayList(Order).init(alloc),
    sell: std.ArrayList(Order) = std.ArrayList(Order).init(alloc),

    pub fn to_json(self: *Orderbook) ![]const u8 {
        return json.toSlice(alloc, self);
    }

    pub fn add_order(self: *Orderbook, is_buy: bool, order: Order) !void {
        if (is_buy) {
            return self.buy.append(order);
        } else {
            return self.sell.append(order);
        }
    }
};

pub const Order = struct {
    id: u64,
    quantity: u64,
    price: u64,

    pub fn default() Order {
        return .{
            .id = 0,
            .quantity = 0,
            .price = 0,
        };
    }
};
