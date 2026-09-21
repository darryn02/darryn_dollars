# Raises a pair of moneyline prices to the book's floor, and never lowers
# them.
#
# Bovada prices a moneyline pair at whatever overround it wants, which is
# sometimes thinner than the 4.76% that -110/-110 charges on every spread
# and total on this board. Normalizing at the trust boundary is what stops
# moneyline from being the one market where the book gives back its edge.
#
# The arguments are named for the two outcomes rather than for favorite and
# underdog on purpose: -105/-115 is a perfectly ordinary pair with two
# favorites and no dog to name.
class MoneylinePricer
  # Returns the pair to store, as integers, in the order given.
  def self.normalize(odds_a, odds_b)
    new(odds_a, odds_b).normalize
  end

  def initialize(odds_a, odds_b)
    @odds_a = Integer(odds_a)
    @odds_b = Integer(odds_b)
  end

  def normalize
    # Short-circuit, not an optimization. Re-deriving a pair that needs
    # nothing damages it: -110/-110 converts to probability and back as
    # -111/-111, charging 105.21% where the book asks 104.76%. A pair
    # already at or above the floor is returned exactly as it arrived.
    return [odds_a, odds_b] if scale == 1.0

    [raw_p_a, raw_p_b].map { |p| AmericanOdds.from_probability(clamp(p * scale)) }
  end

  private

  attr_reader :odds_a, :odds_b

  def raw_p_a = @raw_p_a ||= AmericanOdds.implied_probability(odds_a)
  def raw_p_b = @raw_p_b ||= AmericanOdds.implied_probability(odds_b)

  # Never below 1.0, so this can only ever raise a pair.
  def scale
    @scale ||= [1.0, Moneyline::VIG_FLOOR / (raw_p_a + raw_p_b)].max
  end

  # Where the clamp and the floor genuinely conflict, the clamp wins.
  #
  # -5000/+3500 scales its favorite to 1.01875, which has no price at all.
  # Clamping to 0.99 prevents that but leaves the pair at 101.89%, below the
  # floor. That is accepted rather than fixed, because whenever the clamp
  # fires the partner's probability is at most VIG_FLOOR - 0.99 = 0.0576, so
  # the underdog is never shorter than +1635 - more than five times the +300
  # cap, and therefore withheld from the board in every case rather than
  # merely in practice. The favorite it leaves behind is priced at -9900,
  # which the -1000 bound withholds too.
  def clamp(probability)
    [probability, Moneyline::PROBABILITY_CEILING].min
  end
end
