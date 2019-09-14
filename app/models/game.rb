class Game < ApplicationRecord
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
end
