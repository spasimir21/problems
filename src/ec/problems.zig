const Problem = @import("common").Problem;

pub const problems = Problem.group(
  .{
    .idPrefix = "ec-",
    .namePrefix = "EC ",
    .tags = &.{ "ec" }
  },
  .{
    @import("./2026/problems.zig").problems
  }
);
