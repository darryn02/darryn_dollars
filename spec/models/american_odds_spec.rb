require "rails_helper"

RSpec.describe AmericanOdds do
  describe ".implied_probability" do
    it "converts a favorite" do
      expect(described_class.implied_probability(-110)).to be_within(1e-12).of(110 / 210.0)
    end

    it "converts an underdog" do
      expect(described_class.implied_probability(250)).to be_within(1e-12).of(100 / 350.0)
    end

    it "gives even money the same probability from either side" do
      expect(described_class.implied_probability(100)).to eq(0.5)
      expect(described_class.implied_probability(-100)).to eq(0.5)
    end

    # There is no price between "risk 100 to win 100" and itself. The
    # scraper rejects these at the trust boundary; this is the backstop.
    it "refuses a price inside the dead band" do
      [-99, 0, 99].each do |odds|
        expect { described_class.implied_probability(odds) }.to raise_error(ArgumentError)
      end
    end
  end

  describe ".from_probability" do
    # Plain rounding lands -185/+160 at -192/+157, which is 104.66% - below
    # the -110 floor the pair was being raised to.
    it "rounds a favorite's magnitude away from zero" do
      expect(described_class.from_probability(0.657839)).to eq(-193)
    end

    it "rounds an underdog's magnitude toward zero" do
      expect(described_class.from_probability(0.389780)).to eq(156)
    end

    it "calls exactly even money +100, the way Bovada does" do
      expect(described_class.from_probability(0.5)).to eq(100)
    end

    it "round-trips the probability ceiling to a real price" do
      expect(described_class.from_probability(0.99)).to eq(-9900)
    end

    # Neither branch can emit a price inside the dead band: above 0.5 the
    # favorite magnitude exceeds 100 before rounding up, and at or below it
    # the underdog magnitude is at least 100 before rounding down.
    it "never emits a price the dead band would reject" do
      (1..9_999).each do |thousandths|
        odds = described_class.from_probability(thousandths / 10_000.0)

        expect(odds.abs).to be >= 100
      end
    end

    it "refuses anything that is not a probability" do
      [0.0, 1.0, -0.5, 1.5, nil, "0.5"].each do |value|
        expect { described_class.from_probability(value) }.to raise_error(ArgumentError)
      end
    end
  end
end
