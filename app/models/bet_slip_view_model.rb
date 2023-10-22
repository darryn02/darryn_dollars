class BetSlipViewModel
  attr_reader :status, :account, :wagers, :user
  delegate :name, to: :account

  def initialize(status, account, wagers, user)
    @status = status
    @account = account
    @wagers = wagers
    @user = user
  end

  def title
    if pending?
      "#{name} Pending Wagers".squish
    elsif confirmed?
      "#{name} Confirmed Wagers".squish
    else raise "Invalid Bet Slip Status"
    end
  end

  def pending?
    status == "pending"
  end

  def confirmed?
    status == "confirmed"
  end

  private

  def name
    if user.accounts.many?
      account.name
    elsif user.admin?
      account.qualified_name
    end
  end
end
