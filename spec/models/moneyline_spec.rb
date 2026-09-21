require "rails_helper"

RSpec.describe Moneyline do
  around do |example|
    original = ENV.to_hash.slice("MONEYLINE_ENABLED", "MONEYLINE_MAX_ODDS", "MONEYLINE_MIN_ODDS")
    example.run
  ensure
    %w[MONEYLINE_ENABLED MONEYLINE_MAX_ODDS MONEYLINE_MIN_ODDS].each { |key| ENV.delete(key) }
    original.each { |key, value| ENV[key] = value }
  end

  describe ".enabled?" do
    it "is off when the variable is absent" do
      ENV.delete("MONEYLINE_ENABLED")

      expect(described_class.enabled?).to be(false)
    end

    it "is on for an explicit 1 or true, whatever the case" do
      %w[1 true TRUE True  true ].each do |value|
        ENV["MONEYLINE_ENABLED"] = value

        expect(described_class.enabled?).to be(true)
      end
    end

    # The one that would have bitten. Sports tests `!= "0"`, which reads
    # "false" as enabled. This switch is the whole safety net for a market
    # going live on the app the players actually use, so it fails closed.
    it "is off for anything else, including the words that look like off" do
      %w[0 false no off "" yes 2 enabled].each do |value|
        ENV["MONEYLINE_ENABLED"] = value

        expect(described_class.enabled?).to be(false)
      end
    end
  end

  describe ".max_odds and .min_odds" do
    it "defaults to the settled band" do
      ENV.delete("MONEYLINE_MAX_ODDS")
      ENV.delete("MONEYLINE_MIN_ODDS")

      expect(described_class.max_odds).to eq(300)
      expect(described_class.min_odds).to eq(-1000)
    end

    it "reads a tightened cap at request time, so it is a config change" do
      ENV["MONEYLINE_MAX_ODDS"] = "250"

      expect(described_class.max_odds).to eq(250)
    end
  end

  describe ".bettable_odds?" do
    it "takes the cap itself but not one point past it" do
      expect(described_class.bettable_odds?(300)).to be(true)
      expect(described_class.bettable_odds?(301)).to be(false)
    end

    # The lower bound is exclusive: -1000 is withheld and -999 is the
    # longest price that can reach the board.
    it "refuses the bound itself and takes one point inside it" do
      expect(described_class.bettable_odds?(-1000)).to be(false)
      expect(described_class.bettable_odds?(-999)).to be(true)
    end

    it "takes even money from either side" do
      expect(described_class.bettable_odds?(100)).to be(true)
      expect(described_class.bettable_odds?(-100)).to be(true)
    end

    # Zero is inside (-1000, +300], so the bounds alone let it through -
    # and Line#payout returns amount * 0 * 0.01 on it, meaning a winning
    # bet pays nothing. 12 rows in the live database hold such a price,
    # left by the old "EVEN".to_i parse.
    it "refuses a price in the dead band, which the bounds alone allow" do
      expect(Moneyline.min_odds < 0 && 0 <= Moneyline.max_odds).to be(true)

      [-99, 0, 99].each do |odds|
        expect(described_class.bettable_odds?(odds)).to be(false)
      end
    end

    it "fails closed on a bound that does not parse" do
      ENV["MONEYLINE_MAX_ODDS"] = "soon"

      expect(described_class.bettable_odds?(150)).to be(false)
    end
  end

  describe ".offerable?" do
    let(:game) { create_game }
    let(:away) { game.contestants.order(:priority).first }

    def moneyline(odds)
      create_moneyline(game: game, contestant: away, odds: odds)
    end

    it "offers a price inside the band when the switch is on" do
      ENV["MONEYLINE_ENABLED"] = "1"

      expect(described_class.offerable?(moneyline(240))).to be(true)
    end

    it "withholds an underdog past the cap" do
      ENV["MONEYLINE_ENABLED"] = "1"

      expect(described_class.offerable?(moneyline(450))).to be(false)
    end

    it "withholds a favorite past the bound" do
      ENV["MONEYLINE_ENABLED"] = "1"

      expect(described_class.offerable?(moneyline(-1200))).to be(false)
    end

    it "offers nothing at all when the switch is off" do
      ENV["MONEYLINE_ENABLED"] = "0"

      expect(described_class.offerable?(moneyline(-150))).to be(false)
    end

    # Deliberately not a general predicate over lines. Nothing should be
    # asking it about a spread, and no is the safe way to be wrong.
    it "withholds a legacy row left at zero by the old EVEN parse" do
      ENV["MONEYLINE_ENABLED"] = "1"

      expect(described_class.offerable?(moneyline(0))).to be(false)
    end

    it "answers no about a line that is not a moneyline, and about nil" do
      ENV["MONEYLINE_ENABLED"] = "1"
      spread = create_spread(game: game, contestant: away, value: 2.5)

      expect(described_class.offerable?(spread)).to be(false)
      expect(described_class.offerable?(nil)).to be(false)
    end
  end

  describe "VIG_FLOOR" do
    # Derived rather than written down, so it can never drift from what
    # spread and total actually charge.
    it "is exactly what a -110/-110 pair charges" do
      expect(described_class::VIG_FLOOR).to eq(2 * AmericanOdds.implied_probability(-110))
      expect(described_class::VIG_FLOOR).to be_within(1e-6).of(1.047619)
    end
  end
end
