require "rails_helper"

# What the admin sees that a player must not. The endpoints behind these
# controls are covered separately in spec/requests/authorization_spec.rb -
# hiding a button is presentation, not protection.
RSpec.describe "Admin-only surfaces", type: :system do
  let(:player) { create_user(name: "Plain Player") }
  let!(:player_account) { create_account(user: player) }

  let(:admin) { create_user(name: "The Book", admin: true) }
  let!(:admin_account) { create_account(user: admin) }

  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let!(:card) { create_full_card(game: game) }

  let!(:player_wager) do
    create_wager(account: player_account, line: card[:away_spread], amount: 100, status: :confirmed)
  end

  describe "the scoring controls on a confirmed wager" do
    it "are not offered to the player who placed it" do
      login_as(player, scope: :user)

      visit bet_slip_wagers_path

      expect(page).to have_css(".dd-slip--confirmed", text: "BUF +2.5")
      expect(page).to have_no_css(".dd-score")
      expect(page).to have_no_css(".dd-score__btn--win")
    end

    it "are offered to an admin" do
      login_as(admin, scope: :user)

      visit bet_slip_wagers_path

      expect(page).to have_css(".dd-score__btn--win")
      expect(page).to have_css(".dd-score__btn--loss")
      expect(page).to have_css(".dd-score__btn--push")
    end
  end

  describe "whose bets are listed" do
    let(:other_player) { create_user(name: "Someone Else") }
    let!(:other_account) { create_account(user: other_player) }
    let!(:other_wager) do
      create_wager(account: other_account, line: card[:home_spread], amount: 250, status: :confirmed)
    end

    it "is only your own, for a player" do
      login_as(player, scope: :user)

      visit bet_slip_wagers_path

      expect(page).to have_content("BUF +2.5")
      expect(page).to have_no_content("MIA -2.5")
      expect(page).to have_no_content("$250.00")
    end

    it "is everybody's, for an admin" do
      login_as(admin, scope: :user)

      visit bet_slip_wagers_path

      expect(page).to have_content("BUF +2.5")
      expect(page).to have_content("MIA -2.5")
      expect(page).to have_content("Plain Player")
      expect(page).to have_content("Someone Else")
    end
  end

  describe "the admin dashboard" do
    it "shows every account's position to an admin" do
      login_as(admin, scope: :user)

      visit admin_dashboard_path

      expect(page).to have_css(".dd-page-title", text: "Admin")
      expect(page).to have_content("Plain Player")
      expect(page).to have_content("Account Summary")
      expect(page).to have_content("Enter Payment")
    end
  end
end
