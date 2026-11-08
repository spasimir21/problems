const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\3-5
  \\10-14
  \\16-20
  \\12-18
  \\
  \\1
  \\5
  \\8
  \\11
  \\17
  \\32
  ;

const Range = struct { min: usize, max: usize };

pub const Input = struct {
  allocator: std.mem.Allocator,
  ranges: []const Range,

  iter: std.mem.SplitIterator(u8, .sequence),

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var ranges: std.ArrayList(Range) = .empty;
    defer ranges.deinit(allocator);

    const lineBreak = if (std.mem.findScalar(u8, source, '\r')) |_| "\r\n" else "\n";
    var iter = std.mem.splitSequence(u8, source, lineBreak);
    while (iter.next()) |line| {
      if (line.len == 0) break;

      const dashIndex = std.mem.indexOfScalar(u8, line, '-') orelse return error.InvalidInput;

      try ranges.append(allocator, .{
        .min = try std.fmt.parseUnsigned(usize, line[0..dashIndex], 10),
        .max = try std.fmt.parseUnsigned(usize, line[dashIndex + 1..], 10)
      });
    }

    return .{
      .allocator = allocator,
      .ranges = try ranges.toOwnedSlice(allocator),
      .iter = iter
    };
  }

  pub fn deinit(self: *Input) void {
    self.allocator.free(self.ranges);
  }

  pub fn nextID(self: *Input) !?usize {
    const line = self.iter.next() orelse return null;
    return try std.fmt.parseUnsigned(usize, line, 10);
  }
};

fn buildOptimizedRanges(ranges: []const Range, allocator: std.mem.Allocator) ![]const Range {
  var optimizedRanges: std.ArrayList(Range) = .empty;
  defer optimizedRanges.deinit(allocator);

  for (ranges) |range| {
    if (optimizedRanges.items.len == 0 or range.min > optimizedRanges.getLast().max) {
      try optimizedRanges.append(allocator, range);
      continue;
    }

    for (0..optimizedRanges.items.len) |i| {
      const optimizedRange = &optimizedRanges.items[i];

      if (range.max < optimizedRange.min) {
        try optimizedRanges.insert(allocator, i, range);
        break;
      }

      if (range.min <= optimizedRange.max) {
        optimizedRange.* = .{
          .min = @min(range.min, optimizedRange.min),
          .max = @max(range.max, optimizedRange.max)
        };

        if (i < optimizedRanges.items.len - 1) {
          const nextRange = &optimizedRanges.items[i + 1];

          if (optimizedRange.max >= nextRange.min) {
            nextRange.* = .{
              .min = @min(optimizedRange.min, nextRange.min),
              .max = @max(optimizedRange.max, nextRange.max)
            };

            _ = optimizedRanges.orderedRemove(i);
          }
        }

        break;
      }
    }
  }

  return try optimizedRanges.toOwnedSlice(allocator);
}

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const optimizedRanges = try buildOptimizedRanges(input.ranges, allocator);
  defer allocator.free(optimizedRanges);

  var fresh: usize = 0;

  while (try input.nextID()) |id|
    for (optimizedRanges) |range| {
      if (id > range.max) continue;
      if (id >= range.min) fresh += 1;
      break;
    };

  return fresh;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const optimizedRanges = try buildOptimizedRanges(input.ranges, allocator);
  defer allocator.free(optimizedRanges);

  var fresh: usize = 0;
  for (optimizedRanges) |range| fresh += range.max - range.min + 1;
  return fresh;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 5,
  .parts = &.{
    .{ .run = &part1, .expected = 567, .@"test" = .{ .input = TEST_INPUT, .expected = 3 } },
    .{ .run = &part2, .expected = 354149806372909, .@"test" = .{ .input = TEST_INPUT, .expected = 14 } }
  }
});
