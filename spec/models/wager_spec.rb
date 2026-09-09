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

  describe "waiving the vig" do
    let(:user) { create_user }
    let(:account) { create_account(user: user) }
    let(:game) { create_game(starts_at: 2.hours.ago) }
    let(:away) { game.contestants.order(:priority).first }

    # -110 is already vig-free on the win side - a $110 stake nets exactly
    # $100, same as true pick'em odds would. The vig only ever shows up on
    # the loss side, at the full $110 stake.
    let(:minus_110) { create_spread(game: game, contestant: away, value: -3.0, odds: -110) }

    it "does not change a loss at all until waived" do
      wager = create_wager(account: account, line: minus_110, amount: 110, status: :loss)

      expect(wager.net).to eq(-110)
    end

    it "caps a loss at what a win would have paid once waived" do
      wager = create_wager(account: account, line: minus_110, amount: 110, status: :loss)

      wager.update!(vig_waived: true)

      expect(wager.net).to eq(-100)
    end

    it "leaves a win untouched - there was no vig on that side to waive" do
      wager = create_wager(account: account, line: minus_110, amount: 110, status: :win)
      net_before = wager.net

      wager.update!(vig_waived: true)

      expect(wager.net).to eq(net_before)
      expect(wager.net).to eq(100)
    end

    it "leaves a push at zero" do
      wager = create_wager(account: account, line: minus_110, amount: 110, status: :push)

      wager.update!(vig_waived: true)

      expect(wager.net).to eq(0)
    end

    # The safety the min() in loss_amount exists for: on a positive-odds
    # underdog line, potential_profit is larger than the stake, so waiving
    # the vig must not raise what a loss costs above what was risked.
    it "never makes a loss cost more than the stake, even on a plus-money line" do
      underdog = create_spread(game: game, contestant: away, value: 3.0, odds: 150)
      wager = create_wager(account: account, line: underdog, amount: 100, status: :loss)

      wager.update!(vig_waived: true)

      expect(wager.net).to eq(-100)
    end

    it "credits a bet retroactively, after it has already settled" do
      wager = create_wager(account: account, line: minus_110, amount: 110, status: :loss)
      expect(wager.net).to eq(-110)

      wager.update!(vig_waived: true)

      expect(wager.reload.net).to eq(-100)
    end

    it "reverts cleanly when the waiver is cleared" do
      wager = create_wager(account: account, line: minus_110, amount: 110, status: :loss)
      wager.update!(vig_waived: true)

      wager.update!(vig_waived: false)

      expect(wager.net).to eq(-110)
    end
  end

  describe ".matching_scope" do
    let(:user) { create_user }
    let(:account) { create_account(user: user) }
    let(:game) { create_game(starts_at: 2.hours.from_now) }
    let(:other_game) { create_game(starts_at: 2.hours.from_now,
                                   away: create_competitor(region: "Dallas", name: "Cowboys", abbreviation: "DAL"),
                                   home: create_competitor(region: "New York", name: "Giants", abbreviation: "NYG")) }
    let(:card) { create_full_card(game: game) }

    it "matches only the exact line for scope_type line" do
      wager = create_wager(account: account, line: card[:away_spread])
      create_wager(account: account, line: card[:over])

      matched = Wager.matching_scope(scope_type: "line", line_id: card[:away_spread].id)

      expect(matched).to eq([wager])
    end

    it "groups over and under together under the total kind, for a whole game" do
      over_wager = create_wager(account: account, line: card[:over])
      under_wager = create_wager(account: account, line: card[:under])
      create_wager(account: account, line: card[:away_spread])

      matched = Wager.matching_scope(scope_type: "game", game_id: game.id, kind_group: "total")

      expect(matched).to match_array([over_wager, under_wager])
    end

    it "does not reach into a different game" do
      create_wager(account: account, line: card[:away_spread])
      other_card = create_full_card(game: other_game)
      other_wager = create_wager(account: account, line: other_card[:away_spread])

      matched = Wager.matching_scope(scope_type: "game", game_id: other_game.id, kind_group: "spread")

      expect(matched).to eq([other_wager])
    end

    it "matches every game on the given calendar day, for the day scope" do
      wager = create_wager(account: account, line: card[:away_spread])
      other_card = create_full_card(game: other_game)
      other_wager = create_wager(account: account, line: other_card[:away_spread])

      matched = Wager.matching_scope(
        scope_type: "day", date: game.starts_at.in_time_zone("America/New_York").to_date, kind_group: "spread"
      )

      expect(matched).to match_array([wager, other_wager])
    end

    it "excludes a canceled wager regardless of scope" do
      create_wager(account: account, line: card[:away_spread], status: :canceled)

      matched = Wager.matching_scope(scope_type: "game", game_id: game.id, kind_group: "spread")

      expect(matched).to be_empty
    end
  end
end
