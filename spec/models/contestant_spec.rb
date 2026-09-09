require 'rails_helper'

RSpec.describe Contestant, type: :model do
  it "delegates #name to its competitor" do
    game = create_game(away: create_competitor(region: "Buffalo", name: "Bills", abbreviation: "BUF"))
    contestant = game.contestants.order(:priority).first

    expect(contestant.name).to eq("Bills")
  end

  describe "#latest_line" do
    it "returns the most recently created line" do
      game = create_game
      contestant = game.contestants.order(:priority).first

      older = create_spread(game: game, contestant: contestant, value: 3.0)
      newer = create_spread(game: game, contestant: contestant, value: 2.5)

      expect(contestant.reload.latest_line).to eq(newer)
      expect(contestant.reload.latest_line).not_to eq(older)
    end
  end
end
