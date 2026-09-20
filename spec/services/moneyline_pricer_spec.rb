require "rails_helper"

RSpec.describe MoneylinePricer, type: :service do
  # A bare constant here would land on Object and leak into every other
  # spec file in the run.
  def floor = Moneyline::VIG_FLOOR

  def overround(pair)
    pair.sum { |odds| AmericanOdds.implied_probability(odds) }
  end

  describe ".normalize" do
    it "leaves a pair that already clears the floor exactly as it found it" do
      expect(described_class.normalize(-415, 310)).to eq([-415, 310])
    end

    # The short-circuit is not an optimization. Re-deriving this pair
    # through probability returns -111/-111, charging 105.21% where the
    # book asks 104.76% - a pair at the floor damaged by being normalized.
    it "returns a pair sitting exactly on the floor untouched, not re-derived" do
      expect(described_class.normalize(-110, -110)).to eq([-110, -110])
    end

    it "raises a thin pair to the floor, rounding toward the book" do
      pair = described_class.normalize(-185, 160)

      expect(pair).to eq([-193, 156])
      expect(overround(pair)).to be >= floor
    end

    it "raises a very thin pair without losing the floor to rounding" do
      pair = described_class.normalize(-2000, 1500)

      expect(pair).to eq([-5819, 1449])
      expect(overround(pair)).to be >= floor
    end

    # The formula's favorite/underdog framing implies a split that does not
    # always exist. Two favorites is an ordinary pair and still needs the
    # book rounding.
    it "handles a pair with two favorites and no underdog at all" do
      pair = described_class.normalize(-105, -115)

      expect(pair).to eq([-106, -116])
      expect(pair).to all(be_negative)
      expect(overround(pair)).to be >= floor
    end

    it "keeps the order it was given" do
      expect(described_class.normalize(160, -185)).to eq([156, -193])
    end

    describe "when scaling would push a side past probability 1" do
      # -5000/+3500 scales its favorite to 1.01875, which has no American
      # price. The clamp prevents the overflow and, on this shape alone,
      # wins against the floor rather than the other way round.
      it "emits valid odds rather than overflowing" do
        pair = described_class.normalize(-5000, 3500)

        expect(pair).to eq([-9900, 3364])
        expect(pair.map(&:abs)).to all(be >= 100)
      end

      it "accepts landing below the floor, which is the documented exception" do
        expect(overround(described_class.normalize(-5000, 3500))).to be < floor
      end

      # What makes that exception safe: the clamped pair's underdog is
      # never shorter than +1635, over five times the +300 cap, so it is
      # always withheld from the board. Its favorite is past -1000 too.
      it "always leaves an underdog far beyond the cap and a favorite past the bound" do
        pair = described_class.normalize(-5000, 3500)

        expect(pair.select(&:positive?).min).to be >= 1_635
        expect(Moneyline.bettable_odds?(pair.first)).to be(false)
        expect(Moneyline.bettable_odds?(pair.last)).to be(false)
      end
    end

    # The whole promise of the one-directional rule. The clamp is the only
    # documented exception, in both directions - a favorite already priced
    # worse than -9900 is clamped down by design - so it is excluded here
    # and pinned by its own examples above.
    it "never returns a pair thinner than the one it was given" do
      prices = (100..600).flat_map { |m| [m, -m] } +
               (601..9_999).step(37).flat_map { |m| [m, -m] }
      violations = []

      prices.each do |a|
        prices.each do |b|
          raw = overround([a, b])
          scale = [1.0, floor / raw].max
          next if scale == 1.0
          next if raw_scaled_beyond_ceiling?(a, b, scale)

          after = overround(described_class.normalize(a, b))
          violations << [a, b, raw, after] if after < raw - 1e-12
        end
      end

      expect(violations).to be_empty
    end

    def raw_scaled_beyond_ceiling?(a, b, scale)
      [a, b].any? do |odds|
        AmericanOdds.implied_probability(odds) * scale > Moneyline::PROBABILITY_CEILING
      end
    end
  end
end
