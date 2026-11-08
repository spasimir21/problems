const Problem = @import("common").Problem;
const std = @import("std");

const config = @import("config");

const problems = @import("./problems.zig").problems;

const Args = @This();

inputRoot: []const u8,
filter: Problem.Filter,
help: bool,

allocator: std.mem.Allocator,
argsIt: std.process.Args.Iterator,

pub fn init(rawArgs: std.process.Args, allocator: std.mem.Allocator) !Args {
  var requiredTags: std.ArrayList([]const u8) = .empty;
  defer requiredTags.deinit(allocator);

  var forbiddenTags: std.ArrayList([]const u8) = .empty;
  defer forbiddenTags.deinit(allocator);

  var inputRoot = config.inputRoot;
  var help: bool = false;

  var argsIt = try rawArgs.iterateAllocator(allocator);
  _ = argsIt.skip();

  while (argsIt.next()) |arg| {
    if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
      help = true;
      continue;
    }

    if (std.mem.startsWith(u8, arg, "--input-root=")) {
      inputRoot = arg[13..];
      continue;
    }

    if (arg[0] == '!') {
      try forbiddenTags.append(allocator, arg[1..]);
      continue;
    }

    try requiredTags.append(allocator, arg);
  }

  return .{
    .inputRoot = inputRoot,
    .filter = .{
      .forbiddenTags = try forbiddenTags.toOwnedSlice(allocator),
      .requiredTags = try requiredTags.toOwnedSlice(allocator),
    },
    .help = help,
    .allocator = allocator,
    .argsIt = argsIt
  };
}

pub fn deinit(self: *Args) void {
  self.allocator.free(self.filter.requiredTags);
  self.allocator.free(self.filter.forbiddenTags);
  self.argsIt.deinit();
}

pub fn printHelp(stdout: *std.Io.Writer, allocator: std.mem.Allocator) !void {
  var tagsSet: std.StringHashMap(void) = .init(allocator);
  defer tagsSet.deinit();

  for (problems) |problem| for (problem.tags) |tag| try tagsSet.put(tag, {});

  const tags: [][]const u8 = try allocator.alloc([]const u8, tagsSet.count());
  defer allocator.free(tags);

  var tagIt = tagsSet.keyIterator();
  var index: usize = 0;
  while (tagIt.next()) |tag| : (index += 1) tags[index] = tag.*;

  std.mem.sort([]const u8, tags, {}, struct {
    pub fn lessThan(ctx: void, a: []const u8, b: []const u8) bool {
      _ = ctx;
      return std.mem.order(u8, a, b) == .lt;
    }
  }.lessThan);

  try stdout.print(
    \\Usage: problems [...requiredTags] [...!forbiddenTags] [--input-root=ROOT, default: {s}] [--help/-h]
    \\
    \\Available problems [{d}]
    \\
    , .{ config.inputRoot, problems.len }
  );

  for (problems) |problem| try stdout.print("  - {s}\n", .{ problem.id });

  try stdout.print("\nAvailable tags [{d}]\n", .{ tags.len });
  for (tags) |tag| try stdout.print("  - {s}\n", .{ tag });

  try stdout.flush();
}
