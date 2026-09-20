class AddRawOddsToLines < ActiveRecord::Migration[7.0]
  # The price Bovada actually published, before MoneylinePricer raised the
  # pair to the book's floor. Audit only - nothing settles or pays from it.
  #
  # Nullable, and deliberately nil on every kind but moneyline: spread and
  # total are hardcoded to -110 and have no raw price to remember, so the
  # column keeps one meaning rather than two.
  #
  # Not part of the find_or_create_by! lookup key, which was considered and
  # rejected: normalization is heavily many-to-one, so keying on it would
  # mint a new row on every raw tick that does not change the offered price,
  # and a new row is what invalidates a player's pending slip.
  def change
    add_column :lines, :raw_odds, :integer, null: true
  end
end
