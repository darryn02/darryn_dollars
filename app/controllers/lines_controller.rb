class LinesController < ApplicationController
  before_action :ensure_second_half_lines_are_recent!, only: [:index]

  def index
    @lines_by_game = Line.
      active.
      send(sport).
      send(scope).
      joins(:game).
      merge(Game.wagerable).
      references(:game).
      includes(:competitor).
      order("games.starts_at").
      group_by(&:game)
  end

  private

  def sport
    @sport ||= (params[:sport].to_s.presence_in(Game.sports.keys) || "nfl").to_sym
  end

  def scope
    @scope ||= (params[:scope].to_s.presence_in(Line::scopes.keys) || "game").to_sym
  end

  def ensure_second_half_lines_are_recent!
    if scope == :second_half
      if ENV["USE_ODDS_API"] == "1"
        LinesApiClient.ensure_second_half_lines_are_recent!(sport: sport)
      else
        LineScraper.ensure_second_half_lines_are_recent!
      end
    end
  end
end
