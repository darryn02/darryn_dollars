# Decides whether it is worth asking the book for lines right now.
#
# Heroku Scheduler only offers every-10-minutes, hourly and daily, so the
# scheduler is treated as a plain heartbeat and the real policy lives here.
# The question asked is "has enough time passed", not "is it exactly time",
# so a tick the scheduler drops (it is best effort) heals on the next one
# instead of losing a whole window.
class ScrapeWindow
  # How close the next kickoff has to be before we tighten the cadence.
  PREGAME_INTERVALS = {
    3.hours => 10.minutes,   # final injury reports, late scratches
    8.hours => 30.minutes    # morning-of movement
  }.freeze

  # While a game is on, second half lines appear and vanish. Page views drive
  # most of that, but this keeps them from going stale when nobody is looking.
  IN_PROGRESS_INTERVAL = 10.minutes

  # How long after kickoff a game counts as on without asking anybody. Covers a
  # normal game. Deliberately not Game.in_progress (5 hours), which serves a
  # different purpose and is used elsewhere.
  IN_PROGRESS_WINDOW = 3.hours

  # Past that, ESPN decides - a lightning delay or a long overtime keeps a game
  # live well beyond the clock heuristic. Bounded so we only ask on game days,
  # and so a game nobody ever marked final cannot poll forever.
  MAX_IN_PROGRESS_WINDOW = 8.hours

  # Off days still get one fetch so the site has a board to show.
  BASELINE = 1.day

  # Bovada's edge caches the description payload for 600s, so polling faster
  # cannot return fresher data - it only shortens how long we sit on a change
  # that already happened.
  MINIMUM_INTERVAL = 10.minutes

  # Applied on top of the normal cadence after the book pushes back.
  FIRST_BACKOFF = 30.minutes
  MAX_BACKOFF = 6.hours

  def self.due?(sport: :nfl) = new(sport).due?

  def initialize(sport)
    @sport = sport.to_sym
  end

  def due?
    last_run_at.nil? || (Time.current - last_run_at) >= interval
  end

  # Exposed so the rake task can say why it did nothing.
  def interval
    [[candidate_interval, MINIMUM_INTERVAL].max, backoff_interval].compact.max
  end

  private

  attr_reader :sport

  def candidate_interval
    [in_progress_interval, pregame_interval].compact.min || BASELINE
  end

  def in_progress_interval
    IN_PROGRESS_INTERVAL if games.where(starts_at: MAX_IN_PROGRESS_WINDOW.ago..Time.current).any?(&method(:still_on?))
  end

  # The clock covers the ordinary case for free. ESPN is only consulted for a
  # game that is past it but not yet ancient, which on most days is no game at
  # all. If ESPN cannot be reached we fall back to the clock, which is exactly
  # how this behaved before ESPN was involved.
  def still_on?(game)
    return true if game.starts_at > IN_PROGRESS_WINDOW.ago

    game.live?
  rescue EspnScoreboard::Unavailable
    false
  end

  def pregame_interval
    return nil if next_kickoff.nil?

    lead = next_kickoff - Time.current
    PREGAME_INTERVALS.sort_by(&:first).find { |threshold, _| lead <= threshold }&.last
  end

  def backoff_interval
    strikes = consecutive_pushbacks
    return nil if strikes.zero?

    [FIRST_BACKOFF * (2**(strikes - 1)), MAX_BACKOFF].min
  end

  def consecutive_pushbacks
    ScrapeRun.for_sport(sport).recent_first.limit(10).take_while(&:backoff?).count
  end

  def next_kickoff
    return @next_kickoff if defined?(@next_kickoff)

    @next_kickoff = games.where("starts_at > ?", Time.current).minimum(:starts_at)
  end

  def games = Game.public_send(sport)

  def last_run_at
    return @last_run_at if defined?(@last_run_at)

    @last_run_at = ScrapeRun.for_sport(sport).maximum(:ran_at)
  end
end
