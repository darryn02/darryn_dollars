class Game < ApplicationRecord
  include SportEnum
  include Md5Digestible

  has_many :contestants
  has_many :competitors, through: :contestants
  has_many :lines

  def self.unplayed
    where('starts_at > ?', DateTime.now)
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

  private

  def digestible_attributes
    %w[
        starts_at
        sport
      ]
  end
end
