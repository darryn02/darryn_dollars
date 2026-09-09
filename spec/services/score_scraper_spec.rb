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

  def competition(status: "post", completed: true, type: "STD", date: game_time, teams: [])
    {
      "type" => { "abbreviation" => type },
      "status" => { "type" => { "state" => status, "completed" => completed } },
      "date" => date.strftime("%Y-%m-%dT%H:%MZ"),
      "competitors" => teams
    }
  end

  def team(name, *scores)
    { "team" => { "displayName" => name }, "linescores" => linescore(*scores) }
  end

  def stub_scoreboard(events:)
    stub_request(:get, espn).to_return(status: 200, body: { "events" => events }.to_json,
                                       headers: { "Content-Type" => "application/json" })
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
