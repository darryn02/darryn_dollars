require "rails_helper"

# A bet added under the wrong account is put right by moving it, while it is
# still pending. Every assertion is on where the wager ends up.
RSpec.describe "Moving a pending wager to another account", type: :request do
  let(:player) { create_user(name: "Joe Player") }
  let!(:big) { create_account(user: player, name: "Big Joe") }
  let!(:little) { create_account(user: player, name: "Little Joe") }

  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let(:card) { create_full_card(game: game) }

  let!(:wager) { create_wager(account: big, line: card[:away_spread], amount: 100) }

  it "puts it on the other account's pending slip" do
    sign_in player

    patch move_wager_path(wager, account_id: little.id)

    wager.reload
    expect(wager.account).to eq(little)
    expect(wager.bet_slip.account).to eq(little)
    expect(wager.bet_slip).to be_pending
    expect(wager).to be_pending
    expect(flash[:notice]).to eq("Moved to Little Joe's slip.")
  end

  # Otherwise the moved wager would sit on a slip of its own beside the one
  # the account already has open.
  it "joins the pending slip the other account already has" do
    existing = create_wager(account: little, line: card[:over], amount: 100)
    sign_in player

    patch move_wager_path(wager, account_id: little.id)

    expect(wager.reload.bet_slip).to eq(existing.bet_slip)
  end

  # It then has to pass the same credit check as any other wager, against the
  # account it landed on.
  it "is confirmed against the account it was moved to" do
    little.update!(credit_limit: 50)
    sign_in player

    patch move_wager_path(wager, account_id: little.id)
    expect(wager.reload.account).to eq(little)

    post confirm_pending_wagers_path(account_id: little.id)

    expect(wager.reload).to be_pending
    expect(little.reload.liabilities).to eq(0)
  end

  it "leaves a confirmed wager where it is" do
    wager.update!(status: :confirmed)
    sign_in player

    patch move_wager_path(wager, account_id: little.id)

    expect(wager.reload.account).to eq(big)
  end

  # Two tabs, or two fast taps: Confirm commits after this request has read
  # the wager and before it writes. The decision was made on the copy in
  # memory, so a wager the book had just accepted against one account's
  # credit landed on the other with no check there.
  #
  # find_by is handed the copy read before the confirm, which is the state a
  # request is in at the moment it loses that race.
  it "leaves a wager that was confirmed after this request read it" do
    sign_in player
    read_before_the_confirm = Wager.find(wager.id)
    Wager.find(wager.id).update!(status: :confirmed)

    allow(Wager).to receive(:find_by).and_call_original
    allow(Wager).to receive(:find_by).with(id: wager.id.to_s).and_return(read_before_the_confirm)

    patch move_wager_path(wager, account_id: little.id)

    expect(wager.reload.account).to eq(big)
    expect(wager).to be_confirmed
  end

  # The same race from the other side: Confirm on Big Joe's slip holds a copy
  # read before the wager was moved to Little Joe. It used to confirm it
  # anyway, on the account it had moved to, having checked credit against the
  # one it had left.
  it "is not confirmed by a Confirm on the slip it has just left" do
    sign_in player
    read_before_the_move = Wager.find(wager.id)
    patch move_wager_path(wager, account_id: little.id)
    expect(wager.reload.account).to eq(little)

    allow_any_instance_of(WagersController).
      to receive(:pending_wagers_on_slip).and_return([read_before_the_move])

    post confirm_pending_wagers_path(account_id: big.id)

    expect(wager.reload).to be_pending
  end

  it "will not move a wager to somebody else's account" do
    other = create_user(name: "Someone Else")
    their_account = create_account(user: other)
    sign_in player

    patch move_wager_path(wager, account_id: their_account.id)

    expect(wager.reload.account).to eq(big)
  end

  it "will not let another player move it" do
    other = create_user(name: "Someone Else")
    create_account(user: other)
    sign_in other

    patch move_wager_path(wager, account_id: little.id)

    expect(wager.reload.account).to eq(big)
  end

  # The book reaches every account, but a move is still only ever between one
  # player's own accounts.
  it "lets the book move it between that player's accounts and no further" do
    admin = create_user(name: "The Book", admin: true)
    admin_account = create_account(user: admin)
    sign_in admin

    patch move_wager_path(wager, account_id: admin_account.id)
    expect(wager.reload.account).to eq(big)

    patch move_wager_path(wager, account_id: little.id)
    expect(wager.reload.account).to eq(little)
  end
end
