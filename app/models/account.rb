class Account < ApplicationRecord
  belongs_to :user
  has_many :wagers

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
    name
  end
end
