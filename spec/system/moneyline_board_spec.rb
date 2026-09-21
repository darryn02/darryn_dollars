require "rails_helper"

RSpec.describe "The moneyline column", type: :system do
  let(:user) { create_user(name: "Dana Player") }
  let!(:account) { create_account(user: user) }
  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let(:away) { game.contestants.order(:priority).first }
  let(:home) { game.contestants.order(:priority).second }

  before { login_as(user, scope: :user) }

  def moneyline(contestant, odds)
    create_moneyline(game: game, contestant: contestant, odds: odds)
  end

  describe "with the switch on" do
    before { create_full_card(game: game) }

    it "shows the price on the button, not the letters ML" do
      moneyline(away, -285)
      moneyline(home, 240)

      visit lines_path

      expect(page).to have_css(".dd-board__header", text: "ML")
      expect(page).to have_css(".dd-bet-btn", text: "-285")
      expect(page).to have_css(".dd-bet-btn", text: "+240")
    end

    it "takes a bet at the moneyline price, through the sheet" do
      line = moneyline(home, 240)
      moneyline(away, -285)

      visit lines_path
      find(".dd-bet-btn", text: "+240").click

      within("#betOffcanvas-#{line.id}") do
        # The sheet names the side, where the board cell names the price.
        expect(page).to have_content("MIA ML")
        expect(page).to have_content("240")
        click_button "$100"
        # +240 pays 2.4x the stake, and the form drives that off data-odds.
        expect(find(".js-wager-to-win").value).to eq("$240.00")
        click_button "Add to Bet Slip"
      end

      expect(page).to have_css(".flash-from-js", text: "Added to your bet slip")
      expect(Wager.last.line).to eq(line)
      expect(Wager.last.potential_profit).to eq(240.0)
    end

    # Roughly one game in seven. The withheld side keeps its price in the
    # closed treatment rather than blanking: --empty is aria-hidden, means
    # "never scraped", and fires on both sides at once. None of those is
    # true of a price the book has decided not to take.
    it "prints a capped underdog without a button, keeping its price" do
      moneyline(away, -394)
      moneyline(home, 450)

      visit lines_path

      expect(page).to have_css(".dd-bet-btn", text: "-394")
      expect(page).to have_css(".dd-bet-cell--closed", text: "+450")
      expect(page).to have_no_css(".dd-bet-btn", text: "+450")
    end

    it "keeps the withheld price on its own team's row" do
      moneyline(away, -394)
      moneyline(home, 450)

      visit lines_path

      home_row = find(:xpath, "//div[contains(concat(' ', normalize-space(@class), ' '), ' dd-game__row ')]" \
                              "[.//span[text()='MIA']]")
      expect(home_row).to have_css(".dd-bet-cell--closed", text: "+450")
    end

    it "takes the whole market off a game whose favorite is past the bound" do
      moneyline(away, -1200)
      moneyline(home, 900)

      visit lines_path

      expect(page).to have_css(".dd-bet-cell--closed", text: "-1200")
      expect(page).to have_css(".dd-bet-cell--closed", text: "+900")
      expect(page).to have_no_css(".dd-bet-btn", text: "-1200")
      expect(page).to have_no_css(".dd-bet-btn", text: "+900")
    end

    it "leaves spread and total buttons working alongside it" do
      moneyline(away, -285)
      moneyline(home, 240)

      visit lines_path

      expect(page).to have_css(".dd-bet-btn", text: "+2.5")
      expect(page).to have_css(".dd-bet-btn", text: "O 47.5")
    end
  end

  # The deploy that must be safe on its own: the code ships, the switch
  # stays unset, and the board is what it was. Not just the data - the
  # third cell, the header row and the four-column grid alike, or every
  # existing spread and total button narrows the moment this deploys.
  describe "with the switch off" do
    def board_markup
      visit lines_path
      page.find(".dd-board")[:innerHTML]
    end

    it "renders a board byte-identical to one with no moneyline rows at all" do
      create_full_card(game: game)
      ENV["MONEYLINE_ENABLED"] = "0"

      without_moneyline = board_markup

      moneyline(away, -285)
      moneyline(home, 240)

      expect(board_markup).to eq(without_moneyline)
    end

    it "adds no header row and no fourth column" do
      create_full_card(game: game)
      moneyline(away, -285)
      ENV["MONEYLINE_ENABLED"] = "0"

      visit lines_path

      expect(page).to have_css(".dd-game__row")
      expect(page).to have_no_css(".dd-board__header")
      expect(page).to have_no_css(".dd-game__row--ml")
      expect(page).to have_no_css(".dd-bet-btn", text: "-285")
    end
  end
end
