class AddScoresToContestants < ActiveRecord::Migration[7.0]
  def change
    add_column :contestants, :scores, :integer, array: true, default: [], null: false
  end
end
