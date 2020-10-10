class Game < ApplicationRecord
  include SportEnum
  include Md5Digestible

  has_many :contests

  def self.unplayed
    where('starts_at > ?', DateTime.now)
  end

  def description
    [matchup, I18n.l(starts_at, format: :default)].join(', ')
  end

  def matchup
    contests.primary.contestants.map(&:name).join(' vs. ')
  end

  def cached_competitor_ids
    super.sort
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
