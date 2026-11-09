const common = @import("common");
const std = @import("std");

const Problem = common.Problem;
const EC = common.EC;

const TEST_INPUTS = .{
  \\4<3 2<5 3>1 1>2 1<5 4<1 3>2 4<2 3>5 4<5
  \\4>1 2>1 3>2 1<5 4>5 2<5 3>1 4>3 2<4 5<3
  \\5>1 5>2 4>1 2<4 3>2 3<4 1>2 3>5 1<3 4>5
  ,
  \\2<5 3>1 1>2 1<5 4<1 3>2 4<2 3>5 4<5
  \\2>1 3>2 1<5 4>5 2<5 3>1 4>3 2<4 5<3
  \\5>1 5>2 4>1 3>2 3<4 1>2 3>5 1<3 4>5
  ,
  \\3>1 1>2 1<5 4<2 3>5
  \\2>1 2<5 3>1 4>3 2<4 5<3
  \\5>1 3<4 1>2 3>5
};

const Order = struct { u8, u8 };

const Input = struct {
  orders: std.ArrayList(Order) = .empty,

  iter: std.mem.TokenIterator(u8, .any),
  allocator: std.mem.Allocator,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) Input {
    return .{
      .iter = std.mem.tokenizeAny(u8, source, "\r\n"),
      .allocator = allocator
    };
  }

  pub fn deinit(self: *Input) void {
    self.orders.deinit(self.allocator);
  }

  pub fn next(self: *Input) !?[]const Order {
    const line = self.iter.next() orelse return null;
    self.orders.clearRetainingCapacity();

    var it = std.mem.splitScalar(u8, line, ' ');
    while (it.next()) |order| {
      const lhs = order[0] - '0';
      const rhs = order[2] - '0';

      try self.orders.append(
        self.allocator,
        if (order[1] == '>') .{ lhs, rhs } else .{ rhs, lhs }
      );
    }

    return self.orders.items;
  }
};

const MAX_ALLOYS = 9;

fn calculateChecksum(orders: []const Order) usize {
  var alloys: [MAX_ALLOYS]u8 = undefined;
  for (0..MAX_ALLOYS) |i| alloys[i] = @intCast(i + 1);

  while (true)
    for (orders) |order| {
      const aIndex = std.mem.findScalar(u8, &alloys, order[0]).?;
      const bIndex = std.mem.findScalar(u8, &alloys, order[1]).?;
      if (aIndex < bIndex) continue;

      @memmove(alloys[bIndex..aIndex], alloys[bIndex + 1..aIndex + 1]);
      alloys[aIndex] = order[1];

      break;
    } else break;

  var maxAlloy: u8 = 0;
  for (orders) |order| {
    if (order[0] > maxAlloy) maxAlloy = order[0];
    if (order[1] > maxAlloy) maxAlloy = order[1];
  }

  var checksum: usize = 0;
  for (0..maxAlloy) |i| checksum = checksum * 10 + alloys[i];

  return checksum;
}

fn calculateTotalChecksum(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = .init(rawInput, allocator);
  defer input.deinit();

  var totalChecksum: usize = 0;
  while (try input.next()) |orders| totalChecksum += calculateChecksum(orders);

  return totalChecksum;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 2,
  .parts = &.{
    .{ .run = &calculateTotalChecksum, .expected = 459402, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 122157 } },
    .{ .run = &calculateTotalChecksum, .expected = 62309369142, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 122157 } },
    .{ .run = &calculateTotalChecksum, .expected = 598283942139, .@"test" = .{ .input = TEST_INPUTS[2], .expected = 122157 } }
  }
});
