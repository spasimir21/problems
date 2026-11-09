const EC = @import("common").EC;
const std = @import("std");

const TEST_INPUT = "3,11,12,16,24,25";

const Input = struct {
  iter: std.mem.SplitIterator(u8, .scalar),

  pub fn init(source: []const u8) Input {
    return .{ .iter = std.mem.splitScalar(u8, source, ',') };
  }

  pub fn next(self: *Input) !?usize {
    const number = self.iter.next() orelse return null;
    return try std.fmt.parseUnsigned(usize, number, 10);
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var cones: usize = 0;
  while (try input.next()) |count| {
    const sqrt = std.math.sqrt(count);
    if (sqrt * sqrt == count) continue;
    cones += (sqrt + 1) * (sqrt + 1) - count;
  }

  return cones;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var cones: usize = 0;
  while (try input.next()) |count| {
    if (count < 8) {
      cones += 8 - count;
      continue;
    }

    if (count % 4 == 0) continue;
    cones += 4 - count % 4;
  }

  return cones;
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var cones: usize = 0;
  while (try input.next()) |count| {
    if (count < 8) {
      cones += 8 - count;
      continue;
    }

    var side = std.math.sqrt(count) + 1;
    if (side % 2 == 0) side += 1;

    cones += side * side - 1 - count;
  }

  return cones;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 1,
  .parts = &.{
    .{ .run = &part1, .expected = 1432, .@"test" = .{ .input = TEST_INPUT, .expected = 11 } },
    .{ .run = &part2, .expected = 325, .@"test" = .{ .input = TEST_INPUT, .expected = 9 } },
    .{ .run = &part3, .expected = 639680, .@"test" = .{ .input = TEST_INPUT, .expected = 61 } }
  }
});
