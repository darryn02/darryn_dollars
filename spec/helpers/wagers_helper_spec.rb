require "rails_helper"

RSpec.describe WagersHelper, type: :helper do
  let(:game) { create_game }
  let(:away) { game.contestants.order(:priority).first }

  describe "#wager_line_label" do
    it "reads team plus ML for a moneyline, with the price left to line_terms" do
      line = create_moneyline(game: game, contestant: away, odds: -285)

      expect(helper.wager_line_label(line)).to eq("BUF ML")
      expect(helper.line_terms(line)).to eq("-285")
    end

    it "still reads team plus signed value for a spread" do
      line = create_spread(game: game, contestant: away, value: 2.5)

      expect(helper.wager_line_label(line)).to eq("BUF +2.5")
    end

    it "still falls back to the matchup for a total, which has no side" do
      line = create_total(game: game, kind: :over, value: 47.5)

      expect(helper.wager_line_label(line)).to eq("BUF/MIA O 47.5")
    end
  end
end
