const EC = @import("common").EC;
const std = @import("std");

const TEST_INPUTS = .{
  \\
  ,
  \\
  ,
  \\
};

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

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  return 0;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = _,
  .parts = &.{
    .{ .run = &part1, .expected = null, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 0 } },
    .{ .run = &part2, .expected = null, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 0 } },
    .{ .run = &part3, .expected = null, .@"test" = .{ .input = TEST_INPUTS[2], .expected = 0 } }
  }
});
