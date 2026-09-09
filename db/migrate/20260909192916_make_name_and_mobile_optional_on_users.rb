# An invited-but-not-yet-accepted user is a bare row: devise_invitable
# creates it from an email address alone. name is required again as soon as
# the invitation is accepted (see User#invited_to_sign_up?); mobile is not
# collected at signup at all and nothing in the app depends on it being
# present.
class MakeNameAndMobileOptionalOnUsers < ActiveRecord::Migration[7.0]
  def change
    change_column_null :users, :name, true
    change_column_null :users, :mobile, true
  end
end
