# Decides whether it is worth asking ESPN for scores right now.
#
# Two questions, and both have to answer yes. Is there anything to score - a
# confirmed wager still waiting on a result? And could the game it waits on
# plausibly be over yet? A request made before either is true cannot change a
# single row, and the cheapest way to stay welcome at somebody else's api is
# to not make those.
#
# Deliberately all clock arithmetic and local rows. Game#live? would answer
# "is this game over" authoritatively, but it answers by calling ESPN, which
# is the thing we are deciding whether to do.
class ScoreWindow
  # Measured from kickoff, and deliberately the same for every sport: a rule
  # that differs by league is a rule that goes out of date quietly, and being
  # half an hour early costs one wasted request where being wrong costs a
  # wrongly graded wager.
  HALFTIME_AFTER = 1.5.hours
  FINAL_AFTER = 3.hours

  # Cadence once a game could be over. Games in a slate finish minutes apart,
  # so this settles a board inside a commercial break without being the ten
  # minute drumbeat that gets a scraper noticed.
  SETTLING_INTERVAL = 20.minutes

  # A game still unscored long after it ended is not a game we are waiting on.
  # It is a disagreement between our row and ESPN's, and the fix for that is
  # rarely another request. Keep asking - late corrections do happen - slowly.
  STALE_AFTER = 8.hours
  STALE_INTERVAL = 2.hours

  # Past this nobody is coming. A wager this old needs a person, and polling
  # on its behalf forever is just noise on someone else's server.
  ABANDON_AFTER = 36.hours

  def self.due?(sport:) = new(sport).due?

  def initialize(sport)
    @sport = sport.to_sym
  end

  def due?
    return false if ripe.empty?

    last_run_at.nil? || (Time.current - last_run_at) >= interval
  end

  # Exposed so a caller can say why it did nothing.
  def interval = settling? ? SETTLING_INTERVAL : STALE_INTERVAL

  private

  attr_reader :sport

  # Every unsettled wager this sport is carrying, as kickoff and the scope it
  # is waiting on - the scope being what decides how long that wait is.
  def waiting
    @waiting ||= Wager.confirmed.
      joins(line: :game).
      merge(Game.public_send(sport)).
      where(games: { starts_at: ABANDON_AFTER.ago..HALFTIME_AFTER.ago }).
      pluck("games.starts_at", "lines.scope")
  end

  # The ones whose result could actually exist by now.
  def ripe
    @ripe ||= waiting.select { |starts_at, scope| starts_at <= earliest_for(scope).ago }
  end

  # A scope whose periods stop before the final whistle can settle at a break;
  # everything else waits for the game, because overtime can still move it.
  # Read off Line::PERIODS so a scope added later needs nothing here.
  def earliest_for(scope)
    Line::PERIODS.fetch(scope).end ? HALFTIME_AFTER : FINAL_AFTER
  end

  def settling? = ripe.any? { |starts_at, _scope| starts_at > STALE_AFTER.ago }

  def last_run_at
    return @last_run_at if defined?(@last_run_at)

    @last_run_at = ScrapeRun.for_sport(sport).for_scores.maximum(:ran_at)
  end
end
