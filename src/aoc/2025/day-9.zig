const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUT =
  \\7,1
  \\11,1
  \\11,7
  \\9,7
  \\9,5
  \\2,5
  \\2,3
  \\7,3
  ;

const Point = struct {
  x: usize,
  y: usize
};

const Direction = enum { Horizontal, Vertical };

const Line = struct {
  x1: usize,
  y1: usize,
  x2: usize,
  y2: usize,
  direction: Direction,

  pub fn fromPoints(a: Point, b: Point) !Line {
    return .{
      .x1 = @min(a.x, b.x),
      .y1 = @min(a.y, b.y),
      .x2 = @max(a.x, b.x),
      .y2 = @max(a.y, b.y),
      .direction =
        if (a.x == b.x) .Vertical
        else if (a.y == b.y) .Horizontal
        else return error.InvalidLine
    };
  }
};

const Rect = struct {
  x1: usize,
  y1: usize,
  x2: usize,
  y2: usize,

  pub fn fromPoints(a: Point, b: Point) Rect {
    return .{
      .x1 = @min(a.x, b.x),
      .y1 = @min(a.y, b.y),
      .x2 = @max(a.x, b.x),
      .y2 = @max(a.y, b.y)
    };
  }

  pub fn area(self: Rect) usize {
    return (self.x2 - self.x1 + 1) * (self.y2 - self.y1 + 1);
  }

  pub fn center(self: Rect) Point {
    return .{
      .x = self.x1 + (self.x2 - self.x1) / 2,
      .y = self.y1 + (self.y2 - self.y1) / 2
    };
  }
};

pub const Input = struct {
  allocator: std.mem.Allocator,
  tiles: []const Point,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var tiles: std.ArrayList(Point) = .empty;
    defer tiles.deinit(allocator);

    var lines = std.mem.tokenizeAny(u8, source, "\r\n");
    while (lines.next()) |line| {
      var it = std.mem.splitScalar(u8, line, ',');

      try tiles.append(allocator, .{
        .x = try std.fmt.parseUnsigned(usize, it.next().?, 10),
        .y = try std.fmt.parseUnsigned(usize, it.next().?, 10)
      });
    }
    
    return .{ .allocator = allocator, .tiles = try tiles.toOwnedSlice(allocator) };
  }

  pub fn deinit(self: *Input) void {
    self.allocator.free(self.tiles);
  }
};

const Polygon = struct {
  edges: []const Line,
  allocator: std.mem.Allocator,

  pub fn init(points: []const Point, allocator: std.mem.Allocator) !Polygon {
    var edges: std.ArrayList(Line) = .empty;
    defer edges.deinit(allocator);

    for (1..points.len) |i| try edges.append(allocator, try .fromPoints(points[i - 1], points[i]));
    try edges.append(allocator, try .fromPoints(points[points.len - 1], points[0]));

    return .{ .allocator = allocator, .edges = try edges.toOwnedSlice(allocator) };
  }

  pub fn deinit(self: Polygon) void {
    self.allocator.free(self.edges);
  }

  pub fn containsPoint(self: Polygon, point: Point) bool {
    var contains: bool = false;
    
    for (self.edges) |edge|
      switch (edge.direction) {
        .Horizontal => {
          if (
            edge.y1 == point.y and
            point.x >= edge.x1 and
            point.x <= edge.x2
          )
            return true;
        },
        .Vertical => {
          if (
            edge.x1 == point.x and
            point.y >= edge.y1 and
            point.y <= edge.y2
          )
            return true;

          if (
            edge.x1 > point.x and
            point.y >= edge.y1 and
            point.y < edge.y2
          )
            contains = !contains;
        }
      };

    return contains;
  }

  pub fn enclosesRect(self: Polygon, rect: Rect) bool {
    if (!self.containsPoint(rect.center())) return false;

    for (self.edges) |edge|
      switch (edge.direction) {
        .Horizontal =>
          if (
            edge.y1 > rect.y1 and
            edge.y1 < rect.y2 and
            edge.x1 < rect.x2 and
            edge.x2 > rect.x1
          ) return false,
        .Vertical =>
          if (
            edge.x1 > rect.x1 and
            edge.x1 < rect.x2 and
            edge.y1 < rect.y2 and
            edge.y2 > rect.y1
          ) return false
      };

    return true;
  }
};

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var maxArea: usize = 0;
  for (0..input.tiles.len) |i|
    for (i + 1..input.tiles.len) |j| {
      const area = Rect.fromPoints(input.tiles[i], input.tiles[j]).area();
      if (area > maxArea) maxArea = area;
    };

  return maxArea;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  const polygon: Polygon = try .init(input.tiles, allocator);
  defer polygon.deinit();

  var maxArea: usize = 0;
  for (0..input.tiles.len) |i|
    for (i + 1..input.tiles.len) |j| {
      const rect = Rect.fromPoints(input.tiles[i], input.tiles[j]);
      if (!polygon.enclosesRect(rect)) continue;

      const area = rect.area();
      if (area > maxArea) maxArea = area;
    };

  return maxArea;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 9,
  .parts = &.{
    .{ .run = &part1, .expected = 4749838800, .@"test" = .{ .input = TEST_INPUT, .expected = 50 } },
    .{ .run = &part2, .expected = 1624057680, .@"test" = .{ .input = TEST_INPUT, .expected = 24 } }
  }
});
