class AddInitialBalanceToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :initial_balance, :decimal, null: false, default: 0
  end
end
