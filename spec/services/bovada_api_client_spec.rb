require "rails_helper"

RSpec.describe BovadaApiClient, type: :service do
  let(:api) { %r{bovada\.lv/services/sports/event} }
  let(:home) { %r{bovada\.lv/sports/football/nfl} }

  let!(:bills) { Competitor.create!(sport: :nfl, region: "Buffalo", name: "Bills", abbreviation: "BUF") }
  let!(:jets) { Competitor.create!(sport: :nfl, region: "New York", name: "Jets", abbreviation: "NYJ") }

  let!(:game) do
    Game.create!(sport: :nfl, starts_at: 2.hours.from_now).tap do |g|
      g.contestants.create!(competitor: bills, priority: 0)
      g.contestants.create!(competitor: jets, priority: 1)
    end
  end

  let!(:existing_line) { game.lines.create!(kind: :point_spread, scope: :game, value: -3.0, hidden: false) }

  before { stub_request(:get, home).to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" }) }

  def stub_api(body:, status: 200, content_type: "application/json")
    stub_request(:get, api).to_return(status: status, body: body, headers: { "Content-Type" => content_type })
  end

  describe "when the book returns nothing while lines are active" do
    it "leaves the board alone instead of hiding every line" do
      stub_api(body: [{ events: [] }].to_json)

      result = described_class.update_lines(sport: :nfl)

      expect(result.outcome).to eq(ScrapeRun::NO_DATA)
      expect(existing_line.reload).not_to be_hidden
    end
  end

  describe "when the book serves a challenge page" do
    it "raises rather than treating html as an empty board" do
      stub_api(body: "<html>Access Denied</html>", content_type: "text/html")

      expect { described_class.update_lines(sport: :nfl) }.to raise_error(BovadaSession::Challenged)
      expect(existing_line.reload).not_to be_hidden
    end

    it "records the attempt as challenged rather than a bug" do
      stub_api(body: "<html>Access Denied</html>", content_type: "text/html")

      expect {
        ScrapeRun.track(sport: :nfl) { described_class.update_lines(sport: :nfl) } rescue nil
      }.to change(ScrapeRun, :count).by(1)

      expect(ScrapeRun.last.outcome).to eq(ScrapeRun::CHALLENGED)
    end

    it "raises on a 403" do
      stub_api(body: "denied", status: 403)

      expect { described_class.update_lines(sport: :nfl) }.to raise_error(BovadaSession::Challenged)
    end
  end

  describe "session hygiene" do
    it "sends no pinned cookie and identifies as a browser" do
      stub_api(body: [{ events: [] }].to_json)

      described_class.update_lines(sport: :nfl) rescue nil

      expect(a_request(:get, api).with { |req|
        req.headers["User-Agent"].to_s.include?("Mozilla") && req.headers["Referer"].present?
      }).to have_been_made.at_least_once
    end

    it "carries cookies the book issued during the run" do
      stub_request(:get, home).to_return(
        status: 200, body: "<html></html>",
        headers: { "Content-Type" => "text/html", "Set-Cookie" => "TS0189=abc123; Path=/" }
      )
      stub_api(body: [{ events: [] }].to_json)

      described_class.update_lines(sport: :nfl) rescue nil

      expect(a_request(:get, api).with(headers: { "Cookie" => "TS0189=abc123" })).to have_been_made.at_least_once
    end
  end

  describe "an event it cannot resolve to two of our competitors" do
    let(:client) { described_class.new(:ncaaf) }

    let!(:georgia) do
      Competitor.create!(sport: :ncaaf, region: "Georgia", name: "Bulldogs", abbreviation: "Georgia")
    end
    let!(:alabama) do
      Competitor.create!(sport: :ncaaf, region: "Alabama", name: "Crimson Tide", abbreviation: "Alabama")
    end

    def event(home_team, away_team, spread: -3.5)
      {
        "id" => SecureRandom.hex(4),
        "startTime" => (Time.current + 3.hours).to_i * 1000,
        "competitors" => [
          { "home" => true,  "name" => home_team },
          { "home" => false, "name" => away_team }
        ],
        "displayGroups" => [{
          "description" => "Game Lines",
          "markets" => [{
            "description" => "Point Spread",
            "period" => { "live" => false, "abbreviation" => "G" },
            "outcomes" => [
              { "type" => "H", "price" => { "handicap" => spread, "american" => "-110" } },
              { "type" => "A", "price" => { "handicap" => -spread, "american" => "-110" } }
            ]
          }]
        }]
      }
    end

    def parse(events)
      client.send(:parse_and_assert_lines, [{ "events" => events }])
    end

    it "builds lines for an event whose teams it recognises" do
      expect(parse([event("Georgia", "Alabama")]).map(&:kind).uniq).to eq(["point_spread"])
    end

    # The real failure: Bovada listed a Delaware game, Delaware was missing
    # from the competitors table, and the RecordNotFound aborted the whole
    # parse - taking every other game with it and 404ing the lines board.
    it "keeps the rest of the response when one team is unrecognised" do
      lines = nil
      expect { lines = parse([event("Georgia", "Alabama"), event("Delaware", "Alabama")]) }.
        not_to raise_error

      expect(lines).to be_present
      expect(lines.flat_map { |line| line.game.competitors.map(&:region) }.uniq).
        to match_array(%w[Georgia Alabama])
    end

    it "reports what it skipped rather than failing silently" do
      expect(Rails.logger).to receive(:warn).with(/unrecognised competitors.*Delaware/)

      parse([event("Delaware", "Alabama")])
    end

    it "names the side that could not be resolved, not just the fixture" do
      expect(Rails.logger).to receive(:warn).with(/Delaware vs\. Alabama \(Delaware\)/)

      parse([event("Delaware", "Alabama")])
    end

    # Exactly how a duplicate competitor row breaks things: the name stops
    # being unique, and every game for that team is quietly skipped.
    it "skips a name that matches more than one competitor" do
      Competitor.create!(sport: :ncaaf, region: "Miami", name: "Hurricanes", abbreviation: "Ambiguous")
      Competitor.create!(sport: :ncaaf, region: "Ambiguous", name: "RedHawks", abbreviation: "Miami OH")

      expect(Rails.logger).to receive(:warn).with(/\(Ambiguous\)/)

      lines = nil
      expect { lines = parse([event("Ambiguous", "Alabama")]) }.not_to raise_error
      expect(lines).to be_empty
    end

    it "skips an event that is not a two-sided contest" do
      malformed = event("Georgia", "Alabama").merge(
        "competitors" => [{ "home" => true, "name" => "Georgia" }]
      )

      lines = nil
      expect { lines = parse([malformed]) }.not_to raise_error
      expect(lines).to be_empty
    end

    it "stays quiet when every event resolves" do
      expect(Rails.logger).not_to receive(:warn)

      parse([event("Georgia", "Alabama")])
    end
  end
end
