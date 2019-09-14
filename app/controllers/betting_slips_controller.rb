class BettingSlipsController < ApplicationController
  def create
    @betting_slip = BettingSlip.build betting_slip_params

  end

  def show
  end

  def edit
  end

  def update
  end

  private

  def betting_slip_params
    params.require(:betting_slip).permit(:complete, )
  end
end
