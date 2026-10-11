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

  # An empty body is a stuck cache key, not an empty board. Which key is stuck
  # moves around - the bare v2 url on 2026-09-09, that same url with ?lang=en
  # ten days later - so the client has to survive any one of them being dead
  # rather than betting on a particular query string.
  describe "a url that answers with an empty body" do
    let(:v2) { %r{/event/v2/events/A/description/football/nfl$} }
    let(:coupon) { %r{/event/coupon/events/A/description/football/nfl$} }

    def game_payload
      [{ events: [nfl_event] }].to_json
    end

    def nfl_event
      {
        "id" => "evt1",
        "startTime" => (Time.current + 3.hours).to_i * 1000,
        "competitors" => [
          { "home" => true,  "name" => "Buffalo Bills" },
          { "home" => false, "name" => "New York Jets" }
        ],
        "displayGroups" => [{
          "description" => "Game Lines",
          "markets" => [{
            "description" => "Point Spread",
            "period" => { "live" => false, "abbreviation" => "G" },
            "outcomes" => [
              { "type" => "H", "price" => { "handicap" => -3.5, "american" => "-110" } },
              { "type" => "A", "price" => { "handicap" => 3.5, "american" => "-110" } }
            ]
          }]
        }]
      }
    end

    it "falls through to the next source instead of believing it" do
      stub_api(body: [].to_json)
      stub_request(:get, coupon).to_return(status: 200, body: game_payload,
                                           headers: { "Content-Type" => "application/json" })

      result = described_class.update_lines(sport: :nfl)

      expect(result.outcome).to eq(ScrapeRun::SUCCESS)
      expect(a_request(:get, coupon)).to have_been_made.at_least_once
    end

    it "stops asking as soon as a source has events" do
      stub_api(body: game_payload)

      described_class.update_lines(sport: :nfl)

      expect(a_request(:get, coupon)).not_to have_been_made
    end

    it "reports no data only once every source is empty" do
      stub_api(body: [].to_json)

      result = described_class.update_lines(sport: :nfl)

      expect(result.outcome).to eq(ScrapeRun::NO_DATA)
      expect(existing_line.reload).not_to be_hidden
    end

    # A nonce would defeat the whole point: an unrecognised query string makes
    # the origin return [] every time, so every retry would be born empty.
    # Asserted against SOURCES rather than a literal, so adding a key to the
    # pool cannot quietly become permission to invent one.
    it "asks only urls the book already honours" do
      stub_api(body: [].to_json)

      described_class.update_lines(sport: :nfl)

      queries = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.
        map { |req| URI(req.uri.to_s).query }.compact
      expect(queries.uniq).to all(be_in(described_class::SOURCES.map(&:last).compact))
    end

    # Three keys were all stuck at once on 2026-09-20 and the board sat empty.
    it "keeps enough honoured keys that one dead key is not an outage" do
      expect(described_class::SOURCES.size).to be >= 4
      expect(described_class::SOURCES.uniq.size).to eq(described_class::SOURCES.size)
    end

    it "tries every source before giving up" do
      stub_api(body: [].to_json)

      described_class.update_lines(sport: :nfl)

      described_class::SOURCES.each do |prefix, query|
        url = %r{#{Regexp.escape(prefix)}/football/nfl#{query ? "\\?#{Regexp.escape(query)}" : "$"}}
        expect(a_request(:get, url)).to have_been_made.at_least_once
      end
    end
  end

  # Opening the second half board is the other way a fetch happens, and the
  # only one a player sets off. It left no trace, so a halftime that came and
  # went without lines could not be told apart from one nobody looked at.
  describe "a fetch set off by opening the second half board" do
    it "is written to the scrape log as a page view" do
      stub_api(body: [{ events: [] }].to_json)

      expect { described_class.ensure_second_half_lines_are_recent!(sport: :nfl) }.
        to change(ScrapeRun, :count).by(1)

      expect(ScrapeRun.last).to have_attributes(sport: "nfl", scope: ScrapeRun::PAGE_VIEW)
    end

    # rack-timeout raises an Exception that is not a StandardError, so the
    # fetch that ran too long was exactly the one that went unrecorded.
    it "is still written when the request is cut off for running too long" do
      cut_off = Class.new(Exception) # rubocop:disable Lint/InheritException
      allow(described_class).to receive(:update_lines).and_raise(cut_off, "Request ran for longer than 15000ms")

      expect { described_class.ensure_second_half_lines_are_recent!(sport: :nfl) }.to raise_error(cut_off)

      expect(ScrapeRun.last).to have_attributes(scope: ScrapeRun::PAGE_VIEW, outcome: ScrapeRun::ERROR,
                                                detail: a_string_including("15000ms"))
    end

    it "leaves a signal to stop the process unrecorded" do
      allow(described_class).to receive(:update_lines).and_raise(SignalException, "SIGTERM")

      expect { described_class.ensure_second_half_lines_are_recent!(sport: :nfl) }.to raise_error(SignalException)

      expect(ScrapeRun.count).to eq(0)
    end

    it "asks nobody and writes nothing when the board was refreshed inside the last minute" do
      game.lines.create!(kind: :over, scope: :second_half, value: 23.5, hidden: false)

      expect { described_class.ensure_second_half_lines_are_recent!(sport: :nfl) }.
        not_to change(ScrapeRun, :count)

      expect(a_request(:get, api)).not_to have_been_made
    end
  end

  # Past max-age the edge serves the expired copy and refreshes behind it, so
  # the fresh board goes to the next request. Measured 2026-10-11: a copy 930
  # seconds old, and 36 seconds old when asked again 37 seconds later. Taking
  # the first answer meant every scrape saw the board as of the scrape before,
  # and a second half market only exists for the 14 minutes of halftime.
  describe "a copy of the board that is minutes old" do
    let(:first_source) { %r{/event/coupon/events/A/description/football/nfl\?lang=en$} }
    let(:second_source) { %r{/event/v2/events/A/description/football/nfl\?lang=fr$} }

    let(:kickoff) { 90.minutes.ago }

    before do
      Game.create!(sport: :nfl, starts_at: kickoff)
      allow_any_instance_of(described_class).to receive(:sleep)
    end

    def board(age:, second_half:)
      markets = [market("G", 44.5)]
      markets << market("2H", 23.5) if second_half

      {
        status: 200,
        headers: { "Content-Type" => "application/json", "Age" => age.to_s },
        body: [{ events: [{
          "id" => "evt1",
          "startTime" => kickoff.to_i * 1000,
          "competitors" => [
            { "home" => true,  "name" => "Buffalo Bills" },
            { "home" => false, "name" => "New York Jets" }
          ],
          "displayGroups" => [{ "description" => "Game Lines", "markets" => markets }]
        }] }].to_json
      }
    end

    def market(period, total)
      {
        "description" => "Total",
        "period" => { "live" => false, "abbreviation" => period },
        "outcomes" => [
          { "type" => "O", "price" => { "handicap" => total, "american" => "-110" } },
          { "type" => "U", "price" => { "handicap" => total, "american" => "-110" } }
        ]
      }
    end

    # 600 exactly, because that is where a scrape on a 10 minute heartbeat
    # finds the copy its last run left behind - and the edge does treat it
    # as expired there.
    it "asks an expired source again and builds the second half from the refreshed copy" do
      stub_request(:get, first_source).to_return(board(age: 600, second_half: false),
                                                 board(age: 1, second_half: true))

      described_class.update_lines(sport: :nfl)

      expect(Line.second_half.active.pluck(:kind, :value)).to contain_exactly(["over", 23.5], ["under", 23.5])
      expect(a_request(:get, first_source)).to have_been_made.twice
      expect(a_request(:get, second_source)).not_to have_been_made
    end

    # Too old to trust, too young for the edge to replace - asking again
    # would only get the same copy back.
    it "moves on to the next source when the copy is aging but not yet expired" do
      stub_request(:get, first_source).to_return(board(age: 300, second_half: false))
      stub_request(:get, second_source).to_return(board(age: 0, second_half: true))

      described_class.update_lines(sport: :nfl)

      expect(Line.second_half.active.count).to eq(2)
      expect(a_request(:get, first_source)).to have_been_made.once
    end

    it "settles for the youngest copy when no source is fresh" do
      stub_request(:get, api).to_return(board(age: 500, second_half: false))
      stub_request(:get, second_source).to_return(board(age: 200, second_half: true))

      described_class.update_lines(sport: :nfl)

      expect(Line.second_half.active.count).to eq(2)
      expect(a_request(:get, api)).to have_been_made.times(described_class::SOURCES.size)
    end

    it "takes a fresh copy from the first source without asking anybody else" do
      stub_request(:get, first_source).to_return(board(age: 45, second_half: true))

      described_class.update_lines(sport: :nfl)

      expect(a_request(:get, api)).to have_been_made.once
    end

    it "says how old the copy it used was" do
      stub_request(:get, first_source).to_return(board(age: 45, second_half: true))

      expect(described_class.update_lines(sport: :nfl).to_s).to include("Board copy 45s old")
    end

    # Hunting for a fresher copy asks sources that used to go unasked, and
    # any failure there surfaces as a challenge. With a board already in hand
    # that would have recorded a challenge, updated nothing and backed the
    # scheduler off for half an hour in the middle of a game.
    it "keeps the copy in hand when a later source fails" do
      stub_request(:get, api).to_return(status: 403, body: "denied")
      stub_request(:get, first_source).to_return(board(age: 300, second_half: true))

      result = described_class.update_lines(sport: :nfl)

      expect(result.outcome).to eq(ScrapeRun::SUCCESS)
      expect(Line.second_half.active.count).to eq(2)
    end

    it "keeps the expired copy when asking again fails" do
      stub_request(:get, api).to_return(status: 403, body: "denied")
      stub_request(:get, first_source).to_return(board(age: 600, second_half: true), { status: 403, body: "denied" })

      result = described_class.update_lines(sport: :nfl)

      expect(result.outcome).to eq(ScrapeRun::SUCCESS)
      expect(Line.second_half.active.count).to eq(2)
    end

    # A cold key answers [] - see the sources above. That is not the book
    # taking the board down.
    it "keeps the expired copy when asking again comes back empty" do
      stub_api(body: [].to_json)
      stub_request(:get, first_source).to_return(
        board(age: 600, second_half: true),
        { status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" } }
      )

      result = described_class.update_lines(sport: :nfl)

      expect(result.outcome).to eq(ScrapeRun::SUCCESS)
      expect(Line.second_half.active.count).to eq(2)
    end

    # A page view does this inside a web request with a 15 second limit, and
    # six expired sources would otherwise be six waits.
    it "asks again once per run, however many sources have expired" do
      stub_request(:get, api).to_return(board(age: 700, second_half: false))
      expect_any_instance_of(described_class).to receive(:sleep).once

      described_class.update_lines(sport: :nfl)

      expect(a_request(:get, first_source)).to have_been_made.twice
      expect(a_request(:get, second_source)).to have_been_made.once
    end

    # Between games a board ten minutes behind is still right, and the extra
    # requests would be spent on a site that challenges sessions it finds odd.
    it "takes the first source as it comes when no game is on" do
      Game.nfl.in_progress.delete_all
      stub_request(:get, first_source).to_return(board(age: 1140, second_half: false))

      described_class.update_lines(sport: :nfl)

      expect(a_request(:get, api)).to have_been_made.once
    end
  end

  # The age in the scrape log has to be the age of the copy the lines were
  # built from, or it answers the wrong question with a straight face.
  describe "the copy age it reports" do
    let(:super_bowl) { %r{/description/football/super-bowl} }

    def super_bowl_board(age:)
      {
        status: 200,
        headers: { "Content-Type" => "application/json", "Age" => age.to_s },
        body: [{ events: [{
          "id" => "sb", "startTime" => (Time.current + 3.hours).to_i * 1000,
          "competitors" => [{ "home" => true, "name" => "Buffalo Bills" },
                            { "home" => false, "name" => "New York Jets" }],
          "displayGroups" => [{ "description" => "Game Lines", "markets" => [{
            "description" => "Total", "period" => { "live" => false, "abbreviation" => "G" },
            "outcomes" => [{ "type" => "O", "price" => { "handicap" => 44.5, "american" => "-110" } },
                           { "type" => "U", "price" => { "handicap" => 44.5, "american" => "-110" } }]
          }] }]
        }] }].to_json
      }
    end

    it "is the fallback board's when the fallback is what listed the games" do
      stub_request(:get, api).to_return(status: 200, body: [].to_json,
                                        headers: { "Content-Type" => "application/json", "Age" => "35129" })
      stub_request(:get, super_bowl).to_return(super_bowl_board(age: 77))

      expect(described_class.update_lines(sport: :nfl).to_s).to include("Board copy 77s old")
    end

    it "is left out when no source listed anything" do
      existing_line.update!(hidden: true)
      stub_api(body: [].to_json)

      result = described_class.update_lines(sport: :nfl)

      expect(result.outcome).to eq(ScrapeRun::SUCCESS)
      expect(result.to_s).not_to include("Board copy")
    end
  end

  # The super bowl url holds exactly one event - the Pro Bowl, between "NFC
  # Conference" and "AFC Conference". Reaching for it because we built no
  # *lines* turned every unresolvable nfl response into a competitor alert.
  describe "the super bowl fallback" do
    let(:super_bowl) { %r{/description/football/super-bowl} }

    it "is not consulted when the book listed games we simply could not name" do
      stub_api(body: [{ events: [{ "id" => "x", "startTime" => (Time.current + 3.hours).to_i * 1000,
                                   "competitors" => [{ "home" => true, "name" => "Sharks" },
                                                     { "home" => false, "name" => "Jets" }] }] }].to_json)

      described_class.update_lines(sport: :nfl)

      expect(a_request(:get, super_bowl)).not_to have_been_made
    end

    # The Pro Bowl is unnameable by design, so an empty nfl board used to raise
    # a competitor alert on top of the no_data one - and that alert pointed at
    # the competitors table while the real fault was a stuck cache key.
    it "does not report the pro bowl as an unrecognised nfl competitor" do
      stub_api(body: [].to_json)
      stub_request(:get, super_bowl).to_return(
        status: 200,
        body: [{ events: [{ "id" => "pb", "startTime" => (Time.current + 3.hours).to_i * 1000,
                            "competitors" => [{ "home" => true, "name" => "NFC Conference" },
                                              { "home" => false, "name" => "AFC Conference" }] }] }].to_json,
        headers: { "Content-Type" => "application/json" }
      )
      allow(Honeybadger).to receive(:notify)

      result = described_class.update_lines(sport: :nfl)

      expect(result.outcome).to eq(ScrapeRun::NO_DATA)
      expect(Honeybadger).not_to have_received(:notify).with(/unrecognised competitors/, anything)
      expect(Honeybadger).to have_received(:notify).with(/returned no lines/, anything)
    end

    # Suppressing the fallback report must not suppress the real one.
    it "still reports an unnameable competitor on the primary board" do
      stub_api(body: [{ events: [{ "id" => "x", "startTime" => (Time.current + 3.hours).to_i * 1000,
                                   "competitors" => [{ "home" => true, "name" => "Sharks" },
                                                     { "home" => false, "name" => "Jets" }] }] }].to_json)
      allow(Honeybadger).to receive(:notify)

      described_class.update_lines(sport: :nfl)

      expect(Honeybadger).to have_received(:notify).with(/unrecognised competitors/, anything)
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
      client.send(:parse_and_assert_lines, events)
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

  # Moneyline is the one market where Bovada sets the price rather than the
  # book, so this is the trust boundary: validate the pair, normalize it to
  # the floor, then build. Nothing downstream re-checks it.
  describe "a moneyline market" do
    let(:client) { described_class.new(:nfl) }

    def market(description:, outcomes:, abbreviation: "G")
      {
        "description" => description,
        "period" => { "live" => false, "abbreviation" => abbreviation },
        "outcomes" => outcomes
      }
    end

    def moneyline(home_price, away_price, abbreviation: "G")
      market(description: "Moneyline", abbreviation: abbreviation, outcomes: [
        { "type" => "H", "price" => { "handicap" => 0.0, "american" => home_price } },
        { "type" => "A", "price" => { "handicap" => 0.0, "american" => away_price } }
      ])
    end

    def spread
      market(description: "Point Spread", outcomes: [
        { "type" => "H", "price" => { "handicap" => -3.5, "american" => "-110" } },
        { "type" => "A", "price" => { "handicap" => 3.5, "american" => "-110" } }
      ])
    end

    def total
      market(description: "Total", outcomes: [
        { "type" => "O", "price" => { "handicap" => 47.5, "american" => "-110" } },
        { "type" => "U", "price" => { "handicap" => 47.5, "american" => "-110" } }
      ])
    end

    def event(*markets, id: SecureRandom.hex(4), home: "Buffalo Bills", away: "New York Jets")
      {
        "id" => id,
        "startTime" => (Time.current + 3.hours).to_i * 1000,
        "competitors" => [
          { "home" => true,  "name" => home },
          { "home" => false, "name" => away }
        ],
        "displayGroups" => [{ "description" => "Game Lines", "markets" => markets }]
      }
    end

    def parse(events) = client.send(:parse_and_assert_lines, events)

    def moneylines_in(lines) = lines.select(&:moneyline?)

    it "stores the normalized pair, not the prices the book published" do
      lines = moneylines_in(parse([event(moneyline("-185", "+160"))]))

      expect(lines.map(&:odds)).to match_array([-193, 156])
    end

    it "keeps a pair that already clears the floor exactly as published" do
      lines = moneylines_in(parse([event(moneyline("-415", "+310"))]))

      expect(lines.map(&:odds)).to match_array([-415, 310])
    end

    it "attributes each price to the side that was quoted it" do
      lines = moneylines_in(parse([event(moneyline("-185", "+160"))]))
      by_abbreviation = lines.to_h { |line| [line.competitor.abbreviation, line.odds] }

      expect(by_abbreviation).to eq("BUF" => -193, "NYJ" => 156)
    end

    it "retains the price the book published alongside the one it offers" do
      lines = moneylines_in(parse([event(moneyline("-185", "+160"))]))

      expect(lines.to_h { |line| [line.odds, line.raw_odds] }).to eq(-193 => -185, 156 => 160)
    end

    # raw_odds is written after the find, not inside a create block. Left in
    # the block it would answer nothing: the block runs only on create, so
    # every row that survives a scrape would stay NULL forever.
    it "refreshes the published price on a row that already existed" do
      parse([event(moneyline("-185", "+160"))])
      favorite = Line.moneyline.find_by(odds: -193)

      # A raw tick that normalizes to the same offered price, so the lookup
      # finds the same row rather than minting a new one.
      parse([event(moneyline("-186", "+160"))])

      expect(Line.moneyline.count).to eq(2)
      expect(favorite.reload.raw_odds).to eq(-186)
    end

    # "EVEN" is Bovada's rendering of exactly +100, and "EVEN".to_i is 0 -
    # which sends Line#payout down its odds >= 0 branch and pays $0 on a
    # winning bet. It is mapped, not rejected: rejecting it would drop the
    # market for every near-pick'em game.
    it "reads EVEN as +100 rather than as zero" do
      lines = moneylines_in(parse([event(moneyline("EVEN", "EVEN"))]))

      expect(lines.map(&:raw_odds)).to eq([100, 100])
      expect(lines.map(&:odds)).to eq([-110, -110])
      expect(lines.map { |line| line.payout(100) }).to all(be > 0)
    end

    describe "a price it cannot use" do
      it "skips only its own market and still lands the spread and total" do
        lines = nil
        expect { lines = parse([event(moneyline("n/a", "+160"), spread, total)]) }.not_to raise_error

        expect(moneylines_in(lines)).to be_empty
        expect(lines.map(&:kind).uniq).to match_array(%w[point_spread over under])
      end

      it "keeps every other event in the response" do
        lines = parse([
          event(moneyline("n/a", "+160"), id: "bad"),
          event(moneyline("-185", "+160"), id: "good", home: "Buffalo Bills", away: "New York Jets")
        ])

        expect(moneylines_in(lines).map(&:odds)).to match_array([-193, 156])
      end

      it "reports the skip rather than failing silently" do
        expect(Rails.logger).to receive(:warn).with(/unusable prices.*moneyline carries an unusable price/)

        parse([event(moneyline("n/a", "+160"))])
      end

      it "refuses a price inside the dead band, where no price exists" do
        lines = parse([event(moneyline("-50", "+40"), spread)])

        expect(moneylines_in(lines)).to be_empty
        expect(lines).to be_present
      end
    end

    # No pair to normalize, so offering it means offering it at whatever
    # overround Bovada happened to publish.
    it "skips a one-sided market entirely" do
      one_sided = market(description: "Moneyline", outcomes: [
        { "type" => "H", "price" => { "handicap" => 0.0, "american" => "-185" } }
      ])

      lines = nil
      expect { lines = parse([event(one_sided, spread)]) }.not_to raise_error

      expect(moneylines_in(lines)).to be_empty
      expect(lines.map(&:kind).uniq).to eq(["point_spread"])
    end

    it "normalizes each scope's pair on its own" do
      lines = moneylines_in(parse([event(moneyline("-185", "+160"),
                                         moneyline("-415", "+310", abbreviation: "1H"))]))

      expect(lines.select(&:game?).map(&:odds)).to match_array([-193, 156])
      expect(lines.select(&:first_half?).map(&:odds)).to match_array([-415, 310])
    end

    # The constraint the whole plan is written under.
    it "leaves spread and total priced at exactly -110, with no published price" do
      lines = parse([event(moneyline("-185", "+160"), spread, total)])
      others = lines.reject(&:moneyline?)

      expect(others.map(&:odds).uniq).to eq([-110])
      expect(others.map(&:raw_odds).uniq).to eq([nil])
    end
  end
end
