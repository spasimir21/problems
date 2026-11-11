const EC = @import("common").EC;
const std = @import("std");

const TEST_INPUTS = .{
  \\BRDS:FLWR,SLTT,YSTS
  \\FLWR:SLTT,YSTS
  \\SLTT:YSTS,MLKK,BTTR
  \\NULL:BRDS,FLWR,SLTT
  \\YSTS:BRDS,FLWR
  \\MLKK:SPCS,NULL
  \\HNYN:BRDS,FLWR,SLTT,YSTS
  ,
  \\MEAL:BRDS,CAKE,DOUG
  \\BRDS:DOUG,FLWR
  \\CAKE:DOUG,FLWR,NULLv2,NULLv3
  \\DOUG:FLWR,YSTS,SLTT,NULLv1
  \\FLWR:BRDS,DOUG
  \\YSTS:SPCS
  \\SOUP:BRDS,CAKE,DOUG,FLWR
};

const Input = struct {
  source: []const u8,

  iter: std.mem.TokenIterator(u8, .any),

  pub fn init(source: []const u8) Input {
    return .{ .source = source, .iter = std.mem.tokenizeAny(u8, source, "\r\n") };
  }

  pub fn getIngredients(self: Input, name: [4]u8) ?std.mem.SplitIterator(u8, .scalar) {
    const startIndex = std.mem.find(u8, self.source, &.{ name[0], name[1], name[2], name[3], ':' }) orelse return null;
    var ingredients = self.source[startIndex + 5..];

    const endIndex = std.mem.findAny(u8, ingredients, "\r\n") orelse ingredients.len;
    ingredients = ingredients[0..endIndex];

    return std.mem.splitScalar(u8, ingredients, ',');
  }

  pub fn next(self: *Input) ?[]const u8 {
    const line = self.iter.next() orelse return null;
    return line[0..4];
  }
};

fn getIngredientsOf(name: []const u8, input: *const Input, seen: *std.StringHashMap(void)) !void {
  if (seen.contains(name)) return;
  try seen.put(name, {});

  var ingredients = input.getIngredients(name[0..4].*) orelse return;
  while (ingredients.next()) |ingredient| try getIngredientsOf(ingredient, input, seen);
}

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  const input: Input = .init(rawInput);

  var seen: std.StringHashMap(void) = .init(allocator);
  defer seen.deinit();

  try getIngredientsOf("NULL", &input, &seen);
  return seen.count() -| 1;
}

fn usesNull(name: []const u8, input: *const Input, seen: *std.StringHashMap(void), cache: *std.StringHashMap(bool)) !bool {
  if (std.mem.eql(u8, name, "NULL")) return true;
  if (cache.get(name)) |value| return value;

  if (seen.contains(name)) return false;
  try seen.put(name, {});

  var ingredients = input.getIngredients(name[0..4].*) orelse return false;
  while (ingredients.next()) |ingredient|
    if (try usesNull(ingredient, input, seen, cache)) {
      try cache.put(name, true);
      return true;
    };

  return false;
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput);

  var cache: std.StringHashMap(bool) = .init(allocator);
  defer cache.deinit();

  var seen: std.StringHashMap(void) = .init(allocator);
  defer seen.deinit();

  var total: usize = 0;
  while (input.next()) |ingredient| {
    if (std.mem.eql(u8, ingredient, "NULL")) continue;

    seen.clearRetainingCapacity();
    const doesUseNull = try usesNull(ingredient, &input, &seen, &cache);

    try cache.put(ingredient, doesUseNull);
    if (doesUseNull) total += 1;
  }

  return total;
}

const Nulls = [3]bool;

fn usesNulls(name: []const u8, input: *const Input, seen: *std.StringHashMap(void), cache: *std.StringHashMap(Nulls)) !Nulls {
  if (std.mem.startsWith(u8, name, "NULLv")) return switch (name[5]) {
    '1' => .{ true, false, false },
    '2' => .{ false, true, false },
    '3' => .{ false, false, true },
    else => unreachable
  };

  if (cache.get(name)) |value| return value;

  if (seen.contains(name)) return @splat(false);
  try seen.put(name, {});

  var nulls: Nulls = @splat(false);

  var ingredients = input.getIngredients(name[0..4].*) orelse return @splat(false);
  while (ingredients.next()) |ingredient| {
    const ingredientNulls = try usesNulls(ingredient, input, seen, cache);
    for (0..nulls.len) |i| nulls[i] |= ingredientNulls[i];

    if (std.mem.countScalar(bool, &nulls, true) >= 2) {
      try cache.put(name, nulls);
      return nulls;
    }
  }

  return nulls;
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput);

  var cache: std.StringHashMap(Nulls) = .init(allocator);
  defer cache.deinit();

  var seen: std.StringHashMap(void) = .init(allocator);
  defer seen.deinit();

  var total: usize = 0;
  while (input.next()) |ingredient| {
    if (std.mem.startsWith(u8, ingredient, "NULLv")) continue;

    seen.clearRetainingCapacity();
    const nulls = try usesNulls(ingredient, &input, &seen, &cache);

    try cache.put(ingredient, nulls);
    if (std.mem.countScalar(bool, &nulls, true) >= 2) total += 1;
  }

  return total;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 6,
  .parts = &.{
    .{ .run = &part1, .expected = 48, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 7 } },
    .{ .run = &part2, .expected = 818, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 6 } },
    .{ .run = &part3, .expected = 1631, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 3 } }
  }
});
