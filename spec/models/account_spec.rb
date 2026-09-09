require 'rails_helper'

RSpec.describe Account, type: :model do
  it { should belong_to(:user) }
  it { should have_many(:bet_slips) }

  let(:user) { create_user }
  let(:account) { create_account(user: user, credit_limit: 5_000, initial_balance: 1_000) }
  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let(:card) { create_full_card(game: game) }

  describe "#balance" do
    it "is the starting balance plus wager net plus payments" do
      create_wager(account: account, line: card[:away_spread], amount: 100, status: :win)
      account.payments.create!(amount: 200, submitted_at: Time.current)

      # net for a win is the payout, not the stake.
      expected = 1_000 + card[:away_spread].payout(100) + 200

      expect(Account.find(account.id).balance).to be_within(0.01).of(expected)
    end
  end

  describe "#winnings vs #compute_balance" do
    it "winnings excludes payments, and compute_balance adds them back in" do
      create_wager(account: account, line: card[:away_spread], amount: 100, status: :win)
      account.payments.create!(amount: 500, submitted_at: Time.current)

      fresh = Account.find(account.id)
      expect(fresh.winnings).to be_within(0.01).of(1_000 + card[:away_spread].payout(100))
      expect(fresh.compute_balance).to eq(fresh.winnings + 500)
    end
  end

  describe "#wager_sum" do
    it "agrees whether or not the association is loaded" do
      create_wager(account: account, line: card[:away_spread], amount: 100, status: :win)
      create_wager(account: account, line: card[:home_spread], amount: 200, status: :loss)

      unloaded = Account.find(account.id)
      loaded = Account.find(account.id).tap { |a| a.wagers.load }

      expect(unloaded.wager_sum).to eq(loaded.wager_sum)
    end
  end

  describe "#payment_sum" do
    it "agrees whether or not the association is loaded" do
      account.payments.create!(amount: 100, submitted_at: Time.current)
      account.payments.create!(amount: 50, submitted_at: Time.current)

      unloaded = Account.find(account.id)
      loaded = Account.find(account.id).tap { |a| a.payments.load }

      expect(unloaded.payment_sum).to eq(150)
      expect(loaded.payment_sum).to eq(150)
    end
  end

  describe "#win_sum" do
    it "agrees whether or not the association is loaded" do
      create_wager(account: account, line: card[:away_spread], amount: 100, status: :win)
      create_wager(account: account, line: card[:home_spread], amount: 200, status: :loss)

      unloaded = Account.find(account.id)
      loaded = Account.find(account.id).tap { |a| a.wagers.load }

      expect(unloaded.win_sum).to be_within(0.01).of(card[:away_spread].payout(100))
      expect(loaded.win_sum).to eq(unloaded.win_sum)
    end
  end

  # The known bug: `wagers.select(&loss?)` means `&:loss?` - `loss?` is not a
  # method on Account, so this raises NameError (a NoMethodError, which
  # subclasses it) the moment the association happens to be loaded. Every
  # caller today is safe by accident: the history page's accounts arrive with
  # wagers unloaded, and the leaderboard eager-loads wagers but never calls
  # lose_sum. This spec is what catches the next caller that isn't so lucky.
  describe "#lose_sum" do
    it "agrees whether or not the association is loaded" do
      create_wager(account: account, line: card[:away_spread], amount: 100, status: :win)
      create_wager(account: account, line: card[:home_spread], amount: 200, status: :loss)

      unloaded = Account.find(account.id)
      loaded = Account.find(account.id).tap { |a| a.wagers.load }

      expect(unloaded.lose_sum).to eq(-200)
      expect(loaded.lose_sum).to eq(unloaded.lose_sum)
    end
  end

  describe "#liabilities" do
    it "counts only confirmed wagers, ignoring pending and settled ones" do
      create_wager(account: account, line: card[:away_spread], amount: 100, status: :pending)
      create_wager(account: account, line: card[:home_spread], amount: 200, status: :confirmed)
      create_wager(account: account, line: card[:over], amount: 300, status: :win)

      unloaded = Account.find(account.id)
      loaded = Account.find(account.id).tap { |a| a.wagers.load }

      expect(unloaded.liabilities).to eq(200)
      expect(loaded.liabilities).to eq(200)
    end
  end

  describe "#to_s" do
    it "prefers the nickname over the name" do
      account.update!(name: "Checking", nickname: "The Vault")
      expect(account.to_s).to eq("The Vault")
    end

    it "falls back to the name when there is no nickname" do
      account.update!(name: "Checking", nickname: nil)
      expect(account.to_s).to eq("Checking")
    end

    it "is blank when neither is set" do
      account.update!(name: nil, nickname: nil)
      expect(account.to_s).to eq("")
    end
  end

  describe "#qualified_name" do
    it "is just the user's name when the account is the default one" do
      account.update!(name: "Default", nickname: nil)
      expect(account.qualified_name).to eq(user.name)
    end

    it "appends the account's own name otherwise" do
      account.update!(name: "Side Book", nickname: nil)
      expect(account.qualified_name).to eq("#{user.name} (Side Book)")
    end

    it "is just the user's name when the account has no name at all" do
      account.update!(name: nil, nickname: nil)
      expect(account.qualified_name).to eq(user.name)
    end
  end
end
