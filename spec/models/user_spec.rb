require 'rails_helper'

RSpec.describe User, type: :model do
  describe "#chump? and #non_chump?" do
    it "is not a chump when admin" do
      user = create_user(admin: true)

      expect(user.chump?).to be(false)
      expect(user.non_chump?).to be(true)
    end

    it "is not a chump when the user is Chad, even without admin" do
      user = create_user
      stub_const("User::CHAD", user.id)

      expect(user.chump?).to be(false)
      expect(user.non_chump?).to be(true)
    end

    it "is a chump when neither admin nor Chad" do
      user = create_user
      stub_const("User::CHAD", user.id + 1)

      expect(user.chump?).to be(true)
      expect(user.non_chump?).to be(false)
    end
  end

  describe "invitations" do
    # devise_invitable saves the bare, freshly invited row with
    # validate: false (validate_on_invite defaults to false), so a row with
    # no name at all has to be creatable - it is the only way an invitation
    # can be sent before the person being invited has said anything about
    # themselves.
    it "can be invited with nothing but an email" do
      user = User.invite!(email: "friend@example.com")

      expect(user.errors).to be_empty
      expect(user.reload.name).to be_nil
      expect(user).to be_invited_to_sign_up
    end

    it "requires a name once accepting the invitation" do
      user = User.invite!(email: "friend@example.com")

      accepted = User.accept_invitation!(
        invitation_token: user.raw_invitation_token,
        password: "password123",
        password_confirmation: "password123"
      )

      expect(accepted.errors[:name]).to be_present
      expect(accepted.reload.invitation_accepted_at).to be_nil
    end

    it "requires a name on any later save too, not just the one that accepts" do
      user = create_user(name: "Real Name")

      user.name = nil

      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it "provisions exactly one account on acceptance, using the submitted nickname and visibility" do
      user = User.invite!(email: "friend@example.com")

      accepted = User.accept_invitation!(
        invitation_token: user.raw_invitation_token,
        name: "New Friend",
        password: "password123",
        password_confirmation: "password123",
        account_nickname: "Newbie",
        account_leaderboard_visible: "1"
      )

      expect(accepted.errors).to be_empty
      expect(accepted.accounts.count).to eq(1)

      account = accepted.accounts.first
      expect(account.nickname).to eq("Newbie")
      expect(account.leaderboard_visible).to be(true)
      expect(account.credit_limit).to eq(Account::DEFAULT_CREDIT_LIMIT)
    end

    it "falls back to the first name when no nickname was given" do
      user = User.invite!(email: "friend@example.com")

      accepted = User.accept_invitation!(
        invitation_token: user.raw_invitation_token,
        name: "New Friend",
        password: "password123",
        password_confirmation: "password123"
      )

      expect(accepted.accounts.first.nickname).to eq("New")
    end

    it "does not provision an account if the invitation is never accepted" do
      User.invite!(email: "friend@example.com")

      expect(Account.count).to eq(0)
    end
  end
end
