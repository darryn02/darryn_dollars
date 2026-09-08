require "rails_helper"

RSpec.describe Leaderboard, type: :model do
  let(:competitor) { Competitor.create!(sport: :nfl, region: "Buffalo", name: "Bills", abbreviation: "BUF") }
  let(:game) { Game.create!(sport: :nfl, starts_at: 3.days.ago) }
  let(:contestant) { game.contestants.create!(competitor: competitor, priority: 0) }

  def account_named(name, email)
    user = User.create!(name: name, email: email, mobile: "+1202555#{rand(1000..9999)}",
                        password: "password123", password_confirmation: "password123")
    user.accounts.create!(credit_limit: 1_000, initial_balance: 0, leaderboard_visible: true)
  end

  def settle(account, status, placed_at:)
    slip = BetSlip.create!(account: account, status: :confirmed)
    line = game.lines.create!(kind: :point_spread, scope: :game, value: -3.0, contestant: contestant)
    wager = Wager.new(account: account, bet_slip: slip, line: line, amount: 100)
    wager.save!(validate: false)
    wager.update_columns(status: Wager.statuses[status], placed_at: placed_at, net: 0)
  end

  def this_week(offset) = LeaderboardEntry.week_start + offset.hours

  def labels_for(entries, account)
    entries.find { |entry| entry.account == account }.badges.map(&:label)
  end

  it "ranks in the order it is given" do
    first = account_named("First", "first@example.com")
    second = account_named("Second", "second@example.com")

    entries = described_class.build([first, second])

    expect(entries.map(&:rank)).to eq([1, 2])
    expect(entries.map(&:podium?)).to eq([true, true])
  end

  it "marks a hot streak once three in a row have landed" do
    hot = account_named("Hot", "hot@example.com")
    3.times { |i| settle(hot, :win, placed_at: this_week(i + 1)) }

    expect(labels_for(described_class.build([hot]), hot)).to include("3 straight")
  end

  it "does not call a two-win run a streak" do
    warm = account_named("Warm", "warm@example.com")
    2.times { |i| settle(warm, :win, placed_at: this_week(i + 1)) }

    expect(labels_for(described_class.build([warm]), warm)).
      not_to include(a_string_matching(/straight/))
  end

  it "gives the best week to the account with the most wins" do
    strong = account_named("Strong", "strong@example.com")
    weak = account_named("Weak", "weak@example.com")
    2.times { |i| settle(strong, :win, placed_at: this_week(i + 1)) }
    settle(weak, :win, placed_at: this_week(1))
    settle(weak, :loss, placed_at: this_week(2))

    entries = described_class.build([strong, weak])

    expect(labels_for(entries, strong)).to include("Best week (2-0)")
    expect(labels_for(entries, weak)).not_to include(a_string_matching(/Best week/))
  end

  it "hands out most action only above the minimum" do
    busy = account_named("Busy", "busy@example.com")
    quiet = account_named("Quiet", "quiet@example.com")
    %i[win loss push loss].each_with_index { |s, i| settle(busy, s, placed_at: this_week(i + 1)) }
    settle(quiet, :loss, placed_at: this_week(1))

    entries = described_class.build([busy, quiet])

    expect(labels_for(entries, busy)).to include("Most action (4)")
    expect(labels_for(entries, quiet)).to be_empty
  end

  # The whole point of the badge set: it can only ever say something good.
  it "never badges a bad week or a losing run" do
    cold = account_named("Cold", "cold@example.com")
    4.times { |i| settle(cold, :loss, placed_at: this_week(i + 1)) }

    entries = described_class.build([cold])

    expect(labels_for(entries, cold)).to all(match(/Most action/))
  end
end
