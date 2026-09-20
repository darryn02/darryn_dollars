require "rails_helper"

RSpec.describe HouseLedger, type: :model do
  let(:admin) { create_user(name: "The Book", admin: true) }
  let(:dana) { create_user(name: "Dana Player") }
  let(:reg) { create_user(name: "Reg Player") }

  let(:dana_account) { create_account(user: dana) }
  let(:reg_account) { create_account(user: reg) }

  let(:game) { create_game(starts_at: 2.hours.ago) }
  let(:card) { create_full_card(game: game) }

  describe ".for" do
    # The gate is the constructor rather than a condition in a template, so a
    # view that forgets to ask gets nothing instead of everybody's money.
    it "builds nothing for a player" do
      expect(described_class.for(dana)).to be_nil
    end

    it "builds nothing for nobody at all" do
      expect(described_class.for(nil)).to be_nil
    end

    it "builds a ledger for the book" do
      expect(described_class.for(admin)).to be_a(described_class)
    end
  end

  describe "what it gathers" do
    it "crosses every account rather than one player's" do
      create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :win)
      create_wager(account: reg_account, line: card[:home_spread], amount: 200, status: :loss)

      expect(described_class.for(admin).rows.map(&:account_id)).
        to match_array([dana_account.id, reg_account.id])
    end

    it "leaves out wagers nobody has confirmed" do
      create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :pending)

      expect(described_class.for(admin).rows).to be_empty
    end

    it "keeps a push, which settled even though no money moved" do
      pushed = create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :push)

      expect(described_class.for(admin).settled_wagers).to eq([pushed])
    end
  end

  describe "ordering" do
    it "puts the most recently settled first" do
      older = create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :win)
      newer = create_wager(account: reg_account, line: card[:home_spread], amount: 200, status: :loss)

      older.update_column(:updated_at, 3.hours.ago)
      newer.update_column(:updated_at, 1.minute.ago)

      expect(described_class.for(admin).settled_wagers).to eq([newer, older])
    end

    # Open action has no settlement time to sort by, and it is the part the
    # book cannot bank yet - so it sits above the decided wagers rather than
    # being buried under them.
    it "floats open action above everything settled" do
      settled = create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :win)
      settled.update_column(:updated_at, 1.minute.ago)
      open = create_wager(account: reg_account, line: card[:home_spread], amount: 200, status: :confirmed)

      expect(described_class.for(admin).rows).to eq([open, settled])
    end
  end

  describe "the book's side of it" do
    # The house is the counterparty, so a player's win is its loss. Getting
    # this backwards would report a losing week as a winning one.
    it "reads a player's win as money out" do
      won = create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :win)

      expect(described_class.for(admin).house_net(won)).to be_negative
      expect(described_class.for(admin).house_net(won)).to eq(-won.net)
    end

    it "reads a player's loss as money in" do
      lost = create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :loss)

      expect(described_class.for(admin).house_net(lost)).to be_positive
    end

    it "totals the settled wagers from the book's side" do
      create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :loss)
      create_wager(account: reg_account, line: card[:home_spread], amount: 100, status: :win)

      ledger = described_class.for(admin)
      expected = ledger.settled_wagers.sum { |wager| -wager.net }

      expect(ledger.settled_net).to eq(expected)
    end

    # A push is not a win for anybody, and colouring it as one would overstate
    # a flat week.
    it "reads a push as neither" do
      pushed = create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :push)

      expect(described_class.for(admin).house_net(pushed)).to be_zero
    end

    it "counts what it would owe if every open wager came in" do
      one = create_wager(account: dana_account, line: card[:away_spread], amount: 100, status: :confirmed)
      two = create_wager(account: reg_account, line: card[:home_spread], amount: 200, status: :confirmed)

      expect(described_class.for(admin).exposure).to eq(one.potential_profit + two.potential_profit)
    end
  end
end
