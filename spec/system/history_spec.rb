require "rails_helper"

RSpec.describe "Wager history", type: :system do
  let(:user) { create_user(name: "Dana Player") }
  let(:game) { create_game(starts_at: 2.hours.from_now) }

  before { login_as(user, scope: :user) }

  def card
    @card ||= create_full_card(game: game)
  end

  context "with more than one account" do
    let!(:main) { create_account(user: user, name: "Main") }
    let!(:side) { create_account(user: user, name: "Side") }

    before do
      create_wager(account: main, line: card[:away_spread], amount: 100, status: :win)
      create_wager(account: side, line: card[:home_spread], amount: 200, status: :loss)
    end

    it "separates the accounts into tabs you can switch between" do
      visit history_wagers_path

      expect(page).to have_css(".dd-account-tab", count: 2)

      within("#account-#{main.id}-tab-pane") do
        expect(page).to have_content("BUF +2.5")
      end

      find(".dd-account-tab", text: "Side").click

      within("#account-#{side.id}-tab-pane") do
        expect(page).to have_content("MIA -2.5")
        expect(page).to have_content("$200.00")
      end
    end
  end

  context "with a single account" do
    let!(:account) { create_account(user: user, credit_limit: 5_000, initial_balance: 1_000) }

    it "skips the tabs entirely" do
      create_wager(account: account, line: card[:away_spread], amount: 100, status: :win)

      visit history_wagers_path

      expect(page).to have_no_css(".dd-account-tab")
      expect(page).to have_css(".dd-account")
      expect(page).to have_content("BUF +2.5")
    end

    # This page is the only caller of Account#lose_sum in the app.
    it "totals the money in the account summary" do
      create_wager(account: account, line: card[:away_spread], amount: 100, status: :win)
      create_wager(account: account, line: card[:home_spread], amount: 300, status: :loss)

      visit history_wagers_path

      within(".dd-account__summary") do
        # The stat labels are uppercased in CSS.
        expect(page).to have_content(/starting balance/i)
        expect(page).to have_content("$1,000.00")

        # -110 on a $100 winner returns $90.91; the $300 loser costs its stake.
        expect(page).to have_css(".dd-account__stats", text: "$90.91")
        expect(page).to have_css(".dd-account__stats", text: "-$300.00")

        expect(page).to have_css(".progress[role='progressbar']")
      end

      expect(page).to have_css(".dd-result--win")
      expect(page).to have_css(".dd-result--loss")
    end

    it "says there is nothing to show before anything has settled" do
      visit history_wagers_path

      expect(page).to have_css(".blank-state")
      expect(page).to have_content("Nothing to see here")
    end
  end
end
