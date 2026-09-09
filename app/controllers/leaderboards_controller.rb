class LeaderboardsController < ApplicationController
  def show
    # Opting in makes an account eligible, but an account that has opted in
    # and never had a bet settled is not really playing yet - showing it
    # anyway would pad the board with names that have nothing to rank.
    @accounts = Account.
      where(leaderboard_visible: true).
      includes(:user, :wagers, :payments).
      select { |account| account.wagers.any?(&:historical?) }.
      sort_by(&:winnings).
      reverse

    @entries = Leaderboard.build(@accounts)
  end
end
