const std = @import("std");
const assert = std.debug.assert;

const ROUND_COUNT = 50;

const PLAYER_COUNT = 5;
// const PLAYER_COUNT_MAX = 18;

const CARD_COUNT = blk: {
    const deck = [_]Card{ 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    var i: u8 = 0;
    for (deck) |n| {
        i += n;
    }
    break :blk i;
};

const CARD_COUNT_PER_PLAYER_MAX = 7;

const Card = u8;

const PlayerState = enum {
    playing,
    /// Player has either gotten Flip7 or stopped voluntarily.
    won,
    lost,
};

const Player = struct {
    index: u8,
    state: PlayerState,
    cards: Array(Card, 7),

    fn init(index: u8) Player {
        return .{ .index = index, .state = PlayerState.playing, .cards = Array(Card, 7).init() };
    }

    fn print(self: *const Player) void {
        std.debug.print("Player {}:\n", .{self.index + 1});
        std.debug.print("  Cards: ", .{});
        for (self.cards.buffer[0..self.cards.count]) |card| {
            std.debug.print("{} ", .{card});
        }
        std.debug.print("\n", .{});
    }
};

fn Array(comptime T: type, comptime size: usize) type {
    return struct {
        buffer: [size]T,
        /// Size of currently filled area of the buffer.
        count: usize,

        const Self = @This();

        fn init() Array(T, size) {
            return .{ .buffer = undefined, .count = 0 };
        }

        fn add(self: *Self, v: T) error{OutOfMemory}!void {
            if (self.count < size) {
                self.buffer[self.count] = v;
                self.count += 1;
            } else {
                return error.OutOfMemory;
            }
        }

        fn has(self: *const Self, v: T) bool {
            for (self.buffer[0..self.count]) |item| {
                if (item == v) return true;
            }
            return false;
        }
    };
}

pub fn main(init: std.process.Init) !void {
    // var gpa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer gpa.deinit();
    // const allocator = gpa.allocator();

    // const players = try play_round(init);
    // for (players) |p| {
    //     p.print();
    // }

    var loser_card_sum: f32 = 0;
    var winner_count: f32 = 0;
    for (0..ROUND_COUNT) |_| {
        const players = try play_round(init);

        for (players) |p| {
            if (p.state == .lost) {
                loser_card_sum += @floatFromInt(p.cards.count);
            }
        }

        for (players) |p| {
            if (p.state == .won) {
                winner_count += 1;
            }
        }
    }

    const ROUND_COUNT_f32: f32 = @floatFromInt(ROUND_COUNT);
    const loser_card_count_average_per_round: f32 = loser_card_sum / PLAYER_COUNT / ROUND_COUNT_f32;
    std.debug.print("You bust in round {} on average\n", .{loser_card_count_average_per_round});

    const player_count = PLAYER_COUNT * ROUND_COUNT;
    const winner_rate = winner_count / player_count;
    std.debug.print("You win {}% of rounds\n", .{winner_rate * 100});
}

fn play_round(init: std.process.Init) error{OutOfMemory}![PLAYER_COUNT]Player {
    var players: [PLAYER_COUNT]Player = undefined;
    for (0..PLAYER_COUNT) |i| players[i] = Player.init(@intCast(i));

    var deck = comptime generate_deck();
    shuffle_deck(init, &deck);
    // Deck is not reshuffled, so too many players can essentially cause
    // deadlock.
    comptime assert(PLAYER_COUNT * CARD_COUNT_PER_PLAYER_MAX < deck.len);

    for (deck, 0..) |card, turn| {
        var player = &players[turn % PLAYER_COUNT];

        if (player.state != .playing) continue;

        if (!player.cards.has(card)) {
            try player.cards.add(card);
            if (player.cards.count == 7) {
                player.state = .won;
            }
        } else {
            try player.cards.add(card);
            player.state = .lost;
        }
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

    return deck;
}

fn shuffle_deck(init: std.process.Init, deck: *[CARD_COUNT]Card) void {
    var seed: u64 = undefined;
    init.io.random(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();
    random.shuffleWithIndex(Card, deck, u64);
}

test "Array" {
    const testing = std.testing;

    var arr = Array(i32, 2).init();

    try testing.expectEqual(0, arr.count);
    try testing.expect(!arr.has(5));

    try arr.add(5);
    try testing.expectEqual(1, arr.count);
    try testing.expect(arr.has(5));

    try arr.add(7);
    try testing.expectEqual(2, arr.count);
    try testing.expect(arr.has(5));
    try testing.expect(arr.has(7));

    try testing.expectEqual(error.OutOfMemory, arr.add(9));
    try testing.expectEqual(2, arr.count);
    try testing.expect(arr.has(5));
    try testing.expect(arr.has(7));
}
