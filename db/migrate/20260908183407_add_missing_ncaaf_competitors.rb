# Bovada lists games for teams we never seeded, and until the parser learned to
# skip them, one unrecognised name aborted the whole NCAAF scrape. Skipping is
# the safety net; these rows are the actual fix for the teams we know about.
#
# sport is hardcoded rather than read through the enum so this migration keeps
# meaning the same thing if the enum is ever reordered.
class AddMissingNcaafCompetitors < ActiveRecord::Migration[7.0]
  NCAAF = 1

  class Competitor < ActiveRecord::Base
    self.table_name = "competitors"
  end

  ADDITIONS = [
    { region: "Delaware",       name: "Blue Hens", abbreviation: "Delaware",    nicknames: [] },
    { region: "Missouri State", name: "Bears",     abbreviation: "Missouri St", nicknames: ["Missouri St"] },
    { region: "FIU",            name: "Panthers",  abbreviation: "FIU",         nicknames: ["Florida International"] }
  ].freeze

  # Appalachian State is already here; the short form the books use is not.
  NICKNAME_ADDITIONS = { "Appalachian State" => "App State" }.freeze

  def up
    ADDITIONS.each do |attributes|
      next if Competitor.exists?(sport: NCAAF, region: attributes[:region], name: attributes[:name])

      Competitor.create!(
        attributes.merge(
          sport: NCAAF,
          full_name: "#{attributes[:region]} #{attributes[:name]}".squish
        )
      )
    end

    NICKNAME_ADDITIONS.each do |region, nickname|
      competitor = Competitor.find_by(sport: NCAAF, region: region)
      next if competitor.nil? || competitor.nicknames.include?(nickname)

      competitor.update!(nicknames: competitor.nicknames + [nickname])
    end
  end

  def down
    NICKNAME_ADDITIONS.each do |region, nickname|
      competitor = Competitor.find_by(sport: NCAAF, region: region)
      next if competitor.nil?

      competitor.update!(nicknames: competitor.nicknames - [nickname])
    end

    ADDITIONS.each do |attributes|
      competitor = Competitor.find_by(sport: NCAAF, region: attributes[:region], name: attributes[:name])
      # Leave anything that has since been played; contestants reference it.
      next if competitor.nil? || Contestant.exists?(competitor_id: competitor.id)

      competitor.destroy!
    end
  end
end
