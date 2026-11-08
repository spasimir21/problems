const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
  \\[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}
  \\[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}
  ;

const MAX_BUTTON_CONNECTIONS = 10;
const MAX_JOLTAGE_COUNT = 10;

const Joltage = [MAX_JOLTAGE_COUNT]usize;

const Button = struct {
  parity: usize = 0,
  connectionCount: usize = 0,
  connections: [MAX_BUTTON_CONNECTIONS]u8 = @splat(0)
};

const Machine = struct {
  lights: usize = 0,
  buttons: []const Button,
  joltage: Joltage = @splat(0)
};

pub const Input = struct {
  arena: std.heap.ArenaAllocator,
  iter: std.mem.TokenIterator(u8, .any),

  pub fn init(source: []const u8, allocator: std.mem.Allocator) Input {
    return .{
      .arena = .init(allocator),
      .iter = std.mem.tokenizeAny(u8, source, "\r\n")
    };
  }

  pub fn deinit(self: *Input) void {
    self.arena.deinit();
  }

  pub fn next(self: *Input) !?Machine {
    const line = self.iter.next() orelse return null;
    const allocator = self.arena.allocator();

    const nButtons = std.mem.countScalar(u8, line, ' ') - 1;
    const buttons = try allocator.alloc(Button, nButtons);
    @memset(buttons, .{});

    var machine: Machine = .{ .buttons = buttons };

    var it = std.mem.splitScalar(u8, line, ' ');
    var buttonIndex: usize = 0;
    while (it.next()) |part|
      switch (part[0]) {
        '[' => 
          for (0..part.len - 2) |i|
            if (part[i + 1] == '#') {
              machine.lights |= @as(usize, 1) <<| i;
            },
        '(' => {
          const button = &buttons[buttonIndex];
          buttonIndex += 1;

          var connectionIt = std.mem.splitScalar(u8, part[1..part.len - 1], ',');
          while (connectionIt.next()) |connSource| {
            if (button.connectionCount >= MAX_BUTTON_CONNECTIONS) return error.InvalidInput;

            const conn = try std.fmt.parseUnsigned(u8, connSource, 10);
            button.connections[button.connectionCount] = conn;
            button.connectionCount += 1;
            button.parity |= @as(usize, 1) <<| conn;
          }
        },
        '{' => {
          var joltageIt = std.mem.splitScalar(u8, part[1..part.len - 1], ',');

          var i: usize = 0;
          while (joltageIt.next()) |joltageSource| {
            if (i >= MAX_JOLTAGE_COUNT) return error.InvalidInput;
            machine.joltage[i] = try std.fmt.parseUnsigned(usize, joltageSource, 10);
            i += 1;
          }
        },
        else => return error.InvalidInput
      };

    return machine;
  }
};

const ParityIterator = struct {
  target: usize,
  index: usize = 0,
  parity: usize = 0,
  buttons: []const Button,

  pub fn next(self: *ParityIterator) ?usize {
    if (self.index == 0) {
      self.index += 1;
      if (self.target == 0) return 0;
    }

    while (self.index < (@as(usize, 1) <<| self.buttons.len)) {
      const index = self.index;
      self.index += 1;

      const gray = index ^ (index >> 1);
      const changedIndex = @ctz(gray ^ (index - 1) ^ ((index - 1) >> 1));

      self.parity ^= self.buttons[changedIndex].parity;

      if (self.parity == self.target) return gray;
    }

    return null;
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput, allocator);
  defer input.deinit();

  var totalClicks: usize = 0;

  while (try input.next()) |machine| {
    var fewestClicks: ?usize = null;

    var it: ParityIterator = .{ .target = machine.lights, .buttons = machine.buttons };
    while (it.next()) |permutation| {
      const clicks = @popCount(permutation);
      if (fewestClicks == null or clicks < fewestClicks.?) fewestClicks = clicks;
    }

    totalClicks += fewestClicks orelse return error.InvalidLights;
  }

  return totalClicks;
}

fn getFewestClicksForJoltage(joltage: Joltage, buttons: []const Button, cache: *std.AutoHashMap(Joltage, ?usize)) !?usize {
  if (std.mem.allEqual(usize, &joltage, 0)) return 0;
  if (cache.get(joltage)) |clicks| return clicks;
  
  var parity: usize = 0;
  for (0..joltage.len) |i| {
    if (joltage[i] % 2 != 0) parity |= @as(usize, 1) <<| i;
  }

  var fewestClicks: ?usize = null;

  var it: ParityIterator = .{ .target = parity, .buttons = buttons };
  parity: while (it.next()) |permutation| {
    var subJoltage = joltage;

    var presses = permutation;
    while (presses != 0) {
      const index = @ctz(presses);
      presses ^= @as(usize, 1) <<| index;

      for (0..buttons[index].connectionCount) |i| {
        const conn = buttons[index].connections[i];
        if (subJoltage[conn] == 0) continue :parity;
        subJoltage[conn] -= 1;
      }
    }

    for (0..subJoltage.len) |i| subJoltage[i] /= 2;
    const subJoltageClicks = try getFewestClicksForJoltage(subJoltage, buttons, cache) orelse continue;

    const clicks: usize = @popCount(permutation) + 2 * subJoltageClicks;
    if (fewestClicks == null or clicks < fewestClicks.?) fewestClicks = clicks;
  }

  try cache.put(joltage, fewestClicks);
  return fewestClicks;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput, allocator);
  defer input.deinit();

  var cache: std.AutoHashMap(Joltage, ?usize) = .init(allocator);
  defer cache.deinit();

  var totalClicks: usize = 0;

  while (try input.next()) |machine| {
    cache.clearRetainingCapacity();
    totalClicks += try getFewestClicksForJoltage(machine.joltage, machine.buttons, &cache) orelse return error.InvalidJoltage;
  }

  return totalClicks;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 10,
  .parts = &.{
    .{ .run = &part1, .expected = 545, .@"test" = .{ .input = TEST_INPUT, .expected = 7 } },
    .{ .run = &part2, .expected = 22430, .@"test" = .{ .input = TEST_INPUT, .expected = 33 } }
  }
});
