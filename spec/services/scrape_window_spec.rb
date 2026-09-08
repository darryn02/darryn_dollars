require "rails_helper"

RSpec.describe ScrapeWindow, type: :service do
  subject(:window) { described_class.new(:nfl) }

  let(:now) { Time.zone.local(2026, 9, 13, 9, 0, 0) } # Sunday morning

  around { |example| Timecop.freeze(now) { example.run } }

  def game_at(time)
    Game.create!(sport: :nfl, starts_at: time)
  end

  def espn_says(state:, period: nil)
    status = EspnScoreboard::Status.new(state: state, period: period, completed: state == "post")
    allow(EspnScoreboard).to receive(:for).and_return(double(status_for: status))
  end

  def run_at(time, outcome: ScrapeRun::SUCCESS)
    ScrapeRun.create!(sport: "nfl", ran_at: time, outcome: outcome)
  end

  describe "#due?" do
    it "is due when nothing has ever run" do
      expect(window).to be_due
    end

    it "is not due again inside the interval" do
      game_at(now + 2.hours)
      run_at(now - 1.minute)

      expect(window).not_to be_due
    end
  end

  describe "#interval" do
    it "polls every 10 minutes in the last 3 hours before kickoff" do
      game_at(now + 2.hours)

      expect(window.interval).to eq(10.minutes)
    end

    it "polls every 30 minutes from 3 to 8 hours out" do
      game_at(now + 5.hours)

      expect(window.interval).to eq(30.minutes)
    end

    it "falls back to once a day when the next game is far off" do
      game_at(now + 3.days)

      expect(window.interval).to eq(described_class::BASELINE)
    end

    it "falls back to once a day when there are no games at all" do
      expect(window.interval).to eq(described_class::BASELINE)
    end

    it "keeps polling for 3 hours after kickoff, for delayed games" do
      game_at(now - 2.hours)

      expect(window.interval).to eq(10.minutes)
    end

    it "stops polling once a game is well past kickoff" do
      espn_says(state: "post")
      game_at(now - 4.hours)

      expect(window.interval).to eq(described_class::BASELINE)
    end

    it "keeps polling past the clock window while ESPN says the game is on" do
      espn_says(state: "in", period: 3)
      game_at(now - 5.hours) # lightning delay

      expect(window.interval).to eq(10.minutes)
    end

    it "gives up on a game nobody ever marked final" do
      espn_says(state: "in", period: 4)
      game_at(now - 9.hours)

      expect(window.interval).to eq(described_class::BASELINE)
    end

    it "falls back to the clock when ESPN cannot be reached" do
      allow(EspnScoreboard).to receive(:for).and_raise(EspnScoreboard::Unavailable)
      game_at(now - 5.hours)

      expect(window.interval).to eq(described_class::BASELINE)
    end

    it "does not ask ESPN about a game inside the clock window" do
      expect(EspnScoreboard).not_to receive(:for)
      game_at(now - 1.hour)

      expect(window.interval).to eq(10.minutes)
    end

    it "takes the tightest cadence when a game is on and another is near" do
      game_at(now - 1.hour)
      game_at(now + 5.hours)

      expect(window.interval).to eq(10.minutes)
    end

    it "never polls faster than the book's cache allows" do
      game_at(now + 30.minutes)

      expect(window.interval).to be >= described_class::MINIMUM_INTERVAL
    end
  end

  describe "backing off after the book pushes back" do
    before { game_at(now + 1.hour) } # would otherwise be a 10 minute cadence

    it "eases off after one challenge" do
      run_at(now - 1.minute, outcome: ScrapeRun::CHALLENGED)

      expect(window.interval).to eq(described_class::FIRST_BACKOFF)
    end

    it "doubles for each consecutive challenge" do
      run_at(now - 3.minutes, outcome: ScrapeRun::CHALLENGED)
      run_at(now - 2.minutes, outcome: ScrapeRun::CHALLENGED)

      expect(window.interval).to eq(described_class::FIRST_BACKOFF * 2)
    end

    it "caps the backoff" do
      10.times { |i| run_at(now - (10 - i).minutes, outcome: ScrapeRun::CHALLENGED) }

      expect(window.interval).to eq(described_class::MAX_BACKOFF)
    end

    it "resets as soon as a fetch succeeds" do
      run_at(now - 3.minutes, outcome: ScrapeRun::CHALLENGED)
      run_at(now - 2.minutes, outcome: ScrapeRun::SUCCESS)

      expect(window.interval).to eq(10.minutes)
    end
  end

  it "only considers runs for its own sport" do
    game_at(now + 1.hour)
    ScrapeRun.create!(sport: "ncaaf", ran_at: now - 1.minute, outcome: ScrapeRun::SUCCESS)

    expect(window).to be_due
  end
end
