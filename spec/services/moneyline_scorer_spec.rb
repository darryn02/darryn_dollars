require "rails_helper"

RSpec.describe MoneylineScorer, type: :service do
  # A deliberate no-op: moneylines exist on the board but are not part of
  # settlement yet. This pins that down so it stays a decision, not a gap
  # nobody noticed.
  it "returns a zero tally and leaves the line untouched" do
    game = create_game(starts_at: 2.hours.ago)
    away = game.contestants.order(:priority).first
    away.update!(scores: [24])

    line = create_total(game: game, kind: :moneyline, value: 0)

    results = described_class.new(line).run

    expect(results).to eq(wins: 0, losses: 0, pushes: 0)
    expect(line.reload).to be_pending
  end
end
