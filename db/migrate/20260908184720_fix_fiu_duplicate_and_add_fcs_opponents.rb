# Two corrections to the competitor list.
#
# First, FIU was never missing. It has been here since 2023 as "Florida
# International Panthers"; the previous migration checked for the string "FIU"
# rather than the string Bovada actually sends, added a second row, and gave it
# the nickname "Florida International" - which made that name match two
# competitors and got every FIU game skipped as ambiguous. Remove the duplicate
# and hang "FIU" on the row that was already correct.
#
# Second, Bovada lists FBS teams playing FCS opponents, and those opponents are
# not in a list of FBS schools. Add the ones we have seen skipped.
class FixFiuDuplicateAndAddFcsOpponents < ActiveRecord::Migration[7.0]
  NCAAF = 1

  class Competitor < ActiveRecord::Base
    self.table_name = "competitors"
  end

  class Contestant < ActiveRecord::Base
    self.table_name = "contestants"
  end

  FCS_OPPONENTS = [
    { region: "North Dakota State", name: "Bison",  abbreviation: "N Dakota St" },
    { region: "Sacramento State",   name: "Hornets", abbreviation: "Sacramento St" }
  ].freeze

  def up
    duplicate = Competitor.find_by(sport: NCAAF, region: "FIU", name: "Panthers")
    if duplicate && !Contestant.exists?(competitor_id: duplicate.id)
      duplicate.destroy!
    end

    real = Competitor.find_by(sport: NCAAF, region: "Florida International")
    if real && !real.nicknames.include?("FIU")
      real.update!(nicknames: real.nicknames + ["FIU"])
    end

    FCS_OPPONENTS.each do |attributes|
      next if Competitor.exists?(sport: NCAAF, region: attributes[:region], name: attributes[:name])

      Competitor.create!(
        attributes.merge(
          sport: NCAAF,
          nicknames: [],
          full_name: "#{attributes[:region]} #{attributes[:name]}".squish
        )
      )
    end
  end

  def down
    real = Competitor.find_by(sport: NCAAF, region: "Florida International")
    real&.update!(nicknames: real.nicknames - ["FIU"])

    FCS_OPPONENTS.each do |attributes|
      competitor = Competitor.find_by(sport: NCAAF, region: attributes[:region], name: attributes[:name])
      next if competitor.nil? || Contestant.exists?(competitor_id: competitor.id)

      competitor.destroy!
    end
  end
end
