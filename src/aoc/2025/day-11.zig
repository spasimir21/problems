const AOC = @import("common").AOC;
const std = @import("std");

const TEST_INPUTS = .{
  \\aaa: you hhh
  \\you: bbb ccc
  \\bbb: ddd eee
  \\ccc: ddd eee fff
  \\ddd: ggg
  \\eee: out
  \\fff: out
  \\ggg: out
  \\hhh: ccc fff iii
  \\iii: out
  ,
  \\svr: aaa bbb
  \\aaa: fft
  \\fft: ccc
  \\bbb: tty
  \\tty: ccc
  \\ccc: ddd eee
  \\ddd: hub
  \\hub: fff
  \\eee: dac
  \\dac: fff
  \\fff: ggg hhh
  \\ggg: out
  \\hhh: out
};

const Connections = []const usize;
const Graph = []const ?Connections;

pub const Input = struct {
  arena: std.heap.ArenaAllocator,
  graph: Graph,

  you: ?usize,
  svr: ?usize,
  dac: ?usize,
  fft: ?usize,
  out: ?usize,

  pub fn init(source: []const u8, allocator: std.mem.Allocator) !Input {
    var graph: std.ArrayList(?Connections) = .empty;
    defer graph.deinit(allocator);

    var ids: std.StringHashMap(usize) = .init(allocator);
    defer ids.deinit();

    var arena: std.heap.ArenaAllocator = .init(allocator);

    var it = std.mem.tokenizeAny(u8, source, "\r\n");
    while (it.next()) |line| {
      const connectionCount = std.mem.countScalar(u8, line, ' ');
      const connections = try arena.allocator().alloc(usize, connectionCount);

      var lineIt = std.mem.splitScalar(u8, line, ' ');

      var name = lineIt.next().?;
      name = name[0..name.len - 1];

      const nodeId = (try ids.getOrPutValue(name, graph.items.len)).value_ptr.*;
      if (nodeId >= graph.items.len) try graph.append(allocator, connections)
      else graph.items[nodeId] = connections;

      for (0..connectionCount) |i| {
        const connectionId = (try ids.getOrPutValue(lineIt.next().?, graph.items.len)).value_ptr.*;
        if (connectionId >= graph.items.len) try graph.append(allocator, null);
        connections[i] = connectionId;
      }
    }

    const ownedGraph = try arena.allocator().dupe(?Connections, graph.items);
    
    return .{
      .arena = arena,
      .graph = ownedGraph,
      .you = ids.get("you"),
      .svr = ids.get("svr"),
      .dac = ids.get("dac"),
      .fft = ids.get("fft"),
      .out = ids.get("out")
    };
  }

  pub fn deinit(self: *Input) void {
    self.arena.deinit();
  }
};

fn getPathsFromTo(from: usize, to: usize, graph: Graph, cache: *std.AutoHashMap(usize, usize)) !usize {
  if (from == to) return 1;
  if (cache.get(from)) |paths| return paths;

  var paths: usize = 0;
  if (graph[from]) |connections|
    for (connections) |connection| {
      paths += try getPathsFromTo(connection, to, graph, cache);
    };

  try cache.put(from, paths);
  return paths;
}


fn part1(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var cache: std.AutoHashMap(usize, usize) = .init(allocator);
  defer cache.deinit();

  return getPathsFromTo(input.you.?, input.out.?, input.graph, &cache);
}

fn part2(rawInput: []const u8, allocator: std.mem.Allocator) !usize {
  var input: Input = try .init(rawInput, allocator);
  defer input.deinit();

  var cache: std.AutoHashMap(usize, usize) = .init(allocator);
  defer cache.deinit();

  cache.clearRetainingCapacity();
  const svr_fft = try getPathsFromTo(input.svr.?, input.fft.?, input.graph, &cache);

  cache.clearRetainingCapacity();
  const svr_dac = try getPathsFromTo(input.svr.?, input.dac.?, input.graph, &cache);

  cache.clearRetainingCapacity();
  const fft_out = try getPathsFromTo(input.fft.?, input.out.?, input.graph, &cache);

  cache.clearRetainingCapacity();
  const dac_out = try getPathsFromTo(input.dac.?, input.out.?, input.graph, &cache);

  cache.clearRetainingCapacity();
  const fft_dac = try getPathsFromTo(input.fft.?, input.dac.?, input.graph, &cache);

  cache.clearRetainingCapacity();
  const dac_fft = try getPathsFromTo(input.dac.?, input.fft.?, input.graph, &cache);

  return
    svr_fft * fft_dac * dac_out +
    svr_dac * dac_fft * fft_out;
}

pub const problems = AOC.problemsForDay(.{
  .year = 2025,
  .day = 11,
  .parts = &.{
    .{ .run = &part1, .expected = 782, .@"test" = .{ .input = TEST_INPUTS[0], .expected = 5 } },
    .{ .run = &part2, .expected = 401398751986160, .@"test" = .{ .input = TEST_INPUTS[1], .expected = 2 } }
  }
});
