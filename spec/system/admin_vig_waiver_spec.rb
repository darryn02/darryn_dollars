require "rails_helper"

RSpec.describe "Waiving the vig from the admin screen", type: :system do
  let(:admin) { create_user(name: "The Book", admin: true) }
  let!(:admin_account) { create_account(user: admin) }

  let(:player) { create_user(name: "Plain Player") }
  let!(:player_account) { create_account(user: player) }

  let(:game) { create_game(starts_at: 2.hours.ago) }
  let(:away) { game.contestants.order(:priority).first }
  let(:line) { create_spread(game: game, contestant: away, value: -3.0, odds: -110) }

  before { login_as(admin, scope: :user) }

  it "goes from the dashboard, through the preview, to a credited loss" do
    wager = create_wager(account: player_account, line: line, amount: 110, status: :loss)

    visit admin_dashboard_path
    click_link "Waive the Vig"

    within(".dd-panel", text: "One line") do
      # Game#to_s uses %l (space-padded hour), which browsers collapse when
      # rendering option text - squish so the expected string matches what is
      # actually visible, regardless of the hour it happens to be run at.
      select "#{game} — #{line}".squish, from: "Line"
      click_button "Preview"
    end

    expect(page).to have_content("Plain Player")
    expect(page).to have_content("Loss becomes -$100.00, was -$110.00")

    check "wager_#{wager.id}"
    click_button "Waive the vig on checked wagers"

    expect(page).to have_content("Waived the vig on 1 wager(s).")
    expect(wager.reload).to be_vig_waived
    expect(wager.net).to eq(-100)
  end

  it "shows the player a visible sign of the discount in their history" do
    wager = create_wager(account: player_account, line: line, amount: 110, status: :loss)
    wager.update!(vig_waived: true)

    login_as(player, scope: :user)
    visit history_wagers_path

    expect(page).to have_css(".dd-vig-badge", text: "Vig waived")
    expect(page).to have_content("-$100.00")
    expect(page).to have_no_content("-$110.00")
  end

  it "reaches every market at once with All markets, for a whole game" do
    total_line = create_total(game: game, kind: :over, value: 47.5, odds: -110)
    spread_wager = create_wager(account: player_account, line: line, amount: 110, status: :loss)
    total_wager = create_wager(account: player_account, line: total_line, amount: 110, status: :loss)

    visit new_admin_vig_waiver_path
    within(".dd-panel", text: "One game") do
      select game.to_s.squish, from: "Game"
      select "All markets", from: "Market"
      click_button "Preview"
    end

    expect(page).to have_content("Loss becomes -$100.00, was -$110.00", count: 2)

    check "wager_#{spread_wager.id}"
    check "wager_#{total_wager.id}"
    click_button "Waive the vig on checked wagers"
    expect(page).to have_content("Waived the vig on 2 wager(s).")

    expect(spread_wager.reload).to be_vig_waived
    expect(total_wager.reload).to be_vig_waived
  end

  it "clears a waiver from the preview screen" do
    wager = create_wager(account: player_account, line: line, amount: 110, status: :loss)
    wager.update!(vig_waived: true)

    visit admin_vig_waivers_path(scope_type: "line", line_id: line.id)
    accept_confirm { click_link "Clear" }

    expect(page).to have_content("Cleared the vig waiver.")
    expect(wager.reload).not_to be_vig_waived
    expect(wager.net).to eq(-110)
  end
end
