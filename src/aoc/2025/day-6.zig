const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\123 328  51 64 
  \\ 45 64  387 23 
  \\  6 98  215 314
  \\*   +   *   +  
  ;

pub const Operation = enum { Add, Multiply };

pub const Problem = struct {
  operation: Operation,
  startColumn: usize,
  width: usize
};

pub const Input = struct {
  allocator: std.mem.Allocator,
  lines: []const []const u8,

  lastLine: []const u8,
  column: usize = 0,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var lines: std.ArrayList([]const u8) = .empty;
    defer lines.deinit(allocator);

    var it = std.mem.tokenizeAny(u8, source, "\r\n");
    var lastLine: []const u8 = source;
    while (it.next()) |line| {
      if (line[0] == '+' or line[0] == '*') {
        lastLine = line;
        break;
      }

      try lines.append(allocator, line);
    }

    return .{
      .allocator = allocator,
      .lines = try lines.toOwnedSlice(allocator),
      .lastLine = lastLine
    };
  }

  pub fn deinit(self: *Input) void {
    self.allocator.free(self.lines);
  }

  pub fn next(self: *Input) !?Problem {
    if (self.column >= self.lastLine.len) return null;
    const startColumn = self.column;

    const operation: Operation = switch (self.lastLine[self.column]) {
      '+' => .Add,
      '*' => .Multiply,
      else => return error.InvalidInput
    };
    self.column += 1;

    while (
      self.column < self.lastLine.len and
      self.lastLine[self.column] == ' '
    ) self.column += 1;

    return .{
      .operation = operation,
      .startColumn = startColumn,
      .width = self.column - startColumn - @as(usize, if (self.column < self.lastLine.len) 1 else 0)
    };
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var total: usize = 0;

  while (try input.next()) |problem| {
    var result: usize = switch (problem.operation) {
      .Add => 0,
      .Multiply => 1
    };

    for (input.lines) |line| {
      const value = try std.fmt.parseUnsigned(usize, std.mem.trim(u8, line[problem.startColumn..problem.startColumn + problem.width], " "), 10);
      switch (problem.operation) {
        .Add => result += value,
        .Multiply => result *= value
      }
    }

    total += result;
  }

  return total;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var total: usize = 0;

  while (try input.next()) |problem| {
    var result: usize = switch (problem.operation) {
      .Add => 0,
      .Multiply => 1
    };

    for (problem.startColumn..problem.startColumn + problem.width) |column| {
      var value: usize = 0;

      for (input.lines) |line| {
        if (line[column] == ' ') continue;
        value = value * 10 + (line[column] - '0');
      } 

      switch (problem.operation) {
        .Add => result += value,
        .Multiply => result *= value
      }
    }

    total += result;
  }

  return total;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 6,
  .parts = &.{
    .{ .run = &part1, .expected = 5524274308182, .@"test" = .{ .input = TEST_INPUT, .expected = 4277556 } },
    .{ .run = &part2, .expected = 8843673199391, .@"test" = .{ .input = TEST_INPUT, .expected = 3263827 } }
  }
});
