class Game < ApplicationRecord
  include SportEnum
  include Md5Digestible

  has_many :contestants
  has_many :competitors, through: :contestants
  has_many :lines
  has_many :wagers, through: :lines

  def self.list_all
    Game.order(starts_at: :asc).map do |g|
      "[#{g.id}] #{g.starts_at&.strftime("%-m/%-d %l:%M%P") || 'TBA'} #{g.matchup}"
    end
  end

  def self.results
    Game.order(starts_at: :asc).map do |g|
      "[#{g.id}] #{g.starts_at.strftime("%-m/%-d %l:%M%P")} #{g.contestants.sort_by(&:priority).map { |c| "#{c.competitor.abbreviation} (#{c.scores.join(', ')})" }.join(' vs. ')}"
    end
  end

  def self.unplayed
    where('starts_at > ?', Time.current)
  end

  def self.wagerable
    where('starts_at BETWEEN ? AND ?', 3.hours.ago, Time.current + Wager::WINDOW)
  end

  def self.viewable
    where('starts_at BETWEEN ? AND ?', 3.hours.ago, Time.current + 6.days)
  end

  def self.upcoming
    where('starts_at BETWEEN ? AND ?', Time.current + Wager::WINDOW, Time.current + Wager::PREVIEW_WINDOW)
  end

  def self.in_progress
    where(starts_at: (Time.current - 5.hours)..Time.current)
  end

  def self.today
    where(
      "date_trunc('day', starts_at) = ?",
      Time.now.in_time_zone("America/New_York").to_date
    )
  end

  def description
    [matchup, I18n.l(starts_at, format: :default)].join(', ')
  end

  # ESPN groups its scoreboard by Eastern date, so a Sunday night or Monday
  # night game would land on the wrong day if we used the UTC date.
  def espn_date
    starts_at.in_time_zone("America/New_York").to_date
  end

  # Raises EspnScoreboard::Unavailable if ESPN cannot be reached. Returns nil
  # when ESPN has no event matching this game.
  def espn_status
    EspnScoreboard.for(sport: sport, date: espn_date).status_for(self)
  end

  def live?
    espn_status&.live? || false
  end

  # Authoritative answer to "can this still be wagered", for second half lines
  # that have no scheduled start of their own. Raises Unavailable rather than
  # guessing, so callers can fail closed.
  def second_half_started?
    status = espn_status
    raise EspnScoreboard::Unavailable, "no ESPN event matching game #{id}" if status.nil?

    status.second_half_started?
  end

  def matchup
    if competitors.size == 2
      competitors.map(&:name).join(' vs. ')
    else
      competitors.map(&:name).join(',')
    end
  end

  def short_matchup
    competitors.map(&:abbreviation).join('/')
  end

  def to_s
    "#{starts_at.strftime("%-m/%-d %l:%M%P")} #{matchup}"
  end

  def wagerable?
    starts_at.between?(3.hours.ago, Time.current + Wager::WINDOW)
  end

  private

  def digestible_attributes
    %w[
        starts_at
        sport
        cached_competitor_ids
      ]
  end
end
