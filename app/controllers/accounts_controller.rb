class AccountsController < ApplicationController
  def show
  end

  def update
    current_user.accounts.each { |a| a.update!(leaderboard_visible: true) }
    redirect_to leaderboard_path
  end
end
