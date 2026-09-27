# The FCS opponent that 20260908184720 missed.
#
# That migration added the FCS teams we had seen skipped, because Bovada lists
# FBS teams playing FCS opponents and those opponents are not in a list of FBS
# schools. Florida A&M was skipped at 2026-09-08 19:56 UTC, an hour after it
# ran, so it was never on the list - and it has stayed missing since, which
# means every Miami-Florida A&M listing produces no lines at all.
#
# "Florida A&M" goes in region because that is the exact string Bovada sends,
# and region is what find_by_string matches it on.
#
# abbreviation is deliberately left nil rather than set to "Florida A&M" too.
# The other FCS rows carry a *short* form there ("N Dakota St", "Sacramento
# St") because Bovada was seen sending that form as well; for this school we
# have only ever observed the full string. Repeating region in abbreviation
# would match nothing that region does not already match. When a second form
# turns up in a skip report, add it as a nickname.
class AddFloridaAmFcsOpponent < ActiveRecord::Migration[7.0]
  NCAAF = 1

  # Local models, so a later change to the real Competitor - a validation, a
  # default, a renamed column - cannot retroactively break this migration.
  class Competitor < ActiveRecord::Base
    self.table_name = "competitors"
  end

  class Contestant < ActiveRecord::Base
    self.table_name = "contestants"
  end

  REGION = "Florida A&M".freeze
  NAME = "Rattlers".freeze

  def up
    return if Competitor.exists?(sport: NCAAF, region: REGION, name: NAME)

    Competitor.create!(
      sport: NCAAF,
      region: REGION,
      name: NAME,
      nicknames: [],
      full_name: "#{REGION} #{NAME}".squish
    )
  end

  # Never destroys a row a contestant points at: rolling this back is a
  # correction to the competitor list, not permission to orphan a played game.
  def down
    competitor = Competitor.find_by(sport: NCAAF, region: REGION, name: NAME)
    return if competitor.nil? || Contestant.exists?(competitor_id: competitor.id)

    competitor.destroy!
  end
end
