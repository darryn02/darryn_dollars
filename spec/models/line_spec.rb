require 'rails_helper'

RSpec.describe Line, type: :model do
  let(:competitor) { Competitor.create!(sport: :nfl, region: "Buffalo", name: "Bills", abbreviation: "BUF") }
  let(:other) { Competitor.create!(sport: :nfl, region: "Miami", name: "Dolphins", abbreviation: "MIA") }
  let(:game) { Game.create!(sport: :nfl, starts_at: 2.hours.from_now) }
  let(:contestant) { game.contestants.create!(competitor: competitor, priority: 0) }

  # Both sides have to exist before short_matchup means anything.
  before do
    contestant
    game.contestants.create!(competitor: other, priority: 1)
  end

  describe "#to_s" do
    # This used to interpolate "(#{odds} #{scope_str(scope)})", which left a
    # stray space as "(-110 )" whenever there was no half to name. squish
    # cannot reach a space inside the parentheses.
    it "leaves no gap in the terms for a full game line" do
      line = game.lines.create!(kind: :point_spread, scope: :game, value: -3.0, contestant: contestant)

      expect(line.to_s).to eq("BUF -3.0 (-110)")
    end

    it "names the half when there is one" do
      line = game.lines.create!(kind: :point_spread, scope: :first_half, value: -1.5, contestant: contestant)

      expect(line.to_s).to eq("BUF -1.5 (-110 1H)")
    end

    it "falls back to the matchup for a line with no side, such as a total" do
      line = game.lines.create!(kind: :over, scope: :second_half, value: 24.5)

      expect(line.to_s).to eq("BUF/MIA O24.5 (-110 2H)")
    end

    it "writes a zero spread as PICK" do
      line = game.lines.create!(kind: :point_spread, scope: :game, value: 0.0, contestant: contestant)

      expect(line.to_s).to eq("BUF PICK (-110)")
    end
  end

  describe "#payout" do
    it "pays the stake times the odds over 100 for positive (underdog) odds" do
      line = game.lines.create!(kind: :point_spread, scope: :game, value: 3.0, odds: 150, contestant: contestant)

      expect(line.payout(100)).to eq(150.0)
    end

    it "pays the stake over the odds magnitude for negative (favorite) odds" do
      line = game.lines.create!(kind: :point_spread, scope: :game, value: -3.0, odds: -110, contestant: contestant)

      expect(line.payout(110)).to eq(100.0)
    end
  end
end
