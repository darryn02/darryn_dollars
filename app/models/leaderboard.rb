# Builds the leaderboard rows and hands out badges.
#
# Badges are deliberately one-sided. There is no badge for a cold streak or a
# losing week, and none for last place; the standings already carry the bad
# news, so nothing here adds to it.
class Leaderboard
  Badge = Struct.new(:icon, :label, keyword_init: true)

  HOT_STREAK_MINIMUM = 3
  MOST_ACTION_MINIMUM = 3

  def self.build(accounts)
    new(accounts).entries
  end

  def initialize(accounts)
    @accounts = accounts
  end

  def entries
    @entries ||= begin
      rows = @accounts.each_with_index.map do |account, index|
        LeaderboardEntry.new(account: account, rank: index + 1)
      end

      award_hot_streaks(rows)
      award_best_week(rows)
      award_most_action(rows)
      rows
    end
  end

  private

  def award_hot_streaks(rows)
    rows.each do |row|
      streak = row.current_win_streak
      next if streak < HOT_STREAK_MINIMUM

      row.badges << Badge.new(icon: "fire", label: "#{streak} straight")
    end
  end

  def award_best_week(rows)
    contenders = rows.select { |row| row.week_record[:win].positive? }
    winner = contenders.min_by { |row| [-row.week_record[:win], row.week_record[:loss], row.rank] }
    return if winner.nil?

    record = winner.week_record
    winner.badges << Badge.new(icon: "bullseye", label: "Best week (#{record[:win]}-#{record[:loss]})")
  end

  def award_most_action(rows)
    counts = rows.map { |row| [row, row.week_record.values.sum] }.to_h
    top = counts.values.max.to_i
    return if top < MOST_ACTION_MINIMUM

    winner = counts.select { |_, count| count == top }.keys.min_by(&:rank)
    winner&.badges&.<<(Badge.new(icon: "dice-5", label: "Most action (#{top})"))
  end
end
