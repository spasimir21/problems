const common = @import("common");
const std = @import("std");

const utils = common.utils;
const EC = common.EC;

const TEST_INPUTS = .{
  \\###########
  \\#####.#####
  \\###.....###
  \\##.......##
  \\##.>>.<<.##
  \\#v...>...v#
  \\##...v...##
  \\##.......##
  \\###.....###
  \\#####.#####
  \\###########
  ,
  \\#######################
  \\###########.###########
  \\#######.^>.^.<^.#######
  \\#####..<.>.v^>>^^<#####
  \\####..v<^v.>.>v..^.####
  \\###.................###
  \\###.................###
  \\##.......<...<.<....>##
  \\##...v....>....v.v<.^##
  \\##........###........##
  \\##v......#####.......##
  \\#.<......#####......>.#
  \\##.......#####.......##
  \\##........###........##
  \\##...................##
  \\##...................##
  \\###.................###
  \\###.................###
  \\####...............####
  \\#####.............#####
  \\#######....v....#######
  \\###########.###########
  \\#######################
};

const Point = struct { x: usize, y: usize };

const Direction = enum {
  Left, Right, Up, Down,

  pub fn opposite(self: Direction) Direction {
    return switch (self) {
      .Left => .Right,
      .Right => .Left,
      .Up => .Down,
      .Down => .Up
    };
  }

  pub fn clockwise(self: Direction) Direction {
    return switch (self) {
      .Left => .Up,
      .Right => .Down,
      .Up => .Right,
      .Down => .Left
    };
  }
};

const Ghost = struct {
  position: Point,
  direction: Direction,
  collisions: usize = 0,

  pub fn nextPosition(self: Ghost) Point {
    return switch (self.direction) {
      .Left => .{ .x = self.position.x - 1, .y = self.position.y },
      .Right => .{ .x = self.position.x + 1, .y = self.position.y },
      .Up => .{ .x = self.position.x, .y = self.position.y - 1 },
      .Down => .{ .x = self.position.x, .y = self.position.y + 1 }
    }; 
  }
};

const Input = struct {
  walls: []const []const bool,
  ghosts: []Ghost,

  arena: std.heap.ArenaAllocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var walls: std.ArrayList([]const bool) = .empty;
    defer walls.deinit(allocator);

    var ghosts: std.ArrayList(Ghost) = .empty;
    defer ghosts.deinit(allocator);

    var arena: std.heap.ArenaAllocator = .init(allocator);

    var lineIt = std.mem.tokenizeAny(u8, source, "\r\n");
    while (lineIt.next()) |line| {
      const row = try arena.allocator().alloc(bool, line.len);
      for (0..line.len) |i| {
        row[i] = line[i] == '#';
        if (line[i] == '#' or line[i] == '.') continue;

        try ghosts.append(allocator, .{
          .position = .{ .x = i, .y = walls.items.len },
          .direction = switch (line[i]) {
            '<' => .Left,
            '>' => .Right,
            '^' => .Up,
            'v' => .Down,
            else => unreachable
          }
        });
      }

      try walls.append(allocator, row);
    }

    return .{
      .walls = try arena.allocator().dupe([]const bool, walls.items),
      .ghosts = try arena.allocator().dupe(Ghost, ghosts.items),
      .arena = arena
    };
  }

  pub fn deinit(self: *Input) void {
    self.arena.deinit();
  }
};

fn getStateHash(ghosts: []const Ghost, threshold: usize) u64 {
  var hash: std.hash.Wyhash = .init(0);

  for (0..ghosts.len) |i| {
    const ghost = &ghosts[i];
    if (ghost.collisions >= threshold) continue;

    hash.update(&.{ @intCast(i) });
    hash.update(@ptrCast(&ghost.position));
    hash.update(@ptrCast(&ghost.direction));
  }

  return hash.final();
}

fn simulateRound(
  walls: []const []const bool,
  ghosts: []Ghost,
  threshold: usize,
  occupiedPositions: *std.AutoHashMap(Point, usize)
) !bool {
  occupiedPositions.clearRetainingCapacity();

  for (ghosts) |*ghost| {
    if (ghost.collisions >= threshold) continue;
    const nextPosition = ghost.nextPosition();

    if (walls[nextPosition.y][nextPosition.x]) {
      ghost.direction = ghost.direction.clockwise();
      ghost.collisions += 1;
      if (ghost.collisions >= threshold) continue;
    } else ghost.position = nextPosition;

    const entry = try occupiedPositions.getOrPutValue(ghost.position, 0);
    entry.value_ptr.* += 1;
  }

  for (ghosts) |*ghost| {
    if (ghost.collisions >= threshold or occupiedPositions.get(ghost.position).? <= 1) continue;
    ghost.direction = ghost.direction.opposite();
    ghost.collisions += 1;
  }

  for (ghosts) |ghost| {
    if (ghost.collisions < threshold) break;
  } else return true;

  return false;
}

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var occupiedPositions: std.AutoHashMap(Point, usize) = .init(allocator);
  defer occupiedPositions.deinit();

  for (0..10) |_|
    _ = try simulateRound(input.walls, input.ghosts, std.math.maxInt(usize), &occupiedPositions);

  var collisions: usize = 0;
  for (input.ghosts) |ghost| collisions += ghost.collisions;
  return collisions;
}

fn findLoop(
  walls: []const []const bool,
  ghosts: []Ghost,
  threshold: usize,
  round: *usize,
  collisionsPerGhost: []usize,
  snapshot: []Ghost,
  occupiedPositions: *std.AutoHashMap(Point, usize),
  states: *std.AutoHashMap(u64, usize)
) !?usize {
  const initialRound = round.*;
  @memcpy(snapshot, ghosts);

  states.clearRetainingCapacity();

  var loopRounds: usize = 0;
  const firstLoopRound: usize = while (true) : (round.* += 1) {
    const hash = getStateHash(ghosts, threshold);
    if (states.get(hash)) |firstLoopRound| {
      loopRounds = round.* - firstLoopRound;
      for (0..ghosts.len) |i| collisionsPerGhost[i] = ghosts[i].collisions;

      @memcpy(ghosts, snapshot);
      round.* = initialRound;

      break firstLoopRound;
    }

    try states.put(hash, round.*);

    const didEnd = try simulateRound(walls, ghosts, threshold, occupiedPositions);
    if (didEnd) return null;
  };

  while (round.* < firstLoopRound) : (round.* += 1)
    _ = try simulateRound(walls, ghosts, threshold, occupiedPositions);

  for (0..ghosts.len) |i| collisionsPerGhost[i] -= ghosts[i].collisions;

  return loopRounds;
}

fn simulate(rawInput: []const u8, allocator: std.mem.Allocator, threshold: usize) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const walls = input.walls;
  const ghosts = input.ghosts;

  const collisionsPerGhost = try allocator.alloc(usize, input.ghosts.len);
  defer allocator.free(collisionsPerGhost);

  const snapshot = try allocator.alloc(Ghost, input.ghosts.len);
  defer allocator.free(snapshot);

  var occupiedPositions: std.AutoHashMap(Point, usize) = .init(allocator);
  defer occupiedPositions.deinit();

  var states: std.AutoHashMap(u64, usize) = .init(allocator);
  defer states.deinit();

  var round: usize = 1;
  while (true) {
    const loopRounds = try findLoop(
      walls, 
      ghosts, 
      threshold, 
      &round, 
      collisionsPerGhost,
      snapshot,
      &occupiedPositions,
      &states
    ) orelse break;

    var repeats: usize = std.math.maxInt(usize);
    for (0..ghosts.len) |i| {
      if (collisionsPerGhost[i] == 0) continue;
      var possibleRepeats = (threshold - ghosts[i].collisions) / collisionsPerGhost[i];
      if ((threshold - ghosts[i].collisions) % collisionsPerGhost[i] == 0) possibleRepeats -= 1;
      if (possibleRepeats < repeats) repeats = possibleRepeats;
    }

    for (0..ghosts.len) |i| ghosts[i].collisions += collisionsPerGhost[i] * repeats;
    round += loopRounds * repeats;
  }

  return round;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  return simulate(rawInput, allocator, 10_000);
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  return simulate(rawInput, allocator, 1_000_000_000_000);
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 10,
  .parts = &.{
    .{ .run = &part1, .expected = 53, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 29 } },
    .{ .run = &part2, .expected = 141410, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 50000 } },
    .{ .run = &part3, .expected = 9349285714304, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 13314695352588 } }
  }
});
