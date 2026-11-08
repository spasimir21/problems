const Problem = @import("common").Problem;

pub const problems = Problem.group(
  .{
    .idPrefix = "aoc-",
    .namePrefix = "AOC ",
    .tags = &.{ "aoc" }
  },
  .{
    @import("./2025/problems.zig").problems
  }
);
