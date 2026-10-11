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
    # Nothing to tell this slip apart from, so nothing marking it and
    # nowhere to move a bet to.
    expect(page).to have_no_css(".dd-acct-avatar")
    expect(page).to have_no_css(".dd-slip__move")

    click_link "Confirm 1 wager"

    expect(page).to have_css(".dd-flash", text: "1 wagers confirmed.")
    expect(page).to have_css(".dd-slip--confirmed", text: "BUF +2.5")
    expect(page).to have_no_css(".dd-slip--pending")
  end

  it "asks a player with one account nothing about accounts" do
    visit lines_path

    open_bet_sheet(card[:away_spread], labelled: "+2.5")

    within("#betOffcanvas-#{card[:away_spread].id}") do
      expect(page).to have_button("Add to Bet Slip")
      expect(page).to have_no_css(".dd-bet-as")
    end
  end

  # One login, two accounts. The sheet used to carry a dropdown preselected
  # to the first account, and a bet for the other one meant remembering to
  # change it on every single bet.
  context "with more than one account" do
    let!(:account) { create_account(user: user, name: "Big Joe") }
    let!(:little) { create_account(user: user, name: "Little Joe") }

    let(:sheet) { "#betOffcanvas-#{card[:away_spread].id}" }

    it "offers a button per account and nothing chosen in advance" do
      visit lines_path

      open_bet_sheet(card[:away_spread], labelled: "+2.5")

      within(sheet) do
        expect(page).to have_no_css("select")
        expect(page).to have_no_button("Add to Bet Slip")
        expect(page).to have_css(".dd-bet-as__btn", count: 2)
        expect(page).to have_css(".dd-bet-as__btn .dd-acct-avatar", text: "BJ")
        expect(page).to have_css(".dd-bet-as__btn .dd-acct-avatar", text: "LJ")
        expect(page).to have_css(".dd-bet-as__btn", text: "$5,000 available", count: 2)
      end
    end

    it "puts the bet on the account whose button was pressed" do
      visit lines_path

      open_bet_sheet(card[:away_spread], labelled: "+2.5")

      within(sheet) do
        click_button "$100"
        find(".dd-bet-as__btn", text: "Little Joe").click
      end

      # Named, and marked with the same avatar as the button that was pressed.
      expect(page).to have_css(".flash-from-js", text: "Added to Little Joe's slip.")
      expect(page).to have_css(".flash-from-js .dd-acct-avatar", text: "LJ")
      expect(little.reload.wagers.count).to eq(1)
      expect(Wager.where(account_id: account.id).count).to eq(0)
    end

    # The wrong button is still one slip of the thumb away, so the
    # confirmation that names the account also takes the bet back.
    it "takes the bet back from the confirmation" do
      visit lines_path

      open_bet_sheet(card[:away_spread], labelled: "+2.5")

      within(sheet) do
        click_button "$100"
        find(".dd-bet-as__btn", text: "Big Joe").click
      end

      within(".flash-from-js") { click_link "Undo" }

      expect(page).to have_css(".flash-from-js", text: "has been cancelled")
      expect(Wager.count).to eq(0)
    end

    it "moves a pending bet to the other account from its slip" do
      create_wager(account: account, line: card[:away_spread], amount: 100)

      visit bet_slip_wagers_path

      within(".dd-slip--pending", text: "Big Joe Pending Wagers") do
        click_link "Move to Little Joe"
      end

      expect(page).to have_css(".dd-flash", text: "Moved to Little Joe's slip.")
      expect(page).to have_css(".dd-slip--pending", text: "Little Joe Pending Wagers")
      expect(page).to have_no_css(".dd-slip--pending", text: "Big Joe Pending Wagers")
      within(".dd-slip--pending") { expect(page).to have_link("Move to Big Joe") }
    end

    it "heads each slip with its account and confirms only the one pressed" do
      create_wager(account: account, line: card[:away_spread], amount: 100)
      create_wager(account: little, line: card[:over], amount: 100)

      visit bet_slip_wagers_path

      slips = all(".dd-slip--pending")
      expect(slips.size).to eq(2)

      # The same order as the buttons on the bet sheet.
      expect(slips[0]).to have_css(".dd-slip__header.dd-acct--0 .dd-acct-avatar", text: "BJ")
      expect(slips[0]).to have_css(".dd-slip__title", text: "Big Joe Pending Wagers")
      expect(slips[1]).to have_css(".dd-slip__header.dd-acct--1 .dd-acct-avatar", text: "LJ")

      click_link "Confirm Little Joe's 1 wager"

      expect(page).to have_css(".dd-flash", text: "1 wagers confirmed.")
      expect(page).to have_css(".dd-slip--confirmed", text: "Little Joe Confirmed Wagers")
      expect(page).to have_css(".dd-slip--pending", text: "Big Joe Pending Wagers")
      expect(Wager.where(account_id: account.id).first).to be_pending
    end

    # The single Add to Bet Slip button is disabled by Rails while its request
    # is in flight; the account buttons are hand-written and were not, so a
    # second tap before the sheet closed sent the bet twice.
    #
    # The test layout makes every XHR synchronous, which hides exactly this,
    # so it is switched back for the two taps. They are fired from one script
    # because that is the only way to land the second inside the first's
    # request.
    it "adds one bet when the account button is tapped twice" do
      visit lines_path

      open_bet_sheet(card[:away_spread], labelled: "+2.5")
      within(sheet) { click_button "$100" }

      page.execute_script(<<~JS)
        window.jQuery.ajaxSetup({ async: true });
        var button = document.querySelector("#{sheet} .dd-bet-as__btn");
        button.click();
        button.click();
      JS

      expect(page).to have_css(".flash-from-js", text: "Added to Big Joe's slip.")
      expect(page).to have_no_css("#{sheet}.show")
      expect(Wager.count).to eq(1)
    end

    # Enter presses a form's first submit button, which here would be the
    # first account's: a default by another route.
    it "adds nothing when Enter is pressed in the amount field" do
      visit lines_path

      open_bet_sheet(card[:away_spread], labelled: "+2.5")

      within(sheet) do
        click_button "$100"
        find(".js-wager-amount-bet").send_keys(:enter)
      end

      expect(page).to have_css("#{sheet}.show")
      expect(Wager.count).to eq(0)
    end
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
