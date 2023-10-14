class Account < ApplicationRecord
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
    nickname || name
  end

  def qualified_name
    if to_s.downcase.strip == "default"
      user.name
    else
      "#{user.name} (#{to_s})"
    end
  end

  def balance
    @balance ||= compute_balance
  end

  def compute_balance
    initial_balance + wager_sum + payment_sum
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

  def liabilities
    if wagers.loaded?
      wagers.confirmed.sum(&:amount)
    else
      wagers.confirmed.sum(:amount)
    end
  end
end
