require "rails_helper"

RSpec.describe LinesHelper, type: :helper do
  let(:game) { create_game }
  let(:away) { game.contestants.order(:priority).first }

  describe "#side_label" do
    # The ternary this replaced was `point_spread? ? spread_label :
    # total_label`, so a moneyline fell through to total_label, read
    # line.over? as false and printed "U 0.0".
    it "names a moneyline ML, with no value segment" do
      line = create_moneyline(game: game, contestant: away, odds: -285)

      expect(helper.side_label(line)).to eq("ML")
    end

    it "says ML on both sides, leaving the price to distinguish them" do
      home = game.contestants.order(:priority).second
      favorite = create_moneyline(game: game, contestant: away, odds: -285)
      underdog = create_moneyline(game: game, contestant: home, odds: 240)

      expect(helper.side_label(favorite)).to eq(helper.side_label(underdog))
    end

    it "keeps a spread on its signed value" do
      line = create_spread(game: game, contestant: away, value: 2.5)

      expect(helper.side_label(line)).to eq("+2.5")
    end

    it "keeps an over on O and its value" do
      line = create_total(game: game, kind: :over, value: 47.5)

      expect(helper.side_label(line)).to eq("O 47.5")
    end

    it "keeps an under on U and its value" do
      line = create_total(game: game, kind: :under, value: 47.5)

      expect(helper.side_label(line)).to eq("U 47.5")
    end

    it "is nil for no line at all, the way spread_label and total_label are" do
      expect(helper.side_label(nil)).to be_nil
    end
  end

  describe "#line_headline" do
    it "puts the team in front of ML for a moneyline" do
      line = create_moneyline(game: game, contestant: away, odds: -285)

      expect(helper.line_headline(line)).to eq("BUF ML")
    end
  end
end
