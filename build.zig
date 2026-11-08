const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});

  const common = b.createModule(.{
    .root_source_file = b.path("common/root.zig"),
    .target = target
  });

  const main = b.createModule(.{
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
    .imports = &.{ .{ .name = "common", .module = common } }
  });

  const config = b.addOptions();
  main.addOptions("config", config);

  config.addOption(
    []const u8,
    "staticTagsList",
    b.option(
      []const u8,
      "tags",
      "A comma-separated list of tags used to filter which problems are included in the build"
    ) orelse ""
  );

  config.addOption(
    []const u8,
    "inputRoot",
    b.option(
      []const u8,
      "inputRoot",
      "The path of the root input directory (default: ./inputs)"
    ) orelse "./inputs"
  );

  const exe = b.addExecutable(.{ .name = "problems", .root_module = main });

  b.installArtifact(exe);

  const run_cmd = b.addRunArtifact(exe);
  if (b.args) |args| run_cmd.addArgs(args);

  const run_step = b.step("run", "Run the app");
  run_cmd.step.dependOn(b.getInstallStep());
  run_step.dependOn(&run_cmd.step);

  const check_step = b.step("check", "Check if everything compiles");
  const check_exe = b.addExecutable(.{ .name = "problems_check", .root_module = main });
  check_step.dependOn(&check_exe.step);
}
