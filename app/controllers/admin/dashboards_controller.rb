module Admin
  class DashboardsController < ApplicationController
    before_action :require_admin!

    def show
      @accounts = Account.includes(:user).all
    end

    # One Bovada response carries every scope - game, first half and second
    # half - so there is nothing left for :scope to select between. The param
    # is still accepted so existing links keep working.
    def fetch_lines
      return unless ENV["USE_BOVADA_API"] == "1"

      @notice = BovadaApiClient.update_lines(sport: params[:sport])
    end

    def fetch_scores
      @notice = ScoreScraper.run(params[:sport] || :nfl).gsub("\n", "<br>").html_safe
    end

    def score_lines
      @notice = LineScorer.run.gsub("\n", "<br>").html_safe
    end

    def score_wagers
      @notice = WagerScorer.run.gsub("\n", "<br>").html_safe
    end
  end
end
