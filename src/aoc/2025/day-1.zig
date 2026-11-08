const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\L68
  \\L30
  \\R48
  \\L5
  \\R60
  \\L55
  \\L1
  \\L99
  \\R14
  \\L82
  ;

pub const Direction = enum { Left, Right };

pub const Turn = struct {
  direction: Direction,
  amount: usize
};

pub const Input = struct {
  iter: std.mem.TokenIterator(u8, .any),

  pub fn init(source: []const u8) Input {
    return .{ .iter = std.mem.tokenizeAny(u8, source, "\r\n") };
  }

  pub fn next(self: *Input) !?Turn {
    const line = self.iter.next() orelse return null;

    const direction: Direction = switch (line[0]) {
      'L' => .Left,
      'R' => .Right,
      else => return error.InvalidInput
    };

    const amount = try std.fmt.parseUnsigned(usize, line[1..], 10);

    return .{ .direction = direction, .amount = amount };
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);
  
  var password: usize = 0;
  var dial: usize = 50;

  while (try input.next()) |turn| {
    const amount = turn.amount % 100;

    switch (turn.direction) {
      .Left => {
        if (amount <= dial) dial -= amount
        else dial = 100 - (amount - dial);
      },
      .Right => dial = (dial + amount) % 100
    }

    if (dial == 0) password += 1;
  }

  return password;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var password: usize = 0;
  var dial: usize = 50;

  while (try input.next()) |turn| {
    password += turn.amount / 100;
    const amount = turn.amount % 100;

    switch (turn.direction) {
      .Left => {
        if (dial != 0 and amount >= dial) password += 1;

        if (amount <= dial) dial -= amount
        else dial = 100 - (amount - dial);
      },
      .Right => {
        if (dial + amount >= 100) password += 1;
        dial = (dial + amount) % 100;
      }
    }
  }

  return password;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 1,
  .parts = &.{
    .{ .run = &part1, .expected = 1071, .@"test" = .{ .input = TEST_INPUT, .expected = 3 } },
    .{ .run = &part2, .expected = 6700, .@"test" = .{ .input = TEST_INPUT, .expected = 6 } }
  }
});
