require "rails_helper"

RSpec.describe UnderScorer, type: :service do
  let(:game) { create_game(starts_at: 2.hours.ago) }
  let(:away) { game.contestants.order(:priority).first }
  let(:home) { game.contestants.order(:priority).second }

  def total_for(value, scope: :game)
    create_total(game: game, kind: :under, value: value, scope: scope)
  end

  it "wins when the combined score is below the total" do
    away.update!(scores: [10])
    home.update!(scores: [7])
    line = total_for(44.5)

    results = described_class.run(line)

    expect(line.reload).to be_win
    expect(results).to eq(wins: 1, losses: 0, pushes: 0)
  end

  it "loses when the combined score is above the total" do
    away.update!(scores: [24])
    home.update!(scores: [21])
    line = total_for(44.5)

    results = described_class.run(line)

    expect(line.reload).to be_loss
    expect(results).to eq(wins: 0, losses: 1, pushes: 0)
  end

  it "pushes when the combined score lands exactly on the total" do
    away.update!(scores: [24])
    home.update!(scores: [21])
    line = total_for(45.0)

    results = described_class.run(line)

    expect(line.reload).to be_push
    expect(results).to eq(wins: 0, losses: 0, pushes: 1)
  end

  it "reads only the first two quarters at first-half scope" do
    away.update!(scores: [0, 0, 100, 0])
    home.update!(scores: [0, 0, 0, 0])
    line = total_for(10.0, scope: :first_half)

    described_class.run(line)

    expect(line.reload).to be_win
  end

  it "reads from the third quarter onward at second-half scope" do
    away.update!(scores: [20, 0, 0, 0])
    home.update!(scores: [0, 0, 0, 0])
    line = total_for(10.0, scope: :second_half)

    described_class.run(line)

    expect(line.reload).to be_win
  end

  # Half time writes only the periods that are in, so a second half line spends
  # a stretch of every game with nothing to add up. Grading it then would
  # settle it 0-0 while the third quarter was being played.
  it "leaves a second half total pending while only the first half is in" do
    away.update!(scores: [10, 10])
    home.update!(scores: [7, 7])
    line = total_for(10.0, scope: :second_half)

    results = described_class.run(line)

    expect(line.reload).to be_pending
    expect(results).to eq(wins: 0, losses: 0, pushes: 0)
  end
end
