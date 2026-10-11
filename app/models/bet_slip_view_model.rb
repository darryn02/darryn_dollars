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

  # Whether this slip needs telling apart from a sibling: its owner has more
  # than one account. Asked of the owner, not the viewer, so the book sees a
  # two-account player's slips marked the same way the player does.
  def show_avatar?
    account.user.accounts.many?
  end

  # "Confirm 2 wagers", or "Confirm Big Joe's 2 wagers" where there is another
  # slip it could be mistaken for.
  def confirm_label
    count = ActionController::Base.helpers.pluralize(wagers.size, "wager")

    show_avatar? ? "Confirm #{account.display_name}'s #{count}" : "Confirm #{count}"
  end

  # The owner's other accounts: where a wager on this slip could be moved to.
  def move_targets
    account.user.accounts.reject { |other| other == account }
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
      account.display_name
    elsif user.admin?
      account.qualified_name
    end
  end
end
