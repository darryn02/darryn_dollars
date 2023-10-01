class GamesController < ApplicationController
  def index
    @games = Game.
      wagerable.
      includes(:competitors, lines: { contestant: :competitor }).
      order(starts_at: :asc)
  end
end
