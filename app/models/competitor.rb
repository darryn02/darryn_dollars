# A Competitor is like a team or a player.
# Each time a Competitor is involved in a Game it becomes a Contestant.
# So a given Competitor (like the Buffalo Bills) will be a Contestant
# many times throughout the NFL season.
# Each Contestant has its own Line, because in the case of prop bets,
# you could have many Contestants (like a handful of receivers vying for most receptions)
# each with its own odds of winning the Contest. Same with multi-competitor sports like golf.
class Competitor < ApplicationRecord
  include SportEnum

  has_many :contests
  has_many :games, through: :contests

  before_save :assign_full_name

  def self.find_by_string(str, sport: nil)
    scope = where(abbreviation: str).
      or(where(region: str)).
      or(where(name: str)).
      or(where(full_name: str)).
      or(where("? = ANY(nicknames)", str))
    scope = scope.send(sport) if sport.to_s.presence_in(self.sports.keys)
    scope.sole
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def self.find_by_string!(str, sport: nil)
    result = find_by_string(str, sport: sport)
    raise ActiveRecord::RecordNotFound if result.nil?
    result
  end

  private

  def assign_full_name
    self.full_name = "#{region} #{name}".squish
  end
end
