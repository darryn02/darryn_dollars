# One row of the leaderboard.
#
# Everything here is derived from wagers the controller has already eager
# loaded, so the extra signal costs no additional queries. Nothing negative is
# ever surfaced: there is no cold streak, no losing record, no down arrow. The
# ranking already says who is behind; the badges only ever say something good.
class LeaderboardEntry
  # An NFL week turns over on Tuesday, once Monday night is settled.
  WEEK_STARTS_ON = :tuesday
  FORM_LENGTH = 5

  attr_reader :account, :rank

  def initialize(account:, rank:, badges: [])
    @account = account
    @rank = rank
    @badges = badges
  end

  def name
    account.qualified_name
  end

  def podium?
    rank <= 3
  end

  def badges
    @badges
  end

  # Most recent settled results first-to-last, oldest to newest, capped at five
  # so a bad run rolls off instead of following someone around all season.
  def form
    @form ||= settled.last(FORM_LENGTH).map { |wager| result_of(wager) }
  end

  def week_record
    @week_record ||= record_for(settled.select { |wager| this_week?(wager) })
  end

  def week_summary
    wins, losses, pushes = week_record.values_at(:win, :loss, :push)
    return "No bets settled this week" if (wins + losses + pushes).zero?

    parts = ["#{wins}-#{losses}"]
    parts << "-#{pushes}" if pushes.positive?

    "#{parts.join} this week"
  end

  def current_win_streak
    settled.reverse_each.take_while { |wager| wager.win? }.size
  end

  def settled_count
    settled.size
  end

  def self.week_start
    Time.current.in_time_zone("America/New_York").beginning_of_week(WEEK_STARTS_ON)
  end

  private

  def settled
    @settled ||= account.wagers.
      select { |wager| wager.win? || wager.loss? || wager.push? }.
      sort_by { |wager| wager.placed_at || wager.created_at }
  end

  def this_week?(wager)
    (wager.placed_at || wager.created_at) >= self.class.week_start
  end

  def record_for(wagers)
    {
      win: wagers.count(&:win?),
      loss: wagers.count(&:loss?),
      push: wagers.count(&:push?)
    }
  end

  def result_of(wager)
    return :win if wager.win?
    return :loss if wager.loss?

    :push
  end
end
