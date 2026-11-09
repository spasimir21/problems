const Problem = @import("common").Problem;
const std = @import("std");

const Args = @import("./args.zig");

const problems = @import("./problems.zig").problems;

pub fn main(init: std.process.Init) !void {
  const stdoutFile: std.Io.File = .stdout();
  defer stdoutFile.close(init.io);

  var stdoutBuffer: [4 * 1024]u8 = undefined;
  var stdout = stdoutFile.writer(init.io, &stdoutBuffer);
  defer stdout.interface.flush() catch {};

  var args: Args = try .init(init.minimal.args, init.gpa);
  defer args.deinit();

  if (args.help) return Args.printHelp(&stdout.interface, init.gpa);

  var totalDuration: std.Io.Duration = .zero;
  var correct: usize = 0;
  var incorrect: usize = 0;
  var unknown: usize = 0;

  for (problems) |problem| {
    if (!problem.testFilter(args.filter)) continue;

    const result = try problem.run(args.inputRoot, &stdout.interface, init.io, init.gpa);

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
