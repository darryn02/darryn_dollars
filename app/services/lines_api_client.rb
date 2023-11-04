class LinesApiClient
  URL_BASE = ENV.fetch("ODDS_API_URL_BASE")

  API_SPORT_MAP = {
    nfl: "americanfootball_nfl",
    ncaaf: "americanfootball_ncaaf"
  }

  def self.ensure_second_half_lines_are_recent!(sport: :nfl)
    if ENV["USE_ODDS_API"] == "1"

      last_update = Line.send(sport).active.second_half.maximum(:updated_at)
      if last_update.nil? || last_update < 1.minute.ago
        update_lines(sport:, scope: :second_half)
      end
    end
  end

  def self.update_lines(sport: :nfl, scope: :game)
    new(sport.to_sym).update_lines(scope.to_sym)
  end

  def initialize(sport)
    @sport = sport
  end

  def update_lines(scope = :game)
    require 'open-uri'

    event_metadata = fetch_scoped_lines(:game).compact
    if(scope == :first_half || scope == :second_half)
      fetch_scoped_lines(scope, event_metadata:)
    end
  end

  private

  attr_reader :sport

  def fetch_scoped_lines(scope, event_metadata: nil)
    deactivate_ids = Line.active.send(sport).send(scope).pluck(:id)
    activate_ids = []

    url = File.join(URL_BASE, API_SPORT_MAP[sport])
    if event_metadata.present?
      if event_metadata.is_a?(Array)
        event_metadata.each do |meta|
          next if scope == :first_half && meta[:starts_at].past?
          fetch_scoped_lines(scope, event_metadata: meta)
        end
        return
      else
        url = File.join(url, "events/#{event_metadata[:id]}")
      end
    end
    url = File.join(url, "odds/?apiKey=#{ENV['ODDS_API_KEY']}&bookmakers=bovada&markets=#{markets(scope)}")

    f = URI.open(url)
    requests_remaining = f.meta["x-requests-remaining"]
    json = JSON.parse(f.read)

    parse_and_assert_lines(json, scope, activate_ids).tap do
      deactivated_count = Line.send(sport).where(id: deactivate_ids - activate_ids).update_all(updated_at: Time.now, hidden: true)
      activated_count = Line.send(sport).where(id: activate_ids).update_all(updated_at: Time.now, hidden: false)
      requested = event_metadata.blank? ? 'no specific' : (event_metadata.is_a?(Array) ? event_metadata.count : 1)
      Rails.logger.info "fetch_scoped_lines for #{scope}, #{json.is_a?(Array) ? json.count : 1} fetched events, #{requested} requested events: #{deactivated_count} lines deactivated. #{activated_count} lines activated."
    end
  end

  def parse_and_assert_lines(json, scope, activate_ids)
    Array.wrap(json).map do |event|
      home = Competitor.find_by_string(event["home_team"], sport: sport)
      away = Competitor.find_by_string(event["away_team"], sport: sport)
      commence_time = DateTime.parse(event["commence_time"])

      next if event["bookmakers"].blank?

      game = find_or_create_game(commence_time, [home.id, away.id])
      away_contestant = game.contestants.find_or_create_by!(competitor: away, priority: 0)
      home_contestant = game.contestants.find_or_create_by!(competitor: home, priority: 1)

      lines = extract_lines_from_markets(event)

      activate_ids.push(game.lines.point_spread.send(scope).find_or_create_by!(contestant: away_contestant, value: lines[:away_spread]).id) if lines[:away_spread].present?
      activate_ids.push(game.lines.point_spread.send(scope).find_or_create_by!(contestant: home_contestant, value: lines[:home_spread]).id) if lines[:home_spread].present?
      activate_ids.push(game.lines.moneyline.send(scope).find_or_create_by!(contestant: away_contestant, value: 0, odds: lines[:away_ml]).id) if lines[:away_ml].present?
      activate_ids.push(game.lines.moneyline.send(scope).find_or_create_by!(contestant: home_contestant, value: 0, odds: lines[:home_ml]).id) if lines[:home_ml].present?
      activate_ids.push(game.lines.over.send(scope).find_or_create_by!(value: lines[:total]).id) if lines[:total].present?
      activate_ids.push(game.lines.under.send(scope).find_or_create_by!(value: lines[:total]).id) if lines[:total].present?

      { id: event["id"], starts_at: commence_time }
    end
  end

  def find_or_create_game(commence_time, competitor_ids = [])
    game = Game.send(sport).find_or_create_by!(
      starts_at: (commence_time - 1.hour)..(commence_time + 1.hour),
      cached_competitor_ids: competitor_ids
    ) do |game|
      game.starts_at = commence_time
    end
    game.update!(starts_at: commence_time) if game.starts_at != commence_time
    game
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def markets(scope)
    if scope.to_s == "first_half"
      "spreads_h1,totals_h1"
    elsif scope.to_s == "second_half"
      "spreads_h2,totals_h2"
    else
      "spreads,totals"
    end
  end

  def price_to_odds(price)
    price -= 1
    if price < 1
      price = -Math.round(100.0 / price)
    else
      price = Math.round(100.0 * price)
    end
  end

  def extract_lines_from_markets(event)
    event["bookmakers"].first["markets"].each_with_object({}) do |market, lines|
      case market["key"]
      when "spreads", "spreads_h1", "spreads_h2"
        lines[:home_spread] = market["outcomes"].find { |x| x["name"] == event["home_team"] }["point"]
        lines[:away_spread] = market["outcomes"].find { |x| x["name"] == event["away_team"] }["point"]
      when "h2h", "h2h_h1", "h2h_h2"
        lines[:home_ml] = market["outcomes"].find { |x| x["name"] == event["home_team"] }["price"]
        lines[:home_ml] = price_to_odds(home_ml)
        lines[:away_ml] = market["outcomes"].find { |x| x["name"] == event["away_team"] }["price"]
        lines[:away_ml] = price_to_odds(away_ml)
      when "totals", "totals_h1", "totals_h2"
        lines[:total] = market["outcomes"].first["point"]
      end
    end
  end
end
