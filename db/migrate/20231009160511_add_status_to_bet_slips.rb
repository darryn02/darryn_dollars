class AddStatusToBetSlips < ActiveRecord::Migration[7.0]
  def change
    add_column :bet_slips, :status, :integer, null: false, default: 0
  end
end
