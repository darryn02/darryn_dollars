# Nicknames are about to become what the leaderboard shows in place of a
# full name, so an account with no nickname yet needs a sane one before that
# ships. First name is a reasonable default and asks nobody to do anything;
# anyone who wants something else can still change it from settings.
#
# Only touches accounts with no nickname at all - an account that already has
# one (a father and son sharing a name distinguished as "Big"/"Little", say)
# is left exactly as it is.
class DefaultAccountNicknamesToFirstName < ActiveRecord::Migration[7.0]
  class Account < ActiveRecord::Base
    self.table_name = "accounts"
  end

  class User < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    Account.where(nickname: [nil, ""]).find_each do |account|
      first_name = first_name_for(account)
      next if first_name.blank?

      account.update_column(:nickname, first_name)
    end
  end

  # Best-effort: only undoes what this migration itself would have set, so an
  # account whose nickname was since changed by hand is left alone.
  def down
    Account.find_each do |account|
      first_name = first_name_for(account)
      next if first_name.blank? || account.nickname != first_name

      account.update_column(:nickname, nil)
    end
  end

  private

  def first_name_for(account)
    User.find_by(id: account.user_id)&.name.to_s.split.first
  end
end
