class BovadaApiClient
  HOST = "https://www.bovada.lv".freeze

  # Bovada's edge caches per full URL, and a key can get stuck holding an
  # empty body - no cache-control at all, and an age that climbs without ever
  # expiring. Measured on 2026-09-19: the stuck key answered with age 5611 and
  # no max-age while a healthy key sat at age 30 under max-age=600. Which key
  # is stuck moves around. On 2026-09-09 it was the bare v2 url and ?lang=en
  # was fine; ten days later that had swapped exactly.
  #
  # So an empty body is not an answer about the board, it is a key to stop
  # using. These three URLs were verified to return the same events with the
  # same English team names, so falling through them costs a request and
  # nothing else.
  #
  # A nonce does not work here and must not be reintroduced: an unrecognised
  # query string makes the origin return [] every time (0 events for 5 of 5
  # random strings tried), which is the same symptom for a different reason.
  # Only keys Bovada already honours are worth asking.
  SOURCES = [
    ["services/sports/event/v2/events/A/description", nil],
    ["services/sports/event/coupon/events/A/description", nil],
    ["services/sports/event/v2/events/A/description", "lang=es"]
  ].freeze

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
    events = events_for(session, sport)

    # Only when the book listed nothing at all. This used to fire whenever we
    # built no *lines*, which meant an nfl response full of games we could not
    # name sent us to the super bowl url - whose sole event is the Pro Bowl,
    # between "NFC Conference" and "AFC Conference", teams no sane competitors
    # table carries. So a stuck cache key announced itself as an unrecognised
    # competitor, and the actual failure never said its own name.
    events = events_for(session, :super_bowl) if events.empty? && sport == :nfl

    lines = parse_and_assert_lines(events)

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

  # The first source that lists any events wins. Nothing anywhere is the only
  # honest empty, and the caller still refuses to act on it while we hold
  # active lines.
  def events_for(session, key)
    SOURCES.each do |prefix, query|
      events = events_in(session.get_json(url_for(prefix, query, key)))
      return events if events.any?
    end

    []
  end

  def url_for(prefix, query, key)
    url = File.join(HOST, prefix, API_SPORT_MAP[key])
    query.present? ? "#{url}?#{query}" : url
  end

  def events_in(json) = Array.wrap(Array.wrap(json).first&.fetch("events", nil))

  def no_data(deactivate_ids)
    message = "Bovada returned no lines while #{deactivate_ids.size} are active - left them alone."
    Rails.logger.warn(message)
    Honeybadger.notify(message, context: { sport: sport }) if defined?(Honeybadger)

    ScrapeResult.new(outcome: ScrapeRun::NO_DATA, message: message)
  end

  def parse_and_assert_lines(events)
    return [] if events.blank?

    unresolved = []
    @skipped_markets = []

    lines = events.flat_map { |event|
      names = team_names(event)
      if names.nil?
        unresolved << "event #{event["id"]} (not a two-sided contest)"
        next []
      end

      competitors, unnameable = resolve_competitors(names)
      if competitors.nil?
        unresolved << "#{names.join(" vs. ")} (#{unnameable.join(", ")})"
        next []
      end

      home, away = competitors
      start_time = Time.at(event["startTime"] / 1000.0)

      game = find_or_create_game!(start_time, [home.id, away.id])
      away_contestant = game.contestants.find_or_create_by!(competitor: away, priority: 0)
      home_contestant = game.contestants.find_or_create_by!(competitor: home, priority: 1)

      extract_lines_from_markets(event, game, away_contestant, home_contestant)
    }.compact

    report_unresolved(unresolved)
    report_skipped_markets

    lines
  end

  # [home, away] as the book writes them, or nil if the event is not shaped
  # like a two-sided contest.
  def team_names(event)
    home, away = Array.wrap(event["competitors"]).partition { |competitor| competitor["home"] }
    return nil unless home.one? && away.one?

    [home, away].map { |side| side.first["name"].to_s.gsub(/\(.*?\)/, "").squish }
  end

  # [[home, away], []] when both sides resolve, or [nil, names_that_did_not].
  # Naming the side that failed is the difference between a report you can act
  # on and one you have to go and query the database to understand.
  def resolve_competitors(names)
    found = names.map { |name| [name, competitor_for(name)] }
    unnameable = found.select { |_, competitor| competitor.nil? }.map(&:first)

    return [nil, unnameable] if unnameable.any?

    [found.map(&:last), []]
  end

  # A name we do not carry and a name matching several of our competitors are
  # equally unusable here, so both come back as nil.
  def competitor_for(name)
    Competitor.find_by_string(name, sport: sport)
  rescue ActiveRecord::SoleRecordExceeded
    nil
  end

  # An unrecognised team used to raise straight out of the parse, which took
  # down every other game in the response and aborted the run before any
  # ScrapeRun row was written - so a book adding a team looked, from the
  # outside, exactly like nothing happening at all. Skip that event and say so.
  def report_unresolved(unresolved)
    return if unresolved.empty?

    message = "Skipped #{unresolved.size} #{sport} event(s) with unrecognised competitors: " \
              "#{unresolved.join("; ")}"

    Rails.logger.warn(message)
    Honeybadger.notify(message, context: { sport: sport, events: unresolved }) if defined?(Honeybadger)
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
    return moneyline_lines(market, game, away_contestant, home_contestant) if moneyline_market?(market)

    market["outcomes"].map do |outcome|
      build_line(market, outcome, game, away_contestant, home_contestant,
                 odds: outcome["price"]["american"])
    end
  end

  def moneyline_market?(market) = market["description"] == "Moneyline"

  # The trust boundary for moneyline prices, and the only market where the
  # book does not set its own price.
  #
  # Both the validation and the normalization belong here rather than in
  # LineBuilder, which sees one outcome at a time and - the part that
  # matters - sees only the normalizer's output. A bad raw price caught
  # there has already corrupted the other side's re-pricing through the
  # overround and the scale, and the integer that comes out of that looks
  # plausible enough to pass any bound downstream.
  def moneyline_lines(market, game, away_contestant, home_contestant)
    outcomes = Array.wrap(market["outcomes"])

    # A one-sided market - the other side suspended - has no pair to
    # normalize. Offering it means offering it at whatever overround
    # Bovada happened to publish, so skip the market rather than the check.
    unless outcomes.size == 2
      return skip_market(market, game, "has #{outcomes.size} outcome(s) rather than two")
    end

    raw = outcomes.map { |outcome| parse_american(published_price(outcome)) }
    if raw.any?(&:nil?)
      published = outcomes.map { |outcome| published_price(outcome).inspect }.join(", ")
      return skip_market(market, game, "carries an unusable price (#{published})")
    end

    normalized = MoneylinePricer.normalize(*raw)

    # Normalization can only raise a favorite as far as the probability
    # clamp allows (-9900) and can only shorten an underdog, so a raw pair
    # in range stays in range. Checked anyway, because the cost of being
    # wrong is a RangeError thrown past skip_market at persist time.
    unless (raw + normalized).all? { |odds| storable?(odds) }
      return skip_market(market, game, "prices outside the range the database can store (#{raw.join(", ")})")
    end

    outcomes.each_with_index.map do |outcome, index|
      build_line(market, outcome, game, away_contestant, home_contestant,
                 odds: normalized[index], raw_odds: raw[index])
    end
  rescue ArgumentError => e
    skip_market(market, game, e.message)
  end

  # Bovada writes exactly +100 as "EVEN". That is a well-defined price, not
  # corrupt data, so it is mapped rather than rejected - rejecting it would
  # silently drop the moneyline market for every near-pick'em game, which is
  # the shape of game most worth offering. "EVEN".to_i is 0, which is what
  # the old parse produced and what made a winning bet pay $0.
  #
  # nil for anything that is not an integer outside the (-100, 100) dead
  # band, which the caller turns into a skipped market.
  def parse_american(value)
    published = value.to_s.strip
    return 100 if published.casecmp("EVEN").zero?

    odds = Integer(published, exception: false)
    odds if odds && odds.abs >= 100
  end

  # Bovada has been seen to put a bare string where the price object
  # belongs. String#dig raises TypeError rather than answering nil, which
  # escapes skip_market entirely and aborts every other game in the
  # response - the exact failure skip-and-report exists to prevent.
  def published_price(outcome)
    price = outcome["price"] if outcome.is_a?(Hash)

    price["american"] if price.is_a?(Hash)
  end

  # odds and raw_odds are 4-byte integer columns. A price past that raises
  # ActiveModel::RangeError at persist time, which is also past skip_market.
  INT4_LIMIT = 2_147_483_647

  def storable?(odds) = odds.abs <= INT4_LIMIT

  def build_line(market, outcome, game, away_contestant, home_contestant, odds:, raw_odds: nil)
    contestant = outcome["type"] == "A" ? away_contestant : (outcome["type"] == "H" ? home_contestant : nil)

    LineBuilder.new.
      game(game).
      kind(market["description"] == "Total" ? outcome["type"] : market["description"]).
      scope(market["period"]["abbreviation"]).
      value(outcome["price"]["handicap"]).
      odds(odds).
      raw_odds(raw_odds).
      contestant(contestant).
      find_or_create!
  end

  # Skip and report, never raise. find_or_create_line runs inside an
  # unrescued flat_map, so raising here would abort every other game in the
  # response, write no ScrapeRun at all, and 500 the second half board
  # through LinesController's before_action - the same failure an
  # unrecognised competitor used to cause, and the same discipline applies.
  def skip_market(market, game, reason)
    @skipped_markets << "#{game.short_matchup} #{market["period"]["abbreviation"]} " \
                        "#{market["description"].downcase} #{reason}"
    []
  end

  def report_skipped_markets
    return if @skipped_markets.blank?

    message = "Skipped #{@skipped_markets.size} #{sport} market(s) with unusable prices: " \
              "#{@skipped_markets.join("; ")}"

    Rails.logger.warn(message)
    Honeybadger.notify(message, context: { sport: sport, markets: @skipped_markets }) if defined?(Honeybadger)
  end
end
