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
