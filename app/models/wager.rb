class Wager < ApplicationRecord
  DEFAULT_MIN_WAGER = ENV.fetch('MIN_WAGER', 50).freeze

  belongs_to :betting_slip
  belongs_to :line
  has_one :contestant, through: :line

  enum result: { pending: 0, win: 1, loss: 2, push: 3, canceled: 4 }

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: :min_wager }
  validates :line, presence: true

  before_save :update_net

  def self.min_wager
    @min_wager || DEFAULT_MIN_WAGER
  end

  def self.min_wager=(value)
    @min_wager = value
  end

  private

  def update_net
    return self.net = line.payout(amount) if win?
    return self.net = -amount if loss?
    self.net = 0
  end
end
