require "rails_helper"

RSpec.describe Sports do
  around do |example|
    original = ENV.to_hash.slice("NFL_ENABLED", "NCAAF_ENABLED")
    example.run
  ensure
    %w[NFL_ENABLED NCAAF_ENABLED].each { |key| ENV.delete(key) }
    original.each { |key, value| ENV[key] = value }
  end

  describe ".enabled?" do
    it "treats a sport with no setting as on" do
      ENV.delete("NCAAF_ENABLED")

      expect(described_class.enabled?("ncaaf")).to be(true)
    end

    it "is off only for an explicit zero" do
      ENV["NCAAF_ENABLED"] = "0"

      expect(described_class.enabled?("ncaaf")).to be(false)
    end

    it "stays on for any other value" do
      ENV["NCAAF_ENABLED"] = "1"
      expect(described_class.enabled?("ncaaf")).to be(true)

      ENV["NCAAF_ENABLED"] = "yes"
      expect(described_class.enabled?("ncaaf")).to be(true)
    end

    it "accepts a symbol" do
      ENV["NCAAF_ENABLED"] = "0"

      expect(described_class.enabled?(:ncaaf)).to be(false)
    end

    it "does not invent sports the board does not carry" do
      expect(described_class.enabled?("nba")).to be(false)
    end

    it "switches each sport independently" do
      ENV["NCAAF_ENABLED"] = "0"

      expect(described_class.enabled?("nfl")).to be(true)
    end
  end

  describe ".enabled" do
    it "keeps the display order" do
      expect(described_class.enabled).to eq(%w[nfl ncaaf])
    end

    it "drops what is switched off" do
      ENV["NCAAF_ENABLED"] = "0"

      expect(described_class.enabled).to eq(%w[nfl])
    end
  end

  describe ".default" do
    it "is the first sport still on" do
      ENV["NFL_ENABLED"] = "0"

      expect(described_class.default).to eq("ncaaf")
    end

    it "is nil when the board is closed entirely" do
      ENV["NFL_ENABLED"] = "0"
      ENV["NCAAF_ENABLED"] = "0"

      expect(described_class.default).to be_nil
    end
  end
end
