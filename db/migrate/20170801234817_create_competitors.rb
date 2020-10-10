class CreateCompetitors < ActiveRecord::Migration[5.0]
  def change
    create_table :competitors do |t|
      t.integer :sport, null: false
      t.string :abbreviation
      t.string :nicknames, array: true, default: [], null: false
      t.string :region
      t.string :name, null: false
      t.string :full_name, null: false

      t.timestamps
    end

    add_index :competitors, :sport
    add_index :competitors, :abbreviation
    add_index :competitors, :nicknames, using: :gin
    add_index :competitors, 'lower(region)'
    add_index :competitors, 'lower(name)'
  end
end
