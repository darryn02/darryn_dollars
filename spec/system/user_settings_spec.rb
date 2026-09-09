require "rails_helper"

RSpec.describe "The settings page", type: :system do
  let(:user) { create_user(name: "Dana Player") }

  before { login_as(user, scope: :user) }

  # A single-account player should never have to think about which account a
  # field belongs to - one nickname field, unlabelled, no per-account
  # grouping.
  it "offers one plain nickname field when there is only one account" do
    account = create_account(user: user, nickname: "Dana")

    visit edit_user_path(user)

    expect(page).to have_field("Leaderboard nickname", with: "Dana")
    expect(page).to have_content("Show me on the leaderboard")
    expect(page).to have_no_content(account.name.to_s) if account.name.present?
  end

  it "saves the nickname and takes effect on the leaderboard" do
    account = create_account(user: user, nickname: "Dana", leaderboard_visible: true)

    visit edit_user_path(user)
    fill_in "Leaderboard nickname", with: "The Commissioner"
    click_button "Save changes"
    expect(page).to have_css(".dd-flash", text: "Settings updated")

    expect(account.reload.nickname).to eq("The Commissioner")

    visit leaderboard_path
    expect(page).to have_css(".dd-leaderboard__row", text: "The Commissioner")
    expect(page).to have_no_css(".dd-leaderboard__row", text: "Player")
  end

  it "lets a player opt back out of the leaderboard from settings" do
    account = create_account(user: user, nickname: "Dana", leaderboard_visible: true)

    visit edit_user_path(user)
    uncheck "Show me on the leaderboard"
    click_button "Save changes"
    expect(page).to have_css(".dd-flash", text: "Settings updated")

    expect(account.reload.leaderboard_visible).to be(false)

    visit leaderboard_path
    expect(page).to have_content("Pay to Play!")
  end

  # Two accounts means two fields, each clearly its own - the complication a
  # single-account player never has to see.
  it "offers one labelled field set per account when there is more than one" do
    create_account(user: user, name: "Main", nickname: "Main Nick")
    create_account(user: user, name: "Side", nickname: "Side Nick")

    visit edit_user_path(user)

    expect(page).to have_content("Main")
    expect(page).to have_content("Side")
    expect(page).to have_field("Leaderboard nickname", with: "Main Nick")
    expect(page).to have_field("Leaderboard nickname", with: "Side Nick")
  end

  it "updates each account's nickname independently" do
    main = create_account(user: user, name: "Main", nickname: "Main Nick")
    side = create_account(user: user, name: "Side", nickname: "Side Nick")

    visit edit_user_path(user)
    fill_in "Leaderboard nickname", with: "Renamed Main", match: :first
    all("input[name*='nickname']").last.set("Renamed Side")
    click_button "Save changes"
    expect(page).to have_css(".dd-flash", text: "Settings updated")

    expect(main.reload.nickname).to eq("Renamed Main")
    expect(side.reload.nickname).to eq("Renamed Side")
  end
end
