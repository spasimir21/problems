pub fn getErrorMessage(err: anyerror) ?[]const u8 {
  return switch (err) {
    error.MissingSecretsFile => "Your secrets file is missing!",
    error.MissingSecret => "One of your secrets is missing, check your secrets file and try again!",
    error.FailedRequest => "A request failed during input fetching!",
    error.InputLocked => "An input you're trying to fetch is currently locked!",
    else => null
  };
}
