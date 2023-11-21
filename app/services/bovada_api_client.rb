require 'open-uri'

class BovadaApiClient
  URL_BASE = "https://www.bovada.lv/services/sports/event/v2/events/A/description"

  API_SPORT_MAP = {
    nfl: "football/nfl",
    ncaaf: "football/college-football",
    nba: "basketball/nba",
    ncaab: "basketball/college-basketball",
  }

  def self.ensure_second_half_lines_are_recent!(sport: :nfl)
    last_update = Line.send(sport).active.second_half.maximum(:updated_at)
    if last_update.nil? || last_update < 1.minute.ago
      update_lines(sport: sport)
    end
  end

  def self.update_lines(sport: :nfl)
    new(sport.to_sym).update_lines
  end

  def initialize(sport)
    @sport = sport
  end

  def update_lines
    deactivate_ids = Line.active.send(sport).pluck(:id)

    url = File.join(URL_BASE, API_SPORT_MAP[sport])
    json = JSON.parse(URI.open(url, "Cookie" => "VISITED=true").read)

    lines = parse_and_assert_lines(json)
    activate_ids = lines.map(&:id)
    deactivated_count = Line.where(id: deactivate_ids - activate_ids).update_all(updated_at: Time.now, hidden: true)
    activated_count = Line.where(id: activate_ids - deactivate_ids).update_all(updated_at: Time.now, hidden: false)
    "#{deactivated_count} lines deactivated. #{activated_count} lines activated."
  end

  private

  attr_reader :sport

  def parse_and_assert_lines(json)
    return [] if (json = Array.wrap(json).first).blank?

    json["events"].flat_map do |event|
      home_team, away_team = event["competitors"].partition { |c| c["home"] }.map { |c| c.first["name"].gsub(/\(.*?\)/, "").squish }

      home = Competitor.find_by_string(home_team, sport: sport)
      away = Competitor.find_by_string(away_team, sport: sport)
      start_time = Time.at(event["startTime"] / 1000.0)
      live = event["live"]

      game = find_or_create_game!(start_time, [home.id, away.id])
      away_contestant = game.contestants.find_or_create_by!(competitor: away, priority: 0)
      home_contestant = game.contestants.find_or_create_by!(competitor: home, priority: 1)

      extract_lines_from_markets(event, game, away_contestant, home_contestant)
    end
  end

  def find_or_create_game!(start_time, competitor_ids = [])
    game = Game.send(sport).find_or_create_by!(
      starts_at: (start_time - 1.hour)..(start_time + 1.hour),
      cached_competitor_ids: competitor_ids
    ) do |game|
      game.starts_at = start_time
    end
    game.update!(starts_at: start_time) if game.starts_at != start_time
    game
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def extract_lines_from_markets(event, game, away_contestant, home_contestant)
    game_lines = event["displayGroups"].find { |c| c["description"] == "Game Lines" }
    relevant_markets = game_lines["markets"].select(&method(:relevant_market?))

    relevant_markets.flat_map do |market|
      find_or_create_line(market, game, away_contestant, home_contestant)
    end.compact
  end

  def relevant_market?(market)
    market["period"]["live"] == false &&
      ["Point Spread", "Moneyline", "Total"].include?(market["description"]) &&
      ["G", "1H", "2H"].include?(market["period"]["abbreviation"])
  end

  def find_or_create_line(market, game, away_contestant, home_contestant)
    market["outcomes"].map do |outcome|
      contestant = outcome["type"] == "A" ? away_contestant : (outcome["type"] == "H" ? home_contestant : nil)

      LineBuilder.new.
        game(game).
        kind(market["description"] == "Total" ? outcome["type"] : market["description"]).
        scope(market["period"]["abbreviation"]).
        value(outcome["price"]["handicap"]).
        odds(outcome["price"]["american"]).
        contestant(contestant).
        find_or_create!
    end
  end
end
