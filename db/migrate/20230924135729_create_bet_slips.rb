class CreateBetSlips < ActiveRecord::Migration[7.0]
  def change
    create_table :bet_slips do |t|

      t.timestamps
    end
  end
end
