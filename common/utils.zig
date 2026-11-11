const std = @import("std");

pub fn isBase10Digit(char: u8) bool {
  return char >= '0' and char <= '9';
}

pub fn SequenceIterator(comptime T: type, comptime predicate: fn (T) bool) type {
  return struct {
    sequence: []const T,
    index: usize = 0,

    pub fn init(sequence: []const T) @This() {
      return .{ .sequence = sequence };
    }

    pub fn next(self: *@This()) ?[]const T {
      while (self.index < self.sequence.len) : (self.index += 1)
        if (predicate(self.sequence[self.index])) break;

      const startIndex = self.index;

      while (self.index < self.sequence.len) : (self.index += 1)
        if (!predicate(self.sequence[self.index])) break;

      return if (self.index > startIndex) self.sequence[startIndex..self.index] else null;
    }

    pub fn countRemaining(self: *@This()) usize {
      const index = self.index;
      defer self.index = index;

      var count: usize = 0;
      while (self.next()) |_| count += 1;
      return count;
    }

    pub fn reset(self: *@This()) void {
      self.index = 0;
    }
  };
}

pub fn Matrix(comptime T: type) type {
  return struct {
    width: usize,
    height: usize,
    values: []T,

    pub fn init(width: usize, height: usize, allocator: std.mem.Allocator) !@This() {
      return .{
        .width = width,
        .height = height,
        .values = try allocator.alloc(T, width * height)
      };
    }

    pub inline fn at(self: @This(), x: usize, y: usize) *T {
      return &self.values[y * self.height + x];
    }

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
      allocator.free(self.values);
    }
  };
}

fn enumeratePairsInternal(
  comptime T: type,
  remaining: []T,
  depth: u8,
  pairs: [][2]T,
  context: anytype,
  comptime func: fn (anytype, []const [2]T) anyerror!void
) !void {
  if (remaining.len == 2) {
    pairs[depth] = remaining[0..2].*;
    try func(context, pairs);
    return;
  }

  for (1..remaining.len) |i| {
    pairs[depth] = .{ remaining[0], remaining[i] };

    @memmove(remaining[0..remaining.len - 1], remaining[1..]);
    @memmove(remaining[i - 1..remaining.len - 1], remaining[i..]);
    try enumeratePairsInternal(T, remaining[0..remaining.len - 2], depth + 1, pairs, context, func);
    @memmove(remaining[i..], remaining[i - 1..remaining.len - 1]);
    @memmove(remaining[1..], remaining[0..remaining.len - 1]);

    remaining[0], remaining[i] = pairs[depth];
  }
}

pub fn enumeratePairs(
  comptime T: type,
  elements: []const T,
  context: anytype,
  comptime func: fn (anytype, []const [2]T) anyerror!void,
  allocator: std.mem.Allocator
) !void {
  std.debug.assert(elements.len % 2 == 0);
  if (elements.len == 0) return;

  const pairs = try allocator.alloc([2]T, elements.len / 2);
  defer allocator.free(pairs);

  const remaining = try allocator.dupe(T, elements);
  defer allocator.free(remaining);

  try enumeratePairsInternal(T, remaining, 0, pairs, context, func);
}
