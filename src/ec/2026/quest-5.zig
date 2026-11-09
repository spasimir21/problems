const EC = @import("common").EC;
const std = @import("std");

const TEST_INPUT =
  \\010100100100001101000
  \\111101001000001110000
  \\101111011000101010011
  \\001000101010000100000
  \\000110100110011001100
  \\000001110111111000000
  \\101100010101011110000
  \\001101100000001010011
  \\001001001111010001001
  \\100011011110011010101
  \\001100101110010010000
  ;

const Cell = enum {
  Light,
  Dark,
  Land,
  Water,
  Sand,
  Tree
};

const Input = struct {
  grid: []const []Cell,
  arena: std.heap.ArenaAllocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var rows: std.ArrayList([]Cell) = .empty;
    defer rows.deinit(allocator);

    var arena: std.heap.ArenaAllocator = .init(allocator);

    var it = std.mem.tokenizeAny(u8, source, "\r\n");
    while (it.next()) |line| {
      const row = try arena.allocator().alloc(Cell, line.len);
      for (0..row.len) |i| row[i] = if (line[i] == '0') .Light else .Dark;
      try rows.append(allocator, row);
    }

    return .{
      .grid = try arena.allocator().dupe([]Cell, rows.items),
      .arena = arena
    };
  }

  pub fn deinit(self: *Input) void {
    self.arena.deinit();
  }
};

const CellCount = struct {
  dark: usize = 0,
  land: usize = 0,
  light: usize = 0,
  water: usize = 0,
  sand: usize = 0,
  tree: usize = 0,
  void: usize = 0,

  pub fn add(self: *CellCount, cell: Cell) void {
    switch (cell) {
      .Light => self.light += 1,
      .Dark => self.dark += 1,
      .Land => self.land += 1,
      .Water => self.water += 1,
      .Sand => self.sand += 1,
      .Tree => self.tree += 1
    }
  }

  pub fn addVoid(self: *CellCount, n: usize) void {
    self.void += n;
  }
};

fn countNeighbours(grid: []const []const Cell, x: usize, y: usize) CellCount {
  const width = grid[0].len;
  const height = grid.len;
  
  var neighbours: CellCount = .{};

  if (y > 0) {
    if (x > 0) neighbours.add(grid[y - 1][x - 1]) else neighbours.addVoid(1);
    neighbours.add(grid[y - 1][x]);
    if (x < width - 1) neighbours.add(grid[y - 1][x + 1]) else neighbours.addVoid(1);
  } else neighbours.addVoid(3);

  if (x > 0) neighbours.add(grid[y][x - 1]) else neighbours.addVoid(1);
  if (x < width - 1) neighbours.add(grid[y][x + 1]) else neighbours.addVoid(1);

  if (y < height - 1) {
    if (x > 0) neighbours.add(grid[y + 1][x - 1]) else neighbours.addVoid(1);
    neighbours.add(grid[y + 1][x]);
    if (x < width - 1) neighbours.add(grid[y + 1][x + 1]) else neighbours.addVoid(1);
  } else neighbours.addVoid(3);

  return neighbours;
}

const MAX_UPDATES = 100_000;

fn evolveLand(
  grid: []const []Cell,
  comptime getUpdate: fn (grid: []const []const Cell, x: usize, y: usize) ?Cell,
  maxSteps: ?usize
) void {
  var updates: [MAX_UPDATES]struct { x: usize, y: usize, newCell: Cell } = undefined;
  var nUpdates: usize = 0;

  for (0..maxSteps orelse std.math.maxInt(usize)) |_| {
    nUpdates = 0;

    for (0..grid.len) |y|
      for (0..grid[0].len) |x|
        if (getUpdate(grid, x, y)) |newCell| {
          updates[nUpdates] = .{ .x = x, .y = y, .newCell = newCell };
          nUpdates += 1;
        };

    if (nUpdates == 0) break;

    for (updates[0..nUpdates]) |update| grid[update.y][update.x] = update.newCell;
  }
}

fn countAll(grid: []const []const Cell) CellCount {
  var count: CellCount = .{};
  for (0..grid.len) |y| for (0..grid[0].len) |x| count.add(grid[y][x]);
  return count;
}

fn display(grid: []const []const Cell) void {
  var buffer: [4 * 1024]u8 = undefined;
  const stderr = std.debug.lockStderr(&buffer);
  defer std.debug.unlockStderr();

  const writer = &stderr.file_writer.interface;

  for (0..grid.len) |y| {
    for (0..grid[0].len) |x|
      writer.writeAll(switch (grid[y][x]) {
        .Land => "\x1b[32m#\x1b[0m",
        .Water => "\x1b[34m.\x1b[0m",
        .Sand => "\x1b[33m=\x1b[0m",
        .Tree => "\x1b[38;5;130m@\x1b[0m",
        .Light => " ",
        .Dark => "#"
      }) catch {};

    writer.writeByte('\n') catch {};
  }
}

fn shouldBecomeLand(grid: []const []const Cell, x: usize, y: usize) ?Cell {
  if (grid[y][x] == .Land) return null;

  const neighbours = countNeighbours(grid, x, y);
  return if (neighbours.land >= 1 and (neighbours.land + neighbours.dark) >= 5) .Land else null;
}

fn unchartedToWater(grid: []const []const Cell, x: usize, y: usize) ?Cell {
  const cell = grid[y][x];
  return if (cell == .Light or cell == .Dark) .Water else null;
}

fn growLand(grid: []const []Cell) void {
  grid[grid.len / 2][grid[0].len / 2] = .Land;
  evolveLand(grid, shouldBecomeLand, null);
  evolveLand(grid, unchartedToWater, null);
}

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  growLand(input.grid);

  // display(input.grid);

  return countAll(input.grid).land;
}

fn shouldBecomeSand(grid: []const []const Cell, x: usize, y: usize) ?Cell {
  if (grid[y][x] != .Land) return null;

  const neighbours = countNeighbours(grid, x, y);
  return if ((neighbours.water + neighbours.void) >= 1 or neighbours.sand >= 5) .Sand else null;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  growLand(input.grid);
  evolveLand(input.grid, shouldBecomeSand, null);

  // display(input.grid);

  return countAll(input.grid).sand;
}

fn shouldBecomeTreeFirstPhase(grid: []const []const Cell, x: usize, y: usize) ?Cell {
  if (
    grid[y][x] != .Land or
    x < 2 or
    y < 2 or
    x >= grid[0].len - 2 or
    y >= grid.len - 2
  )
    return null;

  for (0..5) |dxi|
    for (0..5) |dyi| {
      const dx = @as(isize, @intCast(dxi)) - 2;
      const dy = @as(isize, @intCast(dyi)) - 2;
      if (
        (dx == 0 and dy == 0) or
        ((dx == -2 or dx == 2) and (dy == -2 or dy == 2))
      ) continue;
      
      const cell = grid[@intCast(@as(isize, @intCast(y)) + dy)][@intCast(@as(isize, @intCast(x)) + dx)];
      if (cell != .Land and cell != .Tree) return null;
    };

  return .Tree;
}

fn shouldBecomeTreeSecondPhase(grid: []const []const Cell, x: usize, y: usize) ?Cell {
  if (grid[y][x] != .Land) return null;

  const neighbours = countNeighbours(grid, x, y);
  return if (neighbours.sand == 0 and neighbours.tree >= 4) .Tree else null;
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  // display(input.grid);

  growLand(input.grid);
  evolveLand(input.grid, shouldBecomeSand, null);

  evolveLand(input.grid, shouldBecomeTreeFirstPhase, null);
  evolveLand(input.grid, shouldBecomeTreeSecondPhase, 2);

  // display(input.grid);

  return countAll(input.grid).tree;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 5,
  .parts = &.{
    .{ .run = &part1, .expected = 1100, .@"test" = .{ .input = TEST_INPUT, .expected = 137 } },
    .{ .run = &part2, .expected = 1412, .@"test" = .{ .input = TEST_INPUT, .expected = 69 } },
    .{ .run = &part3, .expected = 9755, .@"test" = .{ .input = TEST_INPUT, .expected = 14 } }
  }
});
