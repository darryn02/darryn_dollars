require "rails_helper"

RSpec.describe "The bottom nav", type: :system do
  let!(:account) { create_account(user: user) }

  before { login_as(user, scope: :user) }

  context "as a player" do
    let(:user) { create_user }

    it "offers the four player tabs and no way into the admin dashboard" do
      visit lines_path

      within(".dd-bottom-nav") do
        expect(page).to have_link("Lines")
        expect(page).to have_link("Bet Slips")
        expect(page).to have_link("History")
        expect(page).to have_link("Leaderboard")
        expect(page).to have_no_link("Admin")
      end
    end

    # The tab highlights by controller rather than by path, so it has to stay
    # lit while the sport and scope params move underneath it.
    it "marks the tab you are on" do
      visit lines_path

      expect(page).to have_css(".dd-bottom-nav__link.is-active", text: "Lines")

      within(".dd-bottom-nav") { click_link "History" }

      expect(page).to have_css(".dd-page-title", text: "History")
      expect(page).to have_css(".dd-bottom-nav__link.is-active", text: "History")
      expect(page).to have_css(".dd-bottom-nav__link[aria-current='page']", text: "History")
    end
  end

  context "as an admin" do
    let(:user) { create_user(admin: true) }

    it "adds the admin tab" do
      visit lines_path

      within(".dd-bottom-nav") { expect(page).to have_link("Admin") }
    end
  end
end
