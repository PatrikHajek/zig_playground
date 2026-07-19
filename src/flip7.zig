const std = @import("std");
const assert = std.debug.assert;

const ROUND_COUNT = 50;

const PLAYER_COUNT = 5;
// const PLAYER_COUNT_MAX = 18;

const CARD_NUMBER_COUNT = blk: {
    const deck = [_]CardNumber{ 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    var i: u8 = 0;
    for (deck) |n| {
        i += n;
    }
    break :blk i;
};
const CARD_NUMBER_COUNT_WIN = 7;
const CARD_SCORE_COUNT = 6;
const CARD_ACTION_COUNT = 9;

const CARD_COUNT = CARD_NUMBER_COUNT + CARD_SCORE_COUNT + CARD_ACTION_COUNT;

const CARD_COUNT_PER_PLAYER_MAX =
    CARD_NUMBER_COUNT_WIN + CARD_SCORE_COUNT
    // Freeze can appear only once.
    + (CARD_ACTION_COUNT - 2);

const Card = union(enum) {
    number: CardNumber,
    score: CardScore,
    action: CardAction,
};
const CardNumber = u8;
const CardScore = enum { plus_2, plus_4, plus_6, plus_8, plus_10, times_2 };
const CardAction = enum { freeze, flip_three, second_chance };

const PlayerState = enum {
    playing,
    /// Player has either gotten Flip7 or stopped voluntarily.
    won,
    lost,
};

const Player = struct {
    state: PlayerState,
    cards: Array(Card, CARD_COUNT_PER_PLAYER_MAX),

    const Self = @This();

    fn init() Player {
        return .{
            .state = PlayerState.playing,
            .cards = Array(Card, CARD_COUNT_PER_PLAYER_MAX).init(),
        };
    }

    const Draw = enum {
        // Go to the next player.
        next,
        /// Draw 3 cards for this player.
        flip_three,
    };
    fn draw(self: *Self, card: Card) error{OutOfMemory}!Draw {
        assert(self.state == .playing);

        switch (card) {
            .number => {
                if (!self.cards.has(card)) {
                    try self.cards.add(card);

                    var card_number_count: u8 = 0;
                    for (self.cards.buffer[0..self.cards.count]) |c| {
                        if (c == .number) {
                            card_number_count += 1;
                        }
                    }
                    if (card_number_count == CARD_NUMBER_COUNT_WIN) {
                        self.state = .won;
                    }
                } else {
                    try self.cards.add(card);
                    self.state = .lost;
                }
            },
            .score => {
                try self.cards.add(card);
            },
            .action => |c| {
                try self.cards.add(card);
                switch (c) {
                    .freeze => {
                        self.state = .lost;
                    },
                    .flip_three => return Draw.flip_three,
                    else => {},
                }
            },
        }

        return Draw.next;
    }

    fn print(self: *const Player, index: u8) void {
        std.debug.print("Player {}:\n", .{index + 1});
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
                if (std.meta.eql(item, v)) return true;
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
            if (p.state == .lost and !p.cards.has(Card{ .action = .freeze })) {
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
    for (&players) |*player| player.* = Player.init();

    var deck: [CARD_COUNT]Card = undefined;

    var player_count_playing: u8 = PLAYER_COUNT;
    var player_index: u8 = 0;
    var cards_to_draw: u8 = 1;
    for (0..(PLAYER_COUNT * CARD_COUNT_PER_PLAYER_MAX)) |turn| {
        const card_index = turn % CARD_COUNT;
        if (card_index == 0) {
            deck = comptime generate_deck();
            shuffle_deck(init, &deck);
        }

        if (cards_to_draw == 0) {
            cards_to_draw = 1;
            if (player_index < PLAYER_COUNT - 1) {
                player_index += 1;
            } else {
                player_index = 0;
            }
        }

        var player = &players[player_index];

        if (player.state != .playing) {
            cards_to_draw -= 1;
            continue;
        }

        const card = deck[card_index];
        cards_to_draw -= 1;
        switch (try player.draw(card)) {
            .flip_three => {
                cards_to_draw += 3;
            },
            else => {},
        }

        switch (player.state) {
            .won => break,
            .lost => {
                player_count_playing -= 1;
                cards_to_draw = 0;
                if (player_count_playing == 0) {
                    break;
                }
            },
            else => {},
        }
    }

    return players;
}

fn generate_deck() [CARD_COUNT]Card {
    var filled_count = 0;

    var deck: [CARD_COUNT]Card = undefined;
    var card_number: CardNumber = 0;
    var card_count: CardNumber = 0;
    for (filled_count..CARD_NUMBER_COUNT) |i| {
        deck[i] = Card{ .number = card_number };
        card_count += 1;

        if (card_count >= card_number) {
            card_number += 1;
            card_count = 0;
        }
    }

    filled_count += CARD_NUMBER_COUNT;

    for (filled_count..(filled_count + CARD_SCORE_COUNT)) |i| {
        const card = switch (i % @typeInfo(CardScore).@"enum".fields.len) {
            0 => CardScore.plus_2,
            1 => CardScore.plus_4,
            2 => CardScore.plus_6,
            3 => CardScore.plus_8,
            4 => CardScore.plus_10,
            5 => CardScore.times_2,
            else => unreachable,
        };
        deck[i] = Card{ .score = card };
    }

    filled_count += CARD_SCORE_COUNT;

    for (filled_count..(filled_count + CARD_ACTION_COUNT)) |i| {
        const card = switch (i % @typeInfo(CardAction).@"enum".fields.len) {
            0 => CardAction.freeze,
            1 => CardAction.flip_three,
            2 => CardAction.second_chance,
            else => unreachable,
        };
        deck[i] = Card{ .action = card };
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
