require "rails_helper"

RSpec.describe LeaderboardEntry, type: :model do
  let(:user) do
    User.create!(name: "Player", email: "player@example.com", mobile: "+12025550100",
                 password: "password123", password_confirmation: "password123")
  end
  let(:account) { user.accounts.create!(credit_limit: 1_000, initial_balance: 0) }
  let(:slip) { BetSlip.create!(account: account, status: :confirmed) }

  let(:competitor) { Competitor.create!(sport: :nfl, region: "Buffalo", name: "Bills", abbreviation: "BUF") }
  let(:game) { Game.create!(sport: :nfl, starts_at: 3.days.ago) }
  let(:contestant) { game.contestants.create!(competitor: competitor, priority: 0) }

  def settled(status, placed_at:)
    line = game.lines.create!(kind: :point_spread, scope: :game, value: -3.0, contestant: contestant)
    wager = Wager.new(account: account, bet_slip: slip, line: line, amount: 100)
    wager.save!(validate: false)
    wager.update_columns(status: Wager.statuses[status], placed_at: placed_at, net: 0)
    wager
  end

  def entry
    described_class.new(account: account.reload, rank: 1)
  end

  describe "#week_record" do
    it "counts only what settled since the week turned over" do
      settled(:win,  placed_at: described_class.week_start + 1.hour)
      settled(:win,  placed_at: described_class.week_start + 2.hours)
      settled(:loss, placed_at: described_class.week_start + 3.hours)
      settled(:push, placed_at: described_class.week_start + 4.hours)
      settled(:win,  placed_at: described_class.week_start - 2.days)

      expect(entry.week_record).to eq(win: 2, loss: 1, push: 1)
    end

    it "reads as a record once something has settled" do
      settled(:win,  placed_at: described_class.week_start + 1.hour)
      settled(:win,  placed_at: described_class.week_start + 2.hours)
      settled(:loss, placed_at: described_class.week_start + 3.hours)

      expect(entry.week_summary).to eq("2-1 this week")
    end

    it "mentions pushes only when there are some" do
      settled(:win,  placed_at: described_class.week_start + 1.hour)
      settled(:push, placed_at: described_class.week_start + 2.hours)

      expect(entry.week_summary).to eq("1-0-1 this week")
    end

    it "says so plainly when nothing has settled yet" do
      expect(entry.week_summary).to eq("No bets settled this week")
    end
  end

  describe "#form" do
    it "keeps only the last five results, oldest first" do
      %i[win loss win win loss push].each_with_index do |status, index|
        settled(status, placed_at: 10.days.ago + index.hours)
      end

      expect(entry.form).to eq(%i[loss win win loss push])
    end

    it "ignores wagers that have not settled" do
      line = game.lines.create!(kind: :point_spread, scope: :game, value: -3.0, contestant: contestant)
      Wager.create!(account: account, bet_slip: slip, line: line, amount: 100)

      expect(entry.form).to be_empty
    end
  end

  describe "#current_win_streak" do
    it "counts back from the most recent result" do
      settled(:loss, placed_at: 5.days.ago)
      settled(:win,  placed_at: 4.days.ago)
      settled(:win,  placed_at: 3.days.ago)
      settled(:win,  placed_at: 2.days.ago)

      expect(entry.current_win_streak).to eq(3)
    end

    it "is zero when the most recent bet lost" do
      settled(:win,  placed_at: 4.days.ago)
      settled(:loss, placed_at: 3.days.ago)

      expect(entry.current_win_streak).to be_zero
    end
  end
end
