const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\987654321111111
  \\811111111111119
  \\234234234234278
  \\818181911112111
  ;

pub const Input = struct {
  iter: std.mem.TokenIterator(u8, .any),
  arena: std.heap.ArenaAllocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) Input {
    return .{
      .iter = std.mem.tokenizeAny(u8, source, "\r\n"),
      .arena = .init(allocator)
    };
  }

  pub fn deinit(self: *Input) void {
    self.arena.deinit();
  }

  pub fn next(self: *Input) !?[]const u8 {
    const line = self.iter.next() orelse return null;

    const bank = try self.arena.allocator().alloc(u8, line.len);
    for (0..bank.len) |i| bank[i] = line[i] - '0';
    return bank;
  }
};

fn findMaxJoltage(bank: []const u8, n: usize) usize {
  var joltage: usize = 0;

  var left = bank;
  for (1..n + 1) |i| {
    const maxIndex = std.mem.findMax(u8, left[0..left.len - (n - i)]);
    joltage = joltage * 10 + left[maxIndex];
    left = left[maxIndex + 1..];
  }

  return joltage;
}

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput, allocator);
  defer input.deinit();
  
  var joltage: usize = 0;
  while (try input.next()) |bank| joltage += findMaxJoltage(bank, 2);
  return joltage;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput, allocator);
  defer input.deinit();

  var joltage: usize = 0;
  while (try input.next()) |bank| joltage += findMaxJoltage(bank, 12);
  return joltage;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 3,
  .parts = &.{
    .{ .run = &part1, .expected = 17445, .@"test" = .{ .input = TEST_INPUT, .expected = 357 } },
    .{ .run = &part2, .expected = 173229689350551, .@"test" = .{ .input = TEST_INPUT, .expected = 3121910778619 } }
  }
});
