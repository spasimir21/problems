pub fn isBase10Digit(char: u8) bool {
  return char >= '0' and char <= '9';
}

pub fn SequenceIterator(comptime T: type, comptime predicate: fn (T) bool) type {
  return struct {
    sequence: []const T,
    index: usize = 0,

    pub fn init(sequence: []const T) @This() {
      return .{ .sequence = sequence };
    }

    pub fn next(self: *@This()) ?[]const T {
      while (self.index < self.sequence.len) : (self.index += 1)
        if (predicate(self.sequence[self.index])) break;

      const startIndex = self.index;

      while (self.index < self.sequence.len) : (self.index += 1)
        if (!predicate(self.sequence[self.index])) break;

      return if (self.index > startIndex) self.sequence[startIndex..self.index] else null;
    }

    pub fn countRemaining(self: *@This()) usize {
      const index = self.index;
      defer self.index = index;

      var count: usize = 0;
      while (self.next()) |_| count += 1;
      return count;
    }

    pub fn reset(self: *@This()) void {
      self.index = 0;
    }
  };
}
