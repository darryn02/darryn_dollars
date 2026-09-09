require "rails_helper"

RSpec.describe "Inviting a player", type: :request do
  let(:admin) { create_user(name: "The Book", admin: true) }
  let!(:admin_account) { create_account(user: admin) }

  let(:player) { create_user(name: "Plain Player") }
  let!(:player_account) { create_account(user: player) }

  describe "sending an invitation" do
    it "is not reachable by a player" do
      sign_in player

      get new_user_invitation_path

      expect(response).not_to have_http_status(:ok)
    end

    it "is reachable by an admin" do
      sign_in admin

      get new_user_invitation_path

      expect(response).to have_http_status(:ok)
    end

    it "is refused for a player even if they know the endpoint" do
      sign_in player

      expect {
        post user_invitation_path, params: { user: { email: "friend@example.com" } }
      }.not_to change(User, :count)
    end

    it "creates a bare invited user and emails them a link, for an admin" do
      sign_in admin

      expect {
        post user_invitation_path, params: { user: { email: "friend@example.com" } }
      }.to change(User, :count).by(1)

      invited = User.find_by(email: "friend@example.com")
      expect(invited).to be_invited_to_sign_up
      expect(invited.invited_by).to eq(admin)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(["friend@example.com"])
      expect(mail.body.encoded).to include("/users/invitation/accept")
    end

    it "requires being signed in at all" do
      get new_user_invitation_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "accepting an invitation" do
    let!(:invited) { User.invite!(email: "friend@example.com") }

    it "renders the accept form for a valid token, with no session required" do
      get accept_user_invitation_path(invitation_token: invited.raw_invitation_token)

      expect(response).to have_http_status(:ok)
    end

    it "creates the player's name, password and one account, then signs them in" do
      put user_invitation_path, params: {
        user: {
          invitation_token: invited.raw_invitation_token,
          name: "New Friend",
          password: "password123",
          password_confirmation: "password123",
          account_nickname: "Newbie",
          account_leaderboard_visible: "1"
        }
      }

      invited.reload
      expect(invited.name).to eq("New Friend")
      expect(invited.invitation_accepted_at).to be_present
      expect(invited.accounts.count).to eq(1)
      expect(invited.accounts.first.nickname).to eq("Newbie")
      expect(invited.accounts.first.leaderboard_visible).to be(true)

      follow_redirect!
      expect(response.body).to include("Lines")
    end

    it "rejects an invalid token" do
      put user_invitation_path, params: {
        user: {
          invitation_token: "not-a-real-token",
          name: "New Friend",
          password: "password123",
          password_confirmation: "password123"
        }
      }

      expect(User.find_by(email: "friend@example.com").invitation_accepted_at).to be_nil
    end

    it "cannot be used to set admin, or any account field beyond nickname and visibility" do
      put user_invitation_path, params: {
        user: {
          invitation_token: invited.raw_invitation_token,
          name: "New Friend",
          password: "password123",
          password_confirmation: "password123",
          admin: "1"
        }
      }

      expect(invited.reload.admin).not_to be(true)
    end
  end
end
