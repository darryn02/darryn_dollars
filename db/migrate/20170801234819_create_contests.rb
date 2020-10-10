class CreateContests < ActiveRecord::Migration[5.0]
  def change
    create_table :contests do |t|
      t.references :contestant, foreign_key: true, null: false, index: true
      t.integer :result

      t.timestamps
    end
  end
end
