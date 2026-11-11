const Problem = @import("common").Problem;

pub const problems = Problem.group(
  .{
    .idPrefix = "2026-",
    .namePrefix = "2026 ",
    .tags = &.{ "2026" }
  },
  .{
    @import("./quest-1.zig").problems,
    @import("./quest-2.zig").problems,
    @import("./quest-3.zig").problems,
    @import("./quest-4.zig").problems,
    @import("./quest-5.zig").problems,
    @import("./quest-6.zig").problems,
    @import("./quest-7.zig").problems,
    @import("./quest-8.zig").problems,
    @import("./quest-9.zig").problems,
    @import("./quest-10.zig").problems,
    @import("./quest-11.zig").problems
  }
);
