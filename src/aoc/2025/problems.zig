const Problem = @import("common").Problem;

pub const problems = Problem.group(
  .{
    .idPrefix = "2025-",
    .namePrefix = "2025 ",
    .tags = &.{ "2025" }
  },
  .{
    @import("./day-1.zig").problems,
    @import("./day-2.zig").problems,
    @import("./day-3.zig").problems,
    @import("./day-4.zig").problems,
    @import("./day-5.zig").problems,
    @import("./day-6.zig").problems,
    @import("./day-7.zig").problems,
    @import("./day-8.zig").problems,
    @import("./day-9.zig").problems,
    @import("./day-10.zig").problems,
    @import("./day-11.zig").problems,
    @import("./day-12.zig").problems
  }
);
