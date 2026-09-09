require 'rails_helper'

RSpec.describe Competitor, type: :model do
  describe "#find_by_string" do
    let!(:bills) { create_competitor(region: "Buffalo", name: "Bills", abbreviation: "BUF") }

    it "matches on abbreviation" do
      expect(Competitor.find_by_string("BUF")).to eq(bills)
    end

    it "matches on region" do
      expect(Competitor.find_by_string("Buffalo")).to eq(bills)
    end

    it "matches on name" do
      expect(Competitor.find_by_string("Bills")).to eq(bills)
    end

    it "matches on the composed full name" do
      expect(Competitor.find_by_string("Buffalo Bills")).to eq(bills)
    end

    it "matches a nickname held in the array column" do
      bills.update!(nicknames: ["Buffalo's Team"])

      expect(Competitor.find_by_string("Buffalo's Team")).to eq(bills)
    end

    it "returns nil for a name it does not carry" do
      expect(Competitor.find_by_string("Nonexistent Team")).to be_nil
    end

    it "scopes the match to the given sport, separating two teams that share a name" do
      ncaaf_bills = create_competitor(sport: :ncaaf, region: "Buffalo State", name: "Bills", abbreviation: "BUFS")

      expect(Competitor.find_by_string("Bills", sport: :nfl)).to eq(bills)
      expect(Competitor.find_by_string("Bills", sport: :ncaaf)).to eq(ncaaf_bills)
    end

    # find_by_string only rescues RecordNotFound, not SoleRecordExceeded - an
    # ambiguous match raises rather than guessing. It is BovadaApiClient that
    # rescues this around its own call and treats it the same as no match at
    # all (see bovada_api_client_spec.rb's "ambiguous" example).
    it "raises rather than guessing when a name matches more than one competitor" do
      create_competitor(region: "Ambiguous", name: "Bills", abbreviation: "OTHER")

      expect { Competitor.find_by_string("Bills") }.to raise_error(ActiveRecord::SoleRecordExceeded)
    end
  end

  describe "#find_by_string!" do
    it "raises when nothing matches" do
      expect { Competitor.find_by_string!("Nonexistent Team") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "returns the match when there is exactly one" do
      bills = create_competitor(region: "Buffalo", name: "Bills", abbreviation: "BUF")

      expect(Competitor.find_by_string!("BUF")).to eq(bills)
    end
  end

  describe "#full_name" do
    it "is composed from region and name on save" do
      dolphins = Competitor.create!(sport: :nfl, region: "Miami", name: "Dolphins", abbreviation: "MIA")

      expect(dolphins.full_name).to eq("Miami Dolphins")
    end
  end
end
