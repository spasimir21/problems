const config = @import("config");
const common = @import("common");
const std = @import("std");

const errors = @import("./errors.zig");

const Problem = common.Problem;

const problems = @import("./problems.zig").problems;

const CLI = common.CLI.ArgumentParser("problems", "[...tags] [...!tags]", &.{
  .{
    .name = "help",
    .kind = .Flag,
    .shortName = "h",
    .description = "Displays this help screen."
  },
  .{
    .name = "list",
    .kind = .Flag,
    .shortName = "l",
    .description = "Lists all available problems and tags."
  },
  .{
    .name = "fetch-inputs",
    .kind = .Flag,
    .shortName = "f",
    .description = "Fetches the needed inputs before running the problems."
  },
  .{
    .name = "secrets",
    .kind = .Value,
    .description = "The path of a .env file with secrets for fetching inputs.",
    .default = ".env"
  },
  .{
    .name = "inputs-root",
    .kind = .Value,
    .description = "The root directory of all problem inputs.",
    .default = config.inputsRoot
  }
});

fn parseFilter(tags: []const []const u8, allocator: std.mem.Allocator) !Problem.Filter {
  var forbiddenCount: usize = 0;
  var requiredCount: usize = 0;
  for (tags) |tag| {
    if (std.mem.startsWith(u8, tag, "!")) forbiddenCount += 1
    else requiredCount += 1;
  }

  const forbiddenTags = try allocator.alloc([]const u8, forbiddenCount);
  const requiredTags = try allocator.alloc([]const u8, requiredCount);

  forbiddenCount = 0;
  requiredCount = 0;
  for (tags) |tag| {
    if (std.mem.startsWith(u8, tag, "!")) {
      forbiddenTags[forbiddenCount] = tag[1..];
      forbiddenCount += 1;
    } else {
      requiredTags[requiredCount] = tag;
      requiredCount += 1;
    }
  }

  return .{ .forbiddenTags = forbiddenTags, .requiredTags = requiredTags };
}

fn listProblemsAndTags(stdout: *std.Io.Writer, allocator: std.mem.Allocator) !void {
  try stdout.print("Problems ({d}):\n", .{ problems.len });
  for (problems) |problem| try stdout.print("  - {s}\n", .{ problem.id });

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

  try stdout.print("\nTags ({d}):\n", .{ tags.len });
  for (tags) |tag| try stdout.print("  - {s}\n", .{ tag });

  try stdout.flush();
}

fn readSecrets(
  secrets: *std.StringHashMap([]const u8),
  secretsPath: []const u8,
  io: std.Io,
  allocator: std.mem.Allocator,
) ![]const u8 {
  const secretsSource = try std.Io.Dir.cwd().readFileAlloc(io, secretsPath, allocator, .unlimited);
  errdefer allocator.free(secretsSource);

  var lineIt = std.mem.tokenizeAny(u8, secretsSource, "\r\n");
  while (lineIt.next()) |line| {
    const equalsIndex = std.mem.findScalar(u8, line, '=').?;

    try secrets.put(
      std.mem.trim(u8, line[0..equalsIndex], " \t"),
      std.mem.trim(u8, line[equalsIndex + 1..], " \t")
    );
  }

  return secretsSource;
}

fn fetchInputs(
  inputsRoot: []const u8,
  filter: Problem.Filter,
  secrets: *const std.StringHashMap([]const u8),
  io: std.Io,
  allocator: std.mem.Allocator,
  stdout: *std.Io.Writer,
) !void {
  var problemsWithoutInput: std.StringHashMap(Problem) = .init(allocator);
  defer problemsWithoutInput.deinit();

  const cwd: std.Io.Dir = .cwd();

  for (problems) |problem| {
    if (!problem.testFilter(filter) or problem.input != .path or problem.fetch == null) continue;

    const inputPath = try std.fs.path.join(allocator, &.{ inputsRoot, problem.input.path });
    defer allocator.free(inputPath);

    const stat = cwd.statFile(io, inputPath, .{}) catch null;
    if (stat != null) continue;

    try problemsWithoutInput.put(problem.input.path, problem);
  }

  const startTime: std.Io.Timestamp = .now(io, .boot);

  var it = problemsWithoutInput.valueIterator();
  var n: usize = 1;
  while (it.next()) |problem| : (n += 1) {
    const inputPath = try std.fs.path.join(allocator, &.{ inputsRoot, problem.input.path });
    defer allocator.free(inputPath);

    try stdout.print(
      "\x1b[0G\x1b[2K\x1b[94m[\x1b[5m*\x1b[25m]\x1b[0m \x1b[1mFetching inputs (\x1b[33m{d}/{d}\x1b[39m)...\x1b[0m",
      .{ n, problemsWithoutInput.count() }
    );
    try stdout.flush();

    const fetch = problem.fetch.?;

    const input = try fetch.func(fetch.context, secrets, io, allocator);
    defer allocator.free(input);

    if (std.fs.path.dirname(inputPath)) |dirname| try cwd.createDirPath(io, dirname);
    try cwd.writeFile(io, .{ .sub_path = inputPath, .data = input });

    try io.sleep(.fromMilliseconds(100), .boot);
  }

  try stdout.writeAll("\x1b[0G\x1b[2K");
  if (problemsWithoutInput.count() == 0) return;

  try stdout.print(
    "\x1b[92m[+]\x1b[0m \x1b[1mFetched \x1b[33m{d}\x1b[39m input(s) \x1b[0;2m({d} ms)\x1b[0m\n",
    .{ problemsWithoutInput.count(), startTime.durationTo(.now(io, .boot)).toMilliseconds() }
  );
  try stdout.flush();
}

fn appMain(init: std.process.Init) !void {
  const stdoutFile: std.Io.File = .stdout();
  defer stdoutFile.close(init.io);

  var stdoutBuffer: [4 * 1024]u8 = undefined;
  var stdout = stdoutFile.writer(init.io, &stdoutBuffer);
  defer stdout.interface.flush() catch {};
  
  var args: CLI.Arguments = try CLI.parseArguments(init.minimal.args, init.gpa);
  defer CLI.deinitArguments(&args);

  if (args.help) {
    try stdout.interface.writeAll(CLI.HELP_MESSAGE);
    return;
  }

  if (args.list) {
    try listProblemsAndTags(&stdout.interface, init.gpa);
    return;
  }

  const filter = try parseFilter(args.positional, init.gpa);
  defer filter.free(init.gpa);

  if (args.@"fetch-inputs") {
    var secrets: std.StringHashMap([]const u8) = .init(init.gpa);
    defer secrets.deinit();

    const secretsSource = readSecrets(&secrets, args.secrets, init.io, init.gpa) catch |err| switch (err) {
      error.FileNotFound => return error.MissingSecretsFile,
      else => return err
    };
    defer init.gpa.free(secretsSource);
    
    try fetchInputs(args.@"inputs-root", filter, &secrets, init.io, init.gpa, &stdout.interface);
  }

  var totalDuration: std.Io.Duration = .zero;
  var correct: usize = 0;
  var incorrect: usize = 0;
  var unknown: usize = 0;

  for (problems) |problem| {
    if (!problem.testFilter(filter)) continue;

    const result = try problem.run(args.@"inputs-root", &stdout.interface, init.io, init.gpa);

    totalDuration.nanoseconds += result.duration.nanoseconds;
    switch (result.status) {
      .Correct => correct += 1,
      .Incorrect => incorrect += 1,
      .Unknown => unknown += 1
    }
  }

  const total = correct + incorrect + unknown;

  try stdout.interface.print(
    "\x1b[3m{s}\x1b[0m \x1b[1m{d}/{d}\x1b[0m problems ran: \x1b[{s}32m{d} correct\x1b[0m, \x1b[{s}31m{d} incorrect\x1b[0m, \x1b[{s}33m{d} unknown\x1b[0m, \x1b[2min {d} ms\x1b[0m\n",
    .{
      if (total == problems.len) "All" else "Only",
      total,
      problems.len,
      if (correct == 0) "2;" else "",
      correct,
      if (incorrect == 0) "2;" else "",
      incorrect,
      if (unknown == 0) "2;" else "",
      unknown,
      totalDuration.toMilliseconds()
    }
  );
}

pub fn main(init: std.process.Init) !void {
  const result = appMain(init);

  if (result) {}
  else |err| std.debug.print("\x1b[0G\x1b[2K\x1b[31mError: {s}\x1b[0m\n", .{ errors.getErrorMessage(err) orelse return err });
}
