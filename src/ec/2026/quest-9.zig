const common = @import("common");
const std = @import("std");

const utils = common.utils;
const EC = common.EC;

const TEST_INPUT =
  \\id=1, growth=3, limit=10
  \\id=2, growth=5, limit=20
  \\id=3, growth=7, limit=30
  ;

const Seed = struct { growth: usize, limit: usize };

const Input = struct {
  iter: std.mem.TokenIterator(u8, .any),

  pub fn init(source: []const u8) Input {
    return .{ .iter = std.mem.tokenizeAny(u8, source, "\r\n") };
  }

  pub fn next(self: *Input) !?Seed {
    const line = self.iter.next() orelse return null;
    var it: utils.SequenceIterator(u8, utils.isBase10Digit) = .init(line);
    _ = it.next();

    return .{
      .growth = try std.fmt.parseUnsigned(usize, it.next().?, 10),
      .limit = try std.fmt.parseUnsigned(usize, it.next().?, 10)
    };
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput);

  var total: usize = 0;
  while (try input.next()) |seed| {
    if (seed.limit <= 1) {
      total += seed.limit;
      continue;
    }

    const counts = try allocator.alloc(usize, seed.growth - 1);
    defer allocator.free(counts);

    @memset(counts, 0);
    counts[0] = 1;

    var branchingPoints: usize = 0;
    var seconds: usize = 1;
    while (true) {
      seconds += 1;

      const splits = counts[counts.len - 1];

      @memmove(counts[1..], counts[0..counts.len - 1]);

      counts[0] = splits;
      branchingPoints += splits;
      counts[seed.growth / 2 - 1] += splits * 2;

      var elements: usize = branchingPoints;
      for (0..counts.len) |i| elements += (i + 1) * counts[i];

      if (elements >= seed.limit) break;
    }

    total += seconds;
  }

  return total;
}

fn part2_and_3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput);

  var countBySplitSeconds: std.AutoHashMap(usize, usize) = .init(allocator);
  defer countBySplitSeconds.deinit();

  var total: usize = 0;
  while (try input.next()) |seed| {
    if (seed.limit <= 1) {
      total += seed.limit;
      continue;
    }

    countBySplitSeconds.clearRetainingCapacity();
    try countBySplitSeconds.put(seed.growth, 1);

    var leafs: usize = 1;
    while (true) {
      var seconds: usize = 0;
      var splits: usize = 0;

      var it = countBySplitSeconds.iterator();
      while (it.next()) |entry|
        if (seconds == 0 or seconds > entry.key_ptr.*) {
          seconds = entry.key_ptr.*;
          splits = entry.value_ptr.*;
        };

      _ = countBySplitSeconds.remove(seconds);

      var entry = try countBySplitSeconds.getOrPutValue(seconds + seed.growth - 1, 0);
      entry.value_ptr.* += splits;

      entry = try countBySplitSeconds.getOrPutValue(seconds + seed.growth / 2 + 1, 0);
      entry.value_ptr.* += splits * 2;

      leafs += splits;
      if (leafs >= seed.limit) {
        total += seconds;
        break;
      }
    }
  }

  return total;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 9,
  .parts = &.{
    .{ .run = &part1, .expected = 209, .@"test" = .{ .input = TEST_INPUT, .expected = 27 } },
    .{ .run = &part2_and_3, .expected = 15514, .@"test" = .{ .input = TEST_INPUT, .expected = 42 } },
    .{ .run = &part2_and_3, .expected = 841961323105027 }
  }
});
