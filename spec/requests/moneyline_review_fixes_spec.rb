require "rails_helper"

# Regressions for the defects the 2026-09-20 review found. Each one was
# reproduced before it was fixed.
RSpec.describe "Defects found in review", type: :request do
  let(:player) { create_user }
  let!(:account) { create_account(user: player) }
  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let(:away) { game.contestants.order(:priority).first }

  # A slip can now sit part-confirmed, which made two pre-existing
  # whole-slip operations routine rather than unreachable.
  describe "a part-confirmed bet slip" do
    let(:card) { create_full_card(game: game) }
    let(:slip) { BetSlip.create!(account: account, status: :pending) }

    it "does not reconfirm a settled wager, or erase the net it recorded" do
      settled = create_wager(account: account, line: card[:away_spread], amount: 100, bet_slip: slip)
      settled.confirmed!
      settled.loss!

      sign_in player
      patch bet_slip_path(slip)

      expect(settled.reload).to be_loss
      expect(settled.net).to eq(-100)
    end

    it "cancels only the pending wagers, leaving accepted ones alone" do
      accepted = create_wager(account: account, line: card[:away_spread], amount: 100, bet_slip: slip)
      accepted.confirmed!
      still_pending = create_wager(account: account, line: card[:over], amount: 100, bet_slip: slip)

      sign_in player
      delete bet_slip_path(slip)

      expect(Wager.exists?(accepted.id)).to be(true)
      expect(Wager.exists?(still_pending.id)).to be(false)
    end

    it "counts what this attempt confirmed, not what the slip already held" do
      create_wager(account: account, line: create_moneyline(game: game, contestant: away, odds: 240),
                   amount: 100, bet_slip: slip)
      ENV["MONEYLINE_MAX_ODDS"] = "150"

      sign_in player
      patch bet_slip_path(slip)
      follow_redirect!

      expect(flash[:alert]).to match(/0 wager\(s\) confirmed/)
    end
  end

  # The exclusion lived only on the dropdown. scope_type "line" selects on
  # line_id alone and never consults Line::KIND_GROUPS, so a hand-submitted
  # id still waived - turning a $100 loss at -500 into a $20 one.
  describe "the admin vig waiver reached by an exact line id" do
    let(:admin) { create_user(name: "The Book", admin: true) }
    let!(:admin_account) { create_account(user: admin) }

    it "selects no moneyline wagers, however the line is named" do
      moneyline = create_moneyline(game: game, contestant: away, odds: -500)
      wager = create_wager(account: account, line: moneyline, amount: 100)
      wager.confirmed!
      wager.loss!

      sign_in admin

      # The preview offers it up...
      get admin_vig_waivers_path, params: { scope_type: "line", line_id: moneyline.id }
      expect(response.body).not_to include(wager.to_s)

      # ...and submitting it anyway waives nothing. -500 is where this bit
      # hardest: the waiver turned a $100 loss into a $20 one.
      post admin_vig_waivers_path, params: {
        scope_type: "line", line_id: moneyline.id, wager_ids: [wager.id]
      }

      expect(wager.reload).not_to be_vig_waived
      expect(wager.net).to eq(-100)
    end
  end
end
