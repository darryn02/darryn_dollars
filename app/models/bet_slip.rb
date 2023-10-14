class BetSlip < ApplicationRecord
  has_many :wagers
  belongs_to :account

  enum status: { pending: 0, confirmed: 1 }
end
