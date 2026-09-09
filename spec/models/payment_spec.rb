require 'rails_helper'

RSpec.describe Payment, type: :model do
  it { should belong_to(:account) }

  it "belongs to the account it credits" do
    account = create_account(user: create_user)
    payment = account.payments.create!(amount: 100, submitted_at: Time.current)

    expect(payment.account).to eq(account)
  end

  # There is no model-level presence validation - amount is required only by
  # the database's `null: false`, so a caller finds out through a
  # StatementInvalid rather than an ActiveRecord::RecordInvalid with a
  # friendly message on the record.
  it "is required by the database, with no model-level validation to catch it first" do
    account = create_account(user: create_user)
    payment = account.payments.build(amount: nil, submitted_at: Time.current)

    expect(payment).to be_valid
    expect { payment.save! }.to raise_error(ActiveRecord::NotNullViolation)
  end
end
