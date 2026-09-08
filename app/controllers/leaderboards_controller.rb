class LeaderboardsController < ApplicationController
  def show
    @accounts = Account.
      where(leaderboard_visible: true).
      includes(:user, :wagers, :payments).
      sort_by(&:winnings).
      reverse

    @entries = Leaderboard.build(@accounts)
  end
end
