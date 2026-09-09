require "rails_helper"

RSpec.describe PointSpreadScorer, type: :service do
  let(:game) { create_game(starts_at: 2.hours.ago) }
  let(:away) { game.contestants.order(:priority).first }
  let(:home) { game.contestants.order(:priority).second }

  def spread_for(contestant, value, scope: :game)
    create_spread(game: game, contestant: contestant, value: value, scope: scope)
  end

  describe "at game scope" do
    it "wins the line when the contestant covers" do
      away.update!(scores: [10, 10])
      home.update!(scores: [7, 7])
      line = spread_for(away, 2.5)

      results = described_class.run(line)

      expect(line.reload).to be_win
      expect(results).to eq(wins: 1, losses: 0, pushes: 0)
    end

    it "loses the line when the contestant does not cover" do
      away.update!(scores: [0, 0])
      home.update!(scores: [10, 10])
      line = spread_for(away, 2.5)

      results = described_class.run(line)

      expect(line.reload).to be_loss
      expect(results).to eq(wins: 0, losses: 1, pushes: 0)
    end

    it "pushes the line when the spread lands exactly on the margin" do
      away.update!(scores: [7, 0])
      home.update!(scores: [10, 0])
      line = spread_for(away, 3.0)

      results = described_class.run(line)

      expect(line.reload).to be_push
      expect(results).to eq(wins: 0, losses: 0, pushes: 1)
    end
  end

  it "reads only the first two quarters at first-half scope" do
    away.update!(scores: [10, 0, 100, 0])
    home.update!(scores: [0, 0, 0, 0])
    line = spread_for(away, -5.0, scope: :first_half)

    described_class.run(line)

    expect(line.reload).to be_win
  end

  it "reads from the third quarter onward at second-half scope" do
    away.update!(scores: [0, 0, 0, 10])
    home.update!(scores: [100, 0, 0, 0])
    line = spread_for(away, -5.0, scope: :second_half)

    described_class.run(line)

    expect(line.reload).to be_win
  end

  # `scores` defaults to `[]`, not nil, and `[].sum` is 0 - which is not
  # `blank?`. So the pending branch below is never reached through an
  # unplayed contestant's real default; it would only fire if a score were
  # literally nil, which the schema does not allow. LineScorer never hits
  # this because it filters to games with at least one non-empty score
  # array before it ever calls a scorer - but calling this class directly
  # on two still-scoreless contestants resolves the line by the raw spread,
  # as if the game had ended 0-0.
  it "resolves by the spread alone when both contestants still show their default empty score" do
    line = spread_for(away, 2.5)

    results = described_class.run(line)

    expect(line.reload).to be_win
    expect(results).to eq(wins: 1, losses: 0, pushes: 0)
  end

  # The orphan case at the service layer: `lines` has on_delete: :nullify
  # against contestants, so a spread's contestant_id can point at nobody in
  # this game at all. Scoring it should log and move on, not blow up the run.
  it "logs and returns nothing when the line's contestant is not one of the game's" do
    away.update!(scores: [10, 10])
    home.update!(scores: [7, 7])
    line = spread_for(away, 2.5)
    line.update_column(:contestant_id, nil)

    expect(Rails.logger).to receive(:error).with(/did not match a game contestant/)

    result = nil
    expect { result = described_class.run(line) }.not_to raise_error
    expect(result).to be_nil
    expect(line.reload).to be_pending
  end
end
