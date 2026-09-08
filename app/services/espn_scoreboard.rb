require "net/http"

# Live game state from ESPN's public scoreboard.
#
# Bovada tells us what is wagerable only indirectly - a second half market
# vanishes once the half is underway - and that signal reaches us through a
# CDN that caches for ten minutes. ESPN answers the question directly and is
# not cached, so it is the authority for "has this started", while Bovada
# remains the authority for the numbers.
class EspnScoreboard
  class Unavailable < StandardError; end

  URL_BASE = "https://site.api.espn.com/apis/site/v2/sports".freeze

  SPORT_PATHS = {
    nfl: "football/nfl",
    ncaaf: "football/college-football"
  }.freeze

  # Long enough that confirming a slip of several wagers makes one request,
  # short enough that it cannot mask a half starting mid-decision.
  CACHE_TTL = 10.seconds

  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 3

  # ESPN reports the period a game is in: 1-2 first half, 3-4 second half,
  # 5+ overtime. It stays on 2 through halftime and only advances to 3 at the
  # second half kickoff, so halftime remains bettable.
  SECOND_HALF_PERIOD = 3

  Status = Struct.new(:state, :period, :completed, keyword_init: true) do
    def live? = state == "in"
    def final? = state == "post" || completed
    def second_half_started? = (live? && period.to_i >= SECOND_HALF_PERIOD) || final?
  end

  @cache = {}
  @mutex = Mutex.new

  class << self
    def for(sport:, date:)
      key = [sport.to_sym, date.to_date]

      @mutex.synchronize do
        cached = @cache[key]
        return cached.last if cached && cached.first > CACHE_TTL.ago

        built = new(sport, date.to_date).tap(&:events)
        @cache[key] = [Time.current, built]
        prune
        built
      end
    end

    def reset_cache! = @mutex.synchronize { @cache.clear }

    private

    def prune
      @cache.delete_if { |_, (fetched_at, _)| fetched_at < CACHE_TTL.ago }
    end
  end

  def initialize(sport, date)
    @sport = sport.to_sym
    @date = date
  end

  # The status of the ESPN event matching this game, or nil if there is no
  # match. Callers decide what a missing match means - it is not an error,
  # since a game may simply not be on ESPN's board yet.
  def status_for(game)
    event = event_for(game)
    return nil if event.nil?

    status = event.dig("competitions", 0, "status") || {}
    Status.new(
      state: status.dig("type", "state"),
      period: status["period"],
      completed: status.dig("type", "completed")
    )
  end

  def events
    @events ||= fetch.fetch("events", [])
  end

  private

  attr_reader :sport, :date

  def event_for(game)
    wanted = game.competitors.map(&:id).sort
    return nil if wanted.empty?

    events.find { |event| competitor_ids(event) == wanted }
  end

  def competitor_ids(event)
    competition = event["competitions"]&.first
    return [] if competition.nil?

    competition["competitors"].to_a.filter_map { |c|
      Competitor.find_by_string(c.dig("team", "displayName").to_s, sport: sport)&.id
    }.sort
  end

  def fetch
    uri = URI(File.join(URL_BASE, SPORT_PATHS.fetch(sport), "scoreboard"))
    uri.query = URI.encode_www_form(dates: date.strftime("%Y%m%d"), limit: 1000)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.get(uri.request_uri)
    end

    raise Unavailable, "ESPN returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue Unavailable
    raise
  rescue StandardError => e
    # Timeouts, DNS, TLS, malformed JSON - all the same to the caller.
    raise Unavailable, "#{e.class}: #{e.message}"
  end
end
