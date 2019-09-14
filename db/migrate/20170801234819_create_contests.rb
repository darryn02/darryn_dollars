class CreateContests < ActiveRecord::Migration[5.0]
  def change
    create_table :contests do |t|
      t.string :name
      t.boolean :primary, default: false, null: false
      t.references :game, foreign_key: true, null: false, index: true

      t.timestamps
    end
  end
end
