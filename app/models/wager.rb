class Wager < ApplicationRecord
  include ResultEnum

  DEFAULT_MIN_WAGER = 25

  belongs_to :betting_slip
  belongs_to :line
  has_one :contestant, through: :line

  before_save :update_net

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: :min_wager }
  validates :line, presence: true

  def self.min_wager
    @@min_wager || DEFAULT_MIN_WAGER
  end

  def self.min_wager=(value)
    @@min_wager = value
  end

  private

  def update_net
    return self.net = line.payout(amount) if win?
    return self.net = -amount if loss?
    self.net = 0
  end
end
