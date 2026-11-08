const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\
  ;

const Input = struct {
  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    _ = source;
    _ = allocator;
    return .{};
  }

  pub fn deinit(self: Input) void {
    _ = self;
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  return 0;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();
  
  return 0;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = _,
  .parts = &.{
    .{ .run = &part1, .expected = null, .@"test" = .{ .input = TEST_INPUT, .expected = 3 } },
    .{ .run = &part2, .expected = null, .@"test" = .{ .input = TEST_INPUT, .expected = 6 } }
  }
});
