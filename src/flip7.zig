const std = @import("std");
const assert = std.debug.assert;

const PLAYER_COUNT = 5;
// const PLAYER_COUNT_MAX = 18;

const CARD_COUNT = blk: {
    const deck = [_]Card{ 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12 };
    var i: u8 = 0;
    for (deck) |n| {
        i += n;
    }
    break :blk i;
};

const CARD_COUNT_PER_PLAYER_MAX = 7;

const Card = u8;

const Player = struct {
    index: u8,
    busted: bool,
    cards: Array(Card, 7),

    fn init(index: u8) Player {
        return .{ .index = index, .busted = false, .cards = Array(Card, 7).init() };
    }

    fn print(self: *const Player) void {
        std.debug.print("Player {}:\n", .{self.index + 1});
        for (self.cards.buffer) |card| {
            std.debug.print("Card: {}\n", .{card});
        }
    }
};

fn Array(comptime T: type, comptime size: u64) type {
    return struct {
        buffer: [size]T,
        /// Size of currently filled area of the buffer.
        count: u64,

        const Self = @This();

        fn init() Array(T, size) {
            return .{ .buffer = undefined, .count = 0 };
        }

        fn add(self: *Self, v: T) error{OutOfMemory}!void {
            if (self.count != size) {
                self.buffer[self.count] = v;
            } else {
                return error.OutOfMemory;
            }
        }

        fn has(self: *const Self, v: T) bool {
            for (self.buffer) |item| {
                if (item == v) return true;
            }
            return false;
        }
    };
}

pub fn main() !void {
    // var gpa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer gpa.deinit();
    // const allocator = gpa.allocator();

    const players = try play_round();
    for (players) |p| {
        p.print();
    }
}

fn play_round() error{OutOfMemory}![PLAYER_COUNT]Player {
    var players: [PLAYER_COUNT]Player = undefined;
    for (0..PLAYER_COUNT) |i| players[i] = Player.init(@intCast(i));

    const deck = comptime generate_deck();
    // Deck is not reshuffled, so too many players can essentially cause
    // deadlock.
    comptime assert(PLAYER_COUNT * CARD_COUNT_PER_PLAYER_MAX < deck.len);

    // FIX: All players' cards are 170.
    var card_i: u8 = 0;
    for (0..deck.len) |turn| {
        var player = players[turn % PLAYER_COUNT];
        const card = deck[card_i];

        if (!player.cards.has(card)) {
            try player.cards.add(card);
        } else {
            try player.cards.add(card);
            player.busted = true;
            break;
        }

        card_i += 1;
    }

    return players;
}

fn generate_deck() [CARD_COUNT]Card {
    var deck: [CARD_COUNT]Card = undefined;
    var card: Card = 0;
    var card_count: Card = 0;
    for (0..CARD_COUNT) |i| {
        deck[i] = card;
        card_count += 1;

        if (card_count >= card) {
            card += 1;
            card_count = 0;
        }
    }

    @setEvalBranchQuota(10_000);
    var prng = std.Random.DefaultPrng.init(50);
    const random = prng.random();
    random.shuffleWithIndex(Card, &deck, u64);

    return deck;
}
