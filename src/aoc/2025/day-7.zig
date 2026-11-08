const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\.......S.......
  \\...............
  \\.......^.......
  \\...............
  \\......^.^......
  \\...............
  \\.....^.^.^.....
  \\...............
  \\....^.^...^....
  \\...............
  \\...^.^...^.^...
  \\...............
  \\..^...^.....^..
  \\...............
  \\.^.^.^.^.^...^.
  \\...............
  ;

pub const Input = struct {
  positions: std.ArrayList(usize) = .empty,
  startColumn: usize,

  iter: std.mem.TokenIterator(u8, .any),
  allocator: std.mem.Allocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) Input {
    var iter = std.mem.tokenizeAny(u8, source, "\r\n");
    const startColumn = std.mem.indexOfScalar(u8, iter.next().?, 'S').?;
    return .{ .startColumn = startColumn, .iter = iter, .allocator = allocator };
  }

  pub fn deinit(self: *Input) void {
    self.positions.deinit(self.allocator);
  }

  pub fn next(self: *Input) !?[]const usize {
    const line = self.iter.next() orelse return null;
    self.positions.clearRetainingCapacity();

    for (0..line.len) |i|
      if (line[i] == '^')
        try self.positions.append(self.allocator, i);

    return self.positions.items;
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput, allocator);
  defer input.deinit();

  var beams: std.AutoHashMap(usize, void) = .init(allocator);
  defer beams.deinit();

  var nextBeams: std.AutoHashMap(usize, void) = .init(allocator);
  defer nextBeams.deinit();

  var splits: usize = 0;

  try beams.put(input.startColumn, {});
  while (try input.next()) |splitters| {
    var it = beams.keyIterator();
    while (it.next()) |beam| {
      if (std.mem.findScalar(usize, splitters, beam.*)) |_| {
        try nextBeams.put(beam.* - 1, {});
        try nextBeams.put(beam.* + 1, {});
        splits += 1;
        continue;
      }

      try nextBeams.put(beam.*, {});
    }

    const temp = beams;
    beams = nextBeams;
    nextBeams = temp;

    nextBeams.clearRetainingCapacity();
  }

  return splits;
}

fn putCombineTimelines(beams: *std.AutoHashMap(usize, usize), beam: usize, timelines: usize) !void {
  const entry = try beams.getOrPut(beam);
  if (entry.found_existing) entry.value_ptr.* += timelines
  else entry.value_ptr.* = timelines;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput, allocator);
  defer input.deinit();

  var beams: std.AutoHashMap(usize, usize) = .init(allocator);
  defer beams.deinit();

  var nextBeams: std.AutoHashMap(usize, usize) = .init(allocator);
  defer nextBeams.deinit();

  try beams.put(input.startColumn, 1);
  while (try input.next()) |splitters| {
    var it = beams.iterator();
    while (it.next()) |entry| {
      const timelines = entry.value_ptr.*;
      const beam = entry.key_ptr.*;

      if (std.mem.findScalar(usize, splitters, beam)) |_| {
        try putCombineTimelines(&nextBeams, beam - 1, timelines);
        try putCombineTimelines(&nextBeams, beam + 1, timelines);
        continue;
      }

      try putCombineTimelines(&nextBeams, beam, timelines);
    }

    const temp = beams;
    beams = nextBeams;
    nextBeams = temp;

    nextBeams.clearRetainingCapacity();
  }

  var timelines: usize = 0;
  var it = beams.valueIterator();
  while (it.next()) |beamTimelines| timelines += beamTimelines.*;
  return timelines;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 7,
  .parts = &.{
    .{ .run = &part1, .expected = 1546, .@"test" = .{ .input = TEST_INPUT, .expected = 21 } },
    .{ .run = &part2, .expected = 13883459503480, .@"test" = .{ .input = TEST_INPUT, .expected = 40 } }
  }
});
