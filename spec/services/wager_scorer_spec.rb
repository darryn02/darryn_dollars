require "rails_helper"

RSpec.describe WagerScorer, type: :service do
  let(:user) { create_user }
  let!(:account) { create_account(user: user) }
  let(:game) { create_game(starts_at: 2.hours.ago) }
  let(:away) { game.contestants.order(:priority).first }

  def wager_on(line, amount: 100)
    create_wager(account: account, line: line, amount: amount, status: :confirmed)
  end

  it "settles a confirmed wager as a win, with net equal to the payout" do
    line = create_spread(game: game, contestant: away, value: 2.5, odds: -110)
    line.win!
    wager = wager_on(line, amount: 110)

    described_class.run(Wager.confirmed)

    expect(wager.reload).to be_win
    expect(wager.net).to eq(line.payout(110))
  end

  it "settles a confirmed wager as a loss, with net equal to minus the stake" do
    line = create_spread(game: game, contestant: away, value: 2.5)
    line.loss!
    wager = wager_on(line, amount: 100)

    described_class.run(Wager.confirmed)

    expect(wager.reload).to be_loss
    expect(wager.net).to eq(-100)
  end

  it "settles a confirmed wager as a push, with no net change" do
    line = create_spread(game: game, contestant: away, value: 2.5)
    line.push!
    wager = wager_on(line, amount: 100)

    described_class.run(Wager.confirmed)

    expect(wager.reload).to be_push
    expect(wager.net).to eq(0)
  end

  it "leaves a wager on a still-pending line untouched" do
    line = create_spread(game: game, contestant: away, value: 2.5)
    wager = wager_on(line, amount: 100)

    described_class.run(Wager.confirmed)

    expect(wager.reload).to be_confirmed
  end

  it "returns a summary of what it scored" do
    win_line = create_spread(game: game, contestant: away, value: 2.5)
    win_line.win!
    wager_on(win_line)

    loss_line = create_spread(game: game, contestant: away, value: 3.5)
    loss_line.loss!
    wager_on(loss_line)

    message = described_class.run(Wager.confirmed)

    expect(message).to eq("Wagers scored: 1 wins, 1 losses, 0 pushes.")
  end
end
