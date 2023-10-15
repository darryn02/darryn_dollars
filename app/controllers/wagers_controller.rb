class WagersController < ApplicationController
  def bet_slip
    @bet_slips = current_user.
      wagers.
      where(status: [:pending, :confirmed]).
      includes(:account, :line, :contestant).
      order(created_at: :asc).
      group_by { |wager| [wager.status, wager.account] }.
      map { |(status, account), wagers|
        BetSlipViewModel.new(status, account, wagers)
      }.sort_by(&method(:bet_slip_sort_order))
  end

  def history
    @wagers_by_account = current_user.
      wagers.
      #where.not(status: [:pending, :confirmed]).
      order(created_at: :desc).
      includes(:account, :line, :contestant).
      group_by(&:account)
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

  def confirm_pending
    @wagers = current_user.wagers.pending
    if @wagers.size.zero?
      redirect_to bet_slip_wagers_path, error: "No pending wagers to confirm."
    else
      errors = []
      @wagers.each do |wager|
        begin
          wager.confirmed!
        rescue ActiveRecord::RecordInvalid => e
          errors << "#{wager}: #{e.message.sub('Validation failed:', '')}"
        end
      end
      redirect_to bet_slip_wagers_path, notice: (["#{@wagers.size - errors.size} wagers confirmed."] + errors).join("<br>")
    end
  end

  def cancel_pending
    @wagers = current_user.wagers.pending
    if @wagers.size.zero?
      redirect_to bet_slip_wagers_path, error: "No pending wagers to cancel."
    else
      @wagers.destroy_all
      redirect_to bet_slip_wagers_path, notice: "#{@wagers.size} wagers cancelled"
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
      @notice = "Added to your bet slip. You now have #{current_user.wagers.pending.count} pending wager(s).".html_safe
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

  def bet_slip_sort_order(bet_slip)
    [
      bet_slip.status == "pending" ? 0 : 1,
      bet_slip.account.name.to_s
    ]
  end
end
