class LinesController < ApplicationController
  before_action :ensure_second_half_lines_are_recent!, only: [:index]

  def index
    @games = Line.
      active.
      send(sport).
      send(scope).
      joins(:game).
      merge(Game.viewable).
      references(:game).
      includes(:competitor, :game, :chump_wagers).
      order("games.starts_at").
      group_by(&:game).
      map { |game, lines| GameLinesViewModel.new(game: game, lines: lines, user: current_user) }
  end

  private

  # A sport that is switched off is not just hidden from the nav - asking for
  # it by hand falls back to whatever is on, so a stale bookmark or a link in
  # the group chat cannot reopen a board the book has closed.
  def sport
    @sport ||= (params[:sport].to_s.presence_in(Sports.enabled) || Sports.default || "nfl").to_sym
  end

  def scope
    @scope ||= (params[:scope].to_s.presence_in(Line::scopes.keys) || "game").to_sym
  end

  def ensure_second_half_lines_are_recent!
    return unless scope == :second_half

    return unless ENV["USE_BOVADA_API"] == "1"

    BovadaApiClient.ensure_second_half_lines_are_recent!(sport: sport)
  end
end
