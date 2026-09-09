require "rails_helper"

RSpec.describe LineScorer, type: :service do
  let(:game) { create_game(starts_at: 2.hours.ago) }
  let(:away) { game.contestants.order(:priority).first }
  let(:home) { game.contestants.order(:priority).second }

  it "scores pending lines that have scores and tallies the results per kind" do
    away.update!(scores: [24])
    home.update!(scores: [21])
    winning_spread = create_spread(game: game, contestant: away, value: 2.5)
    losing_spread = create_spread(game: game, contestant: home, value: -2.5)

    message = described_class.run(Line.pending)

    expect(winning_spread.reload).to be_win
    expect(losing_spread.reload).to be_loss
    expect(message).to include("point_spread: 1 wins, 1 losses, 0 pushes")
  end

  it "skips a contestant whose scores are still empty" do
    other_game = create_game(starts_at: 2.hours.ago)
    away_contestant = other_game.contestants.order(:priority).first
    untouched = create_spread(game: other_game, contestant: away_contestant, value: 2.5)

    described_class.run(Line.pending)

    expect(untouched.reload).to be_pending
  end

  it "reports no updates when there is nothing to score" do
    message = described_class.run(Line.none)

    expect(message).to eq("No updates")
  end
end
