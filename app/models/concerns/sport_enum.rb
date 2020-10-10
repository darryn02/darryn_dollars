module SportEnum
  extend ActiveSupport::Concern

  included do
    enum sport: { nfl: 0, ncaaf: 1, nba: 2, ncaab: 3, mlb: 4, nhl: 5 }
  end
end
