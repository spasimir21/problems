const Problem = @import("./Problem.zig");
const std = @import("std");

pub const TestOptions = struct {
  run: ?Problem.Func = null,
  expected: usize,
  input: []const u8
};

pub const PartOptions = struct {
  run: Problem.Func,
  expected: ?usize = null,
  @"test": ?TestOptions = null
};

pub const DayOptions = struct {
  year: usize,
  day: usize,
  parts: []const PartOptions
};

const FetchContext = struct { year: usize, day: usize };

fn fetchInput(
  opaqueContext: *const anyopaque,
  secrets: *const std.StringHashMap([]const u8),
  io: std.Io,
  allocator: std.mem.Allocator
) ![]const u8 {
  const context: *const FetchContext = @ptrCast(@alignCast(opaqueContext));

  const url = try std.fmt.allocPrint(allocator, "https://adventofcode.com/{d}/day/{d}/input", .{ context.year, context.day });
  defer allocator.free(url);

  const cookie = try std.fmt.allocPrint(allocator, "session={s}", .{ secrets.get("AOC_SESSION") orelse return error.MissingSecret });
  defer allocator.free(cookie);

  var client: std.http.Client = .{ .allocator = allocator, .io = io };
  defer client.deinit();

  var response: std.Io.Writer.Allocating = .init(allocator);
  defer response.deinit();

  const result = try client.fetch(.{
    .location = .{ .url = url },
    .method = .GET,
    .headers = .{ .user_agent = .{ .override = "curl/8.0.0" } },
    .extra_headers = &.{ .{ .name = "Cookie", .value = cookie } },
    .response_writer = &response.writer
  });

  return if (result.status == .ok) response.toOwnedSlice() else error.FailedRequest;
}

fn problemsForDayCount(comptime options: DayOptions) usize {
  var count: usize = 0;
  for (options.parts) |part| count += if (part.@"test" != null) 2 else 1;
  return count;
}

pub fn problemsForDay(comptime options: DayOptions) [problemsForDayCount(options)]Problem {
  const input: Problem.Input = .{ .path = std.fmt.comptimePrint("aoc/{d}/day-{d}.txt", .{ options.year, options.day }) };
  var problems: [problemsForDayCount(options)]Problem = undefined;

  var index: usize = 0;
  for (options.parts, 0..options.parts.len) |part, n| {
    const partName = std.fmt.comptimePrint("Part {d}", .{ n + 1 });
    const partId = std.fmt.comptimePrint("part-{d}", .{ n + 1 });

    if (part.@"test") |t| {
      problems[index] = .{
        .id = partId ++ "-test",
        .name = partName ++ ", Test",
        .tags = &.{ partId, "test" },
        .input = .{ .literal = t.input },
        .expected = t.expected,
        .func = t.run orelse part.run
      };

      index += 1;
    }

    problems[index] = .{
      .id = partId,
      .name = partName,
      .tags = &.{ partId },
      .input = input,
      .expected = part.expected,
      .func = part.run,
      .fetch = .{
        .context = &FetchContext { .year = options.year, .day = options.day },
        .func = &fetchInput
      }
    };

    index += 1;
  }

  return Problem.group(
    .{
      .idPrefix = std.fmt.comptimePrint("day-{d}-", .{ options.day }),
      .namePrefix = std.fmt.comptimePrint("Day {d}, ", .{ options.day }),
      .tags = &.{ std.fmt.comptimePrint("day-{d}", .{ options.day }), }
    },
    .{ problems }
  );
}
