require "rails_helper"

# What a signed-in player can actually reach by typing a URL, as opposed to
# what the views offer them. Every assertion here is about a consequence - a
# payment that should not exist, a status that should not have moved - rather
# than about how the refusal is implemented, so a redirect, a 404 or a raised
# exception would all satisfy them.
RSpec.describe "Authorization", type: :request do
  let(:player) { create_user(name: "Plain Player") }
  let!(:player_account) { create_account(user: player) }

  let(:admin) { create_user(name: "The Book", admin: true) }
  let!(:admin_account) { create_account(user: admin) }

  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let(:card) { create_full_card(game: game) }

  describe "the admin dashboard" do
    it "is not reachable by a player" do
      sign_in player

      get admin_dashboard_path

      expect(response).not_to have_http_status(:ok)
    end

    it "is reachable by an admin" do
      sign_in admin

      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "recording a payment" do
    it "is refused for a player, who could otherwise credit their own account" do
      sign_in player

      expect {
        post admin_payments_path, params: { payment: { account_id: player_account.id, amount: "10000" } }
      }.not_to change(Payment, :count)
    end

    it "is allowed for an admin" do
      sign_in admin

      expect {
        post admin_payments_path, params: { payment: { account_id: player_account.id, amount: "100" } }
      }.to change(Payment, :count).by(1)
    end
  end

  describe "scoring a wager" do
    let!(:wager) { create_wager(account: player_account, line: card[:away_spread], amount: 100, status: :confirmed) }

    it "is refused for a player scoring their own bet a winner" do
      sign_in player

      get mark_as_win_wagers_path(id: wager.id)

      expect(wager.reload).to be_confirmed
    end

    it "is allowed for an admin" do
      sign_in admin

      get mark_as_win_wagers_path(id: wager.id)

      expect(wager.reload).to be_win
    end
  end

  describe "another player's wager" do
    let(:other) { create_user(name: "Someone Else") }
    let!(:other_account) { create_account(user: other) }
    let!(:their_wager) { create_wager(account: other_account, line: card[:away_spread], amount: 100) }

    it "cannot be cancelled by a player who does not own it" do
      sign_in player

      delete wager_path(their_wager), headers: { "Accept" => "text/javascript" }

      expect(Wager.exists?(their_wager.id)).to be(true)
    end
  end

  describe "another player's bet slip" do
    let(:other) { create_user(name: "Someone Else") }
    let!(:other_account) { create_account(user: other) }
    let!(:their_wager) { create_wager(account: other_account, line: card[:away_spread], amount: 100) }

    it "cannot be confirmed by a player who does not own it" do
      sign_in player

      patch bet_slip_path(their_wager.bet_slip)

      expect(their_wager.bet_slip.reload).to be_pending
    end

    it "cannot be emptied by a player who does not own it" do
      sign_in player

      delete bet_slip_path(their_wager.bet_slip)

      expect(Wager.exists?(their_wager.id)).to be(true)
    end
  end

  describe "another player's account settings" do
    let(:victim) { create_user(name: "Victim", password: "original-password") }

    it "cannot have its password changed by another player" do
      sign_in player

      patch user_path(victim), params: {
        user: { password: "attacker-chosen", password_confirmation: "attacker-chosen" }
      }

      expect(victim.reload.valid_password?("original-password")).to be(true)
    end

    it "cannot have its name changed by another player" do
      sign_in player

      patch user_path(victim), params: { user: { name: "Renamed By Someone Else" } }

      expect(victim.reload.name).to eq("Victim")
    end
  end

  # The guards above are only half the story: each one has a path it must not
  # have closed. Without these, an over-tight check would look exactly like a
  # passing suite.
  describe "what the owner is still allowed to do" do
    let!(:wager) { create_wager(account: player_account, line: card[:away_spread], amount: 100) }

    it "cancels their own pending wager" do
      sign_in player

      delete wager_path(wager), headers: { "Accept" => "text/javascript" }

      expect(Wager.exists?(wager.id)).to be(false)
    end

    it "confirms their own bet slip" do
      sign_in player

      patch bet_slip_path(wager.bet_slip)

      expect(wager.bet_slip.reload).to be_confirmed
      expect(wager.reload).to be_confirmed
    end

    it "empties their own bet slip" do
      sign_in player

      delete bet_slip_path(wager.bet_slip)

      expect(Wager.exists?(wager.id)).to be(false)
    end

    it "changes their own name" do
      sign_in player

      patch user_path(player), params: { user: { name: "Renamed Myself" } }

      expect(player.reload.name).to eq("Renamed Myself")
    end

    it "changes their own password" do
      sign_in player

      patch user_path(player), params: {
        user: { password: "brand-new-password", password_confirmation: "brand-new-password" }
      }

      expect(player.reload.valid_password?("brand-new-password")).to be(true)
    end
  end

  describe "what an admin is still allowed to do" do
    let(:other) { create_user(name: "Someone Else") }
    let!(:other_account) { create_account(user: other) }
    let!(:their_wager) { create_wager(account: other_account, line: card[:away_spread], amount: 100) }

    it "cancels a player's wager on their behalf" do
      sign_in admin

      delete wager_path(their_wager), headers: { "Accept" => "text/javascript" }

      expect(Wager.exists?(their_wager.id)).to be(false)
    end

    it "changes a player's name" do
      sign_in admin

      patch user_path(other), params: { user: { name: "Corrected Name" } }

      expect(other.reload.name).to eq("Corrected Name")
    end
  end
end
