require "rails_helper"

# Confirm and Cancel all sit on one account's pending slip and count only that
# slip's wagers on the button. Both used to act on every pending wager the
# player had, across every account - so a player with two accounts could not
# confirm one slip while fixing the other, and "Cancel all" on one emptied
# both.
RSpec.describe "Confirming and cancelling a pending slip", type: :request do
  let(:player) { create_user(name: "Joe Player") }
  let!(:big) { create_account(user: player, name: "Big Joe") }
  let!(:little) { create_account(user: player, name: "Little Joe") }

  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let(:card) { create_full_card(game: game) }

  let!(:big_wager) { create_wager(account: big, line: card[:away_spread], amount: 100) }
  let!(:little_wager) { create_wager(account: little, line: card[:over], amount: 100) }

  before { sign_in player }

  describe "confirm" do
    it "confirms the slip it was pressed on and leaves the other account pending" do
      post confirm_pending_wagers_path(account_id: big.id)

      expect(big_wager.reload).to be_confirmed
      expect(little_wager.reload).to be_pending
    end

    # A page left open across the deploy still carries the old link, with no
    # account on it. Confirming everything is the behaviour being removed, so
    # it confirms nothing.
    it "confirms nothing when it is not told which slip" do
      post confirm_pending_wagers_path

      expect(big_wager.reload).to be_pending
      expect(little_wager.reload).to be_pending
    end

    it "refuses an account that belongs to somebody else" do
      other = create_user(name: "Someone Else")
      their_account = create_account(user: other)
      their_wager = create_wager(account: their_account, line: card[:under], amount: 100)

      post confirm_pending_wagers_path(account_id: their_account.id)

      expect(their_wager.reload).to be_pending
    end
  end

  describe "cancel all" do
    it "cancels the slip it was pressed on and leaves the other account alone" do
      delete cancel_pending_wagers_path(account_id: big.id)

      expect(Wager.exists?(big_wager.id)).to be(false)
      expect(little_wager.reload).to be_pending
    end

    it "cancels nothing when it is not told which slip" do
      expect { delete cancel_pending_wagers_path }.not_to change(Wager, :count)
    end

    it "refuses an account that belongs to somebody else" do
      other = create_user(name: "Someone Else")
      their_account = create_account(user: other)
      create_wager(account: their_account, line: card[:under], amount: 100)

      expect {
        delete cancel_pending_wagers_path(account_id: their_account.id)
      }.not_to change(Wager, :count)
    end
  end

  # The request specs above pin the controller. This pins the other half: the
  # button on each slip has to say which slip it is on.
  describe "the bet slips page" do
    it "points each slip at its own account" do
      get bet_slip_wagers_path

      expect(response.body).to include(confirm_pending_wagers_path(account_id: big.id))
      expect(response.body).to include(confirm_pending_wagers_path(account_id: little.id))
      expect(response.body).to include(cancel_pending_wagers_path(account_id: big.id))
      expect(response.body).to include(cancel_pending_wagers_path(account_id: little.id))
    end
  end
end
