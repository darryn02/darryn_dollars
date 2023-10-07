class AddAccountToBetSlips < ActiveRecord::Migration[7.0]
  def change
    add_reference :bet_slips, :account, null: false, foreign_key: { on_delete: :cascade }
  end
end
