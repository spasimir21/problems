const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  "11-22,95-115,998-1012,1188511880-1188511890,222220-222224,1698522-1698528,446443-446449,38593856-38593862,565653-565659,824824821-824824827,2121212118-2121212124";

pub const Range = struct {
  min: usize,
  max: usize
};

pub const Input = struct {
  iter: std.mem.SplitIterator(u8, .scalar),

  pub fn init(source: []const u8) Input {
    return .{ .iter = std.mem.splitScalar(u8, source, ',') };
  }

  pub fn next(self: *Input) !?Range {
    const range = self.iter.next() orelse return null;
    const dashIndex = std.mem.indexOfScalar(u8, range, '-') orelse return error.InvalidInput;

    return .{
      .min = try std.fmt.parseUnsigned(usize, range[0..dashIndex], 10),
      .max = try std.fmt.parseUnsigned(usize, range[dashIndex + 1..], 10)
    };
  }
};

const MAX_DIGITS = 10;

fn getRepeatFactor(digits: usize, repeats: usize) usize {
  const mul = std.math.pow(usize, 10, digits / repeats);
  var factor: usize = 0;
  for (0..repeats) |i| factor += std.math.pow(usize, mul, i);
  return factor;
}

fn isInvalidID(id: usize, maxRepeatCount: ?usize) bool {
  const idDigits = std.math.log10_int(id) + 1;
  if (idDigits > MAX_DIGITS) unreachable;

  inline for (1..MAX_DIGITS + 1) |digits|
    if (idDigits == digits)
      inline for (2..digits + 1) |repeats| {
        if (digits % repeats != 0) continue;
        if (repeats > maxRepeatCount orelse MAX_DIGITS) return false;

        const factor = comptime getRepeatFactor(digits, repeats);
        if (id % factor == 0) return true;
      };

  return false;
}

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var result: usize = 0;

  while (try input.next()) |range| {
    for (range.min..range.max + 1) |n| {
      if (isInvalidID(n, 2)) result += n;
    }
  }

  return result;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var result: usize = 0;

  while (try input.next()) |range| {
    for (range.min..range.max + 1) |n| {
      if (isInvalidID(n, null)) result += n;
    }
  }

  return result;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 2,
  .parts = &.{
    .{ .run = &part1, .expected = 18700015741, .@"test" = .{ .input = TEST_INPUT, .expected = 1227775554 } },
    .{ .run = &part2, .expected = 20077272987, .@"test" = .{ .input = TEST_INPUT, .expected = 4174379265 } }
  }
});
