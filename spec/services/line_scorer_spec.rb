require "rails_helper"

RSpec.describe LineScorer, type: :service do
  let(:game) { create_game(starts_at: 4.hours.ago, completed_at: 1.hour.ago) }
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

  # The one that costs money. At half time the scores array holds two real
  # periods, so a full game line slices to [7, 3] and sums to a perfectly
  # plausible 10 - nothing about the number says the third quarter has not
  # been played. Only the game's own completed_at knows, which is why the
  # gate lives here rather than in the arithmetic.
  describe "a game that is only half over" do
    let(:half_played) { create_game(starts_at: 2.hours.ago) } # completed_at: nil
    let(:half_away) { half_played.contestants.order(:priority).first }
    let(:half_home) { half_played.contestants.order(:priority).second }

    before do
      half_away.update!(scores: [7, 3])
      half_home.update!(scores: [0, 10])
    end

    it "leaves a full game line pending" do
      line = create_spread(game: half_played, contestant: half_away, value: 2.5)

      described_class.run(Line.pending)

      expect(line.reload).to be_pending
    end

    it "leaves a second half line pending" do
      line = create_spread(game: half_played, contestant: half_away, value: 2.5, scope: :second_half)

      described_class.run(Line.pending)

      expect(line.reload).to be_pending
    end

    it "settles the first half, which is what the half time write is for" do
      line = create_spread(game: half_played, contestant: half_away, value: 2.5, scope: :first_half)

      described_class.run(Line.pending)

      expect(line.reload).to be_win # 10 + 2.5 > 10
    end
  end

  it "skips a contestant whose scores are still empty" do
    other_game = create_game(starts_at: 4.hours.ago, completed_at: 1.hour.ago)
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
