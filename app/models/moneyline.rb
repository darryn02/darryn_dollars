# What the book is willing to offer on a moneyline, and whether it is
# offering them at all.
#
# Modelled on Sports in shape - environment-backed, read at request time, so
# every one of these is a config change rather than a deploy. It deliberately
# does NOT copy Sports' truthiness. Sports treats absent as on and only an
# explicit "0" as off, which is right for a market that is normally running.
# This one is the opposite on both counts, for the reasons below.
module Moneyline
  # Every market on this board pays at least what -110 pays. Deriving the
  # floor from -110 rather than writing 1.047619 down means it can never
  # drift from what spread and total actually charge - if that price ever
  # changes, this follows it.
  VIG_FLOOR = 2 * AmericanOdds.implied_probability(-110)

  # The highest probability a side may be scaled to when a pair is being
  # raised to the floor. Without it, scaling a heavy favorite can push its
  # probability past 1.0, which has no American price at all.
  #
  # This is not a global ceiling on what can be stored: a pair already at or
  # above the floor short-circuits untouched and never meets the clamp, so a
  # raw -12000 still lands in the database intact.
  PROBABILITY_CEILING = 0.99

  # On only for an explicit "1" or "true". Absent is off, and so is anything
  # else.
  #
  # An allowlist rather than Sports' `!= "0"` test, because this is the
  # control that has to fail closed: darryn-dollars-staging is the live app
  # and there is no rehearsal tier, so this switch is the whole safety net.
  # Copying the Sports idiom would read MONEYLINE_ENABLED=false as enabled,
  # which is the one way it must never be wrong.
  TRUTHY = %w[1 true].freeze

  def self.enabled?
    TRUTHY.include?(ENV.fetch("MONEYLINE_ENABLED", "").strip.downcase)
  end

  # The longest underdog price the board will take a bet on. +300 caps a
  # single bet at 3x stake and pulls the dog side from about one game in
  # seven. Read at request time, so tightening it mid-season costs a config
  # change and no re-scrape.
  def self.max_odds
    ENV.fetch("MONEYLINE_MAX_ODDS", "300").to_i
  end

  # The shortest favorite price the board will take a bet on, as an
  # exclusive bound - -1000 itself is withheld and -999 is the longest price
  # that can reach the board.
  #
  # This is not about risk, it is about inventory nobody can use: at -999 the
  # $50 minimum wager wins $5.01. It also keeps every bettable price to four
  # characters, which is what lets the board's third column fit a 360px
  # phone without a truncation scheme.
  def self.min_odds
    ENV.fetch("MONEYLINE_MIN_ODDS", "-1000").to_i
  end

  # Whether this moneyline is one the board may offer a bet on.
  #
  # Deliberately not a general predicate over lines: a spread or a total
  # answers false, because the only honest answer to "may we offer this
  # moneyline" about something that is not one is no. Nothing should be
  # asking about other kinds, and false is the safe way to be wrong.
  #
  # Garbage in either bound fails closed rather than open - a
  # MONEYLINE_MAX_ODDS of "soon" reads as 0 and withholds everything.
  def self.offerable?(line)
    return false unless enabled?
    return false unless line.respond_to?(:moneyline?) && line.moneyline?

    bettable_odds?(line.odds)
  end

  # The bettable band, (min_odds, max_odds]. Exclusive at the bottom,
  # inclusive at the top.
  #
  # The dead-band check is not redundant with the bounds, because zero sits
  # inside them. 12 rows in the live database hold a price in (-100, 100) -
  # the pre-flight count on 2026-09-20 - almost certainly zero, from the old
  # `"EVEN".to_i` parse. Line#payout takes its odds >= 0 branch on zero and
  # returns `amount * 0 * 0.01`, so without this the board would have
  # offered those rows a bet that pays nothing at all on a win.
  #
  # The scraper can no longer mint one, and a row keyed on a new price will
  # not be found again, so the existing ones age out on their own. This is
  # what makes that true regardless of what is already stored.
  def self.bettable_odds?(odds)
    return false unless odds.is_a?(Integer) && odds.abs >= 100

    min_odds < odds && odds <= max_odds
  end
end
