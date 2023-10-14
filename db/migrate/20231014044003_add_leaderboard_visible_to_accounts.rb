class AddLeaderboardVisibleToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :leaderboard_visible, :boolean, null: false, default: false
  end
end
