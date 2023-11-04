class ScoreScraper
  # https://gist.github.com/akeaswaran/b48b02f1c94f873c6655e7129910fc3b?permalink_comment_id=4733003#gistcomment-4733003

  API_SPORT_MAP = {
    nfl: ["football/nfl", DateTime.new(2023, 9, 6), 18],
    ncaaf: ["football/college-football", DateTime.new(2023, 8, 28), 15],
    # nba: ["basketball/nba", DateTime.now, 1],
    # ncaab: ["basketball/mens-college-basketball", DateTime.now, 1]
  }

  def self.run(sport, week = nil, season = nil)
    new.run(sport.to_sym, week, season)
  end

  def run(sport, week = nil, season = nil)
    require 'open-uri'

    api_sport, regular_season_start_date, regular_season_weeks = API_SPORT_MAP[sport]
    raw_week = ((DateTime.current  - regular_season_start_date) / 7.0).ceil
    week = [1, (raw_week % regular_season_weeks)].max if week.nil?
    season = [3, raw_week / regular_season_weeks + 2].min if season.nil?

    url = File.join("https://site.api.espn.com/apis/site/v2/sports/", api_sport, "scoreboard?week=#{week}&seasontype=#{season}")
    json = JSON.parse(URI.open(url).read)

    update_count = 0
    missing_competitor_count = 0
    json["events"].map do |event|
      competition = event["competitions"].find { |c| c["type"]["abbreviation"] == "STD" }
      next unless competition["status"]["type"]["completed"]

      date = DateTime.parse(competition["date"]).in_time_zone("UTC")
      competition["competitors"].each do |competitor|

        db_competitor = Competitor.find_by_string(competitor["team"]["displayName"])
        if db_competitor.blank?
          Rails.logger.warn("Couldn't find Competitor #{competitor["team"]["name"]}")
          missing_competitor_count += 1
          next
        end

        scores = competitor["linescores"].map { |s| s["value"] }
        contestant = Contestant.joins(:game).where(competitor: db_competitor).where(games: { starts_at: date - 1.hour..date + 1.hour }).each do |c|
          c.update!(scores: scores)
          update_count += 1
        end
      end
    end

    result_message(update_count, missing_competitor_count)
  end

  private

  def result_message(update_count, missing_competitor_count)
    "#{update_count} contestant scores updated.".then do |str|
      str += " #{missing_competitor_count} competitors not found." if missing_competitor_count > 0
      str
    end
  end
end
