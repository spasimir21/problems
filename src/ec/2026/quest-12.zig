const common = @import("common");
const std = @import("std");

const utils = common.utils;
const EC = common.EC;

const TEST_INPUTS = .{
  \\........#.
  \\.##.......
  \\.##..####.
  \\.##..####.
  \\.....####.
  \\.###......
  ,
  \\...............................
  \\.####....#####..#######........
  \\.####....#####..#######........
  \\.####....#####..#######........
  \\.........#####.......##........
  \\.........########....##........
  \\.........########....##........
  \\...............................
  \\.######....#.....#.....###.....
  \\...........#...........###.....
  \\...........#......########.....
  \\...........#......########.....
  \\...........#......########.....
  \\..................########.....
  \\...............................
  ,
  \\..............................
  \\.##########....##.....#######.
  \\.##########.##.##..#..#######.
  \\.####..####.##.##.....#.#####.
  \\.##########.##.#####..#.#####.
  \\.##########.##........#######.
  \\..............................
  \\.##########..################.
  \\.##########..#..............#.
  \\.#######..#..#..............#.
  \\.#######..#..################.
  \\.##########..################.
  \\..............................
};

const Input = struct {
  grid: []const []const bool,

  arena: std.heap.ArenaAllocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var grid: std.ArrayList([]const bool) = .empty;
    defer grid.deinit(allocator);

    var arena: std.heap.ArenaAllocator = .init(allocator);

    var lineIt = std.mem.tokenizeAny(u8, source, "\r\n");
    while (lineIt.next()) |line| {
      const row = try arena.allocator().alloc(bool, line.len);
      for (0..line.len) |i| row[i] = line[i] == '#';
      try grid.append(allocator, row);
    }

    return .{
      .grid = try arena.allocator().dupe([]const bool, grid.items),
      .arena = arena
    };
  }

  pub fn deinit(self: *Input) void {
    self.arena.deinit();
  }
};

const Spell = struct {
  x1: usize,
  x2: usize,
  y1: usize,
  y2: usize
};

const Edge = [2]?usize;

fn kuhn(i: usize, spells: []const Spell, edges: utils.Matrix(Edge), used: []bool, matched: []?usize) bool {
  if (used[i]) return false;
  used[i] = true;

  for (spells[i].x1..spells[i].x2 + 1) |x|
    for (spells[i].y1..spells[i].y2 + 1) |y| {
      const j = edges.get(x, y)[1].?;

      if (matched[j] == null or kuhn(matched[j].?, spells, edges, used, matched)) {
        matched[j] = i;
        return true;
      }
    };

  return false;
}

fn solve(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const grid = input.grid;

  const width = grid[0].len;
  const height = grid.len;

  const edges: utils.Matrix(Edge) = try .init(width, height, @splat(null), allocator);
  defer edges.deinit(allocator);

  var spells: std.ArrayList(Spell) = .empty;
  defer spells.deinit(allocator);

  for (0..height) |y|
    for (0..width) |x| {
      if (!grid[y][x]) continue;

      if (x == 0 or !grid[y][x - 1]) try spells.append(allocator, .{ .x1 = x, .x2 = x, .y1 = y, .y2 = y });
      if (x == width - 1 or !grid[y][x + 1]) spells.items[spells.items.len - 1].x2 = x;

      edges.at(x, y)[0] = spells.items.len - 1;
    };

  const nHorizontalSpells = spells.items.len;

  for (0..width) |x|
    for (0..height) |y| {
      if (!grid[y][x]) continue;

      if (y == 0 or !grid[y - 1][x]) try spells.append(allocator, .{ .x1 = x, .x2 = x, .y1 = y, .y2 = y });
      if (y == height - 1 or !grid[y + 1][x]) spells.items[spells.items.len - 1].y2 = y;

      edges.at(x, y)[1] = spells.items.len - 1;
    };

  const used = try allocator.alloc(bool, nHorizontalSpells);
  defer allocator.free(used);

  const matched = try allocator.alloc(?usize, spells.items.len);
  defer allocator.free(matched);

  var count: usize = 0;

  @memset(matched, null);
  for (0..nHorizontalSpells) |i| {
    @memset(used, false);
    if (kuhn(i, spells.items, edges, used, matched)) count += 1;
  }

  return count;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 12,
  .parts = &.{
    .{ .run = &solve, .expected = 211, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 7 } },
    .{ .run = &solve, .expected = 2028, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 23 } },
    .{ .run = &solve, .expected = 2803, .@"test" = .{ .input = TEST_INPUTS[2], .expected = 29 } }
  }
});
