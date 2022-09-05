class CreateGames < ActiveRecord::Migration[5.0]
  def change
    create_table :games do |t|
      t.datetime :starts_at
      t.integer :sport, null: false
      t.integer :cached_competitor_ids, array: true, default: [], null: false
      t.string :md5_digest, null: false

      t.timestamps
    end

    add_index :games, :md5_digest
  end
end
