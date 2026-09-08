# EspnScoreboard memoises responses in a class-level hash for ten seconds, which
# outlives an example. Left alone, one spec's stubbed scoreboard answers the
# next spec's question.
RSpec.configure do |config|
  config.before(:each) { EspnScoreboard.reset_cache! }
end
