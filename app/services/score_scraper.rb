class ScoreScraper
  # https://gist.github.com/akeaswaran/b48b02f1c94f873c6655e7129910fc3b?permalink_comment_id=4733003#gistcomment-4733003

  API_SPORT_MAP = {
    nfl: ["football/nfl", DateTime.new(2023, 9, 6), 18],
    ncaaf: ["football/college-football", DateTime.new(2023, 8, 28), 15],
    # nba: ["basketball/nba", DateTime.now, 1],
    # ncaab: ["basketball/mens-college-basketball", DateTime.now, 1]
  }

  def self.run(sport, week = nil)
    new.run(sport.to_sym, week)
  end

  def run(sport, week = nil)
    require 'open-uri'

    api_sport, regular_season_start_date, regular_season_weeks = API_SPORT_MAP[sport]
    week = week.present? ? week : ((DateTime.current  - regular_season_start_date) / 7.0).ceil

    start_date = regular_season_start_date + (week - 1).weeks
    end_date = start_date + 6.days

    events = (start_date.to_date..end_date.to_date).flat_map { |date| events_on(api_sport, date) }

    update_count = 0
    missing_competitor_count = 0
    events.map do |event|
      competition = event["competitions"].find { |c| ["STD", "Bowl Game", "Major Bowl"].include?(c["type"]["abbreviation"]) }
      next unless competition&.dig("status", "type", "completed")

      date = DateTime.parse(competition["date"]).in_time_zone("UTC")
      competition["competitors"].each do |competitor|

        db_competitor = Competitor.find_by_string(competitor["team"]["displayName"], sport: sport)
        if db_competitor.blank?
          Rails.logger.warn("Couldn't find Competitor #{competitor["team"]["displayName"]}")
          missing_competitor_count += 1
          next
        end

        scores = competitor["linescores"].map { |s| s["value"] }
        Contestant.joins(:game).where(competitor: db_competitor).where(games: { starts_at: date - 2.hours..date + 2.hours }).each do |c|
          if c.scores != scores
            c.update!(scores: scores)
            update_count += 1
          end
        end
      end
    end

    result_message(update_count, missing_competitor_count)
  end

  private

  # ESPN stopped serving date *ranges* here in September 2026. A range now
  # answers 400 {"code":400,"message":"Failed to get events endpoint."}, and
  # does so for ranges in seasons long past as well - so the api changed under
  # us rather than anything changing about our dates. Single days still work,
  # so we ask for each day of the week we already compute.
  #
  # Deliberately not ?dates=<year>&seasontype=2&week=<n>, which would also
  # work: it would make us derive a season year and a season week from a date,
  # and decide for ourselves where the regular season stops and the playoffs
  # and bowls begin. Asking by day leaves that calendar with ESPN, which is
  # the only party that actually knows it.
  #
  # site.web.api, not site.api - see the comment on EspnScoreboard::URL_BASE.
  URL_BASE = "https://site.web.api.espn.com/apis/site/v2/sports/".freeze

  def events_on(api_sport, date)
    url = File.join(URL_BASE, api_sport, "scoreboard?dates=#{date.strftime("%Y%m%d")}&limit=1000")

    Array.wrap(JSON.parse(URI.open(url).read)["events"])
  end

  def result_message(update_count, missing_competitor_count)
    "#{update_count} contestant scores updated.".then do |str|
      str += " #{missing_competitor_count} competitors not found." if missing_competitor_count > 0
      str
    end
  end
end
