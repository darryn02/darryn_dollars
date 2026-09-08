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
end
