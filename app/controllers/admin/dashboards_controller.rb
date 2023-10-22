module Admin
  class DashboardsController < ApplicationController
    def show

    end

    def fetch_lines
      if params[:scope].to_s == "second_half"
        if ENV["USE_ODDS_API"] == "1"
          @notice = LinesApiClient.update_lines(:second_half)
        else
          @notice = LineScraper.new.run("second_half")
        end
      else
        if ENV["USE_ODDS_API"] == "1"
          @notice = LinesApiClient.update_lines(:first_half)
        else
          @notice = LineScraper.run
          @notice += "First Half: #{LineScraper.run("first_half")}"
        end
      end
    end

    def fetch_scores
      @notice = ScoreScraper.run
    end

    def score_lines
      @notice = LineScorer.run.gsub("\n", "<br>")
    end

    def score_wagers
      @notice = WagerScorer.run
    end
  end
end
