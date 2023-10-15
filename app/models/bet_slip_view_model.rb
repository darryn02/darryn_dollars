class BetSlipViewModel
  attr_reader :status, :account, :wagers
  delegate :name, to: :account

  def initialize(status, account, wagers)
    @status = status
    @account = account
    @wagers = wagers
  end

  def pending?
    status == "pending"
  end

  def confirmed?
    status == "confirmed"
  end
end
