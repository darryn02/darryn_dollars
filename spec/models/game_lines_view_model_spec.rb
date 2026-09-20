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

  def moneyline_for(contestant, odds)
    game.lines.create!(kind: :moneyline, scope: :game, value: 0, odds: odds, contestant: contestant)
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

  describe "the moneyline column" do
    it "hangs each side's price on its own row" do
      lines = [moneyline_for(away_contestant, -285), moneyline_for(home_contestant, 240)]

      rows = view_model(lines).rows

      expect(rows.map(&:abbreviation)).to eq(%w[BUF MIA])
      expect(rows.map { |row| row.moneyline&.odds }).to eq([-285, 240])
      expect(rows.map(&:moneyline_offered)).to eq([true, true])
    end

    it "offers both sides through bet_lines" do
      lines = [moneyline_for(away_contestant, -285), moneyline_for(home_contestant, 240)]

      expect(view_model(lines).bet_lines.map(&:odds)).to match_array([-285, 240])
    end

    it "names a side that has a moneyline but no spread" do
      rows = view_model([moneyline_for(home_contestant, 240)]).rows

      expect(rows.map(&:abbreviation)).to eq(%w[BUF MIA])
    end

    describe "an underdog past the cap" do
      let(:lines) { [moneyline_for(away_contestant, -5819), moneyline_for(home_contestant, 450)] }

      it "keeps its price on its own row rather than disappearing" do
        rows = view_model(lines).rows

        expect(rows.second.moneyline.odds).to eq(450)
        expect(rows.second.moneyline_offered).to be(false)
      end

      # The one that would put the right price against the wrong team.
      # rows pairs positionally against competitors.first/.second, so
      # filtering the withheld dog out before pairing would slide the
      # favorite down onto the underdog's row.
      it "leaves its partner where it belongs instead of shifting it" do
        rows = view_model(lines).rows

        expect(rows.first.abbreviation).to eq("BUF")
        expect(rows.first.moneyline.odds).to eq(-5819)
      end

      it "gets no bet button while its partner keeps one" do
        # -5819 is past the favorite bound too, so widen it for this case.
        ENV["MONEYLINE_MIN_ODDS"] = "-9999"

        offered = view_model(lines).bet_lines.select(&:moneyline?)

        expect(offered.map(&:odds)).to eq([-5819])
      ensure
        ENV.delete("MONEYLINE_MIN_ODDS")
      end
    end

    it "withholds a favorite past the bound while keeping its price" do
      lines = [moneyline_for(away_contestant, -1200), moneyline_for(home_contestant, 900)]

      rows = view_model(lines).rows

      expect(rows.first.moneyline.odds).to eq(-1200)
      expect(rows.map(&:moneyline_offered)).to eq([false, false])
      expect(view_model(lines).bet_lines.select(&:moneyline?)).to be_empty
    end

    it "offers nothing when the switch is off" do
      ENV["MONEYLINE_ENABLED"] = "0"
      lines = [moneyline_for(away_contestant, -285), moneyline_for(home_contestant, 240)]

      model = view_model(lines)

      expect(model.bet_lines.select(&:moneyline?)).to be_empty
      expect(model.rows.map(&:moneyline_offered)).to eq([false, false])
    end

    # A moneyline belongs to a side, and lines nullifies contestant_id on
    # delete. Same reason spread_lines drops one - but the survivor stays on
    # its own row rather than sliding up into the orphan's place, which is
    # what positional pairing would do.
    it "drops a moneyline whose side has been deleted, without moving its partner" do
      orphan = moneyline_for(away_contestant, -285)
      partner = moneyline_for(home_contestant, 240)
      orphan.update_columns(contestant_id: nil)

      rows = view_model([orphan.reload, partner]).rows

      expect(rows.map(&:abbreviation)).to eq(%w[BUF MIA])
      expect(rows.map { |row| row.moneyline&.odds }).to eq([nil, 240])
    end
  end

  # The money bag is a comparison between two sides, and summing stake was
  # only ever meaningful because both sides of a spread or a total are
  # priced at -110.
  describe "the chump stamp on a moneyline" do
    it "reads what the book would owe, not what was staked" do
      favorite = moneyline_for(away_contestant, -500)
      underdog = moneyline_for(home_contestant, 300)
      chump = create_account(user: create_user(name: "Chump"))
      # More money on the favorite, far more exposure on the underdog.
      create_wager(account: chump, line: favorite, amount: 500)
      create_wager(account: chump, line: underdog, amount: 100)

      rows = view_model([favorite, underdog]).rows

      expect(rows.first.moneyline_flagged).to be(false)
      expect(rows.second.moneyline_flagged).to be(true)
    end

    # Both sides of a spread are -110, so payout-weighting scales the
    # comparison by the same 0.909 on each side and can flip no stamp that
    # stands today.
    it "still flags the side with the most money on a spread" do
      away_spread = spread_for(away_contestant, 2.5)
      home_spread = spread_for(home_contestant, -2.5)
      chump = create_account(user: create_user(name: "Chump"))
      create_wager(account: chump, line: away_spread, amount: 400)
      create_wager(account: chump, line: home_spread, amount: 100)

      rows = view_model([away_spread, home_spread]).rows

      expect(rows.first.spread_flagged).to be(true)
      expect(rows.second.spread_flagged).to be(false)
    end
  end
end
