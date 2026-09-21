require "rails_helper"

# The board is not a security boundary. WagersController#create takes any
# line_id with no kind check at all, and there are moneyline rows in the
# database whether or not the board offers them - so every case here posts
# a line_id directly rather than going through a button. That is the actual
# threat the kill switch and the odds bounds exist to stop.
RSpec.describe "Betting a moneyline directly", type: :request do
  let(:player) { create_user }
  let!(:account) { create_account(user: player) }
  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let(:away) { game.contestants.order(:priority).first }

  def moneyline(odds)
    create_moneyline(game: game, contestant: away, odds: odds)
  end

  def post_wager(line, amount: 100)
    post wagers_path, params: {
      wager: { line_id: line.id, account_id: account.id, amount: amount.to_s }
    }, xhr: true
  end

  describe "placing one" do
    it "is accepted inside the band" do
      sign_in player

      expect { post_wager(moneyline(240)) }.to change(Wager, :count).by(1)
    end

    it "is refused on an underdog past the cap" do
      sign_in player

      expect { post_wager(moneyline(450)) }.not_to change(Wager, :count)
    end

    it "is refused on a favorite past the bound" do
      sign_in player

      expect { post_wager(moneyline(-1200)) }.not_to change(Wager, :count)
    end

    # The cap is inclusive at the top and the bound exclusive at the bottom,
    # so the band is exactly (-1000, +300]. Both ends, both sides.
    it "takes the cap itself and refuses one point past it" do
      sign_in player

      expect { post_wager(moneyline(300)) }.to change(Wager, :count).by(1)
      expect { post_wager(moneyline(301)) }.not_to change(Wager, :count)
    end

    it "refuses the bound itself and takes one point inside it" do
      sign_in player

      expect { post_wager(moneyline(-1000)) }.not_to change(Wager, :count)
      expect { post_wager(moneyline(-999)) }.to change(Wager, :count).by(1)
    end

    # The pre-flight count found 12 of these in the live database. They
    # pass every bound - zero is inside (-1000, +300] - and Line#payout
    # returns nothing on them, so a player could have staked $100 on a
    # winner and been paid $0.
    it "is refused on a legacy row left at zero by the old EVEN parse" do
      sign_in player

      expect { post_wager(moneyline(0)) }.not_to change(Wager, :count)
    end

    it "is refused on any price at all when the switch is off" do
      ENV["MONEYLINE_ENABLED"] = "0"
      sign_in player

      expect { post_wager(moneyline(-150)) }.not_to change(Wager, :count)
    end

    it "leaves spread and total alone when the switch is off" do
      ENV["MONEYLINE_ENABLED"] = "0"
      sign_in player
      card = create_full_card(game: game)

      expect { post_wager(card[:away_spread]) }.to change(Wager, :count).by(1)
      expect { post_wager(card[:over]) }.to change(Wager, :count).by(1)
    end

    it "says why, rather than failing silently" do
      sign_in player

      post_wager(moneyline(450))

      expect(response.body).to match(/is not available to bet right now/)
    end
  end

  # The wager was legal when it was added and is not legal now: the cap was
  # tightened, or the switch was flipped, while the slip sat open.
  describe "confirming one that has stopped being offerable" do
    let!(:stale) do
      create_wager(account: account, line: moneyline(240), amount: 100, status: :pending)
    end

    before { ENV["MONEYLINE_MAX_ODDS"] = "150" }

    it "is refused through confirm_pending" do
      sign_in player

      post confirm_pending_wagers_path

      expect(stale.reload).to be_pending
      expect(account.reload.liabilities).to eq(0)
    end

    # Flipping the switch on an open slip used to raise out of a bare loop
    # and 500 the whole page.
    it "does not blow up the whole slip through bet_slips#update" do
      sign_in player

      expect { patch bet_slip_path(stale.bet_slip) }.not_to raise_error

      expect(response).to have_http_status(:redirect)
    end

    # A bare rescue would have left the slip confirmed and the success flash
    # intact, telling the player a rejected wager went through while it sat
    # pending, outside Account#liabilities, settling nothing.
    it "leaves the slip pending and says which wager did not go through" do
      sign_in player

      patch bet_slip_path(stale.bet_slip)

      expect(stale.reload).to be_pending
      expect(stale.bet_slip.reload).to be_pending
      follow_redirect!
      expect(flash[:alert]).to match(/could not be/)
    end

    it "confirms the wagers it can and refuses only the one it cannot" do
      sign_in player
      card = create_full_card(game: game)
      good = create_wager(account: account, line: card[:away_spread],
                          amount: 100, status: :pending, bet_slip: stale.bet_slip)

      patch bet_slip_path(stale.bet_slip)

      expect(good.reload).to be_confirmed
      expect(stale.reload).to be_pending
    end
  end

  # A wager placed before the cap moved is history. The admin vig-waiver
  # touches it with an ordinary update, which is neither a create nor a
  # confirm, so the bounds must not reach it.
  describe "an admin waiving the vig on a historical moneyline" do
    it "is not blocked by a cap that has since tightened" do
      wager = create_wager(account: account, line: moneyline(240),
                           amount: 100, status: :pending)
      wager.confirmed!
      ENV["MONEYLINE_MAX_ODDS"] = "150"

      expect { wager.update!(vig_waived: true) }.not_to raise_error
      expect(wager.reload).to be_vig_waived
    end

    it "is not blocked by the switch being turned off entirely" do
      wager = create_wager(account: account, line: moneyline(240),
                           amount: 100, status: :pending)
      wager.confirmed!
      ENV["MONEYLINE_ENABLED"] = "0"

      expect { wager.update!(vig_waived: true) }.not_to raise_error
    end
  end

  # The one the plan singles out: `validate :x, on: :create, if: :confirming?`
  # can never fire, because confirming? requires persisted? and a new record
  # is not. Written that way, the switch and both bounds would silently
  # enforce nothing at all in either context.
  describe "the validation's registration" do
    it "fires on create, where confirming? is false" do
      wager = Wager.new(account: account, bet_slip: BetSlip.create!(account: account, status: :pending),
                        line: moneyline(450), amount: 100, status: :pending)

      expect(wager).not_to be_valid
      expect(wager.errors[:line]).to be_present
    end

    it "fires on confirm, where new_record? is false" do
      wager = create_wager(account: account, line: moneyline(240), amount: 100, status: :pending)
      ENV["MONEYLINE_MAX_ODDS"] = "150"

      expect { wager.confirmed! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
