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

    pub fn init(width: usize, height: usize, value: T, allocator: std.mem.Allocator) !@This() {
      const self: @This() = .{
        .width = width,
        .height = height,
        .values = try allocator.alloc(T, width * height)
      };

      @memset(self.values, value);

      return self;
    }

    pub inline fn get(self: @This(), x: usize, y: usize) T {
      return self.values[y * self.width + x];
    }

    pub inline fn set(self: @This(), x: usize, y: usize, value: T) void {
      self.values[y * self.width + x] = value;
    }

    pub inline fn at(self: @This(), x: usize, y: usize) *T {
      return &self.values[y * self.width + x];
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
  comptime func: fn (@TypeOf(context), []const [2]T) anyerror!void
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
  comptime func: fn (@TypeOf(context), []const [2]T) anyerror!void,
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

pub fn OrderedPair(comptime T: type) type {
  return struct {
    first: T,
    second: T,

    pub fn make(a: T, b: T) @This() {
      return .{ .first = @min(a, b), .second = @max(a, b) };
    }

    pub fn has(self: @This(), value: T) bool {
      return self.first == value or self.second == value;
    }

    pub fn other(self: @This(), value: T) T {
      return if (self.first == value) self.second else self.first;
    }
  };
}

pub const DisjointUnionSet = struct {
  n: usize,
  roots: []usize,
  sizes: []usize,
  allocator: std.mem.Allocator,

  pub fn init(n: usize, allocator: std.mem.Allocator) !DisjointUnionSet {
    const roots = try allocator.alloc(usize, n);
    for (0..n) |i| roots[i] = i;

    const sizes = try allocator.alloc(usize, n);
    @memset(sizes, 1);

    return .{
      .n = n,
      .roots = roots,
      .sizes = sizes,
      .allocator = allocator
    };
  }

  pub fn reset(self: DisjointUnionSet) void {
    for (0..self.n) |i| self.roots[i] = i;
    @memset(self.sizes, 1);
  }

  pub fn deinit(self: DisjointUnionSet) void {
    self.allocator.free(self.roots);
    self.allocator.free(self.sizes);
  }

  pub fn rootOf(self: DisjointUnionSet, i: usize) usize {
    std.debug.assert(i < self.n);

    var root = i;
    while (self.roots[root] != root) root = self.roots[root];
    
    var current = i;
    while (current != root) {
      const next = self.roots[current];
      self.roots[current] = root;
      current = next;
    }

    return root;
  }

  pub fn areJoined(self: DisjointUnionSet, i: usize, j: usize) bool {
    return self.rootOf(i) == self.rootOf(j);
  }

  pub fn join(self: DisjointUnionSet, i: usize, j: usize) bool {
    var rootI = self.rootOf(i);
    var rootJ = self.rootOf(j);
    if (rootI == rootJ) return false;

    if (self.sizes[rootI] < self.sizes[rootJ]) std.mem.swap(usize, &rootI, &rootJ);

    self.roots[rootJ] = rootI;
    self.sizes[rootI] += self.sizes[rootJ];
    self.sizes[rootJ] = 0;

    return true;
  }
};
