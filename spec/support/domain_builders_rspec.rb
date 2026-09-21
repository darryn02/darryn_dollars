# RSpec registration for DomainBuilders, kept out of the builder file
# itself so that file stays a plain Ruby module.
#
# lib/tasks/dev.rake requires the builders directly to seed a development
# database, where RSpec is not loaded at all - a `RSpec.configure` call
# sitting in that file made the require raise, which is what kept dev:prime
# broken after it was supposedly repaired.
require_relative "domain_builders"

RSpec.configure do |config|
  config.include DomainBuilders

  # MONEYLINE_ENABLED defaults to off when absent, so without this the suite
  # would inherit whatever the shell happens to have and every moneyline
  # wager would be rejected by Wager#moneyline_is_offerable. Set it
  # explicitly rather than depending on ambient config, and restore the
  # original afterwards the way spec/models/sports_spec.rb does.
  #
  # A spec that needs the switch off - the board-unchanged spec, the
  # rejection specs - overrides ENV inside its own example.
  config.around do |example|
    original = ENV.to_hash.slice("MONEYLINE_ENABLED")
    ENV["MONEYLINE_ENABLED"] = "1"
    example.run
  ensure
    ENV.delete("MONEYLINE_ENABLED")
    original.each { |key, value| ENV[key] = value }
  end
end
