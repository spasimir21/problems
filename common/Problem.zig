const std = @import("std");

const Problem = @This();

pub const Input = union (enum) {
  literal: []const u8,
  path: []const u8
};

pub const Func = *const fn([]const u8, std.mem.Allocator) anyerror!usize;

id: []const u8,
name: []const u8,
tags: []const []const u8,
input: Input,
func: Func,
expected: ?usize = null,

pub const GroupOptions = struct {
  tags: []const []const u8 = &.{},
  idPrefix: []const u8 = "",
  namePrefix: []const u8 = ""
};

fn totalProblemCount(comptime problemLists: anytype) usize {
  var count: usize = 0;
  for (0..@typeInfo(@TypeOf(problemLists)).@"struct".fields.len) |i| count += problemLists[i].len;
  return count;
}

pub fn group(comptime options: GroupOptions, comptime problemLists: anytype) [totalProblemCount(problemLists)]Problem {
  var problems: [totalProblemCount(problemLists)]Problem = undefined;

  var index: usize = 0;
  for (0..@typeInfo(@TypeOf(problemLists)).@"struct".fields.len) |problemListIndex|
    for (problemLists[problemListIndex]) |problem| {
      var newTags: [options.tags.len + problem.tags.len][]const u8 = undefined;
      for (0..options.tags.len) |i| newTags[i] = options.tags[i];
      for (0..problem.tags.len) |i| newTags[options.tags.len + i] = problem.tags[i];

      const newTagsConst = newTags;

      problems[index] = .{
        .id = options.idPrefix ++ problem.id,
        .name = options.namePrefix ++ problem.name,
        .tags = &newTagsConst,
        .input = problem.input,
        .func = problem.func,
        .expected = problem.expected
      };

      index += 1;
    };

  return problems;
}

pub const Filter = struct {
  requiredTags: []const []const u8,
  forbiddenTags: []const []const u8
};

pub fn testFilter(self: Problem, filter: Filter) bool {
  @setEvalBranchQuota(1_000_000);

  for (filter.requiredTags) |requiredTag|
    if (std.mem.eql(u8, self.id, requiredTag)) return true;

  for (filter.forbiddenTags) |forbiddenTag| {
    if (std.mem.eql(u8, self.id, forbiddenTag)) return false;

    for (self.tags) |tag|
      if (std.mem.eql(u8, tag, forbiddenTag)) return false;
  }

  for (filter.requiredTags) |requiredTag| {
    for (self.tags) |tag| {
      if (std.mem.eql(u8, tag, requiredTag)) break;
    } else return false;
  }

  return true;
}

pub const Status = enum { Correct, Incorrect, Unknown };

pub const Result = struct {
  result: anyerror!usize,
  duration: std.Io.Duration,
  status: Status
};

fn getInput(
  input: Input,
  inputRoot: []const u8,
  io: std.Io,
  allocator: std.mem.Allocator
) ![]const u8 {
  if (input == .literal) return input.literal;

  const path = try std.fs.path.join(allocator, &.{ inputRoot, input.path });
  defer allocator.free(path);

  const file = try std.Io.Dir.cwd().openFile(io, path, .{});
  defer file.close(io);

  var readBuffer: [4 * 1024]u8 = undefined;
  var reader = file.reader(io, &readBuffer);

  return reader.interface.allocRemaining(allocator, .unlimited);
}

pub fn run(
  self: Problem,
  inputRoot: []const u8,
  stdout: *std.Io.Writer,
  io: std.Io,
  allocator: std.mem.Allocator
) !Result {
  const input = try getInput(self.input, inputRoot, io, allocator);
  defer if (self.input == .path) allocator.free(input);

  const startTime: std.Io.Timestamp = .now(io, .boot);
  const result = self.func(input, allocator);
  const duration = startTime.durationTo(.now(io, .boot));

  const status: Status =
    if (result) |value|
      (if (self.expected) |expected|
        (if (value == expected) .Correct else .Incorrect)
        else .Unknown)
    else |_| .Incorrect;

  try stdout.print("\x1b[1m{s}\x1b[0m: \x1b[33m{?d}\x1b[0m \x1b[2m(", .{ self.name, result catch null });

  switch (status) {
    .Correct => try stdout.writeAll("\x1b[32mCorrect\x1b[39m"),
    .Incorrect => {
      if (result) |_| try stdout.print("\x1b[31mIncorrect: expected {d}\x1b[39m", .{ self.expected.? })
      else |err| try stdout.print("\x1b[31mError: {t}\x1b[39m", .{ err });
    },
    .Unknown => try stdout.writeAll("\x1b[33mUnknown\x1b[39m"),
  }

  try stdout.print(", {d}ms)\x1b[0m\n", .{ duration.toMilliseconds() });
  try stdout.flush();

  return .{
    .result = result,
    .duration = duration,
    .status = status
  };
}

fn comptimeFilterCount(comptime problems: anytype, comptime filter: Filter) usize {
  var count: usize = 0;
  for (problems) |problem| {
    if (problem.testFilter(filter)) count += 1;
  }
  return count;
}

pub fn comptimeFilter(comptime problems: anytype, comptime filter: Filter) [comptimeFilterCount(problems, filter)]Problem { 
  var filteredProblems: [comptimeFilterCount(problems, filter)]Problem = undefined;
  var index: usize = 0;
  for (problems) |problem| {
    if (!problem.testFilter(filter)) continue;
    filteredProblems[index] = problem;
    index += 1;
  }
  return filteredProblems;
}
