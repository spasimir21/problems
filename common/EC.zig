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

pub const QuestOptions = struct {
  year: usize,
  quest: usize,
  parts: []const PartOptions
};

fn problemsForQuestCount(comptime options: QuestOptions) usize {
  var count: usize = 0;
  for (options.parts) |part| count += if (part.@"test" != null) 2 else 1;
  return count;
}

pub fn problemsForQuest(comptime options: QuestOptions) [problemsForQuestCount(options)]Problem {
  var problems: [problemsForQuestCount(options)]Problem = undefined;

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
      .input = .{
        .path = std.fmt.comptimePrint("ec/{d}/quest-{d}-{d}.txt", .{ options.year, options.quest, n + 1 })
      },
      .expected = part.expected,
      .func = part.run
    };

    index += 1;
  }

  return Problem.group(
    .{
      .idPrefix = std.fmt.comptimePrint("quest-{d}-", .{ options.quest }),
      .namePrefix = std.fmt.comptimePrint("Quest {d}, ", .{ options.quest }),
      .tags = &.{ std.fmt.comptimePrint("quest-{d}", .{ options.quest }), }
    },
    .{ problems }
  );
}
