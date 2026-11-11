const common = @import("common");
const std = @import("std");

const utils = common.utils;
const EC = common.EC;

const TEST_INPUT =
  \\id=1, energy=5, connections=2,5,7
  \\id=2, energy=9, connections=6,7
  \\id=3, energy=3, connections=4
  \\id=4, energy=8, connections=3
  \\id=5, energy=1, connections=6,7
  \\id=6, energy=7, connections=1,7
  \\id=7, energy=6, connections=5
  ;

const Cloud = struct {
  energy: usize,
  connections: []const u8
};

const Input = struct {
  clouds: []const Cloud,

  arena: std.heap.ArenaAllocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var clouds: std.ArrayList(Cloud) = .empty;
    defer clouds.deinit(allocator);

    var arena: std.heap.ArenaAllocator = .init(allocator);

    var lineIt = std.mem.tokenizeAny(u8, source, "\r\n");
    while (lineIt.next()) |line| {
      var it: utils.SequenceIterator(u8, utils.isBase10Digit) = .init(line);

      _ = it.next();

      const energy: usize = try std.fmt.parseUnsigned(usize, it.next().?, 10);

      const connections = try arena.allocator().alloc(u8, it.countRemaining());

      var index: usize = 0;
      while (it.next()) |conn| : (index += 1)
        connections[index] = try std.fmt.parseUnsigned(u8, conn, 10) - 1;

      try clouds.append(allocator, .{ .energy = energy, .connections = connections });
    }

    return .{
      .clouds = try arena.allocator().dupe(Cloud, clouds.items),
      .arena = arena
    };
  }

  pub fn deinit(self: Input) void {
    self.arena.deinit();
  }
};

const MAX_STRIKE_ENERGY = 10;

const Strikes = struct {
  count: [MAX_STRIKE_ENERGY]usize = @splat(0),

  pub fn apply(self: *Strikes, energy: u8) void {
    if (energy > MAX_STRIKE_ENERGY) unreachable;
    if (energy == 0) return;

    self.count[energy - 1] += 1;
  }

  pub fn propagateTo(self: *const Strikes, other: *Strikes) void {
    for (1..MAX_STRIKE_ENERGY) |i| other.count[i - 1] += self.count[i];
  }

  pub fn totalEnergy(self: *const Strikes) usize {
    var total: usize = 0;
    for (0..MAX_STRIKE_ENERGY) |i| total += (i + 1) * self.count[i];
    return total;
  }
};

fn simulate(rootCloud: usize, rootStrikeEnergy: u8, explosionThreshold: ?usize, clouds: []const Cloud, allocator: std.mem.Allocator) !usize {
  const energies = try allocator.alloc(usize, clouds.len);
  defer allocator.free(energies);

  for (0..clouds.len) |i| energies[i] = clouds[i].energy;

  var strikes = try allocator.alloc(Strikes, clouds.len);
  defer allocator.free(strikes);

  @memset(strikes, .{});
  strikes[rootCloud].apply(rootStrikeEnergy);

  var nextStrikes = try allocator.alloc(Strikes, clouds.len);
  defer allocator.free(nextStrikes);

  var explodedClouds: std.ArrayList(usize) = .empty;
  defer explodedClouds.deinit(allocator);

  while (!std.mem.allEqual(u8, @ptrCast(strikes), 0)) {
    @memset(nextStrikes, .{});

    for (0..clouds.len) |i| {
      if (std.mem.findScalar(usize, explodedClouds.items, i)) |_| continue;
      const strike = strikes[i];

      energies[i] += strike.totalEnergy();
      for (clouds[i].connections) |conn| strike.propagateTo(&nextStrikes[conn]);
    }

    if (explosionThreshold) |thresh|
      for (0..clouds.len) |i| {
        if (energies[i] < thresh) continue;

        energies[i] = 0;
        try explodedClouds.append(allocator, i);
        for (clouds[i].connections) |conn| nextStrikes[conn].apply(10);
      };

    const swapTemp = strikes;
    strikes = nextStrikes;
    nextStrikes = swapTemp;
  }

  var total: usize = 0;
  for (energies) |energy| total += energy;
  return total;
}

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const clouds = input.clouds;

  var rootCloud: usize = 0;
  for (0..clouds.len) |i| {
    if (clouds[i].connections.len > clouds[rootCloud].connections.len) rootCloud = i;
  }

  return simulate(rootCloud, 5, null, clouds, allocator);
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const clouds = input.clouds;

  var rootCloud: usize = 0;
  for (0..clouds.len) |i| {
    if (clouds[i].connections.len > clouds[rootCloud].connections.len) rootCloud = i;
  }

  return simulate(rootCloud, 10, null, clouds, allocator);
}

fn part3WithThreshold(rawInput: []const u8, allocator: std.mem.Allocator, threshold: usize) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const clouds = input.clouds;

  var maxEnergy: usize = 0;
  for (0..clouds.len) |i| {
    const energy = try simulate(i, 10, threshold, clouds, allocator);
    if (energy > maxEnergy) maxEnergy = energy;
  }

  return maxEnergy;
}

fn part3_test(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  return part3WithThreshold(rawInput, allocator, 100);
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  return part3WithThreshold(rawInput, allocator, 1_000_000);
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 7,
  .parts = &.{
    .{ .run = &part1, .expected = 272, .@"test" = .{ .input = TEST_INPUT, .expected = 102 } },
    .{ .run = &part2, .expected = 132923678, .@"test" = .{ .input = TEST_INPUT, .expected = 1316 } },
    .{ .run = &part3, .expected = 30104124, .@"test" = .{ .run = &part3_test, .input = TEST_INPUT, .expected = 187 } }
  }
});
