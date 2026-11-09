const EC = @import("common").EC;
const std = @import("std");

const TEST_INPUTS = .{
  \\id=1 quest=1 part=1 time=187
  \\id=3 quest=1 part=1 time=413
  \\id=5 quest=1 part=3 time=744
  \\id=2 quest=1 part=3 time=745
  \\id=4 quest=1 part=2 time=558
  \\id=1 quest=1 part=2 time=299
  \\id=1 quest=1 part=3 time=362
  \\id=4 quest=1 part=3 time=1268
  \\id=4 quest=1 part=1 time=457
  \\id=5 quest=1 part=1 time=257
  \\id=2 quest=1 part=1 time=192
  \\id=3 quest=1 part=3 time=1168
  \\id=5 quest=1 part=2 time=346
  \\id=3 quest=1 part=2 time=455
  \\id=2 quest=1 part=2 time=562
  ,
  \\id=2 quest=1 part=1 time=100
  \\id=4 quest=2 part=1 time=150
  \\id=1 quest=2 part=1 time=140
  \\id=1 quest=1 part=2 time=180
  \\id=2 quest=2 part=1 time=130
  \\id=4 quest=1 part=1 time=110
  \\id=1 quest=2 part=2 time=210
  \\id=2 quest=2 part=2 time=240
  \\id=1 quest=2 part=3 time=330
  \\id=2 quest=1 part=2 time=170
  \\id=3 quest=1 part=1 time=90
  \\id=4 quest=1 part=2 time=175
  \\id=3 quest=2 part=1 time=120
  \\id=1 quest=1 part=1 time=120
  \\id=3 quest=2 part=2 time=220
  \\id=2 quest=2 part=3 time=350
  \\id=3 quest=1 part=2 time=160
  ,
  \\id=2 quest=1 part=1 time=90
  \\id=4 quest=2 part=1 time=150
  \\id=1 quest=2 part=1 time=130
  \\id=1 quest=1 part=2 time=180
  \\id=2 quest=2 part=1 time=130
  \\id=4 quest=1 part=1 time=110
  \\id=1 quest=2 part=2 time=210
  \\id=2 quest=2 part=2 time=220
  \\id=1 quest=2 part=3 time=330
  \\id=2 quest=1 part=2 time=170
  \\id=3 quest=1 part=1 time=90
  \\id=4 quest=1 part=2 time=170
  \\id=3 quest=2 part=1 time=120
  \\id=1 quest=1 part=1 time=120
  \\id=3 quest=2 part=2 time=220
  \\id=2 quest=2 part=3 time=350
  \\id=3 quest=1 part=2 time=170
};

const Record = struct {
  id: usize,
  quest: usize,
  part: usize,
  time: usize
};

const Input = struct {
  iter: std.mem.TokenIterator(u8, .any),

  pub fn init(source: []const u8) Input {
    return .{ .iter = std.mem.tokenizeAny(u8, source, "\r\n") };
  }

  fn parseProperty(property: []const u8) !usize {
    return std.fmt.parseUnsigned(usize, property[std.mem.findScalar(u8, property, '=').? + 1..], 10);
  }

  pub fn next(self: *Input) !?Record {
    const line = self.iter.next() orelse return null;
    var it = std.mem.splitScalar(u8, line, ' ');

    return .{
      .id = try parseProperty(it.next().?),
      .quest = try parseProperty(it.next().?),
      .part = try parseProperty(it.next().?),
      .time = try parseProperty(it.next().?)
    };
  }

  pub fn reset(self: *Input) void {
    self.iter.reset();
  }
};

const MAX_ID = 256;

fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var times: [MAX_ID]usize = @splat(0);
  var nPeople: usize = 0;

  while (try input.next()) |record| {
    if (record.id > nPeople) nPeople = record.id;
    times[record.id - 1] += record.time;
  }

  std.sort.block(usize, times[0..nPeople], {}, std.sort.asc(usize));

  var total: usize = 0;
  for (0..nPeople) |i| total += (i + 1) * times[i];

  return total;
}

const Person = struct {
  id: usize = 0,
  parts: usize = 0,
  time: usize = 0,

  pub fn lessThan(ctx: void, a: Person, b: Person) bool {
    _ = ctx;
    if (a.parts == b.parts) return a.time < b.time;
    return a.parts > b.parts;
  }
};

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var people: [MAX_ID]Person = @splat(.{});
  var nPeople: usize = 0;

  while (try input.next()) |record| {
    if (record.id > nPeople) nPeople = record.id;
    var person = &people[record.id - 1];

    person.id = record.id;
    person.parts += 1;
    person.time += record.time;
  }

  std.mem.sort(Person, people[0..nPeople], {}, Person.lessThan);

  var total: usize = 0;
  for (0..nPeople) |i| total += (i + 1) * people[i].time;

  return total;
}

fn updateScores(input: *Input, scores: []usize, quest: usize, part: usize) !usize {
  input.reset();

  var people: [MAX_ID]Person = @splat(.{});
  var nPeople: usize = 0;

  while (try input.next()) |record| {
    if (record.quest != quest or record.part > part) continue;

    if (record.id > nPeople) nPeople = record.id;
    var person = &people[record.id - 1];

    person.id = record.id;
    person.parts += 1;
    person.time += record.time;
  }

  var nPlayed: usize = 0;
  for (0..nPeople) |i| {
    if (people[i].parts != part) continue;
    people[nPlayed] = people[i];
    nPlayed += 1;
  }

  if (nPlayed == 0) return 0;

  std.mem.sort(Person, people[0..nPlayed], {}, Person.lessThan);

  const maxPoints: usize = part * 50;

  var place: usize = 0;
  for (0..nPlayed) |i| {
    if (i > 0 and people[i - 1].time != people[i].time) place = i;
    scores[people[i].id - 1] += maxPoints -| place;
  }

  return nPlayed;
}

fn part3(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  _ = allocator;

  var input: Input = .init(rawInput);

  var scores: [MAX_ID]usize = @splat(0);

  var quest: usize = 1;
  while (true) : (quest += 1) {
    var nPlayed: usize = 0;
    for (0..3) |part| nPlayed += try updateScores(&input, &scores, quest, part + 1);
    if (nPlayed == 0) break;
  }

  std.sort.block(usize, &scores, {}, std.sort.desc(usize));

  var total: usize = 0;
  var place: usize = 0;
  for (0..scores.len) |i| {
    if (i > 0 and scores[i - 1] != scores[i]) place = i;
    total += (place + 1) * scores[i];
  }

  return total;
}

pub const problems = EC.problemsForQuest(.{
  .year = 2026,
  .quest = 4,
  .parts = &.{
    .{ .run = &part1, .expected = 216326, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 27598 } },
    .{ .run = &part2, .expected = 598388747, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 6470 } },
    .{ .run = &part3, .expected = 6622162, .@"test" = .{ .input = TEST_INPUTS[2], .expected = 3004 } }
  }
});
