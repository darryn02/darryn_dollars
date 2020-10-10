class CreateContestants < ActiveRecord::Migration[5.0]
  def change
    create_table :contestants do |t|
      t.belongs_to :game, foreign_key: true, null: false, index: true
      t.belongs_to :competitor, foreign_key: true, null: false, index: true

      t.timestamps
    end
  end
end
