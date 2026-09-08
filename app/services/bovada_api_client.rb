class BovadaApiClient
  URL_BASE = "https://www.bovada.lv/services/sports/event/v2/events/A/description"

  API_SPORT_MAP = {
    nfl: "football/nfl",
    super_bowl: "football/super-bowl",
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
    created_before = Line.count

    session = BovadaSession.new.warm!
    lines = parse_and_assert_lines(session.get_json(url_for(sport)))
    if lines.empty? && sport == :nfl
      lines = parse_and_assert_lines(session.get_json(url_for(:super_bowl)))
    end

    # A book that returns nothing while we hold active lines is telling us
    # something is wrong with the request, not that every game was cancelled.
    # Deactivating here would empty the board on a single bad response.
    return no_data(deactivate_ids) if lines.empty? && deactivate_ids.any?

    activate_ids = lines.map(&:id)
    deactivated = Line.where(id: deactivate_ids - activate_ids).update_all(updated_at: Time.now, hidden: true)

    # Every active line, not just the newly activated ones. Otherwise a run
    # that changes nothing leaves updated_at untouched, and the callers that
    # ask "were these refreshed recently?" conclude they never were - which
    # made the one minute guard on the second half page a no-op and put a
    # live fetch behind every single page view.
    activated = Line.where(id: activate_ids).update_all(updated_at: Time.now, hidden: false)

    ScrapeResult.new(
      outcome: ScrapeRun::SUCCESS,
      message: "#{deactivated} lines deactivated. #{activated} lines activated.",
      created: Line.count - created_before,
      activated: activated,
      deactivated: deactivated
    )
  end

  private

  attr_reader :sport

  def url_for(key) = File.join(URL_BASE, API_SPORT_MAP[key])

  def no_data(deactivate_ids)
    message = "Bovada returned no lines while #{deactivate_ids.size} are active - left them alone."
    Rails.logger.warn(message)
    Honeybadger.notify(message, context: { sport: sport }) if defined?(Honeybadger)

    ScrapeResult.new(outcome: ScrapeRun::NO_DATA, message: message)
  end

  def parse_and_assert_lines(json)
    return [] if (json = Array.wrap(json).first).blank?

    json["events"].flat_map { |event|
      home_team, away_team = event["competitors"].partition { |c| c["home"] }.
        map { |c| c.first["name"].gsub(/\(.*?\)/, "").squish }

      home = Competitor.find_by_string!(home_team, sport: sport)
      away = Competitor.find_by_string!(away_team, sport: sport)
      start_time = Time.at(event["startTime"] / 1000.0)
      live = event["live"]

      game = find_or_create_game!(start_time, [home.id, away.id])
      away_contestant = game.contestants.find_or_create_by!(competitor: away, priority: 0)
      home_contestant = game.contestants.find_or_create_by!(competitor: home, priority: 1)

      extract_lines_from_markets(event, game, away_contestant, home_contestant)
    }.compact
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
    return [] if game_lines.blank?

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
