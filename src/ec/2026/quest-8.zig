const EC = @import("common").EC;
const std = @import("std");

const TEST_INPUT =
  \\....1.9.6.1.7....
  \\...9.2.3.3.8.1...
  \\..7.8.3.5.1.4.3..
  \\.4.6.7.4.1.1.8.9.
  \\4.5.3.6.5.8.9.4.9
  \\.9.5.1.5.6.2.8.9.
  \\..7.7.6.4.6.2.4..
  \\...9.3.8.3.8.4...
  \\....1.6.6.2.8....
  ;

const Input = struct {
  grid: []const []i8,

  arena: std.heap.ArenaAllocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var grid: std.ArrayList([]i8) = .empty;
    defer grid.deinit(allocator);

    var arena: std.heap.ArenaAllocator = .init(allocator);

    var lineIt = std.mem.tokenizeAny(u8, source, "\r\n");
    while (lineIt.next()) |line| {
      const row = try arena.allocator().alloc(i8, line.len);
      for (0..row.len) |i| row[i] = if (line[i] == '.') 0 else @intCast(line[i] - '0');
      try grid.append(allocator, row);
    }

    return .{
      .grid = try arena.allocator().dupe([]i8, grid.items),
      .arena = arena
    };
  }

  pub fn deinit(self: Input) void {
    self.arena.deinit();
  }
};

const Point = struct {
  x: isize,
  y: isize,

  pub fn add(self: Point, other: Point) Point {
    return .{ .x = self.x + other.x, .y = self.y + other.y };
  }

  pub fn mul(self: Point, factor: isize) Point {
    return .{ .x = self.x * factor, .y = self.y * factor };
  }

  pub fn sample(self: Point, comptime T: type, grid: []const []const T) ?T {
    if (
      self.x < 0 or self.y < 0 or
      self.y >= grid.len or self.x >= grid[0].len
    )
      return null;

    return grid[@intCast(self.y)][@intCast(self.x)];
  }

  pub fn get(self: Point, comptime T: type, grid: []const []T) *T {
    return &grid[@intCast(self.y)][@intCast(self.x)];
  }
};

fn countVisibleFromPoint(start: Point, _direction: Point, grid: []const []const i8) usize {
  var direction = _direction;
  var visible: usize = 0;

  var height: u8 = 0;
  var point = start;
  while (point.sample(i8, grid)) |h| : (point = point.add(direction)) {
    if (visible == 0 and h != 0 and (direction.x == 0 or direction.y == 0)) direction = direction.mul(2);

    if (h <= height) {
      height -|= 1;
      continue;
    }

    height = @intCast(h - 1);
    visible += 1;
  }

  return visible;
}

fn countVisibleFromDirection(direction: Point, grid: []const []const i8) usize {
  var visible: usize = 0;

  const height = grid.len;
  if (height == 0) return 0;
  const width = grid[0].len;

  for (0..width + 2) |i| {
    const x: isize = @as(isize, @intCast(i)) - 1;
    visible += countVisibleFromPoint(direction.add(.{ .x = x, .y = -1 }), direction, grid);
    visible += countVisibleFromPoint(direction.add(.{ .x = x, .y = @intCast(height) }), direction, grid);
  }

  for (0..height) |i| {
    const y: isize = @intCast(i);
    visible += countVisibleFromPoint(direction.add(.{ .x = -1, .y = y }), direction, grid);
    visible += countVisibleFromPoint(direction.add(.{ .x = @intCast(width), .y = y }), direction, grid);
  }

  return visible;
}

const DIRECTIONS = [_]Point {
  .{ .x = 1, .y = 1 },
  .{ .x = -1, .y = 1 },
  .{ .x = -1, .y = 0 },
  .{ .x = -1, .y = -1 },
  .{ .x = 1, .y = -1 },
  .{ .x = 1, .y = 0 }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  return countVisibleFromDirection(DIRECTIONS[0], input.grid);
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var total: usize = 0;
  for (DIRECTIONS) |direction| total += countVisibleFromDirection(direction, input.grid);
  return total;
}

fn beamFromPoint(start: Point, _direction: Point, grid: []const []i8, grown: *usize) usize {
  var direction = _direction;
  var visible: usize = 0;

  var height: u8 = 0;
  var point = start;
  while (point.sample(i8, grid)) |h| : (point = point.add(direction)) {
    if (visible == 0 and h > 0 and (direction.x == 0 or direction.y == 0)) direction = direction.mul(2);

    if (h <= height) {
      height -|= 1;

      if (h < 0) {
        if (h == -1) point.get(i8, grid).* = 1
        else point.get(i8, grid).* += 1;
      }

      continue;
    }

    height = @intCast(h - 1);
    visible += 1;

    if (h == 9) {
      point.get(i8, grid).* = -3;
      grown.* += 1;
    } else point.get(i8, grid).* += 1;
  }

  return visible;
}

fn beamFromDirection(direction: Point, grid: []const []i8, grown: *usize) usize {
  var visible: usize = 0;

  const height = grid.len;
  if (height == 0) return 0;
  const width = grid[0].len;

  for (0..width + 2) |i| {
    const x: isize = @as(isize, @intCast(i)) - 1;
    visible += beamFromPoint(direction.add(.{ .x = x, .y = -1 }), direction, grid, grown);
    visible += beamFromPoint(direction.add(.{ .x = x, .y = @intCast(height) }), direction, grid, grown);
  }

  for (0..height) |i| {
    const y: isize = @intCast(i);
    visible += beamFromPoint(direction.add(.{ .x = -1, .y = y }), direction, grid, grown);
    visible += beamFromPoint(direction.add(.{ .x = @intCast(width), .y = y }), direction, grid, grown);
  }

  return visible;
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var total: usize = 0;
  var grown: usize = 0;
  var round: usize = 0;
  while (grown < 100_000) : (round += 1)
    total += beamFromDirection(DIRECTIONS[round % DIRECTIONS.len], input.grid, &grown);

  return total;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 8,
  .parts = &.{
    .{ .run = &part1, .expected = 185, .@"test" = .{ .input = TEST_INPUT, .expected = 32 } },
    .{ .run = &part2, .expected = 1040, .@"test" = .{ .input = TEST_INPUT, .expected = 187 } },
    .{ .run = &part3, .expected = 899321, .@"test" = .{ .input = TEST_INPUT, .expected = 899889 } }
  }
});
