module Admin
  class DashboardsController < ApplicationController
    def show
      @accounts = Account.all
    end

    def fetch_lines
      if params[:scope].to_s == "second_half"
        if ENV["USE_BOVADA_API"] == "1"
          @notice = BovadaApiClient.update_lines(sport: params[:sport])
        elsif ENV["USE_ODDS_API"] == "1"
          @notice = LinesApiClient.update_lines(sport: params[:sport], scope: :second_half)
        end
      else
        if ENV["USE_BOVADA_API"] == "1"
          @notice = BovadaApiClient.update_lines(sport: params[:sport])
        elsif ENV["USE_ODDS_API"] == "1"
          @notice = LinesApiClient.update_lines(sport: params[:sport], scope: :first_half)
        end
      end
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
