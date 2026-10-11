require "rails_helper"

RSpec.describe AccountsHelper, type: :helper do
  let(:user) { create_user }
  let!(:big) { create_account(user: user, name: "Big Joe") }
  let!(:little) { create_account(user: user, name: "Little Joe") }

  describe "#account_initials" do
    it "takes a letter from each of the first two words" do
      expect(helper.account_initials(big)).to eq("BJ")
      expect(helper.account_initials(little)).to eq("LJ")
    end

    it "takes one letter from a one-word name" do
      big.update!(name: "main")

      expect(helper.account_initials(big)).to eq("M")
    end

    # A nickname can be nothing but an emoji or punctuation, which left the
    # avatar an empty disc.
    it "falls back to the first character when there is no letter or digit" do
      big.update!(name: nil, nickname: "🔥🔥")

      expect(helper.account_initials(big)).to eq("🔥")
    end
  end

  describe "#account_color_class" do
    it "gives sibling accounts different colours" do
      expect(helper.account_color_class(big)).to eq("dd-acct--0")
      expect(helper.account_color_class(little)).to eq("dd-acct--1")
    end

    # The slot comes from the account's place among its owner's accounts, so
    # it rests on that order being fixed.
    it "keeps each account's colour after one of them is saved" do
      big.update!(nickname: "Big")

      reloaded = User.find(user.id).accounts

      expect(reloaded.map { |account| helper.account_color_class(account) }).to eq(%w[dd-acct--0 dd-acct--1])
      expect(reloaded.first).to eq(big)
    end

    it "wraps round rather than running out" do
      extra = Array.new(3) { |i| create_account(user: user, name: "Extra #{i}") }

      expect(helper.account_color_class(extra.last)).to eq("dd-acct--0")
    end
  end

  describe "#account_avatar" do
    it "is hidden from screen readers, since the name is always beside it" do
      html = helper.account_avatar(big)

      expect(html).to include('aria-hidden="true"')
      expect(html).to include("dd-acct--0")
      expect(html).to include(">BJ<")
    end

    it "shows the emoji once the player has picked one" do
      big.update!(emoji: "🐻")

      html = helper.account_avatar(big)

      expect(html).to include(">🐻<")
      expect(html).to include("dd-acct-avatar--emoji")
      expect(html).not_to include("BJ")
    end
  end

  describe "#available_credit" do
    it "never reads as negative" do
      big.update!(credit_limit: 100, initial_balance: -500)

      expect(helper.available_credit(Account.find(big.id))).to eq(0)
    end
  end
end
