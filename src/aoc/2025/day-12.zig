const AOC = @import("common").AOC;
const std = @import("std");

const PRESENT_SIZE = 3;
const PRESENT_COUNT = 6;

const Present = [PRESENT_SIZE][PRESENT_SIZE]bool;

const Board = struct {
  width: usize = 0,
  height: usize = 0,
  presentCounts: [PRESENT_COUNT]usize = @splat(0)
};

pub const Input = struct {
  presents: [PRESENT_COUNT]Present,
  iter: std.mem.SplitIterator(u8, .sequence),

  pub fn init(source: []const u8) Input {
    const lineBreak = if (std.mem.findScalar(u8, source, '\r')) |_| "\r\n" else "\n";

    var self: Input = .{
      .presents = undefined,
      .iter = std.mem.splitSequence(u8, source, lineBreak)
    };

    for (0..PRESENT_COUNT) |i| {
      _ = self.iter.next();
      for (0..PRESENT_SIZE) |y| {
        const line = self.iter.next().?;
        for (0..PRESENT_SIZE) |x| {
          self.presents[i][y][x] = line[x] == '#';
        }
      }
      _ = self.iter.next();
    }

    return self;
  }

  pub fn next(self: *Input) !?Board {
    const line = self.iter.next() orelse return null;
    var board: Board = .{};

    var it = std.mem.splitScalar(u8, line, ' ');

    const size = it.next().?;
    const xIndex = std.mem.findScalar(u8, size, 'x').?;
    board.width = try std.fmt.parseUnsigned(usize, size[0..xIndex], 10);
    board.height = try std.fmt.parseUnsigned(usize, size[xIndex + 1..size.len - 1], 10);

    for (0..PRESENT_COUNT) |i| board.presentCounts[i] = try std.fmt.parseUnsigned(usize, it.next().?, 10);

    return board;
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;
  
  var input: Input = .init(rawInput);
  
  var presentAreas: [PRESENT_COUNT]usize = @splat(0);
  for (0..PRESENT_COUNT) |i|
    presentAreas[i] = std.mem.countScalar(bool, @ptrCast(&input.presents[i]), true);

  var valid: usize = 0;
  while (try input.next()) |board| {
    var totalPresentCount: usize = 0;
    var totalPresentArea: usize = 0;

    for (board.presentCounts, 0..PRESENT_COUNT) |count, i| {
      totalPresentArea += count * presentAreas[i];
      totalPresentCount += count;
    }

    if (board.width * board.height < totalPresentArea) continue;

    if ((board.width / 3) * (board.height / 3) >= totalPresentCount) {
      valid += 1;
      continue;
    }

    std.debug.panic("Ambigious board, sophisticated check not yet implemented (and apparently not needed)!\n", .{});
  }

  return valid;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 12,
  .parts = &.{
    .{ .run = &part1, .expected = 526 }
  }
});
