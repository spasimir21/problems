const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\..@@.@@@@.
  \\@@@.@.@.@@
  \\@@@@@.@.@@
  \\@.@@@@..@.
  \\@@.@@@@.@@
  \\.@@@@@@@.@
  \\.@.@.@.@@@
  \\@.@@@.@@@@
  \\.@@@@@@@@.
  \\@.@.@@@.@.
  ;

pub const Input = struct {
  allocator: std.mem.Allocator,
  grid: []const []bool,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var rows: std.ArrayList([]bool) = .empty;
    defer rows.deinit(allocator);

    var it = std.mem.tokenizeAny(u8, source, "\r\n");
    while (it.next()) |line| {
      const row = try allocator.alloc(bool, line.len);
      for (0..row.len) |i| row[i] = line[i] == '@';
      try rows.append(allocator, row);
    }

    return .{ .allocator = allocator, .grid = try rows.toOwnedSlice(allocator) };
  }

  pub fn deinit(self: *Input) void {
    for (self.grid) |row| self.allocator.free(row);
    self.allocator.free(self.grid);
  }
};

fn countNeighbours(grid: []const []const bool, x: usize, y: usize) usize {
  const width = grid[0].len;
  const height = grid.len;
  
  var neighbours: usize = 0;

  if (y > 0) {
    if (x > 0 and grid[y - 1][x - 1]) neighbours += 1;
    if (grid[y - 1][x]) neighbours += 1;
    if (x < width - 1 and grid[y - 1][x + 1]) neighbours += 1;
  }

  if (x > 0 and grid[y][x - 1]) neighbours += 1;
  if (x < width - 1 and grid[y][x + 1]) neighbours += 1;

  if (y < height - 1) {
    if (x > 0 and grid[y + 1][x - 1]) neighbours += 1;
    if (grid[y + 1][x]) neighbours += 1;
    if (x < width - 1 and grid[y + 1][x + 1]) neighbours += 1;
  }

  return neighbours;
}

fn display(grid: []const []const bool) void {
  for (grid) |row| {
    for (row) |roll| std.debug.print("{c}", (struct { u8 }) { if (roll) '@' else '.' });
    std.debug.print("\n", .{});
  }
}

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var accessible: usize = 0;

  for (0..input.grid.len) |y|
    for (0..input.grid[y].len) |x|
      if (input.grid[y][x] and countNeighbours(input.grid, x, y) < 4) {
        accessible += 1;
      };

  return accessible;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var toBeRemoved: std.ArrayList(struct { x: usize, y: usize }) = .empty;
  defer toBeRemoved.deinit(allocator);

  var removed: usize = 0;

  while (true) {
    toBeRemoved.clearRetainingCapacity();

    for (0..input.grid.len) |y|
      for (0..input.grid[y].len) |x|
        if (input.grid[y][x] and countNeighbours(input.grid, x, y) < 4)
          try toBeRemoved.append(allocator, .{ .x = x, .y = y });

    if (toBeRemoved.items.len == 0) break;
    removed += toBeRemoved.items.len;

    for (toBeRemoved.items) |roll| input.grid[roll.y][roll.x] = false;
  }

  return removed;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 4,
  .parts = &.{
    .{ .run = &part1, .expected = 1491, .@"test" = .{ .input = TEST_INPUT, .expected = 13 } },
    .{ .run = &part2, .expected = 8722, .@"test" = .{ .input = TEST_INPUT, .expected = 43 } }
  }
});
