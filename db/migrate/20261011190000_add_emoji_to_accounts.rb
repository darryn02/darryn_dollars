# The avatar a player picks for one of their accounts, so two accounts under
# one login can be told apart at a glance on the bet sheet and the slips.
# Nil means "not picked", and the avatar falls back to the account's initials.
class AddEmojiToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :emoji, :string
  end
end
