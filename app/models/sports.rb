# Which sports the board is currently offering.
#
# NCAAF comes and goes: the book turns it off for the stretch of the season
# where the players have the edge, and back on for the bowls. That is a
# scheduling decision rather than a code change, so it lives in the
# environment - NCAAF_ENABLED=0 to switch it off, anything else (or nothing at
# all) leaves it on.
#
# Switching a sport off only takes it off the board. The scrape is deliberately
# left alone, so the lines stay warm and turning it back on is immediate rather
# than a wait for the next fetch.
module Sports
  ALL = %w[nfl ncaaf].freeze

  def self.all
    ALL
  end

  def self.enabled
    ALL.select { |sport| enabled?(sport) }
  end

  def self.enabled?(sport)
    return false unless ALL.include?(sport.to_s)

    ENV.fetch("#{sport.to_s.upcase}_ENABLED", "1") != "0"
  end

  # What the board falls back to when nothing was asked for, or when what was
  # asked for is switched off. Nil only if every sport is off at once.
  def self.default
    enabled.first
  end
end
