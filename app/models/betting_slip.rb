class BettingSlip < ApplicationRecord
  belongs_to :user
  has_many :wagers
  has_many :lines, through: :wagers

  validates :user, presence: true
  validates_associated :wagers, if: :confirmed?
end
