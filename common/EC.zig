const Problem = @import("./Problem.zig");
const std = @import("std");

pub const TestOptions = struct {
  run: ?Problem.Func = null,
  expected: usize,
  input: []const u8
};

pub const PartOptions = struct {
  run: Problem.Func,
  expected: ?usize = null,
  @"test": ?TestOptions = null
};

pub const QuestOptions = struct {
  year: usize,
  quest: usize,
  parts: []const PartOptions
};

const FetchContext = struct { event: []const u8, quest: usize, part: usize };

const EncodedInput = struct {
  @"1": []const u8,
  @"2": []const u8,
  @"3": []const u8
};

const Keys = struct {
  key1: ?[]const u8 = null,
  key2: ?[]const u8 = null,
  key3: ?[]const u8 = null
};

fn fetchInput(
  opaqueContext: *const anyopaque,
  secrets: *const std.StringHashMap([]const u8),
  io: std.Io,
  allocator: std.mem.Allocator
) ![]const u8 {
  const context: *const FetchContext = @ptrCast(@alignCast(opaqueContext));

  var client: std.http.Client = .{ .allocator = allocator, .io = io };
  defer client.deinit();

  const seed = try std.fmt.parseUnsigned(usize, secrets.get("EC_SEED") orelse return error.MissingSecret, 10);

  const inputUrl = try std.fmt.allocPrint(allocator, "https://everybody.codes/assets/{s}/{d}/input/{d}.json", .{ context.event, context.quest, seed });
  defer allocator.free(inputUrl);

  const keyUrl = try std.fmt.allocPrint(allocator, "https://api.everybody.codes/event/{s}/quest/{d}", .{ context.event, context.quest });
  defer allocator.free(keyUrl);

  const cookie = try std.fmt.allocPrint(allocator, "everybody-codes={s}", .{ secrets.get("EC_SESSION") orelse return error.MissingSecret });
  defer allocator.free(cookie);

  var response: std.Io.Writer.Allocating = .init(allocator);
  defer response.deinit();

  const inputResult = try client.fetch(.{
    .location = .{ .url = inputUrl },
    .method = .GET,
    .headers = .{ .user_agent = .{ .override = "curl/8.0.0" } },
    .response_writer = &response.writer
  });

  if (inputResult.status != .ok) return error.FailedRequest;

  const encodedInputJSON = try std.json.parseFromSlice(EncodedInput, allocator, response.written(), .{ .allocate = .alloc_if_needed, .ignore_unknown_fields = true });
  defer encodedInputJSON.deinit();

  const encodedInput = switch (context.part) {
    1 => encodedInputJSON.value.@"1",
    2 => encodedInputJSON.value.@"2",
    3 => encodedInputJSON.value.@"3",
    else => unreachable
  };

  const encryptedInput = try allocator.alloc(u8, encodedInput.len / 2);
  defer allocator.free(encryptedInput);

  _ = try std.fmt.hexToBytes(encryptedInput, encodedInput);

  response.clearRetainingCapacity();

  const keyResult = try client.fetch(.{
    .location = .{ .url = keyUrl },
    .method = .GET,
    .headers = .{ .user_agent = .{ .override = "curl/8.0.0" } },
    .extra_headers = &.{ .{ .name = "Cookie", .value = cookie } },
    .response_writer = &response.writer
  });

  if (keyResult.status != .ok) return error.FailedRequest;

  const keysJSON = try std.json.parseFromSlice(Keys, allocator, response.written(), .{ .allocate = .alloc_if_needed, .ignore_unknown_fields = true });
  defer keysJSON.deinit();

  const key = switch (context.part) {
    1 => keysJSON.value.key1,
    2 => keysJSON.value.key2,
    3 => keysJSON.value.key3,
    else => unreachable
  } orelse return error.InputLocked;

  var ctx = std.crypto.core.aes.Aes256.initDec(key[0..32].*);

  const input = try allocator.alloc(u8, encryptedInput.len);
  defer allocator.free(input);

  var previous = key[0..16].*;
  for (0..encryptedInput.len / 16) |i| {
    const offset = i * 16;
    const block = encryptedInput[offset..][0..16].*;

    var decrypted: [16]u8 = undefined;
    ctx.decrypt(&decrypted, &block);

    for (0..16) |j| input[offset + j] = decrypted[j] ^ previous[j];

    previous = block;
  }

  return allocator.dupe(u8, input[0 .. input.len - input[input.len - 1]]);
}

fn problemsForQuestCount(comptime options: QuestOptions) usize {
  var count: usize = 0;
  for (options.parts) |part| count += if (part.@"test" != null) 2 else 1;
  return count;
}

pub fn problemsForQuest(comptime options: QuestOptions) [problemsForQuestCount(options)]Problem {
  var problems: [problemsForQuestCount(options)]Problem = undefined;

  var index: usize = 0;
  for (options.parts, 1..options.parts.len + 1) |part, n| {
    const partName = std.fmt.comptimePrint("Part {d}", .{ n });
    const partId = std.fmt.comptimePrint("part-{d}", .{ n });

    if (part.@"test") |t| {
      problems[index] = .{
        .id = partId ++ "-test",
        .name = partName ++ ", Test",
        .tags = &.{ partId, "test" },
        .input = .{ .literal = t.input },
        .expected = t.expected,
        .func = t.run orelse part.run
      };

      index += 1;
    }

    problems[index] = .{
      .id = partId,
      .name = partName,
      .tags = &.{ partId },
      .input = .{
        .path = std.fmt.comptimePrint("ec/{d}/quest-{d}-{d}.txt", .{ options.year, options.quest, n })
      },
      .expected = part.expected,
      .func = part.run,
      .fetch = .{
        .context = &FetchContext {
          .event = std.fmt.comptimePrint("{d}", .{ options.year }),
          .quest = options.quest,
          .part = n
        },
        .func = &fetchInput
      }
    };

    index += 1;
  }

  return Problem.group(
    .{
      .idPrefix = std.fmt.comptimePrint("quest-{d}-", .{ options.quest }),
      .namePrefix = std.fmt.comptimePrint("Quest {d}, ", .{ options.quest }),
      .tags = &.{ std.fmt.comptimePrint("quest-{d}", .{ options.quest }), }
    },
    .{ problems }
  );
}
