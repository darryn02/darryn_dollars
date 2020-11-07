class CreateBettingSlips < ActiveRecord::Migration[5.0]
  def change
    create_table :betting_slips do |t|
      t.belongs_to :account, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :confirmed

      t.timestamps
    end
  end
end
