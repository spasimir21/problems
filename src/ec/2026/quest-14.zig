const common = @import("common");
const std = @import("std");

const utils = common.utils;
const EC = common.EC;

const TEST_INPUTS = .{
  \\AAAEEEFFFF
  \\AADDDDDGFF
  \\BACDDIGGFF
  \\BABBIIIGGH
  \\BBBBIIIIHH
  ,
  \\IIIIIILOHHHHHHHHGGGGGQSRRRRKKK
  \\IIIIIILOOHHHHHHGGXGGGQSRRRRKKK
  \\PPPPILLLOOOODDHBGGGGGQSSRRRKKK
  \\PPZPLLLLFFOODDBBBBGGQQQSSRKKKK
  \\PPPPLLLLFFFONDDDBBMGGQQSSKKJJJ
  \\PPPCCCCCCFFONNDDMMMGQQQSSSKJJJ
  \\PCCCCCCCCFFNNDDDDMAAQQQSSSKKJJ
  \\PPCCECCCFFNNNNDADMAATQTTSSSJJJ
  \\PPEEEEECCFFNNAAAMMATTTTTSTSSSJ
  \\PPEEEEEEEFFNNNAAAAAATTTTTTSSJJ
  ,
  \\IIIIIILOHHHHHHHHGGGGGQSRRRRKKK
  \\IIIIIILOOHHHHHHGGXGGGQSRRRRKKK
  \\PPPPILLLOOOODDHBGGGGGQSSRRRKKK
  \\PPZPLLLLFFOODDBBBBGGQQQSSRKKKK
  \\PPPPLLLLFFFONDDDBBMGGQQSSKKJJJ
  \\PPPCCCCCCFFONNDDMMMGQQQSSSKJJJ
  \\PCCCCCCCCFFNNDDDDMAAQQQSSSKKJJ
  \\PPCCECCCFFNNNNDADMAATQTTSSSJJJ
  \\PPEEEEECCFFNNAAAMMATTTTTSTSSSJ
  \\PPEEEEEEEFFNNNAAAAAATTTTTTSSJJ
};

const Input = struct {
  grid: []const []const u8,

  arena: std.heap.ArenaAllocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var grid: std.ArrayList([]const u8) = .empty;
    defer grid.deinit(allocator);

    var arena: std.heap.ArenaAllocator = .init(allocator);

    var lineIt = std.mem.tokenizeAny(u8, source, "\r\n");
    while (lineIt.next()) |line| try grid.append(allocator, line);

    return .{
      .grid = try arena.allocator().dupe([]const u8, grid.items),
      .arena = arena
    };
  }

  pub fn deinit(self: *Input) void {
    self.arena.deinit();
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const grid = input.grid;

  const width = grid[0].len;
  const height = grid.len;

  var bindings: usize = width * 2 + height * 2;
  for (0..height) |y|
    for (0..width) |x| {
      if (x > 0 and grid[y][x] != grid[y][x - 1]) bindings += 1;
      if (y > 0 and grid[y][x] != grid[y - 1][x]) bindings += 1;
    };

  return bindings;
}

const Seam = struct {
  pieces: utils.OrderedPair(usize),
  size: usize,

  pub fn lessThan(ctx: void, a: Seam, b: Seam) bool {
    _ = ctx;
    return a.size < b.size;
  }
};

const FRAME = '\x00';

fn getPieces(grid: []const []const u8, allocator: std.mem.Allocator) ![]const u8 {
  var pieces: std.ArrayList(u8) = .empty;
  defer pieces.deinit(allocator);

  try pieces.append(allocator, FRAME);

  for (0..grid.len) |y|
    for (0..grid[y].len) |x|
      if (std.mem.findScalar(u8, pieces.items, grid[y][x]) == null)
        try pieces.append(allocator, grid[y][x]);

  return pieces.toOwnedSlice(allocator);
}

fn makePiecePair(a: u8, b: u8, pieces: []const u8) utils.OrderedPair(usize) {
  return .make(
    std.mem.indexOfScalar(u8, pieces, a).?,
    std.mem.indexOfScalar(u8, pieces, b).?
  );
}

fn getSeams(grid: []const []const u8, pieces: []const u8, allocator: std.mem.Allocator) ![]const Seam {
  var seamMap: std.AutoHashMap(utils.OrderedPair(usize), usize) = .init(allocator);
  defer seamMap.deinit();

  const width = grid[0].len;
  const height = grid.len;

  for (0..height) |y|
    for (0..width) |x| {
      if (x == 0 or grid[y][x] != grid[y][x - 1]) {
        const entry = try seamMap.getOrPutValue(makePiecePair(
          grid[y][x],
          if (x == 0) FRAME else grid[y][x - 1],
          pieces
        ), 0);

        entry.value_ptr.* += 1;
      }

      if (y == 0 or grid[y][x] != grid[y - 1][x]) {
        const entry = try seamMap.getOrPutValue(makePiecePair(
          grid[y][x],
          if (y == 0) FRAME else grid[y - 1][x],
          pieces
        ), 0);

        entry.value_ptr.* += 1;
      }

      if (x == width - 1) {
        const entry = try seamMap.getOrPutValue(makePiecePair(grid[y][x], FRAME, pieces), 0);
        entry.value_ptr.* += 1;
      }

      if (y == height - 1) {
        const entry = try seamMap.getOrPutValue(makePiecePair(grid[y][x], FRAME, pieces), 0);
        entry.value_ptr.* += 1;
      }
    };

  var list: std.ArrayList(Seam) = .empty;
  defer list.deinit(allocator);

  var it = seamMap.iterator();
  while (it.next()) |entry| try list.append(allocator, .{ .pieces = entry.key_ptr.*, .size = entry.value_ptr.* });

  std.mem.sort(Seam, list.items, {}, Seam.lessThan);
  return list.toOwnedSlice(allocator);
}

fn getMinimalBindings(pieces: []const u8, seams: []const Seam, dus: utils.DisjointUnionSet) usize {
  var connections: usize = 0;
  var bindings: usize = 0;
  for (seams) |seam| {
    if (!dus.join(seam.pieces.first, seam.pieces.second)) continue;

    connections += 1;
    bindings += seam.size;

    if (connections >= pieces.len - 1) break;
  }

  return bindings;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const pieces: []const u8 = try getPieces(input.grid, allocator);
  defer allocator.free(pieces);

  const seams: []const Seam = try getSeams(input.grid, pieces, allocator);
  defer allocator.free(seams);

  const dus: utils.DisjointUnionSet = try .init(pieces.len, allocator);
  defer dus.deinit();

  return getMinimalBindings(pieces, seams, dus);
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const pieces: []const u8 = try getPieces(input.grid, allocator);
  defer allocator.free(pieces);

  const seams: []const Seam = try getSeams(input.grid, pieces, allocator);
  defer allocator.free(seams);

  const dus: utils.DisjointUnionSet = try .init(pieces.len, allocator);
  defer dus.deinit();

  var minBindings: usize = std.math.maxInt(usize);
  for (0..pieces.len) |n| {
    if (pieces[n] == FRAME) continue;

    for (n + 1..pieces.len) |m| {
      if (pieces[m] == FRAME) continue;
      dus.reset();

      for (seams) |seam| {
        if (seam.pieces.has(n)) _ = dus.join(n, seam.pieces.other(n))
        else if (seam.pieces.has(m)) _ = dus.join(m, seam.pieces.other(m));
      }

      const bindings = getMinimalBindings(pieces, seams, dus);
      if (bindings < minBindings) minBindings = bindings;
    }
  }

  return minBindings;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 14,
  .parts = &.{
    .{ .run = &part1, .expected = 282, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 67 } },
    .{ .run = &part2, .expected = 505, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 63 } },
    .{ .run = &part3, .expected = 1872, .@"test" = .{ .input = TEST_INPUTS[2], .expected = 21 } }
  }
});
