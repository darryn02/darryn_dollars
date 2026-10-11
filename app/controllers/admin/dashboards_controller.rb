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

    # These three answer with a report of several lines, handed over as the
    # plain text it is. Each used to swap its newlines for <br> and mark the
    # result html_safe, but the flash script renders a message as text, so
    # the book read the tags. The line breaks are now kept by the stylesheet
    # (.dd-flash__lines).
    #
    # Rendering the report as HTML instead was rejected: it carries team
    # names that arrive from a scrape, and html_safe on that is an open door.
    def fetch_scores
      @notice = ScoreScraper.run(params[:sport] || :nfl)
    end

    def score_lines
      @notice = LineScorer.run
    end

    def score_wagers
      @notice = WagerScorer.run
    end
  end
end
