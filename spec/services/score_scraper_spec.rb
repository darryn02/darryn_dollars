require "rails_helper"

RSpec.describe ScoreScraper, type: :service do
  let!(:bills) { create_competitor(region: "Buffalo", name: "Bills", abbreviation: "BUF") }
  let!(:jets) { create_competitor(region: "New York", name: "Jets", abbreviation: "NYJ") }

  let(:game_time) { DateTime.new(2023, 9, 10, 13, 0, 0) }
  let!(:game) do
    Game.create!(sport: :nfl, starts_at: game_time).tap do |g|
      g.contestants.create!(competitor: bills, priority: 0)
      g.contestants.create!(competitor: jets, priority: 1)
    end
  end

  # Pinned to site.web.api, not site.api - see the comment on
  # EspnScoreboard::URL_BASE. A regression back to the blocked host fails
  # this stub match loudly rather than silently hitting it.
  let(:espn) { %r{site\.web\.api\.espn\.com/apis/site/v2/sports/football/nfl/scoreboard} }

  def linescore(*values)
    values.map { |v| { "value" => v } }
  end

  def competition(status: "post", completed: true, type: "STD", date: game_time, teams: [],
                  period: nil, status_name: nil)
    {
      "type" => { "abbreviation" => type },
      "status" => {
        "period" => period,
        "type" => { "state" => status, "completed" => completed, "name" => status_name }
      },
      "date" => date.strftime("%Y-%m-%dT%H:%MZ"),
      "competitors" => teams
    }
  end

  # The shapes below are what ESPN actually served for three live college
  # games on 2026-09-19, checked against the api rather than imagined.
  def in_progress(teams:, period:)
    competition(status: "in", completed: false, period: period,
                status_name: "STATUS_IN_PROGRESS", teams: teams)
  end

  def halftime(teams:)
    competition(status: "in", completed: false, period: 2,
                status_name: "STATUS_HALFTIME", teams: teams)
  end

  def team(name, *scores)
    { "team" => { "displayName" => name }, "linescores" => linescore(*scores) }
  end

  # ESPN no longer serves date ranges, so a run asks for each day of the week
  # separately. Each event is served on the day it is actually played and the
  # other six days come back empty - otherwise a single stub answers all seven
  # requests and every count in here is multiplied by seven.
  def stub_scoreboard(events:)
    stub_request(:get, espn).to_return(status: 200, body: { "events" => [] }.to_json,
                                       headers: { "Content-Type" => "application/json" })

    events.group_by { |event| Date.parse(event["competitions"].first["date"]) }.each do |date, on_date|
      stub_request(:get, /#{Regexp.escape("dates=#{date.strftime("%Y%m%d")}")}/).
        to_return(status: 200, body: { "events" => on_date }.to_json,
                  headers: { "Content-Type" => "application/json" })
    end
  end

  # ESPN began answering 400 {"code":400,"message":"Failed to get events
  # endpoint."} to any dates=A-B range in September 2026, including ranges in
  # seasons long past. Scoring silently stopped for two days. A regression
  # back to a range fails these stub matches loudly rather than in production.
  it "asks for one day at a time, never a date range" do
    stub_scoreboard(events: [])

    described_class.run(:nfl, 1)

    expect(a_request(:get, /dates=\d{8}-\d{8}/)).not_to have_been_made
    expect(a_request(:get, /dates=20230906(&|$)/)).to have_been_made
  end

  it "covers every day of the week it was asked for" do
    stub_scoreboard(events: [])

    described_class.run(:nfl, 1)

    (Date.new(2023, 9, 6)..Date.new(2023, 9, 12)).each do |date|
      expect(a_request(:get, /dates=#{date.strftime("%Y%m%d")}(&|$)/)).to have_been_made
    end
  end

  describe "a game that is still being played" do
    # ESPN keeps a running total in the linescore of the period in progress -
    # observed live: a game one second from the half already reported a second
    # quarter figure that could still move. Writing it would settle a first
    # half on a number that has not stopped changing.
    it "ignores the period being played right now" do
      stub_scoreboard(events: [{
        "competitions" => [in_progress(period: 2, teams: [team("Buffalo Bills", 7, 3),
                                                          team("New York Jets", 0, 10)])]
      }])

      described_class.run(:nfl, 1)

      expect(game.contestants.find_by(competitor: bills).reload.scores).to eq([7])
    end

    it "writes both quarters once the half is over" do
      stub_scoreboard(events: [{
        "competitions" => [halftime(teams: [team("Buffalo Bills", 7, 3),
                                            team("New York Jets", 0, 10)])]
      }])

      described_class.run(:nfl, 1)

      expect(game.contestants.find_by(competitor: bills).reload.scores).to eq([7, 3])
      expect(game.contestants.find_by(competitor: jets).reload.scores).to eq([0, 10])
    end

    it "writes nothing at all during the first period" do
      stub_scoreboard(events: [{
        "competitions" => [in_progress(period: 1, teams: [team("Buffalo Bills", 7),
                                                          team("New York Jets", 0)])]
      }])

      described_class.run(:nfl, 1)

      expect(game.contestants.find_by(competitor: bills).reload.scores).to eq([])
    end

    # The fact the scores array can no longer carry on its own.
    it "does not mark the game completed at the half" do
      stub_scoreboard(events: [{
        "competitions" => [halftime(teams: [team("Buffalo Bills", 7, 3),
                                            team("New York Jets", 0, 10)])]
      }])

      described_class.run(:nfl, 1)

      expect(game.reload.completed_at).to be_nil
    end

    it "marks it completed at the final whistle" do
      stub_scoreboard(events: [{
        "competitions" => [competition(teams: [team("Buffalo Bills", 7, 3, 0, 10),
                                               team("New York Jets", 0, 3, 3, 0)])]
      }])

      described_class.run(:nfl, 1)

      expect(game.reload.completed_at).to be_present
    end
  end

  it "updates a contestant's scores from a completed game" do
    stub_scoreboard(events: [{
      "competitions" => [competition(teams: [team("Buffalo Bills", 7, 3, 0, 10), team("New York Jets", 0, 3, 3, 0)])]
    }])

    message = described_class.run(:nfl, 1)

    expect(game.contestants.find_by(competitor: bills).reload.scores).to eq([7, 3, 0, 10])
    expect(game.contestants.find_by(competitor: jets).reload.scores).to eq([0, 3, 3, 0])
    expect(message).to eq("2 contestant scores updated.")
  end

  it "ignores a game that has not finished" do
    stub_scoreboard(events: [{
      "competitions" => [competition(status: "in", completed: false,
                                     teams: [team("Buffalo Bills", 7), team("New York Jets", 0)])]
    }])

    described_class.run(:nfl, 1)

    expect(game.contestants.find_by(competitor: bills).reload.scores).to eq([])
  end

  it "counts an unresolvable competitor and says so, without aborting the run" do
    stub_scoreboard(events: [{
      "competitions" => [competition(teams: [team("Nonexistent Team", 7), team("New York Jets", 0)])]
    }])

    message = described_class.run(:nfl, 1)

    expect(game.contestants.find_by(competitor: jets).reload.scores).to eq([0])
    expect(message).to eq("1 contestant scores updated. 1 competitors not found.")
  end

  it "only matches a contestant whose game starts within two hours of the reported date" do
    far_away_time = game_time + 1.day
    stub_scoreboard(events: [{
      "competitions" => [competition(date: far_away_time,
                                     teams: [team("Buffalo Bills", 7), team("New York Jets", 0)])]
    }])

    described_class.run(:nfl, 1)

    expect(game.contestants.find_by(competitor: bills).reload.scores).to eq([])
  end

  it "skips a competition that is not a recognised game type" do
    stub_scoreboard(events: [{
      "competitions" => [competition(type: "SCRIMMAGE", teams: [team("Buffalo Bills", 7), team("New York Jets", 0)])]
    }])

    described_class.run(:nfl, 1)

    expect(game.contestants.find_by(competitor: bills).reload.scores).to eq([])
  end
end
