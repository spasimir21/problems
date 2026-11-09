const EC = @import("common").EC;
const std = @import("std");

const TEST_INPUTS = .{
  \\ISO-3210 7654
  \\ISO-8742 2468
  \\ISO-1111 1111
  ,
  \\ISO-3210 7654
  \\ISO-8742 2468
  \\ISO-1 1111
  \\ISO-13 777
  \\ISO-34 140856
  \\ISO-789 2465112
  \\ISO-2341 945
  ,
  \\ISO2-3 23
  \\ISO2-61 149
  \\ISO2-978 99
  \\ISO2-5887 5923
  \\ISO2-76988 123749
  \\ISO2-435657 929977
  \\ISO2-3949 870737
};

const ISO = struct {
  version: u2,
  bases: []const u8,
  digits: []const u8
};

const Input = struct {
  iter: std.mem.TokenIterator(u8, .any),

  pub fn init(source: []const u8) Input {
    return .{ .iter = std.mem.tokenizeAny(u8, source, "\r\n") };
  }

  pub fn next(self: *Input) ?ISO {
    const line = self.iter.next() orelse return null;

    const version: u2 = if (std.mem.startsWith(u8, line, "ISO2")) 2 else 1;
    var it = std.mem.splitScalar(u8, line, ' ');

    return .{
      .version = version,
      .bases = it.next().?[if (version == 2) 5 else 4..],
      .digits = it.next().?
    };
  }
};

const MAX_DIGITS = 8;

fn convertISO(iso: ISO) !?usize {
  var value: usize = 0;

  for (0..iso.digits.len) |i| {
    const base = iso.bases[iso.bases.len - 1 - (i % iso.bases.len)] - '0';
    value += (iso.digits[iso.digits.len - 1 - i] - '0') * try std.math.powi(usize, base, i);
  }

  if (iso.version == 2) {
    var digits: [8]u8 = undefined;

    for (1..try std.fmt.parseUnsigned(usize, iso.digits, 10)) |v| {
      if (try convertISO(.{
        .version = 1,
        .digits = digits[0..std.fmt.printInt(&digits, v, 10, .lower, .{})],
        .bases = iso.bases
      }) == value)
       return null;
    }
  }

  return value;
}

fn calculateTotal(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var total: usize = 0;
  while (input.next()) |iso| {
    if (try convertISO(iso)) |value| total += value;
  }

  return total;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 3,
  .parts = &.{
    .{ .run = &calculateTotal, .expected = 12277, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 1478 } },
    .{ .run = &calculateTotal, .expected = 18576986788, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 1161463 } },
    .{ .run = &calculateTotal, .expected = 278958, .@"test" = .{ .input = TEST_INPUTS[2], .expected = 50987 } }
  }
});
