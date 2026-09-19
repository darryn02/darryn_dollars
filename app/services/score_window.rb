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
  # Nothing is final before this. NFL games run a shade over three hours;
  # college games run longer and stop the clock more.
  SETTLES_AFTER = { nfl: 3.hours, ncaaf: 3.5.hours }.freeze
  DEFAULT_SETTLES_AFTER = 3.hours

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
    return false if candidates.empty?

    last_run_at.nil? || (Time.current - last_run_at) >= interval
  end

  # Exposed so a caller can say why it did nothing.
  def interval = settling? ? SETTLING_INTERVAL : STALE_INTERVAL

  private

  attr_reader :sport

  # Games this sport still owes a result on: a confirmed wager, and a kickoff
  # old enough that a final score could exist but recent enough to be worth
  # asking after.
  def candidates
    @candidates ||= Game.public_send(sport).
      joins(:wagers).
      where(wagers: { status: :confirmed }).
      where(starts_at: ABANDON_AFTER.ago..settles_after.ago).
      distinct.
      pluck(:starts_at)
  end

  def settling? = candidates.any? { |starts_at| starts_at > STALE_AFTER.ago }

  def settles_after = SETTLES_AFTER.fetch(sport, DEFAULT_SETTLES_AFTER)

  def last_run_at
    return @last_run_at if defined?(@last_run_at)

    @last_run_at = ScrapeRun.for_sport(sport).for_scores.maximum(:ran_at)
  end
end
