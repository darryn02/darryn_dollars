require "rails_helper"

# A player with several accounts is given a button per account and no account
# chosen for them. The server holds the same line: a bet that names no account
# is not quietly given one.
RSpec.describe "Naming the account a wager is for", type: :request do
  let(:player) { create_user(name: "Joe Player") }
  let!(:big) { create_account(user: player, name: "Big Joe") }
  let!(:little) { create_account(user: player, name: "Little Joe") }

  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let(:card) { create_full_card(game: game) }

  before { sign_in player }

  def post_wager(account_id: nil)
    wager = { line_id: card[:away_spread].id, amount: "100" }
    wager[:account_id] = account_id if account_id

    post wagers_path, params: { wager: wager }, xhr: true
  end

  it "adds nothing when no account is named, and says what is missing" do
    expect { post_wager }.not_to change(Wager, :count)

    expect(response.body).to include("Choose which account this bet is for.")
  end

  it "adds the wager to the account that was named" do
    expect { post_wager(account_id: little.id) }.to change { Wager.where(account_id: little.id).count }.by(1)

    expect(Wager.where(account_id: big.id).count).to eq(0)
  end
end
