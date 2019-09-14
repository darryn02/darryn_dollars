class CreateContestants < ActiveRecord::Migration[5.0]
  def change
    create_table :contestants do |t|
      t.references :contest, foreign_key: true, null: false, index: true
      t.references :competetor, foreign_key: true, null: false, index: true

      t.timestamps
    end
  end
end
