class Wager < ApplicationRecord
  DEFAULT_MIN_WAGER = ENV.fetch('MIN_WAGER', 50).to_i
  WINDOW = ENV.fetch("WAGER_WINDOW_HOURS", 24).to_i.hours
  GRACE_PERIOD = ENV.fetch("WAGER_GRACE_PERIOD_MINUTES", 2).to_i.minutes

  belongs_to :account
  belongs_to :line
  has_one :contestant, through: :line

  enum status: { confirmed: 0, win: 1, loss: 2, push: 3, canceled: 4 }

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: DEFAULT_MIN_WAGER }
  validates :line, presence: true

  before_save :update_net

  def self.min_wager
    @min_wager || DEFAULT_MIN_WAGER
  end

  def self.min_wager=(value)
    @min_wager = value
  end

  def to_s
    str = "[#{id.presence || "x"}]" \
    " #{account if account.user.accounts.many?}" \
    " #{line}" \
    " for #{ActionController::Base.helpers.number_to_currency(amount)}"

    if valid?
      str.concat(" #{status} at #{placed_at.strftime("%l:%M:%S%P")}")
    else
      str.concat(" invalid, min wager is #{DEFAULT_MIN_WAGER}")
    end

    str.squish
  end

  private

  def update_net
    return self.net = line.payout(amount) if win?
    return self.net = -amount if loss?
    self.net = 0
  end
end
