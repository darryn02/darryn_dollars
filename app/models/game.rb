class Game < ApplicationRecord
  include SportEnum
  include Md5Digestible

  has_many :contestants
  has_many :competitors, through: :contestants
  has_many :lines

  def self.unplayed
    where('starts_at > ?', Time.current)
  end

  def self.wagerable
    where('starts_at BETWEEN ? AND ?', Time.current, Time.current + Wager::WINDOW.hours)
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
    "#{starts_at.strftime("%m/%d %l:%M%P")} #{matchup}"
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
