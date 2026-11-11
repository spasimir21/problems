const common = @import("common");
const std = @import("std");

const utils = common.utils;
const EC = common.EC;

const TEST_INPUTS = .{
  \\portals: 10
  \\
  \\5 10
  \\2 7
  ,
  \\portals: 64
  \\
  \\1 40
  \\3 35
  \\5 42
  \\7 50
};

const Link = [2]usize;

const Input = struct {
  nPortals: usize,
  links: []const Link,

  allocator: std.mem.Allocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var links: std.ArrayList(Link) = .empty;
    defer links.deinit(allocator);

    var lineIt = std.mem.tokenizeAny(u8, source, "\r\n");

    const nPortals = nPortals: {
      var it = std.mem.splitScalar(u8, lineIt.next().?, ' ');
      _ = it.next();
      break :nPortals try std.fmt.parseUnsigned(usize, it.next().?, 10);
    };

    while (lineIt.next()) |line| {
      var it = std.mem.splitScalar(u8, line, ' ');

      try links.append(allocator, .{
        try std.fmt.parseUnsigned(usize, it.next().?, 10) - 1,
        try std.fmt.parseUnsigned(usize, it.next().?, 10) - 1
      });
    }

    return .{
      .nPortals = nPortals,
      .links = try links.toOwnedSlice(allocator),
      .allocator = allocator
    };
  }

  pub fn deinit(self: Input) void {
    self.allocator.free(self.links);
  }
};

fn noLinksStrain(nPortals: usize, connectivity: u8) !usize {
  var strain: usize = 0;
  for (1..nPortals) |i| strain += try std.math.divCeil(usize, @min(i, nPortals - i), connectivity);
  return strain * nPortals;
}

fn minimizeDistances(nPortals: usize, connectivity: u8, links: []const Link, distances: utils.Matrix(usize)) !void {
  for (0..nPortals) |i|
    for (0..nPortals) |j| {
      const direct = @max(i, j) - @min(i, j);
      distances.at(i, j).* = try std.math.divCeil(usize, @min(direct, nPortals - direct), connectivity);
    };

  for (links) |link| {
    distances.at(link[0], link[1]).* = 1;
    distances.at(link[1], link[0]).* = 1;
  }

  for (0..nPortals) |k|
    for (0..nPortals) |i|
      for (0..nPortals) |j| {
        distances.at(i, j).* = @min(
          distances.at(i, j).*,
          distances.at(i, k).* + distances.at(k, j).*
        );
      };
}

fn updateDistances(nPortals: usize, link: Link, distances: utils.Matrix(usize)) !void {
  const a, const b = link;

  if (distances.at(a, b).* <= 1 and distances.at(b, a).* <= 1) return;
  distances.at(a, b).* = 1;
  distances.at(b, a).* = 1;

  for (0..nPortals) |i| {
    for (0..nPortals) |j|
      distances.at(i, j).* = @min(
        distances.at(i, j).*,
        distances.at(i, a).* + 1 + distances.at(b, j).*,
        distances.at(i, b).* + 1 + distances.at(a, j).*
      );
  }
}

fn calculateStrain(distances: utils.Matrix(usize)) usize {
  var strain: usize = 0;
  for (distances.values) |distance| strain += distance;
  return strain;
}

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const distances: utils.Matrix(usize) = try .init(input.nPortals, input.nPortals, allocator);
  defer distances.deinit(allocator);

  try minimizeDistances(input.nPortals, 1, input.links, distances);

  return try noLinksStrain(input.nPortals, 1) - calculateStrain(distances);
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const distances: utils.Matrix(usize) = try .init(input.nPortals, input.nPortals, allocator);
  defer distances.deinit(allocator);

  try minimizeDistances(input.nPortals, 3, input.links, distances);

  const snapshot = try allocator.dupe(usize, distances.values);
  defer allocator.free(snapshot);

  var minStrain: usize = std.math.maxInt(usize);
  for (0..input.nPortals) |i|
    for (0..input.nPortals) |j| {
      @memcpy(distances.values, snapshot);
      try updateDistances(input.nPortals, .{ i, j }, distances);

      const strain = calculateStrain(distances);
      if (strain < minStrain) minStrain = strain;
    };

  return try noLinksStrain(input.nPortals, 3) - minStrain;
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const distances: utils.Matrix(usize) = try .init(input.nPortals, input.nPortals, allocator);
  defer distances.deinit(allocator);

  try minimizeDistances(input.nPortals, 3, input.links, distances);

  const snapshot = try allocator.dupe(usize, distances.values);
  defer allocator.free(snapshot);

  const crystalDistance = input.nPortals / 8;
  var crystals: [8]usize = @splat(0);

  var minStrain: usize = std.math.maxInt(usize);
  for (0..crystalDistance) |phase| {
    for (0..crystals.len) |i| crystals[i] = phase + i * crystalDistance;

    try utils.enumeratePairs(
      usize,
      &crystals,
      .{
        .distances = distances,
        .snapshot = snapshot,
        .nPortals = input.nPortals,
        .minStrain = &minStrain
      },
      struct {
        pub fn checkStrain(ctx: anytype, pairs: []const [2]usize) !void {
          @memcpy(ctx.distances.values, ctx.snapshot);
          try updateDistances(ctx.nPortals, pairs[0], ctx.distances);
          try updateDistances(ctx.nPortals, pairs[1], ctx.distances);
          try updateDistances(ctx.nPortals, pairs[2], ctx.distances);
          try updateDistances(ctx.nPortals, pairs[3], ctx.distances);

          const strain = calculateStrain(ctx.distances);
          if (strain < ctx.minStrain.*) ctx.minStrain.* = strain;
        }
      }.checkStrain,
      allocator
    );
  }

  return try noLinksStrain(input.nPortals, 3) - minStrain;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 11,
  .parts = &.{
    .{ .run = &part1, .expected = 1624, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 60 } },
    .{ .run = &part2, .expected = 3648, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 6 } },
    .{ .run = &part3, .expected = 19650, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 9634 } }
  }
});
