class BetSlipsController < ApplicationController
  def index
  end

  def new
  end

  def create
  end

  def show
  end

  def update
    @bet_slip = BetSlip.find(params[:id])
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
    @bet_slip = BetSlip.find(params[:id])
    if @bet_slip.pending?
      @bet_slip.wagers.destroy_all
      redirect_to bet_slip_wagers_path, notice: "Your wagers have been cancelled"
    else
      redirect_to bet_slip_wagers_path, notice: "Confirmed wagers cannot be cancelled."
    end
  end
end
