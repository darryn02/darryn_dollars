class BetSlip < ApplicationRecord
  has_many :wagers
  belongs_to :account
end
