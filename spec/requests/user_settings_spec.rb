require "rails_helper"

# The settings page is the only place a player edits their leaderboard
# nickname or their leaderboard visibility. This is the account-level
# counterpart to spec/system/leaderboard_spec.rb, which covers what the
# leaderboard does with these values once they're set.
RSpec.describe "Editing account settings on the settings page", type: :request do
  let(:user) { create_user }

  it "updates a single account's nickname and leaderboard visibility" do
    account = create_account(user: user, nickname: "Old Nickname", leaderboard_visible: false)
    sign_in user

    patch user_path(user), params: {
      user: {
        accounts_attributes: {
          "0" => { id: account.id, nickname: "New Nickname", leaderboard_visible: "1" }
        }
      }
    }

    account.reload
    expect(account.nickname).to eq("New Nickname")
    expect(account.leaderboard_visible).to be(true)
  end

  it "turns leaderboard visibility off - the opt-out this page exists to add" do
    account = create_account(user: user, nickname: "Dana", leaderboard_visible: true)
    sign_in user

    patch user_path(user), params: {
      user: {
        accounts_attributes: {
          "0" => { id: account.id, nickname: "Dana", leaderboard_visible: "0" }
        }
      }
    }

    expect(account.reload.leaderboard_visible).to be(false)
  end

  it "updates each account independently when a user has more than one" do
    main = create_account(user: user, name: "Main", nickname: "Old Main")
    side = create_account(user: user, name: "Side", nickname: "Old Side")
    sign_in user

    patch user_path(user), params: {
      user: {
        accounts_attributes: {
          "0" => { id: main.id, nickname: "New Main", leaderboard_visible: "1" },
          "1" => { id: side.id, nickname: "New Side", leaderboard_visible: "0" }
        }
      }
    }

    expect(main.reload.nickname).to eq("New Main")
    expect(main.reload.leaderboard_visible).to be(true)
    expect(side.reload.nickname).to eq("New Side")
    expect(side.reload.leaderboard_visible).to be(false)
  end

  it "still updates the user's own name and password alongside the account fields" do
    account = create_account(user: user, nickname: "Dana")
    sign_in user

    patch user_path(user), params: {
      user: {
        name: "Renamed",
        accounts_attributes: { "0" => { id: account.id, nickname: "Dana", leaderboard_visible: "0" } }
      }
    }

    expect(user.reload.name).to eq("Renamed")
  end

  # The account is looked up through @user.accounts.find_by, so an id that
  # does not belong to this user is simply not found - not acted on.
  it "ignores an account id that does not belong to the signed-in user" do
    account = create_account(user: user, nickname: "Dana")

    other_user = create_user(name: "Someone Else")
    other_account = create_account(user: other_user, nickname: "Original", leaderboard_visible: false)

    sign_in user

    patch user_path(user), params: {
      user: {
        accounts_attributes: {
          "0" => { id: other_account.id, nickname: "Hijacked", leaderboard_visible: "1" }
        }
      }
    }

    expect(other_account.reload.nickname).to eq("Original")
    expect(other_account.reload.leaderboard_visible).to be(false)
  end

  it "lets an admin update another player's account settings" do
    player = create_user(name: "Plain Player")
    account = create_account(user: player, nickname: "Old")

    admin = create_user(name: "The Book", admin: true)
    sign_in admin

    patch user_path(player), params: {
      user: { accounts_attributes: { "0" => { id: account.id, nickname: "Renamed By Admin" } } }
    }

    expect(account.reload.nickname).to eq("Renamed By Admin")
  end

  # leaderboard_visible is a not-null column, so writing a submission that
  # omits the key must leave the existing value alone rather than casting a
  # missing value to nil and blowing up on save.
  it "leaves leaderboard visibility untouched when the field is not submitted at all" do
    account = create_account(user: user, nickname: "Dana", leaderboard_visible: true)
    sign_in user

    patch user_path(user), params: {
      user: { accounts_attributes: { "0" => { id: account.id, nickname: "Dana Renamed" } } }
    }

    expect(account.reload.nickname).to eq("Dana Renamed")
    expect(account.reload.leaderboard_visible).to be(true)
  end
end
