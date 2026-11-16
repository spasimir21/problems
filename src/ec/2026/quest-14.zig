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
  pieces: utils.OrderedPair(u8),
  size: usize,

  pub fn lessThan(ctx: void, a: Seam, b: Seam) bool {
    _ = ctx;
    return a.size < b.size;
  }
};

const FRAME = std.math.maxInt(u8);

fn getSeams(grid: []const []const u8, allocator: std.mem.Allocator) ![]const Seam {
  var seamMap: std.AutoHashMap(utils.OrderedPair(u8), usize) = .init(allocator);
  defer seamMap.deinit();

  const width = grid[0].len;
  const height = grid.len;

  for (0..height) |y|
    for (0..width) |x| {
      if (x == 0 or grid[y][x] != grid[y][x - 1]) {
        const entry = try seamMap.getOrPutValue(.make(
          grid[y][x],
          if (x == 0) FRAME else grid[y][x - 1]
        ), 0);

        entry.value_ptr.* += 1;
      }

      if (y == 0 or grid[y][x] != grid[y - 1][x]) {
        const entry = try seamMap.getOrPutValue(.make(
          grid[y][x],
          if (y == 0) FRAME else grid[y - 1][x]
        ), 0);

        entry.value_ptr.* += 1;
      }

      if (x == width - 1) {
        const entry = try seamMap.getOrPutValue(.make(grid[y][x], FRAME), 0);
        entry.value_ptr.* += 1;
      }

      if (y == height - 1) {
        const entry = try seamMap.getOrPutValue(.make(grid[y][x], FRAME), 0);
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

fn doJoin(a: u8, b: u8, setOf: *std.AutoHashMap(u8, usize)) bool {
  const setA = setOf.get(a).?;
  const setB = setOf.get(b).?;
  if (setA == setB) return false;

  var it = setOf.iterator();
  while (it.next()) |entry| {
    if (entry.value_ptr.* == setB) entry.value_ptr.* = setA;
  }

  return true;
}

fn getMinimalBindings(pieces: []const u8, seams: []const Seam, setOf: *std.AutoHashMap(u8, usize)) usize {
  var connections: usize = 0;
  var bindings: usize = 0;
  for (seams) |seam| {
    if (!doJoin(seam.pieces.first, seam.pieces.second, setOf)) continue;

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

  const seams: []const Seam = try getSeams(input.grid, allocator);
  defer allocator.free(seams);

  var setOf: std.AutoHashMap(u8, usize) = .init(allocator);
  defer setOf.deinit();

  for (0..pieces.len) |i| try setOf.put(pieces[i], i);

  return getMinimalBindings(pieces, seams, &setOf);
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const pieces: []const u8 = try getPieces(input.grid, allocator);
  defer allocator.free(pieces);

  const seams: []const Seam = try getSeams(input.grid, allocator);
  defer allocator.free(seams);

  var setOf: std.AutoHashMap(u8, usize) = .init(allocator);
  defer setOf.deinit();

  var minBindings: usize = std.math.maxInt(usize);
  for (0..pieces.len) |n| {
    const pieceN = pieces[n];
    if (pieceN == FRAME) continue;

    for (n + 1..pieces.len) |m| {
      const pieceM = pieces[m];
      if (pieceM == FRAME) continue;

      for (0..pieces.len) |i| try setOf.put(pieces[i], i);

      for (seams) |seam| {
        if (seam.pieces.has(pieceN)) _ = doJoin(pieceN, seam.pieces.other(pieceN), &setOf)
        else if (seam.pieces.has(pieceM)) _ = doJoin(pieceM, seam.pieces.other(pieceM), &setOf);
      }

      const bindings = getMinimalBindings(pieces, seams, &setOf);
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
