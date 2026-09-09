require 'rails_helper'

RSpec.describe BetSlip, type: :model do
  it { should have_many(:wagers) }
  it { should belong_to(:account) }

  describe "status" do
    it "defaults to pending" do
      account = create_account(user: create_user)
      bet_slip = BetSlip.create!(account: account)

      expect(bet_slip).to be_pending
    end

    it "moves to confirmed" do
      account = create_account(user: create_user)
      bet_slip = BetSlip.create!(account: account, status: :confirmed)

      expect(bet_slip).to be_confirmed
    end
  end
end
