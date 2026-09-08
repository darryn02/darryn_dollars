require "rails_helper"

RSpec.describe GameLinesViewModel, type: :model do
  let(:user) do
    User.create!(name: "Player", email: "player@example.com", mobile: "+12025550100",
                 admin: true, password: "password123", password_confirmation: "password123")
  end

  let(:away) { Competitor.create!(sport: :nfl, region: "Buffalo", name: "Bills", abbreviation: "BUF") }
  let(:home) { Competitor.create!(sport: :nfl, region: "Miami", name: "Dolphins", abbreviation: "MIA") }
  let(:game) { Game.create!(sport: :nfl, starts_at: 2.hours.from_now) }

  let!(:away_contestant) { game.contestants.create!(competitor: away, priority: 0) }
  let!(:home_contestant) { game.contestants.create!(competitor: home, priority: 1) }

  def spread_for(contestant, value)
    game.lines.create!(kind: :point_spread, scope: :game, value: value, contestant: contestant)
  end

  def total(kind, value)
    game.lines.create!(kind: kind, scope: :game, value: value)
  end

  def view_model(lines)
    described_class.new(game: game, lines: lines, user: user)
  end

  describe "#rows" do
    it "puts the away side first and the home side second" do
      lines = [spread_for(away_contestant, 2.5), spread_for(home_contestant, -2.5)]

      rows = view_model(lines).rows

      expect(rows.map(&:abbreviation)).to eq(%w[BUF MIA])
      expect(rows.map { |row| row.spread.value }).to eq([2.5, -2.5])
    end

    it "hangs the over on the first row and the under on the second" do
      lines = [
        spread_for(away_contestant, 2.5), spread_for(home_contestant, -2.5),
        total(:over, 47.5), total(:under, 47.5)
      ]

      rows = view_model(lines).rows

      expect(rows.first.total).to be_over
      expect(rows.second.total).to be_under
    end

    # The old board built its rows with each_cons(2) over the spread lines, so a
    # game in this state rendered nothing at all - the over/under went with it.
    it "still names both teams when only one side has a spread" do
      lines = [spread_for(away_contestant, 2.5), total(:over, 47.5), total(:under, 47.5)]

      rows = view_model(lines).rows

      expect(rows.map(&:abbreviation)).to eq(%w[BUF MIA])
      expect(rows.first.spread).to be_present
      expect(rows.second.spread).to be_nil
      expect(rows.second.total).to be_under
    end

    # `lines` has on_delete: :nullify against contestants, so a spread can
    # outlive the side it belonged to. The board used to raise NoMethodError
    # sorting these by contestant.priority, taking the whole page down.
    it "drops a spread that has lost its contestant rather than raising" do
      keeper = spread_for(away_contestant, 2.5)
      orphan = spread_for(home_contestant, -2.5)
      orphan.update_columns(contestant_id: nil)

      rows = nil
      expect { rows = view_model([keeper, orphan]).rows }.not_to raise_error

      expect(rows.map(&:abbreviation)).to eq(%w[BUF MIA])
      expect(rows.first.spread).to eq(keeper)
      expect(rows.second.spread).to be_nil
    end

    it "survives a game whose contestants are gone entirely" do
      lines = [total(:over, 47.5), total(:under, 47.5)]
      Contestant.where(game_id: game.id).delete_all
      game.reload

      rows = nil
      expect { rows = described_class.new(game: game, lines: lines, user: user).rows }.
        not_to raise_error

      expect(rows.map(&:abbreviation)).to eq([nil, nil])
      expect(rows.map { |row| row.total.value }).to eq([47.5, 47.5])
    end

    it "still shows the totals when neither side has a spread" do
      lines = [total(:over, 47.5), total(:under, 47.5)]

      rows = view_model(lines).rows

      expect(rows.map(&:abbreviation)).to eq(%w[BUF MIA])
      expect(rows.map(&:spread)).to eq([nil, nil])
      expect(rows.map { |row| row.total.value }).to eq([47.5, 47.5])
    end
  end

  describe "#status_label" do
    def view_model_for(starts_at)
      game.update!(starts_at: starts_at)
      view_model([spread_for(away_contestant, 2.5)])
    end

    it "says nothing while betting is open" do
      expect(view_model_for(2.hours.from_now).status_label).to be_nil
    end

    # "Closed" on a game two days out reads as "you missed it", when it means
    # the opposite: betting has not started yet.
    it "says when betting opens for a game outside the window" do
      opens = 3.days.from_now
      label = view_model_for(opens + Wager::WINDOW).status_label

      expect(label).to start_with("Opens")
      expect(label).to include(opens.strftime("%a"))
    end

    it "says closed once the game has been under way too long" do
      expect(view_model_for(4.hours.ago).status_label).to eq("Closed")
    end
  end

  describe "#bet_lines" do
    it "lists each line that gets a button, once" do
      spread_away = spread_for(away_contestant, 2.5)
      spread_home = spread_for(home_contestant, -2.5)
      over = total(:over, 47.5)
      under = total(:under, 47.5)

      expect(view_model([spread_away, spread_home, over, under]).bet_lines).
        to match_array([spread_away, spread_home, over, under])
    end

    it "is empty once the game is no longer wagerable" do
      game.update!(starts_at: 4.hours.ago)
      lines = [spread_for(away_contestant, 2.5), spread_for(home_contestant, -2.5)]

      expect(view_model(lines).bet_lines).to be_empty
    end
  end

  describe "the chump money flag" do
    let(:chump) do
      User.create!(name: "Chump", email: "chump@example.com", mobile: "+12025550101",
                   password: "password123", password_confirmation: "password123")
    end
    let(:chump_account) { chump.accounts.create!(credit_limit: 1_000, initial_balance: 0) }
    let(:slip) { BetSlip.create!(account: chump_account, status: :pending) }

    it "marks the side carrying more chump money" do
      favoured = spread_for(away_contestant, 2.5)
      other = spread_for(home_contestant, -2.5)
      Wager.create!(account: chump_account, bet_slip: slip, line: favoured, amount: 300)
      Wager.create!(account: chump_account, bet_slip: slip, line: other, amount: 50)

      rows = view_model([favoured, other]).rows

      expect(rows.first.spread_flagged).to be(true)
      expect(rows.second.spread_flagged).to be(false)
    end

    it "stays hidden from the chumps themselves" do
      favoured = spread_for(away_contestant, 2.5)
      other = spread_for(home_contestant, -2.5)
      Wager.create!(account: chump_account, bet_slip: slip, line: favoured, amount: 300)

      rows = described_class.new(game: game, lines: [favoured, other], user: chump).rows

      expect(rows.map(&:spread_flagged)).to all(be(false))
    end
  end
end
