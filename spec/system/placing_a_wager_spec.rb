require "rails_helper"

RSpec.describe "Placing a wager", type: :system do
  let(:user) { create_user(name: "Dana Player") }
  let!(:account) { create_account(user: user) }
  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let!(:card) { create_full_card(game: game) }

  before { login_as(user, scope: :user) }

  it "goes from the board to a confirmed slip" do
    visit lines_path

    expect(page).to have_css(".dd-game__abbr", text: "BUF")

    find(".dd-bet-btn", text: "+2.5").click

    within("#betOffcanvas-#{card[:away_spread].id}") do
      expect(page).to have_content("BUF +2.5")
      click_button "$100"
      click_button "Add to Bet Slip"
    end

    expect(page).to have_css(".flash-from-js", text: "Added to your bet slip")

    visit bet_slip_wagers_path

    expect(page).to have_css(".pending-bet-slip")
    expect(page).to have_content("BUF +2.5")
    expect(page).to have_content("$100.00")
  end
end
