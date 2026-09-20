require "rails_helper"

RSpec.describe MoneylineScorer, type: :service do
  let(:game) { create_game(starts_at: 4.hours.ago, completed_at: 1.hour.ago) }
  let(:away) { game.contestants.order(:priority).first }
  let(:home) { game.contestants.order(:priority).second }

  def moneyline_for(contestant, odds, scope: :game)
    create_moneyline(game: game, contestant: contestant, odds: odds, scope: scope)
  end

  describe "at game scope" do
    it "wins the favorite's line when the favorite wins the game" do
      away.update!(scores: [14, 10])
      home.update!(scores: [7, 7])
      line = moneyline_for(away, -285)

      results = described_class.run(line)

      expect(line.reload).to be_win
      expect(results).to eq(wins: 1, losses: 0, pushes: 0)
    end

    it "wins the underdog's line when the underdog wins the game" do
      away.update!(scores: [7, 7])
      home.update!(scores: [14, 10])
      line = moneyline_for(home, 240)

      results = described_class.run(line)

      expect(line.reload).to be_win
      expect(results).to eq(wins: 1, losses: 0, pushes: 0)
    end

    it "loses the line when the contestant loses the game" do
      away.update!(scores: [7, 7])
      home.update!(scores: [14, 10])
      line = moneyline_for(away, -285)

      results = described_class.run(line)

      expect(line.reload).to be_loss
      expect(results).to eq(wins: 0, losses: 1, pushes: 0)
    end

    # A moneyline is a spread of zero, so a drawn game pushes both sides.
    # Rare at game scope and routine at second half scope.
    it "pushes the line when the game is tied" do
      away.update!(scores: [10, 7])
      home.update!(scores: [7, 10])
      line = moneyline_for(away, -110)

      results = described_class.run(line)

      expect(line.reload).to be_push
      expect(results).to eq(wins: 0, losses: 0, pushes: 1)
    end
  end

  it "reads only the first two quarters at first-half scope" do
    away.update!(scores: [10, 0, 100, 0])
    home.update!(scores: [0, 0, 0, 0])
    line = moneyline_for(away, -150, scope: :first_half)

    described_class.run(line)

    expect(line.reload).to be_win
  end

  it "reads from the third quarter onward at second-half scope" do
    away.update!(scores: [0, 0, 0, 10])
    home.update!(scores: [100, 0, 0, 0])
    line = moneyline_for(away, -150, scope: :second_half)

    described_class.run(line)

    expect(line.reload).to be_win
  end

  it "pushes a second half that ended level, whatever the full game did" do
    away.update!(scores: [21, 0, 7, 0])
    home.update!(scores: [0, 0, 0, 7])
    line = moneyline_for(away, -150, scope: :second_half)

    results = described_class.run(line)

    expect(line.reload).to be_push
    expect(results).to eq(wins: 0, losses: 0, pushes: 1)
  end

  # The value column is NOT NULL, so every moneyline carries one, and a
  # moneyline that read its handicap off that column would grade as a spread
  # the moment a bad payload or a hand-corrected kind put something there.
  it "ignores a stray value on the line rather than treating it as a handicap" do
    away.update!(scores: [21])
    home.update!(scores: [24])
    line = moneyline_for(away, -150)
    line.update_columns(value: 7.5)

    described_class.run(line.reload)

    expect(line.reload).to be_loss
  end

  it "leaves the line pending when neither contestant has played a period yet" do
    line = moneyline_for(away, -150)

    results = described_class.run(line)

    expect(line.reload).to be_pending
    expect(results).to eq(wins: 0, losses: 0, pushes: 0)
  end

  # The contestant FK nullifies on delete, so this row is reachable without
  # anyone doing anything wrong. PointSpreadScorer returns nil here, which
  # LineScorer#run calls .fetch on - one orphaned row would abort settlement
  # for every pending line of every kind. A zero tally keeps the run alive.
  it "returns a zero tally rather than nil when no contestant matches" do
    away.update!(scores: [24])
    home.update!(scores: [21])
    line = moneyline_for(away, -150)
    line.update_columns(contestant_id: nil)

    results = described_class.run(line.reload)

    expect(results).to eq(wins: 0, losses: 0, pushes: 0)
    expect(line.reload).to be_pending
  end

  it "does not abort a scoring run that also holds a spread and a total" do
    away.update!(scores: [24])
    home.update!(scores: [21])
    orphan = moneyline_for(away, -150)
    orphan.update_columns(contestant_id: nil)
    spread = create_spread(game: game, contestant: away, value: 2.5)
    over = create_total(game: game, kind: :over, value: 40.5)

    expect { LineScorer.run(Line.pending) }.not_to raise_error

    expect(spread.reload).to be_win
    expect(over.reload).to be_win
    expect(orphan.reload).to be_pending
  end

  # The whole point of Phase 1: before this, a confirmed moneyline wager sat
  # confirmed forever, permanently inside Account#liabilities.
  describe "end to end through LineScorer and WagerScorer" do
    let(:user) { create_user }
    let!(:account) { create_account(user: user) }

    it "settles a confirmed wager on a winning moneyline and releases the liability" do
      away.update!(scores: [24])
      home.update!(scores: [21])
      line = moneyline_for(away, 240)
      wager = create_wager(account: account, line: line, amount: 100, status: :confirmed)

      expect(account.reload.liabilities).to eq(100)

      LineScorer.run(Line.pending)
      WagerScorer.run(Wager.confirmed)

      expect(line.reload).to be_win
      expect(wager.reload).to be_win
      expect(wager.net).to eq(line.payout(100))
      expect(account.reload.liabilities).to eq(0)
    end

    it "settles a confirmed wager on a losing moneyline and releases the liability" do
      away.update!(scores: [21])
      home.update!(scores: [24])
      line = moneyline_for(away, 240)
      wager = create_wager(account: account, line: line, amount: 100, status: :confirmed)

      LineScorer.run(Line.pending)
      WagerScorer.run(Wager.confirmed)

      expect(line.reload).to be_loss
      expect(wager.reload).to be_loss
      expect(wager.net).to eq(-100)
      expect(account.reload.liabilities).to eq(0)
    end
  end
end
