class Wager < ApplicationRecord
  DEFAULT_MIN_WAGER = ENV.fetch('MIN_WAGER', 50).to_i
  WINDOW = ENV.fetch("WAGER_WINDOW_HOURS", 24).to_i.hours
  PREVIEW_WINDOW = ENV.fetch("WAGER_PREVIEW_WINDOW_HOURS", 12).to_i.hours
  GRACE_PERIOD = ENV.fetch("WAGER_GRACE_PERIOD_MINUTES", 2).to_i.minutes

  belongs_to :account
  belongs_to :bet_slip
  belongs_to :line
  has_one :contestant, through: :line

  enum status: { pending: 0, confirmed: 1, win: 2, loss: 3, push: 4, canceled: 5 }

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: DEFAULT_MIN_WAGER }, on: :create
  validates :line, presence: true, on: :create
  validates :account, presence: true, on: :create
  validate :game_has_not_started, on: :create
  validate :line_must_be_active, on: :create
  validate :account_has_sufficient_credit, on: :create

  before_save :update_net
  before_validation :set_placed_at

  def self.historical
    where(status: [:win, :loss, :push])
  end

  def self.min_wager
    @min_wager || DEFAULT_MIN_WAGER
  end

  def self.min_wager=(value)
    @min_wager = value
  end

  def self.list_all
    order(placed_at: :asc).map(&:to_s)
  end

  def historical?
    win? || loss? || push?
  end

  def to_s
    str =
      "#{ActionController::Base.helpers.number_to_currency(amount)} " \
      "#{line}".
      squish
  end

  def potential_profit
    line.payout(amount)
  end

  private

  def update_net
    return self.net = potential_profit if win?
    return self.net = -amount if loss?
    self.net = 0
  end

  def set_placed_at
    self.placed_at = Time.now
  end


  def game_has_not_started
    if line.active? && (line.game? || line.first_half?) && line.game.starts_at.past?
      errors.add(:line, "has expired, past game start time")
    end
  end

  def line_must_be_active
    if line.hidden?
      errors.add(:line, "is no longer active")
    end
  end

  def account_has_sufficient_credit
    if account.credit_limit + account.balance - account.liabilities < amount
      errors.add(:accout, "has insufficient credit")
    end
  end
end
