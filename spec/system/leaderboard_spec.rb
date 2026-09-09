require "rails_helper"

RSpec.describe "The leaderboard", type: :system do
  let(:user) { create_user(name: "Dana Player") }
  let(:game) { create_game(starts_at: 2.hours.from_now) }

  before { login_as(user, scope: :user) }

  def card
    @card ||= create_full_card(game: game)
  end

  it "asks you to opt in before it shows anyone" do
    create_account(user: user)

    visit leaderboard_path

    expect(page).to have_css(".blank-state")
    expect(page).to have_content("Pay to Play!")
    expect(page).to have_no_css(".dd-leaderboard")
  end

  it "opts every one of your accounts in and then shows the standings" do
    account = create_account(user: user, name: "Main")
    other_account = create_account(user: user, name: "Side")

    visit leaderboard_path
    click_link "Include My Accounts and Show Me the Leaders!"

    expect(page).to have_css(".dd-leaderboard")
    expect(account.reload.leaderboard_visible).to be(true)
    expect(other_account.reload.leaderboard_visible).to be(true)
  end

  it "ranks the accounts, marks your own row and awards a hot streak" do
    mine = create_account(user: user, name: "Main", leaderboard_visible: true)

    rival_user = create_user(name: "Sam Rival")
    rival = create_account(user: rival_user, leaderboard_visible: true)

    # Three straight winners is the badge threshold, and puts this account top.
    3.times { create_wager(account: mine, line: card[:away_spread], amount: 100, status: :win) }
    create_wager(account: rival, line: card[:home_spread], amount: 100, status: :loss)

    visit leaderboard_path

    expect(page).to have_css(".dd-leaderboard__row", count: 2)

    rows = all(".dd-leaderboard__row")
    expect(rows.first).to have_content("Dana Player")
    expect(rows.first).to have_css(".dd-leaderboard__you", text: /you/i)
    expect(rows.last).to have_content("Sam Rival")

    expect(page).to have_css(".dd-badge", text: "3 straight")
    expect(page).to have_css(".dd-form__pip--win", minimum: 3)
  end
end
