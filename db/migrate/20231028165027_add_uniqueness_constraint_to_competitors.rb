class AddUniquenessConstraintToCompetitors < ActiveRecord::Migration[7.0]
  def change
    add_index :competitors, ["sport", "region", "name"], unique: true
  end
end
