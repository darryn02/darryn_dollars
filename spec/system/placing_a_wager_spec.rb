require "rails_helper"

RSpec.describe "Placing a wager", type: :system do
  let(:user) { create_user(name: "Dana Player") }
  let!(:account) { create_account(user: user) }
  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let!(:card) { create_full_card(game: game) }

  before { login_as(user, scope: :user) }

  # Bootstrap moves focus onto the sheet when its opening transition ends.
  # Typing before that happens races it, and the keystrokes are swallowed - the
  # field comes back empty and the failure reads as a validation problem rather
  # than a timing one. Waiting for focus to land is waiting for Bootstrap to
  # have finished with the element.
  def open_bet_sheet(line, labelled:)
    find(".dd-bet-btn", text: labelled).click

    sheet = "#betOffcanvas-#{line.id}"
    expect(page).to have_css("#{sheet}.show")

    settled = wait_until do
      page.evaluate_script(
        "(function () { var s = document.querySelector(#{sheet.to_json}); " \
        "return !!s && s.contains(document.activeElement); })()"
      )
    end
    expect(settled).to be(true), "the bet sheet never took focus"
  end

  it "goes from the board to a confirmed slip" do
    visit lines_path

    expect(page).to have_css(".dd-game__abbr", text: "BUF")

    open_bet_sheet(card[:away_spread], labelled: "+2.5")

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

  # The chips are the whole point of the bet sheet on a phone - the alternative
  # is typing a number with one thumb while a game is on.
  it "fills the stake from a quick-amount chip and works out the return" do
    visit lines_path

    open_bet_sheet(card[:away_spread], labelled: "+2.5")

    within("#betOffcanvas-#{card[:away_spread].id}") do
      click_button "$100"

      expect(find(".js-wager-amount-bet").value).to eq("$100.00")
      # -110 pays 100/110 of the stake.
      expect(find(".js-wager-to-win").value).to eq("$90.91")
    end
  end

  it "refuses a stake under the minimum and adds nothing to the slip" do
    visit lines_path

    open_bet_sheet(card[:away_spread], labelled: "+2.5")

    # Addressed by class rather than by label: every bet sheet on the card
    # renders its own copy of this form, and simple_form gives each one the
    # same "wager_amount" id, so the label is not a unique handle.
    within("#betOffcanvas-#{card[:away_spread].id}") do
      find(".js-wager-amount-bet").set("25")
      expect(find(".js-wager-amount-bet").value).to be_present

      click_button "Add to Bet Slip"
    end

    expect(page).to have_css(".flash-from-js", text: "must be at least $#{Wager::DEFAULT_MIN_WAGER}")
    expect(Wager.count).to eq(0)

    visit bet_slip_wagers_path

    expect(page).to have_content("No open bets")
  end

  it "moves a pending slip into the confirmed section" do
    create_wager(account: account, line: card[:away_spread], amount: 100)

    visit bet_slip_wagers_path

    expect(page).to have_css(".dd-slip--pending")

    click_link "Confirm 1 wager"

    expect(page).to have_css(".dd-flash", text: "1 wagers confirmed.")
    expect(page).to have_css(".dd-slip--confirmed", text: "BUF +2.5")
    expect(page).to have_no_css(".dd-slip--pending")
  end

  # Betting opens Wager::WINDOW before kickoff. Before that the board is a
  # scoreboard, not a form - there is no button to press at all, which is what
  # a spec hunting for one needs to know.
  it "offers no bet button on a game the window has not opened for yet" do
    far_off = create_game(
      starts_at: 3.days.from_now,
      away: create_competitor(region: "Dallas", name: "Cowboys", abbreviation: "DAL"),
      home: create_competitor(region: "New York", name: "Giants", abbreviation: "NYG")
    )
    create_full_card(game: far_off)

    visit lines_path

    within(:xpath, "//div[@class='dd-game'][.//span[text()='DAL']]") do
      expect(page).to have_no_css(".dd-bet-btn")
      expect(page).to have_css(".dd-bet-cell--closed", text: "+2.5")
      # The pill is uppercased in CSS, so match without regard to case.
      expect(page).to have_css(".dd-game__status", text: /opens/i)
    end
  end
end
