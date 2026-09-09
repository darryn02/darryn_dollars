require "rails_helper"

# `lines` has `on_delete: :nullify` against contestants, so a spread can outlive
# the side that gave it meaning. That used to raise NoMethodError while sorting
# the rows, which took down the whole board rather than the one line - every
# game disappeared because one of them had a widowed spread.
#
# The app runs with `show_exceptions = false` and Capybara re-raises server
# errors in the example, so on these specs simply reaching the board is most of
# the assertion.
RSpec.describe "The lines board", type: :system do
  let(:user) { create_user }
  let!(:account) { create_account(user: user) }
  let(:game) { create_game(starts_at: 2.hours.from_now) }

  before { login_as(user, scope: :user) }

  it "survives a spread whose side has been deleted" do
    card = create_full_card(game: game)
    away_contestant = game.contestants.order(:priority).first

    away_contestant.destroy
    expect(card[:away_spread].reload.contestant_id).to be_nil

    visit lines_path

    # The board is still standing, and the surviving side still trades.
    expect(page).to have_css(".dd-board")
    expect(page).to have_css(".dd-game__abbr", text: "MIA")
    expect(page).to have_css(".dd-bet-btn", text: "-2.5")

    # The unattributable spread leaves a gap rather than a guess.
    expect(page).to have_css(".dd-bet-cell--empty")

    # And the total, which has nothing to do with the missing side, is untouched.
    expect(page).to have_css(".dd-bet-btn", text: "O 47.5")
    expect(page).to have_css(".dd-bet-btn", text: "U 47.5")
  end

  it "names both sides when only one of them has a spread" do
    away_contestant = game.contestants.order(:priority).first
    create_spread(game: game, contestant: away_contestant, value: 2.5)
    create_total(game: game, kind: :over, value: 47.5)
    create_total(game: game, kind: :under, value: 47.5)

    visit lines_path

    expect(page).to have_css(".dd-game__abbr", text: "BUF")
    expect(page).to have_css(".dd-game__abbr", text: "MIA")
    expect(page).to have_css(".dd-bet-btn", text: "+2.5")
    expect(page).to have_css(".dd-bet-cell--empty")
  end

  it "says so plainly when there is nothing on the board" do
    visit lines_path

    expect(page).to have_css(".blank-state")
    expect(page).to have_content("No Game Lines Right Now")
    expect(page).to have_no_css(".dd-board")
  end
end
