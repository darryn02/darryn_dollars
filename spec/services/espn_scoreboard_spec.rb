require "rails_helper"

RSpec.describe EspnScoreboard, type: :service do
  let(:date) { Date.new(2026, 9, 13) }
  # Pinned to site.web.api, not site.api - Akamai blocks the latter from
  # Heroku's network outright. A regression back to it should fail this
  # stub match loudly (WebMock raises on an unmatched request) rather than
  # silently hitting a blocked host.
  let(:url) { %r{site\.web\.api\.espn\.com.*football/nfl/scoreboard} }

  let!(:bills) { Competitor.create!(sport: :nfl, region: "Buffalo", name: "Bills", abbreviation: "BUF") }
  let!(:jets) { Competitor.create!(sport: :nfl, region: "New York", name: "Jets", abbreviation: "NYJ") }

  let(:game) do
    Game.create!(sport: :nfl, starts_at: date.in_time_zone("America/New_York") + 13.hours).tap do |g|
      g.contestants.create!(competitor: bills, priority: 0)
      g.contestants.create!(competitor: jets, priority: 1)
    end
  end

  def scoreboard(state:, period:, completed: false)
    {
      events: [{
        competitions: [{
          status: { period: period, type: { state: state, completed: completed } },
          competitors: [
            { team: { displayName: "Buffalo Bills" } },
            { team: { displayName: "New York Jets" } }
          ]
        }]
      }]
    }.to_json
  end

  before { described_class.reset_cache! }

  def stub_espn(body, status: 200)
    stub_request(:get, url).to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  describe "#status_for" do
    it "reports a scheduled game as not started" do
      stub_espn(scoreboard(state: "pre", period: 0))

      status = described_class.for(sport: :nfl, date: date).status_for(game)

      expect(status).not_to be_live
      expect(status).not_to be_second_half_started
    end

    it "treats halftime as still in the first half, so it stays bettable" do
      stub_espn(scoreboard(state: "in", period: 2))

      status = described_class.for(sport: :nfl, date: date).status_for(game)

      expect(status).to be_live
      expect(status).not_to be_second_half_started
    end

    it "reports the third quarter as the second half having started" do
      stub_espn(scoreboard(state: "in", period: 3))

      expect(described_class.for(sport: :nfl, date: date).status_for(game)).to be_second_half_started
    end

    it "reports a finished game as started" do
      stub_espn(scoreboard(state: "post", period: 4, completed: true))

      status = described_class.for(sport: :nfl, date: date).status_for(game)

      expect(status).to be_final
      expect(status).to be_second_half_started
    end

    it "returns nil when ESPN has no matching event" do
      stub_espn({ events: [] }.to_json)

      expect(described_class.for(sport: :nfl, date: date).status_for(game)).to be_nil
    end
  end

  describe "failure handling" do
    it "raises Unavailable on a non-success response" do
      stub_espn("nope", status: 503)

      expect { described_class.for(sport: :nfl, date: date) }.to raise_error(described_class::Unavailable)
    end

    it "raises Unavailable on a timeout" do
      stub_request(:get, url).to_timeout

      expect { described_class.for(sport: :nfl, date: date) }.to raise_error(described_class::Unavailable)
    end

    it "raises Unavailable on unparseable json" do
      stub_espn("<html>go away</html>")

      expect { described_class.for(sport: :nfl, date: date) }.to raise_error(described_class::Unavailable)
    end
  end

  describe "caching" do
    it "makes one request when several wagers are confirmed together" do
      stub_espn(scoreboard(state: "in", period: 3))

      3.times { described_class.for(sport: :nfl, date: date).status_for(game) }

      expect(a_request(:get, url)).to have_been_made.once
    end

    it "refetches once the cache has expired" do
      stub_espn(scoreboard(state: "in", period: 3))

      described_class.for(sport: :nfl, date: date)
      Timecop.travel(described_class::CACHE_TTL.from_now + 1.second) do
        described_class.for(sport: :nfl, date: date)
      end

      expect(a_request(:get, url)).to have_been_made.twice
    end
  end

  it "asks ESPN for the Eastern date, so night games land on the right day" do
    monday_night = Game.create!(sport: :nfl, starts_at: Time.utc(2026, 9, 15, 0, 15)) # 8:15pm ET Monday

    expect(monday_night.espn_date).to eq(Date.new(2026, 9, 14))
  end
end
