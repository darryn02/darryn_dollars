class WagersController < ApplicationController
  def bet_slip
    @pending_bet_slip = current_user.accounts.first.bet_slips.pending.sole
    @pending_wagers, @confirmed_wagers = current_user.
      wagers.
      where(status: [:pending, :confirmed]).
      includes(:account, :line, :contestant).
      order(created_at: :asc).
      partition(&:pending?)
  end

  def history
    @wagers = current_user.
      wagers.
      #where.not(status: [:pending, :confirmed]).
      order(created_at: :desc).
      includes(:account, :line, :contestant)
  end

  def create
    respond_to do |format|
      @line_id = wager_params[:line_id]
      sanitize_params

      format.js { create_wager if valid_account_id? }
    end
  end

  def destroy
    @wager = Wager.find(params[:id])
    if @wager.pending?
      @wager.destroy
      @notice = "Wager #{@wager.id} has been cancelled."
    else
      @error = "Confirmed wagers cannot be cancelled.".html_safe
    end
  end

  private

  def valid_account_id?
    if current_user.account_ids.exclude?(wager_params[:account_id].to_i)
      @error = "Nice try - you do not have access to that account.".html_safe
      return false
    end

    true
  end

  def create_wager
    wager = slip.wagers.build(wager_params)
    if wager.save
      @notice = "Added to your bet slip. You now have #{slip.wagers.count} pending wager(s).".html_safe
    else
      @error = "There was a problem creating your wager. #{wager.errors.full_messages.join('. ')}".html_safe
    end
  end

  def wager_params
    params.require(:wager).permit(:line_id, :account_id, :amount)
  end

  def slip
    @slip ||= BetSlip.pending.find_or_create_by!(account_id: wager_params[:account_id])
  end

  def sanitize_params
    params[:wager][:amount] = params[:wager][:amount].gsub(/[\$\,]/, "")
  end
end
