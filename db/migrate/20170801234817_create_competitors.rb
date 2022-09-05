class CreateCompetitors < ActiveRecord::Migration[5.0]
  def change
    enable_extension 'citext'
    create_table :competitors do |t|
      t.integer :sport, null: false
      t.citext :abbreviation
      t.citext :nicknames, array: true, default: [], null: false
      t.citext :region
      t.citext :name, null: false
      t.citext :full_name, null: false

      t.timestamps
    end

    add_index :competitors, :sport
    add_index :competitors, :abbreviation
    add_index :competitors, :nicknames, using: :gin
    add_index :competitors, :region
    add_index :competitors, :name
  end
end
