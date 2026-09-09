class BetSlipsController < ApplicationController
  before_action :load_reachable_bet_slip, only: [:update, :destroy]

  def index
  end

  def new
  end

  def create
  end

  def show
  end

  def update
    if @bet_slip.pending?
      @bet_slip.wagers.each do |wager|
        wager.confirmed!
      end
      @bet_slip.confirmed!
      redirect_to bet_slip_wagers_path, notice: "Your wagers have been confirmed!"
    else
      redirect_to bet_slip_wagers_path, error: "Confirmed wagers cannot be cancelled."
    end
  end

  def destroy
    if @bet_slip.pending?
      @bet_slip.wagers.destroy_all
      redirect_to bet_slip_wagers_path, notice: "Your wagers have been cancelled"
    else
      redirect_to bet_slip_wagers_path, notice: "Confirmed wagers cannot be cancelled."
    end
  end

  private

  def load_reachable_bet_slip
    @bet_slip = BetSlip.find_by(id: params[:id])

    deny!("That bet slip is not yours.") unless @bet_slip && reachable_account?(@bet_slip.account_id)
  end
end
