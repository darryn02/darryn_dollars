class Account < ApplicationRecord
  CHAD = ENV.fetch("CHAD_ACCOUNT_ID", 7).to_i

  belongs_to :user
  has_many :bet_slips
  has_many :wagers, through: :bet_slips
  has_many :payments

  def self.list_all
    Account.includes(:user, wagers: { line: { game: :contestants } }).map do |account|
      [
        "[#{account.id}]",
        account.user.name,
        "(#{account.name || "Primary"})",
        "#{ActionController::Base.helpers.number_to_currency(account.wagers.sum(&:net))}"
      ].join(" ")
    end
  end

  def to_s
    (nickname || name).to_s
  end

  def qualified_name
    if to_s.downcase.strip == "default"
      user.name
    else
      "#{user.name} #{to_s.present? ? "(#{to_s})" : ''}".squish
    end
  end

  def balance
    @balance ||= compute_balance
  end

  def winnings
    @winnings ||= initial_balance + wager_sum
  end

  def compute_balance
    winnings + payment_sum
  end

  def wager_sum
    if wagers.loaded?
      wagers.sum(&:net)
    else
      wagers.sum(:net)
    end
  end

  def payment_sum
    if payments.loaded?
      payments.sum(&:amount)
    else
      payments.sum(:amount)
    end
  end

  def win_sum
    if wagers.loaded?
      wagers.select(&:win?).sum(&:net)
    else
      wagers.win.sum(:net)
    end
  end

  def lose_sum
    if wagers.loaded?
      wagers.select(&loss?).sum(&:net)
    else
      wagers.loss.sum(:net)
    end
  end

  def liabilities
    if wagers.loaded?
      wagers.confirmed.sum(&:amount)
    else
      wagers.confirmed.sum(:amount)
    end
  end
end
