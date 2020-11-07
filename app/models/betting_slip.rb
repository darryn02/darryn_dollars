class BettingSlip < ApplicationRecord
  belongs_to :account
  has_many :wagers
  has_many :lines, through: :wagers

  validates :account, presence: true
  validates_associated :wagers, if: :confirmed?
end
