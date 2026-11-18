const std = @import("std");

pub const Parameter = struct {
  pub const Kind = enum { Flag, Value };
  
  name: []const u8,
  kind: Kind,
  shortName: ?[]const u8 = null,
  description: []const u8,
  default: ?[]const u8 = null,
};

fn ArgumentsType(comptime parameters: []const Parameter) type {
  for (parameters) |param|
    if (param.default != null and param.kind != .Value)
      @compileError("Only value parameters can have a default value!");

  var parameterNames: [parameters.len + 2][]const u8 = undefined;
  var parameterTypes: [parameterNames.len]type = undefined;

  parameterNames[0] = "__arena";
  parameterTypes[0] = std.heap.ArenaAllocator;
  parameterNames[1] = "positional";
  parameterTypes[1] = []const []const u8;

  for (2..parameters.len + 2, parameters) |i, param| {
    parameterNames[i] = param.name;
    parameterTypes[i] = switch (param.kind) {
      .Value => if (param.default) |_| []const u8 else ?[]const u8,
      .Flag => bool
    };
  }

  return @Struct(
    .auto, null,
    &parameterNames, &parameterTypes,
    &@as([parameterNames.len]std.builtin.Type.StructField.Attributes, @splat(.{}))
  );
}

fn getHelpMessage(comptime name: []const u8, comptime positionalParamsHelp: ?[]const u8, comptime parameters: []const Parameter) []const u8 {
  var message: []const u8 = "Usage: " ++ name;

  if (positionalParamsHelp) |help| message = message ++ " " ++ help;

  for (parameters) |param|
    switch (param.kind) {
      .Flag => {
        message = message ++ " [--" ++ param.name;
        if (param.shortName) |short| message = message ++ "|-" ++ short;
        message = message ++ "]";
      },
      .Value => {
        message = message ++ " [--" ++ param.name;
        if (param.shortName) |short| message = message ++ "|-" ++ short;
        message = message ++ "=value";
        if (param.default) |default| message = message ++ " (default: " ++ default ++ ")";
        message = message ++ "]";
      },
    };

  message = message ++ "\n";

  for (parameters) |param|
    message = message ++ "  --" ++ param.name ++ " - " ++ param.description ++ "\n";

  return message;
}

pub fn ArgumentParser(comptime name: []const u8, comptime positionalParamsHelp: ?[]const u8, comptime parameters: []const Parameter) type {
  return struct {
    pub const HELP_MESSAGE = getHelpMessage(name, positionalParamsHelp, parameters);
    pub const Arguments = ArgumentsType(parameters);

    pub fn parseArguments(args: std.process.Args, allocator: std.mem.Allocator) !Arguments {
      var arguments: Arguments = undefined;

      arguments.__arena = std.heap.ArenaAllocator.init(allocator);
      errdefer deinitArguments(&arguments);

      const arena: std.mem.Allocator = arguments.__arena.allocator();
      const argsSlice = (try args.toSlice(arena))[1..];

      var positionalCount: usize = 0;
      for (argsSlice) |arg| {
        if (!std.mem.startsWith(u8, arg, "-")) positionalCount += 1;
      }

      const positional = try arena.alloc([]const u8, positionalCount);
      positionalCount = 0;
      for (argsSlice) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) continue;
        positional[positionalCount] = arg;
        positionalCount += 1;
      }

      arguments.positional = positional;

      inline for (parameters) |param| {
        switch (param.kind) {
          .Flag => {
            @field(arguments, param.name) = false;

            for (argsSlice) |arg| {
              if (std.mem.eql(u8, arg, "--" ++ param.name)) {
                @field(arguments, param.name) = true;
                break;
              }

              if (param.shortName) |short|
                if (std.mem.eql(u8, arg, "-" ++ short)) {
                  @field(arguments, param.name) = true;
                  break;
                };
            }
          },
          .Value => {
            if (param.default) |default| @field(arguments, param.name) = default
            else @field(arguments, param.name) = null;

            const prefix = "--" ++ param.name ++ "=";
            const shortPrefix = if (param.shortName) |short| "-" ++ short ++ "=" else null;

            for (argsSlice) |arg| {
              if (std.mem.startsWith(u8, arg, prefix)) {
                @field(arguments, param.name) = arg[prefix.len..];
                break;
              }

              if (shortPrefix) |short|
                if (std.mem.startsWith(u8, arg, short)) {
                  @field(arguments, param.name) = arg[short.len..];
                  break;
                };
            }
          }
        }
      }

      return arguments;
    }

    pub fn deinitArguments(args: *Arguments) void {
      args.__arena.deinit();
    }
  };
}
