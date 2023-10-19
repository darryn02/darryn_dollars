class ScoreScraper
  def self.run(week = nil, season = nil)
    new.run(week, season)
  end

  def run(week = nil, season = nil)
    require 'open-uri'

    raw_week = ((DateTime.current  - DateTime.new(2023, 9, 13)) / 7.0).ceil
    week = (raw_week % 18 + 1) if week.nil?
    season = raw_week / 18 + 2 if season.nil?

    url = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?week=#{week}&seasontype=#{season}"

    json = JSON.parse(URI.open(url).read)
    json["events"].map do |event|
      competition = event["competitions"].find { |c| c["type"]["abbreviation"] == "STD" }
      next unless competition["status"]["type"]["completed"]

      date = DateTime.parse(competition["date"]).in_time_zone("UTC")
      competition["competitors"].each do |competitor|

        db_competitor = Competitor.find_by_string(competitor["team"]["name"])
        if db_competitor.blank?
          Rails.logger.warn("Couldn't find Competitor #{competitor["team"]["name"]}")
          next
        end

        scores = competitor["linescores"].map { |s| s["value"] }
        contestant = Contestant.joins(:game).where(competitor: db_competitor).where(games: { starts_at: date - 1.hour..date + 1.hour }).each do |c|
          c.update!(scores: scores)
        end
      end
    end
  end
end
