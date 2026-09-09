require "rails_helper"

RSpec.describe Wager, type: :model do
  describe "confirming a second half wager" do
    let(:user) do
      User.create!(name: "Player", email: "player@example.com", mobile: "+12025550100",
                   password: "password123", password_confirmation: "password123")
    end
    let(:account) { user.accounts.create!(credit_limit: 1_000, initial_balance: 0) }
    let(:bet_slip) { BetSlip.create!(account: account, status: :pending) }

    let(:competitor) { Competitor.create!(sport: :nfl, region: "Buffalo", name: "Bills", abbreviation: "BUF") }
    let(:game) { Game.create!(sport: :nfl, starts_at: 90.minutes.ago) }
    let(:contestant) { game.contestants.create!(competitor: competitor, priority: 0) }
    let(:line) { game.lines.create!(kind: :point_spread, scope: :second_half, value: -3.0, contestant: contestant) }

    let(:wager) { Wager.create!(account: account, bet_slip: bet_slip, line: line, amount: 100) }

    def espn_says_second_half_started(started)
      allow_any_instance_of(Game).to receive(:second_half_started?).and_return(started)
    end

    it "goes through while the first half is still on" do
      espn_says_second_half_started(false)

      expect { wager.confirmed! }.not_to raise_error
      expect(wager.reload).to be_confirmed
    end

    it "is rejected once the second half has kicked off" do
      espn_says_second_half_started(true)

      expect { wager.confirmed! }.to raise_error(ActiveRecord::RecordInvalid, /second half has started/)
      expect(wager.reload).to be_pending
    end

    it "fails closed when ESPN cannot be reached" do
      allow_any_instance_of(Game).to receive(:second_half_started?).and_raise(EspnScoreboard::Unavailable)

      expect { wager.confirmed! }.to raise_error(ActiveRecord::RecordInvalid, /could not be verified/)
      expect(wager.reload).to be_pending
    end

    it "does not consult ESPN for a full game line" do
      full_game_line = game.lines.create!(kind: :point_spread, scope: :game, value: -3.0, contestant: contestant)
      other = Wager.create!(account: account, bet_slip: bet_slip, line: full_game_line, amount: 100)
      expect_any_instance_of(Game).not_to receive(:second_half_started?)

      # The game started 90 minutes ago, so the existing start-time rule applies.
      expect { other.confirmed! }.to raise_error(ActiveRecord::RecordInvalid, /past game start time/)
    end

    it "does not consult ESPN when merely adding to a bet slip" do
      expect_any_instance_of(Game).not_to receive(:second_half_started?)

      expect(Wager.create!(account: account, bet_slip: bet_slip, line: line, amount: 100)).to be_pending
    end
  end

  describe "confirming other kinds of wager" do
    let(:user) { create_user }
    let(:account) { create_account(user: user, credit_limit: 200) }
    let(:game) { create_game(starts_at: 2.hours.from_now) }
    let(:card) { create_full_card(game: game) }

    before { allow_any_instance_of(Game).to receive(:second_half_started?).and_return(false) }

    it "rejects confirming a wager once the game has started" do
      wager = create_wager(account: account, line: card[:away_spread], amount: 100)

      Timecop.travel(game.starts_at + 1.minute) do
        expect { wager.confirmed! }.to raise_error(ActiveRecord::RecordInvalid, /past game start time/)
      end
    end

    it "rejects confirming a wager on a line that has since been hidden" do
      wager = create_wager(account: account, line: card[:away_spread], amount: 100)
      card[:away_spread].update!(hidden: true)

      expect { wager.confirmed! }.to raise_error(ActiveRecord::RecordInvalid, /no longer active/)
    end

    # credit_limit(200) + balance(0) - liabilities(0) has to clear the stake.
    it "rejects confirming a wager the account has no credit for" do
      wager = create_wager(account: account, line: card[:away_spread], amount: 250)

      expect { wager.confirmed! }.to raise_error(ActiveRecord::RecordInvalid, /insufficient credit/)
    end

    it "confirms a wager comfortably inside the account's credit" do
      wager = create_wager(account: account, line: card[:away_spread], amount: 100)

      expect { wager.confirmed! }.not_to raise_error
      expect(wager.reload).to be_confirmed
    end
  end
end
