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
  # The combined ledger shows every player's money to whoever can see it, so
  # the test that matters most is the one proving a player cannot.
  describe "the book's combined view" do
    let(:rival) { create_user(name: "Reg Rival") }
    let!(:rival_account) { create_account(user: rival) }
    let!(:own_account) { create_account(user: user) }

    before do
      create_wager(account: own_account, line: card[:away_spread], amount: 100, status: :win)
      create_wager(account: rival_account, line: card[:home_spread], amount: 250, status: :loss)
    end

    context "as a player" do
      it "offers no ledger tab" do
        visit history_wagers_path

        expect(page).to have_no_css("#house-tab")
        expect(page).to have_no_content("The Book")
      end

      it "shows no other player's action anywhere on the page" do
        visit history_wagers_path

        expect(page).to have_no_content("Reg Rival")
        expect(page).to have_no_content("$250.00")
      end
    end

    context "as the book" do
      let(:user) { create_user(name: "Darryn Book", admin: true) }

      it "leads with a combined tab across every account" do
        visit history_wagers_path

        expect(page).to have_css("#house-tab", text: "The Book")

        within("#house-tab-pane") do
          expect(page).to have_content("Dana Player").or have_content("Darryn Book")
          expect(page).to have_content("Reg Rival")
        end
      end

      # A player winning costs the book, which is the opposite sign from the
      # one the player sees on their own history.
      it "reports each wager from the book's side" do
        visit history_wagers_path

        within("#house-tab-pane") do
          expect(page).to have_css(".dd-account__net.is-down", text: "-$90.91")
          expect(page).to have_css(".dd-account__net.is-up", text: "$250.00")
        end
      end

      it "marks action that has not settled instead of dating it" do
        create_wager(account: rival_account, line: card[:over], amount: 75, status: :confirmed)

        visit history_wagers_path

        within("#house-tab-pane") do
          expect(page).to have_css(".dd-ledger__row--open")
          expect(page).to have_content(/in play/i)
        end
      end

      it "still keeps a tab per account beside it" do
        visit history_wagers_path

        expect(page).to have_css(".dd-account-tab", minimum: 3)
      end
    end
  end
end
