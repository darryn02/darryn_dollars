class CreateBettingSlips < ActiveRecord::Migration[5.0]
  def change
    create_table :betting_slips do |t|
      t.belongs_to :user, foreign_key: true
      t.boolean :confirmed

      t.timestamps
    end
  end
end
