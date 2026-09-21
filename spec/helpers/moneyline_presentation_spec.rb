require "rails_helper"

RSpec.describe "Moneyline presentation", type: :helper do
  let(:game) { create_game }
  let(:away) { game.contestants.order(:priority).first }

  # The board cell signed a positive price while the sheet, slip and
  # history showed a bare "240" for the same bet.
  it "signs a positive price the same way everywhere" do
    line = create_moneyline(game: game, contestant: away, odds: 240)

    expect(helper.moneyline_label(line)).to eq("+240")
    expect(helper.line_terms(line)).to eq("+240")
  end

  it "leaves a negative price and a spread's terms alone" do
    moneyline = create_moneyline(game: game, contestant: away, odds: -285)
    spread = create_spread(game: game, contestant: away, value: 2.5)

    expect(helper.line_terms(moneyline)).to eq("-285")
    expect(helper.line_terms(spread)).to eq("-110")
  end

  # A withheld cell was exposed to assistive tech as a bare "+450",
  # conveying neither the market nor that it could not be bet.
  describe "#moneyline_closed_note" do
    def row_for(odds, offered:)
      GameLinesViewModel::Row.new(
        competitor: away.competitor,
        moneyline: create_moneyline(game: game, contestant: away, odds: odds),
        moneyline_offered: offered
      )
    end

    it "names the side, the market and the unavailability" do
      note = helper.moneyline_closed_note(row_for(450, offered: false), wagerable: true)

      expect(note).to eq("BUF moneyline +450, not available")
    end

    it "says nothing about a side that is offered" do
      expect(helper.moneyline_closed_note(row_for(240, offered: true), wagerable: true)).to be_nil
    end

    # The game header already says the board is closed.
    it "says nothing once the game itself has closed" do
      expect(helper.moneyline_closed_note(row_for(450, offered: false), wagerable: false)).to be_nil
    end
  end
end
