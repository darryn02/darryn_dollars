require "rails_helper"

RSpec.describe ScoreWindow, type: :service do
  subject(:window) { described_class.new(:nfl) }

  let(:now) { Time.zone.local(2026, 9, 20, 20, 0, 0) } # Sunday evening

  around { |example| Timecop.freeze(now) { example.run } }

  let(:account) { create_account(user: create_user) }

  def game_at(time, sport: :nfl)
    Game.create!(sport: sport, starts_at: time)
  end

  # A confirmed wager is the only reason to ask ESPN anything, so every case
  # here goes through one. Saved without validation on purpose: the model
  # refuses a wager on a game that has already kicked off, and every game
  # worth scoring has.
  def confirmed_wager_on(game)
    line = game.lines.create!(kind: :point_spread, scope: :game, value: -3.0, hidden: false)

    Wager.new(account: account, bet_slip: BetSlip.create!(account: account, status: :confirmed),
              line: line, amount: 100, status: :confirmed, placed_at: game.starts_at - 1.hour).
      save!(validate: false)
  end

  def scored_at(time, sport: "nfl", outcome: ScrapeRun::SUCCESS)
    ScrapeRun.create!(sport: sport, scope: ScrapeRun::SCORES, ran_at: time, outcome: outcome)
  end

  describe "nothing to score" do
    it "is not due when no wager is waiting on a result" do
      game_at(now - 4.hours) # played, but nobody bet it

      expect(window).not_to be_due
    end

    it "is not due when the only confirmed wager is on a game that has not started" do
      confirmed_wager_on(game_at(now + 2.hours))

      expect(window).not_to be_due
    end

    it "ignores another sport's unsettled wagers" do
      confirmed_wager_on(game_at(now - 4.hours, sport: :ncaaf))

      expect(window).not_to be_due
    end
  end

  describe "a game that cannot be over yet" do
    # The whole point: a request sent now cannot return a final score, so it
    # is a request that can only cost us goodwill.
    it "waits until a game could plausibly have finished" do
      confirmed_wager_on(game_at(now - 2.hours))

      expect(window).not_to be_due
    end

    it "is due once it could have" do
      confirmed_wager_on(game_at(now - 3.hours - 1.minute))

      expect(window).to be_due
    end

    # A fresh instance per assertion on purpose: a window memoises what it
    # found, because it answers one scheduler tick and then goes away.
    it "gives college games longer, because they run longer" do
      confirmed_wager_on(game_at(now - 3.hours - 10.minutes, sport: :ncaaf))

      expect(described_class.new(:ncaaf)).not_to be_due

      confirmed_wager_on(game_at(now - 3.hours - 40.minutes, sport: :ncaaf))

      expect(described_class.new(:ncaaf)).to be_due
    end
  end

  describe "cadence while a game is settling" do
    before { confirmed_wager_on(game_at(now - 4.hours)) }

    it "is due when it has never asked" do
      expect(window).to be_due
    end

    it "does not ask again inside the interval" do
      scored_at(now - 5.minutes)

      expect(window).not_to be_due
    end

    it "asks again once the interval has passed" do
      scored_at(now - described_class::SETTLING_INTERVAL - 1.minute)

      expect(window).to be_due
    end

    it "asks more often than the ten minute scheduler heartbeat would" do
      expect(window.interval).to be > 10.minutes
    end
  end

  describe "a game long past its finish" do
    it "eases off rather than hammering a disagreement it cannot fix" do
      confirmed_wager_on(game_at(now - 10.hours))

      expect(window.interval).to eq(described_class::STALE_INTERVAL)
    end

    it "still asks, because late corrections happen" do
      confirmed_wager_on(game_at(now - 10.hours))
      scored_at(now - described_class::STALE_INTERVAL - 1.minute)

      expect(window).to be_due
    end

    it "gives up entirely on a wager nobody is coming for" do
      confirmed_wager_on(game_at(now - described_class::ABANDON_AFTER - 1.hour))

      expect(window).not_to be_due
    end

    it "keeps the fast cadence when one game is stale but another is settling" do
      confirmed_wager_on(game_at(now - 10.hours))
      confirmed_wager_on(game_at(now - 4.hours))

      expect(window.interval).to eq(described_class::SETTLING_INTERVAL)
    end
  end

  describe "telling its own runs from the line scraper's" do
    before { confirmed_wager_on(game_at(now - 4.hours)) }

    it "is not held off by a line scrape that just ran" do
      ScrapeRun.create!(sport: "nfl", scope: "game", ran_at: now - 1.minute, outcome: ScrapeRun::SUCCESS)

      expect(window).to be_due
    end
  end
end
