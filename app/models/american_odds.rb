# Conversion between American odds and implied probability, in both
# directions.
#
# The two directions are not symmetric, and that asymmetry is the point.
# Going to probability is exact arithmetic. Coming back lands on a fraction
# that has to become an integer, and which way that integer moves decides
# whether the book keeps its margin or leaks it - so from_probability rounds
# toward the book rather than to the nearest value.
module AmericanOdds
  module_function

  # The share of the time a price says the bet wins, vig included. A pair of
  # real prices therefore sums to more than 1; the excess is the overround.
  #
  # Odds inside (-100, 100) have no meaning - there is no price between
  # "risk 100 to win 100" and itself - so they are a caller bug rather than
  # a number to convert. The scraper rejects them at the trust boundary; the
  # raise here is the backstop for anything that gets past it.
  def implied_probability(odds)
    odds = Integer(odds)
    raise ArgumentError, "#{odds} is not a valid American price" if odds.abs < 100

    odds.positive? ? 100.0 / (odds + 100) : -odds / (-odds + 100.0)
  end

  # The price that expresses this probability, rounded so the integer can
  # only ever favor the book.
  #
  # A favorite rounds its magnitude away from zero (-192.3 becomes -193) and
  # an underdog rounds its down (+156.5 becomes +156). Both moves shorten
  # the payout, so an integer pair can overshoot the overround it was
  # derived from but never undershoot it - which is what lets
  # MoneylinePricer promise that normalizing never lowers the book's margin.
  # Plain rounding breaks that promise on most pairs: -185/+160 lands at
  # -192/+157, which is below the -110 floor it was being raised to.
  #
  # Exactly even money is +100, matching Bovada's own "EVEN". The branch is
  # on p > 0.5 rather than >= so the two round-trip: implied_probability
  # gives +100 and -100 the same 0.5, and one of them has to be the answer.
  def from_probability(probability)
    unless probability.is_a?(Numeric) && probability > 0 && probability < 1
      raise ArgumentError, "#{probability.inspect} is not a probability strictly between 0 and 1"
    end

    if probability > 0.5
      -(100.0 * probability / (1 - probability)).ceil
    else
      (100.0 * (1 - probability) / probability).floor
    end
  end
end
