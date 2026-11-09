const Problem = @import("common").Problem;
const std = @import("std");

const config = @import("config");

const allProblems = Problem.group(
  .{},
  .{
    @import("./aoc/problems.zig").problems,
    @import("./ec/problems.zig").problems
  }
);

pub const problems = problems: {
  var forbiddenCount: usize = 0;
  var requiredCount: usize = 0;

  var commaIt = std.mem.splitScalar(u8, config.staticTagsList, ',');

  while (commaIt.next()) |tag| {
    if (tag.len == 0) continue;

    if (tag[0] == '!') {
      forbiddenCount += 1;
      continue;
    }

    requiredCount += 1;
  }

  var forbiddenTags: [forbiddenCount][]const u8 = undefined;
  var requiredTags: [requiredCount][]const u8 = undefined;

  commaIt = std.mem.splitScalar(u8, config.staticTagsList, ',');
  forbiddenCount = 0;
  requiredCount = 0;
  while (commaIt.next()) |tag| {
    if (tag.len == 0) continue;

    if (tag[0] == '!') {
      forbiddenTags[forbiddenCount] = tag[1..];
      forbiddenCount += 1;
      continue;
    }

    requiredTags[requiredCount] = tag;
    requiredCount += 1;
  }

  break :problems Problem.comptimeFilter(
    allProblems,
    .{ .forbiddenTags = &forbiddenTags, .requiredTags = &requiredTags }
  );
};
