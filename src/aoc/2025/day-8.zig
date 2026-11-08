const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\162,817,812
  \\57,618,57
  \\906,360,560
  \\592,479,940
  \\352,342,300
  \\466,668,158
  \\542,29,236
  \\431,825,988
  \\739,650,466
  \\52,470,668
  \\216,146,977
  \\819,987,18
  \\117,168,530
  \\805,96,715
  \\346,949,466
  \\970,615,88
  \\941,993,340
  \\862,61,35
  \\984,92,344
  \\425,690,689
  ;

pub const Box = struct {
  x: f64,
  y: f64,
  z: f64,
  
  pub fn distanceSqrd(self: Box, other: Box) f64 {
    return
      std.math.pow(f64, self.x - other.x, 2) +
      std.math.pow(f64, self.y - other.y, 2) +
      std.math.pow(f64, self.z - other.z, 2);
  }
};

pub const Input = struct {
  allocator: std.mem.Allocator,
  boxes: []const Box,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var boxes: std.ArrayList(Box) = .empty;
    defer boxes.deinit(allocator);

    var lines = std.mem.tokenizeAny(u8, source, "\r\n");
    while (lines.next()) |line| {
      var it = std.mem.splitScalar(u8, line, ',');
      const x = try std.fmt.parseFloat(f64, it.next().?);
      const y = try std.fmt.parseFloat(f64, it.next().?);
      const z = try std.fmt.parseFloat(f64, it.next().?);

      try boxes.append(allocator, .{ .x = x, .y = y, .z = z });
    }

    return .{ .allocator = allocator, .boxes = try boxes.toOwnedSlice(allocator) };
  }

  pub fn deinit(self: *Input) void {
    self.allocator.free(self.boxes);
  }
};

const BoxPair = struct {
  aIndex: usize,
  bIndex: usize,
  distance: f64,

  pub fn lessThan(context: void, a: BoxPair, b: BoxPair) bool {
    _ = context;
    return a.distance < b.distance;
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator, topNConnections: usize) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var pairs: std.ArrayList(BoxPair) = .empty;
  defer pairs.deinit(allocator);

  for (0..input.boxes.len) |i|
    for (i + 1..input.boxes.len) |j|
      try pairs.append(allocator, .{
        .aIndex = i,
        .bIndex = j,
        .distance = input.boxes[i].distanceSqrd(input.boxes[j])
      });

  std.mem.sortUnstable(BoxPair, pairs.items, {}, BoxPair.lessThan);

  const circuitOfBox = try allocator.alloc(usize, input.boxes.len);
  defer allocator.free(circuitOfBox);

  const circuitSizes = try allocator.alloc(usize, input.boxes.len);
  defer allocator.free(circuitSizes);

  for (0..input.boxes.len) |i| circuitOfBox[i] = i;
  @memset(circuitSizes, 1);

  for (pairs.items[0..topNConnections]) |pair| {
    const circuitA = circuitOfBox[pair.aIndex];
    const circuitB = circuitOfBox[pair.bIndex];
    if (circuitA == circuitB) continue;

    circuitSizes[circuitA] += circuitSizes[circuitB];
    circuitSizes[circuitB] = 0;

    for (0..circuitOfBox.len) |i|
      if (circuitOfBox[i] == circuitB) {
        circuitOfBox[i] = circuitA;
      };
  }

  std.mem.sortUnstable(usize, circuitSizes, {}, std.sort.desc(usize));

  var result: usize = 1;
  for (0..3) |i| result *= circuitSizes[i];
  return result;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var pairs: std.ArrayList(BoxPair) = .empty;
  defer pairs.deinit(allocator);

  for (0..input.boxes.len) |i|
    for (i + 1..input.boxes.len) |j|
      try pairs.append(allocator, .{
        .aIndex = i,
        .bIndex = j,
        .distance = input.boxes[i].distanceSqrd(input.boxes[j])
      });

  std.mem.sortUnstable(BoxPair, pairs.items, {}, BoxPair.lessThan);

  const circuitOfBox = try allocator.alloc(usize, input.boxes.len);
  defer allocator.free(circuitOfBox);

  for (0..input.boxes.len) |i| circuitOfBox[i] = i;

  var lastPair: BoxPair = undefined;
  for (pairs.items) |pair| {
    const circuitA = circuitOfBox[pair.aIndex];
    const circuitB = circuitOfBox[pair.bIndex];
    if (circuitA == circuitB) continue;

    lastPair = pair;

    for (0..circuitOfBox.len) |i|
      if (circuitOfBox[i] == circuitB) {
        circuitOfBox[i] = circuitA;
      };
  }

  return @as(usize, @intFromFloat(input.boxes[lastPair.aIndex].x * input.boxes[lastPair.bIndex].x));
}

fn part1Test(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  return part1(rawInput, allocator, 10);
}

fn part1Run(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  return part1(rawInput, allocator, 1000);
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 8,
  .parts = &.{
    .{ .run = &part1Run, .expected = 131580, .@"test" = .{ .run = &part1Test, .input = TEST_INPUT, .expected = 40 } },
    .{ .run = &part2, .expected = 6844224, .@"test" = .{ .input = TEST_INPUT, .expected = 25272 } }
  }
});
